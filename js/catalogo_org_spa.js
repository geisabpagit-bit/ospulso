/* ═══════════════════════════════════════════════════════════════
   Catalogo Org SPA — Gestion de servicios y productos por org
   ═══════════════════════════════════════════════════════════════ */
const fmtCat = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });
let _catData = { servicios: [], productos: [], id_raiz: null };
let _tabActiva = 'servicios';

// ─── INICIALIZAR ────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', cargarCatalogoOrg);

async function cargarCatalogoOrg() {
    try {
        const fd = new URLSearchParams({ accion: 'get_catalogo_org' });
        const res = await fetch('../api/catalogo_org_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' });
        const data = await res.json();
        if (data.status !== 'ok') throw new Error(data.message || 'Error al cargar');

        _catData = data;
        const lbl = document.getElementById('labelOrgCatalogo');
        if (lbl) lbl.textContent = 'ID Organizacion raiz: ' + (data.id_raiz || '—');

        renderTablaServicios(data.servicios || []);
        renderTablaProductos(data.productos || []);
    } catch(e) {
        console.error('[CatalogoOrg]', e);
        Swal.fire('Error', 'No se pudo cargar el catalogo: ' + e.message, 'error');
    }
}

// ─── TABS ────────────────────────────────────────────────────────
function mostrarTab(tab) {
    _tabActiva = tab;
    document.getElementById('panel-servicios').classList.toggle('d-none', tab !== 'servicios');
    document.getElementById('panel-productos').classList.toggle('d-none', tab !== 'productos');
    document.getElementById('tab-servicios').classList.toggle('active', tab === 'servicios');
    document.getElementById('tab-productos').classList.toggle('active', tab === 'productos');
}

// ─── RENDER SERVICIOS ────────────────────────────────────────────
function renderTablaServicios(lista) {
    const tb = document.getElementById('tbodyServicios');
    if (!tb) return;
    if (!lista.length) {
        tb.innerHTML = '<tr><td colspan="4" class="text-center text-muted py-4"><i class="bi bi-inbox me-2"></i>Sin servicios registrados. Agrega el primero.</td></tr>';
        return;
    }
    tb.innerHTML = lista.map(s => `
        <tr>
            <td class="fw-bold small">${_esc(s.nombre)}</td>
            <td class="text-end fw-bold small" style="color:var(--md-blue-deep,#0A2A66);">${fmtCat.format(s.precio)}</td>
            <td class="small text-muted">${_esc(s.descripcion || '')}</td>
            <td class="text-end">
                <div class="d-flex gap-1 justify-content-end">
                    <button class="btn btn-sm btn-outline-primary border-0" onclick="editarItem('servicio','${s.id}')"><i class="bi bi-pencil"></i></button>
                    <button class="btn btn-sm btn-outline-danger border-0" onclick="eliminarItem('servicio','${s.id}','${_esc(s.nombre)}')"><i class="bi bi-trash"></i></button>
                </div>
            </td>
        </tr>`).join('');
}

// ─── RENDER PRODUCTOS ────────────────────────────────────────────
function renderTablaProductos(lista) {
    const tb = document.getElementById('tbodyProductos');
    if (!tb) return;
    if (!lista.length) {
        tb.innerHTML = '<tr><td colspan="6" class="text-center text-muted py-4"><i class="bi bi-inbox me-2"></i>Sin productos registrados. Agrega el primero.</td></tr>';
        return;
    }
    tb.innerHTML = lista.map(p => `
        <tr>
            <td class="fw-bold small">${_esc(p.nombre)}</td>
            <td class="text-end fw-bold small" style="color:var(--md-blue-deep,#0A2A66);">${fmtCat.format(p.precio)}</td>
            <td class="small text-muted">${_esc(p.presentacion || '')}</td>
            <td class="text-end small">${p.cantidad || 0}</td>
            <td class="small text-muted">${_esc(p.descripcion || '')}</td>
            <td class="text-end">
                <div class="d-flex gap-1 justify-content-end">
                    <button class="btn btn-sm btn-outline-primary border-0" onclick="editarItem('producto','${p.id}')"><i class="bi bi-pencil"></i></button>
                    <button class="btn btn-sm btn-outline-danger border-0" onclick="eliminarItem('producto','${p.id}','${_esc(p.nombre)}')"><i class="bi bi-trash"></i></button>
                </div>
            </td>
        </tr>`).join('');
}

// ─── ABRIR FORM NUEVO ITEM ───────────────────────────────────────
function abrirFormItem(tipo) {
    document.getElementById('itemEditId').value = '';
    document.getElementById('itemTipo').value = tipo;
    document.getElementById('itemNombre').value = '';
    document.getElementById('itemPrecio').value = '';
    document.getElementById('itemDesc').value = '';
    document.getElementById('itemCantidad') && (document.getElementById('itemCantidad').value = '');
    document.getElementById('itemPresentacion') && (document.getElementById('itemPresentacion').value = '');
    document.getElementById('camposProducto').classList.toggle('d-none', tipo !== 'producto');
    document.getElementById('modalItemTitle').textContent = tipo === 'servicio' ? 'Agregar Servicio' : 'Agregar Producto';
    bootstrap.Modal.getOrCreateInstance(document.getElementById('modalItemCatalogo')).show();
}

