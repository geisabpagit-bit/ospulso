#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use CGI::Carp qw(fatalsToBrowser);
use File::Spec;
use FindBin;
use JSON qw(decode_json);
use open qw(:std :utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $q = CGI->new;
my $session_data = check_session($q);

unless ($session_data->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $id_consulta = $q->param('id_consulta') || $q->param('folio') || '';
$id_consulta =~ s/^\s+|\s+$//g;

print $q->header(-type => 'text/html', -charset => 'UTF-8');

if (!$id_consulta) {
    print "<html><head><title>Error</title></head><body style='font-family: sans-serif; padding: 2rem; text-align: center;'>";
    print "<h3 style='color: #dc2626;'>Falta el Folio o ID de Consulta</h3>";
    print "<p>No se especificó ningún comprobante para visualizar.</p>";
    print "</body></html>";
    exit;
}

my $ses_org = $session_data->{id_empresa} // '';
my $ses_role = $session_data->{role} // '';

# 1. Localizar Recibo en folios_recibos_privados.dat con Aislamiento Multitenant
my $recibo = {};
my $recibos_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'folios_recibos_privados.dat');

if (-e $recibos_file && open(my $fh, '<:encoding(UTF-8)', $recibos_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        
        my $c_id    = $c[0] // '';
        my $c_folio = $c[1] // '';
        my $c_neg   = $c[2] // '';
        my $c_cons  = $c[4] // '';

        # Aislamiento por organización: Solo el Administrador Global puede ver otros tenants
        if ($ses_role ne 'Administrador Global' && defined $ses_org && $ses_org ne '') {
            my $match_org = ($c_neg eq $ses_org) || (($c_neg eq '0' || $c_neg eq '') && ($ses_org eq '0' || $ses_org eq ''));
            next unless $match_org;
        }

        # Coincidencia exacta de Folio, ID de recibo o ID de Consulta
        my $param_folio_raw = $q->param('folio') // '';
        $param_folio_raw =~ s/^\s+|\s+$//g;

        my $match = 0;
        if ($c_folio eq $id_consulta || $c_id eq $id_consulta || $c_cons eq $id_consulta) {
            $match = 1;
        } elsif ($param_folio_raw ne '' && ($c_folio eq $param_folio_raw || $c_id eq $param_folio_raw)) {
            $match = 1;
        } elsif ($c_folio =~ /^\d+$/ && $id_consulta =~ /^\d+$/ && int($c_folio) == int($id_consulta)) {
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
                items_json    => $c[13] || '[]',
                estatus       => $c[14] || 'Cobrado',
                id_medico     => $c[15] || ''
            };
            last;
        }
    }
    close $fh;
}

