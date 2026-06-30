sub render_step_estudios {
    return qq{
        <div class="wizard-panel" id="step-panel-3">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-file-medical me-2" style="color: var(--md-teal-clinical);"></i>Estudios Complementarios
            </h3>
            
            <div class="row g-4">
                <div class="col-12">
                    <p class="text-muted mb-4">Gestione los estudios de laboratorio o imagenolog&iacute;a solicitados o tra&iacute;dos por el paciente.</p>
                </div>
                
                <div class="col-md-6">
                    <label class="wizard-label">Estudios de Laboratorio Solicitados</label>
                    <textarea name="laboratorios_solicitados" class="wizard-input" rows="3" placeholder="Biometr&iacute;a hem&aacute;tica, Qu&iacute;mica sangu&iacute;nea..."></textarea>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Estudios de Gabinete / Imagenolog&iacute;a</label>
                    <textarea name="gabinete_solicitados" class="wizard-input" rows="3" placeholder="Radiograf&iacute;a panor&aacute;mica, TAC..."></textarea>
                </div>
                
                <div class="col-12 mt-4">
                    <label class="wizard-label">Resultados Previos / Observaciones</label>
                    <textarea name="resultados_estudios" class="wizard-input" rows="4" placeholder="Interprete aqu&iacute; los resultados presentados por el paciente..."></textarea>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a SOAP <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
    };
}
1;
