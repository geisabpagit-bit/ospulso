#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use File::Spec;
use FindBin;
use POSIX qw(strftime);
use lib "$FindBin::Bin/..";
use utils::db_manager qw(leer_tabla guardar_registro obtener_nuevo_id);

binmode STDOUT, ':utf8';

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
my $q = CGI->new;
my $session_data = check_session($q);

if (!$session_data->{session_ok}) {
    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Acceso denegado"});
    exit;
}

my $id_recibo = $q->param('id_recibo') || '';
my $tipo = $q->param('tipo') || 'privados';
my $motivo = $q->param('motivo') || 'Sin motivo especificado';
$id_recibo =~ s/^\s+|\s+$//g;

if (!$id_recibo) {
    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "ID de recibo requerido"});
    exit;
}

my $file_name = $tipo eq 'publicos' ? 'folios_recibos_publicos.dat' : 'folios_recibos_privados.dat';
my $file_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', $file_name);

my @recibos_raw = ();
if (-e $file_path && open(my $fhr, '<:encoding(UTF-8)', $file_path)) {
    my $header = <$fhr>;
    push @recibos_raw, $header if $header;
    while (my $line = <$fhr>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @r = split(/\|/, $line, -1);
        push @recibos_raw, \@r;
    }
    close $fhr;
}

my $found = 0;
my $id_consulta = '';
my $id_paciente = '';
my $total = 0;

open(my $fh, '>:encoding(UTF-8)', $file_path) or do {
    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "No se pudo abrir el archivo de recibos para escritura"});
    exit;
};

foreach my $r (@recibos_raw) {
    if (ref($r) eq 'ARRAY') {
        # Validar match por FOLIO ($r->[1]), ID ($r->[0]) o ID_OS ($r->[4])
        my $match_folio = $r->[1] // '';
        my $match_id    = $r->[0] // '';
        my $match_os    = $r->[4] // '';
        if ($match_folio eq $id_recibo || $match_id eq $id_recibo || $match_os eq $id_recibo || ($match_folio && $match_folio =~ /(?:^|\/|-)\Q$id_recibo\E$/)) {
            $found = 1;
            $id_consulta = $r->[4] || '';
            $id_paciente = $r->[5] || '';
            $total = $r->[8] || 0;
            # Soft delete: Marcar como cancelado y registrar auditoría
            $r->[14] = 'Cancelado';
            # $r->[15] contiene ID_MEDICO, se preserva intacto
            $r->[16] = $motivo;
            $r->[17] = $session_data->{usuario};
            $r->[18] = strftime("%Y-%m-%d %H:%M:%S", localtime);
            print $fh join('|', @$r) . "\n";
            next;
        }
        print $fh join('|', @$r) . "\n";
    } else {
        print $fh $r; # Header
    }
}
close($fh);

if ($found && $id_consulta && $total > 0) {
    # Revertir KPI en estado_cuenta.dat
    # Insertar un cargo negativo para compensar
    my $fecha_actual = strftime("%d/%m/%Y", localtime);
    my $edo_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
    my $id_mov = obtener_nuevo_id($edo_path, 'MOV-');
    
    my $med_id = $session_data->{id_usuario} || '';

    my $nota_cancel = "Cancelación Recibo $id_recibo (Consulta #$id_consulta)";
    my @nuevo_mov = (
        $session_data->{id_empresa} || '1',
        $id_mov,
        $id_paciente,
        'Cargo',
        "Cancelacion de $tipo",
        -$total,
        0,
        -$total,
        $fecha_actual,
        $med_id,
        $nota_cancel,
        "Caja"
    );
    guardar_registro($edo_path, \@nuevo_mov);
}

print $q->header(-type => 'application/json', -charset => 'UTF-8');
if ($found) {
    print JSON::PP->new->utf8(0)->encode({ok => 1, msg => "Recibo cancelado exitosamente"});
} else {
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Recibo no encontrado"});
}
exit;
