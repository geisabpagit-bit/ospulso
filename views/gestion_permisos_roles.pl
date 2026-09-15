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
    titulo => 'Matriz de Permisos por Rol',
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

<style>
    .permisos-card {
        background: #ffffff;
        border-radius: 1.25rem;
        border: 1px solid #e2e8f0;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.04);
    }
    .table-permisos th {
        background: #f8fafc;
        color: #0F172A;
        font-weight: 700;
        text-transform: uppercase;
        font-size: 0.75rem;
        letter-spacing: 0.5px;
        padding: 0.85rem 1rem;
        border-bottom: 2px solid #e2e8f0;
    }
    .table-permisos td {
        padding: 0.75rem 1rem;
        vertical-align: middle;
        border-bottom: 1px solid #f1f5f9;
    }
    .badge-crud {
        font-size: 0.65rem;
        font-weight: 800;
        padding: 0.2rem 0.45rem;
        border-radius: 0.35rem;
    }
    .crud-box {
        display: inline-flex;
        align-items: center;
        gap: 0.25rem;
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        padding: 0.25rem 0.5rem;
        border-radius: 0.5rem;
    }
    .form-check-input:checked {
        background-color: #19B7A5;
        border-color: #19B7A5;
    }
</style>

<main class="container-fluid container-mobile-flush pt-4 px-lg-4 pb-5 animate__animated animate__fadeIn">
    <div class="row g-4 mb-4">
        <div class="col-12">
            <div class="permisos-card p-4 p-md-5">
                <div class="d-flex flex-wrap justify-content-between align-items-center gap-3 mb-4 border-bottom pb-3">
                    <div>
                        <h4 class="fw-black m-0" style="color: var(--md-blue-deep);"><i class="bi bi-shield-lock-fill me-2" style="color: var(--md-teal-clinical);"></i>Matriz Dinámica de Permisos por Rol</h4>
                        <p class="text-muted small m-0 mt-1">Configura el acceso al menú lateral y las facultades CRUD (Crear, Leer, Actualizar, Borrar) para cada rol de tu organización.</p>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <button type="button" class="btn btn-outline-secondary btn-sm rounded-pill px-3 fw-bold" onclick="cargarMatrizPermisos()">
                            <i class="bi bi-arrow-clockwise me-1"></i> Recargar
                        </button>
                        <button type="button" class="btn text-white btn-mobile-standard px-4 py-2.5 fw-bold rounded-3 shadow-sm" style="background: var(--md-blue-deep, #0A2A66);" onclick="guardarMatrizPermisos()">
                            <i class="bi bi-check2-circle me-1 fs-5"></i> Guardar Cambios
                        </button>
                    </div>
                </div>

                <div id="loaderPermisos" class="text-center py-5">
                    <div class="spinner-border text-primary" role="status"></div>
                    <div class="text-muted small mt-2 fw-bold">Cargando matriz de permisos de la organización...</div>
                </div>

                <div id="containerMatriz" style="display: none;">
                    <div class="table-responsive border rounded-4 overflow-hidden shadow-sm bg-white mb-3">
                        <table class="table table-hover table-permisos align-middle m-0" id="tablaPermisos">
                            <thead>
                                <tr id="trHeader">
                                    <th class="ps-4">Módulo / Sección</th>
                                </tr>
                            </thead>
                            <tbody id="tbodyMatriz"></tbody>
                        </table>
                    </div>

                    <div class="alert alert-info border-0 rounded-3 shadow-sm d-flex align-items-center gap-3 py-3">
                        <i class="bi bi-info-circle-fill fs-3 text-info"></i>
                        <div class="small">
                            <strong>Leyenda de Facultades CRUD:</strong><br>
                            <span class="badge bg-success badge-crud me-1">C</span> <b>Crear</b> (Registrar / Emitir) &nbsp;|&nbsp;
                            <span class="badge bg-primary badge-crud me-1">R</span> <b>Leer</b> (Ver en Menú / Consultar) &nbsp;|&nbsp;
                            <span class="badge bg-warning text-dark badge-crud me-1">U</span> <b>Actualizar</b> (Editar / Modificar) &nbsp;|&nbsp;
                            <span class="badge bg-danger badge-crud me-1">D</span> <b>Borrar</b> (Eliminar / Anular)<br>
                            <span class="text-muted mt-1 d-block">* El rol <b>Administrador Organización</b> conserva acceso seguro de administración sin riesgo de auto-bloqueo.</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</main>

