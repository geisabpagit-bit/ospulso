#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use File::Spec;
use FindBin;

binmode STDOUT, ':utf8';

my $items_file = 'c:/xampp/htdocs/ospulso/dat/catalogos_CLUE/QTSMP000116/catalogo_items_QTSMP000116.dat';
my $precios_file = 'c:/xampp/htdocs/ospulso/dat/catalogos_CLUE/QTSMP000116/catalogo_precios_QTSMP000116.dat';

my @medicos_gral = (
    { id_legacy => 6,  nombre => 'DRA CLAUDIA CASTILLO ANDRADE' },
    { id_legacy => 11, nombre => 'DRA DIANA HERNANDEZ GARCIA' },
    { id_legacy => 27, nombre => 'DR LUIS ALBERTO VARGAS LOPEZ' },
    { id_legacy => 37, nombre => 'DRA BELEN ROMERO' },
    { id_legacy => 52, nombre => 'DRA HYPATIA GUILLEN' },
    { id_legacy => 53, nombre => 'DR CESAR JIMENEZ COVALLES' },
    { id_legacy => 54, nombre => 'DRA ALEJANDRA CONTRERAS' },
    { id_legacy => 57, nombre => 'DRA VIRIDIANA GARCIA' },
    { id_legacy => 62, nombre => 'DR JERONIMO MEDINA' },
    { id_legacy => 63, nombre => 'DR GABRIEL ALEJANDRO REYNA FLORES' },
    { id_legacy => 64, nombre => 'DRA JANETH AREVALO' }
);

# 1. Leer items actuales para no duplicar
open(my $fhi, '<:encoding(UTF-8)', $items_file) or die "Cannot open $items_file: $!";
my @items = <$fhi>;
close $fhi;

my %existentes;
my $max_item_id = 0;
foreach my $l (@items) {
    chomp $l;
    next unless $l;
    my @f = split(/\|/, $l, -1);
    if ($f[0] =~ /^\d+$/ && $f[0] > $max_item_id) {
        $max_item_id = $f[0];
    }
    $existentes{uc($f[3])} = 1 if $f[3];
}

my @nuevos_items;
my @nuevos_precios;

# 2. Leer precios actuales para max_precio_id
open(my $fhp, '<:encoding(UTF-8)', $precios_file) or die "Cannot open $precios_file: $!";
my @precios = <$fhp>;
close $fhp;

my $max_precio_id = 0;
foreach my $l (@precios) {
    chomp $l;
    next unless $l;
    my @f = split(/\|/, $l, -1);
    if ($f[0] =~ /^\d+$/ && $f[0] > $max_precio_id) {
        $max_precio_id = $f[0];
    }
}

print "Max item ID actual: $max_item_id\n";
print "Max precio ID actual: $max_precio_id\n";

foreach my $m (@medicos_gral) {
    my $concepto = "CONSULTA MEDICINA GENERAL - $m->{nombre}";
    if ($existentes{uc($concepto)}) {
        print "Ya existe concepto: $concepto\n";
        next;
    }
    $max_item_id++;
    my $item_id = $max_item_id;
    my $sku = sprintf("CONS-%04d", $item_id);
    # ID_ITEM|CODIGO_SKU|ID_CAT|CONCEPTO|APLICA_IVA|INDICACIONES|TIEMPO_ENTREGA
    my $linea_item = "$item_id|$sku|59|$concepto|0|Sin preparación previa|Inmediato";
    push @nuevos_items, $linea_item;

    # Precios: ESTANDAR $500.0, MUNICIPIO $210.0
    # ID_PRECIO|ID_ITEM|TIPO_TARIFA|PRECIO_PUBLICO|COSTO_PROVEEDOR|ID_PROV
    $max_precio_id++;
    push @nuevos_precios, "$max_precio_id|$item_id|ESTANDAR|500.0|0.0|1";
    $max_precio_id++;
    push @nuevos_precios, "$max_precio_id|$item_id|MUNICIPIO|210.0|0.0|1";
}

if (@nuevos_items) {
    print "Agregando " . scalar(@nuevos_items) . " items a $items_file...\n";
    open(my $out_i, '>>:encoding(UTF-8)', $items_file) or die $!;
    foreach (@nuevos_items) {
        print $out_i "$_\n";
    }
    close $out_i;

    print "Agregando " . scalar(@nuevos_precios) . " precios a $precios_file...\n";
    open(my $out_p, '>>:encoding(UTF-8)', $precios_file) or die $!;
    foreach (@nuevos_precios) {
        print $out_p "$_\n";
    }
    close $out_p;
    print "Completado exitosamente!\n";
} else {
    print "No hay nuevos items por agregar.\n";
}
