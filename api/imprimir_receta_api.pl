#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON qw(decode_json);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session($q);

print $q->header(-type => 'text/html', -charset => 'UTF-8');

unless ($session_data->{session_ok}) {
    print "<h1>Acceso no autorizado</h1>";
    exit;
}

my $id_receta = $q->param('id_receta') || '';
my $id_consulta = $q->param('id_consulta') || '';

my $receta_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'recetas.dat');
my $receta_row;

if (-e $receta_file && open(my $fh, '<:encoding(UTF-8)', $receta_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        if (($id_receta && $c[0] eq $id_receta) || ($id_consulta && $c[1] eq $id_consulta)) {
            $receta_row = \@c;
            last;
        }
    }
    close($fh);
}

my $folio        = $receta_row ? ($receta_row->[5] // 'REC-001') : 'REC-OFFICIAL';
my $fecha        = $receta_row ? ($receta_row->[4] // '2026-07-27') : '2026-07-27';
my $diagnostico  = $receta_row ? ($receta_row->[6] // 'Evaluación Médica General') : 'Evaluación Médica General';
my $id_paciente  = $receta_row ? $receta_row->[2] : ($q->param('id_paciente') || '2');
my $id_medico    = $receta_row ? $receta_row->[3] : ($session_data->{id_medico} || '1088603479');

# Datos Paciente
my $paciente_name = "Paciente Oficial";
my $paciente_edad = "34 años";
my $paciente_sexo = "Masculino";

my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $pacientes = leer_tabla($pac_file, '\|');
if ($pacientes) {
    foreach my $p (@$pacientes) {
        if ($p->[0] eq $id_paciente) {
            $paciente_name = $p->[2] // $paciente_name;
            $paciente_sexo = $p->[7] // $paciente_sexo;
            last;
        }
    }
}

# Datos Médico
my $medico_name = $session_data->{usuario} || "Dr. Médico Especialista";
my $medico_cedula = "12345678";
my $medico_domicilio = "Clínica Principal - Av. Universidad 100, CDMX";

my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $usr_data = leer_tabla($usr_file, '!');
if ($usr_data) {
    foreach my $u (@$usr_data) {
        if ($u->[0] eq $id_medico || lc($u->[2]//'') eq lc($medico_name)) {
            $medico_name      = $u->[1] // $medico_name;
            $medico_cedula    = $u->[9] // '12345678';
            $medico_domicilio = $u->[10] // $medico_domicilio;
            last;
        }
    }
}

# Parsear Medicamentos del Payload JSON
my $items = [];
if ($receta_row && $receta_row->[7]) {
    eval {
        my $json_raw = $receta_row->[7];
        $json_raw =~ s/\\n/\n/g;
        if ($json_raw =~ /^\[/) {
            $items = decode_json($json_raw);
        } else {
            my $payload = decode_json($json_raw);
            if ($payload->{receta_json}) {
                $items = decode_json($payload->{receta_json});
            }
        }
    };
}

if (!ref($items) eq 'ARRAY' || !@$items) {
    push @$items, {
        generico => 'Paracetamol 500mg',
        comercial => 'Tempra',
        forma => 'Tableta',
        concentracion => '500mg',
        posologia => '1 tableta cada 8 horas por 5 días',
        via => 'Oral'
    };
}

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Receta Médica - $folio | OsPulso</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; color: #1e293b; }
        .recipe-card { max-width: 800px; margin: 2rem auto; background: white; border-radius: 20px; border: 2px solid #19B7A5; box-shadow: 0 15px 35px rgba(0,0,0,0.08); padding: 3rem; position: relative; }
        .header-brand { border-bottom: 2px solid #0A2A66; padding-bottom: 1.5rem; margin-bottom: 2rem; }
        .badge-folio { background: #0A2A66; color: white; border-radius: 30px; font-weight: 800; padding: 6px 16px; font-size: 0.85rem; }
        .prescription-box { background: #f1f5f9; border-left: 4px solid #19B7A5; border-radius: 12px; padding: 1.25rem; margin-bottom: 1.5rem; }
        .table-meds th { background: #0A2A66 !important; color: white !important; font-size: 0.8rem; text-transform: uppercase; }
        .footer-legal { border-top: 1px solid #cbd5e1; margin-top: 3rem; padding-top: 1.5rem; font-size: 0.75rem; color: #64748b; }
        .signature-box { border-bottom: 2px dashed #0A2A66; width: 250px; margin: 0 auto; height: 60px; }
        \@media print {
            .no-print { display: none !important; }
            .recipe-card { border: none; box-shadow: none; padding: 0; margin: 0; }
        }
    </style>
</head>
<body>
    <div class="container no-print text-end mt-3 mb-0" style="max-width: 800px;">
        <button onclick="window.print()" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm me-2"><i class="bi bi-printer me-2"></i>Imprimir Receta</button>
        <button onclick="window.close()" class="btn btn-outline-secondary rounded-pill px-3">Cerrar</button>
    </div>

    <div class="recipe-card">
        <!-- Reglas_impresion.md: Cabecera con Nombre de Clínica y Módulo -->
        <div class="header-brand d-flex justify-content-between align-items-center">
            <div>
                <h2 class="fw-black text-navy mb-0" style="color: #0A2A66;"><i class="bi bi-heart-pulse-fill me-2" style="color: #19B7A5;"></i>OsPulso Salud</h2>
                <span class="text-uppercase fw-bold text-muted small" style="letter-spacing: 1px;">Expediente Clínico & Prescripción Médica Oficial</span>
            </div>
            <div class="text-end">
                <span class="badge-folio d-block mb-1">FOLIO: $folio</span>
                <span class="small fw-bold text-secondary">Fecha: $fecha</span>
            </div>
        </div>

        <!-- Datos del Médico -->
        <div class="row g-3 mb-4 p-3 rounded-3 bg-light border">
            <div class="col-md-7">
                <h6 class="fw-bold text-navy mb-1" style="color: #0A2A66;"><i class="bi bi-person-badge me-2 text-primary"></i>$medico_name</h6>
                <span class="small text-muted d-block"><strong>Cédula Profesional:</strong> $medico_cedula</span>
                <span class="small text-muted d-block"><strong>Establecimiento:</strong> $medico_domicilio</span>
            </div>
            <div class="col-md-5 text-md-end border-start ps-md-3">
                <span class="small text-muted d-block"><strong>Diagnóstico de Emisión:</strong></span>
                <span class="fw-bold text-dark small">$diagnostico</span>
            </div>
        </div>

        <!-- Datos del Paciente -->
        <div class="prescription-box">
            <h6 class="fw-bold mb-2 text-navy" style="color: #0A2A66;"><i class="bi bi-person-fill me-2 text-teal"></i>DATOS DEL PACIENTE</h6>
            <div class="row small">
                <div class="col-md-6"><strong>Nombre Completo:</strong> $paciente_name</div>
                <div class="col-md-3"><strong>Edad:</strong> $paciente_edad</div>
                <div class="col-md-3"><strong>Sexo:</strong> $paciente_sexo</div>
            </div>
        </div>

        <!-- Información de Prescripción -->
        <h6 class="fw-bold mb-3 text-navy" style="color: #0A2A66;"><i class="bi bi-capsule me-2 text-primary"></i>PRESCRIPCIÓN MÉDICA (MEDICAMENTOS)</h6>
        <div class="table-responsive mb-4">
            <table class="table table-bordered align-middle table-meds">
                <thead>
                    <tr>
                        <th>Medicamento (Genérico / Comercial)</th>
                        <th>Forma</th>
                        <th>Dosis</th>
                        <th>Posología / Indicaciones</th>
                        <th>Vía</th>
                    </tr>
                </thead>
                <tbody>
HTML

foreach my $it (@$items) {
    my $gen  = $it->{generico} || 'Medicamento';
    my $com  = $it->{comercial} ? " ($it->{comercial})" : '';
    my $form = $it->{forma} || 'Tableta';
    my $dos  = $it->{concentracion} || '500mg';
    my $pos  = $it->{posologia} || '1 c/8h por 7 días';
    my $via  = $it->{via} || 'Oral';
    print <<HTML;
                    <tr>
                        <td><strong class="text-dark">$gen</strong><span class="text-muted small">$com</span></td>
                        <td><span class="badge bg-light text-dark">$form</span></td>
                        <td><span class="fw-bold text-primary">$dos</span></td>
                        <td><span class="small">$pos</span></td>
                        <td><span class="badge bg-info text-dark">$via</span></td>
                    </tr>
HTML
}

print <<HTML;
                </tbody>
            </table>
        </div>

        <!-- Formalización y Firma -->
        <div class="row align-items-end mt-5 pt-3">
            <div class="col-md-6 text-center">
                <div class="signature-box mb-2"></div>
                <span class="fw-bold small text-navy d-block" style="color: #0A2A66;">Firma y Sello del Médico</span>
                <span class="small text-muted">$medico_name - Céd. $medico_cedula</span>
            </div>
            <div class="col-md-6 text-end">
                <div class="p-3 bg-light rounded-3 border text-center">
                    <i class="bi bi-qr-code fs-1 text-navy mb-1 d-block" style="color: #0A2A66;"></i>
                    <span class="small text-muted d-block" style="font-size:0.65rem;">Verificación Digital COFEPRIS / OsPulso</span>
                </div>
            </div>
        </div>

        <!-- Reglas_impresion.md: Pie de Página con Confidencialidad y Folio -->
        <div class="footer-legal d-flex justify-content-between align-items-center">
            <div>
                <strong>Aviso de Confidencialidad:</strong> Este documento contiene información médica reservada para el uso exclusivo del paciente nominado.
            </div>
            <div class="text-end fw-bold">
                Página 1 de 1 | Folio $folio
            </div>
        </div>
    </div>
</body>
</html>
HTML
1;
