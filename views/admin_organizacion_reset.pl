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

print <<'HTML';
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-arrow-repeat me-2"></i>Reset Operativo de Organización</h2>
                    <p class="text-white-50 small mb-0 mt-1">Limpieza de movimientos transaccionales y reinicio personalizado de folios</p>
                </div>
                <a href="../views/inicial.pl" class="btn btn-outline-light rounded-pill px-4 fw-semibold shadow-sm">
                    <i class="bi bi-house-door me-2"></i>Inicio
                </a>
            </div>
        </header>

        <div class="container-fluid px-4 pb-5">
            <div class="row justify-content-center">
                <div class="col-12 col-xl-9">
                    <!-- Tarjeta Principal de Información y Advertencia -->
                    <div class="card card-medentia-aura border-0 shadow-sm rounded-4 mb-4">
                        <div class="card-body p-4 p-md-5">
                            
                            <!-- Alerta Informativa de Alto Nivel -->
                            <div class="alert alert-warning border-0 rounded-4 p-4 mb-4 d-flex align-items-start gap-3 shadow-sm" style="background-color: #fffbeb; border-left: 5px solid #f59e0b !important;">
                                <i class="bi bi-exclamation-triangle-fill text-warning fs-2 flex-shrink-0"></i>
                                <div>
                                    <h5 class="fw-bold text-dark mb-1">Atención: Operación de Mantenimiento y Purga Operativa</h5>
                                    <p class="small text-muted mb-0">
                                        Esta herramienta permite purgar los datos transaccionales generados durante pruebas o periodos anteriores para iniciar la operación limpia de la organización.
                                    </p>
                                </div>
                            </div>

                            <div class="row g-4 mb-4">
                                <div class="col-12 col-md-6">
                                    <div class="p-3 rounded-3 bg-danger bg-opacity-10 border border-danger border-opacity-25 h-100">
                                        <h6 class="fw-bold text-danger mb-2"><i class="bi bi-trash3-fill me-2"></i>¿Qué datos SE ELIMINAN?</h6>
                                        <ul class="small text-muted mb-0 ps-3">
                                            <li>Recibos de cobro de caja rápida (privados y públicos).</li>
                                            <li>Historial de estado de cuenta y transacciones de caja.</li>
                                            <li>Citas en agenda médica.</li>
                                            <li>Consultas clínicas, recetas y consentimientos.</li>
                                            <li>Registro de egresos y gastos de la organización.</li>
                                            <li>Pacientes temporales de mostrador.</li>
                                        </ul>
                                    </div>
                                </div>
                                <div class="col-12 col-md-6">
                                    <div class="p-3 rounded-3 bg-success bg-opacity-10 border border-success border-opacity-25 h-100">
                                        <h6 class="fw-bold text-success mb-2"><i class="bi bi-shield-check me-2"></i>¿Qué datos SE CONSERVAN INTACTOS?</h6>
                                        <ul class="small text-muted mb-0 ps-3">
                                            <li><strong>Todos los usuarios creados</strong> (Médicos, Recepcionistas, Administradores).</li>
                                            <li>Especialidades y catálogo de médicos vinculados.</li>
                                            <li>Catálogo universal de servicios, categorías y departamentos.</li>
                                            <li>Tarifas, matriz de precios y convenios institucionales.</li>
                                            <li>Configuración del tenant y datos de la clínica.</li>
                                        </ul>
                                    </div>
                                </div>
                            </div>

                            <!-- Formulario de Configuración de Folios y Ejecución -->
                            <form id="formResetOrg" onsubmit="ejecutarResetOrg(event)" class="mt-4 pt-3 border-top">
                                <h5 class="fw-bold text-dark mb-3"><i class="bi bi-sliders me-2 text-primary"></i>Configuración de Folios Consecutivos Iniciales</h5>
                                <p class="text-muted small mb-4">Defina los números de folio a partir de los cuales se comenzará a emitir la foliatura en caja al concluir el reset:</p>

                                <div class="row g-3 mb-4">
                                    <div class="col-12 col-md-6">
                                        <label class="form-label fw-bold small text-muted"><i class="bi bi-receipt me-1"></i>Folio Inicial de Recibos Privados</label>
                                        <div class="input-group">
                                            <span class="input-group-text bg-light fw-bold">#</span>
                                            <input type="number" min="1" step="1" class="form-control fw-bold" name="folio_privados" id="folio_privados" value="1" required>
                                        </div>
                                        <div class="form-text small">El primer recibo privado cobrado tendrá este número de folio.</div>
                                    </div>
                                    <div class="col-12 col-md-6">
                                        <label class="form-label fw-bold small text-muted"><i class="bi bi-building me-1"></i>Folio Inicial de Recibos Públicos (Convenios)</label>
                                        <div class="input-group">
                                            <span class="input-group-text bg-light fw-bold">#</span>
                                            <input type="number" min="1" step="1" class="form-control fw-bold" name="folio_publicos" id="folio_publicos" value="1" required>
                                        </div>
                                        <div class="form-text small">El primer recibo público emitido tendrá este número de folio.</div>
                                    </div>
                                </div>

                                <div class="p-3 rounded-3 bg-light border mb-4">
                                    <label class="form-label fw-bold small text-danger"><i class="bi bi-lock-fill me-1"></i>Confirmación de Seguridad Obligatoria</label>
                                    <p class="small text-muted mb-2">Para confirmar que comprende la purga de datos operativos, escriba la palabra <strong>CONFIRMAR</strong> en el siguiente campo:</p>
                                    <input type="text" class="form-control text-uppercase fw-bold text-danger font-monospace" name="confirmacion" id="confirmacion" placeholder="Escriba CONFIRMAR aquí" style="max-width: 320px; text-transform: uppercase;" required>
                                </div>

                                <div class="d-flex flex-wrap justify-content-end gap-3 pt-2">
                                    <a href="../views/inicial.pl" class="btn btn-light border px-4 py-2">Cancelar</a>
                                    <button type="submit" id="btnSubmitReset" class="btn btn-danger px-4 py-2 fw-bold shadow-sm">
                                        <i class="bi bi-arrow-counterclockwise me-2"></i>Ejecutar Reset de Organización
                                    </button>
                                </div>
                            </form>

                        </div>
                    </div>
                </div>
            </div>
        </div>

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

                const folioPriv = fd.get('folio_privados') || '1';
                const folioPub = fd.get('folio_publicos') || '1';

                const confirmResult = await Swal.fire({
                    title: '¿Confirmar Reset de Organización?',
                    html: `Se purgarán los movimientos operativos y los folios iniciarán en:<br><br>
                           <strong>Privados: #${folioPriv}</strong> | <strong>Públicos: #${folioPub}</strong><br><br>
                           <span class="text-success fw-bold">Los usuarios permanecerán intactos.</span>`,
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
HTML

render_bottom_nav('ajustes');
render_footer();
