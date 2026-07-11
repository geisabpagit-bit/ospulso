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
use utils::db_manager qw(leer_tabla actualizar_archivo);

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || ($sd->{role} ne 'Ejecutivo Ventas' && $sd->{role} ne 'Administrador Global')) {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $id_vendedor = $sd->{id_usuario};
my $action = $q->param('action') || 'create';

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $archivo_config   = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');

# ==========================================
# CREATE
# ==========================================
if ($action eq 'create') {
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

    # Generar ID de organización
    my $id_org = int(rand(999999)) + 100000;

    # Fechas
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $fecha_inicio = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $time_1y = time + (365 * 24 * 60 * 60);
    my ($s2,$m2,$h2,$md2,$mo2,$y2) = localtime($time_1y);
    my $fecha_fin = sprintf("%04d-%02d-%02d", $y2+1900, $mo2+1, $md2);

    # 22 campos de negocios.dat
    my @campos_negocio = (
        $id_org, $nombre_org, "0", "1", $fecha_inicio, $fecha_fin, "", "", $correo_admin, "", $rfc_org, "", "", $id_vendedor, "", "", "", "", "", "", "", ""
    );
    my $registro_negocio = join("|", @campos_negocio);

    # Crear Administrador de Organización (usuarios.dat)
    my $id_admin_nuevo = int(rand(999999999)) + 100000000;
    my $hash = sha256_hex($clave_admin);
    my $extra_multi_tenant = "$id_org:0";
    my $registro_usuario = join("!", $id_admin_nuevo, $nombre_admin, $correo_admin, $hash, 1, 'Administrador Organizacion', $extra_multi_tenant);

    # Configuración SaaS
    my @config_lines = ();
    push @config_lines, "$id_org|TIPO_ORGANIZACION|$tipo_organizacion";
    push @config_lines, "$id_org|NATURALEZA_JURIDICA|$naturaleza_juridica";
    push @config_lines, "$id_org|REPORTE_INSTITUCION|$reporta_institucion";
    foreach my $inst (@instituciones) { push @config_lines, "$id_org|INSTITUCION|$inst"; }
    foreach my $cap (@capacidades) { push @config_lines, "$id_org|CAPACIDAD|$cap"; }

    eval {
        use Fcntl qw(:flock);
        open(my $fh_neg, '>>:utf8', $archivo_negocios) or die "negocios: $!";
        flock($fh_neg, 2); print $fh_neg "$registro_negocio\n"; close($fh_neg);

        open(my $fh_usr, '>>:utf8', $archivo_usuarios) or die "usuarios: $!";
        flock($fh_usr, 2); print $fh_usr "$registro_usuario\n"; close($fh_usr);

        open(my $fh_cfg, '>>:utf8', $archivo_config) or die "config: $!";
        flock($fh_cfg, 2);
        foreach my $linea (@config_lines) { print $fh_cfg "$linea\n"; }
        close($fh_cfg);
    };

    if ($@) {
        print encode_json({ status => 'error', message => 'Error: ' . $@ });
        exit;
    }
    print encode_json({ status => 'success', id_organizacion => $id_org });
    exit;
}

# ==========================================
# READ
# ==========================================
if ($action eq 'read') {
    my $id_org = $q->param('id_org') // '';
    if (!$id_org) { print encode_json({status=>'error', message=>'ID requerido'}); exit; }

    my %data = ();
    
    # Leer Negocio
    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    foreach my $r (@$regs_negocios) {
        next if @$r < 22;
        if ($r->[0] eq $id_org) {
            $data{nombre_org} = $r->[1];
            $data{rfc_org} = $r->[10];
            last;
        }
    }

    # Leer Config
    my $regs_config = leer_tabla($archivo_config, '\|');
    $data{instituciones} = [];
    $data{capacidades} = [];
    foreach my $r (@$regs_config) {
        if ($r->[0] eq $id_org) {
            my $key = $r->[1];
            my $val = $r->[2] // '';
            if ($key eq 'TIPO_ORGANIZACION') { $data{tipo_organizacion} = $val; }
            elsif ($key eq 'NATURALEZA_JURIDICA') { $data{naturaleza_juridica} = $val; }
            elsif ($key eq 'REPORTE_INSTITUCION') { $data{reporta_institucion} = $val; }
            elsif ($key eq 'INSTITUCION') { push @{$data{instituciones}}, $val; }
            elsif ($key eq 'CAPACIDAD') { push @{$data{capacidades}}, $val; }
        }
    }

    # Leer Usuario (Dueño)
    my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        my $multi_tenant = $r->[6];
        # Extraer id negocio "org:suc"
        my ($u_org, $u_suc) = split(/:/, $multi_tenant);
        if ($r->[5] eq 'Administrador Organizacion' && defined $u_org && $u_org eq $id_org && $r->[4] eq '1') {
            $data{nombre_admin} = $r->[1];
            $data{correo_admin} = $r->[2];
            last;
        }
    }

    print encode_json({ status => 'success', data => \%data });
    exit;
}

