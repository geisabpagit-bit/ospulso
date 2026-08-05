/**
 * OSPULSO - Motor SPA Agenda (Vista Paciente)
 * Renderiza la Vista Semanal Smart adaptada con reglas de negocio del paciente.
 */

var agendaConfig = {};
var appointments = [];
var selectedDate = new Date();
var idMedicoActivo = null;
var idPacienteActivo = null;

// Normalizador ISO YYYY-MM-DD
function getISO(d) {
    return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
}

// Inicializador
function initPacienteSpa(idMedico, idPaciente) {
    idMedicoActivo = idMedico;
    idPacienteActivo = idPaciente;
    selectedDate = new Date(); // Resetear a hoy
    loadContext();
}

// Cargar contexto desde API
function loadContext() {
    if(!idMedicoActivo) return;
    
    document.getElementById('citas_loader').classList.remove('d-none');
    document.getElementById('view-semana-smart').classList.add('d-none');
    document.getElementById('smart-nav-container').classList.add('d-none');

    $.get('../api/citas_crud.pl', { accion: 'get_events', id_medico: idMedicoActivo }, function(res) {
        document.getElementById('citas_loader').classList.add('d-none');
        if (res.ok) {
            appointments = res.data;
            agendaConfig = res.config;
            renderWeeklySmartView();
            document.getElementById('view-semana-smart').classList.remove('d-none');
            document.getElementById('smart-nav-container').classList.remove('d-none');
        } else {
            Swal.fire('Error', res.msg || 'No se pudo cargar la disponibilidad.', 'error');
        }
    }, 'json').fail(function() {
        document.getElementById('citas_loader').classList.add('d-none');
        Swal.fire('Error', 'Problema de conexión con el servidor.', 'error');
    });
}

function moveDate(days) {
    const newDate = new Date(selectedDate);
    newDate.setDate(newDate.getDate() + days);
    if (getISO(newDate) < getISO(new Date())) {
        selectedDate = new Date();
    } else {
        selectedDate = newDate;
    }
    renderWeeklySmartView();
}

function isWorkDay(iso) {
    const d = new Date(iso + 'T12:00:00');
    const wday = d.getDay();
    const isoWday = wday === 0 ? 7 : wday;
    if (!agendaConfig.workDays) return true;
    return agendaConfig.workDays.includes(isoWday.toString()) || agendaConfig.workDays.includes(isoWday);
}

function isHoliday(iso) {
    if (!agendaConfig.festivos) return false;
    const list = agendaConfig.festivos.split(',').map(s => s.trim());
    return list.includes(iso);
}

function renderWeeklySmartView() {
    const scroll = $("#weekly-smart-scroll");
    const slotsCont = $("#weekly-smart-slots");
    scroll.empty(); slotsCont.empty();

    const base = new Date(selectedDate);
    const todayISO = getISO(new Date());
    
    // Título de mes
    const monthName = base.toLocaleDateString('es-ES', { month: 'long', year: 'numeric' });
    $("#current-month-label").text(monthName);
    
    const isMobile = window.innerWidth < 768;
    const numDays = isMobile ? 3 : 7;
    const offset = Math.floor(numDays / 2);
    
    let startDate = new Date(base);
    startDate.setDate(startDate.getDate() - offset);
    if (getISO(startDate) < todayISO) {
        startDate = new Date();
    }
    
    for (let i = 0; i < numDays; i++) {
        const d = new Date(startDate);
        d.setDate(d.getDate() + i);
        const iso = getISO(d);
        const active = iso === getISO(selectedDate);
        const holiday = isHoliday(iso) || !isWorkDay(iso);
        const isToday = iso === todayISO;
        const dayName = d.toLocaleDateString('es-ES', { weekday: 'short' }).replace('.', '');
        const dayNum = d.getDate();

        const disabledClass = holiday ? 'holiday' : '';

        const card = $(`
            <div class="smart-day-card kpi-acrilico ${active ? 'active' : ''} ${disabledClass}" onclick="if(!this.classList.contains('holiday')) { selectSmartDate('${iso}'); }">
                <div class="day-name">${dayName}</div>
                <div class="day-num">${dayNum}</div>
                ${isToday ? '<div style="font-size: 0.6rem; margin-top: 2px; font-weight: bold; color: var(--bs-primary);">HOY</div>' : ''}
            </div>
        `);
        
        scroll.append(card);
    }
    
    // Render slots for selected date
    renderSmartSlots(getISO(selectedDate));
}

function selectSmartDate(iso) {
    selectedDate = new Date(iso + 'T12:00:00');
    renderWeeklySmartView();
}

