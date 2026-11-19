#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(decode_json);
use File::Spec;
use FindBin;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $q  = CGI->new;
my $sd = check_session($q);
binmode STDOUT, ":utf8";
print $q->header(-type => 'text/html; charset=UTF-8');

unless ($sd && $sd->{session_ok}) {
    print "<h3>Sesión expirada. Inicie sesión nuevamente.</h3>";
    exit;
}

my $id_cirugia = $q->param('id_cirugia') || '';
$id_cirugia =~ s/[^a-zA-Z0-9_\-]//g;

my $path_json = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'quirofano', "cirugia_${id_cirugia}.json");
my $dossier = {};
if (-e $path_json && open my $fh, '<:encoding(UTF-8)', $path_json) {
    local $/;
    my $raw = <$fh>;
    close $fh;
    $dossier = eval { decode_json($raw) } || {};
}

unless ($dossier->{id_cirugia}) {
    print "<h3>No se encontró el dossier quirúrgico #$id_cirugia.</h3>";
    exit;
}

my $trm = $dossier->{tramites_ingreso}   || {};
my $sv  = $dossier->{signos_vitales_preop} || {};
my $nq  = $dossier->{nota_quirurgica}    || {};
my $ucp = $dossier->{recuperacion_ucpa}  || {};
my $rec = $dossier->{receta_alta}        || {};
my $liq = $dossier->{liquidacion_insumos}|| {};
my $cns = $dossier->{consumos_3nf}       || [];

my $meds_rows = '';
foreach my $m (@{$rec->{medicamentos} || []}) {
    $meds_rows .= qq{
        <tr>
            <td><strong>$m->{farmaco}</strong></td>
            <td>$m->{dosis}</td>
            <td>$m->{via}</td>
            <td>$m->{frecuencia}</td>
            <td>$m->{duracion}</td>
        </tr>
    };
}
if (!$meds_rows) {
    $meds_rows = qq{<tr><td colspan="5" style="text-align:center;color:#64748b;">Sin medicamentos prescritos en lista.</td></tr>};
}

my $insumos_rows = '';
foreach my $c (@$cns) {
    my $pu  = sprintf("%.2f", ($c->{precio_unitario_snapshot} || 0) + 0);
    my $sub = sprintf("%.2f", ($c->{subtotal} || 0) + 0);
    $insumos_rows .= qq{
        <tr>
            <td><span class="badge">$c->{etapa_clinica}</span></td>
            <td>$c->{codigo_sku}</td>
            <td>$c->{nombre}</td>
            <td style="text-align:center;">$c->{cantidad} $c->{unidad}</td>
            <td style="text-align:right;">\$$pu</td>
            <td style="text-align:right;"><strong>\$$sub</strong></td>
        </tr>
    };
}
if (!$insumos_rows) {
    $insumos_rows = qq{<tr><td colspan="6" style="text-align:center;color:#64748b;">Sin insumos registrados.</td></tr>};
}

my $sub_3nf  = sprintf("%.2f", ($liq->{subtotal_insumos_3nf} || 0) + 0);
my $sub_sala = sprintf("%.2f", ($liq->{subtotal_renta_sala} || 0) + 0);
my $tot_brut = sprintf("%.2f", ($liq->{total_calculado} || 0) + 0);
my $dep_apli = sprintf("%.2f", ($liq->{deposito_aplicado} || 0) + 0);
my $sal_fin  = sprintf("%.2f", ($liq->{saldo_a_liquidar} || 0) + 0);
my $folio_pase = $rec->{folio_pase_salida} || "PASE-PENDIENTE";
my $hash_nom   = $rec->{hash_firma_electronica} || "NOM151-SHA256-PENDIENTE";
my $cie10      = $rec->{diagnostico_egreso_cie10} || $nq->{diagnostico_postop} || $dossier->{procedimiento};
my $indic      = $rec->{indicaciones_generales} || 'Indicaciones generales de cuidado postoperatorio.';

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Resumen de Alta Quirúrgica y Receta - $dossier->{id_cirugia}</title>
    <link rel="stylesheet" href="../css/quirofano_print.css">
