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
require "$FindBin::Bin/../utils/sub_sidebar.pl";
use utils::db_manager qw(leer_tabla);
use POSIX qw(strftime);

my $q = CGI->new;
my $session_data = check_session();
my $fecha_hoy = strftime("%Y-%m-%d", localtime);

if (!$session_data->{session_ok} || $session_data->{role} !~ /Administrador|Caja|Recepcionista|Medico/i) {
    print $q->redirect(-uri => '../index.html');
    exit;
}

my $id_paciente = $q->param('id') || '';

# Verificar SaaS Capabilities (PACIENTES_ESTADO)
my $has_pacientes_estado = 0;
my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
my $id_empresa = $session_data->{id_empresa} // '';
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line);
        if ($biz_id eq $id_empresa && $key eq 'PACIENTES_ESTADO') {
            $has_pacientes_estado = ($val eq '1') ? 1 : 0;
            last;
        }
    }
    close($cf);
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(usuario => $session_data->{usuario}, titulo => "Finanzas - SDM", role => $session_data->{role}, id_medico => $session_data->{id_medico}, skip_header => 1);

print <<'PAGE_HTML';
<link rel="stylesheet" href="../css/expediente_completo.css?v=3">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.1/css/buttons.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/rowgroup/1.4.1/css/rowGroup.bootstrap5.min.css">

PAGE_HTML

utils::sub_sidebar::render_sidebar(
    usuario => $session_data->{usuario},
    role => $session_data->{role},
    id_medico => $session_data->{id_medico},
    pagina_actual => 'finanzas',
    id_empresa => $session_data->{id_empresa} // ''
);

print <<'PAGE_HTML';
<script>
    console.log("[SPA Debug] Declarando funciones de control de Finanzas");

    window.swTab = function(tabId, btnElement) {
        console.log("[SPA Debug] Cambiando a pestaña: " + tabId);
        document.querySelectorAll('.sdm-tab-pane').forEach(el => el.classList.add('d-none'));
        const target = document.getElementById(tabId);
        if(target) target.classList.remove('d-none');
        
        document.querySelectorAll('.sidebar-menu .sub-link').forEach(el => el.classList.remove('active'));
        if(btnElement) {
            btnElement.classList.add('active');
        } else {
            let pureTab = tabId.replace('tab_', '');
            let link = document.querySelector(`.sidebar-menu .sub-link[href*="tab=${pureTab}"]`);
            if (link) {
                link.classList.add('active');
                let parentCollapse = link.closest('.accordion-collapse');
                if (parentCollapse && !parentCollapse.classList.contains('show')) {
                    parentCollapse.classList.add('show');
                    let btn = document.querySelector(`[data-bs-target="#${parentCollapse.id}"]`);
                    if (btn) btn.classList.remove('collapsed');
                }
            }
        }
        
        if(window.innerWidth < 992 && btnElement && typeof window.toggleSidebar === 'function') {
            window.toggleSidebar();
        }
        
        if(tabId === 'tab_cxc' && typeof window.renderCxC === 'function') window.renderCxC();
        if(tabId === 'tab_cxc_estado' && typeof window.renderCxcEstado === 'function') window.renderCxcEstado();
        if(tabId === 'tab_gastos' && typeof window.renderGastos === 'function') window.renderGastos();
        if(tabId === 'tab_ingresos' && typeof window.renderIngresos === 'function') window.renderIngresos();
        if(tabId === 'tab_reportes' && typeof window.renderReportes === 'function') window.renderReportes();
        if(tabId === 'tab_corte_caja' && typeof window.renderCorteCaja === 'function') window.renderCorteCaja();
    };
    
    window.onFinanzasSubLinkClick = function(e) {
        e.preventDefault();
        const url = new URL(this.href, window.location.origin);
        const tab = url.searchParams.get('tab');
        console.log("[SPA Debug] Interceptado click en sidebar link para tab: " + tab);
        window.history.pushState({ spa: true }, '', this.href);
        window.swTab('tab_' + tab, this);
    };

    window.initFinanzasTabs = function() {
        console.log("[SPA Debug] Inicializando pestañas de Finanzas...");
        const urlParams = new URLSearchParams(window.location.search);
        const activeTab = urlParams.get('tab') || 'resumen';
        window.swTab('tab_' + activeTab);
        
        // Intercept sidebar links to prevent reload if already in finanzas
        document.querySelectorAll('.sidebar-menu .sub-link[href*="finanzas.pl?tab="]').forEach(link => {
            link.removeEventListener('click', window.onFinanzasSubLinkClick);
            link.addEventListener('click', window.onFinanzasSubLinkClick);
        });
    };

    // Registrar en DOMContentLoaded para carga normal, y spa:contentLoaded para navegación SPA
    document.addEventListener("DOMContentLoaded", window.initFinanzasTabs);
    document.addEventListener("spa:contentLoaded", window.initFinanzasTabs);

    window.cancelarRecibo = function(id, tipo) {
        if(typeof Swal === 'undefined') return;
        Swal.fire({
            title: '¿Cancelar Recibo?',
            text: "Esta acción marcará el recibo como cancelado. Por favor, explique el motivo:",
            input: 'text',
            inputAttributes: {
                autocapitalize: 'off',
                required: 'true',
                placeholder: 'Motivo de cancelación'
            },
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, Cancelar',
            cancelButtonText: 'No',
            preConfirm: (motivo) => {
                if (!motivo || motivo.trim() === '') {
                    Swal.showValidationMessage('Debe ingresar un motivo de cancelación');
                    return false;
                }
                return motivo;
            }
        }).then((result) => {
            if (result.isConfirmed) {
                let motivo = result.value;
                $.post('../api/cancelar_recibo_api.pl', { id_recibo: id, tipo: tipo, motivo: motivo }, function(res) {
                    if (res.ok) {
                        Swal.fire('Cancelado', res.msg, 'success');
                        if ($.fn.DataTable.isDataTable('#dtPublicosCxC')) {
                            $('#dtPublicosCxC').DataTable().ajax.reload(null, false);
                        }
                    } else {
                        Swal.fire('Error', res.msg, 'error');
                    }
                }, 'json');
            }
        });
    };
</script>
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


                <!-- KPI Cards Acrílicos -->
                <div class="kpi-grid mb-4">
                    <!-- Ingresos Totales -->
                    <div class="kpi-acrilico">
                        <div class="kpi-icono" style="color: #10b981;"><i class="bi bi-cash-stack"></i></div>
                        <div class="kpi-titulo">Ingresos Reales</div>
                        <div class="kpi-valor" id="kpiIngresosTotales">$0.00</div>
                        <div class="kpi-subtexto text-success fw-bold">(Cobrado)</div>
                    </div>
                    <!-- Total Egresos -->
                    <div class="kpi-acrilico">
                        <div class="kpi-icono" style="color: #ef4444;"><i class="bi bi-graph-down-arrow"></i></div>
                        <div class="kpi-titulo">Total Gastos</div>
                        <div class="kpi-valor" id="kpiTotalEgresos">$0.00</div>
                        <div class="kpi-subtexto text-danger fw-bold">(Pagado)</div>
                    </div>
                    <!-- Cuentas por Cobrar -->
                    <div class="kpi-acrilico">
                        <div class="kpi-icono" style="color: #eab308;"><i class="bi bi-wallet2"></i></div>
                        <div class="kpi-titulo">Cuentas por Cobrar</div>
                        <div class="kpi-valor" id="kpiCuentasCobrar">$0.00</div>
                        <div class="kpi-subtexto text-warning fw-bold">(Privadas)</div>
                    </div>
