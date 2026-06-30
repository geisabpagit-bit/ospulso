sub render_step_registro {
    my ($paciente) = @_;
    my $motivo_precargado = $paciente->{motivo_precargado} || '';
    
    return qq{
        <div class="wizard-panel active" id="step-panel-0">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-person-badge me-2" style="color: var(--md-teal-clinical);"></i>Recepci&oacute;n y Registro
            </h3>
            
            <div class="row g-4">
                <!-- Info Paciente Readonly -->
                <div class="col-md-6">
                    <label class="wizard-label">Paciente</label>
                    <input type="text" class="wizard-input bg-light" value="$paciente->{nombre}" readonly>
                </div>
                <div class="col-md-3">
                    <label class="wizard-label">CURP</label>
                    <input type="text" class="wizard-input bg-light" value="$paciente->{curp}" readonly>
                </div>
                <div class="col-md-3">
                    <label class="wizard-label">Sexo</label>
                    <input type="text" class="wizard-input bg-light" value="$paciente->{sexo}" readonly>
                </div>
                
                <!-- Inputs Requeridos -->
                <div class="col-md-6">
                    <label class="wizard-label">Tipo de Consulta <span class="req-star">*</span></label>
                    <select name="tipo_consulta" class="wizard-input" required>
                        <option value="">Seleccione...</option>
                        <option value="Primera Vez">Primera Vez</option>
                        <option value="Seguimiento">Seguimiento</option>
                        <option value="Urgencia">Urgencia</option>
                    </select>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Especialidad <span class="req-star">*</span></label>
                    <select name="especialidad" class="wizard-input" required>
                        <option value="">Seleccione...</option>
                        <option value="Medicina General">Medicina General</option>
                        <option value="Odontologia">Odontolog&iacute;a</option>
                        <option value="Pediatria">Pediatr&iacute;a</option>
                    </select>
                </div>
                
                <div class="col-12">
                    <label class="wizard-label">Motivo Principal de Consulta <span class="req-star">*</span></label>
                    <textarea name="motivo" class="wizard-input" rows="4" placeholder="Describa el motivo por el cual asiste el paciente..." required>$motivo_precargado</textarea>
                </div>
            </div>
            
            <div class="d-flex justify-content-end mt-5">
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Anamnesis <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
    };
}
1;
