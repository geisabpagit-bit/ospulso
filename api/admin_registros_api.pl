#!/usr/bin/perl
BEGIN { eval "use cPanelUserConfig;"; }
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use File::Path qw(remove_tree);
use Fcntl qw(:flock);
use Time::Piece;
use Encode qw(encode_utf8 decode_utf8 is_utf8);
use open qw(:std :utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(
    -type => 'application/json',
    -charset => 'UTF-8',
    -cache_control => 'no-store, no-cache, must-revalidate, max-age=0',
    -pragma => 'no-cache'
);

binmode STDOUT, ':raw';

sub responder_json {
    my ($data) = @_;
    print encode_json($data);
    exit;
}

sub safe_param {
    my ($param_name, $default) = @_;
    my $val = $q->param($param_name);
    return $default if !defined $val;
    return is_utf8($val) ? $val : decode_utf8($val);
}

# RBAC: Exclusivo para Administrador Global
if (!$sd->{session_ok} || ($sd->{role} // '') ne 'Administrador Global') {
    responder_json({
        status  => 'error',
        message => 'Acceso denegado: Esta función requiere privilegios de Administrador Global.'
    });
}

my $action = safe_param('action', 'listar');
my $dat_dir = File::Spec->catfile($FindBin::Bin, '..', 'dat');
my $uploads_dir = File::Spec->catfile($FindBin::Bin, '..', 'uploads');
my $archivo_negocios = File::Spec->catfile($dat_dir, 'negocios.dat');
my $archivo_usuarios = File::Spec->catfile($dat_dir, 'usuarios.dat');
my $archivo_audit    = File::Spec->catfile($dat_dir, 'audit_logs.dat');

my $today = eval { localtime->strftime('%Y-%m-%d') } || '2026-10-31';
my $today_tp = eval { Time::Piece->strptime($today, '%Y-%m-%d') };

# Bitácora de auditoría
sub registrar_auditoria {
    my ($modulo, $tipo_accion, $id_ref, $detalle) = @_;
    my $ahora = eval { localtime->strftime('%Y-%m-%d %H:%M:%S') } || '2026-10-31 00:00:00';
    my $operador = $sd->{usuario} // 'Administrador Global';
    if (open(my $af, '>>:encoding(UTF-8)', $archivo_audit)) {
        flock($af, LOCK_EX);
        print $af "$ahora|$operador|$modulo|$tipo_accion|$id_ref|$detalle\n";
        flock($af, LOCK_UN);
        close($af);
    }
}

if ($action eq 'listar') {
    my @registros = ();
    my %usuarios_admin = ();

    # 1. Mapear administradores de cada clínica desde usuarios.dat
    if (-e $archivo_usuarios && open(my $uf, '<:encoding(UTF-8)', $archivo_usuarios)) {
        <$uf>; # Cabecera
        while (my $line = <$uf>) {
            chomp $line;
            next if $line =~ /^#|^\s*$/;
            my @u = split(/!/, $line, -1);
            my ($u_id, $u_nom, $u_mail, $u_rol, $u_neg) = ($u[0] // '', $u[1] // '', $u[2] // '', $u[5] // '', $u[6] // '');
            my ($id_emp, $id_suc) = split(/:/, $u_neg);
            if ($id_emp && ($u_rol =~ /Administrador/i || !exists $usuarios_admin{$id_emp})) {
                $usuarios_admin{$id_emp} = {
                    id     => $u_id,
                    nombre => $u_nom,
                    correo => $u_mail,
                    rol    => $u_rol
                };
            }
        }
        close($uf);
    }

    # 2. Pre-cargar nombres y estados de las matrices para mapeo jerárquico
    my %nombres_matrices = ();
    my %estados_matrices = ();
    if (-e $archivo_negocios && open(my $nf_pre, '<:encoding(UTF-8)', $archivo_negocios)) {
        <$nf_pre>; # Cabecera
        while (my $line = <$nf_pre>) {
            chomp $line;
            next if $line =~ /^#|^\s*$/;
            my @f = split(/\|/, $line, -1);
            my ($id_n, $nom_n, $id_m, $act_n) = ($f[0] // '', $f[1] // '', $f[2] // '0', $f[3] // '1');
            if ($id_m eq '0' || $id_m eq '') {
                $nombres_matrices{$id_n} = $nom_n;
                $estados_matrices{$id_n} = $act_n;
            }
        }
        close($nf_pre);
    }

    # 3. Leer negocios.dat
    my %kpis = (
        total       => 0,
        demos       => 0,
        activas     => 0,
        por_vencer  => 0,
        suspendidas => 0,
        papelera    => 0
    );

    if (-e $archivo_negocios && open(my $nf, '<:encoding(UTF-8)', $archivo_negocios)) {
        my $header = <$nf>;
        while (my $line = <$nf>) {
            chomp $line;
            next if $line =~ /^#|^\s*$/;
            my @f = split(/\|/, $line, -1);
            my $id_neg   = $f[0] // '';
            my $nom_neg  = $f[1] // '';
            my $id_mat   = $f[2] // '0';
            my $activo   = $f[3] // '1';
            my $ini_susc = $f[4] // '';
            my $fin_susc = $f[5] // '';
            my $dom      = $f[6] // '';
            my $tel      = $f[7] // '';
            my $email    = $f[8] // '';
            my $rfc      = $f[10] // '';
            my $razon    = $f[11] // '';
            my $cp       = $f[14] // '';
            my $entidad  = $f[15] // '';
            my $mun      = $f[16] // '';
            my $colonia  = $f[17] // '';

            my $es_matriz = ($id_mat eq '0' || $id_mat eq '' || $id_mat eq $id_neg) ? 1 : 0;
            my $id_org_matriz = $es_matriz ? $id_neg : $id_mat;
            my $nombre_org_matriz = $nombres_matrices{$id_org_matriz} // ($es_matriz ? $nom_neg : "Organización #$id_org_matriz");
            my $org_activo = $estados_matrices{$id_org_matriz} // $activo;

            my $u_info = $usuarios_admin{$id_neg} // $usuarios_admin{$id_org_matriz} // {
                id => '', nombre => 'Sin Asignar', correo => $email, rol => 'N/A'
            };

            # Calcular días restantes
            my $dias_restantes = 0;
            my $estado_visual = 'activo';
            if ($fin_susc && $today_tp) {
                eval {
                    my $fin_tp = Time::Piece->strptime($fin_susc, '%Y-%m-%d');
                    my $diff_segundos = $fin_tp->epoch - $today_tp->epoch;
                    $dias_restantes = int($diff_segundos / 86400);
                };
            }

            if ($activo eq '-1') {
                $estado_visual = 'papelera';
                $kpis{papelera}++;
            } elsif ($activo eq '0') {
                $estado_visual = 'suspendido';
                $kpis{suspendidas}++;
            } elsif ($dias_restantes < 0) {
                $estado_visual = 'vencido';
                $kpis{por_vencer}++;
            } elsif ($dias_restantes <= 35) {
                $estado_visual = ($dias_restantes <= 5) ? 'demo_urgente' : 'demo';
                $kpis{demos}++;
                if ($dias_restantes <= 5) { $kpis{por_vencer}++; }
            } else {
                $estado_visual = 'pagada';
                $kpis{activas}++;
            }
            $kpis{total}++;

            push @registros, {
                id                => $id_neg,
                nombre_negocio    => $nom_neg,
                id_matriz         => $id_mat,
                es_matriz         => $es_matriz,
                id_org_matriz     => $id_org_matriz,
                nombre_org_matriz => $nombre_org_matriz,
                org_activo        => $org_activo,
                activo            => $activo,
                inicio            => $ini_susc,
                fin               => $fin_susc,
                dias_restantes    => $dias_restantes,
                estado_visual     => $estado_visual,
                telefono          => $tel,
                email             => $email,
                titular_nombre    => $u_info->{nombre},
                titular_email     => $u_info->{correo},
                rfc               => $rfc,
                razon_social      => $razon,
                domicilio         => $dom,
                codigo_postal     => $cp,
                municipio         => $mun,
                entidad           => $entidad,
                colonia           => $colonia
            };
        }
        close($nf);
    }

    responder_json({
        status    => 'ok',
        registros => \@registros,
        kpis      => \%kpis
    });
}

if ($action eq 'obtener') {
    my $id_target = safe_param('id', '');
    if (!$id_target) {
        responder_json({ status => 'error', message => 'ID de negocio no especificado.' });
    }

    my $registro = undef;
    if (-e $archivo_negocios && open(my $nf, '<:encoding(UTF-8)', $archivo_negocios)) {
        my $hdr = <$nf>;
        while (my $line = <$nf>) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            if ($f[0] eq $id_target) {
                $registro = {
                    id             => $f[0] // '',
                    nombre_negocio => $f[1] // '',
                    id_matriz      => $f[2] // '0',
                    activo         => $f[3] // '1',
                    inicio         => $f[4] // '',
                    fin            => $f[5] // '',
                    domicilio      => $f[6] // '',
                    telefono       => $f[7] // '',
                    contacto_email => $f[8] // '',
                    logo_url       => $f[9] // '',
                    rfc            => $f[10] // '',
                    razon_social   => $f[11] // '',
                    codigo_postal  => $f[14] // '',
                    entidad        => $f[15] // '',
                    municipio      => $f[16] // '',
                    colonia        => $f[17] // '',
                    clues          => $f[18] // ''
                };
                last;
            }
        }
        close($nf);
    }

    if ($registro) {
        responder_json({ status => 'ok', registro => $registro });
    } else {
        responder_json({ status => 'error', message => 'Registro no encontrado.' });
    }
}

# Soft-Delete (Mover a la Papelera - a nivel Organización y sus sucursales)
if ($action eq 'soft_delete') {
    my $id_org = safe_param('id_org', '');
    if (!$id_org) {
        responder_json({ status => 'error', message => 'ID de Organización matriz requerido.' });
    }

    my $afectados = 0;
    my @nombres_afectados = ();
    if (-e $archivo_negocios) {
        open(my $nf, '+<:encoding(UTF-8)', $archivo_negocios) or die "No se pudo abrir negocios.dat: $!";
        flock($nf, LOCK_EX);
        my @lineas = <$nf>;
        seek($nf, 0, 0);
        truncate($nf, 0);

        foreach my $line (@lineas) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            if (@f > 3) {
                my ($id_n, $nom_n, $id_m) = ($f[0] // '', $f[1] // '', $f[2] // '0');
                if ($id_n eq $id_org || $id_m eq $id_org) {
                    $f[3] = '-1'; # Marcador de Papelera
                    $line = join('|', @f);
                    $afectados++;
                    push @nombres_afectados, "$nom_n (#$id_n)";
                }
            }
            print $nf "$line\n";
        }
        flock($nf, LOCK_UN);
        close($nf);
    }

    if ($afectados > 0) {
        registrar_auditoria('GestionRegistros', 'SOFT_DELETE', $id_org, "Movida a papelera la organización matriz y $afectados entidad(es): " . join(', ', @nombres_afectados));
        responder_json({
            status => 'ok',
            message => "Organización y $afectados sucursal(es) movidas a la papelera correctamente.",
            afectados => $afectados
        });
    } else {
        responder_json({ status => 'error', message => 'No se encontró la organización solicitada.' });
    }
}

# Restaurar Organización desde la Papelera
if ($action eq 'restaurar_org') {
    my $id_org = safe_param('id_org', '');
    if (!$id_org) {
        responder_json({ status => 'error', message => 'ID de Organización matriz requerido.' });
    }

    my $afectados = 0;
    if (-e $archivo_negocios) {
        open(my $nf, '+<:encoding(UTF-8)', $archivo_negocios) or die "No se pudo abrir negocios.dat: $!";
        flock($nf, LOCK_EX);
        my @lineas = <$nf>;
        seek($nf, 0, 0);
        truncate($nf, 0);

        foreach my $line (@lineas) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            if (@f > 3) {
                my ($id_n, $nom_n, $id_m) = ($f[0] // '', $f[1] // '', $f[2] // '0');
                if ($id_n eq $id_org || $id_m eq $id_org) {
                    $f[3] = '1'; # Reactivar
                    $line = join('|', @f);
                    $afectados++;
                }
            }
            print $nf "$line\n";
        }
        flock($nf, LOCK_UN);
        close($nf);
    }

    if ($afectados > 0) {
        registrar_auditoria('GestionRegistros', 'RESTAURAR_ORG', $id_org, "Restaurada de papelera organización matriz y $afectados sucursal(es)");
        responder_json({
            status => 'ok',
            message => "Organización restaurada exitosamente junto con sus sucursales.",
            afectados => $afectados
        });
    } else {
        responder_json({ status => 'error', message => 'No se encontró la organización para restaurar.' });
    }
}

# Hard-Delete (Eliminación Física Definitiva y Purga Total)
if ($action eq 'hard_delete') {
    my $id_org = safe_param('id_org', '');
    my $confirmacion = safe_param('confirmacion', '');

    if (!$id_org) {
        responder_json({ status => 'error', message => 'ID de Organización requerido.' });
    }
    if (uc($confirmacion) ne 'ELIMINAR') {
        responder_json({ status => 'error', message => 'Palabra de confirmación inválida. Debe escribir exactamente "ELIMINAR".' });
    }

    # 1. Identificar todos los IDs de negocio vinculados (matriz y sucursales)
    my %ids_negocio = ($id_org => 1);
    my $nombre_matriz = "Organización #$id_org";

    if (-e $archivo_negocios && open(my $nf, '<:encoding(UTF-8)', $archivo_negocios)) {
        <$nf>;
        while (my $line = <$nf>) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            my ($id_n, $nom_n, $id_m) = ($f[0] // '', $f[1] // '', $f[2] // '0');
            if ($id_n eq $id_org) {
                $nombre_matriz = $nom_n;
            }
            if ($id_n eq $id_org || $id_m eq $id_org) {
                $ids_negocio{$id_n} = 1;
            }
        }
        close($nf);
    }

    # 2. Identificar usuarios asociados a estos negocios
    my %ids_usuarios = ();
    if (-e $archivo_usuarios && open(my $uf, '<:encoding(UTF-8)', $archivo_usuarios)) {
        <$uf>;
        while (my $line = <$uf>) {
            chomp $line;
            my @u = split(/!/, $line, -1);
            my ($u_id, $u_neg) = ($u[0] // '', $u[6] // '');
            my ($id_emp, $id_suc) = split(/:/, $u_neg);
            if ($ids_negocio{$id_emp // ''} || $ids_negocio{$id_suc // ''}) {
                $ids_usuarios{$u_id} = 1 if $u_id;
            }
        }
        close($uf);
    }

    # 3. Identificar pacientes asociados a estos negocios
    my %ids_pacientes = ();
    my $archivo_pacientes = File::Spec->catfile($dat_dir, 'pacientes.dat');
    if (-e $archivo_pacientes && open(my $pf, '<:encoding(UTF-8)', $archivo_pacientes)) {
        <$pf>;
        while (my $line = <$pf>) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            my $p_id = $f[0] // '';
            my $tenant = $f[13] // ''; # TENANT formato "id_emp:id_suc"
            my ($p_emp, $p_suc) = split(/:/, $tenant);
            if ($ids_negocio{$p_emp // ''} || $ids_negocio{$p_suc // ''}) {
                $ids_pacientes{$p_id} = 1 if $p_id;
            }
        }
        close($pf);
    }

    # Contadores de auditoría de purga
    my %audit_purgados = (
        negocios   => 0,
        usuarios   => 0,
        pacientes  => 0,
        archivos   => 0
    );

    # Helper para depurar archivos .dat filtrando líneas
    my $filtrar_dat = sub {
        my ($ruta, $separador, $criterio_eliminar_sub) = @_;
        return unless -e $ruta;
        open(my $fh, '+<:encoding(UTF-8)', $ruta) or return;
        flock($fh, LOCK_EX);
        my @lineas = <$fh>;
        seek($fh, 0, 0);
        truncate($fh, 0);

        my $is_first = 1;
        foreach my $line (@lineas) {
            if ($is_first) {
                print $fh $line;
                $is_first = 0;
                next;
            }
            chomp $line;
            next if $line =~ /^\s*$/;
            my @cols = split(/\Q$separador\E/, $line, -1);
            if (&$criterio_eliminar_sub(\@cols)) {
                # Se omite (eliminada)
            } else {
                print $fh "$line\n";
            }
        }
        flock($fh, LOCK_UN);
        close($fh);
    };

    # A. Purgar negocios.dat
    $filtrar_dat->($archivo_negocios, '|', sub {
        my $c = shift;
        my ($id_n, $id_m) = ($c->[0] // '', $c->[2] // '0');
        if ($ids_negocio{$id_n} || $ids_negocio{$id_m}) {
            $audit_purgados{negocios}++;
            return 1;
        }
        return 0;
    });

    # B. Purgar negocios_config.dat
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'negocios_config.dat'), '|', sub {
        my $c = shift;
        return $ids_negocio{$c->[0] // ''} ? 1 : 0;
    });

    # C. Purgar usuarios.dat
    $filtrar_dat->($archivo_usuarios, '!', sub {
        my $c = shift;
        my $u_id = $c->[0] // '';
        if ($ids_usuarios{$u_id}) {
            $audit_purgados{usuarios}++;
            return 1;
        }
        return 0;
    });

    # D. Purgar pacientes.dat, pacientes_domicilio.dat, pacientes_antecedentes.dat
    $filtrar_dat->($archivo_pacientes, '|', sub {
        my $c = shift;
        my $p_id = $c->[0] // '';
        if ($ids_pacientes{$p_id}) {
            $audit_purgados{pacientes}++;
            return 1;
        }
        return 0;
    });
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'pacientes_domicilio.dat'), '|', sub {
        my $c = shift;
        return $ids_pacientes{$c->[0] // ''} ? 1 : 0;
    });
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'pacientes_antecedentes.dat'), '|', sub {
        my $c = shift;
        return $ids_pacientes{$c->[0] // ''} ? 1 : 0;
    });

    # E. Purgar citas.dat
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'citas.dat'), '|', sub {
        my $c = shift;
        my $p_id = $c->[2] // '';
        my $n_id = $c->[14] // '';
        return ($ids_negocio{$n_id} || $ids_pacientes{$p_id}) ? 1 : 0;
    });

    # F. Purgar consultas_clinicas.dat, recetas.dat, consentimientos.dat
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'consultas_clinicas.dat'), '|', sub {
        my $c = shift;
        return $ids_pacientes{$c->[1] // ''} ? 1 : 0;
    });
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'recetas.dat'), '|', sub {
        my $c = shift;
        return $ids_pacientes{$c->[2] // ''} ? 1 : 0;
    });
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'consentimientos.dat'), '|', sub {
        my $c = shift;
        return $ids_pacientes{$c->[2] // ''} ? 1 : 0;
    });

    # G. Purgar estado_cuenta.dat
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'estado_cuenta.dat'), '|', sub {
        my $c = shift;
        return $ids_pacientes{$c->[2] // ''} ? 1 : 0;
    });

    # H. Purgar folios_recibos_privados.dat y folios_recibos_publicos.dat
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'folios_recibos_privados.dat'), '|', sub {
        my $c = shift;
        my $n_id = $c->[2] // '';
        my $p_id = $c->[5] // '';
        return ($ids_negocio{$n_id} || $ids_pacientes{$p_id}) ? 1 : 0;
    });
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'folios_recibos_publicos.dat'), '|', sub {
        my $c = shift;
        my $n_id = $c->[2] // '';
        my $p_id = $c->[5] // '';
        return ($ids_negocio{$n_id} || $ids_pacientes{$p_id}) ? 1 : 0;
    });

    # I. Purgar gastos.dat
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'gastos.dat'), '|', sub {
        my $c = shift;
        my $n_id = $c->[11] // '';
        return $ids_negocio{$n_id} ? 1 : 0;
    });

    # J. Purgar cotizaciones.dat, odontogramas.dat, quirofano.dat
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'cotizaciones.dat'), '|', sub {
        my $c = shift;
        return $ids_pacientes{$c->[1] // ''} ? 1 : 0;
    });
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'odontogramas.dat'), '|', sub {
        my $c = shift;
        return $ids_pacientes{$c->[0] // ''} ? 1 : 0;
    });
    $filtrar_dat->(File::Spec->catfile($dat_dir, 'quirofano.dat'), '|', sub {
        my $c = shift;
        my $org_id = $c->[1] // '';
        my $p_id   = $c->[2] // '';
        return ($ids_negocio{$org_id} || $ids_pacientes{$p_id}) ? 1 : 0;
    });

    # K. Purgar archivos físicos individuales en dat/ y uploads/
    foreach my $b_id (keys %ids_negocio) {
        my @archivos_negocio = (
            File::Spec->catfile($dat_dir, "productos_$b_id.dat"),
            File::Spec->catfile($dat_dir, "servicios_$b_id.dat"),
            File::Spec->catfile($dat_dir, "catalogo_odontograma_$b_id.dat"),
            File::Spec->catfile($dat_dir, "contadores_recibos_privados_$b_id.dat"),
            File::Spec->catfile($dat_dir, "agenda_config_sucursal_$b_id.dat"),
            File::Spec->catfile($uploads_dir, "logos", "logo_$b_id.png"),
            File::Spec->catfile($uploads_dir, "logos", "logo_$b_id.jpg")
        );
        foreach my $archivo (@archivos_negocio) {
            if (-e $archivo) {
                unlink($archivo);
                $audit_purgados{archivos}++;
            }
        }
    }

    # Purgar archivos de usuarios
    foreach my $u_id (keys %ids_usuarios) {
        my @archivos_usuario = (
            File::Spec->catfile($dat_dir, "agenda_config_medico_$u_id.dat"),
            File::Spec->catfile($uploads_dir, "avatars", "avatar_$u_id.png"),
            File::Spec->catfile($uploads_dir, "avatars", "avatar_$u_id.jpg")
        );
        foreach my $archivo (@archivos_usuario) {
            if (-e $archivo) {
                unlink($archivo);
                $audit_purgados{archivos}++;
            }
        }
    }

    # Purgar carpetas físicas de pacientes (Estudios RX)
    foreach my $p_id (keys %ids_pacientes) {
        my $dir_paciente = File::Spec->catfile($dat_dir, "estudiosRX", $p_id);
        if (-d $dir_paciente) {
            remove_tree($dir_paciente);
            $audit_purgados{archivos}++;
        }
    }

    # Registrar en auditoría general
    my $resumen_auditoria = sprintf(
        "HARD DELETE DEFINITIVO de Organización '%s' (#%s). Purgados: %d negocios/sucursales, %d usuarios, %d expedientes/pacientes, %d archivos físicos.",
        $nombre_matriz, $id_org, $audit_purgados{negocios}, $audit_purgados{usuarios}, $audit_purgados{pacientes}, $audit_purgados{archivos}
    );
    registrar_auditoria('GestionRegistros', 'HARD_DELETE_ORGANIZACION', $id_org, $resumen_auditoria);

    responder_json({
        status   => 'ok',
        message  => "Organización y todas sus sucursales fueron purgadas definitivamente del sistema sin dejar rastro.",
        auditoria => \%audit_purgados
    });
}

