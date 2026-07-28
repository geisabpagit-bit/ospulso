use strict;
use warnings;
use utf8;

sub render_step_caja_privado {
    my ($paciente) = @_;
    
    # Obtener todas las cotizaciones del paciente para pasarlas a JSON
    my $id_p = $paciente->{id_paciente} || '';
    my $cot_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cotizaciones.dat');
    my $items_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cotizaciones_items.dat');
    
    my %cot_data = ();
    
    # 1. Leer cotizaciones
    if (-e $cot_file && open(my $fh, '<:encoding(UTF-8)', $cot_file)) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            next unless @c >= 6;
            my $id_cot = $c[0];
            my $cot_pac = $c[1] // '';
            my $estado = $c[6] // 'Pendiente';
            if ($cot_pac eq $id_p && $estado ne 'Convertida') {
                $cot_data{$id_cot} = {
                    nombre => $c[2],
                    total  => $c[3] + 0,
                    fecha  => $c[4],
                    items  => []
                };
            }
        }
        close($fh);
    }
    
    # 2. Leer conceptos de cotizaciones
    if (-e $items_file && open(my $fh, '<:encoding(UTF-8)', $items_file)) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            next unless @c >= 5;
            my $id_cot = $c[0];
            if (exists $cot_data{$id_cot}) {
                push @{$cot_data{$id_cot}{items}}, {
                    concepto => $c[1],
                    precio   => $c[2] + 0,
                    cantidad => $c[3] + 0,
                    subtotal => $c[4] + 0
                };
            }
        }
        close($fh);
    }
    
    use JSON::PP;
    my $json_cots = JSON::PP->new->utf8(1)->encode(\%cot_data);
    
    # 3. Buscar si tiene tratamiento abierto
    my $trat_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'tratamientos.dat');
    my $tiene_tratamiento = 0;
    my $id_tratamiento_activo = '';
    my $id_cotizacion_activa = '';
    
    if (-e $trat_file && open(my $fh_t, '<:encoding(UTF-8)', $trat_file)) {
        my $header = <$fh_t>;
        while (my $line = <$fh_t>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            next unless @c >= 4;
            if ($c[1] eq $id_p && $c[3] eq 'Abierto') {
                $tiene_tratamiento = 1;
                $id_tratamiento_activo = $c[0];
                $id_cotizacion_activa = $c[2];
                last;
            }
        }
        close($fh_t);
    }
    
    # 4. Cargar cargos y abonos del paciente / tratamiento activo (incluyendo recepción)
    my @cargos = ();
    my @abonos = ();
    my $total_cargos = 0;
    my $total_abonos = 0;
    
    my $fin_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
    if (-e $fin_file && open(my $fh_f, '<:encoding(UTF-8)', $fin_file)) {
        my $header = <$fh_f>;
        while (my $line = <$fh_f>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            next unless @c >= 8;
            my $id_os_row = $c[0] // '';
            my $id_pac_row = $c[2] // '';
            
            if ($id_pac_row eq $id_p && (!$tiene_tratamiento || $id_os_row eq $id_tratamiento_activo || $line =~ /Recepción|Recepcion/i)) {
                my $tipo = $c[3];
                my $total = $c[7] // 0;
                if ($tipo eq 'Cargo') {
                    push @cargos, {
                        concepto => $c[4],
                        total    => $total + 0
                    };
                    $total_cargos += $total;
                } elsif ($tipo eq 'Abono') {
                    push @abonos, {
                        concepto => $c[4],
                        total    => $total + 0,
                        fecha    => $c[8]
                    };
                    $total_abonos += $total;
                }
            }
        }
        close($fh_f);
    }
    
    my $saldo_pendiente = $total_cargos - $total_abonos;
    
    my $json_historial = JSON::PP->new->utf8(1)->encode({
        tiene_tratamiento => $tiene_tratamiento,
        id_tratamiento => $id_tratamiento_activo,
        cargos => \@cargos,
        abonos => \@abonos,
        total_cargos => $total_cargos,
        total_abonos => $total_abonos,
        saldo_pendiente => $saldo_pendiente
    });
    
    return qq{
        <div class="wizard-panel" id="step-panel-6">
            <input type="hidden" name="caja_items_json" id="f_caja_items_json" value="[]">
            
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-wallet2 me-2" style="color: var(--md-teal-clinical);"></i>Caja y Registro de Pago
            </h3>
            
            <div id="caja-no-cotizacion" class="text-center py-5 border rounded-4 bg-light mb-4">
                <i class="bi bi-info-circle text-muted fs-1 mb-3 d-block"></i>
                <h5 class="fw-bold text-muted font-secondary">No se seleccion&oacute; ninguna cotizaci&oacute;n</h5>
                <p class="text-muted small">Puede continuar al cierre o registrar conceptos/servicios directamente para esta consulta.</p>
                <button type="button" class="btn btn-outline-primary rounded-pill px-4 mt-2 fw-bold" onclick="abrirModalCargoConsultas()">
                    <i class="bi bi-cart-plus me-2"></i>Registrar Conceptos / Orden de Servicio
                </button>
            </div>
            
            <div id="caja-workflow-container" style="display: none;">
                <!-- Conceptos de la Cotización -->
                <div class="card border-0 shadow-sm rounded-4 p-4 mb-4" style="border: 1px solid rgba(25, 183, 165, 0.2) !important;">
                    <div class="d-flex justify-content-between align-items-center mb-3">
                        <h5 class="fw-black text-navy mb-0"><i class="bi bi-cart3 me-2" style="color: var(--md-teal-clinical);"></i>Conceptos a Cobrar</h5>
                        <button type="button" class="btn btn-outline-secondary btn-sm rounded-pill px-3 fw-bold" onclick="abrirModalCargoConsultas()">
                            <i class="bi bi-plus-lg me-1"></i>Agregar Concepto Adicional
                        </button>
                    </div>
                    <div class="table-responsive">
                        <table class="table table-hover align-middle">
                            <thead>
                                <tr class="text-muted small text-uppercase">
                                    <th>Concepto</th>
                                    <th class="text-end">Precio</th>
                                    <th class="text-center">Cant.</th>
                                    <th class="text-end">Subtotal</th>
                                </tr>
                            </thead>
                            <tbody id="caja-tbody-items"></tbody>
                        </table>
                    </div>
                </div>
                
                <!-- Opciones Financieras y Cita -->
                <div class="row g-4">
                    <div class="col-md-6">
                        <div class="card border-0 shadow-sm rounded-4 p-4 h-100" style="border: 1px solid rgba(25, 183, 165, 0.2) !important;">
                            <h5 class="fw-black text-navy mb-3"><i class="bi bi-cash-coin me-2" style="color: var(--md-teal-clinical);"></i>Gesti&oacute;n de Caja</h5>
                            
                            <div class="mb-3">
                                <label class="wizard-label">Tipo de Pago</label>
                                <select name="caja_tipo_pago" id="f_caja_tipo_pago" class="wizard-input" onchange="actualizarMontoPago()">
                                    <option value="Liquidar">Liquidar (Totalidad)</option>
                                    <option value="Abonar">Abonar (Pago Parcial)</option>
                                </select>
                            </div>
                            
                            <div class="mb-3">
                                <label class="wizard-label">Monto a Pagar (\$)</label>
                                <input type="number" step="0.01" min="0" name="caja_monto_abono" id="f_caja_monto_abono" class="wizard-input fw-bold" readonly>
                            </div>
                            
                            <div class="mb-3">
                                <label class="wizard-label">M&eacute;todo de Pago</label>
                                <select name="caja_metodo_pago" class="wizard-input">
                                    <option value="Efectivo">Efectivo</option>
                                    <option value="Tarjeta">Tarjeta de Cr&eacute;dito/D&eacute;bito</option>
                                    <option value="Transferencia">Transferencia Bancaria</option>
                                </select>
                            </div>
                            
                            <div class="mb-3">
                                <label class="wizard-label">Destino del Tratamiento</label>
                                <select name="caja_estado_tratamiento" id="f_caja_estado_tratamiento" class="wizard-input" onchange="toggleCitaWorkflow()">
                                    <option value="Abierto">Dejar tratamiento abierto (Requiere pr&oacute;xima cita)</option>
                                    <option value="Cerrado">Finalizar y Cerrar tratamiento (Alta m&eacute;dica)</option>
                                    <option value="Cobro por recepción">Cobro por recepci&oacute;n (Pendiente por Recepcionista)</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <div class="card border-0 shadow-sm rounded-4 p-4 h-100" style="border: 1px solid rgba(25, 183, 165, 0.2) !important;">
                            <h5 class="fw-black text-navy mb-3"><i class="bi bi-calendar-week me-2" style="color: var(--md-teal-clinical);"></i>Programaci&oacute;n de Cita</h5>
                            
                            <div id="cita-no-requerida" class="text-center py-5 opacity-75">
                                <i class="bi bi-check-circle text-success fs-1 mb-2 d-block"></i>
                                <h6 class="fw-bold">El tratamiento ser&aacute; finalizado</h6>
                                <p class="text-muted small m-0">No se requiere cita de seguimiento para este tratamiento.</p>
                            </div>
                            
                            <div id="cita-requerida-workflow" style="display: none;">
                                <div class="alert alert-warning border-0 rounded-3 small mb-3">
                                    <i class="bi bi-exclamation-triangle-fill me-2"></i> El tratamiento se quedar&aacute; abierto. Es obligatorio agendar una cita de seguimiento antes de cerrar la consulta.
                                </div>
                                <div id="cita-status-card" class="p-3 border rounded-3 text-center bg-light">
                                    <i class="bi bi-calendar-event fs-2 mb-2 text-muted" id="cita-status-icon"></i>
                                    <h6 class="fw-bold text-navy m-0" id="cita-status-text">Sin Cita Agendada</h6>
                                    <p class="text-muted small m-0 mt-1" id="cita-status-detail">Haga clic en el bot&oacute;n inferior para seleccionar fecha y hora en la agenda.</p>
                                    
                                    <input type="hidden" name="proxima_cita_id" id="f_proxima_cita_id" value="">
                                    
                                    <button type="button" class="btn btn-outline-primary rounded-pill px-4 mt-3 fw-bold" onclick="abrirModalCitaConsulta()">
                                        <i class="bi bi-calendar-plus me-2"></i>Agendar Cita en Calendario
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5 pt-4 border-top">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="validarPasoCajaYContinuar()">Continuar a Cierre <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>

        <!-- MODAL ORDEN DE SERVICIO / NUEVO CARGO CONSULTAS -->
        <div class="modal fade modal-diamond" id="modalCargoConsultas" tabindex="-1" aria-labelledby="modalCargoConsultasTitle" aria-hidden="true" style="z-index: 106000 !important;">
            <div class="modal-dialog modal-xl modal-dialog-centered">
                <div class="modal-content">
                    <div class="modal-header" style="background: linear-gradient(135deg, var(--md-blue-deep, #0A2A66) 0%, #f59e0b 100%) !important;">
                        <h5 class="modal-title font-secondary fw-bold text-white" id="modalCargoConsultasTitle">
                            <i class="bi bi-cart-plus me-2"></i>Registrar Conceptos / Orden de Servicio
                        </h5>
                        <button type="button" class="btn-close btn-close-white shadow-none" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body" style="background: var(--md-white-clinical, #F8FBFF);">
                        <div class="row g-3">
                            <!-- Columna Izquierda: Catálogo -->
                            <div class="col-lg-7">
                                <!-- Entrada manual -->
                                <div class="card border-0 shadow-sm p-3 mb-2 rounded-3" style="background: white;">
                                    <label class="wizard-label mb-2"><i class="bi bi-pencil-square me-1 text-primary"></i>Entrada Manual</label>
                                    <div class="input-group input-group-sm">
                                        <input type="text" id="manual_nombre_consultas" class="form-control animate__animated" placeholder="Concepto (ej. Consulta Especialista)" style="border-radius: 8px 0 0 8px;">
                                        <span class="input-group-text fw-bold">\$</span>
                                        <input type="number" id="manual_precio_consultas" class="form-control" style="max-width: 90px;" placeholder="0.00" step="0.01" min="0">
                                        <button type="button" onclick="agregarCargoManualConsultas()" class="btn btn-primary px-3 fw-bold" style="border-radius: 0 8px 8px 0;">
                                            <i class="bi bi-plus-lg"></i>
                                        </button>
                                    </div>
                                </div>

                                <!-- Buscador catálogo -->
                                <div class="position-relative mb-2">
                                    <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-3 small text-muted"></i>
                                    <input type="text" id="buscadorCatalogoConsultas" class="form-control form-control-sm ps-5 py-2 rounded-pill border shadow-sm" placeholder="Buscar en catálogo de servicios y productos..." oninput="filtrarCatalogoConsultas()">
                                </div>

                                <!-- Tabla catálogo -->
                                <div class="table-responsive shadow-sm" style="max-height: 220px; overflow-y: auto; border-radius: 10px; border: 1px solid #dee2e6; background: white;">
                                    <table class="table table-hover table-sm align-middle mb-0">
                                        <thead class="table-light" style="position: sticky; top: 0; z-index: 1;">
                                            <tr>
                                                <th class="ps-3 py-2 small fw-bold text-muted text-uppercase">Concepto</th>
                                                <th class="text-end py-2 small fw-bold text-muted text-uppercase">Precio</th>
                                                <th style="width: 60px;"></th>
                                            </tr>
                                        </thead>
                                        <tbody id="tablaCatalogoConsultas"></tbody>
                                    </table>
                                </div>
                            </div>

                            <!-- Columna Derecha: Carrito -->
                            <div class="col-lg-5">
                                <div class="card border-0 shadow-sm p-3 h-100 d-flex flex-column rounded-3" style="background: white;">
                                    <h6 class="fw-bold mb-2 text-navy small text-uppercase">
                                        <i class="bi bi-cart3 me-1 text-primary"></i>Resumen de la Orden
                                    </h6>
                                    <div id="listaCarritoConsultas" class="flex-grow-1 overflow-auto mb-3" style="max-height: 250px;"></div>
                                    <div class="p-3 rounded-3 mt-auto bg-light border">
                                        <div class="d-flex justify-content-between align-items-center mb-2">
                                            <span class="small fw-bold text-muted">TOTAL CARGOS</span>
                                            <span class="fw-bold fs-4 text-navy" id="carritoTotalConsultas">\$0.00</span>
                                        </div>
                                        <button type="button" class="btn btn-warning w-100 py-2 fw-bold text-white shadow-sm" onclick="confirmarCargosConsultas()">
                                            <i class="bi bi-check-circle me-1"></i>CONFIRMAR CONCEPTOS
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <script>
        const cotizacionesData = $json_cots;
        const historialTratamiento = $json_historial;
        
        // Carrito de conceptos directos de la consulta activa
        var carritoConsulta = carritoConsulta || [];
        var catalogoMasterConsultas = [];
        var carritoLocalConsultas = [];
        
        async function abrirModalCargoConsultas() {
            const el = document.getElementById('modalCargoConsultas');
            if (!el) return console.error("Modal Cargo Consultas no encontrado");
            
            if (el.parentElement !== document.body) {
                document.body.appendChild(el);
            }
            
            carritoLocalConsultas = JSON.parse(JSON.stringify(carritoConsulta || [])); // Clonar
            refrescarGUICarritoConsultas();
            
            const m = bootstrap.Modal.getOrCreateInstance(el);
            m.show();
            
            // Cargar catálogo si no está cargado
            if (catalogoMasterConsultas.length === 0) {
                try {
                    const res = await fetch('../api/estado_cuenta_api.pl', { 
                        method: 'POST', 
                        body: new URLSearchParams({accion: 'get_catalogo'}), 
                        credentials: 'same-origin' 
                    });
                    const data = await res.json();
                    catalogoMasterConsultas = [...(data.servicios||[]), ...(data.productos||[])];
                } catch(e) {
                    console.error("Fallo al cargar catálogo:", e);
                }
            }
            renderCatalogoGUIConsultas();
        }
        
        function renderCatalogoGUIConsultas(f = '') {
            const tbody = document.getElementById('tablaCatalogoConsultas'); if(!tbody) return;
            tbody.innerHTML = '';
            const filtered = catalogoMasterConsultas.filter(i => (i.nombre||'').toLowerCase().includes(f.toLowerCase()));
            
            filtered.forEach(it => {
                tbody.innerHTML += `
                    <tr style="cursor:pointer;" onclick="agregarAlCarritoConsultas('\${it.id}')">
                        <td class="fw-bold text-dark small text-truncate" style="max-width:250px;">\${it.nombre}</td>
                        <td class="text-primary fw-bold text-end small">\$\${it.precio.toFixed(2)}</td>
                        <td class="text-center" style="width: 40px;">
                            <div class="btn btn-sm btn-primary rounded-circle shadow-sm d-flex align-items-center justify-content-center" style="width:24px; height:24px; padding:0; border:none;"><i class="bi bi-plus" style="font-size:1rem;"></i></div>
                        </td>
                    </tr>`;
            });
        }
        
        function filtrarCatalogoConsultas() {
            renderCatalogoGUIConsultas(document.getElementById('buscadorCatalogoConsultas').value);
        }
        
        function agregarCargoManualConsultas() {
            const n = document.getElementById('manual_nombre_consultas'), p = document.getElementById('manual_precio_consultas');
            if(!n.value || !p.value) {
                Swal.fire("Aviso", "Indique descripción y precio", "warning");
                return;
            }
            const id = 'MAN-'+Date.now();
            carritoLocalConsultas.push({ id, nombre: n.value, precio: parseFloat(p.value), cantidad: 1 });
            n.value = ''; p.value = ''; 
            refrescarGUICarritoConsultas();
        }
        
        function agregarAlCarritoConsultas(id) {
            const it = catalogoMasterConsultas.find(x => x.id === id); if(!it) return;
            let ex = carritoLocalConsultas.find(x => x.id === id);
            if(ex) {
                ex.cantidad++;
            } else {
                carritoLocalConsultas.push({ id: it.id, nombre: it.nombre, precio: parseFloat(it.precio), cantidad: 1 });
            }
            refrescarGUICarritoConsultas();
        }
        
        function refrescarGUICarritoConsultas() {
            const uli = document.getElementById('listaCarritoConsultas'); if(!uli) return;
            uli.innerHTML = carritoLocalConsultas.length === 0 ? '<div class="text-center py-4 text-muted fw-bold small">El carrito está vacío.</div>' : '';
            let total = 0;
            carritoLocalConsultas.forEach((c, i) => {
                const st = c.precio * c.cantidad; total += st;
                uli.innerHTML += `
                    <div class="bg-light p-2 rounded-3 border mb-2 d-flex justify-content-between align-items-center">
                        <div class="lh-sm" style="max-width:60%;">
                            <span class="fw-bold text-dark text-truncate d-block small">\${c.nombre}</span>
                            <small class="text-muted">\$\${c.precio.toFixed(2)} c/u</small>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                            <div class="d-flex align-items-center gap-1 bg-white rounded-pill px-2 py-0 border shadow-sm">
                                <button type="button" class="btn btn-sm btn-light rounded-circle p-1 d-flex align-items-center justify-content-center" style="width: 20px; height: 20px;" onclick="updateLocalCartQty(\${i}, -1)"><i class="bi bi-dash"></i></button>
                                <span class="fw-bold px-1" style="font-size:0.85rem;">\${c.cantidad}</span>
                                <button type="button" class="btn btn-sm btn-light rounded-circle p-1 d-flex align-items-center justify-content-center" style="width: 20px; height: 20px;" onclick="updateLocalCartQty(\${i}, 1)"><i class="bi bi-plus"></i></button>
                            </div>
                            <span class="fw-bold text-navy small" style="min-width: 60px; text-align:right;">\$\${st.toFixed(2)}</span>
                            <button type="button" class="btn btn-sm btn-outline-danger border-0 p-1" onclick="removeLocalCartItem(\${i})"><i class="bi bi-trash"></i></button>
                        </div>
                    </div>`;
            });
            const tv = document.getElementById('carritoTotalConsultas');
            if (tv) tv.innerText = '\$' + total.toFixed(2);
        }
        
        function updateLocalCartQty(idx, delta) {
            if (carritoLocalConsultas[idx].cantidad + delta <= 0) {
                carritoLocalConsultas.splice(idx, 1);
            } else {
                carritoLocalConsultas[idx].cantidad += delta;
            }
            refrescarGUICarritoConsultas();
        }
        
        function removeLocalCartItem(idx) {
            carritoLocalConsultas.splice(idx, 1);
            refrescarGUICarritoConsultas();
        }
        
        function confirmarCargosConsultas() {
            carritoConsulta = JSON.parse(JSON.stringify(carritoLocalConsultas)); // Guardar
            cargarCajaDesdeRegistro();
            
            const modalEl = document.getElementById('modalCargoConsultas');
            if (modalEl) {
                const m = bootstrap.Modal.getInstance(modalEl);
                if (m) m.hide();
            }
        }
        
        function removerCargoDirecto(idx) {
            carritoConsulta.splice(idx, 1);
            cargarCajaDesdeRegistro();
        }
        
        function cargarCajaDesdeRegistro() {
            const cotSelect = document.getElementById('f_id_cotizacion');
            const convertirCheck = document.getElementById('f_convertir_tratamiento');
            
            const noCotCard = document.getElementById('caja-no-cotizacion');
            const workflowCont = document.getElementById('caja-workflow-container');
            
            const isTratamientoActivo = historialTratamiento && historialTratamiento.tiene_tratamiento;
            const isNuevaConversion = cotSelect && cotSelect.value && convertirCheck && convertirCheck.checked;
            
            // Banner de Detección de Cobro Anticipado en Recepción
            const tienePrePagoRecepcion = (historialTratamiento && historialTratamiento.abonos && historialTratamiento.abonos.some(a => (a.concepto||'').includes('Recepción') || (a.concepto||'').includes('Recepcion')));
            let alertPrePago = document.getElementById('caja-prepago-alert');
            if (tienePrePagoRecepcion) {
                if (!alertPrePago) {
                    alertPrePago = document.createElement('div');
                    alertPrePago.id = 'caja-prepago-alert';
                    alertPrePago.className = 'alert alert-success border-0 rounded-4 shadow-sm mb-4 p-3 d-flex align-items-center';
                    alertPrePago.innerHTML = `<i class="bi bi-check-circle-fill fs-3 text-success me-3"></i><div><h6 class="fw-bold mb-0" style="color: #065f46;"><i class="bi bi-shield-check me-1"></i>Consulta Pagada en Recepción</h6><p class="small mb-0 text-success-emphasis">El pago por concepto de consulta ya fue cobrado e ingresado en Recepción. Saldo pendiente $0.00.</p></div>`;
                    if (workflowCont) workflowCont.insertBefore(alertPrePago, workflowCont.firstChild);
                }
            } else if (alertPrePago) {
                alertPrePago.remove();
            }

            // Si la cotización en Step Registro es ninguna/vacía, por default seleccionar 'Cerrado' (Alta médica)
            if (!cotSelect || !cotSelect.value || cotSelect.value === 'ninguna' || cotSelect.value === '') {
                const estadoTratSelect = document.getElementById('f_caja_estado_tratamiento');
                if (estadoTratSelect && (!estadoTratSelect.dataset.userChanged)) {
                    estadoTratSelect.value = 'Cerrado';
                }
            }

            // Precargar concepto de Consulta Médica base ($500.00) por regla financiera si está vacío (salvo si ya fue pagado en Recepción)
            if (!isTratamientoActivo && !isNuevaConversion && !tienePrePagoRecepcion && (!carritoConsulta || carritoConsulta.length === 0)) {
                const espeInput = document.querySelector('[name="especialidad"]');
                const espeNombre = (espeInput && espeInput.value) ? espeInput.value : 'General';
                carritoConsulta = [{ id: 'CONS-BASE', nombre: 'Consulta Médica (' + espeNombre + ')', precio: 500.00, cantidad: 1 }];
            }

            const tieneCargosDirectos = carritoConsulta && carritoConsulta.length > 0;
            const tieneHistorialCaja = historialTratamiento && ((historialTratamiento.cargos && historialTratamiento.cargos.length > 0) || (historialTratamiento.abonos && historialTratamiento.abonos.length > 0));
            
            if (isTratamientoActivo || isNuevaConversion || tieneCargosDirectos || tienePrePagoRecepcion || tieneHistorialCaja) {
                noCotCard.style.display = 'none';
                workflowCont.style.display = 'block';
                
                const tbody = document.getElementById('caja-tbody-items');
                tbody.innerHTML = '';
                
                let subtotalAcumulado = 0;
                
                // 1. Mostrar Cargos del tratamiento activo / Cobros de Recepción
                if (isTratamientoActivo || tieneHistorialCaja) {
                    historialTratamiento.cargos.forEach(it => {
                        tbody.innerHTML += `
                            <tr>
                                <td><span class="fw-bold text-dark text-uppercase small" style="letter-spacing:0.3px;">\${it.concepto}</span></td>
                                <td class="text-end fw-semibold">\$\${it.total.toFixed(2)}</td>
                                <td class="text-center fw-bold text-muted">1</td>
                                <td class="text-end fw-black text-navy">\$\${it.total.toFixed(2)}</td>
                            </tr>
                        `;
                    });
                    
                    if (historialTratamiento.abonos.length > 0) {
                        tbody.innerHTML += `
                            <tr class="table-light">
                                <td colspan="3" class="text-end fw-bold text-uppercase small text-success">Total Cargos del Tratamiento</td>
                                <td class="text-end fw-bold text-success">\$\${historialTratamiento.total_cargos.toFixed(2)}</td>
                            </tr>
                        `;
                        
                        historialTratamiento.abonos.forEach(ab => {
                            tbody.innerHTML += `
                                <tr class="text-success small">
                                    <td><i class="bi bi-arrow-return-right me-2"></i>\${ab.concepto} (Fecha: \${ab.fecha})</td>
                                    <td colspan="2"></td>
                                    <td class="text-end fw-bold text-success">-\$\${ab.total.toFixed(2)}</td>
                                </tr>
                            `;
                        });
                    }
                    subtotalAcumulado = historialTratamiento.saldo_pendiente;
                }
                
                // 2. Mostrar Cargos de nueva cotización
                if (isNuevaConversion) {
                    const idCot = cotSelect.value;
                    const cot = cotizacionesData[idCot];
                    if (cot) {
                        cot.items.forEach(it => {
                            tbody.innerHTML += `
                                <tr>
                                    <td><span class="fw-bold text-dark text-uppercase small" style="letter-spacing:0.3px;">\${it.concepto}</span></td>
                                    <td class="text-end fw-semibold">\$\${it.precio.toFixed(2)}</td>
                                    <td class="text-center fw-bold text-muted">\${it.cantidad}</td>
                                    <td class="text-end fw-black text-navy">\$\${it.subtotal.toFixed(2)}</td>
                                </tr>
                            `;
                        });
                        subtotalAcumulado = cot.total;
                    }
                }
                
                // 3. Mostrar Cargos Directos (Carrito de Consulta)
                if (tieneCargosDirectos) {
                    tbody.innerHTML += `
                        <tr class="table-secondary">
                            <td colspan="4" class="fw-bold text-navy py-2"><i class="bi bi-plus-circle-fill me-2 text-primary"></i>Conceptos Adicionales / Directos</td>
                        </tr>
                    `;
                    
                    carritoConsulta.forEach((c, idx) => {
                        const itemSub = c.precio * c.cantidad;
                        subtotalAcumulado += itemSub;
                        tbody.innerHTML += `
                            <tr>
                                <td>
                                    <span class="fw-bold text-dark text-uppercase small" style="letter-spacing:0.3px;">\${c.nombre}</span>
                                    <button type="button" class="btn btn-link text-danger p-0 ms-2" onclick="removerCargoDirecto(\${idx})" title="Eliminar cargo"><i class="bi bi-trash small"></i></button>
                                </td>
                                <td class="text-end fw-semibold">\$\${c.precio.toFixed(2)}</td>
                                <td class="text-center fw-bold text-muted">\${c.cantidad}</td>
                                <td class="text-end fw-black text-navy">\$\${itemSub.toFixed(2)}</td>
                            </tr>
                        `;
                    });
                }
                
                // 4. Agregar fila de total acumulado
                let labelTotal = "Total a Cobrar";
                if (isTratamientoActivo || tieneHistorialCaja) {
                    labelTotal = "Saldo Restante + Conceptos Adicionales";
                } else if (isNuevaConversion) {
                    labelTotal = "Total (Cotización + Adicionales)";
                }
                
                tbody.innerHTML += `
                    <tr class="table-warning border-top-2">
                        <td colspan="3" class="text-end fw-black text-uppercase small">\${labelTotal}</td>
                        <td class="text-end fw-black text-danger fs-6">\$\${subtotalAcumulado.toFixed(2)}</td>
                    </tr>
                `;
                
                // Guardar JSON en input oculto
                document.getElementById('f_caja_items_json').value = JSON.stringify(carritoConsulta);
                
                // Actualizar inputs de caja
                actualizarMontoPago();
            } else {
                noCotCard.style.display = 'block';
                workflowCont.style.display = 'none';
                document.getElementById('f_caja_items_json').value = '[]';
            }
            
            toggleCitaWorkflow();
        }
        
        function actualizarMontoPago() {
            const cotSelect = document.getElementById('f_id_cotizacion');
            const tipoPago = document.getElementById('f_caja_tipo_pago').value;
            const montoInput = document.getElementById('f_caja_monto_abono');
            
            const isTratamientoActivo = historialTratamiento && historialTratamiento.tiene_tratamiento;
            const isNuevaConversion = cotSelect && cotSelect.value;
            
            let totalAcumulado = 0;
            if (isTratamientoActivo || tieneHistorialCaja) {
                totalAcumulado = historialTratamiento.saldo_pendiente;
            } else if (isNuevaConversion) {
                const idCot = cotSelect.value;
                const cot = cotizacionesData[idCot];
                if (cot) totalAcumulado = cot.total;
            }
            
            // Sumar carritoConsulta
            if (carritoConsulta && carritoConsulta.length > 0) {
                carritoConsulta.forEach(c => {
                    totalAcumulado += c.precio * c.cantidad;
                });
            }
            
            const estadoTrat = document.getElementById('f_caja_estado_tratamiento') ? document.getElementById('f_caja_estado_tratamiento').value : '';
            
            if (estadoTrat === 'Cobro por recepción') {
                montoInput.value = '0.00';
                montoInput.readOnly = true;
            } else if (tipoPago === 'Liquidar') {
                montoInput.value = totalAcumulado.toFixed(2);
                montoInput.readOnly = true;
            } else {
                montoInput.value = '';
                montoInput.readOnly = false;
                montoInput.placeholder = "Ingrese abono parcial...";
                montoInput.focus();
            }
        }
        
        function toggleCitaWorkflow() {
            const estadoTrat = document.getElementById('f_caja_estado_tratamiento').value;
            const noReqCard = document.getElementById('cita-no-requerida');
            const reqCard = document.getElementById('cita-requerida-workflow');
            
            if (estadoTrat === 'Abierto') {
                noReqCard.style.display = 'none';
                reqCard.style.display = 'block';
            } else {
                noReqCard.style.display = 'block';
                reqCard.style.display = 'none';
            }
        }
        
        function abrirModalCitaConsulta() {
            const modalEl = document.getElementById('modalCita');
            if (modalEl) {
                if (modalEl.parentElement !== document.body) {
                    document.body.appendChild(modalEl);
                }
                
                const pNombre = "$paciente->{nombre}";
                const pId = "$paciente->{id_paciente}";
                
                const fPacienteInput = document.getElementById('f_paciente');
                const fIdPacienteInput = document.getElementById('f_id_paciente');
                
                if (fPacienteInput) fPacienteInput.value = pNombre;
                if (fIdPacienteInput) fIdPacienteInput.value = pId;
                
                const fFecha = document.getElementById('f_fecha');
                if (fFecha && !fFecha.value) {
                    const tmr = new Date();
                    tmr.setDate(tmr.getDate() + 1);
                    fFecha.value = tmr.toISOString().split('T')[0];
                }
                
                const myModal = bootstrap.Modal.getOrCreateInstance(modalEl);
                myModal.show();
                
                if (typeof renderSlots === 'function' && fFecha) {
                    renderSlots(fFecha.value);
                }
            }
        }
        
        window.onCitaAgendadaExito = function(idCita, fecha, hora) {
            const citaIdInput = document.getElementById('f_proxima_cita_id');
            const statusCard = document.getElementById('cita-status-card');
            const statusIcon = document.getElementById('cita-status-icon');
            const statusText = document.getElementById('cita-status-text');
            const statusDetail = document.getElementById('cita-status-detail');
            
            if (citaIdInput) {
                citaIdInput.value = idCita;
                
                statusCard.classList.remove('bg-light');
                statusCard.classList.add('bg-success-subtle', 'border-success');
                statusIcon.className = 'bi bi-calendar-check-fill fs-2 text-success';
                statusText.innerText = "¡Cita Programada!";
                statusDetail.innerHTML = `Fecha: <strong>\${fecha}</strong><br>Hora: <strong>\${hora}</strong><br><small class="text-muted">(ID Cita: \${idCita})</small>`;
                
                const modalEl = document.getElementById('modalCita');
                if (modalEl) {
                    const m = bootstrap.Modal.getInstance(modalEl);
                    if (m) m.hide();
                }
                
                Swal.fire({
                    icon: 'success',
                    title: 'Cita Agendada',
                    text: `La próxima cita se programó para el \${fecha} a las \${hora}.`,
                    timer: 2500,
                    showConfirmButton: false
                });
            }
        };
        
        function validarPasoCajaYContinuar() {
            const cotSelect = document.getElementById('f_id_cotizacion');
            const convertirCheck = document.getElementById('f_convertir_tratamiento');
            
            const isTratamientoActivo = historialTratamiento && historialTratamiento.tiene_tratamiento;
            const isNuevaConversion = cotSelect && cotSelect.value && convertirCheck && convertirCheck.checked;
            const tieneCargosDirectos = carritoConsulta && carritoConsulta.length > 0;
            
            if (isTratamientoActivo || isNuevaConversion || tieneCargosDirectos) {
                const montoInput = document.getElementById('f_caja_monto_abono');
                const montoVal = parseFloat(montoInput.value) || 0;
                
                let maxMonto = 0;
                if (isTratamientoActivo) {
                    maxMonto = historialTratamiento.saldo_pendiente;
                } else if (isNuevaConversion) {
                    const idCot = cotSelect.value;
                    const cot = cotizacionesData[idCot];
                    if (cot) maxMonto = cot.total;
                }
                
                if (carritoConsulta && carritoConsulta.length > 0) {
                    carritoConsulta.forEach(c => {
                        maxMonto += c.precio * c.cantidad;
                    });
                }
                
                if (montoVal < 0) {
                    Swal.fire('Atención', 'Por favor, ingrese un monto de abono válido.', 'warning');
                    return;
                }
                if (montoVal > maxMonto) {
                    Swal.fire('Atención', `El monto a pagar (\$\${montoVal.toFixed(2)}) no puede ser mayor al saldo pendiente (\$\${maxMonto.toFixed(2)}).`, 'warning');
                    return;
                }
                
                const estadoTrat = document.getElementById('f_caja_estado_tratamiento').value;
                const citaId = document.getElementById('f_proxima_cita_id').value;
                
                if (estadoTrat === 'Abierto' && !citaId) {
                    Swal.fire('Cita Requerida', 'Es obligatorio agendar la próxima cita de seguimiento para dejar el tratamiento abierto.', 'warning');
                    return;
                }
            }
            
            WizardController.nextStep();
        }
        </script>
    };
}
1;
