/**
 * OSPULSO - MOTOR FRONTEND DEL WIZARD QUIRÚRGICO INTEGRAL (6 PASOS + 3NF + SEMAFORIZACIÓN)
 * Cumple NOM-004-SSA3-2012 y NOM-024-SSA3-2012
 */

let currentStep = 1;
let currentCirugiaId = '';
let currentDossier = null;
let catalog3NF = {
    categorias: [],
    unidades: [],
    insumos: []
};
let recetaMedicamentos = [];
let spaceCheckPassed = false;

const ACTORES_CONFIG = [
    { key: 'agenda_espacios',          label: '1. Agenda Espacios',          icon: 'bi-door-open-fill' },
    { key: 'agenda_paciente',          label: '2. Agenda Paciente',          icon: 'bi-calendar-check-fill' },
    { key: 'recepcion_consentimiento', label: '3. Recepción / Consent.',     icon: 'bi-file-earmark-medical-fill' },
    { key: 'caja',                     label: '4. Caja ($5,000 Depósito)',   icon: 'bi-cash-coin' },
    { key: 'enfermeria',               label: '5. Enfermería Pre-Op',        icon: 'bi-heart-pulse-fill' },
    { key: 'quirofano',                label: '6. Quirófano (Trans-Op)',     icon: 'bi-activity' },
    { key: 'recuperacion',             label: '7. Recuperación (UCPA)',      icon: 'bi-hospital-fill' },
    { key: 'alta_receta',              label: '8. Alta / Receta & Corte',    icon: 'bi-clipboard2-check-fill' }
];

document.addEventListener('DOMContentLoaded', async () => {
    const root = document.getElementById('qx-wizard-root');
    if (!root) return;

    const initCirugiaId = root.dataset.idCirugia || '';
    const initStep = parseInt(root.dataset.initStep || '1', 10);
    const fechaHoy = root.dataset.fechaHoy || new Date().toISOString().slice(0, 10);

    const inpFecha = document.getElementById('w_fecha');
    if (inpFecha && !inpFecha.value) {
        inpFecha.value = fechaHoy;
    }

    await cargarCatalogo3NF();
    renderWidget3NFContainers();
    renderRecetaTable();

    if (initCirugiaId) {
        currentCirugiaId = initCirugiaId;
        await cargarCirugiaExistente(initCirugiaId, initStep);
    } else {
        actualizarMonitoreoEnVivo(null);
        irAPaso(1, true);
        verificarDisponibilidadSalaEnVivo();
    }
});

async function cargarCatalogo3NF() {
    try {
        const res = await fetch('../api/quirofano_wizard_api.pl?action=get_catalog_3nf');
        const data = await res.json();
        if (data.ok) {
            catalog3NF.categorias = data.categorias || [];
            catalog3NF.unidades = data.unidades || [];
            catalog3NF.insumos = data.insumos || [];
            poblarModalNuevoInsumo3NF();
            actualizarSelectoresWidget3NF();
        }
    } catch (e) {
        console.error('Error cargando catálogo 3NF:', e);
    }
}

function poblarModalNuevoInsumo3NF() {
    const selCat = document.getElementById('mdl3nf_categoria');
    const selUni = document.getElementById('mdl3nf_unidad');
    if (selCat) {
        selCat.innerHTML = catalog3NF.categorias
            .map(c => `<option value="${c.id_categoria}">${c.nombre}</option>`)
            .join('');
    }
    if (selUni) {
        selUni.innerHTML = catalog3NF.unidades
            .map(u => `<option value="${u.id_unidad}">${u.clave} - ${u.descripcion}</option>`)
            .join('');
    }
}

async function cargarCirugiaExistente(idCirugia, targetStep) {
    try {
        const res = await fetch(`../api/quirofano_crud.pl?action=get_surgical_record&id_cirugia=${encodeURIComponent(idCirugia)}`);
        const data = await res.json();
        if (data.ok && data.dossier) {
            sincronizarUIConDossier(data.dossier);
            const stepToGo = targetStep > 1 ? targetStep : (data.dossier.paso_actual_wizard || 1);
            irAPaso(stepToGo, true);
        }
    } catch (e) {
        console.error('Error cargando dossier:', e);
    }
}

function seleccionarTipoCirugia(tipo) {
    const inp = document.getElementById('w_tipo_cirugia');
    if (inp) inp.value = tipo;

    const cardProg = document.getElementById('card-tipo-programada');
    const cardUrg = document.getElementById('card-tipo-urgencias');
    const bannerUrg = document.getElementById('banner-flujo-paralelo-urgencia');
    const btnSkipUrg = document.getElementById('btn-skip-step2-urgencia');

    if (tipo === 'URGENCIAS') {
        if (cardUrg) cardUrg.classList.add('selected-urgencias');
        if (cardProg) cardProg.classList.remove('selected-programada');
        if (bannerUrg) bannerUrg.classList.remove('d-none');
        if (btnSkipUrg) btnSkipUrg.classList.remove('d-none');
    } else {
        if (cardProg) cardProg.classList.add('selected-programada');
        if (cardUrg) cardUrg.classList.remove('selected-urgencias');
        if (bannerUrg) bannerUrg.classList.add('d-none');
        if (btnSkipUrg) btnSkipUrg.classList.add('d-none');
    }

    verificarDisponibilidadSalaEnVivo();
    if (!currentDossier) {
        actualizarMonitoreoEnVivo(null);
    }
}

