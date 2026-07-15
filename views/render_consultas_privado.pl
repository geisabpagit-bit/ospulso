#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON qw(encode_json decode_json);
use FindBin;
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

$paciente->{motivo_precargado} = '';
if ($id_cita) {
    my $citas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
    my $res = leer_tabla($citas_file, '\|');
    foreach my $c (@$res) {
        if ($c->[0] eq $id_cita) {
            $paciente->{motivo_precargado} = "MOTIVO DE CITA PROGRAMADA:\n" . $c->[6] . "\n\nNotas previas: " . ($c->[7]||'Ninguna');
            last;
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
                $draft_json =~ s/\\n/\n/g; # Restaurar saltos de línea
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
    titulo      => 'SDM Diamond - Wizard Clínico (Privado)', 
    skip_header => 1
);

print <<HTML;
<link rel="stylesheet" href="../css/consulta_flow.css">

<!-- Estilos premium del modal de Cita -->
<style>
  .modal-backdrop.show { z-index: 104900 !important; }
  .ui-autocomplete { z-index: 105001 !important; }
  .floating-label-premium label { font-size: 0.65rem !important; text-transform: uppercase; color: #64748b; font-weight: 700; padding: 1rem 0.75rem; }
  .floating-label-premium .form-control, .floating-label-premium .form-select { border-radius: 1rem; background-color: #f8fafc; border: 1px solid transparent; transition: all 0.2s; box-shadow: none; }
  .floating-label-premium .form-control:focus, .floating-label-premium .form-select:focus { background-color: #ffffff; border-color: rgba(59, 130, 246, 0.4); box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.1); }
  .dur-bar-premium .btn { border-radius: 12px !important; margin: 0; border: 1px solid rgba(59, 130, 246, 0.2) !important; background-color: #ffffff; color: #64748b; font-weight: 600; font-size: 0.85rem; padding: 10px 0; transition: all 0.2s; }
  .dur-bar-premium .btn.active { background-color: var(--md-blue-medical) !important; color: #ffffff !important; border-color: var(--md-blue-medical) !important; box-shadow: 0 4px 10px rgba(59, 130, 246, 0.2); transform: scale(1.05); z-index: 2; }
  .dur-bar-premium .btn:hover:not(.active) { background-color: #f0f7ff; color: #1e293b; }
  #modalCita .slot-grid-compact { display: grid !important; grid-template-columns: repeat(auto-fill, minmax(65px, 1fr)) !important; gap: 10px !important; padding: 12px !important; }
  #modalCita .btn-slot { font-size: 0.70rem !important; padding: 6px 0 !important; border-radius: 8px !important; background-color: #dcfce7 !important; color: #166534 !important; border: 1px solid #bbf7d0 !important; font-weight: 700; }
  #modalCita .btn-slot:hover:not(:disabled) { background-color: #bbf7d0 !important; border-color: #86efac !important; transform: translateY(-2px); box-shadow: 0 4px 8px rgba(22, 101, 52, 0.15); }
  #modalCita .btn-slot.active { background-color: #16a34a !important; color: #ffffff !important; border-color: #15803d !important; box-shadow: 0 4px 12px rgba(22, 101, 52, 0.3); }
  #modalCita .slot-lunch { background-color: #fee2e2 !important; color: #991b1b !important; border-color: #fecaca !important; }
  #modalCita .slot-busy { background-color: #fef9c3 !important; color: #854d0e !important; border-color: #fde047 !important; }
  \@media (min-width: 768px) {
      .border-md-end-soft { border-right: 1px solid var(--md-gray-soft) !important; }
  }
</style>

<div class="wizard-container animate__animated animate__fadeIn">
    <!-- Encabezado Clínico -->
    <div class="d-flex justify-content-between align-items-center mb-4">
        <div>
            <h2 class="fw-black mb-0" style="color: var(--md-navy);">
                <i class="bi bi-heart-pulse-fill me-2" style="color: var(--md-teal-clinical);"></i>Consulta M&eacute;dica (Privada)
            </h2>
            <p class="text-muted fw-bold">Paciente: $paciente->{nombre} (Folio: $id_paciente)</p>
        </div>
        <a href="render_expediente_clinico.pl?id=$id_paciente" class="btn btn-outline-secondary rounded-pill fw-bold">
            <i class="bi bi-x-circle me-2"></i>Cancelar y Salir
        </a>
    </div>

    <!-- Stepper y Progress Bar (8 pasos) -->
    <div class="wizard-stepper">
        <div class="wizard-step active" onclick="WizardController.jumpToStep(0)">
            <div class="wizard-step-icon"><i class="bi bi-person-lines-fill"></i></div>
            <div class="wizard-step-label">Registro</div>
        </div>
        <div class="wizard-step" onclick="WizardController.jumpToStep(1)">
            <div class="wizard-step-icon"><i class="bi bi-clock-history"></i></div>
            <div class="wizard-step-label">Anamnesis</div>
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
        @{[ render_step_exploracion() ]}
        @{[ render_step_estudios() ]}
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
        if (especialidadSelect && especialidadSelect.value === 'Odontologia') {
            odontoSection.style.display = 'block';
            if (typeof initOdontograma === 'function') {
                initOdontograma('odontograma-svg-container', '$id_paciente');
            }
        } else {
            odontoSection.style.display = 'none';
        }
    }
    
    if (especialidadSelect) {
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

sub cargar_datos_paciente {
    my ($id) = @_;
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
    my $res = leer_tabla($path, '\|');
    foreach my $c (@$res) {
        if ($c->[0] eq $id) {
            return {
                id_paciente => $c->[0],
                nombre      => $c->[2]//'',
                curp        => $c->[4]//'',
                sexo        => $c->[7]//''
            };
        }
    }
    return { id_paciente => $id, nombre => 'Paciente Desconocido', curp => '', sexo => '' };
}

render_footer();
