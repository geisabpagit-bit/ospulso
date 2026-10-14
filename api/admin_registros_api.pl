#!/usr/bin/perl
BEGIN { eval "use cPanelUserConfig;"; }
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use File::Temp qw(tempfile);
use Fcntl qw(:flock);
use Time::Piece;
use Encode qw(encode_utf8 decode_utf8);
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

# RBAC: Exclusivo para Administrador Global
if (!$sd->{session_ok} || ($sd->{role} // '') ne 'Administrador Global') {
    print encode_json({
        status  => 'error',
        message => 'Acceso denegado: Esta función requiere privilegios de Administrador Global.'
    });
    exit;
}

my $action = decode_utf8($q->param('action') // 'listar');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');

my $today = eval { localtime->strftime('%Y-%m-%d') } || '2026-10-14';
my $today_tp = eval { Time::Piece->strptime($today, '%Y-%m-%d') };

if ($action eq 'listar') {
    my @registros = ();
    my %usuarios_admin = ();

    # 1. Mapear administradores de cada clínica desde usuarios.dat
    if (-e $archivo_usuarios && open(my $uf, '<:encoding(UTF-8)', $archivo_usuarios)) {
        <$uf>; # Saltear cabecera
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

    # 2. Leer negocios.dat
    my %kpis = (
        total       => 0,
        demos       => 0,
        activas     => 0,
        por_vencer  => 0,
        suspendidas => 0
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

            # Omitir registros de sistema interno o sucursales hijas secundarias si se desea
            my $u_info = $usuarios_admin{$id_neg} // {
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

            if ($activo eq '0') {
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
                id             => $id_neg,
                nombre_negocio => $nom_neg,
                id_matriz      => $id_mat,
                activo         => $activo,
                inicio         => $ini_susc,
                fin            => $fin_susc,
                dias_restantes => $dias_restantes,
                estado_visual  => $estado_visual,
                telefono       => $tel,
                email          => $email,
                titular_nombre => $u_info->{nombre},
                titular_email  => $u_info->{correo},
                rfc            => $rfc,
                razon_social   => $razon,
                domicilio      => $dom,
                codigo_postal  => $cp,
                municipio      => $mun,
                entidad        => $entidad,
                colonia        => $colonia
            };
        }
        close($nf);
    }

    print encode_json({
        status    => 'ok',
        registros => \@registros,
        kpis      => \%kpis
    });
    exit;
}

if ($action eq 'obtener') {
    my $id_target = decode_utf8($q->param('id') // '');
    if (!$id_target) {
        print encode_json({ status => 'error', message => 'ID de negocio no especificado.' });
        exit;
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
        print encode_json({ status => 'ok', registro => $registro });
    } else {
        print encode_json({ status => 'error', message => 'Registro no encontrado.' });
    }
    exit;
}

if ($action eq 'actualizar_estado') {
    my $id_target     = decode_utf8($q->param('id') // '');
    my $nuevo_estado  = decode_utf8($q->param('activo') // '1');
    $nuevo_estado     = ($nuevo_estado eq '1' || $nuevo_estado eq 'true') ? '1' : '0';

    if (!$id_target) {
        print encode_json({ status => 'error', message => 'ID requerido.' });
        exit;
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
        print encode_json({ status => 'ok', message => 'Estado actualizado exitosamente.' });
    } else {
        print encode_json({ status => 'error', message => 'No se encontró el registro para actualizar.' });
    }
    exit;
}

if ($action eq 'extender_demo') {
    my $id_target = decode_utf8($q->param('id') // '');
    my $dias_ext  = int($q->param('dias') // 30);
    $dias_ext = 30 if $dias_ext <= 0;

    if (!$id_target) {
        print encode_json({ status => 'error', message => 'ID requerido.' });
        exit;
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
        print encode_json({
            status => 'ok',
            message => "Periodo extendido exitosamente +$dias_ext días hasta $nueva_fecha_fin.",
            nueva_fecha => $nueva_fecha_fin
        });
    } else {
        print encode_json({ status => 'error', message => 'No se encontró el registro.' });
    }
    exit;
}

if ($action eq 'editar') {
    my $id_target  = decode_utf8($q->param('id') // '');
    my $nombre     = decode_utf8($q->param('nombre_negocio') // '');
    my $telefono   = decode_utf8($q->param('telefono') // '');
    my $email      = decode_utf8($q->param('contacto_email') // '');
    my $rfc        = decode_utf8($q->param('rfc') // '');
    my $razon      = decode_utf8($q->param('razon_social') // '');
    my $domicilio  = decode_utf8($q->param('domicilio') // '');
    my $cp         = decode_utf8($q->param('codigo_postal') // '');
    my $entidad    = decode_utf8($q->param('entidad') // '');
    my $municipio  = decode_utf8($q->param('municipio') // '');
    my $colonia    = decode_utf8($q->param('colonia') // '');

    if (!$id_target || !$nombre) {
        print encode_json({ status => 'error', message => 'El ID y el Nombre de la clínica son obligatorios.' });
        exit;
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
        print encode_json({ status => 'ok', message => 'Datos de la clínica actualizados correctamente.' });
    } else {
        print encode_json({ status => 'error', message => 'No se encontró la clínica solicitada.' });
    }
    exit;
}

print encode_json({ status => 'error', message => "Acción desconocida: $action" });
exit;
