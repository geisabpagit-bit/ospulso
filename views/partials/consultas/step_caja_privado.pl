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
    
    # 4. Cargar cargos y abonos del tratamiento activo
    my @cargos = ();
    my @abonos = ();
    my $total_cargos = 0;
    my $total_abonos = 0;
    
    my $fin_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
    if ($tiene_tratamiento && -e $fin_file && open(my $fh_f, '<:encoding(UTF-8)', $fin_file)) {
        my $header = <$fh_f>;
        while (my $line = <$fh_f>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            next unless @c >= 8;
            if ($c[0] eq $id_tratamiento_activo) {
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
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-wallet2 me-2" style="color: var(--md-teal-clinical);"></i>Caja y Registro de Pago
            </h3>
            
            <div id="caja-no-cotizacion" class="text-center py-5 border rounded-4 bg-light mb-4">
                <i class="bi bi-info-circle text-muted fs-1 mb-3 d-block"></i>
                <h5 class="fw-bold text-muted">No se seleccion&oacute; ninguna cotizaci&oacute;n</h5>
                <p class="text-muted small">Avance al paso de cierre para finalizar la consulta.</p>
            </div>
            
            <div id="caja-workflow-container" style="display: none;">
                <!-- Conceptos de la Cotización -->
                <div class="card border-0 shadow-sm rounded-4 p-4 mb-4" style="border: 1px solid rgba(25, 183, 165, 0.2) !important;">
                    <h5 class="fw-black text-navy mb-3"><i class="bi bi-cart3 me-2" style="color: var(--md-teal-clinical);"></i>Conceptos a Cobrar</h5>
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
        
        <script>
        const cotizacionesData = $json_cots;
        const historialTratamiento = $json_historial;
        
        function cargarCajaDesdeRegistro() {
            const cotSelect = document.getElementById('f_id_cotizacion');
            const convertirCheck = document.getElementById('f_convertir_tratamiento');
            
            const noCotCard = document.getElementById('caja-no-cotizacion');
            const workflowCont = document.getElementById('caja-workflow-container');
            
            if (historialTratamiento && historialTratamiento.tiene_tratamiento) {
                // Flujo con Tratamiento Activo existente
                noCotCard.style.display = 'none';
                workflowCont.style.display = 'block';
                
                // Cargar cargos en la tabla
                const tbody = document.getElementById('caja-tbody-items');
                tbody.innerHTML = '';
                
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
                
                // Si hay abonos anteriores, desplegarlos en la tabla
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
                
                // Agregar fila de saldo pendiente
                tbody.innerHTML += `
                    <tr class="table-warning border-top-2">
                        <td colspan="3" class="text-end fw-black text-uppercase small">Saldo Pendiente a Abonar/Liquidar</td>
                        <td class="text-end fw-black text-danger fs-6">\$\${historialTratamiento.saldo_pendiente.toFixed(2)}</td>
                    </tr>
                `;
                
                // Actualizar inputs
                actualizarMontoPago();
                
            } else if (cotSelect && cotSelect.value && convertirCheck && convertirCheck.checked) {
                noCotCard.style.display = 'none';
                workflowCont.style.display = 'block';
                
                const idCot = cotSelect.value;
                const cot = cotizacionesData[idCot];
                if (cot) {
                    // Cargar items en la tabla
                    const tbody = document.getElementById('caja-tbody-items');
                    tbody.innerHTML = '';
                    
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
                    
                    // Agregar fila de total
                    tbody.innerHTML += `
                        <tr class="table-light">
                            <td colspan="3" class="text-end fw-bold text-uppercase small">Total de la Cotizaci&oacute;n</td>
                            <td class="text-end fw-black text-danger fs-6">\$\${cot.total.toFixed(2)}</td>
                        </tr>
                    `;
                    
                    // Actualizar inputs
                    actualizarMontoPago();
                }
            } else {
                noCotCard.style.display = 'block';
                workflowCont.style.display = 'none';
            }
            
            toggleCitaWorkflow();
        }
        
        function actualizarMontoPago() {
            const cotSelect = document.getElementById('f_id_cotizacion');
            const tipoPago = document.getElementById('f_caja_tipo_pago').value;
            const montoInput = document.getElementById('f_caja_monto_abono');
            
            let maxMonto = 0;
            if (historialTratamiento && historialTratamiento.tiene_tratamiento) {
                maxMonto = historialTratamiento.saldo_pendiente;
            } else if (cotSelect && cotSelect.value) {
                const idCot = cotSelect.value;
                const cot = cotizacionesData[idCot];
                if (cot) maxMonto = cot.total;
            }
            
            if (tipoPago === 'Liquidar') {
                montoInput.value = maxMonto.toFixed(2);
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
                
                const myModal = new bootstrap.Modal(modalEl);
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
            
            if (isTratamientoActivo || isNuevaConversion) {
                const montoInput = document.getElementById('f_caja_monto_abono');
                const montoVal = parseFloat(montoInput.value) || 0;
                
                let maxMonto = 0;
                if (isTratamientoActivo) {
                    maxMonto = historialTratamiento.saldo_pendiente;
                } else {
                    const idCot = cotSelect.value;
                    const cot = cotizacionesData[idCot];
                    if (cot) maxMonto = cot.total;
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
