#!/usr/bin/perl
use cPanelUserConfig;
use utf8;
use strict;
use warnings;
use lib '.';
use JSON::PP;

sub render_navviews {
    my (%args) = @_;
    my $id_paciente = $args{id_paciente} // '';
    my $fecha_dia   = $args{fecha_dia}   // '';

    print qq{
    <!-- DERECHA: Vistas con toggle -->
    <div class="btn-group" role="group">

      <!-- Día -->
      <button type="button"
              class="btn btn-sm vista-toggle"
              data-listado="agenda_vista_lista.pl?vista=dia&id=$id_paciente&fecha=$fecha_dia"
              data-vista="agenda_main.pl?vista=dia&id=$id_paciente&fecha=$fecha_dia"
              data-state="listado">
        <i class="bi bi-list-ul"></i>
        <span class="d-none d-sm-inline">Día</span>
      </button>

      <!-- Semana -->
      <button type="button"
              class="btn btn-sm vista-toggle"
              data-listado="agenda_vista_lista.pl?vista=semana&id=$id_paciente&fecha=$fecha_dia"
              data-vista="agenda_vista_semanal.pl?vista=semana&id=$id_paciente&fecha=$fecha_dia"
              data-state="listado">
        <i class="bi bi-list-ul"></i>
        <span class="d-none d-sm-inline">Semana</span>
      </button>

      <!-- Mes -->
      <button type="button"
              class="btn btn-sm vista-toggle"
              data-listado="agenda_vista_list.pl?vista=mes&id=$id_paciente&fecha=$fecha_dia"
              data-vista="agenda_vista_mensual.pl?vista=mes&id=$id_paciente&fecha=$fecha_dia"
              data-state="listado">
        <i class="bi bi-list-ul"></i>
        <span class="d-none d-sm-inline">Mes</span>
      </button>

    </div>

    <script>
      // Script para alternar entre listado y vista con iconos dinámicos
      document.querySelectorAll('.vista-toggle').forEach(btn => {
        btn.addEventListener('click', () => {
          if (btn.dataset.state === 'listado') {
            window.location.href = btn.dataset.listado;
            btn.dataset.state = 'vista';
            btn.querySelector('i').className = 'bi bi-calendar-event'; // icono vista
          } else {
            window.location.href = btn.dataset.vista;
            btn.dataset.state = 'listado';
            btn.querySelector('i').className = 'bi bi-list-ul'; // icono listado
          }
        });
      });
    </script>
    };
}
1;
