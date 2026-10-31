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

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario = $sd->{usuario};
my $role    = $sd->{role};

# Validación estricta de RBAC: Exclusivo Administrador Global
if ($role ne 'Administrador Global') {
    render_acceso_denegado(
        q => $q, usuario => $usuario, role => $role,
        mensaje => 'Esta sección es de acceso exclusivo para el Administrador Global de la plataforma.',
        rol_requerido => 'Administrador Global'
    );
    exit;
}

print $q->header(
    -type => 'text/html',
    -charset => 'UTF-8',
    -cache_control => 'no-store, no-cache, must-revalidate, max-age=0',
    -pragma => 'no-cache'
);

render_header(
    usuario     => $usuario,
    role        => $role,
    titulo      => "Gestión de Cards de Inicio",
    skip_header => 1
);

utils::sub_sidebar::render_sidebar(
    role          => $role,
    usuario       => $usuario,
    pagina_actual => 'cards_inicio'
);

print <<'PAGE_HTML';
<div class="container-fluid px-3 px-md-4 py-3">

    <!-- Header de Página -->
    <div class="card border-0 rounded-4 shadow-sm p-4 mb-4 bg-white" style="border: 1.5px solid rgba(25, 183, 165, 0.35) !important;">
        <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center gap-3">
            <div>
                <div class="d-flex align-items-center gap-2 mb-1">
                    <span class="badge rounded-pill px-3 py-1 fw-bold" style="background-color: rgba(25, 183, 165, 0.15); color: #0d9488; border: 1px solid rgba(25, 183, 165, 0.3);">
                        <i class="bi bi-window-stack me-1"></i>Personalización Dinámica
                    </span>
                    <span class="badge rounded-pill px-3 py-1 fw-bold text-white" style="background-color: #0A2A66;">
                        Rol: Administrador Global
                    </span>
                </div>
                <h3 class="fw-bold plus-jakarta mb-1" style="color: #0A2A66;">
                    Gestión de Cards de la Vista Inicial
                </h3>
                <p class="text-muted small mb-0">
                    Administra dinámicamente los minicards y accesos directos visibles en el panel maestro de inicio sin tocar código duro.
                </p>
            </div>
            <div class="d-flex gap-2 flex-wrap">
                <a href="inicial.pl" class="btn btn-outline-secondary rounded-pill px-3 py-2 fw-semibold shadow-sm d-flex align-items-center gap-2">
                    <i class="bi bi-eye-fill"></i>
                    <span>Ver Vista Inicial</span>
                </a>
                <button type="button" class="btn btn-premium-primary rounded-pill px-4 py-2 fw-bold shadow-sm d-flex align-items-center gap-2" onclick="abrirModalNuevo()">
                    <i class="bi bi-plus-circle-fill"></i>
                    <span>Nuevo Acceso Directo</span>
                </button>
            </div>
        </div>
    </div>

    <!-- Contenedor Principal de la Tabla de Cards -->
    <div class="card border-0 rounded-4 shadow-sm bg-white overflow-hidden" style="border: 1px solid #e2e8f0 !important;">
        <div class="card-header bg-light border-0 py-3 px-4 d-flex justify-content-between align-items-center flex-wrap gap-2">
            <h6 class="fw-bold mb-0 text-dark d-flex align-items-center gap-2">
                <i class="bi bi-grid-1x2-fill" style="color: #19B7A5;"></i>
                Lista de Minicards Configurados en Vista Inicial
            </h6>
            <button class="btn btn-sm btn-outline-secondary rounded-pill px-3" onclick="cargarCards()">
                <i class="bi bi-arrow-clockwise me-1"></i>Recargar
            </button>
        </div>
        <div class="card-body p-0">
            <div class="table-responsive">
                <table class="table table-hover align-middle mb-0 text-nowrap" id="tablaCards">
                    <thead class="table-light">
                        <tr class="small text-uppercase fw-bold text-muted" style="letter-spacing: 0.5px;">
                            <th class="ps-4" style="width: 70px;">Orden</th>
                            <th style="min-width: 280px;">Minicard (Título y Descripción)</th>
                            <th>Icono</th>
                            <th>Destino / Enlace</th>
                            <th>Color / Badge</th>
                            <th class="text-center">Estado</th>
                            <th class="pe-4 text-end">Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="tbodyCards">
                        <tr>
                            <td colspan="7" class="text-center py-5 text-muted">
                                <div class="spinner-border text-teal spinner-border-sm me-2" role="status"></div>
                                Cargando accesos directos...
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

