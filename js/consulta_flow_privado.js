/**
 * js/consulta_flow_privado.js
 * Motor de control para el Wizard Clínico SDM Diamond (Flujo Privado con Caja)
 */

const WizardController = {
    currentStep: 0,
    totalSteps: 7, // 0 to 7 (8 pasos)
    
    init: function(startIndex = 0) {
        this.currentStep = startIndex;
        this.renderStep();
        this.bindEvents();
        this.updateProgressBar();
    },
    
    bindEvents: function() {
        // Interceptar Enter en inputs (para no submitear el formulario principal)
        document.addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA') {
                e.preventDefault();
            }
        });
    },

    nextStep: function() {
        if (!this.validateCurrentStep()) return;
        
        if (this.currentStep < this.totalSteps) {
            this.currentStep++;
            this.renderStep();
            
            // Trigger autosave al avanzar de paso
            if (typeof AutosaveService !== 'undefined') {
                AutosaveService.triggerSave();
            }
            
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    },

    prevStep: function() {
        if (this.currentStep > 0) {
            this.currentStep--;
            this.renderStep();
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    },

    jumpToStep: function(stepIndex) {
        // Solo permitir saltar si los pasos anteriores son válidos
        if (stepIndex < this.currentStep) {
            this.currentStep = stepIndex;
            this.renderStep();
        } else {
            // Intenta avanzar verificando validaciones
            while(this.currentStep < stepIndex) {
                if (!this.validateCurrentStep()) return;
                this.currentStep++;
            }
            this.renderStep();
        }
    },

    renderStep: function() {
        // Ocultar todos los paneles
        document.querySelectorAll('.wizard-panel').forEach(panel => {
            panel.classList.remove('active');
        });
        
        // Mostrar panel actual
        const currentPanel = document.getElementById('step-panel-' + this.currentStep);
        if (currentPanel) currentPanel.classList.add('active');
        
        // Actualizar Stepper UI
        document.querySelectorAll('.wizard-step').forEach((step, index) => {
            step.classList.remove('active', 'completed');
            if (index === this.currentStep) {
                step.classList.add('active');
            } else if (index < this.currentStep) {
                step.classList.add('completed');
            }
        });
        
        // Cargar los items en la pestaña de Caja al entrar a ella
        if (this.currentStep === 6) {
            if (typeof cargarCajaDesdeRegistro === 'function') {
                cargarCajaDesdeRegistro();
            }
        }
        
        this.updateProgressBar();
    },

    updateProgressBar: function() {
        const percent = (this.currentStep / this.totalSteps) * 100;
        const bar = document.getElementById('wizard-progress-fill');
        if (bar) bar.style.width = percent + '%';
    },

    validateCurrentStep: function() {
        // Validación personalizada en Caja (Paso 6) antes de avanzar
        if (this.currentStep === 6) {
            const cotSelect = document.getElementById('f_id_cotizacion');
            const convertirCheck = document.getElementById('f_convertir_tratamiento');
            
            if (cotSelect && cotSelect.value && convertirCheck && convertirCheck.checked) {
                const montoInput = document.getElementById('f_caja_monto_abono');
                const montoVal = parseFloat(montoInput.value) || 0;
                
                if (montoVal <= 0) {
                    Swal.fire('Atención', 'Por favor, ingrese un monto de abono válido.', 'warning');
                    return false;
                }
                
                const estadoTrat = document.getElementById('f_caja_estado_tratamiento').value;
                const citaId = document.getElementById('f_proxima_cita_id').value;
                
                if (estadoTrat === 'Abierto' && !citaId) {
                    Swal.fire('Cita Requerida', 'Es obligatorio agendar la próxima cita de seguimiento para dejar el tratamiento abierto.', 'warning');
                    return false;
                }
            }
        }

        const currentPanel = document.getElementById('step-panel-' + this.currentStep);
        if (!currentPanel) return true;
        
        let isValid = true;
        const requiredInputs = currentPanel.querySelectorAll('[required]');
        
        requiredInputs.forEach(input => {
            if (!input.value.trim()) {
                input.classList.add('is-invalid');
                isValid = false;
            } else {
                input.classList.remove('is-invalid');
            }
        });
        
        if (!isValid) {
            if (typeof Swal !== 'undefined') {
                Swal.fire({
                    icon: 'warning',
                    title: 'Campos Incompletos',
                    text: 'Por favor, complete todos los campos obligatorios antes de continuar.',
                    toast: true,
                    position: 'top-end',
                    showConfirmButton: false,
                    timer: 3000
                });
            }
        }
        
        return isValid;
    }
};

// Escuchar cambios para limpiar is-invalid
document.addEventListener('input', function(e) {
    if (e.target.classList && e.target.classList.contains('is-invalid')) {
        e.target.classList.remove('is-invalid');
    }
});
