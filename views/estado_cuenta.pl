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

require '../auth/check_session.pl';
require '../utils/sub_header.pl';
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();
my $id_paciente = $q->param('id') || '';

if (!$id_paciente) {
    print "Content-Type: text/html; charset=UTF-8\n\n";
    render_header(usuario => $session_data->{usuario}, titulo => "Estado de Cuenta - SDM", role => $session_data->{role}, id_medico => $session_data->{id_medico}, skip_header => 1);
    print <<HTML;
<div class="container py-4 px-2 px-md-4 animate__animated animate__fadeIn" style="max-width: 1000px; overflow-x: hidden;">
    
    <div class="row g-4 justify-content-center">
        <!-- Dashboard Financiero Global -->
        <div class="col-lg-5">
            <div class="d-flex flex-column gap-4 h-100">
                <div class="bento-card border-0 shadow-lg bg-white h-100 d-flex flex-column justify-content-center" style="border-radius: 20px;">
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <span class="fw-bold plus-jakarta text-dark m-0" style="font-size: 1.1rem;">Resumen Consolidado Global</span>
                        <button class="btn btn-sm bg-light rounded-pill border px-3 fw-bold shadow-sm" style="font-size: 0.75rem; color: #475569;"><i class="bi bi-calendar3 me-1"></i> Global</button>
                    </div>
                    
                    <div class="row align-items-center g-0">
                        <div class="col-6 position-relative" style="height: 160px;">
                            <canvas id="pieResumenConsolidado"></canvas>
                            <div class="position-absolute top-50 start-50 translate-middle text-center w-100" style="pointer-events: none; margin-top: 2px;">
                                <h5 class="fw-bold text-dark m-0 plus-jakarta" id="pieCenterVal" style="font-size: 1.1rem;">\$0</h5>
                                <span class="text-muted fw-bold" style="font-size: 0.7rem; text-transform: uppercase;">Saldo</span>
                            </div>
                        </div>
                        <div class="col-6 ps-2">
                            <div class="d-flex flex-column gap-3 w-100" id="pieCustomLegend">
                                <div class="d-flex align-items-center justify-content-between w-100">
                                    <div class="d-flex align-items-center gap-2">
                                        <div style="width: 10px; height: 10px; border-radius: 50%; background: #eab308; box-shadow: inset -1px -1px 3px rgba(0,0,0,0.3);"></div>
                                        <span class="text-muted fw-bold" style="font-size: 0.75rem;">Cargos</span>
                                    </div>
                                    <span class="fw-bold text-dark" style="font-size: 0.75rem;" id="legCargos">\$0</span>
                                </div>
                                <div class="d-flex align-items-center justify-content-between w-100">
                                    <div class="d-flex align-items-center gap-2">
                                        <div style="width: 10px; height: 10px; border-radius: 50%; background: #10b981; box-shadow: inset -1px -1px 3px rgba(0,0,0,0.3);"></div>
                                        <span class="text-muted fw-bold" style="font-size: 0.75rem;">Abonos</span>
                                    </div>
                                    <span class="fw-bold text-dark" style="font-size: 0.75rem;" id="legAbonos">\$0</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Búsqueda -->
        <div class="col-lg-7">
            <div class="bento-card border-0 shadow-sm h-100 text-center d-flex flex-column justify-content-center align-items-center" style="background: white; padding: 4rem 2rem;">
                <div class="mb-4 text-muted" style="font-size: 4rem; opacity: 0.5;">
                    <i class="bi bi-search"></i>
                </div>
                <h2 class="fw-bold plus-jakarta mb-3" style="color: var(--md-blue-deep, #0A2A66);">Buscar Paciente</h2>
                <p class="text-muted mb-4 fs-5">Para visualizar un estado de cuenta específico y registrar movimientos financieros, selecciona a un paciente.</p>
                <div class="p-3 bg-primary-subtle rounded-3 d-inline-block">
                    <span class="text-primary fw-bold"><i class="bi bi-arrow-up-circle me-2"></i>Utiliza la barra de búsqueda superior para encontrar el expediente.</span>
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
<script src="../js/estado_cuenta_spa.js?v=$^T"></script>
<script>
    document.addEventListener("DOMContentLoaded", () => { 
        initModuloFinanciero('', 'bento', '$session_data->{id_medico}'); 
    });
</script>
</body>
</html>
HTML
    exit;
}

my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $paciente;
my $reg = leer_tabla($archivo_pacientes, '\|');
foreach (@$reg) { if ($_->[0] eq $id_paciente) { $paciente = { id => $_->[0], nombre => $_->[2] }; last; } }

