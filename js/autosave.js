/**
 * js/autosave.js
 * Servicio de Autoguardado Incremental para el Wizard Clínico
 */

const AutosaveService = {
    intervalId: null,
    saveIntervalMs: 30000, // 30 segundos
    lastPayloadString: '',
    endpoint: '../api/autosave_consulta.pl',
    isSaving: false,
    
    init: function(idPaciente, idCita, idMedico) {
        this.idPaciente = idPaciente;
        this.idCita = idCita;
        this.idMedico = idMedico;
        
        // Iniciar timer
        this.intervalId = setInterval(() => this.triggerSave(), this.saveIntervalMs);
        
        // UI Indicator
        if (!document.getElementById('autosave-ui')) {
            const ui = document.createElement('div');
            ui.id = 'autosave-ui';
            ui.className = 'autosave-indicator';
            ui.innerHTML = '<i class="bi bi-cloud-check"></i> <span id="autosave-text">Guardado</span>';
            document.body.appendChild(ui);
        }
    },
    
    stop: function() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
    },
    
    collectData: function() {
        const formData = new FormData();
        formData.append('id_paciente', this.idPaciente || '');
        formData.append('id_cita', this.idCita || '');
        formData.append('id_medico', this.idMedico || '');
        formData.append('current_step', WizardController.currentStep);
        
        // Recolectar todos los inputs y textareas del wizard
        const inputs = document.querySelectorAll('.wizard-panel input, .wizard-panel textarea, .wizard-panel select');
        const dataObj = {};
        
        inputs.forEach(el => {
            if (el.name) {
                if (el.type === 'checkbox' || el.type === 'radio') {
                    if (el.checked) {
                        dataObj[el.name] = el.value;
                        formData.append(el.name, el.value);
                    }
                } else {
                    dataObj[el.name] = el.value;
                    formData.append(el.name, el.value);
                }
            }
        });
        
        // Incluir la receta médica (carrito en scope global)
        if (typeof carrito !== 'undefined') {
            dataObj['medicamentos'] = carrito;
            formData.append('medicamentos_json', JSON.stringify(carrito));
        }
        
        // Stringify para comparar si hubo cambios reales
        const currentString = JSON.stringify(dataObj);
        
        return {
            hasChanges: currentString !== this.lastPayloadString,
            stringified: currentString,
            formData: formData
        };
    },
    
    triggerSave: async function() {
        if (this.isSaving) return;
        
        const data = this.collectData();
        if (!data.hasChanges) return; // No guardar si nada cambió
        
        this.isSaving = true;
        this.showIndicator('Guardando...', 'bi-cloud-upload', true);
        
        try {
            const res = await fetch(this.endpoint, {
                method: 'POST',
                body: data.formData
            });
            
            const json = await res.json();
            if (json.ok) {
                this.lastPayloadString = data.stringified;
                this.showIndicator('Guardado Automático', 'bi-cloud-check', false);
                setTimeout(() => this.hideIndicator(), 2000);
            } else {
                console.error("Autosave backend error:", json.msg);
                this.showIndicator('Error al guardar', 'bi-cloud-slash text-danger', false);
            }
        } catch(e) {
            console.error("Autosave fetch error:", e);
            this.showIndicator('Sin conexión', 'bi-wifi-off text-warning', false);
        } finally {
            this.isSaving = false;
        }
    },
    
    showIndicator: function(text, iconClass, isSpinning) {
        const ui = document.getElementById('autosave-ui');
        if (!ui) return;
        
        ui.innerHTML = `<i class="bi ${iconClass} ${isSpinning ? 'spinner-border spinner-border-sm' : ''}"></i> <span id="autosave-text">${text}</span>`;
        ui.classList.add('show');
    },
    
    hideIndicator: function() {
        const ui = document.getElementById('autosave-ui');
        if (ui) ui.classList.remove('show');
    }
};
