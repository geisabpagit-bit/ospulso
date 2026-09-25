#!/usr/bin/perl
# --- Versión Suprema v3.1.6.3 (Header Fix) ---
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;

sub render_header {
    my %args = @_;
    my $usuario = $args{usuario} // 'Invitado';
    my $role    = $args{role}    // 'Visitante';
    my $titulo  = $args{titulo}  // 'Software Dental Mexicano';
    my $skip    = $args{skip_header} // 0;
    my $show_nav = $args{show_nav_content} // 1;

    my $iniciales = '';
    my @nombres = split(/\s+/, $usuario);
    $iniciales .= uc(substr($nombres[0], 0, 1)) if @nombres > 0;
    $iniciales .= uc(substr($nombres[1], 0, 1)) if @nombres > 1;

    # Buscar Avatar y Config
    my $avatar_url = '';
    my $uid = '';
    my $id_empresa = '';
    my $id_sucursal = '';
    my $roles_disponibles = '';
    eval {
        my $s = main::check_session();
        $uid = $s->{uid} if $s;
        $id_empresa = $s->{id_empresa} if $s;
        $id_sucursal = $s->{id_sucursal} if $s;
        $roles_disponibles = $s->{roles_disponibles} || ($s->{session} ? $s->{session}->param('roles_disponibles') : '') if $s;
    };
    
    my $id_usuario_num = '';
    if ($uid && open(my $fhu, '<:utf8', '../dat/usuarios.dat')) {
        while (<$fhu>) {
            chomp;
            my @u = split /!/;
            if (lc($u[2] // '') eq lc($uid) || ($u[0] eq $uid)) {
                $id_usuario_num = $u[0];
                my $r_raw = $u[5] // '';
                my $esp = $u[7] // '0';
                if ($r_raw =~ /Administrador/ && $esp ne '0' && $esp ne '' && $r_raw !~ /Medico/) {
                    $r_raw .= ',Medico';
                }
                $roles_disponibles = $r_raw if !$roles_disponibles;
                last;
            }
        }
        close $fhu;
    }
    
    my $nombre_org = 'OSPulso Clínicas';
    my $clue_suc = "ID : $id_sucursal";
    if ($id_empresa && open(my $fhn, '<:utf8', '../dat/negocios.dat')) {
        while (<$fhn>) {
            chomp;
            my @f = split /\|/;
            if ($f[0] eq $id_empresa) {
                $nombre_org = $f[1] || $nombre_org;
                my $clue_val = $f[18] // '';
                my $suc_val  = $id_sucursal || $f[0] || '';
                if (length($clue_val)) {
                    $clue_suc = "CLUE : $clue_val  ID : $suc_val";
                } else {
                    $clue_suc = "ID : $suc_val";
                }
                last;
            }
        }
        close $fhn;
    }
    if (($id_usuario_num || $uid) && open(my $fh, '<:encoding(UTF-8)', '../dat/perfiles.dat')) {
        my $header = <$fh>;
        while (<$fh>) {
            chomp;
            my @c = split /!/, $_, -1;
            if (($id_usuario_num && $c[1] eq $id_usuario_num) || ($c[1] && $c[1] eq $uid)) {
                $avatar_url = $c[6] // '';
                last;
            }
        }
        close $fh;
    }

    my $avatar_html = '';
    if ($avatar_url ne '') {
        my $src_url = ($avatar_url =~ /^\.\./) ? $avatar_url : "../$avatar_url";
        $avatar_html = qq{<img src="$src_url" alt="$usuario" style="width:100%; height:100%; object-fit:cover; border-radius:inherit;">};
    } else {
        $avatar_html = qq{<span class="avatar-initials">$iniciales</span>};
    }

    my $puede_buscar = 0;
    my $roles_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'roles.dat');
    if (-e $roles_file) {
        if (open(my $fh_r, '<:encoding(UTF-8)', $roles_file)) {
            while (<$fh_r>) {
                chomp;
                next if /^\s*(#|$)/;
                my @cols = split /\|/;
                if ($cols[0] eq $role) {
                    $puede_buscar = $cols[1] || 0;
                    last;
                }
            }
            close $fh_r;
        }
    }
    
    # Fecha y hora actual formateada (Formato 24 hrs)
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    my @dias = ('Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado');
    my @meses = ('Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre');
    my @meses_cortos = ('Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic');
    
    my $dia_nombre = $dias[$wday];
    my $mes_nombre = $meses[$mon];
    my $mes_corto  = $meses_cortos[$mon];
    my $hora_fmt   = sprintf("%02d:%02d", $hour, $min);
    
    my $fecha_hora_desktop = "$dia_nombre, $mday de $mes_nombre de $year • $hora_fmt hrs";
    my $fecha_hora_mobile  = "$mday $mes_corto $year • $hora_fmt hrs";

    my $search_html = '';
    my $search_html_mobile = '';
    if ($puede_buscar) {
        $search_html = qq{
            <!-- 1. Buscador Desktop con Fecha y Hora 24 hrs centrada debajo -->
            <div class="search-container flex-grow-1 mx-md-auto d-flex flex-column align-items-center" style="max-width: 550px;">
                <div class="position-relative w-100">
                    <input type="text" id="globalSearch" class="sdm-search-input search-pill" placeholder="Buscar expediente...">
                    <i class="bi bi-search search-icon"></i>
                </div>
                <div class="header-datetime-sub text-center mt-1">
                    <span class="header-datetime-text">
                        <i class="bi bi-calendar3 me-1 text-teal"></i>$fecha_hora_desktop
                    </span>
                </div>
            </div>};

        $search_html_mobile = qq{
            <div class="position-relative w-100 my-1">
                <input type="text" id="globalSearchMobile" class="sdm-search-input-mobile search-pill" placeholder="Buscar expediente...">
                <i class="bi bi-search search-icon-mobile"></i>
            </div>};
    } else {
        $search_html = qq{
            <!-- Fecha y Hora 24 hrs sin buscador Desktop -->
            <div class="search-container flex-grow-1 mx-md-auto d-flex flex-column align-items-center justify-content-center" style="max-width: 550px;">
                <div class="header-datetime-sub text-center py-1">
                    <span class="header-datetime-text">
                        <i class="bi bi-calendar3 me-1 text-teal"></i>$fecha_hora_desktop
                    </span>
                </div>
            </div>};
    }

    # 1. Control de cabeceras CGI (Protocolo 11.2)
    # Solo imprimimos el header HTTP si NO se solicita omitirlo
    binmode(STDOUT, ':encoding(UTF-8)');
    if (!$skip) {
        my $q = CGI->new;
        print $q->header(
            -type    => 'text/html',
            -charset => 'UTF-8',
            -expires => 'now',
            -'Cache-Control' => 'no-store, no-cache, must-revalidate, max-age=0',
            -'Pragma' => 'no-cache',
        );
    }

    # Leer configuración global del timeout
    my $global_timeout_mins = 30;
    my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
    if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
        while(<$cf>) {
            chomp;
            my @f = split(/\|/);
            if (defined $f[0] && $f[0] eq '0' && defined $f[1] && $f[1] eq 'GLOBAL_SESSION_TIMEOUT') {
                $global_timeout_mins = int($f[2]) if $f[2] =~ /^\d+$/;
                last;
            }
        }
        close($cf);
    }

    print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>$titulo | OSPulso Diamond</title>
    <script>window.OS_SESSION_TIMEOUT = $global_timeout_mins;</script>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="16x16" href="../favicon/favicon-16x16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="64x64" href="../favicon/favicon-64x64.png">
    <link rel="icon" type="image/png" sizes="128x128" href="../favicon/favicon-128x128.png">
    <link rel="icon" type="image/x-icon" href="../favicon/favicon.ico">
    <link rel="apple-touch-icon" sizes="180x180" href="../favicon/apple-touch-icon.png">
    <link rel="manifest" href="../favicon/site.webmanifest">

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700;900&family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">

    <!-- Libs Core -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css"/>
    <link rel="stylesheet" href="https://code.jquery.com/ui/1.13.2/themes/base/jquery-ui.css">
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
    
    <!-- OSPulso Design System -->
    <link rel="stylesheet" href="../css/ospulso_master.css">
    <link rel="stylesheet" href="../css/ospulso_master_v2.css">
    <link rel="stylesheet" href="../css/theme_acrilico.css">
    <link rel="stylesheet" href="../css/sdm_mobile_standards.css">
    <link rel="stylesheet" href="../css/sub_sidebar.css">
 
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://code.jquery.com/ui/1.13.2/jquery-ui.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <!-- SweetAlert2 UI Alerts -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
    <script src="../js/sub_sidebar.js"></script>

    <script>
    window.toggleSidebar = window.toggleSidebar || function() {
        var sidebar = document.getElementById("moduleSidebar");
        var overlay = document.getElementById("sidebarOverlay");
        if (sidebar) sidebar.classList.toggle("show");
        if (overlay) overlay.classList.toggle("show");
    };
    window.toggleDesktopSidebar = window.toggleDesktopSidebar || function() {
        var sidebar = document.getElementById("moduleSidebar");
        if (sidebar) sidebar.classList.toggle("compact");
    };

    \$(document).ready(function() {
        var \$searchInputs = \$("#globalSearch, #globalSearchMobile");
        if (\$searchInputs.length) {
            // Si estamos en pacientes.pl o agenda y existe tablaPacientes, usar filtro de DataTables
            if (\$('#tablaPacientes').length) {
                \$searchInputs.on('keyup', function() {
                    try {
                        var table = \$('#tablaPacientes').DataTable();
                        table.search(this.value).draw();
                    } catch(e) { console.error("DataTables no inicializado aún", e); }
                });
            } else if (typeof \$.ui !== 'undefined') {
                // Autocomplete estándar para el resto del sistema
                const acConfig = {
                    source: "../api/autocomplete_pacientes.pl",
                    minLength: 2,
                    select: function(e, ui) { 
                        if(ui.item.id) {
                            if (window.location.pathname.indexOf('estado_cuenta.pl') !== -1) {
                                window.location.href = "../views/estado_cuenta.pl?id=" + ui.item.id;
                            } else if (window.location.pathname.indexOf('finanzas.pl') !== -1) {
                                window.location.href = "../views/estado_cuenta.pl?id=" + ui.item.id;
                            } else {
                                window.location.href = "../views/render_expediente_clinico.pl?id=" + ui.item.id; 
                            }
                        }
                    }
                };
                \$searchInputs.autocomplete(acConfig);
            }
        }

        // 💎 Reglas de Responsividad Premium para DataTables (GUIA ESTILO SDM Punto 7.4)
        \$(document).on('init.dt', function(e, settings) {
            try {
                var api = new \$.fn.dataTable.Api(settings);
                var table = api.table().node();
                if (!table) return;

                // 1. Mapear encabezados a data-label para Card View responsivo
                var headers = [];
                \$(table).find('thead th').each(function() {
                    headers.push(\$(this).text().trim());
                });

                function applyDataLabels() {
                    \$(table).find('tbody tr').each(function() {
                        \$(this).find('td').each(function(index) {
                            if (headers[index]) {
                                \$(this).attr('data-label', headers[index]);
                            } else {
                                \$(this).attr('data-label', '');
                            }
                        });
                    });
                }
                
                applyDataLabels();
                api.on('draw', applyDataLabels);

                // 2. Transformar botones de exportación a iconos con tooltips en móvil
                if (typeof api.buttons === 'function') {
                    var container = api.buttons().container();
                    if (container && container.length) {
                        container.find('.btn, button').each(function() {
                            var \$btn = \$(this);
                            var text = \$btn.text().trim();
                            if (text && !\$btn.attr('title')) {
                                \$btn.attr('title', text);
                                \$btn.attr('data-bs-toggle', 'tooltip');
                                \$btn.attr('data-bs-placement', 'top');
                            }
                        });
                        
                        // Inicializar tooltips de Bootstrap
                        if (typeof bootstrap !== 'undefined' && bootstrap.Tooltip) {
                            var tooltipTriggerList = [].slice.call(container[0].querySelectorAll('[data-bs-toggle="tooltip"]'));
                            tooltipTriggerList.map(function (tooltipTriggerEl) {
                                return new bootstrap.Tooltip(tooltipTriggerEl);
                            });
                        }
                    }
                }
            } catch(err) {
                console.error("Error al aplicar responsividad en DataTable:", err);
            }
        });
    });

    function confirmLogout() {
        if (confirm("¿Está seguro de que desea cerrar la sesión actual?")) {
            window.location.href = "../auth/cerrar_sesion.pl";
        }
    }

    window.osPulsoSwitchRole = function(targetRole) {
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                title: 'Cambiando Perfil...',
                text: 'Alternando a ' + (targetRole === 'Medico' ? 'Modo Médico' : 'Modo Administrador'),
                allowOutsideClick: false,
                didOpen: () => { Swal.showLoading(); }
            });
        }
        const fd = new FormData();
        fd.append('nuevo_rol', targetRole);
        fetch('../api/switch_role_api.pl?nuevo_rol=' + encodeURIComponent(targetRole), {
            method: 'POST',
            body: fd,
            credentials: 'same-origin'
        })
        .then(function(r) { return r.json(); })
        .then(function(res) {
            if (res.ok) {
                window.location.href = res.redirect || window.location.href;
            } else {
                if (typeof Swal !== 'undefined') {
                    Swal.fire('Error', res.error || 'No se pudo cambiar el perfil.', 'error');
                } else {
                    alert(res.error || 'Error al cambiar de rol');
                }
            }
        })
        .catch(function(err) {
            console.error(err);
            if (typeof Swal !== 'undefined') {
                Swal.fire('Error', 'Falla de red al alternar de perfil.', 'error');
            } else {
                alert('Falla de red al alternar perfil');
            }
        });
    };
    </script>
