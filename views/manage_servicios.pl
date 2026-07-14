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

# Seguridad: Sólo Administrador de Organización puede ver/gestionar Servicios
if ($role ne 'Administrador Organizacion' && $role ne 'Administrador Global') {
    print $q->header(-status => '403 Forbidden');
    print "<h1>Acceso Denegado</h1><p>Esta sección es exclusiva para el Administrador de la Organización.</p>";
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
    titulo      => "Catálogo de Servicios",
    skip_header => 1
);

my $rutas_cat = catalogo_org_utils::obtener_rutas_catalogo($id_empresa);
my $archivo_serv = $rutas_cat->{servicios};

my $regs = leer_tabla($archivo_serv, '\|');
my @mis_servicios = ();

if ($regs) {
    foreach my $r (@$regs) {
        next if @$r < 3;
        push @mis_servicios, { 
            id => $r->[0], 
            nombre => $r->[1],
            precio => $r->[2] || '0.00',
            descripcion => $r->[3] || ''
        };
    }
}

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'servicios');
print <<HTML;
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-heart-pulse me-2"></i>Catálogo de Servicios</h2>
                    <p class="text-white-50 small mb-0 mt-1">Gestión de precios y descripciones para cotizaciones</p>
                </div>
                <button class="btn btn-sdm-primary rounded-pill px-4 fw-bold shadow-sm" onclick="prepararNuevoServicio()">
                    <i class="bi bi-plus-circle me-2"></i>Nuevo Servicio
                </button>
            </div>
        </header>

        <div class="container-fluid px-4 pb-5">
            <!-- Contenedor del Formulario Inline (Alta/Edición) -->
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 mb-4 d-none animate__animated animate__fadeIn" id="formContainer">
                <div class="card-header border-0 bg-primary bg-gradient text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center" id="formHeader">
                    <h5 class="modal-title fw-black mb-0" id="formTitle"><i class="bi bi-heart-pulse me-2"></i>Nuevo Servicio</h5>
                    <button type="button" class="btn-close btn-close-white" onclick="toggleFormulario()"></button>
                </div>
                <div class="card-body p-4 bg-light rounded-bottom-4">
                    <form id="form-servicio" class="form-sdm-container">
                        <input type="hidden" name="action" id="action_serv" value="create">
                        <input type="hidden" name="id_servicio" id="id_servicio_edit" value="">
                        
                        <div class="row g-3">
                            <div class="col-12 col-md-6">
                                <label class="form-label small fw-bold">Nombre del Servicio</label>
                                <input type="text" class="form-control form-control-sm shadow-sm" name="nombre" id="in_nombre" required placeholder="Ej. Consulta Especialista">
                            </div>
                            <div class="col-12 col-md-6">
                                <label class="form-label small fw-bold">Precio Unitario (\$)</label>
                                <input type="number" step="0.01" class="form-control form-control-sm shadow-sm" name="precio" id="in_precio" required placeholder="Ej. 800.00">
                            </div>
                            <div class="col-12">
                                <label class="form-label small fw-bold">Descripción (Opcional)</label>
                                <textarea class="form-control form-control-sm shadow-sm" name="descripcion" id="in_desc" rows="2" placeholder="Breve descripción del servicio"></textarea>
                            </div>
                        </div>
                        <div class="mt-4 d-flex justify-content-end gap-2">
                            <button type="button" class="btn btn-light fw-bold px-4" onclick="toggleFormulario()">Cancelar</button>
                            <button type="submit" class="btn btn-sdm-primary rounded-pill px-4 fw-bold shadow-sm">
                                <i class="bi bi-save me-2"></i>Guardar Servicio
                            </button>
                        </div>
                    </form>
                </div>
            </div>

            <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                <div class="card-body p-4">
                    <div class="table-responsive">
                        <table class="table table-hover align-middle mb-0" id="tablaServicios">
                            <thead class="table-light">
                                <tr>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Servicio</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Descripción</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Precio</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0 text-end">Acciones</th>
                                </tr>
                            </thead>
                            <tbody>
HTML

