#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib $FindBin::Bin . '/..';

require "$FindBin::Bin/../auth/check_session.pl";
require "$FindBin::Bin/../utils/sub_header.pl";
require "$FindBin::Bin/../utils/sub_bottom_nav.pl";
require "$FindBin::Bin/../utils/sub_sidebar.pl";

my $q = CGI->new;
my $session_data = check_session();

# Gobernanza RBAC: Se permite acceso a personal con rol operativo, comercial o directivo
if (!$session_data->{session_ok} || $session_data->{role} =~ /Paciente/i) {
    print $q->redirect(-uri => '../index.html');
    exit;
}

my $usuario     = $session_data->{usuario} || 'Usuario';
my $role        = $session_data->{role} || 'Staff';
my $id_medico   = $session_data->{id_medico} // '';
my $id_empresa  = $session_data->{id_empresa} // '0';
my $id_registro = $session_data->{id_registro} // '';

# Encabezado HTML
print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $usuario,
    titulo      => "Comunicaciones y Campañas - OSPulso",
    role        => $role,
    id_medico   => $id_medico,
    skip_header => 1
);

# Inyección de Estilos
print <<'PAGE_HEAD';
<link rel="stylesheet" href="../css/expediente_completo.css?v=4">
<link rel="stylesheet" href="../css/comunicacion_masiva.css?v=1">
<link rel="stylesheet" href="../css/sdm_mobile_standards.css?v=1">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
PAGE_HEAD

# Sidebar Maestro
utils::sub_sidebar::render_sidebar(
    usuario       => $usuario,
    role          => $role,
    id_medico     => $id_medico,
    pagina_actual => 'comunicacion_masiva',
    id_empresa    => $id_empresa
);

# Contenedor Principal y Estructura HTML
print <<"PAGE_HTML";
<div class="comunicacion-container container-mobile-flush">

    <!-- Configuración para consumo seguro por Javascript -->
    <div id="comunicacionConfig" 
         data-rol="$role" 
         data-usuario="$usuario" 
         data-id-empresa="$id_empresa" 
         data-id-medico="$id_medico" 
         style="display:none;"></div>

    <!-- Hero Header Compacto -->
    <div class="comunicacion-hero">
        <div>
            <h1 class="comunicacion-hero-title">
                <i class="fa-solid fa-paper-plane text-cyan"></i> Centro de Comunicaciones y Difusión
            </h1>
            <p class="comunicacion-hero-subtitle">
                Emisión de comunicados, campañas y recordatorios por correo masivo segmentado
            </p>
        </div>
        <div class="d-flex align-items-center gap-2">
            <span class="badge bg-white text-dark py-2 px-3 rounded-pill fw-bold shadow-sm">
                <i class="fa-solid fa-shield-halved text-primary me-1"></i> Rol: $role
            </span>
        </div>
    </div>

    <!-- Pestañas de Módulo -->
    <ul class="nav comunicacion-nav-tabs" id="comunicacionTabs" role="tablist">
        <li class="nav-item">
            <button class="nav-link active" id="tab-nueva-btn" data-bs-toggle="tab" data-bs-target="#tab-nueva" type="button" role="tab">
                <i class="fa-solid fa-pen-fancy"></i> Nueva Campaña
            </button>
        </li>
        <li class="nav-item">
            <button class="nav-link" id="tab-historial-btn" data-bs-toggle="tab" data-bs-target="#tab-historial" type="button" role="tab">
                <i class="fa-solid fa-clock-rotate-left"></i> Historial y Trazabilidad
            </button>
        </li>
        <li class="nav-item">
            <button class="nav-link" id="tab-guia-btn" data-bs-toggle="tab" data-bs-target="#tab-guia" type="button" role="tab">
                <i class="fa-solid fa-lightbulb"></i> Buenas Prácticas Anti-SPAM
            </button>
        </li>
    </ul>

    <!-- Contenido de Pestañas -->
    <div class="tab-content" id="comunicacionTabsContent">

        <!-- TAB 1: NUEVA CAMPAÑA -->
        <div class="tab-pane fade show active" id="tab-nueva" role="tabpanel">
            <div class="row g-4">
                
                <!-- Columna Izquierda: Configuración y Redacción -->
                <div class="col-lg-7">
                    
                    <!-- Tarjeta 1: Segmentación de Audiencia -->
                    <div class="panel-card">
                        <div class="panel-header">
                            <h3 class="panel-title">
                                <i class="fa-solid fa-users text-primary"></i> 1. Audiencia y Segmentación
                            </h3>
                            <span class="badge bg-primary-subtle text-primary fw-bold" id="badgeAudienciaTipo">Filtro RBAC Activo</span>
                        </div>

                        <div class="mb-3">
                            <label class="form-label fw-bold text-dark small" for="selAudiencia">
                                Selecciona el público objetivo:
                            </label>
                            <select id="selAudiencia" class="form-select form-select-lg fw-semibold" style="border-radius: 10px;">
