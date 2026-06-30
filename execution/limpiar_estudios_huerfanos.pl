#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use File::Spec;
use File::Path qw(remove_tree);
use FindBin;
use lib '..';

print "Iniciando script de limpieza de estudios huerfanos...\n";

# 1. Leer los estudios validos de estudios.dat
my $estudios_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
my %valid_dirs = ();
my $count_valid = 0;

if (-e $estudios_dat) {
    open(my $fh, '<:encoding(UTF-8)', $estudios_dat) or die "No se pudo abrir estudios.dat: $!";
    while(my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @cols = split(/\|/, $line);
        my $id_estudio = $cols[0];
        my $id_paciente = $cols[1];
        if ($id_estudio && $id_paciente) {
            $valid_dirs{"$id_paciente/$id_estudio"} = 1;
            $count_valid++;
        }
    }
    close $fh;
}

print "Se encontraron $count_valid estudios registrados en la base de datos plana.\n";

# 2. Escanear el directorio fisico
my $rx_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'estudiosRX');
if (!-d $rx_dir) {
    print "El directorio $rx_dir no existe. Saliendo.\n";
    exit;
}

opendir(my $dh_pacientes, $rx_dir) or die "No se pudo leer $rx_dir: $!";
my @pacientes = grep { !/^\./ && -d File::Spec->catdir($rx_dir, $_) } readdir($dh_pacientes);
closedir($dh_pacientes);

my $carpetas_eliminadas = 0;

foreach my $paciente (@pacientes) {
    my $paciente_dir = File::Spec->catdir($rx_dir, $paciente);
    opendir(my $dh_estudios, $paciente_dir) or next;
    my @estudios = grep { !/^\./ && -d File::Spec->catdir($paciente_dir, $_) } readdir($dh_estudios);
    closedir($dh_estudios);

    foreach my $estudio (@estudios) {
        my $key = "$paciente/$estudio";
        if (!$valid_dirs{$key}) {
            my $ruta_a_borrar = File::Spec->catdir($paciente_dir, $estudio);
            print "=> Eliminando directorio huerfano: $ruta_a_borrar\n";
            remove_tree($ruta_a_borrar);
            $carpetas_eliminadas++;
        }
    }
}

print "\nLimpieza completada.\n";
print "Carpetas huerfanas eliminadas físicamente: $carpetas_eliminadas\n";
