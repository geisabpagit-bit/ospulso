#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json decode_json);
use Encode qw(encode_utf8 decode_utf8);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $sd = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($sd->{session_ok} && $sd->{role} =~ /Administrador/i) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada o permisos insuficientes' });
    exit;
}

my $action = $q->param('action') || $q->param('accion') || 'get';
my $id_empresa = $sd->{id_empresa} || 0;
my $target_uid = decode_utf8($q->param('id_usuario') // $q->param('usuario') // '');
$target_uid =~ s/^\s+|\s+$//g;

# Cargar lista de módulos conocidos
my @modulos = (
    { id => 'pacientes',          nombre => 'Expediente Clínico / Pacientes', icono => 'bi-people-fill' },
    { id => 'agenda',             nombre => 'Agenda Médica y Citas',           icono => 'bi-calendar-event-fill' },
    { id => 'quirofano',          nombre => 'Tablero Quirófano / Hospital',    icono => 'bi-heart-pulse-fill' },
    { id => 'finanzas',           nombre => 'Finanzas y Caja Rápida',         icono => 'bi-cash-stack' },
    { id => 'servicios',          nombre => 'Catálogo de Servicios',           icono => 'bi-medical-services' },
    { id => 'productos',          nombre => 'Gestión de Productos / Farmacia', icono => 'bi-box-seam-fill' },
    { id => 'usuarios',           nombre => 'Gestión de Personal / Usuarios',  icono => 'bi-person-gear' },
    { id => 'reportes',           nombre => 'Analítica y Reportes',           icono => 'bi-bar-chart-line-fill' },
    { id => 'gestion_catalogos',  nombre => 'Gestión de Catálogos Org',       icono => 'bi-database-gear' },
    { id => 'tecnico',            nombre => 'Mantenimiento Técnico',          icono => 'bi-tools' },
    { id => 'reset_datos_org',    nombre => 'Reset Operativo Org',            icono => 'bi-arrow-counterclockwise' }
);

if ($action eq 'get') {
    unless ($target_uid) {
        print encode_json({ ok => JSON::false, msg => 'ID de usuario no proporcionado' });
        exit;
    }

    # Buscar usuario para obtener su rol actual y nombre
    my $usuarios_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    my $user_role = '';
    my $user_name = '';
    
    if (-e $usuarios_dat && open(my $uf, '<:encoding(UTF-8)', $usuarios_dat)) {
        while (my $l = <$uf>) {
            chomp $l;
            next if $l =~ /^\s*$/ || $l =~ /^#/;
            my @f = split(/!/, $l, -1);
            if (($f[0] // '') eq $target_uid || (lc($f[2] // '') eq lc($target_uid))) {
                $user_name = $f[1] // '';
                $user_role = $f[5] // '';
                $target_uid = $f[0] // $target_uid; # Normalizar ID exacto
                last;
            }
        }
        close $uf;
    }

    my $user_overrides = utils::permisos_utils::obtener_overrides_usuario_org($id_empresa, $target_uid);
    my $has_overrides = ($user_overrides && ref($user_overrides) eq 'HASH' && keys %$user_overrides) ? 1 : 0;
    
    my $matriz_roles = utils::permisos_utils::obtener_matriz_permisos_org($id_empresa);
    my $role_matrix = $matriz_roles->{$user_role} || {};

    print encode_json({
        ok => JSON::true,
        id_usuario => $target_uid,
        nombre => $user_name,
        rol => $user_role,
        has_overrides => $has_overrides,
        user_overrides => $user_overrides || {},
        role_matrix => $role_matrix,
        modulos => \@modulos
    });
    exit;
}

if ($action eq 'save') {
    unless ($target_uid) {
        print encode_json({ ok => JSON::false, msg => 'ID de usuario no proporcionado' });
        exit;
    }

    my $raw_payload = $q->param('payload') || $q->param('POSTDATA') || '';
    my $payload = eval { decode_json(encode_utf8($raw_payload)) } || eval { decode_json($raw_payload) };

    unless ($payload && ref($payload) eq 'HASH') {
        print encode_json({ ok => JSON::false, msg => 'Payload JSON no válido' });
        exit;
    }

    # Sanitizar estructura { MODULO => { C=>0|1, R=>0|1, U=>0|1, D=>0|1 } }
    my %clean_overrides = ();
    foreach my $mod_key (keys %$payload) {
        my $item = $payload->{$mod_key};
        next unless (ref($item) eq 'HASH');
        $clean_overrides{$mod_key} = {
            C => int($item->{C} // 0),
            R => int($item->{R} // 0),
            U => int($item->{U} // 0),
            D => int($item->{D} // 0)
        };
    }

    my $res = utils::permisos_utils::guardar_overrides_usuario_org($id_empresa, $target_uid, \%clean_overrides);
    if ($res->{ok}) {
        print encode_json({ ok => JSON::true, msg => 'Permisos excepcionales guardados exitosamente.' });
    } else {
        print encode_json({ ok => JSON::false, msg => $res->{msg} || 'Error al guardar excepciones.' });
    }
    exit;
}

if ($action eq 'reset') {
    unless ($target_uid) {
        print encode_json({ ok => JSON::false, msg => 'ID de usuario no proporcionado' });
        exit;
    }

    my $res = utils::permisos_utils::eliminar_overrides_usuario_org($id_empresa, $target_uid);
    if ($res->{ok}) {
        print encode_json({ ok => JSON::true, msg => 'Se han restablecido los permisos del usuario a la matriz de su rol.' });
    } else {
        print encode_json({ ok => JSON::false, msg => $res->{msg} || 'Error al restablecer permisos.' });
    }
    exit;
}

print encode_json({ ok => JSON::false, msg => 'Acción no reconocida' });
