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
my $id_espe         = decode_utf8($q->param('id_espe')         // '0');
my $id_subespe      = decode_utf8($q->param('id_subespe')      // '0');

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

if ($rol eq 'Recepcionista') {
    $id_espe    = '0';
    $id_subespe = '0';
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
my $nombre_duplicado = 0;

if ($regs_usuarios) {
    foreach my $r (@$regs_usuarios) {
        next if @$r < 3;
        if ($r->[0] ne $id_usuario_edit) {
            my $nom_exist = lc($r->[1] // '');
            my $cor_exist = lc($r->[2] // '');
            $nom_exist =~ s/^\s+|\s+$//g;
            $cor_exist =~ s/^\s+|\s+$//g;

            if ($cor_exist eq $correo) {
                $correo_duplicado = 1;
            }
            if ($nom_exist eq lc($nombre)) {
                $nombre_duplicado = 1;
            }
        }
    }

    if ($correo_duplicado) {
        print encode_json({ status => 'error', message => 'El correo electrónico ya está registrado en otra cuenta.' });
        exit;
    }
    if ($nombre_duplicado) {
        print encode_json({ status => 'error', message => 'El nombre de usuario ya está registrado en otra cuenta.' });
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

            # Si el usuario editado es el mismo usuario autenticado en la sesión actual, actualizar sesión en vivo
            my $uid_actual = lc($sd->{uid} // '');
            my $id_actual  = $sd->{id_registro} // $sd->{id_medico} // '';
            if (($id_actual && $id_actual eq $id_usuario_edit) || ($uid_actual && $uid_actual eq lc($r->[2] // ''))) {
                if ($sd->{session}) {
                    $sd->{session}->param('uid', $correo);
                    $sd->{session}->param('usuario', $nombre);
                    $sd->{session}->param('role', $rol);
                }
            }

            $r->[1] = $nombre;
            $r->[2] = $correo;
            $r->[5] = $rol;
            $r->[6] = "$id_org_matriz:$id_sucursal";
            $r->[7] = $id_espe;
            $r->[8] = $id_subespe;

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
    my $header = "id!nombre!correo!clave!activo!rol!ID_negocio!ID_ESPE!ID_SUBESPE";
    actualizar_archivo($archivo_usuarios, $header, \@nuevas_lineas);
};

if ($@) {
    print encode_json({ status => 'error', message => 'Error al actualizar usuario: ' . $@ });
    exit;
}

if ($sd->{session}) {
    eval { $sd->{session}->flush(); };
}

print encode_json({ status => 'success', message => 'Usuario actualizado correctamente.' });
1;
