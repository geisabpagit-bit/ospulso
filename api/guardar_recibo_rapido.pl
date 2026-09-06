#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json decode_json);
use Encode qw(encode_utf8 decode_utf8);
use FindBin;
use File::Spec;
use Fcntl qw(:flock);
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
use utils::db_manager qw(guardar_registro actualizar_archivo);

my $q = CGI->new;
my $sd = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($sd->{session_ok} && $sd->{role} =~ /Recepcionista|Medico|Administrador/i) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada o rol no permitido' });
    exit;
}

my $id_paciente = $q->param('id_paciente') || '';
my $nombre_empleado = $q->param('nombre_paciente_empleado') || '';
$nombre_empleado =~ s/.*Paciente:\s*//i; # Limpiar el texto arrastrado del select2
my $id_medico = $q->param('id_medico') || '';
my $caja_items_json = $q->param('caja_items_json') || '[]';
my $caja_metodo_pago = $q->param('caja_metodo_pago') // 'Efectivo';
my $caja_monto_abono = $q->param('caja_monto_abono') || 0;
my $concepto_recibo = $q->param('caja_concepto') // '';

$id_paciente =~ s/^\s+|\s+$//g;
$id_medico =~ s/^\s+|\s+$//g;

if (!$id_paciente) {
    print encode_json({ ok => JSON::false, msg => 'Falta seleccionar el paciente.' });
    exit;
}

my $caja_items = [];
eval { $caja_items = decode_json($caja_items_json); };
if ($@) {
    eval { $caja_items = decode_json(encode_utf8($caja_items_json)); };
}

if (ref($caja_items) ne 'ARRAY' || !@$caja_items) {
    print encode_json({ ok => JSON::false, msg => 'No hay conceptos a cobrar.' });
    exit;
}

my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
my $hoy_fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);

my $id_tratamiento = 'TX-EXP-' . time() . '-' . int(rand(1000));
my $id_neg = $sd->{id_empresa} || 'ORG-000';
my $id_suc = $sd->{id_sucursal} || 'SUC-000';
my $usuario = $sd->{uid} || 'Sistema';

# 0. Lógica de Pacientes Privados (Sin Portal)
my $org_clues = '';
my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $nf, '<:utf8', $negocios_file)) {
    while (my $line = <$nf>) {
        chomp($line);
        my @f = split(/\|/, $line, -1);
        if ($f[0] eq $id_neg) {
            $org_clues = $f[18] // '';
            last;
        }
    }
    close($nf);
}

my $has_portal_paciente = 1;
my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        my @f = split(/\|/, $line, -1);
        if ($f[0] eq $id_neg && $f[1] eq 'PORTAL_PACIENTE') {
            $has_portal_paciente = ($f[2] eq '1') ? 1 : 0;
            last;
        }
    }
    close($cf);
}

if (!$has_portal_paciente && $id_paciente eq $nombre_empleado && $id_paciente !~ /^EMP-|^PRIV-/) {
    # Es un nombre nuevo (tag free-text)
    my $new_id = 'PRIV-' . time() . int(rand(1000));
    my $priv_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogos_CLUE', $org_clues, "pacientes_privados_${org_clues}.dat");
    my $header_exists = (-e $priv_file) ? 1 : 0;
    if (open(my $fhp, '>>:utf8', $priv_file)) {
        flock($fhp, 2);
        if (!$header_exists) {
            print $fhp "ID_PACIENTE|NOMBRE_COMPLETO|FECHA_REGISTRO\n";
        }
        print $fhp "$new_id|$nombre_empleado|$hoy_fecha\n";
        close($fhp);
    }
    $id_paciente = $new_id;
}

# 1. Generar Folio Consecutivo
my $is_estado = ($id_paciente =~ /^EMP-/) ? 1 : 0;
my $id_raiz = catalogo_org_utils::resolver_id_raiz_catalogo($id_neg);
my $rutas_contadores = catalogo_org_utils::obtener_rutas_contadores($id_raiz);
my $contadores_file = $is_estado ? $rutas_contadores->{publicos} : $rutas_contadores->{privados};
unless (-e $contadores_file) {
    open my $fh_c, '>:encoding(UTF-8)', $contadores_file;
    print $fh_c "ID_NEGOCIO|ID_SUCURSAL|LAST_FOLIO\n";
    close $fh_c;
}

