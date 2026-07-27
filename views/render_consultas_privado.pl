#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON qw(encode_json decode_json);
use FindBin;
use lib "$FindBin::Bin/..";
use File::Spec;

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
use utils::db_manager qw(leer_tabla);

# Cargar Componentes (Partials)
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_registro_privado.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_anamnesis.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_exploracion.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_estudios.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_soap.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_comunicacion.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_caja_privado.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_cierre_privado.pl');

my $q = CGI->new;
my $session_data = check_session($q);
unless ($session_data->{session_ok}) { print $q->header(-status => '302 Found', -location => '../index.html'); exit; }

binmode STDOUT, ":utf8";

my $usuario     = $session_data->{usuario};
my $role        = $session_data->{role};
my $id_medico   = $session_data->{id_medico} || 'DOC-001';
my $id_paciente = $q->param('id') || $q->param('id_paciente') || '';
my $id_cita     = $q->param('id_cita') || '';
my $paciente    = cargar_datos_paciente($id_paciente);

my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
my $hoy_fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
my $hoy_hora  = sprintf("%02d:%02d", $hour, $min);

$paciente->{fecha_consulta} = $hoy_fecha;
$paciente->{hora_consulta}  = $hoy_hora;
$paciente->{motivo_precargado} = '';

# Cargar Especialidad y Sub-Especialidad Inmutable del Médico
my $id_espe_medico       = '0';
my $id_subespe_medico    = '0';
my $espe_nombre_medico   = 'Medicina General';
my $subespe_nombre_medico = 'General / Ninguna';

my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs_usr = leer_tabla($usr_file, '!');
if ($regs_usr) {
    foreach my $r (@$regs_usr) {
        if ($r->[0] eq $id_medico || (lc($r->[2] // '') eq lc($usuario))) {
            $id_espe_medico    = $r->[7] // '0';
            $id_subespe_medico = $r->[8] // '0';
            last;
        }
    }
}

my $esp_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'especialidades.dat');
my $sub_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'sub_especialidades.dat');

my $regs_esp = leer_tabla($esp_file, '\|');
if ($regs_esp) {
    foreach my $r (@$regs_esp) {
        next if $r->[0] =~ /^ID_ESPE$/i;
        if ($r->[0] eq $id_espe_medico) { $espe_nombre_medico = $r->[1]; last; }
    }
}

my $regs_sub = leer_tabla($sub_file, '\|');
if ($regs_sub) {
    foreach my $r (@$regs_sub) {
        next if $r->[0] =~ /^ID_ESPE$/i;
        if ($r->[1] eq $id_subespe_medico) { $subespe_nombre_medico = $r->[2]; last; }
    }
}

$paciente->{id_espe_medico}       = $id_espe_medico;
$paciente->{id_subespe_medico}    = $id_subespe_medico;
$paciente->{espe_nombre_medico}    = $espe_nombre_medico;
$paciente->{subespe_nombre_medico} = $subespe_nombre_medico;

# 1. Bloqueo de Seguridad: Verificar si el médico ya tiene una consulta activa en curso
my $citas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
my $cita_activa_medico = undef;

if (-e $citas_file && open my $fh_chk, '<:encoding(UTF-8)', $citas_file) {
    my $header = <$fh_chk>;
    while (my $l = <$fh_chk>) {
        chomp $l;
        next if $l =~ /^\s*$/;
        my @c = split /\|/, $l, -1;
        my $c_id    = $c[0] // '';
        my $c_med   = $c[1] // '';
        my $c_pac   = $c[2] // '';
        my $c_est   = $c[8] // '';
        
        $c_id  =~ s/^\s+|\s+$//g;
        $c_med =~ s/^\s+|\s+$//g;
        
        if ($c_med eq $id_medico && $c_est eq 'En consulta') {
            if (!$id_cita || $c_id ne $id_cita) {
                $cita_activa_medico = {
                    id_cita     => $c_id,
                    id_paciente => $c_pac,
                    fecha       => $c[3],
                    hora        => $c[4],
                    motivo      => $c[6]
                };
                last;
            }
        }
    }
    close $fh_chk;
}

