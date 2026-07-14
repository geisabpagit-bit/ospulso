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

# Seguridad: Administrador de Organización
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
    titulo      => "Gestión de Personal",
    skip_header => 1
);

# 1. Obtener sucursales
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $regs_negocios = leer_tabla($archivo_negocios, '\|');
my %sucursales_hash = ();
my @mis_sucursales = ();

if ($regs_negocios) {
    foreach my $r (@$regs_negocios) {
        next if @$r < 3;
        if ($r->[2] eq $id_empresa) { # Hija de esta organización
            $sucursales_hash{$r->[0]} = $r->[1];
            push @mis_sucursales, { id => $r->[0], nombre => $r->[1] };
        }
    }
}

# 2. Obtener usuarios (activos e inactivos)
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
my @mi_personal = ();
my @personal_inactivo = ();

if ($regs_usuarios) {
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        my $extra = $r->[6];
        my ($org_id, $suc_id) = split(/:/, $extra);
        
        # Si el usuario pertenece a mi organización y NO es el administrador global
        if ($org_id && $org_id eq $id_empresa && $r->[5] ne 'Administrador Organizacion') {
            my $item = {
                id => $r->[0],
                nombre => $r->[1],
                correo => $r->[2],
                rol => $r->[5],
                id_suc => $suc_id,
                sucursal => $sucursales_hash{$suc_id} || 'No Asignada'
            };
            if ($r->[4] eq '1') {
                push @mi_personal, $item;
            } else {
                push @personal_inactivo, $item;
            }
        }
    }
}

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'usuarios');
print <<HTML;
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-people-fill me-2"></i>Gestión de Personal</h2>
                    <p class="text-white-50 small mb-0 mt-1">Directorio de Médicos, Recepcionistas y Auxiliares</p>
                </div>
                <button class="btn btn-sdm-primary rounded-pill px-4 fw-bold shadow-sm" onclick="prepararNuevoUsuario()">
                    <i class="bi bi-person-plus-fill me-2"></i>Añadir Personal
                </button>
            </div>
        </header>

        <div class="container-fluid px-4 pb-5">
            <!-- Contenedor del Formulario Inline (Alta/Edición) -->
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 mb-4 d-none animate__animated animate__fadeIn" id="formContainer" style="scroll-margin-top: 100px;">
                <div class="card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center" id="formHeader" style="background-color: var(--md-blue-deep) !important;">
                    <h5 class="fw-black mb-0" id="formTitle"><i class="bi bi-person-plus-fill me-2"></i>Añadir Colaborador</h5>
                    <button type="button" class="btn-close btn-close-white" onclick="toggleFormulario()"></button>
                </div>
                <div class="card-body p-4 bg-light rounded-bottom-4">
                    <form id="form-usuario" class="form-sdm-container">
                        <input type="hidden" name="id_usuario_edit" id="form_id_usuario" value="">
                        <input type="hidden" name="action" id="form_action" value="create">
                        
                        <div class="row g-3">
                            <div class="col-12 col-md-6">
                                <label class="form-label small fw-bold text-muted">Nombre Completo</label>
                                <input type="text" class="form-control form-control-sm shadow-sm" id="form_nombre" name="nombre" required placeholder="Ej: Dra. María López">
                            </div>
                            <div class="col-12 col-md-6">
                                <label class="form-label small fw-bold text-muted">Correo Electrónico (Login)</label>
                                <input type="email" class="form-control form-control-sm shadow-sm" id="form_correo" name="correo" required placeholder="maria\@clinica.com" autocomplete="username">
                            </div>
                            <div class="col-12 col-md-6" id="passwordFieldContainer">
                                <label class="form-label small fw-bold text-muted" id="passwordLabel">Contraseña Inicial</label>
                                <input type="password" class="form-control form-control-sm shadow-sm" id="form_clave" name="clave" placeholder="••••••••" autocomplete="new-password">
                            </div>
                            <div class="col-12 col-md-6">
                                <label class="form-label small fw-bold text-muted">Rol Operativo</label>
                                <select class="form-select form-select-sm shadow-sm" id="form_rol" name="rol" required>
                                    <option value="Medico">Médico (Acceso a Expedientes)</option>
                                    <option value="Recepcionista">Recepcionista (Agenda y Pagos)</option>
                                </select>
                            </div>
                            <div class="col-12 col-md-6">
                                <label class="form-label small fw-bold text-muted">Asignar a Sucursal</label>
                                <select class="form-select form-select-sm shadow-sm" id="form_id_sucursal" name="id_sucursal" required>
                                    <option value="" disabled selected>Selecciona una sede...</option>
