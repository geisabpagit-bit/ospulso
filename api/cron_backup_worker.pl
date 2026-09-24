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

# Logging para el cron (opcional, pero útil para depurar)
my $log_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cron_backup.log');
sub cron_log {
    my $msg = shift;
    my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
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
    open(my $fh, '<:encoding(UTF-8)', $config_file) or exit;
    while(<$fh>) {
        chomp;
        if (/^ENABLED\|(\d+)$/) { $config{enabled} = $1; }
        if (/^TIME\|(.+)$/) { $config{time} = $1; }
        if (/^DAYS\|(.+)$/) { $config{days} = $1; }
    }
    close($fh);
}

exit unless $config{enabled} == 1;
exit unless $config{time} && $config{days} ne '';

# 2. Verificar Día y Hora Actual
my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime(time);
my $current_time = sprintf("%02d:%02d", $hour, $min);

my @allowed_days = split(',', $config{days});
my $day_match = grep { $_ == $wday } @allowed_days;

exit unless $day_match;
exit unless $current_time eq $config{time};

# 3. Lock File (Evitar ejecuciones múltiples)
if (-f $lock_file) {
    my $lock_age = time - (stat($lock_file))[9];
    # Si el lock file es de hace menos de 20 minutos (1200 seg), abortar.
    exit if $lock_age < 1200;
}

open(my $lf, '>', $lock_file);
print $lf $$;
close($lf);

cron_log("Iniciando respaldo automático...");

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
    
    my $cmd = qq{cd "$root_dir" && zip -q -r "$backup_path" dat uploads -x "dat/backups/*" -x "dat/backups" -x "dat/migraciones/*" -x "dat/migraciones"};
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;
    
    if ($exit_code != 0) {
        die "Error fatal ZIP nativo. Código: $exit_code. Detalle: $output";
    }
    
    cron_log("Respaldo creado: $filename");
    
    # 5. Rotación a 3 días de permanencia (3 * 86400s)
    opendir(my $bdh, $backups_dir);
    my @auto_backups = grep { /^auto_backup_ospulso_.*\.zip$/ } readdir($bdh);
    closedir($bdh);
    
    my $now = time;
    my $deleted_count = 0;
    foreach my $ab (@auto_backups) {
        my $ab_path = File::Spec->catfile($backups_dir, $ab);
        my $mtime = (stat($ab_path))[9];
        my $age_days = ($now - $mtime) / (60 * 60 * 24);
        if ($age_days > 3) {
            unlink($ab_path);
            $deleted_count++;
        }
    }
    cron_log("Limpieza completada: $deleted_count respaldos automáticos antiguos (>3 días) eliminados.") if $deleted_count > 0;
};

if ($@) {
    cron_log("ERROR CRÍTICO: $@");
}

unlink($lock_file);
