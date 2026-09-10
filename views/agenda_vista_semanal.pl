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

# Constante para un día en segundos
use constant ONE_DAY => 86400;

# Funciones auxiliares de fechas
sub calcular_fecha_anterior {
    my ($fecha) = @_;
    my $tp = Time::Piece->strptime($fecha, "%Y-%m-%d");
    my $prev = $tp - ONE_DAY;
    return $prev->strftime("%Y-%m-%d");
}

sub calcular_fecha_siguiente {
    my ($fecha) = @_;
    my $tp = Time::Piece->strptime($fecha, "%Y-%m-%d");
    my $next = $tp + ONE_DAY;
    return $next->strftime("%Y-%m-%d");
}

sub main {
    my $q = CGI->new;
    my $sess_info = check_session($q);
    my $id_paciente_pre = $q->param('id') || '';
    my $fecha_dia = $q->param('fecha') || strftime("%Y-%m-%d", localtime);

    if (!$sess_info->{session_ok}) {
        print $q->header(-status => '302 Found', -location => '../index.html');
        return;
    }

    my $usuario   = $sess_info->{usuario};
    my $role      = $sess_info->{role};
    my $id_medico = $sess_info->{id_medico};

    render_header(
        usuario     => $usuario,
        titulo      => "Vista Semanal - $usuario",
        ruta_logout => '../auth/cerrar_sesion.pl',
        role        => $role,
        skip_header => 0,
        id_medico   => $id_medico
    );

    my $fecha_hoy  = strftime("%Y-%m-%d", localtime);
    my $fecha_prev = calcular_fecha_anterior($fecha_dia);
    my $fecha_next = calcular_fecha_siguiente($fecha_dia);

    render_navfixgo(
        id_paciente => $id_paciente_pre,
        fecha_dia   => $fecha_dia,
        fecha_prev  => $fecha_prev,
        fecha_next  => $fecha_next,
        fecha_hoy   => $fecha_hoy,
        vista       => 'semana'
    );

    render_vista_semanal($id_medico, $fecha_dia);
    render_footer();
}

sub render_vista_semanal {
    my ($id_medico, $fecha_dia) = @_;

    my $tp = Time::Piece->strptime($fecha_dia, "%Y-%m-%d");

    # Calcular lunes y domingo de la semana
    my $ini = $tp - ($tp->_wday - 1) * ONE_DAY;   # lunes
    my $fin = $ini + 6 * ONE_DAY;                 # domingo

    print qq{
    <link rel="stylesheet" href="../css/agenda.css">
    <div class="container-fluid mt-3">
      <h4>Citas de la semana</h4>
      <div class="row">
    };

    # Cargar pacientes
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

    # Renderizar cada día de la semana
    for my $i (0..6) {
        my $fecha = ($ini + $i * ONE_DAY)->strftime("%Y-%m-%d");
        print qq{
          <div class="col-md-3 mb-3">
            <div class="card">
              <div class="card-header d-flex justify-content-between align-items-center">
                <span>$fecha</span>
                <a href="agenda_main.pl?id=$id_medico&fecha=$fecha&modo=vista" 
                   class="btn btn-sm btn-outline-success no-link-style" 
                   title="Agregar cita">
                   <i class="bi bi-plus-circle"></i>
                </a>
              </div>
              <div class="card-body">
        };

        if ($citas_por_dia{$fecha}) {
            my @ordenadas = sort { $a->{hora_ini} cmp $b->{hora_ini} } @{ $citas_por_dia{$fecha} };
            foreach my $c (@ordenadas) {
                my $estado_class = lc($c->{estado});
                print qq{
                  <div class="agenda-cita-estado-$estado_class mb-2 p-2 border rounded">
                    <strong>$c->{hora_ini} - $c->{hora_fin}</strong><br>
                    Paciente: $c->{nombre_pac}<br>
                    Motivo: $c->{motivo}<br>
                    Estado: $c->{estado}
                  </div>
                };
            }
        } else {
            # Celda disponible → enlace a citas.pl
            print qq{
              <a href="citas.pl?id=$id_medico&fecha=$fecha&modo=vista" 
                 class="no-link-style d-block p-2 border rounded text-center text-success fw-bold">
                Disponible
              </a>
            };
        }

        print qq{
              </div>
            </div>
          </div>
        };
    }

    print qq{
      </div>
    </div>
    };
}

main();
