#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON::PP qw(encode_json decode_json);
use FindBin;
use File::Spec;
use Fcntl qw(:flock);

# Protocolo SDA-11.1: Rutas Absolutas Dinámicas
my $dat_path = File::Spec->catdir($FindBin::Bin, '..', 'dat');

my $q = CGI->new;
require "$FindBin::Bin/../auth/check_session.pl";
my $session_data = check_session($q);

print $q->header(-type => 'application/json', -charset => 'UTF-8');

unless ($session_data->{session_ok}) {
    print encode_json({ status => 'error', message => 'Sesion invalida o expirada.' });
    exit;
}

my $accion     = $q->param('accion')      || '';
my $id_p       = $q->param('id_paciente') || '';
my $id_med     = $session_data->{id_medico} || 'SISTEMA';
my $json_engine = JSON::PP->new->utf8(1);

my $cot_file   = File::Spec->catfile($dat_path, 'cotizaciones.dat');
my $items_file = File::Spec->catfile($dat_path, 'cotizaciones_items.dat');

# Asegurar que los archivos existen con cabecera
unless (-e $cot_file) {
    open(my $fh, '>:encoding(UTF-8)', $cot_file) or die "No se puede crear cotizaciones.dat: $!";
    print $fh "ID_COT|ID_PACIENTE|NOMBRE|TOTAL|FECHA|ID_MEDICO\n";
    close $fh;
}
unless (-e $items_file) {
    open(my $fh, '>:encoding(UTF-8)', $items_file) or die "No se puede crear cotizaciones_items.dat: $!";
    print $fh "ID_COT|CONCEPTO|PRECIO|CANTIDAD|SUBTOTAL\n";
    close $fh;
}

# ==========================================
# GET_LISTA — listar cotizaciones de un paciente
# ==========================================
if ($accion eq 'get_lista') {
    unless ($id_p) { print encode_json({ status => 'error', message => 'id_paciente requerido' }); exit; }

    my @lista = ();
    open(my $fh, '<:encoding(UTF-8)', $cot_file) or do { print encode_json({ status => 'ok', cotizaciones => [] }); exit; };
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        next unless @c >= 6;
        if ($c[1] eq $id_p) {
            push @lista, {
                id_cot  => $c[0],
                nombre  => $c[2],
                total   => $c[3] + 0,
                fecha   => $c[4],
                id_med  => $c[5]
            };
        }
    }
    close $fh;
    print encode_json({ status => 'ok', cotizaciones => \@lista });
    exit;
}

# ==========================================
# GET_DETALLE — items de una cotizacion
# ==========================================
if ($accion eq 'get_detalle') {
    my $id_cot = $q->param('id_cot') || '';
    unless ($id_cot) { print encode_json({ status => 'error', message => 'id_cot requerido' }); exit; }

    my $nombre_cot = '';
    my @items = ();

    # Obtener nombre de la cotizacion
    open(my $fh_c, '<:encoding(UTF-8)', $cot_file) or do { print encode_json({ status => 'error', message => 'No se puede leer cotizaciones.dat' }); exit; };
    my $hdr = <$fh_c>;
    while (my $line = <$fh_c>) {
        chomp $line;
        my @c = split /\|/, $line, -1;
        if (@c >= 3 && $c[0] eq $id_cot) { $nombre_cot = $c[2]; last; }
    }
    close $fh_c;

    # Obtener items
    open(my $fh_i, '<:encoding(UTF-8)', $items_file) or do { print encode_json({ status => 'ok', nombre => $nombre_cot, items => [] }); exit; };
    my $hdr_i = <$fh_i>;
    while (my $line = <$fh_i>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        next unless @c >= 5;
        if ($c[0] eq $id_cot) {
            push @items, {
                concepto  => $c[1],
                precio    => $c[2] + 0,
                cantidad  => $c[3] + 0,
                subtotal  => $c[4] + 0
            };
        }
    }
    close $fh_i;
    print encode_json({ status => 'ok', nombre => $nombre_cot, items => \@items });
    exit;
}

# ==========================================
# CREATE — alta de cotizacion
# ==========================================
if ($accion eq 'create') {
    unless ($id_p) { print encode_json({ status => 'error', message => 'id_paciente requerido' }); exit; }

    my $nombre  = $q->param('nombre') // 'Sin nombre';
    my $payload = $q->param('payload') // '[]';
    my $items   = eval { $json_engine->decode($payload) } || [];

    unless (@$items) { print encode_json({ status => 'error', message => 'Debes agregar al menos un concepto.' }); exit; }

    # Generar ID unico
    my @lt = localtime(time);
    my $fecha   = sprintf("%04d-%02d-%02d", $lt[5]+1900, $lt[4]+1, $lt[3]);
    my $id_cot  = sprintf("COT-%04d%02d%02d-%s-%s", $lt[5]+1900, $lt[4]+1, $lt[3], $id_p, time % 100000);

    # Calcular total
    my $total = 0;
    foreach my $it (@$items) {
        my $sub = ($it->{precio} || 0) * ($it->{cantidad} || 1);
        $total += $sub;
    }

    eval {
        # Guardar cabecera
        open(my $fh, '>>:encoding(UTF-8)', $cot_file) or die "cotizaciones.dat: $!";
        flock($fh, LOCK_EX);
        print $fh "$id_cot|$id_p|$nombre|$total|$fecha|$id_med\n";
        close $fh;

        # Guardar items
        open(my $fi, '>>:encoding(UTF-8)', $items_file) or die "cotizaciones_items.dat: $!";
        flock($fi, LOCK_EX);
        foreach my $it (@$items) {
            my $cant = $it->{cantidad} || 1;
            my $precio = $it->{precio} || 0;
            my $sub = $precio * $cant;
            my $concepto = $it->{nombre} || $it->{concepto} || 'Sin concepto';
            print $fi "$id_cot|$concepto|$precio|$cant|$sub\n";
        }
        close $fi;
    };
    if ($@) { print encode_json({ status => 'error', message => "Error al guardar: $@" }); exit; }

    print encode_json({ status => 'ok', id_cot => $id_cot, total => $total });
    exit;
}

