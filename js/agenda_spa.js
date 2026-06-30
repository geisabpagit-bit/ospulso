// js/agenda_spa.js
let calendar;
let modalCita;
window.allEvents = []; // Cache global de citas

document.addEventListener('DOMContentLoaded', function() {
    // 1. Poblado Predictivo de Pacientes (Autocomplete)
    const $search = $('#cita_paciente_search');
    const $idField = $('#cita_id_paciente');
    
    $search.autocomplete({
        minLength: 1,
        source: window.pacientesList,
        select: function(event, ui) {
            $search.val(ui.item.label);
            $idField.val(ui.item.id);
            return false;
        },
        change: function(event, ui) {
            if (!ui.item) $idField.val("");
        }
    });

    // 2. Inicialización Flatpickr (Mini Calendario)
    let fp = flatpickr("#flatpickr-inline", {
        inline: true,
        locale: "es",
        defaultDate: new Date(),
        onChange: function(selectedDates, dateStr, instance) {
            actualizarHeaderFecha(selectedDates[0]);
            renderDailyTimeline(selectedDates[0]);
        }
    });

    // 3. Inicialización FullCalendar v6 (Oculto)
    const calendarEl = document.getElementById('calendar');
    const minTime = window.agendaConfig.horario_inicio || '08:00:00';
    const maxTime = window.agendaConfig.horario_fin || '20:00:00';
    const slotDur = '00:' + (window.agendaConfig.intervalo_minutos || "30") + ':00';
    const esMovil = window.innerWidth < 768;

    calendar = new FullCalendar.Calendar(calendarEl, {
        initialView: esMovil ? 'listWeek' : 'timeGridWeek',
        locale: 'es',
        headerToolbar: {
            left: 'prev,next today',
            center: 'title',
            right: 'dayGridMonth,timeGridWeek,timeGridDay'
        },
        slotMinTime: minTime,
        slotMaxTime: maxTime,
        slotDuration: slotDur,
        allDaySlot: false,
        editable: true,
        selectable: true,
        height: 'auto',
        events: function(info, successCallback, failureCallback) {
            fetch('/citas_crud.pl?accion=get_events&id_medico=' + window.idMedicoSesion)
            .then(res => res.json())
            .then(data => {
                window.allEvents = data; // Guardamos cache global
                successCallback(data);
                if(fp.selectedDates.length > 0) {
                    renderDailyTimeline(fp.selectedDates[0]);
                }
            })
            .catch(err => failureCallback(err));
        },
        eventDrop: function(info) { confirmarMovimiento(info); },
        eventResize: function(info) { confirmarMovimiento(info); },
        eventClick: function(info) { abrirModalEdicion(info.event); },
        select: function(info) { abrirModalCita(info.startStr, info.endStr); }
    });

    calendar.render();
    modalCita = new bootstrap.Modal(document.getElementById('modalCitaSPA'));
    
    // Al arrancar, mostrar fecha actual
    actualizarHeaderFecha(fp.selectedDates[0]);
});

// -- Funciones UI/UX de Vista Híbrida (Stitch) --

function toggleVista(vista) {
    let dia = document.getElementById('vista-diaria-container');
    let mes = document.getElementById('vista-mensual-container');
    let btnDia = document.getElementById('btnVistaDiaria');
    let btnMes = document.getElementById('btnVistaMensual');

    if (vista === 'diaria') {
        dia.style.display = 'grid'; // grid-cols-12
        mes.style.display = 'none';
        btnDia.className = "px-4 py-2 bg-white text-primary font-bold shadow-sm rounded-md text-sm transition-all focus:outline-none border-0";
        btnMes.className = "px-4 py-2 text-on-surface-variant font-medium hover:text-primary rounded-md text-sm transition-all focus:outline-none bg-transparent border-0";
    } else {
        dia.style.display = 'none';
        mes.style.display = 'block';
        btnMes.className = "px-4 py-2 bg-white text-primary font-bold shadow-sm rounded-md text-sm transition-all focus:outline-none border-0";
        btnDia.className = "px-4 py-2 text-on-surface-variant font-medium hover:text-primary rounded-md text-sm transition-all focus:outline-none bg-transparent border-0";
        calendar.updateSize();
    }
}

function actualizarHeaderFecha(dateObj) {
    if(!dateObj) return;
    const opciones = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    let str = dateObj.toLocaleDateString('es-ES', opciones);
    str = str.charAt(0).toUpperCase() + str.slice(1);
    document.getElementById('fecha-actual-header').innerText = str;
}

