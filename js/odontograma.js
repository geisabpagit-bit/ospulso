/**
 * ==========================================================================
 * ODONTOGRAMA DIGITAL PLUS - MOTOR FRONTEND v1.1
 * Nomenclatura Internacional FDI / ISO 3950 (32 Piezas Permanentes)
 * Reactividad Vectorial SVG, Zoom Dinámico y Persistencia Visual
 * ==========================================================================
 */

const ODONTO_COLORS = {
    PENDING: '#FF3B30',    // Rojo clínico / Patología Activa / Tratamiento Pendiente
    COMPLETED: '#007AFF',  // Azul eléctrico / Tratamiento Realizado / Condición Existente
    NEUTRAL: '#FFFFFF'
};

// Estado global de la dentición del paciente
window.odontogramState = window.odontogramState || {
    patientId: null,
    dentitionType: 'PERMANENT',
    updatedAt: new Date().toISOString(),
    teeth: {},
    financialTotalPending: 0.00
};

// Nivel de Zoom actual
window.currentOdontoZoom = window.currentOdontoZoom || 1.0;

// Definición de Cuadrantes FDI
const ODONTO_QUADRANTS = {
    Q1: [18, 17, 16, 15, 14, 13, 12, 11], // Superior Derecho
    Q2: [21, 22, 23, 24, 25, 26, 27, 28], // Superior Izquierdo
    Q4: [48, 47, 46, 45, 44, 43, 42, 41], // Inferior Derecho
    Q3: [31, 32, 33, 34, 35, 36, 37, 38]  // Inferior Izquierdo
};

/**
 * Determina el nombre anatómico de cada superficie vectorial según la arcada y el cuadrante
 */
function getSurfaceMapping(toothId) {
    const quad = Math.floor(toothId / 10);
    const isUpper = (quad === 1 || quad === 2);
    const isPatientRight = (quad === 1 || quad === 4);

    return {
        top: isUpper ? 'vestibular' : 'lingual',
        bottom: isUpper ? 'lingual' : 'vestibular',
        left: isPatientRight ? 'distal' : 'mesial',
        right: isPatientRight ? 'mesial' : 'distal',
        center: 'occlusal'
    };
}

/**
 * Genera el SVG vectorial de una pieza dental con sus 5 superficies anatómicas independientes
 */
function generateToothSvg(toothId) {
    const map = getSurfaceMapping(toothId);

    return `
        <svg viewBox="0 0 100 100" class="tooth-svg-canvas" data-tooth="${toothId}">
            <g class="tooth" data-tooth="${toothId}">
                <!-- Superficie Superior -->
                <polygon points="0,0 100,0 75,25 25,25" 
                         class="tooth-surface" 
                         data-tooth="${toothId}" 
                         data-surface="${map.top}"
                         title="Diente ${toothId} - ${map.top.toUpperCase()}"></polygon>
                
                <!-- Superficie Inferior -->
                <polygon points="25,75 75,75 100,100 0,100" 
                         class="tooth-surface" 
                         data-tooth="${toothId}" 
                         data-surface="${map.bottom}"
                         title="Diente ${toothId} - ${map.bottom.toUpperCase()}"></polygon>
                
                <!-- Superficie Izquierda -->
                <polygon points="0,0 25,25 25,75 0,100" 
                         class="tooth-surface" 
                         data-tooth="${toothId}" 
                         data-surface="${map.left}"
                         title="Diente ${toothId} - ${map.left.toUpperCase()}"></polygon>
                
                <!-- Superficie Derecha -->
                <polygon points="100,0 100,100 75,75 75,25" 
                         class="tooth-surface" 
                         data-tooth="${toothId}" 
                         data-surface="${map.right}"
                         title="Diente ${toothId} - ${map.right.toUpperCase()}"></polygon>
                
                <!-- Superficie Oclusal / Central -->
                <polygon points="25,25 75,25 75,75 25,75" 
                         class="tooth-surface" 
                         data-tooth="${toothId}" 
                         data-surface="${map.center}"
                         title="Diente ${toothId} - ${map.center.toUpperCase()}"></polygon>
            </g>
        </svg>
    `;
}