PAGE_HTML

# Renderizado Condicional del Select de Audiencias según Rol (UI-RBAC)
if ($role =~ /Administrador Global/i) {
    print <<'PAGE_HTML';
                                <optgroup label="Capa Plataforma (SaaS Global)">
                                    <option value="todos_admin_org" selected>🏢 Todos los Administradores de Organización (Dueños de Clínicas)</option>
                                    <option value="ejecutivos_ventas">💼 Todo el Equipo de Ventas (Ejecutivos)</option>
                                    <option value="broadcast_plataforma">📢 Broadcast Global: A Todo el Personal de Todas las Clínicas</option>
                                    <option value="todos_pacientes_global">👥 Todos los Pacientes Registrados en la Plataforma</option>
                                </optgroup>
                                <optgroup label="Segmentación por Clínica Específica">
                                    <option value="org_actual">🏥 Personal de la Clínica Principal</option>
                                </optgroup>
PAGE_HTML
} elsif ($role =~ /Ejecutivo Ventas/i) {
    print <<'PAGE_HTML';
                                <optgroup label="Capa Comercial">
                                    <option value="mis_cuentas_org" selected>🏢 Dueños y Administradores de Organización Asignados</option>
                                    <option value="prospectos_crm">🎯 Prospectos y Leads Comerciales Activos</option>
                                </optgroup>
PAGE_HTML
} elsif ($role =~ /Administrador Organizacion/i) {
    print <<'PAGE_HTML';
                                <optgroup label="Personal de Mi Clínica">
                                    <option value="personal_clinica" selected>👥 Todo el Personal de mi Clínica (Médicos y Recepción)</option>
                                    <option value="solo_medicos">🩺 Únicamente Médicos de mi Clínica</option>
                                    <option value="solo_recepcion">🛎️ Únicamente Personal de Recepción y Caja</option>
                                </optgroup>
                                <optgroup label="Pacientes de Mi Clínica">
                                    <option value="todos_pacientes_clinica">📋 Todos los Pacientes de mi Organización</option>
                                </optgroup>
PAGE_HTML
} elsif ($role =~ /Medico/i) {
    print <<'PAGE_HTML';
                                <optgroup label="Mi Cartera Clínica">
                                    <option value="mis_pacientes" selected>🩺 Únicamente Mis Pacientes Atendidos</option>
                                </optgroup>
PAGE_HTML
} else {
    print <<'PAGE_HTML';
                                <option value="aviso_operativo" selected>🛎️ Pacientes con Citas Próximas de la Sucursal</option>
PAGE_HTML
}