if ($cita_activa_medico) {
    my $pac_act = cargar_datos_paciente($cita_activa_medico->{id_paciente});
    my $nombre_pac_act = $pac_act->{nombre} || $cita_activa_medico->{id_paciente};
    
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    render_header(
        usuario     => $usuario, 
        role        => $role, 
        titulo      => 'Consulta en Curso Detectada', 
        skip_header => 1
    );
    print <<HTML;
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<div class="container py-5 text-center">
    <script>
    document.addEventListener('DOMContentLoaded', () => {
        Swal.fire({
            icon: 'warning',
            title: 'Consulta Activa en Curso',
            html: 'Tiene una consulta activa en proceso con el paciente <strong>$nombre_pac_act</strong> (Cita ID: <code>$cita_activa_medico->{id_cita}</code>).<br><br>Como regla clínica, un médico debe concluir y cerrar su consulta activa antes de iniciar una nueva.',
            confirmButtonText: '<i class="bi bi-arrow-right-circle me-1"></i> Ir a la Consulta Activa',
            showCancelButton: true,
            cancelButtonText: 'Volver a Agenda',
            allowOutsideClick: false,
            customClass: { popup: 'rounded-4 shadow-lg' }
        }).then((result) => {
            if (result.isConfirmed) {
                window.location.href = 'render_consultas_privado.pl?id=$cita_activa_medico->{id_paciente}&id_cita=$cita_activa_medico->{id_cita}';
            } else {
                window.location.href = 'agenda_main.pl';
            }
        });
    });
    </script>
</div>
HTML
    render_footer();
    exit;
}

# 2. Procesar Cita Actual y actualizar a hora real
if ($id_cita) {
    if (-e $citas_file && open my $fh_in, '<:encoding(UTF-8)', $citas_file) {
        my @lineas = <$fh_in>;
        close $fh_in;
        my $cabecera = shift @lineas;
        chomp $cabecera if defined $cabecera;
        my @nuevas_lineas;
        my $modificado = 0;
        
        foreach my $l (@lineas) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            my $c0_clean = $c[0] // '';
            $c0_clean =~ s/^\s+|\s+$//g;
            if ($c0_clean eq $id_cita) {
                $c[4] = $hoy_hora; # Actualizar la hora de inicio con la hora real
                $paciente->{fecha_consulta} = $c[3] || $hoy_fecha;
                $paciente->{hora_consulta}  = $hoy_hora;
                $paciente->{motivo_precargado} = $c[6] // '';
                
                if (($c[8] // '') !~ /Atendida|Cancelada/i) {
                    $c[8] = 'En consulta';
                }
                $l = join('|', @c);
                $modificado = 1;
            }
            push @nuevas_lineas, $l;
        }
        if ($modificado) {
            utils::db_manager::actualizar_archivo($citas_file, $cabecera, \@nuevas_lineas);
        }
    }
}

# Recuperación de Autosave (Draft)
my $draft_json = '{}';
my $draft_step = 0;
my $draft_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consulta_draft.dat');
if (-e $draft_file) {
    if (open my $fh, '<:encoding(UTF-8)', $draft_file) {
        my $head = <$fh>;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] eq "DRAFT-$id_paciente") {
                $draft_step = $c[4] || 0;
                $draft_json = $c[5] || '{}';
                $draft_json =~ s/\\\\n/\\n/g; # Restaurar saltos de línea
                last;
            }
        }
        close $fh;
    }
}

# Cargar Médicos y Sucursales para el modal de citas
my $id_negocio = $session_data->{id_empresa} || '';
my $id_sucursal = $session_data->{id_sucursal} || '';
my $id_negocio_activo = ($id_sucursal && $id_sucursal ne '0') ? $id_sucursal : $id_negocio;

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');

