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
use JSON::PP;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS ---
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

my $uid = lc($session_data->{uid} // '');
my $id_paciente = '';

# Buscar ID de paciente por correo (uid)
my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
if (-e $pac_file) {
    open(my $fh, '<:encoding(UTF-8)', $pac_file) or die "No se pudo leer pacientes.dat: $!";
    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^ID_PACIENTE/;
        my @f = split(/\|/, $line);
        my $c = lc($f[5] // '');
        $c =~ s/^\s+|\s+$//g;
        if ($c eq $uid) {
            $id_paciente = $f[0];
            last;
        }
    }
    close($fh);
}

sub cargar_historial_correos {
    my ($id) = @_; my @h; 
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'historial_correos.dat');
    open(my $fh, "<:encoding(UTF-8)", $path) or return @h;
    while(<$fh>){ 
        chomp; 
        my @c = split /\|/; 
        if($c[1] eq $id){ 
            push @h, { 
                id_correo => $c[0], 
                fecha     => $c[2], 
                asunto    => $c[3], 
                cuerpo    => $c[4] || 'Sin contenido',
                categoria => $c[4] || 'General',
                adjunto   => $c[5] || 'Sin adjuntos'
            }; 
        } 
    }
    close $fh; 
    my @sorted = sort { $b->{fecha} cmp $a->{fecha} } @h;
    return \@sorted;
}

my $correos_ref = cargar_historial_correos($id_paciente);

print $q->header(-type => 'text/html', -charset => 'UTF-8');

render_header(
    usuario     => $usuario,
    titulo      => 'Mi Inbox',
    ruta_logout => '../auth/cerrar_sesion.pl',
    role        => $role,
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    pagina_actual => 'inbox_paciente'
);

print <<HTML;
<div class="container-fluid px-4 pt-4 pb-5">
    <div class="d-flex justify-content-between align-items-center mb-5">
        <div>
            <h3 class="fw-black m-0 plus-jakarta" style="color: var(--md-blue-deep);"><i class="bi bi-inbox me-2" style="color: var(--md-teal-clinical);"></i>Mi Inbox</h3>
            <p class="text-muted small fw-bold mt-1">COMUNICACIONES Y NOTIFICACIONES</p>
        </div>
    </div>
    
    <div class="row g-3">
HTML

if (@$correos_ref) {
    foreach my $corr (@$correos_ref) {
        my $id_msg = $corr->{id_correo};
        my $cat    = $corr->{categoria} || 'General';
        my $adj    = $corr->{adjunto}   || 'Ninguno';
        my $asunto_esc = $corr->{asunto}; $asunto_esc =~ s/'/\\'/g;
        my $cuerpo_esc = $corr->{cuerpo}; $cuerpo_esc =~ s/'/\\'/g;
        $cuerpo_esc =~ s/\r?\n/\\n/g;

        print qq{
            <div class="col-12">
                <div class="card-medentia-aura p-4 border-0 d-flex gap-4 align-items-center transition-all shadow-sm" 
                     onclick="verDetalleMensaje('$id_msg', '$asunto_esc', '$corr->{fecha}', '$cuerpo_esc', '$cat', '$adj')"
                     style="cursor: pointer; background: #fff; border-radius: 1rem;">
                    <div class="p-3 rounded-4" style="background: rgba(25, 183, 165, 0.1); color: var(--md-teal-clinical);">
                        <i class="bi bi-envelope-check fs-3"></i>
                    </div>
                    <div class="flex-grow-1 overflow-hidden">
                        <div class="d-flex align-items-center justify-content-between gap-2 mb-1">
                            <h6 class="fw-bold m-0 text-truncate">$corr->{asunto}</h6>
                            <span class="badge bg-light text-muted small fw-bold">$corr->{fecha}</span>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                            <span class="badge bg-primary-subtle text-primary border-0 rounded-pill px-2 py-1" style="font-size:0.6rem;">$cat</span>
                            <p class="small text-muted mb-0 text-truncate">$corr->{cuerpo}</p>
                        </div>
                    </div>
                    <div class="text-muted opacity-25">
                        <i class="bi bi-chevron-right fs-4"></i>
                    </div>
                </div>
            </div>
        };
    }
} else {
    print qq{<div class="text-center py-5 opacity-25"><i class="bi bi-chat-left-dots display-1 d-block mb-3"></i><p class="fw-bold">No tienes comunicaciones recientes.</p></div>};
}

print <<HTML;
    </div>
</div>

<!-- Modal Detalle -->
<div class="modal fade" id="modalMensaje" tabindex="-1">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-primary-subtle text-primary p-2 rounded-3"><i class="bi bi-envelope-open-fill"></i></div>
                    <h4 class="fw-black m-0 plus-jakarta">Detalle del Mensaje</h4>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4 pt-4">
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Asunto del Mensaje</label>
                    <h5 id="msgDetailAsunto" class="fw-bold text-dark"></h5>
                </div>
                <div class="row g-3 mb-4">
                    <div class="col-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">ID Registro</label>
                        <div id="msgDetailID" class="fw-bold text-dark small"></div>
                    </div>
                    <div class="col-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Categor&iacute;a</label>
                        <span id="msgDetailCat" class="badge bg-primary-subtle text-primary border-0 rounded-pill px-3 py-1"></span>
                    </div>
                </div>
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Fecha de Env&iacute;o</label>
                    <div id="msgDetailFecha" class="small fw-bold text-primary"></div>
                </div>
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Archivo Adjunto</label>
                    <div id="msgDetailAdjunto" class="small fw-bold text-dark"><i class="bi bi-paperclip me-1"></i> <span></span></div>
                </div>
                <hr class="my-4 opacity-10">
                <div class="bg-light p-4 rounded-4 border">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-2 d-block">Contenido / Cuerpo</label>
                    <p id="msgDetailCuerpo" class="m-0 text-dark" style="white-space: pre-wrap; line-height: 1.6;"></p>
                </div>
            </div>
            <div class="modal-footer border-0 p-4 pt-0">
                <button class="btn btn-navy w-100 py-3 rounded-4 fw-bold text-white shadow-lg" style="background: var(--sdm-navy);" data-bs-dismiss="modal">CERRAR LECTURA</button>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script>
    function verDetalleMensaje(id, asunto, fecha, cuerpo, cat, adjunto) {
        const modalEl = document.getElementById('modalMensaje');
        if (modalEl && modalEl.parentElement !== document.body) {
            document.body.appendChild(modalEl);
        }

        document.getElementById('msgDetailID').innerText = id;
        document.getElementById('msgDetailAsunto').innerText = asunto;
        document.getElementById('msgDetailFecha').innerText = fecha;
        document.getElementById('msgDetailCuerpo').innerText = cuerpo;
        document.getElementById('msgDetailCat').innerText = cat;
        
        const adjContainer = document.getElementById('msgDetailAdjunto');
        const adjSpan = adjContainer.querySelector('span');
        adjSpan.innerText = adjunto;
        
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        m.show();
    }
</script>
HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('inbox_paciente');

1;
