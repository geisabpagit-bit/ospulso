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
my $target_digits = $id_consulta;
$target_digits =~ s/\D+//g;

if (-e $recibos_file && open(my $fh, '<:encoding(UTF-8)', $recibos_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        
        my $c_id    = $c[0] // '';
        my $c_folio = $c[1] // '';
        my $c_cons  = $c[4] // '';

        my $match = 0;
        if ($c_id eq $id_consulta || $c_folio eq $id_consulta || $c_cons eq $id_consulta) {
            $match = 1;
        } elsif ($c_folio =~ /(?:^|\/|-)\Q$id_consulta\E$/) {
            $match = 1;
        } elsif ($target_digits ne '' && ($c_folio =~ /\Q$target_digits\E$/ || $c_id =~ /\Q$target_digits\E$/ || $c_cons =~ /\Q$target_digits\E$/)) {
            $match = 1;
        }

        if ($match) {
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
                elaborado_por => $c[11] || '',
                concepto      => $c[12] || '',
                items_json    => $c[13] || '',
                estatus       => $c[14] || '',
                id_medico     => $c[15] || ''
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
    logo_url => '',
    clues => ''
};
my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fhn, '<:encoding(UTF-8)', $negocios_file)) {
    my $hn = <$fhn>;
    while (my $ln = <$fhn>) {
        chomp $ln;
        my @n = split /\|/, $ln, -1;
        my $target_id = $recibo->{id_negocio} // '';
        if ($n[0] eq $target_id) {
            $negocio->{nombre} = $n[1] // '';
            $negocio->{domicilio} = ($n[3] // '') . ', ' . ($n[4] // '') . ', ' . ($n[7] // '') . ', ' . ($n[8] // '');
            $negocio->{telefono} = $n[12] // '';
            $negocio->{clues} = $n[18] // $n[1] // '';
            $negocio->{logo_url} = $n[9] // '';
            last;
        }
    }
    close $fhn;
}
# 3.1 Obtener datos estructurados para el pie del recibo (CLUE o Sucursal)
my $clue_encontrada = 0;
my ($pie_calle_no, $pie_colonia, $pie_municipio, $pie_entidad, $pie_telefono, $pie_cp) = ('', '', '', '', '', '');

my $clues_id_actual = $negocio->{clues} // '';
if ($clues_id_actual) {
    my $cat_clues_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogosOF', 'CAT_CLUES.dat');
    if (-e $cat_clues_file && open(my $fh_clue, '<:encoding(UTF-8)', $cat_clues_file)) {
        <$fh_clue>; # Omitir encabezado
        while (my $line = <$fh_clue>) {
            chomp $line;
            next unless $line;
            my @c = split /\|/, $line, -1;
            if (@c > 32 && $c[0] eq $clues_id_actual) {
                my $vialidad_tipo = $c[20] // '';
                my $vialidad_nom  = $c[21] // '';
                my $num_ext       = $c[22] // '';
                
                my $dir_calle = join(' ', grep { $_ ne '' } ($vialidad_tipo, $vialidad_nom, $num_ext));
                $pie_calle_no  = $dir_calle || ($c[28] // '');
                $pie_colonia   = $c[26] || $c[8] || '';
                $pie_municipio = $c[6] // '';
                $pie_entidad   = $c[4] // '';
                $pie_telefono  = $c[32] // '';
                $pie_cp        = $c[27] // '';
                
                $clue_encontrada = 1;
                last;
            }
        }
        close $fh_clue;
    }
}

if (!$clue_encontrada) {
    my $id_target = $recibo->{id_sucursal} || $recibo->{id_negocio} || $session_data->{id_empresa} || '';
    if ($id_target && -e $negocios_file && open(my $fn_suc, '<:encoding(UTF-8)', $negocios_file)) {
        <$fn_suc>;
        while (my $line = <$fn_suc>) {
            chomp $line;
            my @n = split /\|/, $line, -1;
            if ($n[0] eq $id_target) {
                $pie_calle_no  = $n[6] // '';
                $pie_colonia   = $n[17] // '';
                $pie_municipio = $n[16] // '';
                $pie_entidad   = $n[15] // '';
                $pie_telefono  = $n[7] // '';
                $pie_cp        = $n[14] // '';
                last;
            }
        }
        close $fn_suc;
    }
}

# Sanitizar y eliminar paréntesis
foreach ($pie_calle_no, $pie_colonia, $pie_municipio, $pie_entidad, $pie_telefono, $pie_cp) {
    s/[\(\)]//g;
    s/^\s+|\s+$//g;
}

my @pie_partes;
push @pie_partes, $pie_calle_no        if $pie_calle_no ne '';
push @pie_partes, $pie_colonia         if $pie_colonia ne '';
push @pie_partes, $pie_municipio       if $pie_municipio ne '';
push @pie_partes, $pie_entidad         if $pie_entidad ne '';
push @pie_partes, "Tel. $pie_telefono" if $pie_telefono ne '';
push @pie_partes, "C.P. $pie_cp"       if $pie_cp ne '';

my $texto_pie_recibo = join(", ", @pie_partes);

# Buscar también en pacientes_privados
if ($paciente_nombre eq 'Paciente Desconocido' || $paciente_nombre eq $recibo->{id_paciente}) {
    my $priv_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "pacientes_privados__$negocio->{clues}.dat");
    if (-e $priv_file && open(my $fhp, '<:encoding(UTF-8)', $priv_file)) {
        my $hp = <$fhp>;
        while (my $lp = <$fhp>) {
            chomp $lp;
            my @p = split /\|/, $lp, -1;
            if ($p[0] eq $recibo->{id_paciente}) {
                $paciente_nombre = $p[1] // '';
                last;
            }
        }
        close $fhp;
    }
}

# Buscar en empleadosmun por si acaso
if ($recibo->{id_paciente} =~ /^EMP-(\w+)/) {
    my $num_empleado = $1;
    if ($num_empleado && $negocio->{clues}) {
        require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
        my $emp_file = catalogo_org_utils::obtener_rutas_por_clue($negocio->{clues})->{empleadosmun};
        if (-e $emp_file && open(my $fe, '<:encoding(UTF-8)', $emp_file)) {
            my $h = <$fe>;
            while (my $le = <$fe>) {
                chomp $le;
                my @e = split /!/, $le, -1;
                next unless @e >= 5;
                if ($e[0] eq $num_empleado && $e[2] eq 'Empleado') {
                    $paciente_nombre = $e[1] // '';
                    last;
                }
            }
            close $fe;
        }
    }
}

my $logo_html = '';
if ($negocio->{clues} eq 'QTSMP000116') {
    $logo_html = qq{<img src="../dat/logos/logo_QTSMP000116.jpg" alt="Logo" style="max-height: 80px; max-width: 200px;">};
} elsif ($negocio->{logo_url}) {
    $logo_html = qq{<img src="../$negocio->{logo_url}" alt="Logo" style="max-height: 80px; max-width: 200px;">};
} else {
    $logo_html = qq{<h2 style="margin:0; color:#333;">$negocio->{nombre}</h2>};
}

# 4. Obtener Conceptos de ITEMS_JSON
use JSON qw(decode_json);
use Encode qw(encode_utf8);
my @cargos;

if ($recibo->{items_json} && $recibo->{items_json} ne '[]') {
    eval {
        my $items;
        eval { $items = decode_json($recibo->{items_json}); };
        if ($@) { $items = decode_json(encode_utf8($recibo->{items_json})); }
        
        foreach my $it (@$items) {
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
    };
}

# Si falló leer de ITEMS_JSON, intentar de consultas_clinicas (Fallback para recibos antiguos)
if (!@cargos) {
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

my $folio_corto = $recibo->{folio} // $id_consulta;
if ($folio_corto =~ /-0*(\d+)$/) {
    $folio_corto = $1;
} elsif ($folio_corto =~ /^\d+$/) {
    $folio_corto = $folio_corto + 0;
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

my $elaborado_por = $recibo->{elaborado_por} || $session_data->{usuario} || $session_data->{nombre_usuario} || 'Sistema';

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
            color: #000;
            font-family: Arial, sans-serif;
            font-weight: normal;
        }
        .grid-receipt td {
            border: 1px solid #ccc;
            padding: 8px;
            vertical-align: middle;
            font-weight: normal;
        }
        .header-row td {
            text-align: center;
        }
        .col-logo { width: 25%; }
        .col-clinic { width: 45%; font-size: 14px; text-transform: uppercase; color: #000; text-align: center; }
        .col-folio { width: 30%; font-size: 11px; color: #000; text-align: center; }
        .info-label-cell {
            width: 25%;
            color: #000;
        }
        .table-inner {
            width: 100%;
            border-collapse: collapse;
            text-transform: capitalize;
        }
        .table-inner td {
            border: none;
            border-bottom: 1px dashed #ccc;
            padding: 6px;
            color: #000;
        }
        .signature-box {
            border-top: 1px solid #ccc;
            width: 80%;
            margin: 0 auto;
            padding-top: 5px;
            color: #000;
            text-transform: capitalize;
        }
        .badge-folio {
            font-size: 16px;
            display: inline-block;
            margin-top: 5px;
            color: #000;
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
    <div class="receipt-container" style="font-family: Arial, sans-serif;">
        <table class="grid-receipt">
            <tr class="header-row">
                <td class="col-logo">
                    <div style="text-align: center;">
                        $logo_html
                    </div>
                </td>
                <td class="col-clinic">$negocio->{nombre}</td>
                <td class="col-folio" style="font-size: 9px; white-space: nowrap; text-align: center;">
                    $recibo->{fecha} - $recibo->{hora} hrs.<br>
                    <span style="margin-top: 4px; display:inline-block;">Folio</span><br>
                    <strong>$folio_corto</strong><br>
                    <span style="margin-top: 4px; display: inline-block;">Visita : Primera vez</span>
                </td>
            </tr>
            <tr>
                <td class="info-label-cell">Paciente :</td>
                <td colspan="2" style="font-size: 10px; text-transform: uppercase;">$paciente_nombre</td>
            </tr>
            <tr>
                <td class="info-label-cell">Motivo:</td>
                <td colspan="2" style="font-size: 10px;">Consulta / Atención Médica</td>
            </tr>

        
            <tr>
                <td class="info-label-cell" style="vertical-align: top;">Concepto :</td>
                <td colspan="2" style="padding: 0;">
                    <table class="table-inner">
HTML

foreach my $c (@cargos) {
    my $precio_fmt   = formato_moneda($c->{precio});
    my $subtotal_fmt = formato_moneda($c->{subtotal});
    my $concepto_txt = $c->{concepto};
    print qq{
                        <tr>
                            <td style="text-align: left; font-size: 10px; text-transform: uppercase;">$concepto_txt</td>
                            <td style="text-align: right; font-size: 10px;">$subtotal_fmt</td>
                        </tr>
    };
}

print <<HTML;
                    </table>
                </td>
            </tr>
            <tr>
                <td colspan="3" style="padding: 0; border: none;">
                    <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
                        <tr>
                            <td style="width: 100%; text-align: right; vertical-align: middle; padding: 12px; border: 1px solid #ccc; border-top: none;">
                                <div style="font-size: 11px; margin-bottom: 8px; font-weight: bold;">Total : @{[ formato_moneda($recibo->{total_cargos}) ]}</div>
                                $abono_saldo_html
                                <div style="display: flex; justify-content: space-between; align-items: center; gap: 8px; margin-top: 10px;">
                                    <span style="border: 1px solid #ccc; border-radius: 4px; padding: 4px 8px; font-size: 11px; display: inline-block;">$recibo->{metodo_pago}</span>
                                    <span style="font-size: 10px; font-weight: bold; color: #334155; white-space: nowrap;">Elaboró : $elaborado_por</span>
                                </div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
            <tr>
                <td colspan="3" style="text-align: center; font-size: 8px; font-weight: bold; padding: 6px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; letter-spacing: -0.2px;">
                    $texto_pie_recibo
                </td>
            </tr>
        </table>
    </div>
</body>
</html>
HTML
