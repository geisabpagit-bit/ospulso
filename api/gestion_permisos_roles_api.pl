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

my $accion = $q->param('accion') || 'get_matrix';
my $id_empresa = $sd->{id_empresa} || 0;

if ($accion eq 'get_matrix') {
    my $matriz = utils::permisos_utils::obtener_matriz_permisos_org($id_empresa);
    
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

    # Cargar lista de roles de la organización desde usuarios.dat / roles.dat
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my %roles_set = ();
    $roles_set{'Administrador Organizacion'} = 1;
    $roles_set{'Medico'} = 1;
    $roles_set{'Recepcionista'} = 1;
    $roles_set{'Enfermeria'} = 1;

    # Cargar roles adicionales de usuarios de esta empresa
    my $usr_file = File::Spec->catfile($dat_dir, 'usuarios.dat');
    if (-e $usr_file) {
        my $users = leer_tabla($usr_file, '!');
        foreach my $u (@$users) {
            next unless @$u >= 7;
            my $rol_u = $u->[5] // '';
            my $emp_u = $u->[6] // '';
            if ($rol_u && ($emp_u eq $id_empresa || $id_empresa eq '0')) {
                $roles_set{$rol_u} = 1;
            }
        }
    }

    my @roles_list = sort keys %roles_set;

    print encode_json({
        ok => JSON::true,
        modulos => \@modulos,
        roles => \@roles_list,
        matriz => $matriz,
        id_empresa => $id_empresa,
        ruta_archivo => utils::permisos_utils::obtener_ruta_permisos_org($id_empresa)
    });
    exit;

} elsif ($accion eq 'save_matrix') {
    my $matrix_json = $q->param('matriz_json') || '{}';
    my $matriz_data = {};
    eval { $matriz_data = decode_json($matrix_json); };
    if ($@) {
        eval { $matriz_data = decode_json(encode_utf8($matrix_json)); };
    }

    if (ref($matriz_data) ne 'HASH' || !keys %$matriz_data) {
        print encode_json({ ok => JSON::false, msg => 'Formato de datos no válido' });
        exit;
    }

    my $res = utils::permisos_utils::guardar_matriz_permisos_org($id_empresa, $matriz_data);

    if ($res->{ok}) {
        print encode_json({ ok => JSON::true, msg => 'Matriz de permisos guardada exitosamente' });
    } else {
        print encode_json({ ok => JSON::false, msg => $res->{msg} || 'No se pudo guardar la matriz' });
    }
    exit;
}

print encode_json({ ok => JSON::false, msg => 'Acción no reconocida' });
1;
