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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};
my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_empresa = $sd->{id_empresa} || '';
my $id_usuario_sesion = $sd->{id_registro} // $sd->{id_medico} // '';

binmode STDOUT, ":utf8";

# Restringir según RBAC y Excepciones Activas por usuario
unless (utils::permisos_utils::tiene_permiso_modulo($id_empresa, $role, 'quirofano', 'R', $id_usuario_sesion)) {
    render_acceso_denegado(
        q => $q, usuario => $usuario, role => $role,
        mensaje => 'No cuenta con facultades para acceder al Tablero de Quirófano de la Organización.',
        rol_requerido => 'Facultad de Lectura (R) en Quirófano'
    );
    exit;
}

# Restringir según Capacidad SaaS de la Organización (Hospitalización)
my $has_hospitalizacion = 0;
my $found_hospitalizacion = 0;
my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line);
        if ($biz_id eq $id_empresa && $key eq 'MANEJA_HOSPITALIZACION') {
            $has_hospitalizacion = ($val eq '1') ? 1 : 0;
            $found_hospitalizacion = 1;
            last;
        }
    }
    close($cf);
}
# Fallback para organización matriz (0 o vacía) sin configuración explícita previa pero con CLUE
if (!$found_hospitalizacion && ($id_empresa eq '0' || $id_empresa eq '')) {
    my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
    if (-e $negocios_file && open(my $fn, '<:raw', $negocios_file)) {
        while(my $ln = <$fn>) {
            chomp($ln);
            my @f = split(/\|/, $ln, -1);
            my $row_id = $f[0] // '';
            $row_id =~ s/\x00//g;
            $row_id =~ s/^\s+|\s+$//g;
            my $c_val = $f[18] // '';
            $c_val =~ s/\x00//g;
            $c_val =~ s/^\s+|\s+$//g;
            if ($row_id eq '0' && length($c_val)) {
                $has_hospitalizacion = 1;
                last;
            }
        }
        close($fn);
    }
}

unless ($has_hospitalizacion) {
    render_acceso_denegado(
        q => $q, usuario => $usuario, role => $role,
        mensaje => 'La organización no cuenta con la capacidad de Hospitalización / Quirófano activa en su suscripción SaaS.',
        rol_requerido => 'Capacidad SaaS: Hospitalización'
    );
    exit;
}

# Cargar Médicos y Anestesiólogos para el modal
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '!');
my @medicos = ();
foreach my $r (@$regs) {
    next unless scalar(@$r) >= 7;
    my $m_id = $r->[0];
    my $m_nom = $r->[1];
    my $rol_u = $r->[5] // '';
    my $org_u = $r->[6] // '';
    if (($rol_u eq 'Medico' || $rol_u =~ /Especialista/i) && ($org_u eq $id_empresa || $role eq 'Administrador Global')) {
        push @medicos, { id => $m_id, nombre => $m_nom };
    }
}
my $medicos_options = "<option value=''>-- Seleccione --</option>";
foreach my $m (@medicos) {
    $medicos_options .= "<option value='$m->{id}'>$m->{nombre}</option>";
}
render_header(
    titulo => 'Tablero de Quirófano (Kanban)',
    role => $role,
    usuario => $usuario
);

print <<"HTML";
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2\@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme\@1.3.0/dist/select2-bootstrap-5-theme.min.css" />
<link rel="stylesheet" href="../css/sdm_mobile_standards.css" />
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

<main class="container-fluid container-mobile-flush pt-3 px-4 pb-5 animate__animated animate__fadeIn">
    
    <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-4">
        <div>
            <h4 class="fw-bold mb-1 text-primary"><i class="bi bi-heart-pulse-fill me-2"></i>Tablero de Quirófano</h4>
            <p class="text-muted small mb-0">Monitor de ejecución y flujo de pacientes quirúrgicos en tiempo real</p>
        </div>
        <div class="d-flex align-items-center gap-2">
            <span class="badge bg-white text-navy border py-2 px-3 shadow-sm rounded-3 fw-bold d-flex align-items-center">
                <i class="bi bi-clock-history text-primary me-2"></i>Monitoreo en Vivo: <span id="lblFechaHoy" class="ms-1.5 fw-bold text-primary"></span>
            </span>
            <a href="agenda_main.pl" class="btn btn-sm btn-outline-primary btn-mobile-standard shadow-sm d-flex align-items-center" title="Programar en la Agenda Central">
                <i class="bi bi-calendar3 me-1.5"></i> Agenda Central
            </a>
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
HTML

print <<'JS';
<script>
    $(document).ready(function() {
        const tzoffset = (new Date()).getTimezoneOffset() * 60000;
        const localISOTime = (new Date(Date.now() - tzoffset)).toISOString().slice(0, 10);
        const hoyTexto = new Date().toLocaleDateString('es-ES', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });
        $('#lblFechaHoy').text(hoyTexto.toUpperCase());
        
        initSortable();
        cargarTablero(localISOTime);
    });
    
    function initSortable() {
        const lists = document.querySelectorAll('.sortable-list');
        lists.forEach(list => {
            new Sortable(list, {
                group: 'kanban',
                animation: 150,
                ghostClass: 'sortable-ghost',
                onEnd: function (evt) {
                    const itemEl = evt.item;
                    const toList = evt.to;
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
    
    async function cargarTablero(fechaFiltro) {
        const tzoffset = (new Date()).getTimezoneOffset() * 60000;
        const fecha = fechaFiltro || (new Date(Date.now() - tzoffset)).toISOString().slice(0, 10);
        
        $('#list-Programada').empty();
        $('#list-Pre-Operatorio').empty();
        $('#list-En\\ Quirófano').empty();
        $('#list-Recuperación').empty();
        $('#list-Alta').empty();
        
        try {
            const req = await fetch('../api/quirofano_crud.pl?action=read&fecha=' + fecha);
            const data = await req.json();
            
            data.forEach(c => {
                const anestesiaHtml = c.nombre_anestesio ? `<div class="small mt-1"><i class="bi bi-lungs text-info"></i> Anest: ${c.nombre_anestesio}</div>` : '';
                const salaHtml = c.sala ? `<span class="badge bg-light text-dark border">${c.sala}</span>` : '';
                
                const card = `
                    <div class="kanban-card" data-id="${c.id_cirugia}">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <span class="badge bg-primary rounded-pill"><i class="bi bi-clock me-1"></i> ${c.hora}</span>
                            ${salaHtml}
                        </div>
                        <h6 class="fw-bold mb-1 text-dark">${c.nombre_paciente}</h6>
                        <div class="text-primary small fw-bold mb-2">${c.procedimiento}</div>
                        
                        <div class="small text-muted">
                            <div><i class="bi bi-person-badge"></i> Cx: ${c.nombre_medico}</div>
                            ${anestesiaHtml}
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
            const el = document.getElementById('list-' + col);
            const cnt = el ? el.children.length : 0;
            const badge = document.getElementById('cnt-' + col);
            if (badge) badge.innerText = cnt;
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
                cargarTablero();
            } else {
                CrystalToast.fire({icon: 'success', title: 'Estado Actualizado'});
            }
        } catch(e) {
            CrystalToast.fire({icon: 'error', title: 'Falla de red al actualizar estado'});
            cargarTablero();
        }
    }
</script>
JS

# Render Footer
render_bottom_nav('hospital');
print "</body></html>\n";
1;
