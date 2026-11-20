use strict;
use warnings;
use utf8;
use File::Spec;

sub render_step_soap {
    my ($paciente, $id_empresa) = @_;
    my $cedula_medico = ($paciente && ref($paciente) eq 'HASH') ? ($paciente->{cedula_medico} // '') : '';
    my $tiene_cedula  = ($cedula_medico && $cedula_medico ne '0' && $cedula_medico !~ /^\s*$/) ? 1 : 0;

    my $cif1_options       = cargar_opciones_dat('CAT_CIF_1erNivel.dat', 1);
    my $cif2_options       = cargar_opciones_dat('CAT_CIF_2oNivel.dat', 1);
    my $cif3_options       = cargar_opciones_dat('CAT_CIF_3erNivel.dat', 1);
    my $cif4_options       = cargar_opciones_dat('CAT_CIF_4oNivel.dat', 1);
    my $calfunc_options    = cargar_opciones_dat('CAT_CIF_CALFUNC.dat', 1);
    my $calestruc_options  = cargar_opciones_dat('CAT_CIF_CALESTRUC.dat', 1);
    my $calactpart_options = cargar_opciones_dat('CAT_CIF_CALACTPART.dat', 1);
    my $calamb_options     = cargar_opciones_dat('CAT_CIF_CALAMB.dat', 1);

    my $banner_bloqueo_cedula = '';
    if (!$tiene_cedula) {
        $banner_bloqueo_cedula = qq{
            <div id="banner-bloqueo-cedula-cofepris" class="alert alert-danger border-danger py-2 px-3 mb-3 d-flex justify-content-between align-items-center flex-wrap gap-2">
                <div>
                    <i class="bi bi-shield-lock-fill me-1.5"></i>
                    <strong>Bloqueo Proactivo COFEPRIS:</strong> Su perfil médico no cuenta con Cédula Profesional validada. Debe validar su Cédula para emitir recetas oficiales.
                </div>
                <button type="button" class="btn btn-xs btn-danger fw-bold rounded-pill px-3 py-1" onclick="SOAPReactiveEngine.validarCedulaExpress()">
                    <i class="bi bi-patch-check-fill me-1"></i>Validar Cédula Ahora
                </button>
            </div>
        };
    }

    return qq{
        <div class="wizard-panel" id="step-panel-2" data-step-index="2">
            <input type="hidden" name="diagnosticos_secundarios_json" id="f_diagnosticos_secundarios_json" value="[]">

            <!-- Encabezado de Paso 3 + Macros Clínicas de 1 Clic -->
            <div class="d-flex justify-content-between align-items-center border-bottom pb-2.5 mb-3 flex-wrap gap-2">
                <div>
                    <h5 class="fw-bold text-navy mb-0">
                        <i class="bi bi-diagram-3-fill me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>Paso 3: Análisis (A), Plan (P), Pronóstico Dual y Receta COFEPRIS
                    </h5>
                    <p class="text-muted small mb-0">Diagnóstico CIE-10, Impresión Clínica, Pronóstico Dual NOM-004, Órdenes de Estudio y Receta con Alergia Cruzada.</p>
                </div>
                <span class="badge bg-primary-subtle text-primary fw-bold">Paso 3 de 6</span>
            </div>

            <!-- Barra de Macros Clínicas Completas (1 Clic) -->
            <div class="qx-subcard mb-3" style="background: linear-gradient(135deg, #f8fafc 0%, #f0fdfa 100%);">
                <div class="d-flex justify-content-between align-items-center mb-1.5 flex-wrap gap-2">
                    <span class="qx-label mb-0 text-navy"><i class="bi bi-magic text-teal me-1"></i>Macros Clínicas Completas en 1 Clic (Rellena CIE-10, Impresión, Plan, Pronóstico, Alarma y Receta)</span>
                    <button type="button" class="btn btn-xs btn-outline-primary rounded-pill px-2.5 py-0.5 fw-bold" onclick="BovedaService.openDrawer('RECETA')">
                        <i class="bi bi-clock-history me-1"></i>Clonar Receta Previa de Bóveda
                    </button>
                </div>
                <div class="d-flex flex-wrap gap-1.5">
                    <span class="chip-macro-card btn-accelerator-action" onclick="SOAPReactiveEngine.aplicarMacroClinica('FARINGITIS')">
                        <i class="bi bi-thermometer-high text-danger"></i> Faringitis Aguda (J02.9)
                    </span>
                    <span class="chip-macro-card btn-accelerator-action" onclick="SOAPReactiveEngine.aplicarMacroClinica('GASTRITIS')">
                        <i class="bi bi-Fire text-warning"></i> Gastritis Aguda / ERGE (K29.7)
                    </span>
                    <span class="chip-macro-card btn-accelerator-action" onclick="SOAPReactiveEngine.aplicarMacroClinica('HTA_CONTROL')">
                        <i class="bi bi-heart-pulse text-primary"></i> Control HTA Esencial (I10)
                    </span>
                    <span class="chip-macro-card btn-accelerator-action" onclick="SOAPReactiveEngine.aplicarMacroClinica('LUMBALGIA')">
                        <i class="bi bi-person-standing text-teal"></i> Lumbalgia Mecánica (M54.5)
                    </span>
                    <span class="chip-macro-card btn-accelerator-action" onclick="SOAPReactiveEngine.aplicarMacroClinica('ODONTALGIA')">
                        <i class="bi bi-journal-medical text-info"></i> Pulpitis / Periodontitis Dental (K04.4)
                    </span>
                </div>
            </div>

            <!-- Subcard 1: Diagnóstico CIE-10 (Principal y Secundarios) + CIF Opcional -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <span><i class="bi bi-search-heart text-teal me-1.5"></i>1. Codificación Diagnóstica Oficial CIE-10 (SSa / NOM-024)</span>
                    <div class="form-check form-switch mb-0">
                        <input class="form-check-input" type="checkbox" role="switch" id="check_usar_cif" onchange="document.getElementById('seccion-cif-opcional').classList.toggle('d-none', !this.checked)">
                        <label class="form-check-label small fw-bold text-muted" for="check_usar_cif">Mostrar Valoración Funcional CIF</label>
                    </div>
                </div>

                <input type="hidden" name="usar_cie10" id="check_usar_cie10" value="1">

                <div class="row g-2.5">
                    <div class="col-12 col-md-5">
                        <label class="wizard-label">Buscador Predictivo Catálogo CIE-10</label>
                        <div class="position-relative">
                            <input type="text" id="cie10_search" class="wizard-input border-primary" placeholder="Escriba código o diagnóstico (ej. J02, K29, I10, K04)..." autocomplete="off">
                            <div id="cie10_results" class="list-group position-absolute w-100 shadow-lg rounded-3 mt-1" style="z-index: 1055; display: none; max-height: 240px; overflow-y: auto; background: white;"></div>
                        </div>
                    </div>

                    <div class="col-12 col-md-5">
                        <label class="wizard-label">Diagnóstico Principal Seleccionado</label>
                        <input type="text" name="diagnostico_principal" id="diagnostico_principal" class="wizard-input bg-light fw-bold text-navy" placeholder="Seleccione del buscador o escriba diagnóstico..." oninput="SOAPReactiveEngine.syncAll()">
                        <input type="hidden" name="clave_diagnostico_cie10" id="clave_diagnostico_cie10">
                    </div>

                    <div class="col-12 col-md-2">
                        <label class="wizard-label">Severidad</label>
                        <select name="severidad" id="f_severidad" class="wizard-input">
                            <option value="Leve">Leve</option>
                            <option value="Moderada">Moderada</option>
                            <option value="Grave">Grave</option>
                        </select>
                    </div>

                    <!-- Diagnósticos Secundarios CIE-10 -->
                    <div class="col-12">
                        <div class="d-flex align-items-center flex-wrap gap-1.5" id="cie10-secundarios-chips">
                            <span class="small text-muted fw-bold">Dx Secundarios / Comorbilidades:</span>
                            <span class="badge bg-light text-muted border">Ninguno agregado</span>
                        </div>
                    </div>
                </div>

                <!-- Sección CIF Opcional (Colapsada por defecto para cero fricción) -->
                <div id="seccion-cif-opcional" class="d-none mt-3 pt-2.5 border-top">
                    <div class="row g-2">
                        <div class="col-md-6">
                            <label class="wizard-label">Código CIF Nivel 1</label>
                            <select name="cif_nivel1" class="wizard-input">$cif1_options</select>
                        </div>
                        <div class="col-md-6">
                            <label class="wizard-label">Calificador Funciones</label>
                            <select name="cif_calif1" class="wizard-input">$calfunc_options</select>
                        </div>
                        <div class="col-md-6">
                            <label class="wizard-label">Código CIF Nivel 2</label>
                            <select name="cif_nivel2" class="wizard-input">$cif2_options</select>
                        </div>
                        <div class="col-md-6">
                            <label class="wizard-label">Calificador Estructuras</label>
                            <select name="cif_calif2" class="wizard-input">$calestruc_options</select>
                        </div>
                        <input type="hidden" name="cif_nivel3" value="">
                        <input type="hidden" name="cif_calif3" value="">
                        <input type="hidden" name="cif_nivel4" value="">
                        <input type="hidden" name="cif_calif4" value="">
                    </div>
                </div>
            </div>

            <!-- Subcard 2: Impresión Clínica (A), Pronóstico Dual NOM-004 y Plan Terapéutico (P) -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <span><i class="bi bi-clipboard2-check-fill text-teal me-1.5"></i>2. Análisis Clínico (A), Pronóstico Dual NOM-004 y Plan (P)</span>
                    <button type="button" class="btn btn-xs btn-success rounded-pill px-2.5 py-0.5 fw-bold btn-accelerator-action" onclick="SOAPReactiveEngine.setPronosticoDual('BUENO','BUENO')">
                        ⚡ Pronóstico Dual: Bueno para la Vida y la Función
                    </button>
                </div>

                <div class="row g-2.5">
                    <!-- Impresión Clínica -->
                    <div class="col-12 col-md-8">
                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <label class="wizard-label mb-0">Impresión Clínica y Juicio Diagnóstico (Assessment) <span class="req-star">*</span></label>
                            <div class="d-flex gap-1">
                                <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-2 py-0" onclick="toggleDictadoVoz('textarea[name=impresion_clinica]', this)"><i class="bi bi-mic-fill"></i></button>
                                <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-0" onclick="limpiarCampoTexto('textarea[name=impresion_clinica]'); SOAPReactiveEngine.syncAll();"><i class="bi bi-eraser-fill"></i></button>
                            </div>
                        </div>
                        <textarea name="impresion_clinica" id="f_impresion_clinica" class="wizard-input" rows="2" placeholder="Integración sindromática, diagnóstico nosológico y estado hemodinámico..." required oninput="SOAPReactiveEngine.syncAll()"></textarea>
                    </div>

                    <!-- Pronóstico Dual NOM-004 (Vida y Función) -->
                    <div class="col-6 col-md-2">
                        <label class="wizard-label">Pronóstico Vida <span class="req-star">*</span></label>
                        <select name="pronostico_vida" id="f_pronostico_vida" class="wizard-input fw-bold text-success" onchange="SOAPReactiveEngine.syncAll()">
                            <option value="BUENO" selected>BUENO</option>
                            <option value="RESERVADO">RESERVADO</option>
                            <option value="MALO">MALO</option>
                        </select>
                    </div>
                    <div class="col-6 col-md-2">
                        <label class="wizard-label">Pronóstico Función <span class="req-star">*</span></label>
                        <select name="pronostico_funcion" id="f_pronostico_funcion" class="wizard-input fw-bold text-success" onchange="SOAPReactiveEngine.syncAll()">
                            <option value="BUENO" selected>BUENO</option>
                            <option value="RESERVADO">RESERVADO</option>
                            <option value="MALO">MALO</option>
                        </select>
                    </div>

                    <!-- Plan de Tratamiento -->
                    <div class="col-12">
                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <label class="wizard-label mb-0">Plan de Tratamiento y Abordaje Clínico (Plan) <span class="req-star">*</span></label>
                            <div class="d-flex gap-1">
                                <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-2 py-0" onclick="toggleDictadoVoz('textarea[name=plan_tratamiento]', this)"><i class="bi bi-mic-fill"></i></button>
                                <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-0" onclick="limpiarCampoTexto('textarea[name=plan_tratamiento]'); SOAPReactiveEngine.syncAll();"><i class="bi bi-eraser-fill"></i></button>
                            </div>
                        </div>
                        <textarea name="plan_tratamiento" id="f_plan_tratamiento" class="wizard-input" rows="2" placeholder="Manejo farmacológico, medidas no farmacológicas y metas terapéuticas..." required oninput="SOAPReactiveEngine.syncAll()"></textarea>
                    </div>

                    <!-- Indicaciones Higiénico-Dietéticas y Datos de Alarma -->
                    <div class="col-12 col-md-6">
                        <label class="wizard-label">Medidas Higiénico-Dietéticas</label>
                        <textarea name="indicaciones_higienico" id="f_indicaciones_higienico" class="wizard-input" rows="2" placeholder="Hidratación abundante, dieta blanda sin irritantes, reposo relativo..." oninput="SOAPReactiveEngine.syncAll()"></textarea>
                        <div class="chip-bar">
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_indicaciones_higienico', 'Abundantes líquidos orales (2L/día), dieta blanda libre de irritantes y grasas.')">⚡ Hidratación + Dieta blanda</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_indicaciones_higienico', 'Dieta hiposódica (<2g Na/día), caminata aeróbica 30 min/día.')">⚡ Dieta hiposódica + Ejercicio</span>
                        </div>
                    </div>

                    <div class="col-12 col-md-6">
                        <label class="wizard-label text-danger"><i class="bi bi-exclamation-octagon-fill me-1"></i>Datos de Alarma (Destacados en Rojo en PDF/Receta)</label>
                        <textarea name="datos_alarma" id="f_datos_alarma" class="wizard-input border-danger-subtle" rows="2" placeholder="Fiebre >38.5°C persistente, disnea, dolor intenso no controlado..." oninput="SOAPReactiveEngine.syncAll()"></textarea>
                        <div class="chip-bar">
                            <span class="chip-accelerator text-danger border-danger-subtle bg-danger-subtle" onclick="SOAPReactiveEngine.appendChip('f_datos_alarma', 'Acudir a Urgencias si presenta fiebre >38.5°C, dificultad respiratoria, intolerancia a la vía oral o deterioro clínico.')">🚨 Alarma General / Fiebre / Disnea</span>
                            <span class="chip-accelerator text-danger border-danger-subtle bg-danger-subtle" onclick="SOAPReactiveEngine.appendChip('f_datos_alarma', 'Acudir a Urgencias si T.A. ≥160/100 mmHg, cefalea intensa, acúfenos, fosfenos o dolor precordial.')">🚨 Alarma Hipertensiva</span>
                        </div>
                    </div>

                    <!-- Órdenes de Laboratorio y Gabinete Solicitados -->
                    <div class="col-12 col-md-6">
                        <label class="wizard-label">Órdenes de Laboratorio Solicitadas</label>
                        <input type="text" name="laboratorios_solicitados" id="f_laboratorios_solicitados" class="wizard-input" placeholder="BH, QS6, EGO, HbA1c, Perfil Lipídico...">
                        <div class="chip-bar">
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_laboratorios_solicitados', 'Biometría Hemática Completa, Química Sanguínea 6 Elementos y EGO.')">⚡ Paquete Básico (BH + QS6 + EGO)</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_laboratorios_solicitados', 'HbA1c, Perfil de Lípidos Completo y Microalbuminuria.')">⚡ Control Metabólico</span>
                        </div>
                    </div>

                    <div class="col-12 col-md-6">
                        <label class="wizard-label">Órdenes de Gabinete / Imagenología Solicitadas</label>
                        <input type="text" name="gabinete_solicitados" id="f_gabinete_solicitados" class="wizard-input" placeholder="Tele de Tórax, USG Abdominal, Rx Panorámica...">
                        <div class="chip-bar">
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_gabinete_solicitados', 'Radiografía Tele de Tórax PA.')">⚡ Tele de Tórax</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_gabinete_solicitados', 'Ultrasonido Abdominal Superior.')">⚡ USG Abdominal</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_gabinete_solicitados', 'Radiografía Panorámica Dental (Ortopantomografía).')">⚡ Rx Panorámica</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Subcard 3: Receta Médica Oficial COFEPRIS + Motor de Alergia Cruzada -->
            <div class="qx-subcard mb-3">
                <div class="d-flex align-items-center justify-content-between border-bottom pb-2 mb-2.5 flex-wrap gap-2">
                    <div>
                        <h6 class="fw-bold m-0 text-navy">
                            <i class="bi bi-capsule-pill me-1.5 text-primary"></i>3. Receta Médica Oficial COFEPRIS + Motor de Seguridad Farmacológica
                        </h6>
                        <small class="text-muted">Conectado a <code>productos.dat</code> (3NF) con cruce en vivo contra las alergias del Paso 1</small>
                    </div>
                    <div class="form-check form-switch fs-5 mb-0">
                        <input class="form-check-input" type="checkbox" role="switch" id="check_requiere_receta" name="requiere_receta" value="1" onchange="toggleSeccionReceta(this.checked)">
                        <label class="form-check-label fs-6 fw-bold text-navy" for="check_requiere_receta">¿Expedir Receta Médica?</label>
                    </div>
                </div>

                $banner_bloqueo_cedula

                <!-- Banner Dinámico de Alerta de Alergia Cruzada Detectada -->
                <div id="banner-alergia-cruzada-receta" class="alert alert-danger border-danger py-2 px-3 mb-2.5 d-none">
                    <div class="d-flex align-items-center gap-2">
                        <i class="bi bi-exclamation-triangle-fill fs-4 text-danger"></i>
                        <div>
                            <strong class="d-block">¡ALERTA FARMACOLÓGICA DE ALERGIA CRUZADA DETECTADA!</strong>
                            <span id="txt-alergia-cruzada-detalle" class="small">Se detectó un conflicto entre la prescripción y las alergias registradas del paciente.</span>
                        </div>
                    </div>
                </div>

                <div id="seccion-receta-medica" style="display: none;">
                    <input type="hidden" name="receta_json" id="receta_json_input" value="[]">

                    <div class="row g-2 mb-2.5">
                        <div class="col-12 col-md-7">
                            <label class="wizard-label">Buscar Medicamento en Catálogo 3NF (productos.dat)</label>
                            <select id="select_producto_receta" class="wizard-input" onchange="seleccionarProductoReceta(this.value)">
                                @{[ cargar_opciones_productos($id_empresa) ]}
                            </select>
                        </div>
                        <div class="col-12 col-md-5 d-flex align-items-end gap-1.5">
                            <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-3 py-1.5 fw-bold flex-grow-1" onclick="agregarMedicamentoRecetaManual()">
                                <i class="bi bi-plus-circle me-1"></i>+ Prescripción Manual
                            </button>
                            <button type="button" class="btn btn-sm btn-outline-teal rounded-pill px-3 py-1.5 fw-bold" style="border-color:#19B7A5;color:#0f766e;" onclick="BovedaService.openDrawer('RECETA')" title="Clonar medicamentos desde una receta previa en la Bóveda">
                                <i class="bi bi-copy me-1"></i>Clonar de Bóveda
                            </button>
                        </div>
                    </div>

                    <div class="table-responsive mb-2.5">
                        <table class="table table-sm table-bordered table-hover align-middle mb-0">
                            <thead class="table-light small text-uppercase fw-bold">
                                <tr>
                                    <th>Medicamento (Genérico / Comercial)</th>
                                    <th style="width: 115px;">Forma</th>
                                    <th style="width: 105px;">Dosis</th>
                                    <th>Posología (Frecuencia y Duración)</th>
                                    <th style="width: 110px;">Vía</th>
                                    <th class="text-center" style="width: 45px;"></th>
                                </tr>
                            </thead>
                            <tbody id="tbody-receta-items">
                                <tr><td colspan="6" class="text-center py-3 text-muted small">Sin medicamentos en la receta. Seleccione del catálogo, aplique una Macro o clone desde la Bóveda.</td></tr>
                            </tbody>
                        </table>
                    </div>

                    <div class="row g-2">
                        <div class="col-6 col-md-3">
                            <label class="wizard-label">Folio Control Receta</label>
                            <input type="text" name="receta_folio" id="receta_folio_input" class="wizard-input bg-light fw-bold font-monospace" readonly>
                        </div>
                        <div class="col-6 col-md-3">
                            <label class="wizard-label">Cédula Profesional COFEPRIS</label>
                            <input type="text" id="f_receta_cedula_display" class="wizard-input bg-light fw-bold text-primary" readonly value="$cedula_medico" placeholder="Pendiente de validar">
                        </div>
                        <div class="col-12 col-md-6">
                            <label class="wizard-label">Indicaciones Generales de la Receta</label>
                            <input type="text" name="receta_indicaciones_extra" id="f_receta_indicaciones_extra" class="wizard-input" placeholder="Ej: Tomar con abundante agua. No suspender antibiótico antes de terminar esquema.">
                        </div>
                    </div>
                </div>
            </div>

            <div class="d-flex justify-content-between mt-3 pt-2 border-top">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()">
                    <i class="bi bi-arrow-left me-1"></i> Paso 2: Objetivo
                </button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">
                    Continuar a Paso 4: Acuerdos y Blindaje Legal <i class="bi bi-arrow-right ms-1"></i>
                </button>
            </div>
        </div>
    };
}

