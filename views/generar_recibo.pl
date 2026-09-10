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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

my $sd = check_session();
my $q  = $sd->{q};
my $usuario   = $sd->{usuario};
my $role      = $sd->{role};
my $id_medico = $sd->{id_medico} || '';
my $id_empresa = $sd->{id_empresa} || '';

binmode STDOUT, ":utf8";

# Restringir a roles permitidos (Recepcion, Medicos, Admins)
unless ($sd->{session_ok}) {
    print $q->redirect('../index.html');
    exit;
}
if ($role !~ /Recepcionista|Medico|Administrador/i) {
    print $q->redirect('inicial.pl');
    exit;
}

sub html_escape {
    my $s = shift;
    $s //= '';
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&#39;/g;
    return $s;
}

# 1. Leer SaaS Capabilities
my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $config_file = File::Spec->catfile($dat_dir, 'negocios_config.dat');
my %capacidades = ();
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line, -1);
        if ($biz_id eq $id_empresa && $key eq 'PACIENTES_ESTADO') {
            $capacidades{'PACIENTES_ESTADO'} = $val;
        }
        if ($biz_id eq $id_empresa && $key eq 'PORTAL_PACIENTE') {
            $capacidades{'PORTAL_PACIENTE'} = $val;
        }
    }
    close($cf);
}
my $has_pacientes_estado = (exists $capacidades{'PACIENTES_ESTADO'} && $capacidades{'PACIENTES_ESTADO'} eq '1') ? 1 : 0;
my $has_portal_paciente = (!exists $capacidades{'PORTAL_PACIENTE'} || $capacidades{'PORTAL_PACIENTE'} eq '1') ? 1 : 0;

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
    my $safe_nombre = html_escape($m->{nombre});
    $medicos_options .= "<option value='$m->{id}' $sel>$safe_nombre</option>";
}

$org_clues =~ s/[^A-Za-z0-9_]//g; # Sanitize path component

# 2.1 Comprobar catálogos custom (Médicos Legacy)
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
my $rutas = catalogo_org_utils::obtener_rutas_por_clue($org_clues);
my $archivo_medicos_custom = $rutas->{medicos};
my $archivo_espe_custom = $rutas->{especialidades};

my $has_custom_medicos = (-e $archivo_medicos_custom && -e $archivo_espe_custom) ? 1 : 0;
my $espe_options = "<option value=''>-- Selecciona Especialidad --</option>";
my $medicos_custom_js = "{}";

