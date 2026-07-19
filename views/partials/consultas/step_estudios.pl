use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;

sub render_step_estudios {
    my ($paciente) = @_;
    my $id_paciente = $paciente->{id_paciente} || '';
    
    # Cargar estudios del paciente
    my $ESTUDIOS_FILE_PATH = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
    my $todos_estudios = -f $ESTUDIOS_FILE_PATH ? utils::db_manager::leer_tabla($ESTUDIOS_FILE_PATH, '\|') : [];
    my @estudios_pac = grep { $_->[1] eq $id_paciente } @$todos_estudios;
    
    # Construir listado HTML de estudios
    my $pacs_html = '';
    if (@estudios_pac) {
        $pacs_html .= qq{
            <div class="col-12 mt-4">
                <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-bottom: 15px;">
                    <i class="bi bi-display me-2"></i>Estudios PACS Disponibles (Gabinete / Imagenolog&iacute;a)
                </h5>
                <div class="table-responsive card-medentia-aura border-0 p-3 shadow-sm bg-white rounded-4">
                    <table class="table table-hover align-middle mb-0" id="tablaConsultaEstudiosPACS" style="width:100%">
                        <thead class="table-light">
                            <tr>
                                <th class="ps-3 border-0 rounded-start-3" style="width: 50px;">Asignar</th>
                                <th class="border-0" style="width: 80px;">Preview</th>
                                <th class="border-0" style="width: 100px;">Fecha</th>
                                <th class="border-0" style="width: 80px;">Modalidad</th>
                                <th class="border-0">Descripci&oacute;n</th>
                                <th class="border-0 text-end pe-3 rounded-end-3" style="width: 80px;">Visor</th>
                            </tr>
                        </thead>
                        <tbody class="small">
        };
        
        foreach my $est (@estudios_pac) {
            my $id_estudio = $est->[0];
            my $fecha = $est->[2];
            my $modalidad = $est->[3];
            my $desc = $est->[4];
            my $ruta = $est->[5] || '';
            
            my $mod_badge = 'bg-secondary-subtle text-secondary border border-secondary-subtle';
            if ($modalidad eq 'CT') { $mod_badge = 'bg-primary-subtle text-primary border border-primary-subtle'; }
            elsif ($modalidad eq 'XR') { $mod_badge = 'bg-info-subtle text-info border border-info-subtle'; }
            elsif ($modalidad eq 'MR') { $mod_badge = 'bg-warning-subtle text-warning border border-warning-subtle'; }
            
            # Vista previa / preview
            my $preview_html = '';
            if ($ruta =~ /\.(jpe?g|png|webp|gif)$/i) {
                # Es una imagen web legible
                $preview_html = qq{
                    <a href="../$ruta" target="_blank">
                        <img src="../$ruta" class="rounded-3 border shadow-sm" style="width: 45px; height: 45px; object-fit: cover;" alt="Preview">
                    </a>
                };
            } else {
                # Es DICOM o no tiene imagen
                $preview_html = qq{
                    <div class="d-flex align-items-center justify-content-center bg-light text-secondary rounded-3 border" style="width: 45px; height: 45px;" title="Archivo DICOM / Gabinete">
                        <i class="bi bi-file-earmark-medical" style="font-size: 1.2rem;"></i>
                    </div>
                };
            }
            
            # Sanitizar desc
            my $safe_desc = $desc;
            $safe_desc =~ s/"/\\"/g;
            $safe_desc =~ s/'/\\'/g;
            
            $pacs_html .= qq{
                            <tr>
                                <td class="ps-3 text-center">
                                    <div class="form-check form-switch d-inline-block">
                                        <input class="form-check-input pacs-chk" type="checkbox" name="pacs_estudios_seleccionados" value="$id_estudio" data-desc="$safe_desc" data-fecha="$fecha" data-mod="$modalidad" onchange="togglePacsToGabinete(this)">
                                    </div>
                                </td>
                                <td>$preview_html</td>
                                <td class="fw-bold text-muted">$fecha</td>
                                <td><span class="badge $mod_badge">$modalidad</span></td>
                                <td class="fw-bold text-dark">$desc</td>
                                <td class="text-end pe-3">
                                    <a href="render_visor_medico.pl?id=$id_paciente&estudio_id=$id_estudio" target="_blank" class="btn btn-sm btn-outline-primary rounded-circle" style="width: 32px; height: 32px; padding: 0; line-height: 30px;" title="Abrir Visor DICOM"><i class="bi bi-box-arrow-up-right"></i></a>
                                </td>
                            </tr>
            };
        }
        
        $pacs_html .= qq{
                        </tbody>
                    </table>
                </div>
            </div>
            
            <!-- Inicialización de DataTables e integración JS -->
            <script>
                \$(document).ready(function() {
                    if (!\$.fn.DataTable.isDataTable('#tablaConsultaEstudiosPACS')) {
                        \$('#tablaConsultaEstudiosPACS').DataTable({
                            language: { url: 'https://cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
                            pageLength: 5,
                            lengthMenu: [5, 10, 25],
                            dom: "<'row mb-2 align-items-center'<'col-sm-12 col-md-6'l><'col-sm-12 col-md-6'f>>" +
                                 "<'row'<'col-sm-12'tr>>" +
                                 "<'row mt-2'<'col-sm-12 col-md-5'i><'col-sm-12 col-md-7'p>>",
                            ordering: false
                        });
                    }
                });

                function togglePacsToGabinete(chk) {
                    const desc = chk.getAttribute('data-desc');
                    const fecha = chk.getAttribute('data-fecha');
                    const mod = chk.getAttribute('data-mod');
                    const text = `[Estudio PACS - \${mod} - \${fecha} - \${desc}]\\n`;
                    
                    const textarea = document.querySelector('textarea[name="gabinete_solicitados"]');
                    if (!textarea) return;
                    
                    if (chk.checked) {
                        // Agregar leyenda si no existe
                        if (!textarea.value.includes(text.trim())) {
                            textarea.value = textarea.value.trim() + (textarea.value ? "\\n" : "") + text;
                        }
                    } else {
                        // Remover leyenda
                        textarea.value = textarea.value.replace(text, '').replace(text.trim(), '').trim();
                    }
                    
                    // Disparar evento de input para guardar borrador
                    textarea.dispatchEvent(new Event('input'));
                }
            </script>
        };
    } else {
        # Si no tiene estudios PACS
        $pacs_html .= qq{
            <div class="col-12 mt-4">
                <div class="alert alert-info border-0 rounded-4 shadow-sm p-4 d-flex align-items-center gap-3">
                    <i class="bi bi-info-circle-fill text-primary" style="font-size: 2rem;"></i>
                    <div>
                        <h6 class="fw-bold mb-1" style="color: var(--md-blue-deep);">Sin estudios PACS previos</h6>
                        <p class="mb-0 small text-muted">No existe ningún estudio registrado en "Estudios de Gabinete / Imagenología" para este paciente.</p>
                    </div>
                </div>
            </div>
        };
    }
    
    return qq{
        <div class="wizard-panel" id="step-panel-3">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-file-medical me-2" style="color: var(--md-teal-clinical);"></i>Estudios Complementarios
            </h3>
            
            <div class="row g-4">
                <div class="col-12">
                    <p class="text-muted mb-4">Gestione los estudios de laboratorio o imagenolog&iacute;a solicitados o tra&iacute;dos por el paciente.</p>
                </div>
                
                <div class="col-md-6">
                    <label class="wizard-label">Estudios de Laboratorio Solicitados</label>
                    <textarea name="laboratorios_solicitados" class="wizard-input" rows="3" placeholder="Biometr&iacute;a hem&aacute;tica, Qu&iacute;mica sangu&iacute;nea..."></textarea>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Estudios de Gabinete / Imagenolog&iacute;a</label>
                    <textarea name="gabinete_solicitados" class="wizard-input" rows="3" placeholder="Radiograf&iacute;a panor&aacute;mica, TAC..."></textarea>
                </div>
                
                $pacs_html
                
                <div class="col-12 mt-4">
                    <label class="wizard-label">Resultados Previos / Observaciones</label>
                    <textarea name="resultados_estudios" class="wizard-input" rows="4" placeholder="Interprete aqu&iacute; los resultados presentados por el paciente..."></textarea>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a SOAP <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
    };
}
1;
