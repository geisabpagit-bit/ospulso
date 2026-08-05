#!/usr/bin/perl
use strict;
use warnings;
use utf8;

my $file = 'views/render_consultas_privado.pl';
open my $fh, '<:encoding(UTF-8)', $file or die $!;
my $content = do { local $/; <$fh> };
close $fh;

my $new_css = <<'CSS';
        '    <style>\\n' +
        '        \@page { size: 5.5in 8.5in; margin: 0; }\\n' +
        '        body { font-family: \'Helvetica Neue\', Helvetica, Arial, sans-serif; margin: 0; padding: 0; color: #111; font-size: 11px; background: #f4f6f9; }\\n' +
        '        .banner-previo { background: #fff3cd; color: #856404; text-align: center; padding: 8px; font-weight: bold; font-size: 12px; border-bottom: 1px solid #ffeeba; }\\n' +
        '        .receipt-container { width: 5.5in; height: 8.5in; box-sizing: border-box; padding: 0.25in; margin: 20px auto; background: #fff; box-shadow: 0 4px 10px rgba(0,0,0,0.1); }\\n' +
        '        .grid-receipt { width: 100%; border-collapse: collapse; margin-bottom: 10px; font-size: 11px; }\\n' +
        '        .grid-receipt td { border: 1px solid #ddd; padding: 6px; vertical-align: middle; }\\n' +
        '        .header-row td { text-align: center; }\\n' +
        '        .col-logo { width: 25%; }\\n' +
        '        .col-clinic { width: 50%; font-size: 13px; text-transform: uppercase; }\\n' +
        '        .col-folio { width: 25%; font-size: 11px; }\\n' +
        '        .info-label-cell { width: 25%; color: #555; }\\n' +
        '    </style>\\n' +
CSS

my $new_html = <<'HTML';
        '</head>\\n' +
        '<body>\\n' +
        '    <div class="banner-previo">VISTA PREVIA DE RECIBO DE CAJA (PREVIO A FIRMA DEFINITIVA)</div>\\n' +
        '    <div class="receipt-container">\\n' +
        '        <table class="grid-receipt">\\n' +
        '            <tr class="header-row">\\n' +
        '                <td class="col-logo"><h2>LOGO</h2></td>\\n' +
        '                <td class="col-clinic">Clínica Médica</td>\\n' +
        '                <td class="col-folio">\\n' +
        '                    ' + hoyFecha + ' - ' + hoyHora + ' hrs.<br>\\n' +
        '                    <strong>Folio</strong><br>\\n' +
        '                    <strong style="font-size: 14px; color: #111;">BORRADOR</strong><br>\\n' +
        '                    Visita : Recurrente\\n' +
        '                </td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td class="info-label-cell">Paciente :</td>\\n' +
        '                <td colspan="2" style="text-transform: uppercase;">' + pacNombre + '</td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td class="info-label-cell">Motivo:</td>\\n' +
        '                <td colspan="2">Consulta / Atención Médica</td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td class="info-label-cell" style="vertical-align: top;">Concepto :</td>\\n' +
        '                <td colspan="2" style="padding: 0;">\\n' +
        '                    <table style="width: 100%; border-collapse: collapse;">\\n' +
        itemsRows +
        '                    </table>\\n' +
        '                </td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td colspan="2" style="text-align: center; vertical-align: bottom; height: 90px; padding-bottom: 10px;">\\n' +
        '                    <div style="border-top: 1px solid #333; width: 60%; margin: 0 auto; padding-top: 5px;">\\n' +
        '                        Nombre y Firma del Paciente\\n' +
        '                    </div>\\n' +
        '                </td>\\n' +
        '                <td style="text-align: right; vertical-align: middle; padding: 15px;">\\n' +
        '                    Costo : ' + fmt(totalCargos) + ' (' + metodo + ')<br><br><br>\\n' +
        '                    Elaboró : ' + medNombre + '\\n' +
        '                </td>\\n' +
        '            </tr>\\n' +
        '            <tr>\\n' +
        '                <td colspan="3" style="text-align: center; color: #555;">\\n' +
        '                    Documento generado por OsPulso - El recibo es válido como comprobante de pago interno.\\n' +
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
