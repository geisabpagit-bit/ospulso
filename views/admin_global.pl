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

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => "Administración Global",
    skip_header => 1
);

# Leer Usuarios Actuales (para ver los ejecutivos de ventas)
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '!');
my @ejecutivos = ();
if ($regs) {
    foreach my $r (@$regs) {
        next if @$r < 7;
        if ($r->[5] eq 'Ejecutivo Ventas') {
            push @ejecutivos, { id => $r->[0], nombre => $r->[1], correo => $r->[2] };
        }
    }
}

print <<HTML;
<!-- Inyectar Layout General -->
<div class="d-flex w-100 h-100 bg-light">
HTML
utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario);
print <<HTML;
    <main class="flex-grow-1" style="margin-left: var(--sidebar-width); margin-bottom: 70px; overflow-y: auto;">
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-globe me-2"></i>Administrador Global</h2>
                    <p class="text-white-50 small mb-0 mt-1">Gestión de Roles, Servidores y Fuerza de Ventas</p>
                </div>
            </div>
        </header>

        <!-- CONTAINER -->
        <div class="container-fluid px-4 pb-5">
            <div class="row g-4">
                
                <!-- CARD: CREAR EJECUTIVO -->
                <div class="col-12 col-xl-4">
                    <div class="card card-medentia-aura border-0 h-100 shadow-sm">
                        <div class="card-body p-4 d-flex flex-column align-items-center text-center">
                            <div class="kpi-icon-box bg-primary text-white shadow-sm mb-3" style="width: 70px; height: 70px; border-radius: 20px; display: flex; align-items: center; justify-content: center; font-size: 2rem;">
                                <i class="bi bi-person-badge"></i>
                            </div>
                            <h4 class="fw-bold text-dark mb-2">Fuerza de Ventas</h4>
                            <p class="text-muted small mb-4">Registra un nuevo Ejecutivo de Ventas. Ellos tendrán acceso al CRM Comercial para registrar Organizaciones.</p>
                            
                            <button type="button" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm w-100 mt-auto" data-bs-toggle="modal" data-bs-target="#modalAltaEjecutivo">
                                <i class="bi bi-plus-circle me-2"></i>Nuevo Ejecutivo
                            </button>
                        </div>
                    </div>
                </div>
                
                <!-- LISTA DE EJECUTIVOS -->
                <div class="col-12 col-xl-8">
                    <div class="card card-medentia-aura border-0 h-100 shadow-sm">
                        <div class="card-header bg-white border-0 pt-4 pb-0 px-4">
                            <h5 class="fw-bold text-dark"><i class="bi bi-list-stars text-primary me-2"></i>Ejecutivos de Ventas Activos</h5>
                        </div>
                        <div class="card-body p-4">
                            <div class="table-responsive">
                                <table class="table table-hover align-middle border-bottom">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Nombre</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Correo</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Acciones</th>
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
                                                    <div class="bg-primary bg-opacity-10 text-primary rounded-circle d-flex justify-content-center align-items-center fw-bold me-3" style="width: 40px; height: 40px;">
                                                        <i class="bi bi-person-fill"></i>
                                                    </div>
                                                    <span class="fw-bold text-dark">$$e{nombre}</span>
                                                </div>
                                            </td>
                                            <td class="text-muted small">$$e{correo}</td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-danger rounded-pill"><i class="bi bi-trash"></i></button>
                                            </td>
                                        </tr>
HTML
    }
} else {
    print <<HTML;
                                        <tr>
                                            <td colspan="3" class="text-center py-4 text-muted">
                                                <i class="bi bi-inbox fs-3 d-block mb-2 text-black-50"></i>
                                                Aún no hay Ejecutivos registrados en el sistema.
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
</div>

<!-- Modal: Alta Ejecutivo -->
<div class="modal fade" id="modalAltaEjecutivo" tabindex="-1" aria-hidden="true" style="z-index: 9999;">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content border-0 shadow-lg rounded-4">
            <div class="modal-header border-0 pb-0">
                <h5 class="fw-black text-dark"><i class="bi bi-person-plus text-primary me-2"></i>Alta de Ejecutivo</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-4">
                <form id="form-alta-ejecutivo">
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted">Nombre Completo</label>
                        <input type="text" class="form-control form-control-lg bg-light border-0 rounded-3" name="nombre" required placeholder="Ej: Maria Lopez">
                    </div>
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted">Correo Electrónico (Acceso)</label>
                        <input type="email" class="form-control form-control-lg bg-light border-0 rounded-3" name="correo" required placeholder="maria\@ospulso.com">
                    </div>
                    <div class="mb-4">
                        <label class="form-label small fw-bold text-muted">Contraseña Temporal</label>
                        <input type="password" class="form-control form-control-lg bg-light border-0 rounded-3" name="clave" required placeholder="••••••••">
                    </div>
                    <button type="submit" class="btn btn-primary rounded-pill py-3 w-100 fw-bold shadow-sm" id="btn-submit-ejecutivo">
                        Registrar en el Sistema
                    </button>
                </form>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
    document.getElementById('form-alta-ejecutivo').addEventListener('submit', function(e) {
        e.preventDefault();
        const fd = new FormData(this);
        const btn = document.getElementById('btn-submit-ejecutivo');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Registrando...';

        fetch('../api/alta_ejecutivo_api.pl', {
            method: 'POST',
            body: fd
        })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Ejecutivo Registrado!',
                    text: 'El ejecutivo ya puede iniciar sesión en OSPulso.',
                    confirmButtonColor: '#18D1E6'
                }).then(() => location.reload());
            } else {
                Swal.fire('Error', data.message || 'Error desconocido.', 'error');
                btn.disabled = false;
                btn.innerHTML = 'Registrar en el Sistema';
            }
        })
        .catch(err => {
            console.error(err);
            Swal.fire('Error', 'Falla en la red al registrar ejecutivo.', 'error');
            btn.disabled = false;
            btn.innerHTML = 'Registrar en el Sistema';
        });
    });
</script>
</body>
</html>
HTML

render_bottom_nav('admin_global');
1;
