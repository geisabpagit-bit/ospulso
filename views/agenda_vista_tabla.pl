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
        titulo      => "Vista Tabla - $usuario",
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
        vista       => 'tabla'
    );

    render_vista_tabla($q, $sess_info, $id_paciente_pre, $id_medico, $fecha_dia);

    render_footer();
}

sub render_vista_tabla {
    my ($q, $sess_info, $id_paciente_pre, $id_medico, $fecha_dia) = @_;

    print qq{
    <script src="/js/citas_actions.js"></script>

    <div class="container-fluid mt-3">
      <h4>Agenda en Vista Tabla</h4>
      <table id="tabla_citas" class="table table-striped table-bordered nowrap" style="width:100%">
        <thead class="table-light">
          <tr>
            <th>ID</th><th>Paciente</th><th>Fecha</th><th>Hora Inicio</th>
            <th>Hora Fin</th><th>Motivo</th><th>Notas</th><th>Estado</th><th>Acciones</th>
          </tr>
        </thead>
        <tbody>
    };

    my $pacientes = cargar_pacientes_hash();
    my $registros_citas = leer_tabla("../dat/citas.dat", '\|');

    foreach my $c (@$registros_citas) {
        next unless @$c >= 9;
        my ($id_cita, $id_medico_reg, $id_paciente, $fecha, $hora_ini, $hora_fin, $motivo, $notas, $estado) = @$c;
        next unless ($id_medico_reg eq $id_medico);
        next unless ($fecha eq $fecha_dia);

        my $nombre_paciente = $pacientes->{$id_paciente} // "Paciente " . $id_paciente;

        print qq{
          <tr>
            <td>$id_cita</td><td>$nombre_paciente</td><td>$fecha</td>
            <td>$hora_ini</td><td>$hora_fin</td><td>$motivo</td>
            <td>$notas</td><td>$estado</td>
            <td>
              <button class="btn btn-sm btn-outline-danger"
                      onclick="event.stopPropagation(); citasActions.eliminar('$id_cita');">
                <i class="bi bi-trash"></i>
              </button>

              <button class="btn btn-sm btn-outline-primary"
                      onclick="event.stopPropagation(); citasActions.editar('$id_cita');">
                <i class="bi bi-pencil"></i>
              </button>
            </td>
          </tr>
        };
    }

    print qq{
        </tbody>
      </table>
    </div>
    <script src="/js/agenda_tabla.js"></script>
    };
}

main();