/**
 * Renderiza el Odontograma Completo de 32 Piezas agrupado por cuadrantes
 */
window.renderOdontogram = function(containerId, patientId) {
    const container = document.getElementById(containerId);
    if (!container) return;

    if (patientId) window.odontogramState.patientId = patientId;

    let html = `
        <div class="odonto-board-outer">
            <div class="odonto-board-wrapper" style="transform: scale(${window.currentOdontoZoom || 1});">
                <!-- ARCADA SUPERIOR (MAXILAR) -->
                <div class="odonto-arch-row upper-arch">
                    <!-- Cuadrante 1: Superior Derecho (18 al 11) -->
                    <div class="odonto-quadrant quadrant-1" data-quadrant="1">
    `;

    ODONTO_QUADRANTS.Q1.forEach(id => {
        html += `
            <div class="tooth-card upper-arch" data-tooth="${id}">
                <span class="tooth-number">${id}</span>
                ${generateToothSvg(id)}
            </div>
        `;
    });

    html += `
                    </div>
                    
                    <!-- Línea Media Superior -->
                    <div class="odonto-midline" title="Línea Media Dental"></div>

                    <!-- Cuadrante 2: Superior Izquierdo (21 al 28) -->
                    <div class="odonto-quadrant quadrant-2" data-quadrant="2">
    `;

    ODONTO_QUADRANTS.Q2.forEach(id => {
        html += `
            <div class="tooth-card upper-arch" data-tooth="${id}">
                <span class="tooth-number">${id}</span>
                ${generateToothSvg(id)}
            </div>
        `;
    });

    html += `
                    </div>
                </div>

                <!-- SEPARADOR DE ARCADAS -->
                <div class="odonto-arch-separator">
                    <span>Línea Oclusal / Intermaxilar</span>
                </div>

                <!-- ARCADA INFERIOR (MANDÍBULA) -->
                <div class="odonto-arch-row lower-arch">
                    <!-- Cuadrante 4: Inferior Derecho (48 al 41) -->
                    <div class="odonto-quadrant quadrant-4" data-quadrant="4">
    `;

    ODONTO_QUADRANTS.Q4.forEach(id => {
        html += `
            <div class="tooth-card lower-arch" data-tooth="${id}">
                ${generateToothSvg(id)}
                <span class="tooth-number">${id}</span>
            </div>
        `;
    });

    html += `
                    </div>

                    <!-- Línea Media Inferior -->
                    <div class="odonto-midline" title="Línea Media Dental"></div>

                    <!-- Cuadrante 3: Inferior Izquierdo (31 al 38) -->
                    <div class="odonto-quadrant quadrant-3" data-quadrant="3">
    `;

    ODONTO_QUADRANTS.Q3.forEach(id => {
        html += `
            <div class="tooth-card lower-arch" data-tooth="${id}">
                ${generateToothSvg(id)}
                <span class="tooth-number">${id}</span>
            </div>
        `;
    });

    html += `
                    </div>
                </div>
            </div>
        </div>
    `;

    container.innerHTML = html;

    // Asignar Event Listeners para clics en superficies
    attachSurfaceClickEvents(container);

    // Restaurar marcas existentes desde el estado en memoria
    restoreDomFromState();

    // Actualizar vista previa del JSON si existe
    updateLiveJsonViewer();
    recalculateFinancialTotal();
};

/**
 * Restaura las clases y colores en el DOM SVG a partir del estado en memoria
 */
