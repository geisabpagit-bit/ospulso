#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use lib '..';

# Carga de dependencias
require '../auth/check_session.pl';
require '../utils/sub_header.pl';
require '../utils/sub_sidebar.pl';
require '../utils/sub_footer.pl';

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
    pagina_actual => 'pacientes'
);

print <<'HTML';
<style>
    .form-container { background: white; border-radius: 2rem; border: 1px solid #f1f5f9; box-shadow: 0 10px 15px -10px rgba(0,0,0,0.1); }
    .label-badge { font-size: 0.72rem; font-weight: 800; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.6rem; display: block; }
    .input-premium { width: 100%; padding: 0.85rem 1.2rem; border-radius: 14px; border: 1px solid #e2e8f0; background: #f8fafc; transition: 0.3s; font-weight: 600; outline: none; font-size: 0.95rem; }
    .input-premium:focus { border-color: #2563eb; background: white; box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.1); }
    .section-divider { border-top: 1px solid #f1f5f9; padding-top: 2.5rem; margin-top: 2.5rem; }
</style>

<div class="animate-fade-in p-1 p-md-3">
    <!-- ENCABEZADO CORPORATIVO (ESTÁNDAR GLOBAL) -->
    <header class="bg-medentia-gradient text-white p-3 p-md-4 shadow-sm mb-4" style="border-radius: 1.25rem;">
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
            <div class="d-flex align-items-center gap-3">
                <div class="bg-white bg-opacity-10 p-2 p-md-3 rounded-circle d-flex align-items-center justify-content-center flex-shrink-0" style="width: 48px; height: 48px;">
                    <i class="bi bi-person-plus-fill fs-3 text-white"></i>
                </div>
                <div>
                    <h3 id="page-hero-title" class="fw-black mb-0 text-white fs-4 fs-md-2" style="letter-spacing: -0.5px;">Inscripci&oacute;n de Paciente</h3>
                    <p id="page-subtitle" class="text-white-50 small mb-0 mt-1">Completa los campos para generar la ficha cl&iacute;nica oficial</p>
                </div>
            </div>
            <div class="d-flex gap-2">
                <a href="pacientes.pl" class="btn text-white fw-bold rounded-pill px-3 py-2 shadow-sm d-flex align-items-center gap-2 small transition-all" style="background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); backdrop-filter: blur(10px);">
                    <i class="bi bi-x-circle-fill text-white"></i><span>Cancelar</span>
                </a>
                <button type="button" id="btnGuardarPaciente" class="btn btn-medentia rounded-pill px-4 py-2 fw-bold shadow-sm d-flex align-items-center gap-2">
                    <i class="bi bi-cloud-check-fill me-1"></i><span id="btn-text-guardar">Guardar Expediente</span>
                </button>
            </div>
        </div>
    </header>

    <!-- Contenedor del Formulario -->
    <div class="form-container p-4 p-md-5 mb-5 shadow-sm">
        <form id="formNuevoPaciente" class="row g-4">
            
            <!-- Bloque 1: Identidad Central -->
            <div class="col-12"><h5 class="plus-jakarta fw-bold text-dark"><i class="bi bi-card-checklist text-primary me-2"></i>Identidad Formal</h5></div>
            
            <div class="col-md-7 col-lg-8">
                <label class="label-badge">Nombre Completo <span class="text-danger">*</span></label>
                <input type="text" id="nombreCompleto" class="input-premium" placeholder="Captura nombre(s) y apellidos" required>
                <p id="errorNombre" class="text-danger small fw-bold d-none mt-1"><i class="bi bi-exclamation-triangle-fill"></i> Verifica el formato del nombre.</p>
            </div>
            
            <div class="col-md-5 col-lg-4">
                <label class="label-badge">Fecha de Nacimiento <span id="lblEdadCalculada" class="badge bg-primary text-white ms-2 d-none"></span></label>
                <input type="date" id="fechaNac" class="input-premium">
            </div>

            <!-- Campo Condicional: Responsable / Tutor (si menor de 18 años) -->
            <div class="col-md-7 col-lg-8 d-none" id="containerTutor">
                <label class="label-badge text-warning"><i class="bi bi-shield-person-fill me-1"></i>Responsable / Tutor <span class="text-danger">*</span></label>
                <input type="text" id="responsableTutor" class="input-premium border-warning" placeholder="Nombre completo del padre, madre o tutor legal">
            </div>

            <div class="col-md-4">
                <label class="label-badge">RFC / Cédula Fiscal</label>
                <input type="text" id="rfc" maxlength="13" class="input-premium text-uppercase" placeholder="Clave Fiscal">
            </div>

            <div class="col-md-4">
                <label class="label-badge">CURP (Identidad)</label>
                <input type="text" id="curp" maxlength="18" class="input-premium text-uppercase" placeholder="18 Caracteres">
            </div>

            <div class="col-md-4">
                <label class="label-badge">Género Registrado</label>
                <select id="genero" class="input-premium">
                    <option value="">Seleccionar...</option>
                    <option value="Masculino">Masculino</option>
                    <option value="Femenino">Femenino</option>
                    <option value="Otro">Otro / Prefiere no decir</option>
                </select>
            </div>

            <!-- Bloque 2: Localización -->
            <div class="col-12 section-divider"><h5 class="plus-jakarta fw-bold text-dark"><i class="bi bi-send-check text-success me-2"></i>Comunicación y Localización</h5></div>

            <div class="col-md-4">
                <label class="label-badge">Teléfono de Contacto <span class="text-danger">*</span></label>
                <input type="tel" id="telefono" class="input-premium" placeholder="10 dígitos directos" required>
            </div>

            <div class="col-md-8">
                <label class="label-badge">Correo Electrónico (Notificaciones)</label>
                <input type="email" id="correo" class="input-premium" placeholder="paciente@dominio.com">
            </div>

            <div class="col-md-6">
                <label class="label-badge">Nacionalidad</label>
                <input type="text" id="nacionalidad" class="input-premium" placeholder="Ej: Mexicana">
            </div>

            <div class="col-md-6">
                <label class="label-badge">Ocupación / Profesión</label>
                <input type="text" id="ocupacion" class="input-premium" placeholder="Ej: Consultor">
            </div>

            <!-- Bloque 3: Biomédicos -->
            <div class="col-12 section-divider"><h5 class="plus-jakarta fw-bold text-dark"><i class="bi bi-activity text-danger me-2"></i>Perfil Biomédico</h5></div>

            <div class="col-md-6">
                <label class="label-badge">Grupo Sanguíneo</label>
                <select id="tipoSangre" class="input-premium">
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

            <div class="col-md-6">
                <label class="label-badge">Estado Civil</label>
                <select id="estadoCivil" class="input-premium">
                    <option value="">Seleccionar...</option>
                    <option value="Soltero">Soltero/a</option>
                    <option value="Casado">Casado/a</option>
                    <option value="Divorciado">Divorciado/a</option>
                    <option value="Viudo">Viudo/a</option>
                </select>
            </div>

            <!-- Bloque 4: Antecedentes Heredofamiliares -->
            <div class="col-12 section-divider"><h5 class="plus-jakarta fw-bold text-dark"><i class="bi bi-people-fill text-primary me-2"></i>Antecedentes Heredofamiliares</h5></div>

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
                    <input type="text" id="hf_enfermedades_especificar" class="input-premium" placeholder="Ej. Hemofilia, Fibrosis Quística">
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

            <!-- Bloque 5: Antecedentes Personales Patológicos -->
            <div class="col-12 section-divider"><h5 class="plus-jakarta fw-bold text-dark"><i class="bi bi-file-earmark-medical-fill text-warning me-2"></i>Antecedentes Personales Patológicos</h5></div>

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
                    <input type="text" id="pp_cirugias_especificar" class="input-premium" placeholder="Tipo de cirugía y fecha aprox.">
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
                    <input type="text" id="pp_alergias_especificar" class="input-premium" placeholder="Medicamentos, Alimentos, Ambiente...">
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

            <!-- Bloque 6: Antecedentes Personales No Patológicos -->
            <div class="col-12 section-divider"><h5 class="plus-jakarta fw-bold text-dark"><i class="bi bi-heart-pulse text-info me-2"></i>Antecedentes Personales No Patológicos</h5></div>

            <div class="col-md-4">
                <label class="label-badge">Tabaquismo</label>
                <select id="pnp_tabaquismo" class="input-premium" onchange="toggleDetalle(this, 'pnp_tab_cant_cont')">
                    <option value="No">No</option>
                    <option value="Sí">Sí</option>
                </select>
                <div id="pnp_tab_cant_cont" class="mt-2 d-none">
                    <input type="text" id="pnp_tabaquismo_cantidad" class="input-premium" placeholder="Cigarrillos al día (ej: 5)">
                </div>
            </div>

            <div class="col-md-4">
                <label class="label-badge">Alcoholismo</label>
                <select id="pnp_alcohol" class="input-premium" onchange="toggleDetalle(this, 'pnp_alc_frec_cont')">
                    <option value="No">No</option>
                    <option value="Sí">Sí</option>
                </select>
                <div id="pnp_alc_frec_cont" class="mt-2 d-none">
                    <input type="text" id="pnp_alcohol_frecuencia" class="input-premium" placeholder="Frecuencia (ej. Ocasional, Semanal)">
                </div>
            </div>

            <div class="col-md-4">
                <label class="label-badge">Consumo de Drogas / Sustancias</label>
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
                    <input type="text" id="pnp_actividad_fisica_tipo" class="input-premium" placeholder="Tipo y frecuencia (ej: Gimnasio 3 veces/sem)">
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
        </form>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script src="../js/paciente_form.js"></script>
<script>console.log("SDM DEBUG: CRUD Paciente Sincronizado y Blindado.");</script>
HTML

utils::sub_sidebar::render_sidebar_footer();

render_footer(role => $sd->{role});
1;