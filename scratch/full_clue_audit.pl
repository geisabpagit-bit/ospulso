#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

my $dir = 'dat/catalogos_CLUE/QTSMP000116';
my $deps_file  = "$dir/departamentos_QTSMP000116.dat";
my $cats_file  = "$dir/categorias_QTSMP000116.dat";
my $items_file = "$dir/catalogo_items_QTSMP000116.dat";
my $precios_file = "$dir/catalogo_precios_QTSMP000116.dat";
my $tarifas_file = "$dir/tipos_tarifas_QTSMP000116.dat";

print "=========================================================\n";
print " AUDITORÍA DE NORMALIZACIÓN CLUE QTSMP000116\n";
print "=========================================================\n\n";

# 1. DEPARTAMENTOS
my %deps;
open my $dh, '<:utf8', $deps_file or die $!;
my $d_count = 0;
while (<$dh>) {
    chomp;
    next if /^ID_DEP/ || /^\s*$/;
    my ($id, $name) = split /\|/;
    if ($deps{$id}) {
        print "[BUG DEPARTAMENTOS] ID_DEP duplicado: $id ($name vs $deps{$id})\n";
    }
    $deps{$id} = $name;
    $d_count++;
}
close $dh;
print "1. DEPARTAMENTOS REGISTRADOS: $d_count\n";
foreach my $did (sort { $a <=> $b } keys %deps) {
    print "   ID_DEP $did: $deps{$did}\n";
}
print "\n";

