#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use POSIX qw(strftime);
use File::Path qw(make_path);
use Cwd 'abs_path';
use Digest::SHA qw(sha256_hex);

# Soporte dual: Modo Web (CGI/Curl) y Modo Terminal (Cron CLI)
my $is_web = ($ENV{'REQUEST_METHOD'} || $ENV{'GATEWAY_INTERFACE'}) ? 1 : 0;
if ($is_web) {
    print "Content-Type: text/plain; charset=UTF-8\n\n";
}

# Parámetro de ejecución forzada para pruebas (CLI o Web ?force=1)
my $force = 0;
if ($ARGV[0] && $ARGV[0] eq '--force') {
    $force = 1;
} elsif ($is_web && ($ENV{'QUERY_STRING'} // '') =~ /force=1/i) {
    $force = 1;
}

my $dat_dir          = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $uploads_dir      = File::Spec->catdir($FindBin::Bin, '..', 'uploads');
my $config_file      = File::Spec->catfile($dat_dir, 'backup_cron_config.dat');
my $backups_dir      = File::Spec->catdir($dat_dir, 'backups');
my $lock_file        = File::Spec->catfile($backups_dir, '.cron_backup.lock');
my $log_file         = File::Spec->catfile($dat_dir, 'cron_backup.log');
my $fingerprint_file = File::Spec->catfile($dat_dir, 'last_backup_fingerprint.dat');
my $last_run_file    = File::Spec->catfile($dat_dir, 'last_cron_backup_run.dat');

sub cron_log {
    my $msg = shift;
    my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
    if ($is_web) {
        print "[$ts] $msg\n";
    }
    if (open(my $lh, '>>:encoding(UTF-8)', $log_file)) {
        print $lh "[$ts] $msg\n";
        close($lh);
    }
}

# 1. Leer Configuración
my %config = ( enabled => 0, time => '', days => '' );
if (-f $config_file) {
    if (open(my $fh, '<:encoding(UTF-8)', $config_file)) {
        while(<$fh>) {
            chomp;
            if (/^ENABLED\|(\d+)$/) { $config{enabled} = $1; }
            if (/^TIME\|(.+)$/)    { $config{time} = $1; }
            if (/^DAYS\|(.+)$/)    { $config{days} = $1; }
        }
        close($fh);
    }
}

unless ($force) {
    if ($config{enabled} != 1) {
        cron_log("Cron inactivo (ENABLED=0). Abortando.");
        exit 0;
    }
    if (!$config{time} || $config{days} eq '') {
        cron_log("Cron sin configuración de horario o días. Abortando.");
        exit 0;
    }

    # 2. Verificar Día y Horarios (soporte hasta 3 horarios separados por coma)
    my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);
    my $current_time = sprintf("%02d:%02d", $hour, $min);

    my @allowed_days = split(',', $config{days});
    my $day_match = grep { $_ == $wday } @allowed_days;

    if (!$day_match) {
        cron_log("Día de la semana ($wday) no habilitado en la programación. Abortando.");
        exit 0;
    }

    # Ventana de coincidencia para cualquiera de los horarios configurados
    my @allowed_times = split(',', $config{time});
    my $now_minutes = ($hour * 60) + $min;
    my $time_matched = 0;
    my $matched_slot = '';

    foreach my $slot (@allowed_times) {
        $slot =~ s/^\s+|\s+$//g;
        next unless $slot =~ /^(\d{1,2}):(\d{2})$/;
        my ($sh, $sm) = ($1, $2);
        my $slot_minutes = ($sh * 60) + $sm;
        my $diff = abs($now_minutes - $slot_minutes);
        
        # Tolerancia: coincidencia dentro de ventana de 15 minutos o igualdad de hora
        if ($diff <= 15 || $current_time eq sprintf("%02d:%02d", $sh, $sm)) {
            $time_matched = 1;
            $matched_slot = $slot;
            last;
        }
    }

    if (!$time_matched) {
        cron_log("Hora actual ($current_time) no coincide con ningún horario programado ($config{time}). Abortando.");
        exit 0;
    }

    # Prevención de ejecuciones repetidas dentro del mismo slot (mínimo 30 minutos de espaciado)
    if (-f $last_run_file) {
        if (open(my $lrf, '<', $last_run_file)) {
            my $last_ts = <$lrf>;
            chomp($last_ts) if defined $last_ts;
            close($lrf);
            if ($last_ts && (time - $last_ts) < 1800) {
                cron_log("Respaldo ya ejecutado hace menos de 30 minutos. Omitiendo repetición en slot ($matched_slot).");
                exit 0;
            }
        }
    }
}

# 3. Lock File (Evitar ejecuciones concurrentes)
make_path($backups_dir) unless -d $backups_dir;
if (-f $lock_file && !$force) {
    my $lock_age = time - (stat($lock_file))[9];
    if ($lock_age < 1200) {
        cron_log("Existe un proceso de respaldo en ejecución (lock activo). Abortando.");
        exit 0;
    }
}

if (open(my $lf, '>', $lock_file)) {
    print $lf $$;
    close($lf);
}

