#!/usr/bin/perl
# --- Diamond Edition v4.0.1: Wizard Stepper Profile (Refactored) ---
use strict;
use warnings;
use utf8;
use Encode qw(encode); 
use JSON::PP;

sub render_edita_perfil {
    my %args = @_;
    my $u    = $args{user_data} // {};
    my $b    = $args{biz_data}  // {};
    my $bs   = $args{biz_status} // {};
    my $p    = $args{perfil_data} // {};
    my $cf   = $args{cat_formacion} // [];
    my $cr   = $args{cat_religion} // [];
    my $cn   = $args{cat_nacionalidades} // [];
    my $role = $args{role}      // 'Sin Rol';
    my $c_s  = $args{correo_sesion} // 'No detectado';
    
    my $clave_formacion = $p->{clave_formacion} // '';
    my $clave_nacionalidad = $p->{clave_nacionalidad} || 'MEX';
    my $clave_religion = $p->{clave_religion} || '110103';


    my $nacionalidad_options = '<option value="">Seleccione Nacionalidad...</option>';
    foreach my $nat (@$cn) {
        my $sel = ($nat->{clave} eq $clave_nacionalidad) ? 'selected' : '';
        $nacionalidad_options .= qq(<option value="$nat->{clave}" $sel>$nat->{pais}</option>\n);
    }

    my $religion_options = '<option value="">Seleccione Religión...</option>';
    foreach my $rel (@$cr) {
        my $sel = ($rel->{clave} eq $clave_religion) ? 'selected' : '';
        $religion_options .= qq(<option value="$rel->{clave}" $sel>$rel->{religion} ($rel->{grupo})</option>\n);
    }

    my $agrupacion_actual = '';
    my $formacion_text_actual = '';

    my %agrupaciones_unicas = ();
    my @js_formaciones_array = ();

    foreach my $f (@$cf) {
        if ($f->{clave} eq $clave_formacion) {
            $formacion_text_actual = $f->{formacion};
            $agrupacion_actual = $f->{agrupacion};
        }
        
        my $ag = $f->{agrupacion} // '';
        $agrupaciones_unicas{$ag} = 1 if $ag;
        
        my $f_nom = $f->{formacion};
        $f_nom =~ s/'/\\'/g;
        push @js_formaciones_array, "{c:'$f->{clave}', f:'$f_nom', a:'$ag'}";
    }
    
    my $js_formaciones_str = join(',', @js_formaciones_array);

    my $agrupaciones_options = '<option value="">Seleccione una Rama...</option>';
    foreach my $agr (sort keys %agrupaciones_unicas) {
        my $sel = ($agr eq $agrupacion_actual) ? 'selected' : '';
        $agrupaciones_options .= qq(<option value="$agr" $sel>$agr</option>\n);
    }
    
    my $u_nombre = $u->{nombre} // 'N/A';
    my $u_correo = $u->{correo} // 'N/A';

    my $is_paciente = ($role eq 'Paciente') ? 1 : 0;

print <<HTML;
<link rel="stylesheet" href="../css/perfil_flow.css">
<style>
    .btn-aura-save {
        background: linear-gradient(135deg, #0d1e3d 0%, #3b82f6 100%);
        border: none; border-radius: 1rem; padding: 1rem 2rem;
        font-weight: 800; letter-spacing: 0.5px; transition: 0.3s;
    }
    .btn-aura-save:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(59, 130, 246, 0.3); }
</style>

<div class="wizard-container animate__animated animate__fadeIn">
    <!-- Encabezado Clínico -->
    <div class="d-flex justify-content-between align-items-center flex-wrap gap-3 mb-4">
        <div>
            <h2 class="fw-black mb-0" style="color: var(--md-navy);">Nombre: $u_nombre ($role)</h2>
            <p class="text-muted small mb-0">Actualiza tu información y asegura que tu expediente esté al día.</p>
        </div>
        <div>
            <button type="submit" form="perfilForm" class="btn btn-primary btn-aura-save py-2 px-4 shadow-sm" id="guardarBtn">
                <i class="bi bi-cloud-upload-fill me-2"></i>Actualizar Perfil
            </button>
        </div>
    </div>
HTML

    if ($is_paciente) {
        print <<HTML;
    <!-- Stepper Paciente -->
    <div class="wizard-stepper">
        <div class="wizard-step active" onclick="PerfilWizardController.jumpToStep(0)">
            <div class="wizard-step-icon"><i class="bi bi-person-badge"></i></div>
            <div class="wizard-step-label">Identidad</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(1)">
            <div class="wizard-step-icon"><i class="bi bi-person-vcard"></i></div>
            <div class="wizard-step-label">Demogr&aacute;ficos</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(2)">
            <div class="wizard-step-icon"><i class="bi bi-briefcase"></i></div>
            <div class="wizard-step-label">Otros Datos</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(3)">
            <div class="wizard-step-icon"><i class="bi bi-shield-lock"></i></div>
            <div class="wizard-step-label">Seguridad</div>
        </div>
    </div>
HTML
    } else {
        print <<HTML;
    <!-- Stepper Especialista -->
    <div class="wizard-stepper">
        <div class="wizard-step active" onclick="PerfilWizardController.jumpToStep(0)">
            <div class="wizard-step-icon"><i class="bi bi-person-badge"></i></div>
            <div class="wizard-step-label">Identidad</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(1)">
            <div class="wizard-step-icon"><i class="bi bi-hospital"></i></div>
            <div class="wizard-step-label">CLUES</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(2)">
            <div class="wizard-step-icon"><i class="bi bi-award"></i></div>
            <div class="wizard-step-label">Suscripci&oacute;n</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(3)">
            <div class="wizard-step-icon"><i class="bi bi-shield-lock"></i></div>
            <div class="wizard-step-label">Seguridad</div>
        </div>
    </div>
HTML
    }

print <<HTML;
    <div class="wizard-progress-bar">
        <div class="wizard-progress-fill" id="wizard-progress-fill"></div>
    </div>

    <form id="perfilForm">
        <input type="hidden" name="user_role" value="$role">
        <div id="alertContainer"></div>
        <div class="alert alert-warning border-0 shadow-sm rounded-4 d-flex align-items-center justify-content-between mb-3 py-2 px-3 animate__animated animate__fadeIn">
            <span class="small fw-semibold text-dark"><i class="bi bi-shield-fill-exclamation text-warning me-2"></i>Recuerda que para guardar cualquier cambio es obligatorio ingresar tu contraseña actual.</span>
            <button type="button" class="btn btn-warning btn-sm rounded-pill fw-bold text-dark px-3" onclick="PerfilWizardController.jumpToStep(3); setTimeout(function(){ \$('#clave_actual').focus(); }, 300);">
                <i class="bi bi-key-fill me-1"></i>Ir a Contraseña
            </button>
        </div>

        <!-- PANEL 0: IDENTIDAD (Común para todos) -->
        <div class="wizard-panel active" id="step-panel-0">
            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-person-badge-fill me-2"></i>Identidad de Acceso</h5>
            <div class="row g-3">
                <div class="col-md-6">
                    <div class="form-floating">
                        <input type="text" class="form-control" id="nombre_completo" name="nombre_completo" placeholder="Nombre" value="$u_nombre" required>
                        <label for="nombre_completo">Nombre Completo</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <input type="email" class="form-control bg-light" id="correo_login" value="$u_correo" readonly>
                        <label for="correo_login">Correo Electr&oacute;nico</label>
                    </div>
                </div>
            </div>
HTML

    if ($role eq 'Medico') {
        print <<HTML;
            <div class="row g-3 mt-1">
                <div class="col-md-5">
                    <div class="form-floating">
                        <select class="form-select border-primary" id="biz_agrupacion">
                            $agrupaciones_options
                        </select>
                        <label>Rama / Agrupación</label>
                    </div>
                </div>
                <div class="col-md-7">
                    <div class="form-floating">
                        <input class="form-control border-primary" list="datalist_formacion" id="biz_formacion_text" value="$formacion_text_actual" placeholder="Escriba para buscar..." autocomplete="off">
                        <datalist id="datalist_formacion">
                            <!-- JS Inject -->
                        </datalist>
                        <input type="hidden" id="biz_formacion" name="biz_formacion" value="$clave_formacion">
                        <label>Formación Académica Oficial <i class="bi bi-search ms-1 text-muted"></i></label>
                    </div>
                </div>
            </div>
            <div class="row g-3 mt-1">
                <div class="col-md-6">
                    <div class="form-floating">
                        <select class="form-select border-primary" id="biz_nacionalidad" name="biz_nacionalidad">
                            $nacionalidad_options
                        </select>
                        <label for="biz_nacionalidad">Nacionalidad</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <select class="form-select border-primary" id="biz_religion" name="biz_religion">
                            $religion_options
                        </select>
                        <label for="biz_religion">Religi&oacute;n</label>
                    </div>
                </div>
            </div>
HTML
    }

    print <<HTML;
            <div class="text-end mt-4">
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente Sección <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
HTML

    if ($is_paciente) {
        my $p_rfc    = $b->{rfc}          // '';
        my $p_curp   = $b->{curp}         // '';
        my $p_tel    = $b->{telefono}     // '';
        my $p_fnac   = $b->{f_nac}        // '';
        my $p_sexo   = $b->{sexo}         // '';
        my $p_sangre = $b->{tipo_sangre}  // '';
        my $p_ecivil = $b->{e_civil}      // '';
        my $p_ocup   = $b->{ocupacion}    // '';
        my $p_nac    = $b->{nacionalidad} // '';

        print <<HTML;
        <!-- PANEL 1: PACIENTE DEMOGRAFICOS -->
        <div class="wizard-panel" id="step-panel-1">
            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-person-vcard me-2"></i>Datos Demográficos</h5>
            <div class="row g-3">
                <div class="col-md-6">
                    <div class="form-floating">
                        <input type="text" class="form-control" name="p_rfc" value="$p_rfc" placeholder="RFC">
                        <label>RFC</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <input type="text" class="form-control" name="p_curp" value="$p_curp" placeholder="CURP">
                        <label>CURP</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <input type="tel" class="form-control" name="p_tel" value="$p_tel" placeholder="Tel">
                        <label>Tel&eacute;fono de Contacto</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <input type="date" class="form-control" name="p_fnac" value="$p_fnac">
                        <label>Fecha de Nacimiento</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <select class="form-select" name="p_sexo">
                            <option value="Masculino" @{[ $p_sexo eq 'Masculino' ? 'selected' : '' ]}>Masculino</option>
                            <option value="Femenino" @{[ $p_sexo eq 'Femenino' ? 'selected' : '' ]}>Femenino</option>
                            <option value="Otro" @{[ $p_sexo eq 'Otro' ? 'selected' : '' ]}>Otro</option>
                        </select>
                        <label>G&eacute;nero</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <select class="form-select" name="p_sangre">
                            <option value="O+" @{[ $p_sangre eq 'O+' ? 'selected' : '' ]}>O Positivo</option>
                            <option value="O-" @{[ $p_sangre eq 'O-' ? 'selected' : '' ]}>O Negativo</option>
                            <option value="A+" @{[ $p_sangre eq 'A+' ? 'selected' : '' ]}>A Positivo</option>
                            <option value="B+" @{[ $p_sangre eq 'B+' ? 'selected' : '' ]}>B Positivo</option>
                            <option value="AB+" @{[ $p_sangre eq 'AB+' ? 'selected' : '' ]}>AB Positivo</option>
                        </select>
                        <label>Tipo de Sangre</label>
                    </div>
                </div>
            </div>
            <div class="d-flex justify-content-between mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>

        <!-- PANEL 2: PACIENTE OTROS DATOS -->
        <div class="wizard-panel" id="step-panel-2">
            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-briefcase me-2"></i>Otros Datos</h5>
            <div class="row g-3">
                <div class="col-md-4">
                    <div class="form-floating">
                        <select class="form-select" name="p_ecivil">
                            <option value="Soltero" @{[ $p_ecivil eq 'Soltero' ? 'selected' : '' ]}>Soltero/a</option>
                            <option value="Casado" @{[ $p_ecivil eq 'Casado' ? 'selected' : '' ]}>Casado/a</option>
                            <option value="Divorciado" @{[ $p_ecivil eq 'Divorciado' ? 'selected' : '' ]}>Divorciado/a</option>
                        </select>
                        <label>Estado Civil</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="text" class="form-control" name="p_ocup" value="$p_ocup" placeholder="Ocupacion">
                        <label>Ocupaci&oacute;n</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="text" class="form-control" name="p_nac" value="$p_nac" placeholder="Nacionalidad">
                        <label>Nacionalidad</label>
                    </div>
                </div>
            </div>
            <div class="d-flex justify-content-between mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>

        <!-- PANEL 3: PACIENTE SEGURIDAD -->
        <div class="wizard-panel" id="step-panel-3">
            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-shield-lock-fill me-2"></i>Seguridad de Cuenta</h5>
            <div class="row g-3">
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="password" class="form-control border-warning" id="clave_actual" name="clave_actual" placeholder="Clave Actual" required>
                        <label for="clave_actual">Contraseña Actual *</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="password" class="form-control" id="clave_nueva" name="clave_nueva" placeholder="Nueva Clave">
                        <label for="clave_nueva">Nueva Contraseña (Opcional)</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="password" class="form-control" id="clave_confirmar" name="clave_confirmar" placeholder="Confirmar">
                        <label for="clave_confirmar">Confirmar Nueva Contraseña</label>
                    </div>
                </div>
            </div>
            <div class="d-flex justify-content-start mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
            </div>
        </div>
HTML

    } else {
        # --- VISTA ESPECIALISTA ---
        my $b_nombre = $b->{nombre}        // '';
        my $b_rfc    = $b->{rfc}           // '';
        my $b_razon  = $b->{razon_social}  // '';
        my $b_tel    = $b->{telefono}      // '';
        my $b_email  = $b->{email_negocio} // '';
        my $b_dir    = $b->{domicilio}     // '';
        my $b_cp       = $b->{codigo_postal} // '';
        my $b_entidad  = $b->{entidad}       // '';
        my $b_mnpio    = $b->{municipio}     // '';
        my $b_colonia  = $b->{colonia}       // '';
        my $b_clues    = $b->{clues}         // '';
        my $b_ext      = $b->{extension}     // '0';
        my $b_lat      = $b->{latitud}       // '';
        my $b_lng      = $b->{longitud}      // '';
        
        $b_nombre =~ s/"/&quot;/g;
        $b_razon  =~ s/"/&quot;/g;
        $b_email  =~ s/"/&quot;/g;
        $b_dir    =~ s/"/&quot;/g;
        
        my $colonia_options = $b_colonia ? qq(<option value="$b_colonia" selected>$b_colonia</option>) : qq(<option value="">Ingrese su C.P. para cargar localidades</option>);

        print <<HTML;
        <!-- PANEL 1: ESPECIALISTA CLUES (Ubicación, CLUES, Comercial) -->
        <div class="wizard-panel" id="step-panel-1">
            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-geo-alt me-2"></i>Ubicación y Domicilio</h5>
            <div class="row g-3">
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="text" class="form-control" id="biz_cp" name="biz_cp" value="$b_cp" placeholder="C.P." maxlength="5">
                        <label>C&oacute;digo Postal</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="text" class="form-control bg-light" id="biz_entidad" name="biz_entidad" value="$b_entidad" placeholder="Entidad" readonly>
                        <label>Entidad Federativa</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="text" class="form-control bg-light" id="biz_municipio" name="biz_municipio" value="$b_mnpio" placeholder="Municipio" readonly>
                        <label>Municipio o Alcald&iacute;a</label>
                    </div>
                </div>
                <div class="col-12">
                    <div class="form-floating">
                        <select class="form-select" id="biz_colonia" name="biz_colonia" data-init-val="$b_colonia">
                            $colonia_options
                        </select>
                        <label>Colonia / Localidad</label>
                    </div>
                </div>
            </div>

            <hr class="my-5 border-primary border-opacity-25">

            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-hospital me-2"></i>Padrón Oficial (CLUES)</h5>
            <p class="text-muted small">Vincular tu clínica a un establecimiento de salud oficial permite autocompletar servicios, horarios y validaciones legales.</p>
            
            <div class="row g-3">
                <div class="col-12" id="clues_container" style="display:none;">
                    <div class="form-floating">
                        <input type="hidden" id="current_clues" value="$b_clues">
                        <select class="form-select border-primary" id="biz_clues" name="biz_clues" style="background-color: #f0f7ff;">
                            <option value="">Seleccione Establecimiento Oficial (Opcional)</option>
                        </select>
                        <label class="text-primary fw-bold"><i class="bi bi-hospital me-1"></i>Establecimiento Oficial (CLUES)</label>
                    </div>
                </div>
                
                <div class="col-12" id="clues_no_results">
                    <div class="alert alert-light border shadow-sm rounded-4 text-center p-4">
                        <i class="bi bi-info-circle text-muted fs-3 mb-2 d-block"></i>
                        <p class="mb-0 text-muted">Ingresa un Código Postal válido arriba para buscar establecimientos en tu zona.</p>
                    </div>
                </div>

                <div class="col-12" id="clues_details_container" style="display:none;">
                    <div class="row g-3">
                        <div class="col-md-6">
                            <div class="p-3 rounded-4 bg-white border border-primary border-opacity-10 h-100 shadow-sm">
                                <h6 class="fw-bold text-primary mb-3"><i class="bi bi-heart-pulse-fill me-2"></i>Servicios Oficiales</h6>
                                <div id="clues_servicios_list" style="max-height: 200px; overflow-y: auto; font-size: 0.85rem;"></div>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="p-3 rounded-4 bg-white border border-primary border-opacity-10 h-100 shadow-sm">
                                <h6 class="fw-bold text-primary mb-3"><i class="bi bi-clock-fill me-2"></i>Horario Oficial</h6>
                                <div id="clues_horarios_list" style="max-height: 200px; overflow-y: auto; font-size: 0.85rem;"></div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <hr class="my-5 border-primary border-opacity-25">

            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-building me-2"></i>Información Comercial</h5>
            <div class="row g-3">
                <div class="col-md-8">
                    <div class="form-floating">
                        <input type="text" class="form-control" id="biz_nombre" name="biz_nombre" value="$b_nombre" placeholder="Clinica">
                        <label>Nombre Comercial de la Cl&iacute;nica</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="text" class="form-control" id="biz_rfc" name="biz_rfc" value="$b_rfc" placeholder="RFC">
                        <label>RFC</label>
                    </div>
                </div>
                <div class="col-12">
                    <div class="form-floating">
                        <input type="text" class="form-control" id="biz_razon" name="biz_razon" value="$b_razon" placeholder="Razon">
                        <label>Raz&oacute;n Social</label>
                    </div>
                </div>
                <div class="col-12">
                    <div class="form-floating">
                        <textarea class="form-control" id="biz_dir" name="biz_dir" style="height: 100px;">$b_dir</textarea>
                        <label>Direcci&oacute;n Completa</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <input type="text" class="form-control bg-light" id="biz_lat" name="biz_lat" value="$b_lat" placeholder="Latitud" readonly>
                        <label><i class="bi bi-geo-alt-fill text-danger me-1"></i>Latitud</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating">
                        <input type="text" class="form-control bg-light" id="biz_lng" name="biz_lng" value="$b_lng" placeholder="Longitud" readonly>
                        <label><i class="bi bi-geo-alt-fill text-danger me-1"></i>Longitud</label>
                    </div>
                </div>
                <div class="col-md-5">
                    <div class="form-floating">
                        <input type="tel" class="form-control" id="biz_tel" name="biz_tel" value="$b_tel" placeholder="Tel">
                        <label>Tel&eacute;fono</label>
                    </div>
                </div>
                <div class="col-md-3" id="div_biz_ext" style="@{[ $b_ext ne '0' && $b_ext ne '' ? '' : 'display:none;' ]}">
                    <div class="form-floating">
                        <input type="text" class="form-control" id="biz_ext" name="biz_ext" value="$b_ext" placeholder="Ext">
                        <label>Extensi&oacute;n</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="email" class="form-control" id="biz_email" name="biz_email" value="$b_email" placeholder="Email">
                        <label>Email Corporativo</label>
                    </div>
                </div>
            </div>

            <div class="d-flex justify-content-between mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>

        <!-- PANEL 2: ESPECIALISTA SUSCRIPCION / LICENCIA -->
        <div class="wizard-panel" id="step-panel-2">
            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-award me-2"></i>Licenciamiento y Suscripción</h5>
            
            <div class="d-flex gap-2 mb-4">
                @{[ $bs->{tipo} eq 'Matriz' ? '<span class="badge rounded-pill px-3 py-2 bg-primary bg-opacity-10 text-primary border border-primary border-opacity-25 fw-bold"><i class="bi bi-diagram-3-fill me-1"></i> MATRIZ</span>' : '<span class="badge rounded-pill px-3 py-2 bg-secondary bg-opacity-10 text-secondary border border-secondary border-opacity-25 fw-bold"><i class="bi bi-geo-fill me-1"></i> SUCURSAL</span>' ]}
                @{[ $bs->{activo} ? '<span class="badge rounded-pill px-3 py-2 bg-success bg-opacity-10 text-success border border-success border-opacity-25 fw-bold"><i class="bi bi-shield-check me-1"></i> LICENCIA ACTIVA</span>' : '<span class="badge rounded-pill px-3 py-2 bg-danger bg-opacity-10 text-danger border border-danger border-opacity-25 fw-bold"><i class="bi bi-exclamation-octagon-fill me-1"></i> SUSCRIPCIÓN VENCIDA</span>' ]}
            </div>
HTML

        if ($bs->{inicio}) {
            print <<HTML;
            <div class="p-4 rounded-4 bg-light border border-primary border-opacity-10 shadow-sm">
                <div class="row align-items-center">
                    <div class="col-md-7">
                        <h6 class="fw-bold mb-1"><i class="bi bi-calendar-check me-2 text-primary"></i>Periodo de Suscripci&oacute;n</h6>
                        <p class="small text-muted mb-0">Vigencia contratada para el uso de la plataforma Diamond.</p>
                    </div>
                    <div class="col-md-5 text-md-end mt-3 mt-md-0">
                        <div class="d-flex justify-content-md-end gap-3">
                            <div class="text-center">
                                <div class="small text-muted fw-bold" style="font-size:0.65rem;">INICIO</div>
                                <div class="fw-black text-dark">$bs->{inicio}</div>
                            </div>
                            <div class="vr"></div>
                            <div class="text-center">
                                <div class="small text-muted fw-bold" style="font-size:0.65rem;">VENCIMIENTO</div>
                                <div class="fw-black text-primary">$bs->{fin}</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
HTML
        }

        print <<HTML;
            <div class="d-flex justify-content-between mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>

        <!-- PANEL 3: ESPECIALISTA SEGURIDAD -->
        <div class="wizard-panel" id="step-panel-3">
            <h5 class="fw-bold mb-4 text-primary"><i class="bi bi-shield-lock-fill me-2"></i>Seguridad de Cuenta</h5>
            <div class="row g-3">
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="password" class="form-control border-warning" id="clave_actual" name="clave_actual" placeholder="Clave Actual" required>
                        <label for="clave_actual">Contraseña Actual *</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="password" class="form-control" id="clave_nueva" name="clave_nueva" placeholder="Nueva Clave">
                        <label for="clave_nueva">Nueva Contraseña (Opcional)</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating">
                        <input type="password" class="form-control" id="clave_confirmar" name="clave_confirmar" placeholder="Confirmar">
                        <label for="clave_confirmar">Confirmar Nueva Contraseña</label>
                    </div>
                </div>
            </div>
            <div class="d-flex justify-content-start mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
            </div>
        </div>
HTML
    }
    
    # Render the save button fixed at the bottom outside the panels
    print <<HTML;
        
        <div class="mt-4 text-center">
            <span class="text-muted small">Todos los cambios se guardan globalmente.</span>
        </div>
    </form>
</div> <!-- /wizard-container -->

<script src="../js/perfil_flow.js"></script>
<script>
\$(document).ready(function() {
    // 1. Inicializar Wizard (Total de pasos depende del rol)
    let totalPasos = 4;
    PerfilWizardController.init(totalPasos);

    // 2. Control del Formulario
    \$('#perfilForm').on('submit', function(e) {
        e.preventDefault(); 
        const alertContainer = \$('#alertContainer');
        const guardarBtn = \$('#guardarBtn');
        
        guardarBtn.attr('disabled', true).html('<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Sincronizando...');

        \$.ajax({
            type: 'POST',
            url: '../api/update_perfil.pl',
            data: \$(this).serialize(), 
            dataType: 'json',
            success: function(r) {
                if (r.success) {
                    alertContainer.html('<div class="alert alert-success shadow-sm border-0 rounded-4"><i class="bi bi-check-circle-fill me-2"></i>' + r.message + '</div>');
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                    setTimeout(() => { window.location.reload(); }, 1500); 
                } else {
                    alertContainer.html('<div class="alert alert-danger shadow-sm border-0 rounded-4"><strong>Error:</strong> ' + r.message + '</div>');
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                }
            },
            error: function() {
                alertContainer.html('<div class="alert alert-danger shadow-sm border-0 rounded-4">Fallo en la comunicación con el servidor.</div>');
                window.scrollTo({ top: 0, behavior: 'smooth' });
            },
            complete: function() {
                guardarBtn.attr('disabled', false).html('<i class="bi bi-cloud-upload-fill me-2"></i>Actualizar Perfil');
            }
        });
    });

    // 3. Lógica de Databinding Unidireccional por CP
    function resolveLocation(cp, autoLoadClues) {
        let current_colonia = \$('#biz_colonia').val();
        let current_colonia_data = \$('#biz_colonia').attr('data-init-val');
        if (!current_colonia && current_colonia_data) {
            current_colonia = current_colonia_data;
        }

        \$('#biz_entidad').val('Buscando...');
        \$('#biz_municipio').val('Buscando...');
        \$('#biz_colonia').html('<option value="">Cargando opciones...</option>');
        
        \$.ajax({
            type: 'GET',
            url: '../api/get_location.pl',
            data: { cp: cp },
            dataType: 'json',
            success: function(r) {
                if(r.success) {
                    \$('#biz_entidad').val(r.entidad);
                    \$('#biz_municipio').val(r.municipio);
                    
                    let options = '<option value="">Seleccione una localidad...</option>';
                    r.localidades.forEach(function(loc) {
                        let sel = (loc === current_colonia) ? 'selected' : '';
                        options += '<option value="' + loc + '" '+sel+'>' + loc + '</option>';
                    });
                    \$('#biz_colonia').html(options);

                    // Poblar CLUES si existen
                    if (r.establecimientos && r.establecimientos.length > 0) {
                        \$('#clues_no_results').hide();
                        \$('#clues_container').slideDown();
                        let current_clues = \$('#current_clues').val();
                        let cluesOptions = '<option value="">Ninguno (Opcional)</option>';
                        r.establecimientos.forEach(function(est) {
                            let sel = (est.id === current_clues) ? 'selected' : '';
                            cluesOptions += '<option value="' + est.id + '" '+sel+'>' + est.nombre + ' (' + est.id + ')</option>';
                        });
                        \$('#biz_clues').html(cluesOptions);
                        
                        if (autoLoadClues && current_clues) {
                            loadCluesDetails(current_clues, false);
                        }
                    } else {
                        \$('#clues_container').slideUp();
                        \$('#biz_clues').html('<option value="">Ninguno (Opcional)</option>');
                        \$('#clues_details_container').slideUp();
                        \$('#clues_no_results').show();
                    }
                } else {
                    \$('#biz_entidad').val('');
                    \$('#biz_municipio').val('');
                    \$('#biz_colonia').html('<option value="">' + r.message + '</option>');
                    \$('#clues_container').slideUp();
                    \$('#clues_no_results').show();
                }
            },
            error: function() {
                \$('#biz_entidad').val('');
                \$('#biz_municipio').val('');
                \$('#biz_colonia').html('<option value="">Error de conexión</option>');
                \$('#clues_container').slideUp();
                \$('#clues_no_results').show();
            }
        });
    }

    \$('#biz_cp').on('input', function() {
        let cp = \$(this).val().replace(/\\D/g, '');
        \$(this).val(cp);
        if(cp.length === 5) {
            resolveLocation(cp, false);
        } else {
            \$('#biz_entidad').val('');
            \$('#biz_municipio').val('');
            \$('#biz_colonia').html('<option value="">Ingrese su C.P. para cargar localidades</option>');
            \$('#clues_container').slideUp();
            \$('#clues_details_container').slideUp();
            \$('#clues_no_results').show();
        }
    });

    // Cargar detalles del CLUES
    function loadCluesDetails(clues_id, overwriteName) {
        if (!clues_id) {
            \$('#clues_details_container').slideUp();
            return;
        }
        
        \$('#clues_details_container').slideDown();
        \$('#clues_servicios_list').html('<div class="text-center p-3"><span class="spinner-border spinner-border-sm text-primary"></span></div>');
        \$('#clues_horarios_list').html('<div class="text-center p-3"><span class="spinner-border spinner-border-sm text-primary"></span></div>');
        
        \$.ajax({
            type: 'GET',
            url: '../api/get_clues_details.pl',
            data: { clues: clues_id },
            dataType: 'json',
            success: function(r) {
                if(r.success) {
                    if (overwriteName && r.nombre) {
                        \$('#biz_nombre').val(r.nombre);
                    }
                    if (overwriteName && r.comercial) {
                        \$('#biz_razon').val(r.comercial);
                    }
                    if (overwriteName && r.rfc_clues) {
                        \$('#biz_rfc').val(r.rfc_clues);
                    }
                    if (overwriteName && r.telefono) {
                        \$('#biz_tel').val(r.telefono);
                    }
                    if (overwriteName) {
                        if (r.extension && r.extension !== '0' && r.extension.trim() !== '') {
                            \$('#div_biz_ext').show();
                            \$('#biz_ext').val(r.extension);
                        } else {
                            \$('#div_biz_ext').hide();
                            \$('#biz_ext').val('0');
                        }
                    }
                    if (overwriteName) {
                        let dir_parts = [];
                        if (r.vialidad) dir_parts.push(r.vialidad);
                        if (r.num_ext) dir_parts.push(r.num_ext);
                        if (r.num_int) dir_parts.push('Int. ' + r.num_int);
                        if (dir_parts.length > 0) {
                            \$('#biz_dir').val(dir_parts.join(' '));
                        }
                    }
                    if (overwriteName && r.latitud) {
                        \$('#biz_lat').val(r.latitud);
                    }
                    if (overwriteName && r.longitud) {
                        \$('#biz_lng').val(r.longitud);
                    }

                    // Renderizar Servicios
                    let s_html = '<ul class="list-group list-group-flush">';
                    if(r.servicios.length > 0) {
                        r.servicios.forEach(s => {
                            s_html += '<li class="list-group-item px-0 py-1 border-0 border-bottom border-light"><i class="bi bi-check2-circle text-success me-2"></i><strong>' + s.servicio + '</strong><br><span class="text-muted" style="font-size:0.75rem;">' + s.area + ' | ' + s.ubicacion + '</span></li>';
                        });
                    } else {
                        s_html += '<li class="list-group-item px-0 py-1 border-0 text-muted">No hay servicios específicos listados.</li>';
                    }
                    s_html += '</ul>';
                    \$('#clues_servicios_list').html(s_html);

                    // Renderizar Horarios
                    let h_html = '<table class="table table-sm table-borderless mb-0"><tbody>';
                    if(r.horarios.length > 0) {
                        r.horarios.forEach(h => {
                            let dias = [];
                            if(h.lunes === 'SI') dias.push('L');
                            if(h.martes === 'SI') dias.push('M');
                            if(h.miercoles === 'SI') dias.push('Mi');
                            if(h.jueves === 'SI') dias.push('J');
                            if(h.viernes === 'SI') dias.push('V');
                            if(h.sabado === 'SI') dias.push('S');
                            if(h.domingo === 'SI') dias.push('D');
                            h_html += '<tr><td><span class="badge bg-light text-dark border">' + dias.join(', ') + '</span></td><td class="text-end fw-bold text-primary">' + h.inicio + ' - ' + h.fin + '</td></tr>';
                        });
                    } else {
                        h_html += '<tr><td class="text-muted">Horarios no especificados en el padrón oficial.</td></tr>';
                    }
                    h_html += '</tbody></table>';
                    \$('#clues_horarios_list').html(h_html);

                } else {
                    \$('#clues_servicios_list').html('<span class="text-danger">Error: ' + r.message + '</span>');
                    \$('#clues_horarios_list').html('');
                }
            },
            error: function() {
                \$('#clues_servicios_list').html('<span class="text-danger">Fallo de conexión.</span>');
                \$('#clues_horarios_list').html('');
            }
        });
    }

    \$('#biz_clues').on('change', function() {
        let val = \$(this).val();
        \$('#current_clues').val(val);
        if (val) {
            loadCluesDetails(val, true); // True para sobreescribir el nombre
        } else {
            \$('#clues_details_container').slideUp();
        }
    });

    // Init load si hay CP
    if (typeof \$('#biz_cp').val() !== 'undefined') {
        let init_cp = \$('#biz_cp').val();
        if(init_cp && init_cp.length === 5) {
            resolveLocation(init_cp, true);
        }
    }

    // DATA Catálogo de Formación
    const catFormacion = [$js_formaciones_str];

    function poblarFormaciones(agrupacionFiltro) {
        let dl = document.getElementById('datalist_formacion');
        if (!dl) return;
        
        let html = '';
        for (let i = 0; i < catFormacion.length; i++) {
            let f = catFormacion[i];
            if (agrupacionFiltro === '' || f.a === agrupacionFiltro) {
                html += '<option value="' + f.f + '" data-clave="' + f.c + '"></option>';
            }
        }
        dl.innerHTML = html;
    }

    // Al cambiar la rama
    \$('#biz_agrupacion').on('change', function() {
        let rama = \$(this).val();
        poblarFormaciones(rama);
        \$('#biz_formacion_text').val('');
        \$('#biz_formacion').val('');
    });

    // Actualizar Formacion Clave mediante Autocomplete
    \$('#biz_formacion_text').on('input change', function() {
        let val = \$(this).val();
        let selectedOption = \$('#datalist_formacion option').filter(function() {
            return this.value === val;
        });

        if (selectedOption.length > 0) {
            let clave = selectedOption.attr('data-clave') || '';
            \$('#biz_formacion').val(clave);
        } else {
            \$('#biz_formacion').val('');
        }
    });

    // Inicializar Datalist al cargar si hay una rama
    if (\$('#biz_agrupacion').length > 0) {
        poblarFormaciones(\$('#biz_agrupacion').val());
    }
});
</script>
HTML
}
1;
