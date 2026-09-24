#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use Digest::SHA qw(sha256_hex);
use FindBin;
use File::Spec;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla guardar_registro);

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Global') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $nombre = $q->param('nombre') // '';
my $correo = lc($q->param('correo') // '');
my $clave  = $q->param('clave')  // '';

$nombre =~ s/^\s+|\s+$//g;
$correo =~ s/^\s+|\s+$//g;
$clave  =~ s/^\s+|\s+$//g;

if (!$nombre || !$correo || !$clave) {
    print encode_json({ status => 'error', message => 'Todos los campos son obligatorios.' });
    exit;
}

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');

# Validar que el correo no exista
my $regs = leer_tabla($archivo_usuarios, '!');
if ($regs) {
    foreach my $r (@$regs) {
        if (lc($r->[2] // '') eq $correo) {
            print encode_json({ status => 'error', message => 'El correo electrónico ya está registrado en OSPulso.' });
            exit;
        }
    }
}

# Crear el registro. EXTRA es '0:0'
# ID!NOMBRE!CORREO!CLAVE!ACTIVO!ROL!EXTRA
my $id_nuevo = int(rand(999999999)) + 100000000; # Generar ID aleatorio tipo 9 digitos
my $hash = sha256_hex($clave);
my $registro = join("!", $id_nuevo, $nombre, $correo, $hash, 1, 'Ejecutivo Ventas', '0:0');

eval {
    open(my $fh, '>>:utf8', $archivo_usuarios) or die $!;
    flock($fh, 2);
    print $fh "$registro\n";
    close($fh);
};

if ($@) {
    print encode_json({ status => 'error', message => 'No se pudo guardar el registro: ' . $@ });
    exit;
}

print encode_json({ status => 'success' });
1;