// ─── EDITAR ITEM ─────────────────────────────────────────────────
function editarItem(tipo, id) {
    const lista = tipo === 'servicio' ? _catData.servicios : _catData.productos;
    const item = lista.find(x => String(x.id) === String(id));
    if (!item) return;

    document.getElementById('itemEditId').value = id;
    document.getElementById('itemTipo').value = tipo;
    document.getElementById('itemNombre').value = item.nombre || '';
    document.getElementById('itemPrecio').value = item.precio || '';
    document.getElementById('itemDesc').value = item.descripcion || '';
    document.getElementById('camposProducto').classList.toggle('d-none', tipo !== 'producto');
    if (tipo === 'producto') {
        document.getElementById('itemCantidad').value = item.cantidad || '';
        document.getElementById('itemPresentacion').value = item.presentacion || '';
    }
    document.getElementById('modalItemTitle').textContent = tipo === 'servicio' ? 'Editar Servicio' : 'Editar Producto';
    bootstrap.Modal.getOrCreateInstance(document.getElementById('modalItemCatalogo')).show();
}

// ─── GUARDAR ITEM (add / edit) ───────────────────────────────────
async function guardarItem() {
    const id     = document.getElementById('itemEditId').value;
    const tipo   = document.getElementById('itemTipo').value;
    const nombre = document.getElementById('itemNombre').value.trim();
    const precio = document.getElementById('itemPrecio').value;
    const desc   = document.getElementById('itemDesc').value.trim();

    if (!nombre || !precio) {
        return Swal.fire('Aviso', 'Nombre y precio son obligatorios.', 'warning');
    }

    const btn = document.getElementById('btnGuardarItem');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Guardando...';

    try {
        const fd = new URLSearchParams({
            accion: id ? 'edit_item' : 'add_item',
            tipo, nombre, precio, descripcion: desc
        });
        if (id) fd.append('id', id);
        if (tipo === 'producto') {
            fd.append('cantidad', document.getElementById('itemCantidad').value || '0');
            fd.append('presentacion', document.getElementById('itemPresentacion').value || '');
        }

        const res = await fetch('../api/catalogo_org_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' });
        const data = await res.json();

        if (data.status !== 'ok') throw new Error(data.message || 'Error al guardar');

        bootstrap.Modal.getInstance(document.getElementById('modalItemCatalogo')).hide();
        Swal.fire({ icon: 'success', title: id ? 'Actualizado' : 'Agregado', timer: 1200, showConfirmButton: false });
        await cargarCatalogoOrg();
    } catch(e) {
        Swal.fire('Error', e.message, 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = '<i class="bi bi-check-lg me-1"></i>Guardar';
    }
}

// ─── ELIMINAR ITEM ───────────────────────────────────────────────
async function eliminarItem(tipo, id, nombre) {
    const result = await Swal.fire({
        title: 'Eliminar ' + (tipo === 'servicio' ? 'Servicio' : 'Producto'),
        html: '<strong>' + _esc(nombre) + '</strong><br><small class="text-muted">Esta accion no se puede deshacer.</small>',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#dc2626',
        cancelButtonColor: '#64748b',
        confirmButtonText: '<i class="bi bi-trash me-1"></i>Eliminar',
        cancelButtonText: 'Cancelar'
    });

    if (!result.isConfirmed) return;

    try {
        const fd = new URLSearchParams({ accion: 'delete_item', tipo, id });
        const res = await fetch('../api/catalogo_org_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' });
        const data = await res.json();
        if (data.status !== 'ok') throw new Error(data.message || 'Error');
        Swal.fire({ icon: 'success', title: 'Eliminado', timer: 1000, showConfirmButton: false });
        await cargarCatalogoOrg();
    } catch(e) {
        Swal.fire('Error', e.message, 'error');
    }
}

// ─── REIMPORTAR DESDE GLOBAL ─────────────────────────────────────
async function importarCatalogoBase() {
    const result = await Swal.fire({
        title: 'Reimportar Catalogo',
        html: 'Se sobrescribiran los servicios y productos actuales con el catalogo base del sistema.<br><small class="text-muted">Esta accion no se puede deshacer.</small>',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#f59e0b',
        cancelButtonColor: '#64748b',
        confirmButtonText: '<i class="bi bi-cloud-download me-1"></i>Reimportar',
        cancelButtonText: 'Cancelar'
    });

    if (!result.isConfirmed) return;

    try {
        const fd = new URLSearchParams({ accion: 'seed_from_global' });
        const res = await fetch('../api/catalogo_org_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' });
        const data = await res.json();
        if (data.status !== 'ok') throw new Error(data.message || 'Error');
        Swal.fire({ icon: 'success', title: 'Catalogo importado', text: data.message, timer: 2000 });
        await cargarCatalogoOrg();
    } catch(e) {
        Swal.fire('Error', e.message, 'error');
    }
}

// ─── UTILIDADES ──────────────────────────────────────────────────
function _esc(str) {
    return String(str || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}