print <<'PAGE_HTML';
                            </select>
                        </div>

                        <!-- Métrica de Audiencia en Vivo -->
                        <div class="audience-metric-card">
                            <div>
                                <div class="audience-metric-label">Destinatarios Únicos con Correo Válido</div>
                                <div class="text-muted small mt-1">
                                    <i class="fa-solid fa-circle-check text-success"></i> Filtro de deduplicación y sintaxis activo
                                </div>
                            </div>
                            <div class="text-end">
                                <span class="audience-metric-count" id="txtTotalDestinatarios">--</span>
                                <span class="small text-muted d-block">personas</span>
                            </div>
                        </div>
                    </div>

                    <!-- Tarjeta 2: Redactor de Correo y Variables Dinámicas -->
                    <div class="panel-card">
                        <div class="panel-header">
                            <h3 class="panel-title">
                                <i class="fa-solid fa-envelope-open-text text-primary"></i> 2. Contenido del Mensaje
                            </h3>
                            <button type="button" class="btn btn-sm btn-outline-secondary rounded-pill" id="btnCargarPlantillaEjemplo">
                                <i class="fa-solid fa-wand-magic-sparkles text-warning me-1"></i> Cargar Plantilla
                            </button>
                        </div>

                        <!-- Asunto -->
                        <div class="mb-3">
                            <label class="form-label fw-bold text-dark small" for="iptAsunto">
                                Asunto del Correo: <span class="text-danger">*</span>
                            </label>
                            <input type="text" id="iptAsunto" class="form-control" 
                                   placeholder="Ej. Aviso Importante: Horarios de Atención y Promoción de Salud" 
                                   maxlength="150" value="Comunicado Oficial de la Clínica">
                        </div>

                        <!-- Variables Dinámicas de Personalización -->
                        <div class="mb-2">
                            <span class="small fw-bold text-muted">Insertar Variable Dinámica (Se sustituirá automáticamente):</span>
                            <div class="variable-tags-container">
                                <button type="button" class="btn-tag-variable" data-tag="{{nombre}}">
                                    <i class="fa-solid fa-user text-primary"></i> {{nombre}}
                                </button>
                                <button type="button" class="btn-tag-variable" data-tag="{{clinica}}">
                                    <i class="fa-solid fa-hospital text-teal"></i> {{clinica}}
                                </button>
                                <button type="button" class="btn-tag-variable" data-tag="{{medico}}">
                                    <i class="fa-solid fa-user-doctor text-info"></i> {{medico}}
                                </button>
                                <button type="button" class="btn-tag-variable" data-tag="{{fecha}}">
                                    <i class="fa-regular fa-calendar text-secondary"></i> {{fecha}}
                                </button>
                            </div>
                        </div>

                        <!-- Cuerpo del Correo -->
                        <div class="mb-3">
                            <label class="form-label fw-bold text-dark small" for="txtCuerpo">
                                Mensaje / Contenido: <span class="text-danger">*</span>
                            </label>
                            <textarea id="txtCuerpo" class="form-control" rows="8" style="border-radius: 8px; font-size: 0.95rem;" 
                                      placeholder="Escribe aquí el contenido del correo... Puedes usar las variables dinámicas de arriba."></textarea>
                        </div>

                        <!-- Botón de Lanzamiento -->
                        <div class="d-grid mt-4">
                            <button type="button" class="btn btn-premium-primary py-3 fs-6" id="btnLanzarCampana">
                                <i class="fa-solid fa-paper-plane me-2"></i> Revisar y Despachar Campaña
                            </button>
                        </div>
                    </div>

                </div>

                <!-- Columna Derecha: Simulador de Bandeja de Entrada (Live Preview) -->
                <div class="col-lg-5">
                    <div class="panel-card sticky-top" style="top: 20px;">
                        <div class="panel-header">
                            <h3 class="panel-title">
                                <i class="fa-solid fa-desktop text-primary"></i> Simulador de Bandeja
                            </h3>
                            <span class="badge bg-success-subtle text-success small fw-bold">
                                <i class="fa-solid fa-eye me-1"></i> Vista Previa en Vivo
                            </span>
                        </div>

                        <div class="email-simulator-wrapper">
                            <!-- Barra superior simulada -->
                            <div class="email-simulator-chrome">
                                <div class="email-simulator-dots">
                                    <span class="email-dot dot-red"></span>
                                    <span class="email-dot dot-yellow"></span>
                                    <span class="email-dot dot-green"></span>
                                </div>
                                <span class="small text-muted fw-semibold" style="font-size: 0.75rem;">Inbox Simulator</span>
                            </div>

                            <!-- Metadatos de Cabecera -->
                            <div class="email-simulator-meta">
                                <div class="email-meta-row">
                                    <span class="email-meta-label">De:</span>
                                    <span class="email-meta-val" id="prevRemitente">OSPulso Clínicas &lt;notificaciones@ospulso.com&gt;</span>
                                </div>
                                <div class="email-meta-row">
                                    <span class="email-meta-label">Para:</span>
                                    <span class="email-meta-val" id="prevDestinatario">Juan Pérez &lt;juan.perez@ejemplo.com&gt;</span>
                                </div>
                                <div class="email-meta-row">
                                    <span class="email-meta-label">Asunto:</span>
                                    <span class="email-meta-val fw-bold" id="prevAsunto">Comunicado Oficial de la Clínica</span>
                                </div>
                            </div>

                            <!-- Cuerpo del Mensaje Simulado -->
                            <div class="email-simulator-body" id="prevCuerpoContainer">
                                <div class="email-brand-header">
                                    <div class="fw-bold fs-5 text-primary" id="prevBrandName">OSPulso Red Dental</div>
                                    <span class="small text-muted" id="prevFechaEnvio">05 Oct 2026</span>
                                </div>
                                <div id="prevCuerpoTexto" style="white-space: pre-wrap; line-height: 1.6;">
