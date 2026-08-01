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

            <div class="table-responsive" id="citas_table_container" style="display:none;">
                <table class="table table-hover align-middle">
                    <thead class="table-light">
                        <tr>
                            <th>Fecha y Hora</th>
                            <th>Clínica</th>
                            <th>Médico</th>
                            <th>Consulta</th>
                            <th>Estado</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="citas_tbody">
                        <!-- Llenado vía JS -->
                    </tbody>
                </table>
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
                    $('#citas_table_container').fadeIn();
                    let html = '';
                    res.citas.forEach(c => {
                        let badgeClass = 'bg-secondary';
                        if(c.status === 'Agendada') badgeClass = 'bg-primary';
                        if(c.status === 'Confirmada') badgeClass = 'bg-success';
                        if(c.status === 'Cancelada') badgeClass = 'bg-danger';
                        if(c.status === 'Concluida') badgeClass = 'bg-dark';

                        html += `<tr>
                            <td><strong>${c.fecha_hora.replace('T', ' ')}</strong></td>
                            <td><i class="bi bi-building me-1"></i> ${c.clinica_nombre}</td>
                            <td><i class="bi bi-person-badge me-1"></i> ${c.medico_nombre}</td>
                            <td>${c.tipo_consulta}</td>
                            <td><span class="badge ${badgeClass}">${c.status}</span></td>
                            <td>
                                <button class="btn btn-sm btn-outline-primary" title="Ver detalles"><i class="bi bi-eye"></i></button>
                                ${c.status !== 'Cancelada' && c.status !== 'Concluida' ? `<button class="btn btn-sm btn-outline-danger ms-1" title="Cancelar" onclick="alert('Cancelar cita en desarrollo')"><i class="bi bi-x-circle"></i></button>` : ''}
                            </td>
                        </tr>`;
                    });
                    $('#citas_tbody').html(html);
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
</script>
HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('mis_citas');

1;
