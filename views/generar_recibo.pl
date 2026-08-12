#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use File::Spec;
use FindBin;
use JSON qw(encode_json);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};
my $usuario   = $sd->{usuario};
my $role      = $sd->{role};
my $id_medico = $sd->{id_medico} || '';
my $id_empresa = $sd->{id_empresa} || '';

binmode STDOUT, ":utf8";

# Restringir a roles permitidos (Recepcion, Medicos, Admins)
if ($role !~ /Recepcionista|Medico|Administrador/i) {
    print $q->redirect('inicial.pl');
    exit;
}

# 1. Leer SaaS Capabilities
my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $config_file = File::Spec->catfile($dat_dir, 'negocios_config.dat');
my %capacidades = ();
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line);
        if ($biz_id eq $id_empresa && $key eq 'CAPACIDAD') {
            $capacidades{$val} = 1;
        }
    }
    close($cf);
}
my $has_pacientes_estado = $capacidades{'Pacientes del Estado'} ? 1 : 0;

# 2. Cargar lista de médicos de la organización para el selector obligatorio
my $archivo_usuarios = File::Spec->catfile($dat_dir, 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '!');
my @medicos = ();
foreach my $r (@$regs) {
    next unless scalar(@$r) >= 7;
    my $m_id = $r->[0];
    my $m_nom = $r->[1];
    my $rol_u = $r->[5] // '';
    my $org_u = $r->[6] // '';
    if ($rol_u eq 'Medico' || $rol_u =~ /Especialista/i) {
        push @medicos, { id => $m_id, nombre => $m_nom };
    }
}

# 3. Render HTML
render_header(
    titulo => 'Caja Rápida',
    role => $role,
    usuario => $usuario,
    hide_search => 1
);

my $medicos_options = "<option value=''>-- Selecciona el Médico que atiende --</option>";
foreach my $m (@medicos) {
    my $sel = ($id_medico eq $m->{id}) ? "selected" : "";
    $medicos_options .= "<option value='$m->{id}' $sel>$m->{nombre}</option>";
}

print <<"HTML";
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme\@1.3.0/dist/select2-bootstrap-5-theme.min.css" />