PAGE_HTML

    if ($has_pacientes_estado) {
        print <<'PAGE_HTML';
                    <!-- Cuentas por Cobrar al Estado -->
                    <div class="kpi-acrilico">
                        <div class="kpi-icono" style="color: #0ea5e9;"><i class="bi bi-bank"></i></div>
                        <div class="kpi-titulo">CxC (Estado)</div>
                        <div class="kpi-valor" id="kpiCxcEstado">$0.00</div>
                        <div class="kpi-subtexto text-info fw-bold">(Públicas)</div>
                    </div>
PAGE_HTML
    }

    print <<'PAGE_HTML';
                    <!-- Cotizaciones Activas -->
                    <div class="kpi-acrilico">
                        <div class="kpi-icono" style="color: #f59e0b;"><i class="bi bi-file-earmark-text"></i></div>
                        <div class="kpi-titulo">Cotizado</div>
                        <div class="kpi-valor" id="kpiPresupuestosActivos">$0.00</div>
                        <div class="kpi-subtexto text-warning fw-bold">(Cotizaciones)</div>
                    </div>
                    <!-- Facturación del Mes -->
                    <div class="kpi-acrilico">
                        <div class="kpi-icono" style="color: #3b82f6;"><i class="bi bi-file-earmark-text"></i></div>
                        <div class="kpi-titulo">Facturación del Mes</div>
                        <div class="kpi-valor" id="kpiFacturacion">$0.00</div>
                        <div class="kpi-subtexto text-primary fw-bold">(CFDI)</div>
                    </div>
                    <!-- Eficiencia de Cobro -->
                    <div class="kpi-acrilico">
                        <div class="kpi-icono" style="color: #059669;"><i class="bi bi-percent"></i></div>
                        <div class="kpi-titulo">Eficiencia de Cobro</div>
                        <div class="kpi-valor" id="kpiEficiencia">0%</div>
                        <div class="kpi-subtexto text-success fw-bold">(Tasa Real)</div>
                    </div>
                </div>

                <div class="row g-4 mb-4">
                    <div class="col-lg-7">
                        <div class="card-acrilico h-100">
                            <h6 class="fw-bold plus-jakarta mb-4 text-dark">Evolución de Ingresos</h6>
                            <div style="height: 250px; width: 100%;">
                                <canvas id="lineEvolucionIngresos"></canvas>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-lg-5">
                        <div class="card-acrilico h-100 d-flex flex-column justify-content-center">
                            <div class="d-flex justify-content-between align-items-center mb-4">
                                <h6 class="fw-bold plus-jakarta m-0 text-dark">Ingresos vs Egresos</h6>
                                <select class="form-select form-select-sm w-auto rounded-pill text-muted fw-bold bg-light border-0"><option>Histórico</option></select>
                            </div>
                            
                            <div class="d-flex flex-column align-items-center g-0">
                                <div class="position-relative mb-4" style="height: 180px; width: 100%;">
                                    <canvas id="pieResumenFinanzas"></canvas>
                                    <div class="position-absolute top-50 start-50 translate-middle text-center w-100" style="pointer-events: none; margin-top: 2px;">
                                        <h5 class="fw-bold text-dark m-0 plus-jakarta" id="pieCenterValFinanzas" style="font-size: 1.1rem;">$0</h5>
                                        <span class="text-muted fw-bold" style="font-size: 0.7rem; text-transform: uppercase;">Total</span>
                                    </div>
                                </div>
                                <div class="d-flex justify-content-center gap-4 w-100">
                                    <!-- Ingresos -->
                                    <div class="d-flex align-items-center">
                                        <div style="width: 12px; height: 12px; border-radius: 50%; background: linear-gradient(to bottom, #00FF7F, #007A3D, #003D1F); box-shadow: inset 0 2px 4px rgba(255,255,255,0.6), inset 0 -2px 4px rgba(0,0,0,0.8), 0 2px 4px rgba(0,0,0,0.2); margin-right: 8px; flex-shrink: 0;"></div>
                                        <div class="d-flex align-items-baseline gap-1">
                                            <span class="text-muted" style="font-size: 0.7rem;">Ingresos</span>
                                            <span class="fw-bold plus-jakarta" style="font-size: 0.9rem; color: var(--md-blue-deep);" id="legIngresosFinanzas">$0.00</span>
                                        </div>
                                    </div>
                                    
                                    <!-- Egresos -->
                                    <div class="d-flex align-items-center">
                                        <div style="width: 12px; height: 12px; border-radius: 50%; background: linear-gradient(to bottom, #FF4D4D, #A63A3A, #5C0000); box-shadow: inset 0 2px 4px rgba(255,255,255,0.6), inset 0 -2px 4px rgba(0,0,0,0.8), 0 2px 4px rgba(0,0,0,0.2); margin-right: 8px; flex-shrink: 0;"></div>
                                        <div class="d-flex align-items-baseline gap-1">
                                            <span class="text-muted" style="font-size: 0.7rem;">Egresos</span>
                                            <span class="fw-bold plus-jakarta" style="font-size: 0.9rem; color: var(--md-blue-deep);" id="legEgresosFinanzas">$0.00</span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Resumen de Ingresos (Table) -->
                <div class="bento-card mb-5">
                    <h6 class="fw-bold plus-jakarta mb-4 text-dark">Resumen de Ingresos Recientes</h6>
                    <div class="table-responsive">
                        <table class="table table-sm table-striped table-hover table-bordered align-middle mb-0 table-diamond" id="tablaResumenIngresos">
                            <thead class="text-muted small">
                                <tr>
                                    <th class="border-0">Fecha</th>
                                    <th class="border-0">Concepto</th>
                                    <th class="border-0">Folio</th>
                                    <th class="border-0">Paciente</th>
                                    <th class="border-0">Monto</th>
                                    <th class="border-0">Tipo</th>
                                    <th class="border-0 text-center">Opciones</th>
                                </tr>
                            </thead>
                            <tbody id="tbodyResumenIngresos">
                                <!-- JS fills this -->
                            </tbody>
                            <tfoot class="bg-light fw-bold">
                                <tr>
                                    <td colspan="4" class="text-end">Total:</td>
                                    <td id="tfootResumenMonto"></td>
                                    <td colspan="2"></td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>
                    <div class="text-center mt-4">
                        <button class="btn btn-sm btn-link text-decoration-none fw-bold" onclick="swTab('tab_ingresos', document.querySelectorAll('.sub-link')[1])" style="color: var(--md-blue-deep);">Ver historial completo de ingresos <i class="bi bi-chevron-right"></i></button>
                    </div>
                </div>
            </div>

            <!-- TAB: INGRESOS -->
            <div id="tab_ingresos" class="sdm-tab-pane d-none">
                <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3">
                    <div>
                        <h4 class="fw-bold plus-jakarta m-0 text-dark"><i class="bi bi-graph-up-arrow me-2 text-primary"></i>Historial de Ingresos</h4>
                        <p class="text-muted m-0 small">Filtro y registro de ingresos por rango de fecha.</p>
                    </div>
                    <div class="d-flex gap-2 flex-wrap align-items-center">
                        <div class="d-flex align-items-center gap-1">
                            <span class="small text-muted fw-bold">Desde:</span>
                            <input type="date" id="ing_fecha_inicio" class="form-control form-control-sm" title="Fecha Inicio">
                        </div>
                        <div class="d-flex align-items-center gap-1">
                            <span class="small text-muted fw-bold">Hasta:</span>
                            <input type="date" id="ing_fecha_fin" class="form-control form-control-sm" title="Fecha Fin">
                        </div>
                        <button class="btn btn-aura-save btn-mobile-standard btn-sm px-3 fw-bold" onclick="cargarIngresos()"><i class="bi bi-funnel me-1"></i>Filtrar</button>
                    </div>
                </div>

                <div class="row g-4">
                    <!-- Tabla 1: Ingresos Privados / Efectivo -->
                    <div class="col-12">
                        <div class="card card-medentia-aura border-0 shadow-sm p-4 rounded-4">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <div>
                                    <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);"><i class="bi bi-wallet2 me-2 text-primary"></i>Ingresos (Efectivo / Privados)</h5>
                                    <p class="text-muted small m-0">Detalle de ingresos recibidos por servicios privados en el periodo seleccionado.</p>
                                </div>
                            </div>
                            <div class="table-responsive">
                                <table id="dtIngresosPrivados" class="table table-hover table-sm align-middle w-100" style="font-size: 10px !important;">
                                    <thead class="table-light text-muted" style="font-size: 10.5px !important;">
                                        <tr>
                                            <th style="width: 8%;">Folio</th>
                                            <th style="width: 12%;">Fecha</th>
                                            <th style="width: 30%;">Paciente</th>
                                            <th style="width: 20%;">Médico</th>
                                            <th style="width: 12%;">Forma Pago</th>
                                            <th style="width: 10%;" class="text-end">Monto</th>
                                            <th style="width: 8%;" class="text-center">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody style="font-size: 10px !important;"></tbody>
                                    <tfoot class="bg-light fw-bold" style="font-size: 11px !important;">
                                        <tr>
                                            <th colspan="5" class="text-end">Total Ingresos Privados:</th>
                                            <th class="text-end text-success" id="tfootTotalPrivados">$0.00</th>
                                            <th></th>
                                        </tr>
                                    </tfoot>
                                </table>
                            </div>
                        </div>
                    </div>

                    <!-- Tabla 2: Ingresos Municipio -->
                    <div class="col-12">
                        <div class="card card-medentia-aura border-0 shadow-sm p-3 rounded-4">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <div>
                                    <h5 class="fw-bold m-0" style="color: var(--md-blue-deep); font-size: 14px;"><i class="bi bi-building me-2 text-info"></i>Ingresos Municipio</h5>
                                    <p class="text-muted small m-0" style="font-size: 11px;">Detalle de ingresos generados por derechohabientes del Municipio en el periodo seleccionado.</p>
                                </div>
                            </div>
                            <div class="table-responsive">
                                <table id="dtIngresosMunicipio" class="table table-hover table-sm align-middle w-100" style="font-size: 10px !important;">
                                    <thead class="table-light text-muted" style="font-size: 10.5px !important;">
                                        <tr>
                                            <th style="width: 8%;">Folio OS</th>
                                            <th style="width: 12%;">Fecha</th>
                                            <th style="width: 32%;">Paciente / Trabajador</th>
                                            <th style="width: 18%;">Dependencia</th>
                                            <th style="width: 15%;">Médico</th>
                                            <th style="width: 7%;" class="text-end">Monto</th>
                                            <th style="width: 8%;" class="text-center">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody style="font-size: 10px !important;"></tbody>
                                    <tfoot class="bg-light fw-bold" style="font-size: 11px !important;">
                                        <tr>
                                            <th colspan="5" class="text-end">Total Ingresos Municipio:</th>
                                            <th class="text-end text-info" id="tfootTotalMunicipio">$0.00</th>
                                            <th></th>
                                        </tr>
                                    </tfoot>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- TAB: GASTOS -->
            <div id="tab_gastos" class="sdm-tab-pane d-none">
                <div class="bento-card">
                    <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                        <div>
                            <h4 class="fw-bold plus-jakarta m-0 text-dark">Control de Egresos</h4>
                            <p class="text-muted m-0 small">Administración de gastos operativos, proveedores y pagos.</p>
                        </div>
                        <button class="btn btn-primary rounded-pill fw-bold btn-medentia-action" onclick="abrirModalGasto()"><i class="bi bi-plus-lg me-2"></i>Registrar Gasto</button>
                    </div>
                    
                    <div class="table-responsive mt-3">
                        <table class="table table-sm table-striped table-hover table-bordered align-middle table-diamond" id="tablaGastos" style="font-size: 10px !important;">
                            <thead class="text-muted" style="font-size: 10.5px !important;">
                                <tr>
                                    <th>Fecha</th>
                                    <th>Categoría / Sub</th>
                                    <th>Proveedor</th>
                                    <th>Origen</th>
                                    <th>Concepto</th>
                                    <th>Monto</th>
                                    <th>Factura</th>
                                    <th>Acciones</th>
                                </tr>
                            </thead>
                            <tbody id="tbodyGastos" style="font-size: 10px !important;">
                                <tr><td colspan="8" class="text-center text-muted"><div class="spinner-border text-primary spinner-border-sm me-2"></div>Cargando...</td></tr>
                            </tbody>
                            <tfoot class="bg-light fw-bold" style="font-size: 11px !important;">
                                <tr>
                                    <td colspan="5" class="text-end">Total Gastos:</td>
                                    <td id="tfootGastosMonto"></td>
                                    <td colspan="2"></td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>
                </div>
            </div>



            <!-- TAB: CUENTAS POR COBRAR -->
            <div id="tab_cxc" class="sdm-tab-pane d-none">
                <div class="bento-card">
                    <h4 class="fw-bold plus-jakarta mb-4 text-dark">Cuentas por Cobrar (CxC)</h4>
                    <p class="text-muted">Pacientes con saldos pendientes. Calculado en tiempo real.</p>
                    <div class="table-responsive mt-3">
                        <table class="table table-sm table-striped table-hover table-bordered align-middle table-diamond" id="tablaCxC">
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
                            <tfoot class="bg-light fw-bold">
                                <tr>
                                    <td colspan="2" class="text-end">Totales:</td>
                                    <td id="tfootCxCCargos"></td>
                                    <td id="tfootCxCAbonos"></td>
                                    <td id="tfootCxCSaldo"></td>
                                    <td></td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>
                </div>
            </div>