async function verificarDisponibilidadSalaEnVivo() {
    const fecha = document.getElementById('w_fecha')?.value || '';
    const hi = document.getElementById('w_hora_ini')?.value || '08:00';
    const hf = document.getElementById('w_hora_fin')?.value || '10:00';
    const sala = document.getElementById('w_sala')?.value || '';
    const tipo = document.getElementById('w_tipo_cirugia')?.value || 'PROGRAMADA';
    const box = document.getElementById('box-disponibilidad-espacio');
    if (!box || !fecha || !sala) return;

    box.innerHTML = `<div class="text-muted small"><span class="spinner-border spinner-border-sm me-1"></span> Consultando Agenda de Espacios en Renta...</div>`;

    try {
        const idRen = currentDossier?.id_sala_renta || '';
        const url = `../api/quirofano_wizard_api.pl?action=check_space_availability&fecha=${encodeURIComponent(fecha)}&hora_ini=${encodeURIComponent(hi)}&hora_fin=${encodeURIComponent(hf)}&sala=${encodeURIComponent(sala)}&id_cirugia=${encodeURIComponent(currentCirugiaId)}&id_sala_renta=${encodeURIComponent(idRen)}`;
        const res = await fetch(url);
        const data = await res.json();

        if (data.ok && data.disponible) {
            spaceCheckPassed = true;
            box.innerHTML = `
                <div class="alert alert-success py-2 px-3 mb-0 d-flex align-items-center justify-content-between border-success">
                    <div>
                        <i class="bi bi-check-circle-fill me-1.5"></i>
                        <strong>Disponible en Agenda de Espacios:</strong> ${sala} libre el ${fecha} (${hi} - ${hf}).
                    </div>
                    <span class="badge bg-success">LIBRE</span>
                </div>`;
        } else {
            const c = (data.conflictos && data.conflictos[0]) ? data.conflictos[0] : { motivo: 'Reserva activa', hora_ini: hi, hora_fin: hf };
            if (tipo === 'URGENCIAS') {
                spaceCheckPassed = true;
                box.innerHTML = `
                    <div class="alert alert-warning py-2 px-3 mb-0 border-warning">
                        <div class="d-flex justify-content-between align-items-center">
                            <strong><i class="bi bi-lightning-charge-fill text-danger me-1"></i>PRIORIDAD DE URGENCIAS ACTIVADA:</strong>
                            <span class="badge bg-danger">SOBREESCRITURA PRIORITARIA</span>
                        </div>
                        <div class="small mt-1">
                            La sala presenta reserva (${c.hora_ini}-${c.hora_fin}: ${c.motivo}), pero al ser <strong>CIRUGÍA DE URGENCIAS</strong> se aplicará bloqueo prioritario inmediato y pase directo a <strong>PRE-OPERATORIO</strong>.
                        </div>
                    </div>`;
            } else {
                spaceCheckPassed = false;
                box.innerHTML = `
                    <div class="alert alert-danger py-2 px-3 mb-0 border-danger">
                        <div class="d-flex justify-content-between align-items-center">
                            <strong><i class="bi bi-exclamation-octagon-fill me-1"></i>SALA OCUPADA EN AGENDA DE ESPACIOS:</strong>
                            <span class="badge bg-danger">BLOQUEADO (REAGENDAR)</span>
                        </div>
                        <div class="small mt-1">
                            <strong>${sala}</strong> ya está reservada de <strong>${c.hora_ini} a ${c.hora_fin}</strong> (${c.motivo} - ${c.responsable || ''}). Para cirugía programada es obligatorio elegir otro horario o sala.
                        </div>
                    </div>`;
            }
        }
    } catch (e) {
        console.error('Error verificando disponibilidad:', e);
    }
}

function irAPaso(stepNum, force = false) {
    if (!force && stepNum > 1 && !currentCirugiaId) {
        Swal.fire({
            icon: 'warning',
            title: 'Paso 1 Requerido',
            text: 'Primero guarde la programación y reserva de sala en el Paso 1 para generar el folio quirúrgico.',
            confirmButtonColor: '#0A2A66'
        });
        return;
    }

    // Regla de bloqueo estricto para Cirugía Programada: no puede pasar a Paso 3+ sin completar Paso 2
    if (!force && stepNum >= 3 && currentDossier && currentDossier.tipo_cirugia === 'PROGRAMADA') {
        const trm = currentDossier.tramites_ingreso || {};
        if (!trm.contrato_firmado || !trm.consentimiento_informado_firmado || !trm.deposito_pagado) {
            Swal.fire({
                icon: 'error',
                title: 'Bloqueo de Cirugía Programada',
                html: 'Para avanzar a <b>Pre-Operatorio</b> en una Cirugía Programada, es obligatorio que <b>Recepción</b> registre Contrato + Consentimiento Informado y <b>Caja</b> confirme el Depósito de Ingreso ($5,000.00).',
                confirmButtonColor: '#0A2A66'
            });
            stepNum = 2;
        }
    }

    currentStep = stepNum;
    document.querySelectorAll('.qx-step-tab').forEach(btn => {
        const s = parseInt(btn.dataset.step, 10);
        btn.classList.toggle('active', s === currentStep);
        btn.classList.toggle('completed', currentCirugiaId && s < currentStep);
    });

    document.querySelectorAll('.qx-stage-panel').forEach(pnl => {
        const s = parseInt(pnl.dataset.panelStep, 10);
        pnl.classList.toggle('active', s === currentStep);
    });
}

