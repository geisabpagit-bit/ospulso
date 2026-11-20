use strict;
use warnings;
use utf8;

sub render_step_cierre_privado {
    my ($paciente) = @_;
    $paciente ||= {};

    return qq{
        <div class="wizard-panel" id="step-panel-4" data-step-index="4">
            <input type="hidden" name="estatus_clinico" id="f_estatus_clinico" value="BORRADOR">
            <input type="hidden" name="hash_nom151" id="f_hash_nom151" value="">
            <input type="hidden" name="efirma_certificado_sat" id="f_efirma_certificado_sat" value="">
            <input type="hidden" name="fecha_sellado" id="f_fecha_sellado" value="">
            <input type="hidden" name="duracion_segundos" id="f_duracion_segundos" value="0">

            <!-- Encabezado Paso 5 -->
            <div class="d-flex justify-content-between align-items-center border-bottom pb-2.5 mb-3 flex-wrap gap-2">
                <div>
                    <h5 class="fw-bold text-navy mb-0">
                        <i class="bi bi-shield-lock-fill me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>Paso 5: Firma Clínica e.firma / NOM-151 y Desacoplamiento de Caja
                    </h5>
                    <p class="text-muted small mb-0">Sellado criptográfico de inmutabilidad NOM-004/NOM-151, vista PDF con QR NOM-024 y bifurcación operativa de cobro.</p>
                </div>
                <span class="badge bg-primary-subtle text-primary fw-bold">Paso 5 de 6</span>
            </div>

            <!-- Subcard 1: Checklist Normativo Pre-Firma -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center">
                    <span><i class="bi bi-clipboard2-check-fill text-teal me-1.5"></i>1. Auditoría Pre-Sellado (NOM-004-SSA3-2012 &amp; COFEPRIS)</span>
                    <span id="badge-auditoria-nom004" class="badge bg-warning text-dark">Verificando requisitos...</span>
                </div>
                <div class="row g-2 small" id="checklist-auditoria-firma">
                    <div class="col-12 col-md-3">
                        <div class="p-2 rounded border bg-light d-flex align-items-center gap-2" id="audit-item-motivo">
                            <i class="bi bi-circle text-muted"></i>
                            <span><strong>Subjetivo:</strong> Motivo y Evolución</span>
                        </div>
                    </div>
                    <div class="col-12 col-md-3">
                        <div class="p-2 rounded border bg-light d-flex align-items-center gap-2" id="audit-item-objetivo">
                            <i class="bi bi-circle text-muted"></i>
                            <span><strong>Objetivo:</strong> Triage y Hallazgos</span>
                        </div>
                    </div>
                    <div class="col-12 col-md-3">
                        <div class="p-2 rounded border bg-light d-flex align-items-center gap-2" id="audit-item-analisis">
                            <i class="bi bi-circle text-muted"></i>
                            <span><strong>Análisis/Plan:</strong> Impresión y Pronóstico Dual</span>
                        </div>
                    </div>
                    <div class="col-12 col-md-3">
                        <div class="p-2 rounded border bg-light d-flex align-items-center gap-2" id="audit-item-legal">
                            <i class="bi bi-circle text-muted"></i>
                            <span><strong>Legal/COFEPRIS:</strong> Acuerdos y Cédula</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Subcard 2: Sello Digital e.firma / NOM-151 -->
            <div class="qx-subcard mb-3" id="card-sello-criptografico">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center">
                    <span><i class="bi bi-key-fill text-primary me-1.5"></i>2. Firma Electrónica Avanzada (e.firma SAT / Sellado de Tiempo NOM-151)</span>
                    <span id="lbl-estado-sello-nom151" class="badge bg-secondary rounded-pill">BORRADOR EN EDICIÓN</span>
                </div>

                <div id="panel-pre-firma-nom151" class="text-center py-3">
                    <p class="small text-muted mb-2.5">
                        Al aplicar la firma clínica, se genera la estampilla de tiempo <strong>SHA-256 NOM-151-SCFI-2016</strong>, se detiene el cronómetro de consulta y los <strong>Pasos 1 al 4 quedan bloqueados contra modificación</strong> conforme a la NOM-004.
                    </p>
                    <button type="button" class="btn btn-navy rounded-pill px-4 py-2 fw-semibold shadow-sm" style="background: linear-gradient(135deg, #0A2A66 0%, #19B7A5 100%); border:none;" onclick="SOAPReactiveEngine.sellarNotaClinicaNOM151()">
                        <i class="bi bi-fingerprint me-1.5 fs-5 align-middle"></i>Sellar Nota Clínica (e.firma / NOM-151) y Congelar Pasos 1–4
                    </button>
                </div>

                <div id="panel-post-firma-nom151" class="d-none p-3 rounded-3 border border-success bg-success-subtle">
                    <div class="d-flex justify-content-between align-items-start flex-wrap gap-2">
                        <div>
                            <h6 class="fw-semibold text-success mb-1">
                                <i class="bi bi-patch-check-fill me-1.5"></i>Nota Clínica Sellada bajo NOM-151-SCFI-2016 (Pasos 1–4 Inmutables)
                            </h6>
                            <div class="small text-dark font-monospace">
                                <div><strong>Certificado SAT:</strong> <span id="lbl-cert-sat">--</span> &bull; <strong>Estampilla:</strong> <span id="lbl-fecha-sello">--</span></div>
                                <div class="text-truncate" style="max-width: 560px;"><strong>Hash SHA-256:</strong> <span id="lbl-hash-nom151">--</span></div>
                            </div>
                        </div>
                        <div class="d-flex gap-1.5 flex-wrap">
                            <button type="button" class="btn btn-sm btn-dark rounded-pill px-3 fw-semibold" onclick="SOAPReactiveEngine.abrirModalPDFNotaQR()">
                                <i class="bi bi-qr-code-scan me-1"></i>Vista Imprimible PDF + QR NOM-024
                            </button>
                            <button type="button" class="btn btn-sm btn-outline-success rounded-pill px-3 fw-semibold" onclick="SOAPReactiveEngine.enviarNotaCifradaTLS()">
                                <i class="bi bi-shield-lock me-1"></i>Enviar por Canal TLS 1.3
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Subcard 3: Bifurcación Operativa — Desacoplamiento Clínico vs. Caja -->
            <div class="qx-subcard mb-3">
                <div class="qx-subcard-title d-flex justify-content-between align-items-center">
                    <span><i class="bi bi-signpost-split-fill text-teal me-1.5"></i>3. Decisión Operativa de Cierre: ¿Quién Realiza el Cobro?</span>
                    <span class="small text-muted">Desacoplamiento Clínico-Financiero</span>
                </div>

                <div class="qx-type-selector">
                    <!-- Opción A: Enviar a Recepción / Caja (Clínica / Municipio) -->
                    <div class="qx-type-card selected-programada" id="card-cierre-recepcion">
                        <div class="d-flex justify-content-between align-items-center mb-1.5">
                            <span class="fw-semibold text-navy"><i class="bi bi-building-check text-primary me-1.5"></i>A. Clínica con Recepción / Caja Desacoplada</span>
                            <span class="badge bg-primary">Fin Acto Médico</span>
                        </div>
                        <p class="text-muted small mb-2.5" style="font-size:0.74rem;">
                            El médico concluye su atención aquí. La nota SOAP, receta y consentimientos se archivan en el expediente, y la orden de cobro se envía con estatus <code>Cobro por recepción</code> a la ventanilla de Caja.
                        </p>
                        <button type="button" class="btn btn-sm btn-navy w-100 rounded-pill fw-semibold py-1.5" onclick="SOAPReactiveEngine.finalizarYEnviarACajaRecepcion()">
                            <i class="bi bi-send-check-fill me-1.5"></i>Sellar y Enviar Orden a Caja Recepción (Cerrar Consulta)
                        </button>
                    </div>

                    <!-- Opción B: Médico Independiente / Consultorio (Ir al Paso 6) -->
                    <div class="qx-type-card" id="card-cierre-independiente" style="border-color: #19B7A5; background: #f0fdfa;">
                        <div class="d-flex justify-content-between align-items-center mb-1.5">
                            <span class="fw-bold text-navy"><i class="bi bi-wallet2 text-teal me-1.5"></i>B. MÉDICO INDEPENDIENTE / COBRO EN CONSULTORIO</span>
                            <span class="badge bg-success">Ir al Paso 6</span>
                        </div>
                        <p class="text-muted small mb-2.5" style="font-size:0.74rem;">
                            Continúe al <strong>Paso 6 (Caja y Seguimiento)</strong> para agregar conceptos del catálogo 3NF, cobrar directamente (Efectivo/Tarjeta/Transferencia), emitir recibo oficial y agendar la próxima cita.
                        </p>
                        <button type="button" class="btn btn-sm btn-success w-100 rounded-pill fw-bold py-1.5" style="background:#19B7A5;border-color:#19B7A5;" onclick="WizardController.jumpToStep(5)">
                            <i class="bi bi-arrow-right-circle-fill me-1.5"></i>Ir al Paso 6: Cobrar en Consultorio y Agendar Cita
                        </button>
                    </div>
                </div>
            </div>

            <div class="d-flex justify-content-between align-items-center mt-3 pt-2 border-top">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()">
                    <i class="bi bi-arrow-left me-1"></i> Paso 4: Acuerdos y Legal
                </button>
                <div class="d-flex gap-2">
                    <button type="button" class="btn btn-sm btn-outline-dark rounded-pill px-3 fw-bold" onclick="SOAPReactiveEngine.abrirModalPDFNotaQR()">
                        <i class="bi bi-printer me-1"></i>Vista Imprimible PDF + QR
                    </button>
                    <button type="button" class="wizard-btn-next" onclick="WizardController.jumpToStep(5)">
                        Continuar a Paso 6: Caja y Seguimiento <i class="bi bi-arrow-right ms-1"></i>
                    </button>
                </div>
            </div>
        </div>
    };
}
1;
