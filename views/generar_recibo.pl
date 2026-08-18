#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use File::Spec;
use FindBin;
use JSON qw(encode_json);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};
my $usuario   = $sd->{usuario};
my $role      = $sd->{role};
my $id_medico = $sd->{id_medico} || '';
my $id_empresa = $sd->{id_empresa} || '';

binmode STDOUT, ":utf8";

# Restringir a roles permitidos (Recepcion, Medicos, Admins)
if ($role !~ /Recepcionista|Medico|Administrador/i) {
    # print $q->redirect('inicial.pl');
    # exit;
}
unless ($sd->{session_ok}) {
    # print $q->redirect('../index.html');
    # exit;
}

# 1. Leer SaaS Capabilities
my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $config_file = File::Spec->catfile($dat_dir, 'negocios_config.dat');
my %capacidades = ();
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line);
        if ($biz_id eq $id_empresa && $key eq 'PACIENTES_ESTADO') {
            $capacidades{'PACIENTES_ESTADO'} = $val;
        }
    }
    close($cf);
}
my $has_pacientes_estado = (exists $capacidades{'PACIENTES_ESTADO'} && $capacidades{'PACIENTES_ESTADO'} eq '1') ? 1 : 0;

my $org_clues = '';
my $negocios_file = File::Spec->catfile($dat_dir, 'negocios.dat');
if (-e $negocios_file && open(my $nf, '<:utf8', $negocios_file)) {
    while (my $line = <$nf>) {
        chomp($line);
        my @f = split(/\|/, $line, -1);
        if ($f[0] eq $id_empresa) {
            $org_clues = $f[18] // '';
            last;
        }
    }
    close($nf);
}

# 2. Cargar lista de médicos de la organización para el selector obligatorio
my $archivo_usuarios = File::Spec->catfile($dat_dir, 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '!');
my @medicos = ();
foreach my $r (@$regs) {
    next unless scalar(@$r) >= 7;
    my $m_id = $r->[0];
    my $m_nom = $r->[1];
    my $rol_u = $r->[5] // '';
    my $org_u = $r->[6] // '';
    if ($rol_u eq 'Medico' || $rol_u =~ /Especialista/i) {
        push @medicos, { id => $m_id, nombre => $m_nom };
    }
}
@medicos = sort { $a->{nombre} cmp $b->{nombre} } @medicos;

# 3. Render HTML
render_header(
    titulo => 'Caja Rápida',
    role => $role,
    usuario => $usuario,
    hide_search => 1
);

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    id_empresa => $id_empresa,
    pagina_actual => 'caja_rapida'
);

my $medicos_options = "<option value=''>-- Selecciona el Médico que atiende --</option>";
foreach my $m (@medicos) {
    my $sel = ($id_medico eq $m->{id}) ? "selected" : "";
    $medicos_options .= "<option value='$m->{id}' $sel>$m->{nombre}</option>";
}

# 2.1 Comprobar catálogos custom (Médicos Legacy)
my $archivo_medicos_custom = File::Spec->catfile($dat_dir, "medicos_${org_clues}.dat");
my $archivo_espe_custom = File::Spec->catfile($dat_dir, "especialidades_${org_clues}.dat");

my $has_custom_medicos = (-e $archivo_medicos_custom && -e $archivo_espe_custom) ? 1 : 0;
my $espe_options = "<option value=''>-- Selecciona Especialidad --</option>";
my $medicos_custom_js = "{}";

if ($has_custom_medicos) {
    my $espe_regs = leer_tabla($archivo_espe_custom);
    @$espe_regs = sort { $a->[1] cmp $b->[1] } @$espe_regs;
    
    foreach my $e (@$espe_regs) {
        next unless scalar(@$e) >= 2;
        my $sel = ($e->[1] eq 'Medicina General') ? 'selected' : '';
        $espe_options .= "<option value='$e->[0]' $sel>$e->[1]</option>";
    }
    
    my $med_regs = leer_tabla($archivo_medicos_custom);
    my %med_by_espe = ();
    foreach my $m (@$med_regs) {
        next unless scalar(@$m) >= 3;
        push @{$med_by_espe{$m->[1]}}, { id => $m->[0], nombre => $m->[2] };
    }
    
    # Sort medicos within each especialidad
    foreach my $espe (keys %med_by_espe) {
        @{$med_by_espe{$espe}} = sort { $a->{nombre} cmp $b->{nombre} } @{$med_by_espe{$espe}};
    }
    
    $medicos_custom_js = encode_json(\%med_by_espe);
}

