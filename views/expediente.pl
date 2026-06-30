#!/usr/bin/perl
use cPanelUserConfig;
use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use CGI::Session;
use strict;
use warnings;
use Encode qw(decode);
use lib '..';

require '../utils/sub_header.pl';
require '../utils/sub_footer.pl';
require 'render_expediente_clinico.pl';

my $q = CGI->new;

print $q->header('text/html; charset=UTF-8');


my $id = $q->param('id') || '';
my $archivo = '../dat/pacientes.dat';
my %datos;

if ($id && -e $archivo) {
  open(my $fh, $archivo);
  my @lineas = <$fh>;
  close($fh);

  for (my $i = 1; $i < @lineas; $i++) {
    my $linea = $lineas[$i];
    chomp $linea;
    my @campos = split /!/, $linea;
    my ($pid, $nombre, $rfc, $curp, $correo) = @campos;

    if ($pid eq $id) {
      %datos = (
        nombre => $nombre,
        curp   => $curp,
        correo => $correo
      );
      last;
    }
  }
}

if (%datos) {
  render_header(
    usuario     => 'Clínica Dental',
    titulo      => "Expediente de $datos{nombre}",
    ruta_logout => '../auth/cerrar_sesion.pl'
  );

  render_expediente_clinico(%datos);
  render_footer();
} 
1;