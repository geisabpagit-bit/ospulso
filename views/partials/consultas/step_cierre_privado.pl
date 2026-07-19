use strict;
use warnings;
use utf8;

sub render_step_cierre_privado {
    return qq{
        <div class="wizard-panel" id="step-panel-7">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-check-circle-fill me-2" style="color: var(--md-teal-clinical);"></i>Cierre de Consulta
            </h3>
            
            <div class="row g-4">
                <div class="col-12 text-center py-4">
                    <i class="bi bi-shield-check" style="font-size: 4rem; color: var(--md-teal-clinical);"></i>
                    <h4 class="mt-3 fw-bold text-dark">Todo listo para finalizar</h4>
                    <p class="text-muted">El expediente clínico y los movimientos financieros han sido validados. Al finalizar se generar&aacute;n los siguientes registros:</p>
                </div>
                
                <div class="col-md-8 mx-auto">
                    <ul class="list-group list-group-flush border rounded">
                        <li class="list-group-item bg-light text-muted fw-bold"><i class="bi bi-check2 text-success me-2"></i> Receta M&eacute;dica Digital (si hay prescripciones)</li>
                        <li class="list-group-item bg-light text-muted fw-bold"><i class="bi bi-check2 text-success me-2"></i> Nota M&eacute;dica de Evoluci&oacute;n (SOAP)</li>
                        <li class="list-group-item bg-light text-muted fw-bold"><i class="bi bi-check2 text-success me-2"></i> Conversi&oacute;n de Cotizaci&oacute;n a Tratamiento (si se seleccion&oacute;)</li>
                        <li class="list-group-item bg-light text-muted fw-bold"><i class="bi bi-check2 text-success me-2"></i> Registro del abono/liquidaci&oacute;n en Caja y Finanzas</li>
                        <li class="list-group-item bg-light text-muted fw-bold"><i class="bi bi-check2 text-success me-2"></i> Actualizaci&oacute;n de Agenda (Estado: Atendido / Programada)</li>
                    </ul>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5 pt-4 border-top">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Volver a Revisar</button>
                <button type="button" class="wizard-btn-next wizard-btn-finish" onclick="finalizarConsulta()">Firmar y Finalizar Consulta <i class="bi bi-lock ms-2"></i></button>
            </div>
        </div>
    };
}
1;
