#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '..', 'utils');
use Fcntl qw(:flock);
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $cgi = CGI->new;
print $cgi->header(-type => 'application/json', -charset => 'utf-8');

sub responder {
    my ($data) = @_;
    print to_json($data, { utf8 => 1 });
    exit;
}

my $session_data = check_session();
if (!$session_data || !$session_data->{session_ok} || !$session_data->{id_usuario}) {
    responder({ error => 'No autorizado' });
}

my $id_empresa = $session_data->{id_empresa};
if (!$id_empresa) {
    responder({ error => 'Empresa no identificada' });
}

my $id_raiz = catalogo_org_utils::resolver_id_raiz_catalogo($id_empresa);
my $rutas = catalogo_org_utils::obtener_rutas_catalogo($id_raiz);

if (!$rutas->{is_universal}) {
    responder({ error => 'Esta organizacion no cuenta con un catalogo universal.' });
}

my $action = $cgi->param('action') || '';

sub get_next_id {
    my ($file) = @_;
    return 1 unless -e $file;
    open(my $fh, '<:encoding(UTF-8)', $file) or return 1;
    <$fh>; # skip header
    my $max = 0;
    while (<$fh>) {
        chomp; next if /^\s*$/;
        my @c = split /\|/;
        $max = $c[0] if $c[0] =~ /^\d+$/ && $c[0] > $max;
    }
    close $fh;
    return $max + 1;
}

sub actualizar_archivo {
    my ($file, $header, $lines_ref) = @_;
    open(my $fh, '>:encoding(UTF-8)', $file) or return 0;
    flock($fh, LOCK_EX);
    print $fh "$header\n";
    foreach my $line (@$lines_ref) {
        print $fh "$line\n";
    }
    close $fh;
    return 1;
}

sub leer_archivo {
    my ($file) = @_;
    my @lines = ();
    my $header = "";
    if (-e $file) {
        open(my $fh, '<:encoding(UTF-8)', $file) or return ("", \@lines);
        $header = <$fh>;
        chomp $header if $header;
        while (<$fh>) {
            chomp; next if /^\s*$/;
            push @lines, $_;
        }
        close $fh;
    }
    return ($header, \@lines);
}

