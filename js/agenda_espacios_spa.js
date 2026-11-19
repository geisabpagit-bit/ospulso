document.addEventListener('spa:contentLoaded', function() {
    if (document.querySelector('.main-container-agenda')) {
        if (typeof initClock === 'function') initClock();
        if (typeof loadFormMetadata === 'function') loadFormMetadata();
        if (typeof loadContext === 'function') loadContext();
        if (window.location.search.includes('open_settings=1')) {
            if (typeof abrirModalAjustes === 'function') setTimeout(abrirModalAjustes, 300);
        }
        
        // [SDM FIX] DOM Teleportation Protocol
        var modalCita = document.getElementById('modalCita');
        if (modalCita) {
            document.querySelectorAll('body > #modalCita').forEach(m => { if (m !== modalCita) m.remove(); });
            document.body.appendChild(modalCita);
        }
        var modalAjustes = document.getElementById('modalAjustes');
        if (modalAjustes) {
            document.querySelectorAll('body > #modalAjustes').forEach(m => { if (m !== modalAjustes) m.remove(); });
            document.body.appendChild(modalAjustes);
        }
        var quickModal = document.getElementById('appointmentQuickModal');
        if (quickModal) {
            document.querySelectorAll('body > #appointmentQuickModal').forEach(m => { if (m !== quickModal) m.remove(); });
            document.body.appendChild(quickModal);
        }
        
        switchView('calendario');
    }
});
// --- SDM AGENDA SPA ENGINE v1.5.0 [Estable 2026-04-14 16:35] ---
var CrystalToast = CrystalToast || (typeof Swal !== 'undefined' ? Swal.mixin({
    toast: true, position: 'top-end', showConfirmButton: false, timer: 3000, 
    timerProgressBar: true,
    didOpen: (t) => { t.addEventListener('mouseenter', Swal.stopTimer); t.addEventListener('mouseleave', Swal.resumeTimer); }
}) : null);

var selectedDate = selectedDate || new Date();
var appointments = appointments || [];
var agendaConfig = agendaConfig || {};
var currentView = currentView || 'mes';
var duracionCita = duracionCita || 30;
var tableInstance = tableInstance || null;
var draggedId = draggedId || null;
var manualDragId = manualDragId || null; // Para modo Doble Clic (Regla Smart-Drag)

/**
 * Normalización Canónica Universal de Espacios Físicos (Consultorios y Quirófanos)
 * Elimina acentos/tildes diacríticas y homologa sinónimos operativos (ej: 'Quirófano 1' <=> 'quirofano 1' <=> 'qx 1')
 */
function normalizarTextoEspacio(txt) {
    if (!txt) return '';
    return String(txt)
        .toLowerCase()
        .normalize("NFD").replace(/[\u0300-\u036f]/g, "") // quita tildes: ó -> o, etc.
        .replace(/[^a-z0-9]/g, ' ')                        // 1º convierte guiones bajos y símbolos a espacios
        .replace(/\bquirofanos?\b/g, 'qx')                  // 2º normaliza quirofano a qx
        .replace(/\bconsultorios?\b/g, 'cons')              // 3º normaliza consultorio a cons
        .replace(/\s+/g, ' ')
        .trim();
}

// --- DICCIONARIO CANÓNICO DE ESTADOS DE RENTA DE ESPACIOS ---
const ESTADOS_CITAS_CONFIG = {
    'reservada': {
        clave: 'Reservada',
        color: '#991B1B',
        bgCard: '#FEF2F2',
        textColor: '#991B1B',
        badgeClass: 'bg-danger text-white',
        border: '#991B1B'
    },
    'programada': {
        clave: 'Reservada',
        color: '#991B1B',
        bgCard: '#FEF2F2',
        textColor: '#991B1B',
        badgeClass: 'bg-danger text-white',
        border: '#991B1B'
    },
    'confirmada': {
        clave: 'Confirmada',
        color: '#EAB308',
        bgCard: '#FEF9C3',
        textColor: '#854D0E',
        badgeClass: 'bg-warning text-dark',
        border: '#EAB308'
    },
    'en uso': {
        clave: 'En Uso',
        color: '#059669',
        bgCard: '#DCFCE7',
        textColor: '#166534',
        badgeClass: 'bg-success text-white',
        border: '#059669'
    },
    'en consulta': {
        clave: 'En Uso',
        color: '#059669',
        bgCard: '#DCFCE7',
        textColor: '#166534',
        badgeClass: 'bg-success text-white',
        border: '#059669'
    },
    'consulta en proceso': {
        clave: 'En Uso',
        color: '#059669',
        bgCard: '#DCFCE7',
        textColor: '#166534',
        badgeClass: 'bg-success text-white',
        border: '#059669'
    },
    'finalizada': {
        clave: 'Finalizada',
        color: '#064E3B',
        bgCard: '#D1FAE5',
        textColor: '#064E3B',
        badgeClass: 'bg-dark text-white',
        border: '#064E3B'
    },
    'atendida': {
        clave: 'Finalizada',
        color: '#064E3B',
        bgCard: '#D1FAE5',
        textColor: '#064E3B',
        badgeClass: 'bg-dark text-white',
        border: '#064E3B'
    },
    'ocupado (pacientes)': {
        clave: 'Ocupado (Pacientes)',
        color: '#0284C7',
        bgCard: '#E0F2FE',
        textColor: '#0369A1',
        badgeClass: 'bg-info text-white',
        border: '#0284C7'
    },
    'no realizada': {
        clave: 'No realizada',
        color: '#64748B',
        bgCard: '#F1F5F9',
        textColor: '#475569',
        badgeClass: 'bg-secondary text-white text-decoration-line-through badge-no-realizada',
        border: '#94A3B8'
    },
    'cancelada': {
        clave: 'Cancelada',
        color: '#DC2626',
        bgCard: '#FEE2E2',
        textColor: '#991B1B',
        badgeClass: 'bg-danger text-white text-decoration-line-through',
        border: '#FCA5A5'
    }
};

function resolverEstadoCita(estadoRaw, fechaIso, horaFinStr) {
    let raw = (estadoRaw || 'Reservada').trim();
    let low = raw.toLowerCase();

    if (low.includes('ocupado')) {
        const cfgO = ESTADOS_CITAS_CONFIG['ocupado (pacientes)'];
        return {
            clave: cfgO.clave, color: cfgO.color, bgCard: cfgO.bgCard, textColor: cfgO.textColor,
            badgeClass: cfgO.badgeClass, border: cfgO.border,
            esNoRealizada: false, esAtendida: true, esCancelada: false, esEnConsulta: false, esBloqueoPacientes: true
        };
    }

    if (low.includes('pagada')) low = 'confirmada';
    if (low.includes('uso') || low.includes('proceso') || low.includes('en consulta')) low = 'en uso';
    if (low.includes('finalizada') || low.includes('atendida')) low = 'finalizada';

    const esActivaEnUso = (low === 'en uso');
    const todayIso = (typeof getISO === 'function') ? getISO(new Date()) : new Date().toISOString().split('T')[0];
    const now = new Date();
    const nowHHMM = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

    if (!low.includes('finalizada') && !low.includes('cancelada')) {
        const esFechaPasada = fechaIso && fechaIso < todayIso;
        const esHoraPasadaHoy = (fechaIso === todayIso && horaFinStr && horaFinStr < nowHHMM && !esActivaEnUso);
        if (esFechaPasada || esHoraPasadaHoy) {
            low = 'no realizada';
            raw = 'No realizada';
        }
    }

    const cfg = ESTADOS_CITAS_CONFIG[low] || ESTADOS_CITAS_CONFIG['reservada'];
    return {
        clave: (low === 'no realizada') ? 'No realizada' : (cfg.clave || raw),
        color: cfg.color,
        bgCard: cfg.bgCard,
        textColor: cfg.textColor,
        badgeClass: cfg.badgeClass,
        border: cfg.border,
        esNoRealizada: low === 'no realizada',
        esAtendida: low === 'finalizada',
        esCancelada: low === 'cancelada',
        esEnConsulta: esActivaEnUso
    };
}

/**
 * Vista Semanal Smart (Image 3 Style)
 */
function renderWeeklySmartView() {
    const scroll = $("#weekly-smart-scroll");
    const slotsCont = $("#weekly-smart-slots");
    scroll.empty(); slotsCont.empty();

    const todayISO = getISO(new Date());
    const selISO = getISO(selectedDate);

    // Calcular el Lunes de la semana activa correspondiente a selectedDate
    const dObj = new Date(selectedDate);
    const dayOfWeek = dObj.getDay(); // 0 = Domingo, 1 = Lunes, ..., 6 = Sábado
    const diffToMonday = (dayOfWeek === 0) ? -6 : (1 - dayOfWeek);
    const monday = new Date(dObj);
    monday.setDate(dObj.getDate() + diffToMonday);
    monday.setHours(12, 0, 0, 0);

    scroll.removeClass('justify-content-start justify-content-center').addClass('justify-content-center');

    // 7 días exactos: Lunes a Domingo
    for (let i = 0; i < 7; i++) {
        const d = new Date(monday);
        d.setDate(monday.getDate() + i);
        const iso = getISO(d);
        const active = (iso === selISO);
        const holiday = isHoliday(iso);
        const isToday = (iso === todayISO);
        const dayName = d.toLocaleDateString('es-ES', { weekday: 'short' }).replace('.', '').toUpperCase();
        const dayNum = d.getDate();

        // Conteo de citas del día para visibilidad inmediata (respetando filtros activos)
        const dayAptsCount = getFilteredAppointments().filter(a => a.start && a.start.startsWith(iso)).length;
        const countBadge = dayAptsCount > 0 
            ? `<span class="badge rounded-pill ${active ? 'bg-white text-dark' : 'bg-teal text-white'} fw-bold shadow-xs" style="font-size:0.58rem; margin-top:3px; padding:2px 6px;">${dayAptsCount} cita${dayAptsCount > 1 ? 's' : ''}</span>`
            : (isToday && !active ? '<div style="width:6px; height:6px; background:var(--md-teal-clinical, #19B7A5); border-radius:50%; margin-top:5px;"></div>' : '<div style="height:11px"></div>');

        const card = $(`
            <div class="smart-day-card card-acrilico ${active ? 'active' : ''} ${holiday ? 'holiday' : ''}" 
                 onclick="selectSmartDate('${iso}')"
                 style="flex: 0 0 auto; cursor: pointer;">
                <span class="small text-uppercase fw-bold ${active ? 'text-white' : 'opacity-50'}" style="font-size:0.6rem;">${dayName}</span>
                <span class="h4 fw-black m-0">${dayNum}</span>
                ${countBadge}
            </div>
        `);
        scroll.append(card);
    }
    renderSmartSlots(selISO);
}

function selectSmartDate(iso) {
    selectedDate = new Date(iso + 'T12:00:00');
    renderHeaders();
    renderWeeklySmartView();
}

