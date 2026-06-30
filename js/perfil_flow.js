/**
 * js/perfil_flow.js
 * Motor de control para las pestañas de Configuración de Perfil SDM Diamond
 */

const PerfilWizardController = {
    currentStep: 0,
    totalSteps: 0, // Set in init
    
    init: function(total) {
        this.totalSteps = total;
        this.currentStep = 0;
        this.renderStep();
        this.bindEvents();
    },
    
    bindEvents: function() {
        // Interceptar Enter en inputs (para no submitear el formulario accidentalmente)
        document.addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA') {
                e.preventDefault();
            }
        });
    },

    nextStep: function() {
        if (this.currentStep < this.totalSteps) {
            this.currentStep++;
            this.renderStep();
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
        // En el perfil, permitimos navegación libre entre tabs
        this.currentStep = stepIndex;
        this.renderStep();
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
        
        this.updateProgressBar();
    },

    updateProgressBar: function() {
        if(this.totalSteps === 0) return;
        const percent = (this.currentStep / this.totalSteps) * 100;
        const bar = document.getElementById('wizard-progress-fill');
        if (bar) bar.style.width = percent + '%';
    }
};
