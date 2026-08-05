#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'render_error_sesion.pl');
use utils::db_manager qw(leer_tabla);

my $session_data = check_session();
my $q = $session_data->{q};

if (!$session_data->{session_ok} || $session_data->{role} ne 'Paciente') {
    render_error_sesion();
    exit;
}

my $correo_pac = lc($session_data->{uid});
$correo_pac =~ s/^\s+|\s+$//g;

# Obtener los médicos/clínicas a los que pertenece el paciente
my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $regs = leer_tabla($archivo_pacientes, '\|');

my %mis_medicos = ();
if ($regs) {
    foreach my $p (@$regs) {
        next if @$p < 6;
        my $c = lc($p->[5] // '');
        $c =~ s/^\s+|\s+$//g;
        if ($c eq $correo_pac) {
            my $id_medico = $p->[1] // '';
            my $tenant = $p->[13] // '';
            my $nombre_paciente = $p->[2] // '';
            my $id_paciente = $p->[0] // '';
            $mis_medicos{$id_medico} = { tenant => $tenant, nombre_paciente => $nombre_paciente, id_paciente => $id_paciente };
        }
    }
}

# Obtener nombres de los médicos
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $usuarios = leer_tabla($archivo_usuarios, '!');
my @opciones_medicos = ();

if ($usuarios) {
    foreach my $u (@$usuarios) {
        if (exists $mis_medicos{$u->[0]}) {
            push @opciones_medicos, {
                id => $u->[0],
                nombre => $u->[1],
                id_paciente => $mis_medicos{$u->[0]}->{id_paciente}
            };
        }
    }
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario => $session_data->{usuario},
    titulo => 'Agendar Cita - OSPulso',
    ruta_logout => '../auth/cerrar_sesion.pl',
    role => $session_data->{role},
    skip_header => 1
);

print <<HTML;
<div class="sdm-layout-wrapper">
    <!-- Sidebar -->
HTML
utils::sub_sidebar::render_sidebar(
    usuario => $session_data->{usuario},
    role => $session_data->{role},
    pagina_actual => 'mis_citas'
);

print <<HTML;
    <main class="sdm-main-content">
        <!-- Header -->
        <header class="sdm-top-header d-flex justify-content-between align-items-center mb-4">
            <h4 class="mb-0 fw-bold"><i class="bi bi-calendar-plus text-primary me-2"></i> Agendar Cita</h4>
        </header>
        <div class="container container-mobile-flush mt-3 pb-5">
            <div class="row justify-content-center card-mobile-flush">
                <div class="col-12 col-md-10 col-lg-10 col-xl-8">
                    <div class="card shadow-sm border-0 rounded-4 p-4 p-lg-5 mobile-edge-to-edge">
                        <form id="formNuevaCita">
                            <div class="mb-4">
                                <label class="form-label fw-bold text-secondary" style="letter-spacing: 0.5px; font-size: 0.85rem;"><i class="bi bi-person-badge me-2"></i>ESPECIALISTA / CLÍNICA</label>
                                <select class="form-select form-select-lg shadow-sm" id="f_medico" style="border-radius: 0.75rem; font-size: 1rem;" required>
                                    <option value="">Seleccione su médico...</option>
HTML

foreach my $m (@opciones_medicos) {
    print qq{<option value="$m->{id}" data-idpac="$m->{id_paciente}">$m->{nombre}</option>\n};
}

if (@opciones_medicos == 0) {
    print qq{<option value="" disabled>No está registrado con ningún médico aún.</option>};
}

print                                </select>
                            </div>

                            <!-- NAVEGACIÓN Y MES ACTUAL -->
                            <div id="smart-nav-container" class="d-none mt-4 text-center">
                                <div class="d-flex align-items-center justify-content-center mb-3">
                                    <button type="button" onclick="moveDate(-7)" class="btn btn-link text-primary p-2"><i class="bi bi-chevron-left fs-4"></i></button>
                                    <h5 class="fw-bold mb-0 mx-3 text-uppercase text-secondary" id="current-month-label" style="min-width: 150px;">
                                        CARGANDO...
                                    </h5>
                                    <button type="button" onclick="moveDate(7)" class="btn btn-link text-primary p-2"><i class="bi bi-chevron-right fs-4"></i></button>
                                </div>
                            </div>
                            
                            <!-- VISTA SEMANAL SMART -->
                            <div id="view-semana-smart" class="agenda-view-container d-none mt-3">
                                <div id="weekly-smart-scroll" class="d-flex justify-content-center gap-2 py-3 mb-4 overflow-auto no-scrollbar">
                                    <!-- Días generados por JS -->
                                </div>
                                <div id="weekly-smart-slots" class="row g-4">
                                    <!-- Slots generados por JS -->
                                </div>
                            </div>
                            
                            <!-- Loader -->
                            <div id="citas_loader" class="text-center py-5 d-none">
                                <div class="spinner-border text-primary" role="status"></div>
                                <p class="mt-2 text-muted">Sincronizando disponibilidad...</p>
                            </div>
                            
                            <div class="text-center mt-5">
                                <a href="mis_citas.pl" class="btn btn-outline-secondary btn-lg rounded-pill px-4"><i class="bi bi-arrow-left-circle me-2"></i> Volver a Mis Citas</a>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </main>
</div>
HTML
render_bottom_nav('mis_citas');

print <<HTML;
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/agenda_paciente_spa.js?v=@{[time()]}"></script>
<style>
/* Estilos extraídos para el Smart View (idénticos a agenda_main.pl) */
.no-scrollbar::-webkit-scrollbar { display: none; }
.no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }

