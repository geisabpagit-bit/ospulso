#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
print $q->header(-type => 'application/json', -charset => 'UTF-8');

my $archivo_espe = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'especialidades.dat');
my $archivo_sub  = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'sub_especialidades.dat');

my @especialidades;
my @subespecialidades;

my $regs_espe = leer_tabla($archivo_espe, '\|');
if ($regs_espe) {
    foreach my $r (@$regs_espe) {
        next if @$r < 2;
        next if $r->[0] =~ /^ID_ESPE$/i;
        push @especialidades, {
            id => $r->[0],
            nombre => $r->[1]
        };
    }
}

my $regs_sub = leer_tabla($archivo_sub, '\|');
if ($regs_sub) {
    foreach my $r (@$regs_sub) {
        next if @$r < 3;
        next if $r->[0] =~ /^ID_ESPE$/i;
        push @subespecialidades, {
            id_espe => $r->[0],
            id_sub  => $r->[1],
            nombre  => $r->[2]
        };
    }
}

print encode_json({
    status => 'success',
    especialidades => \@especialidades,
    subespecialidades => \@subespecialidades
});
1;
