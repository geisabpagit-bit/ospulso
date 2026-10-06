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

    <!-- Hero Header Institucional Alto Contraste -->
    <div class="comunicacion-hero">
        <div class="d-flex align-items-center gap-3">
            <div class="comunicacion-hero-icon-box">
                <i class="fa-solid fa-paper-plane"></i>
            </div>
            <div>
                <h1 class="comunicacion-hero-title">
                    Centro de Comunicaciones y Difusión
                </h1>
                <p class="comunicacion-hero-subtitle">
                    Emisión de comunicados, campañas y recordatorios por correo masivo segmentado
                </p>
            </div>
        </div>
        <div class="d-flex align-items-center gap-2">
            <span class="comunicacion-role-badge">
                <i class="fa-solid fa-shield-halved me-1"></i> Rol: $role
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
            <button class="nav-link" id="tab-plantillas-btn" data-bs-toggle="tab" data-bs-target="#tab-plantillas" type="button" role="tab">
                <i class="fa-solid fa-folder-open"></i> Plantillas Clínicas
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
                            
                            <!-- Indicador de Salud y Entregabilidad (Spam Score Meter) -->
                            <div class="spam-meter-card" id="spamMeterCard">
                                <div class="d-flex justify-content-between align-items-center">
                                    <span class="small fw-bold text-dark"><i class="fa-solid fa-gauge-high text-primary me-1"></i> Índice de Entregabilidad (Anti-SPAM)</span>
                                    <span class="badge bg-success fw-bold" id="spamScoreBadge">95% Excelente</span>
                                </div>
                                <div class="spam-meter-bar">
                                    <div class="spam-meter-fill bg-success" id="spamMeterFill" style="width: 95%;"></div>
                                </div>
                                <p class="small text-muted mb-0" id="spamAdviceText">
                                    <i class="fa-solid fa-check text-success me-1"></i> Asunto balanceado y personalización dinámica detectada.
                                </p>
                            </div>
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
                                <th class="text-center">Acción</th>
                            </tr>
                        </thead>
                        <tbody id="tbodyHistorial">
                            <tr>
                                <td colspan="8" class="text-center py-4 text-muted">
                                    <i class="fa-solid fa-spinner fa-spin me-2 text-primary"></i> Cargando historial de campañas...
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- TAB 3: PLANTILLAS CLÍNICAS E INSTITUCIONALES -->
        <div class="tab-pane fade" id="tab-plantillas" role="tabpanel">
            <div class="panel-card mb-4">
                <div class="panel-header">
                    <div>
                        <h3 class="panel-title">
                            <i class="fa-solid fa-folder-open text-primary"></i> Biblioteca de Plantillas Profesionales
                        </h3>
                        <p class="text-muted small mb-0">Selecciona una plantilla prediseñada para cargarla directamente en el redactor</p>
                    </div>
                </div>

                <div class="row g-3">
                    <!-- Plantilla 1: Prevención y Chequeo Anual -->
                    <div class="col-md-6 col-lg-3">
                        <div class="template-card">
                            <div>
                                <div class="template-icon-box">
                                    <i class="fa-solid fa-heart-pulse"></i>
                                </div>
                                <span class="badge bg-primary-subtle text-primary mb-2">Clínica / Prevención</span>
                                <h5 class="fw-bold fs-6 text-dark mb-2">Chequeo Médico Preventivo</h5>
                                <p class="text-muted small mb-3">Recordatorio para pacientes enfocado en la importancia de revisiones periódicas anuales.</p>
                            </div>
                            <button type="button" class="btn btn-sm btn-outline-primary w-100 rounded-pill btn-usar-plantilla" 
                                    data-asunto="Recordatorio de Chequeo Médico Preventivo y Revisión Periódica"
                                    data-cuerpo="Estimado(a) {{nombre}},&#10;&#10;Esperamos que te encuentres con excelente salud. Desde {{clinica}} queremos recordarte la importancia de mantener al día tus revisiones preventivas periódicas con {{medico}}.&#10;&#10;La detección temprana es el pilar de tu bienestar. Si deseas agendar o reprogramar tu próxima cita, puedes responder directamente a este correo o llamar a recepción.&#10;&#10;¡Cuidar de ti es nuestra prioridad!&#10;&#10;Atentamente,&#10;El Equipo de {{clinica}}">
                                <i class="fa-solid fa-file-import me-1"></i> Usar Plantilla
                            </button>
                        </div>
                    </div>

                    <!-- Plantilla 2: Días Festivos y Horarios -->
                    <div class="col-md-6 col-lg-3">
                        <div class="template-card">
                            <div>
                                <div class="template-icon-box" style="background: rgba(14, 165, 233, 0.1); color: #0EA5E9;">
                                    <i class="fa-regular fa-calendar-check"></i>
                                </div>
                                <span class="badge bg-info-subtle text-info mb-2">Administrativo</span>
                                <h5 class="fw-bold fs-6 text-dark mb-2">Horarios en Días Festivos</h5>
                                <p class="text-muted small mb-3">Comunicado oficial para informar modificaciones en los días de atención y guardias.</p>
                            </div>
                            <button type="button" class="btn btn-sm btn-outline-primary w-100 rounded-pill btn-usar-plantilla"
                                    data-asunto="Aviso Importante: Horarios de Atención en Días Festivos"
                                    data-cuerpo="Estimado(a) {{nombre}},&#10;&#10;Te informamos que con motivo de las fechas festivas próximas, nuestros horarios de atención en {{clinica}} tendrán ajustes temporales.&#10;&#10;Nuestras consultas regulares y servicio de citas operarán en su horario habitual a partir de la siguiente semana. En caso de emergencias o para reprogramar una cita ya agendada con {{medico}}, nuestro conmutador permanecerá disponible.&#10;&#10;¡Te deseamos excelentes días!&#10;&#10;Atentamente,&#10;Administración de {{clinica}}">
                                <i class="fa-solid fa-file-import me-1"></i> Usar Plantilla
                            </button>
                        </div>
                    </div>

                    <!-- Plantilla 3: Cuidados Post-Consulta -->
                    <div class="col-md-6 col-lg-3">
                        <div class="template-card">
                            <div>
                                <div class="template-icon-box" style="background: rgba(234, 179, 8, 0.1); color: #EAB308;">
                                    <i class="fa-solid fa-notes-medical"></i>
                                </div>
                                <span class="badge bg-warning-subtle text-dark mb-2">Seguimiento</span>
                                <h5 class="fw-bold fs-6 text-dark mb-2">Cuidados Post-Tratamiento</h5>
                                <p class="text-muted small mb-3">Mensaje de acompañamiento clínico para asegurar el cumplimiento del tratamiento.</p>
                            </div>
                            <button type="button" class="btn btn-sm btn-outline-primary w-100 rounded-pill btn-usar-plantilla"
                                    data-asunto="Recomendaciones y Seguimiento Tras tu Consulta Médica"
                                    data-cuerpo="Hola {{nombre}},&#10;&#10;Esperamos que te encuentres muy bien tras tu reciente atención con {{medico}} en {{clinica}}.&#10;&#10;Te recordamos la importancia de seguir al pie de la letra las indicaciones de tu receta médica, mantener reposo si te fue prescrito e hidratarte adecuadamente. Si notas cualquier síntoma inesperado, ponte en contacto de inmediato con nosotros.&#10;&#10;¡Deseamos tu pronta recuperación!&#10;&#10;Atentamente,&#10;{{medico}} y el equipo de {{clinica}}">
                                <i class="fa-solid fa-file-import me-1"></i> Usar Plantilla
                            </button>
                        </div>
                    </div>

                    <!-- Plantilla 4: Activación Portal Paciente -->
                    <div class="col-md-6 col-lg-3">
                        <div class="template-card">
                            <div>
                                <div class="template-icon-box" style="background: rgba(168, 85, 247, 0.1); color: #A855F7;">
                                    <i class="fa-solid fa-laptop-medical"></i>
                                </div>
                                <span class="badge bg-purple-subtle text-purple mb-2">Portal Digital</span>
                                <h5 class="fw-bold fs-6 text-dark mb-2">Bienvenida al Portal Digital</h5>
                                <p class="text-muted small mb-3">Invitación para consultar recetas, historial de visitas y comprobantes en línea.</p>
                            </div>
                            <button type="button" class="btn btn-sm btn-outline-primary w-100 rounded-pill btn-usar-plantilla"
                                    data-asunto="Activación de tu Expediente y Portal Digital en OSPulso"
                                    data-cuerpo="Estimado(a) {{nombre}},&#10;&#10;En {{clinica}} tenemos el gusto de informarte que ya se encuentra habilitado tu acceso a la plataforma de salud digital OSPulso.&#10;&#10;A través del Portal del Paciente podrás revisar tus recetas electrónicas, descargar recibos fiscales de caja y consultar tu historial de consultas en cualquier momento de manera 100% segura.&#10;&#10;Accede utilizando este correo electrónico para iniciar sesión.&#10;&#10;Atentamente,&#10;El Equipo de {{clinica}}">
                                <i class="fa-solid fa-file-import me-1"></i> Usar Plantilla
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- TAB 4: BUENAS PRÁCTICAS ANTI-SPAM -->
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
            <div class="dispatch-progress-header d-flex justify-content-between align-items-start">
                <div>
                    <h5 class="modal-title fw-bold mb-1">
                        <i class="fa-solid fa-paper-plane me-2"></i> Despachando Campaña en Segundo Plano
                    </h5>
                    <p class="small text-white-50 mb-0" id="modalProgresoSubtitulo">
                        Enviando lotes controlados para proteger la reputación del servidor...
                    </p>
                </div>
                <button type="button" class="btn-close btn-close-white d-none" id="btnCerrarModalX" data-bs-dismiss="modal" aria-label="Cerrar"></button>
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