my $usuarios = leer_tabla($archivo_usuarios, '!');
my @medicos;
if ($usuarios) {
    foreach my $u (@$usuarios) {
        if ($u->[5] eq 'Medico' && $u->[6] =~ /^$id_negocio:/) {
            push @medicos, { id => $u->[0], nombre => $u->[1] };
        }
    }
}
my $html_medicos = '';
foreach my $m (@medicos) {
    my $sel = ($m->{id} eq $id_medico) ? 'selected' : '';
    $html_medicos .= qq(<option value="$m->{id}" $sel>$m->{nombre}</option>\n);
}

my $negocios = leer_tabla($archivo_negocios, '\|');
my $nombre_sucursal = 'Clínica Principal';
if ($negocios) {
    foreach my $n (@$negocios) {
        if ($n->[0] eq $id_negocio_activo) {
            $nombre_sucursal = $n->[1];
            last;
        }
    }
}
my $html_sucursal = qq(<option value="$nombre_sucursal" selected>$nombre_sucursal</option>);

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => 'OsPulso -  Consulta Privada', 
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(
    role          => $role, 
    usuario       => $usuario, 
    id_medico     => $id_medico, 
    pagina_actual => 'consultas'
);

print <<HTML;
<link rel="stylesheet" href="../css/consulta_flow.css">
<!-- DataTables CSS/JS para Estudios PACS -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>

<div class="wizard-container animate__animated animate__fadeIn p-2 p-md-4">
    <!-- ENCABEZADO CLÍNICO DE ALTO IMPACTO (ESTÁNDAR GLOBAL CORPORATIVO) -->
    <header class="bg-medentia-gradient text-white p-3 p-md-4 shadow-sm mb-4" style="border-radius: 1.25rem;">
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
            <div class="d-flex align-items-center gap-3">
                <div class="bg-white bg-opacity-10 p-2 p-md-3 rounded-circle d-flex align-items-center justify-content-center flex-shrink-0" style="width: 48px; height: 48px;">
                    <i class="bi bi-heart-pulse-fill fs-3 text-white"></i>
                </div>
                <div>
                    <h3 class="fw-black mb-0 text-white fs-4 fs-md-2" style="letter-spacing: -0.5px;">Consulta M&eacute;dica (Privada)</h3>
                    <p class="text-white-50 small mb-0 mt-1">
                        <span class="me-3"><i class="bi bi-person-fill me-1"></i><strong>Paciente:</strong> $paciente->{nombre}</span>
                        <span><i class="bi bi-hash me-1"></i><strong>Folio:</strong> $id_paciente</span>
                    </p>
                </div>
            </div>
            <div>
                <a href="render_expediente_clinico.pl?id=$id_paciente" class="btn text-white fw-bold rounded-pill px-3 py-2 shadow-sm d-flex align-items-center gap-2 small transition-all" style="background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); backdrop-filter: blur(10px);">
                    <i class="bi bi-x-circle-fill text-white"></i><span>Cancelar y Salir</span>
                </a>
            </div>
        </div>
    </header>

    <!-- Stepper y Progress Bar (8 pasos) -->
    <div class="wizard-stepper">
        <div class="wizard-step active" onclick="WizardController.jumpToStep(0)">
            <div class="wizard-step-icon"><i class="bi bi-person-lines-fill"></i></div>
            <div class="wizard-step-label">Registro</div>
        </div>
        <div class="wizard-step" onclick="WizardController.jumpToStep(1)">
            <div class="wizard-step-icon"><i class="bi bi-clock-history"></i></div>
            <div class="wizard-step-label">Historial M&eacute;dico</div>
        </div>
        <div class="wizard-step" onclick="WizardController.jumpToStep(2)">
            <div class="wizard-step-icon"><i class="bi bi-activity"></i></div>
            <div class="wizard-step-label">Exploraci&oacute;n</div>
        </div>
        <div class="wizard-step" onclick="WizardController.jumpToStep(3)">
            <div class="wizard-step-icon"><i class="bi bi-file-medical"></i></div>
            <div class="wizard-step-label">Estudios</div>
        </div>
        <div class="wizard-step" onclick="WizardController.jumpToStep(4)">
            <div class="wizard-step-icon"><i class="bi bi-diagram-3"></i></div>
            <div class="wizard-step-label">S.O.A.P.</div>
        </div>
        <div class="wizard-step" onclick="WizardController.jumpToStep(5)">
            <div class="wizard-step-icon"><i class="bi bi-chat-heart"></i></div>
            <div class="wizard-step-label">Acuerdos</div>
        </div>
        <div class="wizard-step" onclick="WizardController.jumpToStep(6)">
            <div class="wizard-step-icon"><i class="bi bi-wallet2"></i></div>
            <div class="wizard-step-label">Caja</div>
        </div>
        <div class="wizard-step" onclick="WizardController.jumpToStep(7)">
            <div class="wizard-step-icon"><i class="bi bi-check-circle"></i></div>
            <div class="wizard-step-label">Cierre</div>
        </div>
    </div>
    
    <div class="wizard-progress-bar">
        <div class="wizard-progress-fill" id="wizard-progress-fill"></div>
    </div>

    <!-- Contenedor Principal (Form) -->
    <form id="wizard-form">
        <!-- Campos ocultos necesarios -->
        <input type="hidden" name="id_cita" value="$id_cita">
        <input type="hidden" name="id_paciente" value="$id_paciente">
        <input type="hidden" name="id_medico" value="$id_medico">
        
        @{[ render_step_registro_privado($paciente) ]}
        @{[ render_step_anamnesis() ]}
        @{[ render_step_exploracion($paciente) ]}
        @{[ render_step_estudios($paciente) ]}
        @{[ render_step_soap() ]}
        @{[ render_step_comunicacion() ]}
        @{[ render_step_caja_privado($paciente) ]}
        @{[ render_step_cierre_privado() ]}
    </form>
