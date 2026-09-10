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

my $uid = $session_data->{uid};
$uid =~ s/^\s+|\s+$//g;

# Obtener los médicos/clínicas a los que pertenece el paciente
my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $regs = leer_tabla($archivo_pacientes, '\|');

my $id_medico_asignado = '';
my $id_paciente_real = '';

if ($regs) {
    foreach my $p (@$regs) {
        my $id_pac_db = $p->[0] // '';
        if ($id_pac_db eq $uid) {
            $id_medico_asignado = $p->[1] // '';
            $id_paciente_real = $id_pac_db;
            last;
        }
    }
}

# Obtener nombres de los médicos
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $usuarios = leer_tabla($archivo_usuarios, '!');
my @nombres_medicos = ();
my @nombres_fallback = ();
my $id_medico_real = '';
my $id_medico_fallback = '';

if ($usuarios && $id_medico_asignado) {
    my @ids = split(/,/, $id_medico_asignado);
    foreach my $id_m (@ids) {
        $id_m =~ s/^\s+|\s+$//g;
        next unless $id_m;
        foreach my $u (@$usuarios) {
            if ($u->[0] eq $id_m) {
                my $rol_u = $u->[5] // '';
                if ($rol_u =~ /Medico|Especialista/i) {
                    push @nombres_medicos, $u->[1];
                    $id_medico_real = $id_m if $id_medico_real eq ''; # Tomar el primer médico real
                } else {
                    push @nombres_fallback, $u->[1];
                    $id_medico_fallback = $id_m if $id_medico_fallback eq '';
                }
                last;
            }
        }
    }
}

my $nombre_medico_asignado = 'Sin Médico Asignado';
my $f_medico_val = '';

if (@nombres_medicos) {
    $nombre_medico_asignado = join(' / ', @nombres_medicos);
    $f_medico_val = $id_medico_real;
} elsif (@nombres_fallback) {
    $nombre_medico_asignado = join(' / ', @nombres_fallback);
    $f_medico_val = $id_medico_fallback;
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario => $session_data->{usuario},
    titulo => 'Agendar Cita - OSPulso',
    ruta_logout => '../auth/cerrar_sesion.pl',
    role => $session_data->{role},
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(
    usuario => $session_data->{usuario},
    role => $session_data->{role},
    pagina_actual => 'mis_citas'
);

print <<HTML;
        <!-- Header -->
        <header class="sdm-top-header d-flex justify-content-between align-items-center mb-4">
            <h4 class="mb-0 fw-bold"><i class="bi bi-calendar-plus text-primary me-2"></i> Agendar Cita</h4>
        </header>
        <div class="container-fluid container-mobile-flush mt-3 pb-5 px-xl-5">
            <div class="row justify-content-center card-mobile-flush">
                <div class="col-12 col-xxl-11">
                    <div class="card shadow-sm rounded-4 p-3 p-lg-4 mobile-edge-to-edge" style="border: 1px solid var(--md-teal-clinical, #19B7A5);">
                        <form id="formNuevaCita">
                            <div class="mb-4 text-center">
                                <label class="form-label fw-bold" style="color: var(--md-teal-clinical, #19B7A5); letter-spacing: 1px; font-size: 0.9rem;"><i class="bi bi-person-badge me-2"></i>ESPECIALISTA / CLÍNICA</label>
                                <div class="mx-auto" style="max-width: 600px;">
                                    <input type="text" class="form-control form-control-lg shadow-sm text-center fw-bold bg-light" value="$nombre_medico_asignado" readonly style="border-radius: 0.75rem; font-size: 1rem; border-color: rgba(25, 183, 165, 0.4); color: #334155;">
                                    <input type="hidden" id="f_medico" value="$f_medico_val" data-idpac="$id_paciente_real">
                                </div>
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
                            
                            <div class="text-center mt-5 mb-2">
                                <a href="mis_citas.pl" class="btn btn-mobile-standard btn-mobile-outline btn-mobile-full fw-bold" style="color: var(--md-teal-clinical, #19B7A5); border-color: var(--md-teal-clinical, #19B7A5); max-width: 300px;"><i class="bi bi-arrow-left-circle me-2"></i> Volver a Mis Citas</a>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('mis_citas');

print <<HTML;
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/agenda_paciente_spa.js?v=@{[time()]}"></script>
<link rel="stylesheet" href="../css/agenda_paciente.css?v=@{[time()]}">
HTML
render_footer();
1;
