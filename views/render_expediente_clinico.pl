#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(decode_json encode_json);
use FindBin;
use lib "$FindBin::Bin/..";
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();

# Redireccionar si no hay sesión
if (!$session_data->{session_ok}) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Sesión Expirada</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght\@400;600;800&display=swap" rel="stylesheet">
</head>
<body>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            Swal.fire({
                title: 'Sesión Expirada',
                text: 'Por seguridad, tu sesión ha terminado. Serás redirigido al inicio.',
                icon: 'warning',
                confirmButtonText: 'Aceptar',
                confirmButtonColor: '#0d6efd',
                allowOutsideClick: false,
                timer: 4000,
                timerProgressBar: true
            }).then(() => {
                window.location.href = '../index.html';
            });
        });
    </script>
</body>
</html>
HTML
}

my $id_target = $q->param('id') || '';
my $paciente = cargar_datos_paciente($id_target);

if ($paciente) {
    my $tenant_pac = $paciente->{tenant} // '';
    my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
    my $mi_org = $session_data->{id_empresa} || 'X';
    my $mi_sucursal = $session_data->{id_sucursal} // 0;
    my $role = $session_data->{role};
    my $id_medico = $session_data->{id_medico};
    
    my $acceso_permitido = 0;
    if ($role eq 'Administrador Global') {
        $acceso_permitido = 1;
    } elsif ($role =~ /Administrador Organizacion|Soporte/i) {
        if ($org_pac && $org_pac eq $mi_org) {
            $acceso_permitido = 1;
        } elsif (!$org_pac) {
            $acceso_permitido = 1;
        }
    } elsif ($role eq 'Medico') {
        if ($org_pac && $org_pac eq $mi_org) {
            if (($suc_pac eq $mi_sucursal || !$suc_pac || !$mi_sucursal) && $paciente->{id_medico} eq $id_medico) {
                $acceso_permitido = 1;
            }
        } elsif (!$org_pac && $paciente->{id_medico} eq $id_medico) {
            $acceso_permitido = 1;
        }
    }
    
    if (!$acceso_permitido) {
        print $q->header(-type => 'text/html', -charset => 'UTF-8');
        print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Acceso Denegado</title>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
</head>
<body>
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            Swal.fire({
                title: 'Acceso Denegado',
                text: 'No tienes los permisos necesarios para visualizar este expediente clínico.',
                icon: 'error',
                confirmButtonText: 'Aceptar',
                confirmButtonColor: '#0d6efd'
            }).then(() => {
                window.location.href = 'pacientes.pl';
            });
        });
    </script>
</body>
</html>
HTML
        exit;
    }
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $session_data->{usuario}, 
    role        => $session_data->{role}, 
    titulo      => 'SDM Digital - Expediente Unificado', 
    skip_header => 1
);

if ($paciente) {
    my @citas = cargar_citas_paciente($id_target);
    my @correos = cargar_historial_correos($id_target);
    my $consultas = cargar_historial_consultas($id_target);
    render_expediente_completo($paciente, \@citas, \@correos, $consultas, $session_data->{id_medico});
}

print "</main>\n";
render_bottom_nav('pacientes');
print "</body></html>\n";

