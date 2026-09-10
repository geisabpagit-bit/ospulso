#!/usr/bin/perl

use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use JSON::PP qw(encode_json decode_json);
use lib '..';
require File::Spec->catfile('..', 'auth', 'check_session.pl');
require File::Spec->catfile('..', 'utils', 'catalogo_org_utils.pl');

my $q = CGI->new;
my $sd = check_session($q);
print $q->header(-type => 'application/json; charset=UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ ok => JSON::PP::false, msg => "Sesión inválida" });
    exit;
}

# Parámetro de búsqueda
my $term = lc($q->param('term') || '');

# Ruta al archivo de productos de la organización
my $id_empresa = $sd->{id_empresa};
my $rutas = catalogo_org_utils::obtener_rutas_catalogo($id_empresa);
my $file = $rutas->{productos};

open my $fh, '<:encoding(UTF-8)', $file or do {
    print encode_json({ ok => JSON::PP::false, msg => "No se pudo abrir $file" });
    exit;
};

my @results;
my $id = 0;

while (my $line = <$fh>) {
    chomp $line;
    next if $line =~ /^\s*$/; # saltar líneas vacías

    # Formato: nombre|precio|cantidad|presentacion|descripcion
    my ($nombre, $precio, $cantidad, $presentacion, $descripcion) = split /\|/, $line;

    $id++;
    next unless $nombre;

    # Filtrar por término
    if ($term eq '' || index(lc($nombre), $term) >= 0) {
        push @results, {
            id           => $id,
            nombre       => $nombre,
            precio       => $precio,
            cantidad     => $cantidad,
            presentacion => $presentacion,
            descripcion  => $descripcion
        };
    }
}
close $fh;

print encode_json({ ok => JSON::PP::true, results => \@results });
