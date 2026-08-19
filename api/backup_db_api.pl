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

eval {
    my $zip = Archive::Zip->new();
    
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $uploads_dir = File::Spec->catdir($FindBin::Bin, '..', 'uploads');
    
    # 1. Agregar contenido de 'dat' (omitiendo la carpeta 'backups')
    opendir(my $dh_dat, $dat_dir) or die "No se puede abrir directorio dat: $!";
    my @dat_items = grep { $_ !~ /^\.\.?$/ && $_ ne 'backups' } readdir($dh_dat);
    closedir($dh_dat);
    
    foreach my $item (@dat_items) {
        my $full_path = File::Spec->catfile($dat_dir, $item);
        if (-d $full_path) {
            $zip->addTree($full_path, "dat/$item") == AZ_OK or die "Error al añadir carpeta dat/$item";
        } else {
            $zip->addFile($full_path, "dat/$item") or die "Error al añadir archivo dat/$item";
        }
    }
    
    # 2. Agregar contenido de 'uploads'
    if (-d $uploads_dir) {
        $zip->addTree($uploads_dir, "uploads") == AZ_OK or die "Error al añadir carpeta uploads";
    }
    
    # 3. Generar archivo ZIP en dat/backups/
    my $timestamp = strftime "%Y%m%d_%H%M%S", localtime;
    my $filename = "ospulso_backup_$timestamp.zip";
    my $backup_path = File::Spec->catfile($dat_dir, 'backups', $filename);
    
    if ($zip->writeToFileNamed($backup_path) != AZ_OK) {
        die "Error fatal al escribir el archivo ZIP en disco.";
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
