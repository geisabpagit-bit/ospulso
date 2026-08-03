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

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    pagina_actual => 'mi_historial'
);

my $uid = lc($session_data->{uid} // '');
my $id_paciente = '';
my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
if (-e $pac_file) {
    open(my $fh, '<:encoding(UTF-8)', $pac_file) or die $!;
    while (my $line = <$fh>) {
        $line =~ s/\r?\n$//;
        next if $line =~ /^ID_PACIENTE/;
        my @f = split(/\|/, $line);
        my $c = lc($f[5] // '');
        $c =~ s/^\s+|\s+$//g;
        if ($c eq $uid) {
            $id_paciente = $f[0];
            $id_paciente =~ s/\r//g; # Clean any stray CR
            last;
        }
    }
    close($fh);
}

print <<HTML;
<div class="container container-mobile-flush mt-3 pb-5">
    <div class="d-flex justify-content-between align-items-center mb-4 px-2">
        <h2 class="mobile-condensed-title fw-bold"><i class="bi bi-journal-medical me-2 text-primary"></i> Mi Historial Clínico</h2>
    </div>

    <div class="row card-mobile-flush">
        <div class="col-md-4">
            <div class="card shadow-sm mb-4 mobile-edge-to-edge">
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
            <div class="card shadow-sm mb-4 mobile-edge-to-edge">
                <div class="card-header bg-info text-white">
                    <h5 class="mb-0"><i class="bi bi-file-earmark-medical"></i> Mis Estudios e Imágenes</h5>
                </div>
                <div class="card-body p-0">
                    <ul class="list-group list-group-flush" id="lista_estudios">
                        <li class="list-group-item text-center text-muted py-4"><div class="spinner-border spinner-border-sm text-primary"></div> Cargando...</li>
                    </ul>
                </div>
                <div class="card-footer bg-light p-3">
                    <button class="btn btn-mobile-standard btn-mobile-outline btn-mobile-full" onclick="alert('Subida de archivos en desarrollo')">
                        <i class="bi bi-upload fs-5"></i> Subir Resultado
                    </button>
                </div>
            </div>
        </div>

        <div class="col-md-4">
            <div class="card shadow-sm mb-4 mobile-edge-to-edge">
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
    
    <div class="row mt-3 card-mobile-flush">
        <div class="col-12">
            <div class="card shadow-sm border-0 mobile-edge-to-edge" style="border-radius: 1.5rem;">
                <div class="card-header bg-white border-0 pt-4 pb-0">
                    <h5 class="fw-black m-0 mobile-condensed-title" style="color: var(--md-blue-deep);"><i class="bi bi-teeth me-2 text-primary"></i>Odontograma Actual</h5>
                </div>
                <div class="card-body p-4">
                    <div id="odontograma-svg-container" class="w-100 overflow-auto" style="min-height: 350px; background: #f8fbff; border-radius: 1rem; border: 1px dashed #cbd5e1;">
                        <!-- Se renderizará por JS -->
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/odontograma_spa.js?v=$^T"></script>
<script>
$(document).ready(function() {
    // Iniciar odontograma
    if (typeof initOdontograma === 'function' && '$id_paciente' !== '') {
        setTimeout(() => {
            initOdontograma('odontograma-svg-container', '$id_paciente');
        }, 100);
    }

    $.ajax({
        url: '../api/get_mi_expediente.pl',
        type: 'GET',
        dataType: 'json',
        success: function(res) {
            if(res.ok) {
                // Recetas
                var recHtml = '';
                if(res.recetas && res.recetas.length > 0) {
                    $.each(res.recetas, function(i, r) {
                        recHtml += '<li class="list-group-item d-flex justify-content-between align-items-center">';
                        recHtml += '    <div>';
                        recHtml += '        <h6 class="mb-0">' + r.diagnostico + '</h6>';
                        recHtml += '        <small class="text-muted">' + r.fecha + '</small>';
                        recHtml += '    </div>';
                        recHtml += "<button class='btn btn-sm btn-light' onclick='window.open(\"../api/imprimir_receta_api.pl?id_receta=" + r.id_receta + "\")' title='Descargar PDF'><i class='bi bi-download text-primary'></i></button>";
                        recHtml += '</li>';
                    });
                } else {
                    recHtml = '<li class="list-group-item text-center text-muted py-4">No hay recetas emitidas.</li>';
                }
                $('#lista_recetas').html(recHtml);

                // Estudios
                var estHtml = '';
                if(res.estudios && res.estudios.length > 0) {
                    $.each(res.estudios, function(i, e) {
                        estHtml += '<li class="list-group-item d-flex justify-content-between align-items-center">';
                        estHtml += '    <div>';
                        estHtml += '        <h6 class="mb-0">' + e.descripcion + '</h6>';
                        estHtml += '        <small class="text-muted">' + e.fecha + ' | ' + e.modalidad + '</small>';
                        estHtml += '    </div>';
                        estHtml += '    <a href="../' + e.ruta + '" target="_blank" class="btn btn-sm btn-light"><i class="bi bi-eye text-info"></i></a>';
                        estHtml += '</li>';
                    });
                } else {
                    estHtml = '<li class="list-group-item text-center text-muted py-4">No hay estudios asociados.</li>';
                }
                $('#lista_estudios').html(estHtml);

                // Consultas
                var consHtml = '';
                if(res.consultas && res.consultas.length > 0) {
                    $.each(res.consultas, function(i, c) {
                        var f = new Date(c.fecha_ts * 1000).toLocaleString('es-MX', {year:'numeric', month:'short', day:'numeric'});
                        consHtml += '<li class="list-group-item d-flex justify-content-between align-items-center">';
                        consHtml += '    <div>';
                        consHtml += '        <h6 class="mb-0">Consulta Terminada</h6>';
                        consHtml += '        <small class="text-muted">' + f + '</small>';
                        consHtml += '    </div>';
                        consHtml += '    <i class="bi bi-check-circle-fill text-success"></i>';
                        consHtml += '</li>';
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

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('mi_historial');

1;
