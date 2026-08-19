#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;

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

my $backup_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'backups', $filename);

if (!-f $backup_path) {
    print encode_json({ status => 'error', message => 'El archivo de respaldo no existe o ya fue eliminado.' });
    exit;
}

if (unlink $backup_path) {
    print encode_json({ status => 'success', message => 'Respaldo eliminado correctamente.' });
} else {
    print encode_json({ status => 'error', message => "No se pudo eliminar el archivo: $!" });
}
