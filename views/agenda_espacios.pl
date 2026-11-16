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
        <div class="d-none d-lg-block dropdown" id="wrapper_filtro_medicos_toolbar" style="position: relative; z-index: 106000;">
            <button class="btn btn-light fw-bold rounded-3 shadow-sm border bg-white d-flex align-items-center justify-content-between px-3 text-navy dropdown-toggle" 
                    type="button" 
                    id="btn_filtro_medico_dropdown" 
                    data-bs-toggle="dropdown" 
                    data-bs-auto-close="outside" 
                    data-bs-popper-config='{"strategy":"fixed"}'
                    aria-expanded="false" 
                    style="height:42px; font-size:0.80rem; min-width: 190px; max-width: 250px;" 
                    title="Filtrar por Arrendatarios / Profesionales">
                <span class="d-flex align-items-center gap-1.5 text-truncate" id="filtro_medico_btn_label">
                    <i class="bi bi-people-fill text-primary"></i>
                    <span class="text-truncate">Arrendatarios ($cnt_med)</span>
                </span>
            </button>
            <div class="dropdown-menu dropdown-menu-end shadow-lg p-2.5 border-0 rounded-4" id="dropdown_filtro_medico_menu" aria-labelledby="btn_filtro_medico_dropdown" style="min-width: 270px; max-height: 420px; overflow-y: auto; z-index: 106000 !important;">
                <div class="d-flex align-items-center justify-content-between px-2 py-1 border-bottom mb-2">
                    <span class="fw-black text-navy small text-uppercase" style="font-size:0.72rem; letter-spacing:0.5px;">Arrendatarios / Médicos</span>
                    <div class="d-flex align-items-center gap-1.5">
                        <button type="button" class="btn btn-link btn-sm p-0 text-primary fw-bold text-decoration-none" onclick="window.seleccionarTodosMedicos(true)" style="font-size:0.72rem;">Marcar todos</button>
                        <span class="text-muted opacity-50" style="font-size:0.70rem;">•</span>
                        <button type="button" class="btn btn-link btn-sm p-0 text-secondary fw-semibold text-decoration-none" onclick="window.seleccionarTodosMedicos(false)" style="font-size:0.72rem;">Desmarcar</button>
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
foreach my $s (@sucursales_org) {
    my $sel = ($s->{id} eq $id_negocio_activo || scalar(@sucursales_org) == 1) ? 'selected' : '';
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
        <header class="agenda-header sticky-top animate__animated animate__fadeInDown">
            <div class="container-fluid">
                <div class="d-flex align-items-center justify-content-between gap-2 py-2 w-100 flex-nowrap" style="overflow: visible !important;">
                    
                    <!-- BLOQUE 1: NAVEGACIÓN TEMPORAL Y MODOS DE VISUALIZACIÓN -->
                    <div class="d-flex align-items-center gap-2 flex-shrink-0">
                        <span class="badge bg-navy text-white px-2.5 py-2 rounded-3 d-none d-xl-inline-flex align-items-center gap-1.5 shadow-2xs" style="height:42px; font-size:0.76rem;">
                            <i class="bi bi-door-open-fill text-teal"></i> RENTA DE ESPACIOS
                        </span>

                        <button onclick="goToday()" class="btn btn-navy fw-black rounded-3 px-3 shadow-sm text-uppercase" style="font-size:0.75rem; height:42px;">HOY</button>
                        
                        <div class="d-none d-md-flex align-items-center date-nav-pill shadow-sm">
                            <button onclick="moveDate(-1)" class="btn btn-link text-navy p-1" title="Anterior"><i class="bi bi-chevron-left"></i></button>
                            <h1 class="h6 mb-0 fw-black text-navy text-uppercase tracking-tight mx-2 text-nowrap" id="current-date-label-desktop" style="min-width: 170px; text-align: center; font-size: 0.82rem;">
                                CARGANDO...
                            </h1>
                            <button onclick="moveDate(1)" class="btn btn-link text-navy p-1" title="Siguiente"><i class="bi bi-chevron-right"></i></button>
                        </div>

                        <div class="vr mx-1 opacity-25 d-none d-lg-block" style="height: 26px;"></div>

                        <!-- Modos de Vista Principal -->
                        <div class="nav-pill-group shadow-sm">
                            <button onclick="switchView('dia')" class="btn-view-toggle active" id="btn-v-dia" title="Vista Diaria por Consultorios y Quirófanos"><i class="bi bi-calendar-event"></i></button>
                            <button onclick="switchView('semana_smart')" class="btn-view-toggle" id="btn-v-semana-smart" title="Vista Semanal Smart de Espacios"><i class="bi bi-calendar-week"></i></button>
                            <button onclick="switchView('calendario')" class="btn-view-toggle" id="btn-v-calendario" title="Vista Mensual Grid"><i class="bi bi-grid-3x3"></i></button>
                        </div>

                        <!-- Reportes Operativos DataTables (Diario, Semanal y Mensual) -->
                        <div class="nav-pill-group shadow-sm d-none d-xl-flex">
                            <button onclick="switchView('dia_reporte')" class="btn-report-toggle" id="btn-r-dia-reporte" title="Reporte Diario de Espacios"><i class="bi bi-file-earmark-ruled"></i></button>
                            <button onclick="switchView('semana')" class="btn-report-toggle" id="btn-r-semana" title="Reporte Semanal de Espacios"><i class="bi bi-file-earmark-text"></i></button>
                            <button onclick="switchView('mes')" class="btn-report-toggle" id="btn-r-mes" title="Reporte Mensual de Espacios"><i class="bi bi-file-earmark-bar-graph"></i></button>
                        </div>
                    </div>

                    <!-- BLOQUE 2: FILTROS OPERATIVOS, NUEVA RESERVA Y UTILIDADES -->
                    <div class="d-flex align-items-center gap-2 flex-shrink-0 ms-auto">
                        <button type="button" onclick="window.abrirModalNuevaRenta()" class="btn btn-teal text-white fw-bold rounded-3 px-3 shadow-sm d-flex align-items-center gap-1.5" style="height:42px; font-size:0.80rem; background-color: var(--md-teal-clinical, #19B7A5);">
                            <i class="bi bi-plus-circle-fill"></i>
                            <span class="d-none d-sm-inline">Reservar Espacio</span>
                        </button>

                        <!-- Filtro Arrendatarios -->
                        $html_filtro_medicos_toolbar

                        <!-- Filtro Espacios Físicos (Consultorios y Quirófanos de Gestión de Sucursales) -->
                        <div class="d-none d-lg-block dropdown" id="wrapper_filtro_recurso_toolbar" style="position: relative; z-index: 106000;">
                            <button class="btn btn-light fw-bold rounded-3 shadow-sm border bg-white d-flex align-items-center justify-content-between px-3 text-navy dropdown-toggle" 
                                    type="button" 
                                    id="btn_filtro_recurso_dropdown" 
                                    data-bs-toggle="dropdown" 
                                    data-bs-auto-close="outside" 
                                    data-bs-popper-config='{"strategy":"fixed"}'
                                    aria-expanded="false" 
                                    style="height:42px; font-size:0.80rem; min-width: 190px; max-width: 250px;" 
                                    title="Filtrar por Consultorios y Quirófanos">
                                <span class="d-flex align-items-center gap-1.5 text-truncate" id="filtro_recurso_btn_label">
                                    <i class="bi bi-door-open-fill text-teal"></i>
                                    <span class="text-truncate">Todos los Espacios</span>
                                </span>
                            </button>
                            <div class="dropdown-menu dropdown-menu-end shadow-lg p-2.5 border-0 rounded-4" id="dropdown_filtro_recurso_menu" aria-labelledby="btn_filtro_recurso_dropdown" style="min-width: 270px; max-height: 420px; overflow-y: auto; z-index: 106000 !important;">
                                <div class="d-flex align-items-center justify-content-between px-2 py-1 border-bottom mb-2">
                                    <span class="fw-black text-navy small text-uppercase" style="font-size:0.72rem; letter-spacing:0.5px;">Consultorios y Quirófanos</span>
                                    <div class="d-flex align-items-center gap-1.5">
                                        <button type="button" class="btn btn-link btn-sm p-0 text-primary fw-bold text-decoration-none" onclick="window.seleccionarTodosEspacios(true)" style="font-size:0.72rem;">Marcar todos</button>
                                        <span class="text-muted opacity-50" style="font-size:0.70rem;">•</span>
                                        <button type="button" class="btn btn-link btn-sm p-0 text-secondary fw-semibold text-decoration-none" onclick="window.seleccionarTodosEspacios(false)" style="font-size:0.72rem;">Desmarcar</button>
                                    </div>
                                </div>
                                <div id="lista_checkboxes_recursos" class="d-flex flex-column gap-1">
                                    <div class="text-center py-2 text-muted small">Cargando espacios...</div>
                                </div>
                            </div>
                        </div>

                        <!-- Toggle Mini Calendario Lateral -->
                        <button type="button" class="btn btn-light fw-bold rounded-3 shadow-sm border bg-white d-none d-lg-inline-flex align-items-center justify-content-center" id="btn-toggle-side-cal" onclick="toggleSideCalendar()" style="height:42px; width:42px; padding:0;" title="Mostrar/Ocultar Minicalendario Lateral">
                            <i class="bi bi-layout-sidebar-inset text-teal" style="font-size:1.05rem;"></i>
                        </button>

                        <div class="vr mx-1 opacity-25 d-none d-md-block" style="height: 26px;"></div>

                        <!-- Leyenda de Estados y Colores -->
                        <div class="dropdown">
                            <button class="btn btn-light fw-medium rounded-3 shadow-sm border bg-white px-2.5 d-flex align-items-center gap-1.5" type="button" id="dropdownLeyendaColores" data-bs-toggle="dropdown" aria-expanded="false" style="height:42px;" title="Significado de Estados de Renta">
                                <i class="bi bi-palette" style="font-size:1.05rem; color: var(--md-teal-clinical, #19B7A5) !important;"></i>
                                <span class="small d-none d-xl-inline text-secondary">Estados</span>
                            </button>
                            <div class="dropdown-menu dropdown-menu-end shadow-lg p-3 border-0 rounded-4" style="min-width: 280px; z-index: 105200;" aria-labelledby="dropdownLeyendaColores">
                                <h6 class="fw-semibold text-navy small mb-2.5 d-flex align-items-center gap-1.5">
                                    <i class="bi bi-info-circle" style="color: var(--md-teal-clinical, #19B7A5);"></i> Estados de Renta de Espacio
                                </h6>
                                <div class="d-flex flex-column gap-2 small">
                                    <div class="d-flex align-items-center gap-2">
                                        <span class="rounded-circle d-inline-block" style="width: 12px; height: 12px; background-color: #0A2A66;"></span>
                                        <span class="fw-medium text-dark">Reservada</span>
                                        <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Apartada</span>
                                    </div>
                                    <div class="d-flex align-items-center gap-2">
                                        <span class="rounded-circle d-inline-block" style="width: 12px; height: 12px; background-color: #10b981;"></span>
                                        <span class="fw-medium text-dark">Confirmada</span>
                                        <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Confirmada / Pagada</span>
                                    </div>
                                    <div class="d-flex align-items-center gap-2">
                                        <span class="rounded-circle d-inline-block" style="width: 12px; height: 12px; background-color: #059669;"></span>
                                        <span class="fw-medium text-dark">En Uso</span>
                                        <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Ocupación activa</span>
                                    </div>
                                    <div class="d-flex align-items-center gap-2">
                                        <span class="rounded-circle d-inline-block" style="width: 12px; height: 12px; background-color: #19B7A5;"></span>
                                        <span class="fw-medium text-dark">Finalizada</span>
                                        <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Entregado</span>
                                    </div>
                                    <div class="d-flex align-items-center gap-2">
                                        <span class="rounded-circle d-inline-block" style="width: 12px; height: 12px; background-color: #64748b;"></span>
                                        <span class="fw-medium text-dark">Ocupado (Pacientes)</span>
                                        <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Bloqueo clínico</span>
                                    </div>
                                    <div class="d-flex align-items-center gap-2">
                                        <span class="rounded-circle d-inline-block" style="width: 12px; height: 12px; background-color: #ef4444;"></span>
                                        <span class="fw-medium text-dark">No realizada</span>
                                        <span class="text-muted ms-auto text-end" style="font-size: 0.72rem;">Expirada</span>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Botón Ajustes de Jornada de Sucursal -->
                        <button onclick="abrirModalAjustes()" class="btn btn-light fw-bold rounded-3 shadow-sm border bg-white" style="height:42px; width:42px; padding:0;" title="Ajustes de Horario de la Sede"><i class="bi bi-gear-fill"></i></button>
                    </div>
                </div>

                <!-- ROW 2 (Solo Móvil): NAVEGACIÓN DE FECHA -->
                <div class="d-flex d-md-none justify-content-center pb-2">
                    <div class="d-flex align-items-center justify-content-between date-nav-pill w-100 mx-0">
                        <button onclick="moveDate(-1)" class="btn btn-link text-navy p-2"><i class="bi bi-chevron-left"></i></button>
                        <h1 class="h6 mb-0 fw-black text-navy text-uppercase tracking-tight mx-2" id="current-date-label-mobile" style="text-align: center;">
                            CARGANDO...
                        </h1>
                        <button onclick="moveDate(1)" class="btn btn-link text-navy p-2"><i class="bi bi-chevron-right"></i></button>
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

                        <div class="row g-3 align-items-stretch">
                            <!-- PANEL IZQUIERDO: DATOS DEL ESPACIO Y ARRENDATARIO (7 COLS) -->
                            <div class="col-lg-7 d-flex flex-column justify-content-between">
                                <div class="row g-2">
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
                                    <div class="col-md-6">
                                        <label class="form-label-compact" for="f_fecha">Fecha de Reserva <span class="text-danger">*</span></label>
                                        <input type="date" name="fecha" id="f_fecha" class="form-control form-control-compact" onchange="renderSlots(this.value)">
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
                                        <label class="form-label-compact" for="f_monto_renta">Monto Renta (\$ MXN)</label>
                                        <input type="number" step="0.01" min="0" name="monto_renta" id="f_monto_renta" class="form-control form-control-compact fw-bold text-success" value="0.00" placeholder="0.00">
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

    <!-- MODAL AJUSTES DE HORARIO DE LA SUCURSAL -->
    <div class="modal fade modal-diamond" id="modalAjustes" tabindex="-1" aria-hidden="true" style="z-index: 105150 !important;">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-0 shadow-lg rounded-4 overflow-hidden">
                <div class="modal-header py-3 px-4 border-bottom bg-white d-flex align-items-center justify-content-between">
                    <h5 class="modal-title fw-bold text-navy d-flex align-items-center mb-0" style="font-size: 1.05rem;">
                        <i class="bi bi-clock-history text-teal me-2 fs-5"></i> HORARIO DE APERTURA DE ESPACIOS
                    </h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body p-4 bg-light">
                    <form id="formAjustes">
                        <div class="row g-3">
                            <input type="hidden" name="adj_tipo_ambito" id="adj_ambito_sucursal" value="sucursal">
                            <div class="col-12" id="adj_sucursal_wrapper">
                                <div class="form-floating mb-1">
                                    <select class="form-select shadow-sm border-0 rounded-3 fw-bold" id="adj_sucursal_select" onchange="cargarAjustesSucursal(this.value)">
                                        $html_sucursal
                                    </select>
                                    <label class="text-muted fw-bold small text-uppercase">Sucursal / Sede Física</label>
                                </div>
                            </div>

                            <div class="col-6">
                                <div class="form-floating mb-2">
                                    <input type="time" class="form-control shadow-sm border-0 rounded-3 fw-bold" id="adj_h_ini" name="h_ini" required>
                                    <label class="text-muted fw-bold small text-uppercase">Apertura Sede</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating mb-2">
                                    <input type="time" class="form-control shadow-sm border-0 rounded-3 fw-bold" id="adj_h_fin" name="h_fin" required>
                                    <label class="text-muted fw-bold small text-uppercase">Cierre Sede</label>
                                </div>
                            </div>

                            <div class="col-12 mt-1 mb-1">
                                <div class="form-check form-switch p-2 ps-5 bg-white rounded-3 border shadow-2xs d-flex align-items-center">
                                    <input class="form-check-input ms-n5 me-2" type="checkbox" role="switch" id="adj_sin_comida" onchange="toggleComidaAjustes(this.checked)">
                                    <label class="form-check-label small fw-bold text-navy" for="adj_sin_comida" style="cursor: pointer;">
                                        <i class="bi bi-cup-hot text-teal me-1"></i> Omitir horario de comida (Horario continuo / 24 hrs)
                                    </label>
                                </div>
                            </div>
                            <div class="col-6" id="wrapper_adj_c_ini">
                                <div class="form-floating mb-2">
                                    <input type="time" class="form-control shadow-sm border-0 rounded-3" id="adj_c_ini" name="c_ini" value="14:00">
                                    <label class="text-muted fw-bold small text-uppercase">Inicio Receso</label>
                                </div>
                            </div>
                            <div class="col-6" id="wrapper_adj_c_fin">
                                <div class="form-floating mb-2">
                                    <input type="time" class="form-control shadow-sm border-0 rounded-3" id="adj_c_fin" name="c_fin" value="15:00">
                                    <label class="text-muted fw-bold small text-uppercase">Fin Receso</label>
                                </div>
                            </div>

                            <div class="col-12 mt-3">
                                <label class="small fw-bold text-muted mb-2 d-block text-uppercase">Días Hábiles de Renta en la Sede</label>
                                <div class="d-flex flex-wrap gap-2 mb-2 p-3 bg-white rounded-3 shadow-sm border">
                                    <div class="form-check form-check-inline m-0 me-2"><input class="form-check-input adj-dia" type="checkbox" value="1" id="d1"><label class="form-check-label small fw-bold" for="d1">Lun</label></div>
                                    <div class="form-check form-check-inline m-0 me-2"><input class="form-check-input adj-dia" type="checkbox" value="2" id="d2"><label class="form-check-label small fw-bold" for="d2">Mar</label></div>
                                    <div class="form-check form-check-inline m-0 me-2"><input class="form-check-input adj-dia" type="checkbox" value="3" id="d3"><label class="form-check-label small fw-bold" for="d3">Mié</label></div>
                                    <div class="form-check form-check-inline m-0 me-2"><input class="form-check-input adj-dia" type="checkbox" value="4" id="d4"><label class="form-check-label small fw-bold" for="d4">Jue</label></div>
                                    <div class="form-check form-check-inline m-0 me-2"><input class="form-check-input adj-dia" type="checkbox" value="5" id="d5"><label class="form-check-label small fw-bold" for="d5">Vie</label></div>
                                    <div class="form-check form-check-inline m-0 me-2"><input class="form-check-input adj-dia" type="checkbox" value="6" id="d6"><label class="form-check-label small fw-bold" for="d6">Sáb</label></div>
                                    <div class="form-check form-check-inline m-0 me-2"><input class="form-check-input adj-dia" type="checkbox" value="7" id="d7"><label class="form-check-label small fw-bold" for="d7">Dom</label></div>
                                </div>
                            </div>

                            <div class="col-12 mt-2">
                                <div class="form-floating mb-2">
                                    <select class="form-select shadow-sm border-0 rounded-3 fw-bold" id="adj_int" name="int">
                                        <option value="15">15 minutos</option>
                                        <option value="30" selected>30 minutos</option>
                                        <option value="60">60 minutos</option>
                                    </select>
                                    <label class="text-muted fw-bold small text-uppercase">Intervalo de Cuadrícula</label>
                                </div>
                            </div>

                            <div class="col-12 mt-2">
                                <label class="small fw-bold text-muted mb-2 d-block text-uppercase">Días Inhábiles / Mantenimiento</label>
                                <div class="input-group mb-2 shadow-sm rounded-3">
                                    <input type="date" class="form-control border-0" id="adj_fest_picker">
                                    <button type="button" class="btn btn-teal text-white px-3 fw-bold border-0" onclick="var f = document.getElementById('adj_fest'); var p = document.getElementById('adj_fest_picker'); if(p.value){ f.value = f.value ? f.value + ',' + p.value : p.value; p.value = ''; }"><i class="bi bi-plus-lg"></i> Agregar</button>
                                </div>
                                <div class="form-floating">
                                    <input type="text" class="form-control shadow-sm border-0 rounded-3" id="adj_fest" name="festivos" placeholder="YYYY-MM-DD, ...">
                                    <label class="text-muted fw-bold small text-uppercase">Fechas Seleccionadas</label>
                                </div>
                            </div>
                        </div>
                    </form>
                </div>
                <div class="modal-footer bg-light border-0 pt-0">
                    <button type="button" onclick="guardarAjustes()" class="btn btn-navy w-100 py-3 fw-bold shadow-sm border-0 rounded-3 text-uppercase" style="font-size: 0.88rem; letter-spacing: 0.5px;">
                        <i class="bi bi-save me-2"></i> Guardar Horario de la Sede
                    </button>
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

