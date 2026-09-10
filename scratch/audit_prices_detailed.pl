#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

my $dir = 'dat/catalogos_CLUE/QTSMP000116';
my $deps_file  = "$dir/departamentos_QTSMP000116.dat";
my $cats_file  = "$dir/categorias_QTSMP000116.dat";
my $items_file = "$dir/catalogo_items_QTSMP000116.dat";
my $precios_file = "$dir/catalogo_precios_QTSMP000116.dat";

my %deps;
open my $dh, '<:utf8', $deps_file or die $!;
while (<$dh>) { chomp; my ($id, $name) = split /\|/; $deps{$id} = $name if $id ne 'ID_DEP'; }
close $dh;

my %cats;
open my $ch, '<:utf8', $cats_file or die $!;
while (<$ch>) { chomp; my ($id, $dep_id, $name) = split /\|/; $cats{$id} = { dep_id => $dep_id, dep_name => $deps{$dep_id} // '', name => $name } if $id ne 'ID_CAT'; }
close $ch;

my %items;
open my $ih, '<:utf8', $items_file or die $!;
while (<$ih>) { chomp; my ($id, $sku, $cat_id, $concepto) = split /\|/; $items{$id} = { sku => $sku, cat_id => $cat_id, concepto => $concepto } if $id ne 'ID_ITEM'; }
close $ih;

my %precios;
open my $ph, '<:utf8', $precios_file or die $!;
while (<$ph>) {
    chomp;
    my ($id_p, $id_i, $tarifa, $precio) = split /\|/;
    next if $id_p eq 'ID_PRECIO';
    $precios{$id_i}{$tarifa} = $precio;
}
close $ph;

print "--- AUDITORÍA DE COBERTURA DE PRECIOS POR DEPARTAMENTO ---\n\n";

my %dep_stats;
foreach my $iid (keys %items) {
    my $cat_id = $items{$iid}{cat_id};
    my $dep_id = $cats{$cat_id}{dep_id} // 0;
    my $dep_name = $cats{$cat_id}{dep_name} // 'DESCONOCIDO';
    
    $dep_stats{$dep_name}{total_items}++;
    
    my $p_estandar = $precios{$iid}{'ESTANDAR'} // 0;
    my $p_municipio = $precios{$iid}{'MUNICIPIO'} // 0;
    
    if ($p_estandar > 0) { $dep_stats{$dep_name}{con_estandar}++; }
    if ($p_municipio > 0) { $dep_stats{$dep_name}{con_municipio}++; }
    if ($p_estandar == 0 && $p_municipio == 0) { $dep_stats{$dep_name}{sin_precio}++; }
}

printf "%-30s | %-12s | %-14s | %-15s | %-12s\n", "DEPARTAMENTO", "TOTAL ITEMS", "CON ESTÁNDAR", "CON MUNICIPIO", "SIN PRECIO";
print "-" x 92 . "\n";

foreach my $dname (sort keys %dep_stats) {
    printf "%-30s | %-12d | %-14d | %-15d | %-12d\n",
        $dname,
        $dep_stats{$dname}{total_items},
        $dep_stats{$dname}{con_estandar} // 0,
        $dep_stats{$dname}{con_municipio} // 0,
        $dep_stats{$dname}{sin_precio} // 0;
}