if ($action eq 'actualizar_estado') {
    my $id_target     = safe_param('id', '');
    my $nuevo_estado  = safe_param('activo', '1');
    $nuevo_estado     = ($nuevo_estado eq '1' || $nuevo_estado eq 'true') ? '1' : '0';

    if (!$id_target) {
        responder_json({ status => 'error', message => 'ID requerido.' });
    }

    my $modificado = 0;
    if (-e $archivo_negocios) {
        open(my $nf, '+<:encoding(UTF-8)', $archivo_negocios) or die "No se pudo abrir negocios.dat: $!";
        flock($nf, LOCK_EX);
        my @lineas = <$nf>;
        seek($nf, 0, 0);
        truncate($nf, 0);

        foreach my $line (@lineas) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            if (@f > 3 && $f[0] eq $id_target) {
                $f[3] = $nuevo_estado;
                $line = join('|', @f);
                $modificado = 1;
            }
            print $nf "$line\n";
        }
        flock($nf, LOCK_UN);
        close($nf);
    }

    if ($modificado) {
        responder_json({ status => 'ok', message => 'Estado actualizado exitosamente.' });
    } else {
        responder_json({ status => 'error', message => 'No se encontró el registro para actualizar.' });
    }
}

if ($action eq 'extender_demo') {
    my $id_target = safe_param('id', '');
    my $dias_ext  = int($q->param('dias') // 30);
    $dias_ext = 30 if $dias_ext <= 0;

    if (!$id_target) {
        responder_json({ status => 'error', message => 'ID requerido.' });
    }

    my $nueva_fecha_fin = '';
    my $modificado = 0;

    if (-e $archivo_negocios) {
        open(my $nf, '+<:encoding(UTF-8)', $archivo_negocios) or die "No se pudo abrir negocios.dat: $!";
        flock($nf, LOCK_EX);
        my @lineas = <$nf>;
        seek($nf, 0, 0);
        truncate($nf, 0);

        foreach my $line (@lineas) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            if (@f > 5 && $f[0] eq $id_target) {
                my $fin_actual = $f[5] // '';
                my $base_tp = $today_tp;

                if ($fin_actual && $today_tp) {
                    eval {
                        my $fin_tp = Time::Piece->strptime($fin_actual, '%Y-%m-%d');
                        if ($fin_tp->epoch > $today_tp->epoch) {
                            $base_tp = $fin_tp;
                        }
                    };
                }

                my $nuevo_fin_tp = $base_tp + ($dias_ext * 86400);
                $nueva_fecha_fin = $nuevo_fin_tp->strftime('%Y-%m-%d');

                $f[3] = '1'; # Activar cuenta
                $f[5] = $nueva_fecha_fin; # Actualizar fin de suscripción
                $line = join('|', @f);
                $modificado = 1;
            }
            print $nf "$line\n";
        }
        flock($nf, LOCK_UN);
        close($nf);
    }

    if ($modificado) {
        responder_json({
            status => 'ok',
            message => "Periodo extendido exitosamente +$dias_ext días hasta $nueva_fecha_fin.",
            nueva_fecha => $nueva_fecha_fin
        });
    } else {
        responder_json({ status => 'error', message => 'No se encontró el registro.' });
    }
}