</head>
<body>
HTML

    if ($show_nav) {
        my $role_label = uc($role);
        my $tiene_multirrol = ($roles_disponibles =~ /,/) ? 1 : 0;
        my $role_switcher_navbar = '';
        my $role_switcher_mobile = '';
        my $role_switcher_drawer = '';

        if ($tiene_multirrol) {
            if ($role eq 'Administrador Organizacion') {
                $role_switcher_navbar = qq{
            <!-- Role Switcher Pill (Navbar Desktop) -->
            <div class="role-switcher-container me-2 d-flex align-items-center">
                <button type="button" class="btn btn-sm btn-role-pill shadow-sm" onclick="osPulsoSwitchRole('Medico')" title="Cambiar a Modo Médico (Agenda y Consultas)">
                    <span class="badge-role-current text-primary"><i class="bi bi-shield-check me-1"></i>Admin</span>
                    <i class="bi bi-arrow-left-right text-muted opacity-75 mx-1" style="font-size: 0.68rem;"></i>
                    <span class="badge-role-target text-teal"><i class="bi bi-stethoscope me-1"></i>Modo Médico</span>
                </button>
            </div>};
                $role_switcher_mobile = qq{
                    <button type="button" class="btn btn-role-pill-mobile" onclick="osPulsoSwitchRole('Medico')" title="Cambiar a Modo Médico">
                        <i class="bi bi-shield-check text-primary"></i><i class="bi bi-arrow-left-right text-muted mx-1"></i><span class="text-teal">Med</span>
                    </button>};
                $role_switcher_drawer = qq{
                <a href="javascript:void(0)" onclick="osPulsoSwitchRole('Medico')" class="sidebar-nav-link d-flex align-items-center justify-content-between mb-2">
                    <div class="d-flex align-items-center gap-3">
                        <i class="bi bi-stethoscope fs-5 text-teal"></i>
                        <div class="text-start">
                            <span class="d-block text-teal fw-bold">Modo Médico</span>
                            <small class="text-muted d-block" style="font-size: 0.72rem; font-weight: normal;">Consultas, agenda y recetas</small>
                        </div>
                    </div>
                    <i class="bi bi-chevron-right text-muted opacity-50" style="font-size: 0.85rem;"></i>
                </a>};
            } else {
                $role_switcher_navbar = qq{
            <!-- Role Switcher Pill (Navbar Desktop) -->
            <div class="role-switcher-container me-2 d-flex align-items-center">
                <button type="button" class="btn btn-sm btn-role-pill shadow-sm" onclick="osPulsoSwitchRole('Administrador Organizacion')" title="Cambiar a Modo Administrador (Finanzas y Control)">
                    <span class="badge-role-current text-teal"><i class="bi bi-stethoscope me-1"></i>Médico</span>
                    <i class="bi bi-arrow-left-right text-muted opacity-75 mx-1" style="font-size: 0.68rem;"></i>
                    <span class="badge-role-target text-primary"><i class="bi bi-shield-check me-1"></i>Modo Admin</span>
                </button>
            </div>};
                $role_switcher_mobile = qq{
                    <button type="button" class="btn btn-role-pill-mobile" onclick="osPulsoSwitchRole('Administrador Organizacion')" title="Cambiar a Modo Admin">
                        <i class="bi bi-stethoscope text-teal"></i><i class="bi bi-arrow-left-right text-muted mx-1"></i><span class="text-primary">Admin</span>
                    </button>};
                $role_switcher_drawer = qq{
                <a href="javascript:void(0)" onclick="osPulsoSwitchRole('Administrador Organizacion')" class="sidebar-nav-link d-flex align-items-center justify-content-between mb-2">
                    <div class="d-flex align-items-center gap-3">
                        <i class="bi bi-shield-check fs-5 text-primary"></i>
                        <div class="text-start">
                            <span class="d-block text-navy fw-bold">Modo Admin</span>
                            <small class="text-muted d-block" style="font-size: 0.72rem; font-weight: normal;">Finanzas, caja y control</small>
                        </div>
                    </div>
                    <i class="bi bi-chevron-right text-muted opacity-50" style="font-size: 0.85rem;"></i>
                </a>};
            }
        }

        print <<HTML;
    <nav class="navbar sdm-navbar glass-navbar p-1 p-md-2 sticky-top flex-column align-items-stretch">
        <!-- 1. CONTENEDOR DESKTOP (d-none d-md-flex) -->
        <div class="container-fluid px-lg-4 d-none d-md-flex align-items-start justify-content-between flex-nowrap w-100 gap-3">
            <div class="d-flex align-items-center gap-4 me-auto">
                <a class="navbar-brand d-flex align-items-center justify-content-start m-0 text-decoration-none" href="inicial.pl" title="Inicio">
                    <svg width="125" height="38" viewBox="0 0 160 45" fill="none" xmlns="http://www.w3.org/2000/svg" class="sdm-brand-logo flex-shrink-0">
                        <text x="2" y="32" font-family="'Plus Jakarta Sans', sans-serif" font-weight="800" font-size="32" letter-spacing="-1">
                            <tspan fill="#0A2A66">Os</tspan><tspan fill="#00C4C4">Pulso</tspan>
                        </text>
                        <path class="ekg-line-anim" d="M108 32 H112 L118 18 L124 38 L130 6 L136 28 L140 32 H156" stroke="#00C4C4" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none" />
                    </svg>
                    <span class="d-none d-lg-inline-flex flex-column justify-content-center border-start ps-3 ms-2 text-secondary py-0" style="line-height: 1.25;">
                        <strong class="text-dark fw-bold text-truncate" style="font-family: 'Plus Jakarta Sans', sans-serif; font-size: 0.78rem; letter-spacing: 0.3px; max-width: 350px;" title="$nombre_org">$nombre_org</strong>
                        <span class="text-secondary fw-semibold text-truncate" style="font-family: 'Plus Jakarta Sans', sans-serif; font-size: 0.68rem; letter-spacing: 0.5px; margin-top: 2px; max-width: 350px;" title="$clue_suc">$clue_suc</span>
                    </span>
                </a>
            </div>

$search_html
$role_switcher_navbar
            <div class="profile-trigger-container">
                <button class="btn user-dropdown border-0 d-flex align-items-center gap-2 py-1 px-2" type="button" data-bs-toggle="offcanvas" data-bs-target="#sdmSidebar">
                    <div class="text-end me-1 d-none d-sm-block profile-info-text">
                        <span class="d-block plus-jakarta fw-bold" style="font-size:0.75rem; line-height:1">$usuario</span>
                        <span class="d-block text-secondary fw-bold" style="font-size:0.55rem; letter-spacing:0.5px">$role_label</span>
                    </div>
                    <div class="avatar-diamond shadow-sm" style="width: 38px; height: 38px; font-size: 0.9rem;">
                        $avatar_html
                    </div>
                </button>
            </div>
        </div>

        <!-- 2. CONTENEDOR EXCLUSIVO MÓVIL (<768px: d-flex d-md-none) -->
        <div class="d-flex d-md-none flex-column w-100 px-1 py-0 gap-1">
            <!-- Fila 1: Botón Hamburguesa + Logo Mini Izq | Role Switcher + Avatar Der -->
            <div class="d-flex align-items-center justify-content-between w-100">
                <div class="d-flex align-items-center gap-1">
                    <button class="btn btn-menu-toggle-mobile" onclick="toggleSidebar()" aria-label="Abrir menú" type="button">
                        <i class="bi bi-list"></i>
                    </button>
                    <a href="inicial.pl" class="text-decoration-none d-flex align-items-center ms-1" title="Inicio">
                        <span class="header-mobile-logo">Os<span class="text-teal">Pulso</span></span>
                    </a>
                </div>
                <div class="d-flex align-items-center gap-1">
                    $role_switcher_mobile
                    <button class="btn p-0 border-0 ms-1" type="button" data-bs-toggle="offcanvas" data-bs-target="#sdmSidebar" aria-label="Menú Usuario">
                        <div class="avatar-diamond avatar-diamond-mobile shadow-sm">
                            $avatar_html
                        </div>
                    </button>
                </div>
            </div>
            <!-- Fila 2: Buscador y Fecha en una sola línea -->
            <div class="d-flex flex-column align-items-center w-100 px-0 pt-0 pb-1">
                $search_html_mobile
                <div class="header-datetime-mobile text-center">
                    <span class="header-datetime-text-mobile">
                        <i class="bi bi-calendar3 me-1 text-teal"></i>$fecha_hora_mobile
                    </span>
                </div>
            </div>
        </div>

        <!-- Navegación Breadcrumb debajo del logo/navbar principal (Desktop) -->
        <div class="container-fluid px-lg-4 mt-1 d-none d-md-block">
            <nav aria-label="breadcrumb">
                <ol class="breadcrumb m-0 plus-jakarta fw-semibold" style="font-size: 0.75rem;">
                    <li class="breadcrumb-item"><a href="inicial.pl" class="text-decoration-none text-muted"><i class="bi bi-house-door-fill me-1"></i>Inicio</a></li>
                    <li class="breadcrumb-item active text-primary" aria-current="page">$titulo</li>
                </ol>
            </nav>
        </div>
    </nav>

    <!-- User Menu Offcanvas Premium (Floating Panel Homologado con index.html) -->
    <div class="offcanvas offcanvas-end shadow-lg mobile-sidebar" tabindex="-1" id="sdmSidebar" aria-labelledby="sdmSidebarLabel">
        <!-- Header con botón cerrar estándar de index.html -->
        <div class="sidebar-header d-flex justify-content-between align-items-center mb-3">
            <span class="text-uppercase fw-bold text-muted" style="letter-spacing: 1px; font-size: 0.72rem;">Men&uacute; de Usuario</span>
            <button type="button" class="btn-close-sidebar" data-bs-dismiss="offcanvas" aria-label="Cerrar menú">
                <i class="bi bi-x-lg"></i>
            </button>
        </div>
        
        <div class="sidebar-body d-flex flex-column flex-grow-1 p-0">
            <!-- User Info Box con Avatar Diamond -->
            <div class="user-info-box d-flex align-items-center mb-4 p-3 rounded-4">
                <div class="avatar-diamond shadow-sm flex-shrink-0" style="width: 50px; height: 50px; font-size: 1.3rem;">
                    $avatar_html
                </div>
                <div class="ms-3 overflow-hidden">
                    <span class="d-block fw-bold text-truncate text-navy" style="font-size: 1.05rem; line-height: 1.2;" title="$usuario">$usuario</span>
                    <span class="d-block mt-1 text-truncate fw-bold text-teal" style="font-size: 0.72rem; letter-spacing: 0.5px;" title="$role_label">$role_label</span>
                </div>
            </div>

            <!-- Options con clases .sidebar-nav-link de index.html -->
            <div class="nav-links-container flex-grow-1">
$role_switcher_drawer
                <a href="../views/perfil.pl" class="sidebar-nav-link d-flex align-items-center justify-content-between">
                    <div class="d-flex align-items-center gap-3">
                        <i class="bi bi-person-fill fs-5 text-primary"></i>
                        <span>Editar Perfil</span>
                    </div>
                    <i class="bi bi-chevron-right text-muted opacity-50" style="font-size: 0.85rem;"></i>
                </a>
            </div>

            <!-- Botón Cerrar Sesión con clase .btn-solicitar-cita-mobile de index.html -->
            <div class="sidebar-bottom mt-3">
                <a href="../auth/cerrar_sesion.pl" data-no-spa="true" class="btn-solicitar-cita-mobile" style="background: #dc3545 !important;">
                    <i class="bi bi-box-arrow-right fs-5"></i>
                    <span>Cerrar Sesi&oacute;n</span>
                </a>
            </div>
        </div>
    </div>
HTML
    }

    print <<HTML;
    <main class="container-fluid px-lg-4 pt-1 pb-4">