unless ($paciente) { 
    print "Content-Type: text/html; charset=UTF-8\n\n";
    render_header(usuario => $session_data->{usuario}, titulo => "Estado de Cuenta - SDM", role => $session_data->{role}, id_medico => $session_data->{id_medico}, skip_header => 1);
    print "<div class='container py-5 text-center'><h2 class='fw-bold text-danger'>Paciente no localizado.</h2><a href='pacientes.pl' class='btn btn-primary mt-3'>Volver al Directorio</a></div></body></html>"; 
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
my $nombre_display = $paciente->{nombre};
my $id_display = $id_paciente;

print <<HTML;
<div class="container py-4 px-2 px-md-4 animate__animated animate__fadeIn" style="max-width: 1000px; overflow-x: hidden;">

    <!-- Header de Impresión Profesional -->
    <div class="print-header">
        <div class="d-flex justify-content-between align-items-end">
            <div>
                <h1 class="fw-bold plus-jakarta mb-1" style="color: var(--md-blue-deep, #0A2A66);">$negocio->{nombre}</h1>
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

    <!-- Paciente Header Compacto -->
    <div class="diamond-header-compact d-flex flex-column flex-md-row justify-content-between align-items-center mb-4">
        <div class="d-flex align-items-center gap-3 w-100">
            <div class="rounded-circle d-flex align-items-center justify-content-center fw-bold shadow border border-2 border-white" style="width: 50px; height: 50px; font-size: 1.3rem; background: linear-gradient(135deg, var(--md-teal-bright, #00C4C4), #047857); color: white;">
                $iniciales
            </div>
            <div class="profile-hero text-start text-white flex-grow-1">
                <h4 class="text-truncate m-0 fw-bold" style="letter-spacing: -0.5px; font-family: 'Plus Jakarta Sans', sans-serif;">$nombre_display</h4>
                <div class="d-flex align-items-center gap-3 mt-1">
                    <span class="badge bg-light text-dark rounded-pill shadow-sm" style="font-size: 0.75rem;"><i class="bi bi-person-badge me-1"></i>$id_display</span>
                    <a href="https://wa.me/521" target="_blank" class="text-decoration-none text-white opacity-75" title="Contactar por WhatsApp">
                        <i class="bi bi-whatsapp" style="color: #25D366;"></i> WhatsApp
                    </a>
                </div>
            </div>
            <!-- Acciones Desktop -->
            <div class="d-none d-md-flex gap-2">
                <button onclick="imprimirEstadoCuenta()" class="btn btn-premium-outline btn-pill-unify shadow-sm px-3 py-2"><i class="bi bi-printer me-2"></i>Imprimir</button>
                <button onclick="abrirModalAbono()" class="btn btn-premium-outline btn-pill-unify shadow-sm px-3 py-2"><i class="bi bi-cash-coin me-2"></i>Abonar</button>
                <button onclick="abrirModalCargo()" class="btn btn-premium-outline btn-pill-unify shadow-sm px-3 py-2"><i class="bi bi-cart-plus me-2"></i>Nuevo Cargo</button>
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

                <div class="bento-card border-0 shadow-lg bg-white" style="border-radius: 20px;">
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <span class="fw-bold plus-jakarta text-dark m-0" style="font-size: 1.1rem;">Resumen Consolidado</span>
                        <button class="btn btn-sm bg-light rounded-pill border px-3 fw-bold shadow-sm" style="font-size: 0.75rem; color: #475569;"><i class="bi bi-calendar3 me-1"></i> Global</button>
                    </div>
                    
                    <div class="row align-items-center g-0">
                        <div class="col-6 position-relative" style="height: 160px;">
                            <canvas id="pieResumenConsolidado"></canvas>
                            <div class="position-absolute top-50 start-50 translate-middle text-center w-100" style="pointer-events: none; margin-top: 2px;">
                                <h5 class="fw-bold text-dark m-0 plus-jakarta" id="pieCenterVal" style="font-size: 1.1rem;">\$0</h5>
                                <span class="text-muted fw-bold" style="font-size: 0.7rem; text-transform: uppercase;">Saldo</span>
                            </div>
                        </div>
                        <div class="col-6 ps-2">
                            <div class="d-flex flex-column gap-3 w-100" id="pieCustomLegend">
                                <div class="d-flex align-items-center justify-content-between w-100">
                                    <div class="d-flex align-items-center gap-2">
                                        <div style="width: 10px; height: 10px; border-radius: 50%; background: #eab308; box-shadow: inset -1px -1px 3px rgba(0,0,0,0.3);"></div>
                                        <span class="text-muted fw-bold" style="font-size: 0.75rem;">Cargos</span>
                                    </div>
                                    <span class="fw-bold text-dark" style="font-size: 0.75rem;" id="legCargos">\$0</span>
                                </div>
                                <div class="d-flex align-items-center justify-content-between w-100">
                                    <div class="d-flex align-items-center gap-2">
                                        <div style="width: 10px; height: 10px; border-radius: 50%; background: #10b981; box-shadow: inset -1px -1px 3px rgba(0,0,0,0.3);"></div>
                                        <span class="text-muted fw-bold" style="font-size: 0.75rem;">Abonos</span>
                                    </div>
                                    <span class="fw-bold text-dark" style="font-size: 0.75rem;" id="legAbonos">\$0</span>
                                </div>
                            </div>
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
                </div>

                <div class="table-responsive d-print-block d-none d-lg-block">
                    <table id="dtEdoCuenta" class="table table-hover align-middle mb-0 table-medentia" style="border: 2px solid var(--md-teal-bright, #00C4C4) !important; border-radius: 12px; overflow: hidden; width: 100%;">
                        <thead class="bg-light">
                            <tr>
                                <th class="ps-4 py-3 small fw-bold text-muted uppercase tracking-wider">Alias / OS</th>
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
            <div class="modal-header border-0 pb-3" style="background: linear-gradient(135deg, var(--md-blue-deep, #0A2A66) 0%, var(--md-teal-bright, #00C4C4) 100%);">
                <h4 class="modal-title fw-bold plus-jakarta text-white" id="modalCargoTitle"><i class="bi bi-cart-plus me-3"></i>Nueva Orden de Servicio</h4>
                <button type="button" class="btn-close btn-close-white shadow-none" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-3" style="background: #f8fafc;">
                <div class="row g-3">
                    <div class="col-lg-7">
                        <div class="bento-card p-3 mb-2 border-0 shadow-sm" style="background: white;">
                            <label class="kpi-label mb-2">Aplica para:</label>
                            <div class="d-flex gap-4">
                                <div class="form-check">
                                    <input class="form-check-input" type="radio" name="aplica_para" id="aplica_presupuesto" value="Presupuesto">
                                    <label class="form-check-label fw-bold text-muted small" for="aplica_presupuesto">Presupuesto</label>
                                </div>
                                <div class="form-check">
                                    <input class="form-check-input" type="radio" name="aplica_para" id="aplica_consulta" value="Consulta" checked>
                                    <label class="form-check-label fw-bold text-muted small" for="aplica_consulta">Consulta</label>
                                </div>
                            </div>
                        </div>
                        <div class="bento-card p-3 mb-2 border-0 shadow-sm" style="background: white;">
                            <label class="kpi-label">Alias / Referencia Corta (Opcional)</label>
                            <input type="text" id="alias_os_cargo" class="form-control form-control-sm mt-1" maxlength="25" placeholder="Ej. Anticipo Brackets">
                        </div>
                        <div class="bento-card p-3 mb-2 border-0 shadow-sm">
                            <label class="kpi-label mb-1">Entrada Manual</label>
                            <div class="input-group input-group-sm">
                                <input type="text" id="manual_nombre" class="form-control" placeholder="Concepto (ej. Consulta General)">
                                <span class="input-group-text">\$</span>
                                <input type="number" id="manual_precio" class="form-control" style="max-width: 90px;" placeholder="0.00">
                                <button onclick="agregarCargoManual()" class="btn btn-primary px-3"><i class="bi bi-plus-lg"></i></button>
                            </div>
                        </div>
                        <div class="mb-2 position-relative">
                            <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-2 text-muted small"></i>
                            <input type="text" id="buscadorCatalogo" class="form-control form-control-sm ps-4 py-2 rounded-pill shadow-sm border-0" placeholder="Buscar en catálogo..." onkeyup="filtrarCatalogo()">
                        </div>
                        <div id="divCatalogo" class="row g-2 overflow-auto" style="max-height: 150px; padding: 2px;"></div>
                    </div>
                    <div class="col-lg-5">
                       <div class="bento-card p-3 border-0 shadow-md h-100 d-flex flex-column" style="background: #f8fafc;">
                          <h6 class="kpi-label text-primary mb-2">Resumen del Cargo</h6>
                          <div id="listaCarrito" class="flex-grow-1 d-flex flex-column gap-2 overflow-auto mb-2" style="max-height: 150px;"></div>
                          <div class="p-3 bg-white rounded-4 border shadow-sm mt-auto">
                             <div class="d-flex justify-content-between align-items-center mb-2">
                                <span class="small fw-bold text-muted">TOTAL CARGO</span>
                                <span class="h4 fw-bold text-primary m-0" id="carritoTotal">\$0.00</span>
                             </div>
                             <button class="btn btn-primary btn-sm w-100 py-2 fw-bold rounded-3 shadow" id="btnProcesarCargo" onclick="procesarCarrito()">PROCESAR CARGO</button>
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
                <div class="mb-3">
                    <label class="kpi-label">Alias / Referencia Corta (Opcional)</label>
                    <input type="text" id="alias_os_abono" class="form-control" maxlength="25" placeholder="Ej. Pago Quincenal">
                </div>
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

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script src="../js/estado_cuenta_spa.js?v=$^T"></script>
<script>
    document.addEventListener("DOMContentLoaded", () => { 
        initModuloFinanciero('$id_paciente', 'bento', '$session_data->{id_medico}'); 
    });
</script>
HTML
print <<HTML;
</body>
</html>
HTML
1;
