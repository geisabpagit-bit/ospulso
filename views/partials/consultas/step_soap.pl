use strict;
use warnings;
use utf8;
use File::Spec;

sub render_step_soap {
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
                
                <!-- Diagnóstico CIE-10 Autocomplete -->
                <div class="col-md-12">
                    <div class="form-group">
                        <label class="wizard-label">Diagn&oacute;stico CIE-10 (Buscador) <span class="req-star">*</span></label>
                        <div class="position-relative">
                            <input type="text" id="cie10_search" class="wizard-input border-primary" placeholder="Escribe al menos 2 caracteres para buscar en CIE-10..." autocomplete="off">
                            <div id="cie10_results" class="list-group position-absolute w-100 shadow rounded-3 mt-1" style="z-index: 1050; display: none; max-height: 250px; overflow-y: auto; background: white;"></div>
                        </div>
                    </div>
                </div>

                <div class="col-md-8">
                    <div class="form-group">
                        <label class="wizard-label">Diagn&oacute;stico Seleccionado <span class="req-star">*</span></label>
                        <input type="text" name="diagnostico_principal" id="diagnostico_principal" class="wizard-input bg-light border-secondary" readonly placeholder="Ninguno seleccionado..." required>
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
                
                <div class="col-12 mt-4">
                    <label class="wizard-label">Impresi&oacute;n Cl&iacute;nica (Assessment) <span class="req-star">*</span></label>
                    <textarea name="impresion_clinica" class="wizard-input" rows="4" placeholder="An&aacute;lisis m&eacute;dico, diagn&oacute;stico diferencial y razonamiento..." required></textarea>
                </div>
                
                <div class="col-12 mt-4">
                    <label class="wizard-label">Plan de Tratamiento y Abordaje Clínico (Plan) <span class="req-star">*</span></label>
                    <textarea name="plan_tratamiento" class="wizard-input" rows="5" placeholder="Medidas generales, seguimiento, interconsultas..." required></textarea>
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
            </script>
        </div>
    };
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
