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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');

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
    id_medico     => $sd->{id_medico},
    pagina_actual => $pagina_actual_sidebar
);

# --- VERIFICAR SAAS CAPABILITIES (PACIENTES_ESTADO) Y CLUES ---
my $has_pacientes_estado = 0;
my $found_pacientes_estado = 0;
my $id_empresa = $sd->{id_empresa} // '';
my $org_clues = '';

my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fn, '<:raw', $negocios_file)) {
    while(my $ln = <$fn>) {
        chomp($ln);
        my @f = split(/\|/, $ln, -1);
        my $row_id = $f[0] // '';
        $row_id =~ s/\x00//g; $row_id =~ s/^\s+|\s+$//g;
        if ($row_id eq $id_empresa || ($id_empresa eq '0' && ($row_id eq '0' || $row_id eq ''))) {
            my $c_val = $f[18] // '';
            $c_val =~ s/\x00//g; $c_val =~ s/^\s+|\s+$//g;
            $org_clues = $c_val if $c_val;
            last;
        }
    }
    close($fn);
}

my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line);
        if ($biz_id eq $id_empresa && $key eq 'PACIENTES_ESTADO') {
            $has_pacientes_estado = ($val eq '1') ? 1 : 0;
            $found_pacientes_estado = 1;
            last;
        }
    }
    close($cf);
}
if (!$found_pacientes_estado && ($id_empresa eq '0' || $id_empresa eq '') && length($org_clues)) {
    $has_pacientes_estado = 1;
}

