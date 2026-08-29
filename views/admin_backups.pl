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
    titulo      => "Backup & Restore",
    ruta_logout => '../auth/cerrar_sesion.pl',
    skip_header => 1
);

my $backups_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'backups');
my @backups = ();
if (-d $backups_dir) {
    my $now = time;
    opendir(my $dh, $backups_dir);
    my @all_files = readdir($dh);
    closedir($dh);

    foreach my $f (@all_files) {
        next unless $f =~ /\.zip$/;
        # Purga de respaldos automáticos con permanencia mayor a 3 días (3 * 86400 = 259,200 segundos)
        if ($f =~ /^auto_backup_ospulso_/) {
            my $fp = File::Spec->catfile($backups_dir, $f);
            my $mtime = (stat($fp))[9] || 0;
            if ($mtime > 0 && ($now - $mtime) > (3 * 86400)) {
                unlink($fp);
                next;
            }
        }
        push @backups, $f;
    }
}
sub get_backup_timestamp {
    my ($file) = @_;
    if ($file =~ /(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.zip$/) {
        return "$1$2$3$4$5$6";
    }
    my $path = File::Spec->catfile($backups_dir, $file);
    return (stat($path))[9] || 0;
}
@backups = sort { get_backup_timestamp($b) cmp get_backup_timestamp($a) } @backups;

my $filas_backups = "";
my $latest_fecha = "";
my $latest_hora = "";
my $latest_name = "";

foreach my $b (@backups) {
    my $file_path = File::Spec->catfile($backups_dir, $b);
    my $size_bytes = (stat($file_path))[7] || 0;
    my $size_str = $size_bytes < 1048576 ? sprintf("%.2f KB", $size_bytes/1024) : sprintf("%.2f MB", $size_bytes/1048576);
    
    my ($fecha, $hora);
    if ($b =~ /(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.zip$/) {
        $fecha = "$1-$2-$3";
        $hora  = "$4:$5:$6";
    } else {
        my $mtime = (stat($file_path))[9] || time;
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime($mtime);
        $fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
        $hora = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
    }

    if (!$latest_name) {
        $latest_name  = $b;
        $latest_fecha = $fecha;
        $latest_hora  = $hora;
    }
    
    $filas_backups .= qq{
        <tr>
            <td class="align-middle fw-bold text-primary"><i class="bi bi-file-earmark-zip me-2"></i>$b</td>
            <td class="align-middle">$size_str</td>
            <td class="align-middle">$fecha</td>
            <td class="align-middle">$hora</td>
            <td class="align-middle text-end">
                <button type="button" class="btn btn-sm btn-success rounded-pill px-3 shadow-sm me-2" onclick="restoreDB('$b')">
                    <i class="bi bi-cloud-download me-1"></i>Restaurar
                </button>
                <button type="button" class="btn btn-sm btn-outline-danger rounded-pill px-3 shadow-sm" onclick="deleteBackup('$b')">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        </tr>
    };
}
if (!$filas_backups) {
    $filas_backups = qq{<tr><td colspan="5" class="text-center text-muted py-4">No hay copias de seguridad creadas aún.</td></tr>};
}

my $debug_info_json = JSON::PP::encode_json({
    auto_backup_en_carga => 0,
    total_respaldos      => scalar(@backups),
    ultimo_respaldo      => $latest_name || 'Ninguno',
    fecha_ultimo         => $latest_fecha || 'N/A',
    hora_ultimo          => $latest_hora || 'N/A'
});

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
        <div>
            <button type="button" class="btn btn-outline-primary rounded-pill px-3 fw-bold shadow-sm me-2" onclick="openCronModal()">
                <i class="bi bi-clock-history me-2"></i>Programar
            </button>
            <button type="button" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm" onclick="createBackup()">
                <i class="bi bi-cloud-upload-fill me-2"></i>Crear Backup Ahora
            </button>
        </div>
    </div>
    
    <div class="card card-medentia-aura border-0 shadow-sm rounded-4 p-4 mt-4">
        <div class="table-responsive">
            <table class="table table-hover align-middle">
                <thead class="table-light">
                    <tr>
                        <th>Nombre del Respaldo</th>
                        <th>Tamaño</th>
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

<!-- Modal Cron -->
<div class="modal fade" id="modalCron" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content border-0 shadow-lg rounded-4">
            <div class="modal-header bg-primary text-white border-0" style="border-radius: 1rem 1rem 0 0;">
                <h5 class="modal-title fw-bold"><i class="bi bi-clock-history me-2"></i>Programar Respaldos Automáticos</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-4">
                <div class="form-check form-switch mb-4">
                    <input class="form-check-input" type="checkbox" id="cronEnabled" style="transform: scale(1.5); margin-left: -2.5em; margin-right: 1rem; cursor: pointer;">
                    <label class="form-check-label fw-bold" for="cronEnabled" style="padding-top: 0.2rem; cursor: pointer;">Activar Respaldos Automáticos</label>
                </div>
                
                <div id="cronSettings" style="display: none;" class="animate__animated animate__fadeIn">
                    <h6 class="fw-bold text-muted mb-2">Días de ejecución</h6>
                    <div class="d-flex flex-wrap gap-2 mb-4">
                        <input type="checkbox" class="btn-check day-check" id="day_1" value="1" autocomplete="off"><label class="btn btn-outline-primary rounded-circle" style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;" for="day_1">L</label>
                        <input type="checkbox" class="btn-check day-check" id="day_2" value="2" autocomplete="off"><label class="btn btn-outline-primary rounded-circle" style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;" for="day_2">M</label>
                        <input type="checkbox" class="btn-check day-check" id="day_3" value="3" autocomplete="off"><label class="btn btn-outline-primary rounded-circle" style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;" for="day_3">M</label>
                        <input type="checkbox" class="btn-check day-check" id="day_4" value="4" autocomplete="off"><label class="btn btn-outline-primary rounded-circle" style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;" for="day_4">J</label>
                        <input type="checkbox" class="btn-check day-check" id="day_5" value="5" autocomplete="off"><label class="btn btn-outline-primary rounded-circle" style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;" for="day_5">V</label>
                        <input type="checkbox" class="btn-check day-check" id="day_6" value="6" autocomplete="off"><label class="btn btn-outline-primary rounded-circle" style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;" for="day_6">S</label>
                        <input type="checkbox" class="btn-check day-check" id="day_0" value="0" autocomplete="off"><label class="btn btn-outline-primary rounded-circle" style="width: 40px; height: 40px; display: flex; align-items: center; justify-content: center;" for="day_0">D</label>
                    </div>

                    <h6 class="fw-bold text-muted mb-2">Hora de ejecución</h6>
                    <input type="time" id="cronTime" class="form-control form-control-lg rounded-3 mb-3">
                    
                    <div class="alert alert-info border-0 shadow-sm rounded-3 py-2 px-3 small mb-0">
                        <i class="bi bi-info-circle-fill me-2"></i>El sistema conservará únicamente los respaldos automáticos de los últimos 3 días.
                    </div>
                </div>
            </div>
            <div class="modal-footer border-0 pb-4 px-4">
                <button type="button" class="btn btn-light rounded-pill px-4 fw-bold" data-bs-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-primary rounded-pill px-4 fw-bold" onclick="saveCronConfig()"><i class="bi bi-save me-2"></i>Guardar Cambios</button>
            </div>
        </div>
    </div>
</div>
HTML

print <<"JS";
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
    const DEBUG_BACKUP_STATE = $debug_info_json;
    
    document.addEventListener('DOMContentLoaded', function() {
        console.log("[DEBUG OSPulso Backup] Acceso a la vista admin_backups.pl");
        console.log("[DEBUG OSPulso Backup] auto_backup_en_carga: 0");
        console.log("[DEBUG OSPulso Backup] Último respaldo registrado:", DEBUG_BACKUP_STATE.ultimo_respaldo);
        console.log("[DEBUG OSPulso Backup] Fecha de creación:", DEBUG_BACKUP_STATE.fecha_ultimo + " " + DEBUG_BACKUP_STATE.hora_ultimo);
        console.log("[DEBUG OSPulso Backup] Estado general:", DEBUG_BACKUP_STATE);

        const cronEl = document.getElementById('cronEnabled');
        if (cronEl) {
            cronEl.addEventListener('change', function() {
                const settingsEl = document.getElementById('cronSettings');
                if (settingsEl) settingsEl.style.display = this.checked ? 'block' : 'none';
            });
        }
    });

    window.openCronModal = function() {
        Swal.showLoading();
        fetch('../api/get_cron_backup_config_api.pl')
        .then(res => res.json())
        .then(data => {
            Swal.close();
            if(data.status === 'success') {
                document.getElementById('cronEnabled').checked = (data.config.enabled == 1);
                document.getElementById('cronSettings').style.display = (data.config.enabled == 1) ? 'block' : 'none';
                document.getElementById('cronTime').value = data.config.time || '03:00';
                
                document.querySelectorAll('.day-check').forEach(cb => cb.checked = false);
                if(data.config.days) {
                    data.config.days.split(',').forEach(d => {
                        let cb = document.getElementById('day_' + d);
                        if(cb) cb.checked = true;
                    });
                }
            } else {
                document.getElementById('cronEnabled').checked = false;
                document.getElementById('cronSettings').style.display = 'none';
                document.getElementById('cronTime').value = '03:00';
                document.querySelectorAll('.day-check').forEach(cb => cb.checked = false);
            }
            var myModal = new bootstrap.Modal(document.getElementById('modalCron'));
            myModal.show();
        }).catch(err => {
            Swal.close();
            Swal.fire('Error', 'No se pudo cargar la configuración', 'error');
        });
    };

    window.saveCronConfig = function() {
        let enabled = document.getElementById('cronEnabled').checked ? 1 : 0;
        let time = document.getElementById('cronTime').value;
        let days = Array.from(document.querySelectorAll('.day-check:checked')).map(cb => cb.value).join(',');

        if (enabled && (!time || !days)) {
            Swal.fire('Atención', 'Si activas el respaldo, debes elegir al menos un día y la hora.', 'warning');
            return;
        }

        let fd = new FormData();
        fd.append('enabled', enabled);
        fd.append('time', time);
        fd.append('days', days);

        fetch('../api/save_cron_backup_config_api.pl', { method: 'POST', body: fd })
        .then(res => res.json())
        .then(data => {
            if(data.status === 'success') {
                Swal.fire('Guardado', 'La programación ha sido actualizada exitosamente.', 'success');
                bootstrap.Modal.getInstance(document.getElementById('modalCron')).hide();
            } else {
                Swal.fire('Error', data.message, 'error');
            }
        }).catch(err => {
            Swal.fire('Error', 'Error de red al guardar.', 'error');
        });
    };

    window.createBackup = function() {
        console.log("[DEBUG OSPulso Backup] Acción manual gatillada por el usuario. crear_backup_manual_click: 1");
        
        Swal.fire({
            title: 'Creando Respaldo...',
            text: 'Empaquetando la base de datos y archivos adjuntos. Esto puede tardar unos momentos.',
            allowOutsideClick: false,
            didOpen: () => { Swal.showLoading(); }
        });

        fetch('../api/backup_db_api.pl')
        .then(res => res.json())
        .then(data => {
            console.log("[DEBUG OSPulso Backup] Respuesta de API backup_db_api.pl:", data);
            if (data.status === 'success') {
                Swal.fire('¡Éxito!', data.message, 'success').then(() => location.reload());
            } else {
                Swal.fire('Error', data.message, 'error');
            }
        }).catch(err => {
            console.error("[DEBUG OSPulso Backup] Error de red en backup:", err);
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
                    console.log("[DEBUG OSPulso Backup] Respuesta de restore:", data);
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
                    console.log("[DEBUG OSPulso Backup] Respuesta de delete:", data);
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
