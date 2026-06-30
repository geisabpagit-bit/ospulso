// --- SDM AGENDA SPA ENGINE v1.5.0 [Estable 2026-04-14 16:35] ---
const CrystalToast = typeof Swal !== 'undefined' ? Swal.mixin({
    toast: true, position: 'top-end', showConfirmButton: false, timer: 3000, 
    timerProgressBar: true,
    didOpen: (t) => { t.addEventListener('mouseenter', Swal.stopTimer); t.addEventListener('mouseleave', Swal.resumeTimer); }
}) : null;

let selectedDate = new Date();
let appointments = [];
let agendaConfig = {};
let currentView = 'dia';
let duracionCita = 30;
let tableInstance = null;
let draggedId = null;
let manualDragId = null; // Para modo Doble Clic (Regla Smart-Drag)

/**
 * Vista Semanal Smart (Image 3 Style)
 */
function renderWeeklySmartView() {
    const scroll = $("#weekly-smart-scroll");
    const slotsCont = $("#weekly-smart-slots");
    scroll.empty(); slotsCont.empty();

    const base = new Date(selectedDate);
    const todayISO = getISO(new Date());
    
    // Determinamos número de días según el ancho de pantalla
    const isMobile = window.innerWidth < 768;
    const numDays = isMobile ? 3 : 7;
    const offset = Math.floor(numDays / 2);
    
    // Limpiamos clases de centrado y aplicamos según necesidad
    scroll.removeClass('justify-content-start justify-content-center').addClass('justify-content-center');

    for (let i = -offset; i <= offset; i++) {
        const d = new Date(base);
        d.setDate(d.getDate() + i);
        const iso = getISO(d);
        const active = iso === getISO(selectedDate);
        const holiday = isHoliday(iso);
        const isToday = iso === todayISO;
        const dayName = d.toLocaleDateString('es-ES', { weekday: 'short' }).replace('.', '');
        const dayNum = d.getDate();

        const card = $(`
            <div class="smart-day-card ${active ? 'active' : ''} ${holiday ? 'holiday' : ''}" 
                 onclick="selectSmartDate('${iso}')"
                 style="${isMobile ? 'min-width: 80px;' : 'min-width: 100px;'} flex: 0 0 auto;">
                <span class="small text-uppercase fw-bold ${active ? 'text-white' : 'opacity-50'}" style="font-size:0.6rem;">${dayName}</span>
                <span class="h4 fw-black m-0">${dayNum}</span>
                ${isToday && !active ? '<div style="width:6px; height:6px; background:var(--sdm-accent); border-radius:50%; margin-top:5px;"></div>' : '<div style="height:11px"></div>'}
            </div>
        `);
        scroll.append(card);
    }
    renderSmartSlots(getISO(selectedDate));
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

    const s = parseInt(agendaConfig.laborStart?.split(':')[0] || 9);
    const e = parseInt(agendaConfig.laborEnd?.split(':')[0] || 18);
    const interval = parseInt(agendaConfig.intervalo_minutos) || 30;
    const dayApts = appointments.filter(a => a.start.startsWith(date));

    const sections = [
        { label: 'MAÑANA', start: s, end: 13, icon: 'bi-brightness-high-fill' },
        { label: 'TARDE', start: 13, end: e, icon: 'bi-moon-stars-fill' }
    ];

    sections.forEach(sec => {
        const col = $(`
            <div class="col-md-6 mb-4">
                <div class="slot-category-label">
                    <div class="slot-category-icon"><i class="bi ${sec.icon}"></i></div>
                    ${sec.label}
                </div>
                <div class="row g-2" id="smart-slots-${sec.label}"></div>
            </div>
        `);
        cont.append(col);
        const inner = col.find(`#smart-slots-${sec.label}`);

        let delay = 0;
        for (let h = sec.start; h < sec.end; h++) {
            for (let m = 0; m < 60; m += interval) {
                const hhmm = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
                const hfM = h * 60 + m + interval;
                const hhmmF = `${Math.floor(hfM / 60).toString().padStart(2, '0')}:${(hfM % 60).toString().padStart(2, '0')}`;
                
                const isOcc = dayApts.some(a => {
                    const aHi = a.start.split('T')[1].substring(0, 5);
                    const aHf = a.end.split('T')[1].substring(0, 5);
                    return (hhmm < aHf && hhmmF > aHi);
                });

                const btn = $(`
                    <div class="col-4 col-sm-3 col-md-4">
                        <button class="liquid-slot-btn liquid-anim ${isOcc ? 'opacity-25' : ''}" 
                                style="animation-delay: ${delay}s"
                                ${isOcc ? 'disabled' : `onclick="abrirModalNuevaCita('${date}', '${hhmm}')"`}>
                            ${hhmm}
                        </button>
                    </div>
                `);
                inner.append(btn);
                delay += 0.03;
            }
        }
        if (inner.children().length === 0) inner.append('<div class="col-12 small text-muted opacity-50 p-3">No hay horarios disponibles en este turno.</div>');
    });

    // Auto-scroll a la hora actual o primer slot
    setTimeout(() => {
        const todayStr = getISO(new Date());
        if (date === todayStr) {
            const h = new Date().getHours().toString().padStart(2, '0');
            const targetBtn = cont.find(`.liquid-slot-btn:contains('${h}:')`).first();
            if (targetBtn.length) targetBtn[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
        } else {
            const firstActive = cont.find('.liquid-slot-btn:not(:disabled)').first();
            if (firstActive.length) firstActive[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }, 150);
}

$(document).ready(function() {
    initClock();
    loadContext();
    
    // Selector Duración (Diamond Edition Refactor)
    $(document).on('click', '.btn-dur', function() {
        $(".btn-dur").removeClass('btn-primary active').addClass('btn-outline-primary');
        $(this).addClass('btn-primary active').removeClass('btn-outline-primary');
        
        let val = $(this).data('v');
        duracionCita = isNaN(val) ? val : parseInt(val);
        
        console.info("Duración Seleccionada:", duracionCita);
        renderSlots($("#f_fecha").val());
    });

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
 * Autocompletado para el campo de paciente en el modal de citas
 */
function setupAutocomplete() {
    if ($.fn.autocomplete) {
        $("#f_paciente").autocomplete({
            source: function(request, response) {
                const idMed = $("#f_medico").val();
                console.info("Autocomplete -> Buscando:", request.term, "Médico:", idMed);
                
                if ($("#f_accion").val() !== 'create') {
                    console.warn("Autocomplete bloqueado: No es modo creación.");
                    response([]);
                    return;
                }

                $.ajax({
                    url: "../api/autocomplete_pacientes.pl",
                    dataType: "json",
                    data: { term: request.term, id_medico: idMed },
                    success: function(data) {
                        console.info("Autocomplete -> Respuesta recibida:", data.length, "pacientes.");
                        response(data);
                    },
                    error: function(xhr) {
                        console.error("Autocomplete -> Error en servidor:", xhr.statusText);
                    }
                });
            },
            minLength: 2,
            select: function(event, ui) {
                console.info("Autocomplete -> Seleccionado:", ui.item.value, "ID:", ui.item.id);
                $("#f_id_paciente").val(ui.item.id);
                $("#f_paciente").val(ui.item.value);
                return false;
            }
        });
    }
}

// Aliases para compatibilidad con versiones previas de citas.pl
function navigateDate(offset) { moveDate(offset); }
function navigateToday() { goToday(); }

function loadContext() {
    const idMed = $("#f_medico").val() || '2';
    $.get('../api/citas_crud.pl', { accion: 'get_events', id_medico: idMed }, function(res) {
        if (res.ok) {
            appointments = res.data;
            agendaConfig = res.config;
            duracionCita = parseInt(agendaConfig.intervalo_minutos) || 30;
            renderDuracionButtons();
            syncUI();
        }
    });
}

function renderDuracionButtons() {
    const int = parseInt(agendaConfig.intervalo_minutos) || 30;
    const g = $("#btn-group-duracion");
    g.empty();
    
    let l1 = int + 'm';
    if(int === 60) l1 = '1h';
    let val2 = int * 2;
    let l2 = val2 + 'm';
    if(val2 === 60) l2 = '1h';
    else if(val2 === 90) l2 = '1h 30m';
    else if(val2 === 120) l2 = '2h';
    
    g.append(`<button type="button" class="btn btn-outline-primary btn-dur active" data-v="${int}">${l1}</button>`);
    g.append(`<button type="button" class="btn btn-outline-primary btn-dur" data-v="${val2}">${l2}</button>`);
    g.append(`<button type="button" class="btn btn-outline-primary btn-dur" data-v="rest">RESTO</button>`);
    g.append(`<button type="button" class="btn btn-outline-primary btn-dur" data-v="all">DÍA</button>`);
}


function syncUI() {
    renderHeaders();
    renderView();
}

function switchView(v) {
    currentView = v;
    
    // Desktop Header Toggles
    $(".btn-view-toggle, .btn-report-toggle").removeClass('active');
    $(`#btn-v-${v.replace('_','-')}, #btn-r-${v}`).addClass('active');
    
    // Show/Hide Containers
    $(".agenda-view-container").addClass('d-none');
    $(`#view-${v.replace('_','-')}`).removeClass('d-none');

    renderView();
}

function renderView() {
    if (currentView === 'dia') renderTimeline();
    else if (currentView === 'semana_smart') renderWeeklySmartView();
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

    if (currentView === 'dia') {
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
    if (currentView === 'dia') selectedDate.setDate(selectedDate.getDate() + offset);
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

function renderTimeline() {
    renderSideCalendar();
    const cont = $("#timeline-container");
    cont.empty().html('<div class="timeline-container animate__animated animate__fadeIn"></div>');
    const inner = cont.find('.timeline-container');
    
    const s = parseInt(agendaConfig.laborStart?.split(':')[0] || 9);
    const e = parseInt(agendaConfig.laborEnd?.split(':')[0] || 20);
    const interval = parseInt(agendaConfig.intervalo_minutos || 30);
    const iso = getISO(selectedDate);
    
    const dayApts = appointments.filter(a => a.start.startsWith(iso));

    for (let h = s; h < e; h++) {
        for (let m = 0; m < 60; m += interval) {
            const hStr = h.toString().padStart(2, '0');
            const mStr = m.toString().padStart(2, '0');
            const hhmm = `${hStr}:${mStr}`;
            const isP = !isFuture(iso, hhmm);
            const holiday = isHoliday(iso);
            
            const slotStartMin = h * 60 + m;
            const slotEndMin = slotStartMin + interval;
            const hasApt = dayApts.some(a => {
                const aHi = a.start.split('T')[1].substring(0,5);
                const aHf = a.end.split('T')[1].substring(0,5);
                const [ah, am] = aHi.split(':').map(Number);
                const [ahf, amf] = aHf.split(':').map(Number);
                const aptStartMin = ah * 60 + am;
                const aptEndMin = ahf * 60 + amf;
                return (slotStartMin < aptEndMin && slotEndMin > aptStartMin);
            });

            if (isP && !hasApt && !holiday) {
                continue; // Ocultar slots pasados sin citas
            }
            
            const row = $(`
                <div class="timeline-hour-row ${isP || holiday ? 'slot-locked' : ''}" 
                     onclick="handleSlotClick(event, '${iso}', '${hhmm}')" style="min-height: 60px;">
                <div class="timeline-hour-label" style="font-size:0.75rem; width:50px;">${hhmm}</div>
                    <div class="timeline-content-area" id="slot-${hStr}-${mStr}" style="position:relative;">
                        ${isP || holiday ? '<div class="locked-overlay"></div>' : ''}
                    </div>
                </div>
            `);
            inner.append(row);
        }
    }

    dayApts.forEach(a => {
        const startH = a.start.split('T')[1].substring(0, 5);
        const endH = a.end.split('T')[1].substring(0, 5);
        const status = a.extendedProps.estado || 'Programada';
        
        const [ah, am] = startH.split(':').map(Number);
        const [ahf, amf] = endH.split(':').map(Number);
        
        let slotM = Math.floor(am / interval) * interval;
        const sHStr = ah.toString().padStart(2, '0');
        const sMStr = slotM.toString().padStart(2, '0');
        
        const aptStartMin = ah * 60 + am;
        const aptEndMin = ahf * 60 + amf;
        const durationMin = aptEndMin - aptStartMin;
        const slotsSpanned = durationMin / interval;
        const topOffset = ((am - slotM) / interval) * 100;

        const card = $(`
            <div class="apt-card-dia ${status.toLowerCase()} ${manualDragId == a.id ? 'is-dragging-manual' : ''}" 
                 style="top: ${topOffset}%; --calc-height: calc(${slotsSpanned * 100}% - 4px); z-index: 10;"
                 onclick="event.stopPropagation(); handleAptClick('${a.id}')">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="fw-bold text-truncate" style="max-width:70%;">${a.title}</div>
                    <div class="small fw-bold" style="font-size:0.7rem; opacity:0.8;">${startH} - ${endH}</div>
                </div>
                <div class="small opacity-90 mt-1 text-truncate">${a.extendedProps.motivo}</div>
                <div class="badge bg-white text-dark small mt-2 py-1 px-2 rounded-pill fw-bold" style="font-size:0.6rem;">${status.toUpperCase()}</div>
                
                <div class="apt-actions-overlay">
                    <button class="btn-apt-action btn-apt-exp" onclick="event.stopPropagation(); window.open('render_expediente_clinico.pl?id=${a.extendedProps.id_paciente}', '_blank')" title="Ver Expediente"><i class="bi bi-person-vcard"></i></button>
                    <button class="btn-apt-action btn-apt-run" onclick="event.stopPropagation(); window.location.href='render_expediente_clinico.pl?id=${a.extendedProps.id_paciente}&modo=consulta'" title="Ir a Consulta"><i class="bi bi-play-fill"></i></button>
                    <button class="btn-apt-action btn-apt-wa" onclick="event.stopPropagation(); dummyReminder('${a.id}')" title="Enviar Recordatorio"><i class="bi bi-bell-fill"></i></button>
                    <button class="btn-apt-action" onclick="event.stopPropagation(); abrirModalCita('${a.id}')" title="Editar Ficha"><i class="bi bi-pencil-square"></i></button>
                    <button class="btn-apt-action btn-apt-del" onclick="event.stopPropagation(); delCita('${a.id}')" title="Eliminar"><i class="bi bi-trash"></i></button>
                </div>
            </div>
        `);
        $(`#slot-${sHStr}-${sMStr}`).append(card);
    });
}

function renderSideCalendar() {
    const cont = $("#side-datepicker"); if(!cont.length) return;
    cont.empty().html('<div class="side-cal-grid"></div>');
    const grid = cont.find('.side-cal-grid');
    
    const y = selectedDate.getFullYear(); const m = selectedDate.getMonth();
    const fd = (new Date(y, m, 1).getDay() || 7) - 1;
    const days = new Date(y, m + 1, 0).getDate();
    
    ['L','M','M','J','V','S','D'].forEach(d => grid.append(`<div class="text-center small fw-bold opacity-50">${d}</div>`));
    
    for(let i=0; i<fd; i++) grid.append('<div></div>');
    for(let d=1; d<=days; d++) {
        const iso = `${y}-${(m+1).toString().padStart(2,'0')}-${d.toString().padStart(2,'0')}`;
        const holiday = isHoliday(iso);
        const day = new Date(iso + 'T12:00:00').getDay();
        const isWeekend = (day === 0 || day === 6);
        const isActive = iso === getISO(selectedDate);
        
        const hasApts = appointments.some(a => a.start.startsWith(iso));
        const hasAptsClass = hasApts ? 'has-apts' : '';
        const isWork = isWorkDay(iso);
        let onclickAttr = `onclick="goDay('${iso}')"`;
        if (holiday || !isWork) {
            onclickAttr = 'style="cursor:not-allowed; opacity:0.5;" title="Día no disponible"';
        }
        
        const dayEl = $(`<div class="side-cal-day ${isActive?'active':''} ${holiday?'holiday':''} ${isWeekend?'weekend':''} ${hasAptsClass}" ${onclickAttr}>${d}</div>`);
        grid.append(dayEl);
    }
}

function dummyReminder(id) {
    const a = appointments.find(x => x.id == id);
    CrystalToast.fire({
        icon: 'info',
        title: 'Recordatorio Preparado',
        text: `Se ha simulado el envío de recordatorios (24h, 1h, 15m, 5m, 1m) para ${a.title}.`
    });
}

function renderTable(type) {
    const el = $("#agendaTable");
    let data = [];
    const normalizedSelected = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate());

    if (type === 'semana') {
        const start = new Date(normalizedSelected);
        const day = start.getDay() || 7; 
        if (day !== 1) start.setHours(-24 * (day - 1));
        const end = new Date(start);
        end.setDate(end.getDate() + 6);
        end.setHours(23, 59, 59);
        data = appointments.filter(a => {
            const d = new Date(a.start);
            return d >= start && d <= end;
        });
    } else {
        const m = normalizedSelected.getMonth();
        const y = normalizedSelected.getFullYear();
        data = appointments.filter(a => {
            const d = new Date(a.start);
            return d.getMonth() === m && d.getFullYear() === y;
        });
    }

    const mappedData = data.map(a => ({ 
        fecha: a.start.split('T')[0], 
        hora: `${a.start.split('T')[1].substring(0,5)} - ${a.end.split('T')[1].substring(0,5)}`, 
        paciente: a.title, 
        motivo: a.extendedProps.motivo, 
        status: a.extendedProps.estado, 
        id: a.id 
    }));

    if ($.fn.DataTable.isDataTable(el)) {
        const dt = el.DataTable();
        dt.clear().rows.add(mappedData).draw();
    } else {
        tableInstance = el.DataTable({
            data: mappedData,
            columns: [
                {data:'fecha', render: d => `<span class="fw-bold">${d}</span>`},
                {data:'hora', render: d => `<span class="text-primary fw-bold">${d}</span>`},
                {data:'paciente'},
                {data:'motivo'},
                {data:'status', render: s => `<span class="badge rounded-pill ${s==='Confirmada'?'bg-success':'bg-secondary'}">${s}</span>`},
                {data:'id', render: (id, type, row) => `
                    <div class="d-flex gap-1 justify-content-end">
                        <button class="btn btn-sm btn-light border text-navy" onclick="goDay('${row.fecha}')" title="Ver Día"><i class="bi bi-calendar2-day"></i></button>
                        <button class="btn btn-sm btn-light border text-success" onclick="sendWA('${id}')" title="WhatsApp"><i class="bi bi-whatsapp"></i></button>
                        <button class="btn btn-sm btn-light border text-primary" onclick="abrirModalCita('${id}')" title="Editar"><i class="bi bi-pencil"></i></button>
                        <button class="btn btn-sm btn-light border text-danger" onclick="delCita('${id}')" title="Eliminar"><i class="bi bi-trash"></i></button>
                    </div>
                `}
            ],
            createdRow: function(row, data, dataIndex) {
                $(row).find('td').each(function(i) {
                    const labels = ['Fecha', 'Hora', 'Paciente', 'Motivo', 'Status', 'Acciones'];
                    $(this).attr('data-label', labels[i]);
                });
            },
            dom: '<"d-flex justify-content-between align-items-center mb-4"Bf>rtip',
            buttons: [
                { extend: 'copy', text: '<i class="bi bi-clipboard"></i>', className: 'btn btn-sm btn-navy fw-bold px-3 rounded-3', titleAttr: 'Copiar' },
                { extend: 'excel', text: '<i class="bi bi-file-earmark-excel"></i>', className: 'btn btn-sm btn-success fw-bold px-3 rounded-3', titleAttr: 'Excel' },
                { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf"></i>', className: 'btn btn-sm btn-danger fw-bold px-3 rounded-3', titleAttr: 'PDF' },
                { extend: 'print', text: '<i class="bi bi-printer"></i>', className: 'btn btn-sm btn-dark fw-bold px-3 rounded-3', titleAttr: 'Imprimir' }
            ],
            language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
            order: [[0, 'asc'], [1, 'asc']]
        });
    }
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
    container.css({ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '1px', background: '#eee', borderRadius:'15px', overflow:'hidden' });
    ['LUN','MAR','MIE','JUE','VIE','SAB','DOM'].forEach(d => container.append(`<div class="bg-light p-2 text-center small fw-bold">${d}</div>`));
    for (let i=0; i<fd; i++) container.append('<div class="bg-white opacity-25"></div>');
    for (let d=1; d<=days; d++) {
        const iso = `${y}-${(m+1).toString().padStart(2,'0')}-${d.toString().padStart(2,'0')}`;
        const holiday = isHoliday(iso); const dayApts = appointments.filter(a => a.start.startsWith(iso));
        const isWork = isWorkDay(iso);
        const bgColor = holiday ? '#fee2e2' : (isWork ? 'white' : '#f1f5f9');
        const borderColor = holiday ? 'border-top:3px solid #ef4444' : (!isWork ? 'border-top:3px solid #cbd5e1' : '');

        container.append(`
            <div class="p-2 calendar-cell" ondragover="event.preventDefault()" ondrop="dropS(event, '${iso}')" onclick="handleSlotClick(event, '${iso}', '')" style="background:${bgColor}; min-height:110px; border:0.5px solid #f8fafc; ${borderColor}">
                <div class="d-flex justify-content-between align-items-start fw-bold small mb-1">
                    <span class="${iso===getISO(new Date())?'text-primary':''}">${d}</span>
                    ${holiday?'<small class="text-danger" style="font-size:0.5rem">FESTIVO</small>':(!isWork?'<small class="text-muted" style="font-size:0.5rem">NO LABORABLE</small>':'')}
                </div>
                ${dayApts.slice(0,3).map(a => {
                    const st = a.extendedProps.estado || 'Programada';
                    let bgColor = '#103070';
                    const stLow = st.trim().toLowerCase();
                    if (stLow === 'confirmada') bgColor = '#10b981';
                    else if (stLow.includes('atendida')) bgColor = '#3b82f6';
                    else if (stLow === 'cancelada') bgColor = '#ef4444';
                    else if (stLow === 'no asistió' || stLow === 'no asistio') bgColor = '#f59e0b';
                    
                    return `
                    <div class="mini-apt-pro d-flex justify-content-between align-items-center ${a.id == manualDragId ? 'is-dragging-manual':''}" 
                         onclick="event.stopPropagation(); handleAptClick('${a.id}')"
                         style="background:${bgColor}; ${stLow==='cancelada'?'text-decoration:line-through; opacity:0.6;':''} cursor:pointer;"
                         title="Estado: ${st}">
                        <span class="text-truncate" style="font-size:0.55rem;">${a.start.split('T')[1].substring(0,5)} ${a.title.split(' ')[0]}</span>
                        <div class="d-flex gap-1 align-items-center">
                            <i class="bi bi-grip-vertical cursor-pointer px-1 text-white opacity-75" style="font-size:0.8rem;" onclick="event.stopPropagation(); activateManualDrag('${a.id}')" title="Mover Cita (Drag Handle)"></i>
                            <i class="bi bi-calendar2-event cursor-pointer" style="font-size:0.55rem;" onclick="event.stopPropagation(); goDay('${iso}')" title="Ver Día"></i>
                            <i class="bi bi-pencil-square cursor-pointer" style="font-size:0.55rem;" onclick="event.stopPropagation(); abrirModalCita('${a.id}')" title="Editar Ficha"></i>
                            <i class="bi bi-trash cursor-pointer" style="font-size:0.55rem;" onclick="event.stopPropagation(); delCita('${a.id}')" title="Eliminar"></i>
                        </div>
                    </div>`
                }).join('')}
            </div>
        `);
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

    // Días de la semana
    ['L','M','M','J','V','S','D'].forEach(d => {
        grid.append(`<div class="text-center small fw-black opacity-40 mb-2" style="font-size:0.6rem;">${d}</div>`);
    });

    // Celdas vacías
    for (let i = 0; i < fd; i++) grid.append('<div></div>');

    // Días del mes
    for (let d = 1; d <= days; d++) {
        const dateObj = new Date(y, m, d);
        const iso = getISO(dateObj);
        const dayOfWeek = dateObj.getDay(); // 0=Dom, 6=Sab
        const holiday = isHoliday(iso);
        const isWeekend = (dayOfWeek === 0 || dayOfWeek === 6);
        const hasApts = appointments.some(a => a.start.startsWith(iso));
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
}

function renderMobileDayList() {
    const cont = $("#mini-calendar-appointments");
    cont.empty();
    
    const iso = getISO(selectedDate);
    const dayApts = appointments.filter(a => a.start.startsWith(iso)).sort((a,b) => a.start.localeCompare(b.start));

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
        const status = a.extendedProps.estado || 'Programada';
        const color = status === 'Confirmada' ? '#10b981' : (status === 'Cancelada' ? '#ef4444' : '#103070');
        
        const card = $(`
            <div class="mob-apt-card" style="border-left-color: ${color}" onclick="abrirModalCita('${a.id}')">
                <div class="mob-apt-time-box">
                    <span class="mob-apt-time-start">${hi}</span>
                    <span class="mob-apt-time-end">${hf}</span>
                </div>
                <div class="mob-apt-details">
                    <div class="mob-apt-paciente">${a.title}</div>
                    <div class="mob-apt-motivo">${a.extendedProps.motivo || 'Sin motivo'}</div>
                    <div class="mt-2">
                        <span class="badge rounded-pill" style="background:${color}20; color:${color}; font-size:0.6rem; border:1px solid ${color}40">
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
    const hi = $("#f_hi").val(); 
    const fecha = $("#f_fecha").val();
    const idPac = $("#f_id_paciente").val();

    if (!hi) {
        Swal.fire({ icon: 'info', title: 'Horario Requerido', text: 'Por favor, selecciona un horario disponible de la lista.' });
        return;
    }

    if (!idPac) {
        Swal.fire({ icon: 'warning', title: 'Paciente no seleccionado', text: 'Por favor, utiliza el buscador para seleccionar un paciente de la lista oficial.' });
        return;
    }

    // REGLA DE NEGOCIO: No permitir citas en el pasado
    if (fecha === getISO(new Date()) && duracionCita === 'all') {
        const now = new Date();
        const curH = now.getHours().toString().padStart(2, '0');
        const curM = now.getMinutes().toString().padStart(2, '0');
        $("#f_hi").val(`${curH}:${curM}`); // Opción 3: Ajuste automático de Todo el Día a la hora actual
    } else if (!isFuture(fecha, hi)) {
        Swal.fire({ 
            icon: 'warning', 
            title: 'Acción No Permitida', 
            text: 'No es posible agendar o modificar citas en una fecha u horario anterior al actual.',
            customClass: { popup: 'rounded-4' }
        });
        return;
    }

    // REGLA DE NEGOCIO: Detección estricta de colisiones (Regla 4)
    const hf = $("#f_hf").val();
    const curId = $("#f_id_cita").val() || "";
    const medId = String($("#f_medico").val() || "");
    const dayApps = appointments.filter(a => {
        return a.start.startsWith(fecha) && String(a.extendedProps.id_medico || "") === medId && String(a.id) !== curId;
    });
    
    const hasCollision = dayApps.some(a => {
        const aT = a.start.split('T')[1] || '';
        const aHi = aT.substring(0,5).padStart(5, '0');
        const aHf = (a.end.split('T')[1] || '').substring(0,5).padStart(5, '0');
        return (hi < aHf && hf > aHi);
    });

    if (hasCollision) {
        Swal.fire({
            icon: 'error',
            title: 'Colisión de Cita',
            text: 'Ya existe una cita programada en ese horario. Por favor selecciona un horario libre.',
            customClass: { popup: 'rounded-4' }
        });
        return;
    }

    const dataStr = f.serialize() + "&id_medico=" + $("#f_medico").val();
    
    $.post('../api/citas_crud.pl', dataStr, function(res) {
        if (res && res.ok) { 
            if(typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'success', title: 'Sincronizado' }); 
            else Swal.fire({ icon: 'success', title: 'Éxito', text: res.msg || 'Cita Guardada', timer: 1500, showConfirmButton: false });
            
            const modalEl = document.getElementById('modalCita');
            const modalIns = bootstrap.Modal.getInstance(modalEl) || new bootstrap.Modal(modalEl);
            modalIns.hide();
            
            loadContext(); 
        } else {
            Swal.fire({ icon: 'error', title: 'Error', text: (res ? res.msg : 'Error de conexión con el servidor') });
        }
    }, 'json').fail(function() {
        Swal.fire({ icon: 'error', title: 'Error Crítico', text: 'No se pudo comunicar con el servidor.' });
    });
}

/**
 * Valida si una fecha y hora están en el futuro respecto al momento actual
 */
function isFuture(dateStr, timeStr) {
    const now = new Date();
    // Forzamos la creación de la fecha para evitar desfases de segundos
    const targeted = new Date(`${dateStr}T${timeStr}:00`);
    
    // Si el día es hoy, comparamos también los minutos para mayor precisión
    return targeted.getTime() >= now.getTime();
}

function dragS(id) { 
    draggedId = id; 
}

function activateManualDrag(id) {
    if (manualDragId === id) {
        manualDragId = null; // Desactivar
        if (typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'info', title: 'Modo Mover Desactivado' });
    } else {
        manualDragId = id;
        if (typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'info', title: 'Modo Mover Activado', text: 'Haz clic en el destino (Día u Horario) para soltar la cita.' });
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
            goDay(iso); // NUEVO: Navegar a la vista diaria del día pasado
            return;
        }
    }
    
    abrirModalNuevaCita(iso, time);
}

function dropManualDrag(iso, time) {
    const id = manualDragId;
    const a = appointments.find(x => x.id == id);
    if (!a || isHoliday(iso)) {
        manualDragId = null;
        renderView();
        return;
    }

    let targetTime = time || a.start.split('T')[1].substring(0,5);

    if (!isFuture(iso, targetTime)) {
        Swal.fire({ 
            icon: 'warning', 
            title: 'Acción No Permitida', 
            text: 'No puedes mover una cita a una fecha o un horario que ya ha pasado.',
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

    $.post('../api/citas_crud.pl', { 
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
    const a = appointments.find(x => x.id == draggedId); 
    if (!a || isHoliday(iso)) return;

    const horaIni = a.start.split('T')[1].substring(0,5);

    // REGLA DE NEGOCIO: No permitir movimientos al pasado (Incluso el mismo día si la hora ya pasó)
    if (!isFuture(iso, horaIni)) {
        Swal.fire({ 
            icon: 'warning', 
            title: 'Acción No Permitida', 
            text: 'No puedes mover una cita a una fecha o un horario que ya ha pasado.',
            confirmButtonText: 'Entendido',
            customClass: { popup: 'rounded-4' }
        });
        return;
    }

    $.post('../api/citas_crud.pl', { 
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
        cont.append('<div class="text-center p-3 text-danger fw-bold border rounded-4 animate__animated animate__shakeX">DÍA NO LABORABLE</div>');
        return;
    }
    if (isHoliday(date)) {
        cont.append('<div class="text-center p-3 text-danger fw-bold border rounded-4 animate__animated animate__shakeX">DÍA FESTIVO / ASUETO</div>');
        return;
    }

    const s = parseInt(agendaConfig.laborStart.split(':')[0]);
    const e = parseInt(agendaConfig.laborEnd.split(':')[0]);
    const [ls, le] = [agendaConfig.lunchStart, agendaConfig.lunchEnd];
    const curId = $("#f_id_cita").val(); 
    const medId = String($("#f_medico").val() || "");
    const dayApps = appointments.filter(a => {
        const sameDay = a.start.startsWith(date);
        const sameMed = String(a.extendedProps.id_medico || "") === medId;
        const differentId = String(a.id) !== String(curId);
        return sameDay && sameMed && differentId;
    });

    const laborStartMin = s * 60;
    const laborEndMin = e * 60;

    // Si es "Todo el día", verificamos colisión global
    if (duracionCita === 'all') {
        const hhmmS = agendaConfig.laborStart || '09:00';
        const hhmmE = agendaConfig.laborEnd || '20:00';
        
        const isB = dayApps.some(a => {
            const aT = a.start.split('T')[1] || '';
            const aHi = aT.substring(0,5).padStart(5, '0');
            const aHf = (a.end.split('T')[1] || '').substring(0,5).padStart(5, '0');
            return (hhmmS < aHf && hhmmE > aHi);
        });

        if (!isB) {
            const btn = $(`<button type="button" class="btn btn-slot w-100 py-3 mb-2 fw-bold animate__animated animate__fadeIn">TODO EL DÍA (${hhmmS} - ${hhmmE})</button>`);
            btn.click(function() {
                $(".btn-slot").removeClass("active");
                $(this).addClass("active");
                $("#f_hi").val(hhmmS);
                $("#f_hf").val(hhmmE);
                $("#modalCitaTitle").text(`NUEVA CITA: TODO EL DÍA`);
            });
            cont.append(btn);
        } else {
            cont.append(`
                <div class="text-center p-3 opacity-90 small fw-bold text-danger border rounded-4 animate__animated animate__shakeX" style="background: #fee2e2;">
                    ⚠️ ACCIÓN NO DISPONIBLE:<br><br>El día seleccionado ya cuenta con citas agendadas y no está completamente libre.<br><br>Por favor, selecciona la opción 'RESTO' o un bloque específico para aprovechar los intervalos disponibles.
                </div>
            `);
        }
        return;
    }

    const interval = isNaN(duracionCita) ? 30 : duracionCita;
    const lStart = agendaConfig.laborStart || '09:00';
    const lEnd = agendaConfig.laborEnd || '20:00';

    for (let h = s; h < e; h++) {
        for (let m = 0; m < 60; m += interval) {
            const hh = h.toString().padStart(2,'0'); 
            const mm = m.toString().padStart(2,'0');
            const hhmm = `${hh}:${mm}`;
            
            let hhmmE;
            if (duracionCita === 'rest') {
                hhmmE = lEnd;
            } else {
                let tM = h * 60 + m + interval; 
                const hE = Math.floor(tM / 60).toString().padStart(2,'0'); 
                const mE = (tM % 60).toString().padStart(2,'0'); 
                hhmmE = `${hE}:${mE}`;
            }
            
            // Verificamos si el slot está en el pasado
            const isP = !isFuture(date, hhmm);
            let isL = (hhmm < le && hhmmE > ls);
            
            // Detección de Colisión Reforzada
            let isB = dayApps.some(a => {
                const aT = a.start.split('T')[1] || '';
                const aHi = aT.substring(0,5).padStart(5, '0');
                const aHf = (a.end.split('T')[1] || '').substring(0,5).padStart(5, '0');
                return (hhmm < aHf && hhmmE > aHi);
            });

            const btnText = duracionCita === 'rest' ? `${hhmm} ➔ FIN` : hhmm;
            const canBypassLunch = (duracionCita === 'rest');
            const btn = $(`<button type="button" class="btn btn-slot" ${isP || (isL && !canBypassLunch) || isB ? 'disabled' : ''}>${btnText}</button>`);
            
            if (isP) btn.addClass('bg-light text-muted opacity-50').attr('title', 'Pasado');
            if (isL) btn.addClass('slot-lunch').attr('title', 'Comida');
            if (isB) btn.addClass('slot-busy').attr('title', 'Ocupado');
            
            btn.click(function() { 
                $(".btn-slot").removeClass("active"); 
                $(this).addClass("active"); 
                $("#f_hi").val(hhmm); 
                $("#f_hf").val(hhmmE); 
                $("#modalCitaTitle").text(`CITA: ${hhmm} - ${hhmmE}`);
            });
            cont.append(btn);
        }
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

function abrirModalNuevaCita(f, h, idP, nomP) {
    const isGlobal = !f && !h;
    let targetF = f;
    if (!targetF) {
        targetF = getNextAvailableDate(getISO(new Date()));
    }
    
    // Si se especificó una hora, validamos que no sea en el pasado.
    if (!isGlobal && h && !isFuture(targetF, h)) {
        Swal.fire({ 
            icon: 'info', 
            title: 'Horario No Disponible', 
            text: 'No se pueden agendar citas en horarios que ya han pasado.', 
            customClass: { popup: 'rounded-4' } 
        });
        return;
    }

    $("#f_id_cita").val(''); 
    $("#f_accion").val('create'); 
    $("#f_fecha").val(targetF); 
    
    if (h) {
        $("#f_hi").val(h); 
        let [hh, mm] = h.split(':').map(Number); 
        mm += duracionCita; if(mm>=60){ mm=0; hh++; }
        const hf = `${hh.toString().padStart(2,'0')}:${mm.toString().padStart(2,'0')}`;
        $("#f_hf").val(hf); 
    } else {
        $("#f_hi").val(''); 
        $("#f_hf").val('');
    }
    
    $("#modalCitaTitle").text(`GESTIÓN DE CITAS / NUEVA CITA`);
    
    // Inyectar datos de paciente si vienen por parámetro o variables globales
    if (!idP && window.idPacientePre) idP = window.idPacientePre;
    if (!nomP && window.nombrePacientePre) nomP = window.nombrePacientePre;

    if (idP && nomP) {
        $("#f_paciente").val(nomP).prop('readonly', true).addClass('bg-light');
        $("#f_id_paciente").val(idP);
        $("#f_paciente").closest('.position-relative').find('.bi-search').hide();
    } else {
        $("#f_paciente").val('').prop('readonly', false).removeClass('bg-light');
        $("#f_id_paciente").val('');
        $("#f_paciente").closest('.position-relative').find('.bi-search').show();
    }

    $("#f_motivo").val(''); 
    $("#f_estado").val('Programada'); 
    renderSlots(targetF);
    const m = bootstrap.Modal.getOrCreateInstance(document.getElementById('modalCita'));
    m.show();
}

function abrirModalCita(id) {
    const a = appointments.find(x => x.id == id); if(!a) return;
    const hi = a.start.split('T')[1].substring(0,5);
    const hf = a.end.split('T')[1].substring(0,5);
    
    $("#f_id_cita").val(a.id); 
    $("#f_accion").val('update'); // ASEGURAR ACCION UPDATE
    $("#f_id_paciente").val(a.extendedProps.id_paciente);
    $("#f_paciente").val(a.title); // Restauramos el nombre del paciente en el buscador
    $("#f_fecha").val(a.start.split('T')[0]); 
    $("#f_hi").val(hi); 
    $("#f_hf").val(hf);
    $("#f_motivo").val(a.extendedProps.motivo); 
    $("#f_estado").val(a.extendedProps.estado || 'Programada'); 
    $("#modalCitaTitle").text(`GESTIÓN DE CITAS / EDITAR CITA`);

    // Bloqueo de Paciente en modo Edición
    $("#f_paciente").val(a.title).prop('readonly', true).addClass('bg-light');
    $("#f_paciente").closest('.position-relative').find('.bi-search').hide();

    // Regla 3: Si la cita está programada/confirmada y la fecha/hora permiten tomarla
    const est = (a.extendedProps.estado || 'Programada').trim().toLowerCase();
    let mostrarTomarCita = false;
    const aDate = a.start.split('T')[0];
    const todayStr = getISO(new Date());

    if ((est === 'programada' || est === 'confirmada' || est === 'no asistió' || est === 'no asistio') && aDate <= todayStr) {
        // Lógica A: Se permite tomar la cita si la hora de la cita es menor o igual a (Hora Actual + 1 hr)
        const now = new Date();
        const limitDate = new Date(now.getTime() + 60*60*1000); 
        
        const aptDate = new Date(`${aDate}T${hi}:00`);
        if (aptDate.getTime() <= limitDate.getTime()) {
            mostrarTomarCita = true;
        }
    }

    if (mostrarTomarCita) {
        $("#btn-tomar-cita").removeClass('d-none');
    } else {
        $("#btn-tomar-cita").addClass('d-none');
    }

    renderSlots(a.start.split('T')[0]);
    const m = bootstrap.Modal.getOrCreateInstance(document.getElementById('modalCita'));
    m.show();
}

function tomarCitaModal() {
    const id_cita = $("#f_id_cita").val();
    const id_paciente = $("#f_id_paciente").val();
    if (!id_cita || !id_paciente) return;
    
    const a = appointments.find(x => x.id == id_cita);
    if (!a) return;
    const hi = a.start.split('T')[1].substring(0,5);
    const fec = a.start.split('T')[0];
    
    if (!isFuture(fec, hi)) {
        // Es una cita en el pasado, se va a mover a "ahora"
        const now = new Date();
        const curH = now.getHours().toString().padStart(2,'0');
        const curM = now.getMinutes().toString().padStart(2,'0');
        const curTime = `${curH}:${curM}`;
        const todayStr = getISO(now);
        
        const hasCollision = appointments.some(x => {
            if (x.id == id_cita) return false;
            if (!x.start.startsWith(todayStr)) return false;
            const xHi = x.start.split('T')[1].substring(0,5);
            const xHf = x.end.split('T')[1].substring(0,5);
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
                if(r.isConfirmed) proceedTomarCita(id_cita, id_paciente);
            });
            return;
        }
    }
    
    proceedTomarCita(id_cita, id_paciente);
}

function proceedTomarCita(id_cita, id_paciente) {
    bootstrap.Modal.getInstance(document.getElementById('modalCita')).hide();
    if(typeof CrystalToast !== 'undefined') CrystalToast.fire({ icon: 'info', title: 'Preparando Consulta...' });
    
    setTimeout(() => {
        window.location.href = `render_consultas.pl?id=${id_paciente}&id_cita=${id_cita}`;
    }, 400);
}

function delCita(id) {
    Swal.fire({ 
        title: '¿Eliminar cita?', 
        text: "Esta acción no se puede deshacer.",
        icon: 'warning', 
        showCancelButton: true, 
        confirmButtonColor: '#d33',
        confirmButtonText: 'Sí, eliminar',
        cancelButtonText: 'Cancelar',
        customClass: { popup: 'rounded-4' }
    }).then((r) => {
        if(r.isConfirmed) $.post('../api/citas_crud.pl', { accion:'delete', id_cita:id }, function() { loadContext(); });
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
    // Si el usuario hace clic en el cuerpo de la cita, le damos un hint
    // o podemos simplemente activar el drag también.
    // Vamos a usar la misma lógica que activateManualDrag:
    activateManualDrag(id);
}

function initClock() { setInterval(() => { const n = new Date(); $("#digital-clock").text(n.toLocaleTimeString()); }, 1000); }
function getISO(d) { return d.toISOString().split('T')[0]; }
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
    return agendaConfig.workDays.map(Number).includes(isoWDay);
}

function renderTable(type) {
    const tableId = (type === 'semana') ? '#agendaTable' : '#mesTable';
    const title = (type === 'semana') ? 'REPORTE SEMANAL DE CITAS' : 'REPORTE MENSUAL DE CITAS';
    
    // Filtrar citas según el rango
    const today = new Date(selectedDate);
    let startRange, endRange;

    if (type === 'semana') {
        const d = today.getDay() || 7;
        startRange = new Date(today);
        startRange.setDate(today.getDate() - (d - 1));
        endRange = new Date(startRange);
        endRange.setDate(startRange.getDate() + 6);
    } else {
        startRange = new Date(today.getFullYear(), today.getMonth(), 1);
        endRange = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    }

    const filtered = appointments.filter(a => {
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
        const st = a.extendedProps.estado || 'Programada';
        $(tableId + ' tbody').append(`
            <tr>
                <td class="fw-bold" data-label="Fecha">${f}</td>
                <td data-label="Hora"><span class="badge bg-light text-navy border">${h}</span></td>
                <td class="fw-black text-primary" data-label="Paciente">${a.title}</td>
                <td class="small" data-label="Motivo">${a.extendedProps.motivo || ''}</td>
                <td data-label="Status"><span class="badge ${st==='Atendida'?'bg-success':'bg-primary'} rounded-pill">${st.toUpperCase()}</span></td>
                <td class="text-end" data-label="Acciones">
                    <button class="btn btn-sm btn-light rounded-3" onclick="abrirModalCita('${a.id}')"><i class="bi bi-pencil"></i></button>
                </td>
            </tr>
        `);
    });

    $(tableId).DataTable({
        language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
        dom: '<"p-3 d-flex justify-content-start align-items-center"B>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
        buttons: {
            dom: {
                container: { className: 'dt-buttons export-toolbar' },
                button: { className: 'btn-export' }
            },
            buttons: [
                { 
                    extend: 'copy', 
                    text: '<i class="bi bi-clipboard"></i> Copiar',
                    exportOptions: { columns: [0, 1, 2, 3, 4] }
                },
                { 
                    extend: 'excel', 
                    text: '<i class="bi bi-file-earmark-excel"></i> Excel', 
                    title: 'Hospital SDM',
                    messageTop: 'Módulo: ' + title,
                    messageBottom: 'Aviso de confidencialidad: Este documento contiene información confidencial destinada únicamente al receptor autorizado.\r\nCódigo interno: SDM-AGENDA',
                    exportOptions: { columns: [0, 1, 2, 3, 4] },
                    customize: function(xlsx) {
                        var sheet = xlsx.xl.worksheets['sheet1.xml'];
                        $('row c[r^="A1"]', sheet).attr('s', '2');
                    }
                },
                { 
                    extend: 'pdf', 
                    text: '<i class="bi bi-file-earmark-pdf"></i> PDF', 
                    title: 'Hospital SDM',
                    messageTop: 'Módulo: ' + title,
                    exportOptions: { columns: [0, 1, 2, 3, 4] },
                    customize: function (doc) {
                        doc.styles.tableHeader = { fillColor: '#0d1e3d', color: 'white', alignment: 'center', bold: true, fontSize: 10 };
                        
                        var tableIndex = -1;
                        for (var i = 0; i < doc.content.length; i++) {
                            if (doc.content[i].table) {
                                tableIndex = i;
                                break;
                            }
                        }

                        if (tableIndex > -1) {
                            doc.content[tableIndex].table.widths = ['15%', '15%', '30%', '25%', '15%'];
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
                    extend: 'print', 
                    text: '<i class="bi bi-printer"></i> Imprimir',
                    title: '',
                    exportOptions: { columns: [0, 1, 2, 3, 4] },
                    customize: function (win) {
                        var now = new Date();
                        var jsDate = now.getDate().toString().padStart(2, '0') + '/' + (now.getMonth() + 1).toString().padStart(2, '0') + '/' + now.getFullYear();
                        
                        $(win.document.body).css('font-family', 'Inter, sans-serif');
                        $(win.document.body).prepend(
                            '<div style="text-align:center; margin-bottom: 20px;">' +
                            '<h2>Hospital SDM</h2>' +
                            '<p><strong>Módulo:</strong> ' + title + '<br>' +
                            '<strong>Fecha:</strong> ' + jsDate + '</p>' +
                            '</div><hr>'
                        );
                        $(win.document.body).append(
                            '<hr><div style="font-size: 0.8rem; text-align:center; margin-top: 20px;">' +
                            '<p><strong>Aviso de confidencialidad:</strong> Este documento contiene información confidencial destinada únicamente al receptor autorizado.</p>' +
                            '<p><strong>Código interno:</strong> SDM-AGENDA</p>' +
                            '</div>'
                        );
                    }
                }
            ]
        },
        pageLength: 15,
        responsive: true
    });
}
/**
 * Ajustes de Agenda (Per-User Configuration)
 */
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

    const m = new bootstrap.Modal(el);
    
    // Poblar con valores actuales
    $("#adj_h_ini").val(agendaConfig.laborStart || '08:00');
    $("#adj_h_fin").val(agendaConfig.laborEnd || '18:00');
    $("#adj_c_ini").val(agendaConfig.lunchStart || '14:00');
    $("#adj_c_fin").val(agendaConfig.lunchEnd || '16:00');
    $("#adj_int").val(agendaConfig.intervalo_minutos || '30');
    $("#adj_fest").val(agendaConfig.festivos_medico || '');
    
    // Checkboxes días
    $(".adj-dia").prop('checked', false);
    if (agendaConfig.workDays && Array.isArray(agendaConfig.workDays)) {
        agendaConfig.workDays.forEach(d => {
            $(`#d${d}`).prop('checked', true);
        });
    }
    
    m.show();
}

function guardarAjustes() {
    const idMed = $("#f_medico").val() || '2';
    const dias = [];
    $(".adj-dia:checked").each(function() { dias.push($(this).val()); });
    
    const data = {
        accion: 'save_config',
        id_medico: idMed,
        h_ini: $("#adj_h_ini").val(),
        h_fin: $("#adj_h_fin").val(),
        c_ini: $("#adj_c_ini").val(),
        c_fin: $("#adj_c_fin").val(),
        int: $("#adj_int").val(),
        festivos: $("#adj_fest").val(),
        dias: dias.join(',')
    };

    $.post('../api/citas_crud.pl', data, function(res) {
        if (res.ok) {
            let swalConfig = {
                icon: 'success',
                title: 'Ajustes Guardados',
                text: 'Las preferencias de tu agenda han sido actualizadas.',
                confirmButtonColor: '#103070'
            };
            if (res.warning) {
                swalConfig.icon = 'warning';
                swalConfig.title = 'Configuración Guardada con Advertencias';
                swalConfig.html = '<div class="text-start">' + res.warning + '</div>';
            }
            Swal.fire(swalConfig).then(() => {
                const bootstrapModal = bootstrap.Modal.getInstance(document.getElementById('modalAjustes'));
                bootstrapModal.hide();
                loadContext(); // Recargar para aplicar cambios visualmente
            });
        } else {
            Swal.fire('Error', res.msg, 'error');
        }
    });
}