sub render_expediente_completo {
    my ($d, $citas_ref, $correos_ref, $consultas_ref, $id_medico_actual) = @_;
    my $count_c = scalar @$citas_ref;
    my $count_m = scalar @$correos_ref;
    my $count_consultas = scalar @$consultas_ref;
    my $edad = calcular_edad($d->{f_nac});
    my $curp = $d->{curp} || 'Sin CURP';
    my $sexo = $d->{sexo} || 'N/A';

    print <<HTML;
<link rel="stylesheet" href="../css/expediente_completo.css?v=$^T">
HTML

    utils::sub_sidebar::render_sidebar(
        usuario => $session_data->{usuario},
        role => $session_data->{role},
        id_medico => $session_data->{id_medico},
        pagina_actual => 'expediente'
    );

    print <<HTML;
<script>
    let odontogramaInit = false;

    function swTab(id, b) {
        if (window.innerWidth <= 991) {
            if(b && b.classList.contains('sub-link')){
                const sidebar = document.getElementById('moduleSidebar');
                const overlay = document.getElementById('sidebarOverlay');
                if (sidebar && sidebar.classList.contains('show')) toggleSidebar();
            }
        }

        document.querySelectorAll('.sdm-tab-sec').forEach(s => s.classList.add('d-none'));
        const target = document.getElementById(id);
        if(target) target.classList.remove('d-none');

        if (b && b.classList.contains('sub-link')) {
            document.querySelectorAll('.sub-link').forEach(n => n.classList.remove('active'));
            b.classList.add('active');
        }
        
        if (id === 'tab6' && !odontogramaInit && typeof initOdontograma === 'function') {
            setTimeout(() => {
                initOdontograma('odontograma-svg-container', '$d->{id_paciente}');
                odontogramaInit = true;
            }, 100);
        }

        if(b && b.classList.contains('sub-link')){
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }
    
    document.addEventListener('DOMContentLoaded', function() {
        const hash = window.location.hash;
        if (hash) {
            const tabId = hash.substring(1);
            const targetBtn = document.querySelector('.sub-link[onclick*="swTab(\\'' + tabId + '\\'"]');
            if(targetBtn) {
                swTab(tabId, targetBtn);
            }
        }
    });
</script>

        <!-- TOPBAR / HEADER CORPORATIVO (ESTÁNDAR IMAGEN 2) -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm mb-4" style="border-radius: 1.5rem;">
            <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-white bg-opacity-10 p-3 rounded-circle d-flex align-items-center justify-content-center" style="width: 54px; height: 54px;">
                        <i class="bi bi-person-vcard-fill fs-3 text-white"></i>
                    </div>
                    <div>
                        <h2 class="fw-black mb-0 text-white" style="letter-spacing: -0.5px;">$d->{nombre}</h2>
                        <p class="text-white-50 small mb-0 mt-1">
                            <span class="me-3"><i class="bi bi-fingerprint me-1"></i>CURP: $curp</span>
                            <span class="me-3"><i class="bi bi-calendar3 me-1"></i>Edad: $edad a&ntilde;os</span>
                            <span><i class="bi bi-gender-ambiguous me-1"></i>Sexo: $sexo</span>
                        </p>
                    </div>
                </div>
                <div>
                    <a href="pacientes.pl" class="btn text-white fw-bold rounded-pill px-4 py-2 shadow-sm d-flex align-items-center gap-2" style="background: #082050; border: 1px solid rgba(255,255,255,0.2);">
                        <i class="bi bi-arrow-left text-white"></i><span>Directorio de Pacientes</span>
                    </a>
                </div>
            </div>
        </header>

        <div class="mt-4">
        <!-- 6: ODONTOGRAMA -->
        <section class="sdm-tab-sec d-none" id="tab6">
            <div class="d-flex justify-content-between align-items-center mb-5">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Odontograma Digital v2.0</h3>
                    <p class="text-muted small fw-bold">MAPEO DE PIEZAS DENTALES EN TIEMPO REAL</p>
                </div>
                <div class="d-flex gap-2" id="odontograma-toolbar">
                    <button class="btn btn-outline-danger btn-sm rounded-pill px-3 active-tool" data-tool="caries"><i class="bi bi-circle-fill me-1"></i>Caries</button>
                    <button class="btn btn-outline-primary btn-sm rounded-pill px-3" data-tool="corona"><i class="bi bi-square-fill me-1"></i>Corona</button>
                    <button class="btn btn-outline-dark btn-sm rounded-pill px-3" data-tool="extraccion"><i class="bi bi-x-lg me-1"></i>Extracción</button>
                    <button class="btn btn-outline-info btn-sm rounded-pill px-3" data-tool="implante"><i class="bi bi-vinyl-fill me-1"></i>Implante</button>
                    <button class="btn btn-outline-warning btn-sm rounded-pill px-3" data-tool="protesis"><i class="bi bi-diagram-2-fill me-1"></i>Prótesis</button>
                    <button class="btn btn-outline-success btn-sm rounded-pill px-3" data-tool="sano"><i class="bi bi-check-circle-fill me-1"></i>Sano</button>
                    <div class="vr mx-2"></div>
                    <button class="btn btn-outline-danger btn-sm rounded-pill px-3" onclick="resetOdontograma()"><i class="bi bi-trash3-fill me-1"></i>Resetear</button>
                    <div class="vr mx-2"></div>
                    <button class="btn btn-medentia btn-sm rounded-pill px-4" onclick="saveOdontogramaToServer()"><i class="bi bi-cloud-arrow-up-fill me-2" style="color: var(--md-cyan-ia);"></i>Sincronizar</button>
                </div>
            </div>

            <div class="odontograma-container card-medentia-aura p-5 mb-4 overflow-auto border-0" style="border-radius: 20px; overflow: hidden !important;">
                <div id="odontograma-svg-container" class="text-center" style="min-width: 800px;">
                    <!-- El mapa dental se cargará aquí vía JS -->
                    <div class="py-5 text-muted opacity-50"><div class="spinner-border text-primary mb-3"></div><br>Iniciando Mapa Dental...</div>
                </div>
            </div>
            
            <div class="card-medentia-aura p-4 d-flex gap-4 justify-content-center mb-4 border-0">
                <div class="small fw-bold" style="color: var(--md-blue-deep);"><i class="bi bi-info-circle me-1" style="color: var(--md-teal-clinical);"></i> Instrucciones:</div>
                <div class="small"><span class="badge bg-danger">1</span> Seleccione una condición en la barra superior.</div>
                <div class="small"><span class="badge bg-primary">2</span> Haga clic sobre una de las caras de la pieza dental para marcarla.</div>
            </div>

            <!-- Notas Médicas -->
            <div class="mb-4 diamond-input-armor">
                <label for="odontograma-notas" class="small fw-bold text-muted mb-2 ps-1"><i class="bi bi-journal-medical me-2" style="color: var(--md-teal-clinical);"></i>Notas Médicas / Observaciones</label>
                <textarea class="form-control py-3 fw-bold" id="odontograma-notas" rows="4" placeholder="Escriba las observaciones clínicas del odontograma aquí..."></textarea>
            </div>

            <!-- Listado Dinámico de Diagnóstico -->
            <div class="card-medentia-aura p-4 border-0" id="seccion-diagnostico-print">
                
                <!-- Print Header (Hidden on screen) -->
                <div class="d-none d-print-block mb-4 border-bottom pb-3">
                    <div class="d-flex justify-content-between align-items-start">
                        <div>
                            <h3 class="fw-black m-0">Clínica Dental SDM</h3>
                            <p class="text-muted small m-0">REPORTE CLÍNICO DE ODONTOGRAMA</p>
                        </div>
                        <div class="text-end">
                            <h5 class="fw-bold m-0">Paciente: $d->{nombre}</h5>
                            <p class="text-muted small m-0">Fecha de Impresión: <span id="print-date"></span></p>
                        </div>
                    </div>
                </div>

                <div class="d-flex justify-content-between align-items-center mb-4 d-print-none">
                    <div>
                        <h5 class="fw-black m-0" style="color: var(--md-blue-deep);"><i class="bi bi-clipboard2-pulse me-2" style="color: var(--md-teal-clinical);"></i>Registro de Diagnóstico</h5>
                        <p class="text-muted small fw-bold mb-0">ESTADO ACTUAL DEL ODONTOGRAMA</p>
                    </div>
                    <button class="btn btn-sm btn-outline-secondary rounded-pill px-3 shadow-sm" onclick="preparePrint()">
                        <i class="bi bi-printer-fill me-1"></i>Imprimir
                    </button>
                </div>

                <!-- Notas en Impresión -->
                <div class="d-none d-print-block mb-4">
                    <h6 class="fw-bold border-bottom pb-2">Observaciones Clínicas</h6>
                    <p id="print-notas" class="small"></p>
                </div>

                <div class="table-responsive">
                    <table class="table table-hover table-borderless align-middle" id="tabla-diagnostico">
                        <thead class="table-light">
                            <tr>
                                <th class="rounded-start-4 ps-4">Pieza (FDI)</th>
                                <th>Diagnóstico / Estado</th>
                                <th class="rounded-end-4">Detalle / Caras</th>
                            </tr>
                        </thead>
                        <tbody id="tbody-diagnostico">
                            <tr>
                                <td colspan="3" class="text-center text-muted py-4 small fw-bold">No hay hallazgos registrados aún.</td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <!-- Print Footer -->
                <div class="d-none d-print-block mt-5 pt-5 text-center">
                    <div class="w-50 mx-auto border-top border-dark pt-2">
                        <p class="fw-bold mb-0">Dr. $session_data->{usuario}</p>
                        <p class="small text-muted">Firma del Médico Tratante</p>
                    </div>
                </div>
            </div>
        </section>
        <!-- 0: CITAS (TIMELINE) -->
        <section class="sdm-tab-sec" id="tab0">
            <div class="d-flex justify-content-between align-items-center mb-5 flex-wrap gap-3">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Historial Cronol&oacute;gico</h3>
                    <p class="text-muted small fw-bold">RÉCORD DE CITAS Y CONSULTAS</p>
                </div>
                <div class="d-flex gap-2 p-1 bg-transparent rounded-pill flex-wrap">
                    <span class="badge rounded-pill px-3 py-2 align-self-center mx-1" style="background-color: var(--md-teal-clinical);">$count_c Registros</span>
                    <div class="vr mx-1"></div>
                    <a href="agenda_main.pl?id=$d->{id_paciente}" class="btn btn-outline-medentia d-flex align-items-center"><i class="bi bi-calendar-event me-2" style="color: var(--md-teal-clinical);"></i>Gestionar Agenda</a>
                    <a href="render_consultas.pl?id=$d->{id_paciente}" class="btn btn-medentia d-flex align-items-center"><i class="bi bi-lightning-charge-fill me-2" style="color: var(--md-cyan-ia);"></i>Consulta Express</a>
                </div>
            </div>
            
            <div class="timeline-diamond">
HTML
    foreach my $c (@$citas_ref) {
        my $is_en_consulta = ($c->{estado} =~ /En consulta/i);
        my $status_color = $is_en_consulta ? '#00C4C4' : ($c->{estado} =~ /Programada/i) ? '#10b981' : ($c->{estado} =~ /Cancelada/i) ? '#ef4444' : '#64748b';
        my $btn_tomar_cita = "";
        if ($c->{estado} !~ /Realizada|Atendida|Cancelada/i) {
            if ($is_en_consulta) {
                $btn_tomar_cita = qq{<a href="render_consultas_privado.pl?id=$paciente->{id_paciente}&id_cita=$c->{id_cita}" class="btn btn-sm btn-info text-white px-3 fw-bold ms-2 shadow-sm rounded-pill">Continuar con la consulta <i class="bi bi-play-fill ms-1"></i></a>};
            } else {
                $btn_tomar_cita = qq{<a href="render_consultas_privado.pl?id=$paciente->{id_paciente}&id_cita=$c->{id_cita}" class="btn btn-sm btn-medentia px-3 fw-bold ms-2 rounded-pill">Iniciar <i class="bi bi-play-fill ms-1" style="color: var(--md-cyan-ia);"></i></a>};
            }
        }
        print <<HTML;
                <div class="timeline-item">
                    <div class="timeline-dot" style="border-color: $status_color"></div>
                    <div class="timeline-card">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <div>
                                <span class="badge mb-2" style="background: $status_color; color: white;">$c->{estado}</span>
                                <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">$c->{motivo}</h5>
                            </div>
                            <div class="text-end">
                                <div class="fw-black" style="font-size: 1.1rem; color: var(--md-teal-clinical);">$c->{fecha}</div>
                                <div class="small text-muted fw-bold">$c->{hora}</div>
                            </div>
                        </div>
                        <div class="d-flex align-items-center gap-2 mt-3 pt-3 border-top">
                            <i class="bi bi-person-circle text-muted"></i>
                            <span class="small fw-bold text-muted">M&eacute;dico: $c->{id_medico}</span>
                            <div class="ms-auto">
                                $btn_tomar_cita
                            </div>
                        </div>
                    </div>
                </div>
HTML
    }
    print <<HTML;
            </div>
        </section>

        <!-- 10: CONSULTAS (HUB CLÍNICO) -->
        <section class="sdm-tab-sec d-none" id="tab10">
            <div class="d-flex justify-content-between align-items-center mb-5 flex-wrap gap-3">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Hub de Consultas</h3>
                    <p class="text-muted small fw-bold">ATENCI&Oacute;N CL&Iacute;NICA Y TRAZABILIDAD</p>
                </div>
                <a href="render_consultas.pl?id=$paciente->{id_paciente}" class="btn btn-medentia d-flex align-items-center"><i class="bi bi-lightning-charge-fill me-2" style="color: var(--md-cyan-ia);"></i>Consulta Express (Sin Cita)</a>
            </div>

            <!-- Panel Superior: Citas Pendientes de Atención -->
            <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-calendar-check-fill me-2" style="color: var(--md-teal-clinical);"></i>Citas Programadas Listas para Atenderse</h5>
            <div class="row g-3 mb-5">
HTML
    my $hay_citas_pendientes = 0;
    foreach my $c (@$citas_ref) {
        if ($c->{estado} !~ /Realizada|Atendida|Cancelada/i) {
            $hay_citas_pendientes = 1;
            my $is_en_consulta = ($c->{estado} =~ /En consulta/i);
            my $badge_color = $is_en_consulta ? 'info' : ($c->{estado} =~ /Confirmada/i) ? 'success' : ($c->{estado} =~ /No Asistió|No Asistio/i) ? 'warning' : 'primary';
            my $btn_label = $is_en_consulta ? "Continuar con la consulta" : "Iniciar";
            my $btn_class = $is_en_consulta ? "btn btn-info text-white btn-sm d-flex align-items-center px-4 rounded-pill shadow-sm fw-bold" : "btn btn-medentia btn-sm d-flex align-items-center px-4 rounded-pill fw-bold";
            print <<HTML;
                <div class="col-lg-6">
                    <div class="card-medentia-aura p-4 d-flex justify-content-between align-items-center" style="border-left: 5px solid var(--bs-$badge_color) !important;">
                        <div>
                            <span class="badge bg-${badge_color} text-white mb-2">$c->{estado} - $c->{fecha} $c->{hora}</span>
                            <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">$c->{motivo}</h5>
                            <p class="small text-muted m-0">M&eacute;dico: $c->{id_medico}</p>
                        </div>
                        <a href="render_consultas_privado.pl?id=$paciente->{id_paciente}&id_cita=$c->{id_cita}" class="$btn_class">
                            $btn_label <i class="bi bi-arrow-right-short ms-1"></i>
                        </a>
                    </div>
                </div>
HTML
        }
    }
    if (!$hay_citas_pendientes) {
        print <<HTML;
                <div class="col-12">
                    <div class="card-medentia-aura text-center p-5">
                        <i class="bi bi-calendar-x display-6 d-block mb-3 opacity-25" style="color: var(--md-blue-deep);"></i>
                        <span class="fw-bold text-muted">No hay citas programadas pendientes de atenci&oacute;n para este paciente.</span>
                    </div>
                </div>
HTML
    }
    print <<HTML;
            </div>

            <!-- Panel Inferior: Historial Cronológico de Notas Médicas -->
            <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-journal-medical me-2" style="color: var(--md-teal-clinical);"></i>Historial de Notas M&eacute;dicas (Realizadas)</h5>
            <div class="timeline-diamond mb-5">
HTML
    if (@$consultas_ref) {
        foreach my $cons (@$consultas_ref) {
            my $diagnostico = $cons->{data}->{diagnostico_principal} || $cons->{data}->{diagnostico} || 'Sin diagnóstico registrado';
            my $motivo = $cons->{data}->{motivo} || 'Consulta general';
            # Truncar textos largos
            my $diag_trunc = length($diagnostico) > 80 ? substr($diagnostico, 0, 80) . '...' : $diagnostico;
            
            my $badge_cita = $cons->{id_cita} ? "<span class='badge bg-info-subtle text-info border border-info-subtle mb-2'><i class='bi bi-link-45deg me-1'></i>Vinculado a Cita</span>" : "<span class='badge bg-secondary-subtle text-secondary border border-secondary-subtle mb-2'>Consulta Express</span>";
            
            my $meds_count = 0;
            if ($cons->{data}->{medicamentos} && ref($cons->{data}->{medicamentos}) eq 'ARRAY') {
                $meds_count = scalar @{$cons->{data}->{medicamentos}};
            }
            my $receta_html = $meds_count > 0 ? "<div class='mt-3 pt-3 border-top'><span class='badge bg-light text-dark border'><i class='bi bi-capsule text-primary me-1'></i> $meds_count F&aacute;rmaco(s) recetado(s)</span></div>" : "";

            my $nombre_medico = obtener_nombre_medico($cons->{id_medico});

            print <<HTML;
                <div class="timeline-item">
                    <div class="timeline-dot" style="border-color: var(--md-teal-clinical)"></div>
                    <div class="timeline-card card-medentia-aura">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <div>
                                $badge_cita
                                <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">$motivo</h5>
                                <p class="text-muted small mt-2 mb-0"><strong>Dx:</strong> $diag_trunc</p>
                            </div>
                            <div class="text-end">
                                <div class="fw-black" style="font-size: 1.1rem; color: var(--md-teal-clinical);">$cons->{fecha}</div>
                                <div class="small text-muted fw-bold">M&eacute;dico: $nombre_medico</div>
                                <div class="d-flex gap-2 justify-content-end mt-2 flex-wrap">
                                    <a href="../api/imprimir_receta_api.pl?id_consulta=$cons->{id_consulta}" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-capsule me-1"></i>Receta</a>
                                    <a href="../api/imprimir_consentimiento_api.pl?id_consulta=$cons->{id_consulta}" target="_blank" class="btn btn-sm btn-outline-secondary rounded-pill px-3 fw-bold"><i class="bi bi-file-earmark-medical me-1"></i>Consentimiento</a>
                                    <button class="btn btn-sm btn-outline-medentia d-flex align-items-center" onclick="window.location.href='consulta_detalles.pl?id_consulta=$cons->{id_consulta}'"><i class="bi bi-eye-fill me-2"></i> Ver Detalles</button>
                                </div>
                            </div>
                        </div>
                        $receta_html
                    </div>
                </div>
HTML
        }
    } else {
        print <<HTML;
                <div class="card-medentia-aura text-center p-5">
                    <i class="bi bi-folder2-open display-1 opacity-25 mb-3 d-block" style="color: var(--md-blue-deep);"></i>
                    <h4 class="fw-black" style="color: var(--md-blue-deep);">Sin Historial Cl&iacute;nico</h4>
                    <p class="mx-auto text-muted" style="max-width: 500px;">A&uacute;n no hay consultas médicas finalizadas para este paciente.</p>
                </div>
HTML
    }
    print <<HTML;
            </div>
        </section>

        <!-- 7: RADIOGRAFÍAS / HUB DE ESTUDIOS -->
        <section class="sdm-tab-sec d-none" id="tab7">
            <div class="d-flex justify-content-between align-items-center mb-5 flex-wrap gap-3">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Hub de Im&aacute;genes y Estudios</h3>
                    <p class="text-muted small fw-bold">ADMINISTRADOR PACS Y VISOR DICOM</p>
                </div>
                <div class="d-flex gap-2 p-1 bg-transparent flex-wrap">
                    <a href="render_visor_medico.pl?id=$paciente->{id_paciente}" target="_blank" class="btn btn-medentia btn-sm d-flex align-items-center px-4">
                        <i class="bi bi-display me-2" style="color: var(--md-cyan-ia);"></i>Lanzar SDM Viewer
                    </a>
                </div>
            </div>

            <!-- Funciones de Subida removidas hacia el visor -->

            <!-- Bento Grid para el Hub de Estudios -->
            <div class="row g-4">
                <!-- Historial Reciente de Estudios (Dinámico) -->
                <div class="col-lg-8">
                    <h5 class="fw-black mt-1 mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-clock-history me-2" style="color: var(--md-teal-clinical);"></i>Estudios PACS</h5>
                    <div class="table-responsive card-medentia-aura p-4 h-100 border-0">
                        <table class="table table-hover align-middle mb-0" id="tablaEstudiosRX" style="width:100%">
                            <thead class="table-light">
                                <tr>
                                    <th class="ps-3 border-0 rounded-start-3">Fecha</th>
                                    <th class="border-0">Modalidad</th>
                                    <th class="border-0">Descripci&oacute;n</th>
                                    <th class="border-0 text-end pe-3 rounded-end-3">Acci&oacute;n</th>
                                </tr>
                            </thead>
                            <tbody class="small">
HTML
    my $ESTUDIOS_FILE_PATH = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
    my $todos_estudios = leer_tabla($ESTUDIOS_FILE_PATH, '\|');
    my @estudios_pac = grep { $_->[1] eq $d->{id_paciente} } @$todos_estudios;
    
    # Sort reverse chronological (assuming simple string sort works for DD/MM/YYYY, though ideal is proper date sort)
    # We will just reverse the array since new ones are appended.
    @estudios_pac = reverse @estudios_pac;
    
    if (@estudios_pac) {
        foreach my $est (@estudios_pac) {
            my $id_estudio = $est->[0];
            my $fecha = $est->[2];
            my $modalidad = $est->[3];
            my $desc = $est->[4];
            
            my $mod_badge = 'bg-secondary-subtle text-secondary border border-secondary-subtle';
            if ($modalidad eq 'CT') { $mod_badge = 'bg-primary-subtle text-primary border border-primary-subtle'; }
            elsif ($modalidad eq 'XR') { $mod_badge = 'bg-info-subtle text-info border border-info-subtle'; }
            elsif ($modalidad eq 'MR') { $mod_badge = 'bg-warning-subtle text-warning border border-warning-subtle'; }
            
            # Sanitizar descripcion para JS
            my $safe_desc = $desc;
            $safe_desc =~ s/'/\\'/g;

            print <<HTML;
                                <tr>
                                    <td class="ps-3 fw-bold">$fecha</td>
                                    <td><span class="badge $mod_badge">$modalidad</span></td>
                                    <td class="fw-bold text-dark">$desc</td>
                                    <td class="text-end pe-3 text-nowrap">
                                        <a href="render_visor_medico.pl?id=$d->{id_paciente}&estudio_id=$id_estudio" target="_blank" class="btn btn-sm rounded-circle btn-outline-primary ms-1" style="width: 32px; height: 32px; padding: 0; line-height: 30px;" title="Abrir Visor"><i class="bi bi-box-arrow-up-right"></i></a>
                                        <button class="btn btn-sm rounded-circle btn-outline-warning ms-1" style="width: 32px; height: 32px; padding: 0; line-height: 30px;" onclick="editarEstudio($id_estudio, '$safe_desc')" title="Editar Descripción"><i class="bi bi-pencil"></i></button>
                                        <button class="btn btn-sm rounded-circle btn-outline-danger ms-1" style="width: 32px; height: 32px; padding: 0; line-height: 30px;" onclick="eliminarEstudio($id_estudio)" title="Eliminar"><i class="bi bi-trash"></i></button>
                                    </td>
                                </tr>
HTML
        }
    } else {
        # Dejamos el tbody vacio para que DataTables muestre su propio mensaje de "sin datos"
    }
    
    print <<HTML;
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Incluir DataTables (jQuery ya se incluyó en sub_header) -->
                <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
                <link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">
                <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
                <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
                <script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
                <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
                <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
                <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/pdfmake.min.js"></script>
                <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/vfs_fonts.js"></script>
                <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
                <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>
                <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
                <script>
                    document.addEventListener('DOMContentLoaded', function() {
                        const tbl = \$('#tablaEstudiosRX').DataTable({
                            language: { url: 'https://cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
                            pageLength: 10,
                            dom: "<'row mb-3 align-items-center'<'col-sm-12 col-md-6 d-flex flex-wrap gap-2'B><'col-sm-12 col-md-6'f>>" +
                                 "<'row'<'col-sm-12'tr>>" +
                                 "<'row mt-3'<'col-sm-12 col-md-5'i><'col-sm-12 col-md-7'p>>",
                            buttons: [
                                {
                                    extend: 'copy',
                                    text: '<i class="bi bi-clipboard me-1"></i> COPY',
                                    className: 'btn btn-light fw-bolder border shadow-sm',
                                    style: 'border-radius: 12px;'
                                },
                                {
                                    extend: 'excel',
                                    text: '<i class="bi bi-file-earmark-excel me-1"></i> EXCEL',
                                    className: 'btn btn-light fw-bolder border shadow-sm',
                                    style: 'border-radius: 12px;'
                                },
                                {
                                    extend: 'pdf',
                                    text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF',
                                    className: 'btn btn-light fw-bolder border shadow-sm',
                                    style: 'border-radius: 12px;'
                                },
                                {
                                    extend: 'print',
                                    text: '<i class="bi bi-printer me-1"></i> PRINT',
                                    className: 'btn btn-light fw-bolder border shadow-sm',
                                    style: 'border-radius: 12px;'
                                }
                            ]
                        });
                        
                        // Aplicar estilos post-init a la barra de búsqueda y botones
                        \$('.dt-buttons .btn').css({ 'border-radius': '12px', 'font-weight': '800', 'color': '#475569', 'border-color': '#e2e8f0' });
                        \$('.dataTables_filter input').attr('placeholder', 'Buscar...').addClass('form-control rounded-pill px-3 shadow-sm').css('border-color', '#e2e8f0');
                        \$('.dataTables_filter label').contents().filter(function(){ return this.nodeType === 3; }).remove();
                    });

                    function eliminarEstudio(id) {
                        Swal.fire({
                            title: '¿Eliminar Estudio?',
                            text: 'Esta acción no se puede deshacer.',
                            icon: 'warning',
                            showCancelButton: true,
                            confirmButtonColor: '#dc3545',
                            confirmButtonText: 'Sí, eliminar',
                            cancelButtonText: 'Cancelar'
                        }).then((result) => {
                            if (result.isConfirmed) {
                                axios.post('../api/delete_estudio_api.pl', new URLSearchParams({id_estudio: id}))
                                .then(res => {
                                    if(res.data.ok) {
                                        Swal.fire('Eliminado', 'El estudio ha sido borrado.', 'success').then(() => {
                                            // Remove row locally instead of reload
                                            let dt = $('#estudiosTable').DataTable();
                                            let row = $('button[onclick="eliminarEstudio(\''+id+'\')"]').closest('tr');
                                            if (row.length) dt.row(row).remove().draw();
                                        });
                                    } else {
                                        Swal.fire('Error', res.data.msg, 'error');
                                    }
                                });
                            }
                        });
                    }

                    function editarEstudio(id, descActual) {
                        Swal.fire({
                            title: 'Editar Descripción',
                            input: 'text',
                            inputValue: descActual,
                            showCancelButton: true,
                            confirmButtonText: 'Guardar',
                            cancelButtonText: 'Cancelar',
                            inputValidator: (value) => {
                                if (!value) return 'La descripción no puede estar vacía';
                            }
                        }).then((result) => {
                            if (result.isConfirmed) {
                                axios.post('../api/update_estudio_api.pl', new URLSearchParams({
                                    id_estudio: id, 
                                    descripcion: result.value
                                }))
                                .then(res => {
                                    if(res.data.ok) {
                                        Swal.fire('Actualizado', 'La descripción ha sido cambiada.', 'success').then(() => {
                                            let td = $('button[onclick="editarEstudio(\''+id+'\', \''+descActual+'\')"]').closest('tr').find('td').eq(1);
                                            if(td.length) td.text(result.value);
                                        });
                                    } else {
                                        Swal.fire('Error', res.data.msg, 'error');
                                    }
                                });
                            }
                        });
                    }
                </script>


                <!-- Resumen de Almacenamiento -->
                <div class="col-lg-4">
                    <div class="card-medentia-aura p-4 border-0 h-100">
                        <h6 class="fw-black mb-4 uppercase" style="color: var(--md-blue-deep); font-size: 0.8rem; letter-spacing: 1px;">Almacenamiento PACS</h6>
                        
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">2.4 <span class="fs-6 text-muted">GB</span></h3>
                            <i class="bi bi-hdd-network fs-3" style="color: var(--md-teal-clinical);"></i>
                        </div>
                        <p class="small text-muted fw-bold mb-4">Espacio utilizado por el paciente</p>

                        <div class="progress mb-3" style="height: 8px; border-radius: 10px;">
                            <div class="progress-bar bg-primary" role="progressbar" style="width: 45%" aria-valuenow="45" aria-valuemin="0" aria-valuemax="100"></div>
                        </div>
                        
                        <ul class="list-group list-group-flush small">
                            <li class="list-group-item px-0 d-flex justify-content-between align-items-center border-0 py-1">
                                <span><i class="bi bi-circle-fill text-primary me-2" style="font-size: 0.5rem;"></i>Tomograf&iacute;as (CT)</span>
                                <span class="fw-bold text-dark">1.8 GB</span>
                            </li>
                            <li class="list-group-item px-0 d-flex justify-content-between align-items-center border-0 py-1">
                                <span><i class="bi bi-circle-fill text-info me-2" style="font-size: 0.5rem;"></i>Radiograf&iacute;as (XR)</span>
                                <span class="fw-bold text-dark">450 MB</span>
                            </li>
                            <li class="list-group-item px-0 d-flex justify-content-between align-items-center border-0 py-1">
                                <span><i class="bi bi-circle-fill text-secondary me-2" style="font-size: 0.5rem;"></i>Fotograf&iacute;as</span>
                                <span class="fw-bold text-dark">150 MB</span>
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </section>

        <!-- 1: FINANZAS (OPERATIVO TOTAL) -->
        <section class="sdm-tab-sec d-none" id="tab1">
            <h3 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-wallet2 me-2" style="color: var(--md-teal-clinical);"></i>Estado de Cuenta</h3>
            <div class="row g-3 mb-4">
                <div class="col-md-3"><div class="card-medentia-aura border-0 p-4 h-100">
                    <span class="small fw-bold text-muted text-uppercase mb-2 d-block">Saldo Pendiente</span>
                    <div class="d-flex justify-content-between align-items-center">
                        <h3 id="ecSaldo" class="fw-black text-danger m-0">\$0.00</h3>
                        <button onclick="abrirModalAbono()" class="btn btn-sm btn-outline-success fw-bold rounded-pill px-3 py-1">PAGAR</button>
                    </div>
                </div></div>
                <div class="col-md-3"><div class="card-medentia-aura border-0 p-4 h-100"><span class="small fw-bold text-muted text-uppercase mb-2 d-block">Cargos</span><h4 id="ecCargos" class="m-0 fw-bold" style="color: var(--md-blue-deep);">\$0.00</h4></div></div>
                <div class="col-md-3"><div class="card-medentia-aura border-0 p-4 h-100"><span class="small fw-bold text-muted text-uppercase mb-2 d-block">Abonos</span><h4 id="ecAbonos" class="m-0 text-success fw-bold">\$0.00</h4></div></div>
                <div class="col-md-3">
                    <button class="btn btn-medentia w-100 h-100 fw-black d-flex flex-column align-items-center justify-content-center" onclick="abrirModalCarrito()">
                        <i class="bi bi-cart-plus mb-2" style="font-size: 1.5rem; color: var(--md-cyan-ia);"></i>NUEVO CARGO
                    </button>
                </div>
            </div>
            <div class="card-medentia-aura border-0 p-4 overflow-hidden">
                <h6 class="fw-black mb-3" style="color: var(--md-blue-deep);">Movimientos de Cuenta</h6>
                <div class="table-responsive">
                    <table class="table table-sm table-hover align-middle mb-0">
                        <thead class="table-light"><tr><th class="ps-3">Folio</th><th>Fecha</th><th>Concepto</th><th class="text-end">Cargo</th><th class="text-end">Abono</th></tr></thead>
                        <tbody id="tbEdoCuenta" class="small"><tr><td colspan="5" class="text-center py-4">Iniciando motor financiero...</td></tr></tbody>
                    </table>
                </div>
            </div>
        </section>

        <section class="sdm-tab-sec d-none" id="tab2">

            <div class="d-flex justify-content-between align-items-center mb-5 flex-wrap gap-3">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Dashboard Cl&iacute;nico</h3>
                </div>
                <div class="d-flex gap-2 p-1 bg-transparent flex-wrap">
                    <button class="btn btn-outline-secondary btn-sm rounded-pill px-3 fw-bold border-0" onclick="swTab('tab3', this)"><i class="bi bi-person-gear me-1"></i>Ficha</button>
                    <button class="btn btn-medentia btn-sm rounded-pill px-3 fw-bold" onclick="swTab('tab2', this)"><i class="bi bi-heart-pulse me-1"></i>Cl&iacute;nico</button>
                    <button class="btn btn-outline-secondary btn-sm rounded-pill px-3 fw-bold border-0" onclick="swTab('tab4', this)"><i class="bi bi-journal-text me-1"></i>SOAP</button>
                    <div class="vr mx-1"></div>
                    <a href="imprime_expediente_completo.pl?id=$d->{id_paciente}" target="_blank" class="btn btn-outline-medentia btn-sm d-flex align-items-center px-3"><i class="bi bi-printer me-1" style="color: var(--md-teal-clinical);"></i>Reporte</a>
                    <button type="button" class="btn btn-medentia btn-sm d-flex align-items-center px-4" onclick="guardarFichaMaster()">
                        <i class="bi bi-shield-check me-1" style="color: var(--md-cyan-ia);"></i>Guardar
                    </button>
                </div>
            </div>

            <div class="bento-grid">
                <!-- Alertas Médicas (Crucial) -->
                <div class="bento-card card-medentia-aura alert bento-big">
                    <span class="bento-label" style="color:#e11d48">Alertas Médicas & Alergias</span>
                    <div class="mt-3">
                        <div class="d-flex align-items-center gap-3 mb-3 p-3 bg-white rounded-4 border border-danger-subtle">
                            <i class="bi bi-exclamation-triangle-fill text-danger fs-3"></i>
                            <div>
                                <h6 class="m-0 fw-bold">Sin Alergias Registradas</h6>
                                <p class="m-0 small text-muted">No se han reportado reacciones adversas.</p>
                            </div>
                        </div>
                        <p class="small text-muted italic">"El paciente no refiere enfermedades crónicas degenerativas al momento de la última actualización."</p>
                    </div>
                    <i class="bi bi-shield-exclamation bento-icon" style="color:#e11d48"></i>
                </div>

                <!-- Biométricos -->
                <div class="bento-card card-medentia-aura info">
                    <span class="bento-label">Grupo Sanguíneo</span>
                    <div class="bento-value" style="color: var(--md-blue-deep);">$d->{tipo_sangre}</div>
                    <i class="bi bi-droplet-fill bento-icon" style="color: var(--md-teal-clinical);"></i>
                </div>

                <div class="bento-card card-medentia-aura">
                    <span class="bento-label">Género / Sexo</span>
                    <div class="bento-value">$d->{sexo}</div>
                    <i class="bi bi-gender-ambiguous bento-icon"></i>
                </div>

                <!-- Perfil Social -->
                <div class="bento-card card-medentia-aura bento-wide dark">
                    <div class="row align-items-center">
                        <div class="col-7">
                            <span class="bento-label">Ocupación Actual</span>
                            <div class="bento-value" style="font-size:1.2rem;">$d->{ocupacion}</div>
                        </div>
                        <div class="col-5 text-end">
                            <span class="bento-label">Estado Civil</span>
                            <div class="fw-bold">$d->{e_civil}</div>
                        </div>
                    </div>
                    <i class="bi bi-person-workspace bento-icon"></i>
                </div>

                <!-- Resumen de Edad -->
                <div class="bento-card card-medentia-aura">
                    <span class="bento-label">Fecha de Nacimiento</span>
                    <div class="fw-bold" style="color: var(--md-blue-deep);">$d->{f_nac}</div>
                    <hr class="my-2 opacity-10">
                    <div class="small text-muted fw-bold">ID: $d->{id_paciente}</div>
                </div>
            </div>
        </section>

        <!-- 3: FICHA TÉCNICA (MODERNIZADA & FIEL AL DAT) -->
        <section class="sdm-tab-sec d-none" id="tab3">
            <div class="d-flex justify-content-between align-items-center mb-5 flex-wrap gap-3">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Perfil del Paciente</h3>
                    <p class="text-muted small fw-bold">GESTI&Oacute;N DE EXPEDIENTE MAESTRO</p>
                </div>
                <div class="d-flex gap-2 p-1 bg-transparent rounded-pill flex-wrap">
                    <a href="imprime_expediente_completo.pl?id=$d->{id_paciente}" target="_blank" class="btn btn-outline-medentia d-flex align-items-center"><i class="bi bi-printer me-2" style="color: var(--md-teal-clinical);"></i>Reporte</a>
                    <button type="button" class="btn btn-medentia d-flex align-items-center" onclick="guardarFichaMaster()">
                        <i class="bi bi-shield-check me-2" style="color: var(--md-cyan-ia);"></i>Guardar Cambios
                    </button>
                </div>
            </div>

            <form id="formFichaCRUD">
                <input type="hidden" name="id_paciente" value="$paciente->{id_paciente}">
                <div class="row g-4">
                    <div class="col-lg-8">
                        <div class="card-medentia-aura p-5 h-100">
                            <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-person-lines-fill me-2" style="color: var(--md-teal-clinical);"></i>Informaci&oacute;n de Identidad</h5>
                            <div class="row g-3">
                                <div class="col-md-12"><div class="form-floating diamond-input-armor"><input class="form-control" name="nombre" value="$paciente->{nombre}" placeholder="Nombre"><label>Nombre Completo</label></div></div>
                                <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" name="rfc" value="$paciente->{rfc}" placeholder="RFC"><label>RFC</label></div></div>
                                <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" name="curp" value="$paciente->{curp}" placeholder="CURP"><label>CURP</label></div></div>
                                <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" name="email" value="$paciente->{email}" placeholder="Email"><label>Correo Electr&oacute;nico</label></div></div>
                                <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" name="telefono" value="$paciente->{tel}" placeholder="Tel"><label>Tel&eacute;fono de Contacto</label></div></div>
                                <div class="col-md-4">
                                    <div class="form-floating diamond-input-armor">
                                        <select class="form-select" name="sexo">
                                            <option value="Masculino" @{[ $paciente->{sexo} eq 'Masculino' ? 'selected' : '' ]}>Masculino</option>
                                            <option value="Femenino" @{[ $paciente->{sexo} eq 'Femenino' ? 'selected' : '' ]}>Femenino</option>
                                            <option value="Otro" @{[ $paciente->{sexo} eq 'Otro' ? 'selected' : '' ]}>Otro</option>
                                        </select>
                                        <label>G&eacute;nero</label>
                                    </div>
                                </div>
                                <div class="col-md-4"><div class="form-floating diamond-input-armor"><input class="form-control" name="f_nac" value="$paciente->{f_nac}" type="date"><label>Fecha de Nacimiento</label></div></div>
                                <div class="col-md-4"><div class="form-floating diamond-input-armor"><input class="form-control" name="nacionalidad" value="$paciente->{nacionalidad}" placeholder="Nacionalidad"><label>Nacionalidad</label></div></div>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-4">
                        <div class="card-medentia-aura p-5 h-100">
                            <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-heart-pulse-fill me-2" style="color: var(--md-teal-clinical);"></i>Datos Cl&iacute;nicos</h5>
                            <div class="mb-4 diamond-input-armor">
                                <label class="small fw-bold text-muted mb-2 ps-1">Grupo Sangu&iacute;neo</label>
                                <select class="form-select py-3 fw-bold" name="sangre">
                                    <option value="O+" @{[ $paciente->{tipo_sangre} eq 'O+' ? 'selected' : '' ]}>O Positivo</option>
                                    <option value="O-" @{[ $paciente->{tipo_sangre} eq 'O-' ? 'selected' : '' ]}>O Negativo</option>
                                    <option value="A+" @{[ $paciente->{tipo_sangre} eq 'A+' ? 'selected' : '' ]}>A Positivo</option>
                                    <option value="A-" @{[ $paciente->{tipo_sangre} eq 'A-' ? 'selected' : '' ]}>A Negativo</option>
                                    <option value="B+" @{[ $paciente->{tipo_sangre} eq 'B+' ? 'selected' : '' ]}>B Positivo</option>
                                    <option value="AB+" @{[ $paciente->{tipo_sangre} eq 'AB+' ? 'selected' : '' ]}>AB Positivo</option>
                                </select>
                            </div>
                            <div class="mb-4 diamond-input-armor">
                                <label class="small fw-bold text-muted mb-2 ps-1">Estado Civil</label>
                                <select class="form-select py-3 fw-bold" name="e_civil">
                                    <option value="Soltero" @{[ $paciente->{e_civil} eq 'Soltero' ? 'selected' : '' ]}>Soltero/a</option>
                                    <option value="Casado" @{[ $paciente->{e_civil} eq 'Casado' ? 'selected' : '' ]}>Casado/a</option>
                                    <option value="Divorciado" @{[ $paciente->{e_civil} eq 'Divorciado' ? 'selected' : '' ]}>Divorciado/a</option>
                                    <option value="Viudo" @{[ $paciente->{e_civil} eq 'Viudo' ? 'selected' : '' ]}>Viudo/a</option>
                                </select>
                            </div>
                            <div class="mb-4 diamond-input-armor">
                                <label class="small fw-bold text-muted mb-2 ps-1">Ocupaci&oacute;n</label>
                                <div class="input-group">
                                    <span class="input-group-text border-0 bg-transparent ps-3"><i class="bi bi-briefcase" style="color: var(--md-teal-clinical);"></i></span>
                                    <input class="form-control py-3 fw-bold" name="ocupacion" value="$paciente->{ocupacion}">
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </form>
        </section>

        <!-- 4: SOAP (EVOLUCIÓN CLÍNICA) -->
        <section class="sdm-tab-sec d-none" id="tab4">
            <div class="d-flex justify-content-between align-items-center mb-5 flex-wrap gap-3">
                <div class="d-flex align-items-center gap-3">
                    <div>
                        <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Evoluci&oacute;n Cl&iacute;nica</h3>
                        <p class="text-muted small fw-bold mb-0">METODOLOG&Iacute;A S.O.A.P.</p>
                    </div>
                    <div class="vr d-none d-md-block"></div>
                    <button class="btn btn-sm btn-outline-medentia rounded-pill px-3 shadow-sm d-none d-md-block" onclick="Swal.fire({title: 'Nueva Nota', input: 'textarea', confirmButtonText: 'Añadir Evolución'})">
                        <i class="bi bi-plus-circle me-1" style="color: var(--md-teal-clinical);"></i>Nueva Nota
                    </button>
                </div>
                <div class="d-flex gap-2 p-1 bg-transparent flex-wrap">
                    <a href="imprime_expediente_completo.pl?id=$d->{id_paciente}" target="_blank" class="btn btn-outline-medentia btn-sm d-flex align-items-center px-3"><i class="bi bi-printer me-1" style="color: var(--md-teal-clinical);"></i>Reporte</a>
                    <button type="button" class="btn btn-medentia btn-sm d-flex align-items-center px-4" onclick="guardarFichaMaster()">
                        <i class="bi bi-shield-check me-1" style="color: var(--md-cyan-ia);"></i>Guardar
                    </button>
                </div>
            </div>

            <div class="soap-history">
                <div class="soap-entry card-medentia-aura p-4 mb-4 border-0 shadow-sm" style="border-radius: 20px;">
                    <span class="soap-date d-block fw-black mb-3" style="color: var(--md-teal-clinical); font-size: 1.1rem;">Sesion de Hoy - @{[scalar localtime]}</span>
                    <div class="row">
                        <div class="col-md-6 border-md-end border-bottom border-md-bottom-0 pb-3 pb-md-0 mb-3 mb-md-0">
                            <p class="small text-muted fw-bold mb-1 uppercase">Subjetivo / Objetivo</p>
                            <p class="mb-0 fw-bold" style="color: var(--md-blue-deep);">Paciente refiere ligero dolor en pieza 14 al contacto con fr&iacute;o. Se observa caries grado II en cara oclusal.</p>
                        </div>
                        <div class="col-md-6 ps-md-4">
                            <p class="small text-muted fw-bold mb-1 uppercase">An&aacute;lisis / Plan</p>
                            <p class="mb-0 fw-bold" style="color: var(--md-blue-deep);">Se programa resina compuesta para la pr&oacute;xima sesi&oacute;n. Se receta analg&eacute;sico preventivo.</p>
                        </div>
                    </div>
                </div>
                <div class="soap-entry card-medentia-aura p-4 mb-4 border-0 opacity-75 grayscale shadow-sm" style="border-radius: 20px;">
                    <span class="soap-date d-block fw-black mb-2" style="color: var(--md-teal-clinical); font-size: 1.1rem;">22/03/2026 - Consulta General</span>
                    <p class="mb-0 fw-bold" style="color: var(--md-blue-deep);">Limpieza dental profunda realizada con &eacute;xito. Enc&iacute;as sanas, se recomienda seguimiento en 6 meses.</p>
                </div>
            </div>
        </section>

        <!-- 8: FHIR (INTEROPERABILIDAD) -->
        <section class="sdm-tab-sec d-none" id="tab8">
            <div class="d-flex justify-content-between align-items-center mb-5">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Nodo HL7-FHIR R4</h3>
                    <p class="text-muted small fw-bold">EST&Aacute;NDAR INTERNACIONAL DE SALUD</p>
                </div>
                <button class="btn btn-medentia rounded-pill px-4 shadow-sm" onclick="exportFHIR()">
                    <i class="bi bi-filetype-json me-2" style="color: var(--md-cyan-ia);"></i>Exportar Recurso JSON
                </button>
            </div>

            <div class="row g-4">
                <div class="col-lg-6">
                    <div class="card-medentia-aura p-4 border-0 h-100">
                        <h6 class="fw-black mb-3" style="color: var(--md-teal-clinical);">Recurso: Patient</h6>
                        <pre class="bg-light p-3 rounded-4 small" style="color: #0369a1; font-family: 'Courier New';">
{
  "resourceType": "Patient",
  "id": "$paciente->{id_paciente}",
  "active": true,
  "name": [{ "text": "$paciente->{nombre}" }],
  "gender": "@{[lc $paciente->{sexo}]}",
  "birthDate": "$paciente->{f_nac}",
  "telecom": [{ "system": "phone", "value": "$paciente->{tel}" }]
}</pre>
                    </div>
                </div>
                <div class="col-lg-6">
                    <div class="card-medentia-aura p-4 border-0 h-100">
                        <h6 class="fw-black mb-3" style="color: var(--md-teal-clinical);">Endpoints Activos</h6>
                        <div class="list-group list-group-flush small">
                            <div class="list-group-item d-flex justify-content-between align-items-center px-0">
                                <span>SMART on FHIR API</span>
                                <span class="badge bg-success-subtle text-success">ONLINE</span>
                            </div>
                            <div class="list-group-item d-flex justify-content-between align-items-center px-0">
                                <span>HL7 V2 Gateway</span>
                                <span class="badge bg-success-subtle text-success">ONLINE</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- 9: HL7 GATEWAY -->
        <section class="sdm-tab-sec d-none" id="tab9">
            <h3 class="fw-black mb-5" style="color: var(--md-blue-deep);">Monitor de Mensajería HL7 v2.5</h3>
            <div class="card-medentia-aura p-4 border-0" style="background: var(--md-blue-deep); color: white; font-family: 'Courier New'; font-size: 0.85rem; line-height: 1.6;">
                <div class="mb-3">
                    <span class="text-success fw-bold">[SENT]</span> MSH|^~\\&|SDM|CENTRO_DENTAL|LAB|HOSPITAL|202604261945||ADT^A01|101|P|2.5
                </div>
                <div class="mb-3">
                    <span class="text-success fw-bold">[SENT]</span> PID|1||$paciente->{id_paciente}||$paciente->{nombre}||19850520|M|||AV REFORMA 100^^CDMX
                </div>
                <div class="mb-3 text-info">
                    <span class="fw-bold">[ACK]</span> MSA|AA|101|Message received successfully
                </div>
            </div>
            <div class="mt-4 p-4 card-medentia-aura border-0">
                <h6 class="fw-bold"><i class="bi bi-broadcast me-2" style="color: var(--md-teal-clinical);"></i>Conectividad Activa</h6>
                <p class="small text-muted mb-0">El sistema est&aacute; escuchando peticiones en el puerto 5001 para la recepci&oacute;n de resultados de laboratorio e im&aacute;genes DICOM.</p>
            </div>
        </section>

        <!-- 5: MENSAJES (COMUNICACIONES) -->
        <section class="sdm-tab-sec d-none" id="tab5">
            <h3 class="fw-black mb-5" style="color: var(--md-blue-deep);">Comunicaciones Enviadas</h3>
            <div class="row g-3">
HTML
    if (@$correos_ref) {
        foreach my $corr (@$correos_ref) {
            # Capturar todos los detalles
            my $id_msg = $corr->{id_correo};
            my $cat    = $corr->{categoria} || 'General';
            my $adj    = $corr->{adjunto}   || 'Ninguno';
            my $asunto_esc = $corr->{asunto}; $asunto_esc =~ s/'/\\'/g;
            my $cuerpo_esc = $corr->{cuerpo}; $cuerpo_esc =~ s/'/\\'/g;
            $cuerpo_esc =~ s/\r?\n/\\n/g;

            print qq{
                <div class="col-12">
                    <div class="card-medentia-aura p-4 border-0 d-flex gap-4 align-items-center transition-all" 
                         onclick="verDetalleMensaje('$id_msg', '$asunto_esc', '$corr->{fecha}', '$cuerpo_esc', '$cat', '$adj')"
                         style="cursor: pointer;">
                        <div class="p-3 rounded-4" style="background: rgba(25, 183, 165, 0.1); color: var(--md-teal-clinical);">
                            <i class="bi bi-envelope-check fs-3"></i>
                        </div>
                        <div class="flex-grow-1 overflow-hidden">
                            <div class="d-flex align-items-center justify-content-between gap-2 mb-1">
                                <h6 class="fw-bold m-0 text-truncate">$corr->{asunto}</h6>
                                <span class="badge bg-light text-muted small fw-bold">$corr->{fecha}</span>
                            </div>
                            <div class="d-flex align-items-center gap-2">
                                <span class="badge bg-primary-subtle text-primary border-0 rounded-pill px-2 py-1" style="font-size:0.6rem;">$cat</span>
                                <p class="small text-muted mb-0 text-truncate">$corr->{cuerpo}</p>
                            </div>
                        </div>
                        <div class="text-muted opacity-25">
                            <i class="bi bi-chevron-right fs-4"></i>
                        </div>
                    </div>
                </div>
            };
        }
    } else {
        print qq{<div class="text-center py-5 opacity-25"><i class="bi bi-chat-left-dots display-1 d-block mb-3"></i><p class="fw-bold">No hay mensajes registrados en la bit&aacute;cora.</p></div>};
    }
    print <<HTML;
            </div>
        </section>
HTML
    utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/estado_cuenta_spa.js?v=$^T"></script>
<script src="../js/odontograma_spa.js?v=$^T"></script>
<script>
    document.addEventListener('DOMContentLoaded', () => { 
        initModuloFinanciero('$d->{id_paciente}', 'bento', '$id_medico_actual');
    });
    
    function abrirModalCarrito() { 
        windowActiveOS = null; // Reiniciar contexto de OS
        const modalEl = document.getElementById('modalCargo');
        if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        carritoApp = []; 
        refrescarGUICarrito(); 
        m.show(); 
    }
    
    function abrirModalCargoConOS(id_os) {
        windowActiveOS = id_os;
        const modalEl = document.getElementById('modalCargo');
        if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
        carritoApp = [];
        refrescarGUICarrito();
        bootstrap.Modal.getOrCreateInstance(modalEl).show();
    }
    
    function abrirModalAbono() { 
        const modalEl = document.getElementById('modalAbono');
        if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        document.getElementById('montoAbono').value = ''; 
        m.show(); 
    }

    function verDetalleMensaje(id, asunto, fecha, cuerpo, cat, adjunto) {
        console.log("DEBUG: verDetalleMensaje triggered", {id, asunto, fecha, cuerpo, cat, adjunto});
        
        const modalEl = document.getElementById('modalMensaje');
        if (modalEl && modalEl.parentElement !== document.body) {
            console.log("DEBUG: Teleporting modalMensaje to body...");
            document.body.appendChild(modalEl);
        }

        document.getElementById('msgDetailID').innerText = id;
        document.getElementById('msgDetailAsunto').innerText = asunto;
        document.getElementById('msgDetailFecha').innerText = fecha;
        document.getElementById('msgDetailCuerpo').innerText = cuerpo;
        document.getElementById('msgDetailCat').innerText = cat;
        
        const adjContainer = document.getElementById('msgDetailAdjunto');
        const adjSpan = adjContainer.querySelector('span');
        adjSpan.innerText = adjunto;
        
        if(adjunto !== 'Sin adjuntos' && adjunto !== 'Ninguno') {
            adjContainer.style.cursor = 'pointer';
            adjContainer.onclick = () => abrirAdjunto(adjunto);
            adjSpan.classList.add('text-primary');
        } else {
            adjContainer.style.cursor = 'default';
            adjContainer.onclick = null;
            adjSpan.classList.remove('text-primary');
        }
        
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        
        modalEl.addEventListener('shown.bs.modal', function () {
            console.log("DEBUG: Modal shown. Checking Z-Index...");
            const backdrop = document.querySelector('.modal-backdrop');
            console.log("Modal Z-Index:", window.getComputedStyle(modalEl).zIndex);
            if(backdrop) console.log("Backdrop Z-Index:", window.getComputedStyle(backdrop).zIndex);
            
            // Comprobar ancestros para Stacking Context
            let parent = modalEl.parentElement;
            while (parent && parent !== document.body) {
                const s = window.getComputedStyle(parent);
                if (s.transform !== 'none' || s.opacity < 1 || s.filter !== 'none') {
                    console.warn("DEBUG WARNING: Parent has Stacking Context property!", parent, {
                        transform: s.transform,
                        opacity: s.opacity,
                        filter: s.filter
                    });
                }
                parent = parent.parentElement;
            }
        }, { once: true });

        m.show();
    }

    function abrirAdjunto(file) {
        console.log("DEBUG: abrirAdjunto", file);
        const modalEl = document.getElementById('modalPreview');
        if (modalEl && modalEl.parentElement !== document.body) {
            console.log("DEBUG: Teleporting modalPreview to body...");
            document.body.appendChild(modalEl);
        }

        const url = '../dat/adjuntos_crm/$d->{id_paciente}/' + file;
        const previewBody = document.getElementById('previewBody');
        previewBody.innerHTML = '';
        
        const ext = file.split('.').pop().toLowerCase();
        if(['jpg','jpeg','png','webp','gif'].includes(ext)) {
            previewBody.innerHTML = '<div class="preview-container"><img src="' + url + '" class="animate__animated animate__zoomIn"></div>';
        } else if(ext === 'pdf') {
            previewBody.innerHTML = '<div class="preview-container"><iframe src="' + url + '"></iframe></div>';
        } else {
            console.log("DEBUG: Non-previewable file, opening in new tab", url);
            window.open(url, '_blank');
            return;
        }
        
        document.getElementById('previewTitle').innerText = file;
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        m.show();
    }

    function verXRay(url, titulo) {
        Swal.fire({
            title: titulo,
            imageAlt: 'Radiografía del Paciente',
            imageUrl: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&q=80&w=800',
            imageWidth: 800,
            background: '#000',
            color: '#fff',
            confirmButtonText: 'Cerrar Visor',
            confirmButtonColor: 'var(--sdm-blue)'
        });
    }

    function exportFHIR() {
        Swal.fire({
            title: 'Exportando Recurso FHIR',
            html: 'Generando bundle de interoperabilidad...',
            timer: 1500,
            didOpen: () => { Swal.showLoading(); }
        }).then(() => {
            Swal.fire('Éxito', 'Recurso Patient/$d->{id_paciente} exportado correctamente a JSON R4', 'success');
        });
    }
    
    async function guardarFichaMaster() {
        const form = document.getElementById('formFichaCRUD');
        const formData = new FormData(form);
        
        // Mapeo dinámico al estándar de pacientes_crud_api.pl
        const payload = {
            accion: 'actualizar',
            id: formData.get('id_paciente'),
            nombre: formData.get('nombre'),
            rfc: formData.get('rfc'),
            curp: formData.get('curp'),
            correo: formData.get('email'),
            fecha_nac: formData.get('f_nac'),
            genero: formData.get('sexo'),
            ocupacion: formData.get('ocupacion'),
            estado_civil: formData.get('e_civil'),
            nacionalidad: formData.get('nacionalidad'),
            tipo_sangre: formData.get('sangre'),
            telefono: formData.get('telefono')
        };

        Swal.fire({ 
            title: 'Sincronizando con Nodo Central', 
            html: 'Validando integridad del expediente...',
            allowOutsideClick: false,
            didOpen: () => { Swal.showLoading(); } 
        });
        
        try {
            const res = await fetch('../api/pacientes_crud_api.pl', { 
                method: 'POST', 
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload) 
            });
            const data = await res.json();
            
            if (data.ok) { 
                Swal.fire({
                    icon: 'success',
                    title: '¡Sincronizaci&oacute;n Exitosa!',
                    text: data.msg,
                    confirmButtonColor: 'var(--sdm-blue)'
                }); 
            } else {
                Swal.fire("Inconsistencia", data.msg || "Error en el servidor central", "warning");
            }
        } catch(e) { 
            Swal.fire("Error Cr&iacute;tico", "No se pudo establecer conexi&oacute;n con el Nodo de Datos.", "error"); 
        }
    }

    function verDetalleConsulta(id_consulta, fecha, medico) {
        const rawJson = document.getElementById('data_cons_' + id_consulta).value;
        let data = {};
        try { data = JSON.parse(rawJson); } catch(e) { console.error("JSON Error", e); }
        
        document.getElementById('detConsID').innerText = id_consulta;
        document.getElementById('detConsFecha').innerText = fecha;
        document.getElementById('detConsMed').innerText = medico;
        
        document.getElementById('detConsMotivo').innerText = data.motivo || 'N/A';
        document.getElementById('detConsPeso').innerText = data.peso ? data.peso + ' kg' : '--';
        document.getElementById('detConsFC').innerText = data.fc ? data.fc + ' bpm' : '--';
        document.getElementById('detConsTA').innerText = data.ta || '--';
        document.getElementById('detConsTemp').innerText = data.temperatura ? data.temperatura + ' °C' : '--';
        
        document.getElementById('detConsExploracion').innerText = data.exploracion || 'Sin registro';
        document.getElementById('detConsDiagnostico').innerText = data.diagnostico || 'Sin registro';
        document.getElementById('detConsTratamiento').innerText = data.tratamiento || 'Sin registro';
        
        const tbReceta = document.getElementById('detConsReceta');
        tbReceta.innerHTML = '';
        if (data.medicamentos && data.medicamentos.length > 0) {
            data.medicamentos.forEach(m => {
                tbReceta.innerHTML += "<tr>" +
                    "<td>" + (m.nombre || '') + "</td>" +
                    "<td>" + (m.cantidad || '') + "</td>" +
                    "<td>" + (m.indicaciones || '') + "</td>" +
                "</tr>";
            });
            document.getElementById('detConsRecetaCont').classList.remove('d-none');
        } else {
            document.getElementById('detConsRecetaCont').classList.add('d-none');
        }
        
        // Link para impresión
        document.getElementById('btnImprimirNota').onclick = function() {
            window.open('imprime_nota_medica.pl?id_consulta=' + id_consulta, '_blank');
        };
        
        const modalEl = document.getElementById('modalDetalleConsulta');
        if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
        bootstrap.Modal.getOrCreateInstance(modalEl).show();
    }
</script>

<!-- MODALES PREMIUM CRYSTAL (FUERA DE CONTENEDORES PARA EVITAR PROBLEMAS DE CAPAS) -->
<div class="modal fade" id="modalCargo" tabindex="-1">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl overflow-hidden" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header bg-dark text-white p-4 px-5 border-0">
                <h3 class="fw-black m-0 plus-jakarta"><i class="bi bi-cart-plus me-3 text-info"></i>Cat&aacute;logo de Servicios</h3>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-5">
                <div class="row g-4">
                    <div class="col-lg-7">
                        <div class="input-group input-group-lg mb-4">
                            <span class="input-group-text bg-white border-end-0 rounded-start-4"><i class="bi bi-search"></i></span>
                            <input id="buscadorCatalogo" class="form-control border-start-0 rounded-end-4 shadow-sm" placeholder="Buscar tratamiento..." onkeyup="filtrarCatalogo()">
                        </div>
                        <div id="divCatalogo" class="row g-2 overflow-auto" style="max-height: 450px; padding-right: 10px;"></div>
                    </div>
                    <div class="col-lg-5">
                        <div class="bg-light rounded-5 p-4 shadow-inner d-flex flex-column h-100">
                             <h5 class="fw-black mb-3 text-primary uppercase small tracking-widest">Resumen de Cargo</h5>
                             <div id="listaCarrito" class="flex-grow-1 overflow-auto mb-4" style="max-height: 350px;"></div>
                             <div class="pt-3 border-top">
                                <div class="form-check form-switch mb-3">
                                    <input class="form-check-input" type="checkbox" id="checkFactura" onchange="refrescarGUICarrito()">
                                    <label class="form-check-label small fw-bold text-muted" for="checkFactura">Aplica IVA (Factura)</label>
                                </div>
                                <div class="d-flex justify-content-between align-items-center mb-4">
                                    <span class="fw-bold text-muted">TOTAL A CARGAR</span>
                                    <span class="h2 fw-black text-dark m-0" id="carritoTotal">\$0.00</span>
                                </div>
                                <button id="btnProcesarCargo" class="btn btn-primary w-100 py-3 fw-bold rounded-4 shadow-lg" onclick="procesarCarrito()">CONFIRMAR CARGO</button>
                             </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalAbono" tabindex="-1">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <h3 class="fw-black plus-jakarta" id="modalAbonoTitle">Registrar Pago</h3>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4 pt-0 text-center">
                <div class="p-4 bg-success-subtle rounded-4 mb-4 mt-3">
                    <span class="kpi-label text-success">Monto a Recibir</span>
                    <input id="montoAbono" class="bg-transparent border-0 w-100 text-center fw-black display-4 text-success" placeholder="\$0.00">
                </div>
                <div class="mb-4 text-start">
                    <label class="kpi-label">M&eacute;todo de Pago</label>
                    <select id="metodoAbono" class="form-select py-3 rounded-4 border-0 bg-light fw-bold">
                        <option>Efectivo</option>
                        <option>Tarjeta</option>
                        <option>Transferencia</option>
                    </select>
                </div>
                <input type="hidden" id="notasAbono" value="">
                <button class="btn btn-success btn-lg w-100 py-3 rounded-4 fw-black shadow-lg" onclick="procesarAbono()">CONFIRMAR ABONO</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalDetalleConsulta" tabindex="-1">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-primary text-white p-2 rounded-3 shadow-sm"><i class="bi bi-file-earmark-medical-fill fs-5"></i></div>
                    <h4 class="fw-black m-0 plus-jakarta">Expediente Cl&iacute;nico</h4>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4">
                <div class="bg-light rounded-4 p-3 mb-4 d-flex justify-content-between align-items-center border">
                    <div>
                        <span class="badge bg-secondary-subtle text-secondary mb-1" id="detConsID"></span>
                        <div class="small fw-bold text-dark"><i class="bi bi-calendar-event me-1 text-primary"></i> <span id="detConsFecha"></span></div>
                    </div>
                    <div class="text-end">
                        <div class="small text-muted fw-bold">M&eacute;dico Tratante</div>
                        <div class="fw-black text-dark" id="detConsMed"></div>
                    </div>
                </div>

                <div class="row g-4 mb-4">
                    <div class="col-md-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Motivo de Consulta</label>
                        <div class="p-3 bg-white border rounded-4 shadow-sm" id="detConsMotivo" style="min-height: 60px;"></div>
                    </div>
                    <div class="col-md-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Signos Vitales</label>
                        <div class="d-flex gap-2 flex-wrap">
                            <span class="badge bg-light text-dark border p-2"><i class="bi bi-person-standing text-primary me-1"></i> <span id="detConsPeso"></span></span>
                            <span class="badge bg-light text-dark border p-2"><i class="bi bi-heart-pulse text-danger me-1"></i> <span id="detConsFC"></span></span>
                            <span class="badge bg-light text-dark border p-2"><i class="bi bi-activity text-warning me-1"></i> <span id="detConsTA"></span></span>
                            <span class="badge bg-light text-dark border p-2"><i class="bi bi-thermometer text-info me-1"></i> <span id="detConsTemp"></span></span>
                        </div>
                    </div>
                </div>

                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Exploraci&oacute;n F&iacute;sica</label>
                    <div class="p-3 bg-light border rounded-4 text-dark" id="detConsExploracion"></div>
                </div>

                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Diagn&oacute;stico</label>
                    <div class="p-3 bg-danger-subtle border border-danger-subtle rounded-4 text-danger-emphasis fw-bold" id="detConsDiagnostico"></div>
                </div>

                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Plan / Tratamiento</label>
                    <div class="p-3 bg-success-subtle border border-success-subtle rounded-4 text-success-emphasis" id="detConsTratamiento"></div>
                </div>

                <div id="detConsRecetaCont" class="mb-2 d-none">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-2 d-block"><i class="bi bi-prescription2 text-primary me-1"></i> Receta Emitida</label>
                    <div class="table-responsive bg-white rounded-4 border shadow-sm">
                        <table class="table table-sm table-hover mb-0">
                            <thead class="bg-light"><tr><th class="ps-3">F&aacute;rmaco</th><th>Cant.</th><th>Indicaciones</th></tr></thead>
                            <tbody id="detConsReceta" class="small"></tbody>
                        </table>
                    </div>
                </div>
            </div>
            <div class="modal-footer border-0 p-4 pt-0 d-flex justify-content-between">
                <div class="small text-muted fw-bold"><i class="bi bi-shield-lock-fill text-success me-1"></i> Registro Hist&oacute;rico (Solo Lectura)</div>
                <div class="d-flex gap-2">
                    <button type="button" class="btn btn-light rounded-pill px-4 fw-bold" data-bs-dismiss="modal">Cerrar</button>
                    <button type="button" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm" id="btnImprimirNota"><i class="bi bi-printer-fill me-2"></i>Imprimir Nota</button>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalMensaje" tabindex="-1">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-primary-subtle text-primary p-2 rounded-3"><i class="bi bi-envelope-open-fill"></i></div>
                    <h4 class="fw-black m-0 plus-jakarta">Detalle del Mensaje</h4>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4 pt-4">
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Asunto del Mensaje</label>
                    <h5 id="msgDetailAsunto" class="fw-bold text-dark"></h5>
                </div>
                <div class="row g-3 mb-4">
                    <div class="col-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">ID Registro</label>
                        <div id="msgDetailID" class="fw-bold text-dark small"></div>
                    </div>
                    <div class="col-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Categor&iacute;a</label>
                        <span id="msgDetailCat" class="badge bg-primary-subtle text-primary border-0 rounded-pill px-3 py-1"></span>
                    </div>
                </div>
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Fecha de Env&iacute;o</label>
                    <div id="msgDetailFecha" class="small fw-bold text-primary"></div>
                </div>
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Archivo Adjunto</label>
                    <div id="msgDetailAdjunto" class="small fw-bold text-dark"><i class="bi bi-paperclip me-1"></i> <span></span></div>
                </div>
                <hr class="my-4 opacity-10">
                <div class="bg-light p-4 rounded-4 border">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-2 d-block">Contenido / Cuerpo</label>
                    <p id="msgDetailCuerpo" class="m-0 text-dark" style="white-space: pre-wrap; line-height: 1.6;"></p>
                </div>
            </div>
            <div class="modal-footer border-0 p-4 pt-0">
                <button class="btn btn-navy w-100 py-3 rounded-4 fw-bold text-white shadow-lg" style="background: var(--sdm-navy);" data-bs-dismiss="modal">CERRAR LECTURA</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalPreview" tabindex="-1">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-dark text-white p-2 rounded-3"><i class="bi bi-eye-fill"></i></div>
                    <h4 class="fw-black m-0 plus-jakarta" id="previewTitle">Vista Previa</h4>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4" id="previewBody">
            </div>
        </div>
    </div>
</div>
    </div>
HTML
    utils::sub_sidebar::render_sidebar_footer();
}

sub calcular_edad {
    my ($fecha_nac) = @_;
    return 'N/A' unless $fecha_nac && $fecha_nac =~ /^(\d{4})-(\d{2})-(\d{2})$/;
    my ($ano, $mes, $dia) = ($1, $2, $3);
    my (undef, undef, undef, $mday, $mon, $year) = localtime();
    $year += 1900;
    $mon += 1;
    my $edad = $year - $ano;
    if ($mon < $mes || ($mon == $mes && $mday < $dia)) {
        $edad--;
    }
    return $edad >= 0 ? $edad : 0;
}

sub cargar_datos_paciente {
    my ($id) = @_; my $res = leer_tabla(File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat'), '\|');
    foreach my $c (@$res) { if ($c->[0] eq $id) { 
        my $n = $c->[2]//'';
        return { 
            id_paciente  => $c->[0], 
            id_medico    => $c->[1], 
            nombre       => $n, 
            iniciales    => uc(substr($n,0,1)||'P'), 
            rfc          => $c->[3], 
            curp         => $c->[4], 
            email        => $c->[5], 
            f_nac        => $c->[6], 
            sexo         => $c->[7], 
            ocupacion    => $c->[8], 
            e_civil      => $c->[9], 
            nacionalidad => $c->[10],
            tipo_sangre  => $c->[11], 
            tel          => $c->[12],
            tenant       => $c->[13] // ''
        }; 
    } }
    return undef;
}

sub cargar_citas_paciente {
    my ($id) = @_; my @h; my $res = leer_tabla(File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat'), '\|');
    foreach my $c (@$res) { if ($c->[2] eq $id) { push @h, { id_cita=>$c->[0], id_medico=>$c->[1]||'N/A', fecha=>$c->[3], hora=>$c->[4], motivo=>$c->[6], estado=>$c->[8] }; } }
    return sort { $b->{fecha} cmp $a->{fecha} } @h;
}

sub cargar_historial_consultas {
    my ($id) = @_; my @h; 
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
    open(my $fh, "<:encoding(UTF-8)", $path) or return \@h;
    my $cabecera = <$fh>;
    while(<$fh>){ 
        chomp; 
        my @c = split /\|/, $_, -1; 
        if($c[1] eq $id){ 
            my $json_str = $c[5];
            $json_str =~ s/\\n/\n/g if defined $json_str;
            my $data = {};
            eval { $data = decode_json($json_str); };
            
            my ($sec,$min,$hour,$mday,$mon,$year) = localtime($c[4]);
            my $fecha_str = sprintf("%04d-%02d-%02d %02d:%02d", $year+1900, $mon+1, $mday, $hour, $min);
            
            push @h, { 
                id_consulta => $c[0], 
                id_cita     => $c[2],
                id_medico   => $c[3],
                timestamp   => $c[4],
                fecha       => $fecha_str,
                data        => $data
            }; 
        } 
    }
    close $fh;
    my @sorted = sort { $b->{timestamp} <=> $a->{timestamp} } @h;
    return \@sorted;
}

sub cargar_historial_correos {
    my ($id) = @_; my @h; 
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'historial_correos.dat');
    open(my $fh, "<:encoding(UTF-8)", $path) or return @h;
    while(<$fh>){ 
        chomp; 
        my @c = split /\|/; 
        if($c[1] eq $id){ 
            push @h, { 
                id_correo => $c[0], 
                fecha     => $c[2], 
                asunto    => $c[3], 
                cuerpo    => $c[4] || 'Sin contenido',
                categoria => $c[4] || 'General',
                adjunto   => $c[5] || 'Sin adjuntos'
            }; 
        } 
    }
    close $fh; return @h;
}
sub obtener_nombre_medico { my ($id) = @_; return 'Dr(a). Desconocido' unless $id; my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat'); my $res = leer_tabla($path, '!'); foreach my $row (@$res) { if ($row->[0] eq $id || "DOC-" . sprintf("%03d", $row->[0]) eq $id || $row->[0] eq $id) { return "Dr(a). " . $row->[1]; } } return $id; }
1;
