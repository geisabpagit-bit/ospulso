#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

my $items_file = 'dat/catalogos_CLUE/QTSMP000116/catalogo_items_QTSMP000116.dat';

open my $ih, '<:utf8', $items_file or die $!;
while (<$ih>) {
    chomp;
    my ($id, $sku, $cat, $concepto) = split /\|/;
    next if $id eq 'ID_ITEM';
    if ($id >= 780 && $id <= 805) {
        print "ID:$id | SKU:$sku | CAT:$cat | CONCEPTO:$concepto\n";
    }
}
close $ih;
