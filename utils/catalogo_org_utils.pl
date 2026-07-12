#!/usr/bin/perl
package catalogo_org_utils;

use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use Fcntl qw(:flock);
use Exporter 'import';

our @EXPORT_OK = qw(
    resolver_id_raiz_catalogo
    obtener_rutas_catalogo
    crear_catalogo_org_desde_global
    catalogo_org_existe
);

# ─────────────────────────────────────────────────────────────
# resolver_id_raiz_catalogo($id_empresa)
# Dado el ID de un negocio, devuelve el ID de la organizacion
# raiz (ID_MATRIZ == 0). Si el negocio ya es raiz, devuelve su propio ID.
# ─────────────────────────────────────────────────────────────
sub resolver_id_raiz_catalogo {
    my ($id_empresa) = @_;
    return 0 unless $id_empresa;

    my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
    return $id_empresa unless -e $negocios_file;

    open(my $fh, '<:encoding(UTF-8)', $negocios_file) or return $id_empresa;
    <$fh>; # saltar cabecera
    my %negocios;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        next unless @c >= 3;
        $negocios{$c[0]} = $c[2]; # ID => ID_MATRIZ
    }
    close $fh;

    # Si el negocio es raiz (ID_MATRIZ == 0), retornar su propio ID
    if (defined $negocios{$id_empresa} && $negocios{$id_empresa} == 0) {
        return $id_empresa;
    }

    # Si es sucursal, retornar su ID_MATRIZ
    if (defined $negocios{$id_empresa} && $negocios{$id_empresa} > 0) {
        return $negocios{$id_empresa};
    }

    return $id_empresa; # fallback
}

# ─────────────────────────────────────────────────────────────
# obtener_rutas_catalogo($id_raiz)
# Devuelve hashref con rutas absolutas de los archivos .dat
# de servicios y productos de la organizacion.
# ─────────────────────────────────────────────────────────────
sub obtener_rutas_catalogo {
    my ($id_raiz) = @_;
    my $dat = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    return {
        servicios => File::Spec->catfile($dat, "servicios_${id_raiz}.dat"),
        productos  => File::Spec->catfile($dat, "productos_${id_raiz}.dat"),
    };
}

# ─────────────────────────────────────────────────────────────
# catalogo_org_existe($id_raiz)
# Devuelve 1 si ambos archivos de catalogo de la org existen.
# ─────────────────────────────────────────────────────────────
sub catalogo_org_existe {
    my ($id_raiz) = @_;
    my $rutas = obtener_rutas_catalogo($id_raiz);
    return (-e $rutas->{servicios} && -e $rutas->{productos}) ? 1 : 0;
}

# ─────────────────────────────────────────────────────────────
# crear_catalogo_org_desde_global($id_raiz)
# Crea servicios_{ID}.dat y productos_{ID}.dat copiando el
# catalogo global. Si el global no existe, inserta un item base.
# Devuelve { ok => 1 } o { ok => 0, error => $msg }
# ─────────────────────────────────────────────────────────────
sub crear_catalogo_org_desde_global {
    my ($id_raiz) = @_;
    return { ok => 0, error => 'ID raiz invalido' } unless $id_raiz;

    my $rutas       = obtener_rutas_catalogo($id_raiz);
    my $dat_path    = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $serv_global = File::Spec->catfile($dat_path, 'servicios.dat');
    my $prod_global = File::Spec->catfile($dat_path, 'productos.dat');

    eval {
        # ── Servicios ──────────────────────────────────────────
        unless (-e $rutas->{servicios}) {
            open(my $fh_out, '>:encoding(UTF-8)', $rutas->{servicios})
                or die "No se pudo crear servicios_${id_raiz}.dat: $!";
            flock($fh_out, LOCK_EX);

            if (-e $serv_global) {
                open(my $fh_in, '<:encoding(UTF-8)', $serv_global)
                    or die "No se pudo leer servicios.dat: $!";
                while (my $line = <$fh_in>) { print $fh_out $line; }
                close $fh_in;
            } else {
                print $fh_out "ID|NOMBRE|PRECIO|DESCRIPCION\n";
                print $fh_out "1|Consulta General|500.00|Servicio base de la organizacion.\n";
            }
            close $fh_out;
        }

        # ── Productos ─────────────────────────────────────────
        unless (-e $rutas->{productos}) {
            open(my $fh_out, '>:encoding(UTF-8)', $rutas->{productos})
                or die "No se pudo crear productos_${id_raiz}.dat: $!";
            flock($fh_out, LOCK_EX);

            if (-e $prod_global) {
                open(my $fh_in, '<:encoding(UTF-8)', $prod_global)
                    or die "No se pudo leer productos.dat: $!";
                while (my $line = <$fh_in>) { print $fh_out $line; }
                close $fh_in;
            } else {
                print $fh_out "ID|NOMBRE|PRECIO|CANTIDAD|PRESENTACION|DESCRIPCION\n";
                print $fh_out "1|Paracetamol 500mg|50.00|100|Caja 20 tabletas|Analgesico base.\n";
            }
            close $fh_out;
        }
    };

    if ($@) {
        warn "[catalogo_org_utils] Error al crear catalogo org $id_raiz: $@\n";
        return { ok => 0, error => $@ };
    }

    return { ok => 1 };
}

1;