function restoreDomFromState() {
    if (!window.odontogramState || !window.odontogramState.teeth) return;

    Object.entries(window.odontogramState.teeth).forEach(([tooth, tData]) => {
        if (tData.surfaces) {
            Object.entries(tData.surfaces).forEach(([surf, sData]) => {
                const surfaceEl = document.querySelector(`.tooth-surface[data-tooth="${tooth}"][data-surface="${surf}"]`);
                if (surfaceEl) {
                    const color = sData.colorHex || ((sData.state === 'PENDING_TREATMENT') ? ODONTO_COLORS.PENDING : ODONTO_COLORS.COMPLETED);
                    surfaceEl.style.fill = color;
                    surfaceEl.setAttribute('fill', color);
                    surfaceEl.setAttribute('data-state', sData.state);
                    surfaceEl.classList.add('has-condition');
                    if (sData.state === 'PENDING_TREATMENT') {
                        surfaceEl.classList.add('surface-pending');
                        surfaceEl.classList.remove('surface-completed');
                    } else {
                        surfaceEl.classList.add('surface-completed');
                        surfaceEl.classList.remove('surface-pending');
                    }
                }
            });
        }
    });
}

/**
 * Asigna los manejadores de eventos sobre cada cara vectorial
 */
function attachSurfaceClickEvents(container) {
    const surfaces = container.querySelectorAll('.tooth-surface');
    surfaces.forEach(surfaceEl => {
        surfaceEl.addEventListener('click', function(e) {
            e.stopPropagation();
            const tooth = this.getAttribute('data-tooth');
            const surface = this.getAttribute('data-surface');
            
            // Toggle interactivo para pruebas rápidas
            handleSurfaceInteractiveClick(tooth, surface, this);
        });
    });
}

/**
 * Manejador de clic interactivo: Cicla entre Sin Condición -> Pendiente (Rojo) -> Realizado (Azul) -> Limpio
 */
function handleSurfaceInteractiveClick(tooth, surface, element) {
    const toothStr = String(tooth);
    const existing = window.odontogramState.teeth[toothStr]?.surfaces?.[surface];

    if (!existing) {
        // Asignar Pendiente (Rojo)
        window.applySurfaceCondition(tooth, surface, 'CARIES', 'PENDING_TREATMENT', ODONTO_COLORS.PENDING);
    } else if (existing.state === 'PENDING_TREATMENT') {
        // Pasar a Realizado (Azul)
        window.applySurfaceCondition(tooth, surface, 'RESTORATION', 'EXISTING_CONDITION', ODONTO_COLORS.COMPLETED);
    } else {
        // Limpiar superficie
        removeSurfaceCondition(tooth, surface);
    }
}

/**
 * Aplica una condición clínica y color a una superficie dental
 */
window.applySurfaceCondition = function(tooth, surface, code, state, colorHex) {
    tooth = String(tooth);
    surface = String(surface).toLowerCase();
    
    if (!colorHex) {
        colorHex = (state === 'PENDING_TREATMENT') ? ODONTO_COLORS.PENDING : ODONTO_COLORS.COMPLETED;
    }

    if (!window.odontogramState.teeth[tooth]) {
        window.odontogramState.teeth[tooth] = {
            status: 'PRESENT',
            surfaces: {}
        };
    }

    window.odontogramState.teeth[tooth].surfaces[surface] = {
        code: code || 'CARIES',
        state: state || 'PENDING_TREATMENT',
        colorHex: colorHex,
        price: (state === 'PENDING_TREATMENT') ? 85.00 : 0.00
    };

    window.odontogramState.updatedAt = new Date().toISOString();

    // Actualizar DOM SVG con estilo directo y clases con !important
    const surfaceEl = document.querySelector(`.tooth-surface[data-tooth="${tooth}"][data-surface="${surface}"]`);
    if (surfaceEl) {
        surfaceEl.style.fill = colorHex;
        surfaceEl.setAttribute('fill', colorHex);
        surfaceEl.setAttribute('data-state', state);
        surfaceEl.classList.add('has-condition');
        if (state === 'PENDING_TREATMENT') {
            surfaceEl.classList.add('surface-pending');
            surfaceEl.classList.remove('surface-completed');
        } else {
            surfaceEl.classList.add('surface-completed');
            surfaceEl.classList.remove('surface-pending');
        }
    }

    // Recalcular Total Pendiente
    recalculateFinancialTotal();

    // Actualizar visor JSON
    updateLiveJsonViewer();
};

