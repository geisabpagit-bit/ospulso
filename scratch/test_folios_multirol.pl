#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

binmode STDOUT, ':utf8';

print "=== PRUEBA DE FOLIOS SEPARADOS POR ID_NEGOCIO|ID_SUCURSAL CON CONSUMO MULTI-ROL ===\n\n";

my $id_raiz = 'QTSMP000116';

# 1. Sucursal 723800|0 - Privados
print "--- Sucursal 723800|0 (Recibos Privados) ---\n";
my $f1 = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 0, '723800', '0'); # Rol A (Recepcionista)
print "[Rol A Recepcionista | 723800|0] -> Folio Privado: $f1\n";

my $f2 = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 0, '723800', '0'); # Rol B (Médico)
print "[Rol B Médico        | 723800|0] -> Folio Privado: $f2\n";

my $f3 = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 0, '723800', '0'); # Rol C (Admin)
print "[Rol C Administrador | 723800|0] -> Folio Privado: $f3\n";

# 2. Sucursal 0|0 - Privados
print "\n--- Sucursal 0|0 (Recibos Privados) ---\n";
my $f4 = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 0, '0', '0'); # Rol B (Médico en Sucursal 0|0)
print "[Rol B Médico        | 0|0]      -> Folio Privado: $f4\n";

my $f5 = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 0, '0', '0'); # Rol D (Recepcionista en Sucursal 0|0)
print "[Rol D Recepcionista | 0|0]      -> Folio Privado: $f5\n";

# 3. Sucursal 723800|0 - Públicos
print "\n--- Sucursal 723800|0 (Recibos Públicos) ---\n";
my $fp1 = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 1, '723800', '0'); # Rol B
print "[Rol B Médico        | 723800|0] -> Folio Público: $fp1\n";

my $fp2 = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 1, '723800', '0'); # Rol C
print "[Rol C Administrador | 723800|0] -> Folio Público: $fp2\n";

# Validaciones
my $ok_suc1_priv = ($f1 == 25001 && $f2 == 25002 && $f3 == 25003);
my $ok_suc0_priv = ($f4 == 27768 && $f5 == 27769);
my $ok_suc1_pub  = ($fp1 == 2802  && $fp2 == 2803);

print "\n=== RESULTADOS DE VERIFICACIÓN ===\n";
print "Secuencia 723800|0 Privados (25001, 25002, 25003): " . ($ok_suc1_priv ? "CORRECTO" : "FALLÓ ($f1, $f2, $f3)") . "\n";
print "Secuencia 0|0 Privados      (27768, 27769):        " . ($ok_suc0_priv ? "CORRECTO" : "FALLÓ ($f4, $f5)") . "\n";
print "Secuencia 723800|0 Públicos (2802, 2803):         " . ($ok_suc1_pub  ? "CORRECTO" : "FALLÓ ($fp1, $fp2)") . "\n";

if ($ok_suc1_priv && $ok_suc0_priv && $ok_suc1_pub) {
    print "\n¡TODAS LAS PRUEBAS PASARON EXITOSAMENTE!\n";
} else {
    print "\n¡ERROR EN LA PRUEBA DE AISLAMIENTO POR SUCURSAL!\n";
    exit 1;
}
