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
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_registro.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_anamnesis.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_exploracion.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_estudios.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_soap.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_comunicacion.pl');
require File::Spec->catfile($FindBin::Bin, 'partials', 'consultas', 'step_cierre.pl');

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

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => 'SDM Diamond - Wizard Clínico', 
    skip_header => 1
);

print <<HTML;
<link rel="stylesheet" href="../css/consulta_flow.css">

<div class="wizard-container animate__animated animate__fadeIn">
    <!-- Encabezado Clínico -->
    <div class="d-flex justify-content-between align-items-center mb-4">
        <div>
            <h2 class="fw-black mb-0" style="color: var(--md-navy);">
                <i class="bi bi-heart-pulse-fill me-2" style="color: var(--md-teal-clinical);"></i>Consulta M&eacute;dica
            </h2>
            <p class="text-muted fw-bold">Paciente: $paciente->{nombre} (Folio: $id_paciente)</p>
        </div>
        <a href="render_expediente_clinico.pl?id=$id_paciente" class="btn btn-outline-secondary rounded-pill fw-bold">
            <i class="bi bi-x-circle me-2"></i>Cancelar y Salir
        </a>
    </div>

    <!-- Stepper y Progress Bar -->
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
            <div class="wizard-step-icon"><i class="bi bi-check-circle"></i></div>
            <div class="wizard-step-label">Cierre</div>
        </div>
    </div>
    
    <div class="wizard-progress-bar">
        <div class="wizard-progress-fill" id="wizard-progress-fill"></div>
    </div>

    <!-- Contenedor Principal (Form) -->
    <form id="wizard-form">
        @{[ render_step_registro($paciente) ]}
        @{[ render_step_anamnesis() ]}
        @{[ render_step_exploracion() ]}
        @{[ render_step_estudios() ]}
        @{[ render_step_soap() ]}
        @{[ render_step_comunicacion() ]}
        @{[ render_step_cierre() ]}
    </form>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/consulta_flow.js"></script>
<script src="../js/autosave.js"></script>
<script src="../js/odontograma_spa.js?v=$^T"></script>

<script>
document.addEventListener('DOMContentLoaded', () => {
    // 1. Inicializar Wizard
    WizardController.init($draft_step);
    
    // 2. Cargar Draft Data
    const draftData = $draft_json;
    if (Object.keys(draftData).length > 0) {
        // Restaurar inputs
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
            // Iniciar Odontograma SPA
            if (typeof initOdontograma === 'function') {
                initOdontograma('odontograma-svg-container', '$id_paciente');
            }
        } else {
            odontoSection.style.display = 'none';
        }
    }
    
    if (especialidadSelect) {
        especialidadSelect.addEventListener('change', toggleOdontograma);
        // Disparar en carga por si viene del draft
        toggleOdontograma();
    }
});

async function finalizarConsulta() {
    if (!WizardController.validateCurrentStep()) return;
    
    const data = AutosaveService.collectData().formData;
    
    Swal.fire({
        title: 'Finalizando Consulta...',
        html: 'Guardando expediente clínico',
        allowOutsideClick: false,
        didOpen: () => Swal.showLoading()
    });
    
    try {
        const res = await fetch('../api/cerrar_consulta.pl', {
            method: 'POST',
            body: data
        });
        const json = await res.json();
        
        if (json.ok) {
            AutosaveService.stop();
            Swal.fire('Completado', 'La consulta ha sido guardada y el historial actualizado.', 'success').then(() => {
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
    return { nombre => 'Paciente Desconocido', curp => '', sexo => '' };
}

render_footer();