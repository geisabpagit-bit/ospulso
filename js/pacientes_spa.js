// js/pacientes_spa.js

function initPacientesSpa() {
    if (!document.getElementById('tablaPacientes')) return;

    var modalEl = document.getElementById('expedienteModal');
    var bModal = null;
    if (modalEl) {
        // Eliminar modales previos en el body para evitar duplicados en SPA
        var oldModals = document.querySelectorAll('body > #expedienteModal');
        oldModals.forEach(function(m) { if (m !== modalEl) m.remove(); });
        
        // [SDM FIX] Mover el modal físicamente a la raíz del <body> 
        document.body.appendChild(modalEl);
        bModal = new bootstrap.Modal(modalEl);
    }
    var contenido = document.getElementById('expedienteContenido');

    // Delegar eventos a los botones de la tabla
    if (!window._pacientesSpaEventAttached) {
        document.body.addEventListener('click', function(e) {
        var btn = e.target.closest('.btn-expediente');
        if (!btn) return;

        e.preventDefault();
        var idPaciente = btn.getAttribute('data-id');
        
        // Mostrar Loading animado mientras se resuelven las API
        if (contenido) {
            contenido.innerHTML = 
                '<div class="d-flex flex-column justify-content-center align-items-center h-100 w-100 text-muted">' +
                '<div class="spinner-border text-primary border-3 mb-3" role="status" style="width: 3rem; height: 3rem;"></div>' +
                '<h6 class="fw-bold" style="font-family: \'Manrope\', sans-serif;">Cargando Expediente...</h6>' +
                '</div>';
        }
        
        // Use the current DOM element to prevent referencing removed modals
        var currentModalEl = document.getElementById('expedienteModal');
        if (currentModalEl) {
            var currentBModal = bootstrap.Modal.getInstance(currentModalEl) || new bootstrap.Modal(currentModalEl);
            currentBModal.show();
        }

        var timestamp = new Date().getTime();
        var url = '../api/pacientes_api.pl?accion=get_perfil&id=' + encodeURIComponent(idPaciente) + '&_t=' + timestamp;

        // Compatibilidad de API (Puntos 2 y 3) sin async/await
        if (window.fetch) {
            fetch(url, { cache: 'no-store' })
                .then(function(response) { return response.json(); })
                .then(function(data) { procesarRespuesta(data); })
                .catch(function(error) { mostrarError(error); });
        } else if (window.jQuery) {
            // Fallback seguro usando jQuery AJAX para motores JS antiguos o limitados
            jQuery.getJSON(url)
                .done(function(data) { procesarRespuesta(data); })
                .fail(function(jqXHR, textStatus, error) { mostrarError(error); });
        } else {
            mostrarError("El navegador no soporta fetch ni jQuery.");
        }
        
        function procesarRespuesta(data) {
            if (data && data.ok) {
                renderExpediente(data.perfil, data.historial);
            } else {
                if (contenido) {
                    contenido.innerHTML = '<div class="alert alert-danger m-4 shadow-sm border-0"><i class="bi bi-exclamation-octagon-fill me-2"></i> ' + (data ? data.msg : 'Error al obtener expediente.') + '</div>';
                }
            }
        }
        
        function mostrarError(error) {
            if (contenido) {
                contenido.innerHTML = '<div class="alert alert-danger m-4 shadow-sm border-0"><i class="bi bi-wifi-off me-2"></i> Error de conectividad con Backend o incompatibilidad del navegador.</div>';
            }
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
            console.warn("=== [SDM DEBUG] INICIANDO RENDER EXPEDIENTE ===");
            console.log("1. Perfil recibido:", perfil);
            
            var modalEl = document.getElementById('expedienteModal');
            console.log("2. Elemento modal encontrado?", !!modalEl);
            if(modalEl) {
                var headerEl = modalEl.querySelector('.modal-header');
                console.log("3. modal-header encontrado?", !!headerEl, headerEl);
                if(headerEl) {
                    console.log("3a. Altura del header:", headerEl.offsetHeight, "Visibilidad:", window.getComputedStyle(headerEl).visibility, "Display:", window.getComputedStyle(headerEl).display, "Z-index:", window.getComputedStyle(headerEl).zIndex);
                    console.log("3b. HTML del header:", headerEl.innerHTML);
                } else {
                    console.error("CRÍTICO: No se encontró .modal-header dentro del modal!");
                    // Vamos a volcar el HTML completo del modal para ver qué diablos hay
                    console.log("HTML del modal completo:", modalEl.innerHTML);
                }
            }
            
            var contenido = document.getElementById('expedienteContenido');
            console.log("4. expedienteContenido encontrado?", !!contenido);

            if (!perfil) {
                if (contenido) contenido.innerHTML = '<div class="alert alert-danger">Error: No se pudo cargar el expediente.</div>';
                console.error("=== [SDM DEBUG] FALLO: PERFIL NULO ===");
                return;
            }

            var hoy = new Date();
            hoy.setHours(0,0,0,0);

            var historialHtml = '';
            if (!historial || historial.length === 0) {
                historialHtml = 
                    '<div class="card-medentia-aura border-0 text-center text-muted p-5 w-100">' +
                    '<i class="bi bi-clipboard2-x d-block mb-3 text-cyan" style="font-size: 2.5rem;"></i>' +
                    '<span class="font-secondary">No hay historial de citas clínicas.</span>' +
                    '</div>';
            } else {
                historial.forEach(function(cita) {
                    if (!cita) return;
                    var badgeClass = 'bg-primary';
                    var labelEstado = cita.estado || 'Pendiente';

                    var fechaReal = cita.fecha_real || '';
                    var fechaCita = new Date(fechaReal + 'T00:00:00');
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
                    
                    var fh_corta = cita.fecha_corta ? cita.fecha_corta.replace('<br/>', ' ') : 'N/A';
                    var motivo = cita.motivo || 'Sin motivo';
                    var hora = cita.hora || 'N/A';
                    var btnConsulta = '';
                    if (labelEstado === 'Pendiente' || labelEstado === 'Programada') {
                        btnConsulta = '<div class="mt-2"><a href="render_consultas.pl?id=' + (perfil.id||'') + '" class="btn btn-sm btn-outline-primary rounded-pill w-100" style="font-size: 0.65rem;"><i class="bi bi-box-arrow-in-right me-1"></i>Ir a Consulta</a></div>';
                    }

                    historialHtml += 
                        '<div class="card-consulta">' +
                          '<h6 title="' + motivo + '">' + motivo + '</h6>' +
                          '<small>' + fh_corta + ' &bull; ' + hora + '</small>' +
                          '<div class="mt-2"><span class="badge ' + badgeClass + ' rounded-pill">' + labelEstado + '</span></div>' +
                          btnConsulta +
                        '</div>';
                });
            }

            var perfilNombre = perfil.nombre || 'Paciente Sin Nombre';
            var nombreCoded = encodeURIComponent(perfilNombre);
            
            var cvCargos = formatMonedaSeguro(perfil.cargos).split('.')[0];
            var cvAbonos = formatMonedaSeguro(perfil.abonos).split('.')[0];
            var cvSaldo = formatMonedaSeguro(perfil.saldo).split('.')[0];
            var cvPresupuestos = formatMonedaSeguro(perfil.presupuestos || 0).split('.')[0];

            var perfilId = perfil.id || 'N/A';
            var perfilCorreo = perfil.correo || 'No registrado';
            var perfilTelefono = perfil.telefono || '';

            // Actualizar título del modal si existe
            var modalTitle = document.getElementById('modalHeaderTitle');
            if (modalTitle) {
                modalTitle.textContent = "Expediente: " + perfilNombre;
            }

            // Inyectar CSS Premium si no existe
            if (!document.getElementById('bentoPremiumStyles')) {
                var style = document.createElement('style');
                style.id = 'bentoPremiumStyles';
                style.innerHTML = `
                                          .bento-action-btn { background: linear-gradient(135deg, rgba(255, 255, 255, 0.9), rgba(255, 255, 255, 0.2)) !important; backdrop-filter: blur(15px); -webkit-backdrop-filter: blur(15px); border: 1px solid rgba(255, 255, 255, 0.8) !important; border-radius: 16px !important; transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1) !important; box-shadow: 0 8px 32px 0 rgba(10, 42, 102, 0.07), inset 0 0 10px rgba(255, 255, 255, 0.5) !important; text-decoration: none; color: #0A2A66 !important; position: relative; overflow: hidden; }
                      .bento-action-btn::before { content: ''; position: absolute; top: -50%; left: -50%; width: 200%; height: 200%; background: linear-gradient(to right, rgba(255,255,255,0) 0%, rgba(255,255,255,0.4) 50%, rgba(255,255,255,0) 100%); transform: rotate(30deg) translateY(-50%); transition: all 0.5s ease; opacity: 0; pointer-events: none; }
                      .bento-action-btn:hover { transform: translateY(-4px) !important; box-shadow: 0 15px 40px 0 rgba(10, 42, 102, 0.12), inset 0 0 15px rgba(255, 255, 255, 0.8) !important; border-color: rgba(24, 209, 230, 0.5) !important; }
                      .bento-action-btn:hover::before { opacity: 1; transform: rotate(30deg) translateY(50%); }
                      .bento-action-btn i { transition: transform 0.3s ease; }
                      .bento-action-btn:hover i { transform: scale(1.15); }
                    .paciente-info-bento { background: linear-gradient(135deg, #ffffff 0%, #f0f7ff 100%) !important; border: 1px solid rgba(59, 130, 246, 0.3) !important; box-shadow: 0 4px 12px rgba(59, 130, 246, 0.08) !important; transition: transform 0.3s ease; }
                    .paciente-info-bento:hover { transform: translateY(-2px); box-shadow: 0 6px 15px rgba(59, 130, 246, 0.12) !important; border-color: rgba(59, 130, 246, 0.6) !important; }
                    .kpi-btn-hover { transition: transform 0.3s ease, box-shadow 0.3s ease; cursor: pointer; }
                    .kpi-btn-hover:hover { transform: translateY(-4px); box-shadow: 0 15px 30px rgba(0,0,0,0.15) !important; }
                `;
                document.head.appendChild(style);
            }

            contenido.innerHTML = 
                  '<div class="row m-0" style="animation: fadeIn 0.4s ease-out;">' +
                    '<!-- Columna Izquierda: Paciente y Finanzas -->' +
                    '<div class="col-lg-5 col-12 p-0 pe-lg-3">' +
                        '<!-- Datos del Paciente -->' +
                        '<div class="paciente-info-bento mb-2 d-flex align-items-center p-2" style="border-radius: 16px;">' +
                          '<img src="https://ui-avatars.com/api/?name=' + nombreCoded + '&background=0A2A66&color=fff&size=40&bold=true" alt="Paciente" width="44" height="44" class="shadow-sm me-3" style="border-radius: 50%; border: 2px solid #fff;">' +
                          '<div class="overflow-hidden">' +
                            '<h6 class="text-truncate mb-0 fw-bold" title="' + perfilNombre.replace(/'/g, "&apos;") + '" style="font-size: 1rem; color: #0d1e3d; font-family: var(--font-primary, sans-serif); letter-spacing: -0.3px;">' + perfilNombre + '</h6>' +
                            '<small class="fw-bold" style="font-size: 0.75rem; color: #10b981;"><i class="bi bi-shield-check me-1"></i>ID: ' + perfilId + ' &bull; Activo</small>' +
                          '</div>' +
                        '</div>' +
                        
                        '<!-- KPI Cards -->' +
                        '<div class="row g-2 mb-3 mb-lg-0 flex-wrap">' +
                          '<div class="col-6">' +
                            '<div class="kpi-acrilico p-2 h-100 text-start d-flex flex-column justify-content-center m-0" style="width: 100%;">' +
                                '<span class="small fw-bold text-muted text-uppercase mb-1 d-block" style="font-size: 0.65rem;">Cargos</span>' +
                                '<h4 class="m-0 fw-bold text-end" style="color: var(--md-blue-deep); font-family: var(--font-primary, sans-serif); letter-spacing: -0.5px;">$' + cvCargos + '</h4>' +
                            '</div>' +
                          '</div>' +
                          '<div class="col-6">' +
                            '<div class="kpi-acrilico p-2 h-100 text-start d-flex flex-column justify-content-center m-0" style="width: 100%;">' +
                                '<span class="small fw-bold text-muted text-uppercase mb-1 d-block" style="font-size: 0.65rem;">Abonos</span>' +
                                '<h4 class="m-0 text-success fw-bold text-end" style="font-family: var(--font-primary, sans-serif); letter-spacing: -0.5px;">$' + cvAbonos + '</h4>' +
                            '</div>' +
                          '</div>' +
                          '<div class="col-6">' +
                            '<div class="kpi-acrilico p-2 h-100 text-start d-flex flex-column justify-content-center m-0" style="width: 100%;">' +
                                '<span class="small fw-bold text-muted text-uppercase mb-1 d-block" style="font-size: 0.65rem;">Saldo</span>' +
                                '<h3 class="fw-black text-danger m-0 text-end" style="font-family: var(--font-primary, sans-serif); letter-spacing: -0.5px;">$' + cvSaldo + '</h3>' +
                            '</div>' +
                          '</div>' +
                          '<div class="col-6">' +
                            '<div class="kpi-acrilico p-2 h-100 text-start d-flex flex-column justify-content-center m-0" style="width: 100%;">' +
                                '<span class="small fw-bold text-muted text-uppercase mb-1 d-block" style="font-size: 0.65rem;">Presupuestos</span>' +
                                '<h4 class="m-0 fw-bold text-dark text-end" style="font-family: var(--font-primary, sans-serif); letter-spacing: -0.5px;">$' + cvPresupuestos + '</h4>' +
                            '</div>' +
                          '</div>' +
                        '</div>' +
                    '</div>' +
                    '<div class="col-lg-7 col-12">' +
                        '<!-- Barra de Herramientas (Bento Grid) -->' +
                        '<div class="row g-2 mb-2">' +
                          '<div class="col-4">' +
                            '<a href="render_expediente_clinico.pl?id=' + perfilId + '" class="kpi-acrilico kpi-btn-hover p-2 w-100 h-100 d-flex flex-column align-items-center justify-content-center m-0 text-decoration-none" onclick="var m = document.getElementById(\'expedienteModal\'); if(m) { var b = bootstrap.Modal.getInstance(m); if(b) b.hide(); }"><i class="bi bi-folder2-open fs-4 mb-1 text-primary"></i> <span style="font-size: 0.55rem; font-weight: 700; letter-spacing: 0.3px; color: #0A2A66;">EXPEDIENTE</span></a>' +
                          '</div>' +
                          '<div class="col-4">' +
                            '<a href="estado_cuenta.pl?id=' + perfilId + '" class="kpi-acrilico kpi-btn-hover p-2 w-100 h-100 d-flex flex-column align-items-center justify-content-center m-0 text-decoration-none" onclick="var m = document.getElementById(\'expedienteModal\'); if(m) { var b = bootstrap.Modal.getInstance(m); if(b) b.hide(); }"><i class="bi bi-cash-stack fs-4 mb-1 text-success"></i> <span style="font-size: 0.55rem; font-weight: 700; letter-spacing: 0.3px; color: #0A2A66;">FINANZAS</span></a>' +
                          '</div>' +
                          '<div class="col-4">' +
                            '<a href="agenda_main.pl?new_cita_id=' + perfilId + '&new_cita_nombre=' + nombreCoded + '" class="kpi-acrilico kpi-btn-hover p-2 w-100 h-100 d-flex flex-column align-items-center justify-content-center m-0 text-decoration-none" onclick="var m = document.getElementById(\'expedienteModal\'); if(m) { var b = bootstrap.Modal.getInstance(m); if(b) b.hide(); }"><i class="bi bi-calendar-plus fs-4 mb-1" style="color: #8b5cf6;"></i> <span style="font-size: 0.55rem; font-weight: 700; letter-spacing: 0.3px; color: #0A2A66;">CITA</span></a>' +
                          '</div>' +
                          '<div class="col-3">' +
                            '<a href="render_consultas.pl?id=' + perfilId + '" class="kpi-acrilico kpi-btn-hover p-2 w-100 h-100 d-flex flex-column align-items-center justify-content-center m-0 text-decoration-none" onclick="var m = document.getElementById(\'expedienteModal\'); if(m) { var b = bootstrap.Modal.getInstance(m); if(b) b.hide(); }"><i class="bi bi-heart-pulse fs-4 mb-1 text-danger"></i> <span style="font-size: 0.55rem; font-weight: 700; letter-spacing: 0.3px; color: #0A2A66;">CONSULTA</span></a>' +
                          '</div>' +
                          '<div class="col-3">' +
                            '<button type="button" class="kpi-acrilico kpi-btn-hover p-2 w-100 h-100 d-flex flex-column align-items-center justify-content-center m-0 text-decoration-none" onclick="abrirModalCorreoSpa(\'' + perfilCorreo + '\', \'' + perfilNombre.replace(/'/g, "\\'") + '\', \'' + perfilId + '\')"><i class="bi bi-envelope fs-4 mb-1 text-warning"></i> <span style="font-size: 0.55rem; font-weight: 700; letter-spacing: 0.3px; color: #0A2A66;">CORREO</span></button>' +
                          '</div>' +
                          '<div class="col-3">' +
                            '<a href="https://wa.me/' + perfilTelefono + '" target="_blank" class="kpi-acrilico kpi-btn-hover p-2 w-100 h-100 d-flex flex-column align-items-center justify-content-center m-0 text-decoration-none"><i class="bi bi-whatsapp fs-4 mb-1" style="color: #25D366;"></i> <span style="font-size: 0.55rem; font-weight: 700; letter-spacing: 0.3px; color: #0A2A66;">WHATSAPP</span></a>' +
                          '</div>' +
                          '<div class="col-3">' +
                            '<a href="imprime_ficha_identificacion.pl?id=' + perfilId + '" class="kpi-acrilico kpi-btn-hover p-2 w-100 h-100 d-flex flex-column align-items-center justify-content-center m-0 text-decoration-none"><i class="bi bi-printer fs-4 mb-1 text-secondary"></i> <span style="font-size: 0.55rem; font-weight: 700; letter-spacing: 0.3px; color: #0A2A66;">IMPRIMIR</span></a>' +
                          '</div>' +
                        '</div>' +
                        '<!-- Historial de Consultas -->' +
                        '<div class="d-flex justify-content-between align-items-center mt-3 mb-2">' +
                            '<h6 class="fw-bold mb-0" style="color: #0A2A66; font-family: var(--font-primary); font-size: 0.9rem; letter-spacing: -0.2px;"><i class="bi bi-clock-history me-1 text-primary"></i> Consultas</h6>' +
                            '<div class="d-flex gap-2">' +
                                '<button class="btn btn-sm btn-light border rounded-circle shadow-sm" onclick="document.getElementById(\'carruselHistorial\').scrollBy({left:-200, behavior:\'smooth\'})" title="Deslizar Izquierda" style="width: 26px; height: 26px; padding: 0; display: flex; align-items: center; justify-content: center;"><i class="bi bi-chevron-left" style="font-size: 0.7rem;"></i></button>' +
                                '<button class="btn btn-sm btn-light border rounded-circle shadow-sm" onclick="document.getElementById(\'carruselHistorial\').scrollBy({left:200, behavior:\'smooth\'})" title="Deslizar Derecha" style="width: 26px; height: 26px; padding: 0; display: flex; align-items: center; justify-content: center;"><i class="bi bi-chevron-right" style="font-size: 0.7rem;"></i></button>' +
                            '</div>' +
                        '</div>' +
                        '<div class="historial-consultas-h pb-2" id="carruselHistorial">' +
                            historialHtml +
                        '</div>' +
                    '</div>' +
                  '</div>';
        } catch (renderError) {
            console.error("[SDM UI Error Boundary] Error en renderExpediente:", renderError);
            if (contenido) {
                contenido.innerHTML = 
                    '<div class="alert alert-warning m-4 shadow-sm border-0">' +
                        '<h6 class="fw-bold mb-2"><i class="bi bi-exclamation-triangle-fill me-2"></i>Error de Visualización</h6>' +
                        '<p class="mb-0 small">Ocurrió un error al procesar el expediente en este navegador. Detalle: ' + renderError.message + '</p>' +
                    '</div>';
            }
        }
    }
    
    // Set flag inside initPacientesSpa, outside the event listener
    window._pacientesSpaEventAttached = true;
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initPacientesSpa);
} else {
    initPacientesSpa();
}
document.addEventListener('spa:contentLoaded', initPacientesSpa);

// --- Modal Dinámico de Envío de Email CRM ---
window.abrirModalCorreoSpa = function(correoBase, nombreBase, idPaciente) {
    // Cerrar expediente modal si está abierto
    var mExpediente = document.getElementById('expedienteModal');
    if (mExpediente) {
        var bsExp = bootstrap.Modal.getInstance(mExpediente);
        if (bsExp) bsExp.hide();
    }

    if(!document.getElementById('modalCorreoSpaContainer')) {
        var modalHtml = 
            '<div class="modal fade modal-diamond" id="modalCorreoSpaContainer" tabindex="-1" aria-labelledby="modalCorreoSpaLabel" aria-hidden="true" style="z-index: 106000 !important;">' +
                '<div class="modal-dialog modal-dialog-centered modal-lg">' +
                    '<div class="modal-content border-0 shadow-lg">' +
                        '<div class="modal-header fw-bold">' +
                            '<h5 class="modal-title d-flex align-items-center" id="modalCorreoSpaLabel"><i class="bi bi-envelope-paper-fill me-2" style="color: #f59e0b !important;"></i> Redactar Correo a Paciente</h5>' +
                            '<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>' +
                        '</div>' +
                        '<div class="modal-body p-4 bg-light">' +
                            '<form id="formCorreoCrm" enctype="multipart/form-data">' +
                                '<div class="row g-3 mb-3">' +
                                    '<div class="col-md-6">' +
                                        '<label class="form-label text-muted fw-bold small text-uppercase">Destinatario (Para)</label>' +
                                        '<input type="email" class="form-control bg-white shadow-sm border-0 rounded-3" id="crmInputTo" name="para" required readonly>' +
                                        '<input type="hidden" id="crmInputIdPaciente" name="id_paciente">' +
                                    '</div>' +
                                    '<div class="col-md-6">' +
                                        '<label class="form-label text-muted fw-bold small text-uppercase">Asunto</label>' +
                                        '<input type="text" class="form-control shadow-sm border-0 rounded-3" name="asunto" id="crmInputSubject" required>' +
                                    '</div>' +
                                '</div>' +
                                '<div class="mb-3">' +
                                    '<label class="form-label text-muted fw-bold small text-uppercase">Cuerpo del Mensaje (Soporta HTML)</label>' +
                                    '<textarea class="form-control shadow-sm border-0 rounded-3" name="cuerpo" rows="4" required></textarea>' +
                                '</div>' +
                                '<div class="mb-1">' +
                                    '<label class="form-label text-muted fw-bold small text-uppercase"><i class="bi bi-paperclip"></i> Adjuntar Archivos (PDF, XLS, DOC... max 5MB)</label>' +
                                    '<input type="file" class="form-control shadow-sm border-0 rounded-3" name="adjuntos" multiple accept=".pdf,.doc,.docx,.xls,.xlsx,.jpg,.jpeg,.png">' +
                                '</div>' +
                            '</form>' +
                        '</div>' +
                        '<div class="modal-footer bg-light border-0">' +
                            '<button type="button" class="btn btn-secondary rounded-pill fw-bold border-0 shadow-sm" data-bs-dismiss="modal">Cancelar</button>' +
                            '<button type="button" class="btn btn-primary rounded-pill fw-bold shadow-sm px-4" id="btnEnviarCorreoCrm">' +
                                '<i class="bi bi-send-fill me-2"></i> Enviar Correo' +
                            '</button>' +
                        '</div>' +
                    '</div>' +
                '</div>' +
            '</div>';
        document.body.insertAdjacentHTML('beforeend', modalHtml);

        document.getElementById('btnEnviarCorreoCrm').addEventListener('click', function() {
            var formObj = document.getElementById('formCorreoCrm');
            if(!formObj.checkValidity()) {
                formObj.reportValidity(); return;
            }
            var btnSubmit = this;
            var originalText = btnSubmit.innerHTML;
            btnSubmit.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span> Transmitiendo...';
            btnSubmit.disabled = true;

            Swal.fire({
                title: 'Transmitiendo...',
                html: 'Aguarde un momento por favor. Empaquetando y enviando correo al paciente.',
                allowOutsideClick: false,
                didOpen: function() {
                    Swal.showLoading()
                }
            });

            var formData = new FormData(formObj);
            
            if (window.fetch) {
                fetch('../api/enviar_correo_paciente_api.pl', {
                    method: 'POST',
                    body: formData
                })
                .then(function(response) { return response.json(); })
                .then(function(data) { procesarRespuestaCorreo(data, btnSubmit, originalText, formObj); })
                .catch(function(err) { mostrarErrorCorreo(err, btnSubmit, originalText); });
            } else if (window.jQuery) {
                jQuery.ajax({
                    url: '../api/enviar_correo_paciente_api.pl',
                    type: 'POST',
                    data: formData,
                    processData: false,
                    contentType: false
                })
                .done(function(data) { procesarRespuestaCorreo(data, btnSubmit, originalText, formObj); })
                .fail(function(jqXHR, textStatus, err) { mostrarErrorCorreo(err, btnSubmit, originalText); });
            }
        });
    }

    function procesarRespuestaCorreo(data, btnSubmit, originalText, formObj) {
        if(data.ok) {
            Swal.fire({
                icon: 'success',
                title: '¡Enviado Exitosamente!',
                text: data.msg,
                confirmButtonColor: '#174975'
            });
            var modalEl = document.getElementById('modalCorreoSpaContainer');
            var bsModal = bootstrap.Modal.getInstance(modalEl) || new bootstrap.Modal(modalEl);
            bsModal.hide();
            formObj.reset();
        } else {
            Swal.fire({
                icon: 'warning',
                title: 'Atención: Interrupción',
                html: '<p class="mb-2 fw-bold text-dark">' + (data.msg || 'El servidor declinó el envío o no hubo respuesta del túnel.') + '</p>' +
                       '<div class="text-start mt-3 small bg-light p-3 rounded border text-secondary shadow-sm">' +
                        '<strong>Alternativas de Solución:</strong>' +
                        '<ul class="mb-0 mt-2 ps-3 lh-lg">' +
                        '<li>Verifica que la dirección de correo sea válida y que no contenga espacios invisibles.</li>' +
                        '<li>Asegúrate de que los archivos adjuntos (en conjunto) no rebasen los 5MB de capacidad.</li>' +
                        '<li>Si el correo sigue siendo rechazado por un problema de módulos (como MIME::Lite), <strong>comunícate a Soporte Técnico</strong>.</li>' +
                        '</ul>' +
                       '</div>',
                confirmButtonColor: '#174975'
            });
        }
        btnSubmit.innerHTML = originalText;
        btnSubmit.disabled = false;
    }

    function mostrarErrorCorreo(err, btnSubmit, originalText) {
        console.error("[DEBUG CRM EMAIL] Fallo de Red Crítico:", err);
        Swal.fire({
            icon: 'error',
            title: 'Fallo Crítico de Red',
            html: '<p class="mb-2 fw-bold text-dark">La petición falló abruptamente. Tipo de error: ' + (err.message || 'Error Desconocido') + '</p>' +
                   '<div class="text-start mt-3 small bg-danger bg-opacity-10 p-3 rounded border border-danger text-danger shadow-sm">' +
                    '<strong>Diagnóstico y Pasos a Seguir:</strong>' +
                    '<ul class="mb-0 mt-2 ps-3 lh-lg">' +
                    '<li><strong>Conexión:</strong> Es posible que hayas perdido conectividad a tu red Wifi/Ethernet.</li>' +
                    '<li><strong>Bloqueo de Seguridad:</strong> El peso del archivo o su contenido causó un bloqueo inmediato en el firewall local, interrumpiendo la petición.</li>' +
                    '<li>Si el internet funciona bien y el error es constante (posible Error de Servidor 500 no capturado), <strong>por favor llama a Soporte Técnico SDM</strong> indicando que el endpoint de email está caído.</li>' +
                    '</ul>' +
                   '</div>',
            confirmButtonColor: '#174975'
        });

        btnSubmit.innerHTML = originalText;
        btnSubmit.disabled = false;
    }

    // Config Inicial del modal al abrirse
    document.getElementById('crmInputTo').value = correoBase;
    document.getElementById('crmInputIdPaciente').value = idPaciente;
    document.getElementById('formCorreoCrm').reset();
    document.getElementById('crmInputSubject').value = "Información Importante de su Clínica";
    
    var modalEl = document.getElementById('modalCorreoSpaContainer');
    var bModalCorreo = bootstrap.Modal.getInstance(modalEl) || new bootstrap.Modal(modalEl);
    bModalCorreo.show();
};
