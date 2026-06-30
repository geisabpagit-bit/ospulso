#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use FindBin;
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";

# 1. Carga Segura de Componentes
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, 'render_dashboard_principal.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'render_error_sesion.pl');

# --- Validar sesión y obtener datos ---
my $session_data = check_session();

my $q          = $session_data->{q};
my $session_ok = $session_data->{session_ok};
my $usuario    = $session_data->{usuario};
my $role       = $session_data->{role};
my $id_medico  = $session_data->{id_medico};

# --- Imprimir cabecera solo si se va a renderizar contenido completo ---
if ($session_ok) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');

    render_header(
        usuario     => $usuario,
        titulo      => 'Inicio - Software Dental Mexicano',
        ruta_logout => '../auth/cerrar_sesion.pl',
        role        => $role,
        id_medico   => $id_medico,
        skip_header => 1
    );

    render_dashboard_principal(role => $role, id_medico => $id_medico);
    render_bottom_nav('inicio');

} else {
    # Los scripts de error ya imprimen sus cabeceras
    render_error_sesion();
}

1;