#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla actualizar_archivo);

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Organizacion') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $id_org_matriz = $sd->{id_empresa};
my $id_usuario    = $q->param('id_usuario') // '';

$id_usuario =~ s/^\s+|\s+$//g;

if (!$id_usuario) {
    print encode_json({ status => 'error', message => 'ID de usuario es obligatorio.' });
    exit;
}

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
my @nuevas_lineas;
my $encontrado = 0;

if ($regs_usuarios) {
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        if ($r->[0] eq $id_usuario) {
            my $extra = $r->[6];
            my ($org_id, $suc_id) = split(/:/, $extra);
            
            if ($org_id ne $id_org_matriz) {
                print encode_json({ status => 'error', message => 'No tienes permiso para dar de baja este usuario.' });
                exit;
            }

            # Soft Delete
            $r->[4] = '0';
            $encontrado = 1;
        }
        push @nuevas_lineas, join("!", @$r);
    }
}

if (!$encontrado) {
    print encode_json({ status => 'error', message => 'Usuario no encontrado.' });
    exit;
}

eval {
    my $header = "id!nombre!correo!clave!activo!rol!ID_negocio";
    actualizar_archivo($archivo_usuarios, $header, \@nuevas_lineas);
};

if ($@) {
    print encode_json({ status => 'error', message => 'Error al dar de baja al usuario: ' . $@ });
    exit;
}

print encode_json({ status => 'success', message => 'Usuario dado de baja correctamente.' });
1;