function renderSmartSlots(date) {
    const cont = $("#weekly-smart-slots");
    cont.empty();
    
    if (!isWorkDay(date)) {
        cont.append('<div class="col-12 text-center p-5 opacity-50"><i class="bi bi-calendar-x h1 d-block mb-3"></i><h5 class="fw-bold">Día No Laborable</h5></div>');
        return;
    }
    
    if (isHoliday(date)) {
        cont.append('<div class="col-12 text-center p-5 opacity-50"><i class="bi bi-calendar-x h1 d-block mb-3"></i><h5 class="fw-bold">Este día es festivo o asueto.</h5></div>');
        return;
    }

    const lStart = agendaConfig.laborStart || '08:00';
    const lEnd = agendaConfig.laborEnd || '18:00';
    const [lsH, lsM] = lStart.split(':').map(Number);
    const [leH, leM] = lEnd.split(':').map(Number);
    const s = lsH || 0;
    let e = leH || 18;
    if (e <= s || (leH === 23 && leM >= 50) || lEnd === '23:59' || lEnd === '24:00') {
        e = 24;
    }
    const laborTotalMin = (leH * 60 + (leM || 0)) - (lsH * 60 + (lsM || 0));

    const interval = parseInt(agendaConfig.intervalo_minutos) || 30;
    const dayApts = getFilteredAppointments().filter(a => a.start && a.start.startsWith(date));

    const now = new Date();
    const todayISO = getISO(now);
    const currentHHMM = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

    const matchedAptIds = new Set();

    // 1. Detección Inteligente de Citas de Día Completo / Jornada Completa
    const allDayApts = dayApts.filter(a => {
        const aHi = a.start.split('T')[1].substring(0, 5);
        const aHf = a.end.split('T')[1].substring(0, 5);
        const [aH1, aM1] = aHi.split(':').map(Number);
        const [aH2, aM2] = aHf.split(':').map(Number);
        const durMin = (aH2 * 60 + (aM2 || 0)) - (aH1 * 60 + (aM1 || 0));
        
        // Abarca toda la jornada laboral o duración >= total jornada - 30m o >= 6 horas o motivo explícito
        const cubreJornada = (aHi <= lStart && aHf >= lEnd);
        const esCasiJornada = (durMin >= (laborTotalMin - 30));
        const esJornadaLarga = (durMin >= 360 && aHi <= '09:00' && aHf >= '17:00');
        const motivoTodoDia = (a.extendedProps && a.extendedProps.motivo && /todo el d|jornada completa|dia completo|día completo/i.test(a.extendedProps.motivo));
        
        return cubreJornada || esCasiJornada || esJornadaLarga || motivoTodoDia;
    });

    // Renderizar Hero Card para Citas de Día Completo al inicio
    if (allDayApts.length > 0) {
        allDayApts.forEach(apt => {
            matchedAptIds.add(apt.id);
            const aHi = apt.start.split('T')[1].substring(0, 5);
            const aHf = apt.end.split('T')[1].substring(0, 5);
            const [aH1, aM1] = aHi.split(':').map(Number);
            const [aH2, aM2] = aHf.split(':').map(Number);
            const durMin = (aH2 * 60 + (aM2 || 0)) - (aH1 * 60 + (aM1 || 0));
            const durHoras = (durMin / 60).toFixed(1).replace('.0', '');

            const res = resolverEstadoCita(apt.extendedProps?.estado, date, aHf);
            const esAtendida = res.esAtendida || res.clave.toLowerCase().includes('atendida');
            const esCancelada = res.esCancelada || res.clave.toLowerCase().includes('cancelada');
            const esEnConsulta = res.esEnConsulta || res.clave.toLowerCase().includes('proceso');
            const esTomable = (!esAtendida && !esCancelada && !esEnConsulta);

            const initials = apt.title.split(' ').filter(Boolean).map(n => n[0]).slice(0, 2).join('').toUpperCase() || 'P';
            const motivoTxt = apt.extendedProps?.motivo ? apt.extendedProps.motivo.trim() : '';
            const idPac = apt.extendedProps?.id_paciente || '';

            const heroCard = $(`
                <div class="col-12 mb-3">
                    <div class="card p-3 p-md-4 shadow-sm rounded-4 border-0 all-day-hero-card" 
                         style="background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%); border: 1.5px solid var(--md-teal-clinical, #19B7A5) !important;">
                        <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 pb-2.5 border-bottom border-light-subtle">
                            <div class="d-flex align-items-center gap-2 flex-wrap">
                                <span class="badge text-white px-2.5 py-1.5 rounded-pill fw-bold d-inline-flex align-items-center all-day-pill" style="background-color: var(--md-navy, #0A2A66); font-size: 0.72rem;">
                                    <i class="bi bi-sun-fill me-1 text-warning"></i> JORNADA COMPLETA
                                </span>
                                <span class="badge ${res.badgeClass} px-2.5 py-1.5 rounded-pill fw-bold" style="font-size: 0.72rem;">
                                    ${res.clave.toUpperCase()}
                                </span>
                                <span class="badge bg-light text-secondary border px-2.5 py-1.5 rounded-pill fw-medium" style="font-size: 0.72rem;">
                                    <i class="bi bi-clock me-1" style="color: var(--md-teal-clinical, #19B7A5);"></i> ${aHi} - ${aHf} (${durHoras} hrs)
                                </span>
                                ${apt.extendedProps?.consultorio ? `<span class="badge bg-light text-muted border px-2.5 py-1.5 rounded-pill small"><i class="bi bi-geo-alt me-0.5"></i> ${apt.extendedProps.consultorio}</span>` : ''}
                            </div>
                            <div class="d-flex align-items-center gap-1.5 flex-wrap">
                                ${esEnConsulta ? `
                                    <button type="button" class="btn btn-sm text-white rounded-pill px-3 py-1.5 fw-bold shadow-xs" style="font-size:0.75rem; background-color:#059669 !important;" onclick="event.stopPropagation(); window.location.href='render_consultas_privado.pl?id=${idPac}&id_cita=${apt.id}'" title="Ir a Consulta en Proceso">
                                        <i class="bi bi-play-fill me-1"></i> Ir a Consulta
                                    </button>
                                ` : (esTomable ? `
                                    <button type="button" class="btn btn-sm btn-success text-white rounded-pill px-3 py-1.5 fw-bold shadow-xs" style="font-size:0.75rem;" onclick="event.stopPropagation(); window.tomarCitaDirecto('${apt.id}', '${idPac}')" title="Tomar Cita Ahora">
                                        <i class="bi bi-play-fill me-1"></i> Tomar Cita
                                    </button>
                                ` : '')}
                                ${idPac ? `
                                    <a href="render_expediente.pl?id=${idPac}" class="btn btn-sm btn-outline-teal rounded-pill px-2.5 py-1.5 fw-medium" style="font-size:0.75rem;" title="Abrir Expediente Clínico">
                                        <i class="bi bi-folder2-open me-1"></i> Expediente
                                    </a>
                                ` : ''}
                                <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-2.5 py-1.5 fw-medium" style="font-size:0.75rem;" onclick="event.stopPropagation(); abrirModalCita('${apt.id}')" title="Re-agendar o Modificar">
                                    <i class="bi bi-pencil-square me-1"></i> Re-agendar
                                </button>
                                <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill px-2.5 py-1.5" style="font-size:0.75rem;" onclick="event.stopPropagation(); openAppointmentQuickDetail('${apt.id}')" title="Ver Detalle Rápido">
                                    <i class="bi bi-eye me-1"></i> Ver Detalle
                                </button>
                            </div>
                        </div>
                        <div class="d-flex align-items-center gap-3 pt-3">
                            <div class="all-day-avatar d-flex align-items-center justify-content-center text-white fw-bold rounded-circle shadow-xs flex-shrink-0" style="width: 44px; height: 44px; background: linear-gradient(135deg, var(--md-teal-clinical, #19B7A5), var(--md-navy, #0A2A66)); font-size: 1rem;">
                                ${initials}
                            </div>
                            <div class="flex-grow-1 min-w-0">
                                <div class="d-flex align-items-center gap-2 flex-wrap">
                                    <h5 class="mb-0 fw-bold text-navy text-truncate" style="font-size: 1.05rem;">${apt.title}</h5>
                                    ${idPac ? `<span class="badge bg-light text-secondary border small">EXP: #${idPac}</span>` : ''}
                                    ${apt.extendedProps?.prioridad && apt.extendedProps.prioridad !== 'Normal' ? `<span class="badge bg-warning-subtle text-warning-emphasis border border-warning small">${apt.extendedProps.prioridad}</span>` : ''}
                                </div>
                                ${motivoTxt ? `
                                    <p class="mb-0 mt-1 small text-muted text-truncate" title="${motivoTxt}">
                                        <i class="bi bi-chat-left-text me-1 text-teal"></i> <span class="fw-semibold text-dark">Motivo:</span> ${motivoTxt}
                                    </p>
                                ` : ''}
                            </div>
                        </div>
                    </div>
                </div>
            `);
            cont.append(heroCard);
        });
    }

    const sections = [
        { label: 'MAÑANA', start: s, end: 13, icon: 'bi-brightness-high-fill' },
        { label: 'TARDE', start: 13, end: e, icon: 'bi-moon-stars-fill' }
    ];

    sections.forEach(sec => {
        const col = $(`
            <div class="col-md-6 mb-3">
                <div class="card p-3 shadow-sm rounded-4 border-0 smart-slots-category-card" style="border: 1.5px solid var(--md-teal-clinical, #19B7A5) !important; background: rgba(255,255,255,0.7); backdrop-filter: blur(10px);">
                    <div class="slot-category-label mb-3">
                        <div class="slot-category-icon"><i class="bi ${sec.icon}"></i></div>
                        <span>${sec.label}</span>
                    </div>
                    <div class="row g-2" id="smart-slots-${sec.label}"></div>
                </div>
            </div>
        `);
        cont.append(col);
        const inner = col.find(`#smart-slots-${sec.label}`);

        // Si hay una cita de todo el día que cubre este turno completo, renderizamos un banner elegante de turno cubierto
        const secAllDayCover = allDayApts.find(a => {
            const aHi = a.start.split('T')[1].substring(0, 5);
            const aHf = a.end.split('T')[1].substring(0, 5);
            const secHi = `${sec.start.toString().padStart(2, '0')}:00`;
            const secHf = `${sec.end.toString().padStart(2, '0')}:00`;
            return (aHi <= secHi && aHf >= secHf);
        });

        if (secAllDayCover) {
            inner.append(`
                <div class="col-12">
                    <div class="smart-shift-covered p-3 rounded-3 d-flex flex-wrap align-items-center justify-content-between gap-2" style="background: rgba(248, 250, 252, 0.85); border: 1.5px dashed #cbd5e1;">
                        <div class="d-flex align-items-center gap-2.5">
                            <div class="rounded-circle d-flex align-items-center justify-content-center bg-white shadow-xs" style="width:34px; height:34px; color: var(--md-navy, #0A2A66);">
                                <i class="bi bi-shield-lock-fill"></i>
                            </div>
                            <div>
                                <span class="d-block fw-bold text-navy small">Turno Cubierto por Jornada Completa</span>
                                <span class="d-block text-muted" style="font-size:0.75rem;">Asignado a: <strong>${secAllDayCover.title}</strong> (${sec.start.toString().padStart(2, '0')}:00 - ${sec.end.toString().padStart(2, '0')}:00)</span>
                            </div>
                        </div>
                        <button type="button" class="btn btn-sm btn-outline-teal rounded-pill px-3 py-1" style="font-size:0.72rem;" onclick="openAppointmentQuickDetail('${secAllDayCover.id}')">
                            <i class="bi bi-eye me-1"></i> Ver Ficha
                        </button>
                    </div>
                </div>
            `);
            return;
        }

        let delay = 0;
        for (let h = sec.start; h < sec.end; h++) {
            for (let m = 0; m < 60; m += interval) {
                const hhmm = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
                const hfM = h * 60 + m + interval;
                const hhmmF = `${Math.floor(hfM / 60).toString().padStart(2, '0')}:${(hfM % 60).toString().padStart(2, '0')}`;
                
                const aptInSlot = dayApts.find(a => {
                    const aHi = a.start.split('T')[1].substring(0, 5);
                    const aHf = a.end.split('T')[1].substring(0, 5);
                    return (hhmm < aHf && hhmmF > aHi);
                });
                const isOcc = !!aptInSlot;
                if (isOcc) matchedAptIds.add(aptInSlot.id);
                const isPastSlot = (date < todayISO) || (date === todayISO && hhmm < currentHHMM);

                let slotStyle = `animation-delay: ${delay}s;`;
                let slotClass = '';
                let slotContent = '';
                let slotTitle = '';
                let isSlotInteractive = true;

                if (isOcc) {
                    const aHi = aptInSlot.start.split('T')[1].substring(0, 5);
                    const aHf = aptInSlot.end.split('T')[1].substring(0, 5);
                    const isAptStart = (hhmm === aHi) || (hhmm <= aHi && hhmmF > aHi);

                    const res = resolverEstadoCita(aptInSlot.extendedProps?.estado, date, aHf);
                    const st = res.clave;
                    const stLow = st.toLowerCase();
                    const esAtendida = res.esAtendida || stLow.includes('atendida');
                    const esCancelada = res.esCancelada || stLow.includes('cancelada');
                    const esEnConsulta = res.esEnConsulta || (stLow === 'en consulta' || stLow === 'consulta en proceso' || stLow.includes('proceso'));
                    const esNoRealizada = res.esNoRealizada || stLow.includes('no realizada') || (isPastSlot && !esAtendida && !esCancelada && !esEnConsulta);

                    // Si no es el slot inicial de una cita que cubre múltiples slots, mostramos indicador de continuación limpio
                    if (!isAptStart) {
                        slotClass = 'slot-busy slot-continuation';
                        slotStyle += ` background-color: ${res.bgCard || '#f8fafc'} !important; border: 1px dashed ${res.border || '#cbd5e1'} !important; color: ${res.textColor || '#64748b'} !important;`;
                        slotTitle = `Continuación de cita: ${aptInSlot.title} (${aHi} - ${aHf})`;
                        slotContent = `
                            <div class="d-flex align-items-center justify-content-between w-100">
                                <span class="fw-bold opacity-75">${hhmm}</span>
                                <span class="badge bg-white text-secondary border" style="font-size:0.52rem;"><i class="bi bi-arrow-return-right"></i> Continúa</span>
                            </div>
                            <span class="d-block text-truncate mt-1 text-secondary opacity-75" style="font-size:0.65rem;">↳ ${aptInSlot.title}</span>
                        `;
                    } else if (esEnConsulta) {
                        slotClass = 'slot-busy slot-en-consulta';
                        slotStyle += ' background-color: #dcfce7 !important; border-color: #059669 !important; color: #166534 !important;';
                        slotTitle = `Consulta en proceso - ${aptInSlot.title}`;
                        slotContent = `
                            <div class="d-flex align-items-center justify-content-between w-100">
                                <span class="fw-bold">${aHi !== hhmmF ? `${aHi}-${aHf}` : hhmm}</span>
                                <span class="badge text-white" style="font-size:0.55rem; background-color:#059669 !important;">EN PROCESO</span>
                            </div>
                            <span class="d-block text-truncate fw-bold mt-1" style="font-size:0.68rem;">${aptInSlot.title}</span>
                            <div class="d-flex justify-content-end gap-1 mt-1">
                                <button type="button" class="btn btn-sm text-white py-0 px-2 rounded-pill fw-bold" style="font-size:0.65rem; background-color:#059669 !important;" onclick="event.stopPropagation(); window.location.href='render_consultas_privado.pl?id=${aptInSlot.extendedProps?.id_paciente}&id_cita=${aptInSlot.id}'" title="Ir a Consulta en Proceso"><i class="bi bi-play-fill"></i> Ir</button>
                            </div>
                        `;
                    } else if (esAtendida) {
                        slotClass = 'slot-busy slot-atendida';
                        slotStyle += ' background-color: #D1FAE5 !important; border-color: #064E3B !important; color: #064E3B !important;';
                        slotTitle = `Renta Finalizada: ${aptInSlot.title}`;
                        slotContent = `
                            <div class="d-flex align-items-center justify-content-between w-100">
                                <span class="fw-bold">${aHi !== hhmmF ? `${aHi}-${aHf}` : hhmm}</span>
                                <span class="badge text-white" style="font-size:0.55rem; background-color:#064E3B !important;">FINALIZADA</span>
                            </div>
                            <span class="d-block text-truncate fw-bold mt-1" style="font-size:0.68rem;">${aptInSlot.title}</span>
                            <div class="d-flex justify-content-end gap-1 mt-1">
                                <button type="button" class="btn btn-sm btn-outline-secondary py-0 px-2 rounded-pill" style="font-size:0.65rem;" onclick="event.stopPropagation(); openAppointmentQuickDetail('${aptInSlot.id}')" title="Ver Detalle Rápido"><i class="bi bi-eye"></i></button>
                            </div>
                        `;
                    } else if (esCancelada) {
                        slotClass = 'slot-busy slot-cancelada opacity-50';
                        slotStyle += ' background-color: #fee2e2 !important; border-color: #fca5a5 !important; text-decoration: line-through;';
                        slotTitle = `Reserva Cancelada: ${aptInSlot.title}`;
                        slotContent = `
                            <div class="d-flex align-items-center justify-content-between w-100">
                                <span>${hhmm}</span>
                                <span class="badge bg-secondary text-white" style="font-size:0.55rem;">CANCELADA</span>
                            </div>
                            <span class="d-block text-truncate mt-1" style="font-size:0.68rem;">${aptInSlot.title}</span>
                        `;
                    } else if (esNoRealizada) {
                        slotClass = 'slot-busy slot-no-realizada';
                        slotStyle += ' background-color: #F1F5F9 !important; border: 1.5px solid #94A3B8 !important; color: #475569 !important; text-decoration: line-through;';
                        slotTitle = `No Realizada (Tachada): ${aptInSlot.title}`;
                        slotContent = `
                            <div class="d-flex align-items-center justify-content-between w-100">
                                <span class="fw-bold text-secondary text-decoration-line-through">${aHi !== hhmmF ? `${aHi}-${aHf}` : hhmm}</span>
                                <span class="badge bg-secondary text-white text-decoration-line-through" style="font-size:0.55rem;">NO REALIZADA</span>
                            </div>
                            <span class="d-block text-truncate fw-bold mt-1 text-secondary text-decoration-line-through" style="font-size:0.68rem;">${aptInSlot.title}</span>
                            <div class="d-flex justify-content-end gap-1 mt-1">
                                <button type="button" class="btn btn-sm btn-outline-primary py-0 px-1 rounded-pill" style="font-size:0.65rem;" onclick="event.stopPropagation(); abrirModalCita('${aptInSlot.id}')" title="Re-agendar"><i class="bi bi-pencil-square"></i></button>
                                <button type="button" class="btn btn-sm btn-outline-secondary py-0 px-1 rounded-pill" style="font-size:0.65rem;" onclick="event.stopPropagation(); openAppointmentQuickDetail('${aptInSlot.id}')" title="Ver Detalle Rápido"><i class="bi bi-eye"></i></button>
                            </div>
                        `;
                    } else if (res.esBloqueoPacientes || aptInSlot.extendedProps?.es_bloqueo_pacientes) {
                        slotClass = 'slot-busy';
                        slotStyle += ' background-color: #E0F2FE !important; border: 1.5px solid #0284C7 !important; color: #0369A1 !important;';
                        slotTitle = `Ocupado (Pacientes): ${aptInSlot.title}`;
                        slotContent = `
                            <div class="d-flex align-items-center justify-content-between w-100">
                                <span class="fw-bold">${aHi !== hhmmF ? `${aHi}-${aHf}` : hhmm}</span>
                                <span class="badge text-white" style="font-size:0.55rem; background-color:#0284C7 !important;">PACIENTES</span>
                            </div>
                            <span class="d-block text-truncate fw-bold mt-1" style="font-size:0.68rem;">${aptInSlot.title}</span>
                        `;
                    } else {
                        const esConf = stLow.includes('confirmada');
                        const bgProg = esConf ? '#FEF9C3' : '#FEF2F2';
                        const borderProg = esConf ? '#EAB308' : '#991B1B';
                        const textProg = esConf ? '#854D0E' : '#991B1B';
                        const badgeBg = esConf ? 'background-color:#EAB308 !important; color:#1e293b !important;' : 'background-color:#991B1B !important; color:#ffffff !important;';
                        slotClass = 'slot-busy';
                        slotStyle += ` background-color: ${bgProg} !important; border: 1.5px solid ${borderProg} !important; color: ${textProg} !important;`;
                        slotTitle = `${st}: ${aptInSlot.title}`;
                        slotContent = `
                            <div class="d-flex align-items-center justify-content-between w-100">
                                <span class="fw-bold">${aHi !== hhmmF ? `${aHi}-${aHf}` : hhmm}</span>
                                <span class="badge" style="font-size:0.55rem; ${badgeBg}">${st.toUpperCase()}</span>
                            </div>
                            <span class="d-block text-truncate fw-bold mt-1" style="font-size:0.68rem;">${aptInSlot.title}</span>
                            <div class="d-flex justify-content-end gap-1 mt-1">
                                <button type="button" class="btn btn-sm btn-outline-primary py-0 px-1 rounded-pill" style="font-size:0.65rem;" onclick="event.stopPropagation(); abrirModalCita('${aptInSlot.id}')" title="Editar / Re-agendar"><i class="bi bi-pencil-square"></i></button>
                            </div>
                        `;
                    }
                } else if (isPastSlot) {
                    // Horario vacío en el pasado: atenuado y no se pueden agendar citas
                    slotClass = 'slot-pasado-atenuado';
                    slotTitle = 'No se pueden agendar citas en horarios pasados';
                    slotContent = `<span class="opacity-60">${hhmm}</span> <i class="bi bi-slash-circle opacity-50 ms-1" style="font-size:0.6rem;"></i>`;
                    isSlotInteractive = false;
                } else {
                    // Horario disponible para agendar
                    slotTitle = `Disponible: ${hhmm}`;
                    slotContent = hhmm;
                }

                let slotElement;
                if (isOcc) {
                    slotElement = $(`
                        <div class="col-6 col-sm-4 col-md-4">
                            <div class="liquid-slot-btn liquid-anim ${slotClass}" 
                                 style="${slotStyle}; cursor:pointer;"
                                 title="${slotTitle}"
                                 onclick="openAppointmentQuickDetail('${aptInSlot.id}')">
                                ${slotContent}
                            </div>
                        </div>
                    `);
                } else if (!isSlotInteractive) {
                    slotElement = $(`
                        <div class="col-6 col-sm-4 col-md-4">
                            <button type="button" class="liquid-slot-btn liquid-anim ${slotClass}" 
                                    style="${slotStyle}"
                                    title="${slotTitle}"
                                    disabled>
                                ${slotContent}
                            </button>
                        </div>
                    `);
                } else {
                    slotElement = $(`
                        <div class="col-6 col-sm-4 col-md-4">
                            <button type="button" class="liquid-slot-btn liquid-anim ${slotClass}" 
                                    style="${slotStyle}"
                                    title="${slotTitle}"
                                    onclick="abrirModalNuevaCita('${date}', '${hhmm}')">
                                ${slotContent}
                            </button>
                        </div>
                    `);
                }

                inner.append(slotElement);
                delay += 0.03;
            }
        }
        if (inner.children().length === 0) inner.append('<div class="col-12 small text-muted opacity-50 p-3">No hay horarios disponibles en este turno.</div>');
    });

    // Citas fuera de horario o extemporáneas del día (para garantizar que NUNCA desaparezcan en vista semanal)
    const extemporaneas = dayApts.filter(a => !matchedAptIds.has(a.id));
    if (extemporaneas.length > 0) {
        let extRows = '';
        extemporaneas.forEach(a => {
            const aHi = a.start.split('T')[1].substring(0, 5);
            const aHf = a.end.split('T')[1].substring(0, 5);
            const res = resolverEstadoCita(a.extendedProps.estado, date, aHf);
            const esAtendida = res.esAtendida || res.clave.toLowerCase().includes('atendida');
            const esCancelada = res.esCancelada || res.clave.toLowerCase().includes('cancelada');
            const esTomable = (!esAtendida && !esCancelada);

            extRows += `
                <div class="d-flex flex-wrap align-items-center justify-content-between p-2.5 mb-2 rounded-3 border bg-white shadow-xs">
                    <div class="d-flex align-items-center gap-2">
                        <span class="badge bg-secondary fw-bold">${aHi} - ${aHf}</span>
                        <span class="fw-bold text-navy small">${a.title}</span>
                        <span class="badge ${res.badgeClass} ms-1" style="font-size:0.6rem;">${res.clave}</span>
                    </div>
                    <div class="d-flex align-items-center gap-1 mt-1 mt-sm-0">
                        ${esTomable ? `<button type="button" class="btn btn-sm btn-success text-white rounded-pill px-2.5 py-0.5 fw-bold" style="font-size:0.68rem;" onclick="event.stopPropagation(); window.tomarCitaDirecto('${a.id}', '${a.extendedProps.id_paciente}')" title="Tomar Cita"><i class="bi bi-play-fill me-1"></i> Tomar</button>` : ''}
                        <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-2 py-0.5" style="font-size:0.68rem;" onclick="event.stopPropagation(); abrirModalCita('${a.id}')" title="Editar / Re-agendar"><i class="bi bi-pencil-square"></i></button>
                        <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill px-2 py-0.5" style="font-size:0.68rem;" onclick="event.stopPropagation(); openAppointmentQuickDetail('${a.id}')" title="Ver Detalle Rápido"><i class="bi bi-eye"></i></button>
                    </div>
                </div>
            `;
        });
        cont.append(`
            <div class="col-12 mb-3">
                <div class="card p-3 shadow-sm rounded-4 border-0" style="background: rgba(254, 242, 242, 0.7); border: 1.5px solid #f87171 !important;">
                    <div class="d-flex align-items-center gap-2 mb-2 text-danger fw-bold small">
                        <i class="bi bi-clock-history"></i> CITAS FUERA DE HORARIO / EXTEMPORÁNEAS (${extemporaneas.length})
                    </div>
                    ${extRows}
                </div>
            </div>
        `);
    }

    // Auto-scroll encapsulado a la hora actual o primer slot dentro del contenedor interno
    setTimeout(() => {
        const scrollParent = document.getElementById('weekly-smart-slots-container') || cont[0];
        if (!scrollParent) return;
        
        const todayStr = getISO(new Date());
        let targetEl = null;
        if (date === todayStr) {
            const h = new Date().getHours().toString().padStart(2, '0');
            const targetBtn = cont.find(`.liquid-slot-btn:contains('${h}:')`).first();
            if (targetBtn.length) targetEl = targetBtn[0];
        } else {
            const firstActive = cont.find('.liquid-slot-btn:not(:disabled)').first();
            if (firstActive.length) targetEl = firstActive[0];
        }

        if (targetEl && scrollParent) {
            // Calculamos offsetTop relativo al contenedor sin disparar scroll global en window/body
            const parentRect = scrollParent.getBoundingClientRect();
            const elRect = targetEl.getBoundingClientRect();
            const relativeTop = elRect.top - parentRect.top + scrollParent.scrollTop;
            scrollParent.scrollTo({
                top: Math.max(0, relativeTop - 80),
                behavior: 'smooth'
            });
        }
    }, 150);
}

/**
 * Formateo legible de fecha en español (ej. 22 Oct 2026)
 */
function formatFechaLegibleEspanol(fechaIso) {
    if (!fechaIso) return '';
    const partes = fechaIso.split('-');
    if (partes.length < 3) return fechaIso;
    const y = partes[0];
    const m = parseInt(partes[1], 10);
    const d = parseInt(partes[2], 10);
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    const mesNombre = meses[m - 1] || partes[1];
    return `${d} ${mesNombre} ${y}`;
}

/**
 * Resalta en el título del modal la fecha y hora de inicio de la cita,
 * y en la duración estimada muestra con color suave amarillo avena el bloqueo del horario aproximado.
 */
function actualizarResaltadoModalCita(fecha, hi, hf, label) {
    const fechaTexto = formatFechaLegibleEspanol(fecha);
    const horaTexto = hi ? `${hi} hrs` : '--:--';
    const rangoTexto = (hi && hf) ? `${hi} - ${hf} hrs` : (hi ? `${hi} hrs` : '');
    
    let durMin = 30;
    if (hi && hf) {
        const [h1, m1] = hi.split(':').map(Number);
        const [h2, m2] = hf.split(':').map(Number);
        durMin = (h2 * 60 + m2) - (h1 * 60 + m1);
        if (isNaN(durMin) || durMin <= 0) durMin = 30;
    }
    
    // 1. Resaltar en el título del modal la fecha y hora de inicio
    const etiqueta = label || 'GESTIÓN DE CITAS';
    let badgeTitulo = '';
    if (fecha || hi) {
        badgeTitulo = `
            <span class="badge badge-avena-highlight shadow-sm ms-2" style="font-size: 0.82rem; font-weight: 700; padding: 0.28rem 0.65rem; border-radius: 20px; letter-spacing: 0.2px;">
                <i class="bi bi-calendar3 me-1"></i>${fechaTexto} &bull; <i class="bi bi-clock-fill ms-1 me-1" style="color: #B45309;"></i>${horaTexto}
            </span>
        `;
    }
    $("#modalCitaTitle").html(`<span class="fw-semibold">${etiqueta}</span>${badgeTitulo}`);

    // 2. En la Duración Estimada: Mostrar con color suave amarillo avena el bloqueo del horario aproximado
    const $bloqueo = $("#bloqueo-horario-avena");
    if ($bloqueo.length) {
        if (hi && hf) {
            $("#bloqueo-horario-rango").html(`<i class="bi bi-clock me-1"></i>${rangoTexto} (${durMin} min)`);
            $("#bloqueo-horario-detalle").text(`Aprox. ${durMin} min bloqueados`);
            $bloqueo.removeClass('d-none');
        } else {
            $bloqueo.addClass('d-none');
        }
    }

    // 3. Resaltar en el selector de duración el botón correspondiente en tono amarillo avena
    $(".btn-dur").removeClass('dur-avena-active');
    const $matchingBtn = $(`.btn-dur[data-v="${durMin}"]`);
    if ($matchingBtn.length) {
        $(".btn-dur").removeClass('active');
        $matchingBtn.addClass('active dur-avena-active');
    }

    if ($('#f_es_rango').val() === '1' && typeof window.verificarDisponibilidadRango === 'function') {
        window.verificarDisponibilidadRango();
    }
}

$(document).ready(function() {
    initClock();
    if (typeof window.initLiveTimeline === 'function') window.initLiveTimeline();
    loadFormMetadata();
    loadContext();
    
    if (window.location.search.includes('open_settings=1')) {
        if (typeof abrirModalAjustes === 'function') setTimeout(abrirModalAjustes, 300);
    }

    // Selector Duración (Diamond Edition Refactor + Slider Sync)
    $(document).on('click', '.btn-dur', function() {
        $(".btn-dur").removeClass('active dur-avena-active');
        $(this).addClass('active dur-avena-active');
        const val = $(this).attr('data-v');
        duracionCita = isNaN(val) ? val : parseInt(val);
        if (typeof window.sincronizarSliderDuracionUI === 'function') {
            window.sincronizarSliderDuracionUI(duracionCita);
        }
        
        // Limpieza estricta de horas para evitar arrastrar slots de otras duraciones
        $("#f_hi").val('');
        $("#f_hf").val('');
        $("#bloqueo-horario-avena").addClass('d-none');
        
        console.info("Duración Seleccionada:", duracionCita);
        renderSlots($("#f_fecha").val());
    });

    // Actualización reactiva al cambiar la fecha en el modal de reserva (con bloqueo de fechas pasadas)
    $(document).on('change', '#f_fecha', function() {
        const hoyIso = getISO(new Date());
        if (this.value && this.value < hoyIso) {
            Swal.fire({
                icon: 'warning',
                title: 'Fecha Pasada No Permitida',
                text: 'No se puede reservar un espacio antes de la fecha y hora actual.',
                customClass: { popup: 'rounded-4' }
            });
            this.value = hoyIso;
        }
        const nuevaFecha = this.value;
        renderSlots(nuevaFecha);
        const hi = $("#f_hi").val();
        const hf = $("#f_hf").val();
        const accion = $("#f_accion").val();
        if (hi && hf) {
            const lbl = (accion === 'update') ? 'RESERVA DE ESPACIO / EDITAR RESERVA' : 'RESERVA DE ESPACIO / NUEVO ARRENDAMIENTO';
            actualizarResaltadoModalCita(nuevaFecha, hi, hf, lbl);
        }
    });

    if (typeof window.inicializarFiltroMedicos === 'function') {
        window.inicializarFiltroMedicos();
    }
    setupAutocomplete();
    switchView('calendario'); // Vista por defecto cambiada a GRID

    // Lógica Punto 2: Auto-apertura por parámetro de paciente
    if (window.idPacientePre && window.nombrePacientePre) {
        console.info("Agendamiento Inteligente -> Detectado:", window.nombrePacientePre);
        setTimeout(() => {
            abrirModalNuevaCita(null, null, window.idPacientePre, window.nombrePacientePre);
        }, 800); // Pequeño delay para asegurar que el contexto cargó
    }
});

/**
 * Autocompletado Híbrido para el campo "Nombre del Médico / Arrendatario" (#f_paciente)
 * Permite capturar cualquier nombre libremente O buscar y seleccionar de los médicos dados de alta como colaboradores activos.
 */
function setupAutocomplete() {
    const inputEl = document.getElementById('f_paciente');
    const menuEl  = document.getElementById('dropdown_autocomplete_medicos');
    if (!inputEl || !menuEl) return;

    window.mostrarSugerenciasMedicosActivos = function(mostrarTodos = false) {
        const list = Array.isArray(window.medicosActivosList) ? window.medicosActivosList : [];
        const q = (inputEl.value || '').trim().toLowerCase();

        // Sincronizar con el selector #f_medico_select si el texto coincide exactamente con un médico interno
        const exactMatch = list.find(m => (m.nombre || '').toLowerCase() === q);
        const selMed = document.getElementById('f_medico_select');
        if (selMed) {
            if (exactMatch) {
                selMed.value = exactMatch.id;
            } else {
                selMed.value = 'EXTERNO';
            }
        }

        const filtered = list.filter(m => {
            if (mostrarTodos || !q) return true;
            const nom = (m.nombre || '').toLowerCase();
            const cor = (m.correo || '').toLowerCase();
            const qx  = (m.rol_quirurgico || '').toLowerCase();
            return nom.includes(q) || cor.includes(q) || qx.includes(q);
        });

        if (filtered.length === 0) {
            if (q.length > 0) {
                menuEl.innerHTML = `
                    <div class="px-3 py-2 small text-muted d-flex align-items-center justify-content-between">
                        <span><i class="bi bi-person-plus text-teal me-1.5"></i>Se registrará como arrendatario externo: <strong class="text-navy">${q}</strong></span>
                        <span class="badge bg-light text-secondary border">Libre</span>
                    </div>
                `;
                menuEl.style.display = 'block';
            } else {
                menuEl.style.display = 'none';
            }
            return;
        }

        let html = `<div class="px-2.5 py-1 text-uppercase fw-bold text-muted border-bottom" style="font-size: 0.65rem; letter-spacing: 0.5px;">Médicos Colaboradores Activos (${filtered.length})</div>`;
        filtered.forEach(m => {
            const qxTag = (m.rol_quirurgico && m.rol_quirurgico !== 'No aplica')
                ? `<span class="badge bg-danger-subtle text-danger border border-danger-subtle ms-auto" style="font-size:0.62rem;">${m.rol_quirurgico}</span>`
                : `<span class="badge bg-primary-subtle text-primary border border-primary-subtle ms-auto" style="font-size:0.62rem;">Colaborador</span>`;
            const safeNom = (m.nombre || '').replace(/"/g, '&quot;');
            html += `
                <button type="button" class="dropdown-item d-flex align-items-center justify-content-between gap-2 rounded-2 px-2.5 py-1.5 small"
                        onclick="window.seleccionarMedicoAutocomplete('${m.id}', '${safeNom}')">
                    <div class="text-truncate">
                        <i class="bi bi-person-check-fill text-teal me-1.5"></i>
                        <span class="fw-bold text-navy">${m.nombre}</span>
                    </div>
                    ${qxTag}
                </button>
            `;
        });
        menuEl.innerHTML = html;
        menuEl.style.display = 'block';
    };

    window.seleccionarMedicoAutocomplete = function(idMed, nombreMed) {
        inputEl.value = nombreMed;
        const selMed = document.getElementById('f_medico_select');
        if (selMed) {
            selMed.value = idMed;
        }
        menuEl.style.display = 'none';
    };

    inputEl.addEventListener('input', function() {
        window.mostrarSugerenciasMedicosActivos(false);
    });

    inputEl.addEventListener('focus', function() {
        if ((Array.isArray(window.medicosActivosList) && window.medicosActivosList.length > 0)) {
            window.mostrarSugerenciasMedicosActivos(inputEl.value.trim() === '');
        }
    });

    document.addEventListener('click', function(e) {
        const wrapper = document.getElementById('wrapper_autocomplete_arrendatario');
        if (wrapper && !wrapper.contains(e.target)) {
            menuEl.style.display = 'none';
        }
    });
}

// Aliases para compatibilidad con versiones previas de citas.pl
function navigateDate(offset) { moveDate(offset); }
function navigateToday() { goToday(); }

function loadFormMetadata() {
    $.get('../api/espacios_crud.pl', { accion: 'get_form_metadata' }, function(res) {
        if (res.ok) {
            if (res.medicos && Array.isArray(res.medicos)) {
                res.medicos.sort((a, b) => (a.nombre || '').localeCompare(b.nombre || ''));
                window.medicosActivosList = res.medicos;

                const selMed = $("#f_medico_select");
                if (selMed.length) {
                    const currentVal = selMed.val() || 'EXTERNO';
                    selMed.empty();
                    selMed.append('<option value="EXTERNO">-- Profesional / Arrendatario Externo --</option>');
                    res.medicos.forEach(m => {
                        const qxSuffix = (m.rol_quirurgico && m.rol_quirurgico !== 'No aplica') ? ` • ${m.rol_quirurgico}` : ' (Interno)';
                        selMed.append(`<option value="${m.id}">${m.nombre}${qxSuffix}</option>`);
                        if (window.medicosCatalogo) window.medicosCatalogo[m.id] = m.nombre;
                    });
                    selMed.val(currentVal);
                }
            }

            if (res.sucursales && res.sucursales.length > 0) {
                const selSuc = $("#f_sucursal");
                const curSuc = selSuc.val();
                selSuc.empty();
                res.sucursales.forEach(s => {
                    let text = s.nombre;
                    if (s.tipo === 'Matriz' && !res.es_consultorio_ind) text += ' (Matriz)';
                    selSuc.append(`<option value="${s.id}">${text}</option>`);
                });
                if (curSuc) selSuc.val(curSuc);
            }
        }
    });
}

function filtrarAgendaPorMedico(idMed) {
    $("#f_medico").val(idMed);
    cargarEventosYConfig(idMed);
}

function cargarEventosYConfig(idMed) {
    const dest = idMed || $("#f_medico").val() || 'all';
    const suc = $("#f_sucursal").val() || '1';
    $.get('../api/espacios_crud.pl', { accion: 'get_events', id_medico: dest, id_sucursal: suc }, function(res) {
        if (res.ok) {
            appointments = res.data;
            if (res.config) {
                agendaConfig = res.config;
                duracionCita = parseInt(agendaConfig.intervalo_minutos) || 30;
                renderDuracionButtons();
                if (typeof window.actualizarHeaderEspaciosHabilitados === 'function') {
                    window.actualizarHeaderEspaciosHabilitados();
                }
                if (typeof window.poblarFiltroRecursosToolbar === 'function' && window.sucursalRecursos) {
                    window.poblarFiltroRecursosToolbar(window.sucursalRecursos);
                }
            }
            syncUI();
        }
    });
}

function actualizarAgendaDestino() {
    // Si la recepcionista cambia de médico al agendar, recargamos la configuración de jornada real para slots
    const destId = $("#f_medico_select").val();
    const suc = $("#f_sucursal").val() || '1';
    if (!destId) return;
    $.get('../api/espacios_crud.pl', { accion: 'get_events', id_medico: destId, id_sucursal: suc }, function(res) {
        if (res.ok) {
            if (res.config) {
                agendaConfig = res.config;
                duracionCita = parseInt(agendaConfig.intervalo_minutos) || 30;
                renderDuracionButtons();
            }
            renderSlots($("#f_fecha").val());
        }
    });
}

function loadContext() {
    const idMed = $("#f_medico").val() || 'all';
    cargarEventosYConfig(idMed);
}

function formatDuracionLabel(val) {
    if (val === 'all') return 'Día Completo';
    if (val === 'rest') return 'Hasta el Cierre (Resto)';
    const mins = parseInt(val, 10) || 60;
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    if (h > 0 && m > 0) return `${h}h ${m}m (${mins} min)`;
    if (h > 0) return `${h} hr${h > 1 ? 's' : ''} (${mins} min)`;
    return `${mins} min`;
}

window.sincronizarSliderDuracionUI = function(val) {
    const slider = document.getElementById('slider_duracion_renta');
    const badge  = document.getElementById('lbl_slider_duracion_badge');
    if (badge) {
        badge.textContent = formatDuracionLabel(val);
    }
    if (slider) {
        const maxVal = parseInt(slider.max, 10) || 480;
        if (val === 'all' || val === 'rest') {
            slider.value = maxVal;
        } else {
            const num = parseInt(val, 10) || 60;
            slider.value = Math.min(maxVal, Math.max(parseInt(slider.min, 10) || 30, num));
        }
    }
};

window.onDuracionSliderChange = function(rawVal) {
    const slider = document.getElementById('slider_duracion_renta');
    const maxVal = slider ? (parseInt(slider.max, 10) || 480) : 480;
    const numVal = parseInt(rawVal, 10) || 60;

    $(".btn-dur").removeClass('active dur-avena-active');

    if (numVal >= maxVal) {
        // El extremo derecho del slider activa el modo "Hasta el Cierre (Resto del Día)"
        duracionCita = 'rest';
        $('.btn-dur[data-v="rest"]').addClass('active dur-avena-active');
    } else {
        duracionCita = numVal;
        const matchBtn = $(`.btn-dur[data-v="${numVal}"]`);
        if (matchBtn.length) matchBtn.addClass('active dur-avena-active');
    }

    window.sincronizarSliderDuracionUI(duracionCita);

    // Si ya había una hora de inicio seleccionada, recalcular dinámicamente la hora de fin si sigue siendo válida
    const curHi = $("#f_hi").val();
    const curFecha = $("#f_fecha").val();
    if (curHi && curFecha) {
        const lEnd = agendaConfig.laborEnd || '21:00';
        const [leH, leM] = lEnd.split(':').map(Number);
        const endMinJornada = ((leH || 21) * 60) + (leM || 0);
        const [h1, m1] = curHi.split(':').map(Number);
        const startMin = h1 * 60 + m1;

        let newEndMin = (duracionCita === 'rest') ? endMinJornada : (startMin + duracionCita);
        if (newEndMin > endMinJornada) newEndMin = endMinJornada;

        const hE = Math.floor(newEndMin / 60).toString().padStart(2, '0');
        const mE = (newEndMin % 60).toString().padStart(2, '0');
        const newHf = (newEndMin >= 1440) ? '23:59' : `${hE}:${mE}`;
        $("#f_hf").val(newHf);
        const accion = $("#f_accion").val();
        const lbl = (accion === 'update') ? 'RESERVA DE ESPACIO / EDITAR RESERVA' : 'RESERVA DE ESPACIO / NUEVO ARRENDAMIENTO';
        actualizarResaltadoModalCita(curFecha, curHi, newHf, lbl);
    }

    renderSlots(curFecha);
};

function renderDuracionButtons() {
    const int = parseInt(agendaConfig.intervalo_minutos) || 30;
    const g = $("#btn-group-duracion");
    g.empty();

    // Configurar límites del slider según la jornada de la sucursal
    const slider = document.getElementById('slider_duracion_renta');
    if (slider) {
        slider.min = int;
        slider.step = int;
        slider.max = 510; // 30..480 min (8 hrs) y 510 = Hasta el Cierre (Resto)
    }

    g.append(`<button type="button" class="btn btn-dur" data-v="60">1h</button>`);
    g.append(`<button type="button" class="btn btn-dur" data-v="120">2h</button>`);
    g.append(`<button type="button" class="btn btn-dur" data-v="240">4h (Turno)</button>`);
    g.append(`<button type="button" class="btn btn-dur" data-v="rest" title="Reservar desde la hora elegida hasta el cierre de la sede">HASTA CIERRE</button>`);
    g.append(`<button type="button" class="btn btn-dur" data-v="all" title="Reservar toda la jornada del día">DÍA COMPLETO</button>`);

    window.sincronizarSliderDuracionUI(duracionCita);
}


function syncUI() {
    renderHeaders();
    renderView();
}

function switchView(v) {
    currentView = v;
    
    // Desktop Header Toggles
    $(".btn-view-toggle, .btn-report-toggle").removeClass('active');
    $(`#btn-v-${v.replace('_','-')}, #btn-r-${v.replace('_','-')}, #btn-r-${v}`).addClass('active');
    
    // Show/Hide Containers
    $(".agenda-view-container").addClass('d-none');
    $(`#view-${v.replace('_','-')}`).removeClass('d-none');

    // Gestión de controles de toolbar según la vista activa (Nivel 2 siempre mantiene visibles los selectores directos):
    $("#wrapper_filtro_recurso_toolbar").removeClass('d-none d-lg-block');
    if (v === 'dia') {
        $("#btn-toggle-side-cal").removeClass('d-lg-none').addClass('d-lg-inline-flex');
    } else {
        $("#btn-toggle-side-cal").removeClass('d-lg-inline-flex').addClass('d-lg-none');
    }

    renderHeaders();
    renderView();
}

function renderView() {
    if (currentView === 'dia') renderTimeline();
    else if (currentView === 'semana_smart') renderWeeklySmartView();
    else if (currentView === 'dia_reporte') renderTable('dia_reporte');
    else if (currentView === 'semana') renderTable('semana');
    else if (currentView === 'mes') renderTable('mes');
    else renderGrid();
}

function renderHeaders() {
    const today = new Date(); today.setHours(0,0,0,0);
    const sel = new Date(selectedDate); sel.setHours(0,0,0,0);
    
    let title = "";
    const optionsFull = { day: 'numeric', month: 'long', year: 'numeric' };
    const optionsShort = { day: 'numeric', month: 'long' };

    if (currentView === 'dia' || currentView === 'dia_reporte') {
        const diff = Math.round((sel - today) / (1000 * 60 * 60 * 24));
        if (diff === 0) title = "Agenda de Hoy: " + selectedDate.toLocaleDateString('es-ES', optionsShort);
        else if (diff === 1) title = "Agenda para Mañana: " + selectedDate.toLocaleDateString('es-ES', optionsShort);
        else if (diff === -1) title = "Agenda de Ayer: " + selectedDate.toLocaleDateString('es-ES', optionsShort);
        else title = "Vista: " + selectedDate.toLocaleDateString('es-ES', optionsFull);
    } 
    else if (currentView === 'semana_smart' || currentView === 'semana') {
        // Calcular rango de la semana (Lunes a Domingo)
        const d = sel.getDay() || 7;
        const monday = new Date(sel); monday.setDate(sel.getDate() - (d - 1));
        const sunday = new Date(monday); sunday.setDate(monday.getDate() + 6);
        
        const startStr = monday.toLocaleDateString('es-ES', { day:'numeric', month:'short' });
        const endStr = sunday.toLocaleDateString('es-ES', { day:'numeric', month:'short' });
        title = `Semana: ${startStr} - ${endStr}`.replace(/\./g, '');
    } 
    else if (currentView === 'mes' || currentView === 'calendario') {
        title = selectedDate.toLocaleDateString('es-ES', { month:'long', year:'numeric' });
    } else {
        title = selectedDate.toLocaleDateString('es-ES', optionsFull);
    }
    
    const finalTitle = title.toUpperCase();
    $("#current-date-label-desktop, #current-date-label-mobile").text(finalTitle);
    
    // Ocultar botón nueva cita en fechas pasadas
    if (sel < today) {
        $(".btn-navy:contains('NUEVA CITA'), #btn-nueva-cita").addClass('d-none');
    } else {
        $(".btn-navy:contains('NUEVA CITA'), #btn-nueva-cita").removeClass('d-none');
    }
}

function moveDate(offset) {
    if (currentView === 'dia' || currentView === 'dia_reporte') selectedDate.setDate(selectedDate.getDate() + offset);
    else if (currentView === 'semana' || currentView === 'semana_smart') selectedDate.setDate(selectedDate.getDate() + (offset * 7));
    else if (currentView === 'mes' || currentView === 'calendario') selectedDate.setMonth(selectedDate.getMonth() + offset);
    
    renderHeaders();
    renderView();
}

function goToday() {
    selectedDate = new Date();
    selectedDate.setHours(12, 0, 0, 0);
    renderHeaders();
    renderView();
    setTimeout(() => {
        if (currentView === 'dia') {
            const h = new Date().getHours().toString().padStart(2, '0');
            const slot = $(`#slot-${h}-00`);
            if (slot.length) {
                slot[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }
    }, 100);
}

function goDay(iso) {
    selectedDate = new Date(iso + 'T12:00:00');
    switchView('dia');
}

// --- ESTADO Y CONTROLADORES DE LA VISTA DE DÍA MATRICIAL (ESPACIOS FÍSICOS MULTI-CHECK) ---
window.recursosChecked = null; // null = todos seleccionados por defecto; Array de IDs cuando el usuario filtra
window.todosLosRecursosIds = [];

// Claves de memoria local segmentadas por sucursal
function getFiltroStorageKey(tipo) {
    const sucursalId = $('#f_sucursal').val() || $('#f_id_negocio').val() || 'default';
    return `ospulso_espacios_filtro_${tipo}_${sucursalId}`;
}

window.guardarFiltroMemoria = function(tipo) {
    try {
        if (tipo === 'medicos' && Array.isArray(window.medicosChecked)) {
            localStorage.setItem(getFiltroStorageKey('medicos'), JSON.stringify(window.medicosChecked));
        } else if (tipo === 'recursos' && Array.isArray(window.recursosChecked)) {
            localStorage.setItem(getFiltroStorageKey('recursos'), JSON.stringify(window.recursosChecked));
        }
    } catch(e) {
        console.warn("No se pudo guardar filtro en localStorage:", e);
    }
};

window.recuperarFiltroMemoria = function(tipo) {
    try {
        const raw = localStorage.getItem(getFiltroStorageKey(tipo));
        if (raw) {
            const parsed = JSON.parse(raw);
            if (Array.isArray(parsed)) return parsed;
        }
    } catch(e) {
        console.warn("No se pudo recuperar filtro de localStorage:", e);
    }
    return null;
};

window.seleccionarTodosEspacios = function(marcar) {
    $('.chk-recurso-item').prop('checked', !!marcar);
    if (marcar) {
        window.recursosChecked = [...window.todosLosRecursosIds];
    } else {
        window.recursosChecked = [];
    }
    window.guardarFiltroMemoria('recursos');
    window.actualizarLabelFiltroRecursos();
    renderView();
};

window.seleccionarSoloHabilitados = function() {
    const soloHabilitados = [];
    $('.chk-recurso-item').each(function() {
        const val = $(this).val();
        const isLocked = window.esEspacioBloqueado(val);
        const shouldCheck = !isLocked;
        $(this).prop('checked', shouldCheck);
        if (shouldCheck) soloHabilitados.push(val);
    });
    window.recursosChecked = soloHabilitados;
    window.guardarFiltroMemoria('recursos');
    window.actualizarLabelFiltroRecursos();
    renderView();
};

window.onRecursoCheckChange = function() {
    const marcados = [];
    $('.chk-recurso-item:checked').each(function() {
        marcados.push($(this).val());
    });
    window.recursosChecked = marcados;
    window.guardarFiltroMemoria('recursos');
    window.actualizarLabelFiltroRecursos();
    renderView();
};

window.actualizarLabelFiltroRecursos = function() {
    const total = window.todosLosRecursosIds ? window.todosLosRecursosIds.length : 0;
    const marcados = (window.recursosChecked !== null) ? window.recursosChecked.length : total;
    const labelSpan = $('#filtro_recurso_btn_label');
    if (!labelSpan.length) return;

    let bloqueadosTotal = 0;
    if (window.todosLosRecursosIds && window.todosLosRecursosIds.length > 0) {
        window.todosLosRecursosIds.forEach(id => {
            if (window.esEspacioBloqueado(id)) bloqueadosTotal++;
        });
    }
    const habilitadosTotal = Math.max(0, total - bloqueadosTotal);

    if (marcados === total && total > 0) {
        if (bloqueadosTotal > 0) {
            labelSpan.html(`<i class="bi bi-door-open-fill text-teal"></i> <span class="text-truncate">Espacios (${habilitadosTotal} Hab • ${bloqueadosTotal} Bloq)</span>`);
        } else {
            labelSpan.html(`<i class="bi bi-door-open-fill text-teal"></i> <span class="text-truncate">Espacios (${total})</span>`);
        }
    } else if (marcados === 0) {
        labelSpan.html(`<i class="bi bi-dash-circle text-danger"></i> <span class="text-truncate">Espacios (0/${total})</span>`);
    } else {
        labelSpan.html(`<i class="bi bi-funnel-fill text-teal"></i> <span class="text-truncate">Espacios (${marcados}/${total})</span>`);
    }
};

// --- ESTADO Y CONTROLADORES DE MÉDICOS (MULTI-CHECK INTERACTIVO CON MEMORIA) ---
window.medicosChecked = null; // null = todos seleccionados por defecto; Array de IDs cuando el usuario filtra
window.todosLosMedicosIds = [];

window.inicializarFiltroMedicos = function() {
    const allIds = [];
    $('.chk-medico-item').each(function() {
        allIds.push(String($(this).val()));
    });
    if (allIds.length > 0) {
        window.todosLosMedicosIds = allIds;
        
        // Intentar restaurar desde memoria persistente
        const guardado = window.recuperarFiltroMemoria('medicos');
        if (guardado !== null && Array.isArray(guardado) && guardado.length > 0) {
            const guardadoValidos = guardado.filter(id => allIds.includes(String(id)));
            // Si guardado solo tenía 'EXTERNO' pero ahora existen médicos internos registrados,
            // marcar todos por defecto para garantizar visibilidad de las reservas de la clínica
            if (guardadoValidos.length < allIds.length && guardadoValidos.length === 1 && guardadoValidos[0] === 'EXTERNO') {
                window.medicosChecked = [...allIds];
            } else {
                window.medicosChecked = (guardadoValidos.length > 0) ? guardadoValidos : [...allIds];
            }
        } else {
            window.medicosChecked = [...allIds];
        }

        $('.chk-medico-item').each(function() {
            const val = String($(this).val());
            $(this).prop('checked', window.medicosChecked.includes(val));
        });
        window.actualizarLabelFiltroMedicos();
    }
};

window.seleccionarTodosMedicos = function(marcar) {
    if (!window.todosLosMedicosIds.length) {
        $('.chk-medico-item').each(function() {
            window.todosLosMedicosIds.push(String($(this).val()));
        });
    }
    $('.chk-medico-item').prop('checked', !!marcar);
    if (marcar) {
        window.medicosChecked = [...window.todosLosMedicosIds];
    } else {
        window.medicosChecked = [];
    }
    window.guardarFiltroMemoria('medicos');
    window.actualizarLabelFiltroMedicos();
    renderView();
};

window.onMedicoCheckChange = function() {
    if (!window.todosLosMedicosIds.length) {
        $('.chk-medico-item').each(function() {
            window.todosLosMedicosIds.push(String($(this).val()));
        });
    }
    const marcados = [];
    $('.chk-medico-item:checked').each(function() {
        marcados.push(String($(this).val()));
    });
    window.medicosChecked = marcados;
    window.guardarFiltroMemoria('medicos');
    window.actualizarLabelFiltroMedicos();
    renderView();
};

window.actualizarLabelFiltroMedicos = function() {
    const total = window.todosLosMedicosIds.length;
    const marcados = (window.medicosChecked !== null) ? window.medicosChecked.length : total;
    const labelSpan = $('#filtro_medico_btn_label');
    if (!labelSpan.length) return;

    if (marcados === total && total > 0) {
        labelSpan.html('<i class="bi bi-people-fill text-primary"></i> <span class="text-truncate">Médicos (' + total + ')</span>');
    } else if (marcados === 0) {
        labelSpan.html('<i class="bi bi-dash-circle text-danger"></i> <span class="text-truncate">Médicos (0/' + total + ')</span>');
    } else {
        labelSpan.html('<i class="bi bi-funnel-fill text-primary"></i> <span class="text-truncate">Médicos (' + marcados + '/' + total + ')</span>');
    }
};

/**
 * Función Canónica Universal de Filtrado de Citas por Médico y Espacios Físicos (Consultorios / Quirófanos)
 * Aplica de forma coherente el filtro activo en Día, Semana Smart, Mes Grid y Reportes
 */
function getFilteredAppointments(customList) {
    let list = customList || appointments;
    if (!Array.isArray(list)) return [];

    // 1. Filtrado interactivo por Médicos
    if (window.medicosChecked !== null && Array.isArray(window.medicosChecked)) {
        const totalMed = window.todosLosMedicosIds ? window.todosLosMedicosIds.length : 0;
        // Si todos están marcados o no hay IDs definidos, no filtrar por médico
        if (totalMed > 0 && window.medicosChecked.length < totalMed) {
            if (window.medicosChecked.length === 0) {
                return []; // Usuario desmarcó conscientemente todos los médicos
            }
            list = list.filter(a => {
                const mId = String(a.extendedProps?.id_medico || a.extendedProps?.id_arrendatario || '');
                const mNom = String(a.extendedProps?.medico || a.extendedProps?.nombre_arrendatario || '');
                return window.medicosChecked.includes(mId) || 
                       (mId !== 'EXTERNO' && window.medicosChecked.includes(mNom));
            });
        }
    } else {
        const medFiltro = $('#filtro_medico_toolbar').val() || $('#f_medico').val();
        if (medFiltro && medFiltro !== 'all') {
            list = list.filter(a => 
                String(a.extendedProps?.id_medico) === String(medFiltro) || 
                String(a.extendedProps?.id_arrendatario) === String(medFiltro) ||
                String(a.extendedProps?.medico) === String(medFiltro)
            );
        }
    }

    // 2. Filtrado interactivo por Consultorios y Espacios Físicos (Quirófanos / Consultorios)
    if (window.recursosChecked !== null && Array.isArray(window.recursosChecked)) {
        if (window.recursosChecked.length === 0) {
            return []; // El usuario desmarcó todos los espacios
        }
        const total = window.todosLosRecursosIds ? window.todosLosRecursosIds.length : 0;
        if (total > 0 && window.recursosChecked.length < total) {
            list = list.filter(a => {
                const cVal = (a.extendedProps?.consultorio || a.extendedProps?.espacio || a.extendedProps?.recurso || a.extendedProps?.lugar || '').trim();
                const normCVal = normalizarTextoEspacio(cVal); // ej: "qx 1" o "cons 1"
                const aSucId = String(a.extendedProps?.sucursal || a.extendedProps?.id_sucursal || a.extendedProps?.id_negocio || '').trim();
                
                // Evaluar si coincide con alguno de los espacios físicos seleccionados
                return window.recursosChecked.some(recId => {
                    const normRecId = normalizarTextoEspacio(recId);
                    // Si el espacio seleccionado es específico de una sucursal (ej: suc_965257_quirofano_1)
                    if (recId.toLowerCase().startsWith('suc_')) {
                        const parts = recId.toLowerCase().split('_');
                        const rSuc = parts[1];
                        if (aSucId && aSucId !== rSuc) return false;
                        const rTipo = parts[2]; // consultorio o quirofano
                        const rNum = parts[3];
                        const targetPattern = normalizarTextoEspacio(`${rTipo} ${rNum}`); // "qx 1" o "cons 1"
                        return normCVal.includes(targetPattern) || targetPattern.includes(normCVal) || normRecId.includes(normCVal);
                    }

                    // En organización simple o única sucursal (ej: consultorio_1, quirofano_1)
                    return normRecId.includes(normCVal) || normCVal.includes(normRecId);
                });
            });
        }
    }

    return list;
}

window.poblarFiltroRecursosToolbar = function(data) {
    const listContainer = $('#lista_checkboxes_recursos');
    if (!listContainer.length) return;

    const esUnica = (data && (data.es_unica === 1 || data.es_unica === true || data.es_unica === "1")) || 
                    (!data || !data.sucursales || data.sucursales.length <= 1);

    const allIds = [];
    let html = '';

    if (esUnica) {
        let numCons = (data && data.consultorios) ? parseInt(data.consultorios) : 0;
        let numQx = (data && data.quirofanos) ? parseInt(data.quirofanos) : 0;
        if (data && data.sucursales && data.sucursales.length > 0) {
            if (!numCons && data.sucursales[0].consultorios) numCons = parseInt(data.sucursales[0].consultorios);
            if (!numQx && data.sucursales[0].quirofanos) numQx = parseInt(data.sucursales[0].quirofanos);
        }
        numCons = Math.max(1, numCons);

        html += '<div class="px-2 pt-1 pb-0.5 text-muted fw-bold text-uppercase" style="font-size:0.65rem; letter-spacing:0.5px;">Consultorios</div>';
        for (let i = 1; i <= numCons; i++) {
            const idVal = `consultorio_${i}`;
            const label = `Consultorio ${i}`;
            const isLocked = window.esEspacioBloqueado(label) || window.esEspacioBloqueado(idVal);
            allIds.push(idVal);
            html += `
                <label class="dropdown-item d-flex align-items-center gap-2 rounded-2 px-2 py-1.5 cursor-pointer user-select-none mb-0.5 ${isLocked ? 'bg-danger-subtle bg-opacity-25' : ''}">
                    <input type="checkbox" class="form-check-input mt-0 chk-recurso-item" value="${idVal}" onchange="window.onRecursoCheckChange()">
                    <i class="bi ${isLocked ? 'bi-lock-fill text-danger' : 'bi-door-closed-fill text-teal'}" style="font-size:0.95rem;"></i>
                    <span class="fw-semibold ${isLocked ? 'text-danger-emphasis' : 'text-navy'} small">${label}</span>
                    ${isLocked 
                        ? '<span class="badge text-danger-emphasis bg-danger-subtle border border-danger-subtle ms-auto" style="font-size:0.62rem; padding:0.18rem 0.45rem;"><i class="bi bi-lock-fill me-0.5"></i>Bloqueado</span>' 
                        : '<span class="badge text-success-emphasis bg-success-subtle border border-success-subtle ms-auto" style="font-size:0.62rem; padding:0.18rem 0.45rem;">Habilitado</span>'}
                </label>
            `;
        }

        if (numQx > 0) {
            html += '<div class="px-2 pt-2 pb-0.5 text-muted fw-bold text-uppercase border-top mt-1" style="font-size:0.65rem; letter-spacing:0.5px;">Quirófanos</div>';
            for (let i = 1; i <= numQx; i++) {
                const idVal = `quirofano_${i}`;
                const label = `Quirófano ${i}`;
                const isLocked = window.esEspacioBloqueado(label) || window.esEspacioBloqueado(idVal);
                allIds.push(idVal);
                html += `
                    <label class="dropdown-item d-flex align-items-center gap-2 rounded-2 px-2 py-1.5 cursor-pointer user-select-none mb-0.5 ${isLocked ? 'bg-danger-subtle bg-opacity-25' : ''}">
                        <input type="checkbox" class="form-check-input mt-0 chk-recurso-item" value="${idVal}" onchange="window.onRecursoCheckChange()">
                        <i class="bi ${isLocked ? 'bi-lock-fill text-danger' : 'bi-scissors'}" style="font-size:0.95rem; color:${isLocked ? '#dc2626' : '#7C3AED'};"></i>
                        <span class="fw-semibold ${isLocked ? 'text-danger-emphasis' : 'text-navy'} small">${label}</span>
                        ${isLocked 
                            ? '<span class="badge text-danger-emphasis bg-danger-subtle border border-danger-subtle ms-auto" style="font-size:0.62rem; padding:0.18rem 0.45rem;"><i class="bi bi-lock-fill me-0.5"></i>Bloqueado</span>' 
                            : '<span class="badge text-primary bg-primary-subtle border border-primary-subtle ms-auto" style="font-size:0.62rem; padding:0.18rem 0.45rem;">Quirúrgico</span>'}
                    </label>
                `;
            }
        }
    } else {
        // Múltiples sucursales: Agrupadas por Sucursal [nombre_sucursal]
        data.sucursales.forEach((s, idx) => {
            const sId = s.id;
            const sNom = s.nombre || `Sucursal ${sId}`;
            const numCons = parseInt(s.consultorios) || 1;
            const numQx = parseInt(s.quirofanos) || 0;
            const borderTop = idx > 0 ? 'border-top mt-1.5 pt-1.5' : 'pt-1';

            html += `<div class="px-2 pb-0.5 text-navy fw-black text-uppercase ${borderTop}" style="font-size:0.68rem; letter-spacing:0.5px;">🏢 ${sNom}</div>`;
            for (let i = 1; i <= numCons; i++) {
                const idVal = `suc_${sId}_consultorio_${i}`;
                const label = `Consultorio ${i}`;
                const isLocked = window.esEspacioBloqueado(label) || window.esEspacioBloqueado(idVal);
                allIds.push(idVal);
                html += `
                    <label class="dropdown-item d-flex align-items-center gap-2 rounded-2 px-2 py-1.5 cursor-pointer user-select-none mb-0.5 ${isLocked ? 'bg-danger-subtle bg-opacity-25' : ''}">
                        <input type="checkbox" class="form-check-input mt-0 chk-recurso-item" value="${idVal}" onchange="window.onRecursoCheckChange()">
                        <i class="bi ${isLocked ? 'bi-lock-fill text-danger' : 'bi-door-closed-fill text-teal'}" style="font-size:0.95rem;"></i>
                        <span class="fw-semibold ${isLocked ? 'text-danger-emphasis' : 'text-navy'} small">${label}</span>
                        ${isLocked 
                            ? '<span class="badge text-danger-emphasis bg-danger-subtle border border-danger-subtle ms-auto" style="font-size:0.62rem; padding:0.18rem 0.45rem;"><i class="bi bi-lock-fill me-0.5"></i>Bloqueado</span>' 
                            : '<span class="badge text-success-emphasis bg-success-subtle border border-success-subtle ms-auto" style="font-size:0.62rem; padding:0.18rem 0.45rem;">Habilitado</span>'}
                    </label>
                `;
            }
            for (let i = 1; i <= numQx; i++) {
                const idVal = `suc_${sId}_quirofano_${i}`;
                const label = `Quirófano ${i}`;
                const isLocked = window.esEspacioBloqueado(label) || window.esEspacioBloqueado(idVal);
                allIds.push(idVal);
                html += `
                    <label class="dropdown-item d-flex align-items-center gap-2 rounded-2 px-2 py-1.5 cursor-pointer user-select-none mb-0.5 ${isLocked ? 'bg-danger-subtle bg-opacity-25' : ''}">
                        <input type="checkbox" class="form-check-input mt-0 chk-recurso-item" value="${idVal}" onchange="window.onRecursoCheckChange()">
                        <i class="bi ${isLocked ? 'bi-lock-fill text-danger' : 'bi-scissors'}" style="font-size:0.95rem; color:${isLocked ? '#dc2626' : '#7C3AED'};"></i>
                        <span class="fw-semibold ${isLocked ? 'text-danger-emphasis' : 'text-navy'} small">${label}</span>
                        ${isLocked 
                            ? '<span class="badge text-danger-emphasis bg-danger-subtle border border-danger-subtle ms-auto" style="font-size:0.62rem; padding:0.18rem 0.45rem;"><i class="bi bi-lock-fill me-0.5"></i>Bloqueado</span>' 
                            : '<span class="badge text-primary bg-primary-subtle border border-primary-subtle ms-auto" style="font-size:0.62rem; padding:0.18rem 0.45rem;">Quirúrgico</span>'}
                    </label>
                `;
            }
        });
    }

    listContainer.html(html);
    window.todosLosRecursosIds = allIds;

    // Sincronizar estado de selección de checkboxes con memoria
    if (window.recursosChecked === null) {
        const memoriaRec = window.recuperarFiltroMemoria('recursos');
        if (memoriaRec && Array.isArray(memoriaRec) && memoriaRec.length > 0) {
            window.recursosChecked = memoriaRec.filter(id => allIds.includes(id));
            if (window.recursosChecked.length === 0) window.recursosChecked = [...allIds];
        } else {
            window.recursosChecked = [...allIds];
        }
    }
    $('.chk-recurso-item').each(function() {
        const val = $(this).val();
        $(this).prop('checked', window.recursosChecked.includes(val));
    });

    window.actualizarLabelFiltroRecursos();
};

window.toggleSideCalendar = function() {
    const sideCol = $('#dia-side-col');
    const btnToggle = $('#btn-toggle-side-cal');

    if (sideCol.hasClass('d-none')) {
        // Expandir panel
        sideCol.removeClass('d-none');
        localStorage.setItem('agenda_side_collapsed', '0');
        btnToggle.removeClass('btn-teal text-white').addClass('btn-light text-navy')
                 .attr('title', 'Ocultar Minicalendario Lateral');
    } else {
        // Colapsar panel
        sideCol.addClass('d-none');
        localStorage.setItem('agenda_side_collapsed', '1');
        btnToggle.removeClass('btn-light text-navy').addClass('btn-teal text-white')
                 .attr('title', 'Mostrar Minicalendario Lateral');
    }
};

window.aplicarPreferenciaSideCalendar = function() {
    const sideCol = $('#dia-side-col');
    const btnToggle = $('#btn-toggle-side-cal');
    const isCollapsed = localStorage.getItem('agenda_side_collapsed') === '1';

    if (isCollapsed) {
        sideCol.addClass('d-none');
        btnToggle.removeClass('btn-light text-navy').addClass('btn-teal text-white')
                 .attr('title', 'Mostrar Minicalendario Lateral');
    } else {
        if (window.innerWidth >= 992) {
            sideCol.removeClass('d-none');
        }
        btnToggle.removeClass('btn-teal text-white').addClass('btn-light text-navy')
                 .attr('title', 'Ocultar Minicalendario Lateral');
    }
};

window.esEspacioBloqueado = function(espacioStr) {
    if (!espacioStr || !agendaConfig || !Array.isArray(agendaConfig.espacios_bloqueados_list)) return false;
    const normTarget = normalizarTextoEspacio(espacioStr);
    if (!normTarget) return false;
    return agendaConfig.espacios_bloqueados_list.some(eb => {
        const normEb = normalizarTextoEspacio(eb);
        if (!normEb) return false;
        return normEb === normTarget || normTarget.endsWith(normEb) || normEb.endsWith(normTarget);
    });
};

window.actualizarHeaderEspaciosHabilitados = function() {
    const rec = window.sucursalRecursos || {};
    let totalCons = parseInt(rec.consultorios) || 0;
    let totalQx = parseInt(rec.quirofanos) || 0;
    if (rec.sucursales && rec.sucursales.length > 0 && !totalCons && !totalQx) {
        rec.sucursales.forEach(s => {
            totalCons += (parseInt(s.consultorios) || 0);
            totalQx += (parseInt(s.quirofanos) || 0);
        });
    }
    const totalEspacios = Math.max(1, totalCons + totalQx);
    const bloqueadosArr = (agendaConfig && Array.isArray(agendaConfig.espacios_bloqueados_list)) ? agendaConfig.espacios_bloqueados_list : [];
    const numBloqueados = bloqueadosArr.length;
    const habilitados = Math.max(0, totalEspacios - numBloqueados);

    const badgeHeader = document.getElementById('lbl_header_espacios_habilitados');
    if (badgeHeader) {
        if (numBloqueados > 0) {
            badgeHeader.textContent = `${habilitados} Habilitados • ${numBloqueados} Bloqueados`;
        } else {
            badgeHeader.textContent = `${habilitados} Habilitados`;
        }
    }

    // Actualizar opciones bloqueadas en el select #f_consultorio del modal de reserva
    const fCons = document.getElementById('f_consultorio');
    if (fCons) {
        Array.from(fCons.options).forEach(opt => {
            if (!opt.value) return;
            const baseLabel = opt.value;
            const locked = window.esEspacioBloqueado(baseLabel);
            opt.disabled = locked;
            opt.textContent = locked ? `${baseLabel} (Bloqueado)` : baseLabel;
        });
    }
};

window.handleMatrixSlotClick = function(event, fecha, hora, recursoId, recursoTipo) {
    if (event) event.stopPropagation();

    if (window.esEspacioBloqueado(recursoId)) {
        Swal.fire({
            icon: 'warning',
            title: 'Espacio Físico Bloqueado',
            text: 'Este consultorio o quirófano se encuentra bloqueado en Configuración de Espacios. Desmárcalo en Configuración si deseas habilitar nuevas reservas.',
            confirmButtonColor: '#0A2A66',
            customClass: { popup: 'rounded-4' }
        });
        return;
    }

    // Validar si la fecha/hora ya transcurrió
    if (!isFuture(fecha, hora)) {
        Swal.fire({
            icon: 'info',
            title: 'Horario No Disponible',
            text: 'No se pueden agendar citas en horarios o fechas que ya han pasado.',
            customClass: { popup: 'rounded-4' }
        });
        return;
    }

    abrirModalNuevaCita(fecha, hora);

    // Pre-asignar el consultorio o quirófano en #f_consultorio y sucursal si aplica
    if (recursoId) {
        setTimeout(() => {
            if (recursoId.startsWith('suc_')) {
                const parts = recursoId.split('_'); // ['suc', id, 'consultorio', num]
                const sId = parts[1];
                const tipo = parts[2];
                const num = parts[3];
                const fSuc = $('#f_sucursal');
                if (fSuc.length && fSuc.val() !== sId) {
                    fSuc.val(sId).trigger('change');
                }
                setTimeout(() => {
                    const targetText = `${tipo === 'quirofano' ? 'Quirófano' : 'Consultorio'} ${num}`;
                    const consSelect = $('#f_consultorio');
                    if (consSelect.length) {
                        consSelect.find('option').each(function() {
                            if ($(this).text().toLowerCase().includes(targetText.toLowerCase()) || $(this).val().toLowerCase().includes(targetText.toLowerCase())) {
                                consSelect.val($(this).val());
                                return false;
                            }
                        });
                    }
                }, 200);
            } else {
                const consSelect = $('#f_consultorio');
                if (consSelect.length) {
                    let matched = false;
                    consSelect.find('option').each(function() {
                        if ($(this).val().toLowerCase() === recursoId.toLowerCase() || $(this).text().toLowerCase().includes(recursoId.toLowerCase())) {
                            consSelect.val($(this).val());
                            matched = true;
                            return false;
                        }
                    });
                    if (!matched && recursoId.includes('_')) {
                        const num = recursoId.split('_')[1];
                        consSelect.find('option').each(function() {
                            if ($(this).text().includes(num)) {
                                consSelect.val($(this).val());
                                return false;
                            }
                        });
                    }
                }
            }
        }, 150);
    }
};

// POPUP INTERMEDIO DE INSPECCIÓN RÁPIDA (#appointmentQuickModal)
window.openAppointmentQuickDetail = function(id) {
    const a = appointments.find(x => x.id == id);
    if (!a) {
        console.warn("No se encontró la cita con ID:", id);
        return;
    }

    const hi = a.start.split('T')[1].substring(0, 5);
    const hf = a.end.split('T')[1].substring(0, 5);
    const fecha = a.start.split('T')[0];
    const res = resolverEstadoCita(a.extendedProps.estado, fecha, hf);
    const status = res.clave;
    const stLow = status.toLowerCase();

    // Guardar referencia en el modal
    const qModal = $('#appointmentQuickModal');
    qModal.data('cita-id', a.id);
    qModal.data('paciente-id', a.extendedProps.id_paciente);

    // 1. Cabecera con Estado Canónico y Punto de Color Dinámico
    const headerEl = $('#quickModalHeader');
    const dotEl = $('#quickModalDot');
    const estatusEl = $('#quickModalEstatus');

    let bgHeader = '#991B1B';
    let dotColor = '#FCA5A5';

    if (res.esBloqueoPacientes || a.extendedProps.es_bloqueo_pacientes) {
        bgHeader = '#0284C7'; dotColor = '#BAE6FD';
    } else if (res.esEnConsulta) {
        bgHeader = '#059669'; dotColor = '#86EFAC';
    } else if (res.esAtendida) {
        bgHeader = '#064E3B'; dotColor = '#6EE7B7';
    } else if (res.esNoRealizada) {
        bgHeader = '#64748B'; dotColor = '#CBD5E1';
    } else if (stLow.includes('confirmada')) {
        bgHeader = '#CA8A04'; dotColor = '#FEF08A';
    } else if (stLow.includes('cancelada')) {
        bgHeader = '#475569'; dotColor = '#CBD5E1';
    }

    headerEl.css('background-color', bgHeader);
    dotEl.css('background-color', dotColor);
    estatusEl.text(res.clave || status.toUpperCase())
             .css('text-decoration', (res.esNoRealizada || stLow.includes('cancelada')) ? 'line-through' : 'none');

    // 2. Nombre del Arrendatario y Folio
    const pacNom = a.title || a.extendedProps.nombre_arrendatario || a.extendedProps.paciente || 'Arrendatario';
    $('#quickModalPaciente').text(pacNom).attr('title', pacNom);
    const expNum = a.id || '---';
    $('#quickModalExpediente').text(`${expNum}`);

    // Badge y tooltip de Serie por Rango de Fechas
    const notasStr = (a.extendedProps.notas || '');
    const mRango = notasStr.match(/\[Rango:\s*([^|\-\]]+)(?:[|\-]\s*Grupo:\s*([^|\-\]]+))?(?:[|\-]\s*([^\]]+))?\]/);
    if (mRango) {
        const detalleRango = mRango[3] ? mRango[3].trim() : 'Serie';
        const fechasRango = mRango[1] ? mRango[1].trim() : '';
        $('#quickModalRangoBadge')
            .removeClass('d-none')
            .html(`<i class="bi bi-calendar-range me-1"></i>${detalleRango}`)
            .attr('title', `Rango: ${fechasRango} (${mRango[2] ? mRango[2].trim() : ''})`);
    } else {
        $('#quickModalRangoBadge').addClass('d-none');
    }

    // 3. Teléfono de Contacto
    const tel = (a.extendedProps.telefono || '').trim();
    if (tel && tel !== '' && tel !== '--' && tel !== 'No registrado') {
        $('#quickModalTelefonoIcon').attr('class', 'bi bi-telephone-fill text-teal');
        $('#quickModalTelefono').html(`<a href="tel:${tel}" class="text-navy text-decoration-none fw-semibold">${tel}</a>`);
    } else {
        $('#quickModalTelefonoIcon').attr('class', 'bi bi-telephone text-secondary');
        $('#quickModalTelefono').html('<span class="text-muted">No registrado</span>');
    }

    // 4. Tarifa / Monto de Renta
    const montoVal = parseFloat(a.extendedProps.monto_renta || 0).toFixed(2);
    $('#quickModalMedico').text(`Tarifa Renta: $${montoVal}`);

    // 5. Uso / Procedimiento
    const mot = a.extendedProps.motivo || 'Renta de Espacio';
    $('#quickModalMotivo').text(mot).attr('title', mot);

    // 6. Recurso / Espacio Asignado (Consultorio o Quirófano)
    const recursoTxt = a.extendedProps.espacio || a.extendedProps.consultorio || 'Consultorio 1';
    $('#quickModalLugar').text(recursoTxt);

    // 7. Badge de Pago con Alto Contraste
    const pagado = a.extendedProps.pagado === 1 || a.extendedProps.pagado === '1' || a.extendedProps.pagado === true;
    if (a.extendedProps.es_bloqueo_pacientes) {
        $('#quickModalPago')
            .attr('class', 'badge bg-secondary-subtle text-secondary border px-2 py-1 fw-bold')
            .html('<i class="bi bi-shield-lock me-1"></i>Ocupado en Agenda Pacientes');
    } else if (pagado) {
        $('#quickModalPago')
            .attr('class', 'badge bg-success-subtle text-success-emphasis border border-success-subtle px-2 py-1 fw-bold')
            .html('<i class="bi bi-check-circle-fill me-1 text-success"></i>Pagado');
    } else {
        $('#quickModalPago')
            .attr('class', 'badge bg-warning-subtle text-dark border border-warning px-2 py-1 fw-bold')
            .html('<i class="bi bi-clock-history me-1 text-warning"></i>Pendiente de Pago');
    }

    // 8. Tarjeta de Fecha en Amarillo Avena
    const [y, m, d] = fecha.split('-').map(Number);
    const fechaObj = new Date(y, m - 1, d, 12, 0, 0);
    const meses = ['ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO', 'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
    const diasSemana = ['DOMINGO', 'LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO'];

    $('#quickModalMes').text(meses[fechaObj.getMonth()]);
    $('#quickModalDiaNum').text(fechaObj.getDate());
    $('#quickModalDiaSemana').text(diasSemana[fechaObj.getDay()]);
    $('#quickModalHora').text(`${hi} – ${hf}`);

    // 9. Configuración de Botones de Acción
    const btnIniciar = $('#btnQuickIniciarCita');
    const btnExp = $('#btnQuickExpediente');
    const btnEditar = $('#btnQuickEditar');
    const btnCobrar = $('#btnQuickCobrar');
    const btnEliminar = $('#btnQuickEliminar');

    btnIniciar.off('click');
    btnExp.off('click');
    btnEditar.off('click');
    btnCobrar.off('click');
    btnEliminar.off('click');

    if (a.extendedProps.es_bloqueo_pacientes) {
        btnIniciar.prop('disabled', false).removeClass('opacity-50')
            .html('<i class="bi bi-box-arrow-up-right fs-5 me-1.5"></i><span>Ir a Agenda de Pacientes</span>')
            .on('click', function() {
                window.location.href = 'agenda_main.pl';
            });
        btnExp.addClass('d-none');
        btnEditar.addClass('d-none');
        btnCobrar.addClass('d-none');
        btnEliminar.addClass('d-none');
    } else {
        btnExp.removeClass('d-none');
        btnEditar.removeClass('d-none');

        if (stLow.includes('finalizada') || stLow.includes('atendida') || stLow.includes('cancelada')) {
            btnIniciar.prop('disabled', true).addClass('opacity-50')
                .html('<i class="bi bi-check2-circle fs-5 me-1.5"></i><span>Renta Finalizada</span>');
            btnExp.addClass('d-none');
        } else if (stLow.includes('uso') || res.esEnConsulta) {
            btnIniciar.prop('disabled', true).addClass('opacity-75')
                .html('<i class="bi bi-door-open-fill fs-5 me-1.5"></i><span>Espacio En Uso Activo</span>');
            btnExp.html('<i class="bi bi-check2-all text-primary"></i> Finalizar y Liberar').on('click', function() {
                window.cambiarEstadoRentaRapido(a.id, 'Finalizada');
            });
        } else {
            btnIniciar.prop('disabled', false).removeClass('opacity-50')
                .html('<i class="bi bi-play-fill fs-5 me-1.5"></i><span>Iniciar Uso del Espacio</span>')
                .on('click', function() {
                    window.cambiarEstadoRentaRapido(a.id, 'En Uso');
                });
            btnExp.html('<i class="bi bi-check2-all text-primary"></i> Finalizar Uso').on('click', function() {
                window.cambiarEstadoRentaRapido(a.id, 'Finalizada');
            });
        }

        btnEditar.on('click', function() {
            const bsModal = bootstrap.Modal.getInstance(document.getElementById('appointmentQuickModal'));
            if (bsModal) bsModal.hide();
            setTimeout(() => {
                abrirModalCita(a.id, (stLow.includes('finalizada')));
            }, 200);
        });

        if (pagado) {
            btnCobrar.addClass('d-none');
        } else {
            btnCobrar.removeClass('d-none').show().on('click', function() {
                const bsModal = bootstrap.Modal.getInstance(document.getElementById('appointmentQuickModal'));
                if (bsModal) bsModal.hide();
                setTimeout(() => {
                    abrirModalCita(a.id, false);
                    setTimeout(() => cobrarRecepcionModal(), 300);
                }, 200);
            });
        }

        if (stLow.includes('finalizada') || pagado) {
            btnEliminar.addClass('d-none');
        } else {
            btnEliminar.removeClass('d-none').show().on('click', function() {
                const bsModal = bootstrap.Modal.getInstance(document.getElementById('appointmentQuickModal'));
                if (bsModal) bsModal.hide();
                setTimeout(() => {
                    delCita(a.id);
                }, 200);
            });
        }
    }

    const bsModal = bootstrap.Modal.getOrCreateInstance(document.getElementById('appointmentQuickModal'));
    bsModal.show();
};

window.cambiarEstadoRentaRapido = function(idRenta, nuevoEstado) {
    const a = appointments.find(x => x.id == idRenta);
    if (!a) return;
    const hi = a.start.split('T')[1].substring(0, 5);
    const hf = a.end.split('T')[1].substring(0, 5);
    const fecha = a.start.split('T')[0];

    $.post('../api/espacios_crud.pl', {
        accion: 'update',
        id_renta: a.id,
        fecha: fecha,
        hora_ini: hi,
        hora_fin: hf,
        sucursal: a.extendedProps.sucursal || $('#f_sucursal').val(),
        espacio: a.extendedProps.espacio || a.extendedProps.consultorio,
        motivo: a.extendedProps.motivo || 'Renta de Espacio',
        id_arrendatario: a.extendedProps.id_arrendatario || 'EXTERNO',
        nombre_arrendatario: a.title,
        estado: nuevoEstado
    }, function(res) {
        const bsModal = bootstrap.Modal.getInstance(document.getElementById('appointmentQuickModal'));
        if (bsModal) bsModal.hide();
        if (res && res.ok) {
            if (typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'success', title: `Estado: ${nuevoEstado}` });
            loadContext();
        } else {
            Swal.fire('Aviso', (res && res.msg) ? res.msg : 'No se pudo actualizar el estado.', 'warning');
        }
    }, 'json');
};

// Generador de Tarjeta Matriz para Reserva de Espacio
function renderMatrixAptCard(a, interval, maxSlots = 1) {
    const startH = a.start.split('T')[1].substring(0, 5);
    const endH = a.end.split('T')[1].substring(0, 5);
    const aDate = a.start.split('T')[0];
    const res = resolverEstadoCita(a.extendedProps.estado, aDate, endH);
    const status = res.clave;
    const stLow = status.toLowerCase();

    let statusClass = 'status-programada';
    let statusBg = '#991B1B';
    let statusTextCol = '#ffffff';
    let cardCustomStyle = `border-left: 4px solid ${res.color} !important; background-color: ${res.bgCard} !important;`;
    let textStrikeStyle = '';

    if (res.esBloqueoPacientes || a.extendedProps.es_bloqueo_pacientes) {
        statusBg = '#0284C7';
    } else if (res.esEnConsulta) {
        statusClass = 'status-en-consulta';
        statusBg = '#059669';
    } else if (res.esAtendida) {
        statusClass = 'status-atendida';
        statusBg = '#064E3B';
    } else if (res.esNoRealizada) {
        statusClass = 'status-no-realizada';
        statusBg = '#64748B';
        textStrikeStyle = 'text-decoration: line-through;';
    } else if (stLow.includes('confirmada')) {
        statusClass = 'status-confirmada';
        statusBg = '#EAB308';
        statusTextCol = '#1e293b';
    } else if (stLow.includes('cancelada')) {
        statusClass = 'status-cancelada';
        statusBg = '#64748b';
        textStrikeStyle = 'text-decoration: line-through;';
    }

    const pagado = a.extendedProps.pagado === 1 || a.extendedProps.pagado === '1' || a.extendedProps.pagado === true;
    const cardHeightStyle = (maxSlots > 1) 
        ? `height: 100%; min-height: ${(maxSlots * 56) - 10}px;` 
        : `min-height: 48px; height: 100%;`;

    // Evaluación en tiempo real de citas en curso e inminentes
    const todayIso = getISO(new Date());
    const isTodayApt = (aDate === todayIso);
    let isEnCurso = false;
    let progressPct = 0;
    let imminentClass = '';

    if (isTodayApt && !stLow.includes('cancelada') && !stLow.includes('no realizada')) {
        const nowObj = new Date();
        const startMs = new Date(a.start).getTime();
        const endMs = new Date(a.end).getTime();
        const nowMs = nowObj.getTime();
        if (nowMs >= startMs && nowMs <= endMs) {
            isEnCurso = true;
            progressPct = Math.min(100, Math.max(0, ((nowMs - startMs) / (endMs - startMs)) * 100));
        } else if (startMs > nowMs && (startMs - nowMs) <= 15 * 60 * 1000) {
            imminentClass = 'apt-imminent-pulse';
        }
    }

    const enCursoBadge = isEnCurso ? `
        <span class="badge bg-success-subtle text-success border border-success-subtle px-1.5 py-0.5 rounded-pill d-inline-flex align-items-center gap-1" style="font-size:0.60rem;" title="En curso (${Math.round(progressPct)}% completado)">
            <span class="timeline-live-dot" style="width:5px; height:5px; background:#10b981;"></span>
            <span>${Math.round(progressPct)}%</span>
        </span>
    ` : '';

    const progressBarHtml = isEnCurso ? `
        <div class="apt-progress-container" title="Progreso del tiempo: ${Math.round(progressPct)}%">
            <div class="apt-progress-bar" style="width: ${progressPct}%;"></div>
        </div>
    ` : '';

    return `
        <div class="dia-matrix-apt-card ${statusClass} ${imminentClass} animate__animated animate__fadeIn"
             style="${cardHeightStyle} ${cardCustomStyle}"
             onclick="event.stopPropagation(); openAppointmentQuickDetail('${a.id}')"
             title="Clic para inspección rápida">
            <div class="d-flex justify-content-between align-items-center mb-1 gap-1">
                <span class="apt-time-badge text-nowrap" style="${textStrikeStyle}">
                    <i class="bi bi-clock me-1"></i>${startH} - ${endH}
                </span>
                <div class="d-flex align-items-center gap-1">
                    ${enCursoBadge}
                    <span class="badge rounded-pill px-2 py-0.5 text-uppercase fw-bold text-nowrap" style="font-size:0.62rem; background:${statusBg}; color:${statusTextCol}; ${textStrikeStyle}">
                        ${status}
                    </span>
                </div>
            </div>
            <div class="apt-patient-name text-truncate" style="${textStrikeStyle}" title="${a.title}">
                <i class="bi bi-person-fill me-1 opacity-75"></i>${a.title}
            </div>
            <div class="apt-motif text-truncate" style="${textStrikeStyle}" title="${a.extendedProps.motivo || 'Renta de Espacio'}">
                ${a.extendedProps.motivo || 'Renta de Espacio'}
            </div>
            <div class="d-flex align-items-center justify-content-between mt-auto pt-1 border-top border-light-subtle" style="font-size:0.68rem;">
                <span class="text-secondary text-truncate" style="max-width: 75%;">
                    <i class="bi bi-door-open me-0.5 opacity-75"></i>${a.extendedProps.espacio || a.extendedProps.consultorio || 'Espacio'}
                </span>
                ${pagado ? '<i class="bi bi-check-circle-fill text-success" title="Pagado"></i>' : '<i class="bi bi-clock-history text-warning" title="Pendiente de pago"></i>'}
            </div>
            ${progressBarHtml}
        </div>
    `;
}

// Resolver columna asignada para una cita (siempre en Espacio Físico)
function getAppointmentColumnId(a, columns) {
    if (!Array.isArray(columns) || columns.length === 0) return null;
    const rawVal = (a.extendedProps?.consultorio || a.extendedProps?.recurso || a.extendedProps?.lugar || '').trim();
    const normVal = normalizarTextoEspacio(rawVal);
    const aSucId = String(a.extendedProps?.sucursal || a.extendedProps?.id_sucursal || a.extendedProps?.id_negocio || '').trim();

    if (normVal) {
        // 1. Si hay sucursal asociada y coincide con una columna multi-sucursal
        if (aSucId) {
            const matchSuc = columns.find(c => {
                if (c.sucursalId && String(c.sucursalId) !== aSucId) return false;
                const cIdNorm = normalizarTextoEspacio(c.id);
                const cTitNorm = normalizarTextoEspacio(c.titulo);
                return cIdNorm.includes(normVal) || normVal.includes(cTitNorm) || cTitNorm === normVal || cIdNorm === normVal;
            });
            if (matchSuc) return matchSuc.id;
        }

        // 2. Coincidencia directa por ID o Título de Columna
        const col = columns.find(c => {
            const cIdNorm = normalizarTextoEspacio(c.id);
            const cTitNorm = normalizarTextoEspacio(c.titulo);
            return cIdNorm.includes(normVal) || normVal.includes(cTitNorm) || cTitNorm === normVal || cIdNorm === normVal;
        });
        if (col) return col.id;
    }

    // 3. Fallback al primer consultorio disponible
    const firstCons = columns.find(c => c.tipo === 'consultorio') || columns[0];
    return firstCons?.id;
}

// --- RENDER TIMELINE: VISTA DIARIA MATRICIAL DE ESPACIOS FÍSICOS ---
function renderTimeline() {
    renderSideCalendar();
    window.aplicarPreferenciaSideCalendar();

    const cont = $("#timeline-container");
    if (!cont.length) return;

    const iso = getISO(selectedDate);
    const todayIso = getISO(new Date());
    const isPastDay = iso < todayIso;

    // Filtrar citas del día respetando los filtros activos de médicos y espacios
    let dayApts = getFilteredAppointments().filter(a => a.start && a.start.startsWith(iso));

    // Si es un día pasado, renderizar vista ejecutiva o empty state estilizado
    if (isPastDay) {
        if (dayApts.length === 0) {
            cont.html(`
                <div class="agenda-empty-day-card p-5 text-center my-4 animate__animated animate__fadeIn">
                    <div class="empty-icon-circle mx-auto mb-3">
                        <i class="bi bi-calendar-event text-teal fs-1"></i>
                    </div>
                    <h5 class="fw-bold text-navy mb-2">Sin actividad registrada para este día</h5>
                    <p class="text-secondary small mb-4">No se programaron citas ni eventos en la fecha seleccionada (${selectedDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}).</p>
                    <button class="btn btn-outline-teal btn-sm rounded-pill px-4 fw-bold" onclick="goToday()">
                        <i class="bi bi-calendar-check me-1"></i> Volver al Día de Hoy
                    </button>
                </div>
            `);
            return;
        } else {
            let rowsHtml = '';
            const sortedApts = [...dayApts].sort((a,b) => a.start.localeCompare(b.start));
            sortedApts.forEach(a => {
                const startH = a.start.split('T')[1].substring(0, 5);
                const endH = a.end.split('T')[1].substring(0, 5);
                const aDate = a.start.split('T')[0];
                const res = resolverEstadoCita(a.extendedProps.estado, aDate, endH);
                const status = res.clave;
                const badgeClass = res.badgeClass;
                const esTomable = (!status.toLowerCase().includes('atendida') && !status.toLowerCase().includes('cancelada'));

                rowsHtml += `
                    <div class="past-apt-row d-flex flex-wrap align-items-center justify-content-between p-3 mb-2 rounded-3 border bg-white shadow-xs">
                        <div class="d-flex align-items-center gap-3">
                            <div class="text-center px-2 py-1 rounded bg-light border">
                                <span class="d-block fw-bold text-navy small">${startH}</span>
                                <span class="d-block text-muted" style="font-size:0.65rem;">${endH}</span>
                            </div>
                            <div>
                                <span class="d-block fw-bold text-navy cursor-pointer hover-teal" onclick="openAppointmentQuickDetail('${a.id}')">${a.title}</span>
                                <small class="text-secondary d-block"><i class="bi bi-tag me-1"></i>${a.extendedProps.motivo || 'Consulta'}</small>
                            </div>
                        </div>
                        <div class="d-flex align-items-center gap-2 mt-2 mt-md-0">
                            <span class="badge ${badgeClass} rounded-pill px-3 py-1 fw-bold text-uppercase" style="font-size:0.68rem; letter-spacing:0.5px;">${status}</span>
                            ${esTomable ? `
                                <button type="button" class="btn btn-sm btn-success rounded-pill px-3 fw-bold shadow-sm" onclick="event.stopPropagation(); window.tomarCitaDirecto('${a.id}', '${a.extendedProps.id_paciente}')" title="Tomar Cita Ahora">
                                    <i class="bi bi-play-circle me-1"></i> Tomar Cita
                                </button>
                                <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-2" onclick="event.stopPropagation(); abrirModalCita('${a.id}')" title="Re-agendar / Modificar">
                                    <i class="bi bi-pencil-square"></i>
                                </button>
                            ` : ''}
                            <button type="button" class="btn btn-sm btn-outline-primary rounded-pill px-3" onclick="event.stopPropagation(); window.open('render_expediente_clinico.pl?id=${a.extendedProps.id_paciente}', '_blank')" title="Ver Expediente">
                                <i class="bi bi-person-vcard me-1"></i> Expediente
                            </button>
                            <button type="button" class="btn btn-sm btn-light border rounded-pill px-2" onclick="event.stopPropagation(); openAppointmentQuickDetail('${a.id}')" title="Ver Detalle Rápido">
                                <i class="bi bi-eye"></i>
                            </button>
                        </div>
                    </div>
                `;
            });

            cont.html(`
                <div class="agenda-past-day-container p-4 rounded-4 shadow-sm bg-white animate__animated animate__fadeIn">
                    <div class="d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom">
                        <div>
                            <h5 class="fw-bold text-navy m-0"><i class="bi bi-clock-history me-2 text-teal"></i>Historial de Citas del Día</h5>
                            <small class="text-secondary">${selectedDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })} • ${sortedApts.length} cita(s) registrada(s)</small>
                        </div>
                        <button class="btn btn-sm btn-outline-teal rounded-pill px-3 fw-bold" onclick="goToday()">
                            <i class="bi bi-calendar-check me-1"></i> Ir a Hoy
                        </button>
                    </div>
                    <div class="past-apts-list">
                        ${rowsHtml}
                    </div>
                </div>
            `);
            return;
        }
    }

    // 1. RESOLVER COLUMNAS DE ESPACIOS FÍSICOS (Consultorios y Quirófanos)
    let columns = [];
    const recData = window.sucursalRecursos || {};
    const esUnica = (recData && (recData.es_unica === 1 || recData.es_unica === true || recData.es_unica === "1")) || 
                    (!recData || !recData.sucursales || recData.sucursales.length <= 1);

    if (esUnica) {
        let numCons = parseInt(recData.consultorios) || 0;
        let numQx = parseInt(recData.quirofanos) || 0;
        if (recData.sucursales && recData.sucursales.length > 0) {
            if (!numCons && recData.sucursales[0].consultorios) numCons = parseInt(recData.sucursales[0].consultorios);
            if (!numQx && recData.sucursales[0].quirofanos) numQx = parseInt(recData.sucursales[0].quirofanos);
        }
        numCons = Math.max(1, numCons);

        if (numCons > 0) {
            for (let i = 1; i <= numCons; i++) {
                columns.push({
                    id: `consultorio_${i}`,
                    tipo: 'consultorio',
                    titulo: `Consultorio ${i}`,
                    subtitulo: 'Consulta Médica',
                    badge: `Cons ${i}`
                });
            }
        }

        if (numQx > 0) {
            for (let i = 1; i <= numQx; i++) {
                columns.push({
                    id: `quirofano_${i}`,
                    tipo: 'quirofano',
                    titulo: `Quirófano ${i}`,
                    subtitulo: 'Cirugía / Procedimientos',
                    badge: `Qx ${i}`
                });
            }
        }
    } else {
        // Múltiples sucursales: generar columnas agrupadas por sucursal
        recData.sucursales.forEach(s => {
            const sId = s.id;
            const sNom = s.nombre || `Sucursal ${sId}`;
            const numCons = parseInt(s.consultorios) || 1;
            const numQx = parseInt(s.quirofanos) || 0;

            for (let i = 1; i <= numCons; i++) {
                columns.push({
                    id: `suc_${sId}_consultorio_${i}`,
                    sucursalId: sId,
                    sucursalNombre: sNom,
                    tipo: 'consultorio',
                    titulo: `Cons ${i}`,
                    subtitulo: sNom,
                    badge: `${sNom.substring(0, 3)} C${i}`
                });
            }

            for (let i = 1; i <= numQx; i++) {
                columns.push({
                    id: `suc_${sId}_quirofano_${i}`,
                    sucursalId: sId,
                    sucursalNombre: sNom,
                    tipo: 'quirofano',
                    titulo: `Qx ${i}`,
                    subtitulo: sNom,
                    badge: `${sNom.substring(0, 3)} Q${i}`
                });
            }
        });
    }

    if (columns.length === 0) {
        columns.push(
            { id: 'consultorio_1', tipo: 'consultorio', titulo: 'Consultorio 1', subtitulo: 'Medicina General', badge: 'Cons 1' },
            { id: 'consultorio_2', tipo: 'consultorio', titulo: 'Consultorio 2', subtitulo: 'Especialidades', badge: 'Cons 2' },
            { id: 'quirofano_1', tipo: 'quirofano', titulo: 'Quirófano 1', subtitulo: 'Cirugía Ambulatoria', badge: 'Qx 1' }
        );
    }

    // Incorporar recursos adicionales de citas si existen
    dayApts.forEach(a => {
        const cVal = (a.extendedProps.consultorio || a.extendedProps.recurso || '').trim();
        if (cVal) {
            const low = cVal.toLowerCase();
            const exists = columns.some(c => c.titulo.toLowerCase() === low || c.id.toLowerCase() === low);
            if (!exists) {
                const esQx = low.includes('quir') || low.includes('qx') || low.includes('cirug');
                columns.push({
                    id: cVal.toLowerCase().replace(/\s+/g, '_'),
                    tipo: esQx ? 'quirofano' : 'consultorio',
                    titulo: cVal,
                    subtitulo: esQx ? 'Procedimientos' : 'Atención Médica',
                    badge: esQx ? 'Qx' : 'Cons'
                });
            }
        }
    });

    // Sincronizar el selector superior de recursos si está vacío
    if ($('#lista_checkboxes_recursos .chk-recurso-item').length === 0) {
        window.poblarFiltroRecursosToolbar(recData);
    }

    // 2. APLICAR FILTRO MULTI-CHECK DE ESPACIOS FÍSICOS
    let colsToRender = columns;
    if (Array.isArray(window.recursosChecked)) {
        if (window.recursosChecked.length === 0) {
            colsToRender = []; // Ningún espacio marcado
        } else if (window.recursosChecked.length < columns.length) {
            colsToRender = columns.filter(c => window.recursosChecked.includes(c.id));
        }
    }

    // Si el usuario desmarcó todos los espacios, mostrar estado vacío amigable
    if (colsToRender.length === 0) {
        $('#timeline-container').html(`
            <div class="dia-matrix-card card shadow-sm border-0 rounded-4 overflow-hidden animate__animated animate__fadeIn p-5 d-flex flex-column align-items-center justify-content-center text-center" style="min-height: 420px; background-color:#ffffff;">
                <div class="mb-3 p-3 rounded-circle bg-light d-inline-flex align-items-center justify-content-center" style="width: 76px; height: 76px;">
                    <i class="bi bi-funnel text-teal" style="font-size: 2.2rem;"></i>
                </div>
                <h5 class="fw-black text-navy mb-1.5">No hay espacios físicos seleccionados</h5>
                <p class="text-secondary small mb-3.5" style="max-width: 400px; font-size: 0.85rem;">
                    Has desmarcado todos los consultorios y quirófanos. Haz clic en el selector de <strong>Espacios Físicos</strong> arriba para marcar los que deseas visualizar en la agenda.
                </p>
                <button type="button" class="btn btn-teal text-white fw-bold btn-sm rounded-3 px-3.5 py-2 shadow-sm" onclick="window.seleccionarTodosEspacios(true)">
                    <i class="bi bi-check2-all me-1.5"></i> Mostrar todos los espacios
                </button>
            </div>
        `);
        return;
    }

    // 3. PARÁMETROS HORARIOS
    const lStart = agendaConfig.laborStart || '08:00';
    const lEnd = agendaConfig.laborEnd || '20:00';
    const [lsH, lsM] = lStart.split(':').map(Number);
    const [leH, leM] = lEnd.split(':').map(Number);
    
    let startMin = (lsH || 0) * 60 + (lsM || 0);
    let endMin = (leH || 0) * 60 + (leM || 0);

    // Si termina en 23:59, 23:55 o 24:00 (o si cubre 24 horas continuas), extender hasta 1440 min (24:00)
    if (endMin <= startMin || (leH === 23 && leM >= 50) || lEnd === '23:59' || lEnd === '24:00') {
        endMin = 1440;
    }

    const interval = parseInt(agendaConfig.intervalo_minutos || 30);
    const holiday = isHoliday(iso);

    // 4. CONSTRUCCIÓN DE LA MATRIZ TABLE
    const isTodayView = (iso === todayIso);
    const nowTimeObj = new Date();
    const nowTotalMin = nowTimeObj.getHours() * 60 + nowTimeObj.getMinutes();

    let tableHtml = `
        <div class="dia-matrix-card card shadow-sm border-0 rounded-4 overflow-hidden animate__animated animate__fadeIn">
            <!-- MINI-MAPA INTELIGENTE DEL DÍA -->
            <div class="timeline-day-minimap d-flex align-items-center justify-content-between" id="timeline-day-minimap">
                <div class="d-flex align-items-center gap-2 flex-shrink-0">
                    <span class="badge ${isTodayView ? 'bg-danger text-white' : 'bg-secondary text-white'} rounded-pill px-2.5 py-1 d-inline-flex align-items-center gap-1 shadow-2xs" style="font-size:0.68rem; font-weight:800; letter-spacing: 0.3px;">
                        <span class="timeline-live-dot" style="width:6px; height:6px; background:#ffffff;"></span>
                        <span>${isTodayView ? 'HOY EN VIVO' : 'HISTORIAL'}</span>
                    </span>
                    <span class="minimap-time-range text-muted fw-bold d-none d-md-inline" style="font-size:0.70rem;">
                        <i class="bi bi-clock me-1"></i>${lStart} - ${lEnd}
                    </span>
                </div>
                <div class="minimap-track-container position-relative flex-grow-1 mx-2 mx-md-3" onclick="window.handleMinimapClick(event)" title="Haz clic en la barra para desplazarte rápidamente a esa hora">
                    <div class="minimap-track">
                        <div class="minimap-past-fill" id="minimap-past-fill"></div>
                        <div class="minimap-events-layer" id="minimap-events-layer"></div>
                        <div class="minimap-marker ${isTodayView ? '' : 'd-none'}" id="minimap-marker" title="Momento actual">
                            <span class="minimap-marker-dot"></span>
                        </div>
                    </div>
                </div>
                <div class="d-flex align-items-center gap-2 flex-shrink-0">
                    <span class="badge bg-white border text-navy fw-bold d-none d-sm-inline-flex align-items-center gap-1 shadow-2xs" id="minimap-now-clock" style="font-size:0.72rem; color: #0A2A66;">
                        <i class="bi bi-clock-fill text-danger me-1"></i><span id="minimap-clock-val">--:--</span>
                    </span>
                    <button type="button" class="btn btn-timeline-now" onclick="window.scrollToLiveTimeline(true)" title="Centrar matriz en hora actual (Ahora)">
                        <i class="bi bi-crosshair"></i>
                        <span>Ir a Ahora</span>
                    </button>
                </div>
            </div>

            <div class="dia-matrix-responsive position-relative">
                <!-- LÍNEA DE TIEMPO EN VIVO (RED TIMELINE INDICATOR) -->
                <div id="dia-live-timeline-line" class="dia-live-timeline-line d-none">
                    <div class="timeline-live-time-pill" id="timeline-live-time-pill" title="Hora actual">
                        <span class="timeline-live-dot"></span>
                        <span id="timeline-live-time-text">--:--</span>
                    </div>
                    <div class="timeline-live-triangle"></div>
                    <div class="timeline-live-next-badge" id="timeline-live-next-badge" title="Próximo evento programado">
                        <i class="bi bi-bell-fill text-warning"></i>
                        <span id="timeline-live-next-text">Calculando...</span>
                    </div>
                </div>
                <table class="dia-matrix-table">
                    <thead>
                        <tr>
                            <th class="time-col text-center" style="width: 80px; min-width: 80px;">
                                <span class="small fw-bold text-muted text-uppercase" style="font-size:0.7rem; letter-spacing:0.5px;">HORA</span>
                            </th>
    `;

    colsToRender.forEach(col => {
        const isQuirofano = (col.tipo === 'quirofano');
        const isColLocked = window.esEspacioBloqueado(col.titulo) || window.esEspacioBloqueado(col.id);
        const headerClass = isQuirofano ? 'dia-col-quirofano' : 'dia-col-consultorio';
        const icon = isColLocked
            ? '<i class="bi bi-lock-fill me-1 text-danger"></i>'
            : (isQuirofano 
                ? '<i class="bi bi-scissors me-1" style="color:#7C3AED;"></i>' 
                : '<i class="bi bi-door-closed-fill me-1" style="color:var(--md-teal-clinical, #19B7A5);"></i>');

        // En la píldora va el icono + etiqueta + número (Consultorio 1 / Quirófano 1)
        const typeBadge = isQuirofano 
            ? `<span class="dia-th-badge dia-th-badge-quirofano">${icon}${col.titulo}</span>` 
            : `<span class="dia-th-badge dia-th-badge-consultorio">${icon}${col.titulo}</span>`;
        const subtitleHtml = isColLocked
            ? `<span class="badge bg-danger text-white" style="font-size: 0.65rem;">BLOQUEADO</span>`
            : col.subtitulo;

        tableHtml += `
            <th class="${headerClass} text-center">
                <div class="dia-th-container d-flex flex-column align-items-center justify-content-center py-1">
                    <div class="dia-th-badge-wrapper mb-1">
                        ${typeBadge}
                    </div>
                    <div class="dia-th-title fw-black text-navy text-truncate w-100 px-1" title="${col.subtitulo}" style="color: #0A2A66 !important; font-size: 0.88rem; font-weight: 800;">
                        ${subtitleHtml}
                    </div>
                </div>
            </th>
        `;
    });

    tableHtml += `
                </tr>
            </thead>
            <tbody>
    `;

    // Mapa para controlar celdas cubiertas por rowspan en filas subsecuentes
    const activeRowspans = {};

    for (let curMin = startMin; curMin < endMin; curMin += interval) {
        const h = Math.floor(curMin / 60);
        const m = curMin % 60;
        const hStr = h.toString().padStart(2, '0');
        const mStr = m.toString().padStart(2, '0');
        const hhmm = `${hStr}:${mStr}`;
        const isP = !isFuture(iso, hhmm);

        const slotStartMin = curMin;
        const slotEndMin = slotStartMin + interval;

            tableHtml += `
                <tr>
                    <td class="time-col text-center">
                        <span class="dia-matrix-time-label">${hhmm}</span>
                    </td>
            `;

            colsToRender.forEach(col => {
                // Si esta columna ya está cubierta por un rowspan de un slot previo, omitimos el <td>
                if (activeRowspans[col.id] && activeRowspans[col.id] > 0) {
                    activeRowspans[col.id]--;
                    return;
                }

                // Citas que inician exactamente dentro de este slot para esta columna
                const aptsStartingHere = dayApts.filter(a => {
                    const aColId = getAppointmentColumnId(a, columns);
                    if (aColId !== col.id) return false;
                    const aHi = a.start.split('T')[1].substring(0, 5);
                    const [ah, am] = aHi.split(':').map(Number);
                    const aptStartMin = ah * 60 + am;
                    return (aptStartMin >= slotStartMin && aptStartMin < slotEndMin);
                });

                const isPastSlot = isTodayView && (slotEndMin <= nowTotalMin);
                const isCurrentSlot = isTodayView && (nowTotalMin >= slotStartMin && nowTotalMin < slotEndMin);
                const dynamicSlotClass = isCurrentSlot ? 'slot-current-dynamic' : (isPastSlot ? 'slot-past-dynamic' : '');
                const cellClass = (isP || holiday || isPastSlot) ? `slot-past ${dynamicSlotClass}` : dynamicSlotClass;

                if (aptsStartingHere.length > 0) {
                    // Calcular la máxima duración en slots para aplicar rowspan exacto
                    let maxSlots = 1;
                    aptsStartingHere.forEach(a => {
                        const startMs = new Date(a.start).getTime();
                        const endMs = new Date(a.end).getTime();
                        let durMin = (endMs - startMs) / 60000;
                        if (isNaN(durMin) || durMin <= 0) durMin = interval;
                        const sCount = Math.max(1, Math.round(durMin / interval));
                        if (sCount > maxSlots) maxSlots = sCount;
                    });

                    // Si abarca más de 1 slot, reservamos los slots siguientes a saltar
                    if (maxSlots > 1) {
                        activeRowspans[col.id] = maxSlots - 1;
                    }

                    const rowspanAttr = maxSlots > 1 ? `rowspan="${maxSlots}"` : '';
                    const slotHeight = maxSlots * 56;

                    tableHtml += `
                        <td class="dia-matrix-slot has-appointment ${cellClass}" 
                            ${rowspanAttr}
                            style="height: ${slotHeight}px;"
                            onclick="handleMatrixSlotClick(event, '${iso}', '${hhmm}', '${col.id}', '${col.tipo}')">
                            ${aptsStartingHere.map(a => renderMatrixAptCard(a, interval, maxSlots)).join('')}
                        </td>
                    `;
                } else {
                    tableHtml += `
                        <td class="dia-matrix-slot ${cellClass}" 
                            onclick="handleMatrixSlotClick(event, '${iso}', '${hhmm}', '${col.id}', '${col.tipo}')">
                        </td>
                    `;
                }
            });

            tableHtml += `</tr>`;
    }

    tableHtml += `
                    </tbody>
                </table>
                <div class="dia-matrix-bottom-spacer" style="height: 60px; width: 100%; pointer-events: none;"></div>
            </div>
        </div>
    `;

    cont.html(tableHtml);
    initMatrixScrollEdgeDetector();
    window.updateLiveTimeline();
}

// ==========================================================================
// MOTOR DE LÍNEA DE TIEMPO EN VIVO (TIMELINE LIVE ENGINE)
// ==========================================================================

window.initLiveTimeline = function() {
    if (window._liveTimelineInterval) {
        clearInterval(window._liveTimelineInterval);
    }
    // Actualizar cada 15 segundos para máxima fluidez y precisión
    window._liveTimelineInterval = setInterval(() => {
        if (typeof currentView !== 'undefined' && currentView === 'dia') {
            window.updateLiveTimeline();
        }
    }, 15000);

    window.addEventListener('resize', () => {
        if (typeof currentView !== 'undefined' && currentView === 'dia') {
            window.updateLiveTimeline();
        }
    });
};

window.updateLiveTimeline = function() {
    if (typeof currentView === 'undefined' || currentView !== 'dia') return;
    
    const scroller = document.querySelector('.dia-matrix-responsive');
    const table = document.querySelector('.dia-matrix-table');
    const line = document.getElementById('dia-live-timeline-line');
    const pill = document.getElementById('timeline-live-time-text');
    const nextBadge = document.getElementById('timeline-live-next-badge');
    const nextText = document.getElementById('timeline-live-next-text');
    const minimapMarker = document.getElementById('minimap-marker');
    const minimapPastFill = document.getElementById('minimap-past-fill');
    const minimapClock = document.getElementById('minimap-clock-val');
    const minimapEventsLayer = document.getElementById('minimap-events-layer');

    if (!scroller || !table || !line) return;

    const now = new Date();
    const todayIso = getISO(now);
    const isToday = (getISO(selectedDate) === todayIso);

    // Formatear reloj digital HH:MM
    const nowH = now.getHours();
    const nowM = now.getMinutes();
    const nowS = now.getSeconds();
    const nowTimeStr = `${String(nowH).padStart(2, '0')}:${String(nowM).padStart(2, '0')}`;

    if (minimapClock) minimapClock.textContent = nowTimeStr;
    if (pill) pill.textContent = nowTimeStr;

    // Si NO es el día de hoy, ocultar línea de tiempo en vivo
    if (!isToday) {
        line.classList.add('d-none');
        if (minimapMarker) minimapMarker.classList.add('d-none');
        if (minimapPastFill) minimapPastFill.style.width = '0%';
        return;
    }

    // Configuración de límites del día en minutos
    const lStart = (typeof agendaConfig !== 'undefined' && agendaConfig.laborStart) || '08:00';
    const lEnd = (typeof agendaConfig !== 'undefined' && agendaConfig.laborEnd) || '20:00';
    const [lsH, lsM] = lStart.split(':').map(Number);
    const [leH, leM] = lEnd.split(':').map(Number);
    
    let startMin = (lsH || 0) * 60 + (lsM || 0);
    let endMin = (leH || 0) * 60 + (leM || 0);
    if (endMin <= startMin || (leH === 23 && leM >= 50) || lEnd === '23:59' || lEnd === '24:00') {
        endMin = 1440;
    }

    const totalMinutes = Math.max(1, endMin - startMin);
    const currentTotalMin = nowH * 60 + nowM + (nowS / 60);
    const elapsedMinutes = currentTotalMin - startMin;

    // Calcular posición porcentual (0 a 1)
    const rawPct = elapsedMinutes / totalMinutes;
    const clampedPct = Math.min(1, Math.max(0, rawPct));
    const pct100 = (clampedPct * 100).toFixed(2);

    // Actualizar Mini-Mapa
    if (minimapMarker) {
        minimapMarker.classList.remove('d-none');
        minimapMarker.style.left = `${pct100}%`;
    }
    if (minimapPastFill) {
        minimapPastFill.style.width = `${pct100}%`;
    }

    // Renderizar bloques de eventos en el mini-mapa si aún no están
    if (minimapEventsLayer && !minimapEventsLayer.hasChildNodes()) {
        const dayApts = (typeof getFilteredAppointments === 'function') 
            ? getFilteredAppointments().filter(a => a.start && a.start.startsWith(todayIso)) 
            : [];
        let evHtml = '';
        dayApts.forEach(a => {
            const aHi = a.start.split('T')[1]?.substring(0, 5) || '00:00';
            const aHf = a.end.split('T')[1]?.substring(0, 5) || '00:00';
            const [sh, sm] = aHi.split(':').map(Number);
            const [eh, em] = aHf.split(':').map(Number);
            const aStartMin = sh * 60 + sm;
            const aEndMin = eh * 60 + em;
            const evLeftPct = Math.min(100, Math.max(0, ((aStartMin - startMin) / totalMinutes) * 100));
            const evWidthPct = Math.min(100 - evLeftPct, Math.max(1.5, ((aEndMin - aStartMin) / totalMinutes) * 100));
            evHtml += `<div class="minimap-event-block" style="left:${evLeftPct}%; width:${evWidthPct}%;" title="${a.title} (${aHi} - ${aHf})"></div>`;
        });
        minimapEventsLayer.innerHTML = evHtml;
    }

    // Ubicación en la tabla de la matriz
    const tbody = table.querySelector('tbody');
    if (!tbody) {
        line.classList.add('d-none');
        return;
    }

    const tbodyTop = tbody.offsetTop;
    const tbodyHeight = tbody.offsetHeight;

    // Si estamos dentro del rango del horario operativo
    if (currentTotalMin >= startMin && currentTotalMin <= endMin) {
        line.classList.remove('d-none');
        const topPx = tbodyTop + (rawPct * tbodyHeight);
        line.style.top = `${Math.round(topPx)}px`;
    } else if (currentTotalMin < startMin) {
        // Antes de la apertura: posicionar al inicio con etiqueta
        line.classList.remove('d-none');
        line.style.top = `${tbodyTop}px`;
    } else {
        // Después del cierre de jornada
        line.classList.add('d-none');
    }

    // Calcular próximo evento o evento en curso
    const dayApts = (typeof getFilteredAppointments === 'function') 
        ? getFilteredAppointments().filter(a => a.start && a.start.startsWith(todayIso)) 
        : [];

    const nowMs = now.getTime();
    let activeApt = null;
    let nextApt = null;
    let minDiffToNext = Infinity;

    dayApts.forEach(a => {
        const startMs = new Date(a.start).getTime();
        const endMs = new Date(a.end).getTime();
        if (nowMs >= startMs && nowMs <= endMs) {
            if (!activeApt) activeApt = a;
        } else if (startMs > nowMs) {
            const diffMin = Math.round((startMs - nowMs) / 60000);
            if (diffMin < minDiffToNext) {
                minDiffToNext = diffMin;
                nextApt = a;
            }
        }
    });

    if (nextBadge && nextText) {
        if (activeApt) {
            const endH = activeApt.end.split('T')[1].substring(0, 5);
            const leftMin = Math.max(1, Math.round((new Date(activeApt.end).getTime() - nowMs) / 60000));
            nextBadge.innerHTML = `<i class="bi bi-play-circle-fill text-success"></i><span>En curso: <strong>${activeApt.title}</strong> (termina ${endH}, restan ${leftMin}m)</span>`;
            nextBadge.classList.remove('d-none');
        } else if (nextApt) {
            const startH = nextApt.start.split('T')[1].substring(0, 5);
            nextBadge.innerHTML = `<i class="bi bi-bell-fill text-warning"></i><span>Próximo: <strong>${nextApt.title}</strong> a las ${startH} (en ${minDiffToNext}m)</span>`;
            nextBadge.classList.remove('d-none');
        } else {
            nextBadge.innerHTML = `<i class="bi bi-check2-circle text-teal"></i><span>Sin más eventos pendientes hoy</span>`;
            nextBadge.classList.remove('d-none');
        }
    }
};

window.scrollToLiveTimeline = function(smooth = true) {
    const todayIso = getISO(new Date());
    if (getISO(selectedDate) !== todayIso) {
        goToday();
        setTimeout(() => {
            window.scrollToLiveTimeline(smooth);
        }, 350);
        return;
    }

    const scroller = document.querySelector('.dia-matrix-responsive');
    const line = document.getElementById('dia-live-timeline-line');
    if (!scroller || !line) return;

    // Centrar la línea en el tercio superior o centro de la pantalla
    const targetScroll = Math.max(0, line.offsetTop - (scroller.clientHeight / 3));
    scroller.scrollTo({
        top: targetScroll,
        behavior: smooth ? 'smooth' : 'auto'
    });

    // Pequeño realce visual temporal (halo flash)
    line.style.boxShadow = '0 0 24px #ff0000, 0 0 40px rgba(255, 0, 0, 0.8)';
    setTimeout(() => {
        line.style.boxShadow = '';
    }, 1200);
};

window.handleMinimapClick = function(event) {
    const track = event.currentTarget.querySelector('.minimap-track');
    if (!track) return;
    const rect = track.getBoundingClientRect();
    const clickX = event.clientX - rect.left;
    const clickPct = Math.min(1, Math.max(0, clickX / rect.width));

    const scroller = document.querySelector('.dia-matrix-responsive');
    const table = document.querySelector('.dia-matrix-table');
    if (!scroller || !table) return;

    const tbody = table.querySelector('tbody');
    if (!tbody) return;

    const targetTop = tbody.offsetTop + (clickPct * tbody.offsetHeight) - (scroller.clientHeight / 3);
    scroller.scrollTo({
        top: Math.max(0, targetTop),
        behavior: 'smooth'
    });
};

// --- DETECTOR INTELIGENTE DE LÍMITES DE SCROLL (INFINITE DAY OVER-SCROLL) ---
let isChangingDayScroll = false;
let topOverscrollDelta = 0;
let bottomOverscrollDelta = 0;
let scrollEdgeTimeout = null;

function initMatrixScrollEdgeDetector() {
    const scroller = document.querySelector('.dia-matrix-responsive');
    if (!scroller || !scroller.parentElement) return;

    // Crear elementos de aviso flotante si no existen
    let topBanner = document.getElementById('dia-edge-banner-top');
    if (!topBanner) {
        topBanner = document.createElement('div');
        topBanner.id = 'dia-edge-banner-top';
        topBanner.className = 'dia-scroll-edge-banner edge-top animate__animated d-none';
        scroller.parentElement.appendChild(topBanner);
    }

    let bottomBanner = document.getElementById('dia-edge-banner-bottom');
    if (!bottomBanner) {
        bottomBanner = document.createElement('div');
        bottomBanner.id = 'dia-edge-banner-bottom';
        bottomBanner.className = 'dia-scroll-edge-banner edge-bottom animate__animated d-none';
        scroller.parentElement.appendChild(bottomBanner);
    }

    // Calcular nombres de días anterior y siguiente
    const curDate = new Date(selectedDate);
    const prevDate = new Date(curDate); prevDate.setDate(curDate.getDate() - 1);
    const nextDate = new Date(curDate); nextDate.setDate(curDate.getDate() + 1);

    const prevDayName = prevDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'short' });
    const nextDayName = nextDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'short' });

    topBanner.innerHTML = `
        <div class="d-flex align-items-center justify-content-between gap-3 px-3 py-2 text-white rounded-pill shadow-lg border border-teal" style="font-size: 0.8rem; background-color: #0A2A66 !important;">
            <div class="d-flex align-items-center gap-2">
                <i class="bi bi-arrow-up-circle-fill text-teal fs-6 animate__animated animate__bounce animate__infinite"></i>
                <span>Tope superior alcanzado (00:00). Continúa deslizando o haz clic para ir a: <strong>${prevDayName}</strong></span>
            </div>
            <button type="button" class="btn btn-teal btn-sm rounded-pill px-3 py-1 fw-bold text-white shadow-xs" onclick="transicionarDiaScroll(-1)">
                <i class="bi bi-chevron-left me-1"></i> Ir a ${prevDayName}
            </button>
        </div>
    `;

    bottomBanner.innerHTML = `
        <div class="d-flex align-items-center justify-content-between gap-3 px-3 py-2 text-white rounded-pill shadow-lg border border-teal" style="font-size: 0.8rem; background-color: #0A2A66 !important;">
            <div class="d-flex align-items-center gap-2">
                <i class="bi bi-arrow-down-circle-fill text-teal fs-6 animate__animated animate__bounce animate__infinite"></i>
                <span>Fin de jornada alcanzado (23:59). Continúa deslizando o haz clic para pasar a: <strong>${nextDayName}</strong></span>
            </div>
            <button type="button" class="btn btn-teal btn-sm rounded-pill px-3 py-1 fw-bold text-white shadow-xs" onclick="transicionarDiaScroll(1)">
                Ir a ${nextDayName} <i class="bi bi-chevron-right ms-1"></i>
            </button>
        </div>
    `;

    // Resetear contadores
    topOverscrollDelta = 0;
    bottomOverscrollDelta = 0;

    // Escuchador de rueda de scroll
    scroller.onwheel = function(e) {
        if (isChangingDayScroll) return;

        const isAtTop = scroller.scrollTop <= 4;
        const isAtBottom = (scroller.scrollTop + scroller.clientHeight) >= (scroller.scrollHeight - 10);

        // Desplazamiento hacia arriba en el tope superior
        if (isAtTop && e.deltaY < 0) {
            topOverscrollDelta += Math.abs(e.deltaY);
            topBanner.classList.remove('d-none');
            
            clearTimeout(scrollEdgeTimeout);
            scrollEdgeTimeout = setTimeout(() => {
                topBanner.classList.add('d-none');
                topOverscrollDelta = 0;
            }, 1800);

            if (topOverscrollDelta > 220) {
                transicionarDiaScroll(-1);
            }
        } else if (!isAtTop) {
            topBanner.classList.add('d-none');
            topOverscrollDelta = 0;
        }

        // Desplazamiento hacia abajo en el fondo
        if (isAtBottom && e.deltaY > 0) {
            bottomOverscrollDelta += Math.abs(e.deltaY);
            bottomBanner.classList.remove('d-none');

            clearTimeout(scrollEdgeTimeout);
            scrollEdgeTimeout = setTimeout(() => {
                bottomBanner.classList.add('d-none');
                bottomOverscrollDelta = 0;
            }, 1800);

            if (bottomOverscrollDelta > 220) {
                transicionarDiaScroll(1);
            }
        } else if (!isAtBottom) {
            bottomBanner.classList.add('d-none');
            bottomOverscrollDelta = 0;
        }
    };
}

