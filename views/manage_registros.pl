#!/usr/bin/perl
use cPanelUserConfig;
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

# RBAC: Seguridad Estricta - Solo Administrador Global
if ($role ne 'Administrador Global') {
    render_acceso_denegado(
        q             => $q,
        usuario       => $usuario,
        role          => $role,
        mensaje       => 'Esta sección de control de cuentas SaaS es exclusiva para el Administrador Global.',
        rol_requerido => 'Administrador Global'
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
    titulo      => "Gestión de Registros SaaS",
    skip_header => 1
);

render_sidebar(
    pagina_actual => 'registros',
    usuario       => $usuario,
    role          => $role,
    id_empresa    => $id_empresa
);

print <<'PAGE_HTML';
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/responsive/2.5.0/css/responsive.bootstrap5.min.css">
<link rel="stylesheet" href="../css/sdm_mobile_standards.css">
<link rel="stylesheet" href="../css/ospulso_master_v2.css">

<main class="main-content container-fluid py-3 px-md-4 container-mobile-flush">
    <!-- Breadcrumb & Header -->
    <div class="d-flex flex-wrap justify-content-between align-items-center mb-4">
        <div>
            <nav aria-label="breadcrumb">
                <ol class="breadcrumb mb-1">
                    <li class="breadcrumb-item"><a href="dashboard.pl" class="text-decoration-none">Inicio</a></li>
                    <li class="breadcrumb-item text-muted">Administración</li>
                    <li class="breadcrumb-item active text-primary fw-semibold" aria-current="page">Gestión de Registros</li>
                </ol>
            </nav>
            <h2 class="h4 fw-bold text-dark mb-0">
                <i class="bi bi-person-lines-fill text-primary me-2"></i>Control de Registros y Cuentas SaaS
            </h2>
            <p class="text-muted small mb-0">Supervisión, activación de pruebas y gestión del ciclo de vida de clínicas registradas.</p>
        </div>
        <div class="mt-2 mt-md-0 d-flex gap-2">
            <button class="btn btn-outline-primary btn-sm btn-mobile-standard rounded-pill shadow-sm" onclick="cargarRegistros()">
                <i class="bi bi-arrow-clockwise me-1"></i>Actualizar
            </button>
        </div>
    </div>

    <!-- KPI Metric Cards -->
    <div class="row g-3 mb-4">
        <div class="col-6 col-lg-3">
            <div class="card card-mobile-flush border-0 shadow-sm rounded-4 h-100 p-3 bg-white border-start border-primary border-4">
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <span class="text-muted small fw-semibold text-uppercase">Total Registros</span>
                        <h3 class="fw-bold text-dark mt-1 mb-0" id="kpi-total">0</h3>
                    </div>
                    <div class="rounded-circle p-2 bg-primary bg-opacity-10 text-primary">
                        <i class="bi bi-building fs-4"></i>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-6 col-lg-3">
            <div class="card card-mobile-flush border-0 shadow-sm rounded-4 h-100 p-3 bg-white border-start border-info border-4">
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <span class="text-muted small fw-semibold text-uppercase">Cuentas Demo</span>
                        <h3 class="fw-bold text-info mt-1 mb-0" id="kpi-demos">0</h3>
                    </div>
                    <div class="rounded-circle p-2 bg-info bg-opacity-10 text-info">
                        <i class="bi bi-hourglass-split fs-4"></i>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-6 col-lg-3">
            <div class="card card-mobile-flush border-0 shadow-sm rounded-4 h-100 p-3 bg-white border-start border-success border-4">
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <span class="text-muted small fw-semibold text-uppercase">Licencias Activas</span>
                        <h3 class="fw-bold text-success mt-1 mb-0" id="kpi-activas">0</h3>
                    </div>
                    <div class="rounded-circle p-2 bg-success bg-opacity-10 text-success">
                        <i class="bi bi-patch-check-fill fs-4"></i>
                    </div>
                </div>
            </div>
        </div>
        <div class="col-6 col-lg-3">
            <div class="card card-mobile-flush border-0 shadow-sm rounded-4 h-100 p-3 bg-white border-start border-warning border-4">
                <div class="d-flex align-items-center justify-content-between">
                    <div>
                        <span class="text-muted small fw-semibold text-uppercase">Por Vencer (&le; 5 d)</span>
                        <h3 class="fw-bold text-warning mt-1 mb-0" id="kpi-por-vencer">0</h3>
                    </div>
                    <div class="rounded-circle p-2 bg-warning bg-opacity-10 text-warning">
                        <i class="bi bi-exclamation-triangle-fill fs-4"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Data Table Container -->
    <div class="card card-mobile-flush border-0 shadow-sm rounded-4 overflow-hidden bg-white mb-4">
        <div class="card-header bg-white border-bottom border-light py-3 d-flex flex-wrap justify-content-between align-items-center gap-2">
            <div class="d-flex align-items-center gap-2">
                <i class="bi bi-table text-primary fs-5"></i>
                <h5 class="card-title fw-bold text-dark mb-0">Directorio de Cuentas y Solicitudes</h5>
            </div>
            <!-- Quick Filter Tabs -->
            <div class="btn-group btn-group-sm rounded-pill p-1 bg-light" role="group" id="filterStatusGroup">
                <button type="button" class="btn btn-sm btn-white rounded-pill active fw-semibold" onclick="filtrarTabla('todos', this)">Todos</button>
                <button type="button" class="btn btn-sm btn-light rounded-pill fw-semibold text-muted" onclick="filtrarTabla('demo', this)">Demos</button>
                <button type="button" class="btn btn-sm btn-light rounded-pill fw-semibold text-muted" onclick="filtrarTabla('pagada', this)">Pagadas</button>
                <button type="button" class="btn btn-sm btn-light rounded-pill fw-semibold text-muted" onclick="filtrarTabla('urgente', this)">Por Vencer</button>
                <button type="button" class="btn btn-sm btn-light rounded-pill fw-semibold text-muted" onclick="filtrarTabla('suspendido', this)">Suspendidas</button>
            </div>
        </div>
        <div class="card-body p-3">
            <div class="table-responsive">
                <table id="tablaRegistros" class="table table-hover align-middle w-100 table-diamond">
                    <thead>
                        <tr>
                            <th class="text-center" style="width: 70px;">ID</th>
                            <th>Clínica / Institución</th>
                            <th>Titular / Contacto</th>
                            <th>Vigencia / Expiración</th>
                            <th class="text-center">Estado</th>
                            <th class="text-center" style="width: 140px;">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tbodyRegistros">
                        <tr>
                            <td colspan="6" class="text-center py-4 text-muted">
                                <div class="spinner-border text-primary spinner-border-sm me-2" role="status"></div>
                                Cargando catálogo de clínicas registradas...
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</main>

<!-- Modal: Extender Periodo Demo -->
<div class="modal fade" id="modalExtenderDemo" tabindex="-1" aria-labelledby="modalExtenderDemoLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content border-0 shadow rounded-4">
            <div class="modal-header border-bottom border-light pb-2">
                <h5 class="modal-title fw-bold text-dark" id="modalExtenderDemoLabel">
                    <i class="bi bi-hourglass-top text-info me-2"></i>Extender Periodo Demo
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
            </div>
            <div class="modal-body p-4">
                <input type="hidden" id="extIdNegocio">
                <div class="text-center mb-3">
                    <div class="rounded-circle bg-info bg-opacity-10 text-info d-inline-flex p-3 mb-2">
                        <i class="bi bi-calendar-plus fs-2"></i>
                    </div>
                    <h6 class="fw-bold mb-1" id="extNombreNegocio">Nombre de la Clínica</h6>
                    <p class="text-muted small mb-0">Selecciona el periodo adicional de prueba para este usuario.</p>
                </div>
                <div class="row g-2 mb-3">
                    <div class="col-4">
                        <button type="button" class="btn btn-outline-info w-100 py-2 rounded-3 fw-semibold" onclick="aplicarExtension(15)">
                            +15 Días
                        </button>
                    </div>
                    <div class="col-4">
                        <button type="button" class="btn btn-info text-white w-100 py-2 rounded-3 fw-bold" onclick="aplicarExtension(30)">
                            +30 Días
                        </button>
                    </div>
                    <div class="col-4">
                        <button type="button" class="btn btn-outline-info w-100 py-2 rounded-3 fw-semibold" onclick="aplicarExtension(60)">
                            +60 Días
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Modal: Editar Registro Rápido -->
<div class="modal fade" id="modalEditarRegistro" tabindex="-1" aria-labelledby="modalEditarRegistroLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 shadow rounded-4">
            <div class="modal-header border-bottom border-light pb-2">
                <h5 class="modal-title fw-bold text-dark" id="modalEditarRegistroLabel">
                    <i class="bi bi-pencil-square text-primary me-2"></i>Editar Datos de la Clínica
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
            </div>
            <div class="modal-body p-4">
                <form id="formEditarRegistro" onsubmit="guardarEdicionRegistro(event)">
                    <input type="hidden" id="editId">
                    <div class="row g-3">
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-semibold text-muted">Nombre de la Clínica / Consultorio</label>
                            <input type="text" class="form-control rounded-3" id="editNombre" required>
                        </div>
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-semibold text-muted">Razón Social</label>
                            <input type="text" class="form-control rounded-3" id="editRazon">
                        </div>
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-semibold text-muted">Teléfono / WhatsApp</label>
                            <input type="tel" class="form-control rounded-3" id="editTelefono" required>
                        </div>
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-semibold text-muted">Correo Electrónico Oficial</label>
                            <input type="email" class="form-control rounded-3" id="editEmail" required>
                        </div>
                        <div class="col-12 col-md-4">
                            <label class="form-label small fw-semibold text-muted">RFC</label>
                            <input type="text" class="form-control rounded-3" id="editRfc">
                        </div>
                        <div class="col-12 col-md-4">
                            <label class="form-label small fw-semibold text-muted">Código Postal</label>
                            <input type="text" class="form-control rounded-3" id="editCp">
                        </div>
                        <div class="col-12 col-md-4">
                            <label class="form-label small fw-semibold text-muted">Colonia</label>
                            <input type="text" class="form-control rounded-3" id="editColonia">
                        </div>
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-semibold text-muted">Municipio / Alcaldía</label>
                            <input type="text" class="form-control rounded-3" id="editMunicipio">
                        </div>
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-semibold text-muted">Estado / Entidad</label>
                            <input type="text" class="form-control rounded-3" id="editEntidad">
                        </div>
                        <div class="col-12">
                            <label class="form-label small fw-semibold text-muted">Dirección / Calle y Número</label>
                            <input type="text" class="form-control rounded-3" id="editDomicilio">
                        </div>
                    </div>
                    <div class="d-flex justify-content-end gap-2 mt-4">
                        <button type="button" class="btn btn-light rounded-pill px-4" data-bs-dismiss="modal">Cancelar</button>
                        <button type="submit" class="btn btn-primary rounded-pill px-4 fw-bold">Guardar Cambios</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>

<script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.datatables.net/responsive/2.5.0/js/dataTables.responsive.min.js"></script>
<script src="https://cdn.datatables.net/responsive/2.5.0/js/responsive.bootstrap5.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
PAGE_HTML

render_bottom_nav(pagina_actual => 'registros', rol => $role);

# Script JS aislado con comilla simple para evitar colisiones de sigilos
print <<'JS';
<script>
let dtRegistros = null;
let listaRegistrosGlobal = [];

document.addEventListener('DOMContentLoaded', function() {
    cargarRegistros();
});

function cargarRegistros() {
    fetch('../api/admin_registros_api.pl?action=listar', {
        headers: { 'Cache-Control': 'no-cache' }
    })
    .then(res => res.json())
    .then(data => {
        if (data.status === 'ok') {
            listaRegistrosGlobal = data.registros || [];
            actualizarKpis(data.kpis || {});
            renderizarTabla(listaRegistrosGlobal);
        } else {
            Swal.fire('Error', data.message || 'Error al obtener registros', 'error');
        }
    })
    .catch(err => {
        console.error('Error cargando registros:', err);
        Swal.fire('Error de Conexión', 'No se pudo comunicar con el servidor.', 'error');
    });
}

function actualizarKpis(kpis) {
    document.getElementById('kpi-total').textContent = kpis.total || 0;
    document.getElementById('kpi-demos').textContent = kpis.demos || 0;
    document.getElementById('kpi-activas').textContent = kpis.activas || 0;
    document.getElementById('kpi-por-vencer').textContent = kpis.por_vencer || 0;
}

function renderizarTabla(registros) {
    if ($.fn.DataTable.isDataTable('#tablaRegistros')) {
        $('#tablaRegistros').DataTable().destroy();
    }

    const tbody = document.getElementById('tbodyRegistros');
    tbody.innerHTML = '';

    if (registros.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-muted">No se encontraron clínicas registradas.</td></tr>';
        return;
    }

    registros.forEach(r => {
        let badgeHtml = '';
        if (r.activo === '0') {
            badgeHtml = '<span class="badge bg-danger text-white rounded-pill px-2 py-1"><i class="bi bi-slash-circle me-1"></i>Suspendida</span>';
        } else if (r.estado_visual === 'vencido') {
            badgeHtml = '<span class="badge bg-secondary text-white rounded-pill px-2 py-1"><i class="bi bi-clock-history me-1"></i>Vencida</span>';
        } else if (r.estado_visual === 'demo_urgente') {
            badgeHtml = `<span class="badge bg-warning text-dark rounded-pill px-2 py-1"><i class="bi bi-exclamation-circle me-1"></i>Demo (${r.dias_restantes}d)</span>`;
        } else if (r.estado_visual === 'demo') {
            badgeHtml = `<span class="badge bg-info text-white rounded-pill px-2 py-1"><i class="bi bi-hourglass me-1"></i>Demo (${r.dias_restantes}d)</span>`;
        } else {
            badgeHtml = '<span class="badge bg-success text-white rounded-pill px-2 py-1"><i class="bi bi-check-circle me-1"></i>Activa</span>';
        }

        const cleanTel = (r.telefono || '').replace(/\D/g, '');
        const waLink = cleanTel ? `https://wa.me/52${cleanTel}?text=Hola%20${encodeURIComponent(r.titular_nombre || r.nombre_negocio)},%20te%20contacto%20de%20OSPulso.` : '#';

        const tr = document.createElement('tr');
        tr.dataset.estado = r.estado_visual;
        tr.dataset.activo = r.activo;

        tr.innerHTML = `
            <td class="text-center fw-bold text-muted">${r.id}</td>
            <td>
                <div class="fw-bold text-dark">${escapeHtml(r.nombre_negocio)}</div>
                <div class="small text-muted"><i class="bi bi-geo-alt me-1"></i>${escapeHtml(r.municipio || '')}, ${escapeHtml(r.entidad || '')}</div>
            </td>
            <td>
                <div class="fw-semibold text-dark">${escapeHtml(r.titular_nombre || 'N/A')}</div>
                <div class="small text-muted"><i class="bi bi-envelope me-1"></i>${escapeHtml(r.email || r.titular_email || '')}</div>
                <div class="small text-muted"><i class="bi bi-telephone me-1"></i>${escapeHtml(r.telefono || 'Sin teléfono')}</div>
            </td>
            <td>
                <div class="small fw-semibold text-dark">Inicio: ${r.inicio || 'N/A'}</div>
                <div class="small text-muted">Fin: ${r.fin || 'N/A'}</div>
            </td>
            <td class="text-center">${badgeHtml}</td>
            <td class="text-center">
                <div class="btn-group btn-group-sm" role="group">
                    ${cleanTel ? `<a href="${waLink}" target="_blank" class="btn btn-outline-success" title="Contactar por WhatsApp"><i class="bi bi-whatsapp"></i></a>` : ''}
                    <button class="btn btn-outline-info" title="Extender Periodo Demo" onclick="abrirModalExtender('${r.id}', '${escapeJs(r.nombre_negocio)}')">
                        <i class="bi bi-clock-history"></i>
                    </button>
                    <button class="btn btn-outline-primary" title="Editar Información" onclick="abrirModalEditar('${r.id}')">
                        <i class="bi bi-pencil"></i>
                    </button>
                    <button class="btn ${r.activo === '1' ? 'btn-outline-danger' : 'btn-outline-success'}" title="${r.activo === '1' ? 'Suspender Cuenta' : 'Activar Cuenta'}" onclick="toggleEstado('${r.id}', '${r.activo}')">
                        <i class="bi ${r.activo === '1' ? 'bi-lock' : 'bi-unlock'}"></i>
                    </button>
                </div>
            </td>
        `;
        tbody.appendChild(tr);
    });

    dtRegistros = $('#tablaRegistros').DataTable({
        language: {
            url: 'https://cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json'
        },
        pageLength: 10,
        responsive: true,
        order: [[0, 'desc']]
    });
}

function filtrarTabla(filtro, btn) {
    const parent = document.getElementById('filterStatusGroup');
    parent.querySelectorAll('button').forEach(b => {
        b.classList.remove('active', 'btn-white');
        b.classList.add('btn-light', 'text-muted');
    });
    btn.classList.add('active', 'btn-white');
    btn.classList.remove('btn-light', 'text-muted');

    if (!dtRegistros) return;

    if (filtro === 'todos') {
        dtRegistros.search('').columns().search('').draw();
    } else if (filtro === 'demo') {
        dtRegistros.column(4).search('Demo').draw();
    } else if (filtro === 'pagada') {
        dtRegistros.column(4).search('Activa').draw();
    } else if (filtro === 'urgente') {
        dtRegistros.column(4).search('Demo \\([0-5]d\\)', true, false).draw();
    } else if (filtro === 'suspendido') {
        dtRegistros.column(4).search('Suspendida').draw();
    }
}

function abrirModalExtender(id, nombre) {
    document.getElementById('extIdNegocio').value = id;
    document.getElementById('extNombreNegocio').textContent = nombre;
    const modal = new bootstrap.Modal(document.getElementById('modalExtenderDemo'));
    modal.show();
}

function aplicarExtension(dias) {
    const id = document.getElementById('extIdNegocio').value;
    if (!id) return;

    fetch('../api/admin_registros_api.pl', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `action=extender_demo&id=${encodeURIComponent(id)}&dias=${dias}`
    })
    .then(res => res.json())
    .then(data => {
        bootstrap.Modal.getInstance(document.getElementById('modalExtenderDemo')).hide();
        if (data.status === 'ok') {
            Swal.fire('¡Éxito!', data.message, 'success');
            cargarRegistros();
        } else {
            Swal.fire('Error', data.message || 'No se pudo extender', 'error');
        }
    })
    .catch(err => Swal.fire('Error', 'Fallo de conexión', 'error'));
}

