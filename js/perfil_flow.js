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
        if (this.currentStep < this.totalSteps - 1) {
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

window.validarYPrevisualizarAvatar = function(input) {
    if (!input.files || !input.files[0]) return;
    const file = input.files[0];
    
    // 1. Tipos de archivo permitidos (JPG, PNG, WebP)
    const validMimes = ['image/jpeg', 'image/png', 'image/webp'];
    const ext = file.name.split('.').pop().toLowerCase();
    const validExts = ['jpg', 'jpeg', 'png', 'webp'];
    if (!validMimes.includes(file.type) && !validExts.includes(ext)) {
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'warning',
                title: 'Formato no admitido',
                text: 'Únicamente se permiten imágenes en formatos JPG, PNG o WebP.',
                confirmButtonColor: '#19B7A5'
            });
        } else {
            alert('Formato no admitido. Usa JPG, PNG o WebP.');
        }
        input.value = '';
        return;
    }
    
    // 2. Peso máximo permitido: 2 MB (2,097,152 bytes)
    const maxSize = 2 * 1024 * 1024;
    if (file.size > maxSize) {
        const pesoMB = (file.size / (1024 * 1024)).toFixed(2);
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'warning',
                title: 'Imagen muy pesada (' + pesoMB + ' MB)',
                text: 'El tamaño máximo permitido es de 2 MB para asegurar rapidez y optimización.',
                confirmButtonColor: '#19B7A5'
            });
        } else {
            alert('El archivo supera el tamaño máximo permitido de 2 MB.');
        }
        input.value = '';
        return;
    }

    // 3. Previsualizar de inmediato en el círculo perfecto
    const reader = new FileReader();
    reader.onload = function(e) {
        const previewHeader = document.getElementById('avatar_preview_header');
        const iconHeader = document.getElementById('avatar_placeholder_icon');
        
        if (previewHeader) {
            previewHeader.src = e.target.result;
            previewHeader.classList.remove('d-none');
        }
        if (iconHeader) {
            iconHeader.classList.add('d-none');
        }
    };
    reader.readAsDataURL(file);
};
