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
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex flex-column flex-md-row justify-content-between align-items-md-center gap-3">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-globe me-2"></i>Catálogo Universal</h2>
                    <p class="text-white-50 small mb-0 mt-1">Gestión centralizada del catálogo maestro 3NF</p>
                </div>
                <button class="btn btn-sdm-primary btn-mobile-standard btn-mobile-full rounded-pill px-4 fw-bold shadow-sm" onclick="alert('Funcionalidad en desarrollo para la fase de expansión CRUD.')">
                    <i class="bi bi-plus-circle me-2"></i>Nuevo Servicio
                </button>
            </div>
        </header>

        <div class="container-fluid px-4 pb-5 container-mobile-flush">
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 card-mobile-flush">
                <div class="card-header bg-white border-0 pt-4 px-4 pb-0">
                    <ul class="nav nav-pills nav-fill" id="catalogoTabs" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link active rounded-pill fw-bold" data-bs-toggle="tab" data-bs-target="#servicios" type="button" role="tab"><i class="bi bi-list-check me-2"></i>Servicios</button>
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
                            <div class="table-responsive dataTables_wrapper p-3 rounded-4" style="background-color: #f8fafc; border: 1px solid var(--md-teal-clinical);">
                                <table id="tablaServicios" class="table table-hover align-middle w-100">
                                    <thead class="table-light">
                                        <tr>
                                            <th>SKU</th>
                                            <th>Concepto</th>
                                            <th>Dep/Cat</th>
                                            <th>Precios (Tarifas)</th>
                                            <th class="text-end">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

# Render Items
my %cats_map;
foreach my $c (@{$cat_univ->{categorias}}) { $cats_map{$c->{id_cat}} = $c->{nombre}; }
my %deps_map;
foreach my $d (@{$cat_univ->{departamentos}}) { $deps_map{$d->{id_dep}} = $d->{nombre}; }

foreach my $item (@{$cat_univ->{items}}) {
    my $cat_name = $cats_map{$item->{id_cat}} || 'Desc';
    my $precios_html = "";
    foreach my $p (@{$item->{precios}}) {
        $precios_html .= "<span class='badge bg-info me-1'>$p->{tipo_tarifa}: \$$p->{precio_publico}</span><br>";
    }
    
    print <<HTML;
                                        <tr>
                                            <td data-label="SKU"><span class="badge bg-secondary">$item->{codigo_sku}</span></td>
                                            <td data-label="Concepto" class="fw-bold text-primary">$item->{concepto}</td>
                                            <td data-label="Dep/Cat" class="small text-muted">$cat_name</td>
                                            <td data-label="Precios">$precios_html</td>
                                            <td class="text-end">
                                                <button class="btn btn-sm btn-outline-primary rounded-pill"><i class="bi bi-pencil"></i></button>
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
                                    <h5 class="fw-bold mb-3">Departamentos</h5>
                                    <ul class="list-group list-group-flush border rounded">
HTML

foreach my $dep (@{$cat_univ->{departamentos}}) {
    print qq{<li class="list-group-item d-flex justify-content-between align-items-center">$dep->{nombre} <span class="badge bg-primary rounded-pill">$dep->{id_dep}</span></li>};
}

print <<HTML;
                                    </ul>
                                </div>
                                <div class="col-md-6 mt-4 mt-md-0">
                                    <h5 class="fw-bold mb-3">Categorías</h5>
                                    <ul class="list-group list-group-flush border rounded">
HTML

foreach my $cat (@{$cat_univ->{categorias}}) {
    print qq{<li class="list-group-item d-flex justify-content-between align-items-center">$cat->{nombre} <span class="badge bg-secondary rounded-pill">$cat->{id_cat}</span></li>};
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

print <<'JS';
        <script>
            $(document).ready(function() {
                $('#tablaServicios').DataTable({
                    language: { url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json' },
                    dom: "<'row align-items-center mb-3'<'col-sm-12 col-md-6 export-toolbar d-flex flex-wrap gap-2'B><'col-sm-12 col-md-6'f>>" +
                         "<'row'<'col-sm-12'tr>>" +
                         "<'row mt-3'<'col-sm-12 col-md-5'i><'col-sm-12 col-md-7'p>>",
                    buttons: [
                        { extend: 'copyHtml5', className: 'btn btn-export btn-sm btn-light border shadow-sm rounded-pill px-3', text: '<i class="bi bi-clipboard me-1"></i><span class="d-none d-md-inline">Copiar</span>' },
                        { extend: 'excelHtml5', className: 'btn btn-export btn-sm btn-success border shadow-sm rounded-pill px-3', text: '<i class="bi bi-file-earmark-excel me-1"></i><span class="d-none d-md-inline">Excel</span>', exportOptions: { columns: [0, 1, 2, 3] } },
                        { extend: 'pdfHtml5', className: 'btn btn-export btn-sm btn-danger border shadow-sm rounded-pill px-3', text: '<i class="bi bi-file-earmark-pdf me-1"></i><span class="d-none d-md-inline">PDF</span>', exportOptions: { columns: [0, 1, 2, 3] },
                          customize: function(doc) {
                              doc.styles.tableHeader = { bold: true, fontSize: 11, color: 'white', fillColor: '#0d1e3d', alignment: 'center' };
                              var tableIndex = doc.content.findIndex(node => node.table);
                              if (tableIndex !== -1) {
                                  doc.content[tableIndex].table.widths = ['15%', '35%', '25%', '25%'];
                              }
                          }
                        },
                        { extend: 'print', className: 'btn btn-export btn-sm btn-primary border shadow-sm rounded-pill px-3', text: '<i class="bi bi-printer me-1"></i><span class="d-none d-md-inline">Imprimir</span>', exportOptions: { columns: [0, 1, 2, 3] } }
                    ],
                    pageLength: 25,
                    ordering: true,
                    responsive: true
                });
            });
        </script>
JS

utils::sub_sidebar::render_sidebar_footer();
print $q->end_html;

