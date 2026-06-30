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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session($q);
unless ($session_data->{session_ok}) { print $q->header(-status => '302 Found', -location => '../index.html'); exit; }

binmode STDOUT, ":utf8";

my $id_consulta = $q->param('id_consulta') || '';

if (!$id_consulta) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<h1>Falta id_consulta</h1>";
    exit;
}

# 1. Cargar la consulta
my $path_consultas = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
my $res_consultas = leer_tabla($path_consultas, '\|');
my $consulta = {};
foreach my $c (@$res_consultas) {
    if ($c->[0] eq $id_consulta) {
        my $json_str = $c->[5] || '{}';
        $json_str =~ s/\\n/\n/g;
        my $data = {};
        eval { $data = decode_json($json_str); };
        $consulta = {
            id_consulta => $c->[0],
            id_paciente => $c->[1],
            id_cita     => $c->[2],
            id_medico   => $c->[3],
            timestamp   => $c->[4],
            fecha       => scalar localtime($c->[4]),
            data        => $data
        };
        last;
    }
}

if (!keys %$consulta) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<h1>Consulta no encontrada</h1>";
    exit;
}

# 2. Cargar Paciente
my $path_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $res_pacientes = leer_tabla($path_pacientes, '\|');
my $paciente = {};
foreach my $p (@$res_pacientes) {
    if ($p->[0] eq $consulta->{id_paciente}) {
        $paciente = {
            nombre => $p->[2],
            fecha_nac => $p->[3],
            sexo => $p->[7],
            alergias => $p->[11] || 'Negadas',
            ts => $p->[10] || 'O+'
        };
        last;
    }
}

# 3. Obtener nombre del médico
my $path_med = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $res_med = leer_tabla($path_med, '!');
my $nombre_medico = $consulta->{id_medico};
foreach my $m (@$res_med) {
    if ($m->[0] eq $consulta->{id_medico} || "DOC-" . sprintf("%03d", $m->[0]) eq $consulta->{id_medico}) {
        $nombre_medico = "Dr(a). " . $m->[1];
        last;
    }
}

my $d = $consulta->{data};

