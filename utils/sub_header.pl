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
    eval {
        my $s = main::check_session();
        $uid = $s->{uid} if $s;
        $id_empresa = $s->{id_empresa} if $s;
        $id_sucursal = $s->{id_sucursal} if $s;
    };
    
    my $nombre_org = 'OSPulso Clínicas';
    my $clue_suc = "Sucursal $id_sucursal";
    if ($id_empresa && open(my $fhn, '<:utf8', '../dat/negocios.dat')) {
        while (<$fhn>) {
            chomp;
            my @f = split /\|/;
            if ($f[0] eq $id_empresa) {
                $nombre_org = $f[1] || $nombre_org;
                my $clue = $f[18] || '';
                $clue_suc = $clue ? "$clue - $id_sucursal" : "Sucursal $id_sucursal";
                last;
            }
        }
        close $fhn;
    }
    if ($uid && open(my $fh, '<:encoding(UTF-8)', '../dat/perfiles.dat')) {
        my $header = <$fh>;
        while (<$fh>) {
            chomp;
            my @c = split /!/, $_, -1;
            if ($c[1] && $c[1] eq $uid) {
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
    
    my $search_html = '';
    if ($puede_buscar) {
        $search_html = <<'SEARCH_HTML';
            <!-- 1. Buscador (Alineado a la izquierda en móvil) -->
            <div class="search-container flex-grow-1 mx-md-auto" style="max-width: 550px;">
                <div class="position-relative">
                    <input type="text" id="globalSearch" class="sdm-search-input search-pill" placeholder="Buscar expediente...">
                    <i class="bi bi-search search-icon"></i>
                </div>
            </div>
SEARCH_HTML
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
 
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://code.jquery.com/ui/1.13.2/jquery-ui.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <!-- SweetAlert2 UI Alerts -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>



    <script>
    \$(document).ready(function() {
        if (\$("#globalSearch").length) {
            // Si estamos en pacientes.pl o agenda y existe tablaPacientes, usar filtro de DataTables
            if (\$('#tablaPacientes').length) {
                \$("#globalSearch").on('keyup', function() {
                    try {
                        var table = \$('#tablaPacientes').DataTable();
                        table.search(this.value).draw();
                    } catch(e) { console.error("DataTables no inicializado aún", e); }
                });
            } else if (typeof \$.ui !== 'undefined') {
                // Autocomplete estándar para el resto del sistema
                console.log("Inicializando autocomplete para #globalSearch");
                const acConfig = {
                    source: "../api/autocomplete_pacientes.pl",
                    minLength: 2,
                    select: function(e, ui) { 
                        console.log("Autocomplete seleccionado:", ui.item);
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
                \$("#globalSearch").autocomplete(acConfig);
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
    </script>
</head>
<body>
HTML

    if ($show_nav) {
        my $role_label = uc($role);
        my $hamburger_btn = '';
        $hamburger_btn = <<'HAM';
        <!-- Hamburger Menu Toggle (Solo Teléfonos Móviles) -->
        <button class="btn btn-menu-toggle-inline me-2 d-lg-none" onclick="toggleSidebar()" aria-label="Abrir menú" type="button">
            <i class="bi bi-list"></i>
        </button>
HAM

        print <<HTML;
    <nav class="navbar sdm-navbar glass-navbar p-2 sticky-top flex-column align-items-stretch">
        <div class="container-fluid px-lg-4 d-flex align-items-center justify-content-between flex-nowrap w-100">
$hamburger_btn
            <!-- Navigation: Solo Desktop -->
            <div class="d-none d-md-flex align-items-center gap-4 me-auto">
                <a class="navbar-brand d-flex align-items-center justify-content-center m-0 text-decoration-none" href="inicial.pl" title="Inicio" style="margin-bottom: -10px;">
                    <svg width="105" height="40" viewBox="0 0 160 50" fill="none" xmlns="http://www.w3.org/2000/svg" class="ms-1 sdm-brand-logo">
                        <text x="5" y="38" font-family="'Plus Jakarta Sans', sans-serif" font-weight="800" font-size="34" letter-spacing="-1">
                            <tspan fill="#0A2A66">Os</tspan><tspan fill="#00C4C4">Pulso</tspan>
                        </text>
                        <path class="ekg-line-anim" d="M0 40 H115 L121 22 L128 42 L134 6 L141 34 L146 40 H160" stroke="#00C4C4" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none" />
                    </svg>
                    <span class="d-none d-lg-inline-block text-secondary small border-start ps-3 ms-2 align-self-center py-1 fw-medium d-flex flex-column justify-content-center" style="font-size: 0.72rem; letter-spacing: 0.5px; line-height: 1.2;">
                        <strong class="text-dark">$nombre_org</strong>
                        <span>$clue_suc</span>
                    </span>
                </a>

            </div>

$search_html
            <!-- 2. Perfil (Alineado a la derecha en móvil) -->
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
        <!-- Navegación Breadcrumb debajo del logo/navbar principal -->
        <div class="container-fluid px-lg-4 mt-1 d-none d-md-block">
            <nav aria-label="breadcrumb">
                <ol class="breadcrumb m-0 plus-jakarta fw-semibold" style="font-size: 0.75rem;">
                    <li class="breadcrumb-item"><a href="inicial.pl" class="text-decoration-none text-muted"><i class="bi bi-house-door-fill me-1"></i>Inicio</a></li>
                    <li class="breadcrumb-item active text-primary" aria-current="page">$titulo</li>
                </ol>
            </nav>
        </div>
    </nav>

    <!-- User Menu Offcanvas Premium (Floating Panel) -->
    <div class="offcanvas offcanvas-end m-3 shadow-lg glass-user-menu" tabindex="-1" id="sdmSidebar" aria-labelledby="sdmSidebarLabel">
        <!-- Barra superior Teal Accent -->
        <div class="teal-accent-bar"></div>

        <div class="d-flex justify-content-between align-items-center px-4 pt-4 pb-2">
            <h6 class="mb-0 fw-bold text-muted text-uppercase" style="letter-spacing: 1px; font-size: 0.75rem;">Men&uacute; de Usuario</h6>
            <button type="button" class="btn-close shadow-none" data-bs-dismiss="offcanvas" aria-label="Close" style="font-size: 0.8rem; opacity: 0.6;"></button>
        </div>
        
        <div class="offcanvas-body px-4 pb-4 pt-2">
            <!-- User Info Box -->
            <div class="user-info-box d-flex align-items-center mb-4 p-3 rounded-4">
                <div class="avatar-diamond shadow-sm flex-shrink-0" style="width: 50px; height: 50px; font-size: 1.3rem;">
                    $avatar_html
                </div>
                <div class="ms-3 overflow-hidden">
                    <span class="d-block fw-bold text-truncate text-dark" style="font-size: 1.1rem; line-height: 1.2;" title="$usuario">$usuario</span>
                    <span class="d-block mt-1 text-truncate fw-semibold text-teal" style="font-size: 0.75rem; letter-spacing: 0.5px;" title="$role_label">$role_label</span>
                </div>
            </div>

            <!-- Options -->
            <div class="d-flex flex-column gap-2">
                <a href="../views/perfil.pl" class="btn user-menu-option d-flex align-items-center px-3 py-3 rounded-4 text-decoration-none transition-all">
                    <div class="option-icon bg-primary-subtle text-primary me-3">
                        <i class="bi bi-person-fill fs-5"></i>
                    </div>
                    <span class="fw-bold" style="font-size: 0.95rem; color: #495057;">Editar Perfil</span>
                    <i class="bi bi-chevron-right ms-auto text-muted opacity-50" style="font-size: 0.8rem;"></i>
                </a>

                <a href="../auth/cerrar_sesion.pl" data-no-spa="true" class="btn user-menu-option-danger d-flex align-items-center px-3 py-3 rounded-4 text-decoration-none transition-all">
                    <div class="option-icon bg-danger-subtle text-danger me-3">
                        <i class="bi bi-box-arrow-right fs-5"></i>
                    </div>
                    <span class="fw-bold text-danger" style="font-size: 0.95rem;">Cerrar Sesi&oacute;n</span>
                </a>
            </div>
        </div>
    </div>

    <style>
        /* Glassmorphism Premium User Menu */
        .glass-user-menu {
            width: 340px !important;
            height: max-content !important;
            max-height: 95vh;
            border-radius: 24px !important;
            border: 1px solid rgba(32, 201, 151, 0.3) !important;
            background: rgba(255, 255, 255, 0.85) !important;
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1), 0 0 0 1px rgba(255,255,255,0.5) inset !important;
            overflow: hidden;
            z-index: 5000;
        }
        
        .teal-accent-bar {
            height: 6px;
            background: linear-gradient(90deg, #20c997, #0dcaf0);
            width: 100%;
        }

        .user-info-box {
            background: rgba(255, 255, 255, 0.6);
            border: 1px solid rgba(255, 255, 255, 0.8);
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.03);
        }
        
        .text-teal {
            color: #20c997 !important;
        }

        .option-icon {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 38px;
            height: 38px;
            border-radius: 50%;
        }

        .user-menu-option {
            background: rgba(255, 255, 255, 0.5);
            border: 1px solid transparent;
            transition: all 0.2s ease-in-out;
        }
        
        .user-menu-option:hover {
            background: #ffffff;
            border-color: rgba(13, 110, 253, 0.2);
            box-shadow: 0 4px 12px rgba(13, 110, 253, 0.08);
            transform: translateY(-2px);
        }

        .user-menu-option-danger {
            background: rgba(220, 53, 69, 0.03);
            border: 1px solid rgba(220, 53, 69, 0.1);
            transition: all 0.2s ease-in-out;
        }

        .user-menu-option-danger:hover {
            background: rgba(220, 53, 69, 0.08);
            border-color: rgba(220, 53, 69, 0.2);
            box-shadow: 0 4px 12px rgba(220, 53, 69, 0.08);
            transform: translateY(-2px);
        }

        /* Responsive max-width para pantallas pequeñas */
        \@media (max-width: 576px) {
            .glass-user-menu {
                width: auto !important;
                left: 15px !important;
                right: 15px !important;
            }
        }
    </style>
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
