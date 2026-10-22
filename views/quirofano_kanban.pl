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
    <div class="modal-dialog modal-dialog-centered modal-lg">
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
            <div class="modal-body p-4 bg-light">
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

        const modalEl = document.getElementById('modalDetalleCirugia');
        const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
        modal.show();
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
