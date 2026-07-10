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
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_usuario = $sd->{id_usuario}; # ID del usuario activo (Ejecutivo de ventas)

# Seguridad: Sólo Ejecutivo de Ventas (o Admin Global para revisar)
if ($role ne 'Ejecutivo Ventas' && $role ne 'Administrador Global') {
    print $q->header(-status => '403 Forbidden');
    print "<h1>Acceso Denegado</h1><p>Esta sección es exclusiva para la Fuerza de Ventas.</p>";
    exit;
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => "CRM Ventas Corporativo",
    skip_header => 1
);

# Leer Organizaciones Actuales del Ejecutivo
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $regs_negocios = leer_tabla($archivo_negocios, '\|');
my @mis_organizaciones = ();

if ($regs_negocios) {
    foreach my $r (@$regs_negocios) {
        next if @$r < 14;
        # r[0]: ID, r[1]: NOMBRE, r[2]: ID_MATRIZ, r[10]: RFC, r[13]: ID_VENDEDOR
        # Organizaciones raíz (ID_MATRIZ=0)
        if ($r->[2] eq '0' && ($r->[13] eq $id_usuario || $role eq 'Administrador Global')) {
            push @mis_organizaciones, { 
                id => $r->[0], 
                nombre => $r->[1], 
                rfc => $r->[10],
                fecha => $r->[4] || 'N/A'
            };
        }
    }
}

print <<HTML;
<!-- Inyectar Layout General -->
<div class="d-flex w-100 h-100 bg-light">
HTML
utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario);
print <<HTML;
    <main class="flex-grow-1" style="margin-left: var(--sidebar-width); margin-bottom: 70px; overflow-y: auto;">
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-briefcase-fill me-2"></i>CRM Ventas Corporativo</h2>
                    <p class="text-white-50 small mb-0 mt-1">Gestión de Nuevas Organizaciones y Licencias</p>
                </div>
            </div>
        </header>

        <!-- CONTAINER -->
        <div class="container-fluid px-4 pb-5">
            <div class="row g-4">
                
                <!-- CARD: CREAR ORGANIZACION -->
                <div class="col-12 col-xl-4">
                    <div class="card card-medentia-aura border-0 h-100 shadow-sm">
                        <div class="card-body p-4 d-flex flex-column align-items-center text-center">
                            <div class="kpi-icon-box bg-primary text-white shadow-sm mb-3" style="width: 70px; height: 70px; border-radius: 20px; display: flex; align-items: center; justify-content: center; font-size: 2rem;">
                                <i class="bi bi-hospital"></i>
                            </div>
                            <h4 class="fw-bold text-dark mb-2">Venta de Licencia</h4>
                            <p class="text-muted small mb-4">Registra una nueva Organización o Cadena de Clínicas en el sistema (Crea el entorno y el usuario dueño).</p>
                            
                            <button type="button" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm w-100 mt-auto" data-bs-toggle="modal" data-bs-target="#modalAltaOrganizacion">
                                <i class="bi bi-plus-circle me-2"></i>Registrar Organización
                            </button>
                        </div>
                    </div>
                </div>
                
                <!-- LISTA DE ORGANIZACIONES -->
                <div class="col-12 col-xl-8">
                    <div class="card card-medentia-aura border-0 h-100 shadow-sm">
                        <div class="card-header bg-white border-0 pt-4 pb-0 px-4">
                            <h5 class="fw-bold text-dark"><i class="bi bi-building text-primary me-2"></i>Mis Clientes (Organizaciones)</h5>
                        </div>
                        <div class="card-body p-4">
                            <div class="table-responsive">
                                <table class="table table-hover align-middle border-bottom">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Clínica / Organización</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">RFC</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Inicio Suscripción</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

if (@mis_organizaciones) {
    foreach my $org (@mis_organizaciones) {
        print <<HTML;
                                        <tr>
                                            <td>
                                                <div class="d-flex align-items-center">
                                                    <div class="bg-primary bg-opacity-10 text-primary rounded-circle d-flex justify-content-center align-items-center fw-bold me-3" style="width: 40px; height: 40px;">
                                                        <i class="bi bi-building"></i>
                                                    </div>
                                                    <span class="fw-bold text-dark">$$org{nombre}</span>
                                                </div>
                                            </td>
                                            <td class="text-muted small fw-bold">$$org{rfc}</td>
                                            <td class="text-muted small">$$org{fecha}</td>
                                        </tr>
HTML
    }
} else {
    print <<HTML;
                                        <tr>
                                            <td colspan="3" class="text-center py-4 text-muted">
                                                <i class="bi bi-inbox fs-3 d-block mb-2 text-black-50"></i>
                                                Aún no has registrado ninguna organización.
                                            </td>
                                        </tr>
HTML
}

print <<HTML;
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    </main>
</div>

