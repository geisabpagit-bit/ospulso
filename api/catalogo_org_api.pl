#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP qw(encode_json decode_json);
use FindBin;
use File::Spec;
use Fcntl qw(:flock);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

my $q  = CGI->new;
my $sd = check_session($q);

print $q->header(-type => 'application/json', -charset => 'UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ status => 'error', message => 'Sesion invalida' });
    exit;
}

# Solo Administrador Organizacion y Administrador Global
my $role = $sd->{role} || '';
unless ($role eq 'Administrador Organizacion' || $role eq 'Administrador Global') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $accion     = $q->param('accion') || '';
my $id_empresa = $sd->{id_empresa}   || 0;

# Resolver ID raiz del catalogo
my $id_raiz = catalogo_org_utils::resolver_id_raiz_catalogo($id_empresa);
unless ($id_raiz) {
    print encode_json({ status => 'error', message => 'Organizacion no identificada.' });
    exit;
}

my $rutas = catalogo_org_utils::obtener_rutas_catalogo($id_raiz);

# Asegurar que los archivos existen (idempotente)
catalogo_org_utils::crear_catalogo_org_desde_global($id_raiz)
    unless catalogo_org_utils::catalogo_org_existe($id_raiz);

# ──────────────────────────────────────────────────────────
# GET_CATALOGO_ORG — Lista servicios y productos de la org
# ──────────────────────────────────────────────────────────
if ($accion eq 'get_catalogo_org') {
    my (@s, @p);

    if (-e $rutas->{servicios}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{servicios});
        <$fh>; # cabecera
        while (<$fh>) {
            chomp;
            next if /^\s*$/;
            my @c = split /\|/, $_, -1;
            push @s, { id => $c[0], nombre => $c[1], precio => $c[2]+0, descripcion => $c[3]||'' };
        }
        close $fh;
    }

    if (-e $rutas->{productos}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{productos});
        <$fh>; # cabecera
        while (<$fh>) {
            chomp;
            next if /^\s*$/;
            my @c = split /\|/, $_, -1;
            push @p, { id => $c[0], nombre => $c[1], precio => $c[2]+0,
                        cantidad => $c[3]||0, presentacion => $c[4]||'', descripcion => $c[5]||'' };
        }
        close $fh;
    }

    print encode_json({ status => 'ok', servicios => \@s, productos => \@p, id_raiz => $id_raiz });

# ──────────────────────────────────────────────────────────
# ADD_ITEM — Agrega servicio o producto
# ──────────────────────────────────────────────────────────
} elsif ($accion eq 'add_item') {
    my $tipo   = $q->param('tipo')   || '';
    my $nombre = $q->param('nombre') || '';
    my $precio = $q->param('precio') || '0';
    my $desc   = $q->param('descripcion') || '';

    unless ($nombre && $tipo =~ /^(servicio|producto)$/) {
        print encode_json({ status => 'error', message => 'Datos incompletos.' });
        exit;
    }

    if ($tipo eq 'servicio') {
        my $file = $rutas->{servicios};
        # Generar nuevo ID
        my $max_id = 0;
        open(my $fh, '<:encoding(UTF-8)', $file);
        <$fh>;
        while (<$fh>) { chomp; my @c = split /\|/; $max_id = $c[0] if $c[0] > $max_id; }
        close $fh;
        my $new_id = $max_id + 1;

        open(my $fh_out, '>>:encoding(UTF-8)', $file) or die $!;
        flock($fh_out, LOCK_EX);
        print $fh_out "$new_id|$nombre|$precio|$desc\n";
        close $fh_out;
        print encode_json({ status => 'ok', id => $new_id });

    } elsif ($tipo eq 'producto') {
        my $cantidad     = $q->param('cantidad')     || '0';
        my $presentacion = $q->param('presentacion') || '';
        my $file = $rutas->{productos};
        my $max_id = 0;
        open(my $fh, '<:encoding(UTF-8)', $file);
        <$fh>;
        while (<$fh>) { chomp; my @c = split /\|/; $max_id = $c[0] if $c[0] > $max_id; }
        close $fh;
        my $new_id = $max_id + 1;

        open(my $fh_out, '>>:encoding(UTF-8)', $file) or die $!;
        flock($fh_out, LOCK_EX);
        print $fh_out "$new_id|$nombre|$precio|$cantidad|$presentacion|$desc\n";
        close $fh_out;
        print encode_json({ status => 'ok', id => $new_id });
    }

# ──────────────────────────────────────────────────────────
# EDIT_ITEM — Edita servicio o producto existente
# ──────────────────────────────────────────────────────────
} elsif ($accion eq 'edit_item') {
    my $tipo   = $q->param('tipo')   || '';
    my $id     = $q->param('id')     || '';
    my $nombre = $q->param('nombre') || '';
    my $precio = $q->param('precio') || '0';
    my $desc   = $q->param('descripcion') || '';

    unless ($id && $nombre && $tipo =~ /^(servicio|producto)$/) {
        print encode_json({ status => 'error', message => 'Datos incompletos.' });
        exit;
    }

    my $file = ($tipo eq 'servicio') ? $rutas->{servicios} : $rutas->{productos};
    my @lines;
    my $found = 0;

    open(my $fh, '<:encoding(UTF-8)', $file) or die $!;
    my $header = <$fh>;
    push @lines, $header;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        if ($c[0] eq $id) {
            $found = 1;
            if ($tipo eq 'servicio') {
                push @lines, "$id|$nombre|$precio|$desc\n";
            } else {
                my $cantidad     = $q->param('cantidad')     // $c[3];
                my $presentacion = $q->param('presentacion') // $c[4];
                push @lines, "$id|$nombre|$precio|$cantidad|$presentacion|$desc\n";
            }
        } else {
            push @lines, "$line\n";
        }
    }
    close $fh;

    unless ($found) {
        print encode_json({ status => 'error', message => 'Item no encontrado.' });
        exit;
    }

    open(my $fh_out, '>:encoding(UTF-8)', $file) or die $!;
    flock($fh_out, LOCK_EX);
    print $fh_out @lines;
    close $fh_out;

    print encode_json({ status => 'ok' });

