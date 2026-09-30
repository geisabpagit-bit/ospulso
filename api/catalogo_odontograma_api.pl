#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use FindBin;
use File::Spec;
use Fcntl qw(:flock);
use Encode qw(decode_utf8 encode_utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(
    -type          => 'application/json',
    -charset       => 'UTF-8',
    -cache_control => 'no-store, no-cache, must-revalidate, max-age=0',
    -pragma        => 'no-cache'
);

unless ($sd->{session_ok}) {
    print encode_json({ status => 'error', message => 'Sesión expirada o inválida' });
    exit;
}

my $usuario    = $sd->{usuario}    // 'Anon';
my $role       = $sd->{role}       // '';
my $id_empresa = $sd->{id_empresa} // 0;

my $action = $q->param('action') || $q->param('accion') || 'list';

# Obtener ruta de catálogo multi-tenant
my $archivo_cat = catalogo_org_utils::obtener_ruta_catalogo_odontograma($id_empresa);

unless (-e $archivo_cat) {
    catalogo_org_utils::crear_catalogo_odontograma_si_no_existe($id_empresa);
}

sub leer_items_odontograma {
    my ($file) = @_;
    my @items = ();
    return \@items unless -e $file;

    if (open(my $fh, '<:encoding(UTF-8)', $file)) {
        my $header = <$fh>; # Saltar ID|CODE|NOMBRE|...
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            my @f = split(/\|/, $line, -1);
            next if @f < 4;
            push @items, {
                id        => $f[0] // '',
                code      => $f[1] // '',
                nombre    => $f[2] // '',
                grupo     => $f[3] // 'PATHOLOGY',     # PATHOLOGY | RESTORATION | NORMAL
                categoria => $f[4] // 'PENDING',       # PENDING | EXISTING | HEALTHY
                substatus => $f[5] // 'ACTIVE',        # ADAPTED | DEFECTIVE | TEMPORARY | etc.
                color_hex => $f[6] // '#FF3B30',
                precio    => sprintf("%.2f", $f[7] // 0),
                icono     => $f[8] // 'bi-circle-fill text-danger',
                activo    => defined $f[9] ? int($f[9]) : 1
            };
        }
        close($fh);
    }
    return \@items;
}

sub guardar_items_odontograma {
    my ($file, $items_ref) = @_;
    if (open(my $fh, '>:encoding(UTF-8)', $file)) {
        flock($fh, LOCK_EX);
        print $fh "ID|CODE|NOMBRE|GRUPO|CATEGORIA|SUBSTATUS|COLOR_HEX|PRECIO|ICONO|ACTIVO\n";
        foreach my $item (@$items_ref) {
            my $line = join('|', 
                $item->{id},
                $item->{code},
                $item->{nombre},
                $item->{grupo},
                $item->{categoria},
                $item->{substatus},
                $item->{color_hex},
                sprintf("%.2f", $item->{precio} || 0),
                $item->{icono},
                defined $item->{activo} ? $item->{activo} : 1
            );
            print $fh "$line\n";
        }
        close($fh);
        return 1;
    }
    return 0;
}

# ==========================================
# ACTION: LIST
# ==========================================
if ($action eq 'list') {
    my $items = leer_items_odontograma($archivo_cat);
    
    # Formatear diccionario para consumo directo del odontograma JS
    my %catalog_dict = ();
    foreach my $it (@$items) {
        next if $it->{activo} == 0; # Excluir inactivos en catálogo clínico activo
        $catalog_dict{$it->{code}} = {
            id        => $it->{id},
            code      => $it->{code},
            name      => $it->{nombre},
            group     => $it->{grupo},
            category  => $it->{categoria},
            substatus => $it->{substatus},
            state     => ($it->{categoria} eq 'PENDING') ? 'PENDING_TREATMENT' : (($it->{categoria} eq 'HEALTHY') ? 'HEALTHY' : 'EXISTING_CONDITION'),
            colorHex  => $it->{color_hex},
            price     => 0 + $it->{precio},
            icon      => $it->{icono}
        };
    }

    print encode_json({
        status   => 'success',
        total    => scalar(@$items),
        items    => $items,
        catalog  => \%catalog_dict
    });
    exit;
}

# ==========================================
# ACTION: GET
# ==========================================
if ($action eq 'get') {
    my $id   = decode_utf8($q->param('id')   // '');
    my $code = decode_utf8($q->param('code') // '');
    my $items = leer_items_odontograma($archivo_cat);

    foreach my $it (@$items) {
        if (($id ne '' && $it->{id} eq $id) || ($code ne '' && $it->{code} eq $code)) {
            print encode_json({ status => 'success', item => $it });
            exit;
        }
    }
    print encode_json({ status => 'error', message => 'Elemento no encontrado en el catálogo' });
    exit;
}

# ==========================================
# ACTION: SAVE (Create or Update)
# ==========================================
if ($action eq 'save') {
    # Validar permisos de modificación (Admin o Médico)
    unless ($role =~ /Administrador/i || $role =~ /Medico/i) {
        print encode_json({ status => 'error', message => 'No cuenta con privilegios para modificar el catálogo' });
        exit;
    }

    my $id        = decode_utf8($q->param('id')        // '');
    my $code      = uc(decode_utf8($q->param('code')      // ''));
    my $nombre    = decode_utf8($q->param('nombre')    // '');
    my $grupo     = uc(decode_utf8($q->param('grupo')     // 'PATHOLOGY'));
    my $categoria = uc(decode_utf8($q->param('categoria') // 'PENDING'));
    my $substatus = uc(decode_utf8($q->param('substatus') // 'ACTIVE'));
    my $color_hex = decode_utf8($q->param('color_hex') // '#FF3B30');
    my $precio    = $q->param('precio') // '0.00';
    my $icono     = decode_utf8($q->param('icono')     // 'bi-circle-fill text-danger');
    my $activo    = defined $q->param('activo') ? int($q->param('activo')) : 1;

    $code   =~ s/[^A-Z0-9_]//g; # Sanitizar código alfanumérico
    $nombre =~ s/^\s+|\s+$//g;
    $precio =~ s/[^\d\.]//g;
    $precio = 0 if $precio eq '';

    if ($code eq '' || $nombre eq '') {
        print encode_json({ status => 'error', message => 'Código y Nombre son obligatorios' });
        exit;
    }

    my $items = leer_items_odontograma($archivo_cat);
    my $found = 0;
    my $max_id = 0;

    # Validar no duplicidad de código en otros registros
    foreach my $it (@$items) {
        $max_id = $it->{id} if $it->{id} > $max_id;
        if ($it->{code} eq $code && ($id eq '' || $it->{id} ne $id)) {
            print encode_json({ status => 'error', message => "El código '$code' ya está asignado a otro concepto" });
            exit;
        }
    }

    if ($id ne '') {
        # Actualizar existente
        foreach my $it (@$items) {
            if ($it->{id} eq $id) {
                $it->{code}      = $code;
                $it->{nombre}    = $nombre;
                $it->{grupo}     = $grupo;
                $it->{categoria} = $categoria;
                $it->{substatus} = $substatus;
                $it->{color_hex} = $color_hex;
                $it->{precio}    = sprintf("%.2f", $precio);
                $it->{icono}     = $icono;
                $it->{activo}    = $activo;
                $found = 1;
                last;
            }
        }
    }

    if (!$found) {
        # Nuevo registro
        my $new_id = $max_id + 1;
        push @$items, {
            id        => $new_id,
            code      => $code,
            nombre    => $nombre,
            grupo     => $grupo,
            categoria => $categoria,
            substatus => $substatus,
            color_hex => $color_hex,
            precio    => sprintf("%.2f", $precio),
            icono     => $icono,
            activo    => $activo
        };
    }

    if (guardar_items_odontograma($archivo_cat, $items)) {
        print encode_json({ status => 'success', message => 'Catálogo actualizado correctamente', id => $id });
    } else {
        print encode_json({ status => 'error', message => 'Error al escribir en el archivo de catálogo' });
    }
    exit;
}

# ==========================================
# ACTION: DELETE (Baja lógica)
# ==========================================
if ($action eq 'delete') {
    unless ($role =~ /Administrador/i) {
        print encode_json({ status => 'error', message => 'Acción reservada para administradores' });
        exit;
    }

    my $id = decode_utf8($q->param('id') // '');
    if ($id eq '') {
        print encode_json({ status => 'error', message => 'ID requerido para eliminación' });
        exit;
    }

    my $items = leer_items_odontograma($archivo_cat);
    my $deleted = 0;
    foreach my $it (@$items) {
        if ($it->{id} eq $id) {
            $it->{activo} = 0; # Baja lógica para proteger integridad de expedientes previos
            $deleted = 1;
            last;
        }
    }

    if ($deleted && guardar_items_odontograma($archivo_cat, $items)) {
        print encode_json({ status => 'success', message => 'Concepto desactivado del catálogo' });
    } else {
        print encode_json({ status => 'error', message => 'No se encontró el concepto o error al guardar' });
    }
    exit;
}

# ==========================================
# ACTION: RESET DEFAULTS
# ==========================================
if ($action eq 'reset_defaults') {
    unless ($role =~ /Administrador/i) {
        print encode_json({ status => 'error', message => 'Acción reservada para administradores' });
        exit;
    }

    my $default_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogo_odontograma_default.dat');
    if (-e $default_file) {
        if (open(my $in, '<:encoding(UTF-8)', $default_file) && open(my $out, '>:encoding(UTF-8)', $archivo_cat)) {
            flock($out, LOCK_EX);
            while (my $line = <$in>) {
                print $out $line;
            }
            close($out);
            close($in);
            print encode_json({ status => 'success', message => 'Catálogo restablecido a valores de fábrica' });
            exit;
        }
    }
    print encode_json({ status => 'error', message => 'No se pudo restablecer el archivo plantilla' });
    exit;
}

print encode_json({ status => 'error', message => "Acción no reconocida: $action" });
exit;
