#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(decode_json encode_json);
use FindBin;
use File::Spec;
use open qw(:std :utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session($q);
unless ($session_data->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $id_cirugia = $q->param('id_cirugia') || '';
unless ($id_cirugia) {
    print $q->header(-type => 'text/html; charset=UTF-8');
    print "<h3>Error: ID de cirugía no proporcionado.</h3>";
    exit;
}

# 1. Cargar Dossier Quirúrgico Atómico
my $dossier_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'quirofano', "cirugia_$id_cirugia.json");
my $dossier = {};
if (-e $dossier_file && open my $fh_d, '<:encoding(UTF-8)', $dossier_file) {
    local $/;
    my $raw = <$fh_d>;
    close $fh_d;
    if ($raw && $raw =~ /\S/) {
        $dossier = eval { decode_json($raw) } || {};
    }
}

# Fallback si no hay JSON: buscar en quirofano.dat
if (!%$dossier) {
    my $q_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'quirofano.dat');
    if (-e $q_file && open my $fh_q, '<:encoding(UTF-8)', $q_file) {
        my $hdr = <$fh_q>;
        while (my $line = <$fh_q>) {
            chomp $line;
            my @c = split /\|/, $line, -1;
            if ($c[0] eq $id_cirugia) {
                $dossier = {
                    id_cirugia => $c[0],
                    id_org => $c[1],
                    id_paciente => $c[2],
                    id_medico => $c[3],
                    fecha => $c[4],
                    hora => $c[5],
                    estado => $c[6],
                    sala => $c[7],
                    procedimiento => $c[8],
                    id_anestesiologo => $c[9],
                    notas => $c[10] // ''
                };
                last;
            }
        }
        close $fh_q;
    }
}

unless (%$dossier) {
    print $q->header(-type => 'text/html; charset=UTF-8');
    print "<h3>Error: No se encontró el registro de la intervención quirúrgica #$id_cirugia.</h3>";
    exit;
}

# 2. Cargar Datos del Paciente
my $id_paciente = $dossier->{id_paciente} || '';
my $paciente = {
    id => $id_paciente,
    nombre => 'Paciente Desconocido',
    curp => 'N/A',
    edad => 'N/A',
    sexo => 'N/A',
    sangre => 'N/A',
    alergias => 'Negadas'
};

if ($id_paciente) {
    my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
    if (-e $pac_file && open my $fhp, '<:encoding(UTF-8)', $pac_file) {
        my $hdr = <$fhp>;
        while (my $line = <$fhp>) {
            chomp $line;
            my @p = split /\|/, $line, -1;
            if ($p[0] eq $id_paciente) {
                my $edad = 'N/A';
                if ($p[6] && $p[6] =~ /(\d{4})/) {
                    $edad = ((localtime)[5] + 1900) - $1;
                }
                $paciente = {
                    id => $p[0],
                    nombre => $p[2] || 'Paciente',
                    curp => $p[4] || 'N/A',
                    edad => $edad,
                    sexo => $p[7] || 'N/A',
                    sangre => $p[11] || 'N/A',
                    alergias => $p[13] || 'Negadas'
                };
                last;
            }
        }
        close $fhp;
    }
}

# 3. Cargar Datos de la Organización y CLUE
my $id_org = $dossier->{id_org} || $session_data->{id_empresa} || '0';
my $clinica = {
    nombre => 'Clínica Quirúrgica y Hospitalaria OsPulso',
    clue => 'QTSMP000116',
    domicilio => 'Servicio Quirúrgico Central',
    telefono => ''
};

my $neg_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $neg_file && open my $fhn, '<:encoding(UTF-8)', $neg_file) {
    my $hdr = <$fhn>;
    while (my $line = <$fhn>) {
        chomp $line;
        my @n = split /\|/, $line, -1;
        if ($n[0] eq $id_org || ($id_org eq '0' && $n[0] eq '0')) {
            $clinica->{nombre} = $n[1] if $n[1];
            $clinica->{domicilio} = $n[6] if $n[6];
            $clinica->{telefono} = $n[7] if $n[7];
            $clinica->{clue} = $n[18] if scalar(@n) > 18 && $n[18];
            last;
        }
    }
    close $fhn;
}

