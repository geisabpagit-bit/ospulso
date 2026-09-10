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
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $filename = $q->param('filename') // '';

if ($filename !~ /^ospulso_migration_[\d_]+\.zip$/) {
    print encode_json({ status => 'error', message => 'Nombre de archivo no válido.' });
    exit;
}

my $mig_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'migraciones', $filename);

if (-f $mig_path) {
    if (unlink($mig_path)) {
        print encode_json({ status => 'success', message => 'El paquete de migración fue eliminado exitosamente.' });
    } else {
        print encode_json({ status => 'error', message => "No se pudo eliminar el paquete: $!" });
    }
} else {
    print encode_json({ status => 'error', message => 'El archivo no existe o ya fue eliminado.' });
}
