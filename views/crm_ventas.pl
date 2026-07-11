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
            <div class="row g-4" id="contenedorTarjetasPrincipales">
                
                <!-- CARD: CREAR ORGANIZACION -->
                <div class="col-12 col-xl-4">
                    <div class="card card-medentia-aura border-0 h-100 shadow-sm">
                        <div class="card-body p-4 d-flex flex-column align-items-center text-center">
                            <div class="kpi-icon-box bg-primary text-white shadow-sm mb-3" style="width: 70px; height: 70px; border-radius: 20px; display: flex; align-items: center; justify-content: center; font-size: 2rem;">
                                <i class="bi bi-hospital"></i>
                            </div>
                            <h4 class="fw-bold text-dark mb-2">Venta de Licencia</h4>
                            <p class="text-muted small mb-4">Registra una nueva Organización o Cadena de Clínicas en el sistema (Crea el entorno y el usuario dueño).</p>
                            
                            <button type="button" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm w-100 mt-auto" onclick="mostrarFormularioSaaS()">
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

            </div> <!-- Fin row g-4 contenedorTarjetasPrincipales -->

            <!-- CONTENEDOR FORMULARIO (Oculto por defecto) -->
            <div class="row d-none" id="contenedorFormularioSaaS">
                <div class="col-12">
                    <form id="form-alta-organizacion" class="w-100">
                        <div class="card border-0 shadow-sm rounded-4 mb-4">
                            <div class="card-header border-0 bg-primary bg-gradient text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center">
                                <h4 class="fw-black mb-0"><i class="bi bi-building-add me-2"></i>Configurador SaaS - Nueva Organización</h4>
                                <button type="button" class="btn btn-sm btn-light rounded-pill fw-bold shadow-sm px-3" onclick="ocultarFormularioSaaS()">
                                    <i class="bi bi-arrow-left me-1"></i>Volver
                                </button>
                            </div>
                            <div class="card-body p-4 bg-light">
                                <div class="row g-3">
                        <!-- Entidad -->
                        <div class="col-12">
                            <h6 class="fw-bold text-primary mb-2 border-bottom pb-2"><i class="bi bi-building me-2"></i>Entidad y Administrador</h6>
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small fw-bold">Nombre Comercial</label>
                            <input type="text" class="form-control form-control-sm shadow-sm" name="nombre_org" required placeholder="Clínicas Salud Total">
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small fw-bold">Naturaleza Jurídica</label>
                            <select class="form-select form-select-sm shadow-sm" name="naturaleza_juridica" required>
                                <option value="Privado">Privado</option>
                                <option value="Público">Público</option>
                                <option value="Mixto">Mixto</option>
                            </select>
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small fw-bold">RFC (Opcional)</label>
                            <input type="text" class="form-control form-control-sm shadow-sm" name="rfc_org" placeholder="ABC123456T89">
                        </div>
                        
                        <!-- Dueño -->
                        <div class="col-md-4">
                            <label class="form-label small fw-bold">Nombre Administrador</label>
                            <input type="text" class="form-control form-control-sm shadow-sm" name="nombre_admin" required placeholder="Ej: Dr. Roberto Gómez">
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small fw-bold">Correo Electrónico (Login)</label>
                            <input type="email" class="form-control form-control-sm shadow-sm" name="correo_admin" required placeholder="admin\@clinica.com">
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small fw-bold">Contraseña Inicial</label>
                            <input type="password" class="form-control form-control-sm shadow-sm" name="clave_admin" required placeholder="••••••••">
                        </div>

                        <!-- C. Operación -->
                        <div class="col-12 mt-4">
                            <h6 class="fw-bold text-primary mb-2 border-bottom pb-2"><i class="bi bi-diagram-3 me-2"></i>Operación y Reportes</h6>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small fw-bold">Tipo de Organización</label>
                            <select class="form-select form-select-sm shadow-sm" name="tipo_organizacion" required>
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
                            <label class="form-label small fw-bold">¿Reporta a Institución Pública?</label>
                            <select class="form-select form-select-sm shadow-sm" id="selectReportaInstitucion" name="reporta_institucion" required>
                                <option value="No" selected>No</option>
                                <option value="Sí">Sí</option>
                            </select>
                        </div>
                        <div class="col-12 d-none" id="cajaInstituciones">
                            <div class="bg-white p-3 border rounded shadow-sm">
                                <label class="form-label small fw-bold text-muted mb-2">Seleccione Institución(es)</label>
                                <div class="d-flex flex-wrap gap-3">
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="SIS" id="inst1"><label class="form-check-label small" for="inst1">SIS</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="IMSS" id="inst2"><label class="form-check-label small" for="inst2">IMSS</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="ISSSTE" id="inst3"><label class="form-check-label small" for="inst3">ISSSTE</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="IMSS Bienestar" id="inst4"><label class="form-check-label small" for="inst4">IMSS Bienestar</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="Secretaría Estatal" id="inst5"><label class="form-check-label small" for="inst5">Secretaría Estatal</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="PEMEX" id="inst6"><label class="form-check-label small" for="inst6">PEMEX</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="SEDENA" id="inst7"><label class="form-check-label small" for="inst7">SEDENA</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="SEMAR" id="inst8"><label class="form-check-label small" for="inst8">SEMAR</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="Universidad" id="inst9"><label class="form-check-label small" for="inst9">Universidad</label></div>
                                    <div class="form-check m-0"><input class="form-check-input" type="checkbox" name="institucion[]" value="Otro" id="inst10"><label class="form-check-label small" for="inst10">Otro</label></div>
                                </div>
                            </div>
                        </div>

                        <!-- D. Capacidades -->
                        <div class="col-12 mt-4">
                            <h6 class="fw-bold text-primary mb-2 border-bottom pb-2"><i class="bi bi-box-seam me-2"></i>Capacidades SaaS Requeridas</h6>
                            <div class="row g-2 bg-white p-3 border rounded shadow-sm m-0">
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Expediente Clínico" id="cap1" checked><label class="form-check-label small" for="cap1">Expediente Clínico</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Agenda" id="cap2" checked><label class="form-check-label small" for="cap2">Agenda</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Imagenología" id="cap3"><label class="form-check-label small" for="cap3">Imagenología</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Inventario" id="cap4"><label class="form-check-label small" for="cap4">Inventario</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Facturación" id="cap5"><label class="form-check-label small" for="cap5">Facturación</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Telemedicina" id="cap6"><label class="form-check-label small" for="cap6">Telemedicina</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="CRM" id="cap7"><label class="form-check-label small" for="cap7">CRM</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Interoperabilidad SIS" id="cap8"><label class="form-check-label small text-primary fw-bold" for="cap8">Interop. SIS</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Interoperabilidad FHIR" id="cap9"><label class="form-check-label small text-primary fw-bold" for="cap9">Interop. FHIR</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="HL7" id="cap10"><label class="form-check-label small text-primary fw-bold" for="cap10">HL7</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="DICOM" id="cap11"><label class="form-check-label small text-primary fw-bold" for="cap11">DICOM</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="Exportación CSV" id="cap12"><label class="form-check-label small" for="cap12">Exportación CSV</label></div></div>
                                <div class="col-sm-4 col-6"><div class="form-check m-0"><input class="form-check-input" type="checkbox" name="capacidades[]" value="API REST" id="cap13"><label class="form-check-label small text-primary fw-bold" for="cap13">API REST</label></div></div>
                            </div>
                        </div>
                    </div>
                                </div>
                            </div>
                            <div class="card-footer border-0 p-4 bg-light rounded-bottom-4 text-end">
                                <button type="button" class="btn btn-light fw-bold px-4 me-2" onclick="ocultarFormularioSaaS()">Cancelar</button>
                                <button type="submit" class="btn btn-primary rounded-pill px-5 fw-bold shadow-sm" id="btn-submit-org">
                                    <i class="bi bi-cloud-check-fill me-2"></i>Desplegar Tenant y Enviar Accesos
                                </button>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div> <!-- Fin container-fluid -->
    </main>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
    function mostrarFormularioSaaS() {
        document.getElementById('contenedorTarjetasPrincipales').classList.add('d-none');
        document.getElementById('contenedorFormularioSaaS').classList.remove('d-none');
    }

    function ocultarFormularioSaaS() {
        document.getElementById('contenedorFormularioSaaS').classList.add('d-none');
        document.getElementById('contenedorTarjetasPrincipales').classList.remove('d-none');
    }

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
