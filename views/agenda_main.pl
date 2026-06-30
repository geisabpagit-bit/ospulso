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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');

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

    <!-- MODAL CITAS -->
    <div class="modal fade" id="modalCita" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-0 shadow-lg rounded-4">
                <div class="modal-header text-white p-3 border-0" style="background:var(--sdm-blue);">
                    <h6 class="modal-title fw-black small text-uppercase mb-0" id="modalCitaTitle">GESTIÓN DE CITA</h6>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body p-4">
                    <form id="formCita">
                        <input type="hidden" name="id_cita" id="f_id_cita">
                        <input type="hidden" name="id_paciente" id="f_id_paciente">
                        <input type="hidden" name="accion" id="f_accion" value="create">
                        
                        <div class="position-relative mb-2">
                            <div class="form-floating">
                                <input type="text" id="f_paciente" class="form-control border-0 bg-light pe-5" placeholder="Paciente" required>
                                <label>PACIENTE <span class="text-muted text-lowercase ms-1 fw-normal" style="font-size:0.75rem;">(autocompletado)</span></label>
                            </div>
                            <i class="bi bi-search position-absolute top-50 end-0 translate-middle-y me-3 text-muted"></i>
                        </div>

                        <div class="row g-2 mb-2">
                            <div class="col-7">
                                <div class="form-floating">
                                    <input type="date" name="fecha" id="f_fecha" class="form-control border-0 bg-light" onchange="renderSlots(this.value)">
                                    <label>FECHA</label>
                                </div>
                            </div>
                            <div class="col-5">
                                <div class="form-floating">
                                    <select name="estado" id="f_estado" class="form-select border-0 bg-light fw-bold">
                                        <option value="Programada">Programada</option>
                                        <option value="Confirmada">Confirmada</option>
                                        <option value="Atendida">Atendida</option>
                                        <option value="Cancelada">Cancelada</option>
                                    </select>
                                    <label>ESTADO</label>
                                </div>
                            </div>
                        </div>

                        <div class="mb-2">
                            <label class="small fw-bold text-muted mb-1 d-block">DURACIÓN</label>
                            <div class="btn-group w-100 shadow-sm" id="btn-group-duracion">
                                <!-- Generado dinámicamente por JS (renderDuracionButtons) -->
                            </div>
                        </div>

                        <div class="mb-2">
                            <label class="small fw-bold text-muted mb-1 d-block">HORARIOS</label>
                            <div id="slots-container" class="slot-grid-compact p-2 bg-light rounded-3" style="max-height: 120px; overflow-y: auto;"></div>
                            <input type="hidden" name="hora_ini" id="f_hi">
                            <input type="hidden" name="hora_fin" id="f_hf">
                        </div>

                        <div class="form-floating mb-2">
                            <textarea name="motivo" id="f_motivo" class="form-control border-0 bg-light" style="height: 60px" placeholder="Motivo"></textarea>
                            <label>MOTIVO / OBSERVACIONES</label>
                        </div>

                        <div class="d-grid gap-2 mt-3">
                            <button type="button" id="btn-tomar-cita" onclick="tomarCitaModal()" class="btn btn-success py-3 fw-bold rounded-3 shadow-sm border-0 d-none">TOMAR CITA E IR A CONSULTA</button>
                            <button type="button" onclick="saveCita()" class="btn btn-primary py-3 fw-bold rounded-3 shadow-sm border-0">GUARDAR CITA</button>
                            <button type="button" id="btn-del-cita" onclick="delCita()" class="btn btn-outline-danger border-0 fw-bold d-none">ELIMINAR CITA</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL AJUSTES -->
    <div class="modal fade" id="modalAjustes" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-0 shadow-lg rounded-4">
                <div class="modal-header border-0 pb-0">
                    <h5 class="fw-black text-primary text-uppercase tracking-wider m-0">Ajustes de Agenda</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body p-4">
                    <form id="formAjustes">
                        <div class="row g-3">
                            <div class="col-6">
                                <div class="form-floating mb-3">
                                    <input type="time" class="form-control" id="adj_h_ini" name="h_ini" required>
                                    <label>Inicio Jornada</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating mb-3">
                                    <input type="time" class="form-control" id="adj_h_fin" name="h_fin" required>
                                    <label>Fin Jornada</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating mb-3">
                                    <input type="time" class="form-control" id="adj_c_ini" name="c_ini" required>
                                    <label>Inicio Comida</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating mb-3">
                                    <input type="time" class="form-control" id="adj_c_fin" name="c_fin" required>
                                    <label>Fin Comida</label>
                                </div>
                            </div>
                            <div class="col-12">
                                <label class="small fw-bold text-muted mb-2 d-block">Días Laborales</label>
                                <div class="d-flex flex-wrap gap-2 mb-3">
                                    <div class="form-check form-check-inline">
                                        <input class="form-check-input adj-dia" type="checkbox" value="1" id="d1"> <label class="form-check-label" for="d1">Lun</label>
                                    </div>
                                    <div class="form-check form-check-inline">
                                        <input class="form-check-input adj-dia" type="checkbox" value="2" id="d2"> <label class="form-check-label" for="d2">Mar</label>
                                    </div>
                                    <div class="form-check form-check-inline">
                                        <input class="form-check-input adj-dia" type="checkbox" value="3" id="d3"> <label class="form-check-label" for="d3">Mié</label>
                                    </div>
                                    <div class="form-check form-check-inline">
                                        <input class="form-check-input adj-dia" type="checkbox" value="4" id="d4"> <label class="form-check-label" for="d4">Jue</label>
                                    </div>
                                    <div class="form-check form-check-inline">
                                        <input class="form-check-input adj-dia" type="checkbox" value="5" id="d5"> <label class="form-check-label" for="d5">Vie</label>
                                    </div>
                                    <div class="form-check form-check-inline">
                                        <input class="form-check-input adj-dia" type="checkbox" value="6" id="d6"> <label class="form-check-label" for="d6">Sáb</label>
                                    </div>
                                    <div class="form-check form-check-inline">
                                        <input class="form-check-input adj-dia" type="checkbox" value="0" id="d0"> <label class="form-check-label" for="d0">Dom</label>
                                    </div>
                                </div>
                            </div>
                            <div class="col-12">
                                <div class="form-floating mb-3">
                                    <select class="form-select" id="adj_int" name="int">
                                        <option value="15">15 minutos</option>
                                        <option value="30">30 minutos</option>
                                        <option value="45">45 minutos</option>
                                        <option value="60">60 minutos</option>
                                    </select>
                                    <label>Intervalo de Slots</label>
                                </div>
                            </div>
                            <div class="col-12">
                                <div class="form-floating mb-3">
                                    <input type="text" class="form-control" id="adj_fest" name="festivos" placeholder="YYYY-MM-DD, ...">
                                    <label>Festivos Personales</label>
                                </div>
                            </div>
                        </div>
                        <div class="d-grid mt-3">
                            <button type="button" onclick="guardarAjustes()" class="btn btn-primary py-3 fw-bold rounded-3 shadow-sm border-0">GUARDAR PREFERENCIAS</button>
                        </div>
                    </form>
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
    <script src="../js/agenda_spa_new.js?v=4.0.1_Final_Rebuilt"></script>
</body>
</html>
HTML

render_bottom_nav('agenda');
1;
