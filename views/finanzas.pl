#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib $FindBin::Bin . '/..';

require "$FindBin::Bin/../auth/check_session.pl";
require "$FindBin::Bin/../utils/sub_header.pl";
require "$FindBin::Bin/../utils/sub_bottom_nav.pl";
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();

if (!$session_data->{session_ok}) {
    print $q->redirect(-uri => '../auth/login.pl');
    exit;
}

my $id_paciente = $q->param('id') || '';

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(usuario => $session_data->{usuario}, titulo => "Finanzas - SDM", role => $session_data->{role}, id_medico => $session_data->{id_medico}, skip_header => 1);

print <<'PAGE_HTML';
<link rel="stylesheet" href="../css/expediente_completo.css?v=3">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.1/css/buttons.bootstrap5.min.css">

<script>
    function toggleSidebar() {
        const sidebar = document.getElementById('moduleSidebar');
        const overlay = document.getElementById('sidebarOverlay');
        if (sidebar) sidebar.classList.toggle('show');
        if (overlay) overlay.classList.toggle('show');
    }
    function toggleDesktopSidebar() {
        const sidebar = document.getElementById('moduleSidebar');
        if(sidebar) sidebar.classList.toggle('compact');
    }
    function swTab(tabId, btnElement) {
        // Ocultar todos los tabs
        document.querySelectorAll('.sdm-tab-pane').forEach(el => el.classList.add('d-none'));
        const target = document.getElementById(tabId);
        if(target) target.classList.remove('d-none');
        
        // Actualizar visualmente los botones del sidebar
        if(btnElement) {
            document.querySelectorAll('.sidebar-menu .sub-link').forEach(el => el.classList.remove('active'));
            btnElement.classList.add('active');
            
            // Auto cerrar en móvil
            if(window.innerWidth < 992) {
                toggleSidebar();
            }
        }
        
        // Render triggers si aplica
        if(tabId === 'tab_cxc') {
            if(typeof window.renderCxC === 'function') window.renderCxC();
        }
        if(tabId === 'tab_gastos') {
            if(typeof window.renderGastos === 'function') window.renderGastos();
        }
        if(tabId === 'tab_ingresos') {
            if(typeof window.renderIngresos === 'function') window.renderIngresos();
        }
    }
</script>

