#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use POSIX qw(strftime);
use Cwd 'abs_path';

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

# Seguridad estricta: Solo Administrador Global
if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Global') {
    print encode_json({ status => 'error', message => 'Acceso denegado. Exclusivo para Administrador Global.' });
    exit;
}

our $zip_error_msg = '';
Archive::Zip::setErrorHandler(sub {
    $zip_error_msg .= shift() . " | ";
});

eval {
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $uploads_dir = File::Spec->catdir($FindBin::Bin, '..', 'uploads');
    my $root_dir = abs_path("$FindBin::Bin/..");
    
    my $timestamp = strftime "%Y%m%d_%H%M%S", localtime;
    my $filename = "ospulso_backup_$timestamp.zip";
    my $backup_path = File::Spec->catfile($dat_dir, 'backups', $filename);
    
    # Comando nativo ZIP para evitar desbordamiento de memoria (OOM) que causa tablas en cero
    my $cmd = qq{cd "$root_dir" && zip -q -r "$backup_path" dat uploads -x "dat/backups/*" -x "dat/backups" -x "dat/migraciones/*" -x "dat/migraciones"};
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;
    
    if ($exit_code != 0) {
        die "Error al ejecutar zip nativo. Código: $exit_code. Detalle: $output";
    }
    
    print encode_json({ 
        status => 'success', 
        message => 'Backup creado exitosamente.',
        filename => $filename
    });
};

if ($@) {
    print encode_json({ status => 'error', message => "Error en el backup: $@" });
}
