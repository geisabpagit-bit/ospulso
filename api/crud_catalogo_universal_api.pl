#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use Encode qw(decode_utf8 is_utf8);
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

my $session_data = check_session($cgi);
if (!$session_data || !$session_data->{session_ok}) {
    responder({ error => 'No autorizado' });
}

my $role = $session_data->{role} || '';

# API-RBAC: Verificación estricta de Roles Autorizados
if ($role ne 'Administrador Organizacion' && $role ne 'Administrador Global' && $role !~ /Recepcionista/i) {
    responder({ error => 'Acceso denegado. Se requieren permisos de Administrador u Operación.' });
}

my $id_empresa = $session_data->{id_empresa};
if (!defined $id_empresa || $id_empresa eq '') {
    $id_empresa = 0; # ID por defecto para Administrador Global
}

my $id_raiz = catalogo_org_utils::resolver_id_raiz_catalogo($id_empresa);
my $rutas = catalogo_org_utils::obtener_rutas_catalogo($id_raiz);

if (!$rutas->{is_universal}) {
    responder({ error => 'Esta organizacion no cuenta con un catalogo universal.' });
}

my $action = $cgi->param('action') || '';

sub sanitizar_campo {
    my ($val) = @_;
    return '' unless defined $val;
    eval { $val = decode_utf8($val) unless is_utf8($val); };
    $val =~ s/\|//g;
    $val =~ s/[\r\n]+/ /g;
    $val =~ s/^\s+|\s+$//g;
    return $val;
}

sub get_next_id {
    my ($file) = @_;
    return 1 unless -e $file;
    open(my $fh, '<:raw :encoding(UTF-8)', $file) or return 1;
    <$fh>; # skip header
    my $max = 0;
    while (<$fh>) {
        $_ =~ s/[\r\n]+$//;
        next if /^\s*$/;
        my @c = split /\|/, $_, -1;
        $max = $c[0] if defined $c[0] && $c[0] =~ /^\d+$/ && $c[0] > $max;
    }
    close $fh;
    return $max + 1;
}

sub actualizar_archivo {
    my ($file, $header, $lines_ref) = @_;
    return 0 unless $file;
    open(my $fh, '>:raw :encoding(UTF-8)', $file) or return 0;
    flock($fh, LOCK_EX);
    $header =~ s/[\r\n]+$//;
    print $fh "$header\n";
    foreach my $line (@$lines_ref) {
        $line =~ s/[\r\n]+$//;
        print $fh "$line\n";
    }
    flock($fh, LOCK_UN);
    close $fh;
    return 1;
}

sub leer_archivo {
    my ($file) = @_;
    my @lines = ();
    my $header = "";
    if (-e $file) {
        open(my $fh, '<:raw :encoding(UTF-8)', $file) or return ("", \@lines);
        $header = <$fh>;
        $header =~ s/[\r\n]+$// if $header;
        while (<$fh>) {
            $_ =~ s/[\r\n]+$//;
            next if /^\s*$/;
            push @lines, $_;
        }
        close $fh;
    }
    return ($header, \@lines);
}

