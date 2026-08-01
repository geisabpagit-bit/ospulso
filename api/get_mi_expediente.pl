#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use lib '..';
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

my $correo_paciente = lc($session_data->{uid} // '');
if ($session_data->{role} ne 'Paciente' || !$correo_paciente) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Acceso denegado."});
    exit;
}

# 1. Obtener mis IDs
my $regs_pacientes = leer_tabla('../dat/pacientes.dat', '\|');
my %mis_ids = ();
my @alergias_global = ();
my @padecimientos_global = ();

if ($regs_pacientes) {
    foreach my $p (@$regs_pacientes) {
        next if @$p < 6;
        my $c = lc($p->[5] // '');
        $c =~ s/^\s+|\s+$//g;
        if ($c eq $correo_paciente) {
            $mis_ids{$p->[0]} = 1;
        }
    }
}

# 2. Recetas
my @recetas = ();
if (-e '../dat/recetas.dat') {
    my $regs = leer_tabla('../dat/recetas.dat', '\|');
    if ($regs) {
        foreach my $r (@$regs) {
            next if @$r < 7;
            if (exists $mis_ids{$r->[2]}) {
                push @recetas, {
                    id_receta => $r->[0],
                    id_consulta => $r->[1],
                    fecha => $r->[4],
                    folio => $r->[5],
                    diagnostico => $r->[6]
                };
            }
        }
    }
}

# 3. Estudios
my @estudios = ();
if (-e '../dat/estudios.dat') {
    my $regs = leer_tabla('../dat/estudios.dat', '\|');
    if ($regs) {
        foreach my $e (@$regs) {
            next if @$e < 6;
            if (exists $mis_ids{$e->[1]}) {
                push @estudios, {
                    id_estudio => $e->[0],
                    fecha => $e->[2],
                    modalidad => $e->[3],
                    descripcion => $e->[4],
                    ruta => $e->[5]
                };
            }
        }
    }
}

# 4. Consultas (Solo metadatos)
my @consultas = ();
if (-e '../dat/consultas_clinicas.dat') {
    my $regs = leer_tabla('../dat/consultas_clinicas.dat', '\|');
    if ($regs) {
        foreach my $c (@$regs) {
            next if @$c < 5;
            if (exists $mis_ids{$c->[1]}) {
                push @consultas, {
                    id_consulta => $c->[0],
                    fecha_ts => $c->[4]
                };
            }
        }
    }
}

# Ordenamiento
@recetas = sort { $b->{fecha} cmp $a->{fecha} } @recetas;
@estudios = sort { $b->{fecha} cmp $a->{fecha} } @estudios;
@consultas = sort { $b->{fecha_ts} <=> $a->{fecha_ts} } @consultas;

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({
    ok => 1,
    recetas => \@recetas,
    estudios => \@estudios,
    consultas => \@consultas
});
exit;
