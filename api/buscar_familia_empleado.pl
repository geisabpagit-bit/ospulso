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
my $clues = $q->param('clues') || '';
$num_empleado =~ s/^\s+|\s+$//g;
$clues =~ s/^\s+|\s+$//g;

if ($num_empleado eq '') {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => 'Número de empleado no proporcionado'});
    exit;
}

my $sufijo = $clues ? "_${clues}" : "";
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
my $archivo_empleados = catalogo_org_utils::obtener_rutas_por_clue($clues)->{empleadosmun};
my $empleados = leer_tabla($archivo_empleados, '!');

my $archivo_dependencias = catalogo_org_utils::obtener_rutas_por_clue($clues)->{dependencia};
my $deps = leer_tabla($archivo_dependencias, '!');
my %dep_map;
if (ref $deps eq 'ARRAY') {
    foreach my $d (@$deps) {
        if (defined $d->[0]) {
            $dep_map{$d->[0]} = $d->[1] // "";
        }
    }
}

my @resultados;

foreach my $e (@$empleados) {
    if (defined $e->[0] && $e->[0] eq $num_empleado) {
        my $id_dep = $e->[4] // '';
        my $nombre_dep = $dep_map{$id_dep} || "ID: $id_dep";
        push @resultados, {
            id => $e->[0],
            nombre => $e->[1] // '',
            relacion => $e->[2] // '',
            dependencia => $nombre_dep
        };
    }
}

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({
    ok => 1,
    resultados => \@resultados
});
exit;
