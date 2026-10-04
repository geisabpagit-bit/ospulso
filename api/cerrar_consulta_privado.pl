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
use MIME::Base64 qw(decode_base64);
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
use utils::db_manager qw(guardar_registro actualizar_archivo);

my $q = CGI->new;
my $session_data = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($session_data->{session_ok}) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada' });
    exit;
}

my %payload;
foreach my $p ($q->param) {
    my @v = $q->param($p);
    $payload{$p} = scalar(@v) > 1 ? \@v : $v[0];
}
if ($payload{medicamentos_json}) { eval { $payload{medicamentos} = decode_json(encode_utf8($payload{medicamentos_json})); }; }

my $id_cita = $q->param('id_cita') || $payload{id_cita} || '';
my $id_paciente = $q->param('id_paciente') || $q->param('id') || $payload{id_paciente} || '';
my $id_medico = $session_data->{id_medico} || 'DOC-000';

$id_cita =~ s/^\s+|\s+$//g;
$id_paciente =~ s/^\s+|\s+$//g;

if (!$id_paciente) {
    print encode_json({ ok => JSON::false, msg => 'Falta id_paciente' });
    exit;
}

my $id_consulta = '';
my $consultas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');

if ($id_cita && $id_cita ne '') {
    if (-e $consultas_file && open my $fh_search, '<:encoding(UTF-8)', $consultas_file) {
        my $hdr = <$fh_search>;
        while(<$fh_search>) {
            chomp;
            my @c = split /\|/, $_, -1;
            if ($c[2] eq $id_cita) {
                $id_consulta = $c[0];
                last;
            }
        }
        close $fh_search;
    }
}
if (!$id_consulta) {
    $id_consulta = 'CONS-' . time() . '-' . int(rand(1000));
}
$payload{id_consulta} = $id_consulta;

# Lógica de Fecha de Hoy
my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
my $hoy_fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
my $hoy_hora  = sprintf("%02d:%02d", $hour, $min);

# --- PRE-PROCESAMIENTO: Extraer Firmas Base64 y guardarlas como físicas ---
# (Para evitar que payload_json se vuelva gigante en la base de datos de texto)
my $firmas_dir = File::Spec->catdir($FindBin::Bin, '..', 'uploads', 'firmas');
unless (-d $firmas_dir) {
    mkdir $firmas_dir or warn "No se pudo crear directorio $firmas_dir: $!";
}

# Usamos el id de consulta como base para el id de consentimiento si se crea
my $id_consentimiento_ref = 'CNS-' . time() . '-' . int(rand(1000));

foreach my $tipo ('paciente', 'medico') {
    my $campo = "firma_${tipo}_data";
    my $b64_data = $q->param($campo) || $payload{$campo} || '';
    
    if ($b64_data =~ /^data:image\/(png|jpeg);base64,(.*)$/) {
        my $ext = $1;
        my $base64 = $2;
        my $img_data = decode_base64($base64);
        
        my $filename = "${id_consentimiento_ref}_${tipo}.${ext}";
        my $filepath = File::Spec->catfile($firmas_dir, $filename);
        if (open my $fh_img, '>:raw', $filepath) {
            print $fh_img $img_data;
            close $fh_img;
            
            # Reemplazar la base64 por la ruta en el payload
            $payload{$campo} = "uploads/firmas/$filename";
            # Preparación para el futuro: Firma FIEL
            $payload{"tipo_firma_${tipo}"} = "Autógrafa Digital (Pad)";
        }
    }
}
# --------------------------------------------------------------------------

# 1. Guardar la consulta
unless (-e $consultas_file) {
    open my $fh_new, '>:encoding(UTF-8)', $consultas_file;
    print $fh_new "id_consulta|id_paciente|id_cita|id_medico|timestamp|payload_json\n";
    close $fh_new;
}
my $json_str = encode_json(\%payload);
$json_str =~ s/\r|\n/\\n/g; # Escapar saltos de línea para mantener formato CSV
my $linea = join('|', $id_consulta, $id_paciente, $id_cita, $id_medico, time(), $json_str);

if (-e $consultas_file) {
    my @lines;
    my $cabecera = "";
    my $found = 0;
    if (open my $fh_c, '<:encoding(UTF-8)', $consultas_file) {
        my @all = <$fh_c>;
        close $fh_c;
        $cabecera = shift @all;
        chomp $cabecera if defined $cabecera;
        foreach my $l (@all) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id_consulta) {
                $l = $linea;
                $found = 1;
            }
            push @lines, $l;
        }
    }
    if (!$found) {
        push @lines, $linea;
    }
    utils::db_manager::actualizar_archivo($consultas_file, $cabecera, \@lines);
}

