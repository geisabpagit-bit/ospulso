#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;

# 1. Intentar enviar cabecera lo antes posible
my $q = CGI->new;
use CGI::Carp qw(fatalsToBrowser);

use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

# 2. Carga segura de módulos no-core
eval {
    require CGI::Session;
    require JSON::PP;
    require utils::db_manager;
    utils::db_manager->import(qw(autenticar_usuario verificar_estado_negocio));
};
if ($@) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<h1>Error de Sistema</h1><p>Falla en dependencias: $@</p>";
    exit;
}

# --- CARGA DE UTILIDADES UI (Orden Crítico) ---
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_acceso_denegado.pl');

# --- LÓGICA PRINCIPAL ---
my $correo_ingresado = $q->param('h_correo') // '';
my $clave_ingresada  = $q->param('h_clave')  // '';

$correo_ingresado =~ s/\s//g;
$correo_ingresado = lc($correo_ingresado);

# Redirección si faltan datos
unless ($correo_ingresado && $clave_ingresada) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print '<meta http-equiv="refresh" content="0;url=../index.html">';
    exit;
}

# 3. Autenticación
my ($success, $msg, $usuario_data) = autenticar_usuario($correo_ingresado, $clave_ingresada);

if ($success) {
    # 3.1 Verificar Estado de Negocio (Suscripción)
    my $id_negocio = $usuario_data->{id_empresa} || $usuario_data->{id_negocio} || 0;
    if ($id_negocio) {
        my $biz_status = verificar_estado_negocio($id_negocio);
        if (!$biz_status->{activo}) {
            print $q->header(-type => 'text/html', -charset => 'UTF-8');
            render_acceso_denegado(
                skip_header => 1, 
                mensaje => "Suscripción Vencida o Cuenta Inactiva. Por favor contacte a soporte para renovar su licencia."
            );
            exit;
        }
    }

    my $session_dir = File::Spec->catdir($FindBin::Bin, 'sessions');
    
    # Intentar crear el directorio si no existe
    unless (-d $session_dir) {
        mkdir($session_dir, 0755);
    }

    my $session;
    eval {
        $session = CGI::Session->new(undef, $q, { Directory => $session_dir });
    };
    
    if (!$session || $@) {
        print $q->header(-type => 'text/html', -charset => 'UTF-8');
        print "<h1>Error de Sesión</h1><p>No se pudo inicializar la sesión. Error: $@</p>";
        exit;
    }

    $session->expire('+2h');
    $session->param('uid',             $usuario_data->{correo});
    $session->param('usuario',         $usuario_data->{nombre});
    $session->param('role',            $usuario_data->{rol});
    $session->param('id_registro',     $usuario_data->{id});
    $session->param('id_medico',       $usuario_data->{id});
    $session->param('id_empresa',      $usuario_data->{id_empresa} // '');
    $session->param('id_sucursal',     $usuario_data->{id_sucursal} // '');
    $session->flush();

    my $cookie = $q->cookie(
        -name    => 'CGISESSID',
        -value   => $session->id,
        -expires => '+2h',
        -path    => '/'
    );

    print $q->header(-type => 'text/html', -charset => 'UTF-8', -cookie => $cookie);
    print '<meta http-equiv="refresh" content="0;url=../views/inicial.pl">';

} else {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    if ($msg eq 'PENDIENTE') {
        render_cuenta_pendiente($correo_ingresado);
    } else {
        render_acceso_denegado(skip_header => 1);
    }
}

sub render_cuenta_pendiente {
    my ($correo) = @_;
    print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verificación Requerida | OSPulso</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link rel="stylesheet" href="../css/ospulso_master.css">
    <style>
        .pending-card {
            max-width: 480px;
            margin: 0 auto;
            border: 1px solid #fef3c7 !important;
            border-radius: 2.5rem !important;
            overflow: hidden;
            box-shadow: 0 20px 50px rgba(245, 158, 11, 0.08);
        }
        .pending-header {
            background: linear-gradient(135deg, #fffbeb 0%, #ffffff 100%);
            padding: 2.5rem 2rem;
            text-align: center;
            border-bottom: 1px solid #fef3c7;
        }
        .pending-icon {
            width: 60px; height: 60px;
            background: #fffbeb; color: #d97706;
            border-radius: 20px;
            display: inline-flex; align-items: center; justify-content: center;
            margin-bottom: 1rem; font-size: 2rem;
            animation: pulse-warn 2s infinite;
        }
        \@keyframes pulse-warn {
            0% { transform: scale(1); box-shadow: 0 0 0 0 rgba(217, 119, 6, 0.2); }
            70% { transform: scale(1.05); box-shadow: 0 0 0 10px rgba(217, 119, 6, 0); }
            100% { transform: scale(1); box-shadow: 0 0 0 0 rgba(217, 119, 6, 0); }
        }
    </style>
</head>
<body class="d-flex flex-column min-vh-100 bg-light">
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
                    <text x="150" y="82" font-family="Outfit" font-weight="800" font-size="64" fill="#0A2A66">OS</text>
                    <text x="260" y="82" font-family="Outfit" font-weight="800" font-size="64" fill="#18D1E6">Pulso</text>
                </svg>
            </a>
            <a href="../index.html" class="btn btn-outline-primary btn-sm rounded-pill px-3 fw-bold">
                <i class="bi bi-arrow-left me-1"></i> Regresar
            </a>
        </div>
    </nav>
    <main class="flex-grow-1 d-flex align-items-center justify-content-center px-3 mt-5 pt-5">
        <div class="pending-card bg-white animate__animated animate__fadeInUp">
            <div class="pending-header">
                <div class="pending-icon"><i class="bi bi-envelope-check"></i></div>
                <h3 class="fw-bold text-navy mb-2">Verificación Requerida</h3>
                <p class="text-muted small mb-0">Software Dental Mexicano | Diamond Edition</p>
            </div>
            <div class="card-body p-4 text-center">
                <p class="fs-6 text-navy">Cuenta activa pero pendiente de validación.</p>
                <div class="p-3 bg-light rounded-4 mb-4" style="border: 1px dashed #cbd5e1;">
                    <span class="small text-muted">Revisa el correo:</span><br>
                    <strong class="text-navy">$correo</strong>
                </div>
                <a href="../index.html" class="btn-medentia-action w-100">
                    <i class="bi bi-arrow-left-circle me-2"></i>Volver al inicio
                </a>
            </div>
        </div>
    </main>
</body>
</html>
HTML
}

1;
