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

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";
use JSON::PP qw(encode_json);
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario    = $sd->{usuario};
my $role       = $sd->{role};
my $id_medico  = $sd->{id_medico} // '';
my $id_usuario_sesion = $sd->{id_registro} // $sd->{id_medico} // '';
my $id_negocio = $sd->{session} ? $sd->{session}->param('id_empresa') : ($sd->{id_empresa} // '');
$id_negocio = '0' if (!defined $id_negocio || $id_negocio eq '');
my $id_sucursal = $sd->{session} ? $sd->{session}->param('id_sucursal') : '';
my $id_negocio_activo = ($id_sucursal && $id_sucursal ne '0') ? $id_sucursal : $id_negocio;

# 1. Seguridad Estricta RBAC / Privacidad Multi-Tenant (NOM-004)
if ($role =~ /Administrador Global/i) {
    require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_acceso_denegado.pl');
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    render_acceso_denegado(
        q             => $q,
        usuario       => $usuario,
        role          => $role,
        titulo        => "Agenda de Espacios - Acceso Restringido",
        mensaje       => "Por políticas de privacidad multi-tenant (NOM-004), el Administrador Global no tiene acceso a las agendas operativas de las organizaciones.",
        rol_requerido => "Administrador Organización / Recepcionista / Médico"
    );
    exit;
}

# 2. Validar Capacidad SaaS "Renta de Espacios" y Permiso RBAC
my $tiene_cap_renta = 0;
my $tipo_organizacion = 'Clínica';
my $archivo_config = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $archivo_config && open my $fh_c, '<:encoding(UTF-8)', $archivo_config) {
    while (my $line = <$fh_c>) {
        $line =~ s/\R//g;
        next if $line =~ /^\s*$/ || $line =~ /^#/;
        my @f = split(/\|/, $line);
        if (($f[0] // '') eq $id_negocio) {
            if (($f[1] // '') eq 'TIPO_ORGANIZACION') {
                $tipo_organizacion = $f[2] // 'Clínica';
            } elsif (($f[1] // '') eq 'CAPACIDAD' && ($f[2] // '') eq 'Renta de Espacios') {
                $tiene_cap_renta = 1;
            }
        }
    }
    close $fh_c;
}

my $tiene_permiso_rbac = utils::permisos_utils::tiene_permiso_modulo($id_negocio, $role, 'agenda_espacios', 'R', $id_usuario_sesion);

if (!$tiene_cap_renta || !$tiene_permiso_rbac) {
    require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_acceso_denegado.pl');
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    my $msg_denegado = !$tiene_cap_renta
        ? "Esta organización no tiene habilitada la capacidad SaaS 'Renta de Espacios'."
        : "Su perfil actual no cuenta con permiso de lectura para el módulo Agenda de Espacios.";
    render_acceso_denegado(
        q             => $q,
        usuario       => $usuario,
        role          => $role,
        titulo        => "Agenda de Espacios - Módulo Restringido",
        mensaje       => $msg_denegado,
        rol_requerido => "Capacidad SaaS: Renta de Espacios"
    );
    exit;
}

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');

my $usuarios = leer_tabla($archivo_usuarios, '!');
my @medicos;
if ($usuarios) {
    foreach my $u (@$usuarios) {
        next unless defined $u->[4] && $u->[4] eq '1'; # Solo colaboradores activos
        my $es_medico = ($u->[5] =~ /(?:^|,)Medico(?:,|$)/) ||
                        ($u->[5] =~ /Administrador/ && defined $u->[7] && $u->[7] ne '' && $u->[7] ne '0');
        if ($es_medico && ($u->[6] =~ /^$id_negocio:/ || ($id_negocio eq '0' && $u->[6] =~ /^0:/))) {
            push @medicos, {
                id             => $u->[0],
                nombre         => $u->[1],
                correo         => $u->[2] // '',
                rol_quirurgico => $u->[12] // ''
            };
        }
    }
}

my $es_solo_admin_o_recep = ($role =~ /^(Administrador|Recepcion|Asistente)/i && $role !~ /Medico/i);
my $id_medico_activo = 'all';

my $html_medicos = qq(<option value="EXTERNO">-- Profesional / Arrendatario Externo --</option>\n);
my $html_filtro_medicos_toolbar = '';
if (scalar(@medicos) > 0) {
    my $items_m = qq{
        <label class="dropdown-item d-flex align-items-center gap-2 rounded-2 px-2 py-1.5 cursor-pointer user-select-none mb-0.5">
            <input type="checkbox" class="form-check-input mt-0 chk-medico-item" value="EXTERNO" onchange="window.onMedicoCheckChange()" checked>
            <i class="bi bi-person-Vcard text-teal" style="font-size:0.95rem;"></i>
            <span class="fw-semibold text-navy small text-truncate">Arrendatarios Externos</span>
        </label>
    };
    foreach my $m (@medicos) {
        $items_m .= qq{
            <label class="dropdown-item d-flex align-items-center gap-2 rounded-2 px-2 py-1.5 cursor-pointer user-select-none mb-0.5">
                <input type="checkbox" class="form-check-input mt-0 chk-medico-item" value="$m->{id}" onchange="window.onMedicoCheckChange()" checked>
                <i class="bi bi-person-fill text-primary" style="font-size:0.95rem;"></i>
                <span class="fw-semibold text-navy small text-truncate">$m->{nombre}</span>
            </label>
        };
        $html_medicos .= qq(<option value="$m->{id}">$m->{nombre} (Interno)</option>\n);
    }
    my $cnt_med = scalar(@medicos) + 1;
    $html_filtro_medicos_toolbar = qq{
        <div class="dropdown" id="wrapper_filtro_medicos_toolbar" style="position: relative; z-index: 1065;">
            <button class="tier2-executive-select-btn dropdown-toggle" 
                    type="button" 
                    id="btn_filtro_medico_dropdown" 
                    data-bs-toggle="dropdown" 
                    data-bs-display="static"
                    data-bs-auto-close="outside" 
                    aria-expanded="false" 
                    title="Filtrar directamente por Médicos / Arrendatarios">
                <span class="d-flex align-items-center gap-1.5 text-truncate" id="filtro_medico_btn_label">
                    <i class="bi bi-people-fill text-primary"></i>
                    <span class="text-truncate">Médicos ($cnt_med)</span>
                </span>
            </button>
            <div class="dropdown-menu dropdown-menu-end shadow-lg p-2.5 border-0 rounded-4" id="dropdown_filtro_medico_menu" aria-labelledby="btn_filtro_medico_dropdown" style="min-width: 280px; max-height: 360px; overflow-y: auto; z-index: 107000 !important;">
                <div class="d-flex align-items-center justify-content-between px-2 py-1 border-bottom mb-2">
                    <span class="text-navy small text-uppercase" style="font-size:0.72rem; letter-spacing:0.5px; font-weight:700;">Arrendatarios / Médicos</span>
                    <div class="d-flex align-items-center gap-1.5">
                        <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none fw-bold" onclick="window.seleccionarTodosMedicos(true)" style="font-size:0.72rem; color: #19B7A5;">Marcar todos</button>
                        <span class="text-muted opacity-50" style="font-size:0.70rem;">•</span>
                        <button type="button" class="btn btn-link btn-sm p-0 text-secondary text-decoration-none" onclick="window.seleccionarTodosMedicos(false)" style="font-size:0.72rem;">Desmarcar</button>
                    </div>
                </div>
                <div id="lista_checkboxes_medicos" class="d-flex flex-column gap-1">
                    $items_m
                </div>
            </div>
        </div>
    };
}

my $negocios = leer_tabla($archivo_negocios, '\|');
my @sucursales_org;
if ($negocios) {
    foreach my $n (@$negocios) {
        next if @$n < 3;
        my $id_neg = $n->[0];
        my $nom_neg = $n->[1];
        my $id_matriz = $n->[2] // '0';
        my $activo = $n->[3] // '1';
        next if $activo ne '1' && $activo ne '';
        if ($id_matriz eq $id_negocio && $id_matriz ne '0') {
            push @sucursales_org, { id => $id_neg, nombre => $nom_neg };
        }
    }
}
if (!@sucursales_org && $negocios) {
    foreach my $n (@$negocios) {
        if ($n->[0] eq $id_negocio) {
            push @sucursales_org, { id => $n->[0], nombre => $n->[1] };
            last;
        }
    }
}
if (!@sucursales_org) {
    push @sucursales_org, { id => $id_negocio, nombre => 'Clínica Principal' };
}

my $html_sucursal = '';
my $nombre_sucursal_activa = '';
my $id_sucursal_activa = $id_negocio_activo;
foreach my $s (@sucursales_org) {
    my $sel = ($s->{id} eq $id_negocio_activo || scalar(@sucursales_org) == 1) ? 'selected' : '';
    if ($sel || !$nombre_sucursal_activa) {
        $nombre_sucursal_activa = $s->{nombre};
        $id_sucursal_activa = $s->{id};
    }
    $html_sucursal .= qq(<option value="$s->{id}" $sel>$s->{nombre}</option>\n);
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');

render_header(
    usuario     => $usuario,
    role        => $role,
    titulo      => 'Agenda de Renta de Espacios',
    skip_header => 1
);

my %map_medicos = map { $_->{id} => $_->{nombre} } @medicos;
$map_medicos{'EXTERNO'} = 'Arrendatario Externo';
my $json_catalogo_medicos = encode_json(\%map_medicos);
my $json_lista_medicos = encode_json(\@medicos);

print <<HTML;
    <!-- Datos de Configuración mediante atributos DOM data-* -->
    <div id="agenda_espacios_config"
         data-f-medico="$id_medico_activo"
         data-tipo-org="$tipo_organizacion"
         data-id-empresa="$id_negocio"
         class="d-none"></div>
    <input type="hidden" id="f_medico" value="$id_medico_activo">
    <input type="hidden" id="agenda_es_individual" value="0">
    <input type="hidden" id="agenda_es_consultorio" value="0">
    <input type="hidden" id="agenda_tipo_organizacion" value="$tipo_organizacion">
    <script type="application/json" id="json_medicos_catalogo">$json_catalogo_medicos</script>
    <script type="application/json" id="json_medicos_activos_list">$json_lista_medicos</script>

    <!-- DataTables & Estilos Master de Agenda -->
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">
    <link rel="stylesheet" href="../css/sdm_mobile_standards.css?v=1.0">
    <link rel="stylesheet" href="../css/agenda_diamond.css?v=4.3.2">
HTML

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    pagina_actual => 'agenda_espacios'
);

print <<HTML;
    <div class="main-container-agenda container-mobile-flush">
        <header class="agenda-header agenda-header-two-tier">
            <!-- NIVEL 1 (CABECERA NAVY CONTEXTUAL + ACCIÓN PRIORITARIA DE MOSTRADOR) -->
            <div class="agenda-toolbar-tier1">
                <div class="container-fluid px-1 px-md-2 d-flex align-items-center justify-content-between gap-2 flex-wrap">
                    <div class="tier1-context-title">
                        <span class="tier1-context-icon">
                            <i class="bi bi-door-open-fill"></i>
                        </span>
                        <span>Renta de Espacios Clínicos</span>
                        <span class="opacity-50">•</span>
                        <span class="tier1-enabled-badge" id="lbl_header_espacios_habilitados">Cargando espacios...</span>
                    </div>

                    <div class="d-flex align-items-center gap-2 ms-auto">
                        <button type="button" onclick="window.abrirModalNuevaRenta()" class="btn-tier1-reservar" title="Reservar un nuevo espacio clínico">
                            <i class="bi bi-plus-circle-fill"></i>
                            <span>Reservar Espacio</span>
                        </button>
                        <button type="button" onclick="abrirModalAjustes()" class="btn-tier1-config" title="Configuracion de Espacios">
                            <i class="bi bi-gear-fill"></i>
                            <span class="d-none d-sm-inline">Configuración</span>
                        </button>
                    </div>
                </div>
            </div>

            <!-- NIVEL 2 (BANDEJA OPERATIVA BLANCA: NAVEGACIÓN TEMPORAL + VISTAS + SELECTORES DIRECTOS) -->
            <div class="agenda-toolbar-tier2">
                <div class="container-fluid px-1 px-md-2">
                    <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 w-100">
                        <!-- IZQUIERDA: NAVEGACIÓN TEMPORAL, VISTAS DE CALENDARIO Y REPORTES & EXPORT -->
                        <div class="d-flex align-items-center flex-wrap gap-2">
                            <button onclick="goToday()" class="btn-tier2-today text-uppercase" title="Ir al Día de Hoy">HOY</button>
                            <button type="button" onclick="window.scrollToLiveTimeline(true)" class="btn-timeline-now text-nowrap d-none d-sm-inline-flex" id="btn-snap-now-toolbar" title="Centrar línea de tiempo en vivo (Ahora)">
                                <span class="timeline-live-dot" style="width:6px; height:6px; background:#dc2626;"></span>
                                <span>Ahora</span>
                            </button>

                            <div class="d-none d-md-flex align-items-center tier2-date-nav">
                                <button onclick="moveDate(-1)" class="tier2-date-chevron" title="Día Anterior"><i class="bi bi-chevron-left"></i></button>
                                <h1 class="h6 mb-0 text-navy text-uppercase tracking-tight text-nowrap tier2-date-label" id="current-date-label-desktop">
                                    CARGANDO...
                                </h1>
                                <button onclick="moveDate(1)" class="tier2-date-chevron" title="Día Siguiente"><i class="bi bi-chevron-right"></i></button>
                            </div>

                            <!-- Conmutador de Vistas de Calendario (Día, Semana, Mes) -->
                            <div class="tier2-view-group">
                                <button onclick="switchView('dia')" class="btn-view-toggle active" id="btn-v-dia" title="Vista Diaria por Consultorios y Quirófanos">
                                    <i class="bi bi-calendar-event me-1"></i><span class="d-none d-xl-inline">Día</span>
                                </button>
                                <button onclick="switchView('semana_smart')" class="btn-view-toggle" id="btn-v-semana-smart" title="Vista Semanal Smart de Espacios">
                                    <i class="bi bi-calendar-week me-1"></i><span class="d-none d-xl-inline">Semana</span>
                                </button>
                                <button onclick="switchView('calendario')" class="btn-view-toggle" id="btn-v-calendario" title="Vista Mensual Grid">
                                    <i class="bi bi-grid-3x3 me-1"></i><span class="d-none d-xl-inline">Mes</span>
                                </button>
                            </div>

                            <!-- Menú Compacto Reportes & Export (Ahorra espacio horizontal en laptops/tablets) -->
                            <div class="dropdown" style="position: relative; z-index: 1065;">
                                <button class="tier2-executive-select-btn dropdown-toggle" 
                                        type="button" 
                                        id="dropdownReportesExport" 
                                        data-bs-toggle="dropdown" 
                                        data-bs-display="static" 
                                        aria-expanded="false" 
                                        title="Reportes Tabulares e Impresión">
                                    <span class="d-flex align-items-center gap-1.5">
                                        <i class="bi bi-file-earmark-bar-graph text-teal"></i>
                                        <span>Reportes &amp; Export</span>
                                    </span>
                                </button>
                                <div class="dropdown-menu shadow-lg p-2.5 border-0 rounded-4" aria-labelledby="dropdownReportesExport" style="min-width: 230px; z-index: 107000;">
                                    <div class="px-2 py-1 text-navy text-uppercase border-bottom mb-1" style="font-size: 0.68rem; font-weight: 700; letter-spacing: 0.5px;">Tablas Operativas</div>
                                    <button type="button" onclick="switchView('dia_reporte')" class="dropdown-item rounded-2 py-1.5 small d-flex align-items-center gap-2 btn-report-toggle" id="btn-r-dia-reporte">
                                        <i class="bi bi-file-earmark-ruled text-primary"></i> Reporte Diario
                                    </button>
                                    <button type="button" onclick="switchView('semana')" class="dropdown-item rounded-2 py-1.5 small d-flex align-items-center gap-2 btn-report-toggle" id="btn-r-semana">
                                        <i class="bi bi-file-earmark-text text-teal"></i> Reporte Semanal
                                    </button>
                                    <button type="button" onclick="switchView('mes')" class="dropdown-item rounded-2 py-1.5 small d-flex align-items-center gap-2 btn-report-toggle" id="btn-r-mes">
                                        <i class="bi bi-file-earmark-bar-graph text-navy"></i> Reporte Mensual
                                    </button>
                                    <div class="dropdown-divider my-1"></div>
                                    <button type="button" onclick="window.abrirReportePersonalizado(currentView)" class="dropdown-item rounded-2 py-1.5 small d-flex align-items-center gap-2">
                                        <i class="bi bi-printer-fill text-teal"></i> Imprimir Reporte Oficial
                                    </button>
                                </div>
                            </div>
                        </div>

                        <!-- DERECHA: SELECTORES INDEPENDIENTES DIRECTOS (MÉDICOS, ESPACIOS, ESTADOS) -->
                        <div class="d-flex align-items-center flex-wrap gap-2 ms-auto">
                            <!-- Selector Directo 1: Médicos / Arrendatarios -->
                            $html_filtro_medicos_toolbar

                            <!-- Selector Directo 2: Espacios Físicos (Consultorios y Quirófanos) -->
                            <div class="dropdown" id="wrapper_filtro_recurso_toolbar" style="position: relative; z-index: 1065;">
                                <button class="tier2-executive-select-btn dropdown-toggle" 
                                        type="button" 
                                        id="btn_filtro_recurso_dropdown" 
                                        data-bs-toggle="dropdown" 
                                        data-bs-display="static" 
                                        data-bs-auto-close="outside" 
                                        aria-expanded="false" 
                                        title="Filtrar directamente por Consultorios y Quirófanos">
                                    <span class="d-flex align-items-center gap-1.5 text-truncate" id="filtro_recurso_btn_label">
                                        <i class="bi bi-door-open-fill text-teal"></i>
                                        <span class="text-truncate">Espacios</span>
                                    </span>
                                </button>
                                <div class="dropdown-menu dropdown-menu-end shadow-lg p-2.5 border-0 rounded-4" id="dropdown_filtro_recurso_menu" aria-labelledby="btn_filtro_recurso_dropdown" style="min-width: 280px; max-height: 360px; overflow-y: auto; z-index: 107000 !important;">
                                    <div class="d-flex align-items-center justify-content-between px-2 py-1 border-bottom mb-2">
                                        <span class="text-navy small text-uppercase" style="font-size:0.72rem; letter-spacing:0.5px; font-weight: 700;">Consultorios y Quirófanos</span>
                                        <div class="d-flex align-items-center gap-1.5">
                                            <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none fw-bold" onclick="window.seleccionarTodosEspacios(true)" style="font-size:0.72rem; color: #19B7A5;">Marcar todos</button>
                                            <span class="text-muted opacity-50" style="font-size:0.70rem;">•</span>
                                            <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none fw-semibold" onclick="window.seleccionarSoloHabilitados()" style="font-size:0.72rem; color: #0284c7;" title="Filtrar únicamente espacios libres y operativos">Solo habilitados</button>
                                            <span class="text-muted opacity-50" style="font-size:0.70rem;">•</span>
                                            <button type="button" class="btn btn-link btn-sm p-0 text-secondary text-decoration-none" onclick="window.seleccionarTodosEspacios(false)" style="font-size:0.72rem;">Desmarcar</button>
                                        </div>
                                    </div>
                                    <div id="lista_checkboxes_recursos" class="d-flex flex-column gap-1">
                                        <div class="text-center py-2 text-muted small">Cargando espacios...</div>
                                    </div>
                                </div>
                            </div>

                            <!-- Selector Directo 3: Leyenda de Estados -->
                            <div class="dropdown" style="position: relative; z-index: 1065;">
                                <button class="tier2-executive-select-btn dropdown-toggle" 
                                        type="button" 
                                        id="dropdownLeyendaColores" 
                                        data-bs-toggle="dropdown" 
                                        data-bs-display="static" 
                                        aria-expanded="false" 
                                        title="Significado de Estados de Renta">
                                    <span class="d-flex align-items-center gap-1.5">
                                        <i class="bi bi-palette" style="color: var(--md-teal-clinical, #19B7A5) !important;"></i>
                                        <span>Estados</span>
                                    </span>
                                </button>
                                <div class="dropdown-menu dropdown-menu-end shadow-lg p-3 border-0 rounded-4" style="min-width: 280px; z-index: 107000;" aria-labelledby="dropdownLeyendaColores">
                                    <h6 class="text-navy small mb-2.5 d-flex align-items-center gap-1.5 fw-bold" style="letter-spacing: 0.25px;">
                                        <i class="bi bi-info-circle" style="color: var(--md-teal-clinical, #19B7A5);"></i> Estados de Renta de Espacio
                                    </h6>
                                    <div class="d-flex flex-column gap-2 small">
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="rounded-circle d-inline-block shadow-2xs" style="width: 12px; height: 12px; background-color: #991B1B;"></span>
                                            <span class="text-dark fw-medium">Reservada</span>
                                            <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Rojo oscuro</span>
                                        </div>
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="rounded-circle d-inline-block shadow-2xs" style="width: 12px; height: 12px; background-color: #EAB308;"></span>
                                            <span class="text-dark fw-medium">Confirmada</span>
                                            <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Amarillo</span>
                                        </div>
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="rounded-circle d-inline-block shadow-2xs" style="width: 12px; height: 12px; background-color: #059669;"></span>
                                            <span class="text-dark fw-medium">En Uso</span>
                                            <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Verde actual</span>
                                        </div>
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="rounded-circle d-inline-block shadow-2xs" style="width: 12px; height: 12px; background-color: #064E3B;"></span>
                                            <span class="text-dark fw-medium">Finalizada</span>
                                            <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Verde muy oscuro</span>
                                        </div>
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="rounded-circle d-inline-block shadow-2xs" style="width: 12px; height: 12px; background-color: #0284C7;"></span>
                                            <span class="text-dark fw-medium">Ocupado (Pacientes)</span>
                                            <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Azul Health</span>
                                        </div>
                                        <div class="d-flex align-items-center gap-2">
                                            <span class="rounded-circle d-inline-block shadow-2xs" style="width: 12px; height: 12px; background-color: #64748B;"></span>
                                            <span class="text-dark text-decoration-line-through fw-medium">No realizada</span>
                                            <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Tachada</span>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Toggle Mini Calendario Lateral -->
                            <button type="button" class="tier2-icon-circle-btn d-none d-lg-inline-flex" id="btn-toggle-side-cal" onclick="toggleSideCalendar()" title="Mostrar/Ocultar Minicalendario Lateral">
                                <i class="bi bi-layout-sidebar-inset text-teal" style="font-size: 0.95rem;"></i>
                            </button>
                        </div>
                    </div>

                    <!-- Navegación de Fecha para Móvil (< 768px) -->
                    <div class="d-flex d-md-none justify-content-center pt-2">
                        <div class="d-flex align-items-center justify-content-between tier2-date-nav w-100 mx-0">
                            <button onclick="moveDate(-1)" class="tier2-date-chevron"><i class="bi bi-chevron-left"></i></button>
                            <h1 class="h6 mb-0 text-navy text-uppercase tracking-tight mx-2 tier2-date-label" id="current-date-label-mobile" style="text-align: center; font-size: 0.80rem;">
                                CARGANDO...
                            </h1>
                            <button onclick="moveDate(1)" class="tier2-date-chevron"><i class="bi bi-chevron-right"></i></button>
                        </div>
                    </div>
                </div>
            </div>
        </header>

        <main id="app-viewport" class="container-fluid px-1 px-md-3 pt-1 pb-4">
            <!-- VISTA DIARIA (Matriz de Consultorios y Quirófanos) -->
            <div id="view-dia" class="agenda-view-container">
                <div class="dia-view-layout d-flex gap-3 align-items-start w-100" id="dia-layout-row">
                    <div class="dia-side-panel d-none d-lg-block" id="dia-side-col">
                        <div class="card border-0 shadow-sm p-3 sticky-top agenda-side-card" style="top:75px;">
                            <div class="d-flex align-items-center justify-content-between mb-2">
                                <h6 class="fw-black text-navy m-0 text-uppercase small tracking-widest"><i class="bi bi-calendar3 me-1 text-teal"></i> Navegación</h6>
                            </div>
                            <div id="side-datepicker"></div>
                            <hr class="opacity-10 my-2.5">
                            <button class="btn btn-light w-100 btn-sm text-start fw-bold rounded-3 py-1.5 border" onclick="goToday()">
                                <i class="bi bi-calendar2-check me-2 text-primary"></i> Ir a Hoy
                            </button>
                        </div>
                    </div>
                    <div class="dia-main-panel flex-grow-1" id="dia-main-col" style="min-width: 0;">
                        <div id="timeline-container"></div>
                    </div>
                </div>
            </div>

            <!-- VISTA SEMANAL SMART -->
            <div id="view-semana-smart" class="agenda-view-container d-none">
                <div id="weekly-smart-scroll" class="d-flex justify-content-center gap-2 py-2 mb-2 overflow-auto no-scrollbar"></div>
                <div id="weekly-smart-slots-container" class="weekly-smart-slots-scroll-area">
                    <div id="weekly-smart-slots" class="row g-4 m-0"></div>
                </div>
            </div>

            <!-- REPORTE DIARIO (DataTable) -->
            <div id="view-dia-reporte" class="agenda-view-container d-none">
                <div class="card card-mobile-flush border-0 shadow-sm rounded-4 p-2 p-md-4 agenda-report-card">
                    <h4 class="fw-black text-navy mb-2 mb-md-4 agenda-report-title">REPORTE DIARIO DE RENTA DE ESPACIOS</h4>
                    <div class="table-responsive agenda-table-responsive">
                        <table id="diaReporteTable" class="table table-diamond table-hover w-100 mb-0">
                            <thead>
                                <tr><th>Fecha</th><th>Horario</th><th>Arrendatario</th><th>Uso / Procedimiento</th><th>Tarifa</th><th>Espacio</th><th>Status</th><th class="text-end">Acciones</th></tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- REPORTE SEMANAL (DataTable) -->
            <div id="view-semana" class="agenda-view-container d-none">
                <div class="card card-mobile-flush border-0 shadow-sm rounded-4 p-2 p-md-4 agenda-report-card">
                    <h4 class="fw-black text-navy mb-2 mb-md-4 agenda-report-title">REPORTE SEMANAL DE RENTA DE ESPACIOS</h4>
                    <div class="table-responsive agenda-table-responsive">
                        <table id="agendaTable" class="table table-diamond table-hover w-100 mb-0">
                            <thead>
                                <tr><th>Fecha</th><th>Horario</th><th>Arrendatario</th><th>Uso / Procedimiento</th><th>Tarifa</th><th>Espacio</th><th>Status</th><th class="text-end">Acciones</th></tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- REPORTE MENSUAL (DataTable) -->
            <div id="view-mes" class="agenda-view-container d-none">
                <div class="card card-mobile-flush border-0 shadow-sm rounded-4 p-2 p-md-4 agenda-report-card">
                    <h4 class="fw-black text-navy mb-2 mb-md-4 agenda-report-title">REPORTE MENSUAL DE RENTA DE ESPACIOS</h4>
                    <div class="table-responsive agenda-table-responsive">
                        <table id="mesTable" class="table table-diamond table-hover w-100 mb-0">
                            <thead>
                                <tr><th>Fecha</th><th>Horario</th><th>Arrendatario</th><th>Uso / Procedimiento</th><th>Tarifa</th><th>Espacio</th><th>Status</th><th class="text-end">Acciones</th></tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- VISTA MENSUAL GRID -->
            <div id="view-calendario" class="agenda-view-container d-none">
                <div id="calendar-grid-sdm" class="animate__animated animate__fadeIn d-none d-lg-block"></div>
                <div class="d-lg-none animate__animated animate__fadeIn">
                    <div class="card border-0 shadow-sm rounded-4 mb-4 agenda-side-card">
                        <div class="card-body">
                            <div id="mini-calendar-grid"></div>
                        </div>
                    </div>
                    <div id="mini-calendar-appointments"></div>
                </div>
            </div>
        </main>
    </div>

    <!-- MODAL DE INSPECCIÓN RÁPIDA DE RESERVA DE ESPACIO -->
    <div class="modal fade modal-diamond" id="appointmentQuickModal" tabindex="-1" aria-hidden="true" style="z-index: 105160 !important;">
        <div class="modal-dialog modal-dialog-centered" style="max-width: 440px;">
            <div class="modal-content border-0 shadow-lg rounded-4 overflow-hidden">
                <div class="modal-header py-2.5 px-3.5 d-flex align-items-center justify-content-between border-0" id="quickModalHeader" style="background-color: var(--md-blue-deep, #0A2A66); color: white;">
                    <div class="d-flex align-items-center gap-2">
                        <span id="quickModalDot" class="rounded-circle d-inline-block shadow-sm" style="width: 11px; height: 11px; background-color: #19B7A5;"></span>
                        <span class="modal-title fw-black text-uppercase tracking-wider" id="quickModalEstatus" style="font-size: 0.84rem; letter-spacing: 0.6px;">RESERVADA</span>
                    </div>
                    <button type="button" class="btn-close btn-close-white" style="font-size: 0.75rem; opacity: 0.95;" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>

                <div class="modal-body p-3.5">
                    <div class="row g-2 align-items-stretch mb-2">
                        <div class="col-8 pe-2 d-flex flex-column justify-content-between">
                            <div>
                                <div class="d-flex align-items-start gap-2 mb-1.5 text-navy">
                                    <i class="bi bi-person-badge-fill fs-4" style="color: var(--md-teal-clinical, #19B7A5); line-height: 1.1;"></i>
                                    <div class="text-truncate">
                                        <div id="quickModalPaciente" class="fw-black text-truncate text-navy" style="font-size: 1.02rem; line-height: 1.2;">Arrendatario</div>
                                        <span id="quickModalExpediente" class="badge bg-light text-secondary border px-1.5 py-0.5 fw-semibold" style="font-size: 0.68rem;">Folio #---</span>
                                        <span id="quickModalRangoBadge" class="badge bg-info-subtle text-info-emphasis border border-info-subtle px-1.5 py-0.5 fw-semibold d-none" style="font-size: 0.68rem;"><i class="bi bi-calendar-range me-1"></i>Serie Multi-Día</span>
                                    </div>
                                </div>

                                <div class="d-flex align-items-center gap-1.5 mb-1 text-secondary small" style="font-size: 0.80rem;">
                                    <i class="bi bi-telephone" id="quickModalTelefonoIcon"></i>
                                    <span id="quickModalTelefono" class="fw-medium text-truncate">No registrado</span>
                                </div>

                                <div class="d-flex align-items-center gap-1.5 mb-2 text-secondary small" style="font-size: 0.80rem;">
                                    <i class="bi bi-cash-coin text-teal"></i>
                                    <span id="quickModalMedico" class="fw-bold text-truncate text-navy">Tarifa: \$0.00</span>
                                </div>
                            </div>

                            <hr class="my-2 opacity-15">

                            <div>
                                <div class="d-flex align-items-start gap-1.5 mb-1.5" style="font-size: 0.80rem;">
                                    <i class="bi bi-tag-fill mt-0.5" style="color: var(--md-teal-clinical, #19B7A5);"></i>
                                    <span id="quickModalMotivo" class="fw-semibold text-dark text-truncate">Uso del espacio</span>
                                </div>

                                <div class="d-flex align-items-center gap-1.5 mb-1.5" style="font-size: 0.78rem;">
                                    <i class="bi bi-door-open-fill text-muted"></i>
                                    <span id="quickModalLugar" class="badge bg-light text-navy border fw-bold px-2 py-1">Consultorio 1</span>
                                </div>

                                <div class="d-flex align-items-center gap-1.5" style="font-size: 0.78rem;">
                                    <i class="bi bi-cash-stack text-muted"></i>
                                    <span id="quickModalPago" class="badge px-2 py-1 fw-bold">Pendiente de Pago</span>
                                </div>
                            </div>
                        </div>

                        <div class="col-4 ps-1 d-flex">
                            <div class="date-badge rounded-3 overflow-hidden text-center border shadow-2xs w-100 d-flex flex-column justify-content-between" style="background: #ffffff; border-color: #FDE68A !important;">
                                <div class="date-badge-header py-1 text-white fw-bold text-uppercase" id="quickModalMes" style="background-color: var(--md-blue-deep, #0A2A66); font-size: 0.72rem; letter-spacing: 0.5px;">
                                    NOVIEMBRE
                                </div>
                                <div class="date-badge-body py-2.5 flex-fill d-flex flex-column justify-content-center align-items-center" style="background-color: #FEF9C3;">
                                    <p class="date-badge-day m-0 fw-black" id="quickModalDiaNum" style="font-size: 2rem; line-height: 1; color: #78350F;">16</p>
                                    <span class="date-badge-weekday text-uppercase fw-bold mt-1" id="quickModalDiaSemana" style="font-size: 0.68rem; color: #92400E; letter-spacing: 0.5px;">LUNES</span>
                                </div>
                                <div class="date-badge-time py-1.5 fw-black text-navy" id="quickModalHora" style="background-color: #FEF08A; border-top: 1px solid #FDE047; font-size: 0.80rem; color: #78350F !important;">
                                    08:00 – 09:00
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="modal-footer p-3 bg-light border-0 d-flex flex-column gap-2">
                    <button type="button" class="btn btn-success w-100 py-2.5 fw-bold d-flex align-items-center justify-content-center gap-2 shadow-sm rounded-3 btn-mobile-standard" id="btnQuickIniciarCita" style="background-color: #059669; border: none; font-size: 0.92rem;">
                        <i class="bi bi-door-open-fill fs-5"></i>
                        <span>Marcar Espacio En Uso</span>
                    </button>

                    <div class="d-flex gap-2 w-100">
                        <button type="button" class="btn btn-outline-primary flex-fill fw-bold py-2 rounded-3 shadow-2xs d-flex align-items-center justify-content-center gap-1.5" id="btnQuickExpediente" style="font-size: 0.82rem;">
                            <i class="bi bi-check2-all text-primary"></i> Finalizar Uso
                        </button>
                        <button type="button" class="btn btn-outline-secondary flex-fill fw-bold py-2 rounded-3 shadow-2xs d-flex align-items-center justify-content-center gap-1.5" id="btnQuickEditar" style="font-size: 0.82rem;">
                            <i class="bi bi-pencil-square"></i> Editar / Re-agendar
                        </button>
                    </div>

                    <div class="d-flex gap-2 w-100">
                        <button type="button" class="btn btn-outline-success flex-fill fw-bold py-2 rounded-3 shadow-2xs d-flex align-items-center justify-content-center gap-1.5" id="btnQuickCobrar" style="font-size: 0.82rem;">
                            <i class="bi bi-cash-coin"></i> Cobrar Renta
                        </button>
                        <button type="button" class="btn btn-outline-danger flex-fill fw-bold py-2 rounded-3 shadow-2xs d-flex align-items-center justify-content-center gap-1.5" id="btnQuickEliminar" style="font-size: 0.82rem;">
                            <i class="bi bi-trash"></i> Eliminar
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL CRUD DE RESERVA DE ESPACIO (Consultorio / Quirófano) -->
    <div class="modal fade modal-diamond" id="modalCita" tabindex="-1" aria-hidden="true" style="z-index: 105150 !important;">
        <div class="modal-dialog modal-dialog-centered modal-xl" style="max-width: 1040px;">
            <div class="modal-content">
                <div class="modal-header d-flex align-items-center justify-content-between" style="background-color: var(--md-blue-deep, #0A2A66) !important; border-bottom: 2px solid var(--md-teal-clinical, #19B7A5) !important; padding: 0.75rem 1.25rem !important;">
                    <div class="d-flex align-items-center gap-2.5">
                        <div class="modal-header-icon rounded-circle d-flex align-items-center justify-content-center" style="width: 32px; height: 32px; background: rgba(255, 255, 255, 0.16); border: 1px solid rgba(255, 255, 255, 0.25); color: #ffffff;">
                            <i class="bi bi-door-open-fill text-white" style="font-size: 1rem;"></i>
                        </div>
                        <h5 class="modal-title m-0 text-white" style="font-size: 0.95rem; font-weight: 500; letter-spacing: 0.3px;">
                            <span id="modalCitaTitle" class="text-white">RESERVA DE ESPACIO (CONSULTORIO / QUIRÓFANO)</span>
                        </h5>
                    </div>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close" style="font-size: 0.75rem; opacity: 0.9;"></button>
                </div>
                
                <div class="modal-body">
                    <form id="formCita">
                        <input type="hidden" name="id_renta" id="f_id_cita">
                        <input type="hidden" name="id_cita" id="f_id_cita_alias">
                        <input type="hidden" name="accion" id="f_accion" value="create">
                        <input type="hidden" name="hora_ini" id="f_hi">
                        <input type="hidden" name="hora_fin" id="f_hf">
                        <input type="hidden" name="es_rango" id="f_es_rango" value="0">
                        <input type="hidden" name="dias_semana_rango" id="f_dias_semana_rango" value="1,2,3,4,5,6,7">
                        <input type="hidden" name="tipo_tarifa_rango" id="f_tipo_tarifa_rango" value="por_dia">

                        <div class="row g-3 align-items-stretch">
                            <!-- PANEL IZQUIERDO: DATOS DEL ESPACIO Y ARRENDATARIO (7 COLS) -->
                            <div class="col-lg-7 d-flex flex-column justify-content-between">
                                <div class="row g-2">
                                    <!-- Selector de Modalidad: Día Único vs Rango de Fechas -->
                                    <div class="col-12" id="box_modalidad_reserva">
                                        <div class="d-flex flex-wrap align-items-center justify-content-between p-2 rounded-3 border bg-white shadow-2xs mb-1">
                                            <div class="d-flex align-items-center gap-1.5">
                                                <i class="bi bi-calendar-range text-teal fs-6"></i>
                                                <span class="small fw-bold text-navy" style="font-size: 0.76rem;">Modalidad de Reserva:</span>
                                            </div>
                                            <div class="btn-group btn-group-sm" role="group">
                                                <input type="radio" class="btn-check" name="modalidad_fecha" id="mod_fecha_unica" value="unica" checked onchange="window.toggleModalidadFechaRenta('unica')">
                                                <label class="btn btn-outline-primary py-0.5 px-3 fw-semibold" for="mod_fecha_unica" style="font-size:0.72rem;">
                                                    <i class="bi bi-calendar-day me-1"></i>Día Único
                                                </label>

                                                <input type="radio" class="btn-check" name="modalidad_fecha" id="mod_fecha_rango" value="rango" onchange="window.toggleModalidadFechaRenta('rango')">
                                                <label class="btn btn-outline-primary py-0.5 px-3 fw-semibold" for="mod_fecha_rango" style="font-size:0.72rem;">
                                                    <i class="bi bi-calendar-week me-1"></i>Rango de Fechas
                                                </label>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Fila 1: Sucursal y Espacio Físico -->
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_sucursal">Sucursal / Sede Física <span class="text-danger">*</span></label>
                                        <select name="sucursal" id="f_sucursal" class="form-select form-control-compact">
                                            $html_sucursal
                                        </select>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_consultorio">Consultorio o Quirófano <span class="text-danger">*</span></label>
                                        <select name="espacio" id="f_consultorio" class="form-select form-control-compact fw-bold text-navy">
                                            <option value="">Cargando espacios...</option>
                                        </select>
                                    </div>

                                    <!-- Fila 2: Selección de Arrendatario y Fecha -->
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_medico_select">Profesional / Tipo de Arrendatario</label>
                                        <select name="id_arrendatario" id="f_medico_select" class="form-select form-control-compact" onchange="window.onCambioTipoArrendatario(this.value)">
                                            $html_medicos
                                        </select>
                                    </div>
                                    <div class="col-md-6" id="wrapper_fecha_unica">
                                        <label class="form-label-compact" for="f_fecha">Fecha de Reserva <span class="text-danger">*</span></label>
                                        <input type="date" name="fecha" id="f_fecha" class="form-control form-control-compact" onchange="renderSlots(this.value)">
                                    </div>

                                    <!-- Panel Desplegable para Rango de Fechas -->
                                    <div class="col-12 d-none" id="wrapper_fecha_rango">
                                        <div class="p-2.5 rounded-3 border shadow-2xs" style="background-color: #f0fdfa; border-color: rgba(25, 183, 165, 0.3) !important;">
                                            <input type="hidden" name="tipo_cobertura_rango" id="f_tipo_cobertura_rango" value="continuo">
                                            <div class="row g-2">
                                                <!-- Sub-selector de Modalidad del Rango: Continuo vs Recurrente -->
                                                <div class="col-12">
                                                    <div class="d-flex flex-wrap align-items-center justify-content-between p-1.5 rounded-2 bg-white border gap-1">
                                                        <span class="small fw-bold text-navy" style="font-size:0.72rem;">
                                                            <i class="bi bi-clock-history text-teal me-1"></i>Tipo de Cobertura:
                                                        </span>
                                                        <div class="btn-group btn-group-sm" role="group">
                                                            <input type="radio" class="btn-check" name="rad_tipo_cobertura_rango" id="cob_rango_continuo" value="continuo" checked onchange="window.toggleTipoCoberturaRango('continuo')">
                                                            <label class="btn btn-outline-primary py-0.5 px-2.5 fw-bold" for="cob_rango_continuo" style="font-size:0.68rem;" title="Renta continua ininterrumpida día y noche desde el inicio hasta la hora de entrega final (sin huecos intermedios)">
                                                                <i class="bi bi-infinity me-1"></i>Bloque Continuo (24h+)
                                                            </label>

                                                            <input type="radio" class="btn-check" name="rad_tipo_cobertura_rango" id="cob_rango_recurrente" value="recurrente" onchange="window.toggleTipoCoberturaRango('recurrente')">
                                                            <label class="btn btn-outline-primary py-0.5 px-2.5 fw-bold" for="cob_rango_recurrente" style="font-size:0.68rem;" title="Mismo horario de atención repetido en cada día seleccionado (las mañanas/noches quedan libres)">
                                                                <i class="bi bi-repeat me-1"></i>Mismo Horario por Día
                                                            </label>
                                                        </div>
                                                    </div>
                                                </div>

                                                <div class="col-12 mt-0.5">
                                                    <div id="lbl_info_tipo_cobertura" class="small p-1.5 rounded-2 border text-navy" style="font-size:0.68rem; background-color: #ecfeff; border-color: #cffafe !important;">
                                                        <i class="bi bi-info-circle-fill text-primary me-1"></i><strong>Bloque Continuo (24h+):</strong> El espacio se reservará día y noche ininterrumpidamente desde la hora de inicio del primer día hasta la hora de entrega del último día.
                                                    </div>
                                                </div>

                                                <div class="col-md-6">
                                                    <label class="form-label-compact fw-bold text-navy" for="f_fecha_rango_ini">
                                                        <i class="bi bi-calendar-event text-teal me-1"></i>Fecha Inicio <span class="text-danger">*</span>
                                                    </label>
                                                    <input type="date" id="f_fecha_rango_ini" class="form-control form-control-compact bg-white" onchange="window.onFechasRangoChange()">
                                                </div>
                                                <div class="col-md-6">
                                                    <label class="form-label-compact fw-bold text-navy" for="f_fecha_fin">
                                                        <i class="bi bi-calendar-check text-teal me-1"></i>Fecha Fin (Límite del Rango) <span class="text-danger">*</span>
                                                    </label>
                                                    <input type="date" name="fecha_fin" id="f_fecha_fin" class="form-control form-control-compact bg-white" onchange="window.onFechasRangoChange()">
                                                </div>

                                                <!-- Selector de días de la semana (solo visible en modo Recurrente) -->
                                                <div class="col-12 mt-1.5 d-none" id="wrapper_dias_semana_pills">
                                                    <div class="d-flex flex-wrap align-items-center justify-content-between gap-1">
                                                        <span class="small fw-bold text-navy" style="font-size:0.70rem;">
                                                            <i class="bi bi-funnel me-1 text-teal"></i>Días a aplicar dentro del rango:
                                                        </span>
                                                        <div class="d-flex align-items-center gap-1.5">
                                                            <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none fw-bold" onclick="window.seleccionarDiasSemanaRango('todos')" style="font-size:0.68rem; color:#19B7A5;">Todos</button>
                                                            <span class="text-muted" style="font-size:0.65rem;">•</span>
                                                            <button type="button" class="btn btn-link btn-sm p-0 text-decoration-none fw-semibold" onclick="window.seleccionarDiasSemanaRango('laborables')" style="font-size:0.68rem; color:#0284c7;">Lun a Vie</button>
                                                        </div>
                                                    </div>
                                                    <div class="d-flex gap-1 mt-1" id="dias_semana_pills">
                                                        <button type="button" class="btn btn-sm btn-outline-secondary py-0.5 px-2 active btn-dia-rango" data-wday="1" onclick="window.toggleDiaRango(this)">Lun</button>
                                                        <button type="button" class="btn btn-sm btn-outline-secondary py-0.5 px-2 active btn-dia-rango" data-wday="2" onclick="window.toggleDiaRango(this)">Mar</button>
                                                        <button type="button" class="btn btn-sm btn-outline-secondary py-0.5 px-2 active btn-dia-rango" data-wday="3" onclick="window.toggleDiaRango(this)">Mié</button>
                                                        <button type="button" class="btn btn-sm btn-outline-secondary py-0.5 px-2 active btn-dia-rango" data-wday="4" onclick="window.toggleDiaRango(this)">Jue</button>
                                                        <button type="button" class="btn btn-sm btn-outline-secondary py-0.5 px-2 active btn-dia-rango" data-wday="5" onclick="window.toggleDiaRango(this)">Vie</button>
                                                        <button type="button" class="btn btn-sm btn-outline-secondary py-0.5 px-2 active btn-dia-rango" data-wday="6" onclick="window.toggleDiaRango(this)">Sáb</button>
                                                        <button type="button" class="btn btn-sm btn-outline-secondary py-0.5 px-2 active btn-dia-rango" data-wday="7" onclick="window.toggleDiaRango(this)">Dom</button>
                                                    </div>
                                                </div>

                                                <div class="col-12 mt-1.5">
                                                    <div id="box_diagnostico_rango" class="d-flex flex-wrap align-items-center justify-content-between gap-1 p-1.5 rounded-2 bg-white border" style="font-size:0.72rem;">
                                                        <span id="lbl_conteo_dias_rango" class="fw-semibold text-navy">
                                                            <i class="bi bi-info-circle text-teal me-1"></i>Indique fecha de inicio y fin
                                                        </span>
                                                        <span id="lbl_status_anticolision_rango" class="badge bg-light text-secondary border">Sin verificar</span>
                                                    </div>
                                                    <div id="lista_conflictos_rango" class="mt-1 d-none"></div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Fila 3: Nombre del Arrendatario (Híbrido Libre + Autocomplete Colaboradores Activos) y Teléfono -->
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_paciente">Nombre del Médico / Arrendatario <span class="text-danger">*</span> <span class="text-muted fw-normal" style="font-size:0.65rem;">(Libre o buscar colaborador)</span></label>
                                        <div class="position-relative" id="wrapper_autocomplete_arrendatario">
                                            <input type="text" name="nombre_arrendatario" id="f_paciente" class="form-control form-control-compact pe-4" placeholder="Escribe libremente o busca médico activo..." autocomplete="off" required>
                                            <i class="bi bi-search position-absolute end-0 top-50 translate-middle-y me-2.5 text-teal" style="font-size: 0.8rem; cursor: pointer;" onclick="window.mostrarSugerenciasMedicosActivos(true)" title="Ver médicos colaboradores activos"></i>
                                            <div id="dropdown_autocomplete_medicos" class="dropdown-menu w-100 shadow-lg border rounded-3 p-1 mt-1" style="max-height: 220px; overflow-y: auto; z-index: 106500; display: none;"></div>
                                        </div>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_telefono_arrendatario">Teléfono de Contacto</label>
                                        <input type="text" name="telefono_arrendatario" id="f_telefono_arrendatario" class="form-control form-control-compact" placeholder="10 dígitos...">
                                    </div>

                                    <!-- Fila 4: Uso / Procedimiento y Costo de Renta -->
                                    <div class="col-md-8">
                                        <label class="form-label-compact" for="f_motivo">Uso / Procedimiento / Especialidad <span class="text-danger">*</span></label>
                                        <input type="text" name="motivo" id="f_motivo" class="form-control form-control-compact" placeholder="Ej: Renta por turno / Cirugía ambulatoria..." required>
                                    </div>
                                    <div class="col-md-4">
                                        <div class="d-flex align-items-center justify-content-between">
                                            <label class="form-label-compact" for="f_monto_renta">Monto Renta (\$ MXN)</label>
                                            <span id="lbl_tarifa_rango_tipo" class="badge text-primary bg-primary-subtle border border-primary-subtle d-none" style="font-size:0.62rem; cursor:pointer;" onclick="window.toggleTipoTarifaRango()" title="Clic para alternar entre Por Día y Total del Rango">Por día <i class="bi bi-arrow-repeat"></i></span>
                                        </div>
                                        <input type="number" step="0.01" min="0" name="monto_renta" id="f_monto_renta" class="form-control form-control-compact fw-bold text-success" value="0.00" placeholder="0.00" oninput="window.onMontoRentaChange()">
                                        <div id="lbl_calculo_total_rango" class="small text-muted mt-0.5 d-none" style="font-size:0.68rem; font-weight:600;"></div>
                                    </div>

                                    <!-- Fila 5: Estado y Notas de Equipamiento -->
                                    <div class="col-md-5">
                                        <label class="form-label-compact" for="f_estado">Estado de Reserva</label>
                                        <select name="estado" id="f_estado" class="form-select form-control-compact">
                                            <option value="Reservada">Reservada</option>
                                            <option value="Confirmada">Confirmada</option>
                                            <option value="En Uso">En Uso</option>
                                            <option value="Finalizada">Finalizada</option>
                                            <option value="No realizada">No realizada</option>
                                            <option value="Cancelada">Cancelada</option>
                                        </select>
                                    </div>
                                    <div class="col-md-7">
                                        <label class="form-label-compact" for="f_notas">Equipamiento Requerido / Notas</label>
                                        <input type="text" name="notas" id="f_notas" class="form-control form-control-compact" placeholder="Ej: Requiere cauterio, lámpara quirúrgica...">
                                    </div>
                                </div>

                                <div id="leyenda-cita-pagada" class="badge text-success px-3 py-2 rounded-2 d-none mt-2 text-start" style="font-size: 0.8rem; font-weight: 500; background-color: #f0fdf4; border: 1px solid #bbf7d0;">
                                    <i class="bi bi-check-circle-fill me-1 text-success"></i> Renta Liquidada en Recepción
                                </div>
                            </div>

                            <!-- PANEL DERECHO: DURACIÓN Y SLOTS ANTICOLISIÓN (5 COLS) -->
                            <div class="col-lg-5">
                                <div class="h-100 d-flex flex-column p-2.5 rounded-3" style="background-color: #f8fafc; border: 1px solid rgba(25, 183, 165, 0.28);">
                                    <div class="mb-2">
                                        <div class="d-flex align-items-center justify-content-between mb-1">
                                            <label class="form-label-compact m-0"><i class="bi bi-sliders text-teal me-1"></i>Duración del Bloque de Renta</label>
                                            <span class="badge bg-navy text-white px-2 py-0.5 fw-bold" id="lbl_slider_duracion_badge" style="font-size: 0.70rem;">1 hr (60 min)</span>
                                        </div>

                                        <!-- Slider Táctil de Duración (30 min hasta Resto del Día) -->
                                        <div class="px-2 py-1.5 bg-white rounded-3 border shadow-2xs mb-1.5">
                                            <input type="range" class="form-range m-0" id="slider_duracion_renta" min="30" max="480" step="30" value="60" oninput="window.onDuracionSliderChange(this.value)">
                                            <div class="d-flex justify-content-between text-muted fw-semibold" style="font-size: 0.62rem; margin-top: -2px;">
                                                <span>30m</span>
                                                <span>2h</span>
                                                <span>4h (Turno)</span>
                                                <span>6h</span>
                                                <span id="lbl_slider_max_mark">8h+ / Cierre</span>
                                            </div>
                                        </div>

                                        <!-- Píldoras de Acceso Rápido + Resto del Día + Día Completo -->
                                        <div class="d-flex gap-1 dur-bar-premium w-100" id="btn-group-duracion"></div>

                                        <div id="bloqueo-horario-avena" class="bloqueo-avena-card d-none mt-2 p-2 rounded-3 animate__animated animate__fadeIn">
                                            <div class="d-flex align-items-center justify-content-between">
                                                <div class="d-flex align-items-center gap-1.5">
                                                    <i class="bi bi-lock-fill" style="color: #D97706; font-size: 0.85rem;"></i>
                                                    <span style="font-size: 0.74rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px;">Bloque Reservado:</span>
                                                </div>
                                                <span id="bloqueo-horario-rango" class="badge badge-avena-highlight" style="font-size: 0.78rem; font-weight: 700; padding: 0.22rem 0.55rem; border-radius: 6px;">
                                                    --:--
                                                </span>
                                            </div>
                                            <div class="d-flex align-items-center justify-content-between mt-1 pt-1" style="border-top: 1px dashed rgba(217, 119, 6, 0.25); font-size: 0.7rem; color: #92400E;">
                                                <span><i class="bi bi-door-open me-1"></i>Espacio apartado</span>
                                                <span id="bloqueo-horario-detalle" class="fw-semibold">--</span>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="d-flex flex-column flex-grow-1">
                                        <div class="d-flex align-items-center justify-content-between mb-1">
                                            <label class="form-label-compact m-0">Horarios Disponibles (Anticolisión)</label>
                                            <span class="text-muted" style="font-size: 0.68rem;"><i class="bi bi-shield-check text-teal me-1"></i>Sincronizado con Pacientes</span>
                                        </div>
                                        <div id="slots-container" class="slot-grid-compact flex-grow-1" style="height: 185px; max-height: 195px; overflow-y: auto;"></div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- FOOTER DE ACCIONES -->
                        <div class="d-flex flex-column flex-sm-row justify-content-between align-items-center gap-2 pt-2.5 mt-2.5" style="border-top: 1px solid rgba(25, 183, 165, 0.2);">
                            <div class="d-flex align-items-center gap-2">
                                <button type="button" id="btn-del-cita" onclick="delCita()" class="btn btn-outline-danger btn-compact d-none">
                                    <i class="bi bi-trash3 me-1"></i>Eliminar Reserva
                                </button>
                            </div>
                            <div class="d-flex align-items-center gap-2 ms-auto">
                                <button type="button" class="btn btn-light btn-compact border" data-bs-dismiss="modal">
                                    Cancelar
                                </button>
                                <button type="button" id="btn-cobrar-recepcion" onclick="cobrarRecepcionModal()" class="btn btn-amber btn-compact d-none">
                                    <i class="bi bi-cash-coin me-1"></i> Cobrar Renta
                                </button>
                                <button type="button" onclick="saveCita()" class="btn btn-teal-primary btn-compact">
                                    <i class="bi bi-check2-circle me-1"></i>Guardar Reserva
                                </button>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL CONFIGURACION OPERATIVA DE ESPACIOS (VARIANTE PREMIUM BOOTSTRAP 5.3 + SEDE ACTIVA) -->
    <div class="modal fade modal-apertura-premium" id="modalAjustes" tabindex="-1" aria-hidden="true" style="z-index: 105150 !important;">
        <div class="modal-dialog modal-dialog-centered modal-lg" style="zoom: 0.75;">
            <div class="modal-content card-mobile-flush custom-modal-card">
                <!-- Modal Top Bar -->
                <div class="modal-top-bar d-flex align-items-center justify-content-between">
                    <div class="d-flex align-items-center gap-3">
                        <div class="icon-header-badge shadow-sm">
                            <i class="bi bi-sliders2"></i>
                        </div>
                        <div>
                            <div class="d-flex align-items-center gap-2 flex-wrap">
                                <h5 class="fw-bold mb-0 text-navy">Configuración de Agenda &amp; Disponibilidad de Sede</h5>
                                <span class="badge-pill-teal"><i class="bi bi-check-circle-fill me-1"></i>Parámetros de Sede</span>
                            </div>
                            <p class="text-secondary small mb-0 mt-0.5" style="font-size: 0.76rem;">Define horarios operativos, intervalo de cuadrícula, bloqueos preventivos y días inhábiles para la sede seleccionada.</p>
                        </div>
                    </div>
                    <button type="button" class="btn-close btn-sm p-2" data-bs-dismiss="modal" aria-label="Cerrar"></button>
                </div>

                <!-- Modal Body (2 Columnas) -->
                <div class="p-3 p-md-4">
                    <form id="formAjustes" class="m-0" onsubmit="event.preventDefault(); guardarAjustes();">
                        <input type="hidden" name="adj_tipo_ambito" id="adj_ambito_sucursal" value="sucursal">
                        <input type="hidden" name="int" id="adj_int" value="30">
                        <input type="hidden" name="espacios_bloqueados" id="adj_espacios_bloqueados" value="">
                        <input type="hidden" id="adj_sucursal_select" value="$id_sucursal_activa">

                        <div class="row g-3 g-md-4">
                            <!-- COLUMNA IZQUIERDA -->
                            <div class="col-12 col-lg-6 d-flex flex-column gap-3">
                                <!-- Sucursal / Sede Física (Solo Sede Activa) -->
                                <div>
                                    <label class="section-label mb-2"><i class="bi bi-geo-alt-fill text-muted"></i> Sucursal / Sede Física</label>
                                    <div class="field-card d-flex align-items-center justify-content-between">
                                        <div class="d-flex align-items-center gap-2.5">
                                            <div class="d-flex align-items-center justify-content-center rounded-3" style="width: 36px; height: 36px; background: rgba(10, 42, 102, 0.08); color: #0A2A66;">
                                                <i class="bi bi-hospital fs-5"></i>
                                            </div>
                                            <div>
                                                <span class="fw-bold text-dark d-block small" id="lbl_adj_sucursal_nombre">$nombre_sucursal_activa</span>
                                                <small class="text-muted" style="font-size: 0.72rem;">Sede Operativa Principal Sincronizada</small>
                                            </div>
                                        </div>
                                        <span class="badge bg-success-subtle text-success border border-success-subtle rounded-pill px-2.5 py-1 small fw-bold">
                                            <i class="bi bi-check-circle-fill me-1"></i>Activa
                                        </span>
                                    </div>
                                </div>

                                <!-- Jornada de Apertura y Cierre -->
                                <div>
                                    <div class="d-flex align-items-center justify-content-between mb-2">
                                        <label class="section-label mb-0"><i class="bi bi-clock-fill text-muted"></i> Jornada de Apertura y Cierre</label>
                                        <span class="text-secondary" style="font-size: 0.74rem;">Horario de operación general</span>
                                    </div>
                                    <div class="row g-2">
                                        <div class="col-6">
                                            <div class="field-card">
                                                <label class="text-muted small d-block mb-1" style="font-size: 0.72rem; font-weight: 600;">Apertura Sede</label>
                                                <div class="input-group input-group-sm">
                                                    <input type="time" class="form-control border-0 p-0 fw-bold fs-6 text-dark" id="adj_h_ini" name="h_ini" required value="07:00">
                                                    <span class="input-group-text bg-transparent border-0 text-muted p-0"><i class="bi bi-clock"></i></span>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="col-6">
                                            <div class="field-card">
                                                <label class="text-muted small d-block mb-1" style="font-size: 0.72rem; font-weight: 600;">Cierre Sede</label>
                                                <div class="input-group input-group-sm">
                                                    <input type="time" class="form-control border-0 p-0 fw-bold fs-6 text-dark" id="adj_h_fin" name="h_fin" required value="23:59">
                                                    <span class="input-group-text bg-transparent border-0 text-muted p-0"><i class="bi bi-clock"></i></span>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <!-- Días Hábiles en Píldoras Interactivas -->
                                <div>
                                    <div class="d-flex align-items-center justify-content-between mb-2">
                                        <label class="section-label mb-0"><i class="bi bi-calendar-week-fill text-muted"></i> Días Hábiles de Renta en Sede</label>
                                        <span class="badge rounded-pill px-2.5 py-1 fw-bold" id="badgeDiasActivos" style="color: #009e95; background: #e6f9f8; font-size: 0.72rem;">7 Días Activos</span>
                                    </div>
                                    <div class="row g-1 text-center" id="diasContainer">
                                        <div class="col">
                                            <button type="button" class="btn-day-pill active" data-day="1" onclick="window.toggleDiaPill(this, 1)"><span>Lun</span><span class="dot"></span></button>
                                            <input class="adj-dia d-none" type="checkbox" value="1" id="d1" checked>
                                        </div>
                                        <div class="col">
                                            <button type="button" class="btn-day-pill active" data-day="2" onclick="window.toggleDiaPill(this, 2)"><span>Mar</span><span class="dot"></span></button>
                                            <input class="adj-dia d-none" type="checkbox" value="2" id="d2" checked>
                                        </div>
                                        <div class="col">
                                            <button type="button" class="btn-day-pill active" data-day="3" onclick="window.toggleDiaPill(this, 3)"><span>Mié</span><span class="dot"></span></button>
                                            <input class="adj-dia d-none" type="checkbox" value="3" id="d3" checked>
                                        </div>
                                        <div class="col">
                                            <button type="button" class="btn-day-pill active" data-day="4" onclick="window.toggleDiaPill(this, 4)"><span>Jue</span><span class="dot"></span></button>
                                            <input class="adj-dia d-none" type="checkbox" value="4" id="d4" checked>
                                        </div>
                                        <div class="col">
                                            <button type="button" class="btn-day-pill active" data-day="5" onclick="window.toggleDiaPill(this, 5)"><span>Vie</span><span class="dot"></span></button>
                                            <input class="adj-dia d-none" type="checkbox" value="5" id="d5" checked>
                                        </div>
                                        <div class="col">
                                            <button type="button" class="btn-day-pill active" data-day="6" onclick="window.toggleDiaPill(this, 6)"><span>Sáb</span><span class="dot"></span></button>
                                            <input class="adj-dia d-none" type="checkbox" value="6" id="d6" checked>
                                        </div>
                                        <div class="col">
                                            <button type="button" class="btn-day-pill active" data-day="7" onclick="window.toggleDiaPill(this, 7)"><span>Dom</span><span class="dot"></span></button>
                                            <input class="adj-dia d-none" type="checkbox" value="7" id="d7" checked>
                                        </div>
                                    </div>
                                </div>

                                <!-- Continuidad y Receso Operativo -->
                                <div class="field-card bg-light-subtle">
                                    <div class="d-flex align-items-center justify-content-between">
                                        <div>
                                            <label class="section-label mb-0 text-dark"><i class="bi bi-cup-hot-fill text-warning me-1"></i> Continuidad y Receso Operativo</label>
                                            <p class="text-secondary small mb-0 mt-0.5" style="font-size: 0.74rem;">Omitir horario de comida (Horario continuo / 24 hrs)</p>
                                        </div>
                                        <div class="form-check form-switch fs-5 mb-0">
                                            <input class="form-check-input" type="checkbox" role="switch" id="adj_sin_comida" checked onchange="toggleComidaAjustes(this.checked)">
                                        </div>
                                    </div>
                                    <div class="row g-2 mt-2 pt-2 border-top" id="recesoFields" style="opacity: 0.35; pointer-events: none;">
                                        <div class="col-6" id="wrapper_adj_c_ini">
                                            <div class="bg-white p-2 rounded border">
                                                <small class="text-muted d-block" style="font-size: 0.7rem; font-weight: 600;">INICIO RECESO</small>
                                                <input type="time" class="form-control form-control-sm border-0 p-0 fw-semibold" id="adj_c_ini" name="c_ini" value="14:00">
                                            </div>
                                        </div>
                                        <div class="col-6" id="wrapper_adj_c_fin">
                                            <div class="bg-white p-2 rounded border">
                                                <small class="text-muted d-block" style="font-size: 0.7rem; font-weight: 600;">FIN RECESO</small>
                                                <input type="time" class="form-control form-control-sm border-0 p-0 fw-semibold" id="adj_c_fin" name="c_fin" value="15:00">
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- COLUMNA DERECHA -->
                            <div class="col-12 col-lg-6 d-flex flex-column gap-3">
                                <!-- Intervalo de Cuadrícula -->
                                <div>
                                    <div class="d-flex align-items-center justify-content-between mb-2">
                                        <label class="section-label mb-0"><i class="bi bi-grid-3x3-gap-fill text-muted"></i> Intervalo de Cuadrícula</label>
                                        <span class="badge text-white px-2.5 py-1 rounded" id="badgeIntervalo" style="background-color: #0A2A66; font-size: 0.75rem; font-weight: 700;">30 minutos</span>
                                    </div>
                                    <div class="btn-group w-100 interval-btn-group" role="group">
                                        <input type="radio" class="btn-check" name="intervalRadio" id="int15" autocomplete="off" onchange="window.updateIntervalModal(15)">
                                        <label class="btn btn-outline-secondary" for="int15">15 minutos</label>

                                        <input type="radio" class="btn-check" name="intervalRadio" id="int30" autocomplete="off" checked onchange="window.updateIntervalModal(30)">
                                        <label class="btn btn-outline-secondary" for="int30">30 minutos</label>

                                        <input type="radio" class="btn-check" name="intervalRadio" id="int60" autocomplete="off" onchange="window.updateIntervalModal(60)">
                                        <label class="btn btn-outline-secondary" for="int60">60 minutos</label>
                                    </div>
                                    <input type="range" class="form-range mt-2" min="15" max="60" step="15" value="30" id="sliderInterval" oninput="window.handleSliderIntervalModal(this.value)">
                                </div>

                                <!-- Bloqueo Preventivo de Espacios Físicos -->
                                <div>
                                    <div class="d-flex align-items-center justify-content-between mb-2">
                                        <div>
                                            <label class="section-label mb-0"><i class="bi bi-shield-lock-fill text-muted"></i> Bloqueo Preventivo de Espacios</label>
                                            <small class="text-secondary d-block" style="font-size: 0.72rem;">Impide nuevas reservaciones en consultorios o quirófanos</small>
                                        </div>
                                        <div class="btn-group btn-group-sm">
                                            <button type="button" class="btn btn-sm btn-outline-secondary py-0 px-2" style="font-size: 0.72rem;" onclick="window.marcarBloqueoTodosEspacios(true)">Marcar todos</button>
                                            <button type="button" class="btn btn-sm btn-outline-secondary py-0 px-2" style="font-size: 0.72rem;" onclick="window.marcarBloqueoTodosEspacios(false)">Desmarcar</button>
                                        </div>
                                    </div>
                                    <div class="row g-2" id="lista_bloqueo_espacios_modal" style="max-height: 200px; overflow-y: auto;">
                                        <div class="text-center py-2 text-muted small w-100">Cargando inventario de espacios...</div>
                                    </div>
                                </div>

                                <!-- Días Inhábiles / Mantenimiento -->
                                <div>
                                    <label class="section-label mb-1"><i class="bi bi-calendar-x-fill text-muted"></i> Días Inhábiles / Mantenimiento</label>
                                    <div class="input-group input-group-sm mb-2">
                                        <input type="date" class="form-control" id="adj_fest_picker">
                                        <select class="form-select" id="selectMotivoInhabil" style="max-width: 140px;">
                                            <option value="Mantenimiento">Mantenimiento</option>
                                            <option value="Feriado Oficial">Feriado Oficial</option>
                                            <option value="Fumigación">Fumigación</option>
                                        </select>
                                        <button class="btn fw-bold" type="button" onclick="window.agregarFechaInhabil()" style="color: #009e95; border-color: #00c0b5; background-color: #e6f9f8;">
                                            <i class="bi bi-plus-lg me-1"></i>Agregar
                                        </button>
                                    </div>
                                    <div class="d-flex flex-wrap gap-1.5" id="contenedorTagsFechas"></div>
                                    <input type="hidden" id="adj_fest" name="festivos" value="">
                                </div>
                            </div>
                        </div>
                    </form>
                </div>

                <!-- Modal Footer -->
                <div class="bg-light px-4 py-3 border-top d-flex flex-column flex-sm-row align-items-center justify-content-between gap-3">
                    <div class="d-flex align-items-center gap-2 text-muted small">
                        <i class="bi bi-shield-check text-success fs-5"></i>
                        <span style="font-size: 0.76rem;">Configuración sincronizada con la sede física • <strong class="text-dark">Norma Oficial NOM-024</strong></span>
                    </div>
                    <div class="d-flex align-items-center gap-2 w-100 w-sm-auto justify-content-end">
                        <button type="button" class="btn btn-light border text-secondary fw-semibold px-4 py-2" data-bs-dismiss="modal" style="border-radius: 0.75rem; font-size: 0.85rem;">
                            Cancelar
                        </button>
                        <button type="button" class="btn btn-osp-navy" onclick="guardarAjustes()">
                            <i class="bi bi-check2-circle"></i> Guardar Configuración
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- LIBRERÍAS DATA TABLES Y SWEETALERT -->
    <script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/pdfmake.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/vfs_fonts.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
    <script src="../js/agenda_espacios_spa.js?v=$^T"></script>
HTML

print <<'JS';
    <script>
        document.body.classList.add('agenda-page-layout');
        try {
            window.medicosCatalogo = JSON.parse(document.getElementById('json_medicos_catalogo')?.textContent || '{}');
            window.medicosActivosList = JSON.parse(document.getElementById('json_medicos_activos_list')?.textContent || '[]');
        } catch(e) {
            window.medicosCatalogo = {};
            window.medicosActivosList = [];
        }

        document.addEventListener('DOMContentLoaded', function() {
            var fSucursal = document.getElementById('f_sucursal');
            var fConsultorio = document.getElementById('f_consultorio');

            window.cargarRecursos = function(idSucursal, consultorioSeleccionado) {
                if (fConsultorio) fConsultorio.innerHTML = '<option value="">Cargando espacios...</option>';
                fetch('../api/espacios_crud.pl?accion=get_recursos&id_sucursal=' + (idSucursal || ''))
                    .then(r => r.json())
                    .then(data => {
                        if (data.ok) {
                            window.sucursalRecursos = data;
                            if (fConsultorio) {
                                let html = '<optgroup label="Consultorios">';
                                for (let i = 1; i <= (data.consultorios || 1); i++) {
                                    html += `<option value="Consultorio ${i}">Consultorio ${i}</option>`;
                                }
                                html += '</optgroup>';

                                if (data.quirofanos > 0) {
                                    html += '<optgroup label="Quirófanos">';
                                    for (let i = 1; i <= data.quirofanos; i++) {
                                        html += `<option value="Quirófano ${i}">Quirófano ${i}</option>`;
                                    }
                                    html += '</optgroup>';
                                }
                                fConsultorio.innerHTML = html;
                                if (consultorioSeleccionado) {
                                    fConsultorio.value = consultorioSeleccionado;
                                }
                            }
                            if (typeof window.poblarFiltroRecursosToolbar === 'function') {
                                window.poblarFiltroRecursosToolbar(data);
                            }
                            if (typeof window.actualizarHeaderEspaciosHabilitados === 'function') {
                                window.actualizarHeaderEspaciosHabilitados();
                            }
                            if (typeof currentView !== 'undefined' && currentView === 'dia' && typeof renderTimeline === 'function') {
                                renderTimeline();
                            }
                        }
                    })
                    .catch(e => {
                        console.error("Error cargando recursos de espacios", e);
                    });
            };

            if (fSucursal) {
                fSucursal.addEventListener('change', function() {
                    window.cargarRecursos(this.value);
                    if (typeof renderSlots === 'function' && document.getElementById('f_fecha')) {
                        renderSlots(document.getElementById('f_fecha').value);
                    }
                });
            }

            if (fConsultorio) {
                fConsultorio.addEventListener('change', function() {
                    if (typeof renderSlots === 'function' && document.getElementById('f_fecha')) {
                        renderSlots(document.getElementById('f_fecha').value);
                    }
                });
            }

            if (fSucursal && fSucursal.value) {
                window.cargarRecursos(fSucursal.value);
            } else {
                window.cargarRecursos('');
            }
        });
    </script>
JS

utils::sub_sidebar::render_sidebar_footer();
print <<HTML;
</body>
</html>
HTML

render_bottom_nav('agenda_espacios');
1;