# 1.1 Persistir Receta Médica si fue expedida
my $requiere_receta = $q->param('requiere_receta') || $payload{requiere_receta} || '0';
my $receta_json = $q->param('receta_json') || $payload{receta_json} || '';
if ($requiere_receta eq '1' || $receta_json) {
    my $recetas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'recetas.dat');
    unless (-e $recetas_file) {
        open my $fh_r, '>:encoding(UTF-8)', $recetas_file;
        print $fh_r "id_receta|id_consulta|id_paciente|id_medico|fecha|folio|diagnostico|payload_json\n";
        close $fh_r;
    }
    my $id_receta = 'REC-' . time() . '-' . int(rand(1000));
    my $folio_receta = $q->param('receta_folio') || "REC-$hoy_fecha-" . int(rand(9000)+1000);
    my $diag_receta  = $payload{diagnostico_principal} || $payload{clave_diagnostico_cie10} || 'Sin diagnóstico';
    my $r_json_clean = $receta_json || encode_json(\%payload);
    $r_json_clean =~ s/\r|\n/\\n/g;
    my $linea_rec = join('|', $id_receta, $id_consulta, $id_paciente, $id_medico, $hoy_fecha, $folio_receta, $diag_receta, $r_json_clean);
    utils::db_manager::guardar_registro($recetas_file, $linea_rec);
}

# 1.2 Persistir Consentimiento Informado si fue requerido
my $requiere_consentimiento = $q->param('requiere_consentimiento') || $payload{requiere_consentimiento} || '0';
# Siempre ignoramos el consentimiento_json del input si hay payload directo, ya que limpiamos las firmas del payload
my $consentimiento_json = encode_json(\%payload); 

if ($requiere_consentimiento eq '1' || $q->param('consentimiento_json')) {
    my $cons_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consentimientos.dat');
    unless (-e $cons_file) {
        open my $fh_c, '>:encoding(UTF-8)', $cons_file;
        print $fh_c "id_consentimiento|id_consulta|id_paciente|id_medico|fecha|procedimiento|payload_json\n";
        close $fh_c;
    }
    
    my $proc_consentimiento = $payload{procedimiento_descripcion} || 'Procedimiento Médico General';
    my $c_json_clean = $consentimiento_json;
    $c_json_clean =~ s/\r|\n/\\n/g;
    my $linea_cons = join('|', $id_consentimiento_ref, $id_consulta, $id_paciente, $id_medico, $hoy_fecha, $proc_consentimiento, $c_json_clean);
    utils::db_manager::guardar_registro($cons_file, $linea_cons);
}

# 2. Sincronizar estado en citas.dat
my $citas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');

# Lógica de redondeo a bloques de 30 mins para evitar fracciones
my $min_start = ($min < 30) ? 0 : 30;
my $min_end   = ($min < 30) ? 30 : 0;
my $hour_start = $hour;
my $hour_end   = ($min < 30) ? $hour : $hour + 1;
$hour_end = 0 if $hour_end == 24;

my $hoy_hora_rounded = sprintf("%02d:%02d", $hour_start, $min_start);
my $hoy_hora_fin_rounded = sprintf("%02d:%02d", $hour_end, $min_end);