# 2. CATEGORÍAS
my %cats;
my %cat_dep_map;
my $c_count = 0;
open my $ch, '<:utf8', $cats_file or die $!;
while (<$ch>) {
    chomp;
    next if /^ID_CAT/ || /^\s*$/;
    my ($id, $dep_id, $name) = split /\|/;
    if ($cats{$id}) {
        print "[BUG CATEGORÍAS] ID_CAT duplicado: $id ($name vs $cats{$id}{name})\n";
    }
    unless ($deps{$dep_id}) {
        print "[BUG CATEGORÍAS] ID_CAT $id ($name) tiene ID_DEP HUÉRFANO: $dep_id\n";
    }
    $cats{$id} = { dep_id => $dep_id, dep_name => $deps{$dep_id} // 'HUERFANO', name => $name };
    $cat_dep_map{$id} = $dep_id;
    $c_count++;
}
close $ch;
print "2. CATEGORÍAS REGISTRADAS: $c_count\n\n";

# 3. TARIFAS
my %tarifas;
open my $th, '<:utf8', $tarifas_file or die $!;
while (<$th>) {
    chomp;
    next if /^ID_TIPO_TARIFA/ || /^\s*$/;
    my ($id, $name, $desc, $activo) = split /\|/;
    $tarifas{$id} = $name;
}
close $th;

# 4. ITEMS Y ASIGNACIONES
my %items;
my %skus;
my %cat_item_counts;
my $i_count = 0;
open my $ih, '<:utf8', $items_file or die $!;
while (<$ih>) {
    chomp;
    next if /^ID_ITEM/ || /^\s*$/;
    my ($id, $sku, $cat_id, $concepto, $iva, $indicaciones, $tiempo) = split /\|/, $_, 7;
    
    $i_count++;
    if ($items{$id}) {
        print "[BUG ITEMS] ID_ITEM duplicado: $id ($sku vs $items{$id}{sku})\n";
    }
    if ($skus{$sku}) {
        print "[BUG ITEMS] SKU duplicado: $sku (ID $id vs ID $skus{$sku})\n";
    }
    $skus{$sku} = $id;

    unless ($cats{$cat_id}) {
        print "[BUG ITEMS] ID_ITEM $id ($sku - $concepto) referencia ID_CAT HUÉRFANO: $cat_id\n";
    }
    
    $cat_item_counts{$cat_id}++;
    $items{$id} = {
        sku => $sku,
        cat_id => $cat_id,
        concepto => $concepto,
        iva => $iva,
        indicaciones => $indicaciones,
        tiempo => $tiempo
    };
}
close $ih;
print "3. ITEMS REGISTRADOS: $i_count\n\n";

# Check Categories without items
print "4. CATEGORÍAS SIN ITEMS (VACÍAS/HUÉRFANAS):\n";
my $empty_cats_count = 0;
foreach my $cid (sort { $a <=> $b } keys %cats) {
    unless ($cat_item_counts{$cid}) {
        print "   ID_CAT $cid [$cats{$cid}{name}] (Dep $cats{$cid}{dep_id}: $cats{$cid}{dep_name}) -> 0 items\n";
        $empty_cats_count++;
    }
}
if ($empty_cats_count == 0) {
    print "   (Ninguna, todas las categorías tienen al menos 1 ítem)\n";
}
print "\n";

# 5. ANÁLISIS DE PRECIOS
my %precios_by_item;
open my $ph, '<:utf8', $precios_file or die $!;
my $p_count = 0;
while (<$ph>) {
    chomp;
    next if /^ID_PRECIO/ || /^\s*$/;
    my ($id_precio, $id_item, $id_tarifa, $precio, $costo) = split /\|/;
    $p_count++;
    
    unless ($items{$id_item}) {
        print "[BUG PRECIOS] Precio ID $id_precio referencia ID_ITEM INEXISTENTE: $id_item\n";
    }
    unless ($tarifas{$id_tarifa}) {
        print "[BUG PRECIOS] Precio ID $id_precio referencia TARIFA INEXISTENTE: $id_tarifa\n";
    }
    $precios_by_item{$id_item}{$id_tarifa} = $precio;
}
close $ph;
print "5. REGISTROS DE PRECIOS EN TOTAL: $p_count\n\n";

# Check items missing prices
print "6. ITEMS SIN PRECIO CONFIGURADO:\n";
my $missing_prices_count = 0;
foreach my $iid (sort { $a <=> $b } keys %items) {
    unless ($precios_by_item{$iid}) {
        print "   ID_ITEM $iid ($items{$iid}{sku} - $items{$iid}{concepto}) no tiene ningún precio registrado.\n";
        $missing_prices_count++;
    }
}
if ($missing_prices_count == 0) {
    print "   (Ninguno, todos los ítems tienen al menos una tarifa de precio registrada)\n";
}
print "\n";

# 7. INCONSISTENCIAS DE NOMBRES Y CONCEPTOS
print "7. ANÁLISIS DE CATEGORÍAS DUPLICADAS O INCONSISTENTES ENTRE DEPARTAMENTOS:\n";
my %cat_names;
foreach my $cid (sort { $a <=> $b } keys %cats) {
    my $name = $cats{$cid}{name};
    my $dep_id = $cats{$cid}{dep_id};
    my $dep_name = $cats{$cid}{dep_name};
    push @{$cat_names{$name}}, { id => $cid, dep_id => $dep_id, dep_name => $dep_name };
}

foreach my $name (sort keys %cat_names) {
    if (@{$cat_names{$name}} > 1) {
        print "   Categoría '$name' existe en múltiples departamentos/IDs:\n";
        foreach my $item (@{$cat_names{$name}}) {
            my $cnt = $cat_item_counts{$item->{id}} // 0;
            print "     - ID_CAT $item->{id} en Dep $item->{dep_id} ($item->{dep_name}) -> $cnt items\n";
        }
    }
}
print "\n";

# 8. DETECCIÓN DE PREFIJOS DE SKU MEZCLADOS POR DEPARTAMENTO
print "8. REVISIÓN DE DEPARTAMENTOS CON PREFIJOS MEZCLADOS EN SUS ITEMS:\n";
my %dep_skus;
foreach my $iid (keys %items) {
    my $cat_id = $items{$iid}{cat_id};
    my $dep_id = $cats{$cat_id}{dep_id} // 0;
    my $dep_name = $cats{$cat_id}{dep_name} // 'DESCONOCIDO';
    my $sku = $items{$iid}{sku};
    my $prefix = ($sku =~ /^([A-Z]+)-/)? $1 : 'SIN_PREFIJO';
    $dep_skus{$dep_name}{$prefix}++;
}

foreach my $dname (sort keys %dep_skus) {
    print "   Departamento '$dname':\n";
    foreach my $p (sort keys %{$dep_skus{$dname}}) {
        print "     - Prefijo $p: $dep_skus{$dname}{$p} items\n";
    }
}
