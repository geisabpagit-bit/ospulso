#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON::PP qw(encode_json);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q} || CGI->new;

print $q->header(-type => 'application/json', -charset => 'UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ ok => 0, error => 'Sesión no válida o expirada.' });
    exit;
}

my $nuevo_rol = $q->param('nuevo_rol') || $q->url_param('nuevo_rol') || '';
$nuevo_rol =~ s/^\s+|\s+$//g;

unless ($nuevo_rol) {
    print encode_json({ ok => 0, error => 'Parámetro nuevo_rol requerido.' });
    exit;
}

my $session = $sd->{session};
my $roles_disponibles = $session->param('roles_disponibles') // '';

# Fallback de seguridad: verificar en usuarios.dat si roles_disponibles está vacío
if (!$roles_disponibles) {
    my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    my $regs = leer_tabla($archivo_usuarios, '!');
    if ($regs) {
        foreach my $u (@$regs) {
            if ($u->[0] eq ($sd->{id_medico} || '') || lc($u->[2] // '') eq lc($sd->{uid} || '')) {
                my $r_raw = $u->[5] // '';
                my $esp   = $u->[7] // '0';
                if ($r_raw =~ /Administrador/ && $esp ne '0' && $esp ne '') {
                    $r_raw .= ',Medico' unless $r_raw =~ /Medico/;
                }
                $roles_disponibles = $r_raw;
                last;
            }
        }
    }
}

my @permitidos = split /,/, $roles_disponibles;
my %permitidos_map = map { $_ => 1 } @permitidos;

if (!$permitidos_map{$nuevo_rol}) {
    print encode_json({ ok => 0, error => "El rol solicitado '$nuevo_rol' no está autorizado para este perfil." });
    exit;
}

# Actualizar el rol activo en la sesión
$session->param('role', $nuevo_rol);
$session->flush();

# Ruta sugerida según el rol de destino
my $redirect = ($nuevo_rol eq 'Medico') ? '../views/agenda_main.pl' : '../views/inicial.pl';

print encode_json({
    ok        => 1,
    nuevo_rol => $nuevo_rol,
    redirect  => $redirect,
    mensaje   => "Perfil conmutado exitosamente a $nuevo_rol"
});
exit;
