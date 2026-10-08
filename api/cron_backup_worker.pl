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

# Logging para el cron
my $log_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cron_backup.log');
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

my $dat_dir     = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $uploads_dir = File::Spec->catdir($FindBin::Bin, '..', 'uploads');
my $config_file = File::Spec->catfile($dat_dir, 'backup_cron_config.dat');
my $backups_dir = File::Spec->catdir($dat_dir, 'backups');
my $lock_file   = File::Spec->catfile($backups_dir, '.cron_backup.lock');

# 1. Leer Configuración
my %config = ( enabled => 0, time => '', days => '' );
if (-f $config_file) {
    if (open(my $fh, '<:encoding(UTF-8)', $config_file)) {
        while(<$fh>) {
            chomp;
            if (/^ENABLED\|(\d+)$/) { $config{enabled} = $1; }
            if (/^TIME\|(.+)$/) { $config{time} = $1; }
            if (/^DAYS\|(.+)$/) { $config{days} = $1; }
        }
        close($fh);
    }
}

unless ($force) {
    if ($config{enabled} != 1) {
        cron_log("Cron inactivo (ENABLED=0). Abortando.");
        exit;
    }
    if (!$config{time} || $config{days} eq '') {
        cron_log("Cron sin configuración de hora o días. Abortando.");
        exit;
    }

    # 2. Verificar Día y Hora Actual
    my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);
    my $current_time = sprintf("%02d:%02d", $hour, $min);

    my @allowed_days = split(',', $config{days});
    my $day_match = grep { $_ == $wday } @allowed_days;

    if (!$day_match) {
        cron_log("Día de la semana ($wday) no habilitado en la programación. Abortando.");
        exit;
    }

    # Tolerancia: Coincidencia exacta de hora o dentro de una ventana de 15 minutos del slot
    my ($conf_h, $conf_m) = split(':', $config{time});
    $conf_h //= 0; $conf_m //= 0;
    my $now_minutes = ($hour * 60) + $min;
    my $conf_minutes = ($conf_h * 60) + $conf_m;
    my $diff_minutes = abs($now_minutes - $conf_minutes);

    if ($diff_minutes > 15 && $current_time ne $config{time}) {
        cron_log("Hora actual ($current_time) no coincide con hora programada ($config{time}). Abortando.");
        exit;
    }
}

# 3. Lock File (Evitar ejecuciones concurrentes)
if (-f $lock_file && !$force) {
    my $lock_age = time - (stat($lock_file))[9];
    if ($lock_age < 1200) {
        cron_log("Existe un proceso de respaldo en ejecución (lock activo). Abortando.");
        exit;
    }
}

if (open(my $lf, '>', $lock_file)) {
    print $lf $$;
    close($lf);
}

cron_log("Iniciando respaldo automático de OSPulso (Modo: " . ($force ? "FORZADO" : "PROGRAMADO") . ")...");

our $zip_error_msg = '';
Archive::Zip::setErrorHandler(sub {
    $zip_error_msg .= shift() . " | ";
});

eval {
    make_path($backups_dir) unless -d $backups_dir;
    
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
        cron_log("Aviso: Zip nativo falló ($output). Usando fallback Archive::Zip...");
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
    
    cron_log("Respaldo creado con éxito: $filename (" . (-s $backup_path) . " bytes)");
    
    # 5. Rotación a 3 días de permanencia (3 * 86400s)
    if (opendir(my $bdh, $backups_dir)) {
        my @auto_backups = grep { /^auto_backup_ospulso_.*\.zip$/ } readdir($bdh);
        closedir($bdh);
        
        my $now = time;
        my $deleted_count = 0;
        foreach my $ab (@auto_backups) {
            my $ab_path = File::Spec->catfile($backups_dir, $ab);
            my $mtime = (stat($ab_path))[9] || 0;
            my $age_days = ($now - $mtime) / (60 * 60 * 24);
            if ($age_days > 3) {
                unlink($ab_path);
                $deleted_count++;
            }
        }
        cron_log("Limpieza rotativa completada: $deleted_count respaldos antiguos (>3 días) eliminados.") if $deleted_count > 0;
    }
};

if ($@) {
    cron_log("ERROR CRÍTICO: $@");
}

unlink($lock_file) if -f $lock_file;
cron_log("Trabajo de cron finalizado.");