function transicionarDiaScroll(dir) {
    if (isChangingDayScroll) return;
    isChangingDayScroll = true;

    const toast = Swal.mixin({
        toast: true,
        position: dir < 0 ? 'top' : 'bottom',
        showConfirmButton: false,
        timer: 1200,
        timerProgressBar: true
    });
    
    selectedDate.setDate(selectedDate.getDate() + dir);
    const dayStr = selectedDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long' });
    
    toast.fire({
        icon: 'info',
        title: dir < 0 ? `⬅ Día Anterior: ${dayStr}` : `➡ Siguiente Día: ${dayStr}`
    });

    renderHeaders();
    renderView();

    setTimeout(() => {
        const scroller = document.querySelector('.dia-matrix-responsive');
        if (scroller) {
            if (dir < 0) {
                // Al retroceder, situar al final del día
                scroller.scrollTop = scroller.scrollHeight - scroller.clientHeight - 80;
            } else {
                // Al avanzar, situar al inicio del día
                scroller.scrollTop = 5;
            }
        }
        isChangingDayScroll = false;
    }, 280);
}
window.transicionarDiaScroll = transicionarDiaScroll;

function renderSideCalendar() {
    const cont = $("#side-datepicker"); if(!cont.length) return;
    
    const y = selectedDate.getFullYear(); const m = selectedDate.getMonth();
    const meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    const fd = (new Date(y, m, 1).getDay() || 7) - 1;
    const days = new Date(y, m + 1, 0).getDate();
    
    let html = `
        <div class="side-cal-wrapper">
            <div class="side-cal-header d-flex align-items-center justify-content-between mb-3 px-1">
                <button type="button" class="btn btn-sm side-cal-nav-btn" onclick="prevSideMonth()" title="Mes anterior">
                    <i class="bi bi-chevron-left"></i>
                </button>
                <span class="fw-bold text-navy side-cal-month-title">${meses[m]} ${y}</span>
                <button type="button" class="btn btn-sm side-cal-nav-btn" onclick="nextSideMonth()" title="Mes siguiente">
                    <i class="bi bi-chevron-right"></i>
                </button>
            </div>
            <div class="side-cal-grid">
    `;
    
    ['L','M','M','J','V','S','D'].forEach(d => {
        html += `<div class="text-center small fw-bold text-muted side-cal-head-day">${d}</div>`;
    });
    
    // 1. Días del mes anterior
    const prevMonthLastDay = new Date(y, m, 0).getDate();
    for(let i = fd - 1; i >= 0; i--) {
        const dNum = prevMonthLastDay - i;
        const prevDate = new Date(y, m - 1, dNum);
        const iso = getISO(prevDate);
        const hasApts = appointments.some(a => a.start && a.start.startsWith(iso));
        const hasAptsClass = hasApts ? 'has-apts' : '';
        html += `<div class="side-cal-day other-month ${hasAptsClass}" onclick="goDay('${iso}')" title="${dNum} (Mes anterior)">
            <span>${dNum}</span>
        </div>`;
    }
    
    // 2. Días del mes actual
    const todayIso = getISO(new Date());
    for(let d=1; d<=days; d++) {
        const iso = `${y}-${(m+1).toString().padStart(2,'0')}-${d.toString().padStart(2,'0')}`;
        const holiday = isHoliday(iso);
        const day = new Date(iso + 'T12:00:00').getDay();
        const isWeekend = (day === 0 || day === 6);
        const isActive = iso === getISO(selectedDate);
        const isToday = iso === todayIso;
        
        const hasApts = appointments.some(a => a.start && a.start.startsWith(iso));
        const hasAptsClass = hasApts ? 'has-apts' : '';
        const isWork = isWorkDay(iso);
        let onclickAttr = `onclick="goDay('${iso}')"`;
        if (holiday || !isWork) {
            onclickAttr = 'style="cursor:not-allowed; opacity:0.4;" title="Día no disponible"';
        }
        
        html += `<div class="side-cal-day ${isActive ? 'active' : ''} ${isToday ? 'is-today' : ''} ${holiday ? 'holiday' : ''} ${isWeekend ? 'weekend' : ''} ${hasAptsClass}" ${onclickAttr}>
            <span>${d}</span>
        </div>`;
    }

    // 3. Días del mes posterior para completar la cuadrícula semanal
    const totalCells = fd + days;
    const remainingDays = (7 - (totalCells % 7)) % 7;
    for(let d = 1; d <= remainingDays; d++) {
        const nextDate = new Date(y, m + 1, d);
        const iso = getISO(nextDate);
        const hasApts = appointments.some(a => a.start && a.start.startsWith(iso));
        const hasAptsClass = hasApts ? 'has-apts' : '';
        html += `<div class="side-cal-day other-month ${hasAptsClass}" onclick="goDay('${iso}')" title="${d} (Mes siguiente)">
            <span>${d}</span>
        </div>`;
    }
    
    html += `</div></div>`;
    cont.html(html);
}

