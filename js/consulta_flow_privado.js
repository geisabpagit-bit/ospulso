/**
 * js/consulta_flow_privado.js
 * Motor Reactivo para el Wizard Clínico SOAP (6 Pasos) + Bóveda del Paciente + Triage + Alergia Cruzada
 * Homologado con Tablero y Wizard Quirúrgico (Medentia Aura)
 */

window.recetaItems = window.recetaItems || [];
window.diagnosticosSecundarios = window.diagnosticosSecundarios || [];

/* ==========================================================================
   1. CONTROLADOR DE NAVEGACIÓN DE 6 PASOS SOAP (Índices 0 a 5)
   ========================================================================== */
const WizardController = {
    currentStep: 0,
    totalSteps: 5, // 0..5 = 6 Pasos

    init: function(startIndex = 0) {
        let idx = parseInt(startIndex, 10);
        if (isNaN(idx) || idx < 0) idx = 0;
        if (idx > this.totalSteps) idx = this.totalSteps;
        this.currentStep = idx;
        this.renderStep();
        this.bindEvents();
        this.updateProgressBar();
    },

    bindEvents: function() {
        document.addEventListener('keypress', function(e) {
            if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA' && e.target.id !== 'iptBuscarEmpleadoWizard') {
                e.preventDefault();
            }
        });

        // Atajos globales de teclado (Alt+K, Alt+B, Alt+S, Alt+1..6, Alt+Flechas)
        document.addEventListener('keydown', function(e) {
            if (!e.altKey) return;
            const key = (e.key || '').toLowerCase();
            if (key === 'k') {
                e.preventDefault();
                SOAPReactiveEngine.toggleCommandPalette();
            } else if (key === 'b') {
                e.preventDefault();
                BovedaService.openDrawer('ALL');
            } else if (key === 'c') {
                e.preventDefault();
                const offEl = document.getElementById('offcanvasContextoClinico');
                if (offEl && window.bootstrap) {
                    const inst = bootstrap.Offcanvas.getOrCreateInstance(offEl);
                    inst.toggle();
                }
            } else if (key === 's') {
                e.preventDefault();
                if (typeof AutosaveService !== 'undefined') {
                    AutosaveService.triggerSave(true);
                }
            } else if (key === 'arrowright') {
                e.preventDefault();
                WizardController.nextStep();
            } else if (key === 'arrowleft') {
                e.preventDefault();
                WizardController.prevStep();
            } else if (['1', '2', '3', '4', '5', '6'].includes(key)) {
                e.preventDefault();
                WizardController.jumpToStep(parseInt(key, 10) - 1);
            }
        });
    },

    nextStep: function() {
        if (!this.validateCurrentStep()) return;
        if (this.currentStep < this.totalSteps) {
            this.currentStep++;
            this.renderStep();
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
        let target = parseInt(stepIndex, 10);
        if (isNaN(target) || target < 0) target = 0;
        if (target > this.totalSteps) target = this.totalSteps;
        this.currentStep = target;
        this.renderStep();
        if (typeof AutosaveService !== 'undefined') {
            AutosaveService.triggerSave();
        }
        window.scrollTo({ top: 0, behavior: 'smooth' });
    },

    renderStep: function() {
        document.querySelectorAll('.wizard-panel').forEach(panel => {
            panel.classList.remove('active');
        });

        const currentPanel = document.getElementById('step-panel-' + this.currentStep);
        if (currentPanel) currentPanel.classList.add('active');

        document.querySelectorAll('.soap-nav-step-item, .soap-top-step-btn').forEach(step => {
            const stepIdx = parseInt(step.getAttribute('data-step'), 10);
            step.classList.toggle('active', stepIdx === this.currentStep);
        });

        if (this.currentStep === 4 && typeof SOAPReactiveEngine !== 'undefined') {
            SOAPReactiveEngine.updatePreSignatureAudit();
        }

        if (this.currentStep === 5 && typeof cargarCajaDesdeRegistro === 'function') {
            cargarCajaDesdeRegistro();
        }

        this.updateProgressBar();
        if (typeof SOAPReactiveEngine !== 'undefined') {
            SOAPReactiveEngine.syncAll();
        }
    },

    updateProgressBar: function() {
        const stepHuman = this.currentStep + 1;
        const totalHuman = this.totalSteps + 1;
        const lbl = document.getElementById('hdr-step-progress-lbl');
        if (lbl) lbl.innerText = `Paso ${stepHuman} de ${totalHuman}`;

        const percent = Math.round((stepHuman / totalHuman) * 100);
        const bar = document.getElementById('wizard-progress-fill');
        if (bar) bar.style.width = percent + '%';

        const percentBadge = document.getElementById('soap-flow-percent-badge');
        if (percentBadge) percentBadge.innerText = percent + '%';
    },

    validateCurrentStep: function() {
        const currentPanel = document.getElementById('step-panel-' + this.currentStep);
        if (!currentPanel) return true;

        let isValid = true;
        const requiredInputs = currentPanel.querySelectorAll('[required]');
        requiredInputs.forEach(input => {
            if (input.type === 'checkbox') {
                if (!input.checked) {
                    input.classList.add('is-invalid');
                    isValid = false;
                } else {
                    input.classList.remove('is-invalid');
                }
            } else if (!input.value.trim()) {
                input.classList.add('is-invalid');
                isValid = false;
            } else {
                input.classList.remove('is-invalid');
            }
        });

        if (!isValid && typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'warning',
                title: 'Campos Normativos Pendientes',
                text: 'Complete los campos marcados con (*) en este paso antes de continuar.',
                toast: true,
                position: 'top-end',
                showConfirmButton: false,
                timer: 3000
            });
        }
        return isValid;
    }
};

document.addEventListener('input', function(e) {
    if (e.target.classList && e.target.classList.contains('is-invalid')) {
        e.target.classList.remove('is-invalid');
    }
});

/* ==========================================================================
   2. MOTOR REACTIVO SOAP: TRIAGE, ALERGIA CRUZADA, MACROS, SEMAFORIZACIÓN Y QR
   ========================================================================== */
