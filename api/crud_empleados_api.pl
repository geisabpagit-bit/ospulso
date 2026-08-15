#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json decode_json);
use File::Spec;
use FindBin;
use POSIX qw(strftime);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $sd = check_session();
my $q = $sd->{q};
my $usuario = $sd->{usuario} || '';

binmode STDOUT, ":utf8";
print $q->header('application/json; charset=UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ ok => 0, error => 'No autorizado' });
    exit;
}

my $action = $q->param('action') || '';
my $clues = $q->param('clues') || '';

if (!$clues) {
    print encode_json({ ok => 0, error => 'CLUES no proporcionado' });
    exit;
}

my $file_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', "empleadosmun_${clues}.dat");

if ($action eq 'list') {
    my @data = ();
    if (-e $file_path && open(my $fh, '<:utf8', $file_path)) {
        my $header = <$fh>; # skip header
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^\s*$/;
            my @cols = split(/!/, $line, -1);
            if (scalar(@cols) >= 12) {
                my $num = $cols[0] // '';
                my $nom = $cols[1] // '';
                my $rel = $cols[2] // '';
                my $mun = $cols[3] // '';
                my $dep = $cols[4] // '';
                my $tel = $cols[5] // '';
                my $est = $cols[7] // '';
                
                my $opts = qq{<button class="btn btn-sm btn-outline-primary" onclick="abrirModalEditar('$num', '$nom', '$rel', '$mun', '$dep', '$tel', '$est')"><i class="bi bi-pencil"></i></button>};
                
                push @data, [
                    $num,
                    $nom,
                    $rel,
                    $tel,
                    $est eq 'Activo' ? '<span class="badge bg-success">Activo</span>' : '<span class="badge bg-danger">Baja</span>',
                    $opts
                ];
            }
        }
        close($fh);
    }
    print encode_json({ data => \@data });
    exit;
}

if ($action eq 'check_num') {
    my $num = $q->param('num_empleado') || '';
    my $exists = 0;
    if (-e $file_path && open(my $fh, '<:utf8', $file_path)) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp($line);
            my @cols = split(/!/, $line, -1);
            # Verificamos si existe un titular con ese numero (Empleado)
            if (($cols[0] // '') eq $num && ($cols[2] // '') =~ /Empleado/i) {
                $exists = 1;
                last;
            }
        }
        close($fh);
    }
    print encode_json({ ok => 1, exists => $exists });
    exit;
}

if ($action eq 'crear' || $action eq 'editar') {
    my $num = $q->param('num_empleado') || '';
    my $nom = $q->param('nombre') || '';
    my $rel = $q->param('relacion') || '';
    my $mun = $q->param('municipio') || '';
    my $dep = $q->param('dependencia') || '';
    my $tel = $q->param('telefono') || '';
    my $est = $q->param('estatus') || '';
    
    my $orig_num = $q->param('original_num') || '';
    my $orig_name = $q->param('original_name') || '';
    
    if (!$num || !$nom) {
        print encode_json({ ok => 0, error => 'Faltan datos obligatorios' });
        exit;
    }
    
    my $fecha_actual = strftime("%d/%m/%Y", localtime);
    my @lines = ();
    
    if (-e $file_path) {
        open(my $fh, '<:utf8', $file_path);
        @lines = <$fh>;
        close($fh);
    } else {
        push @lines, '$c_clinumempleado!$c_nombreCompleto!$c_clirelacion!$c_climunicipio!$c_cliiddependencia!$c_clitelefono!$c_cliemail!$c_clistatus!$c_clifecha!$c_cliusualta!$c_cliusumod!$c_clifechamod!$c_libre1!$c_libre2!\n';
    }
    
    my $modificado = 0;
    my @new_lines = ();
    
    foreach my $line (@lines) {
        chomp($line);
        if ($line =~ /^(\$|#|^\s*$)/) {
            push @new_lines, $line;
            next;
        }
        my @cols = split(/!/, $line, -1);
        # Si es editar y coincide el num y el nombre
        if ($action eq 'editar' && $cols[0] eq $orig_num && $cols[1] eq $orig_name) {
            # Actualizamos preservando lo que no tocamos
            $cols[1] = $nom;
            $cols[2] = $rel;
            $cols[3] = $mun;
            $cols[4] = $dep;
            $cols[5] = $tel;
            $cols[7] = $est;
            $cols[10] = $usuario; # usu_mod
            $cols[11] = $fecha_actual; # fecha_mod
            $line = join('!', @cols);
            $modificado = 1;
        }
        push @new_lines, $line;
    }
    
    if ($action eq 'crear') {
        # $c_clinumempleado!$c_nombreCompleto!$c_clirelacion!$c_climunicipio!$c_cliiddependencia!$c_clitelefono!$c_cliemail!$c_clistatus!$c_clifecha!$c_cliusualta!$c_cliusumod!$c_clifechamod!$c_libre1!$c_libre2!
        my $nueva_linea = "$num!$nom!$rel!$mun!$dep!$tel!!$est!$fecha_actual!$usuario!!!!";
        push @new_lines, $nueva_linea;
        $modificado = 1;
    }
    
    if ($modificado) {
        open(my $fw, '>:utf8', $file_path);
        foreach my $nl (@new_lines) {
            print $fw "$nl\n";
        }
        close($fw);
        print encode_json({ ok => 1 });
    } else {
        print encode_json({ ok => 0, error => 'No se encontró el registro a editar' });
    }
    exit;
}

print encode_json({ ok => 0, error => 'Acción inválida' });
