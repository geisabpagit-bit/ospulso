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
use utils::db_manager qw(leer_tabla actualizar_archivo);

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Organizacion') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

use Encode qw(decode_utf8);

my $id_org_matriz = $sd->{id_empresa};

my $id_usuario_edit = decode_utf8($q->param('id_usuario_edit') // '');
my $nombre          = decode_utf8($q->param('nombre')          // '');
my $correo          = lc(decode_utf8($q->param('correo')       // ''));
my $clave           = decode_utf8($q->param('clave')           // '');
my $rol             = decode_utf8($q->param('rol')             // '');
my $id_sucursal     = decode_utf8($q->param('id_sucursal')     // '');

$nombre          =~ s/^\s+|\s+$//g;
$correo          =~ s/^\s+|\s+$//g;
$clave           =~ s/^\s+|\s+$//g;
$id_usuario_edit =~ s/^\s+|\s+$//g;

if (!$id_usuario_edit || !$nombre || !$correo || !$rol || !$id_sucursal) {
    print encode_json({ status => 'error', message => 'Todos los campos son obligatorios.' });
    exit;
}

if ($rol ne 'Medico' && $rol ne 'Recepcionista') {
    print encode_json({ status => 'error', message => 'Rol no válido.' });
    exit;
}

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');

# 1. Validar que la sucursal pertenezca a la Organización
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
    print encode_json({ status => 'error', message => 'La sucursal seleccionada no pertenece a tu organización.' });
    exit;
}

# 2. Modificar el usuario
my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
my @nuevas_lineas;
my $encontrado = 0;
my $correo_duplicado = 0;

if ($regs_usuarios) {
    foreach my $r (@$regs_usuarios) {
        if ($r->[0] ne $id_usuario_edit && lc($r->[2] // '') eq $correo) {
            $correo_duplicado = 1;
        }
    }

    if ($correo_duplicado) {
        print encode_json({ status => 'error', message => 'El correo electrónico ya está registrado en otra cuenta.' });
        exit;
    }

    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        if ($r->[0] eq $id_usuario_edit) {
            # Verificar que este usuario pertenece a mi organización
            my $extra = $r->[6];
            my ($org_id, $suc_id) = split(/:/, $extra);
            
            if ($org_id ne $id_org_matriz) {
                print encode_json({ status => 'error', message => 'No tienes permiso para editar este usuario.' });
                exit;
            }

            $r->[1] = $nombre;
            $r->[2] = $correo;
            $r->[5] = $rol;
            $r->[6] = "$id_org_matriz:$id_sucursal";

            if ($clave ne '') {
                $r->[3] = sha256_hex($clave);
            }
            $encontrado = 1;
        }
        push @nuevas_lineas, join("!", @$r);
    }
}

if (!$encontrado) {
    print encode_json({ status => 'error', message => 'Usuario no encontrado.' });
    exit;
}

eval {
    my $header = "id!nombre!correo!clave!activo!rol!ID_negocio";
    actualizar_archivo($archivo_usuarios, $header, \@nuevas_lineas);
};

if ($@) {
    print encode_json({ status => 'error', message => 'Error al actualizar usuario: ' . $@ });
    exit;
}

print encode_json({ status => 'success', message => 'Usuario actualizado correctamente.' });
1;
