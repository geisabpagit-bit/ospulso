#!/usr/bin/perl
# --- Versión Suprema v3.1.6.3 (Header Fix) ---
use strict;
use warnings;
use utf8;
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
    if (!$skip) {
        my $q = CGI->new;
        print $q->header(-type => 'text/html', -charset => 'UTF-8');
    }

    print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>$titulo | OSPulso Diamond</title>

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
        if ($role ne 'Paciente') {
            $hamburger_btn = <<'HAM';
            <!-- Hamburger Menu Toggle (Solo Teléfonos Móviles) -->
            <button class="btn btn-menu-toggle-inline me-2" onclick="toggleSidebar()" aria-label="Abrir menú" type="button">
                <i class="bi bi-list"></i>
            </button>
HAM
        }

        print <<HTML;
    <nav class="navbar sdm-navbar glass-navbar p-2 sticky-top flex-column align-items-stretch">
        <div class="container-fluid px-lg-4 d-flex align-items-center justify-content-between flex-nowrap w-100">
$hamburger_btn
            <!-- Navigation: Solo Desktop -->
            <div class="d-none d-md-flex align-items-center gap-4 me-auto">
                <a class="navbar-brand d-flex align-items-center justify-content-center m-0 text-decoration-none" href="inicial.pl" title="Inicio" style="margin-bottom: -10px;">
                    <svg class="ospulso-logo-svg" viewBox="0 0 165 50" xmlns="http://www.w3.org/2000/svg" style="height: 55px; width: auto; overflow: visible;">
                        <text x="0" y="32" font-family="'Outfit', sans-serif" font-weight="900" font-size="28" letter-spacing="0.5">
                            <tspan fill="#0A2A66">Os</tspan><tspan fill="#00C4C4">Pulso</tspan>
                        </text>
                        <path class="ekg-line-anim" d="M0 40 H115 L121 22 L128 42 L134 6 L141 34 L146 40 H160" stroke="#00C4C4" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none" />
                    </svg>
                    <span class="d-none d-lg-inline-block text-secondary small border-start ps-3 ms-2 align-self-center py-1 fw-medium" style="font-size: 0.72rem; letter-spacing: 0.5px;">Sistema Operativo para Clínicas Modernas</span>
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
                    <div class="avatar-diamond d-flex align-items-center justify-content-center shadow-sm" style="width: 38px; height: 38px; font-size: 0.9rem; border-width: 2px;">
                        $iniciales
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
                <div class="avatar-diamond d-flex align-items-center justify-content-center flex-shrink-0" style="width: 50px; height: 50px; font-size: 1.3rem; border: 2px solid teal; color: teal; background: rgba(32, 201, 151, 0.1);">
                    $iniciales
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
1;
