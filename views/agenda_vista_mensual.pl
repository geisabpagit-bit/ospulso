#!/usr/bin/perl

use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use Time::Piece;
use Time::Seconds; 
use lib '.';
use JSON;
use POSIX qw(strftime);
use utils::db_manager qw(leer_tabla);

# Dependencias del sistema
require '../auth/check_session.pl';
require '../utils/sub_header.pl';
require '../utils/sub_footer.pl';
require '../utils/sub_navfixgo.pl';
require '../api/sub_agenda_utils.pl';  

# Ejecución principal
main(); 

sub main {
    my $q = CGI->new;
    my $sess_info = check_session($q);
    
    if (!$sess_info->{session_ok}) {
        print $q->header(-status => '302 Found', -location => '../index.html');
        return;
    }

    my $id_paciente_pre = $q->param('id') || '';
    my $fecha_dia       = $q->param('fecha') || strftime("%Y-%m-%d", localtime);

    my $usuario   = $sess_info->{usuario};
    my $role      = $sess_info->{role};
    my $id_medico = $sess_info->{id_medico};

    # Renderizado de Header
    render_header(
        usuario     => $usuario,
        titulo      => "Agenda Mensual - $usuario",
        ruta_logout => '../auth/cerrar_sesion.pl',
        role        => $role,
        id_medico   => $id_medico
    );

    my $fecha_hoy  = strftime("%Y-%m-%d", localtime);
    my $fecha_prev = calcular_fecha_anterior($fecha_dia); 
    my $fecha_next = calcular_fecha_siguiente($fecha_dia);

    # Barra de navegación superior fija
    render_navfixgo(
        id_paciente => $id_paciente_pre,
        fecha_dia   => $fecha_dia,
        fecha_prev  => $fecha_prev,
        fecha_next  => $fecha_next,
        fecha_hoy   => $fecha_hoy,
        vista       => 'mes' 
    );

    # Contenido principal del calendario
    render_vista_mensual($id_medico, $fecha_dia);

    render_footer();
}

sub render_vista_mensual {
    my ($id_medico, $fecha_dia) = @_;

    my $tp = Time::Piece->strptime($fecha_dia, "%Y-%m-%d");
    my $ini_mes = Time::Piece->strptime($tp->strftime("%Y-%m-01"), "%Y-%m-%d");
    
    # Cálculo inteligente del grid (Lunes a Domingo)
    my $wday_inicio   = $ini_mes->day_of_week; 
    my $offset_inicio = ($wday_inicio == 0) ? 6 : ($wday_inicio - 1);
    my $ini_grid      = $ini_mes - ($offset_inicio * ONE_DAY);
    my $fin_grid      = $ini_grid + (41 * ONE_DAY); 

    # Cargar citas y pacientes
    my $pacientes = cargar_pacientes_hash(); 
    my %citas_por_dia;
    my $registros_citas = leer_tabla("../dat/citas.dat", '\|');

    foreach my $f (@$registros_citas) {
        next unless @$f >= 9;
        next unless ($f->[1] eq $id_medico); 
        push @{ $citas_por_dia{$f->[3]} }, { 
            id_cita    => $f->[0],
            nombre_pac => $pacientes->{$f->[2]} // "Paciente " . $f->[2],
            hora_ini   => $f->[4],
            estado     => $f->[8] || 'Programada'
        };
    }

    print qq{
    <link rel="stylesheet" href="/css/agenda.css">
    <div class="container-fluid px-md-4 mb-5">
        <div class="calendar-main-container shadow-sm mt-3">
            
            <div class="p-3 bg-white border-bottom">
                <h4 class="text-capitalize m-0 fw-bold text-primary">
                    <i class="bi bi-calendar3 me-2"></i>} . $tp->strftime("%B %Y") . qq{
                </h4>
            </div>

            <div class="calendar-grid-header bg-light d-none d-md-grid">
                <div class="day-name">Lun</div>
                <div class="day-name">Mar</div>
                <div class="day-name">Mié</div>
                <div class="day-name">Jue</div>
                <div class="day-name">Vie</div>
                <div class="day-name">Sáb</div>
                <div class="day-name">Dom</div>
            </div>

            <div class="calendar-grid-body">
    };

    # Renderizado de los 42 días
    for (my $d = $ini_grid; $d <= $fin_grid; $d += ONE_DAY) {
        my $f_curr    = $d->strftime("%Y-%m-%d");
        my $es_hoy    = ($f_curr eq strftime("%Y-%m-%d", localtime)) ? "dia-hoy"   : "";
        my $fuera_mes = ($d->mon != $tp->mon)                         ? "dia-fuera" : "";

        # Cada celda es un enlace a citas.pl
        print qq{
            <a href="agenda_main.pl?id=$id_medico&fecha=$f_curr&modo=vista" 
               class="calendar-dia $es_hoy $fuera_mes no-link-style">
                <div class="num-dia">
                    <span>} . $d->mday . qq{</span>
                </div>
                <div class="citas-wrapper">
        };

        if ($citas_por_dia{$f_curr}) {
            my @ordenadas = sort { $a->{hora_ini} cmp $b->{hora_ini} } @{ $citas_por_dia{$f_curr} };
            my $limite = 4;
            my $cont = 0;

            foreach my $c (@ordenadas) {
                $cont++;
                if ($cont > $limite) {
                    my $restantes = scalar(@ordenadas) - $limite;
                    print qq{<div class="more-citas">+ $restantes más</div>};
                    last;
                }
                my $st_class = lc($c->{estado});
                $st_class =~ s/\s+/-/g;

                print qq{
                    <div class="agenda-cita-chip chip-$st_class">
                        <span class="cita-hora">$c->{hora_ini}</span>
                        <span class="cita-paciente">$c->{nombre_pac}</span>
                    </div>
                };
            }
        }

        print qq{
                </div>
            </a>
        };
    }

    print qq{
            </div>
        </div>
    </div>
    };
}

1;
