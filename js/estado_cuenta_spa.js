/* SDM Digital - Financial Motor SPA */
const formatter = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });
let idPacienteGlobal = null;
let idMedicoGlobal = null;
let catalogoMaster = [];
let carritoApp = [];
let windowActiveOS = null;
let currentSaldoTotal = 0;

async function initModuloFinanciero(id, modo, idMed) {
    idPacienteGlobal = id;
    idMedicoGlobal = idMed || 'SISTEMA';
    await cargarHistorialCuentas();
    // Cargar catálogo siempre que se inicialice el módulo, ya que ambos modos pueden usar modales
    await cargarCatalogo();
}

async function cargarHistorialCuentas() {
    try {
        const formData = new URLSearchParams();
        formData.append('accion', 'get_historial');
        formData.append('id_paciente', idPacienteGlobal);
        
        const response = await fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: formData });
        if (!response.ok) throw new Error("Error en servidor");
        const res = await response.json();

        // Actualizar KPIs
        currentSaldoTotal = res.saldo || 0;
        if (document.getElementById('ecCargos')) document.getElementById('ecCargos').innerText = formatter.format(res.cargos || 0);
        if (document.getElementById('ecAbonos')) document.getElementById('ecAbonos').innerText = formatter.format(res.abonos || 0);
        
        // Actualizar Footer de Tabla e Impresión
        if (document.getElementById('tfCargos')) document.getElementById('tfCargos').innerText = formatter.format(res.cargos || 0);
        if (document.getElementById('tfAbonos')) document.getElementById('tfAbonos').innerText = formatter.format(res.abonos || 0);
        if (document.getElementById('printDate')) {
            const now = new Date();
            document.getElementById('printDate').innerText = now.toLocaleDateString('es-MX', { day: '2-digit', month: 'long', year: 'numeric' }) + ' ' + now.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
        }

        // Mostrar/Ocultar botón de liquidar
        const btnL = document.getElementById('btnLiquidarTodo');
        if(btnL) btnL.style.display = currentSaldoTotal > 0 ? 'block' : 'none';

        const sl = document.getElementById('ecSaldo');
        if (sl) {
            sl.innerText = formatter.format(res.saldo || 0);
            const card = document.getElementById('ecSaldoCard');
            if (card) {
                // Estilo dinámico basado en saldo
                if (res.saldo > 0) {
                    if (card.classList.contains('kpi-card')) {
                        card.style.borderColor = "#dc2626";
                        sl.style.color = "#dc2626";
                    }
                } else {
                    if (card.classList.contains('kpi-card')) {
                        card.style.borderColor = "#059669";
                        sl.style.color = "#059669";
                    }
                }
            }
        }

        renderHistorial(res.historial || []);
    } catch (e) {
        console.error("Fallo financiero:", e);
    }
}