function renderSmartSlots(date) {
    const cont = $("#weekly-smart-slots");
    cont.empty();
    
    const todayISO = getISO(new Date());
    if (date < todayISO) {
        cont.append('<div class="col-12 text-center p-5 opacity-50"><i class="bi bi-clock-history h1 d-block mb-3"></i><h5 class="fw-bold">No se puede agendar en el pasado</h5></div>');
        return;
    }

    if (!isWorkDay(date) || isHoliday(date)) {
        cont.append('<div class="col-12 text-center p-5 opacity-50"><i class="bi bi-calendar-x h1 d-block mb-3"></i><h5 class="fw-bold">Día No Laborable</h5></div>');
        return;
    }

    const s = parseInt(agendaConfig.laborStart?.split(':')[0] || 9);
    const e = parseInt(agendaConfig.laborEnd?.split(':')[0] || 18);
    const interval = parseInt(agendaConfig.intervalo_minutos) || 30;
    
    // Filtrar citas del día para checar ocupación
    const dayApts = appointments.filter(a => a.start.startsWith(date));

    const sections = [
        { label: 'MAÑANA', start: s, end: 13, icon: 'bi-brightness-high-fill', color: '#38bdf8' },
        { label: 'TARDE', start: 13, end: e, icon: 'bi-moon-stars-fill', color: '#818cf8' }
    ];

    sections.forEach(sec => {
        const col = $(`
            <div class="col-md-6 mb-4">
                <h6 class="fw-black mb-3 d-flex align-items-center" style="letter-spacing: 1px; color: #475569;">
                    <i class="bi ${sec.icon} fs-5 me-2" style="color: ${sec.color};"></i> ${sec.label}
                </h6>
                <div class="row g-2" id="sec-${sec.label}"></div>
            </div>
        `);
        cont.append(col);
        
        const secCont = col.find(`#sec-${sec.label}`);
        let hasSlots = false;

        for (let h = sec.start; h < sec.end; h++) {
            for (let m = 0; m < 60; m += interval) {
                const hh = h.toString().padStart(2, '0');
                const mm = m.toString().padStart(2, '0');
                const timeStr = `${hh}:${mm}`;
                
                // Comida
                if (agendaConfig.lunchStart && agendaConfig.lunchEnd) {
                    if (timeStr >= agendaConfig.lunchStart && timeStr < agendaConfig.lunchEnd) continue;
                }
                
                // Excluir horas que ya pasaron el día de hoy
                if (date === todayISO) {
                    const now = new Date();
                    const slotTime = new Date(`${date}T${timeStr}:00`);
                    if (slotTime <= now) continue; // Ya pasó
                }

                hasSlots = true;

                // Checar Ocupación
                // Buscamos si existe alguna cita que se superponga con este intervalo
                // Para simplificar: checamos si este timeStr está dentro de una cita existente
                let isOccupied = false;
                for (let i = 0; i < dayApts.length; i++) {
                    const apt = dayApts[i];
                    const aptStart = apt.start.split('T')[1].substring(0,5);
                    const aptEnd = apt.end.split('T')[1].substring(0,5);
                    
                    if (timeStr >= aptStart && timeStr < aptEnd) {
                        isOccupied = true;
                        break;
                    }
                }

                const btn = $(`<button type="button" class="btn slot-btn ${isOccupied ? 'disabled' : ''}" ${isOccupied ? 'disabled' : ''}>${timeStr}</button>`);
                
                if (!isOccupied) {
                    btn.click(function() {
                        solicitarCita(date, timeStr, interval);
                    });
                }
                
                secCont.append($('<div class="col-4 col-md-4"></div>').append(btn));
            }
        }
        
        if (!hasSlots) {
            secCont.append('<div class="col-12"><div class="text-muted small">No hay horarios disponibles en este bloque.</div></div>');
        }
    });
}

function solicitarCita(date, timeStr, intervalMinutes) {
    Swal.fire({
        title: 'Agendar Cita',
        html: `
            <div class="text-start">
                <p>Está a punto de agendar una cita para el <strong>${date}</strong> a las <strong>${timeStr}</strong>.</p>
                <label class="form-label fw-bold">Por favor, indique brevemente el motivo de su visita:</label>
                <textarea id="swal-motivo" class="form-control form-control-lg shadow-sm" rows="3" placeholder="Ej. Revisión general, dolor de muela, limpieza..."></textarea>
            </div>
        `,
        icon: 'info',
        showCancelButton: true,
        confirmButtonColor: '#10b981',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Confirmar Cita',
        cancelButtonText: 'Cancelar',
        preConfirm: () => {
            const motivo = document.getElementById('swal-motivo').value;
            if (!motivo) {
                Swal.showValidationMessage('El motivo es obligatorio');
            }
            return motivo;
        }
    }).then((result) => {
        if (result.isConfirmed) {
            const motivo = result.value;
            
            // Calcular fin
            const [h, m] = timeStr.split(':').map(Number);
            let mFin = m + intervalMinutes;
            let hFin = h;
            if (mFin >= 60) {
                hFin += Math.floor(mFin / 60);
                mFin = mFin % 60;
            }
            const timeEndStr = String(hFin).padStart(2, '0') + ':' + String(mFin).padStart(2, '0');

            const formData = new FormData();
            formData.append('accion', 'create');
            formData.append('id_medico', idMedicoActivo);
            formData.append('id_paciente', idPacienteActivo);
            formData.append('fecha', date);
            formData.append('hora_ini', timeStr);
            formData.append('hora_fin', timeEndStr);
            formData.append('motivo', motivo);
            formData.append('tipo', 'Consulta General de Valoración');
            formData.append('estado', 'Programada');
            
            Swal.fire({ title: 'Agendando...', allowOutsideClick: false, didOpen: () => { Swal.showLoading(); } });

            fetch('../api/citas_crud.pl', {
                method: 'POST',
                body: formData
            })
            .then(res => res.json())
            .then(data => {
                if(data.success || data.ok) {
                    Swal.fire({
                        icon: 'success',
                        title: '¡Cita Agendada!',
                        text: 'Su cita ha sido programada con éxito.',
                        timer: 2000,
                        showConfirmButton: false
                    }).then(() => {
                        window.location.href = 'mis_citas.pl';
                    });
                } else {
                    Swal.fire('Error', data.message || data.msg || 'No se pudo agendar la cita.', 'error');
                }
            })
            .catch(err => {
                Swal.fire('Error', 'Error de comunicación con el servidor', 'error');
            });
        }
    });
}
