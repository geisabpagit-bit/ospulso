#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use utf8;
use open qw(:std :utf8);
use FindBin;
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";

# --- Carga de Subrutinas y Módulos ---
sub render_header;
sub render_footer;
sub render_bottom_nav;
sub render_catalogo_principal;

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, 'render_catalogo_principal.pl'); 

# --- Validar sesión y obtener datos (Protocolo 11.1) ---
my $session_data = check_session();

my $q          = $session_data->{q};
my $session_ok = $session_data->{session_ok};
my $usuario    = $session_data->{usuario};
my $role       = $session_data->{role};

print $q->header('text/html; charset=UTF-8');

if ($session_ok) {
    # 1. Renderizamos la cabecera (Navbar)
    render_header(
        usuario     => $usuario,
        titulo      => "Administración - $role",
        ruta_logout => '../auth/cerrar_sesion.pl',
        role        => $role,
        skip_header => 1 
    );

    # 2. Renderizamos el contenido de Catálogos (NIVEL 2)
    render_catalogo_principal(role => $role);

    # 3. Navegación Inferior (Móvil)
    render_bottom_nav('ajustes');

    # 4. Renderizamos el pie de página
    render_footer();

} else {
    # CASO: Sesión no válida o EXPIRADA (Diseño Bento/Glassmorphism Premium)
    render_header(usuario => 'Invitado', titulo => 'Error de Sesión', ruta_logout => '../index.html', show_nav_content => 0);
    
    print <<HTML;
<div class="container d-flex justify-content-center align-items-center animate__animated animate__zoomIn" style="min-height: 80vh;">
  <div class="card-medentia p-5 text-center border-danger border-opacity-50 shadow-lg" style="max-width: 500px; width: 100%;">
    <div class="bg-danger bg-opacity-10 text-danger rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style="width: 80px; height: 80px;">
      <i class="bi bi-shield-lock-fill fs-1"></i>
    </div>
    <h4 class="fw-bold text-dark mb-3">Acceso Restringido - Sesión Expirada</h4>
    <p class="text-muted small mb-4">Tu sesión ha expirado o no se pudo cargar. Por favor, vuelve a iniciar sesión para continuar.</p>
    <div>
      <a href="../index.html" class="btn-medentia px-4"><i class="bi bi-arrow-left-circle-fill me-2"></i>Volver al Login</a>
    </div>
  </div>
</div>
HTML

    render_footer();
}

1;