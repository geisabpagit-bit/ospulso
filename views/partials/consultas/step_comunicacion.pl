use strict;
use warnings;
use utf8;

sub render_step_comunicacion {
    return qq{
        <div class="wizard-panel" id="step-panel-5">
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
                    <label class="wizard-label">Observaciones Adicionales de la Interacci&oacute;n</label>
                    <textarea name="com_observaciones" class="wizard-input" rows="3" placeholder="Comentarios sobre la recepci&oacute;n de las noticias por parte del paciente o familiares..."></textarea>
                </div>

                <!-- Módulo de Consentimiento Informado Oficial NOM-004-SSA3 -->
                <div class="col-12 mt-4">
                    <div class="card-medentia-aura border-0 bg-white p-4 rounded-4 shadow-sm">
                        <div class="d-flex align-items-center justify-content-between mb-3">
                            <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">
                                <i class="bi bi-file-earmark-medical me-2 text-primary"></i>Consentimiento Informado Oficial
                            </h5>
                            <div class="form-check form-switch fs-5">
                                <input class="form-check-input" type="checkbox" role="switch" id="check_requiere_consentimiento" name="requiere_consentimiento" value="1" onchange="toggleSeccionConsentimiento(this.checked)">
                                <label class="form-check-label fs-6 fw-bold text-muted" for="check_requiere_consentimiento">¿Requiere Consentimiento Informado?</label>
                            </div>
                        </div>

                        <div id="seccion-consentimiento-informado" style="display: none;">
                            <input type="hidden" name="consentimiento_json" id="consentimiento_json_input" value="{}">
                            <input type="hidden" name="firma_paciente_data" id="firma_paciente_data">
                            <input type="hidden" name="firma_medico_data" id="firma_medico_data">

                            <div class="row g-3">
                                <div class="col-md-12">
                                    <label class="wizard-label">Descripción del Procedimiento / Tratamiento <span class="req-star">*</span></label>
                                    <input type="text" name="procedimiento_descripcion" id="proc_desc" class="wizard-input" placeholder="Ej: Procedimiento invasivo / Abordaje quirúrgico / Tratamiento farmacológico especializado">
                                </div>
                                <div class="col-md-6">
                                    <label class="wizard-label">Objetivo del Procedimiento</label>
                                    <input type="text" name="procedimiento_objetivo" id="proc_obj" class="wizard-input" placeholder="Ej: Restablecer la función del tejido y eliminar dolor">
                                </div>
                                <div class="col-md-6">
                                    <label class="wizard-label">Beneficios Esperados</label>
                                    <input type="text" name="procedimiento_beneficios" id="proc_ben" class="wizard-input" placeholder="Ej: Recuperación de la salud y prevención de secuelas">
                                </div>
                                <div class="col-md-6">
                                    <label class="wizard-label">Riesgos y Complicaciones Posibles</label>
                                    <textarea name="procedimiento_riesgos" id="proc_ries" class="wizard-input" rows="2" placeholder="Ej: Inflamación local, sangrado leve, malestar temporal"></textarea>
                                </div>
                                <div class="col-md-6">
                                    <label class="wizard-label">Alternativas Disponibles</label>
                                    <textarea name="procedimiento_alternativas" id="proc_alt" class="wizard-input" rows="2" placeholder="Ej: Tratamiento conservador alternativo"></textarea>
                                </div>

                                <div class="col-12 mt-3">
                                    <div class="alert alert-warning bg-warning bg-opacity-10 border-warning border-opacity-25 rounded-3 p-3 small">
                                        <i class="bi bi-shield-check text-warning fs-5 me-2"></i>
                                        <strong>Derechos del Paciente:</strong> El paciente manifiesta haber sido informado de forma comprensible y conserva el <strong>derecho de revocación</strong> en cualquier momento.
                                    </div>
                                </div>

                                <!-- Pad de Firma Digital Canvas -->
                                <div class="col-md-6 text-center">
                                    <label class="wizard-label mb-2 d-block">Firma Digital del Paciente</label>
                                    <div class="border rounded-3 p-2 bg-light shadow-sm">
                                        <canvas id="canvas-firma-paciente" width="280" height="120" style="border:1px dashed #cbd5e1; background:#ffffff; cursor:crosshair; touch-action:none;"></canvas>
                                        <div class="mt-2">
                                            <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill px-3" onclick="limpiarCanvasFirma('paciente')">Limpiar Firma</button>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-md-6 text-center">
                                    <label class="wizard-label mb-2 d-block">Firma Digital del Médico</label>
                                    <div class="border rounded-3 p-2 bg-light shadow-sm">
                                        <canvas id="canvas-firma-medico" width="280" height="120" style="border:1px dashed #cbd5e1; background:#ffffff; cursor:crosshair; touch-action:none;"></canvas>
                                        <div class="mt-2">
                                            <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill px-3" onclick="limpiarCanvasFirma('medico')">Limpiar Firma</button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Caja <i class="bi bi-arrow-right ms-2"></i></button>
            </div>

            <script>
            let canvasPac, ctxPac, canvasMed, ctxMed;
            let isDrawingPac = false, isDrawingMed = false;

            function toggleSeccionConsentimiento(checked) {
                const sec = document.getElementById('seccion-consentimiento-informado');
                if (sec) {
                    sec.style.display = checked ? 'block' : 'none';
                    if (checked) {
                        setTimeout(initCanvasFirmas, 200);
                    }
                }
            }

            function initCanvasFirmas() {
                canvasPac = document.getElementById('canvas-firma-paciente');
                if (canvasPac) {
                    ctxPac = canvasPac.getContext('2d');
                    bindCanvasEvents(canvasPac, ctxPac, 'paciente');
                }
                canvasMed = document.getElementById('canvas-firma-medico');
                if (canvasMed) {
                    ctxMed = canvasMed.getContext('2d');
                    bindCanvasEvents(canvasMed, ctxMed, 'medico');
                }
            }

            function bindCanvasEvents(canvas, ctx, tipo) {
                ctx.lineWidth = 2;
                ctx.strokeStyle = '#0A2A66';
                ctx.lineCap = 'round';

                const getPos = (e) => {
                    const rect = canvas.getBoundingClientRect();
                    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
                    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
                    return { x: clientX - rect.left, y: clientY - rect.top };
                };

                const start = (e) => {
                    e.preventDefault();
                    const pos = getPos(e);
                    ctx.beginPath();
                    ctx.moveTo(pos.x, pos.y);
                    if (tipo === 'paciente') isDrawingPac = true; else isDrawingMed = true;
                };

                const move = (e) => {
                    const drawing = (tipo === 'paciente') ? isDrawingPac : isDrawingMed;
                    if (!drawing) return;
                    e.preventDefault();
                    const pos = getPos(e);
                    ctx.lineTo(pos.x, pos.y);
                    ctx.stroke();
                };

                const stop = () => {
                    if (tipo === 'paciente') {
                        isDrawingPac = false;
                        document.getElementById('firma_paciente_data').value = canvas.toDataURL();
                    } else {
                        isDrawingMed = false;
                        document.getElementById('firma_medico_data').value = canvas.toDataURL();
                    }
                };

                canvas.onmousedown = start; canvas.onmousemove = move; window.onmouseup = stop;
                canvas.ontouchstart = start; canvas.ontouchmove = move; window.ontouchend = stop;
            }

            function limpiarCanvasFirma(tipo) {
                if (tipo === 'paciente' && canvasPac) {
                    ctxPac.clearRect(0, 0, canvasPac.width, canvasPac.height);
                    document.getElementById('firma_paciente_data').value = '';
                } else if (tipo === 'medico' && canvasMed) {
                    ctxMed.clearRect(0, 0, canvasMed.width, canvasMed.height);
                    document.getElementById('firma_medico_data').value = '';
                }
            }
            </script>
        </div>
    };
}
1;