my $encontrada = 0;
if (-e $citas_file && open my $fh_in, '<:encoding(UTF-8)', $citas_file) {
    my @lineas = <$fh_in>;
    close $fh_in;
    
    my @nuevas_lineas;
    my $cabecera = shift @lineas;
    chomp $cabecera if defined $cabecera;
    
    foreach my $l (@lineas) {
        chomp $l;
        my @c = split /\|/, $l, -1;
        my $c0_clean = $c[0] // '';
        $c0_clean =~ s/^\s+|\s+$//g;
        my $c_id_pac = $c[2] // '';
        $c_id_pac =~ s/^\s+|\s+$//g;
        my $c_fec    = $c[3] // '';
        $c_fec =~ s/^\s+|\s+$//g;
        
        my $match = 0;
        if ($id_cita && $c0_clean eq $id_cita) {
            $match = 1;
        } elsif (!$id_cita && $c_id_pac eq $id_paciente && $c_fec eq $hoy_fecha && ($c[8]//'') !~ /^(Atendida|Cancelada)$/i) {
            $match = 1;
        }
        
        if ($match && !$encontrada) {
            $c[3] = $hoy_fecha; # Asegurar fecha de atención real en el cierre
            $c[8] = 'Atendida';
            $l = join('|', @c);
            $encontrada = 1;
        }
        push @nuevas_lineas, $l;
    }
    if ($encontrada) {
        utils::db_manager::actualizar_archivo($citas_file, $cabecera, \@nuevas_lineas);
    } elsif (!$id_cita) {
        # Si no había cita programada para hoy, registrar consulta express automática
        my $new_id_cita = "EXP-" . time() . "-" . int(rand(1000));
        my $linea = join('|', $new_id_cita, $id_medico, $id_paciente, $hoy_fecha, $hoy_hora_rounded, $hoy_hora_fin_rounded, 'Consulta Express Automática', 'Originada desde consultorio', 'Atendida', '');
        utils::db_manager::guardar_registro($citas_file, $linea);
    }
}

# 3. Flujo Clínico-Financiero Privado (Cotizaciones -> Tratamientos -> Caja -> Citas)
my $id_cotizacion = $q->param('id_cotizacion') || '';
my $convertir_tratamiento = $q->param('convertir_tratamiento') || '0';
my $id_tratamiento_param = $q->param('id_tratamiento') || '';
my $caja_items_json = $q->param('caja_items_json') || '[]';
my $caja_monto_abono = $q->param('caja_monto_abono') // 0;

my $id_neg = (defined $session_data->{id_empresa} && $session_data->{id_empresa} ne '') ? $session_data->{id_empresa} : '0';
my $id_suc = (defined $session_data->{id_sucursal} && $session_data->{id_sucursal} ne '') ? $session_data->{id_sucursal} : '0';

if (($id_neg eq '0' || $id_neg eq 'ORG-000') && defined $session_data->{usuario} && $session_data->{usuario} ne '') {
    my $usr_f = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    if (-e $usr_f && open my $fhu, '<:encoding(UTF-8)', $usr_f) {
        my $hdr = <$fhu>;
        while (my $l = <$fhu>) {
            chomp $l;
            my @f = split /!/, $l, -1;
            if ($f[0] eq $id_medico || (lc($f[2] // '') eq lc($session_data->{usuario}))) {
                my $raw_neg = $f[6] // '';
                my ($neg_id, $suc_id) = split /:/, $raw_neg;
                $id_neg = $neg_id if defined $neg_id && $neg_id ne '';
                $id_suc = $suc_id if defined $suc_id && $suc_id ne '';
                last;
            }
        }
        close $fhu;
    }
}
$id_neg ||= '0';
$id_suc ||= '0';

my $tipo_organizacion = 'Clínica';
my $archivo_config = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $archivo_config && open my $fh_cfg, '<:encoding(UTF-8)', $archivo_config) {
    while (my $line = <$fh_cfg>) {
        $line =~ s/\R//g;
        next if $line =~ /^#|^\s*$/;
        my @f = split(/\|/, $line);
        if ($f[0] eq $id_neg && $f[1] eq 'TIPO_ORGANIZACION') {
            $tipo_organizacion = $f[2] // 'Clínica';
            last;
        }
    }
    close $fh_cfg;
}

my $org_clues = '';
my $org_nombre = '';
my $neg_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $neg_file && open my $fhn, '<:encoding(UTF-8)', $neg_file) {
    my $hdr = <$fhn>;
    while (my $ln = <$fhn>) {
        chomp $ln;
        next if $ln =~ /^\s*$/;
        my @nr = split(/\|/, $ln, -1);
        if ($nr[0] eq $id_neg || ($id_neg eq '0' && $nr[0] eq '0')) {
            $org_nombre = $nr[1] // '';
            $org_clues  = $nr[18] // '';
            last;
        }
    }
    close $fhn;
}

if ($tipo_organizacion eq 'Clínica') {
    if (!$org_clues || $org_clues eq '0' || $org_nombre =~ /consultorio/i) {
        $tipo_organizacion = 'Consultorio Individual';
    }
}

my $es_consultorio = ($tipo_organizacion =~ /Consultorio/i) ? 1 : 0;

my $caja_items = [];
eval {
    $caja_items = decode_json(encode_utf8($caja_items_json)) if $caja_items_json;
};
my $tiene_cargos_directos = (ref($caja_items) eq 'ARRAY' && @$caja_items) ? 1 : 0;

my $caja_estado_tratamiento = $q->param('caja_estado_tratamiento') // 'Abierto';
my $es_cobro_recepcion = ($caja_estado_tratamiento =~ /Cobro/i) ? 1 : 0;
if ($es_cobro_recepcion) {
    $caja_monto_abono = 0; # El cobro se delega a recepción
}

# REGLA FINANCIERA: Si no hay cotización ni ítems directos explícitos enviados:
if (!$id_cotizacion && !$tiene_cargos_directos) {
    if ($caja_monto_abono > 0 || $es_cobro_recepcion) {
        my $monto_cargo = $caja_monto_abono > 0 ? $caja_monto_abono : 500.00;
        $caja_items = [ { nombre => 'Consulta Médica', precio => $monto_cargo, cantidad => 1 } ];
        $tiene_cargos_directos = 1;
    } else {
        # Verificar si es consulta de seguimiento/continuación o primera vez
        my $consultas_previas = 0;
        if (-e $consultas_file && open my $fh_prev, '<:encoding(UTF-8)', $consultas_file) {
            <$fh_prev>;
            while (my $lp = <$fh_prev>) {
                chomp $lp;
                my @cp = split /\|/, $lp, -1;
                if ($cp[1] eq $id_paciente && $cp[0] ne $id_consulta) {
                    $consultas_previas++;
                }
            }
            close $fh_prev;
        }
        if ($consultas_previas > 0) {
            $caja_items = [ { nombre => 'Consulta de Seguimiento / Continuación de Tratamiento', precio => 0.00, cantidad => 1 } ];
            $tiene_cargos_directos = 1;
        }
    }
}

if (($id_cotizacion && ($convertir_tratamiento eq '1' || $id_tratamiento_param)) || $tiene_cargos_directos || $caja_monto_abono > 0) {
    my $cot_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cotizaciones.dat');
    my $items_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cotizaciones_items.dat');
    my $trat_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'tratamientos.dat');
    my $fin_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
    
    my $fecha_fin = ($caja_estado_tratamiento eq 'Cerrado') ? $hoy_fecha : '';
    my $proxima_cita_id = $q->param('proxima_cita_id') // '';
    my $caja_metodo_pago = $q->param('caja_metodo_pago') // 'Efectivo';
    
    my $id_tratamiento = $id_tratamiento_param;
    
    # Calcular total de cargos directos
    my $total_cargos_directos = 0;
    foreach my $it (@$caja_items) {
        $total_cargos_directos += ($it->{precio} || 0) * ($it->{cantidad} || 1);
    }
    
    if ($id_tratamiento) {
        # A. ACTUALIZAR TRATAMIENTO EXISTENTE
        if (-e $trat_file && open my $fh_t, '<:encoding(UTF-8)', $trat_file) {
            my @lineas = <$fh_t>;
            close $fh_t;
            
            my $cabecera = shift @lineas;
            chomp $cabecera if defined $cabecera;
            
            my @nuevas;
            foreach my $l (@lineas) {
                chomp $l;
                my @c = split /\|/, $l, -1;
                if ($c[0] eq $id_tratamiento) {
                    $c[3] = $caja_estado_tratamiento; # ESTADO
                    $c[5] = $fecha_fin;               # FECHA_FIN
                    $c[7] = ($c[7] || 0) + $total_cargos_directos; # TOTAL actualizado
                    $c[8] = $proxima_cita_id;         # ID_CITA
                    $l = join('|', @c);
                }
                push @nuevas, $l;
            }
            utils::db_manager::actualizar_archivo($trat_file, $cabecera, \@nuevas);
        }
    } else {
        # B. CREAR TRATAMIENTO NUEVO Y REGISTRAR CARGOS
        $id_tratamiento = 'TX-' . time() . '-' . int(rand(1000));
        
        my $total_cot = 0;
        if ($id_cotizacion) {
            # 1. Actualizar cotizaciones.dat para marcarla como 'Convertida'
            if (-e $cot_file && open my $fh_c, '<:encoding(UTF-8)', $cot_file) {
                my @lineas = <$fh_c>;
                close $fh_c;
                
                my $cabecera = shift @lineas;
                chomp $cabecera if defined $cabecera;
                
                my @nuevas;
                foreach my $l (@lineas) {
                    chomp $l;
                    my @c = split /\|/, $l, -1;
                    if ($c[0] eq $id_cotizacion) {
                        $total_cot = $c[3] // 0;
                        $c[6] = 'Convertida';
                        $l = join('|', @c);
                    }
                    push @nuevas, $l;
                }
                utils::db_manager::actualizar_archivo($cot_file, $cabecera, \@nuevas);
            }
        }
        
        # 2. Escribir fila en tratamientos.dat
        unless (-e $trat_file) {
            open my $fh_t, '>:encoding(UTF-8)', $trat_file;
            print $fh_t "ID_TRATAMIENTO|ID_PACIENTE|ID_COT|ESTADO|FECHA_INICIO|FECHA_FIN|ID_MEDICO|TOTAL|ID_CITA\n";
            close $fh_t;
        }
        
        my $total_trat = $total_cot + $total_cargos_directos;
        
        my $linea_trat = join('|', 
            $id_tratamiento, $id_paciente, $id_cotizacion, $caja_estado_tratamiento, 
            $hoy_fecha, $fecha_fin, $id_medico, $total_trat, $proxima_cita_id
        );
        utils::db_manager::guardar_registro($trat_file, $linea_trat);
        
        # 3. Registrar cargos iniciales de la cotización desde cotizaciones_items.dat
        if ($id_cotizacion) {
            my @items_cot;
            if (-e $items_file && open my $fh_i, '<:encoding(UTF-8)', $items_file) {
                my $header = <$fh_i>;
                while (my $line = <$fh_i>) {
                    chomp $line;
                    my @c = split /\|/, $line, -1;
                    next unless @c >= 5;
                    if ($c[0] eq $id_cotizacion) {
                        push @items_cot, {
                            concepto => $c[1],
                            subtotal => $c[4] // 0
                        };
                    }
                }
                close $fh_i;
            }
            
            unless (-e $fin_file) {
                open my $fh_f, '>:encoding(UTF-8)', $fin_file;
                print $fh_f "ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS\n";
                close $fh_f;
            }
            
            my $idx = 1;
            foreach my $it (@items_cot) {
                my $id_mov = 'MOV-' . time() . '-' . $idx++;
                my $nota_tratamiento = "Tratamiento: $id_tratamiento";
                $nota_tratamiento .= " | Cita #$id_cita" if $id_cita;
                $nota_tratamiento .= " | Consulta #$id_consulta";
                my $linea_cargo = join('|',
                    $id_tratamiento, $id_mov, $id_paciente, 'Cargo', $it->{concepto},
                    $it->{subtotal}, 0, $it->{subtotal}, $hoy_fecha, $id_medico,
                    $nota_tratamiento, ''
                );
                utils::db_manager::guardar_registro($fin_file, $linea_cargo);
            }
        }
    }
    
    # C. REGISTRAR CARGOS DIRECTOS (SI APLICA)
    if ($tiene_cargos_directos) {
        unless (-e $fin_file) {
            open my $fh_f, '>:encoding(UTF-8)', $fin_file;
            print $fh_f "ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS\n";
            close $fh_f;
        }
        
        my $idx_dir = 100;
        foreach my $it (@$caja_items) {
            my $id_mov = 'MOV-' . time() . '-' . $idx_dir++;
            my $sub = ($it->{precio} || 0) * ($it->{cantidad} || 1);
            my $nota_cargo = "Tratamiento: $id_tratamiento | Cargo Directo";
            $nota_cargo .= " | Cita #$id_cita" if $id_cita;
            $nota_cargo .= " | Consulta #$id_consulta";
            my $linea_cargo = join('|',
                $id_tratamiento, $id_mov, $id_paciente, 'Cargo', $it->{nombre},
                $sub, 0, $sub, $hoy_fecha, $id_medico,
                $nota_cargo, ''
            );
            utils::db_manager::guardar_registro($fin_file, $linea_cargo);
        }
    }
    
    # D. REGISTRAR ABONO EN CAJA (PARA TODOS LOS CASOS)
    if ($caja_monto_abono > 0) {
        unless (-e $fin_file) {
            open my $fh_f, '>:encoding(UTF-8)', $fin_file;
            print $fh_f "ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS\n";
            close $fh_f;
        }
        
        my $id_mov_abono = 'MOV-' . time() . '-ABONO';
        my $concepto_abono = "Abono en Caja - Metodo: $caja_metodo_pago";
        my $nota_abono = "Tratamiento: $id_tratamiento | Metodo: $caja_metodo_pago";
        $nota_abono .= " | Cita #$id_cita" if $id_cita;
        $nota_abono .= " | Consulta #$id_consulta";
        my $linea_abono = join('|',
            $id_tratamiento, $id_mov_abono, $id_paciente, 'Abono', $concepto_abono,
            $caja_monto_abono, 0, $caja_monto_abono, $hoy_fecha, $id_medico,
            $nota_abono, ''
        );
        utils::db_manager::guardar_registro($fin_file, $linea_abono);
    }
    
    # E. GENERAR RECIBO DE CAJA (FOLIOS CONSECUTIVOS POR SUCURSAL)
    if ($tiene_cargos_directos || $caja_monto_abono > 0) {
        my $id_raiz = catalogo_org_utils::resolver_id_raiz_catalogo($id_neg);
        my $next_folio = catalogo_org_utils::obtener_siguiente_folio_blindado($id_raiz, 0, $id_neg, $id_suc);
        my $folio_str = $next_folio;
        my $id_recibo = "RC-" . time() . "-" . int(rand(1000));
        my $elaborado_por = $session_data->{usuario} || $id_medico;
        
        my $recibos_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'folios_recibos_privados.dat');
        unless (-e $recibos_file) {
            open my $fh_r, '>:encoding(UTF-8)', $recibos_file;
            print $fh_r "ID_RECIBO|FOLIO|ID_NEGOCIO|ID_SUCURSAL|ID_CONSULTA|ID_PACIENTE|FECHA|HORA|TOTAL_CARGOS|TOTAL_ABONOS|METODO_PAGO|ELABORADO_POR|CONCEPTO|ITEMS_JSON|ESTATUS|ID_MEDICO|MOTIVO\n";
            close $fh_r;
        }
        
        # Preparar ítems estructurados para el recibo (ad-hoc para impresión)
        my @items_recibo;
        if (ref($caja_items) eq 'ARRAY' && @$caja_items) {
            foreach my $it (@$caja_items) {
                my $nom = $it->{nombre} || $it->{concepto} || 'Consulta y Servicios Médicos';
                my $cant = $it->{cantidad} || 1;
                my $pu = $it->{precio} || 0;
                my $sub = ($pu * $cant);
                push @items_recibo, {
                    concepto => $nom,
                    cantidad => int($cant),
                    precio   => sprintf('%.2f', $pu) + 0,
                    subtotal => sprintf('%.2f', $sub) + 0
                };
            }
        }
        if (!@items_recibo && $id_cotizacion) {
            my $items_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'cotizaciones_items.dat');
            if (-e $items_file && open my $fh_ci, '<:encoding(UTF-8)', $items_file) {
                my $hdr = <$fh_ci>;
                while (my $l = <$fh_ci>) {
                    chomp $l;
                    my @c = split /\|/, $l, -1;
                    if ($c[0] eq $id_cotizacion) {
                        push @items_recibo, {
                            concepto => $c[1] || 'Servicio Médico',
                            cantidad => int($c[2] || 1),
                            precio   => sprintf('%.2f', $c[3] || 0) + 0,
                            subtotal => sprintf('%.2f', $c[4] || 0) + 0
                        };
                    }
                }
                close $fh_ci;
            }
        }
        if (!@items_recibo) {
            my $monto_c = $total_cargos_directos > 0 ? $total_cargos_directos : ($caja_monto_abono > 0 ? $caja_monto_abono : 500);
            push @items_recibo, {
                concepto => 'Consulta Médica General',
                cantidad => 1,
                precio   => sprintf('%.2f', $monto_c) + 0,
                subtotal => sprintf('%.2f', $monto_c) + 0
            };
        }
        
        my $items_json_str = encode_json(\@items_recibo);
        my $concepto_recibo = @items_recibo ? $items_recibo[0]->{concepto} : 'Consulta Médica';
        
        my $linea_recibo = join('|',
            $id_recibo, $folio_str, $id_neg, $id_suc, $id_consulta, $id_paciente, $hoy_fecha, $hoy_hora,
            $total_cargos_directos, $caja_monto_abono, $caja_metodo_pago, $elaborado_por,
            $concepto_recibo, $items_json_str, 'Cobrado', $id_medico, ''
        );
        utils::db_manager::guardar_registro($recibos_file, $linea_recibo);
    }
}

