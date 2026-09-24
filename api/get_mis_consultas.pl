#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use FindBin;
use File::Spec;
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
        $mis_ids{$p->[0]} = 1;
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
sub obtener_nombre_medico { 
    my ($id) = @_; 
    return 'Dr(a). Desconocido' unless $id; 
    return "Dr(a). " . $medicos{$id} if exists $medicos{$id};
    my $padded = "DOC-" . sprintf("%03d", $id);
    return "Dr(a). " . $medicos{$padded} if exists $medicos{$padded};
    return $id; 
}

# 2. Leer consultas_clinicas.dat y filtrar las que correspondan a mis_ids
my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
my @consultas = ();
if (open(my $fh, "<:encoding(UTF-8)", $path)) {
    my $cabecera = <$fh>;
    while(<$fh>){ 
        chomp; 
        my @c = split /\|/, $_, -1; 
        if(exists $mis_ids{$c[1]}){ 
            my $json_str = $c[5];
            $json_str =~ s/\\n/\n/g if defined $json_str;
            my $data = {};
            eval { $data = decode_json($json_str); };
            
            my ($sec,$min,$hour,$mday,$mon,$year) = localtime($c[4]);
            my $fecha_str = sprintf("%04d-%02d-%02d %02d:%02d", $year+1900, $mon+1, $mday, $hour, $min);
            
            my $meds_count = 0;
            if ($data->{medicamentos} && ref($data->{medicamentos}) eq 'ARRAY') {
                $meds_count = scalar @{$data->{medicamentos}};
            }

            push @consultas, { 
                id_consulta => $c[0], 
                id_cita     => $c[2],
                id_medico   => $c[3],
                nombre_medico => obtener_nombre_medico($c[3]),
                timestamp   => $c[4],
                fecha       => $fecha_str,
                diagnostico => $data->{diagnostico_principal} || $data->{diagnostico} || 'Sin diagnóstico registrado',
                motivo      => $data->{motivo} || 'Consulta general',
                meds_count  => $meds_count
            }; 
        } 
    }
    close $fh;
}

# Ordenar por fecha desc (las más recientes primero)
@consultas = sort { $b->{timestamp} <=> $a->{timestamp} } @consultas;

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({
    ok => 1,
    consultas => \@consultas,
    paciente => $session_data->{usuario}
});
exit;
