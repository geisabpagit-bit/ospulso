<!-- MODALES (BOOTSTRAP 5) -->
<div class="modal fade modal-diamond" id="modalCargo" tabindex="-1" aria-labelledby="modalCargoTitle" aria-hidden="true">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header" style="background: linear-gradient(135deg, var(--md-blue-deep, #0A2A66) 0%, #f59e0b 100%) !important;">
                <h5 class="modal-title font-secondary fw-bold text-white" id="modalCargoTitle">
                    <i class="bi bi-cart-plus me-2"></i>Nueva Orden de Servicio
                </h5>
                <button type="button" class="btn-close btn-close-white shadow-none" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body" style="background: var(--md-white-clinical, #F8FBFF);">
                <!-- Fila superior: Tipo de cargo + Alias -->
                <div class="row g-2 mb-3">
                    <div class="col-md-6">
                        <div class="bento-card p-3 h-100" style="border-radius: 12px;">
                            <label class="kpi-label">Aplica para</label>
                        <div class="d-flex gap-4 mt-1">
                            <div class="form-check">
                                <input class="form-check-input" type="radio" name="aplica_para" id="aplica_cotizacion" value="Consulta">
                                <label class="form-check-label fw-bold small" style="color: var(--md-text-secondary, #486581);" for="aplica_cotizacion">Cotizaci&oacute;n</label>
                            </div>
                            <div class="form-check">
                                <input class="form-check-input" type="radio" name="aplica_para" id="aplica_consulta" value="Consulta" checked>
                                <label class="form-check-label fw-bold small" style="color: var(--md-text-secondary, #486581);" for="aplica_consulta">Consulta</label>
                            </div>
                        </div>
                        <!-- Selector de cotizacion (aparece al elegir radio Cotizacion) -->
                        <div id="panelSelCotizacion" class="mt-2 d-none">
                            <label class="kpi-label mb-1">Cargar desde cotizaci&oacute;n guardada</label>
                            <select id="selectCotizacionCargo" class="form-select form-select-sm rounded-3 shadow-sm border-0"
                                onchange="if(this.value) { window._cargarCotizacionEnCarrito(this.value); }">
                                <option value="">-- Selecciona una cotizaci&oacute;n --</option>
                            </select>
                            <small class="text-muted d-block mt-1"><i class="bi bi-info-circle me-1"></i>Los conceptos se cargar&aacute;n en el carrito. Puedes editar antes de procesar.</small>
                        </div>

                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="bento-card p-3 h-100" style="border-radius: 12px;">
                            <label class="kpi-label" for="alias_os_cargo">Alias / Referencia <span class="fw-normal text-muted">(Opcional)</span></label>
                            <input type="text" id="alias_os_cargo" class="form-control form-control-sm mt-1" maxlength="25" placeholder="Ej. Anticipo Brackets"
                                style="border-radius: 8px; border: 1px solid var(--md-gray-soft, #D9E2EC); font-family: 'Plus Jakarta Sans', sans-serif;">
                        </div>
                    </div>
                </div>

                <div class="row g-3">
                    <!-- Columna Izquierda: CatÃ¡logo -->
                    <div class="col-lg-7">
                        <!-- Entrada manual -->
                        <div class="bento-card p-3 mb-2" style="border-radius: 12px;">
                            <label class="kpi-label mb-2">Entrada Manual</label>
                            <div class="input-group input-group-sm">
                                <input type="text" id="manual_nombre" class="form-control"
                                    placeholder="Concepto (ej. Consulta General)"
                                    style="border-color: var(--md-gray-soft, #D9E2EC); font-family: 'Plus Jakarta Sans', sans-serif;">
                                <span class="input-group-text fw-bold" style="background: var(--md-white-clinical, #F8FBFF); border-color: var(--md-gray-soft, #D9E2EC); color: var(--md-blue-deep, #0A2A66);">\$</span>
                                <input type="number" id="manual_precio" class="form-control" style="max-width: 90px; border-color: var(--md-gray-soft, #D9E2EC);" placeholder="0.00" step="0.01" min="0">
                                <button onclick="agregarCargoManual()" class="btn btn-sm px-3 fw-bold"
                                    style="background: linear-gradient(135deg, var(--md-blue-deep, #0A2A66), var(--md-blue-medical, #124A9E)); color: white; border: none;">
                                    <i class="bi bi-plus-lg"></i>
                                </button>
                            </div>
                        </div>

                        <!-- Buscador catÃ¡logo -->
                        <div class="position-relative mb-2">
                            <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-3 small" style="color: var(--md-cyan-ia, #18D1E6);"></i>
                            <input type="text" id="buscadorCatalogo"
                                class="form-control form-control-sm ps-4 py-2 rounded-pill border-0 shadow-sm"
                                placeholder="Buscar en catÃ¡logo de servicios y productos..."
                                style="background: white; font-family: 'Plus Jakarta Sans', sans-serif;"
                                oninput="filtrarCatalogo()" onkeyup="filtrarCatalogo()">
                        </div>

                        <!-- Tabla catÃ¡logo -->
                        <div class="table-responsive shadow-sm" style="max-height: 200px; overflow-y: auto; border-radius: 10px; border: 1px solid var(--md-gray-soft, #D9E2EC);">
                            <table class="table table-hover table-sm align-middle mb-0" style="background: white;">
                                <thead style="background: var(--md-white-clinical, #F8FBFF); position: sticky; top: 0; z-index: 1;">
                                    <tr>
                                        <th class="ps-3 py-2" style="font-family: 'Plus Jakarta Sans', sans-serif; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: var(--md-text-secondary, #486581); border-bottom: 2px solid var(--md-gray-soft, #D9E2EC);">Concepto</th>
                                        <th class="text-end py-2" style="font-family: 'Plus Jakarta Sans', sans-serif; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; color: var(--md-text-secondary, #486581); border-bottom: 2px solid var(--md-gray-soft, #D9E2EC);">Precio</th>
                                        <th style="width: 60px; border-bottom: 2px solid var(--md-gray-soft, #D9E2EC);"></th>
                                    </tr>
                                </thead>
                                <tbody id="tablaCatalogo">
                                    <!-- AJAX rellena esto -->
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Columna Derecha: Carrito -->
                    <div class="col-lg-5">
                        <div class="bento-card p-3 h-100 d-flex flex-column" style="border-radius: 12px; background: white;">
                            <h6 class="fw-bold mb-2" style="font-family: 'Plus Jakarta Sans', sans-serif; color: var(--md-blue-deep, #0A2A66); font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.5px;">
                                <i class="bi bi-cart3 me-1" style="color: var(--md-cyan-ia, #18D1E6);"></i>Resumen del Cargo
                            </h6>
                            <div id="listaCarrito" class="flex-grow-1 d-flex flex-column gap-2 overflow-auto mb-3" style="max-height: 230px;"></div>
                            <div class="p-3 rounded-4 mt-auto" style="background: var(--md-white-clinical, #F8FBFF); border: 1px solid var(--md-gray-soft, #D9E2EC);">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <span class="kpi-label m-0" style="font-size: 0.7rem;">TOTAL CARGO</span>
                                    <span class="fw-bold m-0" id="carritoTotal" style="font-size: 1.5rem; font-family: 'Plus Jakarta Sans', sans-serif; color: var(--md-blue-deep, #0A2A66);">\$0.00</span>
                                </div>
                                <button class="btn btn-sm w-100 py-2 fw-bold rounded-3 shadow" id="btnProcesarCargo" onclick="procesarCarrito()"
                                    style="background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; border: none; font-family: 'Plus Jakarta Sans', sans-serif; letter-spacing: 0.3px; transition: all 0.3s ease;">
                                    <i class="bi bi-check-circle me-1"></i>PROCESAR CARGO
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