# 1.1 Si no se encontró directo, intentar asociar por dat/consultas_clinicas.dat (ej. id_consulta tipo CONS-...)
if (!keys %$recibo) {
    my $cons_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
    if (-e $cons_file && open(my $fhc, '<:encoding(UTF-8)', $cons_file)) {
        my $hc = <$fhc>;
        while (my $lc = <$fhc>) {
            chomp $lc;
            next if $lc =~ /^\s*$/;
            my @c = split /\|/, $lc, -1;
            if (@c >= 6 && ($c[0] eq $id_consulta || ($c[2] && $c[2] eq $id_consulta))) {
                my $cid_cons = $c[0];
                my $cid_pac  = $c[1];
                my $cid_cita = $c[2];
                my $cid_med  = $c[3];
                my $cts      = $c[4] || time();
                my ($c_sec,$c_min,$c_hour,$c_mday,$c_mon,$c_year) = localtime($cts);
                my $c_fec = sprintf("%04d-%02d-%02d", $c_year+1900, $c_mon+1, $c_mday);
                my $c_hor = sprintf("%02d:%02d", $c_hour, $c_min);
                
                # Intentar buscar en folios_recibos_privados.dat por id_cita
                if ($cid_cita && -e $recibos_file && open(my $fhr2, '<:encoding(UTF-8)', $recibos_file)) {
                    <$fhr2>;
                    while (my $lr2 = <$fhr2>) {
                        chomp $lr2;
                        my @cr = split /\|/, $lr2, -1;
                        if (($cr[4] && $cr[4] eq $cid_cita) || ($cr[1] && $cr[1] eq $cid_cita) || ($cr[0] && $cr[0] eq $cid_cita)) {
                            $recibo = {
                                id_recibo     => $cr[0],
                                folio         => $cr[1],
                                id_negocio    => $cr[2],
                                id_sucursal   => $cr[3],
                                id_consulta   => $cr[4],
                                id_paciente   => $cr[5],
                                fecha         => $cr[6],
                                hora          => $cr[7],
                                total_cargos  => $cr[8] || 0,
                                total_abonos  => $cr[9] || 0,
                                metodo_pago   => $cr[10] || 'Efectivo',
                                elaborado_por => $cr[11] || '',
                                concepto      => $cr[12] || '',
                                items_json    => $cr[13] || '[]',
                                estatus       => $cr[14] || 'Cobrado',
                                id_medico     => $cr[15] || ''
                            };
                            last;
                        }
                    }
                    close $fhr2;
                }
                
                # Si aún no existe en folios_recibos_privados, reconstruir desde payload_json de la consulta
                if (!keys %$recibo) {
                    my $pdata = {};
                    eval { $pdata = decode_json($c[5]); };
                    my @cargos_items;
                    my $raw_items = $pdata->{caja_items_json} || $pdata->{caja_items};
                    if ($raw_items) {
                        my $arr = ref($raw_items) eq 'ARRAY' ? $raw_items : eval { decode_json($raw_items) };
                        if (ref($arr) eq 'ARRAY') {
                            foreach my $it (@$arr) {
                                my $nom = $it->{nombre} || $it->{concepto} || 'Consulta Médica';
                                my $pu  = $it->{precio} // 0;
                                my $cnt = $it->{cantidad} // 1;
                                push @cargos_items, {
                                    concepto => $nom,
                                    precio   => $pu + 0,
                                    cantidad => $cnt + 0,
                                    subtotal => ($pu * $cnt) + 0
                                };
                            }
                        }
                    }
                    if (!@cargos_items) {
                        push @cargos_items, {
                            concepto => 'Consulta Médica de Especialidad',
                            precio   => 0,
                            cantidad => 1,
                            subtotal => 0
                        };
                    }
                    
                    my $tot_c = 0;
                    foreach my $ci (@cargos_items) { $tot_c += $ci->{subtotal}; }
                    my $abono_val = $pdata->{caja_monto_abono} // $tot_c;
                    my $metodo_val = $pdata->{caja_metodo_pago} // 'Efectivo';
                    use JSON qw(encode_json);
                    
                    $recibo = {
                        id_recibo     => 'REC-' . ($cid_cita || 'CONS'),
                        folio         => ($cid_cita || '1'),
                        id_negocio    => $ses_org || '0',
                        id_sucursal   => '0',
                        id_consulta   => $cid_cons,
                        id_paciente   => $cid_pac,
                        fecha         => $c_fec,
                        hora          => $c_hor,
                        total_cargos  => $tot_c,
                        total_abonos  => $abono_val,
                        metodo_pago   => $metodo_val,
                        elaborado_por => $cid_med,
                        concepto      => $cargos_items[0]->{concepto},
                        items_json    => encode_json(\@cargos_items),
                        estatus       => 'Cobrado',
                        id_medico     => $cid_med
                    };
                }
                last;
            }
        }
        close $fhc;
    }
}

if (!keys %$recibo) {
    print "<html><head><title>Recibo No Encontrado</title></head><body style='font-family: sans-serif; padding: 3rem; text-align: center;'>";
    print "<div style='max-width: 500px; margin: auto; padding: 2rem; border-radius: 12px; background: #fff; box-shadow: 0 4px 12px rgba(0,0,0,0.1);'>";
    print "<h3 style='color: #0A2A66; margin-bottom: 0.5rem;'>Recibo no encontrado</h3>";
    print "<p style='color: #64748b;'>No se localizó ningún comprobante con el folio <strong>$id_consulta</strong> en su consultorio.</p>";
    print "<button onclick='window.close()' style='padding: 8px 18px; border-radius: 8px; background: #0A2A66; color: white; border: none; cursor: pointer;'>Cerrar</button>";
    print "</div></body></html>";
    exit;
}

# 2. Obtener Datos del Paciente
my $paciente_nombre = 'Público General';
if ($recibo->{id_paciente} && $recibo->{id_paciente} ne 'PAC-GENERICO') {
    my $pacientes_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
    if (-e $pacientes_file && open(my $fhp, '<:encoding(UTF-8)', $pacientes_file)) {
        <$fhp>; # Salta header
        while (my $lp = <$fhp>) {
            chomp $lp;
            next if $lp =~ /^\s*$/;
            my @p = split /\|/, $lp, -1;
            if ($p[0] eq $recibo->{id_paciente}) {
                $paciente_nombre = $p[2] // $recibo->{id_paciente};
                last;
            }
        }
        close $fhp;
    }
}

