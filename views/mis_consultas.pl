#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use FindBin;
use File::Spec;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'render_error_sesion.pl');

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');

my $session_data = check_session();
my $q          = $session_data->{q};
my $session_ok = $session_data->{session_ok};
my $usuario    = $session_data->{usuario};
my $role       = $session_data->{role};

if (!$session_ok || $role ne 'Paciente') {
    render_error_sesion();
    exit;
}

render_header(
    usuario     => $usuario,
    titulo      => 'OsPulso - Mis Consultas',
    ruta_logout => '../auth/cerrar_sesion.pl',
    role        => $role
);

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    pagina_actual => 'mis_consultas'
);

print <<'HTML';
<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <div>
            <h3 class="fw-black m-0 plus-jakarta" style="color: var(--md-blue-deep);"><i class="bi bi-file-earmark-medical me-2" style="color: var(--md-teal-clinical);"></i>Mis Consultas</h3>
            <p class="text-muted small fw-bold mt-1">HISTORIAL DE ATENCIÓN MÉDICA</p>
        </div>
    </div>

    <div class="card shadow-sm border-0 bg-transparent">
        <div class="card-body p-0">
            <div id="consultas_loader" class="text-center py-5">
                <div class="spinner-border text-primary" role="status"></div>
                <p class="mt-2 text-muted">Cargando tus consultas...</p>
            </div>
            
            <div id="consultas_empty" class="text-center py-5" style="display:none;">
                <div class="card-medentia-aura text-center p-5">
                    <i class="bi bi-folder2-open display-1 opacity-25 mb-3 d-block" style="color: var(--md-blue-deep);"></i>
                    <h4 class="fw-black" style="color: var(--md-blue-deep);">Sin Historial Clínico</h4>
                    <p class="mx-auto text-muted" style="max-width: 500px;">Aún no hay consultas médicas finalizadas para este paciente.</p>
                </div>
            </div>

            <div class="timeline-diamond mb-5" id="consultas_timeline_container" style="display:none;">
                <!-- Llenado vía JS -->
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    $.ajax({
        url: '../api/get_mis_consultas.pl',
        type: 'GET',
        dataType: 'json',
        success: function(res) {
            $('#consultas_loader').hide();
            if(res.ok) {
                if(res.consultas.length > 0) {
                    $('#consultas_timeline_container').fadeIn();
                    let html = '';
                    res.consultas.forEach(cons => {
                        let diag_trunc = cons.diagnostico;
                        if(diag_trunc.length > 80) diag_trunc = diag_trunc.substring(0, 80) + '...';
                        
                        let badge_cita = cons.id_cita ? "<span class='badge bg-info-subtle text-info border border-info-subtle mb-2'><i class='bi bi-link-45deg me-1'></i>Vinculado a Cita</span>" : "<span class='badge bg-secondary-subtle text-secondary border border-secondary-subtle mb-2'>Consulta Express</span>";
                        
                        let receta_html = cons.meds_count > 0 ? `<div class='mt-3 pt-3 border-top'><span class='badge bg-light text-dark border'><i class='bi bi-capsule text-primary me-1'></i> ${cons.meds_count} Fármaco(s) recetado(s)</span></div>` : "";

                        html += `
                            <div class="timeline-item">
                                <div class="timeline-dot" style="border-color: var(--md-teal-clinical)"></div>
                                <div class="timeline-card card-medentia-aura">
                                    <div class="d-flex justify-content-between align-items-start mb-2">
                                        <div>
                                            ${badge_cita}
                                            <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">${cons.motivo}</h5>
                                            <p class="text-muted small mt-2 mb-0"><strong>Dx:</strong> ${diag_trunc}</p>
                                        </div>
                                        <div class="text-end">
                                            <div class="fw-black" style="font-size: 1.1rem; color: var(--md-teal-clinical);">${cons.fecha}</div>
                                            <div class="small text-muted fw-bold">Médico: ${cons.nombre_medico}</div>
                                            <div class="d-flex gap-2 justify-content-end mt-2 flex-wrap">
                                                <a href="consulta_detalles.pl?id_consulta=${cons.id_consulta}" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-eye-fill me-1"></i>Detalles</a>
                                                <a href="../api/imprimir_receta_api.pl?id_consulta=${cons.id_consulta}" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-capsule me-1"></i>Receta</a>
                                                <a href="../api/imprimir_consentimiento_api.pl?id_consulta=${cons.id_consulta}" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-file-earmark-text me-1"></i>Consentimiento</a>
                                                <a href="../api/imprimir_recibo_caja.pl?id_consulta=${cons.id_consulta}" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-receipt me-1"></i>Recibo</a>
                                            </div>
                                        </div>
                                    </div>
                                    ${receta_html}
                                </div>
                            </div>
                        `;
                    });
                    $('#consultas_timeline_container').html(html);
                } else {
                    $('#consultas_empty').fadeIn();
                }
            } else {
                Swal.fire('Error', res.msg, 'error');
            }
        },
        error: function() {
            $('#consultas_loader').hide();
            Swal.fire('Error', 'No se pudo conectar con el servidor', 'error');
        }
    });
});
</script>
HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('mis_consultas');

1;