</div>

<!-- Modal para Crear o Editar Card -->
<div class="modal fade" id="modalCard" tabindex="-1" aria-labelledby="modalCardLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 rounded-4 shadow-lg overflow-hidden" style="border: 1.5px solid rgba(25, 183, 165, 0.4) !important;">
            
            <div class="modal-header text-white px-4 py-3" style="background: linear-gradient(135deg, #0A2A66, #124A9E); border-bottom: 2px solid #19B7A5;">
                <div class="d-flex align-items-center gap-2">
                    <i class="bi bi-window-stack fs-5 text-info"></i>
                    <h5 class="modal-title fw-bold plus-jakarta mb-0" id="modalCardLabel">Configurar Minicard de Inicio</h5>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>

            <form id="formCard" onsubmit="guardarCard(event)">
                <div class="modal-body p-4 bg-light">
                    
                    <input type="hidden" id="cardId" name="id" value="">

                    <!-- Selección de Plantilla Rápida -->
                    <div class="card border-0 rounded-3 p-3 mb-3 bg-white shadow-sm" style="border-left: 4px solid #19B7A5 !important;">
                        <label class="form-label fw-bold small text-dark mb-1">
                            <i class="bi bi-magic text-teal me-1"></i>Autocompletar con Módulo del Menú (Plantilla Rápida):
                        </label>
                        <select class="form-select form-select-sm" id="selectPlantilla" onchange="aplicarPlantilla(this.value)">
                            <option value="">-- Selecciona para autocompletar o escribe manualmente abajo --</option>
                            <option value="registros">Gestión de Registros (manage_registros.pl)</option>
                            <option value="permisos">Matriz de Permisos (gestion_permisos_roles.pl)</option>
                            <option value="usuarios_online">Usuarios en Línea (usuarios_online.pl)</option>
                            <option value="mantenimiento">Catálogos y Mantenimiento (administracion_catalogo.pl)</option>
                            <option value="catalogos">Gestión de Catálogos (gestion_catalogos.pl)</option>
                            <option value="backups">Copias de Seguridad (admin_backups.pl)</option>
                            <option value="migracion">Migración SaaS (admin_migracion.pl)</option>
                            <option value="hot_deploy">Actualización en Caliente (javascript:iniciarHotDeploy())</option>
                            <option value="crm_ventas">CRM Ventas (crm_ventas.pl)</option>
                            <option value="reportes">Reportes y Análisis (reportes.pl)</option>
                        </select>
                    </div>

                    <div class="row g-3">
                        <!-- Título -->
                        <div class="col-md-7">
                            <label class="form-label fw-bold small text-dark">
                                Título del Minicard <span class="text-danger">*</span>
                            </label>
                            <input type="text" class="form-control" id="cardTitulo" name="titulo" placeholder="Ej. Gestión de Registros" required oninput="actualizarPreview()">
                        </div>

                        <!-- Orden -->
                        <div class="col-md-5">
                            <label class="form-label fw-bold small text-dark">
                                Posición / Orden
                            </label>
                            <input type="number" class="form-control" id="cardOrden" name="orden" value="1" min="1" max="99" required>
                        </div>

                        <!-- Descripción -->
                        <div class="col-12">
                            <label class="form-label fw-bold small text-dark">
                                Descripción Breve <span class="text-danger">*</span>
                            </label>
                            <textarea class="form-control" id="cardDesc" name="desc" rows="2" placeholder="Resumen conciso del módulo o acceso." required oninput="actualizarPreview()"></textarea>
                        </div>

                        <!-- Destino / Enlace -->
                        <div class="col-md-8">
                            <label class="form-label fw-bold small text-dark">
                                Archivo Destino o Enlace <span class="text-danger">*</span>
                            </label>
                            <input type="text" class="form-control font-mono small" id="cardDestino" name="destino" placeholder="Ej. manage_registros.pl o javascript:iniciarHotDeploy()" required>
                            <div class="form-text small">Ruta de vista (.pl) o comando JavaScript.</div>
                        </div>

                        <!-- Icono Bootstrap -->
                        <div class="col-md-4">
                            <label class="form-label fw-bold small text-dark">
                                Icono Bootstrap (bi-*)
                            </label>
                            <div class="input-group">
                                <span class="input-group-text bg-white" id="previewIconoBox">
                                    <i class="bi bi-grid-fill" id="previewIconoElem"></i>
                                </span>
                                <input type="text" class="form-control" id="cardIcono" name="icono" value="bi-grid-fill" placeholder="bi-grid-fill" oninput="actualizarPreview()">
                            </div>
                        </div>

                        <!-- Color Distintivo -->
                        <div class="col-md-6">
                            <label class="form-label fw-bold small text-dark">
                                Color Distintivo
                            </label>
                            <select class="form-select" id="cardColor" name="color" onchange="actualizarPreview()">
                                <option value="primary">Azul Primario (Primary)</option>
                                <option value="teal" selected>Teal Clínico (Teal)</option>
                                <option value="info">Cyan / Info</option>
                                <option value="success">Verde Éxito (Success)</option>
                                <option value="warning">Ámbar / Warning</option>
                                <option value="danger">Rojo Alerta (Danger)</option>
                                <option value="dark">Gris Oscuro (Dark)</option>
                            </select>
                        </div>

                        <!-- Estado Activo -->
                        <div class="col-md-6 d-flex align-items-center mt-4">
                            <div class="form-check form-switch ps-5">
                                <input class="form-check-input" type="checkbox" role="switch" id="cardActivo" name="activo" value="1" checked style="width: 2.4em; height: 1.3em;">
                                <label class="form-check-label fw-bold small text-dark ms-2" for="cardActivo">
                                    Visible en Vista Inicial
                                </label>
                            </div>
                        </div>
                    </div>

                    <!-- Previsualización en Vivo del Minicard -->
                    <div class="mt-4 pt-3 border-top">
                        <label class="form-label fw-bold small text-muted text-uppercase mb-2" style="letter-spacing: 0.5px;">
                            <i class="bi bi-eye me-1"></i>Previsualización en tiempo real del Minicard:
                        </label>
                        <div class="p-3 bg-white rounded-4" style="border: 1px dashed #cbd5e1;">
                            <div class="row justify-content-center">
                                <div class="col-md-8 col-lg-6">
                                    
                                    <div id="demoCard" class="card border-0 rounded-4 p-3 shadow-sm position-relative overflow-hidden" style="border: 1.5px solid #19B7A5 !important; background: #ffffff;">
                                        <div class="d-flex align-items-start gap-3">
                                            <div id="demoIconWrap" class="rounded-3 d-flex align-items-center justify-content-center flex-shrink-0" style="width: 44px; height: 44px; background: rgba(25, 183, 165, 0.12); color: #19B7A5; transition: all 0.25s ease;">
                                                <i class="bi bi-grid-fill fs-5" id="demoIcon"></i>
                                            </div>
                                            <div class="flex-grow-1 min-w-0">
                                                <div class="mb-1">
                                                    <span class="badge px-2 py-1 rounded-pill fw-bold text-white text-truncate max-w-100" id="demoTitle" style="background-color: #0A2A66; font-size: 0.85rem;">
                                                        Título del Minicard
                                                    </span>
                                                </div>
                                                <p class="small text-muted mb-0" id="demoDesc" style="font-size: 0.82rem; line-height: 1.35;">
                                                    Descripción concisa del acceso directo configurado.
                                                </p>
                                            </div>
                                        </div>
                                    </div>

                                </div>
                            </div>
                        </div>
                    </div>

                </div>
                <div class="modal-footer bg-white px-4 py-3 border-top">
                    <button type="button" class="btn btn-light border rounded-pill px-4" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-premium-primary rounded-pill px-4 fw-bold shadow-sm" id="btnGuardarCard">
                        <i class="bi bi-check-circle-fill me-1"></i>Guardar Acceso Directo
                    </button>
                </div>
            </form>

        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
