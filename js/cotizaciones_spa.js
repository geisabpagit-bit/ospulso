/* =====================================================
   SDM Digital - cotizaciones_spa.js
   Módulo de Cotizaciones (Carrito) desde el Expediente
   ===================================================== */

var cotPacienteId    = null;
var cotPacienteNombre = '';
var cotCarrito       = [];
var cotCatalogo      = [];
var cotEditandoId    = null;  // null = nueva, id_cot = edición
var cotTableInstance = null;

var formatter = (typeof formatter !== 'undefined') ? formatter : new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });

// ─────────────────────────────────────────────
// 1. ABRIR MODAL DE LISTA DE COTIZACIONES
// ─────────────────────────────────────────────
window.abrirModalCotizaciones = function(idPaciente, nombrePaciente) {
    cotPacienteId     = idPaciente;
    cotPacienteNombre = nombrePaciente;

    // Inyectar modal si no existe
    if (!document.getElementById('modalCotizaciones')) {
        _inyectarModalCotizaciones();
    }

    // Mostrar modal
    var el = document.getElementById('modalCotizaciones');
    if (el) {
        var bsModal = bootstrap.Modal.getInstance(el) || new bootstrap.Modal(el);
        bsModal.show();
    }

    // Actualizar subtítulo
    var sub = document.getElementById('cotPacienteLabel');
    if (sub) sub.textContent = 'Paciente: ' + nombrePaciente;

    // Cargar lista
    _cargarListaCotizaciones();

    // Pre-cargar catálogo para el carrito
    _cargarCatalogoCot();
};

// ─────────────────────────────────────────────
// 2. CARGAR LISTA DE COTIZACIONES (DataTable)
// ─────────────────────────────────────────────
function _cargarListaCotizaciones() {
    var tbody = document.getElementById('cotTbody');
    if (!tbody) return;
    tbody.innerHTML = '<tr><td colspan="3" class="text-center py-4"><div class="spinner-border spinner-border-sm text-primary me-2"></div>Cargando...</td></tr>';

    var fd = new URLSearchParams();
    fd.append('accion', 'get_lista');
    fd.append('id_paciente', cotPacienteId);

    fetch('../api/cotizaciones_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(res) {
            if (cotTableInstance) {
                try { cotTableInstance.destroy(); } catch(e) {}
                cotTableInstance = null;
            }

            if (!res.cotizaciones || res.cotizaciones.length === 0) {
                tbody.innerHTML = '<tr><td colspan="3" class="text-center py-5 text-muted"><i class="bi bi-file-earmark-x d-block mb-2" style="font-size:2rem;"></i>Sin cotizaciones generadas</td></tr>';
                return;
            }

            tbody.innerHTML = '';
            res.cotizaciones.forEach(function(c) {
                var tr = document.createElement('tr');
                tr.innerHTML =
                    '<td class="fw-bold">' + _escHTML(c.nombre) + '<br><small class="text-muted">' + _escHTML(c.fecha) + '</small></td>' +
                    '<td class="text-end fw-bold text-primary">' + formatter.format(c.total) + '</td>' +
                    '<td class="text-center">' +
                        '<button class="btn btn-sm btn-outline-primary rounded-circle me-1" title="Editar" onclick="editarCotizacion(\'' + _escHTML(c.id_cot) + '\')">' +
                            '<i class="bi bi-pencil"></i></button>' +
                        '<button class="btn btn-sm btn-outline-danger rounded-circle" title="Eliminar" onclick="borrarCotizacion(\'' + _escHTML(c.id_cot) + '\', \'' + _escHTML(c.nombre) + '\')">' +
                            '<i class="bi bi-trash"></i></button>' +
                    '</td>';
                tbody.appendChild(tr);
            });

            if (window.jQuery && $.fn.DataTable) {
                cotTableInstance = $('#cotTabla').DataTable({
                    language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                    pageLength: 5,
                    dom: '<"d-flex justify-content-between align-items-center mb-2"lf>rt<"d-flex justify-content-between align-items-center mt-2"ip>',
                    columnDefs: [{ orderable: false, targets: 2 }],
                    responsive: true,
                    destroy: true
                });
            }
        })
        .catch(function(err) {
            tbody.innerHTML = '<tr><td colspan="3" class="text-center text-danger py-3"><i class="bi bi-wifi-off me-1"></i>Error de conexión</td></tr>';
            console.error('[Cotizaciones] Error lista:', err);
        });
}

