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

utils::sub_sidebar::render_sidebar(
    usuario       => $usuario,
    role          => $role,
    id_medico     => $id_usuario_sesion,
    pagina_actual => 'quirofano_kanban'
);

print <<"HTML";
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme\@1.3.0/dist/select2-bootstrap-5-theme.min.css" />
<link rel="stylesheet" href="../css/sdm_mobile_standards.css" />
<link rel="stylesheet" href="../css/quirofano_wizard.css" />
<script src="https://cdn.jsdelivr.net/npm/sortablejs\@latest/Sortable.min.js"></script>

<main class="container-fluid container-mobile-flush pb-4 animate__animated animate__fadeIn kanban-wrapper kanban-wrapper-compact">

    <!-- CABECERA EJECUTIVA DE 3 FILAS (THREE-TIER TOOLBAR CON BORDE TEAL RAISED ESTILO FINANZAS & AGENDAS) -->
    <header class="qx-executive-three-tier">
        <!-- FILA 1: CABECERA NAVY CONTEXTUAL + ACCIONES PRIORITARIAS -->
        <div class="qx-tier1-navy">
            <div class="qx-tier1-brand">
                <span class="qx-tier1-icon">
                    <i class="bi bi-heart-pulse-fill"></i>
                </span>
                <span>Tablero Quirúrgico &amp; Control Transoperatorio</span>
                <span class="opacity-50 d-none d-sm-inline">•</span>
                <span class="qx-tier1-date-pill">
                    <span class="pulse-live"></span>
                    <span>En Vivo:</span>
                    <span id="lblFechaHoy"></span>
                </span>
            </div>

            <div class="d-flex align-items-center gap-2 ms-auto">
                <a href="agenda_espacios.pl" class="btn-qx-tier1-ghost" title="Ver disponibilidad en Agenda de Renta de Espacios">
                    <i class="bi bi-door-open-fill text-teal"></i>
                    <span class="d-none d-md-inline">Agenda Espacios</span>
                </a>
                <a href="quirofano_ingreso.pl" class="btn-qx-tier1-action" title="Iniciar Wizard de 6 Pasos para Nuevo Ingreso Quirúrgico">
                    <i class="bi bi-plus-circle-fill"></i>
                    <span>+ Nuevo Ingreso (Wizard)</span>
                </a>
                <button type="button" class="btn-qx-tier1-ghost" onclick="cargarTablero(fechaActualSeleccionada)" title="Sincronizar tablero en vivo">
                    <i class="bi bi-arrow-clockwise"></i>
                </button>
            </div>
        </div>

        <!-- FILA 2: BANDEJA OPERATIVA DE NAVEGACIÓN TEMPORAL Y FILTROS DIRECTOS (SIN ETIQUETAS RUIDOSAS) -->
        <div class="qx-tier2-controls">
            <div class="d-flex align-items-center flex-wrap gap-2">
                <button type="button" id="btnFechaHoy" class="btn-qx-today-pill" title="Ir al Día de Hoy">HOY</button>

                <div class="qx-date-nav-pill">
                    <button type="button" id="btnFechaAnt" class="qx-date-chevron" title="Día Anterior">
                        <i class="bi bi-chevron-left"></i>
                    </button>
                    <input type="date" id="filtroFecha" class="qx-date-input-clean" title="Seleccionar fecha quirúrgica">
                    <button type="button" id="btnFechaSig" class="qx-date-chevron" title="Día Siguiente">
                        <i class="bi bi-chevron-right"></i>
                    </button>
                </div>

                <button type="button" id="btnVerTodasFechas" class="qx-filter-pill-box fw-bold text-navy" onclick="alternarTodasLasFechas()" title="Mostrar cirugías de todas las fechas">
                    <i class="bi bi-calendar-range text-teal"></i>
                    <span id="lblBtnTodasFechas" class="small">Todas las fechas</span>
                </button>
            </div>

            <div class="d-flex align-items-center flex-wrap gap-2 ms-auto">
                <!-- Selector Directo de Cirujano -->
                <div class="qx-filter-pill-box">
                    <i class="bi bi-person-badge-fill text-teal"></i>
                    <select id="filtroMedico" class="qx-filter-select-clean">
                        <option value="">Todos los Cirujanos</option>
                        $medicos_options_filtro
                    </select>
                </div>

                <!-- Buscador Directo en Píldora -->
                <div class="qx-filter-pill-box">
                    <i class="bi bi-search text-teal"></i>
                    <input type="text" id="filtroTexto" class="qx-filter-input-clean" placeholder="Buscar paciente, folio, sala, cirugía...">
                    <button type="button" id="btnLimpiarTexto" class="btn btn-sm p-0 border-0 text-muted" title="Limpiar filtro" style="display:none;">
                        <i class="bi bi-x-circle-fill"></i>
                    </button>
                </div>
            </div>
        </div>

        <!-- FILA 3: BARRA DE MICRO-CARDS KPI ESTILO FINANZAS.PL CON BORDES TEAL RAISED -->
        <div class="qx-tier3-kpis">
            <div class="qx-fin-kpi-card active-kpi-filter" data-kpi-est="" onclick="filtrarPorEstacionKpi('', this)" title="Clic para mostrar todas las estaciones">
                <span class="qx-fin-kpi-label"><i class="bi bi-grid-fill text-teal"></i> Total</span>
                <span id="kpi-total" class="qx-fin-kpi-val text-navy">0</span>
            </div>
            <div class="qx-fin-kpi-card" data-kpi-est="Programada" onclick="filtrarPorEstacionKpi('Programada', this)" title="Filtrar estación: Programadas">
                <span class="qx-fin-kpi-label"><i class="bi bi-calendar-check text-secondary"></i> Programadas</span>
                <span id="kpi-prog" class="qx-fin-kpi-val text-secondary">0</span>
            </div>
            <div class="qx-fin-kpi-card" data-kpi-est="Pre-Operatorio" onclick="filtrarPorEstacionKpi('Pre-Operatorio', this)" title="Filtrar estación: Pre-Operatorio">
                <span class="qx-fin-kpi-label"><i class="bi bi-hourglass-split text-warning"></i> Pre-Op</span>
                <span id="kpi-preop" class="qx-fin-kpi-val text-warning">0</span>
            </div>
            <div class="qx-fin-kpi-card" data-kpi-est="En Quirófano" onclick="filtrarPorEstacionKpi('En Quirófano', this)" title="Filtrar estación: En Quirófano">
                <span class="qx-fin-kpi-label"><span class="pulse-live"></span> En Quirófano</span>
                <span id="kpi-qx" class="qx-fin-kpi-val text-danger">0</span>
            </div>
            <div class="qx-fin-kpi-card" data-kpi-est="Recuperación" onclick="filtrarPorEstacionKpi('Recuperación', this)" title="Filtrar estación: Recuperación UCPA">
                <span class="qx-fin-kpi-label"><i class="bi bi-bandaid-fill text-primary"></i> Recuperación</span>
                <span id="kpi-ucpa" class="qx-fin-kpi-val text-primary">0</span>
            </div>
            <div class="qx-fin-kpi-card" data-kpi-est="Alta" onclick="filtrarPorEstacionKpi('Alta', this)" title="Filtrar estación: Alta / Concluidas">
                <span class="qx-fin-kpi-label"><i class="bi bi-check-circle-fill text-success"></i> Concluidas</span>
                <span id="kpi-alta" class="qx-fin-kpi-val text-success">0</span>
            </div>
        </div>
    </header>
    
    <!-- Tablero Kanban Fluid 5 Estaciones con Bordes Teal Raised -->
    <div class="kanban-board kanban-board-raised">
        
        <!-- PROGRAMADA -->
        <div class="kanban-col kanban-col-raised col-programada">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5"><i class="bi bi-calendar-check text-secondary"></i> Programada</span>
                <span class="badge bg-secondary badge-counter rounded-pill" id="cnt-Programada">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Programada" data-estado="Programada"></div>
        </div>
        
        <!-- PRE-OPERATORIO -->
        <div class="kanban-col kanban-col-raised col-preop">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5"><i class="bi bi-hourglass-split text-warning"></i> Pre-Operatorio</span>
                <span class="badge bg-warning text-dark badge-counter rounded-pill" id="cnt-Pre-Operatorio">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Pre-Operatorio" data-estado="Pre-Operatorio"></div>
        </div>
        
        <!-- EN QUIRÓFANO -->
        <div class="kanban-col kanban-col-raised col-quirofano">
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
        <div class="kanban-col kanban-col-raised col-recuperacion">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5"><i class="bi bi-bandaid-fill text-primary"></i> Recuperación</span>
                <span class="badge bg-primary badge-counter rounded-pill" id="cnt-Recuperación">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Recuperación" data-estado="Recuperación"></div>
        </div>
        
        <!-- ALTA / TRASLADO -->
        <div class="kanban-col kanban-col-raised col-alta">
            <div class="kanban-header">
                <span class="d-flex align-items-center gap-1.5"><i class="bi bi-check-circle-fill text-success"></i> Alta / Traslado</span>
                <span class="badge bg-success badge-counter rounded-pill" id="cnt-Alta">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Alta" data-estado="Alta"></div>
        </div>
        
    </div>