print $q->header(-type => 'text/html', -charset => 'UTF-8');

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Detalles de Consulta - $id_consulta</title>
    <!-- Core MedentIA Diamond Armor Styles -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap" rel="stylesheet">
    
    <style>
        :root {
            --md-teal-clinical: #19B7A5;
            --md-blue-deep: #0A2A66;
            --md-navy: #051A44;
            --md-gray-bg: #F1F5F9;
        }
        body {
            font-family: 'Inter', sans-serif;
            background: var(--md-gray-bg);
            color: var(--md-blue-deep);
        }
        
        .bento-card {
            background: #ffffff;
            border-radius: 1.5rem;
            padding: 2rem;
            box-shadow: 0 10px 30px rgba(10, 42, 102, 0.05);
            border: 2px solid var(--md-teal-clinical);
            height: 100%;
        }
        
        .bento-title {
            font-size: 1.1rem;
            font-weight: 800;
            color: var(--md-teal-clinical);
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            border-bottom: 2px solid var(--md-gray-bg);
            padding-bottom: 0.8rem;
        }
        
        .data-label {
            font-size: 0.75rem;
            font-weight: 800;
            text-transform: uppercase;
            color: #64748b;
            margin-bottom: 0.2rem;
        }
        
        .data-value {
            font-weight: 600;
            margin-bottom: 1.2rem;
            white-space: pre-line; /* Para respetar saltos de línea de textareas */
        }
        
        /* Ajustes de Impresión (Reglas de Impresión SDM) */
        \@page {
            margin: 1.5cm;
        }
        \@media print {
            body { 
                background: white; 
                font-family: 'Inter', sans-serif;
                color: black;
            }
            .container {
                width: 100% !important;
                max-width: 100% !important;
                padding: 0 !important;
                margin: 0 !important;
            }
            .d-print-none { display: none !important; }
            .bento-card { 
                box-shadow: none !important; 
                border: 1px solid #ccc !important; 
                padding: 1rem !important; 
                border-radius: 0 !important; 
                page-break-inside: avoid;
            }
            .row { display: flex !important; flex-wrap: wrap !important; }
            .col-md-6, .col-lg-4, .col-lg-8, .col-lg-12, .col-12 { 
                flex: 0 0 auto;
            }
            .bento-title { border-bottom: 1px solid #000 !important; color: #000 !important; }
            .data-label { color: #555 !important; }
            .recipe-section { page-break-before: always; }
        }
    </style>
</head>
<body>

<div class="container py-5">
    <!-- Action Bar -->
    <div class="d-flex justify-content-between align-items-center mb-4 d-print-none">
        <a href="render_expediente_clinico.pl?id=$consulta->{id_paciente}" class="btn btn-outline-secondary rounded-pill fw-bold">
            <i class="bi bi-arrow-left me-2"></i>Volver al Expediente
        </a>
        <button onclick="window.print()" class="btn text-white rounded-pill px-4 fw-bold shadow-sm" style="background: var(--md-teal-clinical);">
            <i class="bi bi-printer-fill me-2"></i>Imprimir Nota M&eacute;dica
        </button>
    </div>

    <!-- Header Impresión -->
    <div class="d-none d-print-block text-center mb-5 border-bottom pb-4">
        <h2 class="fw-black" style="color: var(--md-navy);">M&Eacute;DICA DIAMOND CLINIC</h2>
        <h5 class="fw-bold text-muted">EXPEDIENTE CL&Iacute;NICO - NOTA DE EVOLUCI&Oacute;N</h5>
    </div>

    <div class="row g-4">
        <!-- 1. Ficha Identificación -->
        <div class="col-12">
            <div class="bento-card" style="background: linear-gradient(135deg, var(--md-navy) 0%, var(--md-blue-deep) 100%); color: white;">
                <div class="row">
                    <div class="col-md-6">
                        <div class="data-label text-white-50">Paciente</div>
                        <div class="data-value fs-4 mb-0">$paciente->{nombre}</div>
                        <div class="small text-white-50 mt-1">ID: $consulta->{id_paciente} | Sexo: $paciente->{sexo} | GS: $paciente->{ts}</div>
                    </div>
                    <div class="col-md-6 text-md-end mt-3 mt-md-0">
                        <div class="data-label text-white-50">M&eacute;dico Tratante</div>
                        <div class="data-value fs-5 mb-0" style="color: var(--md-teal-clinical);">$nombre_medico</div>
                        <div class="small text-white-50 mt-1">Fecha: $consulta->{fecha} | Folio: $consulta->{id_consulta}</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- 2. Registro y Anamnesis -->
        <div class="col-lg-4">
            <div class="bento-card">
                <div class="bento-title"><i class="bi bi-clock-history me-2"></i>Anamnesis</div>
                
                <div class="data-label">Motivo de Consulta</div>
                <div class="data-value">@{[ $d->{motivo} || 'No especificado' ]}</div>
                
                <div class="data-label">Evoluci&oacute;n y Padecimiento</div>
                <div class="data-value">@{[ $d->{evolucion} || 'Sin registro' ]}</div>
                
                <div class="data-label">Intensidad S&iacute;ntomas (1-10)</div>
                <div class="data-value">@{[ $d->{intensidad} || '--' ]}/10</div>
                
                <div class="data-label">Antecedentes Relevantes</div>
                <div class="data-value">@{[ $d->{antecedentes_patologicos} || 'Negados' ]}</div>
                
                <div class="data-label text-danger">Alergias</div>
                <div class="data-value text-danger">@{[ $d->{alergias} || $paciente->{alergias} || 'Negadas' ]}</div>
            </div>
        </div>

        <!-- 3. Exploración -->
        <div class="col-lg-4">
            <div class="bento-card">
                <div class="bento-title"><i class="bi bi-activity me-2"></i>Exploraci&oacute;n F&iacute;sica</div>
                
                <div class="row mb-3 bg-light p-2 rounded">
                    <div class="col-6">
                        <span class="data-label d-block">T.A.</span>
                        <span class="fw-bold">@{[ $d->{ta} || '--' ]}</span> mmHg
                    </div>
                    <div class="col-6">
                        <span class="data-label d-block">F.C.</span>
                        <span class="fw-bold">@{[ $d->{fc} || '--' ]}</span> lpm
                    </div>
                    <div class="col-6 mt-2">
                        <span class="data-label d-block">Peso / Talla</span>
                        <span class="fw-bold">@{[ $d->{peso} || '--' ]}kg / @{[ $d->{talla} || '--' ]}cm</span>
                    </div>
                    <div class="col-6 mt-2">
                        <span class="data-label d-block">Temp.</span>
                        <span class="fw-bold">@{[ $d->{temp} || '--' ]}</span> &deg;C
                    </div>
                </div>
                
                <div class="data-label">Hallazgos Cl&iacute;nicos</div>
                <div class="data-value">@{[ $d->{exploracion_hallazgos} || 'Sin registro' ]}</div>
            </div>
        </div>
        
        <!-- 4. SOAP & Diagnóstico -->
        <div class="col-lg-4">
            <div class="bento-card">
                <div class="bento-title"><i class="bi bi-diagram-3 me-2"></i>S.O.A.P.</div>
                
                <div class="data-label">Diagn&oacute;stico Principal</div>
                <div class="data-value fs-5" style="color: var(--md-navy);">@{[ $d->{diagnostico_principal} || 'Sin diagnóstico' ]}</div>
                
                <div class="data-label">Severidad</div>
                <div class="data-value">
                    <span class="badge bg-secondary">@{[ $d->{severidad} || 'No especificada' ]}</span>
                </div>
                
                <div class="data-label">Impresi&oacute;n Cl&iacute;nica (Assessment)</div>
                <div class="data-value">@{[ $d->{impresion_clinica} || 'Sin registro' ]}</div>
            </div>
        </div>

        <!-- 5. Plan y Acuerdos -->
        <div class="col-lg-12">
            <div class="bento-card">
                <div class="bento-title"><i class="bi bi-journal-medical me-2"></i>Plan de Tratamiento y Acuerdos</div>
                
                <div class="row">
                    <div class="col-md-7">
                        <div class="data-label">Abordaje y Plan</div>
                        <div class="data-value fs-6">@{[ $d->{plan_tratamiento} || 'Sin plan registrado' ]}</div>
                        
                        <div class="data-label mt-4">Estudios Solicitados / Analizados</div>
                        <div class="data-value small">
                            <strong>Labs:</strong> @{[ $d->{laboratorios_solicitados} || 'Ninguno' ]}<br>
                            <strong>Gabinete:</strong> @{[ $d->{gabinete_solicitados} || 'Ninguno' ]}<br>
                            <strong>Resultados Anteriores:</strong> @{[ $d->{resultados_estudios} || 'N/A' ]}
                        </div>
                    </div>
                    <div class="col-md-5 bg-light p-4 rounded">
                        <div class="data-label mb-3">Checklist Médico-Legal</div>
                        <ul class="list-unstyled mb-0">
                            <li class="mb-2"><i class="bi @{[ $d->{com_explicacion} ? 'bi-check-circle-fill text-success' : 'bi-dash-circle text-muted' ]} me-2"></i> Explicaci&oacute;n de diagn&oacute;stico brindada</li>
                            <li class="mb-2"><i class="bi @{[ $d->{com_riesgos} ? 'bi-check-circle-fill text-success' : 'bi-dash-circle text-muted' ]} me-2"></i> Riesgos informados</li>
                            <li class="mb-2"><i class="bi @{[ $d->{com_dudas} ? 'bi-check-circle-fill text-success' : 'bi-dash-circle text-muted' ]} me-2"></i> Dudas resueltas (Consentimiento oral)</li>
                        </ul>
                        
                        @{[ $d->{com_observaciones} ? "<div class='data-label mt-4'>Observaciones de Interacci&oacute;n</div><div class='data-value small'>$d->{com_observaciones}</div>" : "" ]}
                    </div>
                </div>
            </div>
        </div>
HTML

# 6. Receta (Si existe)
if ($d->{medicamentos} && ref($d->{medicamentos}) eq 'ARRAY' && scalar @{$d->{medicamentos}} > 0) {
    print <<HTML;
        <div class="col-12 recipe-section mt-5">
            <div class="bento-card border border-primary border-2">
                <div class="text-center mb-4">
                    <h3 class="fw-black" style="color: var(--md-navy);"><i class="bi bi-file-earmark-medical me-2"></i>RECETA M&Eacute;DICA</h3>
                </div>
                
                <table class="table table-borderless table-striped align-middle">
                    <thead class="table-dark">
                        <tr>
                            <th>F&aacute;rmaco / Presentaci&oacute;n</th>
                            <th>Dosis</th>
                            <th>Frecuencia</th>
                            <th>Duraci&oacute;n</th>
                            <th>V&iacute;a</th>
                        </tr>
                    </thead>
                    <tbody>
HTML
    foreach my $med (@{$d->{medicamentos}}) {
        my $f = $med->{farmaco} || '';
        my $p = $med->{presentacion} || '';
        my $do = $med->{dosis} || '';
        my $fr = $med->{frecuencia} || '';
        my $du = $med->{duracion} || '';
        my $vi = $med->{via} || '';
        print "<tr><td><span class='fw-bold'>$f</span><br><small class='text-muted'>$p</small></td><td>$do</td><td>$fr</td><td>$du</td><td>$vi</td></tr>\n";
    }
    
    print <<HTML;
                    </tbody>
                </table>
                <div class="mt-5 text-center pt-5 d-print-block">
                    <div style="border-top: 1px solid #000; width: 300px; margin: 0 auto; padding-top: 10px;">
                        <strong>$nombre_medico</strong><br>Firma y C&eacute;dula Profesional
                    </div>
                </div>
            </div>
        </div>
HTML
}

print <<HTML;
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
HTML
