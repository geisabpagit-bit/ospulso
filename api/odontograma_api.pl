#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use File::Spec;
use FindBin;
use lib '..';
use POSIX qw(strftime);
use utils::db_manager qw(leer_tabla actualizar_archivo);

my $q = CGI->new;
my $accion = $q->param('accion') || 'get';
my $id_paciente = $q->param('id_paciente');

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$id_paciente) {
    print encode_json({ ok => 0, msg => 'ID de paciente requerido' });
    exit;
}

my $archivo = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');

if ($accion eq 'save') {
    my $json_text = $q->param('data') || '{}';
    my $data_hash = eval { decode_json($json_text) } || {};
    
    my $notas_text = $q->param('notas') || '';
    $notas_text =~ s/\|/ /g; # Limpiar pipes para no quebrar el CSV
    $notas_text =~ s/\n/ /g; # Limpiar saltos de línea
    $notas_text =~ s/\r//g;
    
    my $fecha = strftime("%d/%m/%Y %H:%M:%S", localtime);
    
    my @adult_cols;
    my @child_cols;

    foreach my $tooth (sort keys %$data_hash) {
        my $val = encode_json($data_hash->{$tooth});
        if ($tooth =~ /^[1234][1-8]$/) {
            push @adult_cols, "$tooth=$val";
        } elsif ($tooth =~ /^[5678][1-5]$/) {
            push @child_cols, "$tooth=$val";
        }
    }

    # Estructura: ID | TIPO | FECHA | NOTAS | 11=... | 12=...
    my $adult_line = join('|', $id_paciente, 'adulto', $fecha, $notas_text, @adult_cols);
    my $child_line = join('|', $id_paciente, 'nino', $fecha, $notas_text, @child_cols);
    
    my $registros = leer_tabla($archivo, '\|');
    my @nuevos_registros;
    
    # Mantener registros de otros pacientes
    foreach my $fila (@$registros) {
        if ($fila->[0] ne $id_paciente) {
            push @nuevos_registros, join('|', @$fila);
        }
    }
    
    # Agregar los 2 registros del paciente actual
    push @nuevos_registros, $adult_line;
    push @nuevos_registros, $child_line;
    
    my $cabecera = "ID_PACIENTE|TIPO|FECHA|NOTAS|DATOS_FDI";
    actualizar_archivo($archivo, $cabecera, \@nuevos_registros);
    
    print encode_json({ ok => 1, msg => 'Odontograma guardado con nomenclatura FDI' });
} 
else {
    # Cargar datos
    my $registros = leer_tabla($archivo, '\|');
    my %data_encontrada = ();
    
    foreach my $fila (@$registros) {
        if ($fila->[0] eq $id_paciente) {
            # Extraer Metadatos (Columna 2: Fecha, Columna 3: Notas)
            my $fecha = $fila->[2] || '';
            my $notas = $fila->[3] || '';
            
            $data_encontrada{fecha} = $fecha if $fecha;
            $data_encontrada{notas} = $notas if $notas;

            # Las columnas de dientes empiezan desde el índice 4
            for (my $i = 4; $i < @$fila; $i++) {
                if ($fila->[$i] =~ /^(\d+)=(.+)$/) {
                    my $tooth = $1;
                    my $val_hash = eval { decode_json($2) } || {};
                    $data_encontrada{$tooth} = $val_hash;
                }
            }
        }
    }
    
    print encode_json({ ok => 1, data => \%data_encontrada });
}
