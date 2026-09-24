#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";
use CGI::Session;

binmode STDOUT, ":utf8";

print "=== EJECUTANDO HARD RESET OFICIAL DE BASE DE DATOS ===\n";

# Crear sesión temporal de Administrador Global
my $session_dir = File::Spec->catdir($FindBin::Bin, '..', 'auth', 'sessions');
unless (-d $session_dir) {
    mkdir $session_dir or die "No se pudo crear $session_dir: $!";
}

my $session_admin = CGI::Session->new(undef, undef, { Directory => $session_dir });
$session_admin->param('uid', 'admin@ospulso.com');
$session_admin->param('usuario', 'Administrador Global');
$session_admin->param('role', 'Administrador Global');
$session_admin->flush();
my $sid_admin = $session_admin->id();

$ENV{REQUEST_METHOD} = 'GET';
$ENV{HTTP_COOKIE} = "CGISESSID=$sid_admin";

my $res = `perl api/hard_reset_db_api.pl`;
print "Respuesta de hard_reset_db_api.pl:\n$res\n";

# Limpiar sesión temporal
unlink File::Spec->catfile($session_dir, "cgisess_$sid_admin");

print "=== HARD RESET COMPLETADO ===\n";
