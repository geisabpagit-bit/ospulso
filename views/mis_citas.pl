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
    titulo      => 'OsPulso - Mis Citas',
    ruta_logout => '../auth/cerrar_sesion.pl',
    role        => $role
);

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    pagina_actual => 'mis_citas'
);

print <<'HTML';
<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h2><i class="bi bi-calendar-event me-2 text-primary"></i> Mis Citas</h2>
        <button class="btn btn-primary" onclick="window.location.href='agendar_cita_paciente.pl'"><i class="bi bi-plus-lg"></i> Agendar Cita</button>
    </div>

    <div class="card shadow-sm">
        <div class="card-body">
            <div id="citas_loader" class="text-center py-5">
                <div class="spinner-border text-primary" role="status"></div>
                <p class="mt-2 text-muted">Cargando tus citas...</p>
            </div>
            
            <div id="citas_empty" class="text-center py-5" style="display:none;">
                <i class="bi bi-calendar-x display-1 text-muted"></i>
                <h4 class="mt-3">No tienes citas agendadas</h4>
                <p class="text-muted">Cuando agendes citas en tus clínicas, aparecerán aquí.</p>
            </div>

            <div class="timeline-diamond" id="citas_timeline_container" style="display:none;">
                <!-- Llenado vía JS -->
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    $.ajax({
        url: '../api/get_mis_citas.pl',
        type: 'GET',
        dataType: 'json',
        success: function(res) {
            $('#citas_loader').hide();
            if(res.ok) {
                if(res.citas.length > 0) {
                    $('#citas_timeline_container').fadeIn();
                    let html = '';
                    res.citas.forEach(c => {
                        let is_en_consulta = c.status.toLowerCase().includes('en consulta');
                        let status_color = is_en_consulta ? '#00C4C4' : c.status.toLowerCase().includes('programada') || c.status.toLowerCase().includes('agendada') ? '#10b981' : c.status.toLowerCase().includes('cancelada') ? '#ef4444' : '#64748b';
                        
                        let action_buttons = '';
                        if (c.status.toLowerCase().includes('programada') || c.status.toLowerCase().includes('agendada')) {
                            action_buttons = `
                                <div class="d-flex gap-2 ms-auto">
                                    <button class="btn btn-sm btn-outline-danger px-3 rounded-pill" onclick="cancelarCita('${c.id}')"><i class="bi bi-x-circle me-1"></i> Cancelar</button>
                                    <button class="btn btn-sm btn-success px-3 rounded-pill" onclick="confirmarCita('${c.id}')"><i class="bi bi-check2-circle me-1"></i> Confirmar Asistencia</button>
                                </div>
                            `;
                        }

                        html += `
                            <div class="timeline-item">
                                <div class="timeline-dot" style="border-color: ${status_color}"></div>
                                <div class="timeline-card">
                                    <div class="d-flex justify-content-between align-items-start mb-2">
                                        <div>
                                            <span class="badge mb-2" style="background: ${status_color}; color: white;">${c.status}</span>
                                            <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">${c.tipo_consulta}</h5>
                                            <p class="small text-muted m-0 mt-1"><i class="bi bi-building me-1"></i> ${c.clinica_nombre}</p>
                                        </div>
                                        <div class="text-end">
                                            <div class="fw-black" style="font-size: 1.1rem; color: var(--md-teal-clinical);">${c.fecha_hora.split(' ')[0]}</div>
                                            <div class="small text-muted fw-bold">${c.fecha_hora.split(' ')[1] || ''}</div>
                                        </div>
                                    </div>
                                    <div class="d-flex align-items-center mt-3 pt-3 border-top">
                                        <i class="bi bi-person-circle text-muted me-2"></i>
                                        <span class="small fw-bold text-muted">Médico: ${c.medico_nombre}</span>
                                        ${action_buttons}
                                    </div>
                                </div>
                            </div>
                        `;
                    });
                    $('#citas_timeline_container').html(html);
                } else {
                    $('#citas_empty').fadeIn();
                }
            } else {
                Swal.fire('Error', res.msg, 'error');
            }
        },
        error: function() {
            $('#citas_loader').hide();
            Swal.fire('Error', 'No se pudo conectar con el servidor', 'error');
        }
    });
});

function confirmarCita(id) {
    Swal.fire({
        title: '¿Confirmar Asistencia?',
        text: "Le indicaremos a su médico que sí asistirá a esta cita.",
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#10b981',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Sí, confirmaré mi asistencia',
        cancelButtonText: 'Cerrar'
    }).then((result) => {
        if (result.isConfirmed) {
            $.post('../api/citas_crud.pl', { accion: 'confirm_paciente', id_cita: id }, function(res) {
                if(res.ok) {
                    Swal.fire('Confirmada', res.msg, 'success').then(() => location.reload());
                } else {
                    Swal.fire('Aviso', res.msg, 'warning');
                }
            }, 'json').fail(function() {
                Swal.fire('Error', 'No se pudo conectar con el servidor.', 'error');
            });
        }
    });
}

function cancelarCita(id) {
    Swal.fire({
        title: 'Cancelar Cita',
        text: 'Por favor, indíquenos brevemente el motivo de su cancelación:',
        input: 'text',
        inputPlaceholder: 'Ej. Motivos personales, enfermedad...',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#ef4444',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Cancelar definitivamente',
        cancelButtonText: 'Regresar',
        inputValidator: (value) => {
            if (!value) {
                return '¡Necesitamos saber el motivo para poder cancelar!';
            }
        }
    }).then((result) => {
        if (result.isConfirmed) {
            $.post('../api/citas_crud.pl', { accion: 'cancel_paciente', id_cita: id, motivo_cancel: result.value }, function(res) {
                if(res.ok) {
                    Swal.fire('Cancelada', res.msg, 'success').then(() => location.reload());
                } else {
                    Swal.fire('Aviso', res.msg, 'warning');
                }
            }, 'json').fail(function() {
                Swal.fire('Error', 'No se pudo conectar con el servidor.', 'error');
            });
        }
    });
}
</script>
HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('mis_citas');

1;
