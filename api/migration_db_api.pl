#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
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

my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $mig_dir = File::Spec->catdir($dat_dir, 'migraciones');
my $root_dir = abs_path("$FindBin::Bin/..");

unless (-d $mig_dir) {
    require File::Path;
    File::Path::make_path($mig_dir);
}

my $timestamp = strftime "%Y%m%d_%H%M%S", localtime;
my $filename = "ospulso_migration_$timestamp.zip";
my $backup_path = File::Spec->catfile($mig_dir, $filename);

# Construimos comando ZIP nativo de Linux
# -q = quiet, -r = recursivo
# -x excluye las carpetas completas y todo su contenido
my $cmd = qq{cd "$root_dir" && zip -q -r "$backup_path" . -x ".git/*" -x ".git" -x "dat/backups/*" -x "dat/backups" -x "dat/migraciones/*" -x "dat/migraciones"};
my $output = `$cmd 2>&1`;
my $exit_code = $? >> 8;

# Zip devuelve código 0 en éxito, 12 si no hay nada que hacer, pero 0 es éxito.
if ($exit_code == 0) {
    print encode_json({ 
        status => 'success', 
        message => 'Paquete de migración creado exitosamente usando ZIP nativo.',
        filename => $filename
    });
} else {
    print encode_json({ 
        status => 'error', 
        message => "Error al ejecutar zip nativo. Código: $exit_code. Detalle: $output" 
    });
}
