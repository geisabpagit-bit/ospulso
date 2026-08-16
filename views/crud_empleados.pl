#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use File::Spec;
use FindBin;
use JSON qw(encode_json decode_json);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');

my $sd = check_session();
my $q  = $sd->{q};
my $usuario   = $sd->{usuario};
my $role      = $sd->{role};
my $id_medico = $sd->{id_medico} || '';
my $id_empresa = $sd->{id_empresa} || '';

binmode STDOUT, ":utf8";

if ($role !~ /Recepcionista|Administrador/i) {
    print $q->redirect('inicial.pl');
    exit;
}

my $clues = $q->param('clues') || '';
my $sufijo = $clues ? "_${clues}" : "";

my $opts_mun = "";
if (open my $fh, '<:encoding(UTF-8)', "$FindBin::Bin/../dat/municipios${sufijo}.dat") {
    my $header = <$fh>;
    while(<$fh>) {
        chomp;
        my @f = split('!');
        if (defined $f[0] && defined $f[1]) {
            $opts_mun .= qq|<option value="$f[0]">$f[1]</option>\n|;
        }
    }
    close $fh;
}

my $opts_dep = "";
if (open my $fh, '<:encoding(UTF-8)', "$FindBin::Bin/../dat/dependencia${sufijo}.dat") {
    my $header = <$fh>;
    while(<$fh>) {
        chomp;
        my @f = split('!');
        if (defined $f[0] && defined $f[1]) {
            $opts_dep .= qq|<option value="$f[0]">$f[1]</option>\n|;
        }
    }
    close $fh;
}

render_header(
    titulo => 'Gestión de Empleados', 
    role => $role, 
    usuario => $usuario,
    hide_search => 1
);

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    id_empresa => $id_empresa,
    pagina_actual => 'crud_empleados'
);

print <<"HTML";
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="../css/sdm_mobile_standards.css">

<main class="container-fluid pt-3 px-3 pb-5">
    <div class="d-flex flex-column flex-md-row justify-content-between align-items-md-center mb-4 gap-3">
        <h5 class="fw-bold m-0" style="color: var(--md-blue-deep, #0A2A66);">Directorio de Empleados y Beneficiarios</h5>
        <button class="btn btn-primary shadow-sm" onclick="abrirModalAlta()"><i class="bi bi-person-plus"></i> Nuevo Registro</button>
    </div>
    
    <div class="card shadow-sm border-0 rounded-4">
        <div class="card-body">
            <div class="table-responsive">
                <table id="dtEmpleados" class="table table-hover align-middle w-100">
                    <thead class="table-light">
                        <tr>
                            <th>Núm. Empleado</th>
                            <th>Nombre Completo</th>
                            <th>Relación</th>
                            <th>Teléfono</th>
                            <th>Estatus</th>
                            <th>Opciones</th>
                        </tr>
                    </thead>
                    <tbody></tbody>
                </table>
            </div>
        </div>
    </div>
</main>
HTML

utils::sub_sidebar::render_sidebar_footer();

print <<"HTML";
<!-- Modal -->
<div class="modal fade" id="modalEmpleado" tabindex="-1">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content rounded-4 border-0 shadow">
            <form id="frmEmpleado" onsubmit="guardarEmpleado(event)">
                <div class="modal-header border-bottom">
                    <h5 class="modal-title fw-bold" id="modalTitle" style="color: var(--md-blue-deep, #0A2A66);">Nuevo Registro</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body row g-3">
                    <input type="hidden" id="iptAction" name="action" value="crear">
                    <input type="hidden" id="iptOriginalNum" name="original_num" value="">
                    <input type="hidden" id="iptOriginalName" name="original_name" value="">
                    
                    <div class="col-md-4">
                        <div class="form-floating diamond-input-armor">
                            <input type="number" class="form-control" id="iptNumEmpleado" name="num_empleado" placeholder="Núm. Empleado" required onblur="validarNumEmpleado()">
                            <label for="iptNumEmpleado" class="fw-bold text-muted">Núm. Empleado</label>
                        </div>
                        <div id="numFeedback" class="small mt-1 fw-bold"></div>
                    </div>
                    <div class="col-md-8">
                        <div class="form-floating diamond-input-armor">
                            <input type="text" class="form-control" id="iptNombre" name="nombre" placeholder="Nombre Completo" required>
                            <label for="iptNombre" class="fw-bold text-muted">Nombre Completo</label>
                        </div>
                    </div>
                    
                    <div class="col-md-4">
                        <div class="form-floating diamond-input-armor">
                            <select class="form-select" id="iptRelacion" name="relacion" required>
                                <option value="Empleado">Empleado (Titular)</option>
                                <option value="Beneficiario">Beneficiario</option>
                            </select>
                            <label for="iptRelacion" class="fw-bold text-muted">Relación</label>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="form-floating diamond-input-armor">
                            <select class="form-select" id="iptMunicipio" name="municipio" required>
                                $opts_mun
                            </select>
                            <label for="iptMunicipio" class="fw-bold text-muted">Municipio</label>
                        </div>
                    </div>
                    <div class="col-md-4">
                        <div class="form-floating diamond-input-armor">
                            <select class="form-select" id="iptDependencia" name="dependencia" required>
                                <option value="">Selecciona dependencia...</option>
                                $opts_dep
                            </select>
                            <label for="iptDependencia" class="fw-bold text-muted">Dependencia</label>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <div class="form-floating diamond-input-armor">
                            <input type="text" class="form-control" id="iptTelefono" name="telefono" placeholder="Teléfono">
                            <label for="iptTelefono" class="fw-bold text-muted">Teléfono</label>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="form-floating diamond-input-armor">
                            <select class="form-select" id="iptEstatus" name="estatus">
                                <option value="Activo">Activo</option>
                                <option value="Baja">Baja</option>
                            </select>
                            <label for="iptEstatus" class="fw-bold text-muted">Estatus</label>
                        </div>
                    </div>
                </div>
                <div class="modal-footer border-top bg-light rounded-bottom-4">
                    <button type="button" class="btn btn-secondary rounded-pill" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary rounded-pill px-4" id="btnGuardar">Guardar Registro</button>
                </div>
            </form>
        </div>
    </div>
