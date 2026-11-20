use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use JSON qw(decode_json);
use Encode qw(encode_utf8);

sub render_step_exploracion {
    my ($paciente) = @_;
    $paciente //= {};
    my $id_paciente   = $paciente->{id_paciente} || $paciente->{id} || '';
    my $id_espe       = $paciente->{id_espe_medico} // '0';
    my $espe_nombre   = $paciente->{espe_nombre_medico} // 'Medicina General';
    my $is_odontologia = ($id_espe eq '100' || $espe_nombre =~ /Odontolog/i) ? 1 : 0;

    # 1. Cargar estudios PACS previos del paciente (dat/estudios.dat)
    my $ESTUDIOS_FILE_PATH = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
    my $todos_estudios = -f $ESTUDIOS_FILE_PATH ? utils::db_manager::leer_tabla($ESTUDIOS_FILE_PATH, '\|') : [];
    my @estudios_pac = grep { ($_->[1] // '') eq $id_paciente } @$todos_estudios;

    my $pacs_html = '';
    if (@estudios_pac) {
        $pacs_html .= qq{
            <div class="table-responsive rounded-3 border bg-white shadow-xs mt-2">
                <table class="table table-sm table-hover align-middle mb-0" id="tablaConsultaEstudiosPACS" style="width:100%">
                    <thead class="table-light small">
                        <tr>
                            <th class="ps-2" style="width: 60px;">Citar</th>
                            <th style="width: 90px;">Fecha</th>
                            <th style="width: 70px;">Mod.</th>
                            <th>Descripción del Estudio PACS</th>
                            <th class="text-end pe-2" style="width: 75px;">Visor</th>
                        </tr>
                    </thead>
                    <tbody class="small">
        };
        foreach my $est (@estudios_pac) {
            my $id_estudio = $est->[0];
            my $fecha      = $est->[2];
            my $modalidad  = $est->[3];
            my $desc       = $est->[4];
            my $safe_desc  = $desc; $safe_desc =~ s/"/&quot;/g; $safe_desc =~ s/'/&#39;/g;
            $pacs_html .= qq{
                <tr>
                    <td class="ps-2 text-center">
                        <input class="form-check-input pacs-chk" type="checkbox" name="pacs_estudios_seleccionados" value="$id_estudio" data-desc="$safe_desc" data-fecha="$fecha" data-mod="$modalidad" onchange="togglePacsToGabinete(this)">
                    </td>
                    <td class="fw-bold text-muted">$fecha</td>
                    <td><span class="badge bg-info-subtle text-info border border-info-subtle">$modalidad</span></td>
                    <td class="fw-bold text-dark">$desc</td>
                    <td class="text-end pe-2">
                        <a href="render_visor_medico.pl?id=$id_paciente&estudio_id=$id_estudio" target="_blank" class="btn btn-xs btn-outline-primary rounded-pill px-2 py-0.5" title="Abrir Visor DICOM"><i class="bi bi-box-arrow-up-right"></i></a>
                    </td>
                </tr>
            };
        }
        $pacs_html .= qq{
                    </tbody>
                </table>
            </div>
        };
    } else {
        $pacs_html = qq{
            <div class="p-2 px-3 rounded-3 bg-light border small text-muted d-flex justify-content-between align-items-center mt-2">
                <span><i class="bi bi-display me-1.5 text-teal"></i>Sin estudios DICOM en <code>estudios.dat</code>. Puede consultar laboratorios e historial en la <strong>Bóveda del Paciente</strong>.</span>
                <button type="button" class="btn btn-xs btn-outline-primary rounded-pill px-2.5 py-0.5 fw-bold" onclick="BovedaService.openDrawer('LAB')">
                    <i class="bi bi-folder2-open me-1"></i>Ver Labs en Bóveda
                </button>
            </div>
        };
    }

    # 2. Cargar catálogo de odontogramas del paciente (dat/odontogramas/paciente_<id>.json)
    my @odontogramas_pac;
    if ($id_paciente) {
        my $dir_json = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'odontogramas');
        my $archivo_json = File::Spec->catfile($dir_json, "paciente_${id_paciente}.json");
        my $archivo_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');

        if (-e $archivo_json) {
            my $json_raw = '';
            if (open my $fh, '<:raw', $archivo_json) {
                local $/;
                $json_raw = <$fh>;
                close $fh;
            }
            my $parsed = eval { decode_json($json_raw) };
            if ($parsed && ref($parsed) eq 'HASH') {
                if (exists $parsed->{odontogramas} && ref($parsed->{odontogramas}) eq 'ARRAY') {
                    @odontogramas_pac = @{ $parsed->{odontogramas} };
                } elsif (exists $parsed->{teeth} && ref($parsed->{teeth}) eq 'HASH') {
                    push @odontogramas_pac, {
                        id_odonto => "OD-${id_paciente}-1",
                        alias     => $parsed->{alias} || 'Diagnóstico Inicial',
                        fecha     => $parsed->{fechaLocal} || $parsed->{updatedAt} || 'Recientemente',
                        estado    => $parsed->{estado} || 'En Proceso',
                        importe   => $parsed->{financialTotalPending} || 0,
                        teeth     => $parsed->{teeth} || {}
                    };
                }
            }
        }
        if (!@odontogramas_pac && -e $archivo_dat) {
            my $registros = eval { utils::db_manager::leer_tabla($archivo_dat, '\|') } || [];
            my %teeth_found;
            my $fecha_found = '';
            my $alias_found = 'Diagnóstico Base';
            foreach my $fila (@$registros) {
                if (($fila->[0] // '') eq $id_paciente) {
                    $alias_found = $fila->[1] if $fila->[1];
                    $fecha_found = $fila->[2] if $fila->[2];
                    for (my $i = 4; $i < @$fila; $i++) {
                        if ($fila->[$i] =~ /^(\d+)=(.+)$/) {
                            my $tooth = $1;
                            my $val_hash = eval { decode_json(encode_utf8($2)) } || {};
                            $teeth_found{$tooth} = $val_hash;
                        }
                    }
                }
            }
            if (%teeth_found || $fecha_found) {
                push @odontogramas_pac, {
                    id_odonto => "OD-${id_paciente}-1",
                    alias     => $alias_found,
                    fecha     => $fecha_found || 'Recientemente',
                    estado    => 'En Proceso',
                    importe   => 0.00,
                    teeth     => \%teeth_found
                };
            }
        }
    }

    my $odonto_html = '';
    if (@odontogramas_pac) {
        my $header_odonto = $is_odontologia
            ? qq{
                <div class="d-flex align-items-center justify-content-between mb-2 flex-wrap gap-2">
                    <span class="qx-subcard-title mb-0 border-0 pb-0"><i class="bi bi-journal-medical text-teal me-1.5"></i>Odontogramas Clínicos Disponibles ($espe_nombre)</span>
                    <div class="d-flex align-items-center gap-2 flex-wrap">
                        <a href="render_visor_odontograma.pl?id=$id_paciente" target="_blank" class="btn btn-xs btn-outline-primary rounded-pill px-2.5 py-0.5 fw-bold">
                            <i class="bi bi-plus-circle me-1"></i>Nuevo Odontograma
                        </a>
                        <div class="form-check form-switch bg-light px-2.5 py-0.5 rounded-pill border mb-0">
                            <input class="form-check-input ms-0 me-1.5" type="checkbox" name="odonto_finalizar_al_cerrar" id="odonto_finalizar_al_cerrar" value="1" checked>
                            <label class="form-check-label small fw-bold text-navy" for="odonto_finalizar_al_cerrar" style="font-size:0.7rem;">Finalizar al cerrar</label>
                        </div>
                    </div>
                </div>
            }
            : qq{<div class="qx-subcard-title"><i class="bi bi-journal-medical text-teal me-1.5"></i>Odontogramas Clínicos Disponibles</div>};

        $odonto_html .= qq{
            <div class="qx-subcard mb-3">
                $header_odonto
                <div class="table-responsive">
                    <table class="table table-sm table-hover align-middle mb-0" id="tablaConsultaOdontogramas" style="width:100%">
                        <thead class="table-light small">
                            <tr>
                                <th class="ps-2" style="width: 55px;">Asignar</th>
                                <th style="width: 95px;">Fecha</th>
                                <th style="width: 95px;">Estado</th>
                                <th>Descripción / Alias</th>
                                <th class="text-end pe-2" style="width: 130px;">Acciones</th>
                            </tr>
                        </thead>
                        <tbody class="small">
        };
        foreach my $od (@odontogramas_pac) {
            my $id_odonto  = $od->{id_odonto} || "OD-${id_paciente}-1";
            my $alias      = $od->{alias} || 'Odontograma Clínico';
            my $fecha      = $od->{fecha} || 'Sin fecha';
            my $estado     = $od->{estado} || 'En Proceso';
            my $importe    = sprintf("%.2f", $od->{importe} || 0);
            my $cnt_piezas = (ref($od->{teeth}) eq 'HASH') ? scalar(keys %{ $od->{teeth} }) : 0;

            my $badge_estado = '<span class="badge bg-secondary-subtle text-secondary border px-2 py-0.5">Histórico</span>';
            if ($estado =~ /En Proceso|Activo/i) {
                $badge_estado = '<span class="badge bg-warning-subtle text-warning-emphasis border border-warning-subtle px-2 py-0.5">En Proceso</span>';
            } elsif ($estado =~ /Finalizado|Completado/i) {
                $badge_estado = '<span class="badge bg-success-subtle text-success border border-success-subtle px-2 py-0.5">Finalizado</span>';
            }

            my $safe_alias = $alias; $safe_alias =~ s/"/&quot;/g; $safe_alias =~ s/'/&#39;/g;
            my $btn_evolucion = $is_odontologia
                ? qq{<button type="button" class="btn btn-xs btn-outline-primary rounded-pill px-2 py-0.5 fw-bold" style="font-size:0.68rem;" onclick="crearEvolucionOdonto('$id_odonto', '$safe_alias')"><i class="bi bi-copy me-1"></i>Evolución</button>}
                : '';

            $odonto_html .= qq{
                <tr>
                    <td class="ps-2 text-center">
                        <input class="form-check-input odonto-chk" type="checkbox" name="odonto_estudios_seleccionados" value="$id_odonto" data-alias="$safe_alias" data-fecha="$fecha" data-piezas="$cnt_piezas" data-importe="$importe" onchange="toggleOdontoToExploracion(this)">
                    </td>
                    <td class="fw-bold text-muted">$fecha</td>
                    <td>$badge_estado</td>
                    <td>
                        <div class="fw-bold text-dark">$alias</div>
                        <div class="text-muted" style="font-size:0.7rem;">#$id_odonto &bull; $cnt_piezas piezas &bull; <span class="text-danger fw-bold">\$$importe MXN</span></div>
                    </td>
                    <td class="text-end pe-2">
                        <div class="d-inline-flex align-items-center gap-1">
                            $btn_evolucion
                            <a href="render_visor_odontograma.pl?id=$id_paciente&id_odonto=$id_odonto" target="_blank" class="btn btn-xs btn-light border rounded-pill px-2 py-0.5" title="Abrir Visor Dental"><i class="bi bi-box-arrow-up-right"></i></a>
                        </div>
                    </td>
                </tr>
            };
        }
        $odonto_html .= qq{
                        </tbody>
                    </table>
                </div>
            </div>
        };
    } elsif ($is_odontologia) {
        $odonto_html = qq{
            <div class="qx-subcard mb-3 d-flex justify-content-between align-items-center flex-wrap gap-2">
                <div>
                    <span class="fw-bold text-navy small"><i class="bi bi-journal-medical text-teal me-1.5"></i>Especialidad Odontología — Sin odontogramas previos</span>
                    <p class="text-muted small mb-0" style="font-size:0.72rem;">Puede crear un odontograma inicial para este paciente en el Visor FDI.</p>
                </div>
                <a href="render_visor_odontograma.pl?id=$id_paciente" target="_blank" class="btn btn-sm btn-primary rounded-pill px-3 fw-bold">
                    <i class="bi bi-plus-circle me-1"></i>Crear Odontograma Inicial
                </a>
            </div>
        };
    }

    # 3. Subformulario Polimórfico de Especialidad (Regla de Oro SOAP #1 y #3)
    my $seccion_especialidad = '';
    if (!$is_odontologia) {
        $seccion_especialidad = qq{
            <div class="qx-subcard mb-3" id="especialidad-subformulario-container">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center">
                    <span><i class="bi bi-diagram-3-fill text-teal me-1.5"></i>Plugin Slot: Exploración Dirigida ($espe_nombre)</span>
                    <span class="badge bg-info text-dark fw-bold">soap.objective.especialidad_data</span>
                </div>
                <div class="row g-2 align-items-center">
                    <div class="col-12 col-md-8">
                        <label class="wizard-label">Notas Específicas de Especialidad ($espe_nombre)</label>
                        <input type="text" id="f_esp_nota_especifica" class="wizard-input" placeholder="Hallazgos o escalas específicas de $espe_nombre..." oninput="SOAPReactiveEngine.syncEspecialidadData()">
                    </div>
                    <div class="col-12 col-md-4">
                        <label class="wizard-label">Estado Funcional Especialidad</label>
                        <select id="f_esp_estado_funcional" class="wizard-input" onchange="SOAPReactiveEngine.syncEspecialidadData()">
                            <option value="Conservado / Sin compromiso">Conservado / Sin compromiso</option>
                            <option value="Alteración Leve">Alteración Leve</option>
                            <option value="Alteración Moderada">Alteración Moderada</option>
                            <option value="Compromiso Severo">Compromiso Severo</option>
                        </select>
                    </div>
                </div>
            </div>
        };
    }

    return qq{
        <div class="wizard-panel" id="step-panel-1" data-step-index="1">
            <input type="hidden" name="exploracion_cefalocaudal_json" id="f_exploracion_cefalocaudal_json" value="{}">
            <input type="hidden" name="especialidad_data_json" id="f_especialidad_data_json" value="{}">

            <!-- Encabezado de Paso 2 + Aceleradores de 1 Clic -->
            <div class="d-flex justify-content-between align-items-center border-bottom pb-2.5 mb-3 flex-wrap gap-2">
                <div>
                    <h5 class="fw-bold text-navy mb-0">
                        <i class="bi bi-activity me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>Paso 2: Objetivo (O), Triage Semaforizado y Estudios Previos
                    </h5>
                    <p class="text-muted small mb-0">6 Signos Vitales + IMC OMS en vivo, Exploración Cefalocaudal por excepción y acceso contextual a Bóveda.</p>
                </div>
                <div class="d-flex align-items-center gap-1.5 flex-wrap">
                    <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-2.5 py-1 fw-bold shadow-xs btn-accelerator-action" onclick="SOAPReactiveEngine.copiarSignosBasales()" title="Importar peso, T.A. y F.C. de la consulta previa">
                        <i class="bi bi-clock-history me-1"></i>Copiar Basales
                    </button>
                    <button type="button" class="btn btn-sm btn-success rounded-pill px-3 py-1 fw-bold shadow-sm btn-accelerator-action" onclick="SOAPReactiveEngine.aplicarTodoNormal()" title="Rellenar signos vitales normales, inspección general, cefalocaudal y hallazgos base en 1 clic">
                        <i class="bi bi-lightning-charge-fill me-1"></i>⚡ Todo Normal (1 Clic)
                    </button>
                    <span class="badge bg-primary-subtle text-primary fw-bold">Paso 2 de 6</span>
                </div>
            </div>

            <!-- Subcard 1: Motor de Triage (6 Signos Vitales Semaforizados + Peso/Talla/IMC OMS) -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <span><i class="bi bi-heart-pulse-fill text-danger me-1.5"></i>1. Motor de Triage Fisiológico (6 Signos Vitales + IMC OMS)</span>
                    <span id="triage-global-badge" class="badge bg-secondary rounded-pill">Pendiente de captura</span>
                </div>

                <div class="row g-2">
                    <!-- 1. T.A. -->
                    <div class="col-6 col-md-3">
                        <div class="vital-sign-card" id="vcard-ta">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <label class="wizard-label mb-0">1. T.A. (mmHg)</label>
                                <span id="vbadge-ta" class="vital-status-pill bg-light text-muted">--</span>
                            </div>
                            <input type="text" name="ta" id="ef_ta" class="wizard-input text-center fw-bold" placeholder="120/80" oninput="SOAPReactiveEngine.evaluateTriage()">
                        </div>
                    </div>

                    <!-- 2. F.C. -->
                    <div class="col-6 col-md-3">
                        <div class="vital-sign-card" id="vcard-fc">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <label class="wizard-label mb-0">2. F.C. (lpm)</label>
                                <span id="vbadge-fc" class="vital-status-pill bg-light text-muted">--</span>
                            </div>
                            <input type="number" name="fc" id="ef_fc" class="wizard-input text-center fw-bold" placeholder="72" oninput="SOAPReactiveEngine.evaluateTriage()">
                        </div>
                    </div>

                    <!-- 3. F.R. -->
                    <div class="col-6 col-md-3">
                        <div class="vital-sign-card" id="vcard-fr">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <label class="wizard-label mb-0">3. F.R. (rpm)</label>
                                <span id="vbadge-fr" class="vital-status-pill bg-light text-muted">--</span>
                            </div>
                            <input type="number" name="fr" id="ef_fr" class="wizard-input text-center fw-bold" placeholder="16" oninput="SOAPReactiveEngine.evaluateTriage()">
                        </div>
                    </div>

                    <!-- 4. Temp -->
                    <div class="col-6 col-md-3">
                        <div class="vital-sign-card" id="vcard-temp">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <label class="wizard-label mb-0">4. Temp (°C)</label>
                                <span id="vbadge-temp" class="vital-status-pill bg-light text-muted">--</span>
                            </div>
                            <input type="number" step="0.1" name="temp" id="ef_temp" class="wizard-input text-center fw-bold" placeholder="36.5" oninput="SOAPReactiveEngine.evaluateTriage()">
                        </div>
                    </div>

                    <!-- 5. SpO2 -->
                    <div class="col-6 col-md-3">
                        <div class="vital-sign-card" id="vcard-spo2">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <label class="wizard-label mb-0">5. SpO₂ (%)</label>
                                <span id="vbadge-spo2" class="vital-status-pill bg-light text-muted">--</span>
                            </div>
                            <input type="number" name="spo2" id="ef_spo2" class="wizard-input text-center fw-bold" placeholder="98" oninput="SOAPReactiveEngine.evaluateTriage()">
                        </div>
                    </div>

                    <!-- 6. Glucosa Capilar + Selector Ayuno / Posprandial -->
                    <div class="col-6 col-md-3">
                        <div class="vital-sign-card" id="vcard-glucosa">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <label class="wizard-label mb-0">6. Glucosa (mg/dL)</label>
                                <span id="vbadge-glucosa" class="vital-status-pill bg-light text-muted">--</span>
                            </div>
                            <div class="input-group input-group-sm">
                                <input type="number" name="glucosa" id="ef_glucosa" class="form-control fw-bold text-center" placeholder="92" oninput="SOAPReactiveEngine.evaluateTriage()">
                                <select name="glucosa_tipo" id="ef_glucosa_tipo" class="form-select fw-bold px-1" style="max-width: 82px; font-size:0.7rem;" onchange="SOAPReactiveEngine.evaluateTriage()">
                                    <option value="AYUNO">Ayuno</option>
                                    <option value="POSPRANDIAL">Pospr.</option>
                                </select>
                            </div>
                        </div>
                    </div>

                    <!-- Somatometría: Peso, Talla e IMC OMS Automático -->
                    <div class="col-4 col-md-2">
                        <div class="vital-sign-card">
                            <label class="wizard-label mb-1">Peso (kg)</label>
                            <input type="number" step="0.1" name="peso" id="ef_peso" class="wizard-input text-center fw-bold" placeholder="72.0" oninput="SOAPReactiveEngine.evaluateTriage()">
                        </div>
                    </div>
                    <div class="col-4 col-md-2">
                        <div class="vital-sign-card">
                            <label class="wizard-label mb-1">Talla (cm)</label>
                            <input type="number" step="1" name="talla" id="ef_talla" class="wizard-input text-center fw-bold" placeholder="170" oninput="SOAPReactiveEngine.evaluateTriage()">
                        </div>
                    </div>
                    <div class="col-4 col-md-2">
                        <div class="vital-sign-card" id="vcard-imc">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <label class="wizard-label mb-0">IMC OMS</label>
                                <span id="vbadge-imc" class="vital-status-pill bg-light text-muted">--</span>
                            </div>
                            <input type="text" name="imc" id="ef_imc" class="wizard-input text-center fw-bold bg-light" readonly placeholder="--">
                        </div>
                    </div>
                </div>
            </div>

            <!-- Subcard 2: Inspección General y Exploración Cefalocaudal Rápida -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <span><i class="bi bi-person-bounding-box text-teal me-1.5"></i>2. Inspección General, Exploración Cefalocaudal y Hallazgos</span>
                    <span class="small text-muted">Modifique únicamente los segmentos con hallazgos patológicos</span>
                </div>

                <div class="row g-2.5">
                    <div class="col-12 col-md-4">
                        <label class="wizard-label">Habitus Exterior / Inspección General</label>
                        <input type="text" name="inspeccion_general" id="ef_inspeccion_general" class="wizard-input" placeholder="Consciente, orientado, Glasgow 15, hidratado..." oninput="SOAPReactiveEngine.syncCefalocaudal()">
                    </div>
                    <div class="col-6 col-md-4">
                        <label class="wizard-label">Cabeza, Cuello y ORL</label>
                        <input type="text" id="cef_cabeza_cuello" class="wizard-input" placeholder="Normocéfalo, faringe sin exudados, cuello sin adenopatías..." oninput="SOAPReactiveEngine.syncCefalocaudal()">
                    </div>
                    <div class="col-6 col-md-4">
                        <label class="wizard-label">Tórax y Cardiopulmonar</label>
                        <input type="text" id="cef_torax" class="wizard-input" placeholder="Murmullo vesicular normal, ruidos cardíacos rítmicos..." oninput="SOAPReactiveEngine.syncCefalocaudal()">
                    </div>
                    <div class="col-6 col-md-4">
                        <label class="wizard-label">Abdomen</label>
                        <input type="text" id="cef_abdomen" class="wizard-input" placeholder="Blando, depresible, no doloroso, peristalsis normal..." oninput="SOAPReactiveEngine.syncCefalocaudal()">
                    </div>
                    <div class="col-6 col-md-4">
                        <label class="wizard-label">Extremidades y Columna</label>
                        <input type="text" id="cef_extremidades" class="wizard-input" placeholder="Íntegras, simétricas, sin edema, llenado capilar <2s..." oninput="SOAPReactiveEngine.syncCefalocaudal()">
                    </div>
                    <div class="col-12 col-md-4">
                        <label class="wizard-label">Neurológico y Piel</label>
                        <input type="text" id="cef_neuro" class="wizard-input" placeholder="Pares craneales íntegros, sin focalización..." oninput="SOAPReactiveEngine.syncCefalocaudal()">
                    </div>

                    <!-- Narrativa Consolidada de Hallazgos Clínicos (Obligatoria) -->
                    <div class="col-12 mt-2">
                        <div class="d-flex justify-content-between align-items-center mb-1 flex-wrap gap-1">
                            <label class="wizard-label mb-0">Hallazgos Clínicos de Exploración Física <span class="req-star">*</span></label>
                            <div class="d-flex align-items-center gap-1">
                                <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-2.5 py-0.5 shadow-xs d-inline-flex align-items-center" onclick="toggleDictadoVoz('textarea[name=exploracion_hallazgos]', this)">
                                    <i class="bi bi-mic-fill me-1"></i><span class="btn-dictado-text fw-bold">Dictar</span>
                                </button>
                                <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-0.5 shadow-xs d-inline-flex align-items-center" onclick="limpiarCampoTexto('textarea[name=exploracion_hallazgos]'); SOAPReactiveEngine.syncAll();">
                                    <i class="bi bi-eraser-fill me-1"></i><span class="small fw-semibold">Limpiar</span>
                                </button>
                            </div>
                        </div>
                        <textarea name="exploracion_hallazgos" id="f_exploracion_hallazgos" class="wizard-input" rows="3" placeholder="Describa los hallazgos relevantes de la exploración física o pulse ⚡ Todo Normal..." required oninput="SOAPReactiveEngine.syncAll()"></textarea>
                        <div class="dictado-live-badge text-danger fw-bold mt-1 d-none align-items-center gap-2">
                            <span class="spinner-grow spinner-grow-sm text-danger"></span><span>Escuchando dictado...</span>
                        </div>
                        <div class="chip-bar">
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_exploracion_hallazgos', 'Faringe hiperémica con exudado amigdalino bilateral y adenopatía cervical dolorosa.')">⚡ Faringe hiperémica + exudado</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_exploracion_hallazgos', 'Abdomen blando con dolor a la palpación media en epigastrio, Murphy y McBurney negativos.')">⚡ Dolor epigástrico sin irritación</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_exploracion_hallazgos', 'Contractura muscular paravertebral lumbar bilateral, Lasègue negativo, fuerza 5/5.')">⚡ Contractura lumbar Lasègue (-)</span>
                            <span class="chip-accelerator" onclick="SOAPReactiveEngine.appendChip('f_exploracion_hallazgos', 'Cavidad oral con lesión cariosa profunda en órgano dentario, sensible a percusión.')">⚡ Hallazgo dental / caries</span>
                        </div>
                    </div>
                </div>
            </div>

            $seccion_especialidad
            $odonto_html

            <!-- Subcard 3: Estudios Previos, PACS y Enlace Contextual a Bóveda -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center flex-wrap gap-2">
                    <span><i class="bi bi-file-earmark-medical-fill text-teal me-1.5"></i>3. Interpretación de Estudios Previos (PACS / Laboratorio / Bóveda)</span>
                    <div class="d-flex gap-1.5">
                        <button type="button" class="btn btn-xs btn-outline-primary rounded-pill px-2.5 py-0.5 fw-bold" onclick="BovedaService.openDrawer('PACS')">
                            <i class="bi bi-images me-1"></i>Abrir PACS en Bóveda
                        </button>
                        <button type="button" class="btn btn-xs btn-outline-teal rounded-pill px-2.5 py-0.5 fw-bold" style="border-color:#19B7A5;color:#0f766e;" onclick="BovedaService.openDrawer('LAB')">
                            <i class="bi bi-eyedropper me-1"></i>Ver Laboratorios Previos
                        </button>
                    </div>
                </div>

                $pacs_html

                <div class="mt-2.5">
                    <div class="d-flex justify-content-between align-items-center mb-1">
                        <label class="wizard-label mb-0">Resultados Previos / Observaciones de Estudios</label>
                        <div class="d-flex gap-1">
                            <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-2 py-0" onclick="toggleDictadoVoz('textarea[name=resultados_estudios]', this)"><i class="bi bi-mic-fill"></i></button>
                            <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-0" onclick="limpiarCampoTexto('textarea[name=resultados_estudios]'); SOAPReactiveEngine.syncAll();"><i class="bi bi-eraser-fill"></i></button>
                        </div>
                    </div>
                    <textarea name="resultados_estudios" id="f_resultados_estudios" class="wizard-input" rows="2" placeholder="Interprete aquí estudios previos o use el botón 'Citar en Nota Actual' desde la Bóveda (Alt+B)..." oninput="SOAPReactiveEngine.syncAll()"></textarea>
                </div>
            </div>

            <div class="d-flex justify-content-between mt-3 pt-2 border-top">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()">
                    <i class="bi bi-arrow-left me-1"></i> Paso 1: Subjetivo
                </button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">
                    Continuar a Paso 3: Análisis (A), Plan (P) y Receta <i class="bi bi-arrow-right ms-1"></i>
                </button>
            </div>
        </div>

        <script>
            window.PACIENTE_ID_ODONTO = '$id_paciente';

            function togglePacsToGabinete(chk) {
                const desc = chk.getAttribute('data-desc') || '';
                const fecha = chk.getAttribute('data-fecha') || '';
                const mod = chk.getAttribute('data-mod') || '';
                const text = `[Ref. PACS · \${mod} · \${fecha}] \${desc}`;
                const textarea = document.getElementById('f_resultados_estudios');
                if (!textarea) return;
                if (chk.checked) {
                    if (!textarea.value.includes(text)) {
                        textarea.value = (textarea.value.trim() ? textarea.value.trim() + "\\n" : "") + text;
                    }
                } else {
                    textarea.value = textarea.value.replace(text, '').trim();
                }
                textarea.dispatchEvent(new Event('input'));
            }

            function toggleOdontoToExploracion(chk) {
                const alias = chk.getAttribute('data-alias') || 'Odontograma Clínico';
                const fecha = chk.getAttribute('data-fecha') || '';
                const piezas = chk.getAttribute('data-piezas') || '0';
                const importe = chk.getAttribute('data-importe') || '0.00';
                const text = `[Odontograma Clínico - \${alias} - \${fecha} - \${piezas} piezas - Presupuesto: \\\$\${importe} MXN]`;
                const textarea = document.getElementById('f_exploracion_hallazgos');
                if (!textarea) return;
                if (chk.checked) {
                    if (!textarea.value.includes(text)) {
                        textarea.value = (textarea.value.trim() ? textarea.value.trim() + "\\n" : "") + text;
                    }
                } else {
                    textarea.value = textarea.value.replace(text, '').trim();
                }
                textarea.dispatchEvent(new Event('input'));
                if (typeof verificarOdontoParaCaja === 'function') {
                    verificarOdontoParaCaja();
                }
            }

            async function crearEvolucionOdonto(idFuente, aliasFuente) {
                if (typeof Swal === 'undefined') return;
                const { value: nuevoAlias } = await Swal.fire({
                    title: 'Crear Evolución Clínica Dental',
                    html: `Se creará una copia de <b>\${aliasFuente || 'Odontograma Base'}</b> para registrar los procedimientos realizados hoy.`,
                    input: 'text',
                    inputValue: 'Evolución - ' + new Date().toLocaleDateString('es-MX'),
                    showCancelButton: true,
                    confirmButtonText: '<i class="bi bi-copy me-1"></i> Crear y Asignar',
                    confirmButtonColor: '#19B7A5'
                });
                if (!nuevoAlias) return;
                try {
                    const fd = new FormData();
                    fd.append('accion', 'clone');
                    fd.append('id_paciente', window.PACIENTE_ID_ODONTO || '$id_paciente');
                    fd.append('id_odonto', idFuente);
                    fd.append('alias', nuevoAlias);
                    const res = await fetch('../api/odontograma_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' });
                    const data = await res.json();
                    if (data.ok) {
                        Swal.fire('¡Evolución Creada!', `Se creó \${data.alias}.`, 'success').then(() => {
                            window.location.reload();
                        });
                    } else {
                        Swal.fire('Error', data.error || 'No se pudo clonar', 'error');
                    }
                } catch (err) {
                    Swal.fire('Error', 'Fallo de conexión: ' + err.message, 'error');
                }
            }
        </script>
    };
}
1;