Estimado(a) Juan Pérez,

Le saludamos cordialmente desde OSPulso Red Dental. Ponemos a su disposición este canal de comunicación directa para mantenerle informado sobre sus atenciones, novedades y servicios preventivos.

Atentamente,
El Equipo Médico
                                </div>
                                <div class="email-footer-legal">
                                    Este es un mensaje institucional seguro generado por OSPulso Dental Cloud.<br>
                                    Si no deseas recibir más avisos de este consultorio, haz clic en <a href="#" style="color: #64748B;">Desuscribirme</a>.
                                </div>
                            </div>
                        </div>

                        <div class="alert alert-light border mt-3 mb-0 small text-muted">
                            <i class="fa-solid fa-circle-info text-primary me-1"></i>
                            <strong>Nota de personalización:</strong> Al momento de enviar, las variables como <code>{{nombre}}</code> serán reemplazadas automáticamente por el nombre real de cada persona de la lista.
                        </div>
                    </div>
                </div>

            </div>
        </div>

        <!-- TAB 2: HISTORIAL Y TRAZABILIDAD -->
        <div class="tab-pane fade" id="tab-historial" role="tabpanel">
            <div class="panel-card">
                <div class="panel-header">
                    <h3 class="panel-title">
                        <i class="fa-solid fa-clock-rotate-left text-primary"></i> Registro de Campañas Anteriores
                    </h3>
                    <button class="btn btn-sm btn-outline-primary rounded-pill" id="btnRecargarHistorial">
                        <i class="fa-solid fa-arrows-rotate me-1"></i> Actualizar
                    </button>
                </div>

                <div class="table-responsive">
                    <table class="table table-hover align-middle" id="tblHistorialCampanas">
                        <thead class="table-light">
                            <tr>
                                <th>Fecha y Hora</th>
                                <th>Asunto / Campaña</th>
                                <th>Audiencia</th>
                                <th>Remitente</th>
                                <th class="text-center">Enviados</th>
                                <th class="text-center">Tasa Éxito</th>
                                <th class="text-center">Estado</th>
                            </tr>
                        </thead>
                        <tbody id="tbodyHistorial">
                            <tr>
                                <td>2026-10-04 11:30</td>
                                <td class="fw-bold">Recordatorio de Campaña Preventiva</td>
                                <td><span class="badge bg-light text-dark border">Todos los Pacientes</span></td>
                                <td>Dr. Roberto Martínez</td>
                                <td class="text-center">48 / 48</td>
                                <td class="text-center"><span class="badge bg-success-subtle text-success">100%</span></td>
                                <td class="text-center"><span class="badge bg-success">Completado</span></td>
                            </tr>
                            <tr>
                                <td>2026-09-28 09:15</td>
                                <td class="fw-bold">Aviso de Mantenimiento de Sucursal</td>
                                <td><span class="badge bg-light text-dark border">Personal Clínica</span></td>
                                <td>Administrador</td>
                                <td class="text-center">12 / 12</td>
                                <td class="text-center"><span class="badge bg-success-subtle text-success">100%</span></td>
                                <td class="text-center"><span class="badge bg-success">Completado</span></td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- TAB 3: BUENAS PRÁCTICAS ANTI-SPAM -->
        <div class="tab-pane fade" id="tab-guia" role="tabpanel">
            <div class="row g-4">
                <div class="col-md-6">
                    <div class="panel-card h-100">
                        <h4 class="panel-title text-success mb-3">
                            <i class="fa-solid fa-shield-check me-2"></i> Prácticas para Garantizar Entrega a Bandeja Principal
                        </h4>
                        <ul class="list-group list-group-flush small">
                            <li class="list-group-item px-0">
                                <strong>1. Personaliza siempre el saludo:</strong> Usa <code>{{nombre}}</code>. Los filtros anti-spam de Gmail y Outlook premian los correos individualizados.
                            </li>
                            <li class="list-group-item px-0">
                                <strong>2. Evita palabras trampa en el asunto:</strong> No uses mayúsculas sostenidas ("URGENTE", "GRATIS", "GANA DINERO") ni signos de exclamación excesivos ("!!!").
                            </li>
                            <li class="list-group-item px-0">
                                <strong>3. Despacho en lotes pequeños:</strong> Nuestro motor envía en bloques de 10 correos con intervalos controlados para no saturar el servidor SMTP de cPanel.
                            </li>
                            <li class="list-group-item px-0">
                                <strong>4. Calidad sobre cantidad:</strong> Envía comunicados relevantes a pacientes que hayan asistido recientemente a consulta.
                            </li>
                        </ul>
                    </div>
                </div>

                <div class="col-md-6">
                    <div class="panel-card h-100">
                        <h4 class="panel-title text-danger mb-3">
                            <i class="fa-solid fa-triangle-exclamation me-2"></i> Lo que NUNCA debes hacer
                        </h4>
                        <ul class="list-group list-group-flush small">
                            <li class="list-group-item px-0">
                                <strong>1. No uses listas de correos compradas o externas:</strong> Solo envía a pacientes o usuarios registrados orgánicamente en el sistema.
                            </li>
                            <li class="list-group-item px-0">
                                <strong>2. No adjuntes archivos gigantes:</strong> Mantén los documentos o folletos en menos de 5 MB.
                            </li>
                            <li class="list-group-item px-0">
                                <strong>3. No envíes correos vacíos o con solo una imagen:</strong> Los filtros de spam penalizan correos sin texto real.
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>

    </div>

