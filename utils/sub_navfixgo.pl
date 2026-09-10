#!/usr/bin/perl
use cPanelUserConfig;
use utf8;
use strict;
use warnings;
use lib '.';
use JSON::PP;
use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);


sub render_navfixgo {
    my (%args) = @_;
    my $id_paciente = $args{id_paciente} // '';
    my $fecha_dia   = $args{fecha_dia}   // '';
    my $fecha_prev  = $args{fecha_prev}  // '';
    my $fecha_next  = $args{fecha_next}  // '';
    my $fecha_hoy   = $args{fecha_hoy}   // '';
    my $vista_activa = $args{vista}      // 'dia'; # Importante saber en qué vista estamos

    print qq{
<div class="agenda-header-fixed d-flex flex-column flex-md-row justify-content-between align-items-center gap-3 mb-3">

  <div class="d-flex align-items-center gap-2">
    <button type="button" class="btn btn-outline-secondary btn-sm" onclick="history.back()">
      <i class="bi bi-arrow-left"></i>
    </button>
    <h4 class="m-0">Agenda</h4>
  </div>

  <div class="d-flex align-items-center gap-2">
    <a href="?id=$id_paciente&fecha=$fecha_prev" class="btn btn-outline-primary btn-sm">
      <i class="bi bi-chevron-left"></i>
    </a>
    <form method="get" class="m-0 p-0">
      <input type="hidden" name="id" value="$id_paciente">
      <input type="date" name="fecha" value="$fecha_dia" class="form-control form-control-sm" onchange="this.form.submit()">
    </form>
    <a href="?id=$id_paciente&fecha=$fecha_next" class="btn btn-outline-primary btn-sm">
      <i class="bi bi-chevron-right"></i>
    </a>
    <a href="?id=$id_paciente&fecha=$fecha_hoy" class="btn btn-primary btn-sm">Hoy</a>
  </div>

  <div class="btn-group" role="group">
    <button type="button" 
            id="toggle-dia"
            class="btn btn-outline-primary btn-sm vista-toggle @{[$vista_activa eq 'dia' ? 'active' : '']}" 
            data-tipo="dia"
            data-listado="agenda_vista_lista.pl?vista=dia&id=$id_paciente&fecha=$fecha_dia&modo=listado"
            data-calendar="agenda_main.pl?id=$id_paciente&fecha=$fecha_dia&modo=vista">
      <i class="bi bi-list-ul"></i> <span class="d-none d-sm-inline">Día</span>
    </button>

    <button type="button" 
            id="toggle-semana"
            class="btn btn-outline-primary btn-sm vista-toggle @{[$vista_activa eq 'semana' ? 'active' : '']}" 
            data-tipo="semana"
            data-listado="agenda_vista_lista.pl?vista=semana&id=$id_paciente&fecha=$fecha_dia&modo=listado"
            data-calendar="agenda_vista_semanal.pl?vista=semana&id=$id_paciente&fecha=$fecha_dia&modo=vista">
      <i class="bi bi-list-ul"></i> <span class="d-none d-sm-inline">Semana</span>
    </button>

    <button type="button" 
            id="toggle-mes"
            class="btn btn-outline-primary btn-sm vista-toggle @{[$vista_activa eq 'mes' ? 'active' : '']}" 
            data-tipo="mes"
            data-listado="agenda_vista_lista.pl?vista=mes&id=$id_paciente&fecha=$fecha_dia&modo=listado"
            data-calendar="agenda_vista_mensual.pl?vista=mes&id=$id_paciente&fecha=$fecha_dia&modo=vista">
      <i class="bi bi-list-ul"></i> <span class="d-none d-sm-inline">Mes</span>
    </button>
  </div>
</div>

<script>
  (function() {
    const urlParams = new URLSearchParams(window.location.search);
    const modoActual = urlParams.get('modo') || 'listado';

    document.querySelectorAll('.vista-toggle').forEach(btn => {
      const icono = btn.querySelector('i');
      
      // 1. Configurar la apariencia inicial basándonos en el modo actual
      if (modoActual === 'vista') {
        icono.className = 'bi bi-calendar-event';
        btn.dataset.target = 'listado'; // Si estamos en vista, el clic nos lleva a listado
      } else {
        icono.className = 'bi bi-list-ul';
        btn.dataset.target = 'calendar'; // Si estamos en listado, el clic nos lleva a vista
      }

      // 2. Evento Click corregido
      btn.addEventListener('click', () => {
        // Si el botón es el activo (la vista actual), conmuta el modo
        if (btn.classList.contains('active')) {
            if (btn.dataset.target === 'listado') {
                window.location.href = btn.dataset.listado;
            } else {
                window.location.href = btn.dataset.calendar;
            }
        } else {
            // Si el botón NO es el activo (ej. estoy en día y clico semana), 
            // me lleva a esa vista manteniendo el modo actual
            const destino = (modoActual === 'vista') ? btn.dataset.calendar : btn.dataset.listado;
            window.location.href = destino;
        }
      });
    });
  })();
</script>
    };
}


# Cargar pacientes en hash id_paciente -> nombre
sub cargar_pacientes {
    my %pacientes;
    my $file = "dat/pacientes.dat";
    if (-e $file) {
        open(my $fh, '<:encoding(UTF-8)', $file) or warn "No se pudo abrir $file: $!";
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my ($id_paciente, $id_medico, $nombre, $rfc, $curp, $correo) = split(/!/, $line);
            $pacientes{$id_paciente} = $nombre;
        }
        close($fh);
    }
    return \%pacientes;
}
1;