# 4. Zero-Change Guard: Cálculo de huella digital de datos para evitar respaldos idénticos
sub calcular_huella_datos {
    my ($dir_dat, $dir_uploads) = @_;
    my @entradas;
    
    my $sub_explorar;
    $sub_explorar = sub {
        my ($dir, $rel_prefix) = @_;
        return unless -d $dir;
        opendir(my $dh, $dir) or return;
        my @items = grep { $_ !~ /^\.\.?$/ } readdir($dh);
        closedir($dh);
        
        foreach my $item (@items) {
            my $full_path = File::Spec->catfile($dir, $item);
            my $rel_path  = $rel_prefix ? "$rel_prefix/$item" : $item;
            
            # Exclusiones de archivos efímeros, temporales o carpetas de salida
            next if $rel_path =~ m{^(dat[/\\])?(backups|migraciones)([/\\]|$)};
            next if $item =~ /\.(log|lock|status|tmp|fingerprint)$/i;
            next if $item eq 'backup_cron_config.dat';
            next if $item =~ /^last_cron_backup_run/;
            next if $item =~ /^last_backup_fingerprint/;
            
            if (-d $full_path) {
                $sub_explorar->($full_path, $rel_path);
            } elsif (-f $full_path) {
                my @st = stat($full_path);
                my $size  = $st[7] || 0;
                my $mtime = $st[9] || 0;
                push @entradas, "$rel_path:$size:$mtime";
            }
        }
    };
    
    $sub_explorar->($dir_dat, 'dat');
    if (-d $dir_uploads) {
        $sub_explorar->($dir_uploads, 'uploads');
    }
    
    @entradas = sort @entradas;
    my $cadena_control = join("\n", @entradas);
    return sha256_hex($cadena_control);
}

my $huella_actual = eval { calcular_huella_datos($dat_dir, $uploads_dir) } || '';

if (!$force && $huella_actual) {
    my $huella_anterior = '';
    if (-f $fingerprint_file && open(my $fh_fp, '<', $fingerprint_file)) {
        $huella_anterior = <$fh_fp>;
        chomp($huella_anterior) if defined $huella_anterior;
        close($fh_fp);
    }
    
    if ($huella_anterior && $huella_anterior eq $huella_actual) {
        cron_log("Zero-Change Guard: Sin modificaciones detectadas en datos desde el último respaldo. Respaldo omitido para optimizar almacenamiento.");
        unlink($lock_file) if -f $lock_file;
        exit 0;
    }
}

cron_log("Iniciando respaldo automático de OSPulso (Modo: " . ($force ? "FORZADO" : "PROGRAMADO") . ")...");

our $zip_error_msg = '';
Archive::Zip::setErrorHandler(sub {
    $zip_error_msg .= shift() . " | ";
});

eval {
    my $root_dir = abs_path("$FindBin::Bin/..");
    my $timestamp = strftime "%Y%m%d_%H%M%S", localtime;
    my $filename = "auto_backup_ospulso_$timestamp.zip";
    my $backup_path = File::Spec->catfile($backups_dir, $filename);
    
    # Intento 1: Comando nativo zip si está disponible en el servidor Linux
    my $cmd = qq{cd "$root_dir" && zip -q -r "$backup_path" dat uploads -x "dat/backups/*" -x "dat/backups" -x "dat/migraciones/*" -x "dat/migraciones"};
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;
    
    if ($exit_code != 0) {
        # Intento 2: Fallback puro con Archive::Zip
        cron_log("Aviso: Zip nativo no disponible o falló ($output). Usando fallback Archive::Zip...");
        my $zip = Archive::Zip->new();
        $zip->addTree($dat_dir, 'dat', sub {
            return 0 if $_ =~ m{[/\\]backups([/\\].*)?$}i;
            return 0 if $_ =~ m{[/\\]migraciones([/\\].*)?$}i;
            return 1;
        });
        if (-d $uploads_dir) {
            $zip->addTree($uploads_dir, 'uploads');
        }
        unless ($zip->writeToFileNamed($backup_path) == AZ_OK) {
            die "Error en fallback Archive::Zip: $zip_error_msg";
        }
    }
    
    my $filesize = -s $backup_path || 0;
    cron_log("Respaldo creado con éxito: $filename ($filesize bytes)");
    
    # Guardar nueva huella y marca de última ejecución exitosa
    if ($huella_actual && open(my $fh_out_fp, '>', $fingerprint_file)) {
        print $fh_out_fp $huella_actual;
        close($fh_out_fp);
    }
    if (open(my $fh_lrf, '>', $last_run_file)) {
        print $fh_lrf time();
        close($fh_lrf);
    }
    
    # 5. Política de retención estricta: Conservar únicamente los 3 respaldos automáticos más recientes
    if (opendir(my $bdh, $backups_dir)) {
        my @all_files = readdir($bdh);
        closedir($bdh);
        
        my @auto_backups = grep { /^auto_backup_ospulso_\d{8}_\d{6}\.zip$/ } @all_files;
        
        # Ordenar descendente por timestamp (más recientes primero)
        @auto_backups = sort {
            my ($ta) = $a =~ /_(\d{8}_\d{6})\.zip$/;
            my ($tb) = $b =~ /_(\d{8}_\d{6})\.zip$/;
            ($tb // '') cmp ($ta // '')
        } @auto_backups;
        
        my $total_auto = scalar(@auto_backups);
        if ($total_auto > 3) {
            my $deleted_count = 0;
            for (my $i = 3; $i < $total_auto; $i++) {
                my $file_to_del = File::Spec->catfile($backups_dir, $auto_backups[$i]);
                if (unlink($file_to_del)) {
                    $deleted_count++;
                }
            }
            cron_log("Retención aplicada: Conservados los 3 últimos respaldos. Eliminados $deleted_count respaldos excedentes.");
        } else {
            cron_log("Retención: $total_auto respaldos automáticos en almacén (dentro del límite de 3).");
        }
    }
};

if ($@) {
    cron_log("ERROR CRÍTICO: $@");
}

unlink($lock_file) if -f $lock_file;
cron_log("Trabajo de cron finalizado.");