// ─────────────────────────────────────────────
// 3. ABRIR MODAL NUEVA / EDITAR COTIZACIÓN
// ─────────────────────────────────────────────
window.abrirNuevaCotizacion = function() {
    cotEditandoId = null;
    cotCarrito = [];
    var inp = document.getElementById('cotNombreInput');
    if (inp) inp.value = '';
    _renderizarCarritoCot();
    _filtrarCatalogoCot();

    var el = document.getElementById('modalNuevaCot');
    if (el) {
        var bsM = bootstrap.Modal.getInstance(el) || new bootstrap.Modal(el, { backdrop: 'static' });
        bsM.show();
    }
    var titulo = document.getElementById('modalNuevaCotTitle');
    if (titulo) titulo.innerHTML = '<i class="bi bi-cart-plus me-2"></i>Nueva Cotización';
};

window.editarCotizacion = function(idCot) {
    cotEditandoId = idCot;
    cotCarrito = [];

    var fd = new URLSearchParams();
    fd.append('accion', 'get_detalle');
    fd.append('id_cot', idCot);

    fetch('../api/cotizaciones_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(res) {
            var inp = document.getElementById('cotNombreInput');
            if (inp) inp.value = res.nombre || '';

            cotCarrito = (res.items || []).map(function(it) {
                return { nombre: it.concepto, precio: it.precio, cantidad: it.cantidad };
            });
            _renderizarCarritoCot();
            _filtrarCatalogoCot();

            var el = document.getElementById('modalNuevaCot');
            if (el) {
                var bsM = bootstrap.Modal.getInstance(el) || new bootstrap.Modal(el, { backdrop: 'static' });
                bsM.show();
            }
            var titulo = document.getElementById('modalNuevaCotTitle');
            if (titulo) titulo.innerHTML = '<i class="bi bi-pencil me-2"></i>Editar Cotización';
        })
        .catch(function(err) {
            console.error('[Cotizaciones] Error get_detalle:', err);
            Swal.fire('Error', 'No se pudo cargar el detalle de la cotización.', 'error');
        });
};