# 3. Obtener Datos del Médico Tratante (Cédula y Especialidad)
my $medico_nombre = 'Médico Tratante';
my $medico_cedula = '';
my $medico_esp_id = '';
my $medico_especialidad = 'Medicina General';

my $usuarios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
if (-e $usuarios_file && open(my $fhu, '<:encoding(UTF-8)', $usuarios_file)) {
    <$fhu>;
    while (my $lu = <$fhu>) {
        chomp $lu;
        next if $lu =~ /^\s*$/;
        my @u = split /!/, $lu, -1;
        if (($recibo->{id_medico} && ($u[0] eq $recibo->{id_medico} || $u[2] eq $recibo->{id_medico})) ||
            ($recibo->{elaborado_por} && ($u[0] eq $recibo->{elaborado_por} || lc($u[2] // '') eq lc($recibo->{elaborado_por})))) {
            $medico_nombre = $u[1] // $medico_nombre;
            $medico_esp_id = $u[7] // '';
            $medico_cedula = $u[9] // '';
            last;
        }
    }
    close $fhu;
}

# Resolver nombre de Especialidad si existe
if ($medico_esp_id ne '' && $medico_esp_id ne '0') {
    my $esp_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'especialidades.dat');
    if (-e $esp_file && open(my $fhe, '<:encoding(UTF-8)', $esp_file)) {
        <$fhe>;
        while (my $le = <$fhe>) {
            chomp $le;
            next if $le =~ /^\s*$/;
            my @e = split /\|/, $le, -1;
            if ($e[0] eq $medico_esp_id) {
                $medico_especialidad = $e[1] // $medico_especialidad;
                last;
            }
        }
        close $fhe;
    }
}

# 4. Obtener Datos del Consultorio / Negocio
my $negocio_nombre = 'Consultorio Médico';
my $negocio_dir = 'Dirección no registrada';
my $negocio_tel = '';
my $negocio_rfc = '';
my $negocio_logo = '';

my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fhn, '<:encoding(UTF-8)', $negocios_file)) {
    <$fhn>;
    while (my $ln = <$fhn>) {
        $ln =~ s/\x00//g;
        chomp $ln;
        next if $ln =~ /^\s*$/;
        my @n = split /\|/, $ln, -1;
        if ($n[0] eq $recibo->{id_negocio}) {
            $negocio_nombre = $n[1] // $negocio_nombre;
            my $calle   = $n[6] // $n[3] // '';
            my $colonia = $n[17] // '';
            my $muni    = $n[16] // '';
            my $ent     = $n[15] // '';
            my $cp      = $n[14] // '';
            my @partes_dir = grep { $_ ne '' } ($calle, $colonia, $muni, $ent, ($cp ? "C.P. $cp" : ''));
            $negocio_dir    = join(', ', @partes_dir) if @partes_dir;
            $negocio_tel    = $n[7] // $n[12] // '';
            $negocio_rfc    = $n[10] // '';
            $negocio_logo   = $n[9] // '';
            last;
        }
    }
    close $fhn;
}

# 5. Parsear Ítems Vendidos
my $items = [];
eval {
    $items = decode_json($recibo->{items_json});
};
$items = [] unless ref($items) eq 'ARRAY';

# Si items_json estaba vacío, crear concepto genérico a partir del campo concepto
if (@$items == 0) {
    push @$items, {
        concepto => ($recibo->{concepto} || 'Consulta y Servicios Médicos'),
        cantidad => 1,
        precio   => $recibo->{total_cargos},
        subtotal => $recibo->{total_cargos}
    };
}

my $total_cargos_val = $recibo->{total_cargos} + 0;
my $total_abonos_val = $recibo->{total_abonos} + 0;
my $saldo_remanente_val = $total_cargos_val - $total_abonos_val;
$saldo_remanente_val = 0 if $saldo_remanente_val < 0.005;

my $total_cargos_fmt    = sprintf('%.2f', $total_cargos_val);
my $total_abonos_fmt    = sprintf('%.2f', $total_abonos_val);
my $saldo_remanente_fmt = sprintf('%.2f', $saldo_remanente_val);

my $estatus_recibo = ($saldo_remanente_val <= 0.005) ? 'Liquidado' : ($recibo->{estatus} || 'Cobrado');

