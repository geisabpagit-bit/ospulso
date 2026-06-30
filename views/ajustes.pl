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
<div class="container py-5">
    <div class="row justify-content-center">
        <div class="col-md-8">
            <div class="card border-0 shadow-sm rounded-4 overflow-hidden">
                <div class="card-header bg-navy text-white p-4" style="background:#103070">
                    <h4 class="m-0 fw-bold">Configuración del Sistema</h4>
                </div>
                <div class="card-body p-5 text-center">
                    <div class="display-1 text-muted mb-4"><i class="bi bi-gear-wide-connected"></i></div>
                    <h3>Panel de Control</h3>
                    <p class="text-muted">Módulo en proceso de integración v3.1.6</p>
                    <hr class="my-4 opacity-10">
                    <div class="list-group text-start">
                        <a href="#" class="list-group-item list-group-item-action p-3 d-flex justify-content-between align-items-center">
                            <span><i class="bi bi-person-gear me-3"></i>Perfil de Usuario</span>
                            <i class="bi bi-chevron-right small text-muted"></i>
                        </a>
                        <a href="#" class="list-group-item list-group-item-action p-3 d-flex justify-content-between align-items-center">
                            <span><i class="bi bi-shield-check me-3"></i>Seguridad</span>
                            <i class="bi bi-chevron-right small text-muted"></i>
                        </a>
                        <a href="../auth/cerrar_sesion.pl" class="list-group-item list-group-item-action p-3 text-danger d-flex justify-content-between align-items-center">
                            <span><i class="bi bi-power me-3"></i>Cerrar Sesión</span>
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
HTML

render_bottom_nav('ajustes');
render_footer();
1;
