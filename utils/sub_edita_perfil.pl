#!/usr/bin/perl
# --- MedentIA Diamond Edition v4.6.0: Role-Based User Profile with Operative CLUES for Org Admin ---
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
    my $naturaleza_juridica = $args{naturaleza_juridica} // 'Privado';

    my $clave_formacion = $p->{clave_formacion} // '';
    my $clave_nacionalidad = $p->{clave_nacionalidad} || 'MEX';
    my $clave_religion = $p->{clave_religion} || '110103';
    my $cedula_especialidad = $p->{cedula_especialidad} // '';
    my $avatar_url = $p->{avatar_url} // '';
    my $firma_url = $p->{firma_url} // '';

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
    my $is_medico   = ($role eq 'Medico') ? 1 : 0;
    my $is_admin_org= ($role =~ /Administrador Organizacion|Administrador Global/i) ? 1 : 0;

    # Determinar badge de rol y avatar inicial
    my $role_badge_class = 'bg-primary-subtle text-primary border-primary-subtle';
    my $role_title = $role;
    if ($is_medico) {
        $role_badge_class = 'bg-primary text-white border-0';
        $role_title = 'M&eacute;dico Especialista';
    } elsif ($is_admin_org) {
        $role_badge_class = 'bg-navy text-white border-0';
        $role_title = 'Director de Organizaci&oacute;n';
    } elsif ($role =~ /Ejecutivo/i) {
        $role_badge_class = 'bg-success text-white border-0';
        $role_title = 'Ejecutivo de Ventas';
    } elsif ($role =~ /Soporte/i) {
        $role_badge_class = 'bg-warning text-dark border-0';
        $role_title = 'Soporte T&eacute;cnico';
    } elsif ($is_paciente) {
        $role_badge_class = 'bg-info-subtle text-info border-info-subtle';
        $role_title = 'Paciente';
    }

    # Avatar URL o inicial
    my $avatar_src = ($avatar_url ne '') ? "../$avatar_url" : '';
    my $inicial = uc(substr($u_nombre, 0, 1) || 'U');