function sincronizarUIConDossier(dossier) {
    currentDossier = dossier;
    currentCirugiaId = dossier.id_cirugia;

    const lblFolio = document.getElementById('lbl-folio-activo');
    if (lblFolio) {
        lblFolio.textContent = `${dossier.id_cirugia} (${dossier.nombre_paciente || ''})`;
        lblFolio.className = 'badge bg-primary text-white px-2.5 py-1.5 rounded-pill fw-bold';
    }

    // Paso 1
    seleccionarTipoCirugia(dossier.tipo_cirugia || 'PROGRAMADA');
    setVal('w_id_paciente', dossier.id_paciente);
    setVal('w_id_medico', dossier.id_medico);
    setVal('w_id_anestesiologo', dossier.id_anestesiologo);
    setVal('w_procedimiento', dossier.procedimiento);
    setVal('w_sala', dossier.sala);
    setVal('w_fecha', dossier.fecha);
    setVal('w_hora_ini', dossier.hora);
    setVal('w_hora_fin', dossier.hora_fin || '18:00');
    setVal('w_notas', dossier.notas || '');

    // Paso 2
    const trm = dossier.tramites_ingreso || {};
    setChk('w_contrato_firmado', !!trm.contrato_firmado);
    setChk('w_consentimiento_firmado', !!trm.consentimiento_informado_firmado);
    setVal('w_nombre_firmante', trm.nombre_firmante || dossier.nombre_paciente || '');
    setVal('w_parentesco_firmante', trm.parentesco_firmante || 'Titular / Paciente');
    setVal('w_fecha_firma', trm.fecha_firma_consentimiento || '');
    setVal('w_deposito_monto', (trm.deposito_monto !== undefined ? trm.deposito_monto : 5000).toFixed(2));
    setChk('w_deposito_pagado', !!trm.deposito_pagado);
    setVal('w_metodo_pago_deposito', trm.metodo_pago_deposito || 'Efectivo');

    const badgeRecibo = document.getElementById('lbl-folio-recibo-deposito');
    if (badgeRecibo) {
        if (trm.folio_recibo_caja) {
            badgeRecibo.innerHTML = `<span class="badge bg-success"><i class="bi bi-receipt me-1"></i>Recibo Emitido: ${trm.folio_recibo_caja}</span>`;
        } else {
            badgeRecibo.innerHTML = `<span class="badge bg-secondary">Sin recibo emitido</span>`;
        }
    }

    // Paso 3
    const sv = dossier.signos_vitales_preop || {};
    const chk = dossier.checklist_preop || {};
    setVal('w_expediente_fisico', dossier.expediente_fisico_folio || '');
    setVal('w_habitacion_asignada', dossier.habitacion_asignada || 'HAB-101');
    setVal('w_sv_ta', sv.ta || '120/80');
    setVal('w_sv_fc', sv.fc || '74');
    setVal('w_sv_temp', sv.temp || '36.6');
    setVal('w_sv_spo2', sv.spo2 || '98');
    setChk('w_chk_identidad', !!chk.identidad_verificada);
    setChk('w_chk_ayuno', !!chk.ayuno_confirmado);
    setChk('w_chk_labs', !!chk.labs_validados);
    setChk('w_chk_sitio', !!chk.sitio_marcado);
    setChk('w_chk_via', !!chk.via_permeable);
    setChk('w_chk_profilaxis', !!chk.profilaxis_antibiotica);
    setVal('w_obs_enfermeria', chk.observaciones_enfermeria || '');

    // Paso 4
    const trn = dossier.transoperatorio || {};
    const nq = dossier.nota_quirurgica || {};
    setVal('w_hora_ingreso_sala', trn.hora_ingreso_sala || dossier.hora || '');
    setVal('w_hora_anestesia', trn.hora_inicio_anestesia || '');
    setVal('w_hora_incision', trn.hora_incision || '');
    setVal('w_hora_cierre', trn.hora_cierre || '');
    setVal('w_hora_salida_sala', trn.hora_salida_sala || '');
    setChk('w_cnt_gasas', !!trn.conteo_gasas_completo);
    setChk('w_cnt_compresas', !!trn.conteo_compresas_completo);
    setChk('w_cnt_instrumental', !!trn.conteo_instrumental_completo);
    setVal('w_diag_preop', nq.diagnostico_preop || dossier.procedimiento || '');
    setVal('w_diag_postop', nq.diagnostico_postop || dossier.procedimiento || '');
    setVal('w_op_realizada', nq.operacion_realizada || dossier.procedimiento || '');
    setVal('w_sangrado_ml', nq.sangrado_aprox_ml || '50');
    setVal('w_desc_tecnica', nq.descripcion_tecnica || '');
    setVal('w_hallazgos', nq.hallazgos || '');

    // Paso 5
    const ucp = dossier.recuperacion_ucpa || {};
    setVal('w_cama_ucpa', ucp.cama_ucpa || 'UCPA-01');
    setVal('w_hab_traslado', ucp.habitacion_traslado || dossier.habitacion_asignada || 'HAB-101');
    setVal('w_ald_act', ucp.aldrete_actividad !== undefined ? ucp.aldrete_actividad : 2);
    setVal('w_ald_res', ucp.aldrete_respiracion !== undefined ? ucp.aldrete_respiracion : 2);
    setVal('w_ald_cir', ucp.aldrete_circulacion !== undefined ? ucp.aldrete_circulacion : 2);
    setVal('w_ald_con', ucp.aldrete_conciencia !== undefined ? ucp.aldrete_conciencia : 2);
    setVal('w_ald_sat', ucp.aldrete_saturacion !== undefined ? ucp.aldrete_saturacion : 2);
    setVal('w_val_postop', ucp.valoracion_postop || '');
    recalcularAldreteWizard();

    // Paso 6
    const rec = dossier.receta_alta || {};
    setVal('w_rec_cie10', rec.diagnostico_egreso_cie10 || nq.diagnostico_postop || dossier.procedimiento || '');
    setVal('w_rec_indicaciones', rec.indicaciones_generales || 'Reposo relativo, dieta blanda, curación diaria de herida quirúrgica.');
    recetaMedicamentos = Array.isArray(rec.medicamentos) && rec.medicamentos.length > 0
        ? [...rec.medicamentos]
        : [
            { farmaco: 'Ketorolaco 10 mg Tabletas', dosis: '1 tableta', via: 'Oral', frecuencia: 'Cada 8 horas', duracion: '5 días' },
            { farmaco: 'Cefalexina 500 mg Cápsulas', dosis: '1 cápsula', via: 'Oral', frecuencia: 'Cada 8 horas', duracion: '7 días' }
        ];
    renderRecetaTable();

    // Tablas de consumos 3NF y Corte de Caja
    renderTablasConsumos3NF();
    renderCorteDeCaja();
    actualizarMonitoreoEnVivo(dossier);
    verificarDisponibilidadSalaEnVivo();
}

function setVal(id, val) {
    const el = document.getElementById(id);
    if (el && val !== undefined && val !== null) el.value = val;
}

function setChk(id, boolVal) {
    const el = document.getElementById(id);
    if (el) el.checked = !!boolVal;
}

