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

# Departamentos / Conceptos
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

# Construir texto Markdown listo para copiar
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

my $tipo_titulo = ucfirst($tipo_periodo);
my $markdown_export = <<"MD_TEXT";
# INFORME EJECUTIVO DE OPERACIÓN Y RECAUDACIÓN ($tipo_titulo)
**CLUE:** `$clue_org` | **Clínica:** $nombre_negocio  
**Periodo Reportado:** $tipo_titulo $periodo_activo  
**Fuente:** OSPulso Suite Producción

---

## 1. Tablero de Control de KPIs
* **Flujo Real en Caja (Privados):** \$@{[ sprintf("%.2f", $tot_priv_abonos) ]} MXN
* **Cuentas por Cobrar (Municipio):** \$@{[ sprintf("%.2f", $tot_pub_cargos) ]} MXN
* **Total Recibos Emitidos:** $total_recibos_activa recibos (@{[ scalar(@priv_activa) ]} Privados / @{[ scalar(@pub_activa) ]} Públicos)
* **Ticket Promedio Privado:** \$@{[ sprintf("%.2f", @priv_activa ? $tot_priv_abonos / scalar(@priv_activa) : 0) ]} MXN
* **Ticket Promedio Público:** \$@{[ sprintf("%.2f", @pub_activa ? $tot_pub_cargos / scalar(@pub_activa) : 0) ]} MXN
* **Índice de Calidad de Datos:** @{[ $calidad_cuadre_perfecto ? '100% Óptimo (Cuadre matemático exacto)' : 'Requiere revisión' ]}

---

## 2. Desglose Cronológico
| Periodo / Rango | Detalle | Rec. Priv | Monto Privado | Rec. Púb | Monto Municipio | Total Recibos | Total Facturado |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|:---:|
$md_diario_lineas
---

## 3. Control de Medios de Pago (Canal Privado)
$md_pago_lineas
MD_TEXT

print encode_json({
    status               => 'ok',
    id_empresa           => $id_target,
    nombre_negocio       => $nombre_negocio,
    clue                 => $clue_org,
    tipo_periodo         => $tipo_periodo,
    periodo_activo       => $periodo_activo,
    periodo_previo       => $periodo_previo,
    dias_disponibles     => \@dias_disponibles,
    semanas_disponibles  => \@semanas_disponibles,
    meses_disponibles    => \@meses_disponibles,
    anos_disponibles     => \@anos_disponibles,
    kpis => {
        flujo_privado       => $tot_priv_abonos,
        cargos_publicos     => $tot_pub_cargos,
        total_recibos       => $total_recibos_activa,
        recibos_privados    => scalar(@priv_activa),
        recibos_publicos    => scalar(@pub_activa),
        ticket_prom_privado => scalar(@priv_activa) ? ($tot_priv_abonos / scalar(@priv_activa)) : 0,
        ticket_prom_publico => scalar(@pub_activa) ? ($tot_pub_cargos / scalar(@pub_activa)) : 0,
        crec_ingresos_pct   => sprintf("%.1f", $crec_ingresos_pct),
        crec_recibos_pct    => sprintf("%.1f", $crec_recibos_pct),
        calidad_datos_pct   => $calidad_cuadre_perfecto ? 100 : 95
    },
    desglose_cronologico => \@desglose_cronologico,
    elemento_pico        => $elemento_pico,
    medios_pago          => \@medios_pago_lista,
    deptos_priv          => \%deptos_priv,
    deptos_pub           => \%deptos_pub,
    markdown_export      => $markdown_export
});
exit;