function renderDailyTimeline(dateObj) {
    if(!dateObj) return;
    const container = document.getElementById('timelineContainer');
    let html = '';
    
    // Aislar fecha en formato YYYY-MM-DD local
    let isoDate = dateObj.getFullYear() + "-" + String(dateObj.getMonth() + 1).padStart(2,'0') + "-" + String(dateObj.getDate()).padStart(2,'0');
    
    let citasHoy = window.allEvents.filter(e => e.start.startsWith(isoDate));
    citasHoy.sort((a,b) => a.start.localeCompare(b.start));

    // KPIs
    document.getElementById('kpi-total-dia').innerText = citasHoy.length;
    let completadas = citasHoy.filter(c => c.extendedProps && (c.extendedProps.estado === 'Realizada' || c.extendedProps.estado === 'Completada')).length;
    document.getElementById('kpi-completadas-dia').innerText = completadas;

    if (citasHoy.length === 0) {
        container.innerHTML = `<div class="text-center py-10 text-on-surface-variant font-medium"><span class="material-symbols-outlined text-4xl mb-2 opacity-50 block">event_available</span>Día libre. No hay citas programadas.</div>`;
        return;
    }

    const ahora = new Date();
    
    citasHoy.forEach((e) => {
        let horaIniStr = e.start.substring(11,16); // HH:MM
        let px = e.extendedProps || {};
        let status = px.estado || 'Programada';
        let isPast = new Date(e.start) < ahora && new Date(e.end || e.start) < ahora;
        let isNow = new Date(e.start) <= ahora && new Date(e.end || new Date(e.start).getTime() + 30*60000) >= ahora;

        let badgeHtml = '';
        let borderClass = 'border-primary/30';
        let cardBg = 'bg-surface-container-lowest';
        let textClass = 'text-on-surface';
        let badgeColor = 'bg-surface-container text-primary';
        let iconHtml = '<button class="p-3 bg-surface-container-low hover:bg-surface-container-high rounded-full transition-colors text-primary" onclick="window.editarDesdeTimeline(\`'+e.id+'\`)"><span class="material-symbols-outlined">edit</span></button>';

        if (status === 'Realizada' || status === 'Completada' || isPast) {
            borderClass = 'border-secondary/40';
            badgeHtml = `<span class="px-3 py-1 bg-secondary/10 text-secondary text-[10px] font-bold uppercase rounded-full tracking-wide">Completado</span>`;
            cardBg = 'bg-surface-container-low opacity-75';
        } else if (status === 'Urgente' || status === 'Cancelada') {
            borderClass = 'border-tertiary';
            cardBg = 'bg-error-container';
            badgeHtml = `<span class="px-3 py-1 bg-tertiary text-white text-[10px] font-bold uppercase rounded-full tracking-wide">${status}</span>`;
            textClass = 'text-tertiary';
        } else if (isNow) {
            borderClass = 'border-primary shadow-[0_0_12px_rgba(37,99,235,0.4)]';
            cardBg = 'bg-primary text-white shadow-xl shadow-primary/20';
            textClass = 'text-white';
            badgeHtml = `<span class="px-3 py-1 bg-white/20 text-white text-[10px] font-bold uppercase rounded-full tracking-wide">Ahora</span>`;
            iconHtml = '<button class="bg-white text-primary px-4 py-2 rounded-xl font-bold hover:scale-105 transition-transform text-sm" onclick="window.editarDesdeTimeline(\`'+e.id+'\`)">Atender</button>';
        } else {
            badgeHtml = `<span class="px-3 py-1 bg-primary/10 text-primary-container text-[10px] font-bold uppercase rounded-full tracking-wide">${status}</span>`;
        }

        html += `
        <div class="relative group">
            <div class="absolute -left-[41px] top-1 w-4 h-4 rounded-full border-4 ${borderClass} bg-white group-hover:scale-125 transition-transform z-10"></div>
            <div class="${cardBg} p-6 rounded-3xl flex flex-col md:flex-row gap-6 ${isNow ? 'relative overflow-hidden' : 'shadow-sm'} animation-fade-in">
                ${isNow ? '<div class="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full -mr-16 -mt-16 blur-3xl"></div>' : ''}
                <div class="flex-1 relative z-10">
                    <div class="flex items-center gap-3 mb-2">
                        <span class="text-xs font-bold ${isNow ? 'text-white/80' : 'text-primary-container'} uppercase tracking-widest">${horaIniStr}</span>
                        ${badgeHtml}
                    </div>
                    <h4 class="text-xl font-bold mb-1 ${textClass}">${e.title}</h4>
                    <p class="${isNow ? 'text-white/80' : 'text-on-surface-variant'} text-sm">${px.motivo || 'Consulta General'}</p>
                </div>
                <div class="flex items-center gap-4 relative z-10">
                    ${iconHtml}
                </div>
            </div>
        </div>
        `;
    });

    container.innerHTML = html;
}

