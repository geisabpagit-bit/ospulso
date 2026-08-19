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

my $input_data = '';
read(STDIN, $input_data, $ENV{'CONTENT_LENGTH'} || 0);
my $json_in = eval { decode_json($input_data) } || {};
my $filename = $json_in->{filename} // '';

if ($filename !~ /^ospulso_backup_[\d_]+\.zip$/) {
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
    my $zip = Archive::Zip->new();
    if ($zip->read($backup_path) != AZ_OK) {
        die "Error fatal al leer el archivo ZIP.";
    }
    
    my $root_dir = File::Spec->catdir($FindBin::Bin, '..');
    
    if ($zip->extractTree('', "$root_dir/") != AZ_OK) {
        die "Error fatal al extraer el archivo ZIP.";
    }
    
    print encode_json({ status => 'success', message => 'Restauración completada con éxito. El sistema ha vuelto al estado del respaldo.' });
};

if ($@) {
    print encode_json({ status => 'error', message => "Error crítico durante la restauración: $@" });
}
