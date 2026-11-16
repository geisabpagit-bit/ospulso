#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std);
use CGI qw(-utf8);
use JSON::PP qw(encode_json decode_json);
use FindBin;
use File::Basename;
use File::Spec;
use lib "$FindBin::Bin/..";
use utils::db_manager qw(leer_tabla);
use Fcntl qw(:flock);

# ==========================================================
# OSPULSO / SDM - MOTOR DE AGENDA DE RENTA DE ESPACIOS v1.0
# Gestión Anticolisión de Consultorios y Quirófanos
# ==========================================================

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');
my $session_data = check_session();

my $dirname      = dirname(__FILE__);
my $ARCHIVO      = "$dirname/../dat/rentas_espacios.dat";
my $ARCHIVO_CITAS = "$dirname/../dat/citas.dat";
my $CONFIG_FILE  = "$dirname/../dat/agenda_config.dat";
my $HEADER       = "id_renta|id_arrendatario|nombre_arrendatario|telefono_arrendatario|correo_arrendatario|fecha|hora_ini|hora_fin|sucursal|espacio|tipo_espacio|motivo|notas|estado|monto_renta|pagado|folio_recibo|id_negocio|elaborado_por";

my $q = CGI->new;
my $accion = $q->param('accion') // '';
my $id_sucursal = $q->param('id_sucursal') // $q->param('sucursal') // $session_data->{id_empresa} // '1';

unless ($session_data->{session_ok}) {
    responder_json(0, "Sesión expirada o no válida.");
}

my $role_sesion = $session_data->{role} // '';
my $id_empresa_sesion = $session_data->{id_empresa} // '0';
my $id_usuario_sesion = $session_data->{id_registro} // $session_data->{id_medico} // '';

if ($role_sesion =~ /Administrador Global/i) {
    responder_json(0, "Por políticas de privacidad multi-tenant (NOM-004), el Administrador Global no opera agendas de organizaciones.");
}

# Validar capacidad SaaS "Renta de Espacios"
unless (tiene_capacidad_renta_espacios($id_empresa_sesion)) {
    responder_json(0, "La organización no tiene habilitada la capacidad SaaS 'Renta de Espacios'.");
}

my %CONF = cargar_agenda_config_sucursal($id_sucursal);

# Inicializar archivo si no existe
unless (-e $ARCHIVO) {
    if (open my $fh_init, '>:encoding(UTF-8)', $ARCHIVO) {
        print $fh_init "$HEADER\n";
        close $fh_init;
    }
}

my $rentas = cargar_rentas();
auto_actualizar_rentas_vencidas($rentas);

if    ($accion eq 'create')            { crear_renta($rentas, $q); }
elsif ($accion eq 'update')            { actualizar_renta($rentas, $q); }
elsif ($accion eq 'delete')            { eliminar_renta($rentas, $q); }
elsif ($accion eq 'save_config')       { guardar_config_agenda($q); }
elsif ($accion eq 'get_config')        { obtener_config_agenda($q); }
elsif ($accion eq 'get_form_metadata') { obtener_metadatos_formulario($q); }
elsif ($accion eq 'get_recursos')      { obtener_recursos_sucursal($q); }
elsif ($accion eq 'get_events')        { enviar_eventos_oficial($rentas); }
elsif ($accion eq 'cobrar_renta')      { cobrar_renta_recepcion($rentas, $q); }
else                                   { responder_json(0, "Acción no reconocida: $accion"); }

# ==========================================================
# SUBRUTINAS DE CONFIGURACIÓN Y GOBERNANZA
# ==========================================================

sub tiene_capacidad_renta_espacios {
    my ($id_emp) = @_;
    return 0 unless defined $id_emp && $id_emp ne '';
    my $cfg_file = "$dirname/../dat/negocios_config.dat";
    if (-e $cfg_file && open my $fh, '<:encoding(UTF-8)', $cfg_file) {
        while (my $line = <$fh>) {
            $line =~ s/\R//g;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            my ($biz, $k, $v) = split(/\|/, $line);
            if (defined $biz && $biz eq $id_emp && defined $k && $k eq 'CAPACIDAD' && defined $v && $v eq 'Renta de Espacios') {
                close $fh;
                return 1;
            }
        }
        close $fh;
    }
    return 0;
}

