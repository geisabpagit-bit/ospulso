// js/pacientes_spa.js

document.addEventListener('DOMContentLoaded', () => {
    const canvasEl = document.getElementById('expedienteCanvas');
    const bCanvas = new bootstrap.Offcanvas(canvasEl);
    const contenido = document.getElementById('expedienteContenido');

    // Delegar eventos a los botones de la tabla, 
    // importante porque DataTables recrea los elementos del DOM constantemente.
    document.body.addEventListener('click', async (e) => {
        let btn = e.target.closest('.btn-expediente');
        if (!btn) return;

        e.preventDefault();
        const idPaciente = btn.getAttribute('data-id');
        
        // Mostrar Loading animado mientras se resuelven las API
        contenido.innerHTML = `
            <div class="d-flex flex-column justify-content-center align-items-center h-100 w-100 text-muted">
                <div class="spinner-border text-primary border-3 mb-3" role="status" style="width: 3rem; height: 3rem;"></div>
                <h6 class="fw-bold" style="font-family: 'Manrope', sans-serif;">Cargando Expediente...</h6>
            </div>`;
        
        bCanvas.show();

        try {
            const timestamp = new Date().getTime();
            const url = '../api/pacientes_api.pl?accion=get_perfil&id=' + encodeURIComponent(idPaciente) + '&_t=' + timestamp;
            let data;

            // Compatibilidad de API (Puntos 2 y 3)
            if (window.fetch) {
                const response = await fetch(url, { cache: 'no-store' });
                data = await response.json();
            } else if (window.jQuery) {
                // Fallback seguro usando jQuery AJAX para motores JS antiguos o limitados
                data = await new Promise((resolve, reject) => {
                    jQuery.getJSON(url, resolve).fail(reject);
                });
            } else {
                throw new Error("El navegador no soporta fetch ni jQuery.");
            }

            if (data && data.ok) {
                renderExpediente(data.perfil, data.historial);
            } else {
                contenido.innerHTML = `<div class="alert alert-danger m-4 shadow-sm border-0"><i class="bi bi-exclamation-octagon-fill me-2"></i> ${data ? data.msg : 'Error al obtener expediente.'}</div>`;
            }
        } catch(error) {
            contenido.innerHTML = `<div class="alert alert-danger m-4 shadow-sm border-0"><i class="bi bi-wifi-off me-2"></i> Error de conectividad con Backend o incompatibilidad del navegador.</div>`;
            console.error(error);
        }
    });

    // Formateador de moneda ultra-seguro y compatible (Evita crashes de toLocaleString en WebView/TV)
    function formatMonedaSeguro(valor) {
        try {
            var num = Number(valor);
            if (isNaN(num)) return '0.00';
            
            // En TV/Low-Mem o si no se soporta es-MX de forma nativa, usar fallback determinista por regex
            if (window.SDM_IS_LOW_MEM) {
                var partes = num.toFixed(2).split('.');
                partes[0] = partes[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
                return partes.join('.');
            }
            
            return num.toLocaleString('es-MX', {
                minimumFractionDigits: 2, 
                maximumFractionDigits: 2
            });
        } catch (err) {
            console.warn("Fallback toLocaleString:", err);
            try {
                return Number(valor).toFixed(2);
            } catch(e) {
                return '0.00';
            }
        }
    }

    // Función Renderer que inyecta la Maqueta Premium Diamond Edition
    function renderExpediente(perfil, historial) {
        try {
            // Validar datos antes de renderizar para evitar crashes (Puntos 3 y 4)
            if (!perfil) {
                throw new Error("Datos de perfil inválidos o inexistentes");
            }

            const hoy = new Date();
            hoy.setHours(0,0,0,0);

            let historialHtml = '';
            if (!historial || historial.length === 0) {
                historialHtml = `
                    <div class="text-center text-muted p-5 w-100 bg-white shadow-sm" style="border-radius: var(--radius-md);">
                        <i class="bi bi-clipboard2-x d-block mb-3 text-cyan" style="font-size: 2.5rem;"></i>
                        <span class="font-secondary">No hay historial de citas clínicas.</span>
                    </div>`;
            } else {
                historial.forEach(cita => {
                    if (!cita) return;
                    let badgeClass = 'bg-primary';
                    let labelEstado = cita.estado || 'Pendiente';

                    var fechaReal = cita.fecha_real || '';
                    const fechaCita = new Date(fechaReal + 'T00:00:00');
                    if (fechaReal && fechaCita < hoy && cita.estado === 'Confirmada') {
                        badgeClass = 'bg-success';
                        labelEstado = 'Realizado';
                    } else if (cita.estado === 'Cancelada') {
                        badgeClass = 'bg-danger';
                    } else if (cita.estado === 'Confirmada') {
                        badgeClass = 'bg-primary';
                        labelEstado = 'Programada';
                    } else {
                        badgeClass = 'bg-warning text-dark';
                        labelEstado = 'Pendiente';
                    }
                    
                    let fh_corta = cita.fecha_corta ? cita.fecha_corta.replace('<br/>', ' ') : 'N/A';
                    let motivo = cita.motivo || 'Sin motivo';
                    let hora = cita.hora || 'N/A';

                    historialHtml += `
                        <div class="card-consulta">
                          <h6 title="${motivo}">${motivo}</h6>
                          <small>${fh_corta} • ${hora}</small>
                          <div class="mt-2"><span class="badge ${badgeClass} rounded-pill">${labelEstado}</span></div>
                        </div>
                    `;
                });
            }

            let perfilNombre = perfil.nombre || 'Paciente Sin Nombre';
            let nombreCoded = encodeURIComponent(perfilNombre);
            
            let cvCargos = formatMonedaSeguro(perfil.cargos);
            let cvAbonos = formatMonedaSeguro(perfil.abonos);
            let cvSaldo = formatMonedaSeguro(perfil.saldo);

            let perfilId = perfil.id || 'N/A';
            let perfilCorreo = perfil.correo || 'No registrado';
            let perfilTelefono = perfil.telefono || '';

            contenido.innerHTML = `
                <div class="d-flex flex-column" style="background-color: var(--bg-main) !important; padding: 1.25rem; font-size: 0.85rem;">

                    <!-- Datos del Paciente -->
                    <div class="paciente-info-bento mb-3">
                      <img src="https://ui-avatars.com/api/?name=${nombreCoded}&background=0d1e3d&color=fff&size=45&bold=true" alt="Paciente" width="45" height="45" class="shadow-sm">
                      <div class="overflow-hidden">
                        <h6 class="text-truncate mb-0" title="${perfilNombre}" style="font-size: 0.9rem;">${perfilNombre}</h6>
                        <small style="font-size: 0.75rem;">ID: ${perfilId} • Activo</small>
                      </div>
                    </div>

                    <!-- KPI Cards -->
                    <div class="row g-2 mb-3 flex-nowrap">
                      <div class="col-4">
                        <div class="kpi-card-bento cargos px-2 py-3">
                            <h6 style="font-size: 0.65rem;">CARGOS</h6>
                            <h5 style="font-size: 0.95rem;">$${cvCargos}</h5>
                        </div>
                      </div>
                      <div class="col-4">
                        <div class="kpi-card-bento abonos px-2 py-3">
                            <h6 style="font-size: 0.65rem;">ABONOS</h6>
                            <h5 style="font-size: 0.95rem;">$${cvAbonos}</h5>
                        </div>
                      </div>
                      <div class="col-4">
                        <div class="kpi-card-bento saldo px-2 py-3">
                            <h6 style="font-size: 0.65rem;">SALDO</h6>
                            <h5 style="font-size: 0.95rem;">$${cvSaldo}</h5>
                        </div>
                      </div>
                    </div>

                    <!-- Barra de Herramientas -->
                    <div class="toolbar-operativa mb-3" style="gap: 0.35rem; padding: 0.75rem;">
                      <a href="render_expediente_clinico.pl?id=${perfilId}" class="btn-outline-primary-medentia btn-toolbar-medentia" style="font-size: 0.75rem; padding: 0.35rem;"><i class="bi bi-folder2-open"></i> Expediente</a>
                      <a href="estado_cuenta.pl?id=${perfilId}" class="btn-outline-primary-medentia btn-toolbar-medentia" style="font-size: 0.75rem; padding: 0.35rem;"><i class="bi bi-cash-stack"></i> Finanzas</a>
                      <a href="agenda_main.pl?new_cita_id=${perfilId}&new_cita_nombre=${nombreCoded}" class="btn-primary-medentia btn-toolbar-medentia" style="font-size: 0.75rem; padding: 0.35rem;"><i class="bi bi-calendar-plus"></i> Nueva Cita</a>
                      <button type="button" class="btn-outline-primary-medentia btn-toolbar-medentia" data-bs-toggle="modal" data-bs-target="#modalCorreoSpaContainer" onclick="abrirModalCorreoSpa('${perfilCorreo}', '${perfilNombre.replace(/'/g, "\\'")}', '${perfilId}')" style="font-size: 0.75rem; padding: 0.35rem;"><i class="bi bi-envelope"></i> Correo</button>
                      <a href="tel:${perfilTelefono}" class="btn-outline-primary-medentia btn-toolbar-medentia" style="font-size: 0.75rem; padding: 0.35rem;"><i class="bi bi-telephone"></i> Llamar</a>
                      <a href="https://wa.me/${perfilTelefono}" target="_blank" class="btn-outline-primary-medentia btn-toolbar-medentia" style="font-size: 0.75rem; padding: 0.35rem;"><i class="bi bi-whatsapp"></i> WhatsApp</a>
                      <a href="imprime_ficha_identificacion.pl?id=${perfilId}" class="btn-outline-primary-medentia btn-toolbar-medentia" style="font-size: 0.75rem; padding: 0.35rem;"><i class="bi bi-printer"></i> Imprimir</a>
                    </div>

                    <!-- Historial de Consultas -->
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <h6 class="fw-bold mb-0" style="color: var(--md-blue-deep); font-family: var(--font-primary);">Historial de Consultas</h6>
                        <div class="d-flex gap-2">
                            <button class="btn btn-sm btn-light border rounded-circle shadow-sm" onclick="document.getElementById('carruselHistorial').scrollBy({left:-250, behavior:'smooth'})" title="Deslizar Izquierda" style="width: 32px; height: 32px; padding: 0; display: flex; align-items: center; justify-content: center;"><i class="bi bi-chevron-left"></i></button>
                            <button class="btn btn-sm btn-light border rounded-circle shadow-sm" onclick="document.getElementById('carruselHistorial').scrollBy({left:250, behavior:'smooth'})" title="Deslizar Derecha" style="width: 32px; height: 32px; padding: 0; display: flex; align-items: center; justify-content: center;"><i class="bi bi-chevron-right"></i></button>
                        </div>
                    </div>
                    <div class="historial-consultas-h" id="carruselHistorial">
                        ${historialHtml}
                    </div>
                </div>
            `;
        } catch (renderError) {
            console.error("[SDM UI Error Boundary] Error en renderExpediente:", renderError);
            contenido.innerHTML = `
                <div class="alert alert-warning m-4 shadow-sm border-0">
                    <h6 class="fw-bold mb-2"><i class="bi bi-exclamation-triangle-fill me-2"></i>Error de Visualización</h6>
                    <p class="mb-0 small">Ocurrió un error al procesar el expediente en este navegador. Detalle: ${renderError.message}</p>
                </div>`;
        }
    }
});

// --- Modal Dinámico de Envío de Email CRM ---
function abrirModalCorreoSpa(correoBase, nombreBase, idPaciente) {
    if(!document.getElementById('modalCorreoSpaContainer')) {
        const modalHtml = `
            <div class="modal fade" id="modalCorreoSpaContainer" tabindex="-1" aria-labelledby="modalCorreoSpaLabel" aria-hidden="true" style="z-index: 1060;">
                <div class="modal-dialog modal-dialog-centered modal-lg">
                    <div class="modal-content border-0 shadow-lg rounded-4">
                        <div class="modal-header fw-bold text-white" style="background-color: #174975; border-top-left-radius: 1rem; border-top-right-radius: 1rem;">
                            <h5 class="modal-title" id="modalCorreoSpaLabel"><i class="bi bi-envelope-paper-fill me-2"></i> Redactar Correo a Paciente</h5>
                            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                        </div>
                        <div class="modal-body p-4 bg-light">
                            <form id="formCorreoCrm" enctype="multipart/form-data">
                                <div class="row g-3 mb-3">
                                    <div class="col-md-6">
                                        <label class="form-label text-muted fw-bold small text-uppercase">Destinatario (Para)</label>
                                        <input type="email" class="form-control bg-white shadow-sm border-0" id="crmInputTo" name="para" required readonly>
                                        <input type="hidden" id="crmInputIdPaciente" name="id_paciente">
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label text-muted fw-bold small text-uppercase">Asunto</label>
                                        <input type="text" class="form-control shadow-sm border-0" name="asunto" id="crmInputSubject" required>
                                    </div>
                                </div>
                                <div class="mb-3">
                                    <label class="form-label text-muted fw-bold small text-uppercase">Cuerpo del Mensaje (Soporta HTML)</label>
                                    <textarea class="form-control shadow-sm border-0" name="cuerpo" rows="4" required></textarea>
                                </div>
                                <div class="mb-1">
                                    <label class="form-label text-muted fw-bold small text-uppercase"><i class="bi bi-paperclip"></i> Adjuntar Archivos (PDF, XLS, DOC... max 5MB)</label>
                                    <input type="file" class="form-control shadow-sm border-0" name="adjuntos" multiple accept=".pdf,.doc,.docx,.xls,.xlsx,.jpg,.jpeg,.png">
                                </div>
                            </form>
                        </div>
                        <div class="modal-footer bg-light border-0">
                            <button type="button" class="btn btn-secondary rounded-pill fw-bold border-0 shadow-sm" data-bs-dismiss="modal">Cancelar</button>
                            <button type="button" class="btn btn-primary rounded-pill fw-bold shadow-sm px-4" id="btnEnviarCorreoCrm" style="background-color: #174975;">
                                <i class="bi bi-send-fill me-2"></i> Enviar Correo
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `;
        document.body.insertAdjacentHTML('beforeend', modalHtml);

        document.getElementById('btnEnviarCorreoCrm').addEventListener('click', async function() {
            const formObj = document.getElementById('formCorreoCrm');
            if(!formObj.checkValidity()) {
                formObj.reportValidity(); return;
            }
            const btnSubmit = this;
            const originalText = btnSubmit.innerHTML;
            btnSubmit.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span> Transmitiendo...';
            btnSubmit.disabled = true;

            Swal.fire({
                title: 'Transmitiendo...',
                html: 'Aguarde un momento por favor. Empaquetando y enviando correo al paciente.',
                allowOutsideClick: false,
                didOpen: () => {
                    Swal.showLoading()
                }
            });

            try {
                const formData = new FormData(formObj);
                const response = await fetch('../api/enviar_correo_paciente_api.pl', {
                    method: 'POST',
                    body: formData
                });
                const data = await response.json();
                if(data.ok) {
                    Swal.fire({
                        icon: 'success',
                        title: '¡Enviado Exitosamente!',
                        text: data.msg,
                        confirmButtonColor: '#174975'
                    });
                    console.log("[DEBUG CRM EMAIL] Éxito:", data);
                    const bsModal = bootstrap.Modal.getInstance(document.getElementById('modalCorreoSpaContainer'));
                    if(bsModal) bsModal.hide();
                    formObj.reset();
                } else {
                    Swal.fire({
                        icon: 'warning',
                        title: 'Atención: Interrupción',
                        html: `<p class="mb-2 fw-bold text-dark">${data.msg || 'El servidor declinó el envío o no hubo respuesta del túnel.'}</p>
                               <div class="text-start mt-3 small bg-light p-3 rounded border text-secondary shadow-sm">
                                <strong>Alternativas de Solución:</strong>
                                <ul class="mb-0 mt-2 ps-3 lh-lg">
                                <li>Verifica que la dirección de correo sea válida y que no contenga espacios invisibles.</li>
                                <li>Asegúrate de que los archivos adjuntos (en conjunto) no rebasen los 5MB de capacidad.</li>
                                <li>Si el correo sigue siendo rechazado por un problema de módulos (como MIME::Lite), <strong>comunícate a Soporte Técnico</strong>.</li>
                                </ul>
                               </div>`,
                        confirmButtonColor: '#174975'
                    });
                    console.error("[DEBUG CRM EMAIL] Rechazo Servidor:", data);
                }
            } catch (err) {
                console.error("[DEBUG CRM EMAIL] Fallo de Red Crítico:", err);
                Swal.fire({
                    icon: 'error',
                    title: 'Fallo Crítico de Red',
                    html: `<p class="mb-2 fw-bold text-dark">La petición falló abruptamente. Tipo de error: Failed to fetch</p>
                           <div class="text-start mt-3 small bg-danger bg-opacity-10 p-3 rounded border border-danger text-danger shadow-sm">
                            <strong>Diagnóstico y Pasos a Seguir:</strong>
                            <ul class="mb-0 mt-2 ps-3 lh-lg">
                            <li><strong>Conexión:</strong> Es posible que hayas perdido conectividad a tu red Wifi/Ethernet.</li>
                            <li><strong>Bloqueo de Seguridad:</strong> El peso del archivo o su contenido causó un bloqueo inmediato en el firewall local, interrumpiendo la petición.</li>
                            <li>Si el internet funciona bien y el error es constante (posible Error de Servidor 500 no capturado), <strong>por favor llama a Soporte Técnico SDM</strong> indicando que el endpoint de email está caído.</li>
                            </ul>
                           </div>`,
                    confirmButtonColor: '#174975'
                });
            } finally {
                btnSubmit.innerHTML = originalText;
                btnSubmit.disabled = false;
            }
        });
    }

    // Config Inicial del modal al abrirse
    document.getElementById('crmInputTo').value = correoBase || '';
    document.getElementById('crmInputIdPaciente').value = idPaciente || '';
    document.getElementById('crmInputSubject').value = 'Resultados e Información Clínica de ' + (nombreBase || 'Paciente');
    const bsModal = new bootstrap.Modal(document.getElementById('modalCorreoSpaContainer'));
    bsModal.show();
}