</main>

<!-- MODAL ZOOM CARD 360° (EFECTO ZOOM AL HACER CLIC EN LA TARJETA DE CUALQUIER ESTACIÓN) -->
<div class="modal fade modal-zoom-card" id="modalZoomCardQx" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
            <div class="zoom-card-header d-flex justify-content-between align-items-center">
                <div class="d-flex align-items-center gap-2.5">
                    <div class="qx-glance-avatar" id="zc_avatar" style="width:40px;height:40px;font-size:0.95rem;">PX</div>
                    <div>
                        <div class="d-flex align-items-center gap-2 flex-wrap">
                            <h5 class="fw-bold text-white mb-0" id="zc_paciente">Paciente</h5>
                            <span id="zc_badge_tipo" class="badge bg-info text-dark fw-bold">PROGRAMADA</span>
                            <span id="zc_badge_estado" class="badge bg-light text-navy fw-bold">Programada</span>
                        </div>
                        <div class="small text-white-50" id="zc_folio_meta">Folio #CIR-000</div>
                    </div>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Cerrar"></button>
            </div>

            <div class="modal-body p-3 p-md-4" style="background:#F8FBFF;">
                <!-- Banner de Alerta Paralela si aplica -->
                <div id="zc_alert_paralelo" class="alert alert-danger py-2 px-3 mb-3 d-none border-danger d-flex justify-content-between align-items-center">
                    <div>
                        <i class="bi bi-exclamation-triangle-fill me-1.5"></i>
                        <strong>Flujo en Paralelo de Urgencia Activo:</strong> Trámite de Recepción (Consentimiento) o Depósito en Caja (\$5,000) pendiente.
                    </div>
                    <a href="#" id="zc_btn_resolver_paralelo" class="btn btn-sm btn-danger fw-bold">Resolver en Paso 2</a>
                </div>

                <!-- Bloque 1: Ficha Clínica y Espacios (3 Mini-Cards con Borde Teal Raised estilo finanzas.pl) -->
                <div class="row g-2.5 mb-3">
                    <div class="col-12 col-md-4">
                        <div class="zoom-fin-card h-100">
                            <span class="qx-label"><i class="bi bi-clipboard2-pulse text-teal me-1"></i>Procedimiento &amp; Sala</span>
                            <div class="fw-bold text-navy" id="zc_procedimiento">-</div>
                            <div class="small text-muted mt-1" id="zc_sala_horario">-</div>
                        </div>
                    </div>
                    <div class="col-12 col-md-4">
                        <div class="zoom-fin-card h-100">
                            <span class="qx-label"><i class="bi bi-people-fill text-teal me-1"></i>Equipo Quirúrgico</span>
                            <div class="fw-bold text-navy" id="zc_cirujano">-</div>
                            <div class="small text-muted mt-1" id="zc_anestesiologo">-</div>
                        </div>
                    </div>
                    <div class="col-12 col-md-4">
                        <div class="zoom-fin-card h-100">
                            <span class="qx-label"><i class="bi bi-cash-coin text-teal me-1"></i>Insumos 3NF &amp; Garantía Caja</span>
                            <div class="fw-bold text-success fs-5 plus-jakarta" id="zc_total_insumos">\$0.00</div>
                            <div class="small text-muted mt-0.5" id="zc_deposito_info">-</div>
                        </div>
                    </div>
                </div>

                <!-- Bloque 2: Matriz Expandida de los 8 Semáforos en Tiempo Real -->
                <div class="qx-subcard mb-3">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <span class="qx-subcard-title mb-0 border-0 pb-0"><i class="bi bi-stoplights-fill text-teal me-1.5"></i>Semaforización Sincronizada de los 8 Actores</span>
                        <span class="small text-muted">Tiempo Real</span>
                    </div>
                    <div class="zoom-actor-grid" id="zc_actors_grid"></div>
                </div>

                <!-- Bloque 3: Transición Rápida de Estación Kanban -->
                <div class="qx-subcard">
                    <span class="qx-label mb-1.5"><i class="bi bi-arrows-move text-teal me-1"></i>Mover Tarjeta de Estación Kanban</span>
                    <div class="d-flex flex-wrap gap-1.5" id="zc_quick_move_btns"></div>
                </div>
            </div>

            <div class="modal-footer bg-white border-top px-3 py-2.5 d-flex flex-wrap justify-content-between align-items-center gap-2">
                <div class="d-flex flex-wrap gap-1.5">
                    <button type="button" class="btn btn-sm btn-outline-primary fw-bold" id="zc_btn_bitacora_clinica">
                        <i class="bi bi-journal-medical me-1"></i>Bitácora OMS / Nota Qx / Aldrete
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-dark fw-bold" id="zc_btn_imprimir_alta">
                        <i class="bi bi-printer-fill me-1"></i>Imprimir Alta &amp; Receta
                    </button>
                </div>
                <div class="d-flex gap-2">
                    <a href="#" id="zc_btn_ir_wizard" class="btn btn-sm btn-qx-tier1-action">
                        <i class="bi bi-magic"></i>
                        <span id="zc_lbl_ir_wizard">Abrir en Wizard</span>
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Modal de Inspección Quirúrgica Compacto y Alto Contraste (Estilos Mandantes Medentia Aura) -->
<div class="modal fade modal-qx-compact" id="modalDetalleCirugia" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header modal-qx-header">
                <div class="d-flex align-items-center gap-2">
                    <div class="p-1.5 bg-white bg-opacity-15 rounded-3 d-flex align-items-center justify-content-center" style="width: 36px; height: 36px;">
                        <i class="bi bi-heart-pulse-fill text-warning fs-5"></i>
                    </div>
                    <div>
                        <h6 class="modal-title fw-bold text-white mb-0" id="mdl_paciente_nombre" style="font-size: 0.98rem; letter-spacing: -0.2px;">Detalles Quirúrgicos</h6>
                        <small style="color: rgba(255,255,255,0.85); font-size: 0.72rem; font-weight: 500;" id="mdl_subtitulo">Expediente Clínico & Control Operatorio</small>
                    </div>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body modal-qx-body">
                <!-- Pestañas de Navegación Quirúrgica -->
                <ul class="nav nav-pills nav-pills-qx mb-2.5" id="pills-modal-qx" role="tablist">
                    <li class="nav-item flex-fill" role="presentation">
                        <button class="nav-link active" id="pills-ficha-tab" data-bs-toggle="pill" data-bs-target="#pills-ficha" type="button" role="tab">
                            <i class="bi bi-card-checklist me-1"></i> 1. Ficha & Sala
                        </button>
                    </li>
                    <li class="nav-item flex-fill" role="presentation">
                        <button class="nav-link" id="pills-preop-tab" data-bs-toggle="pill" data-bs-target="#pills-preop" type="button" role="tab">
                            <i class="bi bi-shield-check me-1"></i> 2. Checklist OMS
                        </button>
                    </li>
                    <li class="nav-item flex-fill" role="presentation">
                        <button class="nav-link" id="pills-nota-tab" data-bs-toggle="pill" data-bs-target="#pills-nota" type="button" role="tab">
                            <i class="bi bi-journal-medical me-1"></i> 3. Nota Qx & UCPA
                        </button>
                    </li>
                    <li class="nav-item flex-fill" role="presentation">
                        <button class="nav-link" id="pills-caja-tab" data-bs-toggle="pill" data-bs-target="#pills-caja" type="button" role="tab">
                            <i class="bi bi-cash-coin me-1"></i> 4. Liquidación & Caja
                        </button>
                    </li>
                </ul>

                <div class="tab-content" id="pills-modal-qxContent">
                    <!-- TAB 1: FICHA Y SALA -->
                    <div class="tab-pane fade show active" id="pills-ficha" role="tabpanel">
                        <div class="row g-2.5">
                            <!-- Resumen General -->
                            <div class="col-12 col-md-7">
                                <div class="qx-subcard h-100">
                                    <div class="qx-subcard-title d-flex align-items-center justify-content-between">
                                        <span><i class="bi bi-file-earmark-medical me-1 text-primary"></i> Información del Procedimiento</span>
                                    </div>
                                    <div class="mb-2">
                                        <span class="qx-label">Procedimiento Programado</span>
                                        <span class="qx-value" id="mdl_procedimiento"></span>
                                    </div>
                                    <div class="row g-2 mb-2">
                                        <div class="col-6">
                                            <span class="qx-label">Sala / Quirófano</span>
                                            <span class="badge bg-light text-dark border px-2 py-1 fw-bold font-monospace" style="font-size:0.75rem;" id="mdl_sala"></span>
                                        </div>
                                        <div class="col-6">
                                            <span class="qx-label">Horario Programado</span>
                                            <span class="badge bg-primary-subtle text-primary border border-primary-subtle px-2 py-1 fw-bold" style="font-size:0.75rem;" id="mdl_horario"></span>
                                        </div>
                                    </div>
                                    <!-- Semáforo Consentimiento Quirúrgico (NOM-004) -->
                                    <div class="mb-2 p-2 rounded-2 border" id="mdl_box_consentimiento" style="background: #ffffff; border-color: rgba(25, 183, 165, 0.3) !important;">
                                        <div class="d-flex justify-content-between align-items-center gap-2">
                                            <div>
                                                <span class="qx-label mb-0.5" style="color: var(--md-blue-deep, #0A2A66);">Consentimiento Quirúrgico (NOM-004)</span>
                                                <div id="mdl_semaforo_cons" class="mt-0.5 d-flex align-items-center gap-1.5 flex-wrap">
                                                    <span class="badge bg-secondary-subtle text-secondary border px-2 py-0.5" style="font-size:0.72rem;"><i class="bi bi-hourglass-split me-1"></i> Consultando...</span>
                                                </div>
                                            </div>
                                            <div id="mdl_cons_acciones"></div>
                                        </div>
                                    </div>
                                    <div>
                                        <span class="qx-label">Notas Clínicas / Indicaciones</span>
                                        <p class="small text-secondary bg-light p-2 rounded-2 border mb-0" style="font-size: 0.76rem; min-height: 44px;" id="mdl_notas">Sin notas registradas</p>
                                    </div>
                                </div>
                            </div>
                            <!-- Equipo y Transiciones Rápidas -->
                            <div class="col-12 col-md-5">
                                <div class="qx-subcard h-100 d-flex flex-column justify-content-between">
                                    <div>
                                        <div class="qx-subcard-title">
                                            <i class="bi bi-people me-1 text-primary"></i> Equipo Quirúrgico
                                        </div>
                                        <div class="mb-1.5">
                                            <span class="qx-label">Cirujano Titular</span>
                                            <span class="qx-value small" id="mdl_cirujano"></span>
                                        </div>
                                        <div class="mb-2.5">
                                            <span class="qx-label">Anestesiólogo</span>
                                            <span class="qx-value small" id="mdl_anestesio"></span>
                                        </div>
                                    </div>
                                    <div>
                                        <div class="qx-subcard-title mb-1.5">
                                            <i class="bi bi-arrow-left-right me-1 text-primary"></i> Transición de Estado
                                        </div>
                                        <div class="d-grid gap-1" id="mdl_botones_transicion">
                                            <!-- Se inyectan dinámicamente -->
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- TAB 2: CHECKLIST OMS PRE-OP -->
                    <div class="tab-pane fade" id="pills-preop" role="tabpanel">
                        <form id="formChecklistPreop" onsubmit="guardarChecklistPreop(event)">
                            <input type="hidden" id="chk_id_cirugia" name="id_cirugia">
                            <div class="row g-2.5">
                                <div class="col-12 col-md-6">
                                    <div class="qx-subcard h-100">
                                        <div class="qx-subcard-title">
                                            <i class="bi bi-person-check me-1 text-primary"></i> Seguridad del Paciente
                                        </div>
                                        <div class="form-check form-switch mb-1.5">
                                            <input class="form-check-input" type="checkbox" id="chk_identidad" name="identidad_verificada" value="1">
                                            <label class="qx-switch-label" for="chk_identidad">Identidad confirmada (2 identificadores)</label>
                                        </div>
                                        <div class="form-check form-switch mb-1.5">
                                            <input class="form-check-input" type="checkbox" id="chk_consentimiento" name="consentimiento_firmado" value="1">
                                            <label class="qx-switch-label" for="chk_consentimiento">Consentimiento Qx y Anestésico verificado</label>
                                        </div>
                                        <div class="form-check form-switch mb-1.5">
                                            <input class="form-check-input" type="checkbox" id="chk_sitio_marcado" name="sitio_marcado" value="1">
                                            <label class="qx-switch-label" for="chk_sitio_marcado">Sitio quirúrgico marcado por cirujano</label>
                                        </div>
                                        <div class="form-check form-switch mb-1">
                                            <input class="form-check-input" type="checkbox" id="chk_alergias" name="alergias_verificadas" value="1">
                                            <label class="qx-switch-label" for="chk_alergias">Alergias a fármacos verificadas</label>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-12 col-md-6">
                                    <div class="qx-subcard h-100">
                                        <div class="qx-subcard-title">
                                            <i class="bi bi-capsule me-1 text-primary"></i> Preparación Clínica y Vía
                                        </div>
                                        <div class="d-flex align-items-center justify-content-between mb-1.5">
                                            <div class="form-check form-switch mb-0">
                                                <input class="form-check-input" type="checkbox" id="chk_ayuno" name="ayuno_confirmado" value="1">
                                                <label class="qx-switch-label" for="chk_ayuno">Ayuno confirmado</label>
                                            </div>
                                            <div class="d-flex align-items-center gap-1">
                                                <input type="number" id="chk_horas_ayuno" name="horas_ayuno" class="qx-form-control text-center" style="width: 58px;" min="0" max="48" value="8">
                                                <span class="small text-muted" style="font-size:0.75rem;">hrs</span>
                                            </div>
                                        </div>
                                        <div class="form-check form-switch mb-1.5">
                                            <input class="form-check-input" type="checkbox" id="chk_labs" name="labs_validados" value="1">
                                            <label class="qx-switch-label" for="chk_labs">Laboratorios validados (TP/Hb/Rh)</label>
                                        </div>
                                        <div class="form-check form-switch mb-1.5">
                                            <input class="form-check-input" type="checkbox" id="chk_via" name="via_permeable" value="1">
                                            <label class="qx-switch-label" for="chk_via">Vía venosa permeable</label>
                                        </div>
                                        <div class="form-check form-switch mb-1">
                                            <input class="form-check-input" type="checkbox" id="chk_profilaxis" name="profilaxis_antibiotica" value="1">
                                            <label class="qx-switch-label" for="chk_profilaxis">Profilaxis antibiótica (&lt;60 min)</label>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-12">
                                    <div class="qx-subcard">
                                        <label class="qx-label mb-1" for="chk_observaciones">Observaciones / Notas de Enfermería Pre-Op</label>
                                        <textarea id="chk_observaciones" name="observaciones_enfermeria" class="qx-form-control w-100" rows="2" placeholder="Notas sobre el estado general del paciente, catéteres o indicaciones previas a sala..."></textarea>
                                        <div class="d-flex justify-content-end mt-2">
                                            <button type="submit" class="btn btn-sm text-white fw-bold px-3 py-1" style="background: var(--md-teal-clinical, #19B7A5); border-radius: 8px;">
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
                            <div class="row g-2.5">
                                <!-- Tiempos y Conteo de Seguridad -->
                                <div class="col-12 col-md-5">
                                    <div class="qx-subcard mb-2.5">
                                        <div class="qx-subcard-title">
                                            <i class="bi bi-clock-history me-1 text-primary"></i> Tiempos Quirúrgicos
                                        </div>
                                        <div class="row g-1.5">
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_t_ingreso">Ingreso Sala</label>
                                                <input type="time" id="nt_t_ingreso" name="hora_ingreso_sala" class="qx-form-control w-100">
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_t_anestesia">Inicio Anestesia</label>
                                                <input type="time" id="nt_t_anestesia" name="hora_inicio_anestesia" class="qx-form-control w-100">
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_t_incision">Incisión Qx</label>
                                                <input type="time" id="nt_t_incision" name="hora_incision" class="qx-form-control w-100">
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_t_cierre">Cierre de Piel</label>
                                                <input type="time" id="nt_t_cierre" name="hora_cierre" class="qx-form-control w-100">
                                            </div>
                                            <div class="col-12">
                                                <label class="qx-label" for="nt_t_salida">Salida a UCPA</label>
                                                <input type="time" id="nt_t_salida" name="hora_salida_sala" class="qx-form-control w-100">
                                            </div>
                                        </div>
                                    </div>
                                    <div class="qx-subcard">
                                        <div class="qx-subcard-title">
                                            <i class="bi bi-shield-lock me-1 text-success"></i> Seguridad Transoperatoria
                                        </div>
                                        <div class="form-check form-switch mb-1.5">
                                            <input class="form-check-input" type="checkbox" id="nt_conteo_gasas" name="conteo_gasas_completo" value="1">
                                            <label class="qx-switch-label" for="nt_conteo_gasas">Conteo Gasas Verificado (100%)</label>
                                        </div>
                                        <div class="form-check form-switch mb-1.5">
                                            <input class="form-check-input" type="checkbox" id="nt_conteo_compresas" name="conteo_compresas_completo" value="1">
                                            <label class="qx-switch-label" for="nt_conteo_compresas">Conteo Compresas (100%)</label>
                                        </div>
                                        <div class="form-check form-switch mb-1.5">
                                            <input class="form-check-input" type="checkbox" id="nt_conteo_instrumental" name="conteo_instrumental_completo" value="1">
                                            <label class="qx-switch-label" for="nt_conteo_instrumental">Conteo Instrumental Completo</label>
                                        </div>
                                        <div>
                                            <label class="qx-label" for="nt_incidentes">Incidentes / Accidentes</label>
                                            <input type="text" id="nt_incidentes" name="incidentes_accidentes" class="qx-form-control w-100" placeholder="Sin incidentes">
                                        </div>
                                    </div>
                                </div>
                                <!-- Nota Quirúrgica NOM-004 y Aldrete -->
                                <div class="col-12 col-md-7">
                                    <div class="qx-subcard">
                                        <div class="qx-subcard-title">
                                            <i class="bi bi-file-earmark-medical me-1 text-primary"></i> Nota Quirúrgica (NOM-004)
                                        </div>
                                        <div class="row g-1.5 mb-2">
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_dx_preop">Dx Preoperatorio</label>
                                                <input type="text" id="nt_dx_preop" name="diagnostico_preop" class="qx-form-control w-100" required>
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_dx_postop">Dx Postoperatorio</label>
                                                <input type="text" id="nt_dx_postop" name="diagnostico_postop" class="qx-form-control w-100" required>
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_op_planeada">Operación Planeada</label>
                                                <input type="text" id="nt_op_planeada" name="operacion_planeada" class="qx-form-control w-100">
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_op_realizada">Operación Realizada</label>
                                                <input type="text" id="nt_op_realizada" name="operacion_realizada" class="qx-form-control w-100" required>
                                            </div>
                                            <div class="col-12">
                                                <label class="qx-label" for="nt_tecnica">Técnica Quirúrgica</label>
                                                <textarea id="nt_tecnica" name="descripcion_tecnica" class="qx-form-control w-100" rows="2" placeholder="Vía de abordaje, disección, hallazgos, hemostasia y síntesis..."></textarea>
                                            </div>
                                            <div class="col-12">
                                                <label class="qx-label" for="nt_hallazgos">Hallazgos Quirúrgicos</label>
                                                <textarea id="nt_hallazgos" name="hallazgos" class="qx-form-control w-100" rows="1" placeholder="Detalles de anatomía o hallazgos visuales..."></textarea>
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_sangrado">Sangrado Aprox (ml)</label>
                                                <input type="text" id="nt_sangrado" name="sangrado_aprox_ml" class="qx-form-control w-100" placeholder="Ej: 50 ml">
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_patologia">Muestras a Patología</label>
                                                <input type="text" id="nt_patologia" name="piezas_patologia" class="qx-form-control w-100" placeholder="Ej: Apéndice cecal">
                                            </div>
                                        </div>

                                        <!-- Criterios Aldrete UCPA -->
                                        <div class="qx-subcard-title d-flex justify-content-between align-items-center mb-1.5 pt-1">
                                            <span><i class="bi bi-heart-pulse text-danger me-1"></i> Aldrete UCPA</span>
                                            <span id="badge_aldrete_total" class="badge bg-success-subtle text-success border border-success-subtle px-1.5 py-0.5 fw-bold" style="font-size:0.72rem;">10 / 10 Pts (Apto)</span>
                                        </div>
                                        <div class="row g-1.5 mb-2">
                                            <div class="col-4">
                                                <label class="qx-label" for="nt_ald_act">Actividad</label>
                                                <select id="nt_ald_act" name="aldrete_actividad" class="qx-form-control w-100" onchange="calcularAldrete()">
                                                    <option value="2">2 - Mueve 4 m.</option>
                                                    <option value="1">1 - Mueve 2 m.</option>
                                                    <option value="0">0 - No mueve</option>
                                                </select>
                                            </div>
                                            <div class="col-4">
                                                <label class="qx-label" for="nt_ald_res">Respiración</label>
                                                <select id="nt_ald_res" name="aldrete_respiracion" class="qx-form-control w-100" onchange="calcularAldrete()">
                                                    <option value="2">2 - Tose/respira</option>
                                                    <option value="1">1 - Disnea leve</option>
                                                    <option value="0">0 - Apnea</option>
                                                </select>
                                            </div>
                                            <div class="col-4">
                                                <label class="qx-label" for="nt_ald_cir">Circulación</label>
                                                <select id="nt_ald_cir" name="aldrete_circulacion" class="qx-form-control w-100" onchange="calcularAldrete()">
                                                    <option value="2">2 - PA ±20%</option>
                                                    <option value="1">1 - PA ±20-49%</option>
                                                    <option value="0">0 - PA ±50%</option>
                                                </select>
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_ald_con">Conciencia</label>
                                                <select id="nt_ald_con" name="aldrete_conciencia" class="qx-form-control w-100" onchange="calcularAldrete()">
                                                    <option value="2">2 - Despierto</option>
                                                    <option value="1">1 - Al llamado</option>
                                                    <option value="0">0 - No responde</option>
                                                </select>
                                            </div>
                                            <div class="col-6">
                                                <label class="qx-label" for="nt_ald_sat">Saturación O2</label>
                                                <select id="nt_ald_sat" name="aldrete_saturacion" class="qx-form-control w-100" onchange="calcularAldrete()">
                                                    <option value="2">2 - &gt;92% amb.</option>
                                                    <option value="1">1 - Con O2</option>
                                                    <option value="0">0 - &lt;90% con O2</option>
                                                </select>
                                            </div>
                                        </div>

                                        <div class="d-flex justify-content-between align-items-center mt-2 flex-wrap gap-1.5">
                                            <a href="#" target="_blank" id="btn_imprimir_nota_qx" class="btn btn-sm btn-outline-dark fw-bold px-2.5 py-1" style="font-size:0.75rem; border-radius: 8px;">
                                                <i class="bi bi-printer me-1"></i> Imprimir Nota
                                            </a>
                                            <button type="submit" class="btn btn-sm text-white fw-bold px-3 py-1" style="background: var(--md-blue-deep, #0A2A66); font-size:0.75rem; border-radius: 8px;">
                                                <i class="bi bi-save me-1"></i> Guardar Nota & Aldrete
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
                            <div class="row g-2.5">
                                <div class="col-12 col-md-5">
                                    <div class="qx-subcard h-100">
                                        <div class="qx-subcard-title">
                                            <i class="bi bi-stopwatch me-1 text-primary"></i> Tiempos y Honorarios
                                        </div>
                                        <div class="mb-1.5">
                                            <label class="qx-label" for="liq_horas_sala">Horas en Sala Qx</label>
                                            <input type="number" step="0.25" id="liq_horas_sala" name="horas_sala" class="qx-form-control w-100" value="1.0" oninput="calcularTotalLiquidacion()">
                                        </div>
                                        <div class="mb-1.5">
                                            <label class="qx-label" for="liq_costo_hora">Tarifa por Hora ($)</label>
                                            <input type="number" step="0.01" id="liq_costo_hora" name="costo_hora_sala" class="qx-form-control w-100" value="1500.00" oninput="calcularTotalLiquidacion()">
                                        </div>
                                        <div class="mb-1.5">
                                            <label class="qx-label" for="liq_hon_cir">Honorarios Cirujano ($)</label>
                                            <input type="number" step="0.01" id="liq_hon_cir" name="honorarios_cirujano" class="qx-form-control w-100" value="0.00" oninput="calcularTotalLiquidacion()">
                                        </div>
                                        <div class="mb-1">
                                            <label class="qx-label" for="liq_hon_ane">Honorarios Anestesiólogo ($)</label>
                                            <input type="number" step="0.01" id="liq_hon_ane" name="honorarios_anestesio" class="qx-form-control w-100" value="0.00" oninput="calcularTotalLiquidacion()">
                                        </div>
                                    </div>
                                </div>
                                <div class="col-12 col-md-7">
                                    <div class="qx-subcard h-100 d-flex flex-column justify-content-between">
                                        <div>
                                            <div class="d-flex justify-content-between align-items-center pb-1.5 mb-1.5 border-bottom">
                                                <div class="qx-subcard-title mb-0 border-0 pb-0">
                                                    <i class="bi bi-box-seam text-success me-1"></i> Insumos y Materiales
                                                </div>
                                                <button type="button" class="btn btn-xs fw-bold px-2 py-0.5" style="background: rgba(25,183,165,0.1); color: var(--md-teal-dark, #0D9488); border: 1px solid var(--md-teal-clinical, #19B7A5); border-radius: 6px; font-size: 0.72rem;" onclick="agregarFilaInsumo()">
                                                    <i class="bi bi-plus-circle me-1"></i> + Insumo
                                                </button>
                                            </div>
                                            <div class="table-responsive" style="max-height: 140px; overflow-y: auto;">
                                                <table class="table table-sm table-borderless align-middle mb-0" id="tablaInsumosQx">
                                                    <thead class="table-light" style="font-size: 0.72rem; color: #475569;">
                                                        <tr>
                                                            <th>Concepto / Material</th>
                                                            <th style="width: 60px;">Cant.</th>
                                                            <th style="width: 85px;">Precio U.</th>
                                                            <th style="width: 30px;"></th>
                                                        </tr>
                                                    </thead>
                                                    <tbody id="tbodyInsumosQx">
                                                        <!-- Filas dinámicas -->
                                                    </tbody>
                                                </table>
                                            </div>
                                        </div>

                                        <!-- Total y Acción Caja -->
                                        <div class="border-top pt-2 mt-2">
                                            <div class="d-flex justify-content-between align-items-center mb-2">
                                                <span class="fw-bold" style="font-size:0.8rem; color: #1e293b;">Total Pre-Liquidación Qx:</span>
                                                <span class="fs-6 fw-bold text-success font-monospace" id="lbl_total_liquidacion">$0.00</span>
                                            </div>
                                            <div class="d-flex justify-content-between align-items-center flex-wrap gap-1.5">
                                                <div id="box_estado_caja">
                                                    <span class="badge bg-secondary-subtle text-secondary border px-2 py-0.5" style="font-size:0.72rem;">No enviado a Caja</span>
                                                </div>
                                                <div class="d-flex gap-1.5">
                                                    <button type="submit" class="btn btn-sm btn-outline-secondary fw-semibold px-2.5 py-1" style="font-size:0.75rem; border-radius: 6px;">
                                                        <i class="bi bi-save me-1"></i> Guardar
                                                    </button>
                                                    <button type="button" class="btn btn-sm text-white fw-bold px-3 py-1 shadow-sm" id="btn_enviar_caja" onclick="inyectarCirugiaACaja()" style="background: #16a34a; font-size:0.75rem; border-radius: 6px;">
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
            <div class="modal-footer bg-white border-top px-3 py-2 d-flex justify-content-between align-items-center">
                <div>
                    <a href="#" id="mdl_btn_expediente" target="_blank" class="btn btn-sm fw-semibold px-3 py-1" style="background: rgba(10,42,102,0.06); color: var(--md-blue-deep, #0A2A66); border: 1.5px solid rgba(10,42,102,0.2); border-radius: 8px; font-size: 0.78rem;">
                        <i class="bi bi-folder2-open me-1"></i> Abrir Expediente
                    </a>
                </div>
                <button type="button" class="btn btn-sm btn-light border text-secondary fw-semibold px-3 py-1" data-bs-dismiss="modal" style="border-radius: 8px; font-size: 0.78rem;">Cerrar</button>
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

    let estacionKpiFiltro = '';
    let modoTodasLasFechas = false;

    function obtenerIniciales(nombre) {
        if (!nombre) return 'PX';
        const parts = nombre.trim().split(/\s+/);
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }

    function alternarTodasLasFechas() {
        modoTodasLasFechas = !modoTodasLasFechas;
        const btn = document.getElementById('btnVerTodasFechas');
        const lbl = document.getElementById('lblBtnTodasFechas');
        if (modoTodasLasFechas) {
            if (btn) btn.style.background = '#e6fcf5';
            if (lbl) lbl.textContent = 'Mostrando: Todas';
            $('#lblFechaHoy').text('TODAS LAS FECHAS');
            cargarTablero('todas');
        } else {
            if (btn) btn.style.background = '#ffffff';
            if (lbl) lbl.textContent = 'Todas las fechas';
            $('#lblFechaHoy').text(formatearFechaTexto(fechaActualSeleccionada));
            cargarTablero(fechaActualSeleccionada);
        }
    }

    function filtrarPorEstacionKpi(estacion, elCard) {
        estacionKpiFiltro = estacion || '';
        document.querySelectorAll('.qx-fin-kpi-card').forEach(k => k.classList.remove('active-kpi-filter'));
        if (elCard) elCard.classList.add('active-kpi-filter');

        document.querySelectorAll('.kanban-col').forEach(col => {
            const listEl = col.querySelector('.sortable-list');
            const estCol = listEl ? listEl.getAttribute('data-estado') : '';
            if (!estacionKpiFiltro || estCol === estacionKpiFiltro) {
                col.style.opacity = '1';
                col.style.filter = 'none';
            } else {
                col.style.opacity = '0.42';
                col.style.filter = 'grayscale(30%)';
            }
        });
    }
    
    async function cargarTablero(fechaFiltro) {
        const fecha = fechaFiltro || (modoTodasLasFechas ? 'todas' : fechaActualSeleccionada);
        
        const columnas = ['Programada', 'Pre-Operatorio', 'En\\ Quirófano', 'Recuperación', 'Alta'];
        columnas.forEach(c => $('#list-' + c).empty());
        
        try {
            const req = await fetch('../api/quirofano_crud.pl?action=read&fecha=' + encodeURIComponent(fecha));
            const data = await req.json();
            
            cirugiasCargadas = Array.isArray(data) ? data : [];
            
            if (cirugiasCargadas.length > 0) {
                cirugiasCargadas.forEach(c => {
                    const salaShort = (c.sala || 'Qx 1').replace(/Quir[oó]fano/i, 'Qx');
                    const iniciales = obtenerIniciales(c.nombre_paciente);
                    const tipoCir = (c.tipo_cirugia || 'PROGRAMADA').toUpperCase();
                    const tipoBadge = tipoCir === 'URGENCIAS'
                        ? `<span class="qx-glance-badge-urg" title="Cirugía de Urgencias (Flujo en Paralelo)"><i class="bi bi-lightning-charge-fill"></i> URG</span>`
                        : `<span class="qx-glance-badge-prog" title="Cirugía Programada">PROG</span>`;

                    const sem = c.semaforos || {};
                    const actorsOrder = [
                        { k: 'agenda_espacios', n: 'Agenda Espacios' },
                        { k: 'agenda_paciente', n: 'Agenda Paciente' },
                        { k: 'recepcion_consentimiento', n: 'Recepción/Consent.' },
                        { k: 'caja', n: 'Caja Depósito' },
                        { k: 'enfermeria', n: 'Enfermería Pre-Op' },
                        { k: 'quirofano', n: 'Quirófano' },
                        { k: 'recuperacion', n: 'Recuperación' },
                        { k: 'alta_receta', n: 'Alta/Receta' }
                    ];
                    const hasRedAlert = (sem.recepcion_consentimiento === 'ROJO' || sem.caja === 'ROJO');
                    const dotsHtml = actorsOrder.map(a => {
                        const st = (sem[a.k] || 'GRIS').toUpperCase();
                        let cls = 'dot-gris';
                        if (st === 'VERDE') cls = 'dot-verde';
                        else if (st === 'AMBAR') cls = 'dot-ambar';
                        else if (st === 'ROJO') cls = 'dot-rojo';
                        return `<span class="qx-glance-dot ${cls}" title="${a.n}: ${st}"></span>`;
                    }).join('');

                    const alertIcon = hasRedAlert
                        ? `<span class="text-danger fw-bold ms-1" style="font-size:0.65rem;" title="Trámite paralelo de Recepción/Caja pendiente"><i class="bi bi-exclamation-triangle-fill"></i></span>`
                        : '';

                    const pasoWiz = c.paso_actual_wizard || 1;
                    const totalIns = Number(c.total_insumos_3nf || 0).toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
                    const searchIndex = `${c.id_cirugia || ''} ${c.nombre_paciente || ''} ${c.procedimiento || ''} ${c.nombre_medico || ''} ${c.sala || ''} ${c.notas || ''} ${tipoCir}`.toLowerCase();
                    
                    const card = `
                        <div class="kanban-card qx-glance-card" data-id="${c.id_cirugia}" data-medico-id="${c.id_medico || ''}" data-search="${searchIndex.replace(/"/g, '&quot;')}" onclick="abrirModalZoomCard('${c.id_cirugia}')">
                            <!-- Fila 1: Hora, Sala Compacta y Badge de Modalidad -->
                            <div class="qx-glance-top">
                                <div class="d-flex align-items-center gap-1">
                                    <span class="qx-glance-time"><i class="bi bi-clock"></i>${c.hora || '00:00'}</span>
                                    <span class="qx-glance-room" title="${c.sala || 'Quirófano'}">${salaShort}</span>
                                </div>
                                ${tipoBadge}
                            </div>
                            
                            <!-- Fila 2: Avatar + Nombre Paciente + Procedimiento Limpio -->
                            <div class="qx-glance-patient-row">
                                <div class="qx-glance-avatar" title="${c.nombre_paciente}">${iniciales}</div>
                                <div class="overflow-hidden flex-grow-1">
                                    <div class="qx-glance-patient-name text-truncate" title="${c.nombre_paciente}">${c.nombre_paciente}</div>
                                    <div class="qx-glance-proc text-truncate" title="${c.procedimiento || 'Procedimiento'}">${c.procedimiento || 'Cirugía'}</div>
                                </div>
                            </div>

                            <!-- Cirujano en 1 línea limpia -->
                            <div class="qx-glance-doctor text-truncate" title="Cirujano: ${c.nombre_medico}">
                                <i class="bi bi-person-badge text-teal me-1"></i>${c.nombre_medico}
                            </div>

                            <!-- Fila 3: Barra de 8 Semáforos + Acumulado 3NF -->
                            <div class="qx-glance-status-bar" title="Clic para hacer Zoom 360° a los 8 semáforos y detalles">
                                <div class="qx-glance-dots">
                                    ${dotsHtml}
                                    ${alertIcon}
                                </div>
                                <span class="qx-glance-cost"><i class="bi bi-box-seam text-teal me-0.5"></i>\$${totalIns}</span>
                            </div>
                            
                            <!-- Fila 4: Acciones Rápidas (Zoom Card Modal + Wizard) -->
                            <div class="qx-glance-actions">
                                <button type="button" class="btn-glance-zoom" onclick="event.stopPropagation(); abrirModalZoomCard('${c.id_cirugia}')" title="Ampliar Tarjeta en Vista Zoom 360°">
                                    <i class="bi bi-arrows-angle-expand"></i> Zoom
                                </button>
                                <a href="quirofano_ingreso.pl?id_cirugia=${encodeURIComponent(c.id_cirugia)}&step=${pasoWiz}"
                                   onclick="event.stopPropagation();"
                                   class="btn-glance-wizard"
                                   title="Continuar en el Paso ${pasoWiz} del Wizard">
                                    <i class="bi bi-magic"></i> Paso ${pasoWiz}
                                </a>
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

    function abrirModalZoomCard(idCirugia) {
        const c = cirugiasCargadas.find(item => String(item.id_cirugia) === String(idCirugia));
        if (!c) return;

        const tipoCir = (c.tipo_cirugia || 'PROGRAMADA').toUpperCase();
        const pasoWiz = c.paso_actual_wizard || 1;
        const totalIns = Number(c.total_insumos_3nf || 0).toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

        $('#zc_avatar').text(obtenerIniciales(c.nombre_paciente));
        $('#zc_paciente').text(c.nombre_paciente || 'Paciente');
        $('#zc_folio_meta').text(`Folio Quirúrgico: #${c.id_cirugia} • Exp. Físico: ${c.expediente_fisico_folio || 'Asignado'} • Fecha: ${c.fecha || fechaActualSeleccionada}`);

        const badgeTipo = document.getElementById('zc_badge_tipo');
        if (badgeTipo) {
            badgeTipo.className = tipoCir === 'URGENCIAS' ? 'badge bg-danger text-white fw-bold' : 'badge bg-info text-dark fw-bold';
            badgeTipo.innerHTML = tipoCir === 'URGENCIAS' ? '<i class="bi bi-lightning-charge-fill me-1"></i>URGENCIAS' : 'PROGRAMADA';
        }
        $('#zc_badge_estado').text(`Estación: ${c.estado}`);

        $('#zc_procedimiento').text(c.procedimiento || 'Procedimiento Quirúrgico');
        $('#zc_sala_horario').html(`<i class="bi bi-door-open text-teal me-1"></i><strong>${c.sala || 'Quirófano 1'}</strong> • <i class="bi bi-clock ms-1 me-1"></i>${c.hora || '00:00'} hrs`);
        $('#zc_cirujano').html(`<i class="bi bi-person-badge text-primary me-1"></i>${c.nombre_medico || 'Sin Cirujano'}`);
        $('#zc_anestesiologo').html(`<i class="bi bi-lungs text-info me-1"></i>Anestesia: ${c.nombre_anestesio || 'Por asignar'}`);
        $('#zc_total_insumos').text('$' + totalIns);

        if (c.deposito_pagado) {
            $('#zc_deposito_info').html(`<span class="text-success fw-bold"><i class="bi bi-check-circle-fill me-1"></i>Depósito \$5,000 Pagado (${c.folio_recibo_caja || 'Recibo OK'})</span>`);
        } else {
            $('#zc_deposito_info').html(`<span class="text-danger fw-bold"><i class="bi bi-exclamation-circle-fill me-1"></i>Depósito \$5,000 Pendiente en Caja</span>`);
        }

        const sem = c.semaforos || {};
        const hasRedAlert = (sem.recepcion_consentimiento === 'ROJO' || sem.caja === 'ROJO');
        const alertBanner = document.getElementById('zc_alert_paralelo');
        if (alertBanner) {
            if (hasRedAlert) {
                alertBanner.classList.remove('d-none');
                document.getElementById('zc_btn_resolver_paralelo').href = `quirofano_ingreso.pl?id_cirugia=${encodeURIComponent(c.id_cirugia)}&step=2`;
            } else {
                alertBanner.classList.add('d-none');
            }
        }

        const actorsList = [
            { k: 'agenda_espacios', n: '1. Agenda Espacios', ic: 'bi-door-open-fill' },
            { k: 'agenda_paciente', n: '2. Agenda Paciente', ic: 'bi-calendar-check-fill' },
            { k: 'recepcion_consentimiento', n: '3. Recepción / Consent.', ic: 'bi-file-earmark-medical-fill' },
            { k: 'caja', n: '4. Caja ($5,000 Dep.)', ic: 'bi-cash-coin' },
            { k: 'enfermeria', n: '5. Enfermería Pre-Op', ic: 'bi-heart-pulse-fill' },
            { k: 'quirofano', n: '6. Quirófano', ic: 'bi-activity' },
            { k: 'recuperacion', n: '7. Recuperación UCPA', ic: 'bi-bandaid-fill' },
            { k: 'alta_receta', n: '8. Alta y Receta', ic: 'bi-clipboard2-check-fill' }
        ];

        const gridHtml = actorsList.map(a => {
            const st = (sem[a.k] || 'GRIS').toUpperCase();
            let dotCls = 'dot-gris';
            let boxCls = '';
            let lblSt = 'Pendiente';
            if (st === 'VERDE') { dotCls = 'dot-verde'; boxCls = 'st-verde'; lblSt = 'Validado'; }
            else if (st === 'AMBAR') { dotCls = 'dot-ambar'; boxCls = 'st-ambar'; lblSt = 'En proceso'; }
            else if (st === 'ROJO')  { dotCls = 'dot-rojo';  boxCls = 'st-rojo';  lblSt = 'Alerta Paralela'; }

            return `
                <div class="zoom-actor-box ${boxCls}">
                    <div class="overflow-hidden">
                        <div class="fw-bold text-navy text-truncate" style="font-size:0.74rem;"><i class="bi ${a.ic} text-teal me-1"></i>${a.n}</div>
                        <div class="text-muted" style="font-size:0.66rem;">${lblSt}</div>
                    </div>
                    <span class="qx-traffic-dot ${dotCls}"></span>
                </div>
            `;
        }).join('');
        $('#zc_actors_grid').html(gridHtml);

        const estaciones = ['Programada', 'Pre-Operatorio', 'En Quirófano', 'Recuperación', 'Alta'];
        const moveBtns = estaciones.map(est => {
            const active = (c.estado === est);
            return `<button type="button" class="btn btn-sm ${active ? 'btn-primary fw-bold' : 'btn-outline-secondary'}" ${active ? 'disabled' : ''} onclick="moverDesdeZoomCard('${c.id_cirugia}', '${est}')">
                        ${active ? '<i class="bi bi-check2-circle me-1"></i>' : ''}${est}
                    </button>`;
        }).join('');
        $('#zc_quick_move_btns').html(moveBtns);

        document.getElementById('zc_btn_ir_wizard').href = `quirofano_ingreso.pl?id_cirugia=${encodeURIComponent(c.id_cirugia)}&step=${pasoWiz}`;
        $('#zc_lbl_ir_wizard').text(`Retomar Wizard (Paso ${pasoWiz})`);

        document.getElementById('zc_btn_bitacora_clinica').onclick = function() {
            bootstrap.Modal.getInstance(document.getElementById('modalZoomCardQx')).hide();
            abrirModalDetalleCirugia(c.id_cirugia);
        };
        document.getElementById('zc_btn_imprimir_alta').onclick = function() {
            window.open(`imprimir_alta_quirurgica.pl?id_cirugia=${encodeURIComponent(c.id_cirugia)}`, '_blank');
        };

        const modalEl = document.getElementById('modalZoomCardQx');
        bootstrap.Modal.getOrCreateInstance(modalEl).show();
    }

    async function moverDesdeZoomCard(idCirugia, nuevoEstado) {
        const modalEl = document.getElementById('modalZoomCardQx');
        const m = bootstrap.Modal.getInstance(modalEl);
        if (m) m.hide();
        await actualizarEstadoCirugia(idCirugia, nuevoEstado);
        cargarTablero(modoTodasLasFechas ? 'todas' : fechaActualSeleccionada);
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
utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('hospital');
print "</body></html>\n";
1;
