#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib "$FindBin::Bin/..";
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');

my $q = CGI->new;
my $sd = check_session();

# --- CABECERA DE SEGURIDAD (Obligatoria para evitar Error 500) ---
if ($sd->{session_ok}) {
    print $sd->{q}->header(-type => 'text/html', -charset => 'UTF-8');
} else {
    print $sd->{q}->header(-status => '302 Found', -location => '../index.html');
    exit;
}

# Forzamos codificación para acentos en STDOUT
binmode(STDOUT, ":encoding(UTF-8)");

my $id_target = $q->param('id') || $q->param('id_paciente') || $q->param('edit_id') || '';
my $from_param = $q->param('from') || '';

# Menú lateral dinámico: Si viene de la Ficha del Expediente o id está presente, mostrar sidebar de expediente
my $pagina_actual_sidebar = ($from_param eq 'expediente' || ($id_target ne '' && $from_param ne 'directorio')) ? 'expediente' : 'pacientes';

# --- RENDER HEADER & SIDEBAR ---
render_header(
    usuario => $sd->{usuario},
    role    => $sd->{role},
    titulo  => "SDM - Expediente del Paciente",
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(
    role          => $sd->{role},
    usuario       => $sd->{usuario},
    id_medico     => $sd->{id_medico},
    pagina_actual => $pagina_actual_sidebar
);

my $btn_cancel_url = ($pagina_actual_sidebar eq 'expediente' && $id_target ne '') ? "render_expediente_clinico.pl?id=$id_target#tab3" : "pacientes.pl";
my $btn_cancel_text = ($pagina_actual_sidebar eq 'expediente' && $id_target ne '') ? "Volver al Expediente" : "Cancelar";

print <<HTML;
<link rel="stylesheet" href="../css/expediente_completo.css?v=$^T">
<style>
    .label-badge { font-size: 0.75rem; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.4rem; display: block; }
    .input-premium { width: 100%; padding: 0.75rem 1rem; border-radius: 1rem; border: 1px solid #e2e8f0; background: #F8FBFF; transition: 0.3s; font-weight: 600; outline: none; font-size: 0.95rem; color: #0A2A66; }
    .input-premium:focus { border-color: #19B7A5; background: white; box-shadow: 0 0 0 3px rgba(25, 183, 165, 0.15); }
    .section-divider { border-top: 1px solid #e2e8f0; padding-top: 2rem; margin-top: 2rem; }
</style>

<div class="animate-fade-in p-1 p-md-3">
    <!-- ENCABEZADO CORPORATIVO MEDENTIA DIAMOND -->
    <header class="bg-medentia-gradient text-white p-3 p-md-4 shadow-sm mb-4" style="border-radius: 1.5rem;">
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
            <div class="d-flex align-items-center gap-3">
                <div class="bg-white bg-opacity-10 p-2 p-md-3 rounded-circle d-flex align-items-center justify-content-center flex-shrink-0" style="width: 52px; height: 52px;">
                    <i class="bi bi-person-vcard-fill fs-3 text-white"></i>
                </div>
                <div>
                    <h3 id="page-hero-title" class="fw-black mb-0 text-white fs-4 fs-md-2" style="letter-spacing: -0.5px;">@{[ $id_target ne '' ? 'Editar Ficha de Paciente' : 'Inscripción de Paciente' ]}</h3>
                    <p id="page-subtitle" class="text-white-50 small mb-0 mt-1">@{[ $id_target ne '' ? 'Modifica los datos del expediente clínico del paciente' : 'Completa los campos para generar la ficha clínica oficial' ]}</p>
                </div>
            </div>
            <div class="d-flex gap-2">
                <a href="$btn_cancel_url" class="btn text-white fw-bold rounded-pill px-3 py-2 shadow-sm d-flex align-items-center gap-2 small transition-all" style="background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); backdrop-filter: blur(10px);">
                    <i class="bi bi-arrow-left text-white"></i><span>$btn_cancel_text</span>
                </a>
                <button type="button" id="btnGuardarPaciente" class="btn btn-medentia rounded-pill px-4 py-2 fw-bold shadow-sm d-flex align-items-center gap-2">
                    <i class="bi bi-cloud-check-fill me-1" style="color: var(--md-cyan-ia);"></i><span id="btn-text-guardar">@{[ $id_target ne '' ? 'Actualizar Ficha' : 'Guardar Expediente' ]}</span>
                </button>
            </div>
        </div>
    </header>

    <!-- FORMULARIO MASTER ESTILO FICHA DE IDENTIFICACIÓN (IMAGEN 1) -->
    <form id="formNuevoPaciente">
        <input type="hidden" id="editIdVal" value="$id_target">
        
        <!-- ROW PRINCIPAL: IDENTIDAD & DATOS CLÍNICOS (ESTÁNDAR IMAGEN 1) -->
        <div class="row g-4 mb-4">
            <!-- BLOQUE IZQUIERDO: INFORMACIÓN DE IDENTIDAD -->
            <div class="col-lg-8">
                <div class="card-medentia-aura p-4 p-md-5 h-100 border-0 shadow-sm" style="border-radius: 1.5rem;">
                    <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-person-lines-fill me-2" style="color: var(--md-teal-clinical);"></i>Informaci&oacute;n de Identidad</h5>
                    <div class="row g-3">
                        <div class="col-md-12">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" id="nombreCompleto" class="form-control fw-bold" placeholder="Nombre Completo" required>
                                <label>Nombre Completo <span class="text-danger">*</span></label>
                            </div>
                            <p id="errorNombre" class="text-danger small fw-bold d-none mt-1"><i class="bi bi-exclamation-triangle-fill"></i> Verifica el formato del nombre.</p>
                        </div>
                        
                        <div class="col-md-6">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" id="rfc" maxlength="13" class="form-control fw-bold text-uppercase" placeholder="RFC">
                                <label>RFC</label>
                            </div>
                        </div>
                        
                        <div class="col-md-6">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" id="curp" maxlength="18" class="form-control fw-bold text-uppercase" placeholder="CURP">
                                <label>CURP</label>
                            </div>
                        </div>
                        
                        <div class="col-md-6">
                            <div class="form-floating diamond-input-armor">
                                <input type="email" id="correo" class="form-control fw-bold" placeholder="Correo Electrónico">
                                <label>Correo Electr&oacute;nico</label>
                            </div>
                        </div>
                        
                        <div class="col-md-6">
                            <div class="form-floating diamond-input-armor">
                                <input type="tel" id="telefono" class="form-control fw-bold" placeholder="Teléfono" required>
                                <label>Tel&eacute;fono de Contacto <span class="text-danger">*</span></label>
                            </div>
                        </div>
                        
                        <div class="col-md-4">
                            <div class="form-floating diamond-input-armor">
                                <select id="genero" class="form-select fw-bold">
                                    <option value="">Seleccionar...</option>
                                    <option value="Masculino">Masculino</option>
                                    <option value="Femenino">Femenino</option>
                                    <option value="Otro">Otro</option>
                                </select>
                                <label>G&eacute;nero</label>
                            </div>
                        </div>
                        
                        <div class="col-md-4">
                            <div class="form-floating diamond-input-armor">
                                <input type="date" id="fechaNac" class="form-control fw-bold">
                                <label>Fecha de Nacimiento <span id="lblEdadCalculada" class="badge bg-primary text-white ms-1 d-none"></span></label>
                            </div>
                        </div>
                        
                        <div class="col-md-4">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" id="nacionalidad" class="form-control fw-bold" placeholder="Nacionalidad" value="Mexicana">
                                <label>Nacionalidad</label>
                            </div>
                        </div>

                        <!-- Campo Responsable / Tutor (si menor de edad) -->
                        <div class="col-md-12 d-none" id="containerTutor">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" id="responsableTutor" class="form-control fw-bold border-warning" placeholder="Responsable / Tutor">
                                <label class="text-warning"><i class="bi bi-shield-person-fill me-1"></i>Responsable / Tutor Legal *</label>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- BLOQUE DERECHO: DATOS CLÍNICOS -->
            <div class="col-lg-4">
                <div class="card-medentia-aura p-4 p-md-5 h-100 border-0 shadow-sm" style="border-radius: 1.5rem;">
                    <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-heart-pulse-fill me-2" style="color: var(--md-teal-clinical);"></i>Datos Cl&iacute;nicos</h5>
                    
                    <div class="mb-4 diamond-input-armor">
                        <label class="small fw-bold text-muted mb-2 ps-1">Grupo Sangu&iacute;neo</label>
                        <select id="tipoSangre" class="form-select py-3 fw-bold">
                            <option value="">No Evaluado / Desconocido</option>
                            <option value="O+">O Positivo (+)</option>
                            <option value="O-">O Negativo (-)</option>
                            <option value="A+">A Positivo (+)</option>
                            <option value="A-">A Negativo (-)</option>
                            <option value="B+">B Positivo (+)</option>
                            <option value="B-">B Negativo (-)</option>
                            <option value="AB+">AB Positivo (+)</option>
                            <option value="AB-">AB Negativo (-)</option>
                        </select>
                    </div>
                    
                    <div class="mb-4 diamond-input-armor">
                        <label class="small fw-bold text-muted mb-2 ps-1">Estado Civil</label>
                        <select id="estadoCivil" class="form-select py-3 fw-bold">
                            <option value="">Seleccionar...</option>
                            <option value="Soltero">Soltero/a</option>
                            <option value="Casado">Casado/a</option>
                            <option value="Divorciado">Divorciado/a</option>
                            <option value="Viudo">Viudo/a</option>
                        </select>
                    </div>
                    
                    <div class="mb-4 diamond-input-armor">
                        <label class="small fw-bold text-muted mb-2 ps-1">Ocupaci&oacute;n</label>
                        <div class="input-group">
                            <span class="input-group-text border-0 bg-transparent ps-3"><i class="bi bi-briefcase" style="color: var(--md-teal-clinical);"></i></span>
                            <input type="text" id="ocupacion" class="form-control py-3 fw-bold" placeholder="Ej. Diseñadora / Consultor">
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- SECCIONES DE ANTECEDENTES COMPLEMENTARIOS -->
        <div class="card-medentia-aura p-4 p-md-5 mb-4 border-0 shadow-sm" style="border-radius: 1.5rem;">
            <!-- Bloque: Antecedentes Heredofamiliares -->
            <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-people-fill me-2" style="color: var(--md-teal-clinical);"></i>Antecedentes Heredofamiliares</h5>
            <div class="row g-3 mb-4">
                <div class="col-md-4">
                    <label class="label-badge">Hipertensión Arterial Familiar</label>
                    <select id="hf_hipertension" class="input-premium">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                </div>

                <div class="col-md-4">
                    <label class="label-badge">Diabetes Mellitus Familiar</label>
                    <select id="hf_diabetes" class="input-premium">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                </div>

                <div class="col-md-4">
                    <label class="label-badge">Cardiopatías Familiares</label>
                    <select id="hf_cardiopatias" class="input-premium">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                </div>

                <div class="col-md-4">
                    <label class="label-badge">Cáncer Familiar</label>
                    <select id="hf_cancer" class="input-premium" onchange="toggleDetalle(this, 'hf_cancer_tipo_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="hf_cancer_tipo_cont" class="mt-2 d-none">
                        <input type="text" id="hf_cancer_tipo" class="input-premium" placeholder="Especificar tipo de cáncer">
                    </div>
                </div>

                <div class="col-md-4">
                    <label class="label-badge">Enfermedades Hereditarias</label>
                    <select id="hf_enfermedades" class="input-premium" onchange="toggleDetalle(this, 'hf_enfermedades_esp_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="hf_enfermedades_esp_cont" class="mt-2 d-none">
                        <input type="text" id="hf_enfermedades_especificar" class="input-premium" placeholder="Ej. Hemofilia">
                    </div>
                </div>

                <div class="col-md-4">
                    <label class="label-badge">Alergias Familiares</label>
                    <select id="hf_alergias" class="input-premium" onchange="toggleDetalle(this, 'hf_alergias_esp_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="hf_alergias_esp_cont" class="mt-2 d-none">
                        <input type="text" id="hf_alergias_especificar" class="input-premium" placeholder="Especificar alergias familiares">
                    </div>
                </div>
            </div>

            <hr class="my-4 opacity-25">

            <!-- Bloque: Antecedentes Personales Patológicos -->
            <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-file-earmark-medical-fill me-2" style="color: var(--md-teal-clinical);"></i>Antecedentes Personales Patol&oacute;gicos</h5>
            <div class="row g-3 mb-4">
                <div class="col-md-6">
                    <label class="label-badge">Enfermedades Crónicas</label>
                    <select id="pp_cronicas" class="input-premium" onchange="toggleDetalle(this, 'pp_cronicas_esp_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pp_cronicas_esp_cont" class="mt-2 d-none">
                        <input type="text" id="pp_cronicas_especificar" class="input-premium" placeholder="Hipertensión, Diabetes, Asma...">
                    </div>
                </div>

                <div class="col-md-6">
                    <label class="label-badge">Cirugías Previas</label>
                    <select id="pp_cirugias" class="input-premium" onchange="toggleDetalle(this, 'pp_cirugias_esp_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pp_cirugias_esp_cont" class="mt-2 d-none">
                        <input type="text" id="pp_cirugias_especificar" class="input-premium" placeholder="Tipo de cirugía y fecha approx">
                    </div>
                </div>

                <div class="col-md-6">
                    <label class="label-badge">Hospitalizaciones</label>
                    <select id="pp_hospitalizaciones" class="input-premium" onchange="toggleDetalle(this, 'pp_hosp_esp_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pp_hosp_esp_cont" class="mt-2 d-none">
                        <input type="text" id="pp_hospitalizaciones_especificar" class="input-premium" placeholder="Motivo de hospitalización">
                    </div>
                </div>

                <div class="col-md-6">
                    <label class="label-badge">Alergias Conocidas</label>
                    <select id="pp_alergias" class="input-premium" onchange="toggleDetalle(this, 'pp_alergias_esp_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pp_alergias_esp_cont" class="mt-2 d-none">
                        <input type="text" id="pp_alergias_especificar" class="input-premium" placeholder="Medicamentos, Alimentos...">
                    </div>
                </div>

                <div class="col-md-12">
                    <label class="label-badge">Tratamientos Médicos Actuales</label>
                    <select id="pp_tratamientos" class="input-premium" onchange="toggleDetalle(this, 'pp_trat_esp_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pp_trat_esp_cont" class="mt-2 d-none">
                        <input type="text" id="pp_tratamientos_especificar" class="input-premium" placeholder="Medicamentos y dosis actuales">
                    </div>
                </div>
            </div>

            <hr class="my-4 opacity-25">

            <!-- Bloque: Antecedentes Personales No Patológicos -->
            <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-heart-pulse me-2" style="color: var(--md-teal-clinical);"></i>Antecedentes Personales No Patol&oacute;gicos</h5>
            <div class="row g-3">
                <div class="col-md-4">
                    <label class="label-badge">Tabaquismo</label>
                    <select id="pnp_tabaquismo" class="input-premium" onchange="toggleDetalle(this, 'pnp_tab_cant_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pnp_tab_cant_cont" class="mt-2 d-none">
                        <input type="text" id="pnp_tabaquismo_cantidad" class="input-premium" placeholder="Cigarrillos al día">
                    </div>
                </div>

                <div class="col-md-4">
                    <label class="label-badge">Alcoholismo</label>
                    <select id="pnp_alcohol" class="input-premium" onchange="toggleDetalle(this, 'pnp_alc_frec_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pnp_alc_frec_cont" class="mt-2 d-none">
                        <input type="text" id="pnp_alcohol_frecuencia" class="input-premium" placeholder="Frecuencia">
                    </div>
                </div>

                <div class="col-md-4">
                    <label class="label-badge">Consumo de Sustancias</label>
                    <select id="pnp_drogas" class="input-premium" onchange="toggleDetalle(this, 'pnp_drogas_tipo_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pnp_drogas_tipo_cont" class="mt-2 d-none">
                        <input type="text" id="pnp_drogas_tipo" class="input-premium" placeholder="Tipo de sustancia">
                    </div>
                </div>

                <div class="col-md-6">
                    <label class="label-badge">Actividad Física</label>
                    <select id="pnp_actividad_fisica" class="input-premium" onchange="toggleDetalle(this, 'pnp_act_fisica_cont')">
                        <option value="No">No</option>
                        <option value="Sí">Sí</option>
                    </select>
                    <div id="pnp_act_fisica_cont" class="mt-2 d-none">
                        <input type="text" id="pnp_actividad_fisica_tipo" class="input-premium" placeholder="Tipo y frecuencia">
                    </div>
                </div>

                <div class="col-md-6">
                    <label class="label-badge">Alimentación</label>
                    <select id="pnp_alimentacion" class="input-premium" onchange="toggleAlimentacionOtro(this)">
                        <option value="Balanceada">Balanceada</option>
                        <option value="Alta en grasas">Alta en grasas</option>
                        <option value="Alta en azúcares">Alta en azúcares</option>
                        <option value="Otro">Otro</option>
                    </select>
                    <div id="pnp_alimentacion_otro_cont" class="mt-2 d-none">
                        <input type="text" id="pnp_alimentacion_otro" class="input-premium" placeholder="Especificar patrón de alimentación">
                    </div>
                </div>
            </div>
        </div>
    </form>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/paciente_form.js"></script>
<script>console.log("SDM DEBUG: CRUD Paciente MedentIA Diamond Refactorizado.");</script>
HTML

utils::sub_sidebar::render_sidebar_footer();

render_footer(role => $sd->{role});
1;