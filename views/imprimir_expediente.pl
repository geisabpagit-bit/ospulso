#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib $FindBin::Bin . '/..';

require '../auth/check_session.pl';
require '../utils/sub_header.pl';
require '../utils/sub_footer.pl';
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();
unless ($session_data->{session_ok}) { print $q->header(-status => '302 Found', -location => '../index.html'); exit; }

my $id_paciente = $q->param('id');
unless ($id_paciente) { print $q->header(-type => 'text/html', -charset => 'UTF-8'); print "Error: ID de paciente no proporcionado."; exit; }

# Cargar Datos del Paciente
my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $paciente;
my $reg = leer_tabla($archivo_pacientes, '\|');
foreach (@$reg) { 
    if ($_->[0] eq $id_paciente) { 
        my $edad = 'N/A';
        if ($_->[6] && $_->[6] =~ /(\d{4})/) {
            $edad = ((localtime)[5] + 1900) - $1;
        }
        $paciente = { 
            id => $_->[0], 
            curp => $_->[4] || 'N/A',
            nombre => $_->[2], 
            correo => $_->[5] || 'N/A',
            telefono => $_->[12] || 'N/A',
            sexo => $_->[7] || 'N/A',
            edad => $edad,
            sangre => $_->[11] || 'N/A'
        }; last; 
    } 
}

unless ($paciente) { print $q->header(-type => 'text/html', -charset => 'UTF-8'); print "Error: Paciente no localizado."; exit; }

# Obtener Saldo (Simulado o desde API si existiera, aquí lo leemos de la lógica de negocio básica)
my $saldo = "0.00"; # En un sistema real se calcularía sumando cargos - abonos

# Renderizado del Informe de Impresión
print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Resumen Clínico - $paciente->{nombre}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;700&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: white; color: black; }
        .print-container { max-width: 800px; margin: 0 auto; padding: 40px; }
        .header-border { border-bottom: 3px solid #000; padding-bottom: 20px; margin-bottom: 30px; }
        .section-title { background: #f8fafc; border-left: 5px solid #000; padding: 8px 15px; font-weight: bold; text-transform: uppercase; font-size: 0.9rem; margin-bottom: 20px; }
        .data-label { font-size: 0.75rem; color: #64748b; text-uppercase; font-weight: bold; }
        .data-value { font-size: 1rem; font-weight: 700; margin-bottom: 15px; }
        
        \@media print {
            .no-print { display: none !important; }
            body { padding: 0; margin: 0; }
            .print-container { padding: 0; width: 100%; max-width: 100%; }
        }
    </style>
</head>
<body onload="window.print()">

    <div class="no-print bg-dark text-white p-3 text-center mb-4">
        <span class="fw-bold">VISTA DE IMPRESI&Oacute;N</span> - Presione Ctrl+P si el cuadro de di&aacute;logo no aparece.
        <a href="javascript:window.close()" class="btn btn-sm btn-outline-light ms-3">Cerrar Ventana</a>
    </div>

    <div class="print-container">
        <!-- Encabezado Corporativo -->
        <div class="header-border d-flex justify-content-between align-items-end">
            <div>
                <h2 class="fw-bold mb-0">SOFTWARE DENTAL MEXICANO</h2>
                <p class="mb-0 text-muted small">Reporte de Resumen de Expediente Cl&iacute;nico</p>
            </div>
            <div class="text-end">
                <p class="mb-0 fw-bold">ID: $paciente->{id}</p>
                <p class="mb-0 small">Generado: @{[scalar localtime]}</p>
            </div>
        </div>

        <!-- Ficha de Identificación -->
        <div class="section-title">I. Ficha de Identificaci&oacute;n</div>
        <div class="row mb-4">
            <div class="col-6">
                <div class="data-label">Nombre Completo</div>
                <div class="data-value">$paciente->{nombre}</div>
                
                <div class="data-label">CURP</div>
                <div class="data-value">$paciente->{curp}</div>
            </div>
            <div class="col-3">
                <div class="data-label">Edad</div>
                <div class="data-value">$paciente->{edad} a&ntilde;os</div>
                
                <div class="data-label">Sexo</div>
                <div class="data-value">$paciente->{sexo}</div>
            </div>
            <div class="col-3">
                <div class="data-label">Tipo Sangre</div>
                <div class="data-value">$paciente->{sangre}</div>
                
                <div class="data-label">Tel&eacute;fono</div>
                <div class="data-value">$paciente->{telefono}</div>
            </div>
        </div>

        <!-- Resumen Financiero -->
        <div class="section-title">II. Estatus Financiero</div>
        <div class="row mb-5">
            <div class="col-4">
                <div class="p-3 border rounded text-center">
                    <div class="data-label">Saldo Pendiente</div>
                    <div class="h3 fw-bold mb-0">\$ $saldo</div>
                </div>
            </div>
            <div class="col-8">
                <p class="small text-muted pt-2 italic">Este saldo refleja la suma consolidada de cargos y abonos a la fecha de este reporte. Para un desglose detallado, favor de solicitar el Estado de Cuenta.</p>
            </div>
        </div>

        <!-- Firma -->
        <div style="margin-top: 100px;">
            <div class="row">
                <div class="col-6 text-center">
                    <div style="border-top: 1px solid #000; width: 80%; margin: 0 auto; padding-top: 10px;">
                        <p class="small mb-0 fw-bold">FIRMA DEL PACIENTE</p>
                        <p class="text-muted" style="font-size: 10px;">Aceptaci&oacute;n de t&eacute;rminos y veracidad de datos</p>
                    </div>
                </div>
                <div class="col-6 text-center">
                    <div style="border-top: 1px solid #000; width: 80%; margin: 0 auto; padding-top: 10px;">
                        <p class="small mb-0 fw-bold">M&Eacute;DICO TRATANTE</p>
                        <p class="text-muted" style="font-size: 10px;">Software Dental Mexicano v3.7</p>
                    </div>
                </div>
            </div>
        </div>

        <!-- Footer -->
        <div class="mt-5 pt-5 text-center text-muted" style="font-size: 9px; border-top: 1px solid #eee;">
            Este documento es un resumen informativo. No sustituye la historia cl&iacute;nica detallada ni tiene validez legal como certificado m&eacute;dico sin la firma y sello original de la instituci&oacute;n.
        </div>
    </div>

</body>
</html>
HTML