HTML

foreach my $suc (@mis_sucursales) {
    print qq|                                    <option value="$suc->{id}">$suc->{nombre}</option>\n|;
}

if (!@mis_sucursales) {
    print qq|                                    <option value="" disabled>! PRIMERO DEBES CREAR UNA SUCURSAL</option>\n|;
}

print <<HTML;
                                </select>
                            </div>
                        </div>
                        <div class="mt-4 d-flex justify-content-end gap-2">
                            <button type="button" class="btn btn-light fw-bold px-4" onclick="toggleFormulario()">Cancelar</button>
                            <button type="submit" class="btn btn-blue-deep rounded-pill px-4 fw-bold shadow-sm" id="btn-submit-form">
                                <i class="bi bi-person-check me-2"></i>Guardar Colaborador
                            </button>
                        </div>
                    </form>
                </div>
            </div>

            <!-- Pestañas de Navegación -->
            <ul class="nav nav-pills mb-4 gap-2" id="userTabs" role="tablist">
                <li class="nav-item" role="presentation">
                    <button class="nav-link btn btn-blue-deep active rounded-pill px-4 fw-bold shadow-sm" id="activos-tab" data-bs-toggle="pill" data-bs-target="#tab-activos" type="button" role="tab">
                        <i class="bi bi-person-check-fill me-2"></i>Colaboradores Activos
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link btn btn-light rounded-pill px-4 fw-bold shadow-sm position-relative" id="inactivos-tab" data-bs-toggle="pill" data-bs-target="#tab-inactivos" type="button" role="tab" style="border: 1px solid #dee2e6;">
                        <i class="bi bi-person-x-fill me-2"></i>Inactivos / Papelera
HTML
if (@personal_inactivo) {
    my $count = scalar(@personal_inactivo);
    print qq|                        <span class="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger">$count</span>\n|;
}
print <<HTML;
                    </button>
                </li>
            </ul>

            <div class="tab-content" id="userTabsContent">
                <!-- PANEL: ACTIVOS -->
                <div class="tab-pane fade show active" id="tab-activos" role="tabpanel">
                    <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                        <div class="card-body p-4">
                            <div class="table-responsive">
                                <table class="table table-hover align-middle mb-0" id="tablaUsuarios">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Colaborador</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Rol / Perfil</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Sucursal Asignada</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0 text-end">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

