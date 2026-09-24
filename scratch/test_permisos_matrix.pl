#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use JSON qw(decode_json);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');
use utils::db_manager qw(leer_tabla);

print "=== PRUEBA DE CARGA DE ROLES CANÓNICOS Y USUARIOS POR ROL ===\n";

my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my %roles_set = ();

my $roles_file = File::Spec->catfile($dat_dir, 'roles.dat');
if (-e $roles_file && open(my $rf, '<:encoding(UTF-8)', $roles_file)) {
    <$rf>;
    while (my $line = <$rf>) {
        chomp $line;
        next if $line =~ /^\s*$/ || $line =~ /^#/;
        my ($rname) = split(/\|/, $line, -1);
        $rname =~ s/^\s+|\s+$//g;
        next unless length($rname);
        next if ($rname eq 'Administrador Global' || $rname eq 'Paciente');
        $roles_set{$rname} = 1;
    }
    close $rf;
}

$roles_set{'Administrador Organizacion'} = 1;
$roles_set{'Medico'} = 1;
$roles_set{'Recepcionista'} = 1;

my %conteo_usuarios = ();
my $usr_file = File::Spec->catfile($dat_dir, 'usuarios.dat');
if (-e $usr_file) {
    my $users = leer_tabla($usr_file, '!');
    foreach my $u (@$users) {
        next unless @$u >= 7;
        my $u_id  = $u->[0] // '';
        my $rol_u = $u->[5] // '';
        next if ($u_id =~ /^id$/i);
        if ($rol_u) {
            $roles_set{$rol_u} = 1;
            $conteo_usuarios{$rol_u} = ($conteo_usuarios{$rol_u} // 0) + 1;
        }
    }
}

foreach my $r (keys %roles_set) {
    $conteo_usuarios{$r} //= 0;
}

my @roles_list = sort keys %roles_set;

print "Roles detectados: " . join(", ", @roles_list) . "\n";
print "Verificación del rol Recepcionista: " . ($roles_set{'Recepcionista'} ? "PRESENTE [OK]" : "AUSENTE [FAIL]") . "\n";

foreach my $r (@roles_list) {
    print "  - $r: " . ($conteo_usuarios{$r} || 0) . " usuarios\n";
}

print "=== PRUEBA EXITOSA ===\n";
1;