<style>
    .wizard-step { display: none; }
    .wizard-step.active { display: block; animation: fadeIn 0.4s ease-in-out; }
    \@keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
    .cart-item { border-bottom: 1px solid #e2e8f0; padding: 0.75rem 0; }
    .cart-item:last-child { border-bottom: none; }
</style>

<main class="container-fluid pt-3 px-3 pb-5 animate__animated animate__fadeIn">
    
    <div class="row justify-content-center">
        <div class="col-12 col-lg-8">
            <div class="bento-card border-0 shadow-sm rounded-4">
                <div class="card-header bg-transparent border-0 pt-4 pb-0">
                    <h5 class="fw-bold mb-0" style="color: var(--md-blue-deep, #0A2A66);"><i class="bi bi-receipt-cutoff me-2" style="color: var(--md-cyan-ia, #18D1E6);"></i>Caja Rápida - Recibo Independiente</h5>
                    <p class="text-muted small">Genera comprobantes de pago sin necesidad de una cita programada.</p>
                </div>
                
                <div class="card-body">
                    
                    <!-- PASO 1: Captura -->
                    <div id="step1" class="wizard-step active">
                        <form id="frmCajaRapida" onsubmit="return false;">
                            
                            <!-- Selección del Paciente -->
                            <div class="mb-4">
                                <label class="form-label fw-bold small text-muted">1. Selecciona o Busca al Paciente</label>
HTML

if ($has_pacientes_estado) {
    print <<"HTML";
                                <div class="mb-3 d-flex gap-4">
                                    <div class="form-check">
                                        <input class="form-check-input" type="radio" name="tipoPaciente" id="tipoPrivado" value="privado" checked onchange="cambiarTipoPaciente()">
                                        <label class="form-check-label" for="tipoPrivado">Privado (General)</label>
                                    </div>
                                    <div class="form-check">
                                        <input class="form-check-input" type="radio" name="tipoPaciente" id="tipoEstado" value="estado" onchange="cambiarTipoPaciente()">
                                        <label class="form-check-label" for="tipoEstado">Pacientes del Estado</label>
                                    </div>
                                </div>
HTML
}

print <<"HTML";
                                <div id="contenedorPrivado">
                                    <select id="selPaciente" class="form-select fw-bold border-primary shadow-sm"></select>
                                    <div class="form-text">Si el paciente no existe, debe registrarse previamente en el Directorio.</div>
                                </div>
                                <div id="contenedorEstado" class="d-none mt-2">
                                    <div class="input-group mb-2">
                                        <input type="number" id="iptNumEmpleado" class="form-control fw-bold border-primary shadow-sm" placeholder="Ingresa el número de empleado">
                                        <button class="btn btn-primary shadow-sm" type="button" id="btnBuscarEmpleado" onclick="buscarEmpleadoEstado()"><i class="bi bi-search"></i> Buscar</button>
                                    </div>
                                    <div id="resultadosEmpleado" class="d-flex flex-column gap-2"></div>
                                </div>
                            </div>
                            
                            <!-- Selección del Médico -->
                            <div class="mb-4">
                                <label class="form-label fw-bold small text-muted">2. Médico Responsable (Para honorarios/comisiones)</label>
                                <select id="selMedico" class="form-select fw-bold border-primary shadow-sm" required>
                                    $medicos_options
                                </select>
                            </div>
                            
                            <!-- Conceptos / Carrito Universal -->
                            <div class="mb-4">
                                <label class="kpi-label mb-2">3. Conceptos a Cobrar</label>
                                <button type="button" class="btn btn-light border w-100 py-3 rounded-4 mb-3 d-flex flex-column align-items-center justify-content-center shadow-sm" onclick="$('#modalCargo').modal('show')" style="border-color: var(--md-gray-soft, #D9E2EC) !important;">
                                    <i class="bi bi-cart-plus fs-3 mb-1" style="color: var(--md-blue-deep, #0A2A66);"></i>
                                    <span class="fw-bold" style="color: var(--md-blue-deep, #0A2A66); font-family: 'Plus Jakarta Sans', sans-serif;">Abrir Carrito de Conceptos</span>
                                    <span class="small text-muted">Agrega desde catálogo o entrada manual</span>
                                </button>
                                
                                <!-- Resumen visual del carrito (sincronizado con el modal) -->
                                <div class="p-3 rounded-4" style="background: var(--md-white-clinical, #F8FBFF); border: 1px solid var(--md-gray-soft, #D9E2EC);">
                                    <div class="d-flex justify-content-between align-items-center mb-2 border-bottom pb-2">
                                        <span class="fw-bold" style="color: var(--md-text-secondary, #486581); font-family: 'Plus Jakarta Sans', sans-serif;"><i class="bi bi-receipt me-1"></i> Resumen de Cobro</span>
                                        <span class="fw-bold fs-5" id="cartTotalText" style="color: var(--md-blue-deep, #0A2A66);">\$0.00</span>
                                    </div>
                                    <div id="cartContainer" class="d-flex flex-column gap-2 overflow-auto" style="max-height: 150px;">
                                        <div class="text-center text-muted small py-2" id="cartEmpty">No hay conceptos agregados</div>
                                    </div>
                                </div>
                            </div>
                            
                            <!-- Método de Pago -->
                            <div class="mb-4">
                                <label class="form-label fw-bold small text-muted">4. Método de Pago</label>
                                <select id="selMetodoPago" class="form-select">
                                    <option value="Efectivo">Efectivo</option>
                                    <option value="Tarjeta de Debito">Tarjeta de Débito</option>
                                    <option value="Tarjeta de Credito">Tarjeta de Crédito</option>
                                    <option value="Transferencia">Transferencia (SPEI)</option>
                                    <option value="Convenio / Aseguradora">Convenio / Aseguradora</option>
                                    <option value="Cortesía">Cortesía (Sin cobro)</option>
                                </select>
                            </div>
                            
                            <hr class="my-4">
                            <div class="d-flex justify-content-end">
                                <button type="button" class="btn btn-primary px-4 fw-bold rounded-pill shadow-sm" onclick="irAlPaso2()">
                                    Siguiente: Vista Previa <i class="bi bi-arrow-right ms-1"></i>
                                </button>
                            </div>
                        </form>
                    </div>
                    
                    <!-- PASO 2: Vista Previa -->
                    <div id="step2" class="wizard-step">
                        <div class="alert alert-info border-0 shadow-sm d-flex align-items-center mb-4">
                            <i class="bi bi-info-circle-fill fs-4 me-3 text-info"></i>
                            <div>
                                <h6 class="fw-bold mb-1">Paso Final</h6>
                                <p class="mb-0 small">Revisa el comprobante. Una vez emitido, se registrará el ingreso en el sistema permanentemente.</p>
                            </div>
                        </div>
                        
                        <div class="border rounded-3 p-1 mb-4 bg-light" style="height: 400px;">
                            <iframe id="iframePreview" src="about:blank" style="width: 100%; height: 100%; border: none; background: #fff; border-radius: 6px;"></iframe>
                        </div>
                        
                        <div class="d-flex justify-content-between">
                            <button type="button" class="btn btn-light px-4 fw-bold rounded-pill" onclick="volverAlPaso1()">
                                <i class="bi bi-arrow-left me-1"></i> Volver
                            </button>
                            <button type="button" class="btn btn-success px-5 fw-bold rounded-pill shadow" onclick="emitirReciboFinal()">
                                <i class="bi bi-check2-circle me-1"></i> Emitir Recibo Oficial
                            </button>
                        </div>
                    </div>
                    
                </div>
            </div>
        </div>
    </div>
<!-- MODAL CARRITO UNIVERSAL -->
<div class="modal fade modal-diamond" id="modalCargo" tabindex="-1" aria-labelledby="modalCargoTitle" aria-hidden="true">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header" style="background: linear-gradient(135deg, var(--md-blue-deep, #0A2A66) 0%, #f59e0b 100%) !important;">
                <h5 class="modal-title font-secondary fw-bold text-white" id="modalCargoTitle">
                    <i class="bi bi-cart-plus me-2"></i>Conceptos del Recibo
                </h5>
                <button type="button" class="btn-close btn-close-white shadow-none" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body" style="background: var(--md-white-clinical, #F8FBFF);">
                <div class="row g-3">
                    <!-- Columna Izquierda: Catálogo -->
                    <div class="col-lg-7">
                        <!-- Entrada manual -->
                        <div class="bento-card p-3 mb-2" style="border-radius: 12px;">
                            <label class="kpi-label mb-2">Entrada Manual</label>
                            <div class="input-group input-group-sm">
                                <input type="text" id="manual_nombre" class="form-control" placeholder="Concepto (ej. Consulta General)" style="border-color: var(--md-gray-soft, #D9E2EC); font-family: 'Plus Jakarta Sans', sans-serif;">
                                <span class="input-group-text fw-bold" style="background: var(--md-white-clinical, #F8FBFF); border-color: var(--md-gray-soft, #D9E2EC); color: var(--md-blue-deep, #0A2A66);">\$</span>
                                <input type="number" id="manual_precio" class="form-control" style="max-width: 90px; border-color: var(--md-gray-soft, #D9E2EC);" placeholder="0.00" step="0.01" min="0">
                                <button onclick="agregarCargoManual()" class="btn btn-sm px-3 fw-bold" style="background: linear-gradient(135deg, var(--md-blue-deep, #0A2A66), var(--md-blue-medical, #124A9E)); color: white; border: none;">
                                    <i class="bi bi-plus-lg"></i>
                                </button>
                            </div>
                        </div>

                        <!-- Buscador catálogo -->
                        <div class="position-relative mb-2">
                            <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-3 small" style="color: var(--md-cyan-ia, #18D1E6);"></i>
                            <input type="text" id="buscadorCatalogo" class="form-control form-control-sm ps-4 py-2 rounded-pill border-0 shadow-sm" placeholder="Buscar en catálogo de servicios y productos..." style="background: white; font-family: 'Plus Jakarta Sans', sans-serif;" oninput="filtrarCatalogo()" onkeyup="filtrarCatalogo()">
                        </div>

                        <!-- Tabla catálogo -->
                        <div class="table-responsive shadow-sm" style="max-height: 300px; overflow-y: auto; border-radius: 10px; border: 1px solid var(--md-gray-soft, #D9E2EC);">
                            <table class="table table-hover table-sm align-middle mb-0" style="background: white;">
                                <thead style="background: var(--md-white-clinical, #F8FBFF); position: sticky; top: 0; z-index: 1;">
                                    <tr>
                                        <th class="ps-3 py-2" style="font-family: 'Plus Jakarta Sans', sans-serif; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: var(--md-text-secondary, #486581); border-bottom: 2px solid var(--md-gray-soft, #D9E2EC);">Concepto</th>
                                        <th class="text-end py-2" style="font-family: 'Plus Jakarta Sans', sans-serif; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: var(--md-text-secondary, #486581); border-bottom: 2px solid var(--md-gray-soft, #D9E2EC);">Precio</th>
                                        <th style="width: 60px; border-bottom: 2px solid var(--md-gray-soft, #D9E2EC);"></th>
                                    </tr>
                                </thead>
                                <tbody id="tablaCatalogo">
                                    <!-- AJAX rellena esto -->
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Columna Derecha: Carrito -->
                    <div class="col-lg-5">
                        <div class="bento-card p-3 h-100 d-flex flex-column" style="border-radius: 12px; background: white;">
                            <h6 class="fw-bold mb-2" style="font-family: 'Plus Jakarta Sans', sans-serif; color: var(--md-blue-deep, #0A2A66); font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.5px;">
                                <i class="bi bi-cart3 me-1" style="color: var(--md-cyan-ia, #18D1E6);"></i>Resumen del Cargo
                            </h6>
                            <div id="listaCarrito" class="flex-grow-1 d-flex flex-column gap-2 overflow-auto mb-3" style="max-height: 280px;"></div>
                            <div class="p-3 rounded-4 mt-auto" style="background: var(--md-white-clinical, #F8FBFF); border: 1px solid var(--md-gray-soft, #D9E2EC);">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <span class="kpi-label m-0" style="font-size: 0.7rem;">TOTAL</span>
                                    <span class="fw-bold m-0" id="carritoTotal" style="font-size: 1.5rem; font-family: 'Plus Jakarta Sans', sans-serif; color: var(--md-blue-deep, #0A2A66);">\$0.00</span>
                                </div>
                                <button class="btn btn-sm w-100 py-2 fw-bold rounded-3 shadow" id="btnProcesarCargo" onclick="$('#modalCargo').modal('hide')" style="background: linear-gradient(135deg, #059669 0%, #10b981 100%); color: white; border: none; font-family: 'Plus Jakarta Sans', sans-serif; letter-spacing: 0.3px; transition: all 0.3s ease;">
                                    <i class="bi bi-check-circle me-1"></i>CONFIRMAR CONCEPTOS
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

</main>
<script src="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/js/select2.min.js"></script>
HTML

print <<'JS';
<script>
    let cartItems = [];
    let catalogoMaster = [];
    
    $(document).ready(function() {
        initSelect2Paciente();
        cargarCatalogo();
    });

    let pacienteEstadoSeleccionado = { id: '', nombre: '' };

    function initSelect2Paciente() {
        if ($('#selPaciente').hasClass('select2-hidden-accessible')) {
            $('#selPaciente').select2('destroy');
        }
        $('#selPaciente').select2({
            theme: 'bootstrap-5',
            placeholder: '🔍 Escribe el nombre del paciente (Privado)...',
            minimumInputLength: 2,
            ajax: {
                url: '../api/autocomplete_pacientes.pl',
                dataType: 'json',
                delay: 350,
                data: function (params) { return { term: params.term }; },
                processResults: function (data) {
                    return { results: data.map(function(item) { return { id: item.id, text: item.label }; }) };
                }
            }
        });
    }

    function cambiarTipoPaciente() {
        let tipo = $('input[name="tipoPaciente"]:checked').val() || 'privado';
        if (tipo === 'estado') {
            $('#contenedorPrivado').addClass('d-none');
            $('#contenedorEstado').removeClass('d-none');
        } else {
            $('#contenedorEstado').addClass('d-none');
            $('#contenedorPrivado').removeClass('d-none');
        }
    }
    
    function buscarEmpleadoEstado() {
        const num = $('#iptNumEmpleado').val().trim();
        if(!num) return;
        $('#resultadosEmpleado').html('<div class="spinner-border text-primary spinner-border-sm"></div> Buscando...');
        $.ajax({
            url: '../api/buscar_familia_empleado.pl',
            method: 'POST',
            data: { num_empleado: num },
            success: function(res) {
                if(res.ok && res.resultados.length > 0) {
                    let html = '';
                    res.resultados.forEach((r, idx) => {
                        html += `
                        <div class="form-check border rounded p-2 ps-4 bg-white shadow-sm">
                            <input class="form-check-input" type="radio" name="pacienteEstadoRad" id="radEst_${idx}" value="${r.nombre}" onchange="seleccionarPacienteEstado('${r.id}', '${r.nombre.replace(/'/g, "&apos;")}')">
                            <label class="form-check-label w-100" for="radEst_${idx}" style="cursor: pointer;">
                                <strong>${r.nombre}</strong> <span class="badge bg-secondary ms-2">${r.relacion}</span>
                            </label>
                        </div>`;
                    });
                    $('#resultadosEmpleado').html(html);
                } else {
                    $('#resultadosEmpleado').html('<div class="alert alert-warning py-2 small m-0">No se encontraron resultados para el número de empleado ingresado.</div>');
                }
            },
            error: function() {
                $('#resultadosEmpleado').html('<div class="alert alert-danger py-2 small m-0">Error de conexión al buscar.</div>');
            }
        });
    }

    function seleccionarPacienteEstado(id, nombre) {
        pacienteEstadoSeleccionado = { id: id, nombre: nombre };
    }
    
    async function cargarCatalogo() {
        try {
            const req = await fetch('../api/catalogo_org_api.pl?accion=get_catalogo_org');
            const res = await req.json();
            if(res.status === 'ok') {
                catalogoMaster = [...(res.servicios || []), ...(res.productos || [])];
            } else {
                catalogoMaster = [];
            }
            filtrarCatalogo();
        } catch(e) {
            console.error("Error al cargar catálogo:", e);
        }
    }

    function formatCurrency(val) {
        return new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(val);
    }

    function filtrarCatalogo() {
        const term = $('#buscadorCatalogo').val().toLowerCase();
        const tbody = document.getElementById('tablaCatalogo');
        if(!tbody) return;
        
        let filtered = catalogoMaster.filter(c => c.nombre.toLowerCase().includes(term) || (c.id && String(c.id).toLowerCase().includes(term)));
        filtered = filtered.slice(0, 30); // max 30
        
        let html = '';
        filtered.forEach(c => {
            let precio = parseFloat(c.precio) || 0;
            let claveText = c.id ? `Clave: ${c.id}` : '';
            html += `
            <tr>
                <td class="ps-3 py-2">
                    <div class="fw-bold" style="color: var(--md-blue-deep, #0A2A66); font-size: 0.8rem;">${c.nombre}</div>
                    <div class="text-muted" style="font-size: 0.7rem;">${claveText}</div>
                </td>
                <td class="text-end py-2 fw-bold" style="color: var(--md-text-secondary, #486581); font-size: 0.85rem;">
                    ${formatCurrency(precio)}
                </td>
                <td class="text-center py-2">
                    <button class="btn btn-sm btn-light border shadow-sm rounded-circle p-1" onclick="addConceptoCatalogo('${c.id}', '${c.nombre.replace(/'/g, "&apos;")}', ${precio})" style="width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; color: var(--md-blue-medical, #124A9E);">
                        <i class="bi bi-plus"></i>
                    </button>
                </td>
            </tr>`;
        });
        tbody.innerHTML = html;
    }

    function agregarCargoManual() {
        const nombre = $('#manual_nombre').val().trim();
        const precio = parseFloat($('#manual_precio').val());
        if(!nombre || isNaN(precio) || precio < 0) {
            Swal.fire('Error', 'Ingresa un concepto y un precio válido.', 'error');
            return;
        }
        cartItems.push({ id: Date.now(), nombre: nombre, precio: precio, cantidad: 1 });
        $('#manual_nombre').val('');
        $('#manual_precio').val('');
        renderCart();
    }

    function addConceptoCatalogo(id, nombre, precio) {
        let ex = cartItems.find(i => i.nombre === nombre);
        if (ex) {
            ex.cantidad++;
        } else {
            cartItems.push({ id: Date.now() + Math.random(), nombre: nombre, precio: precio, cantidad: 1 });
        }
        renderCart();
    }
    
    function removeConcepto(id) {
        cartItems = cartItems.filter(item => item.id != id);
        renderCart();
    }

    function updateCantidad(id, delta) {
        let ex = cartItems.find(i => i.id == id);
        if (ex) {
            ex.cantidad += delta;
            if (ex.cantidad < 1) ex.cantidad = 1;
            renderCart();
        }
    }
    
    function renderCart() {
        const cModal = $('#listaCarrito');
        const cMain = $('#cartContainer');
        
        if (cartItems.length === 0) {
            let emptyHtml = '<div class="text-center text-muted small py-4" id="cartEmpty"><i class="bi bi-cart-x fs-2 d-block mb-2 text-black-50"></i>No hay conceptos agregados</div>';
            cModal.html(emptyHtml);
            cMain.html(emptyHtml);
            $('#carritoTotal').text('$0.00');
            $('#cartTotalText').text('$0.00');
            return;
        }
        
        let htmlModal = '';
        let htmlMain = '';
        let total = 0;
        
        cartItems.forEach(item => {
            const sub = item.precio * item.cantidad;
            total += sub;
            
            // Modal
            htmlModal += `
                <div class="d-flex justify-content-between align-items-center p-2 rounded-3 mb-2 shadow-sm" style="background: white; border: 1px solid var(--md-gray-soft, #D9E2EC);">
                    <div class="me-2" style="flex: 1; min-width: 0;">
                        <div class="fw-bold text-truncate" style="font-size: 0.8rem; color: var(--md-blue-deep, #0A2A66);">${item.nombre}</div>
                        <div class="text-muted" style="font-size: 0.7rem;">${formatCurrency(item.precio)} c/u</div>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <div class="input-group input-group-sm" style="width: 75px;">
                            <button class="btn btn-outline-secondary px-1 py-0" type="button" onclick="updateCantidad('${item.id}', -1)">-</button>
                            <input type="text" class="form-control text-center p-0" value="${item.cantidad}" readonly style="font-size: 0.75rem;">
                            <button class="btn btn-outline-secondary px-1 py-0" type="button" onclick="updateCantidad('${item.id}', 1)">+</button>
                        </div>
                        <span class="fw-bold" style="font-size: 0.85rem; color: var(--md-blue-deep, #0A2A66); width: 60px; text-align: right;">${formatCurrency(sub)}</span>
                        <button class="btn btn-sm text-danger p-1 border-0" onclick="removeConcepto('${item.id}')"><i class="bi bi-trash"></i></button>
                    </div>
                </div>
            `;
            
            // Main view
            htmlMain += `
                <div class="d-flex justify-content-between align-items-center p-2 rounded-3 mb-1 bg-white border" style="border-color: var(--md-gray-soft, #D9E2EC) !important;">
                    <div>
                        <div class="fw-bold" style="font-size: 0.8rem; color: var(--md-blue-deep, #0A2A66);">${item.nombre}</div>
                        <div class="text-muted" style="font-size: 0.7rem;">${item.cantidad} x ${formatCurrency(item.precio)}</div>
                    </div>
                    <div class="fw-bold text-success" style="font-size: 0.85rem;">
                        ${formatCurrency(sub)}
                    </div>
                </div>
            `;
        });
        
        cModal.html(htmlModal);
        cMain.html(htmlMain);
        
        let totalFmt = formatCurrency(total);
        $('#carritoTotal').text(totalFmt);
        $('#cartTotalText').text(totalFmt);
    }
    
    async function irAlPaso2() {
        let tipo = $('input[name="tipoPaciente"]:checked').val() || 'privado';
        let id_paciente = '';
        let name_paciente = '';
        
        if (tipo === 'estado') {
            id_paciente = pacienteEstadoSeleccionado.id ? "EMP-" + pacienteEstadoSeleccionado.id : '';
            name_paciente = pacienteEstadoSeleccionado.nombre;
        } else {
            id_paciente = $('#selPaciente').val();
            name_paciente = $('#selPaciente option:selected').text();
        }
        
        const id_medico = $('#selMedico').val();
        
        if (!id_paciente) {
            return Swal.fire('Atención', 'Debes seleccionar un Paciente o registrarlo previamente.', 'warning');
        }
        if (!id_medico) {
            return Swal.fire('Atención', 'Debes seleccionar al Médico responsable.', 'warning');
        }
        if (cartItems.length === 0) {
            return Swal.fire('Atención', 'Agrega al menos un concepto a cobrar en el carrito.', 'warning');
        }
        
        const total = cartItems.reduce((acc, it) => acc + (it.precio * it.cantidad), 0);
        const metodo = $('#selMetodoPago').val();
        
        const fechaHtml = new Date().toLocaleDateString('es-MX', { year:'numeric', month:'short', day:'numeric' });
        let draftHtml = `
        <!DOCTYPE html><html><head><style>body { font-family: 'Inter', sans-serif; padding: 20px; color: #333; } .banner { background: #f59e0b; color: white; text-align: center; padding: 5px; font-weight: bold; font-size: 12px; margin-bottom: 20px; border-radius: 4px; }</style></head><body>
            <div class="banner">VISTA PREVIA DE RECIBO (BORRADOR)</div>
            <h2 style="margin:0 0 5px 0;">Recibo de Caja</h2>
            <p style="margin:0; color:#666;">Fecha: ${fechaHtml} | Método: ${metodo}</p>
            <p style="margin:15px 0; font-size:14px;"><strong>Paciente:</strong> ${name_paciente}<br><strong>Médico:</strong> ${$('#selMedico option:selected').text()}</p>
            <table style="width:100%; border-collapse:collapse; margin-top:20px; font-size:13px;">
                <tr style="background:#f1f5f9;"><th style="padding:8px;text-align:left;">Concepto</th><th style="padding:8px;text-align:center;">Cant.</th><th style="padding:8px;text-align:right;">Subtotal</th></tr>
        `;
        cartItems.forEach(it => {
            const s = it.precio * it.cantidad;
            draftHtml += `<tr><td style="padding:8px; border-bottom:1px solid #e2e8f0;">${it.nombre}</td><td style="padding:8px; border-bottom:1px solid #e2e8f0; text-align:center;">${it.cantidad}</td><td style="padding:8px; border-bottom:1px solid #e2e8f0; text-align:right;">${formatCurrency(s)}</td></tr>`;
        });
        draftHtml += `<tr><td colspan="2" style="padding:8px;text-align:right;font-weight:bold;font-size:16px;">TOTAL PAGADO:</td><td style="padding:8px;text-align:right;font-weight:bold;font-size:16px;color:#10b981;">${formatCurrency(total)}</td></tr>`;
        draftHtml += `</table></body></html>`;
        
        const doc = document.getElementById('iframePreview').contentWindow.document;
        doc.open(); doc.write(draftHtml); doc.close();
        
        $('#step1').removeClass('active');
        $('#step2').addClass('active');
    }
    
    function volverAlPaso1() {
        $('#step2').removeClass('active');
        $('#step1').addClass('active');
    }
    
    async function emitirReciboFinal() {
        let tipo = $('input[name="tipoPaciente"]:checked').val() || 'privado';
        let id_paciente = '';
        let name_paciente = '';
        
        if (tipo === 'estado') {
            id_paciente = pacienteEstadoSeleccionado.id ? "EMP-" + pacienteEstadoSeleccionado.id : '';
            name_paciente = pacienteEstadoSeleccionado.nombre;
        } else {
            id_paciente = $('#selPaciente').val();
            name_paciente = $('#selPaciente option:selected').text();
        }
        
        const id_medico = $('#selMedico').val();
        const metodo = $('#selMetodoPago').val();
        const total = cartItems.reduce((acc, it) => acc + (it.precio * it.cantidad), 0);
        
        CrystalToast.fire({ icon: 'info', title: 'Emitiendo recibo, un momento...' });
        
        try {
            const form = new URLSearchParams();
            form.append('id_paciente', id_paciente);
            form.append('nombre_paciente_empleado', name_paciente);
            form.append('id_medico', id_medico);
            form.append('caja_items_json', JSON.stringify(cartItems));
            form.append('caja_metodo_pago', metodo);
            form.append('caja_monto_abono', total);
            
            const req = await fetch('../api/guardar_recibo_rapido.pl', {
                method: 'POST',
                body: form
            });
            const res = await req.json();
            
            if (res.ok) {
                Swal.fire({
                    icon: 'success',
                    title: '¡Recibo Emitido!',
                    text: 'El ingreso ha sido registrado exitosamente en caja.',
                    confirmButtonText: 'Abrir PDF'
                }).then(() => {
                    window.open('../api/imprimir_recibo_caja.pl?id_consulta=' + encodeURIComponent(res.id_tratamiento), '_blank');
                    cartItems = [];
                    renderCart();
                    $('#selPaciente').val(null).trigger('change');
                    if ($('#selPacienteEstado').length) $('#selPacienteEstado').val(null).trigger('change');
                    volverAlPaso1();
                });
            } else {
                Swal.fire('Error', res.msg || 'No se pudo generar el recibo.', 'error');
            }
        } catch (e) {
            Swal.fire('Error', 'Falla de red.', 'error');
        }
    }
</script>
JS

render_bottom_nav('finanzas');
print "</body></html>\n";
1;
