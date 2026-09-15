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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');

my $sd = check_session();
my $q  = $sd->{q};
my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_medico  = $sd->{id_medico} || '';
my $id_empresa = $sd->{id_empresa} || '';

binmode STDOUT, ":utf8";

unless ($sd->{session_ok} && $role =~ /Administrador/i) {
    print $q->redirect('inicial.pl');
    exit;
}

sub html_escape {
    my $s = shift // '';
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s =~ s/'/&#39;/g;
    return $s;
}

render_header(
    titulo => 'Matriz Dinámica de Permisos por Rol',
    role => $role,
    usuario => $usuario,
    hide_search => 1
);

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    id_empresa => $id_empresa,
    pagina_actual => 'usuarios'
);

print <<"HTML";
<link rel="stylesheet" href="../css/sdm_mobile_standards.css" />
<link rel="stylesheet" href="../css/ospulso_master_v2.css" />

<style>
    /* Estilos de alta densidad, scroll bidireccional y fuente muy pequeña */
    .table-permisos-sticky {
        position: relative;
        max-height: calc(100vh - 210px);
        overflow-x: auto;
        overflow-y: auto;
    }
    .table-permisos-sticky table {
        font-size: 0.68rem;
        font-weight: 400;
    }
    .table-permisos-sticky thead th {
        position: sticky;
        top: 0;
        z-index: 1020;
        background: #f8f9fa;
        font-weight: 500;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
    }
    .table-permisos-sticky .col-sticky-left {
        position: sticky;
        left: 0;
        z-index: 1010;
        background: #ffffff;
        box-shadow: 2px 0 4px rgba(0,0,0,0.05);
    }
    .table-permisos-sticky thead th.col-sticky-left {
        z-index: 1030;
        background: #f8f9fa;
    }
    .perm-badge-pill {
        user-select: none;
        cursor: pointer;
        transition: all 0.15s ease-in-out;
        font-size: 0.62rem;
        font-weight: 500;
        padding: 1px 4px;
        border-radius: 3px;
        display: inline-flex;
        align-items: center;
        gap: 2px;
    }
    .perm-badge-pill:hover {
        transform: translateY(-1px);
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    .badge-c { background-color: #e6f4ea; color: #137333; border: 1px solid #ceead6; }
    .badge-r { background-color: #e8f0fe; color: #1a73e8; border: 1px solid #d2e3fc; }
    .badge-u { background-color: #fef7e0; color: #b06000; border: 1px solid #feefc3; }
    .badge-d { background-color: #fce8e6; color: #c5221f; border: 1px solid #fad2cf; }

    .user-count-badge {
        font-size: 0.65rem;
        font-weight: 400;
        cursor: pointer;
        transition: all 0.2s ease;
    }
    .user-count-badge:hover {
        transform: scale(1.04);
    }
    .kpi-card-mini {
        background: rgba(255,255,255,0.9);
        border: 1px solid rgba(0,0,0,0.06);
        border-radius: 8px;
        padding: 6px 12px;
        font-size: 0.72rem;
    }
</style>

<main class="container-fluid container-mobile-flush py-2 px-2 px-md-3 animate__animated animate__fadeIn">
    <!-- Header principal de alta densidad -->
    <div class="card-medentia-aura p-2 p-md-3 rounded-3 shadow-sm border-0 mb-2">
        <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2 pb-2 border-bottom">
            <div class="d-flex align-items-center gap-2">
                <div class="bg-primary text-white rounded-2 p-1.5 d-flex align-items-center justify-content-center" style="width: 32px; height: 32px;">
                    <i class="bi bi-shield-lock-fill fs-6"></i>
                </div>
                <div>
                    <h6 class="m-0 text-primary lh-1" style="font-weight: 500;">Matriz Dinámica de Permisos por Rol</h6>
                    <span class="text-muted" style="font-size: 0.70rem;">Configuración de menú lateral y facultades CRUD (Crear, Leer, Actualizar, Borrar) por organización.</span>
                </div>
            </div>
            
            <div class="d-flex align-items-center gap-2">
                <a href="administracion_usuarios.pl" class="btn btn-outline-secondary btn-xs btn-mobile-standard rounded-2 px-2 py-1" style="font-size: 0.72rem;">
                    <i class="bi bi-people-fill me-1"></i> Ir a Usuarios
                </a>
                <button type="button" class="btn btn-outline-primary btn-xs btn-mobile-standard rounded-2 px-2 py-1" style="font-size: 0.72rem;" onclick="cargarMatrizPermisos()">
                    <i class="bi bi-arrow-clockwise me-1"></i> Recargar
                </button>
                <button type="button" class="btn btn-primary btn-xs text-white btn-mobile-standard rounded-2 px-2.5 py-1 shadow-sm" style="font-size: 0.72rem;" onclick="guardarMatrizPermisos()">
                    <i class="bi bi-check2-circle me-1"></i> Guardar Cambios
                </button>
            </div>
        </div>

        <!-- Resumen de Métricas KPI ultracompacto -->
        <div class="row g-2 mb-2" id="kpiBar">
            <div class="col-6 col-md-3">
                <div class="kpi-card-mini d-flex align-items-center justify-content-between">
                    <div>
                        <span class="text-muted d-block" style="font-size: 0.65rem;">Roles Activos</span>
                        <span class="fs-6 text-dark" id="kpiTotalRoles">0</span>
                    </div>
                    <i class="bi bi-person-badge text-teal fs-5"></i>
                </div>
            </div>
            <div class="col-6 col-md-3">
                <div class="kpi-card-mini d-flex align-items-center justify-content-between">
                    <div>
                        <span class="text-muted d-block" style="font-size: 0.65rem;">Módulos del Sistema</span>
                        <span class="fs-6 text-dark" id="kpiTotalModulos">0</span>
                    </div>
                    <i class="bi bi-grid-3x3-gap-fill text-primary fs-5"></i>
                </div>
            </div>
            <div class="col-6 col-md-3">
                <div class="kpi-card-mini d-flex align-items-center justify-content-between">
                    <div>
                        <span class="text-muted d-block" style="font-size: 0.65rem;">Personal Asignado</span>
                        <span class="fs-6 text-dark" id="kpiTotalUsuarios">0</span>
                    </div>
                    <i class="bi bi-people-fill text-indigo fs-5"></i>
                </div>
            </div>
            <div class="col-6 col-md-3">
                <div class="kpi-card-mini d-flex align-items-center justify-content-between">
                    <div class="w-100">
                        <span class="text-muted d-block" style="font-size: 0.65rem;">Buscador Rápido</span>
                        <input type="text" class="form-control form-control-sm py-0 px-1.5 mt-0.5 border" style="font-size: 0.68rem;" id="inputBuscarModulo" placeholder="Buscar módulo..." onkeyup="filtrarModulos()">
                    </div>
                </div>
            </div>
        </div>

        <!-- Estado de Carga -->
        <div id="loaderPermisos" class="text-center py-3">
            <div class="spinner-border spinner-border-sm text-primary" role="status"></div>
            <span class="text-muted small ms-2" style="font-size: 0.72rem;">Cargando matriz dinámica de permisos...</span>
        </div>

        <!-- Contenedor Matriz -->
        <div id="containerMatriz" style="display: none;">
            <div class="table-responsive border rounded-2 overflow-hidden shadow-sm bg-white mb-2 table-permisos-sticky">
                <table class="table table-bordered table-hover align-middle m-0 p-0" id="tablaPermisos">
                    <thead>
                        <tr id="trHeader" class="bg-light text-dark">
                            <th class="ps-3 py-1.5 col-sticky-left" style="min-width: 240px;">Módulo / Sección</th>
                        </tr>
                    </thead>
                    <tbody id="tbodyMatriz"></tbody>
                </table>
            </div>

            <!-- Leyenda Compacta -->
            <div class="bg-light border rounded-2 p-1.5 d-flex flex-wrap align-items-center justify-content-between gap-2" style="font-size: 0.68rem;">
                <div class="d-flex flex-wrap align-items-center gap-2">
                    <span class="text-dark me-1"><i class="bi bi-info-circle text-primary me-1"></i>Facultades:</span>
                    <span class="badge badge-c"><i class="bi bi-plus-circle"></i> C: Crear</span>
                    <span class="badge badge-r"><i class="bi bi-eye"></i> R: Leer (Menú)</span>
                    <span class="badge badge-u"><i class="bi bi-pencil-square"></i> U: Actualizar</span>
                    <span class="badge badge-d"><i class="bi bi-trash"></i> D: Borrar</span>
                </div>
                <div class="text-muted" style="font-size: 0.65rem;">
                    * Administrador Organización tiene protección contra auto-bloqueo en módulos clave.
                </div>
            </div>
        </div>
    </div>
</main>

<!-- Modal de Desglose de Usuarios por Rol -->
<div class="modal fade" id="modalUsuariosRol" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content border-0 shadow-lg rounded-3" style="font-size: 0.75rem;">
            <div class="modal-header bg-primary text-white py-2 px-3">
                <h6 class="modal-title" id="modalUsuariosRolTitulo" style="font-weight: 500;"><i class="bi bi-people-fill me-2"></i>Personal Asignado al Rol</h6>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-3">
                <p class="text-muted mb-2" style="font-size: 0.72rem;">Listado de colaboradores registrados con el rol <span id="modalRolNombre" class="text-dark"></span> en esta organización:</p>
                <div class="list-group list-group-flush border rounded-2 overflow-hidden" id="listadoUsuariosRol"></div>
            </div>
            <div class="modal-footer bg-light py-1.5 px-3 d-flex justify-content-between">
                <a href="administracion_usuarios.pl" class="btn btn-xs btn-outline-primary rounded-pill px-2.5" style="font-size: 0.72rem;">
                    <i class="bi bi-person-plus-fill me-1"></i> Asignar o Editar Usuarios
                </a>
                <button type="button" class="btn btn-xs btn-secondary rounded-pill px-2.5" style="font-size: 0.72rem;" data-bs-dismiss="modal">Cerrar</button>
            </div>
        </div>
    </div>
</div>
HTML

print <<'JS';
<script>
    let rawPermisosData = null;

    document.addEventListener('DOMContentLoaded', () => {
        const modalEl = document.getElementById('modalUsuariosRol');
        if (modalEl && modalEl.parentElement !== document.body) {
            document.body.appendChild(modalEl);
        }
        cargarMatrizPermisos();
    });

    async function cargarMatrizPermisos() {
        $('#loaderPermisos').show();
        $('#containerMatriz').hide();

        try {
            const res = await fetch('../api/gestion_permisos_roles_api.pl?accion=get_matrix').then(r => r.json());
            if (res.ok) {
                rawPermisosData = res;
                renderizarTablaMatriz(res);
                $('#loaderPermisos').hide();
                $('#containerMatriz').fadeIn();
            } else {
                Swal.fire('Error', res.msg || 'No se pudo cargar la matriz.', 'error');
            }
        } catch (e) {
            console.error("Error al cargar matriz:", e);
            Swal.fire('Error', 'Hubo un error de conexión al cargar la matriz de permisos.', 'error');
        }
    }

    function renderizarTablaMatriz(data) {
        const trHeader = document.getElementById('trHeader');
        const tbody = document.getElementById('tbodyMatriz');
        if (!trHeader || !tbody) return;

        const roles = data.roles || [];
        const modulos = data.modulos || [];
        const matriz = data.matriz || {};
        const conteoUsuarios = data.conteo_usuarios || {};

        // Actualizar KPIs
        $('#kpiTotalRoles').text(roles.length);
        $('#kpiTotalModulos').text(modulos.length);
        
        let totalUsuarios = 0;
        Object.values(conteoUsuarios).forEach(c => totalUsuarios += (parseInt(c) || 0));
        $('#kpiTotalUsuarios').text(totalUsuarios);

        trHeader.innerHTML = `
            <th class="ps-3 py-1.5 bg-light border-end col-sticky-left" style="min-width: 230px;">
                <div class="d-flex align-items-center justify-content-between">
                    <span class="text-dark" style="font-size: 0.68rem; font-weight: 500;"><i class="bi bi-grid-fill me-1 text-primary"></i> Módulo / Sección</span>
                </div>
            </th>
        `;

        roles.forEach(rol => {
            const numUsers = conteoUsuarios[rol] || 0;
            const th = document.createElement('th');
            th.className = 'text-center py-1 px-2 border-end bg-light';
            th.style.minWidth = '180px';
            th.innerHTML = `
                <div class="text-dark lh-sm text-truncate" style="font-size: 0.68rem; font-weight: 500;" title="${escapeHtml(rol)}">${escapeHtml(rol)}</div>
                <div class="d-flex align-items-center justify-content-center gap-1 my-0.5">
                    <button type="button" class="btn btn-xs btn-light border py-0 px-1.5 user-count-badge rounded-pill text-primary" style="font-size: 0.65rem;" onclick="verUsuariosRol('${escapeHtml(rol)}')">
                        <i class="bi bi-people-fill text-teal me-1"></i>${numUsers} usu.
                    </button>
                </div>
                <div class="d-flex justify-content-center gap-1" style="font-size: 0.62rem;">
                    <button type="button" class="btn btn-link p-0 text-decoration-none text-muted" onclick="marcarTodoRol('${escapeHtml(rol)}', true)">[Todos]</button>
                    <span class="text-muted">|</span>
                    <button type="button" class="btn btn-link p-0 text-decoration-none text-muted" onclick="marcarTodoRol('${escapeHtml(rol)}', false)">[Ninguno]</button>
                </div>
            `;
            trHeader.appendChild(th);
        });

        tbody.innerHTML = '';

        modulos.forEach(mod => {
            const tr = document.createElement('tr');
            tr.className = 'modulo-row';
            tr.setAttribute('data-mod-id', mod.id);
            tr.setAttribute('data-mod-nombre', mod.nombre.toLowerCase());

            let colModHtml = `
                <td class="ps-3 py-1 align-middle border-end bg-white col-sticky-left">
                    <div class="d-flex align-items-center justify-content-between">
                        <div class="d-flex align-items-center gap-1.5">
                            <i class="bi ${escapeHtml(mod.icono || 'bi-folder')} text-primary" style="font-size: 0.85rem;"></i>
                            <div>
                                <div class="text-dark lh-1" style="font-size: 0.68rem; font-weight: 400;">${escapeHtml(mod.nombre)}</div>
                                <code class="text-muted" style="font-size: 0.60rem;">id: ${escapeHtml(mod.id)}</code>
                            </div>
                        </div>
                        <div class="d-flex gap-1 ms-2" style="font-size: 0.62rem;">
                            <button type="button" class="btn btn-link p-0 text-decoration-none text-muted" onclick="marcarTodoModulo('${escapeHtml(mod.id)}', true)" title="Activar módulo para todos los roles">[Fila All]</button>
                            <span class="text-muted">|</span>
                            <button type="button" class="btn btn-link p-0 text-decoration-none text-muted" onclick="marcarTodoModulo('${escapeHtml(mod.id)}', false)" title="Desactivar módulo para todos los roles">[Fila Off]</button>
                        </div>
                    </div>
                </td>
            `;

            let colsRolesHtml = '';
            roles.forEach(rol => {
                const isAdmin = (rol === 'Administrador Organizacion' || rol === 'Administrador Global');
                const isCriticalAdminMod = isAdmin && (mod.id === 'usuarios' || mod.id === 'gestion_permisos' || mod.id === 'pacientes');

                const perm = (matriz[rol] && matriz[rol][mod.id]) ? matriz[rol][mod.id] : { C: 0, R: 0, U: 0, D: 0 };
                
                const cChecked = (isCriticalAdminMod || perm.C) ? 'checked' : '';
                const rChecked = (isCriticalAdminMod || perm.R) ? 'checked' : '';
                const uChecked = (isCriticalAdminMod || perm.U) ? 'checked' : '';
                const dChecked = (isCriticalAdminMod || perm.D) ? 'checked' : '';

                const disabledAttr = isCriticalAdminMod ? 'disabled' : '';

                colsRolesHtml += `
                    <td class="text-center align-middle py-1 px-1 border-end">
                        <div class="d-inline-flex flex-wrap justify-content-center gap-1 p-0.5 rounded-1 bg-light border">
                            <label class="perm-badge-pill badge-c" title="Crear / Registrar">
                                <span>C</span>
                                <input class="form-check-input m-0 perm-check" style="width:12px; height:12px;" type="checkbox" data-rol="${escapeHtml(rol)}" data-mod="${escapeHtml(mod.id)}" data-act="C" ${cChecked} ${disabledAttr}>
                            </label>
                            <label class="perm-badge-pill badge-r" title="Leer / Ver en Menú">
                                <span>R</span>
                                <input class="form-check-input m-0 perm-check" style="width:12px; height:12px;" type="checkbox" data-rol="${escapeHtml(rol)}" data-mod="${escapeHtml(mod.id)}" data-act="R" ${rChecked} ${disabledAttr}>
                            </label>
                            <label class="perm-badge-pill badge-u" title="Actualizar / Modificar">
                                <span>U</span>
                                <input class="form-check-input m-0 perm-check" style="width:12px; height:12px;" type="checkbox" data-rol="${escapeHtml(rol)}" data-mod="${escapeHtml(mod.id)}" data-act="U" ${uChecked} ${disabledAttr}>
                            </label>
                            <label class="perm-badge-pill badge-d" title="Borrar / Anular">
                                <span>D</span>
                                <input class="form-check-input m-0 perm-check" style="width:12px; height:12px;" type="checkbox" data-rol="${escapeHtml(rol)}" data-mod="${escapeHtml(mod.id)}" data-act="D" ${dChecked} ${disabledAttr}>
                            </label>
                        </div>
                    </td>
                `;
            });

            tr.innerHTML = colModHtml + colsRolesHtml;
            tbody.appendChild(tr);
        });
    }

    function filtrarModulos() {
        const query = ($('#inputBuscarModulo').val() || '').toLowerCase().trim();
        $('.modulo-row').each(function() {
            const nom = $(this).attr('data-mod-nombre') || '';
            const id  = $(this).attr('data-mod-id') || '';
            if (nom.includes(query) || id.includes(query)) {
                $(this).show();
            } else {
                $(this).hide();
            }
        });
    }

    function marcarTodoRol(rolName, estado) {
        $(`.perm-check[data-rol="${rolName}"]`).not(':disabled').prop('checked', estado);
    }

    function marcarTodoModulo(modId, estado) {
        $(`.perm-check[data-mod="${modId}"]`).not(':disabled').prop('checked', estado);
    }

    function verUsuariosRol(rolName) {
        if (!rawPermisosData || !rawPermisosData.usuarios_por_rol) return;
        const lista = rawPermisosData.usuarios_por_rol[rolName] || [];
        
        $('#modalRolNombre').text(rolName);
        const container = $('#listadoUsuariosRol');
        container.empty();

        if (lista.length === 0) {
            container.html(`
                <div class="text-center py-3 text-muted" style="font-size: 0.72rem;">
                    <i class="bi bi-person-x fs-4 d-block text-secondary mb-1"></i>
                    No hay personal asignado actualmente a este rol en tu organización.
                </div>
            `);
        } else {
            lista.forEach(u => {
                const activoBadge = (u.activo == 1) 
                    ? '<span class="badge bg-success-subtle text-success border border-success-subtle rounded-pill px-2" style="font-weight:400; font-size:0.65rem;">Activo</span>' 
                    : '<span class="badge bg-danger-subtle text-danger border border-danger-subtle rounded-pill px-2" style="font-weight:400; font-size:0.65rem;">Inactivo</span>';
                
                container.append(`
                    <div class="list-group-item d-flex justify-content-between align-items-center py-1.5 px-2.5">
                        <div class="d-flex align-items-center gap-2">
                            <div class="bg-light text-primary rounded-circle p-1 d-flex align-items-center justify-content-center" style="width:28px; height:28px;">
                                <i class="bi bi-person-fill"></i>
                            </div>
                            <div>
                                <div class="text-dark m-0" style="font-size:0.72rem;">${escapeHtml(u.nombre)}</div>
                                <span class="text-muted" style="font-size:0.65rem;">${escapeHtml(u.correo)}</span>
                            </div>
                        </div>
                        ${activoBadge}
                    </div>
                `);
            });
        }

        const modalEl = document.getElementById('modalUsuariosRol');
        if (modalEl && modalEl.parentElement !== document.body) {
            document.body.appendChild(modalEl);
        }
        const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
        modal.show();
    }

    async function guardarMatrizPermisos() {
        if (!rawPermisosData) return;

        const nuevaMatriz = {};

        $('.perm-check').each(function() {
            const r = $(this).attr('data-rol');
            const m = $(this).attr('data-mod');
            const a = $(this).attr('data-act');
            const val = $(this).is(':checked') ? 1 : 0;

            if (!nuevaMatriz[r]) nuevaMatriz[r] = {};
            if (!nuevaMatriz[r][m]) nuevaMatriz[r][m] = { C: 0, R: 0, U: 0, D: 0 };

            nuevaMatriz[r][m][a] = val;
        });

        Swal.fire({
            title: 'Guardando permisos...',
            text: 'Aplicando matriz dinámica de permisos por rol.',
            allowOutsideClick: false,
            didOpen: () => { Swal.showLoading(); }
        });

        try {
            const form = new URLSearchParams();
            form.append('accion', 'save_matrix');
            form.append('matriz_json', JSON.stringify(nuevaMatriz));

            const req = await fetch('../api/gestion_permisos_roles_api.pl', {
                method: 'POST',
                body: form
            });
            const res = await req.json();

            if (res.ok) {
                Swal.fire({
                    icon: 'success',
                    title: '¡Permisos Guardados!',
                    text: 'La matriz dinámica ha sido actualizada. Los menús e interfaces se adaptarán automáticamente para cada rol.',
                    confirmButtonText: 'Entendido'
                }).then(() => {
                    cargarMatrizPermisos();
                });
            } else {
                Swal.fire('Error', res.msg || 'No se pudieron guardar los permisos.', 'error');
            }
        } catch (e) {
            console.error("Excepción al guardar permisos:", e);
            Swal.fire('Error', 'Problema de conexión al guardar.', 'error');
        }
    }

    function escapeHtml(unsafe) {
        if (!unsafe) return '';
        return String(unsafe)
             .replace(/&/g, "&amp;")
             .replace(/</g, "&lt;")
             .replace(/>/g, "&gt;")
             .replace(/"/g, "&quot;")
             .replace(/'/g, "&#039;");
    }
</script>
JS

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('usuarios');
print "</body></html>\n";
1;