// ─────────────────────────────────────────────
// 4. BORRAR COTIZACIÓN
// ─────────────────────────────────────────────
window.borrarCotizacion = function(idCot, nombre) {
    Swal.fire({
        title: '¿Eliminar cotización?',
        html: '<strong>' + _escHTML(nombre) + '</strong><br><small class="text-muted">Esta acción no se puede deshacer.</small>',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#e74c3c',
        cancelButtonColor: '#486581',
        confirmButtonText: '<i class="bi bi-trash me-1"></i>Eliminar',
        cancelButtonText: 'Cancelar',
        background: '#ffffff',
        customClass: { popup: 'rounded-4 shadow-lg' }
    }).then(function(result) {
        if (!result.isConfirmed) return;
        var fd = new URLSearchParams();
        fd.append('accion', 'delete');
        fd.append('id_cot', idCot);
        fetch('../api/cotizaciones_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
            .then(function(r) { return r.json(); })
            .then(function(res) {
                if (res.status === 'ok') {
                    Swal.fire({ icon: 'success', title: 'Eliminada', timer: 1200, showConfirmButton: false });
                    _cargarListaCotizaciones();
                } else {
                    Swal.fire('Error', res.message || 'No se pudo eliminar.', 'error');
                }
            });
    });
};

// ─────────────────────────────────────────────
// 5. GUARDAR COTIZACIÓN (Create / Update)
// ─────────────────────────────────────────────
window.guardarCotizacion = function() {
    var nombre = (document.getElementById('cotNombreInput') || {}).value || '';
    if (!nombre.trim()) {
        Swal.fire({ icon: 'warning', title: 'Nombre requerido', text: 'Por favor escribe un nombre para la cotización.', confirmButtonColor: '#0A2A66' });
        return;
    }
    if (cotCarrito.length === 0) {
        Swal.fire({ icon: 'warning', title: 'Carrito vacío', text: 'Agrega al menos un concepto antes de guardar.', confirmButtonColor: '#0A2A66' });
        return;
    }

    var btn = document.getElementById('btnGuardarCot');
    if (btn) { btn.disabled = true; btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Guardando...'; }

    var fd = new URLSearchParams();
    fd.append('nombre', nombre.trim());
    fd.append('id_paciente', cotPacienteId);
    fd.append('payload', JSON.stringify(cotCarrito));

    if (cotEditandoId) {
        fd.append('accion', 'update');
        fd.append('id_cot', cotEditandoId);
    } else {
        fd.append('accion', 'create');
    }

    fetch('../api/cotizaciones_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(res) {
            if (btn) { btn.disabled = false; btn.innerHTML = '<i class="bi bi-check-lg me-1"></i>GUARDAR COTIZACIÓN'; }
            if (res.status === 'ok') {
                var el = document.getElementById('modalNuevaCot');
                if (el) { var bsM = bootstrap.Modal.getInstance(el); if (bsM) bsM.hide(); }
                Swal.fire({ icon: 'success', title: cotEditandoId ? 'Cotización actualizada' : 'Cotización guardada', timer: 1400, showConfirmButton: false });
                _cargarListaCotizaciones();
                cotEditandoId = null;
            } else {
                Swal.fire('Error', res.message || 'No se pudo guardar.', 'error');
            }
        })
        .catch(function(err) {
            if (btn) { btn.disabled = false; btn.innerHTML = '<i class="bi bi-check-lg me-1"></i>GUARDAR COTIZACIÓN'; }
            Swal.fire('Error de red', 'No se pudo conectar con el servidor.', 'error');
            console.error('[Cotizaciones] guardar error:', err);
        });
};

// ─────────────────────────────────────────────
// 6. CARRITO DE COMPRAS
// ─────────────────────────────────────────────
window.agregarItemManualCot = function() {
    var nombre = (document.getElementById('cotManualNombre') || {}).value || '';
    var precio = parseFloat((document.getElementById('cotManualPrecio') || {}).value) || 0;
    if (!nombre.trim() || precio <= 0) {
        Swal.fire({ icon: 'warning', title: 'Datos incompletos', text: 'Escribe un concepto y un precio mayor a cero.', confirmButtonColor: '#0A2A66' });
        return;
    }
    cotCarrito.push({ nombre: nombre.trim(), precio: precio, cantidad: 1 });
    var n = document.getElementById('cotManualNombre'); if (n) n.value = '';
    var p = document.getElementById('cotManualPrecio'); if (p) p.value = '';
    _renderizarCarritoCot();
};

window.agregarItemCatalogoCot = function(nombre, precio) {
    var idx = cotCarrito.findIndex(function(i) { return i.nombre === nombre; });
    if (idx > -1) {
        cotCarrito[idx].cantidad++;
    } else {
        cotCarrito.push({ nombre: nombre, precio: precio, cantidad: 1 });
    }
    _renderizarCarritoCot();
};

window.quitarItemCot = function(idx) {
    cotCarrito.splice(idx, 1);
    _renderizarCarritoCot();
};

window.cambiarCantidadCot = function(idx, delta) {
    cotCarrito[idx].cantidad = Math.max(1, (cotCarrito[idx].cantidad || 1) + delta);
    _renderizarCarritoCot();
};

function _renderizarCarritoCot() {
    var cont = document.getElementById('cotListaCarrito');
    var totalEl = document.getElementById('cotTotalCarrito');
    if (!cont) return;

    if (cotCarrito.length === 0) {
        cont.innerHTML = '<div class="text-center text-muted py-4"><i class="bi bi-cart-x d-block mb-2" style="font-size:2rem;opacity:.4;"></i><small>Sin conceptos</small></div>';
        if (totalEl) totalEl.textContent = '$0.00';
        return;
    }

    var total = 0;
    var html = '';
    cotCarrito.forEach(function(item, idx) {
        var sub = item.precio * item.cantidad;
        total += sub;
        html +=
            '<div class="d-flex align-items-center justify-content-between p-2 mb-1 rounded-3 border bg-white shadow-sm">' +
                '<div class="flex-grow-1 overflow-hidden me-2">' +
                    '<div class="fw-bold text-truncate" style="font-size:.78rem;" title="' + _escHTML(item.nombre) + '">' + _escHTML(item.nombre) + '</div>' +
                    '<small class="text-muted">' + formatter.format(item.precio) + ' c/u</small>' +
                '</div>' +
                '<div class="d-flex align-items-center gap-1 flex-shrink-0">' +
                    '<button class="btn btn-outline-secondary btn-sm rounded-circle" style="width:22px;height:22px;padding:0;font-size:.7rem;" onclick="cambiarCantidadCot(' + idx + ',-1)">−</button>' +
                    '<span class="fw-bold mx-1" style="min-width:18px;text-align:center;">' + item.cantidad + '</span>' +
                    '<button class="btn btn-outline-secondary btn-sm rounded-circle" style="width:22px;height:22px;padding:0;font-size:.7rem;" onclick="cambiarCantidadCot(' + idx + ',1)">+</button>' +
                    '<button class="btn btn-outline-danger btn-sm rounded-circle ms-1" style="width:22px;height:22px;padding:0;font-size:.7rem;" onclick="quitarItemCot(' + idx + ')"><i class="bi bi-x"></i></button>' +
                '</div>' +
                '<div class="ms-2 fw-bold text-primary flex-shrink-0" style="font-size:.8rem;min-width:55px;text-align:right;">' + formatter.format(sub) + '</div>' +
            '</div>';
    });
    cont.innerHTML = html;
    if (totalEl) totalEl.textContent = formatter.format(total);
}

// ─────────────────────────────────────────────
// 7. CATÁLOGO
// ─────────────────────────────────────────────
function _cargarCatalogoCot() {
    if (cotCatalogo.length > 0) { _renderizarCatalogoCot(); return; }
    var fd = new URLSearchParams();
    fd.append('accion', 'get_catalogo');
    fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(function(r) { return r.json(); })
        .then(function(res) {
            cotCatalogo = [];
            (res.servicios || []).forEach(function(s) { cotCatalogo.push({ id: s.id, nombre: s.nombre, precio: s.precio }); });
            (res.productos || []).forEach(function(p) { cotCatalogo.push({ id: p.id, nombre: p.nombre, precio: p.precio }); });
            _renderizarCatalogoCot();
        })
        .catch(function(e) { console.warn('[Cotizaciones] catalogo error:', e); });
}

window._filtrarCatalogoCot = function() {
    var q = ((document.getElementById('cotBuscador') || {}).value || '').toLowerCase();
    var tbody = document.getElementById('cotTablaCatalogo');
    if (!tbody) return;
    tbody.innerHTML = '';
    var filtrado = cotCatalogo.filter(function(it) { return it.nombre.toLowerCase().indexOf(q) > -1; });
    if (filtrado.length === 0) {
        tbody.innerHTML = '<tr><td colspan="3" class="text-center text-muted small py-2">Sin resultados</td></tr>';
        return;
    }
    filtrado.slice(0, 30).forEach(function(it) {
        var tr = document.createElement('tr');
        tr.style.cursor = 'pointer';
        tr.innerHTML =
            '<td class="small">' + _escHTML(it.nombre) + '</td>' +
            '<td class="small text-end">' + formatter.format(it.precio) + '</td>' +
            '<td class="text-center"><button class="btn btn-sm btn-outline-primary px-2 py-0" onclick="agregarItemCatalogoCot(\'' + _escAttr(it.nombre) + '\',' + it.precio + ')"><i class="bi bi-plus-lg"></i></button></td>';
        tbody.appendChild(tr);
    });
};

function _renderizarCatalogoCot() {
    _filtrarCatalogoCot();
}

// ─────────────────────────────────────────────
// 8. INYECTAR HTML DE MODALES
// ─────────────────────────────────────────────
function _inyectarModalCotizaciones() {
    // Inyectar estilos si no existen
    if (!document.getElementById('cotStyles')) {
        var s = document.createElement('style');
        s.id = 'cotStyles';
        s.innerHTML =
            '#cotTabla { width: 100% !important; }' +
            '.cot-carrito-item:hover { background: #f0f7ff !important; }';
        document.head.appendChild(s);
    }

    // ── MODAL LISTA ──
    var divLista = document.createElement('div');
    divLista.innerHTML =
        '<div class="modal fade modal-diamond" id="modalCotizaciones" tabindex="-1" aria-labelledby="modalCotizacionesLabel" aria-hidden="true" style="z-index:107000!important;">' +
          '<div class="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable">' +
            '<div class="modal-content">' +
              '<div class="modal-header border-0 pb-2" style="background:linear-gradient(135deg,#0A2A66 0%,#f59e0b 100%);">' +
                '<h5 class="modal-title fw-bold text-white" id="modalCotizacionesLabel"><i class="bi bi-file-earmark-text me-2"></i>Cotizaciones</h5>' +
                '<button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>' +
              '</div>' +
              '<div class="modal-body p-3" style="background:#f8fafc;">' +
                '<div class="d-flex justify-content-between align-items-center mb-3">' +
                  '<small class="text-muted fw-bold" id="cotPacienteLabel"></small>' +
                  '<button class="btn btn-warning btn-sm rounded-pill fw-bold shadow-sm px-3" onclick="abrirNuevaCotizacion()"><i class="bi bi-plus-lg me-1"></i>Nueva Cotización</button>' +
                '</div>' +
                '<div class="table-responsive">' +
                  '<table class="table table-hover align-middle mb-0" id="cotTabla" style="width:100%">' +
                    '<thead class="table-dark"><tr>' +
                      '<th>Nombre Cotización</th>' +
                      '<th class="text-end">Valor Total</th>' +
                      '<th class="text-center">Acciones</th>' +
                    '</tr></thead>' +
                    '<tbody id="cotTbody"></tbody>' +
                  '</table>' +
                '</div>' +
              '</div>' +
            '</div>' +
          '</div>' +
        '</div>';
    document.body.appendChild(divLista.firstChild);

    // ── MODAL NUEVA/EDITAR COT (carrito) ──
    var divNueva = document.createElement('div');
    divNueva.innerHTML =
        '<div class="modal fade" id="modalNuevaCot" tabindex="-1" aria-labelledby="modalNuevaCotLabel" aria-hidden="true" style="z-index:108000!important;">' +
          '<div class="modal-dialog modal-xl modal-dialog-centered">' +
            '<div class="modal-content overflow-hidden">' +
              '<div class="modal-header border-0 pb-2" style="background:linear-gradient(135deg,#0A2A66 0%,#f59e0b 100%);">' +
                '<h5 class="modal-title fw-bold text-white" id="modalNuevaCotTitle"><i class="bi bi-cart-plus me-2"></i>Nueva Cotización</h5>' +
                '<button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>' +
              '</div>' +
              '<div class="modal-body p-3" style="background:#f8fafc;">' +
                '<!-- Nombre de la cotización -->' +
                '<div class="mb-3">' +
                  '<label class="form-label fw-bold small text-uppercase text-muted">Nombre de la Cotización</label>' +
                  '<input type="text" id="cotNombreInput" class="form-control shadow-sm border-0 rounded-3" placeholder="Ej. Ortodoncia Fase 1, Plan Blanqueamiento..." maxlength="80">' +
                '</div>' +
                '<div class="row g-3">' +
                  '<!-- Columna Izquierda: Catálogo -->' +
                  '<div class="col-lg-7">' +
                    '<div class="card border-0 shadow-sm mb-2">' +
                      '<div class="card-body p-3">' +
                        '<label class="fw-bold small text-muted text-uppercase mb-2 d-block">Entrada Manual</label>' +
                        '<div class="input-group input-group-sm">' +
                          '<input type="text" id="cotManualNombre" class="form-control" placeholder="Concepto (ej. Placa removible)">' +
                          '<span class="input-group-text">$</span>' +
                          '<input type="number" id="cotManualPrecio" class="form-control" style="max-width:90px;" placeholder="0.00">' +
                          '<button class="btn btn-primary px-3" onclick="agregarItemManualCot()"><i class="bi bi-plus-lg"></i></button>' +
                        '</div>' +
                      '</div>' +
                    '</div>' +
                    '<div class="position-relative mb-2">' +
                      '<i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-2 text-muted small"></i>' +
                      '<input type="text" id="cotBuscador" class="form-control form-control-sm ps-4 py-2 rounded-pill shadow-sm border-0" placeholder="Buscar en catálogo..." oninput="_filtrarCatalogoCot()">' +
                    '</div>' +
                    '<div class="table-responsive border rounded bg-white shadow-sm" style="max-height:200px;overflow-y:auto;">' +
                      '<table class="table table-hover table-sm align-middle mb-0">' +
                        '<thead class="table-light"><tr><th>Concepto</th><th class="text-end">Precio</th><th></th></tr></thead>' +
                        '<tbody id="cotTablaCatalogo"></tbody>' +
                      '</table>' +
                    '</div>' +
                  '</div>' +
                  '<!-- Columna Derecha: Carrito -->' +
                  '<div class="col-lg-5">' +
                    '<div class="card border-0 shadow-sm h-100 d-flex flex-column">' +
                      '<div class="card-body p-3 d-flex flex-column">' +
                        '<h6 class="fw-bold text-primary mb-2"><i class="bi bi-cart3 me-1"></i>Resumen de Cotización</h6>' +
                        '<div id="cotListaCarrito" class="flex-grow-1 overflow-auto mb-2" style="max-height:220px;"></div>' +
                        '<div class="p-3 bg-white rounded-4 border shadow-sm mt-auto">' +
                          '<div class="d-flex justify-content-between align-items-center mb-2">' +
                            '<span class="small fw-bold text-muted">TOTAL</span>' +
                            '<span class="h4 fw-bold text-primary m-0" id="cotTotalCarrito">$0.00</span>' +
                          '</div>' +
                          '<button id="btnGuardarCot" class="btn btn-warning btn-sm w-100 py-2 fw-bold rounded-3 shadow" onclick="guardarCotizacion()">' +
                            '<i class="bi bi-check-lg me-1"></i>GUARDAR COTIZACIÓN</button>' +
                        '</div>' +
                      '</div>' +
                    '</div>' +
                  '</div>' +
                '</div>' +
              '</div>' +
            '</div>' +
          '</div>' +
        '</div>';
    document.body.appendChild(divNueva.firstChild);

    // Backdrop compartido para modales apilados
    document.getElementById('modalNuevaCot').addEventListener('hidden.bs.modal', function() {
        // Asegurar que modalCotizaciones siga abierto si lo estaba
        var elLista = document.getElementById('modalCotizaciones');
        if (elLista && elLista.classList.contains('show')) return;
    });
}

// ─────────────────────────────────────────────
// 9. UTILIDADES
// ─────────────────────────────────────────────
function _escHTML(str) {
    return String(str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}
function _escAttr(str) {
    return String(str || '').replace(/'/g,"\\'").replace(/"/g,'&quot;');
}