function prevSideMonth() {
    selectedDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth() - 1, 1);
    renderHeaders();
    if (currentView === 'dia') renderTimeline();
    else if (currentView === 'calendario') renderGrid();
    else if (currentView === 'semana_smart') renderWeeklySmartView();
    else renderSideCalendar();
}

function nextSideMonth() {
    selectedDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth() + 1, 1);
    renderHeaders();
    if (currentView === 'dia') renderTimeline();
    else if (currentView === 'calendario') renderGrid();
    else if (currentView === 'semana_smart') renderWeeklySmartView();
    else renderSideCalendar();
}

function dummyReminder(id) {
    const a = appointments.find(x => x.id == id);
    if (!a) return;
    CrystalToast.fire({
        icon: 'info',
        title: 'Recordatorio Preparado',
        text: `Se ha simulado el envío de recordatorios (24h, 1h, 15m, 5m, 1m) para ${a.title}.`
    });
}


function renderGrid() {
    if (window.innerWidth < 992) {
        renderMobileCalendar();
        return;
    }
    const grid = $("#calendar-grid-sdm"); grid.empty().html('<div id="grid-inner" class="animate__animated animate__fadeIn"></div>');
    const container = $("#grid-inner");
    const y = selectedDate.getFullYear(); const m = selectedDate.getMonth();
    const fd = (new Date(y, m, 1).getDay() || 7) - 1; const days = new Date(y, m + 1, 0).getDate();
    container.css({ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '1px', background: '#cbd5e1', borderRadius:'15px', overflow:'hidden', border: '1px solid #cbd5e1' });
    
    // Titulos de dias con fondo azul marino corporativo y letras blancas (Req 3.1)
    ['LUN','MAR','MIE','JUE','VIE','SAB','DOM'].forEach(d => container.append(`<div class="cal-grid-header-day">${d}</div>`));
    
    function buildCellHtml(dateObj, isCurrentMonth, monthLabel = '') {
        const iso = getISO(dateObj);
        const d = dateObj.getDate();
        const holiday = isHoliday(iso); 
        const dayApts = getFilteredAppointments().filter(a => a.start && a.start.startsWith(iso));
        const isWork = isWorkDay(iso);
        const isToday = (iso === getISO(new Date()));

        const cellClass = isCurrentMonth ? 'calendar-cell' : 'calendar-cell calendar-cell-other-month';
        const bgColor = isCurrentMonth 
            ? (holiday ? '#fee2e2' : (isWork ? 'white' : '#f8fafc'))
            : (holiday ? '#fee2e2' : (isWork ? '#f8fafc' : '#f1f5f9'));
        const borderColor = holiday ? 'border-top:3px solid #ef4444' : (!isWork ? 'border-top:3px solid #cbd5e1' : '');

        let dayNumHtml = '';
        if (isToday) {
            dayNumHtml = `<span class="badge bg-primary rounded-pill px-2 text-white">${d}</span>`;
        } else if (!isCurrentMonth) {
            dayNumHtml = `<span class="other-month-day-num">${d}</span>`;
        } else {
            dayNumHtml = `<span class="text-navy">${d}</span>`;
        }

        let badgeHtml = '';
        if (holiday) {
            badgeHtml = '<small class="text-danger fw-bold" style="font-size:0.55rem">FESTIVO</small>';
        } else if (monthLabel) {
            badgeHtml = `<span class="other-month-badge">${monthLabel}</span>`;
        }

        return `
            <div class="p-2 ${cellClass}" ondragover="event.preventDefault()" ondrop="dropS(event, '${iso}')" onclick="handleSlotClick(event, '${iso}', '')" style="background:${bgColor}; min-height:115px; ${borderColor}">
                <div class="d-flex justify-content-between align-items-start fw-bold small mb-1">
                    ${dayNumHtml}
                    ${badgeHtml}
                </div>
                ${dayApts.slice(0,3).map(a => {
                    const aHi = a.start.split('T')[1].substring(0, 5);
                    const aHf = a.end.split('T')[1].substring(0, 5);
                    const res = resolverEstadoCita(a.extendedProps.estado, iso, aHf);
                    const st = res.clave;
                    const bColor = res.color;
                    const textColor = '#ffffff';
                    const isPast = res.esNoRealizada;

                    let actionIcons = '';
                    if (res.esEnConsulta) {
                        actionIcons = `
                            <i class="bi bi-play-circle cursor-pointer text-white" style="font-size:0.7rem;" onclick="event.stopPropagation(); window.location.href='render_consultas_privado.pl?id=${a.extendedProps.id_paciente}&id_cita=${a.id}'" title="Ir a Consulta Activa"></i>
                            <i class="bi bi-calendar2-event cursor-pointer text-white" style="font-size:0.55rem;" onclick="event.stopPropagation(); goDay('${iso}')" title="Ver Día"></i>
                        `;
                    } else if (st.toLowerCase().includes('sala de espera')) {
                        actionIcons = `
                            <i class="bi bi-clock-history cursor-pointer text-white" style="font-size:0.6rem;" onclick="event.stopPropagation(); openAppointmentQuickDetail('${a.id}')" title="Ver Cita"></i>
                            <i class="bi bi-calendar2-event cursor-pointer text-white" style="font-size:0.55rem;" onclick="event.stopPropagation(); goDay('${iso}')" title="Ver Día"></i>
                        `;
                    } else if (res.esAtendida) {
                        actionIcons = `
                            <i class="bi bi-eye cursor-pointer text-white" style="font-size:0.6rem;" onclick="event.stopPropagation(); openAppointmentQuickDetail('${a.id}')" title="Ver Ficha Rápida"></i>
                            <i class="bi bi-calendar2-event cursor-pointer text-white" style="font-size:0.55rem;" onclick="event.stopPropagation(); goDay('${iso}')" title="Ver Día"></i>
                        `;
                    } else if (isPast) {
                        // Citas Pasadas No Realizadas: permitir Tomar Cita, Ver Detalle y Re-agendar
                        const esTomable = (!st.toLowerCase().includes('atendida') && !st.toLowerCase().includes('cancelada'));
                        actionIcons = `
                            ${esTomable ? `<i class="bi bi-play-fill cursor-pointer text-white" style="font-size:0.75rem;" onclick="event.stopPropagation(); window.tomarCitaDirecto('${a.id}', '${a.extendedProps.id_paciente}')" title="Tomar Cita Ahora"></i>` : ''}
                            <i class="bi bi-eye cursor-pointer text-white" style="font-size:0.6rem;" onclick="event.stopPropagation(); openAppointmentQuickDetail('${a.id}')" title="Ver Detalle Rápido"></i>
                            ${esTomable ? `<i class="bi bi-pencil-square cursor-pointer text-white" style="font-size:0.55rem;" onclick="event.stopPropagation(); abrirModalCita('${a.id}')" title="Re-agendar"></i>` : ''}
                            <i class="bi bi-trash cursor-pointer text-white" style="font-size:0.55rem;" onclick="event.stopPropagation(); delCita('${a.id}')" title="Eliminar"></i>
                        `;
                    } else {
                        actionIcons = `
                            <i class="bi bi-grip-vertical cursor-pointer px-1 text-white opacity-75" style="font-size:0.8rem;" onclick="event.stopPropagation(); activateManualDrag('${a.id}')" title="Mover Cita (Drag Handle)"></i>
                            <i class="bi bi-calendar2-event cursor-pointer text-white" style="font-size:0.55rem;" onclick="event.stopPropagation(); goDay('${iso}')" title="Ver Día"></i>
                            <i class="bi bi-pencil-square cursor-pointer text-white" style="font-size:0.55rem;" onclick="event.stopPropagation(); abrirModalCita('${a.id}')" title="Editar Ficha"></i>
                            <i class="bi bi-trash cursor-pointer text-white" style="font-size:0.55rem;" onclick="event.stopPropagation(); delCita('${a.id}')" title="Eliminar"></i>
                        `;
                    }
                    
                    const itemClick = `openAppointmentQuickDetail('${a.id}')`;

                    return `
                    <div class="mini-apt-pro d-flex justify-content-between align-items-center mb-1 ${a.id == manualDragId ? 'is-dragging-manual':''} ${isPast ? 'is-past-apt':''}" 
                         onclick="event.stopPropagation(); ${itemClick}"
                         style="background:${bColor} !important; color:${st.toLowerCase().includes('confirmada') ? '#1e293b' : textColor} !important; ${(res.esCancelada || res.esNoRealizada) ? 'text-decoration:line-through; opacity:0.85;' : ''} cursor:pointer; border-radius:6px; padding:2px 6px;"
                         title="Estado: ${st} | ${a.title} (${aHi} - ${aHf})">
                        <span class="text-truncate fw-bold ${(res.esCancelada || res.esNoRealizada) ? 'text-decoration-line-through' : ''}" style="font-size:0.62rem;">${aHi} ${a.title.split(' ')[0]}</span>
                        <div class="d-flex gap-1 align-items-center">
                            ${actionIcons}
                        </div>
                    </div>`;
                }).join('')}
                ${dayApts.length > 3 ? `<div class="text-center mt-1"><span class="badge rounded-pill bg-light text-navy border fw-bold cursor-pointer" style="font-size:0.55rem;" onclick="event.stopPropagation(); goDay('${iso}')">+${dayApts.length - 3} más</span></div>` : ''}
            </div>
        `;
    }

    // 1. Días del mes anterior
    const prevMonthLastDay = new Date(y, m, 0).getDate();
    for (let i = fd - 1; i >= 0; i--) {
        const dNum = prevMonthLastDay - i;
        const dateObj = new Date(y, m - 1, dNum);
        const isFirst = (i === fd - 1);
        const label = isFirst ? dateObj.toLocaleDateString('es-ES', { month: 'short' }) : '';
        container.append(buildCellHtml(dateObj, false, label));
    }

    // 2. Días del mes en curso
    for (let d = 1; d <= days; d++) {
        const dateObj = new Date(y, m, d);
        container.append(buildCellHtml(dateObj, true, ''));
    }

    // 3. Días del mes posterior para completar la cuadrícula semanal
    const totalCells = fd + days;
    const remainingDays = (7 - (totalCells % 7)) % 7;
    for (let d = 1; d <= remainingDays; d++) {
        const dateObj = new Date(y, m + 1, d);
        const isFirst = (d === 1);
        const label = isFirst ? dateObj.toLocaleDateString('es-ES', { month: 'short' }) : '';
        container.append(buildCellHtml(dateObj, false, label));
    }
}

