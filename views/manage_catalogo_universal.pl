#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use File::Spec;
use JSON::PP;
use open qw(:std :utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
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

# Seguridad
if ($role ne 'Administrador Organizacion' && $role ne 'Administrador Global' && $role !~ /Recepcionista/i) {
    print $q->header(-status => '403 Forbidden');
    print "<h1>Acceso Denegado</h1><p>Esta sección es exclusiva para el Administrador de la Organización y Recepcionistas.</p>";
    exit;
}

print $q->header(
    -type => 'text/html',
    -charset => 'UTF-8',
    -cache_control => 'no-store, no-cache, must-revalidate, max-age=0',
    -pragma => 'no-cache'
);
render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => "Catálogo Universal",
    skip_header => 1
);

my $id_raiz = catalogo_org_utils::resolver_id_raiz_catalogo($id_empresa);
my $cat_univ = catalogo_org_utils::get_catalogo_universal($id_raiz);

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'servicios');
print <<HTML;
        <link rel="stylesheet" href="../css/sdm_mobile_standards.css?v=$^T">
        <script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex flex-column flex-md-row justify-content-between align-items-md-center gap-3">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-globe me-2"></i>Catálogo Universal</h2>
                    <p class="text-white-50 small mb-0 mt-1">Gestión centralizada del catálogo maestro 3NF</p>
                </div>
            </div>
        </header>

        <div class="container-fluid px-4 pb-5 container-mobile-flush">
            
            <!-- CONTENEDOR DE FORMULARIOS INLINE -->
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 mb-4 d-none animate__animated animate__fadeIn" id="formContainer">
                <div class="card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center" id="formHeader" style="background-color: var(--md-blue-deep) !important;">
                    <h5 class="fw-black mb-0" id="formTitle"><i class="bi bi-pencil-square me-2"></i>Formulario</h5>
                    <button type="button" class="btn-close btn-close-white" onclick="cerrarFormulario()"></button>
                </div>
                <div class="card-body p-4 bg-light rounded-bottom-4" id="formBody">
                    <!-- Los formularios se inyectan dinamicamente con JS -->
                </div>
            </div>

            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 card-mobile-flush" id="mainCard">
                <div class="card-header bg-white border-0 pt-4 px-4 pb-0 d-flex justify-content-between align-items-center">
                    <ul class="nav nav-pills nav-fill flex-grow-1" id="catalogoTabs" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link active rounded-pill fw-bold" data-bs-toggle="tab" data-bs-target="#servicios" type="button" role="tab"><i class="bi bi-list-check me-2"></i>Servicios</button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link rounded-pill fw-bold" data-bs-toggle="tab" data-bs-target="#productos" type="button" role="tab"><i class="bi bi-box-seam me-2"></i>Productos</button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link rounded-pill fw-bold" data-bs-toggle="tab" data-bs-target="#deptos" type="button" role="tab"><i class="bi bi-diagram-3 me-2"></i>Departamentos y Categorías</button>
                        </li>
                    </ul>
                </div>
                
                <div class="card-body p-4">
                    <div class="tab-content">
                        <!-- PESTAÑA SERVICIOS -->
                        <div class="tab-pane fade show active" id="servicios" role="tabpanel">
                            <div class="d-flex justify-content-end mb-3">
                                <button class="btn btn-sdm-primary btn-sm rounded-pill px-3 fw-bold shadow-sm" onclick="abrirFormulario('servicio')">
                                    <i class="bi bi-plus-circle me-1"></i>Nuevo Servicio
                                </button>
                            </div>
                            <div class="table-responsive dataTables_wrapper p-3 rounded-4" style="background-color: #f8fafc; border: 1px solid var(--md-teal-clinical);">
                                <table id="tablaServicios" class="table table-hover align-middle w-100" style="font-size: 0.75rem;">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small fw-bold text-muted text-uppercase border-0">SKU</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Concepto</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Dep/Cat</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Precios (Tarifas)</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0 text-end pe-4">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

my %cats_map;
foreach my $c (@{$cat_univ->{categorias} || []}) { $cats_map{$c->{id_cat}} = { n => $c->{nombre}, d => $c->{id_dep} }; }
my %deps_map;
foreach my $d (@{$cat_univ->{departamentos} || []}) { $deps_map{$d->{id_dep}} = $d->{nombre}; }