if ($action eq 'get_servicio') {
    my $id_item = $cgi->param('id_item') || '';
    if (!$id_item) { responder({ error => 'ID de servicio requerido.' }); }

    my ($header_i, $lines_i) = leer_archivo($rutas->{items});
    my ($header_p, $lines_p) = leer_archivo($rutas->{precios});
    my ($header_c, $lines_c) = leer_archivo($rutas->{categorias});

    my $item_encontrado;
    foreach my $l (@$lines_i) {
        my @c = split /\|/, $l, -1;
        if ($c[0] eq $id_item) {
            # ID_ITEM|CODIGO_SKU|ID_CAT|CONCEPTO|APLICA_IVA|INDICACIONES|TIEMPO_ENTREGA
            $item_encontrado = {
                id_item        => $c[0],
                codigo_sku     => $c[1] // '',
                id_cat         => $c[2] // '',
                concepto       => $c[3] // '',
                aplica_iva     => ($c[4] && $c[4] eq '1') ? 1 : 0,
                indicaciones   => $c[5] // '',
                tiempo_entrega => $c[6] // '',
                tarifas        => []
            };
            last;
        }
    }

    if (!$item_encontrado) {
        responder({ error => 'Servicio no encontrado.' });
    }

    # Resolver id_dep a través de la categoría
    my $id_dep = '';
    foreach my $cl (@$lines_c) {
        my @cc = split /\|/, $cl, -1;
        if ($cc[0] eq $item_encontrado->{id_cat}) {
            $id_dep = $cc[1];
            last;
        }
    }
    $item_encontrado->{id_dep} = $id_dep;

    # Extraer todas las tarifas asociadas a este ítem
    foreach my $pl (@$lines_p) {
        my @pc = split /\|/, $pl, -1;
        if ($pc[1] eq $id_item) {
            # ID_PRECIO|ID_ITEM|TIPO_TARIFA|PRECIO_PUBLICO|COSTO_PROVEEDOR|ID_PROV
            push @{$item_encontrado->{tarifas}}, {
                id_precio       => $pc[0],
                id_item         => $pc[1],
                tipo_tarifa     => $pc[2] // 'ESTANDAR',
                precio_publico  => $pc[3] // '0.00',
                costo_proveedor => $pc[4] // '0.00',
                id_prov         => $pc[5] // 1
            };
        }
    }

    responder({ success => 1, servicio => $item_encontrado });
}
elsif ($action eq 'save_departamento') {
    my $id = sanitizar_campo($cgi->param('id'));
    my $nombre = uc(sanitizar_campo($cgi->param('nombre')));
    if (!$nombre) { responder({ error => 'Nombre es requerido' }); }

    my ($header, $lines) = leer_archivo($rutas->{departamentos});
    my @new_lines;
    my $found = 0;

    if ($id) { # Editar
        foreach my $l (@$lines) {
            my @c = split /\|/, $l, -1;
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
    my $id = sanitizar_campo($cgi->param('id'));
    my ($header, $lines) = leer_archivo($rutas->{departamentos});
    my @new_lines = grep { (split /\|/, $_, -1)[0] ne $id } @$lines;
    my (undef, $cat_lines) = leer_archivo($rutas->{categorias});
    my $has_children = grep { (split /\|/, $_, -1)[1] eq $id } @$cat_lines;
    if ($has_children) {
        responder({ error => 'No se puede eliminar porque tiene categorias asignadas' });
    }
    actualizar_archivo($rutas->{departamentos}, $header, \@new_lines);
    responder({ success => 1, msg => 'Departamento eliminado' });
}
elsif ($action eq 'save_categoria') {
    my $id = sanitizar_campo($cgi->param('id'));
    my $id_dep = sanitizar_campo($cgi->param('id_dep'));
    my $nombre = uc(sanitizar_campo($cgi->param('nombre')));
    if (!$nombre || !$id_dep) { responder({ error => 'Datos requeridos' }); }

    my ($header, $lines) = leer_archivo($rutas->{categorias});
    my @new_lines;
    my $found = 0;

    if ($id) {
        foreach my $l (@$lines) {
            my @c = split /\|/, $l, -1;
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
    my $id = sanitizar_campo($cgi->param('id'));
    my ($header, $lines) = leer_archivo($rutas->{categorias});
    my @new_lines = grep { (split /\|/, $_, -1)[0] ne $id } @$lines;
    my (undef, $item_lines) = leer_archivo($rutas->{items});
    my $has_children = grep { (split /\|/, $_, -1)[2] eq $id } @$item_lines; # ID_CAT es columna 2 en items
    if ($has_children) {
        responder({ error => 'No se puede eliminar porque tiene servicios asignados' });
    }
    actualizar_archivo($rutas->{categorias}, $header, \@new_lines);
    responder({ success => 1, msg => 'Categoria eliminada' });
}
elsif ($action eq 'save_producto') {
    my $id = sanitizar_campo($cgi->param('id'));
    my $nombre = uc(sanitizar_campo($cgi->param('nombre')));
    my $precio = sanitizar_campo($cgi->param('precio')) || '0.00';
    my $cantidad = sanitizar_campo($cgi->param('cantidad')) || '0';
    my $presentacion = sanitizar_campo($cgi->param('presentacion'));
    my $descripcion = sanitizar_campo($cgi->param('descripcion'));
    
    my ($header, $lines) = leer_archivo($rutas->{productos});
    my @new_lines;
    my $found = 0;

    if ($id) {
        foreach my $l (@$lines) {
            my @c = split /\|/, $l, -1;
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
    my $id = sanitizar_campo($cgi->param('id'));
    my ($header, $lines) = leer_archivo($rutas->{productos});
    my @new_lines = grep { (split /\|/, $_, -1)[0] ne $id } @$lines;
    actualizar_archivo($rutas->{productos}, $header, \@new_lines);
    responder({ success => 1, msg => 'Producto eliminado' });
}
elsif ($action eq 'save_tipo_tarifa') {
    my $id            = sanitizar_campo($cgi->param('id'));
    my $clave         = uc(sanitizar_campo($cgi->param('clave')));
    my $nombre_tarifa = sanitizar_campo($cgi->param('nombre_tarifa') // $cgi->param('nombre'));
    my $descripcion   = sanitizar_campo($cgi->param('descripcion'));
    my $activo        = defined $cgi->param('activo') ? ($cgi->param('activo') ? 1 : 0) : 1;

    # Limpiar clave: solo alfanuméricos y guiones bajos
    $clave =~ s/\s+/_/g;
    $clave =~ s/[^A-Z0-9_]//g;

    if (!$clave || !$nombre_tarifa) {
        responder({ error => 'La clave y el nombre de la tarifa son obligatorios.' });
    }

    my ($header, $lines) = leer_archivo($rutas->{tipos_tarifas});
    $header ||= "ID_TARIFA|CLAVE|NOMBRE_TARIFA|DESCRIPCION|ACTIVO";

    my @new_lines;
    my $found = 0;

    # Validar que la clave no esté duplicada en otro registro
    foreach my $l (@$lines) {
        my @c = split /\|/, $l, -1;
        if ($c[1] eq $clave && (!$id || $c[0] ne $id)) {
            responder({ error => "Ya existe un tipo de tarifa registrado con la clave '$clave'." });
        }
    }

    if ($id) {
        foreach my $l (@$lines) {
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id) {
                # ID_TARIFA|CLAVE|NOMBRE_TARIFA|DESCRIPCION|ACTIVO
                # Si es ESTANDAR, MUNICIPIO o URGENCIAS, proteger la clave para que no se altere accidentalmente
                if ($c[1] =~ /^(ESTANDAR|MUNICIPIO|URGENCIAS)$/i) {
                    $clave = $c[1]; # Mantener clave de sistema protegida
                }
                $l = "$id|$clave|$nombre_tarifa|$descripcion|$activo";
                $found = 1;
            }
            push @new_lines, $l;
        }
        if (!$found) { responder({ error => 'Tipo de tarifa no encontrado.' }); }
    } else {
        $id = get_next_id($rutas->{tipos_tarifas});
        @new_lines = @$lines;
        push @new_lines, "$id|$clave|$nombre_tarifa|$descripcion|$activo";
    }

    if (actualizar_archivo($rutas->{tipos_tarifas}, $header, \@new_lines)) {
        responder({ success => 1, msg => 'Tipo de tarifa guardado exitosamente.' });
    } else {
        responder({ error => 'Error al guardar el archivo de tipos de tarifa.' });
    }
}
elsif ($action eq 'delete_tipo_tarifa') {
    my $id = sanitizar_campo($cgi->param('id'));
    if (!$id) { responder({ error => 'ID de tarifa no especificado.' }); }

    my ($header, $lines) = leer_archivo($rutas->{tipos_tarifas});
    my $tarifa_a_borrar;
    foreach my $l (@$lines) {
        my @c = split /\|/, $l, -1;
        if ($c[0] eq $id) {
            $tarifa_a_borrar = \@c;
            last;
        }
    }

    if (!$tarifa_a_borrar) {
        responder({ error => 'Tipo de tarifa no encontrado.' });
    }

    my $clave_tarifa = $tarifa_a_borrar->[1];

    # Protección de tarifas base del sistema
    if ($clave_tarifa =~ /^(ESTANDAR|MUNICIPIO|URGENCIAS)$/i) {
        responder({ error => "La tarifa '$clave_tarifa' es parte de la arquitectura del sistema y no puede eliminarse." });
    }

    # Verificar si está asignada en el catálogo de precios
    if (-e $rutas->{precios}) {
        my (undef, $precios_lines) = leer_archivo($rutas->{precios});
        my $en_uso = grep { (split /\|/, $_, -1)[2] eq $clave_tarifa } @$precios_lines;
        if ($en_uso) {
            responder({ error => "No se puede eliminar la tarifa '$clave_tarifa' porque actualmente está asignada a uno o más servicios ($en_uso asignación(es)). Modifique o elimine los precios asociados primero." });
        }
    }

    my @new_lines = grep { (split /\|/, $_, -1)[0] ne $id } @$lines;
    if (actualizar_archivo($rutas->{tipos_tarifas}, $header, \@new_lines)) {
        responder({ success => 1, msg => "Tipo de tarifa '$clave_tarifa' eliminado exitosamente." });
    } else {
        responder({ error => 'Error al actualizar el archivo de tipos de tarifas.' });
    }
}
elsif ($action eq 'save_servicio') {
    my $id_item        = sanitizar_campo($cgi->param('id_item'));
    my $id_cat         = sanitizar_campo($cgi->param('id_cat'));
    my $sku            = uc(sanitizar_campo($cgi->param('codigo_sku')));
    my $concepto       = uc(sanitizar_campo($cgi->param('concepto')));
    my $aplica_iva     = sanitizar_campo($cgi->param('aplica_iva')) ? 1 : 0;
    my $indicaciones   = sanitizar_campo($cgi->param('indicaciones'));
    my $tiempo_entrega = sanitizar_campo($cgi->param('tiempo_entrega'));
    my $tarifas_json   = $cgi->param('tarifas_json') || '';
    my $precio_legado  = sanitizar_campo($cgi->param('precio'));

    if (!$id_cat || !$concepto) {
        responder({ error => 'Categoría y Concepto son campos obligatorios.' });
    }

    $indicaciones   ||= 'Sin preparación previa';
    $tiempo_entrega ||= 'Inmediato';

    my @tarifas_input = ();
    if ($tarifas_json) {
        eval {
            my $parsed = decode_json($tarifas_json);
            if (ref($parsed) eq 'ARRAY') {
                @tarifas_input = @$parsed;
            }
        };
    }

    # Compatibilidad con formularios legados de precio simple
    if (!@tarifas_input && defined $precio_legado && $precio_legado ne '') {
        push @tarifas_input, {
            tipo_tarifa => 'ESTANDAR',
            precio      => $precio_legado,
            costo       => 0.00
        };
    }

    if (!@tarifas_input) {
        responder({ error => 'Debe ingresar al menos una tarifa válida para el servicio.' });
    }

    # Validación de montos (se permite tarifa en $0.00 para esquemas donde el servicio no está disponible)
    my $tiene_precio_positivo = 0;
    foreach my $t (@tarifas_input) {
        my $p = (defined $t->{precio} && $t->{precio} ne '') ? $t->{precio} : ($t->{precio_publico} // 0);
        if ($p < 0) {
            my $nom_t = $t->{tipo_tarifa} || 'DESCONOCIDA';
            responder({ error => "El precio de la tarifa $nom_t no puede ser negativo." });
        }
        if ($p > 0) {
            $tiene_precio_positivo = 1;
        }
    }

    if (!$tiene_precio_positivo) {
        responder({ error => 'El servicio debe contar con al menos una tarifa con precio mayor a $0.00.' });
    }

    my ($header_i, $lines_i) = leer_archivo($rutas->{items});
    my ($header_p, $lines_p) = leer_archivo($rutas->{precios});

    $header_i ||= "ID_ITEM|CODIGO_SKU|ID_CAT|CONCEPTO|APLICA_IVA|INDICACIONES|TIEMPO_ENTREGA";
    $header_p ||= "ID_PRECIO|ID_ITEM|TIPO_TARIFA|PRECIO_PUBLICO|COSTO_PROVEEDOR|ID_PROV";

    my @new_i;
    my $es_nuevo = 0;

    if ($id_item) {
        my $encontrado = 0;
        foreach my $l (@$lines_i) {
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id_item) {
                # ID_ITEM|CODIGO_SKU|ID_CAT|CONCEPTO|APLICA_IVA|INDICACIONES|TIEMPO_ENTREGA
                $l = "$id_item|$sku|$id_cat|$concepto|$aplica_iva|$indicaciones|$tiempo_entrega";
                $encontrado = 1;
            }
            push @new_i, $l;
        }
        if (!$encontrado) { responder({ error => 'Servicio no encontrado para actualizar.' }); }
    } else {
        $es_nuevo = 1;
        $id_item = get_next_id($rutas->{items});
        if (!$sku) {
            $sku = "SRV-" . sprintf("%04d", $id_item);
        }
        @new_i = @$lines_i;
        # ID_ITEM|CODIGO_SKU|ID_CAT|CONCEPTO|APLICA_IVA|INDICACIONES|TIEMPO_ENTREGA
        push @new_i, "$id_item|$sku|$id_cat|$concepto|$aplica_iva|$indicaciones|$tiempo_entrega";
    }

    # Mapear tarifas existentes para preservar ID_PRECIO e ID_PROV
    my %precios_existentes;
    foreach my $l (@$lines_p) {
        my @c = split /\|/, $l, -1;
        if ($c[1] eq $id_item) {
            $precios_existentes{uc($c[2])} = {
                id_precio => $c[0],
                id_prov   => $c[5] || 1,
                costo     => $c[4] || '0.00'
            };
        }
    }

    # Filtrar todas las tarifas que NO pertenecen a este ítem
    my @new_p = grep { (split /\|/, $_, -1)[1] ne $id_item } @$lines_p;

    # Insertar/actualizar las tarifas indicadas
    my $next_id_precio = get_next_id($rutas->{precios});
    my %tipos_procesados;

    foreach my $t (@tarifas_input) {
        my $tipo = uc(sanitizar_campo($t->{tipo_tarifa} || 'ESTANDAR'));
        next if $tipos_procesados{$tipo}++;

        my $p_val = (defined $t->{precio} && $t->{precio} ne '') ? $t->{precio} : ($t->{precio_publico} || 0);
        my $c_val = (defined $t->{costo} && $t->{costo} ne '') ? $t->{costo} : ($t->{costo_proveedor} || 0);

        my $precio_pub = sprintf("%.2f", $p_val);
        my $costo_prov = sprintf("%.2f", $c_val);

        my $id_p;
        my $id_prov = 1;
        if ($precios_existentes{$tipo}) {
            $id_p    = $precios_existentes{$tipo}->{id_precio};
            $id_prov = $precios_existentes{$tipo}->{id_prov} || 1;
        } else {
            $id_p = $next_id_precio++;
        }

        # ID_PRECIO|ID_ITEM|TIPO_TARIFA|PRECIO_PUBLICO|COSTO_PROVEEDOR|ID_PROV
        push @new_p, "$id_p|$id_item|$tipo|$precio_pub|$costo_prov|$id_prov";
    }

    # Guardado atómico en ambos archivos
    if (!actualizar_archivo($rutas->{items}, $header_i, \@new_i)) {
        responder({ error => 'Fallo al escribir en catálogo de ítems.' });
    }
    if (!actualizar_archivo($rutas->{precios}, $header_p, \@new_p)) {
        responder({ error => 'Fallo al escribir en catálogo de precios.' });
    }

    responder({
        success => 1,
        msg => $es_nuevo ? 'Servicio creado exitosamente con sus tarifas.' : 'Servicio actualizado exitosamente.',
        id_item => $id_item
    });
}
elsif ($action eq 'delete_servicio') {
    my $id_item = sanitizar_campo($cgi->param('id_item') // $cgi->param('id'));
    if (!$id_item) {
        responder({ error => 'ID de servicio no especificado.' });
    }
    my ($header_i, $lines_i) = leer_archivo($rutas->{items});
    my ($header_p, $lines_p) = leer_archivo($rutas->{precios});
    
    my @new_i = grep { (split /\|/, $_, -1)[0] ne $id_item } @$lines_i;
    my @new_p = grep { (split /\|/, $_, -1)[1] ne $id_item } @$lines_p;
    
    actualizar_archivo($rutas->{items}, $header_i, \@new_i);
    actualizar_archivo($rutas->{precios}, $header_p, \@new_p);
    responder({ success => 1, msg => 'Servicio eliminado exitosamente.' });
}
else {
    responder({ error => 'Accion invalida' });
}
