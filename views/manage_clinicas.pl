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
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_empresa = $sd->{id_empresa};

# Seguridad: Sólo Administrador de Organización puede ver/gestionar Sucursales
if ($role ne 'Administrador Organizacion') {
    print $q->header(-status => '403 Forbidden');
    print "<h1>Acceso Denegado</h1><p>Esta sección es exclusiva para Directores de Organización.</p>";
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
    titulo      => "Gestión de Sucursales",
    skip_header => 1
);

my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $regs_negocios = leer_tabla($archivo_negocios, '\|');
my @mis_sucursales = ();

if ($regs_negocios) {
    foreach my $r (@$regs_negocios) {
        next if @$r < 3;
        # Si la matriz de esta sucursal es mi organizacion
        if ($r->[2] eq $id_empresa) {
            push @mis_sucursales, { 
                id => $r->[0], 
                nombre => $r->[1],
                estado => $r->[3] eq '1' ? 'Activa' : 'Inactiva',
                telefono => $r->[7] || 'N/A',
                domicilio => $r->[6] || 'No registrado'
            };
        }
    }
}

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'clinicas');
print <<HTML;
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-building-gear me-2"></i>Gestión de Sucursales</h2>
                    <p class="text-white-50 small mb-0 mt-1">Configuración de clínicas y sedes físicas</p>
                </div>
                <button class="btn btn-sdm-primary rounded-pill px-4 fw-bold shadow-sm" onclick="toggleFormulario()">
                    <i class="bi bi-plus-circle me-2"></i>Nueva Sucursal
                </button>
            </div>
        </header>

        <div class="container-fluid px-4">
            <!-- Contenedor del Formulario Inline -->
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 mb-4 d-none animate__animated animate__fadeIn" id="formContainer">
                <div class="card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center" id="formHeader" style="background-color: var(--md-blue-deep) !important;">
                    <h5 class="fw-black mb-0" id="formTitle"><i class="bi bi-shop me-2"></i>Añadir Nueva Sucursal</h5>
                    <button type="button" class="btn-close btn-close-white" onclick="toggleFormulario()"></button>
                </div>
                <div class="card-body p-4 bg-light rounded-bottom-4">
                    <form id="form-alta-sucursal" class="form-sdm-container">
                        <input type="hidden" name="id_sucursal_edit" id="form_id_sucursal" value="">
                        <input type="hidden" name="action" id="form_action" value="create">
                        <div class="row g-3">
                            <div class="col-12 col-md-6">
                                <label class="form-label small fw-bold text-muted">Nombre de la Sucursal</label>
                                <input type="text" class="form-control form-control-sm shadow-sm" id="form_nombre" name="nombre_sucursal" required placeholder="Ej: Sucursal Norte">
                            </div>
                            <div class="col-12 col-md-6">
                                <label class="form-label small fw-bold text-muted">Teléfono Principal</label>
                                <input type="text" class="form-control form-control-sm shadow-sm" id="form_telefono" name="telefono" placeholder="555-1234">
                            </div>
                            <div class="col-12">
                                <label class="form-label small fw-bold text-muted">Domicilio</label>
                                <input type="text" class="form-control form-control-sm shadow-sm" id="form_domicilio" name="domicilio" placeholder="Av. Siempre Viva 742">
                            </div>
                        </div>
                        <div class="mt-4 d-flex justify-content-end gap-2">
                            <button type="button" class="btn btn-light fw-bold px-4" onclick="toggleFormulario()">Cancelar</button>
                            <button type="submit" class="btn btn-sdm-primary rounded-pill px-4 fw-bold shadow-sm" id="btn-submit-sucursal">
                                <i class="bi bi-plus-circle me-2"></i>Registrar Sucursal
                            </button>
                        </div>
                    </form>
                </div>
            </div>

            <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                <div class="card-body p-4">
                    <div class="table-responsive">
                        <table class="table table-hover align-middle mb-0" id="tablaSucursales">
                            <thead class="table-light">
                                <tr>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Sucursal</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Estado</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Teléfono</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Domicilio</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0 text-end pe-4">Acciones</th>
                                </tr>
                            </thead>
                            <tbody>
HTML

