#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(decode_json encode_json);
use lib '..';
use FindBin;
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS Y SESIÓN ---
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();

# Redireccionar si no hay sesión
if (!$session_data->{session_ok}) {
    print $q->redirect(-url => '../index.pl');
    exit;
}

my $id_target = $q->param('id') || '';

my $PACIENTES_FILE   = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $ODONTOGRAMA_FILE = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');

my $pacientes_ref = leer_tabla($PACIENTES_FILE, '\|');

my $paciente = {
    id_paciente => $id_target,
    nombre      => 'Desconocido',
    curp        => '-',
    f_nac       => '-',
    sexo        => '-',
};

foreach my $p (@$pacientes_ref) {
    if ($p->[0] eq $id_target) {
        $paciente->{nombre} = $p->[2] || 'Desconocido';
        $paciente->{curp}   = $p->[5] || '-';
        $paciente->{f_nac}  = $p->[6] || '-';
        $paciente->{sexo}   = $p->[7] || '-';
        last;
    }
}

# Calcular edad estimada
my $edad = '-';
if ($paciente->{f_nac} =~ /(\d{4})/) {
    my $year = $1;
    my $current_year = (localtime)[5] + 1900;
    $edad = $current_year - $year;
    $edad = $edad > 0 ? $edad : '-';
}