/**
 * VISTA MÓVIL REFINADA: Grid Compacto + Lista de Citas del Día
 */
function renderMobileCalendar() {
    renderMobileMiniGrid();
    renderMobileDayList();
}

function renderMobileMiniGrid() {
    const grid = $("#mini-calendar-grid");
    grid.empty();
    
    const y = selectedDate.getFullYear();
    const m = selectedDate.getMonth();
    const fd = (new Date(y, m, 1).getDay() || 7) - 1;
    const days = new Date(y, m + 1, 0).getDate();
    const todayISO = getISO(new Date());
    const selectedISO = getISO(selectedDate);

    // Días de la semana con fondo azul marino corporativo y texto blanco (Req 3.1)
    ['L','M','M','J','V','S','D'].forEach(d => {
        grid.append(`<div class="cal-grid-header-day-mobile">${d}</div>`);
    });

    // 1. Días del mes anterior
    const prevMonthLastDay = new Date(y, m, 0).getDate();
    for (let i = fd - 1; i >= 0; i--) {
        const dNum = prevMonthLastDay - i;
        const dateObj = new Date(y, m - 1, dNum);
        const iso = getISO(dateObj);
        const dayOfWeek = dateObj.getDay();
        const holiday = isHoliday(iso);
        const isWeekend = (dayOfWeek === 0 || dayOfWeek === 6);
        const hasApts = getFilteredAppointments().some(a => a.start && a.start.startsWith(iso));
        const isActive = (iso === selectedISO);
        const isToday = (iso === todayISO);

        const dayEl = $(`
            <div class="mini-grid-day other-month ${isActive ? 'active' : ''} ${holiday ? 'holiday' : ''} ${isWeekend ? 'weekend' : ''} ${hasApts ? 'has-apts' : ''}" 
                 onclick="selectMobileDate('${iso}')" title="${dNum} (Mes anterior)">
                ${dNum}
                ${isToday && !isActive ? '<div style="position:absolute; top:4px; right:4px; width:5px; height:5px; background:var(--sdm-accent); border-radius:50%;"></div>' : ''}
            </div>
        `);
        grid.append(dayEl);
    }

    // 2. Días del mes actual
    for (let d = 1; d <= days; d++) {
        const dateObj = new Date(y, m, d);
        const iso = getISO(dateObj);
        const dayOfWeek = dateObj.getDay(); // 0=Dom, 6=Sab
        const holiday = isHoliday(iso);
        const isWeekend = (dayOfWeek === 0 || dayOfWeek === 6);
        const hasApts = getFilteredAppointments().some(a => a.start && a.start.startsWith(iso));
        const isActive = iso === selectedISO;
        const isToday = iso === todayISO;

        const dayEl = $(`
            <div class="mini-grid-day ${isActive ? 'active' : ''} ${holiday ? 'holiday' : ''} ${isWeekend ? 'weekend' : ''} ${hasApts ? 'has-apts' : ''}" 
                 onclick="selectMobileDate('${iso}')">
                ${d}
                ${isToday && !isActive ? '<div style="position:absolute; top:4px; right:4px; width:5px; height:5px; background:var(--sdm-accent); border-radius:50%;"></div>' : ''}
            </div>
        `);
        grid.append(dayEl);
    }

    // 3. Días del mes posterior para completar la cuadrícula semanal
    const totalCells = fd + days;
    const remainingDays = (7 - (totalCells % 7)) % 7;
    for (let d = 1; d <= remainingDays; d++) {
        const dateObj = new Date(y, m + 1, d);
        const iso = getISO(dateObj);
        const dayOfWeek = dateObj.getDay();
        const holiday = isHoliday(iso);
        const isWeekend = (dayOfWeek === 0 || dayOfWeek === 6);
        const hasApts = getFilteredAppointments().some(a => a.start && a.start.startsWith(iso));
        const isActive = (iso === selectedISO);
        const isToday = (iso === todayISO);

        const dayEl = $(`
            <div class="mini-grid-day other-month ${isActive ? 'active' : ''} ${holiday ? 'holiday' : ''} ${isWeekend ? 'weekend' : ''} ${hasApts ? 'has-apts' : ''}" 
                 onclick="selectMobileDate('${iso}')" title="${d} (Mes siguiente)">
                ${d}
                ${isToday && !isActive ? '<div style="position:absolute; top:4px; right:4px; width:5px; height:5px; background:var(--sdm-accent); border-radius:50%;"></div>' : ''}
            </div>
        `);
        grid.append(dayEl);
    }
}

function renderMobileDayList() {
    const cont = $("#mini-calendar-appointments");
    cont.empty();
    
    const iso = getISO(selectedDate);
    const dayApts = getFilteredAppointments().filter(a => a.start.startsWith(iso)).sort((a,b) => a.start.localeCompare(b.start));

    if (dayApts.length === 0) {
        cont.html(`
            <div class="text-center p-4 bg-light rounded-4 opacity-50">
                <i class="bi bi-calendar-check fs-2 d-block mb-2"></i>
                <p class="small fw-bold mb-0">No hay citas para este día.</p>
            </div>
        `);
        return;
    }

    dayApts.forEach(a => {
        const hi = a.start.split('T')[1].substring(0, 5);
        const hf = a.end.split('T')[1].substring(0, 5);
        const res = resolverEstadoCita(a.extendedProps.estado, iso, hf);
        const status = res.clave;
        const color = res.color;
        
        const strikeMobile = (res.esNoRealizada || res.esCancelada) ? 'text-decoration: line-through; opacity: 0.78;' : '';
        const badgeTextColor = (status === 'confirmada' || status === 'confirmado' || status === 'pagada') ? '#854D0E' : color;
        
        const card = $(`
            <div class="mob-apt-card" style="border-left-color: ${color}; ${strikeMobile}" onclick="openAppointmentQuickDetail('${a.id}')">
                <div class="mob-apt-time-box">
                    <span class="mob-apt-time-start">${hi}</span>
                    <span class="mob-apt-time-end">${hf}</span>
                </div>
                <div class="mob-apt-details">
                    <div class="mob-apt-paciente" style="${strikeMobile}">${a.title}</div>
                    <div class="mob-apt-motivo">${a.extendedProps.motivo || 'Sin motivo'}</div>
                    <div class="mt-2">
                        <span class="badge rounded-pill" style="background:${color}20; color:${badgeTextColor}; font-size:0.6rem; border:1px solid ${color}40; ${strikeMobile}">
                            ${status.toUpperCase()}
                        </span>
                    </div>
                </div>
                <i class="bi bi-chevron-right text-muted opacity-30"></i>
            </div>
        `);
        cont.append(card);
    });
}

function selectMobileDate(iso) {
    selectedDate = new Date(iso + 'T12:00:00');
    renderHeaders();
    renderMobileCalendar();
}

