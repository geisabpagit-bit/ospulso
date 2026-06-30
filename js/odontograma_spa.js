/**
 * SDM ODONTOGRAMA SPA ENGINE v2.0
 * Genera un mapa dental interactivo basado en polígonos SVG con persistencia
 * Cumple NOM-013-SSA2-2015: Numeración FDI, superficies clínicas y dentición decidua.
 */

let selectedTool = 'caries';
let currentPacienteId = null;
let currentView = 'adulto'; // 'adulto' o 'nino'
let globalState = {};

const colors = {
    caries: '#e63946',
    corona: '#3b82f6',
    extraccion: '#1e293b',
    sano: '#10b981',
    implante: '#06b6d4',
    protesis: '#f59e0b'
};

const fdiAdulto = {
    sup: [18,17,16,15,14,13,12,11, 21,22,23,24,25,26,27,28],
    inf: [48,47,46,45,44,43,42,41, 31,32,33,34,35,36,37,38]
};

const fdiNino = {
    sup: [55,54,53,52,51, 61,62,63,64,65],
    inf: [85,84,83,82,81, 71,72,73,74,75]
};

async function initOdontograma(containerId, pacienteId) {
    currentPacienteId = pacienteId;
    const container = document.getElementById(containerId);
    if (!container) return;

    container.innerHTML = `
        <div class="d-flex justify-content-center mb-4">
            <div class="btn-group shadow-sm">
                <button class="btn btn-outline-primary active" id="btn-view-adulto" onclick="switchView('adulto')">Dentición Permanente</button>
                <button class="btn btn-outline-primary" id="btn-view-nino" onclick="switchView('nino')">Dentición Decidua</button>
            </div>
        </div>
        <div class="odontograma-grid-layout" style="display: flex; flex-direction: column; gap: 40px; align-items: center;">
            <div class="dental-row row-superior d-flex gap-2 justify-content-center" id="odontograma-row-sup"></div>
            <div class="dental-row row-inferior d-flex gap-2 justify-content-center mt-5" id="odontograma-row-inf"></div>
        </div>
    `;

    setupToolbar();
    drawTeeth();
    await loadOdontogramaFromServer();
}

window.switchView = function(view) {
    currentView = view;
    document.getElementById('btn-view-adulto').classList.toggle('active', view === 'adulto');
    document.getElementById('btn-view-nino').classList.toggle('active', view === 'nino');
    drawTeeth();
    applyOdontogramaState(globalState);
};

function drawTeeth() {
    const rowSup = document.getElementById('odontograma-row-sup');
    const rowInf = document.getElementById('odontograma-row-inf');
    rowSup.innerHTML = '';
    rowInf.innerHTML = '';

    const data = currentView === 'adulto' ? fdiAdulto : fdiNino;

    data.sup.forEach(id => { rowSup.appendChild(createToothElement(id, 'sup')); });
    data.inf.forEach(id => { rowInf.appendChild(createToothElement(id, 'inf')); });
}

function createToothElement(id, rowType) {
    const div = document.createElement('div');
    div.className = 'tooth-wrapper text-center';
    div.style.width = '55px';
    
    // Mapeo clínico. Si es superior, top = vestibular, bottom = palatino. Si es inferior, top = lingual, bottom = vestibular
    const isSup = (rowType === 'sup');
    const topFace = isSup ? 'vestibular' : 'lingual';
    const bottomFace = isSup ? 'palatino' : 'vestibular';
    
    // Simplificación para UI: Las caras izquierda/derecha dependen de si es cuadrante derecho o izquierdo.
    // Usaremos "mesial" y "distal" asignados dinámicamente según el diente.
    let leftFace = 'distal';
    let rightFace = 'mesial';
    
    const quad = Math.floor(id / 10);
    if (quad === 1 || quad === 4 || quad === 5 || quad === 8) {
        // Lado derecho del paciente (izquierdo en pantalla)
        leftFace = 'distal';
        rightFace = 'mesial';
    } else {
        // Lado izquierdo del paciente (derecho en pantalla)
        leftFace = 'mesial';
        rightFace = 'distal';
    }

    div.innerHTML = `
        <span class="small fw-bold text-muted d-block mb-2">${id}</span>
        <svg viewBox="0 0 100 100" class="tooth-svg" style="cursor: pointer; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.05));">
            <polygon points="10,10 90,10 75,25 25,25" class="tooth-face" data-pos="${topFace}" fill="white" stroke="#cbd5e1" stroke-width="2"/>
            <polygon points="25,75 75,75 90,90 10,90" class="tooth-face" data-pos="${bottomFace}" fill="white" stroke="#cbd5e1" stroke-width="2"/>
            <polygon points="10,10 25,25 25,75 10,90" class="tooth-face" data-pos="${leftFace}" fill="white" stroke="#cbd5e1" stroke-width="2"/>
            <polygon points="90,10 90,90 75,75 75,25" class="tooth-face" data-pos="${rightFace}" fill="white" stroke="#cbd5e1" stroke-width="2"/>
            <rect x="25" y="25" width="50" height="50" class="tooth-face" data-pos="oclusal" fill="white" stroke="#cbd5e1" stroke-width="2"/>
        </svg>
    `;
    div.querySelectorAll('.tooth-face').forEach(face => {
        face.addEventListener('click', function(e) { applyTool(this); });
    });
    return div;
}

