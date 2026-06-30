#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib $FindBin::Bin . '/..';

require '../auth/check_session.pl';
require '../utils/sub_header.pl';
require '../utils/sub_footer.pl';
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();
unless ($session_data->{session_ok}) { print $q->header(-status => '302 Found', -location => '../index.html'); exit; }

my $id_paciente = $q->param('id');
unless ($id_paciente) { print $q->redirect('pacientes.pl'); exit; }

my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $paciente;
my $reg = leer_tabla($archivo_pacientes, '\|');
foreach (@$reg) { if ($_->[0] eq $id_paciente) { $paciente = { id => $_->[0], nombre => $_->[2] }; last; } }

unless ($paciente) { 
    print $q->header(-charset => 'UTF-8'); 
    print "<div class='container py-5 text-center'><h2 class='fw-bold text-danger'>Paciente no localizado.</h2><a href='pacientes.pl' class='btn btn-primary mt-3'>Volver al Directorio</a></div>"; 
    exit; 
}

# 1. Cabecera SDP Premium
render_header(
    usuario => $session_data->{usuario}, 
    titulo => "Estado de Cuenta - SDM", 
    role => $session_data->{role}, 
    id_medico => $session_data->{id_medico}
);

my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $negocio = { nombre => 'SDM Dental', domicilio => '', telefono => '', email => '' };
my $reg_neg = leer_tabla($archivo_negocios, '\|');
foreach (@$reg_neg) { 
    if ($_->[0] eq '1') { 
        $negocio = { 
            nombre => $_->[1], 
            domicilio => $_->[6], 
            telefono => $_->[7], 
            email => $_->[8] 
        }; last; 
    } 
}