<div class="sdm-layout-wrapper animate__animated animate__fadeIn">
    <!-- Sidebar Left -->
    <nav class="diamond-sidebar" id="moduleSidebar">
        <div class="sidebar-brand">
            <div class="avatar-diamond d-flex align-items-center justify-content-center" style="width: 45px; height: 45px; font-size: 1.2rem; border-width: 2px;"><i class="bi bi-wallet2 text-primary"></i></div>
            <div class="sidebar-brand-text lh-1">
                <h5 class="m-0 fw-black text-dark">FINANZAS</h5>
                <small class="text-muted fw-bold" style="font-size: 0.6rem;">DIAMOND v3.8.0</small>
            </div>
            <button class="btn btn-light rounded-circle p-2 shadow-sm d-lg-none ms-auto" onclick="toggleSidebar()"><i class="bi bi-x-lg"></i></button>
            <button class="btn-sidebar-toggle d-none d-lg-flex ms-auto" onclick="toggleDesktopSidebar()"><i class="bi bi-layout-sidebar text-muted"></i></button>
        </div>

        <div class="sidebar-menu accordion accordion-flush flex-grow-1" id="accordionSidebar">
            <!-- Finanzas Corporativas -->
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-fin">
                    <button class="accordion-button" type="button" data-bs-toggle="collapse" data-bs-target="#c-fin" aria-expanded="true" aria-controls="c-fin">
                        <i class="bi bi-cash-stack text-success"></i><span class="sidebar-text">Gesti&oacute;n Financiera</span>
                    </button>
                </h2>
                <div id="c-fin" class="accordion-collapse collapse show" aria-labelledby="h-fin" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body">
                        <button class="sub-link active w-100 text-start" onclick="swTab('tab_resumen', this)"><i class="bi bi-pie-chart-fill text-muted me-2"></i>Resumen General</button>
                        <button class="sub-link w-100 text-start" onclick="swTab('tab_ingresos', this)"><i class="bi bi-arrow-down-circle-fill text-success me-2"></i>Ingresos</button>
                        <button class="sub-link w-100 text-start" onclick="swTab('tab_gastos', this)"><i class="bi bi-arrow-up-circle-fill text-danger me-2"></i>Gastos (Egresos)</button>
                        <button class="sub-link w-100 text-start" onclick="swTab('tab_cxc', this)"><i class="bi bi-exclamation-triangle-fill text-warning me-2"></i>Cuentas por Cobrar</button>
                    </div>
                </div>
            </div>

            <!-- Contabilidad Fiscal -->
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-fiscal">
                    <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#c-fiscal" aria-expanded="false" aria-controls="c-fiscal">
                        <i class="bi bi-bank text-primary"></i><span class="sidebar-text">Fiscal y Contable</span>
                    </button>
                </h2>
                <div id="c-fiscal" class="accordion-collapse collapse" aria-labelledby="h-fiscal" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body">
                        <button class="sub-link w-100 text-start" onclick="swTab('tab_facturacion', this)"><i class="bi bi-receipt text-muted me-2"></i>Facturaci&oacute;n PAC</button>
                        <button class="sub-link w-100 text-start" onclick="swTab('tab_reportes', this)"><i class="bi bi-file-earmark-bar-graph-fill text-muted me-2"></i>Reportes (P&L)</button>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="p-3 sidebar-footer">
            <a href="inicial.pl" class="btn btn-danger w-100 rounded-pill fw-bold d-flex justify-content-center align-items-center"><i class="bi bi-house-door me-2"></i><span class="sidebar-text">Inicio</span></a>
        </div>
    </nav>

    <!-- Overlay -->
    <div class="sidebar-overlay" id="sidebarOverlay" onclick="toggleSidebar()"></div>

    <!-- Main Content -->
    <div class="sdm-main-content">
        <!-- Header Compacto -->
        <div class="diamond-header-compact d-flex justify-content-between align-items-center">
            <div class="d-flex align-items-center gap-3">
                <button class="btn btn-menu-toggle-inline d-lg-none" onclick="toggleSidebar()">
                    <i class="bi bi-list"></i>
                </button>
                <div class="profile-hero text-start">
                    <h4 class="text-truncate m-0 text-white fw-bold" style="max-width: 60vw; letter-spacing: -0.5px;">Módulo Financiero</h4>
                </div>
            </div>
        </div>

        <div class="content-wrapper p-3 p-md-4">
            
            <!-- TAB: RESUMEN (Actual Dashboard) -->
            <div id="tab_resumen" class="sdm-tab-pane">
                <div class="d-flex justify-content-between align-items-end mb-4 flex-wrap gap-3">
                    <div>
                        <h2 class="fw-bold plus-jakarta m-0" style="color: var(--md-text-primary);">Dashboard</h2>
                        <p class="text-muted m-0">Vista global del estado financiero.</p>
                    </div>
                </div>

                <!-- 4 KPI Cards -->
                <div class="row g-3 mb-4">
                    <!-- Ingresos Totales -->
                    <div class="col-md-3 col-6">
                        <div class="bento-card border-0 shadow-sm bg-white h-100 p-3" style="border-radius: 16px;">
                            <div class="d-flex align-items-center gap-2 mb-3">
                                <div class="shadow-sm d-flex justify-content-center align-items-center" style="width: 36px; height: 36px; border-radius: 50%; background: linear-gradient(135deg, #fef08a, #eab308, #a16207); color: white; font-size: 1.1rem;">
                                    <i class="bi bi-currency-dollar"></i>
                                </div>
                                <span class="fw-bold text-muted" style="font-size: 0.75rem;">Ingresos Totales</span>
                            </div>
                            <h4 class="fw-bold plus-jakarta mb-1" id="kpiIngresosTotales">$0.00</h4>
                            <span class="text-success fw-bold" style="font-size: 0.7rem;">+15% <span class="text-muted fw-normal">vs mes anterior</span></span>
                        </div>
                    </div>
                    <!-- Cuentas por Cobrar -->
                    <div class="col-md-3 col-6">
                        <div class="bento-card border-0 shadow-sm bg-white h-100 p-3" style="border-radius: 16px;">
                            <div class="d-flex align-items-center gap-2 mb-3">
                                <div class="shadow-sm d-flex justify-content-center align-items-center" style="width: 36px; height: 36px; border-radius: 50%; background: linear-gradient(135deg, #60a5fa, #3b82f6, #1e3a8a); color: white; font-size: 1.1rem;">
                                    <i class="bi bi-wallet2"></i>
                                </div>
                                <span class="fw-bold text-muted" style="font-size: 0.75rem;">Cuentas por Cobrar</span>
                            </div>
                            <h4 class="fw-bold plus-jakarta mb-1" id="kpiCuentasCobrar">$0.00</h4>
                            <span class="text-success fw-bold" style="font-size: 0.7rem;">+8% <span class="text-muted fw-normal">vs mes anterior</span></span>
                        </div>
                    </div>
                    <!-- Facturación del Mes -->
                    <div class="col-md-3 col-6">
                        <div class="bento-card border-0 shadow-sm bg-white h-100 p-3" style="border-radius: 16px;">
                            <div class="d-flex align-items-center gap-2 mb-3">
                                <div class="shadow-sm d-flex justify-content-center align-items-center" style="width: 36px; height: 36px; border-radius: 50%; background: linear-gradient(135deg, #93c5fd, #60a5fa, #2563eb); color: white; font-size: 1.1rem;">
                                    <i class="bi bi-file-earmark-text"></i>
                                </div>
                                <span class="fw-bold text-muted" style="font-size: 0.75rem;">Facturación del Mes</span>
                            </div>
                            <h4 class="fw-bold plus-jakarta mb-1" id="kpiFacturacion">$0.00</h4>
                            <span class="text-success fw-bold" style="font-size: 0.7rem;">+12% <span class="text-muted fw-normal">vs mes anterior</span></span>
                        </div>
                    </div>
                    <!-- Eficiencia de Cobro -->
                    <div class="col-md-3 col-6">
                        <div class="bento-card border-0 shadow-sm bg-white h-100 p-3" style="border-radius: 16px;">
                            <div class="d-flex align-items-center gap-2 mb-3">
                                <div class="shadow-sm d-flex justify-content-center align-items-center" style="width: 36px; height: 36px; border-radius: 50%; background: linear-gradient(135deg, #fef08a, #eab308, #a16207); color: white; font-size: 1.1rem;">
                                    <i class="bi bi-percent"></i>
                                </div>
                                <span class="fw-bold text-muted" style="font-size: 0.75rem;">Eficiencia de Cobro</span>
                            </div>
                            <h4 class="fw-bold plus-jakarta mb-1" id="kpiEficiencia">0%</h4>
                            <span class="text-muted fw-bold" style="font-size: 0.7rem;">Excelente</span>
                        </div>
                    </div>
                </div>

                <div class="row g-4 mb-4">
                    <div class="col-lg-7">
                        <div class="bento-card border-0 shadow-sm bg-white h-100 p-4" style="border-radius: 20px;">
                            <h6 class="fw-bold plus-jakarta mb-4 text-dark">Evolución de Ingresos</h6>
                            <div style="height: 250px; width: 100%;">
                                <canvas id="lineEvolucionIngresos"></canvas>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-lg-5">
                        <div class="bento-card border-0 shadow-sm bg-white h-100 p-4 d-flex flex-column justify-content-center" style="border-radius: 20px;">
                            <div class="d-flex justify-content-between align-items-center mb-4">
                                <h6 class="fw-bold plus-jakarta m-0 text-dark">Ingresos por Categoría</h6>
                                <select class="form-select form-select-sm w-auto rounded-pill text-muted fw-bold bg-light border-0"><option>Este Mes</option></select>
                            </div>
                            
                            <div class="row align-items-center g-0">
                                <div class="col-6 position-relative" style="height: 160px;">
                                    <canvas id="pieResumenConsolidado"></canvas>
                                    <div class="position-absolute top-50 start-50 translate-middle text-center w-100" style="pointer-events: none; margin-top: 2px;">
                                        <h5 class="fw-bold text-dark m-0 plus-jakarta" id="pieCenterVal" style="font-size: 1.1rem;">$0</h5>
                                        <span class="text-muted fw-bold" style="font-size: 0.7rem; text-transform: uppercase;">Total</span>
                                    </div>
                                </div>
                                <div class="col-6 ps-2">
                                    <div class="d-flex flex-column gap-3 w-100" id="pieCustomLegend">
                                        <div class="d-flex align-items-center justify-content-between w-100">
                                            <div class="d-flex align-items-center gap-2">
                                                <div style="width: 10px; height: 10px; border-radius: 50%; background: #eab308; box-shadow: inset -1px -1px 3px rgba(0,0,0,0.3);"></div>
                                                <span class="text-muted fw-bold" style="font-size: 0.75rem;">Cargos</span>
                                            </div>
                                            <span class="fw-bold text-dark" style="font-size: 0.75rem;" id="legCargos">$0</span>
                                        </div>
                                        <div class="d-flex align-items-center justify-content-between w-100">
                                            <div class="d-flex align-items-center gap-2">
                                                <div style="width: 10px; height: 10px; border-radius: 50%; background: #10b981; box-shadow: inset -1px -1px 3px rgba(0,0,0,0.3);"></div>
                                                <span class="text-muted fw-bold" style="font-size: 0.75rem;">Abonos</span>
                                            </div>
                                            <span class="fw-bold text-dark" style="font-size: 0.75rem;" id="legAbonos">$0</span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Resumen de Ingresos (Table) -->
                <div class="bento-card border-0 shadow-sm bg-white p-4 mb-5" style="border-radius: 20px;">
                    <h6 class="fw-bold plus-jakarta mb-4 text-dark">Resumen de Ingresos Recientes</h6>
                    <div class="table-responsive">
                        <table class="table table-hover align-middle mb-0" id="tablaResumenIngresos">
                            <thead class="text-muted small">
                                <tr>
                                    <th class="border-0">Fecha</th>
                                    <th class="border-0">Concepto</th>
                                    <th class="border-0">Folio</th>
                                    <th class="border-0">Paciente</th>
                                    <th class="border-0">Monto</th>
                                    <th class="border-0">Tipo</th>
                                </tr>
                            </thead>
                            <tbody id="tbodyResumenIngresos">
                                <!-- JS fills this -->
                            </tbody>
                        </table>
                    </div>
                    <div class="text-center mt-4">
                        <button class="btn btn-sm btn-link text-decoration-none fw-bold" onclick="swTab('tab_ingresos', document.querySelectorAll('.sub-link')[1])" style="color: var(--md-blue-deep);">Ver historial completo de ingresos <i class="bi bi-chevron-right"></i></button>
                    </div>
                </div>
            </div>

            <!-- TAB: INGRESOS -->
            <div id="tab_ingresos" class="sdm-tab-pane d-none">
                <div class="bento-card border-0 shadow-sm bg-white p-4" style="border-radius: 20px;">
                    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                        <div>
                            <h4 class="fw-bold plus-jakarta m-0 text-dark">Historial de Ingresos</h4>
                            <p class="text-muted m-0 small">Registro detallado de abonos y pagos recibidos en clínica.</p>
                        </div>
                    </div>
                    
                    <div class="table-responsive mt-3">
                        <table class="table table-hover align-middle" id="tablaIngresos">
                            <thead class="text-muted small">
                                <tr>
                                    <th>Fecha</th>
                                    <th>Paciente</th>
                                    <th>Concepto (OS)</th>
                                    <th>Abono</th>
                                </tr>
                            </thead>
                            <tbody id="tbodyIngresos">
                                <tr><td colspan="4" class="text-center text-muted"><div class="spinner-border text-primary spinner-border-sm me-2"></div>Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB: GASTOS -->
            <div id="tab_gastos" class="sdm-tab-pane d-none">
                <div class="bento-card border-0 shadow-sm bg-white p-4" style="border-radius: 20px;">
                    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                        <div>
                            <h4 class="fw-bold plus-jakarta m-0 text-dark">Control de Egresos</h4>
                            <p class="text-muted m-0 small">Administración de gastos operativos, proveedores y pagos.</p>
                        </div>
                        <button class="btn btn-primary rounded-pill fw-bold btn-medentia-action" onclick="abrirModalGasto()"><i class="bi bi-plus-lg me-2"></i>Registrar Gasto</button>
                    </div>
                    
                    <div class="table-responsive mt-3">
                        <table class="table table-hover align-middle" id="tablaGastos">
                            <thead class="text-muted small">
                                <tr>
                                    <th>Fecha</th>
                                    <th>Categoría / Sub</th>
                                    <th>Proveedor</th>
                                    <th>Concepto</th>
                                    <th>Monto</th>
                                    <th>Factura</th>
                                    <th>Acciones</th>
                                </tr>
                            </thead>
                            <tbody id="tbodyGastos">
                                <tr><td colspan="5" class="text-center text-muted"><div class="spinner-border text-primary spinner-border-sm me-2"></div>Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>



            <!-- TAB: CUENTAS POR COBRAR -->
            <div id="tab_cxc" class="sdm-tab-pane d-none">
                <div class="bento-card border-0 shadow-sm bg-white p-4" style="border-radius: 20px;">
                    <h4 class="fw-bold plus-jakarta mb-4 text-dark">Cuentas por Cobrar (CxC)</h4>
                    <p class="text-muted">Pacientes con saldos pendientes. Calculado en tiempo real.</p>
                    <div class="table-responsive mt-3">
                        <table class="table table-hover align-middle" id="tablaCxC">
                            <thead class="text-muted small">
                                <tr>
                                    <th>Paciente</th>
                                    <th>Ult. Movimiento</th>
                                    <th>Cargos Acum.</th>
                                    <th>Abonos Acum.</th>
                                    <th>Saldo Pendiente</th>
                                    <th>Acción</th>
                                </tr>
                            </thead>
                            <tbody id="tbodyCxC">
                                <tr><td colspan="6" class="text-center text-muted">Cargando...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- TAB: FACTURACION -->
            <div id="tab_facturacion" class="sdm-tab-pane d-none">
                <div class="bento-card border-0 shadow-sm bg-white p-4" style="border-radius: 20px;">
                    <h4 class="fw-bold plus-jakarta mb-4 text-dark">Facturación Electrónica (PAC SAT)</h4>
                    <p class="text-muted">Pronto: Emisión de CFDI 4.0 conectado a PAC.</p>
                </div>
            </div>

            <!-- TAB: REPORTES -->
            <div id="tab_reportes" class="sdm-tab-pane d-none">
                <div class="bento-card border-0 shadow-sm bg-white p-4" style="border-radius: 20px;">
                    <h4 class="fw-bold plus-jakarta mb-4 text-dark">Reportes Financieros (P&L)</h4>
                    <p class="text-muted">Pronto: Generador de estados de resultados y exportación a PDF/Excel.</p>
                </div>
            </div>

        </div> <!-- content-wrapper -->
    </div> <!-- sdm-main-content -->
