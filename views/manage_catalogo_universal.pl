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
    render_acceso_denegado(
        q => $q, usuario => $usuario, role => $role,
        mensaje => 'Esta sección es exclusiva para el Administrador de la Organización y Recepcionistas.',
        rol_requerido => 'Administrador Organización o Recepcionista'
    );
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
        <link rel="stylesheet" href="../css/ospulso_master_v2.css?v=$^T">
        <link rel="stylesheet" href="../css/sdm_mobile_standards.css?v=$^T">
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-3 shadow-sm" style="border-bottom-left-radius: 16px; border-bottom-right-radius: 16px; margin-bottom: 0.5rem;">
            <div class="d-flex flex-column flex-md-row justify-content-between align-items-md-center gap-2">
                <div>
                    <h3 class="fw-black mb-0"><i class="bi bi-globe me-2"></i>Catálogo Universal</h3>
                    <p class="text-white-50 small mb-0">Gestión centralizada del catálogo maestro 3NF</p>
                </div>
            </div>
        </header>

        <div class="container-fluid px-1 pb-2 container-mobile-flush catalogo-container-flat">
            
            <!-- CONTENEDOR DE FORMULARIOS INLINE -->
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 mb-3 d-none animate__animated animate__fadeIn" id="formContainer">
                <div class="card-header border-0 text-white py-2 px-3 rounded-top-4 d-flex justify-content-between align-items-center" id="formHeader" style="background: linear-gradient(135deg, var(--inst-navy-deep) 0%, var(--inst-navy-mid) 100%) !important;">
                    <h6 class="fw-black mb-0" id="formTitle"><i class="bi bi-pencil-square me-2"></i>Formulario</h6>
                    <button type="button" class="btn-close btn-close-white" onclick="cerrarFormulario()"></button>
                </div>
                <div class="card-body p-3 bg-light rounded-bottom-4" id="formBody">
                    <!-- Los formularios se inyectan dinamicamente con JS -->
                </div>
            </div>

            <!-- CONTENEDOR PRINCIPAL FLUIDO (SIN CAPAS NI MARCOS REDUNDANTES) -->
            <div id="mainCard" class="w-100">
                <div class="bg-transparent border-0 pt-1 px-1 pb-2 d-flex justify-content-between align-items-center">
                    <ul class="nav nav-pills nav-fill flex-grow-1 gap-2" id="catalogoTabs" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link active rounded-pill fw-bold py-1.5" data-bs-toggle="tab" data-bs-target="#servicios" type="button" role="tab"><i class="bi bi-list-check me-2"></i>Servicios</button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link rounded-pill fw-bold py-1.5" data-bs-toggle="tab" data-bs-target="#productos" type="button" role="tab"><i class="bi bi-box-seam me-2"></i>Productos</button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link rounded-pill fw-bold py-1.5" data-bs-toggle="tab" data-bs-target="#deptos" type="button" role="tab"><i class="bi bi-diagram-3 me-2"></i>Departamentos y Categorías</button>
                        </li>
                    </ul>
                </div>
                
                <div class="p-0 pt-1">
                    <div class="tab-content">
                        <!-- PESTAÑA SERVICIOS -->
                        <div class="tab-pane fade show active" id="servicios" role="tabpanel">
HTML

my %cats_map;
foreach my $c (@{$cat_univ->{categorias} || []}) { $cats_map{$c->{id_cat}} = { n => $c->{nombre}, d => $c->{id_dep} }; }
my %deps_map;
foreach my $d (@{$cat_univ->{departamentos} || []}) { $deps_map{$d->{id_dep}} = $d->{nombre}; }

my $filter_deps_options = "<option value=''>-- Todos los Deptos --</option>";
foreach my $dep (@{$cat_univ->{departamentos} || []}) {
    $filter_deps_options .= "<option value='$dep->{id_dep}'>$dep->{nombre}</option>";
}
my $filter_cats_options = "<option value=''>-- Todas las Categorías --</option>";
foreach my $cat (@{$cat_univ->{categorias} || []}) {
    $filter_cats_options .= "<option value='$cat->{id_cat}' data-dep-id='$cat->{id_dep}'>$cat->{nombre}</option>";
}