/**
 * Elimina la condición de una superficie y restaura su color blanco
 */
function removeSurfaceCondition(tooth, surface) {
    tooth = String(tooth);
    surface = String(surface).toLowerCase();

    if (window.odontogramState.teeth[tooth]?.surfaces?.[surface]) {
        delete window.odontogramState.teeth[tooth].surfaces[surface];
        if (Object.keys(window.odontogramState.teeth[tooth].surfaces).length === 0) {
            delete window.odontogramState.teeth[tooth];
        }
    }

    const surfaceEl = document.querySelector(`.tooth-surface[data-tooth="${tooth}"][data-surface="${surface}"]`);
    if (surfaceEl) {
        surfaceEl.style.fill = '';
        surfaceEl.setAttribute('fill', ODONTO_COLORS.NEUTRAL);
        surfaceEl.removeAttribute('data-state');
        surfaceEl.classList.remove('has-condition', 'surface-pending', 'surface-completed');
    }

    recalculateFinancialTotal();
    updateLiveJsonViewer();
}

/**
 * Limpia todo el odontograma tanto en memoria como en el SVG
 */
window.clearOdontogram = function() {
    window.odontogramState.teeth = {};
    window.odontogramState.financialTotalPending = 0.00;
    window.odontogramState.updatedAt = new Date().toISOString();

    document.querySelectorAll('.tooth-surface').forEach(el => {
        el.style.fill = '';
        el.setAttribute('fill', ODONTO_COLORS.NEUTRAL);
        el.removeAttribute('data-state');
        el.classList.remove('has-condition', 'surface-pending', 'surface-completed');
    });

    recalculateFinancialTotal();
    updateLiveJsonViewer();
};

/**
 * Recalcula el total financiero pendiente en base a los tratamientos marcados
 */
function recalculateFinancialTotal() {
    let total = 0;
    Object.values(window.odontogramState.teeth).forEach(tooth => {
        if (tooth.surfaces) {
            Object.values(tooth.surfaces).forEach(surf => {
                if (surf.state === 'PENDING_TREATMENT' && surf.price) {
                    total += parseFloat(surf.price) || 0;
                }
            });
        }
    });
    window.odontogramState.financialTotalPending = total;
    
    const totalEl = document.getElementById('odonto-total-pending');
    if (totalEl) {
        totalEl.textContent = `$${total.toFixed(2)}`;
    }
}

/**
 * Actualiza el bloque de previsualización JSON en tiempo real
 */
function updateLiveJsonViewer() {
    const viewer = document.getElementById('odontogram-live-json');
    if (viewer) {
        viewer.textContent = JSON.stringify(window.odontogramState, null, 2);
    }
}

/**
 * Funciones de Control de Zoom
 */
window.changeOdontoZoom = function(delta) {
    let newZoom = Math.round((window.currentOdontoZoom + delta) * 10) / 10;
    if (newZoom < 0.6) newZoom = 0.6;
    if (newZoom > 1.4) newZoom = 1.4;
    window.setOdontoZoom(newZoom);
};

window.resetOdontoZoom = function() {
    window.setOdontoZoom(1.0);
};

window.setOdontoZoom = function(zoomVal) {
    window.currentOdontoZoom = zoomVal;
    const board = document.querySelector('.odonto-board-wrapper');
    if (board) {
        board.style.transform = `scale(${zoomVal})`;
    }
    const label = document.getElementById('odonto-zoom-label');
    if (label) {
        label.textContent = `${Math.round(zoomVal * 100)}%`;
    }
};

// Inicialización automática si existe el contenedor al cargar DOM
document.addEventListener('DOMContentLoaded', () => {
    const container = document.getElementById('odontograma-svg-container');
    if (container && !container.querySelector('.odonto-board-wrapper')) {
        const patientId = container.getAttribute('data-patient-id') || null;
        window.renderOdontogram('odontograma-svg-container', patientId);
    }
});