print <<HTML;
<link rel="stylesheet" href="../css/perfil_flow.css">
<style>
    .btn-aura-save {
        background: linear-gradient(135deg, #0d1e3d 0%, #3b82f6 100%);
        border: none; border-radius: 1rem; padding: 1rem 2rem;
        font-weight: 800; letter-spacing: 0.5px; transition: 0.3s;
    }
    .btn-aura-save:hover { transform: translateY(-2px); box-shadow: 0 8px 20px rgba(59, 130, 246, 0.3); }
    .profile-avatar-circle {
        width: 90px; height: 90px; border-radius: 50%;
        background: linear-gradient(135deg, #0A2A66 0%, #19B7A5 100%);
        color: #fff; font-size: 2.5rem; font-weight: 900;
        display: flex; align-items: center; justify-content: center;
        overflow: hidden; position: relative; border: 3px solid #ffffff;
        box-shadow: 0 8px 25px rgba(10, 42, 102, 0.15);
    }
    .profile-avatar-circle img {
        width: 100%; height: 100%; object-fit: cover;
    }
    .avatar-upload-overlay {
        position: absolute; bottom: 0; left: 0; right: 0; background: rgba(10,42,102,0.75);
        color: #fff; text-align: center; font-size: 0.7rem; padding: 3px 0; cursor: pointer;
        transition: all 0.2s ease; display: none;
    }
    .profile-avatar-circle:hover .avatar-upload-overlay { display: block; }
    .signature-box-preview {
        height: 120px; border: 2px dashed #cbd5e1; border-radius: 1rem;
        background: #f8fafc; display: flex; align-items: center; justify-content: center;
        cursor: pointer; transition: all 0.3s ease; position: relative; overflow: hidden;
    }
    .signature-box-preview:hover {
        border-color: var(--md-teal-clinical); background: #f0fdf4;
    }
    .signature-box-preview img {
        max-height: 100px; max-width: 100%; object-fit: contain;
    }
</style>

<div class="wizard-container animate__animated animate__fadeIn">
    <!-- Encabezado Perfil MedentIA Diamond -->
    <div class="card-medentia-aura p-4 p-md-5 mb-4 border-0 shadow-sm" style="border-radius: 1.5rem; background: #ffffff;">
        <div class="d-flex align-items-center justify-content-between flex-wrap gap-4">
            <div class="d-flex align-items-center gap-4">
                <div class="profile-avatar-circle" onclick="document.getElementById('avatar_file').click();" title="Haz clic para cambiar tu foto de perfil">
                    @{[ $avatar_src ne '' ? qq(<img id="avatar_preview_header" src="$avatar_src" alt="Avatar">) : qq(<span id="avatar_initial_header">$inicial</span><img id="avatar_preview_header" src="" alt="Avatar" class="d-none">) ]}
                    <div class="avatar-upload-overlay"><i class="bi bi-camera-fill"></i> Cambiar</div>
                </div>
                <div>
                    <div class="d-flex align-items-center gap-2 flex-wrap">
                        <h2 class="fw-black mb-0" style="color: var(--md-blue-deep);">$u_nombre</h2>
                        <span class="badge rounded-pill px-3 py-1 small fw-bold $role_badge_class">$role_title</span>
                    </div>
                    <p class="text-muted small fw-bold mb-0 mt-1"><i class="bi bi-envelope-fill me-1" style="color: var(--md-teal-clinical);"></i>$u_correo</p>
                </div>
            </div>
            <div>
                <button type="submit" form="perfilForm" class="btn btn-primary btn-aura-save py-2 px-4 shadow-sm" id="guardarBtn">
                    <i class="bi bi-cloud-upload-fill me-2"></i>Actualizar Perfil
                </button>
            </div>
        </div>
    </div>
HTML

    # --- STEPPER NAVEGACIÓN BASADA EN ROLES (RBAC) ---
    if ($is_paciente) {
        print <<HTML;
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
    } elsif ($is_medico) {
        print <<HTML;
    <div class="wizard-stepper">
        <div class="wizard-step active" onclick="PerfilWizardController.jumpToStep(0)">
            <div class="wizard-step-icon"><i class="bi bi-person-badge"></i></div>
            <div class="wizard-step-label">Identidad</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(1)">
            <div class="wizard-step-icon"><i class="bi bi-patch-check-fill"></i></div>
            <div class="wizard-step-label">Credenciales M&eacute;dicas</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(2)">
            <div class="wizard-step-icon"><i class="bi bi-shield-lock"></i></div>
            <div class="wizard-step-label">Seguridad</div>
        </div>
    </div>
HTML
    } elsif ($is_admin_org) {
        print <<HTML;
    <div class="wizard-stepper">
        <div class="wizard-step active" onclick="PerfilWizardController.jumpToStep(0)">
            <div class="wizard-step-icon"><i class="bi bi-person-badge"></i></div>
            <div class="wizard-step-label">Identidad</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(1)">
            <div class="wizard-step-icon"><i class="bi bi-hospital"></i></div>
            <div class="wizard-step-label">CLUES & Domicilio</div>
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
    } else {
        print <<HTML;
    <div class="wizard-stepper">
        <div class="wizard-step active" onclick="PerfilWizardController.jumpToStep(0)">
            <div class="wizard-step-icon"><i class="bi bi-person-badge"></i></div>
            <div class="wizard-step-label">Identidad</div>
        </div>
        <div class="wizard-step" onclick="PerfilWizardController.jumpToStep(1)">
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

    <form id="perfilForm" enctype="multipart/form-data">
        <input type="hidden" name="user_role" value="$role">
        <input type="file" id="avatar_file" name="avatar_file" accept="image/*" class="d-none" onchange="previewAvatarImage(this)">
        <input type="file" id="firma_file" name="firma_file" accept="image/*" class="d-none" onchange="previewFirmaImage(this)">

        <div id="alertContainer"></div>
        <div class="alert alert-warning border-0 shadow-sm rounded-4 d-flex align-items-center justify-content-between mb-3 py-2 px-3 animate__animated animate__fadeIn">
            <span class="small fw-semibold text-dark"><i class="bi bi-shield-fill-exclamation text-warning me-2"></i>Para confirmar cualquier actualización de tu perfil es obligatorio ingresar tu contraseña actual.</span>
            <button type="button" class="btn btn-warning btn-sm rounded-pill fw-bold text-dark px-3" onclick="PerfilWizardController.jumpToStep(@{[ $is_paciente || $is_admin_org ? 3 : ($is_medico ? 2 : 1) ]}); setTimeout(function(){ \$('#clave_actual').focus(); }, 300);">
                <i class="bi bi-key-fill me-1"></i>Ir a Contraseña
            </button>
        </div>

        <!-- PANEL 0: IDENTIDAD (Común para todos los usuarios) -->
        <div class="wizard-panel active" id="step-panel-0">
            <h5 class="fw-bold mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-person-badge-fill me-2" style="color: var(--md-teal-clinical);"></i>Identidad de Acceso</h5>
            
            <div class="row g-3">
                <div class="col-md-3 text-center">
                    <div class="p-3 border rounded-4 bg-light text-center">
                        <label class="small fw-bold text-muted mb-2 d-block">Fotograf&iacute;a / Avatar</label>
                        <div class="profile-avatar-circle mx-auto my-2" onclick="document.getElementById('avatar_file').click();" style="width: 100px; height: 100px; cursor: pointer;">
                            @{[ $avatar_src ne '' ? qq(<img id="avatar_preview_panel" src="$avatar_src" alt="Avatar">) : qq(<span id="avatar_initial_panel">$inicial</span><img id="avatar_preview_panel" src="" alt="Avatar" class="d-none">) ]}
                            <div class="avatar-upload-overlay"><i class="bi bi-camera-fill"></i> Cambiar</div>
                        </div>
                        <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-3 py-1 mt-2 fw-bold" onclick="document.getElementById('avatar_file').click();">
                            <i class="bi bi-upload me-1"></i> Subir Foto
                        </button>
                    </div>
                </div>
                <div class="col-md-9">
                    <div class="row g-3">
                        <div class="col-md-6">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" class="form-control fw-bold" id="nombre_completo" name="nombre_completo" placeholder="Nombre" value="$u_nombre" required>
                                <label for="nombre_completo">Nombre Completo *</label>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-floating diamond-input-armor">
                                <input type="email" class="form-control bg-light fw-bold text-muted" id="correo_login" value="$u_correo" readonly>
                                <label for="correo_login">Correo Electr&oacute;nico Institucional</label>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" class="form-control bg-light fw-bold text-muted" value="$role_title" readonly>
                                <label>Rol de Usuario en la Plataforma</label>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-floating diamond-input-armor">
                                <input type="text" class="form-control bg-light fw-bold text-muted" value="$b->{nombre}" readonly>
                                <label>Cl&iacute;nica / Organizaci&oacute;n Asignada</label>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="text-end mt-4">
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente Secci&oacute;n <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
HTML

    # --- PANEL PARA ROL MÉDICO: CREDENCIALES MÉDICAS Y FIRMA ---
    if ($is_medico) {
        my $espe_nombre = $u->{espe_nombre} || 'General / Ninguna';
        my $subespe_nombre = $u->{subespe_nombre} || 'General / Ninguna';
        my $u_cedula = $u->{cedula} // '';
        my $firma_src = ($firma_url ne '') ? "../$firma_url" : '';

        print <<HTML;
        <!-- PANEL 1: CREDENCIALES MÉDICAS Y FIRMA (Rol Médico Exclusivo) -->
        <div class="wizard-panel" id="step-panel-1">
            <h5 class="fw-bold mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-patch-check-fill me-2" style="color: var(--md-teal-clinical);"></i>Credenciales M&eacute;dicas y Firma Digital</h5>
            
            <div class="row g-3">
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control fw-bold border-primary" id="biz_cedula" name="biz_cedula" placeholder="Cédula Profesional" value="$u_cedula">
                        <label for="biz_cedula"><i class="bi bi-card-heading text-primary me-1"></i>C&eacute;dula Profesional Principal *</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control fw-bold border-primary" id="biz_cedula_espe" name="biz_cedula_espe" placeholder="Cédula Especialidad" value="$cedula_especialidad">
                        <label for="biz_cedula_espe"><i class="bi bi-award-fill text-primary me-1"></i>C&eacute;dula de Especialidad (Opcional)</label>
                    </div>
                </div>

                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control bg-light fw-bold text-primary" value="$espe_nombre" readonly>
                        <label><i class="bi bi-check-circle-fill text-primary me-1"></i>Especialidad Asignada (Solo Lectura)</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control bg-light fw-bold text-info" value="$subespe_nombre" readonly>
                        <label><i class="bi bi-award-fill text-info me-1"></i>Sub-Especialidad (Solo Lectura)</label>
                    </div>
                </div>

                <div class="col-md-5">
                    <div class="form-floating diamond-input-armor">
                        <select class="form-select fw-bold" id="biz_agrupacion">
                            $agrupaciones_options
                        </select>
                        <label>Rama / Agrupaci&oacute;n Acad&eacute;mica</label>
                    </div>
                </div>
                <div class="col-md-7">
                    <div class="form-floating diamond-input-armor">
                        <input class="form-control fw-bold" list="datalist_formacion" id="biz_formacion_text" value="$formacion_text_actual" placeholder="Escriba para buscar..." autocomplete="off">
                        <datalist id="datalist_formacion">
                            <!-- JS Inject -->
                        </datalist>
                        <input type="hidden" id="biz_formacion" name="biz_formacion" value="$clave_formacion">
                        <label>Formaci&oacute;n Acad&eacute;mica Oficial <i class="bi bi-search ms-1 text-muted"></i></label>
                    </div>
                </div>

                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <select class="form-select fw-bold" id="biz_nacionalidad" name="biz_nacionalidad">
                            $nacionalidad_options
                        </select>
                        <label for="biz_nacionalidad">Nacionalidad</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <select class="form-select fw-bold" id="biz_religion" name="biz_religion">
                            $religion_options
                        </select>
                        <label for="biz_religion">Religi&oacute;n / Credo (Bio&eacute;tica)</label>
                    </div>
                </div>

                <!-- CARGA DE FIRMA DIGITALIZADA -->
                <div class="col-12 mt-3">
                    <div class="p-4 border rounded-4 bg-white shadow-sm">
                        <h6 class="fw-bold mb-2" style="color: var(--md-blue-deep);"><i class="bi bi-pen-fill me-2" style="color: var(--md-teal-clinical);"></i>Firma Aut&oacute;grafa Digitalizada (NOM-024 / NOM-004)</h6>
                        <p class="text-muted small mb-3">Sube tu firma manuscrita transparente (PNG/JPG). Esta firma se estampar&aacute; autom&aacute;ticamente en tus recetas m&eacute;dicas y notas de evoluci&oacute;n.</p>
                        
                        <div class="signature-box-preview" onclick="document.getElementById('firma_file').click();">
                            @{[ $firma_src ne '' ? qq(<img id="firma_preview_img" src="$firma_src" alt="Firma Digital">) : qq(<div id="firma_placeholder" class="text-center text-muted"><i class="bi bi-cloud-arrow-up fs-2 d-block mb-1 text-primary"></i><span class="fw-bold small">Haz clic o arrastra tu imagen de firma aqu&iacute;</span></div><img id="firma_preview_img" src="" alt="Firma Digital" class="d-none">) ]}
                        </div>
                    </div>
                </div>
            </div>

            <div class="d-flex justify-content-between mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente Secci&oacute;n <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
HTML
    }

    # --- PANELS PARA ADMINISTRADOR DE ORGANIZACIÓN: TAB 1 (CLUES OPERATIVO) Y TAB 2 (SUSCRIPCIÓN) ---
    if ($is_admin_org) {
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
        <!-- PANEL 1: CLUES Y DOMICILIO INSTITUCIONAL OPERATIVO (Administrador Organización Exclusivo) -->
        <div class="wizard-panel" id="step-panel-1">
            <h5 class="fw-bold mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-geo-alt-fill me-2" style="color: var(--md-teal-clinical);"></i>Ubicaci&oacute;n y Domicilio Oficial</h5>
            <div class="row g-3">
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control fw-bold" id="biz_cp" name="biz_cp" value="$b_cp" placeholder="C.P." maxlength="5">
                        <label>C&oacute;digo Postal *</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control bg-light fw-bold" id="biz_entidad" name="biz_entidad" value="$b_entidad" placeholder="Entidad" readonly>
                        <label>Entidad Federativa</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control bg-light fw-bold" id="biz_municipio" name="biz_municipio" value="$b_mnpio" placeholder="Municipio" readonly>
                        <label>Municipio o Alcald&iacute;a</label>
                    </div>
                </div>
                <div class="col-12">
                    <div class="form-floating diamond-input-armor">
                        <select class="form-select fw-bold" id="biz_colonia" name="biz_colonia" data-init-val="$b_colonia">
                            $colonia_options
                        </select>
                        <label>Colonia / Localidad *</label>
                    </div>
                </div>
            </div>

            <hr class="my-4 border-secondary border-opacity-25">

            <h5 class="fw-bold mb-3" style="color: var(--md-blue-deep);"><i class="bi bi-hospital me-2" style="color: var(--md-teal-clinical);"></i>Padr&oacute;n Oficial de Establecimientos (CLUES)</h5>
            <p class="text-muted small mb-3">Vincular tu cl&iacute;nica a un establecimiento de salud oficial permite autocompletar servicios, horarios y validaciones legales.</p>
            
            <div class="row g-3">
                <div class="col-12" id="clues_container" style="display:none;">
                    <div class="form-floating diamond-input-armor">
                        <input type="hidden" id="current_clues" value="$b_clues">
                        <select class="form-select border-primary fw-bold" id="biz_clues" name="biz_clues" style="background-color: #f0f7ff;">
                            <option value="">Seleccione Establecimiento Oficial (Opcional)</option>
                        </select>
                        <label class="text-primary fw-bold"><i class="bi bi-hospital me-1"></i>Establecimiento Oficial (CLUES)</label>
                    </div>
                </div>
                
                <div class="col-12" id="clues_no_results">
                    <div class="alert alert-light border shadow-sm rounded-4 text-center p-4">
                        <i class="bi bi-info-circle text-muted fs-3 mb-2 d-block"></i>
                        <p class="mb-0 text-muted">Ingresa un C&oacute;digo Postal v&aacute;lido arriba para buscar establecimientos en tu zona.</p>
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

            <hr class="my-4 border-secondary border-opacity-25">

            <h5 class="fw-bold mb-3" style="color: var(--md-blue-deep);"><i class="bi bi-building me-2" style="color: var(--md-teal-clinical);"></i>Informaci&oacute;n Comercial e Institucional</h5>
            <div class="row g-3">
                <div class="col-md-8">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control fw-bold" id="biz_nombre" name="biz_nombre" value="$b_nombre" placeholder="Clinica">
                        <label>Nombre Comercial de la Cl&iacute;nica *</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control fw-bold" id="biz_rfc" name="biz_rfc" value="$b_rfc" placeholder="RFC">
                        <label>RFC Institucional</label>
                    </div>
                </div>
                <div class="col-12">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control fw-bold" id="biz_razon" name="biz_razon" value="$b_razon" placeholder="Razon">
                        <label>Raz&oacute;n Social</label>
                    </div>
                </div>
                <div class="col-12">
                    <div class="form-floating diamond-input-armor">
                        <textarea class="form-control fw-bold" id="biz_dir" name="biz_dir" style="height: 100px;">$b_dir</textarea>
                        <label>Direcci&oacute;n Completa</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control bg-light fw-bold" id="biz_lat" name="biz_lat" value="$b_lat" placeholder="Latitud" readonly>
                        <label><i class="bi bi-geo-alt-fill text-danger me-1"></i>Latitud GPS</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control bg-light fw-bold" id="biz_lng" name="biz_lng" value="$b_lng" placeholder="Longitud" readonly>
                        <label><i class="bi bi-geo-alt-fill text-danger me-1"></i>Longitud GPS</label>
                    </div>
                </div>
                <div class="col-md-5">
                    <div class="form-floating diamond-input-armor">
                        <input type="tel" class="form-control fw-bold" id="biz_tel" name="biz_tel" value="$b_tel" placeholder="Tel">
                        <label>Tel&eacute;fono de Contacto</label>
                    </div>
                </div>
                <div class="col-md-3" id="div_biz_ext" style="@{[ $b_ext ne '0' && $b_ext ne '' ? '' : 'display:none;' ]}">
                    <div class="form-floating diamond-input-armor">
                        <input type="text" class="form-control fw-bold" id="biz_ext" name="biz_ext" value="$b_ext" placeholder="Ext">
                        <label>Extensi&oacute;n</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="email" class="form-control fw-bold" id="biz_email" name="biz_email" value="$b_email" placeholder="Email">
                        <label>Email Corporativo de la Cl&iacute;nica</label>
                    </div>
                </div>
            </div>

            <div class="d-flex justify-content-between mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente Secci&oacute;n <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>

        <!-- PANEL 2: SUSCRIPCIÓN Y LICENCIAMIENTO (Rol Administrador Organización Exclusivo) -->
        <div class="wizard-panel" id="step-panel-2">
            <h5 class="fw-bold mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-award-fill me-2" style="color: var(--md-teal-clinical);"></i>Licenciamiento y Estado de Suscripci&oacute;n</h5>
            
            <div class="row g-3 mb-4">
                <div class="col-md-6">
                    <div class="p-4 rounded-4 bg-light border shadow-sm">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Organizaci&oacute;n / Cl&iacute;nica</label>
                        <h5 class="fw-bold text-dark mb-0">$b->{nombre}</h5>
                        <p class="small text-muted mb-0">RFC: $b->{rfc} | Razi&oacute;n Social: $b->{razon_social}</p>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="p-4 rounded-4 bg-light border shadow-sm">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Estado del Servicio</label>
                        <div class="d-flex gap-2 align-items-center mt-1">
                            @{[ $bs->{activo} ? '<span class="badge rounded-pill px-3 py-2 bg-success text-white fw-bold"><i class="bi bi-shield-check me-1"></i> LICENCIA ACTIVA</span>' : '<span class="badge rounded-pill px-3 py-2 bg-danger text-white fw-bold"><i class="bi bi-exclamation-octagon-fill me-1"></i> SUSCRIPCIÓN VENCIDA</span>' ]}
                            <span class="badge rounded-pill px-3 py-2 bg-primary-subtle text-primary border border-primary-subtle fw-bold">Naturaleza: $naturaleza_juridica</span>
                        </div>
                    </div>
                </div>
            </div>

            @{[ $bs->{inicio} ? qq(
            <div class="p-4 rounded-4 bg-light border border-primary border-opacity-10 shadow-sm mb-4">
                <div class="row align-items-center">
                    <div class="col-md-7">
                        <h6 class="fw-bold mb-1"><i class="bi bi-calendar-check me-2 text-primary"></i>Periodo de Suscripci&oacute;n Contratado</h6>
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
            ) : '' ]}

            <div class="alert alert-info border-0 shadow-sm rounded-4 p-4 d-flex align-items-center justify-content-between">
                <div>
                    <h6 class="fw-bold mb-1 text-info-emphasis"><i class="bi bi-info-circle-fill me-2"></i>Gesti&oacute;n de Licencias y Facturaci&oacute;n</h6>
                    <p class="small text-muted mb-0">Para solicitar ampliaci&oacute;n de folios m&eacute;dicos, m&oacute;dulos adicionales o cambio de plan de suscripci&oacute;n, contacte a su Ejecutivo de Ventas asignado.</p>
                </div>
            </div>

            <div class="d-flex justify-content-between mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente Secci&oacute;n <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
HTML
    }

    # --- PANELS PARA PACIENTE (SI APLICA) ---
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
                    <div class="form-floating diamond-input-armor"><input type="text" class="form-control" name="p_rfc" value="$p_rfc" placeholder="RFC"><label>RFC</label></div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor"><input type="text" class="form-control" name="p_curp" value="$p_curp" placeholder="CURP"><label>CURP</label></div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor"><input type="tel" class="form-control" name="p_tel" value="$p_tel" placeholder="Tel"><label>Tel&eacute;fono de Contacto</label></div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor"><input type="date" class="form-control" name="p_fnac" value="$p_fnac"><label>Fecha de Nacimiento</label></div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
                        <select class="form-select" name="p_sexo">
                            <option value="Masculino" @{[ $p_sexo eq 'Masculino' ? 'selected' : '' ]}>Masculino</option>
                            <option value="Femenino" @{[ $p_sexo eq 'Femenino' ? 'selected' : '' ]}>Femenino</option>
                            <option value="Otro" @{[ $p_sexo eq 'Otro' ? 'selected' : '' ]}>Otro</option>
                        </select>
                        <label>G&eacute;nero</label>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="form-floating diamond-input-armor">
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
                    <div class="form-floating diamond-input-armor">
                        <select class="form-select" name="p_ecivil">
                            <option value="Soltero" @{[ $p_ecivil eq 'Soltero' ? 'selected' : '' ]}>Soltero/a</option>
                            <option value="Casado" @{[ $p_ecivil eq 'Casado' ? 'selected' : '' ]}>Casado/a</option>
                            <option value="Divorciado" @{[ $p_ecivil eq 'Divorciado' ? 'selected' : '' ]}>Divorciado/a</option>
                        </select>
                        <label>Estado Civil</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor"><input type="text" class="form-control" name="p_ocup" value="$p_ocup" placeholder="Ocupacion"><label>Ocupaci&oacute;n</label></div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor"><input type="text" class="form-control" name="p_nac" value="$p_nac" placeholder="Nacionalidad"><label>Nacionalidad</label></div>
                </div>
            </div>
            <div class="d-flex justify-content-between mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="PerfilWizardController.nextStep()">Siguiente <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
HTML
    }

    # --- PANEL FINAL DE SEGURIDAD (Común para todos) ---
    my $security_step_idx = $is_paciente || $is_admin_org ? 3 : ($is_medico ? 2 : 1);

print <<HTML;
        <!-- PANEL DE SEGURIDAD Y CREDENCIALES (Paso Final) -->
        <div class="wizard-panel" id="step-panel-$security_step_idx">
            <h5 class="fw-bold mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-shield-lock-fill me-2" style="color: var(--md-teal-clinical);"></i>Seguridad y Confirmaci&oacute;n de Cuenta</h5>
            <div class="row g-3">
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="password" class="form-control border-warning fw-bold" id="clave_actual" name="clave_actual" placeholder="Clave Actual" required>
                        <label for="clave_actual" class="text-dark fw-bold">Contrase&ntilde;a Actual *</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="password" class="form-control fw-bold" id="clave_nueva" name="clave_nueva" placeholder="Nueva Clave">
                        <label for="clave_nueva">Nueva Contrase&ntilde;a (Opcional)</label>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-floating diamond-input-armor">
                        <input type="password" class="form-control fw-bold" id="clave_confirmar" name="clave_confirmar" placeholder="Confirmar">
                        <label for="clave_confirmar">Confirmar Nueva Contrase&ntilde;a</label>
                    </div>
                </div>
            </div>
            <div class="d-flex justify-content-start mt-4">
                <button type="button" class="wizard-btn-prev" onclick="PerfilWizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i>Anterior</button>
            </div>
        </div>

        <div class="mt-4 text-center">
            <span class="text-muted small fw-bold"><i class="bi bi-lock-fill me-1 text-success"></i>Todos los datos se sincronizan con los est&aacute;ndares de seguridad Diamond.</span>
        </div>
    </form>
</div> <!-- /wizard-container -->

<script src="../js/perfil_flow.js"></script>
<script>
function previewAvatarImage(input) {
    if (input.files && input.files[0]) {
        const reader = new FileReader();
        reader.onload = function(e) {
            const previewHeader = document.getElementById('avatar_preview_header');
            const initialHeader = document.getElementById('avatar_initial_header');
            const previewPanel = document.getElementById('avatar_preview_panel');
            const initialPanel = document.getElementById('avatar_initial_panel');

            if (previewHeader) {
                previewHeader.src = e.target.result;
                previewHeader.classList.remove('d-none');
            }
            if (initialHeader) initialHeader.classList.add('d-none');

            if (previewPanel) {
                previewPanel.src = e.target.result;
                previewPanel.classList.remove('d-none');
            }
            if (initialPanel) initialPanel.classList.add('d-none');
        };
        reader.readAsDataURL(input.files[0]);
    }
}

function previewFirmaImage(input) {
    if (input.files && input.files[0]) {
        const reader = new FileReader();
        reader.onload = function(e) {
            const img = document.getElementById('firma_preview_img');
            const placeholder = document.getElementById('firma_placeholder');
            if (img) {
                img.src = e.target.result;
                img.classList.remove('d-none');
            }
            if (placeholder) placeholder.classList.add('d-none');
        };
        reader.readAsDataURL(input.files[0]);
    }
}

\$(document).ready(function() {
    // 1. Inicializar Wizard según total de pasos por Rol
    let totalPasos = @{[ $is_paciente || $is_admin_org ? 4 : ($is_medico ? 3 : 2) ]};
    PerfilWizardController.init(totalPasos);

    // 2. Control del Formulario mediante FormData multipart
    \$('#perfilForm').on('submit', function(e) {
        e.preventDefault(); 
        const alertContainer = \$('#alertContainer');
        const guardarBtn = \$('#guardarBtn');

        const passNueva = \$('#clave_nueva').val();
        const passConf = \$('#clave_confirmar').val();
        if (passNueva && passNueva !== passConf) {
            alertContainer.html('<div class="alert alert-danger shadow-sm border-0 rounded-4"><i class="bi bi-exclamation-triangle-fill me-2"></i>Las contraseñas nuevas no coinciden.</div>');
            window.scrollTo({ top: 0, behavior: 'smooth' });
            return;
        }

        guardarBtn.attr('disabled', true).html('<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Sincronizando...');

        let formData = new FormData(this);

        \$.ajax({
            type: 'POST',
            url: '../api/update_perfil.pl',
            data: formData,
            processData: false,
            contentType: false,
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

    // 3. Lógica de Databinding Unidireccional por CP y Padrón CLUES (Para Admin Org)
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
                        if (r.num_ext) dir_parts.push('No. ' + r.num_ext);
                        if (r.asentamiento) dir_parts.push(r.asentamiento);
                        if (r.municipio) dir_parts.push(r.municipio);
                        if (r.entidad) dir_parts.push(r.entidad);
                        if (r.cp) dir_parts.push('C.P. ' + r.cp);
                        if (dir_parts.length > 0) {
                            \$('#biz_dir').val(dir_parts.join(', '));
                        }
                    }
                    if (r.latitud && r.longitud) {
                        \$('#biz_lat').val(r.latitud);
                        \$('#biz_lng').val(r.longitud);
                    }

                    // Render Servicios
                    let s_html = '<ul class="list-group list-group-flush">';
                    if(r.servicios && r.servicios.length > 0) {
                        r.servicios.forEach(s => {
                            s_html += '<li class="list-group-item bg-transparent py-1 px-0 border-0"><i class="bi bi-check2-circle text-success me-2"></i>' + s.nombre + '</li>';
                        });
                    } else {
                        s_html += '<li class="list-group-item bg-transparent text-muted py-1 px-0 border-0">Sin servicios registrados.</li>';
                    }
                    s_html += '</ul>';
                    \$('#clues_servicios_list').html(s_html);

                    // Render Horarios
                    let h_html = '<table class="table table-sm table-borderless mb-0"><tbody>';
                    if(r.horarios && r.horarios.length > 0) {
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
            loadCluesDetails(val, true); 
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
