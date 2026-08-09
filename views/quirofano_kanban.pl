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
my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_empresa = $sd->{id_empresa} || '';

# Restringir
if ($role !~ /Medico|Administrador|Enfermeria/i) {
    print $q->redirect('inicial.pl');
    exit;
}

# Cargar Médicos y Anestesiólogos para el modal
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '\|');
my @medicos = ();
foreach my $r (@$regs) {
    next unless scalar(@$r) >= 11;
    my $rol_u = $r->[3];
    my $org_u = $r->[9];
    if (($rol_u eq 'Medico' || $rol_u =~ /Especialista/i) && ($org_u eq $id_empresa || $role eq 'Administrador Global')) {
        push @medicos, { id => $r->[1], nombre => $r->[2] };
    }
}
my $medicos_options = "<option value=''>-- Seleccione --</option>";
foreach my $m (@medicos) {
    $medicos_options .= "<option value='$m->{id}'>$m->{nombre}</option>";
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    titulo => 'Tablero de Quirófano (Kanban)',
    role => $role,
    usuario => $usuario
);

print <<"HTML";
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme\@1.3.0/dist/select2-bootstrap-5-theme.min.css" />
<script src="https://cdn.jsdelivr.net/npm/sortablejs\@latest/Sortable.min.js"></script>