</div>

<!-- Modal de Despacho Progresivo en Lotes -->
<div class="modal fade dispatch-progress-modal" id="modalDespacho" data-bs-backdrop="static" data-bs-keyboard="false" tabindex="-1">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="dispatch-progress-header">
                <h5 class="modal-title fw-bold mb-1">
                    <i class="fa-solid fa-paper-plane me-2"></i> Despachando Campaña en Segundo Plano
                </h5>
                <p class="small text-white-50 mb-0" id="modalProgresoSubtitulo">
                    Enviando lotes controlados para proteger la reputación del servidor...
                </p>
            </div>
            <div class="modal-body p-4">
                
                <!-- Barra de Progreso -->
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <span class="fw-bold small text-dark" id="modalProgresoTexto">Procesando: 0%</span>
                    <span class="badge bg-primary rounded-pill" id="modalProgresoConteo">0 / 0</span>
                </div>
                <div class="progress progress-custom mb-3">
                    <div class="progress-bar progress-custom-bar" id="modalProgressBar" role="progressbar" style="width: 0%;"></div>
                </div>

                <!-- Log de Estado en Vivo -->
                <div class="bg-light p-3 rounded-3 border small" style="max-height: 140px; overflow-y: auto;" id="modalLogEnvio">
                    <div class="text-muted"><i class="fa-solid fa-gear fa-spin text-primary me-1"></i> Inicializando cola de envío...</div>
                </div>

                <!-- Botón de Cierre al Concluir -->
                <div class="text-center mt-4 d-none" id="modalFooterFinalizado">
                    <button type="button" class="btn btn-success px-4 py-2 rounded-pill fw-bold" data-bs-dismiss="modal" id="btnCerrarModalExito">
                        <i class="fa-solid fa-check-circle me-1"></i> Campaña Completada con Éxito
                    </button>
                </div>

            </div>
        </div>
    </div>
</div>
PAGE_HTML