if (@mis_sucursales) {
    foreach my $suc (@mis_sucursales) {
        my $badge = $suc->{estado} eq 'Activa' ? 'bg-success' : 'bg-danger';
        my $toggle_title = $suc->{estado} eq 'Activa' ? 'Desactivar' : 'Activar';
        my $toggle_class = $suc->{estado} eq 'Activa' ? 'text-danger border-danger border-opacity-25' : 'text-success border-success border-opacity-25';
        my $toggle_bg = $suc->{estado} eq 'Activa' ? 'rgba(220, 53, 69, 0.05)' : 'rgba(25, 135, 84, 0.05)';
        my $toggle_icon = $suc->{estado} eq 'Activa' ? 'bi-toggle-on' : 'bi-toggle-off';
        print <<HTML;
                                <tr>
                                    <td>
                                        <div class="d-flex align-items-center">
                                            <div class="bg-primary bg-opacity-10 text-primary rounded-circle d-flex justify-content-center align-items-center me-3" style="width: 40px; height: 40px;">
                                                <i class="bi bi-shop"></i>
                                            </div>
                                            <div>
                                                <span class="fw-bold text-dark d-block">$$suc{nombre}</span>
                                                <span class="small text-muted">ID: $$suc{id}</span>
                                            </div>
                                        </div>
                                    </td>
                                    <td><span class="badge rounded-pill $badge px-3 py-2">$$suc{estado}</span></td>
                                    <td class="text-muted small fw-bold">$$suc{telefono}</td>
                                    <td class="text-muted small">$$suc{domicilio}</td>
                                    <td class="text-end pe-4">
                                        <div class="d-flex justify-content-end gap-2">
                                            <button onclick="abrirFormEditar('$$suc{id}', '$$suc{nombre}', '$$suc{telefono}', '$$suc{domicilio}')" class="btn p-0 border-0 btn-expediente" title="Editar">
                                                <div class="icon-container-acrylic text-primary"><i class="bi bi-pencil-square"></i></div>
                                            </button>
                                            <button onclick="confirmToggleStatus('$$suc{id}', '$$suc{nombre}', '$$suc{estado}')" class="btn p-0 border-0 action-btn-delete" title="$toggle_title">
                                                <div class="icon-container-acrylic $toggle_class" style="background: $toggle_bg;"><i class="bi $toggle_icon"></i></div>
                                            </button>
                                        </div>
                                    </td>
                                </tr>
HTML
    }
} else {
    print <<HTML;
                                <tr>
                                    <td colspan="5" class="text-center py-5 text-muted">
                                        <i class="bi bi-shop-window display-4 d-block mb-3 text-black-50 opacity-50"></i>
                                        <p class="mb-0 fw-bold fs-5">Aún no has registrado ninguna sucursal.</p>
                                        <p class="small text-muted">Crea tu primera sede clínica para comenzar a agregar personal.</p>
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
        </div>
HTML
utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
<!-- Hojas de Estilo de DataTables -->
<link class="datatables-css" rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.1/css/buttons.bootstrap5.min.css">

<!-- Librerías de DataTables y Exportaciones -->
<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.bootstrap5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/vfs_fonts.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.print.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>

<script>
    // 1. Declarar funciones globales primero (Garantiza acceso en navegación SPA)
    window.toggleFormulario = function() {
        const container = document.getElementById('formContainer');
        if (container.classList.contains('d-none')) {
            // Limpiar formulario y restablecer a modo Creación
            document.getElementById('form-alta-sucursal').reset();
            document.getElementById('form_action').value = 'create';
            document.getElementById('form_id_sucursal').value = '';
            document.getElementById('formTitle').innerHTML = '<i class="bi bi-shop me-2"></i>Añadir Nueva Sucursal';
            document.getElementById('btn-submit-sucursal').innerHTML = '<i class="bi bi-plus-circle me-2"></i>Registrar Sucursal';
            
            container.classList.remove('d-none');
            const offset = container.offsetTop - 100;
            window.scrollTo({ top: offset, behavior: 'smooth' });
        } else {
            container.classList.add('d-none');
        }
    };

    window.abrirFormEditar = function(id, nombre, telefono, domicilio) {
        document.getElementById('form_action').value = 'update';
        document.getElementById('form_id_sucursal').value = id;
        document.getElementById('form_nombre').value = nombre;
        document.getElementById('form_telefono').value = (telefono === 'N/A' || telefono === 'No aplica') ? '' : telefono;
        document.getElementById('form_domicilio').value = (domicilio === 'No registrado' || domicilio === 'No aplica') ? '' : domicilio;
        
        document.getElementById('formTitle').innerHTML = '<i class="bi bi-pencil-square me-2"></i>Editar Sucursal';
        document.getElementById('btn-submit-sucursal').innerHTML = '<i class="bi bi-save me-2"></i>Guardar Cambios';
        
        const container = document.getElementById('formContainer');
        container.classList.remove('d-none');
        const offset = container.offsetTop - 100;
        window.scrollTo({ top: offset, behavior: 'smooth' });
    };

    window.confirmToggleStatus = function(id, nombre, estadoActual) {
        const accion = (estadoActual === 'Activa') ? 'desactivar' : 'activar';
        const color = (estadoActual === 'Activa') ? '#d33' : '#198754';
        
        Swal.fire({
            title: '¿' + accion.charAt(0).toUpperCase() + accion.slice(1) + ' sucursal?',
            text: '¿Estás seguro de que deseas ' + accion + ' la sucursal "' + nombre + '"?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: color,
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, ' + accion,
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('id_sucursal', id);
                fd.append('action', 'toggle_status');
                
                fetch('../api/crud_sucursales_api.pl', {
                    method: 'POST',
                    body: fd
                })
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        Swal.fire({
                            icon: 'success',
                            title: '¡Estado Actualizado!',
                            text: 'La sucursal ha sido modificada.',
                            confirmButtonColor: '#18D1E6'
                        }).then(() => location.reload());
                    } else {
                        Swal.fire('Error', data.message || 'Ocurrió un error.', 'error');
                    }
                })
                .catch(err => {
                    console.error(err);
                    Swal.fire('Error', 'Falla de conexión.', 'error');
                });
            }
        });
    };

    // 2. Inicialización segura de DataTables con Barra de Herramientas Estándar (Norma 7)
    var dtSucursales;
    function initSucursalesTable() {
        try {
            if (\$('#tablaSucursales').length && \$('#tablaSucursales tbody tr td').length > 1) {
                dtSucursales = \$('#tablaSucursales').DataTable({
                    destroy: true,
                    language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                    dom: '<"p-3 d-flex justify-content-start align-items-center"B>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
                    buttons: {
                        dom: {
                            container: { className: 'dt-buttons export-toolbar' },
                            button: { className: 'btn-export' }
                        },
                        buttons: [
                            { 
                                extend: 'copy', 
                                text: '<i class="bi bi-clipboard"></i> Copiar',
                                exportOptions: { columns: [0, 1, 2, 3] }
                            },
                            { 
                                extend: 'excel', 
                                text: '<i class="bi bi-file-earmark-excel"></i> Excel', 
                                title: 'Gestión de Sucursales - SDM',
                                exportOptions: { columns: [0, 1, 2, 3] }
                            },
                            { 
                                extend: 'pdf', 
                                text: '<i class="bi bi-file-earmark-pdf"></i> PDF', 
                                title: 'Gestión de Sucursales - SDM',
                                exportOptions: { columns: [0, 1, 2, 3] },
                                customize: function (doc) {
                                    doc.styles.tableHeader = { fillColor: '#0d1e3d', color: 'white', alignment: 'center', bold: true, fontSize: 10 };
                                    var tableIndex = -1;
                                    for (var i = 0; i < doc.content.length; i++) {
                                        if (doc.content[i].table) {
                                            tableIndex = i;
                                            break;
                                        }
                                    }
                                    if (tableIndex > -1) {
                                        doc.content[tableIndex].table.widths = ['25%', '15%', '20%', '40%'];
                                        doc.content[tableIndex].margin = [0, 10, 0, 10];
                                        if (tableIndex > 0) doc.content.splice(0, tableIndex);
                                    }
                                }
                            },
                            {
                                extend: 'print',
                                text: '<i class="bi bi-printer"></i> Imprimir',
                                exportOptions: { columns: [0, 1, 2, 3] }
                            }
                        ]
                    }
                });
            }
        } catch(e) {
            console.error("Error al inicializar DataTables:", e);
        }
    }

    try {
        \$(document).ready(initSucursalesTable);
        document.addEventListener("spa:contentLoaded", initSucursalesTable);
    } catch(e) {
        console.error("Error al configurar bindings jQuery:", e);
    }

    // 3. Envío del Formulario vía Fetch
    document.getElementById('form-alta-sucursal').addEventListener('submit', function(e) {
        e.preventDefault();
        const fd = new FormData(this);
        const btn = document.getElementById('btn-submit-sucursal');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Guardando...';

        fetch('../api/crud_sucursales_api.pl', {
            method: 'POST',
            body: fd
        })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Guardado!',
                    text: 'La sucursal ha sido guardada correctamente.',
                    confirmButtonColor: '#18D1E6'
                }).then(() => location.reload());
            } else {
                Swal.fire('Error', data.message || 'Error al procesar.', 'error');
                btn.disabled = false;
                btn.innerHTML = '<i class="bi bi-save me-2"></i>Guardar Cambios';
            }
        })
        .catch(err => {
            console.error(err);
            Swal.fire('Error', 'Falla de conexión.', 'error');
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-save me-2"></i>Guardar Cambios';
        });
    });
</script>
</body>
</html>
HTML

render_bottom_nav('clinicas');
1;
