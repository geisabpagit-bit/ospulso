use strict;
use warnings;
use utf8;

sub render_step_registro_privado {
    my ($paciente) = @_;
    my $motivo_precargado = $paciente->{motivo_precargado} || '';
    
    # Cargar cotizaciones pendientes del paciente
    my $id_p = $paciente->{id_paciente} || '';
    my $cot_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cotizaciones.dat');
    my @cots = ();
    if (-e $cot_file && open(my $fh, '<:encoding(UTF-8)', $cot_file)) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            next unless @c >= 6;
            # ID_COT|ID_PACIENTE|NOMBRE|TOTAL|FECHA|ID_MEDICO|ESTADO
            my $cot_pac = $c[1] // '';
            my $estado = $c[6] // 'Pendiente';
            if ($cot_pac eq $id_p && $estado ne 'Convertida') {
                push @cots, {
                    id_cot => $c[0],
                    nombre => $c[2],
                    total  => $c[3] // 0,
                    fecha  => $c[4]
                };
            }
        }
        close($fh);
    }
    
    my $cot_options = qq{<option value="">Ninguna...</option>};
    foreach my $c (@cots) {
        $cot_options .= qq{<option value="$c->{id_cot}" data-total="$c->{total}">$c->{nombre} ($c->{fecha}) - \$$c->{total}</option>};
    }

    return qq{
        <div class="wizard-panel active" id="step-panel-0">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-person-badge me-2" style="color: var(--md-teal-clinical);"></i>Recepci&oacute;n y Registro (Privado)
            </h3>
            
            <div class="row g-4">
                <!-- Info Paciente Readonly -->
                <div class="col-md-6">
                    <label class="wizard-label">Paciente</label>
                    <input type="text" class="wizard-input bg-light" value="$paciente->{nombre}" readonly>
                </div>
                <div class="col-md-3">
                    <label class="wizard-label">CURP</label>
                    <input type="text" class="wizard-input bg-light" value="$paciente->{curp}" readonly>
                </div>
                <div class="col-md-3">
                    <label class="wizard-label">Sexo</label>
                    <input type="text" class="wizard-input bg-light" value="$paciente->{sexo}" readonly>
                </div>

                <!-- Selección de Cotización -->
                <div class="col-md-6">
                    <label class="wizard-label"><i class="bi bi-receipt me-1"></i>Cotizaci&oacute;n del Paciente</label>
                    <select name="id_cotizacion" id="f_id_cotizacion" class="wizard-input" onchange="toggleConversionCheckbox()">
                        $cot_options
                    </select>
                </div>
                
                <!-- Opción para Convertir a Tratamiento -->
                <div class="col-md-6 d-flex align-items-end">
                    <div class="form-check form-switch p-3 border rounded-3 w-100 bg-light" id="conversion_wrapper" style="display: none; height: 50px; align-items: center; justify-content: start;">
                        <input class="form-check-input ms-0 me-3" type="checkbox" name="convertir_tratamiento" id="f_convertir_tratamiento" value="1" onchange="toggleConversionStyle()">
                        <label class="form-check-label fw-bold text-navy" for="f_convertir_tratamiento">¿Convertir en Tratamiento Activo?</label>
                    </div>
                </div>
                
                <!-- Inputs Requeridos -->
                <div class="col-md-6">
                    <label class="wizard-label">Tipo de Consulta <span class="req-star">*</span></label>
                    <select name="tipo_consulta" class="wizard-input" required>
                        <option value="">Seleccione...</option>
                        <option value="Primera Vez">Primera Vez</option>
                        <option value="Seguimiento">Seguimiento</option>
                        <option value="Urgencia">Urgencia</option>
                    </select>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Especialidad <span class="req-star">*</span></label>
                    <select name="especialidad" class="wizard-input" required>
                        <option value="">Seleccione...</option>
                        <option value="Medicina General">Medicina General</option>
                        <option value="Odontologia">Odontolog&iacute;a</option>
                        <option value="Pediatria">Pediatr&iacute;a</option>
                    </select>
                </div>
                
                <div class="col-12">
                    <label class="wizard-label">Motivo Principal de Consulta <span class="req-star">*</span></label>
                    <textarea name="motivo" class="wizard-input" rows="4" placeholder="Describa el motivo por el cual asiste el paciente..." required>$motivo_precargado</textarea>
                </div>
            </div>
            
            <div class="d-flex justify-content-end mt-5">
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Anamnesis <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
        
        <script>
        function toggleConversionCheckbox() {
            const cotSelect = document.getElementById('f_id_cotizacion');
            const wrapper = document.getElementById('conversion_wrapper');
            const check = document.getElementById('f_convertir_tratamiento');
            
            if (cotSelect && cotSelect.value) {
                wrapper.style.display = 'flex';
                check.checked = true; // Seleccionado por defecto al elegir cotización
                toggleConversionStyle();
            } else {
                wrapper.style.display = 'none';
                check.checked = false;
                toggleConversionStyle();
            }
        }
        
        function toggleConversionStyle() {
            const check = document.getElementById('f_convertir_tratamiento');
            const wrapper = document.getElementById('conversion_wrapper');
            if (check && check.checked) {
                wrapper.style.borderColor = 'var(--md-teal-clinical)';
                wrapper.style.background = '#f0fdfa';
            } else {
                wrapper.style.borderColor = '#dee2e6';
                wrapper.style.background = '#f8fafc';
            }
        }
        </script>
    };
}
1;
