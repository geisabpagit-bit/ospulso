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
    render_acceso_denegado(
        q => $q, usuario => $usuario, role => $role,
        mensaje => 'Esta sección es exclusiva para el Administrador Global.',
        rol_requerido => 'Administrador Global'
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
    titulo      => "Administrador Global",
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'dashboard');

# Se movió la lógica de lectura de backups a admin_backups.pl

print <<HTML;
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
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 p-4">
                <div class="d-flex align-items-center mb-3">
                    <div class="bg-danger bg-opacity-10 text-danger rounded-circle d-flex justify-content-center align-items-center me-3" style="width: 55px; height: 55px;">
                        <i class="bi bi-exclamation-octagon-fill" style="font-size: 1.5rem;"></i>
                    </div>
                    <div>
                        <h4 class="fw-bold text-dark mb-0">Mantenimiento de Base de Datos</h4>
                        <p class="text-muted small mb-0 mt-1">Herramientas de depuración del sistema global</p>
                    </div>
                </div>
                <hr>
                <div class="mt-3 d-flex align-items-center flex-wrap gap-3">
                    <span class="badge bg-success bg-opacity-10 text-success border border-success border-opacity-25 rounded-pill px-3 py-2 fw-semibold">
                        <i class="bi bi-shield-check me-2"></i>Base de Datos Protegida (Modo Producción Activo)
                    </span>
                    <span class="text-muted small">Los reseteos destructivos se encuentran deshabilitados permanentemente para salvaguardar la operación clínica.</span>
                </div>
                </div>
            </div>

            <!-- BACKUP SECTION (Migrado a admin_backups.pl) -->

        </div>
    </main>

HTML

print <<'JS';
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
    window.hardResetDB = function() {
        Swal.fire('Función Deshabilitada', 'El Hard Reset se encuentra bloqueado permanentemente en producción.', 'info');
    };

    // Funciones de backup migradas a admin_backups.pl
</script>
JS
utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
</body>
</html>
HTML

render_bottom_nav('admin_global');
1;
