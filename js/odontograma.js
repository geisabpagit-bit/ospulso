/**
 * ==========================================================================
 * ODONTOGRAMA DIGITAL PLUS - MOTOR FRONTEND v1.2
 * Nomenclatura Internacional FDI / ISO 3950 (32 Piezas Permanentes)
 * Modelado Anatómico, Selector Clínico en Cascada y Modal Glassmorphism
 * ==========================================================================
 */

const ODONTO_COLORS = {
    PENDING: '#FF3B30',    // Rojo clínico / Patología Activa / Tratamiento Pendiente
    COMPLETED: '#007AFF',  // Azul eléctrico / Tratamiento Realizado / Condición Existente
    NEUTRAL: '#FFFFFF',
    ABSENT: '#64748B'
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

// Variables de contexto para el modal clínico activo
window.odontoModalContext = {
    tooth: null,
    surface: 'occlusal',
    scope: 'SURFACE', // SURFACE | CROWN | TOOTH
    selectedCondition: 'CARIES'
};

// Definición de Cuadrantes FDI
const ODONTO_QUADRANTS = {
    Q1: [18, 17, 16, 15, 14, 13, 12, 11], // Superior Derecho
    Q2: [21, 22, 23, 24, 25, 26, 27, 28], // Superior Izquierdo
    Q4: [48, 47, 46, 45, 44, 43, 42, 41], // Inferior Derecho
    Q3: [31, 32, 33, 34, 35, 36, 37, 38]  // Inferior Izquierdo
};

// Catálogo Clínico Canónico de Patologías y Procedimientos
// Catálogo Clínico Canónico de Patologías y Procedimientos (3 Grupos SaaS)
const ODONTO_CATALOG = {
    // ==========================================
    // 🔴 GRUPO 1: PATOLOGÍA / HALLAZGO
    // ==========================================
    CARIES: {
        code: 'CARIES',
        name: 'Caries Dental (Activa)',
        group: 'PATHOLOGY',
        category: 'PENDING',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF3B30',
        price: 850.00,
        icon: 'bi-circle-fill text-danger'
    },
    CARIES_RECURRENT: {
        code: 'CARIES_RECURRENT',
        name: 'Caries Recurrente / Filtrada',
        group: 'PATHOLOGY',
        category: 'PENDING',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF3B30',
        price: 950.00,
        icon: 'bi-exclamation-triangle-fill text-danger'
    },
    FRACTURE: {
        code: 'FRACTURE',
        name: 'Fractura Dental',
        group: 'PATHOLOGY',
        category: 'PENDING',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF3B30',
        price: 1200.00,
        icon: 'bi-slash-circle-fill text-danger'
    },
    ABSENT: {
        code: 'ABSENT',
        name: 'Diente Ausente',
        group: 'PATHOLOGY',
        category: 'EXISTING',
        state: 'EXISTING_CONDITION',
        colorHex: '#64748B',
        price: 0.00,
        icon: 'bi-x-lg text-secondary'
    },
    EXTRACTION_REQ: {
        code: 'EXTRACTION_REQ',
        name: 'Extracción Indicada',
        group: 'PATHOLOGY',
        category: 'PENDING',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF3B30',
        price: 1100.00,
        icon: 'bi-x-octagon-fill text-danger'
    },

    // ==========================================
    // 🟠 GRUPO 2: ESTADO DE TRATAMIENTO / RESTAURACIÓN
    // ==========================================
    AMALGAM: {
        code: 'AMALGAM',
        name: 'Amalgama Adaptada',
        group: 'RESTORATION',
        category: 'EXISTING',
        substatus: 'ADAPTED',
        state: 'EXISTING_CONDITION',
        colorHex: '#007AFF',
        price: 0.00,
        icon: 'bi-shield-check text-primary'
    },
    AMALGAM_DEFECTIVE: {
        code: 'AMALGAM_DEFECTIVE',
        name: 'Amalgama Desadaptada (Recambio)',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'DEFECTIVE',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF9500',
        price: 850.00,
        icon: 'bi-shield-exclamation text-warning'
    },
    COMPOSITE: {
        code: 'COMPOSITE',
        name: 'Resina Adaptada',
        group: 'RESTORATION',
        category: 'EXISTING',
        substatus: 'ADAPTED',
        state: 'EXISTING_CONDITION',
        colorHex: '#007AFF',
        price: 0.00,
        icon: 'bi-check-circle-fill text-primary'
    },
    COMPOSITE_DEFECTIVE: {
        code: 'COMPOSITE_DEFECTIVE',
        name: 'Resina Desadaptada (Filtrada)',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'DEFECTIVE',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF9500',
        price: 950.00,
        icon: 'bi-exclamation-circle-fill text-warning'
    },
    CROWN_DONE: {
        code: 'CROWN_DONE',
        name: 'Corona Buena',
        group: 'RESTORATION',
        category: 'EXISTING',
        substatus: 'ADAPTED',
        state: 'EXISTING_CONDITION',
        colorHex: '#007AFF',
        price: 0.00,
        icon: 'bi-trophy-fill text-primary'
    },
    CROWN_DEFECTIVE: {
        code: 'CROWN_DEFECTIVE',
        name: 'Corona Desadaptada (Reemplazo)',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'DEFECTIVE',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF9500',
        price: 3500.00,
        icon: 'bi-exclamation-triangle-fill text-warning'
    },
    POST_GOOD: {
        code: 'POST_GOOD',
        name: 'Perno Bueno',
        group: 'RESTORATION',
        category: 'EXISTING',
        substatus: 'ADAPTED',
        state: 'EXISTING_CONDITION',
        colorHex: '#007AFF',
        price: 0.00,
        icon: 'bi-pin-fill text-primary'
    },
    POST_DEFECTIVE: {
        code: 'POST_DEFECTIVE',
        name: 'Perno Malo / Desajustado',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'DEFECTIVE',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF9500',
        price: 1400.00,
        icon: 'bi-pin-angle-fill text-warning'
    },
    SEALANT_GOOD: {
        code: 'SEALANT_GOOD',
        name: 'Sellante Bueno',
        group: 'RESTORATION',
        category: 'EXISTING',
        substatus: 'ADAPTED',
        state: 'EXISTING_CONDITION',
        colorHex: '#007AFF',
        price: 0.00,
        icon: 'bi-shield-shaded text-primary'
    },
    SEALANT_DEFECTIVE: {
        code: 'SEALANT_DEFECTIVE',
        name: 'Sellante Desadaptado',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'DEFECTIVE',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF9500',
        price: 450.00,
        icon: 'bi-shield-slash text-warning'
    },
    PROVISIONAL: {
        code: 'PROVISIONAL',
        name: 'Restauración Provisional',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'TEMPORARY',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF9500',
        price: 500.00,
        icon: 'bi-clock-history text-warning'
    },
    ENDO_DONE: {
        code: 'ENDO_DONE',
        name: 'Endodoncia Buena',
        group: 'RESTORATION',
        category: 'EXISTING',
        substatus: 'ADAPTED',
        state: 'EXISTING_CONDITION',
        colorHex: '#007AFF',
        price: 0.00,
        icon: 'bi-heart-pulse-fill text-primary'
    },
    ENDO_DEFECTIVE: {
        code: 'ENDO_DEFECTIVE',
        name: 'Endodoncia Mala / Retratamiento',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'DEFECTIVE',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF9500',
        price: 3200.00,
        icon: 'bi-activity text-warning'
    },
    IMPLANT: {
        code: 'IMPLANT',
        name: 'Implante Bueno',
        group: 'RESTORATION',
        category: 'EXISTING',
        substatus: 'ADAPTED',
        state: 'EXISTING_CONDITION',
        colorHex: '#007AFF',
        price: 0.00,
        icon: 'bi-pin-angle-fill text-primary'
    },
    IMPLANT_DEFECTIVE: {
        code: 'IMPLANT_DEFECTIVE',
        name: 'Implante Malo / Periimplantitis',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'DEFECTIVE',
        state: 'PENDING_TREATMENT',
        colorHex: '#FF9500',
        price: 4500.00,
        icon: 'bi-exclamation-diamond-fill text-warning'
    },
    PONTIC: {
        code: 'PONTIC',
        name: 'Póntico de Puente Fijo',
        group: 'RESTORATION',
        category: 'PENDING',
        substatus: 'PONTIC',
        state: 'PENDING_TREATMENT',
        colorHex: '#007AFF',
        price: 2800.00,
        icon: 'bi-link-45deg text-primary'
    },

    // ==========================================
    // 🟢 GRUPO 3: ESTADO NORMAL
    // ==========================================
    HEALTHY: {
        code: 'HEALTHY',
        name: 'Diente Sano (Sin Hallazgos)',
        group: 'NORMAL',
        category: 'HEALTHY',
        state: 'HEALTHY',
        colorHex: '#FFFFFF',
        price: 0.00,
        icon: 'bi-shield-check text-success'
    },
    OTHER: {
        code: 'OTHER',
        name: 'Otros Hallazgos Fisiológicos',
        group: 'NORMAL',
        category: 'HEALTHY',
        state: 'HEALTHY',
        colorHex: '#94A3B8',
        price: 0.00,
        icon: 'bi-info-circle-fill text-secondary'
    }
};

// Alias de retrocompatibilidad
ODONTO_CATALOG.AMALGAM_ADAPTED     = ODONTO_CATALOG.AMALGAM;
ODONTO_CATALOG.COMPOSITE_ADAPTED   = ODONTO_CATALOG.COMPOSITE;
ODONTO_CATALOG.CROWN_GOOD          = ODONTO_CATALOG.CROWN_DONE;
ODONTO_CATALOG.CROWN_REQ           = ODONTO_CATALOG.CROWN_DEFECTIVE;
ODONTO_CATALOG.SEALANT_REQ         = ODONTO_CATALOG.SEALANT_DEFECTIVE;
ODONTO_CATALOG.ENDO_REQ            = ODONTO_CATALOG.ENDO_DEFECTIVE;
ODONTO_CATALOG.ENDO_GOOD           = ODONTO_CATALOG.ENDO_DONE;
ODONTO_CATALOG.IMPLANT_GOOD        = ODONTO_CATALOG.IMPLANT;

/**
 * Retorna el nombre anatómico en español según FDI
 */
function getToothFullName(toothId) {
    const id = parseInt(toothId, 10);
    const quad = Math.floor(id / 10);
    const num = id % 10;
    
    const quadNames = {
        1: 'Superior Derecho',
        2: 'Superior Izquierdo',
        3: 'Inferior Izquierdo',
        4: 'Inferior Derecho'
    };
    
    const toothTypes = {
        1: 'Incisivo Central',
        2: 'Incisivo Lateral',
        3: 'Canino',
        4: 'Primer Premolar',
        5: 'Segundo Premolar',
        6: 'Primer Molar',
        7: 'Segundo Molar',
        8: 'Tercer Molar'
    };
    
    const type = toothTypes[num] || 'Pieza';
    const quadName = quadNames[quad] || '';
    return `${type} ${quadName}`;
}

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
 * Clasifica la pieza dental según su familia anatómica FDI
 */
function getToothFamily(toothId) {
    const digit = parseInt(toothId, 10) % 10;
    if (digit === 1 || digit === 2) return 'INCISOR';
    if (digit === 3) return 'CANINE';
    if (digit === 4 || digit === 5) return 'PREMOLAR';
    return 'MOLAR'; // 6, 7, 8
}

/**
 * Modelado Anatómico Vectorial de Porcelana (Raíces + Coronas)
 */
const PORCELAIN_ROOT_PATHS = {
    UPPER: {
        MOLAR: "M 18,65 C 14,35 10,12 18,5 C 24,5 26,28 34,65 Z M 42,65 C 45,30 48,6 52,4 C 56,6 58,30 60,65 Z M 66,65 C 74,28 78,12 84,5 C 90,5 86,35 82,65 Z",
        PREMOLAR: "M 28,65 C 24,32 32,8 50,5 C 68,8 76,32 72,65 Z",
        CANINE: "M 28,65 C 26,28 38,4 50,3 C 62,4 74,28 72,65 Z",
        INCISOR: "M 32,65 C 32,32 40,6 50,5 C 60,6 68,32 68,65 Z"
    },
    LOWER: {
        MOLAR: "M 16,75 C 12,105 14,132 22,136 C 28,136 34,112 42,88 C 47,84 53,84 58,88 C 66,112 72,136 78,136 C 86,132 88,105 84,75 Z",
        PREMOLAR: "M 28,75 C 24,108 32,132 50,135 C 68,132 76,108 72,75 Z",
        CANINE: "M 28,75 C 26,112 38,136 50,137 C 62,136 74,112 72,75 Z",
        INCISOR: "M 32,75 C 32,108 40,134 50,135 C 60,134 68,108 68,75 Z"
    }
};

const ANATOMICAL_SURFACE_PATHS = {
    MOLAR: {
        center: "M 32,32 C 38,26 62,26 68,32 C 74,38 74,62 68,68 C 62,74 38,74 32,68 C 26,62 26,38 32,32 Z",
        top: "M 14,18 C 28,6 72,6 86,18 C 82,24 76,28 68,32 C 62,26 38,26 32,32 C 24,28 18,24 14,18 Z",
        bottom: "M 32,68 C 38,74 62,74 68,68 C 76,72 82,76 86,82 C 72,94 28,94 14,82 C 18,76 24,72 32,68 Z",
        left: "M 14,18 C 18,24 24,28 32,32 C 26,38 26,62 32,68 C 24,72 18,76 14,82 C 6,68 6,32 14,18 Z",
        right: "M 68,32 C 76,28 82,24 86,18 C 94,32 94,68 86,82 C 82,76 76,72 68,68 C 74,62 74,38 68,32 Z",
        fissures: "M 32,32 L 68,68 M 68,32 L 32,68"
    },
    PREMOLAR: {
        center: "M 34,35 C 42,28 58,28 66,35 C 72,42 72,58 66,65 C 58,72 42,72 34,65 C 28,58 28,42 34,35 Z",
        top: "M 18,22 C 32,10 68,10 82,22 C 78,28 72,32 66,35 C 58,28 42,28 34,35 C 28,32 22,28 18,22 Z",
        bottom: "M 34,65 C 42,72 58,72 66,65 C 72,68 78,72 82,78 C 68,90 32,90 18,78 C 22,72 28,68 34,65 Z",
        left: "M 18,22 C 22,28 28,32 34,35 C 28,42 28,58 34,65 C 28,68 22,72 18,78 C 10,64 10,36 18,22 Z",
        right: "M 66,35 C 72,32 78,28 82,22 C 90,36 90,64 82,78 C 78,72 72,68 66,65 C 72,58 72,42 66,35 Z",
        fissures: "M 38,50 L 62,50"
    },
    CANINE: {
        center: "M 38,36 C 46,28 54,28 62,36 C 68,44 66,56 60,63 C 54,68 46,68 40,63 C 34,56 32,44 38,36 Z",
        top: "M 22,26 C 36,12 50,6 50,6 C 50,6 64,12 78,26 C 72,31 66,34 62,36 C 54,28 46,28 38,36 C 34,34 28,31 22,26 Z",
        bottom: "M 40,63 C 46,68 54,68 60,63 C 66,68 72,73 76,80 C 64,92 36,92 24,80 C 28,73 34,68 40,63 Z",
        left: "M 22,26 C 28,31 34,34 38,36 C 32,44 34,56 40,63 C 34,68 28,73 24,80 C 14,64 12,42 22,26 Z",
        right: "M 62,36 C 66,34 72,31 78,26 C 88,42 86,64 76,80 C 72,73 66,68 60,63 C 66,56 68,44 62,36 Z",
        fissures: "M 50,18 L 50,48"
    },
    INCISOR: {
        center: "M 28,43 C 36,39 64,39 72,43 C 76,47 76,53 72,57 C 64,61 36,61 28,57 C 24,53 24,47 28,43 Z",
        top: "M 18,22 C 32,12 68,12 82,22 C 78,32 74,38 72,43 C 64,39 36,39 28,43 C 26,38 22,32 18,22 Z",
        bottom: "M 28,57 C 36,61 64,61 72,57 C 74,62 78,68 82,78 C 68,88 32,88 18,78 C 22,68 26,62 28,57 Z",
        left: "M 18,22 C 22,32 26,38 28,43 C 24,47 24,53 28,57 C 26,62 22,68 18,78 C 12,62 12,38 18,22 Z",
        right: "M 72,43 C 74,38 78,32 82,22 C 88,38 88,62 82,78 C 78,68 74,62 72,57 C 76,53 76,47 72,43 Z",
        fissures: "M 32,50 L 68,50"
    }
};

/**
 * Genera el mapa clínico de 5 zonas vectoriales independientes (caja azul)
 */
function generateToothSvg(toothId) {
    const map = getSurfaceMapping(toothId);
    const family = getToothFamily(toothId);
    const paths = ANATOMICAL_SURFACE_PATHS[family] || ANATOMICAL_SURFACE_PATHS.MOLAR;

    return `
        <svg viewBox="0 0 100 100" class="tooth-svg-canvas family-${family.toLowerCase()}" data-tooth="${toothId}">
            <g class="tooth" data-tooth="${toothId}" data-family="${family}">
                <!-- Superficie Superior (${map.top}) -->
                <path d="${paths.top}" 
                      class="tooth-surface surface-top" 
                      data-tooth="${toothId}" 
                      data-surface="${map.top}"
                      title="Diente ${toothId} - ${map.top.toUpperCase()}"></path>
                
                <!-- Superficie Inferior (${map.bottom}) -->
                <path d="${paths.bottom}" 
                      class="tooth-surface surface-bottom" 
                      data-tooth="${toothId}" 
                      data-surface="${map.bottom}"
                      title="Diente ${toothId} - ${map.bottom.toUpperCase()}"></path>
                
                <!-- Superficie Izquierda (${map.left}) -->
                <path d="${paths.left}" 
                      class="tooth-surface surface-left" 
                      data-tooth="${toothId}" 
                      data-surface="${map.left}"
                      title="Diente ${toothId} - ${map.left.toUpperCase()}"></path>
                
                <!-- Superficie Derecha (${map.right}) -->
                <path d="${paths.right}" 
                      class="tooth-surface surface-right" 
                      data-tooth="${toothId}" 
                      data-surface="${map.right}"
                      title="Diente ${toothId} - ${map.right.toUpperCase()}"></path>
                
                <!-- Superficie Oclusal / Central (${map.center}) -->
                <path d="${paths.center}" 
                      class="tooth-surface surface-center" 
                      data-tooth="${toothId}" 
                      data-surface="${map.center}"
                      title="Diente ${toothId} - ${map.center.toUpperCase()}"></path>

                <!-- Fisuras Anatómicas Oclusales -->
                ${paths.fissures ? `<path d="${paths.fissures}" class="tooth-fissure-line" />` : ''}
            </g>
        </svg>
    `;
}

/**
 * Resuelve la ruta canónica de los activos de piezas dentales según la ubicación de la vista
 */
function getToothImgPath(filename) {
    if (window.location.pathname.includes('/views/')) {
        return `../img/teeth/${filename}`;
    }
    return `img/teeth/${filename}`;
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
        const fam = getToothFamily(id).toLowerCase();
        html += `
            <div class="tooth-card upper-arch family-${fam}" data-tooth="${id}">
                <span class="tooth-number">${id}</span>
                <div class="tooth-porcelain-morphology" title="Morfología Anatómica 3D Pieza ${id}">
                    <img src="${getToothImgPath('tooth_' + id + '.png')}" alt="Pieza ${id}" class="tooth-porcelain-img" onerror="if(!this.dataset.fallback){this.dataset.fallback=1; this.src='../img/teeth/tooth_${id}.png';}" />
                </div>
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
        const fam = getToothFamily(id).toLowerCase();
        html += `
            <div class="tooth-card upper-arch family-${fam}" data-tooth="${id}">
                <span class="tooth-number">${id}</span>
                <div class="tooth-porcelain-morphology" title="Morfología Anatómica 3D Pieza ${id}">
                    <img src="${getToothImgPath('tooth_' + id + '.png')}" alt="Pieza ${id}" class="tooth-porcelain-img" onerror="if(!this.dataset.fallback){this.dataset.fallback=1; this.src='../img/teeth/tooth_${id}.png';}" />
                </div>
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
        const fam = getToothFamily(id).toLowerCase();
        html += `
            <div class="tooth-card lower-arch family-${fam}" data-tooth="${id}">
                ${generateToothSvg(id)}
                <div class="tooth-porcelain-morphology" title="Morfología Anatómica 3D Pieza ${id}">
                    <img src="${getToothImgPath('tooth_' + id + '.png')}" alt="Pieza ${id}" class="tooth-porcelain-img" onerror="if(!this.dataset.fallback){this.dataset.fallback=1; this.src='../img/teeth/tooth_${id}.png';}" />
                </div>
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
        const fam = getToothFamily(id).toLowerCase();
        html += `
            <div class="tooth-card lower-arch family-${fam}" data-tooth="${id}">
                ${generateToothSvg(id)}
                <div class="tooth-porcelain-morphology" title="Morfología Anatómica 3D Pieza ${id}">
                    <img src="${getToothImgPath('tooth_' + id + '.png')}" alt="Pieza ${id}" class="tooth-porcelain-img" onerror="if(!this.dataset.fallback){this.dataset.fallback=1; this.src='../img/teeth/tooth_${id}.png';}" />
                </div>
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

    // Asignar Event Listeners para clics en superficies y dientes
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
        const card = document.querySelector(`.tooth-card[data-tooth="${tooth}"]`);
        if (card) {
            card.classList.remove('tooth-absent', 'tooth-extraction-req', 'tooth-endo-pending', 'tooth-endo-done');
            
            // Diente ausente o exodoncia requerida
            if (tData.status === 'ABSENT' || tData.absent) {
                card.classList.add('tooth-absent');
            } else if (tData.status === 'EXTRACTION_REQUIRED') {
                card.classList.add('tooth-extraction-req');
            }

            // Endodoncia en raíz
            if (tData.root && tData.root.code) {
                if (tData.root.code === 'ENDO_REQ') card.classList.add('tooth-endo-pending');
                else if (tData.root.code === 'ENDO_DONE') card.classList.add('tooth-endo-done');
            }
        }

        // Superficies
        if (tData.surfaces) {
            Object.entries(tData.surfaces).forEach(([surf, sData]) => {
                const surfaceEl = document.querySelector(`.tooth-surface[data-tooth="${tooth}"][data-surface="${surf}"]`);
                if (surfaceEl) {
                    const condCode = (typeof sData === 'object' && sData.code) ? sData.code : sData;
                    const catObj = window.ODONTO_CATALOG ? window.ODONTO_CATALOG[condCode] : null;
                    const state = (typeof sData === 'object' && sData.state) 
                        ? sData.state 
                        : ((catObj?.category === 'PENDING') ? 'PENDING_TREATMENT' : 'EXISTING_CONDITION');
                    const isDefective = (catObj?.substatus === 'DEFECTIVE') || (sData.colorHex === '#FF9500');
                    const color = (typeof sData === 'object' && sData.colorHex) 
                        ? sData.colorHex 
                        : (catObj?.colorHex || (isDefective ? '#FF9500' : (state === 'PENDING_TREATMENT' ? ODONTO_COLORS.PENDING : ODONTO_COLORS.COMPLETED)));

                    surfaceEl.style.fill = color;
                    surfaceEl.setAttribute('fill', color);
                    surfaceEl.setAttribute('data-state', state);
                    surfaceEl.classList.add('has-condition');
                    surfaceEl.classList.remove('surface-pending', 'surface-completed', 'surface-defective');
                    if (isDefective) {
                        surfaceEl.classList.add('surface-defective');
                    } else if (state === 'PENDING_TREATMENT') {
                        surfaceEl.classList.add('surface-pending');
                    } else {
                        surfaceEl.classList.add('surface-completed');
                    }
                }
            });
        }
    });
}