if ($has_custom_medicos) {
    my $espe_regs = leer_tabla($archivo_espe_custom);
    @$espe_regs = sort { $a->[1] cmp $b->[1] } @$espe_regs;
    
    foreach my $e (@$espe_regs) {
        next unless scalar(@$e) >= 2;
        my $sel = ($e->[1] =~ /^MEDICINA GENERAL$/i) ? 'selected' : '';
        my $safe_espe = html_escape($e->[1]);
        $espe_options .= "<option value='$e->[0]' $sel>$safe_espe</option>";
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

my $motivos_html = "<option value=''>-- Selecciona Concepto --</option>";
if ($org_clues) {
    $rutas = catalogo_org_utils::obtener_rutas_por_clue($org_clues);
} else {
    $rutas = catalogo_org_utils::obtener_rutas_catalogo($id_empresa);
}
my $motivos_file = $rutas->{motivos};
if (-e $motivos_file) {
    my $mots = leer_tabla($motivos_file);
    foreach my $m (@$mots) {
        next unless @$m >= 2;
        my $motivo = $m->[1];
        $motivo =~ s/\s+$//; # Strip trailing \r or spaces
        my $safe_mot = html_escape($motivo);
        $motivos_html .= "<option value='$safe_mot'>$safe_mot</option>";
    }
}

my $css_path = File::Spec->catfile($FindBin::Bin, '..', 'css', 'expediente_completo.css');
my $css_ver = (stat($css_path))[9] || $^T;

print <<"HTML";
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme@1.3.0/dist/select2-bootstrap-5-theme.min.css" />
<link rel="stylesheet" href="../css/sdm_mobile_standards.css" />
<link rel="stylesheet" href="../css/expediente_completo.css?v=$css_ver" />

<style>
    /* Unificar estilos de Select2, inputs y contenedores de resultados */
    .select2-container--bootstrap-5 .select2-selection,
    .custom-input-caja {
        border: 1px solid #e9ecef !important;
        border-radius: 1rem !important;
        padding: 0.75rem 1rem !important;
        background: #F8FBFF !important;
        font-family: inherit !important;
        transition: all 0.2s ease-in-out;
    }
    .select2-container--bootstrap-5 .select2-selection:focus,
    .select2-container--bootstrap-5.select2-container--open .select2-selection,
    .custom-input-caja:focus {
        border-color: #19B7A5 !important;
        background: white !important;
        box-shadow: 0 0 0 3px rgba(25, 183, 165, 0.15) !important;
        outline: none !important;
    }
    .select2-dropdown {
        border-color: #19B7A5 !important;
        border-radius: 1rem !important;
        box-shadow: 0 4px 12px rgba(0,0,0,0.1) !important;
    }
    .select2-search__field {
        border-radius: 0.5rem !important;
    }
    .select2-search__field:focus {
        box-shadow: none !important;
        border-color: #19B7A5 !important;
    }
    .select2-container--bootstrap-5 .select2-selection--single .select2-selection__rendered {
        color: #0A2A66 !important;
        font-weight: 600 !important;
        font-size: 0.95rem !important;
        line-height: 1.5 !important;
    }
    .select2-container--bootstrap-5 .select2-selection--single {
        height: auto !important;
    }
    
    /* Grupo de input acoplado para Número de empleado */
    .input-group-caja {
        display: flex;
        border: 1px solid #e9ecef;
        border-radius: 1rem;
        background: #F8FBFF;
        transition: all 0.2s ease-in-out;
    }
    .input-group-caja:focus-within {
        border-color: #19B7A5;
        background: white;
        box-shadow: 0 0 0 3px rgba(25, 183, 165, 0.15);
    }
    .input-group-caja .form-control {
        border: none !important;
        background: transparent !important;
        padding: 0.75rem 1rem !important;
        box-shadow: none !important;
        font-weight: 600 !important;
        color: #0A2A66 !important;
        border-top-right-radius: 0;
        border-bottom-right-radius: 0;
    }
    .input-group-caja .btn {
        border: none !important;
        border-top-right-radius: 1rem !important;
        border-bottom-right-radius: 1rem !important;
        background: var(--md-blue-deep, #0A2A66) !important;
        color: white !important;
        padding: 0 1.5rem !important;
    }
    .custom-cart-container {
        padding-right: 2px;
        scrollbar-width: thin;
        scrollbar-color: #cbd5e1 transparent;
    }
    .custom-cart-container::-webkit-scrollbar {
        width: 6px;
    }
    .custom-cart-container::-webkit-scrollbar-thumb {
        background-color: #cbd5e1;
        border-radius: 4px;
    }
    .cart-item-card {
        background: #F8FBFF;
        border: 1px solid #e9ecef !important;
        border-radius: 0.85rem !important;
        transition: all 0.2s ease-in-out;
    }
    .cart-item-card:hover {
        border-color: #cbd5e1 !important;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
    }
</style>

<main class="container-fluid container-mobile-flush pt-4 px-lg-4 pb-5 animate__animated animate__fadeIn">
    <div class="row g-4 mb-4">
        <!-- Columna Izquierda: Formulario -->
        <div class="col-lg-6">
            <div class="card-medentia-aura p-4 p-md-5 h-100 border-0 shadow-sm" style="border-radius: 1.5rem;">
                <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-person-lines-fill me-2" style="color: var(--md-teal-clinical);"></i>Caja Rápida</h5>
                
                <form id="frmCajaRapida" onsubmit="return false;">
                    
                    <div class="row g-3">
                        <!-- 1. Paciente Privado -->
                        <div class="col-12">
                            <div class="mb-3 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Paciente Privado</label>
                                <select id="selPaciente" class="form-select border-0 shadow-none fw-bold" onchange="seleccionarPacientePrivado()"></select>
                            </div>
                        </div>
                        
                        <!-- Paciente Público -->
                        <div class="col-12">
                            <div class="mb-3 diamond-input-armor">
                                <label class="small fw-bold text-muted mb-2 ps-1">N&uacute;mero Empleado (Estado)</label>
                                <div class="input-group-caja">
                                    <input type="number" id="iptNumEmpleado" class="form-control" placeholder="Ej. 12345" onkeypress="if(event.key==='Enter') buscarEmpleadoEstado()">
                                    <button class="btn" type="button" onclick="buscarEmpleadoEstado()"><i class="bi bi-search"></i></button>
                                </div>
                            </div>
                        </div>
                        
                        <!-- Resultados de búsqueda de empleados (oculto por defecto) -->
                        <div class="col-12" id="resultadosEmpleadoContainer" style="display:none;">
                            <div id="resultadosEmpleado" class="mb-3"></div>
                        </div>

                        <!-- Concepto del Recibo (Movido inmediatamente después de Número de Empleado) -->
                        <div class="col-12">
                            <div class="mb-3 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Concepto del Recibo (Departamento)</label>
                                <select id="selConceptoRecibo" class="form-select py-2 fw-bold border-0 shadow-none bg-transparent" onchange="onConceptoDepartamentoChange()" required>
                                    <option value="">-- Cargando Departamentos... --</option>
                                </select>
                            </div>
                        </div>

                        <!-- Especialidad (Categorías de Consultas) -->
                        <div class="col-12" id="containerEspecialidad">
                            <div class="mb-3 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Especialidad</label>
                                <select id="selEspecialidadCustom" class="form-select py-2 fw-bold border-0 shadow-none bg-transparent" onchange="onEspecialidadChange()">
                                    <option value="">-- Selecciona Especialidad --</option>
                                </select>
                            </div>
                        </div>

                        <!-- Médico Tratante (Ítems de Consulta del Catálogo Universal) -->
                        <div class="col-12" id="containerMedico">
                            <div class="mb-3 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Médico Tratante</label>
                                <select id="selMedico" class="form-select py-2 fw-bold border-0 shadow-none bg-transparent" onchange="onMedicoItemChange()">
                                    <option value="">-- Selecciona Médico --</option>
                                </select>
                            </div>
                        </div>

                        <!-- Tarifa de Consulta (Solo Paciente Privado) -->
                        <div class="col-12" id="containerTarifaConsulta" style="display: none;">
                            <div class="mb-3 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1"><i class="bi bi-tag-fill text-success me-1"></i>Tarifa de Consulta</label>
                                <select id="selTarifaConsulta" class="form-select py-2 fw-bold border-0 shadow-none bg-transparent" onchange="onTarifaConsultaChange()">
                                    <option value="ESTANDAR">ESTÁNDAR (Público General / Base)</option>
                                </select>
                            </div>
                        </div>
                        
                        <!-- Método de Pago -->
                        <div class="col-12">
                            <div class="mb-3 diamond-input-armor rounded-3">
                                <label class="small fw-bold text-muted mb-2 ps-1">Método de Pago</label>
                                <select id="selMetodoPago" class="form-select py-2 fw-bold border-0 shadow-none bg-transparent">
                                    <option value="Efectivo">Efectivo</option>
                                    <option value="Tarjeta de Debito">Tarjeta de Débito</option>
                                    <option value="Tarjeta de Credito">Tarjeta de Crédito</option>
                                    <option value="Transferencia">Transferencia (SPEI)</option>
                                    <option value="Convenio / Aseguradora">Convenio / Aseguradora</option>
                                    <option value="Cortesía">Cortesía (Sin cobro)</option>
                                </select>
                            </div>
                        </div>
HTML

print <<"HTML";
                        
                    </div>
                </form>
            </div>
        </div>
        
        <!-- Columna Derecha: Resumen de Cobro (50% / 50%) -->
        <div class="col-lg-6">
            <div class="card-medentia-aura p-4 p-md-5 h-100 border-0 shadow-sm d-flex flex-column" style="border-radius: 1.5rem;">
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <h5 class="fw-black m-0" style="color: var(--md-blue-deep);"><i class="bi bi-receipt-cutoff me-2" style="color: var(--md-teal-clinical);"></i>Resumen</h5>
                    <button type="button" class="btn btn-sm text-white px-3 py-2 fw-bold rounded-3 shadow-sm btn-mobile-standard d-inline-flex align-items-center gap-1" style="background: var(--md-blue-deep, #0A2A66);" onclick="abrirModalConceptosRecibo()">
                        <i class="bi bi-cart-plus fs-6"></i> <span>Agregar</span>
                    </button>
                </div>
                
                <div id="cartContainer" class="d-flex flex-column custom-cart-container mb-3" style="flex: 1 1 auto; min-height: 100px; max-height: 420px; overflow-y: auto;">
                    <div class="text-center text-muted py-4 px-3 rounded-3 border border-dashed my-auto bg-light" id="cartEmpty">
                        <i class="bi bi-cart-x text-secondary opacity-50 fs-2 d-block mb-2"></i>
                        <div class="fw-bold text-dark mb-1 small">Ningún concepto agregado</div>
                        <div class="text-muted" style="font-size: 0.72rem;">Selecciona una consulta o pulsa <b>+ Agregar</b> para incluir conceptos.</div>
                    </div>
                </div>
                
                <hr class="border-light mt-auto mb-3">
                
                <div class="d-flex justify-content-between align-items-center text-muted small mb-3">
                    <div class="form-check form-switch m-0">
                        <input class="form-check-input" type="checkbox" id="chkIva" onchange="renderCart()">
                        <label class="form-check-label fw-bold" style="cursor: pointer;" for="chkIva">Tax (IVA 16%)</label>
                    </div>
                    <span class="fw-bold text-dark fs-6" id="taxAmountText">\$0.00</span>
                </div>
                
                <div class="d-flex justify-content-between align-items-center mb-4">
                    <span class="fw-bold text-muted" style="letter-spacing: 1px;">TOTAL A PAGAR</span>
                    <span class="fw-black fs-3" style="color: var(--md-blue-deep);" id="cartTotalText">\$0.00</span>
                </div>
                
                <button type="button" class="btn rounded-3 py-3 fw-bold w-100 d-flex align-items-center justify-content-center gap-2 shadow-sm btn-mobile-standard" style="background: var(--md-blue-deep); color: white;" onclick="mostrarReciboPrevio()">
                    <i class="bi bi-check2-circle fs-5"></i> <span>Emitir Recibo</span>
                </button>
            </div>
        </div>
    </div>
</main>
<script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script>
<script>
    const HAS_PACIENTES_ESTADO = ${has_pacientes_estado} || 0;
    const HAS_PORTAL_PACIENTE = ${has_portal_paciente};
    const ORG_CLUES = '$org_clues';
    const MEDICOS_CUSTOM_JSON = $medicos_custom_js;
</script>
HTML

print <<'JS';
<script>
    function escapeHtml(unsafe) {
        if (!unsafe) return '';
        return String(unsafe)
             .replace(/&/g, "&amp;")
             .replace(/</g, "&lt;")
             .replace(/>/g, "&gt;")
             .replace(/"/g, "&quot;")
             .replace(/'/g, "&#039;");
    }

    function formatCurrency(val) {
        return new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(val || 0);
    }

    let cartItems = [];
    let consecutivoId = 1;
    let pacienteSeleccionado = null;
    let cargoSeleccionadoManual = null;

    function _poblarDepartamentosSegunPaciente() {
        if (!window.RAW_CATALOGO || !window.RAW_CATALOGO.departamentos) return;
        const selDep = document.getElementById('selConceptoRecibo');
        if (!selDep) return;
        
        let esEstado = (pacienteTipoActual === 'estado');
        let currentVal = selDep.value;
        
        let depsActivos = (window.RAW_CATALOGO.departamentos || []).filter(d => {
            if (String(d.id_dep) === '1') return true;
            let itemsDep = (window.RAW_CATALOGO.items || []).filter(it => {
                let cat = (window.RAW_CATALOGO.categorias || []).find(c => String(c.id_cat) === String(it.id_cat));
                return cat && String(cat.id_dep) === String(d.id_dep);
            });
            if (itemsDep.length === 0) return false;
            if (esEstado) {
                return itemsDep.some(it => (it.precios || []).some(p => p.tipo_tarifa === 'MUNICIPIO' && parseFloat(p.precio_publico) > 0));
            } else {
                return itemsDep.some(it => (it.precios || []).some(p => p.tipo_tarifa !== 'MUNICIPIO' && parseFloat(p.precio_publico) > 0) || (it.precios || []).some(p => parseFloat(p.precio_publico) > 0));
            }
        });
        
        // 1. Ordenar departamentos alfabéticamente
        depsActivos.sort((a, b) => (a.nombre || '').localeCompare(b.nombre || '', 'es', { sensitivity: 'base' }));

        // 2. Determinar departamento a preseleccionar: 'CONSULTAS' por default si no hay selección previa
        let valToSelect = currentVal;
        if (!valToSelect || !depsActivos.some(d => String(d.id_dep) === String(valToSelect))) {
            let depConsultas = depsActivos.find(d => (d.nombre || '').toUpperCase() === 'CONSULTAS' || String(d.id_dep) === '1');
            valToSelect = depConsultas ? String(depConsultas.id_dep) : (depsActivos[0] ? String(depsActivos[0].id_dep) : '');
        }
        
        let html = '<option value="">-- Selecciona Departamento / Concepto --</option>';
        depsActivos.forEach(d => {
            let sel = (String(valToSelect) === String(d.id_dep)) ? 'selected' : '';
            html += `<option value="${d.id_dep}" ${sel}>${escapeHtml(d.nombre)}</option>`;
        });
        selDep.innerHTML = html;
        selDep.value = valToSelect;
        onConceptoDepartamentoChange();
    }

    function onConceptoDepartamentoChange() {
        const selDep = document.getElementById('selConceptoRecibo');
        const depId = selDep ? selDep.value : '';
        const contEspe = document.getElementById('containerEspecialidad');
        const contMed  = document.getElementById('containerMedico');
        const contTarifa = document.getElementById('containerTarifaConsulta');
        const selMed   = document.getElementById('selMedico');
        
        if (String(depId) === '1') {
            if (contEspe) contEspe.style.display = '';
            if (contMed) contMed.style.display = '';
            if (contTarifa && pacienteTipoActual !== 'estado') contTarifa.style.display = '';
            if (selMed) selMed.setAttribute('required', 'required');
            _poblarEspecialidades('1');
        } else {
            if (contEspe) contEspe.style.display = 'none';
            if (contMed) contMed.style.display = 'none';
            if (contTarifa) contTarifa.style.display = 'none';
            if (selMed) {
                selMed.removeAttribute('required');
                selMed.value = '';
            }
            cartItems = cartItems.filter(it => !it.is_consulta_principal);
            renderCart();
        }
    }

    function _poblarEspecialidades(depId) {
        if (!window.RAW_CATALOGO || !window.RAW_CATALOGO.categorias) return;
        const selEspe = document.getElementById('selEspecialidadCustom');
        if (!selEspe) return;
        
        let currentVal = selEspe.value;
        let esEstado = (pacienteTipoActual === 'estado');

        // Filtrar especialidades según tarifas activas (> 0) del tipo de paciente
        let cats = (window.RAW_CATALOGO.categorias || []).filter(c => {
            if (String(c.id_dep) !== String(depId)) return false;
            
            // Si es CONSULTAS (depId == 1), validar que exista al menos un médico con tarifa > 0 aplicable
            if (String(depId) === '1') {
                let itemsDeEspecialidad = (window.RAW_CATALOGO.items || []).filter(it => String(it.id_cat) === String(c.id_cat));
                if (itemsDeEspecialidad.length === 0) return false;

                if (esEstado) {
                    // Para Municipio/Convenio: Al menos un médico debe tener tarifa MUNICIPIO > 0
                    return itemsDeEspecialidad.some(it => 
                        (it.precios || []).some(p => p.tipo_tarifa === 'MUNICIPIO' && parseFloat(p.precio_publico) > 0)
                    );
                } else {
                    // Para Paciente Privado: Al menos un médico debe tener tarifa privada (ESTANDAR u otra != MUNICIPIO) > 0
                    return itemsDeEspecialidad.some(it => 
                        (it.precios || []).some(p => p.tipo_tarifa !== 'MUNICIPIO' && parseFloat(p.precio_publico) > 0)
                    );
                }
            }
            return true;
        });

        cats.sort((a, b) => (a.nombre || '').localeCompare(b.nombre || '', 'es', { sensitivity: 'base' }));
        
        let html = '<option value="">-- Selecciona Especialidad --</option>';
        cats.forEach(c => {
            let sel = (currentVal && String(currentVal) === String(c.id_cat)) ? 'selected' : '';
            html += `<option value="${c.id_cat}" ${sel}>${escapeHtml(c.nombre)}</option>`;
        });
        selEspe.innerHTML = html;
        
        if (currentVal && cats.some(c => String(c.id_cat) === String(currentVal))) {
            selEspe.value = currentVal;
        } else if (cats.length > 0) {
            let medGral = cats.find(c => (c.nombre || '').toUpperCase() === 'MEDICINA GENERAL');
            if (medGral) {
                selEspe.value = medGral.id_cat;
            } else {
                selEspe.selectedIndex = 1;
            }
        }
        onEspecialidadChange();
    }

    function onEspecialidadChange() {
        if (!window.RAW_CATALOGO || !window.RAW_CATALOGO.items) return;
        const selEspe = document.getElementById('selEspecialidadCustom');
        const selMed = document.getElementById('selMedico');
        if (!selEspe || !selMed) return;
        
        const catId = selEspe.value;
        if (!catId) {
            selMed.innerHTML = '<option value="">-- Selecciona Especialidad Primero --</option>';
            cartItems = cartItems.filter(it => !it.is_consulta_principal);
            renderCart();
            return;
        }
        
        let esEstado = (pacienteTipoActual === 'estado');
        // Filtrar médicos de la especialidad cuya tarifa correspondiente sea mayor a 0
        let itemsCat = (window.RAW_CATALOGO.items || []).filter(it => {
            if (String(it.id_cat) !== String(catId)) return false;
            if (esEstado) {
                return (it.precios || []).some(p => p.tipo_tarifa === 'MUNICIPIO' && parseFloat(p.precio_publico) > 0);
            } else {
                return (it.precios || []).some(p => p.tipo_tarifa !== 'MUNICIPIO' && parseFloat(p.precio_publico) > 0);
            }
        });
        
        // Extraer nombre del doctor y ordenar alfabéticamente (limpiando cualquier precio o sufijo)
        itemsCat.forEach(it => {
            let displayNom = it.concepto || it.nombre || '';
            let labelMedico = displayNom;
            if (displayNom.includes(' - ')) {
                let parts = displayNom.split(' - ');
                labelMedico = parts[parts.length - 1].trim();
            }
            // Quitar cualquier precio en formato $... o (...) del nombre del médico
            labelMedico = labelMedico.replace(/\s*(?:-\s*)?\$[\d.,]+.*/g, '').replace(/\s*\(.*?\)/g, '').trim();
            it._labelMedico = labelMedico;
        });
        itemsCat.sort((a, b) => (a._labelMedico || '').localeCompare(b._labelMedico || '', 'es', { sensitivity: 'base' }));
        
        let html = '<option value="">-- Selecciona Médico --</option>';
        itemsCat.forEach(it => {
            let pMunObj = (it.precios || []).find(p => p.tipo_tarifa === 'MUNICIPIO');
            let pEstObj = (it.precios || []).find(p => p.tipo_tarifa === 'ESTANDAR') || (it.precios || [])[0];
            let pMun = pMunObj ? parseFloat(pMunObj.precio_publico || 0) : 0;
            let pEst = pEstObj ? parseFloat(pEstObj.precio_publico || 0) : 0;
            let precioActivo = esEstado ? (pMun || pEst) : pEst;
            let displayNom = it.concepto || it.nombre;
            
            html += `<option value="${it.id_item}" data-item-id="${it.id_item}" data-concepto="${escapeHtml(displayNom)}" data-precio-mun="${pMun}" data-precio-est="${pEst}" data-precio="${precioActivo}">${escapeHtml(it._labelMedico)}</option>`;
        });
        
        selMed.innerHTML = html;
        if (itemsCat.length === 1) {
            selMed.selectedIndex = 1;
        }
        onMedicoItemChange();
    }

    function onMedicoItemChange() {
        const selMed = document.getElementById('selMedico');
        const contTarifa = document.getElementById('containerTarifaConsulta');
        const selTarifa = document.getElementById('selTarifaConsulta');
        if (!selMed) return;
        
        const opt = selMed.options[selMed.selectedIndex];
        const itemId = selMed.value;
        
        cartItems = cartItems.filter(it => !it.is_consulta_principal);
        
        if (itemId && opt && opt.value) {
            let esEstado = (pacienteTipoActual === 'estado');
            let pMun = parseFloat(opt.getAttribute('data-precio-mun')) || 0;
            let pEst = parseFloat(opt.getAttribute('data-precio-est')) || 0;
            let precioActivo = esEstado ? (pMun || pEst) : pEst;
            let conceptoStr = opt.getAttribute('data-concepto') || opt.text;
            let tarifaSeleccionada = 'ESTANDAR';

            // Si el departamento es CONSULTAS (depId == 1), armar concepto: "Consulta - [ESPECIALIDAD]"
            const selDep = document.getElementById('selConceptoRecibo');
            const depId = selDep ? selDep.value : '';
            const selEspe = document.getElementById('selEspecialidadCustom');
            let espTexto = (selEspe && selEspe.selectedIndex >= 0 && selEspe.options[selEspe.selectedIndex].value) 
                ? selEspe.options[selEspe.selectedIndex].text.trim() 
                : '';
            
            let medNombre = opt.text.trim();
            let conceptoFinal = conceptoStr;
            if (String(depId) === '1' && espTexto) {
                conceptoFinal = `Consulta - ${espTexto}`;
            }

            // Poblar selector de tarifas para paciente privado en consultas
            if (!esEstado && contTarifa && selTarifa && window.RAW_CATALOGO && window.RAW_CATALOGO.items) {
                contTarifa.style.display = '';
                const itObj = (window.RAW_CATALOGO.items || []).find(it => String(it.id_item) === String(itemId));
                let preciosPrivados = (itObj && itObj.precios) ? itObj.precios.filter(p => p.tipo_tarifa !== 'MUNICIPIO' && parseFloat(p.precio_publico) > 0) : [];
                
                if (preciosPrivados.length > 0) {
                    let optHtml = '';
                    const tarifasMeta = (window.RAW_CATALOGO && window.RAW_CATALOGO.tipos_tarifas) ? window.RAW_CATALOGO.tipos_tarifas : [];
                    preciosPrivados.forEach(p => {
                        let metaObj = tarifasMeta.find(tm => tm.clave === p.tipo_tarifa);
                        let labelTarifa = (metaObj && metaObj.nombre_tarifa) ? metaObj.nombre_tarifa : p.tipo_tarifa.replace(/_/g, ' ');
                        optHtml += `<option value="${p.tipo_tarifa}" data-precio="${p.precio_publico}">${labelTarifa} (${formatCurrency(p.precio_publico)})</option>`;
                    });
                    selTarifa.innerHTML = optHtml;
                    let primerOpt = selTarifa.options[0];
                    if (primerOpt) {
                        tarifaSeleccionada = primerOpt.value;
                        precioActivo = parseFloat(primerOpt.getAttribute('data-precio')) || precioActivo;
                    }
                } else {
                    selTarifa.innerHTML = `<option value="ESTANDAR" data-precio="${pEst}">ESTÁNDAR (${formatCurrency(pEst)})</option>`;
                }
            } else if (contTarifa) {
                contTarifa.style.display = 'none';
            }
            
            cartItems.unshift({
                id: itemId,
                id_item: itemId,
                nombre: conceptoFinal,
                concepto: conceptoFinal,
                medico: medNombre,
                nombre_medico: medNombre,
                especialidad: espTexto,
                precio: precioActivo,
                precio_paciente: esEstado ? 0 : precioActivo,
                cubierto_convenio: esEstado ? 1 : 0,
                cantidad: 1,
                tipo_tarifa: tarifaSeleccionada,
                is_consulta_principal: true
            });
        } else {
            if (contTarifa) contTarifa.style.display = 'none';
        }
        renderCart();
    }

    function onTarifaConsultaChange() {
        const selTarifa = document.getElementById('selTarifaConsulta');
        if (!selTarifa) return;
        const opt = selTarifa.options[selTarifa.selectedIndex];
        if (!opt) return;

        const nuevaTarifa = opt.value;
        const nuevoPrecio = parseFloat(opt.getAttribute('data-precio')) || 0;

        let consultaItem = cartItems.find(it => it.is_consulta_principal);
        if (consultaItem) {
            consultaItem.precio = nuevoPrecio;
            consultaItem.precio_paciente = nuevoPrecio;
            consultaItem.tipo_tarifa = nuevaTarifa;
            renderCart();
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        initSelect2Paciente();
        _cargarCatalogoRecibo();

        $('#iptNumEmpleado').on('input', function() {
            if (!$(this).val().trim() && pacienteTipoActual === 'estado') {
                pacienteTipoActual = 'privado';
                $('#resultadosEmpleado').html('');
                $('#resultadosEmpleadoContainer').hide();
                pacienteEstadoSeleccionado = { id: '', nombre: '' };
                _actualizarTarifasSegunPaciente();
            }
        });
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
                if (res.ok && res.resultados && res.resultados.length > 0) {
                    let html = '';
                    try {
                        res.resultados.forEach((emp, i) => {
                            let isChecked = i === 0 ? 'checked' : '';
                            let nombreStr = emp.nombre ? String(emp.nombre) : '';
                            let safeNombre = escapeHtml(nombreStr).replace(/'/g, "\\'");
                            if(i===0) seleccionarEmpleadoEstado(emp.id, nombreStr); // Select first auto
                            
                            let badgeText = (emp.relacion && emp.relacion.toLowerCase() === 'empleado') ? 'Empleado' : (emp.relacion || 'Desconocido');
                            
                            html += `
                            <div class="form-check custom-input-caja p-2 mb-2 d-flex align-items-center">
                                <input class="form-check-input ms-0 me-3" style="width:1.2rem; height:1.2rem;" type="radio" name="empSeleccionado" id="empSel${escapeHtml(emp.id)}_${i}" value="${escapeHtml(emp.id)}" ${isChecked} onchange="seleccionarEmpleadoEstado('${escapeHtml(emp.id)}', '${safeNombre}')">
                                <label class="form-check-label w-100 mb-0" for="empSel${escapeHtml(emp.id)}_${i}" style="cursor:pointer; display:flex; align-items:center;">
                                    <div class="fw-bold text-dark flex-grow-1">${escapeHtml(nombreStr)}</div>
                                    <span class="badge bg-secondary rounded-pill px-3">${escapeHtml(badgeText)}</span>
                                </label>
                            </div>`;
                        });
                        html += `
                        <div class="mt-3 text-end border-top pt-2">
                            <button type="button" class="btn btn-outline-primary btn-sm rounded-pill px-4 shadow-sm fw-bold" onclick="window.location.href='crud_empleados.pl?clues='+ORG_CLUES">
                                <i class="bi bi-pencil-square me-1"></i> Editar Beneficiarios
                            </button>
                        </div>`;
                        $('#resultadosEmpleado').html(html);
                        pacienteTipoActual = 'estado';
                        $('#selPaciente').val(null).trigger('change.select2');
                    } catch (err) {
                        console.error("Error al procesar resultados:", err);
                        $('#resultadosEmpleado').html('<div class="alert alert-danger py-2 small m-0 border-0 shadow-sm"><i class="bi bi-exclamation-circle text-danger me-2"></i>Error interno al mostrar resultados. Revise la consola.</div>');
                    }
                } else {
                    $('#resultadosEmpleado').html(`<div class="alert alert-warning py-3 text-center small m-0 shadow-sm border-0"><p class="mb-2"><i class="bi bi-exclamation-triangle fs-4 d-block mb-1"></i>No se encontraron resultados para el número de empleado ingresado.</p><button type="button" class="btn btn-primary btn-sm rounded-pill px-4 shadow-sm mt-2 fw-bold" onclick="window.location.href='crud_empleados.pl?clues='+ORG_CLUES"><i class="bi bi-person-plus me-1"></i> Registrar Nuevo Empleado / Beneficiario</button></div>`);
                    pacienteEstadoSeleccionado = { id: '', nombre: '' };
                }
            },
            error: function() {
                $('#resultadosEmpleado').html('<div class="alert alert-danger py-2 small m-0">Error de conexión al buscar.</div>');
            }
        });
    }

    function seleccionarEmpleadoEstado(id, nombre) {
        pacienteEstadoSeleccionado = { id: id, nombre: nombre };
        pacienteTipoActual = 'estado';
        _actualizarTarifasSegunPaciente();
    }

    function initSelect2Paciente() {
        if ($('#selPaciente').hasClass('select2-hidden-accessible')) {
            $('#selPaciente').select2('destroy');
        }
        
        let ajaxUrl = HAS_PORTAL_PACIENTE ? '../api/autocomplete_pacientes.pl' : '../api/autocomplete_pacientes_privados.pl';
        let ajaxDataFn = HAS_PORTAL_PACIENTE ? function (params) { return { term: params.term }; } : function (params) { return { term: params.term, clues: ORG_CLUES }; };
        
        $('#selPaciente').select2({
            theme: 'bootstrap-5',
            placeholder: '🔍 Escribe el nombre del paciente (Privado)...',
            minimumInputLength: 2,
            tags: !HAS_PORTAL_PACIENTE, // Permitir agregar nuevos nombres si no hay portal
            ajax: {
                url: ajaxUrl,
                dataType: 'json',
                delay: 350,
                data: ajaxDataFn,
                processResults: function (data) {
                    return {
                        results: $.map(data, function (item) {
                            return {
                                id: item.id,
                                text: item.label,
                                nombre: item.label
                            }
                        })
                    };
                },
                cache: true
            },
            createTag: function(params) {
                if(HAS_PORTAL_PACIENTE) return null; // No permitir crear si el portal global manda
                var term = $.trim(params.term);
                if (term === '') return null;
                return { id: term, text: term, newTag: true };
            },
            language: {
                inputTooShort: function() { return "Por favor ingresa 2 o más caracteres"; },
                noResults: function() { return HAS_PORTAL_PACIENTE ? "No se encontraron resultados" : "Presiona enter para agregar como nuevo paciente"; },
                searching: function() { return "Buscando..."; }
            }
        });

        $('#selPaciente').on('select2:select', function (e) {
            seleccionarPacientePrivado();
        });
    }

    let pacienteTipoActual = 'privado';

    function cambiarTipoPaciente(e) {
        // Función mantenida por compatibilidad (vacía)
    }
    
    function seleccionarPacientePrivado() {
        if(!$('#selPaciente').val()) return; // Evitar dispararse a sí mismo cuando se limpia vía JS
        pacienteTipoActual = 'privado';
        $('#resultadosEmpleado').html('');
        $('#resultadosEmpleadoContainer').hide();
        $('#iptNumEmpleado').val('');
        pacienteEstadoSeleccionado = { id: '', nombre: '' };
        _actualizarTarifasSegunPaciente();
    }

    function _actualizarTarifasSegunPaciente() {
        let esEstado = (pacienteTipoActual === 'estado');
        
        // 1. Conmutar departamentos y cascada de consulta de la cabecera
        _poblarDepartamentosSegunPaciente();
        
        // 2. Conmutar precios del catalogo modal (servicios adicionales)
        (masterCatalogoRecibo || []).forEach(it => {
            it.precio = esEstado ? (it.precio_municipio || it.precio_estandar || 0) : (it.precio_estandar || 0);
        });

        // Refrescar los filtros de departamento y categoría del modal según las tarifas del paciente
        if (typeof _poblarFiltrosRecibo === 'function') _poblarFiltrosRecibo();
        
        if (modalCartItems && modalCartItems.length > 0) {
            modalCartItems.forEach(it => {
                let master = masterCatalogoRecibo.find(m => m.id === it.id);
                if (master) {
                    it.precio = esEstado ? (master.precio_municipio || master.precio_estandar || 0) : (master.precio_estandar || 0);
                }
            });
            if (typeof _renderizarCarritoModalRecibo === 'function') _renderizarCarritoModalRecibo();
        }
        
        // 3. Conmutar items en el carrito activo
        if (cartItems && cartItems.length > 0) {
            cartItems.forEach(it => {
                if (it.is_consulta_principal) {
                    const selMed = document.getElementById('selMedico');
                    const opt = selMed ? selMed.options[selMed.selectedIndex] : null;
                    if (opt && opt.value) {
                        let pMun = parseFloat(opt.getAttribute('data-precio-mun')) || 0;
                        let pEst = parseFloat(opt.getAttribute('data-precio-est')) || 0;
                        let pActivo = esEstado ? (pMun || pEst) : pEst;
                        it.precio = pActivo;
                        it.precio_paciente = esEstado ? 0 : pActivo;
                        it.cubierto_convenio = esEstado ? 1 : 0;
                    }
                } else {
                    let master = masterCatalogoRecibo.find(m => m.id === it.id);
                    if (master) {
                        it.precio = esEstado ? (master.precio_municipio || master.precio_estandar || 0) : (master.precio_estandar || 0);
                        if (esEstado && it.cubierto_convenio) {
                            it.precio_paciente = 0;
                        }
                    }
                }
            });
            if (typeof renderCart === 'function') renderCart();
        }
        
        if (typeof _renderizarCatalogoRecibo === 'function') _renderizarCatalogoRecibo();
    }

    let masterCatalogoRecibo = [];
    let modalCartItems = [];
    let recDepsMap = {};
    let recCatsMap = {};

    async function _cargarCatalogoRecibo() {
        if (masterCatalogoRecibo.length > 0) return;
        try {
            const res = await fetch('../api/estado_cuenta_api.pl', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams({ accion: 'get_catalogo' })
            }).then(r => r.json());

            masterCatalogoRecibo = [];
            recDepsMap = {};
            recCatsMap = {};

            if (res.is_universal && res.catalogo) {
                window.RAW_CATALOGO = res.catalogo;

                // REGLA DE EXCLUSIÓN: Omitir ID_DEP = 1 (CONSULTAS) del mapa de departamentos del modal del carrito
                (res.catalogo.departamentos || []).forEach(d => {
                    if (String(d.id_dep) !== '1') {
                        recDepsMap[d.id_dep] = d.nombre;
                    }
                });

                (res.catalogo.categorias || []).forEach(c => {
                    recCatsMap[c.id_cat] = { n: c.nombre, d: c.id_dep };
                });

                // REGLA DE EXCLUSIÓN: Omitir ítems con departamento 1 (CONSULTAS) del carrito modal
                (res.catalogo.items || []).forEach(c => {
                    var catInfo = recCatsMap[c.id_cat] || { d: '' };
                    if (String(catInfo.d) === '1') {
                        return; // Omitir del catálogo del modal del carrito
                    }

                    var pEst = (c.precios || []).find(p => p.tipo_tarifa === 'ESTANDAR') || (c.precios || [])[0];
                    var pMun = (c.precios || []).find(p => p.tipo_tarifa === 'MUNICIPIO');
                    var precioEst = pEst ? parseFloat(pEst.precio_publico || 0) : 0;
                    var precioMun = pMun ? parseFloat(pMun.precio_publico || 0) : precioEst;
                    var esEstado = (pacienteTipoActual === 'estado');
                    
                    masterCatalogoRecibo.push({
                        id: c.id_item,
                        nombre: c.concepto || c.nombre,
                        precio_estandar: precioEst,
                        precio_municipio: precioMun,
                        precio: esEstado ? precioMun : precioEst,
                        indicaciones: c.indicaciones || '',
                        cat: c.id_cat,
                        dep: catInfo.d
                    });
                });

                (res.catalogo.productos || []).forEach(p => {
                    masterCatalogoRecibo.push({
                        id: p.id_prod,
                        nombre: p.nombre,
                        precio: parseFloat(p.precio) || 0,
                        cat: '',
                        dep: ''
                    });
                });

                _poblarFiltrosRecibo();
                _poblarDepartamentosSegunPaciente();
            } else {
                (res.servicios || []).forEach(s => {
                    masterCatalogoRecibo.push({ id: s.id, nombre: s.nombre, precio: parseFloat(s.precio) || 0, cat: '', dep: '' });
                });
                (res.productos || []).forEach(p => {
                    masterCatalogoRecibo.push({ id: p.id, nombre: p.nombre, precio: parseFloat(p.precio) || 0, cat: '', dep: '' });
                });
            }
        } catch (e) {
            console.error("Error al cargar catálogo de recibo:", e);
        }
    }

    function _poblarFiltrosRecibo() {
        const selDep = document.getElementById('reciboSelDep');
        const selCat = document.getElementById('reciboSelCat');
        if (!selDep || !selCat) return;

        let curDepVal = selDep.value;
        selDep.innerHTML = '<option value="">Todos los Departamentos</option>';
        selCat.innerHTML = '<option value="">Todas las Categorías</option>';

        let esEstado = (pacienteTipoActual === 'estado');

        // Identificar departamentos con al menos 1 ítem con tarifa > 0 para el paciente activo
        let depsValidos = new Set();
        (masterCatalogoRecibo || []).forEach(it => {
            let pVal = esEstado ? 
                ((it.precio_municipio !== undefined) ? parseFloat(it.precio_municipio) : parseFloat(it.precio)) :
                ((it.precio_estandar !== undefined) ? parseFloat(it.precio_estandar) : parseFloat(it.precio));
            if (pVal > 0 && it.dep) {
                depsValidos.add(String(it.dep));
            }
        });

        let depsArray = [];
        for (var k in recDepsMap) {
            if (depsValidos.has(String(k))) {
                depsArray.push({ id: k, nombre: recDepsMap[k] });
            }
        }
        depsArray.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es', { sensitivity: 'base' }));
        depsArray.forEach(d => {
            let sel = (String(curDepVal) === String(d.id)) ? 'selected' : '';
            selDep.insertAdjacentHTML('beforeend', `<option value="${d.id}" ${sel}>${escapeHtml(d.nombre)}</option>`);
        });

        _onDepChangeRecibo();
    }

    function _onDepChangeRecibo() {
        const selDep = document.getElementById('reciboSelDep');
        const selCat = document.getElementById('reciboSelCat');
        if (!selDep || !selCat) return;
        const dep = selDep.value;
        let curCatVal = selCat.value;
        selCat.innerHTML = '<option value="">Todas las Categorías</option>';

        let esEstado = (pacienteTipoActual === 'estado');

        // Filtrar categorías que posean ítems válidos (> 0) según el departamento seleccionado
        let catsConItemsValidos = new Set();
        (masterCatalogoRecibo || []).forEach(it => {
            let pVal = esEstado ? 
                ((it.precio_municipio !== undefined) ? parseFloat(it.precio_municipio) : parseFloat(it.precio)) :
                ((it.precio_estandar !== undefined) ? parseFloat(it.precio_estandar) : parseFloat(it.precio));
            if (pVal > 0 && (!dep || String(it.dep) === String(dep)) && it.cat) {
                catsConItemsValidos.add(String(it.cat));
            }
        });

        let catsArray = [];
        for (var k in recCatsMap) {
            if (catsConItemsValidos.has(String(k))) {
                if (dep === '' || String(recCatsMap[k].d) === String(dep)) {
                    catsArray.push({ id: k, nombre: recCatsMap[k].n });
                }
            }
        }
        catsArray.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es', { sensitivity: 'base' }));
        catsArray.forEach(c => {
            let sel = (String(curCatVal) === String(c.id)) ? 'selected' : '';
            selCat.insertAdjacentHTML('beforeend', `<option value="${c.id}" ${sel}>${escapeHtml(c.nombre)}</option>`);
        });
        _filtrarCatalogoRecibo();
    }

    function _filtrarCatalogoRecibo() {
        _renderizarCatalogoRecibo();
    }

    function _renderizarCatalogoRecibo() {
        const tbody = document.getElementById('reciboTablaCatalogo');
        if (!tbody) return;
        tbody.innerHTML = '';

        const filterText = (document.getElementById('reciboBuscador') ? document.getElementById('reciboBuscador').value : '').toLowerCase();
        const selDep = document.getElementById('reciboSelDep') ? document.getElementById('reciboSelDep').value : '';
        const selCat = document.getElementById('reciboSelCat') ? document.getElementById('reciboSelCat').value : '';
        const esEstado = (pacienteTipoActual === 'estado');

        const filtered = masterCatalogoRecibo.filter(item => {
            const matchText = (item.nombre || '').toLowerCase().includes(filterText);
            const matchDep = !selDep || item.dep == selDep;
            const matchCat = !selCat || item.cat == selCat;

            // Filtrar ítems cuyo precio para el tipo de paciente activo sea mayor a 0
            let pVal = esEstado ? 
                ((item.precio_municipio !== undefined) ? parseFloat(item.precio_municipio) : parseFloat(item.precio)) :
                ((item.precio_estandar !== undefined) ? parseFloat(item.precio_estandar) : parseFloat(item.precio));

            return matchText && matchDep && matchCat && (pVal > 0);
        });

        if (filtered.length === 0) {
            tbody.innerHTML = '<tr><td colspan="3" class="text-center text-muted small py-3">No se encontraron conceptos</td></tr>';
            return;
        }

        filtered.forEach(it => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td class="ps-3 fw-bold small text-dark align-middle">${escapeHtml(it.nombre)}</td>
                <td class="text-end fw-bold text-success small align-middle">${formatCurrency(it.precio)}</td>
                <td class="text-center align-middle">
                    <button type="button" class="btn btn-sm text-white rounded-circle p-0 d-inline-flex align-items-center justify-content-center shadow-sm" style="width:26px; height:26px; background: var(--md-blue-deep, #0A2A66);" onclick="agregarAlCarritoModalRecibo('${escapeHtml(it.id)}')">
                        <i class="bi bi-plus" style="font-size:1.1rem;"></i>
                    </button>
                </td>
            `;
            tbody.appendChild(tr);
        });
    }

    async function abrirModalConceptosRecibo() {
        modalCartItems = JSON.parse(JSON.stringify(cartItems));
        await _cargarCatalogoRecibo();
        _renderizarCatalogoRecibo();
        _renderizarCarritoModalRecibo();

        const el = document.getElementById('modalConceptosRecibo');
        if (!el) return;
        if (el.parentElement !== document.body) {
            document.body.appendChild(el);
        }
        const m = bootstrap.Modal.getOrCreateInstance(el);
        m.show();
    }

    function agregarAlCarritoModalRecibo(id) {
        const item = masterCatalogoRecibo.find(x => x.id === id);
        if (!item) return;
        let ex = modalCartItems.find(x => x.nombre === item.nombre);
        if (ex) {
            ex.cantidad++;
        } else {
            modalCartItems.push({ id: item.id, nombre: item.nombre, precio: parseFloat(item.precio), indicaciones: item.indicaciones || '', cantidad: 1 });
        }
        _renderizarCarritoModalRecibo();
    }

    function agregarItemManualRecibo() {
        const nomIn = document.getElementById('reciboManualNombre');
        const precIn = document.getElementById('reciboManualPrecio');
        if (!nomIn || !precIn) return;
        const nombre = nomIn.value.trim();
        const precio = parseFloat(precIn.value) || 0;
        if (!nombre) {
            Swal.fire('Atención', 'Ingresa el nombre del concepto.', 'warning');
            return;
        }
        modalCartItems.push({
            id: 'MAN-' + Date.now(),
            nombre: nombre,
            precio: precio,
            cantidad: 1
        });
        nomIn.value = '';
        precIn.value = '';
        _renderizarCarritoModalRecibo();
    }

    function _renderizarCarritoModalRecibo() {
        const container = document.getElementById('reciboListaCarritoModal');
        const totalEl = document.getElementById('reciboTotalCarritoModal');
        if (!container) return;

        if (modalCartItems.length === 0) {
            container.innerHTML = `
                <div class="text-center py-5 text-muted">
                    <i class="bi bi-cart-x fs-1 d-block mb-2 text-black-50"></i>
                    <span class="fw-bold small">Sin conceptos</span>
                </div>`;
            if (totalEl) totalEl.textContent = '$0.00';
            return;
        }

        let html = '';
        let total = 0;
        modalCartItems.forEach((it, idx) => {
            const sub = it.precio * it.cantidad;
            total += sub;
            html += `
                <div class="bg-white p-2 mb-2 rounded-3 border shadow-sm d-flex align-items-center justify-content-between gap-2">
                    <div class="lh-sm flex-grow-1 overflow-hidden">
                        <div class="fw-bold text-dark text-truncate small">${escapeHtml(it.nombre)}</div>
                        <div class="text-muted small" style="font-size:0.75rem;">${formatCurrency(it.precio)} c/u</div>
                    </div>
                    <div class="d-flex align-items-center gap-1">
                        <button type="button" class="btn btn-sm btn-light border p-0 rounded-circle d-inline-flex align-items-center justify-content-center" style="width:22px; height:22px; line-height:1;" onclick="updateModalQtyRecibo(${idx}, -1)">-</button>
                        <span class="fw-bold small px-1">${it.cantidad}</span>
                        <button type="button" class="btn btn-sm btn-light border p-0 rounded-circle d-inline-flex align-items-center justify-content-center" style="width:22px; height:22px; line-height:1;" onclick="updateModalQtyRecibo(${idx}, 1)">+</button>
                    </div>
                    <div class="fw-bold small text-end" style="min-width:60px; color: var(--md-blue-deep, #0A2A66);">${formatCurrency(sub)}</div>
                    <button type="button" class="btn btn-sm text-danger p-0 border-0 shadow-none" onclick="removeModalItemRecibo(${idx})"><i class="bi bi-trash"></i></button>
                </div>`;
        });
        container.innerHTML = html;
        if (totalEl) totalEl.textContent = formatCurrency(total);
    }

    function updateModalQtyRecibo(idx, delta) {
        if (modalCartItems[idx]) {
            modalCartItems[idx].cantidad += delta;
            if (modalCartItems[idx].cantidad < 1) modalCartItems[idx].cantidad = 1;
            _renderizarCarritoModalRecibo();
        }
    }

    function removeModalItemRecibo(idx) {
        modalCartItems.splice(idx, 1);
        _renderizarCarritoModalRecibo();
    }

    function guardarConceptosModalRecibo() {
        cartItems = JSON.parse(JSON.stringify(modalCartItems));
        renderCart();
        const el = document.getElementById('modalConceptosRecibo');
        if (el) {
            const m = bootstrap.Modal.getInstance(el);
            if (m) m.hide();
        }
    }

    function removeConcepto(idx) {
        cartItems.splice(idx, 1);
        renderCart();
    }

    function updateCantidad(idx, delta) {
        if (cartItems[idx]) {
            cartItems[idx].cantidad += delta;
            if (cartItems[idx].cantidad < 1) cartItems[idx].cantidad = 1;
            renderCart();
        }
    }

    function renderCart() {
        const cMain = $('#cartContainer');
        
        if (cartItems.length === 0) {
            let emptyHtml = `
                <div class="text-center text-muted py-4 px-3 rounded-3 border border-dashed my-auto bg-light" id="cartEmpty">
                    <i class="bi bi-cart-x text-secondary opacity-50 fs-2 d-block mb-2"></i>
                    <div class="fw-bold text-dark mb-1 small">Ningún concepto agregado</div>
                    <div class="text-muted" style="font-size: 0.72rem;">Selecciona una consulta o pulsa <b>+ Agregar</b> para incluir conceptos.</div>
                </div>`;
            cMain.html(emptyHtml);
            $('#taxAmountText').text('$0.00');
            $('#cartTotalText').text('$0.00');
            return;
        }

        let html = '';
        let totalCobrar = 0;
        let totalConvenio = 0;
        
        cartItems.forEach((item, idx) => {
            let isCubierto = (pacienteTipoActual === 'estado' && (item.cubierto_convenio || item.precio_paciente === 0));
            const sub = (item.precio || 0) * (item.cantidad || 1);
            if (isCubierto) {
                totalConvenio += sub;
            } else {
                totalCobrar += ((item.precio_paciente !== undefined ? item.precio_paciente : item.precio) * (item.cantidad || 1));
            }
            
            let badgePrecio = isCubierto ?
                `<span class="badge rounded-pill ms-1" style="background:#e0f2fe; color:#0369a1; font-size: 0.68rem; border: 1px solid #bae6fd;">[Convenio Estado]</span>` :
                `<span class="fw-bold ms-1" style="font-size: 0.78rem; color: var(--md-blue-deep, #0A2A66);">${formatCurrency(sub)}</span>`;
                
            let subtexto = isCubierto ?
                `<small class="text-muted fw-bold" style="font-size: 0.7rem;">Convenio Municipio</small>` :
                `<small class="text-muted fw-bold" style="font-size: 0.7rem;">${formatCurrency(item.precio)} c/u</small>`;
            
            html += `
                <div class="cart-item-card p-2.5 rounded-3 mb-2 d-flex flex-column gap-1.5 w-100">
                    <div class="d-flex justify-content-between align-items-start gap-2">
                        <span class="fw-bold text-dark text-uppercase flex-grow-1" style="font-size: 0.73rem; line-height: 1.3; letter-spacing: 0.1px;">${escapeHtml(item.nombre)}</span>
                        <button type="button" class="btn btn-sm text-danger p-0 border-0 shadow-none btn-mobile-standard" style="font-size: 0.82rem;" onclick="removeConcepto(${idx})" title="Quitar concepto"><i class="bi bi-trash"></i></button>
                    </div>
                    <div class="d-flex justify-content-between align-items-center mt-1">
                        ${subtexto}
                        <div class="d-flex align-items-center gap-1.5 ms-auto">
                            <button type="button" class="btn btn-sm btn-white border rounded-circle p-0 d-inline-flex align-items-center justify-content-center" style="width:22px; height:22px; line-height:1; font-size: 0.68rem;" onclick="updateCantidad(${idx}, -1)">-</button>
                            <span class="fw-bold px-1" style="font-size: 0.73rem; color: #0f172a;">${item.cantidad}</span>
                            <button type="button" class="btn btn-sm btn-white border rounded-circle p-0 d-inline-flex align-items-center justify-content-center" style="width:22px; height:22px; line-height:1; font-size: 0.68rem;" onclick="updateCantidad(${idx}, 1)">+</button>
                            ${badgePrecio}
                        </div>
                    </div>
                </div>
            `;
        });
        
        cMain.html(html);
        
        let iva = 0;
        if ($('#chkIva').length && $('#chkIva').is(':checked')) {
            iva = totalCobrar * 0.16;
        }
        
        let totalIvaText = iva > 0 ? formatCurrency(iva) : '$0.00';
        $('#taxAmountText').text(totalIvaText);
        
        let totalFmt = formatCurrency(totalCobrar + iva);
        $('#cartTotalText').text(totalFmt);
    }
    
    async function irAlPaso2() {
        // Obsoleto en la nueva UI, ya no hay scrolling
    }
    
    function evaluarVisibilidadMedico() {
        onConceptoDepartamentoChange();
    }

    $(document).ready(function() {
        $('#selConceptoRecibo').on('change', onConceptoDepartamentoChange);
    });

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
        let conceptoVal = $('#selConceptoRecibo').val() || '';
        let requiereMedico = (String(conceptoVal) === '1');
        
        if (!id_paciente) {
            return Swal.fire('Atención', 'Debes seleccionar un Paciente o registrarlo previamente.', 'warning');
        }
        if ($('#selConceptoRecibo').length && !$('#selConceptoRecibo').val()) {
            return Swal.fire('Atención', 'Debes seleccionar el Concepto del Recibo (Departamento).', 'warning');
        }
        if (requiereMedico && !id_medico) {
            return Swal.fire('Atención', 'Debes seleccionar la Especialidad y el Médico responsable.', 'warning');
        }
        if (cartItems.length === 0) {
            return Swal.fire('Atención', 'Agrega al menos un concepto a cobrar en el carrito.', 'warning');
        }
        
        let totalCobro = 0;
        let isEstado = (tipo === 'estado');
        cartItems.forEach(it => {
            if (isEstado) {
                let pp = (it.precio_paciente !== undefined) ? it.precio_paciente : (it.cubierto_convenio ? 0 : it.precio);
                totalCobro += (pp * (it.cantidad || 1));
            } else {
                totalCobro += ((it.precio || 0) * (it.cantidad || 1));
            }
        });

        let iva = 0;
        if ($('#chkIva').length && $('#chkIva').is(':checked') && totalCobro > 0) {
            iva = totalCobro * 0.16;
            totalCobro += iva;
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
            let isCubierto = isEstado && (it.cubierto_convenio || it.precio_paciente === 0);
            let s = isCubierto ? 0 : ((it.precio_paciente !== undefined ? it.precio_paciente : it.precio) * it.cantidad);
            let subtotalHtml = isCubierto ?
                `<span style="background:#e0f2fe; color:#0369a1; padding:2px 6px; border-radius:4px; font-size:10px; font-weight:bold; border:1px solid #bae6fd;">[Cubierto por Convenio]</span>` :
                formatCurrency(s);
            draftHtml += `<tr><td style="padding:8px; border-bottom:1px solid #e2e8f0;">${escapeHtml(it.nombre)}</td><td style="padding:8px; border-bottom:1px solid #e2e8f0; text-align:center;">${escapeHtml(it.cantidad)}</td><td style="padding:8px; border-bottom:1px solid #e2e8f0; text-align:right;">${subtotalHtml}</td></tr>`;
        });
        if (iva > 0) {
            draftHtml += `<tr><td colspan="2" style="padding:8px;text-align:right;font-size:14px;color:#666;">Tax (IVA 16%):</td><td style="padding:8px;text-align:right;font-size:14px;color:#666;">${formatCurrency(iva)}</td></tr>`;
        }
        let totalDisplayHtml = (isEstado && totalCobro === 0) ?
            `<span style="background:#e0f2fe; color:#0369a1; padding:4px 8px; border-radius:4px; font-size:12px; font-weight:bold; border:1px solid #bae6fd;">[Cubierto por Convenio]</span>` :
            `<span style="color:#10b981;">${formatCurrency(totalCobro)}</span>`;
        draftHtml += `<tr><td colspan="2" style="padding:8px;text-align:right;font-weight:bold;font-size:16px;">TOTAL PAGADO:</td><td style="padding:8px;text-align:right;font-weight:bold;font-size:16px;">${totalDisplayHtml}</td></tr>`;
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
        const conceptoVal = $('#selConceptoRecibo').val() || '';
        const requiereMedico = (String(conceptoVal) === '1');

        if (requiereMedico && !id_medico) {
            return Swal.fire('Atención', 'Debes seleccionar la Especialidad y el Médico responsable.', 'warning');
        }

        // Si es paciente de Estado y el carrito está vacío, agregar automáticamente la consulta de convenio
        if (tipo === 'estado' && cartItems.length === 0 && requiereMedico) {
            let medNombre = $('#selMedico option:selected').text() || 'MÉDICO GENERAL';
            cartItems.push({
                id: 'CONS-' + (id_medico || 'GEN'),
                nombre: 'CONSULTA MÉDICA - ' + medNombre,
                precio: 0,
                precio_paciente: 0,
                cubierto_convenio: 1,
                cantidad: 1
            });
        }

        let totalCobroVentanilla = 0;
        cartItems.forEach(it => {
            if (tipo === 'estado') {
                if (!it.cubierto_convenio && it.precio_paciente > 0) {
                    totalCobroVentanilla += (it.precio_paciente * (it.cantidad || 1));
                }
            } else {
                totalCobroVentanilla += ((it.precio || 0) * (it.cantidad || 1));
            }
        });

        let con_iva = 0;
        if ($('#chkIva').length && $('#chkIva').is(':checked') && totalCobroVentanilla > 0) {
            totalCobroVentanilla += (totalCobroVentanilla * 0.16);
            con_iva = 1;
        }
        
        Swal.fire({ toast: true, position: 'top-end', icon: 'info', title: 'Emitiendo recibo, un momento...', showConfirmButton: false, timer: 2000 });
        
        try {
            const form = new URLSearchParams();
            form.append('id_paciente', id_paciente);
            form.append('nombre_paciente_empleado', name_paciente);
            form.append('id_medico', id_medico);

            let medNombreExacto = '';
            if ($('#selMedico option:selected').length && $('#selMedico').val()) {
                medNombreExacto = $('#selMedico option:selected').text();
                if (medNombreExacto.includes(' - ')) {
                    medNombreExacto = medNombreExacto.split(' - ')[1].trim();
                }
                medNombreExacto = medNombreExacto.replace(/\s*\(.*?\)\s*$/, '').trim();
            }
            form.append('nombre_medico', medNombreExacto);

            form.append('caja_items_json', JSON.stringify(cartItems));
            form.append('caja_metodo_pago', metodo);
            form.append('caja_monto_abono', totalCobroVentanilla);
            form.append('caja_con_iva', con_iva);
            if ($('#selConceptoRecibo').length) {
                form.append('caja_concepto', $('#selConceptoRecibo option:selected').text());
            }
            
            console.log("Enviando petición a guardar_recibo_rapido.pl con datos:", Object.fromEntries(form.entries()));
            
            const req = await fetch('../api/guardar_recibo_rapido.pl', {
                method: 'POST',
                body: form
            });
            const res = await req.json();
            console.log("Respuesta del servidor:", res);
            
            if (res.ok) {
                Swal.fire({
                    icon: 'success',
                    title: '¡Recibo Emitido!',
                    text: 'El ingreso ha sido registrado exitosamente en caja.',
                    confirmButtonText: 'Abrir PDF y Volver'
                }).then(() => {
                    $('#modalReciboPrevio').modal('hide');
                    const ticketUrl = '../api/imprimir_recibo_' + (pacienteTipoActual === 'estado' ? 'publico' : 'caja') + '.pl?id_consulta=' + encodeURIComponent(res.folio);
                    window.open(ticketUrl, '_blank');
                    window.location.href = 'generar_recibo.pl';
                });
            } else {
                Swal.fire('Error', res.error || res.msg || 'No se pudo emitir el recibo.', 'error');
            }
        } catch (e) {
            console.error("Excepción al emitir recibo:", e);
            Swal.fire('Error', 'Hubo un problema de conexión. Revisa la consola para más detalles.', 'error');
        }
    }
</script>
JS

utils::sub_sidebar::render_sidebar_footer();

print <<"HTML";
<!-- MODAL CONCEPTOS DEL RECIBO -->
<div class="modal fade" id="modalConceptosRecibo" tabindex="-1" aria-labelledby="modalConceptosReciboTitle" aria-hidden="true" style="z-index: 108000 !important;">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content overflow-hidden border-0 shadow-lg rounded-4">
            <div class="modal-header border-0 pb-3 text-white" style="background: var(--md-blue-deep, #0A2A66);">
                <h5 class="modal-title fw-bold text-white m-0" id="modalConceptosReciboTitle">
                    <i class="bi bi-cart-plus me-2" style="color: var(--md-teal-clinical, #0D9488);"></i>Conceptos del Recibo
                </h5>
                <button type="button" class="btn-close btn-close-white shadow-none" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-3" style="background: #f8fafc;">
                <div class="row g-3">
                    <!-- Columna Izquierda: Catálogo -->
                    <div class="col-lg-7">
                        <div class="card border-0 shadow-sm mb-2 rounded-3">
                            <div class="card-body p-3">
                                <label class="fw-bold small text-muted text-uppercase mb-2 d-block">Entrada Manual</label>
                                <div class="input-group input-group-sm">
                                    <input type="text" id="reciboManualNombre" class="form-control" placeholder="Concepto (ej. Consulta General)">
                                    <span class="input-group-text">\$</span>
                                    <input type="number" id="reciboManualPrecio" class="form-control" style="max-width: 90px;" placeholder="0.00" step="0.01" min="0">
                                    <button type="button" class="btn text-white px-3 fw-bold rounded-2 shadow-sm" style="background: var(--md-blue-deep, #0A2A66);" onclick="agregarItemManualRecibo()"><i class="bi bi-plus-lg"></i></button>
                                </div>
                            </div>
                        </div>
                        <div class="row g-2 mb-2">
                            <div class="col-6">
                                <select id="reciboSelDep" class="form-select form-select-sm border-0 shadow-sm rounded-pill" onchange="_onDepChangeRecibo()">
                                    <option value="">Todos los Departamentos</option>
                                </select>
                            </div>
                            <div class="col-6">
                                <select id="reciboSelCat" class="form-select form-select-sm border-0 shadow-sm rounded-pill" onchange="_filtrarCatalogoRecibo()">
                                    <option value="">Todas las Categorías</option>
                                </select>
                            </div>
                        </div>
                        <div class="position-relative mb-2">
                            <i class="bi bi-search position-absolute top-50 start-0 translate-middle-y ms-3 text-muted small"></i>
                            <input type="text" id="reciboBuscador" class="form-control form-control-sm ps-5 py-2 rounded-pill shadow-sm border-0" placeholder="Buscar en catálogo..." oninput="_filtrarCatalogoRecibo()">
                        </div>
                        <div class="table-responsive border rounded-3 bg-white shadow-sm" style="max-height: 220px; overflow-y: auto;">
                            <table class="table table-hover table-sm align-middle mb-0">
                                <thead class="table-light sticky-top">
                                    <tr>
                                        <th class="ps-3 py-2 text-uppercase text-muted small fw-bold">Concepto</th>
                                        <th class="text-end py-2 text-uppercase text-muted small fw-bold">Precio</th>
                                        <th style="width: 50px;"></th>
                                    </tr>
                                </thead>
                                <tbody id="reciboTablaCatalogo"></tbody>
                            </table>
                        </div>
                    </div>
                    <!-- Columna Derecha: Carrito en el Modal -->
                    <div class="col-lg-5">
                        <div class="card border-0 shadow-sm h-100 d-flex flex-column rounded-3">
                            <div class="card-body p-3 d-flex flex-column">
                                <h6 class="fw-bold mb-2" style="color: var(--md-blue-deep, #0A2A66);">
                                    <i class="bi bi-cart3 me-1" style="color: var(--md-teal-clinical, #0D9488);"></i>Conceptos del Recibo
                                </h6>
                                <div id="reciboListaCarritoModal" class="flex-grow-1 overflow-auto mb-2 pe-1" style="max-height: 220px;"></div>
                                <div class="p-3 bg-light rounded-3 border shadow-sm mt-auto">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="small fw-bold text-muted">TOTAL</span>
                                        <span class="h4 fw-bold m-0" style="color: var(--md-blue-deep, #0A2A66);" id="reciboTotalCarritoModal">\$0.00</span>
                                    </div>
                                    <button type="button" id="btnGuardarConceptosRecibo" class="btn text-white btn-sm w-100 py-2.5 fw-bold rounded-3 shadow-sm" style="background: var(--md-blue-deep, #0A2A66);" onclick="guardarConceptosModalRecibo()">
                                        <i class="bi bi-check2-circle me-1"></i> GUARDAR CONCEPTOS
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

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
