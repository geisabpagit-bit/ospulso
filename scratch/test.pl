use strict;
use warnings;
use JSON;
use FindBin;
use lib "$FindBin::Bin/../";
use utils::db_manager qw(leer_tabla);

my @cat = leer_tabla("$FindBin::Bin/../dat/categorias.dat");
print "ARRAY OF ARRAYREFS? " . ref($cat[0]) . "\n";
print "DUMP: " . encode_json(\@cat) . "\n";

my @cat_map = map { { id => $_->[0], nombre => $_->[1], desc => $_->[2] } } @cat;
print "MAPPED: " . encode_json(\@cat_map) . "\n";
