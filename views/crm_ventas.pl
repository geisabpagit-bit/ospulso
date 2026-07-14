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
my $id_usuario = $sd->{id_medico}; # ID del usuario activo (Ejecutivo de ventas)

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
my @orgs_activas = ();
my @orgs_inactivas = ();

if ($regs_negocios) {
    foreach my $r (@$regs_negocios) {
        next if @$r < 14;
        # r[0]: ID, r[1]: NOMBRE, r[2]: ID_MATRIZ, r[10]: RFC, r[13]: ID_VENDEDOR
        # Organizaciones raíz (ID_MATRIZ=0)
        if ($r->[2] eq '0' && ($r->[13] eq $id_usuario || $role eq 'Administrador Global')) {
            my $org = { 
                id => $r->[0], 
                nombre => $r->[1], 
                rfc => $r->[10],
                fecha => $r->[4] || 'N/A',
                fecha_fin => $r->[5] || 'N/A',
                activo => $r->[3]
            };
            if ($r->[3] eq '1') {
                push @orgs_activas, $org;
            } else {
                push @orgs_inactivas, $org;
            }
        }
    }
}

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'crm_ventas');
print <<HTML;
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-briefcase-fill me-2"></i>CRM Ventas Corporativo</h2>
                    <p class="text-white-50 small mb-0 mt-1">Gestión de Nuevas Organizaciones y Licencias</p>
                </div>
                <div>
                    <button type="button" class="btn btn-blue-deep rounded-pill px-4 fw-bold shadow-sm" onclick="mostrarFormularioSaaS()">
                        <i class="bi bi-plus-circle me-2"></i><span>Registrar Organización</span>
                    </button>
                </div>
            </div>
        </header>

        <!-- CONTAINER -->
        <div class="container-fluid px-4 pb-5">
            <div class="row g-4" id="contenedorTarjetasPrincipales">
                
                <div class="col-12">
                    <!-- Pestañas de Navegación -->
                    <ul class="nav nav-pills mb-4 gap-2" id="orgTabs" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link btn btn-blue-deep active rounded-pill px-4 fw-bold shadow-sm text-white" style="background-color: var(--md-blue-deep); border: none;" id="activas-tab" data-bs-toggle="pill" data-bs-target="#tab-activas" type="button" role="tab" aria-controls="tab-activas" aria-selected="true">
                                <i class="bi bi-building-check me-2"></i>Organizaciones Activas
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link btn btn-light rounded-pill px-4 fw-bold shadow-sm position-relative text-dark" id="inactivas-tab" data-bs-toggle="pill" data-bs-target="#tab-inactivas" type="button" role="tab" aria-controls="tab-inactivas" aria-selected="false" style="border: 1px solid #dee2e6;">
                                <i class="bi bi-building-x me-2"></i>Inactivas / Papelera
HTML
if (@orgs_inactivas) {
    my $count = scalar(@orgs_inactivas);
    print qq|                        <span class="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-danger" style="z-index:10;">$count</span>\n|;
}
print <<HTML;
                            </button>
                        </li>
                    </ul>

                    <div class="tab-content" id="orgTabsContent">
                        <!-- PANEL: ACTIVAS -->
                        <div class="tab-pane fade show active" id="tab-activas" role="tabpanel" aria-labelledby="activas-tab">
                            <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                                <div class="card-body p-4">
                                    <div class="table-responsive">
                                        <table class="table table-hover align-middle mb-0" id="tablaOrganizaciones">
                                            <thead class="table-light">
                                                <tr>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase">Clínica / Organización</th>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase">Inicio Suscripción</th>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase">Fin Suscripción</th>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase">Activo</th>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase text-center">Acciones</th>
                                                </tr>
                                            </thead>
                                            <tbody>
HTML

