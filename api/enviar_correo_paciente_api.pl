#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI::Carp qw(fatalsToBrowser);
BEGIN { eval "use cPanelUserConfig;"; }
use CGI;
use JSON::PP qw(encode_json decode_json);
use File::Temp qw(tempdir);
use File::Basename;
use Encode qw(decode_utf8);
use lib '..';

my $has_mime_lite = eval "use MIME::Lite; 1;";

# Aumentar límite de POST (aprox 15MB)
$CGI::POST_MAX = 15 * 1024 * 1024;

# Forzamos STDOUT a utf8
binmode STDOUT, ":utf8";

require '../auth/check_session.pl';
my $session_data = check_session();
unless ($session_data->{session_ok}) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Sesión caducada. Por favor recargue la página."});
    exit;
}

my $q = $session_data->{q} || CGI->new;
my $error_cgi = $q->cgi_error;
if ($error_cgi) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Error interno: El archivo supera el tamaño permitido o está corrupto."});
    exit;
}

# --- Extracción de Parámetros Metadatos ---
my $para   = decode_utf8($q->param('para') || '');
my $asunto = decode_utf8($q->param('asunto') || 'Información de la Clínica');
my $cuerpo = decode_utf8($q->param('cuerpo') || 'Se adjunta la documentación clínica solicitada.');
my $id_paciente = $q->param('id_paciente') || '';

unless ($para =~ /^[^\s@]+@[^\s@]+\.[^\s@]+$/) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "El destinatario indicado no es un correo válido ($para)."});
    exit;
}

# --- Cuerpo HTML Base Estético ---
my $cuerpo_html = qq{
<html>
  <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; border: 1px solid #ddd; padding: 20px;">
      <h2 style="color: #174975;">$asunto</h2>
      <div style="margin: 20px 0; background-color: #f8f9ff; padding: 15px; border-radius: 8px;">
        <p>$cuerpo</p>
      </div>
      <hr>
      <p style="font-size: 0.9em; color: #777;">Este es un mensaje automático de Software Dental Mexicano.</p>
    </div>
  </body>
</html>
};

# --- Inicialización del Motor MIME ---
unless ($has_mime_lite) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "El módulo MIME::Lite no está instalado en este servidor (XAMPP Local). Funcionalidad de envíos deshabilitada."});
    exit;
}

my $msg = MIME::Lite->new(
    From    => 'administracion@sdm.pdigitalesm.com',
    To      => $para,
    Subject => $asunto,
    Type    => 'multipart/mixed'
);

$msg->attach(
    Type     => 'text/html; charset=UTF-8',
    Data     => $cuerpo_html,
    Encoding => 'quoted-printable'
);

# --- Procesar Archivos Adjuntos Multipart ---
my @files = $q->upload('adjuntos');
my $persistent_dir = "";
my $nombres_adjuntos = "";
if ($id_paciente) {
    require File::Path;
    $persistent_dir = "../dat/adjuntos_crm/$id_paciente";
    File::Path::make_path($persistent_dir) unless -d $persistent_dir;
}
my $tempdir = $persistent_dir ? $persistent_dir : tempdir(CLEANUP => 1); # Carpeta efímera de respaldo
my $adjuntos_usados = 0;

if (@files) {
    foreach my $filehandle (@files) {
        my $filename = $filehandle; # CGI upload retorna el handler que como string es el filename
        # Sanitizar nombre del archivo
        my ($nombre_base, $ruta, $extension) = fileparse($filename, qr/\.[^.]*/);
        $nombre_base =~ s/[^a-zA-Z0-9_\-]/_/g; # Sanitize
        my $safe_filename = $nombre_base . $extension;
        my $temp_path = "$tempdir/$safe_filename";
        
        # Copiar al OS Temporal
        open(my $out, '>', $temp_path) or next;
        binmode $out;
        while (my $bytes = read($filehandle, my $buffer, 4096)) {
            print $out $buffer;
        }
        close($out);
        
        # Mapear Tipos MIME Nativos (Básico)
        my $mime_type = 'application/octet-stream';
        $mime_type = 'application/pdf' if $extension =~ /\.pdf$/i;
        $mime_type = 'image/jpeg' if $extension =~ /\.jpe?g$/i;
        $mime_type = 'image/png' if $extension =~ /\.png$/i;
        $mime_type = 'application/msword' if $extension =~ /\.doc$/i;
        $mime_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' if $extension =~ /\.docx$/i;
        $mime_type = 'application/vnd.ms-excel' if $extension =~ /\.xls$/i;
        $mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' if $extension =~ /\.xlsx$/i;

        # Acoplar al correo
        $msg->attach(
            Type        => $mime_type,
            Path        => $temp_path,
            Filename    => $safe_filename,
            Disposition => 'attachment'
        );
        $adjuntos_usados++;
        $nombres_adjuntos .= "$safe_filename|";
    }
}

# --- Intento de Envio ---
eval {
    $msg->send;
};

if ($@) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Fallo de enrutador SMTP: $@"});
} else {
    # Guardar bitácora si hay ID Paciente
    if ($id_paciente) {
        my $fecha_envio = sprintf("%04d-%02d-%02d %02d:%02d:%02d", (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3], (localtime)[2], (localtime)[1], (localtime)[0]);
        my $id_correo = time();
        $nombres_adjuntos =~ s/\|$//; # Quitar ultimo pipe
        
        # ID_CORREO|ID_PACIENTE|FECHA_ENVIO|ASUNTO|CUERPO|ARCHIVOS_ADJUNTOS
        open(my $fh, '>>:encoding(UTF-8)', '../dat/historial_correos.dat');
        my $safe_asunto = $asunto; $safe_asunto =~ s/\|/ /g; $safe_asunto =~ s/\r?\n/<br>/g;
        my $safe_cuerpo = $cuerpo; $safe_cuerpo =~ s/\|/ /g; $safe_cuerpo =~ s/\r?\n/<br>/g;
        print $fh "$id_correo|$id_paciente|$fecha_envio|$safe_asunto|$safe_cuerpo|$nombres_adjuntos\n";
        close $fh;
    }

    my $extra = $adjuntos_usados > 0 ? " Llevaba empacado(s) $adjuntos_usados archivo(s)." : "";
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 1, msg => "Correo enviado sin incidencias a $para.$extra"});
}
