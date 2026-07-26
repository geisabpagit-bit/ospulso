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

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Organizacion') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

use Encode qw(decode_utf8);

my $id_org_matriz = $sd->{id_empresa};

my $nombre      = decode_utf8($q->param('nombre')      // '');
my $correo      = lc(decode_utf8($q->param('correo')   // ''));
my $clave       = decode_utf8($q->param('clave')       // '');
my $rol         = decode_utf8($q->param('rol')         // '');
my $id_sucursal = decode_utf8($q->param('id_sucursal') // '');
my $id_espe     = decode_utf8($q->param('id_espe')     // '0');
my $id_subespe  = decode_utf8($q->param('id_subespe')  // '0');

$nombre =~ s/^\s+|\s+$//g;
$correo =~ s/^\s+|\s+$//g;
$clave  =~ s/^\s+|\s+$//g;


if (!$nombre || !$correo || !$clave || !$rol || !$id_sucursal) {
    print encode_json({ status => 'error', message => 'Todos los campos son obligatorios.' });
    exit;
}

if ($rol ne 'Medico' && $rol ne 'Recepcionista') {
    print encode_json({ status => 'error', message => 'Rol no válido.' });
    exit;
}

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');

# 1. Validar que la sucursal pertenezca a la Organización (Seguridad Multi-Tenant)
my $regs_negocios = leer_tabla($archivo_negocios, '\|');
my $sucursal_valida = 0;
if ($regs_negocios) {
    foreach my $r (@$regs_negocios) {
        if ($r->[0] eq $id_sucursal && $r->[2] eq $id_org_matriz) {
            $sucursal_valida = 1;
            last;
        }
    }
}

if (!$sucursal_valida) {
    print encode_json({ status => 'error', message => 'La sucursal seleccionada no es válida o no pertenece a tu organización.' });
    exit;
}

# 2. Validar que el correo no exista
my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
if ($regs_usuarios) {
    foreach my $r (@$regs_usuarios) {
        if (lc($r->[2] // '') eq $correo) {
            print encode_json({ status => 'error', message => 'El correo electrónico ya está registrado.' });
            exit;
        }
    }
}

# 3. Crear el usuario
my $id_nuevo = int(rand(999999999)) + 100000000;
my $hash = sha256_hex($clave);
my $extra_multi_tenant = "$id_org_matriz:$id_sucursal"; # EL BLINDAJE

my $registro_usuario = join("!", 
    $id_nuevo, 
    $nombre, 
    $correo, 
    $hash, 
    1, 
    $rol, 
    $extra_multi_tenant,
    $id_espe,
    $id_subespe
);

eval {
    use Fcntl qw(:flock);
    open(my $fh_usr, '>>:utf8', $archivo_usuarios) or die "usuarios: $!";
    flock($fh_usr, 2);
    print $fh_usr "$registro_usuario\n";
    close($fh_usr);
};

if ($@) {
    print encode_json({ status => 'error', message => 'Error al guardar el usuario: ' . $@ });
    exit;
}

print encode_json({ status => 'success' });
1;
