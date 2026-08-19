#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use File::Path qw(remove_tree);
use Cwd 'abs_path';
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

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

my $filename = $q->param('filename') // '';

if ($filename !~ /^(?:auto_backup_ospulso_|ospulso_backup_)[\d_]+\.zip$/) {
    print encode_json({ status => 'error', message => 'Nombre de archivo no válido.' });
    exit;
}

my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $uploads_dir = File::Spec->catdir($FindBin::Bin, '..', 'uploads');
my $backup_path = File::Spec->catfile($dat_dir, 'backups', $filename);

if (!-f $backup_path) {
    print encode_json({ status => 'error', message => 'El archivo de respaldo no existe.' });
    exit;
}

eval {
    # PASO 0: VERIFICAR Y ABRIR EL ZIP (Antes de borrar nada)
    my $zip = Archive::Zip->new();
    if ($zip->read($backup_path) != AZ_OK) {
        die "Error fatal al leer el archivo ZIP. El archivo podría estar corrupto. No se ha modificado la base de datos actual.";
    }

    # PASO 1: LIMPIEZA DE DIRECTORIOS OPERATIVOS
    # Limpiamos dat/ (omitiendo la carpeta backups)
    opendir(my $dh_dat, $dat_dir) or die "No se puede abrir directorio dat: $!";
    my @dat_items = grep { $_ !~ /^\.\.?$/ && $_ ne 'backups' } readdir($dh_dat);
    closedir($dh_dat);
    
    foreach my $item (@dat_items) {
        my $full_path = File::Spec->catfile($dat_dir, $item);
        if (-d $full_path) {
            remove_tree($full_path);
        } else {
            unlink $full_path;
        }
    }
    
    # Limpiamos uploads/
    if (-d $uploads_dir) {
        opendir(my $dh_up, $uploads_dir) or die "No se puede abrir directorio uploads: $!";
        my @up_items = grep { $_ !~ /^\.\.?$/ } readdir($dh_up);
        closedir($dh_up);
        foreach my $item (@up_items) {
            my $full_path = File::Spec->catfile($uploads_dir, $item);
            if (-d $full_path) {
                remove_tree($full_path);
            } else {
                unlink $full_path;
            }
        }
    }

    # PASO 2: DESCOMPRIMIR EL RESPALDO
    
    my $root_dir = abs_path("$FindBin::Bin/..");
    chdir $root_dir or die "No se pudo cambiar al directorio raíz del proyecto: $!";
    
    if ($zip->extractTree() != AZ_OK) {
        die "Error fatal al extraer el archivo ZIP. Detalles Archive::Zip: $zip_error_msg";
    }
    
    print encode_json({ status => 'success', message => 'Restauración completada con éxito. El sistema ha vuelto al estado del respaldo.' });
};

if ($@) {
    print encode_json({ status => 'error', message => "Error crítico durante la restauración: $@" });
}
