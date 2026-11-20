use strict;
use warnings;
use utf8;

sub render_step_registro_privado {
    my ($paciente) = @_;
    $paciente ||= {};
    my $motivo_precargado = $paciente->{motivo_precargado} || '';
    my $id_p = $paciente->{id_paciente} || '';

    # 1. Antecedentes y Tutor del Expediente
    my $tutor = $paciente->{tutor} // '';
    my $ant   = $paciente->{antecedentes} // {};
    my $hf    = $ant->{heredofamiliares} // {};
    my $pp    = $ant->{personales_patologicos} // {};
    my $pnp   = $ant->{personales_no_patologicos} // {};

    my $num_emp = $ant->{num_empleado_estado} || $paciente->{num_empleado_estado} || '';
    my $dep_emp = $ant->{dependencia} || $paciente->{dependencia} || '';
    my $es_municipio = ($num_emp ne '' || $dep_emp ne '') ? 1 : 0;

    my $badge_tipo_paciente = $es_municipio
        ? qq{<span class="badge bg-info text-dark fw-bold rounded-pill px-2.5 py-1"><i class="bi bi-building-check me-1"></i>EMPLEADO MUNICIPIO #$num_emp ($dep_emp)</span>}
        : qq{<span class="badge bg-primary-subtle text-primary border border-primary-subtle fw-bold rounded-pill px-2.5 py-1"><i class="bi bi-person-vcard me-1"></i>PACIENTE PARTICULAR</span>};

    my $_fmt_badge = sub {
        my ($label, $val, $spec) = @_;
        my $is_si = ($val && $val =~ /S[ií]/i);
        my $cls   = $is_si ? 'bg-danger-subtle text-danger border border-danger-subtle' : 'bg-light text-muted border';
        my $ic    = $is_si ? '<i class="bi bi-exclamation-triangle-fill me-1"></i>' : '<i class="bi bi-check-circle me-1"></i>';
        my $txt   = "$ic<strong>$label:</strong> " . ($val || 'No');
        $txt .= " <em>($spec)</em>" if ($is_si && $spec);
        return qq{<span class="badge $cls px-2 py-1 fw-medium text-wrap text-start me-1 mb-1" style="font-size:0.7rem;">$txt</span>};
    };

    my $hf_html = '';
    $hf_html .= $_fmt_badge->("HTA", $hf->{hipertension});
    $hf_html .= $_fmt_badge->("Diabetes", $hf->{diabetes});
    $hf_html .= $_fmt_badge->("Cardiopatías", $hf->{cardiopatias});
    $hf_html .= $_fmt_badge->("Cáncer", $hf->{cancer}, $hf->{cancer_tipo});
    $hf_html .= $_fmt_badge->("Hereditarias", $hf->{enfermedades}, $hf->{enfermedades_especificar});

    my $pp_html = '';
    $pp_html .= $_fmt_badge->("Crónicas", $pp->{cronicas}, $pp->{cronicas_especificar});
    $pp_html .= $_fmt_badge->("Cirugías", $pp->{cirugias}, $pp->{cirugias_especificar});
    $pp_html .= $_fmt_badge->("Hospitalizaciones", $pp->{hospitalizaciones}, $pp->{hospitalizaciones_especificar});
    $pp_html .= $_fmt_badge->("Alergias", $pp->{alergias}, $pp->{alergias_especificar});
    $pp_html .= $_fmt_badge->("Tratamientos", $pp->{tratamientos}, $pp->{tratamientos_especificar});

    my $pnp_html = '';
    $pnp_html .= $_fmt_badge->("Tabaco", $pnp->{tabaquismo}, $pnp->{tabaquismo_cantidad});
    $pnp_html .= $_fmt_badge->("Alcohol", $pnp->{alcohol}, $pnp->{alcohol_frecuencia});
    $pnp_html .= $_fmt_badge->("Act. Física", $pnp->{actividad_fisica}, $pnp->{actividad_fisica_tipo});

    my $patologicos_val = $pp->{cronicas_especificar} || ($pp->{cronicas} && $pp->{cronicas} =~ /S[ií]/i ? 'Enfermedad crónica referida en expediente' : '');
    my $alergias_val    = $pp->{alergias_especificar} || ($pp->{alergias} && $pp->{alergias} =~ /S[ií]/i ? 'Alergia registrada en expediente' : '');

    # 2. Tratamiento Activo y Cotizaciones
    my $trat_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'tratamientos.dat');
    my $tiene_tratamiento = 0;
    my $id_tratamiento_activo = '';
    my $id_cotizacion_activa = '';
    my $fecha_inicio_activa = '';

    if (-e $trat_file && open(my $fh_t, '<:encoding(UTF-8)', $trat_file)) {
        <$fh_t>;
        while (my $line = <$fh_t>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            if (@c >= 4 && $c[1] eq $id_p && $c[3] eq 'Abierto') {
                $tiene_tratamiento = 1;
                $id_tratamiento_activo = $c[0];
                $id_cotizacion_activa  = $c[2];
                $fecha_inicio_activa   = $c[4] // '';
                last;
            }
        }
        close($fh_t);
    }

    my $nombre_cotizacion_activa = '';
    my $cot_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cotizaciones.dat');
    my @cots = ();
    if (-e $cot_file && open(my $fh, '<:encoding(UTF-8)', $cot_file)) {
        <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            next unless @c >= 6;
            if ($tiene_tratamiento && $c[0] eq $id_cotizacion_activa) {
                $nombre_cotizacion_activa = $c[2];
            }
            if (($c[1] // '') eq $id_p && ($c[6] // 'Pendiente') ne 'Convertida') {
                push @cots, { id_cot => $c[0], nombre => $c[2], total => $c[3] // 0, fecha => $c[4] };
            }
        }
        close($fh);
    }

    my $cot_options = qq{<option value="">Ninguna cotización vinculada...</option>};
    foreach my $c (@cots) {
        $cot_options .= qq{<option value="$c->{id_cot}" data-total="$c->{total}">$c->{nombre} ($c->{fecha}) - \$$c->{total}</option>};
    }

    my ($cot_section, $conversion_section, $tipo_consulta_options);
    if ($tiene_tratamiento) {
        $cot_section = qq{
            <label class="wizard-label"><i class="bi bi-shield-fill-check me-1 text-success"></i>Tratamiento Activo</label>
            <div class="p-2 px-3 rounded-3 border border-info bg-info-subtle text-dark small fw-bold d-flex align-items-center">
                <i class="bi bi-info-circle-fill text-info me-2"></i>Plan: $nombre_cotizacion_activa (Iniciado: $fecha_inicio_activa)
            </div>
            <input type="hidden" name="id_cotizacion" id="f_id_cotizacion" value="$id_cotizacion_activa">
            <input type="hidden" name="id_tratamiento" value="$id_tratamiento_activo">
        };
        $conversion_section = qq{
            <div class="p-2 px-3 rounded-3 border border-success bg-success-subtle text-success small fw-bold w-100 d-flex align-items-center">
                <i class="bi bi-check-circle-fill me-2"></i>Seguimiento de Tratamiento Activo (Tarifa Consulta \$0.00)
            </div>
        };
        $tipo_consulta_options = qq{
            <option value="Seguimiento" selected>Seguimiento (Automático)</option>
            <option value="Primera Vez">Primera Vez</option>
            <option value="Urgencia">Urgencia</option>
        };
    } else {
        $cot_section = qq{
            <div class="form-floating">
                <select name="id_cotizacion" id="f_id_cotizacion" class="form-select wizard-input" onchange="toggleConversionCheckbox()">
                    $cot_options
                </select>
                <label for="f_id_cotizacion"><i class="bi bi-receipt me-1 text-teal"></i>Cotización del Paciente</label>
            </div>
        };
        $conversion_section = qq{
            <div class="form-check form-switch p-2 px-3 border rounded-3 w-100 bg-light" id="conversion_wrapper" style="display: none; align-items: center;">
                <input class="form-check-input ms-0 me-2" type="checkbox" name="convertir_tratamiento" id="f_convertir_tratamiento" value="1" onchange="toggleConversionStyle()">
                <label class="form-check-label fw-semibold text-navy small" for="f_convertir_tratamiento">¿Convertir en Tratamiento Activo?</label>
            </div>
        };
        $tipo_consulta_options = qq{
            <option value="Primera Vez" selected>Primera Vez</option>
            <option value="Seguimiento">Seguimiento / Control</option>
            <option value="Urgencia">Urgencia Médica</option>
        };
    }

    my $hoy_str = sprintf('%04d-%02d-%02d', (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3]);

    return qq{
        <div class="wizard-panel active" id="step-panel-0" data-step-index="0">
            <!-- Encabezado de Paso Estilo Quirófano -->
            <div class="d-flex justify-content-between align-items-center border-bottom pb-2 mb-3 flex-wrap gap-2">
                <div>
                    <h5 class="fw-semibold text-navy mb-0">
                        <i class="bi bi-person-vcard-fill me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>Paso 1: Subjetivo (S), Registro e Interrogatorio
                    </h5>
                    <p class="text-muted small mb-0">Motivo de consulta, escala EVA de dolor, evolución del padecimiento actual, alergias/NKDA y consentimiento anticipado.</p>
                </div>
                <div class="d-flex align-items-center gap-2">
                    $badge_tipo_paciente
                    <span class="badge bg-primary-subtle text-primary fw-semibold">Paso 1 de 6</span>
                </div>
            </div>

            <!-- Subcard 1: Ficha Rápida de Identificación y Clasificación -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center">
                    <span><i class="bi bi-person-check-fill text-teal me-1.5"></i>1. Datos de Admisión y Modalidad</span>
                    <span class="small text-muted fw-semibold">Expediente #$id_p</span>
                </div>
                <div class="row g-2.5">
                    <div class="col-12 col-md-4">
                        <div class="form-floating">
                            <input type="text" id="f_paciente_nombre" name="paciente_nombre_display" class="form-control wizard-input bg-light" placeholder=" " value="$paciente->{nombre}" readonly data-preserve="true">
                            <label for="f_paciente_nombre">Paciente Titular</label>
                        </div>
                    </div>
                    <div class="col-6 col-md-3">
                        <div class="form-floating">
                            <input type="text" id="f_paciente_curp" name="paciente_curp_display" class="form-control wizard-input bg-light font-monospace" placeholder=" " value="$paciente->{curp}" readonly data-preserve="true">
                            <label for="f_paciente_curp">CURP</label>
                        </div>
                    </div>
                    <div class="col-3 col-md-2">
                        <div class="form-floating">
                            <input type="text" id="f_paciente_sexo" name="paciente_sexo_display" class="form-control wizard-input bg-light" placeholder=" " value="$paciente->{sexo}" readonly data-preserve="true">
                            <label for="f_paciente_sexo">Sexo</label>
                        </div>
                    </div>
                    <div class="col-3 col-md-1.5">
                        <div class="form-floating">
                            <input type="text" id="f_paciente_edad" name="paciente_edad_display" class="form-control wizard-input bg-light" placeholder=" " value="$paciente->{edad}" readonly data-preserve="true">
                            <label for="f_paciente_edad">Edad</label>
                        </div>
                    </div>
                    <div class="col-6 col-md-1.5">
                        <div class="form-floating">
                            <input type="text" id="f_paciente_hora" name="hora_consulta" class="form-control wizard-input bg-light text-center" placeholder=" " value="$paciente->{hora_consulta}" readonly data-preserve="true">
                            <label for="f_paciente_hora">Hora</label>
                        </div>
                        <input type="hidden" name="fecha_consulta" value="$paciente->{fecha_consulta}" data-preserve="true">
                    </div>

                    <div class="col-6 col-md-3">
                        <div class="form-floating">
                            <select name="tipo_consulta" id="f_tipo_consulta" class="form-select wizard-input" required onchange="SOAPReactiveEngine.syncAll()">
                                $tipo_consulta_options
                            </select>
                            <label for="f_tipo_consulta">Tipo de Consulta <span class="req-star">*</span></label>
                        </div>
                    </div>
                    <div class="col-12 col-md-3">
                        <div class="form-floating">
                            <input type="text" id="f_paciente_espe" class="form-control wizard-input bg-light text-primary" placeholder=" " value="$paciente->{espe_nombre_medico}" readonly data-preserve="true">
                            <label for="f_paciente_espe">Especialidad (Inamovible)</label>
                        </div>
                        <input type="hidden" name="especialidad" value="$paciente->{espe_nombre_medico}" data-preserve="true">
                        <input type="hidden" name="id_espe" value="$paciente->{id_espe_medico}" data-preserve="true">
                    </div>
                    <div class="col-12 col-md-3">
                        $cot_section
                    </div>
                    <div class="col-12 col-md-3 d-flex align-items-center">
                        $conversion_section
                    </div>
                </div>
            </div>

            <!-- Subcard 2: Padecimiento Actual (Subjetivo - S) + Chips Aceleradores + Escala EVA -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <span><i class="bi bi-chat-left-text-fill text-teal me-1.5"></i>2. Padecimiento Actual (Subjetivo - S)</span>
                    <span class="small text-muted">Toque un chip para insertar motivo rápido en 1 clic</span>
                </div>

                <div class="row g-2.5">
                    <!-- Motivo de Consulta -->
                    <div class="col-12">
                        <div class="d-flex justify-content-between align-items-center mb-1 flex-wrap gap-1">
                            <span class="wizard-section-title">Motivo Principal de Consulta</span>
                            <div class="d-flex align-items-center gap-1">
                                <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-2.5 py-0.5 shadow-xs d-inline-flex align-items-center" onclick="toggleDictadoVoz('textarea[name=motivo]', this)">
                                    <i class="bi bi-mic-fill me-1"></i><span class="btn-dictado-text fw-semibold">Dictar</span>
                                </button>
                                <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-0.5 shadow-xs d-inline-flex align-items-center" onclick="limpiarCampoTexto('textarea[name=motivo]'); SOAPReactiveEngine.syncAll();">
                                    <i class="bi bi-eraser-fill me-1"></i><span class="small fw-semibold">Limpiar</span>
                                </button>
                            </div>
                        </div>
                        <div class="form-floating">
                            <textarea name="motivo" id="f_motivo_consulta" class="form-control wizard-input" placeholder=" " style="height: 85px;" required oninput="SOAPReactiveEngine.syncAll()">$motivo_precargado</textarea>
                            <label for="f_motivo_consulta">Describa el motivo por el cual acude el paciente... <span class="req-star">*</span></label>
                        </div>
                        <div class="dictado-live-badge text-danger fw-semibold mt-1 d-none align-items-center gap-2">
                            <span class="spinner-grow spinner-grow-sm text-danger"></span><span>Escuchando dictado...</span>
                        </div>
                        <div class="chip-bar">
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_motivo_consulta', 'Valoración general y control clínico')">⚡ Valoración general</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_motivo_consulta', 'Odinofagia, fiebre y ataque al estado general')">⚡ Odinofagia / Fiebre</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_motivo_consulta', 'Dolor epigástrico urente y dispepsia')">⚡ Dolor epigástrico</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_motivo_consulta', 'Control y seguimiento de Hipertensión Arterial / Diabetes')">⚡ Control Crónico</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_motivo_consulta', 'Lumbalgia mecánica aguda post-esfuerzo')">⚡ Lumbalgia</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_motivo_consulta', 'Odontalgia aguda y revisión dental')">⚡ Odontalgia / Dental</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_motivo_consulta', 'Seguimiento y revisión de estudios previos')">⚡ Revisión de estudios</span>
                        </div>
                    </div>

                    <!-- Inicio de síntomas y Escala EVA 1-10 -->
                    <div class="col-12 col-md-4">
                        <div class="form-floating">
                            <input type="date" name="inicio_sintomas" id="f_inicio_sintomas" class="form-control wizard-input" placeholder=" " value="$hoy_str" onchange="SOAPReactiveEngine.syncAll()">
                            <label for="f_inicio_sintomas">Inicio de Síntomas</label>
                        </div>
                    </div>
                    <div class="col-12 col-md-8">
                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <span class="wizard-section-title">Escala Visual Analógica del Dolor (EVA 1–10)</span>
                            <span id="lbl-eva-badge" class="badge bg-success rounded-pill fw-bold px-2.5 py-1">EVA 1/10 · Dolor Leve</span>
                        </div>
                        <input type="hidden" name="intensidad" id="f_intensidad_eva" value="1">
                        <input type="hidden" name="eva_dolor" id="f_eva_dolor" value="1">
                        <div class="eva-slider-wrapper position-relative px-1 py-1">
                            <input type="range" class="form-range eva-range-slider" min="0" max="10" step="1" id="f_slider_eva" value="1" oninput="SOAPReactiveEngine.setEva(this.value)">
                            <div class="d-flex justify-content-between text-muted small px-1 font-monospace" style="font-size:0.72rem; margin-top:-2px;">
                                <span>0 (Sin Dolor)</span>
                                <span>3 (Leve)</span>
                                <span>5 (Moderado)</span>
                                <span>8 (Severo)</span>
                                <span>10 (Máximo)</span>
                            </div>
                        </div>
                    </div>

                    <!-- Evolución y semiología -->
                    <div class="col-12">
                        <div class="d-flex justify-content-between align-items-center mb-1 flex-wrap gap-1">
                            <span class="wizard-section-title">Evolución y Semiología del Cuadro Clínico</span>
                            <div class="d-flex align-items-center gap-1">
                                <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-2.5 py-0.5 shadow-xs d-inline-flex align-items-center" onclick="toggleDictadoVoz('textarea[name=evolucion]', this)">
                                    <i class="bi bi-mic-fill me-1"></i><span class="btn-dictado-text fw-semibold">Dictar</span>
                                </button>
                                <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-0.5 shadow-xs d-inline-flex align-items-center" onclick="limpiarCampoTexto('textarea[name=evolucion]'); SOAPReactiveEngine.syncAll();">
                                    <i class="bi bi-eraser-fill me-1"></i><span class="small fw-semibold">Limpiar</span>
                                </button>
                            </div>
                        </div>
                        <div class="form-floating">
                            <textarea name="evolucion" id="f_evolucion" class="form-control wizard-input" placeholder=" " style="height: 85px;" required oninput="SOAPReactiveEngine.syncAll()"></textarea>
                            <label for="f_evolucion">Cronología, factores desencadenantes y síntomas acompañantes... <span class="req-star">*</span></label>
                        </div>
                        <div class="dictado-live-badge text-danger fw-semibold mt-1 d-none align-items-center gap-2">
                            <span class="spinner-grow spinner-grow-sm text-danger"></span><span>Escuchando dictado...</span>
                        </div>
                        <div class="chip-bar">
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_evolucion', 'Inicia hace 48 horas con sintomatología progresiva, sin automedicación previa.')">⚡ Inicio 48h sin automedicación</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_evolucion', 'Niega fiebre, disnea, dolor torácico o pérdida ponderal.')">⚡ Niega datos de alarma sistémicos</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_evolucion', 'Acude a control subsecuente con adecuada adherencia terapéutica y mejoría clínica.')">⚡ Evolución favorable en control</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Subcard 3: Alergias (Motor Farmacológico + NKDA 1 Clic) y Antecedentes -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <span><i class="bi bi-shield-exclamation text-danger me-1.5"></i>3. Alergias Farmacológicas (Cruce COFEPRIS) y Antecedentes</span>
                    <button type="button" class="btn btn-sm btn-success rounded-pill px-3 py-0.5 fw-semibold shadow-xs btn-accelerator-action" onclick="SOAPReactiveEngine.marcarNKDA()">
                        <i class="bi bi-check2-all me-1"></i>✓ Sin Alergias Conocidas (NKDA)
                    </button>
                </div>

                <input type="hidden" name="es_nkda" id="f_es_nkda" value="0">

                <div class="row g-2.5">
                    <div class="col-12 col-md-6">
                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <span class="wizard-section-title text-danger"><i class="bi bi-capsule me-1"></i>Alergias a Medicamentos / Alimentos</span>
                            <div class="d-flex gap-1">
                                <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-2 py-0" onclick="toggleDictadoVoz('textarea[name=alergias]', this)"><i class="bi bi-mic-fill"></i></button>
                                <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-0" onclick="limpiarCampoTexto('textarea[name=alergias]'); SOAPReactiveEngine.onAlergiasInput();"><i class="bi bi-eraser-fill"></i></button>
                            </div>
                        </div>
                        <div class="form-floating">
                            <textarea name="alergias" id="f_alergias" class="form-control wizard-input border-danger-subtle" placeholder=" " style="height: 85px;" oninput="SOAPReactiveEngine.onAlergiasInput()">$alergias_val</textarea>
                            <label for="f_alergias">Ej. Penicilina, Betalactámicos, AINEs, Sulfas... o marque NKDA</label>
                        </div>
                        <div class="chip-bar">
                            <span class="chip-accelerator text-danger border-danger-subtle bg-danger-subtle" onclick="SOAPReactiveEngine.setAlergiaRapida('Penicilina / Betalactámicos')">⚠️ Alergia Penicilina</span>
                            <span class="chip-accelerator text-danger border-danger-subtle bg-danger-subtle" onclick="SOAPReactiveEngine.setAlergiaRapida('AINEs (Ibuprofeno / Ketorolaco / Naproxeno)')">⚠️ Alergia AINEs</span>
                            <span class="chip-accelerator text-danger border-danger-subtle bg-danger-subtle" onclick="SOAPReactiveEngine.setAlergiaRapida('Sulfonamidas / Trimetoprima')">⚠️ Alergia Sulfas</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.marcarNKDA()">✓ Negadas (NKDA)</span>
                        </div>
                    </div>

                    <div class="col-12 col-md-6">
                        <div class="d-flex justify-content-between align-items-center mb-1">
                            <span class="wizard-section-title">Antecedentes Personales Patológicos</span>
                            <div class="d-flex gap-1">
                                <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-2 py-0" onclick="toggleDictadoVoz('textarea[name=antecedentes_patologicos]', this)"><i class="bi bi-mic-fill"></i></button>
                                <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-0" onclick="limpiarCampoTexto('textarea[name=antecedentes_patologicos]'); SOAPReactiveEngine.syncAll();"><i class="bi bi-eraser-fill"></i></button>
                            </div>
                        </div>
                        <div class="form-floating">
                            <textarea name="antecedentes_patologicos" id="f_antecedentes_patologicos" class="form-control wizard-input" placeholder=" " style="height: 85px;" oninput="SOAPReactiveEngine.syncAll()">$patologicos_val</textarea>
                            <label for="f_antecedentes_patologicos">Crónico-degenerativos, quirúrgicos, hospitalizaciones...</label>
                        </div>
                        <div class="chip-bar">
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_antecedentes_patologicos', 'Niega crónico-degenerativos, quirúrgicos y transfusionales.')">⚡ Crónicos y Qx Negados</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_antecedentes_patologicos', 'Hipertensión Arterial Sistémica en tratamiento.')">⚡ HTA en control</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_antecedentes_patologicos', 'Diabetes Mellitus Tipo 2 en control.')">⚡ DM2 en control</span>
                        </div>
                    </div>

                    <!-- Resumen Compacto de Antecedentes del Expediente -->
                    <div class="col-12 mt-2">
                        <div class="p-2.5 rounded-3 bg-light border d-flex flex-wrap justify-content-between align-items-center gap-2">
                            <div class="d-flex flex-wrap gap-1 align-items-center">
                                <span class="small fw-semibold text-navy me-1"><i class="bi bi-journal-medical text-teal me-1"></i>Expediente:</span>
                                $hf_html $pp_html $pnp_html
                            </div>
                            <a href="crud_paciente.pl?accion=U&edit_id=$id_p&from=expediente" target="_blank" class="btn btn-xs btn-navy-outline rounded-pill px-2.5 py-0.5 fw-semibold" style="font-size:0.7rem;">
                                <i class="bi bi-pencil-square me-1"></i>Editar Ficha
                            </a>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Subcard 4: Bifurcación Legal — Consentimiento Informado Anticipado -->
            <div class="qx-subcard mb-3" style="border-left: 4px solid #0A2A66 !important;">
                <div class="d-flex align-items-center justify-content-between flex-wrap gap-2">
                    <div class="d-flex align-items-center gap-2.5">
                        <div class="p-2 bg-primary-subtle text-primary rounded-3">
                            <i class="bi bi-file-earmark-lock2-fill fs-5"></i>
                        </div>
                        <div>
                            <h6 class="fw-semibold mb-0 text-navy small">
                                ¿Requiere Procedimiento Invasivo Menor o Consentimiento Informado en esta Consulta? (NOM-004)
                            </h6>
                            <p class="text-muted mb-0" style="font-size:0.72rem;">
                                Si se activa, puede recabar la firma de Consentimiento Informado de forma anticipada antes de pasar a la Exploración (Paso 2) o vincularlo en el Paso 4.
                            </p>
                        </div>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <button type="button" id="btn-consentimiento-anticipado-p1" class="btn btn-sm btn-navy rounded-pill px-3 py-1 fw-semibold shadow-xs d-none" onclick="if(window.abrirModalNuevoConsentimientoWizard) window.abrirModalNuevoConsentimientoWizard();">
                            <i class="bi bi-pen-fill me-1"></i>Firmar Consentimiento Anticipado Ahora
                        </button>
                        <div class="form-check form-switch fs-5 mb-0">
                            <input class="form-check-input" type="checkbox" role="switch" id="check_requiere_consentimiento_registro" name="requiere_consentimiento_registro" value="1" onchange="SOAPReactiveEngine.toggleConsentimientoAnticipado(this.checked)">
                        </div>
                    </div>
                </div>
            </div>

            <div class="wizard-footer-nav justify-content-end">
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">
                    Continuar a Paso 2: Objetivo (O) y Estudios Previos <i class="bi bi-arrow-right ms-1"></i>
                </button>
            </div>
        </div>

        <script>
        function toggleConversionCheckbox() {
            const cotSelect = document.getElementById('f_id_cotizacion');
            const wrapper = document.getElementById('conversion_wrapper');
            const check = document.getElementById('f_convertir_tratamiento');
            if (!wrapper || !check) return;
            if (cotSelect && cotSelect.value) {
                wrapper.style.display = 'flex';
                check.checked = true;
                toggleConversionStyle();
            } else {
                wrapper.style.display = 'none';
                check.checked = false;
                toggleConversionStyle();
            }
        }
        function toggleConversionStyle() {
            const check = document.getElementById('f_convertir_tratamiento');
            const wrapper = document.getElementById('conversion_wrapper');
            if (!wrapper) return;
            if (check && check.checked) {
                wrapper.style.borderColor = 'var(--md-teal-clinical)';
                wrapper.style.background = '#f0fdfa';
            } else {
                wrapper.style.borderColor = '#dee2e6';
                wrapper.style.background = '#f8fafc';
            }
        }
        </script>
    };
}
1;
