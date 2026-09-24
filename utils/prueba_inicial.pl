#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Encode qw(encode_utf8);

binmode STDOUT, ":utf8";

# Archivos
my $usuarios_file   = "../dat/usuarios.dat";
my $pacientes_file  = "../dat/pacientes.dat";
my $citas_file      = "../dat/citas.dat";
my $tokens_file     = "../dat/tokens_google.dat";

# --- Crear usuario médico ---
open my $u, '>:encoding(UTF-8)', $usuarios_file or die "No se puede abrir $usuarios_file: $!";
print $u "1!Dr. Juan Pérez!juan.perez\@gmail.com!clavehash!1!Medico!\n";
close $u;

# --- Crear paciente ---
open my $p, '>:encoding(UTF-8)', $pacientes_file or die "No se puede abrir $pacientes_file: $!";
print $p "18!1!Abby Massiel Garay Villegas!GAVA120609!GAVA120609!abby\@gmail.com!2012-06-09!Femenino!Estudiante!Soltero!Mexicana!0+!55-3142-2575\n";
close $p;

# --- Crear cita (sin event_id todavía) ---
open my $c, '>:encoding(UTF-8)', $citas_file or die "No se puede abrir $citas_file: $!";
print $c "1734901234567|1|18|2025-12-23|10:00|11:00|Consulta general|Notas iniciales|Programada|\n";
close $c;

# --- Crear token ficticio (simulación de autorización Google) ---
open my $t, '>:encoding(UTF-8)', $tokens_file or die "No se puede abrir $tokens_file: $!";
print $t "1|REFRESH_TOKEN_DE_PRUEBA\n";
close $t;

print encode_utf8("✅ Datos de prueba creados:\n");
print encode_utf8("- Usuario médico en $usuarios_file\n");
print encode_utf8("- Paciente en $pacientes_file\n");
print encode_utf8("- Cita en $citas_file\n");
print encode_utf8("- Token ficticio en $tokens_file\n");
