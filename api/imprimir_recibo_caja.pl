#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

binmode STDOUT, ':utf8';

my $q = CGI->new;
my $session_data = check_session($q);

unless ($session_data->{session_ok}) {
    print $q->redirect(-uri => '../index.pl');
    exit;
}

my $id_consulta = $q->param('id_consulta') || '';
$id_consulta =~ s/^\s+|\s+$//g;

if (!$id_consulta) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<h1>Error: Falta ID de Consulta</h1>";
    exit;
}

# 1. Leer Recibo
my $recibo = {};
my $recibos_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'folios_recibos_privados.dat');
if (-e $recibos_file && open(my $fh, '<:encoding(UTF-8)', $recibos_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        my @c = split /\|/, $line, -1;
        # ID_RECIBO|FOLIO|ID_NEGOCIO|ID_SUCURSAL|ID_CONSULTA|ID_PACIENTE|FECHA|HORA|TOTAL_CARGOS|TOTAL_ABONOS|METODO_PAGO|ELABORADO_POR
        if ($c[4] eq $id_consulta) {
            $recibo = {
                id_recibo     => $c[0],
                folio         => $c[1],
                id_negocio    => $c[2],
                id_sucursal   => $c[3],
                id_consulta   => $c[4],
                id_paciente   => $c[5],
                fecha         => $c[6],
                hora          => $c[7],
                total_cargos  => $c[8] || 0,
                total_abonos  => $c[9] || 0,
                metodo_pago   => $c[10] || 'Efectivo',
                elaborado_por => $c[11] || ''
            };
            last;
        }
    }
    close $fh;
}

if (!keys %$recibo) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<h1>Error: Recibo no encontrado para esta consulta. Es posible que la consulta haya sido gratuita.</h1>";
    exit;
}

# 2. Obtener Paciente
my $paciente_nombre = 'Paciente Desconocido';
my $pacientes_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
if (-e $pacientes_file && open(my $fhp, '<:encoding(UTF-8)', $pacientes_file)) {
    my $hp = <$fhp>;
    while (my $lp = <$fhp>) {
        chomp $lp;
        my @p = split /\|/, $lp, -1;
        if ($p[0] eq $recibo->{id_paciente}) {
            $paciente_nombre = $p[2] // '';
            last;
        }
    }
    close $fhp;
}

# 3. Obtener Datos del Negocio
my $negocio = {
    nombre => 'Sucursal Clínica',
    domicilio => 'Dirección no registrada',
    telefono => 'Sin teléfono',
    logo_url => ''
};
my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fhn, '<:encoding(UTF-8)', $negocios_file)) {
    my $hn = <$fhn>;
    while (my $ln = <$fhn>) {
        chomp $ln;
        my @n = split /\|/, $ln, -1;
        # Si tiene sucursal usamos ese, sino la matriz (id_negocio)
        my $target_id = ($recibo->{id_sucursal} && $recibo->{id_sucursal} ne 'SUC-000' && $recibo->{id_sucursal} ne '0') ? $recibo->{id_sucursal} : $recibo->{id_negocio};
        if ($n[0] eq $target_id) {
            $negocio->{nombre} = $n[1] || 'Clínica';
            $negocio->{domicilio} = $n[6] || '';
            $negocio->{telefono} = $n[7] || '';
            $negocio->{logo_url} = $n[9] || '';
            last;
        }
    }
    close $fhn;
}

my $logo_html = '';
if ($negocio->{logo_url}) {
    $logo_html = qq{<img src="../$negocio->{logo_url}" alt="Logo" style="max-height: 80px; max-width: 200px;">};
} else {
    $logo_html = qq{<h2 style="margin:0; color:#333;">$negocio->{nombre}</h2>};
}

# 4. Obtener Conceptos de consultas_clinicas.dat y estado_cuenta.dat
use JSON qw(decode_json);
my @cargos;
my $cons_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
if (-e $cons_file && open(my $fhc, '<:encoding(UTF-8)', $cons_file)) {
    my $hc = <$fhc>;
    while (my $lc = <$fhc>) {
        chomp $lc;
        my @c = split /\|/, $lc, -1;
        if (@c >= 6 && $c[0] eq $id_consulta) {
            eval {
                my $pdata = decode_json($c[5]);
                my $raw_items = $pdata->{caja_items_json} || $pdata->{caja_items};
                if ($raw_items) {
                    my $arr = ref($raw_items) eq 'ARRAY' ? $raw_items : decode_json($raw_items);
                    if (ref($arr) eq 'ARRAY') {
                        foreach my $it (@$arr) {
                            my $name = $it->{nombre} || $it->{concepto} || 'Concepto Médico';
                            my $prec = $it->{precio} // $it->{monto} // 0;
                            my $cant = $it->{cantidad} // 1;
                            my $subt = $it->{subtotal} // ($prec * $cant);
                            push @cargos, {
                                concepto => $name,
                                precio   => $prec,
                                cantidad => $cant,
                                subtotal => $subt
                            };
                        }
                    }
                }
            };
            last;
        }
    }
    close $fhc;
}