print <<"HTML";
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme@1.3.0/dist/select2-bootstrap-5-theme.min.css" />
<link rel="stylesheet" href="../css/sdm_mobile_standards.css" />
<link rel="stylesheet" href="../css/expediente_completo.css?v=$^T" />

<style>
    /* Soporte adicional para Select2 y Diamond Style */
    .select2-container--bootstrap-5 .select2-selection {
        border: 1px solid var(--md-cyan-ia, #19B7A5) !important;
        border-radius: 1rem !important;
        padding: 0.75rem 1rem !important;
        background: #F8FBFF !important;
    }
    .select2-container--bootstrap-5 .select2-selection:focus {
        border-color: #19B7A5 !important;
        background: white !important;
        box-shadow: 0 0 0 3px rgba(25, 183, 165, 0.15) !important;
    }
    /* Eliminar el borde feo del main input premium para integrarlo a select2 visual */
    .select2-container--bootstrap-5 .select2-selection--single .select2-selection__rendered {
        color: #0A2A66 !important;
        font-weight: 600 !important;
        font-size: 0.95rem !important;
        line-height: 1.5 !important;
    }
    .select2-container--bootstrap-5 .select2-selection--single {
        height: auto !important;
    }
</style>

<main class="container-fluid container-mobile-flush pt-4 px-lg-4 pb-5 animate__animated animate__fadeIn">
    <div class="row g-4 mb-4">
        <!-- Columna Izquierda: Formulario -->
        <div class="col-lg-8">
            <div class="card-medentia-aura p-4 p-md-5 h-100 border-0 shadow-sm" style="border-radius: 1.5rem;">
                <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-person-lines-fill me-2" style="color: var(--md-teal-clinical);"></i>test</h5>
                
                <form id="frmCajaRapida" onsubmit="return false;">
                    
                    <div class="row g-3">
                        <!-- 1. Paciente Privado -->
                        <div class="col-md-6">
                            <div class="mb-4 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Paciente Privado</label>
                                <select id="selPaciente" class="form-select border-0 shadow-none fw-bold" onchange="seleccionarPacientePrivado()"></select>
                            </div>
                        </div>
                        
                        <!-- Paciente Público -->
                        <div class="col-md-6">
                            <div class="mb-4 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">N&uacute;mero Empleado (Estado)</label>
                                <div class="input-group">
                                    <input type="number" id="iptNumEmpleado" class="form-control py-2 fw-bold border-0 bg-transparent shadow-none" style="border-top-right-radius:0 !important; border-bottom-right-radius:0 !important;" placeholder="Ej. 12345" onkeypress="if(event.key==='Enter') buscarEmpleadoEstado()">
                                    <button class="btn px-4 m-0" style="background: var(--md-blue-deep, #0A2A66); color: white; border-top-right-radius: 0.5rem; border-bottom-right-radius: 0.5rem; border:none;" type="button" onclick="buscarEmpleadoEstado()"><i class="bi bi-search"></i></button>
                                </div>
                            </div>
                        </div>
                        
                        <!-- Resultados de búsqueda de empleados (oculto por defecto) -->
                        <div class="col-12" id="resultadosEmpleadoContainer" style="display:none;">
                            <div id="resultadosEmpleado" class="mb-3"></div>
                        </div>

HTML

if ($has_custom_medicos) {
print <<"HTML";
                        <!-- 2. Especialidad -->
                        <div class="col-md-6">
                            <div class="mb-4 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Especialidad</label>
                                <select id="selEspecialidadCustom" class="form-select py-2 fw-bold border-0 shadow-none bg-transparent" onchange="filtrarMedicosCustom()" required>
                                    $espe_options
                                </select>
                            </div>
                        </div>
HTML
}

print <<"HTML";
                        
                        <!-- 3. Médico Tratante -->
                        <div class="col-md-6">
                            <div class="mb-4 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Médico Tratante</label>
                                <select id="selMedico" class="form-select py-2 fw-bold border-0 shadow-none bg-transparent" required>
HTML

if ($has_custom_medicos) {
    print "<option value=''>-- Selec. Médico --</option>";
} else {
    print $medicos_options;
}

print <<"HTML";
                                </select>
                            </div>
                        </div>
                        
                        <!-- 4. Método de Pago -->
                        <div class="col-md-12">
                            <div class="mb-4 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Método de Pago</label>
                                <select id="selMetodoPago" class="form-select py-2 fw-bold border-0 shadow-none bg-transparent" style="max-width: 50%;">
                                    <option value="Efectivo">Efectivo</option>
                                    <option value="Tarjeta de Debito">Tarjeta de Débito</option>
                                    <option value="Tarjeta de Credito">Tarjeta de Crédito</option>
                                    <option value="Transferencia">Transferencia (SPEI)</option>
                                    <option value="Convenio / Aseguradora">Convenio / Aseguradora</option>
                                    <option value="Cortesía">Cortesía (Sin cobro)</option>
                                </select>
                            </div>
                        </div>
                        
                    </div>
                </form>
            </div>
        </div>
        
        <!-- Columna Derecha: Resumen de Cobro -->
        <div class="col-lg-4">
            <div class="card-medentia-aura p-4 p-md-5 h-100 border-0 shadow-sm d-flex flex-column" style="border-radius: 1.5rem;">
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <h5 class="fw-black m-0" style="color: var(--md-blue-deep);"><i class="bi bi-receipt-cutoff me-2" style="color: var(--md-teal-clinical);"></i>Resumen</h5>
                    <button type="button" class="btn btn-sm text-white px-3 py-1 fw-bold rounded-3 shadow-sm" style="background: var(--md-blue-deep, #0A2A66);" onclick="new bootstrap.Modal(document.getElementById('modalCargo')).show()">
                        <i class="bi bi-cart-plus me-1"></i> Agregar
                    </button>
                </div>
                
                <div id="cartContainer" class="d-flex flex-column overflow-auto mb-3 pe-2" style="height: 250px;">
                    <div class="text-center text-muted small py-4" id="cartEmpty">
                        Ningún concepto agregado
                    </div>
                </div>
                
                <hr class="border-light mt-auto">
                
                <div class="d-flex justify-content-between align-items-center text-muted small mb-3">
                    <div class="form-check form-switch m-0">
                        <input class="form-check-input" type="checkbox" id="chkIva" onchange="renderCart()">
                        <label class="form-check-label fw-bold" style="cursor: pointer;" for="chkIva">Tax (IVA 16%)</label>
                    </div>
                    <span class="fw-bold text-dark" id="taxAmountText">\$0.00</span>
                </div>
                
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <span class="fw-bold text-muted" style="letter-spacing: 1px;">TOTAL A PAGAR</span>
                    <span class="fw-black fs-3" style="color: var(--md-blue-deep);" id="cartTotalText">\$0.00</span>
                </div>
                
                <button type="button" class="btn rounded-3 py-3 fw-bold w-100 d-flex align-items-center justify-content-center gap-2 shadow-sm" style="background: var(--md-blue-deep); color: white;" onclick="mostrarReciboPrevio()">
                    <i class="bi bi-check2-circle fs-5"></i> Emitir Recibo
                </button>
            </div>
        </div>
    </div>
</main>
<!-- MODAL CARRITO UNIVERSAL -->
<div class="modal fade modal-diamond" id="modalCargo" tabindex="-1" aria-hidden="true" style="z-index: 105000 !important;">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content border-0 shadow-lg">
            <div class="modal-header" style="background: var(--md-blue-deep, #0A2A66);">
                <h5 class="modal-title plus-jakarta fw-bold text-white">
                    <i class="bi bi-cart-plus me-2" style="color: var(--md-cyan-ia, #18D1E6);"></i>Catálogo y Conceptos
                </h5>
                <button type="button" class="btn-close btn-close-white shadow-none" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body bg-light">
                <div class="row g-4">
                    <!-- Columna Izquierda: Catálogo -->
                    <div class="col-lg-7">
                        <!-- Entrada manual -->
                        <div class="card-medentia p-3 mb-3 bg-white rounded-4 border-0 shadow-sm">
                            <label class="fw-bold text-muted small mb-2 text-uppercase"><i class="bi bi-keyboard text-primary me-1"></i>Cargo Manual / Libre</label>
                            <div class="row g-2 align-items-center">
                                <div class="col-md-7">
                                    <div class="form-floating diamond-input-armor rounded-3 bg-light">
                                        <input type="text" id="manual_nombre" class="form-control border-0 bg-transparent shadow-none" placeholder="Concepto">
                                        <label for="manual_nombre" class="fw-bold text-muted">Descripción del concepto</label>
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="form-floating diamond-input-armor rounded-3 bg-light">
                                        <input type="number" id="manual_precio" class="form-control border-0 bg-transparent shadow-none" placeholder="0.00" step="0.01" min="0">
                                        <label for="manual_precio" class="fw-bold text-muted">Precio (\(\$\))</label>
                                    </div>
                                </div>
                                <div class="col-md-2">
                                    <button onclick="agregarCargoManual()" class="btn h-100 w-100 rounded-3 d-flex align-items-center justify-content-center shadow-sm" style="background: var(--md-blue-deep, #0A2A66); color: white; border: none;" title="Añadir libre">
                                        <i class="bi bi-cart-plus fs-4"></i>
                                    </button>
                                </div>
                            </div>
                        </div>

                        <!-- Buscador catálogo -->
                        <div class="position-relative mb-3 diamond-input-armor rounded-pill p-1 shadow-sm bg-white">
                            <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-3 text-primary"></i>
                            <input type="text" id="buscadorCatalogo" class="form-control form-control-lg border-0 bg-transparent shadow-none plus-jakarta" style="padding-left: 2.8rem;" placeholder="Buscar producto o servicio..." oninput="filtrarCatalogo()" onkeyup="filtrarCatalogo()">
                        </div>

                        <!-- Tabla catálogo -->
                        <div class="table-responsive rounded-4 shadow-sm bg-white" style="max-height: 350px; overflow-y: auto; border: 1px solid rgba(25,183,165,0.2);">
                            <table class="table table-hover align-middle mb-0">
                                <thead class="table-light sticky-top" style="z-index: 1;">
                                    <tr>
                                        <th class="ps-4 py-3 text-muted text-uppercase small fw-bold">Concepto en Catálogo</th>
                                        <th class="text-end py-3 text-muted text-uppercase small fw-bold">Precio</th>
                                        <th style="width: 80px;" class="py-3"></th>
                                    </tr>
                                </thead>
                                <tbody id="tablaCatalogo">
                                    <!-- AJAX rellena esto -->
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Columna Derecha: Carrito -->
                    <div class="col-lg-5">
                        <div class="card-medentia p-3 h-100 d-flex flex-column bg-white rounded-4 border-0 shadow-sm">
                            <h6 class="fw-bold plus-jakarta mb-3 text-primary text-uppercase border-bottom pb-2">
                                <i class="bi bi-basket2 me-2"></i>Carrito Actual
                            </h6>
                            <div id="listaCarrito" class="flex-grow-1 d-flex flex-column gap-2 overflow-auto mb-3" style="max-height: 320px;"></div>
                            
                            <div class="card-medentia-aura p-3 rounded-4 mt-auto">
                                <div class="d-flex justify-content-between align-items-center mb-3">
                                    <span class="text-muted fw-bold small text-uppercase">Total a Cobrar</span>
                                    <span class="fw-bold fs-2 plus-jakarta text-primary" id="carritoTotal">\$0.00</span>
                                </div>
                                <button class="btn btn-primary w-100 py-3 fw-bold rounded-pill shadow-sm plus-jakarta fs-6" id="btnProcesarCargo" onclick="bootstrap.Modal.getInstance(document.getElementById('modalCargo')).hide()">
                                    <i class="bi bi-check-circle me-2"></i>CONFIRMAR Y CERRAR
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</main>
<script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script>
<script>
    const HAS_PACIENTES_ESTADO = ${has_pacientes_estado} || 0;
    const ORG_CLUES = '$org_clues';
    const MEDICOS_CUSTOM_JSON = $medicos_custom_js;
</script>
HTML

print <<'JS';
<script>
    let catalogoMaster = [];
    let cartItems = [];
    let consecutivoId = 1;
    let pacienteSeleccionado = null;
    let cargoSeleccionadoManual = null;

    function filtrarMedicosCustom() {
        const idEspe = document.getElementById('selEspecialidadCustom').value;
        const selMedico = document.getElementById('selMedico');
        if (!selMedico) return;
        
        selMedico.innerHTML = "<option value=''>-- Selecciona Médico --</option>";
        if (idEspe && MEDICOS_CUSTOM_JSON[idEspe]) {
            const medicos = MEDICOS_CUSTOM_JSON[idEspe];
            medicos.forEach(m => {
                const opt = document.createElement('option');
                opt.value = m.id;
                opt.textContent = m.nombre;
                selMedico.appendChild(opt);
            });
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        console.log("hola");
        document.body.appendChild(document.getElementById('modalCargo'));
        initSelect2Paciente();
        cargarCatalogo();
    });

    let pacienteEstadoSeleccionado = { id: '', nombre: '' };

    function buscarEmpleadoEstado() {
        const num = $('#iptNumEmpleado').val().trim();
        if(!num) return;
        
        if (!HAS_PACIENTES_ESTADO) {
            Swal.fire({
                icon: 'warning',
                title: 'Función no disponible',
                text: 'La capacidad de Empleados Públicos/Estado no está habilitada.',
                confirmButtonText: 'Entendido'
            });
            return;
        }
        console.log("Buscando empleado con número:", num);
        
        $('#resultadosEmpleadoContainer').show();
        $('#resultadosEmpleado').html('<div class="spinner-border text-primary spinner-border-sm"></div> Buscando...');
        $.ajax({
            url: '../api/buscar_familia_empleado.pl',
            method: 'POST',
            data: { num_empleado: num, clues: ORG_CLUES },
            success: function(res) {
                console.log("Respuesta de buscar_familia_empleado.pl:", res);
                if (res.ok && res.resultados && res.resultados.length > 0) {
                    console.log("Resultados encontrados:", res.resultados.length);
                    let html = '';
                    try {
                        res.resultados.forEach((emp, i) => {
                            let isChecked = i === 0 ? 'checked' : '';
                            let nombreStr = emp.nombre ? String(emp.nombre) : '';
                            let safeNombre = nombreStr.replace(/'/g, "&apos;");
                            if(i===0) seleccionarEmpleadoEstado(emp.id, nombreStr); // Select first auto
                            
                            html += `
                            <div class="form-check border rounded-3 p-2 mb-1 bg-light cr-cart-item">
                                <input class="form-check-input ms-0 mt-1" type="radio" name="empSeleccionado" id="empSel${emp.id}_${i}" value="${emp.id}" ${isChecked} onchange="seleccionarEmpleadoEstado('${emp.id}', '${safeNombre}')">
                                <label class="form-check-label w-100 ps-2" for="empSel${emp.id}_${i}" style="cursor:pointer; font-size: 0.8rem;">
                                    <div class="fw-bold text-dark">${nombreStr}</div>
                                    <div class="text-muted" style="font-size:0.7rem;">Relación: ${emp.relacion}</div>
                                </label>
                            </div>`;
                        });
                        console.log("HTML generado:", html);
                        $('#resultadosEmpleado').html(html);
                        pacienteTipoActual = 'estado';
                        $('#selPaciente').val(null).trigger('change.select2');
                    } catch (err) {
                        console.error("Error procesando resultados:", err);
                        $('#resultadosEmpleado').html('<div class="alert alert-danger py-2 small m-0">Error procesando los resultados. Revisa la consola.</div>');
                    }
                } else {
                    $('#resultadosEmpleado').html(`<div class="alert alert-warning py-2 text-center small m-0 shadow-sm border-0">No se encontraron resultados para el número.</div>`);
                }
            },
            error: function() {
                $('#resultadosEmpleado').html('<div class="alert alert-danger py-2 small m-0">Error de conexión al buscar.</div>');
            }
        });
    }

    function seleccionarEmpleadoEstado(id, nombre) {
        pacienteEstadoSeleccionado = { id: id, nombre: nombre };
    }

    function initSelect2Paciente() {
        if ($('#selPaciente').hasClass('select2-hidden-accessible')) {
            $('#selPaciente').select2('destroy');
        }
        $('#selPaciente').select2({
            theme: 'bootstrap-5',
            placeholder: '🔍 Escribe el nombre del paciente (Privado)...',
            minimumInputLength: 2,
            ajax: {
                url: '../api/autocomplete_pacientes.pl',
                dataType: 'json',
                delay: 350,
                data: function (params) { return { term: params.term }; },
                processResults: function (data) {
                    return { results: data.map(function(item) { return { id: item.id, text: item.label }; }) };
                }
            }
        });
    }

    let pacienteTipoActual = 'privado';

    function cambiarTipoPaciente(e) {
        // Función mantenida por compatibilidad (vacía)
    }
    
    function seleccionarPacientePrivado() {
        pacienteTipoActual = 'privado';
        $('#resultadosEmpleado').html('');
        $('#resultadosEmpleadoContainer').hide();
        $('#iptNumEmpleado').val('');
        pacienteEstadoSeleccionado = { id: '', nombre: '' };
    }
    

    
    async function cargarCatalogo() {
        try {
            const req = await fetch('../api/catalogo_org_api.pl?accion=get_catalogo_org');
            const res = await req.json();
            if(res.status === 'ok') {
                catalogoMaster = [...(res.servicios || []), ...(res.productos || [])];
            } else {
                catalogoMaster = [];
            }
            filtrarCatalogo();
        } catch(e) {
            console.error("Error al cargar catálogo:", e);
        }
    }

    function formatCurrency(val) {
        return new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(val);
    }

    function filtrarCatalogo() {
        const term = $('#buscadorCatalogo').val().toLowerCase();
        const tbody = document.getElementById('tablaCatalogo');
        if(!tbody) return;
        
        let filtered = catalogoMaster.filter(c => c.nombre.toLowerCase().includes(term) || (c.id && String(c.id).toLowerCase().includes(term)));
        filtered = filtered.slice(0, 30); // max 30
        
        let html = '';
        filtered.forEach(c => {
            let precio = parseFloat(c.precio) || 0;
            let claveText = c.id ? `Clave: ${c.id}` : '';
            html += `
            <tr>
                <td class="ps-3 py-2">
                    <div class="fw-bold" style="color: var(--md-blue-deep, #0A2A66); font-size: 0.8rem;">${c.nombre}</div>
                    <div class="text-muted" style="font-size: 0.7rem;">${claveText}</div>
                </td>
                <td class="text-end py-2 fw-bold" style="color: var(--md-text-secondary, #486581); font-size: 0.85rem;">
                    ${formatCurrency(precio)}
                </td>
                <td class="text-center py-2">
                    <button class="btn btn-sm btn-light border shadow-sm rounded-circle p-1" onclick="addConceptoCatalogo('${c.id}', '${c.nombre.replace(/'/g, "&apos;")}', ${precio})" style="width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; color: var(--md-blue-medical, #124A9E);">
                        <i class="bi bi-plus"></i>
                    </button>
                </td>
            </tr>`;
        });
        tbody.innerHTML = html;
    }

    function agregarCargoManual() {
        const nombre = $('#manual_nombre').val().trim();
        const precio = parseFloat($('#manual_precio').val());
        if(!nombre || isNaN(precio) || precio < 0) {
            Swal.fire('Error', 'Ingresa un concepto y un precio válido.', 'error');
            return;
        }
        cartItems.push({ id: Date.now(), nombre: nombre, precio: precio, cantidad: 1 });
        $('#manual_nombre').val('');
        $('#manual_precio').val('');
        renderCart();
    }

    function addConceptoCatalogo(id, nombre, precio) {
        let ex = cartItems.find(i => i.nombre === nombre);
        if (ex) {
            ex.cantidad++;
        } else {
            cartItems.push({ id: Date.now() + Math.random(), nombre: nombre, precio: precio, cantidad: 1 });
        }
        renderCart();
    }
    
    function removeConcepto(id) {
        cartItems = cartItems.filter(item => item.id != id);
        renderCart();
    }

    function updateCantidad(id, delta) {
        let ex = cartItems.find(i => i.id == id);
        if (ex) {
            ex.cantidad += delta;
            if (ex.cantidad < 1) ex.cantidad = 1;
            renderCart();
        }
    }
    
    function renderCart() {
        const cModal = $('#listaCarrito');
        const cMain = $('#cartContainer');
        
        if (cartItems.length === 0) {
            let emptyHtml = '<div class="text-center text-muted small py-4" id="cartEmpty"><i class="bi bi-cart-x fs-2 d-block mb-2 text-black-50"></i>No hay conceptos agregados</div>';
            cModal.html(emptyHtml);
            cMain.html(emptyHtml);
            $('#carritoTotal').text('$0.00');
            $('#cartTotalText').text('$0.00');
            return;
        }
        
        let htmlModal = '';
        let htmlMain = '';
        let total = 0;
        
        cartItems.forEach(item => {
            const sub = item.precio * item.cantidad;
            total += sub;
            
            // Modal
            htmlModal += `
                <div class="d-flex justify-content-between align-items-center p-2 rounded-3 mb-2 shadow-sm" style="background: white; border: 1px solid var(--md-gray-soft, #D9E2EC);">
                    <div class="me-2" style="flex: 1; min-width: 0;">
                        <div class="fw-bold text-truncate" style="font-size: 0.8rem; color: var(--md-blue-deep, #0A2A66);">${item.nombre}</div>
                        <div class="text-muted" style="font-size: 0.7rem;">${formatCurrency(item.precio)} c/u</div>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <div class="input-group input-group-sm" style="width: 75px;">
                            <button class="btn btn-outline-secondary px-1 py-0" type="button" onclick="updateCantidad('${item.id}', -1)">-</button>
                            <input type="text" class="form-control text-center p-0" value="${item.cantidad}" readonly style="font-size: 0.75rem;">
                            <button class="btn btn-outline-secondary px-1 py-0" type="button" onclick="updateCantidad('${item.id}', 1)">+</button>
                        </div>
                        <span class="fw-bold" style="font-size: 0.85rem; color: var(--md-blue-deep, #0A2A66); width: 60px; text-align: right;">${formatCurrency(sub)}</span>
                        <button class="btn btn-sm text-danger p-1 border-0" onclick="removeConcepto('${item.id}')"><i class="bi bi-trash"></i></button>
                    </div>
                </div>
            `;
            
            // Main view (Right column cart)
            htmlMain += `
                <div class="d-flex justify-content-between align-items-center p-2 rounded-3 mb-1 bg-white border shadow-sm" style="border-color: var(--md-gray-soft, #D9E2EC) !important; gap: 0.5rem;">
                    <div style="min-width: 0;">
                        <div class="fw-bold text-truncate" style="font-size: 0.85rem; color: var(--md-blue-deep, #0A2A66);">${item.nombre}</div>
                        <div class="text-muted" style="font-size: 0.75rem;">${item.cantidad} x ${formatCurrency(item.precio)}</div>
                    </div>
                    <div class="fw-bold text-success text-end flex-shrink-0" style="font-size: 0.9rem;">
                        ${formatCurrency(sub)}
                    </div>
                </div>
            `;
        });
        
        cModal.html(htmlModal);
        cMain.html(htmlMain);
        
        let iva = 0;
        if ($('#chkIva').length && $('#chkIva').is(':checked')) {
            iva = total * 0.16;
        }
        
        let totalIvaText = iva > 0 ? formatCurrency(iva) : '\\$0.00';
        $('#taxAmountText').text(totalIvaText);
        
        let totalFmt = formatCurrency(total + iva);
        $('#carritoTotal').text(totalFmt);
        $('#cartTotalText').text(totalFmt);
    }
    
    async function irAlPaso2() {
        // Obsoleto en la nueva UI, ya no hay scrolling
    }
    
    function volverAlPaso1() {
        // Obsoleto
    }
    
    function mostrarReciboPrevio() {
        let tipo = pacienteTipoActual;
        let id_paciente = '';
        let name_paciente = '';
        
        if (tipo === 'estado') {
            id_paciente = pacienteEstadoSeleccionado.id ? "EMP-" + pacienteEstadoSeleccionado.id : '';
            name_paciente = pacienteEstadoSeleccionado.nombre;
        } else {
            id_paciente = $('#selPaciente').val();
            name_paciente = $('#selPaciente option:selected').text();
        }
        
        const id_medico = $('#selMedico').val();
        
        if (!id_paciente) {
            return Swal.fire('Atención', 'Debes seleccionar un Paciente o registrarlo previamente.', 'warning');
        }
        if (!id_medico) {
            return Swal.fire('Atención', 'Debes seleccionar al Médico responsable.', 'warning');
        }
        if (cartItems.length === 0) {
            return Swal.fire('Atención', 'Agrega al menos un concepto a cobrar en el carrito.', 'warning');
        }
        
        let total = cartItems.reduce((acc, it) => acc + (it.precio * it.cantidad), 0);
        let iva = 0;
        if ($('#chkIva').length && $('#chkIva').is(':checked')) {
            iva = total * 0.16;
            total += iva;
        }
        const metodo = $('#selMetodoPago').val();
        
        const fechaHtml = new Date().toLocaleDateString('es-MX', { year:'numeric', month:'short', day:'numeric' });
        let draftHtml = `
        <!DOCTYPE html><html><head><style>body { font-family: 'Inter', sans-serif; padding: 20px; color: #333; } .banner { background: #f59e0b; color: white; text-align: center; padding: 5px; font-weight: bold; font-size: 12px; margin-bottom: 20px; border-radius: 4px; }</style></head><body>
            <div class="banner">VISTA PREVIA DE RECIBO (BORRADOR)</div>
            <h2 style="margin:0 0 5px 0;">Recibo de Caja</h2>
            <p style="margin:0; color:#666;">Fecha: ${fechaHtml} | Método: ${metodo}</p>
            <p style="margin:15px 0; font-size:14px;"><strong>Paciente:</strong> ${name_paciente}<br><strong>Médico:</strong> ${$('#selMedico option:selected').text()}</p>
            <table style="width:100%; border-collapse:collapse; margin-top:20px; font-size:13px;">
                <tr style="background:#f1f5f9;"><th style="padding:8px;text-align:left;">Concepto</th><th style="padding:8px;text-align:center;">Cant.</th><th style="padding:8px;text-align:right;">Subtotal</th></tr>
        `;
        cartItems.forEach(it => {
            const s = it.precio * it.cantidad;
            draftHtml += `<tr><td style="padding:8px; border-bottom:1px solid #e2e8f0;">${it.nombre}</td><td style="padding:8px; border-bottom:1px solid #e2e8f0; text-align:center;">${it.cantidad}</td><td style="padding:8px; border-bottom:1px solid #e2e8f0; text-align:right;">${formatCurrency(s)}</td></tr>`;
        });
        if (iva > 0) {
            draftHtml += `<tr><td colspan="2" style="padding:8px;text-align:right;font-size:14px;color:#666;">Tax (IVA 16%):</td><td style="padding:8px;text-align:right;font-size:14px;color:#666;">${formatCurrency(iva)}</td></tr>`;
        }
        draftHtml += `<tr><td colspan="2" style="padding:8px;text-align:right;font-weight:bold;font-size:16px;">TOTAL PAGADO:</td><td style="padding:8px;text-align:right;font-weight:bold;font-size:16px;color:#10b981;">${formatCurrency(total)}</td></tr>`;
        draftHtml += `</table></body></html>`;
        
        const doc = document.getElementById('iframePreview').contentWindow.document;
        doc.open(); doc.write(draftHtml); doc.close();
        
        $('#modalReciboPrevio').modal('show');
    }
    
    async function emitirReciboFinal() {
        let tipo = pacienteTipoActual;
        let id_paciente = '';
        let name_paciente = '';
        
        if (tipo === 'estado') {
            id_paciente = pacienteEstadoSeleccionado.id ? "EMP-" + pacienteEstadoSeleccionado.id : '';
            name_paciente = pacienteEstadoSeleccionado.nombre;
        } else {
            id_paciente = $('#selPaciente').val();
            name_paciente = $('#selPaciente option:selected').text();
        }
        
        const id_medico = $('#selMedico').val();
        const metodo = $('#selMetodoPago').val();
        let total = cartItems.reduce((acc, it) => acc + (it.precio * it.cantidad), 0);
        let con_iva = 0;
        if ($('#chkIva').length && $('#chkIva').is(':checked')) {
            total += (total * 0.16);
            con_iva = 1;
        }
        
        Swal.fire({ toast: true, position: 'top-end', icon: 'info', title: 'Emitiendo recibo, un momento...', showConfirmButton: false, timer: 2000 });
        
        try {
            const form = new URLSearchParams();
            form.append('id_paciente', id_paciente);
            form.append('nombre_paciente_empleado', name_paciente);
            form.append('id_medico', id_medico);
            form.append('caja_items_json', JSON.stringify(cartItems));
            form.append('caja_metodo_pago', metodo);
            form.append('caja_monto_abono', total);
            form.append('caja_con_iva', con_iva);
            
            const req = await fetch('../api/guardar_recibo_rapido.pl', {
                method: 'POST',
                body: form
            });
            const res = await req.json();
            
            if (res.ok) {
                Swal.fire({
                    icon: 'success',
                    title: '¡Recibo Emitido!',
                    text: 'El ingreso ha sido registrado exitosamente en caja.',
                    confirmButtonText: 'Abrir PDF y Volver'
                }).then(() => {
                    $('#modalReciboPrevio').modal('hide');
                    const script_print = tipo === 'estado' ? 'imprimir_recibo_publico.pl' : 'imprimir_recibo_caja.pl';
                    window.open(`../api/${script_print}?id_consulta=${res.id_tratamiento}`, '_blank');
                    window.location.href = 'inicial.pl';
                });
            } else {
                Swal.fire('Error', res.error || 'No se pudo emitir el recibo.', 'error');
            }
        } catch (e) {
            Swal.fire('Error', 'Hubo un problema de conexión.', 'error');
        }
    }
</script>
JS

utils::sub_sidebar::render_sidebar_footer();

print <<"HTML";
<!-- Modal Recibo Previo -->
<div class="modal fade" id="modalReciboPrevio" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content border-0 shadow-lg rounded-4">
            <div class="modal-header border-0 pb-0">
                <h5 class="modal-title fw-bold" style="color: var(--md-blue-deep, #0A2A66);">
                    <i class="bi bi-eye text-primary"></i> Confirmar Emisión de Recibo
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body text-center pt-3 pb-4">
                <iframe id="iframePreview" style="width: 100%; height: 280px; border: 1px solid #e2e8f0; border-radius: 8px; margin-bottom: 1rem; background: #fafafa;"></iframe>
                <p class="text-muted small mb-4">¿Estás seguro que deseas emitir el recibo? Esta acción registrará el ingreso en caja y no podrá modificarse posteriormente sin generar una cancelación.</p>
                <div class="d-flex justify-content-between gap-3 mt-3">
                    <button type="button" class="btn btn-outline-secondary w-50 fw-bold rounded-pill shadow-sm" data-bs-dismiss="modal">Regresar a Editar</button>
                    <button type="button" class="btn btn-success w-50 fw-bold rounded-pill shadow-sm" onclick="emitirReciboFinal()">Confirmar y Emitir</button>
                </div>
            </div>
        </div>
    </div>
</div>
HTML

render_bottom_nav('finanzas');
print "</body></html>\n";
1;
