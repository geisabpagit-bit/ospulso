#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI::Carp qw(fatalsToBrowser);
BEGIN { eval "use cPanelUserConfig;"; }
use CGI;
use JSON::PP qw(encode_json decode_json);
use File::Basename;
use Encode qw(decode_utf8);
use lib '.';
use File::Path;

# Aumentar límite de POST a 50MB para DICOM/NIfTI
$CGI::POST_MAX = 50 * 1024 * 1024;
binmode STDOUT, ":utf8";

require 'check_session.pl';
my $session_data = check_session();
unless ($session_data->{session_ok}) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print encode_json({ok => 0, msg => "Sesión caducada."});
    exit;
}

my $q = $session_data->{q} || CGI->new;
if ($q->cgi_error) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print encode_json({ok => 0, msg => "Error: El archivo supera el tamaño permitido (50MB) o está corrupto."});
    exit;
}

# Parámetros
my $id_paciente = $q->param('id_paciente') || '';
my $modalidad   = decode_utf8($q->param('modalidad') || 'OTRO');
my $descripcion = decode_utf8($q->param('descripcion') || 'Estudio Médico');

if (!$id_paciente) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print encode_json({ok => 0, msg => "ID de paciente requerido."});
    exit;
}

# Procesar archivo
my $filehandle = $q->upload('archivo');
if (!$filehandle) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print encode_json({ok => 0, msg => "No se detectó ningún archivo."});
    exit;
}

# Preparar directorio
my $storage_dir = "dat/estudios/$id_paciente";
File::Path::make_path($storage_dir) unless -d $storage_dir;

# Sanitizar nombre
my $filename = $filehandle;
my ($nombre_base, $ruta, $extension) = fileparse($filename, qr/\.[^.]*/);
$nombre_base =~ s/[^a-zA-Z0-9_\-]/_/g;
my $safe_filename = time() . "_" . $nombre_base . $extension;
my $file_path = "$storage_dir/$safe_filename";

# Guardar archivo
open(my $out, '>', $file_path) or die "Cannot open $file_path: $!";
binmode $out;
my $size = 0;
while (my $bytes = read($filehandle, my $buffer, 4096)) {
    print $out $buffer;
    $size += $bytes;
}
close($out);

# Guardar metadatos en estudios.dat
# Formato: ID_ESTUDIO|ID_PACIENTE|FECHA|MODALIDAD|DESCRIPCION|RUTA_ARCHIVO|SIZE_BYTES
my $id_estudio = time();
my $fecha_estudio = sprintf("%04d-%02d-%02d", (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3]);

open(my $fh, '>>:encoding(UTF-8)', 'dat/estudios.dat');
my $safe_desc = $descripcion; 
$safe_desc =~ s/\|/ /g; 
$safe_desc =~ s/\r?\n/ /g;

print $fh "$id_estudio|$id_paciente|$fecha_estudio|$modalidad|$safe_desc|$file_path|$size\n";
close $fh;

# Respuesta JSON
print "Content-Type: application/json; charset=UTF-8\n\n";
print encode_json({
    ok => 1, 
    msg => "Estudio cargado y procesado exitosamente.",
    data => {
        id_estudio => $id_estudio,
        archivo => $safe_filename
    }
});