foreach my $item (@{$cat_univ->{items} || []}) {
    my $cat = $cats_map{$item->{id_cat}};
    my $cat_name = $cat ? $cat->{n} : 'Desc';
    my $precios_html = "";
    my $precio_base = 0;
    foreach my $p (@{$item->{precios} || []}) {
        $precio_base = $p->{precio_publico} if $p->{tipo_tarifa} eq 'DIA';
        $precios_html .= "<span class='badge bg-info me-1'>$p->{tipo_tarifa}: \$$p->{precio_publico}</span><br>";
    }
    
    print <<HTML;
                                        <tr>
                                            <td data-label="SKU"><span class="badge bg-secondary">$item->{codigo_sku}</span></td>
                                            <td data-label="Concepto" class="fw-bold text-primary">$item->{concepto}</td>
                                            <td data-label="Dep/Cat" class="small text-muted">$cat_name</td>
                                            <td data-label="Precios">$precios_html</td>
                                            <td class="text-end">
                                                <button class="btn btn-sm btn-outline-primary rounded-circle me-1" onclick="abrirFormulario('servicio', '$item->{id_item}', '$item->{codigo_sku}', '$item->{concepto}', '$item->{id_cat}', '$precio_base')"><i class="bi bi-pencil"></i></button>
                                                <button class="btn btn-sm btn-outline-danger rounded-circle" onclick="deleteEntity('servicio', '$item->{id_item}')"><i class="bi bi-trash"></i></button>
                                            </td>
                                        </tr>
HTML
}

print <<HTML;
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        
                        <!-- PESTAÑA PRODUCTOS -->
                        <div class="tab-pane fade" id="productos" role="tabpanel">
                            <div class="d-flex justify-content-end mb-3">
                                <button class="btn btn-sdm-primary btn-sm rounded-pill px-3 fw-bold shadow-sm" onclick="abrirFormulario('producto')">
                                    <i class="bi bi-plus-circle me-1"></i>Nuevo Producto
                                </button>
                            </div>
                            <div class="table-responsive dataTables_wrapper p-3 rounded-4" style="background-color: #f8fafc; border: 1px solid var(--md-teal-clinical);">
                                <table id="tablaProductos" class="table table-hover align-middle w-100" style="font-size: 0.75rem;">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small fw-bold text-muted text-uppercase border-0">ID</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Nombre</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Descripción</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Presentación</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Precio</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0 text-end">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

foreach my $prod (@{$cat_univ->{productos} || []}) {
    print <<HTML;
                                        <tr>
                                            <td><span class="badge bg-secondary">$$prod{id_prod}</span></td>
                                            <td class="fw-bold text-primary">$$prod{nombre}</td>
                                            <td class="small text-muted">$$prod{descripcion}</td>
                                            <td class="small">$$prod{presentacion}</td>
                                            <td class="fw-bold text-success">\$$$prod{precio}</td>
                                            <td class="text-end">
                                                <button class="btn btn-sm btn-outline-primary rounded-circle me-1" onclick="abrirFormulario('producto', '$$prod{id_prod}', '$$prod{nombre}', '$$prod{precio}', '$$prod{cantidad}', '$$prod{presentacion}', '$$prod{descripcion}')"><i class="bi bi-pencil"></i></button>
                                                <button class="btn btn-sm btn-outline-danger rounded-circle" onclick="deleteEntity('producto', '$$prod{id_prod}')"><i class="bi bi-trash"></i></button>
                                            </td>
                                        </tr>
HTML
}

print <<HTML;
                                    </tbody>
                                </table>
                            </div>
                        </div>

                        <!-- PESTAÑA DEPARTAMENTOS -->
                        <div class="tab-pane fade" id="deptos" role="tabpanel">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="d-flex justify-content-between align-items-center mb-3">
                                        <h5 class="fw-bold mb-0">Departamentos</h5>
                                        <button class="btn btn-sdm-primary btn-sm rounded-pill px-3 fw-bold shadow-sm" onclick="abrirFormulario('departamento')">
                                            <i class="bi bi-plus-circle me-1"></i>Nuevo
                                        </button>
                                    </div>
                                    <ul class="list-group list-group-flush border rounded">
HTML

