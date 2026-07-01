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
    <title>OSPulso | Registro de Clínica</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link href="../css/ospulso_master.css" rel="stylesheet">
    <style>
        /* Ajustes específicos para el Registro OSPulso */
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
                border-radius: 20px !important;
            }
            main {
                padding-left: 5px !important;
                padding-right: 5px !important;
                margin-top: 5rem !important;
            }
        }
        .form-control:focus {
            border-color: #00C4C4;
            box-shadow: 0 0 0 0.25rem rgba(0, 196, 196, 0.1);
        }
    </style>
</head>
<body class="d-flex flex-column min-vh-100">

    <!-- HEADER -->
    <header class="navbar navbar-expand-lg">
        <a href="../index.html" class="logo text-decoration-none d-flex align-items-center justify-content-center" style="margin-bottom: -10px;">
            <svg class="ospulso-logo-svg" viewBox="0 0 165 50" xmlns="http://www.w3.org/2000/svg" style="height: 55px; width: auto; overflow: visible;">
                <text x="0" y="32" font-family="'Outfit', sans-serif" font-weight="900" font-size="28" letter-spacing="0.5">
                    <tspan fill="#0A2A66">Os</tspan><tspan fill="#00C4C4">Pulso</tspan>
                </text>
                <path class="ekg-line-anim" d="M0 40 H115 L121 22 L128 42 L134 6 L141 34 L146 40 H160" stroke="#00C4C4" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none" />
            </svg>
            <span class="d-none d-md-inline-block text-secondary small border-start ps-3 ms-2 align-self-center py-1 fw-medium" style="font-size: 0.72rem; letter-spacing: 0.5px;">Sistema Operativo para Clínicas Modernas</span>
        </a>
        <nav class="menu d-none d-lg-flex">
            <a href="../index.html#inicio">Producto</a>
            <a href="../index.html#problema">El Reto</a>
            <a href="../index.html#demo">Demo Interactiva</a>
            <a href="../index.html#planes">Planes</a>
        </nav>
        <div class="acciones d-none d-lg-flex">
            <a href="../index.html" class="btn-outline">Iniciar Sesión</a>
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
                <a href="../index.html#inicio" class="sidebar-nav-link active">Producto</a>
                <a href="../index.html#problema" class="sidebar-nav-link">El Reto</a>
                <a href="../index.html#demo" class="sidebar-nav-link">Demo Interactiva</a>
                <a href="../index.html#planes" class="sidebar-nav-link">Planes</a>
                <a href="../index.html" class="sidebar-nav-link">Iniciar Sesión</a>
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
            <div class="login-card shadow-premium border-0" style="border-radius: 20px; overflow: hidden; border: 1px solid var(--md-green-medical) !important; background: rgba(255, 255, 255, 0.98); backdrop-filter: blur(25px);">
                <div class="login-header-premium text-center">
                    <div class="icon-pulse-container" style="background: rgba(0, 196, 196, 0.1); width: 60px; height: 60px; display: inline-flex; align-items: center; justify-content: center; border-radius: 50%; margin-bottom: 15px;">
                        <i class="bi bi-shield-check text-primary fs-3"></i>
                    </div>
                    <h5 class="fw-bold text-navy mb-1">Comienza con OSPulso</h5>
                    <p class="text-navy-50 small mb-0">Menos administración. Más medicina.</p>
                </div>

                <div class="card-body p-4">
                    <form method="POST" action="../api/guardar_cliente.pl" id="formRegistro">
                        <div id="alertContainer"></div>

                        <div class="form-floating mb-3">
                            <input type="text" class="form-control" id="h_admin_nombre" name="h_admin_nombre" placeholder="Nombre" required style="border: 2px solid #e2e8f0; border-radius: 8px;">
                            <label for="h_admin_nombre"><i class="bi bi-person-badge me-2"></i>Nombre del Especialista</label>
                        </div>

                        <div class="form-floating mb-2">
                            <input type="email" class="form-control" id="h_admin_correo" name="h_admin_correo" placeholder="Email" required style="border: 2px solid #e2e8f0; border-radius: 8px;">
                            <label for="h_admin_correo"><i class="bi bi-envelope-at me-2"></i>Correo Electrónico</label>
                        </div>
                        <div id="emailInfo" class="small mb-3 px-1" style="min-height: 20px;"></div>

                        <div class="row g-2 mb-4">
                            <div class="col-6">
                                <div class="form-floating">
                                    <input type="password" class="form-control" id="h_admin_clave" name="h_admin_clave" placeholder="Clave" required style="border: 2px solid #e2e8f0; border-radius: 8px;">
                                    <label for="h_admin_clave"><i class="bi bi-lock me-2"></i>Contraseña</label>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="form-floating">
                                    <input type="password" class="form-control" id="h_admin_clave_confirm" name="h_admin_clave_confirm" placeholder="Confirma" required style="border: 2px solid #e2e8f0; border-radius: 8px;">
                                    <label for="h_admin_clave_confirm"><i class="bi bi-shield-check me-2"></i>Confirmar</label>
                                </div>
                            </div>
                        </div>

                        <div class="p-3 bg-light rounded-4 mb-4" style="border-radius: 12px; border: 1px dashed #cbd5e1;">
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

                        <button type="submit" class="btn btn-primary w-100 py-3 fw-bold shadow-lg" style="border-radius: 12px; background: var(--md-blue-medical); border: none;">
                            Quiero que mi clínica vuelva a rendir al 100%
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </main>

    <!-- FOOTER -->
    <footer style="background: rgba(232, 243, 255, 0.96) !important; backdrop-filter: blur(15px) !important; -webkit-backdrop-filter: blur(15px) !important; color: var(--md-blue-deep) !important; padding: 2rem 0 !important; margin-top: auto; border-top: 1px solid rgba(10, 42, 102, 0.08) !important;">
        <div class="container text-center">
            <p class="mb-0 small fw-semibold">GEISABPA &copy; 2026 | OSPulso es una marca registrada de Plataformas Digitales de México.</p>
        </div>
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
            });

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