if (@orgs_activas) {
    foreach my $org (@orgs_activas) {
        my $badge_activo = '<span class="badge bg-success rounded-pill px-3 py-2"><i class="bi bi-check-circle me-1"></i>Activo</span>';
        my $rfc_text = $$org{rfc} ? $$org{rfc} : 'Sin RFC';

        print <<HTML;
                                                <tr>
                                                    <td>
                                                        <div class="d-flex align-items-center">
                                                            <div class="bg-primary bg-opacity-10 text-primary rounded-circle d-flex justify-content-center align-items-center fw-bold me-3" style="width: 40px; height: 40px;">
                                                                <i class="bi bi-building"></i>
                                                            </div>
                                                            <div>
                                                                <span class="fw-bold text-dark d-block">$$org{nombre}</span>
                                                                <span class="text-muted small">RFC: $rfc_text</span>
                                                            </div>
                                                        </div>
                                                    </td>
                                                    <td class="text-muted small fw-bold">$$org{fecha}</td>
                                                    <td class="text-muted small fw-bold">$$org{fecha_fin}</td>
                                                    <td>$badge_activo</td>
                                                    <td class="text-center">
                                                        <button class="btn btn-sm btn-light text-primary rounded-pill me-1" onclick="editarOrganizacion('$$org{id}')" title="Editar"><i class="bi bi-pencil"></i></button>
                                                        <button class="btn btn-sm btn-light text-danger rounded-pill" onclick="borrarOrganizacion('$$org{id}')" title="Suspender"><i class="bi bi-trash"></i></button>
                                                    </td>
                                                </tr>
HTML
    }
} else {
    print <<HTML;
                                                <tr>
                                                    <td colspan="5" class="text-center py-5 text-muted">
                                                        <i class="bi bi-buildings display-4 d-block mb-3 text-black-50 opacity-50"></i>
                                                        <p class="mb-0 fw-bold fs-5">Sin organizaciones activas.</p>
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

                        <!-- PANEL: INACTIVAS -->
                        <div class="tab-pane fade" id="tab-inactivas" role="tabpanel" aria-labelledby="inactivas-tab">
                            <div class="card card-medentia-aura border-0 shadow-sm rounded-4">
                                <div class="card-body p-4">
                                    <div class="table-responsive">
                                        <table class="table table-hover align-middle mb-0" id="tablaOrganizacionesInactivas">
                                            <thead class="table-light">
                                                <tr>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase">Clínica / Organización</th>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase">Inicio Suscripción</th>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase">Fin Suscripción</th>
                                                    <th class="small text-muted fw-bold border-0 text-uppercase text-center">Acciones</th>
                                                </tr>
                                            </thead>
                                            <tbody>
HTML

if (@orgs_inactivas) {
    foreach my $org (@orgs_inactivas) {
        my $rfc_text = $$org{rfc} ? $$org{rfc} : 'Sin RFC';

        print <<HTML;
                                                <tr>
                                                    <td>
                                                        <div class="d-flex align-items-center opacity-75">
                                                            <div class="bg-secondary bg-opacity-10 text-secondary rounded-circle d-flex justify-content-center align-items-center fw-bold me-3" style="width: 40px; height: 40px;">
                                                                <i class="bi bi-building-x"></i>
                                                            </div>
                                                            <div>
                                                                <span class="fw-bold text-muted d-block">$$org{nombre}</span>
                                                                <span class="text-muted small">RFC: $rfc_text</span>
                                                            </div>
                                                        </div>
                                                    </td>
                                                    <td class="text-muted small fw-bold">$$org{fecha}</td>
                                                    <td class="text-muted small fw-bold">$$org{fecha_fin}</td>
                                                    <td class="text-center">
                                                        <button class="btn btn-sm btn-light text-success rounded-pill me-1" onclick="reactivarOrganizacion('$$org{id}')" title="Reactivar"><i class="bi bi-arrow-counterclockwise"></i></button>
                                                        <button class="btn btn-sm btn-light text-danger rounded-pill" onclick="eliminarDefinitivoOrganizacion('$$org{id}')" title="Eliminar Permanentemente"><i class="bi bi-trash-fill"></i></button>
                                                    </td>
                                                </tr>
HTML
    }
} else {
    print <<HTML;
                                                <tr>
                                                    <td colspan="4" class="text-center py-5 text-muted">
                                                        <i class="bi bi-trash3 display-4 d-block mb-3 text-black-50 opacity-50"></i>
                                                        <p class="mb-0 fw-bold fs-5">La papelera está vacía.</p>
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
            </div> <!-- Fin row g-4 contenedorTarjetasPrincipales -->

            <!-- CONTENEDOR FORMULARIO (Oculto por defecto) -->
            <div class="row d-none" id="contenedorFormularioSaaS">
                <div class="col-12">
                    <form id="form-alta-organizacion" class="w-100">
                        <input type="hidden" name="action" id="action_org" value="create">
                        <input type="hidden" name="id_org" id="id_org_edit" value="">
                        <div class="card border-0 shadow-sm rounded-4 mb-4 modal-diamond">
                            <div class="card-header border-0 text-white py-3 px-4 rounded-top-4 d-flex justify-content-between align-items-center" id="formHeader" style="background-color: var(--md-blue-deep) !important;">
                                <h4 class="fw-black mb-0" id="tituloSaaS"><i class="bi bi-building-add me-2"></i>Configurador SaaS - Nueva Organización</h4>
                                <button type="button" class="btn btn-sm btn-light rounded-pill fw-bold shadow-sm px-3" onclick="ocultarFormularioSaaS()">
                                    <i class="bi bi-arrow-left me-1"></i>Volver
                                </button>
                            </div>
                            <div class="card-body p-4 bg-light form-sdm-container">
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
                            <input type="email" class="form-control form-control-sm shadow-sm" name="correo_admin" required placeholder="admin\@clinica.com" autocomplete="username">
                        </div>
                        <div class="col-md-4">
                            <label class="form-label small fw-bold">Contraseña Inicial</label>
                            <input type="password" class="form-control form-control-sm shadow-sm" id="input_clave_admin" name="clave_admin" required placeholder="••••••••" autocomplete="new-password">
                            <small class="text-muted d-none" id="hint_clave_admin" style="font-size: 0.7rem;">Dejar en blanco para mantener la actual.</small>
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
                                <button type="submit" class="btn btn-blue-deep rounded-pill px-5 fw-bold shadow-sm" id="btn-submit-org">
                                    <i class="bi bi-cloud-check-fill me-2"></i><span id="txt-submit-org">Desplegar Tenant y Enviar Accesos</span>
                                </button>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div> <!-- Fin container-fluid -->
HTML

utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
<!-- Scripts y Librerías de DataTables -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
    var dtOrganizaciones;
    var dtOrganizacionesInactivas;
    \$(document).ready(function() {
        dtOrganizaciones = \$('#tablaOrganizaciones').DataTable({
            language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
            dom: '<"p-3 d-flex justify-content-end align-items-center"f>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
            ordering: true,
            order: [[1, 'desc']], // Por fecha inicio descendente
            paging: true
        });

        dtOrganizacionesInactivas = \$('#tablaOrganizacionesInactivas').DataTable({
            language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
            dom: '<"p-3 d-flex justify-content-end align-items-center"f>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
            ordering: true,
            order: [[1, 'desc']], // Por fecha inicio descendente
            paging: true
        });

        // Tabs styling
        const tabActivos = document.getElementById('activas-tab');
        const tabInactivos = document.getElementById('inactivas-tab');

        if(tabActivos && tabInactivos) {
            tabActivos.addEventListener('shown.bs.tab', function (event) {
                tabActivos.style.backgroundColor = 'var(--md-blue-deep)';
                tabActivos.style.color = '#fff';
                tabActivos.style.border = 'none';

                tabInactivos.style.backgroundColor = 'transparent';
                tabInactivos.style.color = '#212529';
                tabInactivos.style.border = '1px solid #dee2e6';
            });
            tabInactivos.addEventListener('shown.bs.tab', function (event) {
                tabInactivos.style.backgroundColor = 'var(--md-blue-deep)';
                tabInactivos.style.color = '#fff';
                tabInactivos.style.border = 'none';

                tabActivos.style.backgroundColor = 'transparent';
                tabActivos.style.color = '#212529';
                tabActivos.style.border = '1px solid #dee2e6';
            });
        }
    });

    window.mostrarFormularioSaaS = function() {
        // Reset form for create
        document.getElementById('form-alta-organizacion').reset();
        document.getElementById('action_org').value = 'create';
        document.getElementById('id_org_edit').value = '';
        document.getElementById('tituloSaaS').innerHTML = '<i class="bi bi-building-add me-2"></i>Configurador SaaS - Nueva Organización';
        document.getElementById('txt-submit-org').innerText = 'Desplegar Tenant y Enviar Accesos';
        
        document.getElementById('input_clave_admin').required = true;
        document.getElementById('hint_clave_admin').classList.add('d-none');
        document.getElementById('cajaInstituciones').classList.add('d-none');
        
        document.getElementById('contenedorTarjetasPrincipales').classList.add('d-none');
        document.getElementById('contenedorFormularioSaaS').classList.remove('d-none');
    };

    window.ocultarFormularioSaaS = function() {
        document.getElementById('contenedorFormularioSaaS').classList.add('d-none');
        document.getElementById('contenedorTarjetasPrincipales').classList.remove('d-none');
    };

    window.editarOrganizacion = function(id) {
        Swal.fire({ title: 'Cargando datos...', allowOutsideClick: false, didOpen: () => { Swal.showLoading(); } });
        
        const fd = new FormData();
        fd.append('action', 'read');
        fd.append('id_org', id);
        
        fetch('../api/crud_organizaciones_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(r => r.json())
        .then(data => {
            Swal.close();
            if(data.status === 'success') {
                const d = data.data;
                document.getElementById('form-alta-organizacion').reset();
                document.getElementById('action_org').value = 'update';
                document.getElementById('id_org_edit').value = id;
                document.getElementById('tituloSaaS').innerHTML = '<i class="bi bi-building-gear me-2"></i>Editar Organización';
                document.getElementById('txt-submit-org').innerText = 'Guardar Cambios';
                
                document.getElementById('input_clave_admin').required = false;
                document.getElementById('hint_clave_admin').classList.remove('d-none');
                
                // Set fields
                document.querySelector('input[name="nombre_org"]').value = d.nombre_org || '';
                document.querySelector('input[name="rfc_org"]').value = d.rfc_org || '';
                document.querySelector('select[name="naturaleza_juridica"]').value = d.naturaleza_juridica || 'Privado';
                document.querySelector('select[name="tipo_organizacion"]').value = d.tipo_organizacion || 'Clínica';
                document.querySelector('select[name="reporta_institucion"]').value = d.reporta_institucion || 'No';
                
                document.querySelector('input[name="nombre_admin"]').value = d.nombre_admin || '';
                document.querySelector('input[name="correo_admin"]').value = d.correo_admin || '';
                
                // Instituciones box
                if(d.reporta_institucion === 'Sí') {
                    document.getElementById('cajaInstituciones').classList.remove('d-none');
                } else {
                    document.getElementById('cajaInstituciones').classList.add('d-none');
                }
                
                // Checkboxes
                const instChecks = document.querySelectorAll('input[name="institucion[]"]');
                instChecks.forEach(chk => chk.checked = d.instituciones.includes(chk.value));
                
                const capChecks = document.querySelectorAll('input[name="capacidades[]"]');
                capChecks.forEach(chk => chk.checked = d.capacidades.includes(chk.value));
                
                document.getElementById('contenedorTarjetasPrincipales').classList.add('d-none');
                document.getElementById('contenedorFormularioSaaS').classList.remove('d-none');
            } else {
                Swal.fire('Error', data.message, 'error');
            }
        }).catch(err => { Swal.fire('Error', 'Falla de red', 'error'); });
    };

    window.borrarOrganizacion = function(id) {
        Swal.fire({
            title: '¿Suspender Organización?',
            text: "La organización pasará a estado inactivo (Soft Delete).",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            confirmButtonText: 'Sí, suspender',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('action', 'remove');
                fd.append('id_org', id);
                
                fetch('../api/crud_organizaciones_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
                .then(r => r.json())
                .then(data => {
                    if(data.status === 'success') {
                        Swal.fire('Suspendida', 'La organización ha sido desactivada.', 'success')
                        .then(() => location.reload());
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                }).catch(err => { Swal.fire('Error', 'Falla de red', 'error'); });
            }
        });
    };

    window.reactivarOrganizacion = function(id) {
        Swal.fire({
            title: '¿Reactivar Organización?',
            text: "La organización volverá a estar activa.",
            icon: 'question',
            showCancelButton: true,
            confirmButtonColor: '#28a745',
            confirmButtonText: 'Sí, reactivar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('action', 'reactivate');
                fd.append('id_org', id);
                
                fetch('../api/crud_organizaciones_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
                .then(r => r.json())
                .then(data => {
                    if(data.status === 'success') {
                        Swal.fire('Reactivada', 'La organización ha sido reactivada.', 'success')
                        .then(() => location.reload());
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                }).catch(err => { Swal.fire('Error', 'Falla de red', 'error'); });
            }
        });
    };

    window.eliminarDefinitivoOrganizacion = function(id) {
        Swal.fire({
            title: '¿Eliminar Definitivamente?',
            text: "Esta acción no se puede deshacer y borrará la organización por completo.",
            icon: 'error',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                const fd = new FormData();
                fd.append('action', 'delete_permanent');
                fd.append('id_org', id);
                
                fetch('../api/crud_organizaciones_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
                .then(r => r.json())
                .then(data => {
                    if(data.status === 'success') {
                        Swal.fire('Eliminada', 'La organización ha sido eliminada permanentemente.', 'success')
                        .then(() => location.reload());
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                }).catch(err => { Swal.fire('Error', 'Falla de red', 'error'); });
            }
        });
    };

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

        fetch('../api/crud_organizaciones_api.pl', {
            method: 'POST',
            body: fd,
            credentials: 'same-origin'
        })
        .then(res => res.json())
        .then(data => {
            if (data.status === 'success') {
                const action = document.getElementById('action_org').value;
                Swal.fire({
                    icon: 'success',
                    title: action === 'create' ? '¡Organización Creada!' : '¡Cambios Guardados!',
                    text: action === 'create' ? 'El dueño ya puede iniciar sesión en OSPulso y configurar sus sucursales.' : 'Los datos se actualizaron correctamente.',
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
HTML

utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
</body>
</html>
HTML

render_bottom_nav('crm_ventas');
1;
