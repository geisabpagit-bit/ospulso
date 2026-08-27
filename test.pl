#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Data::Dumper;
use File::Spec;

use lib 'c:/xampp/htdocs/ospulso';
use utils::db_manager qw(leer_tabla);

my $f = 'c:/xampp/htdocs/ospulso/dat/catalogos_CLUE/QTSMP000116/motivos_QTSMP000116.dat';
my $m = leer_tabla($f);
print Dumper($m);
