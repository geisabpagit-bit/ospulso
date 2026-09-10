#!/usr/bin/perl
use strict;
use warnings;
use utf8;

my $items_file = 'dat/catalogos_CLUE/QTSMP000116/catalogo_items_QTSMP000116.dat';

open my $fh, '<:utf8', $items_file or die $!;
my @lines;
my $fixed_count = 0;

while (<$fh>) {
    chomp;
    my ($id, $sku, $cat, $concepto, $iva, $ind, $tiempo) = split /\|/, $_, 7;
    
    if ($id ne 'ID_ITEM') {
        # Fix 789-795: LAB- in CAT 16 -> CAT 15 (ANALISIS CLINICOS - LABORATORIO SANTIAGO)
        if ($id >= 789 && $id <= 795 && $cat == 16) {
            $cat = 15;
            $fixed_count++;
        }
        # Fix 796-814: US- in CAT 17 -> CAT 28 (ECOGRAFIA - ULTRASONIDO)
        elsif ($id >= 796 && $id <= 814 && $cat == 17) {
            $cat = 28;
            $fixed_count++;
        }
        # Fix 815-818: RX- in CAT 15 -> CAT 16 (RAYOS X - IMAGENOLOGIA)
        elsif ($id >= 815 && $id <= 818 && $cat == 15) {
            $cat = 16;
            $fixed_count++;
        }
        # Fix 760: CONS- in CAT 39 -> CAT 61 (HEMATOLOGIA)
        elsif ($id == 760 && $cat == 39) {
            $cat = 61;
            $fixed_count++;
        }
    }
    push @lines, join('|', $id, $sku, $cat, $concepto, $iva, $ind, $tiempo);
}
close $fh;

open my $out, '>:utf8', $items_file or die $!;
foreach my $l (@lines) {
    print $out "$l\n";
}
close $out;

print "Se corrigieron $fixed_count registros en $items_file\n";
