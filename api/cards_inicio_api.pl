#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use FindBin;
use File::Spec;
use Fcntl qw(:flock);
use JSON::PP qw(encode_json decode_json);

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS ---
use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $q = CGI->new;
my $session_data = check_session();

# 1. Validación de Sesión
unless ($session_data->{session_ok}) {
    print $q->header(-type => 'application/json', -status => '401 Unauthorized', -charset => 'UTF-8');
    print encode_json({ success => 0, error => 'Sesión expirada o no válida.' });
    exit;
}

# 2. Control de Acceso Estricto RBAC: Exclusivo Administrador Global
my $role = $session_data->{role} || '';
unless ($role =~ /Administrador Global/i) {
    print $q->header(-type => 'application/json', -status => '403 Forbidden', -charset => 'UTF-8');
    print encode_json({ success => 0, error => 'Acceso denegado: Acción exclusiva de Administrador Global.' });
    exit;
}

print $q->header(-type => 'application/json', -charset => 'UTF-8');

my $dat_dir   = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $data_file = File::Spec->catfile($dat_dir, 'cards_inicio_admin.dat');

# Subrutina para leer todas las tarjetas
sub leer_cards {
    my @cards = ();
    return \@cards unless (-e $data_file);

    open(my $fh, '<:encoding(UTF-8)', $data_file) or return \@cards;
    flock($fh, LOCK_SH);
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#|^\s*$/;
        my ($id, $titulo, $desc, $icono, $color, $destino, $orden, $activo) = split(/\|/, $line, -1);
        push @cards, {
            id      => $id      // '',
            titulo  => $titulo  // '',
            desc    => $desc    // '',
            icono   => $icono   // 'bi-grid-fill',
            color   => $color   // 'primary',
            destino => $destino // '#',
            orden   => int($orden // 0),
            activo  => int($activo // 1)
        };
    }
    flock($fh, LOCK_UN);
    close($fh);

    # Ordenar por el campo orden
    @cards = sort { $a->{orden} <=> $b->{orden} || $a->{id} <=> $b->{id} } @cards;
    return \@cards;
}

# Subrutina para guardar todas las tarjetas
sub guardar_cards {
    my ($cards_ref) = @_;
    open(my $fh, '>:encoding(UTF-8)', $data_file) or return 0;
    flock($fh, LOCK_EX);
    print $fh "ID|TITULO|DESCRIPCION|ICONO_BS|COLOR_BS|DESTINO|ORDEN|ACTIVO\n";
    foreach my $c (@$cards_ref) {
        my $id      = $c->{id} // '';
        my $titulo  = $c->{titulo} // '';
        my $desc    = $c->{desc} // '';
        my $icono   = $c->{icono} // 'bi-grid-fill';
        my $color   = $c->{color} // 'primary';
        my $destino = $c->{destino} // '#';
        my $orden   = int($c->{orden} // 0);
        my $activo  = int($c->{activo} // 1);

        # Sanitizar pipes y saltos de línea
        for ($titulo, $desc, $icono, $color, $destino) {
            s/\|/ /g;
            s/[\r\n]+/ /g;
        }

        print $fh "$id|$titulo|$desc|$icono|$color|$destino|$orden|$activo\n";
    }
    flock($fh, LOCK_UN);
    close($fh);
    return 1;
}

my $accion = $q->param('accion') || 'listar';

if ($accion eq 'listar') {
    my $cards = leer_cards();
    print encode_json({ success => 1, data => $cards });
    exit;
}

elsif ($accion eq 'obtener') {
    my $id = $q->param('id') // '';
    my $cards = leer_cards();
    my ($encontrado) = grep { $_->{id} eq $id } @$cards;
    if ($encontrado) {
        print encode_json({ success => 1, card => $encontrado });
    } else {
        print encode_json({ success => 0, error => 'Tarjeta no encontrada.' });
    }
    exit;
}

elsif ($accion eq 'guardar') {
    my $id      = $q->param('id') // '';
    my $titulo  = $q->param('titulo') // '';
    my $desc    = $q->param('desc') // '';
    my $icono   = $q->param('icono') // 'bi-grid-fill';
    my $color   = $q->param('color') // 'primary';
    my $destino = $q->param('destino') // '';
    my $orden   = $q->param('orden');
    my $activo  = $q->param('activo');

    $titulo =~ s/^\s+|\s+$//g;
    $desc   =~ s/^\s+|\s+$//g;
    $destino =~ s/^\s+|\s+$//g;
    $icono  =~ s/^\s+|\s+$//g;
    $color  =~ s/^\s+|\s+$//g;

    if ($titulo eq '' || $destino eq '') {
        print encode_json({ success => 0, error => 'El título y el archivo/destino son campos requeridos.' });
        exit;
    }

    $icono = 'bi-grid-fill' if $icono eq '';
    $color = 'primary' if $color eq '';

    my $cards = leer_cards();

    if ($id ne '') {
        # Actualizar existente
        my $found = 0;
        foreach my $c (@$cards) {
            if ($c->{id} eq $id) {
                $c->{titulo}  = $titulo;
                $c->{desc}    = $desc;
                $c->{icono}   = $icono;
                $c->{color}   = $color;
                $c->{destino} = $destino;
                $c->{orden}   = defined $orden && $orden ne '' ? int($orden) : $c->{orden};
                $c->{activo}  = defined $activo && $activo ne '' ? int($activo) : $c->{activo};
                $found = 1;
                last;
            }
        }
        if (!$found) {
            print encode_json({ success => 0, error => 'El ID especificado no existe para actualizar.' });
            exit;
        }
    } else {
        # Nuevo registro: autoincrementar ID
        my $max_id = 0;
        my $max_orden = 0;
        foreach my $c (@$cards) {
            $max_id = int($c->{id}) if int($c->{id}) > $max_id;
            $max_orden = int($c->{orden}) if int($c->{orden}) > $max_orden;
        }
        my $nuevo_id = $max_id + 1;
        my $nuevo_orden = defined $orden && $orden ne '' ? int($orden) : ($max_orden + 1);
        my $nuevo_activo = defined $activo && $activo ne '' ? int($activo) : 1;

        push @$cards, {
            id      => $nuevo_id,
            titulo  => $titulo,
            desc    => $desc,
            icono   => $icono,
            color   => $color,
            destino => $destino,
            orden   => $nuevo_orden,
            activo  => $nuevo_activo
        };
    }

    if (guardar_cards($cards)) {
        print encode_json({ success => 1, message => 'Tarjeta guardada correctamente.' });
    } else {
        print encode_json({ success => 0, error => 'Error al escribir el archivo de configuración.' });
    }
    exit;
}

elsif ($accion eq 'eliminar') {
    my $id = $q->param('id') // '';
    if ($id eq '') {
        print encode_json({ success => 0, error => 'ID no proporcionado.' });
        exit;
    }

    my $cards = leer_cards();
    my @filtrados = grep { $_->{id} ne $id } @$cards;

    if (@filtrados == @$cards) {
        print encode_json({ success => 0, error => 'Tarjeta no encontrada para eliminar.' });
        exit;
    }

    if (guardar_cards(\@filtrados)) {
        print encode_json({ success => 1, message => 'Tarjeta eliminada con éxito.' });
    } else {
        print encode_json({ success => 0, error => 'Error al actualizar el archivo.' });
    }
    exit;
}

elsif ($accion eq 'toggle') {
    my $id = $q->param('id') // '';
    my $cards = leer_cards();
    my $nuevo_estado = 0;
    my $found = 0;

    foreach my $c (@$cards) {
        if ($c->{id} eq $id) {
            $c->{activo} = ($c->{activo} == 1) ? 0 : 1;
            $nuevo_estado = $c->{activo};
            $found = 1;
            last;
        }
    }

    if ($found && guardar_cards($cards)) {
        print encode_json({ success => 1, activo => $nuevo_estado, message => 'Estado actualizado.' });
    } else {
        print encode_json({ success => 0, error => 'No se pudo cambiar el estado.' });
    }
    exit;
}

else {
    print encode_json({ success => 0, error => 'Acción no reconocida.' });
    exit;
}