foreach my $dep (@{$cat_univ->{departamentos} || []}) {
    print <<HTML;
                                        <li class="list-group-item d-flex justify-content-between align-items-center">
                                            <div>
                                                <span class="badge bg-primary rounded-pill me-2">$dep->{id_dep}</span>$dep->{nombre}
                                            </div>
                                            <div>
                                                <button class="btn btn-sm text-primary p-1" onclick="abrirFormulario('departamento', '$dep->{id_dep}', '$dep->{nombre}')"><i class="bi bi-pencil"></i></button>
                                                <button class="btn btn-sm text-danger p-1" onclick="deleteEntity('departamento', '$dep->{id_dep}')"><i class="bi bi-trash"></i></button>
                                            </div>
                                        </li>
HTML
}

print <<HTML;
                                    </ul>
                                </div>
                                <div class="col-md-6 mt-4 mt-md-0">
                                    <div class="d-flex justify-content-between align-items-center mb-3">
                                        <h5 class="fw-bold mb-0">Categorías</h5>
                                        <button class="btn btn-sdm-primary btn-sm rounded-pill px-3 fw-bold shadow-sm" onclick="abrirFormulario('categoria')">
                                            <i class="bi bi-plus-circle me-1"></i>Nueva
                                        </button>
                                    </div>
                                    <ul class="list-group list-group-flush border rounded">
HTML

foreach my $cat (@{$cat_univ->{categorias} || []}) {
    print <<HTML;
                                        <li class="list-group-item d-flex justify-content-between align-items-center">
                                            <div>
                                                <span class="badge bg-secondary rounded-pill me-2">$cat->{id_cat}</span>$cat->{nombre}
                                                <small class="text-muted ms-2">(Dep: $cat->{id_dep})</small>
                                            </div>
                                            <div>
                                                <button class="btn btn-sm text-primary p-1" onclick="abrirFormulario('categoria', '$cat->{id_cat}', '$cat->{id_dep}', '$cat->{nombre}')"><i class="bi bi-pencil"></i></button>
                                                <button class="btn btn-sm text-danger p-1" onclick="deleteEntity('categoria', '$cat->{id_cat}')"><i class="bi bi-trash"></i></button>
                                            </div>
                                        </li>
HTML
}

print <<HTML;
                                    </ul>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- DataTables JS & CSS -->
        <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
        <link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">
        <script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
        <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
        <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
        <script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
        <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/pdfmake.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/vfs_fonts.js"></script>
        <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
        <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>
HTML

my $cats_options = "<option value=''>Seleccione...</option>";
foreach my $cat (@{$cat_univ->{categorias} || []}) {
    $cats_options .= "<option value='$cat->{id_cat}'>$cat->{nombre}</option>";
}
my $deps_options = "<option value=''>Seleccione...</option>";
foreach my $dep (@{$cat_univ->{departamentos} || []}) {
    $deps_options .= "<option value='$dep->{id_dep}'>$dep->{nombre}</option>";
}

print <<HTML;
<div id="config-catalogo" style="display:none;" data-cats="$cats_options" data-deps="$deps_options"></div>
HTML

