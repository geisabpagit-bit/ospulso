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

    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my %roles_set = ();
    
    # 1. Cargar roles base canónicos dinámicamente desde dat/roles.dat
    my $roles_file = File::Spec->catfile($dat_dir, 'roles.dat');
    if (-e $roles_file && open(my $rf, '<:encoding(UTF-8)', $roles_file)) {
        <$rf>; # Saltar encabezado ROL|PUEDE_BUSCAR...
        while (my $line = <$rf>) {
            chomp $line;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            my ($rname) = split(/\|/, $line, -1);
            $rname =~ s/^\s+|\s+$//g;
            next unless length($rname);
            next if ($rname eq 'Administrador Global' || $rname eq 'Paciente'); # Roles de sistema/paciente externa
            $roles_set{$rname} = 1;
        }
        close $rf;
    }

    # Asegurar roles esenciales de organización
    $roles_set{'Administrador Organizacion'} = 1;
    $roles_set{'Medico'} = 1;
    $roles_set{'Recepcionista'} = 1;
    $roles_set{'Enfermeria'} = 1;

    my %conteo_usuarios = ();
    my %usuarios_por_rol = ();

    # 2. Cargar usuarios activos y relacionarlos con sus roles para la empresa activa
    my $usr_file = File::Spec->catfile($dat_dir, 'usuarios.dat');
    if (-e $usr_file) {
        my $users = leer_tabla($usr_file, '!');
        foreach my $u (@$users) {
            next unless @$u >= 7;
            my $u_id     = $u->[0] // '';
            my $u_nom    = $u->[1] // '';
            my $u_email  = $u->[2] // '';
            my $u_act    = $u->[4] // '1';
            my $rol_u    = $u->[5] // '';
            my $emp_u    = $u->[6] // '';

            next if ($u_id =~ /^id$/i); # Encabezado

            # Filtrar por empresa activa (o todas si id_empresa es 0)
            if ($rol_u && ($emp_u eq $id_empresa || $id_empresa eq '0' || $emp_u =~ /^0:/)) {
                $roles_set{$rol_u} = 1; # Incluir si existe un usuario con rol personalizado
                $conteo_usuarios{$rol_u} = ($conteo_usuarios{$rol_u} // 0) + 1;
                push @{$usuarios_por_rol{$rol_u}}, {
                    id => $u_id,
                    nombre => $u_nom,
                    correo => $u_email,
                    activo => $u_act
                };
            }
        }
    }

    # Inicializar conteos en 0 para roles sin usuarios
    foreach my $r (keys %roles_set) {
        $conteo_usuarios{$r} //= 0;
        $usuarios_por_rol{$r} //= [];
    }

    my @roles_list = sort keys %roles_set;

    print encode_json({
        ok => JSON::true,
        modulos => \@modulos,
        roles => \@roles_list,
        matriz => $matriz,
        conteo_usuarios => \%conteo_usuarios,
        usuarios_por_rol => \%usuarios_por_rol,
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
