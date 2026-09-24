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

# Validación estricta de rol RBAC
if ($role ne 'Administrador Organizacion' && $role ne 'Administrador Global') {
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
my $es_consultorio_ind = ($tipo_organizacion eq 'Consultorio Individual') ? 1 : 0;
# Los folios públicos y personalización de folios iniciales SOLO aplican si tiene CLUE y PACIENTES_ESTADO activo
my $maneja_folios_publicos = ($has_clue && $has_pacientes_estado && !$es_consultorio_ind) ? 1 : 0;

my $subtitulo_topbar = $maneja_folios_publicos 
    ? 'Limpieza de movimientos transaccionales y reinicio personalizado de folios'
    : 'Limpieza de movimientos transaccionales y reinicio automático de contadores a cero';

# Textos adaptados para Qué datos SE ELIMINAN
my $html_datos_eliminados = '';
if ($es_consultorio_ind) {
    $html_datos_eliminados = <<'HTML_DEL';
                                        <ul class="small text-muted mb-0 ps-3">
                                            <li class="mb-1">Recibos de cobro de caja rápida del consultorio.</li>
                                            <li class="mb-1">Historial de estado de cuenta y transacciones de caja.</li>
                                            <li class="mb-1">Citas en agenda médica e historial de movimientos.</li>
                                            <li class="mb-1">Consultas clínicas (SOAP), recetas, consentimientos y borradores.</li>
                                            <li class="mb-1">Registro de egresos y gastos operativos del consultorio.</li>
                                            <li class="mb-1">Pacientes registrados en caja rápida / mostrador.</li>
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
                                            <li class="mb-1"><strong>Usuario titular y accesos</strong> (ID, credenciales, especialidad y cédula profesional).</li>
                                            <li class="mb-1">Catálogo de servicios, tarifas y tratamientos del consultorio.</li>
                                            <li class="mb-1">Expedientes de pacientes clínicos base.</li>
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
    $html_seccion_folios = <<'HTML_FOLIOS_AUTO';
                                <div class="alert alert-success border-0 rounded-4 p-3 p-md-4 mb-4 d-flex align-items-start gap-3 shadow-sm" style="background-color: #f0fdf4; border-left: 5px solid #16a34a !important;">
                                    <i class="bi bi-check-circle-fill text-success fs-3 flex-shrink-0"></i>
                                    <div>
                                        <h6 class="fw-bold text-dark mb-1">Reinicio Automático de Contadores</h6>
                                        <p class="small text-muted mb-0">
                                            Esta organización opera bajo esquema privado (sin convenios públicos del Estado). Su contador único de recibos privados se reiniciará <strong>automáticamente en 0</strong> (el próximo recibo cobrado iniciará con el <strong>#1</strong>). No se requiere configuración manual de folios.
                                        </p>
                                    </div>
                                </div>
HTML_FOLIOS_AUTO
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
                    <!-- Tarjeta Principal de Información y Advertencia -->
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

                let confirmHtml = '';
                if (manejaFolios) {
                    const folioPriv = fd.get('folio_privados') || '1';
                    const folioPub = fd.get('folio_publicos') || '1';
                    confirmHtml = `Se purgarán los movimientos operativos y los folios iniciarán en:<br><br>` +
                                  `<strong>Privados: #${folioPriv}</strong> | <strong>Públicos: #${folioPub}</strong><br><br>` +
                                  `<span class="text-success fw-bold">Los usuarios y configuraciones permanecerán intactos.</span>`;
                } else {
                    confirmHtml = `Se purgarán los movimientos operativos de esta organización.<br><br>` +
                                  `Su contador único de recibos privados se reiniciará automáticamente en <strong>#0</strong> (el próximo recibo cobrado será el <strong>#1</strong>).<br><br>` +
                                  `<span class="text-success fw-bold">Los usuarios, catálogo y configuraciones permanecerán intactos.</span>`;
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