function applyTool(element) {
    const svg = element.closest('svg');
    const toothId = svg.parentElement.querySelector('span').innerText;

    // Actualizar globalState para trazabilidad
    if (!globalState[toothId]) {
        globalState[toothId] = { extracted: false, faces: {} };
    }

    if (selectedTool === 'extraccion' || selectedTool === 'implante' || selectedTool === 'protesis') {
        const isWholeToothStatus = svg.classList.contains(selectedTool);
        
        // Limpiar todas las clases previas de diente completo
        svg.classList.remove('extracted', 'implante', 'protesis');
        
        if (isWholeToothStatus) {
            svg.querySelectorAll('.tooth-face').forEach(f => f.setAttribute('fill', 'white'));
            globalState[toothId].extracted = false;
            globalState[toothId].whole_status = null;
        } else {
            svg.classList.add(selectedTool);
            svg.querySelectorAll('.tooth-face').forEach(f => f.setAttribute('fill', colors[selectedTool]));
            globalState[toothId].extracted = (selectedTool === 'extraccion');
            globalState[toothId].whole_status = selectedTool;
            globalState[toothId].faces = {}; // Limpiar caras
        }
    } else {
        // Herramientas de caras individuales (Caries, Corona, Sano)
        element.setAttribute('fill', colors[selectedTool]);
        svg.classList.remove('extracted', 'implante', 'protesis');
        globalState[toothId].extracted = false;
        globalState[toothId].whole_status = null;
        
        const facePos = element.dataset.pos;
        globalState[toothId].faces[facePos] = selectedTool;
    }

    if (typeof updateDiagnosisList === 'function') updateDiagnosisList();
}

function setupToolbar() {
    document.querySelectorAll('#odontograma-toolbar button').forEach(btn => {
        btn.addEventListener('click', function() {
            // Remove active classes
            document.querySelectorAll('#odontograma-toolbar button').forEach(b => {
                b.classList.remove('active');
                // Remove btn-danger, btn-primary etc, restore outline
                const t = b.dataset.tool;
                const c = t==='caries'?'danger':t==='corona'?'primary':t==='extraccion'?'dark':t==='implante'?'info':t==='protesis'?'warning':'success';
                b.classList.remove('btn-'+c);
                b.classList.add('btn-outline-'+c);
            });
            // Set active class
            const t = this.dataset.tool;
            const c = t==='caries'?'danger':t==='corona'?'primary':t==='extraccion'?'dark':t==='implante'?'info':t==='protesis'?'warning':'success';
            this.classList.remove('btn-outline-'+c);
            this.classList.add('btn-'+c, 'active');
            selectedTool = this.dataset.tool;
        });
    });
}

async function loadOdontogramaFromServer() {
    try {
        const res = await fetch(`../api/odontograma_api.pl?id_paciente=${currentPacienteId}`);
        const json = await res.json();
        if (json.ok && json.data) { 
            globalState = json.data;
            if (globalState.notas) {
                const notasEl = document.getElementById('odontograma-notas');
                if (notasEl) notasEl.value = globalState.notas;
                delete globalState.notas;
            }
            if (globalState.fecha) {
                delete globalState.fecha;
            }
            applyOdontogramaState(globalState); 
        }
    } catch (e) { console.error("Error cargando odontograma", e); }
}

