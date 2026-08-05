#!/usr/bin/perl
use strict;
use warnings;
use utf8;

my $file = 'views/render_consultas_privado.pl';
open my $fh, '<:encoding(UTF-8)', $file or die $!;
my $content = do { local $/; <$fh> };
close $fh;

my $new_css = <<'CSS';
        '    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">\\n' +
        '    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">\\n' +
        '    <style>\\n' +
        '        \@page { size: 5.5in 8.5in; margin: 0; }\\n' +
        '        body { font-family: \'Plus Jakarta Sans\', sans-serif; background: #f8fafc; color: #1e293b; margin: 0; padding: 0; font-size: 11px; }\\n' +
        '        .banner-previo { background: #fff3cd; color: #856404; text-align: center; padding: 8px; font-weight: bold; font-size: 12px; border-bottom: 1px solid #ffeeba; }\\n' +
        '        .recipe-card { max-width: 5.5in; margin: 20px auto; background: white; border-radius: 12px; border: 2px solid #19B7A5; box-shadow: 0 10px 25px rgba(0,0,0,0.08); padding: 0.25in; position: relative; }\\n' +
        '        .grid-receipt { width: 100%; border-collapse: collapse; margin-bottom: 10px; font-size: 11px; }\\n' +
        '        .grid-receipt td { border: 1px solid #0A2A66; padding: 8px; vertical-align: middle; }\\n' +
        '        .header-row td { text-align: center; border-bottom: 2px solid #0A2A66; }\\n' +
        '        .col-logo { width: 25%; }\\n' +
        '        .col-clinic { width: 50%; font-size: 14px; text-transform: uppercase; color: #0A2A66; font-weight: 900; }\\n' +
        '        .col-folio { width: 25%; font-size: 11px; color: #64748b; }\\n' +
        '        .info-label-cell { width: 25%; font-weight: bold; color: #0A2A66; }\\n' +
        '        .badge-folio { background: #0A2A66; color: white; border-radius: 20px; font-weight: 800; padding: 4px 10px; font-size: 0.85rem; display: inline-block; margin-top: 5px; }\\n' +
        '        .table-inner { width: 100%; border-collapse: collapse; }\\n' +
        '        .table-inner td { border: none; border-bottom: 1px dashed #cbd5e1; padding: 6px; }\\n' +
        '        .signature-box { border-top: 1px solid #0A2A66; width: 70%; margin: 0 auto; padding-top: 5px; font-weight: bold; color: #0A2A66; }\\n' +
        '    </style>\\n' +
CSS

my $new_html = <<'HTML';
        '</head>\\n' +
        '<body>\\n' +
        '    <div class="banner-previo">VISTA PREVIA DE RECIBO DE CAJA (PREVIO A FIRMA DEFINITIVA)</div>\\n' +
        '    <div class="recipe-card">\\n' +
        '        <table class="grid-receipt">\\n' +
        '            <tr class="header-row">\\n' +
        '                <td class="col-logo"><i class="bi bi-heart-pulse-fill" style="color: #19B7A5; font-size: 2rem;"></i></td>\\n' +
        '                <td class="col-clinic">Clínica Médica</td>\\n' +
        '                <td class="col-folio">\\n' +
        '                    <span class="fw-bold text-dark">' + hoyFecha + ' - ' + hoyHora + ' hrs.</span><br>\\n' +
        '                    <span class="badge-folio">BORRADOR</span><br>\\n' +
        '                    <span class="mt-1 d-inline-block">Visita : Recurrente</span>\\n' +
        '                </td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td class="info-label-cell"><i class="bi bi-person-fill me-1 text-teal" style="color: #19B7A5;"></i>Paciente :</td>\\n' +
        '                <td colspan="2" class="fw-bold text-uppercase">' + pacNombre + '</td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td class="info-label-cell"><i class="bi bi-clipboard-pulse me-1 text-teal" style="color: #19B7A5;"></i>Motivo:</td>\\n' +
        '                <td colspan="2" class="fw-bold">Consulta / Atención Médica</td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td class="info-label-cell" style="vertical-align: top;"><i class="bi bi-tags-fill me-1 text-teal" style="color: #19B7A5;"></i>Concepto :</td>\\n' +
        '                <td colspan="2" style="padding: 0;">\\n' +
        '                    <table class="table-inner">\\n' +
        itemsRows +
        '                    </table>\\n' +
        '                </td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td colspan="2" style="text-align: center; vertical-align: bottom; height: 90px; padding-bottom: 10px;">\\n' +
        '                    <div class="signature-box">\\n' +
        '                        Nombre y Firma del Paciente\\n' +
        '                    </div>\\n' +
        '                </td>\\n' +
        '                <td style="text-align: right; vertical-align: middle; padding: 15px;">\\n' +
        '                    <div class="fw-bold text-navy mb-2" style="color: #0A2A66; font-size: 14px;">Costo : ' + fmt(totalCargos) + '</div>\\n' +
        '                    <span class="badge bg-light text-dark border mb-3">' + metodo + '</span><br>\\n' +
        '                    <span class="small text-muted">Elaboró :<br><strong>' + medNombre + '</strong></span>\\n' +
        '                </td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td colspan="3" style="text-align: center; color: #64748b; font-size: 9px; padding: 10px;">\\n' +
        '                    <strong>Aviso de Confidencialidad:</strong> Documento generado por OsPulso - El recibo es válido como comprobante de pago interno.\\n' +
        '                </td>\\n' +
        '            </tr>\\n' +
        '        </table>\\n' +
        '    </div>\\n' +
        '</body>\\n' +
        '</html>';
HTML

$content =~ s/'\s*<style>\\\\n'\s*\+.*?'\s*<\/style>\\\\n'\s*\+/$new_css/s or die "Failed CSS";
$content =~ s/'\s*<\/head>\\\\n'\s*\+.*?'\s*<\/html>';/$new_html/s or die "Failed HTML";

open $fh, '>:encoding(UTF-8)', $file or die $!;
print $fh $content;
close $fh;
