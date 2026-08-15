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
my $file_name = $tipo eq 'publicos' ? 'folios_recibos_publicos.dat' : 'folios_recibos_privados.dat';
my $file_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', $file_name);

my $recibos = leer_tabla($file_path, '|', 1); # Saltamos cabecera

# ID_RECIBO|FOLIO|ID_NEGOCIO|ID_SUCURSAL|ID_CONSULTA|ID_PACIENTE|FECHA|HORA|TOTAL_CARGOS|TOTAL_ABONOS|METODO_PAGO|ELABORADO_POR|ESTATUS
# 0         1     2          3           4           5           6     7    8            9            10          11            12

my $pacientes_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $pacs = leer_tabla($pacientes_file, '|', 1);
my %map_pacientes = ();
foreach my $p (@$pacs) {
    next unless @$p >= 3;
    $map_pacientes{$p->[0]} = $p->[2];
}

my @data = ();
foreach my $r (@$recibos) {
    next unless @$r >= 12;
    my $id_negocio = $r->[2];
    # Filtrar por el negocio activo
    next if $id_negocio ne $session_data->{id_empresa};
    
    my $id_recibo = $r->[0] || '';
    my $folio = $r->[1] || '';
    my $id_consulta = $r->[4] || '';
    my $id_paciente = $r->[5] || '';
    my $fecha = $r->[6] || '';
    my $total = $r->[8] || 0;
    my $estatus = $r->[12] // 'Activo';
    
    my $pac_nombre = $map_pacientes{$id_paciente} || $id_paciente;
    if ($tipo eq 'publicos' && $id_paciente =~ /^EMP-/) {
        $pac_nombre = "EMPLEADO ESTADO " . $pac_nombre; # Solo para distinguirlo más visualmente si se quiere, o lo dejamos normal
        $pac_nombre = $map_pacientes{$id_paciente} || $id_paciente; # Restore original mapping to keep it clean
    }
    
    my $medico = "Médico Tratante";
    my $detalle = "Caja";
    
    # Opciones
    my $script_print = $tipo eq 'publicos' ? 'imprimir_recibo_publico.pl' : 'imprimir_recibo_caja.pl';
    my $btn_print = qq{<a href="../api/$script_print?id_consulta=$id_consulta" target="_blank" class="btn btn-sm btn-info text-white me-1" title="Ver Recibo (HTML)"><i class="fas fa-file-invoice"></i></a>};
    my $btn_cancel = "";
    if ($estatus ne 'Cancelado') {
        $btn_cancel = qq{<button onclick="cancelarRecibo('$id_recibo', '$tipo')" class="btn btn-sm btn-danger text-white" title="Cancelar Recibo"><i class="fas fa-ban"></i></button>};
    }
    
    my $estatus_badge = $estatus eq 'Cancelado' ? '<span class="badge bg-danger">Cancelado</span>' : '<span class="badge bg-success">Cobrado</span>';
    
    push @data, [
        $folio,
        $fecha,
        $pac_nombre,
        "Consulta",
        $medico,
        $detalle,
        "\$" . sprintf("%.2f", $total),
        $estatus_badge,
        $btn_print . $btn_cancel
    ];
}

@data = reverse @data;

print $q->header(-type => 'application/json', -charset => 'UTF-8');
print JSON::PP->new->utf8(0)->encode({
    draw => 1,
    recordsTotal => scalar(@data),
    recordsFiltered => scalar(@data),
    data => \@data
});
exit;
