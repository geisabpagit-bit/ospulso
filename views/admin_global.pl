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
    titulo      => "Administrador Global",
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'dashboard');

my $backups_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'backups');
my @backups = ();
if (-d $backups_dir) {
    opendir(my $dh, $backups_dir);
    @backups = grep { $_ =~ /\.zip$/ } readdir($dh);
    closedir($dh);
}
# Ordenar del más reciente al más antiguo
@backups = sort { (stat(File::Spec->catfile($backups_dir, $b)))[9] <=> (stat(File::Spec->catfile($backups_dir, $a)))[9] } @backups;

my $filas_backups = "";
foreach my $b (@backups) {
    my $file_path = File::Spec->catfile($backups_dir, $b);
    my $mtime = (stat($file_path))[9];
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime($mtime);
    my $fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $hora = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    
    $filas_backups .= qq{
        <tr>
            <td class="align-middle fw-bold text-primary"><i class="bi bi-file-earmark-zip me-2"></i>$b</td>
            <td class="align-middle">$fecha</td>
            <td class="align-middle">$hora</td>
            <td class="align-middle text-end">
                <button class="btn btn-sm btn-success rounded-pill px-3 shadow-sm me-2" onclick="restoreDB('$b')">
                    <i class="bi bi-cloud-download me-1"></i>Restaurar
                </button>
                <button class="btn btn-sm btn-outline-danger rounded-pill px-3 shadow-sm" onclick="deleteBackup('$b')">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        </tr>
    };
}

if (!$filas_backups) {
    $filas_backups = qq{
        <tr><td colspan="4" class="text-center text-muted py-4">No hay copias de seguridad creadas aún.</td></tr>
    };
}

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
                    <button class="btn btn-danger rounded-pill px-4 fw-bold shadow-sm" onclick="hardResetDB()">
                        <i class="bi bi-exclamation-triangle-fill me-2"></i>Hard Reset DB
                    </button>
                    <span class="text-muted small"><strong>Advertencia:</strong> Esta acción eliminará toda la información transaccional y re-inicializará el sistema operativo.</span>
                </div>
                </div>
            </div>

            <!-- BACKUP SECTION -->
            <div class="card card-medentia-aura border-0 shadow-sm rounded-4 p-4 mt-4">
                <div class="d-flex justify-content-between align-items-center mb-3">
                    <div class="d-flex align-items-center">
                        <div class="bg-primary bg-opacity-10 text-primary rounded-circle d-flex justify-content-center align-items-center me-3" style="width: 55px; height: 55px;">
                            <i class="bi bi-hdd-network-fill" style="font-size: 1.5rem;"></i>
                        </div>
                        <div>
                            <h4 class="fw-bold text-dark mb-0">Copias de Seguridad (Backup & Restore)</h4>
                            <p class="text-muted small mb-0 mt-1">Administra los respaldos completos del sistema y archivos adjuntos</p>
                        </div>
                    </div>
                    <button class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm" onclick="createBackup()">
                        <i class="bi bi-cloud-upload-fill me-2"></i>Crear Backup Ahora
                    </button>
                </div>
                <hr>
                <div class="table-responsive mt-3">
                    <table class="table table-hover align-middle">
                        <thead class="table-light">
                            <tr>
                                <th>Nombre del Respaldo</th>
                                <th>Fecha</th>
                                <th>Hora</th>
                                <th class="text-end">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            $filas_backups
                        </tbody>
                    </table>
                </div>
            </div>
            <!-- END BACKUP SECTION -->

        </div>
    </main>

HTML

print <<'JS';
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
    window.hardResetDB = function() {
        Swal.fire({
            title: '¡Peligro Inminente!',
            text: 'Estás a punto de borrar TODA la base de datos operativa y resetear el sistema. Esto no se puede deshacer. ¿Proceder?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#3085d6',
            confirmButtonText: 'Sí, PURGAR TODO',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                Swal.fire({
                    title: 'Purgando Base de Datos...',
                    allowOutsideClick: false,
                    didOpen: () => { Swal.showLoading(); }
                });

                fetch('../api/hard_reset_db_api.pl')
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        Swal.fire(
                            '¡Base de Datos Purgada!',
                            'El sistema está en blanco. El Administrador Global ha sido reinstaurado.',
                            'success'
                        ).then(() => {
                            window.location.href = '../index.html'; // Obliga a reingresar
                        });
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                })
                .catch(err => {
                    Swal.fire('Error', 'Fallo de red al intentar resetear.', 'error');
                });
            }
        });
    };

    window.createBackup = function() {
        Swal.fire({
            title: 'Creando Respaldo...',
            text: 'Empaquetando la base de datos y archivos adjuntos. Esto puede tardar unos momentos.',
            allowOutsideClick: false,
            didOpen: () => { Swal.showLoading(); }
        });

        fetch('../api/backup_db_api.pl')
        .then(res => res.json())
        .then(data => {
            console.log("Respuesta de backup:", data);
            if (data.status === 'success') {
                Swal.fire('¡Éxito!', data.message, 'success').then(() => location.reload());
            } else {
                Swal.fire('Error', data.message, 'error');
            }
        }).catch(err => {
            console.error("Error de red en backup:", err);
            Swal.fire('Error', 'Error de red al crear el backup.', 'error');
        });
    };

    window.restoreDB = function(filename) {
        Swal.fire({
            title: '¡Restauración Destructiva!',
            text: 'Al restaurar, se borrará TODO tu estado actual para ser reemplazado por la copia "' + filename + '". ¿Confirmar?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#3085d6',
            confirmButtonText: 'Sí, Restaurar Ahora',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                Swal.fire({
                    title: 'Restaurando...',
                    text: 'Extrayendo datos y reconstruyendo el sistema.',
                    allowOutsideClick: false,
                    didOpen: () => { Swal.showLoading(); }
                });

                fetch('../api/restore_db_api.pl', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ filename: filename })
                })
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        Swal.fire('¡Restaurado!', data.message, 'success').then(() => location.reload());
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                }).catch(err => {
                    Swal.fire('Error', 'Error de red al restaurar.', 'error');
                });
            }
        });
    };

    window.deleteBackup = function(filename) {
        Swal.fire({
            title: '¿Eliminar Backup?',
            text: '¿Seguro que deseas eliminar el respaldo "' + filename + '" permanentemente?',
            icon: 'question',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#3085d6',
            confirmButtonText: 'Sí, Eliminar'
        }).then((result) => {
            if (result.isConfirmed) {
                Swal.fire({ title: 'Eliminando...', allowOutsideClick: false, didOpen: () => { Swal.showLoading(); } });

                fetch('../api/delete_backup_api.pl', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ filename: filename })
                })
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        Swal.fire('Eliminado', data.message, 'success').then(() => location.reload());
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                }).catch(err => {
                    Swal.fire('Error', 'Error de red.', 'error');
                });
            }
        });
    };
</script>
JS
utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
</body>
</html>
HTML

render_bottom_nav('admin_global');
1;