/**
 * Carga e hidrata un estado completo de odontograma (FDI) en memoria y en el lienzo SVG
 */
window.loadOdontogramState = function(stateObj) {
    if (!stateObj || typeof stateObj !== 'object') return;

    if (stateObj.patientId) window.odontogramState.patientId = stateObj.patientId;
    if (stateObj.dentitionType) window.odontogramState.dentitionType = stateObj.dentitionType;
    if (stateObj.periodontalSummary) window.odontogramState.periodontalSummary = stateObj.periodontalSummary;
    if (stateObj.updatedAt) window.odontogramState.updatedAt = stateObj.updatedAt;

    if (stateObj.teeth && typeof stateObj.teeth === 'object') {
        window.odontogramState.teeth = stateObj.teeth;
    } else {
        window.odontogramState.teeth = {};
        Object.keys(stateObj).forEach(key => {
            if (/^\d{2}$/.test(key) && typeof stateObj[key] === 'object') {
                window.odontogramState.teeth[key] = stateObj[key];
            }
        });
    }

    restoreDomFromState();
    recalculateFinancialTotal();
    updateLiveJsonViewer();

    if (typeof refreshSidebarFindings === 'function') {
        refreshSidebarFindings();
    }
};

/**
 * ==========================================================================
 * PUENTE CIRCULAR GLASSMORPHIC (RADIAL FLOATING POPUP MENU CONTROLLER)
 * ==========================================================================
 */
