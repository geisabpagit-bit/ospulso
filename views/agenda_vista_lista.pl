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
use lib '.';
use JSON;
use JSON;
use POSIX qw(strftime);
use Time::Local qw(timelocal);
use utils::db_manager qw(leer_tabla);

require '../auth/check_session.pl';
require '../utils/sub_header.pl';
require '../utils/sub_footer.pl';
require '../utils/sub_navfixgo.pl';
require '../api/sub_agenda_utils.pl';

sub main {
    my $q = CGI->new;
    my $sess_info = check_session($q);

    if (!$sess_info->{session_ok}) {
        print $q->header(-status => '302 Found', -location => '../index.html');
        return;
    }

    my $usuario   = $sess_info->{usuario};
    my $role      = $sess_info->{role};
    my $id_medico = $sess_info->{id_medico};

    my $vista     = $q->param('vista') || 'dia';   # dia | semana | mes
    my $id_paciente = $q->param('id') || '';
    my $fecha_act = $q->param('fecha') || strftime("%Y-%m-%d", localtime);

    my $fecha_hoy  = strftime("%Y-%m-%d", localtime);
    my $fecha_prev = calcular_fecha_anterior($fecha_act);
    my $fecha_next = calcular_fecha_siguiente($fecha_act);

    render_header(
        usuario     => $usuario,
        titulo      => "Vista Listado - $usuario",
        ruta_logout => '../auth/cerrar_sesion.pl',
        role        => $role,
        skip_header => 0,
        id_medico   => $id_medico
    );

    # Bloque de navegación de fechas
    render_navfixgo(
        id_paciente => $id_paciente,
        fecha_dia   => $fecha_act,
        fecha_prev  => $fecha_prev,
        fecha_next  => $fecha_next,
        fecha_hoy   => $fecha_hoy,
        vista       => $vista
    );

    # Render listado de citas
    render_vista_list($vista, $fecha_act, $id_medico);

    render_footer();
}

sub render_vista_list {
    my ($vista, $fecha_act, $id_medico) = @_;

    my $tp = Time::Piece->strptime($fecha_act, "%Y-%m-%d");

    # Calcular rango de fechas según vista
    my ($ini, $fin, $titulo);
    if ($vista eq 'dia') {
        $ini = $tp; $fin = $tp;
        $titulo = "Citas del día " . $tp->strftime("%d/%m/%Y");
    }
    elsif ($vista eq 'semana') {
        $ini = $tp - ($tp->_wday - 1) * 86400;   # lunes
        $fin = $ini + 6 * 86400;                 # domingo
        $titulo = "Citas de la Semana del " . $ini->strftime("%d/%m/%Y") .
                  " al " . $fin->strftime("%d/%m/%Y");
    }
    elsif ($vista eq 'mes') {
        $ini = Time::Piece->strptime($tp->strftime("%Y-%m-01"), "%Y-%m-%d");
        my $last_day = $ini->month_last_day;
        $fin = Time::Piece->strptime($tp->strftime("%Y-%m-$last_day"), "%Y-%m-%d");
        $titulo = "Citas de " .$tp->strftime("%B %Y"); # Ej: Diciembre 2025
    }

    print qq{
    <div class="agenda-listado">
      <h4>$titulo</h4>
    };

    my $pacientes = cargar_pacientes_hash();
    my %citas_por_dia;
    my $registros_citas = leer_tabla("../dat/citas.dat", '\|');

    foreach my $c (@$registros_citas) {
        next unless @$c >= 9;
        my ($id_cita, $id_medico_reg, $id_paciente, $fecha, $hora_ini, $hora_fin, $motivo, $notas, $estado) = @$c;
        next unless ($id_medico_reg eq $id_medico);

        my $tp_cita = eval { Time::Piece->strptime($fecha, "%Y-%m-%d") };
        next if $@;

        if ($tp_cita >= $ini && $tp_cita <= $fin) {
            push @{ $citas_por_dia{$fecha} }, {
                id_cita    => $id_cita,
                nombre_pac => $pacientes->{$id_paciente} // "Paciente " . $id_paciente,
                fecha      => $fecha,
                hora_ini   => $hora_ini,
                hora_fin   => $hora_fin,
                motivo     => $motivo,
                notas      => $notas,
                estado     => $estado
            };
        }
    }
print qq{<link rel="stylesheet" href="/css/agenda.css">};
        # Renderizar agrupado por día y ordenado por hora
        foreach my $fecha (sort keys %citas_por_dia) {
            print qq{<div class="agenda-list-dia">$fecha</div><ul class="agenda-list-group">};
            my @ordenadas = sort { $a->{hora_ini} cmp $b->{hora_ini} } @{ $citas_por_dia{$fecha} };

            foreach my $c (@ordenadas) {
                my $estado_class = lc($c->{estado}); # programada, confirmada, cancelada, realizada
                print qq{
                
                  <li class="agenda-list-item $estado_class">
                    <div class="agenda-list-info">
                      <strong>$c->{hora_ini} - $c->{hora_fin}</strong>
                      Paciente: $c->{nombre_pac} |
                      Motivo: $c->{motivo} |
                      Estado: $c->{estado}
                    </div>
                    <div class="agenda-list-actions">
                      <button class="btn btn-sm btn-outline-primary" onclick="editarCita('$c->{id_cita}')"><i class="bi bi-pencil"></i></button>
                      <button class="btn btn-sm btn-outline-danger" onclick="eliminarCita('$c->{id_cita}')"><i class="bi bi-trash"></i></button>
                    </div>
                  </li>
                };
            }
            print qq{</ul>};
        }

    print qq{</div>};
}


main();
