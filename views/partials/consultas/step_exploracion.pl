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
        my $header_extra = '';
        if ($is_odontologia) {
            $header_extra = qq{
                <div class="d-flex align-items-center justify-content-between mb-3 flex-wrap gap-2">
                    <div>
                        <h5 style="color: var(--md-teal-clinical); margin: 0; font-weight: 700;">
                            <i class="bi bi-journal-medical me-2"></i>Odontogramas Cl&iacute;nicos Disponibles (Planes y Detalle Anat&oacute;mico)
                        </h5>
                        <small class="text-muted">Asigne el odontograma para la consulta o cree una copia de evoluci&oacute;n para registrar el procedimiento del d&iacute;a.</small>
                    </div>
                    <div class="d-flex align-items-center gap-2 flex-wrap">
                        <a href="render_visor_odontograma.pl?id=$id_paciente" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 py-1 shadow-xs fw-bold" title="Abrir Visor para crear o editar odontogramas">
                            <i class="bi bi-plus-circle me-1"></i>Nuevo Odontograma
                        </a>
                        <div class="form-check form-switch bg-light px-3 py-1 rounded-pill border mb-0">
                            <input class="form-check-input ms-0 me-2" type="checkbox" name="odonto_finalizar_al_cerrar" id="odonto_finalizar_al_cerrar" value="1" checked>
                            <label class="form-check-label small fw-bold text-navy" for="odonto_finalizar_al_cerrar">
                                <i class="bi bi-check-circle-fill text-success me-1"></i>Finalizar odontograma al cerrar
                            </label>
                        </div>
                    </div>
                </div>
            };
        } else {
            $header_extra = qq{
                <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-bottom: 15px;">
                    <i class="bi bi-journal-medical me-2"></i>Odontogramas Cl&iacute;nicos Disponibles (Planes y Detalle Anat&oacute;mico)
                </h5>
            };
        }

        my $th_visor_width = $is_odontologia ? '140px' : '80px';
        $odonto_html .= qq{
            <div class="col-12 mt-4">
                $header_extra
                <div class="table-responsive card-medentia-aura border-0 p-3 shadow-sm bg-white rounded-4">
                    <table class="table table-hover align-middle mb-0" id="tablaConsultaOdontogramas" style="width:100%">
                        <thead class="table-light">
                            <tr>
                                <th class="ps-3 border-0 rounded-start-3" style="width: 50px;">Asignar</th>
                                <th class="border-0" style="width: 80px;">Preview</th>
                                <th class="border-0" style="width: 100px;">Fecha</th>
                                <th class="border-0" style="width: 90px;">Estado</th>
                                <th class="border-0">Descripci&oacute;n / Alias</th>
                                <th class="border-0 text-end pe-3 rounded-end-3" style="width: $th_visor_width;">Acciones</th>
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

            my $btn_evolucion = '';
            if ($is_odontologia) {
                $btn_evolucion = qq{
                    <button type="button" class="btn btn-sm btn-outline-teal rounded-pill px-2 py-1 shadow-xs" style="font-size: 0.72rem; font-weight: 700; border-color: var(--md-teal-clinical, #19B7A5); color: var(--md-teal-clinical, #19B7A5);" title="Crear Copia para Evolución Clínica (Antes y Después)" onclick="crearEvolucionOdonto('$id_odonto', '$safe_alias')">
                        <i class="bi bi-copy me-1"></i>Evoluci&oacute;n
                    </button>
                };
            }

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
                                    <div class="d-flex align-items-center justify-content-end gap-1">
                                        $btn_evolucion
                                        <a href="render_visor_odontograma.pl?id=$id_paciente&id_odonto=$id_odonto" target="_blank" class="btn btn-sm btn-outline-primary rounded-circle" style="width: 30px; height: 30px; padding: 0; line-height: 28px; display: inline-flex; align-items: center; justify-content: center;" title="Abrir Visor de Odontograma"><i class="bi bi-box-arrow-up-right"></i></a>
                                    </div>
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
                window.PACIENTE_ID_ODONTO = '$id_paciente';

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

                    // Disparar sincronización con Caja si existe
                    if (typeof verificarOdontoParaCaja === 'function') {
                        verificarOdontoParaCaja();
                    }
                }

                async function crearEvolucionOdonto(idFuente, aliasFuente) {
                    if (typeof Swal === 'undefined') {
                        alert('SweetAlert2 no disponible');
                        return;
                    }

                    const { value: nuevoAlias } = await Swal.fire({
                        title: 'Crear Evolución Clínica',
                        html: `Se creará una copia de <b>\${aliasFuente || 'Odontograma Base'}</b> para registrar los procedimientos realizados hoy.<br><small class="text-muted">El odontograma inicial se conservará intacto como diagnóstico previo (Antes).</small>`,
                        input: 'text',
                        inputValue: 'Evolución - ' + new Date().toLocaleDateString('es-MX'),
                        inputLabel: 'Nombre / Alias de la Evolución',
                        showCancelButton: true,
                        confirmButtonText: '<i class="bi bi-copy me-1"></i> Crear y Asignar',
                        cancelButtonText: 'Cancelar',
                        confirmButtonColor: '#19B7A5'
                    });

                    if (!nuevoAlias) return;

                    Swal.fire({
                        title: 'Generando copia clínica...',
                        allowOutsideClick: false,
                        didOpen: () => { Swal.showLoading(); }
                    });

                    try {
                        const fd = new FormData();
                        fd.append('accion', 'clone');
                        fd.append('id_paciente', window.PACIENTE_ID_ODONTO || '$id_paciente');
                        fd.append('id_odonto', idFuente);
                        fd.append('alias', nuevoAlias);

                        const res = await fetch('../api/odontograma_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' });
                        const data = await res.json();

                        if (data.ok) {
                            Swal.fire({
                                icon: 'success',
                                title: '¡Evolución Creada!',
                                html: `Se creó <b>\${data.alias}</b> y se asignó a esta consulta.<br>¿Desea abrir el Visor Odontológico ahora para editar los procedimientos realizados?`,
                                showCancelButton: true,
                                confirmButtonText: '<i class="bi bi-display me-1"></i> Abrir Visor Dental',
                                cancelButtonText: 'Continuar en Consulta',
                                confirmButtonColor: '#0A2A66'
                            }).then((result) => {
                                if (result.isConfirmed) {
                                    window.open(`render_visor_odontograma.pl?id=\${encodeURIComponent(window.PACIENTE_ID_ODONTO || '$id_paciente')}&id_odonto=\${encodeURIComponent(data.id_odonto)}`, '_blank');
                                }
                            });

                            recargarTablaOdontogramas(data.id_odonto);
                        } else {
                            Swal.fire('Error', data.error || 'No se pudo crear la copia', 'error');
                        }
                    } catch (err) {
                        Swal.fire('Error', 'Fallo de conexión al clonar: ' + err.message, 'error');
                    }
                }

                async function recargarTablaOdontogramas(autoSelectId) {
                    try {
                        const pacId = window.PACIENTE_ID_ODONTO || '$id_paciente';
                        const res = await fetch('../api/odontograma_api.pl', {
                            method: 'POST',
                            body: new URLSearchParams({ accion: 'list', id_paciente: pacId }),
                            credentials: 'same-origin'
                        });
                        const resJson = await res.json();
                        if (resJson.ok && resJson.data) {
                            const tbody = document.querySelector('#tablaConsultaOdontogramas tbody');
                            if (!tbody) return;
                            tbody.innerHTML = '';
                            resJson.data.forEach(od => {
                                const isSelected = (autoSelectId && od.id_odonto === autoSelectId);
                                const safeAlias = (od.alias || 'Odontograma').replace(/"/g, '&quot;');
                                let badgeClass = 'bg-secondary-subtle text-secondary border';
                                if ((od.estado || '').match(/En Proceso|Activo/i)) badgeClass = 'bg-warning-subtle text-warning-emphasis border border-warning-subtle';
                                else if ((od.estado || '').match(/Planificado|Presupuesto/i)) badgeClass = 'bg-info-subtle text-info-emphasis border border-info-subtle';
                                else if ((od.estado || '').match(/Finalizado|Completado/i)) badgeClass = 'bg-success-subtle text-success border border-success-subtle';

                                const tr = document.createElement('tr');
                                tr.innerHTML = `
                                    <td class="ps-3 text-center">
                                        <div class="form-check form-switch d-inline-block">
                                            <input class="form-check-input odonto-chk" type="checkbox" name="odonto_estudios_seleccionados" value="\${od.id_odonto}" data-alias="\${safeAlias}" data-fecha="\${od.fecha}" data-piezas="\${od.piezas || 0}" data-importe="\${od.importe || '0.00'}" onchange="toggleOdontoToExploracion(this)" \${isSelected ? 'checked' : ''}>
                                        </div>
                                    </td>
                                    <td>
                                        <div class="d-flex align-items-center justify-content-center rounded-3 border" style="width: 45px; height: 45px; background: rgba(25, 183, 165, 0.08); color: var(--md-teal-clinical, #19B7A5);" title="Odontograma Clínico">
                                            <i class="bi bi-journal-medical fs-5"></i>
                                        </div>
                                    </td>
                                    <td class="fw-bold text-muted">\${od.fecha}</td>
                                    <td><span class="badge \${badgeClass} px-2 py-1">\${od.estado}</span></td>
                                    <td>
                                        <div class="fw-bold text-dark">\${od.alias}</div>
                                        <div class="small text-muted">
                                            <span class="badge bg-light text-muted border me-1">#\${od.id_odonto}</span>
                                            <span>\${od.piezas || 0} piezas</span> &bull; 
                                            <span class="text-danger fw-semibold">\\\$\${od.importe} MXN</span>
                                        </div>
                                    </td>
                                    <td class="text-end pe-3">
                                        <div class="d-flex align-items-center justify-content-end gap-1">
                                            <button type="button" class="btn btn-sm btn-outline-teal rounded-pill px-2 py-1 shadow-xs" style="font-size: 0.72rem; font-weight: 700; border-color: var(--md-teal-clinical, #19B7A5); color: var(--md-teal-clinical, #19B7A5);" title="Crear Copia para Evolución Clínica" onclick="crearEvolucionOdonto('\${od.id_odonto}', '\${safeAlias}')">
                                                <i class="bi bi-copy me-1"></i>Evolución
                                            </button>
                                            <a href="render_visor_odontograma.pl?id=\${encodeURIComponent(pacId)}&id_odonto=\${encodeURIComponent(od.id_odonto)}" target="_blank" class="btn btn-sm btn-outline-primary rounded-circle" style="width: 30px; height: 30px; padding: 0; line-height: 28px; display: inline-flex; align-items: center; justify-content: center;" title="Abrir Visor"><i class="bi bi-box-arrow-up-right"></i></a>
                                        </div>
                                    </td>
                                `;
                                tbody.appendChild(tr);

                                if (isSelected) {
                                    const chk = tr.querySelector('.odonto-chk');
                                    if (chk) toggleOdontoToExploracion(chk);
                                }
                            });
                        }
                    } catch(e) {
                        console.error('Error al recargar tabla de odontogramas:', e);
                    }
                }
            </script>
        };
    } else {
        if ($is_odontologia) {
            $odonto_html .= qq{
                <div class="col-12 mt-4">
                    <div class="alert alert-light border rounded-4 shadow-sm p-4 d-flex align-items-center justify-content-between flex-wrap gap-3">
                        <div class="d-flex align-items-center gap-3">
                            <i class="bi bi-journal-medical" style="font-size: 2.2rem; color: var(--md-teal-clinical, #19B7A5);"></i>
                            <div>
                                <h6 class="fw-bold mb-1" style="color: var(--md-blue-deep);">Sin odontogramas previos</h6>
                                <p class="mb-0 small text-muted">Este paciente a&uacute;n no tiene ning&uacute;n odontograma registrado en su expediente cl&iacute;nico.</p>
                            </div>
                        </div>
                        <div>
                            <a href="render_visor_odontograma.pl?id=$id_paciente" target="_blank" class="btn btn-primary rounded-pill px-4 py-2 fw-bold shadow-sm">
                                <i class="bi bi-plus-circle me-2"></i>Crear Odontograma Inicial
                            </a>
                        </div>
                    </div>
                </div>
            };
        }
    }

    my $subformulario_html = '';
    my $seccion_especialidad = '';

    if (!$is_odontologia) {
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

        $seccion_especialidad = qq{
            <div class="col-12">
                <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 20px;">Exploraci&oacute;n Dirigida por Especialidad</h5>
            </div>
            $subformulario_html
        };
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
                
                $seccion_especialidad

                $odonto_html

                <div class="col-12">
                    <div class="d-flex justify-content-between align-items-center mb-1 flex-wrap gap-2">
                        <label class="wizard-label mb-0">Hallazgos Cl&iacute;nicos <span class="req-star">*</span></label>
                        <div class="d-flex align-items-center gap-1">
                            <button type="button" class="btn btn-sm btn-dictado-voz rounded-pill px-3 py-1 shadow-xs d-inline-flex align-items-center" id="btn-dictado-hallazgos" data-feedback-id="dictado-feedback-hallazgos" onclick="toggleDictadoVoz('textarea[name=exploracion_hallazgos]', this)" title="Dictar hallazgos clínicos por voz con micrófono">
                                <i class="bi bi-mic-fill me-1"></i>
                                <span class="btn-dictado-text fw-bold">Dictar</span>
                            </button>
                            <button type="button" class="btn btn-sm btn-limpiar-campo rounded-pill px-2 py-1 shadow-xs d-inline-flex align-items-center" onclick="limpiarCampoTexto('textarea[name=exploracion_hallazgos]')" title="Limpiar hallazgos clínicos">
                                <i class="bi bi-eraser-fill me-1"></i>
                                <span class="small fw-semibold">Limpiar</span>
                            </button>
                        </div>
                    </div>
                    <div class="position-relative">
                        <textarea name="exploracion_hallazgos" class="wizard-input" rows="5" placeholder="Describa los hallazgos de la exploraci&oacute;n f&iacute;sica o dicte usando el micr&oacute;fono..." required></textarea>
                        <div id="dictado-feedback-hallazgos" class="dictado-live-badge text-danger fw-bold mt-2 d-none align-items-center gap-2">
                            <span class="spinner-grow spinner-grow-sm text-danger" role="status" aria-hidden="true"></span>
                            <span>Escuchando... Hable claramente al micr&oacute;fono de su dispositivo (haga clic en 'Detener Dictado' para pausar).</span>
                        </div>
                    </div>
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
