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
my $id_sucursal = $sd->{session} ? $sd->{session}->param('id_sucursal') : '';
my $id_negocio_activo = ($id_sucursal && $id_sucursal ne '0') ? $id_sucursal : $id_negocio;

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');

my $usuarios = leer_tabla($archivo_usuarios, '!');
my @medicos;
if ($usuarios) {
    foreach my $u (@$usuarios) {
        if ($u->[5] eq 'Medico' && $u->[6] =~ /^$id_negocio:/) {
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
    <script>
        window.idPacientePre = "$id_paciente_pre";
        window.nombrePacientePre = "$nombre_paciente_pre";
    </script>

    <link rel="stylesheet" href="../css/agenda_diamond.css?v=4.2.0">
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
                    <div class="col-lg-3 d-none d-lg-block">
                        <div class="card border-0 shadow-sm rounded-4 p-3 sticky-top" style="top:100px; background: rgba(255,255,255,0.7); backdrop-filter: blur(10px);">
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
                <div class="card border-0 shadow-sm rounded-4 p-4">
                    <h4 class="fw-black text-navy mb-4">REPORTE SEMANAL DE CITAS</h4>
                    <div class="table-responsive">
                        <table id="agendaTable" class="table table-hover w-100">
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
                <div class="card border-0 shadow-sm rounded-4 p-4">
                    <h4 class="fw-black text-navy mb-4">REPORTE MENSUAL DE CITAS</h4>
                    <div class="table-responsive">
                        <table id="mesTable" class="table table-hover w-100">
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
                    <div class="card border-0 shadow-sm rounded-4 mb-4">
                        <div class="card-body">
                            <div id="mini-calendar-grid"></div>
                        </div>
                    </div>
                    <div id="mini-calendar-appointments"></div>
                </div>
            </div>
        </main>
    </div>

    <!-- MODAL CITAS (Aura Premium & Z-Index Guard) -->
    <style>
      .modal-backdrop.show { z-index: 104900 !important; }
      .ui-autocomplete { z-index: 105001 !important; }
      .bento-action-btn { background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%); border: 1px solid rgba(59, 130, 246, 0.3) !important; border-radius: 12px !important; transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1) !important; box-shadow: 0 2px 4px rgba(0,0,0,0.02); text-decoration: none; color: #1e293b; }
      .bento-action-btn:hover { transform: translateY(-3px) scale(1.02) !important; box-shadow: 0 10px 20px rgba(59, 130, 246, 0.15) !important; border-color: rgba(59, 130, 246, 0.6) !important; background: linear-gradient(180deg, #ffffff 0%, #f0f7ff 100%); color: #0A2A66; }
      .floating-label-premium label { font-size: 0.65rem !important; text-transform: uppercase; color: #64748b; font-weight: 700; padding: 1rem 0.75rem; }
      .floating-label-premium .form-control, .floating-label-premium .form-select { border-radius: 1rem; background-color: #f8fafc; border: 1px solid transparent; transition: all 0.2s; box-shadow: none; }
      .floating-label-premium .form-control:focus, .floating-label-premium .form-select:focus { background-color: #ffffff; border-color: rgba(59, 130, 246, 0.4); box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.1); }
      .dur-bar-premium .btn { border-radius: 12px !important; margin: 0; border: 1px solid rgba(59, 130, 246, 0.2) !important; background-color: #ffffff; color: #64748b; font-weight: 600; font-size: 0.85rem; padding: 10px 0; transition: all 0.2s; }
      .dur-bar-premium .btn.active { background-color: var(--md-blue-medical) !important; color: #ffffff !important; border-color: var(--md-blue-medical) !important; box-shadow: 0 4px 10px rgba(59, 130, 246, 0.2); transform: scale(1.05); z-index: 2; }
      .dur-bar-premium .btn:hover:not(.active) { background-color: #f0f7ff; color: #1e293b; }
      #modalCita .slot-grid-compact { display: grid !important; grid-template-columns: repeat(auto-fill, minmax(65px, 1fr)) !important; gap: 10px !important; padding: 12px !important; }
      #modalCita .btn-slot { font-size: 0.70rem !important; padding: 6px 0 !important; border-radius: 8px !important; background-color: #dcfce7 !important; color: #166534 !important; border: 1px solid #bbf7d0 !important; font-weight: 700; }
      #modalCita .btn-slot:hover:not(:disabled) { background-color: #bbf7d0 !important; border-color: #86efac !important; transform: translateY(-2px); box-shadow: 0 4px 8px rgba(22, 101, 52, 0.15); }
      #modalCita .btn-slot.active { background-color: #16a34a !important; color: #ffffff !important; border-color: #15803d !important; box-shadow: 0 4px 12px rgba(22, 101, 52, 0.3); }
      #modalCita .slot-lunch { background-color: #fee2e2 !important; color: #991b1b !important; border-color: #fecaca !important; }
      #modalCita .slot-busy { background-color: #fef9c3 !important; color: #854d0e !important; border-color: #fde047 !important; }
      \@media (min-width: 768px) {
          .border-md-end-soft { border-right: 1px solid var(--md-gray-soft) !important; }
      }
    </style>
    <div class="modal fade modal-diamond" id="modalCita" tabindex="-1" aria-hidden="true" style="z-index: 105000 !important;">
        <div class="modal-dialog modal-dialog-centered modal-lg">
            <div class="modal-content">
                
                <!-- Cabecera manual -->
                <div class="modal-header">
                    <h5 class="modal-title d-flex align-items-center">
                        <i class="bi bi-calendar-check me-2" style="color: #00C4C4 !important;"></i> 
                        <span id="modalCitaTitle">GESTIÓN DE CITA</span>
                    </h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                
                <div class="modal-body p-3 p-md-4">
                    <form id="formCita">
                        <input type="hidden" name="id_cita" id="f_id_cita">
                        <input type="hidden" name="id_paciente" id="f_id_paciente">
                        <input type="hidden" name="accion" id="f_accion" value="create">
                        <input type="hidden" name="hora_ini" id="f_hi">
                        <input type="hidden" name="hora_fin" id="f_hf">

                        <div class="row g-3">
                            <!-- Primera Fila -->
                            <div class="col-md-3">
                                <div class="form-floating floating-label-premium position-relative">
                                    <input type="text" id="f_paciente" class="form-control pe-4" placeholder="Buscar paciente..." required>
                                    <label for="f_paciente">PACIENTE <span class="fw-normal text-lowercase">(auto)</span></label>
                                    <i class="bi bi-search position-absolute end-0 translate-middle-y me-3 text-muted" style="top: 50%;"></i>
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-floating floating-label-premium">
                                    <input type="date" name="fecha" id="f_fecha" class="form-control" placeholder="Fecha" onchange="renderSlots(this.value)">
                                    <label for="f_fecha">FECHA DE LA CITA</label>
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-floating floating-label-premium">
                                    <input type="text" name="motivo" id="f_motivo" class="form-control" placeholder="Detalles de la cita..." required>
                                    <label for="f_motivo">MOTIVO / OBSERVACIONES <span class="text-danger">*</span></label>
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-floating floating-label-premium">
                                    <select name="id_medico" id="f_medico_select" class="form-select fw-bold" onchange="actualizarAgendaDestino()">
                                        $html_medicos
                                    </select>
                                    <label for="f_medico_select">PROFESIONAL</label>
                                </div>
                            </div>

                            <!-- Segunda Fila -->
                            <div class="col-md-3">
                                <div class="form-floating floating-label-premium">
                                    <select name="sucursal" id="f_sucursal" class="form-select fw-bold">
                                        $html_sucursal
                                    </select>
                                    <label for="f_sucursal">SUCURSAL</label>
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-floating floating-label-premium">
                                    <select name="consultorio" id="f_consultorio" class="form-select fw-bold">
                                        <option value="Virtual">Cargando...</option>
                                    </select>
                                    <label for="f_consultorio">LUGAR</label>
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-floating floating-label-premium">
                                    <select name="estado" id="f_estado" class="form-select fw-bold">
                                        <option value="Programada">Programada</option>
                                        <option value="En Sala de Espera">En Sala de Espera</option>
                                        <option value="Confirmada">Confirmada</option>
                                        <option value="Atendida">Atendida</option>
                                        <option value="Cancelada">Cancelada</option>
                                    </select>
                                    <label for="f_estado">ESTADO</label>
                                </div>
                            </div>
                            <div class="col-md-3">
                                <div class="form-floating floating-label-premium">
                                    <select name="prioridad" id="f_prioridad" class="form-select fw-bold">
                                        <option value="Baja">Baja</option>
                                        <option value="Normal" selected>Normal</option>
                                        <option value="Alta">Alta</option>
                                        <option value="Urgente">Urgente</option>
                                    </select>
                                    <label for="f_prioridad">PRIORIDAD</label>
                                </div>
                            </div>
                        </div>

                        <div class="row g-4 mt-1">
                            <div class="col-md-12 p-3" style="background-color: var(--md-white-clinical); border-radius: 1rem; border: 1px solid var(--md-gray-soft);">
                                <div class="row">
                                    <div class="col-md-3 border-bottom border-md-0 pb-3 pb-md-0 mb-3 mb-md-0 pe-md-3 border-md-end-soft">
                                        <label class="small fw-bold text-muted mb-3 d-block text-uppercase" style="letter-spacing: 1px;">Duración</label>
                                        <div class="d-flex flex-row flex-md-column flex-wrap gap-2 dur-bar-premium" id="btn-group-duracion">
                                            <!-- Generado dinámicamente por JS -->
                                        </div>
                                    </div>
                                    <div class="col-md-9 d-flex flex-column ps-md-3">
                                        <label class="small fw-bold text-muted mb-3 d-block text-uppercase" style="letter-spacing: 1px;">Horarios Disponibles</label>
                                        <div id="slots-container" class="slot-grid-compact w-100 flex-grow-1" style="min-height: 200px; max-height: 250px; overflow-y: auto;"></div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <hr class="opacity-10 my-4" style="border-color: rgba(59, 130, 246, 0.2);">

                        <!-- Acciones Principales -->
                        <div class="d-flex flex-column flex-md-row justify-content-between align-items-center gap-2 mt-4">
                            <div id="leyenda-cita-pagada" class="badge bg-success-subtle text-success border border-success-subtle px-3 py-2.5 rounded-pill fw-bold d-none my-1" style="font-size: 0.85rem; background-color: #dcfce7 !important; color: #15803d !important; border-color: #86efac !important;">
                                <i class="bi bi-check-circle-fill me-1 text-success"></i> Consulta Pagada en Recepción
                            </div>
                            <div class="d-flex flex-column flex-md-row justify-content-end gap-2 ms-auto w-100 w-md-auto">
                                <button type="button" id="btn-del-cita" onclick="delCita()" class="btn btn-outline-danger fw-bold d-none px-4 order-3 order-md-1 rounded-pill">ELIMINAR CITA</button>
                                <button type="button" onclick="saveCita()" class="btn btn-premium-primary fw-bold px-4 order-1 order-md-2"><i class="bi bi-save me-1"></i> GUARDAR CITA</button>
                                <button type="button" id="btn-cobrar-recepcion" onclick="cobrarRecepcionModal()" class="btn btn-warning text-dark fw-bold d-none px-4 order-2 order-md-3 rounded-pill" style="background: linear-gradient(135deg, #f59e0b, #d97706); border:none;"><i class="bi bi-cash-coin me-1"></i> COBRAR EN RECEPCIÓN</button>
                                <button type="button" id="btn-tomar-cita" onclick="tomarCitaModal()" class="btn btn-success fw-bold d-none px-4 order-2 order-md-4 rounded-pill" style="background: linear-gradient(135deg, #10b981, #059669); border:none;"><i class="bi bi-person-check me-1"></i> TOMAR CITA</button>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL AJUSTES -->
    <div class="modal fade modal-diamond" id="modalAjustes" tabindex="-1" aria-hidden="true" style="z-index: 105000 !important;">
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
    <script src="../js/agenda_spa_new.js?v=20260707_0018"></script>
HTML

print <<'JS';
    <!-- SCRIPT DE RECURSOS (Consultorios y Quirófanos) -->
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            var fSucursal = document.getElementById('f_sucursal');
            var fConsultorio = document.getElementById('f_consultorio');
            
            window.cargarRecursos = function(idSucursal) {
                if (!fConsultorio) return;
                fConsultorio.innerHTML = '<option value="">Cargando...</option>';
                
                fetch('../api/citas_crud.pl?accion=get_recursos&id_sucursal=' + idSucursal)
                    .then(r => r.json())
                    .then(data => {
                        if (data.ok) {
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
                        fConsultorio.innerHTML = '<option value="Virtual">Virtual (Error)</option>';
                    });
            };

            if (fSucursal) {
                // Escuchar el cambio manual del usuario
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
                    setTimeout(() => {
                        if (fSucursal && fSucursal.value) {
                            window.cargarRecursos(fSucursal.value);
                        }
                    }, 300); // Esperar a que agenda_spa_new.js pueble la sucursal
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
