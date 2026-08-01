#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use lib '..';
use utils::db_manager qw(leer_tabla);

# Forzamos STDOUT a utf8
binmode STDOUT, ":utf8";

require '../auth/check_session.pl';
my $session_data = check_session();
unless ($session_data->{session_ok}) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Sesión caducada."});
    exit;
}

my $correo_paciente = lc($session_data->{correo} // '');
if ($session_data->{role} ne 'Paciente' || !$correo_paciente) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Acceso denegado."});
    exit;
}

# 1. Obtener mis IDs
my $regs_pacientes = leer_tabla('../dat/pacientes.dat', '\|');
my %mis_ids = ();

if ($regs_pacientes) {
    foreach my $p (@$regs_pacientes) {
        next if @$p < 6;
        my $c = lc($p->[5] // '');
        $c =~ s/^\s+|\s+$//g;
        if ($c eq $correo_paciente) {
            $mis_ids{$p->[0]} = 1;
        }
    }
}

# Pre-cargar diccionarios para nombres reales de médicos
my %medicos = ();
my $regs_usuarios = leer_tabla('../dat/usuarios.dat', '!');
if ($regs_usuarios) {
    foreach my $u (@$regs_usuarios) {
        $medicos{$u->[0]} = $u->[1] if @$u >= 2;
    }
}

# 2. Leer estado de cuenta
# ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS
my @movimientos = ();
my $saldo_total = 0;

if (-e '../dat/estado_cuenta.dat') {
    my $regs = leer_tabla('../dat/estado_cuenta.dat', '\|');
    if ($regs) {
        foreach my $r (@$regs) {
            next if @$r < 10;
            my $id_pac = $r->[2];
            if (exists $mis_ids{$id_pac}) {
                my $tipo = $r->[3]; # 'cargo' o 'abono'
                my $total = $r->[7] || 0;
                
                if (lc($tipo) eq 'cargo') {
                    $saldo_total += $total;
                } else {
                    $saldo_total -= $total;
                }

                push @movimientos, {
                    id_os => $r->[0],
                    tipo => ucfirst($tipo),
                    concepto => $r->[4],
                    total => $total,
                    fecha => $r->[8],
                    medico_nombre => $medicos{$r->[9]} // "Médico $r->[9]",
                    notas => $r->[10] // ''
                };
            }
        }
    }
}

# Ordenar por fecha desc
@movimientos = sort { $b->{fecha} cmp $a->{fecha} } @movimientos;

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({
    ok => 1,
    movimientos => \@movimientos,
    saldo_total => $saldo_total
});
exit;
