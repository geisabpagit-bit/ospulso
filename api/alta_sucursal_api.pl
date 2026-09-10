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

if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Organizacion') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $id_org_matriz   = $sd->{id_empresa};

my $nombre_sucursal = $q->param('nombre_sucursal') // '';
my $telefono        = $q->param('telefono')        // '';
my $domicilio       = $q->param('domicilio')       // '';

$nombre_sucursal =~ s/^\s+|\s+$//g;

if (!$nombre_sucursal) {
    print encode_json({ status => 'error', message => 'El nombre de la sucursal es obligatorio.' });
    exit;
}

my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');

# Generar ID de sucursal
my $id_sucursal = int(rand(999999)) + 200000;

# Fechas
my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
my $fecha_inicio = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
my $fecha_fin    = "2099-12-31"; # Sucursales dependen de la matriz

# 22 campos de negocios.dat
my @campos_negocio = (
    $id_sucursal,    # 1. ID
    $nombre_sucursal,# 2. NOMBRE_NEGOCIO
    $id_org_matriz,  # 3. ID_MATRIZ (Es hija)
    "1",             # 4. Activo
    $fecha_inicio,   # 5. inicio_suscripcion
    $fecha_fin,      # 6. fin_suscripcion
    $domicilio,      # 7. domicilio
    $telefono,       # 8. telefono
    "",              # 9. contacto_email
    "",              # 10. logo_url
    "",              # 11. rfc
    "",              # 12. razon_social
    "",              # 13. id_tienda
    "",              # 14. id_vendedor
    "", "", "", "", "", "", "", "" # Resto vacíos
);

my $registro_sucursal = join("|", @campos_negocio);

eval {
    use Fcntl qw(:flock);
    open(my $fh_neg, '>>:utf8', $archivo_negocios) or die "negocios: $!";
    flock($fh_neg, 2);
    print $fh_neg "$registro_sucursal\n";
    close($fh_neg);
};

if ($@) {
    print encode_json({ status => 'error', message => 'Error al guardar la sucursal: ' . $@ });
    exit;
}

print encode_json({ status => 'success', id_sucursal => $id_sucursal });
1;
