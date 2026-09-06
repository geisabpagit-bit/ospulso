#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use File::Spec;

# ==========================================================
# SDM - RESTABLECER CONTRASEÑA v3.1.6 PREMIUM
# ==========================================================

use lib "$FindBin::Bin/..";
my $q = CGI->new;
my $token = $q->param('token') || '';
my $current_time = time();
my ($is_valid, $valid_correo) = (0, undef);

my $archivo_tokens = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'tokens.dat');

if ($token && -e $archivo_tokens) {
    if (open(my $fh, '<:encoding(UTF-8)', $archivo_tokens)) {
        while (my $linea = <$fh>) {
            chomp $linea;
            my ($t, $c, $exp) = split /!/, $linea;
            if ($t eq $token && $exp > $current_time) {
                $is_valid = 1;
                $valid_correo = $c;
                last;
            }
        }
        close($fh);
    }
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');

print <<'HTML';
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0" />
    <title>Recuperación - OSPulso</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="16x16" href="../favicon/favicon-16x16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="64x64" href="../favicon/favicon-64x64.png">
    <link rel="icon" type="image/png" sizes="128x128" href="../favicon/favicon-128x128.png">
    <link rel="icon" type="image/x-icon" href="../favicon/favicon.ico">
    <link rel="apple-touch-icon" sizes="180x180" href="../favicon/apple-touch-icon.png">
    <link rel="manifest" href="../favicon/site.webmanifest">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet" />
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet" />
    <link href="https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css" rel="stylesheet" />
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;600;800&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <link href="../css/ospulso_master.css" rel="stylesheet">
    <link href="../css/sdm_mobile_standards.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <style>
        body { 
            font-family: var(--font-secondary); 
            background: var(--md-white-clinical); 
            min-height: 100vh; 
            display: flex; 
            flex-direction: column; 
        }
        .navbar-medentia { 
            background: var(--md-blue-deep); 
            padding: 1rem; 
            box-shadow: var(--shadow-md);
        }
        .glass-card { 
            background: rgba(255, 255, 255, 0.98); 
            backdrop-filter: blur(10px); 
            border-radius: var(--radius-lg); 
            border: 1px solid var(--md-gray-soft);
            box-shadow: var(--shadow-lg);
            max-width: 450px;
            width: 100%;
            margin: auto;
        }
        .form-control:focus { 
            border-color: var(--md-cyan-ia); 
            box-shadow: 0 0 0 0.25rem rgba(24, 209, 230, 0.1); 
        }
        .btn-medentia { 
            background: var(--md-blue-deep); 
            color: white; 
            border-radius: var(--radius-md); 
            font-weight: 700; 
            transition: 0.3s;
            border: none;
            font-family: var(--font-primary);
        }
        .btn-medentia:hover { 
            background: var(--md-blue-medical); 
            transform: translateY(-2px); 
            color: white; 
            box-shadow: var(--shadow-md);
        }
        footer { 
            background: var(--md-blue-deep); 
            color: rgba(255,255,255,0.6); 
            padding: 2rem 0; 
            margin-top: auto; 
        }
        .input-group-text.bg-white {
            border-left: none;
            cursor: pointer;
        }
        .form-control.border-end-0 {
            border-right: none;
        }
    </style>
</head>
<body>

<nav class="navbar-medentia">
    <div class="container-fluid justify-content-center text-center">
        <a class="navbar-brand m-0" href="../index.html">
            <img src="../img/logo_ospulso.png" alt="OSPulso Logo" style="height: 45px;">
        </a>
    </div>
</nav>

<div class="container container-mobile-flush flex-grow-1 d-flex py-4 py-md-5">
HTML

if ($is_valid) {
    print <<"HTML";
    <div class="glass-card card-mobile-flush p-3 p-md-5 animate__animated animate__fadeInUp">
        <div class="text-center mb-4 mb-md-5">
            <div class="bg-primary bg-opacity-10 text-primary rounded-circle d-inline-flex align-items-center justify-content-center mb-3 shadow-sm" style="width: 80px; height: 80px;">
                <i class="bi bi-shield-lock-fill fs-1"></i>
            </div>
            <h2 class="fw-extrabold text-dark" style="font-weight: 800; font-family: var(--font-primary);">Nueva Clave</h2>
            <p class="text-muted small">Configurando acceso para:<br><span class="badge bg-light text-primary border mt-1" style="font-size: 0.9rem;">$valid_correo</span></p>
        </div>

        <form action="actualizar_clave.pl" method="POST" id="recoveryForm">
            <input type="hidden" name="h_token" value="$token" />
            
            <div class="mb-3">
                <label for="newPass" class="form-label text-muted small fw-bold">Nueva Contraseña</label>
                <div class="input-group">
                    <span class="input-group-text bg-white text-muted"><i class="bi bi-key"></i></span>
                    <input type="text" name="h_nueva_clave" id="newPass" class="form-control form-control-lg border-end-0" placeholder="Escribe tu nueva clave" required minlength="8">
                    <span class="input-group-text bg-white text-muted toggle-password" data-target="newPass"><i class="bi bi-eye-slash-fill"></i></span>
                </div>
            </div>

            <div class="mb-4">
                <label for="confPass" class="form-label text-muted small fw-bold">Confirmar Contraseña</label>
                <div class="input-group">
                    <span class="input-group-text bg-white text-muted"><i class="bi bi-check2-all"></i></span>
                    <input type="text" name="h_confirmar_clave" id="confPass" class="form-control form-control-lg border-end-0" placeholder="Repite la clave" required minlength="8">
                    <span class="input-group-text bg-white text-muted toggle-password" data-target="confPass"><i class="bi bi-eye-slash-fill"></i></span>
                </div>
            </div>

            <button type="submit" class="btn-medentia btn-mobile-standard btn-mobile-full w-100 shadow-sm mb-2" id="submitBtn">
                <i class="bi bi-shield-check me-2"></i> ESTABLECER ACCESO
            </button>
            
            <div id="msg-error" class="text-danger small text-center fw-bold animate__animated animate__headShake" style="display:none;">
                <i class="bi bi-exclamation-triangle-fill me-1"></i> Las contraseñas no coinciden.
            </div>
        </form>
    </div>
HTML

    print <<'JS';
    <script>
        const form = document.getElementById('recoveryForm');
        const pass = document.getElementById('newPass');
        const conf = document.getElementById('confPass');
        const error = document.getElementById('msg-error');
        const btn = document.getElementById('submitBtn');
        const toggles = document.querySelectorAll('.toggle-password');

        // Toggle visibilidad de contraseña
        toggles.forEach(toggle => {
            toggle.addEventListener('click', function() {
                const targetId = this.getAttribute('data-target');
                const input = document.getElementById(targetId);
                const icon = this.querySelector('i');
                
                if (input.type === 'text') {
                    input.type = 'password';
                    icon.classList.remove('bi-eye-slash-fill');
                    icon.classList.add('bi-eye-fill');
                } else {
                    input.type = 'text';
                    icon.classList.remove('bi-eye-fill');
                    icon.classList.add('bi-eye-slash-fill');
                }
            });
        });

        // Validacion en vivo
        function validateMatch() {
            if (conf.value.length > 0 && pass.value !== conf.value) {
                conf.classList.add('is-invalid');
                conf.classList.remove('is-valid');
                error.style.display = 'block';
                btn.disabled = true;
            } else if (conf.value.length > 0) {
                conf.classList.remove('is-invalid');
                conf.classList.add('is-valid');
                error.style.display = 'none';
                btn.disabled = false;
            } else {
                conf.classList.remove('is-invalid', 'is-valid');
                error.style.display = 'none';
                btn.disabled = false;
            }
        }
        
        pass.addEventListener('input', validateMatch);
        conf.addEventListener('input', validateMatch);

        form.onsubmit = (e) => {
            if (pass.value !== conf.value) {
                e.preventDefault();
                error.style.display = 'block';
                conf.classList.add('is-invalid');
                return false;
            }
            Swal.fire({
                title: 'Actualizando...',
                text: 'Por favor espera un momento',
                allowOutsideClick: false,
                didOpen: () => { Swal.showLoading(); }
            });
        };
    </script>
JS

} else {
    print <<"HTML";
    <div class="glass-card card-mobile-flush p-4 p-md-5 text-center animate__animated animate__shakeX">
        <div class="text-danger mb-4">
            <i class="bi bi-exclamation-octagon-fill" style="font-size: 5rem;"></i>
        </div>
        <h3 class="fw-bold text-dark" style="font-family: var(--font-primary);">Vínculo Caducado</h3>
        <p class="text-muted">Por seguridad, los enlaces de recuperación expiran en 1 hora o tras su primer uso.</p>
        <hr class="my-4 opacity-10">
        <a href="../index.html" class="btn-medentia btn-mobile-standard btn-mobile-full px-5 w-100">VOLVER AL INICIO</a>
        <meta http-equiv="refresh" content="10; url=../index.html">
    </div>
HTML
}

print <<'FOOTER';
</div>

<footer>
    <div class="container text-center">
        <p class="small mb-2 fw-bold">OSPulso - Plataforma de Gestión Clínica</p>
        <p class="mb-0" style="font-size: 0.75rem;">© 2026 GEISABPA Plataformas Digitales de México</p>
    </div>
</footer>

</body>
</html>
FOOTER

1;