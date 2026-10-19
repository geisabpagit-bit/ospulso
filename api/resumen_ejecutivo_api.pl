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

# Si es Administrador Global puede recibir id_empresa por parámetro, si no, usa el de su sesión
my $id_target = decode_utf8($q->param('id_empresa') // '');
if ($role_sesion ne 'Administrador Global' || !$id_target) {
    $id_target = ($id_empresa_sesion ne '' && $id_empresa_sesion ne '0') ? $id_empresa_sesion : '723800';
}

my $semana_req = decode_utf8($q->param('semana') // '');

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

# Mapear semanas ISO disponibles
my %semanas_map = ();
for my $r (@recibos_priv, @recibos_pub) {
    my $fecha = $r->{FECHA};
    next unless ($fecha && $fecha =~ /^\d{4}-\d{2}-\d{2}$/);
    eval {
        my $tp = Time::Piece->strptime($fecha, '%Y-%m-%d');
        my ($year, $week) = ($tp->year, $tp->week);
        my $w_key = sprintf("%04d-W%02d", $year, $week);
        $semanas_map{$w_key}++;
        $r->{_SEMANA_ISO} = $w_key;
        $r->{_TIME_PIECE} = $tp;
    };
}

my @semanas_disponibles = sort { $b cmp $a } keys %semanas_map;

# Determinar semana seleccionada
my $semana_activa = $semana_req;
if (!$semana_activa || !exists $semanas_map{$semana_activa}) {
    $semana_activa = $semanas_disponibles[0] // '';
}

# Semana previa para cálculo de tendencias
my $semana_previa = '';
if ($semana_activa) {
    eval {
        my ($y, $w) = split(/-W/, $semana_activa);
        my $prev_w = int($w) - 1;
        my $prev_y = int($y);
        if ($prev_w <= 0) {
            $prev_y--;
            $prev_w = 52;
        }
        $semana_previa = sprintf("%04d-W%02d", $prev_y, $prev_w);
    };
}

# Filtrar registros de la semana activa y previa
my @priv_activa = grep { ($_->{_SEMANA_ISO} // '') eq $semana_activa } @recibos_priv;
my @pub_activa  = grep { ($_->{_SEMANA_ISO} // '') eq $semana_activa } @recibos_pub;

my @priv_previa = grep { ($_->{_SEMANA_ISO} // '') eq $semana_previa } @recibos_priv;
my @pub_previa  = grep { ($_->{_SEMANA_ISO} // '') eq $semana_previa } @recibos_pub;

# Cálculos Financieros
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

# Semana Previa
my $prev_priv_abonos = 0;
for (@priv_previa) { $prev_priv_abonos += ($_->{TOTAL_ABONOS} || 0); }
my $prev_total_recibos = scalar(@priv_previa) + scalar(@pub_previa);

# Crecimiento %
my $crec_ingresos_pct = 0;
if ($prev_priv_abonos > 0) {
    $crec_ingresos_pct = (($tot_priv_abonos - $prev_priv_abonos) / $prev_priv_abonos) * 100;
}

my $total_recibos_activa = scalar(@priv_activa) + scalar(@pub_activa);
my $crec_recibos_pct = 0;
if ($prev_total_recibos > 0) {
    $crec_recibos_pct = (($total_recibos_activa - $prev_total_recibos) / $prev_total_recibos) * 100;
}

# Desglose Diario
my %dias_map = ();
my @nombres_dias = ('Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado');

for my $r (@priv_activa) {
    my $f = $r->{FECHA};
    $dias_map{$f} //= { fecha => $f, priv_cnt => 0, priv_monto => 0, pub_cnt => 0, pub_monto => 0, total_cnt => 0, total_monto => 0, dia_nombre => '' };
    $dias_map{$f}->{priv_cnt}++;
    $dias_map{$f}->{priv_monto} += ($r->{TOTAL_ABONOS} || 0);
    $dias_map{$f}->{total_cnt}++;
    $dias_map{$f}->{total_monto} += ($r->{TOTAL_ABONOS} || 0);
    if ($r->{_TIME_PIECE}) {
        $dias_map{$f}->{dia_nombre} = $nombres_dias[$r->{_TIME_PIECE}->_wday];
    }
}

for my $r (@pub_activa) {
    my $f = $r->{FECHA};
    $dias_map{$f} //= { fecha => $f, priv_cnt => 0, priv_monto => 0, pub_cnt => 0, pub_monto => 0, total_cnt => 0, total_monto => 0, dia_nombre => '' };
    $dias_map{$f}->{pub_cnt}++;
    $dias_map{$f}->{pub_monto} += ($r->{TOTAL_CARGOS} || 0);
    $dias_map{$f}->{total_cnt}++;
    $dias_map{$f}->{total_monto} += ($r->{TOTAL_CARGOS} || 0);
    if ($r->{_TIME_PIECE} && !$dias_map{$f}->{dia_nombre}) {
        $dias_map{$f}->{dia_nombre} = $nombres_dias[$r->{_TIME_PIECE}->_wday];
    }
}

my @desglose_diario = map { $dias_map{$_} } sort keys %dias_map;

# Encontrar día pico
my $dia_pico = undef;
for my $d (@desglose_diario) {
    if (!$dia_pico || $d->{total_monto} > $dia_pico->{total_monto}) {
        $dia_pico = $d;
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
my $folios_priv_ordenados = [ sort { $a <=> $b } map { int($_->{FOLIO} || 0) } @priv_activa ];
my $folios_pub_ordenados  = [ sort { $a <=> $b } map { int($_->{FOLIO} || 0) } @pub_activa ];

my $calidad_cuadre_perfecto = 1;
my $cuadre_errores_cnt = 0;
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
            $cuadre_errores_cnt++;
        }
    };
}

# Construir texto Markdown listo para copiar
my $md_diario_lineas = "";
for my $d (@desglose_diario) {
    $md_diario_lineas .= sprintf("| **%s** | %s | %d | \$%.2f | %d | \$%.2f | %d | \$%.2f |\n",
        $d->{fecha}, $d->{dia_nombre}, $d->{priv_cnt}, $d->{priv_monto}, $d->{pub_cnt}, $d->{pub_monto}, $d->{total_cnt}, $d->{total_monto}
    );
}

my $md_pago_lineas = "";
for my $mp (@medios_pago_lista) {
    $md_pago_lineas .= sprintf("* **%s:** %d recibos (\$%.2f MXN - %s%%)\n", $mp->{metodo}, $mp->{count}, $mp->{monto}, $mp->{porcentaje});
}

my $markdown_export = <<"MD_TEXT";
# INFORME EJECUTIVO SEMANAL DE OPERACIÓN Y RECAUDACIÓN
**CLUE:** `$clue_org` | **Clínica:** $nombre_negocio  
**Periodo Reportado:** Semana $semana_activa  
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

## 2. Desglose Diario de Recaudación
| Fecha | Día | Rec. Priv | Monto Privado | Rec. Púb | Monto Municipio | Total Recibos | Total Facturado |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|:---:|
$md_diario_lineas
---

## 3. Control de Medios de Pago (Canal Privado)
$md_pago_lineas
MD_TEXT

print encode_json({
    status              => 'ok',
    id_empresa          => $id_target,
    nombre_negocio      => $nombre_negocio,
    clue                => $clue_org,
    semana_activa       => $semana_activa,
    semana_previa       => $semana_previa,
    semanas_disponibles => \@semanas_disponibles,
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
    desglose_diario     => \@desglose_diario,
    dia_pico            => $dia_pico,
    medios_pago         => \@medios_pago_lista,
    deptos_priv         => \%deptos_priv,
    deptos_pub          => \%deptos_pub,
    markdown_export     => $markdown_export
});
exit;