<!-- Modal de Auditoría de Campaña -->
<div class="modal fade" id="modalAuditoriaCampana" tabindex="-1">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content" style="border-radius: 1rem; overflow: hidden; border: none; box-shadow: 0 20px 40px rgba(10, 42, 102, 0.2);">
            <div class="modal-header text-white" style="background: linear-gradient(135deg, #0A2A66, #124A9E); padding: 1.25rem 1.5rem;">
                <h5 class="modal-title fw-bold">
                    <i class="fa-solid fa-list-check me-2" style="color: #19B7A5;"></i> Auditoría de Campaña: <span id="auditCampanaId">--</span>
                </h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4">
                <div class="row g-3 mb-3 bg-light p-3 rounded-3 border">
                    <div class="col-sm-6">
                        <div class="small text-muted fw-bold">Asunto:</div>
                        <div class="fw-bold text-dark" id="auditAsunto">--</div>
                    </div>
                    <div class="col-sm-3">
                        <div class="small text-muted fw-bold">Fecha / Hora:</div>
                        <div class="text-dark" id="auditFecha">--</div>
                    </div>
                    <div class="col-sm-3">
                        <div class="small text-muted fw-bold">Remitente:</div>
                        <div class="text-dark" id="auditRemitente">--</div>
                    </div>
                </div>
                
                <h6 class="fw-bold text-dark mb-2">Desglose de Destinatarios y Envíos</h6>
                <div class="table-responsive">
                    <table class="table table-sm table-hover align-middle">
                        <thead class="table-light">
                            <tr>
                                <th>Nombre</th>
                                <th>Correo</th>
                                <th class="text-center">Estado</th>
                                <th class="text-center">Intentos</th>
                                <th>Detalle / Fecha</th>
                            </tr>
                        </thead>
                        <tbody id="tbodyAuditDestinatarios">
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="modal-footer bg-light">
                <button type="button" class="btn btn-secondary rounded-pill px-4" data-bs-dismiss="modal">Cerrar</button>
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

    // 3. Conteo Dinámico en Vivo de Destinatarios consultando la API Backend
    function actualizarConteoAudiencia() {
        const val = selAudiencia ? selAudiencia.value : '';
        if (!val) return;

        if (txtTotalDestinatarios) {
            txtTotalDestinatarios.innerText = '...';
        }

        fetch('../api/comunicacion_audiencia_api.pl?segmento=' + encodeURIComponent(val))
            .then(res => res.json())
            .then(data => {
                if (data.ok && txtTotalDestinatarios) {
                    txtTotalDestinatarios.innerText = data.total_destinatarios;
                } else if (txtTotalDestinatarios) {
                    txtTotalDestinatarios.innerText = '0';
                }
            })
            .catch(err => {
                console.error('[Comunicación] Error al consultar audiencia:', err);
                if (txtTotalDestinatarios) txtTotalDestinatarios.innerText = '0';
            });
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
            cuerpo = cuerpo.replace(/\{\{nombre\}\}/g, 'Juan Pérez')
                           .replace(/\{\{clinica\}\}/g, prevBrandName.innerText)
                           .replace(/\{\{medico\}\}/g, 'Dr. ' + nombreUsuario)
                           .replace(/\{\{fecha\}\}/g, new Date().toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' }));
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

    // 7. Despacho Real Progresivo por Lotes (API Encolar + API Despachar)
    const btnLanzar = document.getElementById('btnLanzarCampana');
    const modalEl = document.getElementById('modalDespacho');
    const progressBar = document.getElementById('modalProgressBar');
    const progresoTexto = document.getElementById('modalProgresoTexto');
    const progresoConteo = document.getElementById('modalProgresoConteo');
    const logEnvio = document.getElementById('modalLogEnvio');
    const footerFinalizado = document.getElementById('modalFooterFinalizado');
    const btnCerrarModalX = document.getElementById('btnCerrarModalX');
    const btnCerrarModalExito = document.getElementById('btnCerrarModalExito');

    function cerrarModalDespachoSeguro() {
        if (!modalEl) return;
        const inst = bootstrap.Modal.getInstance(modalEl) || bootstrap.Modal.getOrCreateInstance(modalEl);
        if (inst) inst.hide();
        setTimeout(function () {
            document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
            document.body.classList.remove('modal-open');
            document.body.style.removeProperty('overflow');
            document.body.style.removeProperty('padding-right');
        }, 200);
    }

    if (btnCerrarModalExito) btnCerrarModalExito.addEventListener('click', cerrarModalDespachoSeguro);
    if (btnCerrarModalX) btnCerrarModalX.addEventListener('click', cerrarModalDespachoSeguro);

    if (modalEl) {
        modalEl.addEventListener('hidden.bs.modal', function () {
            setTimeout(function () {
                document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
                document.body.classList.remove('modal-open');
                document.body.style.removeProperty('overflow');
                document.body.style.removeProperty('padding-right');
            }, 100);
        });
    }

    if (btnLanzar && modalEl) {
        btnLanzar.addEventListener('click', function () {
            const asunto = iptAsunto.value.trim();
            const cuerpo = txtCuerpo.value.trim();
            const segmento = selAudiencia ? selAudiencia.value : '';

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

            const bsModal = bootstrap.Modal.getOrCreateInstance(modalEl);
            bsModal.show();

            // Reset de Modal
            progressBar.style.width = '0%';
            progresoTexto.innerText = 'Encolando campaña...';
            progresoConteo.innerText = '0 / --';
            logEnvio.innerHTML = '<div class="text-muted"><i class="fa-solid fa-spinner fa-spin text-primary me-1"></i> Registrando campaña y resolviendo lista de destinatarios...</div>';
            footerFinalizado.classList.add('d-none');
            if (btnCerrarModalX) btnCerrarModalX.classList.add('d-none');

            // 1. Encolar Campaña en Backend
            const formData = new URLSearchParams();
            formData.append('asunto', asunto);
            formData.append('cuerpo', cuerpo);
            formData.append('segmento', segmento);

            fetch('../api/crear_campana_correo_api.pl', {
                method: 'POST',
                body: formData
            })
            .then(res => res.json())
            .then(data => {
                if (!data.ok) {
                    logEnvio.innerHTML += '<div class="text-danger mt-1"><i class="fa-solid fa-triangle-exclamation me-1"></i> ' + (data.msg || 'Error al encolar') + '</div>';
                    progresoTexto.innerText = 'Error en encolado';
                    footerFinalizado.classList.remove('d-none');
                    if (btnCerrarModalX) btnCerrarModalX.classList.remove('d-none');
                    return;
                }

                const idCampana = data.id_campana;
                const totalDest = data.total;
                progresoConteo.innerText = '0 / ' + totalDest;
                logEnvio.innerHTML += '<div class="text-success mt-1"><i class="fa-solid fa-check text-success me-1"></i> ' + data.msg + '</div>';

                // 2. Función Recursiva de Despacho por Lotes
                function procesarSiguienteLote() {
                    fetch('../api/despachar_lote_correos_api.pl?id_campana=' + encodeURIComponent(idCampana) + '&lote_size=5')
                        .then(r => r.json())
                        .then(batchRes => {
                            if (!batchRes.ok) {
                                logEnvio.innerHTML += '<div class="text-danger mt-1">Error en lote: ' + (batchRes.msg || 'Desconocido') + '</div>';
                                footerFinalizado.classList.remove('d-none');
                                if (btnCerrarModalX) btnCerrarModalX.classList.remove('d-none');
                                return;
                            }

                            const procesados = totalDest - batchRes.pendientes_restantes;
                            const pct = batchRes.porcentaje;
                            progressBar.style.width = pct + '%';
                            progresoTexto.innerText = 'Despachando lotes: ' + pct + '%';
                            progresoConteo.innerText = procesados + ' / ' + totalDest;

                            const itemLog = document.createElement('div');
                            itemLog.className = 'text-success mt-1';
                            itemLog.innerHTML = '<i class="fa-solid fa-paper-plane text-primary me-1"></i> Lote despachado (' + procesados + ' de ' + totalDest + ' entregados)';
                            logEnvio.appendChild(itemLog);
                            logEnvio.scrollTop = logEnvio.scrollHeight;

                            if (!batchRes.completado) {
                                // Pausa de 600ms para no saturar
                                setTimeout(procesarSiguienteLote, 600);
                            } else {
                                progressBar.style.width = '100%';
                                progresoTexto.innerText = '¡Campaña finalizada al 100%!';
                                footerFinalizado.classList.remove('d-none');
                                if (btnCerrarModalX) btnCerrarModalX.classList.remove('d-none');
                                cargarHistorialCampanas(); // Refrescar automáticamente historial
                            }
                        })
                        .catch(err => {
                            console.error('[Comunicación] Error de red en lote:', err);
                            logEnvio.innerHTML += '<div class="text-danger mt-1">Error de conexión al despachar lote.</div>';
                            footerFinalizado.classList.remove('d-none');
                            if (btnCerrarModalX) btnCerrarModalX.classList.remove('d-none');
                        });
                }

                procesarSiguienteLote();
            })
            .catch(err => {
                console.error('[Comunicación] Error al crear campaña:', err);
                logEnvio.innerHTML += '<div class="text-danger mt-1">Error de conexión con el servidor.</div>';
                footerFinalizado.classList.remove('d-none');
                if (btnCerrarModalX) btnCerrarModalX.classList.remove('d-none');
            });
        });
    }


    // 8. Calculadora Reactiva de Salud y Entregabilidad (Spam Score)
    const spamScoreBadge = document.getElementById('spamScoreBadge');
    const spamMeterFill = document.getElementById('spamMeterFill');
    const spamAdviceText = document.getElementById('spamAdviceText');

    function calcularSpamScore() {
        if (!iptAsunto || !txtCuerpo || !spamScoreBadge) return;

        const asunto = iptAsunto.value.trim();
        const cuerpo = txtCuerpo.value.trim();

        let score = 100;
        let consejos = [];

        // Evaluar Asunto
        if (asunto.length < 10) {
            score -= 20;
            consejos.push('El asunto es muy corto');
        } else if (asunto.length > 90) {
            score -= 15;
            consejos.push('El asunto es demasiado extenso (más de 90 letras)');
        }

        // Mayúsculas excesivas en asunto
        const upperCount = (asunto.match(/[A-ZÁÉÍÓÚÑ]/g) || []).length;
        if (asunto.length > 0 && (upperCount / asunto.length) > 0.4) {
            score -= 25;
            consejos.push('Demasiadas MAYÚSCULAS en el asunto');
        }

        // Palabras detonantes de Spam
        const spamTriggers = /gratis|urgente|gana dinero|100% gratis|oferta exclusiva|sin costo|$$$/i;
        if (spamTriggers.test(asunto) || spamTriggers.test(cuerpo)) {
            score -= 30;
            consejos.push('Detectadas palabras comúnmente bloqueadas por filtros (ej. "gratis", "urgente")');
        }

        // Presencia de personalización dinámica
        if (!cuerpo.includes('{{nombre}}')) {
            score -= 15;
            consejos.push('Agrega {{nombre}} para mejorar la tasa de apertura y evitar spam');
        }

        if (score < 10) score = 10;

        spamMeterFill.style.width = score + '%';
        if (score >= 85) {
            spamScoreBadge.className = 'badge bg-success fw-bold';
            spamScoreBadge.innerText = score + '% Excelente';
            spamMeterFill.className = 'spam-meter-fill bg-success';
            spamAdviceText.innerHTML = '<i class="fa-solid fa-check text-success me-1"></i> Asunto equilibrado y personalización dinámica óptima.';
        } else if (score >= 60) {
            spamScoreBadge.className = 'badge bg-warning text-dark fw-bold';
            spamScoreBadge.innerText = score + '% Aceptable';
            spamMeterFill.className = 'spam-meter-fill bg-warning';
            spamAdviceText.innerHTML = '<i class="fa-solid fa-circle-exclamation text-warning me-1"></i> ' + consejos.join('. ') + '.';
        } else {
            spamScoreBadge.className = 'badge bg-danger fw-bold';
            spamScoreBadge.innerText = score + '% Riesgo Spam';
            spamMeterFill.className = 'spam-meter-fill bg-danger';
            spamAdviceText.innerHTML = '<i class="fa-solid fa-triangle-exclamation text-danger me-1"></i> ' + consejos.join('. ') + '.';
        }
    }

    if (iptAsunto) iptAsunto.addEventListener('input', calcularSpamScore);
    if (txtCuerpo) txtCuerpo.addEventListener('input', calcularSpamScore);
    calcularSpamScore();

    // 9. Uso de Plantillas desde la Biblioteca (Tab 3)
    document.querySelectorAll('.btn-usar-plantilla').forEach(function (btn) {
        btn.addEventListener('click', function () {
            const asunto = this.dataset.asunto;
            const cuerpo = this.dataset.cuerpo;

            if (iptAsunto) iptAsunto.value = asunto;
            if (txtCuerpo) txtCuerpo.value = cuerpo;

            refrescarSimulador();
            calcularSpamScore();

            // Cambiar a la Pestaña 1 (Nueva Campaña)
            const tabNuevaBtn = document.getElementById('tab-nueva-btn');
            if (tabNuevaBtn) {
                const tabTrigger = new bootstrap.Tab(tabNuevaBtn);
                tabTrigger.show();
            }
        });
    });

    // 10. Historial y Trazabilidad de Campañas Anteriores (Tab 2)
    const tbodyHistorial = document.getElementById('tbodyHistorial');
    const btnRecargarHistorial = document.getElementById('btnRecargarHistorial');
    const tabHistorialBtn = document.getElementById('tab-historial-btn');

    function cargarHistorialCampanas() {
        if (!tbodyHistorial) return;
        tbodyHistorial.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-muted"><i class="fa-solid fa-spinner fa-spin me-2 text-primary"></i> Consultando historial de campañas...</td></tr>';

        fetch('../api/listar_campanas_comunicacion_api.pl')
            .then(res => res.json())
            .then(data => {
                if (!data.ok || !data.campanas || data.campanas.length === 0) {
                    tbodyHistorial.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-muted"><i class="fa-solid fa-inbox me-2"></i> No se han registrado campañas de correo todavía.</td></tr>';
                    return;
                }

                let html = '';
                data.campanas.forEach(function (c) {
                    const badgeEstado = (c.estado === 'COMPLETADO') 
                        ? '<span class="badge bg-success">Completado</span>' 
                        : '<span class="badge bg-warning text-dark">En Proceso</span>';

                    html += '<tr>' +
                        '<td><span class="small fw-bold text-dark">' + c.fecha + '</span> <span class="small text-muted d-block">' + c.hora + '</span></td>' +
                        '<td><div class="fw-bold text-dark">' + c.asunto + '</div><span class="badge bg-light text-muted border">' + c.id_campana + '</span></td>' +
                        '<td><span class="badge bg-light text-dark border">' + c.segmento + '</span></td>' +
                        '<td><span class="small text-dark">' + c.remitente + '</span></td>' +
                        '<td class="text-center fw-bold">' + c.enviados + ' / ' + c.total + '</td>' +
                        '<td class="text-center"><span class="badge bg-success-subtle text-success">' + c.tasa_exito + '</span></td>' +
                        '<td class="text-center">' + badgeEstado + '</td>' +
                        '<td class="text-center">' +
                            '<button type="button" class="btn btn-sm btn-outline-primary rounded-pill btn-ver-auditoria" data-id="' + c.id_campana + '">' +
                                '<i class="fa-solid fa-magnifying-glass me-1"></i> Detalle' +
                            '</button>' +
                        '</td>' +
                    '</tr>';
                });

                tbodyHistorial.innerHTML = html;

                // Eventos de Detalle / Auditoría
                document.querySelectorAll('.btn-ver-auditoria').forEach(function (btn) {
                    btn.addEventListener('click', function () {
                        const id = this.dataset.id;
                        abrirAuditoriaCampana(id);
                    });
                });
            })
            .catch(err => {
                console.error('[Comunicación] Error al cargar historial:', err);
                tbodyHistorial.innerHTML = '<tr><td colspan="8" class="text-center py-4 text-danger"><i class="fa-solid fa-triangle-exclamation me-2"></i> Error al conectar con el servidor de historial.</td></tr>';
            });
    }

    if (btnRecargarHistorial) btnRecargarHistorial.addEventListener('click', cargarHistorialCampanas);
    if (tabHistorialBtn) tabHistorialBtn.addEventListener('shown.bs.tab', cargarHistorialCampanas);

    // 11. Modal de Auditoría de Destinatarios de una Campaña
    const modalAuditoriaEl = document.getElementById('modalAuditoriaCampana');
    const auditCampanaId = document.getElementById('auditCampanaId');
    const auditAsunto = document.getElementById('auditAsunto');
    const auditFecha = document.getElementById('auditFecha');
    const auditRemitente = document.getElementById('auditRemitente');
    const tbodyAudit = document.getElementById('tbodyAuditDestinatarios');

    function abrirAuditoriaCampana(idCampana) {
        if (!modalAuditoriaEl) return;
        const bsAuditModal = new bootstrap.Modal(modalAuditoriaEl);
        bsAuditModal.show();

        auditCampanaId.innerText = idCampana;
        auditAsunto.innerText = 'Cargando...';
        auditFecha.innerText = '--';
        auditRemitente.innerText = '--';
        tbodyAudit.innerHTML = '<tr><td colspan="5" class="text-center py-4 text-muted"><i class="fa-solid fa-spinner fa-spin me-2 text-primary"></i> Cargando destinatarios...</td></tr>';

        fetch('../api/detalle_campana_comunicacion_api.pl?id_campana=' + encodeURIComponent(idCampana))
            .then(res => res.json())
            .then(data => {
                if (!data.ok || !data.campana) {
                    tbodyAudit.innerHTML = '<tr><td colspan="5" class="text-center py-4 text-danger">No se pudo cargar la información de la campaña.</td></tr>';
                    return;
                }

                auditAsunto.innerText = data.campana.asunto;
                auditFecha.innerText = data.campana.fecha + ' ' + data.campana.hora;
                auditRemitente.innerText = data.campana.remitente;

                if (!data.destinatarios || data.destinatarios.length === 0) {
                    tbodyAudit.innerHTML = '<tr><td colspan="5" class="text-center py-4 text-muted">No se encontraron destinatarios registrados en la cola.</td></tr>';
                    return;
                }

                let rowsHtml = '';
                data.destinatarios.forEach(function (d) {
                    let stBadge = '<span class="badge bg-secondary">' + d.estado + '</span>';
                    if (d.estado === 'ENVIADO') stBadge = '<span class="badge bg-success">Enviado</span>';
                    else if (d.estado === 'FALLIDO') stBadge = '<span class="badge bg-danger">Fallido</span>';
                    else if (d.estado === 'PENDIENTE') stBadge = '<span class="badge bg-warning text-dark">Pendiente</span>';

                    rowsHtml += '<tr>' +
                        '<td class="fw-bold">' + (d.nombre || 'N/A') + '</td>' +
                        '<td>' + d.email + '</td>' +
                        '<td class="text-center">' + stBadge + '</td>' +
                        '<td class="text-center">' + d.intentos + '</td>' +
                        '<td class="small text-muted">' + (d.fecha_envio || d.error_msg || '-') + '</td>' +
                    '</tr>';
                });

                tbodyAudit.innerHTML = rowsHtml;
            })
            .catch(err => {
                console.error('[Comunicación] Error al cargar auditoría:', err);
                tbodyAudit.innerHTML = '<tr><td colspan="5" class="text-center py-4 text-danger">Error de comunicación con el servidor.</td></tr>';
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
