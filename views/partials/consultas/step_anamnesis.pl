use strict;
use warnings;
use utf8;

sub render_step_anamnesis {
    my ($paciente) = @_;
    $paciente ||= {};
    
    my $tutor = $paciente->{tutor} // '';
    my $ant = $paciente->{antecedentes} // {};
    my $hf  = $ant->{heredofamiliares} // {};
    my $pp  = $ant->{personales_patologicos} // {};
    my $pnp = $ant->{personales_no_patologicos} // {};

    sub _fmt_ant_badge {
        my ($label, $val, $spec) = @_;
        my $is_si = ($val && $val =~ /S[ií]/i);
        my $badge_cls = $is_si ? 'bg-danger-subtle text-danger border border-danger-subtle' : 'bg-light text-muted border';
        my $icon = $is_si ? '<i class="bi bi-exclamation-triangle-fill me-1"></i>' : '<i class="bi bi-check-circle me-1"></i>';
        my $txt = "$icon<strong>$label:</strong> " . ($val || 'No');
        if ($is_si && $spec) {
            $txt .= " <em>($spec)</em>";
        }
        return qq{<span class="badge $badge_cls p-2 fw-medium text-wrap text-start me-1 mb-1">$txt</span>};
    }

    my $hf_html = '';
    $hf_html .= _fmt_ant_badge("Hipertensión", $hf->{hipertension});
    $hf_html .= _fmt_ant_badge("Diabetes", $hf->{diabetes});
    $hf_html .= _fmt_ant_badge("Cardiopatías", $hf->{cardiopatias});
    $hf_html .= _fmt_ant_badge("Cáncer", $hf->{cancer}, $hf->{cancer_tipo});
    $hf_html .= _fmt_ant_badge("Hereditarias", $hf->{enfermedades}, $hf->{enfermedades_especificar});
    $hf_html .= _fmt_ant_badge("Alergias Fam.", $hf->{alergias}, $hf->{alergias_especificar});

    my $pp_html = '';
    $pp_html .= _fmt_ant_badge("Crónicas", $pp->{cronicas}, $pp->{cronicas_especificar});
    $pp_html .= _fmt_ant_badge("Cirugías", $pp->{cirugias}, $pp->{cirugias_especificar});
    $pp_html .= _fmt_ant_badge("Hospitalizaciones", $pp->{hospitalizaciones}, $pp->{hospitalizaciones_especificar});
    $pp_html .= _fmt_ant_badge("Alergias", $pp->{alergias}, $pp->{alergias_especificar});
    $pp_html .= _fmt_ant_badge("Tratamientos", $pp->{tratamientos}, $pp->{tratamientos_especificar});

    my $pnp_html = '';
    $pnp_html .= _fmt_ant_badge("Tabaquismo", $pnp->{tabaquismo}, $pnp->{tabaquismo_cantidad} ? "$pnp->{tabaquismo_cantidad} cig/día" : '');
    $pnp_html .= _fmt_ant_badge("Alcoholismo", $pnp->{alcohol}, $pnp->{alcohol_frecuencia});
    $pnp_html .= _fmt_ant_badge("Drogas", $pnp->{drogas}, $pnp->{drogas_tipo});
    $pnp_html .= _fmt_ant_badge("Act. Física", $pnp->{actividad_fisica}, $pnp->{actividad_fisica_tipo});
    my $alim_txt = $pnp->{alimentacion} || 'Balanceada';
    if ($alim_txt eq 'Otro' && $pnp->{alimentacion_otro}) {
        $alim_txt .= " ($pnp->{alimentacion_otro})";
    }
    $pnp_html .= qq{<span class="badge bg-light text-dark border p-2 fw-medium me-1 mb-1"><i class="bi bi-egg-fried me-1 text-info"></i><strong>Alimentación:</strong> $alim_txt</span>};

    my $tutor_html = '';
    if ($tutor) {
        $tutor_html = qq{
            <div class="col-12 mb-3">
                <div class="alert alert-warning mb-0 p-3 d-flex align-items-center rounded-4 shadow-sm border-warning-subtle">
                    <i class="bi bi-shield-person-fill fs-4 me-3 text-warning"></i>
                    <div>
                        <div class="fw-bold small text-uppercase tracking-wider text-warning-emphasis">Responsable / Tutor Registrado</div>
                        <div class="fs-6 fw-bold text-dark">$tutor</div>
                    </div>
                </div>
            </div>
        };
    }

    my $patologicos_val = $pp->{cronicas_especificar} || ($pp->{cronicas} && $pp->{cronicas} eq 'Sí' ? 'Sí' : '');
    my $alergias_val = $pp->{alergias_especificar} || ($pp->{alergias} && $pp->{alergias} eq 'Sí' ? 'Sí' : '');

    return qq{
        <div class="wizard-panel" id="step-panel-1">
            <h3 class="mb-4" style="color: var(--md-blue-deep); font-weight: 800;">
                <i class="bi bi-clock-history me-2" style="color: var(--md-teal-clinical);"></i>Historial M&eacute;dico y Antecedentes
            </h3>
            
            $tutor_html

            <div class="row g-4">
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 10px;">Padecimiento Actual</h5>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Inicio de S&iacute;ntomas</label>
                    <input type="date" name="inicio_sintomas" class="wizard-input" value="@{[ sprintf('%04d-%02d-%02d', (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3]) ]}">
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Intensidad (1-10)</label>
                    <input type="number" name="intensidad" class="wizard-input" min="1" max="10" value="1">
                </div>
                <div class="col-12">
                    <label class="wizard-label">Evoluci&oacute;n y S&iacute;ntomas <span class="req-star">*</span></label>
                    <textarea name="evolucion" class="wizard-input" rows="3" placeholder="Describa c&oacute;mo ha evolucionado el cuadro cl&iacute;nico..." required></textarea>
                </div>
                
                <div class="col-12">
                    <h5 style="color: var(--md-teal-clinical); border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; margin-top: 10px;">Antecedentes Personales y Notas R&aacute;pidas de Consulta</h5>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Patol&oacute;gicos (Notas de Consulta)</label>
                    <textarea name="antecedentes_patologicos" class="wizard-input" rows="2" placeholder="Ej. Hipertensi&oacute;n, Diabetes...">$patologicos_val</textarea>
                </div>
                <div class="col-md-6">
                    <label class="wizard-label">Alergias (Notas de Consulta)</label>
                    <textarea name="alergias" class="wizard-input" rows="2" placeholder="Medicamentos, alimentos...">$alergias_val</textarea>
                </div>

                <!-- MÓDULO COMPLETO DE ANTECEDENTES (PROVENIENTE DEL EXPEDIENTE DEL PACIENTE) -->
                <div class="col-12 mt-4">
                    <div class="card border-0 shadow-sm rounded-4 p-4" style="background: #f8fafc; border: 1px solid #e2e8f0 !important;">
                        <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
                            <div>
                                <h6 class="fw-bold m-0" style="color: var(--md-blue-deep);"><i class="bi bi-journal-medical me-2" style="color: var(--md-teal-clinical);"></i>M&oacute;dulo Completo de Antecedentes del Expediente</h6>
                                <p class="text-muted small mb-0">Informaci&oacute;n estructurada extra&iacute;da de la Ficha de Identificaci&oacute;n del Paciente</p>
                            </div>
                            <a href="crud_paciente.pl?accion=U&edit_id=$paciente->{id_paciente}" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 shadow-sm"><i class="bi bi-pencil me-1"></i>Editar Expediente</a>
                        </div>
                        <div class="row g-3">
                            <div class="col-md-4">
                                <div class="p-3 bg-white rounded-3 border h-100 shadow-sm">
                                    <div class="fw-bold small text-primary mb-2 border-bottom pb-1"><i class="bi bi-people-fill me-1"></i>Antecedentes Heredofamiliares</div>
                                    <div class="d-flex flex-wrap">$hf_html</div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="p-3 bg-white rounded-3 border h-100 shadow-sm">
                                    <div class="fw-bold small text-warning-emphasis mb-2 border-bottom pb-1"><i class="bi bi-file-earmark-medical-fill me-1"></i>Personales Patol&oacute;gicos</div>
                                    <div class="d-flex flex-wrap">$pp_html</div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="p-3 bg-white rounded-3 border h-100 shadow-sm">
                                    <div class="fw-bold small text-info mb-2 border-bottom pb-1"><i class="bi bi-heart-pulse me-1"></i>Personales No Patol&oacute;gicos</div>
                                    <div class="d-flex flex-wrap">$pnp_html</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="d-flex justify-content-between mt-5">
                <button type="button" class="wizard-btn-prev" onclick="WizardController.prevStep()"><i class="bi bi-arrow-left me-2"></i> Anterior</button>
                <button type="button" class="wizard-btn-next" onclick="WizardController.nextStep()">Continuar a Exploraci&oacute;n <i class="bi bi-arrow-right ms-2"></i></button>
            </div>
        </div>
    };
}
1;