</div> <!-- sdm-layout-wrapper -->

<!-- Modal Nuevo Gasto (Floating Armor) - Movido fuera del contexto de apilamiento para evitar solapamiento con navbar -->
<div class="modal fade" id="modalGasto" tabindex="-1" aria-hidden="true" style="z-index: 105000;">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 shadow-lg" style="border-radius: 20px;">
            <div class="modal-header border-0 pb-0 d-flex justify-content-between align-items-center">
                <h5 class="fw-bold plus-jakarta text-dark m-0"><i class="bi bi-cash-stack text-danger me-2"></i>Registrar Gasto</h5>
                <div class="d-flex align-items-center gap-2">
                    <button type="button" class="btn btn-sm btn-light rounded-circle text-muted" onclick="abrirModalCategorias()" title="Gestionar Categorías">
                        <i class="bi bi-gear-fill"></i>
                    </button>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
            </div>
            <div class="modal-body">
                <form id="formGasto">
                    <div class="form-floating mb-3">
                        <input type="date" class="form-control bg-light border-0 diamond-input-armor" style="border-radius: 1rem;" id="fecha_gasto" required>
                        <label for="fecha_gasto" style="font-size: 0.65rem; text-transform: uppercase; color: #64748b;">Fecha del Gasto</label>
                    </div>
                    <div class="row">
                        <div class="col-md-4">
                            <div class="form-floating mb-3">
                                <select class="form-select bg-light border-0 diamond-input-armor" style="border-radius: 1rem;" id="cat_gasto" required onchange="filtrarSubcategorias()">
                                    <option value="">Seleccione...</option>
                                </select>
                                <label for="cat_gasto" style="font-size: 0.65rem; text-transform: uppercase; color: #64748b;">Categoría Principal</label>
                            </div>
                        </div>
                        <div class="col-md-4" id="col_subcat_gasto" style="display:none;">
                            <div class="form-floating mb-3">
                                <select class="form-select bg-light border-0 diamond-input-armor" style="border-radius: 1rem;" id="subcat_gasto" onchange="filtrarSubcategorias3()">
                                    <option value="">Seleccione...</option>
                                </select>
                                <label for="subcat_gasto" style="font-size: 0.65rem; text-transform: uppercase; color: #64748b;">Subcategoría Nivel 2</label>
                            </div>
                        </div>
                        <div class="col-md-4" id="col_subcat3_gasto" style="display:none;">
                            <div class="form-floating mb-3">
                                <select class="form-select bg-light border-0 diamond-input-armor" style="border-radius: 1rem;" id="subcat3_gasto">
                                    <option value="">Seleccione...</option>
                                </select>
                                <label for="subcat3_gasto" style="font-size: 0.65rem; text-transform: uppercase; color: #64748b;">Detalle Gasto (Nivel 3)</label>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-floating mb-3">
                                <input type="text" class="form-control bg-light border-0 diamond-input-armor" style="border-radius: 1rem;" id="proveedor_gasto" placeholder="Proveedor" required>
                                <label for="proveedor_gasto" style="font-size: 0.65rem; text-transform: uppercase; color: #64748b;">Proveedor</label>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-floating mb-3">
                                <input type="text" class="form-control bg-light border-0 diamond-input-armor" style="border-radius: 1rem;" id="concepto_gasto" placeholder="Concepto" required>
                                <label for="concepto_gasto" style="font-size: 0.65rem; text-transform: uppercase; color: #64748b;">Concepto / Descripción</label>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-floating mb-3">
                                <input type="number" step="0.01" class="form-control bg-light border-0 diamond-input-armor" style="border-radius: 1rem;" id="monto_gasto" placeholder="Monto" required>
                                <label for="monto_gasto" style="font-size: 0.65rem; text-transform: uppercase; color: #64748b;">Monto Total ($)</label>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label for="factura_gasto" style="font-size: 0.65rem; text-transform: uppercase; color: #64748b; margin-left: 0.75rem;">Adjuntar Factura (Opcional)</label>
                                <input type="file" class="form-control bg-light border-0 diamond-input-armor" style="border-radius: 1rem; padding-top: 0.65rem; padding-bottom: 0.65rem;" id="factura_gasto" accept=".pdf,.png,.jpg,.jpeg">
                            </div>
                        </div>
                    </div>
                    <button type="submit" class="btn w-100 rounded-pill fw-bold text-white shadow-sm" style="background: var(--md-blue-medical);">Guardar Gasto</button>
                </form>
            </div>
        </div>
    </div>