function abrirModalEditar(id) {
    fetch(`../api/admin_registros_api.pl?action=obtener&id=${encodeURIComponent(id)}`)
    .then(res => res.json())
    .then(data => {
        if (data.status === 'ok' && data.registro) {
            const r = data.registro;
            document.getElementById('editId').value = r.id;
            document.getElementById('editNombre').value = r.nombre_negocio || '';
            document.getElementById('editRazon').value = r.razon_social || '';
            document.getElementById('editTelefono').value = r.telefono || '';
            document.getElementById('editEmail').value = r.contacto_email || '';
            document.getElementById('editRfc').value = r.rfc || '';
            document.getElementById('editCp').value = r.codigo_postal || '';
            document.getElementById('editColonia').value = r.colonia || '';
            document.getElementById('editMunicipio').value = r.municipio || '';
            document.getElementById('editEntidad').value = r.entidad || '';
            document.getElementById('editDomicilio').value = r.domicilio || '';

            const modal = new bootstrap.Modal(document.getElementById('modalEditarRegistro'));
            modal.show();
        } else {
            Swal.fire('Error', data.message || 'No se encontró la clínica', 'error');
        }
    })
    .catch(err => Swal.fire('Error', 'Fallo de conexión', 'error'));
}

function guardarEdicionRegistro(e) {
    e.preventDefault();
    const id = document.getElementById('editId').value;
    const params = new URLSearchParams({
        action: 'editar',
        id: id,
        nombre_negocio: document.getElementById('editNombre').value,
        razon_social: document.getElementById('editRazon').value,
        telefono: document.getElementById('editTelefono').value,
        contacto_email: document.getElementById('editEmail').value,
        rfc: document.getElementById('editRfc').value,
        codigo_postal: document.getElementById('editCp').value,
        colonia: document.getElementById('editColonia').value,
        municipio: document.getElementById('editMunicipio').value,
        entidad: document.getElementById('editEntidad').value,
        domicilio: document.getElementById('editDomicilio').value
    });

    fetch('../api/admin_registros_api.pl', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
    })
    .then(res => res.json())
    .then(data => {
        bootstrap.Modal.getInstance(document.getElementById('modalEditarRegistro')).hide();
        if (data.status === 'ok') {
            Swal.fire('Actualizado', data.message, 'success');
            cargarRegistros();
        } else {
            Swal.fire('Error', data.message || 'No se pudo actualizar', 'error');
        }
    })
    .catch(err => Swal.fire('Error', 'Fallo de comunicación con el servidor', 'error'));
}