</div>

<!-- MODAL GESTIÓN DE CITAS -->
<div class="modal fade modal-diamond" id="modalCita" tabindex="-1" aria-hidden="true" style="z-index: 105000 !important;">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title d-flex align-items-center">
                    <i class="bi bi-calendar-check me-2" style="color: #00C4C4 !important;"></i> 
                    <span id="modalCitaTitle">GESTIÓN DE CITA</span>
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            
            <div class="modal-body p-3 p-md-4">
                <form id="formCita">
                    <input type="hidden" name="id_cita" id="f_id_cita" value="">
                    <input type="hidden" name="id_paciente" id="f_id_paciente" value="$id_paciente">
                    <input type="hidden" name="accion" id="f_accion" value="create">
                    <input type="hidden" name="hora_ini" id="f_hi">
                    <input type="hidden" name="hora_fin" id="f_hf">

                    <div class="row g-3">
                        <div class="col-md-3">
                            <div class="form-floating floating-label-premium position-relative">
                                <input type="text" id="f_paciente" class="form-control pe-4" placeholder="Buscar paciente..." readonly required value="$paciente->{nombre}">
                                <label for="f_paciente">PACIENTE</label>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="form-floating floating-label-premium">
                                <input type="date" name="fecha" id="f_fecha" class="form-control" placeholder="Fecha" onchange="renderSlots(this.value)">
                                <label for="f_fecha">FECHA DE LA CITA</label>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="form-floating floating-label-premium">
                                <input type="text" name="motivo" id="f_motivo" class="form-control" placeholder="Detalles de la cita...">
                                <label for="f_motivo">MOTIVO / OBSERVACIONES</label>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="form-floating floating-label-premium">
                                <select name="id_medico" id="f_medico_select" class="form-select fw-bold" onchange="actualizarAgendaDestino()">
                                    $html_medicos
                                </select>
                                <label for="f_medico_select">PROFESIONAL</label>
                            </div>
                        </div>

                        <div class="col-md-3">
                            <div class="form-floating floating-label-premium">
                                <select name="sucursal" id="f_sucursal" class="form-select fw-bold">
                                    $html_sucursal
                                </select>
                                <label for="f_sucursal">SUCURSAL</label>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="form-floating floating-label-premium">
                                <select name="consultorio" id="f_consultorio" class="form-select fw-bold">
                                    <option value="Consultorio 1">Cons. 1</option>
                                    <option value="Consultorio 2">Cons. 2</option>
                                    <option value="Consultorio 3">Cons. 3</option>
                                    <option value="Consultorio 4">Cons. 4</option>
                                    <option value="Virtual">Virtual</option>
                                </select>
                                <label for="f_consultorio">LUGAR</label>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="form-floating floating-label-premium">
                                <select name="estado" id="f_estado" class="form-select fw-bold">
                                    <option value="Programada">Programada</option>
                                    <option value="Confirmada">Confirmada</option>
                                    <option value="Atendida">Atendida</option>
                                </select>
                                <label for="f_estado">ESTADO</label>
                            </div>
                        </div>
                        <div class="col-md-3">
                            <div class="form-floating floating-label-premium">
                                <select name="prioridad" id="f_prioridad" class="form-select fw-bold">
                                    <option value="Baja">Baja</option>
                                    <option value="Normal" selected>Normal</option>
                                    <option value="Alta">Alta</option>
                                    <option value="Urgente">Urgente</option>
                                </select>
                                <label for="f_prioridad">PRIORIDAD</label>
                            </div>
                        </div>
                    </div>

                    <div class="row g-4 mt-1">
                        <div class="col-md-12 p-3" style="background-color: var(--md-white-clinical); border-radius: 1rem; border: 1px solid var(--md-gray-soft);">
                            <div class="row">
                                <div class="col-md-3 border-bottom border-md-0 pb-3 pb-md-0 mb-3 mb-md-0 pe-md-3 border-md-end-soft">
                                    <label class="small fw-bold text-muted mb-3 d-block text-uppercase" style="letter-spacing: 1px;">Duración</label>
                                    <div class="d-flex flex-row flex-md-column flex-wrap gap-2 dur-bar-premium" id="btn-group-duracion">
                                        <!-- Generado dinámicamente -->
                                    </div>
                                </div>
                                <div class="col-md-9 d-flex flex-column ps-md-3">
                                    <label class="small fw-bold text-muted mb-3 d-block text-uppercase" style="letter-spacing: 1px;">Horarios Disponibles</label>
                                    <div id="slots-container" class="slot-grid-compact w-100 flex-grow-1" style="min-height: 200px; max-height: 250px; overflow-y: auto;"></div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <hr class="opacity-10 my-4" style="border-color: rgba(59, 130, 246, 0.2);">

                    <div class="d-flex justify-content-end gap-2 mt-4">
                        <button type="button" data-bs-dismiss="modal" class="btn btn-outline-secondary rounded-pill px-4 fw-bold">CANCELAR</button>
                        <button type="button" onclick="saveCita()" class="btn btn-primary rounded-pill px-5 fw-bold" style="background-color: var(--md-teal-clinical); border-color: var(--md-teal-clinical);"><i class="bi bi-save me-1"></i> GUARDAR CITA</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>