if ($action eq 'editar') {
    my $id_target  = safe_param('id', '');
    my $nombre     = safe_param('nombre_negocio', '');
    my $telefono   = safe_param('telefono', '');
    my $email      = safe_param('contacto_email', '');
    my $rfc        = safe_param('rfc', '');
    my $razon      = safe_param('razon_social', '');
    my $domicilio  = safe_param('domicilio', '');
    my $cp         = safe_param('codigo_postal', '');
    my $entidad    = safe_param('entidad', '');
    my $municipio  = safe_param('municipio', '');
    my $colonia    = safe_param('colonia', '');

    if (!$id_target || !$nombre) {
        responder_json({ status => 'error', message => 'El ID y el Nombre de la clínica son obligatorios.' });
    }

    my $modificado = 0;
    if (-e $archivo_negocios) {
        open(my $nf, '+<:encoding(UTF-8)', $archivo_negocios) or die "No se pudo abrir negocios.dat: $!";
        flock($nf, LOCK_EX);
        my @lineas = <$nf>;
        seek($nf, 0, 0);
        truncate($nf, 0);

        foreach my $line (@lineas) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            if (@f > 17 && $f[0] eq $id_target) {
                $f[1]  = $nombre;
                $f[6]  = $domicilio if $domicilio ne '';
                $f[7]  = $telefono;
                $f[8]  = $email;
                $f[10] = $rfc;
                $f[11] = $razon;
                $f[14] = $cp;
                $f[15] = $entidad;
                $f[16] = $municipio;
                $f[17] = $colonia;

                $line = join('|', @f);
                $modificado = 1;
            }
            print $nf "$line\n";
        }
        flock($nf, LOCK_UN);
        close($nf);
    }

    if ($modificado) {
        responder_json({ status => 'ok', message => 'Datos de la clínica actualizados correctamente.' });
    } else {
        responder_json({ status => 'error', message => 'No se encontró la clínica solicitada.' });
    }
}

responder_json({ status => 'error', message => "Acción desconocida: $action" });
