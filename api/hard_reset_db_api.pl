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

my $dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');

# Hash SHA-256 de "admin123"
my $admin_hash = "240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9";

my %archivos = (
    'usuarios.dat' => "id!nombre!correo!clave!activo!rol!ID_negocio\n1!Administrador Global!admin\@ospulso.com!$admin_hash!1!Administrador Global!0:0\n",
    'negocios.dat' => "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud\n",
    'citas.dat' => "ID_CITA|ID_MEDICO|ID_PACIENTE|FECHA|HORA_INICIO|HORA_FIN|TIPO_CONSULTA|NOTAS|ESTADO|EXTRA\n",
    'pacientes.dat' => "ID_PACIENTE|ID_MEDICO|NOMBRE_COMPLETO|RFC|CURP|CORREO|FECHA_NACIMIENTO|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO\n",
    'estado_cuenta.dat' => "ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS\n",
    'gastos.dat' => "ID_GASTO|CONCEPTO|MONTO|FECHA|CATEGORIA|SUBCATEGORIA|METODO_PAGO|ESTADO|COMPROBANTE|ID_MEDICO\n",
    'negocios_config.dat' => "ID_NEGOCIO|CLAVE|VALOR\n",
    'tokens.dat' => "\n",
    'id_cat.counter' => "0\n",
    'id_subcat.counter' => "0\n",
    'id_subcat3.counter' => "0\n",
    'id_gasto.counter' => "0\n",
    'contador_pacientes.dat' => "0\n",
    'contador_registro_inicial.dat' => "0\n"
);

eval {
    use Fcntl qw(:flock);
    foreach my $archivo (keys %archivos) {
        my $ruta = File::Spec->catfile($dir, $archivo);
        open(my $fh, '>:utf8', $ruta) or die "Error abriendo $archivo: $!";
        flock($fh, 2);
        print $fh $archivos{$archivo};
        close($fh);
    }
};

if ($@) {
    print encode_json({ status => 'error', message => "Error en reseteo: $@" });
    exit;
}

print encode_json({ status => 'success', message => 'Base de datos operativa reiniciada correctamente.' });
1;
