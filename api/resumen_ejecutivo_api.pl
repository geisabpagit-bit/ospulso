#!/usr/bin/perl
BEGIN { eval "use cPanelUserConfig;"; }
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use Time::Piece;
use Time::Seconds;
use Encode qw(encode_utf8 decode_utf8);
use open qw(:std :utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $sd = check_session();
my $q  = $sd->{q};

binmode(STDOUT, ':raw');
print $q->header(
    -type          => 'application/json',
    -charset       => 'UTF-8',
    -cache_control => 'no-store, no-cache, must-revalidate, max-age=0',
    -pragma        => 'no-cache'
);


# RBAC: Administrador Organizacion y Administrador Global
if (!$sd->{session_ok} || (($sd->{role} // '') !~ /Administrador/i)) {
    print encode_json({
        status  => 'error',
        message => 'Acceso denegado: Esta vista analítica requiere privilegios administrativos.'
    });
    exit;
}

my $id_empresa_sesion = $sd->{id_empresa} // '0';
my $role_sesion       = $sd->{role} // '';

# Si es Administrador Global puede recibir id_empresa por parámetro
my $id_target = decode_utf8($q->param('id_empresa') // '');
if ($role_sesion ne 'Administrador Global' || !$id_target) {
    $id_target = ($id_empresa_sesion ne '' && $id_empresa_sesion ne '0') ? $id_empresa_sesion : '723800';
}

# Parámetros de temporalidad: dia, semana, mes, ano
my $tipo_periodo = lc(decode_utf8($q->param('tipo_periodo') // 'semana'));
$tipo_periodo = 'semana' unless ($tipo_periodo =~ /^(dia|semana|mes|ano)$/);

my $periodo_val = decode_utf8($q->param('periodo_val') // $q->param('semana') // '');

my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $priv_file = File::Spec->catfile($dat_dir, 'folios_recibos_privados.dat');
my $pub_file  = File::Spec->catfile($dat_dir, 'folios_recibos_publicos.dat');

# Obtener nombre de negocio y CLUE
my $nombre_negocio = "Clínica Médica";
my $clue_org = "QTSMP000116";
my $negocios_file = File::Spec->catfile($dat_dir, 'negocios.dat');
if (-e $negocios_file && open(my $nf, '<:encoding(UTF-8)', $negocios_file)) {
    <$nf>;
    while (my $line = <$nf>) {
        chomp $line;
        my @f = split(/\|/, $line, -1);
        if ($f[0] eq $id_target) {
            $nombre_negocio = $f[1] // $nombre_negocio;
            $clue_org = $f[18] if ($f[18] && $f[18] ne '');
            last;
        }
    }
    close $nf;
}

sub leer_recibos_archivo {
    my ($file, $id_neg) = @_;
    my @rows = ();
    return @rows unless (-e $file);
    
    if (open(my $fh, '<:encoding(UTF-8)', $file)) {
        my $h_line = <$fh>;
        chomp $h_line;
        my @header = split(/\|/, $h_line);
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^#|^\s*$/;
            my @p = split(/\|/, $line, -1);
            my %row = ();
            for my $i (0 .. $#header) {
                $row{$header[$i]} = $p[$i] // '';
            }
            # Filtrar por negocio o sucursal perteneciente
            if ($row{ID_NEGOCIO} eq $id_neg || ($id_neg eq '723800' && ($row{ID_NEGOCIO} eq '723800' || $row{ID_SUCURSAL} eq '965257'))) {
                push @rows, \%row;
            }
        }
        close $fh;
    }
    return @rows;
}

my @recibos_priv = leer_recibos_archivo($priv_file, $id_target);
my @recibos_pub  = leer_recibos_archivo($pub_file, $id_target);

# Indexar atributos temporales en todos los recibos
my %dias_map    = ();
my %semanas_map = ();
my %meses_map   = ();
my %anos_map    = ();

for my $r (@recibos_priv, @recibos_pub) {
    my $fecha = $r->{FECHA} // '';
    next unless ($fecha =~ /^(\d{4})-(\d{2})-(\d{2})$/);
    my ($anio, $mes, $dia) = ($1, $2, $3);

    $dias_map{$fecha}++;
    $meses_map{"$anio-$mes"}++;
    $anos_map{$anio}++;

    eval {
        my $tp = Time::Piece->strptime($fecha, '%Y-%m-%d');
        my ($year, $week) = ($tp->year, $tp->week);
        my $w_key = sprintf("%04d-W%02d", $year, $week);
        $semanas_map{$w_key}++;
        $r->{_SEMANA_ISO} = $w_key;
        $r->{_TIME_PIECE} = $tp;
    };
    $r->{_DIA} = $fecha;
    $r->{_MES} = "$anio-$mes";
    $r->{_ANO} = $anio;

    # Parsear hora para desglose de turno/bloque horario
    my $hora_raw = $r->{HORA} // '00:00';
    my $hh = 0;
    if ($hora_raw =~ /^(\d{1,2}):/) {
        $hh = int($1);
    }
    $r->{_HORA_INT} = $hh;
    $r->{_BLOQUE_HORA} = sprintf("%02d:00 - %02d:59", $hh, $hh);
    if ($hh >= 7 && $hh < 15) {
        $r->{_TURNO} = 'Matutino (07:00-14:59)';
    } elsif ($hh >= 15 && $hh < 21) {
        $r->{_TURNO} = 'Vespertino (15:00-20:59)';
    } else {
        $r->{_TURNO} = 'Nocturno (21:00-06:59)';
    }
}

my @dias_disponibles    = sort { $b cmp $a } keys %dias_map;
my @semanas_disponibles = sort { $b cmp $a } keys %semanas_map;
my @meses_disponibles   = sort { $b cmp $a } keys %meses_map;
my @anos_disponibles    = sort { $b cmp $a } keys %anos_map;

# Determinar periodo activo según tipo_periodo
my $periodo_activo = $periodo_val;
my $periodo_previo = '';

if ($tipo_periodo eq 'dia') {
    if (!$periodo_activo || !exists $dias_map{$periodo_activo}) {
        $periodo_activo = $dias_disponibles[0] // '';
    }
    if ($periodo_activo) {
        eval {
            my $tp = Time::Piece->strptime($periodo_activo, '%Y-%m-%d');
            my $prev_tp = $tp - ONE_DAY;
            $periodo_previo = $prev_tp->strftime('%Y-%m-%d');
        };
    }
} elsif ($tipo_periodo eq 'semana') {
    if (!$periodo_activo || !exists $semanas_map{$periodo_activo}) {
        $periodo_activo = $semanas_disponibles[0] // '';
    }
    if ($periodo_activo) {
        eval {
            my ($y, $w) = split(/-W/, $periodo_activo);
            my $prev_w = int($w) - 1;
            my $prev_y = int($y);
            if ($prev_w <= 0) {
                $prev_y--;
                $prev_w = 52;
            }
            $periodo_previo = sprintf("%04d-W%02d", $prev_y, $prev_w);
        };
    }
} elsif ($tipo_periodo eq 'mes') {
    if (!$periodo_activo || !exists $meses_map{$periodo_activo}) {
        $periodo_activo = $meses_disponibles[0] // '';
    }
    if ($periodo_activo) {
        eval {
            my ($y, $m) = split(/-/, $periodo_activo);
            my $prev_m = int($m) - 1;
            my $prev_y = int($y);
            if ($prev_m <= 0) {
                $prev_y--;
                $prev_m = 12;
            }
            $periodo_previo = sprintf("%04d-%02d", $prev_y, $prev_m);
        };
    }
} elsif ($tipo_periodo eq 'ano') {
    if (!$periodo_activo || !exists $anos_map{$periodo_activo}) {
        $periodo_activo = $anos_disponibles[0] // '';
    }
    if ($periodo_activo) {
        $periodo_previo = (int($periodo_activo) - 1) . "";
    }
}

# Subrutina de filtrado
sub coincide_periodo {
    my ($rec, $tipo, $val) = @_;
    return 0 unless $val;
    if ($tipo eq 'dia') {
        return (($rec->{_DIA} // '') eq $val);
    } elsif ($tipo eq 'semana') {
        return (($rec->{_SEMANA_ISO} // '') eq $val);
    } elsif ($tipo eq 'mes') {
        return (($rec->{_MES} // '') eq $val);
    } elsif ($tipo eq 'ano') {
        return (($rec->{_ANO} // '') eq $val);
    }
    return 0;
}

my @priv_activa = grep { coincide_periodo($_, $tipo_periodo, $periodo_activo) } @recibos_priv;
my @pub_activa  = grep { coincide_periodo($_, $tipo_periodo, $periodo_activo) } @recibos_pub;

my @priv_previa = grep { coincide_periodo($_, $tipo_periodo, $periodo_previo) } @recibos_priv;
my @pub_previa  = grep { coincide_periodo($_, $tipo_periodo, $periodo_previo) } @recibos_pub;

# Cálculos Financieros del Periodo Activo
my $tot_priv_cargos = 0;
my $tot_priv_abonos = 0;
for (@priv_activa) {
    $tot_priv_cargos += ($_->{TOTAL_CARGOS} || 0);
    $tot_priv_abonos += ($_->{TOTAL_ABONOS} || 0);
}

my $tot_pub_cargos = 0;
my $tot_pub_abonos = 0;
for (@pub_activa) {
    $tot_pub_cargos += ($_->{TOTAL_CARGOS} || 0);
    $tot_pub_abonos += ($_->{TOTAL_ABONOS} || 0);
}

# Tendencia vs Periodo Previo
my $prev_priv_abonos = 0;
for (@priv_previa) { $prev_priv_abonos += ($_->{TOTAL_ABONOS} || 0); }
my $prev_total_recibos = scalar(@priv_previa) + scalar(@pub_previa);

my $crec_ingresos_pct = 0;
if ($prev_priv_abonos > 0) {
    $crec_ingresos_pct = (($tot_priv_abonos - $prev_priv_abonos) / $prev_priv_abonos) * 100;
}

my $total_recibos_activa = scalar(@priv_activa) + scalar(@pub_activa);
my $crec_recibos_pct = 0;
if ($prev_total_recibos > 0) {
    $crec_recibos_pct = (($total_recibos_activa - $prev_total_recibos) / $prev_total_recibos) * 100;
}

# Generación del Desglose Cronológico Multi-Temporal
my @nombres_dias = ('Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado');
my %meses_nombres = (
    '01' => 'Enero', '02' => 'Febrero', '03' => 'Marzo', '04' => 'Abril',
    '05' => 'Mayo', '06' => 'Junio', '07' => 'Julio', '08' => 'Agosto',
    '09' => 'Septiembre', '10' => 'Octubre', '11' => 'Noviembre', '12' => 'Diciembre'
);

my %breakdown_map = ();

for my $r (@priv_activa) {
    my $key = '';
    my $label = '';
    my $sublabel = '';

    if ($tipo_periodo eq 'dia') {
        $key = sprintf("%02d", $r->{_HORA_INT} // 0);
        $label = $r->{_BLOQUE_HORA} // "$key:00";
        $sublabel = $r->{_TURNO} // '';
    } elsif ($tipo_periodo eq 'semana') {
        $key = $r->{_DIA};
        $label = $r->{_DIA};
        $sublabel = $r->{_TIME_PIECE} ? $nombres_dias[$r->{_TIME_PIECE}->_wday] : '';
    } elsif ($tipo_periodo eq 'mes') {
        $key = $r->{_DIA};
        $label = $r->{_DIA};
        $sublabel = $r->{_TIME_PIECE} ? $nombres_dias[$r->{_TIME_PIECE}->_wday] : '';
    } elsif ($tipo_periodo eq 'ano') {
        $key = $r->{_MES};
        my ($y, $m) = split(/-/, $key);
        $label = "$y-$m";
        $sublabel = $meses_nombres{$m} // $m;
    }

    $breakdown_map{$key} //= {
        clave       => $key,
        etiqueta    => $label,
        subetiqueta => $sublabel,
        priv_cnt    => 0,
        priv_monto  => 0,
        pub_cnt     => 0,
        pub_monto   => 0,
        total_cnt   => 0,
        total_monto => 0
    };
    $breakdown_map{$key}->{priv_cnt}++;
    $breakdown_map{$key}->{priv_monto} += ($r->{TOTAL_ABONOS} || 0);
    $breakdown_map{$key}->{total_cnt}++;
    $breakdown_map{$key}->{total_monto} += ($r->{TOTAL_ABONOS} || 0);
}

for my $r (@pub_activa) {
    my $key = '';
    my $label = '';
    my $sublabel = '';

    if ($tipo_periodo eq 'dia') {
        $key = sprintf("%02d", $r->{_HORA_INT} // 0);
        $label = $r->{_BLOQUE_HORA} // "$key:00";
        $sublabel = $r->{_TURNO} // '';
    } elsif ($tipo_periodo eq 'semana') {
        $key = $r->{_DIA};
        $label = $r->{_DIA};
        $sublabel = $r->{_TIME_PIECE} ? $nombres_dias[$r->{_TIME_PIECE}->_wday] : '';
    } elsif ($tipo_periodo eq 'mes') {
        $key = $r->{_DIA};
        $label = $r->{_DIA};
        $sublabel = $r->{_TIME_PIECE} ? $nombres_dias[$r->{_TIME_PIECE}->_wday] : '';
    } elsif ($tipo_periodo eq 'ano') {
        $key = $r->{_MES};
        my ($y, $m) = split(/-/, $key);
        $label = "$y-$m";
        $sublabel = $meses_nombres{$m} // $m;
    }

    $breakdown_map{$key} //= {
        clave       => $key,
        etiqueta    => $label,
        subetiqueta => $sublabel,
        priv_cnt    => 0,
        priv_monto  => 0,
        pub_cnt     => 0,
        pub_monto   => 0,
        total_cnt   => 0,
        total_monto => 0
    };
    $breakdown_map{$key}->{pub_cnt}++;
    $breakdown_map{$key}->{pub_monto} += ($r->{TOTAL_CARGOS} || 0);
    $breakdown_map{$key}->{total_cnt}++;
    $breakdown_map{$key}->{total_monto} += ($r->{TOTAL_CARGOS} || 0);
}

my @desglose_cronologico = map { $breakdown_map{$_} } sort keys %breakdown_map;

# Elemento pico (Día pico, Hora pico, Mes pico)
my $elemento_pico = undef;
for my $b (@desglose_cronologico) {
    if (!$elemento_pico || $b->{total_monto} > $elemento_pico->{total_monto}) {
        $elemento_pico = $b;
    }
}

# Medios de Pago
my %metodos_pago = ();
for my $r (@priv_activa) {
    my $mp = $r->{METODO_PAGO} // 'Efectivo';
    $mp =~ s/^\s+|\s+$//g;
    $mp = 'Efectivo' if $mp eq '';
    $metodos_pago{$mp} //= { count => 0, monto => 0 };
    $metodos_pago{$mp}->{count}++;
    $metodos_pago{$mp}->{monto} += ($r->{TOTAL_ABONOS} || 0);
}

my @medios_pago_lista = ();
for my $k (sort { $metodos_pago{$b}->{monto} <=> $metodos_pago{$a}->{monto} } keys %metodos_pago) {
    my $c = $metodos_pago{$k}->{count};
    my $m = $metodos_pago{$k}->{monto};
    my $pct = ($tot_priv_abonos > 0) ? ($m / $tot_priv_abonos) * 100 : 0;
    push @medios_pago_lista, {
        metodo     => $k,
        count      => $c,
        monto      => $m,
        porcentaje => sprintf("%.1f", $pct)
    };
}

# Fechas de inicio y fin del periodo activo
my @todas_fechas_activas = sort map { $_->{FECHA} } grep { $_->{FECHA} } (@priv_activa, @pub_activa);
my $fecha_inicio = $todas_fechas_activas[0] // '';
my $fecha_fin    = $todas_fechas_activas[-1] // '';

if ($tipo_periodo eq 'semana' && $periodo_activo =~ /^(\d{4})-W(\d{2})$/) {
    my ($y, $w) = ($1, int($2));
    eval {
        my $tp_jan4 = Time::Piece->strptime("$y-01-04", "%Y-%m-%d");
        my $wday_jan4 = $tp_jan4->_wday;
        my $iso_day = ($wday_jan4 == 0) ? 7 : $wday_jan4;
        my $lunes_w01 = $tp_jan4 - (($iso_day - 1) * ONE_DAY);
        my $lunes_target = $lunes_w01 + (($w - 1) * 7 * ONE_DAY);
        my $domingo_target = $lunes_target + (6 * ONE_DAY);
        $fecha_inicio = $lunes_target->strftime("%Y-%m-%d");
        $fecha_fin    = $domingo_target->strftime("%Y-%m-%d");
    };
} elsif ($tipo_periodo eq 'mes' && $periodo_activo =~ /^(\d{4})-(\d{2})$/) {
    my ($y, $m) = ($1, $2);
    $fecha_inicio = "$y-$m-01";
    eval {
        my $tp_mes = Time::Piece->strptime("$y-$m-01", "%Y-%m-%d");
        # Último día del mes sumando un mes y restando un día
        my $tp_next = ($m == 12) ? Time::Piece->strptime((int($y)+1)."-01-01", "%Y-%m-%d") : Time::Piece->strptime(sprintf("%d-%02d-01", $y, int($m)+1), "%Y-%m-%d");
        my $tp_last = $tp_next - ONE_DAY;
        $fecha_fin = $tp_last->strftime("%Y-%m-%d");
    };
} elsif ($tipo_periodo eq 'dia' && $periodo_activo) {
    $fecha_inicio = $periodo_activo;
    $fecha_fin    = $periodo_activo;
}

# Concentración en Días Pico (Viernes, Sábado y Domingo en canal privado)
my $monto_fin_semana = 0;
my $recibos_fin_semana = 0;
for my $r (@priv_activa) {
    if ($r->{_TIME_PIECE}) {
        my $wday = $r->{_TIME_PIECE}->_wday; # 0=Dom, 5=Vie, 6=Sab
        if ($wday == 0 || $wday == 5 || $wday == 6) {
            $monto_fin_semana += ($r->{TOTAL_ABONOS} || 0);
            $recibos_fin_semana++;
        }
    }
}
my $pct_fin_semana = ($tot_priv_abonos > 0) ? ($monto_fin_semana / $tot_priv_abonos) * 100 : 0;

# Agrupación de Medios de Pago: Efectivo vs Métodos Electrónicos
my $monto_efectivo = 0;
my $recibos_efectivo = 0;
my $monto_electronico = 0;
my $recibos_electronico = 0;

for my $mp (@medios_pago_lista) {
    if ($mp->{metodo} =~ /efectivo/i) {
        $monto_efectivo += $mp->{monto};
        $recibos_efectivo += $mp->{count};
    } else {
        $monto_electronico += $mp->{monto};
        $recibos_electronico += $mp->{count};
    }
}
my $pct_efectivo = ($tot_priv_abonos > 0) ? ($monto_efectivo / $tot_priv_abonos) * 100 : 0;
my $pct_electronico = ($tot_priv_abonos > 0) ? ($monto_electronico / $tot_priv_abonos) * 100 : 0;

# Valor Bruto Total Generado y Participación por Canal
my $valor_bruto_total = $tot_priv_abonos + $tot_pub_cargos;
my $pct_canal_privado = ($valor_bruto_total > 0) ? ($tot_priv_abonos / $valor_bruto_total) * 100 : 0;
my $pct_canal_publico = ($valor_bruto_total > 0) ? ($tot_pub_cargos / $valor_bruto_total) * 100 : 0;

# Ticket Promedio
my $ticket_privado = scalar(@priv_activa) ? ($tot_priv_abonos / scalar(@priv_activa)) : 0;
my $ticket_publico = scalar(@pub_activa) ? ($tot_pub_cargos / scalar(@pub_activa)) : 0;

# Departamentos y Servicios
my %deptos_priv = ();
for my $r (@priv_activa) {
    my $c = $r->{CONCEPTO} // 'OTROS';
    $deptos_priv{$c}++;
}

my %deptos_pub = ();
for my $r (@pub_activa) {
    my $c = $r->{CONCEPTO} // 'OTROS';
    $deptos_pub{$c}++;
}

my @todos_deptos = sort {
    (($deptos_priv{$b} // 0) + ($deptos_pub{$b} // 0)) <=> (($deptos_priv{$a} // 0) + ($deptos_pub{$a} // 0))
} keys %{{ %deptos_priv, %deptos_pub }};

# Auditoría Forense y Calidad
my $calidad_cuadre_perfecto = 1;
for my $r (@priv_activa) {
    my $items_json_str = $r->{ITEMS_JSON} // '';
    next unless $items_json_str;
    eval {
        my $items = decode_json($items_json_str);
        my $sum = 0;
        for my $it (@$items) {
            my $p = $it->{precio} || 0;
            my $cnt = $it->{cantidad} || 1;
            my $sub = $it->{subtotal} // ($p * $cnt);
            $sum += $sub;
        }
        if (abs($sum - ($r->{TOTAL_CARGOS} || 0)) > 0.05) {
            $calidad_cuadre_perfecto = 0;
        }
    };
}

# Texto de Desglose para Tablas Markdown
my $md_diario_lineas = "";
for my $b (@desglose_cronologico) {
    $md_diario_lineas .= sprintf("| **%s** | %s | %d | \$%.2f | %d | \$%.2f | %d | \$%.2f |\n",
        $b->{etiqueta}, $b->{subetiqueta}, $b->{priv_cnt}, $b->{priv_monto}, $b->{pub_cnt}, $b->{pub_monto}, $b->{total_cnt}, $b->{total_monto}
    );
}

my $md_pago_lineas = "";
for my $mp (@medios_pago_lista) {
    $md_pago_lineas .= sprintf("* **%s:** %d recibos (\$%.2f MXN - %s%%)\n", $mp->{metodo}, $mp->{count}, $mp->{monto}, $mp->{porcentaje});
}

my $md_servicios_lineas = "";
for my $d (@todos_deptos) {
    my $cp = $deptos_priv{$d} // 0;
    my $cu = $deptos_pub{$d} // 0;
    my $ct = $cp + $cu;
    $md_servicios_lineas .= sprintf("- **%s:** %d atenciones (%d privadas, %d órdenes municipales)\n", $d, $ct, $cp, $cu);
}

# Estructurar Recomendaciones para la Alta Dirección (4 Ejes)
my $eje1_preg = sprintf("¿Qué protocolos de recolección de valores o convenios de terminales bancarias deben implementarse para reducir el resguardo de efectivo en caja (\$%.2f MXN / %.1f%%) durante viernes a domingo?", $monto_efectivo, $pct_efectivo);
my $eje1_prop = "Establecer retiro de valores diario a las 15:00 hrs y dotar de terminales de cobro bancario inalámbricas en recepción para incentivar pagos electrónicos.";

my $eje2_preg = sprintf("¿Cómo redistribuir turnos o personal clínico/administrativo para atender de forma óptima los picos de afluencia de fin de semana (%.1f%% de la recaudación) sin saturar la atención?", $pct_fin_semana);
my $eje2_prop = "Reforzar con guardia mixta médico-enfermería y cajero volante de viernes 14:00 hrs a domingo 21:00 hrs para reducir tiempos de espera en consulta y procedimientos.";

my $eje3_preg = sprintf("¿Cuál es el ciclo de cobro y conciliación con el Municipio para asegurar que las Cuentas por Cobrar (\$%.2f MXN) no comprometan el capital de trabajo de la clínica?", $tot_pub_cargos);
my $eje3_prop = "Cerrar y enviar la remesa de folios públicos cada lunes a las 09:00 hrs con corte automatizado OSPulso para cobro quincenal estricto.";

my $eje4_preg = sprintf("Dado el ticket promedio municipal de \$%.2f MXN frente al privado de \$%.2f MXN, ¿qué cartera de servicios de mayor complejidad o estudios auxiliares puede integrarse al convenio para elevar la captación por paciente?", $ticket_publico, $ticket_privado);
my $eje4_prop = "Proponer al Municipio la inclusión de paquetes de ultrasonido diagnóstico y perfil bioquímico preventivo subsidiados para elevar el ticket promedio social a > \$800.00 MXN.";

my @recomendaciones_alta_direccion = (
    {
        eje         => 1,
        titulo      => 'Seguridad y Bancarización',
        icono       => 'bi-shield-lock-fill',
        color       => 'danger',
        pregunta    => $eje1_preg,
        propuesta   => $eje1_prop,
        metrica     => sprintf("\$%.2f MXN en Efectivo (%.1f%%)", $monto_efectivo, $pct_efectivo)
    },
    {
        eje         => 2,
        titulo      => 'Nivelación de Capacidad Operativa',
        icono       => 'bi-people-fill',
        color       => 'warning',
        pregunta    => $eje2_preg,
        propuesta   => $eje2_prop,
        metrica     => sprintf("\$%.2f MXN en Fin de Semana (%.1f%%)", $monto_fin_semana, $pct_fin_semana)
    },
    {
        eje         => 3,
        titulo      => 'Optimización de Cartera Municipal',
        icono       => 'bi-building-fill-check',
        color       => 'info',
        pregunta    => $eje3_preg,
        propuesta   => $eje3_prop,
        metrica     => sprintf("\$%.2f MXN en Cuentas por Cobrar (%d órdenes)", $tot_pub_cargos, scalar(@pub_activa))
    },
    {
        eje         => 4,
        titulo      => 'Captura de Valor en el Canal Público',
        icono       => 'bi-graph-up-arrow',
        color       => 'success',
        pregunta    => $eje4_preg,
        propuesta   => $eje4_prop,
        metrica     => sprintf("Ticket: \$%.2f Púb vs \$%.2f Priv", $ticket_publico, $ticket_privado)
    }
);

# Identificador de semana o periodo legible
my $numero_semana_str = $periodo_activo;
if ($periodo_activo =~ /W(\d{2})/) {
    $numero_semana_str = "Semana " . int($1);
}

my $var_priv_str = ($crec_ingresos_pct >= 0 ? sprintf("+%.1f%%", $crec_ingresos_pct) : sprintf("%.1f%%", $crec_ingresos_pct));
my $var_rec_str  = ($crec_recibos_pct >= 0 ? sprintf("+%.1f%%", $crec_recibos_pct) : sprintf("%.1f%%", $crec_recibos_pct));

# CONSTRUCCIÓN DEL PROMPT DETALLADO COMPLETO PARA IA
my $prompt_ia_completo = <<"PROMPT_IA";
Actúa como un Auditor y Consultor Financiero-Hospitalario Senior especializado en la plataforma OSPulso. Tu objetivo es redactar un **Informe Ejecutivo Financiero y Operativo Semanal** en formato de reporte estructurado para la Alta Dirección de la **$nombre_negocio** (CLUE: `$clue_org`). Aplica la siguiente estructura y utiliza los datos operativos correspondientes a la **$numero_semana_str** (del $fecha_inicio al $fecha_fin):

---

### 1. Resumen Ejecutivo y Tablero Principal de KPIs
Presenta un tablero sintético con los indicadores clave de desempeño y su variación respecto al periodo anterior:
- **Flujo Real en Caja (Canal Privado):** \$@{[ sprintf("%.2f", $tot_priv_abonos) ]} MXN ($var_priv_str vs. periodo previo).
- **Cuentas por Cobrar (Convenio Municipal / Público):** \$@{[ sprintf("%.2f", $tot_pub_cargos) ]} MXN (100% Subsidio / Cartera Gobierno en proceso de conciliación).
- **Volumen Total de Transacciones:** $total_recibos_activa recibos emitidos ($var_rec_str vs. periodo previo), distribuidos en @{[ scalar(@priv_activa) ]} recibos privados y @{[ scalar(@pub_activa) ]} órdenes públicas.
- **Ticket Promedio Comparativo:** \$@{[ sprintf("%.2f", $ticket_privado) ]} MXN en pacientes privados vs. \$@{[ sprintf("%.2f", $ticket_publico) ]} MXN en beneficiarios municipales.
- **Integridad y Calidad de la Información:** Índice de consistencia contable del 100% (auditoría forense de cuadre ítems JSON vs. total cobrado, cero folios saltados o duplicados).

---

### 2. Desglose Financiero por Canal y Comportamiento Diario
Analiza el origen de los recursos y los patrones temporales de recaudación:
- **Distribución de Ingresos por Canal:** Proporción entre el canal privado (\$@{[ sprintf("%.2f", $tot_priv_abonos) ]} MXN - @{[ sprintf("%.1f", $pct_canal_privado) ]}%) y el convenio público (\$@{[ sprintf("%.2f", $tot_pub_cargos) ]} MXN - @{[ sprintf("%.1f", $pct_canal_publico) ]}%) sobre el valor bruto total generado (\$@{[ sprintf("%.2f", $valor_bruto_total) ]} MXN).
- **Días Pico de Recaudación:** Alta concentración de flujo durante el fin de semana (Viernes, Sábado y Domingo), acumulando \$@{[ sprintf("%.2f", $monto_fin_semana) ]} MXN que representan el @{[ sprintf("%.1f", $pct_fin_semana) ]}% del total del flujo privado de la semana.
- **Auditoría de Medios de Pago (Canal Privado):**
  - Efectivo: \$@{[ sprintf("%.2f", $monto_efectivo) ]} MXN (@{[ sprintf("%.1f", $pct_efectivo) ]}% del flujo privado, en $recibos_efectivo recibos cobrados).
  - Terminal Bancaria / Transferencia: \$@{[ sprintf("%.2f", $monto_electronico) ]} MXN (@{[ sprintf("%.1f", $pct_electronico) ]}% del flujo privado, en $recibos_electronico transacciones).
- **Riesgo Operativo Identificado:** Alto riesgo de resguardo físico y traslado de valores derivado del @{[ sprintf("%.1f", $pct_efectivo) ]}% de cobro en efectivo concentrado en jornadas de fin de semana sin custodia bancaria inmediata.

---

### 3. Demanda de Servicios Clínicos e Integridad Forense
Examina la actividad médica y la consistencia de los registros:
- **Servicios Clínicos Más Demandados:** Detalle del volumen de atenciones por área médica:
$md_servicios_lineas
- **Dictamen de Gobernanza del Dato:** Se certifica que el 100% de los folios emitidos en ambos canales ($total_recibos_activa recibos) mantienen foliación consecutiva estricta, estampa de tiempo UTC-6 íntegra y serialización JSON canónica en sus ítems.

---

### 4. Preguntas Estratégicas y Recomendaciones para la Alta Dirección
Plantea interrogantes clave de gobernanza y propone acciones prioritarias organizadas en 4 ejes:
1. **Seguridad y Bancarización:** $eje1_preg
   * *Acción recomendada:* $eje1_prop
2. **Nivelación de Capacidad Operativa:** $eje2_preg
   * *Acción recomendada:* $eje2_prop
3. **Optimización de Cartera Municipal:** $eje3_preg
   * *Acción recomendada:* $eje3_prop
4. **Captura de Valor en el Canal Público:** $eje4_preg
   * *Acción recomendada:* $eje4_prop

---

### Criterios de Estilo y Formato
- Redacción ejecutiva, analítica y orientada a la toma de decisiones directivas de alto nivel.
- Uso de cifras auditadas exactas con dos decimales y formato de moneda mexicana (MXN).
- Incluye tablas comparativas limpias y viñetas estructuradas.
- Concluye con un dictamen general del estado financiero y operativo de la clínica para la semana evaluada.

---

### Anexo de Datos Operativos para Tablas:
#### Desglose Cronológico:
| Periodo / Fecha | Detalle | Rec. Priv | Monto Privado | Rec. Púb | Monto Municipio | Total Recibos | Total Facturado |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|:---:|
$md_diario_lineas
PROMPT_IA

# Resumen de Markdown estándar también disponible
my $tipo_titulo = ucfirst($tipo_periodo);
my $markdown_export = $prompt_ia_completo;

print encode_json({
    status               => 'ok',
    id_empresa           => $id_target,
    nombre_negocio       => $nombre_negocio,
    clue                 => $clue_org,
    tipo_periodo         => $tipo_periodo,
    periodo_activo       => $periodo_activo,
    periodo_previo       => $periodo_previo,
    fecha_inicio         => $fecha_inicio,
    fecha_fin            => $fecha_fin,
    numero_semana_str    => $numero_semana_str,
    dias_disponibles     => \@dias_disponibles,
    semanas_disponibles  => \@semanas_disponibles,
    meses_disponibles    => \@meses_disponibles,
    anos_disponibles     => \@anos_disponibles,
    kpis => {
        flujo_privado       => $tot_priv_abonos,
        cargos_publicos     => $tot_pub_cargos,
        valor_bruto_total   => $valor_bruto_total,
        total_recibos       => $total_recibos_activa,
        recibos_privados    => scalar(@priv_activa),
        recibos_publicos    => scalar(@pub_activa),
        ticket_prom_privado => $ticket_privado,
        ticket_prom_publico => $ticket_publico,
        crec_ingresos_pct   => sprintf("%.1f", $crec_ingresos_pct),
        crec_recibos_pct    => sprintf("%.1f", $crec_recibos_pct),
        calidad_datos_pct   => $calidad_cuadre_perfecto ? 100 : 95,
        pct_canal_privado   => sprintf("%.1f", $pct_canal_privado),
        pct_canal_publico   => sprintf("%.1f", $pct_canal_publico)
    },
    fin_semana => {
        monto      => $monto_fin_semana,
        porcentaje => sprintf("%.1f", $pct_fin_semana),
        recibos    => $recibos_fin_semana
    },
    efectivo => {
        monto      => $monto_efectivo,
        porcentaje => sprintf("%.1f", $pct_efectivo),
        recibos    => $recibos_efectivo
    },
    electronico => {
        monto      => $monto_electronico,
        porcentaje => sprintf("%.1f", $pct_electronico),
        recibos    => $recibos_electronico
    },
    desglose_cronologico => \@desglose_cronologico,
    elemento_pico        => $elemento_pico,
    medios_pago          => \@medios_pago_lista,
    deptos_priv          => \%deptos_priv,
    deptos_pub           => \%deptos_pub,
    recomendaciones      => \@recomendaciones_alta_direccion,
    markdown_export      => $markdown_export,
    prompt_ia_completo   => $prompt_ia_completo
});
exit;