function saveCita() {
    const f = $("#formCita");
    const esRango = $("#f_es_rango").val() === '1';
    const hi = $("#f_hi").val();
    let fecha = $("#f_fecha").val();
    const nomArr = ($("#f_paciente").val() || '').trim();
    const motivoVal = ($("#f_motivo").val() || '').trim();
    const curConsultorio = String($("#f_consultorio").val() || "");

    if (!curConsultorio || curConsultorio === 'Virtual') {
        Swal.fire({ icon: 'warning', title: 'Espacio Requerido', text: 'Seleccione un Consultorio o Quirófano válido.', customClass: { popup: 'rounded-4' } });
        return;
    }

    if (!nomArr) {
        Swal.fire({ icon: 'warning', title: 'Arrendatario Requerido', text: 'Indique el nombre del Médico o Arrendatario responsable.', customClass: { popup: 'rounded-4' } });
        return;
    }

    if (!motivoVal) {
        Swal.fire({ icon: 'warning', title: 'Uso / Procedimiento Requerido', text: 'El campo Uso / Procedimiento es obligatorio.', customClass: { popup: 'rounded-4' } });
        return;
    }

    const accion = $("#f_accion").val();
    const estado = $("#f_estado").val();
    if (accion === 'create' && (estado === 'Cancelada' || estado === 'No realizada' || estado === 'Finalizada')) {
        Swal.fire({
            icon: 'warning',
            title: 'Estado Inválido',
            text: 'Una nueva reserva no puede crearse en estado Cancelada, No realizada o Finalizada.',
            customClass: { popup: 'rounded-4' }
        });
        return;
    }

    if (!hi) {
        Swal.fire({ icon: 'info', title: 'Horario Requerido', text: 'Por favor, selecciona un bloque de horario disponible.' });
        return;
    }

    if (esRango) {
        const fIni = $("#f_fecha_rango_ini").val();
        const fFin = $("#f_fecha_fin").val();
        if (!fIni || !fFin) {
            Swal.fire({ icon: 'warning', title: 'Rango Incompleto', text: 'Especifique la fecha de inicio y la fecha de fin del rango.', customClass: { popup: 'rounded-4' } });
            return;
        }
        if (fFin < fIni) {
            Swal.fire({ icon: 'warning', title: 'Rango Inválido', text: 'La fecha fin no puede ser anterior a la fecha de inicio.', customClass: { popup: 'rounded-4' } });
            return;
        }
        $("#f_fecha").val(fIni);
        fecha = fIni;

        if (!isFuture(fecha, hi)) {
            const curHf = $("#f_hf").val();
            if (!curHf || !isFuture(fecha, curHf)) {
                Swal.fire({
                    icon: 'warning',
                    title: 'Fecha Inicio Pasada',
                    text: 'La fecha y hora de inicio del rango no pueden ser anteriores al momento actual.',
                    customClass: { popup: 'rounded-4' }
                });
                return;
            }
        }
    } else {
        const curId = $("#f_id_cita").val() || "";
        const curSucursal = String($("#f_sucursal").val() || "");
        const normCurCons = normalizarTextoEspacio(curConsultorio);

        const dayApps = appointments.filter(a => {
            const sameDay = a.start.startsWith(fecha);
            const differentId = String(a.id) !== curId;
            const aSuc = String(a.extendedProps?.sucursal || "");
            const aCons = normalizarTextoEspacio(a.extendedProps?.espacio || a.extendedProps?.consultorio || "");
            const isSameResource = (!curSucursal || !aSuc || aSuc === curSucursal) && (aCons === normCurCons);
            return sameDay && differentId && isSameResource;
        });

        if (duracionCita === 'all' && dayApps.length > 0) {
            Swal.fire({
                icon: 'warning',
                title: 'Día Completo No Disponible',
                html: `No se puede reservar el día completo porque el espacio <strong>${curConsultorio}</strong> ya cuenta con <strong>${dayApps.length}</strong> evento(s) en esta fecha.`,
                confirmButtonText: 'Entendido',
                customClass: { popup: 'rounded-4' }
            });
            return;
        }

        if (fecha === getISO(new Date()) && duracionCita === 'all') {
            const now = new Date();
            const curH = now.getHours().toString().padStart(2, '0');
            const curM = now.getMinutes().toString().padStart(2, '0');
            $("#f_hi").val(`${curH}:${curM}`);
        } else if (!isFuture(fecha, hi)) {
            const curHf = $("#f_hf").val();
            if (!curHf || !isFuture(fecha, curHf)) {
                Swal.fire({
                    icon: 'warning',
                    title: 'Acción No Permitida',
                    text: 'No es posible reservar o modificar espacios en una fecha u horario anterior al actual.',
                    customClass: { popup: 'rounded-4' }
                });
                return;
            }
        }

        const hf = $("#f_hf").val();
        let collisionApt = null;
        const hasCollision = dayApps.some(a => {
            const aT = a.start.split('T')[1] || '';
            const aHi = aT.substring(0,5).padStart(5, '0');
            const aHf = (a.end.split('T')[1] || '').substring(0,5).padStart(5, '0');
            if (hi < aHf && hf > aHi) {
                collisionApt = a;
                return true;
            }
            return false;
        });

        if (hasCollision && collisionApt) {
            const aT = collisionApt.start.split('T')[1] || '';
            const aHi = aT.substring(0,5).padStart(5, '0');
            const aHf = (collisionApt.end.split('T')[1] || '').substring(0,5).padStart(5, '0');
            const pacNombre = collisionApt.title || 'Reserva existente';

            Swal.fire({
                icon: 'error',
                title: 'Colisión de Espacio Detectada',
                html: `El espacio <strong>${curConsultorio}</strong> ya se encuentra ocupado en ese horario (<strong>${aHi} - ${aHf}</strong>: ${pacNombre}).<br><br>Por favor selecciona otro horario o espacio libre.`,
                customClass: { popup: 'rounded-4' }
            });
            return;
        }
    }

    const dataStr = f.serialize();

    $.post('../api/espacios_crud.pl', dataStr, function(res) {
        if (res && res.ok) {
            const idMedCreado = String($("#f_medico_select").val() || '');
            if (idMedCreado && Array.isArray(window.medicosChecked) && !window.medicosChecked.includes(idMedCreado)) {
                window.medicosChecked.push(idMedCreado);
                $(`.chk-medico-item[value="${idMedCreado}"]`).prop('checked', true);
                window.guardarFiltroMemoria('medicos');
                window.actualizarLabelFiltroMedicos();
            }

            if (typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'success', title: esRango ? 'Rango Reservado' : 'Espacio Reservado' });
            else Swal.fire({ icon: 'success', title: 'Éxito', text: res.msg || 'Reserva Guardada', timer: 1800, showConfirmButton: false });

            const modalEl = document.getElementById('modalCita');
            const modalIns = bootstrap.Modal.getInstance(modalEl) || new bootstrap.Modal(modalEl);
            modalIns.hide();

            if (typeof loadContext === 'function') {
                loadContext();
            }
        } else {
            Swal.fire({ icon: 'error', title: 'Conflicto o Error', text: (res ? res.msg : 'Error de conexión con el servidor'), customClass: { popup: 'rounded-4' } });
        }
    }, 'json').fail(function() {
        Swal.fire({ icon: 'error', title: 'Error Crítico', text: 'No se pudo comunicar con el servidor.', customClass: { popup: 'rounded-4' } });
    });
}

/**
 * Valida si una fecha y hora están en el futuro o presente respecto al momento actual
 */
function isFuture(dateStr, timeStr) {
    if (!dateStr) return false;
    const now = new Date();
    const time = (timeStr && timeStr.length >= 5) ? timeStr.substring(0, 5) : '00:00';
    const [y, m, d] = dateStr.split('-').map(Number);
    const [hh, mm] = time.split(':').map(Number);
    const targeted = new Date(y, m - 1, d, hh, mm, 0, 0);
    return targeted.getTime() >= now.getTime();
}

function dragS(id) { 
    // REGLA: El drag and drop SOLO puede existir en la Vista Mensual Grid
    if (currentView !== 'calendario') {
        draggedId = null;
        return;
    }
    draggedId = id; 
}

function activateManualDrag(id) {
    // REGLA: El drag and drop SOLO puede existir en la Vista Mensual Grid
    if (currentView !== 'calendario') {
        manualDragId = null;
        return;
    }
    const a = appointments.find(x => x.id == id);
    if (a) {
        const stLow = (a.extendedProps.estado || '').trim().toLowerCase();
        if (stLow === 'en consulta' || stLow === 'consulta en proceso' || stLow.includes('proceso') || stLow.includes('atendida')) {
            if (typeof CrystalToast !== 'undefined') {
                CrystalToast.fire({ icon: 'warning', title: 'Acción Bloqueada', text: 'Las citas en consulta o atendidas no se pueden mover.' });
            } else {
                Swal.fire({ icon: 'warning', title: 'Acción Bloqueada', text: 'Las citas en consulta o atendidas no se pueden mover.', customClass: { popup: 'rounded-4' } });
            }
            return;
        }
    }
    if (manualDragId === id) {
        manualDragId = null; // Desactivar
        if (typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'info', title: 'Modo Mover Desactivado' });
    } else {
        manualDragId = id;
        if (typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'info', title: 'Modo Mover Activado', text: 'Haz clic en el día destino en la vista mensual para mover la cita.' });
    }
    renderView(); // Refrescar para mostrar u ocultar la animación (is-dragging-manual)
}

function handleSlotClick(event, iso, time) {
    if (manualDragId) {
        if (event) event.stopPropagation();
        dropManualDrag(iso, time);
        return;
    }
    
    // Si no se proporcionó hora (ej. clic genérico en el día del grid mensual)
    if (!time) {
        const nowIso = getISO(new Date());
        if (iso < nowIso) {
            goDay(iso); // Navegar a la vista diaria del día pasado
            return;
        }
    }
    
    abrirModalNuevaCita(iso, time);
}

function dropManualDrag(iso, time) {
    if (currentView !== 'calendario') {
        manualDragId = null;
        renderView();
        return;
    }
    const id = manualDragId;
    const a = appointments.find(x => x.id == id);
    if (!a || isHoliday(iso)) {
        manualDragId = null;
        renderView();
        return;
    }

    const stLow = (a.extendedProps.estado || '').trim().toLowerCase();
    if (stLow === 'en consulta' || stLow === 'consulta en proceso' || stLow.includes('proceso') || stLow.includes('atendida')) {
        Swal.fire({ 
            icon: 'warning', 
            title: 'Acción Bloqueada', 
            text: 'Las citas en consulta o finalizadas (atendidas) están bloqueadas contra movimiento de horario.',
            customClass: { popup: 'rounded-4' }
        });
        manualDragId = null;
        renderView();
        return;
    }

    let targetTime = time || a.start.split('T')[1].substring(0,5);

    // REGLA: El drop solo puede aceptar fechas y horas iguales o superiores a la fecha y hora actual
    if (!isFuture(iso, targetTime)) {
        Swal.fire({ 
            icon: 'warning', 
            title: 'Acción No Permitida', 
            text: 'El drop solo acepta fechas y horas iguales o superiores a la fecha y hora actual.',
            confirmButtonText: 'Entendido',
            customClass: { popup: 'rounded-4' }
        });
        manualDragId = null;
        renderView();
        return;
    }

    const [ah, am] = a.start.split('T')[1].substring(0,5).split(':').map(Number);
    const [ahf, amf] = a.end.split('T')[1].substring(0,5).split(':').map(Number);
    const durationMin = (ahf * 60 + amf) - (ah * 60 + am);
    
    const [th, tm] = targetTime.split(':').map(Number);
    let targetEndMin = th * 60 + tm + durationMin;
    const targetEndH = Math.floor(targetEndMin / 60).toString().padStart(2, '0');
    const targetEndM = (targetEndMin % 60).toString().padStart(2, '0');
    let targetEndTime = `${targetEndH}:${targetEndM}`;

    const medId = String(a.extendedProps.id_medico || "");
    const dayApps = appointments.filter(x => x.start.startsWith(iso) && String(x.extendedProps.id_medico || "") === medId && x.id != id);
    const tStartMin = th * 60 + tm;
    
    const isB = dayApps.some(x => {
        const xHi = x.start.split('T')[1].substring(0,5);
        const xHf = x.end.split('T')[1].substring(0,5);
        const [xh, xm] = xHi.split(':').map(Number);
        const [xhf, xmf] = xHf.split(':').map(Number);
        const xStartMin = xh * 60 + xm;
        const xEndMin = xhf * 60 + xmf;
        return (tStartMin < xEndMin && targetEndMin > xStartMin);
    });

    if (isB) {
        Swal.fire({ 
            icon: 'warning', 
            title: 'Colisión Detectada', 
            text: 'El horario destino choca con otra cita.',
            customClass: { popup: 'rounded-4' }
        });
        manualDragId = null;
        renderView();
        return;
    }

    $.post('../api/espacios_crud.pl', { 
        accion:'update', 
        id_cita:a.id, 
        id_paciente:a.extendedProps.id_paciente, 
        id_medico:a.extendedProps.id_medico, 
        fecha:iso, 
        hora_ini:targetTime, 
        hora_fin:targetEndTime, 
        motivo:a.extendedProps.motivo, 
        estado:a.extendedProps.estado 
    }, function(res) {
        if(res.ok) {
            if(typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'success', title: 'Movido correctamente' }); 
            manualDragId = null;
            loadContext();
        } else {
            Swal.fire({ icon: 'error', title: 'Movimiento Inválido', text: res.msg, customClass: { popup: 'rounded-4' } });
            manualDragId = null;
            loadContext();
        }
    });
}

function dropS(e, iso) {
    e.preventDefault(); 
    if (currentView !== 'calendario') {
        draggedId = null;
        return;
    }
    const a = appointments.find(x => x.id == draggedId); 
    if (!a || isHoliday(iso)) return;

    const horaIni = a.start.split('T')[1].substring(0,5);

    // REGLA: El drop solo acepta fechas y horas iguales o superiores a la fecha y hora actual
    if (!isFuture(iso, horaIni)) {
        Swal.fire({ 
            icon: 'warning', 
            title: 'Acción No Permitida', 
            text: 'El drop solo acepta fechas y horas iguales o superiores a la fecha y hora actual.',
            confirmButtonText: 'Entendido',
            customClass: { popup: 'rounded-4' }
        });
        draggedId = null;
        return;
    }

    $.post('../api/espacios_crud.pl', { 
        accion:'update', 
        id_cita:a.id, 
        id_paciente:a.extendedProps.id_paciente, 
        id_medico:a.extendedProps.id_medico, 
        fecha:iso, 
        hora_ini:horaIni, 
        hora_fin:a.end.split('T')[1].substring(0,5), 
        motivo:a.extendedProps.motivo, 
        estado:a.extendedProps.estado 
    }, function(res) {
        if(res.ok) {
            if(typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'success', title: 'Movido correctamente' }); 
            loadContext();
        } else {
            Swal.fire({ icon: 'error', title: 'Movimiento Inválido', text: res.msg, confirmButtonText: 'Entendido', customClass: { popup: 'rounded-4' } });
            loadContext();
        }
    });
}

function renderSlots(date) {
    const cont = $("#slots-container"); cont.empty(); if (!date) return;
    
    // Blindaje de Jornada y Días Laborables
    if (!isWorkDay(date)) {
        cont.append('<div class="slot-alert-banner slot-alert-banner-danger animate__animated animate__shakeX"><strong>DÍA NO LABORABLE</strong><div class="small mt-1 text-muted">Este día no forma parte de la jornada laboral asignada.</div></div>');
        return;
    }
    if (isHoliday(date)) {
        cont.append('<div class="slot-alert-banner slot-alert-banner-danger animate__animated animate__shakeX"><strong>DÍA FESTIVO / ASUETO</strong><div class="small mt-1 text-muted">La clínica no labora en esta fecha festiva.</div></div>');
        return;
    }

    const s = parseInt(agendaConfig.laborStart.split(':')[0]);
    const e = parseInt(agendaConfig.laborEnd.split(':')[0]);
    const [ls, le] = [agendaConfig.lunchStart, agendaConfig.lunchEnd];
    const curId = $("#f_id_cita").val(); 
    const curSucursal = String($("#f_sucursal").val() || "");
    const curConsultorio = String($("#f_consultorio").val() || "");
    const normCurCons = normalizarTextoEspacio(curConsultorio);

    const dayApps = appointments.filter(a => {
        const sameDay = a.start.startsWith(date);
        const differentId = String(a.id) !== String(curId);
        const aSuc = String(a.extendedProps?.sucursal || "");
        const aCons = normalizarTextoEspacio(a.extendedProps?.espacio || a.extendedProps?.consultorio || "");
        const isSameResource = (!curSucursal || !aSuc || aSuc === curSucursal) && (aCons === normCurCons);
        return sameDay && differentId && isSameResource;
    });

    const laborStartMin = s * 60;
    const laborEndMin = e * 60;

    // Si es "Todo el día", verificamos colisión global estricta y que esté en horario futuro
    if (duracionCita === 'all') {
        let hhmmS = agendaConfig.laborStart || '09:00';
        const hhmmE = agendaConfig.laborEnd || '20:00';
        if (!isFuture(date, hhmmS)) {
            const now = new Date();
            if (date === getISO(now)) {
                let nextMin = now.getHours() * 60 + (now.getMinutes() < 30 ? 30 : 60);
                const hN = Math.floor(nextMin / 60).toString().padStart(2, '0');
                const mN = (nextMin % 60).toString().padStart(2, '0');
                hhmmS = (nextMin >= 1440) ? '23:59' : `${hN}:${mN}`;
            }
        }
        const isPastDay = !isFuture(date, hhmmS) || hhmmS >= hhmmE;
        
        // Bloqueo total si existe CUALQUIER cita en el día para este médico o recurso o si ya pasó el horario
        const isB = dayApps.length > 0 || isPastDay;

        if (!isB) {
            const btn = $(`<button type="button" class="btn btn-slot btn-slot-full w-100 py-3 mb-2 fw-medium animate__animated animate__fadeIn">JORNADA DISPONIBLE (${hhmmS} - ${hhmmE})</button>`);
            btn.click(function() {
                $(".btn-slot").removeClass("active dur-avena-slot");
                $(this).addClass("active dur-avena-slot");
                $("#f_hi").val(hhmmS);
                $("#f_hf").val(hhmmE);
                const accion = $("#f_accion").val();
                const lbl = (accion === 'update') ? 'RESERVA DE ESPACIO / EDITAR RESERVA' : 'RESERVA DE ESPACIO / NUEVO ARRENDAMIENTO';
                actualizarResaltadoModalCita($("#f_fecha").val(), hhmmS, hhmmE, lbl);
            });
            cont.append(btn);
        } else {
            $("#f_hi").val('');
            $("#f_hf").val('');
            cont.append(`
                <div class="slot-alert-banner slot-alert-banner-danger animate__animated animate__fadeIn">
                    <div class="d-flex align-items-center justify-content-center gap-1.5 fw-semibold mb-1" style="font-size: 0.82rem; color: #b91c1c;">
                        <i class="bi bi-exclamation-triangle-fill text-danger"></i> DÍA NO DISPONIBLE
                    </div>
                    <div style="font-size: 0.76rem; line-height: 1.45; color: #7f1d1d;">
                        El día seleccionado ya cuenta con <strong>${dayApps.length}</strong> cita(s) agendada(s) y no se encuentra completamente libre.
                    </div>
                    <div class="mt-2 pt-2 border-top" style="border-color: #fee2e2 !important; font-size: 0.72rem; color: #991b1b;">
                        Para asignar el <strong>Día Completo</strong>, las citas que lo impiden deben ser reprogramadas o eliminadas. También puede optar por la opción <strong>RESTO</strong> o un bloque específico de 30m / 1h.
                    </div>
                </div>
            `);
        }
        return;
    }

    const interval = isNaN(duracionCita) ? (parseInt(agendaConfig.intervalo_minutos) || 30) : duracionCita;
    const stepGrid = (duracionCita === 'rest') ? (parseInt(agendaConfig.intervalo_minutos) || 30) : Math.min(interval, 60);
    const lStart = agendaConfig.laborStart || '09:00';
    const lEnd = agendaConfig.laborEnd || '20:00';
    const [lsH, lsM] = lStart.split(':').map(Number);
    const [leH, leM] = lEnd.split(':').map(Number);
    
    let startMin = (lsH || 0) * 60 + (lsM || 0);
    let endMin = (leH || 0) * 60 + (leM || 0);
    if (endMin <= startMin || (leH === 23 && leM >= 50) || lEnd === '23:59' || lEnd === '24:00') {
        endMin = 1440;
    }

    let viableRestSlots = 0;

    for (let curMin = startMin; curMin < endMin; curMin += stepGrid) {
        if (duracionCita !== 'rest' && (curMin + interval) > endMin) {
            continue;
        }
        const h = Math.floor(curMin / 60);
        const m = curMin % 60;
        const hh = h.toString().padStart(2,'0'); 
        const mm = m.toString().padStart(2,'0');
        const hhmm = `${hh}:${mm}`;
        
        let hhmmE;
        let restHoursLabel = '';
        if (duracionCita === 'rest') {
            hhmmE = (endMin === 1440) ? '23:59' : lEnd;
            const remMin = endMin - curMin;
            const rH = Math.floor(remMin / 60);
            const rM = remMin % 60;
            restHoursLabel = rM > 0 ? `${rH}h ${rM}m` : `${rH}h`;
        } else {
            let tM = curMin + interval; 
            const hE = Math.floor(tM / 60).toString().padStart(2,'0'); 
            const mE = (tM % 60).toString().padStart(2,'0'); 
            hhmmE = (tM >= 1440) ? '23:59' : `${hE}:${mE}`;
        }
        
        // Verificamos si el slot está en el pasado: en Renta de Espacios NO se renderizan los recuadros anteriores a la hora actual
        const isCurrentSlot = ($("#f_hi").val() === hhmm);
        const isP = !isFuture(date, hhmm);
        if (isP && !isCurrentSlot) {
            continue;
        }
        let isL = false;
        if (ls && le && ls !== le) {
            isL = (hhmm < le && hhmmE > ls);
        }
            
            // Detección de Colisión Reforzada y captura de la cita en conflicto
            let isB = false;
            let conflictApt = null;
            for (const a of dayApps) {
                const aT = a.start.split('T')[1] || '';
                const aHi = aT.substring(0,5).padStart(5, '0');
                const aHf = (a.end.split('T')[1] || '').substring(0,5).padStart(5, '0');
                if (hhmm < aHf && hhmmE > aHi) {
                    isB = true;
                    conflictApt = a;
                    break;
                }
            }

            const canBypassLunch = (duracionCita === 'rest' || interval >= 120);
            const isBlocked = isP || (isL && !canBypassLunch) || isB;
            if (!isBlocked && duracionCita === 'rest') {
                viableRestSlots++;
            }

            const btnText = duracionCita === 'rest'
                ? `<span class="d-block fw-bold" style="font-size:0.74rem;">${hhmm} ➔ ${hhmmE}</span><small class="d-block opacity-75" style="font-size:0.60rem;">(${restHoursLabel} hasta cierre)</small>`
                : (interval >= 120 ? `<span class="d-block fw-bold" style="font-size:0.74rem;">${hhmm} - ${hhmmE}</span>` : hhmm);
            let btn;

            if (duracionCita === 'rest' && isB && conflictApt) {
                // Para Resto del Día: botón clicable con alerta informativa de la cita que impide el resto del día
                const cT = conflictApt.start.split('T')[1] || '';
                const cHi = cT.substring(0,5).padStart(5, '0');
                const cHf = (conflictApt.end.split('T')[1] || '').substring(0,5).padStart(5, '0');
                const cPac = conflictApt.title || 'Paciente agendado';
                const cMotivo = conflictApt.extendedProps.motivo || 'Consulta médica';

                btn = $(`<button type="button" class="btn btn-slot slot-busy btn-slot-conflict" title="No disponible: Cita a las ${cHi}">${btnText}</button>`);
                btn.click(function() {
                    Swal.fire({
                        icon: 'warning',
                        title: 'Resto del Día No Disponible',
                        html: `No es posible atender por el <strong>Resto del Día</strong> a partir de las <strong>${hhmm}</strong> debido a que existe una cita agendada:<br><br>
                               <div class="p-2.5 rounded-3 bg-light border text-start small">
                                   <div><strong>Horario:</strong> ${cHi} - ${cHf}</div>
                                   <div><strong>Paciente:</strong> ${cPac}</div>
                                   <div><strong>Motivo:</strong> ${cMotivo}</div>
                               </div><br>
                               Para disponer de este horario continuo hasta el cierre (<strong>${lEnd}</strong>), la cita que genera el empalme debe ser <strong>reprogramada</strong> o <strong>eliminada</strong>.`,
                        confirmButtonText: 'Entendido',
                        customClass: { popup: 'rounded-4' }
                    });
                });
            } else {
                const isCurrentSlot = ($("#f_hi").val() === hhmm);
                btn = $(`<button type="button" class="btn btn-slot ${isCurrentSlot ? 'active dur-avena-slot' : ''}" ${(isBlocked && !isCurrentSlot) ? 'disabled' : ''}>${btnText}</button>`);
                if (isP && !isCurrentSlot) btn.addClass('bg-light text-muted opacity-50').attr('title', 'Pasado');
                if (isL && !isCurrentSlot) btn.addClass('slot-lunch').attr('title', 'Comida');
                if (isB && !isCurrentSlot) btn.addClass('slot-busy').attr('title', 'Ocupado');
                
                btn.click(function() { 
                    $(".btn-slot").removeClass("active dur-avena-slot"); 
                    $(this).addClass("active dur-avena-slot"); 
                    $("#f_hi").val(hhmm); 
                    $("#f_hf").val(hhmmE); 
                    const accion = $("#f_accion").val();
                    const lbl = (accion === 'update') ? 'RESERVA DE ESPACIO / EDITAR RESERVA' : 'RESERVA DE ESPACIO / NUEVO ARRENDAMIENTO';
                    actualizarResaltadoModalCita($("#f_fecha").val(), hhmm, hhmmE, lbl);
                });
            }

            cont.append(btn);
    }

    if (cont.children().length === 0) {
        cont.append(`
            <div class="slot-alert-banner slot-alert-banner-warning mb-2 animate__animated animate__fadeIn">
                <div class="d-flex align-items-center justify-content-center gap-1.5 fw-semibold mb-1" style="font-size: 0.82rem; color: #b45309;">
                    <i class="bi bi-clock-history text-warning"></i> SIN HORARIOS FUTUROS DISPONIBLES HOY
                </div>
                <div style="font-size: 0.76rem; line-height: 1.45; color: #78350f;">
                    Los bloques de tiempo para esta fecha y duración ya han transcurrido. Seleccione una duración menor o elija una fecha posterior.
                </div>
            </div>
        `);
        return;
    }

    // Si en 'rest' no hubo ningún slot viable en todo el día, anteponer banner explicativo
    if (duracionCita === 'rest' && viableRestSlots === 0) {
        cont.prepend(`
            <div class="slot-alert-banner slot-alert-banner-warning mb-2 animate__animated animate__fadeIn">
                <div class="d-flex align-items-center justify-content-center gap-1.5 fw-semibold mb-1" style="font-size: 0.82rem; color: #b45309;">
                    <i class="bi bi-clock-history text-warning"></i> RESTO DEL DÍA NO DISPONIBLE
                </div>
                <div style="font-size: 0.76rem; line-height: 1.45; color: #78350f;">
                    Existen citas agendadas durante la jornada que impiden atender de forma continua hasta el cierre (${lEnd}).
                </div>
                <div class="mt-1" style="font-size: 0.72rem; color: #92400e;">
                    Haga clic en cualquiera de los bloques ocupados para conocer la cita en conflicto, o seleccione duraciones de 30m / 1h.
                </div>
            </div>
        `);
    }
}

function getNextAvailableDate(startIso) {
    let d = new Date(startIso + 'T12:00:00');
    for (let i = 0; i < 30; i++) {
        let currentIso = getISO(d);
        if (isWorkDay(currentIso) && !isHoliday(currentIso)) {
            if (isFuture(currentIso, agendaConfig.laborEnd || '20:00')) {
                return currentIso;
            }
        }
        d.setDate(d.getDate() + 1);
    }
    return startIso;
}

window.onCambioTipoArrendatario = function(val) {
    if (val && val !== 'EXTERNO' && window.medicosCatalogo && window.medicosCatalogo[val]) {
        $("#f_paciente").val(window.medicosCatalogo[val]);
    } else if (val === 'EXTERNO') {
        $("#f_paciente").val('').focus();
    }
};

/* ==========================================================================
   GESTIÓN DE RESERVAS EN RANGO DE FECHAS (MULTI-DÍA)
   ========================================================================== */

window.toggleModalidadFechaRenta = function(modo) {
    const isRango = (modo === 'rango');
    $('#f_es_rango').val(isRango ? '1' : '0');

    if (isRango) {
        $('#wrapper_fecha_unica').addClass('d-none');
        $('#wrapper_fecha_rango').removeClass('d-none');
        $('#lbl_tarifa_rango_tipo').removeClass('d-none');
        $('#lbl_calculo_total_rango').removeClass('d-none');

        const curF = $('#f_fecha').val() || getISO(new Date());
        if (!$('#f_fecha_rango_ini').val()) {
            $('#f_fecha_rango_ini').val(curF);
        }
        if (!$('#f_fecha_fin').val() || $('#f_fecha_fin').val() < $('#f_fecha_rango_ini').val()) {
            const [y, m, d] = ($('#f_fecha_rango_ini').val() || curF).split('-').map(Number);
            const finDate = new Date(y, m - 1, d + 4);
            $('#f_fecha_fin').val(getISO(finDate));
        }
        window.onFechasRangoChange();
    } else {
        $('#wrapper_fecha_unica').removeClass('d-none');
        $('#wrapper_fecha_rango').addClass('d-none');
        $('#lbl_tarifa_rango_tipo').addClass('d-none');
        $('#lbl_calculo_total_rango').addClass('d-none');

        const fIni = $('#f_fecha_rango_ini').val();
        if (fIni) $('#f_fecha').val(fIni);
        renderSlots($('#f_fecha').val());
    }
};

window.toggleDiaRango = function(btn) {
    $(btn).toggleClass('active');
    window.actualizarDiasSemanaRangoHidden();
};

window.seleccionarDiasSemanaRango = function(tipo) {
    if (tipo === 'todos') {
        $('.btn-dia-rango').addClass('active');
    } else if (tipo === 'laborables') {
        $('.btn-dia-rango').each(function() {
            const w = parseInt($(this).data('wday'));
            if (w >= 1 && w <= 5) $(this).addClass('active');
            else $(this).removeClass('active');
        });
    }
    window.actualizarDiasSemanaRangoHidden();
};

window.actualizarDiasSemanaRangoHidden = function() {
    const dias = [];
    $('.btn-dia-rango.active').each(function() {
        dias.push($(this).data('wday'));
    });
    $('#f_dias_semana_rango').val(dias.join(','));
    window.onFechasRangoChange();
};

window.toggleTipoTarifaRango = function() {
    const cur = $('#f_tipo_tarifa_rango').val() || 'por_dia';
    const next = (cur === 'por_dia') ? 'total' : 'por_dia';
    $('#f_tipo_tarifa_rango').val(next);
    $('#lbl_tarifa_rango_tipo').html(next === 'por_dia' ? 'Por día <i class="bi bi-arrow-repeat"></i>' : 'Total del rango <i class="bi bi-arrow-repeat"></i>');
    window.onMontoRentaChange();
};

window.onMontoRentaChange = function() {
    const esRango = $('#f_es_rango').val() === '1';
    if (!esRango) {
        $('#lbl_calculo_total_rango').addClass('d-none');
        return;
    }
    const dias = window.calcularDiasSeleccionadosRango();
    const numDias = dias.length;
    const monto = parseFloat($('#f_monto_renta').val() || 0);
    const tipo = $('#f_tipo_tarifa_rango').val() || 'por_dia';

    if (numDias > 0) {
        $('#lbl_calculo_total_rango').removeClass('d-none');
        if (tipo === 'por_dia') {
            const total = (numDias * monto).toFixed(2);
            $('#lbl_calculo_total_rango').html(`<span class="text-navy fw-bold">${numDias} días</span> × $${monto.toFixed(2)} = <span class="text-success fw-bold">Total: $${total} MXN</span>`);
        } else {
            const porDia = (numDias > 0 ? monto / numDias : 0).toFixed(2);
            $('#lbl_calculo_total_rango').html(`Total: $${monto.toFixed(2)} ÷ <span class="text-navy fw-bold">${numDias} días</span> = <span class="text-success fw-bold">$${porDia} / día</span>`);
        }
    } else {
        $('#lbl_calculo_total_rango').addClass('d-none');
    }
};

window.toggleTipoCoberturaRango = function(tipo) {
    const isContinuo = (tipo === 'continuo');
    $('#f_tipo_cobertura_rango').val(isContinuo ? 'continuo' : 'recurrente');
    if (isContinuo) {
        $('#wrapper_dias_semana_pills').addClass('d-none');
        $('#lbl_info_tipo_cobertura')
            .attr('style', 'font-size:0.68rem; background-color: #ecfeff; border-color: #cffafe !important;')
            .html('<i class="bi bi-info-circle-fill text-primary me-1"></i><strong>Bloque Continuo (24h+):</strong> El espacio se reservará día y noche ininterrumpidamente desde la hora de inicio del primer día hasta la hora de entrega del último día.');
    } else {
        $('#wrapper_dias_semana_pills').removeClass('d-none');
        $('#lbl_info_tipo_cobertura')
            .attr('style', 'font-size:0.68rem; background-color: #f8fafc; border-color: #e2e8f0 !important;')
            .html('<i class="bi bi-repeat text-teal me-1"></i><strong>Turnos Recurrentes:</strong> El espacio se ocupará de forma idéntica en el mismo horario cada día seleccionado (las mañanas/noches intermedias quedan libres).');
    }
    window.onFechasRangoChange();
};

window.calcularDiasSeleccionadosRango = function() {
    const fIni = $('#f_fecha_rango_ini').val();
    const fFin = $('#f_fecha_fin').val();
    if (!fIni || !fFin || fFin < fIni) return [];

    const tipoCob = $('#f_tipo_cobertura_rango').val() || 'continuo';
    const esContinuo = (tipoCob === 'continuo');

    const diasSemanaStr = $('#f_dias_semana_rango').val() || '1,2,3,4,5,6,7';
    const permitidos = diasSemanaStr.split(',').map(Number);

    const res = [];
    const [y1, m1, d1] = fIni.split('-').map(Number);
    const [y2, m2, d2] = fFin.split('-').map(Number);
    let cur = new Date(y1, m1 - 1, d1);
    const fin = new Date(y2, m2 - 1, d2);

    let count = 0;
    while (cur <= fin && count < 120) {
        count++;
        let w = cur.getDay(); // 0=Dom, 1=Lun, ..., 6=Sab
        let isoW = (w === 0) ? 7 : w;
        if (esContinuo || permitidos.includes(isoW)) {
            res.push(getISO(cur));
        }
        cur.setDate(cur.getDate() + 1);
    }
    return res;
};

window.onFechasRangoChange = function() {
    const fIni = $('#f_fecha_rango_ini').val();
    const fFin = $('#f_fecha_fin').val();
    if (!fIni) return;

    $('#f_fecha').val(fIni);
    renderSlots(fIni);

    const dias = window.calcularDiasSeleccionadosRango();
    const lblConteo = $('#lbl_conteo_dias_rango');
    if (dias.length > 0) {
        lblConteo.html(`<i class="bi bi-calendar-check text-teal me-1"></i><strong class="text-navy">${dias.length} día(s)</strong> seleccionados (${fIni} al ${fFin})`);
    } else if (fFin && fFin < fIni) {
        lblConteo.html(`<i class="bi bi-exclamation-triangle text-danger me-1"></i><span class="text-danger fw-semibold">Fecha fin anterior a fecha inicio</span>`);
    } else {
        lblConteo.html(`<i class="bi bi-info-circle text-muted me-1"></i>Sin días seleccionados`);
    }

    window.onMontoRentaChange();
    window.verificarDisponibilidadRango();
};

