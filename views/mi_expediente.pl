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

my $session_data = check_session();
my $q          = $session_data->{q};
my $session_ok = $session_data->{session_ok};
my $usuario    = $session_data->{usuario};
my $role       = $session_data->{role};

if (!$session_ok || $role ne 'Paciente') {
    render_error_sesion();
    exit;
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');

render_header(
    usuario     => $usuario,
    titulo      => 'OsPulso - Mi Historial Clínico',
    ruta_logout => '../auth/cerrar_sesion.pl',
    role        => $role,
    skip_header => 1
);

print <<'HTML';
<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h2><i class="bi bi-journal-medical me-2 text-primary"></i> Mi Historial Clínico</h2>
    </div>

    <div class="row">
        <div class="col-md-4">
            <div class="card shadow-sm mb-4">
                <div class="card-header bg-primary text-white">
                    <h5 class="mb-0"><i class="bi bi-prescription2"></i> Mis Recetas</h5>
                </div>
                <div class="card-body p-0">
                    <ul class="list-group list-group-flush" id="lista_recetas">
                        <li class="list-group-item text-center text-muted py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando...</li>
                    </ul>
                </div>
            </div>
        </div>
        
        <div class="col-md-4">
            <div class="card shadow-sm mb-4">
                <div class="card-header bg-info text-white">
                    <h5 class="mb-0"><i class="bi bi-file-earmark-medical"></i> Mis Estudios e Imágenes</h5>
                </div>
                <div class="card-body p-0">
                    <ul class="list-group list-group-flush" id="lista_estudios">
                        <li class="list-group-item text-center text-muted py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando...</li>
                    </ul>
                </div>
                <div class="card-footer bg-light">
                    <button class="btn btn-sm btn-outline-info w-100" onclick="alert('Subida de archivos en desarrollo')">
                        <i class="bi bi-upload"></i> Subir Resultado
                    </button>
                </div>
            </div>
        </div>

        <div class="col-md-4">
            <div class="card shadow-sm mb-4">
                <div class="card-header bg-success text-white">
                    <h5 class="mb-0"><i class="bi bi-clipboard2-pulse"></i> Resumen de Consultas</h5>
                </div>
                <div class="card-body p-0">
                    <ul class="list-group list-group-flush" id="lista_consultas">
                        <li class="list-group-item text-center text-muted py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando...</li>
                    </ul>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    $.ajax({
        url: '../api/get_mi_expediente.pl',
        type: 'GET',
        dataType: 'json',
        success: function(res) {
            if(res.ok) {
                // Recetas
                let recHtml = '';
                if(res.recetas.length > 0) {
                    res.recetas.forEach(r => {
                        recHtml += `<li class="list-group-item d-flex justify-content-between align-items-center">
                            <div>
                                <h6 class="mb-0">${r.diagnostico}</h6>
                                <small class="text-muted">${r.fecha}</small>
                            </div>
                            <button class="btn btn-sm btn-light" onclick="window.open('../api/imprimir_receta_api.pl?id_receta=${r.id_receta}')" title="Descargar PDF"><i class="bi bi-download text-primary"></i></button>
                        </li>`;
                    });
                } else {
                    recHtml = '<li class="list-group-item text-center text-muted py-4">No hay recetas emitidas.</li>';
                }
                $('#lista_recetas').html(recHtml);

                // Estudios
                let estHtml = '';
                if(res.estudios.length > 0) {
                    res.estudios.forEach(e => {
                        estHtml += `<li class="list-group-item d-flex justify-content-between align-items-center">
                            <div>
                                <h6 class="mb-0">${e.descripcion}</h6>
                                <small class="text-muted">${e.fecha} | ${e.modalidad}</small>
                            </div>
                            <a href="../${e.ruta}" target="_blank" class="btn btn-sm btn-light"><i class="bi bi-eye text-info"></i></a>
                        </li>`;
                    });
                } else {
                    estHtml = '<li class="list-group-item text-center text-muted py-4">No hay estudios asociados.</li>';
                }
                $('#lista_estudios').html(estHtml);

                // Consultas
                let consHtml = '';
                if(res.consultas.length > 0) {
                    res.consultas.forEach(c => {
                        let f = new Date(c.fecha_ts * 1000).toLocaleString('es-MX', {year:'numeric', month:'short', day:'numeric'});
                        consHtml += `<li class="list-group-item d-flex justify-content-between align-items-center">
                            <div>
                                <h6 class="mb-0">Consulta Terminada</h6>
                                <small class="text-muted">${f}</small>
                            </div>
                            <i class="bi bi-check-circle-fill text-success"></i>
                        </li>`;
                    });
                } else {
                    consHtml = '<li class="list-group-item text-center text-muted py-4">Aún no hay consultas finalizadas.</li>';
                }
                $('#lista_consultas').html(consHtml);

            } else {
                Swal.fire('Error', res.msg, 'error');
            }
        },
        error: function() {
            Swal.fire('Error', 'No se pudo cargar el expediente', 'error');
        }
    });
});
</script>
HTML

render_bottom_nav('mi_historial');

1;
