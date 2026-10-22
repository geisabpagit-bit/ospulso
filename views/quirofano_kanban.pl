#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use File::Spec;
use FindBin;
use JSON qw(encode_json);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};
my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_empresa = $sd->{id_empresa} || '';
my $id_usuario_sesion = $sd->{id_registro} // $sd->{id_medico} // '';

binmode STDOUT, ":utf8";

# Restringir según RBAC y Excepciones Activas por usuario
unless (utils::permisos_utils::tiene_permiso_modulo($id_empresa, $role, 'quirofano', 'R', $id_usuario_sesion)) {
    render_acceso_denegado(
        q => $q, usuario => $usuario, role => $role,
        mensaje => 'No cuenta con facultades para acceder al Tablero de Quirófano de la Organización.',
        rol_requerido => 'Facultad de Lectura (R) en Quirófano'
    );
    exit;
}

# Restringir según Capacidad SaaS de la Organización (Hospitalización)
my $has_hospitalizacion = 0;
my $found_hospitalizacion = 0;
my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line);
        if ($biz_id eq $id_empresa && $key eq 'MANEJA_HOSPITALIZACION') {
            $has_hospitalizacion = ($val eq '1') ? 1 : 0;
            $found_hospitalizacion = 1;
            last;
        }
    }
    close($cf);
}
# Fallback para organización matriz (0 o vacía) sin configuración explícita previa pero con CLUE
if (!$found_hospitalizacion && ($id_empresa eq '0' || $id_empresa eq '')) {
    my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
    if (-e $negocios_file && open(my $fn, '<:raw', $negocios_file)) {
        while(my $ln = <$fn>) {
            chomp($ln);
            my @f = split(/\|/, $ln, -1);
            my $row_id = $f[0] // '';
            $row_id =~ s/\x00//g;
            $row_id =~ s/^\s+|\s+$//g;
            my $c_val = $f[18] // '';
            $c_val =~ s/\x00//g;
            $c_val =~ s/^\s+|\s+$//g;
            if ($row_id eq '0' && length($c_val)) {
                $has_hospitalizacion = 1;
                last;
            }
        }
        close($fn);
    }
}

unless ($has_hospitalizacion) {
    render_acceso_denegado(
        q => $q, usuario => $usuario, role => $role,
        mensaje => 'La organización no cuenta con la capacidad de Hospitalización / Quirófano activa en su suscripción SaaS.',
        rol_requerido => 'Capacidad SaaS: Hospitalización'
    );
    exit;
}

