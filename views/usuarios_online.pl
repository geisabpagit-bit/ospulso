#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/..";
use CGI;

BEGIN {
    $ENV{TZ} = 'America/Mexico_City';
}
use POSIX qw(tzset);
eval { tzset(); };

require "$FindBin::Bin/../auth/check_session.pl";
require "$FindBin::Bin/../utils/sub_header.pl";

my $q = CGI->new;
my $session_data = main::check_session();
if (!$session_data) {
    print $q->redirect(-uri => '../index.html');
    exit;
}

my $role = $session_data->{role} || 'Visitante';
my $usuario = $session_data->{usuario} || 'Usuario';

if ($role ne 'Administrador Global' && $role ne 'Administrador Organizacion') {
    print $q->redirect(-uri => '../index.html');
    exit;
}

my $is_global = ($role eq 'Administrador Global') ? 1 : 0;

render_header(
    titulo => 'Usuarios en Línea - OSPulso',
    role  => $role,
    usuario => $usuario,
    pagina_actual => 'usuarios_online'
);

print <<'HTML';
<div class="container-fluid container-mobile-flush py-4">
    <div class="d-flex flex-column flex-md-row justify-content-between align-items-md-center mb-4 gap-3">
        <div>
            <h2 class="plus-jakarta fw-bold text-dark mb-1 d-flex align-items-center gap-2">
                <div class="pulse-indicator" style="width:12px;height:12px;background:#00C4C4;border-radius:50%;box-shadow: 0 0 10px #00C4C4;"></div>
                Usuarios en Línea
            </h2>
            <p class="text-secondary mb-0">Monitoreo en tiempo real de sesiones activas (Protocolo 500 Guard)</p>
        </div>
HTML

if ($is_global) {
    print <<'HTML';
        <div class="card border-0 shadow-sm" style="min-width:300px; border-radius:12px;">
            <div class="card-body p-3">
                <label class="form-label fw-bold text-dark mb-1" style="font-size:0.85rem;">Límite Global de Inactividad (Minutos)</label>
                <div class="d-flex gap-2">
                    <input type="number" id="timeoutConfig" class="form-control form-control-sm" value="" min="1">
                    <button class="btn btn-sm btn-primary btn-mobile-standard" onclick="guardarConfiguracion()">Guardar</button>
                </div>
            </div>
        </div>
HTML
}

print <<'HTML';
    </div>

    <div class="card card-mobile-flush border-0 shadow-sm" style="border-radius:16px;">
        <div class="card-body p-4 p-md-4">
            <div class="table-responsive">
                <table id="dtOnlineUsers" class="table table-hover align-middle w-100 table-borderless">
                    <thead>
                        <tr>
                            <th class="text-secondary" style="font-size:0.85rem;">USUARIO</th>
                            <th class="text-secondary" style="font-size:0.85rem;">ROL</th>
                            <th class="text-secondary" style="font-size:0.85rem;">ÚLTIMA ACTIVIDAD</th>
                            <th class="text-secondary" style="font-size:0.85rem;">DIRECCIÓN IP</th>
                        </tr>
                    </thead>
                    <tbody>
                        <!-- Llenado via Ajax -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<!-- Animación de pulso -->
<style>
@keyframes pulseGlow {
    0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(0, 196, 196, 0.7); }
    70% { transform: scale(1); box-shadow: 0 0 0 8px rgba(0, 196, 196, 0); }
    100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(0, 196, 196, 0); }
}
.pulse-indicator {
    animation: pulseGlow 2s infinite;
}
</style>

<script>
let dtUsers;
document.addEventListener('DOMContentLoaded', function() {
    // Configurar CSRF token global si aplica, SweetAlert2 está cargado en sub_header
    
    dtUsers = $('#dtOnlineUsers').DataTable({
        ajax: {
            url: '../api/get_usuarios_online_api.pl',
            dataSrc: function(json) {
                if (json.status === 'error') {
                    Swal.fire('Error', json.message, 'error');
                    return [];
                }
                // Si es Global Admin, llenamos el input config con el valor devuelto
                if ($('#timeoutConfig').length && $('#timeoutConfig').val() === '') {
                    $('#timeoutConfig').val(json.timeout_config || 30);
                }
                return json.data;
            }
        },
        columns: [
            { 
                data: 'usuario',
                render: function(data, type, row) {
                    return `<div class="d-flex align-items-center gap-2">
                                <div class="bg-primary text-white rounded-circle d-flex align-items-center justify-content-center" style="width:32px;height:32px;font-size:0.85rem;font-weight:600;">
                                    ${data.substring(0,1).toUpperCase()}
                                </div>
                                <span class="fw-bold text-dark">${data}</span>
                            </div>`;
                }
            },
            { data: 'role', className: 'text-secondary fw-medium' },
            { 
                data: 'actividad', 
                render: function(data) {
                    return `<span class="badge bg-success bg-opacity-10 text-success rounded-pill px-3 py-2"><i class="bi bi-clock-history me-1"></i> ${data}</span>`;
                }
            },
            { data: 'ip', className: 'text-muted font-monospace small' }
        ],
        language: { url: "https://cdn.datatables.net/plug-ins/1.13.6/i18n/es-ES.json" },
        dom: '<"row mb-3"<"col-md-6"B><"col-md-6"f>>rt<"row mt-3"<"col-md-6"i><"col-md-6"p>>',
        buttons: [
            { extend: 'excel', text: '<i class="bi bi-file-earmark-excel"></i> Exportar', className: 'btn btn-light shadow-sm' }
        ],
        pageLength: 25,
        ordering: false // Los más recientes deberían venir así, o dejamos default
    });

    // Auto-refresh cada 30 segundos
    setInterval(() => {
        dtUsers.ajax.reload(null, false); // false = no resetear paginación
    }, 30000);
});

function guardarConfiguracion() {
    let t = $('#timeoutConfig').val();
    if (!t || t < 1) {
        Swal.fire('Atención', 'Ingresa un límite válido de minutos', 'warning');
        return;
    }
    
    $.ajax({
        url: '../api/guardar_configuracion_sesion.pl',
        type: 'POST',
        data: { timeout: t },
        success: function(res) {
            if (res.status === 'success') {
                Swal.fire({
                    title: '¡Guardado!',
                    text: res.message + ' Los cambios aplicarán inmediatamente para todos.',
                    icon: 'success',
                    timer: 2500,
                    showConfirmButton: false
                });
                if (window.OS_SESSION_TIMEOUT) {
                    window.OS_SESSION_TIMEOUT = t; // Reflejar en la instancia actual
                    if (typeof SessionWatcher !== 'undefined') {
                        SessionWatcher.timeoutMs = window.OS_SESSION_TIMEOUT * 60 * 1000;
                        SessionWatcher.warningMs = (window.OS_SESSION_TIMEOUT - 5) * 60 * 1000;
                        SessionWatcher.resetTimers();
                    }
                }
            } else {
                Swal.fire('Error', res.message, 'error');
            }
        },
        error: function() {
            Swal.fire('Error', 'Falla de comunicación con el servidor', 'error');
        }
    });
}
</script>

</main>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script src="../js/session_watcher.js"></script>
</body>
</html>
HTML
