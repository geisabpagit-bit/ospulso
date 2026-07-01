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

    <!-- Libs Core -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css"/>
    <link rel="stylesheet" href="https://code.jquery.com/ui/1.13.2/themes/base/jquery-ui.css">
    <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
    
    <!-- OSPulso Design System -->
    <link rel="stylesheet" href="../css/ospulso_master.css">

    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://code.jquery.com/ui/1.13.2/jquery-ui.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <!-- SweetAlert2 UI Alerts -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>



    <script>
    \$(document).ready(function() {
        if (typeof \$.ui !== 'undefined') {
            const acConfig = {
                source: "../api/autocomplete_pacientes.pl",
                minLength: 2,
                select: function(e, ui) { 
                    if(ui.item.id) window.location.href = "../views/render_expediente_clinico.pl?id=" + ui.item.id; 
                }
            };
            if (\$("#globalSearch").length) \$("#globalSearch").autocomplete(acConfig);
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
    <nav class="navbar sdm-navbar p-2 sticky-top">
        <div class="container-fluid px-lg-4 d-flex align-items-center justify-content-between flex-nowrap">
            
            <!-- Navigation: Solo Desktop -->
            <div class="d-none d-md-flex align-items-center gap-4 me-auto">
                <a class="navbar-brand d-flex flex-column align-items-center justify-content-center m-0 text-decoration-none" href="../index.html" title="Inicio" style="font-family: 'Outfit', sans-serif; font-weight: 800; font-size: 2.2rem; letter-spacing: -1.5px; line-height: 0.95;">
                    <div class="d-flex align-items-center justify-content-center" style="text-shadow: 0 3px 6px rgba(10, 42, 102, 0.22), 0 0 12px rgba(16, 185, 129, 0.4);">
                        <span style="color: var(--md-blue-deep);">Os</span><span style="color: var(--md-green-medical);">Pulso</span>
                    </div>
                    <svg class="ekg-pulse animate__animated animate__pulse animate__infinite animate__slower" viewBox="0 0 100 20" fill="none" xmlns="http://www.w3.org/2000/svg" style="width: 120px; height: 12px; margin-top: -2px;">
                        <path d="M0 10H30L35 3L42 17L48 1L53 13L57 10H100" stroke="var(--md-green-medical)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" style="filter: drop-shadow(0 0 2px rgba(16, 185, 129, 0.6));" />
                    </svg>
                </a>
                
                <a href="pacientes.pl" class="d-flex align-items-center nav-link-item text-decoration-none">
                    <i class="bi bi-people me-2"></i>Pacientes
                </a>
                
                <a href="agenda_main.pl" class="d-flex align-items-center nav-link-item text-decoration-none">
                    <i class="bi bi-calendar3 me-2"></i>Agenda
                </a>
            </div>

            <!-- 1. Buscador (Alineado a la izquierda en móvil) -->
            <div class="search-container flex-grow-1 mx-md-auto" style="max-width: 550px;">
                <div class="position-relative">
                    <input type="text" id="globalSearch" class="sdm-search-input" placeholder="Buscar expediente...">
                    <i class="bi bi-search search-icon"></i>
                </div>
            </div>

            <!-- 2. Perfil (Alineado a la derecha en móvil) -->
            <div class="profile-trigger-container">
                <button class="btn user-dropdown border-0 d-flex align-items-center gap-2 py-1 px-2" type="button" data-bs-toggle="offcanvas" data-bs-target="#sdmSidebar">
                    <div class="text-end me-1 d-none d-sm-block profile-info-text">
                        <span class="d-block plus-jakarta fw-bold" style="font-size:0.75rem; line-height:1">$usuario</span>
                        <span class="d-block text-secondary fw-bold" style="font-size:0.55rem; letter-spacing:0.5px">$role_label</span>
                    </div>
                    <div class="ospulso-avatar shadow-sm">
                        <i class="bi bi-person-fill"></i>
                    </div>
                </button>
            </div>
        </div>
    </nav>

    <!-- Sidebar Offcanvas Premium v3 (Aura Glass Design) -->
    <div class="offcanvas offcanvas-end aura-sidebar-menu" tabindex="-1" id="sdmSidebar" aria-labelledby="sdmSidebarLabel">
        <div class="p-4 text-end">
            <button type="button" class="btn-close shadow-none" data-bs-dismiss="offcanvas" aria-label="Close"></button>
        </div>
        
        <div class="offcanvas-body p-4 pt-0 d-flex flex-column">
            <div class="nav flex-column gap-2">
                
                <!-- Perfil Card Bento -->
                <div class="user-aura-card mb-4">
                    <div class="d-flex align-items-center gap-3">
                        <div class="ospulso-avatar ospulso-avatar-lg">
                            <i class="bi bi-person-fill"></i>
                        </div>
                        <div class="text-truncate">
                            <span class="d-block fw-bold text-dark text-truncate" style="font-size: 1rem;">$usuario</span>
                            <span class="d-block text-primary small text-uppercase fw-bold" style="letter-spacing: 1px; font-size: 0.6rem;">$role_label</span>
                        </div>
                    </div>
                </div>

                <a href="../views/perfil.pl" class="aura-nav-link">
                    <i class="bi bi-person-gear"></i>
                    <span>Editar Perfil</span>
                </a>

                <div class="my-2"><hr class="border-primary opacity-10 m-0"></div>

                <a href="javascript:void(0)" onclick="confirmLogout()" class="aura-nav-link text-danger">
                    <i class="bi bi-power"></i>
                    <span>Cerrar Sesi&oacute;n</span>
                </a>
            </div>
        </div>
    </div>
HTML
    }

    print <<HTML;
    <main class="container-fluid px-lg-4 py-4">
HTML
}
1;
