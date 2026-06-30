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

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Seguridad - MedentIA</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet" />
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet" />
    <link href="https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css" rel="stylesheet" />
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;600;800&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <link href="../css/ospulso_master.css" rel="stylesheet">
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
            width: 95%;
            margin: auto;
        }
        .form-floating > .form-control:focus { 
            border-color: var(--md-cyan-ia); 
            box-shadow: 0 0 0 0.25rem rgba(24, 209, 230, 0.1); 
        }
        .btn-medentia { 
            background: var(--md-blue-deep); 
            color: white; 
            border-radius: var(--radius-md); 
            padding: 1rem; 
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
    </style>
</head>
<body>

<nav class="navbar-medentia">
    <div class="container-fluid justify-content-center text-center">
        <a class="navbar-brand m-0" href="../index.html">
            <img src="../img/logo_medentia.png" alt="MedentIA Logo" style="height: 45px;">
        </a>
    </div>
</nav>

<div class="container flex-grow-1 d-flex py-5">
HTML

if ($is_valid) {
    print <<HTML;
    <div class="glass-card p-4 p-md-5 animate__animated animate__fadeInUp">
        <div class="text-center mb-5">
            <div class="bg-primary bg-opacity-10 text-primary rounded-pill d-inline-flex align-items-center justify-content-center mb-3" style="width: 80px; height: 80px;">
                <i class="bi bi-shield-lock-fill fs-1"></i>
            </div>
            <h2 class="fw-extrabold text-dark" style="font-weight: 800;">Nueva Clave</h2>
            <p class="text-muted">Protegiendo la cuenta de:<br><span class="badge bg-light text-dark border">$valid_correo</span></p>
        </div>

        <form action="actualizar_clave.pl" method="POST" id="recoveryForm">
            <input type="hidden" name="h_token" value="$token" />
            
            <div class="form-floating mb-3">
                <input type="password" name="h_nueva_clave" id="newPass" class="form-control" placeholder="Clave" required minlength="8">
                <label for="newPass">Nueva Contraseña</label>
            </div>

            <div class="form-floating mb-4">
                <input type="password" name="h_confirmar_clave" id="confPass" class="form-control" placeholder="Confirmar" required minlength="8">
                <label for="confPass">Confirmar Contraseña</label>
            </div>

            <button type="submit" class="btn-medentia w-100 shadow-lg mb-3">
                ACTUALIZAR CREDENCIALES
            </button>
            
            <div id="msg-error" class="text-danger small text-center fw-bold" style="display:none;">
                <i class="bi bi-exclamation-circle me-1"></i> Las contraseñas no coinciden.
            </div>
        </form>
    </div>

    <script>
        const form = document.getElementById('recoveryForm');
        const pass = document.getElementById('newPass');
        const conf = document.getElementById('confPass');
        const error = document.getElementById('msg-error');

        form.onsubmit = (e) => {
            if (pass.value !== conf.value) {
                e.preventDefault();
                error.style.display = 'block';
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
HTML
} else {
    print <<HTML;
    <div class="glass-card p-5 text-center animate__animated animate__shakeX">
        <div class="text-danger mb-4">
            <i class="bi bi-exclamation-octagon-fill" style="font-size: 5rem;"></i>
        </div>
        <h3 class="fw-bold text-dark">Vínculo Caducado</h3>
        <p class="text-muted">Por seguridad, los enlaces de recuperación expiran en 24 horas o tras su primer uso.</p>
        <hr class="my-4 opacity-10">
        <a href="../index.html" class="btn-medentia d-inline-block px-5">VOLVER AL INICIO</a>
        <meta http-equiv="refresh" content="10; url=../index.html">
    </div>
HTML
}

print <<HTML;
</div>

<footer>
    <div class="container text-center">
        <p class="small mb-2 fw-bold">Software Dental Mexicano - Plataforma de Gestión Clínica</p>
        <p class="mb-0" style="font-size: 0.75rem;">© 2026 GEISABPA Plataformas Digitales de México</p>
    </div>
</footer>

</body>
</html>
HTML

1;