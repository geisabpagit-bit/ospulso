#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use File::Spec;
use FindBin;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_medico  = $sd->{id_medico} // '';
my $id_empresa = $sd->{id_empresa} // '0';
$id_empresa    = '0' if $id_empresa eq '';
my $id_usuario_sesion = $sd->{id_registro} // $sd->{id_medico} // '';

binmode STDOUT, ":utf8";

# 1. Gobernanza RBAC
unless (utils::permisos_utils::tiene_permiso_modulo($id_empresa, $role, 'quirofano', 'R', $id_usuario_sesion)) {
    render_acceso_denegado(
        q             => $q,
        usuario       => $usuario,
        role          => $role,
        mensaje       => 'No cuenta con facultades RBAC para acceder al Módulo de Ingreso Quirúrgico.',
        rol_requerido => 'Facultad de Operación en Quirófano'
    );
    exit;
}

# 2. Validar Capacidad SaaS Hospitalización y Quirófanos de la Organización
my $has_hospitalizacion = 0;
my $num_quirofanos      = 1;
my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line);
        if ($biz_id eq $id_empresa) {
            if ($key eq 'MANEJA_HOSPITALIZACION') {
                $has_hospitalizacion = ($val eq '1') ? 1 : 0;
            } elsif ($key eq 'QUIROFANOS' && int($val // 0) > 0) {
                $num_quirofanos = int($val);
            }
        }
    }
    close($cf);
}
if (!$has_hospitalizacion && ($id_empresa eq '0' || $id_empresa eq '723800')) {
    $has_hospitalizacion = 1;
}

unless ($has_hospitalizacion) {
    render_acceso_denegado(
        q             => $q,
        usuario       => $usuario,
        role          => $role,
        mensaje       => 'La organización no cuenta con la capacidad SaaS de Hospitalización / Quirófano activa.',
        rol_requerido => 'Capacidad SaaS: Hospitalización'
    );
    exit;
}