my $next_folio = 1;
my @nuevas_cont;
my $encontrado = 0;
if (open my $fh_c, '<:encoding(UTF-8)', $contadores_file) {
    my @lines_c = <$fh_c>;
    close $fh_c;
    my $cab = shift @lines_c;
    chomp $cab if defined $cab;
    foreach my $lc (@lines_c) {
        chomp $lc;
        my @cc = split /\|/, $lc, -1;
        if ($cc[0] eq $id_neg && $cc[1] eq $id_suc) {
            $next_folio = ($cc[2] || 0) + 1;
            $cc[2] = $next_folio;
            $lc = join('|', @cc);
            $encontrado = 1;
        }
        push @nuevas_cont, $lc;
    }
    if (!$encontrado) {
        push @nuevas_cont, join('|', $id_neg, $id_suc, $next_folio);
    }
    utils::db_manager::actualizar_archivo($contadores_file, $cab, \@nuevas_cont);
}

my $folio_impreso = $next_folio;
my $folios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', $is_estado ? 'folios_recibos_publicos.dat' : 'folios_recibos_privados.dat');
unless (-s $folios_file) {
    open my $fh_f2, '>:encoding(UTF-8)', $folios_file;
    print $fh_f2 "ID_RECIBO|FOLIO|ID_NEGOCIO|ID_SUCURSAL|ID_CONSULTA|ID_PACIENTE|FECHA|HORA|TOTAL_CARGOS|TOTAL_ABONOS|METODO_PAGO|ELABORADO_POR|CONCEPTO|ITEMS_JSON\n";
    close $fh_f2;
}

# Función auxiliar para resolver costo de convenio de consulta médica por catálogo de la organización
sub resolver_costo_convenio_medico {
    my ($clues, $id_med) = @_;
    return 550.0 unless ($clues && $id_med);

    my $cat_items_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogos_CLUE', $clues, "catalogo_items_${clues}.dat");
    my $cat_prec_file  = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogos_CLUE', $clues, "catalogo_precios_${clues}.dat");
    my $med_file       = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogos_CLUE', $clues, "medicos_${clues}.dat");
    my $esp_file       = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogos_CLUE', $clues, "especialidades_${clues}.dat");

    my $id_esp = '';
    my $nom_med = '';
    if (-e $med_file && open(my $fm, '<:utf8', $med_file)) {
        while (my $l = <$fm>) {
            chomp $l;
            my @f = split(/\|/, $l, -1);
            if ($f[0] eq $id_med) {
                $id_esp = $f[1] || '';
                $nom_med = $f[2] || '';
                last;
            }
        }
        close($fm);
    }

    my $nom_esp = '';
    if ($id_esp && -e $esp_file && open(my $fe, '<:utf8', $esp_file)) {
        while (my $l = <$fe>) {
            chomp $l;
            my @f = split(/\|/, $l, -1);
            if ($f[0] eq $id_esp) {
                $nom_esp = uc($f[1] || '');
                last;
            }
        }
        close($fe);
    }

    my @tokens_med = grep { length($_) > 3 && $_ !~ /^(DRA?|LIC|ING|MTRO)$/i } split(/\s+/, uc($nom_med));

    my $target_item = '';
    if (-e $cat_items_file && open(my $fi, '<:utf8', $cat_items_file)) {
        while (my $li = <$fi>) {
            chomp $li;
            my @f = split(/\|/, $li, -1);
            next if $f[0] =~ /^ID_ITEM/;
            my $item_id = $f[0];
            my $concepto = uc($f[3] || '');
            if ($concepto =~ /CONSULTA/i) {
                # 1. Match por tokens del médico (al menos 2 palabras coincidentes)
                my $hits = 0;
                foreach my $tk (@tokens_med) {
                    $hits++ if $concepto =~ /\Q$tk\E/;
                }
                if ($hits >= 2) {
                    $target_item = $item_id;
                    last;
                }
                # 2. Match por nombre de especialidad
                if ($nom_esp && $concepto =~ /\Q$nom_esp\E/ && !$target_item) {
                    $target_item = $item_id;
                }
            }
        }
        close($fi);
    }

    if ($target_item && -e $cat_prec_file && open(my $fp, '<:utf8', $cat_prec_file)) {
        my $precio_mun = 0;
        my $precio_fallback = 0;
        while (my $lp = <$fp>) {
            chomp $lp;
            my @f = split(/\|/, $lp, -1);
            if ($f[1] eq $target_item) {
                my $tarifa = uc($f[2] || '');
                my $p = $f[3] || 0;
                $p =~ s/[^\d\.]//g;
                if ($tarifa eq 'MUNICIPIO' && $p > 0) {
                    $precio_mun = $p;
                    last;
                } elsif ($p > 0 && !$precio_fallback) {
                    $precio_fallback = $p;
                }
            }
        }
        close($fp);
        return $precio_mun if ($precio_mun > 0);
        return $precio_fallback if ($precio_fallback > 0);
    }

    return 550.0;
}

