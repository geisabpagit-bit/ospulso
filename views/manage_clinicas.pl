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

print $q->header(-type => 'text/html', -charset => 'UTF-8');
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
                <button class="btn btn-light rounded-pill px-4 fw-bold shadow-sm" data-bs-toggle="modal" data-bs-target="#modalAltaSucursal">
                    <i class="bi bi-plus-circle text-primary me-2"></i>Nueva Sucursal
                </button>
            </div>
        </header>

        <div class="container-fluid px-4 pb-5">
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                <div class="card-body p-4">
                    <div class="table-responsive">
                        <table class="table table-hover align-middle mb-0">
                            <thead class="table-light">
                                <tr>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Sucursal</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Estado</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Teléfono</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Domicilio</th>
                                </tr>
                            </thead>
                            <tbody>
HTML

if (@mis_sucursales) {
    foreach my $suc (@mis_sucursales) {
        my $badge = $suc->{estado} eq 'Activa' ? 'bg-success' : 'bg-danger';
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
                                </tr>
HTML
    }
} else {
    print <<HTML;
                                <tr>
                                    <td colspan="4" class="text-center py-5 text-muted">
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

<style>
  .modal-backdrop.show { z-index: 104900 !important; }
  \@media (min-width: 992px) { 
      #modalAltaSucursal { padding-left: 280px !important; } 
  }
</style>
<!-- Modal: Alta Sucursal -->
<div class="modal fade modal-diamond" id="modalAltaSucursal" tabindex="-1" aria-hidden="true" style="z-index: 105000 !important;">
    <div class="modal-dialog modal-dialog-centered">
        <form id="form-alta-sucursal" class="w-100">
            <div class="modal-content border-0 shadow-lg rounded-4">
                <div class="modal-header border-0 bg-primary bg-gradient text-white py-3 px-4 rounded-top-4">
                    <h5 class="fw-black mb-0"><i class="bi bi-shop me-2"></i>Añadir Nueva Sucursal</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body p-4">
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted">Nombre de la Sucursal</label>
                        <input type="text" class="form-control form-control-lg bg-light border-0 rounded-3" name="nombre_sucursal" required placeholder="Ej: Sucursal Norte">
                    </div>
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted">Teléfono Principal</label>
                        <input type="text" class="form-control form-control-lg bg-light border-0 rounded-3" name="telefono" placeholder="555-1234">
                    </div>
                    <div class="mb-4">
                        <label class="form-label small fw-bold text-muted">Domicilio</label>
                        <input type="text" class="form-control form-control-lg bg-light border-0 rounded-3" name="domicilio" placeholder="Av. Siempre Viva 742">
                    </div>
                    <button type="submit" class="btn btn-primary rounded-pill py-3 w-100 fw-bold shadow-sm" id="btn-submit-sucursal">
                        <i class="bi bi-plus-circle me-2"></i>Registrar Sucursal
                    </button>
                </div>
            </div>
        </form>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
    document.body.appendChild(document.getElementById('modalAltaSucursal'));

    document.getElementById('form-alta-sucursal').addEventListener('submit', function(e) {
        e.preventDefault();
        const fd = new FormData(this);
        const btn = document.getElementById('btn-submit-sucursal');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Guardando...';

        fetch('../api/alta_sucursal_api.pl', {
            method: 'POST',
            body: fd
        })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Sucursal Creada!',
                    text: 'La sede ha sido dada de alta.',
                    confirmButtonColor: '#18D1E6'
                }).then(() => location.reload());
            } else {
                Swal.fire('Error', data.message || 'Ocurrió un error.', 'error');
                btn.disabled = false;
                btn.innerHTML = '<i class="bi bi-plus-circle me-2"></i>Registrar Sucursal';
            }
        })
        .catch(err => {
            console.error(err);
            Swal.fire('Error', 'Falla de conexión.', 'error');
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-plus-circle me-2"></i>Registrar Sucursal';
        });
    });
</script>
</body>
</html>
HTML

render_bottom_nav('clinicas');
1;