my $iniciales = uc(substr($paciente->{nombre}, 0, 2) // 'PA');

print <<HTML;
<style>
    .print-header { display: none; }

    \@media print {
        .navbar, .btn, .dropdown, .modal, .bi, .btn-close, .col-lg-4, #btnLiquidarTodo, .financial-dock, .top-actions-desktop, .breadcrumb { display: none !important; }
        body { background: white !important; padding: 0 !important; color: black !important; }
        .bento-card { border: none !important; box-shadow: none !important; padding: 10px 0 !important; width: 100% !important; }
        
        /* Ocultar columna acciones */
        #tbEdoCuenta tr td:last-child, 
        table thead tr th:last-child { display: none !important; }

        /* Forzar visibilidad total de la tabla y su contenido */
        #bentoTransactionsContainer { display: none !important; }
        .table-responsive { display: block !important; overflow: visible !important; width: 100% !important; }
        table { display: table !important; width: 100% !important; font-size: 8pt !important; border-collapse: collapse !important; color: black !important; }
        thead { display: table-header-group !important; }
        tbody { display: table-row-group !important; }
        tfoot { display: table-footer-group !important; font-weight: bold !important; border-top: 2px solid #000 !important; }
        
        tr { page-break-inside: avoid !important; border-bottom: 1px solid #eee !important; }
        td, th { color: black !important; background: transparent !important; }

        .d-none-print { display: none !important; }
        .container-fluid { padding: 0 !important; margin: 0 !important; max-width: 100% !important; }
        
        .print-header { 
            display: block !important; 
            border-bottom: 3px solid #000 !important; 
            padding-bottom: 15px;
            margin-bottom: 25px; 
            color: black !important;
        }
        .print-header h1 { color: black !important; margin-bottom: 5px; }
    }

    /* Botones Institucionales */
    .btn-sdm-primary {
        background: var(--sdm-primary) !important;
        color: white !important;
        border: none !important;
        transition: all 0.3s ease;
    }
    .btn-sdm-primary:hover {
        background: var(--sdm-navy) !important;
        transform: translateY(-2px);
        box-shadow: 0 5px 15px rgba(13, 30, 61, 0.2);
    }
    .btn-sdm-primary i { color: white !important; }

    /* DOCK FINANCIERO MOBILE */
    .financial-dock {
        position: fixed;
        bottom: 20px;
        left: 20px;
        right: 20px;
        background: rgba(255, 255, 255, 0.85);
        backdrop-filter: blur(15px);
        -webkit-backdrop-filter: blur(15px);
        border: 1px solid rgba(255, 255, 255, 0.3);
        border-radius: 2rem;
        height: 70px;
        display: flex;
        align-items: center;
        justify-content: space-around;
        box-shadow: 0 15px 35px rgba(0, 0, 0, 0.1);
        z-index: 1050;
        padding: 0 10px;
    }
    .dock-item {
        color: #64748b;
        font-size: 1.4rem;
        display: flex;
        flex-direction: column;
        align-items: center;
        text-decoration: none;
        transition: all 0.2s ease;
        background: none;
        border: none;
        padding: 10px;
    }
    .dock-item:active { transform: scale(0.9); color: var(--sdm-navy); }
    .dock-fab {
        width: 60px;
        height: 60px;
        background: linear-gradient(135deg, #0d1e3d 0%, #1e40af 100%);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white !important;
        font-size: 1.8rem;
        margin-top: -40px;
        box-shadow: 0 10px 20px rgba(13, 30, 61, 0.3);
        border: 4px solid white;
    }
    .dock-fab:active { transform: scale(0.9) translateY(5px); }

    \@media (max-width: 768px) {
        .top-actions-desktop { display: none !important; }
        body { padding-bottom: 100px !important; }
    }
    \@media (min-width: 769px) {
        .financial-dock { display: none !important; }
    }
</style>
<div class="container-fluid px-md-5 py-4 animate__animated animate__fadeIn">
    <!-- Breadcrumb -->
    <div class="d-flex justify-content-between align-items-center mb-4">
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb mb-0">
                <li class="breadcrumb-item"><a href="pacientes.pl" class="text-decoration-none text-muted fw-bold">Pacientes</a></li>
                <li class="breadcrumb-item active fw-bold text-primary" aria-current="page">Estado de Cuenta</li>
            </ol>
        </nav>
    </div>

    <!-- Header de Impresión Profesional -->
    <div class="print-header">
        <div class="d-flex justify-content-between align-items-end">
            <div>
                <h1 class="fw-bold plus-jakarta mb-1" style="color: var(--sdm-navy);">$negocio->{nombre}</h1>
                <p class="mb-0 text-muted small fw-bold">
                    <i class="bi bi-geo-alt me-1"></i>$negocio->{domicilio} | 
                    <i class="bi bi-telephone me-1"></i>$negocio->{telefono} | 
                    <i class="bi bi-envelope me-1"></i>$negocio->{email}
                </p>
            </div>
            <div class="text-end">
                <h4 class="fw-bold mb-0">ESTADO DE CUENTA</h4>
                <p class="text-muted small mb-0">Fecha de reporte: <span id="printDate"></span></p>
            </div>
        </div>
    </div>

    <!-- Paciente Header Card -->
    <div class="bento-card mb-4 border-0 shadow-sm" style="background: white; border-left: 6px solid var(--sdm-navy) !important;">
        <div class="d-flex align-items-center gap-4">
            <div class="bg-primary text-white rounded-4 d-flex align-items-center justify-content-center shadow" style="width:70px; height:70px; font-size:1.8rem; font-weight:800;">$iniciales</div>
            <div>
                <h2 class="fw-bold plus-jakarta mb-1 text-dark">$paciente->{nombre}</h2>
                <div class="d-flex gap-3 text-muted small fw-bold uppercase tracking-wider">
                    <span><i class="bi bi-hash me-1"></i>PACIENTE ID: $id_paciente</span>
                    <span><i class="bi bi-shield-check text-success me-1"></i>SNC-FIN-ACTIVE</span>
                </div>
            </div>
            <!-- Botones de Acción Integrados (Desktop/Tablet) -->
            <div class="ms-auto d-flex gap-2 bg-light p-2 rounded-pill shadow-sm border">
                <button onclick="imprimirEstadoCuenta()" class="btn btn-sdm-primary fw-bold rounded-pill px-3 px-lg-4"><i class="bi bi-printer me-lg-2"></i><span class="d-none d-lg-inline">IMPRIMIR</span></button>
                <button onclick="abrirModalAbono()" class="btn btn-sdm-primary fw-bold rounded-pill px-3 px-lg-4"><i class="bi bi-cash-coin me-lg-2"></i><span class="d-none d-lg-inline">ABONAR</span></button>
                <button onclick="abrirModalCargo()" class="btn btn-sdm-primary fw-bold rounded-pill px-3 px-lg-4"><i class="bi bi-cart-plus me-lg-2"></i><span class="d-none d-lg-inline">NUEVO CARGO</span></button>
            </div>
        </div>
    </div>

    <div class="row g-4">
        <!-- Dashboard Financiero -->
        <div class="col-lg-4">
            <div class="d-flex flex-column gap-4">
                <div id="ecSaldoCard" class="bento-card kpi-card shadow-sm border-0" style="background: white;">
                    <span class="kpi-label">Balance Pendiente</span>
                    <div class="d-flex justify-content-between align-items-center">
                        <h2 id="ecSaldo" class="kpi-value">\$0.00</h2>
                        <button onclick="liquidarSaldoTotal()" class="btn btn-sm btn-danger fw-bold rounded-pill px-3 py-1 shadow-sm" id="btnLiquidarTodo" style="display:none; font-size: 0.6rem;">LIQUIDAR</button>
                    </div>
                    <i class="bi bi-wallet2 kpi-icon"></i>
                </div>

                <div class="bento-card border-0 shadow-sm bg-white">
                    <span class="kpi-label mb-3">Resumen Consolidado</span>
                    <div class="d-flex flex-column gap-3">
                        <div class="d-flex justify-content-between align-items-end">
                            <span class="small fw-bold text-muted">TOTAL CARGOS</span>
                            <span id="ecCargos" class="fw-bold text-danger">\$0.00</span>
                        </div>
                        <div class="progress" style="height: 6px;">
                            <div class="progress-bar bg-danger" style="width: 100%"></div>
                        </div>
                        <div class="d-flex justify-content-between align-items-end">
                            <span class="small fw-bold text-muted">TOTAL ABONOS</span>
                            <span id="ecAbonos" class="fw-bold text-success">\$0.00</span>
                        </div>
                        <div class="progress" style="height: 6px;">
                            <div class="progress-bar bg-success" style="width: 100%"></div>
                        </div>
                    </div>
                </div>

                <div class="bento-card border-0 shadow-sm bg-primary text-white">
                    <h5 class="fw-bold mb-3">&iquest;Dudas?</h5>
                    <p class="small opacity-75 mb-4">Puedes conciliar los pagos directamente con el m&eacute;dico asignado o el administrador del sistema dental.</p>
                    <button class="btn btn-light btn-sm w-100 fw-bold rounded-3">SOLICITAR AUDITOR&Iacute;A</button>
                </div>
            </div>
        </div>

        <!-- Historial de Movimientos -->
        <div class="col-lg-8">
            <div class="bento-card border-0 shadow-sm h-100">
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <h4 class="fw-bold plus-jakarta m-0">Movimientos Recientes</h4>
                    <div class="dropdown">
                        <button class="btn btn-sm btn-light border dropdown-toggle" type="button" data-bs-toggle="dropdown">Filtrar</button>
                        <ul class="dropdown-menu">
                            <li><a class="dropdown-item" href="#">Todos</a></li>
                            <li><a class="dropdown-item" href="#">Solo Cargos</a></li>
                            <li><a class="dropdown-item" href="#">Solo Abonos</a></li>
                        </ul>
                    </div>
                </div>

                <div class="table-responsive d-print-block d-none d-lg-block">
                    <table class="table table-hover align-middle mb-0">
                        <thead class="bg-light">
                            <tr>
                                <th class="ps-4 py-3 small fw-bold text-muted uppercase tracking-wider">Folio / OS</th>
                                <th class="py-3 small fw-bold text-muted uppercase tracking-wider">Fecha</th>
                                <th class="py-3 small fw-bold text-muted uppercase tracking-wider">Concepto</th>
                                <th class="py-3 text-end small fw-bold text-muted uppercase tracking-wider">Cargos</th>
                                <th class="py-3 text-end small fw-bold text-muted uppercase tracking-wider">Abonos</th>
                                <th class="py-3 text-center small fw-bold text-muted uppercase tracking-wider">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="tbEdoCuenta" class="border-top-0">
                            <!-- Se llena vía AJAX -->
                        </tbody>
                        <tfoot class="bg-light fw-bold border-top-2">
                            <tr>
                                <td colspan="3" class="text-end py-3 ps-4">TOTALES CONSOLIDADOS:</td>
                                <td id="tfCargos" class="text-end text-danger py-3">\$0.00</td>
                                <td id="tfAbonos" class="text-end text-success py-3">\$0.00</td>
                                <td></td>
                            </tr>
                        </tfoot>
                    </table>
                </div>

                <div id="bentoTransactionsContainer" class="d-flex flex-column gap-3 d-lg-none">
                    <div class="text-center py-5">
                        <div class="spinner-border text-primary mb-3"></div>
                        <p class="text-muted fw-bold small">Sincronizando transacciones financieras...</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- DOCK FINANCIERO (WebApp Experience) -->
<div class="financial-dock">
    <a href="pacientes.pl" class="dock-item" title="Volver">
        <i class="bi bi-arrow-left"></i>
    </a>
    <button onclick="imprimirEstadoCuenta()" class="dock-item" title="Imprimir">
        <i class="bi bi-printer"></i>
    </button>
    <button onclick="abrirModalCargo()" class="dock-item dock-fab" title="Nuevo Cargo">
        <i class="bi bi-plus-lg"></i>
    </button>
    <button onclick="abrirModalAbono()" class="dock-item" title="Abonar">
        <i class="bi bi-cash-coin"></i>
    </button>
    <button onclick="window.scrollTo({top:0, behavior:'smooth'})" class="dock-item" title="KPIs">
        <i class="bi bi-graph-up-arrow"></i>
    </button>
</div>

<!-- MODALES (BOOTSTRAP 5) -->
<div class="modal fade" id="modalCargo" tabindex="-1">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content overflow-hidden">
            <div class="modal-header bg-navy text-white py-4 px-4 border-0" style="background: var(--sdm-navy);">
                <h4 class="modal-title fw-bold plus-jakarta" id="modalCargoTitle"><i class="bi bi-cart-plus me-3"></i>Cat&aacute;logo de Servicios</h4>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body bg-light p-4">
                <div class="row g-4">
                    <div class="col-lg-7">
                        <div class="bento-card p-4 mb-4 border-0 shadow-sm">
                            <label class="kpi-label">Entrada Manual</label>
                            <div class="input-group">
                                <input type="text" id="manual_nombre" class="form-control" placeholder="Concepto (ej. Consulta General)">
                                <span class="input-group-text">\$</span>
                                <input type="number" id="manual_precio" class="form-control" style="max-width: 120px;" placeholder="0.00">
                                <button onclick="agregarCargoManual()" class="btn btn-primary px-4"><i class="bi bi-plus-lg"></i></button>
                            </div>
                        </div>
                        <div class="mb-3 position-relative">
                            <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-3 text-muted"></i>
                            <input type="text" id="buscadorCatalogo" class="form-control ps-5 py-3 rounded-pill shadow-sm border-0" placeholder="Buscar en el catálogo dental..." onkeyup="filtrarCatalogo()">
                        </div>
                        <div id="divCatalogo" class="row g-2 overflow-auto" style="max-height: 450px; padding: 5px;"></div>
                    </div>
                    <div class="col-lg-5">
                       <div class="bento-card p-4 border-0 shadow-md h-100 d-flex flex-column" style="background: #f8fafc;">
                          <h6 class="kpi-label text-primary">Resumen del Cargo</h6>
                          <div id="listaCarrito" class="flex-grow-1 d-flex flex-column gap-2 overflow-auto mb-4" style="max-height: 350px;"></div>
                          <div class="p-4 bg-white rounded-4 border shadow-sm">
                             <div class="d-flex justify-content-between align-items-center mb-3">
                                <span class="small fw-bold text-muted">TOTAL CARGO</span>
                                <span class="h2 fw-bold text-primary m-0" id="carritoTotal">\$0.00</span>
                             </div>
                             <button class="btn btn-primary w-100 py-3 fw-bold rounded-3 shadow" id="btnProcesarCargo" onclick="procesarCarrito()">PROCESAR CARGO</button>
                          </div>
                       </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalAbono" tabindex="-1">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content p-2">
            <div class="modal-header border-0 px-4 pt-4">
                <h4 class="fw-bold plus-jakarta" id="modalAbonoTitle">Registrar Abono</h4>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4">
                <input type="hidden" id="notasAbono" value="">
                <div class="p-4 bg-success-subtle rounded-4 text-center mb-4">
                    <span class="kpi-label text-success">Monto del Pago</span>
                    <div class="input-group mt-2">
                        <span class="input-group-text bg-transparent border-0 text-success fs-2 fw-bold">\$</span>
                        <input type="number" id="montoAbono" class="form-control bg-transparent border-0 text-success fs-1 fw-bold text-center" placeholder="0.00">
                    </div>
                </div>
                <div class="mb-4">
                    <label class="kpi-label">M&eacute;todo de Pago</label>
                    <select id="metodoAbono" class="form-select py-3 rounded-3">
                        <option>Efectivo</option>
                        <option>Tarjeta de Cr&eacute;dito/D&eacute;bito</option>
                        <option>Transferencia</option>
                        <option>Seguro Dental</option>
                    </select>
                </div>
                <button class="btn btn-success w-100 py-3 fw-bold rounded-3 shadow" onclick="procesarAbono()">CONFIRMAR PAGO</button>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script src="../js/estado_cuenta_spa.js?v=$^T"></script>
<script>
    document.addEventListener("DOMContentLoaded", () => { 
        initModuloFinanciero('$id_paciente', 'bento', '$session_data->{id_medico}'); 
    });
</script>
HTML

render_footer();
1;
