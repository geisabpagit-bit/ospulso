#!/usr/bin/perl

use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use JSON::PP qw(encode_json decode_json);
use lib '..';

my $q = CGI->new;
print $q->header(-type => 'application/json; charset=UTF-8');

# Parámetro de búsqueda
my $term = lc($q->param('term') || '');

# Ruta al archivo de productos
my $file = '../dat/productos.dat';

open my $fh, '<:encoding(UTF-8)', $file or do {
    print encode_json({ ok => JSON::false, msg => "No se pudo abrir $file" });
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

print encode_json({ ok => JSON::true, results => \@results });
