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
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();
my $id_paciente = $q->param('id') || '';
render_header(usuario => $session_data->{usuario}, titulo => "Finanzas - SDM", role => $session_data->{role}, id_medico => $session_data->{id_medico});
print <<HTML;
<div class="container py-4 px-2 px-md-4 animate__animated animate__fadeIn" style="max-width: 1200px; overflow-x: hidden;">
    
    <!-- Finanzas Header -->
    <div class="d-flex justify-content-between align-items-end mb-4 flex-wrap gap-3">
        <div>
            <h2 class="fw-bold plus-jakarta m-0" style="color: var(--md-text-primary);">Finanzas</h2>
            <p class="text-muted m-0">Control total de ingresos, facturación y cuentas por cobrar.</p>
        </div>
        <div class="d-flex align-items-center gap-2 flex-grow-1 justify-content-end" style="max-width: 400px;">
            <a href="estado_cuenta.pl" id="btnCargosAbonos" class="btn btn-primary rounded-pill fw-bold text-nowrap px-4 shadow-sm" style="display: none;"><i class="bi bi-cash-stack me-2"></i>Cargos y Abonos</a>
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
                <h4 class="fw-bold plus-jakarta mb-1" id="kpiIngresosTotales">\$0.00</h4>
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
                <h4 class="fw-bold plus-jakarta mb-1" id="kpiCuentasCobrar">\$0.00</h4>
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
                <h4 class="fw-bold plus-jakarta mb-1" id="kpiFacturacion">\$0.00</h4>
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

    <!-- Tabs -->
    <div class="d-flex gap-4 mb-4 border-bottom pb-2 overflow-auto" style="white-space: nowrap;">
        <a href="#" class="text-decoration-none fw-bold pb-2" style="color: var(--md-blue-deep); border-bottom: 3px solid var(--md-blue-deep);">Resumen</a>
        <a href="#" class="text-decoration-none fw-bold text-muted pb-2">Ingresos</a>
        <a href="#" class="text-decoration-none fw-bold text-muted pb-2">Gastos</a>
        <a href="#" class="text-decoration-none fw-bold text-muted pb-2">Cuentas por Cobrar</a>
        <a href="#" class="text-decoration-none fw-bold text-muted pb-2">Facturación</a>
        <a href="#" class="text-decoration-none fw-bold text-muted pb-2">Reportes</a>
    </div>

    <!-- Resumen View (Evolucion, Categoria) -->
    <div class="row g-4 mb-4">
        <!-- Evolución de Ingresos -->
        <div class="col-lg-7">
            <div class="bento-card border-0 shadow-sm bg-white h-100 p-4" style="border-radius: 20px;">
                <h6 class="fw-bold plus-jakarta mb-4 text-dark">Evolución de Ingresos</h6>
                <div style="height: 250px; width: 100%;">
                    <canvas id="lineEvolucionIngresos"></canvas>
                </div>
            </div>
        </div>
        
        <!-- Ingresos por Categoría (Dona) -->
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
                            <h5 class="fw-bold text-dark m-0 plus-jakarta" id="pieCenterVal" style="font-size: 1.1rem;">\$0</h5>
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

    <!-- Resumen de Ingresos (Table) -->
    <div class="bento-card border-0 shadow-sm bg-white p-4 mb-5" style="border-radius: 20px;">
        <h6 class="fw-bold plus-jakarta mb-4 text-dark">Resumen de Ingresos</h6>
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
            <button class="btn btn-sm btn-link text-decoration-none fw-bold" style="color: var(--md-blue-deep);">Ver todas las transacciones <i class="bi bi-chevron-right"></i></button>
        </div>
    </div>

</div>

<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.1/css/buttons.bootstrap5.min.css">
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
<script src="../js/estado_cuenta_spa.js?v=$^T"></script>
<script>
    document.addEventListener("DOMContentLoaded", () => { 
        initModuloFinanciero('', 'bento', '$session_data->{id_medico}'); 
    });
</script>
</body>
</html>
HTML
