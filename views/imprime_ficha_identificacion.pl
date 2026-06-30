#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use Encode qw(decode encode);
use POSIX qw(strftime);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $q = CGI->new;
my $session_data = check_session($q);
unless ($session_data->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $id_paciente = $q->param('id') || '';
my $p = {};

eval {
    # Validación UTF-8: Garantizar que la salida será UTF-8
    binmode STDOUT, ":utf8";

    my $archivo = "$FindBin::Bin/../dat/pacientes.dat";
    die "No se pudo abrir $archivo" unless -e $archivo;

    open(my $fh, '<:encoding(UTF-8)', $archivo) or die "Error IO: $!";
    while (my $l = <$fh>) {
        chomp $l;
        my @c = split /\|/, $l, -1;
        if ($c[0] eq $id_paciente) {
            $p = {
                id           => $c[0],
                nombre       => $c[2],
                rfc          => $c[3],
                curp         => $c[4],
                correo       => $c[5],
                fnac         => $c[6],
                sexo         => $c[7],
                ocupacion    => $c[8],
                estado_civil => $c[9],
                nacionalidad => $c[10],
                sangre       => $c[11],
                telefono     => $c[12]
            };
            last;
        }
    }
    close($fh);

    die "Paciente no hallado" unless $p->{id};
};
if ($@) {
    my $error = $@;
    # Observabilidad Capa 4: Log de error
    open(my $log, '>>:encoding(UTF-8)', "$FindBin::Bin/../logs/execution.log");
    print $log "[".strftime("%Y-%m-%d %H:%M:%S", localtime)."] [ERROR 500] imprime_ficha_identificacion.pl: $error\n" if $log;
    close($log) if $log;

    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print qq{
        <!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Error 500</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet"></head>
        <body class="bg-light d-flex align-items-center justify-content-center vh-100">
            <div class="text-center p-5 bg-white border rounded shadow-sm">
                <h1 class="text-danger fw-bold">Error 500</h1>
                <p class="text-muted">Falla en generación de reporte. El incidente ha sido registrado.</p>
                <button class="btn btn-outline-secondary mt-3" onclick="window.close()">Cerrar</button>
            </div>
        </body></html>
    };
    exit;
}

my $fecha_actual = strftime("%d/%m/%Y", localtime);

print $q->header(-type => "text/html", -charset => "utf-8");
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Ficha_Identificacion_$p->{id}</title>
    <style>
        body { font-family: 'Arial', sans-serif; background: white; color: #1e293b; font-size: 12px; margin: 0; padding: 0; -webkit-print-color-adjust: exact; }
        .print-page { max-width: 800px; margin: 0 auto; padding: 40px; }
        
        /* Reglas de Impresión: Cabecera */
        .report-header { border-bottom: 2px solid #0A2A66; margin-bottom: 20px; padding-bottom: 10px; }
        .report-header h2 { margin: 0; color: #0A2A66; font-size: 24px; font-weight: bold; }
        .report-header p { margin: 5px 0 0 0; font-size: 14px; }
        
        /* Reglas de Impresión: Pie de Página */
        .report-footer { border-top: 1px solid #cbd5e1; margin-top: 40px; padding-top: 10px; font-size: 10px; color: #64748b; text-align: center; }
        .report-footer p { margin: 3px 0; }
        
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-top: 20px; }
        .info-box { border: 1px solid #e2e8f0; padding: 15px; border-radius: 8px; }
        .info-label { font-size: 10px; font-weight: bold; color: #64748b; text-transform: uppercase; margin-bottom: 4px; }
        .info-value { font-size: 14px; font-weight: bold; color: #0f172a; }
        
        \@media print {
            .no-print { display: none !important; }
            .print-page { width: 100%; padding: 0; }
        }
    </style>
</head>
<body onload="window.print()">
    <div class="no-print" style="background:#f1f5f9; padding: 10px; text-align:center; border-bottom: 1px solid #cbd5e1;">
        <button onclick="window.print()" style="padding: 5px 15px; cursor:pointer;">Imprimir</button>
        <button onclick="window.close()" style="padding: 5px 15px; cursor:pointer;">Cerrar</button>
    </div>

    <div class="print-page">
        <!-- Cabecera Estandarizada -->
        <div class="report-header">
            <h2>Hospital SDM Diamond</h2>
            <p><strong>M&oacute;dulo:</strong> Ficha de Identificaci&oacute;n de Paciente</p>
            <p><strong>Fecha:</strong> $fecha_actual</p>
        </div>

        <!-- Cuerpo del Documento -->
        <div style="margin-bottom: 20px;">
            <div style="font-size: 12px; color:#64748b; font-weight:bold; text-transform:uppercase;">Paciente ID: SDM-$p->{id}</div>
            <div style="font-size: 22px; font-weight:bold; color:#0A2A66;">$p->{nombre}</div>
        </div>

        <div class="info-grid">
            <div class="info-box">
                <div class="info-label">RFC / CURP</div>
                <div class="info-value">$p->{rfc} / $p->{curp}</div>
            </div>
            <div class="info-box">
                <div class="info-label">Fecha de Nacimiento</div>
                <div class="info-value">$p->{fnac}</div>
            </div>
            <div class="info-box">
                <div class="info-label">Sexo / Sangre</div>
                <div class="info-value">$p->{sexo} | <span style="color:#e63946;">$p->{sangre}</span></div>
            </div>
            <div class="info-box">
                <div class="info-label">Estado Civil / Nacionalidad</div>
                <div class="info-value">$p->{estado_civil} / $p->{nacionalidad}</div>
            </div>
            <div class="info-box" style="grid-column: span 2;">
                <div class="info-label">Ocupaci&oacute;n</div>
                <div class="info-value">$p->{ocupacion}</div>
            </div>
            <div class="info-box">
                <div class="info-label">Correo Electr&oacute;nico</div>
                <div class="info-value">$p->{correo}</div>
            </div>
            <div class="info-box">
                <div class="info-label">Tel&eacute;fono</div>
                <div class="info-value">$p->{telefono}</div>
            </div>
        </div>

        <!-- Pie de Impresión Estandarizado -->
        <div class="report-footer">
            <p><strong>Direcci&oacute;n:</strong> Av Reforma 100, CDMX | <strong>Tel&eacute;fono:</strong> 555-1234-567 | <strong>Correo:</strong> contacto\@sdm.com</p>
            <p><strong>Aviso de confidencialidad:</strong> Este documento contiene informaci&oacute;n confidencial destinada &uacute;nicamente al receptor autorizado.</p>
            <p><strong>C&oacute;digo interno:</strong> SDM-FCH-01 | <strong>P&aacute;gina 1 de 1</strong></p>
        </div>
    </div>
</body>
</html>
HTML