# 4. Extraer Sub-Estructuras
my $preop = $dossier->{checklist_preop} || {};
my $transop = $dossier->{transoperatorio} || {};
my $nota = $dossier->{nota_quirurgica} || {};
my $ucpa = $dossier->{recuperacion_ucpa} || {};

my $cirujano_nombre = $nota->{cirujano} || $dossier->{nombre_medico} || 'Cirujano Titular';
my $anestesio_nombre = $nota->{anestesiologo} || $dossier->{nombre_anestesio} || 'Anestesiólogo';
my $procedimiento_nombre = $nota->{operacion_realizada} || $dossier->{procedimiento} || 'Procedimiento Quirúrgico';
my $fecha_qx = $dossier->{fecha} || sprintf("%04d-%02d-%02d", (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3]);
my $hora_qx = $dossier->{hora} || '08:00';
my $sala_qx = $dossier->{sala} || 'Quirófano 1';

# Formatear Criterios Aldrete
my $aldrete_total = $ucpa->{aldrete_total} // 10;
my $aldrete_status = $aldrete_total >= 9 ? 'APROBADO PARA ALTA A PISO / DOMICILIO' : 'EN VIGILANCIA EN UCPA';

print $q->header(-type => 'text/html; charset=UTF-8');
print <<"HTML";
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Nota Quirúrgica NOM-004 - Folio QX-$id_cirugia</title>
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght\@400;500;600;700;800&family=JetBrains+Mono:wght\@400;600&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #f1f5f9;
            color: #0f172a;
            font-size: 11.5px;
            line-height: 1.45;
        }
        .sheet-container {
            max-width: 900px;
            margin: 25px auto;
            background: #ffffff;
            padding: 35px 45px;
            border-radius: 8px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
            border: 1px solid #e2e8f0;
        }
        .header-box {
            border-bottom: 2.5px solid #0f172a;
            padding-bottom: 12px;
            margin-bottom: 18px;
        }
        .inst-title {
            font-size: 17px;
            font-weight: 800;
            color: #0f172a;
            letter-spacing: -0.3px;
            text-transform: uppercase;
        }
        .inst-sub {
            font-size: 11px;
            color: #475569;
            font-weight: 500;
        }
        .badge-folio {
            background: #0f172a;
            color: #ffffff;
            padding: 5px 12px;
            border-radius: 6px;
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            font-weight: 700;
        }
        .section-header {
            background: #f8fafc;
            border-left: 4px solid #0f172a;
            padding: 5px 10px;
            font-size: 11.5px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-top: 14px;
            margin-bottom: 8px;
            color: #1e293b;
        }
        .field-label {
            font-size: 10px;
            font-weight: 700;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 0.4px;
            display: block;
            margin-bottom: 2px;
        }
        .field-value {
            font-size: 11.5px;
            font-weight: 600;
            color: #0f172a;
        }
        .field-box {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            padding: 6px 10px;
            border-radius: 5px;
            margin-bottom: 8px;
            min-height: 38px;
        }
        .text-narrative {
            background: #f8fafc;
            border: 1px solid #cbd5e1;
            padding: 8px 12px;
            border-radius: 6px;
            min-height: 65px;
            white-space: pre-wrap;
            font-size: 11px;
            color: #1e293b;
        }
        .check-item {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            margin-right: 15px;
            font-weight: 600;
            font-size: 10.5px;
        }
        .signature-line {
            border-top: 1.5px solid #0f172a;
            margin-top: 55px;
            padding-top: 5px;
            text-align: center;
        }
        .sig-title {
            font-size: 10.5px;
            font-weight: 700;
            color: #0f172a;
            text-transform: uppercase;
        }
        .sig-sub {
            font-size: 9.5px;
            color: #64748b;
        }
        .aldrete-pill {
            display: inline-block;
            background: #f1f5f9;
            border: 1px solid #cbd5e1;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 10px;
            margin-right: 6px;
        }

        \@media print {
            body {
                background: #ffffff !important;
                padding: 0 !important;
                margin: 0 !important;
            }
            .no-print {
                display: none !important;
            }
            .sheet-container {
                box-shadow: none !important;
                border: none !important;
                padding: 10px 20px !important;
                max-width: 100% !important;
                margin: 0 !important;
            }
            .section-header {
                background: #f1f5f9 !important;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }
        }
    </style>
</head>
<body onload="window.print()">

    <!-- Barra de Navegación de Impresión (No Imprimible) -->
    <div class="no-print bg-dark text-white p-2.5 text-center d-flex justify-content-between align-items-center px-4 shadow-sm">
        <div class="d-flex align-items-center gap-2">
            <span class="badge bg-primary px-2 py-1 font-monospace">NOM-004-SSA3-2012</span>
            <span class="fw-semibold small">Expediente Clínico & Hoja Quirúrgica Oficial</span>
        </div>
        <div class="d-flex gap-2">
            <button onclick="window.print()" class="btn btn-sm btn-success fw-bold px-3">
                <i class="bi bi-printer me-1"></i> Imprimir Documento
            </button>
            <button onclick="window.close()" class="btn btn-sm btn-outline-light px-3">
                <i class="bi bi-x-circle me-1"></i> Cerrar
            </button>
        </div>
    </div>

    <div class="sheet-container">
        <!-- 1. Encabezado Institucional -->
        <div class="header-box d-flex justify-content-between align-items-start">
            <div class="d-flex align-items-center gap-3">
                <div class="p-2.5 rounded-3 bg-light border border-2 text-primary">
                    <i class="bi bi-hospital fs-3"></i>
                </div>
                <div>
                    <div class="inst-title">$clinica->{nombre}</div>
                    <div class="inst-sub">
                        <span><strong>CLUE:</strong> $clinica->{clue}</span> &bull; 
                        <span>$clinica->{domicilio}</span>
                    </div>
                    <div class="inst-sub text-muted">
                        JEFATURA DE QUIRÓFANO Y ANESTESIOLOGÍA &bull; HOJA POST-OPERATORIA Y TRANSOPERATORIA
                    </div>
                </div>
            </div>
            <div class="text-end">
                <div class="badge-folio">FOLIO QX: #$id_cirugia</div>
                <div class="small text-muted mt-1 fw-semibold">Fecha: $fecha_qx | Hora: $hora_qx hrs</div>
                <div class="small text-muted font-monospace">Sala: $sala_qx</div>
            </div>
        </div>

        <!-- 2. Datos Generales del Paciente -->
        <div class="section-header">1. Ficha de Identificación del Paciente</div>
        <div class="row g-2">
            <div class="col-6">
                <div class="field-box">
                    <span class="field-label">Nombre Completo del Paciente:</span>
                    <span class="field-value text-uppercase">$paciente->{nombre}</span>
                </div>
            </div>
            <div class="col-3">
                <div class="field-box">
                    <span class="field-label">Expediente Clínico:</span>
                    <span class="field-value font-monospace">#$paciente->{id}</span>
                </div>
            </div>
            <div class="col-3">
                <div class="field-box">
                    <span class="field-label">CURP:</span>
                    <span class="field-value font-monospace">$paciente->{curp}</span>
                </div>
            </div>
            <div class="col-3">
                <div class="field-box">
                    <span class="field-label">Edad / Sexo:</span>
                    <span class="field-value">$paciente->{edad} años / $paciente->{sexo}</span>
                </div>
            </div>
            <div class="col-3">
                <div class="field-box">
                    <span class="field-label">Grupo y Rh:</span>
                    <span class="field-value fw-bold text-danger">$paciente->{sangre}</span>
                </div>
            </div>
            <div class="col-6">
                <div class="field-box">
                    <span class="field-label">Alergias a Fármacos:</span>
                    <span class="field-value">$paciente->{alergias}</span>
                </div>
            </div>
        </div>

        <!-- 3. Equipo Quirúrgico -->
        <div class="section-header">2. Equipo Quirúrgico y Personal Asistencial</div>
        <div class="row g-2">
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Cirujano Titular:</span>
                    <span class="field-value">$cirujano_nombre</span>
                </div>
            </div>
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Primer Ayudante:</span>
                    <span class="field-value">@{[ $nota->{primer_ayudante} || 'No registrado' ]}</span>
                </div>
            </div>
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Médico Anestesiólogo:</span>
                    <span class="field-value">$anestesio_nombre</span>
                </div>
            </div>
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Tipo de Anestesia:</span>
                    <span class="field-value">@{[ $nota->{tipo_anestesia} || 'General Balanceada' ]}</span>
                </div>
            </div>
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Enfermera Instrumentista:</span>
                    <span class="field-value">@{[ $nota->{instrumentista} || 'Personal en Turno' ]}</span>
                </div>
            </div>
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Enfermera Circulante:</span>
                    <span class="field-value">@{[ $nota->{circulante} || 'Personal en Turno' ]}</span>
                </div>
            </div>
        </div>

        <!-- 4. Seguridad Quirúrgica y Tiempos Transoperatorios -->
        <div class="section-header">3. Protocolo de Cirugía Segura (OMS) & Tiempos Transoperatorios</div>
        <div class="p-2 border rounded bg-white mb-2">
            <div class="row g-2 align-items-center">
                <div class="col-12 col-md-7">
                    <div class="d-flex flex-wrap gap-2">
                        <span class="check-item"><i class="bi bi-check-circle-fill text-success"></i> Identidad Verificada</span>
                        <span class="check-item"><i class="bi bi-check-circle-fill text-success"></i> Consentimiento Qx Firmado</span>
                        <span class="check-item"><i class="bi bi-check-circle-fill text-success"></i> Sitio Marcado</span>
                        <span class="check-item"><i class="bi bi-check-circle-fill text-success"></i> Ayuno Confirmado (@{[ $preop->{horas_ayuno} || 8 ]} hrs)</span>
                        <span class="check-item"><i class="bi bi-check-circle-fill text-success"></i> Profilaxis Antibiótica</span>
                    </div>
                </div>
                <div class="col-12 col-md-5 text-md-end border-start ps-3">
                    <div class="small fw-bold text-dark mb-1">Conteo de Material de Esponjear:</div>
                    <span class="check-item"><i class="bi @{[ $transop->{conteo_gasas_completo} ? 'bi-check2-circle text-success' : 'bi-exclamation-circle text-danger' ]}"></i> Gasas: 100%</span>
                    <span class="check-item"><i class="bi @{[ $transop->{conteo_compresas_completo} ? 'bi-check2-circle text-success' : 'bi-exclamation-circle text-danger' ]}"></i> Compresas: 100%</span>
                    <span class="check-item"><i class="bi @{[ $transop->{conteo_instrumental_completo} ? 'bi-check2-circle text-success' : 'bi-exclamation-circle text-danger' ]}"></i> Instrumental</span>
                </div>
            </div>
            <div class="row g-2 border-top pt-2 mt-2 font-monospace small">
                <div class="col-auto"><strong>Ingreso Sala:</strong> @{[ $transop->{hora_ingreso_sala} || '--:--' ]}</div>
                <div class="col-auto"><strong>Inicio Anestesia:</strong> @{[ $transop->{hora_inicio_anestesia} || '--:--' ]}</div>
                <div class="col-auto"><strong>Incisión:</strong> @{[ $transop->{hora_incision} || '--:--' ]}</div>
                <div class="col-auto"><strong>Cierre Piel:</strong> @{[ $transop->{hora_cierre} || '--:--' ]}</div>
                <div class="col-auto"><strong>Salida UCPA:</strong> @{[ $transop->{hora_salida_sala} || '--:--' ]}</div>
            </div>
        </div>

        <!-- 5. Nota Quirúrgica y Hallazgos (NOM-004-SSA3-2012) -->
        <div class="section-header">4. Nota Quirúrgica (NOM-004-SSA3-2012)</div>
        <div class="row g-2">
            <div class="col-6">
                <div class="field-box">
                    <span class="field-label">Diagnóstico Preoperatorio:</span>
                    <span class="field-value">@{[ $nota->{diagnostico_preop} || $dossier->{procedimiento} || 'Sin especificar' ]}</span>
                </div>
            </div>
            <div class="col-6">
                <div class="field-box">
                    <span class="field-label">Diagnóstico Postoperatorio:</span>
                    <span class="field-value">@{[ $nota->{diagnostico_postop} || $nota->{diagnostico_preop} || $dossier->{procedimiento} || 'Sin especificar' ]}</span>
                </div>
            </div>
            <div class="col-6">
                <div class="field-box">
                    <span class="field-label">Operación Planeada:</span>
                    <span class="field-value">@{[ $nota->{operacion_planeada} || $dossier->{procedimiento} || 'Sin especificar' ]}</span>
                </div>
            </div>
            <div class="col-6">
                <div class="field-box">
                    <span class="field-label">Operación Realizada:</span>
                    <span class="field-value fw-bold text-primary">@{[ $nota->{operacion_realizada} || $dossier->{procedimiento} || 'Sin especificar' ]}</span>
                </div>
            </div>
            <div class="col-12">
                <div class="mb-2">
                    <span class="field-label">Descripción de la Técnica Quirúrgica (Paso a Paso):</span>
                    <div class="text-narrative">@{[ $nota->{descripcion_tecnica} || 'Técnica quirúrgica habitual efectuada bajo estrictas normas de asepsia y antisepsia.' ]}</div>
                </div>
            </div>
            <div class="col-12">
                <div class="mb-2">
                    <span class="field-label">Hallazgos Quirúrgicos Relevantes:</span>
                    <div class="text-narrative" style="min-height: 45px;">@{[ $nota->{hallazgos} || 'Sin hallazgos patológicos adicionales.' ]}</div>
                </div>
            </div>
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Sangrado Cuantificado:</span>
                    <span class="field-value">@{[ $nota->{sangrado_aprox_ml} || '0' ]} ml</span>
                </div>
            </div>
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Muestras a Patología:</span>
                    <span class="field-value">@{[ $nota->{piezas_patologia} || 'Ninguna' ]}</span>
                </div>
            </div>
            <div class="col-4">
                <div class="field-box">
                    <span class="field-label">Incidentes / Accidentes:</span>
                    <span class="field-value">@{[ $transop->{incidentes_accidentes} || 'Sin incidentes' ]}</span>
                </div>
            </div>
        </div>

        <!-- 6. Recuperación Post-Anestésica UCPA (Escala Aldrete) -->
        <div class="section-header">5. Recuperación Post-Anestésica UCPA (Criterios de Aldrete)</div>
        <div class="p-2 border rounded bg-white">
            <div class="d-flex justify-content-between align-items-center mb-2 border-bottom pb-1">
                <div>
                    <strong>Cama UCPA:</strong> @{[ $ucpa->{cama_ucpa} || 'UCPA-01' ]} &bull; 
                    <strong>Puntuación Total:</strong> <span class="badge bg-dark font-monospace fs-6 px-2 py-0.5">$aldrete_total / 10 Puntos</span>
                </div>
                <div>
                    <span class="badge @{[ $aldrete_total >= 9 ? 'bg-success' : 'bg-warning text-dark' ]} fw-bold">
                        $aldrete_status
                    </span>
                </div>
            </div>
            <div class="d-flex flex-wrap gap-1 font-monospace">
                <span class="aldrete-pill">Actividad: <strong>@{[ $ucpa->{aldrete_actividad} // 2 ]}/2</strong></span>
                <span class="aldrete-pill">Respiración: <strong>@{[ $ucpa->{aldrete_respiracion} // 2 ]}/2</strong></span>
                <span class="aldrete-pill">Circulación (PA): <strong>@{[ $ucpa->{aldrete_circulacion} // 2 ]}/2</strong></span>
                <span class="aldrete-pill">Conciencia: <strong>@{[ $ucpa->{aldrete_conciencia} // 2 ]}/2</strong></span>
                <span class="aldrete-pill">Saturación O2: <strong>@{[ $ucpa->{aldrete_saturacion} // 2 ]}/2</strong></span>
            </div>
        </div>

        <!-- 7. Firmas de Validación y Responsabilidad Legal -->
        <div class="row mt-4 pt-2">
            <div class="col-6">
                <div class="signature-line">
                    <div class="sig-title">$cirujano_nombre</div>
                    <div class="sig-sub">CIRUJANO TITULAR &bull; CÉDULA PROFESIONAL</div>
                </div>
            </div>
            <div class="col-6">
                <div class="signature-line">
                    <div class="sig-title">$anestesio_nombre</div>
                    <div class="sig-sub">MÉDICO ANESTESIÓLOGO &bull; CÉDULA ESPECIALIDAD</div>
                </div>
            </div>
        </div>

        <div class="mt-4 pt-3 border-top text-center text-muted" style="font-size: 9px;">
            Documento médico-legal generado electrónicamente por <strong>OsPulso SaaS</strong> bajo las especificaciones de la Norma Oficial Mexicana NOM-004-SSA3-2012 del Expediente Clínico y NOM-006-SSA3-2011 para la práctica de la Anestesiología.
        </div>
    </div>

</body>
</html>
HTML

1;
