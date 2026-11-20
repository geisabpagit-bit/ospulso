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

use Encode qw(decode encode);
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(actualizar_archivo);

# Rutina Canónica de Saneamiento y Desenredo Multi-Capa UTF-8
sub fix_utf8 {
    my ($str) = @_;
    return '' unless defined $str;
    
    for (1..4) {
        last unless $str =~ /Ã[\x80-\xFF]|Â[\x80-\xFF]|â€|Ãƒ|Ã‚/;
        my $decoded = eval { Encode::decode("UTF-8", Encode::encode("iso-8859-1", $str)) };
        if (defined $decoded && length($decoded)) {
            $str = $decoded;
        } else {
            last;
        }
    }
    
    $str =~ s/Ã¡/á/g;
    $str =~ s/Ã©/é/g;
    $str =~ s/Ã­/í/g;
    $str =~ s/Ã³/ó/g;
    $str =~ s/Ãº/ú/g;
    $str =~ s/Ã±/ñ/g;
    $str =~ s/Ã‘/Ñ/g;
    $str =~ s/Â°/°/g;
    $str =~ s/Â¿/¿/g;
    $str =~ s/Â¡/¡/g;
    $str =~ s/â€¢/•/g;
    $str =~ s/â€”/—/g;
    $str =~ s/â€“/–/g;
    
    return $str;
}

my $q = CGI->new;
my $session_data = check_session($q);

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDIN,  ":encoding(UTF-8)");

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($session_data->{session_ok}) {
    print JSON::PP->new->utf8(0)->encode({ ok => JSON::PP::false, msg => 'Sesión expirada' });
    exit;
}

my $id_paciente = $q->param('id_paciente') || '';
my $id_cita     = $q->param('id_cita') || '';
my $id_medico   = $session_data->{id_medico} || $q->param('id_medico') || 'DOC-000';
my $step        = $q->param('current_step') || 0;

my $action      = $q->param('action') || '';

if (!$id_paciente) {
    print JSON::PP->new->utf8(0)->encode({ ok => JSON::PP::false, msg => 'Falta id_paciente' });
    exit;
}

# Recopilar todos los parámetros en un payload garantizando saneamiento UTF-8
my %payload;
foreach my $p ($q->param) {
    my $val = $q->param($p);
    utf8::decode($val) if !utf8::is_utf8($val);
    $val = fix_utf8($val);
    $payload{$p} = $val;
}
# Decodificar medicamentos_json si existe
if ($payload{medicamentos_json}) {
    eval { $payload{medicamentos} = JSON::PP->new->utf8(0)->decode($payload{medicamentos_json}); };
}

my $draft_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consulta_draft.dat');

# Estructura del draft: id_draft|id_paciente|id_cita|id_medico|current_step|payload_json|timestamp
# NOTA: utf8(0) produce caracteres; al escribirse en un filehandle con :encoding(UTF-8) evita la doble codificación
my $id_draft = "DRAFT-$id_paciente"; 
my $json_str = JSON::PP->new->utf8(0)->encode(\%payload);
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
            next if $l =~ /^\s*$/;
            next if $l !~ /^DRAFT-/; # Filtrar líneas fragmentadas o corruptas
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

if ($action eq 'clear_draft') {
    # Eliminar el borrador si existe
    @nuevas_lineas = grep { $_ !~ /^$id_draft\|/ } @nuevas_lineas;
} else {
    if (!$encontrado) {
        push @nuevas_lineas, join('|', $id_draft, $id_paciente, $id_cita, $id_medico, $step, $json_str, $now);
    }
}

utils::db_manager::actualizar_archivo($draft_file, $cabecera, \@nuevas_lineas);

print JSON::PP->new->utf8(0)->encode({
    ok => JSON::PP::true,
    msg => $action eq 'clear_draft' ? 'Borrador eliminado' : 'Borrador guardado',
    step => $step,
    timestamp => scalar localtime
});
