use strict;
use warnings;
use utf8;

use FindBin;
use File::Spec;
use JSON qw(decode_json);
use Encode qw(encode_utf8);

sub render_step_exploracion {
    my ($paciente) = @_;
    $paciente //= {};
    my $id_paciente = $paciente->{id_paciente} || $paciente->{id} || '';
    my $id_espe = $paciente->{id_espe_medico} // '0';
    my $espe_nombre = $paciente->{espe_nombre_medico} // 'Medicina General';
    my $is_odontologia = ($id_espe eq '100' || $espe_nombre =~ /Odontolog/i) ? 1 : 0;

    # Cargar catálogo de odontogramas del paciente
    my @odontogramas_pac;
    if ($id_paciente) {
        my $dir_json = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'odontogramas');
        my $archivo_json = File::Spec->catfile($dir_json, "paciente_${id_paciente}.json");
        my $archivo_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');

        if (-e $archivo_json) {
            my $json_raw = '';
            if (open my $fh, '<:raw', $archivo_json) {
                local $/;
                $json_raw = <$fh>;
                close $fh;
            }
            my $parsed = eval { decode_json($json_raw) };
            if ($parsed && ref($parsed) eq 'HASH') {
                if (exists $parsed->{odontogramas} && ref($parsed->{odontogramas}) eq 'ARRAY') {
                    @odontogramas_pac = @{ $parsed->{odontogramas} };
                } elsif (exists $parsed->{teeth} && ref($parsed->{teeth}) eq 'HASH') {
                    push @odontogramas_pac, {
                        id_odonto => "OD-${id_paciente}-1",
                        alias     => $parsed->{alias} || 'Diagnóstico Inicial',
                        fecha     => $parsed->{fechaLocal} || $parsed->{updatedAt} || 'Recientemente',
                        estado    => $parsed->{estado} || 'En Proceso',
                        importe   => $parsed->{financialTotalPending} || 0,
                        teeth     => $parsed->{teeth} || {}
                    };
                }
            }
        }

        if (!@odontogramas_pac && -e $archivo_dat) {
            my $registros = eval { utils::db_manager::leer_tabla($archivo_dat, '\|') } || [];
            my %teeth_found;
            my $fecha_found = '';
            my $alias_found = 'Diagnóstico Base';
            foreach my $fila (@$registros) {
                if ($fila->[0] eq $id_paciente) {
                    $alias_found = $fila->[1] if $fila->[1];
                    $fecha_found = $fila->[2] if $fila->[2];
                    for (my $i = 4; $i < @$fila; $i++) {
                        if ($fila->[$i] =~ /^(\d+)=(.+)$/) {
                            my $tooth = $1;
                            my $val_hash = eval { decode_json(encode_utf8($2)) } || {};
                            $teeth_found{$tooth} = $val_hash;
                        }
                    }
                }
            }
            if (%teeth_found || $fecha_found) {
                push @odontogramas_pac, {
                    id_odonto => "OD-${id_paciente}-1",
                    alias     => $alias_found,
                    fecha     => $fecha_found || 'Recientemente',
                    estado    => 'En Proceso',
                    importe   => 0.00,
                    teeth     => \%teeth_found
                };
            }
        }
    }

    # Construir listado HTML de odontogramas
    my $odonto_html = '';
    if (@odontogramas_pac) {
        $odonto_html .= qq{
            <div class="col-12 mt-4">
                <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-bottom: 15px;">
                    <i class="bi bi-journal-medical me-2"></i>Odontogramas Cl&iacute;nicos Disponibles (Planes y Detalle Anat&oacute;mico)
                </h5>
                <div class="table-responsive card-medentia-aura border-0 p-3 shadow-sm bg-white rounded-4">
                    <table class="table table-hover align-middle mb-0" id="tablaConsultaOdontogramas" style="width:100%">
                        <thead class="table-light">
                            <tr>
                                <th class="ps-3 border-0 rounded-start-3" style="width: 50px;">Asignar</th>
                                <th class="border-0" style="width: 80px;">Preview</th>
                                <th class="border-0" style="width: 100px;">Fecha</th>
                                <th class="border-0" style="width: 90px;">Estado</th>
                                <th class="border-0">Descripci&oacute;n / Alias</th>
                                <th class="border-0 text-end pe-3 rounded-end-3" style="width: 80px;">Visor</th>
                            </tr>
                        </thead>
                        <tbody class="small">
        };

        foreach my $od (@odontogramas_pac) {
            my $id_odonto = $od->{id_odonto} || "OD-${id_paciente}-1";
            my $alias = $od->{alias} || 'Odontograma Clínico';
            my $fecha = $od->{fecha} || 'Sin fecha';
            my $estado = $od->{estado} || 'En Proceso';
            my $importe = sprintf("%.2f", $od->{importe} || 0);
            my $cnt_piezas = (ref($od->{teeth}) eq 'HASH') ? scalar(keys %{ $od->{teeth} }) : 0;

            my $badge_estado = '<span class="badge bg-secondary-subtle text-secondary border px-2 py-1">Histórico</span>';
            if ($estado =~ /En Proceso|Activo/i) {
                $badge_estado = '<span class="badge bg-warning-subtle text-warning-emphasis border border-warning-subtle px-2 py-1"><i class="bi bi-clock-history me-1"></i>En Proceso</span>';
            } elsif ($estado =~ /Planificado|Presupuesto/i) {
                $badge_estado = '<span class="badge bg-info-subtle text-info-emphasis border border-info-subtle px-2 py-1"><i class="bi bi-calendar-check me-1"></i>Planificado</span>';
            } elsif ($estado =~ /Finalizado|Completado/i) {
                $badge_estado = '<span class="badge bg-success-subtle text-success border border-success-subtle px-2 py-1"><i class="bi bi-check-circle-fill me-1"></i>Finalizado</span>';
            }

            my $safe_alias = $alias;
            $safe_alias =~ s/"/\\"/g;
            $safe_alias =~ s/'/\\'/g;

            $odonto_html .= qq{
                            <tr>
                                <td class="ps-3 text-center">
                                    <div class="form-check form-switch d-inline-block">
                                        <input class="form-check-input odonto-chk" type="checkbox" name="odonto_estudios_seleccionados" value="$id_odonto" data-alias="$safe_alias" data-fecha="$fecha" data-piezas="$cnt_piezas" data-importe="$importe" onchange="toggleOdontoToExploracion(this)">
                                    </div>
                                </td>
                                <td>
                                    <div class="d-flex align-items-center justify-content-center rounded-3 border" style="width: 45px; height: 45px; background: rgba(25, 183, 165, 0.08); color: var(--md-teal-clinical, #19B7A5);" title="Odontograma Clínico">
                                        <i class="bi bi-journal-medical fs-5"></i>
                                    </div>
                                </td>
                                <td class="fw-bold text-muted">$fecha</td>
                                <td>$badge_estado</td>
                                <td>
                                    <div class="fw-bold text-dark">$alias</div>
                                    <div class="small text-muted">
                                        <span class="badge bg-light text-muted border me-1">#$id_odonto</span>
                                        <span>$cnt_piezas piezas</span> &bull; 
                                        <span class="text-danger fw-semibold">\$$importe MXN</span>
                                    </div>
                                </td>
                                <td class="text-end pe-3">
                                    <a href="render_visor_odontograma.pl?id=$id_paciente&id_odonto=$id_odonto" target="_blank" class="btn btn-sm btn-outline-primary rounded-circle" style="width: 32px; height: 32px; padding: 0; line-height: 30px; display: inline-flex; align-items: center; justify-content: center;" title="Abrir Visor de Odontograma"><i class="bi bi-box-arrow-up-right"></i></a>
                                </td>
                            </tr>
            };
        }

        $odonto_html .= qq{
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Inicialización de DataTables e integración JS -->
            <script>
                \$(document).ready(function() {
                    if (!\$.fn.DataTable.isDataTable('#tablaConsultaOdontogramas')) {
                        \$('#tablaConsultaOdontogramas').DataTable({
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

                function toggleOdontoToExploracion(chk) {
                    const alias = chk.getAttribute('data-alias') || 'Odontograma Clínico';
                    const fecha = chk.getAttribute('data-fecha') || '';
                    const piezas = chk.getAttribute('data-piezas') || '0';
                    const importe = chk.getAttribute('data-importe') || '0.00';
                    const text = `[Odontograma Clínico - \${alias} - \${fecha} - \${piezas} piezas - Presupuesto: \\\$\${importe} MXN]\\n`;

                    const textarea = document.querySelector('textarea[name="exploracion_hallazgos"]');
                    if (!textarea) return;

                    if (chk.checked) {
                        if (!textarea.value.includes(text.trim())) {
                            textarea.value = textarea.value.trim() + (textarea.value ? "\\n" : "") + text;
                        }
                    } else {
                        textarea.value = textarea.value.replace(text, '').replace(text.trim(), '').trim();
                    }

                    textarea.dispatchEvent(new Event('input'));
                }
            </script>
        };
    } else {
        $odonto_html .= qq{
            <div class="col-12 mt-4">
                <div class="alert alert-light border rounded-4 shadow-sm p-4 d-flex align-items-center gap-3">
                    <i class="bi bi-info-circle-fill" style="font-size: 2rem; color: var(--md-teal-clinical, #19B7A5);"></i>
                    <div>
                        <h6 class="fw-bold mb-1" style="color: var(--md-blue-deep);">Sin odontogramas previos</h6>
                        <p class="mb-0 small text-muted">No existen odontogramas registrados en el expediente clínico para este paciente.</p>
                    </div>
                </div>
            </div>
        };
    }

    my $subformulario_html = '';

    if ($is_odontologia) {
        $subformulario_html = <<HTML;
                <!-- Odontograma Interactivo (Se muestra si es Odontología) -->
                <div class="col-12" id="odontograma-section">
                    <div class="card-medentia-aura border-0 bg-white p-4 rounded shadow-sm">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <h5 style="color: var(--md-teal-clinical); m-0"><i class="bi bi-tooth me-2"></i>Odontograma Interactivo</h5>
                            <span class="badge bg-primary">Modo Odontología</span>
                        </div>
                        
                        <!-- Toolbar -->
                        <div class="d-flex flex-column gap-3 mb-4" id="odontograma-toolbar">
                            <div class="odontograma-tools-grid">
                                <button type="button" class="btn btn-outline-danger btn-sm rounded-pill px-3 active-tool" data-tool="caries"><i class="bi bi-circle-fill me-1"></i>Caries</button>
                                <button type="button" class="btn btn-outline-primary btn-sm rounded-pill px-3" data-tool="corona"><i class="bi bi-square-fill me-1"></i>Corona</button>
                                <button type="button" class="btn btn-outline-dark btn-sm rounded-pill px-3" data-tool="extraccion"><i class="bi bi-x-lg me-1"></i>Extracci&oacute;n</button>
                                <button type="button" class="btn btn-outline-info btn-sm rounded-pill px-3" data-tool="implante"><i class="bi bi-vinyl-fill me-1"></i>Implante</button>
                                <button type="button" class="btn btn-outline-warning btn-sm rounded-pill px-3" data-tool="protesis"><i class="bi bi-diagram-2-fill me-1"></i>Pr&oacute;tesis</button>
                                <button type="button" class="btn btn-outline-success btn-sm rounded-pill px-3" data-tool="sano"><i class="bi bi-check-circle-fill me-1"></i>Sano</button>
                            </div>
                            <div class="d-flex justify-content-end">
                                <button type="button" class="btn btn-medentia btn-sm rounded-pill px-4" onclick="saveOdontogramaToServer()"><i class="bi bi-cloud-arrow-up-fill me-2"></i>Guardar Mapa Dental</button>
                            </div>
                        </div>
                        
                        <!-- Container SVG -->
                        <div class="odontograma-container card-medentia-aura p-3 mb-3 overflow-auto border-0 bg-light rounded text-center" style="min-height: 300px;">
                            <div id="odontograma-svg-container" class="text-center w-100">
                                <div class="py-5 text-muted opacity-50"><div class="spinner-border text-primary mb-3"></div><br>Iniciando Mapa Dental...</div>
                            </div>
                        </div>
                        
                        <div class="form-check mt-3">
                            <input class="form-check-input wizard-input-check" type="checkbox" name="odontograma_evaluado" value="1" id="od_eval">
                            <label class="form-check-label fw-bold" for="od_eval">Confirmo que he actualizado y guardado el odontograma en esta sesión.</label>
                        </div>
                    </div>
                </div>
HTML
    } else {
        $subformulario_html = <<HTML;
                <!-- Subformulario Dinámico para Especialidades No Odontológicas -->
                <div class="col-12" id="especialidad-subformulario-container">
                    <div class="card-medentia-aura border-0 bg-white p-4 rounded-4 shadow-sm">
                        <div class="d-flex align-items-center mb-3">
                            <i class="bi bi-diagram-3-fill me-2 text-primary fs-5"></i>
                            <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">Módulo de Exploración Dirigida ($espe_nombre)</h5>
                            <span class="badge bg-info text-white ms-auto">Especialidad: $espe_nombre</span>
                        </div>
                        <div class="alert alert-primary bg-primary bg-opacity-10 border-primary border-opacity-25 rounded-4 p-4 text-center my-2">
                            <i class="bi bi-tools display-5 d-block mb-3 text-primary"></i>
                            <h4 class="fw-bold text-primary mb-2">(Aquí van los subformularios según la especialidad)</h4>
                            <p class="text-muted mb-0 small">Subformulario modular y extensible dinámico configurado para <strong>$espe_nombre</strong>.</p>
                        </div>
                    </div>
                </div>
HTML
    }

    return qq{
        <div class="wizard-panel" id="step-panel-2">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-activity me-2" style="color: var(--md-teal-clinical);"></i>Exploraci&oacute;n F&iacute;sica (Objetivo - O)
            </h3>
            
            <div class="row g-4">
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 10px;">Signos Vitales B&aacute;sicos</h5>
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">T.A. (mmHg)</label>
                    <input type="text" name="ta" class="wizard-input" placeholder="120/80">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">F.C. (lpm)</label>
                    <input type="number" name="fc" class="wizard-input" placeholder="70">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">F.R. (rpm)</label>
                    <input type="number" name="fr" class="wizard-input" placeholder="16">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">Temp (&deg;C)</label>
                    <input type="number" name="temp" class="wizard-input" step="0.1" placeholder="36.5">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">Peso (kg)</label>
                    <input type="number" name="peso" id="ef_peso" class="wizard-input" step="0.1">
                </div>
                <div class="col-12 col-md-2">
                    <label class="wizard-label">Talla (cm)</label>
                    <input type="number" name="talla" id="ef_talla" class="wizard-input" step="1">
                </div>
                
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 20px;">Exploraci&oacute;n Dirigida por Especialidad</h5>
                </div>
                
                $subformulario_html

                $odonto_html

                <div class="col-12">
                    <label class="wizard-label">Hallazgos Cl&iacute;nicos <span class="req-star">*</span></label>
                    <textarea name="exploracion_hallazgos" class="wizard-input" rows="5" placeholder="Describa los hallazgos de la exploraci&oacute;n f&iacute;sica..." required></textarea>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Estudios <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
    };
}
1;
