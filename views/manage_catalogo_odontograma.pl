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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_empresa = $sd->{id_empresa};

# Seguridad: Validar que sea Administrador o Médico
unless ($role =~ /Administrador/i || $role =~ /Medico/i) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<div style='padding:2rem; font-family:sans-serif;'><h3>Acceso Denegado</h3><p>Se requieren permisos de Administrador de Organización para gestionar el catálogo de odontograma.</p></div>";
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
    titulo      => "Gestión de Catálogo de Odontograma",
    skip_header => 1
);

my $archivo_cat = catalogo_org_utils::obtener_ruta_catalogo_odontograma($id_empresa);

print <<HTML;
<link rel="stylesheet" href="../css/ospulso_master.css?v=$^T">
<link rel="stylesheet" href="../css/sdm_mobile_standards.css?v=$^T">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">

<style>
    .cat-kpi-card {
        border-radius: 16px;
        transition: transform 0.2s ease, box-shadow 0.2s ease;
        border: 1px solid rgba(0,0,0,0.06);
    }
    .cat-kpi-card:hover {
        transform: translateY(-3px);
        box-shadow: 0 10px 20px rgba(0,0,0,0.08) !important;
    }
    .color-preview-box {
        width: 22px;
        height: 22px;
        border-radius: 6px;
        display: inline-block;
        vertical-align: middle;
        border: 1px solid rgba(0,0,0,0.2);
    }
</style>

<div class="d-flex">
HTML

utils::sub_sidebar::render_sidebar(
    usuario       => $usuario,
    role          => $role,
    pagina_actual => 'gestion_odontograma'
);

print <<HTML;
    <main class="content-wrapper flex-grow-1 p-3 p-md-4 container-mobile-flush" style="background-color: #f8fafc; min-height: 100vh;">
        <!-- Header de Página -->
        <div class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4">
            <div>
                <div class="d-flex align-items-center gap-2">
                    <span class="badge bg-primary-subtle text-primary border border-primary-subtle px-2 py-1 rounded-pill small">SaaS Dental</span>
                    <h3 class="fw-black text-navy mb-0" style="color: #0A2A66;">Gestión de Catálogo de Odontograma</h3>
                </div>
                <p class="text-muted small mb-0 mt-1">Configuración multi-tenant de patologías, tratamientos, precios sugeridos y colores anatómicos.</p>
            </div>
            <div class="d-flex align-items-center gap-2">
                <button type="button" class="btn btn-outline-secondary btn-sm rounded-pill px-3 shadow-xs fw-bold" onclick="resetCatalogoDefaults()">
                    <i class="bi bi-arrow-counterclockwise me-1"></i> Restablecer Valores de Fábrica
                </button>
                <button type="button" class="btn btn-primary btn-sm rounded-pill px-3 shadow-sm fw-bold" onclick="abrirModalConcepto()">
                    <i class="bi bi-plus-circle-fill me-1"></i> + Nuevo Concepto
                </button>
            </div>
        </div>

        <!-- KPIs Resumen -->
        <div class="row g-3 mb-4">
            <div class="col-6 col-md-3">
                <div class="card cat-kpi-card bg-white p-3 shadow-xs">
                    <span class="text-muted small fw-bold">TOTAL CONCEPTOS</span>
                    <h3 class="fw-black text-dark my-1" id="kpi-total">-</h3>
                    <span class="text-success small" style="font-size: 0.72rem;"><i class="bi bi-check-circle-fill me-1"></i>Activos en Odontograma</span>
                </div>
            </div>
            <div class="col-6 col-md-3">
                <div class="card cat-kpi-card bg-white p-3 shadow-xs border-start border-danger border-4">
                    <span class="text-muted small fw-bold">PATOLOGÍAS / HALLAZGOS</span>
                    <h3 class="fw-black text-danger my-1" id="kpi-patologias">-</h3>
                    <span class="text-muted small" style="font-size: 0.72rem;">Diagnóstico Inicial</span>
                </div>
            </div>
            <div class="col-6 col-md-3">
                <div class="card cat-kpi-card bg-white p-3 shadow-xs border-start border-primary border-4">
                    <span class="text-muted small fw-bold">RESTAURACIONES / TRATAMIENTOS</span>
                    <h3 class="fw-black text-primary my-1" id="kpi-restauraciones">-</h3>
                    <span class="text-muted small" style="font-size: 0.72rem;">Procedimientos Clínicos</span>
                </div>
            </div>
            <div class="col-6 col-md-3">
                <div class="card cat-kpi-card bg-white p-3 shadow-xs border-start border-warning border-4">
                    <span class="text-muted small fw-bold">PRECIO PROMEDIO TRATAMIENTO</span>
                    <h3 class="fw-black text-warning my-1" id="kpi-precio-promedio">\$0.00</h3>
                    <span class="text-muted small" style="font-size: 0.72rem;">Arancel Clínico Base</span>
                </div>
            </div>
        </div>

        <!-- Tabla DataTables -->
        <div class="card shadow-sm border-0 rounded-4 overflow-hidden">
            <div class="card-header bg-white py-3 border-bottom d-flex flex-wrap align-items-center justify-content-between gap-2">
                <div class="btn-group btn-group-sm p-1 bg-light rounded-pill border" role="group">
                    <button type="button" class="btn btn-sm rounded-pill px-3 active fw-bold btn-tab-filtro" data-filter="ALL" onclick="filtrarGrupo('ALL', this)">Todos</button>
                    <button type="button" class="btn btn-sm rounded-pill px-3 fw-bold btn-tab-filtro" data-filter="PATHOLOGY" onclick="filtrarGrupo('PATHOLOGY', this)">Patologías</button>
                    <button type="button" class="btn btn-sm rounded-pill px-3 fw-bold btn-tab-filtro" data-filter="RESTORATION" onclick="filtrarGrupo('RESTORATION', this)">Restauraciones</button>
                    <button type="button" class="btn btn-sm rounded-pill px-3 fw-bold btn-tab-filtro" data-filter="NORMAL" onclick="filtrarGrupo('NORMAL', this)">Normales</button>
                </div>
                <div class="small text-muted">
                    <i class="bi bi-shield-check text-success me-1"></i>Sincronizado con Motor FDI OSPulso
                </div>
            </div>
            <div class="card-body p-0 p-md-3">
                <div class="table-responsive">
                    <table class="table table-hover align-middle mb-0 w-100" id="tablaCatalogoOdonto">
                        <thead class="table-light text-uppercase small text-muted">
                            <tr>
                                <th style="width: 60px;">ID</th>
                                <th>Código</th>
                                <th>Nombre Clínico</th>
                                <th>Grupo</th>
                                <th>Categoría</th>
                                <th>Color</th>
                                <th>Precio Ref.</th>
                                <th>Estado</th>
                                <th style="width: 100px;" class="text-end">Acciones</th>
                            </tr>
                        </thead>
                        <tbody id="tbodyCatalogoOdonto">
                            <tr><td colspan="9" class="text-center py-4 text-muted"><div class="spinner-border spinner-border-sm text-primary me-2"></div>Cargando catálogo...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </main>