<style>
  .modal-backdrop.show { z-index: 104900 !important; }
  .dimension-section { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1.5rem; margin-bottom: 1.5rem; }
  .dimension-title { font-weight: 800; color: #1e293b; margin-bottom: 1rem; font-size: 1rem; text-transform: uppercase; letter-spacing: 0.5px; }
  .check-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 0.75rem; }
</style>
<!-- Modal: Alta Organización -->
<div class="modal fade modal-diamond" id="modalAltaOrganizacion" tabindex="-1" aria-hidden="true" style="z-index: 105000 !important;">
    <div class="modal-dialog modal-dialog-centered modal-xl modal-dialog-scrollable">
        <form id="form-alta-organizacion" class="w-100">
            <div class="modal-content border-0 shadow-lg rounded-4">
                <div class="modal-header border-0 bg-primary bg-gradient text-white py-3 px-4 rounded-top-4">
                    <h4 class="fw-black mb-0"><i class="bi bi-building-add me-2"></i>Configurador SaaS - Nueva Organización</h4>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body p-4">
                    
                    <div class="row g-4">
                        <!-- Columna Izquierda: Datos Core -->
                        <div class="col-12 col-lg-5 border-end-lg pe-lg-4">
                            
                            <div class="dimension-section">
                                <h6 class="dimension-title"><i class="bi bi-person-badge text-primary me-2"></i>A. Entidad Jurídica</h6>
                                <div class="mb-3">
                                    <label class="form-label small fw-bold text-muted">Nombre Comercial</label>
                                    <input type="text" class="form-control bg-white shadow-sm border-0 rounded-3" name="nombre_org" required placeholder="Ej: Clínicas Salud Total">
                                </div>
                                <div class="mb-3">
                                    <label class="form-label small fw-bold text-muted">RFC (Opcional)</label>
                                    <input type="text" class="form-control bg-white shadow-sm border-0 rounded-3" name="rfc_org" placeholder="ABC123456T89">
                                </div>
                                <div class="mb-3">
                                    <label class="form-label small fw-bold text-muted">Naturaleza Jurídica</label>
                                    <select class="form-select bg-white shadow-sm border-0 rounded-3" name="naturaleza_juridica" required>
                                        <option value="Privado" selected>Privado</option>
                                        <option value="Público">Público</option>
                                        <option value="Mixto">Mixto</option>
                                    </select>
                                </div>
                            </div>

                            <div class="dimension-section">
                                <h6 class="dimension-title"><i class="bi bi-shield-lock text-primary me-2"></i>B. Dueño de la Plataforma</h6>
                                <div class="mb-3">
                                    <label class="form-label small fw-bold text-muted">Nombre Completo</label>
                                    <input type="text" class="form-control bg-white shadow-sm border-0 rounded-3" name="nombre_admin" required placeholder="Ej: Dr. Roberto Gómez">
                                </div>
                                <div class="mb-3">
                                    <label class="form-label small fw-bold text-muted">Correo Electrónico (Login)</label>
                                    <input type="email" class="form-control bg-white shadow-sm border-0 rounded-3" name="correo_admin" required placeholder="director\@saludtotal.com">
                                </div>
                                <div class="mb-3">
                                    <label class="form-label small fw-bold text-muted">Contraseña Inicial</label>
                                    <input type="password" class="form-control bg-white shadow-sm border-0 rounded-3" name="clave_admin" required placeholder="••••••••">
                                </div>
                            </div>

                        </div>

                        <!-- Columna Derecha: Dimensiones SaaS -->
                        <div class="col-12 col-lg-7">
                            
                            <div class="dimension-section">
                                <h6 class="dimension-title"><i class="bi bi-diagram-3 text-primary me-2"></i>C. Dimensión Operativa</h6>
                                <div class="row g-3">
                                    <div class="col-md-6">
                                        <label class="form-label small fw-bold text-muted">Tipo de Organización</label>
                                        <select class="form-select bg-white shadow-sm border-0 rounded-3" name="tipo_organizacion" required>
                                            <option value="Consultorio Individual">Consultorio Individual</option>
                                            <option value="Consultorio Compartido">Consultorio Compartido</option>
                                            <option value="Clínica" selected>Clínica</option>
                                            <option value="Hospital">Hospital</option>
                                            <option value="Cadena">Cadena</option>
                                            <option value="Universidad">Universidad</option>
                                            <option value="Gobierno">Gobierno</option>
                                            <option value="Laboratorio">Laboratorio</option>
                                            <option value="Imagenología">Imagenología</option>
                                            <option value="Otro">Otro</option>
                                        </select>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label small fw-bold text-muted">¿Reporta a Institución Pública?</label>
                                        <select class="form-select bg-white shadow-sm border-0 rounded-3" id="selectReportaInstitucion" name="reporta_institucion" required>
                                            <option value="No" selected>No</option>
                                            <option value="Sí">Sí</option>
                                        </select>
                                    </div>
                                    <div class="col-12 d-none" id="cajaInstituciones">
                                        <label class="form-label small fw-bold text-muted">Seleccione Institución(es)</label>
                                        <div class="check-grid bg-white p-3 shadow-sm border-0 rounded-3">
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="SIS" id="inst1"><label class="form-check-label small" for="inst1">SIS</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="IMSS" id="inst2"><label class="form-check-label small" for="inst2">IMSS</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="ISSSTE" id="inst3"><label class="form-check-label small" for="inst3">ISSSTE</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="IMSS Bienestar" id="inst4"><label class="form-check-label small" for="inst4">IMSS Bienestar</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="Secretaría Estatal" id="inst5"><label class="form-check-label small" for="inst5">Secretaría Estatal</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="PEMEX" id="inst6"><label class="form-check-label small" for="inst6">PEMEX</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="SEDENA" id="inst7"><label class="form-check-label small" for="inst7">SEDENA</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="SEMAR" id="inst8"><label class="form-check-label small" for="inst8">SEMAR</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="Universidad" id="inst9"><label class="form-check-label small" for="inst9">Universidad</label></div>
                                            <div class="form-check"><input class="form-check-input" type="checkbox" name="institucion[]" value="Otro" id="inst10"><label class="form-check-label small" for="inst10">Otro</label></div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="dimension-section">
                                <h6 class="dimension-title"><i class="bi bi-box-seam text-primary me-2"></i>D. Capacidades SaaS Requeridas</h6>
                                <p class="small text-muted mb-3">Selecciona los módulos a activar para el Tenant.</p>
                                <div class="check-grid">
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Expediente Clínico" id="cap1" checked><label class="form-check-label fw-bold" for="cap1">Expediente Clínico</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Agenda" id="cap2" checked><label class="form-check-label fw-bold" for="cap2">Agenda</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Imagenología" id="cap3"><label class="form-check-label fw-bold" for="cap3">Imagenología</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Inventario" id="cap4"><label class="form-check-label fw-bold" for="cap4">Inventario</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Facturación" id="cap5"><label class="form-check-label fw-bold" for="cap5">Facturación</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Telemedicina" id="cap6"><label class="form-check-label fw-bold" for="cap6">Telemedicina</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="CRM" id="cap7"><label class="form-check-label fw-bold" for="cap7">CRM</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Interoperabilidad SIS" id="cap8"><label class="form-check-label fw-bold text-primary" for="cap8">Interop. SIS</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Interoperabilidad FHIR" id="cap9"><label class="form-check-label fw-bold text-primary" for="cap9">Interop. FHIR</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="HL7" id="cap10"><label class="form-check-label fw-bold text-primary" for="cap10">HL7</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="DICOM" id="cap11"><label class="form-check-label fw-bold text-primary" for="cap11">DICOM</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Exportación CSV" id="cap12"><label class="form-check-label fw-bold" for="cap12">Exportación CSV</label></div>
                                    <div class="form-check"><input class="form-check-input" type="checkbox" name="capacidades[]" value="API REST" id="cap13"><label class="form-check-label fw-bold text-primary" for="cap13">API REST</label></div>
                                </div>
                            </div>

                        </div>
                    </div>

                </div>
                <div class="modal-footer border-0 p-4 bg-light rounded-bottom-4">
                    <button type="button" class="btn btn-light fw-bold px-4" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary rounded-pill px-5 fw-bold shadow-sm" id="btn-submit-org">
                        <i class="bi bi-cloud-check-fill me-2"></i>Desplegar Tenant y Enviar Accesos
                    </button>
                </div>
            </div>
        </form>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
    // Toggle Instituciones
    document.getElementById('selectReportaInstitucion').addEventListener('change', function() {
        if(this.value === 'Sí') {
            document.getElementById('cajaInstituciones').classList.remove('d-none');
        } else {
            document.getElementById('cajaInstituciones').classList.add('d-none');
        }
    });

    document.getElementById('form-alta-organizacion').addEventListener('submit', function(e) {
        e.preventDefault();
        const fd = new FormData(this);
        const btn = document.getElementById('btn-submit-org');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Registrando...';

        fetch('../api/alta_organizacion_api.pl', {
            method: 'POST',
            body: fd
        })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                Swal.fire({
                    icon: 'success',
                    title: '¡Organización Creada!',
                    text: 'El dueño ya puede iniciar sesión en OSPulso y configurar sus sucursales.',
                    confirmButtonColor: '#18D1E6'
                }).then(() => location.reload());
            } else {
                Swal.fire('Error', data.message || 'Error desconocido.', 'error');
                btn.disabled = false;
                btn.innerHTML = 'Registrar Organización y Enviar Accesos';
            }
        })
        .catch(err => {
            console.error(err);
            Swal.fire('Error', 'Falla en la red al registrar la organización.', 'error');
            btn.disabled = false;
            btn.innerHTML = 'Registrar Organización y Enviar Accesos';
        });
    });
</script>
</body>
</html>
HTML

render_bottom_nav('crm_ventas');
1;