# 3. Cargar Pacientes de la Organización
my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $pacientes_html = '';
if (-e $pac_file && open my $fhp, '<:encoding(UTF-8)', $pac_file) {
    <$fhp>;
    while (my $l = <$fhp>) {
        chomp $l;
        next if $l =~ /^\s*$/;
        my @p = split /\|/, $l, -1;
        next unless @p >= 3;
        my $p_tenant = $p[13] // '';
        my ($p_org)  = split(/:/, $p_tenant);
        if (!$p_org || $p_org eq $id_empresa || $id_empresa eq '0') {
            $pacientes_html .= qq(<option value="$p[0]">$p[2] (Exp #$p[0])</option>\n);
        }
    }
    close $fhp;
}

# 4. Cargar Médicos / Cirujanos / Anestesiólogos de la Organización
my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs = leer_tabla($usr_file, '!');
my $medicos_html = '';
foreach my $r (@$regs) {
    next unless scalar(@$r) >= 7;
    next unless ($r->[4] // '1') eq '1';
    my $m_id  = $r->[0];
    my $m_nom = $r->[1];
    my $rol_u = $r->[5] // '';
    my ($org_u) = split(/:/, $r->[6] // '');
    my $qx_tag = $r->[12] ? " [$r->[12]]" : "";
    if (($rol_u =~ /Medico|Especialista/i) && ($org_u eq $id_empresa || $id_empresa eq '0')) {
        $medicos_html .= qq(<option value="$m_id">$m_nom$qx_tag</option>\n);
    }
}

# 5. Generar Opciones de Salas de Quirófano (Sincronizadas con Agenda de Espacios)
my $salas_html = '';
for (my $i = 1; $i <= ($num_quirofanos > 0 ? $num_quirofanos : 2); $i++) {
    $salas_html .= qq(<option value="Quirófano $i">Quirófano $i (Sala de Renta #$i)</option>\n);
}

my $id_cirugia_param = $q->param('id_cirugia') || '';
$id_cirugia_param =~ s/[^a-zA-Z0-9_\-]//g;
my $step_param = int($q->param('step') || 1);
my @lt = localtime(time);
my $fecha_hoy = sprintf("%04d-%02d-%02d", $lt[5]+1900, $lt[4]+1, $lt[3]);

render_header(
    titulo      => 'Nuevo Ingreso Quirúrgico (Wizard Integral)',
    role        => $role,
    usuario     => $usuario,
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(
    usuario       => $usuario,
    role          => $role,
    id_medico     => $id_medico,
    pagina_actual => 'quirofano_ingreso'
);

print <<HTML;
<link rel="stylesheet" href="../css/sdm_mobile_standards.css" />
<link rel="stylesheet" href="../css/quirofano_wizard.css" />

<div id="qx-wizard-root"
     class="container-fluid container-mobile-flush pt-2 px-2 px-lg-3 pb-5"
     data-id-cirugia="$id_cirugia_param"
     data-init-step="$step_param"
     data-fecha-hoy="$fecha_hoy"
     data-role="$role">

    <!-- Encabezado Ejecutivo del Módulo Quirúrgico -->
    <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3 bg-white p-3 rounded-3 shadow-sm border">
        <div class="d-flex align-items-center gap-2.5">
            <div class="p-2.5 bg-danger-subtle text-danger rounded-3">
                <i class="bi bi-heart-pulse-fill fs-4"></i>
            </div>
            <div>
                <div class="d-flex align-items-center gap-2 flex-wrap">
                    <h4 class="fw-bold text-navy mb-0">Wizard de Ingreso a Cirugía y Flujo Transoperatorio</h4>
                    <span id="lbl-folio-activo" class="badge bg-secondary text-white px-2.5 py-1 rounded-pill">Nuevo Ingreso</span>
                </div>
                <p class="text-muted small mb-0">Sincronizado con Agenda de Espacios en Renta, Tablero Kanban en Vivo, Catálogo 3NF y Caja</p>
            </div>
        </div>
        <div class="d-flex align-items-center gap-2">
            <a href="agenda_espacios.pl" class="btn btn-sm btn-outline-secondary btn-mobile-standard fw-semibold">
                <i class="bi bi-door-open me-1"></i>Ver Agenda Espacios
            </a>
            <a href="quirofano_kanban.pl" class="btn btn-sm btn-primary btn-mobile-standard fw-bold shadow-sm">
                <i class="bi bi-kanban me-1"></i>Ir al Tablero Quirúrgico
            </a>
        </div>
    </div>

    <!-- Stepper Guiado de 6 Pasos -->
    <div class="qx-stepper-bar">
        <button type="button" class="qx-step-tab active" data-step="1" onclick="irAPaso(1)">
            <span class="qx-step-num">1</span>
            <div>
                <span class="qx-step-title">Programación</span>
                <span class="qx-step-sub">Espacios & Agenda</span>
            </div>
        </button>
        <button type="button" class="qx-step-tab" data-step="2" onclick="irAPaso(2)">
            <span class="qx-step-num">2</span>
            <div>
                <span class="qx-step-title">Recepción y Caja</span>
                <span class="qx-step-sub">Consent. & Depósito</span>
            </div>
        </button>
        <button type="button" class="qx-step-tab" data-step="3" onclick="irAPaso(3)">
            <span class="qx-step-num">3</span>
            <div>
                <span class="qx-step-title">Pre-Operatorio</span>
                <span class="qx-step-sub">Enfermería & 3NF</span>
            </div>
        </button>
        <button type="button" class="qx-step-tab" data-step="4" onclick="irAPaso(4)">
            <span class="qx-step-num">4</span>
            <div>
                <span class="qx-step-title">Transoperatorio</span>
                <span class="qx-step-sub">Quirófano & 3NF</span>
            </div>
        </button>
        <button type="button" class="qx-step-tab" data-step="5" onclick="irAPaso(5)">
            <span class="qx-step-num">5</span>
            <div>
                <span class="qx-step-title">Recuperación</span>
                <span class="qx-step-sub">Aldrete UCPA & 3NF</span>
            </div>
        </button>
        <button type="button" class="qx-step-tab" data-step="6" onclick="irAPaso(6)">
            <span class="qx-step-num">6</span>
            <div>
                <span class="qx-step-title">Alta y Corte Caja</span>
                <span class="qx-step-sub">Receta CIE-10 & Pase</span>
            </div>
        </button>
    </div>

    <!-- Layout Principal: Panel Lateral de Semaforización en Vivo + Contenedor de Pasos -->
    <div class="qx-wizard-layout">

        <!-- PANEL LATERAL DE MONITOREO EN VIVO (8 ACTORES) -->
        <aside class="qx-live-monitor-panel">
            <div class="qx-monitor-header">
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <span class="small fw-bold text-uppercase opacity-75" style="font-size:0.68rem; letter-spacing:0.6px;">Monitoreo en Vivo</span>
                    <span id="monitor-tipo-cirugia" class="badge bg-info text-dark fw-bold">PROGRAMADA</span>
                </div>
                <div class="d-flex justify-content-between align-items-center">
                    <span class="small">Columna Kanban:</span>
                    <span id="monitor-kanban-col" class="qx-kanban-pill bg-secondary"><i class="bi bi-kanban"></i> Programada</span>
                </div>
            </div>

            <div class="px-3 pt-2.5 pb-1 border-bottom bg-light d-flex justify-content-between align-items-center">
                <span class="small fw-bold text-muted">Semaforización (8 Actores)</span>
                <div class="d-flex gap-1.5 align-items-center" style="font-size:0.65rem;">
                    <span class="qx-traffic-dot dot-verde" style="width:8px;height:8px;"></span>OK
                    <span class="qx-traffic-dot dot-ambar" style="width:8px;height:8px;"></span>Proc
                    <span class="qx-traffic-dot dot-rojo" style="width:8px;height:8px;"></span>Alerta
                </div>
            </div>

            <div class="qx-actor-list" id="monitor-actors-list"></div>

            <div class="p-3 bg-light border-top">
                <div class="d-flex justify-content-between align-items-center">
                    <span class="small fw-bold text-secondary">Acumulado Insumos 3NF:</span>
                    <span id="monitor-total-insumos" class="fw-bold text-primary fs-6">\$0.00</span>
                </div>
                <div class="small text-muted mt-1" style="font-size:0.7rem;">
                    <i class="bi bi-shield-check text-success me-1"></i>Cumplimiento NOM-004 y NOM-024
                </div>
            </div>
        </aside>

        <!-- CONTENEDOR DE LOS 6 PASOS DEL WIZARD -->
        <section class="card border-0 shadow-sm rounded-3 bg-white">
            <div class="card-body p-3 p-lg-4">

                <!-- =========================================================
                     PASO 1: PROGRAMACIÓN Y AGENDA DE ESPACIOS EN RENTA
                     ========================================================= -->
                <div class="qx-stage-panel active" data-panel-step="1">
                    <div class="d-flex justify-content-between align-items-center border-bottom pb-2.5 mb-3">
                        <div>
                            <h5 class="fw-bold text-navy mb-0"><i class="bi bi-calendar2-check-fill text-primary me-2"></i>Paso 1: Programación y Reserva en Agenda de Espacios</h5>
                            <p class="text-muted small mb-0">Seleccione la modalidad quirúrgica, asigne paciente/cirujano y valide disponibilidad de sala en tiempo real.</p>
                        </div>
                        <span class="badge bg-primary-subtle text-primary fw-bold">Paso 1 de 6</span>
                    </div>

                    <input type="hidden" id="w_tipo_cirugia" value="PROGRAMADA" />

                    <!-- Selector de Modalidad Quirúrgica -->
                    <label class="form-label fw-bold text-navy small text-uppercase mb-2">1. Modalidad de Ingreso Quirúrgico (Bifurcación de Máquina de Estados)</label>
                    <div class="qx-type-selector mb-3">
                        <div class="qx-type-card selected-programada" id="card-tipo-programada" onclick="seleccionarTipoCirugia('PROGRAMADA')">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <span class="fw-bold text-primary"><i class="bi bi-calendar-check-fill me-1.5"></i>CIRUGÍA PROGRAMADA</span>
                                <span class="badge bg-primary">Secuencial Estricto</span>
                            </div>
                            <p class="text-muted small mb-0" style="font-size:0.76rem;">
                                Requiere disponibilidad libre en <strong>Agenda de Espacios</strong>. Ingresa a columna <code>PROGRAMADA</code> y exige Contrato, Consentimiento y Depósito (\$5,000) antes de pasar a Pre-Op.
                            </p>
                        </div>

                        <div class="qx-type-card" id="card-tipo-urgencias" onclick="seleccionarTipoCirugia('URGENCIAS')">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <span class="fw-bold text-danger"><i class="bi bi-lightning-charge-fill me-1.5"></i>CIRUGÍA DE URGENCIAS</span>
                                <span class="badge bg-danger">Flujo en Paralelo</span>
                            </div>
                            <p class="text-muted small mb-0" style="font-size:0.76rem;">
                                Bloqueo prioritario en <strong>Agenda de Espacios</strong>. Ingresa directo a <code>PRE-OPERATORIO</code>. Enfermería estabiliza sin bloqueo mientras el familiar tramita Recepción y Caja (Semáforos en Rojo pulsante).
                            </p>
                        </div>
                    </div>

                    <div class="row g-3">
                        <!-- Paciente -->
                        <div class="col-12 col-md-6">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <label class="form-label small fw-bold text-navy mb-0">2. Paciente Quirúrgico *</label>
                                <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none fw-bold" onclick="abrirModalAltaRapidaPaciente()">
                                    <i class="bi bi-person-plus-fill me-1"></i>+ Alta Rápida de Paciente
                                </button>
                            </div>
                            <select id="w_id_paciente" class="form-select form-select-sm fw-semibold">
                                <option value="">-- Seleccione Paciente --</option>
                                $pacientes_html
                            </select>
                        </div>

                        <!-- Médico Cirujano Titular -->
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-bold text-navy mb-1">3. Médico Cirujano Tratante *</label>
                            <select id="w_id_medico" class="form-select form-select-sm fw-semibold">
                                <option value="">-- Seleccione Cirujano Titular --</option>
                                $medicos_html
                            </select>
                        </div>

                        <!-- Procedimiento Quirúrgico -->
                        <div class="col-12 col-md-8">
                            <label class="form-label small fw-bold text-navy mb-1">4. Procedimiento Quirúrgico a Realizar *</label>
                            <input type="text" id="w_procedimiento" class="form-control form-control-sm fw-semibold" placeholder="Ej. Colecistectomía Laparoscópica, Apendicectomía, Hernioplastía..." />
                        </div>

                        <!-- Anestesiólogo -->
                        <div class="col-12 col-md-4">
                            <label class="form-label small fw-bold text-navy mb-1">5. Médico Anestesiólogo</label>
                            <select id="w_id_anestesiologo" class="form-select form-select-sm">
                                <option value="">-- Por Asignar / Opcional --</option>
                                $medicos_html
                            </select>
                        </div>

                        <!-- Sala en Agenda de Espacios -->
                        <div class="col-12 col-md-4">
                            <label class="form-label small fw-bold text-navy mb-1">6. Sala en Agenda de Espacios *</label>
                            <select id="w_sala" class="form-select form-select-sm fw-bold text-primary" onchange="verificarDisponibilidadSalaEnVivo()">
                                $salas_html
                            </select>
                        </div>

                        <!-- Fecha Programada -->
                        <div class="col-12 col-md-4">
                            <label class="form-label small fw-bold text-navy mb-1">7. Fecha de Cirugía *</label>
                            <input type="date" id="w_fecha" class="form-control form-control-sm fw-bold" onchange="verificarDisponibilidadSalaEnVivo()" />
                        </div>

                        <!-- Horario Inicio / Fin -->
                        <div class="col-6 col-md-2">
                            <label class="form-label small fw-bold text-navy mb-1">Hora Inicio *</label>
                            <input type="time" id="w_hora_ini" class="form-control form-control-sm fw-bold" value="10:00" onchange="verificarDisponibilidadSalaEnVivo()" />
                        </div>
                        <div class="col-6 col-md-2">
                            <label class="form-label small fw-bold text-navy mb-1">Hora Fin Est. *</label>
                            <input type="time" id="w_hora_fin" class="form-control form-control-sm fw-bold" value="12:00" onchange="verificarDisponibilidadSalaEnVivo()" />
                        </div>

                        <!-- Resultado en Vivo de Verificación con Agenda de Espacios -->
                        <div class="col-12">
                            <div id="box-disponibilidad-espacio"></div>
                        </div>

                        <!-- Notas Clínicas de Admisión -->
                        <div class="col-12">
                            <label class="form-label small fw-bold text-navy mb-1">8. Notas de Programación / Requerimientos Especiales de Sala</label>
                            <textarea id="w_notas" class="form-control form-control-sm" rows="2" placeholder="Requerimientos de torre laparoscópica, fluoroscopía, reserva de hemoderivados..."></textarea>
                        </div>
                    </div>

                    <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
                        <button type="button" class="btn btn-primary btn-mobile-standard fw-bold px-4" onclick="guardarPaso1Programacion()">
                            <i class="bi bi-save2-fill me-1.5"></i>Guardar Reserva en Agenda y Continuar <i class="bi bi-arrow-right ms-1"></i>
                        </button>
                    </div>
                </div>

                <!-- =========================================================
                     PASO 2: RECEPCIÓN, CONSENTIMIENTO INFORMADO Y CAJA ($5,000)
                     ========================================================= -->
                <div class="qx-stage-panel" data-panel-step="2">
                    <div class="d-flex justify-content-between align-items-center border-bottom pb-2.5 mb-3">
                        <div>
                            <h5 class="fw-bold text-navy mb-0"><i class="bi bi-file-earmark-check-fill text-teal me-2"></i>Paso 2: Recepción, Consentimiento Informado y Depósito en Caja</h5>
                            <p class="text-muted small mb-0">Validación médico-legal NOM-004 y garantía financiera de ingreso hospitalario.</p>
                        </div>
                        <span class="badge bg-primary-subtle text-primary fw-bold">Paso 2 de 6</span>
                    </div>

                    <!-- Banner exclusivo cuando la cirugía es de URGENCIAS -->
                    <div id="banner-flujo-paralelo-urgencia" class="alert alert-danger border-danger d-none mb-3">
                        <div class="d-flex flex-wrap justify-content-between align-items-center gap-2">
                            <div>
                                <h6 class="fw-bold mb-0.5"><i class="bi bi-exclamation-triangle-fill me-1.5"></i>MODO URGENCIAS — FLUJO EN PARALELO HABILITADO</h6>
                                <p class="small mb-0">Enfermería y Quirófano pueden avanzar al Paso 3 y 4 sin bloqueo mientras el familiar completa el Contrato, Consentimiento y Depósito en Recepción/Caja.</p>
                            </div>
                            <button type="button" id="btn-skip-step2-urgencia" class="btn btn-sm btn-danger fw-bold" onclick="guardarPaso2RecepcionCaja(true)">
                                <i class="bi bi-fast-forward-fill me-1"></i>Saltar a Paso 3 en Paralelo (Alerta Roja)
                            </button>
                        </div>
                    </div>

                    <div class="row g-3">
                        <!-- Bloque 1: Recepción y Consentimiento Informado -->
                        <div class="col-12 col-md-6">
                            <div class="p-3 rounded-3 border bg-light h-100">
                                <h6 class="fw-bold text-navy border-bottom pb-2 mb-2.5">
                                    <i class="bi bi-file-earmark-medical text-primary me-1.5"></i>A. Contrato y Consentimiento Informado (NOM-004)
                                </h6>

                                <div class="form-check form-switch mb-2.5">
                                    <input class="form-check-input" type="checkbox" id="w_contrato_firmado">
                                    <label class="form-check-label fw-bold text-dark small" for="w_contrato_firmado">
                                        Contrato de Prestación de Servicios Hospitalarios Firmado
                                    </label>
                                </div>

                                <div class="form-check form-switch mb-3">
                                    <input class="form-check-input" type="checkbox" id="w_consentimiento_firmado">
                                    <label class="form-check-label fw-bold text-dark small" for="w_consentimiento_firmado">
                                        Carta de Consentimiento Informado Quirúrgico y Anestésico Firmada
                                    </label>
                                </div>

                                <div class="mb-2">
                                    <label class="form-label small fw-bold text-muted mb-1">Nombre Completo del Firmante (Paciente o Representante Legal) *</label>
                                    <input type="text" id="w_nombre_firmante" class="form-control form-control-sm fw-semibold" placeholder="Nombre de quien firma el consentimiento" />
                                </div>

                                <div class="row g-2">
                                    <div class="col-6">
                                        <label class="form-label small fw-bold text-muted mb-1">Parentesco / Calidad</label>
                                        <select id="w_parentesco_firmante" class="form-select form-select-sm">
                                            <option value="Titular / Paciente">Titular / Paciente</option>
                                            <option value="Cónyuge">Cónyuge</option>
                                            <option value="Padre / Madre">Padre / Madre</option>
                                            <option value="Hijo(a)">Hijo(a)</option>
                                            <option value="Hermano(a)">Hermano(a)</option>
                                            <option value="Tutor / Representante Legal">Tutor / Representante Legal</option>
                                        </select>
                                    </div>
                                    <div class="col-6">
                                        <label class="form-label small fw-bold text-muted mb-1">Fecha / Hora de Firma</label>
                                        <input type="text" id="w_fecha_firma" class="form-control form-control-sm" placeholder="Automático al guardar" />
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Bloque 2: Depósito en Caja ($5,000.00) -->
                        <div class="col-12 col-md-6">
                            <div class="p-3 rounded-3 border bg-light h-100">
                                <div class="d-flex justify-content-between align-items-center border-bottom pb-2 mb-2.5">
                                    <h6 class="fw-bold text-navy mb-0">
                                        <i class="bi bi-cash-stack text-success me-1.5"></i>B. Depósito de Ingreso en Caja
                                    </h6>
                                    <div id="lbl-folio-recibo-deposito"></div>
                                </div>

                                <div class="alert alert-info py-2 px-2.5 small mb-2.5">
                                    <i class="bi bi-info-circle-fill me-1"></i>El depósito estándar a cuenta de cirugía es de <strong>\$5,000.00 MXN</strong> y se deduce automáticamente en el Corte de Caja del Paso 6.
                                </div>

                                <div class="row g-2 mb-3">
                                    <div class="col-6">
                                        <label class="form-label small fw-bold text-muted mb-1">Monto de Depósito (\$ MXN)</label>
                                        <input type="number" step="0.01" id="w_deposito_monto" class="form-control form-control-sm fw-bold text-success fs-6" value="5000.00" />
                                    </div>
                                    <div class="col-6">
                                        <label class="form-label small fw-bold text-muted mb-1">Método de Pago</label>
                                        <select id="w_metodo_pago_deposito" class="form-select form-select-sm fw-semibold">
                                            <option value="Efectivo">Efectivo</option>
                                            <option value="Tarjeta">Tarjeta Crédito / Débito</option>
                                            <option value="Transferencia">Transferencia SPEI</option>
                                        </select>
                                    </div>
                                </div>

                                <div class="form-check form-switch p-2.5 bg-white rounded border">
                                    <input class="form-check-input ms-0 me-2" type="checkbox" id="w_deposito_pagado">
                                    <label class="form-check-label fw-bold text-success small" for="w_deposito_pagado">
                                        Confirmar Cobro de Depósito y Emitir Recibo Oficial en Caja
                                    </label>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="d-flex justify-content-between mt-4 pt-3 border-top">
                        <button type="button" class="btn btn-outline-secondary btn-mobile-standard" onclick="irAPaso(1)">
                            <i class="bi bi-arrow-left me-1"></i>Paso 1
                        </button>
                        <button type="button" class="btn btn-success btn-mobile-standard fw-bold px-4" onclick="guardarPaso2RecepcionCaja(false)">
                            <i class="bi bi-check2-circle me-1.5"></i>Validar Recepción y Caja e Ir a Pre-Operatorio <i class="bi bi-arrow-right ms-1"></i>
                        </button>
                    </div>
                </div>

                <!-- =========================================================
                     PASO 3: PRE-OPERATORIO (ENFERMERÍA + INSUMOS 3NF PRE_OP)
                     ========================================================= -->
                <div class="qx-stage-panel" data-panel-step="3">
                    <div class="d-flex justify-content-between align-items-center border-bottom pb-2.5 mb-3">
                        <div>
                            <h5 class="fw-bold text-navy mb-0"><i class="bi bi-clipboard2-pulse-fill text-warning me-2"></i>Paso 3: Pre-Operatorio (Enfermería y Checklist OMS)</h5>
                            <p class="text-muted small mb-0">Signos vitales de ingreso, folio físico, habitación y carga de insumos etapa <code>PRE_OP</code>.</p>
                        </div>
                        <span class="badge bg-warning text-dark fw-bold">Paso 3 de 6</span>
                    </div>

                    <div class="row g-2.5 mb-3">
                        <div class="col-6 col-md-3">
                            <label class="form-label small fw-bold text-muted mb-1">Folio Expediente Físico *</label>
                            <input type="text" id="w_expediente_fisico" class="form-control form-control-sm fw-bold text-primary" placeholder="EXP-FIS-..." />
                        </div>
                        <div class="col-6 col-md-3">
                            <label class="form-label small fw-bold text-muted mb-1">Habitación / Cubículo Pre-Op *</label>
                            <input type="text" id="w_habitacion_asignada" class="form-control form-control-sm fw-bold" value="HAB-101" />
                        </div>
                        <div class="col-3 col-md-1.5">
                            <label class="form-label small fw-bold text-muted mb-1">T.A. (mmHg)</label>
                            <input type="text" id="w_sv_ta" class="form-control form-control-sm text-center fw-bold" value="120/80" />
                        </div>
                        <div class="col-3 col-md-1.5">
                            <label class="form-label small fw-bold text-muted mb-1">F.C. (lpm)</label>
                            <input type="text" id="w_sv_fc" class="form-control form-control-sm text-center fw-bold" value="74" />
                        </div>
                        <div class="col-3 col-md-1.5">
                            <label class="form-label small fw-bold text-muted mb-1">Temp (°C)</label>
                            <input type="text" id="w_sv_temp" class="form-control form-control-sm text-center fw-bold" value="36.6" />
                        </div>
                        <div class="col-3 col-md-1.5">
                            <label class="form-label small fw-bold text-muted mb-1">SpO2 (%)</label>
                            <input type="text" id="w_sv_spo2" class="form-control form-control-sm text-center fw-bold" value="98" />
                        </div>
                    </div>

                    <!-- Checklist Pre-Op OMS -->
                    <div class="p-2.5 rounded-3 border bg-light mb-3">
                        <div class="small fw-bold text-navy mb-2"><i class="bi bi-shield-fill-check text-success me-1"></i>Checklist de Cirugía Segura OMS (Pre-Ingreso a Sala)</div>
                        <div class="row g-2 small">
                            <div class="col-6 col-md-4">
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_chk_identidad" checked><label class="form-check-label fw-semibold" for="w_chk_identidad">Identidad y pulsera verificadas</label></div>
                            </div>
                            <div class="col-6 col-md-4">
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_chk_ayuno" checked><label class="form-check-label fw-semibold" for="w_chk_ayuno">Ayuno preoperatorio confirmado</label></div>
                            </div>
                            <div class="col-6 col-md-4">
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_chk_labs" checked><label class="form-check-label fw-semibold" for="w_chk_labs">Laboratorios y riesgo validados</label></div>
                            </div>
                            <div class="col-6 col-md-4">
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_chk_sitio" checked><label class="form-check-label fw-semibold" for="w_chk_sitio">Marcaje del sitio quirúrgico</label></div>
                            </div>
                            <div class="col-6 col-md-4">
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_chk_via" checked><label class="form-check-label fw-semibold" for="w_chk_via">Vía venosa permeable instalada</label></div>
                            </div>
                            <div class="col-6 col-md-4">
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_chk_profilaxis" checked><label class="form-check-label fw-semibold" for="w_chk_profilaxis">Profilaxis antibiótica administrada</label></div>
                            </div>
                        </div>
                        <div class="mt-2">
                            <input type="text" id="w_obs_enfermeria" class="form-control form-control-sm" placeholder="Observaciones de enfermería preoperatoria..." />
                        </div>
                    </div>

                    <!-- Widget Reutilizable 3NF Etapa PRE_OP -->
                    <div id="widget-3nf-PRE_OP"></div>

                    <div class="d-flex flex-wrap justify-content-between gap-2 mt-4 pt-3 border-top">
                        <button type="button" class="btn btn-outline-secondary btn-mobile-standard" onclick="irAPaso(2)">
                            <i class="bi bi-arrow-left me-1"></i>Paso 2
                        </button>
                        <div class="d-flex gap-2">
                            <button type="button" class="btn btn-outline-primary btn-mobile-standard fw-semibold" onclick="guardarPaso3PreOp(false)">
                                <i class="bi bi-floppy me-1"></i>Guardar Avance Pre-Op
                            </button>
                            <button type="button" class="btn btn-danger btn-mobile-standard fw-bold px-3" onclick="guardarPaso3PreOp(true)">
                                <i class="bi bi-door-open-fill me-1.5"></i>Ingresar Paciente a Quirófano (Paso 4) <i class="bi bi-arrow-right ms-1"></i>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- =========================================================
                     PASO 4: TRANSOPERATORIO (QUIRÓFANO + INSUMOS 3NF QUIROFANO)
                     ========================================================= -->
                <div class="qx-stage-panel" data-panel-step="4">
                    <div class="d-flex justify-content-between align-items-center border-bottom pb-2.5 mb-3">
                        <div>
                            <h5 class="fw-bold text-navy mb-0"><i class="bi bi-activity text-danger me-2"></i>Paso 4: Transoperatorio (Quirófano en Vivo)</h5>
                            <p class="text-muted small mb-0">Cronología quirúrgica, conteo de textiles/instrumental, nota NOM-004 y consumo 3NF etapa <code>QUIROFANO</code>.</p>
                        </div>
                        <span class="badge bg-danger text-white fw-bold">Paso 4 de 6</span>
                    </div>

                    <div class="row g-2 mb-3">
                        <div class="col-6 col-md-2.4">
                            <label class="form-label small fw-bold text-muted mb-1">Ingreso a Sala</label>
                            <input type="time" id="w_hora_ingreso_sala" class="form-control form-control-sm fw-bold" />
                        </div>
                        <div class="col-6 col-md-2.4">
                            <label class="form-label small fw-bold text-muted mb-1">Inicio Anestesia</label>
                            <input type="time" id="w_hora_anestesia" class="form-control form-control-sm fw-bold" />
                        </div>
                        <div class="col-6 col-md-2.4">
                            <label class="form-label small fw-bold text-danger mb-1">Hora Incisión *</label>
                            <input type="time" id="w_hora_incision" class="form-control form-control-sm fw-bold border-danger" />
                        </div>
                        <div class="col-6 col-md-2.4">
                            <label class="form-label small fw-bold text-success mb-1">Hora Cierre *</label>
                            <input type="time" id="w_hora_cierre" class="form-control form-control-sm fw-bold border-success" />
                        </div>
                        <div class="col-12 col-md-2.4">
                            <label class="form-label small fw-bold text-muted mb-1">Salida a UCPA</label>
                            <input type="time" id="w_hora_salida_sala" class="form-control form-control-sm fw-bold" />
                        </div>
                    </div>

                    <div class="row g-2.5 mb-3">
                        <div class="col-12 col-md-4">
                            <label class="form-label small fw-bold text-muted mb-1">Diagnóstico Pre-Operatorio</label>
                            <input type="text" id="w_diag_preop" class="form-control form-control-sm" />
                        </div>
                        <div class="col-12 col-md-4">
                            <label class="form-label small fw-bold text-muted mb-1">Diagnóstico Post-Operatorio (NOM-004)</label>
                            <input type="text" id="w_diag_postop" class="form-control form-control-sm fw-semibold" />
                        </div>
                        <div class="col-8 col-md-3">
                            <label class="form-label small fw-bold text-muted mb-1">Operación Realizada</label>
                            <input type="text" id="w_op_realizada" class="form-control form-control-sm fw-semibold" />
                        </div>
                        <div class="col-4 col-md-1">
                            <label class="form-label small fw-bold text-muted mb-1">Sangrado(ml)</label>
                            <input type="number" id="w_sangrado_ml" class="form-control form-control-sm text-center" value="50" />
                        </div>
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-bold text-muted mb-1">Descripción de Técnica Quirúrgica</label>
                            <textarea id="w_desc_tecnica" class="form-control form-control-sm" rows="2" placeholder="Asepsia y antisepsia, abordaje, disección, hemostasia y síntesis por planos..."></textarea>
                        </div>
                        <div class="col-12 col-md-6">
                            <label class="form-label small fw-bold text-muted mb-1">Hallazgos Transoperatorios y Conteo de Seguridad</label>
                            <textarea id="w_hallazgos" class="form-control form-control-sm mb-1.5" rows="1" placeholder="Hallazgos anatómicos relevantes..."></textarea>
                            <div class="d-flex flex-wrap gap-3 small">
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_cnt_gasas" checked><label class="form-check-label fw-bold text-success" for="w_cnt_gasas">Gasas 100% OK</label></div>
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_cnt_compresas" checked><label class="form-check-label fw-bold text-success" for="w_cnt_compresas">Compresas 100% OK</label></div>
                                <div class="form-check"><input class="form-check-input" type="checkbox" id="w_cnt_instrumental" checked><label class="form-check-label fw-bold text-success" for="w_cnt_instrumental">Instrumental 100% OK</label></div>
                            </div>
                        </div>
                    </div>

                    <!-- Widget Reutilizable 3NF Etapa QUIROFANO -->
                    <div id="widget-3nf-QUIROFANO"></div>

                    <div class="d-flex flex-wrap justify-content-between gap-2 mt-4 pt-3 border-top">
                        <button type="button" class="btn btn-outline-secondary btn-mobile-standard" onclick="irAPaso(3)">
                            <i class="bi bi-arrow-left me-1"></i>Paso 3
                        </button>
                        <div class="d-flex gap-2">
                            <button type="button" class="btn btn-outline-primary btn-mobile-standard fw-semibold" onclick="guardarPaso4TransOp(false)">
                                <i class="bi bi-floppy me-1"></i>Guardar Nota Transoperatoria
                            </button>
                            <button type="button" class="btn btn-primary btn-mobile-standard fw-bold px-3" onclick="guardarPaso4TransOp(true)">
                                <i class="bi bi-hospital me-1.5"></i>Pasar Paciente a Recuperación UCPA (Paso 5) <i class="bi bi-arrow-right ms-1"></i>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- =========================================================
                     PASO 5: POSTOPERATORIO (RECUPERACIÓN UCPA + INSUMOS 3NF RECUPERACION)
                     ========================================================= -->
                <div class="qx-stage-panel" data-panel-step="5">
                    <div class="d-flex justify-content-between align-items-center border-bottom pb-2.5 mb-3">
                        <div>
                            <h5 class="fw-bold text-navy mb-0"><i class="bi bi-bandaid-fill text-primary me-2"></i>Paso 5: Postoperatorio y Recuperación (UCPA - Escala Aldrete)</h5>
                            <p class="text-muted small mb-0">Valoración post-anestésica, traslado a habitación y consumo 3NF etapa <code>RECUPERACION</code>.</p>
                        </div>
                        <span class="badge bg-primary text-white fw-bold">Paso 5 de 6</span>
                    </div>

                    <div class="row g-3 mb-3">
                        <div class="col-6 col-md-3">
                            <label class="form-label small fw-bold text-muted mb-1">Cama / Bahía UCPA</label>
                            <input type="text" id="w_cama_ucpa" class="form-control form-control-sm fw-bold" value="UCPA-01" />
                        </div>
                        <div class="col-6 col-md-3">
                            <label class="form-label small fw-bold text-muted mb-1">Habitación de Traslado</label>
                            <input type="text" id="w_hab_traslado" class="form-control form-control-sm fw-bold text-primary" value="HAB-101" />
                        </div>
                        <div class="col-12 col-md-6 d-flex align-items-end justify-content-between">
                            <div>
                                <span class="d-block small fw-bold text-muted">Puntaje Escala de Aldrete (Mínimo 9/10 para Alta):</span>
                                <span id="w_aldrete_badge" class="badge bg-success px-3 py-1.5 fs-6">10 / 10 pts (APTO PARA ALTA)</span>
                            </div>
                        </div>
                    </div>

                    <div class="row g-2 mb-3 p-2.5 bg-light rounded border">
                        <div class="col-6 col-md-2.4">
                            <label class="form-label small fw-bold mb-1">1. Actividad Motora</label>
                            <select id="w_ald_act" class="form-select form-select-sm" onchange="recalcularAldreteWizard()">
                                <option value="2">2 - Mueve 4 extremidades</option>
                                <option value="1">1 - Mueve 2 extremidades</option>
                                <option value="0">0 - Inmóvil</option>
                            </select>
                        </div>
                        <div class="col-6 col-md-2.4">
                            <label class="form-label small fw-bold mb-1">2. Respiración</label>
                            <select id="w_ald_res" class="form-select form-select-sm" onchange="recalcularAldreteWizard()">
                                <option value="2">2 - Respira profundo y tose</option>
                                <option value="1">1 - Disnea / superficial</option>
                                <option value="0">0 - Apnea</option>
                            </select>
                        </div>
                        <div class="col-6 col-md-2.4">
                            <label class="form-label small fw-bold mb-1">3. Circulación (TA)</label>
                            <select id="w_ald_cir" class="form-select form-select-sm" onchange="recalcularAldreteWizard()">
                                <option value="2">2 - TA ±20% basal</option>
                                <option value="1">1 - TA ±20-50% basal</option>
                                <option value="0">0 - TA >50% basal</option>
                            </select>
                        </div>
                        <div class="col-6 col-md-2.4">
                            <label class="form-label small fw-bold mb-1">4. Conciencia</label>
                            <select id="w_ald_con" class="form-select form-select-sm" onchange="recalcularAldreteWizard()">
                                <option value="2">2 - Alerta y orientado</option>
                                <option value="1">1 - Despierta al llamado</option>
                                <option value="0">0 - No responde</option>
                            </select>
                        </div>
                        <div class="col-12 col-md-2.4">
                            <label class="form-label small fw-bold mb-1">5. Saturación SpO2</label>
                            <select id="w_ald_sat" class="form-select form-select-sm" onchange="recalcularAldreteWizard()">
                                <option value="2">2 - SpO2 >92% aire amb.</option>
                                <option value="1">1 - Requiere O2 para >90%</option>
                                <option value="0">0 - SpO2 <90% con O2</option>
                            </select>
                        </div>
                        <div class="col-12 mt-2">
                            <label class="form-label small fw-bold text-muted mb-1">Nota de Evolución y Valoración Postoperatoria</label>
                            <input type="text" id="w_val_postop" class="form-control form-control-sm" placeholder="Paciente consciente, tolerando vía oral, herida quirúrgica limpia y sin sangrado activo..." />
                        </div>
                    </div>

                    <!-- Widget Reutilizable 3NF Etapa RECUPERACION -->
                    <div id="widget-3nf-RECUPERACION"></div>

                    <div class="d-flex flex-wrap justify-content-between gap-2 mt-4 pt-3 border-top">
                        <button type="button" class="btn btn-outline-secondary btn-mobile-standard" onclick="irAPaso(4)">
                            <i class="bi bi-arrow-left me-1"></i>Paso 4
                        </button>
                        <div class="d-flex gap-2">
                            <button type="button" class="btn btn-outline-primary btn-mobile-standard fw-semibold" onclick="guardarPaso5Recuperacion(false)">
                                <i class="bi bi-floppy me-1"></i>Guardar Valoración UCPA
                            </button>
                            <button type="button" class="btn btn-success btn-mobile-standard fw-bold px-3" onclick="guardarPaso5Recuperacion(true)">
                                <i class="bi bi-clipboard2-check-fill me-1.5"></i>Continuar a Alta, Receta y Corte de Caja (Paso 6) <i class="bi bi-arrow-right ms-1"></i>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- =========================================================
                     PASO 6: ALTA, RECETA MÉDICA CIE-10 Y CORTE DE CAJA AUTOMÁTICO
                     ========================================================= -->
                <div class="qx-stage-panel" data-panel-step="6">
                    <div class="d-flex flex-wrap justify-content-between align-items-center border-bottom pb-2.5 mb-3 gap-2">
                        <div>
                            <h5 class="fw-bold text-navy mb-0"><i class="bi bi-award-fill text-success me-2"></i>Paso 6: Alta Quirúrgica, Receta Médica y Corte de Caja Automático</h5>
                            <p class="text-muted small mb-0">Prescripción de egreso con CIE-10, liquidación de insumos 3NF menos depósito y emisión de Pase de Salida.</p>
                        </div>
                        <div id="badge-pase-salida-status"></div>
                    </div>

                    <div class="row g-3">
                        <!-- Columna Izquierda: Receta Médica de Alta -->
                        <div class="col-12 col-lg-7">
                            <div class="p-3 rounded-3 border bg-light h-100">
                                <h6 class="fw-bold text-navy border-bottom pb-2 mb-2.5">
                                    <i class="bi bi-prescription2 text-primary me-1.5"></i>A. Receta Médica de Alta Quirúrgica (NOM-004 / NOM-024)
                                </h6>

                                <div class="mb-2.5">
                                    <label class="form-label small fw-bold text-navy mb-1">Diagnóstico Definitivo de Egreso (CIE-10) *</label>
                                    <input type="text" id="w_rec_cie10" class="form-control form-control-sm fw-bold" placeholder="Ej. K80.2 - Cálculo de la vesícula biliar sin colecistitis" />
                                </div>

                                <!-- Mini formulario para agregar medicamentos -->
                                <div class="row g-1.5 align-items-end mb-2 bg-white p-2 rounded border">
                                    <div class="col-12 col-md-4">
                                        <label class="form-label small fw-bold text-muted mb-0.5" style="font-size:0.7rem;">Fármaco y Presentación</label>
                                        <input type="text" id="rec_add_farmaco" class="form-control form-control-sm" placeholder="Ketorolaco 10mg Tab" />
                                    </div>
                                    <div class="col-6 col-md-2">
                                        <label class="form-label small fw-bold text-muted mb-0.5" style="font-size:0.7rem;">Dosis</label>
                                        <input type="text" id="rec_add_dosis" class="form-control form-control-sm" placeholder="1 tableta" />
                                    </div>
                                    <div class="col-6 col-md-2">
                                        <label class="form-label small fw-bold text-muted mb-0.5" style="font-size:0.7rem;">Vía</label>
                                        <select id="rec_add_via" class="form-select form-select-sm">
                                            <option value="Oral">Oral</option>
                                            <option value="IM">IM</option>
                                            <option value="IV">IV</option>
                                            <option value="Sublingual">Sublingual</option>
                                            <option value="Tópica">Tópica</option>
                                        </select>
                                    </div>
                                    <div class="col-6 col-md-2">
                                        <label class="form-label small fw-bold text-muted mb-0.5" style="font-size:0.7rem;">Frecuencia</label>
                                        <input type="text" id="rec_add_frecuencia" class="form-control form-control-sm" placeholder="Cada 8 h" />
                                    </div>
                                    <div class="col-6 col-md-2">
                                        <label class="form-label small fw-bold text-muted mb-0.5" style="font-size:0.7rem;">Duración</label>
                                        <div class="input-group input-group-sm">
                                            <input type="text" id="rec_add_duracion" class="form-control" placeholder="5 días" />
                                            <button type="button" class="btn btn-primary fw-bold" onclick="agregarMedicamentoReceta()" title="Agregar a Receta">+</button>
                                        </div>
                                    </div>
                                </div>

                                <div class="table-responsive bg-white rounded border mb-2.5">
                                    <table class="table table-sm align-middle mb-0" style="font-size:0.76rem;">
                                        <thead class="table-light">
                                            <tr>
                                                <th>Fármaco</th>
                                                <th>Dosis</th>
                                                <th>Vía</th>
                                                <th>Frecuencia</th>
                                                <th>Duración</th>
                                                <th></th>
                                            </tr>
                                        </thead>
                                        <tbody id="tbody-receta-meds"></tbody>
                                    </table>
                                </div>

                                <div>
                                    <label class="form-label small fw-bold text-navy mb-1">Indicaciones Generales de Alta y Signos de Alarma</label>
                                    <textarea id="w_rec_indicaciones" class="form-control form-control-sm" rows="2"></textarea>
                                </div>
                            </div>
                        </div>

                        <!-- Columna Derecha: Corte de Caja Automático -->
                        <div class="col-12 col-lg-5">
                            <div class="p-3 rounded-3 border bg-white shadow-sm h-100">
                                <h6 class="fw-bold text-navy border-bottom pb-2 mb-2.5">
                                    <i class="bi bi-calculator-fill text-teal me-1.5"></i>B. Corte de Caja Automático (3NF + Sala - Depósito)
                                </h6>

                                <div class="row g-2 mb-2.5">
                                    <div class="col-6">
                                        <label class="form-label small fw-bold text-muted mb-1">Horas de Uso de Sala</label>
                                        <input type="number" step="0.5" id="w_corte_horas_sala" class="form-control form-control-sm fw-bold" value="2" oninput="renderCorteDeCaja()" />
                                    </div>
                                    <div class="col-6">
                                        <label class="form-label small fw-bold text-muted mb-1">Tarifa por Hora (\$)</label>
                                        <input type="number" step="50" id="w_corte_costo_hora" class="form-control form-control-sm fw-bold" value="2500" oninput="renderCorteDeCaja()" />
                                    </div>
                                </div>

                                <div class="bg-light p-2.5 rounded border small mb-2.5">
                                    <div class="d-flex justify-content-between py-1 border-bottom">
                                        <span class="text-muted">Insumos 3NF Etapa <code>PRE_OP</code>:</span>
                                        <strong id="corte-sub-preop">\$0.00</strong>
                                    </div>
                                    <div class="d-flex justify-content-between py-1 border-bottom">
                                        <span class="text-muted">Insumos 3NF Etapa <code>QUIROFANO</code>:</span>
                                        <strong id="corte-sub-qx">\$0.00</strong>
                                    </div>
                                    <div class="d-flex justify-content-between py-1 border-bottom">
                                        <span class="text-muted">Insumos 3NF Etapa <code>RECUPERACION</code>:</span>
                                        <strong id="corte-sub-ucpa">\$0.00</strong>
                                    </div>
                                    <div class="d-flex justify-content-between py-1 border-bottom text-primary">
                                        <span class="fw-bold">Subtotal Insumos Consumidos (3NF):</span>
                                        <strong id="corte-sub-insumos">\$0.00</strong>
                                    </div>
                                    <div class="d-flex justify-content-between py-1 border-bottom">
                                        <span class="fw-semibold">Renta de Sala de Quirófano:</span>
                                        <strong id="corte-sub-sala">\$5,000.00</strong>
                                    </div>
                                    <div class="d-flex justify-content-between py-1 border-bottom">
                                        <span class="fw-bold text-dark">Total Bruto de Cirugía:</span>
                                        <strong id="corte-total-bruto">\$5,000.00</strong>
                                    </div>
                                    <div class="d-flex justify-content-between py-1 border-bottom text-success">
                                        <span class="fw-bold"><i class="bi bi-check-circle me-1"></i>Menos Depósito de Ingreso en Caja:</span>
                                        <strong id="corte-deposito-aplicado">-\$5,000.00</strong>
                                    </div>
                                    <div class="d-flex justify-content-between pt-2 fs-5 fw-bold text-navy">
                                        <span>SALDO A LIQUIDAR:</span>
                                        <span id="corte-saldo-final" class="text-primary">\$0.00</span>
                                    </div>
                                </div>

                                <div class="p-2 rounded border bg-light mb-2">
                                    <div class="form-check form-switch mb-1.5">
                                        <input class="form-check-input" type="checkbox" id="w_liquidar_saldo_chk" checked>
                                        <label class="form-check-label small fw-bold text-dark" for="w_liquidar_saldo_chk">
                                            Liquidar saldo remanente en Caja y emitir Recibo de Finiquito
                                        </label>
                                    </div>
                                    <select id="w_metodo_finiquito" class="form-select form-select-sm">
                                        <option value="Efectivo">Pago en Efectivo</option>
                                        <option value="Tarjeta">Tarjeta Bancaria</option>
                                        <option value="Transferencia">Transferencia SPEI</option>
                                    </select>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-4 pt-3 border-top">
                        <button type="button" class="btn btn-outline-secondary btn-mobile-standard" onclick="irAPaso(5)">
                            <i class="bi bi-arrow-left me-1"></i>Paso 5
                        </button>
                        <div class="d-flex flex-wrap gap-2">
                            <button type="button" class="btn btn-outline-dark btn-mobile-standard fw-bold" onclick="abrirVistaImprimibleAlta()">
                                <i class="bi bi-printer-fill me-1.5"></i>Imprimir Resumen de Alta + Receta + Pase
                            </button>
                            <button type="button" class="btn btn-success btn-mobile-standard fw-bold px-4 shadow-sm" onclick="guardarPaso6AltaYCorte(true)">
                                <i class="bi bi-patch-check-fill me-1.5"></i>Generar Pase de Salida y Mover a ALTA / TRASLADO
                            </button>
                        </div>
                    </div>
                </div>

            </div>
        </section>

    </div>
</div>

<!-- MODAL: ALTA RÁPIDA DE PACIENTE -->
<div class="modal fade" id="modalQuickPatient" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header bg-navy text-white py-2.5" style="background:#0A2A66;">
                <h6 class="modal-title fw-bold mb-0"><i class="bi bi-person-plus-fill me-2"></i>Alta Rápida de Paciente Quirúrgico</h6>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div class="mb-2.5">
                    <label class="form-label small fw-bold">Nombre Completo del Paciente *</label>
                    <input type="text" id="qp_nombre" class="form-control form-control-sm" placeholder="Nombre(s) y Apellidos" />
                </div>
                <div class="row g-2">
                    <div class="col-6">
                        <label class="form-label small fw-bold">Teléfono</label>
                        <input type="text" id="qp_telefono" class="form-control form-control-sm" placeholder="10 dígitos" />
                    </div>
                    <div class="col-6">
                        <label class="form-label small fw-bold">Sexo</label>
                        <select id="qp_sexo" class="form-select form-select-sm">
                            <option value="Femenino">Femenino</option>
                            <option value="Masculino">Masculino</option>
                        </select>
                    </div>
                    <div class="col-6">
                        <label class="form-label small fw-bold">Fecha de Nacimiento</label>
                        <input type="date" id="qp_fecha_nac" class="form-control form-control-sm" value="1985-05-15" />
                    </div>
                    <div class="col-6">
                        <label class="form-label small fw-bold">Grupo y Rh</label>
                        <select id="qp_sangre" class="form-select form-select-sm">
                            <option value="O+">O+</option>
                            <option value="O-">O-</option>
                            <option value="A+">A+</option>
                            <option value="A-">A-</option>
                            <option value="B+">B+</option>
                            <option value="AB+">AB+</option>
                        </select>
                    </div>
                </div>
            </div>
            <div class="modal-footer py-2">
                <button type="button" class="btn btn-sm btn-light border" data-bs-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-sm btn-primary fw-bold" onclick="guardarPacienteRapido()">Guardar y Seleccionar</button>
            </div>
        </div>
    </div>
</div>

<!-- MODAL: NUEVO INSUMO AL CATÁLOGO UNIVERSAL 3NF -->
<div class="modal fade" id="modalNuevoInsumo3NF" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content border-0 shadow">
            <div class="modal-header bg-navy text-white py-2.5" style="background:#0A2A66;">
                <h6 class="modal-title fw-bold mb-0"><i class="bi bi-box-seam-fill me-2"></i>Agregar Insumo al Catálogo Universal (3NF)</h6>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div class="row g-2">
                    <div class="col-8">
                        <label class="form-label small fw-bold">Nombre del Insumo / Medicamento *</label>
                        <input type="text" id="mdl3nf_nombre" class="form-control form-control-sm" placeholder="Ej. Sevoflurano 250ml" />
                    </div>
                    <div class="col-4">
                        <label class="form-label small fw-bold">Código SKU</label>
                        <input type="text" id="mdl3nf_sku" class="form-control form-control-sm" placeholder="SKU-MED-09" />
                    </div>
                    <div class="col-7">
                        <label class="form-label small fw-bold">Categoría Normalizada (FK)</label>
                        <select id="mdl3nf_categoria" class="form-select form-select-sm"></select>
                    </div>
                    <div class="col-5">
                        <label class="form-label small fw-bold">Unidad Medida (FK)</label>
                        <select id="mdl3nf_unidad" class="form-select form-select-sm"></select>
                    </div>
                    <div class="col-6">
                        <label class="form-label small fw-bold">Precio Unitario (\$ MXN) *</label>
                        <input type="number" step="0.01" id="mdl3nf_precio" class="form-control form-control-sm fw-bold" placeholder="450.00" />
                    </div>
                    <div class="col-6">
                        <label class="form-label small fw-bold">Stock Inicial</label>
                        <input type="number" id="mdl3nf_stock" class="form-control form-control-sm" value="50" />
                    </div>
                </div>
            </div>
            <div class="modal-footer py-2">
                <button type="button" class="btn btn-sm btn-light border" data-bs-dismiss="modal">Cancelar</button>
                <button type="button" class="btn btn-sm btn-primary fw-bold" onclick="guardarNuevoInsumoCatalogo3NF()">Registrar en Catálogo 3NF</button>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/quirofano_wizard.js"></script>
HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('hospital');
print "</body></html>\n";
1;