sub cargar_opciones_productos {
    my ($id_empresa) = @_;
    require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
    my $id_raiz = $id_empresa ? catalogo_org_utils::resolver_id_raiz_catalogo($id_empresa) : 0;
    my $rutas   = catalogo_org_utils::obtener_rutas_catalogo($id_raiz);
    my $path    = $rutas->{productos};

    my $options = '<option value="">Buscar en catálogo de productos.dat...</option>';
    if ($path && -e $path && open(my $fh, '<:encoding(UTF-8)', $path)) {
        <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            if (@c >= 2) {
                my $id   = $c[0];
                my $nom  = $c[1];
                my $pres = $c[4] // '';
                my $conc = ($nom =~ /(\d+\s*(?:mg|g|ml|mcg|ui))/i) ? $1 : '500mg';
                my $forma = 'Tableta';
                if ($pres =~ /cápsula|capsula/i) { $forma = 'Cápsula'; }
                elsif ($pres =~ /jarabe|suspensi/i) { $forma = 'Jarabe'; }
                elsif ($pres =~ /ampolleta|inyectable/i) { $forma = 'Inyectable'; }
                $options .= qq(<option value="$id|$nom|$forma|$conc">$nom ($pres)</option>\n);
            }
        }
        close($fh);
    }
    return $options;
}

sub cargar_opciones_dat {
    my ($file_name, $has_head) = @_;
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogosOF', $file_name);
    my $options = '<option value="">Seleccione...</option>';
    if (-e $path && open(my $fh, '<:encoding(UTF-8)', $path)) {
        <$fh> if $has_head;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my ($code, $desc) = split /!/, $line, 2;
            if ($code && $desc) {
                $desc =~ s/"/&quot;/g;
                $options .= qq(<option value="$code">$code - $desc</option>\n);
            }
        }
        close($fh);
    }
    return $options;
}

1;