if (@mi_personal) {
    foreach my $per (@mi_personal) {
        print <<HTML;
                                        <tr>
                                            <td>
                                                <div class="d-flex align-items-center">
                                                    <div class="bg-primary bg-opacity-10 text-primary rounded-circle d-flex justify-content-center align-items-center me-3" style="width: 40px; height: 40px;">
                                                        <i class="bi bi-person"></i>
                                                    </div>
                                                    <div>
                                                        <span class="fw-bold text-dark d-block">$$per{nombre}</span>
                                                        <span class="small text-muted">$$per{correo}</span>
                                                    </div>
                                                </div>
                                            </td>
                                            <td><span class="badge bg-secondary px-3 py-2">$$per{rol}</span></td>
                                            <td class="text-muted small fw-bold">$$per{sucursal}</td>
                                            <td class="text-end pe-4">
                                                <div class="d-flex justify-content-end gap-2">
                                                    <button onclick="abrirFormEditar('$$per{id}', '$$per{nombre}', '$$per{correo}', '$$per{rol}', '$$per{id_suc}')" class="btn p-0 border-0 btn-expediente" title="Editar">
                                                        <div class="icon-container-acrylic text-primary"><i class="bi bi-pencil-square"></i></div>
                                                    </button>
                                                    <button onclick="confirmDesactivar('$$per{id}')" class="btn p-0 border-0 action-btn-delete" title="Desactivar">
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
                                            <td colspan="4" class="text-center py-5 text-muted">
                                                <i class="bi bi-person-badge display-4 d-block mb-3 text-black-50 opacity-50"></i>
                                                <p class="mb-0 fw-bold fs-5">Sin colaboradores activos.</p>
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
                <div class="tab-pane fade" id="tab-inactivos" role="tabpanel">
                    <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                        <div class="card-body p-4">
                            <div class="table-responsive">
                                <table class="table table-hover align-middle mb-0" id="tablaUsuariosInactivos">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Colaborador</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Rol / Perfil</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0">Sucursal Asignada</th>
                                            <th class="small fw-bold text-muted text-uppercase border-0 text-end">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

if (@personal_inactivo) {
    foreach my $per (@personal_inactivo) {
        print <<HTML;
                                        <tr>
                                            <td>
                                                <div class="d-flex align-items-center opacity-75">
                                                    <div class="bg-secondary bg-opacity-10 text-secondary rounded-circle d-flex justify-content-center align-items-center me-3" style="width: 40px; height: 40px;">
                                                        <i class="bi bi-person-x"></i>
                                                    </div>
                                                    <div>
                                                        <span class="fw-bold text-muted d-block">$$per{nombre}</span>
                                                        <span class="small text-muted">$$per{correo}</span>
                                                    </div>
                                                </div>
                                            </td>
                                            <td><span class="badge bg-light text-muted px-3 py-2">$$per{rol}</span></td>
                                            <td class="text-muted small fw-bold">$$per{sucursal}</td>
                                            <td class="text-end pe-4">
                                                <div class="d-flex justify-content-end gap-2">
                                                    <button onclick="confirmReactivar('$$per{id}')" class="btn p-0 border-0 btn-expediente" title="Reactivar">
                                                        <div class="icon-container-acrylic text-success" style="background: rgba(25, 135, 84, 0.05); border-color: rgba(25, 135, 84, 0.25);"><i class="bi bi-arrow-counterclockwise"></i></div>
                                                    </button>
                                                    <button onclick="confirmEliminarDefinitivo('$$per{id}')" class="btn p-0 border-0 action-btn-delete" title="Eliminar Permanentemente">
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
                                            <td colspan="4" class="text-center py-5 text-muted">
                                                <i class="bi bi-trash3 display-4 d-block mb-3 text-black-50 opacity-50"></i>
                                                <p class="mb-0 fw-bold fs-5">La papelera está vacía.</p>
                                                <p class="small text-muted">Aquí aparecerán los colaboradores inactivos.</p>
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
HTML
print <<HTML;

<style>
  .export-toolbar { display: flex; gap: 0.5rem; flex-wrap: wrap; }
</style>

<!-- Scripts y Librerías de Exportación (DataTables) -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">

<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>

<!-- Librerías de exportación -->
<script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/vfs_fonts.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
    // Lógica para mostrar/ocultar formulario y llenarlo
    window.toggleFormulario = function() {
        const container = document.getElementById('formContainer');
        if (container.classList.contains('d-none')) {
            container.classList.remove('d-none');
            container.scrollIntoView({ behavior: 'smooth', block: 'start' });
        } else {
            container.classList.add('d-none');
        }
    };

    window.prepararNuevoUsuario = function() {
        document.getElementById('form_action').value = 'create';
        document.getElementById('form_id_usuario').value = '';
        document.getElementById('form_nombre').value = '';
        document.getElementById('form_correo').value = '';
        document.getElementById('form_clave').value = '';
        document.getElementById('form_clave').required = true;
        document.getElementById('passwordLabel').innerText = 'Contraseña Inicial';
        document.getElementById('form_rol').value = 'Medico';
        document.getElementById('form_id_sucursal').value = '';
        
        document.getElementById('formTitle').innerHTML = '<i class="bi bi-person-plus-fill me-2"></i>Añadir Colaborador';
        document.getElementById('formHeader').className = 'card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center';
        
        const container = document.getElementById('formContainer');
        container.classList.remove('d-none');
        container.scrollIntoView({ behavior: 'smooth', block: 'start' });
    };

    window.abrirFormEditar = function(id, nombre, correo, rol, id_sucursal) {
        document.getElementById('form_action').value = 'update';
        document.getElementById('form_id_usuario').value = id;
        document.getElementById('form_nombre').value = nombre;
        document.getElementById('form_correo').value = correo;
        document.getElementById('form_clave').value = '';
        document.getElementById('form_clave').required = false;
        document.getElementById('passwordLabel').innerText = 'Nueva Contraseña (Opcional)';
        document.getElementById('form_rol').value = rol;
        document.getElementById('form_id_sucursal').value = id_sucursal;
        
        document.getElementById('formTitle').innerHTML = '<i class="bi bi-pencil-square me-2"></i>Editar Colaborador';
        document.getElementById('formHeader').className = 'card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center';
        
        const container = document.getElementById('formContainer');
        container.classList.remove('d-none');
        container.scrollIntoView({ behavior: 'smooth', block: 'start' });
    };

    // Envío del Formulario
    document.getElementById('form-usuario').addEventListener('submit', function(e) {
        e.preventDefault();
        const fd = new FormData(this);
        const action = document.getElementById('form_action').value;
        const btn = document.getElementById('btn-submit-form');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Guardando...';

        const apiUrl = (action === 'create') ? '../api/alta_usuario_api.pl' : '../api/editar_usuario_api.pl';

        fetch(apiUrl, {
            method: 'POST',
            body: fd
        })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Guardado!',
                    text: 'El perfil del colaborador ha sido guardado.',
                    confirmButtonColor: '#18D1E6'
                }).then(() => location.reload());
            } else {
                Swal.fire('Error', data.message || 'Ocurrió un error.', 'error');
                btn.disabled = false;
                btn.innerHTML = '<i class="bi bi-save me-2"></i>Guardar Colaborador';
            }
        })
        .catch(err => {
            console.error(err);
            Swal.fire('Error', 'Falla de conexión.', 'error');
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-save me-2"></i>Guardar Colaborador';
        });
    });

    // Desactivar Usuario (Soft Delete)
    window.confirmDesactivar = function(id) {
        Swal.fire({
            title: '¿Desactivar Colaborador?',
            text: "El usuario ya no podrá iniciar sesión y pasará a la papelera.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, Desactivar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('id_usuario', id);
                fd.append('accion', 'deactivate');
                fetch('../api/baja_usuario_api.pl', {
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

    // Reactivar Usuario
    window.confirmReactivar = function(id) {
        Swal.fire({
            title: '¿Reactivar Colaborador?',
            text: "El usuario volverá a la lista de personal activo y podrá iniciar sesión.",
            icon: 'question',
            showCancelButton: true,
            confirmButtonColor: '#198754',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, Reactivar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('id_usuario', id);
                fd.append('accion', 'reactivate');
                fetch('../api/baja_usuario_api.pl', {
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

    // Eliminar Permanentemente (Físico)
    window.confirmEliminarDefinitivo = function(id) {
        Swal.fire({
            title: '¿Eliminar Permanentemente?',
            text: "Esta acción borrará de forma física al colaborador de la base de datos. No se puede deshacer. ¿Proceder?",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, BORRAR FÍSICAMENTE',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('id_usuario', id);
                fd.append('accion', 'delete_permanent');
                fetch('../api/baja_usuario_api.pl', {
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

    // Inicialización de DataTables Diamond
    \$(document).ready(function() {
        if (\$('#tablaUsuarios').length && \$('#tablaUsuarios tbody tr td').length > 1) {
            \$('#tablaUsuarios').DataTable({
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
                            exportOptions: { columns: [0, 1, 2] }
                        },
                        { 
                            extend: 'excel', 
                            text: '<i class="bi bi-file-earmark-excel"></i> Excel', 
                            title: 'Directorio de Personal - SDM',
                            exportOptions: { columns: [0, 1, 2] }
                        },
                        { 
                            extend: 'pdf', 
                            text: '<i class="bi bi-file-earmark-pdf"></i> PDF', 
                            title: 'Directorio de Personal - SDM',
                            exportOptions: { columns: [0, 1, 2] },
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
                                    doc.content[tableIndex].table.widths = ['40%', '30%', '30%'];
                                    doc.content[tableIndex].margin = [0, 10, 0, 10];
                                    if (tableIndex > 0) doc.content.splice(0, tableIndex);
                                }
                            }
                        }
                    ]
                }
            });
        }

        if (\$('#tablaUsuariosInactivos').length && \$('#tablaUsuariosInactivos tbody tr td').length > 1) {
            \$('#tablaUsuariosInactivos').DataTable({
                language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                dom: '<"p-3 d-flex justify-content-end align-items-center"f>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
            });
        }

        // Toggling styles on Tab Pills click dynamically
        \$('button[data-bs-toggle="pill"]').on('shown.bs.tab', function (e) {
            \$(e.target).removeClass('btn-light text-dark').addClass('btn-blue-deep text-white');
            \$(e.relatedTarget).removeClass('btn-blue-deep text-white').addClass('btn-light text-dark');
        });
    });
</script>
HTML

utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
</body>
</html>
HTML
render_bottom_nav('usuarios');
print $q->end_html;