# Cargar Médicos de la Organización para filtros y asignación
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '!');
my @medicos = ();
foreach my $r (@$regs) {
    next unless scalar(@$r) >= 7;
    my $m_id  = $r->[0];
    my $m_nom = $r->[1];
    my $rol_u = $r->[5] // '';
    my ($org_u) = split(/:/, $r->[6] // '');
    if (($rol_u =~ /Medico/i || $rol_u =~ /Especialista/i) && ($org_u eq $id_empresa || $id_empresa eq '0' || $role eq 'Administrador Global')) {
        push @medicos, { id => $m_id, nombre => $m_nom };
    }
}
my $medicos_options_filtro = "";
foreach my $m (@medicos) {
    $medicos_options_filtro .= "<option value='$m->{id}'>$m->{nombre}</option>\n";
}

render_header(
    titulo => 'Tablero de Quirófano (Kanban)',
    role => $role,
    usuario => $usuario
);

print <<"HTML";
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme\@1.3.0/dist/select2-bootstrap-5-theme.min.css" />
<link rel="stylesheet" href="../css/sdm_mobile_standards.css" />
<script src="https://cdn.jsdelivr.net/npm/sortablejs\@latest/Sortable.min.js"></script>

<style>
    /* Estructura Kanban Fluida y Responsiva - CERO SCROLL HORIZONTAL en Desktop */
    .kanban-wrapper {
        width: 100%;
        max-width: 100%;
    }
    .kanban-board {
        display: grid;
        grid-template-columns: repeat(5, minmax(0, 1fr));
        gap: 0.85rem;
        padding-bottom: 1.5rem;
        min-height: calc(100vh - 290px);
        width: 100%;
        align-items: start;
    }
    \@media (max-width: 1099px) {
        .kanban-board {
            display: flex;
            overflow-x: auto;
            scroll-snap-type: x mandatory;
            -webkit-overflow-scrolling: touch;
            padding-bottom: 1rem;
        }
        .kanban-col {
            min-width: 280px !important;
            max-width: 320px !important;
            scroll-snap-align: start;
            flex-shrink: 0;
        }
    }
    
    .kanban-col {
        background: #f8fafc;
        border-radius: 14px;
        min-width: 0;
        display: flex;
        flex-direction: column;
        border: 1px solid #e2e8f0;
        box-shadow: 0 4px 12px rgba(15, 23, 42, 0.03);
        transition: transform 0.2s ease, box-shadow 0.2s ease;
        overflow: hidden;
    }
    .kanban-col:hover {
        box-shadow: 0 6px 18px rgba(15, 23, 42, 0.06);
    }
    .kanban-header {
        padding: 0.85rem 0.95rem;
        font-weight: 700;
        font-size: 0.85rem;
        letter-spacing: 0.02em;
        text-transform: uppercase;
        border-bottom: 2px solid;
        display: flex;
        justify-content: space-between;
        align-items: center;
        background: #ffffff;
    }
    .kanban-header .badge-counter {
        font-size: 0.75rem;
        padding: 0.25rem 0.55rem;
        font-weight: 700;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    }
    .kanban-body {
        padding: 0.75rem 0.65rem;
        flex: 1;
        overflow-y: auto;
        max-height: calc(100vh - 350px);
        min-height: 220px;
        display: flex;
        flex-direction: column;
        gap: 0.65rem;
    }
    
    /* Tarjeta Quirúrgica de Alto Rendimiento UI */
    .kanban-card {
        background: #ffffff;
        border-radius: 10px;
        padding: 0.85rem;
        box-shadow: 0 2px 6px rgba(15, 23, 42, 0.05);
        border: 1px solid #e2e8f0;
        border-left: 4px solid #cbd5e1;
        cursor: grab;
        transition: transform 0.18s ease, box-shadow 0.18s ease, border-color 0.18s ease;
        position: relative;
    }
    .kanban-card:active {
        cursor: grabbing;
    }
    .kanban-card:hover {
        box-shadow: 0 8px 16px rgba(15, 23, 42, 0.08);
        transform: translateY(-2px);
    }
    
    /* Identidad cromática por columna */
    .col-programada .kanban-header { border-color: #94a3b8; color: #475569; background: #f8fafc; }
    .col-programada .kanban-card { border-left-color: #94a3b8; }
    
    .col-preop .kanban-header { border-color: #f59e0b; color: #b45309; background: #fffdf5; }
    .col-preop .kanban-card { border-left-color: #f59e0b; }
    
    .col-quirofano .kanban-header { border-color: #ef4444; color: #b91c1c; background: #fff5f5; }
    .col-quirofano .kanban-card { border-left-color: #ef4444; }
    
    .col-recuperacion .kanban-header { border-color: #3b82f6; color: #1d4ed8; background: #f0f7ff; }
    .col-recuperacion .kanban-card { border-left-color: #3b82f6; }
    
    .col-alta .kanban-header { border-color: #10b981; color: #047857; background: #f0fdf4; }
    .col-alta .kanban-card { border-left-color: #10b981; }

    /* Pulso animado para quirófano en curso */
    .pulse-live {
        display: inline-block;
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: #ef4444;
        box-shadow: 0 0 0 rgba(239, 68, 68, 0.6);
        animation: pulseLiveAnim 1.6s infinite;
        margin-right: 5px;
    }
    \@keyframes pulseLiveAnim {
        0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7); }
        70% { transform: scale(1.1); box-shadow: 0 0 0 6px rgba(239, 68, 68, 0); }
        100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); }
    }

    /* Avatar clínico con monograma */
    .avatar-monogram {
        width: 32px;
        height: 32px;
        border-radius: 50%;
        background: linear-gradient(135deg, #0A2A66 0%, #1e40af 100%);
        color: #ffffff;
        font-weight: 700;
        font-size: 0.75rem;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
    }
    
    .sortable-ghost {
        opacity: 0.35;
        background: #e2e8f0;
        border: 2px dashed #94a3b8;
    }
    .sortable-drag {
        transform: rotate(2deg);
        box-shadow: 0 12px 24px rgba(0,0,0,0.18) !important;
    }

    .empty-kanban-hint {
        padding: 2.2rem 0.5rem;
        text-align: center;
        color: #94a3b8;
        font-size: 0.8rem;
        font-weight: 500;
        user-select: none;
    }

    /* KPI Summary Pills */
    .kpi-chip {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 8px;
        padding: 0.35rem 0.75rem;
        font-size: 0.78rem;
        font-weight: 600;
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        color: #334155;
        box-shadow: 0 1px 3px rgba(0,0,0,0.02);
    }
</style>

<main class="container-fluid container-mobile-flush pt-3 px-3 px-lg-4 pb-5 animate__animated animate__fadeIn kanban-wrapper">
    
    <!-- Header principal & Quick Actions -->
    <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2">
        <div>
            <div class="d-flex align-items-center gap-2">
                <div class="p-2 bg-primary-subtle text-primary rounded-3">
                    <i class="bi bi-hospital fs-5"></i>
                </div>
                <div>
                    <h4 class="fw-bold mb-0 text-navy d-flex align-items-center gap-2">
                        Tablero Quirúrgico
                        <span class="badge bg-primary text-white fs-8 rounded-pill px-2 py-1">En Vivo</span>
                    </h4>
                    <p class="text-muted small mb-0">Gestión de flujo transoperatorio y seguridad del paciente</p>
                </div>
            </div>
        </div>
        <div class="d-flex flex-wrap align-items-center gap-2">
            <span class="badge bg-white text-navy border py-2 px-3 shadow-sm rounded-3 fw-bold d-flex align-items-center">
                <i class="bi bi-calendar-event text-primary me-2"></i>
                <span id="lblFechaHoy" class="fw-bold text-primary"></span>
            </span>
            <a href="agenda_main.pl" class="btn btn-sm btn-outline-primary btn-mobile-standard shadow-sm d-flex align-items-center fw-semibold">
                <i class="bi bi-calendar-plus me-1.5"></i> Programar Cirugía
            </a>
            <button class="btn btn-sm btn-light border text-muted shadow-sm d-flex align-items-center" onclick="cargarTablero(fechaActualSeleccionada)" title="Refrescar datos">
                <i class="bi bi-arrow-clockwise"></i>
            </button>
        </div>
    </div>

    <!-- Barra de KPIs Rápidos del Día -->
    <div class="d-flex flex-wrap gap-2 mb-3">
        <div class="kpi-chip">
            <i class="bi bi-calendar3 text-muted"></i>
            <span>Total:</span>
            <span id="kpi-total" class="fw-bold text-dark">0</span>
        </div>
        <div class="kpi-chip">
            <i class="bi bi-calendar-check text-secondary"></i>
            <span>Programadas:</span>
            <span id="kpi-prog" class="fw-bold text-secondary">0</span>
        </div>
        <div class="kpi-chip">
            <i class="bi bi-hourglass-split text-warning"></i>
            <span>Pre-Op:</span>
            <span id="kpi-preop" class="fw-bold text-warning">0</span>
        </div>
        <div class="kpi-chip">
            <span class="pulse-live"></span>
            <span class="text-danger">En Quirófano:</span>
            <span id="kpi-qx" class="fw-bold text-danger">0</span>
        </div>
        <div class="kpi-chip">
            <i class="bi bi-bandaid-fill text-primary"></i>
            <span>Recuperación:</span>
            <span id="kpi-ucpa" class="fw-bold text-primary">0</span>
        </div>
        <div class="kpi-chip">
            <i class="bi bi-check-circle-fill text-success"></i>
            <span>Concluidas:</span>
            <span id="kpi-alta" class="fw-bold text-success">0</span>
        </div>
    </div>

    <!-- Barra de Filtros y Navegación Quirúrgica -->
    <div class="card border-0 shadow-sm rounded-3 mb-3 bg-white">
        <div class="card-body p-2 p-md-3">
            <div class="row g-2 align-items-end">
                <!-- 1. Navegador de Fecha -->
                <div class="col-12 col-md-4 col-lg-4">
                    <label class="form-label small text-muted fw-bold mb-1">
                        <i class="bi bi-calendar3 text-primary me-1"></i>Fecha de Cirugías
                    </label>
                    <div class="input-group input-group-sm">
                        <button class="btn btn-outline-secondary" type="button" id="btnFechaAnt" title="Día Anterior">
                            <i class="bi bi-chevron-left"></i>
                        </button>
                        <input type="date" id="filtroFecha" class="form-control text-center fw-bold text-primary">
                        <button class="btn btn-outline-primary fw-semibold" type="button" id="btnFechaHoy" title="Ir al día de hoy">
                            Hoy
                        </button>
                        <button class="btn btn-outline-secondary" type="button" id="btnFechaSig" title="Día Siguiente">
                            <i class="bi bi-chevron-right"></i>
                        </button>
                    </div>
                </div>

                <!-- 2. Filtro por Cirujano -->
                <div class="col-12 col-sm-6 col-md-4 col-lg-4">
                    <label class="form-label small text-muted fw-bold mb-1">
                        <i class="bi bi-person-badge text-info me-1"></i>Cirujano / Especialista
                    </label>
                    <select id="filtroMedico" class="form-select form-select-sm fw-semibold">
                        <option value="">👨‍⚕️ Todos los Médicos / Cirujanos</option>
                        $medicos_options_filtro
                    </select>
                </div>

                <!-- 3. Búsqueda de Paciente / Procedimiento -->
                <div class="col-12 col-sm-6 col-md-4 col-lg-4">
                    <label class="form-label small text-muted fw-bold mb-1">
                        <i class="bi bi-search text-success me-1"></i>Buscar Paciente / Procedimiento
                    </label>
                    <div class="input-group input-group-sm">
                        <span class="input-group-text bg-white text-muted"><i class="bi bi-search"></i></span>
                        <input type="text" id="filtroTexto" class="form-control" placeholder="Nombre, procedimiento, sala...">
                        <button class="btn btn-outline-secondary" type="button" id="btnLimpiarTexto" title="Limpiar filtro" style="display:none;">
                            <i class="bi bi-x-lg"></i>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Tablero Kanban Fluid 5 Columnas -->
    <div class="kanban-board">
        
        <!-- PROGRAMADA -->
        <div class="kanban-col col-programada">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5"><i class="bi bi-calendar-check text-secondary"></i> Programada</span>
                <span class="badge bg-secondary badge-counter rounded-pill" id="cnt-Programada">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Programada" data-estado="Programada"></div>
        </div>
        
        <!-- PRE-OPERATORIO -->
        <div class="kanban-col col-preop">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5"><i class="bi bi-hourglass-split text-warning"></i> Pre-Operatorio</span>
                <span class="badge bg-warning text-dark badge-counter rounded-pill" id="cnt-Pre-Operatorio">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Pre-Operatorio" data-estado="Pre-Operatorio"></div>
        </div>
        
        <!-- EN QUIRÓFANO -->
        <div class="kanban-col col-quirofano">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5">
                    <span class="pulse-live"></span>
                    <span>En Quirófano</span>
                </span>
                <span class="badge bg-danger badge-counter rounded-pill" id="cnt-En Quirófano">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-En Quirófano" data-estado="En Quirófano"></div>
        </div>
        
        <!-- RECUPERACIÓN (UCPA) -->
        <div class="kanban-col col-recuperacion">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5"><i class="bi bi-bandaid-fill text-primary"></i> Recuperación</span>
                <span class="badge bg-primary badge-counter rounded-pill" id="cnt-Recuperación">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Recuperación" data-estado="Recuperación"></div>
        </div>
        
        <!-- ALTA / TRASLADO -->
        <div class="kanban-col col-alta">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5"><i class="bi bi-check-circle-fill text-success"></i> Alta / Traslado</span>
                <span class="badge bg-success badge-counter rounded-pill" id="cnt-Alta">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Alta" data-estado="Alta"></div>
        </div>
        
    </div>

</main>

<!-- Modal Premium: Ficha Rápida e Inspección Quirúrgica -->
<div class="modal fade" id="modalDetalleCirugia" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-xl">
        <div class="modal-content border-0 shadow-lg rounded-4 overflow-hidden">
            <div class="modal-header bg-navy text-white px-4 py-3">
                <div class="d-flex align-items-center gap-2">
                    <div class="p-2 bg-white bg-opacity-10 rounded-3">
                        <i class="bi bi-heart-pulse text-warning fs-5"></i>
                    </div>
                    <div>
                        <h5 class="modal-title fw-bold mb-0" id="mdl_paciente_nombre">Detalles Quirúrgicos</h5>
                        <small class="text-white-50" id="mdl_subtitulo">Expediente Clínico & Control Operatorio</small>
                    </div>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-3 p-md-4 bg-light">
                <!-- Pestañas de Navegación Quirúrgica -->
                <ul class="nav nav-pills nav-fill mb-3 bg-white p-1.5 rounded-3 shadow-xs border" id="pills-modal-qx" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active fw-bold py-1.5" id="pills-ficha-tab" data-bs-toggle="pill" data-bs-target="#pills-ficha" type="button" role="tab">
                            <i class="bi bi-card-checklist me-1"></i> 1. Ficha y Sala
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link fw-bold py-1.5" id="pills-preop-tab" data-bs-toggle="pill" data-bs-target="#pills-preop" type="button" role="tab">
                            <i class="bi bi-shield-check me-1"></i> 2. Checklist OMS Pre-Op
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link fw-bold py-1.5" id="pills-nota-tab" data-bs-toggle="pill" data-bs-target="#pills-nota" type="button" role="tab">
                            <i class="bi bi-journal-medical me-1"></i> 3. Nota Quirúrgica & UCPA
                        </button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link fw-bold py-1.5" id="pills-caja-tab" data-bs-toggle="pill" data-bs-target="#pills-caja" type="button" role="tab">
                            <i class="bi bi-cash-coin me-1"></i> 4. Pre-Liquidación & Caja
                        </button>
                    </li>
                </ul>

                <div class="tab-content" id="pills-modal-qxContent">
                    <!-- TAB 1: FICHA Y SALA -->
                    <div class="tab-pane fade show active" id="pills-ficha" role="tabpanel">
                        <div class="row g-3">
                            <!-- Resumen General -->
                            <div class="col-12 col-md-7">
                                <div class="card border-0 shadow-sm rounded-3 p-3 bg-white h-100">
                                    <h6 class="fw-bold text-primary mb-3 border-bottom pb-2">
                                        <i class="bi bi-file-earmark-medical me-1"></i> Información del Procedimiento
                                    </h6>
                                    <div class="mb-2">
                                        <span class="text-muted small d-block">Procedimiento Programado:</span>
                                        <span class="fw-bold text-dark fs-6" id="mdl_procedimiento"></span>
                                    </div>
                                    <div class="row g-2 mb-2">
                                        <div class="col-6">
                                            <span class="text-muted small d-block">Sala / Quirófano:</span>
                                            <span class="badge bg-light text-dark border px-2 py-1 fw-bold" id="mdl_sala"></span>
                                        </div>
                                        <div class="col-6">
                                            <span class="text-muted small d-block">Horario Programado:</span>
                                            <span class="badge bg-primary-subtle text-primary border border-primary-subtle px-2 py-1 fw-bold" id="mdl_horario"></span>
                                        </div>
                                    </div>
                                    <!-- Semáforo Consentimiento Quirúrgico (NOM-004) -->
                                    <div class="mb-2 p-2.5 rounded-3 border" id="mdl_box_consentimiento" style="background: #f8fafc;">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <div>
                                                <span class="text-muted small d-block fw-bold" style="font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.5px;">Consentimiento Quirúrgico (NOM-004)</span>
                                                <div id="mdl_semaforo_cons" class="mt-1 d-flex align-items-center gap-1.5 flex-wrap">
                                                    <span class="badge bg-secondary-subtle text-secondary border px-2 py-0.5"><i class="bi bi-hourglass-split me-1"></i> Consultando...</span>
                                                </div>
                                            </div>
                                            <div id="mdl_cons_acciones"></div>
                                        </div>
                                    </div>
                                    <div class="mb-2">
                                        <span class="text-muted small d-block">Notas Clínicas / Indicaciones:</span>
                                        <p class="small text-muted bg-light p-2 rounded border mb-0" id="mdl_notas">Sin notas registradas</p>
                                    </div>
                                </div>
                            </div>
                            <!-- Equipo y Transiciones Rápidas -->
                            <div class="col-12 col-md-5">
                                <div class="card border-0 shadow-sm rounded-3 p-3 bg-white h-100">
                                    <h6 class="fw-bold text-primary mb-3 border-bottom pb-2">
                                        <i class="bi bi-people me-1"></i> Equipo Quirúrgico
                                    </h6>
                                    <div class="mb-2">
                                        <span class="text-muted small d-block">Cirujano Titular:</span>
                                        <span class="fw-semibold text-dark small" id="mdl_cirujano"></span>
                                    </div>
                                    <div class="mb-3">
                                        <span class="text-muted small d-block">Anestesiólogo:</span>
                                        <span class="fw-semibold text-dark small" id="mdl_anestesio"></span>
                                    </div>
                                    <h6 class="fw-bold text-muted small mb-2 border-top pt-2">
                                        <i class="bi bi-arrow-left-right me-1"></i> Transición Rápida de Estado
                                    </h6>
                                    <div class="d-grid gap-1.5" id="mdl_botones_transicion">
                                        <!-- Se inyectan dinámicamente -->
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- TAB 2: CHECKLIST OMS PRE-OP -->
                    <div class="tab-pane fade" id="pills-preop" role="tabpanel">
                        <form id="formChecklistPreop" onsubmit="guardarChecklistPreop(event)">
                            <input type="hidden" id="chk_id_cirugia" name="id_cirugia">
                            <div class="row g-3">
                                <div class="col-12 col-md-6">
                                    <div class="card p-3 border-0 shadow-xs rounded-3 bg-white h-100">
                                        <h6 class="fw-bold text-primary border-bottom pb-2 mb-3">
                                            <i class="bi bi-person-check me-1"></i> Verificación y Seguridad del Paciente
                                        </h6>
                                        <div class="form-check form-switch mb-2.5">
                                            <input class="form-check-input" type="checkbox" id="chk_identidad" name="identidad_verificada" value="1">
                                            <label class="form-check-label small fw-semibold" for="chk_identidad">Identidad confirmada con 2 identificadores</label>
                                        </div>
                                        <div class="form-check form-switch mb-2.5">
                                            <input class="form-check-input" type="checkbox" id="chk_consentimiento" name="consentimiento_firmado" value="1">
                                            <label class="form-check-label small fw-semibold" for="chk_consentimiento">Consentimiento Qx y Anestésico verificado</label>
                                        </div>
                                        <div class="form-check form-switch mb-2.5">
                                            <input class="form-check-input" type="checkbox" id="chk_sitio_marcado" name="sitio_marcado" value="1">
                                            <label class="form-check-label small fw-semibold" for="chk_sitio_marcado">Sitio quirúrgico marcado por cirujano</label>
                                        </div>
                                        <div class="form-check form-switch mb-2.5">
                                            <input class="form-check-input" type="checkbox" id="chk_alergias" name="alergias_verificadas" value="1">
                                            <label class="form-check-label small fw-semibold" for="chk_alergias">Alergias a fármacos verificadas</label>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-12 col-md-6">
                                    <div class="card p-3 border-0 shadow-xs rounded-3 bg-white h-100">
                                        <h6 class="fw-bold text-primary border-bottom pb-2 mb-3">
                                            <i class="bi bi-capsule me-1"></i> Preparación Clínica y Vía
                                        </h6>
                                        <div class="d-flex align-items-center justify-content-between mb-2.5">
                                            <div class="form-check form-switch mb-0">
                                                <input class="form-check-input" type="checkbox" id="chk_ayuno" name="ayuno_confirmado" value="1">
                                                <label class="form-check-label small fw-semibold" for="chk_ayuno">Ayuno confirmado</label>
                                            </div>
                                            <div class="d-flex align-items-center gap-1">
                                                <input type="number" id="chk_horas_ayuno" name="horas_ayuno" class="form-control form-control-sm text-center" style="width: 65px;" min="0" max="48" value="8">
                                                <span class="small text-muted">hrs</span>
                                            </div>
                                        </div>
                                        <div class="form-check form-switch mb-2.5">
                                            <input class="form-check-input" type="checkbox" id="chk_labs" name="labs_validados" value="1">
                                            <label class="form-check-label small fw-semibold" for="chk_labs">Laboratorios validados (TP/TTP/Hb/Rh)</label>
                                        </div>
                                        <div class="form-check form-switch mb-2.5">
                                            <input class="form-check-input" type="checkbox" id="chk_via" name="via_permeable" value="1">
                                            <label class="form-check-label small fw-semibold" for="chk_via">Vía venosa periférica permeable</label>
                                        </div>
                                        <div class="form-check form-switch mb-2.5">
                                            <input class="form-check-input" type="checkbox" id="chk_profilaxis" name="profilaxis_antibiotica" value="1">
                                            <label class="form-check-label small fw-semibold" for="chk_profilaxis">Profilaxis antibiótica (&lt;60 min)</label>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-12">
                                    <div class="card p-3 border-0 shadow-xs rounded-3 bg-white">
                                        <label class="form-label small fw-bold text-dark mb-1">Observaciones / Notas de Enfermería Pre-Op</label>
                                        <textarea id="chk_observaciones" name="observaciones_enfermeria" class="form-control form-control-sm" rows="2" placeholder="Notas sobre el estado general del paciente, catéteres o indicaciones previas a sala..."></textarea>
                                        <div class="d-flex justify-content-end mt-2">
                                            <button type="submit" class="btn btn-sm btn-primary fw-bold rounded-pill px-4">
                                                <i class="bi bi-check2-circle me-1"></i> Guardar Checklist Pre-Op
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>

                    <!-- TAB 3: NOTA QUIRURGICA & UCPA -->
                    <div class="tab-pane fade" id="pills-nota" role="tabpanel">
                        <form id="formNotaQuirurgica" onsubmit="guardarNotaQuirurgica(event)">
                            <input type="hidden" id="nt_id_cirugia" name="id_cirugia">
                            <div class="row g-3">
                                <!-- Tiempos y Conteo de Seguridad -->
                                <div class="col-12 col-md-5">
                                    <div class="card p-3 border-0 shadow-xs rounded-3 bg-white mb-3">
                                        <h6 class="fw-bold text-primary border-bottom pb-2 mb-2">
                                            <i class="bi bi-clock-history me-1"></i> Tiempos Quirúrgicos
                                        </h6>
                                        <div class="row g-2">
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Ingreso Sala:</label>
                                                <input type="time" id="nt_t_ingreso" name="hora_ingreso_sala" class="form-control form-control-sm">
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Inicio Anestesia:</label>
                                                <input type="time" id="nt_t_anestesia" name="hora_inicio_anestesia" class="form-control form-control-sm">
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Incisión Qx:</label>
                                                <input type="time" id="nt_t_incision" name="hora_incision" class="form-control form-control-sm">
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Cierre de Piel:</label>
                                                <input type="time" id="nt_t_cierre" name="hora_cierre" class="form-control form-control-sm">
                                            </div>
                                            <div class="col-12">
                                                <label class="small text-muted d-block">Salida a UCPA:</label>
                                                <input type="time" id="nt_t_salida" name="hora_salida_sala" class="form-control form-control-sm">
                                            </div>
                                        </div>
                                    </div>
                                    <div class="card p-3 border-0 shadow-xs rounded-3 bg-white">
                                        <h6 class="fw-bold text-success border-bottom pb-2 mb-2">
                                            <i class="bi bi-shield-lock me-1"></i> Seguridad Transoperatoria
                                        </h6>
                                        <div class="form-check form-switch mb-2">
                                            <input class="form-check-input" type="checkbox" id="nt_conteo_gasas" name="conteo_gasas_completo" value="1">
                                            <label class="form-check-label small fw-semibold" for="nt_conteo_gasas">Conteo de Gasas Verificado (100%)</label>
                                        </div>
                                        <div class="form-check form-switch mb-2">
                                            <input class="form-check-input" type="checkbox" id="nt_conteo_compresas" name="conteo_compresas_completo" value="1">
                                            <label class="form-check-label small fw-semibold" for="nt_conteo_compresas">Conteo de Compresas Verificado (100%)</label>
                                        </div>
                                        <div class="form-check form-switch mb-2">
                                            <input class="form-check-input" type="checkbox" id="nt_conteo_instrumental" name="conteo_instrumental_completo" value="1">
                                            <label class="form-check-label small fw-semibold" for="nt_conteo_instrumental">Conteo de Instrumental Completo</label>
                                        </div>
                                        <div>
                                            <label class="small text-muted d-block mb-1">Incidentes o Accidentes:</label>
                                            <input type="text" id="nt_incidentes" name="incidentes_accidentes" class="form-control form-control-sm" placeholder="Sin incidentes">
                                        </div>
                                    </div>
                                </div>
                                <!-- Nota Quirúrgica NOM-004 y Aldrete -->
                                <div class="col-12 col-md-7">
                                    <div class="card p-3 border-0 shadow-xs rounded-3 bg-white">
                                        <h6 class="fw-bold text-primary border-bottom pb-2 mb-2">
                                            <i class="bi bi-file-earmark-medical me-1"></i> Nota Quirúrgica (NOM-004-SSA3-2012)
                                        </h6>
                                        <div class="row g-2 mb-2">
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Dx Preoperatorio:</label>
                                                <input type="text" id="nt_dx_preop" name="diagnostico_preop" class="form-control form-control-sm" required>
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Dx Postoperatorio:</label>
                                                <input type="text" id="nt_dx_postop" name="diagnostico_postop" class="form-control form-control-sm" required>
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Operación Planeada:</label>
                                                <input type="text" id="nt_op_planeada" name="operacion_planeada" class="form-control form-control-sm">
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Operación Realizada:</label>
                                                <input type="text" id="nt_op_realizada" name="operacion_realizada" class="form-control form-control-sm" required>
                                            </div>
                                            <div class="col-12">
                                                <label class="small text-muted d-block">Descripción de la Técnica Quirúrgica:</label>
                                                <textarea id="nt_tecnica" name="descripcion_tecnica" class="form-control form-control-sm" rows="3" placeholder="Vía de abordaje, disección, hallazgos, hemostasia y síntesis..."></textarea>
                                            </div>
                                            <div class="col-12">
                                                <label class="small text-muted d-block">Hallazgos Quirúrgicos Relevantes:</label>
                                                <textarea id="nt_hallazgos" name="hallazgos" class="form-control form-control-sm" rows="2" placeholder="Detalles de la anatomía, lesiones o hallazgos visuales..."></textarea>
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Sangrado Aprox (ml):</label>
                                                <input type="text" id="nt_sangrado" name="sangrado_aprox_ml" class="form-control form-control-sm" placeholder="Ej: 50 ml">
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block">Muestras a Patología:</label>
                                                <input type="text" id="nt_patologia" name="piezas_patologia" class="form-control form-control-sm" placeholder="Ej: Apéndice cecal">
                                            </div>
                                        </div>

                                        <!-- Criterios Aldrete UCPA -->
                                        <h6 class="fw-bold text-dark border-top pt-2 pb-1 mb-2 d-flex justify-content-between align-items-center">
                                            <span><i class="bi bi-heart-pulse text-danger me-1"></i> Recuperación UCPA (Escala Aldrete)</span>
                                            <span id="badge_aldrete_total" class="badge bg-success-subtle text-success border border-success-subtle px-2 py-0.5 fw-bold">10 / 10 Pts (Apto Alta)</span>
                                        </h6>
                                        <div class="row g-2 mb-2">
                                            <div class="col-4">
                                                <label class="small text-muted d-block" style="font-size:0.7rem;">Actividad Motora:</label>
                                                <select id="nt_ald_act" name="aldrete_actividad" class="form-select form-select-sm" onchange="calcularAldrete()">
                                                    <option value="2">2 - Mueve 4 miembros</option>
                                                    <option value="1">1 - Mueve 2 miembros</option>
                                                    <option value="0">0 - No mueve</option>
                                                </select>
                                            </div>
                                            <div class="col-4">
                                                <label class="small text-muted d-block" style="font-size:0.7rem;">Respiración:</label>
                                                <select id="nt_ald_res" name="aldrete_respiracion" class="form-select form-select-sm" onchange="calcularAldrete()">
                                                    <option value="2">2 - Tose y respira</option>
                                                    <option value="1">1 - Disnea leve</option>
                                                    <option value="0">0 - Apnea</option>
                                                </select>
                                            </div>
                                            <div class="col-4">
                                                <label class="small text-muted d-block" style="font-size:0.7rem;">Circulación (PA):</label>
                                                <select id="nt_ald_cir" name="aldrete_circulacion" class="form-select form-select-sm" onchange="calcularAldrete()">
                                                    <option value="2">2 - PA ±20% basal</option>
                                                    <option value="1">1 - PA ±20-49%</option>
                                                    <option value="0">0 - PA ±50%</option>
                                                </select>
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block" style="font-size:0.7rem;">Conciencia:</label>
                                                <select id="nt_ald_con" name="aldrete_conciencia" class="form-select form-select-sm" onchange="calcularAldrete()">
                                                    <option value="2">2 - Completamente despierto</option>
                                                    <option value="1">1 - Despierta al llamado</option>
                                                    <option value="0">0 - No responde</option>
                                                </select>
                                            </div>
                                            <div class="col-6">
                                                <label class="small text-muted d-block" style="font-size:0.7rem;">Saturación O2:</label>
                                                <select id="nt_ald_sat" name="aldrete_saturacion" class="form-select form-select-sm" onchange="calcularAldrete()">
                                                    <option value="2">2 - &gt;92% con aire ambiente</option>
                                                    <option value="1">1 - Necesita O2 suplementario</option>
                                                    <option value="0">0 - &lt;90% aun con O2</option>
                                                </select>
                                            </div>
                                        </div>

                                        <div class="d-flex justify-content-between align-items-center mt-2 flex-wrap gap-2">
                                            <a href="#" target="_blank" id="btn_imprimir_nota_qx" class="btn btn-sm btn-outline-dark fw-bold rounded-pill px-3 shadow-xs">
                                                <i class="bi bi-printer me-1"></i> Imprimir Nota NOM-004
                                            </a>
                                            <button type="submit" class="btn btn-sm btn-primary fw-bold rounded-pill px-4">
                                                <i class="bi bi-save me-1"></i> Guardar Nota Quirúrgica y Aldrete
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>

                    <!-- TAB 4: PRE-LIQUIDACION & CAJA -->
                    <div class="tab-pane fade" id="pills-caja" role="tabpanel">
                        <form id="formLiquidacionCaja" onsubmit="guardarLiquidacionCaja(event)">
                            <input type="hidden" id="liq_id_cirugia" name="id_cirugia">
                            <div class="row g-3">
                                <div class="col-12 col-md-5">
                                    <div class="card p-3 border-0 shadow-xs rounded-3 bg-white h-100">
                                        <h6 class="fw-bold text-primary border-bottom pb-2 mb-3">
                                            <i class="bi bi-stopwatch me-1"></i> Tiempos y Honorarios de Quirófano
                                        </h6>
                                        <div class="mb-2">
                                            <label class="small text-muted d-block">Horas en Sala Quirúrgica:</label>
                                            <input type="number" step="0.25" id="liq_horas_sala" name="horas_sala" class="form-control form-control-sm" value="1.0" oninput="calcularTotalLiquidacion()">
                                        </div>
                                        <div class="mb-2">
                                            <label class="small text-muted d-block">Tarifa por Hora de Sala ($):</label>
                                            <input type="number" step="0.01" id="liq_costo_hora" name="costo_hora_sala" class="form-control form-control-sm" value="1500.00" oninput="calcularTotalLiquidacion()">
                                        </div>
                                        <div class="mb-2">
                                            <label class="small text-muted d-block">Honorarios Cirujano ($):</label>
                                            <input type="number" step="0.01" id="liq_hon_cir" name="honorarios_cirujano" class="form-control form-control-sm" value="0.00" oninput="calcularTotalLiquidacion()">
                                        </div>
                                        <div class="mb-2">
                                            <label class="small text-muted d-block">Honorarios Anestesiólogo ($):</label>
                                            <input type="number" step="0.01" id="liq_hon_ane" name="honorarios_anestesio" class="form-control form-control-sm" value="0.00" oninput="calcularTotalLiquidacion()">
                                        </div>
                                    </div>
                                </div>
                                <div class="col-12 col-md-7">
                                    <div class="card p-3 border-0 shadow-xs rounded-3 bg-white h-100 d-flex flex-column justify-content-between">
                                        <div>
                                            <div class="d-flex justify-content-between align-items-center border-bottom pb-2 mb-2">
                                                <h6 class="fw-bold text-primary mb-0">
                                                    <i class="bi bi-box-seam text-success me-1"></i> Insumos y Materiales de Sala
                                                </h6>
                                                <button type="button" class="btn btn-xs btn-outline-primary rounded-pill px-2 py-0.5 fw-bold" onclick="agregarFilaInsumo()">
                                                    <i class="bi bi-plus-circle me-1"></i> + Agregar Insumo
                                                </button>
                                            </div>
                                            <div class="table-responsive" style="max-height: 180px; overflow-y: auto;">
                                                <table class="table table-sm table-borderless align-middle mb-0" id="tablaInsumosQx">
                                                    <thead class="table-light small text-muted">
                                                        <tr>
                                                            <th>Concepto / Material</th>
                                                            <th style="width: 70px;">Cant.</th>
                                                            <th style="width: 100px;">Precio U.</th>
                                                            <th style="width: 35px;"></th>
                                                        </tr>
                                                    </thead>
                                                    <tbody id="tbodyInsumosQx">
                                                        <!-- Filas dinámicas -->
                                                    </tbody>
                                                </table>
                                            </div>
                                        </div>

                                        <!-- Total y Acción Caja -->
                                        <div class="border-top pt-3 mt-2">
                                            <div class="d-flex justify-content-between align-items-center mb-3">
                                                <span class="fs-6 fw-bold text-dark">Total Pre-Liquidación Qx:</span>
                                                <span class="fs-5 fw-bold text-success font-monospace" id="lbl_total_liquidacion">$0.00</span>
                                            </div>
                                            <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
                                                <div id="box_estado_caja">
                                                    <span class="badge bg-secondary-subtle text-secondary border px-2 py-1">No enviado a Caja</span>
                                                </div>
                                                <div class="d-flex gap-2">
                                                    <button type="submit" class="btn btn-sm btn-outline-primary fw-semibold rounded-pill px-3">
                                                        <i class="bi bi-save me-1"></i> Guardar Borrador
                                                    </button>
                                                    <button type="button" class="btn btn-sm btn-success fw-bold rounded-pill px-4 shadow-sm" id="btn_enviar_caja" onclick="inyectarCirugiaACaja()">
                                                        <i class="bi bi-cash-stack me-1"></i> Enviar a Caja
                                                    </button>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
            <div class="modal-footer bg-white border-top px-4 py-2.5 d-flex justify-content-between">
                <div>
                    <a href="#" id="mdl_btn_expediente" target="_blank" class="btn btn-sm btn-outline-primary fw-semibold">
                        <i class="bi bi-folder2-open me-1"></i> Abrir Expediente
                    </a>
                </div>
                <button type="button" class="btn btn-sm btn-secondary fw-semibold" data-bs-dismiss="modal">Cerrar</button>
            </div>
        </div>
    </div>
</div>
HTML

print <<'JS';
<script>
    let fechaActualSeleccionada = '';
    let cirugiasCargadas = [];

    $(document).ready(function() {
        initFechaDefecto();
        initFiltrosUI();
        initSortable();
        cargarTablero(fechaActualSeleccionada);
    });

    function formatearFechaTexto(fechaIso) {
        if (!fechaIso) return '';
        const partes = fechaIso.split('-');
        if (partes.length !== 3) return fechaIso;
        const d = new Date(parseInt(partes[0]), parseInt(partes[1]) - 1, parseInt(partes[2]));
        return d.toLocaleDateString('es-ES', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' }).toUpperCase();
    }

    function initFechaDefecto() {
        const tzoffset = (new Date()).getTimezoneOffset() * 60000;
        fechaActualSeleccionada = (new Date(Date.now() - tzoffset)).toISOString().slice(0, 10);
        $('#filtroFecha').val(fechaActualSeleccionada);
        $('#lblFechaHoy').text(formatearFechaTexto(fechaActualSeleccionada));
    }

    function initFiltrosUI() {
        $('#filtroFecha').on('change', function() {
            const nuevaFecha = $(this).val();
            if (nuevaFecha) {
                fechaActualSeleccionada = nuevaFecha;
                $('#lblFechaHoy').text(formatearFechaTexto(fechaActualSeleccionada));
                cargarTablero(fechaActualSeleccionada);
            }
        });

        $('#btnFechaAnt').on('click', function() {
            navegarFechaRelativa(-1);
        });

        $('#btnFechaSig').on('click', function() {
            navegarFechaRelativa(1);
        });

        $('#btnFechaHoy').on('click', function() {
            initFechaDefecto();
            cargarTablero(fechaActualSeleccionada);
        });

        $('#filtroMedico').on('change', function() {
            aplicarFiltrosLocales();
        });

        $('#filtroTexto').on('input', function() {
            const val = $(this).val();
            if (val && val.trim().length > 0) {
                $('#btnLimpiarTexto').show();
            } else {
                $('#btnLimpiarTexto').hide();
            }
            aplicarFiltrosLocales();
        });

        $('#btnLimpiarTexto').on('click', function() {
            $('#filtroTexto').val('');
            $(this).hide();
            aplicarFiltrosLocales();
        });
    }

    function navegarFechaRelativa(dias) {
        const fVal = $('#filtroFecha').val() || fechaActualSeleccionada;
        const partes = fVal.split('-');
        const dt = new Date(parseInt(partes[0]), parseInt(partes[1]) - 1, parseInt(partes[2]));
        dt.setDate(dt.getDate() + dias);
        const y = dt.getFullYear();
        const m = String(dt.getMonth() + 1).padStart(2, '0');
        const d = String(dt.getDate()).padStart(2, '0');
        const nuevaIso = `${y}-${m}-${d}`;
        $('#filtroFecha').val(nuevaIso);
        fechaActualSeleccionada = nuevaIso;
        $('#lblFechaHoy').text(formatearFechaTexto(nuevaIso));
        cargarTablero(nuevaIso);
    }
    
    function initSortable() {
        const lists = document.querySelectorAll('.sortable-list');
        lists.forEach(list => {
            new Sortable(list, {
                group: 'kanban',
                animation: 200,
                ghostClass: 'sortable-ghost',
                dragClass: 'sortable-drag',
                onEnd: function (evt) {
                    const itemEl = evt.item;
                    const toList = evt.to;
                    const idCirugia = itemEl.getAttribute('data-id');
                    const nuevoEstado = toList.getAttribute('data-estado');
                    
                    if (evt.from !== toList) {
                        actualizarEstadoCirugia(idCirugia, nuevoEstado);
                        actualizarContadores();
                    }
                },
            });
        });
    }

    function obtenerIniciales(nombre) {
        if (!nombre) return 'PX';
        const parts = nombre.trim().split(/\s+/);
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    
    async function cargarTablero(fechaFiltro) {
        const fecha = fechaFiltro || fechaActualSeleccionada;
        
        const columnas = ['Programada', 'Pre-Operatorio', 'En\\ Quirófano', 'Recuperación', 'Alta'];
        columnas.forEach(c => $('#list-' + c).empty());
        
        try {
            const req = await fetch('../api/quirofano_crud.pl?action=read&fecha=' + encodeURIComponent(fecha));
            const data = await req.json();
            
            cirugiasCargadas = Array.isArray(data) ? data : [];
            
            if (cirugiasCargadas.length > 0) {
                cirugiasCargadas.forEach(c => {
                    const anestesiaHtml = c.nombre_anestesio ? `<div class="text-truncate mt-0.5" title="Anestesiólogo: ${c.nombre_anestesio}"><i class="bi bi-lungs text-info me-1"></i>${c.nombre_anestesio}</div>` : '';
                    const salaLabel = c.sala ? c.sala : 'Sin Sala';
                    const salaHtml = `<span class="badge bg-light text-dark border px-2 py-0.5 fw-bold" style="font-size: 0.72rem;">${salaLabel}</span>`;
                    const iniciales = obtenerIniciales(c.nombre_paciente);
                    
                    const searchIndex = `${c.nombre_paciente || ''} ${c.procedimiento || ''} ${c.nombre_medico || ''} ${c.sala || ''} ${c.notas || ''}`.toLowerCase();
                    
                    const card = `
                        <div class="kanban-card" data-id="${c.id_cirugia}" data-medico-id="${c.id_medico || ''}" data-search="${searchIndex.replace(/"/g, '&quot;')}" onclick="abrirModalDetalleCirugia('${c.id_cirugia}')">
                            <div class="d-flex justify-content-between align-items-center mb-1.5">
                                <span class="badge bg-primary-subtle text-primary border border-primary-subtle rounded-pill px-2 py-0.5 fw-bold" style="font-size: 0.72rem;">
                                    <i class="bi bi-clock me-1"></i>${c.hora || '00:00'}
                                </span>
                                ${salaHtml}
                            </div>
                            
                            <div class="d-flex align-items-center gap-2 mb-1.5">
                                <div class="avatar-monogram" title="${c.nombre_paciente}">${iniciales}</div>
                                <div class="overflow-hidden">
                                    <h6 class="fw-bold mb-0 text-dark text-truncate" style="font-size: 0.88rem;" title="${c.nombre_paciente}">${c.nombre_paciente}</h6>
                                    <div class="text-primary fw-semibold text-truncate" style="font-size: 0.76rem;" title="${c.procedimiento || 'Procedimiento'}">${c.procedimiento || 'Cirugía Programada'}</div>
                                </div>
                            </div>
                            
                            <div class="small text-muted border-top pt-1.5 mt-1" style="font-size: 0.73rem;">
                                <div class="text-truncate" title="Cirujano: ${c.nombre_medico}"><i class="bi bi-person-badge text-secondary me-1"></i>${c.nombre_medico}</div>
                                ${anestesiaHtml}
                            </div>
                        </div>
                    `;
                    
                    let targetId = 'list-' + c.estado;
                    const el = document.getElementById(targetId);
                    if (el) {
                        el.innerHTML += card;
                    }
                });
            }
            
            aplicarFiltrosLocales();
            
        } catch (e) {
            console.error(e);
            CrystalToast.fire({icon: 'error', title: 'Error al sincronizar tablero quirúrgico'});
        }
    }
    
    function aplicarFiltrosLocales() {
        const medicoFiltro = ($('#filtroMedico').val() || '').trim();
        const textoFiltro = ($('#filtroTexto').val() || '').trim().toLowerCase();
        
        const cards = document.querySelectorAll('.kanban-card');
        cards.forEach(card => {
            const cardMedico = (card.getAttribute('data-medico-id') || '').trim();
            const cardSearch = (card.getAttribute('data-search') || '').toLowerCase();
            
            const matchMedico = !medicoFiltro || (cardMedico === medicoFiltro);
            const matchTexto = !textoFiltro || cardSearch.includes(textoFiltro);
            
            if (matchMedico && matchTexto) {
                card.style.display = '';
            } else {
                card.style.display = 'none';
            }
        });
        
        actualizarContadores();
    }

    function actualizarContadores() {
        const columns = ['Programada', 'Pre-Operatorio', 'En Quirófano', 'Recuperación', 'Alta'];
        let totalGeneral = 0;
        
        columns.forEach(col => {
            const el = document.getElementById('list-' + col);
            if (!el) return;
            
            const tarjetasVisibles = el.querySelectorAll('.kanban-card:not([style*="display: none"])');
            const count = tarjetasVisibles.length;
            totalGeneral += count;
            
            const badge = document.getElementById('cnt-' + col);
            if (badge) badge.innerText = count;
            
            // Actualizar KPI pills superiores
            if (col === 'Programada') $('#kpi-prog').text(count);
            if (col === 'Pre-Operatorio') $('#kpi-preop').text(count);
            if (col === 'En Quirófano') $('#kpi-qx').text(count);
            if (col === 'Recuperación') $('#kpi-ucpa').text(count);
            if (col === 'Alta') $('#kpi-alta').text(count);
            
            // Si no hay tarjetas visibles en la columna, mostrar indicador premium sutil
            const hintExistente = el.querySelector('.empty-kanban-hint');
            if (count === 0) {
                if (!hintExistente) {
                    const emptyDiv = document.createElement('div');
                    emptyDiv.className = 'empty-kanban-hint';
                    emptyDiv.innerHTML = '<i class="bi bi-inbox d-block fs-3 mb-1 text-muted opacity-40"></i><span>Sin pacientes</span>';
                    el.appendChild(emptyDiv);
                }
            } else {
                if (hintExistente) {
                    hintExistente.remove();
                }
            }
        });
        
        $('#kpi-total').text(totalGeneral);
    }
    
    async function actualizarEstadoCirugia(id, estado) {
        try {
            const f = new URLSearchParams();
            f.append('action', 'update_status');
            f.append('id_cirugia', id);
            f.append('estado', estado);
            
            const req = await fetch('../api/quirofano_crud.pl', { method: 'POST', body: f });
            const res = await req.json();
            
            if(!res.ok) {
                CrystalToast.fire({icon: 'error', title: res.msg || 'Error al actualizar'});
                cargarTablero(fechaActualSeleccionada);
            } else {
                CrystalToast.fire({icon: 'success', title: `Movido a ${estado}`});
                // Actualizar cache local
                const c = cirugiasCargadas.find(item => String(item.id_cirugia) === String(id));
                if (c) c.estado = estado;
            }
        } catch(e) {
            CrystalToast.fire({icon: 'error', title: 'Falla de red al actualizar estado'});
            cargarTablero(fechaActualSeleccionada);
        }
    }

    function abrirModalDetalleCirugia(idCirugia) {
        const c = cirugiasCargadas.find(item => String(item.id_cirugia) === String(idCirugia));
        if (!c) return;

        $('#mdl_paciente_nombre').text(c.nombre_paciente || 'Paciente');
        $('#mdl_subtitulo').text(`ID Cirugía: #${c.id_cirugia} | Estado actual: ${c.estado}`);
        $('#mdl_procedimiento').text(c.procedimiento || 'Cirugía General');
        $('#mdl_sala').text(c.sala || 'Sala General');
        $('#mdl_horario').text(`${c.fecha || fechaActualSeleccionada} - ${c.hora || '00:00'} hrs`);
        $('#mdl_notas').text(c.notas && c.notas.trim().length > 0 ? c.notas : 'Sin notas u observaciones específicas.');
        $('#mdl_cirujano').text(c.nombre_medico || 'No asignado');
        $('#mdl_anestesio').text(c.nombre_anestesio || 'No especificado');

        if (c.id_paciente) {
            $('#mdl_btn_expediente').attr('href', `render_expediente_clinico.pl?id_paciente=${encodeURIComponent(c.id_paciente)}`).show();
            
            // Consultar semáforo de consentimiento para quirófano (NOM-004)
            $('#mdl_box_consentimiento').show();
            $('#mdl_semaforo_cons').html('<span class="badge bg-secondary-subtle text-secondary border px-2 py-0.5"><i class="bi bi-hourglass-split me-1"></i>Verificando...</span>');
            $('#mdl_cons_acciones').html('');

            fetch(`../api/consentimientos_api.pl?accion=list&id_paciente=${encodeURIComponent(c.id_paciente)}&ambito=USO_QUIROFANO`)
                .then(r => r.json())
                .then(res => {
                    if (res.ok && res.consentimientos && res.consentimientos.length > 0) {
                        const vinculado = res.consentimientos.find(cs => String(cs.id_cirugia) === String(idCirugia)) || res.consentimientos[0];
                        const estaFirmado = vinculado.firmas && vinculado.firmas.paciente;
                        const estaUtilizado = (vinculado.utilizado == 1 || vinculado.utilizado === '1');

                        if (estaFirmado) {
                            $('#mdl_semaforo_cons').html(`
                                <span class="badge bg-success-subtle text-success border border-success-subtle px-2 py-0.5 fw-bold">
                                    <i class="bi bi-shield-check me-1"></i> 🟢 Firmado (NOM-004)
                                </span>
                                <span class="badge ${estaUtilizado ? 'bg-primary-subtle text-primary border border-primary-subtle' : 'bg-warning-subtle text-dark border border-warning-subtle'}">
                                    ${estaUtilizado ? 'Utilizado / Vinculado' : 'Disponible'}
                                </span>
                            `);
                            $('#mdl_cons_acciones').html(`
                                <button type="button" class="btn btn-sm btn-outline-success fw-semibold" onclick="verConsentimientoQuirurgico('${c.id_paciente}', '${vinculado.id_consentimiento}')">
                                    <i class="bi bi-file-earmark-check me-1"></i>Ver Doc
                                </button>
                            `);
                        } else {
                            $('#mdl_semaforo_cons').html(`
                                <span class="badge bg-warning-subtle text-dark border border-warning-subtle px-2 py-0.5 fw-bold">
                                    <i class="bi bi-exclamation-triangle me-1"></i> 🟡 Pendiente de Firma
                                </span>
                            `);
                            $('#mdl_cons_acciones').html(`
                                <a href="render_expediente_clinico.pl?id_paciente=${encodeURIComponent(c.id_paciente)}#tab-11" target="_blank" class="btn btn-sm btn-outline-warning fw-semibold">
                                    <i class="bi bi-pen me-1"></i>Firmar
                                </a>
                            `);
                        }
                    } else {
                        $('#mdl_semaforo_cons').html(`
                            <span class="badge bg-danger-subtle text-danger border border-danger-subtle px-2 py-0.5 fw-bold">
                                <i class="bi bi-shield-x me-1"></i> 🔴 Sin Consentimiento Qx
                            </span>
                        `);
                        $('#mdl_cons_acciones').html(`
                            <a href="render_expediente_clinico.pl?id_paciente=${encodeURIComponent(c.id_paciente)}#tab-11" target="_blank" class="btn btn-sm btn-outline-danger fw-semibold">
                                <i class="bi bi-plus-circle me-1"></i>Emitir
                            </a>
                        `);
                    }
                })
                .catch(err => {
                    $('#mdl_semaforo_cons').html('<span class="badge bg-secondary text-white">No disponible</span>');
                });
        } else {
            $('#mdl_btn_expediente').hide();
            $('#mdl_box_consentimiento').hide();
        }

        // Renderizar transiciones de estado
        const estados = [
            { id: 'Programada', label: 'Programada', icon: 'bi-calendar-check', btn: 'btn-outline-secondary' },
            { id: 'Pre-Operatorio', label: 'Pre-Operatorio', icon: 'bi-hourglass-split', btn: 'btn-outline-warning' },
            { id: 'En Quirófano', label: 'En Quirófano', icon: 'bi-heart-pulse-fill', btn: 'btn-outline-danger' },
            { id: 'Recuperación', label: 'Recuperación (UCPA)', icon: 'bi-bandaid-fill', btn: 'btn-outline-primary' },
            { id: 'Alta', label: 'Alta / Concluida', icon: 'bi-check-circle-fill', btn: 'btn-outline-success' }
        ];

        let btnsHtml = '';
        estados.forEach(st => {
            const esActual = (c.estado === st.id);
            if (esActual) {
                btnsHtml += `<button class="btn btn-sm ${st.btn.replace('outline-', '')} text-white fw-bold py-1.5 text-start" disabled>
                    <i class="bi bi-check2-circle me-1.5"></i> Actual: ${st.label}
                </button>`;
            } else {
                btnsHtml += `<button class="btn btn-sm ${st.btn} py-1.5 text-start fw-semibold" onclick="cambiarEstadoDesdeModal('${c.id_cirugia}', '${st.id}')">
                    <i class="bi ${st.icon} me-1.5"></i> Mover a ${st.label}
                </button>`;
            }
        });
        $('#mdl_botones_transicion').html(btnsHtml);

        // Resetear a pestaña 1 y cargar dossier quirúrgico completo (Fases III y IV)
        const tabTrigger = document.querySelector('#pills-ficha-tab');
        if (tabTrigger) {
            const tabInstance = bootstrap.Tab.getOrCreateInstance(tabTrigger);
            tabInstance.show();
        }
        cargarDossierModal(c.id_cirugia);

        const modalEl = document.getElementById('modalDetalleCirugia');
        const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
        modal.show();
    }

    let dossierActual = null;

    async function cargarDossierModal(idCirugia) {
        try {
            $('#chk_id_cirugia').val(idCirugia);
            $('#nt_id_cirugia').val(idCirugia);
            $('#liq_id_cirugia').val(idCirugia);
            $('#btn_imprimir_nota_qx').attr('href', `imprimir_nota_quirurgica.pl?id_cirugia=${encodeURIComponent(idCirugia)}`);

            const res = await fetch(`../api/quirofano_crud.pl?action=get_surgical_record&id_cirugia=${encodeURIComponent(idCirugia)}`);
            const d = await res.json();
            if (!d.ok || !d.dossier) return;
            dossierActual = d.dossier;

            // 1. Hidratar Tab Pre-Op
            const pre = dossierActual.checklist_preop || {};
            $('#chk_identidad').prop('checked', !!pre.identidad_verificada);
            $('#chk_consentimiento').prop('checked', !!pre.consentimiento_firmado);
            $('#chk_sitio_marcado').prop('checked', !!pre.sitio_marcado);
            $('#chk_alergias').prop('checked', !!pre.alergias_verificadas);
            $('#chk_ayuno').prop('checked', !!pre.ayuno_confirmado);
            $('#chk_horas_ayuno').val(pre.horas_ayuno || 8);
            $('#chk_labs').prop('checked', !!pre.labs_validados);
            $('#chk_via').prop('checked', !!pre.via_permeable);
            $('#chk_profilaxis').prop('checked', !!pre.profilaxis_antibiotica);
            $('#chk_observaciones').val(pre.observaciones_enfermeria || '');

            // 2. Hidratar Tab Nota Quirúrgica & UCPA
            const tr = dossierActual.transoperatorio || {};
            $('#nt_t_ingreso').val(tr.hora_ingreso_sala || '');
            $('#nt_t_anestesia').val(tr.hora_inicio_anestesia || '');
            $('#nt_t_incision').val(tr.hora_incision || '');
            $('#nt_t_cierre').val(tr.hora_cierre || '');
            $('#nt_t_salida').val(tr.hora_salida_sala || '');
            $('#nt_conteo_gasas').prop('checked', !!tr.conteo_gasas_completo);
            $('#nt_conteo_compresas').prop('checked', !!tr.conteo_compresas_completo);
            $('#nt_conteo_instrumental').prop('checked', !!tr.conteo_instrumental_completo);
            $('#nt_incidentes').val(tr.incidentes_accidentes || '');

            const nq = dossierActual.nota_quirurgica || {};
            $('#nt_dx_preop').val(nq.diagnostico_preop || dossierActual.procedimiento || '');
            $('#nt_dx_postop').val(nq.diagnostico_postop || nq.diagnostico_preop || dossierActual.procedimiento || '');
            $('#nt_op_planeada').val(nq.operacion_planeada || dossierActual.procedimiento || '');
            $('#nt_op_realizada').val(nq.operacion_realizada || dossierActual.procedimiento || '');
            $('#nt_tecnica').val(nq.descripcion_tecnica || '');
            $('#nt_hallazgos').val(nq.hallazgos || '');
            $('#nt_sangrado').val(nq.sangrado_aprox_ml || '0');
            $('#nt_patologia').val(nq.piezas_patologia || '');

            const ald = dossierActual.recuperacion_ucpa || {};
            $('#nt_ald_act').val(ald.aldrete_actividad !== undefined ? ald.aldrete_actividad : 2);
            $('#nt_ald_res').val(ald.aldrete_respiracion !== undefined ? ald.aldrete_respiracion : 2);
            $('#nt_ald_cir').val(ald.aldrete_circulacion !== undefined ? ald.aldrete_circulacion : 2);
            $('#nt_ald_con').val(ald.aldrete_conciencia !== undefined ? ald.aldrete_conciencia : 2);
            $('#nt_ald_sat').val(ald.aldrete_saturacion !== undefined ? ald.aldrete_saturacion : 2);
            calcularAldrete();

            // 3. Hidratar Tab Pre-Liquidación & Caja
            const liq = dossierActual.liquidacion_insumos || {};
            $('#liq_horas_sala').val(liq.horas_sala || 1);
            $('#liq_costo_hora').val(liq.costo_hora_sala || 1500);
            $('#liq_hon_cir').val(liq.honorarios_cirujano || 0);
            $('#liq_hon_ane').val(liq.honorarios_anestesio || 0);

            $('#tbodyInsumosQx').empty();
            const itemsInsumos = Array.isArray(liq.insumos) ? liq.insumos : [];
            if (itemsInsumos.length > 0) {
                itemsInsumos.forEach(item => {
                    agregarFilaInsumo(item.concepto || item.item || '', item.cantidad || item.cant || 1, item.precio || 0);
                });
            } else {
                agregarFilaInsumo('Kit Básico Quirúrgico Desechable', 1, 450);
            }
            calcularTotalLiquidacion();

            if (liq.registrado_en_caja) {
                $('#box_estado_caja').html(`<span class="badge bg-success-subtle text-success border border-success-subtle px-2 py-1 fw-bold"><i class="bi bi-check-circle-fill me-1"></i> Inyectado a Caja (${liq.id_movimiento_caja || 'Registrado'})</span>`);
                $('#btn_enviar_caja').prop('disabled', true).addClass('opacity-50').html('<i class="bi bi-check2-all me-1"></i> Ya en Caja');
            } else {
                $('#box_estado_caja').html('<span class="badge bg-warning-subtle text-dark border border-warning-subtle px-2 py-1"><i class="bi bi-clock me-1"></i> Pendiente de enviar a Caja</span>');
                $('#btn_enviar_caja').prop('disabled', false).removeClass('opacity-50').html('<i class="bi bi-cash-stack me-1"></i> Enviar a Caja');
            }

        } catch(e) {
            console.error('Error al cargar dossier quirúrgico', e);
        }
    }

    function calcularAldrete() {
        const act = parseInt($('#nt_ald_act').val()) || 0;
        const res = parseInt($('#nt_ald_res').val()) || 0;
        const cir = parseInt($('#nt_ald_cir').val()) || 0;
        const con = parseInt($('#nt_ald_con').val()) || 0;
        const sat = parseInt($('#nt_ald_sat').val()) || 0;
        const total = act + res + cir + con + sat;

        const badge = $('#badge_aldrete_total');
        if (total >= 9) {
            badge.removeClass('bg-warning-subtle text-dark border-warning-subtle bg-danger-subtle text-danger border-danger-subtle')
                 .addClass('bg-success-subtle text-success border-success-subtle')
                 .html(`<i class="bi bi-check-circle me-1"></i> ${total} / 10 Pts (Apto para Alta)`);
        } else {
            badge.removeClass('bg-success-subtle text-success border-success-subtle')
                 .addClass('bg-warning-subtle text-dark border-warning-subtle')
                 .html(`<i class="bi bi-hourglass-split me-1"></i> ${total} / 10 Pts (En Recuperación)`);
        }
    }

    function agregarFilaInsumo(concepto = '', cantidad = 1, precio = 0) {
        const tr = `
            <tr>
                <td><input type="text" class="form-control form-control-sm in-insumo-concepto" value="${concepto}" placeholder="Ej: Sutura, Gasas, Fármaco" oninput="calcularTotalLiquidacion()"></td>
                <td><input type="number" min="1" step="1" class="form-control form-control-sm text-center in-insumo-cant" value="${cantidad}" oninput="calcularTotalLiquidacion()"></td>
                <td><input type="number" min="0" step="0.5" class="form-control form-control-sm in-insumo-precio" value="${precio}" oninput="calcularTotalLiquidacion()"></td>
                <td class="text-center"><button type="button" class="btn btn-xs btn-outline-danger border-0" onclick="eliminarFilaInsumo(this)"><i class="bi bi-trash"></i></button></td>
            </tr>
        `;
        $('#tbodyInsumosQx').append(tr);
        calcularTotalLiquidacion();
    }

    function eliminarFilaInsumo(btn) {
        $(btn).closest('tr').remove();
        calcularTotalLiquidacion();
    }

    function recolectarInsumos() {
        const insumos = [];
        $('#tbodyInsumosQx tr').each(function() {
            const concepto = $(this).find('.in-insumo-concepto').val();
            const cant = parseFloat($(this).find('.in-insumo-cant').val()) || 0;
            const precio = parseFloat($(this).find('.in-insumo-precio').val()) || 0;
            if (concepto && concepto.trim().length > 0) {
                insumos.push({ concepto: concepto.trim(), cantidad: cant, precio: precio });
            }
        });
        return insumos;
    }

    function calcularTotalLiquidacion() {
        const horas = parseFloat($('#liq_horas_sala').val()) || 0;
        const costoHora = parseFloat($('#liq_costo_hora').val()) || 0;
        const honCir = parseFloat($('#liq_hon_cir').val()) || 0;
        const honAne = parseFloat($('#liq_hon_ane').val()) || 0;

        let totalInsumos = 0;
        $('#tbodyInsumosQx tr').each(function() {
            const cant = parseFloat($(this).find('.in-insumo-cant').val()) || 0;
            const precio = parseFloat($(this).find('.in-insumo-precio').val()) || 0;
            totalInsumos += (cant * precio);
        });

        const total = (horas * costoHora) + honCir + honAne + totalInsumos;
        $('#lbl_total_liquidacion').text('$' + total.toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
        return total;
    }

    async function guardarChecklistPreop(e) {
        e.preventDefault();
        try {
            const f = new FormData(document.getElementById('formChecklistPreop'));
            f.append('action', 'save_preop_checklist');
            const searchParams = new URLSearchParams(f);

            const req = await fetch('../api/quirofano_crud.pl', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: searchParams
            });
            const res = await req.json();
            if (res.ok) {
                CrystalToast.fire({ icon: 'success', title: 'Checklist Pre-Op OMS Guardado' });
            } else {
                CrystalToast.fire({ icon: 'error', title: res.msg || 'Error al guardar' });
            }
        } catch(err) {
            CrystalToast.fire({ icon: 'error', title: 'Falla de red' });
        }
    }

    async function guardarNotaQuirurgica(e) {
        e.preventDefault();
        try {
            const f = new FormData(document.getElementById('formNotaQuirurgica'));
            f.append('action', 'save_surgical_note');
            const searchParams = new URLSearchParams(f);

            const req = await fetch('../api/quirofano_crud.pl', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: searchParams
            });
            const res = await req.json();
            if (res.ok) {
                CrystalToast.fire({ icon: 'success', title: 'Nota Quirúrgica y Aldrete Guardados' });
            } else {
                CrystalToast.fire({ icon: 'error', title: res.msg || 'Error al guardar' });
            }
        } catch(err) {
            CrystalToast.fire({ icon: 'error', title: 'Falla de red' });
        }
    }

    async function guardarLiquidacionCaja(e) {
        if (e) e.preventDefault();
        try {
            const insumos = recolectarInsumos();
            const total = calcularTotalLiquidacion();

            const f = new FormData(document.getElementById('formLiquidacionCaja'));
            f.append('action', 'save_financial_closure');
            f.append('insumos_json', JSON.stringify(insumos));
            f.append('total_calculado', total);
            f.append('enviar_a_caja', '0');
            const searchParams = new URLSearchParams(f);

            const req = await fetch('../api/quirofano_crud.pl', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: searchParams
            });
            const res = await req.json();
            if (res.ok) {
                CrystalToast.fire({ icon: 'success', title: 'Borrador de Liquidación Guardado' });
            } else {
                CrystalToast.fire({ icon: 'error', title: res.msg || 'Error al guardar' });
            }
        } catch(err) {
            CrystalToast.fire({ icon: 'error', title: 'Falla de red' });
        }
    }

    async function inyectarCirugiaACaja() {
        const idCir = $('#liq_id_cirugia').val();
        if (!idCir) return;

        const total = calcularTotalLiquidacion();
        const confirmacion = await Swal.fire({
            title: '¿Enviar Liquidación a Caja?',
            html: `Se generará un cargo oficial en el Estado de Cuenta del paciente por <strong class="text-success">$${total.toFixed(2)}</strong> para ser cobrado en ventanilla de caja.`,
            icon: 'question',
            showCancelButton: true,
            confirmButtonText: 'Sí, Inyectar a Caja',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#198754'
        });

        if (!confirmacion.isConfirmed) return;

        try {
            const insumos = recolectarInsumos();
            const f = new FormData(document.getElementById('formLiquidacionCaja'));
            f.append('action', 'save_financial_closure');
            f.append('insumos_json', JSON.stringify(insumos));
            f.append('total_calculado', total);
            f.append('enviar_a_caja', '1');
            const searchParams = new URLSearchParams(f);

            const req = await fetch('../api/quirofano_crud.pl', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: searchParams
            });
            const res = await req.json();
            if (res.ok) {
                Swal.fire({
                    icon: 'success',
                    title: '¡Cargo Inyectado a Caja!',
                    text: `Registrado en Estado de Cuenta con Folio #${res.id_movimiento_caja}. El personal de caja ya puede procesar el cobro.`,
                    timer: 3000
                });
                $('#box_estado_caja').html(`<span class="badge bg-success-subtle text-success border border-success-subtle px-2 py-1 fw-bold"><i class="bi bi-check-circle-fill me-1"></i> Inyectado a Caja (${res.id_movimiento_caja})</span>`);
                $('#btn_enviar_caja').prop('disabled', true).addClass('opacity-50').html('<i class="bi bi-check2-all me-1"></i> Ya en Caja');
            } else {
                Swal.fire({ icon: 'error', title: 'Error', text: res.msg || 'No se pudo inyectar a caja' });
            }
        } catch(err) {
            Swal.fire({ icon: 'error', title: 'Error de red', text: 'No se pudo comunicar con el servidor' });
        }
    }

    async function verConsentimientoQuirurgico(idPaciente, idConsentimiento) {
        try {
            const res = await fetch(`../api/consentimientos_api.pl?accion=get&id_paciente=${encodeURIComponent(idPaciente)}&id_consentimiento=${encodeURIComponent(idConsentimiento)}`);
            const d = await res.json();
            if (!d.ok || !d.consentimiento) {
                Swal.fire({ icon: 'error', title: 'Error', text: d.msg || 'No se pudo cargar el consentimiento' });
                return;
            }
            const c = d.consentimiento;
            const tieneFirmaPac = c.firmas && c.firmas.paciente;
            const tieneFirmaMed = c.firmas && c.firmas.medico;

            Swal.fire({
                title: `<span class="fs-6 fw-bold text-navy"><i class="bi bi-shield-check text-success me-1"></i> Consentimiento Quirúrgico (NOM-004)</span>`,
                html: `
                    <div class="text-start small p-2">
                        <div class="d-flex justify-content-between mb-2 border-bottom pb-1">
                            <span class="badge bg-primary-subtle text-primary border">Folio: ${c.folio_formato || c.id_consentimiento}</span>
                            <span class="badge ${c.utilizado == 1 ? 'bg-success-subtle text-success border border-success-subtle' : 'bg-warning-subtle text-dark border border-warning-subtle'}">
                                ${c.utilizado == 1 ? '🟢 Utilizado' : '🟡 Disponible'}
                            </span>
                        </div>
                        <div class="mb-2">
                            <strong class="text-secondary d-block">Procedimiento Propuesto:</strong>
                            <div class="fw-bold text-dark">${c.procedimiento_propuesto || 'No especificado'}</div>
                        </div>
                        <div class="mb-2">
                            <strong class="text-secondary d-block">Diagnóstico:</strong>
                            <div>${c.diagnostico || 'No especificado'}</div>
                        </div>
                        <div class="mb-2">
                            <strong class="text-secondary d-block">Riesgos y Beneficios:</strong>
                            <div class="text-muted fst-italic bg-light p-2 rounded border">${c.riesgos_beneficios || 'No especificado'}</div>
                        </div>
                        <div class="row g-2 pt-2 border-top text-center">
                            <div class="col-6">
                                <span class="d-block small text-muted">Firma Paciente:</span>
                                ${tieneFirmaPac ? `<img src="${c.firmas.paciente}" style="max-height: 48px; max-width: 100%;" class="border rounded bg-white p-1" />` : '<span class="text-danger">Pendiente</span>'}
                            </div>
                            <div class="col-6">
                                <span class="d-block small text-muted">Firma Médico:</span>
                                ${tieneFirmaMed ? `<img src="${c.firmas.medico}" style="max-height: 48px; max-width: 100%;" class="border rounded bg-white p-1" />` : '<span class="text-muted">En expediente</span>'}
                            </div>
                        </div>
                    </div>
                `,
                confirmButtonText: 'Cerrar',
                customClass: {
                    popup: 'rounded-4 shadow-lg'
                }
            });
        } catch(e) {
            Swal.fire({ icon: 'error', title: 'Error', text: 'Falla al recuperar documento legal' });
        }
    }

    async function cambiarEstadoDesdeModal(idCirugia, nuevoEstado) {
        const modalEl = document.getElementById('modalDetalleCirugia');
        const modal = bootstrap.Modal.getInstance(modalEl);
        if (modal) modal.hide();
        
        await actualizarEstadoCirugia(idCirugia, nuevoEstado);
        cargarTablero(fechaActualSeleccionada);
    }
</script>
JS

# Render Footer
render_bottom_nav('hospital');
print "</body></html>\n";
1;
