#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use lib '..';
use utils::db_manager qw(leer_tabla);
use POSIX qw(strftime);

require '../auth/check_session.pl';
my $sd = check_session();
unless ($sd->{session_ok}) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Sesión inválida"});
    exit;
}

my $q = $sd->{q};
my $accion = $q->param('accion') // '';
my $id_paciente = $q->param('id') // '';

sub calcular_edad {
    my ($fecha_nac) = @_;
    return "N/A" unless $fecha_nac && $fecha_nac =~ /^(\d{4})-(\d{2})-(\d{2})$/;
    my ($a_nac, $m_nac, $d_nac) = ($1, $2, $3);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;
    my $edad = $year - $a_nac;
    if ($mon < $m_nac || ($mon == $m_nac && $mday < $d_nac)) {
        $edad--;
    }
    return $edad;
}

if ($accion eq 'get_perfil') {
    my $registros = leer_tabla('../dat/pacientes.dat', '\|');
    my $perfil;
    foreach my $p (@$registros) {
        if ($p->[0] && $p->[0] eq $id_paciente) {
            my $tenant_pac = $p->[13] // '';
            my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
            my $mi_org = $sd->{id_empresa} || 'X';
            my $mi_sucursal = $sd->{id_sucursal} // 0;
            my $role = $sd->{role};
            my $id_medico = $sd->{id_medico};
            
            my $acceso_permitido = 0;
            if ($role eq 'Administrador Global') {
                $acceso_permitido = 1;
            } elsif ($role =~ /Administrador Organizacion|Soporte/i) {
                if ($org_pac && $org_pac eq $mi_org) {
                    $acceso_permitido = 1;
                } elsif (!$org_pac) {
                    $acceso_permitido = 1;
                }
            } elsif ($role eq 'Medico') {
                if ($org_pac && $org_pac eq $mi_org) {
                    if (($suc_pac eq $mi_sucursal || !$suc_pac || !$mi_sucursal) && $p->[1] eq $id_medico) {
                        $acceso_permitido = 1;
                    }
                } elsif (!$org_pac && $p->[1] eq $id_medico) {
                    $acceso_permitido = 1;
                }
            }
            
            unless ($acceso_permitido) {
                print "Content-Type: application/json; charset=UTF-8\n\n";
                print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Acceso denegado"});
                exit;
            }
            $perfil = {
                id => $p->[0],
                id_medico => $p->[1],
                nombre => $p->[2],
                rfc => $p->[3],
                curp => $p->[4],
                correo => $p->[5] || 'No registrado',
                fecha_nac => $p->[6],
                edad => calcular_edad($p->[6]),
                sexo => $p->[7],
                ocupacion => $p->[8],
                estado_civil => $p->[9],
                nacionalidad => $p->[10],
                tipo_sangre => $p->[11] || 'No definido',
                telefono => $p->[12] || 'No registrado'
            };
            last;
        }
    }
    
    if ($perfil) {
        # Cargar métricas financieras
        my ($saldo_total, $cargos_sum, $abonos_sum) = (0, 0, 0);
        my $ec_file = '../dat/estado_cuenta.dat';
        if (-e $ec_file) {
            open(my $fh, "<:encoding(UTF-8)", $ec_file); <$fh>;
            while (my $line = <$fh>) {
                chomp $line;
                my @v = split /\|/, $line;
                if (@v >= 11 && $v[2] eq $id_paciente) {
                    my $tot = $v[7] + 0;
                    my $tipo = $v[3] || '';
                    my $notas = $v[10] || '';
                    my $is_cotizacion = ($tipo =~ /Cargo/i && $notas =~ /Presupuesto|Cotizacion/i) ? 1 : 0;
                    
                    if ($is_cotizacion) {
                        # Cargo legado tipo presupuesto — excluir del balance real
                    } elsif ($tipo =~ /Cargo/i) { $saldo_total += $tot; $cargos_sum += $tot; }
                    else { $saldo_total -= $tot; $abonos_sum += $tot; }
                }
            }
            close $fh;
        }
        $perfil->{saldo} = $saldo_total;
        $perfil->{cargos} = $cargos_sum;
        $perfil->{abonos} = $abonos_sum;
        # Cotizaciones desde cotizaciones.dat (fuente canónica)
        my $cot_file_path = '../dat/cotizaciones.dat';
        my $cotizaciones_sum = 0;
        if (-e $cot_file_path) {
            open(my $fhc, '<:encoding(UTF-8)', $cot_file_path);
            <$fhc>; # saltar cabecera
            while (my $cline = <$fhc>) {
                chomp $cline;
                my @cv = split /\|/, $cline, -1;
                # ID_COT|ID_PACIENTE|NOMBRE|TOTAL|FECHA|ID_MEDICO
                next unless @cv >= 4;
                if ($cv[1] eq $id_paciente) {
                    $cotizaciones_sum += ($cv[3] + 0);
                }
            }
            close $fhc;
        }
        $perfil->{cotizaciones} = $cotizaciones_sum;

        # Obtener Historial Médico
        my $citas_db = leer_tabla('../dat/citas.dat', '\|');
        my @historial;
        foreach my $c (@$citas_db) {
            next if @$c < 9;
            if ($c->[2] eq $id_paciente) {
                my @partes_fecha = split(/-/, $c->[3]);
                my $fecha_corta = "N/A";
                if (@partes_fecha == 3) {
                    my @meses = qw(ENE FEB MAR ABR MAY JUN JUL AGO SEP OCT NOV DIC);
                    my $mes = $meses[$partes_fecha[1] - 1];
                    $fecha_corta = $partes_fecha[2] . "<br/>" . $mes;
                }

                push @historial, {
                    id_cita => $c->[0],
                    fecha_real => $c->[3],
                    fecha_corta => $fecha_corta,
                    hora => $c->[4],
                    motivo => $c->[6],
                    estado => $c->[8],
                    notas => $c->[7]
                };
            }
        }
        
        # Sort descendente
        @historial = sort { $b->{fecha_real} cmp $a->{fecha_real} } @historial;

        print "Content-Type: application/json; charset=UTF-8\n\n";
        binmode STDOUT, ":raw";
        print JSON::PP->new->utf8(1)->encode({ok => 1, perfil => $perfil, historial => \@historial});
        exit;
    } else {
        print "Content-Type: application/json; charset=UTF-8\n\n";
        binmode STDOUT, ":raw";
        print JSON::PP->new->utf8(1)->encode({ok => 0, msg => "Paciente no encontrado"});
        exit;
    }
}

print "Content-Type: application/json; charset=UTF-8\n\n";
binmode STDOUT, ":raw";
print JSON::PP->new->utf8(1)->encode({ok => 0, msg => "Acción inválida"});
exit;
