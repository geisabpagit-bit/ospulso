#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON qw(decode_json);
use Encode qw(encode_utf8);
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
my $id_cita     = $q->param('id_cita') || '';

if (!$id_consulta && !$id_cita) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<div style='font-family:sans-serif; text-align:center; padding:50px;'><h2>No se especificó ninguna consulta o cita</h2><a href='inicial.pl'>Volver al Inicio</a></div>";
    exit;
}

# 1. Cargar la consulta
my $path_consultas = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
my $res_consultas = leer_tabla($path_consultas, '\|');
my $consulta = {};

foreach my $c (@$res_consultas) {
    my $match_consulta = ($id_consulta ne '' && $c->[0] eq $id_consulta);
    my $match_cita     = ($id_cita ne '' && $c->[2] eq $id_cita);
    if ($match_consulta || $match_cita) {
        my $json_str = $c->[5] || '{}';
        $json_str =~ s/\\n/\n/g;
        my $data = {};
        eval { $data = decode_json(encode_utf8($json_str)); };
        if (!%$data) { eval { $data = decode_json($json_str); }; }
        
        my $ts = $c->[4] || time();
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime($ts);
        my $fecha_formatted = sprintf("%04d-%02d-%02d %02d:%02d", $year+1900, $mon+1, $mday, $hour, $min);
        
        $consulta = {
            id_consulta => $c->[0],
            id_paciente => $c->[1],
            id_cita     => $c->[2],
            id_medico   => $c->[3],
            timestamp   => $ts,
            fecha       => $fecha_formatted,
            data        => $data
        };
        last;
    }
}

if (!keys %$consulta) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<div style='font-family:sans-serif; text-align:center; padding:50px;'><h2>Consulta Clínica No Encontrada</h2><p>No se localizó el expediente clínico para los parámetros especificados.</p><a href='inicial.pl'>Volver al Inicio</a></div>";
    exit;
}

# 2. Cargar Datos del Paciente
my $path_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $res_pacientes = leer_tabla($path_pacientes, '\|');
my $paciente = {};
foreach my $p (@$res_pacientes) {
    if ($p->[0] eq $consulta->{id_paciente}) {
        $paciente = {
            id => $p->[0],
            nombre => $p->[2],
            fecha_nac => $p->[3],
            telefono => $p->[4] || 'No registrado',
            curp => $p->[6] || '',
            sexo => $p->[7] || 'No especificado',
            ts => $p->[10] || 'O+',
            alergias => $p->[11] || 'Negadas'
        };
        last;
    }
}

# 3. Obtener Datos del Médico
my $path_med = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $res_med = leer_tabla($path_med, '!');
my $nombre_medico = $consulta->{id_medico};
my $especialidad_medico = 'Medicina General';
foreach my $m (@$res_med) {
    if ($m->[0] eq $consulta->{id_medico} || "DOC-" . sprintf("%03d", $m->[0]) eq $consulta->{id_medico}) {
        $nombre_medico = "Dr(a). " . $m->[1];
        $especialidad_medico = $m->[5] if ($m->[5] && $m->[5] ne '');
        last;
    }
}

my $d = $consulta->{data} || {};

# Medicamentos expedidos
my $medicamentos = $d->{medicamentos} || [];
if ((!$medicamentos || ref($medicamentos) ne 'ARRAY' || scalar @$medicamentos == 0) && $d->{medicamentos_json}) {
    eval { $medicamentos = decode_json(encode_utf8($d->{medicamentos_json})); };
}

# IMC Cálculo
my $peso_val = parseFloatVal($d->{peso});
my $talla_val = parseFloatVal($d->{talla});
my $imc_val = '--';
my $imc_status = '';
if ($peso_val > 0 && $talla_val > 0) {
    my $talla_m = $talla_val > 3 ? $talla_val / 100 : $talla_val;
    my $calc = $peso_val / ($talla_m * $talla_m);
    $imc_val = sprintf("%.1f", $calc);
    if ($calc < 18.5) { $imc_status = 'Bajo peso'; }
    elsif ($calc < 25.0) { $imc_status = 'Peso normal'; }
    elsif ($calc < 30.0) { $imc_status = 'Sobrepeso'; }
    else { $imc_status = 'Obesidad'; }
}

