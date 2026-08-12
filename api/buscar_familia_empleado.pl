#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use FindBin;
use lib "$FindBin::Bin/..";
use utils::db_manager qw(leer_tabla);

# Forzamos STDOUT a utf8
binmode STDOUT, ":utf8";

require '../auth/check_session.pl';
my $session_data = check_session();
unless ($session_data->{session_ok}) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Sesión caducada."});
    exit;
}

my $q = CGI->new;
my $num_empleado = $q->param('num_empleado') || '';
$num_empleado =~ s/^\s+|\s+$//g;

if ($num_empleado eq '') {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => 'Número de empleado no proporcionado'});
    exit;
}

my $archivo_empleados = "$FindBin::Bin/../dat/empleadosmun.dat";
my $empleados = leer_tabla($archivo_empleados, '!');

my @resultados;

foreach my $e (@$empleados) {
    if (defined $e->[0] && $e->[0] eq $num_empleado) {
        push @resultados, {
            id => $e->[0],
            nombre => $e->[1] // '',
            relacion => $e->[2] // ''
        };
    }
}

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({
    ok => 1,
    resultados => \@resultados
});
exit;