<script>
    let rawPermisosData = null;

    document.addEventListener('DOMContentLoaded', () => {
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

        trHeader.innerHTML = '<th class="ps-4" style="min-width: 240px;">Módulo / Sección</th>';
        tbody.innerHTML = '';

        const roles = data.roles || [];
        const modulos = data.modulos || [];
        const matriz = data.matriz || {};

        roles.forEach(rol => {
            const th = document.createElement('th');
            th.className = 'text-center';
            th.style.minWidth = '210px';
            th.innerHTML = `
                <div class="fw-bold text-dark mb-1">${escapeHtml(rol)}</div>
                <div class="d-flex justify-content-center gap-1">
                    <button type="button" class="btn btn-link p-0 text-decoration-none small text-muted" style="font-size: 0.68rem;" onclick="marcarTodoRol('${escapeHtml(rol)}', true)">[Todos]</button>
                    <span class="text-muted" style="font-size:0.68rem;">|</span>
                    <button type="button" class="btn btn-link p-0 text-decoration-none small text-muted" style="font-size: 0.68rem;" onclick="marcarTodoRol('${escapeHtml(rol)}', false)">[Ninguno]</button>
                </div>
            `;
            trHeader.appendChild(th);
        });

        modulos.forEach(mod => {
            const tr = document.createElement('tr');
            let colModHtml = `
                <td class="ps-4 align-middle">
                    <div class="d-flex align-items-center gap-2">
                        <i class="bi ${escapeHtml(mod.icono || 'bi-folder')} text-primary fs-5"></i>
                        <div>
                            <div class="fw-bold text-dark small">${escapeHtml(mod.nombre)}</div>
                            <code class="text-muted" style="font-size: 0.68rem;">mod: ${escapeHtml(mod.id)}</code>
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
                    <td class="text-center align-middle">
                        <div class="d-inline-flex flex-wrap justify-content-center gap-1.5 p-1 rounded-3 bg-light border">
                            <label class="crud-box" title="Crear / Registrar">
                                <span class="badge bg-success badge-crud">C</span>
                                <input class="form-check-input m-0 perm-check" type="checkbox" data-rol="${escapeHtml(rol)}" data-mod="${escapeHtml(mod.id)}" data-act="C" ${cChecked} ${disabledAttr}>
                            </label>
                            <label class="crud-box" title="Leer / Ver en Menú">
                                <span class="badge bg-primary badge-crud">R</span>
                                <input class="form-check-input m-0 perm-check" type="checkbox" data-rol="${escapeHtml(rol)}" data-mod="${escapeHtml(mod.id)}" data-act="R" ${rChecked} ${disabledAttr}>
                            </label>
                            <label class="crud-box" title="Actualizar / Modificar">
                                <span class="badge bg-warning text-dark badge-crud">U</span>
                                <input class="form-check-input m-0 perm-check" type="checkbox" data-rol="${escapeHtml(rol)}" data-mod="${escapeHtml(mod.id)}" data-act="U" ${uChecked} ${disabledAttr}>
                            </label>
                            <label class="crud-box" title="Borrar / Anular">
                                <span class="badge bg-danger badge-crud">D</span>
                                <input class="form-check-input m-0 perm-check" type="checkbox" data-rol="${escapeHtml(rol)}" data-mod="${escapeHtml(mod.id)}" data-act="D" ${dChecked} ${disabledAttr}>
                            </label>
                        </div>
                    </td>
                `;
            });

            tr.innerHTML = colModHtml + colsRolesHtml;
            tbody.appendChild(tr);
        });
    }

    function marcarTodoRol(rolName, estado) {
        $(`.perm-check[data-rol="${rolName}"]`).not(':disabled').prop('checked', estado);
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

HTML

utils::sub_sidebar::render_sidebar_footer();
print "</body></html>\n";
1;
