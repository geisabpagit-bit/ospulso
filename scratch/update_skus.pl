#!/usr/bin/perl
use strict;
use warnings;
use utf8;

my $file = 'dat/catalogos_CLUE/QTSMP000116/catalogo_items_QTSMP000116.dat';

open my $fh, '<:utf8', $file or die $!;
my @lines;
while (<$fh>) {
    chomp;
    my ($id, $sku, $cat, $concept, $iva, $ind, $tiempo) = split /\|/, $_, 7;
    if ($id eq '830') {
        $sku = 'CONS-0830';
    }
    elsif ($id eq '831') {
        $sku = 'CONS-0831';
    }
    elsif ($id eq '832') {
        $sku = 'CONS-0832';
    }
    push @lines, join('|', $id, $sku, $cat, $concept, $iva, $ind, $tiempo);
}
close $fh;

open my $out, '>:utf8', $file or die $!;
foreach my $l (@lines) {
    print $out "$l\n";
}
close $out;

print "SKUs actualizados correctamente para IDs 830, 831 y 832.\n";
