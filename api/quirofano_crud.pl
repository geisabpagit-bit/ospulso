#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json);
use File::Spec;
use FindBin;
use Fcntl qw(:flock);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(guardar_registro actualizar_archivo);

my $q = CGI->new;
my $sd = check_session($q);
print $q->header(-type => 'application/json; charset=UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada' });
    exit;
}

my $action = $q->param('action') || 'read';
my $file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'quirofano.dat');
my $id_org = $sd->{id_empresa} || 'ORG-000';

unless (-e $file) {
    open my $fh_init, '>:encoding(UTF-8)', $file;
    print $fh_init "ID_CIRUGIA|ID_ORG|ID_PACIENTE|ID_MEDICO|FECHA_PROGRAMADA|HORA_PROGRAMADA|ESTADO|SALA_QUIROFANO|PROCEDIMIENTO|ID_ANESTESIOLOGO|NOTAS\n";
    close $fh_init;
}

if ($action eq 'read') {
    my $fecha_filtro = $q->param('fecha') || '';
    my @registros;
    
    # Necesitamos cruzar datos de pacientes y médicos para mostrar nombres
    my %pacientes;
    my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
    if (-e $pac_file && open my $fhp, '<:encoding(UTF-8)', $pac_file) {
        my $hdr = <$fhp>;
        while (my $line = <$fhp>) {
            chomp $line;
            my @p = split /\|/, $line, -1;
            $pacientes{$p[0]} = $p[2] || 'Paciente Desconocido';
        }
        close $fhp;
    }
    
    my %medicos;
    my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    if (-e $usr_file && open my $fhu, '<:encoding(UTF-8)', $usr_file) {
        my $hdr = <$fhu>;
        while (my $line = <$fhu>) {
            chomp $line;
            my @u = split /\|/, $line, -1;
            $medicos{$u[1]} = $u[2] || 'Sin Médico';
        }
        close $fhu;
    }

    if (open my $fh, '<:encoding(UTF-8)', $file) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /\|/, $line, -1;
            next unless @c >= 10;
            
            # Filtro por Organización
            next if ($c[1] ne $id_org && $id_org ne 'ORG-000');
            
            # Filtro por Fecha (opcional, por defecto traemos todo activo o de hoy)
            if ($fecha_filtro && $c[4] ne $fecha_filtro && $c[6] ne 'Programada' && $c[6] ne 'Pre-Operatorio' && $c[6] ne 'En Quirófano' && $c[6] ne 'Recuperación') {
                # Si filtran por fecha, solo mostramos las de ese día, SALVO que estén activas
                next if ($c[4] ne $fecha_filtro);
            }
            
            # Si el paciente es del estado, mostramos su nombre tal cual en caso de no estar en dat/pacientes
            my $nombre_pac = $pacientes{$c[2]} // $c[2];
            
            push @registros, {
                id_cirugia       => $c[0],
                id_paciente      => $c[2],
                nombre_paciente  => $nombre_pac,
                id_medico        => $c[3],
                nombre_medico    => $medicos{$c[3]} // 'Desconocido',
                fecha            => $c[4],
                hora             => $c[5],
                estado           => $c[6],
                sala             => $c[7],
                procedimiento    => $c[8],
                id_anestesiologo => $c[9],
                nombre_anestesio => $c[9] ? ($medicos{$c[9]} // '') : '',
                notas            => $c[10] // ''
            };
        }
        close $fh;
    }
    print encode_json(\@registros);
    exit;
}
elsif ($action eq 'create') {
    my $id_paciente = $q->param('id_paciente') || '';
    my $id_medico = $q->param('id_medico') || '';
    my $fecha = $q->param('fecha_programada') || '';
    my $hora = $q->param('hora_programada') || '';
    my $sala = $q->param('sala') || '';
    my $procedimiento = $q->param('procedimiento') || '';
    my $id_anest = $q->param('id_anestesiologo') || '';
    my $notas = $q->param('notas') || '';
    
    $sala =~ s/\|/ /g;
    $procedimiento =~ s/\|/ /g;
    $notas =~ s/\|/ /g;
    
    if (!$id_paciente || !$id_medico || !$procedimiento) {
        print encode_json({ ok => JSON::false, msg => 'Datos obligatorios incompletos (Paciente, Médico y Procedimiento).' });
        exit;
    }
    
    my $id_cir = 'CIR-' . time() . '-' . int(rand(1000));
    my $linea = join('|', $id_cir, $id_org, $id_paciente, $id_medico, $fecha, $hora, 'Programada', $sala, $procedimiento, $id_anest, $notas);
    
    utils::db_manager::guardar_registro($file, $linea);
    print encode_json({ ok => JSON::true, id_cirugia => $id_cir });
    exit;
}
elsif ($action eq 'update_status') {
    my $id_cirugia = $q->param('id_cirugia') || '';
    my $nuevo_estado = $q->param('estado') || '';
    
    if (!$id_cirugia || !$nuevo_estado) {
        print encode_json({ ok => JSON::false, msg => 'Faltan parámetros' });
        exit;
    }
    
    my @lines;
    my $found = 0;
    if (open my $fh, '<:encoding(UTF-8)', $file) {
        my $cabecera = <$fh>;
        chomp $cabecera if defined $cabecera;
        
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id_cirugia && ($c[1] eq $id_org || $id_org eq 'ORG-000')) {
                $c[6] = $nuevo_estado;
                $l = join('|', @c);
                $found = 1;
            }
            push @lines, $l;
        }
        close $fh;
        if ($found) {
            utils::db_manager::actualizar_archivo($file, $cabecera, \@lines);
            print encode_json({ ok => JSON::true });
        } else {
            print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada o acceso denegado.' });
        }
    } else {
        print encode_json({ ok => JSON::false, msg => 'No se pudo leer el archivo' });
    }
    exit;
}
elsif ($action eq 'delete') {
    my $id_cirugia = $q->param('id_cirugia') || '';
    my @lines;
    my $found = 0;
    if (open my $fh, '<:encoding(UTF-8)', $file) {
        my $cabecera = <$fh>;
        chomp $cabecera if defined $cabecera;
        
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id_cirugia && ($c[1] eq $id_org || $id_org eq 'ORG-000')) {
                $found = 1;
                next; # Lo omitimos para borrarlo
            }
            push @lines, $l;
        }
        close $fh;
        if ($found) {
            utils::db_manager::actualizar_archivo($file, $cabecera, \@lines);
            print encode_json({ ok => JSON::true });
        } else {
            print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada.' });
        }
    }
    exit;
}
else {
    print encode_json({ ok => JSON::false, msg => 'Acción inválida' });
    exit;
}
1;