<!-- Script del médico actual para colisiones -->
<input type="hidden" id="f_medico" value="$id_medico">

<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/consulta_flow_privado.js"></script>
<script src="../js/autosave.js"></script>
<script src="../js/odontograma_spa.js?v=$^T"></script>

<!-- Scripts de soporte de Agenda de agenda_main.pl -->
<script>
  // Funciones mockeadas para evitar errores de compilación de agenda_spa_new.js
  function renderHeaders() {}
  function renderView() {}
  function renderMobileCalendar() {}
</script>
<script src="../js/agenda_spa_new.js?v=$^T"></script>

<script>
document.addEventListener('DOMContentLoaded', () => {
    // 1. Inicializar Wizard
    WizardController.init($draft_step);
    
    // 2. Cargar Draft Data
    const draftData = $draft_json;
    if (Object.keys(draftData).length > 0) {
        for (const key in draftData) {
            const val = draftData[key];
            const el = document.querySelector(`[name="\${key}"]`);
            if (el) {
                if (el.type === 'checkbox' || el.type === 'radio') {
                    if (el.value == val) el.checked = true;
                } else {
                    el.value = val;
                }
            }
        }
    }
    
    // 3. Inicializar Autosave
    AutosaveService.init('$id_paciente', '$id_cita', '$id_medico');
    
    // 4. Lógica de Odontograma Dinámico
    const especialidadSelect = document.querySelector('[name="especialidad"]');
    const odontoSection = document.getElementById('odontograma-section');
    
    function toggleOdontograma() {
        if (!odontoSection) return;
        const val = especialidadSelect ? especialidadSelect.value : '';
        const isOdonto = (val === 'Odontologia' || val === '100' || val.toLowerCase().includes('odontolog'));
        if (isOdonto) {
            odontoSection.style.display = 'block';
            if (typeof initOdontograma === 'function') {
                initOdontograma('odontograma-svg-container', '$id_paciente');
            }
        } else {
            odontoSection.style.display = 'none';
        }
    }
    
    if (especialidadSelect && odontoSection) {
        especialidadSelect.addEventListener('change', toggleOdontograma);
        toggleOdontograma();
    }
});