sub parseFloatVal {
    my ($val) = @_;
    return 0 unless defined $val;
    $val =~ s/[^0-9.]//g;
    return $val + 0;
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Detalle de Consulta M&eacute;dica - $consulta->{id_consulta}</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="16x16" href="../favicon/favicon-16x16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="64x64" href="../favicon/favicon-64x64.png">
    <link rel="icon" type="image/png" sizes="128x128" href="../favicon/favicon-128x128.png">
    <link rel="icon" type="image/x-icon" href="../favicon/favicon.ico">
    <link rel="apple-touch-icon" sizes="180x180" href="../favicon/apple-touch-icon.png">
    <link rel="manifest" href="../favicon/site.webmanifest">
    <!-- Core MedentIA Diamond Armor Styles -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.10.5/font/bootstrap-icons.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap" rel="stylesheet">
    
    <style>
        :root {
            --md-teal-clinical: #19B7A5;
            --md-blue-deep: #0A2A66;
            --md-navy: #051A44;
            --md-gray-bg: #F8FAFC;
            --md-cyan-ia: #00C4C4;
        }
        body {
            font-family: 'Inter', sans-serif;
            background: var(--md-gray-bg);
            color: var(--md-blue-deep);
        }
        
        .bento-card {
            background: #ffffff;
            border-radius: 1.25rem;
            padding: 1.75rem;
            box-shadow: 0 10px 30px rgba(10, 42, 102, 0.04);
            border: 1px solid rgba(25, 183, 165, 0.25);
            height: 100%;
            transition: all 0.2s ease;
        }
        .bento-card:hover {
            border-color: var(--md-teal-clinical);
            box-shadow: 0 12px 36px rgba(10, 42, 102, 0.08);
        }
        
        .bento-header {
            font-size: 1.05rem;
            font-weight: 800;
            color: var(--md-blue-deep);
            margin-bottom: 1.25rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 2px solid var(--md-gray-bg);
            padding-bottom: 0.75rem;
        }

        .bento-title-text {
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .data-label {
            font-size: 0.72rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #64748b;
            margin-bottom: 0.25rem;
        }
        
        .data-value {
            font-size: 0.95rem;
            font-weight: 600;
            color: var(--md-navy);
            margin-bottom: 1.1rem;
            white-space: pre-line;
        }
        
        .vital-box {
            background: #f1f5f9;
            border-radius: 1rem;
            padding: 1rem;
            text-align: center;
            border: 1px solid #e2e8f0;
        }
        .vital-value {
            font-size: 1.3rem;
            font-weight: 800;
            color: var(--md-blue-deep);
        }
        .vital-unit {
            font-size: 0.7rem;
            color: #64748b;
            font-weight: 600;
        }
        
        .pain-bar-bg {
            height: 10px;
            background: #e2e8f0;
            border-radius: 5px;
            overflow: hidden;
        }
        .pain-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, #10b981 0%, #f59e0b 50%, #ef4444 100%);
            border-radius: 5px;
        }

        /* Estilos de Impresión */
        \@media print {
            body { background: white !important; color: black !important; font-size: 12pt; }
            .d-print-none { display: none !important; }
            .bento-card { box-shadow: none !important; border: 1px solid #cbd5e1 !important; padding: 1rem !important; border-radius: 0.5rem !important; page-break-inside: avoid; }
            .container { max-width: 100% !important; width: 100% !important; padding: 0 !important; }
            .recipe-print-page { page-break-before: always; }
        }
    </style>
</head>
<body>

<div class="container py-4">
    <!-- Bar de Acciones Superior -->
    <div class="d-flex justify-content-between align-items-center mb-4 d-print-none flex-wrap gap-2">
        <div>
            <a href="render_expediente_clinico.pl?id=$paciente->{id}" class="btn btn-outline-secondary rounded-pill fw-bold btn-sm px-3">
                <i class="bi bi-arrow-left me-1"></i> Expediente
            </a>
            <a href="inicial.pl" class="btn btn-light rounded-pill fw-bold btn-sm px-3 ms-1 border">
                <i class="bi bi-house me-1"></i> Dashboard
            </a>
        </div>
        <div class="d-flex gap-2">
            @{[ scalar(@$medicamentos) > 0 ? "<button onclick='window.print()' class='btn btn-outline-primary rounded-pill btn-sm fw-bold px-3'><i class='bi bi-file-earmark-medical me-1'></i>Imprimir Receta</button>" : "" ]}
            <button onclick="window.print()" class="btn text-white rounded-pill btn-sm px-4 fw-bold shadow-sm" style="background: linear-gradient(135deg, var(--md-blue-deep), var(--md-teal-clinical));">
                <i class="bi bi-printer-fill me-1"></i> Imprimir Nota M&eacute;dica
            </button>
        </div>
    </div>

    <!-- Header Impresión -->
    <div class="d-none d-print-block text-center mb-4 border-bottom pb-3">
        <h3 class="fw-black mb-1" style="color: var(--md-navy);">MEDENTIA CLINIC - NOTA CL&Iacute;NICA DE EVOLUCI&Oacute;N</h3>
        <p class="small text-muted mb-0">Folio de Consulta: $consulta->{id_consulta} | Cita: $consulta->{id_cita}</p>
    </div>

    <!-- Banner Principal: Datos de Paciente y Atención -->
    <div class="card border-0 shadow-sm rounded-4 mb-4" style="background: linear-gradient(135deg, var(--md-navy) 0%, var(--md-blue-deep) 100%); color: white;">
        <div class="card-body p-4">
            <div class="row align-items-center">
                <div class="col-md-7">
                    <span class="badge bg-white-10 text-white border border-white-20 rounded-pill px-3 py-1 mb-2 small fw-bold" style="background: rgba(255,255,255,0.15);">
                        <i class="bi bi-person-badge me-1"></i> PACIENTE
                    </span>
                    <h3 class="fw-black text-white mb-1">$paciente->{nombre}</h3>
                    <p class="text-white-50 small mb-0">
                        <span class="me-3"><i class="bi bi-gender-ambiguous me-1"></i>$paciente->{sexo}</span>
                        <span class="me-3"><i class="bi bi-droplet-fill me-1 text-danger"></i>GS: $paciente->{ts}</span>
                        <span><i class="bi bi-telephone me-1"></i>$paciente->{telefono}</span>
                    </p>
                    @{[ $paciente->{alergias} ne 'Negadas' ? "<div class='mt-2'><span class='badge bg-danger text-white rounded-pill px-3'><i class='bi bi-exclamation-triangle-fill me-1'></i>Alergias: $paciente->{alergias}</span></div>" : "" ]}
                </div>
                <div class="col-md-5 text-md-end mt-3 mt-md-0 border-start-md border-white-10 ps-md-4">
                    <div class="small text-white-50 fw-bold text-uppercase">M&eacute;dico Tratante</div>
                    <h5 class="fw-bold mb-1" style="color: var(--md-cyan-ia);">$nombre_medico</h5>
                    <div class="small text-white-50">$especialidad_medico</div>
                    <div class="mt-2 pt-2 border-top border-white-10 small text-white-50">
                        <i class="bi bi-calendar3 me-1"></i>Fecha: $consulta->{fecha}
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Signos Vitales Bento Grid -->
    <div class="row g-3 mb-4">
        <div class="col-6 col-sm-4 col-md-2">
            <div class="vital-box">
                <div class="data-label"><i class="bi bi-heart-pulse me-1 text-danger"></i> T.A.</div>
                <div class="vital-value">@{[ $d->{ta} || '--' ]}</div>
                <div class="vital-unit">mmHg</div>
            </div>
        </div>
        <div class="col-6 col-sm-4 col-md-2">
            <div class="vital-box">
                <div class="data-label"><i class="bi bi-activity me-1 text-primary"></i> F.C.</div>
                <div class="vital-value">@{[ $d->{fc} || '--' ]}</div>
                <div class="vital-unit">bpm</div>
            </div>
        </div>
        <div class="col-6 col-sm-4 col-md-2">
            <div class="vital-box">
                <div class="data-label"><i class="bi bi-wind me-1 text-info"></i> F.R.</div>
                <div class="vital-value">@{[ $d->{fr} || '--' ]}</div>
                <div class="vital-unit">rpm</div>
            </div>
        </div>
        <div class="col-6 col-sm-4 col-md-2">
            <div class="vital-box">
                <div class="data-label"><i class="bi bi-thermometer-half me-1 text-warning"></i> Temp</div>
                <div class="vital-value">@{[ $d->{temp} || '--' ]}</div>
                <div class="vital-unit">&deg;C</div>
            </div>
        </div>
        <div class="col-6 col-sm-4 col-md-2">
            <div class="vital-box">
                <div class="data-label"><i class="bi bi-speedometer2 me-1 text-success"></i> SpO2</div>
                <div class="vital-value">@{[ $d->{spo2} || '--' ]}</div>
                <div class="vital-unit">%</div>
            </div>
        </div>
        <div class="col-6 col-sm-4 col-md-2">
            <div class="vital-box">
                <div class="data-label"><i class="bi bi-person-bounding-box me-1 text-secondary"></i> IMC</div>
                <div class="vital-value">$imc_val</div>
                <div class="vital-unit">$imc_status</div>
            </div>
        </div>
    </div>

    <!-- Grid de Secciones Clínicas -->
    <div class="row g-4 mb-4">
        <!-- 1. Anamnesis y Padecimiento -->
        <div class="col-lg-6">
            <div class="bento-card">
                <div class="bento-header">
                    <div class="bento-title-text"><i class="bi bi-chat-left-text text-primary"></i> Anamnesis y Padecimiento Actual</div>
                    <span class="badge bg-light text-secondary border">Paso 2</span>
                </div>
                
                <div class="data-label">Motivo de Consulta</div>
                <div class="data-value fs-6 fw-bold" style="color: var(--md-navy);">@{[ $d->{motivo} || $d->{motivo_consulta} || 'Sin registro' ]}</div>
                
                <div class="data-label">Evoluci&oacute;n y Padecimiento Actual</div>
                <div class="data-value">@{[ $d->{evolucion} || $d->{padecimiento_actual} || 'Sin registro de evolución' ]}</div>
                
                @{[ ($d->{intensidad} || $d->{intensidad_sintomas}) ? "
                <div class='data-label'>Intensidad de S&iacute;ntomas (" . ($d->{intensidad} || $d->{intensidad_sintomas}) . "/10)</div>
                <div class='mb-3'>
                    <div class='pain-bar-bg'><div class='pain-bar-fill' style='width: " . (($d->{intensidad} || $d->{intensidad_sintomas}) * 10) . "%;'></div></div>
                </div>
                " : "" ]}
                
                <div class="data-label">Antecedentes Relevantes</div>
                <div class="data-value small text-muted">
                    <strong>Patol&oacute;gicos:</strong> @{[ $d->{antecedentes_patologicos} || 'Negados' ]}<br>
                    <strong>No Patol&oacute;gicos:</strong> @{[ $d->{antecedentes_no_patologicos} || 'Negados' ]}<br>
                    <strong>Quir&uacute;rgicos:</strong> @{[ $d->{antecedentes_quirurgicos} || 'Negados' ]}
                </div>
            </div>
        </div>

        <!-- 2. Exploración Física -->
        <div class="col-lg-6">
            <div class="bento-card">
                <div class="bento-header">
                    <div class="bento-title-text"><i class="bi bi-body-text text-success"></i> Exploraci&oacute;n F&iacute;sica</div>
                    <span class="badge bg-light text-secondary border">Paso 3</span>
                </div>
                
                <div class="data-label">Hallazgos Cl&iacute;nicos por Regi&oacute;n</div>
                <div class="data-value" style="min-height: 120px;">@{[ $d->{exploracion_hallazgos} || $d->{hallazgos_exploracion} || 'Sin hallazgos patológicos registrados.' ]}</div>
                
                <div class="data-label">Estudios Solicitados / Analizados</div>
                <div class="data-value small">
                    <strong>Laboratorios:</strong> @{[ $d->{laboratorios_solicitados} || 'Ninguno' ]}<br>
                    <strong>Gabinete:</strong> @{[ $d->{gabinete_solicitados} || 'Ninguno' ]}<br>
                    <strong>Resultados Anteriores:</strong> @{[ $d->{resultados_estudios} || 'N/A' ]}
                </div>
            </div>
        </div>

        <!-- 3. Metodología S.O.A.P. & Diagnóstico -->
        <div class="col-lg-12">
            <div class="bento-card">
                <div class="bento-header">
                    <div class="bento-title-text"><i class="bi bi-diagram-3-fill text-info"></i> Diagn&oacute;stico y Metodolog&iacute;a S.O.A.P.</div>
                    <span class="badge bg-primary text-white border-0">Paso 5</span>
                </div>
                
                <div class="row g-4">
                    <div class="col-md-6 border-end-md">
                        <div class="data-label text-primary">Diagn&oacute;stico Principal (CIE-10)</div>
                        <div class="data-value fs-5 fw-black text-navy mb-2">
                            @{[ $d->{diagnostico_principal} || 'Sin diagnóstico principal' ]}
                            @{[ $d->{clave_diagnostico_cie10} ? "<span class='badge bg-primary-subtle text-primary border border-primary-subtle rounded-pill ms-2 small'>" . $d->{clave_diagnostico_cie10} . "</span>" : "" ]}
                        </div>
                        
                        @{[ $d->{diagnosticos_secundarios} ? "<div class='data-label'>Diagn&oacute;sticos Secundarios</div><div class='data-value small'>" . $d->{diagnosticos_secundarios} . "</div>" : "" ]}
                        
                        <div class="d-flex gap-3 mt-3">
                            <div>
                                <span class="data-label d-block">Severidad</span>
                                <span class="badge bg-warning-subtle text-warning-emphasis fw-bold border">@{[ $d->{severidad} || 'Moderada' ]}</span>
                            </div>
                            <div>
                                <span class="data-label d-block">Pron&oacute;stico</span>
                                <span class="badge bg-success-subtle text-success-emphasis fw-bold border">@{[ $d->{pronostico} || 'Favorable' ]}</span>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <div class="data-label">Plan de Tratamiento (P)</div>
                        <div class="data-value">@{[ $d->{plan_tratamiento} || $d->{plan} || 'Sin plan especificado' ]}</div>
                        
                        <div class="data-label">Evaluaci&oacute;n y An&aacute;lisis (A)</div>
                        <div class="data-value small text-muted">@{[ $d->{impresion_clinica} || $d->{assessment} || 'Sin notas de análisis adicionales' ]}</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- 4. Receta Médica (si aplica) -->
        @{[ scalar(@$medicamentos) > 0 ? "
        <div class='col-lg-12 recipe-print-page'>
            <div class='bento-card border-primary border-2'>
                <div class='bento-header'>
                    <div class='bento-title-text text-primary'><i class='bi bi-capsule me-2'></i> Receta M&eacute;dica Expedida</div>
                    <span class='badge bg-success text-white border-0'>F&aacute;rmacos</span>
                </div>
                
                <div class='table-responsive mb-3'>
                    <table class='table table-hover align-middle'>
                        <thead class='table-light small text-uppercase fw-bold'>
                            <tr>
                                <th>F&aacute;rmaco / Presentaci&oacute;n</th>
                                <th>Dosis</th>
                                <th>Frecuencia</th>
                                <th>Duraci&oacute;n</th>
                                <th>V&iacute;a</th>
                            </tr>
                        </thead>
                        <tbody>
                            " . join("", map { "<tr><td><strong class='text-navy'>" . ($_->{farmaco}||'') . "</strong><br><small class='text-muted'>" . ($_->{presentacion}||'') . "</small></td><td>" . ($_->{dosis}||'') . "</td><td>" . ($_->{frecuencia}||'') . "</td><td>" . ($_->{duracion}||'') . "</td><td><span class='badge bg-light text-dark border'>" . ($_->{via}||'Oral') . "</span></td></tr>" } @$medicamentos) . "
                        </tbody>
                    </table>
                </div>
                
                " . ($d->{receta_indicaciones} ? "<div class='p-3 bg-light rounded-3 border small'><strong>Indicaciones Especiales:</strong> " . $d->{receta_indicaciones} . "</div>" : "") . "
            </div>
        </div>
        " : "" ]}

        <!-- 5. Firmas y Conformidad -->
        <div class="col-lg-12">
            <div class="bento-card">
                <div class="bento-header">
                    <div class="bento-title-text"><i class="bi bi-shield-check text-success"></i> Conformidad y Firmas Digitales</div>
                    <span class="badge bg-light text-secondary border">Validaci&oacute;n</span>
                </div>
                
                <div class="row align-items-center text-center">
                    <div class="col-md-6 border-end-md py-3">
                        <div class="data-label mb-2">Firma del M&eacute;dico Tratante</div>
                        @{[ ($d->{firma_medico_data} && -e File::Spec->catfile($FindBin::Bin, '..', $d->{firma_medico_data})) ? "<img src='../" . $d->{firma_medico_data} . "' style='max-height:80px;' class='img-fluid mb-2'>" : "<div class='p-3 bg-light rounded text-muted small mb-2'>Firma Digital Registrada en Sistema</div>" ]}
                        <div class="fw-bold small text-navy">$nombre_medico</div>
                        <div class="small text-muted">$especialidad_medico</div>
                    </div>
                    
                    <div class="col-md-6 py-3">
                        <div class="data-label mb-2">Firma del Paciente / Tutor</div>
                        @{[ ($d->{firma_paciente_data} && -e File::Spec->catfile($FindBin::Bin, '..', $d->{firma_paciente_data})) ? "<img src='../" . $d->{firma_paciente_data} . "' style='max-height:80px;' class='img-fluid mb-2'>" : "<div class='p-3 bg-light rounded text-muted small mb-2'>Consentimiento Informado Aceptado</div>" ]}
                        <div class="fw-bold small text-navy">$paciente->{nombre}</div>
                        <div class="small text-muted">Conformidad con Atención y Tratamiento</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
HTML

1;
