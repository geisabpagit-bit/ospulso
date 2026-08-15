#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use Encode qw(decode_utf8);
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/..";
use utils::db_manager qw(leer_tabla);

binmode STDOUT, ':utf8';

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
my $q = CGI->new;
my $session_data = check_session($q);

if (!$session_data->{session_ok} || $session_data->{role} ne 'Recepcionista') {
    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Acceso denegado"});
    exit;
}

my $tipo = $q->param('tipo') || 'privados';
my $file_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');

my $movimientos = leer_tabla($file_path);

my $pacientes_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $pacs = leer_tabla($pacientes_file, '|', 1);
my %map_pacientes = ();
foreach my $p (@$pacs) {
    next unless @$p >= 3;
    $map_pacientes{$p->[0]} = $p->[2];
}

my %recibos = ();

foreach my $r (@$movimientos) {
    next unless @$r >= 12;
    my $id_os = $r->[0] || '';
    my $id_paciente = $r->[2] || '';
    my $tipo_mov = $r->[3] || '';
    my $concepto = $r->[4] || '';
    my $total = $r->[7] || 0;
    my $fecha = $r->[8] || '';
    my $id_medico = $r->[9] || '';
    my $notas = $r->[10] || '';
    my $alias = $r->[11] || '';
    
    # Filtro Privados / Publicos
    if ($tipo eq 'publicos') {
        next unless $id_paciente =~ /^EMP-/;
    } else {
        next if $id_paciente =~ /^EMP-/;
    }
    
    if (!exists $recibos{$id_os}) {
        $recibos{$id_os} = {
            folio => $id_os,
            fecha => $fecha,
            id_consulta => $id_os, # Usamos id_os como llave para imprimir el recibo
            pac_nombre => $alias || $map_pacientes{$id_paciente} || $id_paciente,
            total_cargo => 0,
            total_abono => 0,
            estatus => 'Activo' # Se asume activo, si quisieramos cancelado requeriría cruzar con folios
        };
    }
    
    if ($tipo_mov eq 'Cargo') {
        $recibos{$id_os}->{total_cargo} += $total;
    } elsif ($tipo_mov eq 'Abono') {
        $recibos{$id_os}->{total_abono} += $total;
    }
}

my @data = ();
foreach my $id_os (keys %recibos) {
    my $rec = $recibos{$id_os};
    my $total_mostrar = $rec->{total_abono} > 0 ? $rec->{total_abono} : $rec->{total_cargo};
    
    my $medico = "Médico Tratante";
    my $detalle = "Caja";
    
    # Opciones
    my $script_print = $tipo eq 'publicos' ? 'imprimir_recibo_publico.pl' : 'imprimir_recibo_caja.pl';
    my $btn_print = qq{<a href="../api/$script_print?id_consulta=$rec->{id_consulta}" target="_blank" class="btn btn-sm btn-info text-white me-1" title="Ver Recibo (HTML)"><i class="bi bi-file-earmark-text"></i></a>};
    my $btn_cancel = "";
    if ($rec->{estatus} ne 'Cancelado') {
        $btn_cancel = qq{<button onclick="cancelarRecibo('$id_os', '$tipo')" class="btn btn-sm btn-danger text-white" title="Cancelar Recibo"><i class="bi bi-x-circle"></i></button>};
    }
    
    my $estatus_badge = $rec->{estatus} eq 'Cancelado' ? '<span class="badge bg-danger">Cancelado</span>' : '<span class="badge bg-success">Cobrado</span>';
    
    # Formatear folio para mostrarlo amigable
    my $folioDisplay = ($id_os =~ /^TX/i) ? $id_os : sprintf("OS/2024/%04d", $id_os);
    
    push @data, {
        raw_fecha => $rec->{fecha},
        row => [
            $folioDisplay,
            $rec->{fecha},
            $rec->{pac_nombre},
            "Servicios Múltiples",
            $medico,
            $detalle,
            "\$" . sprintf("%.2f", $total_mostrar),
            $estatus_badge,
            $btn_print . $btn_cancel
        ]
    };
}

# Ordenar por fecha descendente
my @sorted_data = map { $_->{row} } sort { $b->{raw_fecha} cmp $a->{raw_fecha} } @data;

print $q->header(-type => 'application/json', -charset => 'UTF-8');
print JSON::PP->new->utf8(0)->encode({
    draw => 1,
    recordsTotal => scalar(@sorted_data),
    recordsFiltered => scalar(@sorted_data),
    data => \@sorted_data
});
exit;
