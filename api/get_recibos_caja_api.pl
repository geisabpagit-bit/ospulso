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
my $folios_file = $tipo eq 'publicos' ? 
    File::Spec->catfile($FindBin::Bin, '..', 'dat', 'folios_recibos_publicos.dat') :
    File::Spec->catfile($FindBin::Bin, '..', 'dat', 'folios_recibos_privados.dat');

my $pacientes_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $pacs = leer_tabla($pacientes_file, '|', 1);
my %map_pacientes = ();
foreach my $p (@$pacs) {
    next unless @$p >= 3;
    $map_pacientes{$p->[0]} = $p->[2];
}

my $org_clues = '';
my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $nf, '<:utf8', $negocios_file)) {
    while (my $line = <$nf>) {
        chomp($line);
        my @f = split(/\|/, $line, -1);
        if ($f[0] eq ($session_data->{id_empresa} || '')) {
            $org_clues = $f[18] // '';
            last;
        }
    }
    close($nf);
}

my $empleados_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "empleadosmun_${org_clues}.dat");
my %map_empleados = ();
if ($org_clues && -e $empleados_file) {
    my $emps = leer_tabla($empleados_file, '!');
    foreach my $e (@$emps) {
        if (@$e >= 3) {
            $map_empleados{$e->[0]} = $e->[1] if $e->[2] eq 'Empleado';
        }
    }
}

my $usuarios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my %map_medicos = ();
if (-e $usuarios_file) {
    my $usr_data = leer_tabla($usuarios_file, '!', 1);
    foreach my $u (@$usr_data) {
        if (@$u >= 2) {
            $map_medicos{$u->[0]} = $u->[1];
        }
    }
}

my @data = ();
if (-e $folios_file && open(my $fh, '<:encoding(UTF-8)', $folios_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @r = split(/\|/, $line, -1);
        
        # ID_RECIBO|FOLIO|ID_NEGOCIO|ID_SUCURSAL|ID_CONSULTA|ID_PACIENTE|FECHA|HORA|TOTAL_CARGOS|TOTAL_ABONOS|METODO_PAGO|ELABORADO_POR|CONCEPTO|ITEMS_JSON
        my $id_recibo = $r[0] || '';
        my $folio_absoluto = $r[1] || '';
        my $id_neg = $r[2] || '';
        my $id_paciente = $r[5] || '';
        my $fecha = $r[6] || '';
        my $total = $r[8] || 0;
        my $elaborado_por = $r[11] || '';
        my $concepto_recibo = $r[12] || 'Servicios Múltiples';
        
        # Filtros de tipo
        if ($tipo eq 'publicos') {
            next unless $id_paciente =~ /^EMP-/;
        } else {
            next if $id_paciente =~ /^EMP-/;
        }
        
        my $nombre_final = $map_pacientes{$id_paciente} || $id_paciente;
        $nombre_final =~ s/.*Paciente:\s*//i;
        
        if ($tipo eq 'publicos' && $id_paciente =~ /^EMP-(.*)/) {
            my $num_emp = $1;
            my $paciente_nombre = $nombre_final;
            my $empleado_nombre = $map_empleados{$num_emp} || 'Desconocido';
            $nombre_final = "<strong>Empleado:</strong> $num_emp - $empleado_nombre<br><strong>Paciente:</strong> $paciente_nombre";
        }
        
        my $medico = $map_medicos{$elaborado_por} || $elaborado_por || "Médico Tratante";
        my $detalle = "Caja";
        
        my $folio_mostrar = $folio_absoluto;
        if ($folio_absoluto =~ /-(\d+)$/) {
            $folio_mostrar = $1;
        }
        
        my $script_print = $tipo eq 'publicos' ? 'imprimir_recibo_publico.pl' : 'imprimir_recibo_caja.pl';
        my $btn_print = qq{<a href="../api/$script_print?id_consulta=$folio_absoluto" target="_blank" class="btn btn-sm btn-info text-white me-1" title="Ver Recibo (HTML)"><i class="bi bi-file-earmark-text"></i></a>};
        my $btn_cancel = qq{<button onclick="cancelarRecibo('$folio_absoluto', '$tipo')" class="btn btn-sm btn-danger text-white" title="Cancelar Recibo"><i class="bi bi-x-circle"></i></button>};
        
        my $estatus_badge = '<span class="badge bg-success">Cobrado</span>';
        
        push @data, {
            raw_fecha => $fecha,
            row => [
                $folio_mostrar,
                $fecha,
                $nombre_final,
                $concepto_recibo,
                $medico,
                $detalle,
                "\$" . sprintf("%.2f", $total),
                $estatus_badge,
                $btn_print . $btn_cancel
            ]
        };
    }
    close $fh;
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
