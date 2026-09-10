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
use File::Basename;
use POSIX qw(strftime);
use FindBin;
use lib '..';

# Evitar límites pequeños en subidas
$CGI::POST_MAX = 1024 * 1024 * 50; # 50 MB max
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
my $notas = $q->param('notas') || '';
my $id_estudio = $q->param('id_estudio') || '';
my $modalidad = $q->param('modalidad') || '';
my $upload_fh = $q->upload('archivo_estudio');

if (!$id_paciente || !$upload_fh) {
    print encode_json({ ok => 0, msg => "Faltan datos obligatorios (Paciente o Archivo)." });
    exit;
}

my $base_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'estudiosRX');
my $estudios_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');

# 1. Determinar ID de estudio (Nuevo o Existente)
if (!$id_estudio) {
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
    $id_estudio = $max_id + 1;

    # Modalidad inferida
    if (!$modalidad) {
        $modalidad = 'OT';
        $modalidad = 'RX' if $nombre_estudio =~ /rayos x|rx|radiograf/i;
        $modalidad = 'US' if $nombre_estudio =~ /ultrasonido|eco/i;
        $modalidad = 'MRI' if $nombre_estudio =~ /resonancia|mri/i;
        $modalidad = 'CT' if $nombre_estudio =~ /tomograf|ct/i;
    }

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
}

# 2. Crear directorio del estudio
my $estudio_dir = File::Spec->catdir($base_dir, $id_paciente, $id_estudio);
unless (-d $estudio_dir) {
    make_path($estudio_dir) or do {
        print encode_json({ ok => 0, msg => "Error al crear la carpeta del estudio." });
        exit;
    };
}

# 3. Guardar archivo
my $filename = $q->param('archivo_estudio');
my ($name, $path, $ext) = fileparse($filename, qr/\.[^.]*/);
$name =~ s/[^A-Za-z0-9_-]/_/g;
$ext = lc($ext);
$ext = '.png' if $ext eq '';

my $timestamp = time();
my $new_filename = "${name}_${timestamp}${ext}";
my $filepath = File::Spec->catfile($estudio_dir, $new_filename);

open(my $out_fh, '>', $filepath) or do {
    print encode_json({ ok => 0, msg => "No se pudo guardar la imagen." });
    exit;
};
binmode $out_fh;
while (my $bytesread = read($upload_fh, my $buffer, 1024)) {
    print $out_fh $buffer;
}
close $out_fh;

my $size_bytes = -s $filepath;
my $size_str = "$size_bytes B";
if ($size_bytes > 1024 * 1024) {
    $size_str = sprintf("%.2f MB", $size_bytes / (1024 * 1024));
} elsif ($size_bytes > 1024) {
    $size_str = sprintf("%d KB", int($size_bytes / 1024));
}

# 4. Actualizar metadata.json
my $meta_path = File::Spec->catfile($estudio_dir, "metadata.json");
my $metadata = {
    id_estudio => $id_estudio,
    id_paciente => $id_paciente,
    estado => "en_edicion",
    imagenes => [],
    metadatos => { equipo => "Generico" },
    observaciones => []
};

if (-e $meta_path) {
    open(my $fh, '<', $meta_path);
    local $/;
    my $json_text = <$fh>;
    close $fh;
    eval {
        $metadata = JSON->new->utf8(1)->decode($json_text);
    };
    if ($@) {
        # Silently fallback to empty array if decoding fails
        print STDERR "Warning: Failed to decode metadata.json for estudio $id_estudio: $@\n";
    }
}

push @{$metadata->{imagenes}}, {
    id_imagen => "img_${timestamp}",
    nombre_archivo => $new_filename,
    ruta => "dat/estudiosRX/${id_paciente}/${id_estudio}/${new_filename}",
    fecha_subida => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime($timestamp)),
    size => $size_str
};

open(my $meta_fh, '>', $meta_path);
print $meta_fh JSON->new->utf8(1)->pretty(1)->encode($metadata);
close $meta_fh;

print encode_json({
    ok => 1,
    msg => "Imagen agregada correctamente al estudio.",
    estudio => $metadata
});
