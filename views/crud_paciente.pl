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

# --- RENDER HEADER ---
render_header(
    usuario => $sd->{usuario},
    role    => $sd->{role},
    titulo  => "SDM - Expediente del Paciente"
);

print <<'HTML';
<style>
    .form-container { background: white; border-radius: 2rem; border: 1px solid #f1f5f9; box-shadow: 0 10px 15px -10px rgba(0,0,0,0.1); }
    .label-badge { font-size: 0.72rem; font-weight: 800; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.6rem; display: block; }
    .input-premium { width: 100%; padding: 0.85rem 1.2rem; border-radius: 14px; border: 1px solid #e2e8f0; background: #f8fafc; transition: 0.3s; font-weight: 600; outline: none; font-size: 0.95rem; }
    .input-premium:focus { border-color: #2563eb; background: white; box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.1); }
    .section-divider { border-top: 1px solid #f1f5f9; padding-top: 2.5rem; margin-top: 2.5rem; }
</style>

<div class="animate-fade-in p-1">
    <!-- Header de Acción -->
    <div class="d-flex flex-column flex-md-row justify-content-between align-items-center mb-5 gap-3">
        <div>
            <nav aria-label="breadcrumb">
                <ol class="breadcrumb mb-1">
                    <li class="breadcrumb-item small"><a href="pacientes.pl" class="text-decoration-none">Directorio</a></li>
                    <li id="breadcrumb-title" class="breadcrumb-item active small" aria-current="page">Nuevo Expediente</li>
                </ol>
            </nav>
            <h1 id="page-hero-title" class="plus-jakarta fw-black text-dark m-0">Inscripción de Paciente</h1>
            <p id="page-subtitle" class="text-muted m-0 small">Completa los campos para generar la ficha clínica oficial</p>
        </div>
        <div class="d-flex gap-2">
            <a href="pacientes.pl" class="btn btn-light rounded-pill px-4 fw-bold shadow-sm">Cancelar</a>
            <button type="button" id="btnGuardarPaciente" class="btn btn-primary rounded-pill px-4 py-2 fw-bold shadow-sm">
                <i class="bi bi-cloud-check-fill me-2"></i><span id="btn-text-guardar">Guardar Expediente</span>
            </button>
        </div>
    </div>

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
                <label class="label-badge">Fecha de Nacimiento</label>
                <input type="date" id="fechaNac" class="input-premium">
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
        </form>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script src="../js/paciente_form.js"></script>
<script>console.log("SDM DEBUG: CRUD Paciente Sincronizado y Blindado.");</script>
HTML

render_footer(role => $sd->{role});
1;