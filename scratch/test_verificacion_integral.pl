#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/..";
use JSON qw(decode_json encode_json);

binmode STDOUT, ':utf8';

print "=== PRUEBA 1: Verificar items de Medicina General en catalogo_items_QTSMP000116.dat ===\n";
my $items_file = "$FindBin::Bin/../dat/catalogos_CLUE/QTSMP000116/catalogo_items_QTSMP000116.dat";
my $precios_file = "$FindBin::Bin/../dat/catalogos_CLUE/QTSMP000116/catalogo_precios_QTSMP000116.dat";

my @items_mg;
if (open(my $fh, '<:encoding(UTF-8)', $items_file)) {
    while (my $line = <$fh>) {
        chomp $line;
        my @f = split(/\|/, $line, -1);
        if ($f[2] eq '59') {
            push @items_mg, { id => $f[0], sku => $f[1], concepto => $f[3] };
        }
    }
    close $fh;
}
print "Total items encontrados con ID_CAT = 59: " . scalar(@items_mg) . "\n";
foreach (@items_mg) {
    print " - ID: $_->{id} | Concepto: $_->{concepto}\n";
}

print "\n=== PRUEBA 2: Verificar precios ESTANDAR y MUNICIPIO para los items de Medicina General ===\n";
my %precios_map;
if (open(my $fhp, '<:encoding(UTF-8)', $precios_file)) {
    while (my $line = <$fhp>) {
        chomp $line;
        my @f = split(/\|/, $line, -1);
        $precios_map{$f[1]}->{$f[2]} = $f[3];
    }
    close $fhp;
}

my $precios_ok = 1;
foreach my $it (@items_mg) {
    my $p_est = $precios_map{$it->{id}}->{ESTANDAR} // 'N/D';
    my $p_mun = $precios_map{$it->{id}}->{MUNICIPIO} // 'N/D';
    print " Item $it->{id}: ESTANDAR = $p_est | MUNICIPIO = $p_mun\n";
    if ($p_mun ne '210.0') {
        $precios_ok = 0;
    }
}
print "Validación precios Municipio $210.0: " . ($precios_ok ? "OK" : "FALLÓ") . "\n";

print "\n=== PRUEBA 3: Verificar contadores CLUE QTSMP000116 ===\n";
my $cont_pub = "$FindBin::Bin/../dat/catalogos_CLUE/QTSMP000116/contadores_recibos_publicos_QTSMP000116.dat";
my $cont_priv = "$FindBin::Bin/../dat/catalogos_CLUE/QTSMP000116/contadores_recibos_privados_QTSMP000116.dat";

open(my $fc1, '<:encoding(UTF-8)', $cont_pub) or die $!;
my $c_pub_content = do { local $/; <$fc1> }; close $fc1;
open(my $fc2, '<:encoding(UTF-8)', $cont_priv) or die $!;
my $c_priv_content = do { local $/; <$fc2> }; close $fc2;

print "Contador Publico:\n$c_pub_content\n";
print "Contador Privado:\n$c_priv_content\n";

print "\n=== PRUEBA 4: Simular resolución de médico para Folio 2 ('12') en generar_corte_caja.pl ===\n";
# En el folio 2, id_med era '12'.
# Comprobamos cómo resolver_nombre_medico_recibo maneja '12':
require "$FindBin::Bin/../utils/catalogo_org_utils.pl";
my $org_clues = 'QTSMP000116';
my $it_file = catalogo_org_utils::obtener_rutas_por_clue($org_clues)->{items};
my %items_cat;
if (-e $it_file && open(my $fi, '<:encoding(UTF-8)', $it_file)) {
    while (my $l = <$fi>) {
        chomp $l;
        my @f = split(/\|/, $l, -1);
        $items_cat{$f[0]} = $f[3] if $f[0];
    }
    close $fi;
}
my $conc_12 = $items_cat{12} || '';
print "Item 12 concepto en catálogo: $conc_12\n";
if ($conc_12 =~ /-\s*(.+)$/) {
    my $cand = $1;
    $cand =~ s/\s*\(.*?\)//g;
    print "Médico extraído para '12': '$cand'\n";
}

print "\n=== PRUEBA COMPLETADA ===\n";
