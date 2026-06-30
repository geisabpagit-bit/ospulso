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

my $q = CGI->new;
my $term = $q->param('term') // '';
my $id_medico_req = $q->param('id_medico') // '';

my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');

# Leemos con codificación explícita y ruta segura
my $regs = leer_tabla($archivo_pacientes, '\|');
my @results;

if ($regs) {
    foreach my $f (@$regs) {
        next unless @$f >= 3;
        my ($id, $med_id, $nombre) = ($f->[0], $f->[1], $f->[2]);
        
        # Saltamos la cabecera
        next if $id =~ /ID_PACIENTE/i;

        # REGLA DE NEGOCIO: Solo pacientes del médico solicitado
        if ($id_medico_req) {
            next unless $med_id eq $id_medico_req;
        }

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
