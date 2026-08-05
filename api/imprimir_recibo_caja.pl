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

# 4. Obtener Conceptos de estado_cuenta.dat
my @cargos;
my @abonos;
my $edo_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
if (-e $edo_file && open(my $fhe, '<:encoding(UTF-8)', $edo_file)) {
    my $he = <$fhe>;
    while (my $le = <$fhe>) {
        chomp $le;
        my @e = split /\|/, $le, -1;
        # 0:ID_OS, 1:ID_MOV, 2:ID_PAC, 3:TIPO, 4:CONCEPTO, 5:MONTO, 6:IVA, 7:TOTAL, 8:FECHA, 9:MEDICO, 10:NOTAS
        if ($e[10] && $e[10] =~ /Consulta #$id_consulta/) {
            my $item = {
                tipo => $e[3],
                concepto => $e[4],
                monto => $e[7]
            };
            if ($item->{tipo} eq 'Cargo') {
                push @cargos, $item;
            } else {
                push @abonos, $item;
            }
        }
    }
    close $fhe;
}

sub formato_moneda {
    my ($monto) = @_;
    $monto ||= 0;
    my $fmt = sprintf("%.2f", $monto);
    while ($fmt =~ s/^(-?\\d+)(\\d{3})/$1,$2/) {}
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
            padding: 0.4in;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            margin-bottom: 15px;
            border-bottom: 1px solid #ccc;
            padding-bottom: 10px;
        }
        .header p {
            margin: 2px 0;
            color: #555;
            font-size: 10px;
        }
        .title-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }
        .title-row h1 {
            margin: 0;
            font-size: 16px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .title-row .folio {
            font-size: 14px;
            font-weight: bold;
            color: #d32f2f;
        }
        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-bottom: 15px;
            background: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
        }
        .info-item {
            margin-bottom: 4px;
        }
        .info-label {
            font-weight: bold;
            color: #555;
            display: inline-block;
            width: 65px;
        }
        .table-concepts {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 15px;
        }
        .table-concepts th {
            border-bottom: 1px solid #000;
            padding: 5px;
            text-align: left;
            text-transform: uppercase;
            font-size: 10px;
        }
        .table-concepts th.right { text-align: right; }
        .table-concepts td {
            padding: 6px 5px;
            border-bottom: 1px dashed #ccc;
        }
        .table-concepts td.right { text-align: right; font-weight: 500; }
        
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
        <div class="header">
            $logo_html
            <p><strong>$negocio->{nombre}</strong></p>
            <p>$negocio->{domicilio}</p>
            <p>Tel: $negocio->{telefono}</p>
        </div>
        
        <div class="title-row">
            <h1>Recibo de Caja</h1>
            <div class="folio">Folio: $recibo->{folio}</div>
        </div>
        
        <div class="info-grid">
            <div class="info-item"><span class="info-label">Fecha:</span> $recibo->{fecha} $recibo->{hora}</div>
            <div class="info-item"><span class="info-label">Paciente:</span> <strong>$paciente_nombre</strong></div>
            <div class="info-item"><span class="info-label">Método:</span> $recibo->{metodo_pago}</div>
            <div class="info-item"><span class="info-label">Elaboró:</span> $recibo->{elaborado_por}</div>
        </div>
        
        <table class="table-concepts">
            <thead>
                <tr>
                    <th>Concepto</th>
                    <th class="right">Importe</th>
                </tr>
            </thead>
            <tbody>
HTML

foreach my $c (@cargos) {
    my $monto_fmt = formato_moneda($c->{monto});
    print qq{
                <tr>
                    <td>$c->{concepto}</td>
                    <td class="right">$monto_fmt</td>
                </tr>
    };
}

print <<HTML;
            </tbody>
        </table>
        
        <div class="totals-box">
            <div class="totals-row">
                <span>Subtotal Cargos:</span>
                <span>@{[ formato_moneda($recibo->{total_cargos}) ]}</span>
            </div>
            <div class="totals-row" style="color: #2e7d32;">
                <span>Total Abonado:</span>
                <span>- @{[ formato_moneda($recibo->{total_abonos}) ]}</span>
            </div>
            <div class="totals-row grand-total">
                <span>Saldo Pendiente:</span>
                <span>@{[ formato_moneda($saldo) ]}</span>
            </div>
        </div>
        
        <div class="signatures">
            <div class="signature-line">
                <br>
                Firma del Paciente<br>
                $paciente_nombre
            </div>
            <div class="signature-line">
                <br>
                Firma de Recibido<br>
                $recibo->{elaborado_por}
            </div>
        </div>
        
        <div class="footer">
            Documento generado por OsPulso - El recibo es válido como comprobante de pago interno.<br>
            Cita ID: $recibo->{id_consulta}
        </div>
    </div>
</body>
</html>
HTML
