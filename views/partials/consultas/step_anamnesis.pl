sub render_step_anamnesis {
    return qq{
        <div class="wizard-panel" id="step-panel-1">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-clock-history me-2" style="color: var(--md-teal-clinical);"></i>Anamnesis y Antecedentes
            </h3>
            
            <div class="row g-4">
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 10px;">Padecimiento Actual</h5>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Inicio de S&iacute;ntomas</label>
                    <input type="date" name="inicio_sintomas" class="wizard-input">
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Intensidad (1-10)</label>
                    <input type="number" name="intensidad" class="wizard-input" min="1" max="10">
                </div>
                <div class="col-12">
                    <label class="wizard-label">Evoluci&oacute;n y S&iacute;ntomas <span class="req-star">*</span></label>
                    <textarea name="evolucion" class="wizard-input" rows="4" placeholder="Describa c&oacute;mo ha evolucionado el cuadro cl&iacute;nico..." required></textarea>
                </div>
                
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 20px;">Antecedentes Personales</h5>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Patol&oacute;gicos</label>
                    <textarea name="antecedentes_patologicos" class="wizard-input" rows="2" placeholder="Ej. Hipertensi&oacute;n, Diabetes..."></textarea>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Alergias</label>
                    <textarea name="alergias" class="wizard-input" rows="2" placeholder="Medicamentos, alimentos..."></textarea>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Exploraci&oacute;n <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
    };
}
1;
