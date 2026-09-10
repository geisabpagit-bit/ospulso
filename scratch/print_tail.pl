#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

open my $fh, '<:utf8', 'dat/catalogos_CLUE/QTSMP000116/catalogo_items_QTSMP000116.dat' or die $!;
while (<$fh>) {
    chomp;
    my ($id, $sku, $cat, $concept) = split /\|/;
    next if $id eq 'ID_ITEM';
    if ($id >= 820) {
        print "ID:$id | SKU:$sku | CAT:$cat | $concept\n";
    }
}
close $fh;