PAGE_HTML

    if ($has_pacientes_estado) {
        print <<'PAGE_HTML';
            <!-- TAB: CUENTAS POR COBRAR ESTADO -->
            <div id="tab_cxc_estado" class="sdm-tab-pane d-none">
                <div class="bento-card">
                    <h4 class="fw-bold plus-jakarta mb-4 text-dark">Movimientos de Recibos de Municipio</h4>
                    <p class="text-muted">Ingresos generados por pacientes del Estado.</p>
                    <div class="table-responsive mt-3">
                        <table class="table table-sm table-striped table-hover table-bordered align-middle table-diamond w-100" id="dtPublicosCxC">
                            <thead class="table-light text-secondary small">
                                <tr>
                                    <th>Folio</th>
                                    <th>Fecha</th>
                                    <th>Paciente</th>
                                    <th>Concepto</th>
                                    <th>Medico</th>
                                    <th>Detalle</th>
                                    <th>Total</th>
                                    <th>Estatus</th>
                                    <th>Opciones</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr><td colspan="9" class="text-center text-muted">Cargando...</td></tr>
                            </tbody>
                            <tfoot class="bg-light fw-bold">
                                <tr>
                                    <th colspan="6" style="text-align:right; font-weight:bold;">Total:</th>
                                    <th style="font-weight:bold;"></th>
                                    <th colspan="2"></th>
                                </tr>
                            </tfoot>
                        </table>
                    </div>
                </div>
            </div>
PAGE_HTML
    }

    print <<'PAGE_HTML';

            <!-- TAB: FACTURACION -->
            <div id="tab_facturacion" class="sdm-tab-pane d-none">
                <div class="bento-card">
                    <h4 class="fw-bold plus-jakarta mb-4 text-dark">Facturación Electrónica (PAC SAT)</h4>
                    <p class="text-muted">Pronto: Emisión de CFDI 4.0 conectado a PAC.</p>
                </div>
            </div>

            <!-- TAB: REPORTES -->
            <div id="tab_reportes" class="sdm-tab-pane d-none">
                <div class="bento-card">
                    <h4 class="fw-bold plus-jakarta mb-4 text-dark">Reportes Financieros (P&L)</h4>
                    <p class="text-muted">Pronto: Generador de estados de resultados y exportación a PDF/Excel.</p>
                </div>
            </div>

        </div> <!-- content-wrapper -->
    