let currentRadialTooth = null;
let currentRadialSurface = 'occlusal';

/**
 * Inicializa e inyecta el menú radial flotante en el body si no existe
 */
function initOdontoRadialMenu() {
    if (document.getElementById('odonto-radial-menu')) return;

    const radialHtml = `
        <div id="odonto-radial-menu">
            <div class="radial-glass-disc">
                <div class="radial-outer-ring"></div>
                <!-- Badge superior estilo Imagen 2 -->
                <div class="radial-top-badge" id="radial-top-badge">16</div>
                <button type="button" class="radial-close-btn" onclick="closeOdontoRadialMenu()" title="Cerrar">&times;</button>
                
                <!-- 5 Botones Radiales de Caras Anatómicas con Iconos de Diente -->
                <button type="button" class="radial-sector-btn" data-surface="occlusal" onclick="selectRadialSurface('occlusal')" title="Cara Oclusal">
                    <span class="sector-icon"><i class="bi bi-circle"></i></span>
                    <span class="sector-label">Oclusal</span>
                </button>
                <button type="button" class="radial-sector-btn" data-surface="mesial" onclick="selectRadialSurface('mesial')" title="Cara Mesial">
                    <span class="sector-icon"><i class="bi bi-arrow-right-short"></i></span>
                    <span class="sector-label">Mesial</span>
                </button>
                <button type="button" class="radial-sector-btn" data-surface="vestibular" onclick="selectRadialSurface('vestibular')" title="Cara Vestibular">
                    <span class="sector-icon"><i class="bi bi-arrow-down-right"></i></span>
                    <span class="sector-label">Vestibular</span>
                </button>
                <button type="button" class="radial-sector-btn" data-surface="lingual" onclick="selectRadialSurface('lingual')" title="Cara Lingual / Palatina">
                    <span class="sector-icon"><i class="bi bi-arrow-down-left"></i></span>
                    <span class="sector-label">Lingual</span>
                </button>
                <button type="button" class="radial-sector-btn" data-surface="distal" onclick="selectRadialSurface('distal')" title="Cara Distal">
                    <span class="sector-icon"><i class="bi bi-arrow-left-short"></i></span>
                    <span class="sector-label">Distal</span>
                </button>

                <!-- Núcleo Central: Pieza de Porcelana 3D Realista (Estilo Imagen 2) + Doble Clic para Diagnosticar -->
                <div class="radial-nucleus" id="odonto-radial-nucleus" ondblclick="triggerModalFromRadial()" onclick="handleNucleusSingleClick()" title="Doble clic para abrir opciones clínicas">
                    <img src="${getToothImgPath('tooth_upright_16.png')}" class="radial-nucleus-porcelain-img" id="radial-nucleus-porcelain" alt="Pieza Dental 3D" onerror="if(!this.dataset.fallback){this.dataset.fallback=1; this.src='../img/teeth/tooth_upright_16.png';}" />
                    <div class="radial-finding-spot" id="radial-finding-spot"></div>
                    <span class="nucleus-surface-name" id="radial-nucleus-surface">OCLUSAL</span>
                    <span class="nucleus-action-hint">2x Clic Abrir</span>
                </div>
            </div>
        </div>
    `;

    document.body.insertAdjacentHTML('beforeend', radialHtml);

    // Cerrar al hacer clic fuera del menú radial
    document.addEventListener('click', function(e) {
        const menu = document.getElementById('odonto-radial-menu');
        if (!menu || !menu.classList.contains('active')) return;
        if (!menu.contains(e.target) && !e.target.closest('.tooth-card') && !e.target.closest('.tooth-surface') && !e.target.closest('.tooth-porcelain-morphology')) {
            closeOdontoRadialMenu();
        }
    });

    // Cerrar al presionar tecla ESC
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeOdontoRadialMenu();
        }
    });
}

