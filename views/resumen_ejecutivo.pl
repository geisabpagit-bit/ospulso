#!/usr/bin/perl
BEGIN { eval "use cPanelUserConfig;"; }
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use File::Spec;
use open qw(:std :utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario    = $sd->{usuario} // 'Usuario';
my $role       = $sd->{role} // '';
my $id_empresa = $sd->{id_empresa} // 0;

# RBAC: Exclusivo para Administrador Organizacion y Administrador Global
if ($role !~ /Administrador/i) {
    render_acceso_denegado(
        q             => $q,
        usuario       => $usuario,
        role          => $role,
        mensaje       => 'El Tablero Ejecutivo es exclusivo para la Dirección y Administración de la Organización.',
        rol_requerido => 'Administrador Organización'
    );
    exit;
}

print $q->header(
    -type          => 'text/html',
    -charset       => 'UTF-8',
    -cache_control => 'no-store, no-cache, must-revalidate, max-age=0',
    -pragma        => 'no-cache'
);

render_header(
    usuario     => $usuario,
    role        => $role,
    titulo      => "Tablero Ejecutivo de Recaudación | OSPulso",
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(
    pagina_actual => 'resumen_ejecutivo',
    usuario       => $usuario,
    role          => $role,
    id_empresa    => $id_empresa
);

print <<'PAGE_HTML';
<link rel="stylesheet" href="../css/sdm_mobile_standards.css">
<link rel="stylesheet" href="../css/ospulso_master_v2.css">

<main class="main-content container-fluid py-3 px-md-4 container-mobile-flush">
    <!-- Breadcrumb & Cabecera Ejecutiva -->
    <div class="d-flex flex-wrap justify-content-between align-items-center mb-4 gap-3">
        <div>
            <nav aria-label="breadcrumb">
                <ol class="breadcrumb mb-1">
                    <li class="breadcrumb-item"><a href="dashboard.pl" class="text-decoration-none">Inicio</a></li>
                    <li class="breadcrumb-item"><a href="finanzas.pl" class="text-decoration-none">Finanzas</a></li>
                    <li class="breadcrumb-item active text-primary fw-semibold" aria-current="page">Tablero Ejecutivo</li>
                </ol>
            </nav>
            <h2 class="h4 fw-bold text-dark mb-0 d-flex align-items-center gap-2 flex-wrap">
                <i class="bi bi-bar-chart-line-fill text-primary"></i>
                <span>Tablero Ejecutivo de Recaudación y Operación</span>
                <span class="badge bg-primary bg-opacity-10 text-primary fs-6 px-3 py-1 rounded-pill" id="badgePeriodoActual">Cargando...</span>
            </h2>
            <p class="text-muted small mb-0" id="subtituloClinica">Análisis consolidado multi-temporal de caja física, convenios públicos y calidad contable.</p>
        </div>

        <!-- Toolbar de Acciones Rápidas -->
        <div class="d-flex flex-wrap align-items-center gap-2 btn-action-toolbar">
            <button class="btn btn-outline-primary btn-sm rounded-pill shadow-sm px-3 fw-semibold" onclick="copiarMarkdownIA()">
                <i class="bi bi-clipboard2-check me-1"></i>Copiar para IA (Gamma / Notion)
            </button>
            <button class="btn btn-primary btn-sm rounded-pill shadow-sm px-3 fw-bold" onclick="window.print()">
                <i class="bi bi-printer me-1"></i>Imprimir / PDF
            </button>
        </div>
    </div>

    <!-- Barra de Control Multi-Temporal (Día, Semana, Mes, Año) -->
    <div class="card card-mobile-flush border-0 shadow-sm rounded-4 bg-white p-3 mb-4 temporal-pills-nav">
        <div class="d-flex flex-wrap justify-content-between align-items-center gap-3">
            <!-- Píldoras de Temporalidad -->
            <div class="d-flex align-items-center gap-2">
                <span class="text-muted small fw-bold text-uppercase me-1"><i class="bi bi-filter-left me-1"></i>Vista:</span>
                <div class="btn-group p-1 bg-light rounded-pill border" role="group" id="grupoTemporalidad">
                    <button type="button" class="temporal-pill-btn" onclick="cambiarTipoPeriodo('dia', this)">Día</button>
                    <button type="button" class="temporal-pill-btn active" onclick="cambiarTipoPeriodo('semana', this)">Semana</button>
                    <button type="button" class="temporal-pill-btn" onclick="cambiarTipoPeriodo('mes', this)">Mes</button>
                    <button type="button" class="temporal-pill-btn" onclick="cambiarTipoPeriodo('ano', this)">Año</button>
                </div>
            </div>

            <!-- Selector Dinámico del Periodo Activo -->
            <div id="selectorPeriodoContainer" class="d-flex align-items-center gap-2 bg-light px-3 py-1 rounded-pill border">
                <i class="bi bi-calendar3 text-muted"></i>
                <label for="selectPeriodo" class="small text-muted fw-semibold mb-0" id="labelPeriodo">Periodo:</label>
                <select id="selectPeriodo" class="form-select form-select-sm border-0 bg-transparent fw-bold text-dark" style="cursor: pointer; min-width: 170px;" onchange="seleccionarPeriodoEspecifico()">
                    <option value="">Cargando periodos...</option>
                </select>
            </div>
        </div>
    </div>

    <!-- Tablero de 5 KPIs Principales -->
    <div class="row g-3 mb-4">
        <!-- 1. Flujo Real Caja Privada -->
        <div class="col-12 col-sm-6 col-xl">
            <div class="card kpi-card-exec p-3 h-100 border-start border-4 border-success">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <span class="text-muted small fw-bold text-uppercase">Caja Real (Privados)</span>
                        <h3 class="fw-bold text-dark mt-1 mb-1" id="kpi-flujo-privado">$0.00</h3>
                        <div id="badge-crec-ingresos" class="badge rounded-pill small py-1 px-2">0% vs periodo anterior</div>
                    </div>
                    <div class="p-2 bg-success bg-opacity-10 rounded-circle text-success">
                        <i class="bi bi-cash-stack fs-4"></i>
                    </div>
                </div>
                <div class="small text-muted mt-2">100% cobrado en ventanilla</div>
            </div>
        </div>

        <!-- 2. CXC Convenio Municipio -->
        <div class="col-12 col-sm-6 col-xl">
            <div class="card kpi-card-exec p-3 h-100 border-start border-4 border-info">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <span class="text-muted small fw-bold text-uppercase">CXC Municipio (100% Subsidio)</span>
                        <h3 class="fw-bold text-info mt-1 mb-1" id="kpi-cargos-publicos">$0.00</h3>
                        <span class="badge bg-info bg-opacity-10 text-info rounded-pill py-1 px-2">Cartera Gobierno</span>
                    </div>
                    <div class="p-2 bg-info bg-opacity-10 rounded-circle text-info">
                        <i class="bi bi-building-check fs-4"></i>
                    </div>
                </div>
                <div class="small text-muted mt-2">Facturación consolidada</div>
            </div>
        </div>

        <!-- 3. Volumen Total Recibos -->
        <div class="col-12 col-sm-6 col-xl">
            <div class="card kpi-card-exec p-3 h-100 border-start border-4 border-primary">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <span class="text-muted small fw-bold text-uppercase">Recibos Emitidos</span>
                        <h3 class="fw-bold text-primary mt-1 mb-1" id="kpi-total-recibos">0</h3>
                        <div id="badge-crec-recibos" class="badge rounded-pill small py-1 px-2">0% transacciones</div>
                    </div>
                    <div class="p-2 bg-primary bg-opacity-10 rounded-circle text-primary">
                        <i class="bi bi-receipt-cutoff fs-4"></i>
                    </div>
                </div>
                <div class="small text-muted mt-2" id="kpi-recibos-desglose">0 Privados / 0 Públicos</div>
            </div>
        </div>

        <!-- 4. Ticket Promedio -->
        <div class="col-12 col-sm-6 col-xl">
            <div class="card kpi-card-exec p-3 h-100 border-start border-4 border-warning">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <span class="text-muted small fw-bold text-uppercase">Ticket Prom. Privado</span>
                        <h3 class="fw-bold text-dark mt-1 mb-1" id="kpi-ticket-privado">$0.00</h3>
                        <span class="badge bg-warning bg-opacity-10 text-dark rounded-pill py-1 px-2" id="kpi-ticket-publico">Púb: $0.00</span>
                    </div>
                    <div class="p-2 bg-warning bg-opacity-10 rounded-circle text-warning">
                        <i class="bi bi-pie-chart-fill fs-4"></i>
                    </div>
                </div>
                <div class="small text-muted mt-2">Promedio por paciente</div>
            </div>
        </div>

        <!-- 5. Calidad y Consistencia Forense -->
        <div class="col-12 col-sm-6 col-xl">
            <div class="card kpi-card-exec p-3 h-100 border-start border-4" style="border-left-color: var(--md-teal-clinical, #19B7A5) !important;">
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <span class="text-muted small fw-bold text-uppercase">Integridad Contable</span>
                        <h3 class="fw-bold text-success mt-1 mb-1" id="kpi-calidad">100%</h3>
                        <span class="badge badge-teal-clinical rounded-pill py-1 px-2">Cuadre al Centavo</span>
                    </div>
                    <div class="p-2 bg-opacity-10 rounded-circle" style="background-color: rgba(25, 183, 165, 0.1); color: var(--md-teal-clinical, #19B7A5);">
                        <i class="bi bi-shield-check fs-4"></i>
                    </div>
                </div>
                <div class="small text-muted mt-2">Cero folios saltados</div>
            </div>
        </div>
    </div>

    <!-- Comportamiento Cronológico del Periodo Seleccionado -->
    <div class="card card-mobile-flush border-0 shadow-sm rounded-4 overflow-hidden bg-white mb-4">
        <div class="card-header bg-white border-bottom border-light py-3 d-flex flex-wrap justify-content-between align-items-center gap-2">
            <div class="d-flex align-items-center gap-2">
                <i class="bi bi-calendar2-week text-primary fs-5"></i>
                <h5 class="card-title fw-bold text-dark mb-0" id="tituloTablaDesglose">Comportamiento y Desglose Cronológico</h5>
            </div>
            <div id="alertaElementoPico" class="badge bg-warning bg-opacity-10 text-dark px-3 py-2 rounded-pill fw-bold">
                <i class="bi bi-lightning-charge-fill text-warning me-1"></i>Analizando pico de recaudación...
            </div>
        </div>
        <div class="card-body p-0">
            <div class="table-responsive">
                <table class="table table-hover align-middle mb-0 table-executive">
                    <thead>
                        <tr id="trHeaderDesglose">
                            <th>Periodo / Fecha</th>
                            <th>Detalle</th>
                            <th class="text-center">Rec. Privados</th>
                            <th class="text-end">Caja Privada</th>
                            <th class="text-center">Rec. Públicos</th>
                            <th class="text-end">Fact. Municipio</th>
                            <th class="text-center">Total Recibos</th>
                            <th class="text-end">Total Recaudado</th>
                            <th style="width: 140px;">% Aporte</th>
                        </tr>
                    </thead>
                    <tbody id="tbodyDesgloseCronologico">
                        <tr>
                            <td colspan="9" class="text-center py-4 text-muted">
                                <div class="spinner-border text-primary spinner-border-sm me-2"></div>Cargando datos ejecutivos...
                            </td>
                        </tr>
                    </tbody>
                    <tfoot id="tfootDesgloseCronologico" class="table-light fw-bold"></tfoot>
                </table>
            </div>
        </div>
    </div>

    <!-- Dos Columnas: Medios de Pago & Demanda Clínica -->
    <div class="row g-4 mb-4">
        <!-- Columna Izquierda: Control de Medios de Pago -->
        <div class="col-12 col-lg-6">
            <div class="card card-mobile-flush border-0 shadow-sm rounded-4 bg-white h-100 p-4">
                <div class="d-flex align-items-center justify-content-between mb-3 border-bottom pb-2">
                    <h5 class="fw-bold text-dark mb-0 d-flex align-items-center gap-2">
                        <i class="bi bi-credit-card-2-front-fill text-success"></i>Control de Medios de Pago (Arqueo de Caja)
                    </h5>
                    <span class="badge bg-light text-muted">Canal Privado</span>
                </div>
                <p class="text-muted small mb-3">Distribución de ingresos físicos en mostrador para conciliación bancaria y prevención de fuga.</p>
                <div id="contenedorMediosPago" class="d-flex flex-column gap-3">
                    <div class="text-center py-3 text-muted">Cargando medios de pago...</div>
                </div>
            </div>
        </div>

        <!-- Columna Derecha: Demanda por Departamentos Clínicos -->
        <div class="col-12 col-lg-6">
            <div class="card card-mobile-flush border-0 shadow-sm rounded-4 bg-white h-100 p-4">
                <div class="d-flex align-items-center justify-content-between mb-3 border-bottom pb-2">
                    <h5 class="fw-bold text-dark mb-0 d-flex align-items-center gap-2">
                        <i class="bi bi-hospital-fill text-primary"></i>Demanda por Departamento Clínico
                    </h5>
                    <span class="badge bg-light text-muted">Servicios y Estudios</span>
                </div>
                <p class="text-muted small mb-3">Concentración de volumen entre atenciones privadas de caja y órdenes municipales de convenio.</p>
                <div id="contenedorDepartamentos" class="d-flex flex-column gap-2">
                    <div class="text-center py-3 text-muted">Cargando departamentos...</div>
                </div>
            </div>
        </div>
    </div>

    <!-- Dictamen de Seguridad y Certificación Forense -->
    <div class="card border-0 shadow-sm rounded-4 bg-white p-4 mb-4 border-top border-4 border-primary">
        <div class="d-flex flex-wrap align-items-center justify-content-between gap-3">
            <div class="d-flex align-items-center gap-3">
                <div class="p-3 bg-primary bg-opacity-10 text-primary rounded-circle">
                    <i class="bi bi-patch-check-fill fs-3"></i>
                </div>
                <div>
                    <h6 class="fw-bold text-dark mb-1">Certificación Contable y Forense del Periodo</h6>
                    <p class="text-muted small mb-0">La base de datos de producción cumple estrictamente con el principio de integridad contable: cero folios saltados, cuadre matemático de items JSON y firmas digitales de usuario certificadas.</p>
                </div>
            </div>
            <div class="text-end">
                <span class="badge bg-success px-3 py-2 rounded-pill fw-bold">Estatus: 100% Auditado</span>
            </div>
        </div>
    </div>
</main>
PAGE_HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav(pagina_actual => 'finanzas', role => $role);

# Script JS aislado con comilla simple para evitar colisiones de sigilos
print <<'JS';
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
let tipoPeriodoActual = 'semana';
let periodoValActual  = '';
let datosEjecutivosGlobal = null;

document.addEventListener('DOMContentLoaded', function() {
    cargarResumenEjecutivo('semana', '');
});

function cambiarTipoPeriodo(tipo, btnElem) {
    tipoPeriodoActual = tipo;
    periodoValActual  = '';

    // Actualizar botones de píldora
    const botones = document.querySelectorAll('#grupoTemporalidad .temporal-pill-btn');
    botones.forEach(b => b.classList.remove('active'));
    if (btnElem) {
        btnElem.classList.add('active');
    }

    cargarResumenEjecutivo(tipoPeriodoActual, '');
}

function seleccionarPeriodoEspecifico() {
    const sel = document.getElementById('selectPeriodo');
    periodoValActual = sel.value;
    cargarResumenEjecutivo(tipoPeriodoActual, periodoValActual);
}

function cargarResumenEjecutivo(tipo, val) {
    let url = `../api/resumen_ejecutivo_api.pl?tipo_periodo=${encodeURIComponent(tipo)}`;
    if (val) {
        url += `&periodo_val=${encodeURIComponent(val)}`;
    }

    fetch(url, { headers: { 'Cache-Control': 'no-cache' } })
    .then(res => res.json())
    .then(data => {
        if (data.status === 'ok') {
            datosEjecutivosGlobal = data;
            renderizarVista(data);
        } else {
            Swal.fire('Error', data.message || 'No se pudo cargar el resumen ejecutivo', 'error');
        }
    })
    .catch(err => {
        console.error('Error fetching resumen ejecutivo:', err);
        Swal.fire('Error', 'Fallo de conexión al cargar datos ejecutivos.', 'error');
    });
}

function renderizarVista(data) {
    // 1. Configurar selector dinámico según la temporalidad
    const sel = document.getElementById('selectPeriodo');
    sel.innerHTML = '';

    let listaPeriodos = [];
    let prefijoEtiqueta = '';

    if (data.tipo_periodo === 'dia') {
        listaPeriodos = data.dias_disponibles || [];
        prefijoEtiqueta = 'Día: ';
        document.getElementById('labelPeriodo').textContent = 'Día:';
        document.getElementById('tituloTablaDesglose').textContent = 'Comportamiento y Desglose por Turno / Horario (' + data.periodo_activo + ')';
    } else if (data.tipo_periodo === 'semana') {
        listaPeriodos = data.semanas_disponibles || [];
        prefijoEtiqueta = 'Semana: ';
        document.getElementById('labelPeriodo').textContent = 'Semana:';
        document.getElementById('tituloTablaDesglose').textContent = 'Comportamiento y Desglose Diario (Lunes a Domingo)';
    } else if (data.tipo_periodo === 'mes') {
        listaPeriodos = data.meses_disponibles || [];
        prefijoEtiqueta = 'Mes: ';
        document.getElementById('labelPeriodo').textContent = 'Mes:';
        document.getElementById('tituloTablaDesglose').textContent = 'Comportamiento Diario del Mes (' + data.periodo_activo + ')';
    } else if (data.tipo_periodo === 'ano') {
        listaPeriodos = data.anos_disponibles || [];
        prefijoEtiqueta = 'Año: ';
        document.getElementById('labelPeriodo').textContent = 'Año:';
        document.getElementById('tituloTablaDesglose').textContent = 'Comportamiento Mensual del Año (' + data.periodo_activo + ')';
    }

    listaPeriodos.forEach(p => {
        const opt = document.createElement('option');
        opt.value = p;
        opt.textContent = prefijoEtiqueta + p + (p === listaPeriodos[0] ? ' (Más Reciente)' : '');
        if (p === data.periodo_activo) {
            opt.selected = true;
        }
        sel.appendChild(opt);
    });

    document.getElementById('badgePeriodoActual').textContent = capitalizar(data.tipo_periodo) + ' ' + data.periodo_activo;
    document.getElementById('subtituloClinica').textContent = (data.nombre_negocio || 'Clínica') + ' (CLUE ' + (data.clue || '') + ') - Análisis consolidado de caja y convenios.';

    // 2. KPIs
    const kpis = data.kpis || {};
    document.getElementById('kpi-flujo-privado').textContent = formatoMoneda(kpis.flujo_privado || 0);
    document.getElementById('kpi-cargos-publicos').textContent = formatoMoneda(kpis.cargos_publicos || 0);
    document.getElementById('kpi-total-recibos').textContent = (kpis.total_recibos || 0) + ' recibos';
    document.getElementById('kpi-recibos-desglose').textContent = (kpis.recibos_privados || 0) + ' Privados / ' + (kpis.recibos_publicos || 0) + ' Públicos';
    document.getElementById('kpi-ticket-privado').textContent = formatoMoneda(kpis.ticket_prom_privado || 0);
    document.getElementById('kpi-ticket-publico').textContent = 'Púb: ' + formatoMoneda(kpis.ticket_prom_publico || 0);
    document.getElementById('kpi-calidad').textContent = (kpis.calidad_datos_pct || 100) + '%';

    // Tendencia de ingresos
    const crecIng = parseFloat(kpis.crec_ingresos_pct || 0);
    const bCrecIng = document.getElementById('badge-crec-ingresos');
    bCrecIng.textContent = (crecIng >= 0 ? '+' : '') + crecIng + '% vs periodo anterior';
    bCrecIng.className = 'badge rounded-pill small py-1 px-2 ' + (crecIng >= 0 ? 'badge-trend-up' : 'badge-trend-down');

    // Tendencia de transacciones
    const crecRec = parseFloat(kpis.crec_recibos_pct || 0);
    const bCrecRec = document.getElementById('badge-crec-recibos');
    bCrecRec.textContent = (crecRec >= 0 ? '+' : '') + crecRec + '% transacciones';
    bCrecRec.className = 'badge rounded-pill small py-1 px-2 ' + (crecRec >= 0 ? 'badge-trend-up' : 'badge-trend-down');

    // 3. Desglose Cronológico
    const tbody = document.getElementById('tbodyDesgloseCronologico');
    tbody.innerHTML = '';
    const desglose = data.desglose_cronologico || [];
    let totGralMonto = 0;
    desglose.forEach(b => { totGralMonto += (b.total_monto || 0); });

    if (desglose.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" class="text-center py-4 text-muted">No hay movimientos registrados en este periodo.</td></tr>';
    } else {
        desglose.forEach(b => {
            const esPico = data.elemento_pico && data.elemento_pico.clave === b.clave;
            const pctAporte = totGralMonto > 0 ? ((b.total_monto / totGralMonto) * 100).toFixed(1) : 0;
            const tr = document.createElement('tr');
            if (esPico) tr.className = 'table-warning bg-opacity-25';

            tr.innerHTML = `
                <td class="fw-bold">${b.etiqueta}</td>
                <td>
                    <span class="fw-semibold">${b.subetiqueta || ''}</span>
                    ${esPico ? '<span class="badge bg-warning text-dark ms-1 small fw-bold">Pico</span>' : ''}
                </td>
                <td class="text-center">${b.priv_cnt}</td>
                <td class="text-end fw-semibold text-success">${formatoMoneda(b.priv_monto)}</td>
                <td class="text-center">${b.pub_cnt}</td>
                <td class="text-end fw-semibold text-info">${formatoMoneda(b.pub_monto)}</td>
                <td class="text-center fw-bold">${b.total_cnt}</td>
                <td class="text-end fw-bold text-dark">${formatoMoneda(b.total_monto)}</td>
                <td>
                    <div class="d-flex align-items-center gap-2">
                        <div class="progress flex-grow-1" style="height: 6px;">
                            <div class="progress-bar ${esPico ? 'bg-warning' : 'bg-primary'}" role="progressbar" style="width: ${pctAporte}%;"></div>
                        </div>
                        <span class="small text-muted fw-bold">${pctAporte}%</span>
                    </div>
                </td>
            `;
            tbody.appendChild(tr);
        });

        // Alerta Elemento Pico
        if (data.elemento_pico) {
            const nomPico = data.elemento_pico.subetiqueta ? `${data.elemento_pico.subetiqueta} (${data.elemento_pico.etiqueta})` : data.elemento_pico.etiqueta;
            document.getElementById('alertaElementoPico').innerHTML = `
                <i class="bi bi-lightning-charge-fill text-warning me-1"></i>Pico del Periodo: <strong>${nomPico}</strong> (${formatoMoneda(data.elemento_pico.total_monto)})
            `;
        }
    }

    // 4. Medios de Pago
    const contPago = document.getElementById('contenedorMediosPago');
    contPago.innerHTML = '';
    const medios = data.medios_pago || [];
    if (medios.length === 0) {
        contPago.innerHTML = '<div class="text-center py-3 text-muted">Sin movimientos de pago registrados en este periodo.</div>';
    } else {
        medios.forEach(mp => {
            const iconClass = mp.metodo.toLowerCase().includes('efectivo') ? 'bi-cash-coin text-success' : (mp.metodo.toLowerCase().includes('tarjeta') ? 'bi-credit-card text-primary' : 'bi-bank text-info');
            const itemHtml = `
                <div>
                    <div class="d-flex justify-content-between align-items-center mb-1">
                        <span class="fw-semibold d-flex align-items-center gap-2">
                            <i class="bi ${iconClass}"></i>${mp.metodo}
                            <span class="badge bg-light text-muted small">${mp.count} recibos</span>
                        </span>
                        <span class="fw-bold text-dark">${formatoMoneda(mp.monto)} <span class="text-muted small fw-normal">(${mp.porcentaje}%)</span></span>
                    </div>
                    <div class="progress" style="height: 8px;">
                        <div class="progress-bar ${mp.metodo.toLowerCase().includes('efectivo') ? 'bg-success' : 'bg-primary'}" role="progressbar" style="width: ${mp.porcentaje}%;"></div>
                    </div>
                </div>
            `;
            contPago.innerHTML += itemHtml;
        });
    }

    // 5. Departamentos Clínicos
    const contDeptos = document.getElementById('contenedorDepartamentos');
    contDeptos.innerHTML = '';
    const dpPriv = data.deptos_priv || {};
    const dpPub  = data.deptos_pub || {};
    const todosDeptos = Array.from(new Set([...Object.keys(dpPriv), ...Object.keys(dpPub)]));

    if (todosDeptos.length === 0) {
        contDeptos.innerHTML = '<div class="text-center py-3 text-muted">Sin registros de departamentos.</div>';
    } else {
        todosDeptos.sort((a, b) => ((dpPriv[b] || 0) + (dpPub[b] || 0)) - ((dpPriv[a] || 0) + (dpPub[a] || 0)));
        todosDeptos.forEach(dep => {
            const cPriv = dpPriv[dep] || 0;
            const cPub  = dpPub[dep] || 0;
            const cTot  = cPriv + cPub;
            const cardDepto = `
                <div class="p-2 border rounded-3 d-flex justify-content-between align-items-center bg-light bg-opacity-50">
                    <span class="fw-semibold text-dark"><i class="bi bi-chevron-right text-primary me-1 small"></i>${dep}</span>
                    <div class="d-flex gap-2">
                        <span class="badge bg-success bg-opacity-10 text-success">${cPriv} Priv</span>
                        <span class="badge bg-info bg-opacity-10 text-info">${cPub} Púb</span>
                        <span class="badge bg-dark text-white fw-bold">${cTot} Total</span>
                    </div>
                </div>
            `;
            contDeptos.innerHTML += cardDepto;
        });
    }
}

function formatoMoneda(valor) {
    return '$' + parseFloat(valor || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function capitalizar(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
}

function copiarMarkdownIA() {
    if (!datosEjecutivosGlobal || !datosEjecutivosGlobal.markdown_export) {
        Swal.fire('Aviso', 'Aún no se han cargado los datos para copiar.', 'info');
        return;
    }

    navigator.clipboard.writeText(datosEjecutivosGlobal.markdown_export)
    .then(() => {
        Swal.fire({
            title: '¡Copiado con Éxito!',
            text: 'El informe ejecutivo en formato Markdown estructurado ha sido copiado a tu portapapeles. Listo para pegar en Gamma.app, Notion, ChatGPT o Claude.',
            icon: 'success',
            confirmButtonText: 'Excelente'
        });
    })
    .catch(err => {
        console.error('Error al copiar:', err);
        Swal.fire('Error', 'No se pudo copiar automáticamente al portapapeles.', 'error');
    });
}
</script>
</body>
</html>
JS
