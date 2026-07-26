sub render_step_exploracion {
    my ($paciente) = @_;
    my $id_espe = $paciente->{id_espe_medico} // '0';
    my $espe_nombre = $paciente->{espe_nombre_medico} // 'Medicina General';
    my $is_odontologia = ($id_espe eq '100' || $espe_nombre =~ /Odontolog/i) ? 1 : 0;

    my $subformulario_html = '';

    if ($is_odontologia) {
        $subformulario_html = <<HTML;
                <!-- Odontograma Interactivo (Se muestra si es Odontología) -->
                <div class="col-12" id="odontograma-section">
                    <div class="card-medentia-aura border-0 bg-white p-4 rounded shadow-sm">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h5 style="color: var(--md-teal-clinical); m-0"><i class="bi bi-tooth me-2"></i>Odontograma Interactivo</h5>
                            <span class="badge bg-primary">Modo Odontología</span>
                        </div>
                        
                        <!-- Toolbar -->
                        <div class="d-flex flex-column gap-3 mb-4" id="odontograma-toolbar">
                            <div class="odontograma-tools-grid">
                                <button type="button" class="btn btn-outline-danger btn-sm rounded-pill px-3 active-tool" data-tool="caries"><i class="bi bi-circle-fill me-1"></i>Caries</button>
                                <button type="button" class="btn btn-outline-primary btn-sm rounded-pill px-3" data-tool="corona"><i class="bi bi-square-fill me-1"></i>Corona</button>
                                <button type="button" class="btn btn-outline-dark btn-sm rounded-pill px-3" data-tool="extraccion"><i class="bi bi-x-lg me-1"></i>Extracci&oacute;n</button>
                                <button type="button" class="btn btn-outline-info btn-sm rounded-pill px-3" data-tool="implante"><i class="bi bi-vinyl-fill me-1"></i>Implante</button>
                                <button type="button" class="btn btn-outline-warning btn-sm rounded-pill px-3" data-tool="protesis"><i class="bi bi-diagram-2-fill me-1"></i>Pr&oacute;tesis</button>
                                <button type="button" class="btn btn-outline-success btn-sm rounded-pill px-3" data-tool="sano"><i class="bi bi-check-circle-fill me-1"></i>Sano</button>
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="button" class="btn btn-medentia btn-sm rounded-pill px-4" onclick="saveOdontogramaToServer()"><i class="bi bi-cloud-arrow-up-fill me-2"></i>Guardar Mapa Dental</button>
                            </div>
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
HTML
    } else {
        $subformulario_html = <<HTML;
                <!-- Subformulario Dinámico para Especialidades No Odontológicas -->
                <div class="col-12" id="especialidad-subformulario-container">
                    <div class="card-medentia-aura border-0 bg-white p-4 rounded-4 shadow-sm">
                        <div class="d-flex align-items-center mb-3">
                            <i class="bi bi-diagram-3-fill me-2 text-primary fs-5"></i>
                            <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">Módulo de Exploración Dirigida ($espe_nombre)</h5>
                            <span class="badge bg-info text-white ms-auto">Especialidad: $espe_nombre</span>
                        </div>
                        <div class="alert alert-primary bg-primary bg-opacity-10 border-primary border-opacity-25 rounded-4 p-4 text-center my-2">
                            <i class="bi bi-tools display-5 d-block mb-3 text-primary"></i>
                            <h4 class="fw-bold text-primary mb-2">(Aquí van los subformularios según la especialidad)</h4>
                            <p class="text-muted mb-0 small">Subformulario modular y extensible dinámico configurado para <strong>$espe_nombre</strong>.</p>
                        </div>
                    </div>
                </div>
HTML
    }

    return qq{
        <div class="wizard-panel" id="step-panel-2">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-activity me-2" style="color: var(--md-teal-clinical);"></i>Exploraci&oacute;n F&iacute;sica (Objetivo - O)
            </h3>
            
            <div class="row g-4">
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 10px;">Signos Vitales B&aacute;sicos</h5>
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">T.A. (mmHg)</label>
                    <input type="text" name="ta" class="wizard-input" placeholder="120/80">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">F.C. (lpm)</label>
                    <input type="number" name="fc" class="wizard-input" placeholder="70">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">F.R. (rpm)</label>
                    <input type="number" name="fr" class="wizard-input" placeholder="16">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">Temp (&deg;C)</label>
                    <input type="number" name="temp" class="wizard-input" step="0.1" placeholder="36.5">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">Peso (kg)</label>
                    <input type="number" name="peso" id="ef_peso" class="wizard-input" step="0.1">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">Talla (cm)</label>
                    <input type="number" name="talla" id="ef_talla" class="wizard-input" step="1">
                </div>
                
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 20px;">Exploraci&oacute;n Dirigida por Especialidad</h5>
                </div>
                
                $subformulario_html

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