# 3.6 Finalizar Odontograma asignado si aplica (Especialidad Odontología)
my $odonto_sel = $q->param('odonto_estudios_seleccionados') || $payload{odonto_estudios_seleccionados} || '';
my $odonto_finalizar = $q->param('odonto_finalizar_al_cerrar') // $payload{odonto_finalizar_al_cerrar} // '0';
my $espe_check = $payload{especialidad} // $payload{espe_nombre_medico} // $session_data->{rol} // '';
my $es_odontologia = ($espe_check =~ /odontolog/i || ($payload{id_espe_medico} && $payload{id_espe_medico} eq '100')) ? 1 : 0;

if ($odonto_sel && ($odonto_finalizar eq '1' || $es_odontologia)) {
    my @target_odontos = split /\s*,\s*/, $odonto_sel;
    my %targets = map { $_ => 1 } grep { $_ ne '' } @target_odontos;
    
    if (keys %targets) {
        my $odonto_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'odontogramas');
        my $json_file  = File::Spec->catfile($odonto_dir, "paciente_${id_paciente}.json");
        my $dat_file   = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');
        
        my $modificado = 0;
        my $perfil = undef;
        
        if (-e $json_file && open my $fh_j, '<:encoding(UTF-8)', $json_file) {
            flock($fh_j, LOCK_SH);
            local $/;
            my $content = <$fh_j>;
            close $fh_j;
            eval { $perfil = decode_json(encode_utf8($content)); };
        }
        
        if ($perfil && ref($perfil->{odontogramas}) eq 'ARRAY') {
            foreach my $od (@{ $perfil->{odontogramas} }) {
                if ($targets{$od->{id_odonto}}) {
                    $od->{estado} = 'Finalizado';
                    $od->{fecha_finalizado} = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
                    $modificado = 1;
                }
            }
            if ($modificado) {
                if (open my $fh_jw, '>:encoding(UTF-8)', $json_file) {
                    flock($fh_jw, LOCK_EX);
                    print $fh_jw JSON->new->utf8(0)->pretty(1)->encode($perfil);
                    flock($fh_jw, LOCK_UN);
                    close $fh_jw;
                }
            }
        }
        
        # Sincronizar estado en dat/odontogramas.dat si existe
        if (-e $dat_file && open my $fh_d, '<:encoding(UTF-8)', $dat_file) {
            my @d_lines = <$fh_d>;
            close $fh_d;
            my $d_cab = shift @d_lines;
            chomp $d_cab if defined $d_cab;
            my @nuevas_d;
            my $d_mod = 0;
            foreach my $dl (@d_lines) {
                chomp $dl;
                my @dc = split /\|/, $dl, -1;
                if ($dc[0] eq $id_paciente && $targets{$dc[1]}) {
                    $dc[3] = ($dc[3] // '') . " [Finalizado en Consulta $id_consulta]";
                    $dl = join('|', @dc);
                    $d_mod = 1;
                }
                push @nuevas_d, $dl;
            }
            if ($d_mod) {
                utils::db_manager::actualizar_archivo($dat_file, $d_cab, \@nuevas_d);
            }
        }
    }
}

# 4. Limpiar borrador de autosave
my $draft_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consulta_draft.dat');
my $id_draft = "DRAFT-$id_paciente"; 
if (-e $draft_file) {
    if (open my $fh_d, '<:encoding(UTF-8)', $draft_file) {
        my @lineas = <$fh_d>;
        close $fh_d;
        
        my @nuevas;
        my $cab = shift @lineas;
        chomp $cab if defined $cab;
        
        foreach my $l (@lineas) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            my $match_draft = ($c[0] eq $id_draft || ($c[1] && $c[1] eq $id_paciente) || ($id_cita && $c[2] && $c[2] eq $id_cita)) ? 1 : 0;
            push @nuevas, $l unless $match_draft;
        }
        utils::db_manager::actualizar_archivo($draft_file, $cab, \@nuevas);
    }
}

print encode_json({
    ok             => JSON::true,
    msg            => 'Consulta y transacciones de caja guardadas correctamente.',
    id_consulta    => $id_consulta,
    id_paciente    => $id_paciente,
    es_consultorio => $es_consultorio,
    recibo_script  => ($es_consultorio ? 'imprimir_recibo_caja_consultorio.pl' : 'imprimir_recibo_caja.pl')
});
exit;
