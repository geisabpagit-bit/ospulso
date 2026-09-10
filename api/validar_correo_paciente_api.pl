#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use lib '..';
use utils::db_manager qw(leer_tabla);

binmode STDOUT, ":utf8";
my $q = CGI->new;
my $correo = lc($q->param('correo') || '');
$correo =~ s/^\s+|\s+$//g;

if (!$correo || $correo !~ /\@/) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ existe => 0 });
    exit;
}

# 1. Checar en usuarios.dat
my $usuarios = leer_tabla('../dat/usuarios.dat', '!');
my $existe = 0;
foreach my $u (@$usuarios) {
    if (lc($u->[2] // '') eq $correo) {
        $existe = 1;
        last;
    }
}

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({ existe => $existe });
exit;
