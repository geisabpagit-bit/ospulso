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

# Restringir a roles permitidos (Recepcion, Medicos, Admins)
if ($role !~ /Recepcionista|Medico|Administrador/i) {
    print $q->redirect('inicial.pl');
    exit;
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
        if ($biz_id eq $id_empresa && $key eq 'CAPACIDAD') {
            $capacidades{$val} = 1;
        }
    }
    close($cf);
}
my $has_pacientes_estado = $capacidades{'Pacientes del Estado'} ? 1 : 0;

# 2. Cargar lista de médicos de la organización para el selector obligatorio
my $archivo_usuarios = File::Spec->catfile($dat_dir, 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '\|');
my @medicos = ();
foreach my $r (@$regs) {
    next unless scalar(@$r) >= 11;
    my $rol_u = $r->[3];
    my $org_u = $r->[9];
    if ($rol_u eq 'Medico' && ($org_u eq $id_empresa || $role eq 'Administrador Global')) {
        push @medicos, { id => $r->[1], nombre => $r->[2] };
    }
}

# 3. Render HTML
print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    titulo => 'Caja Rápida',
    role => $role,
    usuario => $usuario,
    hide_search => 1
);

my $medicos_options = "<option value=''>-- Selecciona el Médico que atiende --</option>";
foreach my $m (@medicos) {
    my $sel = ($id_medico eq $m->{id}) ? "selected" : "";
    $medicos_options .= "<option value='$m->{id}' $sel>$m->{nombre}</option>";
}

print <<"HTML";
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme\@1.3.0/dist/select2-bootstrap-5-theme.min.css" />

