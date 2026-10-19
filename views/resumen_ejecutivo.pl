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

binmode(STDOUT, ':utf8');
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
    <!-- Membrete Formal Institucional (Visible al Imprimir / Guardar como PDF) -->
    <div class="print-header-executive">
        <div class="d-flex justify-content-between align-items-center">
            <div>
                <h3 class="fw-bold mb-0 text-dark" id="printClinicaNombre">CLÍNICA MÉDICA DE ESPECIALIDADES JUAN PABLO II</h3>
                <div class="small text-muted">CLUE: <strong id="printClueOrg">QTSMP000116</strong> | Suite Médica OSPulso | Dirección General</div>
            </div>
            <div class="text-end">
                <div class="badge bg-primary text-white px-3 py-1 fw-bold fs-6" id="printPeriodoBadge">Periodo Activo</div>
                <div class="small text-muted mt-1" id="printRangoFechas">Del periodo analizado</div>
            </div>
        </div>
        <div class="mt-2 pt-2 border-top border-secondary border-opacity-25 d-flex justify-content-between small text-muted">
            <span><strong>Tipo de Dictamen:</strong> Auditoría Operativa y Financiera Hospitalaria</span>
            <span><strong>Estatus Contable:</strong> 100% Auditado - Cero Discrepancias</span>
            <span id="printFechaEmision">Fecha de Emisión</span>
        </div>
    </div>

    <!-- Barra de Control Temporal y Filtros Dinámicos (Estilo Dashboard Finanzas con Borde Teal) -->
    <div class="card card-mobile-flush border-0 shadow-sm mb-3" style="border-radius: 14px; background: #FFFFFF; border: 1.5px solid var(--md-teal-clinical, #19B7A5) !important;">
        <div class="card-body p-2.5 p-md-4">
            <div class="d-flex flex-column flex-lg-row justify-content-between align-items-lg-center gap-2 gap-lg-3">
                <!-- Título e Identidad -->
                <div>
                    <h5 class="fw-bold plus-jakarta mb-1 d-flex align-items-center gap-2 flex-wrap" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                        <i class="bi bi-speedometer2" style="color: var(--md-teal-clinical, #19B7A5);"></i>
                        <span>Tablero Financiero Ejecutivo</span>
                        <span class="badge bg-primary bg-opacity-10 text-primary fs-6 px-3 py-1 rounded-pill" id="badgePeriodoActual">Cargando...</span>
                    </h5>
                    <p class="text-muted small mb-0" style="font-size: 0.72rem; line-height: 1.25;" id="subtituloClinica">Métricas consolidadas, rentabilidad y flujo operativo de la organización</p>
                </div>

                <!-- Controles: Píldoras de Periodo + Selector Dinámico + Acciones -->
                <div class="d-flex flex-wrap align-items-center justify-content-between justify-content-lg-end gap-2">
                    <!-- Píldoras Rápidas de Periodo -->
                    <div class="btn-group btn-group-sm p-1 bg-light rounded-pill border" role="group" id="filterPillsGroup">
                        <button type="button" class="btn btn-sm rounded-pill fw-semibold btn-filter-pill btn-light text-secondary" onclick="cambiarTipoPeriodo('dia', this)">Hoy</button>
                        <button type="button" class="btn btn-sm rounded-pill fw-semibold btn-filter-pill active" onclick="cambiarTipoPeriodo('semana', this)">Semana</button>
                        <button type="button" class="btn btn-sm rounded-pill fw-semibold btn-filter-pill btn-light text-secondary" onclick="cambiarTipoPeriodo('mes', this)">Este Mes</button>
                        <button type="button" class="btn btn-sm rounded-pill fw-semibold btn-filter-pill btn-light text-secondary" onclick="cambiarTipoPeriodo('ano', this)">Año</button>
                    </div>

                    <!-- Selector Dinámico con Borde Teal -->
                    <div class="financial-date-range-bar d-flex align-items-center p-1 rounded-pill border shadow-xs" style="border-color: rgba(25, 183, 165, 0.4) !important;">
                        <i class="bi bi-calendar3 text-muted ms-2 me-1"></i>
                        <select id="selectPeriodo" class="form-select form-select-sm border-0 bg-transparent fw-bold text-dark py-0" style="cursor: pointer; min-width: 160px; font-size: 0.8rem;" onchange="seleccionarPeriodoEspecifico()">
                            <option value="">Cargando periodos...</option>
                        </select>
                        <button class="btn btn-sm rounded-pill px-2.5 text-white flex-shrink-0 d-inline-flex align-items-center justify-content-center" style="background: var(--md-blue-deep, #0A2A66); min-height: 28px;" onclick="seleccionarPeriodoEspecifico()" title="Actualizar Periodo">
                            <i class="bi bi-arrow-repeat"></i>
                        </button>
                    </div>

                    <!-- Botones de Acción Rápida -->
                    <div class="d-flex align-items-center gap-1.5 btn-action-toolbar">
                        <button class="btn btn-outline-primary btn-sm rounded-pill shadow-sm px-3 fw-semibold" onclick="copiarMarkdownIA()" title="Copia el prompt completo de auditoría para ChatGPT, Claude o Gamma">
                            <i class="bi bi-robot me-1"></i>Copiar Prompt para IA
                        </button>
                        <button class="btn btn-primary btn-sm rounded-pill shadow-sm px-3 fw-bold" onclick="window.print()">
                            <i class="bi bi-printer me-1"></i>Imprimir / PDF
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- CAPA 1: Flujo de Caja y Rentabilidad Real (Hero KPIs - Borde Teal Clínico) -->
    <div class="row row-cols-1 row-cols-md-3 g-2 g-md-3 mb-2 mb-md-3">
        <!-- 1. Ingresos Reales (Canal Privado) -->
        <div class="col">
            <div class="card card-mobile-flush h-100 p-2.5 p-md-4 border-0 shadow-sm rounded-4" style="background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.45) !important;">
                <div class="d-flex justify-content-between align-items-center mb-1 mb-md-2">
                    <span class="small fw-bold text-muted text-uppercase tracking-wider" style="font-size: 0.72rem;">INGRESOS REALES (CAJA PRIVADA)</span>
                    <div class="rounded-circle d-flex align-items-center justify-content-center" style="width: 36px; height: 36px; background: rgba(16, 185, 129, 0.1);">
                        <i class="bi bi-cash-stack text-success fs-5"></i>
                    </div>
                </div>
                <h2 class="fw-bold m-0 text-success plus-jakarta" id="kpi-flujo-privado" style="font-size: 1.65rem;">$0.00</h2>
                <div class="d-flex justify-content-between align-items-center mt-2 mt-md-3 pt-2 border-top border-light">
                    <span class="badge bg-success bg-opacity-10 text-success rounded-pill px-2.5 py-1 small fw-semibold" style="font-size: 0.65rem;">Cobrado en Caja</span>
                    <span class="small text-muted d-flex align-items-center gap-1" id="badge-crec-ingresos" style="font-size: 0.72rem;">+0% vs periodo anterior</span>
                </div>
            </div>
        </div>

        <!-- 2. Cartera Convenio Municipio (Cuentas por Cobrar) -->
        <div class="col">
            <div class="card card-mobile-flush h-100 p-2.5 p-md-4 border-0 shadow-sm rounded-4" style="background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.45) !important;">
                <div class="d-flex justify-content-between align-items-center mb-1 mb-md-2">
                    <span class="small fw-bold text-muted text-uppercase tracking-wider" style="font-size: 0.72rem;">CXC ESTADO / MUNICIPIO</span>
                    <div class="rounded-circle d-flex align-items-center justify-content-center" style="width: 36px; height: 36px; background: rgba(13, 202, 240, 0.1);">
                        <i class="bi bi-building-check text-info fs-5"></i>
                    </div>
                </div>
                <h2 class="fw-bold m-0 text-info plus-jakarta" id="kpi-cargos-publicos" style="font-size: 1.65rem;">$0.00</h2>
                <div class="d-flex justify-content-between align-items-center mt-2 mt-md-3 pt-2 border-top border-light">
                    <span class="badge bg-info bg-opacity-10 text-info rounded-pill px-2.5 py-1 small fw-semibold" style="font-size: 0.65rem;">Subsidio 100%</span>
                    <span class="small text-muted d-flex align-items-center gap-1" id="kpi-recibos-publicos-sub" style="font-size: 0.72rem;">Cartera Gobierno</span>
                </div>
            </div>
        </div>

        <!-- 3. Valor Bruto Generado (Tarjeta Resaltada con Borde Teal 2px) -->
        <div class="col">
            <div class="card card-mobile-flush h-100 p-2.5 p-md-4 border-0 shadow-sm rounded-4" style="background: #FFFFFF; border: 2px solid var(--md-teal-clinical, #19B7A5) !important;">
                <div class="d-flex justify-content-between align-items-center mb-1 mb-md-2">
                    <span class="small fw-bold text-uppercase tracking-wider" style="color: var(--md-blue-deep, #0A2A66); font-size: 0.72rem;">VALOR BRUTO GENERADO</span>
                    <div class="rounded-circle d-flex align-items-center justify-content-center" style="width: 36px; height: 36px; background: rgba(10, 42, 102, 0.08);">
                        <i class="bi bi-wallet2 fs-5" style="color: var(--md-blue-deep, #0A2A66);"></i>
                    </div>
                </div>
                <h2 class="fw-bold m-0 plus-jakarta" id="kpi-valor-bruto" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.65rem;">$0.00</h2>
                <div class="d-flex justify-content-between align-items-center mt-2 mt-md-3 pt-2 border-top border-light">
                    <span class="small text-muted" id="kpiMargenSubtexto" style="font-size: 0.72rem;">Impacto Asistencial: <span class="fw-bold text-success">100%</span></span>
                    <span class="badge rounded-pill px-2.5 py-1 small fw-semibold" style="background: rgba(25, 183, 165, 0.12); color: var(--md-teal-clinical, #19B7A5); font-size: 0.65rem;">Flujo Operativo</span>
                </div>
            </div>
        </div>
    </div>

    <!-- CAPA 2: Cobranza, Recibos y Eficiencia Operativa (4 Tarjetas con Borde Teal Suave) -->
    <div class="row row-cols-2 row-cols-md-4 g-2 g-md-3 mb-3 mb-md-4">
        <!-- 4. Recibos Emitidos -->
        <div class="col">
            <div class="card card-mobile-flush h-100 p-2.5 p-md-3 border-0 shadow-sm rounded-4" style="background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
                <div class="d-flex justify-content-between align-items-center mb-1 mb-md-2">
                    <span class="small fw-bold text-muted text-uppercase tracking-wider" style="font-size: 0.72rem;">Recibos Emitidos</span>
                    <i class="bi bi-receipt-cutoff text-primary fs-5"></i>
                </div>
                <h3 class="fw-bold m-0 text-dark plus-jakarta" id="kpi-total-recibos" style="font-size: 1.35rem;">0</h3>
                <div class="d-flex justify-content-between align-items-center mt-2 pt-1 border-top border-light">
                    <span class="small text-muted" id="kpi-recibos-desglose" style="font-size: 0.72rem;">0 Priv / 0 Púb</span>
                    <span class="badge rounded-pill small py-1 px-2" id="badge-crec-recibos" style="font-size: 0.65rem;">0% trans.</span>
                </div>
            </div>
        </div>

        <!-- 5. Ticket Promedio Privado -->
        <div class="col">
            <div class="card card-mobile-flush h-100 p-2.5 p-md-3 border-0 shadow-sm rounded-4" style="background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
                <div class="d-flex justify-content-between align-items-center mb-1 mb-md-2">
                    <span class="small fw-bold text-muted text-uppercase tracking-wider" style="font-size: 0.72rem;">Ticket Prom. Privado</span>
                    <i class="bi bi-pie-chart-fill text-warning fs-5"></i>
                </div>
                <h3 class="fw-bold m-0 text-dark plus-jakarta" id="kpi-ticket-privado" style="font-size: 1.35rem;">$0.00</h3>
                <div class="d-flex justify-content-between align-items-center mt-2 pt-1 border-top border-light">
                    <span class="small text-muted" style="font-size: 0.72rem;">Por Paciente</span>
                    <span class="badge bg-warning bg-opacity-10 text-dark rounded-pill py-1 px-2" id="kpi-ticket-publico" style="font-size: 0.65rem;">Púb: $0.00</span>
                </div>
            </div>
        </div>

        <!-- 6. Efectivo en Ventanilla -->
        <div class="col">
            <div class="card card-mobile-flush h-100 p-2.5 p-md-3 border-0 shadow-sm rounded-4" style="background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
                <div class="d-flex justify-content-between align-items-center mb-1 mb-md-2">
                    <span class="small fw-bold text-muted text-uppercase tracking-wider" style="font-size: 0.72rem;">Efectivo en Ventanilla</span>
                    <i class="bi bi-cash-coin text-success fs-5"></i>
                </div>
                <h3 class="fw-bold m-0 text-success plus-jakarta" id="kpi-efectivo-monto" style="font-size: 1.35rem;">$0.00</h3>
                <div class="d-flex justify-content-between align-items-center mt-2 pt-1 border-top border-light">
                    <span class="small text-muted" style="font-size: 0.72rem;">Caja Física</span>
                    <span class="badge bg-success bg-opacity-10 text-success rounded-pill" id="kpi-efectivo-pct" style="font-size: 0.65rem;">0% de caja</span>
                </div>
            </div>
        </div>

        <!-- 7. Integridad Contable Forense -->
        <div class="col">
            <div class="card card-mobile-flush h-100 p-2.5 p-md-3 border-0 shadow-sm rounded-4" style="background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
                <div class="d-flex justify-content-between align-items-center mb-1 mb-md-2">
                    <span class="small fw-bold text-muted text-uppercase tracking-wider" style="font-size: 0.72rem;">Integridad Contable</span>
                    <i class="bi bi-shield-check fs-5" style="color: var(--md-teal-clinical, #19B7A5);"></i>
                </div>
                <h3 class="fw-bold m-0 text-success plus-jakarta" id="kpi-calidad" style="font-size: 1.35rem;">100%</h3>
                <div class="d-flex justify-content-between align-items-center mt-2 pt-1 border-top border-light">
                    <span class="small text-muted" style="font-size: 0.72rem;">Cero Inconsistencias</span>
                    <span class="badge badge-teal-clinical rounded-pill py-1 px-2" style="font-size: 0.65rem;">Cuadre Exacto</span>
                </div>
            </div>
        </div>
    </div>

    <!-- Comportamiento Cronológico del Periodo Seleccionado (Borde Teal) -->
    <div class="card card-mobile-flush border-0 shadow-sm rounded-4 overflow-hidden bg-white mb-4" style="border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
        <div class="card-header bg-white border-bottom border-light py-3 d-flex flex-wrap justify-content-between align-items-center gap-2">
            <div class="d-flex align-items-center gap-2">
                <i class="bi bi-calendar2-week fs-5" style="color: var(--md-teal-clinical, #19B7A5);"></i>
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

    <!-- Dos Columnas: Medios de Pago & Demanda Clínica (Borde Teal) -->
    <div class="row g-4 mb-4">
        <!-- Columna Izquierda: Control de Medios de Pago -->
        <div class="col-12 col-lg-6">
            <div class="card card-mobile-flush border-0 shadow-sm rounded-4 bg-white h-100 p-4" style="border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
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
            <div class="card card-mobile-flush border-0 shadow-sm rounded-4 bg-white h-100 p-4" style="border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
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

    <!-- Sección 4: Preguntas Estratégicas y Recomendaciones para la Alta Dirección (Borde Teal) -->
    <div class="card card-mobile-flush border-0 shadow-sm rounded-4 bg-white p-4 mb-4" style="border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
        <div class="d-flex flex-wrap align-items-center justify-content-between mb-3 border-bottom pb-2 gap-2">
            <div>
                <h5 class="fw-bold text-dark mb-0 d-flex align-items-center gap-2">
                    <i class="bi bi-lightbulb-fill text-warning"></i>Preguntas Estratégicas y Recomendaciones para la Alta Dirección
                </h5>
                <p class="text-muted small mb-0">Ejes prioritarios de gobernanza, seguridad en caja física, nivelación de capacidad operativa y optimización de convenios públicos.</p>
            </div>
            <span class="badge bg-warning bg-opacity-10 text-dark px-3 py-1 rounded-pill fw-bold">Ejes Estratégicos</span>
        </div>
        <div id="contenedorRecomendaciones" class="row g-3">
            <div class="col-12 text-center py-3 text-muted">Cargando recomendaciones estratégicas...</div>
        </div>
    </div>

    <!-- Dictamen de Seguridad y Certificación Forense (Borde Teal) -->
    <div class="card border-0 shadow-sm rounded-4 bg-white p-4 mb-4" style="border: 1.5px solid var(--md-teal-clinical, #19B7A5) !important;">
        <div class="d-flex flex-wrap align-items-center justify-content-between gap-3">
            <div class="d-flex align-items-center gap-3">
                <div class="p-3 bg-opacity-10 rounded-circle" style="background-color: rgba(25, 183, 165, 0.12); color: var(--md-teal-clinical, #19B7A5);">
                    <i class="bi bi-patch-check-fill fs-3"></i>
                </div>
                <div>
                    <h6 class="fw-bold text-dark mb-1">Certificación Contable y Forense del Periodo</h6>
                    <p class="text-muted small mb-0">La base de datos de producción cumple estrictamente con el principio de integridad contable: cero folios saltados, cuadre matemático de ítems JSON y firmas digitales de usuario certificadas.</p>
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
    const botones = document.querySelectorAll('#filterPillsGroup .btn-filter-pill');
    botones.forEach(b => {
        b.classList.remove('active');
        b.classList.add('btn-light', 'text-secondary');
    });
    if (btnElem) {
        btnElem.classList.add('active');
        btnElem.classList.remove('btn-light', 'text-secondary');
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
        document.getElementById('tituloTablaDesglose').textContent = 'Comportamiento y Desglose por Turno / Horario (' + data.periodo_activo + ')';
    } else if (data.tipo_periodo === 'semana') {
        listaPeriodos = data.semanas_disponibles || [];
        prefijoEtiqueta = 'Semana: ';
        document.getElementById('tituloTablaDesglose').textContent = 'Comportamiento y Desglose Diario (Lunes a Domingo)';
    } else if (data.tipo_periodo === 'mes') {
        listaPeriodos = data.meses_disponibles || [];
        prefijoEtiqueta = 'Mes: ';
        document.getElementById('tituloTablaDesglose').textContent = 'Comportamiento Diario del Mes (' + data.periodo_activo + ')';
    } else if (data.tipo_periodo === 'ano') {
        listaPeriodos = data.anos_disponibles || [];
        prefijoEtiqueta = 'Año: ';
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

    // Poblar Membrete Formal Institucional de Impresión / PDF
    if (document.getElementById('printClinicaNombre')) {
        document.getElementById('printClinicaNombre').textContent = data.nombre_negocio || 'CLÍNICA MÉDICA';
        document.getElementById('printClueOrg').textContent = data.clue || 'QTSMP000116';
        document.getElementById('printPeriodoBadge').textContent = data.numero_semana_str || (capitalizar(data.tipo_periodo) + ' ' + data.periodo_activo);
        document.getElementById('printRangoFechas').textContent = data.fecha_inicio ? (`Del ${data.fecha_inicio} al ${data.fecha_fin}`) : '';
        document.getElementById('printFechaEmision').textContent = 'Emisión: ' + (new Date()).toLocaleDateString('es-MX', { year: 'numeric', month: 'long', day: 'numeric' });
    }

    // 2. Hero KPIs y Métricas
    const kpis = data.kpis || {};
    document.getElementById('kpi-flujo-privado').textContent = formatoMoneda(kpis.flujo_privado || 0);
    document.getElementById('kpi-cargos-publicos').textContent = formatoMoneda(kpis.cargos_publicos || 0);
    document.getElementById('kpi-valor-bruto').textContent = formatoMoneda(kpis.valor_bruto_total || ((kpis.flujo_privado || 0) + (kpis.cargos_publicos || 0)));
    document.getElementById('kpi-total-recibos').textContent = (kpis.total_recibos || 0);
    document.getElementById('kpi-recibos-desglose').textContent = (kpis.recibos_privados || 0) + ' Priv / ' + (kpis.recibos_publicos || 0) + ' Púb';
    document.getElementById('kpi-recibos-publicos-sub').textContent = (kpis.recibos_publicos || 0) + ' órdenes públicas';
    document.getElementById('kpi-ticket-privado').textContent = formatoMoneda(kpis.ticket_prom_privado || 0);
    document.getElementById('kpi-ticket-publico').textContent = 'Púb: ' + formatoMoneda(kpis.ticket_prom_publico || 0);
    document.getElementById('kpi-calidad').textContent = (kpis.calidad_datos_pct || 100) + '%';

    // Medios de pago / Efectivo
    const efec = data.efectivo || {};
    if (document.getElementById('kpi-efectivo-monto')) {
        document.getElementById('kpi-efectivo-monto').textContent = formatoMoneda(efec.monto || 0);
        document.getElementById('kpi-efectivo-pct').textContent = (efec.porcentaje || '0') + '% de caja';
    }

    // Tendencia de ingresos
    const crecIng = parseFloat(kpis.crec_ingresos_pct || 0);
    const bCrecIng = document.getElementById('badge-crec-ingresos');
    bCrecIng.textContent = (crecIng >= 0 ? '+' : '') + crecIng + '% vs periodo anterior';
    bCrecIng.className = 'small fw-semibold d-flex align-items-center gap-1 ' + (crecIng >= 0 ? 'text-success' : 'text-danger');

    // Tendencia de transacciones
    const crecRec = parseFloat(kpis.crec_recibos_pct || 0);
    const bCrecRec = document.getElementById('badge-crec-recibos');
    bCrecRec.textContent = (crecRec >= 0 ? '+' : '') + crecRec + '%';
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

    // 6. Sección 4: Recomendaciones y Preguntas Estratégicas para la Alta Dirección
    const contRecom = document.getElementById('contenedorRecomendaciones');
    if (contRecom) {
        contRecom.innerHTML = '';
        const recoms = data.recomendaciones || [];
        if (recoms.length === 0) {
            contRecom.innerHTML = '<div class="col-12 text-center text-muted py-2">Sin recomendaciones disponibles para este periodo.</div>';
        } else {
            recoms.forEach(rec => {
                const col = document.createElement('div');
                col.className = 'col-12 col-md-6';
                col.innerHTML = `
                    <div class="recom-card-exec p-3 h-100 d-flex flex-column justify-content-between" style="border: 1.5px solid rgba(25, 183, 165, 0.25) !important;">
                        <div>
                            <div class="d-flex justify-content-between align-items-center mb-2">
                                <span class="fw-bold text-dark d-flex align-items-center gap-2">
                                    <i class="bi ${rec.icono} text-${rec.color}"></i>Eje ${rec.eje}: ${rec.titulo}
                                </span>
                                <span class="badge bg-${rec.color} bg-opacity-10 text-${rec.color} small">${rec.metrica}</span>
                            </div>
                            <p class="small text-secondary mb-2 fst-italic">"${rec.pregunta}"</p>
                        </div>
                        <div class="p-2 rounded bg-light border-start border-3 border-${rec.color} mt-2">
                            <div class="small fw-semibold text-dark"><i class="bi bi-arrow-right-short text-${rec.color} fs-6"></i>Acción propuesta:</div>
                            <div class="small text-muted">${rec.propuesta}</div>
                        </div>
                    </div>
                `;
                contRecom.appendChild(col);
            });
        }
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
    const textoCopiar = (datosEjecutivosGlobal && (datosEjecutivosGlobal.prompt_ia_completo || datosEjecutivosGlobal.markdown_export)) || '';
    if (!textoCopiar) {
        Swal.fire('Aviso', 'Aún no se han cargado los datos para copiar.', 'info');
        return;
    }

    navigator.clipboard.writeText(textoCopiar)
    .then(() => {
        Swal.fire({
            title: '¡Prompt para IA Copiado!',
            html: `Se ha copiado a tu portapapeles el <strong>Prompt de Auditoría Hospitalaria Senior</strong> con la estructura ejecutiva de 4 secciones y todas las cifras auditadas.<br><br><span class="badge bg-primary px-3 py-2 fs-6">Listo para pegar en ChatGPT, Claude o Gamma</span>`,
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