async function finalizarConsulta() {
    if (!WizardController.validateCurrentStep()) return;
    
    // Serializar todo el formulario del wizard
    const formEl = document.getElementById('wizard-form');
    const data = new FormData(formEl);
    
    Swal.fire({
        title: 'Finalizando Consulta...',
        html: 'Guardando expediente clínico y transacciones de caja',
        allowOutsideClick: false,
        didOpen: () => Swal.showLoading()
    });
    
    try {
        const res = await fetch('../api/cerrar_consulta_privado.pl', {
            method: 'POST',
            body: data
        });
        const json = await res.json();
        
        if (json.ok) {
            AutosaveService.stop();
            Swal.fire('Completado', 'La consulta y transacciones de caja se han guardado con éxito.', 'success').then(() => {
                window.location.href = 'render_expediente_clinico.pl?id=$id_paciente';
            });
        } else {
            Swal.fire('Error', json.msg || 'No se pudo guardar la consulta', 'warning');
        }
    } catch(e) {
        Swal.fire('Error', 'Fallo de conexión.', 'error');
    }
}
</script>
HTML

utils::sub_sidebar::render_sidebar_footer();

sub calcular_edad {
    my ($fecha_nac) = @_;
    return "N/A" unless $fecha_nac && $fecha_nac =~ /^(\d{4})-(\d{2})-(\d{2})$/;
    my ($a_nac, $m_nac, $d_nac) = ($1, $2, $3);
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    $year += 1900;
    $mon += 1;
    my $edad = $year - $a_nac;
    if ($mon < $m_nac || ($mon == $m_nac && $mday < $d_nac)) {
        $edad--;
    }
    return "$edad años";
}

sub cargar_datos_paciente {
    my ($id) = @_;
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
    my $res = leer_tabla($path, '\|');
    foreach my $c (@$res) {
        if ($c->[0] eq $id) {
            my $fecha_nac = $c->[6] // '';
            my $edad = calcular_edad($fecha_nac);
            return {
                id_paciente => $c->[0],
                nombre      => $c->[2]//'',
                curp        => $c->[4]//'',
                fecha_nac   => $fecha_nac,
                sexo        => $c->[7]//'',
                edad        => $edad
            };
        }
    }
    return { id_paciente => $id, nombre => 'Paciente Desconocido', curp => '', fecha_nac => '', sexo => '', edad => 'N/A' };
}

render_footer();
