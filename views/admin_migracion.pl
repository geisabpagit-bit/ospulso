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
    titulo      => "Migración SaaS",
    ruta_logout => '../auth/cerrar_sesion.pl',
    skip_header => 1
);

my $mig_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'migraciones');
my @migraciones = ();
if (-d $mig_dir) {
    opendir(my $dh, $mig_dir);
    @migraciones = grep { $_ =~ /\.zip$/ } readdir($dh);
    closedir($dh);
}
@migraciones = sort { (stat(File::Spec->catfile($mig_dir, $b)))[9] <=> (stat(File::Spec->catfile($mig_dir, $a)))[9] } @migraciones;

my $filas_mig = "";
foreach my $b (@migraciones) {
    my $file_path = File::Spec->catfile($mig_dir, $b);
    my $mtime = (stat($file_path))[9];
    my $size_bytes = (stat($file_path))[7] || 0;
    my $size_str = $size_bytes < 1048576 ? sprintf("%.2f KB", $size_bytes/1024) : sprintf("%.2f MB", $size_bytes/1048576);
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime($mtime);
    my $fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $hora = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    
    $filas_mig .= qq{
        <tr>
            <td class="align-middle fw-bold text-dark"><i class="bi bi-box-seam me-2"></i>$b</td>
            <td class="align-middle">$size_str</td>
            <td class="align-middle">$fecha</td>
            <td class="align-middle">$hora</td>
            <td class="align-middle text-end">
                <a href="../dat/migraciones/$b" class="btn btn-sm btn-dark rounded-pill px-3 shadow-sm me-2" download>
                    <i class="bi bi-cloud-download me-1"></i>Descargar
                </a>
                <button class="btn btn-sm btn-outline-danger rounded-pill px-3 shadow-sm" onclick="deleteMigration('$b')">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        </tr>
    };
}
if (!$filas_mig) {
    $filas_mig = qq{<tr><td colspan="5" class="text-center text-muted py-4">No hay paquetes de migración creados aún.</td></tr>};
}

print <<HTML;
<div class="container mt-4 mb-5 pb-5 animate__animated animate__fadeIn">
    <div class="d-flex justify-content-between align-items-center mb-3">
        <div class="d-flex align-items-center">
            <a href="administracion_catalogo.pl" class="btn btn-outline-secondary rounded-circle me-3" style="width: 45px; height: 45px; display: flex; align-items: center; justify-content: center;">
                <i class="bi bi-arrow-left"></i>
            </a>
            <div>
                <h3 class="fw-bold m-0"><i class="bi bi-cloud-arrow-down-fill text-dark me-2"></i>Migración SaaS</h3>
                <p class="text-muted small mb-0">Copia completa de código fuente y base de datos.</p>
            </div>
        </div>
        <div>
            <button class="btn btn-dark rounded-pill px-4 fw-bold shadow-sm" onclick="createMigration()">
                <i class="bi bi-box-seam me-2"></i>Empaquetar SaaS Ahora
            </button>
        </div>
    </div>
    
    <div class="alert alert-warning border-0 shadow-sm rounded-4 mt-3 mb-4">
        <i class="bi bi-exclamation-triangle-fill me-2"></i><strong>Atención:</strong> A diferencia de un respaldo regular, la migración empaqueta <strong>todo el sistema</strong> (código fuente, scripts, imágenes, etc.). Este proceso puede tardar varios minutos y el archivo resultante será muy pesado. No abuses de esta función para evitar llenar el disco.
    </div>

    <div class="card card-medentia-aura border-0 shadow-sm rounded-4 p-4">
        <div class="table-responsive">
            <table class="table table-hover align-middle">
                <thead class="table-light">
                    <tr>
                        <th>Nombre del Paquete</th>
                        <th>Tamaño</th>
                        <th>Fecha</th>
                        <th>Hora</th>
                        <th class="text-end">Acciones</th>
                    </tr>
                </thead>
                <tbody>
                    $filas_mig
                </tbody>
            </table>
        </div>
    </div>
</div>
HTML

print <<'JS';
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
    window.createMigration = function() {
        Swal.fire({
            title: 'Empaquetando SaaS...',
            text: 'Comprimiendo todo el código fuente y datos. Esto tomará tiempo, por favor no cierres la ventana.',
            allowOutsideClick: false,
            didOpen: () => { Swal.showLoading(); }
        });

        fetch('../api/migration_db_api.pl')
        .then(res => res.json())
        .then(data => {
            console.log("Respuesta de migration:", data);
            if (data.status === 'success') {
                Swal.fire('¡Éxito!', data.message, 'success').then(() => location.reload());
            } else {
                Swal.fire('Error', data.message, 'error');
            }
        }).catch(err => {
            console.error("Error de red en migration:", err);
            Swal.fire('Error', 'Error de red al crear el paquete de migración.', 'error');
        });
    };

    window.deleteMigration = function(filename) {
        Swal.fire({
            title: '¿Eliminar Paquete?',
            text: '¿Seguro que deseas eliminar el paquete "' + filename + '" permanentemente?',
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

                fetch('../api/delete_migration_api.pl', {
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