# Construir Filas de Ítems
my $items_html = '';
foreach my $it (@$items) {
    my $desc = $it->{concepto} // $it->{nombre} // 'Servicio Médico';
    my $cant = $it->{cantidad} // 1;
    my $pu   = sprintf('%.2f', $it->{precio} // 0);
    my $sub  = sprintf('%.2f', $it->{subtotal} // ($cant * ($it->{precio} // 0)));
    $items_html .= qq{
        <tr>
            <td style="text-align: center; padding: 6px 4px; border-bottom: 1px dashed #cbd5e1; font-size: 0.85rem;">$cant</td>
            <td style="padding: 6px 4px; border-bottom: 1px dashed #cbd5e1; font-size: 0.85rem; font-weight: 500;">$desc</td>
            <td style="text-align: right; padding: 6px 4px; border-bottom: 1px dashed #cbd5e1; font-size: 0.85rem;">\$$pu</td>
            <td style="text-align: right; padding: 6px 4px; border-bottom: 1px dashed #cbd5e1; font-size: 0.85rem; font-weight: 600;">\$$sub</td>
        </tr>
    };
}

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Recibo de Cobro - Folio $recibo->{folio}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;900&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css">
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #f1f5f9;
            color: #1e293b;
            margin: 0;
            padding: 20px;
            display: flex;
            justify-content: center;
        }
        .ticket-wrapper {
            width: 100%;
            max-width: 440px;
            background: #ffffff;
            border-radius: 16px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.08), 0 8px 10px -6px rgba(0, 0, 0, 0.04);
            padding: 24px;
            border: 1px solid #e2e8f0;
        }
        .header-negocio {
            text-align: center;
            border-bottom: 2px solid #0A2A66;
            padding-bottom: 14px;
            margin-bottom: 14px;
        }
        .negocio-title {
            font-family: 'Outfit', sans-serif;
            font-size: 1.25rem;
            font-weight: 800;
            color: #0A2A66;
            margin: 0 0 4px 0;
            line-height: 1.2;
        }
        .medico-subtitle {
            font-size: 0.95rem;
            font-weight: 700;
            color: #0f766e;
            margin: 0 0 2px 0;
        }
        .medico-meta {
            font-size: 0.78rem;
            color: #64748b;
            margin: 0;
            line-height: 1.3;
        }
        .badge-folio {
            display: inline-block;
            background: #f0fdfa;
            color: #0f766e;
            border: 1px solid #99f6e4;
            padding: 4px 12px;
            border-radius: 9999px;
            font-weight: 800;
            font-size: 0.85rem;
            letter-spacing: 0.5px;
            margin: 10px 0 4px 0;
        }
        .info-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 4px;
            font-size: 0.82rem;
            background: #f8fafc;
            padding: 10px 12px;
            border-radius: 10px;
            border: 1px solid #e2e8f0;
            margin-bottom: 14px;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
        }
        .info-label { color: #64748b; font-weight: 600; text-transform: uppercase; font-size: 0.72rem; }
        .info-val { font-weight: 700; color: #0A2A66; }
        .table-items {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 14px;
        }
        .table-items th {
            font-size: 0.72rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #475569;
            background: #f1f5f9;
            padding: 6px 4px;
            border-top: 1px solid #cbd5e1;
            border-bottom: 1px solid #cbd5e1;
        }
        .totales-box {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 10px 14px;
            margin-bottom: 14px;
        }
        .total-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 0.88rem;
            margin-bottom: 4px;
        }
        .total-principal {
            font-family: 'Outfit', sans-serif;
            font-size: 1.25rem;
            font-weight: 900;
            color: #0A2A66;
            padding-top: 6px;
            border-top: 1px dashed #cbd5e1;
            margin-top: 6px;
        }
        .footer-recibo {
            text-align: center;
            font-size: 0.72rem;
            color: #94a3b8;
            margin-top: 16px;
            line-height: 1.4;
        }
        .action-bar {
            display: flex;
            gap: 10px;
            margin-bottom: 16px;
            width: 100%;
            max-width: 440px;
        }
        .btn-action {
            flex: 1;
            padding: 10px;
            border: none;
            border-radius: 10px;
            font-weight: 700;
            font-size: 0.88rem;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
            transition: all 0.2s;
        }
        .btn-print { background: #0A2A66; color: #ffffff; }
        .btn-print:hover { background: #071c44; }
        .btn-close { background: #e2e8f0; color: #334155; }
        .btn-close:hover { background: #cbd5e1; }

        \@media print {
            body { background: #ffffff; padding: 0; }
            .action-bar { display: none !important; }
            .ticket-wrapper {
                box-shadow: none;
                border: none;
                padding: 0;
                max-width: 100%;
                width: 100%;
            }
        }
    </style>
</head>
<body>
    <div style="display: flex; flex-direction: column; align-items: center; width: 100%;">
        <!-- Barra de Acciones (No imprimible) -->
        <div class="action-bar">
            <button class="btn-action btn-print" onclick="window.print()">
                <i class="bi bi-printer-fill"></i> Imprimir Recibo
            </button>
            <button class="btn-action btn-close" onclick="cerrarORegresar()">
                <i class="bi bi-arrow-left-circle-fill"></i> Regresar / Cerrar
            </button>
        </div>

        <!-- Ticket de Recibo Consultorio -->
        <div class="ticket-wrapper">
            <!-- Header Negocio / Médico -->
            <div class="header-negocio">
                <h1 class="negocio-title">$negocio_nombre</h1>
                <div class="medico-subtitle">$medico_nombre</div>
                <p class="medico-meta">
                    $medico_especialidad
                    @{[$medico_cedula ? " | Céd. Prof. $medico_cedula" : ""]}
                </p>
                <p class="medico-meta" style="margin-top: 4px;">$negocio_dir</p>
                @{[$negocio_tel ? qq{<p class="medico-meta">Tel. $negocio_tel</p>} : ""]}
                
                <div class="badge-folio">FOLIO: #$recibo->{folio}</div>
            </div>

            <!-- Metadatos de la Venta -->
            <div class="info-grid">
                <div class="info-row">
                    <span class="info-label">Fecha y Hora:</span>
                    <span class="info-val">$recibo->{fecha} $recibo->{hora}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Paciente:</span>
                    <span class="info-val" style="max-width: 65%; text-align: right; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="$paciente_nombre">$paciente_nombre</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Método de Pago:</span>
                    <span class="info-val" style="color: #0f766e;">$recibo->{metodo_pago}</span>
                </div>
                @{[$recibo->{concepto} ? qq{
                <div class="info-row">
                    <span class="info-label">Nota / Concepto:</span>
                    <span class="info-val">$recibo->{concepto}</span>
                </div>
                } : ""]}
            </div>

            <!-- Tabla de Ítems Cobrados -->
            <table class="table-items">
                <thead>
                    <tr>
                        <th style="width: 35px; text-align: center;">Cant.</th>
                        <th>Concepto / Servicio</th>
                        <th style="width: 75px; text-align: right;">Precio</th>
                        <th style="width: 80px; text-align: right;">Total</th>
                    </tr>
                </thead>
                <tbody>
                    $items_html
                </tbody>
            </table>

            <!-- Desglose de Totales -->
            <div class="totales-box">
                <div class="total-row">
                    <span style="color: #64748b; font-weight: 600;">Total Servicios / Tratamiento:</span>
                    <span style="font-weight: 700;">\$$total_cargos_fmt</span>
                </div>
                <div class="total-row total-principal">
                    <span>IMPORTE COBRADO:</span>
                    <span>\$$total_abonos_fmt</span>
                </div>
                <div class="total-row" style="margin-top: 6px; padding-top: 6px; border-top: 1px dashed #cbd5e1;">
                    <span style="font-weight: 700; color: @{[$saldo_remanente_val > 0 ? '#b91c1c' : '#0f766e']};">Saldo Remanente:</span>
                    <span style="font-weight: 800; font-size: 0.95rem; color: @{[$saldo_remanente_val > 0 ? '#b91c1c' : '#0f766e']};">\$$saldo_remanente_fmt @{[$saldo_remanente_val <= 0 ? '(Liquidado)' : '']}</span>
                </div>
                <div class="total-row" style="margin-top: 4px; font-size: 0.78rem;">
                    <span style="color: #0f766e; font-weight: 700;"><i class="bi bi-check-circle-fill me-1"></i>Estatus:</span>
                    <span style="font-weight: 800; color: #0f766e;">$estatus_recibo</span>
                </div>
            </div>

            <!-- Pie de Recibo -->
            <div class="footer-recibo">
                <p style="margin: 0 0 4px 0;">Comprobante emitido para control de cobro en consultorio privado.</p>
                <p style="margin: 0; font-weight: 600;">¡Gracias por su visita y preferencia médica!</p>
            </div>
        </div>
    </div>
    <script>
        function cerrarORegresar() {
            if (window.opener && !window.opener.closed) {
                window.opener.focus();
                window.close();
            } else if (window.history.length > 1) {
                window.history.back();
            } else {
                window.close();
            }
        }
    </script>
</body>
</html>
HTML

1;
