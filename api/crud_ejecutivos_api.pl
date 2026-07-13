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
use utils::db_manager qw(leer_tabla actualizar_archivo guardar_registro);

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

unless ($sd->{session_ok} && $sd->{role} eq 'Administrador Global') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $action = $q->param('action') // '';
my $id     = $q->param('id') // '';
my $nombre = $q->param('nombre') // '';
my $correo = lc($q->param('correo') // '');
my $clave  = $q->param('clave')  // '';

$action =~ s/^\s+|\s+$//g;
$id     =~ s/^\s+|\s+$//g;
$nombre =~ s/^\s+|\s+$//g;
$correo =~ s/^\s+|\s+$//g;
$clave  =~ s/^\s+|\s+$//g;

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '!');

if ($action eq 'create') {
    if (!$nombre || !$correo || !$clave) {
        print encode_json({ status => 'error', message => 'Todos los campos son obligatorios.' });
        exit;
    }
    
    # Validar que el correo no exista
    if ($regs) {
        foreach my $r (@$regs) {
            if (lc($r->[2] // '') eq $correo) {
                print encode_json({ status => 'error', message => 'El correo electrónico ya está registrado.' });
                exit;
            }
        }
    }
    
    my $id_nuevo = int(rand(999999999)) + 100000000;
    my $hash = sha256_hex($clave);
    my $registro = join("!", $id_nuevo, $nombre, $correo, $hash, 1, 'Ejecutivo Ventas', '0:0');
    
    eval { guardar_registro($archivo_usuarios, $registro) };
    if ($@) {
        print encode_json({ status => 'error', message => 'No se pudo guardar el registro: ' . $@ });
    } else {
        print encode_json({ status => 'success', id => $id_nuevo });
    }
    exit;
}
elsif ($action eq 'edit') {
    if (!$id || !$nombre || !$correo) {
        print encode_json({ status => 'error', message => 'ID, Nombre y Correo son obligatorios.' });
        exit;
    }
    
    my @nuevas_lineas;
    my $encontrado = 0;
    
    # Validar duplicados
    if ($regs) {
        foreach my $r (@$regs) {
            if ($r->[0] ne $id && lc($r->[2] // '') eq $correo) {
                print encode_json({ status => 'error', message => 'El correo ya está en uso por otro usuario.' });
                exit;
            }
        }
    }
    
    if ($regs) {
        foreach my $r (@$regs) {
            next if @$r < 7;
            if ($r->[0] eq $id && $r->[5] eq 'Ejecutivo Ventas') {
                $r->[1] = $nombre;
                $r->[2] = $correo;
                if ($clave ne '') {
                    $r->[3] = sha256_hex($clave);
                }
                $encontrado = 1;
            }
            push @nuevas_lineas, join("!", @$r);
        }
    }
    
    if (!$encontrado) {
        print encode_json({ status => 'error', message => 'Ejecutivo no encontrado.' });
        exit;
    }
    
    eval {
        my $header = "id!nombre!correo!clave!activo!rol!ID_negocio";
        actualizar_archivo($archivo_usuarios, $header, \@nuevas_lineas);
    };
    
    if ($@) {
        print encode_json({ status => 'error', message => 'Error al actualizar: ' . $@ });
    } else {
        print encode_json({ status => 'success' });
    }
    exit;
}
elsif ($action eq 'remove') {
    if (!$id) {
        print encode_json({ status => 'error', message => 'ID obligatorio.' });
        exit;
    }
    
    my @nuevas_lineas;
    my $encontrado = 0;
    
    if ($regs) {
        foreach my $r (@$regs) {
            next if @$r < 7;
            if ($r->[0] eq $id && $r->[5] eq 'Ejecutivo Ventas') {
                $r->[4] = '0'; # Soft delete
                $encontrado = 1;
            }
            push @nuevas_lineas, join("!", @$r);
        }
    }
    
    if (!$encontrado) {
        print encode_json({ status => 'error', message => 'Ejecutivo no encontrado.' });
        exit;
    }
    
    eval {
        my $header = "id!nombre!correo!clave!activo!rol!ID_negocio";
        actualizar_archivo($archivo_usuarios, $header, \@nuevas_lineas);
    };
    
    if ($@) {
        print encode_json({ status => 'error', message => 'Error al borrar: ' . $@ });
    } else {
        print encode_json({ status => 'success' });
    }
    exit;
}
elsif ($action eq 'reactivate') {
    if (!$id) {
        print encode_json({ status => 'error', message => 'ID obligatorio.' });
        exit;
    }
    
    my @nuevas_lineas;
    my $encontrado = 0;
    
    if ($regs) {
        foreach my $r (@$regs) {
            next if @$r < 7;
            if ($r->[0] eq $id && $r->[5] eq 'Ejecutivo Ventas') {
                $r->[4] = '1'; # Reactivate
                $encontrado = 1;
            }
            push @nuevas_lineas, join("!", @$r);
        }
    }
    
    if (!$encontrado) {
        print encode_json({ status => 'error', message => 'Ejecutivo no encontrado.' });
        exit;
    }
    
    eval {
        my $header = "id!nombre!correo!clave!activo!rol!ID_negocio";
        actualizar_archivo($archivo_usuarios, $header, \@nuevas_lineas);
    };
    
    if ($@) {
        print encode_json({ status => 'error', message => 'Error al reactivar: ' . $@ });
    } else {
        print encode_json({ status => 'success' });
    }
    exit;
}
elsif ($action eq 'delete_permanent') {
    if (!$id) {
        print encode_json({ status => 'error', message => 'ID obligatorio.' });
        exit;
    }
    
    my @nuevas_lineas;
    my $encontrado = 0;
    
    if ($regs) {
        foreach my $r (@$regs) {
            next if @$r < 7;
            if ($r->[0] eq $id && $r->[5] eq 'Ejecutivo Ventas') {
                $encontrado = 1;
                # No push to nuevas_lineas (eliminar físicamente)
            } else {
                push @nuevas_lineas, join("!", @$r);
            }
        }
    }
    
    if (!$encontrado) {
        print encode_json({ status => 'error', message => 'Ejecutivo no encontrado.' });
        exit;
    }
    
    eval {
        my $header = "id!nombre!correo!clave!activo!rol!ID_negocio";
        actualizar_archivo($archivo_usuarios, $header, \@nuevas_lineas);
    };
    
    if ($@) {
        print encode_json({ status => 'error', message => 'Error al eliminar permanentemente: ' . $@ });
    } else {
        print encode_json({ status => 'success' });
    }
    exit;
}
else {
    print encode_json({ status => 'error', message => 'Acción no válida.' });
    exit;
}
1;
