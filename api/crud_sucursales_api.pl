#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use Encode qw(decode_utf8);

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

my $id_org_matriz = $sd->{id_empresa};
my $action        = $q->param('action') // '';

my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');

if ($action eq 'create') {
    my $nombre_sucursal = decode_utf8($q->param('nombre_sucursal') // '');
    my $telefono        = decode_utf8($q->param('telefono')        // '');
    my $domicilio       = decode_utf8($q->param('domicilio')       // '');

    $nombre_sucursal =~ s/^\s+|\s+$//g;
    $telefono        =~ s/^\s+|\s+$//g;
    $domicilio       =~ s/^\s+|\s+$//g;

    $telefono = "No aplica" if $telefono eq '';
    $domicilio = "No aplica" if $domicilio eq '';

    if (!$nombre_sucursal) {
        print encode_json({ status => 'error', message => 'El nombre de la sucursal es obligatorio.' });
        exit;
    }

    # Generar ID de sucursal
    my $id_sucursal = int(rand(999999)) + 200000;

    # Fechas
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $fecha_inicio = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $fecha_fin    = "2099-12-31"; 

    my @campos_negocio = (
        $id_sucursal,    # 1. ID
        $nombre_sucursal,# 2. NOMBRE_NEGOCIO
        $id_org_matriz,  # 3. ID_MATRIZ
        "1",             # 4. Activo
        $fecha_inicio,   # 5. inicio_suscripcion
        $fecha_fin,      # 6. fin_suscripcion
        $domicilio,      # 7. domicilio
        $telefono,       # 8. telefono
        "No aplica",     # 9. contacto_email
        "No aplica",     # 10. logo_url
        "No aplica",     # 11. rfc
        "No aplica",     # 12. razon_social
        "No aplica",     # 13. id_tienda
        "No aplica",     # 14. id_vendedor
        "", "", "", "", "", "", "", "" # Resto
    );

    my $registro_sucursal = join("|", @campos_negocio);

    eval {
        use Fcntl qw(:flock);
        open(my $fh_neg, '>>:utf8', $archivo_negocios) or die "negocios: $!";
        flock($fh_neg, 2);
        print $fh_neg "$registro_sucursal\n";
        close($fh_neg);
    };

    if ($@) {
        print encode_json({ status => 'error', message => 'Error al guardar la sucursal: ' . $@ });
        exit;
    }

    print encode_json({ status => 'success', id_sucursal => $id_sucursal });
    exit;
}

elsif ($action eq 'update') {
    my $id_sucursal     = decode_utf8($q->param('id_sucursal_edit') // '');
    my $nombre_sucursal = decode_utf8($q->param('nombre_sucursal') // '');
    my $telefono        = decode_utf8($q->param('telefono')        // '');
    my $domicilio       = decode_utf8($q->param('domicilio')       // '');

    $nombre_sucursal =~ s/^\s+|\s+$//g;
    $telefono        =~ s/^\s+|\s+$//g;
    $domicilio       =~ s/^\s+|\s+$//g;

    $telefono = "No aplica" if $telefono eq '';
    $domicilio = "No aplica" if $domicilio eq '';

    if (!$id_sucursal || !$nombre_sucursal) {
        print encode_json({ status => 'error', message => 'Datos obligatorios faltantes.' });
        exit;
    }

    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    my @nuevos_negocios = ();
    my $encontrado = 0;

    foreach my $r (@$regs_negocios) {
        if (@$r >= 3 && $r->[0] eq $id_sucursal) {
            # Validar pertenencia a la organización
            if ($r->[2] ne $id_org_matriz) {
                print encode_json({ status => 'error', message => 'No autorizado.' });
                exit;
            }
            $r->[1] = $nombre_sucursal;
            $r->[6] = $domicilio;
            $r->[7] = $telefono;
            $encontrado = 1;
        }
        push @nuevos_negocios, join('|', @$r);
    }

    if (!$encontrado) {
        print encode_json({ status => 'error', message => 'Sucursal no encontrada.' });
        exit;
    }

    eval {
        actualizar_archivo($archivo_negocios, "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud", \@nuevos_negocios);
    };

    if ($@) {
        print encode_json({ status => 'error', message => 'Error al actualizar la sucursal: ' . $@ });
        exit;
    }

    print encode_json({ status => 'success' });
    exit;
}

elsif ($action eq 'toggle_status') {
    my $id_sucursal = decode_utf8($q->param('id_sucursal') // '');

    if (!$id_sucursal) {
        print encode_json({ status => 'error', message => 'ID de sucursal requerido.' });
        exit;
    }

    my $regs_negocios = leer_tabla($archivo_negocios, '\|');
    my @nuevos_negocios = ();
    my $encontrado = 0;

    foreach my $r (@$regs_negocios) {
        if (@$r >= 3 && $r->[0] eq $id_sucursal) {
            # Validar pertenencia a la organización
            if ($r->[2] ne $id_org_matriz) {
                print encode_json({ status => 'error', message => 'No autorizado.' });
                exit;
            }
            $r->[3] = ($r->[3] eq '1') ? '0' : '1';
            $encontrado = 1;
        }
        push @nuevos_negocios, join('|', @$r);
    }

    if (!$encontrado) {
        print encode_json({ status => 'error', message => 'Sucursal no encontrada.' });
        exit;
    }

    eval {
        actualizar_archivo($archivo_negocios, "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud", \@nuevos_negocios);
    };

    if ($@) {
        print encode_json({ status => 'error', message => 'Error al cambiar estado: ' . $@ });
        exit;
    }

    print encode_json({ status => 'success' });
    exit;
}

else {
    print encode_json({ status => 'error', message => 'Acción no válida.' });
    exit;
}
1;