<!-- Modal Nuevo Gasto (Floating Armor) - Movido fuera del contexto de apilamiento para evitar solapamiento con navbar -->
<div class="modal fade modal-diamond" id="modalGasto" tabindex="-1" aria-hidden="true" style="z-index: 105000 !important;">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 shadow-lg">
            <div class="modal-header">
                <h5 class="modal-title d-flex align-items-center m-0">
                    <i class="bi bi-cash-stack me-2" style="color: #00C4C4 !important;"></i>
                    <span>Registrar Gasto</span>
                </h5>
                <div class="d-flex align-items-center gap-2">
                    <button type="button" class="btn btn-sm btn-light rounded-circle text-muted" onclick="abrirModalCategorias()" title="Gestionar Categorías">
                        <i class="bi bi-gear-fill"></i>
                    </button>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
            </div>
            <div class="modal-body">
                <form id="formGasto">
                    <div class="row">
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label for="fecha_gasto" class="form-label">Fecha del Gasto</label>
                                <input type="date" class="form-control" id="fecha_gasto" required>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label for="origen_gasto" class="form-label d-flex justify-content-between">
                                    <span>Origen del Dinero</span>
                                    <a href="javascript:void(0)" onclick="abrirModalOrigenesDinero()" class="text-muted"><i class="bi bi-gear-fill"></i></a>
                                </label>
                                <select class="form-select" id="origen_gasto" required>
                                    <option value="">Cargando...</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-4">
                            <div class="mb-3">
                                <label for="cat_gasto" class="form-label">Categoría Principal</label>
                                <select class="form-select" id="cat_gasto" required onchange="filtrarSubcategorias()">
                                    <option value="">Seleccione...</option>
                                </select>
                            </div>
                        </div>
                        <div class="col-md-4" id="col_subcat_gasto" style="display:none;">
                            <div class="mb-3">
                                <label for="subcat_gasto" class="form-label">Subcategoría Nivel 2</label>
                                <select class="form-select" id="subcat_gasto" onchange="filtrarSubcategorias3()">
                                    <option value="">Seleccione...</option>
                                </select>
                            </div>
                        </div>
                        <div class="col-md-4" id="col_subcat3_gasto" style="display:none;">
                            <div class="mb-3">
                                <label for="subcat3_gasto" class="form-label">Detalle Gasto (Nivel 3)</label>
                                <select class="form-select" id="subcat3_gasto">
                                    <option value="">Seleccione...</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label for="proveedor_gasto" class="form-label">Proveedor</label>
                                <input type="text" class="form-control" id="proveedor_gasto" placeholder="Ingresa el proveedor" required>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label for="concepto_gasto" class="form-label">Concepto / Descripción</label>
                                <input type="text" class="form-control" id="concepto_gasto" placeholder="Describe el gasto" required>
                            </div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label for="monto_gasto" class="form-label">Monto Total ($)</label>
                                <input type="number" step="0.01" class="form-control" id="monto_gasto" placeholder="0.00" required>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label for="factura_gasto" class="form-label">Adjuntar Factura (Opcional)</label>
                                <input type="file" class="form-control" id="factura_gasto" accept=".pdf,.png,.jpg,.jpeg">
                            </div>
                        </div>
                    </div>
                    <button type="submit" class="btn w-100 rounded-pill fw-bold text-white shadow-sm mt-2" style="background: var(--md-blue-medical);">Guardar Gasto</button>
                </form>
            </div>
        </div>
    </div>
</div>