HTML
}

sub render_acceso_denegado {
    my %args = @_;
    my $q             = $args{q} || CGI->new;
    my $usuario       = $args{usuario} || 'Usuario';
    my $role          = $args{role} || 'Invitado';
    my $mensaje       = $args{mensaje} || 'No cuentas con los permisos necesarios para acceder a este módulo.';
    my $rol_requerido = $args{rol_requerido} || '';
    my $titulo        = $args{titulo} || 'Acceso Denegado';

    print $q->header(
        -status => '403 Forbidden',
        -type => 'text/html',
        -charset => 'UTF-8',
        -cache_control => 'no-store, no-cache, must-revalidate, max-age=0',
        -pragma => 'no-cache'
    );

    render_header(
        usuario     => $usuario,
        role        => $role,
        titulo      => $titulo,
        skip_header => 1
    );

    require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
    utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => '');

    my $badge_rol_req = '';
    if ($rol_requerido) {
        $badge_rol_req = qq{<div class="mt-3"><span class="small text-muted fw-bold">Rol requerido:</span> <span class="badge bg-danger bg-opacity-10 text-danger border border-danger border-opacity-25 px-3 py-2 ms-1 rounded-pill"><i class="bi bi-shield-lock-fill me-1"></i>$rol_requerido</span></div>};
    }

    print <<HTML;
        <link rel="stylesheet" href="../css/sdm_mobile_standards.css?v=$^T">
        <!-- TOPBAR INSTITUCIONAL -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-shield-slash-fill me-2 text-warning"></i>Acceso Restringido</h2>
                    <p class="text-white-50 small mb-0 mt-1">Control de Acceso y Gobernanza RBAC</p>
                </div>
            </div>
        </header>

        <div class="container-fluid px-4 pb-5 container-mobile-flush">
            <div class="row justify-content-center">
                <div class="col-12 col-md-8 col-lg-6">
                    <div class="card card-medentia-aura border-0 shadow-lg rounded-4 p-4 text-center my-4">
                        <div class="card-body p-4 d-flex flex-column align-items-center">
                            
                            <div class="d-flex align-items-center justify-content-center mb-4" style="width: 90px; height: 90px; border-radius: 50%; background: rgba(220, 53, 69, 0.1); border: 2px solid rgba(220, 53, 69, 0.25); color: #dc3545;">
                                <i class="bi bi-shield-lock-fill display-4"></i>
                            </div>

                            <h3 class="fw-black text-dark mb-2">Acceso Denegado</h3>
                            <p class="text-muted fs-6 mb-3">$mensaje</p>

                            <div class="d-flex align-items-center justify-content-center flex-wrap gap-2 mb-3">
                                <span class="small text-muted fw-bold">Tu Rol Actual:</span>
                                <span class="badge bg-secondary px-3 py-2 rounded-pill">$role</span>
                            </div>

                            $badge_rol_req

                            <div class="alert alert-warning border-0 rounded-4 text-start small mt-4 mb-4 p-3 shadow-sm w-100" style="background-color: #fff8e6; border-left: 4px solid #f59e0b !important;">
                                <div class="d-flex align-items-start gap-2">
                                    <i class="bi bi-exclamation-triangle-fill text-warning fs-5 flex-shrink-0"></i>
                                    <div>
                                        <strong class="text-dark d-block">¿Necesitas acceso a esta sección?</strong>
                                        Si consideras que deberías tener acceso a este módulo, solicita a un Administrador de la Organización que actualice tus permisos en el sistema.
                                    </div>
                                </div>
                            </div>

                            <div class="d-flex flex-column flex-sm-row justify-content-center gap-3 w-100 mt-2">
                                <button type="button" onclick="window.history.back()" class="btn btn-sdm-primary rounded-pill px-4 py-2 fw-bold shadow-sm">
                                    <i class="bi bi-arrow-left me-2"></i>Regresar a Página Anterior
                                </button>
                                <a href="../views/pacientes.pl" class="btn btn-outline-secondary rounded-pill px-4 py-2 fw-bold shadow-sm">
                                    <i class="bi bi-house-door-fill me-2"></i>Ir al Inicio
                                </a>
                            </div>

                        </div>
                    </div>
                </div>
            </div>
        </div>
HTML

    utils::sub_sidebar::render_sidebar_footer();
    if (defined &render_bottom_nav) {
        render_bottom_nav('');
    }
    print $q->end_html;
}

1;
