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
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar al Cierre <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
    };
}
1;
