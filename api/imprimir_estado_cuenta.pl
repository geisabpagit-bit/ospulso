#!/usr/bin/perl

use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use lib '..';

require '../auth/check_session.pl';

my $q = CGI->new;
my $session_data = check_session($q);

unless ($session_data->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $id_paciente = $q->param('id') || '';
my $p = {};

if (-e '../dat/pacientes.dat') {
    open(my $fh, '<:encoding(UTF-8)', '../dat/pacientes.dat') or die "No se pudo abrir pacientes.dat: $!";
    while (<$fh>) {
        chomp;
        my @c = split /\|/;
        if ($c[0] eq $id_paciente) {
            $p = { id => $c[0], nombre => $c[2], rfc => $c[3], curp => $c[4], correo => $c[5], telefono => $c[12] };
            last;
        }
    }
    close($fh);
}

unless ($p->{id}) {
    print $q->header(-type => "text/html", -charset => "utf-8");
    print qq{<div style="font-family:sans-serif; text-align:center; padding:50px;">
                <h2 style="color:#d93025;">Error: Paciente no hallado</h2>
                <button onclick="window.close()">Cerrar Ventana</button>
             </div>};
    exit;
}

# --- Leer Transacciones Estado de Cuenta ---
my @transacciones = ();
my $total_cargos = 0;
my $total_abonos = 0;
my $total_iva    = 0;

if (-e '../dat/estado_cuenta.dat') {
    open(my $fh, "<:encoding(UTF-8)", '../dat/estado_cuenta.dat');
    my $header = <$fh>;
    while (<$fh>) {
        chomp;
        my @c = split /\|/;
        if (@c > 6 && $c[1] eq $id_paciente) {
            my $tipo = $c[2];
            my $base = $c[4] + 0;
            my $iva  = $c[5] + 0;
            my $total = $c[6] + 0;
            
            push @transacciones, {
                tipo => $tipo, fecha => $c[7], concepto => $c[3],
                base => $base, iva => $iva, total => $total
            };
            
            if ($tipo eq 'Cargo') {
                $total_cargos += $total;
                $total_iva += $iva;
            } else {
                $total_abonos += $total;
            }
        }
    }
    close $fh;
}

@transacciones = sort { $a->{fecha} cmp $b->{fecha} } @transacciones; # Cronológico antiguo a nuevo

my $saldo_pendiente = $total_cargos - $total_abonos;

sub fmt_money {
    my $num = shift;
    # basic formatting trick
    $num = sprintf("%.2f", $num);
    while ($num =~ s/^(-?\d+)(\d{3})/$1,$2/) {}
    return '$' . $num;
}

print $q->header(-type => "text/html", -charset => "utf-8");

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Estado_de_Cuenta_$p->{id}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        :root { --brand-dark: #002b5c; --brand-primary: #174975; --med-gray: #64748b; }
        body { background: white !important; font-family: 'Inter', sans-serif; -webkit-print-color-adjust: exact; }
        .container-print { max-width: 850px; margin: 0 auto; padding: 40px; }
        .report-header { border-bottom: 3px solid var(--brand-dark); margin-bottom: 30px; padding-bottom: 15px; }
        .info-label { font-size: 0.75rem; color: var(--med-gray); text-transform: uppercase; font-weight: 700; margin-bottom: 2px; }
        .info-value { font-size: 1.05rem; color: #202124; border-bottom: 1px solid #f1f3f4; padding-bottom: 5px; margin-bottom: 15px; }
        
        .transaction-table th { background-color: var(--brand-dark) !important; color: white !important; font-size: 0.85rem; font-weight: 600; text-transform: uppercase; }
        .transaction-table td { font-size: 0.9rem; padding: 12px 10px; border-bottom: 1px solid #dee2e6; }
        
        .summary-box { background-color: #f7f9fc; border-radius: 12px; padding: 20px; border: 1px solid #e2e8f0; }
        .summary-title { font-size: 0.8rem; text-transform: uppercase; color: var(--med-gray); font-weight: bold; }
        .summary-val { font-size: 1.5rem; font-weight: 800; color: var(--brand-dark); }
        .val-danger { color: #dc3545; }
        .val-success { color: #198754; }
        
        \@media print {
            .no-print { display: none !important; }
            .container-print { padding: 0; width: 100%; }
        }
    </style>
</head>
<body onload="window.print()">

    <div class="no-print bg-light p-3 border-bottom text-center mb-4">
        <button onclick="window.print()" class="btn btn-primary btn-sm me-2 fw-bold"><i class="bi bi-printer"></i> Imprimir</button>
        <button onclick="window.close()" class="btn btn-outline-secondary btn-sm fw-bold">Cerrar</button>
    </div>

    <div class="container-print">
        <div class="report-header d-flex justify-content-between align-items-end">
            <div>
                <h2 style="color: var(--brand-dark); font-weight: 800; margin: 0; letter-spacing: -1px;">ESTADO DE CUENTA CLÍNICO</h2>
                <p class="text-muted mb-0 small">Software Dental Mexicano | ID Paciente: $p->{id}</p>
            </div>
            <div class="text-end">
                <p class="mb-0 fw-bold" style="color: var(--brand-dark);">Fecha de Emisión: @{[scalar(localtime)]}</p>
            </div>
        </div>

        <div class="row mt-4 mb-4">
            <div class="col-8">
                <div class="info-label">Paciente</div>
                <div class="info-value fw-bold" style="font-size: 1.3rem;">$p->{nombre}</div>
            </div>
            <div class="col-4">
                <div class="info-label">RFC (Facturación)</div>
                <div class="info-value">$p->{rfc}</div>
            </div>
        </div>

        <!-- TABLA DE MOVIMIENTOS -->
        <table class="table transaction-table mb-5">
            <thead>
                <tr>
                    <th width="15%">FECHA</th>
                    <th width="40%">CONCEPTO</th>
                    <th class="text-end" width="15%">CARGOS</th>
                    <th class="text-end" width="15%">ABONOS</th>
                    <th class="text-end" width="15%">SALDO PARCIAL</th>
                </tr>
            </thead>
            <tbody>
HTML

my $saldo_parcial = 0;
if (@transacciones) {
    foreach my $t (@transacciones) {
        my $c_cargo = '-';
        my $c_abono = '-';
        if ($t->{tipo} eq 'Cargo') {
            $c_cargo = fmt_money($t->{total});
            $saldo_parcial += $t->{total};
        } else {
            $c_abono = fmt_money($t->{total});
            $saldo_parcial -= $t->{total};
        }
        
        my $info_iva = $t->{iva} > 0 ? " <span style='color:#888; font-size:0.75rem;'>(Incluye IVA ".fmt_money($t->{iva}).")</span>" : "";
        print qq{
            <tr>
                <td class="text-muted small">$t->{fecha}</td>
                <td><strong>$t->{concepto}</strong>$info_iva</td>
                <td class="text-end text-danger">$c_cargo</td>
                <td class="text-end text-success">$c_abono</td>
                <td class="text-end fw-bold">}.fmt_money($saldo_parcial).qq{</td>
            </tr>
        };
    }
} else {
    print qq{<tr><td colspan="5" class="text-center py-4 text-muted">No existen movimientos financieros registrados.</td></tr>};
}

print <<HTML;
            </tbody>
        </table>

        <!-- RESUMEN FINANCIERO -->
        <div class="row g-3 justify-content-end">
            <div class="col-md-5">
                <div class="summary-box">
                    <div class="d-flex justify-content-between mb-2">
                        <span class="summary-title">Total Cargos (Tratamientos)</span>
                        <span class="fw-bold">@{[fmt_money($total_cargos)]}</span>
                    </div>
                    <!-- Desglose estricto del IVA interno cobrado en el total de los cargos -->
                    <div class="d-flex justify-content-between mb-2 border-bottom pb-2">
                        <span class="summary-title" style="font-size:0.75rem;">∟ IVA 16% Integrado</span>
                        <span class="text-muted small">@{[fmt_money($total_iva)]}</span>
                    </div>
                    <div class="d-flex justify-content-between mb-2 border-bottom pb-2 mt-2">
                        <span class="summary-title text-success">Pagado / Abonado</span>
                        <span class="fw-bold text-success">- @{[fmt_money($total_abonos)]}</span>
                    </div>
                    <div class="d-flex justify-content-between align-items-end mt-3">
                        <span class="summary-title" style="font-size:1rem; color:#002b5c;">SALDO AL CORTE</span>
                        <span class="summary-val">@{[fmt_money($saldo_pendiente)]}</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="mt-5 pt-5 text-center text-muted border-top">
            <p class="small">Este estado de cuenta refleja los movimientos registrados hasta el corte actual.<br>
            Para dudas o aclaraciones comerciales, por favor contactar con su especialista.</p>
        </div>

    </div>
</body>
</html>
HTML
