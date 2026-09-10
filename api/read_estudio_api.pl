#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use File::Spec;
use File::Basename;
use FindBin;
use lib '..';

my $q = CGI->new;

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
my $session_data = check_session();
if (!$session_data->{session_ok}) {
    print $q->header(-status => 403, -type => 'text/plain');
    print "Acceso denegado.";
    exit;
}

my $ruta = $q->param('ruta') || '';

if (!$ruta || $ruta !~ /^dat\/estudiosRX\/(\d+)\/(.+)$/) {
    print $q->header(-status => 400, -type => 'text/plain');
    print "Ruta invalida o malformada.";
    exit;
}

# Solo el propio paciente (si fuera portal) o el médico puede acceder.
# En este sistema el médico tiene acceso a todo.

my $abs_path = File::Spec->catfile($FindBin::Bin, '..', $ruta);

if (!-e $abs_path || !-f $abs_path) {
    print $q->header(-status => 404, -type => 'text/plain');
    print "Archivo no encontrado.";
    exit;
}

# Usamos un hash simple en lugar de MIME::Types para mayor compatibilidad en Hostgator
my %mime_types = (
    'jpg'  => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'png'  => 'image/png',
    'gif'  => 'image/gif',
    'dcm'  => 'application/dicom',
    'pdf'  => 'application/pdf',
);

my ($ext) = $abs_path =~ /\.([^.]+)$/;
$ext = lc($ext) if $ext;
my $mime = $mime_types{$ext} || 'application/octet-stream';

my $size = -s $abs_path;

print $q->header(
    -type => $mime,
    -Content_length => $size,
    -access_control_allow_origin => '*'
);

open(my $fh, '<', $abs_path) or die "No se puede leer archivo";
binmode $fh;
my $buffer;
while (read($fh, $buffer, 10240)) {
    print $buffer;
}
close $fh;