# Calcular cargos y enriquecer items
my $total_cargos_calculado = 0;
foreach my $it (@$caja_items) {
    if ($is_estado) {
        if (!defined $it->{precio} || $it->{precio} == 0) {
            my $costo_convenio = resolver_costo_convenio_medico($org_clues, $id_medico);
            $it->{precio} = $costo_convenio;
            $it->{cubierto_convenio} = 1;
            $it->{precio_paciente} = 0;
        }
    }
    my $cant = $it->{cantidad} || 1;
    $total_cargos_calculado += ($it->{precio} || 0) * $cant;
}

my $total_cargos_final = ($total_cargos_calculado > 0) ? $total_cargos_calculado : ($caja_monto_abono || 0);
my $total_abonos_final = $is_estado ? ($caja_monto_abono || 0) : ($caja_monto_abono || $total_cargos_final);

# Re-serializar items JSON
$caja_items_json = encode_json($caja_items);

my $id_recibo_folio = 'R-' . time() . '-' . int(rand(1000));
my $hoy_hora = sprintf("%02d:%02d", $hour, $min);
my $estatus = 'Cobrado';
my $linea_folio = join('|', $id_recibo_folio, $folio_impreso, $id_neg, $id_suc, $folio_impreso, $id_paciente, $hoy_fecha, $hoy_hora, $total_cargos_final, $total_abonos_final, $caja_metodo_pago, $usuario, $concepto_recibo, $caja_items_json, $estatus, $id_medico);
utils::db_manager::guardar_registro($folios_file, $linea_folio);

# 2. Guardar Cargos y Abonos en estado_cuenta.dat usando el FOLIO ABSOLUTO como ID_OS
my $fin_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
unless (-e $fin_file) {
    open my $fh_f, '>:encoding(UTF-8)', $fin_file;
    print $fh_f "ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS\n";
    close $fh_f;
}

my $idx_dir = 100;
foreach my $it (@$caja_items) {
    my $id_mov = 'MOV-' . time() . '-' . $idx_dir++;
    my $sub = ($it->{precio} || 0) * ($it->{cantidad} || 1);
    my $nota_cargo = "Cargo Walk-in | Paciente: " . ($nombre_empleado || $id_paciente);
    if ($concepto_recibo) {
        $nota_cargo .= " | Concepto: $concepto_recibo";
    }
    my $linea_cargo = join('|',
        $folio_impreso, $id_mov, $id_paciente, 'Cargo', $it->{nombre},
        $sub, 0, $sub, $hoy_fecha, $id_medico,
        $nota_cargo, ($nombre_empleado || '')
    );
    utils::db_manager::guardar_registro($fin_file, $linea_cargo);
}

# Solo registrar Abono en caja si el paciente realizó un pago físico en ventanilla (copago o privado)
if ($total_abonos_final > 0) {
    my $id_mov_abono = 'MOV-' . time() . '-ABONO';
    my $nota_abono = "Pago Recibo Rápido | Metodo: $caja_metodo_pago";
    if ($concepto_recibo) {
        $nota_abono .= " | Concepto: $concepto_recibo";
    }
    my $linea_abono = join('|',
        $folio_impreso, $id_mov_abono, $id_paciente, 'Abono', "Abono en Caja - $caja_metodo_pago",
        $total_abonos_final, 0, $total_abonos_final, $hoy_fecha, $id_medico,
        $nota_abono, ($nombre_empleado || '')
    );
    utils::db_manager::guardar_registro($fin_file, $linea_abono);
}

print encode_json({ ok => JSON::true, id_tratamiento => $folio_impreso, folio => $folio_impreso, is_estado => $is_estado });
1;