window.editarDesdeTimeline = function(id) {
    let evt = calendar.getEventById(id);
    if(evt) abrirModalEdicion(evt);
};

// -- Fin Funciones UI/UX Hibrida --


// Lógica de Movimiento Interactivo (Drag & Drop AJAX)
function confirmarMovimiento(info) {
    Swal.fire({
        title: '¿Reagendar cita?',
        text: "La cita cambiará al nuevo horario arrastrado.",
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#0d6efd',
        confirmButtonText: 'Sí, aplicar',
        cancelButtonText: 'Cancelar'
    }).then((result) => {
        if (result.isConfirmed) {
            // Manejador ISO de Fechas Locales
            let startD = new Date(info.event.start);
            let endD = info.event.end ? new Date(info.event.end) : new Date(startD.getTime() + 30*60000);
            
            // Corrige Offsets de zona horaria aislando fecha local
            let fecha = startD.getFullYear() + "-" + String(startD.getMonth() + 1).padStart(2,'0') + "-" + String(startD.getDate()).padStart(2,'0');
            
            let hora_ini = String(startD.getHours()).padStart(2,'0') + ":" + String(startD.getMinutes()).padStart(2,'0');
            let hora_fin = String(endD.getHours()).padStart(2,'0') + ":" + String(endD.getMinutes()).padStart(2,'0');

            let props = info.event.extendedProps;
            let formData = new URLSearchParams();
            formData.append('accion', 'update');
            formData.append('id_cita', info.event.id);
            formData.append('id_paciente', props.id_paciente);
            formData.append('id_medico', window.idMedicoSesion);
            formData.append('fecha', fecha);
            formData.append('hora_ini', hora_ini);
            formData.append('hora_fin', hora_fin);
            formData.append('motivo', props.motivo);
            formData.append('notas', props.notas);
            formData.append('estado', props.estado);

            enviarAJAXSPA(formData, () => {
                const Toast = Swal.mixin({ toast: true, position: "top-end", showConfirmButton: false, timer: 3000 });
                Toast.fire({ icon: "success", title: "Horario actualizado" });
            }, (err) => { info.revert(); });

        } else { info.revert(); }
    });
}

// Ventanas Modales Ui
function abrirModalCita(startStr, endStr) {
    document.getElementById('formCitaSPA').reset();
    document.getElementById('cita_accion').value = 'create';
    document.getElementById('cita_id_cita').value = '';
    document.getElementById('modalCitaTitulo').innerText = 'Agendar Cita';
    document.getElementById('btnBorrarCita').classList.add('d-none');
    
    document.getElementById('cita_paciente_search').value = '';
    
    if(window.idPacientePre) {
        document.getElementById('cita_id_paciente').value = window.idPacientePre;
        let pMatch = window.pacientesList.find(x => x.id == window.idPacientePre);
        if(pMatch) document.getElementById('cita_paciente_search').value = pMatch.label;
    }

    if(startStr) {
        document.getElementById('cita_fecha').value = startStr.substring(0,10);
        document.getElementById('cita_hora_ini').value = startStr.substring(11,16);
    }
    if(endStr) document.getElementById('cita_hora_fin').value = endStr.substring(11,16);

    // -- Inyectar Configuracion de Agenda (Limitar inputs de tiempo) --
    let minH = window.agendaConfig.horario_inicio || '08:00';
    let maxH = window.agendaConfig.horario_fin || '20:00';
    let step = (parseInt(window.agendaConfig.intervalo_minutos) || 30) * 60;
    document.getElementById('cita_hora_ini').setAttribute('min', minH);
    document.getElementById('cita_hora_ini').setAttribute('max', maxH);
    document.getElementById('cita_hora_ini').setAttribute('step', step);
    document.getElementById('cita_hora_fin').setAttribute('min', minH);
    document.getElementById('cita_hora_fin').setAttribute('max', maxH);
    document.getElementById('cita_hora_fin').setAttribute('step', step);
    
    modalCita.show();
}