print <<'JS';
        <script>
            const config = document.getElementById('config-catalogo');
            const optsCat = config ? config.dataset.cats : '';
            const optsDep = config ? config.dataset.deps : '';

            function initCatalogoTable(tableId, titleExport) {
                if ($(tableId).length) {
                    $(tableId).DataTable({
                        destroy: true,
                        language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                        dom: '<"p-3 d-flex justify-content-start align-items-center"B>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
                        buttons: {
                            dom: {
                                container: { className: 'dt-buttons export-toolbar' },
                                button: { className: 'btn-export' }
                            },
                            buttons: [
                                { extend: 'copy', text: '<i class="bi bi-clipboard"></i> Copiar', exportOptions: { columns: ':not(:last-child)' } },
                                { extend: 'excel', text: '<i class="bi bi-file-earmark-excel"></i> Excel', title: titleExport, exportOptions: { columns: ':not(:last-child)' } },
                                { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf"></i> PDF', title: titleExport, exportOptions: { columns: ':not(:last-child)' } },
                                { extend: 'print', text: '<i class="bi bi-printer"></i> Imprimir', exportOptions: { columns: ':not(:last-child)' } }
                            ]
                        }
                    });
                }
            }

            $(document).ready(function() {
                initCatalogoTable('#tablaServicios', 'Catálogo Universal - Servicios');
                initCatalogoTable('#tablaProductos', 'Catálogo Universal - Productos');
            });

            // LOGICA DE CRUD FRONTEND
            function cerrarFormulario() {
                document.getElementById('formContainer').classList.add('d-none');
                document.getElementById('mainCard').classList.remove('d-none');
            }

            function abrirFormulario(tipo, ...args) {
                document.getElementById('mainCard').classList.add('d-none');
                const container = document.getElementById('formContainer');
                container.classList.remove('d-none');
                const title = document.getElementById('formTitle');
                const body = document.getElementById('formBody');
                
                let html = '';
                if (tipo === 'departamento') {
                    const id = args[0] || '';
                    const nombre = args[1] || '';
                    title.innerHTML = `<i class="bi bi-diagram-2 me-2"></i>${id ? 'Editar' : 'Nuevo'} Departamento`;
                    html = `
                        <form id="crudForm" onsubmit="saveEntity(event, 'departamento')">
                            <input type="hidden" name="action" value="save_departamento">
                            <input type="hidden" name="id" value="${id}">
                            <div class="mb-3">
                                <label class="form-label fw-bold small text-muted">Nombre del Departamento</label>
                                <input type="text" class="form-control" name="nombre" value="${nombre}" required>
                            </div>
                            <div class="d-flex justify-content-end gap-2">
                                <button type="button" class="btn btn-light border" onclick="cerrarFormulario()">Cancelar</button>
                                <button type="submit" class="btn btn-sdm-primary px-4"><i class="bi bi-save me-2"></i>Guardar</button>
                            </div>
                        </form>
                    `;
                } else if (tipo === 'categoria') {
                    const id = args[0] || '';
                    const id_dep = args[1] || '';
                    const nombre = args[2] || '';
                    title.innerHTML = `<i class="bi bi-tags me-2"></i>${id ? 'Editar' : 'Nueva'} Categoría`;
                    html = `
                        <form id="crudForm" onsubmit="saveEntity(event, 'categoria')">
                            <input type="hidden" name="action" value="save_categoria">
                            <input type="hidden" name="id" value="${id}">
                            <div class="row g-3 mb-3">
                                <div class="col-md-6">
                                    <label class="form-label fw-bold small text-muted">Departamento</label>
                                    <select class="form-select" name="id_dep" id="sel_dep" required>${optsDep}</select>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label fw-bold small text-muted">Nombre de Categoría</label>
                                    <input type="text" class="form-control" name="nombre" value="${nombre}" required>
                                </div>
                            </div>
                            <div class="d-flex justify-content-end gap-2">
                                <button type="button" class="btn btn-light border" onclick="cerrarFormulario()">Cancelar</button>
                                <button type="submit" class="btn btn-sdm-primary px-4"><i class="bi bi-save me-2"></i>Guardar</button>
                            </div>
                        </form>
                    `;
                } else if (tipo === 'producto') {
                    const id = args[0] || '';
                    const nombre = args[1] || '';
                    const precio = args[2] || '';
                    const cantidad = args[3] || '0';
                    const presentacion = args[4] || '';
                    const descripcion = args[5] || '';
                    title.innerHTML = `<i class="bi bi-box-seam me-2"></i>${id ? 'Editar' : 'Nuevo'} Producto`;
                    html = `
                        <form id="crudForm" onsubmit="saveEntity(event, 'producto')">
                            <input type="hidden" name="action" value="save_producto">
                            <input type="hidden" name="id" value="${id}">
                            <div class="row g-3 mb-3">
                                <div class="col-md-8">
                                    <label class="form-label fw-bold small text-muted">Nombre del Producto</label>
                                    <input type="text" class="form-control" name="nombre" value="${nombre}" required>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label fw-bold small text-muted">Precio Público</label>
                                    <input type="number" step="0.01" class="form-control" name="precio" value="${precio}" required>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label fw-bold small text-muted">Stock / Cantidad</label>
                                    <input type="number" class="form-control" name="cantidad" value="${cantidad}">
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label fw-bold small text-muted">Presentación</label>
                                    <input type="text" class="form-control" name="presentacion" value="${presentacion}" placeholder="Ej: Caja 20 tab">
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label fw-bold small text-muted">Descripción Corta</label>
                                    <input type="text" class="form-control" name="descripcion" value="${descripcion}">
                                </div>
                            </div>
                            <div class="d-flex justify-content-end gap-2">
                                <button type="button" class="btn btn-light border" onclick="cerrarFormulario()">Cancelar</button>
                                <button type="submit" class="btn btn-sdm-primary px-4"><i class="bi bi-save me-2"></i>Guardar</button>
                            </div>
                        </form>
                    `;
                } else if (tipo === 'servicio') {
                    const id = args[0] || '';
                    const sku = args[1] || '';
                    const concepto = args[2] || '';
                    const id_cat = args[3] || '';
                    const precio = args[4] || '';
                    title.innerHTML = `<i class="bi bi-activity me-2"></i>${id ? 'Editar' : 'Nuevo'} Servicio`;
                    html = `
                        <form id="crudForm" onsubmit="saveEntity(event, 'servicio')">
                            <input type="hidden" name="action" value="save_servicio">
                            <input type="hidden" name="id_item" value="${id}">
                            <div class="row g-3 mb-3">
                                <div class="col-md-4">
                                    <label class="form-label fw-bold small text-muted">Categoría Mapeada</label>
                                    <select class="form-select" name="id_cat" id="sel_cat" required>${optsCat}</select>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label fw-bold small text-muted">Código SKU</label>
                                    <input type="text" class="form-control" name="codigo_sku" value="${sku}" required>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label fw-bold small text-muted">Precio Base (DIA)</label>
                                    <input type="number" step="0.01" class="form-control" name="precio" value="${precio}" required>
                                </div>
                                <div class="col-md-12">
                                    <label class="form-label fw-bold small text-muted">Concepto / Descripción</label>
                                    <input type="text" class="form-control" name="concepto" value="${concepto}" required>
                                </div>
                            </div>
                            <div class="d-flex justify-content-end gap-2">
                                <button type="button" class="btn btn-light border" onclick="cerrarFormulario()">Cancelar</button>
                                <button type="submit" class="btn btn-sdm-primary px-4"><i class="bi bi-save me-2"></i>Guardar</button>
                            </div>
                        </form>
                    `;
                }
                
                body.innerHTML = html;
                if (tipo === 'categoria' && args[1]) document.getElementById('sel_dep').value = args[1];
                if (tipo === 'servicio' && args[3]) document.getElementById('sel_cat').value = args[3];
            }

            async function saveEntity(e, tipo) {
                e.preventDefault();
                const form = e.target;
                const fd = new FormData(form);
                try {
                    const res = await fetch('../api/crud_catalogo_universal_api.pl', { method: 'POST', body: fd });
                    const data = await res.json();
                    if (data.success) {
                        Swal.fire('¡Éxito!', data.msg, 'success').then(() => location.reload());
                    } else {
                        Swal.fire('Error', data.error || 'Ocurrió un error al guardar.', 'error');
                    }
                } catch(e) {
                    Swal.fire('Error', 'Problema de conexión con el servidor.', 'error');
                }
            }

            function deleteEntity(tipo, id) {
                Swal.fire({
                    title: '¿Estás seguro?',
                    text: 'Esta acción eliminará el registro de forma permanente. Si otros registros dependen de él, la operación podría cancelarse para mantener la integridad.',
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonColor: '#d33',
                    cancelButtonColor: '#3085d6',
                    confirmButtonText: 'Sí, eliminar',
                    cancelButtonText: 'Cancelar'
                }).then(async (result) => {
                    if (result.isConfirmed) {
                        try {
                            const fd = new FormData();
                            fd.append('action', 'delete_' + tipo);
                            fd.append('id', id);
                            const res = await fetch('../api/crud_catalogo_universal_api.pl', { method: 'POST', body: fd });
                            const data = await res.json();
                            if (data.success) {
                                Swal.fire('Eliminado', data.msg, 'success').then(() => location.reload());
                            } else {
                                Swal.fire('No se pudo eliminar', data.error || 'Ocurrió un error interno.', 'error');
                            }
                        } catch(e) {
                            Swal.fire('Error', 'Problema de conexión con el servidor.', 'error');
                        }
                    }
                });
            }
        </script>
JS

utils::sub_sidebar::render_sidebar_footer();
print $q->end_html;
