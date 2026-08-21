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

## 1. Leer Recibo (Opcional, puede ser un recibo exprés sin folio oficial)
my $recibo = {};
my $recibos_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'folios_recibos_publicos.dat');
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

my $id_medico = '';
my $paciente_nombre = 'Paciente Desconocido';
my $empleado_nombre = '';
my $num_empleado = '';
my $paciente_tipo = 'Desconocido';
my $dependencia_nombre = '';
my $id_dep = '';

# 2. Leer estado_cuenta.dat y consultas_clinicas.dat (obtener cargos y datos básicos del recibo si es exprés)
use JSON qw(decode_json);
my @cargos;

# Datos extra si es un recibo exprés
my $express_paciente = '';
my $express_fecha = '';
my $express_hora = '';
my $express_folio = '';

# Intentar de estado_cuenta.dat
my $edc_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
if (-e $edc_file && open(my $fhe, '<:encoding(UTF-8)', $edc_file)) {
    my $he = <$fhe>;
    while (my $le = <$fhe>) {
        chomp $le;
        my @e = split /\|/, $le, -1;
        
        if ($e[3] eq 'Cargo' && ($e[0] eq $id_consulta || ($e[10] && $e[10] =~ /Consulta #$id_consulta/) || ($recibo->{id_paciente} && $e[2] eq $recibo->{id_paciente} && $e[8] eq $recibo->{fecha}))) {
            my $monto = $e[7] || 0;
            push @cargos, {
                concepto => $e[4],
                precio   => $monto,
                cantidad => 1,
                subtotal => $monto
            };
            $id_medico = $e[9] if !$id_medico && $e[9];
            $express_paciente = $e[2] if !$express_paciente;
            $express_fecha = $e[8] if !$express_fecha;
            $express_folio = $e[0] if !$express_folio;
            
            # Rescatar nombre de empleado/paciente si se pasó por ALIAS (columna 11)
            if (defined $e[11] && $e[11] ne '') {
                $paciente_nombre = $e[11];
                $paciente_nombre =~ s/.*Paciente:\s*//i;
            }
        }
    }
    close $fhe;
}

# Intentar de consultas_clinicas (si no hay cargos de estado_cuenta)
my $cons_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
if (!@cargos && -e $cons_file && open(my $fhc, '<:encoding(UTF-8)', $cons_file)) {
    my $hc = <$fhc>;
    while (my $lc = <$fhc>) {
        chomp $lc;
        my @c = split /\|/, $lc, -1;
        if (@c >= 6 && $c[0] eq $id_consulta) {
            eval {
                my $pdata = decode_json($c[5]);
                my $raw_items = $pdata->{caja_items_json} || $pdata->{caja_items};
                if ($raw_items) {
                    my $items = decode_json($raw_items);
                    if (ref($items) eq 'ARRAY') {
                        @cargos = @$items;
                    }
                }
            };
            $id_medico = $c[1] if !$id_medico;
            $express_paciente = $c[2] if !$express_paciente;
            $express_fecha = $c[3] if !$express_fecha;
            $express_hora = $c[4] if !$express_hora;
            last;
        }
    }
    close $fhc;
}

if (!keys %$recibo && !@cargos) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<h1>Error: Recibo no encontrado para esta consulta.</h1>";
    exit;
}

# Consolidar datos de recibo (oficial o exprés)
$recibo->{id_paciente} = $recibo->{id_paciente} || $express_paciente;
$recibo->{fecha} = $recibo->{fecha} || $express_fecha;
$recibo->{hora} = $recibo->{hora} || $express_hora || '00:00:00';
$recibo->{id_negocio} = $recibo->{id_negocio} || $session_data->{id_empresa};
$recibo->{folio} = $recibo->{folio} || $express_folio || $id_consulta;

# Obtener nombre original de paciente si no hay ALIAS
if ($paciente_nombre eq 'Paciente Desconocido') {
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
}

# 3. Obtener Datos del Negocio
my $negocio = {
    nombre => 'MUNICIPIO DE SAN JUAN DEL RIO, QRO.',
    direccion => 'Av. Paso de los Guzman, Centro, San Juan del Rio, Qro.',
    telefono => '427 272 0000',
    clues => ''
};
my $neg_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $neg_file && open(my $fn, '<:encoding(UTF-8)', $neg_file)) {
    my $hn = <$fn>;
    while (my $ln = <$fn>) {
        chomp $ln;
        my @n = split /\|/, $ln, -1;
        if ($n[0] eq ($recibo->{id_negocio} // '')) {
            $negocio->{nombre} = $n[2] // '';
            $negocio->{direccion} = ($n[3] // '') . ', ' . ($n[4] // '') . ', ' . ($n[7] // '') . ', ' . ($n[8] // '');
            $negocio->{telefono} = $n[12] // '';
            $negocio->{clues} = $n[1] // '';
            $negocio->{logo_url} = $n[9] // '';
            last;
        }
    }
    close $fn;
}

my $logo_html = '';
if ($negocio->{logo_url}) {
    $logo_html = qq{<img src="../$negocio->{logo_url}" alt="Logo" style="max-height: 80px; max-width: 150px;">};
} else {
    $logo_html = qq{<h2 style="margin:0; color:#333; font-size:14px;">$negocio->{nombre}</h2>};
}

my $folio_corto = $recibo->{folio} // $id_consulta;
if ($negocio->{clues} ne 'QTSMP000116') {
    if ($folio_corto =~ /-0*(\d+)$/) {
        $folio_corto = $1;
    } elsif ($folio_corto =~ /^\d+$/) {
        # If it was already just digits, keep it as is.
        $folio_corto = $folio_corto + 0;
    }
}

if ($recibo->{id_paciente} =~ /^EMP-(\w+)/) {

    $num_empleado = $1;
}

if ($num_empleado && $negocio->{clues}) {
    my $emp_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "empleadosmun_$negocio->{clues}.dat");
    
    # Buscar el paciente y al titular (Empleado)
    if (-e $emp_file && open(my $fe, '<:encoding(UTF-8)', $emp_file)) {
        my $h = <$fe>;
        while (my $le = <$fe>) {
            chomp $le;
            my @e = split /!/, $le, -1;
            next unless @e >= 5;
            if ($e[0] eq $num_empleado) {
                # Identificamos el tipo de paciente (si hace match exacto)
                if ($e[1] eq $paciente_nombre || uc($e[1]) eq uc($paciente_nombre)) {
                    $paciente_tipo = $e[2] // '';
                }
                
                # Siempre buscamos quién es el Empleado Titular para la dependencia
                if ($e[2] =~ /^Empleado/i) {
                    $empleado_nombre = $e[1] // '';
                    $id_dep = $e[4] // '';
                }
            }
        }
        close $fe;
    }
    
    if (!$paciente_tipo || $paciente_tipo eq 'Desconocido') {
        # Si no lo encontramos pero sabemos que es de empleados, lo asumimos Beneficiario a menos que él mismo sea el empleado
        $paciente_tipo = ($paciente_nombre eq $empleado_nombre) ? 'Empleado' : 'Beneficiario';
    }
    
    if ($id_dep) {
        my $dep_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "dependencia_$negocio->{clues}.dat");
        if (-e $dep_file && open(my $fd, '<:encoding(UTF-8)', $dep_file)) {
            my $hd = <$fd>;
            while (my $ld = <$fd>) {
                chomp $ld;
                my @d = split /!/, $ld, -1;
                if ($d[0] eq $id_dep) {
                    $dependencia_nombre = $d[1] // '';
                    last;
                }
            }
            close $fd;
        }
    }
}

