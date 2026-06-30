#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON qw(encode_json decode_json);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(actualizar_archivo);

my $q = CGI->new;
my $session_data = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($session_data->{session_ok}) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada' });
    exit;
}

my $id_paciente = $q->param('id_paciente') || '';
my $id_cita     = $q->param('id_cita') || '';
my $id_medico   = $session_data->{id_medico} || $q->param('id_medico') || 'DOC-000';
my $step        = $q->param('current_step') || 0;

if (!$id_paciente) {
    print encode_json({ ok => JSON::false, msg => 'Falta id_paciente' });
    exit;
}

# Recopilar todos los parámetros en un payload
my %payload;
foreach my $p ($q->param) {
    $payload{$p} = $q->param($p);
}
# Decodificar medicamentos_json si existe
if ($payload{medicamentos_json}) {
    eval { $payload{medicamentos} = decode_json($payload{medicamentos_json}); };
}

my $draft_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consulta_draft.dat');

# Estructura del draft: id_draft|id_paciente|id_cita|id_medico|current_step|payload_json|timestamp
my $id_draft = "DRAFT-$id_paciente"; 
my $json_str = encode_json(\%payload);
$json_str =~ s/\r|\n/\\n/g; # Escapar saltos de línea
my $now = time();

my @nuevas_lineas;
my $cabecera = "";
my $encontrado = 0;

if (-e $draft_file) {
    if (open my $fh, '<:encoding(UTF-8)', $draft_file) {
        $cabecera = <$fh> || "id_draft|id_paciente|id_cita|id_medico|current_step|payload_json|timestamp\n";
        chomp $cabecera;
        
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id_draft) {
                # Actualizar línea existente
                $l = join('|', $id_draft, $id_paciente, $id_cita, $id_medico, $step, $json_str, $now);
                $encontrado = 1;
            }
            push @nuevas_lineas, $l;
        }
        close $fh;
    }
} else {
    $cabecera = "id_draft|id_paciente|id_cita|id_medico|current_step|payload_json|timestamp";
}

if (!$encontrado) {
    push @nuevas_lineas, join('|', $id_draft, $id_paciente, $id_cita, $id_medico, $step, $json_str, $now);
}

utils::db_manager::actualizar_archivo($draft_file, $cabecera, \@nuevas_lineas);

print encode_json({
    ok => JSON::true,
    msg => 'Borrador guardado',
    step => $step,
    timestamp => scalar localtime
});
