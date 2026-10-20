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
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

# --- CONFIGURACIÓN DE RUTAS Y SESIÓN ---
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = eval { check_session() } || {};

# Redireccionar si no hay sesión
if (!$session_data->{session_ok}) {
    print $q->redirect(-url => '../index.pl');
    exit;
}

eval {
    my $id_target = $q->param('id') || '';
    my $id_odonto_req = $q->param('id_odonto') || '';
    my $alias_odonto_req = $q->param('alias') || '';

my $PACIENTES_FILE   = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $ODONTOGRAMA_FILE = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');
my $PACIENTE_JSON_FILE = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas', "paciente_${id_target}.json");

my $pacientes_ref = leer_tabla($PACIENTES_FILE, '\|');

my $paciente = {
    id_paciente => $id_target,
    nombre      => 'Desconocido',
    curp        => '-',
    correo      => '-',
    f_nac       => '-',
    sexo        => '-',
};

foreach my $p (@$pacientes_ref) {
    if ($p->[0] eq $id_target) {
        $paciente->{nombre} = $p->[2] || 'Desconocido';
        $paciente->{curp}   = $p->[4] || '-';
        $paciente->{correo} = $p->[5] || '-';
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

# Inicializar Alias, Estado y Notas desde el JSON del paciente
my $odonto_alias = $alias_odonto_req;
my $odonto_estado = 'En Proceso';
my $notas_guardadas = '';
my $id_odonto_activo = $id_odonto_req;

if (-e $PACIENTE_JSON_FILE && open my $fh_pj, '<:raw', $PACIENTE_JSON_FILE) {
    local $/;
    my $raw_json = <$fh_pj>;
    close $fh_pj;
    my $p_data = eval { decode_json($raw_json) };
    if ($p_data && ref($p_data) eq 'HASH') {
        if ($p_data->{odontogramas} && ref($p_data->{odontogramas}) eq 'ARRAY') {
            foreach my $od (@{ $p_data->{odontogramas} }) {
                if ($od->{alias}) {
                    $od->{alias} =~ s/ÃƒÂ­/í/g; $od->{alias} =~ s/Ã­/í/g;
                    $od->{alias} =~ s/Ã³/ó/g; $od->{alias} =~ s/Ã¡/á/g;
                    $od->{alias} =~ s/Ã©/é/g; $od->{alias} =~ s/Ãº/ú/g;
                    $od->{alias} =~ s/Ã±/ñ/g;
                }
                if ($od->{notas}) {
                    $od->{notas} =~ s/ÃƒÂ­/í/g; $od->{notas} =~ s/Ã­/í/g;
                    $od->{notas} =~ s/Ã³/ó/g; $od->{notas} =~ s/Ã¡/á/g;
                    $od->{notas} =~ s/Ã©/é/g; $od->{notas} =~ s/Ãº/ú/g;
                    $od->{notas} =~ s/Ã±/ñ/g;
                }
                if (!$id_odonto_activo || $od->{id_odonto} eq $id_odonto_activo) {
                    $id_odonto_activo ||= $od->{id_odonto};
                    $odonto_alias     ||= $od->{alias};
                    $odonto_estado    = $od->{estado} if $od->{estado};
                    $notas_guardadas  = $od->{notas} if $od->{notas};
                    last;
                }
            }
        }
    }
}

$id_odonto_activo ||= "OD-${id_target}-" . time();
$odonto_alias     ||= "Diagnóstico Clínico Inicial";

# Cargar datos de la Clínica / Organización para Vista de Impresión
my $negocio_nombre = 'Clínica Odontológica Especializada';
my $negocio_dir    = '';
my $negocio_tel    = '';
my $negocio_rfc    = '';
my $negocio_clues  = '';
my $negocio_logo   = '';

my $org_id_sesion = $session_data->{id_empresa} || $session_data->{organizacion_id} || '';
my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fhn, '<:encoding(UTF-8)', $negocios_file)) {
    <$fhn>;
    while (my $ln = <$fhn>) {
        $ln =~ s/\x00//g;
        chomp $ln;
        next if $ln =~ /^\s*$/;
        my @n = split /\|/, $ln, -1;
        if (!$org_id_sesion || $n[0] eq $org_id_sesion) {
            $negocio_nombre = $n[1] if $n[1];
            my $calle   = $n[6] // '';
            my $colonia = $n[17] // '';
            my $muni    = $n[16] // '';
            my $ent     = $n[15] // '';
            my $cp      = $n[14] // '';
            my @partes_dir = grep { $_ ne '' } ($calle, $colonia, $muni, $ent, ($cp ? "C.P. $cp" : ''));
            $negocio_dir    = join(', ', @partes_dir);
            $negocio_tel    = $n[7] // '';
            $negocio_rfc    = $n[10] // '';
            $negocio_logo   = $n[9] // '';
            $negocio_clues  = $n[18] // '';
            last if $org_id_sesion && $n[0] eq $org_id_sesion;
        }
    }
    close $fhn;
}

my ($sec_c,$min_c,$hour_c,$mday_c,$mon_c,$year_c) = localtime();
my $fecha_actual = sprintf("%02d/%02d/%04d %02d:%02d", $mday_c, $mon_c+1, $year_c+1900, $hour_c, $min_c);
my $usuario_sesion = $session_data->{usuario} || 'Dr(a). Odontólogo';

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
        /* Los estilos residen canónicamente en ../css/odontograma_plus.css */
    </style>
</head>
<body class="odonto-viewer-mode">

    <div class="odonto-viewer-layout">
        <!-- HEADER / NAVBAR CORPORATIVO ODONTOGRAMA CLÍNICO -->
        <header class="odonto-viewer-header">
            <!-- Botón Volver y Toggle Sidebar (Izquierda) -->
            <div class="d-flex align-items-center gap-2">
                <a href="render_expediente_clinico.pl?id=$paciente->{id_paciente}#tab6" class="btn btn-outline-secondary btn-sm rounded-pill px-3 fw-bold d-flex align-items-center gap-2" style="border-color: #cbd5e1; color: var(--odonto-navy);" title="Volver al Expediente Clínico">
                    <i class="bi bi-arrow-left"></i>
                    <span class="d-none d-lg-inline">Expediente</span>
                </a>
                <button class="btn btn-sm btn-outline-secondary rounded-circle p-2 d-flex align-items-center justify-content-center" style="border-color: #cbd5e1; color: var(--odonto-navy);" onclick="toggleOdontoSidebar()" title="Mostrar/Ocultar Panel de Información">
                    <i class="bi bi-layout-sidebar-inset fs-6"></i>
                </button>
            </div>

            <!-- BARRA DE HERRAMIENTAS Y OPCIONES ESTILO RAYOS X (Centro - Imagen 1) -->
            <div class="odonto-rayos-x-toolbar d-none d-md-flex">
                <!-- Cápsula 1: Archivo y Acciones -->
                <div class="odonto-tool-capsule" title="Herramientas de Estudio">
                    <button type="button" class="odonto-tool-btn" onclick="toggleOdontoSidebar()" title="Ver Ficha y Hallazgos">
                        <i class="bi bi-folder2-open"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="loadOdontogramaFromServer(window.ID_PACIENTE, window.ID_ODONTO)" title="Recargar del Servidor">
                        <i class="bi bi-arrow-clockwise"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="abrirVistaImpresionOdonto()" title="Vista Previa e Impresión de Odontograma">
                        <i class="bi bi-printer"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn text-success" onclick="saveOdontogramaToServer()" title="Guardar Odontograma en Servidor">
                        <i class="bi bi-cloud-arrow-up-fill"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="abrirModalGestionCatalogoOdonto()" title="Gestión de Catálogo (Patologías y Tratamientos)">
                        <i class="bi bi-sliders2"></i>
                    </button>
                </div>

                <!-- Cápsula 2: Navegación y Zoom -->
                <div class="odonto-tool-capsule" title="Navegación y Zoom">
                    <button type="button" class="odonto-tool-btn active" id="btn-tool-pointer" onclick="setActiveOdontoTool('pointer')" title="Selección / Puntero">
                        <i class="bi bi-cursor-fill"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" id="btn-tool-pan" onclick="setActiveOdontoTool('pan')" title="Modo Desplazamiento (Pan)">
                        <i class="bi bi-arrows-move"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="changeOdontoZoom(0.1)" title="Acercar (Zoom +)">
                        <i class="bi bi-zoom-in"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="changeOdontoZoom(-0.1)" title="Alejar (Zoom -)">
                        <i class="bi bi-zoom-out"></i>
                    </button>
                </div>

                <!-- Cápsula 3: Diagnóstico y Anotaciones -->
                <div class="odonto-tool-capsule" title="Herramientas Clínicas">
                    <button type="button" class="odonto-tool-btn active" id="btn-diag-faces" onclick="setOdontoDiagScope('SURFACE')" title="Diagnóstico por Cara Anatómica">
                        <i class="bi bi-bounding-box"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" id="btn-diag-crown" onclick="setOdontoDiagScope('CROWN')" title="Diagnóstico Corona Completa">
                        <i class="bi bi-square"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" id="btn-diag-tooth" onclick="setOdontoDiagScope('TOOTH')" title="Diagnóstico Pieza Completa / Extracción">
                        <i class="bi bi-circle"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="focusOdontoNotes()" title="Anotaciones y Hallazgos">
                        <i class="bi bi-pencil-square"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn text-danger" onclick="clearOdontogram()" title="Limpiar Marcas (Borrador)">
                        <i class="bi bi-eraser-fill"></i>
                    </button>
                </div>

                <!-- Cápsula 4: Vistas y Dentición -->
                <div class="odonto-tool-capsule" title="Vistas Anatómicas">
                    <button type="button" class="odonto-tool-btn active" id="btn-hdr-perm" onclick="setDentitionType('PERMANENT')" title="Dentición Permanente (32)">
                        <span class="odonto-badge-dentition" style="font-size: 0.8rem;">32</span>
                    </button>
                    <button type="button" class="odonto-tool-btn" id="btn-hdr-temp" onclick="setDentitionType('TEMPORARY')" title="Dentición Temporal / Infantil (20)">
                        <span class="odonto-badge-dentition" style="font-size: 0.8rem;">20</span>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="focusOdontoArch('upper')" title="Vista Maxilar Superior">
                        <i class="bi bi-chevron-bar-up"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="focusOdontoArch('lower')" title="Vista Mandíbula Inferior">
                        <i class="bi bi-chevron-bar-down"></i>
                    </button>
                    <button type="button" class="odonto-tool-btn" onclick="resetOdontoZoom()" title="Restablecer Vista (100%)">
                        <i class="bi bi-aspect-ratio"></i>
                    </button>
                </div>
            </div>

            <!-- Acciones Principales (Derecha - Presupuesto Pendiente Imagen 1) -->
            <div class="d-flex align-items-center gap-2">
                <div class="text-end me-2">
                    <span class="odonto-header-kpi-title">PRESUPUESTO PENDIENTE</span>
                    <span class="odonto-header-kpi-amount" id="odonto-total-pending">\$0.00</span>
                </div>
            </div>
        </header>

        <!-- CUERPO PRINCIPAL DEL VISOR -->
        <div class="odonto-viewer-body">
            
            <!-- PANEL LATERAL IZQUIERDO (HALLAZGOS Y PRESUPUESTO - TEMA CLÍNICO CLARO) -->
            <aside class="odonto-sidebar-left" id="odontoSidebar">
                <!-- Info Paciente y Alias Rápido -->
                <div class="odonto-sidebar-header-box">
                    <div class="d-flex align-items-center justify-content-between mb-1">
                        <div class="d-flex align-items-center gap-2">
                            <div class="rounded-circle p-1 d-flex align-items-center justify-content-center" style="background: var(--odonto-teal-light); border: 1px solid var(--odonto-teal);">
                                <i class="bi bi-person-vcard fs-6" style="color: var(--odonto-teal-dark);"></i>
                            </div>
                            <span class="fw-black text-dark small">$paciente->{nombre}</span>
                        </div>
                        <span class="badge rounded-pill odonto-patient-badge">$id_odonto_activo</span>
                    </div>
                    <div class="small mb-3 text-secondary" style="font-size: 0.75rem;">
                        <span><strong>CORREO:</strong> $paciente->{correo}</span> &bull; <span>Edad: $edad a&ntilde;os ($paciente->{sexo})</span>
                    </div>

                    <!-- Selector de Dentición (Permanente vs Temporal) -->
                    <div class="mb-3 odonto-dentition-toggle-wrap">
                        <button type="button" class="btn btn-xs rounded-pill flex-fill fw-bold py-1 btn-dentition-toggle active" id="btn-dentition-perm" onclick="setDentitionType('PERMANENT')">
                            <i class="bi bi-grid-3x3-gap-fill me-1"></i>Permanente (32)
                        </button>
                        <button type="button" class="btn btn-xs rounded-pill flex-fill fw-bold py-1 btn-dentition-toggle" id="btn-dentition-temp" onclick="setDentitionType('TEMPORARY')">
                            <i class="bi bi-stars me-1"></i>Temporal (20)
                        </button>
                    </div>

                    <!-- Input de Alias en Sidebar -->
                    <div class="mb-2">
                        <label for="odonto-alias-sidebar" class="small fw-black text-secondary text-uppercase d-block mb-1" style="font-size: 0.72rem;">
                            <i class="bi bi-bookmark-star-fill text-warning me-1"></i>Nombre / Alias del Estudio:
                        </label>
                        <input type="text" id="odonto-alias-sidebar" class="form-control form-control-sm rounded-3 fw-bold odonto-sidebar-input" value="$odonto_alias" placeholder="Ej: Diagnóstico Inicial, Plan 2026">
                    </div>

                    <!-- Estado del Odontograma -->
                    <div class="d-flex justify-content-between align-items-center">
                        <span class="small fw-bold text-secondary" style="font-size: 0.75rem;">Estado Clínico:</span>
                        <select id="odonto-estado-sidebar" class="form-select form-select-sm rounded-pill fw-bold odonto-sidebar-input" style="width: 140px; font-size: 0.75rem;">
                            <option value="En Proceso">En Proceso</option>
                            <option value="Presupuestado">Presupuestado</option>
                            <option value="Completado">Completado</option>
                            <option value="Borrador">Borrador</option>
                        </select>
                    </div>
                </div>

                <!-- Resumen Presupuestario -->
                <div class="p-3 border-bottom" style="border-color: #e2e8f0 !important;">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="small fw-black text-secondary text-uppercase">Plan de Tratamiento</span>
                        <span class="badge bg-danger text-white rounded-pill fw-bold" id="badge-total-pending">0 Pendientes</span>
                    </div>
                    <div class="odonto-budget-card-light mb-2">
                        <span class="small text-danger-emphasis fw-bold d-block">Importe Total Estimado</span>
                        <h3 class="m-0" id="odonto-sidebar-price">\$0.00</h3>
                        <span class="badge rounded-pill mt-2" id="odonto-sidebar-count" style="background: var(--odonto-teal-light); color: var(--odonto-teal-dark); border: 1px solid var(--odonto-teal);">0 Procedimientos</span>
                    </div>
                </div>

                <!-- Lista de Hallazgos en Tiempo Real -->
                <div class="p-3 flex-grow-1 overflow-auto border-bottom" style="border-color: #e2e8f0 !important;">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="small fw-black text-secondary text-uppercase"><i class="bi bi-list-check me-1" style="color: var(--odonto-teal);"></i>Hallazgos Registrados</span>
                        <button type="button" class="btn btn-xs btn-link text-danger text-decoration-none p-0 fw-bold" onclick="clearOdontogram()" title="Limpiar todas las marcas"><i class="bi bi-trash3 me-1"></i>Limpiar</button>
                    </div>
                    <div class="table-responsive">
                        <table class="table table-sm align-middle mb-0 odonto-findings-table">
                            <thead>
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
                    <label for="odontograma-notas" class="small fw-black text-secondary text-uppercase mb-2 d-block">
                        <i class="bi bi-pencil-square me-1" style="color: var(--odonto-teal);"></i>Notas Clínicas del Odontograma
                    </label>
                    <textarea class="form-control form-control-sm rounded-3 odonto-sidebar-input" id="odontograma-notas" rows="3" placeholder="Observaciones de oclusión, periodonto, encías...">$notas_guardadas</textarea>
                </div>
            </aside>

            <!-- ESCENARIO CENTRAL DEL ODONTOGRAMA (CANVAS COMPLETO) -->
            <main class="odonto-stage-main">

                <!-- CONTENEDOR DEL ODONTOGRAMA VECTORIAL 2D (4 CUADRANTES) -->
                <div class="w-100 d-flex justify-content-center">
                    <div id="odontograma-svg-container" class="text-center" data-patient-id="$paciente->{id_paciente}" style="min-width: 900px; max-width: 1280px;">
                        <div class="py-5 text-muted opacity-50">
                            <div class="spinner-border text-primary mb-3"></div><br>
                            Inicializando OSOdontograma Vectorial...
                        </div>
                    </div>
                </div>

                <!-- LEYENDA CLÍNICA AL PIE (SANITIZADA CLÍNICA CLARA - IMAGEN 1) -->
                <div class="odonto-legend mt-4">
                    <div class="odonto-legend-item">
                        <span class="odonto-legend-color" style="background: #FF3B30;"></span>
                        <span class="small fw-bold">Caries / Patología</span>
                    </div>
                    <div class="odonto-legend-item">
                        <span class="odonto-legend-color" style="background: #00A896;"></span>
                        <span class="small fw-bold">Restauración Adaptada</span>
                    </div>
                    <div class="odonto-legend-item">
                        <span class="odonto-legend-color" style="background: #FF9500;"></span>
                        <span class="small fw-bold">Restauración Desadaptada</span>
                    </div>
                    <div class="odonto-legend-item">
                        <span class="badge bg-light text-secondary rounded-pill px-2 py-0 border">✕</span>
                        <span class="small fw-bold">Diente Ausente</span>
                    </div>
                    <div class="odonto-legend-item">
                        <span class="odonto-legend-color" style="background: #FFFFFF; border: 1.5px solid #cbd5e1;"></span>
                        <span class="small fw-bold">Sin alteraciones / Sano</span>
                    </div>
                </div>

            </main>
        </div>
    </div>

    <!-- MODAL CLÍNICO CONTEXTUAL CLARO (PREVIEW 3D/2D + CATEGORÍAS SAAS - IMAGEN 2) -->
    <div class="modal fade" id="modalOdontoClinico" tabindex="-1" aria-labelledby="modalOdontoClinicoLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered modal-xl modal-dialog-scrollable">
            <div class="modal-content border-0 shadow-2xl rounded-4 odonto-modal-light">
                <div class="modal-header border-bottom py-3 px-4 d-flex justify-content-between align-items-center" style="border-color: #e2e8f0 !important;">
                    <div class="d-flex align-items-center gap-3">
                        <span class="badge rounded-pill px-3 py-2 fw-black fs-6 odonto-modal-badge" id="odonto-modal-tooth-badge">#16</span>
                        <div>
                            <h5 class="fw-black mb-0 text-dark" id="odonto-modal-tooth-title">Primer Molar Superior Derecho</h5>
                            <span class="small fw-bold" id="odonto-modal-surface-label" style="color: #0d9488;"><i class="bi bi-geo-alt-fill me-1"></i>Zona activa: Superficie <strong class="text-uppercase text-dark">MESIAL</strong></span>
                        </div>
                    </div>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
                </div>
                <div class="modal-body p-4">
                    <div class="row g-4">
                        <!-- COLUMNA IZQUIERDA: PREVISUALIZACIÓN ANATÓMICA (3D UPRIGHT + 2D CORONA OCLUSAL) -->
                        <div class="col-lg-4">
                            <div class="odonto-modal-tooth-showcase">
                                <!-- Pieza Dental 3D Vertical -->
                                <div class="mb-3">
                                    <div class="d-flex align-items-center justify-content-between mb-2">
                                        <span class="small fw-black text-uppercase" style="font-size: 0.72rem; color: #0d9488;">
                                            <i class="bi bi-badge-3d me-1"></i>Vista Sagital / 3D
                                        </span>
                                        <span class="badge rounded-pill" style="background: #ccfbf1; color: #0f766e; font-size: 0.65rem; border: 1px solid #14b8a6;">Porcelana HD</span>
                                    </div>
                                    <div class="odonto-modal-upright-wrap">
                                        <img id="odonto-modal-tooth-img" src="../img/teeth/tooth_upright_16.png" class="odonto-modal-upright-img" alt="Pieza Dental 3D" onerror="if(!this.dataset.fallback){this.dataset.fallback=1; this.src='../img/teeth/tooth_upright_16.png';}">
                                    </div>
                                </div>

                                <!-- Vista Oclusal / Corona 2D y Superficie Activa -->
                                <div>
                                    <div class="d-flex align-items-center justify-content-between mb-2">
                                        <span class="small fw-black text-uppercase" style="font-size: 0.72rem; color: #0d9488;">
                                            <i class="bi bi-circle-square me-1"></i>Corona Oclusal 2D
                                        </span>
                                        <span class="badge rounded-pill" style="background: #ccfbf1; color: #0f766e; font-size: 0.65rem; border: 1px solid #14b8a6;">Cara Activa</span>
                                    </div>
                                    <div class="odonto-modal-crown-wrap w-100">
                                        <img id="odonto-modal-crown-img" src="../img/teeth/crown_16.png" class="odonto-modal-crown-img mb-2" alt="Corona Oclusal 2D" onerror="if(!this.dataset.fallback){this.dataset.fallback=1; this.src='../img/teeth/crown_molar.png';}">
                                        <span class="odonto-surface-indicator-badge">
                                            <i class="bi bi-bullseye me-1"></i>Superficie: <strong id="odonto-modal-surface-name" class="text-dark text-uppercase">OCLUSAL</strong>
                                        </span>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- COLUMNA DERECHA: SELECCIÓN CLÍNICA Y PROCEDIMIENTO (IMAGEN 2) -->
                        <div class="col-lg-8">
                            <!-- Nivel 1: Alcance -->
                            <div class="mb-4">
                                <label class="small text-dark fw-bold text-uppercase mb-2 d-block">1. Alcance del Diagnóstico</label>
                                <div class="btn-group w-100 odonto-scope-btn-group" role="group" id="odonto-scope-group">
                                    <input type="radio" class="btn-check" name="odonto-scope" id="scope-surface" value="SURFACE" checked onchange="handleScopeChange('SURFACE')">
                                    <label class="btn btn-sm rounded-pill fw-bold" for="scope-surface" id="label-scope-surface"><i class="bi bi-bounding-box me-1"></i>Superficie Seleccionada</label>

                                    <input type="radio" class="btn-check" name="odonto-scope" id="scope-crown" value="CROWN" onchange="handleScopeChange('CROWN')">
                                    <label class="btn btn-sm rounded-pill fw-bold" for="scope-crown"><i class="bi bi-circle-square me-1"></i>Toda la Corona (5 caras)</label>

                                    <input type="radio" class="btn-check" name="odonto-scope" id="scope-tooth" value="TOOTH" onchange="handleScopeChange('TOOTH')">
                                    <label class="btn btn-sm rounded-pill fw-bold" for="scope-tooth"><i class="bi bi-x-circle me-1"></i>Pieza Completa (Ausente)</label>
                                </div>
                            </div>

                            <!-- Nivel 2: Selector en Cascada por Categorías (3 Grupos SaaS) -->
                            <div class="mb-4">
                                <label class="small text-dark fw-bold text-uppercase mb-2 d-block">2. Categoría y Condición Clínica</label>
                                <ul class="nav nav-pills nav-fill mb-3 odonto-category-pills" id="pills-odonto-cat" role="tablist">
                                    <li class="nav-item" role="presentation">
                                        <button class="nav-link active fw-bold text-danger" id="pills-pending-tab" data-bs-toggle="pill" data-bs-target="#pills-pending" type="button" role="tab"><i class="bi bi-exclamation-octagon-fill me-1"></i>🔴 Patología / Hallazgo</button>
                                    </li>
                                    <li class="nav-item" role="presentation">
                                        <button class="nav-link fw-bold text-primary" id="pills-existing-tab" data-bs-toggle="pill" data-bs-target="#pills-existing" type="button" role="tab"><i class="bi bi-shield-shaded me-1"></i>🔵 Tratamiento / Restauración</button>
                                    </li>
                                    <li class="nav-item" role="presentation">
                                        <button class="nav-link fw-bold text-success" id="pills-healthy-tab" data-bs-toggle="pill" data-bs-target="#pills-healthy" type="button" role="tab"><i class="bi bi-check-circle-fill me-1"></i>🟢 Estado Normal</button>
                                    </li>
                                </ul>

                                <div class="tab-content" id="pills-odonto-tabContent">
                                    <!-- TAB 1: PENDIENTES / PATOLOGÍAS -->
                                    <div class="tab-pane fade show active" id="pills-pending" role="tabpanel">
                                        <div class="row g-2" id="grid-conditions-pending">
                                            <!-- Inyectado dinámicamente por JS -->
                                        </div>
                                    </div>

                                    <!-- TAB 2: TRATAMIENTOS / RESTAURACIONES -->
                                    <div class="tab-pane fade" id="pills-existing" role="tabpanel">
                                        <div class="row g-2" id="grid-conditions-existing">
                                            <!-- Inyectado dinámicamente por JS -->
                                        </div>
                                    </div>

                                    <!-- TAB 3: SANO / NORMAL -->
                                    <div class="tab-pane fade" id="pills-healthy" role="tabpanel">
                                        <div class="row g-2 mb-3" id="grid-conditions-healthy">
                                            <!-- Inyectado dinámicamente por JS -->
                                        </div>
                                        <div class="p-3 rounded-4 text-center border bg-light" style="border-color: var(--odonto-card-border) !important;">
                                            <i class="bi bi-shield-check text-success display-6 d-block mb-1"></i>
                                            <h6 class="fw-black text-dark mb-1">Restaurar a Estado Sano</h6>
                                            <p class="small text-muted mb-2">Se removerán las marcas patológicas o restauraciones de la zona o diente seleccionado.</p>
                                            <button type="button" class="btn btn-sm btn-outline-success rounded-pill px-4 fw-bold" onclick="selectOdontoCondition('HEALTHY')">
                                                <i class="bi bi-check-lg me-1"></i>Marcar Sano / Sin Hallazgo
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Nivel 3: Resumen y Precio (Imagen 2) -->
                            <div class="p-3 rounded-4 border d-flex justify-content-between align-items-center flex-wrap gap-2 odonto-modal-summary-box">
                                <div>
                                    <span class="small text-muted fw-bold d-block">Resumen de Selección:</span>
                                    <span class="fw-bold text-dark fs-6" id="odonto-summary-condition">Caries Dental (Activa)</span>
                                    <span class="badge rounded-pill px-2 py-1 ms-2" id="odonto-summary-scope" style="background: #ccfbf1; color: #0f766e; border: 1px solid #14b8a6;">Superficie Mesial</span>
                                </div>
                                <div class="text-end">
                                    <span class="small text-muted fw-bold d-block">Importe Sugerido</span>
                                    <span class="h4 fw-black text-dark m-0 font-monospace" id="odonto-summary-price">\$850.00 MXN</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer border-top py-3 px-4 d-flex justify-content-between" style="border-color: #e2e8f0 !important;">
                    <button type="button" class="btn btn-outline-secondary rounded-pill px-4 fw-bold" data-bs-dismiss="modal">Cancelar</button>
                    <button type="button" class="btn btn-apply-odonto" onclick="confirmApplyClinicalCondition()">
                        <i class="bi bi-check2-circle me-1"></i>Aplicar al Odontograma
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- VISTA PREVIA PERSONALIZADA DE IMPRESIÓN (3/4 MAPA + 1/4 DATOS OFFCANVAS) -->
    <div id="modalPrintPreviewOdonto">
        <!-- Barra Superior de Control (No se imprime) -->
        <div class="odonto-print-toolbar d-print-none">
            <div class="d-flex align-items-center gap-3">
                <button type="button" class="btn btn-outline-light rounded-pill px-4 fw-bold btn-sm d-flex align-items-center gap-2" onclick="cerrarVistaImpresionOdonto()">
                    <i class="bi bi-arrow-left"></i>
                    <span>Volver al Visor</span>
                </button>
                <div class="vr bg-secondary mx-1"></div>
                <div class="text-white">
                    <span class="fw-bold d-block lh-1">Vista Previa de Impresión Fiel</span>
                    <small class="text-white-50">Odontograma Clínico FDI / ISO 3950 &bull; $paciente->{nombre}</small>
                </div>
            </div>
            <div class="d-flex align-items-center gap-2">
                <button type="button" class="btn btn-success rounded-pill px-4 fw-bold btn-sm d-flex align-items-center gap-2 shadow-sm" onclick="ejecutarImpresionOdonto()" style="background: linear-gradient(135deg, #10b981, #06b6d4); border: 0;">
                    <i class="bi bi-printer-fill fs-6"></i>
                    <span>Imprimir Documento</span>
                </button>
            </div>
        </div>

        <!-- Hoja de Impresión Fiel -->
        <div class="odonto-print-sheet" id="odonto-print-sheet">
            <!-- Encabezado Clínico Institucional -->
            <div class="odonto-print-header">
                <div class="d-flex justify-content-between align-items-start flex-wrap gap-3">
                    <div class="d-flex align-items-center gap-3">
                        @{[ $negocio_logo ? qq{<img src="../dat/logos/$negocio_logo" alt="Logo" style="max-height: 52px; object-fit: contain;">} : qq{<div class="p-2 rounded bg-primary text-white d-flex align-items-center justify-content-center" style="width: 48px; height: 48px;"><i class="bi bi-hospital fs-4"></i></div>} ]}
                        <div>
                            <h4 class="fw-black mb-0 text-dark">$negocio_nombre</h4>
                            <div class="small text-secondary">
                                @{[ $negocio_clues ? "<span>CLUES: <strong>$negocio_clues</strong></span> &bull; " : "" ]}
                                @{[ $negocio_rfc ? "<span>RFC: <strong>$negocio_rfc</strong></span> &bull; " : "" ]}
                                @{[ $negocio_tel ? "<span>Tel: $negocio_tel</span>" : "" ]}
                            </div>
                            @{[ $negocio_dir ? qq{<div class="small text-muted">$negocio_dir</div>} : "" ]}
                        </div>
                    </div>
                    <div class="text-end">
                        <span class="badge bg-dark text-white rounded-pill px-3 py-1 mb-1 fw-bold">ODONTOGRAMA Y PLAN DE TRATAMIENTO</span>
                        <div class="small text-muted"><strong>Fecha y Hora:</strong> $fecha_actual</div>
                        <div class="small text-muted"><strong>Folio de Estudio:</strong> <code class="text-primary fw-bold" id="print-odonto-id">$id_odonto_activo</code></div>
                        <div class="small text-muted"><strong>Estado:</strong> <span class="fw-bold" id="print-odonto-estado">$odonto_estado</span></div>
                    </div>
                </div>

                <!-- Ficha del Paciente y Estudio -->
                <div class="mt-3 p-2 rounded-3 bg-light border d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <div>
                        <span class="small text-muted d-block text-uppercase fw-bold" style="font-size: 0.68rem;">Paciente:</span>
                        <strong class="text-dark fs-6">$paciente->{nombre}</strong>
                        <span class="text-secondary small ms-2">($edad a&ntilde;os, $paciente->{sexo})</span>
                    </div>
                    <div>
                        <span class="small text-muted d-block text-uppercase fw-bold" style="font-size: 0.68rem;">Identificadores:</span>
                        <span class="small text-muted">CURP: <strong>$paciente->{curp}</strong> | Correo: <strong>$paciente->{correo}</strong></span>
                    </div>
                    <div>
                        <span class="small text-muted d-block text-uppercase fw-bold" style="font-size: 0.68rem;">Nombre del Estudio:</span>
                        <span class="badge bg-secondary-subtle text-dark border fw-bold" id="print-odonto-alias">$odonto_alias</span>
                    </div>
                </div>
            </div>

            <!-- Cuerpo Dividido: 3/4 Mapa Odontograma + 1/4 Ficha Offcanvas -->
            <div class="odonto-print-split-row">
                <!-- Columna Izquierda: 3/4 (75% ancho) - Mapa Anatómico Dental -->
                <div class="odonto-print-map-col">
                    <div class="d-flex justify-content-between align-items-center mb-2 border-bottom pb-1">
                        <span class="small fw-black text-uppercase text-dark">
                            <i class="bi bi-grid-3x3-gap-fill text-primary me-1"></i>Mapa Dental Anatómico (Arcadas Superior e Inferior)
                        </span>
                        <span class="badge bg-primary-subtle text-primary border border-primary-subtle rounded-pill small">Sistema FDI / ISO 3950</span>
                    </div>
                    <!-- Contenedor donde se clona el odontograma vectorizado -->
                    <div id="print-odonto-map-container" class="d-flex justify-content-center py-2" style="overflow: hidden;">
                        <!-- Inyectado dinámicamente -->
                    </div>

                    <!-- Leyenda Clínica en Impresión -->
                    <div class="d-flex justify-content-center align-items-center gap-3 pt-2 mt-2 border-top small text-muted flex-wrap">
                        <div class="d-flex align-items-center gap-1">
                            <span style="display:inline-block; width:12px; height:12px; border-radius:3px; background:#FF3B30;"></span>
                            <span style="font-size:0.75rem;">Patología / Caries</span>
                        </div>
                        <div class="d-flex align-items-center gap-1">
                            <span style="display:inline-block; width:12px; height:12px; border-radius:3px; background:#007AFF;"></span>
                            <span style="font-size:0.75rem;">Restauración Adaptada</span>
                        </div>
                        <div class="d-flex align-items-center gap-1">
                            <span style="display:inline-block; width:12px; height:12px; border-radius:3px; background:#FF9500;"></span>
                            <span style="font-size:0.75rem;">Restauración Desadaptada</span>
                        </div>
                        <div class="d-flex align-items-center gap-1">
                            <span class="badge bg-secondary-subtle text-secondary border px-1" style="font-size:0.65rem;">✕</span>
                            <span style="font-size:0.75rem;">Diente Ausente</span>
                        </div>
                    </div>
                </div>

                <!-- Columna Derecha: 1/4 (25% ancho) - Resumen Offcanvas, Presupuesto y Hallazgos -->
                <div class="odonto-print-side-col">
                    <!-- Resumen Presupuestal -->
                    <div class="p-2 mb-2 rounded bg-white border text-center">
                        <span class="small text-muted fw-bold d-block text-uppercase" style="font-size: 0.68rem;">Presupuesto Estimado</span>
                        <h4 class="fw-black text-danger m-0 font-monospace" id="print-budget-price">\$0.00</h4>
                        <span class="badge bg-success-subtle text-success rounded-pill mt-1" id="print-budget-count" style="font-size:0.68rem;">0 Procedimientos</span>
                    </div>

                    <!-- Tabla de Hallazgos Fiel -->
                    <div class="mb-2">
                        <span class="small fw-black text-uppercase text-dark d-block mb-1" style="font-size: 0.7rem;">
                            <i class="bi bi-list-check text-primary me-1"></i>Detalle de Hallazgos
                        </span>
                        <div class="table-responsive" style="max-height: 280px; overflow-y: auto;">
                            <table class="table table-sm table-striped align-middle mb-0" style="font-size: 0.72rem;">
                                <thead class="table-light">
                                    <tr>
                                        <th>Pieza</th>
                                        <th>Cara</th>
                                        <th>Diagnóstico</th>
                                        <th class="text-end">Costo</th>
                                    </tr>
                                </thead>
                                <tbody id="print-findings-tbody">
                                    <!-- Inyectado desde sidebar -->
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Notas Clínicas -->
                    <div class="p-2 rounded bg-white border mb-3">
                        <span class="small fw-black text-uppercase text-dark d-block mb-1" style="font-size: 0.68rem;">
                            <i class="bi bi-journal-text text-primary me-1"></i>Observaciones Clínicas:
                        </span>
                        <p class="small text-muted m-0" id="print-clinical-notes" style="font-size: 0.72rem; min-height: 48px; white-space: pre-wrap;">$notas_guardadas</p>
                    </div>

                    <!-- Firma del Odontólogo -->
                    <div class="text-center pt-3 mt-3 border-top">
                        <div style="border-bottom: 1px dashed #64748b; width: 80%; margin: 24px auto 6px auto;"></div>
                        <strong class="d-block small text-dark">$usuario_sesion</strong>
                        <span class="small text-muted d-block" style="font-size: 0.65rem;">Odontólogo Responsable</span>
                        <span class="small text-muted d-block" style="font-size: 0.62rem;">Firma y Cédula Profesional</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL GESTIÓN DE CATÁLOGO ODONTOGRAMA (CRUD AJAX - TEMA CLARO) -->
    <!-- MODAL GESTIÓN DE CATÁLOGO ODONTOGRAMA (CRUD AJAX - TEMA CLARO CLÍNICO) -->
    <div class="modal fade" id="modalGestionCatalogoOdonto" tabindex="-1" aria-labelledby="modalGestionCatalogoOdontoLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered modal-xl modal-dialog-scrollable">
            <div class="modal-content border-0 shadow-2xl rounded-4 odonto-modal-light" style="background: #ffffff;">
                <div class="modal-header border-bottom py-3 px-4" style="border-color: #e2e8f0 !important; background: #ffffff;">
                    <div class="d-flex align-items-center gap-3">
                        <div class="rounded-circle p-2 d-flex align-items-center justify-content-center" style="background: var(--odonto-teal-light); border: 1.5px solid var(--odonto-teal); width: 40px; height: 40px;">
                            <i class="bi bi-sliders2 fs-5" style="color: var(--odonto-teal-dark);"></i>
                        </div>
                        <div>
                            <h5 class="fw-black mb-0" style="color: #083344; font-size: 1.05rem;" id="modalGestionCatalogoOdontoLabel">Gestión de Catálogo Clínico Odontológico</h5>
                            <span class="text-secondary" style="font-size: 0.75rem;">Configuración personalizada de patologías, tratamientos, aranceles base y códigos FDI</span>
                        </div>
                    </div>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
                </div>
                <div class="modal-body p-4" style="background: #ffffff;">
                    <!-- Formulario de Edición / Alta (Colapsable) -->
                    <div id="wrapperFormConceptoModal" class="d-none mb-3 p-3 rounded-4" style="background: #f8fafc; border: 1.5px solid #e2e8f0;">
                        <div class="d-flex align-items-center justify-content-between mb-3 border-bottom pb-2" style="border-color: #e2e8f0 !important;">
                            <h6 class="fw-bold mb-0" style="color: #083344; font-size: 0.85rem;" id="tituloFormConceptoModal"><i class="bi bi-pencil-square me-2" style="color: var(--odonto-teal);"></i>Editar Concepto</h6>
                            <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill px-3" style="font-size: 0.75rem;" onclick="cancelarFormularioConceptoModal()">Cancelar</button>
                        </div>
                        <form id="formConceptoModalOdonto" onsubmit="guardarConceptoModal(event)">
                            <input type="hidden" id="modal_form_id" name="id" value="">
                            <div class="row g-2">
                                <div class="col-md-3">
                                    <label class="form-label fw-bold mb-1" style="font-size: 0.72rem; color: #475569;">Código FDI/ISO</label>
                                    <input type="text" class="form-control form-control-sm bg-white border-secondary-subtle text-uppercase fw-bold" style="font-size: 0.78rem; color: #0f172a;" id="modal_form_code" name="code" required placeholder="EJ: RESINA_3D">
                                </div>
                                <div class="col-md-5">
                                    <label class="form-label fw-bold mb-1" style="font-size: 0.72rem; color: #475569;">Nombre Clínico / Procedimiento</label>
                                    <input type="text" class="form-control form-control-sm bg-white border-secondary-subtle" style="font-size: 0.78rem; color: #0f172a;" id="modal_form_nombre" name="nombre" required placeholder="Ej: Resina Fotocurable">
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label fw-bold mb-1" style="font-size: 0.72rem; color: #475569;">Grupo SaaS</label>
                                    <select class="form-select form-select-sm bg-white border-secondary-subtle" style="font-size: 0.78rem; color: #0f172a;" id="modal_form_grupo" name="grupo" required onchange="ajustarGrupoModal(this.value)">
                                        <option value="PATHOLOGY">Patología / Hallazgo</option>
                                        <option value="RESTORATION">Tratamiento / Restauración</option>
                                        <option value="NORMAL">Estado Normal</option>
                                    </select>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label fw-bold mb-1" style="font-size: 0.72rem; color: #475569;">Categoría</label>
                                    <select class="form-select form-select-sm bg-white border-secondary-subtle" style="font-size: 0.78rem; color: #0f172a;" id="modal_form_categoria" name="categoria" required>
                                        <option value="PENDING">Pendiente (Presupuesto)</option>
                                        <option value="EXISTING">Existente (Realizado)</option>
                                        <option value="HEALTHY">Sano (Neutro)</option>
                                    </select>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label fw-bold mb-1" style="font-size: 0.72rem; color: #475569;">Subestado Técnico</label>
                                    <select class="form-select form-select-sm bg-white border-secondary-subtle" style="font-size: 0.78rem; color: #0f172a;" id="modal_form_substatus" name="substatus">
                                        <option value="ACTIVE">Activa / Presente</option>
                                        <option value="ADAPTED">Adaptada / Buena</option>
                                        <option value="DEFECTIVE">Desadaptada / Defectuosa</option>
                                        <option value="TEMPORARY">Provisional / Temporal</option>
                                        <option value="PONTIC">Póntico de Puente</option>
                                        <option value="ABSENT">Ausente</option>
                                        <option value="HEALTHY">Sano</option>
                                    </select>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label fw-bold mb-1" style="font-size: 0.72rem; color: #475569;">Precio Ref. (MXN)</label>
                                    <div class="input-group input-group-sm">
                                        <span class="input-group-text bg-light border-secondary-subtle" style="font-size: 0.78rem; color: #475569;">\$</span>
                                        <input type="number" step="0.01" min="0" class="form-control form-control-sm bg-white border-secondary-subtle fw-bold" style="font-size: 0.78rem; color: #0f172a;" id="modal_form_precio" name="precio" value="0.00" required>
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label fw-bold mb-1" style="font-size: 0.72rem; color: #475569;">Color Odontograma</label>
                                    <div class="d-flex align-items-center gap-2">
                                        <input type="color" class="form-control form-control-color p-0 bg-transparent border-0" id="modal_form_color" name="color_hex" value="#FF3B30">
                                        <input type="text" class="form-control form-control-sm bg-white border-secondary-subtle text-uppercase font-monospace" style="font-size: 0.78rem; color: #0f172a;" id="modal_form_color_text" value="#FF3B30" onchange="document.getElementById('modal_form_color').value = this.value">
                                    </div>
                                </div>
                                <div class="col-md-9">
                                    <label class="form-label fw-bold mb-1" style="font-size: 0.72rem; color: #475569;">Ícono Bootstrap</label>
                                    <input type="text" class="form-control form-control-sm bg-white border-secondary-subtle" style="font-size: 0.78rem; color: #0f172a;" id="modal_form_icono" name="icono" value="bi-circle-fill text-danger">
                                </div>
                                <div class="col-md-3 d-flex align-items-end">
                                    <button type="submit" class="btn btn-sm btn-apply-odonto w-100 rounded-pill fw-bold shadow-sm" style="font-size: 0.78rem;">
                                        <i class="bi bi-save me-1"></i> Guardar Concepto
                                    </button>
                                </div>
                            </div>
                        </form>
                    </div>

                    <!-- Barra de Filtros y Búsqueda -->
                    <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-3">
                        <div class="btn-group btn-group-sm p-1 rounded-pill border" style="background: #f8fafc; border-color: #e2e8f0 !important;" role="group">
                            <button type="button" class="btn btn-sm rounded-pill px-3 active fw-bold btn-modal-filter" style="background: var(--odonto-teal); color: #ffffff; font-size: 0.75rem;" data-filter="ALL" onclick="filtrarCatalogoModal('ALL', this)">Todos</button>
                            <button type="button" class="btn btn-sm rounded-pill px-3 fw-bold btn-modal-filter" style="background: transparent; color: #475569; font-size: 0.75rem;" data-filter="PATHOLOGY" onclick="filtrarCatalogoModal('PATHOLOGY', this)">Patologías</button>
                            <button type="button" class="btn btn-sm rounded-pill px-3 fw-bold btn-modal-filter" style="background: transparent; color: #475569; font-size: 0.75rem;" data-filter="RESTORATION" onclick="filtrarCatalogoModal('RESTORATION', this)">Restauraciones</button>
                            <button type="button" class="btn btn-sm rounded-pill px-3 fw-bold btn-modal-filter" style="background: transparent; color: #475569; font-size: 0.75rem;" data-filter="NORMAL" onclick="filtrarCatalogoModal('NORMAL', this)">Normales</button>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                            <div class="position-relative">
                                <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-3 text-secondary" style="font-size: 0.75rem;"></i>
                                <input type="text" class="form-control form-control-sm rounded-pill bg-white border-secondary-subtle ps-4 pe-3" style="color: #0f172a; font-size: 0.78rem; width: 220px;" id="inputBuscarModalCatalogo" placeholder="Buscar concepto..." oninput="buscarConceptoModal(this.value)">
                            </div>
                            <button type="button" class="btn btn-sm rounded-pill px-3 fw-bold text-nowrap" style="background: #f0fdfa; color: var(--odonto-teal-dark); border: 1.5px solid var(--odonto-teal); font-size: 0.78rem;" onclick="mostrarFormularioNuevoModal()">
                                <i class="bi bi-plus-circle-fill me-1" style="color: var(--odonto-teal);"></i>+ Nuevo Concepto
                            </button>
                        </div>
                    </div>

                    <!-- Lista / Tabla de Conceptos -->
                    <div class="table-responsive rounded-3 border" style="max-height: 480px; overflow-y: auto; border-color: #e2e8f0 !important;">
                        <table class="table table-hover align-middle mb-0">
                            <thead style="position: sticky; top: 0; z-index: 2; background: #f8fafc; border-bottom: 2px solid #e2e8f0;">
                                <tr style="font-size: 0.70rem; font-weight: 800; color: #475569; letter-spacing: 0.5px;">
                                    <th style="width: 55px; background: #f8fafc;" class="py-2.5 px-3">ID</th>
                                    <th style="background: #f8fafc;" class="py-2.5 px-3">CÓDIGO</th>
                                    <th style="background: #f8fafc;" class="py-2.5 px-3">CONCEPTO CLÍNICO</th>
                                    <th style="background: #f8fafc;" class="py-2.5 px-3">GRUPO</th>
                                    <th style="background: #f8fafc;" class="py-2.5 px-3">CATEGORÍA</th>
                                    <th style="background: #f8fafc;" class="py-2.5 px-3">COLOR</th>
                                    <th style="background: #f8fafc;" class="py-2.5 px-3">PRECIO REF.</th>
                                    <th style="width: 85px; background: #f8fafc;" class="py-2.5 px-3 text-end">ACCIÓN</th>
                                </tr>
                            </thead>
                            <tbody id="tbodyModalCatalogoOdonto">
                                <tr><td colspan="8" class="text-center py-4 text-secondary small"><div class="spinner-border spinner-border-sm text-teal me-2"></div>Cargando catálogo...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
                <div class="modal-footer border-top py-2 px-4 d-flex justify-content-between" style="border-color: #e2e8f0 !important; background: #f8fafc;">
                    <span class="text-secondary" style="font-size: 0.75rem;" id="infoTotalModalCatalogo"><i class="bi bi-info-circle me-1"></i>Los cambios se sincronizan en vivo con el visor clínico.</span>
                    <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill px-4 fw-bold" style="font-size: 0.78rem;" data-bs-dismiss="modal">Cerrar</button>
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
        window.ID_PACIENTE   = '$paciente->{id_paciente}';
        window.ID_ODONTO     = '$id_odonto_activo';
        window.ODONTO_ALIAS  = '$odonto_alias';
        window.ODONTO_ESTADO = '$odonto_estado';
        window.CLINICA_INFO  = {
            nombre: '$negocio_nombre',
            dir: '$negocio_dir',
            tel: '$negocio_tel',
            rfc: '$negocio_rfc',
            clues: '$negocio_clues',
            fechaHora: '$fecha_actual',
            medico: '$usuario_sesion'
        };
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

        // Sincronizar inputs de Alias entre Cabecera y Barra Lateral
        document.addEventListener('DOMContentLoaded', () => {
            const aHead = document.getElementById('odonto-alias-input');
            const aSide = document.getElementById('odonto-alias-sidebar');
            if (aHead && aSide) {
                aHead.addEventListener('input', function() { aSide.value = this.value; window.ODONTO_ALIAS = this.value; });
                aSide.addEventListener('input', function() { aHead.value = this.value; window.ODONTO_ALIAS = this.value; });
            }
        });

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
                if (tData.absent || tData.status === 'ABSENT') {
                    rowsHtml += `
                        <tr>
                            <td><span class="badge rounded-pill fw-bold" style="background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1;">#${toothId}</span></td>
                            <td><span class="text-muted small">Pieza</span></td>
                            <td><span class="badge bg-secondary-subtle text-secondary border">Ausente ✕</span></td>
                            <td class="text-end text-muted">-</td>
                        </tr>
                    `;
                }

                if (tData.surfaces) {
                    Object.keys(tData.surfaces).forEach(surf => {
                        const sData = tData.surfaces[surf];
                        const isPending = sData.state === 'PENDING_TREATMENT';
                        const badgeClass = isPending ? 'bg-danger text-white' : 'bg-primary text-white';
                        const price = parseFloat(sData.price) || 0;
                        if (isPending) {
                            total += price;
                            pendingCount++;
                        }

                        rowsHtml += `
                            <tr>
                                <td><span class="badge rounded-pill fw-bold" style="background: #ccfbf1; color: #0f766e; border: 1px solid #14b8a6;">#${toothId}</span></td>
                                <td><span class="small fw-semibold text-uppercase text-secondary">${surf}</span></td>
                                <td><span class="badge ${badgeClass}">${sData.code || 'Condición'}</span></td>
                                <td class="text-end fw-bold font-monospace ${isPending ? 'text-danger' : 'text-primary'}">$${price.toFixed(2)}</td>
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
        window.refreshSidebarFindings = refreshSidebarFindings;

        // Sobrescribir o enganchar al recálculo
        const originalRecalculate = window.recalculateFinancialTotal;
        window.recalculateFinancialTotal = function() {
            if (typeof originalRecalculate === 'function') {
                originalRecalculate();
            }
            refreshSidebarFindings();
        };

        // Guardar Odontograma en Servidor (Persistencia Atómica Canónica con Alias)
        window.saveOdontogramaToServer = function() {
            const patientId = window.ID_PACIENTE;
            const idOdonto  = window.ID_ODONTO || '';
            const alias     = document.getElementById('odonto-alias-sidebar')?.value || document.getElementById('odonto-alias-input')?.value || window.ODONTO_ALIAS || 'Diagnóstico Inicial';
            const estado    = document.getElementById('odonto-estado-sidebar')?.value || window.ODONTO_ESTADO || 'En Proceso';
            const notas     = document.getElementById('odontograma-notas')?.value || '';

            if (!patientId) {
                Swal.fire('Error', 'ID de paciente no definido.', 'error');
                return;
            }

            Swal.fire({
                title: 'Sincronizando Odontograma...',
                text: `Guardando "${alias}" atómicamente en OSPulso Cloud`,
                allowOutsideClick: false,
                didOpen: () => { Swal.showLoading(); }
            });

            const payload = new URLSearchParams();
            payload.append('accion', 'save');
            payload.append('id_paciente', patientId);
            payload.append('id_odonto', idOdonto);
            payload.append('alias', alias);
            payload.append('estado', estado);
            payload.append('notas', notas);
            payload.append('financialTotalPending', window.odontogramState.financialTotalPending || 0);
            payload.append('data', JSON.stringify(window.odontogramState));

            axios.post('../api/odontograma_api.pl', payload)
                .then(res => {
                    if (res.data && res.data.ok) {
                        if (res.data.id_odonto) window.ID_ODONTO = res.data.id_odonto;
                        Swal.fire({
                            icon: 'success',
                            title: 'Odontograma Guardado',
                            text: `El estudio "${alias}" ha sido sincronizado con éxito.`,
                            timer: 2000,
                            showConfirmButton: false
                        });
                    } else {
                        Swal.fire('Error', res.data?.error || res.data?.msg || 'No se pudo guardar el odontograma', 'error');
                    }
                })
                .catch(err => {
                    console.error('Error al guardar odontograma:', err);
                    Swal.fire('Error', 'Fallo de conexión al servidor.', 'error');
                });
        };

        // Cargar Odontograma desde Servidor (Soporte Dual: JSON Canónico y Tabla Dat)
        window.loadOdontogramaFromServer = function(patientId, idOdonto) {
            if (!patientId) return;
            idOdonto = idOdonto || window.ID_ODONTO || '';

            axios.get(`../api/odontograma_api.pl?accion=get&id_paciente=${encodeURIComponent(patientId)}&id_odonto=${encodeURIComponent(idOdonto)}`)
                .then(res => {
                    if (res.data && res.data.ok && res.data.data) {
                        const data = res.data.data;
                        if (data.id_odonto) window.ID_ODONTO = data.id_odonto;
                        if (data.alias) {
                            window.ODONTO_ALIAS = data.alias;
                            const aH = document.getElementById('odonto-alias-input');
                            const aS = document.getElementById('odonto-alias-sidebar');
                            if (aH) aH.value = data.alias;
                            if (aS) aS.value = data.alias;
                        }
                        if (data.estado) {
                            const eS = document.getElementById('odonto-estado-sidebar');
                            if (eS) eS.value = data.estado;
                        }
                        if (data.notas && document.getElementById('odontograma-notas')) {
                            document.getElementById('odontograma-notas').value = data.notas;
                        }

                        if (typeof window.loadOdontogramState === 'function') {
                            window.loadOdontogramState(data);
                        } else {
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

        // ==========================================
        // CONTROLADOR MODAL GESTIÓN CATÁLOGO (CRUD AJAX)
        // ==========================================
        window.odontoModalCatalogData = [];
        window.odontoModalCurrentFilter = 'ALL';
        window.odontoModalSearchText = '';

        window.abrirModalGestionCatalogoOdonto = function() {
            const modalEl = document.getElementById('modalGestionCatalogoOdonto');
            if (!modalEl) return;
            cancelarFormularioConceptoModal();
            new bootstrap.Modal(modalEl).show();
            cargarTablaModalCatalogo();
        };

        window.cargarTablaModalCatalogo = async function() {
            const tbody = document.getElementById('tbodyModalCatalogoOdonto');
            if (tbody) {
                tbody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-secondary small"><div class="spinner-border spinner-border-sm text-teal me-2"></div>Cargando conceptos clínicos...</td></tr>';
            }
            try {
                const resp = await fetch('../api/catalogo_odontograma_api.pl?action=list');
                const data = await resp.json();
                if (data.status === 'success') {
                    window.odontoModalCatalogData = data.items || [];
                    if (data.catalog && typeof window.ODONTO_CATALOG !== 'undefined') {
                        Object.assign(window.ODONTO_CATALOG, data.catalog);
                    }
                    renderTablaModalCatalogo();
                } else {
                    if (tbody) tbody.innerHTML = `<tr><td colspan="8" class="text-center py-4 text-danger small">${data.message || 'Error al cargar catálogo'}</td></tr>`;
                }
            } catch (e) {
                console.error('Error cargando catalogo modal:', e);
                if (tbody) tbody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-danger small">Fallo de comunicación con el servidor</td></tr>';
            }
        };

        window.filtrarCatalogoModal = function(grupo, btn) {
            window.odontoModalCurrentFilter = grupo;
            document.querySelectorAll('.btn-modal-filter').forEach(b => {
                b.classList.remove('active');
                b.style.background = 'transparent';
                b.style.color = '#475569';
            });
            if (btn) {
                btn.classList.add('active');
                btn.style.background = 'var(--odonto-teal)';
                btn.style.color = '#ffffff';
            }
            renderTablaModalCatalogo();
        };

        window.buscarConceptoModal = function(txt) {
            window.odontoModalSearchText = (txt || '').toLowerCase().trim();
            renderTablaModalCatalogo();
        };

        function renderTablaModalCatalogo() {
            const tbody = document.getElementById('tbodyModalCatalogoOdonto');
            if (!tbody) return;

            const items = (window.odontoModalCatalogData || []).filter(item => {
                if (window.odontoModalCurrentFilter !== 'ALL' && item.grupo !== window.odontoModalCurrentFilter) {
                    return false;
                }
                if (window.odontoModalSearchText) {
                    const matchNombre = (item.nombre || '').toLowerCase().includes(window.odontoModalSearchText);
                    const matchCode = (item.code || '').toLowerCase().includes(window.odontoModalSearchText);
                    if (!matchNombre && !matchCode) return false;
                }
                return true;
            });

            const totalEl = document.getElementById('infoTotalModalCatalogo');
            if (totalEl) {
                totalEl.innerHTML = `<i class="bi bi-info-circle me-1"></i>Mostrando ${items.length} conceptos clínicos. Sincronización en vivo con el visor.`;
            }

            if (items.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-secondary" style="font-size:0.78rem;">No se encontraron conceptos clínicos con el filtro seleccionado.</td></tr>';
                return;
            }

            tbody.innerHTML = '';
            items.forEach(item => {
                const tr = document.createElement('tr');
                tr.style.fontSize = '0.78rem';
                tr.style.borderColor = '#f1f5f9';
                
                let badgeGrupo = '<span class="badge rounded-pill" style="background:#f1f5f9; color:#475569; border:1px solid #e2e8f0; font-size:0.70rem; font-weight:700;">Normal</span>';
                if (item.grupo === 'PATHOLOGY') {
                    badgeGrupo = '<span class="badge rounded-pill" style="background:#fef2f2; color:#991b1b; border:1px solid #fecdd3; font-size:0.70rem; font-weight:700;">Patología</span>';
                } else if (item.grupo === 'RESTORATION') {
                    badgeGrupo = '<span class="badge rounded-pill" style="background:#f0fdfa; color:#0f766e; border:1px solid #ccfbf1; font-size:0.70rem; font-weight:700;">Restauración</span>';
                }

                let badgeCat = '<span class="badge rounded-pill" style="background:#f8fafc; color:#64748b; border:1px solid #e2e8f0; font-size:0.70rem; font-weight:700;">Normal</span>';
                if (item.categoria === 'PENDING') {
                    badgeCat = '<span class="badge rounded-pill" style="background:#ffe4e6; color:#be123c; border:1px solid #fecdd3; font-size:0.70rem; font-weight:700;">Pendiente</span>';
                } else if (item.categoria === 'EXISTING') {
                    badgeCat = '<span class="badge rounded-pill" style="background:#e0f2fe; color:#0369a1; border:1px solid #bae6fd; font-size:0.70rem; font-weight:700;">Existente</span>';
                } else if (item.categoria === 'HEALTHY') {
                    badgeCat = '<span class="badge rounded-pill" style="background:#dcfce7; color:#15803d; border:1px solid #bbf7d0; font-size:0.70rem; font-weight:700;">Sano</span>';
                }

                tr.innerHTML = `
                    <td class="text-secondary fw-semibold py-2 px-3" style="font-size:0.72rem;">#${item.id}</td>
                    <td class="py-2 px-3"><code class="px-2 py-0.5 rounded fw-bold" style="font-size:0.72rem; background:#f1f5f9; color:#0d9488; border:1px solid #cbd5e1;">${item.code}</code></td>
                    <td class="py-2 px-3">
                        <div class="d-flex align-items-center gap-2">
                            <i class="bi ${item.icono} fs-6"></i>
                            <span class="fw-bold" style="color:#0f172a; font-size:0.80rem;">${item.nombre}</span>
                        </div>
                    </td>
                    <td class="py-2 px-3">${badgeGrupo}</td>
                    <td class="py-2 px-3">${badgeCat}</td>
                    <td class="py-2 px-3">
                        <div class="d-flex align-items-center gap-2">
                            <span style="display:inline-block; width:16px; height:16px; border-radius:4px; background:${item.color_hex}; border:1px solid #cbd5e1; box-shadow:0 1px 2px rgba(0,0,0,0.08);"></span>
                            <span class="font-monospace text-secondary" style="font-size:0.72rem;">${item.color_hex}</span>
                        </div>
                    </td>
                    <td class="py-2 px-3">
                        <span class="fw-black" style="color:#0f766e; font-size:0.82rem;">\$${parseFloat(item.precio).toFixed(2)}</span>
                    </td>
                    <td class="py-2 px-3 text-end">
                        <button type="button" class="btn btn-sm rounded-circle p-1 me-1 border-0" style="background:#f0fdfa; color:#0d9488; width:28px; height:28px;" onclick="editarConceptoModal(${item.id})" title="Editar Concepto">
                            <i class="bi bi-pencil-fill" style="font-size:0.75rem;"></i>
                        </button>
                        <button type="button" class="btn btn-sm rounded-circle p-1 border-0" style="background:#fef2f2; color:#dc2626; width:28px; height:28px;" onclick="eliminarConceptoModal(${item.id}, '${item.nombre}')" title="Desactivar">
                            <i class="bi bi-trash-fill" style="font-size:0.75rem;"></i>
                        </button>
                    </td>
                `;
                tbody.appendChild(tr);
            });
        }

        window.mostrarFormularioNuevoModal = function() {
            document.getElementById('formConceptoModalOdonto').reset();
            document.getElementById('modal_form_id').value = '';
            document.getElementById('modal_form_code').readOnly = false;
            document.getElementById('modal_form_color').value = '#FF3B30';
            document.getElementById('modal_form_color_text').value = '#FF3B30';
            document.getElementById('modal_form_precio').value = '0.00';
            document.getElementById('tituloFormConceptoModal').innerHTML = '<i class="bi bi-plus-circle me-2"></i>Nuevo Concepto Clínico';
            document.getElementById('wrapperFormConceptoModal').classList.remove('d-none');
            document.getElementById('wrapperFormConceptoModal').scrollIntoView({ behavior: 'smooth' });
        };

        window.editarConceptoModal = function(id) {
            const item = (window.odontoModalCatalogData || []).find(x => x.id == id);
            if (!item) return;

            document.getElementById('modal_form_id').value = item.id;
            document.getElementById('modal_form_code').value = item.code;
            document.getElementById('modal_form_code').readOnly = true;
            document.getElementById('modal_form_nombre').value = item.nombre;
            document.getElementById('modal_form_grupo').value = item.grupo;
            document.getElementById('modal_form_categoria').value = item.categoria;
            document.getElementById('modal_form_substatus').value = item.substatus;
            document.getElementById('modal_form_precio').value = parseFloat(item.precio).toFixed(2);
            document.getElementById('modal_form_color').value = item.color_hex;
            document.getElementById('modal_form_color_text').value = item.color_hex;
            document.getElementById('modal_form_icono').value = item.icono;

            document.getElementById('tituloFormConceptoModal').innerHTML = `<i class="bi bi-pencil-square me-2"></i>Editar: ${item.nombre}`;
            document.getElementById('wrapperFormConceptoModal').classList.remove('d-none');
            document.getElementById('wrapperFormConceptoModal').scrollIntoView({ behavior: 'smooth' });
        };

        window.cancelarFormularioConceptoModal = function() {
            document.getElementById('wrapperFormConceptoModal')?.classList.add('d-none');
        };

        window.ajustarGrupoModal = function(grupo) {
            if (grupo === 'PATHOLOGY') {
                document.getElementById('modal_form_categoria').value = 'PENDING';
                document.getElementById('modal_form_color').value = '#FF3B30';
                document.getElementById('modal_form_color_text').value = '#FF3B30';
                document.getElementById('modal_form_icono').value = 'bi-circle-fill text-danger';
            } else if (grupo === 'RESTORATION') {
                document.getElementById('modal_form_categoria').value = 'EXISTING';
                document.getElementById('modal_form_color').value = '#007AFF';
                document.getElementById('modal_form_color_text').value = '#007AFF';
                document.getElementById('modal_form_icono').value = 'bi-shield-check text-primary';
            } else {
                document.getElementById('modal_form_categoria').value = 'HEALTHY';
                document.getElementById('modal_form_color').value = '#FFFFFF';
                document.getElementById('modal_form_color_text').value = '#FFFFFF';
                document.getElementById('modal_form_icono').value = 'bi-shield-check text-success';
                document.getElementById('modal_form_precio').value = '0.00';
            }
        };

        window.guardarConceptoModal = async function(e) {
            e.preventDefault();
            const fd = new FormData(document.getElementById('formConceptoModalOdonto'));
            fd.append('action', 'save');

            try {
                const resp = await fetch('../api/catalogo_odontograma_api.pl', {
                    method: 'POST',
                    body: fd
                });
                const data = await resp.json();
                if (data.status === 'success') {
                    cancelarFormularioConceptoModal();
                    Swal.fire({
                        icon: 'success',
                        title: 'Catálogo Actualizado',
                        text: data.message,
                        timer: 1500,
                        showConfirmButton: false
                    });
                    await cargarTablaModalCatalogo();
                    if (typeof window.cargarCatalogoOdontogramaDinamico === 'function') {
                        window.cargarCatalogoOdontogramaDinamico();
                    }
                } else {
                    Swal.fire('Error', data.message || 'No se pudo guardar el concepto', 'error');
                }
            } catch (err) {
                console.error('Error guardando concepto:', err);
                Swal.fire('Error', 'Fallo de comunicación con el servidor', 'error');
            }
        };

        window.eliminarConceptoModal = async function(id, nombre) {
            const res = await Swal.fire({
                title: '¿Desactivar concepto?',
                text: `El concepto "${nombre}" ya no aparecerá en la paleta del odontograma.`,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#d33',
                cancelButtonColor: '#64748b',
                confirmButtonText: 'Sí, desactivar',
                cancelButtonText: 'Cancelar'
            });

            if (!res.isConfirmed) return;

            try {
                const resp = await fetch(`../api/catalogo_odontograma_api.pl?action=delete&id=${id}`);
                const data = await resp.json();
                if (data.status === 'success') {
                    Swal.fire('Desactivado', data.message, 'success');
                    await cargarTablaModalCatalogo();
                    if (typeof window.cargarCatalogoOdontogramaDinamico === 'function') {
                        window.cargarCatalogoOdontogramaDinamico();
                    }
                } else {
                    Swal.fire('Error', data.message || 'No se pudo desactivar', 'error');
                }
            } catch (e) {
                console.error(e);
                Swal.fire('Error', 'Fallo de conexión', 'error');
            }
        };

        document.addEventListener('DOMContentLoaded', () => {
            const containerId = 'odontograma-svg-container';
            const patientId   = window.ID_PACIENTE;
            const idOdonto    = window.ID_ODONTO;

            if (typeof renderOdontogram === 'function') {
                renderOdontogram(containerId, patientId);
                setTimeout(() => {
                    loadOdontogramaFromServer(patientId, idOdonto);
                }, 100);
            }
        });
    </script>
</body>
</html>
JS
};

if ($@) {
    print $q->header(-status => '500 Internal Server Error', -type => 'text/html', -charset => 'UTF-8');
    print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Error 500 - Odontograma</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light d-flex align-items-center justify-content-center min-vh-100 p-4">
    <div class="card shadow-sm border-0 rounded-4 p-5 text-center" style="max-width: 550px;">
        <div class="text-danger mb-3"><i class="bi bi-exclamation-octagon-fill display-3"></i></div>
        <h3 class="fw-bold text-dark">Error 500: Error Interno</h3>
        <p class="text-muted small">Ocurrió un error inesperado al inicializar el visor odontológico.</p>
        <div class="alert alert-danger text-start small font-monospace">$@</div>
        <a href="javascript:history.back()" class="btn btn-outline-secondary rounded-pill px-4 fw-bold">Volver Atrás</a>
    </div>
</body>
</html>
HTML
    exit;
}
1;
