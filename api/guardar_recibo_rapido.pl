#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json decode_json);
use Encode qw(encode_utf8);
use FindBin;
use File::Spec;
use Fcntl qw(:flock);
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(guardar_registro actualizar_archivo);

my $q = CGI->new;
my $sd = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada' });
    exit;
}

my $id_paciente = $q->param('id_paciente') || '';
my $nombre_empleado = $q->param('nombre_paciente_empleado') || '';
$nombre_empleado =~ s/.*Paciente:\s*//i; # Limpiar el texto arrastrado del select2
my $id_medico = $q->param('id_medico') || '';
my $caja_items_json = $q->param('caja_items_json') || '[]';
my $caja_metodo_pago = $q->param('caja_metodo_pago') || 'Efectivo';
my $caja_monto_abono = $q->param('caja_monto_abono') // 0;

$id_paciente =~ s/^\s+|\s+$//g;
$id_medico =~ s/^\s+|\s+$//g;

if (!$id_paciente || !$id_medico) {
    print encode_json({ ok => JSON::false, msg => 'Falta paciente o médico.' });
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
my $usuario = $sd->{usuario} || 'Sistema';

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
    my $priv_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "pacientes_privados__${org_clues}.dat");
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

# 1. Crear Tratamiento Express
my $trat_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'tratamientos.dat');
unless (-e $trat_file) {
    open my $fh_t, '>:encoding(UTF-8)', $trat_file;
    print $fh_t "ID_TRATAMIENTO|ID_PACIENTE|ID_COT|ESTADO|FECHA_INICIO|FECHA_FIN|ID_MEDICO|TOTAL|ID_CITA\n";
    close $fh_t;
}
utils::db_manager::guardar_registro($trat_file, join('|', $id_tratamiento, $id_paciente, '', 'Cerrado', $hoy_fecha, $hoy_fecha, $id_medico, $caja_monto_abono, ''));

# 2. Guardar Cargos y Abonos
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
    # En estado_cuenta.dat: ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS
    my $linea_cargo = join('|',
        $id_tratamiento, $id_mov, $id_paciente, 'Cargo', $it->{nombre},
        $sub, 0, $sub, $hoy_fecha, $id_medico,
        $nota_cargo, ($nombre_empleado || '')
    );
    utils::db_manager::guardar_registro($fin_file, $linea_cargo);
}

my $id_mov_abono = 'MOV-' . time() . '-ABONO';
my $nota_abono = "Pago Recibo Rápido | Metodo: $caja_metodo_pago";
my $linea_abono = join('|',
    $id_tratamiento, $id_mov_abono, $id_paciente, 'Abono', "Abono en Caja - $caja_metodo_pago",
    $caja_monto_abono, 0, $caja_monto_abono, $hoy_fecha, $id_medico,
    $nota_abono, ($nombre_empleado || '')
);
utils::db_manager::guardar_registro($fin_file, $linea_abono);


# 3. Generar Folio Consecutivo
my $is_estado = ($id_paciente =~ /^EMP-/) ? 1 : 0;
my $contadores_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', $is_estado ? 'contadores_recibos_publicos.dat' : 'contadores_recibos_privados.dat');
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

my $folio_impreso = sprintf("%s-%s-%06d", $id_neg, $id_suc, $next_folio);
my $folios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', $is_estado ? 'folios_recibos_publicos.dat' : 'folios_recibos_privados.dat');
unless (-e $folios_file) {
    open my $fh_f2, '>:encoding(UTF-8)', $folios_file;
    print $fh_f2 "ID_RECIBO|FOLIO|ID_NEGOCIO|ID_SUCURSAL|ID_CONSULTA|ID_PACIENTE|FECHA|HORA|TOTAL_CARGOS|TOTAL_ABONOS|METODO_PAGO|ELABORADO_POR\n";
    close $fh_f2;
}
my $id_recibo_folio = 'R-' . time() . '-' . int(rand(1000));
my $hoy_hora = sprintf("%02d:%02d", $hour, $min);
my $linea_folio = join('|', $id_recibo_folio, $folio_impreso, $id_neg, $id_suc, $id_tratamiento, $id_paciente, $hoy_fecha, $hoy_hora, $caja_monto_abono, $caja_monto_abono, $caja_metodo_pago, $usuario);
utils::db_manager::guardar_registro($folios_file, $linea_folio);

print encode_json({ ok => JSON::true, id_tratamiento => $id_tratamiento, folio => $folio_impreso, is_estado => $is_estado });
1;