// =========================================================================
// MONITOREO EN VIVO DE LOS 8 SEMÁFOROS Y ESTADO KANBAN
// =========================================================================
function actualizarMonitoreoEnVivo(dossier) {
    const tipo = dossier ? dossier.tipo_cirugia : (document.getElementById('w_tipo_cirugia')?.value || 'PROGRAMADA');
    const estado = dossier ? dossier.estado : (tipo === 'URGENCIAS' ? 'Pre-Operatorio (Directo)' : 'Programada');

    const badgeKanban = document.getElementById('monitor-kanban-col');
    if (badgeKanban) {
        let bg = 'bg-secondary';
        if (estado.includes('Pre-Op')) bg = 'bg-warning text-dark';
        else if (estado.includes('Quirófano')) bg = 'bg-danger text-white';
        else if (estado.includes('Recuperación')) bg = 'bg-primary text-white';
        else if (estado.includes('Alta')) bg = 'bg-success text-white';
        badgeKanban.className = `qx-kanban-pill ${bg}`;
        badgeKanban.innerHTML = `<i class="bi bi-kanban"></i> ${estado}`;
    }

    const badgeTipo = document.getElementById('monitor-tipo-cirugia');
    if (badgeTipo) {
        badgeTipo.className = tipo === 'URGENCIAS'
            ? 'badge bg-danger text-white fw-bold'
            : 'badge bg-info text-dark fw-bold';
        badgeTipo.textContent = tipo;
    }

    const sem = (dossier && dossier.semaforos) ? dossier.semaforos : {
        agenda_espacios: 'AMBAR',
        agenda_paciente: 'GRIS',
        recepcion_consentimiento: tipo === 'URGENCIAS' ? 'ROJO' : 'GRIS',
        caja: tipo === 'URGENCIAS' ? 'ROJO' : 'GRIS',
        enfermeria: 'GRIS',
        quirofano: 'GRIS',
        recuperacion: 'GRIS',
        alta_receta: 'GRIS'
    };

    const listEl = document.getElementById('monitor-actors-list');
    if (listEl) {
        listEl.innerHTML = ACTORES_CONFIG.map(act => {
            const st = (sem[act.key] || 'GRIS').toUpperCase();
            let dotClass = 'dot-gris';
            let itemClass = '';
            let statusTxt = 'Pendiente';

            if (st === 'VERDE') {
                dotClass = 'dot-verde';
                itemClass = 'actor-green-done';
                statusTxt = 'Validado';
            } else if (st === 'AMBAR') {
                dotClass = 'dot-ambar';
                itemClass = 'actor-amber-wait';
                statusTxt = 'En proceso';
            } else if (st === 'ROJO') {
                dotClass = 'dot-rojo';
                itemClass = 'actor-red-alert';
                statusTxt = 'Alerta / Paralelo';
            }

            return `
                <div class="qx-actor-item ${itemClass}">
                    <div class="qx-actor-name">
                        <i class="bi ${act.icon} text-navy"></i>
                        <span>${act.label}</span>
                    </div>
                    <div class="d-flex align-items-center gap-1.5">
                        <span class="small text-muted" style="font-size:0.68rem; font-weight:700;">${statusTxt}</span>
                        <span class="qx-traffic-dot ${dotClass}" title="${statusTxt}"></span>
                    </div>
                </div>
            `;
        }).join('');
    }

    const totalInsumosEl = document.getElementById('monitor-total-insumos');
    const liq = dossier?.liquidacion_insumos || {};
    if (totalInsumosEl) {
        const sub3nf = Number(liq.subtotal_insumos_3nf || 0);
        totalInsumosEl.textContent = '$' + sub3nf.toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
}

// =========================================================================
// ACCIONES DE GUARDADO DE LOS 6 PASOS
// =========================================================================

async function guardarPaso1Programacion() {
    const tipo = document.getElementById('w_tipo_cirugia').value;
    const idPac = document.getElementById('w_id_paciente').value;
    const idMed = document.getElementById('w_id_medico').value;
    const idAne = document.getElementById('w_id_anestesiologo').value;
    const proc = document.getElementById('w_procedimiento').value.trim();
    const sala = document.getElementById('w_sala').value;
    const fecha = document.getElementById('w_fecha').value;
    const hi = document.getElementById('w_hora_ini').value;
    const hf = document.getElementById('w_hora_fin').value;
    const notas = document.getElementById('w_notas').value.trim();

    if (!idPac || !idMed || !proc || !fecha || !sala) {
        Swal.fire({ icon: 'warning', title: 'Campos incompletos', text: 'Seleccione Paciente, Cirujano, Procedimiento, Sala y Fecha.' });
        return;
    }

    const fd = new URLSearchParams();
    fd.append('action', 'step1_save_programming');
    fd.append('id_cirugia', currentCirugiaId);
    fd.append('tipo_cirugia', tipo);
    fd.append('id_paciente', idPac);
    fd.append('id_medico', idMed);
    fd.append('id_anestesiologo', idAne);
    fd.append('procedimiento', proc);
    fd.append('sala', sala);
    fd.append('fecha', fecha);
    fd.append('hora_ini', hi);
    fd.append('hora_fin', hf);
    fd.append('notas', notas);

    try {
        const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
        const data = await res.json();
        if (data.ok) {
            sincronizarUIConDossier(data.dossier);
            Swal.fire({
                icon: 'success',
                title: tipo === 'URGENCIAS' ? 'Urgencia Ingresada a Pre-Op' : 'Cirugía Programada y Sala Reservada',
                text: data.msg,
                timer: 2200,
                showConfirmButton: false
            });
            irAPaso(data.next_step || 2, true);
        } else {
            Swal.fire({ icon: 'error', title: 'No se pudo programar', text: data.msg });
        }
    } catch (e) {
        console.error(e);
    }
}

async function guardarPaso2RecepcionCaja(saltarParaleloUrgencia = false) {
    if (!currentCirugiaId) return;

    const fd = new URLSearchParams();
    fd.append('action', 'step2_save_reception_cash');
    fd.append('id_cirugia', currentCirugiaId);
    fd.append('contrato_firmado', document.getElementById('w_contrato_firmado').checked ? '1' : '0');
    fd.append('consentimiento_informado_firmado', document.getElementById('w_consentimiento_firmado').checked ? '1' : '0');
    fd.append('nombre_firmante', document.getElementById('w_nombre_firmante').value.trim());
    fd.append('parentesco_firmante', document.getElementById('w_parentesco_firmante').value);
    fd.append('fecha_firma_consentimiento', document.getElementById('w_fecha_firma').value);
    fd.append('deposito_monto', document.getElementById('w_deposito_monto').value || '5000');
    fd.append('deposito_pagado', document.getElementById('w_deposito_pagado').checked ? '1' : '0');
    fd.append('metodo_pago_deposito', document.getElementById('w_metodo_pago_deposito').value);
    fd.append('saltar_urgencia_paralelo', saltarParaleloUrgencia ? '1' : '0');

    try {
        const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
        const data = await res.json();
        if (data.dossier) sincronizarUIConDossier(data.dossier);

        if (data.ok) {
            Swal.fire({
                icon: 'success',
                title: saltarParaleloUrgencia ? 'Flujo en Paralelo Activo' : 'Recepción y Caja Validados',
                text: data.msg,
                timer: 2000,
                showConfirmButton: false
            });
            irAPaso(3, true);
        } else {
            Swal.fire({ icon: 'warning', title: 'Requisito Pendiente', text: data.msg });
        }
    } catch (e) {
        console.error(e);
    }
}

async function guardarPaso3PreOp(avanzarQuirofano = false) {
    if (!currentCirugiaId) return;

    const fd = new URLSearchParams();
    fd.append('action', 'step3_save_preop');
    fd.append('id_cirugia', currentCirugiaId);
    fd.append('expediente_fisico_folio', document.getElementById('w_expediente_fisico').value.trim());
    fd.append('habitacion_asignada', document.getElementById('w_habitacion_asignada').value.trim());
    fd.append('ta', document.getElementById('w_sv_ta').value.trim());
    fd.append('fc', document.getElementById('w_sv_fc').value.trim());
    fd.append('temp', document.getElementById('w_sv_temp').value.trim());
    fd.append('spo2', document.getElementById('w_sv_spo2').value.trim());
    fd.append('identidad_verificada', document.getElementById('w_chk_identidad').checked ? '1' : '0');
    fd.append('ayuno_confirmado', document.getElementById('w_chk_ayuno').checked ? '1' : '0');
    fd.append('labs_validados', document.getElementById('w_chk_labs').checked ? '1' : '0');
    fd.append('sitio_marcado', document.getElementById('w_chk_sitio').checked ? '1' : '0');
    fd.append('via_permeable', document.getElementById('w_chk_via').checked ? '1' : '0');
    fd.append('profilaxis_antibiotica', document.getElementById('w_chk_profilaxis').checked ? '1' : '0');
    fd.append('observaciones_enfermeria', document.getElementById('w_obs_enfermeria').value.trim());
    fd.append('avanzar_quirofano', avanzarQuirofano ? '1' : '0');

    try {
        const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
        const data = await res.json();
        if (data.ok) {
            sincronizarUIConDossier(data.dossier);
            Swal.fire({ icon: 'success', title: 'Pre-Operatorio Guardado', text: data.msg, timer: 1800, showConfirmButton: false });
            if (avanzarQuirofano) irAPaso(4, true);
        }
    } catch (e) {
        console.error(e);
    }
}

async function guardarPaso4TransOp(avanzarRecuperacion = false) {
    if (!currentCirugiaId) return;

    const fd = new URLSearchParams();
    fd.append('action', 'step4_save_transop');
    fd.append('id_cirugia', currentCirugiaId);
    fd.append('hora_ingreso_sala', document.getElementById('w_hora_ingreso_sala').value);
    fd.append('hora_inicio_anestesia', document.getElementById('w_hora_anestesia').value);
    fd.append('hora_incision', document.getElementById('w_hora_incision').value);
    fd.append('hora_cierre', document.getElementById('w_hora_cierre').value);
    fd.append('hora_salida_sala', document.getElementById('w_hora_salida_sala').value);
    fd.append('conteo_gasas_completo', document.getElementById('w_cnt_gasas').checked ? '1' : '0');
    fd.append('conteo_compresas_completo', document.getElementById('w_cnt_compresas').checked ? '1' : '0');
    fd.append('conteo_instrumental_completo', document.getElementById('w_cnt_instrumental').checked ? '1' : '0');
    fd.append('diagnostico_preop', document.getElementById('w_diag_preop').value.trim());
    fd.append('diagnostico_postop', document.getElementById('w_diag_postop').value.trim());
    fd.append('operacion_realizada', document.getElementById('w_op_realizada').value.trim());
    fd.append('sangrado_aprox_ml', document.getElementById('w_sangrado_ml').value.trim());
    fd.append('descripcion_tecnica', document.getElementById('w_desc_tecnica').value.trim());
    fd.append('hallazgos', document.getElementById('w_hallazgos').value.trim());
    fd.append('avanzar_recuperacion', avanzarRecuperacion ? '1' : '0');

    try {
        const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
        const data = await res.json();
        if (data.ok) {
            sincronizarUIConDossier(data.dossier);
            Swal.fire({ icon: 'success', title: 'Transoperatorio Guardado', text: data.msg, timer: 1800, showConfirmButton: false });
            if (avanzarRecuperacion) irAPaso(5, true);
        }
    } catch (e) {
        console.error(e);
    }
}

function recalcularAldreteWizard() {
    const a = parseInt(document.getElementById('w_ald_act')?.value || '2', 10);
    const r = parseInt(document.getElementById('w_ald_res')?.value || '2', 10);
    const c = parseInt(document.getElementById('w_ald_cir')?.value || '2', 10);
    const n = parseInt(document.getElementById('w_ald_con')?.value || '2', 10);
    const s = parseInt(document.getElementById('w_ald_sat')?.value || '2', 10);
    const tot = a + r + c + n + s;

    const badge = document.getElementById('w_aldrete_badge');
    if (badge) {
        badge.textContent = `${tot} / 10 pts (${tot >= 9 ? 'APTO PARA ALTA' : 'EN OBSERVACIÓN'})`;
        badge.className = tot >= 9 ? 'badge bg-success px-3 py-1.5 fs-6' : 'badge bg-warning text-dark px-3 py-1.5 fs-6';
    }
    return tot;
}

async function guardarPaso5Recuperacion(avanzarAlta = false) {
    if (!currentCirugiaId) return;

    const fd = new URLSearchParams();
    fd.append('action', 'step5_save_recovery');
    fd.append('id_cirugia', currentCirugiaId);
    fd.append('cama_ucpa', document.getElementById('w_cama_ucpa').value.trim());
    fd.append('habitacion_traslado', document.getElementById('w_hab_traslado').value.trim());
    fd.append('aldrete_actividad', document.getElementById('w_ald_act').value);
    fd.append('aldrete_respiracion', document.getElementById('w_ald_res').value);
    fd.append('aldrete_circulacion', document.getElementById('w_ald_cir').value);
    fd.append('aldrete_conciencia', document.getElementById('w_ald_con').value);
    fd.append('aldrete_saturacion', document.getElementById('w_ald_sat').value);
    fd.append('valoracion_postop', document.getElementById('w_val_postop').value.trim());
    fd.append('avanzar_alta', avanzarAlta ? '1' : '0');

    try {
        const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
        const data = await res.json();
        if (data.ok) {
            sincronizarUIConDossier(data.dossier);
            Swal.fire({ icon: 'success', title: 'Recuperación Guardada', text: data.msg, timer: 1800, showConfirmButton: false });
            if (avanzarAlta) irAPaso(6, true);
        }
    } catch (e) {
        console.error(e);
    }
}

async function guardarPaso6AltaYCorte(emitirPaseSalida = false) {
    if (!currentCirugiaId) return;

    const fd = new URLSearchParams();
    fd.append('action', 'step6_save_discharge_and_cut');
    fd.append('id_cirugia', currentCirugiaId);
    fd.append('diagnostico_egreso_cie10', document.getElementById('w_rec_cie10').value.trim());
    fd.append('indicaciones_generales', document.getElementById('w_rec_indicaciones').value.trim());
    fd.append('medicamentos_json', JSON.stringify(recetaMedicamentos));
    fd.append('horas_sala', document.getElementById('w_corte_horas_sala').value || '2');
    fd.append('costo_hora_sala', document.getElementById('w_corte_costo_hora').value || '2500');
    fd.append('liquidar_saldo_caja', document.getElementById('w_liquidar_saldo_chk')?.checked ? '1' : '0');
    fd.append('metodo_pago_finiquito', document.getElementById('w_metodo_finiquito')?.value || 'Efectivo');
    fd.append('emitir_pase_salida', emitirPaseSalida ? '1' : '0');

    try {
        const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
        const data = await res.json();
        if (data.ok) {
            sincronizarUIConDossier(data.dossier);
            Swal.fire({
                icon: 'success',
                title: emitirPaseSalida ? 'Pase de Salida y Alta Emitidos' : 'Corte y Receta Guardados',
                text: data.msg,
                confirmButtonColor: '#0A2A66'
            });
        }
    } catch (e) {
        console.error(e);
    }
}

// =========================================================================
// WIDGET REUTILIZABLE DE INSUMOS 3NF (PRE_OP, QUIROFANO, RECUPERACION)
// =========================================================================
function renderWidget3NFContainers() {
    const etapas = [
        { code: 'PRE_OP',       title: 'Insumos y Medicamentos Pre-Operatorios (3NF)', badge: 'bg-warning text-dark' },
        { code: 'QUIROFANO',    title: 'Insumos, Instrumental y Fármacos Transoperatorios (3NF)', badge: 'bg-danger text-white' },
        { code: 'RECUPERACION', title: 'Insumos y Monitoreo en Recuperación UCPA (3NF)', badge: 'bg-primary text-white' }
    ];

    etapas.forEach(et => {
        const container = document.getElementById(`widget-3nf-${et.code}`);
        if (!container) return;

        container.innerHTML = `
            <div class="qx-3nf-widget mt-3">
                <div class="qx-3nf-header flex-wrap gap-2">
                    <div class="d-flex align-items-center gap-2">
                        <span class="badge ${et.badge} px-2.5 py-1">${et.code}</span>
                        <h6 class="fw-bold text-navy mb-0" style="font-size:0.86rem;">
                            <i class="bi bi-box-seam-fill text-teal me-1"></i>${et.title}
                        </h6>
                    </div>
                    <button type="button" class="btn btn-sm btn-outline-primary py-0.5 px-2 fw-semibold" onclick="abrirModalNuevoInsumo3NF()" style="font-size:0.75rem;">
                        <i class="bi bi-plus-circle me-1"></i>Nuevo Insumo al Catálogo 3NF
                    </button>
                </div>

                <div class="row g-2 align-items-end mb-2.5">
                    <div class="col-12 col-md-4">
                        <label class="form-label small fw-bold text-muted mb-1">1. Categoría (3NF)</label>
                        <select class="form-select form-select-sm sel-cat-3nf" id="cat-3nf-${et.code}" onchange="filtrarInsumosPorCategoria('${et.code}')">
                            <option value="">Todas las Categorías</option>
                        </select>
                    </div>
                    <div class="col-12 col-md-5">
                        <label class="form-label small fw-bold text-muted mb-1">2. Insumo / Medicamento / Uso de Sala</label>
                        <select class="form-select form-select-sm sel-ins-3nf" id="ins-3nf-${et.code}" onchange="actualizarPreviewPrecio3NF('${et.code}')">
                        </select>
                    </div>
                    <div class="col-6 col-md-1">
                        <label class="form-label small fw-bold text-muted mb-1">Cant.</label>
                        <input type="number" min="1" value="1" class="form-control form-control-sm text-center fw-bold" id="qty-3nf-${et.code}" oninput="actualizarPreviewPrecio3NF('${et.code}')">
                    </div>
                    <div class="col-6 col-md-2">
                        <button type="button" class="btn btn-sm btn-primary w-100 fw-bold" onclick="agregarConsumo3NF('${et.code}')">
                            <i class="bi bi-cart-plus-fill me-1"></i>Cargar
                        </button>
                    </div>
                </div>

                <div class="d-flex justify-content-between align-items-center bg-white px-2.5 py-1.5 rounded border mb-2 small">
                    <span id="preview-info-3nf-${et.code}" class="text-muted">Seleccione un insumo para ver SKU, stock y precio snapshot.</span>
                    <span id="preview-sub-3nf-${et.code}" class="fw-bold text-navy">$0.00</span>
                </div>

                <div class="table-responsive bg-white rounded border">
                    <table class="table table-sm table-hover align-middle mb-0" style="font-size:0.78rem;">
                        <thead class="table-light">
                            <tr>
                                <th>SKU</th>
                                <th>Insumo / Categoría</th>
                                <th class="text-center">Cant.</th>
                                <th class="text-end">P. Unit (Snapshot)</th>
                                <th class="text-end">Subtotal</th>
                                <th class="text-center">Acción</th>
                            </tr>
                        </thead>
                        <tbody id="tbody-3nf-${et.code}">
                            <tr><td colspan="6" class="text-center text-muted py-2">Sin insumos cargados en esta etapa.</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        `;
    });

    actualizarSelectoresWidget3NF();
}

function actualizarSelectoresWidget3NF() {
    ['PRE_OP', 'QUIROFANO', 'RECUPERACION'].forEach(et => {
        const selCat = document.getElementById(`cat-3nf-${et}`);
        if (selCat) {
            const valActual = selCat.value;
            selCat.innerHTML = `<option value="">-- Todas las Categorías (${catalog3NF.categorias.length}) --</option>` +
                catalog3NF.categorias.map(c => `<option value="${c.id_categoria}">${c.nombre}</option>`).join('');
            selCat.value = valActual;
        }
        filtrarInsumosPorCategoria(et);
    });
}

function filtrarInsumosPorCategoria(etapa) {
    const idCat = document.getElementById(`cat-3nf-${etapa}`)?.value || '';
    const selIns = document.getElementById(`ins-3nf-${etapa}`);
    if (!selIns) return;

    const filtrados = catalog3NF.insumos.filter(i => !idCat || i.id_categoria === idCat);
    selIns.innerHTML = filtrados.map(i =>
        `<option value="${i.id_insumo}">[${i.codigo_sku}] ${i.nombre} — $${Number(i.precio_unitario).toFixed(2)} / ${i.clave_unidad} (Stock: ${i.stock_actual})</option>`
    ).join('');

    actualizarPreviewPrecio3NF(etapa);
}

function actualizarPreviewPrecio3NF(etapa) {
    const idIns = document.getElementById(`ins-3nf-${etapa}`)?.value || '';
    const qty = parseFloat(document.getElementById(`qty-3nf-${etapa}`)?.value || '1') || 1;
    const infoEl = document.getElementById(`preview-info-3nf-${etapa}`);
    const subEl = document.getElementById(`preview-sub-3nf-${etapa}`);

    const ins = catalog3NF.insumos.find(i => i.id_insumo === idIns);
    if (!ins) {
        if (infoEl) infoEl.textContent = 'Sin insumo seleccionado';
        if (subEl) subEl.textContent = '$0.00';
        return;
    }

    const sub = qty * Number(ins.precio_unitario);
    if (infoEl) {
        infoEl.innerHTML = `<strong>${ins.nombre_categoria}</strong> | Unidad: <span class="badge bg-light text-dark border">${ins.clave_unidad}</span> | Stock: <strong>${ins.stock_actual}</strong>`;
    }
    if (subEl) {
        subEl.textContent = `Subtotal Snapshot: $${sub.toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    }
}

async function agregarConsumo3NF(etapa) {
    if (!currentCirugiaId) {
        Swal.fire({ icon: 'warning', title: 'Guarde el Paso 1', text: 'Primero registre la cirugía en el Paso 1.' });
        return;
    }
    const idIns = document.getElementById(`ins-3nf-${etapa}`)?.value || '';
    const qty = parseFloat(document.getElementById(`qty-3nf-${etapa}`)?.value || '1') || 1;

    const fd = new URLSearchParams();
    fd.append('action', 'add_3nf_consumption');
    fd.append('id_cirugia', currentCirugiaId);
    fd.append('id_insumo', idIns);
    fd.append('etapa_clinica', etapa);
    fd.append('cantidad', qty);

    try {
        const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
        const data = await res.json();
        if (data.ok) {
            await cargarCatalogo3NF();
            sincronizarUIConDossier(data.dossier);
        } else {
            Swal.fire({ icon: 'error', title: 'Error al cargar insumo', text: data.msg });
        }
    } catch (e) {
        console.error(e);
    }
}

async function eliminarConsumo3NF(idConsumo) {
    if (!currentCirugiaId || !idConsumo) return;

    const fd = new URLSearchParams();
    fd.append('action', 'remove_3nf_consumption');
    fd.append('id_cirugia', currentCirugiaId);
    fd.append('id_consumo', idConsumo);

    try {
        const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
        const data = await res.json();
        if (data.ok) {
            await cargarCatalogo3NF();
            sincronizarUIConDossier(data.dossier);
        }
    } catch (e) {
        console.error(e);
    }
}

function renderTablasConsumos3NF() {
    const consumos = currentDossier?.consumos_3nf || [];
    ['PRE_OP', 'QUIROFANO', 'RECUPERACION'].forEach(et => {
        const tbody = document.getElementById(`tbody-3nf-${et}`);
        if (!tbody) return;
        const lista = consumos.filter(c => c.etapa_clinica === et);
        if (lista.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted py-2">Sin insumos cargados en la etapa ${et}.</td></tr>`;
            return;
        }
        tbody.innerHTML = lista.map(c => `
            <tr>
                <td><span class="badge bg-light text-dark border">${c.codigo_sku || c.id_insumo}</span></td>
                <td>
                    <div class="fw-bold text-navy">${c.nombre}</div>
                    <div class="text-muted" style="font-size:0.7rem;">${c.categoria || ''}</div>
                </td>
                <td class="text-center fw-bold">${c.cantidad} ${c.unidad || ''}</td>
                <td class="text-end">$${Number(c.precio_unitario_snapshot).toFixed(2)}</td>
                <td class="text-end fw-bold text-primary">$${Number(c.subtotal).toFixed(2)}</td>
                <td class="text-center">
                    <button type="button" class="btn btn-sm btn-outline-danger py-0 px-1.5" onclick="eliminarConsumo3NF('${c.id_consumo}')" title="Quitar y restaurar stock">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
    });
}

// =========================================================================
// RECETA MÉDICA DE ALTA Y CORTE DE CAJA AUTOMÁTICO (PASO 6)
// =========================================================================
function agregarMedicamentoReceta() {
    const f = document.getElementById('rec_add_farmaco')?.value.trim() || '';
    const d = document.getElementById('rec_add_dosis')?.value.trim() || '';
    const v = document.getElementById('rec_add_via')?.value || 'Oral';
    const fr = document.getElementById('rec_add_frecuencia')?.value.trim() || '';
    const du = document.getElementById('rec_add_duracion')?.value.trim() || '';

    if (!f || !d || !fr || !du) {
        Swal.fire({ icon: 'warning', title: 'Datos del fármaco', text: 'Complete Fármaco, Dosis, Frecuencia y Duración.' });
        return;
    }

    recetaMedicamentos.push({ farmaco: f, dosis: d, via: v, frecuencia: fr, duracion: du });
    document.getElementById('rec_add_farmaco').value = '';
    document.getElementById('rec_add_dosis').value = '';
    document.getElementById('rec_add_frecuencia').value = '';
    document.getElementById('rec_add_duracion').value = '';
    renderRecetaTable();
}

function eliminarMedicamentoReceta(idx) {
    recetaMedicamentos.splice(idx, 1);
    renderRecetaTable();
}

function renderRecetaTable() {
    const tbody = document.getElementById('tbody-receta-meds');
    if (!tbody) return;
    if (recetaMedicamentos.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted py-2">Agregue medicamentos a la receta de alta.</td></tr>`;
        return;
    }
    tbody.innerHTML = recetaMedicamentos.map((m, i) => `
        <tr>
            <td class="fw-bold text-navy">${m.farmaco}</td>
            <td>${m.dosis}</td>
            <td><span class="badge bg-light text-dark border">${m.via}</span></td>
            <td>${m.frecuencia}</td>
            <td>${m.duracion}</td>
            <td class="text-center">
                <button type="button" class="btn btn-sm btn-outline-danger py-0 px-1.5" onclick="eliminarMedicamentoReceta(${i})">
                    <i class="bi bi-x-lg"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

function renderCorteDeCaja() {
    const consumos = currentDossier?.consumos_3nf || [];
    const liq = currentDossier?.liquidacion_insumos || {};
    const trm = currentDossier?.tramites_ingreso || {};

    const horasSala = parseFloat(document.getElementById('w_corte_horas_sala')?.value || liq.horas_sala || 2);
    const costoHora = parseFloat(document.getElementById('w_corte_costo_hora')?.value || liq.costo_hora_sala || 2500);

    setVal('w_corte_horas_sala', horasSala);
    setVal('w_corte_costo_hora', costoHora);

    let subPre = 0, subQx = 0, subUcpa = 0;
    consumos.forEach(c => {
        const s = Number(c.subtotal || 0);
        if (c.etapa_clinica === 'PRE_OP') subPre += s;
        else if (c.etapa_clinica === 'QUIROFANO') subQx += s;
        else subUcpa += s;
    });

    const subInsumos3NF = subPre + subQx + subUcpa;
    const subRentaSala = horasSala * costoHora;
    const totalCargos = subInsumos3NF + subRentaSala;
    const depositoPagado = trm.deposito_pagado ? Number(trm.deposito_monto || 5000) : 0;
    const saldoLiquidar = totalCargos - depositoPagado;

    setText('corte-sub-preop', fmtMoney(subPre));
    setText('corte-sub-qx', fmtMoney(subQx));
    setText('corte-sub-ucpa', fmtMoney(subUcpa));
    setText('corte-sub-insumos', fmtMoney(subInsumos3NF));
    setText('corte-sub-sala', fmtMoney(subRentaSala));
    setText('corte-total-bruto', fmtMoney(totalCargos));
    setText('corte-deposito-aplicado', '-' + fmtMoney(depositoPagado));
    setText('corte-saldo-final', fmtMoney(saldoLiquidar));

    const badgeP = document.getElementById('badge-pase-salida-status');
    if (badgeP) {
        const rec = currentDossier?.receta_alta || {};
        if (rec.pase_salida_emitido) {
            badgeP.innerHTML = `<span class="badge bg-success px-3 py-2 fs-6"><i class="bi bi-patch-check-fill me-1"></i>PASE DE SALIDA EMITIDO: ${rec.folio_pase_salida}</span>`;
        } else {
            badgeP.innerHTML = `<span class="badge bg-warning text-dark px-3 py-2">Pendiente de Emitir Pase de Salida</span>`;
        }
    }
}

function setText(id, txt) {
    const el = document.getElementById(id);
    if (el) el.textContent = txt;
}

function fmtMoney(n) {
    return '$' + Number(n || 0).toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

// =========================================================================
// MODALES DE APOYO: ALTA RÁPIDA DE PACIENTE Y NUEVO INSUMO 3NF
// =========================================================================
function abrirModalAltaRapidaPaciente() {
    const m = bootstrap.Modal.getOrCreateInstance(document.getElementById('modalQuickPatient'));
    m.show();
}

async function guardarPacienteRapido() {
    const nom = document.getElementById('qp_nombre').value.trim();
    const tel = document.getElementById('qp_telefono').value.trim();
    const sex = document.getElementById('qp_sexo').value;
    const nac = document.getElementById('qp_fecha_nac').value;
    const san = document.getElementById('qp_sangre').value;

    if (!nom) {
        Swal.fire({ icon: 'warning', title: 'Nombre obligatorio', text: 'Ingrese el nombre completo del paciente.' });
        return;
    }

    const fd = new URLSearchParams();
    fd.append('action', 'quick_create_patient');
    fd.append('nombre', nom);
    fd.append('telefono', tel);
    fd.append('sexo', sex);
    fd.append('fecha_nac', nac);
    fd.append('tipo_sangre', san);

    const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
    const data = await res.json();
    if (data.ok) {
        const sel = document.getElementById('w_id_paciente');
        const opt = document.createElement('option');
        opt.value = data.id_paciente;
        opt.textContent = `${data.nombre} (Exp #${data.id_paciente})`;
        opt.selected = true;
        sel.appendChild(opt);

        bootstrap.Modal.getInstance(document.getElementById('modalQuickPatient')).hide();
        Swal.fire({ icon: 'success', title: 'Paciente Creado', text: data.msg, timer: 1500, showConfirmButton: false });
    }
}

function abrirModalNuevoInsumo3NF() {
    const m = bootstrap.Modal.getOrCreateInstance(document.getElementById('modalNuevoInsumo3NF'));
    m.show();
}

async function guardarNuevoInsumoCatalogo3NF() {
    const nom = document.getElementById('mdl3nf_nombre').value.trim();
    const sku = document.getElementById('mdl3nf_sku').value.trim();
    const cat = document.getElementById('mdl3nf_categoria').value;
    const uni = document.getElementById('mdl3nf_unidad').value;
    const pre = document.getElementById('mdl3nf_precio').value;
    const stk = document.getElementById('mdl3nf_stock').value;

    if (!nom || !pre) {
        Swal.fire({ icon: 'warning', title: 'Datos incompletos', text: 'Capture nombre y precio unitario.' });
        return;
    }

    const fd = new URLSearchParams();
    fd.append('action', 'save_catalog_insumo');
    fd.append('nombre', nom);
    fd.append('codigo_sku', sku);
    fd.append('id_categoria', cat);
    fd.append('id_unidad', uni);
    fd.append('precio_unitario', pre);
    fd.append('stock_actual', stk);

    const res = await fetch('../api/quirofano_wizard_api.pl', { method: 'POST', body: fd });
    const data = await res.json();
    if (data.ok) {
        await cargarCatalogo3NF();
        bootstrap.Modal.getInstance(document.getElementById('modalNuevoInsumo3NF')).hide();
        Swal.fire({ icon: 'success', title: 'Insumo 3NF Agregado', text: data.msg, timer: 1500, showConfirmButton: false });
    }
}

function abrirVistaImprimibleAlta() {
    if (!currentCirugiaId) {
        Swal.fire({ icon: 'warning', title: 'Sin cirugía activa', text: 'Guarde primero el registro quirúrgico.' });
        return;
    }
    window.open(`imprimir_alta_quirurgica.pl?id_cirugia=${encodeURIComponent(currentCirugiaId)}`, '_blank');
}