function applyOdontogramaState(data) {
    const allWrappers = document.querySelectorAll('.tooth-wrapper');
    Object.keys(data).forEach(toothId => {
        let wrapper = Array.from(allWrappers).find(w => w.querySelector('span').innerText == toothId);
        if (wrapper) {
            const svg = wrapper.querySelector('svg');
            const state = data[toothId];
            
            // Limpiar
            svg.classList.remove('extracted', 'implante', 'protesis');
            svg.querySelectorAll('.tooth-face').forEach(f => f.setAttribute('fill', 'white'));

            if (state.extracted || state.whole_status === 'extraccion') {
                svg.classList.add('extraccion'); // CSS uses extracted? Actually in draw we use selectedTool name
                svg.querySelectorAll('.tooth-face').forEach(f => f.setAttribute('fill', colors.extraccion));
            } else if (state.whole_status === 'implante') {
                svg.classList.add('implante');
                svg.querySelectorAll('.tooth-face').forEach(f => f.setAttribute('fill', colors.implante));
            } else if (state.whole_status === 'protesis') {
                svg.classList.add('protesis');
                svg.querySelectorAll('.tooth-face').forEach(f => f.setAttribute('fill', colors.protesis));
            } else if (state.faces) {
                Object.keys(state.faces).forEach(facePos => {
                    const face = svg.querySelector(`[data-pos="${facePos}"]`);
                    if (face) face.setAttribute('fill', colors[state.faces[facePos]]);
                });
            }
        }
    });

    if (typeof updateDiagnosisList === 'function') updateDiagnosisList();
}

async function saveOdontogramaToServer() {
    Swal.fire({ title: 'Guardando Odontograma...', didOpen: () => { Swal.showLoading(); } });
    try {
        const fd = new FormData();
        fd.append('accion', 'save');
        fd.append('id_paciente', currentPacienteId);
        fd.append('data', JSON.stringify(globalState));
        
        const notasEl = document.getElementById('odontograma-notas');
        if (notasEl) {
            fd.append('notas', notasEl.value);
        }

        const res = await fetch('../api/odontograma_api.pl', { method: 'POST', body: fd });
        const json = await res.json();
        if (json.ok) { Swal.fire({ icon: 'success', title: 'Guardado', text: 'El estado dental se ha sincronizado correctamente.', timer: 1500, showConfirmButton: false }); }
    } catch (e) { Swal.fire('Error', 'No se pudo conectar con el servidor', 'error'); }
}

window.resetOdontograma = function() {
    Swal.fire({
        title: '¿Resetear Odontograma?',
        text: "Se borrarán todos los diagnósticos en pantalla de ambas denticiones.",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#e63946',
        confirmButtonText: 'Sí, borrar todo',
        cancelButtonText: 'Cancelar'
    }).then((result) => {
        if (result.isConfirmed) {
            globalState = {};
            const notasEl = document.getElementById('odontograma-notas');
            if (notasEl) notasEl.value = '';
            applyOdontogramaState(globalState);
        }
    });
};

window.preparePrint = function() {
    const printDate = document.getElementById('print-date');
    if (printDate) printDate.innerText = new Date().toLocaleString();
    
    const printNotas = document.getElementById('print-notas');
    const notasEl = document.getElementById('odontograma-notas');
    if (printNotas && notasEl) {
        printNotas.innerText = notasEl.value.trim() !== '' ? notasEl.value : 'Sin observaciones clínicas.';
    }
    
    window.print();
};

window.updateDiagnosisList = function() {
    const tbody = document.getElementById('tbody-diagnostico');
    if (!tbody) return;

    let html = '';
    const teeth = Object.keys(globalState).sort((a, b) => parseInt(a) - parseInt(b));
    let hasFindings = false;

    teeth.forEach(tooth => {
        const state = globalState[tooth];
        if (!state) return;
        
        let diag = [];
        let detalles = [];
        
        if (state.whole_status) {
            diag.push(state.whole_status.charAt(0).toUpperCase() + state.whole_status.slice(1));
            detalles.push("Pieza Completa");
        }
        
        if (state.faces && Object.keys(state.faces).length > 0) {
            let caraList = [];
            for (const [cara, tool] of Object.entries(state.faces)) {
                caraList.push(`${tool.charAt(0).toUpperCase() + tool.slice(1)} en cara ${cara.toUpperCase()}`);
            }
            if (caraList.length > 0) {
                diag.push("Afección en caras");
                detalles.push(caraList.join('<br>'));
            }
        }
        
        if (diag.length > 0) {
            hasFindings = true;
            html += `<tr>
                <td class="rounded-start-4 ps-4 fw-bold">Pieza ${tooth}</td>
                <td class="fw-bold text-primary">${diag.join(' + ')}</td>
                <td class="rounded-end-4 text-muted small">${detalles.join('<br>')}</td>
            </tr>`;
        }
    });

    if (!hasFindings) {
        html = `<tr><td colspan="3" class="text-center text-muted py-4 small fw-bold">No hay hallazgos registrados aún.</td></tr>`;
    }

    tbody.innerHTML = html;
};
