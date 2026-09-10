#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP qw(encode_json decode_json);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

my $q = CGI->new;
my $sd = check_session($q);

print $q->header(-type => 'application/json', -charset => 'UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ status => 'error', message => 'Sesión inválida.' });
    exit;
}

my $role = $sd->{role};
my $id_empresa = $sd->{id_empresa};

if ($role ne 'Administrador Organizacion' && $role ne 'Administrador Global') {
    print encode_json({ status => 'error', message => 'Permisos insuficientes.' });
    exit;
}

my $action = $q->param('action') || '';
my $rutas_cat = catalogo_org_utils::obtener_rutas_catalogo($id_empresa);
my $archivo_prod = $rutas_cat->{productos};

if ($action eq 'create' || $action eq 'update') {
    my $id_producto = $q->param('id_producto') || '';
    my $nombre      = $q->param('nombre') || '';
    my $precio      = $q->param('precio') || '0';
    my $cantidad    = $q->param('cantidad') || '0';
    my $presentacion = $q->param('presentacion') || '';
    my $descripcion = $q->param('descripcion') || '';

    $nombre =~ s/\|/ /g;
    $presentacion =~ s/\|/ /g;
    $descripcion =~ s/\|/ /g;
    $precio =~ s/[^\d\.]//g;
    $cantidad =~ s/[^\d]//g;

    if (!$nombre) {
        print encode_json({ status => 'error', message => 'El nombre es obligatorio.' });
        exit;
    }

    my @lineas = ();
    my $nuevo_id = 1;

    if (-e $archivo_prod) {
        open my $fh, '<:encoding(UTF-8)', $archivo_prod or do {
            print encode_json({ status => 'error', message => 'No se pudo leer el archivo de productos.' });
            exit;
        };
        my $cabecera = <$fh>;
        push @lineas, $cabecera;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            push @lineas, $line . "\n";
            my @f = split(/\|/, $line);
            if ($f[0] =~ /^\d+$/ && $f[0] >= $nuevo_id) {
                $nuevo_id = $f[0] + 1;
            }
        }
        close $fh;
    } else {
        push @lineas, "id|nombre|precio|cantidad|presentacion|descripcion\n";
    }

    if ($action eq 'create') {
        push @lineas, "$nuevo_id|$nombre|$precio|$cantidad|$presentacion|$descripcion\n";
    } else {
        if (!$id_producto) {
            print encode_json({ status => 'error', message => 'ID de producto no proporcionado para actualizar.' });
            exit;
        }
        my $actualizado = 0;
        for (my $i = 1; $i < @lineas; $i++) {
            my $line = $lineas[$i];
            chomp $line;
            my @f = split(/\|/, $line);
            if ($f[0] eq $id_producto) {
                $lineas[$i] = "$id_producto|$nombre|$precio|$cantidad|$presentacion|$descripcion\n";
                $actualizado = 1;
                last;
            }
        }
        if (!$actualizado) {
            print encode_json({ status => 'error', message => 'Producto no encontrado.' });
            exit;
        }
    }

    open my $fhw, '>:encoding(UTF-8)', $archivo_prod or do {
        print encode_json({ status => 'error', message => 'No se pudo escribir en el archivo de productos.' });
        exit;
    };
    print $fhw $_ foreach @lineas;
    close $fhw;

    print encode_json({ status => 'success', message => 'Producto guardado correctamente.' });
    exit;

} elsif ($action eq 'delete') {
    my $id_producto = $q->param('id_producto') || '';
    if (!$id_producto) {
        print encode_json({ status => 'error', message => 'ID de producto no proporcionado.' });
        exit;
    }

    my @lineas = ();
    if (-e $archivo_prod) {
        open my $fh, '<:encoding(UTF-8)', $archivo_prod or do {
            print encode_json({ status => 'error', message => 'No se pudo leer el archivo de productos.' });
            exit;
        };
        my $cabecera = <$fh>;
        push @lineas, $cabecera;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @f = split(/\|/, $line);
            if ($f[0] ne $id_producto) {
                push @lineas, $line . "\n";
            }
        }
        close $fh;
    }

    open my $fhw, '>:encoding(UTF-8)', $archivo_prod or do {
        print encode_json({ status => 'error', message => 'No se pudo escribir en el archivo de productos.' });
        exit;
    };
    print $fhw $_ foreach @lineas;
    close $fhw;

    print encode_json({ status => 'success', message => 'Producto eliminado correctamente.' });
    exit;
}

print encode_json({ status => 'error', message => 'Acción no válida.' });
