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

my $usuario   = $sd->{usuario};
my $role      = $sd->{role};
my $id_medico = $sd->{id_medico};

# Seguridad Estricta: Sólo Administrador Global
if ($role ne 'Administrador Global') {
    print $q->header(-status => '403 Forbidden');
    print "<h1>Acceso Denegado</h1><p>Esta sección es exclusiva para el Administrador Global.</p>";
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
    titulo      => "Fuerza de Ventas",
    skip_header => 1
);

# Leer Usuarios Actuales (para ver los ejecutivos de ventas activos e inactivos)
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '!');
my @ejecutivos = ();
my @ejecutivos_inactivos = ();

if ($regs) {
    foreach my $r (@$regs) {
        next if @$r < 7;
        if ($r->[5] eq 'Ejecutivo Ventas') {
            my $item = { id => $r->[0], nombre => $r->[1], correo => $r->[2] };
            if ($r->[4] eq '1') {
                push @ejecutivos, $item;
            } else {
                push @ejecutivos_inactivos, $item;
            }
        }
    }
}

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'admin_ejecutivos');
print <<HTML;
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-briefcase-fill me-2"></i>Ventas</h2>
                    <p class="text-white-50 small mb-0 mt-1">Gestión de la Fuerza de Ventas y Ejecutivos Comerciales</p>
                </div>
                <button class="btn btn-blue-deep rounded-pill px-4 fw-bold shadow-sm" onclick="prepararNuevoEjecutivo()">
                    <i class="bi bi-person-plus-fill me-2"></i>Añadir Ejecutivo
                </button>
            </div>
        </header>

        <!-- CONTAINER -->
        <div class="container-fluid px-4 pb-5">
            
            <!-- Contenedor del Formulario Inline (Alta/Edición de Ejecutivo) -->
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 mb-4 d-none animate__animated animate__fadeIn" id="formContainer" style="scroll-margin-top: 100px;">
                <div class="card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center" id="formHeader" style="background-color: var(--md-blue-deep) !important;">
                    <h5 class="fw-black mb-0" id="formTitle"><i class="bi bi-person-plus-fill me-2"></i>Añadir Ejecutivo de Ventas</h5>
                    <button type="button" class="btn-close btn-close-white" onclick="toggleFormulario()"></button>
                </div>
                <div class="card-body p-4 bg-light rounded-bottom-4">
                    <form id="form-ejecutivo" class="form-sdm-container">
                        <input type="hidden" name="id" id="form_id_ejecutivo" value="">
                        <input type="hidden" name="action" id="form_action" value="create">
                        
                        <div class="row g-3">
                            <div class="col-12 col-md-4">
                                <label class="form-label small fw-bold text-muted">Nombre Completo</label>
                                <input type="text" class="form-control form-control-sm shadow-sm" id="form_nombre" name="nombre" required placeholder="Ej: Pamela Villegas">
                            </div>
                            <div class="col-12 col-md-4">
                                <label class="form-label small fw-bold text-muted">Correo Electrónico (Login)</label>
                                <input type="email" class="form-control form-control-sm shadow-sm" id="form_correo" name="correo" required placeholder="correo\@correo.com" autocomplete="username">
                            </div>
                            <div class="col-12 col-md-4" id="passwordFieldContainer">
                                <label class="form-label small fw-bold text-muted" id="passwordLabel">Contraseña Inicial</label>
                                <input type="password" class="form-control form-control-sm shadow-sm" id="form_clave" name="clave" placeholder="••••••••" autocomplete="new-password">
                            </div>
                        </div>
                        <div class="mt-4 d-flex justify-content-end gap-2">
                            <button type="button" class="btn btn-light fw-bold px-4" onclick="toggleFormulario()">Cancelar</button>
                            <button type="submit" class="btn btn-blue-deep rounded-pill px-4 fw-bold shadow-sm" id="btn-submit-form">
                                <i class="bi bi-person-check me-2"></i>Guardar Ejecutivo
                            </button>
                        </div>
                    </form>
                </div>
            </div>

            <!-- Pestañas de Navegación -->
            <ul class="nav nav-pills mb-4 gap-2" id="execTabs" role="tablist">
                <li class="nav-item" role="presentation">
                    <button class="nav-link btn btn-blue-deep active rounded-pill px-4 fw-bold shadow-sm" id="activos-tab" data-bs-toggle="pill" data-bs-target="#tab-activos" type="button" role="tab" aria-controls="tab-activos" aria-selected="true">
                        <i class="bi bi-person-check-fill me-2"></i>Ejecutivos Activos
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link btn btn-light rounded-pill px-4 fw-bold shadow-sm position-relative" id="inactivos-tab" data-bs-toggle="pill" data-bs-target="#tab-inactivos" type="button" role="tab" aria-controls="tab-inactivos" aria-selected="false" style="border: 1px solid #dee2e6;">
                        <i class="bi bi-person-x-fill me-2"></i>Inactivos / Papelera