/**
 * Abre el menú radial flotante centrado sobre la pieza dental seleccionada
 */
window.openOdontoRadialMenu = function(toothId, initialSurface, event) {
    initOdontoRadialMenu();

    const menu = document.getElementById('odonto-radial-menu');
    if (!menu) return;

    currentRadialTooth = String(toothId);
    currentRadialSurface = String(initialSurface || 'occlusal').toLowerCase();

    // Localizar tarjeta dental para posicionar el popup circular directamente encima
    const card = document.querySelector(`.tooth-card[data-tooth="${currentRadialTooth}"]`);
    if (card) {
        const rect = card.getBoundingClientRect();
        const centerX = rect.left + (rect.width / 2) + window.scrollX;
        const centerY = rect.top + (rect.height / 2) + window.scrollY;

        menu.style.left = `${centerX}px`;
        menu.style.top = `${centerY}px`;
    } else if (event) {
        menu.style.left = `${event.pageX}px`;
        menu.style.top = `${event.pageY}px`;
    }

    updateRadialMenuUI();
    menu.classList.add('active');
};

/**
 * Actualiza los elementos del menú radial (botón activo, textos del núcleo y preview)
 */
function updateRadialMenuUI() {
    const topBadge = document.getElementById('radial-top-badge');
    const surfEl = document.getElementById('radial-nucleus-surface');
    const toothImg = document.getElementById('radial-nucleus-porcelain');
    const spotEl = document.getElementById('radial-finding-spot');

    if (topBadge) topBadge.textContent = currentRadialTooth || '16';
    if (surfEl) surfEl.textContent = currentRadialSurface.toUpperCase();
    if (toothImg && currentRadialTooth) {
        toothImg.src = getToothImgPath(`tooth_upright_${currentRadialTooth}.png`);
        toothImg.onerror = function() {
            if (!this.dataset.fallback) {
                this.dataset.fallback = '1';
                this.src = `../img/teeth/tooth_upright_${currentRadialTooth}.png`;
            }
        };
    }

    // Actualizar botones de cara activa
    document.querySelectorAll('.radial-sector-btn').forEach(btn => {
        if (btn.getAttribute('data-surface') === currentRadialSurface) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    // Posición del resplandor del hallazgo en el núcleo según cara
    if (spotEl) {
        const spotPositions = {
            occlusal: { top: '30%', left: '50%', transform: 'translate(-50%, -50%)' },
            mesial: { top: '48%', left: '72%', transform: 'translate(-50%, -50%)' },
            distal: { top: '48%', left: '28%', transform: 'translate(-50%, -50%)' },
            vestibular: { top: '44%', left: '50%', transform: 'translate(-50%, -50%)' },
            lingual: { top: '36%', left: '50%', transform: 'translate(-50%, -50%)' }
        };
        const pos = spotPositions[currentRadialSurface] || spotPositions.occlusal;
        spotEl.style.top = pos.top;
        spotEl.style.left = pos.left;
        spotEl.style.transform = pos.transform;

        // Comprobar si tiene condición en esa superficie
        const sData = window.odontogramState?.teeth?.[currentRadialTooth]?.surfaces?.[currentRadialSurface];
        if (sData) {
            const color = sData.colorHex || (sData.state === 'PENDING_TREATMENT' ? '#FF3B30' : '#007AFF');
            spotEl.style.background = `radial-gradient(circle, ${color} 20%, ${color}B3 60%, transparent 100%)`;
            spotEl.style.boxShadow = `0 0 16px ${color}`;
            spotEl.classList.add('active');
        } else {
            // Resplandor cian suave indicador de cara activa
            spotEl.style.background = `radial-gradient(circle, #00E5FF 20%, rgba(0, 229, 255, 0.4) 60%, transparent 100%)`;
            spotEl.style.boxShadow = `0 0 12px rgba(0, 229, 255, 0.8)`;
            spotEl.classList.add('active');
        }
    }
}

/**
 * Selecciona una cara desde los botones radiales
 */
window.selectRadialSurface = function(surface) {
    currentRadialSurface = String(surface).toLowerCase();
    updateRadialMenuUI();
};

/**
 * Cierra el menú radial
 */
window.closeOdontoRadialMenu = function() {
    const menu = document.getElementById('odonto-radial-menu');
    if (menu) menu.classList.remove('active');
};

/**
 * Maneja el clic simple en el núcleo (da feedback y abre si es touch/segundo clic rápido)
 */
let lastNucleusClick = 0;
function handleNucleusSingleClick() {
    const now = Date.now();
    if (now - lastNucleusClick < 350) {
        // Doble clic detectado
        triggerModalFromRadial();
        return;
    }
    lastNucleusClick = now;
}

/**
 * Abre el modal clínico contextual a partir de la selección en el Puente Circular
 */
window.triggerModalFromRadial = function() {
    if (!currentRadialTooth) return;
    const tooth = currentRadialTooth;
    const surface = currentRadialSurface;
    closeOdontoRadialMenu();
    window.openOdontoClinicalModal(tooth, surface);
};

/**
 * Asigna los manejadores de eventos sobre cada cara vectorial y diente
 */
function attachSurfaceClickEvents(container) {
    // Inicializar el Puente Circular si aún no existe en el DOM
    initOdontoRadialMenu();

    // Clic en superficie anatómica -> Abre el Puente Circular posicionado en la pieza
    const surfaces = container.querySelectorAll('.tooth-surface');
    surfaces.forEach(surfaceEl => {
        surfaceEl.addEventListener('click', function(e) {
            e.stopPropagation();
            const tooth = this.getAttribute('data-tooth');
            const surface = this.getAttribute('data-surface');
            openOdontoRadialMenu(tooth, surface, e);
        });
    });

    // Clic en número o tarjeta dental -> Abre el Puente Circular en la pieza (oclusal por defecto)
    const cards = container.querySelectorAll('.tooth-card');
    cards.forEach(cardEl => {
        const numEl = cardEl.querySelector('.tooth-number');
        if (numEl) {
            numEl.addEventListener('click', function(e) {
                e.stopPropagation();
                const tooth = cardEl.getAttribute('data-tooth');
                openOdontoRadialMenu(tooth, 'occlusal', e);
            });
        }
        cardEl.addEventListener('click', function(e) {
            // Si el clic fue directamente a la tarjeta o raíz y no en una cara
            if (e.target.classList.contains('tooth-surface')) return;
            const tooth = cardEl.getAttribute('data-tooth');
            openOdontoRadialMenu(tooth, 'occlusal', e);
        });
    });
}

/**
 * ==========================================================================
 * CONTROLADOR DEL MODAL CLÍNICO CONTEXTUAL GLASSMORPHISM (FASE 1.2 / 2 UI)
 * ==========================================================================
 */

/**
 * Abre el Modal Clínico contextual con datos de la pieza y superficie seleccionada
 */
window.openOdontoClinicalModal = function(toothId, surface) {
    toothId = String(toothId);
    surface = String(surface || 'occlusal').toLowerCase();

    window.odontoModalContext.tooth = toothId;
    window.odontoModalContext.surface = surface;
    window.odontoModalContext.scope = 'SURFACE';
    window.odontoModalContext.selectedCondition = 'CARIES';

    const modalEl = document.getElementById('modalOdontoClinico');
    if (!modalEl) return;

    // Actualizar encabezados
    const badgeEl = document.getElementById('odonto-modal-tooth-badge');
    const titleEl = document.getElementById('odonto-modal-tooth-title');
    const surfaceLabelEl = document.getElementById('odonto-modal-surface-label');

    if (badgeEl) badgeEl.textContent = `#${toothId}`;
    if (titleEl) titleEl.textContent = getToothFullName(toothId);
    if (surfaceLabelEl) {
        surfaceLabelEl.innerHTML = `<i class="bi bi-geo-alt-fill text-teal me-1" style="color: var(--md-teal-clinical);"></i>Zona activa: Superficie <strong class="text-uppercase">${surface}</strong>`;
    }

    // Reset de botones de alcance
    const scopeSurfaceRadio = document.getElementById('scope-surface');
    if (scopeSurfaceRadio) scopeSurfaceRadio.checked = true;
    const labelScopeSurface = document.getElementById('label-scope-surface');
    if (labelScopeSurface) labelScopeSurface.innerHTML = `<i class="bi bi-bounding-box me-1"></i>Superficie (${surface.toUpperCase()})`;

    // Resetear a pestaña Pendiente
    const pendingTabBtn = document.getElementById('pills-pending-tab');
    if (pendingTabBtn) {
        bootstrap.Tab.getOrCreateInstance(pendingTabBtn).show();
    }

    // Renderizar grilla de opciones en las pestañas
    renderModalConditionGrids();

    // Seleccionar por defecto la primera condición
    window.selectOdontoCondition('CARIES');

    // Desplegar modal (garantizar que resida directamente en document.body para evitar trampas de apilamiento)
    if (modalEl && modalEl.parentNode !== document.body) {
        document.body.appendChild(modalEl);
    }
    const modalInstance = bootstrap.Modal.getOrCreateInstance(modalEl);
    modalInstance.show();
};

/**
 * Renderiza dinámicamente las tarjetas de opciones clínicas en el modal
 */
function renderModalConditionGrids() {
    const gridPending = document.getElementById('grid-conditions-pending');
    const gridExisting = document.getElementById('grid-conditions-existing');
    const gridHealthy = document.getElementById('grid-conditions-healthy');

    // GRUPO 1: PATOLOGÍA / HALLAZGO (Rojo Neón)
    if (gridPending) {
        let htmlP = '';
        Object.values(ODONTO_CATALOG).filter(c => c.group === 'PATHOLOGY').forEach(item => {
            htmlP += `
                <div class="col-md-6">
                    <div class="odonto-condition-card" data-code="${item.code}" onclick="selectOdontoCondition('${item.code}')">
                        <div class="d-flex align-items-center gap-2">
                            <span class="odonto-condition-badge" style="background: ${item.colorHex};"></span>
                            <span class="small fw-bold text-navy">${item.name}</span>
                        </div>
                        ${item.price > 0 ? `<span class="badge bg-danger-subtle text-danger rounded-pill px-2 py-1 fw-bold" style="font-size: 0.7rem;">$${item.price.toFixed(2)}</span>` : `<span class="badge bg-secondary-subtle text-secondary rounded-pill px-2 py-1 fw-bold" style="font-size: 0.7rem;">Ausente</span>`}
                    </div>
                </div>
            `;
        });
        gridPending.innerHTML = htmlP;
    }

    // GRUPO 2: ESTADO DE TRATAMIENTO / RESTAURACIÓN (Azul Adaptada / Ámbar Desadaptada)
    if (gridExisting) {
        let htmlE = '';
        Object.values(ODONTO_CATALOG).filter(c => c.group === 'RESTORATION').forEach(item => {
            let badgeHtml = '';
            if (item.substatus === 'DEFECTIVE') {
                badgeHtml = `<span class="badge bg-warning-subtle text-warning-emphasis rounded-pill px-2 py-1 fw-bold" style="font-size: 0.7rem;">Desadaptada ($${item.price.toFixed(2)})</span>`;
            } else if (item.substatus === 'TEMPORARY') {
                badgeHtml = `<span class="badge bg-warning-subtle text-warning-emphasis rounded-pill px-2 py-1 fw-bold" style="font-size: 0.7rem;">Provisional ($${item.price.toFixed(2)})</span>`;
            } else if (item.substatus === 'PONTIC') {
                badgeHtml = `<span class="badge bg-info-subtle text-info-emphasis rounded-pill px-2 py-1 fw-bold" style="font-size: 0.7rem;">Póntico ($${item.price.toFixed(2)})</span>`;
            } else {
                badgeHtml = `<span class="badge bg-primary-subtle text-primary rounded-pill px-2 py-1 fw-bold" style="font-size: 0.7rem;">Adaptada</span>`;
            }

            htmlE += `
                <div class="col-md-6">
                    <div class="odonto-condition-card" data-code="${item.code}" onclick="selectOdontoCondition('${item.code}')">
                        <div class="d-flex align-items-center gap-2">
                            <span class="odonto-condition-badge" style="background: ${item.colorHex};"></span>
                            <span class="small fw-bold text-navy">${item.name}</span>
                        </div>
                        ${badgeHtml}
                    </div>
                </div>
            `;
        });
        gridExisting.innerHTML = htmlE;
    }

    // GRUPO 3: ESTADO NORMAL (Verde / Sin Hallazgo)
    if (gridHealthy) {
        let htmlH = '';
        Object.values(ODONTO_CATALOG).filter(c => c.group === 'NORMAL').forEach(item => {
            htmlH += `
                <div class="col-md-6">
                    <div class="odonto-condition-card" data-code="${item.code}" onclick="selectOdontoCondition('${item.code}')">
                        <div class="d-flex align-items-center gap-2">
                            <span class="odonto-condition-badge" style="background: ${item.colorHex}; border: 1px solid #cbd5e1;"></span>
                            <span class="small fw-bold text-navy">${item.name}</span>
                        </div>
                        <span class="badge bg-success-subtle text-success rounded-pill px-2 py-1 fw-bold" style="font-size: 0.7rem;">Normal</span>
                    </div>
                </div>
            `;
        });
        gridHealthy.innerHTML = htmlH;
    }
}

/**
 * Selecciona una condición clínica y actualiza el resumen del modal
 */
window.selectOdontoCondition = function(code) {
    const item = ODONTO_CATALOG[code];
    if (!item) return;

    window.odontoModalContext.selectedCondition = code;

    // Resaltar tarjeta activa
    document.querySelectorAll('.odonto-condition-card').forEach(card => {
        if (card.getAttribute('data-code') === code) {
            card.classList.add('active');
        } else {
            card.classList.remove('active');
        }
    });

    // Actualizar resumen y precio
    const summaryCond = document.getElementById('odonto-summary-condition');
    const summaryScope = document.getElementById('odonto-summary-scope');
    const summaryPrice = document.getElementById('odonto-summary-price');

    if (summaryCond) summaryCond.textContent = item.name;
    
    if (summaryScope) {
        const scope = window.odontoModalContext.scope;
        if (scope === 'SURFACE') {
            summaryScope.textContent = `Superficie ${window.odontoModalContext.surface.toUpperCase()}`;
            summaryScope.className = 'badge bg-danger-subtle text-danger ms-2 rounded-pill px-2 py-1';
        } else if (scope === 'CROWN') {
            summaryScope.textContent = 'Toda la Corona (5 Caras)';
            summaryScope.className = 'badge bg-warning-subtle text-warning-emphasis ms-2 rounded-pill px-2 py-1';
        } else {
            summaryScope.textContent = 'Pieza Completa';
            summaryScope.className = 'badge bg-secondary-subtle text-secondary ms-2 rounded-pill px-2 py-1';
        }
    }

    if (summaryPrice) {
        summaryPrice.textContent = `$${item.price.toFixed(2)} MXN`;
    }
};

/**
 * Maneja el cambio de alcance (Superficie vs Corona vs Diente)
 */
window.handleScopeChange = function(newScope) {
    window.odontoModalContext.scope = newScope;
    window.selectOdontoCondition(window.odontoModalContext.selectedCondition);
};

/**
 * Aplica el diagnóstico seleccionado desde el modal al Odontograma y al Estado
 */
window.confirmApplyClinicalCondition = function() {
    const ctx = window.odontoModalContext;
    const tooth = String(ctx.tooth);
    const surface = String(ctx.surface);
    const condition = ODONTO_CATALOG[ctx.selectedCondition];

    if (!tooth || !condition) return;

    // Si es estado SANO / LIMPIAR
    if (condition.code === 'HEALTHY') {
        const card = document.querySelector(`.tooth-card[data-tooth="${tooth}"]`);
        if (card) {
            card.classList.remove('tooth-absent', 'tooth-extraction-req', 'tooth-endo-pending', 'tooth-endo-done');
        }

        if (ctx.scope === 'SURFACE') {
            removeSurfaceCondition(tooth, surface);
        } else {
            // Limpiar toda la corona y pieza
            ['occlusal', 'vestibular', 'lingual', 'mesial', 'distal'].forEach(s => {
                removeSurfaceCondition(tooth, s);
            });
            if (window.odontogramState.teeth[tooth]) {
                window.odontogramState.teeth[tooth].status = 'PRESENT';
                delete window.odontogramState.teeth[tooth].absent;
            }
        }
    } 
    // Si es DIENTE AUSENTE / EXODONCIA
    else if (condition.code === 'ABSENT' || condition.code === 'EXTRACTION_REQ' || ctx.scope === 'TOOTH') {
        if (!window.odontogramState.teeth[tooth]) {
            window.odontogramState.teeth[tooth] = { status: 'PRESENT', surfaces: {} };
        }
        window.odontogramState.teeth[tooth].status = (condition.code === 'ABSENT') ? 'ABSENT' : 'EXTRACTION_REQUIRED';
        
        const card = document.querySelector(`.tooth-card[data-tooth="${tooth}"]`);
        if (card) {
            card.classList.remove('tooth-absent', 'tooth-extraction-req', 'tooth-endo-pending', 'tooth-endo-done');
            if (condition.code === 'EXTRACTION_REQ') {
                card.classList.add('tooth-extraction-req');
            } else {
                card.classList.add('tooth-absent');
            }
        }

        if (condition.code === 'EXTRACTION_REQ') {
            window.applySurfaceCondition(tooth, 'occlusal', condition.code, condition.state, condition.colorHex, condition.price);
        }
    }
    // Si es ENDODONCIA (Indicada o Realizada - Efecto sobre Raíz / Conducto Central)
    else if (condition.code === 'ENDO_REQ' || condition.code === 'ENDO_DONE') {
        const card = document.querySelector(`.tooth-card[data-tooth="${tooth}"]`);
        if (card) {
            card.classList.remove('tooth-endo-pending', 'tooth-endo-done');
            if (condition.code === 'ENDO_REQ') {
                card.classList.add('tooth-endo-pending');
            } else {
                card.classList.add('tooth-endo-done');
            }
        }
        window.applySurfaceCondition(tooth, 'occlusal', condition.code, condition.state, condition.colorHex, condition.price);
    }
    // Si es TODA LA CORONA (ej. Corona Protésica)
    else if (ctx.scope === 'CROWN') {
        const perSurfacePrice = (condition.price > 0) ? (condition.price / 5) : 0;
        ['occlusal', 'vestibular', 'lingual', 'mesial', 'distal'].forEach(s => {
            window.applySurfaceCondition(tooth, s, condition.code, condition.state, condition.colorHex, perSurfacePrice);
        });
    }
    // Si es SUPERFICIE INDIVIDUAL
    else {
        window.applySurfaceCondition(tooth, surface, condition.code, condition.state, condition.colorHex, condition.price);
    }

    recalculateFinancialTotal();
    updateLiveJsonViewer();

    // Cerrar modal
    const modalEl = document.getElementById('modalOdontoClinico');
    if (modalEl) {
        bootstrap.Modal.getInstance(modalEl)?.hide();
    }

    // Feedback visual
    if (typeof Swal !== 'undefined') {
        const Toast = Swal.mixin({
            toast: true,
            position: 'top-end',
            showConfirmButton: false,
            timer: 2000,
            timerProgressBar: true
        });
        Toast.fire({
            icon: condition.code === 'HEALTHY' ? 'info' : 'success',
            title: `Pieza #${tooth} actualizada: ${condition.name}`
        });
    }
};

/**
 * ==========================================================================
 * APLICACIÓN DE ESTADO Y CONDICIÓN CLÍNICA SOBRE EL DOM Y MEMORIA
 * ==========================================================================
 */

/**
 * Aplica una condición clínica y color a una superficie dental
 */
window.applySurfaceCondition = function(tooth, surface, code, state, colorHex, price) {
    tooth = String(tooth);
    surface = String(surface).toLowerCase();
    
    if (!colorHex) {
        colorHex = (state === 'PENDING_TREATMENT') ? ODONTO_COLORS.PENDING : ODONTO_COLORS.COMPLETED;
    }

    if (price === undefined || price === null) {
        price = (state === 'PENDING_TREATMENT') ? 850.00 : 0.00;
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
        price: parseFloat(price) || 0.00
    };

    window.odontogramState.updatedAt = new Date().toISOString();

    // Actualizar DOM SVG con estilo directo y clases con !important
    const surfaceEl = document.querySelector(`.tooth-surface[data-tooth="${tooth}"][data-surface="${surface}"]`);
    if (surfaceEl) {
        const catObj = window.ODONTO_CATALOG ? window.ODONTO_CATALOG[code] : null;
        const isDefective = (catObj?.substatus === 'DEFECTIVE') || (colorHex === '#FF9500');

        surfaceEl.style.fill = colorHex;
        surfaceEl.setAttribute('fill', colorHex);
        surfaceEl.setAttribute('data-state', state);
        surfaceEl.classList.add('has-condition');
        surfaceEl.classList.remove('surface-pending', 'surface-completed', 'surface-defective');
        if (isDefective) {
            surfaceEl.classList.add('surface-defective');
        } else if (state === 'PENDING_TREATMENT') {
            surfaceEl.classList.add('surface-pending');
        } else {
            surfaceEl.classList.add('surface-completed');
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

    document.querySelectorAll('.tooth-card').forEach(card => {
        card.classList.remove('tooth-absent', 'tooth-extraction-req', 'tooth-endo-pending', 'tooth-endo-done');
    });

    document.querySelectorAll('.tooth-surface').forEach(el => {
        el.style.fill = '';
        el.setAttribute('fill', ODONTO_COLORS.NEUTRAL);
        el.removeAttribute('data-state');
        el.classList.remove('has-condition', 'surface-pending', 'surface-completed');
    });

    recalculateFinancialTotal();
    updateLiveJsonViewer();

    if (typeof Swal !== 'undefined') {
        Swal.fire({
            icon: 'info',
            title: 'Odontograma Limpio',
            text: 'Se han reiniciado las marcas y el presupuesto.',
            timer: 1500,
            showConfirmButton: false
        });
    }
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
