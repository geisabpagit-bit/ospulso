#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

binmode STDOUT, ':utf8';

print "=== PRUEBA DE UNIFICACIÓN DE FOLIOS MULTI-ROL (CLUE QTSMP000116) ===\n\n";

my $id_raiz = 'QTSMP000116';

# Simular consumo de folios privados por diferentes roles / id_negocio
print "--- Simulando generación de Recibos Privados ---\n";
my @roles_privados = (
    { rol => 'Rol A (Recepcionista)', id_neg => '723800' },
    { rol => 'Rol B (Médico)',        id_neg => '0' },
    { rol => 'Rol C (Administrador)', id_neg => '723800' },
    { rol => 'Rol N (Especialista)',  id_neg => '99999' },
);

my @folios_priv_generados;
foreach my $r (@roles_privados) {
    my $f = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 0, $r->{id_neg}, '0');
    push @folios_priv_generados, $f;
    print "[$r->{rol} | id_neg: $r->{id_neg}] -> Folio Privado Generado: $f\n";
}

# Simular consumo de folios públicos por diferentes roles / id_negocio
print "\n--- Simulando generación de Recibos Públicos ---\n";
my @roles_publicos = (
    { rol => 'Rol B (Médico)',        id_neg => '0' },
    { rol => 'Rol C (Administrador)', id_neg => '723800' },
    { rol => 'Rol N (Especialista)',  id_neg => '88888' },
);

my @folios_pub_generados;
foreach my $r (@roles_publicos) {
    my $f = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 1, $r->{id_neg}, '0');
    push @folios_pub_generados, $f;
    print "[$r->{rol} | id_neg: $r->{id_neg}] -> Folio Público Generado: $f\n";
}

# Validación de correlatividad estricta (+1 entre cada llamada)
my $priv_ok = 1;
for (my $i = 1; $i < @folios_priv_generados; $i++) {
    if ($folios_priv_generados[$i] != $folios_priv_generados[$i-1] + 1) {
        $priv_ok = 0;
    }
}

my $pub_ok = 1;
for (my $i = 1; $i < @folios_pub_generados; $i++) {
    if ($folios_pub_generados[$i] != $folios_pub_generados[$i-1] + 1) {
        $pub_ok = 0;
    }
}

print "\n=== RESULTADOS DE VERIFICACIÓN ===\n";
print "Folios Privados Consecutivos: " . ($priv_ok ? "CORRECTO (Secuencia estricta +1)" : "ERROR") . "\n";
print "Folios Públicos Consecutivos: " . ($pub_ok  ? "CORRECTO (Secuencia estricta +1)" : "ERROR") . "\n";

if ($priv_ok && $pub_ok) {
    print "\n¡TODAS LAS PRUEBAS PASARON EXITOSAMENTE!\n";
} else {
    print "\n¡ALERTA! SE DETECTÓ FALLA EN LA SECUENCIA DE FOLIOS.\n";
    exit 1;
}