HTML
if (@ejecutivos_inactivos) {
    my $count = scalar(@ejecutivos_inactivos);
    print qq|                        <span class="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger" style="z-index:10;">$count</span>\n|;
}
print <<HTML;
                    </button>
                </li>
            </ul>

            <div class="tab-content" id="execTabsContent">
                <!-- PANEL: ACTIVOS -->
                <div class="tab-pane fade show active" id="tab-activos" role="tabpanel" aria-labelledby="activos-tab">
                    <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                        <div class="card-body p-4">
                            <div class="table-responsive">
                                <table class="table table-hover align-middle mb-0" id="tablaEjecutivos">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Nombre</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Correo Electrónico</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase text-end">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

if (@ejecutivos) {
    foreach my $e (@ejecutivos) {
        print <<HTML;
                                        <tr>
                                            <td>
                                                <div class="d-flex align-items-center">
                                                    <div class="bg-primary bg-opacity-10 text-primary rounded-circle d-flex justify-content-center align-items-center me-3" style="width: 40px; height: 40px;">
                                                        <i class="bi bi-person-badge"></i>
                                                    </div>
                                                    <span class="fw-bold text-dark">$$e{nombre}</span>
                                                </div>
                                            </td>
                                            <td class="text-muted small fw-bold">$$e{correo}</td>
                                            <td class="text-end pe-4">
                                                <div class="d-flex justify-content-end gap-2">
                                                    <button onclick="abrirFormEditar('$$e{id}', '$$e{nombre}', '$$e{correo}')" class="btn p-0 border-0 btn-expediente" title="Editar">
                                                        <div class="icon-container-acrylic text-primary"><i class="bi bi-pencil-square"></i></div>
                                                    </button>
                                                    <button onclick="confirmDesactivar('$$e{id}')" class="btn p-0 border-0 action-btn-delete" title="Desactivar / Papelera">
                                                        <div class="icon-container-acrylic text-danger border-danger border-opacity-25" style="background: rgba(220, 53, 69, 0.05);"><i class="bi bi-person-x"></i></div>
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
HTML
    }
} else {
    print <<HTML;
                                        <tr>
                                            <td colspan="3" class="text-center py-5 text-muted">
                                                <i class="bi bi-people display-4 d-block mb-3 text-black-50 opacity-50"></i>
                                                <p class="mb-0 fw-bold fs-5">Sin ejecutivos de ventas activos.</p>
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

                <!-- PANEL: INACTIVOS -->
                <div class="tab-pane fade" id="tab-inactivos" role="tabpanel" aria-labelledby="inactivos-tab">
                    <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                        <div class="card-body p-4">
                            <div class="table-responsive">
                                <table class="table table-hover align-middle mb-0" id="tablaEjecutivosInactivos">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Nombre</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Correo Electrónico</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase text-end">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

if (@ejecutivos_inactivos) {
    foreach my $e (@ejecutivos_inactivos) {
        print <<HTML;
                                        <tr>
                                            <td>
                                                <div class="d-flex align-items-center opacity-75">
                                                    <div class="bg-secondary bg-opacity-10 text-secondary rounded-circle d-flex justify-content-center align-items-center me-3" style="width: 40px; height: 40px;">
                                                        <i class="bi bi-person-x"></i>
                                                    </div>
                                                    <span class="fw-bold text-muted">$$e{nombre}</span>
                                                </div>
                                            </td>
                                            <td class="text-muted small fw-bold">$$e{correo}</td>
                                            <td class="text-end pe-4">
                                                <div class="d-flex justify-content-end gap-2">
                                                    <button onclick="confirmReactivar('$$e{id}')" class="btn p-0 border-0 btn-expediente" title="Reactivar">
                                                        <div class="icon-container-acrylic text-success" style="background: rgba(25, 135, 84, 0.05); border-color: rgba(25, 135, 84, 0.25);"><i class="bi bi-arrow-counterclockwise"></i></div>
                                                    </button>
                                                    <button onclick="confirmEliminarDefinitivo('$$e{id}')" class="btn p-0 border-0 action-btn-delete" title="Eliminar Permanentemente">
                                                        <div class="icon-container-acrylic text-danger" style="background: rgba(220, 53, 69, 0.1); border-color: rgba(220, 53, 69, 0.4);"><i class="bi bi-trash-fill"></i></div>
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
HTML
    }
} else {
    print <<HTML;
                                        <tr>
                                            <td colspan="3" class="text-center py-5 text-muted">
                                                <i class="bi bi-trash3 display-4 d-block mb-3 text-black-50 opacity-50"></i>
                                                <p class="mb-0 fw-bold fs-5">La papelera está vacía.</p>
                                                <p class="small text-muted">Aquí aparecerán los ejecutivos inactivos.</p>
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
            </div>
        </div>
    </main>
HTML
print <<HTML;



<!-- Scripts y Librerías de DataTables -->
<link class="datatables-css" rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>

<script>
    var dtEjecutivos;
    var dtEjecutivosInactivos;

    \$(document).ready(function() {
        if (\$('#tablaEjecutivos').length && \$('#tablaEjecutivos tbody tr td').length > 1) {
            dtEjecutivos = \$('#tablaEjecutivos').DataTable({
                destroy: true,
                language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                dom: '<"p-3 d-flex justify-content-end align-items-center"f>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
                ordering: true,
                paging: true
            });
        }

        if (\$('#tablaEjecutivosInactivos').length && \$('#tablaEjecutivosInactivos tbody tr td').length > 1) {
            dtEjecutivosInactivos = \$('#tablaEjecutivosInactivos').DataTable({
                destroy: true,
                language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                dom: '<"p-3 d-flex justify-content-end align-items-center"f>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
                ordering: true,
                paging: true
            });
        }

        // Toggling styles on Tab Pills click dynamically
        \$('button[data-bs-toggle="pill"]').on('shown.bs.tab', function (e) {
            \$(e.target).removeClass('btn-light text-dark').addClass('btn-blue-deep text-white');
            \$(e.relatedTarget).removeClass('btn-blue-deep text-white').addClass('btn-light text-dark');
        });
    });

    window.toggleFormulario = function() {
        const container = document.getElementById('formContainer');
        if (container.classList.contains('d-none')) {
            container.classList.remove('d-none');
            const offset = container.offsetTop - 90;
            window.scrollTo({ top: offset, behavior: 'smooth' });
        } else {
            container.classList.add('d-none');
        }
    };

    window.prepararNuevoEjecutivo = function() {
        document.getElementById('form_action').value = 'create';
        document.getElementById('form_id_ejecutivo').value = '';
        document.getElementById('form_nombre').value = '';
        document.getElementById('form_correo').value = '';
        document.getElementById('form_clave').value = '';
        document.getElementById('form_clave').required = true;
        document.getElementById('passwordLabel').innerText = 'Contraseña Inicial';
        
        document.getElementById('formTitle').innerHTML = '<i class="bi bi-person-plus-fill me-2"></i>Añadir Ejecutivo de Ventas';
        document.getElementById('formHeader').className = 'card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center';
        
        const container = document.getElementById('formContainer');
        container.classList.remove('d-none');
        const offset = container.offsetTop - 90;
        window.scrollTo({ top: offset, behavior: 'smooth' });
    };

    window.abrirFormEditar = function(id, nombre, correo) {
        document.getElementById('form_action').value = 'edit';
        document.getElementById('form_id_ejecutivo').value = id;
        document.getElementById('form_nombre').value = nombre;
        document.getElementById('form_correo').value = correo;
        document.getElementById('form_clave').value = '';
        document.getElementById('form_clave').required = false;
        document.getElementById('passwordLabel').innerText = 'Nueva Contraseña (Opcional)';
        
        document.getElementById('formTitle').innerHTML = '<i class="bi bi-pencil-square me-2"></i>Editar Ejecutivo de Ventas';
        document.getElementById('formHeader').className = 'card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center';
        
        const container = document.getElementById('formContainer');
        container.classList.remove('d-none');
        const offset = container.offsetTop - 90;
        window.scrollTo({ top: offset, behavior: 'smooth' });
    };

    document.getElementById('form-ejecutivo').addEventListener('submit', function(e) {
        e.preventDefault();
        const fd = new FormData(this);
        const action = document.getElementById('form_action').value;
        const btn = document.getElementById('btn-submit-form');
        
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Guardando...';

        fetch('../api/crud_ejecutivos_api.pl', {
            method: 'POST',
            body: fd
        })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Guardado!',
                    text: 'El perfil del ejecutivo ha sido guardado.',
                    confirmButtonColor: '#18D1E6'
                }).then(() => location.reload());
            } else {
                Swal.fire('Error', data.message || 'Ocurrió un error.', 'error');
                btn.disabled = false;
                btn.innerHTML = '<i class="bi bi-save me-2"></i>Guardar Ejecutivo';
            }
        })
        .catch(err => {
            console.error(err);
            Swal.fire('Error', 'Falla de conexión.', 'error');
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-save me-2"></i>Guardar Ejecutivo';
        });
    });

    // Desactivar Ejecutivo (Soft Delete)
    window.confirmDesactivar = function(id) {
        Swal.fire({
            title: '¿Desactivar Ejecutivo?',
            text: "El usuario ya no podrá iniciar sesión en el CRM y pasará a la papelera.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, Desactivar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('id', id);
                fd.append('action', 'remove');
                fetch('../api/crud_ejecutivos_api.pl', {
                    method: 'POST',
                    body: fd
                })
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        location.reload();
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                });
            }
        })
    }

    // Reactivar Ejecutivo
    window.confirmReactivar = function(id) {
        Swal.fire({
            title: '¿Reactivar Ejecutivo?',
            text: "El usuario volverá a la lista activa y podrá iniciar sesión en el CRM.",
            icon: 'question',
            showCancelButton: true,
            confirmButtonColor: '#198754',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, Reactivar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('id', id);
                fd.append('action', 'reactivate');
                fetch('../api/crud_ejecutivos_api.pl', {
                    method: 'POST',
                    body: fd
                })
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        location.reload();
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                });
            }
        })
    }

    // Eliminar permanentemente (Borrado físico)
    window.confirmEliminarDefinitivo = function(id) {
        Swal.fire({
            title: '¿Eliminar Permanentemente?',
            text: "Esta acción borrará de forma física al Ejecutivo de la base de datos. No se puede deshacer.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, BORRAR FÍSICAMENTE',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('id', id);
                fd.append('action', 'delete_permanent');
                fetch('../api/crud_ejecutivos_api.pl', {
                    method: 'POST',
                    body: fd
                })
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        location.reload();
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                });
            }
        })
    }
</script>
HTML

utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
</body>
</html>
HTML

render_bottom_nav('admin_global');
1;
