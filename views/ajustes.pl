#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use FindBin;
use lib "$FindBin::Bin/..";

require 'auth/check_session.pl';
require 'utils/sub_header.pl';
require 'utils/sub_footer.pl';
require 'utils/sub_bottom_nav.pl';

my $sd = check_session();
my $q = $sd->{q};
unless ($sd->{session_ok}) { print $q->header(-status => '302 Found', -location => '../index.html'); exit; }

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(usuario => $sd->{usuario}, role => $sd->{role}, titulo => 'Configuración - SDM', skip_header => 1);

print <<HTML;
<div class="container py-5 animate__animated animate__fadeIn">
    <!-- Breadcrumb -->
    <div class="d-flex justify-content-between align-items-center mb-4 px-2">
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb mb-0">
                <li class="breadcrumb-item"><a href="inicial.pl" class="text-decoration-none text-muted fw-bold">Inicio</a></li>
                <li class="breadcrumb-item active fw-bold text-primary" aria-current="page">Ajustes Generales</li>
            </ol>
        </nav>
    </div>

    <div class="row justify-content-center">
        <div class="col-lg-8">
            <!-- Bento Header -->
            <div class="bento-card mb-4 border-0 shadow-sm" style="background: white; border-left: 6px solid var(--md-blue-deep) !important;">
                <div class="d-flex align-items-center gap-4">
                    <div class="bg-primary text-white rounded-4 d-flex align-items-center justify-content-center shadow" style="width:70px; height:70px; font-size:2.5rem;">
                        <i class="bi bi-gear-fill"></i>
                    </div>
                    <div>
                        <h2 class="fw-bold plus-jakarta mb-1 text-dark">Configuraci&oacute;n del Sistema</h2>
                        <div class="d-flex gap-3 text-muted small fw-bold uppercase tracking-wider">
                            <span><i class="bi bi-shield-check text-success me-1"></i>V3.6 PREMIUM READY</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Bento List -->
            <div class="bento-card border-0 shadow-sm p-4 bg-white mb-4">
                <h5 class="fw-bold plus-jakarta text-dark mb-4"><i class="bi bi-grid me-2 text-primary"></i>Panel de Control</h5>
                
                <div class="list-group list-group-flush border-0">
                    <a href="perfil.pl" class="list-group-item list-group-item-action d-flex justify-content-between align-items-center border-0 p-3 mb-2 bg-light rounded-4 fw-medium text-secondary">
                        <div class="d-flex align-items-center gap-3">
                            <div class="bg-white p-2 rounded-3 shadow-sm text-primary"><i class="bi bi-person-gear"></i></div>
                            <span>Mi Perfil de Usuario</span>
                        </div>
                        <i class="bi bi-chevron-right"></i>
                    </a>

                    <a href="#" class="list-group-item list-group-item-action d-flex justify-content-between align-items-center border-0 p-3 mb-2 bg-light rounded-4 fw-medium text-secondary">
                        <div class="d-flex align-items-center gap-3">
                            <div class="bg-white p-2 rounded-3 shadow-sm text-info"><i class="bi bi-shield-lock"></i></div>
                            <span>Seguridad y Accesos</span>
                        </div>
                        <i class="bi bi-chevron-right"></i>
                    </a>

                    <a href="../auth/cerrar_sesion.pl" class="list-group-item list-group-item-action d-flex justify-content-between align-items-center border-0 p-3 bg-danger-subtle rounded-4 fw-bold text-danger">
                        <div class="d-flex align-items-center gap-3">
                            <div class="bg-white p-2 rounded-3 shadow-sm text-danger"><i class="bi bi-power"></i></div>
                            <span>Cerrar Sesi&oacute;n</span>
                        </div>
                        <i class="bi bi-box-arrow-right"></i>
                    </a>
                </div>
            </div>

        </div>
    </div>
</div>
HTML

render_bottom_nav('ajustes');
render_footer();
1;
