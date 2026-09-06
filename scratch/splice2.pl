#!/usr/bin/perl
use strict;
use warnings;
use File::Slurp;

my $file = "c:/xampp/htdocs/ospulso/views/render_dashboard_principal.pl";
my @lines = read_file($file);

my $new_block = read_file("c:/xampp/htdocs/ospulso/scratch/recepcionista_block.txt");

# Remove lines 543 to 711 (indices 542 to 710)
splice(@lines, 542, 711 - 542 + 1, $new_block);

write_file($file, @lines);
print "Spliced correctly by line numbers!\n";
