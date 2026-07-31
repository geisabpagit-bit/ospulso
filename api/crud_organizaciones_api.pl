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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
use utils::db_manager qw(leer_tabla actualizar_archivo);

use Encode qw(decode_utf8);

my $sd = check_session();
my $q  = $sd->{q};


print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || ($sd->{role} ne 'Ejecutivo Ventas' && $sd->{role} ne 'Administrador Global')) {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $id_vendedor = $sd->{id_medico};
my $action = $q->param('action') || 'create';

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $archivo_config   = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');

# ==========================================
# CREATE
# ==========================================
if ($action eq 'create') {
    my $nombre_org   = decode_utf8($q->param('nombre_org')   // '');
    my $rfc_org      = decode_utf8($q->param('rfc_org')      // '');
    my $razon_org    = decode_utf8($q->param('razon_org')    // '');
    my $naturaleza_juridica = decode_utf8($q->param('naturaleza_juridica') // '');
    my $tipo_organizacion   = decode_utf8($q->param('tipo_organizacion') // '');
    my $reporta_institucion = decode_utf8($q->param('reporta_institucion') // '');
    my @instituciones = map { decode_utf8($_ // '') } $q->multi_param('institucion[]');
    my @capacidades   = map { decode_utf8($_ // '') } $q->multi_param('capacidades[]');

    my $nombre_admin = decode_utf8($q->param('nombre_admin') // '');
    my $correo_admin = lc(decode_utf8($q->param('correo_admin') // ''));
    my $clave_admin  = decode_utf8($q->param('clave_admin')  // '');

    my $cp_org        = decode_utf8($q->param('cp_org')        // '');
    my $entidad_org   = decode_utf8($q->param('entidad_org')   // '');
    my $municipio_org = decode_utf8($q->param('municipio_org') // '');
    my $colonia_org   = decode_utf8($q->param('colonia_org')   // '');
    my $clues_org     = decode_utf8($q->param('clues_org')     // '');
    my $dir_org       = decode_utf8($q->param('dir_org')       // '');
    my $tel_org       = decode_utf8($q->param('tel_org')       // '');
    my $ext_org       = decode_utf8($q->param('ext_org')       // '0');
    my $lat_org       = decode_utf8($q->param('lat_org')       // '');
    my $lng_org       = decode_utf8($q->param('lng_org')       // '');

    $nombre_org   =~ s/^\s+|\s+$//g;
    $nombre_admin =~ s/^\s+|\s+$//g;
    $correo_admin =~ s/^\s+|\s+$//g;
    $clave_admin  =~ s/^\s+|\s+$//g;
    $rfc_org      =~ s/^\s+|\s+$//g;
    $razon_org    =~ s/^\s+|\s+$//g;
    $reporta_institucion =~ s/^\s+|\s+$//g;

    # Valores por defecto para evitar nulos en campos opcionales
    $rfc_org = "No aplica" if $rfc_org eq '';
    $reporta_institucion = "No aplica" if $reporta_institucion eq '';
    @instituciones = ("No aplica") if !@instituciones;

    if (!$nombre_org || !$nombre_admin || !$correo_admin || !$clave_admin || !$tipo_organizacion || !$naturaleza_juridica) {
        print encode_json({ status => 'error', message => 'Faltan datos obligatorios.' });
        exit;
    }

    # Validar no duplicidad de Nombre Comercial y RFC Institucional
    my ($dup_ok, $dup_msg) = validar_no_duplicidad('', $nombre_org, $rfc_org);
    unless ($dup_ok) {
        print encode_json({ status => 'error', message => $dup_msg });
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
        $id_org, $nombre_org, "0", "1", $fecha_inicio, $fecha_fin, $dir_org, $tel_org, $correo_admin, "", $rfc_org, $razon_org, "", $id_vendedor, $cp_org, $entidad_org, $municipio_org, $colonia_org, $clues_org, $ext_org, $lat_org, $lng_org
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

    # Crear catalogo de servicios y productos para la nueva organizacion
    catalogo_org_utils::crear_catalogo_org_desde_global($id_org);

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
            $data{nombre_org}   = $r->[1];
            $data{dir_org}      = $r->[6];
            $data{tel_org}      = $r->[7];
            $data{rfc_org}      = $r->[10];
            $data{razon_org}    = $r->[11];
            $data{cp_org}       = $r->[14];
            $data{entidad_org}  = $r->[15];
            $data{municipio_org}= $r->[16];
            $data{colonia_org}  = $r->[17];
            $data{clues_org}    = $r->[18];
            $data{ext_org}      = $r->[19];
            $data{lat_org}      = $r->[20];
            $data{lng_org}      = $r->[21];
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

    my $nombre_org   = decode_utf8($q->param('nombre_org')   // '');
    my $rfc_org      = decode_utf8($q->param('rfc_org')      // '');
    my $razon_org    = decode_utf8($q->param('razon_org')    // '');
    my $naturaleza_juridica = decode_utf8($q->param('naturaleza_juridica') // '');
    my $tipo_organizacion   = decode_utf8($q->param('tipo_organizacion') // '');
    my $reporta_institucion = decode_utf8($q->param('reporta_institucion') // '');
    my @instituciones = map { decode_utf8($_ // '') } $q->multi_param('institucion[]');
    my @capacidades   = map { decode_utf8($_ // '') } $q->multi_param('capacidades[]');

    my $nombre_admin = decode_utf8($q->param('nombre_admin') // '');
    my $correo_admin = lc(decode_utf8($q->param('correo_admin') // ''));
    my $clave_admin  = decode_utf8($q->param('clave_admin')  // '');

    my $cp_org        = decode_utf8($q->param('cp_org')        // '');
    my $entidad_org   = decode_utf8($q->param('entidad_org')   // '');
    my $municipio_org = decode_utf8($q->param('municipio_org') // '');
    my $colonia_org   = decode_utf8($q->param('colonia_org')   // '');
    my $clues_org     = decode_utf8($q->param('clues_org')     // '');
    my $dir_org       = decode_utf8($q->param('dir_org')       // '');
    my $tel_org       = decode_utf8($q->param('tel_org')       // '');
    my $ext_org       = decode_utf8($q->param('ext_org')       // '0');
    my $lat_org       = decode_utf8($q->param('lat_org')       // '');
    my $lng_org       = decode_utf8($q->param('lng_org')       // '');

    $nombre_org   =~ s/^\s+|\s+$//g;
    $nombre_admin =~ s/^\s+|\s+$//g;
    $correo_admin =~ s/^\s+|\s+$//g;
    $clave_admin  =~ s/^\s+|\s+$//g;
    $rfc_org      =~ s/^\s+|\s+$//g;
    $razon_org    =~ s/^\s+|\s+$//g;
    $reporta_institucion =~ s/^\s+|\s+$//g;

    # Valores por defecto para evitar nulos en campos opcionales
    $rfc_org = "No aplica" if $rfc_org eq '';
    $reporta_institucion = "No aplica" if $reporta_institucion eq '';
    @instituciones = ("No aplica") if !@instituciones;

    if (!$nombre_org || !$nombre_admin || !$correo_admin || !$tipo_organizacion || !$naturaleza_juridica) {
        print encode_json({ status => 'error', message => 'Faltan datos obligatorios.' });
        exit;
    }

    # Validar no duplicidad de Nombre Comercial y RFC Institucional (excluyendo la org actual)
    my ($dup_ok, $dup_msg) = validar_no_duplicidad($id_org, $nombre_org, $rfc_org);
    unless ($dup_ok) {
        print encode_json({ status => 'error', message => $dup_msg });
        exit;
    }

    # Actualizar negocios.dat
    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    my @nuevos_negocios = ();
    my $org_found = 0;
    foreach my $r (@$regs_negocios) {
        if (@$r >= 22 && $r->[0] eq $id_org) {
            $r->[1] = $nombre_org;
            $r->[6] = $dir_org if $dir_org ne '';
            $r->[7] = $tel_org if $tel_org ne '';
            $r->[8] = $correo_admin;
            $r->[10] = $rfc_org;
            $r->[11] = $razon_org if $razon_org ne '';
            $r->[14] = $cp_org if $cp_org ne '';
            $r->[15] = $entidad_org if $entidad_org ne '';
            $r->[16] = $municipio_org if $municipio_org ne '';
            $r->[17] = $colonia_org if $colonia_org ne '';
            $r->[18] = $clues_org if $clues_org ne '';
            $r->[19] = $ext_org if $ext_org ne '';
            $r->[20] = $lat_org if $lat_org ne '';
            $r->[21] = $lng_org if $lng_org ne '';
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

# ==========================================
# REACTIVATE
# ==========================================
if ($action eq 'reactivate') {
    my $id_org = $q->param('id_org') // '';
    if (!$id_org) { print encode_json({status=>'error', message=>'ID requerido'}); exit; }

    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    my @nuevos_negocios = ();
    foreach my $r (@$regs_negocios) {
        if (@$r >= 22 && $r->[0] eq $id_org) {
            $r->[3] = '1'; # Activo = 1
        }
        push @nuevos_negocios, join('|', @$r);
    }
    
    my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
    my @nuevos_usuarios = ();
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        my $multi_tenant = $r->[6];
        my ($u_org, $u_suc) = split(/:/, $multi_tenant);
        if (defined $u_org && $u_org eq $id_org) {
            $r->[4] = '1'; # Reactivar todos los usuarios de la org
        }
        push @nuevos_usuarios, join('!', @$r);
    }

    eval {
        actualizar_archivo($archivo_negocios, "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud", \@nuevos_negocios);
        actualizar_archivo($archivo_usuarios, "id!nombre!correo!clave!activo!rol!ID_negocio", \@nuevos_usuarios);
    };
    if ($@) { print encode_json({status=>'error', message=>'Error: '.$@}); exit; }

    print encode_json({ status => 'success', message => 'Organización reactivada' });
    exit;
}

# ==========================================
# DELETE PERMANENT
# ==========================================
if ($action eq 'delete_permanent') {
    my $id_org = $q->param('id_org') // '';
    if (!$id_org) { print encode_json({status=>'error', message=>'ID requerido'}); exit; }

    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    my @nuevos_negocios = ();
    foreach my $r (@$regs_negocios) {
        if (@$r >= 22 && $r->[0] eq $id_org) {
            next; # Skip (Físicamente eliminado)
        }
        push @nuevos_negocios, join('|', @$r);
    }
    
    my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
    my @nuevos_usuarios = ();
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        my $multi_tenant = $r->[6];
        my ($u_org, $u_suc) = split(/:/, $multi_tenant);
        if (defined $u_org && $u_org eq $id_org) {
            next; # Skip
        }
        push @nuevos_usuarios, join('!', @$r);
    }

    eval {
        actualizar_archivo($archivo_negocios, "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud", \@nuevos_negocios);
        actualizar_archivo($archivo_usuarios, "id!nombre!correo!clave!activo!rol!ID_negocio", \@nuevos_usuarios);
    };
    if ($@) { print encode_json({status=>'error', message=>'Error: '.$@}); exit; }

    print encode_json({ status => 'success', message => 'Organización eliminada permanentemente' });
    exit;
}

sub validar_no_duplicidad {
    my ($id_org_ignore, $nombre_org, $rfc_org) = @_;
    my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    
    my $target_nombre = lc($nombre_org // '');
    $target_nombre =~ s/^\s+|\s+$//g;

    my $target_rfc = uc($rfc_org // '');
    $target_rfc =~ s/^\s+|\s+$//g;

    if ($regs_negocios) {
        foreach my $r (@$regs_negocios) {
            next if @$r < 11;
            my $curr_id     = $r->[0] // '';
            my $curr_nombre = $r->[1] // '';
            my $curr_activo = $r->[3] // '1';
            my $curr_rfc    = $r->[10] // '';
            
            # Ignorar la misma organización si estamos editando
            next if $id_org_ignore && $curr_id eq $id_org_ignore;
            
            # Solo validar contra organizaciones activas
            next if $curr_activo ne '1';

            # 1. Validar Nombre Comercial
            my $clean_curr_nombre = lc($curr_nombre);
            $clean_curr_nombre =~ s/^\s+|\s+$//g;
            if ($target_nombre ne '' && $clean_curr_nombre eq $target_nombre) {
                return (0, "Ya existe una organización registrada con el Nombre Comercial '$curr_nombre'.");
            }

            # 2. Validar RFC Institucional (si no es 'NO APLICA' ni vacío)
            if ($target_rfc ne '' && $target_rfc ne 'NO APLICA') {
                my $clean_curr_rfc = uc($curr_rfc);
                $clean_curr_rfc =~ s/^\s+|\s+$//g;
                if ($clean_curr_rfc ne '' && $clean_curr_rfc ne 'NO APLICA' && $clean_curr_rfc eq $target_rfc) {
                    return (0, "Ya existe una organización registrada con el RFC Institucional '$curr_rfc' ($curr_nombre).");
                }
            }
        }
    }

    return (1, '');
}

print encode_json({ status => 'error', message => 'Acción inválida.' });