</div>

<!-- Modal CRUD Concepto -->
<div class="modal fade" id="modalConceptoOdonto" tabindex="-1" aria-labelledby="modalConceptoLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content rounded-4 border-0 shadow-lg">
            <div class="modal-header border-bottom bg-light">
                <h5 class="modal-title fw-bold text-navy" id="modalConceptoLabel">
                    <i class="bi bi-pencil-square me-2 text-primary"></i><span>Concepto de Odontograma</span>
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form id="formConceptoOdonto" onsubmit="guardarConcepto(event)">
                <div class="modal-body p-4">
                    <input type="hidden" id="input_id" name="id" value="">
                    
                    <div class="row g-3">
                        <div class="col-md-5">
                            <label class="form-label small fw-bold">Código Único (FDI/ISO)</label>
                            <input type="text" class="form-control form-control-sm text-uppercase fw-bold" id="input_code" name="code" required placeholder="EJ: CARIES_LEVE">
                            <small class="text-muted" style="font-size: 0.68rem;">Solo letras, números y guión bajo.</small>
                        </div>
                        <div class="col-md-7">
                            <label class="form-label small fw-bold">Nombre Clínico / Procedimiento</label>
                            <input type="text" class="form-control form-control-sm" id="input_nombre" name="nombre" required placeholder="Ej: Caries Incipiente Esmalte">
                        </div>

                        <div class="col-md-6">
                            <label class="form-label small fw-bold">Grupo SaaS</label>
                            <select class="form-select form-select-sm" id="select_grupo" name="grupo" required onchange="ajustarGrupo(this.value)">
                                <option value="PATHOLOGY">Patología / Hallazgo</option>
                                <option value="RESTORATION">Tratamiento / Restauración</option>
                                <option value="NORMAL">Estado Normal</option>
                            </select>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small fw-bold">Categoría de Impacto</label>
                            <select class="form-select form-select-sm" id="select_categoria" name="categoria" required>
                                <option value="PENDING">Pendiente (Afecta Presupuesto / Rojo)</option>
                                <option value="EXISTING">Existente (Realizado / Azul)</option>
                                <option value="HEALTHY">Sano (Normal / Neutro)</option>
                            </select>
                        </div>

                        <div class="col-md-6">
                            <label class="form-label small fw-bold">Subestado Técnico</label>
                            <select class="form-select form-select-sm" id="select_substatus" name="substatus">
                                <option value="ACTIVE">Activa / Presente</option>
                                <option value="ADAPTED">Adaptada / Buena</option>
                                <option value="DEFECTIVE">Desadaptada / Defectuosa</option>
                                <option value="TEMPORARY">Provisional / Temporal</option>
                                <option value="PONTIC">Póntico de Puente</option>
                                <option value="ABSENT">Ausente</option>
                                <option value="HEALTHY">Sano</option>
                            </select>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small fw-bold">Precio Referencial (MXN)</label>
                            <div class="input-group input-group-sm">
                                <span class="input-group-text">\$</span>
                                <input type="number" step="0.01" min="0" class="form-control form-control-sm fw-bold" id="input_precio" name="precio" value="0.00" required>
                            </div>
                        </div>

                        <div class="col-md-6">
                            <label class="form-label small fw-bold">Color en Odontograma</label>
                            <div class="d-flex align-items-center gap-2">
                                <input type="color" class="form-control form-control-color p-1" id="input_color" name="color_hex" value="#FF3B30" title="Seleccionar Color">
                                <input type="text" class="form-control form-control-sm text-uppercase" id="input_color_text" value="#FF3B30" onchange="document.getElementById('input_color').value = this.value">
                            </div>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small fw-bold">Ícono Bootstrap</label>
                            <input type="text" class="form-control form-control-sm" id="input_icono" name="icono" value="bi-circle-fill text-danger" placeholder="bi-circle-fill text-danger">
                        </div>

                        <div class="col-12">
                            <div class="form-check form-switch mt-2">
                                <input class="form-check-input" type="checkbox" role="switch" id="check_activo" name="activo" value="1" checked>
                                <label class="form-check-label small fw-bold" for="check_activo">Concepto Activo en Odontograma</label>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer bg-light border-top">
                    <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill px-3" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-sm btn-primary rounded-pill px-4 fw-bold" id="btnGuardarConcepto">
                        <i class="bi bi-save me-1"></i> Guardar Concepto
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
HTML

