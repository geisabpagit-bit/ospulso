#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI '-utf8';
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(encode_json);
use File::Spec;
use File::Path qw(make_path);
use POSIX qw(strftime);
use FindBin;
use lib '..';

my $q = CGI->new;

print $q->header(-type => 'application/json', -charset => 'UTF-8');

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
my $session_data = check_session();
if (!$session_data->{session_ok}) {
    print encode_json({ ok => 0, msg => "Sesión caducada." });
    exit;
}

my $id_paciente = $q->param('id_paciente');
my $nombre_estudio = $q->param('nombre_estudio') || 'Estudio sin nombre';
my $modalidad = $q->param('modalidad') || 'OT';

if (!$id_paciente || !$nombre_estudio) {
    print encode_json({ ok => 0, msg => "Faltan datos obligatorios (Paciente o Nombre de Estudio)." });
    exit;
}

my $base_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'estudiosRX');
my $estudios_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');

# 1. Determinar ID de estudio
my $max_id = 0;
if (-e $estudios_dat) {
    open(my $in_fh, '<', $estudios_dat);
    my $header = <$in_fh>; # saltar cabecera
    while(<$in_fh>) {
        chomp;
        my @cols = split(/\|/, $_);
        if ($cols[0] =~ /^\d+$/ && $cols[0] > $max_id) {
            $max_id = $cols[0];
        }
    }
    close $in_fh;
}
my $id_estudio = $max_id + 1;

my $timestamp = time();
my $fecha_str = strftime("%Y-%m-%d", localtime($timestamp));
my $ruta_logica = "dat/estudiosRX/${id_paciente}/${id_estudio}";

use utils::db_manager qw(guardar_registro);
my $nueva_linea = join('|', 
    $id_estudio, 
    $id_paciente, 
    $fecha_str, 
    $modalidad, 
    $nombre_estudio, 
    $ruta_logica, 
    "-"
);
guardar_registro($estudios_dat, $nueva_linea);

# 2. Crear directorio del estudio
my $estudio_dir = File::Spec->catdir($base_dir, $id_paciente, $id_estudio);
unless (-d $estudio_dir) {
    make_path($estudio_dir) or do {
        print encode_json({ ok => 0, msg => "Error al crear la carpeta del estudio." });
        exit;
    };
}

# 3. Crear metadata.json inicial vacio
my $meta_path = File::Spec->catfile($estudio_dir, "metadata.json");
my $metadata = {
    id_estudio => $id_estudio,
    id_paciente => $id_paciente,
    estado => "creado",
    imagenes => [],
    metadatos => { equipo => "Generico" },
    observaciones => []
};

open(my $meta_fh, '>', $meta_path);
print $meta_fh JSON->new->utf8(1)->pretty(1)->encode($metadata);
close $meta_fh;

print encode_json({
    ok => 1,
    msg => "Estudio creado correctamente.",
    estudio => $metadata
});
