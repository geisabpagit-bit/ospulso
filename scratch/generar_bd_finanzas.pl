#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

# Archivos de datos
my $file_gastos = 'dat/gastos.dat';
my $file_facturas = 'dat/facturacion.dat';
my $file_cat = 'dat/categorias.dat';
my $file_subcat = 'dat/sub_categoria.dat';
my $file_subcat3 = 'dat/sub_categoria_nivel3.dat';

# Inicializar archivos vacíos
open my $fh1, '>', $file_gastos; close $fh1;
open my $fh2, '>', $file_facturas; close $fh2;

# Datos de Categorías
my @categorias = (
    "1|Operativos|Gastos del día a día",
    "2|Marketing|Publicidad y ventas",
    "3|Inmobiliario|Renta y mantenimiento",
    "4|Financieros|Comisiones e impuestos"
);
open my $fh3, '>', $file_cat;
print $fh3 "$_\n" for @categorias;
close $fh3;

# Datos de Subcategorías Nivel 2
my @subcategorias = (
    "1|1|Nómina|Pago a empleados",
    "2|1|Material Clínico|Insumos dentales",
    "3|2|Redes Sociales|Pauta digital",
    "4|3|Renta Local|Pago de alquiler",
    "5|3|Servicios Públicos|Agua, luz, internet",
    "6|4|Comisiones|Terminales bancarias"
);
open my $fh4, '>', $file_subcat;
print $fh4 "$_\n" for @subcategorias;
close $fh4;

# Datos de Subcategorías Nivel 3
my @subcat3 = (
    "1|1|Salario Fijo",
    "2|1|Bonos y Comisiones",
    "3|2|Desechables",
    "4|2|Instrumental",
    "5|5|Energía Eléctrica",
    "6|5|Internet/Telefonía"
);
open my $fh5, '>', $file_subcat3;
print $fh5 "$_\n" for @subcat3;
close $fh5;

print "Bases de datos financieras creadas exitosamente.\n";