function renderHistorial(historial) {
    // Intentar renderizar en modo Tabla
    const tb = document.getElementById('tbEdoCuenta');
    if (tb) {
        tb.innerHTML = historial.length ? '' : '<tr><td colspan="6" class="text-center py-5 text-muted fw-bold">Sin movimientos.</td></tr>';
        historial.forEach(m => {
            const isC = m.tipo === 'Cargo';
            tb.insertAdjacentHTML('beforeend', `
                <tr>
                    <td class="ps-4 small text-primary fw-bold">${m.id_os}</td>
                    <td class="small text-muted fw-bold">${m.fecha}</td>
                    <td><div class="d-flex align-items-center gap-3">
                        <div class="btn btn-sm ${isC?'btn-light text-danger':'btn-light text-success'} rounded-3" style="width:35px; height:35px; display:flex; align-items:center; justify-content:center;">
                            <i class="bi ${isC?'bi-receipt':'bi-cash-coin'}"></i>
                        </div>
                        <span class="fw-bold text-dark small">${m.concepto}</span>
                    </div></td>
                    <td class="text-end fw-black ${isC?'text-danger':''}">${isC ? formatter.format(m.total) : '-'}</td>
                    <td class="text-end fw-black ${!isC?'text-success':''}">${!isC ? formatter.format(m.total) : '-'}</td>
                    <td class="text-center">
                        <div class="d-flex gap-1 justify-content-center">
                            <button onclick="imprimirOS('${m.id_os}')" title="Imprimir Recibo" class="btn btn-sm btn-outline-dark border-0"><i class="bi bi-printer"></i></button>
                            ${isC ? `<button onclick="abrirModalAbonoContextual(${m.total}, '${m.concepto}', '${m.id_os}')" title="Abonar a este ítem" class="btn btn-sm btn-outline-success border-0"><i class="bi bi-cash-coin"></i></button>` : ''}
                            ${isC ? `<button onclick="abrirModalCargoConOS('${m.id_os}')" title="Agregar ítem a esta OS" class="btn btn-sm btn-outline-primary border-0"><i class="bi bi-folder-plus"></i></button>` : ''}
                            <button onclick="prepararEdicion('${m.id_mov}', '${m.concepto}', '${m.total}')" class="btn btn-sm btn-outline-secondary border-0"><i class="bi bi-pencil"></i></button>
                            <button onclick="eliminarMovimiento('${m.id_mov}')" class="btn btn-sm btn-outline-danger border-0"><i class="bi bi-trash"></i></button>
                        </div>
                    </td>
                </tr>`);
        });
    }

    // Intentar renderizar en modo Bento
    const container = document.getElementById('bentoTransactionsContainer');
    if (container) {
        container.innerHTML = historial.length ? '' : '<div class="p-5 text-center text-muted fw-bold small">No se encontraron movimientos registrados.</div>';
        historial.forEach(m => {
            const isC = m.tipo === 'Cargo';
            container.insertAdjacentHTML('beforeend', `
                <div class="bento-card p-3 border shadow-sm d-flex justify-content-between align-items-center animate__animated animate__fadeInUp" style="border-radius:1.5rem;">
                    <div class="d-flex align-items-center gap-3">
                        <div class="rounded-4 d-flex align-items-center justify-content-center shadow-sm ${isC?'bg-danger-subtle text-danger':'bg-success-subtle text-success'}" style="width:50px; height:50px;">
                            <i class="bi ${isC?'bi-receipt-cutoff':'bi-cash-stack'}" style="font-size:1.5rem;"></i>
                        </div>
                        <div>
                            <div class="d-flex align-items-center gap-2 mb-1">
                                <span class="badge bg-primary-subtle text-primary border-0 rounded-pill px-2 py-1" style="font-size:0.6rem;">${m.id_os}</span>
                                <span class="text-muted small" style="font-size:0.6rem;">• ${m.fecha}</span>
                            </div>
                            <p class="fw-bold text-dark mb-0 tracking-tight">${m.concepto}</p>
                            <div class="d-flex align-items-center gap-2">
                                <span class="small fw-bold uppercase tracking-wider ${isC?'text-danger':'text-success'}" style="font-size:0.6rem;">${m.tipo}</span>
                            </div>
                        </div>
                    </div>
                    <div class="d-flex align-items-center gap-4">
                        <div class="text-end">
                            <p class="fw-bold h5 mb-0 tracking-tighter ${isC?'text-dark':'text-success'}">${isC?'':'-'}${formatter.format(m.total)}</p>
                        </div>
                        <div class="d-flex gap-2">
                            ${isC ? `<button onclick="abrirModalAbonoContextual(${m.total}, '${m.concepto}', '${m.id_os}')" class="btn btn-sm btn-light border-0"><i class="bi bi-cash-coin text-success"></i></button>` : ''}
                            ${isC ? `<button onclick="abrirModalCargoConOS('${m.id_os}')" class="btn btn-sm btn-light border-0"><i class="bi bi-folder-plus text-primary"></i></button>` : ''}
                            <button onclick="prepararEdicion('${m.id_mov}', '${m.concepto}', '${m.total}')" class="btn btn-sm btn-light border-0"><i class="bi bi-pencil text-muted"></i></button>
                            <button onclick="eliminarMovimiento('${m.id_mov}')" class="btn btn-sm btn-light border-0"><i class="bi bi-trash text-danger"></i></button>
                        </div>
                    </div>
                </div>`);
        });
    }
}

async function cargarCatalogo() {
    try {
        const res = await fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: new URLSearchParams({accion: 'get_catalogo'}) });
        const data = await res.json();
        catalogoMaster = [...(data.servicios||[]), ...(data.productos||[])];
        renderCatalogoGUI();
    } catch(e) {}
}

function renderCatalogoGUI(f = '') {
    const div = document.getElementById('divCatalogo'); if(!div) return;
    div.innerHTML = '';
    const filtered = catalogoMaster.filter(i => (i.nombre||'').toLowerCase().includes(f.toLowerCase()));
    
    filtered.forEach(it => {
        div.insertAdjacentHTML('beforeend', `
            <div class="col-12 col-md-6 mb-2">
                <div class="card h-100 border-0 shadow-sm hover-shadow transition-all" onclick="agregarAlCarrito('${it.id}')" style="cursor:pointer; border-radius:1.2rem; background:#ffffff;">
                    <div class="card-body p-3 d-flex justify-content-between align-items-center">
                        <div class="text-truncate">
                            <p class="fw-bold text-dark m-0 small text-truncate" title="${it.nombre}">${it.nombre}</p>
                            <p class="text-primary fw-bold m-0 small tracking-tighter">${formatter.format(it.precio)}</p>
                        </div>
                        <div class="btn btn-sm btn-primary rounded-circle shadow-sm d-flex align-items-center justify-content-center" style="width:28px; height:28px; border:none;"><i class="bi bi-plus" style="font-size:1.2rem;"></i></div>
                    </div>
                </div>
            </div>`);
    });
}