.smart-day-card {
    background: white; border: 2px solid #f1f5f9; border-radius: 1rem;
    padding: 10px 15px; text-align: center; cursor: pointer;
    min-width: 80px; transition: all 0.2s ease;
}
.smart-day-card:hover:not(.active) { border-color: #cbd5e1; transform: translateY(-2px); }
.smart-day-card.active {
    background: linear-gradient(135deg, #3b82f6 0%, #6366f1 100%);
    color: white; border: none; box-shadow: 0 4px 15px rgba(59, 130, 246, 0.4);
}
.smart-day-card.active .day-name, .smart-day-card.active .day-num { color: white !important; }
.smart-day-card .day-name { font-size: 0.7rem; font-weight: 800; color: #94a3b8; text-transform: uppercase; }
.smart-day-card .day-num { font-size: 1.5rem; font-weight: 900; color: #0f172a; line-height: 1; margin-top: 5px; }
.smart-day-card.holiday { opacity: 0.5; cursor: not-allowed; }
.smart-day-card.holiday:hover { transform: none; border-color: #f1f5f9; }

.slot-btn {
    background: white; border: 1px solid #e2e8f0; border-radius: 0.75rem;
    color: #334155; font-weight: 700; padding: 12px; width: 100%;
    transition: all 0.2s; font-size: 0.95rem; box-shadow: 0 1px 2px rgba(0,0,0,0.02);
}
.slot-btn:hover:not(:disabled) { border-color: #3b82f6; color: #3b82f6; transform: translateY(-1px); box-shadow: 0 4px 6px rgba(59, 130, 246, 0.1); }
.slot-btn.disabled, .slot-btn:disabled {
    background: #f8fafc; border-color: #f1f5f9; color: #cbd5e1;
    text-decoration: line-through; opacity: 0.8; cursor: not-allowed;
}
.slot-btn.disabled:hover, .slot-btn:disabled:hover { transform: none; box-shadow: none; border-color: #f1f5f9; }
</style>
<script>
document.addEventListener('DOMContentLoaded', function() {
    // Inicialización al seleccionar médico
    const medicoSelect = document.getElementById('f_medico');
    medicoSelect.addEventListener('change', function() {
        if(this.value) {
            initPacienteSpa(this.value, this.options[this.selectedIndex].getAttribute('data-idpac'));
        } else {
            document.getElementById('view-semana-smart').classList.add('d-none');
            document.getElementById('smart-nav-container').classList.add('d-none');
        }
    });

    // Si solo hay una opción habilitada, autoseleccionarla
    if(medicoSelect.options.length === 2 && medicoSelect.options[1].value) {
        medicoSelect.selectedIndex = 1;
        medicoSelect.dispatchEvent(new Event('change'));
    }
});
</script>
HTML
render_footer();
1;
