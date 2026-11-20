#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use File::Spec;
use open qw(:std :utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_empresa = $sd->{id_empresa};
$id_empresa = '0' if (!defined $id_empresa || $id_empresa eq '');

# Validación estricta de rol RBAC (exclusivo para Administrador de Organización)
if ($role ne 'Administrador Organizacion') {
    render_acceso_denegado(
        q => $q, usuario => $usuario, role => $role,
        mensaje => 'Esta sección es de acceso exclusivo para el Administrador de la Organización.',
        rol_requerido => 'Administrador Organización'
    );
    exit;
}

print $q->header(
    -type => 'text/html',
    -charset => 'UTF-8',
    -cache_control => 'no-store, no-cache, must-revalidate, max-age=0',
    -pragma => 'no-cache'
);

render_header(
    usuario     => $usuario,
    role        => $role,
    titulo      => "Reset Operativo de Organización",
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'reset_datos_org');

# Detección de Capacidades SaaS y Tipo de Organización
my $tipo_organizacion = 'Clínica';
my $has_pacientes_estado = 0;
my $clue_org = '';

my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $cfg_file = File::Spec->catfile($dat_dir, 'negocios_config.dat');
if (-e $cfg_file && open(my $fh_cfg, '<:encoding(UTF-8)', $cfg_file)) {
    my $cnt = 0;
    while (my $line = <$fh_cfg>) {
        $cnt++;
        $line =~ s/\R//g;
        next if $cnt == 1 || $line =~ /^\s*$/;
        my @f = split(/\|/, $line);
        if ($f[0] eq $id_empresa) {
            if ($f[1] eq 'TIPO_ORGANIZACION') { $tipo_organizacion = $f[2] // 'Clínica'; }
            elsif ($f[1] eq 'PACIENTES_ESTADO') { $has_pacientes_estado = ($f[2] eq '1') ? 1 : 0; }
        }
    }
    close $fh_cfg;
}

my $neg_file = File::Spec->catfile($dat_dir, 'negocios.dat');
if (-e $neg_file && open(my $fn, '<:encoding(UTF-8)', $neg_file)) {
    <$fn>;
    while (my $line = <$fn>) {
        $line =~ s/\R//g;
        my @f = split(/\|/, $line, -1);
        if ($f[0] eq $id_empresa) {
            $clue_org = $f[18] // '';
            last;
        }
    }
    close $fn;
}
$clue_org ||= 'QTSMP000116' if ($id_empresa eq '0');

my $has_clue = ($clue_org ne '' && $clue_org ne 'No asignada' && $clue_org ne '0') ? 1 : 0;
my $es_consultorio_ind = ($tipo_organizacion eq 'Consultorio Individual' || $tipo_organizacion eq 'Consultorio Compartido') ? 1 : 0;
# Los folios públicos y personalización de folios públicos SOLO aplican si tiene CLUE y PACIENTES_ESTADO activo
my $maneja_folios_publicos = ($has_clue && $has_pacientes_estado && !$es_consultorio_ind) ? 1 : 0;

my $subtitulo_topbar = $maneja_folios_publicos 
    ? 'Limpieza de movimientos transaccionales y reinicio personalizado de folios institucionales'
    : 'Limpieza de movimientos transaccionales y reinicio de foliatura de caja del consultorio';

# Textos adaptados para Qué datos SE ELIMINAN
my $html_datos_eliminados = '';
if ($es_consultorio_ind) {
    $html_datos_eliminados = <<'HTML_DEL';
                                        <ul class="small text-muted mb-0 ps-3">
                                            <li class="mb-1">Recibos de cobro de caja rápida del consultorio.</li>
                                            <li class="mb-1">Historial de estado de cuenta y transacciones de caja.</li>
                                            <li class="mb-1">Citas en agenda médica e historial de movimientos.</li>
                                            <li class="mb-1">Consultas clínicas (SOAP), recetas, consentimientos y borradores.</li>
                                            <li class="mb-1">Odontogramas clínicos y planes de tratamiento dental.</li>
                                            <li class="mb-1">Registro de egresos y gastos operativos del consultorio.</li>
                                            <li>Cotizaciones, tratamientos y archivos adjuntos temporales.</li>
                                        </ul>
HTML_DEL
} else {
    $html_datos_eliminados = <<'HTML_DEL';
                                        <ul class="small text-muted mb-0 ps-3">
                                            <li class="mb-1">Recibos de cobro de caja rápida (privados y públicos / convenios).</li>
                                            <li class="mb-1">Historial de estado de cuenta y transacciones de caja.</li>
                                            <li class="mb-1">Citas en agenda médica e historial de movimientos.</li>
                                            <li class="mb-1">Consultas clínicas (SOAP), recetas, consentimientos y borradores.</li>
                                            <li class="mb-1">Odontogramas clínicos y planes de tratamiento dental.</li>
                                            <li class="mb-1">Registro de egresos y gastos operativos de la organización.</li>
                                            <li class="mb-1">Pacientes temporales de mostrador / caja rápida.</li>
                                            <li>Cotizaciones, tratamientos y archivos adjuntos temporales.</li>
                                        </ul>
HTML_DEL
}

# Textos adaptados para Qué datos SE CONSERVAN
my $html_datos_conservados = '';
if ($es_consultorio_ind) {
    $html_datos_conservados = <<'HTML_KEEP';
                                        <ul class="small text-muted mb-0 ps-3">
                                            <li class="mb-1"><strong>Médico titular y accesos</strong> (ID, credenciales, especialidad y cédula profesional).</li>
                                            <li class="mb-1">Catálogo de servicios y precios privados del consultorio.</li>
                                            <li class="mb-1">Categorías y fuentes de dinero de gastos configuradas.</li>
                                            <li class="mb-1">Expedientes clínicos y directorio base de pacientes.</li>
                                            <li class="mb-1">Plantillas y formatos médicos predefinidos.</li>
                                            <li>Configuración general y parámetros del consultorio.</li>
                                        </ul>
HTML_KEEP
} else {
    $html_datos_conservados = <<'HTML_KEEP';
                                        <ul class="small text-muted mb-0 ps-3">
                                            <li class="mb-1"><strong>Todos los usuarios del sistema</strong> (IDs, roles, correos, passwords de Médicos, Recepcionistas, Admins).</li>
                                            <li class="mb-1">Especialidades, médicos y catálogo de personal configurado.</li>
                                            <li class="mb-1">Catálogo universal de servicios, productos, categorías y departamentos.</li>
                                            <li class="mb-1">Matriz de tarifas y convenios institucionales (públicos y privados).</li>
                                            <li class="mb-1">Directorio de dependencias y empleados municipales.</li>
                                            <li>Configuración del tenant, clínica y parámetros del negocio.</li>
                                        </ul>
HTML_KEEP
}

# Sección de configuración de folios
my $html_seccion_folios = '';
if ($maneja_folios_publicos) {
    $html_seccion_folios = <<'HTML_FOLIOS';
                                <h5 class="fw-bold text-dark mb-2"><i class="bi bi-sliders me-2 text-primary"></i>Configuración de Folios Consecutivos Iniciales</h5>
                                <p class="text-muted small mb-4">Defina los números de folio a partir de los cuales se comenzará a emitir la foliatura en caja al concluir el reset:</p>

                                <div class="row g-3 mb-4">
                                    <div class="col-12 col-md-6">
                                        <label class="form-label fw-bold small text-secondary"><i class="bi bi-receipt me-1"></i>Folio Inicial de Recibos Privados</label>
                                        <div class="input-group input-group-lg">
                                            <span class="input-group-text bg-light fw-bold">#</span>
                                            <input type="number" min="1" step="1" class="form-control fw-bold" name="folio_privados" id="folio_privados" value="1" required>
                                        </div>
                                        <div class="form-text small">El primer recibo privado cobrado tendrá este número de folio.</div>
                                    </div>
                                    <div class="col-12 col-md-6">
                                        <label class="form-label fw-bold small text-secondary"><i class="bi bi-building me-1"></i>Folio Inicial de Recibos Públicos (Convenios)</label>
                                        <div class="input-group input-group-lg">
                                            <span class="input-group-text bg-light fw-bold">#</span>
                                            <input type="number" min="1" step="1" class="form-control fw-bold" name="folio_publicos" id="folio_publicos" value="1" required>
                                        </div>
                                        <div class="form-text small">El primer recibo público emitido tendrá este número de folio.</div>
                                    </div>
                                </div>
HTML_FOLIOS
} else {
    $html_seccion_folios = <<'HTML_FOLIOS_IND';
                                <h5 class="fw-bold text-dark mb-2"><i class="bi bi-sliders me-2 text-primary"></i>Configuración de Folio Inicial de Caja</h5>
                                <p class="text-muted small mb-3">Defina el número de folio con el que desea que inicie la foliatura de sus recibos de cobro en caja rápida (por defecto #1):</p>

                                <div class="row g-3 mb-4">
                                    <div class="col-12 col-md-6">
                                        <label class="form-label fw-bold small text-secondary"><i class="bi bi-receipt me-1"></i>Folio Inicial de Recibos Privados</label>
                                        <div class="input-group input-group-lg">
                                            <span class="input-group-text bg-light fw-bold">#</span>
                                            <input type="number" min="1" step="1" class="form-control fw-bold" name="folio_privados" id="folio_privados" value="1" required>
                                        </div>
                                        <div class="form-text small">El primer recibo cobrado en caja tendrá este número de folio. Si migra de otro sistema, puede especificar el número inicial correlativo.</div>
                                    </div>
                                </div>
HTML_FOLIOS_IND
}

print <<HTML;
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm mb-4" style="border-bottom-left-radius: 24px; border-bottom-right-radius: 24px;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-arrow-repeat me-2"></i>Reset Operativo de Organización</h2>
                    <p class="text-white-50 small mb-0 mt-1">$subtitulo_topbar</p>
                </div>
            </div>
        </header>

        <div class="container-fluid container-mobile-flush px-2 px-md-4 pb-5">
            <div class="row g-3">
                <div class="col-12">
                    <!-- TARJETA 1: AUDITORÍA Y PURGA FORENSE MULTI-MÓDULO DE DATOS / ARCHIVOS HUÉRFANOS -->
                    <div class="card card-medentia-aura card-mobile-flush border-0 shadow-sm rounded-4 mb-4" style="border-top: 4px solid #19B7A5 !important;">
                        <div class="card-body p-3 p-md-5">
                            <div class="d-flex flex-wrap justify-content-between align-items-center gap-3 mb-3 pb-3 border-bottom">
                                <div class="d-flex align-items-center gap-3">
                                    <div class="rounded-4 d-flex align-items-center justify-content-center shadow-sm" style="width: 52px; height: 52px; background: linear-gradient(135deg, #0A2A66, #19B7A5); color: #ffffff;">
                                        <i class="bi bi-shield-check fs-3"></i>
                                    </div>
                                    <div>
                                        <div class="d-flex align-items-center gap-2 flex-wrap">
                                            <h4 class="fw-black text-dark mb-0">Auditoría y Purga Multi-Módulo de Datos Huérfanos</h4>
                                            <span class="badge bg-info-subtle text-info-emphasis border border-info-subtle rounded-pill px-2.5 py-1 small fw-bold">5 Módulos Transversales • Padre → Hijo</span>
                                        </div>
                                        <p class="small text-muted mb-0 mt-1">
                                            Escanea y limpia exclusivamente registros o archivos sin relación padre válida en toda la organización. Puedes filtrar por módulo, seleccionar qué registros depurar con checkboxes o eliminarlos 1 a 1 con el botón de basura de cada fila. <strong>Jamás afecta cirugías, rentas, consultas, Caja Rápida ni gastos activos.</strong>
                                        </p>
                                    </div>
                                </div>
                                <div class="d-flex align-items-center gap-2 ms-auto">
                                    <button type="button" id="btnScanOrphans" onclick="escanearHuerfanosOrg()" class="btn btn-mobile-standard btn-outline-primary fw-bold px-3 py-2 rounded-3">
                                        <i class="bi bi-search me-1.5"></i>Escanear Módulos
                                    </button>
                                    <button type="button" id="btnPurgeOrphans" onclick="purgarHuerfanosSeleccionados()" class="btn btn-mobile-standard btn-teal text-white fw-bold px-3.5 py-2 rounded-3 shadow-sm d-none" style="background-color: #19B7A5;">
                                        <i class="bi bi-trash3-fill me-1.5"></i>Purgar Seleccionados (<span id="lblCountPurgeBtn">0</span>)
                                    </button>
                                </div>
                            </div>

                            <!-- PÍLDORAS / CHECKBOXES DE LOS 5 MÓDULOS A AUDITAR -->
                            <div class="p-3 rounded-4 bg-white border mb-3 shadow-2xs">
                                <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-2">
                                    <span class="small fw-bold text-uppercase text-secondary" style="font-size: 0.72rem; letter-spacing: 0.4px;">
                                        <i class="bi bi-layers-fill text-teal me-1"></i>Módulos Incluidos en la Auditoría Relacional:
                                    </span>
                                    <div class="d-flex align-items-center gap-2">
                                        <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none fw-bold" style="font-size: 0.75rem; color: #19B7A5;" onclick="marcarTodosModulosHuerfanos(true)">Marcar todos</button>
                                        <span class="text-muted">•</span>
                                        <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none text-secondary" style="font-size: 0.75rem;" onclick="marcarTodosModulosHuerfanos(false)">Desmarcar</button>
                                    </div>
                                </div>
                                <div class="row g-2">
                                    <div class="col-12 col-sm-6 col-xl-4">
                                        <label class="d-flex align-items-center justify-content-between p-2 rounded-3 border bg-light cursor-pointer w-100">
                                            <span class="d-flex align-items-center gap-2 small fw-bold text-dark">
                                                <input type="checkbox" class="form-check-input mt-0 chk-modulo-huerfano" value="qx_espacios" checked onchange="escanearHuerfanosOrg()">
                                                <i class="bi bi-heart-pulse-fill text-danger"></i>
                                                <span>1. Quirófano &amp; Agenda Espacios</span>
                                            </span>
                                            <span class="badge bg-white text-dark border rounded-pill" id="cnt_mod_qx_espacios">0</span>
                                        </label>
                                    </div>
                                    <div class="col-12 col-sm-6 col-xl-4">
                                        <label class="d-flex align-items-center justify-content-between p-2 rounded-3 border bg-light cursor-pointer w-100">
                                            <span class="d-flex align-items-center gap-2 small fw-bold text-dark">
                                                <input type="checkbox" class="form-check-input mt-0 chk-modulo-huerfano" value="clinico_soap" checked onchange="escanearHuerfanosOrg()">
                                                <i class="bi bi-file-earmark-medical-fill text-primary"></i>
                                                <span>2. Consultas SOAP, Borradores &amp; Recetas</span>
                                            </span>
                                            <span class="badge bg-white text-dark border rounded-pill" id="cnt_mod_clinico_soap">0</span>
                                        </label>
                                    </div>
                                    <div class="col-12 col-sm-6 col-xl-4">
                                        <label class="d-flex align-items-center justify-content-between p-2 rounded-3 border bg-light cursor-pointer w-100">
                                            <span class="d-flex align-items-center gap-2 small fw-bold text-dark">
                                                <input type="checkbox" class="form-check-input mt-0 chk-modulo-huerfano" value="dental_cotizaciones" checked onchange="escanearHuerfanosOrg()">
                                                <i class="bi bi-receipt-cutoff text-warning"></i>
                                                <span>3. Cotizaciones, Tratamientos &amp; Odonto</span>
                                            </span>
                                            <span class="badge bg-white text-dark border rounded-pill" id="cnt_mod_dental_cotizaciones">0</span>
                                        </label>
                                    </div>
                                    <div class="col-12 col-sm-6 col-xl-6">
                                        <label class="d-flex align-items-center justify-content-between p-2 rounded-3 border bg-light cursor-pointer w-100">
                                            <span class="d-flex align-items-center gap-2 small fw-bold text-dark">
                                                <input type="checkbox" class="form-check-input mt-0 chk-modulo-huerfano" value="boveda_archivos" checked onchange="escanearHuerfanosOrg()">
                                                <i class="bi bi-folder2-open text-info"></i>
                                                <span>4. Bóveda PACS, Estudios &amp; Firmas PNG en Disco</span>
                                            </span>
                                            <span class="badge bg-white text-dark border rounded-pill" id="cnt_mod_boveda_archivos">0</span>
                                        </label>
                                    </div>
                                    <div class="col-12 col-sm-12 col-xl-6">
                                        <label class="d-flex align-items-center justify-content-between p-2 rounded-3 border bg-light cursor-pointer w-100">
                                            <span class="d-flex align-items-center gap-2 small fw-bold text-dark">
                                                <input type="checkbox" class="form-check-input mt-0 chk-modulo-huerfano" value="config_edo_cta" checked onchange="escanearHuerfanosOrg()">
                                                <i class="bi bi-sliders text-success"></i>
                                                <span>5. Configuraciones de Usuarios Eliminados &amp; Estado de Cuenta</span>
                                            </span>
                                            <span class="badge bg-white text-dark border rounded-pill" id="cnt_mod_config_edo_cta">0</span>
                                        </label>
                                    </div>
                                </div>
                            </div>

                            <div id="boxOrphansResult" class="p-3 rounded-4 bg-light border">
                                <div class="text-center py-3 text-muted small">
                                    <span class="spinner-border spinner-border-sm text-primary me-2" role="status"></span>
                                    Analizando integridad relacional de archivos <code>.dat</code>, <code>.json</code> y <code>uploads/</code>...
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- TARJETA 2: RESET OPERATIVO TOTAL DE LA ORGANIZACIÓN -->
                    <div class="card card-medentia-aura card-mobile-flush border-0 shadow-sm rounded-4 mb-4">
                        <div class="card-body p-3 p-md-5">
                            
                            <!-- Alerta Informativa de Alto Nivel -->
                            <div class="alert alert-warning border-0 rounded-4 p-3 p-md-4 mb-4 d-flex align-items-start gap-3 shadow-sm" style="background-color: #fffbeb; border-left: 5px solid #f59e0b !important;">
                                <i class="bi bi-exclamation-triangle-fill text-warning fs-2 flex-shrink-0"></i>
                                <div>
                                    <h5 class="fw-bold text-dark mb-1">Atención: Operación de Mantenimiento y Purga Operativa</h5>
                                    <p class="small text-muted mb-0">
                                        Esta herramienta permite purgar los datos transaccionales generados durante pruebas o periodos anteriores para iniciar la operación limpia de la organización.
                                    </p>
                                </div>
                            </div>

                            <div class="row g-3 g-md-4 mb-4">
                                <div class="col-12 col-md-6">
                                    <div class="p-3 p-md-4 rounded-4 bg-danger bg-opacity-10 border border-danger border-opacity-25 h-100 shadow-sm">
                                        <h6 class="fw-bold text-danger mb-2"><i class="bi bi-trash3-fill me-2"></i>¿Qué datos SE ELIMINAN? (Reset Operativo)</h6>
                                        $html_datos_eliminados
                                    </div>
                                </div>
                                <div class="col-12 col-md-6">
                                    <div class="p-3 p-md-4 rounded-4 bg-success bg-opacity-10 border border-success border-opacity-25 h-100 shadow-sm">
                                        <h6 class="fw-bold text-success mb-2"><i class="bi bi-shield-check me-2"></i>¿Qué datos SE CONSERVAN INTACTOS?</h6>
                                        $html_datos_conservados
                                    </div>
                                </div>
                            </div>

                            <!-- Contenedor de configuración de reset para JS -->
                            <div id="configReset" data-maneja-folios="$maneja_folios_publicos" data-es-individual="$es_consultorio_ind" style="display:none;"></div>

                            <!-- Formulario de Configuración de Folios y Ejecución -->
                            <form id="formResetOrg" onsubmit="ejecutarResetOrg(event)" class="mt-4 pt-4 border-top">
                                $html_seccion_folios

                                <div class="p-3 p-md-4 rounded-4 bg-light border mb-4 shadow-sm">
                                    <label class="form-label fw-bold small text-danger"><i class="bi bi-lock-fill me-1"></i>Confirmación de Seguridad Obligatoria</label>
                                    <p class="small text-muted mb-2">Para confirmar que comprende la purga de datos operativos, escriba la palabra <strong>CONFIRMAR</strong> en el siguiente campo:</p>
                                    <input type="text" class="form-control form-control-lg text-uppercase fw-bold text-danger font-monospace" name="confirmacion" id="confirmacion" placeholder="Escriba CONFIRMAR aquí" style="max-width: 360px; text-transform: uppercase;" required>
                                </div>

                                <div class="d-flex flex-column flex-sm-row justify-content-end gap-3 pt-2">
                                    <a href="../views/inicial.pl" class="btn btn-mobile-standard btn-mobile-outline btn-light border px-4 py-2">Cancelar</a>
                                    <button type="submit" id="btnSubmitReset" class="btn btn-mobile-standard btn-mobile-action btn-danger px-4 py-2 fw-bold shadow-sm">
                                        <i class="bi bi-arrow-counterclockwise me-2"></i>Ejecutar Reset de Organización
                                    </button>
                                </div>
                            </form>

                        </div>
                    </div>
                </div>
            </div>
        </div>
HTML

print <<'JS';
        <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
        <script>
            let huerfanosDetectadosCache = [];

            document.addEventListener('DOMContentLoaded', function() {
                escanearHuerfanosOrg();
            });

            function obtenerModulosSeleccionados() {
                const mods = [];
                document.querySelectorAll('.chk-modulo-huerfano:checked').forEach(chk => {
                    mods.push(chk.value);
                });
                return mods;
            }

            function marcarTodosModulosHuerfanos(marcar) {
                document.querySelectorAll('.chk-modulo-huerfano').forEach(chk => {
                    chk.checked = !!marcar;
                });
                escanearHuerfanosOrg();
            }

            function actualizarContadorSeleccionHuerfanos() {
                const chks = document.querySelectorAll('.chk-orphan-item:checked');
                const btnPurge = document.getElementById('btnPurgeOrphans');
                const lblCnt = document.getElementById('lblCountPurgeBtn');
                if (lblCnt) lblCnt.textContent = chks.length;
                if (btnPurge) {
                    if (chks.length > 0) {
                        btnPurge.classList.remove('d-none');
                    } else {
                        btnPurge.classList.add('d-none');
                    }
                }
            }

            function toggleSeleccionTodosHuerfanos(masterChk) {
                const checked = !!(masterChk && masterChk.checked);
                document.querySelectorAll('.chk-orphan-item').forEach(chk => {
                    chk.checked = checked;
                });
                actualizarContadorSeleccionHuerfanos();
            }

            async function escanearHuerfanosOrg() {
                const box = document.getElementById('boxOrphansResult');
                const btnScan = document.getElementById('btnScanOrphans');
                const btnPurge = document.getElementById('btnPurgeOrphans');

                const mods = obtenerModulosSeleccionados();
                if (mods.length === 0) {
                    if (btnPurge) btnPurge.classList.add('d-none');
                    if (box) {
                        box.innerHTML = '<div class="text-center py-3 text-muted small"><i class="bi bi-info-circle me-1"></i>Seleccione al menos un módulo arriba para ejecutar la auditoría de registros huérfanos.</div>';
                    }
                    ['qx_espacios', 'clinico_soap', 'dental_cotizaciones', 'boveda_archivos', 'config_edo_cta'].forEach(k => {
                        const el = document.getElementById('cnt_mod_' + k);
                        if (el) el.textContent = '0';
                    });
                    return;
                }

                if (btnScan) btnScan.disabled = true;
                if (box) {
                    box.innerHTML = '<div class="text-center py-3 text-muted small"><span class="spinner-border spinner-border-sm text-primary me-2"></span>Escaneando relaciones padre-hijo en los módulos seleccionados...</div>';
                }

                try {
                    const url = '../api/reset_datos_organizacion_api.pl?action=scan_orphans&modulos=' + encodeURIComponent(mods.join(','));
                    const res = await fetch(url);
                    const data = await res.json();

                    if (btnScan) btnScan.disabled = false;

                    if (!data || !data.success) {
                        box.innerHTML = `<div class="alert alert-danger mb-0 small">${(data && data.error) || 'No se pudo completar el escaneo.'}</div>`;
                        return;
                    }

                    const lista = Array.isArray(data.huerfanos) ? data.huerfanos : [];
                    huerfanosDetectadosCache = lista;

                    const conteoPorMod = {
                        qx_espacios: 0,
                        clinico_soap: 0,
                        dental_cotizaciones: 0,
                        boveda_archivos: 0,
                        config_edo_cta: 0
                    };
                    lista.forEach(h => {
                        if (h.modulo && conteoPorMod[h.modulo] !== undefined) {
                            conteoPorMod[h.modulo]++;
                        }
                    });
                    Object.keys(conteoPorMod).forEach(k => {
                        const el = document.getElementById('cnt_mod_' + k);
                        if (el) {
                            el.textContent = conteoPorMod[k];
                            el.className = conteoPorMod[k] > 0
                                ? 'badge bg-warning text-dark border border-warning rounded-pill fw-bold'
                                : 'badge bg-white text-muted border rounded-pill';
                        }
                    });

                    if (lista.length === 0) {
                        if (btnPurge) btnPurge.classList.add('d-none');
                        box.innerHTML = `
                            <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 p-2">
                                <div class="d-flex align-items-center gap-2.5 text-success">
                                    <i class="bi bi-check-circle-fill fs-4"></i>
                                    <div>
                                        <div class="fw-bold">0 Registros o Archivos Huérfanos Detectados en los Módulos Seleccionados</div>
                                        <div class="small text-muted">La integridad relacional entre Quirófano, Agenda de Espacios, Consultas SOAP, Cotizaciones, Odontogramas, Bóveda PACS y Caja está al 100%.</div>
                                    </div>
                                </div>
                                <span class="badge bg-success-subtle text-success border border-success-subtle px-3 py-1.5 rounded-pill fw-bold">Base Limpia</span>
                            </div>
                        `;
                    } else {
                        let rows = '';
                        lista.forEach((h, idx) => {
                            const safeUid = (h.uid || '').replace(/"/g, '&quot;');
                            rows += `
                                <tr>
                                    <td class="text-center">
                                        <input type="checkbox" class="form-check-input chk-orphan-item" value="${safeUid}" checked onchange="actualizarContadorSeleccionHuerfanos()">
                                    </td>
                                    <td class="fw-bold text-secondary small">${idx + 1}</td>
                                    <td><span class="badge bg-light text-dark border small">${h.modulo_nombre || h.modulo || ''}</span></td>
                                    <td><span class="badge bg-warning-subtle text-dark border border-warning-subtle">${h.categoria || 'Huérfano'}</span></td>
                                    <td><code class="small text-primary">${h.archivo || ''}</code></td>
                                    <td class="fw-bold font-monospace small">${h.id || ''}</td>
                                    <td class="small text-muted">${h.detalle || ''}</td>
                                    <td class="text-end">
                                        <button type="button" class="btn btn-sm btn-outline-danger py-0.5 px-2 rounded-2" data-uid="${safeUid}" onclick="purgarHuerfanoIndividual(this.getAttribute('data-uid'))" title="Purgar únicamente este registro/archivo huérfano">
                                            <i class="bi bi-trash3-fill"></i>
                                        </button>
                                    </td>
                                </tr>
                            `;
                        });

                        box.innerHTML = `
                            <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-2.5">
                                <div class="fw-bold text-warning-emphasis small">
                                    <i class="bi bi-exclamation-triangle-fill text-warning me-1.5"></i>Se detectaron <strong>${lista.length}</strong> registro(s) / archivo(s) huérfano(s) sin vínculo padre activo:
                                </div>
                                <span class="badge bg-success-subtle text-success border border-success-subtle small">
                                    <i class="bi bi-shield-lock-fill me-1"></i>0 afectación a ingresos, gastos o consultas activas
                                </span>
                            </div>
                            <div class="table-responsive" style="max-height: 340px; overflow-y: auto;">
                                <table class="table table-sm table-hover align-middle bg-white rounded-3 overflow-hidden mb-0">
                                    <thead class="table-light small text-uppercase">
                                        <tr>
                                            <th class="text-center" style="width: 36px;">
                                                <input type="checkbox" class="form-check-input" checked onchange="toggleSeleccionTodosHuerfanos(this)" title="Seleccionar / Desmarcar todos">
                                            </th>
                                            <th>#</th>
                                            <th>Módulo</th>
                                            <th>Categoría</th>
                                            <th>Archivo / Tabla</th>
                                            <th>Folio / ID</th>
                                            <th>Diagnóstico Relacional</th>
                                            <th class="text-end">1-a-1</th>
                                        </tr>
                                    </thead>
                                    <tbody>${rows}</tbody>
                                </table>
                            </div>
                        `;
                        actualizarContadorSeleccionHuerfanos();
                    }
                } catch (err) {
                    if (btnScan) btnScan.disabled = false;
                    if (box) box.innerHTML = '<div class="alert alert-danger mb-0 small">Error de red al consultar el escáner de huérfanos.</div>';
                }
            }

            async function purgarHuerfanoIndividual(uid) {
                if (!uid) return;
                const item = huerfanosDetectadosCache.find(x => x.uid === uid) || { id: uid };
                const confirmResult = await Swal.fire({
                    title: '¿Purgar Registro Huérfano 1-a-1?',
                    html: `
                        <div class="text-start small p-2">
                            <div class="p-2 rounded-3 bg-light border mb-2">
                                <div><strong>Módulo:</strong> ${item.modulo_nombre || ''}</div>
                                <div><strong>Categoría:</strong> ${item.categoria || ''}</div>
                                <div><strong>Archivo:</strong> <code>${item.archivo || ''}</code></div>
                                <div><strong>Folio / ID:</strong> <code>${item.id || ''}</code></div>
                            </div>
                            <div class="text-secondary">${item.detalle || ''}</div>
                        </div>
                    `,
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonColor: '#dc2626',
                    cancelButtonColor: '#64748b',
                    confirmButtonText: '<i class="bi bi-trash3-fill me-1"></i> Sí, Eliminar este Huérfano',
                    cancelButtonText: 'Cancelar'
                });
                if (!confirmResult.isConfirmed) return;
                await ejecutarPurgaHuerfanosBackend([uid]);
            }

            async function purgarHuerfanosSeleccionados() {
                const uids = [];
                document.querySelectorAll('.chk-orphan-item:checked').forEach(chk => {
                    if (chk.value) uids.push(chk.value);
                });
                if (uids.length === 0) {
                    Swal.fire('Atención', 'Seleccione al menos un registro huérfano en la tabla.', 'info');
                    return;
                }

                const confirmResult = await Swal.fire({
                    title: `¿Purgar ${uids.length} Huérfano(s) Seleccionado(s)?`,
                    html: `Se eliminarán <strong>únicamente</strong> los <strong>${uids.length}</strong> registros/archivos huérfanos marcados (y se devolverá al stock cualquier consumo 3NF huérfano seleccionado).<br><br><span class="text-success fw-bold">Las cirugías activas, rentas vigentes, consultas clínicas, ingresos y gastos permanecerán 100% intactos.</span>`,
                    icon: 'question',
                    showCancelButton: true,
                    confirmButtonColor: '#19B7A5',
                    cancelButtonColor: '#64748b',
                    confirmButtonText: '<i class="bi bi-trash3-fill me-1"></i> Sí, Purgar Seleccionados',
                    cancelButtonText: 'Cancelar'
                });

                if (!confirmResult.isConfirmed) return;
                await ejecutarPurgaHuerfanosBackend(uids);
            }

            async function ejecutarPurgaHuerfanosBackend(uidsArray) {
                const btnPurge = document.getElementById('btnPurgeOrphans');
                if (btnPurge) btnPurge.disabled = true;

                try {
                    const mods = obtenerModulosSeleccionados();
                    const fd = new URLSearchParams();
                    fd.append('action', 'purge_orphans');
                    fd.append('modulos', mods.join(','));
                    if (Array.isArray(uidsArray) && uidsArray.length > 0) {
                        fd.append('uids', JSON.stringify(uidsArray));
                    }

                    const res = await fetch('../api/reset_datos_organizacion_api.pl', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                        body: fd
                    });
                    const data = await res.json();

                    if (btnPurge) btnPurge.disabled = false;

                    if (data && data.success) {
                        await Swal.fire({
                            icon: 'success',
                            title: '¡Purga Forense Completada!',
                            text: data.msg,
                            confirmButtonColor: '#0A2A66'
                        });
                        escanearHuerfanosOrg();
                    } else {
                        Swal.fire('Error', (data && data.error) || 'No se pudo completar la purga de huérfanos.', 'error');
                    }
                } catch (err) {
                    if (btnPurge) btnPurge.disabled = false;
                    Swal.fire('Error de Red', 'No se pudo conectar con el servidor.', 'error');
                }
            }

            async function ejecutarResetOrg(e) {
                e.preventDefault();
                const form = document.getElementById('formResetOrg');
                const fd = new FormData(form);
                const conf = (fd.get('confirmacion') || '').trim().toUpperCase();

                if (conf !== 'CONFIRMAR') {
                    Swal.fire('Atención', 'Debe escribir la palabra CONFIRMAR en el campo de seguridad.', 'warning');
                    return;
                }

                const configEl = document.getElementById('configReset');
                const manejaFolios = configEl && configEl.dataset.manejaFolios === '1';
                const folioPriv = fd.get('folio_privados') || '1';

                let confirmHtml = '';
                if (manejaFolios) {
                    const folioPub = fd.get('folio_publicos') || '1';
                    confirmHtml = `Se purgarán los movimientos operativos institucionales y los folios iniciarán en:<br><br>` +
                                  `<strong>Privados: #${folioPriv}</strong> | <strong>Públicos: #${folioPub}</strong><br><br>` +
                                  `<span class="text-success fw-bold">Los usuarios, médicos, convenios y catálogos permanecerán intactos.</span>`;
                } else {
                    confirmHtml = `Se purgarán los movimientos operativos de este consultorio.<br><br>` +
                                  `El contador de recibos de caja se configurará para iniciar en el folio: <strong>#${folioPriv}</strong>.<br><br>` +
                                  `<span class="text-success fw-bold">Los datos del médico titular, usuarios, catálogo y directorio de pacientes permanecerán intactos.</span>`;
                }

                const confirmResult = await Swal.fire({
                    title: '¿Confirmar Reset de Organización?',
                    html: confirmHtml,
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonColor: '#dc2626',
                    cancelButtonColor: '#64748b',
                    confirmButtonText: 'Sí, ejecutar Reset',
                    cancelButtonText: 'Cancelar'
                });

                if (!confirmResult.isConfirmed) return;

                const btn = document.getElementById('btnSubmitReset');
                btn.disabled = true;
                btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>Procesando Reset...';

                try {
                    const res = await fetch('../api/reset_datos_organizacion_api.pl', {
                        method: 'POST',
                        body: fd
                    });
                    const data = await res.json();

                    if (data.success) {
                        await Swal.fire({
                            title: '¡Reset Completado!',
                            text: data.msg,
                            icon: 'success',
                            confirmButtonText: 'Entendido'
                        });
                        window.location.href = '../views/inicial.pl';
                    } else {
                        Swal.fire('Error', data.error || 'No se pudo completar el reset.', 'error');
                        btn.disabled = false;
                        btn.innerHTML = '<i class="bi bi-arrow-counterclockwise me-2"></i>Ejecutar Reset de Organización';
                    }
                } catch (err) {
                    Swal.fire('Error de Conexión', 'Ocurrió un problema de comunicación con el servidor.', 'error');
                    btn.disabled = false;
                    btn.innerHTML = '<i class="bi bi-arrow-counterclockwise me-2"></i>Ejecutar Reset de Organización';
                }
            }
        </script>
JS

render_bottom_nav('ajustes');