my $select_medico_html = '';
if ($sd->{role} =~ /Recepcion/i || $sd->{role} =~ /Administrador/i) {
    my $usuarios = utils::db_manager::leer_tabla(File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat'), '!');
    my $mi_org = $sd->{id_empresa} // '0';
    my $options_medicos = qq{<option value="0" selected>Abierto</option>\n};
    foreach my $u (@$usuarios) {
        next unless defined $u->[5] && $u->[5] =~ /Medico/i;
        my ($u_org) = split(/:/, $u->[6] // '');
        if ($u_org eq $mi_org || ($mi_org eq '0' && ($u_org eq '0' || $u_org eq ''))) {
            $options_medicos .= qq{<option value="$u->[0]">$u->[1]</option>\n};
        }
    }
    $select_medico_html = qq{
        <div class="mb-3 diamond-input-armor">
            <label class="small fw-bold text-muted mb-2 ps-1"><i class="bi bi-person-badge-fill me-1" style="color: var(--md-teal-clinical, #19B7A5);"></i>Médico Tratante</label>
            <select id="idMedicoAsignado" class="form-select py-2.5 fw-bold">
                $options_medicos
            </select>
        </div>
    };
} else {
    $select_medico_html = qq{<input type="hidden" id="idMedicoAsignado" value="$sd->{id_medico}">};
}

my $btn_cancel_url = ($pagina_actual_sidebar eq 'expediente' && $id_target ne '') ? "render_expediente_clinico.pl?id=$id_target#tab3" : "pacientes.pl";
my $btn_cancel_text = ($pagina_actual_sidebar eq 'expediente' && $id_target ne '') ? "Volver al Expediente" : "Cancelar";

my $btn_importar_header_html = '';
if ($has_pacientes_estado && $id_target eq '') {
    $btn_importar_header_html = qq{
        <button type="button" class="btn text-white fw-bold rounded-pill px-3 py-1.5 shadow-sm d-flex align-items-center gap-1.5 small" style="background: rgba(25, 183, 165, 0.25); border: 1.5px solid var(--md-teal-clinical, #19B7A5); backdrop-filter: blur(10px);" onclick="abrirModalImportarEmpleado()">
            <i class="bi bi-building-down" style="color: #6ee7b7;"></i><span>Importar Empleado Municipio</span>
        </button>
    };
}

print <<HTML;
<link rel="stylesheet" href="../css/ospulso_master_v2.css">
<link rel="stylesheet" href="../css/expediente_completo.css?v=$^T">
<link rel="stylesheet" href="../css/sdm_mobile_standards.css?v=1.1">
<style>
    .label-badge { font-size: 0.72rem; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.35rem; display: block; }
    .input-premium { width: 100%; padding: 0.65rem 0.9rem; border-radius: 0.75rem; border: 1px solid #e2e8f0; background: #F8FBFF; transition: 0.3s; font-weight: 600; outline: none; font-size: 0.9rem; color: #0A2A66; }
    .input-premium:focus { border-color: #19B7A5; background: white; box-shadow: 0 0 0 3px rgba(25, 183, 165, 0.15); }
    .section-divider { border-top: 1px solid #e2e8f0; padding-top: 1.5rem; margin-top: 1.5rem; }
</style>

<div class="content-wrapper container-mobile-flush p-1 p-md-3">
    <!-- HEADER COMPACTO CORPORATIVO (ESTÁNDAR IMÁGENES 1 Y 2) -->
    <div class="diamond-header-compact d-flex justify-content-between align-items-center mb-3">
        <div class="d-flex align-items-center gap-2 gap-sm-3">
            <div class="profile-hero text-start">
                <h4 id="page-hero-title" class="text-truncate m-0 text-white fw-bold d-flex align-items-center gap-2" style="max-width: 80vw; letter-spacing: -0.5px;">
                    <i class="bi bi-person-vcard text-white"></i> @{[ $id_target ne '' ? 'Editar Ficha de Paciente' : 'Inscripción de Paciente' ]}
                </h4>
                <p id="page-subtitle" class="text-white-50 small m-0" style="font-size: 0.8rem;">@{[ $id_target ne '' ? 'Modifica los datos del expediente clínico del paciente' : 'Completa los campos para generar la ficha clínica oficial' ]}</p>
            </div>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap justify-content-end">
            $btn_importar_header_html
            <a href="$btn_cancel_url" class="btn text-white fw-bold rounded-pill px-3 py-1.5 shadow-sm d-flex align-items-center gap-1.5 small" style="background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); backdrop-filter: blur(10px);">
                <i class="bi bi-arrow-left text-white"></i><span>$btn_cancel_text</span>
            </a>
            <button type="button" id="btnGuardarPaciente" class="btn rounded-pill px-3 px-md-4 py-1.5 fw-bold shadow-sm d-flex align-items-center gap-2 small text-white" style="background: var(--md-teal-clinical, #19B7A5); border: none;">
                <i class="bi bi-cloud-check-fill text-white"></i><span id="btn-text-guardar">@{[ $id_target ne '' ? 'Actualizar Ficha' : 'Guardar Expediente' ]}</span>
            </button>
        </div>
    </div>

    <!-- FORMULARIO MASTER ESTILO FICHA DE IDENTIFICACIÓN -->
    <form id="formNuevoPaciente">
        <input type="hidden" id="editIdVal" value="$id_target">
        
        <!-- ROW PRINCIPAL: IDENTIDAD & DATOS CLÍNICOS -->
        <div class="row g-3 mb-3">
            <!-- BLOQUE IZQUIERDO: INFORMACIÓN DE IDENTIDAD -->
            <div class="col-lg-8">
                <div class="card card-mobile-flush border-0 shadow-sm p-3 p-md-4 h-100" style="border-radius: 14px; background: #FFFFFF; border: 1.5px solid var(--md-teal-clinical, #19B7A5) !important;">
                    <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
                        <h5 class="fw-bold plus-jakarta mb-0 d-flex align-items-center gap-2" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                            <i class="bi bi-person-lines-fill" style="color: var(--md-teal-clinical, #19B7A5);"></i>Informaci&oacute;n de Identidad
                        </h5>
                        <span id="badgeOrigenEmpleado" class="badge rounded-pill px-3 py-1 small fw-semibold d-none" style="background: rgba(25, 183, 165, 0.12); color: #0d7a6e; border: 1px solid rgba(25, 183, 165, 0.3);">
                            <i class="bi bi-building-check me-1"></i>Padr&oacute;n Municipal
                        </span>
                    </div>

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

                        <!-- Campos Específicos: Dependencia y No. Empleado Municipal -->
                        <div class="col-md-8">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" id="dependencia" class="form-control fw-bold" placeholder="Dependencia / Adscripción">
                                <label><i class="bi bi-building me-1" style="color: var(--md-teal-clinical, #19B7A5);"></i>Dependencia / Adscripci&oacute;n</label>
                            </div>
                        </div>

                        <div class="col-md-4">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" id="num_empleado_estado" class="form-control fw-bold" placeholder="No. Empleado">
                                <label><i class="bi bi-hash me-1" style="color: var(--md-teal-clinical, #19B7A5);"></i>No. Empleado Municipal</label>
                            </div>
                        </div>

                        <!-- Campo Responsable / Tutor (si menor de edad) -->
                        <div class="col-md-12 d-none" id="containerTutor">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" id="responsableTutor" class="form-control fw-bold border-success-subtle" placeholder="Responsable / Tutor">
                                <label class="text-success fw-bold"><i class="bi bi-shield-person-fill me-1" style="color: var(--md-teal-clinical);"></i>Responsable / Tutor Legal *</label>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- BLOQUE DERECHO: DATOS CLÍNICOS -->
            <div class="col-lg-4">
                <div class="card card-mobile-flush border-0 shadow-sm p-3 p-md-4 h-100" style="border-radius: 14px; background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.45) !important;">
                    <h5 class="fw-bold plus-jakarta mb-3 d-flex align-items-center gap-2" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                        <i class="bi bi-heart-pulse-fill" style="color: var(--md-teal-clinical, #19B7A5);"></i>Datos Cl&iacute;nicos
                    </h5>
                    
                    $select_medico_html
                    
                    <div class="mb-3 diamond-input-armor">
                        <label class="small fw-bold text-muted mb-2 ps-1">Grupo Sangu&iacute;neo</label>
                        <select id="tipoSangre" class="form-select py-2.5 fw-bold">
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
                    
                    <div class="mb-3 diamond-input-armor">
                        <label class="small fw-bold text-muted mb-2 ps-1">Estado Civil</label>
                        <select id="estadoCivil" class="form-select py-2.5 fw-bold">
                            <option value="">Seleccionar...</option>
                            <option value="Soltero">Soltero/a</option>
                            <option value="Casado">Casado/a</option>
                            <option value="Divorciado">Divorciado/a</option>
                            <option value="Viudo">Viudo/a</option>
                        </select>
                    </div>
                    
                    <div class="mb-3 diamond-input-armor">
                        <label class="small fw-bold text-muted mb-2 ps-1">Ocupaci&oacute;n</label>
                        <div class="input-group">
                            <span class="input-group-text border-0 bg-transparent ps-3"><i class="bi bi-briefcase" style="color: var(--md-teal-clinical, #19B7A5);"></i></span>
                            <input type="text" id="ocupacion" class="form-control py-2.5 fw-bold" placeholder="Ej. Empleado Municipal / Diseñador">
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- CARD DOMICILIO CON BÚSQUEDA DE CP (SEPOMEX / INEGI OFICIAL) -->
        <div class="card card-mobile-flush border-0 shadow-sm p-3 p-md-4 mb-3" style="border-radius: 14px; background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.45) !important;">
            <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
                <h5 class="fw-bold plus-jakarta mb-0 d-flex align-items-center gap-2" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                    <i class="bi bi-geo-alt-fill" style="color: var(--md-teal-clinical, #19B7A5);"></i>Domicilio
                </h5>
                <span class="badge rounded-pill px-3 py-1 small fw-semibold" style="background: rgba(16, 185, 129, 0.1); color: #10b981; border: 1px solid rgba(16, 185, 129, 0.25);">
                    <i class="bi bi-patch-check-fill me-1"></i>Cat&aacute;logo Oficial SEPOMEX / INEGI
                </span>
            </div>

            <div class="row g-3">
                <!-- Buscador de CP -->
                <div class="col-md-3">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" id="cp_paciente" maxlength="5" class="form-control fw-bold" placeholder="00000" oninput="buscarDomicilioPorCP(this.value)">
                        <label>C&oacute;digo Postal (CP) *</label>
                    </div>
                    <div id="cpStatus" class="small mt-1 fw-bold text-muted d-none"></div>
                </div>

                <!-- Entidad Federativa -->
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" id="entidad_paciente" class="form-control fw-bold" placeholder="Entidad Federativa">
                        <label>Entidad Federativa (Estado)</label>
                    </div>
                </div>

                <!-- Municipio / Alcaldía -->
                <div class="col-md-5">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" id="municipio_paciente" class="form-control fw-bold" placeholder="Municipio / Alcaldía">
                        <label>Municipio / Alcald&iacute;a</label>
                    </div>
                </div>

                <!-- Colonia / Asentamiento -->
                <div class="col-md-5">
                    <div class="form-floating diamond-input-armor">
                        <select id="colonia_paciente" class="form-select fw-bold">
                            <option value="">Seleccione Colonia / Asentamiento...</option>
                        </select>
                        <label>Colonia / Asentamiento</label>
                    </div>
                </div>

                <!-- Calle -->
                <div class="col-md-7">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" id="calle_paciente" class="form-control fw-bold" placeholder="Calle / Avenida">
                        <label>Calle / Avenida</label>
                    </div>
                </div>

                <!-- Número Exterior -->
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" id="num_ext_paciente" class="form-control fw-bold" placeholder="No. Exterior">
                        <label>N&uacute;mero Exterior</label>
                    </div>
                </div>

                <!-- Número Interior -->
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" id="num_int_paciente" class="form-control fw-bold" placeholder="No. Interior">
                        <label>N&uacute;mero Interior (Opcional)</label>
                    </div>
                </div>
            </div>
        </div>

        <!-- SECCIONES DE ANTECEDENTES COMPLEMENTARIOS -->
        <div class="card card-mobile-flush border-0 shadow-sm p-3 p-md-4 mb-4" style="border-radius: 14px; background: #FFFFFF; border: 1.5px solid rgba(25, 183, 165, 0.45) !important;">
            <!-- Bloque: Antecedentes Heredofamiliares -->
            <h5 class="fw-bold plus-jakarta mb-3 d-flex align-items-center gap-2" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                <i class="bi bi-people-fill" style="color: var(--md-teal-clinical, #19B7A5);"></i>Antecedentes Heredofamiliares
            </h5>
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

            <hr class="my-3 opacity-25">

            <!-- Bloque: Antecedentes Personales Patológicos -->
            <h5 class="fw-bold plus-jakarta mb-3 d-flex align-items-center gap-2" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                <i class="bi bi-file-earmark-medical-fill" style="color: var(--md-teal-clinical, #19B7A5);"></i>Antecedentes Personales Patol&oacute;gicos
            </h5>
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

            <hr class="my-3 opacity-25">

            <!-- Bloque: Antecedentes Personales No Patológicos -->
            <h5 class="fw-bold plus-jakarta mb-3 d-flex align-items-center gap-2" style="color: var(--md-blue-deep, #0A2A66); font-size: 1.05rem;">
                <i class="bi bi-heart-pulse" style="color: var(--md-teal-clinical, #19B7A5);"></i>Antecedentes Personales No Patol&oacute;gicos
            </h5>
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

<!-- MODAL PARA IMPORTACIÓN ASISTIDA DE EMPLEADO DE MUNICIPIO (ESTÁNDAR IMAGEN 3) -->
<div class="modal fade" id="modalImportarEmpleado" tabindex="-1" aria-labelledby="modalImportarEmpleadoLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 shadow-lg" style="border-radius: 16px; overflow: hidden;">
            <div class="modal-header text-white px-4 py-3" style="background: var(--md-blue-deep, #0A2A66);">
                <div class="d-flex align-items-center gap-2">
                    <div class="rounded-circle d-flex align-items-center justify-content-center" style="width: 34px; height: 34px; background: rgba(255,255,255,0.15);">
                        <i class="bi bi-building-down text-white fs-6"></i>
                    </div>
                    <div>
                        <h6 class="modal-title fw-bold m-0" id="modalImportarEmpleadoLabel">Importar Empleado de Municipio / Estado</h6>
                        <span class="text-white-50 small" style="font-size: 0.75rem;">Búsqueda directa en el padrón oficial de la organización</span>
                    </div>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-3 p-md-4 bg-light">
                <!-- Buscador tipo Imagen 3 de Caja Rápida -->
                <div class="mb-3">
                    <label class="small fw-bold text-muted mb-1 ps-1">Número de Empleado o Nombre</label>
                    <div class="input-group shadow-xs">
                        <span class="input-group-text bg-white border-end-0 rounded-pill-start ps-3" style="border-color: #cbd5e1;"><i class="bi bi-search text-muted"></i></span>
                        <input type="text" id="iptBuscarEmpleadoModal" class="form-control border-start-0 border-end-0 py-2.5 fw-bold" placeholder="Escribe al menos 2 letras o dígitos del No. de empleado..." style="border-color: #cbd5e1;" onkeypress="if(event.key==='Enter') ejecutarBusquedaEmpleadoModal()">
                        <button class="btn text-white rounded-pill-end px-3 px-md-4 fw-bold" type="button" style="background: var(--md-blue-deep, #0A2A66);" onclick="ejecutarBusquedaEmpleadoModal()">
                            Buscar
                        </button>
                    </div>
                    <div class="form-text small ps-2 text-muted" style="font-size: 0.75rem;">
                        <i class="bi bi-info-circle me-1"></i>Puedes ingresar el número exacto de empleado o su nombre/apellidos para ver sugerencias automáticas.
                    </div>
                </div>

                <!-- Contenedor de Resultados con Scroll -->
                <div id="resultadosEmpleadoModalCont" class="p-2 bg-white rounded-3 border" style="min-height: 200px; max-height: 360px; overflow-y: auto;">
                    <div class="text-center py-5 text-muted">
                        <i class="bi bi-person-badge fs-1 text-secondary opacity-50 d-block mb-2"></i>
                        <span class="fw-bold small">Ingresa un criterio de búsqueda</span>
                        <p class="text-muted small m-0" style="font-size: 0.75rem;">Los empleados y su rama familiar de beneficiarios se desplegarán aquí.</p>
                    </div>
                </div>

                <!-- Aviso Fase Posterior: Rama Familiar Completa -->
                <div class="mt-3 p-2.5 rounded-3 border d-flex align-items-center justify-content-between gap-2" style="background: #f0fdfa; border-color: #ccfbf1 !important;">
                    <div class="d-flex align-items-center gap-2 small" style="color: #0f766e; font-size: 0.75rem;">
                        <i class="bi bi-diagram-3-fill fs-6"></i>
                        <span><b>Rama Familiar:</b> Se muestran el empleado titular y sus beneficiarios asociados. En esta fase puedes importar individualmente a cualquiera de ellos.</span>
                    </div>
                </div>
            </div>
            <div class="modal-footer bg-white border-top px-4 py-2.5 d-flex justify-content-end">
                <button type="button" class="btn btn-sm btn-light border rounded-pill px-4 fw-semibold" data-bs-dismiss="modal">Cerrar</button>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
    window.HAS_PACIENTES_ESTADO = $has_pacientes_estado;
    window.ORG_CLUES = "$org_clues";
</script>
<script src="../js/paciente_form.js?v=$^T"></script>
HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('pacientes');
1;