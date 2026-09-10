#!/usr/bin/perl
use cPanelUserConfig;

use strict;
use warnings;

use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use CGI::Session;
use lib '.';

# --- Carga de Subrutinas ---
sub render_header;
sub render_footer;

require 'sub_header.pl';
require 'sub_footer.pl';
require 'render_dashboard_principal.pl';

# --- 1. Declaración de Variables ---
my $q = CGI->new; 
# CORRECCIÓN DE SEGURIDAD: Mismo check que acceso.pl
my $session_dir = (-d './sessions' && -w './sessions') ? './sessions' : '/tmp';

my $session;  
my $usuario = ''; 

# --- 2. Lógica de Sesión: INTENTAR RECUPERAR ---
eval {
    # Recuperar la sesión del mismo directorio que el script de login.
    $session = CGI::Session->new(undef, $q, {Directory => $session_dir});
};
if ($@) {
    # Manejo de error de CGI::Session
    print $q->header('text/html; charset=UTF-8');
    # ... (código de error) ...
    exit;
}

$usuario = $session->param('usuario') || ''; 
my $session_id_actual = $session->id() || 'NINGUNO'; 

print $q->header('text/html; charset=UTF-8');

if ($usuario) {
    # CASO 1: Sesión válida (ÉXITO)
    render_header(
        usuario     => $usuario,
        titulo      => 'Inicio - Software Dental Mexicano',
        ruta_logout => 'cerrar_sesion.pl'
    );
    render_dashboard_principal();
    render_footer();

} else {
    # CASO 2: Sesión NO válida (Falló la recuperación)
    render_header(usuario => 'Invitado', titulo => 'Error de Sesión', ruta_logout => 'index.html', show_nav_content => 0);
    
    # Muestra el error de acceso con la información de depuración
    print <<HTML;
<div class="container d-flex justify-content-center align-items-center" style="min-height: 80vh;">
  <div class="card shadow-sm p-4 text-center text-danger" style="max-width: 500px; width: 100%;">
    <i class="bi bi-shield-lock text-danger" style="font-size: 3rem;"></i>
    <h5 class="mt-3 text-danger">Acceso Restringido - DEBUG</h5>
    <p class="mb-0 mt-2">Tu sesión ha expirado o no se pudo cargar.</p>
    <hr>
    <p class="text-start small">
        <strong>DEBUG ID:</strong> <code class="text-break">$session_id_actual</code><br>
        <strong>Directorio Usado:</strong> <code class="text-danger">$session_dir</code>
    </p>
    <div class="mt-4">
      <a href="index.html" class="btn btn-primary"><i class="bi bi-box-arrow-in-right me-1"></i>Iniciar sesión</a>
    </div>
  </div>
</div>
HTML
    render_footer();
}