# Aislamiento Estricto de Javascript (Sin colisión de sigilos con Perl)
print <<'JS';
<script>
document.addEventListener('DOMContentLoaded', function () {
    console.log('[Comunicación Masiva] Inicializando controlador frontend.');

    // 1. Obtención segura de metadatos desde el DOM
    const configEl = document.getElementById('comunicacionConfig');
    const rolUsuario = configEl ? configEl.dataset.rol : 'Staff';
    const nombreUsuario = configEl ? configEl.dataset.usuario : 'Usuario';
    const idEmpresa = configEl ? configEl.dataset.idEmpresa : '0';

    // 2. Elementos Clave
    const selAudiencia = document.getElementById('selAudiencia');
    const txtTotalDestinatarios = document.getElementById('txtTotalDestinatarios');
    const iptAsunto = document.getElementById('iptAsunto');
    const txtCuerpo = document.getElementById('txtCuerpo');

    // Elementos del Simulador
    const prevAsunto = document.getElementById('prevAsunto');
    const prevCuerpoTexto = document.getElementById('prevCuerpoTexto');
    const prevRemitente = document.getElementById('prevRemitente');
    const prevBrandName = document.getElementById('prevBrandName');

    // Ajustar remitente y marca según el rol activo
    if (rolUsuario.includes('Administrador Global') || rolUsuario.includes('Ventas')) {
        prevRemitente.innerText = 'OSPulso Plataforma <notificaciones@ospulso.com>';
        prevBrandName.innerText = 'OSPulso Cloud Dental';
    } else {
        prevRemitente.innerText = nombreUsuario + ' <clinica@ospulso.com>';
        prevBrandName.innerText = 'Consultorio Médico & Dental';
    }

    // 3. Simulación Reactiva de Conteo de Destinatarios según Audiencia
    function actualizarConteoAudiencia() {
        const val = selAudiencia ? selAudiencia.value : '';
        let conteo = 0;

        switch (val) {
            case 'todos_admin_org':
                conteo = 4;
                break;
            case 'ejecutivos_ventas':
                conteo = 2;
                break;
            case 'broadcast_plataforma':
                conteo = 18;
                break;
            case 'todos_pacientes_global':
            case 'todos_pacientes_clinica':
                conteo = 35;
                break;
            case 'personal_clinica':
                conteo = 8;
                break;
            case 'solo_medicos':
                conteo = 3;
                break;
            case 'solo_recepcion':
                conteo = 5;
                break;
            case 'mis_pacientes':
                conteo = 14;
                break;
            case 'mis_cuentas_org':
                conteo = 4;
                break;
            default:
                conteo = 12;
                break;
        }

        if (txtTotalDestinatarios) {
            txtTotalDestinatarios.innerText = conteo;
        }
    }

    if (selAudiencia) {
        selAudiencia.addEventListener('change', actualizarConteoAudiencia);
        actualizarConteoAudiencia();
    }

    // 4. Actualización en Tiempo Real del Simulador
    function refrescarSimulador() {
        const asunto = iptAsunto.value.trim() || 'Sin Asunto';
        prevAsunto.innerText = asunto;

        let cuerpo = txtCuerpo.value.trim();
        if (!cuerpo) {
            cuerpo = 'Estimado(a) Juan Pérez,\n\nEscribe en el panel izquierdo para ver la simulación en tiempo real de tu correo...';
        } else {
            // Sustituir variables de ejemplo en la vista previa
            cuerpo = cuerpo.replace(/{{nombre}}/g, 'Juan Pérez')
                           .replace(/{{clinica}}/g, prevBrandName.innerText)
                           .replace(/{{medico}}/g, 'Dr. ' + nombreUsuario)
                           .replace(/{{fecha}}/g, new Date().toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' }));
        }
        prevCuerpoTexto.innerText = cuerpo;
    }

    if (iptAsunto) iptAsunto.addEventListener('input', refrescarSimulador);
    if (txtCuerpo) txtCuerpo.addEventListener('input', refrescarSimulador);

    // 5. Inserción de Variables Dinámicas en la posición del cursor
    document.querySelectorAll('.btn-tag-variable').forEach(function (btn) {
        btn.addEventListener('click', function () {
            const tag = this.dataset.tag;
            if (!txtCuerpo) return;

            const startPos = txtCuerpo.selectionStart;
            const endPos = txtCuerpo.selectionEnd;
            const text = txtCuerpo.value;

            txtCuerpo.value = text.substring(0, startPos) + tag + text.substring(endPos, text.length);
            txtCuerpo.focus();
            txtCuerpo.selectionStart = startPos + tag.length;
            txtCuerpo.selectionEnd = startPos + tag.length;

            refrescarSimulador();
        });
    });

    // 6. Cargar Plantilla de Ejemplo
    const btnCargarPlantilla = document.getElementById('btnCargarPlantillaEjemplo');
    if (btnCargarPlantilla) {
        btnCargarPlantilla.addEventListener('click', function () {
            if (iptAsunto) {
                iptAsunto.value = 'Aviso Importante: Cuidados Preventivos y Horarios de Atención';
            }
            if (txtCuerpo) {
                txtCuerpo.value = 'Estimado(a) {{nombre}},\n\nEsperamos que te encuentres muy bien. Desde {{clinica}} queremos recordarte la importancia de mantener al día tus revisiones periódicas y cuidados preventivos de salud.\n\nTe compartimos que nuestros horarios de consulta habituales son de Lunes a Sábado de 09:00 a 19:00 hrs. Si necesitas agendar o reprogramar tu próxima visita con {{medico}}, puedes responder directamente a este correo o comunicarte con recepción.\n\n¡Cuidar de tu bienestar es nuestra prioridad!\n\nAtentamente,\nEl Equipo de {{clinica}}';
            }
            refrescarSimulador();
        });
    }

    // 7. Simulación Interactiva del Despacho por Lotes (Modal con Barra de Progreso)
    const btnLanzar = document.getElementById('btnLanzarCampana');
    const modalEl = document.getElementById('modalDespacho');
    const progressBar = document.getElementById('modalProgressBar');
    const progresoTexto = document.getElementById('modalProgresoTexto');
    const progresoConteo = document.getElementById('modalProgresoConteo');
    const logEnvio = document.getElementById('modalLogEnvio');
    const footerFinalizado = document.getElementById('modalFooterFinalizado');

    if (btnLanzar && modalEl) {
        btnLanzar.addEventListener('click', function () {
            const asunto = iptAsunto.value.trim();
            const cuerpo = txtCuerpo.value.trim();

            if (!asunto) {
                alert('Por favor introduce un asunto para la campaña.');
                iptAsunto.focus();
                return;
            }
            if (!cuerpo) {
                alert('Por favor redacta el mensaje o carga una plantilla.');
                txtCuerpo.focus();
                return;
            }

            const total = parseInt(txtTotalDestinatarios.innerText, 10) || 10;
            const bsModal = new bootstrap.Modal(modalEl);
            bsModal.show();

            // Reset de Modal
            progressBar.style.width = '0%';
            progresoTexto.innerText = 'Iniciando despacho...';
            progresoConteo.innerText = '0 / ' + total;
            logEnvio.innerHTML = '<div class="text-muted"><i class="fa-solid fa-spinner fa-spin text-primary me-1"></i> Conectando al servidor SMTP y preparando cola...</div>';
            footerFinalizado.classList.add('d-none');

            // Simulación de Lotes Progresivos
            let enviados = 0;
            const paso = Math.max(1, Math.ceil(total / 4));

            const timer = setInterval(function () {
                enviados += paso;
                if (enviados > total) enviados = total;

                const porcentaje = Math.round((enviados / total) * 100);
                progressBar.style.width = porcentaje + '%';
                progresoTexto.innerText = 'Enviando por lotes: ' + porcentaje + '%';
                progresoConteo.innerText = enviados + ' / ' + total;

                const logItem = document.createElement('div');
                logItem.className = 'text-success mt-1';
                logItem.innerHTML = '<i class="fa-solid fa-check text-success me-1"></i> Lote despachado exitosamente (' + enviados + ' de ' + total + ' entregados)';
                logEnvio.appendChild(logItem);
                logEnvio.scrollTop = logEnvio.scrollHeight;

                if (enviados >= total) {
                    clearInterval(timer);
                    progresoTexto.innerText = '¡Envío completado al 100%!';
                    footerFinalizado.classList.remove('d-none');
                }
            }, 800);
        });
    }
});
</script>
JS

# Renderizado del Menú Inferior Móvil Estándar
render_bottom_nav(
    role          => $role,
    pagina_actual => 'comunicacion_masiva',
    id_medico     => $id_medico
);

print "</body>\n</html>";