<style>
    /* Estilos Kanban */
    .kanban-board {
        display: flex;
        overflow-x: auto;
        gap: 1rem;
        padding-bottom: 1rem;
        min-height: calc(100vh - 200px);
    }
    .kanban-col {
        background: #f8fafc;
        border-radius: 8px;
        min-width: 320px;
        max-width: 320px;
        display: flex;
        flex-direction: column;
        border: 1px solid #e2e8f0;
    }
    .kanban-header {
        padding: 1rem;
        font-weight: 700;
        border-bottom: 2px solid;
        border-radius: 8px 8px 0 0;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .kanban-body {
        padding: 0.75rem;
        flex: 1;
        overflow-y: auto;
        min-height: 150px;
    }
    .kanban-card {
        background: #fff;
        border-radius: 6px;
        padding: 1rem;
        margin-bottom: 0.75rem;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        border: 1px solid #e2e8f0;
        cursor: grab;
        transition: transform 0.2s, box-shadow 0.2s;
    }
    .kanban-card:active { cursor: grabbing; }
    .kanban-card:hover { box-shadow: 0 4px 6px rgba(0,0,0,0.1); transform: translateY(-2px); }
    .sortable-ghost { opacity: 0.4; background: #e2e8f0; }
    
    /* Colores por columna */
    .col-programada .kanban-header { border-color: #94a3b8; background: #f1f5f9; color: #475569; }
    .col-preop .kanban-header { border-color: #f59e0b; background: #fffbeb; color: #b45309; }
    .col-quirofano .kanban-header { border-color: #ef4444; background: #fef2f2; color: #b91c1c; }
    .col-recuperacion .kanban-header { border-color: #3b82f6; background: #eff6ff; color: #1d4ed8; }
    .col-alta .kanban-header { border-color: #10b981; background: #ecfdf5; color: #047857; }
</style>

<main class="container-fluid pt-3 px-4 pb-5 animate__animated animate__fadeIn">
    
    <div class="d-flex justify-content-between align-items-center mb-4">
        <div>
            <h4 class="fw-bold mb-1 text-primary"><i class="bi bi-heart-pulse-fill me-2"></i>Tablero de Quirófano</h4>
            <p class="text-muted small mb-0">Gestión de flujo de pacientes quirúrgicos (Kanban)</p>
        </div>
        <div class="d-flex gap-2">
            <input type="date" id="filtroFecha" class="form-control form-control-sm" style="width: 150px;">
            <button class="btn btn-sm btn-primary shadow-sm" onclick="\$('#modalNuevaCirugia').modal('show')">
                <i class="bi bi-plus-circle me-1"></i> Agendar Cirugía
            </button>
        </div>
    </div>
    
    <div class="kanban-board">
        
        <!-- PROGRAMADA -->
        <div class="kanban-col col-programada">
            <div class="kanban-header">
                <span>Programada</span>
                <span class="badge bg-secondary rounded-pill" id="cnt-Programada">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Programada" data-estado="Programada"></div>
        </div>
        
        <!-- PRE-OPERATORIO -->
        <div class="kanban-col col-preop">
            <div class="kanban-header">
                <span>Pre-Operatorio</span>
                <span class="badge bg-warning text-dark rounded-pill" id="cnt-Pre-Operatorio">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Pre-Operatorio" data-estado="Pre-Operatorio"></div>
        </div>
        
        <!-- EN QUIRÓFANO -->
        <div class="kanban-col col-quirofano">
            <div class="kanban-header">
                <span><i class="bi bi-heart-pulse-fill me-1"></i> En Quirófano</span>
                <span class="badge bg-danger rounded-pill" id="cnt-En Quirófano">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-En Quirófano" data-estado="En Quirófano"></div>
        </div>
        
        <!-- RECUPERACIÓN -->
        <div class="kanban-col col-recuperacion">
            <div class="kanban-header">
                <span>Recuperación (UCPA)</span>
                <span class="badge bg-primary rounded-pill" id="cnt-Recuperación">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Recuperación" data-estado="Recuperación"></div>
        </div>
        
        <!-- ALTA -->
        <div class="kanban-col col-alta">
            <div class="kanban-header">
                <span>Alta / Traslado</span>
                <span class="badge bg-success rounded-pill" id="cnt-Alta">0</span>
            </div>
            <div class="kanban-body sortable-list" id="list-Alta" data-estado="Alta"></div>
        </div>
        
    </div>

</main>

<!-- Modal Nueva Cirugía -->
<div class="modal fade" id="modalNuevaCirugia" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-lg modal-dialog-centered">
    <div class="modal-content border-0 shadow">
      <div class="modal-header bg-primary text-white border-0">
        <h5 class="modal-title fw-bold"><i class="bi bi-calendar-plus me-2"></i>Agendar Procedimiento Quirúrgico</h5>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body bg-light">
        <form id="frmNuevaCirugia" onsubmit="return false;">
            
            <div class="row g-3 mb-3">
                <div class="col-md-12">
                    <label class="form-label fw-bold small text-muted">Paciente <span class="text-danger">*</span></label>
                    <select id="selPaciente" name="id_paciente" class="form-select" style="width:100%;"></select>
                </div>
            </div>
            
            <div class="row g-3 mb-3">
                <div class="col-md-8">
                    <label class="form-label fw-bold small text-muted">Procedimiento / Cirugía <span class="text-danger">*</span></label>
                    <input type="text" id="iptProcedimiento" name="procedimiento" class="form-control" placeholder="Ej. Apendicectomía Laparoscópica" required>
                </div>
                <div class="col-md-4">
                    <label class="form-label fw-bold small text-muted">Sala / Quirófano</label>
                    <input type="text" id="iptSala" name="sala" class="form-control" placeholder="Ej. Sala 1">
                </div>
            </div>
            
            <div class="row g-3 mb-3">
                <div class="col-md-6">
                    <label class="form-label fw-bold small text-muted">Cirujano Responsable <span class="text-danger">*</span></label>
                    <select id="selMedico" name="id_medico" class="form-select" required>
                        $medicos_options
                    </select>
                </div>
                <div class="col-md-6">
                    <label class="form-label fw-bold small text-muted">Anestesiólogo (Opcional)</label>
                    <select id="selAnestesio" name="id_anestesiologo" class="form-select">
                        $medicos_options
                    </select>
                </div>
            </div>
            
            <div class="row g-3 mb-3">
                <div class="col-md-6">
                    <label class="form-label fw-bold small text-muted">Fecha Programada <span class="text-danger">*</span></label>
                    <input type="date" id="iptFecha" name="fecha_programada" class="form-control" required>
                </div>
                <div class="col-md-6">
                    <label class="form-label fw-bold small text-muted">Hora Programada <span class="text-danger">*</span></label>
                    <input type="time" id="iptHora" name="hora_programada" class="form-control" required>
                </div>
            </div>
            
            <div class="mb-3">
                <label class="form-label fw-bold small text-muted">Notas Adicionales</label>
                <textarea id="iptNotas" name="notas" class="form-control" rows="2" placeholder="Requerimientos de sangre, alergias específicas para quirófano, etc."></textarea>
            </div>
            
        </form>
      </div>
      <div class="modal-footer border-0">
        <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancelar</button>
        <button type="button" class="btn btn-primary shadow-sm" onclick="guardarCirugia()">Guardar en Agenda</button>
      </div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/js/select2.min.js"></script>
<script>
    \$(document).ready(function() {
        // Init Filtro de Fecha a HOY
        const tzoffset = (new Date()).getTimezoneOffset() * 60000;
        const localISOTime = (new Date(Date.now() - tzoffset)).toISOString().slice(0, 10);
        \$('#filtroFecha').val(localISOTime);
        \$('#iptFecha').val(localISOTime);
        
        \$('#filtroFecha').on('change', function() { cargarTablero(); });
        
        // Select2 Pacientes
        \$('#selPaciente').select2({
            theme: 'bootstrap-5',
            dropdownParent: \$('#modalNuevaCirugia'),
            placeholder: '🔍 Buscar Paciente...',
            minimumInputLength: 2,
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
        
        initSortable();
        cargarTablero();
    });
    
    function initSortable() {
        const lists = document.querySelectorAll('.sortable-list');
        lists.forEach(list => {
            new Sortable(list, {
                group: 'kanban', // set both lists to same group
                animation: 150,
                ghostClass: 'sortable-ghost',
                onEnd: function (evt) {
                    const itemEl = evt.item;  // dragged HTMLElement
                    const toList = evt.to;    // target list
                    const idCirugia = itemEl.getAttribute('data-id');
                    const nuevoEstado = toList.getAttribute('data-estado');
                    
                    if (evt.from !== toList) {
                        actualizarEstadoCirugia(idCirugia, nuevoEstado);
                        actualizarContadores();
                    }
                },
            });
        });
    }
    
    async function cargarTablero() {
        const fecha = \$('#filtroFecha').val();
        
        \$('#list-Programada').empty();
        \$('#list-Pre-Operatorio').empty();
        \$('#list-En\\ Quirófano').empty();
        \$('#list-Recuperación').empty();
        \$('#list-Alta').empty();
        
        try {
            const req = await fetch('../api/quirofano_crud.pl?action=read&fecha=' + fecha);
            const data = await req.json();
            
            data.forEach(c => {
                const anestesiaHtml = c.nombre_anestesio ? `<div class="small mt-1"><i class="bi bi-lungs text-info"></i> Anest: \${c.nombre_anestesio}</div>` : '';
                const salaHtml = c.sala ? `<span class="badge bg-light text-dark border">\${c.sala}</span>` : '';
                
                const card = `
                    <div class="kanban-card" data-id="\${c.id_cirugia}">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <span class="badge bg-primary rounded-pill"><i class="bi bi-clock me-1"></i> \${c.hora}</span>
                            \${salaHtml}
                        </div>
                        <h6 class="fw-bold mb-1 text-dark">\${c.nombre_paciente}</h6>
                        <div class="text-primary small fw-bold mb-2">\${c.procedimiento}</div>
                        
                        <div class="small text-muted">
                            <div><i class="bi bi-person-badge"></i> Cx: \${c.nombre_medico}</div>
                            \${anestesiaHtml}
                        </div>
                    </div>
                `;
                
                let targetId = 'list-' + c.estado;
                const el = document.getElementById(targetId);
                if(el) {
                    el.innerHTML += card;
                } else {
                    console.log("No column found for state: " + c.estado);
                }
            });
            
            actualizarContadores();
            
        } catch (e) {
            console.error(e);
            CrystalToast.fire({icon: 'error', title: 'Error al cargar tablero'});
        }
    }
    
    function actualizarContadores() {
        const columns = ['Programada', 'Pre-Operatorio', 'En Quirófano', 'Recuperación', 'Alta'];
        columns.forEach(col => {
            const cnt = document.getElementById('list-' + col).children.length;
            document.getElementById('cnt-' + col).innerText = cnt;
        });
    }
    
    async function actualizarEstadoCirugia(id, estado) {
        try {
            const f = new URLSearchParams();
            f.append('action', 'update_status');
            f.append('id_cirugia', id);
            f.append('estado', estado);
            
            const req = await fetch('../api/quirofano_crud.pl', { method: 'POST', body: f });
            const res = await req.json();
            
            if(!res.ok) {
                CrystalToast.fire({icon: 'error', title: res.msg});
                cargarTablero(); // revert visual change
            } else {
                CrystalToast.fire({icon: 'success', title: 'Estado Actualizado'});
            }
        } catch(e) {
            CrystalToast.fire({icon: 'error', title: 'Falla de red al actualizar estado'});
            cargarTablero(); // revert visual change
        }
    }
    
    async function guardarCirugia() {
        const frm = document.getElementById('frmNuevaCirugia');
        if (!frm.checkValidity()) {
            frm.reportValidity();
            return;
        }
        
        const formData = new URLSearchParams(new FormData(frm));
        formData.append('action', 'create');
        
        try {
            const req = await fetch('../api/quirofano_crud.pl', { method: 'POST', body: formData });
            const res = await req.json();
            
            if (res.ok) {
                Swal.fire('Agendado', 'Cirugía guardada correctamente', 'success');
                \$('#modalNuevaCirugia').modal('hide');
                frm.reset();
                \$('#selPaciente').val(null).trigger('change');
                \$('#iptFecha').val(\$('#filtroFecha').val()); // reset to selected filter
                
                cargarTablero();
            } else {
                Swal.fire('Error', res.msg, 'error');
            }
        } catch (e) {
            Swal.fire('Error', 'Falla de red', 'error');
        }
    }
</script>

HTML

render_bottom_nav('hospital');
print "</body></html>\n";
1;