print <<'JS';
<script>
let catalogoData = [];
let dataTableInst = null;
let currentFilter = 'ALL';

document.addEventListener('DOMContentLoaded', () => {
    cargarCatalogo();
    
    document.getElementById('input_color').addEventListener('input', function() {
        document.getElementById('input_color_text').value = this.value.toUpperCase();
    });
});

async function cargarCatalogo() {
    try {
        const resp = await fetch('../api/catalogo_odontograma_api.pl?action=list');
        const data = await resp.json();
        if (data.status === 'success') {
            catalogoData = data.items || [];
            renderTabla();
            calcularKPIs();
        } else {
            Swal.fire('Error', data.message || 'No se pudo cargar el catálogo', 'error');
        }
    } catch (e) {
        console.error('Error cargando catalogo:', e);
        Swal.fire('Error', 'Fallo de conexión al cargar catálogo', 'error');
    }
}

function calcularKPIs() {
    let total = catalogoData.length;
    let patologias = 0;
    let restauraciones = 0;
    let sumaPrecios = 0;
    let countPrecios = 0;

    catalogoData.forEach(item => {
        if (item.activo == 1) {
            if (item.grupo === 'PATHOLOGY') patologias++;
            if (item.grupo === 'RESTORATION') {
                restauraciones++;
                let p = parseFloat(item.precio) || 0;
                if (p > 0) {
                    sumaPrecios += p;
                    countPrecios++;
                }
            }
        }
    });

    let avg = countPrecios > 0 ? (sumaPrecios / countPrecios) : 0;

    document.getElementById('kpi-total').textContent = total;
    document.getElementById('kpi-patologias').textContent = patologias;
    document.getElementById('kpi-restauraciones').textContent = restauraciones;
    document.getElementById('kpi-precio-promedio').textContent = '$' + avg.toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function filtrarGrupo(grupo, btn) {
    currentFilter = grupo;
    document.querySelectorAll('.btn-tab-filtro').forEach(b => b.classList.remove('active', 'btn-primary'));
    btn.classList.add('active');
    renderTabla();
}

function renderTabla() {
    if (dataTableInst) {
        dataTableInst.destroy();
    }

    const tbody = document.getElementById('tbodyCatalogoOdonto');
    tbody.innerHTML = '';

    const filtrados = catalogoData.filter(item => {
        if (currentFilter === 'ALL') return true;
        return item.grupo === currentFilter;
    });

    filtrados.forEach(item => {
        const tr = document.createElement('tr');
        
        let badgeGrupo = '<span class="badge bg-secondary-subtle text-secondary rounded-pill border">Normal</span>';
        if (item.grupo === 'PATHOLOGY') {
            badgeGrupo = '<span class="badge bg-danger-subtle text-danger rounded-pill border border-danger-subtle">Patología</span>';
        } else if (item.grupo === 'RESTORATION') {
            badgeGrupo = '<span class="badge bg-primary-subtle text-primary rounded-pill border border-primary-subtle">Restauración</span>';
        }

        let badgeCat = '<span class="badge bg-light text-muted border">Normal</span>';
        if (item.categoria === 'PENDING') {
            badgeCat = '<span class="badge bg-warning-subtle text-warning-emphasis border border-warning-subtle">Pendiente</span>';
        } else if (item.categoria === 'EXISTING') {
            badgeCat = '<span class="badge bg-info-subtle text-info-emphasis border border-info-subtle">Existente</span>';
        }

        let badgeActivo = item.activo == 1 
            ? '<span class="badge bg-success-subtle text-success border border-success-subtle rounded-pill">Activo</span>'
            : '<span class="badge bg-secondary-subtle text-muted border rounded-pill">Inactivo</span>';

        tr.innerHTML = `
            <td class="text-muted small">${item.id}</td>
            <td><code class="fw-bold text-dark">${item.code}</code></td>
            <td>
                <div class="d-flex align-items-center gap-2">
                    <i class="bi ${item.icono} fs-6"></i>
                    <span class="fw-bold">${item.nombre}</span>
                </div>
            </td>
            <td>${badgeGrupo}</td>
            <td>${badgeCat}</td>
            <td>
                <div class="d-flex align-items-center gap-2">
                    <span class="color-preview-box" style="background-color: ${item.color_hex};"></span>
                    <small class="text-muted font-monospace">${item.color_hex}</small>
                </div>
            </td>
            <td class="fw-bold text-navy">$${parseFloat(item.precio).toFixed(2)}</td>
            <td>${badgeActivo}</td>
            <td class="text-end">
                <button type="button" class="btn btn-sm btn-outline-primary rounded-circle p-1 me-1" onclick="editarConcepto(${item.id})" title="Editar Concepto">
                    <i class="bi bi-pencil-fill" style="font-size: 0.8rem;"></i>
                </button>
                <button type="button" class="btn btn-sm btn-outline-danger rounded-circle p-1" onclick="eliminarConcepto(${item.id}, '${item.nombre}')" title="Desactivar">
                    <i class="bi bi-trash-fill" style="font-size: 0.8rem;"></i>
                </button>
            </td>
        `;
        tbody.appendChild(tr);
    });

    dataTableInst = $('#tablaCatalogoOdonto').DataTable({
        language: {
            url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json'
        },
        pageLength: 25,
        order: [[0, 'asc']]
    });
}

function abrirModalConcepto() {
    document.getElementById('formConceptoOdonto').reset();
    document.getElementById('input_id').value = '';
    document.getElementById('modalConceptoLabel').innerHTML = '<i class="bi bi-plus-circle me-2 text-primary"></i><span>Nuevo Concepto de Odontograma</span>';
    document.getElementById('input_code').readOnly = false;
    document.getElementById('input_color').value = '#FF3B30';
    document.getElementById('input_color_text').value = '#FF3B30';
    document.getElementById('input_precio').value = '0.00';
    document.getElementById('check_activo').checked = true;
    
    new bootstrap.Modal(document.getElementById('modalConceptoOdonto')).show();
}

function editarConcepto(id) {
    const item = catalogoData.find(x => x.id == id);
    if (!item) return;

    document.getElementById('input_id').value = item.id;
    document.getElementById('modalConceptoLabel').innerHTML = '<i class="bi bi-pencil-square me-2 text-primary"></i><span>Editar Concepto de Odontograma</span>';
    document.getElementById('input_code').value = item.code;
    document.getElementById('input_code').readOnly = true; // No modificar clave primaria técnica
    document.getElementById('input_nombre').value = item.nombre;
    document.getElementById('select_grupo').value = item.grupo;
    document.getElementById('select_categoria').value = item.categoria;
    document.getElementById('select_substatus').value = item.substatus;
    document.getElementById('input_precio').value = parseFloat(item.precio).toFixed(2);
    document.getElementById('input_color').value = item.color_hex;
    document.getElementById('input_color_text').value = item.color_hex;
    document.getElementById('input_icono').value = item.icono;
    document.getElementById('check_activo').checked = (item.activo == 1);

    new bootstrap.Modal(document.getElementById('modalConceptoOdonto')).show();
}

function ajustarGrupo(grupo) {
    if (grupo === 'PATHOLOGY') {
        document.getElementById('select_categoria').value = 'PENDING';
        document.getElementById('input_color').value = '#FF3B30';
        document.getElementById('input_color_text').value = '#FF3B30';
        document.getElementById('input_icono').value = 'bi-circle-fill text-danger';
    } else if (grupo === 'RESTORATION') {
        document.getElementById('select_categoria').value = 'EXISTING';
        document.getElementById('input_color').value = '#007AFF';
        document.getElementById('input_color_text').value = '#007AFF';
        document.getElementById('input_icono').value = 'bi-shield-check text-primary';
    } else {
        document.getElementById('select_categoria').value = 'HEALTHY';
        document.getElementById('input_color').value = '#FFFFFF';
        document.getElementById('input_color_text').value = '#FFFFFF';
        document.getElementById('input_icono').value = 'bi-shield-check text-success';
        document.getElementById('input_precio').value = '0.00';
    }
}

async function guardarConcepto(e) {
    e.preventDefault();
    const fd = new FormData(document.getElementById('formConceptoOdonto'));
    fd.append('action', 'save');
    if (!document.getElementById('check_activo').checked) {
        fd.set('activo', '0');
    }

    try {
        const resp = await fetch('../api/catalogo_odontograma_api.pl', {
            method: 'POST',
            body: fd
        });
        const data = await resp.json();
        if (data.status === 'success') {
            bootstrap.Modal.getInstance(document.getElementById('modalConceptoOdonto')).hide();
            Swal.fire({
                icon: 'success',
                title: 'Guardado',
                text: data.message,
                timer: 1500,
                showConfirmButton: false
            });
            cargarCatalogo();
        } else {
            Swal.fire('Error', data.message || 'No se pudo guardar el concepto', 'error');
        }
    } catch (err) {
        console.error('Error guardando concepto:', err);
        Swal.fire('Error', 'Fallo de comunicación con el servidor', 'error');
    }
}

async function eliminarConcepto(id, nombre) {
    const res = await Swal.fire({
        title: '¿Desactivar concepto?',
        text: `El concepto "${nombre}" ya no aparecerá en nuevos odontogramas, pero se conservará en el historial.`,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#64748b',
        confirmButtonText: 'Sí, desactivar',
        cancelButtonText: 'Cancelar'
    });

    if (!res.isConfirmed) return;

    try {
        const resp = await fetch(`../api/catalogo_odontograma_api.pl?action=delete&id=${id}`);
        const data = await resp.json();
        if (data.status === 'success') {
            Swal.fire('Desactivado', data.message, 'success');
            cargarCatalogo();
        } else {
            Swal.fire('Error', data.message || 'No se pudo desactivar', 'error');
        }
    } catch (e) {
        console.error(e);
        Swal.fire('Error', 'Fallo de conexión', 'error');
    }
}

async function resetCatalogoDefaults() {
    const res = await Swal.fire({
        title: '¿Restablecer Catálogo?',
        text: 'Se restablecerán todos los conceptos a los 23 valores de fábrica estándar.',
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#0A2A66',
        cancelButtonColor: '#64748b',
        confirmButtonText: 'Sí, restablecer',
        cancelButtonText: 'Cancelar'
    });

    if (!res.isConfirmed) return;

    try {
        const resp = await fetch('../api/catalogo_odontograma_api.pl?action=reset_defaults');
        const data = await resp.json();
        if (data.status === 'success') {
            Swal.fire('Completado', data.message, 'success');
            cargarCatalogo();
        } else {
            Swal.fire('Error', data.message, 'error');
        }
    } catch (e) {
        console.error(e);
        Swal.fire('Error', 'Fallo de conexión', 'error');
    }
}
</script>
JS

render_bottom_nav(role => $role, pagina_actual => 'gestion_odontograma');
print "</body></html>\n";