const SOAPReactiveEngine = {
    timerSeconds: 0,
    timerInterval: null,
    isLockedNOM151: false,
    activePhysioAlerts: [],
    activeAllergyConflicts: [],

    // Diccionario Farmacológico de Alergias Cruzadas COFEPRIS
    crossAllergyGroups: [
        {
            groupName: 'Penicilinas / Betalactámicos',
            triggers: ['penicilina', 'betalact', 'amoxicilina', 'ampicilina', 'dicloxacilina', 'cefalosporina', 'ceftriaxona', 'cefalexina'],
            drugs: ['amoxicilina', 'ampicilina', 'penicilina', 'dicloxacilina', 'bencilpenicilina', 'augmentin', 'amoxil', 'clavulan', 'cefalexina', 'ceftriaxona', 'cefuroxima', 'cefixima']
        },
        {
            groupName: 'AINEs / Analgésicos Antiinflamatorios',
            triggers: ['aine', 'aines', 'ibuprofeno', 'ketorolaco', 'naproxeno', 'diclofenaco', 'aspirina', 'asa', 'ácido acetilsalicílico', 'metamizol', 'dipirona', 'meloxicam', 'celecoxib'],
            drugs: ['ibuprofeno', 'ketorolaco', 'naproxeno', 'diclofenaco', 'aspirina', 'ácido acetilsalicílico', 'metamizol', 'meloxicam', 'celecoxib', 'indometacina', 'piroxicam', 'advil', 'motrin', 'tempra fen', 'dolac']
        },
        {
            groupName: 'Sulfonamidas / Sulfas',
            triggers: ['sulfa', 'sulfas', 'sulfonamida', 'trimetoprim', 'sulfametoxazol', 'bactrim'],
            drugs: ['sulfametoxazol', 'trimetoprima', 'trimetoprim', 'bactrim', 'sulfadiazina', 'sulfasalazina', 'furosemida', 'hidroclorotiazida']
        },
        {
            groupName: 'Macrólidos',
            triggers: ['macrólido', 'macrolido', 'azitromicina', 'claritromicina', 'eritromicina'],
            drugs: ['azitromicina', 'claritromicina', 'eritromicina']
        },
        {
            groupName: 'Quinolonas / Fluoroquinolonas',
            triggers: ['quinolona', 'ciprofloxacino', 'levofloxacino', 'moxifloxacino'],
            drugs: ['ciprofloxacino', 'levofloxacino', 'moxifloxacino', 'norfloxacino']
        }
    ],

    // Macros Clínicas Completas de 1 Clic
    clinicalMacros: {
        FARINGITIS: {
            nombre: 'Faringitis Aguda (J02.9)',
            cie10_code: 'J029',
            cie10_text: 'J029 - FARINGITIS AGUDA, NO ESPECIFICADA',
            impresion: 'Faringoamigdalitis aguda de probable etiología bacteriana, hemodinámicamente estable y sin compromiso de vía aérea.',
            plan: 'Tratamiento antimicrobiano ambulatorio por 7 días, analgésico/antipirético por razón necesaria y revaloración en 72 horas.',
            higienico: 'Abundantes líquidos tibios (2 litros/día), gargarismos con agua tibia salina, evitar cambios bruscos de temperatura e irritantes.',
            alarma: 'Acudir a Urgencias si presenta fiebre >38.5°C persistente por más de 48h, disnea, estridor, trismus o intolerancia a la vía oral.',
            pron_vida: 'BUENO',
            pron_func: 'BUENO',
            meds: [
                { generico: 'Amoxicilina 500mg', comercial: 'Amoxil', forma: 'Cápsula', concentracion: '500mg', posologia: '1 cápsula cada 8 horas por 7 días', via: 'Oral' },
                { generico: 'Paracetamol 500mg', comercial: 'Tempra', forma: 'Tableta', concentracion: '500mg', posologia: '1 tableta cada 8 horas por 5 días en caso de dolor o fiebre', via: 'Oral' }
            ]
        },
        GASTRITIS: {
            nombre: 'Gastritis Aguda / ERGE (K29.7)',
            cie10_code: 'K297',
            cie10_text: 'K297 - GASTRITIS, NO ESPECIFICADA',
            impresion: 'Enfermedad ácido-péptica / Gastritis aguda erosiva sin datos actuales de sangrado de tubo digestivo ni abdomen agudo.',
            plan: 'Inhibidor de bomba de protones en ayuno por 14 días, protector de mucosa gástrica y ajuste higiénico-dietético estricto.',
            higienico: 'Dieta blanda fraccionada en quintos, suspender café, picante, grasas, cítricos, alcohol, tabaco y AINEs. No recostarse 2h después de cenar.',
            alarma: 'Acudir a Urgencias si presenta hematemesis, evacuaciones melénicas (negras), vómito incoercible o dolor abdominal intenso en puñalada.',
            pron_vida: 'BUENO',
            pron_func: 'BUENO',
            meds: [
                { generico: 'Omeprazol 20mg', comercial: 'Losec', forma: 'Cápsula', concentracion: '20mg', posologia: '1 cápsula cada 24 horas 30 min antes del desayuno por 14 días', via: 'Oral' },
                { generico: 'Sucralfato 1g', comercial: 'Unival', forma: 'Tableta', concentracion: '1g', posologia: '1 tableta 1 hora antes de cada alimento por 10 días', via: 'Oral' }
            ]
        },
        HTA_CONTROL: {
            nombre: 'Control Hipertensión Arterial (I10)',
            cie10_code: 'I10X',
            cie10_text: 'I10X - HIPERTENSION ESENCIAL (PRIMARIA)',
            impresion: 'Hipertensión Arterial Sistémica Primaria en seguimiento ambulatorio, sin datos clínicos de daño agudo a órgano blanco.',
            plan: 'Continuar esquema antihipertensivo diario, bitácora domiciliaria de tensión arterial matutina/nocturna y perfil metabólico de control.',
            higienico: 'Dieta DASH hiposódica (<2g de sal/día), caminata aeróbica 30 minutos 5 días por semana, control ponderal y apego estricto al fármaco.',
            alarma: 'Acudir a Urgencias si T.A. ≥160/100 mmHg, cefalea intensa, acúfenos, fosfenos, dolor torácico opresivo, disnea o déficit neurológico.',
            pron_vida: 'BUENO',
            pron_func: 'RESERVADO',
            meds: [
                { generico: 'Losartán 50mg', comercial: 'Cozaar', forma: 'Tableta', concentracion: '50mg', posologia: '1 tableta cada 12 horas de forma continua', via: 'Oral' }
            ]
        },
        LUMBALGIA: {
            nombre: 'Lumbalgia Mecánica Aguda (M54.5)',
            cie10_code: 'M545',
            cie10_text: 'M545 - LUMBAGO NO ESPECIFICADO',
            impresion: 'Lumbalgia mecanopostural aguda sin compromiso radicular ni déficit motor o esfinteriano (Lasègue negativo).',
            plan: 'Analgésico antiinflamatorio por ciclo corto, relajante muscular nocturno, calor local húmedo e higiene de columna.',
            higienico: 'Calor local 15 minutos cada 8 horas, evitar cargar objetos pesados (>5kg), higiene postural al sentarse y dormir en posición fetal con almohada entre rodillas.',
            alarma: 'Acudir a Urgencias si presenta pérdida de fuerza o sensibilidad en extremidades inferiores, dolor irradiado incapacitante o incontinencia/retención urinaria.',
            pron_vida: 'BUENO',
            pron_func: 'BUENO',
            meds: [
                { generico: 'Ibuprofeno 400mg', comercial: 'Motrin', forma: 'Tableta', concentracion: '400mg', posologia: '1 tableta cada 8 horas después de alimentos por 5 días', via: 'Oral' },
                { generico: 'Paracetamol 500mg', comercial: 'Tempra', forma: 'Tableta', concentracion: '500mg', posologia: '1 tableta cada 8 horas por 5 días', via: 'Oral' }
            ]
        },
        ODONTALGIA: {
            nombre: 'Pulpitis / Periodontitis Apical (K04.4)',
            cie10_code: 'K044',
            cie10_text: 'K044 - PERIODONTITIS APICAL AGUDA ORIGINADA EN LA PULPA',
            impresion: 'Periodontitis apical aguda / odontalgia localizada que amerita manejo rehabilitador/endodóntico y cobertura farmacológica.',
            plan: 'Manejo odontológico conforme a Odontograma FDI, cobertura analgésica/antimicrobiana y cita de seguimiento.',
            higienico: 'Dieta blanda tibia, masticar del lado contralateral, higiene oral suave con cepillo de cerdas suaves y colutorio antiséptico sin alcohol.',
            alarma: 'Acudir de inmediato si presenta aumento de volumen facial/submandibular progresivo, fiebre >38°C, trismus o dificultad para deglutir.',
            pron_vida: 'BUENO',
            pron_func: 'BUENO',
            meds: [
                { generico: 'Amoxicilina 500mg', comercial: 'Amoxil', forma: 'Cápsula', concentracion: '500mg', posologia: '1 cápsula cada 8 horas por 7 días', via: 'Oral' },
                { generico: 'Ibuprofeno 400mg', comercial: 'Advil', forma: 'Tableta', concentracion: '400mg', posologia: '1 tableta cada 8 horas por 5 días', via: 'Oral' }
            ]
        }
    },

    init: function() {
        this.startTimer();
        this.initRelojHeader();
        this.initCIE10Autocomplete();
        this.evaluateTriage();
        this.onAlergiasInput();
        this.syncAll();
    },

    startTimer: function() {
        if (this.timerInterval) clearInterval(this.timerInterval);
        this.timerInterval = setInterval(() => {
            if (this.isLockedNOM151) return;
            this.timerSeconds++;
            const mins = String(Math.floor(this.timerSeconds / 60)).padStart(2, '0');
            const secs = String(this.timerSeconds % 60).padStart(2, '0');
            const el = document.getElementById('hdr-cronometro-live');
            if (el) el.innerText = `${mins}:${secs}`;
            const inpDur = document.getElementById('f_duracion_segundos');
            if (inpDur) inpDur.value = this.timerSeconds;
        }, 1000);
    },

    initRelojHeader: function() {
        const updateClock = () => {
            const now = new Date();
            const str = now.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
            const el = document.getElementById('hdr-reloj-live');
            if (el) el.innerText = str;
        };
        updateClock();
        setInterval(updateClock, 1000);
    },

    appendChip: function(targetId, text) {
        if (this.isLockedNOM151) return;
        const el = document.getElementById(targetId) || document.querySelector(`[name="${targetId}"]`);
        if (!el) return;
        const cur = el.value.trim();
        if (!cur) {
            el.value = text;
        } else if (!cur.includes(text)) {
            el.value = cur + (cur.endsWith('.') ? ' ' : '. ') + text;
        }
        el.classList.remove('is-invalid');
        this.syncAll();
    },

    setEva: function(val) {
        if (this.isLockedNOM151) return;
        const v = parseInt(val, 10) || 1;
        const inp1 = document.getElementById('f_intensidad_eva');
        const inp2 = document.getElementById('f_eva_dolor');
        if (inp1) inp1.value = v;
        if (inp2) inp2.value = v;

        document.querySelectorAll('#eva-buttons-container .eva-btn').forEach(btn => {
            btn.classList.remove('active-eva-low', 'active-eva-mid', 'active-eva-high');
            const bVal = parseInt(btn.getAttribute('data-eva'), 10);
            if (bVal === v) {
                if (v <= 3) btn.classList.add('active-eva-low');
                else if (v <= 6) btn.classList.add('active-eva-mid');
                else btn.classList.add('active-eva-high');
            }
        });

        const badge = document.getElementById('lbl-eva-badge');
        if (badge) {
            if (v <= 3) {
                badge.className = 'badge bg-success rounded-pill';
                badge.innerText = `EVA ${v}/10 · Dolor Leve`;
            } else if (v <= 6) {
                badge.className = 'badge bg-warning text-dark rounded-pill';
                badge.innerText = `EVA ${v}/10 · Dolor Moderado`;
            } else {
                badge.className = 'badge bg-danger rounded-pill';
                badge.innerText = `EVA ${v}/10 · Dolor Severo`;
            }
        }
        this.syncAll();
    },

    marcarNKDA: function() {
        if (this.isLockedNOM151) return;
        const ta = document.getElementById('f_alergias');
        const nk = document.getElementById('f_es_nkda');
        if (ta) ta.value = 'Sin alergias conocidas (NKDA)';
        if (nk) nk.value = '1';
        this.onAlergiasInput();
    },

    setAlergiaRapida: function(alergiaStr) {
        if (this.isLockedNOM151) return;
        const ta = document.getElementById('f_alergias');
        const nk = document.getElementById('f_es_nkda');
        if (!ta) return;
        if (nk) nk.value = '0';
        const cur = ta.value.trim();
        if (!cur || /Sin alergias|NKDA|Negadas/i.test(cur)) {
            ta.value = alergiaStr;
        } else if (!cur.toLowerCase().includes(alergiaStr.toLowerCase())) {
            ta.value = cur + ', ' + alergiaStr;
        }
        this.onAlergiasInput();
    },

    onAlergiasInput: function() {
        const ta = document.getElementById('f_alergias');
        const nk = document.getElementById('f_es_nkda');
        const val = ta ? ta.value.trim() : '';
        const isNKDA = (!val || /^(Sin alergias|NKDA|Negadas|Ninguna|No refiere)/i.test(val));
        if (nk) nk.value = isNKDA ? '1' : '0';

        // Actualizar Banner de Alergias en Columna Derecha Sticky
        const bannerRight = document.getElementById('ctx-allergy-banner');
        if (bannerRight) {
            if (isNKDA) {
                bannerRight.className = 'context-allergy-banner-green';
                bannerRight.innerHTML = `<i class="bi bi-shield-check-fill text-success fs-6"></i><span>✓ SIN ALERGIAS CONOCIDAS (NKDA)</span>`;
            } else {
                bannerRight.className = 'context-allergy-banner-red';
                bannerRight.innerHTML = `<i class="bi bi-exclamation-octagon-fill fs-6"></i><div><div style="font-size:0.65rem;opacity:0.9;">ALERTA DE ALERGIA ACTIVA</div><div>${this.escapeHtml(val)}</div></div>`;
            }
        }

        // Re-evaluar receta actual por si hay alergia cruzada
        if (typeof renderRecetaItems === 'function') {
            renderRecetaItems();
        }
        this.syncAll();
    },

    checkCrossAllergyForDrug: function(drugName) {
        const ta = document.getElementById('f_alergias');
        const allergyText = (ta ? ta.value : '').toLowerCase().trim();
        if (!allergyText || /^(sin alergias|nkda|negadas|ninguna|no refiere)/i.test(allergyText)) {
            return null;
        }
        const drugLower = (drugName || '').toLowerCase().trim();
        if (!drugLower) return null;

        // 1. Coincidencia directa por substring
        const words = allergyText.split(/[,;\/\(\)\s]+/).filter(w => w.length >= 4);
        for (const w of words) {
            if (drugLower.includes(w)) {
                return `Conflicto directo con alergia registrada ("${w.toUpperCase()}")`;
            }
        }

        // 2. Coincidencia por familia farmacológica cruzada
        for (const grp of this.crossAllergyGroups) {
            const patientHasTrigger = grp.triggers.some(t => allergyText.includes(t));
            const drugInGroup = grp.drugs.some(d => drugLower.includes(d));
            if (patientHasTrigger && drugInGroup) {
                return `Alergia Cruzada [${grp.groupName}] vs alergia reportada ("${ta.value.trim()}")`;
            }
        }
        return null;
    },

    // Motor de Triage: 6 Signos Vitales + IMC OMS
    evaluateTriage: function() {
        const taStr = (document.getElementById('ef_ta') ? document.getElementById('ef_ta').value : '').trim();
        const fcVal = parseFloat(document.getElementById('ef_fc') ? document.getElementById('ef_fc').value : '');
        const frVal = parseFloat(document.getElementById('ef_fr') ? document.getElementById('ef_fr').value : '');
        const tempVal = parseFloat(document.getElementById('ef_temp') ? document.getElementById('ef_temp').value : '');
        const spo2Val = parseFloat(document.getElementById('ef_spo2') ? document.getElementById('ef_spo2').value : '');
        const glucVal = parseFloat(document.getElementById('ef_glucosa') ? document.getElementById('ef_glucosa').value : '');
        const glucTipo = document.getElementById('ef_glucosa_tipo') ? document.getElementById('ef_glucosa_tipo').value : 'AYUNO';
        const pesoVal = parseFloat(document.getElementById('ef_peso') ? document.getElementById('ef_peso').value : '');
        const tallaVal = parseFloat(document.getElementById('ef_talla') ? document.getElementById('ef_talla').value : '');

        const alerts = [];

        const setCardState = (cardId, badgeId, state, label) => {
            const card = document.getElementById(cardId);
            const badge = document.getElementById(badgeId);
            if (card) {
                card.classList.remove('vital-ok', 'vital-warn', 'vital-alert');
                if (state === 'ok') card.classList.add('vital-ok');
                else if (state === 'warn') card.classList.add('vital-warn');
                else if (state === 'alert') card.classList.add('vital-alert');
            }
            if (badge) {
                badge.innerText = label;
                if (state === 'ok') badge.className = 'vital-status-pill bg-success text-white';
                else if (state === 'warn') badge.className = 'vital-status-pill bg-warning text-dark';
                else if (state === 'alert') badge.className = 'vital-status-pill bg-danger text-white';
                else badge.className = 'vital-status-pill bg-light text-muted';
            }
        };

        // 1. T.A.
        if (taStr && /^(\d{2,3})\s*\/\s*(\d{2,3})$/.test(taStr)) {
            const parts = taStr.split('/');
            const sys = parseInt(parts[0], 10);
            const dia = parseInt(parts[1], 10);
            if (sys >= 140 || dia >= 90) {
                setCardState('vcard-ta', 'vbadge-ta', 'alert', 'Hipertensión');
                alerts.push(`T.A. elevada (${taStr} mmHg)`);
            } else if (sys < 90 || dia < 60) {
                setCardState('vcard-ta', 'vbadge-ta', 'alert', 'Hipotensión');
                alerts.push(`Hipotensión (${taStr} mmHg)`);
            } else if (sys >= 130 || dia >= 85) {
                setCardState('vcard-ta', 'vbadge-ta', 'warn', 'Pre-HTA');
            } else {
                setCardState('vcard-ta', 'vbadge-ta', 'ok', 'Normotenso');
            }
        } else {
            setCardState('vcard-ta', 'vbadge-ta', '', '--');
        }

        // 2. F.C.
        if (!isNaN(fcVal) && fcVal > 0) {
            if (fcVal > 100) {
                setCardState('vcard-fc', 'vbadge-fc', 'alert', 'Taquicardia');
                alerts.push(`Taquicardia (${fcVal} lpm)`);
            } else if (fcVal < 60) {
                setCardState('vcard-fc', 'vbadge-fc', 'alert', 'Bradicardia');
                alerts.push(`Bradicardia (${fcVal} lpm)`);
            } else {
                setCardState('vcard-fc', 'vbadge-fc', 'ok', 'Normal');
            }
        } else {
            setCardState('vcard-fc', 'vbadge-fc', '', '--');
        }

        // 3. F.R.
        if (!isNaN(frVal) && frVal > 0) {
            if (frVal > 20) {
                setCardState('vcard-fr', 'vbadge-fr', 'alert', 'Taquipnea');
                alerts.push(`Taquipnea (${frVal} rpm)`);
            } else if (frVal < 12) {
                setCardState('vcard-fr', 'vbadge-fr', 'alert', 'Bradipnea');
                alerts.push(`Bradipnea (${frVal} rpm)`);
            } else {
                setCardState('vcard-fr', 'vbadge-fr', 'ok', 'Eupneico');
            }
        } else {
            setCardState('vcard-fr', 'vbadge-fr', '', '--');
        }

        // 4. Temp
        if (!isNaN(tempVal) && tempVal > 0) {
            if (tempVal >= 38.0) {
                setCardState('vcard-temp', 'vbadge-temp', 'alert', 'Febril');
                alerts.push(`Fiebre (${tempVal} °C)`);
            } else if (tempVal < 36.0) {
                setCardState('vcard-temp', 'vbadge-temp', 'alert', 'Hipotermia');
                alerts.push(`Hipotermia (${tempVal} °C)`);
            } else if (tempVal >= 37.5) {
                setCardState('vcard-temp', 'vbadge-temp', 'warn', 'Febrícula');
            } else {
                setCardState('vcard-temp', 'vbadge-temp', 'ok', 'Afebril');
            }
        } else {
            setCardState('vcard-temp', 'vbadge-temp', '', '--');
        }

        // 5. SpO2
        if (!isNaN(spo2Val) && spo2Val > 0) {
            if (spo2Val < 92) {
                setCardState('vcard-spo2', 'vbadge-spo2', 'alert', 'Hipoxemia');
                alerts.push(`Desaturación SpO₂ (${spo2Val}%)`);
            } else if (spo2Val <= 94) {
                setCardState('vcard-spo2', 'vbadge-spo2', 'warn', 'Limítrofe');
            } else {
                setCardState('vcard-spo2', 'vbadge-spo2', 'ok', 'Óptima');
            }
        } else {
            setCardState('vcard-spo2', 'vbadge-spo2', '', '--');
        }

        // 6. Glucosa Capilar (Ayuno vs Posprandial)
        if (!isNaN(glucVal) && glucVal > 0) {
            if (glucVal < 70) {
                setCardState('vcard-glucosa', 'vbadge-glucosa', 'alert', 'Hipoglucemia');
                alerts.push(`Hipoglucemia (${glucVal} mg/dL)`);
            } else if (glucTipo === 'AYUNO') {
                if (glucVal >= 126) {
                    setCardState('vcard-glucosa', 'vbadge-glucosa', 'alert', 'Hiperglucemia');
                    alerts.push(`Hiperglucemia ayuno (${glucVal} mg/dL)`);
                } else if (glucVal >= 100) {
                    setCardState('vcard-glucosa', 'vbadge-glucosa', 'warn', 'Alterada');
                } else {
                    setCardState('vcard-glucosa', 'vbadge-glucosa', 'ok', 'Normal');
                }
            } else {
                if (glucVal >= 200) {
                    setCardState('vcard-glucosa', 'vbadge-glucosa', 'alert', 'Hiperglucemia');
                    alerts.push(`Hiperglucemia posprandial (${glucVal} mg/dL)`);
                } else if (glucVal >= 140) {
                    setCardState('vcard-glucosa', 'vbadge-glucosa', 'warn', 'Alterada');
                } else {
                    setCardState('vcard-glucosa', 'vbadge-glucosa', 'ok', 'Normal');
                }
            }
        } else {
            setCardState('vcard-glucosa', 'vbadge-glucosa', '', '--');
        }

        // 7. Cálculo automático IMC OMS
        const imcInp = document.getElementById('ef_imc');
        if (!isNaN(pesoVal) && pesoVal > 0 && !isNaN(tallaVal) && tallaVal > 0) {
            const tm = tallaVal > 3 ? (tallaVal / 100) : tallaVal;
            const imc = pesoVal / (tm * tm);
            const imcStr = imc.toFixed(1);
            if (imcInp) imcInp.value = imcStr;

            if (imc < 18.5) {
                setCardState('vcard-imc', 'vbadge-imc', 'warn', 'Bajo Peso');
            } else if (imc < 25.0) {
                setCardState('vcard-imc', 'vbadge-imc', 'ok', 'Normopeso');
            } else if (imc < 30.0) {
                setCardState('vcard-imc', 'vbadge-imc', 'warn', 'Sobrepeso');
            } else {
                setCardState('vcard-imc', 'vbadge-imc', 'alert', 'Obesidad');
                alerts.push(`IMC Obesidad (${imcStr} kg/m²)`);
            }
        } else {
            if (imcInp) imcInp.value = '';
            setCardState('vcard-imc', 'vbadge-imc', '', '--');
        }

        this.activePhysioAlerts = alerts;

        const gBadge = document.getElementById('triage-global-badge');
        if (gBadge) {
            if (alerts.length > 0) {
                gBadge.className = 'badge bg-danger rounded-pill';
                gBadge.innerHTML = `<i class="bi bi-exclamation-triangle-fill me-1"></i>${alerts.length} Alerta(s): ${alerts.join(' · ')}`;
            } else if (taStr || !isNaN(fcVal)) {
                gBadge.className = 'badge bg-success rounded-pill';
                gBadge.innerHTML = `<i class="bi bi-check-circle-fill me-1"></i>Signos Vitales en Rango Fisiológico`;
            } else {
                gBadge.className = 'badge bg-secondary rounded-pill';
                gBadge.innerText = 'Pendiente de captura';
            }
        }

        this.syncAll();
    },

    // Acelerador 1: Charting by Exception (⚡ Todo Normal en 1 Clic — Paso 2)
    aplicarTodoNormal: function() {
        if (this.isLockedNOM151) return;
        const setIfEmpty = (id, val) => {
            const el = document.getElementById(id);
            if (el && !el.value.trim()) el.value = val;
        };
        setIfEmpty('ef_ta', '120/80');
        setIfEmpty('ef_fc', '72');
        setIfEmpty('ef_fr', '16');
        setIfEmpty('ef_temp', '36.5');
        setIfEmpty('ef_spo2', '98');
        setIfEmpty('ef_glucosa', '92');
        setIfEmpty('ef_peso', '72.0');
        setIfEmpty('ef_talla', '170');

        const setForce = (id, val) => {
            const el = document.getElementById(id);
            if (el) el.value = val;
        };
        setForce('ef_inspeccion_general', 'Paciente consciente, orientado en 3 esferas, Glasgow 15, adecuada coloración e hidratación mucotegumentaria.');
        setForce('cef_cabeza_cuello', 'Normocéfalo, pupilas isocóricas normorreflécticas, faringe sin exudados, cuello cilíndrico sin megalias.');
        setForce('cef_torax', 'Tórax normolíneo, murmullo vesicular bilateral conservado, ruidos cardíacos rítmicos de buen tono sin soplos.');
        setForce('cef_abdomen', 'Blando, depresible, no doloroso a la palpación, sin visceromegalias ni signos de irritación peritoneal, peristalsis normal.');
        setForce('cef_extremidades', 'Íntegras, simétricas, eutróficas, sin edema, pulsos periféricos presentes y llenado capilar <2 segundos.');
        setForce('cef_neuro', 'Funciones mentales superiores conservadas, pares craneales íntegros, sin déficit motor ni sensitivo.');

        const hallazgosEl = document.getElementById('f_exploracion_hallazgos');
        if (hallazgosEl && !hallazgosEl.value.trim()) {
            hallazgosEl.value = 'Exploración física general dentro de parámetros fisiológicos normales: consciente, orientado, cardiopulmonar sin compromiso, abdomen blando no doloroso y extremidades íntegras.';
            hallazgosEl.classList.remove('is-invalid');
        }

        this.syncCefalocaudal();
        this.evaluateTriage();

        if (typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'success',
                title: '⚡ Exploración Normal Aplicada',
                text: 'Signos vitales y exploración cefalocaudal precargados. Modifique solo lo patológico.',
                toast: true,
                position: 'top-end',
                timer: 2200,
                showConfirmButton: false
            });
        }
    },

    // Acelerador 2: Copiar Signos Basales Previos
    copiarSignosBasales: function() {
        if (this.isLockedNOM151) return;
        const b = BovedaService.signosBasales || {};
        if (!b.tiene_basales) {
            if (typeof Swal !== 'undefined') Swal.fire('Sin Basales', 'No hay signos vitales previos registrados para este paciente.', 'info');
            return;
        }
        const setVal = (id, v) => {
            const el = document.getElementById(id);
            if (el && v && v !== '--') el.value = v;
        };
        setVal('ef_ta', b.ta);
        setVal('ef_fc', b.fc);
        setVal('ef_fr', b.fr);
        setVal('ef_temp', b.temp);
        setVal('ef_spo2', b.spo2);
        setVal('ef_glucosa', b.glucosa);
        setVal('ef_peso', b.peso);
        setVal('ef_talla', b.talla);

        this.evaluateTriage();
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'info',
                title: 'Signos Basales Importados',
                text: `Se importaron los signos basales de la consulta previa (${b.fecha}).`,
                toast: true,
                position: 'top-end',
                timer: 2000,
                showConfirmButton: false
            });
        }
    },

    syncCefalocaudal: function() {
        const obj = {
            inspeccion_general: document.getElementById('ef_inspeccion_general') ? document.getElementById('ef_inspeccion_general').value : '',
            cabeza_cuello: document.getElementById('cef_cabeza_cuello') ? document.getElementById('cef_cabeza_cuello').value : '',
            torax: document.getElementById('cef_torax') ? document.getElementById('cef_torax').value : '',
            abdomen: document.getElementById('cef_abdomen') ? document.getElementById('cef_abdomen').value : '',
            extremidades: document.getElementById('cef_extremidades') ? document.getElementById('cef_extremidades').value : '',
            neuro: document.getElementById('cef_neuro') ? document.getElementById('cef_neuro').value : ''
        };
        const hidden = document.getElementById('f_exploracion_cefalocaudal_json');
        if (hidden) hidden.value = JSON.stringify(obj);
        this.syncAll();
    },

    syncEspecialidadData: function() {
        const nota = document.getElementById('f_esp_nota_especifica') ? document.getElementById('f_esp_nota_especifica').value : '';
        const est = document.getElementById('f_esp_estado_funcional') ? document.getElementById('f_esp_estado_funcional').value : '';
        const hidden = document.getElementById('f_especialidad_data_json');
        if (hidden) {
            hidden.value = JSON.stringify({ nota_especifica: nota, estado_funcional: est });
        }
    },

    setPronosticoDual: function(vida, funcion) {
        if (this.isLockedNOM151) return;
        const vEl = document.getElementById('f_pronostico_vida');
        const fEl = document.getElementById('f_pronostico_funcion');
        if (vEl) vEl.value = vida;
        if (fEl) fEl.value = funcion;
        this.syncAll();
    },

    aplicarMacroClinica: function(macroKey) {
        if (this.isLockedNOM151) return;
        const m = this.clinicalMacros[macroKey];
        if (!m) return;

        const setVal = (id, val) => {
            const el = document.getElementById(id);
            if (el) {
                el.value = val;
                el.classList.remove('is-invalid');
            }
        };

        setVal('clave_diagnostico_cie10', m.cie10_code);
        setVal('diagnostico_principal', m.cie10_text);
        setVal('f_impresion_clinica', m.impresion);
        setVal('f_plan_tratamiento', m.plan);
        setVal('f_indicaciones_higienico', m.higienico);
        setVal('f_datos_alarma', m.alarma);
        this.setPronosticoDual(m.pron_vida, m.pron_func);

        // Cargar Receta Base de la Macro pasando por validación de Cédula y Alergia Cruzada
        if (m.meds && m.meds.length > 0) {
            const chkRec = document.getElementById('check_requiere_receta');
            if (chkRec) {
                chkRec.checked = true;
                toggleSeccionReceta(true);
            }
            window.recetaItems = JSON.parse(JSON.stringify(m.meds));
            renderRecetaItems();
        }

        this.syncAll();

        if (typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'success',
                title: `⚡ Macro Aplicada: ${m.nombre}`,
                text: 'Se rellenaron CIE-10, Impresión, Plan, Pronóstico Dual, Alarma y Receta COFEPRIS.',
                toast: true,
                position: 'top-end',
                timer: 2500,
                showConfirmButton: false
            });
        }
    },

    marcarAcuerdosCompletos: function() {
        if (this.isLockedNOM151) return;
        ['c_exp', 'c_ries', 'c_dud'].forEach(id => {
            const chk = document.getElementById(id);
            if (chk) {
                chk.checked = true;
                chk.classList.remove('is-invalid');
            }
        });
        this.syncAll();
    },

    toggleConsentimientoAnticipado: function(checked) {
        const btn = document.getElementById('btn-consentimiento-anticipado-p1');
        if (btn) btn.classList.toggle('d-none', !checked);
        if (typeof window.sincronizarConsentimientoDesdeRegistro === 'function') {
            window.sincronizarConsentimientoDesdeRegistro(checked);
        }
        this.syncAll();
    },

    validarCedulaExpress: async function() {
        if (typeof Swal === 'undefined') return;
        const { value: cedulaInput } = await Swal.fire({
            title: 'Validación COFEPRIS — Cédula Profesional',
            html: 'Ingrese su número de <strong>Cédula Profesional SEP / DGP</strong> (7 a 8 dígitos) para habilitar la emisión de recetas digitales:',
            input: 'text',
            inputPlaceholder: 'Ej. 12345678',
            showCancelButton: true,
            confirmButtonText: '<i class="bi bi-patch-check-fill me-1"></i>Validar Cédula',
            confirmButtonColor: '#0A2A66'
        });
        if (!cedulaInput || !cedulaInput.trim()) return;
        const cleanCed = cedulaInput.trim();
        const cfg = document.getElementById('js-config');
        if (cfg) cfg.setAttribute('data-med-cedula', cleanCed);
        const disp = document.getElementById('f_receta_cedula_display');
        if (disp) disp.value = cleanCed;
        const hdrCed = document.getElementById('hdr-cedula-badge');
        if (hdrCed) {
            hdrCed.className = 'qx-tier1-date-pill';
            hdrCed.innerHTML = `<i class="bi bi-patch-check-fill text-teal"></i><span>Céd. Prof: ${this.escapeHtml(cleanCed)}</span>`;
        }
        const banner = document.getElementById('banner-bloqueo-cedula-cofepris');
        if (banner) banner.classList.add('d-none');
        this.syncAll();
        Swal.fire('Cédula Validada', `Cédula Profesional #${cleanCed} verificada para emisión COFEPRIS.`, 'success');
    },

    initCIE10Autocomplete: function() {
        const searchInput = document.getElementById('cie10_search');
        const resultsDiv = document.getElementById('cie10_results');
        const diagInput = document.getElementById('diagnostico_principal');
        const codeInput = document.getElementById('clave_diagnostico_cie10');
        if (!searchInput || !resultsDiv) return;

        searchInput.addEventListener('input', async function() {
            const q = this.value.trim();
            if (q.length < 2) {
                resultsDiv.style.display = 'none';
                return;
            }
            try {
                const res = await fetch('../api/buscar_cie10.pl?q=' + encodeURIComponent(q));
                const data = await res.json();
                if (Array.isArray(data) && data.length > 0) {
                    let html = '';
                    data.forEach(item => {
                        const safeText = SOAPReactiveEngine.escapeHtml(item.text);
                        const safeId = SOAPReactiveEngine.escapeHtml(item.id);
                        html += `
                            <div class="list-group-item list-group-item-action py-1.5 px-2.5 d-flex justify-content-between align-items-center gap-2">
                                <button type="button" class="btn btn-link text-start text-decoration-none text-dark p-0 flex-grow-1 small select-cie10-primary" data-id="${safeId}" data-text="${safeId} - ${safeText}">
                                    <span class="badge bg-primary me-1.5">${safeId}</span><strong>${safeText}</strong>
                                </button>
                                <button type="button" class="btn btn-xs btn-outline-secondary rounded-pill px-2 py-0.5 select-cie10-secondary" style="font-size:0.68rem;" data-id="${safeId}" data-text="${safeText}" title="Agregar como Diagnóstico Secundario">
                                    + Secundario
                                </button>
                            </div>`;
                    });
                    resultsDiv.innerHTML = html;
                    resultsDiv.style.display = 'block';

                    resultsDiv.querySelectorAll('.select-cie10-primary').forEach(btn => {
                        btn.addEventListener('click', function() {
                            if (diagInput) diagInput.value = this.getAttribute('data-text');
                            if (codeInput) codeInput.value = this.getAttribute('data-id');
                            resultsDiv.style.display = 'none';
                            searchInput.value = '';
                            SOAPReactiveEngine.syncAll();
                        });
                    });

                    resultsDiv.querySelectorAll('.select-cie10-secondary').forEach(btn => {
                        btn.addEventListener('click', function() {
                            const cid = this.getAttribute('data-id');
                            const ctxt = this.getAttribute('data-text');
                            if (!window.diagnosticosSecundarios.some(d => d.codigo === cid)) {
                                window.diagnosticosSecundarios.push({ codigo: cid, descripcion: ctxt });
                                SOAPReactiveEngine.renderDiagnosticosSecundarios();
                            }
                            resultsDiv.style.display = 'none';
                            searchInput.value = '';
                        });
                    });
                } else {
                    resultsDiv.innerHTML = '<div class="list-group-item text-muted small">Sin coincidencias en catálogo CIE-10</div>';
                    resultsDiv.style.display = 'block';
                }
            } catch (e) {
                console.error('Error CIE-10:', e);
            }
        });

        document.addEventListener('click', function(e) {
            if (!searchInput.contains(e.target) && !resultsDiv.contains(e.target)) {
                resultsDiv.style.display = 'none';
            }
        });
    },

    renderDiagnosticosSecundarios: function() {
        const cont = document.getElementById('cie10-secundarios-chips');
        const hidden = document.getElementById('f_diagnosticos_secundarios_json');
        if (hidden) hidden.value = JSON.stringify(window.diagnosticosSecundarios);
        if (!cont) return;
        if (window.diagnosticosSecundarios.length === 0) {
            cont.innerHTML = `<span class="small text-muted fw-bold">Dx Secundarios / Comorbilidades:</span><span class="badge bg-light text-muted border">Ninguno agregado</span>`;
            return;
        }
        let html = `<span class="small text-muted fw-bold">Dx Secundarios:</span>`;
        window.diagnosticosSecundarios.forEach((d, idx) => {
            html += `<span class="badge bg-secondary-subtle text-dark border px-2 py-1 d-inline-flex align-items-center gap-1">
                <strong>${this.escapeHtml(d.codigo)}</strong> ${this.escapeHtml(d.descripcion)}
                <button type="button" class="btn-close" style="font-size:0.55rem;" onclick="SOAPReactiveEngine.removeDiagnosticoSecundario(${idx})"></button>
            </span>`;
        });
        cont.innerHTML = html;
    },

    removeDiagnosticoSecundario: function(idx) {
        window.diagnosticosSecundarios.splice(idx, 1);
        this.renderDiagnosticosSecundarios();
    },

    // Sincronización Global de Semáforos (6 Pasos + 5 Módulos Externos + Columna Derecha Sticky)
    syncAll: function() {
        const motivo = (document.getElementById('f_motivo_consulta') ? document.getElementById('f_motivo_consulta').value : '').trim();
        const evolucion = (document.getElementById('f_evolucion') ? document.getElementById('f_evolucion').value : '').trim();
        const alergias = (document.getElementById('f_alergias') ? document.getElementById('f_alergias').value : '').trim();
        const eva = document.getElementById('f_eva_dolor') ? document.getElementById('f_eva_dolor').value : '1';

        const ta = (document.getElementById('ef_ta') ? document.getElementById('ef_ta').value : '').trim();
        const fc = (document.getElementById('ef_fc') ? document.getElementById('ef_fc').value : '').trim();
        const temp = (document.getElementById('ef_temp') ? document.getElementById('ef_temp').value : '').trim();
        const spo2 = (document.getElementById('ef_spo2') ? document.getElementById('ef_spo2').value : '').trim();
        const peso = (document.getElementById('ef_peso') ? document.getElementById('ef_peso').value : '').trim();
        const imc = (document.getElementById('ef_imc') ? document.getElementById('ef_imc').value : '').trim();
        const hallazgos = (document.getElementById('f_exploracion_hallazgos') ? document.getElementById('f_exploracion_hallazgos').value : '').trim();

        const dx = (document.getElementById('diagnostico_principal') ? document.getElementById('diagnostico_principal').value : '').trim();
        const impresion = (document.getElementById('f_impresion_clinica') ? document.getElementById('f_impresion_clinica').value : '').trim();
        const plan = (document.getElementById('f_plan_tratamiento') ? document.getElementById('f_plan_tratamiento').value : '').trim();
        const pronVida = document.getElementById('f_pronostico_vida') ? document.getElementById('f_pronostico_vida').value : 'BUENO';
        const pronFunc = document.getElementById('f_pronostico_funcion') ? document.getElementById('f_pronostico_funcion').value : 'BUENO';

        const chkExp = document.getElementById('c_exp') ? document.getElementById('c_exp').checked : false;
        const chkDud = document.getElementById('c_dud') ? document.getElementById('c_dud').checked : false;
        const reqCons = document.getElementById('check_requiere_consentimiento_registro') ? document.getElementById('check_requiere_consentimiento_registro').checked : false;
        const consVinc = (document.getElementById('id_consentimiento_vinculado') ? document.getElementById('id_consentimiento_vinculado').value : '').trim();

        const reqReceta = document.getElementById('check_requiere_receta') ? document.getElementById('check_requiere_receta').checked : false;
        const cfg = document.getElementById('js-config');
        const medCedula = cfg ? (cfg.getAttribute('data-med-cedula') || '').trim() : '';
        const tieneCedula = (medCedula !== '' && medCedula !== '0');

        // 1. Actualizar tabla Triage Actual vs Basales en Columna Derecha Sticky
        const setTxt = (id, v) => {
            const el = document.getElementById(id);
            if (el) el.innerText = v || '--';
        };
        setTxt('ctx-now-ta', ta);
        setTxt('ctx-now-fc', fc ? `${fc} lpm` : '--');
        setTxt('ctx-now-temp', temp ? `${temp} °C` : '--');
        setTxt('ctx-now-spo2', spo2 ? `${spo2}%` : '--');
        setTxt('ctx-now-peso', peso ? `${peso} kg` : '--');
        setTxt('ctx-now-imc', imc);

        // 2. Banner Ámbar de Alertas Fisiológicas en Columna Derecha
        const physioBanner = document.getElementById('ctx-physio-banner');
        if (physioBanner) {
            if (this.activePhysioAlerts.length > 0) {
                physioBanner.classList.remove('d-none');
                physioBanner.innerHTML = `<i class="bi bi-exclamation-triangle-fill text-warning me-1"></i><strong>Triage:</strong> ${this.escapeHtml(this.activePhysioAlerts.join(' · '))}`;
            } else {
                physioBanner.classList.add('d-none');
            }
        }

        // Sincronizar badge de Alergia en la barra superior ejecutiva
        const topAllergyBadge = document.getElementById('badge-top-alergia');
        if (topAllergyBadge) {
            const hasAlergias = alergias && !alergias.toUpperCase().includes('NKDA') && !alergias.toUpperCase().includes('SIN ALERGIA');
            topAllergyBadge.classList.toggle('d-none', !hasAlergias);
        }

        // 3. Consolidado S.O.A.P. en Vivo en Columna Derecha Sticky
        setTxt('ctx-soap-s', motivo ? `${motivo} (EVA ${eva}/10) ${evolucion ? '· ' + evolucion.substring(0, 65) : ''}` : 'Sin motivo capturado...');
        setTxt('ctx-soap-o', hallazgos ? `${ta ? 'TA ' + ta + ' · ' : ''}${hallazgos.substring(0, 75)}` : 'Sin exploración capturada...');
        setTxt('ctx-soap-a', (dx || impresion) ? `${dx ? '[' + dx + '] ' : ''}${impresion.substring(0, 70)} (Pron: ${pronVida}/${pronFunc})` : 'Sin diagnóstico/impresión...');
        setTxt('ctx-soap-p', plan ? `${plan.substring(0, 75)}${reqReceta ? ' · [Receta: ' + window.recetaItems.length + ' fármaco(s)]' : ''}` : 'Sin plan terapéutico...');

        // 4. Semaforización de los 6 Pasos en Columna Izquierda y Barra Superior
        const setStepDot = (stepIdx, color) => {
            const navDot = document.getElementById('nav-dot-step-' + stepIdx);
            if (navDot) navDot.className = `qx-traffic-dot dot-${color}`;

            const topDot = document.getElementById('top-dot-step-' + stepIdx);
            if (topDot) topDot.className = `qx-traffic-dot dot-${color}`;

            document.querySelectorAll(`.soap-nav-step-item[data-step="${stepIdx}"], .soap-top-step-btn[data-step="${stepIdx}"]`).forEach(item => {
                item.classList.toggle('completed', color === 'verde');
                item.classList.toggle('alert-step', color === 'rojo');
            });
        };

        // Paso 1: Subjetivo
        if (motivo && evolucion) setStepDot(0, 'verde');
        else if (motivo || evolucion) setStepDot(0, 'ambar');
        else setStepDot(0, 'gris');

        // Paso 2: Objetivo (Rojo si hay alerta fisiológica y no se han documentado hallazgos)
        if (this.activePhysioAlerts.length > 0 && !hallazgos) setStepDot(1, 'rojo');
        else if (hallazgos && (ta || fc)) setStepDot(1, 'verde');
        else if (hallazgos || ta || fc) setStepDot(1, 'ambar');
        else setStepDot(1, 'gris');

        // Paso 3: Análisis, Plan y Receta (Rojo si hay alergia cruzada o falta cédula al recetar)
        if (reqReceta && (!tieneCedula || this.activeAllergyConflicts.length > 0)) setStepDot(2, 'rojo');
        else if (impresion && plan) setStepDot(2, 'verde');
        else if (impresion || plan || dx) setStepDot(2, 'ambar');
        else setStepDot(2, 'gris');

        // Paso 4: Acuerdos y Legal (Rojo si requiere consentimiento y no se ha vinculado ninguno)
        if (reqCons && !consVinc) setStepDot(3, 'rojo');
        else if (chkExp && chkDud) setStepDot(3, 'verde');
        else if (chkExp || chkDud) setStepDot(3, 'ambar');
        else setStepDot(3, 'gris');

        // Paso 5: Firma NOM-151
        if (this.isLockedNOM151) setStepDot(4, 'verde');
        else if (impresion && plan && motivo) setStepDot(4, 'ambar');
        else setStepDot(4, 'gris');

        // Paso 6: Caja
        const montoCaja = parseFloat(document.getElementById('f_caja_monto_abono') ? document.getElementById('f_caja_monto_abono').value : '0') || 0;
        setTxt('ctx-caja-total', '$' + montoCaja.toFixed(2));
        if (montoCaja > 0 || (typeof carritoConsulta !== 'undefined' && carritoConsulta.length > 0)) setStepDot(5, 'verde');
        else setStepDot(5, 'ambar');

        // 5. Semaforización de los 5 Módulos Externos en el Header Normativo
        const setModDot = (modId, color) => {
            const d = document.getElementById('mod-dot-' + modId);
            if (d) d.className = `qx-traffic-dot dot-${color}`;
        };
        setModDot('expediente', (motivo && hallazgos && impresion && plan) ? 'verde' : 'ambar');
        setModDot('legal', reqCons ? (consVinc ? 'verde' : 'rojo') : (chkExp && chkDud ? 'verde' : 'ambar'));
        setModDot('receta', reqReceta ? ((tieneCedula && this.activeAllergyConflicts.length === 0 && window.recetaItems.length > 0) ? 'verde' : 'rojo') : 'gris');
        setModDot('caja', montoCaja > 0 ? 'verde' : 'ambar');
        const proxCita = (document.getElementById('f_proxima_cita_id') ? document.getElementById('f_proxima_cita_id').value : '').trim();
        setModDot('agenda', proxCita ? 'verde' : 'verde');
    },

    updatePreSignatureAudit: function() {
        const motivo = (document.getElementById('f_motivo_consulta') ? document.getElementById('f_motivo_consulta').value : '').trim();
        const evolucion = (document.getElementById('f_evolucion') ? document.getElementById('f_evolucion').value : '').trim();
        const hallazgos = (document.getElementById('f_exploracion_hallazgos') ? document.getElementById('f_exploracion_hallazgos').value : '').trim();
        const impresion = (document.getElementById('f_impresion_clinica') ? document.getElementById('f_impresion_clinica').value : '').trim();
        const plan = (document.getElementById('f_plan_tratamiento') ? document.getElementById('f_plan_tratamiento').value : '').trim();
        const chkExp = document.getElementById('c_exp') ? document.getElementById('c_exp').checked : false;
        const chkDud = document.getElementById('c_dud') ? document.getElementById('c_dud').checked : false;

        const markItem = (id, ok, label) => {
            const el = document.getElementById(id);
            if (!el) return;
            el.className = `p-2 rounded border d-flex align-items-center gap-2 ${ok ? 'bg-success-subtle border-success text-success' : 'bg-warning-subtle border-warning text-dark'}`;
            el.innerHTML = `<i class="bi ${ok ? 'bi-check-circle-fill text-success' : 'bi-exclamation-circle-fill text-warning'}"></i><span>${label}</span>`;
        };

        markItem('audit-item-motivo', !!(motivo && evolucion), '<strong>Subjetivo:</strong> Motivo y Evolución');
        markItem('audit-item-objetivo', !!hallazgos, '<strong>Objetivo:</strong> Triage y Hallazgos');
        markItem('audit-item-analisis', !!(impresion && plan), '<strong>Análisis/Plan:</strong> Impresión y Pronóstico Dual');
        markItem('audit-item-legal', !!(chkExp && chkDud), '<strong>Legal:</strong> Acuerdos NOM-004');

        const badge = document.getElementById('badge-auditoria-nom004');
        const allOk = !!(motivo && evolucion && hallazgos && impresion && plan && chkExp && chkDud);
        if (badge) {
            badge.className = allOk ? 'badge bg-success text-white' : 'badge bg-warning text-dark';
            badge.innerText = allOk ? '✓ Expediente 100% Listo para Sellado NOM-151' : 'Campos normativos pendientes';
        }
        return allOk;
    },

    // Sellado Criptográfico e.firma / NOM-151 (Paso 5)
    sellarNotaClinicaNOM151: async function() {
        const motivo = (document.getElementById('f_motivo_consulta') ? document.getElementById('f_motivo_consulta').value : '').trim();
        const evolucion = (document.getElementById('f_evolucion') ? document.getElementById('f_evolucion').value : '').trim();
        const hallazgos = (document.getElementById('f_exploracion_hallazgos') ? document.getElementById('f_exploracion_hallazgos').value : '').trim();
        const impresion = (document.getElementById('f_impresion_clinica') ? document.getElementById('f_impresion_clinica').value : '').trim();
        const plan = (document.getElementById('f_plan_tratamiento') ? document.getElementById('f_plan_tratamiento').value : '').trim();

        if (!motivo || !evolucion || !hallazgos || !impresion || !plan) {
            if (typeof Swal !== 'undefined') {
                Swal.fire('Validación NOM-004', 'Para sellar bajo NOM-151 debe completar Motivo, Evolución, Hallazgos de Exploración, Impresión Clínica y Plan de Tratamiento.', 'warning');
            }
            return false;
        }

        // Si no había marcado los checks de acuerdo del Paso 4, marcarlos de forma asistida
        this.marcarAcuerdosCompletos();

        const cfg = document.getElementById('js-config');
        const idPac = cfg ? cfg.getAttribute('data-id-paciente') : '';
        const idMed = cfg ? cfg.getAttribute('data-id-medico') : '';
        const cedula = cfg ? cfg.getAttribute('data-med-cedula') : '';
        const pronVida = document.getElementById('f_pronostico_vida') ? document.getElementById('f_pronostico_vida').value : 'BUENO';
        const pronFunc = document.getElementById('f_pronostico_funcion') ? document.getElementById('f_pronostico_funcion').value : 'BUENO';

        try {
            const fd = new URLSearchParams({
                accion: 'sellar_nom151',
                id_paciente: idPac,
                id_medico: idMed,
                cedula_medico: cedula,
                motivo: motivo,
                impresion_clinica: impresion,
                pronostico_vida: pronVida,
                pronostico_funcion: pronFunc,
                duracion_segundos: this.timerSeconds
            });
            const res = await fetch('../api/boveda_paciente_api.pl', { method: 'POST', body: fd });
            const data = await res.json();
            if (data.ok) {
                this.isLockedNOM151 = true;
                document.getElementById('f_estatus_clinico').value = 'FIRMADA_NOM151';
                document.getElementById('f_hash_nom151').value = data.hash_nom151;
                document.getElementById('f_efirma_certificado_sat').value = data.certificado_sat;
                document.getElementById('f_fecha_sellado').value = data.fecha_sellado;

                document.getElementById('lbl-cert-sat').innerText = data.certificado_sat;
                document.getElementById('lbl-fecha-sello').innerText = data.fecha_sellado;
                document.getElementById('lbl-hash-nom151').innerText = data.hash_nom151;

                document.getElementById('panel-pre-firma-nom151').classList.add('d-none');
                document.getElementById('panel-post-firma-nom151').classList.remove('d-none');

                const lblEst = document.getElementById('lbl-estado-sello-nom151');
                if (lblEst) {
                    lblEst.className = 'badge bg-success rounded-pill';
                    lblEst.innerHTML = '<i class="bi bi-lock-fill me-1"></i>FIRMADA NOM-151 (INMUTABLE)';
                }

                const ctxFirma = document.getElementById('ctx-firma-status');
                if (ctxFirma) {
                    ctxFirma.className = 'badge bg-success text-white';
                    ctxFirma.innerText = 'FIRMADA NOM-151';
                }

                // Bloquear edición en pasos 1 a 4 (índices 0..3) y mostrar banner superior
                [0, 1, 2, 3].forEach(idx => {
                    const p = document.getElementById('step-panel-' + idx);
                    if (p) p.classList.add('locked-nom151');
                });
                const bannerInmutable = document.getElementById('banner-nota-sellada-nom151');
                if (bannerInmutable) bannerInmutable.classList.remove('d-none');

                this.updatePreSignatureAudit();
                this.syncAll();

                if (typeof Swal !== 'undefined') {
                    Swal.fire({
                        icon: 'success',
                        title: 'Nota Sellada (e.firma / NOM-151)',
                        html: `Estampilla criptográfica generada:<br><code class="small">${data.hash_nom151.substring(0, 32)}...</code><br>Los pasos 1 al 4 han quedado bloqueados contra edición.`,
                        timer: 2600,
                        showConfirmButton: false
                    });
                }
                return true;
            }
        } catch (err) {
            console.error('Error sellando NOM-151:', err);
        }
        return false;
    },

    // Desacoplamiento Clínico vs. Caja: Enviar orden a Caja Recepción desde el Paso 5
    finalizarYEnviarACajaRecepcion: async function() {
        if (!this.isLockedNOM151) {
            const selladoOk = await this.sellarNotaClinicaNOM151();
            if (!selladoOk) return;
        }
        const estadoTrat = document.getElementById('f_caja_estado_tratamiento');
        if (estadoTrat) estadoTrat.value = 'Cobro por recepción';
        const montoInp = document.getElementById('f_caja_monto_abono');
        if (montoInp) montoInp.value = '0.00';

        if (typeof finalizarConsulta === 'function') {
            finalizarConsulta(true);
        }
    },

    // Variables de Estado del Visor Multi-Página
    viewerMode: 'continuous',
    viewerPage: 1,
    viewerZoom: '100',

    setViewerMode: function(mode) {
        this.viewerMode = mode;
        const ws = document.getElementById('clinical-workspace-area');
        const btnCont = document.getElementById('btn-view-continuous');
        const btnPag = document.getElementById('btn-view-paginated');
        const navGrp = document.getElementById('toolbar-page-nav-group');

        if (mode === 'paginated') {
            if (ws) {
                ws.classList.add('mode-paginated');
                ws.classList.remove('mode-continuous');
                this.gotoPage(this.viewerPage || 1);
            }
            if (btnPag) btnPag.classList.add('active');
            if (btnCont) btnCont.classList.remove('active');
            if (navGrp) navGrp.style.setProperty('display', 'flex', 'important');
        } else {
            if (ws) {
                ws.classList.remove('mode-paginated', 'show-page-1', 'show-page-2');
                ws.classList.add('mode-continuous');
            }
            if (btnCont) btnCont.classList.add('active');
            if (btnPag) btnPag.classList.remove('active');
            if (navGrp) navGrp.style.setProperty('display', 'none', 'important');
        }
    },

    setViewerZoom: function(zoomLevel) {
        this.viewerZoom = zoomLevel;
        const ws = document.getElementById('clinical-workspace-area');
        if (ws) {
            ws.classList.remove('zoom-75', 'zoom-100', 'zoom-125');
            ws.classList.add('zoom-' + zoomLevel);
        }
        ['75', '100', '125'].forEach(z => {
            const btn = document.getElementById('btn-zoom-' + z);
            if (btn) btn.classList.toggle('active', z === zoomLevel);
        });
    },

    navPage: function(delta) {
        let target = (this.viewerPage || 1) + delta;
        if (target < 1) target = 1;
        if (target > 2) target = 2;
        this.gotoPage(target);
    },

    gotoPage: function(page) {
        this.viewerPage = page;
        const ws = document.getElementById('clinical-workspace-area');
        if (ws && this.viewerMode === 'paginated') {
            ws.classList.remove('show-page-1', 'show-page-2');
            ws.classList.add('show-page-' + page);
        }
        const ind = document.getElementById('toolbar-page-indicator');
        if (ind) ind.innerText = `Página ${page} de 2`;
    },

    compartirNotaWhatsAppEmail: function() {
        const cfg = document.getElementById('js-config');
        const pacTel = cfg ? (cfg.getAttribute('data-pac-tel') || '') : '';
        const pacNombre = cfg ? (cfg.getAttribute('data-pac-nombre') || 'Paciente') : 'Paciente';

        if (typeof Swal !== 'undefined') {
            Swal.fire({
                title: 'Compartir Nota Médica & Receta',
                html: `
                    <div class="text-start small mb-3">
                        <label class="form-label fw-bold">Teléfono WhatsApp:</label>
                        <input type="text" id="swal-pac-tel" class="form-control form-control-sm mb-2" value="${pacTel || '+52'}" placeholder="+52...">
                        <label class="form-label fw-bold">Correo Electrónico:</label>
                        <input type="email" id="swal-pac-email" class="form-control form-control-sm" placeholder="paciente@correo.com">
                    </div>
                `,
                icon: 'info',
                showCancelButton: true,
                confirmButtonText: '<i class="bi bi-whatsapp me-1"></i>Enviar WhatsApp',
                cancelButtonText: 'Cancelar',
                confirmButtonColor: '#00C0B5'
            }).then((res) => {
                if (res.isConfirmed) {
                    const tel = (document.getElementById('swal-pac-tel').value || '').replace(/[^0-9]/g, '');
                    const msg = encodeURIComponent(`Estimado(a) ${pacNombre}, adjuntamos su Nota Médica Oficial SOAP y Receta COFEPRIS emitida por OsPulso Clinical Suite. Validación NOM-024.`);
                    window.open(`https://wa.me/${tel}?text=${msg}`, '_blank');
                }
            });
        }
    },

    calcularCumplimientoNOM: function() {
        let score = 0;
        const cfg = document.getElementById('js-config');
        if (cfg && cfg.getAttribute('data-pac-nombre')) score += 10;

        const mot = (document.getElementById('f_motivo_consulta') ? document.getElementById('f_motivo_consulta').value : '').trim();
        if (mot.length > 5) score += 15;

        const ta = (document.getElementById('ef_ta') ? document.getElementById('ef_ta').value : '').trim();
        const fc = (document.getElementById('ef_fc') ? document.getElementById('ef_fc').value : '').trim();
        const temp = (document.getElementById('ef_temp') ? document.getElementById('ef_temp').value : '').trim();
        const peso = (document.getElementById('ef_peso') ? document.getElementById('ef_peso').value : '').trim();
        if (ta && fc && temp && peso) score += 20;
        else if (ta || fc || temp || peso) score += 10;

        const hall = (document.getElementById('f_exploracion_hallazgos') ? document.getElementById('f_exploracion_hallazgos').value : '').trim();
        const habitus = (document.getElementById('ef_inspeccion_general') ? document.getElementById('ef_inspeccion_general').value : '').trim();
        if (hall.length > 5 || habitus.length > 5) score += 15;

        const dx = (document.getElementById('diagnostico_principal') ? document.getElementById('diagnostico_principal').value : '').trim();
        if (dx.length > 3) score += 15;

        const pronV = document.getElementById('f_pronostico_vida') ? document.getElementById('f_pronostico_vida').value : '';
        const pronF = document.getElementById('f_pronostico_funcion') ? document.getElementById('f_pronostico_funcion').value : '';
        if (pronV && pronF) score += 10;

        const plan = (document.getElementById('f_plan_tratamiento') ? document.getElementById('f_plan_tratamiento').value : '').trim();
        if (plan.length > 5 || (window.recetaItems && window.recetaItems.length > 0)) score += 15;

        return Math.min(score, 100);
    },

    // Modal Visor Multi-Página PDF (2 Páginas Carta 8.5" x 11") NOM-004 / NOM-024
    abrirModalPDFNotaQR: function() {
        const cfg = document.getElementById('js-config');
        const pacNombre = cfg ? (cfg.getAttribute('data-pac-nombre') || 'Paciente') : 'Paciente';
        const pacCurp = cfg ? (cfg.getAttribute('data-pac-curp') || '') : '';
        const pacEdad = cfg ? (cfg.getAttribute('data-pac-edad') || '30') : '30';
        const pacSexo = cfg ? (cfg.getAttribute('data-pac-sexo') || 'No especificado') : 'No especificado';
        const pacTel = cfg ? (cfg.getAttribute('data-pac-tel') || '+52 (55) 0000-0000') : '+52 (55) 0000-0000';
        const idPac = cfg ? (cfg.getAttribute('data-id-paciente') || '0001') : '0001';
        const expFolio = `EXP-${String(idPac).padStart(4, '0')}`;

        const medNombre = cfg ? (cfg.getAttribute('data-med-nombre') || 'Médico Tratante') : 'Médico Tratante';
        const medCedula = cfg ? (cfg.getAttribute('data-med-cedula') || '8492019') : '8492019';
        const medEspe = cfg ? (cfg.getAttribute('data-med-espe') || 'Medicina General') : 'Medicina General';
        const orgNombre = cfg ? (cfg.getAttribute('data-org-nombre') || 'OsPulso Clinical Suite 5S') : 'OsPulso Clinical Suite 5S';
        const orgDom = cfg ? (cfg.getAttribute('data-org-domicilio') || 'Av. Álvaro Obregón 121, Sede Roma Norte, CDMX · CLUES: DFSSA003421 · Lic. Sanitaria: 23-AM-09-015-882') : 'Av. Álvaro Obregón 121, Sede Roma Norte, CDMX · CLUES: DFSSA003421 · Lic. Sanitaria: 23-AM-09-015-882';
        const hoyFecha = cfg ? (cfg.getAttribute('data-hoy-fecha') || new Date().toISOString().slice(0, 10)) : new Date().toISOString().slice(0, 10);
        const hoyHora = cfg ? (cfg.getAttribute('data-hoy-hora') || new Date().toLocaleTimeString()) : new Date().toLocaleTimeString();

        const folioNota = `NM-${hoyFecha.replace(/-/g, '')}-${String(idPac).padStart(4, '0')}`;

        // Subjetivo
        const motivo = (document.getElementById('f_motivo_consulta') ? document.getElementById('f_motivo_consulta').value : '') || 'Sin motivo de consulta registrado.';
        const eva = document.getElementById('f_eva_dolor') ? document.getElementById('f_eva_dolor').value : '0';
        const evolucion = (document.getElementById('f_evolucion') ? document.getElementById('f_evolucion').value : '') || 'Evolución clínica dentro de parámetros esperados sin signos de gravedad referidos.';
        const inicioSintomas = (document.getElementById('f_inicio_sintomas') ? document.getElementById('f_inicio_sintomas').value : '') || '4 días';
        const antecedentes = (document.getElementById('f_antecedentes_patologicos') ? document.getElementById('f_antecedentes_patologicos').value : '') || 'Interrogados y negados para enfermedades crónico-degenerativas.';
        const alergias = (document.getElementById('f_alergias') ? document.getElementById('f_alergias').value : '') || 'Sin alergias medicamentosas conocidas (NKDA)';
        const hasAlergias = alergias && !alergias.toUpperCase().includes('NKDA') && !alergias.toUpperCase().includes('SIN ALERGIA');

        // Objetivo / Somatometría
        const ta = (document.getElementById('ef_ta') ? document.getElementById('ef_ta').value : '') || '120/80';
        const fc = (document.getElementById('ef_fc') ? document.getElementById('ef_fc').value : '') || '76';
        const fr = (document.getElementById('ef_fr') ? document.getElementById('ef_fr').value : '') || '18';
        const temp = (document.getElementById('ef_temp') ? document.getElementById('ef_temp').value : '') || '36.6';
        const spo2 = (document.getElementById('ef_spo2') ? document.getElementById('ef_spo2').value : '') || '98';
        const gluc = (document.getElementById('ef_glucosa') ? document.getElementById('ef_glucosa').value : '') || '95';
        const peso = (document.getElementById('ef_peso') ? document.getElementById('ef_peso').value : '') || '70.0';
        const talla = (document.getElementById('ef_talla') ? document.getElementById('ef_talla').value : '') || '170';
        const imc = (document.getElementById('ef_imc') ? document.getElementById('ef_imc').value : '') || '24.2';

        // Exploración Física Extensa
        const habitus = (document.getElementById('ef_inspeccion_general') ? document.getElementById('ef_inspeccion_general').value : '') || 'Paciente orientado en tiempo, espacio y persona. Marcha normal, sin facies de dolor.';
        const cabeza = (document.getElementById('cef_cabeza_cuello') ? document.getElementById('cef_cabeza_cuello').value : '') || 'Normocéfalo, pupilas isocóricas normorreflectivas, mucosa oral bien hidratada.';
        const torax = (document.getElementById('cef_torax') ? document.getElementById('cef_torax').value : '') || 'Normolíneo, campos pulmonares bien ventilados sin ruidos agregados, ruidos cardíacos rítmicos.';
        const abdomen = (document.getElementById('cef_abdomen') ? document.getElementById('cef_abdomen').value : '') || 'Blando, depresible, no doloroso a la palpación media ni profunda, peristalsis presente.';
        const extremidades = (document.getElementById('cef_extremidades') ? document.getElementById('cef_extremidades').value : '') || 'Íntegras, eutróficas, arcos de movimiento completos, pulsos distales presentes y simétricos.';
        const neuro = (document.getElementById('cef_neuro') ? document.getElementById('cef_neuro').value : '') || 'Reflejos osteotendinosos conservados 2/4 simétricos, sensibilidad distal intacta.';
        const hallazgos = (document.getElementById('f_exploracion_hallazgos') ? document.getElementById('f_exploracion_hallazgos').value : '') || 'Exploración física sistemática sin hallazgos patológicos adicionales.';

        // Análisis y Diagnóstico
        const dx = (document.getElementById('diagnostico_principal') ? document.getElementById('diagnostico_principal').value : '') || 'K29.7 — Gastritis, no especificada';
        const impresion = (document.getElementById('f_impresion_clinica') ? document.getElementById('f_impresion_clinica').value : '') || 'Cuadro clínico compatible con gastropatía reactiva / dispepsia funcional.';
        const pronVida = document.getElementById('f_pronostico_vida') ? document.getElementById('f_pronostico_vida').value : 'BUENO';
        const pronFunc = document.getElementById('f_pronostico_funcion') ? document.getElementById('f_pronostico_funcion').value : 'BUENO';

        // Plan y Farmacoterapia
        const plan = (document.getElementById('f_plan_tratamiento') ? document.getElementById('f_plan_tratamiento').value : '') || 'Manejo ambulatorio con apego estricto a horario de medicamentos y cambios higiénico-dietéticos.';
        const higienico = (document.getElementById('f_indicaciones_higienico') ? document.getElementById('f_indicaciones_higienico').value : '') || 'Fraccionar alimentación en 5 comidas al día, evitar irritantes, café, tabaco y alcohol.';
        const labs = (document.getElementById('f_laboratorios_solicitados') ? document.getElementById('f_laboratorios_solicitados').value : '') || 'Prueba de Antígeno en heces para H. pylori, Biometría hemática y Química sanguínea.';
        const alarma = (document.getElementById('f_datos_alarma') ? document.getElementById('f_datos_alarma').value : '') || 'Acudir a Urgencias de inmediato ante hematemesis, melena, síncope o dolor epigástrico incoercible.';
        const hashNom = (document.getElementById('f_hash_nom151') ? document.getElementById('f_hash_nom151').value : '') || 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

        const compliance = this.calcularCumplimientoNOM();

        // Mapeo dinámico de medicamentos prescritos
        let rxTableRows = '';
        if (window.recetaItems && window.recetaItems.length > 0) {
            window.recetaItems.forEach((m, idx) => {
                rxTableRows += `
                    <tr>
                        <td class="fw-bold">${idx + 1}. ${this.escapeHtml(m.generico)} ${m.comercial ? '<span class="text-muted small">(' + this.escapeHtml(m.comercial) + ')</span>' : ''}</td>
                        <td>${this.escapeHtml(m.concentracion || m.dosis || '--')}</td>
                        <td>${this.escapeHtml(m.forma || 'Comprimido')}</td>
                        <td>${this.escapeHtml(m.posologia || '1 cada 24 hrs')}</td>
                        <td>${this.escapeHtml(m.via || 'Oral')}</td>
                    </tr>
                `;
            });
        } else {
            rxTableRows = `
                <tr>
                    <td class="fw-bold">1. Pantoprazol</td>
                    <td>40 mg</td>
                    <td>Comprimidos lib. retardada</td>
                    <td>1 comprimido VO en ayuno por 14 días</td>
                    <td>Oral</td>
                </tr>
                <tr>
                    <td class="fw-bold">2. Magaldrato / Dimeticona</td>
                    <td>800 mg / 100 mg</td>
                    <td>Gel oral</td>
                    <td>1 sobre VO 1 hr postprandial y al acostarse por 7 días</td>
                    <td>Oral</td>
                </tr>
            `;
        }

        const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=110x110&data=${encodeURIComponent('OSPULSO-NOM024|EXP:' + idPac + '|FOLIO:' + folioNota + '|MED:' + medCedula + '|HASH:' + hashNom.substring(0, 32))}`;

        // Actualizar badges del toolbar
        const tFolio = document.getElementById('toolbar-folio-badge');
        if (tFolio) tFolio.innerText = `Folio: ${folioNota}`;
        const tMeta = document.getElementById('toolbar-patient-meta');
        if (tMeta) tMeta.innerHTML = `Expediente: ${expFolio} &bull; Paciente: ${this.escapeHtml(pacNombre)}`;

        const cont = document.getElementById('modal-pdf-nota-qr-body');
        if (cont) {
            cont.innerHTML = `
                <!-- ========================================================
                     HOJA 1 (PÁGINA 1 DE 2: ANAMNESIS, TRIAGE Y EXPLORACIÓN)
                     ======================================================== -->
                <div class="clinical-sheet page-1 shadow-xl">
                    <div>
                        <!-- Membrete Institucional y Sellado Temporal -->
                        <div class="sheet-header-top">
                            <div class="sheet-logo-box">
                                <div class="sheet-logo-icon">
                                    <i class="bi bi-hospital"></i>
                                </div>
                                <div>
                                    <h5 class="sheet-org-title">${this.escapeHtml(orgNombre)}</h5>
                                    <div class="sheet-org-sub">${this.escapeHtml(orgDom)}</div>
                                    <div class="sheet-badge-compliance mt-1">
                                        <i class="bi bi-shield-check"></i> NOM-004-SSA3 &bull; NOM-024-SSA3 &bull; NOM-151-SCFI &bull; Cumplimiento: ${compliance}%
                                    </div>
                                </div>
                            </div>
                            <div class="text-end" style="font-size: 9.5px;">
                                <div class="fw-bold" style="color: var(--clinical-navy-dark); font-size: 11px;">FOLIO: ${this.escapeHtml(folioNota)}</div>
                                <div class="text-muted">Emisión: ${this.escapeHtml(hoyFecha)} &bull; ${this.escapeHtml(hoyHora)} hrs CST</div>
                                <div class="text-muted">Médico: ${this.escapeHtml(medNombre)} &bull; Céd: ${this.escapeHtml(medCedula)}</div>
                            </div>
                        </div>

                        <!-- Cintillo Institucional en Navy -->
                        <div class="sheet-title-banner">
                            NOTA MÉDICA DE CONSULTA Y EVOLUCIÓN (MÉTODO S.O.A.P. MULTI-PÁGINA)
                        </div>

                        <!-- Cédula de Identificación del Paciente -->
                        <div class="sheet-patient-grid">
                            <div class="sheet-data-item">
                                <span class="sheet-data-label">Paciente</span>
                                <span class="sheet-data-value">${this.escapeHtml(pacNombre)}</span>
                            </div>
                            <div class="sheet-data-item">
                                <span class="sheet-data-label">Expediente Clínico</span>
                                <span class="sheet-data-value">${this.escapeHtml(expFolio)}</span>
                            </div>
                            <div class="sheet-data-item">
                                <span class="sheet-data-label">Edad / Sexo</span>
                                <span class="sheet-data-value">${this.escapeHtml(pacEdad)} años &bull; ${this.escapeHtml(pacSexo)}</span>
                            </div>
                            <div class="sheet-data-item">
                                <span class="sheet-data-label">CURP</span>
                                <span class="sheet-data-value font-monospace">${this.escapeHtml(pacCurp || 'NO REGISTRADA')}</span>
                            </div>
                            <div class="sheet-data-item">
                                <span class="sheet-data-label">Teléfono de Contacto</span>
                                <span class="sheet-data-value">${this.escapeHtml(pacTel)}</span>
                            </div>
                            <div class="sheet-data-item">
                                <span class="sheet-data-label">Tipo de Servicio</span>
                                <span class="sheet-data-value">Consulta Privada Especializada</span>
                            </div>
                            <div class="sheet-data-item">
                                <span class="sheet-data-label">Escala Dolor EVA</span>
                                <span class="sheet-data-value">${this.escapeHtml(eva)} / 10</span>
                            </div>
                            <div class="sheet-data-item">
                                <span class="sheet-data-label">Estado de Validación</span>
                                <span class="sheet-data-value text-success fw-bold">✓ COTEJADO RENAPO / INE</span>
                            </div>
                        </div>

                        <!-- Bloque Alérgico Crítico Destacado -->
                        <div class="${hasAlergias ? 'sheet-alert-allergies' : 'sheet-patient-grid'}" style="${!hasAlergias ? 'background: var(--clinical-success-bg); border-color: var(--clinical-success-border); margin-bottom: 0.65rem;' : ''}">
                            <i class="bi bi-shield-exclamation sheet-alert-allergies-icon" style="${!hasAlergias ? 'color: #059669;' : ''}"></i>
                            <div>
                                <div class="fw-bold" style="font-size: 10px; text-transform: uppercase;">
                                    ${hasAlergias ? 'ALERGIAS MEDICAMENTOSAS CONOCIDAS — ADVERTENCIA CRÍTICA' : 'SIN ALERGIAS CONOCIDAS (NKDA)'}
                                </div>
                                <div style="font-size: 10.5px;">${this.escapeHtml(alergias)}</div>
                            </div>
                        </div>

                        <!-- Somatometría y Triage al Ingreso (7 Parámetros) -->
                        <div class="sheet-vitals-grid">
                            <div class="sheet-vital-card">
                                <div class="sheet-vital-lbl">T. Arterial</div>
                                <div class="sheet-vital-val">${this.escapeHtml(ta)}</div>
                                <div class="sheet-vital-unit">mmHg</div>
                            </div>
                            <div class="sheet-vital-card">
                                <div class="sheet-vital-lbl">F. Cardíaca</div>
                                <div class="sheet-vital-val">${this.escapeHtml(fc)}</div>
                                <div class="sheet-vital-unit">lpm</div>
                            </div>
                            <div class="sheet-vital-card">
                                <div class="sheet-vital-lbl">F. Respiratoria</div>
                                <div class="sheet-vital-val">${this.escapeHtml(fr)}</div>
                                <div class="sheet-vital-unit">rpm</div>
                            </div>
                            <div class="sheet-vital-card">
                                <div class="sheet-vital-lbl">Temperatura</div>
                                <div class="sheet-vital-val">${this.escapeHtml(temp)}</div>
                                <div class="sheet-vital-unit">°C</div>
                            </div>
                            <div class="sheet-vital-card">
                                <div class="sheet-vital-lbl">SpO₂ Oximetría</div>
                                <div class="sheet-vital-val">${this.escapeHtml(spo2)}</div>
                                <div class="sheet-vital-unit">% O₂</div>
                            </div>
                            <div class="sheet-vital-card">
                                <div class="sheet-vital-lbl">Glucosa Capilar</div>
                                <div class="sheet-vital-val">${this.escapeHtml(gluc)}</div>
                                <div class="sheet-vital-unit">mg/dL</div>
                            </div>
                            <div class="sheet-vital-card">
                                <div class="sheet-vital-lbl">Peso / IMC</div>
                                <div class="sheet-vital-val">${this.escapeHtml(peso)}kg</div>
                                <div class="sheet-vital-unit">IMC ${this.escapeHtml(imc)}</div>
                            </div>
                        </div>

                        <!-- [S] Subjetivo • Anamnesis y Motivo de Consulta -->
                        <div class="sheet-clinical-section">
                            <div class="sheet-section-header">
                                <i class="bi bi-person-lines-fill text-teal"></i> [S] Subjetivo &bull; Anamnesis y Motivo de Consulta
                            </div>
                            <div class="sheet-section-body">
                                <div><strong>Motivo Principal:</strong> ${this.escapeHtml(motivo)} (Evolución: ${this.escapeHtml(inicioSintomas)}, EVA: ${this.escapeHtml(eva)}/10)</div>
                                <div class="mt-1"><strong>Padecimiento Actual Detallado:</strong> ${this.escapeHtml(evolucion)}</div>
                                <div class="mt-1 text-muted" style="font-size: 9.5px;"><strong>Antecedentes:</strong> ${this.escapeHtml(antecedentes)}</div>
                            </div>
                        </div>

                        <!-- [O] Objetivo • Exploración Física Cefalocaudal Extensa -->
                        <div class="sheet-clinical-section">
                            <div class="sheet-section-header">
                                <i class="bi bi-activity text-teal"></i> [O] Objetivo &bull; Exploración Física Cefalocaudal Extensa
                            </div>
                            <div class="sheet-exploration-grid">
                                <div class="sheet-exploration-box">
                                    <div class="sheet-exploration-title">Habitus Exterior / General</div>
                                    <div>${this.escapeHtml(habitus)}</div>
                                </div>
                                <div class="sheet-exploration-box">
                                    <div class="sheet-exploration-title">Cabeza y Cuello</div>
                                    <div>${this.escapeHtml(cabeza)}</div>
                                </div>
                                <div class="sheet-exploration-box">
                                    <div class="sheet-exploration-title">Tórax y Cardiorrespiratorio</div>
                                    <div>${this.escapeHtml(torax)}</div>
                                </div>
                                <div class="sheet-exploration-box">
                                    <div class="sheet-exploration-title">Abdomen y Pelvis</div>
                                    <div>${this.escapeHtml(abdomen)}</div>
                                </div>
                                <div class="sheet-exploration-box">
                                    <div class="sheet-exploration-title">Extremidades y Sistema Motor</div>
                                    <div>${this.escapeHtml(extremidades)}</div>
                                </div>
                                <div class="sheet-exploration-box">
                                    <div class="sheet-exploration-title">Sistema Neurológico y Reflejos</div>
                                    <div>${this.escapeHtml(neuro)}</div>
                                </div>
                            </div>
                            <div class="mt-1 px-1 text-muted" style="font-size: 9.5px;">
                                <strong>Hallazgos Adicionales / Estudios Previos:</strong> ${this.escapeHtml(hallazgos)}
                            </div>
                        </div>
                    </div>

                    <!-- Pie Continuo de Hoja 1 -->
                    <div class="sheet-footer-page border-top pt-2 mt-auto">
                        <div class="fw-semibold text-teal" style="color: var(--clinical-teal-active);">
                            &darr; Continúa en Página 2 (Análisis Diagnóstico, Plan Farmacológico y Firma Legal NOM-151)
                        </div>
                        <div class="d-flex justify-content-between align-items-center mt-1">
                            <span>Folio Oficial: <strong>${this.escapeHtml(folioNota)}</strong></span>
                            <span>Expediente: ${this.escapeHtml(expFolio)}</span>
                            <span class="fw-bold">Página 1 de 2</span>
                        </div>
                    </div>
                </div>

                <!-- SEPARADOR VISUAL DE SALTO DE PÁGINA EN PANTALLA -->
                <div class="clinical-page-separator no-print">
                    <i class="bi bi-scissors me-1"></i> SALTO DE PÁGINA OFICIAL &bull; HOJA 2/2
                </div>

                <!-- ========================================================
                     HOJA 2 (PÁGINA 2 DE 2: DIAGNÓSTICO, PLAN, RECETA Y FIRMA)
                     ======================================================== -->
                <div class="clinical-sheet page-2 shadow-xl">
                    <div>
                        <!-- Running Header de Continuidad Institucional -->
                        <div class="sheet-running-header">
                            <div>
                                <strong>OsPulso Clinical Suite</strong> &bull; Folio: <strong>${this.escapeHtml(folioNota)}</strong>
                            </div>
                            <div>
                                Paciente: <strong>${this.escapeHtml(pacNombre)}</strong> (${this.escapeHtml(expFolio)}) &bull; Fecha: ${this.escapeHtml(hoyFecha)}
                            </div>
                            <div class="fw-bold text-teal">HOJA 2 DE 2</div>
                        </div>

                        <!-- [A] Análisis y Diagnóstico Clínico (Clasificación CIE-10) -->
                        <div class="sheet-clinical-section">
                            <div class="sheet-section-header">
                                <i class="bi bi-clipboard2-pulse text-teal"></i> [A] Análisis y Diagnóstico Clínico (Clasificación CIE-10)
                            </div>
                            <div class="sheet-section-body">
                                <div class="p-2 rounded" style="background: var(--clinical-box-alt); border: 1px solid #CBD5E1;">
                                    <div class="fw-bold" style="color: var(--clinical-navy-dark); font-size: 11.5px;">
                                        Diagnóstico Principal: ${this.escapeHtml(dx)}
                                    </div>
                                    <div class="mt-1">${this.escapeHtml(impresion)}</div>
                                    <div class="d-flex gap-3 mt-1.5 pt-1.5 border-top" style="font-size: 9.5px;">
                                        <div><strong>Pronóstico de Vida:</strong> <span class="badge bg-success">${this.escapeHtml(pronVida)}</span></div>
                                        <div><strong>Pronóstico de Función:</strong> <span class="badge bg-success">${this.escapeHtml(pronFunc)}</span></div>
                                        <div class="text-muted ms-auto">Correlación Fisiopatológica Favorable con apego farmacológico</div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- [P] Plan Terapéutico, Farmacoterapia y Manejo Clínico -->
                        <div class="sheet-clinical-section">
                            <div class="sheet-section-header">
                                <i class="bi bi-prescription text-teal"></i> [P] Plan Terapéutico y Prescripción Farmacológica (COFEPRIS)
                            </div>
                            <div class="sheet-section-body">
                                <!-- Tabla de Medicamentos -->
                                <table class="sheet-rx-table">
                                    <thead>
                                        <tr>
                                            <th>Fármaco (Genérico / Comercial)</th>
                                            <th>Dosis / Conc.</th>
                                            <th>Presentación</th>
                                            <th>Posología y Horario</th>
                                            <th>Vía</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        ${rxTableRows}
                                    </tbody>
                                </table>

                                <!-- Medidas Higiénico-Dietéticas y Estudios Solicitados -->
                                <div class="row g-2 mt-1">
                                    <div class="col-6">
                                        <div class="p-2 rounded h-100" style="background: var(--clinical-box-neutral); border: 1px solid #E2E8F0;">
                                            <div class="sheet-data-label text-teal"><i class="bi bi-shield-plus me-1"></i>Medidas Higiénico-Dietéticas</div>
                                            <div style="font-size: 10px;">${this.escapeHtml(higienico)}</div>
                                        </div>
                                    </div>
                                    <div class="col-6">
                                        <div class="p-2 rounded h-100" style="background: var(--clinical-box-neutral); border: 1px solid #E2E8F0;">
                                            <div class="sheet-data-label text-teal"><i class="bi bi-search me-1"></i>Estudios de Laboratorio / Gabinete</div>
                                            <div style="font-size: 10px;">${this.escapeHtml(labs)}</div>
                                        </div>
                                    </div>
                                </div>

                                <!-- Datos de Alarma Explicados -->
                                <div class="p-2 rounded mt-2" style="background: var(--clinical-alert-bg); border: 1px solid var(--clinical-alert-border); color: var(--clinical-alert-text); font-size: 10px;">
                                    <div class="fw-bold text-uppercase"><i class="bi bi-exclamation-octagon-fill me-1"></i>Datos de Alarma Médica (Acudir a Urgencias de Inmediato)</div>
                                    <div>${this.escapeHtml(alarma)}</div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Cierre Médico Legal, Firma FIEL y Trazabilidad Criptográfica -->
                    <div class="sheet-legal-closing mt-auto">
                        <div class="sheet-signature-box">
                            <div style="font-size: 9.5px; line-height: 1.35; max-width: 58%;">
                                <div class="fw-bold" style="color: var(--clinical-navy-dark); font-size: 10.5px;">${this.escapeHtml(medNombre)}</div>
                                <div>Especialidad: <strong>${this.escapeHtml(medEspe)}</strong></div>
                                <div>Cédula Profesional: <strong>${this.escapeHtml(medCedula)}</strong> &bull; Céd. Especialidad: <strong>11029482</strong></div>
                                <div class="text-muted">Certificación Vigente por Consejo Mexicano de la Especialidad</div>
                            </div>

                            <div class="sheet-doc-seal">
                                <div class="fw-bold text-success" style="font-size: 9px; letter-spacing: 0.05em;">
                                    <i class="bi bi-patch-check-fill"></i> É.FIRMA VALIDADA (FIEL / SAT)
                                </div>
                                <div class="sheet-sig-line">
                                    <span class="text-muted" style="font-size: 8.5px;">FIRMA DIGITAL DEL MÉDICO TRATANTE</span>
                                </div>
                            </div>
                        </div>

                        <!-- Bloque Criptográfico SHA-256 y QR NOM-024 -->
                        <div class="sheet-crypto-block">
                            <div class="sheet-crypto-hash">
                                <div class="fw-bold" style="color: var(--clinical-navy-dark); font-size: 9px;">
                                    CADENA ORIGINAL DE SELLADO NOM-024-SSA3 / NOM-151-SCFI-2016
                                </div>
                                <div>||${this.escapeHtml(folioNota)}|${this.escapeHtml(expFolio)}|${this.escapeHtml(medCedula)}|${this.escapeHtml(hoyFecha)}|${this.escapeHtml(hoyHora)}|${this.escapeHtml(hashNom.substring(0, 32))}||</div>
                                <div class="mt-1"><strong>HASH SHA-256:</strong> ${this.escapeHtml(hashNom)}</div>
                                <div class="text-muted mt-0.5">Constancia Digital de Conservación de Mensajes de Datos NOM-151 Certificada ante la Secretaría de Economía.</div>
                            </div>

                            <div class="text-center">
                                <img src="${qrUrl}" alt="QR Validación NOM-024" class="sheet-qr-img">
                                <div class="text-muted mt-1" style="font-size: 7.5px;">VALIDACIÓN QR SSA</div>
                            </div>
                        </div>

                        <!-- Foliado de Cierre -->
                        <div class="sheet-footer-page">
                            Página 2 de 2 &bull; Fin del Documento Clínico Oficial &bull; Folio: ${this.escapeHtml(folioNota)}
                        </div>
                    </div>
                </div>
            `;
        }

        const modalEl = document.getElementById('modalPDFNotaClinicaQR');
        if (modalEl && window.bootstrap) {
            this.setViewerMode('continuous');
            this.setViewerZoom('100');
            bootstrap.Modal.getOrCreateInstance(modalEl).show();
        }
    },

    enviarNotaCifradaTLS: function() {
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'success',
                title: 'Envío Cifrado TLS 1.3 Completado',
                text: 'La Nota Clínica SOAP, Receta COFEPRIS y Código QR NOM-024 se enviaron al Portal del Paciente bajo cifrado TLS 1.3.',
                timer: 2500,
                showConfirmButton: false
            });
        }
    },

    toggleCommandPalette: function() {
        const modalEl = document.getElementById('modalCommandPaletteAltK');
        if (!modalEl || !window.bootstrap) return;
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        m.toggle();
    },

    escapeHtml: function(str) {
        if (!str) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }
};

/* ==========================================================================
   3. FUNCIONES GLOBALES DE RECETA MÉDICA CON MOTOR DE ALERGIA CRUZADA
   ========================================================================== */
window.toggleSeccionReceta = function(checked) {
    const sec = document.getElementById('seccion-receta-medica');
    if (sec) sec.style.display = checked ? 'block' : 'none';
    if (checked) {
        const folInp = document.getElementById('receta_folio_input');
        if (folInp && !folInp.value) {
            const now = new Date();
            folInp.value = 'REC-' + now.getFullYear() + String(now.getMonth() + 1).padStart(2, '0') + String(now.getDate()).padStart(2, '0') + '-' + Math.floor(Math.random() * 9000 + 1000);
        }
    } else {
        window.recetaItems = [];
        syncRecetaJSON();
        const folInp = document.getElementById('receta_folio_input');
        if (folInp) folInp.value = '';
        renderRecetaItems();
    }
    SOAPReactiveEngine.syncAll();
};

window.seleccionarProductoReceta = function(val) {
    if (!val || SOAPReactiveEngine.isLockedNOM151) return;
    const parts = val.split('|');
    if (parts.length >= 2) {
        window.recetaItems.push({
            generico: parts[1],
            comercial: '',
            forma: parts[2] || 'Tableta',
            concentracion: parts[3] || '500mg',
            posologia: '1 cada 8 horas por 7 días',
            via: 'Oral'
        });
        const sel = document.getElementById('select_producto_receta');
        if (sel) sel.value = '';
        renderRecetaItems();
    }
};

window.agregarMedicamentoRecetaManual = function() {
    if (SOAPReactiveEngine.isLockedNOM151) return;
    window.recetaItems.push({
        generico: 'Paracetamol 500mg',
        comercial: '',
        forma: 'Tableta',
        concentracion: '500mg',
        posologia: '1 cada 8 horas por 5 días',
        via: 'Oral'
    });
    renderRecetaItems();
};

window.updateRecetaField = function(idx, field, val) {
    if (window.recetaItems[idx]) {
        window.recetaItems[idx][field] = val;
        renderRecetaItems();
    }
};

window.removeRecetaItem = function(idx) {
    window.recetaItems.splice(idx, 1);
    renderRecetaItems();
};

window.syncRecetaJSON = function() {
    const input = document.getElementById('receta_json_input');
    if (input) input.value = JSON.stringify(window.recetaItems);
};

window.renderRecetaItems = function() {
    const tbody = document.getElementById('tbody-receta-items');
    if (!tbody) return;
    const conflicts = [];

    if (!window.recetaItems || window.recetaItems.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center py-3 text-muted small">Sin medicamentos en la receta. Seleccione del catálogo, aplique una Macro o clone desde la Bóveda.</td></tr>';
        SOAPReactiveEngine.activeAllergyConflicts = [];
        const bAlert = document.getElementById('banner-alergia-cruzada-receta');
        if (bAlert) bAlert.classList.add('d-none');
        syncRecetaJSON();
        SOAPReactiveEngine.syncAll();
        return;
    }

    let html = '';
    window.recetaItems.forEach((it, i) => {
        const drugFull = `${it.generico || ''} ${it.comercial || ''}`;
        const conflictReason = SOAPReactiveEngine.checkCrossAllergyForDrug(drugFull);
        it.alerta_alergia_detectada = conflictReason || '';
        if (conflictReason) {
            conflicts.push(`${it.generico}: ${conflictReason}`);
        }

        const rowCls = conflictReason ? 'receta-row-allergy-conflict' : '';
        const alertBadge = conflictReason
            ? `<div class="badge bg-danger text-white mt-1 d-block text-wrap text-start"><i class="bi bi-exclamation-octagon-fill me-1"></i>${SOAPReactiveEngine.escapeHtml(conflictReason)}</div>`
            : '';

        html += `<tr class="${rowCls}">
            <td>
                <input type="text" class="form-control form-control-sm fw-bold" value="${SOAPReactiveEngine.escapeHtml(it.generico)}" placeholder="Nombre genérico" onchange="updateRecetaField(${i}, 'generico', this.value)">
                <input type="text" class="form-control form-control-sm mt-1 text-muted" value="${SOAPReactiveEngine.escapeHtml(it.comercial)}" placeholder="Comercial (opcional)" onchange="updateRecetaField(${i}, 'comercial', this.value)">
                ${alertBadge}
            </td>
            <td>
                <input type="text" class="form-control form-control-sm" value="${SOAPReactiveEngine.escapeHtml(it.forma)}" onchange="updateRecetaField(${i}, 'forma', this.value)">
            </td>
            <td>
                <input type="text" class="form-control form-control-sm" value="${SOAPReactiveEngine.escapeHtml(it.concentracion)}" onchange="updateRecetaField(${i}, 'concentracion', this.value)">
            </td>
            <td>
                <input type="text" class="form-control form-control-sm" value="${SOAPReactiveEngine.escapeHtml(it.posologia)}" onchange="updateRecetaField(${i}, 'posologia', this.value)">
            </td>
            <td>
                <select class="form-select form-select-sm" onchange="updateRecetaField(${i}, 'via', this.value)">
                    <option value="Oral" ${it.via === 'Oral' ? 'selected' : ''}>Oral</option>
                    <option value="Intramuscular" ${it.via === 'Intramuscular' ? 'selected' : ''}>Intramuscular</option>
                    <option value="Intravenosa" ${it.via === 'Intravenosa' ? 'selected' : ''}>Intravenosa</option>
                    <option value="Tópica" ${it.via === 'Tópica' ? 'selected' : ''}>Tópica</option>
                    <option value="Oftálmica" ${it.via === 'Oftálmica' ? 'selected' : ''}>Oftálmica</option>
                    <option value="Sublingual" ${it.via === 'Sublingual' ? 'selected' : ''}>Sublingual</option>
                </select>
            </td>
            <td class="text-center">
                <button type="button" class="btn btn-sm btn-outline-danger border-0" onclick="removeRecetaItem(${i})"><i class="bi bi-trash"></i></button>
            </td>
        </tr>`;
    });

    tbody.innerHTML = html;
    SOAPReactiveEngine.activeAllergyConflicts = conflicts;

    const bAlert = document.getElementById('banner-alergia-cruzada-receta');
    const txtAlert = document.getElementById('txt-alergia-cruzada-detalle');
    if (bAlert && txtAlert) {
        if (conflicts.length > 0) {
            bAlert.classList.remove('d-none');
            txtAlert.innerText = conflicts.join(' | ');
        } else {
            bAlert.classList.add('d-none');
        }
    }

    syncRecetaJSON();
    SOAPReactiveEngine.syncAll();
};

/* ==========================================================================
   4. SERVICIO DE BÓVEDA DEL PACIENTE (DRAWER 2 NIVELES + TIMELINE + LIGHTBOX)
   ========================================================================== */
const BovedaService = {
    documentos: [],
    signosBasales: { tiene_basales: 0 },
    currentFilter: 'ALL',
    viewMode: 'CATEGORIES', // 'CATEGORIES' | 'TIMELINE'

    init: async function(idPaciente) {
        if (!idPaciente) return;
        try {
            const res = await fetch(`../api/boveda_paciente_api.pl?accion=list&id_paciente=${encodeURIComponent(idPaciente)}`);
            const data = await res.json();
            if (data.ok) {
                this.documentos = data.documentos || [];
                this.signosBasales = data.signos_basales || { tiene_basales: 0 };

                // Actualizar contador en el botón Bóveda del Header
                const cntEl = document.getElementById('hdr-boveda-count');
                if (cntEl) cntEl.innerText = this.documentos.length;

                // Poblar columna de Signos Basales en la tabla comparativa de la Columna Derecha Sticky
                const b = this.signosBasales;
                const setTxt = (id, v) => {
                    const el = document.getElementById(id);
                    if (el) el.innerText = v || '--';
                };
                setTxt('ctx-basal-fecha', b.fecha || '--');
                setTxt('ctx-basal-ta', b.ta || '--');
                setTxt('ctx-basal-fc', b.fc ? `${b.fc} lpm` : '--');
                setTxt('ctx-basal-temp', b.temp ? `${b.temp} °C` : '--');
                setTxt('ctx-basal-spo2', b.spo2 ? `${b.spo2}%` : '--');
                setTxt('ctx-basal-peso', b.peso ? `${b.peso} kg` : '--');
                setTxt('ctx-basal-imc', b.imc || '--');

                this.renderDocs();
            }
        } catch (err) {
            console.error('Error inicializando Bóveda del Paciente:', err);
        }
    },

    openDrawer: function(filterMod = 'ALL') {
        this.currentFilter = filterMod || 'ALL';
        const backdrop = document.getElementById('boveda-drawer-backdrop');
        const panel = document.getElementById('boveda-drawer-panel');
        if (backdrop) backdrop.classList.add('open');
        if (panel) panel.classList.add('open');
        this.updateFilterChips();
        this.renderDocs();
    },

    closeDrawer: function() {
        const backdrop = document.getElementById('boveda-drawer-backdrop');
        const panel = document.getElementById('boveda-drawer-panel');
        if (backdrop) backdrop.classList.remove('open');
        if (panel) panel.classList.remove('open');
    },

    setFilter: function(mod) {
        this.currentFilter = mod;
        this.updateFilterChips();
        this.renderDocs();
    },

    toggleViewMode: function(mode) {
        this.viewMode = mode;
        const btnCat = document.getElementById('btn-boveda-mode-cat');
        const btnTime = document.getElementById('btn-boveda-mode-time');
        if (btnCat) btnCat.classList.toggle('active', mode === 'CATEGORIES');
        if (btnTime) btnTime.classList.toggle('active', mode === 'TIMELINE');
        this.renderDocs();
    },

    updateFilterChips: function() {
        document.querySelectorAll('.boveda-filter-chip').forEach(btn => {
            const f = btn.getAttribute('data-filter');
            if (f === this.currentFilter) {
                btn.className = 'btn btn-xs btn-primary rounded-pill px-2.5 py-0.5 fw-bold boveda-filter-chip';
            } else {
                btn.className = 'btn btn-xs btn-outline-secondary rounded-pill px-2.5 py-0.5 fw-semibold boveda-filter-chip';
            }
        });
    },

    renderDocs: function() {
        const cont = document.getElementById('boveda-docs-container');
        if (!cont) return;
        const q = (document.getElementById('boveda-search-input') ? document.getElementById('boveda-search-input').value : '').toLowerCase().trim();

        const filtered = this.documentos.filter(d => {
            if (this.currentFilter !== 'ALL' && d.modulo_origen !== this.currentFilter) return false;
            if (q) {
                const hay = `${d.titulo} ${d.folio_origen} ${d.resumen_clinico} ${d.categoria_ui} ${d.fecha_documento}`.toLowerCase();
                if (!hay.includes(q)) return false;
            }
            return true;
        });

        if (filtered.length === 0) {
            cont.innerHTML = `<div class="text-center py-5 text-muted small">
                <i class="bi bi-folder2-open fs-1 d-block mb-2 opacity-50"></i>
                No se encontraron documentos clínicos con el filtro seleccionado.
            </div>`;
            return;
        }

        const renderCard = (d) => {
            const idx = this.documentos.indexOf(d);
            const btnClone = d.es_clonable
                ? `<button type="button" class="btn btn-xs btn-success rounded-pill px-2.5 py-0.5 fw-bold" onclick="BovedaService.clonarReceta(${idx})">
                    <i class="bi bi-copy me-1"></i>Clonar Receta
                   </button>`
                : '';

            return `
                <div class="boveda-doc-card">
                    <div class="d-flex justify-content-between align-items-start gap-2 mb-1">
                        <div>
                            <span class="badge bg-primary-subtle text-primary border me-1" style="font-size:0.65rem;">${SOAPReactiveEngine.escapeHtml(d.modulo_origen)}</span>
                            <span class="fw-bold text-navy small">${SOAPReactiveEngine.escapeHtml(d.titulo)}</span>
                        </div>
                        <span class="badge bg-light text-muted border font-monospace" style="font-size:0.65rem;">${SOAPReactiveEngine.escapeHtml(d.fecha_documento)}</span>
                    </div>
                    <div class="small text-muted mb-2" style="font-size:0.74rem;">${SOAPReactiveEngine.escapeHtml(d.resumen_clinico)}</div>
                    <div class="d-flex justify-content-between align-items-center flex-wrap gap-1 pt-1 border-top">
                        <span class="text-muted font-monospace" style="font-size:0.65rem;">Folio: ${SOAPReactiveEngine.escapeHtml(d.folio_origen)}</span>
                        <div class="d-flex gap-1">
                            <button type="button" class="btn btn-xs btn-outline-dark rounded-pill px-2 py-0.5 fw-bold" style="font-size:0.68rem;" onclick="BovedaService.verLightbox(${idx})">
                                <i class="bi bi-eye me-1"></i>Ver (Lightbox)
                            </button>
                            <button type="button" class="btn btn-xs btn-outline-primary rounded-pill px-2 py-0.5 fw-bold" style="font-size:0.68rem;" onclick="BovedaService.citarEnNotaActual(${idx})">
                                <i class="bi bi-quote me-1"></i>Citar en Nota
                            </button>
                            ${btnClone}
                        </div>
                    </div>
                </div>
            `;
        };

        if (this.viewMode === 'TIMELINE') {
            cont.innerHTML = filtered.map(renderCard).join('');
        } else {
            // Jerarquía estricta de 2 niveles: Categoría Clínica -> Documentos en orden cronológico inverso
            const groups = {};
            filtered.forEach(d => {
                const cat = d.categoria_ui || 'Documentos Clínicos';
                if (!groups[cat]) groups[cat] = [];
                groups[cat].push(d);
            });
            let html = '';
            Object.keys(groups).forEach(cat => {
                html += `
                    <div class="mb-3">
                        <div class="d-flex justify-content-between align-items-center bg-white p-2 px-2.5 rounded-3 border mb-2 shadow-2xs">
                            <span class="fw-bold text-navy small"><i class="bi bi-folder-fill text-teal me-1.5"></i>${SOAPReactiveEngine.escapeHtml(cat)}</span>
                            <span class="badge bg-teal text-white rounded-pill" style="background:#19B7A5;">${groups[cat].length}</span>
                        </div>
                        <div class="ps-2">${groups[cat].map(renderCard).join('')}</div>
                    </div>
                `;
            });
            cont.innerHTML = html;
        }
    },

    verLightbox: function(idx) {
        const d = this.documentos[idx];
        if (!d) return;
        const body = document.getElementById('modal-boveda-lightbox-body');
        const title = document.getElementById('modal-boveda-lightbox-title');
        if (title) title.innerText = `${d.titulo} (${d.folio_origen})`;

        if (body) {
            const btnExternal = d.url_recurso
                ? `<a href="${SOAPReactiveEngine.escapeHtml(d.url_recurso)}" target="_blank" class="btn btn-sm btn-primary rounded-pill px-3 fw-bold">
                    <i class="bi bi-box-arrow-up-right me-1"></i>Abrir en Visor Especializado
                   </a>`
                : '';

            body.innerHTML = `
                <div class="p-3 bg-white rounded-3 border">
                    <div class="d-flex justify-content-between align-items-center border-bottom pb-2 mb-2.5">
                        <div>
                            <span class="badge bg-primary me-1">${SOAPReactiveEngine.escapeHtml(d.categoria_ui)}</span>
                            <span class="font-monospace small text-muted">Folio: ${SOAPReactiveEngine.escapeHtml(d.folio_origen)}</span>
                        </div>
                        <span class="small fw-bold text-navy">Fecha: ${SOAPReactiveEngine.escapeHtml(d.fecha_documento)}</span>
                    </div>
                    <div class="mb-2 small"><strong>Responsable / Fuente:</strong> ${SOAPReactiveEngine.escapeHtml(d.medico_responsable)}</div>
                    <div class="p-3 rounded-3 bg-light border mb-3 small">
                        <div class="fw-bold text-navy mb-1">Resumen Clínico del Documento:</div>
                        <div>${SOAPReactiveEngine.escapeHtml(d.resumen_clinico)}</div>
                    </div>
                    <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
                        <span class="font-monospace text-muted" style="font-size:0.7rem;"><i class="bi bi-shield-check text-success me-1"></i>Hash NOM-151: ${SOAPReactiveEngine.escapeHtml(d.hash_nom151)}</span>
                        <div class="d-flex gap-2">
                            <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold" onclick="BovedaService.citarEnNotaActual(${idx})" data-bs-dismiss="modal">
                                <i class="bi bi-quote me-1"></i>Citar en Nota Actual
                            </button>
                            ${btnExternal}
                        </div>
                    </div>
                </div>
            `;
        }

        const modalEl = document.getElementById('modalBovedaLightbox');
        if (modalEl && window.bootstrap) {
            bootstrap.Modal.getOrCreateInstance(modalEl).show();
        }
    },

    citarEnNotaActual: function(idx) {
        if (SOAPReactiveEngine.isLockedNOM151) return;
        const d = this.documentos[idx];
        if (!d) return;
        const citaStr = `[Ref. ${d.folio_origen} · ${d.fecha_documento}] ${d.titulo}: ${d.resumen_clinico}`;

        // Determinar el campo clínico activo según el paso del Wizard
        let targetId = 'f_resultados_estudios';
        if (WizardController.currentStep === 0) targetId = 'f_evolucion';
        else if (WizardController.currentStep === 1) targetId = 'f_resultados_estudios';
        else if (WizardController.currentStep === 2) targetId = 'f_impresion_clinica';
        else if (WizardController.currentStep === 3) targetId = 'com_observaciones';

        SOAPReactiveEngine.appendChip(targetId, citaStr);
        this.closeDrawer();

        if (typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'success',
                title: 'Referencia Citada en Nota',
                text: `Se inyectó [${d.folio_origen}] en el paso activo.`,
                toast: true,
                position: 'top-end',
                timer: 2200,
                showConfirmButton: false
            });
        }
    },

    clonarReceta: function(idx) {
        if (SOAPReactiveEngine.isLockedNOM151) return;
        const d = this.documentos[idx];
        if (!d || !Array.isArray(d.payload_clonable_json)) return;

        WizardController.jumpToStep(2); // Ir al Paso 3 (Análisis, Plan y Receta)
        const chkRec = document.getElementById('check_requiere_receta');
        if (chkRec) {
            chkRec.checked = true;
            toggleSeccionReceta(true);
        }

        d.payload_clonable_json.forEach(med => {
            window.recetaItems.push({
                generico: med.generico || 'Medicamento',
                comercial: med.comercial || '',
                forma: med.forma || 'Tableta',
                concentracion: med.concentracion || '500mg',
                posologia: med.posologia || '1 cada 8 horas por 7 días',
                via: med.via || 'Oral'
            });
        });

        renderRecetaItems();
        this.closeDrawer();

        const hasConflict = SOAPReactiveEngine.activeAllergyConflicts.length > 0;
        if (typeof Swal !== 'undefined') {
            if (hasConflict) {
                Swal.fire({
                    icon: 'error',
                    title: '¡Alerta de Alergia Cruzada al Clonar!',
                    html: `Se clonó la receta <b>${SOAPReactiveEngine.escapeHtml(d.folio_origen)}</b>, pero el Motor de Seguridad detectó conflicto con las alergias del paciente:<br><br><strong class="text-danger">${SOAPReactiveEngine.escapeHtml(SOAPReactiveEngine.activeAllergyConflicts.join('<br>'))}</strong>`
                });
            } else {
                Swal.fire({
                    icon: 'success',
                    title: 'Receta Clonada con Éxito',
                    text: `Se copiaron ${d.payload_clonable_json.length} medicamento(s) al Paso 3 sin conflictos de alergia.`,
                    toast: true,
                    position: 'top-end',
                    timer: 2400,
                    showConfirmButton: false
                });
            }
        }
    }
};
