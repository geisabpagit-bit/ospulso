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
foreach my $p ($q->param) { $payload{$p} = $q->param($p); }
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
if ($id_cita) {
    my $citas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
    if (open my $fh_in, '<:encoding(UTF-8)', $citas_file) {
        my @lineas = <$fh_in>;
        close $fh_in;
        
        my @nuevas_lineas;
        my $cabecera = shift @lineas;
        chomp $cabecera if defined $cabecera;
        
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
        my $hoy_fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
        my $hoy_hora  = sprintf("%02d:%02d", $hour, $min);
        
        foreach my $l (@lineas) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            my $c0_clean = $c[0] // '';
            $c0_clean =~ s/^\s+|\s+$//g;
            
            if ($c0_clean eq $id_cita) {
                my $fecha_cita = $c[3] // '';
                my $hora_cita  = $c[4] // '';
                
                if ($fecha_cita ne $hoy_fecha || ($fecha_cita eq $hoy_fecha && $hora_cita lt $hoy_hora)) {
                    $c[3] = $hoy_fecha;
                    $c[4] = $hoy_hora;
                    my $h_fin; my $m_fin;
                    if ($c[5]) {
                        my ($ho, $mo) = split /:/, $hora_cita;
                        my ($hf, $mf) = split /:/, $c[5];
                        my $dur = ($hf*60+$mf) - ($ho*60+$mo);
                        $dur = 30 if $dur <= 0;
                        my $tot = $hour*60 + $min + $dur;
                        $h_fin = int($tot/60); $m_fin = $tot%60;
                    } else {
                        my $tot = $hour*60 + $min + 30;
                        $h_fin = int($tot/60); $m_fin = $tot%60;
                    }
                    $c[5] = sprintf("%02d:%02d", $h_fin, $m_fin);
                    $c[8] = 'Atendida';
                } else {
                    $c[8] = 'Atendida';
                }
                $l = join('|', @c);
            }
            push @nuevas_lineas, $l;
        }
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
