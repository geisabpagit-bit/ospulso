#!/usr/bin/perl
use cPanelUserConfig;

# sub_agenda_utils.pl
use strict;
use warnings;
use POSIX qw(strftime);
use Time::Local qw(timelocal);
use utils::db_manager qw(leer_tabla);

# Convierte HH:MM a minutos
sub minutos {
    my ($h) = @_;
    my ($hh, $mm) = split(':', $h);
    return $hh * 60 + $mm;
}

# Calcula altura en píxeles de un bloque de cita
sub calcular_altura_px {
    my ($ini, $fin, $alto_slot) = @_;
    my $duracion = minutos($fin) - minutos($ini);
    my $slots = $duracion / 30; # intervalo base
    return $slots * $alto_slot;
}

# Fecha anterior
sub calcular_fecha_anterior {
  my ($f) = @_;
  my ($y,$m,$d) = split('-', $f);
  my $t = timelocal(0,0,0,$d,$m-1,$y) - 86400;
  return strftime("%Y-%m-%d", localtime($t));
}

# Fecha siguiente
sub calcular_fecha_siguiente {
  my ($f) = @_;
  my ($y,$m,$d) = split('-', $f);
  my $t = timelocal(0,0,0,$d,$m-1,$y) + 86400;
  return strftime("%Y-%m-%d", localtime($t));
}

# Devuelve hash id_paciente => nombre de paciente para las agendas
sub cargar_pacientes_hash {
    my %pacientes;
    my $registros = leer_tabla("dat/pacientes.dat", '\|');
    foreach my $f (@$registros) {
        next unless @$f > 2;
        $pacientes{$f->[0]} = $f->[2];
    }
    return \%pacientes;
}

1;