</head>
<body class="qx-print-body">
    <div class="no-print-bar">
        <button onclick="window.print()" class="btn-print">🖨️ Imprimir Resumen de Alta, Receta y Pase de Salida</button>
        <button onclick="window.close()" class="btn-close-win">Cerrar Ventana</button>
    </div>

    <div class="print-sheet">
        <!-- Encabezado Legal -->
        <header class="print-header">
            <div>
                <h1 class="org-title">OSPULSO CLINICAL SUITE — UNIDAD QUIRÚRGICA</h1>
                <p class="org-sub">Expediente Clínico Quirúrgico conforme a NOM-004-SSA3-2012 y NOM-024-SSA3-2012</p>
            </div>
            <div class="folio-box">
                <div><strong>FOLIO QX:</strong> $dossier->{id_cirugia}</div>
                <div><strong>EXP. FÍSICO:</strong> $dossier->{expediente_fisico_folio}</div>
                <div><strong>MODALIDAD:</strong> $dossier->{tipo_cirugia}</div>
                <div><strong>FECHA:</strong> $dossier->{fecha} $dossier->{hora}</div>
            </div>
        </header>

        <!-- 1. Identificación y Resumen Clínico -->
        <section class="print-section">
            <h2 class="sec-title">1. RESUMEN CLÍNICO DE ALTA QUIRÚRGICA</h2>
            <table class="info-grid">
                <tr>
                    <td><strong>Paciente:</strong> $dossier->{nombre_paciente} (#$dossier->{id_paciente})</td>
                    <td><strong>Sala Quirúrgica:</strong> $dossier->{sala} (Renta: $dossier->{id_sala_renta})</td>
                    <td><strong>Habitación:</strong> $dossier->{habitacion_asignada}</td>
                </tr>
                <tr>
                    <td><strong>Cirujano Titular:</strong> $dossier->{nombre_medico}</td>
                    <td><strong>Anestesiólogo:</strong> $dossier->{nombre_anestesio}</td>
                    <td><strong>Puntaje Aldrete UCPA:</strong> $ucp->{aldrete_total} / 10 pts</td>
                </tr>
                <tr>
                    <td colspan="2"><strong>Procedimiento Realizado:</strong> $dossier->{procedimiento}</td>
                    <td><strong>Signos Vitales:</strong> TA $sv->{ta} | FC $sv->{fc} | SpO2 $sv->{spo2}%</td>
                </tr>
                <tr>
                    <td colspan="3"><strong>Diagnóstico de Egreso (CIE-10):</strong> $cie10</td>
                </tr>
            </table>
        </section>

        <!-- 2. Receta Médica de Alta -->
        <section class="print-section">
            <h2 class="sec-title">2. RECETA MÉDICA DE ALTA</h2>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Fármaco / Sustancia Activa</th>
                        <th>Dosis</th>
                        <th>Vía</th>
                        <th>Frecuencia</th>
                        <th>Duración</th>
                    </tr>
                </thead>
                <tbody>
                    $meds_rows
                </tbody>
            </table>
            <div class="indicaciones-box">
                <strong>Indicaciones Generales y Cuidados Postoperatorios:</strong><br>
                $indic
            </div>
            <div class="hash-box">
                <strong>Sello Digital / Hash e.firma (NOM-151):</strong> <code>$hash_nom</code>
            </div>
        </section>

        <!-- 3. Estado de Cuenta e Insumos 3NF (Corte de Caja Automático) -->
        <section class="print-section">
            <h2 class="sec-title">3. CORTE DE CAJA AUTOMÁTICO Y DESGLOSE DE INSUMOS (3NF)</h2>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Etapa</th>
                        <th>SKU</th>
                        <th>Concepto / Insumo 3NF</th>
                        <th>Cantidad</th>
                        <th>P. Unit Snapshot</th>
                        <th>Subtotal</th>
                    </tr>
                </thead>
                <tbody>
                    $insumos_rows
                </tbody>
            </table>

            <div class="totals-wrapper">
                <table class="totals-table">
                    <tr><td>Subtotal Insumos Consumidos (3NF):</td><td>\$$sub_3nf</td></tr>
                    <tr><td>Derecho / Renta de Sala Quirúrgica ($liq->{horas_sala} hrs):</td><td>\$$sub_sala</td></tr>
                    <tr><td><strong>Total Bruto de Cirugía:</strong></td><td><strong>\$$tot_brut</strong></td></tr>
                    <tr><td>(-) Depósito en Caja ($trm->{folio_recibo_caja}):</td><td>-\$$dep_apli</td></tr>
                    <tr class="grand-total"><td>SALDO A LIQUIDAR:</td><td>\$$sal_fin</td></tr>
                </table>
            </div>
        </section>

        <!-- 4. Firmas Reglamentarias -->
        <section class="signatures-row">
            <div class="sig-block">
                <div class="sig-line"></div>
                <strong>$dossier->{nombre_medico}</strong><br>
                <span>Médico Cirujano Tratante</span>
            </div>
            <div class="sig-block">
                <div class="sig-line"></div>
                <strong>$trm->{nombre_firmante}</strong><br>
                <span>Paciente o Familiar Responsable ($trm->{parentesco_firmante})</span>
            </div>
        </section>

        <!-- 5. Talón Desprendible: Pase de Salida -->
        <section class="pase-salida-box">
            <div class="d-flex-between">
                <div>
                    <h3 style="margin:0;color:#0A2A66;">PASE DE SALIDA HOSPITALARIO — MÓDULO QUIRÚRGICO</h3>
                    <p style="margin:2px 0;font-size:11px;">Entregar en Control de Enfermería y Vigilancia al egresar el paciente.</p>
                </div>
                <div class="pase-folio">$folio_pase</div>
            </div>
            <div style="margin-top:6px;font-size:12px;">
                <strong>Paciente:</strong> $dossier->{nombre_paciente} |
                <strong>Sala:</strong> $dossier->{sala} |
                <strong>Habitación:</strong> $dossier->{habitacion_asignada} |
                <strong>Estado Kanban:</strong> $dossier->{estado} |
                <strong>Autorizó:</strong> $dossier->{nombre_medico}
            </div>
        </section>
    </div>
</body>
</html>
HTML
1;