<!-- TAB: CORTE DE CAJA -->
<div id="tab_corte_caja" class="sdm-tab-pane d-none">
    <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap">
        <h5 class="fw-bold mb-2 m-0" style="color: var(--md-blue-medical);"><i class="bi bi-safe me-2"></i>Corte de Caja Diario</h5>
        <div class="d-flex gap-2">
            <button class="btn btn-outline-secondary btn-mobile-standard px-3 fw-bold" onclick="imprimirResumenEjecutivo()"><i class="bi bi-printer me-1"></i>Imprimir Resumen</button>
            <input type="date" id="cc_fecha_inicio" class="form-control" title="Fecha Inicio">
            <input type="date" id="cc_fecha_fin" class="form-control" title="Fecha Fin">
            <button class="btn btn-aura-save btn-mobile-standard px-4" onclick="cargarCorteCaja()"><i class="bi bi-search me-1"></i>Generar</button>
        </div>
    </div>

    <!-- KPIs -->
    <div class="row g-3 mb-4">
        <div class="col-12 col-sm-6 col-md-3">
            <div class="kpi-acrilico h-100">
                <div class="kpi-icono text-success"><i class="bi bi-arrow-down-circle"></i></div>
                <div class="kpi-titulo">Ingresos (Efvo)</div>
                <div class="kpi-valor" id="cc_ingresos">$0.00</div>
            </div>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
            <div class="kpi-acrilico h-100">
                <div class="kpi-icono text-info"><i class="bi bi-building"></i></div>
                <div class="kpi-titulo">Ingresos Municipio</div>
                <div class="kpi-valor" id="cc_cxc">$0.00</div>
            </div>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
            <div class="kpi-acrilico h-100">
                <div class="kpi-icono text-danger"><i class="bi bi-arrow-up-circle"></i></div>
                <div class="kpi-titulo">Egresos</div>
                <div class="kpi-valor" id="cc_egresos">$0.00</div>
            </div>
        </div>
        <div class="col-12 col-sm-6 col-md-3">
            <div class="kpi-acrilico bg-white bg-opacity-75 h-100">
                <div class="kpi-icono text-warning"><i class="bi bi-cash"></i></div>
                <div class="kpi-titulo">Efectivo Físico</div>
                <input type="number" id="cc_fisico" class="form-control mt-2 text-center fw-bold fs-5 shadow-sm border-2 rounded-3 text-primary" value="0" oninput="calcularFaltante()" placeholder="0.00">
            </div>
        </div>
        <div class="col-12">
            <div class="kpi-acrilico h-100" id="kpi_diferencia_box">
                <div class="kpi-icono text-secondary" id="cc_dif_icon"><i class="bi bi-calculator"></i></div>
                <div class="kpi-titulo">Faltante / Sobrante</div>
                <div class="kpi-valor" id="cc_diferencia">$0.00</div>
                <div class="kpi-subtexto" id="cc_dif_label">Efectivo Físico - (Ingresos - Egresos)</div>
            </div>
        </div>
    </div>

    <div class="row">
        <!-- Tablas de Desglose -->
        <div class="col-12 mb-4">
            <div class="card card-medentia-aura h-100 p-3 card-mobile-flush container-mobile-flush border-0">
                <ul class="nav nav-tabs sdm-tabs mb-3" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active fw-bold" data-bs-toggle="tab" data-bs-target="#cc_tab_ingresos" type="button"><i class="bi bi-graph-up me-1 text-success"></i>Ingresos</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link fw-bold" data-bs-toggle="tab" data-bs-target="#cc_tab_cxc" type="button"><i class="bi bi-building me-1 text-info"></i>Ingresos Municipio</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link fw-bold" data-bs-toggle="tab" data-bs-target="#cc_tab_egresos" type="button"><i class="bi bi-graph-down text-danger me-1"></i>Egresos</button>
                    </li>
                </ul>
                <div class="tab-content">
                    <div class="tab-pane fade show active" id="cc_tab_ingresos" role="tabpanel">
                        <div class="table-responsive">
                            <table id="dtCorteIngresos" class="table table-hover dt-responsive-mobile nowrap w-100">
                                <thead class="table-light text-muted small">
                                    <tr>
                                        <th>Folio</th>
                                        <th>Fecha</th>
                                        <th>Paciente</th>
                                        <th>Médico</th>
                                        <th>Forma de Pago</th>
                                        <th class="text-end">Monto</th>
                                    </tr>
                                </thead>
                                <tbody></tbody>
                            </table>
                        </div>
                    </div>
                    <div class="tab-pane fade" id="cc_tab_cxc" role="tabpanel">
                        <div class="table-responsive">
                            <table id="dtCorteCxC" class="table table-hover dt-responsive-mobile nowrap w-100">
                                <thead class="table-light text-muted small">
                                    <tr>
                                        <th>Folio OS</th>
                                        <th>Fecha</th>
                                        <th>Paciente</th>
                                        <th>Médico</th>
                                        <th>Categoría</th>
                                        <th class="text-end">Monto</th>
                                    </tr>
                                </thead>
                                <tbody></tbody>
                            </table>
                        </div>
                    </div>
                    <div class="tab-pane fade" id="cc_tab_egresos" role="tabpanel">
                        <div class="table-responsive">
                            <table id="dtCorteEgresos" class="table table-hover dt-responsive-mobile nowrap w-100">
                                <thead class="table-light text-muted small">
                                    <tr>
                                        <th>Folio</th>
                                        <th>Fecha</th>
                                        <th>Categoría</th>
                                        <th>Proveedor</th>
                                        <th>Concepto</th>
                                        <th class="text-end">Monto</th>
                                    </tr>
                                </thead>
                                <tbody></tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="row">
        <!-- Gráfica -->
        <div class="col-12 mb-4">
            <div class="card card-medentia-aura p-3 card-mobile-flush container-mobile-flush border-0">
                <h6 class="fw-bold mb-3 text-muted">Distribución de Corte de Caja</h6>
                <div style="position: relative; height: 350px; width: 100%;">
                    <canvas id="chartCorteCaja"></canvas>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
    window.renderIngresos = function() {
        console.log("[Ingresos] Inicializando vista de ingresos");
        let hoy = new Date().toISOString().split('T')[0];
        const elInicio = document.getElementById('ing_fecha_inicio');
        const elFin = document.getElementById('ing_fecha_fin');
        if (elInicio) elInicio.value = hoy;
        if (elFin) elFin.value = hoy;
        
        cargarIngresos();
    };

    window.cancelarRecibo = function(id_recibo, tipo) {
        if (!id_recibo) return;
        
        if (typeof Swal === 'undefined') {
            alert("SweetAlert2 no está disponible.");
            return;
        }

        Swal.fire({
            title: 'Cancelar Recibo',
            html: '<p class="text-muted small">Está a punto de cancelar el recibo <strong>' + id_recibo + '</strong> (' + tipo + ').</p>',
            input: 'textarea',
            inputPlaceholder: 'Ingrese el motivo detallado de la cancelación aquí...',
            inputAttributes: {
                'aria-label': 'Motivo de la cancelación',
                'rows': 3
            },
            showCancelButton: true,
            confirmButtonColor: '#ef4444',
            cancelButtonColor: '#6c757d',
            confirmButtonText: '<i class="bi bi-trash-fill me-1"></i> Confirmar Cancelación',
            cancelButtonText: 'Cancelar',
            customClass: {
                confirmButton: 'btn btn-danger btn-mobile-standard rounded-pill px-4',
                cancelButton: 'btn btn-secondary btn-mobile-standard rounded-pill px-4'
            },
            inputValidator: (value) => {
                if (!value || !value.trim()) {
                    return '¡Debe ingresar un motivo obligatorio para cancelar el recibo!';
                }
            }
        }).then((result) => {
            if (result.isConfirmed) {
                const motivo = result.value.trim();
                $.ajax({
                    url: '../api/cancelar_recibo_api.pl',
                    type: 'POST',
                    dataType: 'json',
                    data: { id_recibo: id_recibo, tipo: tipo, motivo: motivo },
                    success: function(res) {
                        if (res.ok) {
                            Swal.fire({
                                icon: 'success',
                                title: 'Recibo Cancelado',
                                text: res.msg || 'El recibo fue cancelado correctamente.',
                                timer: 2000,
                                showConfirmButton: false
                            });
                            cargarIngresos();
                            if (typeof cargarCorteCaja === 'function') cargarCorteCaja();
                        } else {
                            Swal.fire('Error', res.msg || 'No se pudo cancelar el recibo.', 'error');
                        }
                    },
                    error: function() {
                        Swal.fire('Error', 'Error al comunicarse con el servidor para cancelar el recibo.', 'error');
                    }
                });
            }
        });
    };

    window.cargarIngresos = function() {
        const elInicio = document.getElementById('ing_fecha_inicio');
        const elFin = document.getElementById('ing_fecha_fin');
        let hoy = new Date().toISOString().split('T')[0];

        if (elInicio && !elInicio.value) elInicio.value = hoy;
        if (elFin && !elFin.value) elFin.value = hoy;

        let f_inicio = elInicio ? elInicio.value : hoy;
        let f_fin = elFin ? elFin.value : hoy;

        $.ajax({
            url: '../api/generar_corte_caja.pl',
            type: 'POST',
            dataType: 'json',
            data: { f_inicio: f_inicio, f_fin: f_fin },
            success: function(res) {
                if (res.error) {
                    if (typeof Swal !== 'undefined') Swal.fire('Error', res.msg || 'Error al cargar ingresos', 'error');
                    return;
                }

                let dataIngresos = (res && Array.isArray(res.ingresos)) ? res.ingresos : [];
                let dataMunicipio = (res && Array.isArray(res.cxc)) ? res.cxc : [];

                renderTablaCorte('#dtIngresosPrivados', dataIngresos, [
                    { 
                        data: 'folio',
                        render: function(d) {
                            return `<span class="badge bg-light text-dark border font-monospace px-2 py-1" style="font-size: 9.5px;">${d || ''}</span>`;
                        }
                    },
                    { 
                        data: 'fecha',
                        render: function(d) {
                            if (!d) return '';
                            let parts = d.split(' ');
                            let f = parts[0] || '';
                            let h = parts[1] || '';
                            return `<div class="text-nowrap fw-semibold" style="font-size: 10px;">${f}</div><div class="text-muted text-nowrap" style="font-size: 9.5px;">${h}</div>`;
                        }
                    },
                    { 
                        data: 'paciente',
                        render: function(data, type, row) {
                            let isCancel = (row.estatus === 'Cancelado');
                            let pacHtml = `<div class="fw-bold ${isCancel ? 'text-decoration-line-through text-muted' : 'text-dark'}" style="font-size: 10.5px;">${data || ''}</div>`;
                            if (isCancel) {
                                pacHtml += `<div class="d-flex align-items-center gap-1 mt-1">
                                    <span class="badge bg-danger text-uppercase px-2 py-0" style="font-size: 8.5px;"><i class="bi bi-x-circle me-1"></i>CANCELADO</span>
                                    <span class="text-danger fw-semibold" style="font-size: 9.5px;">Motivo: ${row.motivo || 'Sin motivo registrado'}</span>
                                </div>`;
                            }
                            return pacHtml;
                        }
                    },
                    { 
                        data: 'medico',
                        render: function(d) {
                            return `<span class="text-muted fw-semibold d-block text-truncate" style="max-width: 140px; font-size: 10px;" title="${d || 'N/D'}">${d || 'N/D'}</span>`;
                        }
                    },
                    { 
                        data: 'forma_pago',
                        render: function(data, type, row) {
                            if (row.estatus === 'Cancelado') {
                                return `<span class="badge bg-danger text-uppercase px-2 py-0" style="font-size: 8.5px;"><i class="bi bi-x-circle me-1"></i>CANCELADO</span>`;
                            }
                            return `<span class="badge bg-light text-dark border px-2 py-1" style="font-size: 9.5px;">${data || 'Efectivo'}</span>`;
                        }
                    },
                    { 
                        data: 'monto', 
                        className: 'text-end',
                        render: function(data, type, row) {
                            let val = parseFloat(data) || 0;
                            let fmt = '$' + val.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                            if (row.estatus === 'Cancelado') {
                                return `<span class="text-decoration-line-through text-danger fw-bold text-nowrap" style="font-size: 11px;">${fmt}</span>`;
                            }
                            return `<span class="text-success fw-bold text-nowrap" style="font-size: 11.5px;">${fmt}</span>`;
                        }
                    },
                    {
                        data: null,
                        className: 'text-center',
                        orderable: false,
                        render: function(data, type, row) {
                            let f = row.folio_raw || row.folio || '';
                            let isCancel = (row.estatus === 'Cancelado');
                            let btnDelete = isCancel ?
                                `<button class="btn btn-sm btn-outline-secondary rounded-pill px-2 py-0 disabled text-nowrap" style="font-size: 9px;" title="Ya está cancelado"><i class="bi bi-x-circle me-1"></i>Cancelado</button>` :
                                `<button class="btn btn-sm btn-outline-danger shadow-sm rounded-pill px-2 py-0 text-nowrap" style="font-size: 9px;" onclick="cancelarRecibo('${f}', 'privados')" title="Cancelar Recibo"><i class="bi bi-trash-fill me-1"></i>Eliminar</button>`;
                            return `<div class="d-flex justify-content-center align-items-center gap-1 text-nowrap">
                                <button class="btn btn-sm btn-outline-primary shadow-sm rounded-pill px-2 py-0 text-nowrap" style="font-size: 9.5px;" onclick="window.open('../api/ver_recibo.pl?tipo=privados&id_os=${f}', '_blank')" title="Ver / Imprimir Recibo Privado"><i class="bi bi-printer-fill me-1"></i>Ver Recibo</button>
                                ${btnDelete}
                            </div>`;
                        }
                    }
                ]);

                renderTablaCorte('#dtIngresosMunicipio', dataMunicipio, [
                    { 
                        data: 'folio',
                        render: function(d) {
                            return `<span class="badge bg-light text-dark border font-monospace px-2 py-1" style="font-size: 9.5px;">${d || ''}</span>`;
                        }
                    },
                    { 
                        data: 'fecha',
                        render: function(d) {
                            if (!d) return '';
                            let parts = d.split(' ');
                            let f = parts[0] || '';
                            let h = parts[1] || '';
                            return `<div class="text-nowrap fw-semibold" style="font-size: 10px;">${f}</div><div class="text-muted text-nowrap" style="font-size: 9.5px;">${h}</div>`;
                        }
                    },
                    { 
                        data: 'paciente',
                        render: function(data, type, row) {
                            let isCancel = (row.estatus === 'Cancelado');
                            let rawPac = (data || '').replace(/^Paciente:\s*/i, '').trim();
                            if (!rawPac || /^Metodo:/i.test(rawPac)) {
                                rawPac = row.trabajador_nombre || 'Empleado Estatal';
                            }
                            let empNum = row.num_empleado || '';
                            let empNom = row.trabajador_nombre || '';

                            let txtTrabajador = empNom ? (empNum ? `${empNum} - ${empNom}` : empNom) : (empNum ? empNum : '');

                            let html = `<div class="fw-bold ${isCancel ? 'text-decoration-line-through text-muted' : 'text-dark'}" style="font-size: 10.5px;"><i class="bi bi-person-fill me-1 text-primary"></i>${escapeHtml(rawPac)}</div>`;
                            
                            if (txtTrabajador && rawPac.toLowerCase() !== empNom.toLowerCase()) {
                                html += `<div class="text-muted ${isCancel ? 'text-decoration-line-through' : ''}" style="font-size: 9.5px;"><i class="bi bi-person-badge me-1 text-secondary"></i><strong>Trabajador:</strong> ${escapeHtml(txtTrabajador)}</div>`;
                            } else if (empNum) {
                                html += `<div class="text-muted ${isCancel ? 'text-decoration-line-through' : ''}" style="font-size: 9.5px;"><i class="bi bi-card-text me-1 text-secondary"></i><strong>Num. Empleado:</strong> ${escapeHtml(empNum)}</div>`;
                            }

                            if (isCancel) {
                                html += `<div class="d-flex align-items-center gap-1 mt-1">
                                    <span class="badge bg-danger text-uppercase px-2 py-0" style="font-size: 8.5px;"><i class="bi bi-x-circle me-1"></i>CANCELADO</span>
                                    <span class="text-danger fw-semibold" style="font-size: 9.5px;">Motivo: ${escapeHtml(row.motivo || 'Sin motivo registrado')}</span>
                                </div>`;
                            }
                            return html;
                        }
                    },
                    { 
                        data: 'dependencia',
                        render: function(data, type, row) {
                            let dep = data || 'Municipio';
                            let isCancel = (row.estatus === 'Cancelado');
                            return `<div class="d-inline-block text-truncate border rounded px-2 py-0 bg-light text-dark ${isCancel ? 'text-decoration-line-through opacity-75' : ''}" style="max-width: 150px; font-size: 9.5px;" title="${dep}"><i class="bi bi-building me-1 text-info"></i>${dep}</div>`;
                        }
                    },
                    { 
                        data: 'medico',
                        render: function(d) {
                            return `<span class="text-muted fw-semibold d-block text-truncate" style="max-width: 130px; font-size: 10px;" title="${d || 'N/D'}">${d || 'N/D'}</span>`;
                        }
                    },
                    { 
                        data: 'monto', 
                        className: 'text-end',
                        render: function(data, type, row) {
                            let val = parseFloat(data) || 0;
                            let fmt = '$' + val.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                            if (row.estatus === 'Cancelado') {
                                return `<span class="text-decoration-line-through text-danger fw-bold text-nowrap" style="font-size: 11px;">${fmt}</span>`;
                            }
                            return `<span class="text-info fw-bold text-nowrap" style="font-size: 11.5px;">${fmt}</span>`;
                        }
                    },
                    {
                        data: null,
                        className: 'text-center',
                        orderable: false,
                        render: function(data, type, row) {
                            let f = row.folio_raw || row.folio || '';
                            let isCancel = (row.estatus === 'Cancelado');
                            let btnDelete = isCancel ?
                                `<button class="btn btn-sm btn-outline-secondary rounded-pill px-2 py-0 disabled text-nowrap" style="font-size: 9px;" title="Ya está cancelado"><i class="bi bi-x-circle me-1"></i>Cancelado</button>` :
                                `<button class="btn btn-sm btn-outline-danger shadow-sm rounded-pill px-2 py-0 text-nowrap" style="font-size: 9px;" onclick="cancelarRecibo('${f}', 'publicos')" title="Cancelar Recibo"><i class="bi bi-trash-fill me-1"></i>Eliminar</button>`;
                            return `<div class="d-flex justify-content-center align-items-center gap-1 text-nowrap">
                                <button class="btn btn-sm btn-outline-primary shadow-sm rounded-pill px-2 py-0 text-nowrap" style="font-size: 9.5px;" onclick="window.open('../api/ver_recibo.pl?tipo=publicos&id_os=${f}', '_blank')" title="Ver / Imprimir Recibo Municipio"><i class="bi bi-printer-fill me-1"></i>Ver Recibo</button>
                                ${btnDelete}
                            </div>`;
                        }
                    }
                ]);

                let totPriv = dataIngresos.reduce((acc, curr) => acc + (curr.estatus === 'Cancelado' ? 0 : (parseFloat(curr.monto) || 0)), 0);
                let totMuni = dataMunicipio.reduce((acc, curr) => acc + (curr.estatus === 'Cancelado' ? 0 : (parseFloat(curr.monto) || 0)), 0);

                let elTotPriv = document.getElementById('tfootTotalPrivados');
                let elTotMuni = document.getElementById('tfootTotalMunicipio');
                if (elTotPriv) elTotPriv.textContent = '$' + totPriv.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                if (elTotMuni) elTotMuni.textContent = '$' + totMuni.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
            },
            error: function() {
                if (typeof Swal !== 'undefined') Swal.fire('Error', 'Fallo al comunicarse con la API de Corte de Caja', 'error');
            }
        });
    };

    window.renderCorteCaja = function() {
        console.log("[Corte Caja] Inicializando vista");
        let hoy = new Date().toISOString().split('T')[0];
        if(!document.getElementById('cc_fecha_inicio').value) document.getElementById('cc_fecha_inicio').value = hoy;
        if(!document.getElementById('cc_fecha_fin').value) document.getElementById('cc_fecha_fin').value = hoy;
        
        cargarCorteCaja();
    };

    let ccTotalIngresos = 0;
    let ccTotalCxC = 0;
    let ccTotalEgresos = 0;
    let ccTotalEgresosFisicos = 0;
    let chartCorte = null;
    let ultimoResCorte = null;

    window.cargarCorteCaja = function() {
        let f_inicio = document.getElementById('cc_fecha_inicio').value;
        let f_fin = document.getElementById('cc_fecha_fin').value;

        $.ajax({
            url: '../api/generar_corte_caja.pl',
            type: 'POST',
            dataType: 'json',
            data: { f_inicio: f_inicio, f_fin: f_fin },
            success: function(res) {
                if(res.error) {
                    Swal.fire('Error', res.msg || 'No autorizado', 'error');
                    return;
                }
                
                ultimoResCorte = res;

                ccTotalIngresos = parseFloat(res.total_ingresos) || 0;
                ccTotalCxC = parseFloat(res.total_cxc) || 0;
                ccTotalEgresos = parseFloat(res.total_egresos) || 0;
                
                ccTotalEgresosFisicos = 0;
                if (res.egresos) {
                    res.egresos.forEach(e => {
                        let orig = (e.origen_nombre || '').toLowerCase();
                        if (orig === 'no especificado' || orig === 'desconocido' || orig.includes('caja') || orig.includes('efectivo')) {
                            ccTotalEgresosFisicos += parseFloat(e.monto) || 0;
                        }
                    });
                }
                
                document.getElementById('cc_ingresos').textContent = '\$' + ccTotalIngresos.toFixed(2);
                document.getElementById('cc_cxc').textContent = '\$' + ccTotalCxC.toFixed(2);
                document.getElementById('cc_egresos').textContent = '\$' + ccTotalEgresos.toFixed(2);
                
                // Actualizar tablas
                renderTablaCorte('#dtCorteIngresos', res.ingresos, [
                    { data: 'folio' },
                    { data: 'fecha' },
                    { data: 'paciente' },
                    { data: 'medico' },
                    { data: 'forma_pago' },
                    { data: 'monto', className: 'text-end text-success fw-bold', render: $.fn.dataTable.render.number(',', '.', 2, '$') }
                ]);
                
                renderTablaCorte('#dtCorteEgresos', res.egresos, [
                    { data: 'folio' },
                    { data: 'fecha' },
                    { data: 'categoria' },
                    { data: 'responsable' },
                    { data: 'concepto' },
                    { data: 'monto', className: 'text-end text-danger fw-bold', render: $.fn.dataTable.render.number(',', '.', 2, '$') }
                ]);

                if(res.cxc) {
                    renderTablaCorte('#dtCorteCxC', res.cxc, [
                        { data: 'folio' },
                        { data: 'fecha' },
                        { data: 'paciente' },
                        { data: 'medico' },
                        { data: 'forma_pago' },
                        { data: 'monto', className: 'text-end text-info fw-bold', render: $.fn.dataTable.render.number(',', '.', 2, '$') }
                    ]);
                }

                calcularFaltante();
            },
            error: function() {
                if (typeof Swal !== 'undefined') {
                    Swal.fire('Error', 'Fallo de comunicación con la API de Corte de Caja', 'error');
                }
            }
        });
    };

    window.renderTablaCorte = function(selector, data, columns) {
        if($.fn.DataTable.isDataTable(selector)) {
            $(selector).DataTable().clear().rows.add(data).draw();
        } else {
            $(selector).DataTable({
                data: data,
                columns: columns,
                language: { url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
                dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B><"search-box"f>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                buttons: [
                    { extend: 'copyHtml5', text: '<i class="bi bi-files me-1"></i> <span class="d-none d-md-inline">COPIAR</span>', className: 'btn btn-sm btn-export' },
                    { extend: 'excelHtml5', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> <span class="d-none d-md-inline">EXCEL</span>', className: 'btn btn-sm btn-export' },
                    { extend: 'pdfHtml5', text: '<i class="bi bi-file-earmark-pdf me-1"></i> <span class="d-none d-md-inline">PDF</span>', className: 'btn btn-sm btn-export' },
                    { extend: 'print', text: '<i class="bi bi-printer me-1"></i> <span class="d-none d-md-inline">IMPRIMIR</span>', className: 'btn btn-sm btn-export' }
                ],
                responsive: false, // Handle via SDM mobile styles data-label
                createdRow: function(row, data, dataIndex) {
                    // Inject data-label for SDM Mobile Standards point 7
                    $(row).find('td').each(function(i) {
                        let header = $(selector).find('thead th').eq(i).text();
                        $(this).attr('data-label', header);
                    });
                }
            });
        }
    };

    window.calcularFaltante = function() {
        let fisico = parseFloat(document.getElementById('cc_fisico').value) || 0;
        // Formula Faltante Físico: Efectivo Físico - (Ingresos Efectivo - Egresos Físicos)
        let saldoEsperado = ccTotalIngresos - ccTotalEgresosFisicos;
        let diferencia = fisico - saldoEsperado;

        let elDif = document.getElementById('cc_diferencia');
        let iconDif = document.getElementById('cc_dif_icon');
        let labelDif = document.getElementById('cc_dif_label');
        let boxDif = document.getElementById('kpi_diferencia_box');

        elDif.textContent = '\$' + Math.abs(diferencia).toFixed(2);
        if(diferencia > 0) {
            elDif.className = 'kpi-valor text-success';
            iconDif.style.color = '#10b981';
            iconDif.innerHTML = '<i class="bi bi-arrow-up-right-circle-fill"></i>';
            labelDif.textContent = 'Sobrante';
            labelDif.className = 'kpi-subtexto text-success fw-bold';
            boxDif.style.border = '2px solid #10b981';
            boxDif.style.backgroundColor = 'rgba(16, 185, 129, 0.05)';
        } else if(diferencia < 0) {
            elDif.className = 'kpi-valor text-danger';
            iconDif.style.color = '#ef4444';
            iconDif.innerHTML = '<i class="bi bi-arrow-down-right-circle-fill"></i>';
            labelDif.textContent = 'Faltante';
            labelDif.className = 'kpi-subtexto text-danger fw-bold';
            boxDif.style.border = '2px solid #ef4444';
            boxDif.style.backgroundColor = 'rgba(239, 68, 68, 0.05)';
            boxDif.style.backgroundColor = '#f8f9fa';
        }

        actualizarGraficaCorte(ccTotalIngresos, ccTotalCxC, ccTotalEgresos, fisico);
    };

    window.imprimirResumenEjecutivo = function() {
        if(!ultimoResCorte) {
            Swal.fire('Atención', 'Primero debes generar el corte de caja para poder imprimir el resumen.', 'warning');
            return;
        }

        let fInicio = document.getElementById('cc_fecha_inicio').value;
        let fFin = document.getElementById('cc_fecha_fin').value;
        let fechaTexto = fInicio === fFin ? fInicio : (fInicio + " al " + fFin);

        let fisico = parseFloat(document.getElementById('cc_fisico').value) || 0;
        let saldoEsperado = ccTotalIngresos - ccTotalEgresosFisicos;
        let dif = fisico - saldoEsperado;
        let difTexto = dif > 0 ? "Sobrante" : (dif < 0 ? "Faltante" : "Cuadrado Perfecto");
        let difColor = dif > 0 ? "green" : (dif < 0 ? "red" : "gray");

        let htmlIngresos = ultimoResCorte.ingresos.length ? ultimoResCorte.ingresos.map(i => '<tr><td>' + i.folio + '</td><td>' + i.fecha + '</td><td>' + i.paciente + '</td><td>' + i.medico + '</td><td>' + i.forma_pago + '</td><td class="text-right">$' + parseFloat(i.monto).toFixed(2) + '</td></tr>').join('') : '<tr><td colspan="6" style="text-align:center;">Sin ingresos en este periodo</td></tr>';
        
        let htmlEgresos = (ultimoResCorte.egresos && ultimoResCorte.egresos.length) ? ultimoResCorte.egresos.map(i => '<tr><td>' + i.folio + '</td><td>' + i.fecha + '</td><td>' + i.categoria + '</td><td>' + (i.origen_nombre || 'No Especificado') + '</td><td>' + i.concepto + '</td><td class="text-right">$' + parseFloat(i.monto).toFixed(2) + '</td></tr>').join('') : '<tr><td colspan="6" style="text-align:center;">Sin egresos en este periodo</td></tr>';

        let html = `
        <html>
        <head>
            <title>Resumen Ejecutivo - Corte de Caja</title>
            <style>
                body { font-family: 'Arial', sans-serif; padding: 20px; color: #333; }
                .header { text-align: center; border-bottom: 2px solid #00C4C4; padding-bottom: 10px; margin-bottom: 20px; }
                .header h2 { margin: 0; color: #004d40; }
                .header p { margin: 5px 0 0; color: #666; font-size: 14px; }
                
                .kpi-container { display: flex; justify-content: space-around; margin-bottom: 20px; }
                .kpi-box { border: 1px solid #ddd; border-radius: 8px; padding: 15px; width: 30%; text-align: center; background: #f9f9f9; }
                .kpi-box h4 { margin: 0 0 10px; font-size: 13px; color: #666; }
                .kpi-box .val { font-size: 20px; font-weight: bold; color: #333; margin: 0; }
                
                table { width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 11px; }
                th, td { border: 1px solid #eee; padding: 6px; text-align: left; }
                th { background-color: #f1f1f1; font-weight: bold; color: #555; }
                .text-right { text-align: right; }
                .section-title { font-size: 15px; margin: 20px 0 10px; color: #004d40; border-bottom: 1px solid #eee; padding-bottom: 5px; }
                
                .footer-box { margin-top: 30px; border: 2px dashed #ccc; padding: 15px; text-align: center; background: #fcfcfc; }
                .footer-box h3 { margin: 0 0 10px; color: #333; font-size: 16px; }
                .footer-box p { margin: 5px 0; font-size: 14px; }
                
                @media print {
                    .no-print { display: none !important; }
                    body { padding: 0; }
                }
            </style>
        </head>
        <body>
            <div class="no-print" style="margin-bottom: 20px; background: #0A2A66; color: #ffffff; padding: 12px 20px; border-radius: 12px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 12px rgba(0,0,0,0.15);">
                <div style="display: flex; align-items: center; gap: 10px;">
                    <span style="font-size: 18px;">📊</span>
                    <strong style="font-size: 15px;">Vista Previa de Resumen Ejecutivo de Caja</strong>
                </div>
                <div>
                    <button onclick="window.print()" style="background: #18D1E6; color: #0A2A66; border: none; padding: 8px 20px; border-radius: 20px; font-weight: bold; cursor: pointer; margin-right: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.2);">🖨️ Imprimir Reporte</button>
                    <button onclick="window.close()" style="background: #6c757d; color: #ffffff; border: none; padding: 8px 18px; border-radius: 20px; font-weight: bold; cursor: pointer;">Cerrar Vista</button>
                </div>
            </div>

            <div class="header">
                <h2>Resumen Ejecutivo de Caja</h2>
                <p>Periodo: ${fechaTexto}</p>
            </div>

            <div class="kpi-container">
                <div class="kpi-box">
                    <h4>Ingresos Total</h4>
                    <p class="val" style="color: green;">$${ccTotalIngresos.toFixed(2)}</p>
                </div>
                <div class="kpi-box">
                    <h4>Egresos Total</h4>
                    <p class="val" style="color: red;">$${ccTotalEgresos.toFixed(2)}</p>
                </div>
                <div class="kpi-box" style="background: #e0f7fa; border-color: #00C4C4;">
                    <h4>Saldo Esperado</h4>
                    <p class="val" style="color: #00838F;">$${saldoEsperado.toFixed(2)}</p>
                </div>
            </div>

            <div class="section-title">Detalle de Ingresos</div>
            <table>
                <thead>
                    <tr><th>Folio</th><th>Fecha</th><th>Paciente</th><th>Médico</th><th>Forma Pago</th><th class="text-right">Monto</th></tr>
                </thead>
                <tbody>
                    ${htmlIngresos}
                </tbody>
            </table>

            <div class="section-title">Detalle de Egresos</div>
            <table>
                <thead>
                    <tr><th>Folio</th><th>Fecha</th><th>Categoría</th><th>Origen</th><th>Concepto</th><th class="text-right">Monto</th></tr>
                </thead>
                <tbody>
                    ${htmlEgresos}
                </tbody>
            </table>

            <div class="footer-box">
                <h3>Declaración Física de Caja</h3>
                <p>Efectivo Físico Reportado: <strong>$${fisico.toFixed(2)}</strong></p>
                <p>Saldo Esperado (Ingresos Efectivo - Egresos Físicos): <strong>$${saldoEsperado.toFixed(2)}</strong></p>
                <p>Resultado del Cuadre: <strong style="color: ${difColor};">${difTexto} por $${Math.abs(dif).toFixed(2)}</strong></p>
            </div>
            
            <div style="margin-top: 50px; text-align: center;">
                <div style="display: inline-block; width: 250px; border-top: 1px solid #000; padding-top: 5px;">
                    Nombre y Firma del Responsable
                </div>
            </div>
        </body>
        </html>
        `;

        let printWin = window.open('', '_blank');
        printWin.document.write(html);
        printWin.document.close();
        printWin.focus();
    };

    window.actualizarGraficaCorte = function(ingresos, cxc, egresos, fisico) {
        let ctx = document.getElementById('chartCorteCaja');
        if(!ctx) return;
        
        if(chartCorte) {
            chartCorte.data.datasets[0].data = [ingresos, cxc, egresos, fisico];
            chartCorte.update();
        } else {
            chartCorte = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: ['Ingresos (Efvo)', 'Ingresos Municipio', 'Egresos', 'Físico'],
                    datasets: [{
                        label: 'Monto ($)',
                        data: [ingresos, cxc, egresos, fisico],
                        backgroundColor: ['rgba(16, 185, 129, 0.7)', 'rgba(13, 202, 240, 0.7)', 'rgba(239, 68, 68, 0.7)', 'rgba(234, 179, 8, 0.7)'],
                        borderColor: ['#10b981', '#0dcaf0', '#ef4444', '#eab308'],
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: { y: { beginAtZero: true } }
                }
            });
        }
    };
</script>

<!-- Modal Gestión de Categorías -->
<div class="modal fade modal-diamond" id="modalCategorias" tabindex="-1" aria-hidden="true" style="z-index: 105050 !important;">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 shadow-lg">
            <div class="modal-header">
                <h5 class="modal-title d-flex align-items-center m-0">
                    <i class="bi bi-gear-fill me-2" style="color: #00C4C4 !important;"></i>
                    <span>Gestión de Categorías</span>
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div class="row mb-3">
                    <div class="col-md-5">
                        <label class="form-label">Nivel</label>
                        <select id="mg_nivel" class="form-select" onchange="cambiarNivelGestion()">
                            <option value="1">1. Categoría Principal</option>
                            <option value="2">2. Subcategoría</option>
                            <option value="3">3. Detalle (Nivel 3)</option>
                        </select>
                    </div>
                    <div class="col-md-7" id="mg_parent_col" style="display:none;">
                        <label class="form-label" id="mg_parent_label">Padre</label>
                        <select id="mg_parent" class="form-select" onchange="renderListaCategorias()">
                            <option value="">Seleccione...</option>
                        </select>
                    </div>
                </div>
                
                <div class="input-group mb-4 shadow-sm" style="border-radius: 10px; overflow: hidden; border: 1px solid var(--md-gray-soft);">
                    <input type="text" id="mg_nombre" class="form-control border-0" placeholder="Nombre de la nueva categoría...">
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

<!-- Modal Origenes de Dinero -->
<div class="modal fade modal-diamond" id="modalOrigenesDinero" tabindex="-1" aria-hidden="true" style="z-index: 105050 !important;">
    <div class="modal-dialog modal-dialog-centered modal-md">
        <div class="modal-content border-0 shadow-lg">
            <div class="modal-header">
                <h5 class="modal-title d-flex align-items-center m-0">
                    <i class="bi bi-cash-coin me-2" style="color: #00C4C4 !important;"></i>
                    <span>Gestión de Origen del Dinero</span>
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div class="mb-3">
                    <label class="form-label">Nombre del Origen</label>
                    <div class="input-group shadow-sm" style="border-radius: 10px; overflow: hidden; border: 1px solid var(--md-gray-soft);">
                        <input type="text" id="od_nombre" class="form-control border-0" placeholder="Ej. Tarjeta Corporativa, Caja Fuerte...">
                        <button class="btn fw-bold px-3 text-white" type="button" style="background: var(--md-blue-medical);" onclick="agregarOrigenDinero()">
                            <i class="bi bi-plus-lg"></i>
                        </button>
                    </div>
                </div>
                
                <div class="table-responsive" style="max-height: 250px; overflow-y: auto;">
                    <table class="table table-hover align-middle mb-0">
                        <thead class="text-muted small sticky-top bg-white">
                            <tr>
                                <th>Origen</th>
                                <th class="text-end">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="tbodyOrigenesDinero">
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
<script src="https://cdn.datatables.net/rowgroup/1.4.1/js/dataTables.rowGroup.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/vfs_fonts.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.print.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script src="../js/estado_cuenta_spa.js?v=5"></script>

<script>
    window.bootFinanzas = function() {
        console.log("[SPA Debug] Ejecutando bootFinanzas...");
        if(typeof window.initModuloFinanciero === 'function') {
            console.log("[SPA Debug] Llamando a initModuloFinanciero");
            window.initModuloFinanciero('', 'bento', ''); 
        } else {
            console.warn("[SPA Debug] initModuloFinanciero no está definido en el contexto window");
        }

        const urlParams = new URLSearchParams(window.location.search);
        const activeTab = urlParams.get('tab') || '';
        if (activeTab === 'ingresos' && typeof window.renderIngresos === 'function') {
            window.renderIngresos();
        }
    };
    document.addEventListener("DOMContentLoaded", window.bootFinanzas);
    document.addEventListener("spa:contentLoaded", window.bootFinanzas);
</script>
PAGE_HTML
utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('finanzas');
print "</body></html>\n";