if (!@cargos) {
    my $edo_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
    if (-e $edo_file && open(my $fhe, '<:encoding(UTF-8)', $edo_file)) {
        my $he = <$fhe>;
        while (my $le = <$fhe>) {
            chomp $le;
            my @e = split /\|/, $le, -1;
            if ($e[3] eq 'Cargo' && (($e[10] && $e[10] =~ /Consulta #$id_consulta/) || ($recibo->{id_paciente} && $e[2] eq $recibo->{id_paciente} && $e[8] eq $recibo->{fecha}))) {
                my $monto = $e[7] || 0;
                push @cargos, {
                    concepto => $e[4],
                    precio   => $monto,
                    cantidad => 1,
                    subtotal => $monto
                };
            }
        }
        close $fhe;
    }
}

sub formato_moneda {
    my ($monto) = @_;
    $monto ||= 0;
    my $fmt = sprintf("%.2f", $monto);
    while ($fmt =~ s/^(-?\d+)(\d{3})/$1,$2/) {}
    return '$' . $fmt;
}

my $saldo = $recibo->{total_cargos} - $recibo->{total_abonos};
$saldo = 0 if $saldo < 0;

print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Recibo $recibo->{folio}</title>
    <style>
        /* CSS Específico para Impresión en Media Carta (5.5 x 8.5 in) */
        \@page {
            size: 5.5in 8.5in;
            margin: 0;
        }
        body {
            font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 0;
            color: #111;
            font-size: 11px;
            background: #fff;
        }
        .receipt-container {
            width: 5.5in;
            height: 8.5in;
            box-sizing: border-box;
            padding: 0.25in;
            margin: 0 auto;
        }
        .grid-receipt {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 10px;
            font-size: 11px;
        }
        .grid-receipt td {
            border: 1px solid #ddd;
            padding: 6px;
            vertical-align: middle;
        }
        .header-row td {
            text-align: center;
        }
        .col-logo { width: 25%; }
        .col-clinic { width: 50%; font-size: 13px; text-transform: uppercase; }
        .col-folio { width: 25%; font-size: 11px; }
        .info-label-cell {
            width: 25%;
            color: #555;
        }
        .table-concepts {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 15px;
        }
        .table-concepts th {
            border-bottom: 2px solid #1a365d;
            padding: 6px;
            text-transform: uppercase;
            font-size: 10px;
            color: #1a365d;
        }
        .table-concepts td {
            padding: 6px 5px;
            border-bottom: 1px dashed #ccc;
        }
        
        .totals-box {
            width: 50%;
            margin-left: auto;
            border: 1px solid #ccc;
            padding: 8px;
            border-radius: 4px;
        }
        .totals-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 4px;
        }
        .totals-row.grand-total {
            font-weight: bold;
            font-size: 13px;
            border-top: 1px solid #000;
            padding-top: 4px;
            margin-top: 4px;
        }
        .signatures {
            margin-top: 40px;
            display: flex;
            justify-content: space-between;
            text-align: center;
        }
        .signature-line {
            width: 45%;
            border-top: 1px solid #000;
            padding-top: 5px;
            font-size: 10px;
            color: #333;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            font-size: 9px;
            color: #777;
        }
        \@media screen {
            body { background: #e0e0e0; padding: 20px; }
            .receipt-container {
                background: white;
                box-shadow: 0 4px 10px rgba(0,0,0,0.1);
            }
        }
    </style>
</head>
<body onload="window.print()">
    <div class="receipt-container">
        <table class="grid-receipt">
            <tr class="header-row">
                <td class="col-logo">$logo_html</td>
                <td class="col-clinic">$negocio->{nombre}</td>
                <td class="col-folio">
                    $recibo->{fecha} - $recibo->{hora} hrs.<br>
                    <strong>Folio</strong><br>
                    <strong style="font-size: 14px; color: #111;">$recibo->{folio}</strong><br>
                    Visita : Recurrente
                </td>
            </tr>
            <tr>
                <td class="info-label-cell">Paciente :</td>
                <td colspan="2" style="text-transform: uppercase;">$paciente_nombre</td>
            </tr>
            <tr>
                <td class="info-label-cell">Motivo:</td>
                <td colspan="2">Consulta / Atención Médica</td>
            </tr>

        
            <tr>
                <td class="info-label-cell" style="vertical-align: top;">Concepto :</td>
                <td colspan="2" style="padding: 0;">
                    <table style="width: 100%; border-collapse: collapse;">
HTML

foreach my $c (@cargos) {
    my $precio_fmt   = formato_moneda($c->{precio});
    my $subtotal_fmt = formato_moneda($c->{subtotal});
    my $concepto_txt = uc($c->{concepto});
    print qq{
                        <tr>
                            <td style="text-align: left; padding: 6px; border-bottom: 1px dashed #ccc;">$concepto_txt</td>
                            <td style="text-align: right; padding: 6px; border-bottom: 1px dashed #ccc;">$subtotal_fmt</td>
                        </tr>
    };
}

print <<HTML;
                    </table>
                </td>
            </tr>
            <tr>
                <td colspan="2" style="text-align: center; vertical-align: bottom; height: 90px; padding-bottom: 10px;">
                    <div style="border-top: 1px solid #333; width: 60%; margin: 0 auto; padding-top: 5px;">
                        Nombre y Firma del Paciente
                    </div>
                </td>
                <td style="text-align: right; vertical-align: middle; padding: 15px;">
                    Costo : @{[ formato_moneda($recibo->{total_cargos}) ]} ($recibo->{metodo_pago})<br><br><br>
                    Elaboro : $recibo->{elaborado_por}
                </td>
            </tr>
            <tr>
                <td colspan="3" style="text-align: center; color: #555;">
                    $negocio->{domicilio}, Tel: $negocio->{telefono}
                </td>
            </tr>
        </table>
    </div>
</body>
</html>
HTML
