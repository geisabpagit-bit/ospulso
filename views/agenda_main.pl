#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use File::Spec;
use open qw(:std :utf8);

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

# Validar sesión
unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario   = $sd->{usuario};
my $role      = $sd->{role};
my $id_medico = $sd->{id_medico};
my $id_negocio = $sd->{session} ? $sd->{session}->param('id_empresa') : '';
$id_negocio = '0' if (!defined $id_negocio || $id_negocio eq '');
my $id_sucursal = $sd->{session} ? $sd->{session}->param('id_sucursal') : '';
my $id_negocio_activo = ($id_sucursal && $id_sucursal ne '0') ? $id_sucursal : $id_negocio;

# Detección de Tipo de Organización
my $tipo_organizacion = 'Clínica';
my $archivo_config = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $archivo_config && open my $fh_c, '<:encoding(UTF-8)', $archivo_config) {
    my $cnt = 0;
    while (my $line = <$fh_c>) {
        $cnt++;
        $line =~ s/\R//g;
        next if $cnt == 1 || $line =~ /^\s*$/;
        my @f = split(/\|/, $line);
        if ($f[0] eq $id_negocio && $f[1] eq 'TIPO_ORGANIZACION') {
            $tipo_organizacion = $f[2] // 'Clínica';
            last;
        }
    }
    close $fh_c;
}
my $es_consultorio_ind = ($tipo_organizacion eq 'Consultorio Individual') ? 1 : 0;
my $es_consultorio = ($tipo_organizacion eq 'Consultorio Individual' || $tipo_organizacion eq 'Consultorio Compartido') ? 1 : 0;
my $btn_cobrar_recepcion_html = $es_consultorio ? '' : qq{<button type="button" id="btn-cobrar-recepcion" onclick="cobrarRecepcionModal()" class="btn btn-amber btn-compact d-none"><i class="bi bi-cash-coin me-1"></i> Cobrar en Recepción</button>};

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');

my $usuarios = leer_tabla($archivo_usuarios, '!');
my @medicos;
if ($usuarios) {
    foreach my $u (@$usuarios) {
        my $es_medico = ($u->[5] =~ /(?:^|,)Medico(?:,|$)/) || 
                        ($u->[5] =~ /Administrador/ && defined $u->[7] && $u->[7] ne '' && $u->[7] ne '0');
        if ($es_medico && ($u->[6] =~ /^$id_negocio:/ || ($id_negocio eq '0' && $u->[6] =~ /^0:/))) {
            push @medicos, { id => $u->[0], nombre => $u->[1] };
        }
    }
}
my $html_medicos = '';
foreach my $m (@medicos) {
    my $sel = ($m->{id} eq $id_medico) ? 'selected' : '';
    $html_medicos .= qq(<option value="$m->{id}" $sel>$m->{nombre}</option>\n);
}

my $negocios = leer_tabla($archivo_negocios, '\|');
my $nombre_sucursal = 'Clínica Principal';
if ($negocios) {
    foreach my $n (@$negocios) {
        if ($n->[0] eq $id_negocio_activo) {
            $nombre_sucursal = $n->[1];
            last;
        }
    }
}
$nombre_sucursal = 'Consultorio Principal' if ($es_consultorio_ind && ($nombre_sucursal eq 'Clínica Principal' || $nombre_sucursal eq ''));
my $html_sucursal = qq(<option value="$id_negocio_activo" selected>$nombre_sucursal</option>);

# 1. Cabecera Corporativa
print $q->header(-type => 'text/html', -charset => 'UTF-8');

my $id_paciente_pre = $q->param('new_cita_id') || '';
my $nombre_paciente_pre = $q->param('new_cita_nombre') || '';

render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => 'Agenda Cl&iacute;nica Inteligente',
    skip_header => 1
);

print <<HTML;
    <!-- Datos de Sesión para JS -->
    <input type="hidden" id="f_medico" value="$id_medico">
    <input type="hidden" id="agenda_es_individual" value="$es_consultorio_ind">
    <input type="hidden" id="agenda_es_consultorio" value="$es_consultorio">
    <input type="hidden" id="agenda_tipo_organizacion" value="$tipo_organizacion">
    <script>
        window.idPacientePre = "$id_paciente_pre";
        window.nombrePacientePre = "$nombre_paciente_pre";
    </script>

    <!-- DataTables CSS Core (Carga Paralela) -->
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">
    <link rel="stylesheet" href="../css/agenda_diamond.css?v=4.3.2">
