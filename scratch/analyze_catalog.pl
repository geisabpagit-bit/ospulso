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

print "--- ANÁLISIS DE ITEMS EN CAT 16 (RAYOS X) ---\n";
open my $ih, '<:utf8', $items_file or die $!;
my %skus_by_cat;
my %skus_by_prefix;

while (<$ih>) {
    chomp;
    my ($id, $sku, $cat, $concepto) = split /\|/;
    next if $id eq 'ID_ITEM';
    
    my $prefix = ($sku =~ /^([A-Z]+)-/)? $1 : 'OTRO';
    $skus_by_cat{$cat}{$prefix}++;
    $skus_by_prefix{$prefix}{$cat}++;

    if ($cat == 16) {
        print "ID:$id | SKU:$sku | CAT:$cat | CONCEPTO:$concepto\n";
    }
}
close $ih;

print "\n--- DESGLOSE DE PREFIXES POR CATEGORIA ---\n";
foreach my $c (sort { $a <=> $b } keys %skus_by_cat) {
    my $cat_info = $cats{$c};
    my $cname = $cat_info ? "$cat_info->{name} (Dep: $cat_info->{dep_name})" : "DESCONOCIDA";
    print "CAT $c [$cname]: ";
    foreach my $p (sort keys %{$skus_by_cat{$c}}) {
        print "$p: $skus_by_cat{$c}{$p} | ";
    }
    print "\n";
}
