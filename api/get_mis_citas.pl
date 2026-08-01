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

# 1. Encontrar todos los ID_PACIENTE asociados a este correo en pacientes.dat
my $regs_pacientes = leer_tabla('../dat/pacientes.dat', '\|');
my %mis_ids = ();
foreach my $p (@$regs_pacientes) {
    next if @$p < 6;
    my $c = lc($p->[5] // '');
    $c =~ s/^\s+|\s+$//g;
    if ($c eq $correo_paciente) {
        $mis_ids{$p->[0]} = {
            id_medico => $p->[1],
            nombre => $p->[2],
            tenant => $p->[13]
        };
    }
}

# Pre-cargar diccionarios para nombres reales
my %medicos = ();
my $regs_usuarios = leer_tabla('../dat/usuarios.dat', '!');
if ($regs_usuarios) {
    foreach my $u (@$regs_usuarios) {
        $medicos{$u->[0]} = $u->[1] if @$u >= 2;
    }
}

my %clinicas = ();
my $regs_negocios = leer_tabla('../dat/negocios.dat', '\|');
if ($regs_negocios) {
    foreach my $n (@$regs_negocios) {
        $clinicas{$n->[0]} = $n->[1] if @$n >= 2;
    }
}

# 2. Leer citas.dat y filtrar las que correspondan a mis_ids
# ID_CITA|ID_PACIENTE|FECHA_HORA|ID_MEDICO|STATUS|TIPO_CONSULTA|NOTAS|TENANT
my $regs_citas = leer_tabla('../dat/citas.dat', '\|');
my @citas = ();

if ($regs_citas) {
    foreach my $c (@$regs_citas) {
        next if @$c < 8;
        my $id_cita = $c->[0];
        my $id_pac  = $c->[1];
        
        if (exists $mis_ids{$id_pac}) {
            my $id_medico = $c->[3];
            my $tenant = $c->[7];
            my $id_org = (split(/:/, $tenant))[0];
            
            push @citas, {
                id_cita => $id_cita,
                fecha_hora => $c->[2],
                id_medico => $id_medico,
                status => $c->[4],
                tipo_consulta => $c->[5],
                notas => $c->[6],
                tenant => $tenant,
                # Meta
                medico_nombre => $medicos{$id_medico} // "Médico $id_medico",
                clinica_nombre => $clinicas{$id_org} // "Clínica $id_org"
            };
        }
    }
}

# Ordenar por fecha desc (las más recientes primero)
@citas = sort { $b->{fecha_hora} cmp $a->{fecha_hora} } @citas;

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({
    ok => 1,
    citas => \@citas,
    paciente => $session_data->{usuario}
});
exit;
