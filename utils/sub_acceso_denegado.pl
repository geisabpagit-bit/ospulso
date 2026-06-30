#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use lib '..';

# --- FUNCIÓN CENTRAL: Renderiza el Error de Credenciales Incorrectas ---
sub render_acceso_denegado {
    my (%args) = @_;

    # Forzar UTF-8 en salida
    binmode(STDOUT, ":utf8");

    my $mensaje = $args{mensaje} // 'El correo o la contraseña son incorrectos. Por favor, verifica tus datos e intenta de nuevo.';
    my $titulo  = $args{titulo}  // 'Acceso Denegado | MedentIA';

    # 1. Imprime el contenido HTML moderno
    print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$titulo</title>
    
    <!-- Libs Core -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    
    <!-- MedentIA Design System -->
    <link rel="stylesheet" href="../css/medentia_master.css">
    <link rel="stylesheet" href="../css/indexFirst.css">
    
    <style>
        .error-card {
            max-width: 450px;
            margin: 0 auto;
            border: 1px solid #fee2e2 !important; /* Rojo suave para error */
            border-radius: 2.5rem !important;
            overflow: hidden;
            box-shadow: 0 20px 50px rgba(220, 38, 38, 0.08);
        }
        .error-header {
            background: linear-gradient(135deg, #fff5f5 0%, #ffffff 100%);
            padding: 2.5rem 2rem;
            text-align: center;
            border-bottom: 1px solid #fee2e2;
        }
        .error-icon {
            width: 60px;
            height: 60px;
            background: #fef2f2;
            color: #dc2626;
            border-radius: 20px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 1rem;
            font-size: 2rem;
            animation: pulse-error 2s infinite;
        }
        \@keyframes pulse-error {
            0% { transform: scale(1); box-shadow: 0 0 0 0 rgba(220, 38, 38, 0.2); }
            70% { transform: scale(1.05); box-shadow: 0 0 0 10px rgba(220, 38, 38, 0); }
            100% { transform: scale(1); box-shadow: 0 0 0 0 rgba(220, 38, 38, 0); }
        }
        .btn-regresar-login {
            background: var(--md-blue-deep);
            color: white !important;
            padding: 1rem;
            border-radius: 1.25rem;
            font-weight: 800;
            text-decoration: none !important;
            display: block;
            text-align: center;
            transition: 0.3s;
            box-shadow: 0 10px 20px rgba(10, 42, 102, 0.15);
        }
        .btn-regresar-login:hover {
            transform: scale(1.03);
            background: white;
            color: var(--md-blue-deep) !important;
            border: 1px solid var(--md-blue-deep);
        }
    </style>
</head>
<body class="d-flex flex-column min-vh-100 bg-light">

    <!-- Navbar Minimalista (Solo Regresar) -->
    <nav class="navbar-fixed-pill shadow-2xl">
        <div class="navbar-content">
            <a href="../index.html" class="navbar-logo-link">
                <svg viewBox="0 0 500 120" fill="none" xmlns="http://www.w3.org/2000/svg" class="navbar-logo-svg">
                    <g>
                        <path d="M40 60C40 43.4315 53.4315 30 70 30" stroke="#124A9E" stroke-width="6" stroke-linecap="round"></path>
                        <circle cx="40" cy="60" r="4" fill="#18D1E6"></circle>
                        <path d="M40 60C40 76.5685 53.4315 90 70 90" stroke="#124A9E" stroke-width="6" stroke-linecap="round"></path>
                        <circle cx="70" cy="30" r="4" fill="#18D1E6"></circle>
                        <circle cx="70" cy="90" r="4" fill="#18D1E6"></circle>
                        <path d="M55 45H40" stroke="#124A9E" stroke-width="4"></path>
                        <path d="M55 75H40" stroke="#124A9E" stroke-width="4"></path>
                        <rect x="75" y="35" width="50" height="50" rx="10" fill="#124A9E"></rect>
                        <path d="M100 45V75M85 60H115" stroke="white" stroke-width="8" stroke-linecap="round"></path>
                    </g>
                    <text x="150" y="82" font-family="Outfit" font-weight="800" font-size="64" fill="#0A2A66">Medent</text>
                    <text x="410" y="82" font-family="Outfit" font-weight="800" font-size="64" fill="#18D1E6">IA</text>
                </svg>
            </a>
            <a href="../index.html" class="btn btn-outline-primary btn-sm rounded-pill px-3 fw-bold">
                <i class="bi bi-arrow-left me-1"></i> Regresar
            </a>
        </div>
    </nav>

    <main class="flex-grow-1 d-flex align-items-center justify-content-center px-3 mt-5 pt-5">
        <div class="error-card bg-white animate__animated animate__zoomIn">
            <div class="error-header">
                <div class="error-icon">
                    <i class="bi bi-shield-lock"></i>
                </div>
                <h3 class="fw-bold text-navy mb-2">Acceso denegado</h3>
                <p class="text-muted small mb-0">Software Dental Mexicano | Diamond Edition</p>
            </div>
            <div class="card-body p-4 text-center">
                <p class="fs-6 text-navy mb-4">$mensaje</p>
                <a href="../index.html" class="btn-regresar-login">
                    <i class="bi bi-door-open-fill me-2"></i>Volver al login
                </a>
            </div>
        </div>
    </main>

    <footer class="text-center py-4">
        <p class="text-navy-50 small mb-0 opacity-50">GEISABPA &copy; 2026 | Protección Inteligente</p>
    </footer>

</body>
</html>
HTML
}

1;