#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json decode_json);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(guardar_registro actualizar_archivo);

my $q = CGI->new;
my $session_data = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($session_data->{session_ok}) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada' });
    exit;
}

my %payload;
foreach my $p ($q->param) {
    my @v = $q->param($p);
    $payload{$p} = scalar(@v) > 1 ? \@v : $v[0];
}
if ($payload{medicamentos_json}) { eval { $payload{medicamentos} = decode_json($payload{medicamentos_json}); }; }

my $id_cita = $q->param('id_cita') || $payload{id_cita} || '';
my $id_paciente = $q->param('id_paciente') || $q->param('id') || $payload{id_paciente} || '';
my $id_medico = $session_data->{id_medico} || 'DOC-000';

$id_cita =~ s/^\s+|\s+$//g;
$id_paciente =~ s/^\s+|\s+$//g;

if (!$id_paciente) {
    print encode_json({ ok => JSON::false, msg => 'Falta id_paciente' });
    exit;
}

my $id_consulta = 'CONS-' . time() . '-' . int(rand(1000));
$payload{id_consulta} = $id_consulta;

# 1. Guardar la consulta
my $consultas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
unless (-e $consultas_file) {
    open my $fh_new, '>:encoding(UTF-8)', $consultas_file;
    print $fh_new "id_consulta|id_paciente|id_cita|id_medico|timestamp|payload_json\n";
    close $fh_new;
}
my $json_str = encode_json(\%payload);
$json_str =~ s/\r|\n/\\n/g; # Escapar saltos de línea para mantener formato CSV
my $linea = join('|', $id_consulta, $id_paciente, $id_cita, $id_medico, time(), $json_str);
utils::db_manager::guardar_registro($consultas_file, $linea);

# 2. Sincronizar estado en agenda.dat (citas.dat)
my $citas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
if (-e $citas_file && open my $fh_in, '<:encoding(UTF-8)', $citas_file) {
    my @lineas = <$fh_in>;
    close $fh_in;
    
    my @nuevas_lineas;
    my $cabecera = shift @lineas;
    chomp $cabecera if defined $cabecera;
    
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $hoy_fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $hoy_hora  = sprintf("%02d:%02d", $hour, $min);
    my $modificado = 0;
    
    foreach my $l (@lineas) {
        chomp $l;
        my @c = split /\|/, $l, -1;
        my $c0_clean = $c[0] // '';
        $c0_clean =~ s/^\s+|\s+$//g;
        my $c_id_pac = $c[2] // '';
        $c_id_pac =~ s/^\s+|\s+$//g;
        my $c_fec = $c[3] // '';
        $c_fec =~ s/^\s+|\s+$//g;
        
        my $match = 0;
        if ($id_cita && $c0_clean eq $id_cita) {
            $match = 1;
        } elsif (!$id_cita && $c_id_pac eq $id_paciente && $c_fec eq $hoy_fecha && ($c[8]//'') !~ /^(Atendida|Cancelada)$/i) {
            $match = 1;
        }
        
        if ($match) {
            $c[3] = $hoy_fecha; # Asegurar fecha de atención real en el cierre
            $c[8] = 'Atendida';
            $l = join('|', @c);
            $modificado = 1;
        }
        push @nuevas_lineas, $l;
    }
    if ($modificado) {
        utils::db_manager::actualizar_archivo($citas_file, $cabecera, \@nuevas_lineas);
    }
}

# 3. Limpiar draft de autosave
my $draft_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consulta_draft.dat');
my $id_draft = "DRAFT-$id_paciente"; 
if (-e $draft_file) {
    if (open my $fh_d, '<:encoding(UTF-8)', $draft_file) {
        my @lineas = <$fh_d>;
        close $fh_d;
        
        my @nuevas;
        my $cab = shift @lineas;
        chomp $cab if defined $cab;
        
        foreach my $l (@lineas) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            push @nuevas, $l unless $c[0] eq $id_draft;
        }
        utils::db_manager::actualizar_archivo($draft_file, $cab, \@nuevas);
    }
}

print encode_json({
    ok          => JSON::true,
    msg         => 'Consulta guardada correctamente y borrador eliminado.',
    id_consulta => $id_consulta,
    id_paciente => $id_paciente
});