# ==========================================
# UPDATE — editar nombre y reemplazar items
# ==========================================
if ($accion eq 'update') {
    my $id_cot = $q->param('id_cot') || '';
    unless ($id_cot) { print encode_json({ status => 'error', message => 'id_cot requerido' }); exit; }

    my $nombre  = $q->param('nombre') // '';
    my $payload = $q->param('payload') // '[]';
    my $items   = eval { $json_engine->decode($payload) } || [];

    # Calcular nuevo total
    my $total = 0;
    foreach my $it (@$items) {
        $total += ($it->{precio} || 0) * ($it->{cantidad} || 1);
    }

    eval {
        # Actualizar cabecera en cotizaciones.dat
        open(my $fh, '<:encoding(UTF-8)', $cot_file) or die "read cot: $!";
        my @lineas = <$fh>;
        close $fh;
        open(my $fw, '>:encoding(UTF-8)', $cot_file) or die "write cot: $!";
        flock($fw, LOCK_EX);
        foreach my $l (@lineas) {
            chomp(my $trimmed = $l);
            my @c = split /\|/, $trimmed, -1;
            if (@c >= 6 && $c[0] eq $id_cot) {
                $c[2] = $nombre;
                $c[3] = $total;
                print $fw join('|', @c) . "\n";
            } else {
                print $fw $l;
            }
        }
        close $fw;

        # Reemplazar items: borrar los del id_cot y reapergar los nuevos
        open(my $fi, '<:encoding(UTF-8)', $items_file) or die "read items: $!";
        my @ilineas = <$fi>;
        close $fi;
        open(my $fiw, '>:encoding(UTF-8)', $items_file) or die "write items: $!";
        flock($fiw, LOCK_EX);
        foreach my $l (@ilineas) {
            chomp(my $t = $l);
            my @c = split /\|/, $t, -1;
            # Mantener cabecera o lineas de otras cotizaciones
            if (@c < 2 || $c[0] ne $id_cot) {
                print $fiw $l;
            }
        }
        # Escribir nuevos items
        foreach my $it (@$items) {
            my $cant    = $it->{cantidad} || 1;
            my $precio  = $it->{precio}   || 0;
            my $sub     = $precio * $cant;
            my $concepto = $it->{nombre} || $it->{concepto} || 'Sin concepto';
            print $fiw "$id_cot|$concepto|$precio|$cant|$sub\n";
        }
        close $fiw;
    };
    if ($@) { print encode_json({ status => 'error', message => "Error al actualizar: $@" }); exit; }

    print encode_json({ status => 'ok', total => $total });
    exit;
}

# ==========================================
# DELETE — borrar cotizacion y sus items
# ==========================================
if ($accion eq 'delete') {
    my $id_cot = $q->param('id_cot') || '';
    unless ($id_cot) { print encode_json({ status => 'error', message => 'id_cot requerido' }); exit; }

    eval {
        # Borrar de cotizaciones.dat
        open(my $fh, '<:encoding(UTF-8)', $cot_file) or die "read cot: $!";
        my @lineas = <$fh>;
        close $fh;
        open(my $fw, '>:encoding(UTF-8)', $cot_file) or die "write cot: $!";
        flock($fw, LOCK_EX);
        foreach my $l (@lineas) {
            chomp(my $t = $l);
            my @c = split /\|/, $t, -1;
            print $fw $l unless (@c >= 1 && $c[0] eq $id_cot);
        }
        close $fw;

        # Borrar items de cotizaciones_items.dat
        open(my $fi, '<:encoding(UTF-8)', $items_file) or die "read items: $!";
        my @ilineas = <$fi>;
        close $fi;
        open(my $fiw, '>:encoding(UTF-8)', $items_file) or die "write items: $!";
        flock($fiw, LOCK_EX);
        foreach my $l (@ilineas) {
            chomp(my $t = $l);
            my @c = split /\|/, $t, -1;
            print $fiw $l unless (@c >= 1 && $c[0] eq $id_cot);
        }
        close $fiw;
    };
    if ($@) { print encode_json({ status => 'error', message => "Error al borrar: $@" }); exit; }

    print encode_json({ status => 'ok' });
    exit;
}

# Accion no reconocida
print encode_json({ status => 'error', message => 'Accion no reconocida.' });
1;
