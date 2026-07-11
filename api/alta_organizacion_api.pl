#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use Digest::SHA qw(sha256_hex);
use FindBin;
use File::Spec;
use Time::Local;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || ($sd->{role} ne 'Ejecutivo Ventas' && $sd->{role} ne 'Administrador Global')) {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $id_vendedor = $sd->{id_medico};

my $nombre_org   = $q->param('nombre_org')   // '';
my $rfc_org      = $q->param('rfc_org')      // '';
my $naturaleza_juridica = $q->param('naturaleza_juridica') // '';
my $tipo_organizacion   = $q->param('tipo_organizacion') // '';
my $reporta_institucion = $q->param('reporta_institucion') // '';
my @instituciones = $q->multi_param('institucion[]');
my @capacidades   = $q->multi_param('capacidades[]');

my $nombre_admin = $q->param('nombre_admin') // '';
my $correo_admin = lc($q->param('correo_admin') // '');
my $clave_admin  = $q->param('clave_admin')  // '';

$nombre_org   =~ s/^\s+|\s+$//g;
$nombre_admin =~ s/^\s+|\s+$//g;
$correo_admin =~ s/^\s+|\s+$//g;
$clave_admin  =~ s/^\s+|\s+$//g;

if (!$nombre_org || !$nombre_admin || !$correo_admin || !$clave_admin || !$tipo_organizacion || !$naturaleza_juridica) {
    print encode_json({ status => 'error', message => 'Faltan datos obligatorios.' });
    exit;
}

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $archivo_config   = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');

# Validar que el correo no exista en usuarios
my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
if ($regs_usuarios) {
    foreach my $r (@$regs_usuarios) {
        if (lc($r->[2] // '') eq $correo_admin) {
            print encode_json({ status => 'error', message => 'El correo electrónico del administrador ya está en uso.' });
            exit;
        }
    }
}

# --- Paso 1: Crear la Organización (negocios.dat) ---
# Generar ID de organización
my $id_org = int(rand(999999)) + 100000;

# Fechas
my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
my $fecha_inicio = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);

# Suscripción inicial de 1 año
my $time_1y = time + (365 * 24 * 60 * 60);
my ($s2,$m2,$h2,$md2,$mo2,$y2) = localtime($time_1y);
my $fecha_fin = sprintf("%04d-%02d-%02d", $y2+1900, $mo2+1, $md2);

# 22 campos de negocios.dat
my @campos_negocio = (
    $id_org,         # 1. ID
    $nombre_org,     # 2. NOMBRE_NEGOCIO
    "0",             # 3. ID_MATRIZ (Es raíz)
    "1",             # 4. Activo
    $fecha_inicio,   # 5. inicio_suscripcion
    $fecha_fin,      # 6. fin_suscripcion
    "",              # 7. domicilio
    "",              # 8. telefono
    $correo_admin,   # 9. contacto_email
    "",              # 10. logo_url
    $rfc_org,        # 11. rfc
    "",              # 12. razon_social
    "",              # 13. id_tienda
    $id_vendedor,    # 14. id_vendedor
    "", "", "", "", "", "", "", "" # Resto de campos geográficos/clues (8 vacíos)
);

my $registro_negocio = join("|", @campos_negocio);


# --- Paso 2: Crear Administrador de Organización (usuarios.dat) ---
my $id_admin_nuevo = int(rand(999999999)) + 100000000;
my $hash = sha256_hex($clave_admin);
my $extra_multi_tenant = "$id_org:0"; # ¡LA CLAVE DE LA ARQUITECTURA!

my $registro_usuario = join("!", 
    $id_admin_nuevo, 
    $nombre_admin, 
    $correo_admin, 
    $hash, 
    1, 
    'Administrador Organizacion', 
    $extra_multi_tenant
);

# --- Paso 3: Guardar Configuración SaaS (negocios_config.dat) ---
my @config_lines = ();
push @config_lines, "$id_org|TIPO_ORGANIZACION|$tipo_organizacion";
push @config_lines, "$id_org|NATURALEZA_JURIDICA|$naturaleza_juridica";
push @config_lines, "$id_org|REPORTE_INSTITUCION|$reporta_institucion";
foreach my $inst (@instituciones) {
    push @config_lines, "$id_org|INSTITUCION|$inst";
}
foreach my $cap (@capacidades) {
    push @config_lines, "$id_org|CAPACIDAD|$cap";
}

# --- Escribir a archivos ---
eval {
    use Fcntl qw(:flock);

    # Guardar Negocio
    open(my $fh_neg, '>>:utf8', $archivo_negocios) or die "negocios: $!";
    flock($fh_neg, 2);
    print $fh_neg "$registro_negocio\n";
    close($fh_neg);

    # Guardar Usuario
    open(my $fh_usr, '>>:utf8', $archivo_usuarios) or die "usuarios: $!";
    flock($fh_usr, 2);
    print $fh_usr "$registro_usuario\n";
    close($fh_usr);

    # Guardar Configuración SaaS
    open(my $fh_cfg, '>>:utf8', $archivo_config) or die "configuracion: $!";
    flock($fh_cfg, 2);
    foreach my $linea (@config_lines) {
        print $fh_cfg "$linea\n";
    }
    close($fh_cfg);
};

if ($@) {
    print encode_json({ status => 'error', message => 'No se pudo guardar la organización: ' . $@ });
    exit;
}

print encode_json({ status => 'success', id_organizacion => $id_org });
1;