</div>

<!-- Modal Gestión de Categorías -->
<div class="modal fade" id="modalCategorias" tabindex="-1" aria-hidden="true" style="z-index: 105010;">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 shadow-lg" style="border-radius: 20px;">
            <div class="modal-header border-0 pb-0">
                <h5 class="fw-bold plus-jakarta text-dark m-0"><i class="bi bi-gear-fill text-secondary me-2"></i>Gestión de Categorías</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div class="row mb-3">
                    <div class="col-md-5">
                        <label class="small text-muted fw-bold mb-1">Nivel</label>
                        <select id="mg_nivel" class="form-select bg-light border-0 diamond-input-armor" onchange="cambiarNivelGestion()">
                            <option value="1">1. Categoría Principal</option>
                            <option value="2">2. Subcategoría</option>
                            <option value="3">3. Detalle (Nivel 3)</option>
                        </select>
                    </div>
                    <div class="col-md-7" id="mg_parent_col" style="display:none;">
                        <label class="small text-muted fw-bold mb-1" id="mg_parent_label">Padre</label>
                        <select id="mg_parent" class="form-select bg-light border-0 diamond-input-armor" onchange="renderListaCategorias()">
                            <option value="">Seleccione...</option>
                        </select>
                    </div>
                </div>
                
                <div class="input-group mb-4 shadow-sm" style="border-radius: 1rem; overflow: hidden;">
                    <input type="text" id="mg_nombre" class="form-control bg-light border-0" placeholder="Nombre de la nueva categoría..." style="padding: 0.75rem 1rem;">
                    <button class="btn fw-bold px-4 text-white" type="button" style="background: var(--md-blue-medical);" onclick="agregarCategoria()" id="btn_add_cat">
                        <i class="bi bi-plus-lg me-1"></i>Añadir
                    </button>
                </div>
                
                <div class="table-responsive" style="max-height: 350px; overflow-y: auto;">
                    <table class="table table-hover align-middle mb-0">
                        <thead class="text-muted small sticky-top bg-white">
                            <tr>
                                <th>Nombre</th>
                                <th class="text-end">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="tbodyCategorias">
                            <!-- JS populate -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.bootstrap5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/vfs_fonts.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.print.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script src="../js/estado_cuenta_spa.js?v=4"></script>

<script>
    document.addEventListener("DOMContentLoaded", () => { 
        initModuloFinanciero('', 'bento', ''); 
    });
</script>
PAGE_HTML

render_bottom_nav('finanzas');
print "</body></html>\n";