sub normalizar_espacio_perl {
    my ($str) = @_;
    return '' unless defined $str;
    $str = lc($str);
    $str =~ s/[áàäâ]/a/g;
    $str =~ s/[éèëê]/e/g;
    $str =~ s/[íìïî]/i/g;
    $str =~ s/[óòöô]/o/g;
    $str =~ s/[úùüû]/u/g;
    $str =~ s/ñ/n/g;
    $str =~ s/[^a-z0-9]/ /g;
    $str =~ s/\bquirofanos?\b/qx/g;
    $str =~ s/\bconsultorios?\b/cons/g;
    $str =~ s/\s+/ /g;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub cargar_agenda_config_sucursal {
    my ($id_suc) = @_;
    my %c = (
        laborStart => '07:00', laborEnd => '21:00',
        lunchStart => '14:00', lunchEnd => '15:00',
        workDays => [1,2,3,4,5,6,7], intervalo_minutos => 30,
        cancel_hours => 24,
        festivos => '',
        festivos_global => '',
        festivos_sucursal => ''
    );

    if (-e $CONFIG_FILE) {
        my %g = ();
        _parse_config_file($CONFIG_FILE, \%g);
        $c{festivos_global} = $g{festivos} // '';
        foreach my $k (keys %g) { $c{$k} = $g{$k} unless $k eq 'festivos'; }
    }

    if ($id_suc) {
        my $SUC_CONFIG = "$dirname/../dat/agenda_config_sucursal_$id_suc.dat";
        if (-e $SUC_CONFIG) {
            my %s = ();
            _parse_config_file($SUC_CONFIG, \%s);
            $c{festivos_sucursal} = $s{festivos} // '';
            foreach my $k (keys %s) {
                next if $k eq 'festivos';
                $c{$k} = $s{$k};
            }
        }
    }

    my @unificados = ();
    push @unificados, split(/,/, $c{festivos_global}) if $c{festivos_global};
    push @unificados, split(/,/, $c{festivos_sucursal}) if $c{festivos_sucursal};
    my %seen = ();
    my @limpios = grep { $_ && !$seen{$_}++ } map { s/^\s+|\s+$//g; $_ } @unificados;
    $c{festivos} = join(',', @limpios);

    return %c;
}

sub _parse_config_file {
    my ($file, $ref) = @_;
    if (open my $fh, '<:encoding(UTF-8)', $file) {
        while (my $line = <$fh>) {
            chomp $line; $line =~ s/\r//g;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            my ($key, $val) = split(/=/, $line, 2);
            if ($key eq 'horario_inicio') { $ref->{laborStart} = $val; }
            elsif ($key eq 'horario_fin') { $ref->{laborEnd} = $val; }
            elsif ($key eq 'horario_comida_inicio') { $ref->{lunchStart} = $val; }
            elsif ($key eq 'horario_comida_fin') { $ref->{lunchEnd} = $val; }
            elsif ($key eq 'dias_habiles') {
                my @ds = map { $_ eq '0' ? '7' : $_ } split(/,/, $val);
                $ref->{workDays} = \@ds;
            }
            elsif ($key eq 'intervalo_minutos') { $ref->{intervalo_minutos} = $val; }
            elsif ($key eq 'cancel_hours') { $ref->{cancel_hours} = $val; }
            elsif ($key eq 'festivos') { $ref->{festivos} = $val; }
        }
        close $fh;
    }
}

# ==========================================================
# PERSISTENCIA DE RENTAS DE ESPACIOS
# ==========================================================

sub cargar_rentas {
    my @lista;
    if (-e $ARCHIVO && open my $fh, '<:encoding(UTF-8)', $ARCHIVO) {
        my $cnt = 0;
        while (my $line = <$fh>) {
            $cnt++;
            $line =~ s/\R//g;
            next if $cnt == 1 || $line =~ /^\s*$/ || $line =~ /^id_renta\|/i;
            my @f = split(/\|/, $line, -1);
            next unless scalar(@f) >= 14;
            foreach (@f) { s/^\s+//; s/\s+$//; }
            push @lista, {
                id_renta              => $f[0],
                id_arrendatario       => $f[1] // '',
                nombre_arrendatario   => $f[2] // '',
                telefono_arrendatario => $f[3] // '',
                correo_arrendatario   => $f[4] // '',
                fecha                 => $f[5] // '',
                hora_ini              => $f[6] // '',
                hora_fin              => $f[7] // '',
                sucursal              => $f[8] // '',
                espacio               => $f[9] // '',
                tipo_espacio          => $f[10] // 'Consultorio',
                motivo                => $f[11] // '',
                notas                 => $f[12] // '',
                estado                => $f[13] // 'Reservada',
                monto_renta           => $f[14] // '0.00',
                pagado                => $f[15] // '0',
                folio_recibo          => $f[16] // '',
                id_negocio            => $f[17] // '',
                elaborado_por         => $f[18] // ''
            };
        }
        close $fh;
    }
    return \@lista;
}

sub guardar_rentas {
    my ($arr) = @_;
    open my $fh, '>:encoding(UTF-8)', $ARCHIVO or die "Error Crítico de Escritura en rentas_espacios.dat: $!";
    flock($fh, LOCK_EX) or die "No se pudo bloquear rentas_espacios.dat (LOCK_EX): $!";
    print $fh "$HEADER\n";
    foreach my $r (@$arr) {
        print $fh join('|',
            $r->{id_renta}              // '',
            $r->{id_arrendatario}       // '',
            $r->{nombre_arrendatario}   // '',
            $r->{telefono_arrendatario} // '',
            $r->{correo_arrendatario}   // '',
            $r->{fecha}                 // '',
            $r->{hora_ini}              // '',
            $r->{hora_fin}              // '',
            $r->{sucursal}              // '',
            $r->{espacio}               // '',
            $r->{tipo_espacio}          // 'Consultorio',
            $r->{motivo}                // '',
            $r->{notas}                 // '',
            $r->{estado}                // 'Reservada',
            $r->{monto_renta}           // '0.00',
            $r->{pagado}                // '0',
            $r->{folio_recibo}          // '',
            $r->{id_negocio}            // '',
            $r->{elaborado_por}         // ''
        ) . "\n";
    }
    close $fh;
}

sub auto_actualizar_rentas_vencidas {
    my ($arr) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $hoy = sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
    my $hora_actual = sprintf("%02d:%02d", $hour, $min);

    my $cambios = 0;
    foreach my $r (@$arr) {
        my $estado = $r->{estado} // '';
        $estado =~ s/^\s+|\s+$//g;
        next if $estado =~ /^(Finalizada|Atendida|Cancelada|No realizada|En Uso|En consulta|Consulta en proceso)$/i;

        my $fec = $r->{fecha} // '';
        my $hf  = $r->{hora_fin} // '';
        next unless $fec;

        my $vencida = 0;
        if ($fec lt $hoy) {
            $vencida = 1;
        } elsif ($fec eq $hoy && $hf && $hf lt $hora_actual) {
            $vencida = 1;
        }

        if ($vencida) {
            $r->{estado} = 'No realizada';
            $cambios++;
        }
    }
    if ($cambios > 0) {
        guardar_rentas($arr);
    }
}

# ==========================================================
# OPERACIONES CRUD CON VALIDACIÓN ANTICOLISIÓN BIDIRECCIONAL
# ==========================================================

sub crear_renta {
    my ($arr, $query) = @_;
    unless (utils::permisos_utils::tiene_permiso_modulo($id_empresa_sesion, $role_sesion, 'agenda_espacios', 'C', $id_usuario_sesion)) {
        responder_json(0, "No cuenta con permisos para crear reservas de espacios.");
        return;
    }

    my ($fec, $hi, $hf) = ($query->param('fecha') // '', $query->param('hora_ini') // '', $query->param('hora_fin') // '');
    my $sucursal = $query->param('sucursal') // $id_empresa_sesion;
    my $espacio  = $query->param('espacio') // $query->param('consultorio') // '';
    my $motivo   = $query->param('motivo') // '';
    my $notas    = $query->param('notas') // '';
    my $id_arr   = $query->param('id_arrendatario') // $query->param('id_medico') // '';
    my $nom_arr  = $query->param('nombre_arrendatario') // '';
    my $tel_arr  = $query->param('telefono_arrendatario') // '';
    my $cor_arr  = $query->param('correo_arrendatario') // '';
    my $monto    = $query->param('monto_renta') // '0.00';

    $motivo  =~ s/^\s+|\s+$//g;
    $espacio =~ s/^\s+|\s+$//g;
    $nom_arr =~ s/^\s+|\s+$//g;
    $notas   =~ s/\|/ /g;
    $motivo  =~ s/\|/ /g;

    unless ($espacio && $espacio ne 'Virtual') {
        responder_json(0, "Debe seleccionar un Consultorio o Quirófano físico válido.");
        return;
    }
    unless ($motivo) {
        responder_json(0, "El campo Uso / Procedimiento / Motivo es obligatorio.");
        return;
    }

    # Resolver datos del arrendatario si es un médico interno de usuarios.dat
    if ($id_arr && $id_arr ne 'EXTERNO' && !$nom_arr) {
        my ($n_med, $c_med) = obtener_datos_medico_org($id_arr);
        $nom_arr = $n_med if $n_med;
        $cor_arr = $c_med if $c_med && !$cor_arr;
    }
    unless ($nom_arr) {
        responder_json(0, "Debe indicar el Médico o Arrendatario responsable del espacio.");
        return;
    }

    my ($ok_h, $msg_h) = validar_horario_sucursal($fec, $hi, $hf, $sucursal);
    unless ($ok_h) { responder_json(0, $msg_h); return; }

    my ($ok_c, $msg_c) = detectar_colisiones_espacio($arr, $fec, $hi, $hf, $sucursal, $espacio, undef, $id_arr);
    unless ($ok_c) { responder_json(0, $msg_c); return; }

    my $estado_sol = $query->param('estado') // 'Reservada';
    $estado_sol =~ s/^\s+|\s+$//g;
    if ($estado_sol =~ /^(Cancelada|No realizada|Finalizada|Atendida)$/i) {
        responder_json(0, "No está permitido crear una reserva nueva con estado $estado_sol.");
        return;
    }
    my $estado_final = ($estado_sol eq 'Confirmada' || $estado_sol eq 'En Uso') ? $estado_sol : 'Reservada';
    my $tipo_espacio = ($espacio =~ /Quir[oó]fano/i) ? 'Quirofano' : 'Consultorio';
    $monto = sprintf("%.2f", ($monto =~ /^[0-9.]+$/ ? $monto + 0 : 0));

    my $new_id = "REN-" . time() . "-" . int(rand(900) + 100);
    my $nueva_renta = {
        id_renta              => $new_id,
        id_arrendatario       => $id_arr || 'EXTERNO',
        nombre_arrendatario   => $nom_arr,
        telefono_arrendatario => $tel_arr,
        correo_arrendatario   => $cor_arr,
        fecha                 => $fec,
        hora_ini              => $hi,
        hora_fin              => $hf,
        sucursal              => $sucursal,
        espacio               => $espacio,
        tipo_espacio          => $tipo_espacio,
        motivo                => $motivo,
        notas                 => $notas,
        estado                => $estado_final,
        monto_renta           => $monto,
        pagado                => '0',
        folio_recibo          => '',
        id_negocio            => $id_empresa_sesion,
        elaborado_por         => $session_data->{uid} // $session_data->{usuario} // ''
    };

    push @$arr, $nueva_renta;
    guardar_rentas($arr);
    sincronizar_renta_con_quirofano($nueva_renta, 0);

    print "Content-Type: application/json; charset=UTF-8\n\n";
    binmode STDOUT, ":raw";
    print encode_json({
        ok => 1,
        msg => "Espacio ($espacio) reservado exitosamente para $nom_arr.",
        id_renta => $new_id
    });
    exit;
}

sub actualizar_renta {
    my ($arr, $query) = @_;
    unless (utils::permisos_utils::tiene_permiso_modulo($id_empresa_sesion, $role_sesion, 'agenda_espacios', 'U', $id_usuario_sesion)) {
        responder_json(0, "No cuenta con permisos para modificar reservas de espacios.");
        return;
    }

    my $id_r     = $query->param('id_renta') // $query->param('id_cita') // '';
    my ($fec, $hi, $hf) = ($query->param('fecha') // '', $query->param('hora_ini') // '', $query->param('hora_fin') // '');
    my $sucursal = $query->param('sucursal') // '';
    my $espacio  = $query->param('espacio') // $query->param('consultorio') // '';
    my $motivo   = $query->param('motivo') // '';
    my $notas    = $query->param('notas') // '';
    my $id_arr   = $query->param('id_arrendatario') // $query->param('id_medico') // '';
    my $nom_arr  = $query->param('nombre_arrendatario') // '';
    my $tel_arr  = $query->param('telefono_arrendatario') // '';
    my $cor_arr  = $query->param('correo_arrendatario') // '';
    my $monto    = $query->param('monto_renta');

    $motivo  =~ s/^\s+|\s+$//g;
    $espacio =~ s/^\s+|\s+$//g;
    $nom_arr =~ s/^\s+|\s+$//g;

    unless ($id_r)   { responder_json(0, "ID de reserva requerido."); return; }
    unless ($motivo) { responder_json(0, "El campo Uso / Procedimiento es obligatorio."); return; }

    my ($ok_h, $msg_h) = validar_horario_sucursal($fec, $hi, $hf, $sucursal);
    unless ($ok_h) { responder_json(0, $msg_h); return; }

    my ($ok_c, $msg_c) = detectar_colisiones_espacio($arr, $fec, $hi, $hf, $sucursal, $espacio, $id_r, $id_arr);
    unless ($ok_c) { responder_json(0, $msg_c); return; }

    my $found;
    foreach my $r (@$arr) {
        if ($r->{id_renta} eq $id_r) {
            if (($r->{estado} // '') =~ /^(Finalizada|Atendida)$/i && ($query->param('estado') // '') !~ /^(Finalizada|Atendida)$/i) {
                responder_json(0, "La reserva ya fue Finalizada y está bloqueada para edición de horario.");
                return;
            }
            if ($id_arr && $id_arr ne 'EXTERNO' && !$nom_arr) {
                my ($n_med, $c_med) = obtener_datos_medico_org($id_arr);
                $nom_arr = $n_med if $n_med;
                $cor_arr = $c_med if $c_med && !$cor_arr;
            }
            $r->{fecha}                 = $fec if $fec;
            $r->{hora_ini}              = $hi  if $hi;
            $r->{hora_fin}              = $hf  if $hf;
            $r->{motivo}                = $motivo;
            $r->{notas}                 = $notas if defined $query->param('notas');
            $r->{estado}                = $query->param('estado') // $r->{estado};
            $r->{id_arrendatario}       = $id_arr if $id_arr;
            $r->{nombre_arrendatario}   = $nom_arr if $nom_arr;
            $r->{telefono_arrendatario} = $tel_arr if defined $query->param('telefono_arrendatario');
            $r->{correo_arrendatario}   = $cor_arr if defined $query->param('correo_arrendatario');
            $r->{sucursal}              = $sucursal if $sucursal;
            $r->{espacio}               = $espacio if $espacio;
            $r->{tipo_espacio}          = ($r->{espacio} =~ /Quir[oó]fano/i) ? 'Quirofano' : 'Consultorio';
            if (defined $monto && $monto ne '') {
                $r->{monto_renta} = sprintf("%.2f", ($monto =~ /^[0-9.]+$/ ? $monto + 0 : 0));
            }
            $found = $r;
            last;
        }
    }

    if ($found) {
        guardar_rentas($arr);
        sincronizar_renta_con_quirofano($found, 0);
        responder_json(1, "Reserva de espacio actualizada correctamente.");
    } else {
        responder_json(0, "No se encontró el registro de la reserva.");
    }
}

sub eliminar_renta {
    my ($arr, $query) = @_;
    unless (utils::permisos_utils::tiene_permiso_modulo($id_empresa_sesion, $role_sesion, 'agenda_espacios', 'D', $id_usuario_sesion)) {
        responder_json(0, "No cuenta con permisos para eliminar reservas de espacios.");
        return;
    }

    my $target = $query->param('id_renta') // $query->param('id_cita') // '';
    my @filtrados;
    my $eliminado;

    foreach my $r (@$arr) {
        if ($r->{id_renta} eq $target) {
            if (($r->{estado} // '') =~ /^(Finalizada|Atendida)$/i || ($r->{pagado} // '0') eq '1') {
                responder_json(0, "La reserva ya fue Finalizada o Cobrada y no se puede eliminar.");
                return;
            }
            $eliminado = $r;
        } else {
            push @filtrados, $r;
        }
    }

    if ($eliminado) {
        guardar_rentas(\@filtrados);
        sincronizar_renta_con_quirofano($eliminado, 1);
        responder_json(1, "Reserva de espacio eliminada correctamente.");
    } else {
        responder_json(0, "No se localizó la reserva especificada.");
    }
}

# ==========================================================
# VALIDACIÓN HORARIA Y MOTOR ANTICOLISIÓN BIDIRECCIONAL
# ==========================================================

sub validar_horario_sucursal {
    my ($fec, $hi, $hf, $suc) = @_;
    my %conf_s = cargar_agenda_config_sucursal($suc || $id_sucursal);

    if ($hi ge $hf) {
        return (0, "La hora de inicio ($hi) debe ser menor a la hora de fin ($hf).");
    }
    if ($hi lt $conf_s{laborStart} || $hf gt $conf_s{laborEnd}) {
        return (0, "Fuera del horario de apertura de la sucursal ($conf_s{laborStart} - $conf_s{laborEnd}).");
    }
    if ($hf ne $conf_s{laborEnd} && $conf_s{lunchStart} && $conf_s{lunchEnd} && $conf_s{lunchStart} ne $conf_s{lunchEnd}) {
        if ($hi lt $conf_s{lunchEnd} && $hf gt $conf_s{lunchStart}) {
            return (0, "Traslape con el horario de receso de la sede ($conf_s{lunchStart} - $conf_s{lunchEnd}).");
        }
    }

    use Time::Piece;
    my $t = eval { Time::Piece->strptime($fec, "%Y-%m-%d") };
    return (0, "Fecha inválida.") if $@;
    my $wday = $t->wday;
    my $iso_wday = ($wday == 1) ? 7 : $wday - 1;

    my $found_day = 0;
    foreach my $d (@{$conf_s{workDays}}) {
        my $norm_d = ($d eq '0') ? 7 : $d;
        if ($norm_d == $iso_wday) { $found_day = 1; last; }
    }
    unless ($found_day) { return (0, "El día seleccionado no es laborable en esta sucursal."); }

    if ($conf_s{festivos}) {
        foreach my $f (split(/,/, $conf_s{festivos})) {
            $f =~ s/^\s+|\s+$//g;
            if ($f eq $fec) { return (0, "El día seleccionado está marcado como inhábil/festivo en la sucursal."); }
        }
    }
    return (1, "OK");
}

sub detectar_colisiones_espacio {
    my ($arr_rentas, $fec, $hi, $hf, $sucursal, $espacio, $exclude_id, $id_arrendatario) = @_;
    $exclude_id //= '';
    my $esp_norm = normalizar_espacio_perl($espacio);
    return (0, "Espacio físico no especificado.") unless $esp_norm;

    my ($hi_h, $hi_m) = split(/:/, $hi);
    my $hi_min = ($hi_h // 0) * 60 + ($hi_m // 0);
    my ($hf_h, $hf_m) = split(/:/, $hf);
    my $hf_min = ($hf_h // 0) * 60 + ($hf_m // 0);

    my %conf_s = cargar_agenda_config_sucursal($sucursal);
    my $es_dia_completo = ($hi le $conf_s{laborStart} && $hf ge $conf_s{laborEnd}) ? 1 : 0;

    # 1. VERIFICAR CONTRA OTRAS RENTAS EN rentas_espacios.dat
    foreach my $r (@$arr_rentas) {
        next if $exclude_id && $r->{id_renta} eq $exclude_id;
        next if $r->{fecha} ne $fec;
        next if ($r->{estado} // '') =~ /^(Cancelada|No realizada)$/i;
        next if $r->{id_negocio} ne '' && $r->{id_negocio} ne $id_empresa_sesion;

        my $misma_suc = (!$sucursal || !$r->{sucursal} || $r->{sucursal} eq $sucursal) ? 1 : 0;
        next unless $misma_suc;

        my $r_esp_norm = normalizar_espacio_perl($r->{espacio});
        if ($r_esp_norm eq $esp_norm) {
            if ($es_dia_completo) {
                return (0, "No se puede reservar Día Completo porque el espacio ($espacio) ya tiene una renta activa de $r->{nombre_arrendatario} ($r->{hora_ini} - $r->{hora_fin}).");
            }
            my ($rhi_h, $rhi_m) = split(/:/, $r->{hora_ini});
            my $rhi_min = ($rhi_h // 0) * 60 + ($rhi_m // 0);
            my ($rhf_h, $rhf_m) = split(/:/, $r->{hora_fin});
            my $rhf_min = ($rhf_h // 0) * 60 + ($rhf_m // 0);

            if ($hi_min < $rhf_min && $hf_min > $rhi_min) {
                return (0, "Colisión de Espacio: $espacio ya está reservado por $r->{nombre_arrendatario} en el horario $r->{hora_ini} - $r->{hora_fin}.");
            }
        }
    }

    # 2. VERIFICACIÓN TRANSVERSAL CONTRA AGENDA DE PACIENTES (citas.dat)
    if (-e $ARCHIVO_CITAS && open my $fh_c, '<:encoding(UTF-8)', $ARCHIVO_CITAS) {
        my $cnt = 0;
        while (my $line = <$fh_c>) {
            $cnt++;
            $line =~ s/\R//g;
            next if $cnt == 1 || $line =~ /^\s*$/;
            my @f = split(/\|/, $line);
            next unless scalar(@f) >= 14;
            my $c_med = $f[1] // '';
            my $c_fec = $f[3] // '';
            my $c_hi  = $f[4] // '';
            my $c_hf  = $f[5] // '';
            my $c_mot = $f[6] // 'Consulta Médica';
            my $c_est = $f[8] // 'Programada';
            my $c_suc = $f[12] // '';
            my $c_con = $f[13] // '';
            my $c_neg = $f[14] // '';

            next if $c_fec ne $fec;
            next if $c_est =~ /^(Cancelada|No realizada)$/i;
            next if $c_neg ne '' && $c_neg ne $id_empresa_sesion;

            my $misma_suc = (!$sucursal || !$c_suc || $c_suc eq $sucursal) ? 1 : 0;
            next unless $misma_suc;

            my $c_esp_norm = normalizar_espacio_perl($c_con);
            if ($c_esp_norm && $c_esp_norm eq $esp_norm) {
                # Si la cita de paciente pertenece al mismo médico que está rentando el bloque, no es colisión hostil
                next if ($id_arrendatario && $id_arrendatario ne 'EXTERNO' && $c_med eq $id_arrendatario);

                if ($es_dia_completo) {
                    close $fh_c;
                    return (0, "No se puede reservar Día Completo porque $espacio tiene una cita de pacientes programada ($c_hi - $c_hf: $c_mot).");
                }
                my ($chi_h, $chi_m) = split(/:/, $c_hi);
                my $chi_min = ($chi_h // 0) * 60 + ($chi_m // 0);
                my ($chf_h, $chf_m) = split(/:/, $c_hf);
                my $chf_min = ($chf_h // 0) * 60 + ($chf_m // 0);

                if ($hi_min < $chf_min && $hf_min > $chi_min) {
                    close $fh_c;
                    return (0, "Colisión con Agenda de Pacientes: El espacio ($espacio) está ocupado por una consulta/cirugía de $c_hi a $c_hf ($c_mot).");
                }
            }
        }
        close $fh_c;
    }

    return (1, "OK");
}

# ==========================================================
# ENVÍO DE EVENTOS (RENTAS + ESPEJO DE OCUPACIÓN PACIENTES)
# ==========================================================

sub enviar_eventos_oficial {
    my ($arr) = @_;
    my @eventos;
    my $my_org = $session_data->{id_empresa} // '0';
    $my_org = '0' if $my_org eq '';
    my $filtro_arrendatario = $q->param('id_medico') // '';

    my %meds_org;
    my %meds_nombres;
    my $file_usu = "$dirname/../dat/usuarios.dat";
    if (-e $file_usu && open my $fh_u, '<:encoding(UTF-8)', $file_usu) {
        my $cnt = 0;
        while (my $l = <$fh_u>) {
            $cnt++;
            $l =~ s/\R//g;
            next if $cnt == 1 || $l =~ /^\s*$/;
            my @u = split(/!/, $l);
            my ($u_biz) = split(/:/, $u[6] // '');
            $meds_nombres{$u[0]} = $u[1];
            if ($u_biz eq $my_org || ($my_org eq '0' && ($u_biz eq '0' || $u_biz eq ''))) {
                $meds_org{$u[0]} = 1;
            }
        }
        close $fh_u;
    }

    # 1. Eventos de Renta de Espacios
    foreach my $r (@$arr) {
        next if ($r->{estado} // '') eq 'Cancelada';
        next if $r->{id_negocio} ne '' && $r->{id_negocio} ne $my_org;

        if ($filtro_arrendatario && $filtro_arrendatario ne 'all' && $filtro_arrendatario ne '0') {
            my $es_solo_admin_sesion = ($session_data->{role} =~ /^(Administrador|Recepcion|Asistente)/i && $session_data->{role} !~ /Medico/i);
            unless ($es_solo_admin_sesion && $filtro_arrendatario eq ($session_data->{id_medico} // '')) {
                next unless $r->{id_arrendatario} eq $filtro_arrendatario;
            }
        }

        my $es_pagado = ($r->{pagado} eq '1' || $r->{estado} =~ /^(Finalizada|Atendida|Confirmada \(Pagada\))$/i) ? 1 : 0;
        my $color = ($r->{estado} eq 'No realizada') ? '#ef4444' :
                    ($r->{estado} =~ /^(En Uso|En consulta|Consulta en proceso)$/i) ? '#059669' :
                    ($r->{estado} =~ /^(Finalizada|Atendida)$/i) ? '#19B7A5' :
                    ($r->{estado} =~ /^Confirmada/i) ? '#10b981' :
                    (($r->{espacio} && $r->{espacio} =~ /quir/i) ? '#dc3545' : '#0A2A66');

        push @eventos, {
            id => $r->{id_renta},
            title => $r->{nombre_arrendatario} || 'Espacio Reservado',
            start => "$r->{fecha}T$r->{hora_ini}:00",
            end   => "$r->{fecha}T$r->{hora_fin}:00",
            color => $color,
            extendedProps => {
                es_renta              => 1,
                es_bloqueo_pacientes  => 0,
                id_renta              => $r->{id_renta},
                id_arrendatario       => $r->{id_arrendatario},
                paciente              => $r->{nombre_arrendatario},
                nombre_arrendatario   => $r->{nombre_arrendatario},
                telefono              => $r->{telefono_arrendatario},
                correo                => $r->{correo_arrendatario},
                id_medico             => $r->{id_arrendatario},
                medico                => $r->{nombre_arrendatario},
                motivo                => $r->{motivo},
                notas                 => $r->{notas},
                estado                => $r->{estado},
                sucursal              => $r->{sucursal},
                consultorio           => $r->{espacio},
                espacio               => $r->{espacio},
                tipo_espacio          => $r->{tipo_espacio},
                monto_renta           => $r->{monto_renta} || '0.00',
                pagado                => $es_pagado,
                folio_recibo          => $r->{folio_recibo} || ''
            }
        };
    }

    # 2. Espejo de Ocupación desde Agenda de Pacientes (citas.dat) para visibilidad anticolisión
    if (-e $ARCHIVO_CITAS && open my $fh_c, '<:encoding(UTF-8)', $ARCHIVO_CITAS) {
        my $cnt = 0;
        while (my $line = <$fh_c>) {
            $cnt++;
            $line =~ s/\R//g;
            next if $cnt == 1 || $line =~ /^\s*$/;
            my @f = split(/\|/, $line);
            next unless scalar(@f) >= 14;
            my $c_id  = $f[0] // '';
            my $c_med = $f[1] // '';
            my $c_fec = $f[3] // '';
            my $c_hi  = $f[4] // '';
            my $c_hf  = $f[5] // '';
            my $c_mot = $f[6] // 'Consulta de Paciente';
            my $c_est = $f[8] // 'Programada';
            my $c_suc = $f[12] // '';
            my $c_con = $f[13] // '';
            my $c_neg = $f[14] // '';

            next if $c_est =~ /^(Cancelada|No realizada)$/i;
            next if !$c_con || $c_con eq 'Virtual';
            if (keys %meds_org) {
                next unless $meds_org{$c_med};
            }

            my $nom_med = $meds_nombres{$c_med} // 'Médico Clínico';
            push @eventos, {
                id => "CIT-BLK-$c_id",
                title => "Ocupado (Cita: $nom_med)",
                start => "${c_fec}T${c_hi}:00",
                end   => "${c_fec}T${c_hf}:00",
                color => '#64748b',
                extendedProps => {
                    es_renta              => 0,
                    es_bloqueo_pacientes  => 1,
                    id_cita_origen        => $c_id,
                    paciente              => "Agenda Pacientes ($nom_med)",
                    nombre_arrendatario   => $nom_med,
                    telefono              => '',
                    id_medico             => $c_med,
                    medico                => $nom_med,
                    motivo                => "Ocupado en Agenda Pacientes: $c_mot",
                    notas                 => "Reserva originada en Agenda de Pacientes",
                    estado                => 'Ocupado (Pacientes)',
                    sucursal              => $c_suc,
                    consultorio           => $c_con,
                    espacio               => $c_con,
                    tipo_espacio          => ($c_con =~ /Quir[oó]fano/i ? 'Quirofano' : 'Consultorio'),
                    monto_renta           => '0.00',
                    pagado                => 1
                }
            };
        }
        close $fh_c;
    }

    print "Content-Type: application/json; charset=UTF-8\n\n";
    binmode STDOUT, ":raw";
    print encode_json({ ok => 1, data => \@eventos, config => \%CONF });
    exit;
}

# ==========================================================
# RECURSOS DE SUCURSAL Y METADATOS (CONSULTORIOS Y QUIRÓFANOS)
# ==========================================================

sub obtener_metadatos_formulario {
    my ($q) = @_;
    my @medicos;
    my @sucursales;

    my $my_org = $session_data->{id_empresa} // '0';
    $my_org = '0' if $my_org eq '';

    my $tipo_org = 'Clínica';
    my $file_cfg = "$dirname/../dat/negocios_config.dat";
    if (-e $file_cfg && open my $fh_cfg, '<:encoding(UTF-8)', $file_cfg) {
        while (my $line = <$fh_cfg>) {
            $line =~ s/\R//g;
            my @f = split(/\|/, $line);
            if (($f[0] // '') eq $my_org && ($f[1] // '') eq 'TIPO_ORGANIZACION') {
                $tipo_org = $f[2] // 'Clínica';
                last;
            }
        }
        close $fh_cfg;
    }

    my $file_usu = "$dirname/../dat/usuarios.dat";
    if (-e $file_usu && open my $fh, '<:encoding(UTF-8)', $file_usu) {
        my $cnt = 0;
        while (my $line = <$fh>) {
            $cnt++;
            $line =~ s/\R//g;
            next if $cnt == 1 || $line =~ /^\s*$/;
            my @f = split(/!/, $line);
            next unless scalar(@f) >= 7;
            my ($u_biz) = split(/:/, $f[6] // '');
            next unless ($u_biz eq $my_org || ($my_org eq '0' && ($u_biz eq '0' || $u_biz eq '')));
            my $es_med = ($f[5] =~ /(?:^|,)Medico(?:,|$)/) || ($f[5] =~ /Administrador/ && defined $f[7] && $f[7] ne '' && $f[7] ne '0');
            if ($f[4] == 1 && $es_med) {
                push @medicos, { id => $f[0], nombre => $f[1], correo => $f[2] // '', rol_quirurgico => $f[12] // '' };
            }
        }
        close $fh;
    }

    my $file_neg = "$dirname/../dat/negocios.dat";
    my $nombre_matriz = 'Sede Principal';
    if (-e $file_neg && open my $fh, '<:encoding(UTF-8)', $file_neg) {
        my @hijas;
        while (my $line = <$fh>) {
            $line =~ s/\R//g;
            my @f = split(/\|/, $line);
            next unless scalar(@f) >= 3;
            if ($f[0] eq $my_org) {
                $nombre_matriz = $f[1];
            }
            if (($f[3] // '1') eq '1' && ($f[2] // '') eq $my_org && $my_org ne '0') {
                push @hijas, { id => $f[0], nombre => $f[1], tipo => "Sucursal" };
            }
        }
        close $fh;
        if (@hijas) {
            push @sucursales, @hijas;
        } else {
            push @sucursales, { id => $my_org, nombre => $nombre_matriz, tipo => "Matriz" };
        }
    }

    print $q->header(-type => 'application/json', -charset => 'utf-8');
    print encode_json({
        ok => 1,
        tipo_organizacion => $tipo_org,
        es_consultorio_ind => 0,
        medicos => \@medicos,
        sucursales => \@sucursales
    });
    exit;
}

sub obtener_recursos_sucursal {
    my ($q) = @_;
    my $id_sucursal_solicitada = $q->param('id_sucursal') // '';
    my $my_org = $session_data->{id_empresa} // '0';
    $my_org = '0' if $my_org eq '';

    my $file_cfg = "$dirname/../dat/negocios_config.dat";
    my $file_neg = "$dirname/../dat/negocios.dat";

    my %config_por_negocio;
    if (-e $file_cfg && open my $fh, '<:encoding(UTF-8)', $file_cfg) {
        while (my $line = <$fh>) {
            $line =~ s/\R//g;
            next if $line =~ /^\s*$/;
            my @f = split(/\|/, $line);
            next unless scalar(@f) >= 3;
            $config_por_negocio{$f[0]}{$f[1]} = $f[2];
        }
        close $fh;
    }

    my @sucursales;
    my @filas_hijas;
    my $fila_matriz;

    if (-e $file_neg && open my $fhn, '<:encoding(UTF-8)', $file_neg) {
        while (my $nl = <$fhn>) {
            $nl =~ s/\R//g;
            my @nf = split(/\|/, $nl);
            next unless scalar(@nf) >= 3;
            my $id_neg = $nf[0];
            my $id_matriz = $nf[2] // '0';
            my $activo = $nf[3] // '1';
            next if $activo ne '1' && $activo ne '';

            if ($id_matriz eq $my_org && $id_matriz ne '0') {
                push @filas_hijas, \@nf;
            } elsif ($id_neg eq $my_org) {
                $fila_matriz = \@nf;
            }
        }
        close $fhn;
    }

    my @filas_operativas = (@filas_hijas > 0) ? @filas_hijas : ($fila_matriz ? ($fila_matriz) : ());

    foreach my $nf (@filas_operativas) {
        my $id_neg  = $nf->[0];
        my $nom_neg = $nf->[1];
        my $c_num   = $config_por_negocio{$id_neg}{CONSULTORIOS} // $config_por_negocio{$my_org}{CONSULTORIOS} // 1;
        my $q_num   = $config_por_negocio{$id_neg}{QUIROFANOS}   // $config_por_negocio{$my_org}{QUIROFANOS}   // 0;
        $c_num = int($c_num) || 1;
        $q_num = int($q_num) || 0;

        my $nom_lower = lc($nom_neg);
        $nom_lower =~ s/[áàä]/a/g; $nom_lower =~ s/[éèë]/e/g; $nom_lower =~ s/[íìï]/i/g; $nom_lower =~ s/[óòö]/o/g; $nom_lower =~ s/[úùü]/u/g;
        my $es_nom_unica = ($nom_lower =~ /^unica$/);

        push @sucursales, {
            id => $id_neg,
            nombre => $nom_neg,
            consultorios => $c_num,
            quirofanos => $q_num,
            es_unica => $es_nom_unica ? 1 : 0
        };
    }

    if (scalar(@sucursales) == 0) {
        my $c_num = $config_por_negocio{$my_org}{CONSULTORIOS} // 1;
        my $q_num = $config_por_negocio{$my_org}{QUIROFANOS}   // 0;
        push @sucursales, {
            id => $my_org,
            nombre => 'Clínica Principal',
            consultorios => int($c_num) || 1,
            quirofanos => int($q_num) || 0,
            es_unica => 1
        };
    }

    my $es_unica = (scalar(@sucursales) == 1 || scalar(grep { !$_->{es_unica} } @sucursales) == 0) ? 1 : 0;
    my $suc_target;
    if ($id_sucursal_solicitada ne '') {
        ($suc_target) = grep { $_->{id} eq $id_sucursal_solicitada } @sucursales;
    }
    $suc_target //= $sucursales[0];

    my $consultorios = $suc_target ? $suc_target->{consultorios} : 1;
    my $quirofanos   = $suc_target ? $suc_target->{quirofanos}   : 0;
    $consultorios = 1 if $consultorios < 1;
    $quirofanos   = 0 if $quirofanos < 0;

    print $q->header(-type => 'application/json', -charset => 'utf-8');
    print encode_json({
        ok => 1,
        consultorios => $consultorios,
        quirofanos => $quirofanos,
        tipo_org => $config_por_negocio{$my_org}{TIPO_ORGANIZACION} // 'Clínica',
        es_unica => $es_unica,
        sucursales => \@sucursales
    });
    exit;
}

# ==========================================================
# CONFIGURACIÓN HORARIA Y COBRO EN RECEPCIÓN
# ==========================================================

sub obtener_config_agenda {
    my ($q) = @_;
    my $id_suc = $q->param('id_sucursal') // $id_empresa_sesion;
    my %c = cargar_agenda_config_sucursal($id_suc);
    print $q->header(-type => 'application/json', -charset => 'utf-8');
    print encode_json({ ok => 1, config => \%c });
    exit;
}

sub guardar_config_agenda {
    my ($q) = @_;
    my $id_suc = $q->param('id_sucursal') // $id_empresa_sesion;
    return responder_json(0, "Identificador de sucursal requerido.") unless $id_suc;

    my $file = "$dirname/../dat/agenda_config_sucursal_$id_suc.dat";
    my $h_ini = $q->param('h_ini') // '07:00';
    my $h_fin = $q->param('h_fin') // '21:00';
    my $sin_comida = $q->param('sin_comida') // '0';
    my $c_ini = $q->param('c_ini') // '';
    my $c_fin = $q->param('c_fin') // '';
    if ($sin_comida eq '1' || $sin_comida eq 'true' || $c_ini eq $c_fin) {
        $c_ini = '';
        $c_fin = '';
    }
    my $d_hab = $q->param('dias') // '1,2,3,4,5,6,7';
    my @norm_days = map { $_ eq '0' ? '7' : $_ } split(/,/, $d_hab);
    $d_hab = join(',', @norm_days);
    my $int = $q->param('int') // '30';
    my $cancel_hours = $q->param('cancel_hours') // '24';
    my $festivos = $q->param('festivos') // '';

    if (open my $fh, '>:encoding(UTF-8)', $file) {
        print $fh "horario_inicio=$h_ini\n";
        print $fh "horario_fin=$h_fin\n";
        print $fh "horario_comida_inicio=$c_ini\n";
        print $fh "horario_comida_fin=$c_fin\n";
        print $fh "intervalo_minutos=$int\n";
        print $fh "dias_habiles=$d_hab\n";
        print $fh "cancel_hours=$cancel_hours\n";
        print $fh "festivos=$festivos\n";
        close $fh;

        print $q->header(-type => 'application/json', -charset => 'utf-8');
        print encode_json({
            ok => 1,
            msg => "Horario operativo de espacios para la sucursal guardado exitosamente."
        });
    } else {
        responder_json(0, "No se pudo escribir el archivo de configuración de sucursal.");
    }
    exit;
}

sub cobrar_renta_recepcion {
    my ($arr, $q) = @_;
    my $id_renta = $q->param('id_renta') // $q->param('id_cita') // '';
    my $monto    = $q->param('monto') // 0;
    my $metodo   = $q->param('metodo_pago') // 'Efectivo';
    $monto = sprintf("%.2f", ($monto =~ /^[0-9.]+$/ ? $monto + 0 : 0));

    unless ($id_renta) { responder_json(0, "Falta el ID de la reserva de espacio."); return; }
    unless ($monto > 0) { responder_json(0, "El importe a cobrar debe ser mayor a \$0.00."); return; }

    my $renta_obj;
    foreach my $r (@$arr) {
        if ($r->{id_renta} eq $id_renta) {
            $renta_obj = $r;
            last;
        }
    }
    unless ($renta_obj) { responder_json(0, "Reserva de espacio no encontrada."); return; }

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $fecha_iso = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $hora_iso  = sprintf("%02d:%02d", $hour, $min);

    # Folio consecutivo privado
    my $folio_num = 1;
    my $cnt_file = "$dirname/../dat/contadores_recibos_privados_${id_empresa_sesion}.dat";
    if (-e $cnt_file && open my $fhc, '<', $cnt_file) {
        my $val = <$fhc>; chomp $val if defined $val;
        $folio_num = int($val) + 1 if defined $val && $val =~ /^\d+$/;
        close $fhc;
    }
    if (open my $fhw, '>', $cnt_file) {
        print $fhw $folio_num;
        close $fhw;
    }

    my $id_recibo = "RC-" . time() . "-" . int(rand(899) + 100);
    my $concepto  = "Renta de Espacio: $renta_obj->{espacio} ($renta_obj->{fecha} $renta_obj->{hora_ini}-$renta_obj->{hora_fin})";
    my $items_json = encode_json([{
        concepto => $concepto,
        cantidad => 1,
        precio   => $monto + 0,
        subtotal => $monto + 0
    }]);

    my $rec_file = "$dirname/../dat/folios_recibos_privados.dat";
    my $linea_rec = join('|',
        $id_recibo,
        $folio_num,
        $id_empresa_sesion,
        $renta_obj->{sucursal} || $id_empresa_sesion,
        $id_renta,
        $renta_obj->{id_arrendatario} || 'ARRENDATARIO',
        $fecha_iso,
        $hora_iso,
        $monto,
        $monto,
        $metodo,
        $session_data->{usuario} // 'RECEPCION',
        $concepto,
        $items_json,
        'Liquidado',
        $renta_obj->{id_arrendatario} || '0',
        $renta_obj->{motivo} || 'Arrendamiento de Espacio Clínico'
    );

    if (open my $fhr, '>>:encoding(UTF-8)', $rec_file) {
        flock($fhr, LOCK_EX);
        print $fhr "$linea_rec\n";
        close $fhr;
    }

    $renta_obj->{monto_renta}  = $monto;
    $renta_obj->{pagado}       = '1';
    $renta_obj->{folio_recibo} = $id_recibo;
    if ($renta_obj->{estado} eq 'Reservada') {
        $renta_obj->{estado} = 'Confirmada';
    }
    guardar_rentas($arr);

    responder_json(1, "Cobro de Renta de Espacio por \$$monto ($metodo) registrado exitosamente con Folio #$folio_num.");
}

sub sincronizar_renta_con_quirofano {
    my ($renta, $es_eliminar) = @_;
    return unless $renta;
    my $espacio = $renta->{espacio} // '';
    return unless $espacio =~ /Quir[oó]fano/i;

    my $file_qx = "$dirname/../dat/quirofano.dat";
    my $header_qx = "ID_CIRUGIA|ID_ORG|ID_PACIENTE|ID_MEDICO|FECHA_PROGRAMADA|HORA_PROGRAMADA|ESTADO|SALA_QUIROFANO|PROCEDIMIENTO|ID_ANESTESIOLOGO|NOTAS";

    my @lineas_qx;
    if (-e $file_qx && open(my $fh_r, '<:encoding(UTF-8)', $file_qx)) {
        while (my $line = <$fh_r>) {
            chomp $line; $line =~ s/\r//g;
            next if $line =~ /^\s*$/;
            push @lineas_qx, $line;
        }
        close $fh_r;
    }

    my $id_r = $renta->{id_renta};
    my @nuevas_lineas;
    my $header_presente = 0;
    foreach my $l (@lineas_qx) {
        if ($l =~ /^ID_CIRUGIA\|/) {
            push @nuevas_lineas, $header_qx;
            $header_presente = 1;
            next;
        }
        my @f = split(/\|/, $l, -1);
        next if ($f[0] // '') eq $id_r;
        push @nuevas_lineas, $l;
    }
    unshift @nuevas_lineas, $header_qx unless $header_presente;

    my $estado_r = $renta->{estado} // 'Reservada';
    if (!$es_eliminar && $estado_r !~ /^(Cancelada|No realizada)$/i) {
        my $estado_qx = 'Programada';
        if ($estado_r =~ /^En Uso$/i) { $estado_qx = 'En Quirófano'; }
        elsif ($estado_r =~ /^Finalizada$/i) { $estado_qx = 'Alta'; }

        my $nueva_linea = join('|',
            $id_r,
            $renta->{id_negocio} || $id_empresa_sesion || '0',
            $renta->{nombre_arrendatario} // 'Arrendatario',
            $renta->{id_arrendatario} // '',
            $renta->{fecha} // '',
            $renta->{hora_ini} // '',
            $estado_qx,
            $espacio,
            "RENTA ESPACIO: " . ($renta->{motivo} // ''),
            '',
            "Reserva desde Agenda de Espacios (" . ($renta->{nombre_arrendatario} // '') . ")"
        );
        push @nuevas_lineas, $nueva_linea;
    }

    if (open(my $fh_w, '>:encoding(UTF-8)', $file_qx)) {
        flock($fh_w, LOCK_EX);
        foreach my $nl (@nuevas_lineas) { print $fh_w "$nl\n"; }
        close $fh_w;
    }
}

sub obtener_datos_medico_org {
    my ($id_m) = @_;
    my $file_usu = "$dirname/../dat/usuarios.dat";
    if (-e $file_usu && open my $fh, '<:encoding(UTF-8)', $file_usu) {
        while (my $line = <$fh>) {
            $line =~ s/\R//g;
            my @u = split(/!/, $line);
            if (($u[0] // '') eq $id_m) {
                close $fh;
                return ($u[1] // '', $u[2] // '');
            }
        }
        close $fh;
    }
    return ('', '');
}

sub responder_json {
    my ($ok, $msg) = @_;
    print "Content-Type: application/json; charset=UTF-8\n\n";
    binmode STDOUT, ":raw";
    print encode_json({ ok => $ok, msg => $msg });
    exit;
}

1;
