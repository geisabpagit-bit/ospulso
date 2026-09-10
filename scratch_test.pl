use strict;
use warnings;
open(my $fh, '<:encoding(UTF-8)', 'dat/negocios.dat') or die $!;
my $l1 = <$fh>;
my $l2 = <$fh>;
my $l3 = <$fh>;
my @hex = map { sprintf("%02x", ord($_)) } split(//, $l3);
print "HEX L3: ", join(' ', @hex), "\n";
print "ASCII L3: ", $l3, "\n";
