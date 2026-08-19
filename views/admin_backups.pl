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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario   = $sd->{usuario};
my $role      = $sd->{role};

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
    titulo      => "Backup & Restore",
    ruta_logout => '../auth/cerrar_sesion.pl',
    skip_header => 1
);

my $backups_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'backups');
my @backups = ();
if (-d $backups_dir) {
    opendir(my $dh, $backups_dir);
    @backups = grep { $_ =~ /\.zip$/ } readdir($dh);
    closedir($dh);
}
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
    $filas_backups = qq{<tr><td colspan="4" class="text-center text-muted py-4">No hay copias de seguridad creadas aún.</td></tr>};
}

print <<HTML;
<div class="container mt-4 mb-5 pb-5 animate__animated animate__fadeIn">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <div class="d-flex align-items-center">
            <a href="administracion_catalogo.pl" class="btn btn-outline-secondary rounded-circle me-3" style="width: 45px; height: 45px; display: flex; align-items: center; justify-content: center;">
                <i class="bi bi-arrow-left"></i>
            </a>
            <div>
                <h3 class="fw-bold m-0"><i class="bi bi-hdd-network-fill text-primary me-2"></i>Backup & Restore</h3>
                <p class="text-muted small mb-0">Gestión de respaldos del sistema.</p>
            </div>
        </div>
        <button class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm" onclick="createBackup()">
            <i class="bi bi-cloud-upload-fill me-2"></i>Crear Backup Ahora
        </button>
    </div>
    
    <div class="card card-medentia-aura border-0 shadow-sm rounded-4 p-4 mt-4">
        <div class="table-responsive">
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
</div>
HTML

print <<'JS';
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
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

                let fd = new FormData();
                fd.append('filename', filename);

                fetch('../api/restore_db_api.pl', {
                    method: 'POST',
                    body: fd
                })
                .then(res => res.json())
                .then(data => {
                    console.log("Respuesta de restore:", data);
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

                let fd = new FormData();
                fd.append('filename', filename);

                fetch('../api/delete_backup_api.pl', {
                    method: 'POST',
                    body: fd
                })
                .then(res => res.json())
                .then(data => {
                    console.log("Respuesta de delete:", data);
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

render_footer();
render_bottom_nav('ajustes');
1;