print <<HTML;
                            <!-- PANEL DE FILTROS PERSONALIZADOS (DEPARTAMENTO, CATEGORIA Y TEXTO LIBRE) -->
                            <div class="card card-filter-diamond">
                                <div class="row g-2 align-items-end">
                                    <div class="col-12 col-md-3">
                                        <label class="form-label mb-1"><i class="bi bi-diagram-3 me-1"></i>Departamento</label>
                                        <select id="filtro_dep" class="form-select filter-control-equal" onchange="onFiltroDepChange()">
                                            $filter_deps_options
                                        </select>
                                    </div>
                                    <div class="col-12 col-md-3">
                                        <label class="form-label mb-1"><i class="bi bi-tags me-1"></i>Categoría</label>
                                        <select id="filtro_cat" class="form-select filter-control-equal" onchange="aplicarFiltrosTabla()">
                                            $filter_cats_options
                                        </select>
                                    </div>
                                    <div class="col-12 col-md-4">
                                        <label class="form-label mb-1"><i class="bi bi-search me-1"></i>Texto Libre</label>
                                        <div class="position-relative">
                                            <input type="text" id="filtro_texto" class="form-control filter-control-equal pe-4" placeholder="Buscar SKU, concepto, precio..." onkeyup="aplicarFiltrosTabla()">
                                            <i class="bi bi-x-circle-fill text-muted position-absolute end-0 top-50 translate-middle-y me-2 cursor-pointer" onclick="limpiarFiltroTexto()" style="display:none;" id="btn_limpiar_texto"></i>
                                        </div>
                                    </div>
                                    <div class="col-12 col-md-2 d-flex align-items-center justify-content-md-end gap-1">
                                        <button type="button" class="btn btn-navy-outline filter-control-equal px-2.5 fw-bold" onclick="limpiarTodosFiltros()" title="Limpiar Filtros">
                                            <i class="bi bi-arrow-counterclockwise"></i>
                                        </button>
                                        <button type="button" class="btn btn-navy-primary filter-control-equal px-2.5 px-lg-3 fw-bold" onclick="abrirFormulario('servicio')">
                                            <i class="bi bi-plus-circle me-1"></i>Nuevo
                                        </button>
                                    </div>
                                </div>
                            </div>

                            <div class="card card-table-diamond">
                                <div class="table-responsive dataTables_wrapper p-0">
                                    <table id="tablaServicios" class="table table-hover align-middle w-100 table-custom-header" style="font-size: 0.78rem;">
                                        <thead>
                                            <tr>
                                                <th class="border-0" style="width: 110px;">SKU</th>
                                                <th class="border-0">Concepto</th>
                                                <th class="border-0">Dep/Cat</th>
                                                <th class="border-0" style="width: 140px; max-width: 140px;">Precios (Tarifas)</th>
                                                <th class="border-0 text-end text-nowrap" style="width: 95px; min-width: 95px;">Acciones</th>
                                            </tr>
                                        </thead>
                                        <tbody>
HTML