PAGE_HTML

print <<'JS';
<script>
    const PLANTILLAS_MODULOS = {
        'registros': {
            titulo: 'Gestión de Registros',
            desc: 'Supervisión centralizada de logs y auditoría del sistema.',
            icono: 'bi-person-lines-fill',
            color: 'primary',
            destino: 'manage_registros.pl',
            orden: 1
        },
        'permisos': {
            titulo: 'Matriz de Permisos',
            desc: 'Control granular de facultades y matrices de acceso por rol.',
            icono: 'bi-shield-lock-fill',
            color: 'info',
            destino: 'gestion_permisos_roles.pl',
            orden: 2
        },
        'usuarios_online': {
            titulo: 'Usuarios en Línea',
            desc: 'Monitoreo en tiempo real de sesiones activas en la plataforma.',
            icono: 'bi-activity',
            color: 'success',
            destino: 'usuarios_online.pl',
            orden: 3
        },
        'mantenimiento': {
            titulo: 'Catálogos y Mantenimiento',
            desc: 'Mantenimiento maestro de infraestructura, copias y catálogos.',
            icono: 'bi-tools',
            color: 'warning',
            destino: 'administracion_catalogo.pl',
            orden: 4
        },
        'catalogos': {
            titulo: 'Gestión de Catálogos',
            desc: 'Configuración de catálogos y nomenclaturas institucionales.',
            icono: 'bi-database-gear',
            color: 'teal',
            destino: 'gestion_catalogos.pl',
            orden: 5
        },
        'backups': {
            titulo: 'Copias de Seguridad',
            desc: 'Generación, descarga y restauración de respaldos globales.',
            icono: 'bi-hdd-network-fill',
            color: 'primary',
            destino: 'admin_backups.pl',
            orden: 6
        },
        'migracion': {
            titulo: 'Migración SaaS',
            desc: 'Paquete de migración para traspaso rápido entre servidores.',
            icono: 'bi-cloud-arrow-down-fill',
            color: 'dark',
            destino: 'admin_migracion.pl',
            orden: 7
        },
        'hot_deploy': {
            titulo: 'Actualización en Caliente',
            desc: 'Despliegue ágil en segundo plano sin alterar datos operativos.',
            icono: 'bi-lightning-charge-fill',
            color: 'teal',
            destino: 'javascript:iniciarHotDeploy()',
            orden: 8
        },
        'crm_ventas': {
            titulo: 'CRM Ventas',
            desc: 'Plataforma comercial y asignación de licencias para organizaciones.',
            icono: 'bi-briefcase-fill',
            color: 'primary',
            destino: 'crm_ventas.pl',
            orden: 9
        },
        'reportes': {
            titulo: 'Reportes y Análisis',
            desc: 'Informes consolidado de actividad y rendimiento de la plataforma.',
            icono: 'bi-file-bar-chart',
            color: 'info',
            destino: 'reportes.pl',
            orden: 10
        }
    };

    const COLOR_PALETTES = {
        'teal':    { bg: 'rgba(25, 183, 165, 0.12)', fg: '#19B7A5' },
        'primary': { bg: 'rgba(10, 42, 102, 0.10)',  fg: '#0A2A66' },
        'info':    { bg: 'rgba(14, 165, 233, 0.12)', fg: '#0284c7' },
        'success': { bg: 'rgba(22, 163, 74, 0.12)',  fg: '#16a34a' },
        'warning': { bg: 'rgba(234, 88, 12, 0.12)',  fg: '#ea580c' },
        'danger':  { bg: 'rgba(220, 38, 38, 0.12)',  fg: '#dc2626' },
        'dark':    { bg: 'rgba(51, 65, 85, 0.12)',   fg: '#334155' }
    };

    let modalInstance = null;

    document.addEventListener('DOMContentLoaded', function() {
        modalInstance = new bootstrap.Modal(document.getElementById('modalCard'));
        cargarCards();
    });

    async function cargarCards() {
        const tbody = document.getElementById('tbodyCards');
        tbody.innerHTML = `
            <tr>
                <td colspan="7" class="text-center py-5 text-muted">
                    <div class="spinner-border spinner-border-sm text-teal me-2" role="status"></div>
                    Cargando accesos directos...
                </td>
            </tr>
        `;

        try {
            const res = await fetch('../api/cards_inicio_api.pl?accion=listar');
            const data = await res.json();

            if (!data.success) {
                tbody.innerHTML = `<tr><td colspan="7" class="text-center text-danger py-4">${data.error || 'Error al cargar'}</td></tr>`;
                return;
            }

            const cards = data.data || [];
            if (cards.length === 0) {
                tbody.innerHTML = `
                    <tr>
                        <td colspan="7" class="text-center py-5 text-muted">
                            <i class="bi bi-inbox fs-2 d-block mb-2 text-muted"></i>
                            No hay minicards configurados aún. Haz clic en "Nuevo Acceso Directo" para agregar el primero.
                        </td>
                    </tr>
                `;
                return;
            }

            let html = '';
            cards.forEach(c => {
                const iconoClase = c.icono || 'bi-grid-fill';
                const esActivo = parseInt(c.activo) === 1;
                const cColor = (c.color || 'teal').toLowerCase();
                const cPal = COLOR_PALETTES[cColor] || COLOR_PALETTES['teal'];

                const badgeActivo = esActivo
                    ? `<span class="badge rounded-pill bg-success bg-opacity-10 text-success border border-success border-opacity-25 px-2 py-1"><i class="bi bi-check-circle me-1"></i>Activo</span>`
                    : `<span class="badge rounded-pill bg-secondary bg-opacity-10 text-secondary border px-2 py-1"><i class="bi bi-eye-slash me-1"></i>Inactivo</span>`;

                html += `
                    <tr>
                        <td class="ps-4 fw-bold text-muted">${c.orden}</td>
                        <td>
                            <div class="d-flex align-items-center gap-3">
                                <div class="rounded-3 d-flex align-items-center justify-content-center flex-shrink-0" 
                                     style="width: 38px; height: 38px; background: ${cPal.bg}; color: ${cPal.fg};">
                                    <i class="bi ${iconoClase} fs-5"></i>
                                </div>
                                <div>
                                    <span class="badge px-2 py-1 rounded-pill fw-bold text-white mb-1" style="background-color: #0A2A66; font-size: 0.85rem;">
                                        ${c.titulo}
                                    </span>
                                    <div class="small text-muted text-wrap" style="max-width: 380px; font-size: 0.8rem;">
                                        ${c.desc}
                                    </div>
                                </div>
                            </div>
                        </td>
                        <td>
                            <code class="small text-dark fw-bold">${c.icono}</code>
                        </td>
                        <td>
                            <span class="font-mono small text-secondary">${c.destino}</span>
                        </td>
                        <td>
                            <span class="badge border px-2 py-1 text-capitalize" style="background-color: ${cPal.bg}; color: ${cPal.fg}; border-color: ${cPal.fg}40 !important;">${c.color}</span>
                        </td>
                        <td class="text-center">
                            <button type="button" class="btn btn-sm p-0 border-0" onclick="toggleEstado('${c.id}')" title="Clic para alternar estado">
                                ${badgeActivo}
                            </button>
                        </td>
                        <td class="pe-4 text-end">
                            <div class="btn-group btn-group-sm">
                                <button type="button" class="btn btn-outline-primary" onclick="editarCard('${c.id}')" title="Editar">
                                    <i class="bi bi-pencil-square"></i>
                                </button>
                                <button type="button" class="btn btn-outline-danger" onclick="eliminarCard('${c.id}', '${c.titulo}')" title="Eliminar">
                                    <i class="bi bi-trash3"></i>
                                </button>
                            </div>
                        </td>
                    </tr>
                `;
            });

            tbody.innerHTML = html;

        } catch (err) {
            tbody.innerHTML = `<tr><td colspan="7" class="text-center text-danger py-4">Error de comunicación con el servidor.</td></tr>`;
        }
    }

    function abrirModalNuevo() {
        document.getElementById('formCard').reset();
        document.getElementById('cardId').value = '';
        document.getElementById('modalCardLabel').textContent = 'Nuevo Minicard de Inicio';
        document.getElementById('selectPlantilla').value = '';
        document.getElementById('cardColor').value = 'teal';
        document.getElementById('cardIcono').value = 'bi-grid-fill';
        document.getElementById('cardActivo').checked = true;
        actualizarPreview();
        modalInstance.show();
    }

    function aplicarPlantilla(clave) {
        if (!clave || !PLANTILLAS_MODULOS[clave]) return;
        const p = PLANTILLAS_MODULOS[clave];
        document.getElementById('cardTitulo').value = p.titulo;
        document.getElementById('cardDesc').value = p.desc;
        document.getElementById('cardIcono').value = p.icono;
        document.getElementById('cardColor').value = p.color;
        document.getElementById('cardDestino').value = p.destino;
        if (p.orden) document.getElementById('cardOrden').value = p.orden;
        actualizarPreview();
    }

    function actualizarPreview() {
        const titulo = document.getElementById('cardTitulo').value || 'Título del Minicard';
        const desc = document.getElementById('cardDesc').value || 'Descripción concisa del acceso directo configurado.';
        let icono = document.getElementById('cardIcono').value.trim() || 'bi-grid-fill';
        if (!icono.startsWith('bi-')) icono = 'bi-' + icono;
        const color = (document.getElementById('cardColor').value || 'teal').toLowerCase();
        const pal = COLOR_PALETTES[color] || COLOR_PALETTES['teal'];

        document.getElementById('demoTitle').textContent = titulo;
        document.getElementById('demoDesc').textContent = desc;
        document.getElementById('demoIcon').className = `bi ${icono} fs-5`;
        document.getElementById('previewIconoElem').className = `bi ${icono}`;

        const iconWrap = document.getElementById('demoIconWrap');
        if (iconWrap) {
            iconWrap.style.backgroundColor = pal.bg;
            iconWrap.style.color = pal.fg;
        }
    }

    async function editarCard(id) {
        try {
            const res = await fetch(`../api/cards_inicio_api.pl?accion=obtener&id=${encodeURIComponent(id)}`);
            const data = await res.json();
            if (!data.success || !data.card) {
                Swal.fire('Error', data.error || 'No se encontró la tarjeta.', 'error');
                return;
            }

            const c = data.card;
            document.getElementById('cardId').value = c.id;
            document.getElementById('cardTitulo').value = c.titulo;
            document.getElementById('cardDesc').value = c.desc;
            document.getElementById('cardIcono').value = c.icono;
            document.getElementById('cardColor').value = c.color;
            document.getElementById('cardDestino').value = c.destino;
            document.getElementById('cardOrden').value = c.orden;
            document.getElementById('cardActivo').checked = parseInt(c.activo) === 1;

            document.getElementById('modalCardLabel').textContent = `Editar Minicard: ${c.titulo}`;
            actualizarPreview();
            modalInstance.show();

        } catch (e) {
            Swal.fire('Error', 'No se pudo consultar la tarjeta.', 'error');
        }
    }

    async function guardarCard(e) {
        e.preventDefault();
        const form = document.getElementById('formCard');
        const fd = new FormData(form);
        fd.append('accion', 'guardar');
        if (!document.getElementById('cardActivo').checked) {
            fd.set('activo', '0');
        } else {
            fd.set('activo', '1');
        }

        const btn = document.getElementById('btnGuardarCard');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1" role="status"></span>Guardando...';

        try {
            const res = await fetch('../api/cards_inicio_api.pl', {
                method: 'POST',
                body: fd
            });
            const data = await res.json();

            if (data.success) {
                modalInstance.hide();
                Swal.fire({
                    icon: 'success',
                    title: '¡Guardado!',
                    text: data.message || 'El acceso directo se guardó correctamente.',
                    timer: 1600,
                    showConfirmButton: false
                });
                cargarCards();
            } else {
                Swal.fire('Error al guardar', data.error || 'Revisa los datos e intenta de nuevo.', 'error');
            }
        } catch (err) {
            Swal.fire('Error de Conexión', 'Ocurrió un error al comunicarse con el servidor.', 'error');
        } finally {
            btn.disabled = false;
            btn.innerHTML = '<i class="bi bi-check-circle-fill me-1"></i>Guardar Acceso Directo';
        }
    }

    async function toggleEstado(id) {
        try {
            const fd = new FormData();
            fd.append('accion', 'toggle');
            fd.append('id', id);

            const res = await fetch('../api/cards_inicio_api.pl', {
                method: 'POST',
                body: fd
            });
            const data = await res.json();
            if (data.success) {
                cargarCards();
            } else {
                Swal.fire('Error', data.error || 'No se pudo cambiar el estado.', 'error');
            }
        } catch (e) {
            Swal.fire('Error', 'Error de comunicación.', 'error');
        }
    }

    async function eliminarCard(id, titulo) {
        const conf = await Swal.fire({
            title: '¿Eliminar acceso directo?',
            html: `Se removerá el minicard <strong>"${titulo}"</strong> de la vista inicial.`,
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc2626',
            cancelButtonColor: '#64748b',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        });

        if (!conf.isConfirmed) return;

        try {
            const fd = new FormData();
            fd.append('accion', 'eliminar');
            fd.append('id', id);

            const res = await fetch('../api/cards_inicio_api.pl', {
                method: 'POST',
                body: fd
            });
            const data = await res.json();
            if (data.success) {
                Swal.fire({
                    icon: 'success',
                    title: 'Eliminado',
                    text: 'El acceso directo fue eliminado.',
                    timer: 1400,
                    showConfirmButton: false
                });
                cargarCards();
            } else {
                Swal.fire('Error', data.error || 'No se pudo eliminar.', 'error');
            }
        } catch (e) {
            Swal.fire('Error', 'Error de comunicación.', 'error');
        }
    }
</script>
JS

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('ajustes');

print <<'PAGE_FOOTER';
</body>
</html>
PAGE_FOOTER

1;
