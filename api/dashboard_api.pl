#!/usr/bin/perl
# --- Versión v3.2.0 (DEPRECADO - MIGRADO A SSR EN render_dashboard_principal.pl) ---
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std); # Sin :utf8 global para JSON
use CGI;
use JSON::PP;
use FindBin;
use File::Spec;
use POSIX qw(strftime);

# ==========================================================
# SDM - DASHBOARD API v3.1.6 (Cálculo Dinámico)
# Optimizado para Ayer/Hoy/Futuro y Finanzas Globales
# ==========================================================

use lib "$FindBin::Bin/..";
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $accion = $q->param('accion') // 'all';
my $id_med_f = $q->param('id_medico') // '';
$id_med_f = '' if $id_med_f eq 'undefined' || $id_med_f eq 'null';

my $archivo_citas     = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $archivo_finanzas  = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');

# --- Lógica de Fechas (Rango: Ayer <-> Hoy + 7) ---
my $time_ahora = time();
my $hoy        = strftime("%Y-%m-%d", localtime($time_ahora));
my $ayer       = strftime("%Y-%m-%d", localtime($time_ahora - 86400));
my $proxima_sem = strftime("%Y-%m-%d", localtime($time_ahora + (7 * 86400)));

if ($accion eq 'all') {
    # 1. Cargar Catálogo de Pacientes
    my $pac_data = leer_tabla($archivo_pacientes, '\|');
    my %nom_pac;
    my $t_pac = 0;
    if ($pac_data && ref $pac_data eq 'ARRAY') {
        foreach my $p (@$pac_data) {
            next if (@$p < 3);
            # Si hay id_medico, filtramos. Si no (Admin), contamos todo.
            if (!$id_med_f || $p->[1] eq $id_med_f) { $t_pac++; }
            $nom_pac{$p->[0]} = $p->[2];
        }
    }

    # 2. Cargar y Filtrar Citas (Ayer <-> Hoy + 7)
    my $citas_data = leer_tabla($archivo_citas, '\|');
    my $citas_hoy = 0;
    my @proximas_citas;
    if ($citas_data && ref $citas_data eq 'ARRAY') {
        foreach my $c (@$citas_data) {
            next if (@$c < 9);
            # Filtro por médico si se proporciona (Medico vs Admin)
            next if ($id_med_f && $c->[1] ne $id_med_f);
            
            my $f_cita = $c->[3];
            
            # KPI: Citas hoy (Independiente del rango de visualización)
            $citas_hoy++ if ($f_cita eq $hoy);

            # FILTRO DE VISUALIZACIÓN: Rango Ayer <-> Hoy + 7
            if ($f_cita ge $ayer && $f_cita le $proxima_sem) {
                push @proximas_citas, { 
                    id => $c->[0], 
                    hora => $c->[4], 
                    fecha => $f_cita,
                    estado => $c->[8], 
                    motivo => $c->[6],
                    nombre_paciente => $nom_pac{$c->[2]} // "Paciente #$c->[2]"
                };
            }
        }
    }
    
    # Ordenar cronológicamente
    @proximas_citas = sort { $a->{fecha} cmp $b->{fecha} || $a->{hora} cmp $b->{hora} } @proximas_citas;

    # 3. Finanzas de la Clínica (Globales como pidió el usuario)
    my $fin_data = leer_tabla($archivo_finanzas, '\|');
    my ($total_cargos, $total_abonos) = (0, 0);
    if ($fin_data && ref $fin_data eq 'ARRAY') {
        foreach my $t (@$fin_data) {
            next if (@$t < 7);
            # Índice 2: TIPO (Cargo/Abono), Índice 6: TOTAL
            my $tipo  = $t->[2] // '';
            my $total = $t->[6] // 0;
            $total =~ s/[^0-9.]//g; # Limpiar moneda si existe
            
            if ($tipo =~ /Cargo/i) {
                $total_cargos += $total;
            } elsif ($tipo =~ /Abono/i) {
                $total_abonos += $total;
            }
        }
    }

    my %response = (
        ok => 1,
        stats => {
            citas_hoy => $citas_hoy,
            pacientes_totales => $t_pac,
            cargos => $total_cargos,
            abonos => $total_abonos
        },
        proximas_citas => \@proximas_citas,
        rango => { hoy => $hoy, ayer => $ayer }
    );

    print "Content-Type: application/json; charset=UTF-8\n\n";
    binmode STDOUT, ":raw";
    print JSON::PP->new->utf8(1)->encode(\%response);
    exit;
}
1;