function filtrarCatalogo() { renderCatalogoGUI(document.getElementById('buscadorCatalogo').value); }

function agregarCargoManual() {
    const n = document.getElementById('manual_nombre'), p = document.getElementById('manual_precio');
    if(!n.value || !p.value) return Swal.fire("Aviso", "Indique descripción y precio", "warning");
    const id = 'MAN-'+Date.now();
    carritoApp.push({ id, nombre: n.value, precio: parseFloat(p.value), cantidad: 1 });
    n.value = ''; p.value = ''; refrescarGUICarrito();
}

function agregarAlCarrito(id) {
    const it = catalogoMaster.find(x => x.id === id); if(!it) return;
    let ex = carritoApp.find(x => x.id === id);
    if(ex) ex.cantidad++; else carritoApp.push({ ...it, precio: parseFloat(it.precio), cantidad: 1 });
    refrescarGUICarrito();
}

function refrescarGUICarrito() {
    const uli = document.getElementById('listaCarrito'); if(!uli) return;
    uli.innerHTML = carritoApp.length === 0 ? '<div class="text-center p-10 text-slate-300 font-bold small">El carrito está vacío.</div>' : '';
    let total = 0;
    carritoApp.forEach((c, i) => {
        const st = c.precio * c.cantidad; total += st;
        uli.insertAdjacentHTML('beforeend', `
            <div class="bg-slate-50 p-4 rounded-2xl border border-slate-100 d-flex justify-content-between align-items-center">
                <div class="lh-sm">
                    <span class="fw-black text-slate-800 d-block mb-1 text-xs uppercase">${c.nombre}</span>
                    <small class="text-slate-400 fw-bold">${c.cantidad} x ${formatter.format(c.precio)}</small>
                </div>
                <div class="d-flex align-items-center gap-3">
                    <span class="fw-black text-primary">${formatter.format(st)}</span>
                    <button class="btn btn-sm btn-white text-danger border shadow-sm rounded-xl p-2" onclick="removeCartItem(${i})"><i class="bi bi-trash"></i></button>
                </div>
            </div>`);
    });
    
    const iva = document.getElementById('checkFactura') && document.getElementById('checkFactura').checked ? (total * 0.16) : 0;
    const tv = document.getElementById('carritoTotal');
    if (tv) tv.innerText = formatter.format(total + iva);
}

function removeCartItem(idx) { carritoApp.splice(idx, 1); refrescarGUICarrito(); }

async function procesarCarrito() {
    if(carritoApp.length === 0) return;
    const btn = document.getElementById('btnProcesarCargo');
    const oldText = btn.innerHTML;
    btn.disabled = true; btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> PROCESANDO...';
    
    try {
        const fd = new URLSearchParams();
        fd.append('accion', 'add_cargo');
        fd.append('id_paciente', idPacienteGlobal);
        fd.append('id_medico', idMedicoGlobal);
        fd.append('id_os_manual', windowActiveOS || '');
        const cf = document.getElementById('checkFactura');
        fd.append('aplica_iva', (cf && cf.checked) ? '1' : '0');
        fd.append('payload', JSON.stringify(carritoApp));
        const res = await fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: fd });
        const json = await res.json();
        if(json.success) {
            const m = bootstrap.Modal.getInstance(document.getElementById('modalCargo'));
            if (m) m.hide();
            await cargarHistorialCuentas();
            Swal.fire("Éxito", "Cargo registrado correctamente", "success");
        }
    } catch(e) { console.error(e); }
    btn.disabled = false; btn.innerHTML = oldText;
}

async function abrirModalAbono() {
    const modalEl = document.getElementById('modalAbono');
    if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
    document.getElementById('modalAbonoTitle').innerText = 'Registrar Abono Global';
    document.getElementById('montoAbono').value = '';
    document.getElementById('notasAbono').value = '';
    const m = bootstrap.Modal.getOrCreateInstance(modalEl);
    m.show();
}

function abrirModalAbonoContextual(monto, concepto, id_os) {
    const modalEl = document.getElementById('modalAbono');
    if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
    document.getElementById('modalAbonoTitle').innerHTML = `<i class="bi bi-cash-coin me-2"></i>Liquidar: <span class="text-success">${concepto}</span>`;
    document.getElementById('montoAbono').value = monto;
    document.getElementById('notasAbono').value = `Pago de: ${concepto} (OS: ${id_os})`;
    const m = bootstrap.Modal.getOrCreateInstance(modalEl);
    m.show();
}