function toggleEstado(id, estadoActual) {
    const nuevoEstado = estadoActual === '1' ? '0' : '1';
    const accionTexto = nuevoEstado === '1' ? 'Activar' : 'Suspender';

    Swal.fire({
        title: `¿Confirmas ${accionTexto} esta cuenta?`,
        text: nuevoEstado === '0' ? 'La clínica no podrá acceder al sistema hasta ser reactivada.' : 'La clínica recuperará el acceso inmediato a la plataforma.',
        icon: nuevoEstado === '0' ? 'warning' : 'question',
        showCancelButton: true,
        confirmButtonText: `Sí, ${accionTexto}`,
        cancelButtonText: 'Cancelar',
        confirmButtonColor: nuevoEstado === '0' ? '#dc3545' : '#198754'
    }).then(result => {
        if (result.isConfirmed) {
            fetch('../api/admin_registros_api.pl', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: `action=actualizar_estado&id=${encodeURIComponent(id)}&activo=${nuevoEstado}`
            })
            .then(res => res.json())
            .then(data => {
                if (data.status === 'ok') {
                    Swal.fire('Éxito', data.message, 'success');
                    cargarRegistros();
                } else {
                    Swal.fire('Error', data.message || 'No se pudo cambiar el estado', 'error');
                }
            })
            .catch(err => Swal.fire('Error', 'Fallo de conexión', 'error'));
        }
    });
}

function escapeHtml(text) {
    if (!text) return '';
    return text.toString()
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function escapeJs(text) {
    if (!text) return '';
    return text.toString().replace(/'/g, "\\'").replace(/"/g, '\\"');
}
</script>
</body>
</html>
JS
