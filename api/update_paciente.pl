#!/usr/bin/perl

use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use lib '.';
use utils::db_manager qw(leer_tabla actualizar_archivo);

my $q = CGI->new;
binmode(STDOUT, ":utf8");
print $q->header(-type => "application/json", -charset => "utf-8");

my $id = $q->param('id_paciente') || '';
unless ($id) {
    print JSON::PP->new->utf8(1)->encode({status => 'error', message => "ID de paciente no proporcionado."});
    exit;
}

my $archivo = '../dat/pacientes.dat';
my $registros = leer_tabla($archivo, '\|');
my @nuevos;
my $actualizado = 0;

foreach my $f (@$registros) {
    if (@$f > 1 && $f->[0] eq $id) {
        $f->[2]  = $q->param('nombre') // $f->[2];
        $f->[3]  = uc($q->param('rfc') // $f->[3]);
        $f->[4]  = uc($q->param('curp') // $f->[4]);
        $f->[5]  = lc($q->param('email') // $f->[5]);
        $f->[6]  = $q->param('f_nac') // $f->[6];
        $f->[7]  = $q->param('sexo') // $f->[7];
        $f->[8]  = $q->param('ocupacion') // $f->[8];
        $f->[9]  = $q->param('e_civil') // $f->[9];
        $f->[10] = $q->param('nacionalidad') // $f->[10];
        $f->[11] = $q->param('sangre') // $f->[11];
        $f->[12] = $q->param('telefono') // $f->[12];
        
        $actualizado = 1;
    }
    push @nuevos, join("|", @$f);
}

if ($actualizado) {
    actualizar_archivo($archivo, "ID_PACIENTE|ID_MEDICO|NOMBRE|RFC|CURP|CORREO|FECHA_NAC|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO", \@nuevos);
    print JSON::PP->new->utf8(1)->encode({status => 'success', message => "Expediente sincronizado correctamente."});
} else {
    print JSON::PP->new->utf8(1)->encode({status => 'error', message => "Registro $id no encontrado."});
}
exit;