foreach my $item (@{$cat_univ->{items} || []}) {
    my $cat = $cats_map{$item->{id_cat}};
    my $cat_id = $item->{id_cat} // '';
    my $cat_name = $cat ? $cat->{n} : 'Desc';
    my $dep_id = $cat ? ($cat->{d} // '') : '';
    my $dep_name = ($cat && $deps_map{$cat->{d}}) ? $deps_map{$cat->{d}} : '';
    my $dep_cat_label = $dep_name ? "$dep_name / $cat_name" : $cat_name;
    
    my $precios_html = "";
    foreach my $p (@{$item->{precios} || []}) {
        $precios_html .= "<span class='badge me-1 mb-1' style='background-color: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0;'>$p->{tipo_tarifa}: \$$p->{precio_publico}</span>";
    }
    
    my $extra_info = "";
    if ($item->{indicaciones} && $item->{indicaciones} ne 'Sin preparación previa') {
        $extra_info .= "<div class='text-muted small text-truncate' style='max-width: 320px; font-size: 0.72rem;' title='$item->{indicaciones}'><i class='bi bi-info-circle me-1 text-primary'></i>$item->{indicaciones}</div>";
    }
    if ($item->{tiempo_entrega} && $item->{tiempo_entrega} ne 'Inmediato') {
        $extra_info .= "<span class='badge bg-light text-secondary border' style='font-size: 0.65rem;'><i class='bi bi-clock me-1'></i>$item->{tiempo_entrega}</span>";
    }
    
    print <<HTML;
                                        <tr data-dep-id="$dep_id" data-cat-id="$cat_id">
                                            <td data-label="SKU"><span class="badge" style="background-color: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; font-weight: 700;">$item->{codigo_sku}</span></td>
                                            <td data-label="Concepto">
                                                <div class="fw-bold" style="color: var(--inst-navy-deep);">$item->{concepto}</div>
                                                $extra_info
                                            </td>
                                            <td data-label="Dep/Cat" class="small text-muted">$dep_cat_label</td>
                                            <td data-label="Precios" style="width: 150px; max-width: 150px;">$precios_html</td>
                                            <td class="text-end text-nowrap" style="width: 95px; min-width: 95px;">
                                                <div class="d-inline-flex align-items-center justify-content-end gap-1">
                                                    <button class="btn btn-sm btn-navy-outline rounded-circle" style="width: 32px; height: 32px; padding: 0;" onclick="abrirFormulario('servicio', '$item->{id_item}')" title="Editar Servicio"><i class="bi bi-pencil"></i></button>
                                                    <button class="btn btn-sm btn-outline-danger rounded-circle" style="width: 32px; height: 32px; padding: 0;" onclick="deleteEntity('servicio', '$item->{id_item}')" title="Eliminar Servicio"><i class="bi bi-trash"></i></button>
                                                </div>
                                            </td>
                                        </tr>
HTML
}

print <<HTML;
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                        
                        <!-- PESTAÑA PRODUCTOS -->
                        <div class="tab-pane fade" id="productos" role="tabpanel">
                            <div class="d-flex justify-content-end mb-3">
                                <button type="button" class="btn btn-navy-primary btn-sm rounded-pill px-3 fw-bold shadow-sm" onclick="abrirFormulario('producto')">
                                    <i class="bi bi-plus-circle me-1"></i>Nuevo Producto
                                </button>
                            </div>
                            <div class="card card-table-diamond">
                                <div class="table-responsive dataTables_wrapper p-0">
                                    <table id="tablaProductos" class="table table-hover align-middle w-100 table-custom-header" style="font-size: 0.78rem;">
                                        <thead>
                                            <tr>
                                                <th class="border-0" style="width: 80px;">ID</th>
                                                <th class="border-0">Nombre</th>
                                                <th class="border-0">Descripción</th>
                                                <th class="border-0">Presentación</th>
                                                <th class="border-0" style="width: 110px;">Precio</th>
                                                <th class="border-0 text-end text-nowrap" style="width: 95px; min-width: 95px;">Acciones</th>
                                            </tr>
                                        </thead>
                                        <tbody>
HTML

foreach my $prod (@{$cat_univ->{productos} || []}) {
    print <<HTML;
                                        <tr>
                                            <td><span class="badge bg-secondary">$$prod{id_prod}</span></td>
                                            <td class="fw-bold" style="color: var(--inst-navy-deep);">$$prod{nombre}</td>
                                            <td class="small text-muted">$$prod{descripcion}</td>
                                            <td class="small">$$prod{presentacion}</td>
                                            <td class="fw-bold text-success">\$$$prod{precio}</td>
                                            <td class="text-end text-nowrap" style="width: 95px; min-width: 95px;">
                                                <div class="d-inline-flex align-items-center justify-content-end gap-1">
                                                    <button class="btn btn-sm btn-navy-outline rounded-circle" style="width: 32px; height: 32px; padding: 0;" onclick="abrirFormulario('producto', '$$prod{id_prod}', '$$prod{nombre}', '$$prod{precio}', '$$prod{cantidad}', '$$prod{presentacion}', '$$prod{descripcion}')" title="Editar Producto"><i class="bi bi-pencil"></i></button>
                                                    <button class="btn btn-sm btn-outline-danger rounded-circle" style="width: 32px; height: 32px; padding: 0;" onclick="deleteEntity('producto', '$$prod{id_prod}')" title="Eliminar Producto"><i class="bi bi-trash"></i></button>
                                                </div>
                                            </td>
                                        </tr>
HTML
}

print <<HTML;
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>

                        <!-- PESTAÑA DEPARTAMENTOS -->
                        <div class="tab-pane fade" id="deptos" role="tabpanel">
                            <div class="row">
                                <div class="col-md-6">
                                    <div class="d-flex justify-content-between align-items-center mb-3">
                                        <h5 class="fw-bold mb-0" style="color: var(--inst-navy-deep);">Departamentos</h5>
                                        <button type="button" class="btn btn-navy-primary btn-sm rounded-pill px-3 fw-bold shadow-sm" onclick="abrirFormulario('departamento')">
                                            <i class="bi bi-plus-circle me-1"></i>Nuevo
                                        </button>
                                    </div>
                                    <ul class="list-group list-group-flush border rounded-4 shadow-sm overflow-hidden">
HTML

foreach my $dep (@{$cat_univ->{departamentos} || []}) {
    print <<HTML;
                                        <li class="list-group-item d-flex justify-content-between align-items-center py-3">
                                            <div>
                                                <span class="badge rounded-pill me-2" style="background-color: var(--inst-navy-deep); color: white;">$dep->{id_dep}</span><strong style="color: var(--inst-navy-deep);">$dep->{nombre}</strong>
                                            </div>
                                            <div>
                                                <button class="btn btn-sm btn-navy-outline rounded-circle me-1" style="width: 30px; height: 30px; padding: 0;" onclick="abrirFormulario('departamento', '$dep->{id_dep}', '$dep->{nombre}')"><i class="bi bi-pencil"></i></button>
                                                <button class="btn btn-sm btn-outline-danger rounded-circle" style="width: 30px; height: 30px; padding: 0;" onclick="deleteEntity('departamento', '$dep->{id_dep}')"><i class="bi bi-trash"></i></button>
                                            </div>
                                        </li>
HTML
}

print <<HTML;
                                    </ul>
                                </div>
                                <div class="col-md-6 mt-4 mt-md-0">
                                    <div class="d-flex justify-content-between align-items-center mb-3">
                                        <h5 class="fw-bold mb-0" style="color: var(--inst-navy-deep);">Categorías</h5>
                                        <button type="button" class="btn btn-navy-primary btn-sm rounded-pill px-3 fw-bold shadow-sm" onclick="abrirFormulario('categoria')">
                                            <i class="bi bi-plus-circle me-1"></i>Nueva
                                        </button>
                                    </div>
                                    <ul class="list-group list-group-flush border rounded-4 shadow-sm overflow-hidden">
HTML

foreach my $cat (@{$cat_univ->{categorias} || []}) {
    print <<HTML;
                                        <li class="list-group-item d-flex justify-content-between align-items-center py-3">
                                            <div>
                                                <span class="badge bg-secondary rounded-pill me-2">$cat->{id_cat}</span><strong>$cat->{nombre}</strong>
                                                <small class="text-muted ms-2">(Dep: $cat->{id_dep})</small>
                                            </div>
                                            <div>
                                                <button class="btn btn-sm btn-navy-outline rounded-circle me-1" style="width: 30px; height: 30px; padding: 0;" onclick="abrirFormulario('categoria', '$cat->{id_cat}', '$cat->{id_dep}', '$cat->{nombre}')"><i class="bi bi-pencil"></i></button>
                                                <button class="btn btn-sm btn-outline-danger rounded-circle" style="width: 30px; height: 30px; padding: 0;" onclick="deleteEntity('categoria', '$cat->{id_cat}')"><i class="bi bi-trash"></i></button>
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

my $deps_json = encode_json($cat_univ->{departamentos} || []);
my $cats_json = encode_json($cat_univ->{categorias} || []);

print <<HTML;
<div id="config-catalogo" style="display:none;" data-cats="$cats_options" data-deps="$deps_options"></div>
<script>
    window.CATALOGO_DEPS = $deps_json;
    window.CATALOGO_CATS = $cats_json;
</script>
HTML

print <<'JS';
        <script>
            const config = document.getElementById('config-catalogo');
            const optsCat = config ? config.dataset.cats : '';
            const optsDep = config ? config.dataset.deps : '';

            function escapeHtml(text) {
                if (!text) return '';
                return String(text)
                    .replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
                    .replace(/"/g, "&quot;")
                    .replace(/'/g, "&#039;");
            }

            function filtrarCategoriasPorDep(depId, targetCatSelectId = 'sel_cat', selectedCatId = '') {
                const catSelect = document.getElementById(targetCatSelectId);
                if (!catSelect) return;
                
                if (!depId) {
                    catSelect.innerHTML = '<option value="">-- Primero seleccione Departamento --</option>';
                    catSelect.disabled = true;
                    return;
                }
                
                const filtered = (window.CATALOGO_CATS || []).filter(c => String(c.id_dep) === String(depId));
                let options = '<option value="">-- Seleccione Categoría --</option>';
                
                if (filtered.length === 0) {
                    options = '<option value="">-- Sin categorías en este departamento --</option>';
                    catSelect.disabled = true;
                } else {
                    catSelect.disabled = false;
                    filtered.forEach(c => {
                        const sel = String(c.id_cat) === String(selectedCatId) ? 'selected' : '';
                        options += `<option value="${c.id_cat}" ${sel}>${escapeHtml(c.nombre)}</option>`;
                    });
                }
                catSelect.innerHTML = options;
            }

            // Registrar filtro personalizado de DataTables para Departamento, Categoría y Texto Libre
            if (typeof $.fn !== 'undefined' && $.fn.dataTable && !window.dtSearchPushed) {
                window.dtSearchPushed = true;
                $.fn.dataTable.ext.search.push(function(settings, data, dataIndex) {
                    const tableId = settings.nTable ? settings.nTable.id : '';
                    if (tableId !== 'tablaServicios') return true;

                    const depVal = $('#filtro_dep').val();
                    const catVal = $('#filtro_cat').val();
                    const textVal = $('#filtro_texto').val() ? $('#filtro_texto').val().trim().toLowerCase() : '';

                    const rowNode = settings.aoData[dataIndex] ? settings.aoData[dataIndex].nTr : null;
                    if (!rowNode) return true;

                    const rowDepId = $(rowNode).attr('data-dep-id') || '';
                    const rowCatId = $(rowNode).attr('data-cat-id') || '';
                    const rowText  = $(rowNode).text().toLowerCase();

                    if (depVal && String(rowDepId) !== String(depVal)) return false;
                    if (catVal && String(rowCatId) !== String(catVal)) return false;
                    if (textVal && !rowText.includes(textVal)) return false;

                    return true;
                });
            }

            function onFiltroDepChange() {
                const depId = $('#filtro_dep').val();
                const catSelect = $('#filtro_cat');
                
                if (!depId) {
                    let options = '<option value="">-- Todas las Categorías --</option>';
                    (window.CATALOGO_CATS || []).forEach(c => {
                        options += `<option value="${c.id_cat}" data-dep-id="${c.id_dep}">${escapeHtml(c.nombre)}</option>`;
                    });
                    catSelect.html(options);
                } else {
                    const filtered = (window.CATALOGO_CATS || []).filter(c => String(c.id_dep) === String(depId));
                    let options = '<option value="">-- Todas las Categorías --</option>';
                    if (filtered.length === 0) {
                        options = '<option value="">-- Sin categorías --</option>';
                    } else {
                        filtered.forEach(c => {
                            options += `<option value="${c.id_cat}" data-dep-id="${c.id_dep}">${escapeHtml(c.nombre)}</option>`;
                        });
                    }
                    catSelect.html(options);
                }
                aplicarFiltrosTabla();
            }

            function aplicarFiltrosTabla() {
                const txt = $('#filtro_texto').val();
                if (txt) {
                    $('#btn_limpiar_texto').show();
                } else {
                    $('#btn_limpiar_texto').hide();
                }

                if ($.fn.DataTable.isDataTable('#tablaServicios')) {
                    $('#tablaServicios').DataTable().draw();
                }
            }

            function limpiarFiltroTexto() {
                $('#filtro_texto').val('');
                aplicarFiltrosTabla();
            }

            function limpiarTodosFiltros() {
                $('#filtro_dep').val('');
                onFiltroDepChange();
                $('#filtro_texto').val('');
                $('#btn_limpiar_texto').hide();
                if ($.fn.DataTable.isDataTable('#tablaServicios')) {
                    $('#tablaServicios').DataTable().search('').draw();
                }
            }

            function initCatalogoTable(tableId, titleExport) {
                if ($(tableId).length) {
                    $(tableId).DataTable({
                        destroy: true,
                        language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                        dom: '<"d-flex flex-wrap justify-content-between align-items-center mb-3"B>rt<"d-flex justify-content-between align-items-center mt-3 flex-wrap"i p>',
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

            function generarNomenclaturaSku() {
                const idInput = document.querySelector('#crudForm input[name="id_item"]');
                if (idInput && idInput.value) return; // En edición, conservar SKU existente

                const selDep = document.getElementById('sel_dep_servicio');
                const selCat = document.getElementById('sel_cat');
                const skuInput = document.getElementById('input_sku');
                if (!selDep || !selCat || !skuInput) return;

                const depText = selDep.options[selDep.selectedIndex] ? selDep.options[selDep.selectedIndex].text : '';
                const catText = selCat.options[selCat.selectedIndex] ? selCat.options[selCat.selectedIndex].text : '';

                if (!depText || depText.includes('--') || !catText || catText.includes('--')) return;

                const depClean = depText.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
                const catClean = catText.replace(/[^A-Za-z0-9]/g, '').toUpperCase();

                if (depClean.length >= 3 && catClean.length >= 1) {
                    const dep3 = depClean.substring(0, 3);
                    const cat1 = catClean.substring(0, 1);
                    skuInput.value = `${dep3}${cat1}-00`;
                }
            }

            function onServicioDepChange(depId) {
                filtrarCategoriasPorDep(depId, 'sel_cat');
                generarNomenclaturaSku();
            }

            function onServicioCatChange(catId) {
                generarNomenclaturaSku();
            }

            const TIPOS_TARIFAS_DISPONIBLES = [
                { id: 'ESTANDAR', label: 'ESTÁNDAR (Público General / Base)' },
                { id: 'MUNICIPIO', label: 'MUNICIPIO (Convenio Sindical / Estatal)' },
                { id: 'LUNES_A_SABADO', label: 'LUNES A SÁBADO (Tarifa Ordinaria)' },
                { id: 'DOMINGOS_Y_FESTIVOS', label: 'DOMINGOS Y FESTIVOS (Recargo)' },
                { id: 'FESTIVO', label: 'DÍA FESTIVO' },
                { id: 'NORMAL', label: 'TURNO NORMAL' },
                { id: 'MATUTINO', label: 'TURNO MATUTINO' },
                { id: 'NOCTURNO', label: 'TURNO NOCTURNO / URGENCIAS' },
                { id: 'SABADO_TARDE_DOMINGO_FESTIVO', label: 'SÁBADO TARDE / DOMINGO / FESTIVO' },
                { id: 'PAQUETE_TODO_INCLUIDO', label: 'PAQUETE TODO INCLUIDO' },
                { id: 'PAQUETE_SOLO_CLINICA', label: 'PAQUETE SOLO CLÍNICA' }
            ];

            function renderFilaTarifa(tipo, precio, costo, canDelete = true) {
                const tbody = document.getElementById('tbodyTarifas');
                if (!tbody) return;

                let optionsHtml = '';
                TIPOS_TARIFAS_DISPONIBLES.forEach(t => {
                    const sel = (t.id === tipo) ? 'selected' : '';
                    optionsHtml += `<option value="${t.id}" ${sel}>${escapeHtml(t.label)}</option>`;
                });

                const isEstandar = (tipo === 'ESTANDAR');
                const tr = document.createElement('tr');
                tr.className = 'tarifa-row align-middle';
                tr.innerHTML = `
                    <td class="py-1.5">
                        ${isEstandar ? `
                            <input type="hidden" class="tarifa-tipo" value="ESTANDAR">
                            <span class="badge px-2.5 py-1.5 fw-bold" style="background:#e0f2fe; color:#0369a1; border: 1px solid #bae6fd; font-size: 0.8rem;">
                                <i class="bi bi-shield-check me-1"></i>ESTÁNDAR (Público General / Base)
                            </span>
                        ` : `
                            <select class="form-select form-select-sm tarifa-tipo" style="font-size: 0.8rem;" required>
                                ${optionsHtml}
                            </select>
                        `}
                    </td>
                    <td class="py-1.5">
                        <div class="input-group input-group-sm">
                            <span class="input-group-text bg-light text-muted fw-bold">$</span>
                            <input type="number" step="0.01" min="0.01" class="form-control form-control-sm fw-bold text-dark tarifa-precio" value="${precio || ''}" placeholder="0.00" required>
                        </div>
                    </td>
                    <td class="py-1.5">
                        <div class="input-group input-group-sm">
                            <span class="input-group-text bg-light text-muted">$</span>
                            <input type="number" step="0.01" min="0.00" class="form-control form-control-sm tarifa-costo" value="${costo || '0.00'}" placeholder="0.00">
                        </div>
                    </td>
                    <td class="text-center py-1.5">
                        ${isEstandar ? `
                            <span class="text-muted small" title="Tarifa obligatoria requerida"><i class="bi bi-lock-fill"></i></span>
                        ` : `
                            <button type="button" class="btn btn-sm btn-outline-danger border-0 rounded-circle" onclick="this.closest('tr').remove()" title="Quitar Tarifa">
                                <i class="bi bi-x-circle-fill fs-6"></i>
                            </button>
                        `}
                    </td>
                `;
                tbody.appendChild(tr);
            }

            function agregarFilaTarifa(tipo = '', precio = '', costo = '0.00') {
                if (!tipo) {
                    const tiposActuales = Array.from(document.querySelectorAll('#tbodyTarifas .tarifa-tipo')).map(el => el.value);
                    const disponibles = TIPOS_TARIFAS_DISPONIBLES.filter(t => !tiposActuales.includes(t.id));
                    tipo = disponibles.length > 0 ? disponibles[0].id : 'NORMAL';
                }
                renderFilaTarifa(tipo, precio, costo, true);
            }

            function agregarTarifaRapidaMunicipio() {
                const tiposActuales = Array.from(document.querySelectorAll('#tbodyTarifas .tarifa-tipo')).map(el => el.value);
                if (tiposActuales.includes('MUNICIPIO')) {
                    Swal.fire('Información', 'La tarifa MUNICIPIO ya está agregada en la matriz.', 'info');
                    return;
                }
                renderFilaTarifa('MUNICIPIO', '', '0.00', true);
            }

            async function abrirFormulario(tipo, ...args) {
                document.getElementById('mainCard').classList.add('d-none');
                const container = document.getElementById('formContainer');
                container.classList.remove('d-none');
                const title = document.getElementById('formTitle');
                const body = document.getElementById('formBody');
                
                if (tipo === 'departamento') {
                    const id = args[0] || '';
                    const nombre = args[1] || '';
                    title.innerHTML = `<i class="bi bi-diagram-2 me-2"></i>${id ? 'Editar' : 'Nuevo'} Departamento`;
                    body.innerHTML = `
                        <form id="crudForm" onsubmit="saveEntity(event, 'departamento')">
                            <input type="hidden" name="action" value="save_departamento">
                            <input type="hidden" name="id" value="${id}">
                            <div class="mb-3">
                                <label class="form-label fw-bold small text-muted">Nombre del Departamento</label>
                                <input type="text" class="form-control text-uppercase" name="nombre" value="${nombre}" oninput="this.value = this.value.toUpperCase()" style="text-transform: uppercase;" required>
                            </div>
                            <div class="d-flex justify-content-end gap-2">
                                <button type="button" class="btn btn-light border" onclick="cerrarFormulario()">Cancelar</button>
                                <button type="submit" class="btn btn-navy-primary px-4"><i class="bi bi-save me-2"></i>Guardar</button>
                            </div>
                        </form>
                    `;
                } else if (tipo === 'categoria') {
                    const id = args[0] || '';
                    const id_dep = args[1] || '';
                    const nombre = args[2] || '';
                    
                    let depOptionsCat = '<option value="">-- Seleccione Departamento --</option>';
                    if (window.CATALOGO_DEPS) {
                        window.CATALOGO_DEPS.forEach(d => {
                            const sel = String(d.id_dep) === String(id_dep) ? 'selected' : '';
                            depOptionsCat += `<option value="${d.id_dep}" ${sel}>${escapeHtml(d.nombre)}</option>`;
                        });
                    }

                    title.innerHTML = `<i class="bi bi-tags me-2"></i>${id ? 'Editar' : 'Nueva'} Categoría`;
                    body.innerHTML = `
                        <form id="crudForm" onsubmit="saveEntity(event, 'categoria')">
                            <input type="hidden" name="action" value="save_categoria">
                            <input type="hidden" name="id" value="${id}">
                            <div class="row g-3 mb-3">
                                <div class="col-md-6">
                                    <label class="form-label fw-bold small text-muted">Departamento</label>
                                    <select class="form-select" name="id_dep" id="sel_dep" required>${depOptionsCat}</select>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label fw-bold small text-muted">Nombre de Categoría</label>
                                    <input type="text" class="form-control text-uppercase" name="nombre" value="${nombre}" oninput="this.value = this.value.toUpperCase()" style="text-transform: uppercase;" required>
                                </div>
                            </div>
                            <div class="d-flex justify-content-end gap-2">
                                <button type="button" class="btn btn-light border" onclick="cerrarFormulario()">Cancelar</button>
                                <button type="submit" class="btn btn-navy-primary px-4"><i class="bi bi-save me-2"></i>Guardar</button>
                            </div>
                        </form>
                    `;
                    if (id_dep) document.getElementById('sel_dep').value = id_dep;
                } else if (tipo === 'producto') {
                    const id = args[0] || '';
                    const nombre = args[1] || '';
                    const precio = args[2] || '';
                    const cantidad = args[3] || '0';
                    const presentacion = args[4] || '';
                    const descripcion = args[5] || '';
                    title.innerHTML = `<i class="bi bi-box-seam me-2"></i>${id ? 'Editar' : 'Nuevo'} Producto`;
                    body.innerHTML = `
                        <form id="crudForm" onsubmit="saveEntity(event, 'producto')">
                            <input type="hidden" name="action" value="save_producto">
                            <input type="hidden" name="id" value="${id}">
                            <div class="row g-3 mb-3">
                                <div class="col-md-8">
                                    <label class="form-label fw-bold small text-muted">Nombre del Producto</label>
                                    <input type="text" class="form-control text-uppercase" name="nombre" value="${nombre}" oninput="this.value = this.value.toUpperCase()" style="text-transform: uppercase;" required>
                                </div>
                                <div class="col-md-4">
                                    <label class="form-label fw-bold small text-muted">Precio Público</label>
                                    <input type="number" step="0.01" min="0.01" class="form-control" name="precio" value="${precio}" placeholder="Monto mayor a 0" required>
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
                                <button type="submit" class="btn btn-navy-primary px-4"><i class="bi bi-save me-2"></i>Guardar</button>
                            </div>
                        </form>
                    `;
                } else if (tipo === 'servicio') {
                    const id = args[0] || '';
                    title.innerHTML = `<i class="bi bi-activity me-2"></i>${id ? 'Editar' : 'Nuevo'} Servicio`;

                    if (id) {
                        body.innerHTML = `
                            <div class="text-center py-4">
                                <div class="spinner-border text-primary" role="status"></div>
                                <p class="text-muted small mt-2">Cargando datos y tarifas del servicio...</p>
                            </div>
                        `;
                        try {
                            const res = await fetch(`../api/crud_catalogo_universal_api.pl?action=get_servicio&id_item=${id}`);
                            const data = await res.json();
                            if (!data.success || !data.servicio) {
                                Swal.fire('Error', data.error || 'No se pudieron obtener los datos del servicio.', 'error');
                                cerrarFormulario();
                                return;
                            }
                            renderFormServicio(data.servicio);
                        } catch (err) {
                            Swal.fire('Error', 'Error de conexión al cargar el servicio.', 'error');
                            cerrarFormulario();
                        }
                    } else {
                        renderFormServicio({
                            id_item: '',
                            codigo_sku: '',
                            id_cat: '',
                            id_dep: '',
                            concepto: '',
                            aplica_iva: 0,
                            indicaciones: 'Sin preparación previa',
                            tiempo_entrega: 'Inmediato',
                            tarifas: [
                                { tipo_tarifa: 'ESTANDAR', precio_publico: '', costo_proveedor: '0.00' }
                            ]
                        });
                    }
                }
            }

            function renderFormServicio(s) {
                const body = document.getElementById('formBody');
                const id = s.id_item || '';
                const currentDepId = s.id_dep || '';
                const id_cat = s.id_cat || '';

                let depOptions = '<option value="">-- Seleccione Departamento --</option>';
                if (window.CATALOGO_DEPS) {
                    window.CATALOGO_DEPS.forEach(d => {
                        const sel = String(d.id_dep) === String(currentDepId) ? 'selected' : '';
                        depOptions += `<option value="${d.id_dep}" ${sel}>${escapeHtml(d.nombre)}</option>`;
                    });
                }

                const html = `
                    <form id="crudForm" onsubmit="saveEntity(event, 'servicio')">
                        <input type="hidden" name="action" value="save_servicio">
                        <input type="hidden" name="id_item" value="${id}">

                        <datalist id="datalistIndicaciones">
                            <option value="Sin preparación previa">
                            <option value="Ayuno mínimo de 8 a 12 horas (agua simple permitida)">
                            <option value="Presentarse con vejiga llena (ingerir 1L de agua 1h antes)">
                            <option value="Suspender medicamentos previos bajo indicación médica">
                            <option value="Aseo de la zona con agua y jabón neutro">
                            <option value="Presentar estudios previos o recetas médicas">
                            <option value="Reposo previo de 15 minutos en clínica">
                            <option value="Cita previa requerida con especialista">
                        </datalist>

                        <datalist id="datalistTiempos">
                            <option value="Inmediato">
                            <option value="Mismo día">
                            <option value="2 a 4 horas (Urgencias)">
                            <option value="24 horas hábiles">
                            <option value="48 horas hábiles">
                            <option value="3 a 5 días hábiles">
                        </datalist>

                        <!-- SECCIÓN 1: CLASIFICACIÓN Y SKU -->
                        <div class="row g-2 mb-3">
                            <div class="col-12 col-md-4">
                                <label class="form-label fw-bold small text-muted mb-1"><i class="bi bi-diagram-3 me-1"></i>Departamento</label>
                                <select class="form-select form-select-sm" id="sel_dep_servicio" onchange="onServicioDepChange(this.value)" required>
                                    ${depOptions}
                                </select>
                            </div>
                            <div class="col-12 col-md-4">
                                <label class="form-label fw-bold small text-muted mb-1"><i class="bi bi-tags me-1"></i>Categoría</label>
                                <select class="form-select form-select-sm" name="id_cat" id="sel_cat" onchange="onServicioCatChange(this.value)" required>
                                    <option value="">-- Primero seleccione Departamento --</option>
                                </select>
                            </div>
                            <div class="col-12 col-md-4">
                                <label class="form-label fw-bold small text-muted mb-1"><i class="bi bi-upc-scan me-1"></i>Código SKU</label>
                                <div class="input-group input-group-sm">
                                    <input type="text" class="form-control form-control-sm text-uppercase font-monospace fw-bold" name="codigo_sku" id="input_sku" value="${escapeHtml(s.codigo_sku)}" oninput="this.value = this.value.toUpperCase()" style="text-transform: uppercase;" placeholder="Ej: CON-MG-0001" required>
                                    <button class="btn btn-outline-secondary" type="button" onclick="generarNomenclaturaSku()" title="Autogenerar SKU"><i class="bi bi-magic"></i></button>
                                </div>
                            </div>
                        </div>

                        <!-- SECCIÓN 2: CONCEPTO E IVA -->
                        <div class="row g-2 mb-3">
                            <div class="col-12 col-md-9">
                                <label class="form-label fw-bold small text-muted mb-1"><i class="bi bi-file-earmark-text me-1"></i>Concepto / Descripción del Servicio</label>
                                <input type="text" class="form-control form-control-sm text-uppercase fw-semibold" name="concepto" value="${escapeHtml(s.concepto)}" oninput="this.value = this.value.toUpperCase()" style="text-transform: uppercase;" placeholder="Nombre completo del servicio o procedimiento" required>
                            </div>
                            <div class="col-12 col-md-3">
                                <label class="form-label fw-bold small text-muted mb-1"><i class="bi bi-percent me-1"></i>Régimen IVA</label>
                                <select class="form-select form-select-sm" name="aplica_iva">
                                    <option value="0" ${s.aplica_iva ? '' : 'selected'}>Exento (Tasa 0% Médico)</option>
                                    <option value="1" ${s.aplica_iva ? 'selected' : ''}>Grava IVA (16%)</option>
                                </select>
                            </div>
                        </div>

                        <!-- SECCIÓN 3: CAMPOS CLÍNICOS PRE-ESTUDIO -->
                        <div class="row g-2 mb-3">
                            <div class="col-12 col-md-8">
                                <label class="form-label fw-bold small text-muted mb-1"><i class="bi bi-info-circle me-1"></i>Indicaciones / Preparación Previa al Paciente</label>
                                <input type="text" list="datalistIndicaciones" class="form-control form-control-sm" name="indicaciones" value="${escapeHtml(s.indicaciones || 'Sin preparación previa')}" placeholder="Ej: Ayuno de 8 hrs, Vejiga llena...">
                            </div>
                            <div class="col-12 col-md-4">
                                <label class="form-label fw-bold small text-muted mb-1"><i class="bi bi-clock-history me-1"></i>Tiempo Estimado de Entrega</label>
                                <input type="text" list="datalistTiempos" class="form-control form-control-sm" name="tiempo_entrega" value="${escapeHtml(s.tiempo_entrega || 'Inmediato')}" placeholder="Ej: Inmediato, 24 horas...">
                            </div>
                        </div>

                        <!-- SECCIÓN 4: MATRIZ DINÁMICA DE PRECIOS Y TARIFAS -->
                        <div class="card border-0 shadow-sm bg-white rounded-3 p-3 mb-3" style="border: 1px solid #e2e8f0 !important;">
                            <div class="d-flex flex-wrap justify-content-between align-items-center mb-2 gap-2">
                                <div>
                                    <h6 class="fw-bold mb-0 text-dark"><i class="bi bi-cash-stack me-1 text-success"></i>Matriz de Tarifas y Precios</h6>
                                    <small class="text-muted">Configure las tarifas aplicables (Privado, Convenio Municipio, Horarios Especiales).</small>
                                </div>
                                <div class="d-flex gap-1">
                                    <button type="button" class="btn btn-sm btn-outline-info rounded-pill px-2.5 fw-semibold" onclick="agregarTarifaRapidaMunicipio()" title="Agregar Tarifa Municipio">
                                        <i class="bi bi-building me-1"></i>+ Municipio
                                    </button>
                                    <button type="button" class="btn btn-sm btn-navy-outline rounded-pill px-2.5 fw-semibold" onclick="agregarFilaTarifa()" title="Añadir otra tarifa">
                                        <i class="bi bi-plus-circle me-1"></i>+ Otra Tarifa
                                    </button>
                                </div>
                            </div>
                            <div class="table-responsive">
                                <table class="table table-sm table-hover align-middle mb-0" id="tablaTarifasForm">
                                    <thead class="table-light small text-muted">
                                        <tr>
                                            <th style="width: 46%;">Tipo de Tarifa / Condición</th>
                                            <th style="width: 25%;">Precio Público ($)</th>
                                            <th style="width: 20%;">Costo / Honorario ($)</th>
                                            <th style="width: 9%;" class="text-center">Quitar</th>
                                        </tr>
                                    </thead>
                                    <tbody id="tbodyTarifas">
                                        <!-- Inyectado dinámicamente -->
                                    </tbody>
                                </table>
                            </div>
                        </div>

                        <div class="d-flex justify-content-end gap-2 pt-2 border-top">
                            <button type="button" class="btn btn-light border px-3" onclick="cerrarFormulario()">Cancelar</button>
                            <button type="submit" class="btn btn-navy-primary px-4 fw-bold"><i class="bi bi-save me-2"></i>Guardar Servicio</button>
                        </div>
                    </form>
                `;

                body.innerHTML = html;

                // Hidratar categorías en cascada
                if (currentDepId) {
                    filtrarCategoriasPorDep(currentDepId, 'sel_cat', id_cat);
                } else {
                    const selCat = document.getElementById('sel_cat');
                    if (selCat) selCat.disabled = true;
                }

                // Hidratar filas de tarifas
                const tbody = document.getElementById('tbodyTarifas');
                tbody.innerHTML = '';
                const tarifas = s.tarifas || [];
                let hasEstandar = false;

                tarifas.forEach(t => {
                    if (t.tipo_tarifa === 'ESTANDAR') hasEstandar = true;
                    renderFilaTarifa(t.tipo_tarifa, t.precio_publico, t.costo_proveedor, t.tipo_tarifa !== 'ESTANDAR');
                });

                if (!hasEstandar) {
                    renderFilaTarifa('ESTANDAR', '', '0.00', false);
                }
            }

            async function saveEntity(e, tipo) {
                e.preventDefault();
                const form = e.target;
                const fd = new FormData(form);

                if (tipo === 'producto') {
                    const precioVal = parseFloat(fd.get('precio'));
                    if (isNaN(precioVal) || precioVal <= 0) {
                        Swal.fire('Atención', 'No se permiten productos con precio menor o igual a cero ($0.00).', 'warning');
                        return;
                    }
                }

                if (tipo === 'servicio') {
                    const filas = document.querySelectorAll('#tbodyTarifas .tarifa-row');
                    const tarifas = [];
                    let tieneEstandar = false;
                    let tieneInvalido = false;
                    const tiposSet = new Set();

                    filas.forEach(f => {
                        const tTipo = f.querySelector('.tarifa-tipo').value;
                        const tPrecio = parseFloat(f.querySelector('.tarifa-precio').value) || 0;
                        const tCosto = parseFloat(f.querySelector('.tarifa-costo').value) || 0;

                        if (tPrecio <= 0) {
                            tieneInvalido = true;
                        }
                        if (tTipo === 'ESTANDAR') tieneEstandar = true;
                        if (tiposSet.has(tTipo)) {
                            Swal.fire('Atención', `La tarifa ${tTipo} está duplicada en la matriz. Cada tipo debe ser único.`, 'warning');
                            return;
                        }
                        tiposSet.add(tTipo);

                        tarifas.push({
                            tipo_tarifa: tTipo,
                            precio: tPrecio,
                            costo: tCosto
                        });
                    });

                    if (!tieneEstandar) {
                        Swal.fire('Atención', 'La tarifa ESTÁNDAR (Público General / Base) es obligatoria.', 'warning');
                        return;
                    }
                    if (tieneInvalido) {
                        Swal.fire('Atención', 'Todas las tarifas ingresadas deben tener un precio mayor a $0.00.', 'warning');
                        return;
                    }

                    fd.append('tarifas_json', JSON.stringify(tarifas));
                }

                try {
                    const res = await fetch('../api/crud_catalogo_universal_api.pl', { method: 'POST', body: fd });
                    const data = await res.json();
                    if (data.success) {
                        Swal.fire('¡Éxito!', data.msg, 'success').then(() => location.reload());
                    } else {
                        Swal.fire('Error', data.error || 'Ocurrió un error al guardar.', 'error');
                    }
                } catch(err) {
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
