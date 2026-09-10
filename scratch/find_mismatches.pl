#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

my $items_file = 'dat/catalogos_CLUE/QTSMP000116/catalogo_items_QTSMP000116.dat';
my $cats_file = 'dat/catalogos_CLUE/QTSMP000116/categorias_QTSMP000116.dat';
my $deps_file = 'dat/catalogos_CLUE/QTSMP000116/departamentos_QTSMP000116.dat';

my %deps;
open my $dh, '<:utf8', $deps_file or die $!;
while (<$dh>) {
    chomp;
    my ($id, $name) = split /\|/;
    $deps{$id} = $name if $id ne 'ID_DEP';
}
close $dh;

my %cats;
open my $ch, '<:utf8', $cats_file or die $!;
while (<$ch>) {
    chomp;
    my ($id, $dep, $name) = split /\|/;
    $cats{$id} = { dep_id => $dep, dep_name => $deps{$dep} // '', name => $name } if $id ne 'ID_CAT';
}
close $ch;

print "--- AUDITORÍA DE INCONSISTENCIAS SKU vs DEPARTAMENTO/CATEGORÍA ---\n\n";

open my $ih, '<:utf8', $items_file or die $!;
my @mismatches;

while (<$ih>) {
    chomp;
    my ($id, $sku, $cat, $concepto) = split /\|/;
    next if $id eq 'ID_ITEM';
    
    my $cat_info = $cats{$cat} // { dep_id => 0, dep_name => 'DESCONOCIDO', name => 'DESCONOCIDA' };
    my $dep_name = $cat_info->{dep_name};
    my $cat_name = $cat_info->{name};
    
    my $expected_dep = '';
    my $prefix = ($sku =~ /^([A-Z]+)-/)? $1 : '';
    
    if ($prefix eq 'CONS') { $expected_dep = 'CONSULTAS'; }
    elsif ($prefix eq 'SERV') { $expected_dep = 'SERVICIOS'; }
    elsif ($prefix eq 'LAB') { $expected_dep = 'LABORATORIO SANTIAGO'; }
    elsif ($prefix eq 'RX') { $expected_dep = 'IMAGENOLOGIA'; }
    elsif ($prefix eq 'LABF') { $expected_dep = 'LABORATORIO FRANCISCO'; }
    elsif ($prefix eq 'US' || $prefix eq 'USG') { $expected_dep = 'ULTRASONIDO'; }
    elsif ($prefix eq 'QX') { $expected_dep = 'CIRUGIAS'; }
    elsif ($prefix eq 'PATP') { $expected_dep = 'PATOLOGIA DR PINEDO'; }
    elsif ($prefix eq 'PATG') { $expected_dep = 'PATOLOGIA DR GALLEGOS'; }
    
    if ($expected_dep && $dep_name ne $expected_dep) {
        push @mismatches, {
            id => $id,
            sku => $sku,
            cat => $cat,
            dep_actual => $dep_name,
            cat_actual => $cat_name,
            dep_esperado => $expected_dep,
            concepto => $concepto
        };
    }
}
close $ih;

print "Total Inconsistencias Encontradas: " . scalar(@mismatches) . "\n\n";
foreach my $m (@mismatches) {
    print "ID:$m->{id} | SKU:$m->{sku} | CAT_ACTUAL:$m->{cat} ($m->{dep_actual} -> $m->{cat_actual}) | DEPARTAMENTO ESPERADO: $m->{dep_esperado} | CONCEPTO: $m->{concepto}\n";
}
