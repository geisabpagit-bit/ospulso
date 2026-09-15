#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');

binmode STDOUT, ':utf8';

print "=== PRUEBA DE MATRIZ DINÁMICA DE PERMISOS MULTI-TENANT (CLUE Y NO-CLUE) ===\n\n";

# 1. Prueba de Resolución de Rutas
print "--- 1. Resolución de Rutas ---\n";
my $ruta_clue   = utils::permisos_utils::obtener_ruta_permisos_org('QTSMP000116');
my $ruta_noclue = utils::permisos_utils::obtener_ruta_permisos_org('723800');

print "Ruta CLUE (QTSMP000116): $ruta_clue\n";
print "Ruta No-CLUE (723800):    $ruta_noclue\n";

my $ok_rutas = ($ruta_clue =~ /catalogos_CLUE/ && $ruta_noclue =~ /permisos_roles_723800\.dat$/);
print "Resultado Resolución Rutas: " . ($ok_rutas ? "CORRECTO" : "ERROR") . "\n\n";

# 2. Prueba de Fallback a roles.dat
print "--- 2. Fallback Transparente a roles.dat ---\n";
my $matriz_fallback = utils::permisos_utils::obtener_matriz_permisos_org('999999_invalida');
my $has_fallback_medico = exists $matriz_fallback->{'Medico'};
print "Matriz de Fallback Cargada correctamente: " . ($has_fallback_medico ? "CORRECTO" : "ERROR") . "\n\n";

# 3. Prueba de Guardado y Consulta en Organización Privada No-CLUE (723800)
print "--- 3. Guardado y Consulta en Org Privada No-CLUE (723800) ---\n";
my %test_matriz_noclue = (
    'Recepcionista' => {
        'agenda'    => { C=>1, R=>1, U=>1, D=>0 },
        'pacientes' => { C=>1, R=>1, U=>0, D=>0 },
        'finanzas'  => { C=>0, R=>0, U=>0, D=>0 }, # Acceso a finanzas revocado dinámicamente
    },
    'Medico' => {
        'agenda'    => { C=>1, R=>1, U=>1, D=>1 },
        'pacientes' => { C=>1, R=>1, U=>1, D=>1 },
        'finanzas'  => { C=>1, R=>1, U=>0, D=>0 },
    }
);

my $res_save_noclue = utils::permisos_utils::guardar_matriz_permisos_org('723800', \%test_matriz_noclue);
print "Guardado No-CLUE: $res_save_noclue->{msg}\n";

my $p_rec_agenda   = utils::permisos_utils::tiene_permiso_modulo('723800', 'Recepcionista', 'agenda', 'R');
my $p_rec_finanzas = utils::permisos_utils::tiene_permiso_modulo('723800', 'Recepcionista', 'finanzas', 'R');

print "Recepcionista 723800 -> Agenda Read: $p_rec_agenda (Esperado: 1)\n";
print "Recepcionista 723800 -> Finanzas Read: $p_rec_finanzas (Esperado: 0)\n";
my $ok_noclue_perm = ($p_rec_agenda == 1 && $p_rec_finanzas == 0);
print "Resultado Permisos No-CLUE: " . ($ok_noclue_perm ? "CORRECTO" : "ERROR") . "\n\n";

# 4. Prueba de Lockout Protection para Administrador
print "--- 4. Lockout Protection (Administrador) ---\n";
my $p_admin_usr = utils::permisos_utils::tiene_permiso_modulo('723800', 'Administrador Organizacion', 'usuarios', 'R');
my $p_admin_del = utils::permisos_utils::tiene_permiso_modulo('723800', 'Administrador Organizacion', 'usuarios', 'D');
print "Administrador -> Usuarios Read: $p_admin_usr (Esperado: 1)\n";
print "Administrador -> Usuarios Delete: $p_admin_del (Esperado: 1)\n";
my $ok_lockout = ($p_admin_usr == 1 && $p_admin_del == 1);
print "Resultado Lockout Protection: " . ($ok_lockout ? "CORRECTO" : "ERROR") . "\n\n";

# 5. Limpieza de archivo de prueba
unlink $ruta_noclue if (-e $ruta_noclue);
print "--- 5. Limpieza de archivos de prueba completada ---\n\n";

print "=== RESULTADOS DE VERIFICACIÓN ===\n";
if ($ok_rutas && $has_fallback_medico && $ok_noclue_perm && $ok_lockout) {
    print "¡TODAS LAS PRUEBAS DE LA MATRIZ DINÁMICA PASARON EXITOSAMENTE!\n";
} else {
    print "¡FALLA EN LAS PRUEBAS DE MATRIZ DINÁMICA!\n";
    exit 1;
}