let debounceVerificarRangoTimer = null;
window.verificarDisponibilidadRango = function() {
    if (debounceVerificarRangoTimer) clearTimeout(debounceVerificarRangoTimer);
    debounceVerificarRangoTimer = setTimeout(() => {
        const esRango = $('#f_es_rango').val() === '1';
        if (!esRango) return;

        const fIni = $('#f_fecha_rango_ini').val();
        const fFin = $('#f_fecha_fin').val();
        const hi = $('#f_hi').val();
        const hf = $('#f_hf').val();
        const suc = $('#f_sucursal').val();
        const esp = $('#f_consultorio').val();
        const idMed = $('#f_medico_select').val();
        const diasSemana = $('#f_dias_semana_rango').val() || '1,2,3,4,5,6,7';

        if (!fIni || !fFin || fFin < fIni) return;

        const statusBadge = $('#lbl_status_anticolision_rango');
        const listaConflictos = $('#lista_conflictos_rango');
        statusBadge.attr('class', 'badge bg-warning-subtle text-warning-emphasis border border-warning-subtle')
                   .html('<span class="spinner-border spinner-border-sm me-1" style="width:0.7rem; height:0.7rem;"></span>Verificando disponibilidad...');

        $.get('../api/espacios_crud.pl', {
            accion: 'check_range_availability',
            fecha_ini: fIni,
            fecha_fin: fFin,
            hora_ini: hi,
            hora_fin: hf,
            sucursal: suc,
            espacio: esp,
            id_arrendatario: idMed,
            dias_semana_rango: diasSemana,
            tipo_cobertura_rango: $('#f_tipo_cobertura_rango').val() || 'continuo'
        }, function(res) {
            if (res && res.ok) {
                if (res.dias_conflicto === 0 && res.total_dias > 0) {
                    statusBadge.attr('class', 'badge bg-success-subtle text-success-emphasis border border-success-subtle')
                               .html(`<i class="bi bi-check-circle-fill me-1"></i>${res.total_dias} de ${res.total_dias} días disponibles`);
                    listaConflictos.addClass('d-none').empty();
                } else if (res.dias_conflicto > 0) {
                    statusBadge.attr('class', 'badge bg-danger-subtle text-danger-emphasis border border-danger-subtle')
                               .html(`<i class="bi bi-exclamation-octagon-fill me-1"></i>${res.dias_conflicto} conflicto(s)`);

                    const conflictos = (res.detalles || []).filter(d => !d.disponible);
                    let htmlConf = '<div class="alert alert-danger py-1 px-2 mb-0 mt-1" style="font-size:0.68rem; max-height:80px; overflow-y:auto;">';
                    htmlConf += '<div class="fw-bold mb-0.5"><i class="bi bi-shield-exclamation me-1"></i>Conflictos encontrados:</div>';
                    conflictos.forEach(c => {
                        htmlConf += `<div>• <strong>${c.fecha} (${c.dia_semana}):</strong> ${c.motivo}</div>`;
                    });
                    htmlConf += '</div>';
                    listaConflictos.removeClass('d-none').html(htmlConf);
                } else {
                    statusBadge.attr('class', 'badge bg-light text-secondary border')
                               .html(`0 días en rango`);
                    listaConflictos.addClass('d-none').empty();
                }
            } else {
                statusBadge.attr('class', 'badge bg-light text-secondary border')
                           .html('Sin verificar');
                listaConflictos.addClass('d-none').empty();
            }
        }, 'json').fail(function() {
            statusBadge.attr('class', 'badge bg-light text-muted border').html('Error de verificación');
        });
    }, 250);
};

window.abrirModalNuevaRenta = function(f, h, espacioPre) {
    abrirModalNuevaCita(f, h, espacioPre);
};

function abrirModalNuevaCita(f, h, espacioPre) {
    const isGlobal = !f && !h;
    const hoyIso = getISO(new Date());
    let targetF = f;
    if (!targetF || targetF < hoyIso) {
        if (f && f < hoyIso) {
            Swal.fire({
                icon: 'warning',
                title: 'Fecha Pasada No Permitida',
                text: 'No se puede reservar un espacio antes de la fecha y hora actual.',
                customClass: { popup: 'rounded-4' }
            });
            return;
        }
        targetF = getNextAvailableDate(hoyIso);
    }

    if (!isGlobal && h && !isFuture(targetF, h)) {
        Swal.fire({
            icon: 'warning',
            title: 'Horario Pasado No Disponible',
            text: 'No se puede reservar un espacio antes de la fecha y hora actual.',
            customClass: { popup: 'rounded-4' }
        });
        return;
    }

    $("#f_id_cita, #f_id_cita_alias").val('');
    $("#f_accion").val('create');
    $("#f_fecha").attr('min', hoyIso).val(targetF);

    // Inicializar modalidad de fecha en 'Día Único'
    if (typeof window.toggleModalidadFechaRenta === 'function') {
        window.toggleModalidadFechaRenta('unica');
    }
    $('#box_modalidad_reserva').removeClass('d-none');
    $('#mod_fecha_unica').prop('checked', true);
    $('#f_fecha_rango_ini').val(targetF);
    $('#f_fecha_fin').val('');
    $('#cob_rango_continuo').prop('checked', true);
    if (typeof window.toggleTipoCoberturaRango === 'function') {
        window.toggleTipoCoberturaRango('continuo');
    }

    if (duracionCita === 30) duracionCita = 60; // Por defecto 1 hora en renta de espacios
    if (typeof window.sincronizarSliderDuracionUI === 'function') {
        window.sincronizarSliderDuracionUI(duracionCita);
    }

    if (h) {
        $("#f_hi").val(h);
        let [hh, mm] = h.split(':').map(Number);
        mm += (isNaN(duracionCita) ? 60 : duracionCita);
        while (mm >= 60) { mm -= 60; hh++; }
        const hf = `${hh.toString().padStart(2,'0')}:${mm.toString().padStart(2,'0')}`;
        $("#f_hf").val(hf);
    } else {
        $("#f_hi").val('');
        $("#f_hf").val('');
    }

    $("#modalCitaTitle").html('<span class="fw-semibold">RESERVA DE ESPACIO / NUEVO ARRENDAMIENTO</span>');
    $("#bloqueo-horario-avena").addClass('d-none');
    $(".btn-dur").removeClass('dur-avena-active');
    $(".btn-slot").removeClass('dur-avena-slot');

    $("#modalCita input, #modalCita select").prop('disabled', false);
    $("#modalCita button[onclick*='saveCita']").show();
    $("#btn-del-cita").addClass('d-none');

    $("#f_medico_select").val('EXTERNO');
    $("#f_paciente").val('').prop('readonly', false).removeClass('bg-light');
    $("#f_telefono_arrendatario").val('');
    $("#f_motivo").val('');
    $("#f_notas").val('');
    $("#f_monto_renta").val('0.00');

    const opcionesNueva = [
        { val: 'Reservada', text: 'Reservada' },
        { val: 'Confirmada', text: 'Confirmada' },
        { val: 'En Uso', text: 'En Uso' }
    ];
    let htmlOptsNueva = '';
    opcionesNueva.forEach(op => {
        htmlOptsNueva += `<option value="${op.val}">${op.text}</option>`;
    });
    $("#f_estado").html(htmlOptsNueva).val('Reservada');

    if (espacioPre) {
        $("#f_consultorio").val(espacioPre);
    } else {
        $("#f_consultorio").prop("selectedIndex", 0);
    }

    $("#btn-cobrar-recepcion").addClass('d-none');
    $("#leyenda-cita-pagada").addClass('d-none');
    renderSlots(targetF);
    const m = bootstrap.Modal.getOrCreateInstance(document.getElementById('modalCita'));
    m.show();
}

function abrirModalCita(id, isReadonly) {
    const a = appointments.find(x => x.id == id); if(!a) return;
    if (a.extendedProps && a.extendedProps.es_bloqueo_pacientes) {
        window.openAppointmentQuickDetail(id);
        return;
    }
    const hi = a.start.split('T')[1].substring(0,5);
    const hf = a.end.split('T')[1].substring(0,5);
    const fecha = a.start.split('T')[0];
    const est = (a.extendedProps.estado || 'Reservada').trim().toLowerCase();

    // Al editar una reserva existente, forzar modalidad 'Día Único'
    if (typeof window.toggleModalidadFechaRenta === 'function') {
        window.toggleModalidadFechaRenta('unica');
    }
    $('#box_modalidad_reserva').addClass('d-none');

    $("#f_id_cita, #f_id_cita_alias").val(a.id);
    $("#f_accion").val('update');
    $("#f_paciente").val(a.title || a.extendedProps.nombre_arrendatario || '').prop('readonly', false).removeClass('bg-light');
    $("#f_telefono_arrendatario").val(a.extendedProps.telefono || '');
    $("#f_fecha").val(fecha);
    $("#f_hi").val(hi);
    $("#f_hf").val(hf);
    $("#f_monto_renta").val(parseFloat(a.extendedProps.monto_renta || 0).toFixed(2));
    $("#f_notas").val(a.extendedProps.notas || '');

    const opcionesEdicion = [
        { val: 'Reservada', text: 'Reservada' },
        { val: 'Confirmada', text: 'Confirmada' },
        { val: 'En Uso', text: 'En Uso' },
        { val: 'Finalizada', text: 'Finalizada' },
        { val: 'No realizada', text: 'No realizada' },
        { val: 'Cancelada', text: 'Cancelada' }
    ];
    let htmlOptsEdicion = '';
    opcionesEdicion.forEach(op => {
        htmlOptsEdicion += `<option value="${op.val}">${op.text}</option>`;
    });
    $("#f_estado").html(htmlOptsEdicion).val(a.extendedProps.estado || 'Reservada');

    if (a.extendedProps.id_arrendatario) {
        $("#f_medico_select").val(a.extendedProps.id_arrendatario);
    } else {
        $("#f_medico_select").val('EXTERNO');
    }

    $("#f_motivo").val(a.extendedProps.motivo || '');

    const sucursalCita = a.extendedProps.sucursal || $("#f_sucursal").val() || '';
    const consultorioCita = a.extendedProps.espacio || a.extendedProps.consultorio || '';
    if (a.extendedProps.sucursal) $("#f_sucursal").val(a.extendedProps.sucursal);

    if (typeof window.cargarRecursos === 'function') {
        window.cargarRecursos(sucursalCita, consultorioCita);
    } else if (consultorioCita) {
        $("#f_consultorio").val(consultorioCita);
    }

    const pagado = a.extendedProps.pagado === 1 || a.extendedProps.pagado === '1' || a.extendedProps.pagado === true;
    const esFinalizada = est.includes('finalizada') || est.includes('atendida');
    const esCancelada = est.includes('cancelada');
    const esCerrada = (esFinalizada || esCancelada);

    if (esCerrada || isReadonly) {
        $("#modalCita input, #modalCita select").prop('disabled', true);
        $("#modalCita button[onclick*='saveCita']").hide();
        $("#btn-del-cita").addClass('d-none');
        if (pagado) {
            $("#btn-cobrar-recepcion").addClass('d-none');
            $("#leyenda-cita-pagada").removeClass('d-none').html('<i class="bi bi-check-circle-fill me-1"></i> Renta Liquidada en Recepción');
        } else {
            $("#btn-cobrar-recepcion").removeClass('d-none');
            $("#leyenda-cita-pagada").addClass('d-none');
        }
        actualizarResaltadoModalCita(fecha, hi, hf, 'RESERVA DE ESPACIO / SOLO LECTURA');
    } else {
        $("#modalCita input, #modalCita select").prop('disabled', false);
        $("#modalCita button[onclick*='saveCita']").show();
        $("#btn-del-cita").removeClass('d-none');
        if (pagado) {
            $("#btn-cobrar-recepcion").addClass('d-none');
            $("#leyenda-cita-pagada").removeClass('d-none').html('<i class="bi bi-check-circle-fill me-1"></i> Renta Liquidada en Recepción');
        } else {
            $("#btn-cobrar-recepcion").removeClass('d-none');
            $("#leyenda-cita-pagada").addClass('d-none');
        }
        actualizarResaltadoModalCita(fecha, hi, hf, 'RESERVA DE ESPACIO / EDITAR RESERVA');
    }

    let durMin = 60;
    if (hi && hf) {
        const [h1, m1] = hi.split(':').map(Number);
        const [h2, m2] = hf.split(':').map(Number);
        durMin = (h2 * 60 + m2) - (h1 * 60 + m1);
        if (isNaN(durMin) || durMin <= 0) durMin = 60;
    }
    duracionCita = durMin;
    if (typeof window.sincronizarSliderDuracionUI === 'function') {
        window.sincronizarSliderDuracionUI(duracionCita);
    }
    $("#f_fecha").attr('min', getISO(new Date()));

    renderSlots(fecha);
    const m = bootstrap.Modal.getOrCreateInstance(document.getElementById('modalCita'));
    m.show();
}

window.tomarCitaDirecto = function(id_cita, id_paciente) {
    if (!id_cita || !id_paciente) return;
    
    const a = appointments.find(x => x.id == id_cita);
    const hi = a ? a.start.split('T')[1].substring(0, 5) : '';
    const fec = a ? a.start.split('T')[0] : '';
    
    if (fec && hi && !isFuture(fec, hi)) {
        // Es una cita en el pasado, se va a atender extemporáneamente "ahora"
        const now = new Date();
        const curH = now.getHours().toString().padStart(2, '0');
        const curM = now.getMinutes().toString().padStart(2, '0');
        const curTime = `${curH}:${curM}`;
        const todayStr = getISO(now);
        
        const hasCollision = appointments.some(x => {
            if (x.id == id_cita) return false;
            if (!x.start.startsWith(todayStr)) return false;
            const xHi = x.start.split('T')[1].substring(0, 5);
            const xHf = x.end.split('T')[1].substring(0, 5);
            return (curTime >= xHi && curTime < xHf);
        });
        
        if (hasCollision) {
            Swal.fire({
                icon: 'warning',
                title: 'Atención: Choque de Horario',
                text: 'Vas a tomar una cita extemporánea, pero actualmente hay otra cita agendada en la agenda para esta misma hora. ¿Deseas empalmarla y atenderla de todos modos?',
                showCancelButton: true,
                confirmButtonColor: '#3b82f6',
                confirmButtonText: 'Sí, atender ahora',
                cancelButtonText: 'Cancelar',
                customClass: { popup: 'rounded-4' }
            }).then(r => {
                if (r.isConfirmed) proceedTomarCita(id_cita, id_paciente);
            });
            return;
        }
    }
    
    proceedTomarCita(id_cita, id_paciente);
};

function tomarCitaModal() {
    const id_cita = $("#f_id_cita").val();
    const id_paciente = $("#f_id_paciente").val();
    if (!id_cita || !id_paciente) return;
    window.tomarCitaDirecto(id_cita, id_paciente);
}

function proceedTomarCita(id_cita, id_paciente) {
    const modalEl = document.getElementById('modalCita');
    if (modalEl) {
        const inst = bootstrap.Modal.getInstance(modalEl);
        if (inst) inst.hide();
    }
    if (typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'info', title: 'Preparando Consulta...' });
    
    setTimeout(() => {
        window.location.href = `render_consultas.pl?id=${id_paciente}&id_cita=${id_cita}`;
    }, 400);
}

function cobrarRecepcionModal() {
    const id_renta = $("#f_id_cita").val();
    const nombre_arrendatario = $("#f_paciente").val() || "Arrendatario";
    const montoSugerido = parseFloat($("#f_monto_renta").val() || 0) > 0 ? parseFloat($("#f_monto_renta").val()).toFixed(2) : "1000.00";
    const espacioTxt = $("#f_consultorio").val() || "Espacio";

    if (!id_renta) {
        Swal.fire("Acción Requerida", "Primero guarda la reserva del espacio para poder registrar su cobro.", "info");
        return;
    }

    Swal.fire({
        title: '<strong>Cobro de Renta de Espacio</strong>',
        icon: 'question',
        html: `
            <div class="text-start p-2">
                <p class="mb-1 fs-6"><strong>Arrendatario:</strong> <span class="text-primary">${nombre_arrendatario}</span></p>
                <p class="mb-3 small text-muted"><strong>Espacio:</strong> ${espacioTxt}</p>
                <div class="mb-3">
                    <label class="form-label fw-bold small text-muted">Importe de Renta ($ MXN):</label>
                    <input type="number" id="swal_monto_cobro" class="form-control fw-bold fs-5 text-success" value="${montoSugerido}" min="1" step="50">
                </div>
                <div class="mb-2">
                    <label class="form-label fw-bold small text-muted">Método de Pago:</label>
                    <select id="swal_metodo_pago" class="form-select fw-bold">
                        <option value="Efectivo" selected>Efectivo</option>
                        <option value="Tarjeta">Tarjeta de Crédito/Débito</option>
                        <option value="Transferencia">Transferencia Bancaria</option>
                    </select>
                </div>
            </div>
        `,
        showCancelButton: true,
        confirmButtonText: '<i class="bi bi-check-circle-fill me-1"></i> Registrar Cobro y Emitir Recibo',
        cancelButtonText: 'Cancelar',
        customClass: { popup: 'rounded-4 shadow-lg' },
        preConfirm: () => {
            const monto = document.getElementById('swal_monto_cobro').value;
            const metodo = document.getElementById('swal_metodo_pago').value;
            if (!monto || parseFloat(monto) <= 0) {
                Swal.showValidationMessage('Proporciona un monto válido mayor a $0.00.');
                return false;
            }
            return { monto: monto, metodo_pago: metodo };
        }
    }).then(async (result) => {
        if (result.isConfirmed) {
            try {
                const data = result.value;
                const body = new URLSearchParams();
                body.append('accion', 'cobrar_renta');
                body.append('id_renta', id_renta);
                body.append('monto', data.monto);
                body.append('metodo_pago', data.metodo_pago);

                const response = await fetch('../api/espacios_crud.pl', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
                    body: body
                });
                const res = await response.json();
                if (res.ok) {
                    $("#f_monto_renta").val(parseFloat(data.monto).toFixed(2));
                    $("#btn-cobrar-recepcion").addClass('d-none');
                    $("#leyenda-cita-pagada").removeClass('d-none').html('<i class="bi bi-check-circle-fill me-1"></i> Renta Liquidada ($' + parseFloat(data.monto).toFixed(2) + ')');

                    Swal.fire({
                        icon: "success",
                        title: "¡Cobro Registrado!",
                        text: res.msg,
                        timer: 2000,
                        showConfirmButton: false
                    }).then(() => {
                        if (typeof loadContext === 'function') loadContext();
                    });
                } else {
                    Swal.fire("Error en Cobro", res.msg || "No fue posible registrar el cobro.", "error");
                }
            } catch (err) {
                console.error("Error en cobro de renta:", err);
                Swal.fire("Falla de Servidor", "Ocurrió un error al procesar el cobro de la renta.", "error");
            }
        }
    });
}

function delCita(id) {
    const targetId = id || $("#f_id_cita").val();
    const a = appointments.find(x => x.id == targetId);
    if (a) {
        const stLow = (a.extendedProps.estado || '').trim().toLowerCase();
        if (stLow === 'en consulta' || stLow === 'consulta en proceso' || stLow.includes('proceso') || stLow.includes('atendida')) {
            Swal.fire({
                icon: 'warning',
                title: 'Acción Bloqueada',
                text: 'La cita está en consulta o finalizada (atendida) y no se puede eliminar.',
                customClass: { popup: 'rounded-4' }
            });
            return;
        }
    }

    const notas = (a && a.extendedProps && a.extendedProps.notas) ? a.extendedProps.notas : '';
    const esSerieRango = notas.includes('Grupo: GRP-');

    if (esSerieRango) {
        Swal.fire({
            title: 'Reserva en Rango Multi-Día',
            text: 'Esta reserva forma parte de una serie de varios días. ¿Deseas eliminar únicamente este día o cancelar la serie completa del rango?',
            icon: 'question',
            showCancelButton: true,
            showDenyButton: true,
            confirmButtonColor: '#d33',
            denyButtonColor: '#b91c1c',
            cancelButtonColor: '#64748b',
            confirmButtonText: '<i class="bi bi-trash me-1"></i> Solo este día',
            denyButtonText: '<i class="bi bi-calendar-x me-1"></i> Toda la serie del rango',
            cancelButtonText: 'Cancelar',
            customClass: { popup: 'rounded-4' }
        }).then((result) => {
            if (result.isConfirmed) {
                // Eliminar solo este día
                $.post('../api/espacios_crud.pl', { accion: 'delete', id_cita: targetId, eliminar_grupo: 0 }, function(res) {
                    if (res && !res.ok) {
                        Swal.fire({ icon: 'error', title: 'Error', text: res.msg, customClass: { popup: 'rounded-4' } });
                    } else {
                        const modalEl = document.getElementById('modalCita');
                        if (modalEl) {
                            const inst = bootstrap.Modal.getInstance(modalEl);
                            if (inst) inst.hide();
                        }
                        const qEl = document.getElementById('appointmentQuickModal');
                        if (qEl) {
                            const instQ = bootstrap.Modal.getInstance(qEl);
                            if (instQ) instQ.hide();
                        }
                        loadContext();
                    }
                }, 'json');
            } else if (result.isDenied) {
                // Eliminar toda la serie del rango
                $.post('../api/espacios_crud.pl', { accion: 'delete', id_cita: targetId, eliminar_grupo: 1 }, function(res) {
                    if (res && !res.ok) {
                        Swal.fire({ icon: 'error', title: 'Error', text: res.msg, customClass: { popup: 'rounded-4' } });
                    } else {
                        const modalEl = document.getElementById('modalCita');
                        if (modalEl) {
                            const inst = bootstrap.Modal.getInstance(modalEl);
                            if (inst) inst.hide();
                        }
                        const qEl = document.getElementById('appointmentQuickModal');
                        if (qEl) {
                            const instQ = bootstrap.Modal.getInstance(qEl);
                            if (instQ) instQ.hide();
                        }
                        Swal.fire({ icon: 'success', title: 'Serie Cancelada', text: res.msg, timer: 1600, showConfirmButton: false });
                        loadContext();
                    }
                }, 'json');
            }
        });
        return;
    }

    // Flujo normal de reserva de día único
    Swal.fire({ 
        title: '¿Eliminar reserva?', 
        text: "Esta acción no se puede deshacer.",
        icon: 'warning', 
        showCancelButton: true, 
        confirmButtonColor: '#d33',
        confirmButtonText: 'Sí, eliminar',
        cancelButtonText: 'Cancelar',
        customClass: { popup: 'rounded-4' }
    }).then((r) => {
        if(r.isConfirmed) $.post('../api/espacios_crud.pl', { accion:'delete', id_cita:targetId }, function(res) {
            if (res && !res.ok) {
                Swal.fire({ icon: 'error', title: 'No se pudo eliminar', text: res.msg, customClass: { popup: 'rounded-4' } });
            } else {
                const modalEl = document.getElementById('modalCita');
                if (modalEl) {
                    const inst = bootstrap.Modal.getInstance(modalEl);
                    if (inst) inst.hide();
                }
                const qEl = document.getElementById('appointmentQuickModal');
                if (qEl) {
                    const instQ = bootstrap.Modal.getInstance(qEl);
                    if (instQ) instQ.hide();
                }
                loadContext();
            }
        }, 'json');
    });
}

function sendWA(id) {
    const a = appointments.find(x => x.id == id); if(!a) return;
    const tel = a.extendedProps.telefono || '525500000000'; 
    const pac = a.title;
    const fec = a.start.split('T')[0];
    const hor = a.start.split('T')[1].substring(0,5);
    const msg = `Hola ${pac}, te recordamos tu cita en Software Dental Mexicano el día ${fec} a las ${hor}. ¡Te esperamos!`;
    window.open(`https://wa.me/${tel}?text=${encodeURIComponent(msg)}`, '_blank');
}

function handleAptClick(id) {
    if (typeof window.openAppointmentQuickDetail === 'function') {
        window.openAppointmentQuickDetail(id);
    } else {
        abrirModalCita(id);
    }
}

function initClock() { setInterval(() => { const n = new Date(); $("#digital-clock").text(n.toLocaleTimeString()); }, 1000); }
function getISO(d) {
    if (!d) return '';
    if (typeof d === 'string') return d.split('T')[0];
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
}
function isHoliday(iso) { 
    if (!agendaConfig.festivos) return false;
    let list = [];
    if (Array.isArray(agendaConfig.festivos)) {
        list = agendaConfig.festivos;
    } else {
        list = agendaConfig.festivos.split(',').map(d => d.trim());
    }
    return list.includes(iso);
}

function isWorkDay(iso) {
    if (!agendaConfig.workDays) return true;
    const d = new Date(iso + 'T12:00:00');
    let day = d.getDay(); // 0=Dom, 1=Lun
    // Convertir a formato 1=Lun...7=Dom
    let isoWDay = (day === 0) ? 7 : day;
    return agendaConfig.workDays.map(Number).some(w => w === isoWDay || (isoWDay === 7 && w === 0));
}

function renderTable(type) {
    const tableId = (type === 'dia_reporte') ? '#diaReporteTable' : (type === 'semana') ? '#agendaTable' : '#mesTable';
    const title = (type === 'dia_reporte') ? 'REPORTE DIARIO DE CITAS' : (type === 'semana') ? 'REPORTE SEMANAL DE CITAS' : 'REPORTE MENSUAL DE CITAS';
    
    // Filtrar citas según el rango
    const today = new Date(selectedDate);
    let startRange, endRange;

    if (type === 'dia_reporte') {
        const isoHoy = (typeof getISO === 'function') ? getISO(today) : today.toISOString().split('T')[0];
        startRange = new Date(isoHoy + 'T00:00:00');
        endRange = new Date(isoHoy + 'T23:59:59');
    } else if (type === 'semana') {
        const d = today.getDay() || 7;
        startRange = new Date(today);
        startRange.setDate(today.getDate() - (d - 1));
        startRange.setHours(0, 0, 0, 0);
        endRange = new Date(startRange);
        endRange.setDate(startRange.getDate() + 6);
        endRange.setHours(23, 59, 59, 999);
    } else {
        startRange = new Date(today.getFullYear(), today.getMonth(), 1, 0, 0, 0);
        endRange = new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59);
    }

    const filtered = getFilteredAppointments().filter(a => {
        const ad = new Date(a.start.split('T')[0] + 'T12:00:00');
        return ad >= startRange && ad <= endRange;
    }).sort((a,b) => a.start.localeCompare(b.start));

    if ($.fn.DataTable.isDataTable(tableId)) {
        $(tableId).DataTable().destroy();
    }

    $(tableId + ' tbody').empty();
    filtered.forEach(a => {
        const f = a.start.split('T')[0];
        const h = a.start.split('T')[1].substring(0, 5);
        const hFin = (a.end && a.end.includes('T')) ? a.end.split('T')[1].substring(0, 5) : '';
        const hDisplay = hFin ? `${h} - ${hFin}` : h;
        const st = a.extendedProps?.estado || 'Reservada';
        const resSt = resolverEstadoCita(st, f, hFin);
        const stKey = resSt.clave;
        let stBadgeStyle = `background-color: ${resSt.color} !important; color: ${stKey.toLowerCase().includes('confirmada') ? '#1e293b' : '#ffffff'} !important;`;
        if (resSt.esNoRealizada || resSt.esCancelada) {
            stBadgeStyle += ' text-decoration: line-through;';
        }
        const stBadgeCls = (resSt.esNoRealizada || resSt.esCancelada) ? 'text-decoration-line-through' : '';

        let mNom = a.extendedProps?.medico || a.extendedProps?.doctor || '';
        if (!mNom || mNom === 'Profesional Asignado') {
            const medId = a.extendedProps?.id_medico;
            if (medId && window.medicosCatalogo && window.medicosCatalogo[medId]) {
                mNom = window.medicosCatalogo[medId];
            }
        }
        if (!mNom) mNom = '---';

        const espNom = a.extendedProps?.espacio || a.extendedProps?.consultorio || 'Consultorio 1';
        const pacNom = a.title || 'Arrendatario';
        const expNum = a.id ? `${a.id}` : '';
        const motivo = a.extendedProps?.motivo || 'Renta de Espacio';
        const tarifaTxt = '$' + parseFloat(a.extendedProps?.monto_renta || 0).toFixed(2);

        $(tableId + ' tbody').append(`
            <tr>
                <td class="fw-bold" data-label="Fecha">${f}</td>
                <td data-label="Horario"><span class="badge bg-light text-navy border">${hDisplay}</span></td>
                <td class="fw-black text-primary" data-label="Arrendatario">
                    <div>${pacNom}</div>
                    ${expNum ? `<small class="text-muted d-block fw-normal" style="font-size:0.75rem;">${expNum}</small>` : ''}
                </td>
                <td class="small" data-label="Uso / Procedimiento">${motivo}</td>
                <td class="fw-bold text-success small" data-label="Tarifa">${tarifaTxt}</td>
                <td data-label="Espacio"><span class="badge bg-light text-navy border">${espNom}</span></td>
                <td data-label="Status"><span class="badge ${stBadgeCls} rounded-pill" style="${stBadgeStyle}">${st.toUpperCase()}</span></td>
                <td class="text-end" data-label="Acciones">
                    <button class="btn btn-sm btn-light rounded-3" onclick="abrirModalCita('${a.id}')" title="Editar / Ver Reserva"><i class="bi bi-pencil"></i></button>
                </td>
            </tr>
        `);
    });

    $(tableId).DataTable({
        language: { 
            url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json',
            search: '',
            searchPlaceholder: 'Buscar cita o paciente...',
            info: 'Mostrando _START_ a _END_ de _TOTAL_ registros',
            infoEmpty: 'Mostrando 0 registros',
            infoFiltered: '(de _MAX_ totales)',
            paginate: {
                previous: '« Ant',
                next: 'Sig »'
            }
        },
        dom: '<"agenda-dt-toolbar-wrapper d-flex flex-column flex-md-row justify-content-between align-items-center gap-2 mb-2"Bf>rt<"agenda-dt-footer-wrapper d-flex flex-column align-items-center gap-1 mt-2"ip>',
        buttons: {
            dom: {
                container: { className: 'dt-buttons export-toolbar m-0' },
                button: { className: 'btn-export' }
            },
            buttons: [
                { 
                    extend: 'copy', 
                    text: '<i class="bi bi-clipboard"></i><span class="export-label d-none d-md-inline ms-1">Copiar</span>',
                    titleAttr: 'Copiar al portapapeles',
                    exportOptions: { columns: [0, 1, 2, 3, 4, 5, 6] }
                },
                { 
                    extend: 'excel', 
                    text: '<i class="bi bi-file-earmark-excel"></i><span class="export-label d-none d-md-inline ms-1">Excel</span>', 
                    titleAttr: 'Exportar a Excel',
                    title: 'Hospital SDM',
                    messageTop: 'Módulo: ' + title,
                    messageBottom: 'Aviso de confidencialidad: Este documento contiene información confidencial destinada únicamente al receptor autorizado.\r\nCódigo interno: SDM-AGENDA',
                    exportOptions: { columns: [0, 1, 2, 3, 4, 5, 6] },
                    customize: function(xlsx) {
                        var sheet = xlsx.xl.worksheets['sheet1.xml'];
                        $('row c[r^="A1"]', sheet).attr('s', '2');
                    }
                },
                { 
                    extend: 'pdf', 
                    text: '<i class="bi bi-file-earmark-pdf"></i><span class="export-label d-none d-md-inline ms-1">PDF</span>', 
                    titleAttr: 'Exportar a PDF',
                    title: 'Hospital SDM',
                    messageTop: 'Módulo: ' + title,
                    exportOptions: { columns: [0, 1, 2, 3, 4, 5, 6] },
                    customize: function (doc) {
                        doc.styles.tableHeader = { fillColor: '#0d1e3d', color: 'white', alignment: 'center', bold: true, fontSize: 9 };
                        
                        var tableIndex = -1;
                        for (var i = 0; i < doc.content.length; i++) {
                            if (doc.content[i].table) {
                                tableIndex = i;
                                break;
                            }
                        }

                        if (tableIndex > -1) {
                            doc.content[tableIndex].table.widths = ['12%', '12%', '22%', '18%', '16%', '10%', '10%'];
                            doc.content[tableIndex].margin = [0, 10, 0, 10];
                            if (tableIndex > 0) {
                                doc.content.splice(0, tableIndex);
                            }
                        }

                        var now = new Date();
                        var jsDate = now.getDate().toString().padStart(2, '0') + '/' + (now.getMonth() + 1).toString().padStart(2, '0') + '/' + now.getFullYear();
                        
                        doc['header'] = (function() {
                            return {
                                columns: [
                                    { alignment: 'left', text: 'Hospital SDM\nMódulo: ' + title + '\nFecha: ' + jsDate, margin: [20, 20], fontSize: 10, bold: true }
                                ]
                            };
                        });
                        
                        doc.pageMargins = [20, 80, 20, 80];
                        
                        doc['footer'] = (function(page, pages) {
                            return {
                                columns: [
                                    { alignment: 'left', text: 'Aviso de confidencialidad: Este documento contiene información confidencial destinada únicamente al receptor autorizado.\nCódigo interno: SDM-AGENDA', fontSize: 8 },
                                    { alignment: 'right', text: 'Página ' + page.toString() + ' de ' + pages.toString(), fontSize: 8 }
                                ],
                                margin: [20, 10]
                            }
                        });
                    }
                },
                { 
                    text: '<i class="bi bi-printer"></i><span class="export-label d-none d-md-inline ms-1">Imprimir</span>',
                    titleAttr: 'Ver Reporte Personalizado para Impresión',
                    className: 'btn-export btn-export-print',
                    action: function (e, dt, node, config) {
                        window.abrirReportePersonalizado(type);
                    }
                }
            ]
        },
        pageLength: 15,
        responsive: true
    });

    // Activar tooltips en botones de exportación
    setTimeout(() => {
        $(`${tableId}_wrapper .btn-export`).each(function() {
            const tip = $(this).attr('title') || $(this).data('bs-original-title');
            if (tip && typeof bootstrap !== 'undefined' && bootstrap.Tooltip) {
                new bootstrap.Tooltip(this, { title: tip, placement: 'top', trigger: 'hover' });
            }
        });
    }, 150);
}
/**
 * Ajustes de Agenda (Multi-Ámbito: Sucursal Física vs Médico)
 */