# Obtener notas preexistentes de odontograma si las hay
my $notas_guardadas = '';
if (-e $ODONTOGRAMA_FILE) {
    my $odonto_rows = leer_tabla($ODONTOGRAMA_FILE, '\|');
    foreach my $row (@$odonto_rows) {
        if ($row->[0] eq $id_target) {
            $notas_guardadas = $row->[3] || '';
            last;
        }
    }
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>OSOdontograma Viewer Pro - $paciente->{nombre}</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    <link rel="apple-touch-icon" sizes="180x180" href="../favicon/apple-touch-icon.png">

    <!-- Bootstrap 5.3 -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Bootstrap Icons -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css">
    <!-- Google Fonts -->
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght\@400;500;600;700;800;900&display=swap" rel="stylesheet">

    <!-- OSPulso Master CSS -->
    <link rel="stylesheet" href="../css/ospulso_master.css?v=$^T">
    <!-- Odontograma Plus Vectorial CSS -->
    <link rel="stylesheet" href="../css/odontograma_plus.css?v=$^T">

    <style>
        :root {
            --odonto-header-h: 70px;
            --odonto-sidebar-w: 360px;
            --odonto-canvas-bg: #f8fafc;
        }
        body.odonto-viewer-mode {
            margin: 0;
            padding: 0;
            overflow: hidden;
            height: 100vh;
            width: 100vw;
            background-color: var(--odonto-canvas-bg);
            font-family: 'Inter', sans-serif;
            color: #1e293b;
        }
        .odonto-viewer-layout {
            display: flex;
            flex-direction: column;
            height: 100vh;
            width: 100vw;
        }
        .odonto-viewer-header {
            height: var(--odonto-header-h);
            background: linear-gradient(135deg, #0A2A66 0%, #082050 100%);
            color: #ffffff;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 1.25rem;
            z-index: 30;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.15);
            border-bottom: 2px solid var(--md-teal-clinical, #19B7A5);
        }
        .odonto-viewer-body {
            display: flex;
            flex: 1;
            height: calc(100vh - var(--odonto-header-h));
            overflow: hidden;
            position: relative;
        }
        .odonto-sidebar-left {
            width: var(--odonto-sidebar-w);
            min-width: var(--odonto-sidebar-w);
            background: #ffffff;
            border-right: 1px solid #e2e8f0;
            display: flex;
            flex-direction: column;
            z-index: 20;
            transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1), margin-left 0.3s cubic-bezier(0.16, 1, 0.3, 1);
            box-shadow: 4px 0 15px rgba(0, 0, 0, 0.03);
            overflow-y: auto;
        }
        .odonto-sidebar-left.collapsed {
            margin-left: calc(-1 * var(--odonto-sidebar-w));
        }
        .odonto-stage-main {
            flex: 1;
            display: flex;
            flex-direction: column;
            overflow: auto;
            position: relative;
            background: radial-gradient(circle at center, #ffffff 0%, #f1f5f9 100%);
            padding: 1.5rem;
            align-items: center;
            justify-content: flex-start;
        }
        .odonto-hud-toolbar {
            position: sticky;
            top: 0;
            z-index: 15;
            background: rgba(255, 255, 255, 0.85);
            backdrop-filter: blur(12px);
            border: 1px solid rgba(226, 232, 240, 0.8);
            border-radius: 50px;
            padding: 6px 16px;
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.05);
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 1.5rem;
        }
        .odonto-findings-table th {
            font-size: 0.72rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #64748b;
        }
        .odonto-findings-table td {
            font-size: 0.8rem;
        }
    </style>
</head>
<body class="odonto-viewer-mode">

    <div class="odonto-viewer-layout">
        <!-- HEADER / NAVBAR CORPORATIVO MEDENTIA -->
        <header class="odonto-viewer-header">
            <div class="d-flex align-items-center gap-3">
                <a href="render_expediente_clinico.pl?id=$paciente->{id_paciente}#tab6" class="btn btn-outline-light btn-sm rounded-pill px-3 fw-bold d-flex align-items-center gap-2" title="Volver al Expediente Clínico">
                    <i class="bi bi-arrow-left"></i>
                    <span class="d-none d-md-inline">Expediente</span>
                </a>
                <button class="btn btn-sm btn-link text-white text-decoration-none p-1" onclick="toggleOdontoSidebar()" title="Mostrar/Ocultar Panel Lateral">
                    <i class="bi bi-layout-sidebar-inset fs-5"></i>
                </button>
                <div class="vr bg-white opacity-25 d-none d-sm-block"></div>
                <div class="d-flex align-items-center gap-2">
                    <span class="badge bg-teal text-white rounded-pill px-3 py-1 fw-black" style="background-color: var(--md-teal-clinical, #19B7A5) !important;">FDI / ISO 3950</span>
                    <h5 class="fw-black mb-0 text-white text-nowrap d-none d-lg-block">OSOdontograma Viewer Pro</h5>
                </div>
            </div>

            <!-- Ficha del Paciente (Centro) -->
            <div class="d-none d-md-flex align-items-center gap-3 bg-white bg-opacity-10 px-3 py-1 rounded-pill border border-white border-opacity-10">
                <div class="text-white">
                    <i class="bi bi-person-fill text-teal me-1" style="color: var(--md-teal-clinical);"></i>
                    <span class="fw-bold">$paciente->{nombre}</span>
                    <span class="opacity-50 small ms-2">ID: $paciente->{id_paciente}</span>
                    <span class="opacity-50 small ms-2">($edad a&ntilde;os, $paciente->{sexo})</span>
                </div>
            </div>

            <!-- Acciones Principales (Derecha) -->
            <div class="d-flex align-items-center gap-2">
                <div class="text-end me-2 d-none d-xl-block">
                    <span class="small text-white-50 fw-bold d-block lh-1" style="font-size: 0.7rem;">PRESUPUESTO PENDIENTE</span>
                    <span class="h5 fw-black text-warning m-0 lh-1" id="odonto-total-pending">\$0.00</span>
                </div>
                <button type="button" class="btn btn-sm btn-outline-light rounded-pill px-3 fw-bold d-flex align-items-center gap-1 shadow-xs" onclick="window.print()">
                    <i class="bi bi-printer-fill"></i>
                    <span class="d-none d-sm-inline">Imprimir</span>
                </button>
                <button type="button" class="btn btn-sm btn-medentia rounded-pill px-3 fw-bold d-flex align-items-center gap-2 shadow-sm" onclick="saveOdontogramaToServer()">
                    <i class="bi bi-cloud-arrow-up-fill" style="color: var(--md-cyan-ia);"></i>
                    <span>Guardar</span>
                </button>
            </div>
        </header>

        <!-- CUERPO PRINCIPAL DEL VISOR -->
        <div class="odonto-viewer-body">
            
            <!-- PANEL LATERAL IZQUIERDO (HALLAZGOS Y PRESUPUESTO) -->
            <aside class="odonto-sidebar-left" id="odontoSidebar">
                <!-- Info Paciente Rápida -->
                <div class="p-3 border-bottom bg-light">
                    <div class="d-flex align-items-center gap-2 mb-1">
                        <i class="bi bi-person-vcard fs-5 text-teal" style="color: var(--md-teal-clinical);"></i>
                        <span class="fw-black text-navy small" style="color: var(--md-blue-deep);">$paciente->{nombre}</span>
                    </div>
                    <div class="text-muted small">
                        <span>CURP: $paciente->{curp}</span> &bull; <span>Edad: $edad</span>
                    </div>
                </div>

                <!-- Resumen Presupuestario -->
                <div class="p-3 border-bottom">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="small fw-black text-muted text-uppercase">Plan de Tratamiento</span>
                        <span class="badge bg-danger-subtle text-danger rounded-pill fw-bold" id="badge-total-pending">0 Pendientes</span>
                    </div>
                    <div class="p-3 rounded-4 bg-light border mb-2 text-center">
                        <span class="small text-muted fw-bold d-block">Importe Total Estimado</span>
                        <h3 class="fw-black text-danger m-0" id="odonto-sidebar-price">\$0.00</h3>
                        <span class="badge bg-success-subtle text-success rounded-pill mt-1" id="odonto-sidebar-count">0 Procedimientos</span>
                    </div>
                </div>

                <!-- Lista de Hallazgos en Tiempo Real -->
                <div class="p-3 flex-grow-1 overflow-auto border-bottom">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="small fw-black text-muted text-uppercase"><i class="bi bi-list-check me-1 text-teal" style="color: var(--md-teal-clinical);"></i>Hallazgos Registrados</span>
                        <button type="button" class="btn btn-xs btn-link text-danger text-decoration-none p-0 fw-bold" onclick="clearOdontogram()">Limpiar</button>
                    </div>
                    <div class="table-responsive">
                        <table class="table table-sm table-hover align-middle mb-0 odonto-findings-table">
                            <thead class="table-light">
                                <tr>
                                    <th>Pieza</th>
                                    <th>Cara/Zona</th>
                                    <th>Diagnóstico</th>
                                    <th class="text-end">Costo</th>
                                </tr>
                            </thead>
                            <tbody id="tbody-sidebar-findings">
                                <tr>
                                    <td colspan="4" class="text-center text-muted py-4 small">Sin hallazgos clínicos registrados. Haz click en una pieza dental.</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Notas Clínicas Odontológicas -->
                <div class="p-3">
                    <label for="odontograma-notas" class="small fw-black text-muted text-uppercase mb-2 d-block">
                        <i class="bi bi-pencil-square me-1 text-teal" style="color: var(--md-teal-clinical);"></i>Notas Clínicas del Odontograma
                    </label>
                    <textarea class="form-control form-control-sm rounded-3 shadow-xs" id="odontograma-notas" rows="3" placeholder="Observaciones de oclusión, periodonto, encías...">$notas_guardadas</textarea>
                </div>
            </aside>

            <!-- ESCENARIO CENTRAL DEL ODONTOGRAMA (CANVAS COMPLETO) -->
            <main class="odonto-stage-main">
                
                <!-- HUD FLOTANTE SUPERIOR CON CONTROLES DE ZOOM Y ACCIONES -->
                <div class="odonto-hud-toolbar">
                    <div class="d-flex align-items-center gap-1">
                        <button type="button" class="btn btn-xs btn-light rounded-circle px-2 py-1 text-muted border shadow-xs" onclick="changeOdontoZoom(-0.1)" title="Zoom Out (Alejar)">
                            <i class="bi bi-dash-lg"></i>
                        </button>
                        <span class="small fw-black text-navy px-2" id="odonto-zoom-label" style="min-width: 48px; text-align: center;">100%</span>
                        <button type="button" class="btn btn-xs btn-light rounded-circle px-2 py-1 text-muted border shadow-xs" onclick="changeOdontoZoom(0.1)" title="Zoom In (Acercar)">
                            <i class="bi bi-plus-lg"></i>
                        </button>
                        <button type="button" class="btn btn-xs btn-outline-secondary rounded-pill px-2 py-1 ms-1 fw-bold" onclick="resetOdontoZoom()" title="Restablecer Zoom">
                            <i class="bi bi-aspect-ratio me-1"></i>100%
                        </button>
                    </div>

                    <div class="vr bg-secondary opacity-25"></div>

                    <!-- Botones de Acción de Prueba / Convención -->
                    <div class="d-flex align-items-center gap-1">
                        <span class="badge rounded-pill bg-light border text-muted px-2 py-1 small fw-bold">
                            <i class="bi bi-cursor-fill text-teal me-1" style="color: var(--md-teal-clinical);"></i>Click en cara anatómica para diagnosticar
                        </span>
                    </div>
                </div>

                <!-- CONTENEDOR DEL ODONTOGRAMA VECTORIAL 2D (4 CUADRANTES) -->
                <div class="w-100 d-flex justify-content-center">
                    <div id="odontograma-svg-container" class="text-center" data-patient-id="$paciente->{id_paciente}" style="min-width: 900px; max-width: 1280px;">
                        <div class="py-5 text-muted opacity-50">
                            <div class="spinner-border text-primary mb-3"></div><br>
                            Inicializando OSOdontograma Vectorial...
                        </div>
                    </div>
                </div>

                <!-- LEYENDA CLÍNICA AL PIE -->
                <div class="odonto-legend mt-4 bg-white p-3 rounded-pill border shadow-xs">
                    <div class="odonto-legend-item">
                        <span class="odonto-legend-color" style="background: #FF3B30;"></span>
                        <span class="small fw-bold">Patología / Pendiente (Rojo)</span>
                    </div>
                    <div class="odonto-legend-item">
                        <span class="odonto-legend-color" style="background: #007AFF;"></span>
                        <span class="small fw-bold">Tratamiento Existente (Azul)</span>
                    </div>
                    <div class="odonto-legend-item">
                        <span class="odonto-legend-color" style="background: #FFFFFF; border: 1px solid #94a3b8;"></span>
                        <span class="small fw-bold">Superficie Sana (Blanco)</span>
                    </div>
                    <div class="odonto-legend-item">
                        <span class="odonto-legend-color" style="background: rgba(25, 183, 165, 0.4); border: 1px solid #19B7A5;"></span>
                        <span class="small fw-bold">Hover Interactivo (Teal)</span>
                    </div>
                    <div class="odonto-legend-item">
                        <span class="badge bg-secondary-subtle text-secondary rounded-pill px-2 py-0 border">✕</span>
                        <span class="small fw-bold">Pieza Ausente</span>
                    </div>
                </div>

            </main>
        </div>
    </div>

    <!-- MODAL CLÍNICO CONTEXTUAL GLASSMORPHISM (3 NIVELES) -->
    <div class="modal fade" id="modalOdontoClinico" tabindex="-1" aria-labelledby="modalOdontoClinicoLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered modal-lg">
            <div class="modal-content odonto-modal-glass border-0 shadow-lg">
                <div class="modal-header border-bottom py-3 px-4 d-flex justify-content-between align-items-center">
                    <div class="d-flex align-items-center gap-3">
                        <span class="badge bg-teal text-white rounded-pill px-3 py-2 fw-black fs-6" id="odonto-modal-tooth-badge" style="background-color: var(--md-teal-clinical, #19B7A5) !important;">#16</span>
                        <div>
                            <h5 class="fw-black mb-0 text-navy" id="odonto-modal-tooth-title" style="color: var(--md-blue-deep);">Primer Molar Superior Derecho</h5>
                            <span class="small text-muted fw-bold" id="odonto-modal-surface-label"><i class="bi bi-geo-alt-fill text-teal me-1" style="color: var(--md-teal-clinical);"></i>Zona activa: Superficie MESIAL</span>
                        </div>
                    </div>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
                </div>
                <div class="modal-body p-4">
                    <!-- Nivel 1: Alcance -->
                    <div class="mb-4">
                        <label class="small text-muted fw-bold text-uppercase mb-2 d-block">1. Alcance del Diagnóstico</label>
                        <div class="btn-group w-100 p-1 bg-light rounded-pill border" role="group" id="odonto-scope-group">
                            <input type="radio" class="btn-check" name="odonto-scope" id="scope-surface" value="SURFACE" checked onchange="handleScopeChange('SURFACE')">
                            <label class="btn btn-sm rounded-pill fw-bold" for="scope-surface" id="label-scope-surface"><i class="bi bi-bounding-box me-1"></i>Superficie Seleccionada</label>

                            <input type="radio" class="btn-check" name="odonto-scope" id="scope-crown" value="CROWN" onchange="handleScopeChange('CROWN')">
                            <label class="btn btn-sm rounded-pill fw-bold" for="scope-crown"><i class="bi bi-circle-square me-1"></i>Toda la Corona (5 caras)</label>

                            <input type="radio" class="btn-check" name="odonto-scope" id="scope-tooth" value="TOOTH" onchange="handleScopeChange('TOOTH')">
                            <label class="btn btn-sm rounded-pill fw-bold" for="scope-tooth"><i class="bi bi-x-circle me-1"></i>Pieza Completa (Ausente)</label>
                        </div>
                    </div>

                    <!-- Nivel 2: Selector en Cascada por Categorías -->
                    <div class="mb-4">
                        <label class="small text-muted fw-bold text-uppercase mb-2 d-block">2. Categoría y Condición Clínica</label>
                        <ul class="nav nav-pills nav-fill mb-3 odonto-category-pills" id="pills-odonto-cat" role="tablist">
                            <li class="nav-item" role="presentation">
                                <button class="nav-link active fw-bold text-danger" id="pills-pending-tab" data-bs-toggle="pill" data-bs-target="#pills-pending" type="button" role="tab"><i class="bi bi-exclamation-circle-fill me-1"></i>Patología / Pendiente</button>
                            </li>
                            <li class="nav-item" role="presentation">
                                <button class="nav-link fw-bold text-primary" id="pills-existing-tab" data-bs-toggle="pill" data-bs-target="#pills-existing" type="button" role="tab"><i class="bi bi-check-circle-fill me-1"></i>Tratamiento Existente</button>
                            </li>
                            <li class="nav-item" role="presentation">
                                <button class="nav-link fw-bold text-secondary" id="pills-healthy-tab" data-bs-toggle="pill" data-bs-target="#pills-healthy" type="button" role="tab"><i class="bi bi-eraser-fill me-1"></i>Sano / Limpiar</button>
                            </li>
                        </ul>

                        <div class="tab-content" id="pills-odonto-tabContent">
                            <!-- TAB 1: PENDIENTES / PATOLOGÍAS -->
                            <div class="tab-pane fade show active" id="pills-pending" role="tabpanel">
                                <div class="row g-2" id="grid-conditions-pending">
                                    <!-- Inyectado por JS -->
                                </div>
                            </div>

                            <!-- TAB 2: TRATAMIENTOS EXISTENTES -->
                            <div class="tab-pane fade" id="pills-existing" role="tabpanel">
                                <div class="row g-2" id="grid-conditions-existing">
                                    <!-- Inyectado por JS -->
                                </div>
                            </div>

                            <!-- TAB 3: SANO / LIMPIAR -->
                            <div class="tab-pane fade" id="pills-healthy" role="tabpanel">
                                <div class="p-4 bg-light rounded-4 text-center border">
                                    <i class="bi bi-shield-check text-success display-5 d-block mb-2"></i>
                                    <h6 class="fw-black text-navy mb-1" style="color: var(--md-blue-deep);">Restaurar a Estado Sano</h6>
                                    <p class="small text-muted mb-3">Se removerán las marcas patológicas o restauraciones de la zona o diente seleccionado.</p>
                                    <button type="button" class="btn btn-outline-secondary rounded-pill px-4 fw-bold" onclick="selectOdontoCondition('HEALTHY')">
                                        <i class="bi bi-check-lg me-1"></i>Marcar Sano / Sin Hallazgo
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Nivel 3: Resumen y Precio -->
                    <div class="p-3 bg-light rounded-4 border d-flex justify-content-between align-items-center flex-wrap gap-2">
                        <div>
                            <span class="small text-muted fw-bold d-block">Resumen de Selección:</span>
                            <span class="fw-bold" style="color: var(--md-blue-deep);" id="odonto-summary-condition">Caries Dental (Activa)</span>
                            <span class="badge bg-danger-subtle text-danger ms-2 rounded-pill px-2 py-1" id="odonto-summary-scope">Superficie Mesial</span>
                        </div>
                        <div class="text-end">
                            <span class="small text-muted fw-bold d-block">Importe Sugerido</span>
                            <span class="h5 fw-black text-danger m-0" id="odonto-summary-price">\$850.00 MXN</span>
                        </div>
                    </div>
                </div>
                <div class="modal-footer border-top py-3 px-4 d-flex justify-content-between">
                    <button type="button" class="btn btn-outline-secondary rounded-pill px-4 fw-bold" data-bs-dismiss="modal">Cancelar</button>
                    <button type="button" class="btn btn-medentia rounded-pill px-4 fw-bold" onclick="confirmApplyClinicalCondition()">
                        <i class="bi bi-check2-circle me-1" style="color: var(--md-cyan-ia);"></i>Aplicar al Odontograma
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Bootstrap 5.3 JS Bundle -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <!-- SweetAlert2 -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
    <!-- Axios -->
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>

    <!-- Motor Frontend Odontograma Plus -->
    <script src="../js/odontograma.js?v=$^T"></script>

    <script>
        window.ID_PACIENTE = '$paciente->{id_paciente}';
    </script>
HTML

print <<'JS';
    <script>
        function toggleOdontoSidebar() {
            const sidebar = document.getElementById('odontoSidebar');
            if (sidebar) {
                sidebar.classList.toggle('collapsed');
            }
        }

        // Actualizar lista de hallazgos en la barra lateral
        function refreshSidebarFindings() {
            const tbody = document.getElementById('tbody-sidebar-findings');
            const priceBadge = document.getElementById('odonto-sidebar-price');
            const countBadge = document.getElementById('odonto-sidebar-count');
            const badgePending = document.getElementById('badge-total-pending');

            if (!tbody) return;

            let rowsHtml = '';
            let total = 0;
            let pendingCount = 0;

            const teeth = window.odontogramState.teeth || {};
            const toothKeys = Object.keys(teeth).sort();

            toothKeys.forEach(toothId => {
                const tData = teeth[toothId];
                if (tData.absent) {
                    rowsHtml += `
                        <tr>
                            <td><span class="badge bg-secondary rounded-pill fw-bold">#${toothId}</span></td>
                            <td><span class="text-muted small">Pieza</span></td>
                            <td><span class="badge bg-dark-subtle text-dark border">Ausente ✕</span></td>
                            <td class="text-end text-muted">-</td>
                        </tr>
                    `;
                }

                if (tData.surfaces) {
                    Object.keys(tData.surfaces).forEach(surf => {
                        const sData = tData.surfaces[surf];
                        const isPending = sData.state === 'PENDING_TREATMENT';
                        const badgeClass = isPending ? 'bg-danger-subtle text-danger border-danger-subtle' : 'bg-primary-subtle text-primary border-primary-subtle';
                        const price = parseFloat(sData.price) || 0;
                        if (isPending) {
                            total += price;
                            pendingCount++;
                        }

                        rowsHtml += `
                            <tr>
                                <td><span class="badge bg-light border text-navy fw-bold">#${toothId}</span></td>
                                <td><span class="small fw-semibold text-uppercase text-muted">${surf}</span></td>
                                <td><span class="badge ${badgeClass} border">${sData.code || 'Condición'}</span></td>
                                <td class="text-end fw-bold ${isPending ? 'text-danger' : 'text-primary'}">$${price.toFixed(2)}</td>
                            </tr>
                        `;
                    });
                }
            });

            if (!rowsHtml) {
                tbody.innerHTML = `<tr><td colspan="4" class="text-center text-muted py-4 small">Sin hallazgos clínicos registrados. Haz click en una pieza dental.</td></tr>`;
            } else {
                tbody.innerHTML = rowsHtml;
            }

            if (priceBadge) priceBadge.textContent = `$${total.toFixed(2)}`;
            if (countBadge) countBadge.textContent = `${pendingCount} Procedimientos`;
            if (badgePending) badgePending.textContent = `${pendingCount} Pendientes`;
        }

        // Sobrescribir o enganchar al recálculo
        const originalRecalculate = window.recalculateFinancialTotal;
        window.recalculateFinancialTotal = function() {
            if (typeof originalRecalculate === 'function') {
                originalRecalculate();
            }
            refreshSidebarFindings();
        };

        // Guardar Odontograma en Servidor (Persistencia Atómica Canónica)
        window.saveOdontogramaToServer = function() {
            const patientId = window.ID_PACIENTE;
            const notas = document.getElementById('odontograma-notas')?.value || '';

            if (!patientId) {
                Swal.fire('Error', 'ID de paciente no definido.', 'error');
                return;
            }

            Swal.fire({
                title: 'Sincronizando Odontograma...',
                text: 'Guardando registro clínico atómicamente en OSPulso Cloud',
                allowOutsideClick: false,
                didOpen: () => { Swal.showLoading(); }
            });

            const payload = new URLSearchParams();
            payload.append('accion', 'save');
            payload.append('id_paciente', patientId);
            payload.append('notas', notas);
            payload.append('financialTotalPending', window.odontogramState.financialTotalPending || 0);
            payload.append('data', JSON.stringify(window.odontogramState));

            axios.post('../api/odontograma_api.pl', payload)
                .then(res => {
                    if (res.data && res.data.ok) {
                        Swal.fire({
                            icon: 'success',
                            title: 'Odontograma Guardado',
                            text: 'El estado dental y presupuesto han sido sincronizados con éxito.',
                            timer: 2000,
                            showConfirmButton: false
                        });
                    } else {
                        Swal.fire('Error', res.data?.msg || 'No se pudo guardar el odontograma', 'error');
                    }
                })
                .catch(err => {
                    console.error('Error al guardar odontograma:', err);
                    Swal.fire('Error', 'Fallo de conexión al servidor.', 'error');
                });
        };

        // Cargar Odontograma desde Servidor (Soporte Dual: JSON Canónico y Tabla Dat)
        window.loadOdontogramaFromServer = function(patientId) {
            if (!patientId) return;

            axios.get(`../api/odontograma_api.pl?accion=get&id_paciente=${encodeURIComponent(patientId)}`)
                .then(res => {
                    if (res.data && res.data.ok && res.data.data) {
                        const data = res.data.data;
                        if (data.notas && document.getElementById('odontograma-notas')) {
                            document.getElementById('odontograma-notas').value = data.notas;
                        }

                        if (typeof window.loadOdontogramState === 'function') {
                            window.loadOdontogramState(data);
                        } else {
                            // Fallback de hidratación directa si la función no estuviera lista
                            if (data.teeth) {
                                window.odontogramState.teeth = data.teeth;
                            }
                        }

                        refreshSidebarFindings();
                    }
                })
                .catch(err => {
                    console.warn('Aviso: No se pudo cargar datos previos de odontograma:', err);
                });
        };

        document.addEventListener('DOMContentLoaded', () => {
            const containerId = 'odontograma-svg-container';
            const patientId = window.ID_PACIENTE;

            if (typeof renderOdontogram === 'function') {
                renderOdontogram(containerId, patientId);
                // Cargar datos previos
                setTimeout(() => {
                    loadOdontogramaFromServer(patientId);
                }, 100);
            }
        });
    </script>
</body>
</html>
JS