HTML

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    pagina_actual => 'agenda'
);

print <<HTML;
    <div class="main-container-agenda">
        <header class="agenda-header sticky-top animate__animated animate__fadeInDown">
            <div class="container-fluid">
                <!-- ROW 1: TOOLS AND ACTIONS -->
                <div class="d-flex align-items-center justify-content-between gap-2 py-2">
                    
                    <!-- LADO IZQUIERDO: HOY + VISTAS + REPORTES -->
                    <div class="d-flex align-items-center gap-2">
                        <button onclick="goToday()" class="btn btn-navy fw-black rounded-3 px-3 shadow-sm text-uppercase" style="font-size:0.75rem; height:42px;">HOY</button>
                        
                        <!-- GRUPO VISTAS -->
                        <div class="nav-pill-group">
                            <button onclick="switchView('dia')" class="btn-view-toggle active" id="btn-v-dia" title="Vista Diaria"><i class="bi bi-calendar-event"></i></button>
                            <button onclick="switchView('semana_smart')" class="btn-view-toggle" id="btn-v-semana-smart" title="Vista Semanal Smart"><i class="bi bi-calendar-week"></i></button>
                            <button onclick="switchView('calendario')" class="btn-view-toggle" id="btn-v-calendario" title="Vista Mensual Grid"><i class="bi bi-grid-3x3"></i></button>
                        </div>

                        <!-- GRUPO REPORTES -->
                        <div class="nav-pill-group">
                            <button onclick="switchView('semana')" class="btn-report-toggle" id="btn-r-semana" title="Reporte Semanal"><i class="bi bi-file-earmark-text"></i></button>
                            <button onclick="switchView('mes')" class="btn-report-toggle" id="btn-r-mes" title="Reporte Mensual"><i class="bi bi-file-earmark-bar-graph"></i></button>
                        </div>
                    </div>

                    <!-- CENTRO (Solo Desktop): NAVEGACIÓN DE FECHA -->
                    <div class="d-none d-md-flex align-items-center date-nav-pill mx-auto">
                        <button onclick="moveDate(-1)" class="btn btn-link text-navy p-2"><i class="bi bi-chevron-left"></i></button>
                        <h1 class="h6 mb-0 fw-black text-navy text-uppercase tracking-tight mx-2" id="current-date-label-desktop" style="min-width: 180px; text-align: center;">
                            CARGANDO...
                        </h1>
                        <button onclick="moveDate(1)" class="btn btn-link text-navy p-2"><i class="bi bi-chevron-right"></i></button>
                    </div>

                    <div class="d-none d-md-flex align-items-center gap-2">
                        <button onclick="abrirModalAjustes()" class="btn btn-light fw-bold rounded-3 shadow-sm border bg-white" style="height:42px; width:42px; padding:0;"><i class="bi bi-gear-fill"></i></button>
                    </div>

                </div>

                <!-- ROW 2 (Solo Móvil): NAVEGACIÓN DE FECHA -->
                <div class="d-flex d-md-none justify-content-center pb-2">
                    <div class="d-flex align-items-center justify-content-between date-nav-pill w-100 mx-0">
                        <button onclick="moveDate(-1)" class="btn btn-link text-navy p-2"><i class="bi bi-chevron-left"></i></button>
                        <h1 class="h6 mb-0 fw-black text-navy text-uppercase tracking-tight mx-2" id="current-date-label-mobile" style="text-align: center;">
                            CARGANDO...
                        </h1>
                        <button onclick="moveDate(1)" class="btn btn-link text-navy p-2"><i class="bi bi-chevron-right"></i></button>
                    </div>
                </div>
            </div>
        </header>

        <main id="app-viewport" class="container-fluid px-1 px-md-3 pt-1 pb-4">
            <!-- VISTA DIARIA (Timeline) -->
            <div id="view-dia" class="agenda-view-container">
                <div class="row g-4">
                    <!-- Panel Izquierdo: Mini Calendario (Desktop Only) -->
                    <!-- Panel Izquierdo: Mini Calendario (Sticky) -->
                    <div class="col-lg-3 d-none d-lg-block">
                        <div class="card border-0 shadow-sm p-3 sticky-top agenda-side-card" style="top:100px;">
                            <h6 class="fw-black text-navy mb-3 text-uppercase small tracking-widest">Navegación</h6>
                            <div id="side-datepicker"></div>
                            <hr class="opacity-10 my-3">
                            <button class="btn btn-light w-100 btn-sm text-start fw-bold rounded-3 py-2 border" onclick="goToday()">
                                <i class="bi bi-calendar2-check me-2 text-primary"></i> Ir a Hoy
                            </button>
                        </div>
                    </div>
                    <!-- Panel Derecho: Timeline -->
                    <div class="col-lg-9">
                        <div id="timeline-container"></div>
                    </div>
                </div>
            </div>

            <!-- VISTA SEMANAL SMART (Nueva) -->
            <div id="view-semana-smart" class="agenda-view-container d-none">
                <div id="weekly-smart-scroll" class="d-flex justify-content-center gap-2 py-3 mb-4 overflow-auto no-scrollbar">
                    <!-- Días generados por JS -->
                </div>
                <div id="weekly-smart-slots" class="row g-4">
                    <!-- Slots generados por JS -->
                </div>
            </div>

            <!-- REPORTE SEMANAL (DataTable) -->
            <div id="view-semana" class="agenda-view-container d-none">
                <div class="card border-0 shadow-sm rounded-4 p-2 p-md-4 agenda-report-card">
                    <h4 class="fw-black text-navy mb-2 mb-md-4 agenda-report-title">REPORTE SEMANAL DE CITAS</h4>
                    <div class="table-responsive agenda-table-responsive">
                        <table id="agendaTable" class="table table-diamond table-hover w-100 mb-0">
                            <thead>
                                <tr><th>Fecha</th><th>Hora</th><th>Paciente</th><th>Motivo</th><th>Status</th><th class="text-end">Acciones</th></tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- REPORTE MENSUAL (DataTable) -->
            <div id="view-mes" class="agenda-view-container d-none">
                <div class="card border-0 shadow-sm rounded-4 p-2 p-md-4 agenda-report-card">
                    <h4 class="fw-black text-navy mb-2 mb-md-4 agenda-report-title">REPORTE MENSUAL DE CITAS</h4>
                    <div class="table-responsive agenda-table-responsive">
                        <table id="mesTable" class="table table-diamond table-hover w-100 mb-0">
                            <thead>
                                <tr><th>Fecha</th><th>Hora</th><th>Paciente</th><th>Motivo</th><th>Status</th><th class="text-end">Acciones</th></tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- VISTA MENSUAL GRID -->
            <div id="view-calendario" class="agenda-view-container d-none">
                <div id="calendar-grid-sdm" class="animate__animated animate__fadeIn d-none d-lg-block"></div>
                
                <!-- Contenedor Móvil para el Grid (Calendario Compacto + Lista) -->
                <div class="d-lg-none animate__animated animate__fadeIn">
                    <div class="card border-0 shadow-sm rounded-4 mb-4 agenda-side-card">
                        <div class="card-body">
                            <div id="mini-calendar-grid"></div>
                        </div>
                    </div>
                    <div id="mini-calendar-appointments"></div>
                </div>
            </div>
        </main>
    </div>

    <!-- MODAL CITAS (Diseño Clínico Minimalista Teal - Zero Scroll & Ajuste Perfecto) -->
    <div class="modal fade modal-diamond" id="modalCita" tabindex="-1" aria-hidden="true" style="z-index: 105150 !important;">
        <div class="modal-dialog modal-dialog-centered modal-xl" style="max-width: 1040px;">
            <div class="modal-content">
                
                <!-- Cabecera Corporativa Azul Marino -->
                <div class="modal-header d-flex align-items-center justify-content-between" style="background-color: var(--md-blue-deep, #0A2A66) !important; border-bottom: 2px solid var(--md-teal-clinical, #19B7A5) !important; padding: 0.75rem 1.25rem !important;">
                    <div class="d-flex align-items-center gap-2.5">
                        <div class="modal-header-icon rounded-circle d-flex align-items-center justify-content-center" style="width: 32px; height: 32px; background: rgba(255, 255, 255, 0.16); border: 1px solid rgba(255, 255, 255, 0.25); color: #ffffff;">
                            <i class="bi bi-calendar2-check text-white" style="font-size: 1rem;"></i>
                        </div>
                        <h5 class="modal-title m-0 text-white" style="font-size: 0.95rem; font-weight: 500; letter-spacing: 0.3px;">
                            <span id="modalCitaTitle" class="text-white">GESTIÓN DE CITA</span>
                        </h5>
                    </div>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close" style="font-size: 0.75rem; opacity: 0.9;"></button>
                </div>
                
                <div class="modal-body">
                    <form id="formCita">
                        <input type="hidden" name="id_cita" id="f_id_cita">
                        <input type="hidden" name="id_paciente" id="f_id_paciente">
                        <input type="hidden" name="accion" id="f_accion" value="create">
                        <input type="hidden" name="hora_ini" id="f_hi">
                        <input type="hidden" name="hora_fin" id="f_hf">

                        <div class="row g-3 align-items-stretch">
                            <!-- PANEL IZQUIERDO: FORMULARIO PRINCIPAL (7 COLS) -->
                            <div class="col-lg-7 d-flex flex-column justify-content-between">
                                <div class="row g-2">
                                    <!-- Fila 1: Paciente y Fecha -->
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_paciente">Paciente <span class="text-muted fw-normal">(búsqueda automática)</span></label>
                                        <div class="position-relative">
                                            <input type="text" id="f_paciente" class="form-control form-control-compact pe-4" placeholder="Nombre del paciente..." required>
                                            <i class="bi bi-search position-absolute end-0 top-50 translate-middle-y me-2.5 text-muted" style="font-size: 0.8rem;"></i>
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_fecha">Fecha de la Cita</label>
                                        <input type="date" name="fecha" id="f_fecha" class="form-control form-control-compact" onchange="renderSlots(this.value)">
                                    </div>

                                    <!-- Fila 2: Motivo y Profesional -->
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_motivo">Motivo / Observaciones <span class="text-danger">*</span></label>
                                        <input type="text" name="motivo" id="f_motivo" class="form-control form-control-compact" placeholder="Detalles de la cita..." required>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_medico_select">Profesional Asignado</label>
                                        <select name="id_medico" id="f_medico_select" class="form-select form-control-compact" onchange="actualizarAgendaDestino()">
                                            $html_medicos
                                        </select>
                                    </div>

                                    <!-- Fila 3: Sucursal y Lugar/Consultorio -->
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_sucursal">Sucursal</label>
                                        <select name="sucursal" id="f_sucursal" class="form-select form-control-compact">
                                            $html_sucursal
                                        </select>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_consultorio">Lugar / Consultorio</label>
                                        <select name="consultorio" id="f_consultorio" class="form-select form-control-compact">
                                            <option value="Virtual">Cargando...</option>
                                        </select>
                                    </div>

                                    <!-- Fila 4: Estado y Prioridad -->
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_estado">Estado</label>
                                        <select name="estado" id="f_estado" class="form-select form-control-compact">
                                            <option value="Programada">Programada</option>
                                            <option value="Confirmada">Confirmada</option>
                                            <option value="En Sala de Espera">En Sala de Espera</option>
                                            <option value="Consulta en proceso">Consulta en proceso</option>
                                            <option value="En consulta">En consulta</option>
                                            <option value="Atendida">Atendida</option>
                                            <option value="No realizada">No realizada</option>
                                            <option value="Cancelada">Cancelada</option>
                                        </select>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_prioridad">Prioridad</label>
                                        <select name="prioridad" id="f_prioridad" class="form-select form-control-compact">
                                            <option value="Baja">Baja</option>
                                            <option value="Normal" selected>Normal</option>
                                            <option value="Alta">Alta</option>
                                            <option value="Urgente">Urgente</option>
                                        </select>
                                    </div>
                                </div>

                                <!-- Leyenda de Cita Pagada en Recepción si aplica -->
                                <div id="leyenda-cita-pagada" class="badge text-success px-3 py-2 rounded-2 d-none mt-2 text-start" style="font-size: 0.8rem; font-weight: 500; background-color: #f0fdf4; border: 1px solid #bbf7d0;">
                                    <i class="bi bi-check-circle-fill me-1 text-success"></i> Consulta Pagada en Recepción
                                </div>
                            </div>

                            <!-- PANEL DERECHO: DURACIÓN Y SLOTS DE HORARIOS (5 COLS) -->
                            <div class="col-lg-5">
                                <div class="h-100 d-flex flex-column p-2.5 rounded-3" style="background-color: #f8fafc; border: 1px solid rgba(25, 183, 165, 0.28);">
                                    <!-- Selector de Duración -->
                                    <div class="mb-2">
                                        <div class="d-flex align-items-center justify-content-between mb-1">
                                            <label class="form-label-compact m-0">Duración Estimada</label>
                                            <span class="text-muted" style="font-size: 0.68rem;">Tiempo de atención</span>
                                        </div>
                                        <div class="d-flex gap-1.5 dur-bar-premium w-100" id="btn-group-duracion">
                                            <!-- Generado dinámicamente por JS -->
                                        </div>
                                    </div>

                                    <!-- Horarios Disponibles -->
                                    <div class="d-flex flex-column flex-grow-1">
                                        <div class="d-flex align-items-center justify-content-between mb-1">
                                            <label class="form-label-compact m-0">Horarios Disponibles</label>
                                            <span class="text-muted" style="font-size: 0.68rem;"><i class="bi bi-clock me-1"></i>Bloque asignado</span>
                                        </div>
                                        <div id="slots-container" class="slot-grid-compact flex-grow-1" style="height: 185px; max-height: 195px; overflow-y: auto;">
                                            <!-- Generado dinámicamente por JS -->
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- ACCIONES / FOOTER -->
                        <div class="d-flex flex-column flex-sm-row justify-content-between align-items-center gap-2 pt-2.5 mt-2.5" style="border-top: 1px solid rgba(25, 183, 165, 0.2);">
                            <div class="d-flex align-items-center gap-2">
                                <button type="button" id="btn-del-cita" onclick="delCita()" class="btn btn-outline-danger btn-compact d-none">
                                    <i class="bi bi-trash3 me-1"></i>Eliminar Cita
                                </button>
                            </div>
                            <div class="d-flex align-items-center gap-2 ms-auto">
                                <button type="button" class="btn btn-light btn-compact border" data-bs-dismiss="modal">
                                    Cancelar
                                </button>
                                $btn_cobrar_recepcion_html
                                <button type="button" id="btn-tomar-cita" onclick="tomarCitaModal()" class="btn btn-emerald btn-compact d-none">
                                    <i class="bi bi-person-check me-1"></i>Tomar Cita
                                </button>
                                <button type="button" onclick="saveCita()" class="btn btn-teal-primary btn-compact">
                                    <i class="bi bi-check2-circle me-1"></i>Guardar Cita
                                </button>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL AJUSTES -->
    <div class="modal fade modal-diamond" id="modalAjustes" tabindex="-1" aria-hidden="true" style="z-index: 105150 !important;">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-0 shadow-lg">
                <div class="modal-header fw-bold">
                    <h5 class="modal-title d-flex align-items-center"><i class="bi bi-gear-fill me-2" style="color: #6366f1 !important;"></i> AJUSTES DE AGENDA</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body p-4 bg-light">
                    <form id="formAjustes">
                        <div class="row g-3">
                            <div class="col-6">
                                <div class="form-floating mb-2">
                                    <input type="time" class="form-control shadow-sm border-0 rounded-3" id="adj_h_ini" name="h_ini" required>
                                    <label class="text-muted fw-bold small text-uppercase">Inicio Jornada</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating mb-2">
                                    <input type="time" class="form-control shadow-sm border-0 rounded-3" id="adj_h_fin" name="h_fin" required>
                                    <label class="text-muted fw-bold small text-uppercase">Fin Jornada</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating mb-2">
                                    <input type="time" class="form-control shadow-sm border-0 rounded-3" id="adj_c_ini" name="c_ini" required>
                                    <label class="text-muted fw-bold small text-uppercase">Inicio Comida</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating mb-2">
                                    <input type="time" class="form-control shadow-sm border-0 rounded-3" id="adj_c_fin" name="c_fin" required>
                                    <label class="text-muted fw-bold small text-uppercase">Fin Comida</label>
                                </div>
                            </div>
                            <div class="col-12 mt-4">
                                <label class="small fw-bold text-muted mb-2 d-block text-uppercase">Días Laborales</label>
                                <div class="d-flex flex-wrap gap-2 mb-2 p-3 bg-white rounded-3 shadow-sm">
                                    <div class="form-check form-check-inline m-0 me-2">
                                        <input class="form-check-input adj-dia" type="checkbox" value="1" id="d1"> <label class="form-check-label small fw-bold" for="d1">Lun</label>
                                    </div>
                                    <div class="form-check form-check-inline m-0 me-2">
                                        <input class="form-check-input adj-dia" type="checkbox" value="2" id="d2"> <label class="form-check-label small fw-bold" for="d2">Mar</label>
                                    </div>
                                    <div class="form-check form-check-inline m-0 me-2">
                                        <input class="form-check-input adj-dia" type="checkbox" value="3" id="d3"> <label class="form-check-label small fw-bold" for="d3">Mié</label>
                                    </div>
                                    <div class="form-check form-check-inline m-0 me-2">
                                        <input class="form-check-input adj-dia" type="checkbox" value="4" id="d4"> <label class="form-check-label small fw-bold" for="d4">Jue</label>
                                    </div>
                                    <div class="form-check form-check-inline m-0 me-2">
                                        <input class="form-check-input adj-dia" type="checkbox" value="5" id="d5"> <label class="form-check-label small fw-bold" for="d5">Vie</label>
                                    </div>
                                    <div class="form-check form-check-inline m-0 me-2">
                                        <input class="form-check-input adj-dia" type="checkbox" value="6" id="d6"> <label class="form-check-label small fw-bold" for="d6">Sáb</label>
                                    </div>
                                    <div class="form-check form-check-inline m-0 me-2">
                                        <input class="form-check-input adj-dia" type="checkbox" value="0" id="d0"> <label class="form-check-label small fw-bold" for="d0">Dom</label>
                                    </div>
                                </div>
                            </div>
                            <div class="col-12 mt-3">
                                <div class="form-floating mb-2">
                                    <select class="form-select shadow-sm border-0 rounded-3 fw-bold" id="adj_int" name="int">
                                        <option value="15">15 minutos</option>
                                        <option value="30">30 minutos</option>
                                        <option value="45">45 minutos</option>
                                        <option value="60">60 minutos</option>
                                    </select>
                                    <label class="text-muted fw-bold small text-uppercase">Intervalo de Slots</label>
                                </div>
                            </div>
                            <div class="col-12 mt-3">
                                <div class="form-floating mb-2">
                                    <select class="form-select shadow-sm border-0 rounded-3 fw-bold" id="adj_cancel_hours" name="cancel_hours">
                                        <option value="0">Sin Límite (0 hrs)</option>
                                        <option value="12">12 Horas previas</option>
                                        <option value="24">24 Horas previas</option>
                                        <option value="48">48 Horas previas</option>
                                        <option value="72">72 Horas previas</option>
                                    </select>
                                    <label class="text-muted fw-bold small text-uppercase">Límite Cancelación (Paciente)</label>
                                </div>
                            </div>
                            <div class="col-12 mt-3">
                                <label class="small fw-bold text-muted mb-2 d-block text-uppercase">Festivos Personales</label>
                                <div class="input-group mb-2 shadow-sm rounded-3">
                                    <input type="date" class="form-control border-0" id="adj_fest_picker">
                                    <button type="button" class="btn btn-primary px-3 fw-bold border-0" style="background-color: #6366f1;" onclick="var f = document.getElementById('adj_fest'); var p = document.getElementById('adj_fest_picker'); if(p.value){ f.value = f.value ? f.value + ',' + p.value : p.value; p.value = ''; }"><i class="bi bi-plus-lg"></i> Agregar</button>
                                </div>
                                <div class="form-floating">
                                    <input type="text" class="form-control shadow-sm border-0 rounded-3" id="adj_fest" name="festivos" placeholder="YYYY-MM-DD, ...">
                                    <label class="text-muted fw-bold small text-uppercase">Fechas Seleccionadas</label>
                                </div>
                            </div>
                        </div>
                    </form>
                </div>
                <div class="modal-footer bg-light border-0 pt-0">
                    <button type="button" onclick="guardarAjustes()" class="btn btn-primary w-100 py-3 fw-bold shadow-sm border-0 rounded-pill" style="background: #6366f1;">
                        <i class="bi bi-save me-2"></i> GUARDAR PREFERENCIAS
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- LIBRERÍAS DE EXPORTACIÓN (ORDEN CRÍTICO) -->
    <script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/pdfmake.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/vfs_fonts.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>

    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script src="../js/agenda_spa_new.js?v=20261008_1955"></script>