if ($action eq 'save_departamento') {
    my $id = $cgi->param('id') || '';
    my $nombre = $cgi->param('nombre') || '';
    $nombre =~ s/\|//g; # limpiar
    if (!$nombre) { responder({ error => 'Nombre es requerido' }); }

    my ($header, $lines) = leer_archivo($rutas->{departamentos});
    my @new_lines;
    my $found = 0;

    if ($id) { # Editar
        foreach my $l (@$lines) {
            my @c = split /\|/, $l;
            if ($c[0] eq $id) {
                $l = "$id|$nombre";
                $found = 1;
            }
            push @new_lines, $l;
        }
        if (!$found) { responder({ error => 'Departamento no encontrado' }); }
    } else { # Nuevo
        $id = get_next_id($rutas->{departamentos});
        @new_lines = @$lines;
        push @new_lines, "$id|$nombre";
    }

    if (actualizar_archivo($rutas->{departamentos}, $header || "ID|NOMBRE_DEPARTAMENTO", \@new_lines)) {
        responder({ success => 1, msg => 'Departamento guardado exitosamente' });
    } else {
        responder({ error => 'Error al guardar archivo' });
    }
}
elsif ($action eq 'delete_departamento') {
    my $id = $cgi->param('id') || '';
    my ($header, $lines) = leer_archivo($rutas->{departamentos});
    my @new_lines = grep { (split /\|/, $_)[0] ne $id } @$lines;
    my (undef, $cat_lines) = leer_archivo($rutas->{categorias});
    my $has_children = grep { (split /\|/, $_)[1] eq $id } @$cat_lines;
    if ($has_children) {
        responder({ error => 'No se puede eliminar porque tiene categorias asignadas' });
    }
    actualizar_archivo($rutas->{departamentos}, $header, \@new_lines);
    responder({ success => 1, msg => 'Departamento eliminado' });
}
elsif ($action eq 'save_categoria') {
    my $id = $cgi->param('id') || '';
    my $id_dep = $cgi->param('id_dep') || '';
    my $nombre = $cgi->param('nombre') || '';
    $nombre =~ s/\|//g;
    if (!$nombre || !$id_dep) { responder({ error => 'Datos requeridos' }); }

    my ($header, $lines) = leer_archivo($rutas->{categorias});
    my @new_lines;
    my $found = 0;

    if ($id) {
        foreach my $l (@$lines) {
            my @c = split /\|/, $l;
            if ($c[0] eq $id) {
                $l = "$id|$id_dep|$nombre";
                $found = 1;
            }
            push @new_lines, $l;
        }
        if (!$found) { responder({ error => 'Categoria no encontrada' }); }
    } else {
        $id = get_next_id($rutas->{categorias});
        @new_lines = @$lines;
        push @new_lines, "$id|$id_dep|$nombre";
    }

    if (actualizar_archivo($rutas->{categorias}, $header || "ID_CAT|ID_DEP|NOMBRE_CATEGORIA", \@new_lines)) {
        responder({ success => 1, msg => 'Categoria guardada' });
    } else {
        responder({ error => 'Error al guardar' });
    }
}
elsif ($action eq 'delete_categoria') {
    my $id = $cgi->param('id') || '';
    my ($header, $lines) = leer_archivo($rutas->{categorias});
    my @new_lines = grep { (split /\|/, $_)[0] ne $id } @$lines;
    my (undef, $item_lines) = leer_archivo($rutas->{items});
    my $has_children = grep { (split /\|/, $_)[1] eq $id } @$item_lines;
    if ($has_children) {
        responder({ error => 'No se puede eliminar porque tiene servicios asignados' });
    }
    actualizar_archivo($rutas->{categorias}, $header, \@new_lines);
    responder({ success => 1, msg => 'Categoria eliminada' });
}
elsif ($action eq 'save_producto') {
    my $id = $cgi->param('id') || '';
    my $nombre = $cgi->param('nombre') || '';
    my $precio = $cgi->param('precio') || '0.00';
    my $cantidad = $cgi->param('cantidad') || '0';
    my $presentacion = $cgi->param('presentacion') || '';
    my $descripcion = $cgi->param('descripcion') || '';
    
    $nombre =~ s/\|//g; $presentacion =~ s/\|//g; $descripcion =~ s/\|//g;
    
    my ($header, $lines) = leer_archivo($rutas->{productos});
    my @new_lines;
    my $found = 0;

    if ($id) {
        foreach my $l (@$lines) {
            my @c = split /\|/, $l;
            if ($c[0] eq $id) {
                $l = "$id|$nombre|$precio|$cantidad|$presentacion|$descripcion";
                $found = 1;
            }
            push @new_lines, $l;
        }
    } else {
        $id = get_next_id($rutas->{productos});
        @new_lines = @$lines;
        push @new_lines, "$id|$nombre|$precio|$cantidad|$presentacion|$descripcion";
    }

    actualizar_archivo($rutas->{productos}, $header || "ID|NOMBRE|PRECIO|CANTIDAD|PRESENTACION|DESCRIPCION", \@new_lines);
    responder({ success => 1, msg => 'Producto guardado' });
}
elsif ($action eq 'delete_producto') {
    my $id = $cgi->param('id') || '';
    my ($header, $lines) = leer_archivo($rutas->{productos});
    my @new_lines = grep { (split /\|/, $_)[0] ne $id } @$lines;
    actualizar_archivo($rutas->{productos}, $header, \@new_lines);
    responder({ success => 1, msg => 'Producto eliminado' });
}
elsif ($action eq 'save_servicio') {
    # Servicios requires updating items AND precios
    my $id_item = $cgi->param('id_item') || '';
    my $id_cat = $cgi->param('id_cat') || '';
    my $sku = $cgi->param('codigo_sku') || '';
    my $concepto = $cgi->param('concepto') || '';
    my $precio = $cgi->param('precio') || '0.00';
    $sku =~ s/\|//g; $concepto =~ s/\|//g;
    
    my ($header_i, $lines_i) = leer_archivo($rutas->{items});
    my ($header_p, $lines_p) = leer_archivo($rutas->{precios});
    
    my @new_i;
    if ($id_item) {
        foreach my $l (@$lines_i) {
            my @c = split /\|/, $l;
            if ($c[0] eq $id_item) {
                $l = "$id_item|$id_cat|$sku|$concepto|0";
            }
            push @new_i, $l;
        }
        
        my @new_p;
        my $updated_precio = 0;
        foreach my $l (@$lines_p) {
            my @c = split /\|/, $l;
            if ($c[1] eq $id_item && $c[3] eq 'DIA') {
                $c[5] = $precio;
                $l = join("|", @c);
                $updated_precio = 1;
            }
            push @new_p, $l;
        }
        if (!$updated_precio) {
            my $id_p = get_next_id($rutas->{precios});
            push @new_p, "$id_p|$id_item|1|DIA|0.00|$precio|0|0";
        }
        actualizar_archivo($rutas->{items}, $header_i, \@new_i);
        actualizar_archivo($rutas->{precios}, $header_p, \@new_p);
        responder({ success => 1, msg => 'Servicio guardado' });
    } else {
        $id_item = get_next_id($rutas->{items});
        push @$lines_i, "$id_item|$id_cat|$sku|$concepto|0";
        my $id_p = get_next_id($rutas->{precios});
        push @$lines_p, "$id_p|$id_item|1|DIA|0.00|$precio|0|0";
        
        actualizar_archivo($rutas->{items}, $header_i || "ID_ITEM|ID_CAT|CODIGO_SKU|CONCEPTO|APLICA_IVA", $lines_i);
        actualizar_archivo($rutas->{precios}, $header_p || "ID_PRECIO|ID_ITEM|ID_PROV|TIPO_TARIFA|COSTO_BASE|PRECIO_PUBLICO|HONORARIO_FIJO|HONORARIO_PORCENTAJE", $lines_p);
        responder({ success => 1, msg => 'Servicio creado' });
    }
}
elsif ($action eq 'delete_servicio') {
    my $id_item = $cgi->param('id') || '';
    my ($header_i, $lines_i) = leer_archivo($rutas->{items});
    my ($header_p, $lines_p) = leer_archivo($rutas->{precios});
    
    my @new_i = grep { (split /\|/, $_)[0] ne $id_item } @$lines_i;
    my @new_p = grep { (split /\|/, $_)[1] ne $id_item } @$lines_p;
    
    actualizar_archivo($rutas->{items}, $header_i, \@new_i);
    actualizar_archivo($rutas->{precios}, $header_p, \@new_p);
    responder({ success => 1, msg => 'Servicio eliminado' });
}
else {
    responder({ error => 'Accion invalida' });
}