my $medico_nombre = "NO ESPECIFICADO";
if ($id_medico) {
    my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    if (-e $usr_file && open(my $fu, '<:encoding(UTF-8)', $usr_file)) {
        my $hu = <$fu>;
        while (my $lu = <$fu>) {
            chomp $lu;
            my @u = split /!/, $lu, -1;
            if ($u[0] eq $id_medico) {
                $medico_nombre = uc($u[1] // '');
                last;
            }
        }
        close $fu;
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



my $abono_saldo_html = "";
if ($saldo > 0) {
    $abono_saldo_html = qq{
        <div style="color: #059669; font-size: 13px; font-weight: bold; margin-bottom: 4px;">Abono : @{[ formato_moneda($recibo->{total_abonos}) ]}</div>
        <div style="color: #dc2626; font-size: 13px; font-weight: bold; margin-bottom: 8px;">Saldo : @{[ formato_moneda($saldo) ]}</div>
    };
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Recibo $recibo->{folio}</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="16x16" href="../favicon/favicon-16x16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="64x64" href="../favicon/favicon-64x64.png">
    <link rel="icon" type="image/png" sizes="128x128" href="../favicon/favicon-128x128.png">
    <link rel="icon" type="image/x-icon" href="../favicon/favicon.ico">
    <link rel="apple-touch-icon" sizes="180x180" href="../favicon/apple-touch-icon.png">
    <link rel="manifest" href="../favicon/site.webmanifest">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght\@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        /* CSS Específico para Impresión en Media Carta (5.5 x 8.5 in) */
        \@page {
            size: 5.5in 8.5in;
            margin: 0;
        }
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            margin: 0;
            padding: 0;
            color: #1e293b;
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
            text-transform: capitalize;
            color: #333;
        }
        .grid-receipt td {
            border: 1px solid rgba(10, 42, 102, 0.25);
            padding: 8px;
            vertical-align: middle;
        }
        .header-row td {
            text-align: center;
            border-bottom: 1px solid rgba(10, 42, 102, 0.25);
        }
        .col-logo { width: 25%; }
        .col-clinic { width: 50%; font-size: 14px; text-transform: uppercase; color: #333; font-weight: bold; }
        .col-folio { width: 25%; font-size: 11px; color: #333; }
        .info-label-cell {
            width: 25%;
            font-weight: bold;
            color: #333;
        }
        .table-inner {
            width: 100%;
            border-collapse: collapse;
            text-transform: capitalize;
        }
        .table-inner td {
            border: none;
            border-bottom: 1px dashed rgba(204, 204, 204, 0.4);
            padding: 6px;
            color: #333;
        }
        .signature-box {
            border-top: 1px solid rgba(10, 42, 102, 0.25);
            width: 60%;
            margin: 0 auto;
            padding-top: 5px;
            font-weight: normal;
            color: #333;
            text-transform: capitalize;
        }
        .badge-folio {
            font-weight: bold;
            font-size: 1.2rem;
            display: inline-block;
            margin-top: 5px;
            color: #333;
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
            <tr class="header-row" style="border-bottom: 1px solid #ccc;">
                <td class="col-logo" style="width:20%; border-right: none;">
                    <div style="text-align: center;">
                        $logo_html
                        <div style="font-size: 8px; margin-top: 4px;">Clinica de Especialidades</div>
                        <div style="font-size: 10px; font-weight: bold;">JUAN PABLO II</div>
                    </div>
                </td>
                <td class="col-clinic" style="width:50%; text-align: center; border-left: none; border-right: 1px solid #0A2A66; color:#000;">
                    $negocio->{nombre}
                </td>
                <td class="col-folio" style="width:30%; text-align: center;">
                    <span style="font-weight: bold; color: #000; font-size: 12px;">$recibo->{fecha} - $recibo->{hora} hrs.</span><br>
                    <span style="font-weight: 800; font-size: 14px; margin-top: 4px; display:inline-block; color:#000;">Folio</span><br>
                    <span class="badge-folio" style="font-size: 16px;">$folio_corto</span>
                </td>
            </tr>
            <tr>
                <td style="width:20%; vertical-align: top;">
                    Visita : Primera vez
                </td>
                <td colspan="2" style="padding-left: 10px;">
                    Empleado: $num_empleado - $empleado_nombre<br>
                    Dependencia: $dependencia_nombre
                </td>
            </tr>
            <tr>
                <td class="info-label-cell" style="color:#000; font-weight: normal;">Paciente :</td>
                <td colspan="2" style="font-weight: normal;">$paciente_nombre ($paciente_tipo)</td>
            </tr>
            <tr>
                <td class="info-label-cell" style="color:#000; font-weight: normal;">Médico:</td>
                <td colspan="2" style="font-weight: normal; text-transform: uppercase;">$medico_nombre</td>
            </tr>
            <tr>
                <td class="info-label-cell" style="color:#000; font-weight: normal; vertical-align: top;">Concepto :</td>
                <td colspan="2" style="padding: 0;">
                    <table class="table-inner">
HTML

foreach my $c (@cargos) {
    my $precio_fmt   = formato_moneda($c->{precio});
    my $subtotal_fmt = formato_moneda($c->{subtotal});
    my $concepto_txt = uc($c->{concepto});
    print qq{
                        <tr>
                            <td style="text-align: left; font-size: 10px; font-weight: normal;">$concepto_txt</td>
                            <td style="text-align: right; color: #1a365d; font-size: 10px; font-weight: normal;">$subtotal_fmt</td>
                        </tr>
    };
}

print <<HTML;
                    </table>
                </td>
            </tr>
            <tr>
                <td colspan="3" style="padding: 0;">
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr>
                            <td style="width: 50%; text-align: center; vertical-align: bottom; height: 60px; padding-bottom: 5px; border-right: 1px solid #0A2A66;">
                                <div class="signature-box" style="width: 80%;">
                                    Nombre y Firma del Paciente
                                </div>
                            </td>
                            <td style="width: 50%; text-align: right; vertical-align: middle; padding: 15px;">
                                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; color:#000; font-weight: bold; font-size: 14px;">
                                    <span>Cuentas x Cobrar</span>
                                    <span>@{[ formato_moneda($recibo->{total_cargos}) ]}</span>
                                </div>
                                <div style="display: flex; justify-content: flex-end; align-items: center; gap: 8px; margin-top: 15px;">
                                    <span style="font-size: 11px; color: #000; text-align: right;">Elaboró :<br><strong>$recibo->{elaborado_por}</strong></span>
                                </div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
            <tr>
                <td colspan="3" style="text-align: center; color: #000; font-size: 11px; padding: 10px;">
                    $negocio->{domicilio}, Tels.$negocio->{telefono} CP. 76900
                </td>
            </tr>
        </table>
    </div>
</body>
</html>
HTML