function abrirModalEdicion(event) {
    let p = event.extendedProps;
    document.getElementById('cita_accion').value = 'update';
    document.getElementById('cita_id_cita').value = event.id;
    document.getElementById('cita_id_paciente').value = p.id_paciente;
    
    let pMatch = window.pacientesList.find(x => x.id == p.id_paciente);
    document.getElementById('cita_paciente_search').value = pMatch ? pMatch.label : ('ID: ' + p.id_paciente);
    
    // Extracción Limpia ISO
    document.getElementById('cita_fecha').value = event.start.toISOString().split('T')[0];
    document.getElementById('cita_hora_ini').value = p.hora_ini;
    document.getElementById('cita_hora_fin').value = p.hora_fin;
    
    document.getElementById('cita_motivo').value = p.motivo;
    document.getElementById('cita_estado').value = p.estado;
    document.getElementById('cita_notas').value = p.notas;
    
    document.getElementById('modalCitaTitulo').innerText = 'Modificar Cita';
    document.getElementById('btnBorrarCita').classList.remove('d-none');
    
    // -- Inyectar Configuracion de Agenda (Limitar inputs de tiempo) --
    let minH = window.agendaConfig.horario_inicio || '08:00';
    let maxH = window.agendaConfig.horario_fin || '20:00';
    let step = (parseInt(window.agendaConfig.intervalo_minutos) || 30) * 60;
    document.getElementById('cita_hora_ini').setAttribute('min', minH);
    document.getElementById('cita_hora_ini').setAttribute('max', maxH);
    document.getElementById('cita_hora_ini').setAttribute('step', step);
    document.getElementById('cita_hora_fin').setAttribute('min', minH);
    document.getElementById('cita_hora_fin').setAttribute('max', maxH);
    document.getElementById('cita_hora_fin').setAttribute('step', step);
    
    modalCita.show();
}

// Controladores Botones
function guardarCitaSPA() {
    let form = document.getElementById('formCitaSPA');
    if(!form.checkValidity()) { form.reportValidity(); return; }
    
    let ini = document.getElementById('cita_hora_ini').value;
    let fin = document.getElementById('cita_hora_fin').value;
    if (ini >= fin) {
        Swal.fire('Revisa los horarios', 'La Hora de Inicio debe ser anterior a la Hora de Fin.', 'warning');
        return;
    }

    let btn = document.getElementById('btnGuardarCita');
    let originalText = btn.innerHTML;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
    btn.disabled = true;

    let formData = new URLSearchParams(new FormData(form));

    enviarAJAXSPA(formData, () => {
        modalCita.hide();
        calendar.refetchEvents();
        btn.innerHTML = originalText; btn.disabled = false;
        Swal.fire({ title: '¡Éxito!',  text: 'Cita registrada en calendario.', icon: 'success', confirmButtonColor: '#0d6efd' });
    }, (errorMsg) => {
        btn.innerHTML = originalText; btn.disabled = false;
        Swal.fire('Atención', errorMsg, 'warning');
    });
}

function eliminarCitaSPA() {
    Swal.fire({
        title: 'Cancelar Cita',
        text: "¿Estás seguro de eliminar este registro? Desaparecerá de tu agenda.",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#dc3545',
        confirmButtonText: 'Sí, eliminar',
        cancelButtonText: 'No'
    }).then((result) => {
        if (result.isConfirmed) {
            let id = document.getElementById('cita_id_cita').value;
            let formData = new URLSearchParams();
            formData.append('accion', 'delete');
            formData.append('id_cita', id);
            
            enviarAJAXSPA(formData, () => {
                modalCita.hide();
                calendar.refetchEvents();
                Swal.fire('Eliminada', 'La cita fue desestimada.', 'success');
            });
        }
    });
}

// Conector AJAX Global
function enviarAJAXSPA(formData, onSuccess, onError) {
    fetch('/citas_crud.pl', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: formData.toString()
    })
    .then(res => res.json())
    .then(data => {
        if (data.ok) { if(onSuccess) onSuccess(); } 
        else { if(onError) onError(data.msg); }
    })
    .catch(err => {
        console.error(err);
        if(onError) onError("Excepción interna al procesar CRUD.");
    });
}
