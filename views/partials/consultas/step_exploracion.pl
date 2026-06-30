sub render_step_exploracion {
    return qq{
        <div class="wizard-panel" id="step-panel-2">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-activity me-2" style="color: var(--md-teal-clinical);"></i>Exploraci&oacute;n F&iacute;sica
            </h3>
            
            <div class="row g-4">
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 10px;">Signos Vitales Básicos</h5>
                </div>
                <div class="col-md-3">
                    <label class="wizard-label">T.A. (mmHg)</label>
                    <input type="text" name="ta" class="wizard-input" placeholder="120/80">
                </div>
                <div class="col-md-3">
                    <label class="wizard-label">F.C. (lpm)</label>
                    <input type="number" name="fc" class="wizard-input" placeholder="70">
                </div>
                <div class="col-md-3">
                    <label class="wizard-label">F.R. (rpm)</label>
                    <input type="number" name="fr" class="wizard-input" placeholder="16">
                </div>
                <div class="col-md-3">
                    <label class="wizard-label">Temp (&deg;C)</label>
                    <input type="number" name="temp" class="wizard-input" step="0.1" placeholder="36.5">
                </div>
                
                <div class="col-md-6">
                    <label class="wizard-label">Peso (kg)</label>
                    <input type="number" name="peso" id="ef_peso" class="wizard-input" step="0.1">
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Talla (cm)</label>
                    <input type="number" name="talla" id="ef_talla" class="wizard-input" step="1">
                </div>
                
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 20px;">Exploraci&oacute;n Dirigida</h5>
                </div>
                
                <!-- Odontograma Interactivo (Se muestra dinámicamente si es Odontología) -->
                <div class="col-12" id="odontograma-section" style="display: none;">
                    <div class="card-medentia-aura border-0 bg-white p-4 rounded shadow-sm">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h5 style="color: var(--md-teal-clinical); m-0"><i class="bi bi-tooth me-2"></i>Odontograma Interactivo</h5>
                            <span class="badge bg-primary">Modo Odontología</span>
                        </div>
                        
                        <!-- Toolbar -->
                        <div class="d-flex flex-wrap gap-2 mb-4" id="odontograma-toolbar">
                            <button type="button" class="btn btn-outline-danger btn-sm rounded-pill px-3 active-tool" data-tool="caries"><i class="bi bi-circle-fill me-1"></i>Caries</button>
                            <button type="button" class="btn btn-outline-primary btn-sm rounded-pill px-3" data-tool="corona"><i class="bi bi-square-fill me-1"></i>Corona</button>
                            <button type="button" class="btn btn-outline-dark btn-sm rounded-pill px-3" data-tool="extraccion"><i class="bi bi-x-lg me-1"></i>Extracción</button>
                            <button type="button" class="btn btn-outline-info btn-sm rounded-pill px-3" data-tool="implante"><i class="bi bi-vinyl-fill me-1"></i>Implante</button>
                            <button type="button" class="btn btn-outline-warning btn-sm rounded-pill px-3" data-tool="protesis"><i class="bi bi-diagram-2-fill me-1"></i>Prótesis</button>
                            <button type="button" class="btn btn-outline-success btn-sm rounded-pill px-3" data-tool="sano"><i class="bi bi-check-circle-fill me-1"></i>Sano</button>
                            <div class="vr mx-2"></div>
                            <button type="button" class="btn btn-medentia btn-sm rounded-pill px-4" onclick="saveOdontogramaToServer()"><i class="bi bi-cloud-arrow-up-fill me-2"></i>Guardar Mapa Dental</button>
                        </div>
                        
                        <!-- Container SVG -->
                        <div class="odontograma-container card-medentia-aura p-3 mb-3 overflow-auto border-0 bg-light rounded text-center" style="min-height: 300px;">
                            <div id="odontograma-svg-container" class="text-center w-100">
                                <div class="py-5 text-muted opacity-50"><div class="spinner-border text-primary mb-3"></div><br>Iniciando Mapa Dental...</div>
                            </div>
                        </div>
                        
                        <div class="form-check mt-3">
                            <input class="form-check-input wizard-input-check" type="checkbox" name="odontograma_evaluado" value="1" id="od_eval">
                            <label class="form-check-label fw-bold" for="od_eval">Confirmo que he actualizado y guardado el odontograma en esta sesión.</label>
                        </div>
                    </div>
                </div>

                <div class="col-12">
                    <label class="wizard-label">Hallazgos Cl&iacute;nicos <span class="req-star">*</span></label>
                    <textarea name="exploracion_hallazgos" class="wizard-input" rows="5" placeholder="Describa los hallazgos de la exploraci&oacute;n f&iacute;sica..." required></textarea>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Estudios <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
    };
}
1;