if (@mis_servicios) {
    foreach my $srv (@mis_servicios) {
        my $id_srv = $srv->{id};
        my $nombre = $srv->{nombre};
        my $desc = $srv->{descripcion};
        my $precio = $srv->{precio};
        # Escapamos las comillas simples para pasarlas de forma segura a JS
        my $nombre_esc = $nombre; $nombre_esc =~ s/'/\\'/g;
        my $desc_esc = $desc; $desc_esc =~ s/'/\\'/g;
        print <<HTML;
                                <tr>
                                    <td><span class="fw-bold text-dark"><i class="bi bi-clipboard-check text-primary me-2"></i>$nombre</span></td>
                                    <td><span class="text-muted small">$desc</span></td>
                                    <td><span class="badge bg-success bg-opacity-10 text-success px-3 py-2 rounded-pill fw-bold">\$ $precio</span></td>
                                    <td class="text-end">
                                        <button class="btn btn-sm btn-light text-primary rounded-pill me-1" onclick="editarServicio('$id_srv', '$nombre_esc', '$precio', '$desc_esc')"><i class="bi bi-pencil"></i></button>
                                        <button class="btn btn-sm btn-light text-danger rounded-pill" onclick="eliminarServicio('$id_srv')"><i class="bi bi-trash"></i></button>
                                    </td>
                                </tr>
HTML
    }
} else {
    print <<HTML;
                                <tr>
                                    <td colspan="4" class="text-center text-muted py-5">
                                        <i class="bi bi-folder-x fs-1 text-light mb-3 d-block"></i>
                                        Aún no hay servicios registrados en su catálogo.
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

<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
    window.toggleFormulario = function() {
        const container = document.getElementById('formContainer');
        if (container.classList.contains('d-none')) {
            container.classList.remove('d-none');
            container.scrollIntoView({ behavior: 'smooth' });
        } else {
            container.classList.add('d-none');
        }
    }

    window.prepararNuevoServicio = function() {
        document.getElementById('action_serv').value = 'create';
        document.getElementById('id_servicio_edit').value = '';
        document.getElementById('in_nombre').value = '';
        document.getElementById('in_precio').value = '';
        document.getElementById('in_desc').value = '';
        document.getElementById('formTitle').innerHTML = '<i class="bi bi-heart-pulse me-2"></i>Nuevo Servicio';
        document.getElementById('formHeader').className = 'card-header border-0 bg-primary bg-gradient text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center';
        
        const container = document.getElementById('formContainer');
        container.classList.remove('d-none');
        container.scrollIntoView({ behavior: 'smooth' });
    }

    window.editarServicio = function(id, nombre, precio, desc) {
        document.getElementById('action_serv').value = 'update';
        document.getElementById('id_servicio_edit').value = id;
        document.getElementById('in_nombre').value = nombre;
        document.getElementById('in_precio').value = precio;
        document.getElementById('in_desc').value = desc;
        document.getElementById('formTitle').innerHTML = '<i class="bi bi-pencil me-2"></i>Editar Servicio';
        document.getElementById('formHeader').className = 'card-header border-0 bg-navy text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center';
        
        const container = document.getElementById('formContainer');
        container.classList.remove('d-none');
        container.scrollIntoView({ behavior: 'smooth' });
    }

    document.getElementById('form-servicio').addEventListener('submit', function(e) {
        e.preventDefault();
        const fd = new FormData(this);
        fetch('../api/crud_servicios_org_api.pl', {
            method: 'POST',
            body: fd
        })
        .then(r => r.json())
        .then(data => {
            if (data.status === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Guardado!',
                    text: 'El servicio se guardó correctamente.',
                    confirmButtonColor: '#18D1E6'
                }).then(() => location.reload());
            } else {
                Swal.fire('Error', data.message, 'error');
            }
        })
        .catch(err => {
            Swal.fire('Error', 'Falla en la red.', 'error');
        });
    });

    window.eliminarServicio = function(id) {
        Swal.fire({
            title: '¿Estás seguro?',
            text: "Se eliminará el servicio de tu catálogo.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#aaa',
            confirmButtonText: 'Sí, eliminar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('action', 'delete');
                fd.append('id_servicio', id);
                fetch('../api/crud_servicios_org_api.pl', {
                    method: 'POST',
                    body: fd
                })
                .then(r => r.json())
                .then(data => {
                    if(data.status === 'success') location.reload();
                    else Swal.fire('Error', data.message, 'error');
                });
            }
        });
    }
</script>
HTML
render_bottom_nav('servicios');
print $q->end_html;
