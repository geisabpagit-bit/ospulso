#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");

my $dir = 'dat/catalogos_CLUE/QTSMP000116';
my $deps_file  = "$dir/departamentos_QTSMP000116.dat";
my $cats_file  = "$dir/categorias_QTSMP000116.dat";
my $items_file = "$dir/catalogo_items_QTSMP000116.dat";

my %deps;
open my $dh, '<:utf8', $deps_file or die $!;
while (<$dh>) {
    chomp;
    next if /^ID_DEP/;
    my ($id, $name) = split /\|/;
    $deps{$id} = $name if $id;
}
close $dh;

my %cats;
open my $ch, '<:utf8', $cats_file or die $!;
while (<$ch>) {
    chomp;
    next if /^ID_CAT/;
    my ($id, $dep_id, $name) = split /\|/;
    $cats{$id} = { id => $id, dep_id => $dep_id, name => $name, dep_name => $deps{$dep_id} // 'HUERFANO' } if $id;
}
close $ch;

print "--- DETALLE DE ANOMALÍAS EN CATEGORÍAS E ITEMS ---\n\n";

open my $ih, '<:utf8', $items_file or die $!;
my %sku_prefixes_by_dep;
my %items_by_cat;
my @anomalies;

while (<$ih>) {
    chomp;
    next if /^ID_ITEM/;
    my ($id, $sku, $cat_id, $concepto, $iva, $indicaciones, $tiempo) = split /\|/, $_, 7;
    
    my $cat = $cats{$cat_id};
    unless ($cat) {
        push @anomalies, "Item ID $id ($sku): Categoría ID $cat_id no existe en categorias_QTSMP000116.dat";
        next;
    }

    $items_by_cat{$cat_id}++;
    my $prefix = ($sku =~ /^([A-Z]+)-/)? $1 : 'SIN_PREFIJO';
    
    # Verificaciones específicas de coherencia:
    # 1. En CONSULTAS (ID_DEP 1), los prefijos estándar son CONS. Si es CONC o CONH, registrar observacion.
    if ($cat->{dep_id} == 1 && $prefix ne 'CONS') {
        push @anomalies, "Item ID $id ($sku - $concepto): En departamento CONSULTAS pero usa prefijo '$prefix'";
    }
    # 2. En SERVICIOS (ID_DEP 2), el prefijo debe ser SERV.
    elsif ($cat->{dep_id} == 2 && $prefix ne 'SERV') {
        push @anomalies, "Item ID $id ($sku - $concepto): En departamento SERVICIOS pero usa prefijo '$prefix'";
    }
    # 3. En LABORATORIO SANTIAGO (ID_DEP 3), el prefijo es LABS o LAB.
    elsif ($cat->{dep_id} == 3 && $prefix ne 'LABS' && $prefix ne 'LAB') {
        push @anomalies, "Item ID $id ($sku - $concepto): En LABORATORIO SANTIAGO pero usa prefijo '$prefix'";
    }
    # 4. En IMAGENOLOGIA (ID_DEP 4), el prefijo debe ser RX.
    elsif ($cat->{dep_id} == 4 && $prefix ne 'RX') {
        push @anomalies, "Item ID $id ($sku - $concepto): En IMAGENOLOGIA (Rayos X) pero usa prefijo '$prefix'";
    }
    # 5. En LABORATORIO FRANCISCO (ID_DEP 5), el prefijo debe ser LABF.
    elsif ($cat->{dep_id} == 5 && $prefix ne 'LABF') {
        push @anomalies, "Item ID $id ($sku - $concepto): En LABORATORIO FRANCISCO pero usa prefijo '$prefix'";
    }
    # 6. En ULTRASONIDO (ID_DEP 6), los prefijos son USG o US.
    elsif ($cat->{dep_id} == 6 && $prefix ne 'USG' && $prefix ne 'US') {
        push @anomalies, "Item ID $id ($sku - $concepto): En ULTRASONIDO pero usa prefijo '$prefix'";
    }
    # 7. En CIRUGIAS (ID_DEP 7), el prefijo es QX.
    elsif ($cat->{dep_id} == 7 && $prefix ne 'QX') {
        push @anomalies, "Item ID $id ($sku - $concepto): En CIRUGIAS pero usa prefijo '$prefix'";
    }
    # 8. En PATOLOGIA DR PINEDO (ID_DEP 8), el prefijo es PATP.
    elsif ($cat->{dep_id} == 8 && $prefix ne 'PATP') {
        push @anomalies, "Item ID $id ($sku - $concepto): En PATOLOGIA DR PINEDO pero usa prefijo '$prefix'";
    }
    # 9. En PATOLOGIA DR GALLEGOS (ID_DEP 9), el prefijo es PATG.
    elsif ($cat->{dep_id} == 9 && $prefix ne 'PATG') {
        push @anomalies, "Item ID $id ($sku - $concepto): En PATOLOGIA DR GALLEGOS pero usa prefijo '$prefix'";
    }
}
close $ih;

print "Total de observaciones registradas: " . scalar(@anomalies) . "\n\n";
foreach my $a (@anomalies) {
    print " - $a\n";
}

print "\n--- REVISIÓN DE CATEGORÍAS DUPLICADAS / ASIGNACIONES DE DEPARTAMENTO ---\n";
my %cat_by_name;
foreach my $cid (sort { $a <=> $b } keys %cats) {
    push @{$cat_by_name{$cats{$cid}{name}}}, $cats{$cid};
}

foreach my $name (sort keys %cat_by_name) {
    my @list = @{$cat_by_name{$name}};
    if (@list > 1) {
        print "Categoría Nombres Coincidentes: '$name'\n";
        foreach my $c (@list) {
            my $cnt = $items_by_cat{$c->{id}} // 0;
            print "   - ID_CAT $c->{id} | ID_DEP $c->{dep_id} ($c->{dep_name}) | Items: $cnt\n";
        }
    }
}