function liquidarSaldoTotal() {
    if(currentSaldoTotal <= 0) return;
    const modalEl = document.getElementById('modalAbono');
    if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
    document.getElementById('modalAbonoTitle').innerHTML = `<i class="bi bi-wallet2 me-2"></i>Liquidaci&oacute;n de Cuenta Total`;
    document.getElementById('montoAbono').value = currentSaldoTotal;
    document.getElementById('notasAbono').value = `Liquidaci&oacute;n total de saldo pendiente.`;
    const m = bootstrap.Modal.getOrCreateInstance(modalEl);
    m.show();
}

function procesarAbono() {
    const val = document.getElementById('montoAbono').value;
    const met = document.getElementById('metodoAbono').value;
    const not = document.getElementById('notasAbono').value;
    
    if(!val || parseFloat(val) <= 0) return Swal.fire("Atención", "Ingrese un monto válido", "warning");

    const fd = new FormData();
    fd.append('accion', 'add_abono');
    fd.append('id_paciente', idPacienteGlobal);
    fd.append('id_medico', idMedicoGlobal);
    fd.append('monto', val);
    fd.append('metodo', met);
    fd.append('notas', not);

    fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: fd })
        .then(r => r.json())
        .then(data => {
            if(data.success) {
                Swal.fire("Éxito", "Abono registrado correctamente", "success");
                bootstrap.Modal.getInstance(document.getElementById('modalAbono')).hide();
                cargarHistorialCuentas(); // Refresco inmediato
            }
        });
}

function imprimirEstadoCuenta() {
    window.print();
}

function imprimirOS(id_os) {
    // 1. Filtrar visualmente la tabla (solo lo que coincida con la OS)
    const rows = document.querySelectorAll('#tbEdoCuenta tr');
    rows.forEach(r => {
        if (!r.innerText.includes(id_os)) r.classList.add('d-none-print');
    });
    
    // 2. Lanzar impresión
    window.print();
    
    // 3. Restaurar visibilidad
    rows.forEach(r => r.classList.remove('d-none-print'));
}

function eliminarMovimiento(id) {
    Swal.fire({ title: '¿Eliminar registro?', text: "Esta acción no se puede deshacer.", icon: 'warning', showCancelButton: true, confirmButtonColor: '#dc2626', cancelButtonColor: '#64748b', confirmButtonText: 'Sí, borrar' }).then((result) => {
        if (result.isConfirmed) {
            fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: new URLSearchParams({accion: 'delete_movimiento', id_mov: id}) })
            .then(r => r.json()).then(res => { if(res.success) { cargarHistorialCuentas(); Swal.fire("Eliminado", "El registro ha sido borrado", "success"); } });
        }
    });
}

function prepararEdicion(id, concepto, total) {
    Swal.fire({
        title: 'Modificar Registro',
        html: `
            <div class="text-start mb-3"><label class="small fw-bold text-muted uppercase">Concepto</label><input id="sw_concepto" class="form-control rounded-3" value="${concepto}"></div>
            <div class="text-start mb-3"><label class="small fw-bold text-muted uppercase">Monto Final</label><input id="sw_monto" class="form-control rounded-3" type="number" step="0.01" value="${total}"></div>
        `,
        showCancelButton: true, confirmButtonText: 'Actualizar', confirmButtonColor: '#174975',
        preConfirm: () => {
            return { c: document.getElementById('sw_concepto').value, m: document.getElementById('sw_monto').value };
        }
    }).then((r) => {
        if (r.isConfirmed) {
            const fd = new URLSearchParams({ accion: 'update_movimiento', id_mov: id, concepto: r.value.c, monto: r.value.m });
            fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: fd }).then(r => r.json()).then(res => { 
                if(res.success) { cargarHistorialCuentas(); Swal.fire("Actualizado", "Registro modificado con éxito", "success"); } 
            });
        }
    });
}

/** 
 * INTERFAZ DE ACTIVACIÓN DE MODALES
 * Estas funciones son llamadas desde views/estado_cuenta.pl
 */

function abrirModalCargo() {
    windowActiveOS = null;
    document.getElementById('modalCargoTitle').innerHTML = '<i class="bi bi-cart-plus me-3"></i>Nueva Orden de Servicio';
    carritoApp = [];
    refrescarGUICarrito();
    const el = document.getElementById('modalCargo');
    if (!el) return console.error("Modal Cargo no encontrado");
    const m = new bootstrap.Modal(el);
    m.show();
}

function abrirModalCargoConOS(id_os) {
    windowActiveOS = id_os;
    document.getElementById('modalCargoTitle').innerHTML = `<i class="bi bi-plus-circle-dotted me-3"></i>Agregar a OS: <span class="text-primary">${id_os}</span>`;
    carritoApp = [];
    refrescarGUICarrito();
    const el = document.getElementById('modalCargo');
    if (!el) return console.error("Modal Cargo no encontrado");
    const m = new bootstrap.Modal(el);
    m.show();
}