HTML

print <<'JS';
    <!-- SCRIPT DE RECURSOS (Consultorios y Quirófanos) -->
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            var fSucursal = document.getElementById('f_sucursal');
            var fConsultorio = document.getElementById('f_consultorio');
            var esIndividual = document.getElementById('agenda_es_individual') && document.getElementById('agenda_es_individual').value === '1';
            
            window.cargarRecursos = function(idSucursal) {
                if (!fConsultorio) return;

                if (esIndividual) {
                    fConsultorio.innerHTML = '<optgroup label="Consultorio"><option value="Consultorio 1" selected>Consultorio 1</option></optgroup><optgroup label="Otros"><option value="Virtual">Virtual</option></optgroup>';
                    return;
                }

                fConsultorio.innerHTML = '<option value="">Cargando...</option>';
                
                fetch('../api/citas_crud.pl?accion=get_recursos&id_sucursal=' + (idSucursal || ''))
                    .then(r => r.json())
                    .then(data => {
                        if (data.ok) {
                            if (data.tipo_org === 'Consultorio Individual' || (data.consultorios === 1 && (!data.quirofanos || data.quirofanos === 0))) {
                                fConsultorio.innerHTML = '<optgroup label="Consultorio"><option value="Consultorio 1" selected>Consultorio 1</option></optgroup><optgroup label="Otros"><option value="Virtual">Virtual</option></optgroup>';
                                return;
                            }
                            let html = '<optgroup label="Consultorios">';
                            for (let i = 1; i <= data.consultorios; i++) {
                                html += `<option value="Consultorio ${i}">Consultorio ${i}</option>`;
                            }
                            html += '</optgroup>';
                            
                            if (data.quirofanos > 0) {
                                html += '<optgroup label="Quirófanos">';
                                for (let i = 1; i <= data.quirofanos; i++) {
                                    html += `<option value="Quirófano ${i}">Quirófano ${i}</option>`;
                                }
                                html += '</optgroup>';
                            }
                            
                            html += '<optgroup label="Otros"><option value="Virtual">Virtual</option></optgroup>';
                            fConsultorio.innerHTML = html;
                        }
                    })
                    .catch(e => {
                        console.error("Error cargando recursos", e);
                        fConsultorio.innerHTML = '<option value="Consultorio 1">Consultorio 1</option><option value="Virtual">Virtual</option>';
                    });
            };

            if (fSucursal) {
                fSucursal.addEventListener('change', function() {
                    window.cargarRecursos(this.value);
                    if (typeof renderSlots === 'function' && document.getElementById('f_fecha')) {
                        renderSlots(document.getElementById('f_fecha').value);
                    }
                });
            }

            if (fConsultorio) {
                fConsultorio.addEventListener('change', function() {
                    if (typeof renderSlots === 'function' && document.getElementById('f_fecha')) {
                        renderSlots(document.getElementById('f_fecha').value);
                    }
                });
            }
            
            // Cargar inicial cuando el modal se abre para asegurar que toma el ID correcto
            let modalEl = document.getElementById('modalCita');
            if (modalEl) {
                modalEl.addEventListener('show.bs.modal', function () {
                    if (esIndividual) {
                        window.cargarRecursos('');
                    } else {
                        setTimeout(() => {
                            if (fSucursal && fSucursal.value) {
                                window.cargarRecursos(fSucursal.value);
                            }
                        }, 200);
                    }
                });
            }
        });
    </script>
JS

utils::sub_sidebar::render_sidebar_footer();
print <<HTML;
</body>
</html>
HTML

render_bottom_nav('agenda');
1;
