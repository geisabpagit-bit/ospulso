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

use JSON qw(decode_json);
use Encode qw(encode_utf8);
my @cargos;
if ($recibo->{items_json} && $recibo->{items_json} ne '[]') {
    eval {
        my $items;
        eval { $items = decode_json($recibo->{items_json}); };
        if ($@) { $items = decode_json(encode_utf8($recibo->{items_json})); }
        
        foreach my $it (@$items) {
            push @cargos, {
                concepto => $it->{nombre},
                precio   => $it->{precio},
                cantidad => $it->{cantidad},
                subtotal => $it->{precio} * $it->{cantidad}
            };
        }
    };
}

my $id_medico = $recibo->{id_medico} || '';
my $paciente_nombre = 'Paciente Desconocido';
my $empleado_nombre = '';
my $num_empleado = '';
my $paciente_tipo = 'Desconocido';
my $dependencia_nombre = '';
my $id_dep = '';

# 2. Leer estado_cuenta.dat y consultas_clinicas.dat (obtener cargos y datos básicos del recibo si es exprés)

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

        # Ignorar movimientos de cancelación que alteran los datos contables
        next if ($e[3] && $e[3] =~ /Cancelac/i) || ($e[4] && $e[4] =~ /Cancelac/i) || ($e[10] && $e[10] =~ /Cancelac/i);
        
        if ($e[3] eq 'Cargo' && ($e[0] eq $id_consulta || ($e[10] && $e[10] =~ /Consulta #$id_consulta/) || ($recibo->{id_paciente} && $e[2] eq $recibo->{id_paciente} && $e[8] eq $recibo->{fecha}))) {
            if (!@cargos) {
                my $monto = $e[7] || 0;
                push @cargos, {
                    concepto => $e[4],
                    precio   => $monto,
                    cantidad => 1,
                    subtotal => $monto
                };
            }
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
            $negocio->{nombre} = $n[1] // '';
            $negocio->{direccion} = ($n[3] // '') . ', ' . ($n[4] // '') . ', ' . ($n[7] // '') . ', ' . ($n[8] // '');
            $negocio->{telefono} = $n[12] // '';
            $negocio->{clues} = $n[18] // $n[1] // '';
            $negocio->{logo_url} = $n[9] // '';
            last;
        }
    }
    close $fn;
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
                # Columnas CAT_CLUES.dat:
                # 4: ENTIDAD, 6: MUNICIPIO, 8: LOCALIDAD, 20: TIPO_VIALIDAD, 21: VIALIDAD, 22: NUM_EXT, 26: ASENTAMIENTO, 27: CP, 32: TELEFONO
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
    if ($id_target && -e $neg_file && open(my $fn_suc, '<:encoding(UTF-8)', $neg_file)) {
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

# Sanitizar y eliminar paréntesis que pudieran venir en los datos
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
    my $priv_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogos_CLUE', $negocio->{clues}, "pacientes_privados_$negocio->{clues}.dat");
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

my $logo_html = '';
if ($negocio->{clues} eq 'QTSMP000116') {
    $logo_html = qq{<img src="../dat/logos/logo_QTSMP000116.jpg" alt="Logo" style="max-height: 80px; max-width: 150px;">};
} elsif ($negocio->{logo_url}) {
    $logo_html = qq{<img src="../$negocio->{logo_url}" alt="Logo" style="max-height: 80px; max-width: 150px;">};
} else {
    $logo_html = qq{<h2 style="margin:0; color:#333; font-size:14px;">$negocio->{nombre}</h2>};
}

my $folio_corto = $recibo->{folio} // $id_consulta;
if ($folio_corto =~ /-0*(\d+)$/) {
    $folio_corto = $1;
} elsif ($folio_corto =~ /^\d+$/) {
    $folio_corto = $folio_corto + 0;
}

if ($recibo->{id_paciente} =~ /^EMP-(\w+)/) {
    $num_empleado = $1;
}

if ($num_empleado && $negocio->{clues}) {
    require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
    my $emp_file = catalogo_org_utils::obtener_rutas_por_clue($negocio->{clues})->{empleadosmun};
    
    if (-e $emp_file && open(my $fe, '<:encoding(UTF-8)', $emp_file)) {
        my $h = <$fe>;
        while (my $le = <$fe>) {
            chomp $le;
            my @e = split /!/, $le, -1;
            next unless @e >= 5;
            if ($e[0] eq $num_empleado) {
                if ($e[2] eq 'Empleado') {
                    $empleado_nombre = $e[1] // '';
                    $id_dep = $e[4] // '';
                }
            }
        }
        close $fe;
    }
    
    if ($id_dep) {
        my $dep_file = catalogo_org_utils::obtener_rutas_por_clue($negocio->{clues})->{dependencia};
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
my $especialidad_nombre = '';
if ($id_medico) {
    my $rutas = catalogo_org_utils::obtener_rutas_por_clue($negocio->{clues});
    my $med_file = $rutas->{medicos};
    my $id_especialidad = '';
    
    if (-e $med_file && open(my $fm, '<:encoding(UTF-8)', $med_file)) {
        while (my $lm = <$fm>) {
            chomp $lm;
            my @m = split /\|/, $lm, -1;
            if ($m[0] eq $id_medico) {
                my $idx = (@m >= 3) ? 2 : 1;
                $medico_nombre = uc($m[$idx] // '');
                $id_especialidad = $m[1] // '' if @m >= 3;
                last;
            }
        }
        close $fm;
    }
    
    if ($id_especialidad) {
        my $esp_file = $rutas->{especialidades};
        if (-e $esp_file && open(my $fe, '<:encoding(UTF-8)', $esp_file)) {
            while (my $le = <$fe>) {
                chomp $le;
                my @e = split /\|/, $le, -1;
                if ($e[0] eq $id_especialidad) {
                    $especialidad_nombre = uc($e[1] // '');
                    last;
                }
            }
            close $fe;
        }
    }
    
    if ($medico_nombre eq "NO ESPECIFICADO") {
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
}

sub formato_moneda {
    my ($monto) = @_;
    $monto ||= 0;
    return '' if $monto == 0;
    my $fmt = sprintf("%.2f", $monto);
    while ($fmt =~ s/^(-?\d+)(\d{3})/$1,$2/) {}
    return '$' . $fmt;
}

my $saldo = $recibo->{total_cargos} - $recibo->{total_abonos};
$saldo = 0 if $saldo < 0;



my $abono_saldo_html = "";
if ($saldo > 0) {
    $abono_saldo_html = qq{
        <div style="color: #059669; font-size: 13px; font-weight: normal; margin-bottom: 4px;">Abono : @{[ formato_moneda($recibo->{total_abonos}) ]}</div>
        <div style="color: #dc2626; font-size: 13px; font-weight: normal; margin-bottom: 8px;">Saldo : @{[ formato_moneda($saldo) ]}</div>
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
        /* CSS Específico para Impresión en Carta, sin zoom */
        \@page {
            size: letter portrait;
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
            width: 8.5in;
            box-sizing: border-box;
            padding: 0.5in;
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
                <td class="col-clinic">
                    $negocio->{nombre}
                </td>
                <td class="col-folio" style="font-size: 9px; white-space: nowrap; text-align: center;">
                    $recibo->{fecha} - $recibo->{hora} hrs.<br>
                    <span style="margin-top: 4px; display:inline-block;">Folio</span><br>
                    <span>$folio_corto</span>
                </td>
            </tr>
            <tr>
                <td style="vertical-align: top;">
                    Visita : Primera vez
                </td>
                <td colspan="2" style="padding-left: 10px;">
                    Empleado: $num_empleado - $empleado_nombre<br>
                    Dependencia: $dependencia_nombre
                </td>
            </tr>
            <tr>
                <td class="info-label-cell">Paciente :</td>
                <td colspan="2" style="text-transform: uppercase;">$paciente_nombre</td>
            </tr>
            <tr>
                <td class="info-label-cell">Médico:</td>
                <td colspan="2" style="font-size: 10px; text-transform: uppercase;">
                    $medico_nombre @{[ $especialidad_nombre ? "- $especialidad_nombre" : "" ]}
                </td>
            </tr>
            <tr>
                <td class="info-label-cell" style="vertical-align: top;">Concepto :</td>
                <td colspan="2" style="padding: 0;">
                    <table class="table-inner">
HTML

my %seen;
foreach my $c (@cargos) {
    next if $seen{$c->{concepto}}++;
    my $concepto_txt = $c->{concepto};
    my $precio_fmt = formato_moneda($c->{precio});
    my $subtotal_fmt = formato_moneda($c->{subtotal});
    
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
                            <td style="width: 50%; text-align: center; vertical-align: bottom; height: 60px; padding-bottom: 5px; border: 1px solid #ccc; border-top: none;">
                                <div class="signature-box">
                                    Nombre y Firma del Paciente
                                </div>
                            </td>
                            <td style="width: 50%; text-align: left; vertical-align: middle; padding: 15px; border: 1px solid #ccc; border-top: none; border-left: none;">
                                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; font-size: 14px; font-weight: normal;">
                                    <span>Cuentas x cobrar</span>
                                    <span>@{[ formato_moneda($recibo->{total_cargos}) ]}</span>
                                </div>
                                <div style="display: flex; justify-content: flex-end; align-items: center; gap: 8px; margin-top: 15px;">
                                    <span style="font-size: 11px; text-align: right; white-space: nowrap; font-weight: normal; color: #334155;">Elaboró : $elaborado_por</span>
                                </div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
            <tr>
                <td colspan="3" style="text-align: center; font-size: 8px; font-weight: normal; padding: 6px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; letter-spacing: -0.2px;">
                    $texto_pie_recibo
                </td>
            </tr>
        </table>
    </div>
</body>
</html>
HTML