# ==========================================
# UPDATE
# ==========================================
if ($action eq 'update') {
    my $id_org = $q->param('id_org') // '';
    if (!$id_org) { print encode_json({status=>'error', message=>'ID requerido'}); exit; }

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

    if (!$nombre_org || !$nombre_admin || !$correo_admin || !$tipo_organizacion || !$naturaleza_juridica) {
        print encode_json({ status => 'error', message => 'Faltan datos obligatorios.' });
        exit;
    }

    # Actualizar negocios.dat
    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    my @nuevos_negocios = ();
    my $org_found = 0;
    foreach my $r (@$regs_negocios) {
        if (@$r >= 22 && $r->[0] eq $id_org) {
            $r->[1] = $nombre_org;
            $r->[10] = $rfc_org;
            $r->[8] = $correo_admin;
            $org_found = 1;
        }
        push @nuevos_negocios, join('|', @$r);
    }
    if (!$org_found) { print encode_json({status=>'error', message=>'Organización no encontrada.'}); exit; }

    # Actualizar usuarios.dat
    my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
    my @nuevos_usuarios = ();
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        my $multi_tenant = $r->[6];
        my ($u_org, $u_suc) = split(/:/, $multi_tenant);
        
        # Validar si otro usuario tiene el correo
        if (lc($r->[2] // '') eq $correo_admin) {
            if ($r->[5] ne 'Administrador Organizacion' || !defined $u_org || $u_org ne $id_org) {
                print encode_json({ status => 'error', message => 'El correo electrónico del administrador ya está en uso por otro usuario.' });
                exit;
            }
        }
        
        if ($r->[5] eq 'Administrador Organizacion' && defined $u_org && $u_org eq $id_org) {
            $r->[1] = $nombre_admin;
            $r->[2] = $correo_admin;
            if ($clave_admin ne '') {
                $r->[3] = sha256_hex($clave_admin);
            }
        }
        push @nuevos_usuarios, join('!', @$r);
    }

    # Actualizar negocios_config.dat (Eliminar config actual y apendear nueva)
    my $regs_config = leer_tabla($archivo_config, '\|');
    my @nueva_config = ();
    foreach my $r (@$regs_config) {
        if ($r->[0] ne $id_org) {
            push @nueva_config, join('|', @$r);
        }
    }
    
    # Agregar nuevas configs
    push @nueva_config, "$id_org|TIPO_ORGANIZACION|$tipo_organizacion";
    push @nueva_config, "$id_org|NATURALEZA_JURIDICA|$naturaleza_juridica";
    push @nueva_config, "$id_org|REPORTE_INSTITUCION|$reporta_institucion";
    foreach my $inst (@instituciones) { push @nueva_config, "$id_org|INSTITUCION|$inst"; }
    foreach my $cap (@capacidades) { push @nueva_config, "$id_org|CAPACIDAD|$cap"; }

    eval {
        actualizar_archivo($archivo_negocios, "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud", \@nuevos_negocios);
        actualizar_archivo($archivo_usuarios, "id!nombre!correo!clave!activo!rol!ID_negocio", \@nuevos_usuarios);
        actualizar_archivo($archivo_config, "ID_ORG|CLAVE|VALOR", \@nueva_config);
    };
    if ($@) { print encode_json({status=>'error', message=>'Error: '.$@}); exit; }

    print encode_json({ status => 'success', message => 'Organización actualizada' });
    exit;
}

# ==========================================
# REMOVE (Soft Delete)
# ==========================================
if ($action eq 'remove') {
    my $id_org = $q->param('id_org') // '';
    if (!$id_org) { print encode_json({status=>'error', message=>'ID requerido'}); exit; }

    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    my @nuevos_negocios = ();
    foreach my $r (@$regs_negocios) {
        if (@$r >= 22 && $r->[0] eq $id_org) {
            $r->[3] = '0'; # Activo = 0 (Soft delete)
        }
        push @nuevos_negocios, join('|', @$r);
    }
    
    # También soft-delete del admin (opcional, pero buena práctica)
    my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
    my @nuevos_usuarios = ();
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        my $multi_tenant = $r->[6];
        my ($u_org, $u_suc) = split(/:/, $multi_tenant);
        if (defined $u_org && $u_org eq $id_org) {
            $r->[4] = '0'; # Desactivar todos los usuarios de la org
        }
        push @nuevos_usuarios, join('!', @$r);
    }

    eval {
        actualizar_archivo($archivo_negocios, "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud", \@nuevos_negocios);
        actualizar_archivo($archivo_usuarios, "id!nombre!correo!clave!activo!rol!ID_negocio", \@nuevos_usuarios);
    };
    if ($@) { print encode_json({status=>'error', message=>'Error: '.$@}); exit; }

    print encode_json({ status => 'success', message => 'Organización eliminada (Soft Delete)' });
    exit;
}

print encode_json({ status => 'error', message => 'Acción inválida.' });
