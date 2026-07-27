use strict;
use warnings;
use utf8;
use File::Spec;

sub render_step_soap {
    my ($paciente) = @_;
    my $cedula_medico = ($paciente && ref($paciente) eq 'HASH') ? ($paciente->{cedula_medico} // '') : '';

    my $cif1_options = cargar_opciones_dat('CAT_CIF_1erNivel.dat', 1);
    my $cif2_options = cargar_opciones_dat('CAT_CIF_2oNivel.dat', 1);
    my $cif3_options = cargar_opciones_dat('CAT_CIF_3erNivel.dat', 1);
    my $cif4_options = cargar_opciones_dat('CAT_CIF_4oNivel.dat', 1);
    
    my $calfunc_options = cargar_opciones_dat('CAT_CIF_CALFUNC.dat', 1);
    my $calestruc_options = cargar_opciones_dat('CAT_CIF_CALESTRUC.dat', 1);
    my $calactpart_options = cargar_opciones_dat('CAT_CIF_CALACTPART.dat', 1);
    my $calamb_options = cargar_opciones_dat('CAT_CIF_CALAMB.dat', 1);

    return qq{
        <div class="wizard-panel" id="step-panel-4">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-diagram-3 me-2" style="color: var(--md-teal-clinical);"></i>Estructura S.O.A.P.
            </h3>
            
            <div class="row g-4">
                <div class="col-12">
                    <p class="text-muted mb-4 fw-bold">An&aacute;lisis (Assessment) y Diagn&oacute;stico. El Subjetivo y Objetivo se consolidan autom&aacute;ticamente a partir de los pasos anteriores.</p>
                </div>
                
                <div class="col-12 mb-2">
                    <div class="card border-0 bg-light p-3 rounded-4 shadow-sm">
                        <div class="form-check form-switch fs-5 m-0 d-flex align-items-center gap-2">
                            <input class="form-check-input my-0" type="checkbox" role="switch" id="check_usar_cie10" name="usar_cie10" value="1" onchange="toggleSeccionCIE10(this.checked)">
                            <label class="form-check-label fs-6 fw-bold text-navy my-0" for="check_usar_cie10">¿Utilizar el catálogo oficial Diagnóstico CIE-10 / Valoración CIF?</label>
                        </div>
                    </div>
                </div>

                <!-- Campos de Diagnóstico CIE-10 y CIF (Ocultos por defecto) -->
                <div id="seccion-cie10-cif" class="col-12 p-0" style="display: none;">
                    <div class="row g-4 m-0">
                        <!-- Diagnóstico CIE-10 Autocomplete -->
                        <div class="col-md-12">
                            <div class="form-group">
                                <label class="wizard-label">Diagn&oacute;stico CIE-10 (Buscador)</label>
                                <div class="position-relative">
                                    <input type="text" id="cie10_search" class="wizard-input border-primary" placeholder="Escribe al menos 2 caracteres para buscar en CIE-10..." autocomplete="off">
                                    <div id="cie10_results" class="list-group position-absolute w-100 shadow rounded-3 mt-1" style="z-index: 1050; display: none; max-height: 250px; overflow-y: auto; background: white;"></div>
                                </div>
                            </div>
                        </div>

                        <div class="col-md-8">
                            <div class="form-group">
                                <label class="wizard-label">Diagn&oacute;stico Seleccionado</label>
                                <input type="text" name="diagnostico_principal" id="diagnostico_principal" class="wizard-input bg-light border-secondary" readonly placeholder="Ninguno seleccionado...">
                                <input type="hidden" name="clave_diagnostico_cie10" id="clave_diagnostico_cie10">
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="form-group">
                                <label class="wizard-label">Severidad</label>
                                <select name="severidad" class="wizard-input">
                                    <option value="Leve">Leve</option>
                                    <option value="Moderada">Moderada</option>
                                    <option value="Grave">Grave</option>
                                </select>
                            </div>
                        </div>

                        <!-- Evaluación Funcional CIF -->
                        <div class="col-12 mt-4">
                            <h5 class="fw-bold mb-3 text-secondary"><i class="bi bi-person-wheelchair me-2"></i>Valoración Funcional CIF</h5>
                            
                            <!-- Nivel 1 -->
                            <div class="row g-3 border rounded-3 p-3 mb-3 bg-light">
                                <div class="col-12"><span class="badge bg-primary">Nivel 1: Funciones Corporales (b) / Estructuras (s) / Actividades (d) / Entorno (e)</span></div>
                                <div class="col-md-8">
                                    <label class="wizard-label">Código CIF Nivel 1</label>
                                    <select name="cif_nivel1" class="wizard-input">
                                        $cif1_options
                                    </select>
                                </div>
                                <div class="col-md-4">
                                    <label class="wizard-label">Calificador (Funciones)</label>
                                    <select name="cif_calif1" class="wizard-input">
                                        $calfunc_options
                                    </select>
                                </div>
                            </div>

                            <!-- Nivel 2 -->
                            <div class="row g-3 border rounded-3 p-3 mb-3 bg-light">
                                <div class="col-12"><span class="badge bg-secondary">Nivel 2: Detalle de Capítulo</span></div>
                                <div class="col-md-8">
                                    <label class="wizard-label">Código CIF Nivel 2</label>
                                    <select name="cif_nivel2" class="wizard-input">
                                        $cif2_options
                                    </select>
                                </div>
                                <div class="col-md-4">
                                    <label class="wizard-label">Calificador (Estructuras)</label>
                                    <select name="cif_calif2" class="wizard-input">
                                        $calestruc_options
                                    </select>
                                </div>
                            </div>

                            <!-- Nivel 3 -->
                            <div class="row g-3 border rounded-3 p-3 mb-3 bg-light">
                                <div class="col-12"><span class="badge bg-info text-dark">Nivel 3: Categoría Específica</span></div>
                                <div class="col-md-8">
                                    <label class="wizard-label">Código CIF Nivel 3</label>
                                    <select name="cif_nivel3" class="wizard-input">
                                        $cif3_options
                                    </select>
                                </div>
                                <div class="col-md-4">
                                    <label class="wizard-label">Calificador (Actividades y Participación)</label>
                                    <select name="cif_calif3" class="wizard-input">
                                        $calactpart_options
                                    </select>
                                </div>
                            </div>

                            <!-- Nivel 4 -->
                            <div class="row g-3 border rounded-3 p-3 mb-3 bg-light">
                                <div class="col-12"><span class="badge bg-dark">Nivel 4: Subcategoría Detallada</span></div>
                                <div class="col-md-8">
                                    <label class="wizard-label">Código CIF Nivel 4</label>
                                    <select name="cif_nivel4" class="wizard-input">
                                        $cif4_options
                                    </select>
                                </div>
                                <div class="col-md-4">
                                    <label class="wizard-label">Calificador (Entorno/Ambiental)</label>
                                    <select name="cif_calif4" class="wizard-input">
                                        $calamb_options
                                    </select>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="col-12 mt-4">
                    <label class="wizard-label">Impresi&oacute;n Cl&iacute;nica (Assessment) <span class="req-star">*</span></label>
                    <textarea name="impresion_clinica" class="wizard-input" rows="4" placeholder="An&aacute;lisis m&eacute;dico, diagn&oacute;stico diferencial y razonamiento..." required></textarea>
                </div>
                
                <div class="col-12 mt-4">
                    <label class="wizard-label">Plan de Tratamiento y Abordaje Clínico (Plan) <span class="req-star">*</span></label>
                    <textarea name="plan_tratamiento" class="wizard-input" rows="4" placeholder="Medidas generales, seguimiento, interconsultas..." required></textarea>
                </div>

                <!-- Módulo de Prescripción: Receta Médica Oficial (NOM-004-SSA3 / NOM-024-SSA3) -->
                <div class="col-12 mt-4">
                    <div class="card-medentia-aura border-0 bg-white p-4 rounded-4 shadow-sm">
                        <div class="d-flex align-items-center justify-content-between mb-3">
                            <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">
                                <i class="bi bi-capsule-prescription me-2 text-primary"></i>Expedición de Receta Médica
                            </h5>
                            <div class="form-check form-switch fs-5">
                                <input class="form-check-input" type="checkbox" role="switch" id="check_requiere_receta" name="requiere_receta" value="1" onchange="toggleSeccionReceta(this.checked)">
                                <label class="form-check-label fs-6 fw-bold text-muted" for="check_requiere_receta">¿Expedir Receta Médica?</label>
                            </div>
                        </div>

                        <div id="seccion-receta-medica" style="display: none;">
                            <input type="hidden" name="receta_json" id="receta_json_input" value="[]">
                            
                            <div class="alert alert-info bg-info bg-opacity-10 border-info border-opacity-25 rounded-3 mb-4 p-3 d-flex align-items-center gap-2">
                                <i class="bi bi-info-circle-fill text-info fs-4"></i>
                                <div class="small">
                                    <strong>Receta Médica Oficial COFEPRIS</strong>: Selecciona medicamentos del catálogo <code>productos.dat</code> o agrega prescripciones personalizadas.
                                </div>
                            </div>

                            <!-- Buscador y Selección de Productos -->
                            <div class="row g-3 mb-4">
                                <div class="col-md-7">
                                    <label class="wizard-label">Buscar Medicamento en Catálogo (productos.dat)</label>
                                    <select id="select_producto_receta" class="wizard-input" onchange="seleccionarProductoReceta(this.value)">
                                        @{[ cargar_opciones_productos() ]}
                                    </select>
                                </div>
                                <div class="col-md-5 d-flex align-items-end">
                                    <button type="button" class="btn btn-outline-primary rounded-pill px-4 fw-bold w-100" onclick="agregarMedicamentoRecetaManual()">
                                        <i class="bi bi-plus-circle me-2"></i>Agregar Prescripción Personalizada
                                    </button>
                                </div>
                            </div>

                            <!-- Tabla de Prescripciones -->
                            <div class="table-responsive mb-3">
                                <table class="table table-bordered table-hover align-middle">
                                    <thead class="table-light small text-uppercase fw-bold">
                                        <tr>
                                            <th>Medicamento (Genérico / Comercial)</th>
                                            <th>Forma Farmacéutica</th>
                                            <th>Dosis / Concentración</th>
                                            <th>Posología (Frecuencia / Duración)</th>
                                            <th>Vía Admin.</th>
                                            <th class="text-center" style="width: 50px;">Acción</th>
                                        </tr>
                                    </thead>
                                    <tbody id="tbody-receta-items">
                                        <tr><td colspan="6" class="text-center py-4 text-muted small">No hay medicamentos en la receta. Selecciona del catálogo o presiona "Agregar Prescripción Personalizada".</td></tr>
                                    </tbody>
                                </table>
                            </div>

                            <div class="row g-3">
                                <div class="col-md-3">
                                    <label class="wizard-label">Folio de Control de Receta</label>
                                    <input type="text" name="receta_folio" id="receta_folio_input" class="wizard-input bg-light fw-bold" readonly>
                                </div>
                                <div class="col-md-3">
                                    <label class="wizard-label">Cédula Profesional Médico</label>
                                    <input type="text" class="wizard-input bg-light fw-bold text-primary" readonly value="$cedula_medico" placeholder="No registrada en perfil">
                                </div>
                                <div class="col-md-6">
                                    <label class="wizard-label">Indicaciones / Advertencias Generales</label>
                                    <input type="text" name="receta_indicaciones_extra" class="wizard-input" placeholder="Ej: Tomar con abundante agua. Evitar consumo de alcohol durante el tratamiento.">
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Comunicaci&oacute;n <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
            
            <script>
            document.addEventListener('DOMContentLoaded', () => {
                const searchInput = document.getElementById('cie10_search');
                const resultsDiv = document.getElementById('cie10_results');
                const diagInput = document.getElementById('diagnostico_principal');
                const codeInput = document.getElementById('clave_diagnostico_cie10');
                
                if (searchInput) {
                    searchInput.addEventListener('input', async function() {
                        const q = this.value.trim();
                        if (q.length < 2) {
                            resultsDiv.style.display = 'none';
                            return;
                        }
                        
                        try {
                            const res = await fetch('../api/buscar_cie10.pl?q=' + encodeURIComponent(q));
                            const data = await res.json();
                            
                            if (data.length > 0) {
                                let html = '';
                                data.forEach(item => {
                                    html += `<button type="button" class="list-group-item list-group-item-action py-2 text-start select-cie10-item" data-id="\${item.id}" data-text="\${item.text}">
                                        <span class="badge bg-secondary me-2">\${item.id}</span> \${item.text}
                                    </button>`;
                                });
                                resultsDiv.innerHTML = html;
                                resultsDiv.style.display = 'block';
                                
                                // Bind click
                                document.querySelectorAll('.select-cie10-item').forEach(btn => {
                                    btn.addEventListener('click', function() {
                                        const code = this.getAttribute('data-id');
                                        const text = this.getAttribute('data-text');
                                        diagInput.value = text;
                                        codeInput.value = code;
                                        resultsDiv.style.display = 'none';
                                        searchInput.value = '';
                                    });
                                });
                            } else {
                                resultsDiv.innerHTML = '<div class="list-group-item text-muted">No se encontraron resultados</div>';
                                resultsDiv.style.display = 'block';
                            }
                        } catch(e) {
                            console.error('Error fetching CIE-10 data:', e);
                        }
                    });
                    
                    // Close on click outside
                    document.addEventListener('click', function(e) {
                        if (e.target !== searchInput && e.target !== resultsDiv) {
                            resultsDiv.style.display = 'none';
                        }
                    });
                }
            });

            // Lógica JS de CIE-10 Toggle
            function toggleSeccionCIE10(checked) {
                const sec = document.getElementById('seccion-cie10-cif');
                const diagInput = document.getElementById('diagnostico_principal');
                if (sec) {
                    sec.style.display = checked ? 'block' : 'none';
                }
                if (diagInput) {
                    if (checked) {
                        diagInput.setAttribute('required', 'required');
                    } else {
                        diagInput.removeAttribute('required');
                        diagInput.classList.remove('is-invalid');
                    }
                }
            }

            // Lógica JS de Receta Médica
            let recetaItems = [];

            function toggleSeccionReceta(checked) {
                const sec = document.getElementById('seccion-receta-medica');
                if (sec) {
                    sec.style.display = checked ? 'block' : 'none';
                }
                if (checked && !document.getElementById('receta_folio_input').value) {
                    const now = new Date();
                    const folio = 'REC-' + now.getFullYear() + String(now.getMonth()+1).padStart(2,'0') + String(now.getDate()).padStart(2,'0') + '-' + Math.floor(Math.random()*9000 + 1000);
                    document.getElementById('receta_folio_input').value = folio;
                }
            }

            function seleccionarProductoReceta(val) {
                if (!val) return;
                const parts = val.split('|');
                if (parts.length >= 2) {
                    const generico = parts[1];
                    const forma = parts[2] || 'Tableta';
                    const conc = parts[3] || '500mg';
                    recetaItems.push({
                        generico: generico,
                        comercial: '',
                        forma: forma,
                        concentracion: conc,
                        posologia: '1 cada 8 horas por 7 días',
                        via: 'Oral'
                    });
                    document.getElementById('select_producto_receta').value = '';
                    renderRecetaItems();
                }
            }

            function agregarMedicamentoRecetaManual() {
                recetaItems.push({
                    generico: 'Medicamento Personalizado',
                    comercial: '',
                    forma: 'Tableta',
                    concentracion: '500mg',
                    posologia: '1 cada 8 horas por 5 días',
                    via: 'Oral'
                });
                renderRecetaItems();
            }

            function updateRecetaField(idx, field, val) {
                if (recetaItems[idx]) {
                    recetaItems[idx][field] = val;
                    syncRecetaJSON();
                }
            }

            function removeRecetaItem(idx) {
                recetaItems.splice(idx, 1);
                renderRecetaItems();
            }

            function syncRecetaJSON() {
                const input = document.getElementById('receta_json_input');
                if (input) {
                    input.value = JSON.stringify(recetaItems);
                }
            }

            function renderRecetaItems() {
                const tbody = document.getElementById('tbody-receta-items');
                if (!tbody) return;
                if (recetaItems.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="6" class="text-center py-4 text-muted small">No hay medicamentos en la receta. Selecciona del catálogo o presiona "Agregar Prescripción Personalizada".</td></tr>';
                    syncRecetaJSON();
                    return;
                }
                let html = '';
                recetaItems.forEach((it, i) => {
                    html += `<tr>
                        <td>
                            <input type="text" class="form-control form-control-sm fw-bold" value="\${it.generico}" placeholder="Nombre genérico" onchange="updateRecetaField(\${i}, 'generico', this.value)">
                            <input type="text" class="form-control form-control-sm mt-1 text-muted" value="\${it.comercial}" placeholder="Nombre comercial (opcional)" onchange="updateRecetaField(\${i}, 'comercial', this.value)">
                        </td>
                        <td>
                            <input type="text" class="form-control form-control-sm" value="\${it.forma}" placeholder="Forma (ej: Tableta)" onchange="updateRecetaField(\${i}, 'forma', this.value)">
                        </td>
                        <td>
                            <input type="text" class="form-control form-control-sm" value="\${it.concentracion}" placeholder="Dosis (ej: 500mg)" onchange="updateRecetaField(\${i}, 'concentracion', this.value)">
                        </td>
                        <td>
                            <input type="text" class="form-control form-control-sm" value="\${it.posologia}" placeholder="Posología (ej: 1 c/8h por 7 días)" onchange="updateRecetaField(\${i}, 'posologia', this.value)">
                        </td>
                        <td>
                            <select class="form-select form-select-sm" onchange="updateRecetaField(\${i}, 'via', this.value)">
                                <option value="Oral" \${it.via==='Oral'?'selected':''}>Oral</option>
                                <option value="Intramuscular" \${it.via==='Intramuscular'?'selected':''}>Intramuscular</option>
                                <option value="Intravenosa" \${it.via==='Intravenosa'?'selected':''}>Intravenosa</option>
                                <option value="Tópica" \${it.via==='Tópica'?'selected':''}>Tópica</option>
                                <option value="Oftálmica" \${it.via==='Oftálmica'?'selected':''}>Oftálmica</option>
                                <option value="Sublingual" \${it.via==='Sublingual'?'selected':''}>Sublingual</option>
                            </select>
                        </td>
                        <td class="text-center">
                            <button type="button" class="btn btn-sm btn-outline-danger border-0" onclick="removeRecetaItem(\${i})"><i class="bi bi-trash"></i></button>
                        </td>
                    </tr>`;
                });
                tbody.innerHTML = html;
                syncRecetaJSON();
            }
            </script>
        </div>
    };
}

sub cargar_opciones_productos {
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'productos.dat');
    my $options = '<option value="">Buscar en catálogo de productos.dat...</option>';
    if (open(my $fh, '<:encoding(UTF-8)', $path)) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @c = split /\|/, $line, -1;
            if (@c >= 2) {
                my $id = $c[0];
                my $nom = $c[1];
                my $pres = $c[4] // '';
                my $conc = ($nom =~ /(\d+\s*(?:mg|g|ml))/i) ? $1 : '500mg';
                my $forma = 'Tableta';
                if ($pres =~ /cápsula/i) { $forma = 'Cápsula'; }
                elsif ($pres =~ /jarabe/i) { $forma = 'Jarabe'; }
                elsif ($pres =~ /efervescente/i) { $forma = 'Tableta Efervescente'; }
                $options .= qq(<option value="$id|$nom|$forma|$conc">$nom ($pres)</option>\n);
            }
        }
        close($fh);
    }
    return $options;
}

sub cargar_opciones_dat {
    my ($file_name, $has_head) = @_;
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogosOF', $file_name);
    my $options = '<option value="">Seleccione...</option>';
    if (open(my $fh, '<:encoding(UTF-8)', $path)) {
        my $header = <$fh> if $has_head;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my ($code, $desc) = split /!/, $line, 2;
            if ($code && $desc) {
                $desc =~ s/"/&quot;/g;
                $options .= qq(<option value="$code">$code - $desc</option>\n);
            }
        }
        close($fh);
    }
    return $options;
}

1;
