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
        print <<HTML;
    <nav class="navbar sdm-navbar glass-navbar p-2 sticky-top flex-column align-items-stretch">
        <div class="container-fluid px-lg-4 d-flex align-items-center justify-content-between flex-nowrap w-100">
            
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

    <!-- Sidebar Offcanvas Premium v3 (Diamond Style) -->
    <div class="offcanvas offcanvas-end" tabindex="-1" id="sdmSidebar" aria-labelledby="sdmSidebarLabel" style="width: 280px; background: #ffffff; z-index: 5000;">
        <div class="p-4 text-end pb-0">
            <button type="button" class="btn-close shadow-none" data-bs-dismiss="offcanvas" aria-label="Close"></button>
        </div>
        
        <div class="offcanvas-body p-4 pt-3 d-flex flex-column">
            <div class="nav flex-column gap-2 h-100">
                
                <!-- Perfil Card Bento -->
                <div class="sidebar-brand mb-4 px-2">
                    <div class="avatar-diamond d-flex align-items-center justify-content-center mb-3" style="width: 55px; height: 55px; font-size: 1.5rem; border-width: 2px; margin: 0 auto;">$iniciales</div>
                    <div class="text-center">
                        <span class="sidebar-text d-block fw-bold" style="font-size: 1.1rem; color: #0A2A66;">$usuario</span>
                        <span class="d-block text-primary small text-uppercase fw-bold mt-1" style="letter-spacing: 1px; font-size: 0.65rem;">$role_label</span>
                    </div>
                </div>

                <div class="sidebar-menu flex-grow-1 px-2 mt-2">
                    <!-- Navegación General (Solo móvil) -->
                    <div class="d-md-none mb-3">
                        <a href="pacientes.pl" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                            <span class="material-icons me-2" style="font-size:1.2rem; color: var(--icon-purple, #6f42c1)">groups</span> <span class="sidebar-text">Pacientes</span>
                        </a>
                        <a href="agenda_main.pl" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                            <span class="material-icons me-2" style="font-size:1.2rem; color: var(--calendar-event, #0ea5e9)">calendar_month</span> <span class="sidebar-text">Agenda</span>
                        </a>
                        <hr class="border-primary opacity-10 my-3">
                    </div>

                    <a href="../views/perfil.pl" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                        <span class="material-icons me-2" style="font-size:1.2rem; color: var(--primary-blue, #0d6efd)">person</span> <span class="sidebar-text">Editar Perfil</span>
                    </a>
                </div>

                <div class="mt-auto sidebar-footer">
                    <a href="javascript:void(0)" onclick="confirmLogout()" class="btn btn-danger w-100 rounded-pill fw-bold d-flex justify-content-center align-items-center"><i class="bi bi-box-arrow-right me-2"></i><span class="sidebar-text">Cerrar Sesión</span></a>
                </div>
            </div>
        </div>
    </div>
HTML
    }

    print <<HTML;
    <main class="container-fluid px-lg-4 pt-1 pb-4">
HTML
}
1;
