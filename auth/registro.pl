#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;

# 1. Header First
my $q = CGI->new;
print $q->header(-type => 'text/html', -charset => 'UTF-8');

use JSON::PP;
use FindBin;
use File::Spec;
use CGI::Carp qw(fatalsToBrowser);

# 3. Forzar UTF-8 en Salida (Protocolo 11.2)
binmode(STDOUT, ":utf8");
binmode(STDIN,  ":utf8");

print <<'HTML';
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MedentIA | Registro Diamond Edition</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../css/medentia_master.css" rel="stylesheet">
    <style>
        /* Ajustes específicos para el Registro Diamond */
        .registration-container {
            max-width: 480px;
            width: 100%;
            margin: 0 auto;
        }
        @media (max-width: 576px) {
            .registration-container {
                max-width: 100%;
                padding: 0 10px !important;
            }
            .login-card {
                border-radius: 1.5rem !important;
            }
            main {
                padding-left: 5px !important;
                padding-right: 5px !important;
                margin-top: 5rem !important;
            }
        }
        .form-control:focus {
            border-color: var(--md-green-medical);
            box-shadow: 0 0 0 0.25rem rgba(0, 184, 148, 0.1);
        }
    </style>
</head>
<body class="d-flex flex-column min-vh-100">

    <!-- HEADER -->
    <header class="navbar navbar-expand-lg">
        <div class="logo">
            <img src="../img/logo_medentia.png" alt="MedentIA Logo" style="height: 38px;" onerror="this.onerror=null; this.style.display='none';" />
            <span>MedentIA</span>
        </div>
        <nav class="menu d-none d-lg-flex">
            <a href="../index.html#inicio">Inicio</a>
            <a href="../index.html#caracteristicas">Características</a>
            <a href="../index.html#testimonios">Testimonios</a>
        </nav>
        <div class="acciones d-none d-lg-flex">
            <a href="../index.html#login" class="btn-outline">Iniciar Sesión</a>
            <a href="registro.pl" class="btn-primary">Regístrate</a>
        </div>
        <!-- Mobile Toggle -->
        <button class="d-lg-none btn-mobile-toggle" type="button" id="openMobileMenu">
            <i class="bi bi-list fs-3"></i>
        </button>
    </header>

    <!-- Mobile Sidebar Menu -->
    <div class="mobile-sidebar" id="mobileSidebar">
        <div class="sidebar-header">
            <button class="btn-close-sidebar" id="closeMobileMenu">
                <i class="bi bi-x-lg"></i>
            </button>
        </div>
        <div class="sidebar-body">
            <div class="nav-links-container">
                <a href="../index.html#inicio" class="sidebar-nav-link active">INICIO</a>
                <a href="../index.html#caracteristicas" class="sidebar-nav-link">CARACTERÍSTICAS</a>
                <a href="../index.html#testimonios" class="sidebar-nav-link">TESTIMONIOS</a>
                <a href="../index.html#login" class="sidebar-nav-link">INICIAR SESIÓN</a>
            </div>

            <div class="sidebar-divider"></div>

            <div class="sidebar-bottom">
                <a href="registro.pl" class="btn-solicitar-cita-mobile text-white">Regístrate</a>
            </div>
        </div>
    </div>
    <div class="sidebar-overlay" id="sidebarOverlay"></div>

    <main class="flex-grow-1 d-flex align-items-center justify-content-center px-2 mt-5 pt-5">
        <div class="registration-container animate-entrance">
            <div class="login-card shadow-premium border-0" style="border: 1px solid var(--md-green-medical) !important;">
                <div class="login-header-premium text-center">
                    <div class="icon-pulse-container">
                        <i class="bi bi-hospital-fill text-navy fs-2"></i>
                    </div>
                    <h5 class="fw-bold text-navy mb-0">Crea tu Consultorio</h5>
                    <p class="text-navy-50 small mb-0">Diamond Edition | Gestión Inteligente</p>
                </div>

                <div class="card-body">
                    <form method="POST" action="../api/guardar_cliente.pl" id="formRegistro">
                        <div id="alertContainer"></div>

                        <div class="form-floating mb-3">
                            <input type="text" class="form-control" id="h_admin_nombre" name="h_admin_nombre" placeholder="Nombre" required>
                            <label for="h_admin_nombre"><i class="bi bi-person-badge me-2"></i>Nombre del Especialista</label>
                        </div>

                        <div class="form-floating mb-2">
                            <input type="email" class="form-control" id="h_admin_correo" name="h_admin_correo" placeholder="Email" required>
                            <label for="h_admin_correo"><i class="bi bi-envelope-at me-2"></i>Correo Electrónico</label>
                        </div>
                        <div id="emailInfo" class="small mb-3 px-1" style="min-height: 20px;"></div>

                        <div class="row g-2 mb-4">
                            <div class="col-6">
                                <div class="form-floating">
                                    <input type="password" class="form-control" id="h_admin_clave" name="h_admin_clave" placeholder="Clave" required>
                                    <label for="h_admin_clave"><i class="bi bi-lock me-2"></i>Contraseña</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating">
                                    <input type="password" class="form-control" id="h_admin_clave_confirm" name="h_admin_clave_confirm" placeholder="Confirma" required>
                                    <label for="h_admin_clave_confirm"><i class="bi bi-shield-check me-2"></i>Confirmar</label>
                                </div>
                            </div>
                        </div>

                        <div class="p-3 bg-light rounded-4 mb-4" style="border: 1px dashed #cbd5e1;">
                            <div class="form-check form-switch px-0 d-flex align-items-center justify-content-between">
                                <label class="form-check-label fw-bold text-navy small" for="consent_calendar">
                                    <i class="bi bi-google me-2 text-primary"></i>Google Calendar Sync
                                </label>
                                <input class="form-check-input ms-0" type="checkbox" name="consent_calendar" id="consent_calendar" checked>
                            </div>
                            <div id="oauthWarning" class="alert alert-warning mt-2 mb-0 py-2 px-3 border-0 rounded-3 d-none" style="font-size: 0.75rem; background: #fffbeb; color: #92400e;">
                                <i class="bi bi-exclamation-triangle-fill me-1"></i>
                                <strong>Nota:</strong> Tu agenda no se sincronizará automáticamente con Google Calendar.
                            </div>
                        </div>

                        <button type="submit" class="btn-medentia-action w-100 shadow-lg py-3">
                            <i class="bi bi-rocket-takeoff-fill me-2"></i>Finalizar Registro
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </main>

    <footer class="text-center py-4">
        <p class="text-navy-50 small mb-0 opacity-50">GEISABPA &copy; 2026 | Blindaje Diamante</p>
    </footer>

    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script>
        $(document).ready(function() {
            let emailTimer;
            $('#h_admin_correo').on('input', function() {
                clearTimeout(emailTimer);
                const email = $(this).val();
                const $info = $('#emailInfo');
                
                $(this).removeClass('is-valid is-invalid');
                $info.html('<span class="spinner-border spinner-border-sm me-1"></span> Verificando...');

                if (email.length < 5) {
                    $info.text('');
                    return;
                }
                
                emailTimer = setTimeout(() => {
                    $.post('check_email.pl', { correo: email }, function(res) {
                        if (res.exists) {
                            $('#h_admin_correo').addClass('is-invalid');
                            $info.html('<i class="bi bi-exclamation-circle me-1"></i> Este correo ya está registrado.').css('color','#e11d48');
                        } else {
                            $('#h_admin_correo').addClass('is-valid');
                            $info.html('<i class="bi bi-check-circle me-1"></i> Correo disponible.').css('color','#00b894');
                        }
                    }, 'json');
                }, 600);
            });

            $('#consent_calendar').on('change', function() {
                if ($(this).is(':checked')) {
                    $('#oauthWarning').addClass('d-none');
                } else {
                    $('#oauthWarning').removeClass('d-none');
                }
            });

            $('#formRegistro').on('submit', function(e) {
                if ($('#h_admin_clave').val() !== $('#h_admin_clave_confirm').val()) {
                    e.preventDefault();
                    alert('Las contraseñas no coinciden.');
                }
            // Lógica Sidebar Móvil
            const openBtn = document.getElementById('openMobileMenu');
            const closeBtn = document.getElementById('closeMobileMenu');
            const sidebar = document.getElementById('mobileSidebar');
            const overlay = document.getElementById('sidebarOverlay');

            function toggleSidebar() {
                sidebar.classList.toggle('open');
                overlay.classList.toggle('show');
                document.body.style.overflow = sidebar.classList.contains('open') ? 'hidden' : '';
            }

            if (openBtn) openBtn.addEventListener('click', toggleSidebar);
            if (closeBtn) closeBtn.addEventListener('click', toggleSidebar);
            if (overlay) overlay.addEventListener('click', toggleSidebar);

            document.querySelectorAll('.sidebar-nav-link').forEach(link => {
                link.addEventListener('click', toggleSidebar);
            });
        });
    </script>
</body>
</html>
HTML
1;