# ──────────────────────────────────────────────────────────
# DELETE_ITEM — Elimina servicio o producto
# ──────────────────────────────────────────────────────────
} elsif ($accion eq 'delete_item') {
    my $tipo = $q->param('tipo') || '';
    my $id   = $q->param('id')   || '';

    unless ($id && $tipo =~ /^(servicio|producto)$/) {
        print encode_json({ status => 'error', message => 'Datos incompletos.' });
        exit;
    }

    my $file = ($tipo eq 'servicio') ? $rutas->{servicios} : $rutas->{productos};
    my @lines;
    my $found = 0;

    open(my $fh, '<:encoding(UTF-8)', $file) or die $!;
    my $header = <$fh>;
    push @lines, $header;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        if ($c[0] eq $id) { $found = 1; next; }
        push @lines, "$line\n";
    }
    close $fh;

    unless ($found) {
        print encode_json({ status => 'error', message => 'Item no encontrado.' });
        exit;
    }

    open(my $fh_out, '>:encoding(UTF-8)', $file) or die $!;
    flock($fh_out, LOCK_EX);
    print $fh_out @lines;
    close $fh_out;

    print encode_json({ status => 'ok' });

# ──────────────────────────────────────────────────────────
# SEED_FROM_GLOBAL — Reimportar desde catalogo global
# ──────────────────────────────────────────────────────────
} elsif ($accion eq 'seed_from_global') {
    my $dat_path    = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $serv_global = File::Spec->catfile($dat_path, 'servicios.dat');
    my $prod_global = File::Spec->catfile($dat_path, 'productos.dat');

    eval {
        # Sobreescribir con el catalogo global
        for my $pair ([$serv_global, $rutas->{servicios}], [$prod_global, $rutas->{productos}]) {
            my ($src, $dst) = @$pair;
            next unless -e $src;
            open(my $fh_in,  '<:encoding(UTF-8)', $src) or die $!;
            open(my $fh_out, '>:encoding(UTF-8)', $dst) or die $!;
            flock($fh_out, LOCK_EX);
            while (<$fh_in>) { print $fh_out $_; }
            close $fh_in;
            close $fh_out;
        }
    };

    if ($@) {
        print encode_json({ status => 'error', message => "Error: $@" });
        exit;
    }

    print encode_json({ status => 'ok', message => 'Catalogo importado desde global correctamente.' });

} else {
    print encode_json({ status => 'error', message => "Accion desconocida: $accion" });
}