function cambiarAmbitoAjustes(tipo) {
    if (tipo === 'sucursal') {
        $("#adj_sucursal_wrapper").removeClass('d-none');
        $("#adj_medico_wrapper").addClass('d-none');
        $("#adj_cancel_hours_wrapper").addClass('d-none');
        $("#lbl_adj_h_ini").text("Apertura Sede");
        $("#lbl_adj_h_fin").text("Cierre Sede");
        $("#lbl_adj_dias").text("Días Hábiles de Renta en la Sede");
        $("#lbl_adj_festivos").text("Días Inhábiles / Mantenimiento");
        
        const curSuc = $("#adj_sucursal_select").val() || $("#f_sucursal").val() || '1';
        if ($("#adj_sucursal_select").length) {
            $("#adj_sucursal_select").val(curSuc);
        }
        cargarAjustesSucursal(curSuc);
    } else {
        $("#adj_sucursal_wrapper").addClass('d-none');
        $("#adj_medico_wrapper").removeClass('d-none');
        $("#adj_cancel_hours_wrapper").removeClass('d-none');
        $("#lbl_adj_h_ini").text("Inicio de Consulta");
        $("#lbl_adj_h_fin").text("Fin de Consulta");
        $("#lbl_adj_dias").text("Días Laborales del Médico");
        $("#lbl_adj_festivos").text("Vacaciones / Inasistencias del Médico");
        
        const curMed = $("#adj_medico_select").val() || $("#f_medico").val() || '2';
        if ($("#adj_medico_select").length) {
            $("#adj_medico_select").val(curMed);
        }
        cargarAjustesMedico(curMed);
    }
}

window.onSliderIntervaloChange = function(stepVal) {
    const mapSteps = { '0': 15, '1': 30, '2': 60 };
    const minutos = mapSteps[String(stepVal)] || 30;
    window.updateIntervalModal(minutos);
};

window.setIntervaloPorValor = function(minutos, moveSlider = true) {
    window.updateIntervalModal(minutos);
};

window.updateIntervalModal = function(val) {
    val = parseInt(val, 10) || 30;
    const validVal = (val <= 20) ? 15 : (val >= 45 ? 60 : 30);
    $("#badgeIntervalo, #lbl_adj_int_badge").text(`${validVal} minutos`);
    $("#sliderInterval").val(validVal);
    $("#adj_int").val(String(validVal));
    $(`#int${validVal}`).prop('checked', true);

    const stepIdx = (validVal === 15) ? 0 : (validVal === 60 ? 2 : 1);
    $("#slider_adj_int").val(stepIdx);
    $("#mark_int_15, #mark_int_30, #mark_int_60").removeClass('active-mark');
    $(`#mark_int_${validVal}`).addClass('active-mark');
};

window.handleSliderIntervalModal = function(val) {
    val = parseInt(val, 10) || 30;
    let target = 30;
    if (val <= 22) target = 15;
    else if (val <= 45) target = 30;
    else target = 60;
    window.updateIntervalModal(target);
};

/* --- CONTROLADORES DE DÍAS HÁBILES (PÍLDORAS TÁCTILES) --- */
window.toggleDiaPill = function(btn, dayNum) {
    const chk = $(`#d${dayNum}`);
    const nowChecked = !chk.is(':checked');
    chk.prop('checked', nowChecked);
    if (nowChecked) $(btn).addClass('active');
    else $(btn).removeClass('active');
    window.actualizarBadgeDiasActivos();
};

window.actualizarBadgeDiasActivos = function() {
    const total = $('.btn-day-pill.active').length;
    $('#badgeDiasActivos').text(`${total} Día${total === 1 ? '' : 's'} Activo${total === 1 ? '' : 's'}`);
};

/* --- CONTROLADORES DE BLOQUEO DE ESPACIOS FÍSICOS (.space-item-card) --- */
window.renderizarListaBloqueoEspaciosModal = function(idSuc, bloqueadosStr) {
    const cont = $("#lista_bloqueo_espacios_modal");
    if (!cont.length) return;

    const bloqueadosList = (bloqueadosStr || '')
        .split(',')
        .map(s => normalizarTextoEspacio(s))
        .filter(Boolean);

    const poblarCards = function(consCount, qxCount) {
        let html = '';
        const cNum = Math.max(1, parseInt(consCount) || 1);
        const qNum = Math.max(0, parseInt(qxCount) || 0);

        for (let i = 1; i <= cNum; i++) {
            const label = `Consultorio ${i}`;
            const isLocked = bloqueadosList.includes(normalizarTextoEspacio(label));
            html += `
                <div class="col-12 col-sm-6">
                    <div class="space-item-card ${isLocked ? 'is-blocked' : ''}" onclick="window.toggleSpaceCard(this)">
                        <div class="d-flex align-items-center gap-2">
                            <input class="form-check-input m-0 chk-bloqueo-espacio" type="checkbox" value="${label}" ${isLocked ? 'checked' : ''} onclick="event.stopPropagation(); window.syncSpaceCardState(this)">
                            <span class="small fw-semibold text-truncate">${label}</span>
                        </div>
                        <span class="badge ${isLocked ? 'text-danger-emphasis bg-danger-subtle border border-danger-subtle' : 'text-secondary bg-light border'} small py-0.5 px-1.5">
                            <i class="bi ${isLocked ? 'bi-lock-fill me-1' : 'bi-door-open me-1'}"></i>${isLocked ? 'Bloqueado' : 'Libre'}
                        </span>
                    </div>
                </div>
            `;
        }
        for (let i = 1; i <= qNum; i++) {
            const label = `Quirófano ${i}`;
            const isLocked = bloqueadosList.includes(normalizarTextoEspacio(label));
            html += `
                <div class="col-12 col-sm-6">
                    <div class="space-item-card ${isLocked ? 'is-blocked' : ''}" onclick="window.toggleSpaceCard(this)">
                        <div class="d-flex align-items-center gap-2">
                            <input class="form-check-input m-0 chk-bloqueo-espacio" type="checkbox" value="${label}" ${isLocked ? 'checked' : ''} onclick="event.stopPropagation(); window.syncSpaceCardState(this)">
                            <span class="small fw-semibold text-truncate">${label}</span>
                        </div>
                        <span class="badge ${isLocked ? 'text-danger-emphasis bg-danger-subtle border border-danger-subtle' : 'text-primary bg-primary-subtle border border-primary-subtle'} small py-0.5 px-1.5">
                            <i class="bi ${isLocked ? 'bi-lock-fill me-1' : 'bi-scissors me-1'}"></i>${isLocked ? 'Bloqueado' : 'Quirúrgico'}
                        </span>
                    </div>
                </div>
            `;
        }
        cont.html(html);
        window.actualizarEspaciosBloqueadosHidden();
    };

    const rec = window.sucursalRecursos;
    if (rec && rec.sucursales && rec.sucursales.length > 0) {
        const sucObj = rec.sucursales.find(s => String(s.id) === String(idSuc)) || rec.sucursales[0];
        poblarCards(sucObj.consultorios, sucObj.quirofanos);
    } else if (rec && rec.consultorios) {
        poblarCards(rec.consultorios, rec.quirofanos);
    } else {
        $.get('../api/espacios_crud.pl', { accion: 'get_recursos', id_sucursal: idSuc }, function(data) {
            if (data && data.ok) {
                window.sucursalRecursos = data;
                poblarCards(data.consultorios, data.quirofanos);
            }
        });
    }
};

window.toggleSpaceCard = function(card) {
    const chk = card.querySelector('.chk-bloqueo-espacio');
    if (chk) {
        chk.checked = !chk.checked;
        window.syncSpaceCardState(chk);
    }
};

window.syncSpaceCardState = function(checkbox) {
    const card = checkbox.closest('.space-item-card');
    if (!card) return;
    const badge = card.querySelector('.badge');
    const isQx = (checkbox.value || card.innerText || '').toLowerCase().includes('quir');
    if (checkbox.checked) {
        card.classList.add('is-blocked');
        if (badge) {
            badge.className = 'badge text-danger-emphasis bg-danger-subtle border border-danger-subtle small py-0.5 px-1.5';
            badge.innerHTML = '<i class="bi bi-lock-fill me-1"></i>Bloqueado';
        }
    } else {
        card.classList.remove('is-blocked');
        if (badge) {
            if (isQx) {
                badge.className = 'badge text-primary bg-primary-subtle border border-primary-subtle small py-0.5 px-1.5';
                badge.innerHTML = '<i class="bi bi-scissors me-1"></i>Quirúrgico';
            } else {
                badge.className = 'badge text-secondary bg-light border small py-0.5 px-1.5';
                badge.innerHTML = '<i class="bi bi-door-open me-1"></i>Libre';
            }
        }
    }
    window.actualizarEspaciosBloqueadosHidden();
};

window.actualizarEspaciosBloqueadosHidden = function() {
    const bloqueados = [];
    $(".chk-bloqueo-espacio:checked").each(function() {
        bloqueados.push($(this).val());
    });
    $("#adj_espacios_bloqueados").val(bloqueados.join(','));
};

window.marcarBloqueoTodosEspacios = function(marcar) {
    $(".chk-bloqueo-espacio").each(function() {
        this.checked = !!marcar;
        window.syncSpaceCardState(this);
    });
};

/* --- CONTROLADORES DE DÍAS INHÁBILES / MANTENIMIENTO CON TAGS DINÁMICOS --- */
window.agregarFechaInhabil = function() {
    const picker = document.getElementById('adj_fest_picker');
    const select = document.getElementById('selectMotivoInhabil');
    const hiddenFest = document.getElementById('adj_fest');
    if (!picker || !picker.value) return;

    const fecha = picker.value;
    let cur = hiddenFest.value ? hiddenFest.value.split(',').map(x => x.trim()).filter(Boolean) : [];
    if (!cur.includes(fecha)) {
        cur.push(fecha);
        hiddenFest.value = cur.join(', ');
    }
    window.renderizarTagsFechasInhabiles(hiddenFest.value);
    picker.value = '';
};

window.eliminarFechaInhabil = function(fecha) {
    const hiddenFest = document.getElementById('adj_fest');
    if (!hiddenFest) return;
    let cur = hiddenFest.value ? hiddenFest.value.split(',').map(x => x.trim()).filter(Boolean) : [];
    cur = cur.filter(f => f !== fecha);
    hiddenFest.value = cur.join(', ');
    window.renderizarTagsFechasInhabiles(hiddenFest.value);
};

window.renderizarTagsFechasInhabiles = function(festivosStr) {
    const cont = document.getElementById('contenedorTagsFechas');
    if (!cont) return;
    const list = (festivosStr || '').split(',').map(x => x.trim()).filter(Boolean);
    if (!list.length) {
        cont.innerHTML = '<span class="text-muted small py-1" style="font-size: 0.72rem;">Sin días inhábiles registrados.</span>';
        return;
    }
    let html = '';
    list.forEach(f => {
        html += `
            <span class="date-tag date-tag-amber">
                <i class="bi bi-circle-fill text-warning" style="font-size: 0.45rem;"></i>
                <span>${f}</span>
                <button type="button" class="remove-btn" onclick="window.eliminarFechaInhabil('${f}')">&times;</button>
            </span>
        `;
    });
    cont.innerHTML = html;
};

function toggleComidaAjustes(sinComida) {
    const recesoDiv = document.getElementById('recesoFields');
    if (recesoDiv) {
        recesoDiv.style.opacity = sinComida ? '0.35' : '1';
        recesoDiv.style.pointerEvents = sinComida ? 'none' : 'auto';
    }
    if (sinComida) {
        $("#adj_c_ini, #adj_c_fin").prop('disabled', true);
    } else {
        $("#adj_c_ini, #adj_c_fin").prop('disabled', false);
        if (!$("#adj_c_ini").val()) $("#adj_c_ini").val('14:00');
        if (!$("#adj_c_fin").val()) $("#adj_c_fin").val('15:00');
    }
}

function cargarAjustesSucursal(idSuc) {
    if (!idSuc) {
        idSuc = $("#adj_sucursal_select").val() || $("#f_sucursal").val() || '1';
    }
    $.get('../api/espacios_crud.pl', { accion: 'get_config', tipo_ambito: 'sucursal', id_sucursal: idSuc }, function(res) {
        if (res.ok && res.config) {
            const cfg = res.config;
            $("#adj_h_ini").val(cfg.laborStart || '07:00');
            $("#adj_h_fin").val(cfg.laborEnd || '21:00');

            const sinComida = (!cfg.lunchStart || !cfg.lunchEnd || cfg.lunchStart === cfg.lunchEnd || (cfg.lunchStart === '00:00' && cfg.lunchEnd === '00:00'));
            $("#adj_sin_comida").prop('checked', sinComida);
            toggleComidaAjustes(sinComida);
            if (!sinComida) {
                $("#adj_c_ini").val(cfg.lunchStart || '14:00');
                $("#adj_c_fin").val(cfg.lunchEnd || '15:00');
            }

            window.updateIntervalModal(cfg.intervalo_minutos || 30);
            $("#adj_cancel_hours").val(cfg.cancel_hours || '24');
            const festStr = cfg.festivos_sucursal || cfg.festivos || '';
            $("#adj_fest").val(festStr);
            window.renderizarTagsFechasInhabiles(festStr);
            $("#adj_espacios_bloqueados").val(cfg.espacios_bloqueados || '');
            window.renderizarListaBloqueoEspaciosModal(idSuc, cfg.espacios_bloqueados || '');
            
            $(".adj-dia").prop('checked', false);
            $(".btn-day-pill").removeClass('active');
            if (cfg.workDays && Array.isArray(cfg.workDays)) {
                cfg.workDays.forEach(d => {
                    let dNum = parseInt(d);
                    if (dNum === 0) dNum = 7;
                    $(`#d${dNum}`).prop('checked', true);
                    $(`.btn-day-pill[data-day="${dNum}"]`).addClass('active');
                });
            }
            window.actualizarBadgeDiasActivos();
        }
    });
}

function cargarAjustesMedico(idMed) {
    if (!idMed) return;
    $.get('../api/espacios_crud.pl', { accion: 'get_config', tipo_ambito: 'medico', id_medico: idMed }, function(res) {
        if (res.ok && res.config) {
            const cfg = res.config;
            $("#adj_h_ini").val(cfg.laborStart || '08:00');
            $("#adj_h_fin").val(cfg.laborEnd || '18:00');

            const sinComida = (!cfg.lunchStart || !cfg.lunchEnd || cfg.lunchStart === cfg.lunchEnd || (cfg.lunchStart === '00:00' && cfg.lunchEnd === '00:00'));
            $("#adj_sin_comida").prop('checked', sinComida);
            toggleComidaAjustes(sinComida);
            if (!sinComida) {
                $("#adj_c_ini").val(cfg.lunchStart || '14:00');
                $("#adj_c_fin").val(cfg.lunchEnd || '16:00');
            }

            $("#adj_int").val(cfg.intervalo_minutos || '30');
            $("#adj_cancel_hours").val(cfg.cancel_hours || '24');
            $("#adj_fest").val(cfg.festivos_medico || '');
            
            $(".adj-dia").prop('checked', false);
            if (cfg.workDays && Array.isArray(cfg.workDays)) {
                cfg.workDays.forEach(d => {
                    $(`#d${d}`).prop('checked', true);
                    if (d == 7 || d == 0) {
                        $("#d7, #d0").prop('checked', true);
                    }
                });
            }
        }
    });
}

function abrirModalAjustes() {
    const el = document.getElementById('modalAjustes');
    if (!el) {
        console.error("Error: Elemento #modalAjustes no encontrado en el DOM.");
        return;
    }

    if (typeof bootstrap === 'undefined') {
        console.error("Error: Bootstrap JS no está cargado.");
        return;
    }

    const m = bootstrap.Modal.getInstance(el) || new bootstrap.Modal(el);
    
    // Determinar ámbito inicial
    const curSuc = $("#f_sucursal").val() || '1';
    if ($("#adj_sucursal_select").length) {
        $("#adj_sucursal_select").val(curSuc);
    }
    const curMed = $("#f_medico").val() || $("#f_medico_select").val() || '';
    if (curMed && curMed !== 'todos' && $("#adj_medico_select").length) {
        $("#adj_medico_select").val(curMed);
    }

    let ambito = $('input[name="adj_tipo_ambito"]:checked').val() || 'sucursal';
    $(`input[name="adj_tipo_ambito"][value="${ambito}"]`).prop('checked', true);
    cambiarAmbitoAjustes(ambito);
    
    m.show();
}

function guardarAjustes() {
    const tipoAmbito = $('input[name="adj_tipo_ambito"]:checked').val() || 'sucursal';
    const dias = [];
    $(".adj-dia:checked").each(function() { dias.push($(this).val()); });

    const sinComida = $("#adj_sin_comida").is(':checked');
    const c_ini = sinComida ? '' : $("#adj_c_ini").val();
    const c_fin = sinComida ? '' : $("#adj_c_fin").val();
    
    const data = {
        accion: 'save_config',
        tipo_ambito: tipoAmbito,
        h_ini: $("#adj_h_ini").val(),
        h_fin: $("#adj_h_fin").val(),
        sin_comida: sinComida ? 1 : 0,
        c_ini: c_ini,
        c_fin: c_fin,
        int: $("#adj_int").val(),
        festivos: $("#adj_fest").val(),
        espacios_bloqueados: $("#adj_espacios_bloqueados").val() || '',
        dias: dias.join(',')
    };

    if (tipoAmbito === 'sucursal') {
        const idSuc = $("#adj_sucursal_select").val() || $("#f_sucursal").val() || '1';
        data.id_sucursal = idSuc;
    } else {
        const idMed = ($("#adj_medico_select").length && $("#adj_medico_select").val()) 
            ? $("#adj_medico_select").val() 
            : ($("#f_medico").val() || '2');
        data.id_medico = idMed;
        data.cancel_hours = $("#adj_cancel_hours").val();
    }

    $.post('../api/espacios_crud.pl', data, function(res) {
        if (res.ok) {
            let swalConfig = {
                icon: 'success',
                title: 'Ajustes Guardados',
                text: tipoAmbito === 'sucursal' 
                    ? 'El horario operativo de la sucursal ha sido actualizado con éxito.' 
                    : 'Las preferencias del médico han sido actualizadas con éxito.',
                confirmButtonColor: '#103070'
            };
            if (res.warning) {
                swalConfig.icon = 'warning';
                swalConfig.title = 'Configuración Guardada con Advertencias';
                swalConfig.html = '<div class="text-start">' + res.warning + '</div>';
            }
            Swal.fire(swalConfig).then(() => {
                const bootstrapModal = bootstrap.Modal.getInstance(document.getElementById('modalAjustes'));
                if (bootstrapModal) bootstrapModal.hide();

                // Sincronizar inmediatamente memoria local de agendaConfig y re-renderizar filtro de toolbar
                if (!agendaConfig) agendaConfig = {};
                agendaConfig.espacios_bloqueados = data.espacios_bloqueados || '';
                agendaConfig.espacios_bloqueados_list = (data.espacios_bloqueados || '')
                    .split(',')
                    .map(s => normalizarTextoEspacio(s))
                    .filter(Boolean);

                if (typeof window.poblarFiltroRecursosToolbar === 'function' && window.sucursalRecursos) {
                    window.poblarFiltroRecursosToolbar(window.sucursalRecursos);
                }
                if (typeof window.actualizarHeaderEspaciosHabilitados === 'function') {
                    window.actualizarHeaderEspaciosHabilitados();
                }

                if (typeof loadContext === 'function') {
                    loadContext(); // Recargar para aplicar cambios visualmente
                } else if (typeof cargarCitas === 'function') {
                    cargarCitas();
                } else {
                    location.reload();
                }
            });
        } else {
            Swal.fire('Error', res.msg, 'error');
        }
    });
}

// Exponer al ámbito global para compatibilidad con eventos inline
window.cambiarAmbitoAjustes = cambiarAmbitoAjustes;
window.cargarAjustesSucursal = cargarAjustesSucursal;
window.cargarAjustesMedico = cargarAjustesMedico;
window.abrirModalAjustes = abrirModalAjustes;
window.guardarAjustes = guardarAjustes;
window.toggleComidaAjustes = toggleComidaAjustes;

// ==========================================================================
// MÓDULO DE REPORTE PERSONALIZADO EJECUTIVO (DIARIO, SEMANAL Y MENSUAL)
// ==========================================================================
window.abrirReportePersonalizado = function(type) {
    type = type || currentView || 'dia_reporte';
    if (type === 'dia') type = 'dia_reporte';

    const today = (selectedDate instanceof Date && !isNaN(selectedDate)) ? new Date(selectedDate) : new Date();
    let startRange, endRange;
    let tituloDoc = 'REPORTE DIARIO DE CITAS MÉDICAS';
    let periodoTexto = '';

    if (type === 'dia_reporte') {
        const isoHoy = (typeof getISO === 'function') ? getISO(today) : today.toISOString().split('T')[0];
        startRange = new Date(isoHoy + 'T00:00:00');
        endRange = new Date(isoHoy + 'T23:59:59');
        tituloDoc = 'REPORTE DIARIO DE CITAS MÉDICAS';
        periodoTexto = `Día: ${today.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}`;
    } else if (type === 'semana') {
        const d = today.getDay() || 7;
        startRange = new Date(today);
        startRange.setDate(today.getDate() - (d - 1));
        startRange.setHours(0, 0, 0, 0);
        endRange = new Date(startRange);
        endRange.setDate(startRange.getDate() + 6);
        endRange.setHours(23, 59, 59, 999);
        tituloDoc = 'REPORTE SEMANAL DE CITAS MÉDICAS';
        const fIniStr = startRange.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' });
        const fFinStr = endRange.toLocaleDateString('es-ES', { day: 'numeric', month: 'short', year: 'numeric' });
        periodoTexto = `Semana: del ${fIniStr} al ${fFinStr}`;
    } else {
        startRange = new Date(today.getFullYear(), today.getMonth(), 1, 0, 0, 0);
        endRange = new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59);
        tituloDoc = 'REPORTE MENSUAL DE CITAS MÉDICAS';
        periodoTexto = `Mes: ${today.toLocaleDateString('es-ES', { month: 'long', year: 'numeric' })}`;
    }

    // 1. Filtrar citas respetando los filtros activos y el rango de fechas
    const citasFiltradas = (typeof getFilteredAppointments === 'function') ? getFilteredAppointments() : appointments;
    const citasRango = citasFiltradas.filter(a => {
        const ad = new Date(a.start.split('T')[0] + 'T12:00:00');
        return ad >= startRange && ad <= endRange;
    }).sort((a, b) => (a.start || '').localeCompare(b.start || ''));

    // 2. Encabezados Institucionales
    const nombreClinica = (document.getElementById('agenda_nombre_clinica') ? document.getElementById('agenda_nombre_clinica').value : '') || 
                          (agendaConfig && agendaConfig.nombre_clinica) || 'Clínica Médica de Especialidades';
    $('#repClinicaNombre').text(nombreClinica);
    $('#repTituloDocumento').text(tituloDoc);
    $('#repPeriodoBadge').text(periodoTexto);
    $('#repFolioBadge').text(`Folio: SDM-REP-${Date.now().toString().slice(-6)}`);

    const now = new Date();
    const fechaEmisionStr = `${now.toLocaleDateString('es-ES')} ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} hrs`;
    $('#repFechaEmision').text(`Emisión: ${fechaEmisionStr}`);

    // 3. Etiquetas de Filtros Activos
    let medicosLabel = 'Todos los Médicos';
    if (window.medicosChecked && window.todosLosMedicosIds && window.medicosChecked.length < window.todosLosMedicosIds.length) {
        if (window.medicosChecked.length === 0) {
            medicosLabel = 'Ninguno';
        } else if (window.medicosChecked.length === 1) {
            const mId = window.medicosChecked[0];
            const mName = (window.medicosCatalogo && window.medicosCatalogo[mId]) || `Médico #${mId}`;
            medicosLabel = mName;
        } else {
            medicosLabel = `${window.medicosChecked.length} seleccionados`;
        }
    }
    $('#repFiltroMedicos').html(`<i class="bi bi-person-badge text-primary me-1"></i>Médicos: ${medicosLabel}`);

    let recursosLabel = 'Todos los Espacios';
    if (window.recursosChecked && window.todosLosRecursosIds && window.recursosChecked.length < window.todosLosRecursosIds.length) {
        if (window.recursosChecked.length === 0) {
            recursosLabel = 'Ninguno';
        } else if (window.recursosChecked.length === 1) {
            recursosLabel = window.recursosChecked[0].replace(/_/g, ' ');
        } else {
            recursosLabel = `${window.recursosChecked.length} seleccionados`;
        }
    }
    $('#repFiltroEspacios').html(`<i class="bi bi-door-open-fill text-teal me-1"></i>Espacios: ${recursosLabel}`);

    // 4. Resumen Cuantitativo (KPIs)
    let total = citasRango.length;
    let confirmadas = 0;
    let enProceso = 0;
    let atendidas = 0;

    citasRango.forEach(c => {
        const st = (c.extendedProps?.estado || 'Programada').toLowerCase();
        if (st === 'atendida') {
            atendidas++;
        } else if (st.includes('consulta') || st.includes('proceso') || st.includes('espera')) {
            enProceso++;
        } else {
            confirmadas++;
        }
    });

    $('#kpiRepTotal').text(total);
    $('#kpiRepConfirmadas').text(confirmadas);
    $('#kpiRepEnProceso').text(enProceso);
    $('#kpiRepAtendidas').text(atendidas);

    // 5. Poblar Cuerpo de la Tabla
    const tbody = $('#repCitasTableBody');
    tbody.empty();

    if (citasRango.length === 0) {
        tbody.html(`
            <tr>
                <td colspan="7" class="text-center py-4 text-muted">
                    <i class="bi bi-calendar-x fs-2 d-block mb-1 opacity-50"></i>
                    No se encontraron citas en este periodo con los filtros seleccionados.
                </td>
            </tr>
        `);
    } else {
        citasRango.forEach(a => {
            const f = a.start.split('T')[0];
            const h = a.start.split('T')[1].substring(0, 5);
            const hFin = (a.end && a.end.includes('T')) ? a.end.split('T')[1].substring(0, 5) : '';
            const hDisplay = hFin ? `${h} - ${hFin}` : h;
            const st = a.extendedProps?.estado || 'Programada';
            const res = (typeof resolverEstadoCita === 'function') ? resolverEstadoCita(st, f, hFin) : { clave: st, badgeClass: 'bg-primary' };

            let mNom = a.extendedProps?.medico || a.extendedProps?.doctor || '';
            if (!mNom || mNom === 'Profesional Asignado') {
                const medId = a.extendedProps?.id_medico;
                if (medId && window.medicosCatalogo && window.medicosCatalogo[medId]) {
                    mNom = window.medicosCatalogo[medId];
                }
            }
            if (!mNom) mNom = '---';

            const espNom = a.extendedProps?.consultorio || a.extendedProps?.recurso || a.extendedProps?.lugar || 'Consultorio 1';
            const pacNom = a.title || 'Paciente';
            const expNum = a.extendedProps?.id_paciente ? `#${a.extendedProps?.id_paciente}` : '';
            const motivo = a.extendedProps?.motivo || 'Consulta General';

            tbody.append(`
                <tr>
                    <td class="fw-semibold text-nowrap">${f}</td>
                    <td class="text-nowrap"><span class="badge bg-light text-navy border">${hDisplay}</span></td>
                    <td>
                        <strong class="text-navy">${pacNom}</strong>
                        ${expNum ? `<small class="text-muted d-block">${expNum}</small>` : ''}
                    </td>
                    <td class="text-muted text-truncate" style="max-width: 170px;" title="${motivo}">${motivo}</td>
                    <td class="text-secondary">${mNom}</td>
                    <td><span class="badge bg-light text-secondary border">${espNom}</span></td>
                    <td class="text-center">
                        <span class="badge ${res.badgeClass}" style="font-size:0.7rem;">${res.clave}</span>
                    </td>
                </tr>
            `);
        });
    }

    // 6. Guardar snapshot en sessionStorage para sincronización reactiva instantánea
    try {
        const payload = {
            tipo: type,
            fecha: (typeof getISO === 'function') ? getISO(today) : today.toISOString().split('T')[0],
            titulo: tituloDoc,
            periodo: periodoTexto,
            clinica: nombreClinica,
            medicosLabel: medicosLabel,
            recursosLabel: recursosLabel,
            kpis: { total, confirmadas, enProceso, atendidas },
            citas: citasRango
        };
        sessionStorage.setItem('ospulso_reporte_espacios_payload', JSON.stringify(payload));
    } catch(e) { console.warn("Storage sync warning", e); }

    // 7. Parámetros de filtros para endpoint independiente
    const fIso = (typeof getISO === 'function') ? getISO(today) : today.toISOString().split('T')[0];
    let medsParam = 'all';
    if (window.medicosChecked && window.todosLosMedicosIds && window.medicosChecked.length < window.todosLosMedicosIds.length) {
        medsParam = (window.medicosChecked.length === 0) ? 'none' : window.medicosChecked.join(',');
    }
    let recsParam = 'all';
    if (window.recursosChecked && window.todosLosRecursosIds && window.recursosChecked.length < window.todosLosRecursosIds.length) {
        recsParam = (window.recursosChecked.length === 0) ? 'none' : window.recursosChecked.join(',');
    }

    // 8. Abrir reporte personalizado independiente (Estilo consentimientos, sin salida directa)
    const url = `../api/imprimir_reporte_espacios_api.pl?tipo=${encodeURIComponent(type)}&fecha=${encodeURIComponent(fIso)}&medicos=${encodeURIComponent(medsParam)}&recursos=${encodeURIComponent(recsParam)}`;
    window.open(url, '_blank');
};

window.imprimirReportePersonalizadoDirecto = function() {
    window.abrirReportePersonalizado(currentView);
};

// [SDM FIX] DOM Teleportation Protocol para evadir secuestros de z-index en moviles
document.addEventListener('DOMContentLoaded', function() {
    var modalCita = document.getElementById('modalCita');
    if (modalCita) {
        document.body.appendChild(modalCita);
    }
    var modalAjustes = document.getElementById('modalAjustes');
    if (modalAjustes) {
        document.body.appendChild(modalAjustes);
    }
    var quickModal = document.getElementById('appointmentQuickModal');
    if (quickModal) {
        document.body.appendChild(quickModal);
    }
    var repModal = document.getElementById('modalReportePersonalizado');
    if (repModal) {
        document.body.appendChild(repModal);
    }
});

// ==========================================================================
// SECCIÓN DE CUARENTENA: FUNCIONES LEGACY / COMPATIBILIDAD (NO BORRAR)
// Rutinas y stubs defensivos para garantizar retrocompatibilidad absoluta
// con otros scripts del ecosistema OSPulso.
// ==========================================================================
window.abrirModalImpresionAgenda = window.abrirModalImpresionAgenda || function() {
    if (typeof window.abrirReportePersonalizado === 'function') {
        window.abrirReportePersonalizado(currentView);
    } else if (typeof switchView === 'function') {
        switchView('dia_reporte');
    }
};

window.ejecutarImpresionAgendaDirecta = window.ejecutarImpresionAgendaDirecta || function() {
    if (typeof window.imprimirReportePersonalizadoDirecto === 'function') {
        window.imprimirReportePersonalizadoDirecto();
    } else {
        window.print();
    }
};

window.legacyRefreshCalendar = window.legacyRefreshCalendar || function() {
    if (typeof renderView === 'function') renderView();
};

window.legacyFilterDoctor = window.legacyFilterDoctor || function(docId) {
    if (typeof window.onMedicoCheckChange === 'function') window.onMedicoCheckChange();
};

window.legacyFilterResource = window.legacyFilterResource || function(resId) {
    if (typeof window.onRecursoCheckChange === 'function') window.onRecursoCheckChange();
};