</div>

<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script>
    const CLUES = "$clues";
    let tabla;
    let validacionExitosa = true;

    \$(document).ready(function() {
        tabla = \$('#dtEmpleados').DataTable({
            ajax: '../api/crud_empleados_api.pl?action=list&clues=' + CLUES,
            language: { url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
            pageLength: 15,
            lengthChange: false
        });
    });

    function abrirModalAlta() {
        \$('#frmEmpleado')[0].reset();
        \$('#iptAction').val('crear');
        \$('#iptOriginalNum').val('');
        \$('#iptOriginalName').val('');
        \$('#modalTitle').text('Nuevo Empleado / Beneficiario');
        \$('#iptNumEmpleado').prop('readonly', false);
        \$('#iptRelacion').prop('disabled', false);
        \$('#numFeedback').html('');
        validacionExitosa = false;
        \$('#modalEmpleado').modal('show');
    }
    
    function abrirModalEditar(num, nombre, relacion, municipio, dependencia, telefono, estatus) {
        \$('#frmEmpleado')[0].reset();
        \$('#iptAction').val('editar');
        \$('#iptOriginalNum').val(num);
        \$('#iptOriginalName').val(nombre);
        \$('#modalTitle').text('Editar Registro');
        
        \$('#iptNumEmpleado').val(num).prop('readonly', true);
        \$('#iptNombre').val(nombre);
        \$('#iptRelacion').val(relacion).prop('disabled', true);
        \$('#iptMunicipio').val(municipio);
        \$('#iptDependencia').val(dependencia);
        \$('#iptTelefono').val(telefono);
        \$('#iptEstatus').val(estatus);
        
        \$('#numFeedback').html('');
        validacionExitosa = true; // Al editar es valido
        \$('#modalEmpleado').modal('show');
    }
    
    async function validarNumEmpleado() {
        if(\$('#iptAction').val() === 'editar') return;
        const num = \$('#iptNumEmpleado').val().trim();
        if(!num) { validacionExitosa = false; return; }
        
        const req = await fetch('../api/crud_empleados_api.pl', {
            method:'POST', 
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: new URLSearchParams({action: 'check_num', clues: CLUES, num_empleado: num})
        });
        const res = await req.json();
        
        if (res.exists) {
            \$('#numFeedback').html('<span class="text-warning"><i class="bi bi-info-circle"></i> Este número ya tiene Titular. Se registrará como Beneficiario.</span>');
            \$('#iptRelacion').val('Beneficiario').prop('disabled', true);
            validacionExitosa = true; 
        } else {
            \$('#numFeedback').html('<span class="text-success"><i class="bi bi-check-circle"></i> Número libre. Alta de Titular.</span>');
            \$('#iptRelacion').val('Empleado').prop('disabled', false);
            validacionExitosa = true;
        }
    }

    async function guardarEmpleado(e) {
        e.preventDefault();
        if(!validacionExitosa && \$('#iptAction').val() === 'crear') {
            await validarNumEmpleado();
            if(!validacionExitosa) return;
        }
        
        \$('#iptRelacion').prop('disabled', false);
        const form = new URLSearchParams(new FormData(e.target));
        form.append('clues', CLUES);
        
        \$('#btnGuardar').prop('disabled', true).html('<div class="spinner-border spinner-border-sm"></div> Guardando...');
        try {
            const req = await fetch('../api/crud_empleados_api.pl', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: form
            });
            const res = await req.json();
            if(res.ok) {
                Swal.fire('Guardado', 'El registro ha sido guardado exitosamente.', 'success');
                \$('#modalEmpleado').modal('hide');
                tabla.ajax.reload();
            } else {
                Swal.fire('Error', res.error || 'No se pudo guardar', 'error');
            }
        } catch(err) {
            Swal.fire('Error', 'Falla de conexión', 'error');
        } finally {
            \$('#btnGuardar').prop('disabled', false).html('Guardar Registro');
        }
    }
</script>
HTML

render_bottom_nav(role => $role, pagina_actual => 'crud_empleados');
print "</body></html>\n";
1;
