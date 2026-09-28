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

unless ($sd->{session_ok}) {
    print $q->redirect('../index.html');
    exit;
}

# 1. Cargar Médicos / Profesionales de la Organización
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my @medicos = ();
if (-e $archivo_usuarios && open(my $fh_u, '<:encoding(UTF-8)', $archivo_usuarios)) {
    my $cnt = 0;
    while (my $line = <$fh_u>) {
        $cnt++;
        chomp $line;
        next if $cnt == 1 || $line =~ /^\s*$/;
        my @f = split(/!/, $line);
        my $u_id   = $f[0] // '';
        my $u_nom  = $f[1] // '';
        my $u_rol  = $f[5] // '';
        my $u_emp  = $f[6] // '';
        if ($u_rol =~ /Medico|Especialista/i && (!$id_empresa || $u_emp eq $id_empresa)) {
            push @medicos, { id => $u_id, nombre => $u_nom };
        }
    }
    close($fh_u);
}
@medicos = sort { $a->{nombre} cmp $b->{nombre} } @medicos;

# 2. Cargar Pacientes para Selector Rápido
my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my @pacientes = ();
if (-e $archivo_pacientes && open(my $fh_p, '<:encoding(UTF-8)', $archivo_pacientes)) {
    my $cnt = 0;
    while (my $line = <$fh_p>) {
        $cnt++;
        chomp $line;
        next if $cnt == 1 || $line =~ /^\s*$/;
        my @f = split(/\|/, $line);
        my $p_id = $f[0] // '';
        my $p_nom = join(' ', grep { $_ ne '' } ($f[1]//'', $f[2]//'', $f[3]//''));
        push @pacientes, { id => $p_id, nombre => $p_nom } if $p_id;
    }
    close($fh_p);
}
@pacientes = sort { $a->{nombre} cmp $b->{nombre} } @pacientes;

# Renderizar Cabecera
utils::sub_header::render_sub_header(
    title => 'Caja Consultorio / Punto de Venta',
    page_title => 'Caja - OSPulso',
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    skip_header => 0
);

# Renderizar Menú Lateral
utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    pagina_actual => 'caja_consultorio'
);

print <<HTML;
<div class="content-wrapper container-fluid px-3 px-md-4 py-3 container-mobile-flush">
    <!-- Header del Módulo -->
    <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center mb-4 gap-3">
        <div>
            <h3 class="fw-black text-navy mb-1" style="color: var(--md-blue-deep, #0A2A66);">
                <i class="bi bi-cart-check-fill me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>Caja Consultorio
            </h3>
            <p class="text-muted small mb-0">Cobro ágil de servicios y productos con carrito reactivo y emisión inmediata de recibo.</p>
        </div>
        <div class="d-flex align-items-center gap-2">
            <span class="badge rounded-pill px-3 py-2 fw-bold" style="background-color: #f0fdfa; color: #0f766e; border: 1px solid #99f6e4;">
                <i class="bi bi-shield-check me-1"></i>Flujo Privado Directo
            </span>
        </div>
    </div>

    <!-- Grid Principal de Caja -->
    <div class="row g-4">
        <!-- Columna Izquierda: Selección de Paciente y Catálogo -->
        <div class="col-lg-7 col-xl-7">
            <!-- 1. Datos del Cliente / Paciente -->
            <div class="card card-acrilico border-0 shadow-sm rounded-4 p-3 p-md-4 mb-4 card-mobile-flush" style="border: 1px solid rgba(25, 183, 165, 0.3) !important;">
                <div class="d-flex justify-content-between align-items-center mb-3">
                    <h5 class="fw-bold text-navy mb-0" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                        <i class="bi bi-person-badge me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>1. Paciente y Médico Tratante
                    </h5>
                    <div class="form-check form-switch m-0">
                        <input class="form-check-input" type="checkbox" id="chk_publico_general" onchange="togglePublicoGeneral(this.checked)" checked>
                        <label class="form-check-label small fw-bold text-muted" for="chk_publico_general">Público General</label>
                    </div>
                </div>

                <div class="row g-3">
                    <!-- Selector de Paciente -->
                    <div class="col-md-7" id="div_selector_paciente" style="display: none;">
                        <label class="form-label small fw-bold text-muted text-uppercase">Paciente Registrado</label>
                        <select id="sel_paciente" class="form-select fw-bold rounded-3" onchange="seleccionarPacienteRegistrado()">
                            <option value="">-- Seleccionar Paciente --</option>
HTML

foreach my $p (@pacientes) {
    print qq{<option value="$p->{id}">$p->{nombre} ($p->{id})</option>\n};
}

print <<HTML;
                        </select>
                    </div>

                    <!-- Input Nombre Walk-in / Público General -->
                    <div class="col-md-7" id="div_nombre_general">
                        <label class="form-label small fw-bold text-muted text-uppercase">Nombre del Cliente / Paciente</label>
                        <div class="input-group">
                            <span class="input-group-text bg-white border-end-0"><i class="bi bi-person text-muted"></i></span>
                            <input type="text" id="txt_nombre_paciente" class="form-control fw-bold border-start-0" value="Público General" placeholder="Nombre completo">
                        </div>
                    </div>

                    <!-- Médico Tratante -->
                    <div class="col-md-5">
                        <label class="form-label small fw-bold text-muted text-uppercase">Médico que Realiza</label>
                        <select id="sel_medico" class="form-select fw-bold rounded-3">
HTML

foreach my $m (@medicos) {
    my $sel = ($m->{id} eq $id_medico) ? 'selected' : '';
    print qq{<option value="$m->{id}" $sel>$m->{nombre}</option>\n};
}

print <<HTML;
                        </select>
                    </div>
                </div>
            </div>

            <!-- 2. Catálogo de Servicios y Productos -->
            <div class="card card-acrilico border-0 shadow-sm rounded-4 p-3 p-md-4 card-mobile-flush" style="border: 1px solid rgba(25, 183, 165, 0.3) !important;">
                <h5 class="fw-bold text-navy mb-3" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                    <i class="bi bi-grid-3x3-gap-fill me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>2. Catálogo de Servicios y Productos
                </h5>

                <!-- Entrada Manual Rápida -->
                <div class="p-3 mb-3 rounded-3" style="background-color: #f8fafc; border: 1px dashed #cbd5e1;">
                    <label class="small fw-bold text-muted text-uppercase mb-2 d-block">
                        <i class="bi bi-pencil-square me-1 text-primary"></i>Entrada Manual Rápida (Concepto Libre)
                    </label>
                    <div class="input-group">
                        <input type="text" id="manual_concepto" class="form-control" placeholder="Concepto (ej. Consulta Especializada, Procedimiento)">
                        <span class="input-group-text fw-bold">\$</span>
                        <input type="number" id="manual_precio" class="form-control text-end fw-bold" style="max-width: 120px;" placeholder="0.00" step="0.01" min="0">
                        <button type="button" class="btn btn-primary fw-bold px-3 btn-mobile-standard" onclick="agregarManual()">
                            <i class="bi bi-plus-lg me-1"></i>Agregar
                        </button>
                    </div>
                </div>

                <!-- Buscador de Catálogo -->
                <div class="position-relative mb-3">
                    <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-3 text-muted"></i>
                    <input type="text" id="txt_buscar_catalogo" class="form-control ps-5 rounded-pill shadow-sm" placeholder="Buscar servicio o producto en el catálogo..." oninput="filtrarCatalogo(this.value)">
                </div>

                <!-- Tabla de Resultados del Catálogo -->
                <div class="table-responsive shadow-sm rounded-3" style="max-height: 280px; overflow-y: auto; border: 1px solid #e2e8f0; background: #ffffff;">
                    <table class="table table-hover align-middle mb-0">
                        <thead style="background-color: #0A2A66; color: #ffffff; position: sticky; top: 0; z-index: 2;">
                            <tr>
                                <th class="ps-3 py-2 small fw-bold text-uppercase">Concepto / Servicio</th>
                                <th class="text-end py-2 small fw-bold text-uppercase">Precio Unit.</th>
                                <th class="text-center py-2" style="width: 70px;">Acción</th>
                            </tr>
                        </thead>
                        <tbody id="tbody_catalogo">
                            <tr>
                                <td colspan="3" class="text-center text-muted py-4">
                                    <div class="spinner-border spinner-border-sm text-primary me-2"></div>Cargando catálogo institucional...
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- Columna Derecha: Resumen de Venta / Carrito Reactivo -->
        <div class="col-lg-5 col-xl-5">
            <div class="card card-acrilico border-0 shadow-sm rounded-4 p-3 p-md-4 card-mobile-flush h-100 d-flex flex-column" style="border: 2px solid var(--md-teal-clinical, #19B7A5) !important;">
                <div class="d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom">
                    <h5 class="fw-black text-navy mb-0" style="color: var(--md-blue-deep, #0A2A66);">
                        <i class="bi bi-cart3 me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>Resumen de la Venta
                    </h5>
                    <button type="button" class="btn btn-sm btn-outline-danger rounded-pill fw-bold" onclick="limpiarCarrito()" title="Vaciar Carrito">
                        <i class="bi bi-trash3 me-1"></i>Vaciar
                    </button>
                </div>

                <!-- Lista de Ítems en Carrito -->
                <div id="contenedor_items_carrito" class="flex-grow-1 overflow-auto mb-3 pe-1" style="min-height: 180px; max-height: 280px;">
                    <div class="text-center text-muted py-5 opacity-75">
                        <i class="bi bi-cart-x fs-1 mb-2 d-block text-secondary"></i>
                        <h6 class="fw-bold">El carrito está vacío</h6>
                        <p class="small m-0">Agrega servicios o conceptos del catálogo para cobrar.</p>
                    </div>
                </div>

                <!-- Desglose de Totales -->
                <div class="p-3 rounded-4 bg-light border mb-3">
                    <div class="d-flex justify-content-between align-items-center mb-1">
                        <span class="text-muted fw-bold small text-uppercase">Subtotal</span>
                        <span class="fw-bold text-dark fs-5" id="lbl_subtotal">\$0.00</span>
                    </div>
                    <div class="d-flex justify-content-between align-items-center pt-2 border-top">
                        <span class="text-navy fw-black text-uppercase" style="letter-spacing: 0.5px;">TOTAL A PAGAR</span>
                        <span class="fw-black fs-3 text-navy" id="lbl_total" style="color: var(--md-blue-deep, #0A2A66);">\$0.00</span>
                    </div>
                </div>

                <!-- Formulario de Liquidación y Pago -->
                <div class="row g-2 mb-3">
                    <div class="col-6">
                        <label class="form-label small fw-bold text-muted text-uppercase mb-1">Método de Pago</label>
                        <select id="sel_metodo_pago" class="form-select fw-bold rounded-3">
                            <option value="Efectivo" selected>Efectivo</option>
                            <option value="Tarjeta">Tarjeta Débito/Crédito</option>
                            <option value="Transferencia">Transferencia Bancaria</option>
                        </select>
                    </div>
                    <div class="col-6">
                        <label class="form-label small fw-bold text-muted text-uppercase mb-1">Tipo de Pago</label>
                        <select id="sel_tipo_pago" class="form-select fw-bold rounded-3" onchange="toggleTipoPago(this.value)">
                            <option value="Liquidar" selected>Liquidar (100%)</option>
                            <option value="Abonar">Abono Parcial</option>
                        </select>
                    </div>
                    <div class="col-12" id="div_monto_abono" style="display: none;">
                        <label class="form-label small fw-bold text-warning text-uppercase mb-1">Monto del Abono (\$)</label>
                        <div class="input-group">
                            <span class="input-group-text fw-bold">\$</span>
                            <input type="number" id="txt_monto_abono" class="form-control fw-bold" step="0.01" min="0" placeholder="0.00">
                        </div>
                    </div>
                    <div class="col-12">
                        <label class="form-label small fw-bold text-muted text-uppercase mb-1">Concepto / Notas del Recibo</label>
                        <input type="text" id="txt_concepto_recibo" class="form-control form-control-sm rounded-3" placeholder="Ej. Consulta de seguimiento, Procedimiento menor">
                    </div>
                </div>

                <!-- Botón de Cobro Principal -->
                <button type="button" id="btn_procesar_cobro" class="btn btn-warning w-100 py-3 fw-bold fs-5 text-white rounded-pill shadow-sm btn-mobile-standard" onclick="procesarCobroCaja()" style="background: linear-gradient(135deg, var(--md-teal-clinical, #19B7A5), var(--md-blue-deep, #0A2A66)); border: none;">
                    <i class="bi bi-receipt me-2"></i>COBRAR Y GENERAR RECIBO
                </button>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
HTML

print <<'JS';
<script>
    let catalogoMaster = [];
    let carrito = [];

    document.addEventListener('DOMContentLoaded', function() {
        cargarCatalogo();
    });

    async function cargarCatalogo() {
        try {
            const res = await fetch('../api/estado_cuenta_api.pl', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams({ accion: 'get_catalogo' })
            });
            const data = await res.json();
            catalogoMaster = [];

            if (data.is_universal && data.catalogo) {
                (data.catalogo.items || []).forEach(function(c) {
                    let pObj = (c.precios || []).find(p => p.tipo_tarifa === 'ESTANDAR') || (c.precios || [])[0];
                    let precio = pObj ? parseFloat(pObj.precio_publico || 0) : 0;
                    catalogoMaster.push({ id: c.id_item, nombre: c.concepto || c.nombre, precio: precio });
                });
                (data.catalogo.productos || []).forEach(function(p) {
                    catalogoMaster.push({ id: p.id_prod, nombre: p.nombre, precio: parseFloat(p.precio) || 0 });
                });
            } else {
                catalogoMaster = [...(data.servicios || []), ...(data.productos || [])];
            }
        } catch(e) {
            console.error("Error al cargar catálogo:", e);
            catalogoMaster = [];
        }
        renderCatalogo('');
    }

    function renderCatalogo(filtro = '') {
        const tbody = document.getElementById('tbody_catalogo');
        if (!tbody) return;

        const f = filtro.toLowerCase().trim();
        const items = catalogoMaster.filter(it => (it.nombre || '').toLowerCase().includes(f));

        if (items.length === 0) {
            tbody.innerHTML = '<tr><td colspan="3" class="text-center text-muted py-3">No se encontraron conceptos.</td></tr>';
            return;
        }

        let html = '';
        items.forEach(it => {
            const idEsc = encodeURIComponent(it.id || it.nombre);
            const nomEsc = encodeURIComponent(it.nombre || '');
            html += `
                <tr style="cursor: pointer;" onclick="agregarAlCarrito('${idEsc}', '${nomEsc}', ${it.precio})">
                    <td class="ps-3 py-2 fw-bold text-dark small text-truncate" style="max-width: 280px;">${it.nombre}</td>
                    <td class="text-end py-2 text-primary fw-bold small">\$${parseFloat(it.precio || 0).toFixed(2)}</td>
                    <td class="text-center py-2">
                        <button type="button" class="btn btn-sm btn-outline-primary rounded-circle p-1 d-inline-flex align-items-center justify-content-center" style="width: 28px; height: 28px;">
                            <i class="bi bi-plus-lg"></i>
                        </button>
                    </td>
                </tr>
            `;
        });
        tbody.innerHTML = html;
    }

    function filtrarCatalogo(val) {
        renderCatalogo(val);
    }

    function agregarManual() {
        const cEl = document.getElementById('manual_concepto');
        const pEl = document.getElementById('manual_precio');
        const concepto = cEl.value.trim();
        const precio = parseFloat(pEl.value);

        if (!concepto) {
            Swal.fire('Aviso', 'Ingresa la descripción del concepto.', 'info');
            return;
        }
        if (isNaN(precio) || precio < 0) {
            Swal.fire('Aviso', 'Ingresa un precio válido mayor o igual a 0.', 'warning');
            return;
        }

        agregarAlCarrito('MAN-' + Date.now(), encodeURIComponent(concepto), precio);
        cEl.value = '';
        pEl.value = '';
    }

    function agregarAlCarrito(idRaw, nombreRaw, precio) {
        const nombre = decodeURIComponent(nombreRaw);
        const idx = carrito.findIndex(i => i.nombre === nombre && Math.abs(i.precio - precio) < 0.001);
        if (idx !== -1) {
            carrito[idx].cantidad += 1;
            carrito[idx].subtotal = carrito[idx].cantidad * carrito[idx].precio;
        } else {
            carrito.push({
                id: decodeURIComponent(idRaw),
                nombre: nombre,
                precio: parseFloat(precio || 0),
                cantidad: 1,
                subtotal: parseFloat(precio || 0)
            });
        }
        renderCarrito();
    }

    function cambiarCantidad(idx, delta) {
        if (!carrito[idx]) return;
        carrito[idx].cantidad += delta;
        if (carrito[idx].cantidad <= 0) {
            carrito.splice(idx, 1);
        } else {
            carrito[idx].subtotal = carrito[idx].cantidad * carrito[idx].precio;
        }
        renderCarrito();
    }

    function eliminarItem(idx) {
        if (!carrito[idx]) return;
        carrito.splice(idx, 1);
        renderCarrito();
    }

    function limpiarCarrito() {
        if (carrito.length === 0) return;
        carrito = [];
        renderCarrito();
    }

    function renderCarrito() {
        const cont = document.getElementById('contenedor_items_carrito');
        const lblSubtotal = document.getElementById('lbl_subtotal');
        const lblTotal = document.getElementById('lbl_total');

        if (!cont) return;

        if (carrito.length === 0) {
            cont.innerHTML = `
                <div class="text-center text-muted py-5 opacity-75">
                    <i class="bi bi-cart-x fs-1 mb-2 d-block text-secondary"></i>
                    <h6 class="fw-bold">El carrito está vacío</h6>
                    <p class="small m-0">Agrega servicios o conceptos del catálogo para cobrar.</p>
                </div>
            `;
            lblSubtotal.innerText = '$0.00';
            lblTotal.innerText = '$0.00';
            return;
        }

        let total = 0;
        let html = '<div class="list-group list-group-flush">';
        carrito.forEach((it, idx) => {
            total += it.subtotal;
            html += `
                <div class="list-group-item px-2 py-2 d-flex justify-content-between align-items-center bg-transparent border-bottom">
                    <div class="me-2" style="max-width: 55%;">
                        <div class="fw-bold text-dark small text-truncate" title="${it.nombre}">${it.nombre}</div>
                        <div class="text-muted small">\$${it.precio.toFixed(2)} c/u</div>
                    </div>
                    <div class="d-flex align-items-center gap-1">
                        <button type="button" class="btn btn-sm btn-light border p-0 rounded-circle" style="width: 24px; height: 24px;" onclick="cambiarCantidad(${idx}, -1)">-</button>
                        <span class="fw-bold px-1 small">${it.cantidad}</span>
                        <button type="button" class="btn btn-sm btn-light border p-0 rounded-circle" style="width: 24px; height: 24px;" onclick="cambiarCantidad(${idx}, 1)">+</button>
                        <span class="fw-black text-navy ms-2 small" style="min-width: 60px; text-align: right;">\$${it.subtotal.toFixed(2)}</span>
                        <button type="button" class="btn btn-sm text-danger p-0 ms-1" onclick="eliminarItem(${idx})" title="Eliminar"><i class="bi bi-x-circle-fill"></i></button>
                    </div>
                </div>
            `;
        });
        html += '</div>';
        cont.innerHTML = html;

        lblSubtotal.innerText = '$' + total.toFixed(2);
        lblTotal.innerText = '$' + total.toFixed(2);
    }

    function togglePublicoGeneral(esPublico) {
        const divGen = document.getElementById('div_nombre_general');
        const divSel = document.getElementById('div_selector_paciente');
        const txtNom = document.getElementById('txt_nombre_paciente');

        if (esPublico) {
            divGen.style.display = 'block';
            divSel.style.display = 'none';
            txtNom.value = 'Público General';
            txtNom.readOnly = false;
        } else {
            divGen.style.display = 'block';
            divSel.style.display = 'block';
            txtNom.value = '';
            txtNom.readOnly = true;
            document.getElementById('sel_paciente').value = '';
        }
    }

    function seleccionarPacienteRegistrado() {
        const sel = document.getElementById('sel_paciente');
        const txtNom = document.getElementById('txt_nombre_paciente');
        if (sel.selectedIndex > 0) {
            txtNom.value = sel.options[sel.selectedIndex].text.replace(/\s*\(.*?\)$/, '');
        } else {
            txtNom.value = '';
        }
    }

    function toggleTipoPago(val) {
        const divAbono = document.getElementById('div_monto_abono');
        if (val === 'Abonar') {
            divAbono.style.display = 'block';
        } else {
            divAbono.style.display = 'none';
        }
    }

    async function procesarCobroCaja() {
        if (carrito.length === 0) {
            Swal.fire('Carrito Vacío', 'Agrega al menos un servicio o concepto a la venta.', 'warning');
            return;
        }

        const esPublico = document.getElementById('chk_publico_general').checked;
        let idPaciente = esPublico ? 'PAC-GENERICO' : document.getElementById('sel_paciente').value;
        const nombrePaciente = document.getElementById('txt_nombre_paciente').value.trim() || 'Público General';
        const idMedico = document.getElementById('sel_medico').value || '';
        const metodoPago = document.getElementById('sel_metodo_pago').value;
        const tipoPago = document.getElementById('sel_tipo_pago').value;
        const conceptoRecibo = document.getElementById('txt_concepto_recibo').value.trim();

        if (!esPublico && !idPaciente) {
            Swal.fire('Aviso', 'Selecciona un paciente registrado o activa Público General.', 'warning');
            return;
        }

        let total = carrito.reduce((acc, it) => acc + it.subtotal, 0);
        let montoCobrar = total;

        if (tipoPago === 'Abonar') {
            const abonoVal = parseFloat(document.getElementById('txt_monto_abono').value);
            if (isNaN(abonoVal) || abonoVal <= 0) {
                Swal.fire('Monto Inválido', 'Indica un monto de abono válido mayor a 0.', 'warning');
                return;
            }
            montoCobrar = abonoVal;
        }

        // Formatear items para api/guardar_recibo_rapido.pl
        const itemsPayload = carrito.map(it => ({
            concepto: it.nombre,
            nombre: it.nombre,
            precio: it.precio,
            cantidad: it.cantidad,
            subtotal: it.subtotal
        }));

        const body = new URLSearchParams();
        body.append('id_paciente', idPaciente);
        body.append('nombre_paciente_empleado', nombrePaciente);
        body.append('id_medico', idMedico);
        body.append('caja_items_json', JSON.stringify(itemsPayload));
        body.append('caja_metodo_pago', metodoPago);
        body.append('caja_monto_abono', montoCobrar);
        body.append('caja_concepto', conceptoRecibo);

        const btn = document.getElementById('btn_procesar_cobro');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Generando Recibo...';

        try {
            const res = await fetch('../api/guardar_recibo_rapido.pl', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
                body: body
            });
            const data = await res.json();

            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-receipt me-2"></i>COBRAR Y GENERAR RECIBO';

            if (data.ok) {
                const folioRecibo = data.folio || data.id_recibo || '';
                Swal.fire({
                    icon: 'success',
                    title: '¡Cobro Exitoso!',
                    html: `Recibo generado satisfactoriamente.<br><strong class="fs-4 text-navy">Folio: ${folioRecibo}</strong>`,
                    showDenyButton: true,
                    confirmButtonText: '<i class="bi bi-printer me-1"></i> Imprimir Recibo',
                    denyButtonText: '<i class="bi bi-plus-circle me-1"></i> Nueva Venta',
                    confirmButtonColor: '#0A2A66',
                    denyButtonColor: '#19B7A5',
                    customClass: { popup: 'rounded-4' }
                }).then((result) => {
                    if (result.isConfirmed) {
                        window.open('../api/imprimir_recibo_caja.pl?id_consulta=' + encodeURIComponent(folioRecibo), '_blank');
                    }
                    limpiarCarrito();
                    document.getElementById('txt_concepto_recibo').value = '';
                    document.getElementById('txt_monto_abono').value = '';
                });
            } else {
                Swal.fire('Error en Cobro', data.msg || 'No fue posible registrar la venta en caja.', 'error');
            }
        } catch(e) {
            console.error('Error al procesar cobro:', e);
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-receipt me-2"></i>COBRAR Y GENERAR RECIBO';
            Swal.fire('Error de Conexión', 'Ocurrió una falla al comunicarse con el servidor.', 'error');
        }
    }
</script>
JS

utils::sub_sidebar::render_sidebar_footer();
print <<HTML;
</body>
</html>
HTML

render_bottom_nav('finanzas');
1;
