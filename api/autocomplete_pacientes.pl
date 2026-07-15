#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std); # Eliminamos :utf8 global para evitar conflictos con JSON
use CGI;
use JSON::PP;
use FindBin;
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";
use utils::db_manager qw(leer_tabla);

require '../auth/check_session.pl';
my $sd = check_session();
unless ($sd->{session_ok}) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode([]);
    exit;
}

my $q = $sd->{q};
my $term = $q->param('term') // '';

my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');

# Leemos con codificación explícita y ruta segura
my $regs = leer_tabla($archivo_pacientes, '\|');
my @results;

if ($regs) {
    my $mi_org = $sd->{id_empresa} || 'X';
    my $mi_sucursal = $sd->{id_sucursal} // 0;
    my $role = $sd->{role};
    my $id_medico = $sd->{id_medico};

    foreach my $f (@$regs) {
        next unless @$f >= 3;
        my ($id, $med_id, $nombre) = ($f->[0], $f->[1], $f->[2]);
        
        # Saltamos la cabecera
        next if $id =~ /ID_PACIENTE/i;

        # Validar permisos de acceso antes de sugerir el paciente
        my $tenant_pac = $f->[13] // '';
        my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
        
        my $acceso_permitido = 0;
        if ($role eq 'Administrador Global') {
            $acceso_permitido = 1;
        } elsif ($role =~ /Administrador Organizacion|Soporte/i) {
            if ($org_pac && $org_pac eq $mi_org) {
                $acceso_permitido = 1;
            } elsif (!$org_pac) {
                $acceso_permitido = 1;
            }
        } elsif ($role eq 'Medico') {
            if ($org_pac && $org_pac eq $mi_org) {
                if (($suc_pac eq $mi_sucursal || !$suc_pac || !$mi_sucursal) && $med_id eq $id_medico) {
                    $acceso_permitido = 1;
                }
            } elsif (!$org_pac && $med_id eq $id_medico) {
                $acceso_permitido = 1;
            }
        }
        
        next unless $acceso_permitido;

        # Búsqueda insensible a mayúsculas/minúsculas
        if ($nombre =~ /\Q$term\E/i) {
            # Aseguramos que el string esté decodificado para Perl (evita doble encode)
            utf8::decode($nombre) unless utf8::is_utf8($nombre);
            
            push @results, { 
                id => $id, 
                label => $nombre, 
                value => $nombre 
            };
        }
    }
}

# Enviamos cabecera JSON pura
print "Content-Type: application/json; charset=UTF-8\n\n";
binmode STDOUT, ":raw";
print JSON::PP->new->utf8(1)->encode(\@results);

1;
