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

print $q->header(-type => 'text/html', -charset => 'UTF-8');
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

# 2. Obtener usuarios
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
my @mi_personal = ();

if ($regs_usuarios) {
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        my $extra = $r->[6];
        my ($org_id, $suc_id) = split(/:/, $extra);
        
        # Si el usuario pertenece a mi organización y NO es el administrador global
        if ($org_id && $org_id eq $id_empresa && $r->[5] ne 'Administrador Organizacion') {
            push @mi_personal, {
                id => $r->[0],
                nombre => $r->[1],
                correo => $r->[2],
                rol => $r->[5],
                sucursal => $sucursales_hash{$suc_id} || 'No Asignada'
            };
        }
    }
}

print <<HTML;
<div class="d-flex w-100 h-100 bg-light">
HTML
utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario);
print <<HTML;
    <main class="flex-grow-1" style="margin-left: var(--sidebar-width); margin-bottom: 70px; overflow-y: auto;">
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-people-fill me-2"></i>Gestión de Personal</h2>
                    <p class="text-white-50 small mb-0 mt-1">Directorio de Médicos, Recepcionistas y Auxiliares</p>
                </div>
                <button class="btn btn-light rounded-pill px-4 fw-bold shadow-sm" data-bs-toggle="modal" data-bs-target="#modalAltaUsuario">
                    <i class="bi bi-person-plus-fill text-primary me-2"></i>Añadir Personal
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
                                    <th class="small fw-bold text-muted text-uppercase border-0">Colaborador</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Rol / Perfil</th>
                                    <th class="small fw-bold text-muted text-uppercase border-0">Sucursal Asignada</th>
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
                                </tr>
HTML
    }
} else {
    print <<HTML;
                                <tr>
                                    <td colspan="3" class="text-center py-5 text-muted">
                                        <i class="bi bi-person-badge display-4 d-block mb-3 text-black-50 opacity-50"></i>
                                        <p class="mb-0 fw-bold fs-5">Sin colaboradores registrados.</p>
                                        <p class="small text-muted">Agrega personal y asígnalo a tus sucursales.</p>
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
    </main>
</div>

<style>
  .modal-backdrop.show { z-index: 104900 !important; }
  \@media (min-width: 992px) { 
      #modalAltaUsuario { padding-left: 280px !important; } 
  }
</style>
<!-- Modal: Alta Usuario -->
<div class="modal fade modal-diamond" id="modalAltaUsuario" tabindex="-1" aria-hidden="true" style="z-index: 105000 !important;">
    <div class="modal-dialog modal-dialog-centered">
        <form id="form-alta-usuario" class="w-100">
            <div class="modal-content border-0 shadow-lg rounded-4">
                <div class="modal-header border-0 bg-primary bg-gradient text-white py-3 px-4 rounded-top-4">
                    <h5 class="fw-black mb-0"><i class="bi bi-person-plus-fill me-2"></i>Añadir Colaborador</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body p-4">
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted">Nombre Completo</label>
                        <input type="text" class="form-control form-control-lg bg-light border-0 rounded-3" name="nombre" required placeholder="Ej: Dra. María López">
                    </div>
                    <div class="row g-3 mb-3">
                        <div class="col-6">
                            <label class="form-label small fw-bold text-muted">Correo Electrónico</label>
                            <input type="email" class="form-control form-control-lg bg-light border-0 rounded-3" name="correo" required placeholder="maria\@clinica.com">
                        </div>
                        <div class="col-6">
                            <label class="form-label small fw-bold text-muted">Contraseña Inicial</label>
                            <input type="password" class="form-control form-control-lg bg-light border-0 rounded-3" name="clave" required placeholder="••••••••">
                        </div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted">Rol Operativo</label>
                        <select class="form-select form-select-lg bg-light border-0 rounded-3" name="rol" required>
                            <option value="Medico">Médico (Acceso a Expedientes)</option>
                            <option value="Recepcionista">Recepcionista (Agenda y Pagos)</option>
                        </select>
                    </div>
                    <div class="mb-4">
                        <label class="form-label small fw-bold text-muted">Asignar a Sucursal</label>
                        <select class="form-select form-select-lg bg-light border-0 rounded-3" name="id_sucursal" required>
                            <option value="" disabled selected>Selecciona una sede...</option>
HTML

foreach my $suc (@mis_sucursales) {
    print qq|                            <option value="$suc->{id}">$suc->{nombre}</option>\n|;
}

if (!@mis_sucursales) {
    print qq|                            <option value="" disabled>! PRIMERO DEBES CREAR UNA SUCURSAL</option>\n|;
}

print <<HTML;
                        </select>
                    </div>
                    <button type="submit" class="btn btn-primary rounded-pill py-3 w-100 fw-bold shadow-sm" id="btn-submit-usuario">
                        <i class="bi bi-person-check me-2"></i>Crear Cuenta
                    </button>
                </div>
            </div>
        </form>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
    document.body.appendChild(document.getElementById('modalAltaUsuario'));

    document.getElementById('form-alta-usuario').addEventListener('submit', function(e) {
        e.preventDefault();
        const fd = new FormData(this);
        const btn = document.getElementById('btn-submit-usuario');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Creando...';

        fetch('../api/alta_usuario_api.pl', {
            method: 'POST',
            body: fd
        })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Usuario Creado!',
                    text: 'El colaborador ya puede iniciar sesión.',
                    confirmButtonColor: '#18D1E6'
                }).then(() => location.reload());
            } else {
                Swal.fire('Error', data.message || 'Ocurrió un error.', 'error');
                btn.disabled = false;
                btn.innerHTML = '<i class="bi bi-person-check me-2"></i>Crear Cuenta';
            }
        })
        .catch(err => {
            console.error(err);
            Swal.fire('Error', 'Falla de conexión.', 'error');
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-person-check me-2"></i>Crear Cuenta';
        });
    });
</script>
</body>
</html>
HTML

render_bottom_nav('usuarios');
1;
