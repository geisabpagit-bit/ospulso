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

# 0. Lógica de Pacientes Privados (Sin Portal)
my $org_clues = '';
my $id_neg = $session_data->{id_empresa} || '';
my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fhn, '<:encoding(UTF-8)', $negocios_file)) {
    my $hn = <$fhn>;
    while (my $ln = <$fhn>) {
        chomp $ln;
        my @n = split /\|/, $ln, -1;
        if ($n[0] eq $id_neg) {
            $org_clues = $n[18] // '';
            last;
        }
    }
    close $fhn;
}
$org_clues ||= 'QTSMP000116';

my %map_alias_estado = ();
my $edo_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
if (-e $edo_file && open(my $fhe, '<:encoding(UTF-8)', $edo_file)) {
    while (my $line = <$fhe>) {
        chomp $line;
        my @e = split /\|/, $line, -1;
        if ($e[3] eq 'Cargo' && $e[11]) {
            $map_alias_estado{$e[0]} = $e[11];
        }
    }
    close $fhe;
}

my $priv_pacs_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "pacientes_privados__${org_clues}.dat");
if (-e $priv_pacs_file && open(my $fhp, '<:encoding(UTF-8)', $priv_pacs_file)) {
    my $header = <$fhp>;
    while (my $line = <$fhp>) {
        chomp($line);
        my @p = split(/\|/, $line, -1);
        if (@p >= 2) {
            $map_pacientes{$p[0]} = $p[1];
        }
    }
    close($fhp);
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

my $medicos_custom_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "medicos_${org_clues}.dat");
my %map_medicos = ();
if ($org_clues && -e $medicos_custom_file) {
    my $meds = leer_tabla($medicos_custom_file, '|');
    foreach my $m (@$meds) {
        if (@$m >= 2) {
            $map_medicos{$m->[0]} = $m->[2] if $m->[0] && $m->[2];
        }
    }
}

my $usuarios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
if (-e $usuarios_file) {
    my $usr_data = leer_tabla($usuarios_file, '!', 1);
    foreach my $u (@$usr_data) {
        if (@$u >= 2 && !exists $map_medicos{$u->[0]}) {
            # Map by username (column 0) to full name (column 1) if not already mapped
            $map_medicos{$u->[0]} = $u->[1];
        }
    }
}
$map_medicos{'rec'} = 'Recepción' unless $map_medicos{'rec'};

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
            my $empleado_nombre = $map_empleados{$num_emp} || 'Desconocido';
            my $paciente_nombre = $map_alias_estado{$folio_absoluto} || ($nombre_final eq $id_paciente ? $empleado_nombre : $nombre_final);
            $paciente_nombre =~ s/.*Paciente:\s*//i;
            $nombre_final = "<strong>Empleado:</strong> $num_emp - $empleado_nombre<br><strong>Paciente:</strong> $paciente_nombre";
        }
        
        # El ID del médico (si se guardó) viene en $r[15], de lo contrario fallback a elaborado_por
        my $id_medico_saved = $r[15] || $elaborado_por;
        my $medico = $map_medicos{$id_medico_saved} || $id_medico_saved || "Médico Tratante";
        my $detalle = "Caja";
        
        my $folio_mostrar = $folio_absoluto;
        if ($folio_absoluto =~ /-(\d+)$/) {
            $folio_mostrar = int($1); # Convert to int to strip leading zeros
        }
        
        my $script_print = $tipo eq 'publicos' ? 'imprimir_recibo_publico.pl' : 'imprimir_recibo_caja.pl';
        my $btn_print = qq{<a href="../api/$script_print?id_consulta=$folio_absoluto" target="_blank" class="btn btn-sm btn-info text-white me-1" title="Ver Recibo (HTML)"><i class="bi bi-file-earmark-text"></i></a>};
        my $btn_cancel = qq{<button onclick="cancelarRecibo('$folio_absoluto', '$tipo')" class="btn btn-sm btn-danger text-white" title="Borrar Recibo"><i class="bi bi-trash"></i></button>};
        
        my $estatus = $r[14] || 'Cobrado';
        my $estatus_badge = $estatus eq 'Cancelado' ? '<span class="badge bg-danger">Cancelado</span>' : '<span class="badge bg-success">Cobrado</span>';
        
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
