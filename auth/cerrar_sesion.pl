#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use FindBin;
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, 'check_session.pl');

# --- SCRIPT PRINCIPAL: CERRAR SESIÓN ---
my $session_data = check_session();
my $q       = $session_data->{q};
my $session = $session_data->{session};

if (defined $session) {
    # Eliminar archivo y cookie de sesión de forma segura
    eval { $session->delete(); };
}

# Limpiar cookie CGISESSID
my $cookie = $q->cookie(
    -name    => 'CGISESSID',
    -value   => '',
    -expires => '-1d',
    -path    => '/',
);

# Redirección al index en raíz
print $q->redirect(
    -uri    => '../index.html',
    -cookie => $cookie,
);

exit;

1;