<style>
    .wizard-step { display: none; }
    .wizard-step.active { display: block; animation: fadeIn 0.4s ease-in-out; }
    \@keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
    .cart-item { border-bottom: 1px solid #e2e8f0; padding: 0.75rem 0; }
    .cart-item:last-child { border-bottom: none; }
</style>

<main class="container-fluid pt-3 px-3 pb-5 animate__animated animate__fadeIn">
    
    <div class="row justify-content-center">
        <div class="col-12 col-lg-8">
            <div class="card shadow-sm border-0 rounded-4">
                <div class="card-header bg-white border-0 pt-4 pb-0">
                    <h5 class="fw-bold mb-0 text-primary"><i class="bi bi-receipt-cutoff me-2"></i>Caja Rápida - Recibo Independiente</h5>
                    <p class="text-muted small">Genera comprobantes de pago sin necesidad de una cita programada.</p>
                </div>
                
                <div class="card-body">
                    
                    <!-- PASO 1: Captura -->
                    <div id="step1" class="wizard-step active">
                        <form id="frmCajaRapida" onsubmit="return false;">
                            
                            <!-- Búsqueda de Paciente -->
                            <div class="mb-4">
                                <label class="form-label fw-bold small text-muted">1. Selecciona o Busca al Paciente</label>
                                <select id="selPaciente" class="form-select" style="width:100%;"></select>
                                <div class="form-text">Si el paciente no existe, debe registrarse previamente en el Directorio.</div>
                            </div>
                            
                            <!-- Búsqueda de Empleados Municipio (Solo si tiene la capacidad) -->
HTML

if ($has_pacientes_estado) {
    print <<"HTML";
                            <div class="mb-4 p-3 bg-light rounded-3 border">
                                <label class="form-label fw-bold small text-primary"><i class="bi bi-bank me-2"></i>Búsqueda Avanzada: Pacientes del Estado (empleadosmun.dat)</label>
                                <select id="selPacienteEstado" class="form-select" style="width:100%;"></select>
                                <div class="form-text">Busca por Número de Empleado o Nombre. Se asignará la información al recibo actual.</div>
                            </div>
HTML
}

print <<"HTML";
                            <!-- Selección del Médico -->
                            <div class="mb-4">
                                <label class="form-label fw-bold small text-muted">2. Médico Responsable (Para honorarios/comisiones)</label>
                                <select id="selMedico" class="form-select fw-bold border-primary shadow-sm" required>
                                    $medicos_options
                                </select>
                            </div>
                            
                            <!-- Conceptos / Cotizador Express -->
                            <div class="mb-4">
                                <label class="form-label fw-bold small text-muted">3. Conceptos a Cobrar</label>
                                <div class="d-flex gap-2 mb-3">
                                    <input type="text" id="iptConcepto" class="form-control form-control-sm" placeholder="Ej. Curación menor">
                                    <input type="number" id="iptPrecio" class="form-control form-control-sm" placeholder="Monto \$" style="width: 120px;">
                                    <input type="number" id="iptCant" class="form-control form-control-sm" placeholder="Cant." value="1" style="width: 80px;">
                                    <button type="button" class="btn btn-sm btn-primary" onclick="addConcepto()"><i class="bi bi-plus-lg"></i> Agregar</button>
                                </div>
                                <div class="bg-light p-3 rounded-3 mb-2" id="cartContainer">
                                    <div class="text-center text-muted small py-2" id="cartEmpty">No hay conceptos agregados</div>
                                    <!-- Items will go here -->
                                </div>
                                <div class="d-flex justify-content-between align-items-center bg-dark text-white p-2 rounded-3 px-3">
                                    <span class="fw-bold">TOTAL:</span>
                                    <span class="fw-bold fs-5" id="cartTotalText">\$ 0.00</span>
                                </div>
                            </div>
                            
                            <!-- Método de Pago -->
                            <div class="mb-4">
                                <label class="form-label fw-bold small text-muted">4. Método de Pago</label>
                                <select id="selMetodoPago" class="form-select">
                                    <option value="Efectivo">Efectivo</option>
                                    <option value="Tarjeta de Debito">Tarjeta de Débito</option>
                                    <option value="Tarjeta de Credito">Tarjeta de Crédito</option>
                                    <option value="Transferencia">Transferencia (SPEI)</option>
                                    <option value="Convenio / Aseguradora">Convenio / Aseguradora</option>
                                    <option value="Cortesía">Cortesía (Sin cobro)</option>
                                </select>
                            </div>
                            
                            <hr class="my-4">
                            <div class="d-flex justify-content-end">
                                <button type="button" class="btn btn-primary px-4 fw-bold rounded-pill shadow-sm" onclick="irAlPaso2()">
                                    Siguiente: Vista Previa <i class="bi bi-arrow-right ms-1"></i>
                                </button>
                            </div>
                        </form>
                    </div>
                    
                    <!-- PASO 2: Vista Previa -->
                    <div id="step2" class="wizard-step">
                        <div class="alert alert-info border-0 shadow-sm d-flex align-items-center mb-4">
                            <i class="bi bi-info-circle-fill fs-4 me-3 text-info"></i>
                            <div>
                                <h6 class="fw-bold mb-1">Paso Final</h6>
                                <p class="mb-0 small">Revisa el comprobante. Una vez emitido, se registrará el ingreso en el sistema permanentemente.</p>
                            </div>
                        </div>
                        
                        <div class="border rounded-3 p-1 mb-4 bg-light" style="height: 400px;">
                            <iframe id="iframePreview" src="about:blank" style="width: 100%; height: 100%; border: none; background: #fff; border-radius: 6px;"></iframe>
                        </div>
                        
                        <div class="d-flex justify-content-between">
                            <button type="button" class="btn btn-light px-4 fw-bold rounded-pill" onclick="volverAlPaso1()">
                                <i class="bi bi-arrow-left me-1"></i> Volver
                            </button>
                            <button type="button" class="btn btn-success px-5 fw-bold rounded-pill shadow" onclick="emitirReciboFinal()">
                                <i class="bi bi-check2-circle me-1"></i> Emitir Recibo Oficial
                            </button>
                        </div>
                    </div>
                    
                </div>
            </div>
        </div>
    </div>
</main>

<script src="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/js/select2.min.js"></script>
<script>
    let cartItems = [];
    let tratamientoExpressGuardado = null; // Guardará el ID retornado tras guardar en step 2
    
    \$(document).ready(function() {
        // Init Pacientes Normal
        \$('#selPaciente').select2({
            theme: 'bootstrap-5',
            placeholder: '🔍 Buscar Paciente por Nombre o ID...',
            minimumInputLength: 2,
            language: { inputTooShort: function() { return "Ingresa al menos 2 letras..."; }, noResults: function() { return "No se encontraron pacientes."; } },
            ajax: {
                url: '../api/pacientes_buscar.pl',
                dataType: 'json',
                delay: 350,
                data: function (params) { return { q: params.term }; },
                processResults: function (data) {
                    return { results: data.map(function(item) { return { id: item.id, text: item.text }; }) };
                }
            }
        });
        
        // Init Empleados Municipio
        if (\$('#selPacienteEstado').length) {
            \$('#selPacienteEstado').select2({
                theme: 'bootstrap-5',
                placeholder: '🔍 Buscar Número de Empleado (Ej: 21)...',
                minimumInputLength: 1,
                ajax: {
                    url: '../api/buscar_empleadosmun.pl',
                    dataType: 'json',
                    delay: 350,
                    data: function (params) { return { q: params.term }; },
                    processResults: function (data) {
                        return { results: data };
                    }
                }
            });
        }
    });
    
    function addConcepto() {
        const nombre = \$('#iptConcepto').val().trim();
        const precio = parseFloat(\$('#iptPrecio').val());
        const cant = parseInt(\$('#iptCant').val());
        
        if (!nombre || isNaN(precio) || isNaN(cant) || cant <= 0) {
            Swal.fire('Error', 'Ingresa concepto, precio y cantidad válidos.', 'error');
            return;
        }
        
        cartItems.push({ id: Date.now(), nombre: nombre, precio: precio, cantidad: cant });
        \$('#iptConcepto').val('');
        \$('#iptPrecio').val('');
        \$('#iptCant').val('1');
        \$('#iptConcepto').focus();
        
        renderCart();
    }
    
    function removeConcepto(id) {
        cartItems = cartItems.filter(item => item.id !== id);
        renderCart();
    }
    
    function renderCart() {
        const c = \$('#cartContainer');
        if (cartItems.length === 0) {
            c.html('<div class="text-center text-muted small py-2" id="cartEmpty">No hay conceptos agregados</div>');
            \$('#cartTotalText').text('\$ 0.00');
            return;
        }
        
        let html = '';
        let total = 0;
        cartItems.forEach(item => {
            const sub = item.precio * item.cantidad;
            total += sub;
            html += `
                <div class="cart-item d-flex justify-content-between align-items-center">
                    <div>
                        <div class="fw-bold text-dark">\${item.nombre}</div>
                        <div class="text-muted small">\${item.cantidad} x \$ \${item.precio.toFixed(2)}</div>
                    </div>
                    <div class="d-flex align-items-center gap-3">
                        <span class="fw-bold text-success">\$ \${sub.toFixed(2)}</span>
                        <button type="button" class="btn btn-sm btn-light text-danger p-1" onclick="removeConcepto(\${item.id})"><i class="bi bi-trash"></i></button>
                    </div>
                </div>
            `;
        });
        
        c.html(html);
        \$('#cartTotalText').text('\$ ' + total.toFixed(2));
    }
    
    async function irAlPaso2() {
        let id_paciente = \$('#selPaciente').val();
        let name_paciente = \$('#selPaciente option:selected').text();
        
        // Si usaron Empleado Estado, usar ese ID
        if (\$('#selPacienteEstado').length && \$('#selPacienteEstado').val()) {
            const dataState = \$('#selPacienteEstado').select2('data')[0];
            // Para el backend marcaremos que viene del estado
            id_paciente = "EMP-" + dataState.id;
            name_paciente = dataState.nombre;
        }
        
        const id_medico = \$('#selMedico').val();
        
        if (!id_paciente) {
            return Swal.fire('Atención', 'Debes seleccionar un Paciente o registrarlo previamente.', 'warning');
        }
        if (!id_medico) {
            return Swal.fire('Atención', 'Debes seleccionar al Médico responsable.', 'warning');
        }
        if (cartItems.length === 0) {
            return Swal.fire('Atención', 'Agrega al menos un concepto a cobrar.', 'warning');
        }
        
        const total = cartItems.reduce((acc, it) => acc + (it.precio * it.cantidad), 0);
        const metodo = \$('#selMetodoPago').val();
        
        // Simular Iframe Previo de Recibo (Draft HTML)
        const fechaHtml = new Date().toLocaleDateString('es-MX', { year:'numeric', month:'short', day:'numeric' });
        let draftHtml = `
        <!DOCTYPE html><html><head><style>body { font-family: 'Inter', sans-serif; padding: 20px; color: #333; } .banner { background: #f59e0b; color: white; text-align: center; padding: 5px; font-weight: bold; font-size: 12px; margin-bottom: 20px; border-radius: 4px; }</style></head><body>
            <div class="banner">VISTA PREVIA DE RECIBO (BORRADOR)</div>
            <h2 style="margin:0 0 5px 0;">Recibo de Caja</h2>
            <p style="margin:0; color:#666;">Fecha: \${fechaHtml} | Método: \${metodo}</p>
            <p style="margin:15px 0; font-size:14px;"><strong>Paciente:</strong> \${name_paciente}<br><strong>Médico:</strong> \${$('#selMedico option:selected').text()}</p>
            <table style="width:100%; border-collapse:collapse; margin-top:20px; font-size:13px;">
                <tr style="background:#f1f5f9;"><th style="padding:8px;text-align:left;">Concepto</th><th style="padding:8px;text-align:center;">Cant.</th><th style="padding:8px;text-align:right;">Subtotal</th></tr>
        `;
        cartItems.forEach(it => {
            const s = it.precio * it.cantidad;
            draftHtml += `<tr><td style="padding:8px; border-bottom:1px solid #e2e8f0;">\${it.nombre}</td><td style="padding:8px; border-bottom:1px solid #e2e8f0; text-align:center;">\${it.cantidad}</td><td style="padding:8px; border-bottom:1px solid #e2e8f0; text-align:right;">\$ \${s.toFixed(2)}</td></tr>`;
        });
        draftHtml += `<tr><td colspan="2" style="padding:8px;text-align:right;font-weight:bold;font-size:16px;">TOTAL PAGADO:</td><td style="padding:8px;text-align:right;font-weight:bold;font-size:16px;color:#10b981;">\$ \${total.toFixed(2)}</td></tr>`;
        draftHtml += `</table></body></html>`;
        
        const doc = document.getElementById('iframePreview').contentWindow.document;
        doc.open(); doc.write(draftHtml); doc.close();
        
        \$('#step1').removeClass('active');
        \$('#step2').addClass('active');
    }
    
    function volverAlPaso1() {
        \$('#step2').removeClass('active');
        \$('#step1').addClass('active');
    }
    
    async function emitirReciboFinal() {
        let id_paciente = \$('#selPaciente').val();
        let name_paciente = \$('#selPaciente option:selected').text();
        
        if (\$('#selPacienteEstado').length && \$('#selPacienteEstado').val()) {
            const dataState = \$('#selPacienteEstado').select2('data')[0];
            id_paciente = "EMP-" + dataState.id;
            name_paciente = dataState.nombre;
        }
        
        const id_medico = \$('#selMedico').val();
        const metodo = \$('#selMetodoPago').val();
        const total = cartItems.reduce((acc, it) => acc + (it.precio * it.cantidad), 0);
        
        CrystalToast.fire({ icon: 'info', title: 'Emitiendo recibo, un momento...' });
        
        try {
            const form = new URLSearchParams();
            form.append('id_paciente', id_paciente);
            form.append('nombre_paciente_empleado', name_paciente);
            form.append('id_medico', id_medico);
            form.append('caja_items_json', JSON.stringify(cartItems));
            form.append('caja_metodo_pago', metodo);
            form.append('caja_monto_abono', total);
            
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
                    confirmButtonText: 'Abrir PDF'
                }).then(() => {
                    window.open('../api/imprimir_recibo_caja.pl?id_consulta=' + encodeURIComponent(res.id_tratamiento), '_blank');
                    // Reiniciar Wizard
                    cartItems = [];
                    renderCart();
                    \$('#selPaciente').val(null).trigger('change');
                    if (\$('#selPacienteEstado').length) \$('#selPacienteEstado').val(null).trigger('change');
                    volverAlPaso1();
                });
            } else {
                Swal.fire('Error', res.msg || 'No se pudo generar el recibo.', 'error');
            }
        } catch (e) {
            Swal.fire('Error', 'Falla de red.', 'error');
        }
    }
</script>
HTML

print "</main>\n";
render_bottom_nav('finanzas');
print "</body></html>\n";
1;
