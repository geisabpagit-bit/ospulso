use strict;
use warnings;
use utf8;

sub render_step_comunicacion {
    my ($paciente) = @_;
    my $id_p = $paciente ? ($paciente->{id_paciente} || '') : '';

    my $html = qq{
        <div class="wizard-panel" id="step-panel-5" data-id-paciente="$id_p">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-chat-heart me-2" style="color: var(--md-teal-clinical);"></i>Comunicaci&oacute;n del Plan
            </h3>
            
            <div class="row g-4">
                <div class="col-12">
                    <p class="text-muted mb-4 fw-bold">Registro de la interacci&oacute;n m&eacute;dico-paciente para blindaje m&eacute;dico-legal.</p>
                </div>
                
                <div class="col-12">
                    <div class="form-check mb-3">
                        <input class="form-check-input wizard-input-check" type="checkbox" name="com_explicacion" value="1" id="c_exp" required>
                        <label class="form-check-label fw-bold" for="c_exp">
                            Se explic&oacute; detalladamente el diagn&oacute;stico y abordaje al paciente. <span class="req-star">*</span>
                        </label>
                    </div>
                    <div class="form-check mb-3">
                        <input class="form-check-input wizard-input-check" type="checkbox" name="com_riesgos" value="1" id="c_ries">
                        <label class="form-check-label fw-bold" for="c_ries">
                            Se informaron los riesgos asociados a su condici&oacute;n / tratamiento.
                        </label>
                    </div>
                    <div class="form-check mb-3">
                        <input class="form-check-input wizard-input-check" type="checkbox" name="com_dudas" value="1" id="c_dud" required>
                        <label class="form-check-label fw-bold" for="c_dud">
                            El paciente expres&oacute; entender las indicaciones y se resolvieron sus dudas. <span class="req-star">*</span>
                        </label>
                    </div>
                </div>
                
                <div class="col-12 mt-4">
                    <div class="d-flex justify-content-between align-items-center mb-1 flex-wrap gap-2">
                        <label class="wizard-label mb-0">Observaciones Adicionales de la Interacci&oacute;n</label>
                        <div class="d-flex align-items-center gap-1">
                            <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-3 py-1 shadow-xs d-inline-flex align-items-center" onclick="toggleDictadoVoz('textarea[name=com_observaciones]', this)" title="Dictar observaciones por voz con micrófono">
                                <i class="bi bi-mic-fill me-1"></i>
                                <span class="btn-dictado-text fw-bold">Dictar</span>
                            </button>
                            <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-1 shadow-xs d-inline-flex align-items-center" onclick="limpiarCampoTexto('textarea[name=com_observaciones]')" title="Limpiar observaciones">
                                <i class="bi bi-eraser-fill me-1"></i>
                                <span class="small fw-semibold">Limpiar</span>
                            </button>
                        </div>
                    </div>
                    <div class="position-relative">
                        <textarea name="com_observaciones" class="wizard-input" rows="3" placeholder="Comentarios sobre la recepci&oacute;n de las noticias por parte del paciente o familiares o dicte usando el micr&oacute;fono..."></textarea>
                        <div class="dictado-live-badge text-danger fw-bold mt-2 d-none align-items-center gap-2">
                            <span class="spinner-grow spinner-grow-sm text-danger" role="status" aria-hidden="true"></span>
                            <span>Escuchando... Hable claramente al micr&oacute;fono de su dispositivo (haga clic en 'Detener Dictado' para pausar).</span>
                        </div>
                    </div>
                </div>

                <!-- Módulo de Consentimiento Informado Oficial (Tabla Dinámica Ámbito: Consulta) -->
                <div class="col-12 mt-4">
                    <input type="hidden" name="id_consentimiento_vinculado" id="id_consentimiento_vinculado" value="">
                    <input type="hidden" name="requiere_consentimiento" id="check_requiere_consentimiento" value="1">

                    <div class="card-medentia-aura border-0 bg-white p-4 rounded-4 shadow-sm">
                        <div class="d-flex align-items-center justify-content-between mb-3 flex-wrap gap-2">
                            <div>
                                <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">
                                    <i class="bi bi-file-earmark-medical me-2 text-primary"></i>Expediente Legal & Consentimientos (Uso en Consulta)
                                </h5>
                                <small class="text-muted">Documentos oficiales archivados en el repositorio atómico del paciente</small>
                            </div>
                            <div class="d-flex align-items-center gap-2">
                                <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill px-3 shadow-xs" onclick="cargarConsentimientosWizard()">
                                    <i class="bi bi-arrow-clockwise me-1"></i> Actualizar
                                </button>
                                <button type="button" id="btn-emitir-cons-wizard" class="btn btn-sm btn-primary rounded-pill px-3.5 py-1.5 fw-bold shadow-sm d-flex align-items-center gap-1.5" onclick="abrirModalNuevoConsentimientoWizard()">
                                    <i class="bi bi-plus-circle-fill"></i> + Emitir Nuevo Consentimiento
                                </button>
                            </div>
                        </div>

                        <!-- Estado Inhabilitado / Prescindible -->
                        <div id="aviso-consentimiento-inhabilitado" class="alert alert-light border d-flex align-items-center justify-content-between p-3 rounded-4 text-muted mb-0 shadow-xs" style="display: none;">
                            <div class="d-flex align-items-center gap-3">
                                <i class="bi bi-shield-slash fs-3 text-secondary"></i>
                                <div>
                                    <span class="fw-bold d-block text-dark small">Documentación Legal Inhabilitada</span>
                                    <span class="small text-muted">Esta consulta fue configurada en el Paso 0 (Registro) como rutinaria y prescinde de consentimientos legales.</span>
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold" onclick="habilitarConsentimientoDesdePaso5()">
                                <i class="bi bi-toggle-on me-1"></i> Habilitar para esta Consulta
                            </button>
                        </div>

                        <!-- Tabla de Consentimientos de Consulta -->
                        <div id="seccion-consentimiento-tabla">
                            <div class="table-responsive rounded-3 border bg-white shadow-xs">
                                <table class="table table-hover align-middle mb-0" id="tablaConsentimientosWizard">
                                    <thead class="table-light">
                                        <tr class="small text-secondary fw-bold">
                                            <th>FOLIO</th>
                                            <th>FECHA / HORA</th>
                                            <th>PROCEDIMIENTO</th>
                                            <th>MÉDICO RESPONSABLE</th>
                                            <th>SEMÁFORO USO</th>
                                            <th class="text-end">ACCIÓN / VINCULAR</th>
                                        </tr>
                                    </thead>
                                    <tbody id="tbodyConsentimientosWizard" class="small">
                                        <tr>
                                            <td colspan="6" class="text-center py-4 text-muted">
                                                <div class="spinner-border spinner-border-sm text-primary me-2"></div>
                                                Consultando registros de consentimientos...
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                            <div id="aviso-consentimiento-seleccionado" class="mt-2.5 p-2 px-3 rounded-3 bg-primary bg-opacity-10 border border-primary border-opacity-25 small text-primary fw-bold d-none align-items-center justify-content-between">
                                <span><i class="bi bi-check-circle-fill me-1.5 text-primary"></i> <span id="txt-consentimiento-vinculado">Consentimiento vinculado exitosamente a esta consulta</span></span>
                                <button type="button" class="btn btn-xs btn-link text-danger p-0 fw-bold text-decoration-none" onclick="desvincularConsentimiento()">Desvincular</button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Caja <i class="bi bi-arrow-right ms-2"></i></button>
            </div>

            <!-- MODAL COMPACTO: EMISIÓN RÁPIDA DE CONSENTIMIENTO EN WIZARD -->
            <div class="modal fade" id="modalNuevoConsentimientoWizard" tabindex="-1" aria-hidden="true" style="z-index: 105250 !important;">
                <div class="modal-dialog modal-dialog-centered" style="max-width: 640px;">
                    <div class="modal-content rounded-4 border-0 shadow-lg overflow-hidden">
                        <div class="modal-header px-4 py-2.5" style="background: #0A2A66; color: #ffffff;">
                            <div class="d-flex align-items-center gap-2">
                                <i class="bi bi-file-earmark-medical text-warning fs-5"></i>
                                <div>
                                    <h6 class="modal-title fw-bold text-white mb-0">Emitir Consentimiento (Uso Consulta)</h6>
                                    <small class="text-white-50" style="font-size: 0.72rem;">Normativa Oficial NOM-004-SSA3</small>
                                </div>
                            </div>
                            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                        </div>
                        <div class="modal-body p-3 p-md-4 bg-light">
                            <form id="formNuevoConsentimientoWizard" onsubmit="guardarNuevoConsentimientoWizard(event)">
                                <input type="hidden" name="id_paciente" id="wiz_cons_id_paciente" value="$id_p">
                                <input type="hidden" name="ambito_uso" value="USO_CONSULTA">
                                <input type="hidden" name="tipo_consentimiento" value="CONSULTA_PROCEDIMIENTO">
                                <input type="hidden" id="wiz_firma_paciente" name="firma_paciente_data" value="">
                                <input type="hidden" id="wiz_firma_medico" name="firma_medico_data" value="">

                                <div class="row g-2.5">
                                    <div class="col-12">
                                        <label class="form-label small fw-bold text-dark mb-1">Procedimiento / Tratamiento en Consulta <span class="text-danger">*</span></label>
                                        <input type="text" class="form-control form-control-sm" name="procedimiento_descripcion" id="wiz_cons_proc" placeholder="Ej: Procedimiento invasivo menor / Sutura / Biopsia" required>
                                    </div>
                                    <div class="col-12 col-md-6">
                                        <label class="form-label small fw-bold text-dark mb-1">Objetivo</label>
                                        <input type="text" class="form-control form-control-sm" name="procedimiento_objetivo" id="wiz_cons_obj" placeholder="Ej: Restablecer función y aliviar dolor">
                                    </div>
                                    <div class="col-12 col-md-6">
                                        <label class="form-label small fw-bold text-dark mb-1">Beneficios Esperados</label>
                                        <input type="text" class="form-control form-control-sm" name="procedimiento_beneficios" id="wiz_cons_ben" placeholder="Ej: Curación y prevención de secuelas">
                                    </div>
                                    <div class="col-12 col-md-6">
                                        <label class="form-label small fw-bold text-dark mb-1">Riesgos y Complicaciones</label>
                                        <textarea class="form-control form-control-sm" name="procedimiento_riesgos" id="wiz_cons_ries" rows="2" placeholder="Ej: Inflamación local, molestia temporal"></textarea>
                                    </div>
                                    <div class="col-12 col-md-6">
                                        <label class="form-label small fw-bold text-dark mb-1">Alternativas</label>
                                        <textarea class="form-control form-control-sm" name="procedimiento_alternativas" id="wiz_cons_alt" rows="2" placeholder="Ej: Manejo farmacológico conservador"></textarea>
                                    </div>

                                    <!-- Pads de Firma Digital Compactos -->
                                    <div class="col-12 col-md-6 text-center mt-2">
                                        <label class="form-label small fw-bold text-dark d-block mb-1">Firma Digital del Paciente</label>
                                        <div class="border rounded-3 p-1.5 bg-white shadow-xs">
                                            <canvas id="canvas-wiz-paciente" width="260" height="85" style="border:1px dashed #94a3b8; background:#ffffff; cursor:crosshair; touch-action:none; border-radius: 6px;"></canvas>
                                            <div class="mt-1">
                                                <button type="button" class="btn btn-xs btn-outline-secondary rounded-pill px-2 py-0.5" style="font-size: 0.72rem;" onclick="limpiarCanvasWiz('paciente')">Limpiar Firma</button>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="col-12 col-md-6 text-center mt-2">
                                        <label class="form-label small fw-bold text-dark d-block mb-1">Firma Digital del Médico</label>
                                        <div class="border rounded-3 p-1.5 bg-white shadow-xs">
                                            <canvas id="canvas-wiz-medico" width="260" height="85" style="border:1px dashed #94a3b8; background:#ffffff; cursor:crosshair; touch-action:none; border-radius: 6px;"></canvas>
                                            <div class="mt-1">
                                                <button type="button" class="btn btn-xs btn-outline-secondary rounded-pill px-2 py-0.5" style="font-size: 0.72rem;" onclick="limpiarCanvasWiz('medico')">Limpiar Firma</button>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div class="d-flex justify-content-end gap-2 mt-3 pt-2.5 border-top">
                                    <button type="button" class="btn btn-sm btn-light rounded-pill px-3 fw-semibold border" data-bs-dismiss="modal">Cancelar</button>
                                    <button type="submit" class="btn btn-sm btn-primary rounded-pill px-4 fw-bold shadow-sm">
                                        <i class="bi bi-shield-check me-1"></i> Sellar y Vincular Documento
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    };

    my $js = <<'SCRIPT_JS';
    <script>
    (function() {
        let canvasWizPac, ctxWizPac, canvasWizMed, ctxWizMed;
        let isDrawingWizPac = false, isDrawingWizMed = false;

        function obtenerIdPacienteWizard() {
            const inp = document.querySelector('input[name="id_paciente"]');
            if (inp && inp.value) return inp.value;
            const panel = document.getElementById('step-panel-5');
            return panel ? (panel.getAttribute('data-id-paciente') || '') : '';
        }

        function sincronizarConsentimientoDesdeRegistro(checked) {
            const sec = document.getElementById('seccion-consentimiento-tabla');
            const aviso = document.getElementById('aviso-consentimiento-inhabilitado');
            const btnEmitir = document.getElementById('btn-emitir-cons-wizard');
            const reqInp = document.getElementById('check_requiere_consentimiento');

            if (reqInp) reqInp.value = checked ? '1' : '0';

            if (checked) {
                if (sec) sec.style.display = 'block';
                if (aviso) aviso.style.display = 'none';
                if (btnEmitir) btnEmitir.style.display = 'inline-flex';
                cargarConsentimientosWizard();
            } else {
                if (sec) sec.style.display = 'none';
                if (aviso) aviso.style.display = 'flex';
                if (btnEmitir) btnEmitir.style.display = 'none';
            }
        }

        function habilitarConsentimientoDesdePaso5() {
            const chkReg = document.getElementById('check_requiere_consentimiento_registro');
            if (chkReg) {
                chkReg.checked = true;
            }
            sincronizarConsentimientoDesdeRegistro(true);
        }

        async function cargarConsentimientosWizard() {
            const tbody = document.getElementById('tbodyConsentimientosWizard');
            if (!tbody) return;
            const pacId = obtenerIdPacienteWizard();
            if (!pacId) {
                tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-muted">ID de paciente no definido.</td></tr>';
                return;
            }

            try {
                const res = await fetch('../api/consentimientos_api.pl?accion=list&ambito=USO_CONSULTA&id_paciente=' + encodeURIComponent(pacId));
                const data = await res.json();

                if (!data.ok || !Array.isArray(data.consentimientos) || data.consentimientos.length === 0) {
                    tbody.innerHTML = '<tr>' +
                        '<td colspan="6" class="text-center py-4 text-muted">' +
                            '<i class="bi bi-file-earmark-check fs-2 text-muted opacity-40 d-block mb-1"></i>' +
                            '<span class="fw-bold d-block text-dark">Sin consentimientos de consulta registrados</span>' +
                            '<span class="small text-muted">El paciente no tiene documentos de ámbito consulta. Si amerita, emita uno nuevo con el botón superior.</span>' +
                        '</td>' +
                    '</tr>';
                    return;
                }

                const items = data.consentimientos;
                const vinInp = document.getElementById('id_consentimiento_vinculado');
                const vinId = vinInp ? vinInp.value : '';
                let rows = '';

                items.forEach(function(c) {
                    const esUtil = (c.utilizado == 1 || c.id_consulta || c.id_cirugia);
                    const semaforoHtml = esUtil 
                        ? '<span class="badge bg-success bg-opacity-15 text-success border border-success border-opacity-25 rounded-pill px-2.5 py-1 fw-bold"><i class="bi bi-check-circle-fill me-1 text-success"></i>Utilizado</span>'
                        : '<span class="badge bg-warning bg-opacity-15 text-warning-emphasis border border-warning border-opacity-25 rounded-pill px-2.5 py-1 fw-bold"><i class="bi bi-clock-history me-1 text-warning"></i>Disponible</span>';

                    const esVinculado = (vinId && vinId === c.id_consentimiento);
                    const rowClass = esVinculado ? 'table-primary border-primary' : '';
                    const procEscaped = (c.procedimiento || 'Procedimiento').replace(/'/g, "\\'");
                    const btnVincular = esVinculado 
                        ? '<span class="badge bg-primary text-white rounded-pill px-3 py-1.5 fw-bold"><i class="bi bi-check-lg me-1"></i>Vinculado</span>'
                        : '<button type="button" class="btn btn-xs btn-outline-primary rounded-pill px-2.5 py-1 fw-bold" onclick="window.vincularConsentimiento(\'' + c.id_consentimiento + '\', \'' + procEscaped + '\')"><i class="bi bi-link-45deg me-1"></i>Vincular a Consulta</button>';

                    rows += '<tr class="' + rowClass + '">' +
                        '<td class="font-monospace fw-bold text-dark">' + c.id_consentimiento + '</td>' +
                        '<td><div class="fw-semibold text-dark">' + (c.fecha || '--') + '</div><div class="text-muted fs-8">' + (c.hora || '') + '</div></td>' +
                        '<td><div class="fw-bold text-dark">' + (c.procedimiento || 'Procedimiento') + '</div><div class="text-muted fs-8 text-truncate" style="max-width: 220px;">' + (c.objetivo || '') + '</div></td>' +
                        '<td class="text-muted small">' + (c.nombre_medico || 'Médico Asignado') + '</td>' +
                        '<td>' + semaforoHtml + '</td>' +
                        '<td class="text-end">' +
                            '<div class="d-inline-flex gap-1.5 align-items-center">' +
                                '<a href="../api/imprimir_consentimiento_api.pl?id_consentimiento=' + encodeURIComponent(c.id_consentimiento) + '&id_paciente=' + encodeURIComponent(pacId) + '" target="_blank" class="btn btn-xs btn-light border rounded-pill px-2 py-1" title="Ver / Imprimir"><i class="bi bi-file-pdf"></i></a>' +
                                btnVincular +
                            '</div>' +
                        '</td>' +
                    '</tr>';
                });

                tbody.innerHTML = rows;

            } catch(e) {
                console.error("Error cargando consentimientos wizard", e);
                tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-danger">Falla al conectar con el repositorio.</td></tr>';
            }
        }

        function vincularConsentimiento(id_c, proc) {
            const inp = document.getElementById('id_consentimiento_vinculado');
            if (inp) inp.value = id_c;
            const aviso = document.getElementById('aviso-consentimiento-seleccionado');
            const txt = document.getElementById('txt-consentimiento-vinculado');
            if (aviso && txt) {
                txt.innerText = 'Documento [' + id_c + '] vinculado a esta consulta (' + proc + ')';
                aviso.classList.remove('d-none');
                aviso.classList.add('d-flex');
            }
            cargarConsentimientosWizard();
            if (window.Swal) {
                Swal.fire({
                    toast: true,
                    position: 'top-end',
                    icon: 'success',
                    title: 'Consentimiento Vinculado',
                    text: 'Folio: ' + id_c,
                    showConfirmButton: false,
                    timer: 2000
                });
            }
        }

        function desvincularConsentimiento() {
            const inp = document.getElementById('id_consentimiento_vinculado');
            if (inp) inp.value = '';
            const aviso = document.getElementById('aviso-consentimiento-seleccionado');
            if (aviso) {
                aviso.classList.add('d-none');
                aviso.classList.remove('d-flex');
            }
            cargarConsentimientosWizard();
        }

        function abrirModalNuevoConsentimientoWizard() {
            const pacId = obtenerIdPacienteWizard();
            const pacInp = document.getElementById('wiz_cons_id_paciente');
            if (pacInp) pacInp.value = pacId;

            const f = document.getElementById('formNuevoConsentimientoWizard');
            if (f) f.reset();
            limpiarCanvasWiz('paciente');
            limpiarCanvasWiz('medico');

            const modalEl = document.getElementById('modalNuevoConsentimientoWizard');
            const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
            modal.show();

            setTimeout(initCanvasWizFirmas, 250);
        }

        function initCanvasWizFirmas() {
            canvasWizPac = document.getElementById('canvas-wiz-paciente');
            if (canvasWizPac) {
                ctxWizPac = canvasWizPac.getContext('2d');
                bindCanvasWizEvents(canvasWizPac, ctxWizPac, 'paciente');
            }
            canvasWizMed = document.getElementById('canvas-wiz-medico');
            if (canvasWizMed) {
                ctxWizMed = canvasWizMed.getContext('2d');
                bindCanvasWizEvents(canvasWizMed, ctxWizMed, 'medico');
            }
        }

        function bindCanvasWizEvents(canvas, ctx, tipo) {
            ctx.lineWidth = 2;
            ctx.strokeStyle = '#0A2A66';
            ctx.lineCap = 'round';

            const getPos = function(e) {
                const rect = canvas.getBoundingClientRect();
                const clientX = e.touches ? e.touches[0].clientX : e.clientX;
                const clientY = e.touches ? e.touches[0].clientY : e.clientY;
                return { x: clientX - rect.left, y: clientY - rect.top };
            };

            const start = function(e) {
                e.preventDefault();
                const pos = getPos(e);
                ctx.beginPath();
                ctx.moveTo(pos.x, pos.y);
                if (tipo === 'paciente') isDrawingWizPac = true; else isDrawingWizMed = true;
            };

            const move = function(e) {
                const drawing = (tipo === 'paciente') ? isDrawingWizPac : isDrawingWizMed;
                if (!drawing) return;
                e.preventDefault();
                const pos = getPos(e);
                ctx.lineTo(pos.x, pos.y);
                ctx.stroke();
            };

            const stop = function() {
                if (tipo === 'paciente') {
                    isDrawingWizPac = false;
                    const hiddenPac = document.getElementById('wiz_firma_paciente');
                    if (hiddenPac) hiddenPac.value = canvas.toDataURL();
                } else {
                    isDrawingWizMed = false;
                    const hiddenMed = document.getElementById('wiz_firma_medico');
                    if (hiddenMed) hiddenMed.value = canvas.toDataURL();
                }
            };

            canvas.onmousedown = start; canvas.onmousemove = move; window.onmouseup = stop;
            canvas.ontouchstart = start; canvas.ontouchmove = move; window.ontouchend = stop;
        }

        function limpiarCanvasWiz(tipo) {
            if (tipo === 'paciente' && canvasWizPac) {
                ctxWizPac.clearRect(0, 0, canvasWizPac.width, canvasWizPac.height);
                const hiddenPac = document.getElementById('wiz_firma_paciente');
                if (hiddenPac) hiddenPac.value = '';
            } else if (tipo === 'medico' && canvasWizMed) {
                ctxWizMed.clearRect(0, 0, canvasWizMed.width, canvasWizMed.height);
                const hiddenMed = document.getElementById('wiz_firma_medico');
                if (hiddenMed) hiddenMed.value = '';
            }
        }

        async function guardarNuevoConsentimientoWizard(e) {
            e.preventDefault();
            const form = document.getElementById('formNuevoConsentimientoWizard');
            const formData = new FormData(form);
            formData.append('accion', 'save');
            const searchParams = new URLSearchParams(formData);

            if (window.Swal) {
                Swal.fire({
                    title: 'Sellando Consentimiento',
                    text: 'Registrando firmas y archivando en expediente...',
                    allowOutsideClick: false,
                    didOpen: function() { Swal.showLoading(); }
                });
            }

            try {
                const res = await fetch('../api/consentimientos_api.pl', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: searchParams
                });
                const data = await res.json();

                if (data.ok) {
                    const modalEl = document.getElementById('modalNuevoConsentimientoWizard');
                    const modal = bootstrap.Modal.getInstance(modalEl);
                    if (modal) modal.hide();

                    const procNombre = (data.consentimiento && data.consentimiento.procedimiento) ? data.consentimiento.procedimiento : 'Procedimiento';
                    vincularConsentimiento(data.id_consentimiento, procNombre);

                    if (window.Swal) {
                        Swal.fire({
                            icon: 'success',
                            title: '¡Consentimiento Emitido!',
                            text: 'Documento sellado y vinculado automáticamente a esta consulta.',
                            timer: 2200,
                            showConfirmButton: false
                        });
                    }
                } else {
                    if (window.Swal) Swal.fire('Error', data.error || 'No se pudo guardar', 'warning');
                    else alert(data.error || 'Error al guardar');
                }
            } catch(err) {
                console.error(err);
                if (window.Swal) Swal.fire('Error', 'Falla de red al conectar con el servidor', 'error');
            }
        }

        // Exponer globalmente para bindings HTML (onclick, onchange)
        window.sincronizarConsentimientoDesdeRegistro = sincronizarConsentimientoDesdeRegistro;
        window.habilitarConsentimientoDesdePaso5 = habilitarConsentimientoDesdePaso5;
        window.abrirModalNuevoConsentimientoWizard = abrirModalNuevoConsentimientoWizard;
        window.vincularConsentimiento = vincularConsentimiento;
        window.desvincularConsentimiento = desvincularConsentimiento;
        window.limpiarCanvasWiz = limpiarCanvasWiz;
        window.guardarNuevoConsentimientoWizard = guardarNuevoConsentimientoWizard;
        window.cargarConsentimientosWizard = cargarConsentimientosWizard;

        document.addEventListener('DOMContentLoaded', function() {
            const chkReg = document.getElementById('check_requiere_consentimiento_registro');
            const checked = chkReg ? chkReg.checked : true;
            sincronizarConsentimientoDesdeRegistro(checked);
        });
    })();
    </script>
SCRIPT_JS

    return $html . $js;
}
1;
