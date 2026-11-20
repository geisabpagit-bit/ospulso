#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json decode_json);
use File::Spec;
use FindBin;
use Fcntl qw(:flock);
use Digest::SHA qw(sha256_hex);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'permisos_utils.pl');
use utils::db_manager qw(guardar_registro actualizar_archivo);

my $q = CGI->new;
my $sd = check_session($q);
print $q->header(-type => 'application/json; charset=UTF-8');

unless ($sd && $sd->{session_ok}) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada o no válida.' });
    exit;
}

my $usuario    = $sd->{usuario} || 'sistema';
my $role       = $sd->{role} || '';
my $id_org     = $sd->{id_empresa} // '0';
$id_org        = '0' if $id_org eq '';
my $id_sucursal = ($sd->{session} ? $sd->{session}->param('id_sucursal') : '') || $id_org;
my $id_usuario_sesion = $sd->{id_registro} // $sd->{id_medico} // '';

if ($role =~ /Administrador Global/i) {
    print encode_json({ ok => JSON::false, msg => 'Por políticas NOM-004, el Administrador Global no opera módulos clínicos de organizaciones.' });
    exit;
}

unless (utils::permisos_utils::tiene_permiso_modulo($id_org, $role, 'quirofano', 'R', $id_usuario_sesion)) {
    print encode_json({ ok => JSON::false, msg => 'No cuenta con permisos RBAC para operar el Módulo Quirúrgico.' });
    exit;
}

my $action = $q->param('action') || $q->param('accion') || 'get_catalog_3nf';

my $dat_dir       = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $qx_dir        = File::Spec->catdir($dat_dir, 'quirofano');
mkdir $qx_dir, 0777 unless -d $qx_dir;

my $file_qx       = File::Spec->catfile($dat_dir, 'quirofano.dat');
my $file_rentas   = File::Spec->catfile($dat_dir, 'rentas_espacios.dat');
my $file_citas    = File::Spec->catfile($dat_dir, 'citas.dat');
my $file_pac      = File::Spec->catfile($dat_dir, 'pacientes.dat');
my $file_edo      = File::Spec->catfile($dat_dir, 'estado_cuenta.dat');
my $file_recibos  = File::Spec->catfile($dat_dir, 'folios_recibos_privados.dat');

my $file_cat      = File::Spec->catfile($qx_dir, 'categorias_insumo.dat');
my $file_uni      = File::Spec->catfile($qx_dir, 'unidades_medida.dat');
my $file_ins      = File::Spec->catfile($qx_dir, 'catalogo_insumos.dat');
my $file_cons     = File::Spec->catfile($qx_dir, 'consumo_insumos.dat');
my $file_trm      = File::Spec->catfile($qx_dir, 'tramites_ingreso.dat');
my $file_rec_alta = File::Spec->catfile($qx_dir, 'recetas_alta.dat');

sub ahora_iso {
    my @t = localtime(time);
    my $f = sprintf("%04d-%02d-%02d", $t[5]+1900, $t[4]+1, $t[3]);
    my $h = sprintf("%02d:%02d:%02d", $t[2], $t[1], $t[0]);
    return ($f, $h, "$f $h");
}

sub limpiar_pipe {
    my ($v) = @_;
    return '' unless defined $v;
    $v =~ s/\|/ /g;
    $v =~ s/[\r\n]+/ /g;
    $v =~ s/^\s+|\s+$//g;
    return $v;
}

sub a_minutos {
    my ($hhmm) = @_;
    return 0 unless defined $hhmm && $hhmm =~ /^(\d{1,2}):(\d{2})/;
    return int($1) * 60 + int($2);
}

# =========================================================================
# 1. CATÁLOGO UNIVERSAL DE INSUMOS 3NF
# =========================================================================
if ($action eq 'get_catalog_3nf') {
    my ($categorias, $cat_map) = cargar_categorias_3nf();
    my ($unidades, $uni_map)   = cargar_unidades_3nf();
    my $insumos                = cargar_insumos_3nf($cat_map, $uni_map);

    print encode_json({
        ok         => JSON::true,
        categorias => $categorias,
        unidades   => $unidades,
        insumos    => $insumos
    });
    exit;
}
elsif ($action eq 'save_catalog_insumo') {
    my $nombre    = limpiar_pipe($q->param('nombre'));
    my $sku       = limpiar_pipe($q->param('codigo_sku')) || ('SKU-' . int(rand(8999)+1000));
    my $id_cat    = limpiar_pipe($q->param('id_categoria')) || 'CAT-QX-04';
    my $id_uni    = limpiar_pipe($q->param('id_unidad')) || 'UNI-01';
    my $precio    = sprintf("%.2f", ($q->param('precio_unitario') || 0) + 0);
    my $stock     = int($q->param('stock_actual') // 100);

    if (!$nombre || $precio <= 0) {
        print encode_json({ ok => JSON::false, msg => 'Nombre y precio unitario mayor a 0 son obligatorios.' });
        exit;
    }

    my (undef, undef, $ts) = ahora_iso();
    my $id_ins = 'INS-QX-' . time() . '-' . int(rand(899)+100);
    my $linea = join('|', $id_ins, $id_org, $sku, $nombre, $id_cat, $id_uni, $precio, $stock, 1, $ts, $ts, $usuario);
    utils::db_manager::guardar_registro($file_ins, $linea);

    print encode_json({ ok => JSON::true, id_insumo => $id_ins, msg => 'Insumo registrado en Catálogo 3NF.' });
    exit;
}

# =========================================================================
# 2. VERIFICACIÓN DE DISPONIBILIDAD EN AGENDA DE ESPACIOS EN RENTA
# =========================================================================
elsif ($action eq 'check_space_availability') {
    my $fecha       = limpiar_pipe($q->param('fecha'));
    my $hora_ini    = limpiar_pipe($q->param('hora_ini')) || '08:00';
    my $hora_fin    = limpiar_pipe($q->param('hora_fin')) || '10:00';
    my $sala        = limpiar_pipe($q->param('sala')) || 'Quirófano 1';
    my $exclude_qx  = limpiar_pipe($q->param('id_cirugia'));
    my $exclude_ren = limpiar_pipe($q->param('id_sala_renta'));

    if (!$fecha || !$sala) {
        print encode_json({ ok => JSON::false, msg => 'Seleccione fecha y sala de quirófano.' });
        exit;
    }

    my $conflictos = verificar_colision_espacio($fecha, $hora_ini, $hora_fin, $sala, $exclude_qx, $exclude_ren);
    my $disponible = (scalar(@$conflictos) == 0) ? 1 : 0;

    print encode_json({
        ok         => JSON::true,
        disponible => $disponible ? JSON::true : JSON::false,
        conflictos => $conflictos,
        fecha      => $fecha,
        hora_ini   => $hora_ini,
        hora_fin   => $hora_fin,
        sala       => $sala
    });
    exit;
}

# =========================================================================
# 3. ALTA RÁPIDA DE PACIENTE (PARA INGRESO QUIRÚRGICO / URGENCIAS)
# =========================================================================
elsif ($action eq 'quick_create_patient') {
    my $nombre   = limpiar_pipe($q->param('nombre'));
    my $telefono = limpiar_pipe($q->param('telefono'));
    my $sexo     = limpiar_pipe($q->param('sexo')) || 'Femenino';
    my $fecha_nac= limpiar_pipe($q->param('fecha_nac')) || '1985-01-01';
    my $sangre   = limpiar_pipe($q->param('tipo_sangre')) || 'O+';
    my $curp     = uc(limpiar_pipe($q->param('curp')));

    if (!$nombre) {
        print encode_json({ ok => JSON::false, msg => 'El nombre completo del paciente es obligatorio.' });
        exit;
    }

    my $max_id = 10;
    if (-e $file_pac && open my $fhp, '<:encoding(UTF-8)', $file_pac) {
        <$fhp>;
        while (my $l = <$fhp>) {
            chomp $l;
            my @p = split /\|/, $l, -1;
            if (defined $p[0] && $p[0] =~ /^\d+$/ && $p[0] > $max_id) {
                $max_id = $p[0];
            }
        }
        close $fhp;
    }
    my $new_id = $max_id + 1;
    my $linea_p = join('|',
        $new_id,
        $id_usuario_sesion || '0',
        $nombre,
        '',
        $curp,
        '',
        $fecha_nac,
        $sexo,
        '',
        '',
        'Mexicana',
        $sangre,
        $telefono,
        "$id_org:0"
    );
    utils::db_manager::guardar_registro($file_pac, $linea_p);

    print encode_json({
        ok          => JSON::true,
        id_paciente => $new_id,
        nombre      => $nombre,
        msg         => 'Paciente registrado exitosamente.'
    });
    exit;
}

# =========================================================================
# 4. PASO 1: PROGRAMACIÓN Y SINCRONIZACIÓN CON AGENDA DE ESPACIOS Y PACIENTES
# =========================================================================
elsif ($action eq 'step1_save_programming') {
    my $id_cirugia       = limpiar_pipe($q->param('id_cirugia'));
    my $tipo_cirugia     = uc(limpiar_pipe($q->param('tipo_cirugia')) || 'PROGRAMADA');
    $tipo_cirugia        = 'PROGRAMADA' unless ($tipo_cirugia eq 'URGENCIAS');
    my $id_paciente      = limpiar_pipe($q->param('id_paciente'));
    my $id_medico        = limpiar_pipe($q->param('id_medico'));
    my $id_anestesiologo = limpiar_pipe($q->param('id_anestesiologo'));
    my $procedimiento    = limpiar_pipe($q->param('procedimiento'));
    my $sala             = limpiar_pipe($q->param('sala')) || 'Quirófano 1';
    my $fecha            = limpiar_pipe($q->param('fecha'));
    my $hora_ini         = limpiar_pipe($q->param('hora_ini')) || '08:00';
    my $hora_fin         = limpiar_pipe($q->param('hora_fin')) || '10:00';
    my $notas            = limpiar_pipe($q->param('notas'));

    if (!$id_paciente || !$id_medico || !$procedimiento || !$fecha || !$sala) {
        print encode_json({ ok => JSON::false, msg => 'Complete todos los campos obligatorios: Paciente, Cirujano, Procedimiento, Sala y Fecha.' });
        exit;
    }

    my $dossier_prev = $id_cirugia ? cargar_dossier_quirurgico($id_cirugia) : undef;
    my $exclude_ren  = $dossier_prev ? ($dossier_prev->{id_sala_renta} || '') : '';

    # Validar disponibilidad en Agenda de Espacios
    my $conflictos = verificar_colision_espacio($fecha, $hora_ini, $hora_fin, $sala, $id_cirugia, $exclude_ren);
    if (scalar(@$conflictos) > 0 && $tipo_cirugia eq 'PROGRAMADA') {
        my $c0 = $conflictos->[0];
        print encode_json({
            ok         => JSON::false,
            collision  => JSON::true,
            conflictos => $conflictos,
            msg        => "CONFLICTO EN AGENDA DE ESPACIOS: La sala '$sala' ya está reservada el $fecha de $c0->{hora_ini} a $c0->{hora_fin} ($c0->{motivo}). Por ser Cirugía Programada, debe elegir otro horario o sala disponible."
        });
        exit;
    }

    my $nombres_pac = obtener_mapa_pacientes();
    my $nombres_med = obtener_mapa_medicos();
    my $nombre_pac  = $nombres_pac->{$id_paciente} || "Paciente #$id_paciente";
    my $nombre_med  = $nombres_med->{$id_medico}   || "Médico #$id_medico";
    my $nombre_ane  = $id_anestesiologo ? ($nombres_med->{$id_anestesiologo} || '') : '';

    # Calcular horas de sala
    my $min_ini = a_minutos($hora_ini);
    my $min_fin = a_minutos($hora_fin);
    my $horas_sala = ($min_fin > $min_ini) ? sprintf("%.1f", ($min_fin - $min_ini) / 60.0) : 2;
    $horas_sala =~ s/\.0$//;
    my $costo_hora_sala = 2500.00;
    my $monto_renta_sala = sprintf("%.2f", $horas_sala * $costo_hora_sala);

    # Estado Kanban inicial según regla de bifurcación:
    # Programada -> 'Programada' | Urgencias -> directo a 'Pre-Operatorio'
    my $estado_kanban = ($tipo_cirugia eq 'URGENCIAS') ? 'Pre-Operatorio' : 'Programada';
    if ($dossier_prev && $dossier_prev->{estado} && $dossier_prev->{estado} ne 'Programada') {
        $estado_kanban = $dossier_prev->{estado};
    }

    my $es_nuevo = $id_cirugia ? 0 : 1;
    $id_cirugia ||= 'CIR-' . time() . '-' . int(rand(899)+100);
    my $folio_exp = ($dossier_prev && $dossier_prev->{expediente_fisico_folio})
        ? $dossier_prev->{expediente_fisico_folio}
        : ('EXP-FIS-' . (localtime)[5]+1900 . '-' . int(rand(8999)+1000));

    # 1. Sincronizar Reserva en Agenda de Renta de Espacios (dat/rentas_espacios.dat)
    my $id_renta = ($dossier_prev && $dossier_prev->{id_sala_renta}) ? $dossier_prev->{id_sala_renta} : ('REN-QX-' . time() . '-' . int(rand(899)+100));
    my $motivo_renta = ($tipo_cirugia eq 'URGENCIAS' ? "[URGENCIA] " : "Cirugía Programada: ") . $procedimiento;
    my $notas_renta  = "Folio QX: $id_cirugia | Paciente: $nombre_pac" . ($tipo_cirugia eq 'URGENCIAS' ? " | Bloqueo Prioritario Urgencias" : "");
    my $estado_renta = ($tipo_cirugia eq 'URGENCIAS') ? 'En uso' : 'Reservada';
    my $pagado_renta = ($dossier_prev && $dossier_prev->{tramites_ingreso} && $dossier_prev->{tramites_ingreso}->{deposito_pagado}) ? 1 : 0;
    my $folio_rec_r  = ($dossier_prev && $dossier_prev->{tramites_ingreso}) ? ($dossier_prev->{tramites_ingreso}->{folio_recibo_caja} || '') : '';

    sincronizar_renta_espacio(
        id_renta            => $id_renta,
        id_arrendatario     => $id_medico,
        nombre_arrendatario => $nombre_med,
        fecha               => $fecha,
        hora_ini            => $hora_ini,
        hora_fin            => $hora_fin,
        sucursal            => $id_sucursal,
        espacio             => $sala,
        tipo_espacio        => 'Quirófano',
        motivo              => $motivo_renta,
        notas               => $notas_renta,
        estado              => $estado_renta,
        monto_renta         => $monto_renta_sala,
        pagado              => $pagado_renta,
        folio_recibo        => $folio_rec_r,
        id_negocio          => $id_org,
        elaborado_por       => $usuario
    );

    # 2. Sincronizar Cita en Agenda de Pacientes (dat/citas.dat)
    my $id_cita = ($dossier_prev && $dossier_prev->{id_cita_paciente}) ? $dossier_prev->{id_cita_paciente} : ('CITA-QX-' . time() . '-' . int(rand(899)+100));
    sincronizar_cita_paciente(
        id_cita       => $id_cita,
        id_medico     => $id_medico,
        id_paciente   => $id_paciente,
        fecha         => $fecha,
        hora_ini      => $hora_ini,
        hora_fin      => $hora_fin,
        motivo        => "Cirugía: $procedimiento",
        notas         => "Folio QX: $id_cirugia | Sala: $sala",
        estado        => ($tipo_cirugia eq 'URGENCIAS' ? 'Consulta en proceso' : 'Programada'),
        prioridad     => ($tipo_cirugia eq 'URGENCIAS' ? 'Urgencia' : 'Alta'),
        sucursal      => $id_sucursal,
        consultorio   => $sala,
        id_negocio    => $id_org,
        elaborado_por => $usuario
    );

    # 3. Guardar en dat/quirofano.dat
    guardar_o_actualizar_quirofano_dat(
        id_cirugia              => $id_cirugia,
        id_org                  => $id_org,
        id_paciente             => $id_paciente,
        id_medico               => $id_medico,
        fecha                   => $fecha,
        hora                    => $hora_ini,
        estado                  => $estado_kanban,
        sala                    => $sala,
        procedimiento           => $procedimiento,
        id_anestesiologo        => $id_anestesiologo,
        notas                   => $notas,
        tipo_cirugia            => $tipo_cirugia,
        id_sala_renta           => $id_renta,
        expediente_fisico_folio => $folio_exp
    );

    # 4. Construir o actualizar Dossier Atómico JSON
    my $dossier = $dossier_prev || {};
    $dossier->{id_cirugia}              = $id_cirugia;
    $dossier->{folio}                   = $id_cirugia;
    $dossier->{id_org}                  = $id_org;
    $dossier->{tenant_id}               = $id_org;
    $dossier->{tipo_cirugia}            = $tipo_cirugia;
    $dossier->{id_paciente}             = $id_paciente;
    $dossier->{nombre_paciente}         = $nombre_pac;
    $dossier->{id_medico}               = $id_medico;
    $dossier->{nombre_medico}           = $nombre_med;
    $dossier->{id_anestesiologo}        = $id_anestesiologo;
    $dossier->{nombre_anestesio}        = $nombre_ane;
    $dossier->{fecha}                   = $fecha;
    $dossier->{hora}                    = $hora_ini;
    $dossier->{hora_fin}                = $hora_fin;
    $dossier->{estado}                  = $estado_kanban;
    $dossier->{estatus_kanban}          = uc($estado_kanban);
    $dossier->{sala}                    = $sala;
    $dossier->{id_sala_renta}           = $id_renta;
    $dossier->{id_cita_paciente}        = $id_cita;
    $dossier->{procedimiento}           = $procedimiento;
    $dossier->{notas}                   = $notas;
    $dossier->{expediente_fisico_folio} = $folio_exp;
    $dossier->{habitacion_asignada}   ||= ($tipo_cirugia eq 'URGENCIAS' ? 'URG-BOX-01' : 'HAB-101');
    $dossier->{paso_actual_wizard}      = ($tipo_cirugia eq 'URGENCIAS') ? 3 : 2;

    $dossier->{tramites_ingreso} ||= {
        id_tramite                      => 'TRM-' . time(),
        contrato_firmado                => 0,
        consentimiento_informado_firmado=> 0,
        id_consentimiento               => '',
        nombre_firmante                 => $nombre_pac,
        parentesco_firmante             => 'Titular / Paciente',
        fecha_firma_consentimiento      => '',
        deposito_monto                  => 5000.00,
        deposito_pagado                 => 0,
        metodo_pago_deposito            => 'Efectivo',
        folio_recibo_caja               => ''
    };
    $dossier->{signos_vitales_preop} ||= {
        ta => '120/80', fc => '75', fr => '16', temp => '36.6', spo2 => '98', peso => '70', talla => '168'
    };
    $dossier->{checklist_preop} ||= {
        identidad_verificada => 0, consentimiento_firmado => 0, id_consentimiento => '',
        ayuno_confirmado => 0, horas_ayuno => 8, labs_validados => 0, sitio_marcado => 0,
        via_permeable => 0, profilaxis_antibiotica => 0, alergias_verificadas => 0,
        observaciones_enfermeria => ''
    };
    $dossier->{transoperatorio} ||= {
        hora_ingreso_sala => $hora_ini, hora_inicio_anestesia => '', hora_incision => '',
        hora_cierre => '', hora_salida_sala => '', conteo_gasas_completo => 0,
        conteo_compresas_completo => 0, conteo_instrumental_completo => 0, incidentes_accidentes => ''
    };
    $dossier->{nota_quirurgica} ||= {
        cirujano => $nombre_med, primer_ayudante => '', anestesiologo => $nombre_ane,
        instrumentista => '', circulante => '', tipo_anestesia => 'General Balanceada',
        diagnostico_preop => $procedimiento, diagnostico_postop => $procedimiento,
        operacion_planeada => $procedimiento, operacion_realizada => $procedimiento,
        descripcion_tecnica => '', hallazgos => '', sangrado_aprox_ml => '0',
        piezas_patologia => '', estado_salida => 'Estable a UCPA', fecha_cierre => ''
    };
    $dossier->{recuperacion_ucpa} ||= {
        cama_ucpa => 'UCPA-01', aldrete_actividad => 2, aldrete_respiracion => 2,
        aldrete_circulacion => 2, aldrete_conciencia => 2, aldrete_saturacion => 2,
        aldrete_total => 10, valoracion_postop => '', habitacion_traslado => $dossier->{habitacion_asignada},
        aprobado_alta => 0, medico_alta => $nombre_med
    };
    $dossier->{consumos_3nf} ||= [];
    $dossier->{liquidacion_insumos} ||= {
        horas_sala => $horas_sala + 0,
        costo_hora_sala => $costo_hora_sala,
        honorarios_cirujano => 0,
        honorarios_anestesio => 0,
        insumos => [],
        subtotal_insumos_3nf => 0,
        subtotal_renta_sala => $monto_renta_sala + 0,
        deposito_aplicado => 0,
        saldo_a_liquidar => $monto_renta_sala + 0,
        total_calculado => $monto_renta_sala + 0,
        id_movimiento_caja => '',
        registrado_en_caja => 0,
        corte_liquidado => 0
    };
    $dossier->{liquidacion_insumos}->{horas_sala} = $horas_sala + 0;
    $dossier->{liquidacion_insumos}->{subtotal_renta_sala} = $monto_renta_sala + 0;

    $dossier->{receta_alta} ||= {
        id_receta => '', diagnostico_egreso_cie10 => '', indicaciones_generales => '',
        medicamentos => [], fecha_emision => '', hash_firma_electronica => '',
        pase_salida_emitido => 0, folio_pase_salida => ''
    };

    recalcular_totales_y_semaforos($dossier);
    guardar_dossier_quirurgico($id_cirugia, $dossier);

    print encode_json({
        ok         => JSON::true,
        id_cirugia => $id_cirugia,
        dossier    => $dossier,
        next_step  => ($tipo_cirugia eq 'URGENCIAS') ? 3 : 2,
        msg        => ($tipo_cirugia eq 'URGENCIAS')
            ? 'URGENCIA REGISTRADA: Bloqueo prioritario aplicado en Agenda de Espacios. Tarjeta ingresada directamente a PRE-OPERATORIO con flujo paralelo activado.'
            : 'Cirugía Programada registrada y sincronizada con Agenda de Espacios y Agenda de Pacientes.'
    });
    exit;
}

# =========================================================================
# 5. PASO 2: RECEPCIÓN, CONSENTIMIENTO INFORMADO Y DEPÓSITO EN CAJA ($5,000)
# =========================================================================
elsif ($action eq 'step2_save_reception_cash') {
    my $id_cirugia = limpiar_pipe($q->param('id_cirugia'));
    if (!$id_cirugia) {
        print encode_json({ ok => JSON::false, msg => 'ID de cirugía requerido.' });
        exit;
    }
    my $dossier = cargar_dossier_quirurgico($id_cirugia);
    unless ($dossier) {
        print encode_json({ ok => JSON::false, msg => 'Dossier quirúrgico no encontrado.' });
        exit;
    }

    my $contrato_ok   = ($q->param('contrato_firmado') eq '1' || $q->param('contrato_firmado') eq 'true') ? 1 : 0;
    my $consent_ok    = ($q->param('consentimiento_informado_firmado') eq '1' || $q->param('consentimiento_informado_firmado') eq 'true') ? 1 : 0;
    my $firmante      = limpiar_pipe($q->param('nombre_firmante')) || $dossier->{nombre_paciente};
    my $parentesco    = limpiar_pipe($q->param('parentesco_firmante')) || 'Titular / Paciente';
    my $fecha_firma   = limpiar_pipe($q->param('fecha_firma_consentimiento'));
    my $deposito_mto  = sprintf("%.2f", ($q->param('deposito_monto') // 5000) + 0);
    my $deposito_ok   = ($q->param('deposito_pagado') eq '1' || $q->param('deposito_pagado') eq 'true') ? 1 : 0;
    my $metodo_pago   = limpiar_pipe($q->param('metodo_pago_deposito')) || 'Efectivo';
    my $modo_paralelo = ($q->param('saltar_urgencia_paralelo') eq '1') ? 1 : 0;

    my ($f_hoy, $h_hoy, $ts_hoy) = ahora_iso();
    $fecha_firma ||= "$f_hoy $h_hoy";

    my $trm = $dossier->{tramites_ingreso} || {};
    $trm->{id_tramite}                       ||= 'TRM-' . time();
    $trm->{contrato_firmado}                   = $contrato_ok;
    $trm->{consentimiento_informado_firmado}   = $consent_ok;
    $trm->{nombre_firmante}                    = $firmante;
    $trm->{parentesco_firmante}                = $parentesco;
    $trm->{fecha_firma_consentimiento}         = $consent_ok ? $fecha_firma : '';
    $trm->{deposito_monto}                     = $deposito_mto + 0;
    $trm->{metodo_pago_deposito}               = $metodo_pago;

    # Si se firma consentimiento, sincronizar con el repositorio atómico de consentimientos del paciente
    if ($consent_ok && !$trm->{id_consentimiento}) {
        my $id_cns = sincronizar_consentimiento_paciente($dossier, $firmante, $parentesco, $fecha_firma);
        $trm->{id_consentimiento} = $id_cns;
        $dossier->{checklist_preop}->{consentimiento_firmado} = 1;
        $dossier->{checklist_preop}->{id_consentimiento}      = $id_cns;
    } elsif (!$consent_ok) {
        $dossier->{checklist_preop}->{consentimiento_firmado} = 0;
    }

    # Si se confirma el depósito en Caja y aún no tenía recibo emitido, emitir recibo privado oficial en folios_recibos_privados.dat
    if ($deposito_ok && !$trm->{folio_recibo_caja}) {
        my $folio_rc = emitir_recibo_deposito_caja($dossier, $deposito_mto, $metodo_pago);
        $trm->{folio_recibo_caja} = $folio_rc;
        $trm->{deposito_pagado}   = 1;

        # Actualizar reserva en Agenda de Espacios como pagada/con recibo
        if ($dossier->{id_sala_renta}) {
            actualizar_pago_renta_espacio($dossier->{id_sala_renta}, 1, $folio_rc);
        }
    } else {
        $trm->{deposito_pagado} = $deposito_ok;
    }

    $dossier->{tramites_ingreso} = $trm;
    guardar_tramite_ingreso_dat($dossier);

    # Validar transición para Cirugía Programada vs Urgencias
    if ($dossier->{tipo_cirugia} eq 'PROGRAMADA' && !$modo_paralelo) {
        if ($contrato_ok && $consent_ok && $trm->{deposito_pagado}) {
            if ($dossier->{estado} eq 'Programada') {
                $dossier->{estado} = 'Pre-Operatorio';
                $dossier->{estatus_kanban} = 'PRE_OPERATORIO';
                actualizar_estado_quirofano_dat($id_cirugia, 'Pre-Operatorio');
            }
            $dossier->{paso_actual_wizard} = 3;
        } else {
            recalcular_totales_y_semaforos($dossier);
            guardar_dossier_quirurgico($id_cirugia, $dossier);
            print encode_json({
                ok      => JSON::false,
                blocked => JSON::true,
                dossier => $dossier,
                msg     => 'BLOQUEO DE CIRUGÍA PROGRAMADA: Para avanzar a Pre-Operatorio (Paso 3), es obligatorio marcar Contrato Firmado, Consentimiento Informado y Depósito en Caja ($5,000.00).'
            });
            exit;
        }
    } else {
        # En Urgencias se permite avanzar en paralelo
        if ($dossier->{estado} eq 'Programada') {
            $dossier->{estado} = 'Pre-Operatorio';
            $dossier->{estatus_kanban} = 'PRE_OPERATORIO';
            actualizar_estado_quirofano_dat($id_cirugia, 'Pre-Operatorio');
        }
        $dossier->{paso_actual_wizard} = 3 if ($dossier->{paso_actual_wizard} || 1) < 3;
    }

    recalcular_totales_y_semaforos($dossier);
    guardar_dossier_quirurgico($id_cirugia, $dossier);

    print encode_json({
        ok        => JSON::true,
        dossier   => $dossier,
        next_step => 3,
        msg       => ($trm->{deposito_pagado} && $contrato_ok && $consent_ok)
            ? "Trámites de Recepción y Depósito en Caja ($trm->{folio_recibo_caja}) validados. Paciente en Pre-Operatorio."
            : "Flujo en paralelo de Urgencia actualizado. Los semáforos pendientes permanecen en alerta activa."
    });
    exit;
}

# =========================================================================
# 6. WIDGET 3NF: AGREGAR Y ELIMINAR CONSUMO DE INSUMOS POR ETAPA CLÍNICA
# =========================================================================
elsif ($action eq 'add_3nf_consumption') {
    my $id_cirugia = limpiar_pipe($q->param('id_cirugia'));
    my $id_insumo  = limpiar_pipe($q->param('id_insumo'));
    my $etapa      = uc(limpiar_pipe($q->param('etapa_clinica')) || 'PRE_OP');
    my $cantidad   = ($q->param('cantidad') || 1) + 0;

    if (!$id_cirugia || !$id_insumo || $cantidad <= 0) {
        print encode_json({ ok => JSON::false, msg => 'Seleccione un insumo válido y una cantidad mayor a cero.' });
        exit;
    }

    my $dossier = cargar_dossier_quirurgico($id_cirugia);
    unless ($dossier) {
        print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada.' });
        exit;
    }

    my (undef, $cat_map) = cargar_categorias_3nf();
    my (undef, $uni_map) = cargar_unidades_3nf();
    my $insumos          = cargar_insumos_3nf($cat_map, $uni_map);

    my $insumo_obj;
    foreach my $i (@$insumos) {
        if ($i->{id_insumo} eq $id_insumo) {
            $insumo_obj = $i;
            last;
        }
    }
    unless ($insumo_obj) {
        print encode_json({ ok => JSON::false, msg => 'Insumo no encontrado en el Catálogo 3NF.' });
        exit;
    }
    if ($insumo_obj->{stock_actual} < $cantidad) {
        print encode_json({ ok => JSON::false, msg => "Stock insuficiente para '$insumo_obj->{nombre}' (Disponible: $insumo_obj->{stock_actual})." });
        exit;
    }

    my $precio_snap = sprintf("%.2f", $insumo_obj->{precio_unitario} + 0);
    my $subtotal    = sprintf("%.2f", $cantidad * $precio_snap);
    my (undef, undef, $ts) = ahora_iso();
    my $id_consumo  = 'CNS-QX-' . time() . '-' . int(rand(899)+100);

    # 1. Guardar en dat/quirofano/consumo_insumos.dat
    my $linea_c = join('|',
        $id_consumo, $id_org, $id_cirugia, $id_insumo, $etapa,
        $cantidad, $precio_snap, $subtotal, $usuario, $ts
    );
    utils::db_manager::guardar_registro($file_cons, $linea_c);

    # 2. Descontar stock en dat/quirofano/catalogo_insumos.dat
    ajustar_stock_insumo_3nf($id_insumo, -$cantidad);

    # 3. Agregar al dossier JSON y recalcular estado de cuenta
    $dossier->{consumos_3nf} ||= [];
    push @{$dossier->{consumos_3nf}}, {
        id_consumo               => $id_consumo,
        id_insumo                => $id_insumo,
        codigo_sku               => $insumo_obj->{codigo_sku},
        nombre                   => $insumo_obj->{nombre},
        id_categoria             => $insumo_obj->{id_categoria},
        categoria                => $insumo_obj->{nombre_categoria},
        unidad                   => $insumo_obj->{clave_unidad},
        etapa_clinica            => $etapa,
        cantidad                 => $cantidad + 0,
        precio_unitario_snapshot => $precio_snap + 0,
        subtotal                 => $subtotal + 0,
        registrado_por           => $usuario,
        fecha_hora               => $ts
    };

    recalcular_totales_y_semaforos($dossier);
    guardar_dossier_quirurgico($id_cirugia, $dossier);

    print encode_json({
        ok           => JSON::true,
        id_consumo   => $id_consumo,
        nuevo_stock  => $insumo_obj->{stock_actual} - $cantidad,
        dossier      => $dossier,
        msg          => "Insumo '$insumo_obj->{nombre}' cargado a la etapa $etapa."
    });
    exit;
}
elsif ($action eq 'remove_3nf_consumption') {
    my $id_cirugia = limpiar_pipe($q->param('id_cirugia'));
    my $id_consumo = limpiar_pipe($q->param('id_consumo'));

    my $dossier = cargar_dossier_quirurgico($id_cirugia);
    unless ($dossier) {
        print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada.' });
        exit;
    }

    my @nuevos;
    my $eliminado;
    foreach my $c (@{$dossier->{consumos_3nf} || []}) {
        if ($c->{id_consumo} eq $id_consumo) {
            $eliminado = $c;
        } else {
            push @nuevos, $c;
        }
    }

    if ($eliminado) {
        $dossier->{consumos_3nf} = \@nuevos;
        ajustar_stock_insumo_3nf($eliminado->{id_insumo}, +($eliminado->{cantidad} || 0));
        eliminar_consumo_dat($id_consumo);
        recalcular_totales_y_semaforos($dossier);
        guardar_dossier_quirurgico($id_cirugia, $dossier);
    }

    print encode_json({
        ok      => JSON::true,
        dossier => $dossier,
        msg     => 'Insumo removido y stock restaurado.'
    });
    exit;
}

# =========================================================================
# 7. PASO 3: PRE-OPERATORIO (ENFERMERÍA)
# =========================================================================
elsif ($action eq 'step3_save_preop') {
    my $id_cirugia = limpiar_pipe($q->param('id_cirugia'));
    my $dossier    = cargar_dossier_quirurgico($id_cirugia);
    unless ($dossier) {
        print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada.' });
        exit;
    }

    $dossier->{expediente_fisico_folio} = limpiar_pipe($q->param('expediente_fisico_folio')) || $dossier->{expediente_fisico_folio};
    $dossier->{habitacion_asignada}     = limpiar_pipe($q->param('habitacion_asignada'))     || 'HAB-101';

    $dossier->{signos_vitales_preop} = {
        ta    => limpiar_pipe($q->param('ta'))    || '120/80',
        fc    => limpiar_pipe($q->param('fc'))    || '74',
        fr    => limpiar_pipe($q->param('fr'))    || '16',
        temp  => limpiar_pipe($q->param('temp'))  || '36.6',
        spo2  => limpiar_pipe($q->param('spo2'))  || '98',
        peso  => limpiar_pipe($q->param('peso'))  || '70',
        talla => limpiar_pipe($q->param('talla')) || '168'
    };

    $dossier->{checklist_preop} = {
        identidad_verificada     => ($q->param('identidad_verificada') eq '1' || $q->param('identidad_verificada') eq 'true') ? 1 : 0,
        consentimiento_firmado   => $dossier->{tramites_ingreso}->{consentimiento_informado_firmado} ? 1 : (($q->param('consentimiento_firmado') eq '1') ? 1 : 0),
        id_consentimiento        => $dossier->{tramites_ingreso}->{id_consentimiento} || '',
        ayuno_confirmado         => ($q->param('ayuno_confirmado') eq '1' || $q->param('ayuno_confirmado') eq 'true') ? 1 : 0,
        horas_ayuno              => int($q->param('horas_ayuno') // 8),
        labs_validados           => ($q->param('labs_validados') eq '1' || $q->param('labs_validados') eq 'true') ? 1 : 0,
        sitio_marcado            => ($q->param('sitio_marcado') eq '1' || $q->param('sitio_marcado') eq 'true') ? 1 : 0,
        via_permeable            => ($q->param('via_permeable') eq '1' || $q->param('via_permeable') eq 'true') ? 1 : 0,
        profilaxis_antibiotica   => ($q->param('profilaxis_antibiotica') eq '1' || $q->param('profilaxis_antibiotica') eq 'true') ? 1 : 0,
        alergias_verificadas     => ($q->param('alergias_verificadas') eq '1' || $q->param('alergias_verificadas') eq 'true') ? 1 : 0,
        observaciones_enfermeria => limpiar_pipe($q->param('observaciones_enfermeria'))
    };

    my $avanzar_qx = ($q->param('avanzar_quirofano') eq '1') ? 1 : 0;
    if ($avanzar_qx) {
        $dossier->{estado}             = 'En Quirófano';
        $dossier->{estatus_kanban}     = 'EN_QUIROFANO';
        $dossier->{paso_actual_wizard} = 4;
        actualizar_estado_quirofano_dat($id_cirugia, 'En Quirófano');
    } else {
        $dossier->{estado}             = 'Pre-Operatorio';
        $dossier->{estatus_kanban}     = 'PRE_OPERATORIO';
        $dossier->{paso_actual_wizard} = 3;
        actualizar_estado_quirofano_dat($id_cirugia, 'Pre-Operatorio');
    }

    recalcular_totales_y_semaforos($dossier);
    guardar_dossier_quirurgico($id_cirugia, $dossier);

    print encode_json({
        ok        => JSON::true,
        dossier   => $dossier,
        next_step => $avanzar_qx ? 4 : 3,
        msg       => $avanzar_qx
            ? 'Pre-Operatorio validado. Paciente trasladado a EN QUIRÓFANO (Paso 4).'
            : 'Datos de Enfermería Pre-Operatoria guardados.'
    });
    exit;
}

# =========================================================================
# 8. PASO 4: TRANSOPERATORIO (QUIRÓFANO)
# =========================================================================
elsif ($action eq 'step4_save_transop') {
    my $id_cirugia = limpiar_pipe($q->param('id_cirugia'));
    my $dossier    = cargar_dossier_quirurgico($id_cirugia);
    unless ($dossier) {
        print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada.' });
        exit;
    }

    $dossier->{transoperatorio} = {
        hora_ingreso_sala            => limpiar_pipe($q->param('hora_ingreso_sala'))     || $dossier->{hora},
        hora_inicio_anestesia        => limpiar_pipe($q->param('hora_inicio_anestesia')) || '',
        hora_incision                => limpiar_pipe($q->param('hora_incision'))         || '',
        hora_cierre                  => limpiar_pipe($q->param('hora_cierre'))           || '',
        hora_salida_sala             => limpiar_pipe($q->param('hora_salida_sala'))      || '',
        conteo_gasas_completo        => ($q->param('conteo_gasas_completo') eq '1' || $q->param('conteo_gasas_completo') eq 'true') ? 1 : 0,
        conteo_compresas_completo    => ($q->param('conteo_compresas_completo') eq '1' || $q->param('conteo_compresas_completo') eq 'true') ? 1 : 0,
        conteo_instrumental_completo => ($q->param('conteo_instrumental_completo') eq '1' || $q->param('conteo_instrumental_completo') eq 'true') ? 1 : 0,
        incidentes_accidentes        => limpiar_pipe($q->param('incidentes_accidentes')) || 'Sin incidentes transoperatorios'
    };

    my (undef, undef, $ts) = ahora_iso();
    $dossier->{nota_quirurgica} ||= {};
    $dossier->{nota_quirurgica}->{cirujano}            = limpiar_pipe($q->param('cirujano'))            || $dossier->{nombre_medico};
    $dossier->{nota_quirurgica}->{primer_ayudante}     = limpiar_pipe($q->param('primer_ayudante'))     || '';
    $dossier->{nota_quirurgica}->{anestesiologo}       = limpiar_pipe($q->param('anestesiologo'))       || $dossier->{nombre_anestesio};
    $dossier->{nota_quirurgica}->{instrumentista}      = limpiar_pipe($q->param('instrumentista'))      || '';
    $dossier->{nota_quirurgica}->{circulante}          = limpiar_pipe($q->param('circulante'))          || '';
    $dossier->{nota_quirurgica}->{tipo_anestesia}      = limpiar_pipe($q->param('tipo_anestesia'))      || 'General Balanceada';
    $dossier->{nota_quirurgica}->{diagnostico_preop}   = limpiar_pipe($q->param('diagnostico_preop'))   || $dossier->{procedimiento};
    $dossier->{nota_quirurgica}->{diagnostico_postop}  = limpiar_pipe($q->param('diagnostico_postop'))  || $dossier->{procedimiento};
    $dossier->{nota_quirurgica}->{operacion_planeada}  = $dossier->{procedimiento};
    $dossier->{nota_quirurgica}->{operacion_realizada} = limpiar_pipe($q->param('operacion_realizada')) || $dossier->{procedimiento};
    $dossier->{nota_quirurgica}->{descripcion_tecnica} = limpiar_pipe($q->param('descripcion_tecnica')) || '';
    $dossier->{nota_quirurgica}->{hallazgos}           = limpiar_pipe($q->param('hallazgos'))           || '';
    $dossier->{nota_quirurgica}->{sangrado_aprox_ml}   = limpiar_pipe($q->param('sangrado_aprox_ml'))   || '50';
    $dossier->{nota_quirurgica}->{piezas_patologia}    = limpiar_pipe($q->param('piezas_patologia'))    || 'No';
    $dossier->{nota_quirurgica}->{fecha_cierre}        = $ts;

    my $avanzar_ucpa = ($q->param('avanzar_recuperacion') eq '1') ? 1 : 0;
    if ($avanzar_ucpa) {
        $dossier->{estado}             = 'Recuperación';
        $dossier->{estatus_kanban}     = 'RECUPERACION';
        $dossier->{paso_actual_wizard} = 5;
        actualizar_estado_quirofano_dat($id_cirugia, 'Recuperación');
    } else {
        $dossier->{estado}             = 'En Quirófano';
        $dossier->{estatus_kanban}     = 'EN_QUIROFANO';
        $dossier->{paso_actual_wizard} = 4;
        actualizar_estado_quirofano_dat($id_cirugia, 'En Quirófano');
    }

    recalcular_totales_y_semaforos($dossier);
    guardar_dossier_quirurgico($id_cirugia, $dossier);

    print encode_json({
        ok        => JSON::true,
        dossier   => $dossier,
        next_step => $avanzar_ucpa ? 5 : 4,
        msg       => $avanzar_ucpa
            ? 'Registro Transoperatorio completado. Paciente trasladado a RECUPERACIÓN (Paso 5).'
            : 'Bitácora Transoperatoria guardada.'
    });
    exit;
}

# =========================================================================
# 9. PASO 5: POSTOPERATORIO (RECUPERACIÓN UCPA)
# =========================================================================
elsif ($action eq 'step5_save_recovery') {
    my $id_cirugia = limpiar_pipe($q->param('id_cirugia'));
    my $dossier    = cargar_dossier_quirurgico($id_cirugia);
    unless ($dossier) {
        print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada.' });
        exit;
    }

    my $act = int($q->param('aldrete_actividad')   // 2);
    my $res = int($q->param('aldrete_respiracion') // 2);
    my $cir = int($q->param('aldrete_circulacion') // 2);
    my $con = int($q->param('aldrete_conciencia')  // 2);
    my $sat = int($q->param('aldrete_saturacion')  // 2);
    my $tot = $act + $res + $cir + $con + $sat;

    $dossier->{recuperacion_ucpa} = {
        cama_ucpa           => limpiar_pipe($q->param('cama_ucpa'))           || 'UCPA-01',
        habitacion_traslado => limpiar_pipe($q->param('habitacion_traslado')) || $dossier->{habitacion_asignada} || 'HAB-101',
        valoracion_postop   => limpiar_pipe($q->param('valoracion_postop'))   || 'Paciente consciente, orientado, hemodinámicamente estable y con dolor controlado.',
        aldrete_actividad   => $act,
        aldrete_respiracion => $res,
        aldrete_circulacion => $cir,
        aldrete_conciencia  => $con,
        aldrete_saturacion  => $sat,
        aldrete_total       => $tot,
        aprobado_alta       => ($tot >= 9) ? 1 : 0,
        medico_alta         => limpiar_pipe($q->param('medico_alta')) || $dossier->{nombre_medico}
    };

    my $avanzar_alta = ($q->param('avanzar_alta') eq '1') ? 1 : 0;
    if ($avanzar_alta) {
        $dossier->{paso_actual_wizard} = 6;
    }

    recalcular_totales_y_semaforos($dossier);
    guardar_dossier_quirurgico($id_cirugia, $dossier);

    print encode_json({
        ok        => JSON::true,
        dossier   => $dossier,
        next_step => $avanzar_alta ? 6 : 5,
        msg       => "Valoración Postoperatoria guardada (Escala Aldrete: $tot/10 pts)."
    });
    exit;
}

# =========================================================================
# 10. PASO 6: ALTA, RECETA MÉDICA Y CORTE DE CAJA AUTOMÁTICO
# =========================================================================
elsif ($action eq 'step6_save_discharge_and_cut') {
    my $id_cirugia = limpiar_pipe($q->param('id_cirugia'));
    my $dossier    = cargar_dossier_quirurgico($id_cirugia);
    unless ($dossier) {
        print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada.' });
        exit;
    }

    # En urgencias o programadas, para emitir Pase de Salida final verificamos si los trámites paralelos de Recepción/Caja siguen pendientes
    my $emitir_pase = ($q->param('emitir_pase_salida') eq '1' || $q->param('emitir_pase_salida') eq 'true') ? 1 : 0;
    my $liquidar_saldo = ($q->param('liquidar_saldo_caja') eq '1' || $q->param('liquidar_saldo_caja') eq 'true') ? 1 : 0;
    my $metodo_finiquito = limpiar_pipe($q->param('metodo_pago_finiquito')) || 'Efectivo';

    my $cie10        = limpiar_pipe($q->param('diagnostico_egreso_cie10')) || $dossier->{nota_quirurgica}->{diagnostico_postop} || $dossier->{procedimiento};
    my $indicaciones = limpiar_pipe($q->param('indicaciones_generales'))   || 'Reposo relativo, dieta blanda, curación de herida cada 24h.';
    my $meds_raw     = $q->param('medicamentos_json') || '[]';
    my $medicamentos = eval { decode_json($meds_raw) } || [];

    my $horas_sala   = ($q->param('horas_sala') // $dossier->{liquidacion_insumos}->{horas_sala} // 2) + 0;
    my $costo_hora   = ($q->param('costo_hora_sala') // $dossier->{liquidacion_insumos}->{costo_hora_sala} // 2500) + 0;
    my $hon_cir      = ($q->param('honorarios_cirujano') // $dossier->{liquidacion_insumos}->{honorarios_cirujano} // 0) + 0;
    my $hon_ane      = ($q->param('honorarios_anestesio') // $dossier->{liquidacion_insumos}->{honorarios_anestesio} // 0) + 0;

    $dossier->{liquidacion_insumos}->{horas_sala}          = $horas_sala;
    $dossier->{liquidacion_insumos}->{costo_hora_sala}     = $costo_hora;
    $dossier->{liquidacion_insumos}->{honorarios_cirujano} = $hon_cir;
    $dossier->{liquidacion_insumos}->{honorarios_anestesio}= $hon_ane;

    my ($f_hoy, $h_hoy, $ts_hoy) = ahora_iso();
    my $id_receta = ($dossier->{receta_alta} && $dossier->{receta_alta}->{id_receta})
        ? $dossier->{receta_alta}->{id_receta}
        : ('REC-QX-' . time() . '-' . int(rand(899)+100));

    my $hash_efirma = uc(substr(sha256_hex("$id_cirugia|$id_receta|$cie10|$ts_hoy|NOM-151"), 0, 32));

    $dossier->{receta_alta} ||= {};
    $dossier->{receta_alta}->{id_receta}                = $id_receta;
    $dossier->{receta_alta}->{diagnostico_egreso_cie10} = $cie10;
    $dossier->{receta_alta}->{indicaciones_generales}   = $indicaciones;
    $dossier->{receta_alta}->{medicamentos}             = $medicamentos;
    $dossier->{receta_alta}->{fecha_emision}            = $ts_hoy;
    $dossier->{receta_alta}->{hash_firma_electronica}   = "NOM151-SHA256-$hash_efirma";

    guardar_receta_alta_dat($dossier);
    recalcular_totales_y_semaforos($dossier);

    # Inyectar a Estado de Cuenta si no se ha registrado
    my $liq = $dossier->{liquidacion_insumos};
    if (!$liq->{registrado_en_caja}) {
        my $id_tx  = "TX-QX-" . time() . "-" . int(rand(899)+100);
        my $id_mov = "MOV-QX-" . time() . "-" . int(rand(899)+100);
        my $total_bruto = sprintf("%.2f", $liq->{total_calculado});
        my $dep_aplic   = sprintf("%.2f", $liq->{deposito_aplicado});
        my $saldo_pend  = sprintf("%.2f", $liq->{saldo_a_liquidar});

        my $linea_edo = join('|',
            $id_tx,
            $id_mov,
            $dossier->{id_paciente},
            'Cargo',
            "Corte Quirúrgico Integral: $dossier->{procedimiento}",
            $total_bruto,
            $dep_aplic,
            $saldo_pend,
            $f_hoy,
            $dossier->{id_medico},
            "Cirugía #$id_cirugia | Sala: $dossier->{sala} | Insumos 3NF + Sala - Depósito",
            $dossier->{nombre_paciente}
        ) . "\n";

        if (open my $fh_e, '>>:encoding(UTF-8)', $file_edo) {
            flock($fh_e, LOCK_EX);
            print $fh_e $linea_edo;
            flock($fh_e, LOCK_UN);
            close $fh_e;
            $liq->{id_movimiento_caja} = $id_mov;
            $liq->{registrado_en_caja} = 1;
        }
    }

    # Si se solicita liquidar el saldo pendiente y emitir Pase de Salida
    if ($emitir_pase) {
        if ($liquidar_saldo && $liq->{saldo_a_liquidar} > 0 && !$liq->{corte_liquidado}) {
            my $folio_fin = emitir_recibo_finiquito_caja($dossier, $liq->{saldo_a_liquidar}, $metodo_finiquito);
            $liq->{folio_recibo_finiquito} = $folio_fin;
            $liq->{corte_liquidado}        = 1;
        } elsif ($liq->{saldo_a_liquidar} <= 0) {
            $liq->{corte_liquidado} = 1;
        }

        $dossier->{receta_alta}->{pase_salida_emitido} = 1;
        $dossier->{receta_alta}->{folio_pase_salida} ||= 'PASE-QX-' . (localtime)[5]+1900 . '-' . int(rand(8999)+1000);
        $dossier->{estado}                             = 'Alta';
        $dossier->{estatus_kanban}                     = 'ALTA_TRASLADO';
        $dossier->{paso_actual_wizard}                 = 6;
        actualizar_estado_quirofano_dat($id_cirugia, 'Alta');
    }

    recalcular_totales_y_semaforos($dossier);
    guardar_dossier_quirurgico($id_cirugia, $dossier);

    print encode_json({
        ok      => JSON::true,
        dossier => $dossier,
        msg     => $emitir_pase
            ? "Alta Quirúrgica, Receta Médica y Pase de Salida ($dossier->{receta_alta}->{folio_pase_salida}) emitidos. Tarjeta movida a ALTA / TRASLADO."
            : "Receta Médica y Pre-Liquidación de Corte de Caja actualizadas."
    });
    exit;
}
else {
    print encode_json({ ok => JSON::false, msg => "Acción no reconocida: $action" });
    exit;
}

# =========================================================================
# SUBRUTINAS AUXILIARES 3NF Y SINCRONIZACIÓN
# =========================================================================

sub cargar_categorias_3nf {
    my @list;
    my %map;
    if (-e $file_cat && open my $fh, '<:encoding(UTF-8)', $file_cat) {
        <$fh>;
        while (my $l = <$fh>) {
            chomp $l;
            next if $l =~ /^\s*$/;
            my @c = split /\|/, $l, -1;
            next unless @c >= 4;
            next unless ($c[1] eq 'ALL' || $c[1] eq $id_org);
            next unless $c[3] eq '1';
            $map{$c[0]} = $c[2];
            push @list, {
                id_categoria => $c[0],
                tenant_id    => $c[1],
                nombre       => $c[2],
                activo       => 1
            };
        }
        close $fh;
    }
    return (\@list, \%map);
}

sub cargar_unidades_3nf {
    my @list;
    my %map;
    if (-e $file_uni && open my $fh, '<:encoding(UTF-8)', $file_uni) {
        <$fh>;
        while (my $l = <$fh>) {
            chomp $l;
            next if $l =~ /^\s*$/;
            my @c = split /\|/, $l, -1;
            next unless @c >= 3;
            $map{$c[0]} = { clave => $c[1], descripcion => $c[2] };
            push @list, {
                id_unidad   => $c[0],
                clave       => $c[1],
                descripcion => $c[2]
            };
        }
        close $fh;
    }
    return (\@list, \%map);
}

sub cargar_insumos_3nf {
    my ($cat_map, $uni_map) = @_;
    my @list;
    if (-e $file_ins && open my $fh, '<:encoding(UTF-8)', $file_ins) {
        <$fh>;
        while (my $l = <$fh>) {
            chomp $l;
            next if $l =~ /^\s*$/;
            my @c = split /\|/, $l, -1;
            next unless @c >= 9;
            next unless ($c[1] eq 'ALL' || $c[1] eq $id_org);
            next unless $c[8] eq '1';
            my $u_info = $uni_map->{$c[5]} || { clave => 'PZA', descripcion => 'Pieza' };
            push @list, {
                id_insumo        => $c[0],
                tenant_id        => $c[1],
                codigo_sku       => $c[2],
                nombre           => $c[3],
                id_categoria     => $c[4],
                nombre_categoria => $cat_map->{$c[4]} || 'General',
                id_unidad        => $c[5],
                clave_unidad     => $u_info->{clave},
                precio_unitario  => sprintf("%.2f", $c[6] + 0) + 0,
                stock_actual     => int($c[7] || 0),
                activo           => 1
            };
        }
        close $fh;
    }
    return \@list;
}

sub ajustar_stock_insumo_3nf {
    my ($id_insumo, $delta) = @_;
    return unless -e $file_ins;
    my @lines;
    my $header = '';
    if (open my $fh, '<:encoding(UTF-8)', $file_ins) {
        $header = <$fh>;
        chomp $header if defined $header;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] && $c[0] eq $id_insumo) {
                my $nuevo = int($c[7] || 0) + $delta;
                $nuevo = 0 if $nuevo < 0;
                $c[7] = $nuevo;
                $l = join('|', @c);
            }
            push @lines, $l;
        }
        close $fh;
        utils::db_manager::actualizar_archivo($file_ins, $header, \@lines);
    }
}

sub eliminar_consumo_dat {
    my ($id_consumo) = @_;
    return unless -e $file_cons;
    my @lines;
    my $header = '';
    if (open my $fh, '<:encoding(UTF-8)', $file_cons) {
        $header = <$fh>;
        chomp $header if defined $header;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            next if ($c[0] && $c[0] eq $id_consumo);
            push @lines, $l;
        }
        close $fh;
        utils::db_manager::actualizar_archivo($file_cons, $header, \@lines);
    }
}

sub norm_espacio {
    my ($s) = @_;
    return '' unless defined $s;
    $s = lc($s);
    $s =~ s/[áàä]/a/g; $s =~ s/[éèë]/e/g; $s =~ s/[íìï]/i/g; $s =~ s/[óòö]/o/g; $s =~ s/[úùü]/u/g;
    $s =~ s/\bquirofanos?\b/qx/g;
    $s =~ s/[^a-z0-9]//g;
    return $s;
}

sub verificar_colision_espacio {
    my ($fecha, $hi, $hf, $sala, $exclude_qx, $exclude_ren) = @_;
    my @conflictos;
    my $m_ini = a_minutos($hi);
    my $m_fin = a_minutos($hf);
    $m_fin = $m_ini + 60 if $m_fin <= $m_ini;
    my $sala_norm = norm_espacio($sala);

    # 1. Revisar en dat/rentas_espacios.dat
    if (-e $file_rentas && open my $fhr, '<:encoding(UTF-8)', $file_rentas) {
        <$fhr>;
        while (my $l = <$fhr>) {
            chomp $l;
            next if $l =~ /^\s*$/;
            my @r = split /\|/, $l, -1;
            next unless @r >= 18;
            my ($r_id, $r_med, $r_nom, $r_fec, $r_hi, $r_hf, $r_esp, $r_mot, $r_not, $r_est, $r_neg) =
               ($r[0], $r[1], $r[2], $r[5], $r[6], $r[7], $r[9], $r[11], $r[12], $r[13], $r[17]);

            next if ($r_neg ne $id_org && $id_org ne '0');
            next if ($r_est =~ /^(Cancelada|No realizada|Finalizada)$/i);
            next if ($exclude_ren && $r_id eq $exclude_ren);
            next if ($exclude_qx && $r_not =~ /\Q$exclude_qx\E/);
            next unless ($r_fec eq $fecha);
            next unless (norm_espacio($r_esp) eq $sala_norm);

            my $rm_ini = a_minutos($r_hi);
            my $rm_fin = a_minutos($r_hf);
            if ($m_ini < $rm_fin && $m_fin > $rm_ini) {
                push @conflictos, {
                    origen      => 'Agenda de Espacios en Renta',
                    id_reserva  => $r_id,
                    responsable => $r_nom || 'Arrendatario',
                    fecha       => $r_fec,
                    hora_ini    => $r_hi,
                    hora_fin    => $r_hf,
                    sala        => $r_esp,
                    motivo      => $r_mot || 'Renta de Quirófano',
                    estado      => $r_est
                };
            }
        }
        close $fhr;
    }

    return \@conflictos;
}

sub sincronizar_renta_espacio {
    my %p = @_;
    my $header = "id_renta|id_arrendatario|nombre_arrendatario|telefono_arrendatario|correo_arrendatario|fecha|hora_ini|hora_fin|sucursal|espacio|tipo_espacio|motivo|notas|estado|monto_renta|pagado|folio_recibo|id_negocio|elaborado_por";
    my $nueva_linea = join('|',
        $p{id_renta},
        $p{id_arrendatario},
        $p{nombre_arrendatario},
        '',
        '',
        $p{fecha},
        $p{hora_ini},
        $p{hora_fin},
        $p{sucursal},
        $p{espacio},
        $p{tipo_espacio},
        $p{motivo},
        $p{notas},
        $p{estado},
        $p{monto_renta},
        $p{pagado},
        $p{folio_recibo},
        $p{id_negocio},
        $p{elaborado_por}
    );

    if (-e $file_rentas && open my $fh, '<:encoding(UTF-8)', $file_rentas) {
        my $hdr = <$fh>;
        chomp $hdr if defined $hdr;
        my @lines;
        my $found = 0;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] && $c[0] eq $p{id_renta}) {
                $l = $nueva_linea;
                $found = 1;
            }
            push @lines, $l;
        }
        close $fh;
        push @lines, $nueva_linea unless $found;
        utils::db_manager::actualizar_archivo($file_rentas, $hdr || $header, \@lines);
    } else {
        utils::db_manager::actualizar_archivo($file_rentas, $header, [$nueva_linea]);
    }
}

sub actualizar_pago_renta_espacio {
    my ($id_renta, $pagado, $folio_recibo) = @_;
    return unless -e $file_rentas;
    if (open my $fh, '<:encoding(UTF-8)', $file_rentas) {
        my $hdr = <$fh>;
        chomp $hdr if defined $hdr;
        my @lines;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] && $c[0] eq $id_renta) {
                $c[15] = $pagado;
                $c[16] = $folio_recibo;
                $l = join('|', @c);
            }
            push @lines, $l;
        }
        close $fh;
        utils::db_manager::actualizar_archivo($file_rentas, $hdr, \@lines);
    }
}

sub sincronizar_cita_paciente {
    my %p = @_;
    my $header = "id_cita|id_medico|id_paciente|fecha|hora_ini|hora_fin|motivo|notas|estado|event_id|color|prioridad|sucursal|consultorio|id_negocio|elaborado_por";
    my $color = ($p{prioridad} eq 'Urgencia') ? '#EF4444' : '#0284C7';
    my $nueva_linea = join('|',
        $p{id_cita},
        $p{id_medico},
        $p{id_paciente},
        $p{fecha},
        $p{hora_ini},
        $p{hora_fin},
        $p{motivo},
        $p{notas},
        $p{estado},
        '',
        $color,
        $p{prioridad},
        $p{sucursal},
        $p{consultorio},
        $p{id_negocio},
        $p{elaborado_por}
    );

    if (-e $file_citas && open my $fh, '<:encoding(UTF-8)', $file_citas) {
        my $hdr = <$fh>;
        chomp $hdr if defined $hdr;
        my @lines;
        my $found = 0;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] && $c[0] eq $p{id_cita}) {
                $l = $nueva_linea;
                $found = 1;
            }
            push @lines, $l;
        }
        close $fh;
        push @lines, $nueva_linea unless $found;
        utils::db_manager::actualizar_archivo($file_citas, $hdr || $header, \@lines);
    } else {
        utils::db_manager::actualizar_archivo($file_citas, $header, [$nueva_linea]);
    }
}

sub guardar_o_actualizar_quirofano_dat {
    my %p = @_;
    my $header = "ID_CIRUGIA|ID_ORG|ID_PACIENTE|ID_MEDICO|FECHA_PROGRAMADA|HORA_PROGRAMADA|ESTADO|SALA_QUIROFANO|PROCEDIMIENTO|ID_ANESTESIOLOGO|NOTAS|TIPO_CIRUGIA|ID_RENTA_ESPACIO|FOLIO_EXPEDIENTE";
    my $nueva = join('|',
        $p{id_cirugia}, $p{id_org}, $p{id_paciente}, $p{id_medico},
        $p{fecha}, $p{hora}, $p{estado}, $p{sala}, $p{procedimiento},
        $p{id_anestesiologo} || '', $p{notas} || '', $p{tipo_cirugia} || 'PROGRAMADA',
        $p{id_sala_renta} || '', $p{expediente_fisico_folio} || ''
    );

    if (-e $file_qx && open my $fh, '<:encoding(UTF-8)', $file_qx) {
        my $hdr = <$fh>;
        chomp $hdr if defined $hdr;
        my @lines;
        my $found = 0;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] && $c[0] eq $p{id_cirugia}) {
                $l = $nueva;
                $found = 1;
            }
            push @lines, $l;
        }
        close $fh;
        push @lines, $nueva unless $found;
        utils::db_manager::actualizar_archivo($file_qx, $header, \@lines);
    } else {
        utils::db_manager::actualizar_archivo($file_qx, $header, [$nueva]);
    }
}

sub actualizar_estado_quirofano_dat {
    my ($id_cirugia, $nuevo_estado) = @_;
    return unless -e $file_qx;
    if (open my $fh, '<:encoding(UTF-8)', $file_qx) {
        my $hdr = <$fh>;
        chomp $hdr if defined $hdr;
        my @lines;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] && $c[0] eq $id_cirugia) {
                $c[6] = $nuevo_estado;
                $l = join('|', @c);
            }
            push @lines, $l;
        }
        close $fh;
        utils::db_manager::actualizar_archivo($file_qx, $hdr, \@lines);
    }
}

sub sincronizar_consentimiento_paciente {
    my ($dossier, $firmante, $parentesco, $fecha_firma) = @_;
    my ($f_hoy, $h_hoy) = ahora_iso();
    my $id_cns = 'CNS-' . time() . '-' . int(rand(899)+100);
    my $id_pac = $dossier->{id_paciente};

    my $dir_cns = File::Spec->catdir($dat_dir, 'consentimientos');
    mkdir $dir_cns, 0777 unless -d $dir_cns;
    my $file_pac_cns = File::Spec->catfile($dir_cns, "paciente_${id_pac}.json");

    my $data = { id_paciente => $id_pac, documentos => [] };
    if (-e $file_pac_cns && open my $fh, '<:encoding(UTF-8)', $file_pac_cns) {
        local $/;
        my $raw = <$fh>;
        close $fh;
        my $dec = eval { decode_json($raw) };
        $data = $dec if ($dec && ref($dec) eq 'HASH');
    }

    push @{$data->{documentos}}, {
        id_consentimiento     => $id_cns,
        tipo                  => 'CIRUGIA_MAYOR',
        fecha                 => $f_hoy,
        hora                  => $h_hoy,
        procedimiento         => $dossier->{procedimiento},
        diagnostico           => $dossier->{procedimiento},
        id_medico             => $dossier->{id_medico},
        nombre_medico         => $dossier->{nombre_medico},
        id_cirugia            => $dossier->{id_cirugia},
        nombre_firmante       => $firmante,
        parentesco_firmante   => $parentesco,
        fecha_firma           => $fecha_firma,
        beneficios            => 'Resolución quirúrgica de la patología diagnosticada bajo protocolo de Cirugía Segura.',
        riesgos_complicaciones=> 'Sangrado, infección, reacciones anestésicas o complicaciones inherentes al acto quirúrgico.',
        alternativas          => 'Valoradas previamente en protocolo preoperatorio.',
        estado                => 'Firmado'
    };

    if (open my $fhw, '>:encoding(UTF-8)', $file_pac_cns) {
        flock($fhw, LOCK_EX);
        print $fhw encode_json($data);
        flock($fhw, LOCK_UN);
        close $fhw;
    }

    return $id_cns;
}

sub emitir_recibo_deposito_caja {
    my ($dossier, $monto, $metodo) = @_;
    return emitir_recibo_privado_canonico(
        dossier  => $dossier,
        monto    => $monto,
        metodo   => $metodo,
        concepto => "Depósito de Ingreso Quirúrgico ($dossier->{id_cirugia} - $dossier->{procedimiento} - $dossier->{sala})"
    );
}

sub emitir_recibo_finiquito_caja {
    my ($dossier, $monto, $metodo) = @_;
    return emitir_recibo_privado_canonico(
        dossier  => $dossier,
        monto    => $monto,
        metodo   => $metodo,
        concepto => "Liquidación de Corte de Caja Quirúrgico ($dossier->{id_cirugia} - $dossier->{procedimiento})"
    );
}

sub emitir_recibo_privado_canonico {
    my %args = @_;
    my $dossier  = $args{dossier};
    my $monto    = sprintf("%.2f", ($args{monto} || 0) + 0);
    my $metodo   = $args{metodo} || 'Efectivo';
    my $concepto = $args{concepto} || 'Servicio Quirúrgico';

    my ($f_iso, $h_iso) = ahora_iso();
    my $folio_num = 1;
    my $cnt_file = File::Spec->catfile($dat_dir, "contadores_recibos_privados_${id_org}.dat");
    if (-e $cnt_file && open my $fhc, '<', $cnt_file) {
        my $val = <$fhc>; chomp $val if defined $val;
        $folio_num = int($val) + 1 if defined $val && $val =~ /^\d+$/;
        close $fhc;
    }
    if (open my $fhw, '>', $cnt_file) {
        print $fhw $folio_num;
        close $fhw;
    }

    my $id_recibo = "RC-" . time() . "-" . int(rand(899)+100);
    my $items_json = encode_json([{
        concepto => $concepto,
        cantidad => 1,
        precio   => $monto + 0,
        subtotal => $monto + 0
    }]);

    my $linea_rec = join('|',
        $id_recibo,
        $folio_num,
        $id_org,
        $f_iso,
        $h_iso,
        $dossier->{id_paciente} || 'EXTERNO',
        $dossier->{nombre_paciente} || 'Paciente Quirúrgico',
        $dossier->{id_medico} || '',
        $dossier->{nombre_medico} || '',
        $monto,
        $metodo,
        $items_json,
        $usuario,
        'Activo',
        '',
        '',
        $dossier->{id_cirugia}
    ) . "\n";

    if (open my $fhr, '>>:encoding(UTF-8)', $file_recibos) {
        flock($fhr, LOCK_EX);
        print $fhr $linea_rec;
        flock($fhr, LOCK_UN);
        close $fhr;
    }

    return $id_recibo;
}

sub guardar_tramite_ingreso_dat {
    my ($dossier) = @_;
    my $trm = $dossier->{tramites_ingreso} || {};
    my (undef, undef, $ts) = ahora_iso();
    my $header = "id_tramite|tenant_id|id_cirugia|contrato_firmado|consentimiento_informado_firmado|nombre_firmante|parentesco_firmante|fecha_firma_consentimiento|deposito_monto|deposito_pagado|folio_recibo_caja|created_at|updated_at|created_by";
    my $nueva = join('|',
        $trm->{id_tramite} || ('TRM-' . time()),
        $id_org,
        $dossier->{id_cirugia},
        $trm->{contrato_firmado} ? 1 : 0,
        $trm->{consentimiento_informado_firmado} ? 1 : 0,
        $trm->{nombre_firmante} || '',
        $trm->{parentesco_firmante} || '',
        $trm->{fecha_firma_consentimiento} || '',
        sprintf("%.2f", ($trm->{deposito_monto} // 5000) + 0),
        $trm->{deposito_pagado} ? 1 : 0,
        $trm->{folio_recibo_caja} || '',
        $ts,
        $ts,
        $usuario
    );

    if (-e $file_trm && open my $fh, '<:encoding(UTF-8)', $file_trm) {
        my $hdr = <$fh>; chomp $hdr if defined $hdr;
        my @lines;
        my $found = 0;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[2] && $c[2] eq $dossier->{id_cirugia}) {
                $l = $nueva;
                $found = 1;
            }
            push @lines, $l;
        }
        close $fh;
        push @lines, $nueva unless $found;
        utils::db_manager::actualizar_archivo($file_trm, $hdr || $header, \@lines);
    } else {
        utils::db_manager::actualizar_archivo($file_trm, $header, [$nueva]);
    }
}

sub guardar_receta_alta_dat {
    my ($dossier) = @_;
    my $rec = $dossier->{receta_alta} || {};
    my (undef, undef, $ts) = ahora_iso();
    my $header = "id_receta|tenant_id|id_cirugia|diagnostico_egreso_cie10|indicaciones_generales|medicamentos_json|fecha_emision|hash_firma_electronica|created_at|updated_at|created_by";
    my $meds_str = encode_json($rec->{medicamentos} || []);
    my $nueva = join('|',
        $rec->{id_receta} || ('REC-QX-' . time()),
        $id_org,
        $dossier->{id_cirugia},
        $rec->{diagnostico_egreso_cie10} || '',
        $rec->{indicaciones_generales} || '',
        $meds_str,
        $rec->{fecha_emision} || $ts,
        $rec->{hash_firma_electronica} || '',
        $ts,
        $ts,
        $usuario
    );

    if (-e $file_rec_alta && open my $fh, '<:encoding(UTF-8)', $file_rec_alta) {
        my $hdr = <$fh>; chomp $hdr if defined $hdr;
        my @lines;
        my $found = 0;
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[2] && $c[2] eq $dossier->{id_cirugia}) {
                $l = $nueva;
                $found = 1;
            }
            push @lines, $l;
        }
        close $fh;
        push @lines, $nueva unless $found;
        utils::db_manager::actualizar_archivo($file_rec_alta, $hdr || $header, \@lines);
    } else {
        utils::db_manager::actualizar_archivo($file_rec_alta, $header, [$nueva]);
    }
}

sub recalcular_totales_y_semaforos {
    my ($dossier) = @_;
    my $consumos = $dossier->{consumos_3nf} || [];
    my $sub_insumos = 0;
    my @resumen_insumos;

    foreach my $c (@$consumos) {
        my $st = ($c->{subtotal} || 0) + 0;
        $sub_insumos += $st;
        push @resumen_insumos, {
            concepto => "[$c->{etapa_clinica}] $c->{nombre} (x$c->{cantidad})",
            monto    => $st
        };
    }

    my $liq = $dossier->{liquidacion_insumos} ||= {};
    my $horas_sala = ($liq->{horas_sala} // 2) + 0;
    my $costo_hora = ($liq->{costo_hora_sala} // 2500) + 0;
    my $hon_cir    = ($liq->{honorarios_cirujano} // 0) + 0;
    my $hon_ane    = ($liq->{honorarios_anestesio} // 0) + 0;

    my $sub_sala   = $horas_sala * $costo_hora;
    my $tot_bruto  = $sub_insumos + $sub_sala + $hon_cir + $hon_ane;

    my $trm = $dossier->{tramites_ingreso} || {};
    my $dep_pagado = $trm->{deposito_pagado} ? (($trm->{deposito_monto} // 5000) + 0) : 0;
    my $saldo_liq  = $tot_bruto - $dep_pagado;

    $liq->{insumos}              = \@resumen_insumos;
    $liq->{subtotal_insumos_3nf} = sprintf("%.2f", $sub_insumos) + 0;
    $liq->{subtotal_renta_sala}  = sprintf("%.2f", $sub_sala) + 0;
    $liq->{deposito_aplicado}    = sprintf("%.2f", $dep_pagado) + 0;
    $liq->{total_calculado}      = sprintf("%.2f", $tot_bruto) + 0;
    $liq->{saldo_a_liquidar}     = sprintf("%.2f", $saldo_liq) + 0;

    # Calcular los 8 semáforos
    my $estado   = $dossier->{estado} || 'Programada';
    my $tipo_cir = $dossier->{tipo_cirugia} || 'PROGRAMADA';
    my $chk      = $dossier->{checklist_preop} || {};
    my $trn      = $dossier->{transoperatorio} || {};
    my $ucp      = $dossier->{recuperacion_ucpa} || {};
    my $rec      = $dossier->{receta_alta} || {};

    my $contrato_ok = $trm->{contrato_firmado} ? 1 : 0;
    my $consent_ok  = ($trm->{consentimiento_informado_firmado} || $chk->{consentimiento_firmado}) ? 1 : 0;
    my $deposito_ok = $trm->{deposito_pagado} ? 1 : 0;

    my %sem = (
        agenda_espacios          => 'VERDE',
        agenda_paciente          => 'VERDE',
        recepcion_consentimiento => ($contrato_ok && $consent_ok) ? 'VERDE' : ($tipo_cir eq 'URGENCIAS' ? 'ROJO' : 'AMBAR'),
        caja                     => $deposito_ok ? 'VERDE' : ($tipo_cir eq 'URGENCIAS' ? 'ROJO' : 'AMBAR'),
        enfermeria               => 'GRIS',
        quirofano                => 'GRIS',
        recuperacion             => 'GRIS',
        alta_receta              => 'GRIS'
    );

    if ($estado eq 'Programada') {
        $sem{enfermeria} = ($contrato_ok && $consent_ok && $deposito_ok) ? 'AMBAR' : 'GRIS';
    } elsif ($estado eq 'Pre-Operatorio') {
        my $preop_done = ($chk->{identidad_verificada} && $chk->{via_permeable}) ? 1 : 0;
        $sem{enfermeria} = $preop_done ? 'VERDE' : 'AMBAR';
        $sem{quirofano}  = $preop_done ? 'AMBAR' : 'GRIS';
    } elsif ($estado =~ /Quir[oó]fano/i) {
        $sem{enfermeria}   = 'VERDE';
        my $qx_done        = ($trn->{hora_incision} && $trn->{hora_cierre}) ? 1 : 0;
        $sem{quirofano}    = $qx_done ? 'VERDE' : 'AMBAR';
        $sem{recuperacion} = $qx_done ? 'AMBAR' : 'GRIS';
    } elsif ($estado =~ /Recuperaci[oó]n/i) {
        $sem{enfermeria}   = 'VERDE';
        $sem{quirofano}    = 'VERDE';
        my $ucpa_done      = ($ucp->{aprobado_alta} || ($ucp->{aldrete_total} && $ucp->{aldrete_total} >= 9)) ? 1 : 0;
        $sem{recuperacion} = $ucpa_done ? 'VERDE' : 'AMBAR';
        $sem{alta_receta}  = 'AMBAR';
    } elsif ($estado =~ /Alta/i) {
        $sem{enfermeria}   = 'VERDE';
        $sem{quirofano}    = 'VERDE';
        $sem{recuperacion} = 'VERDE';
        my $alta_done      = ($rec->{pase_salida_emitido} || $liq->{corte_liquidado}) ? 1 : 0;
        $sem{alta_receta}  = $alta_done ? 'VERDE' : 'AMBAR';
    }

    $dossier->{semaforos} = \%sem;
}

sub obtener_mapa_pacientes {
    my %map;
    if (-e $file_pac && open my $fh, '<:encoding(UTF-8)', $file_pac) {
        <$fh>;
        while (my $l = <$fh>) {
            chomp $l;
            my @p = split /\|/, $l, -1;
            $map{$p[0]} = $p[2] if defined $p[0] && defined $p[2];
        }
        close $fh;
    }
    return \%map;
}

sub obtener_mapa_medicos {
    my %map;
    my $usr_file = File::Spec->catfile($dat_dir, 'usuarios.dat');
    if (-e $usr_file && open my $fh, '<:encoding(UTF-8)', $usr_file) {
        <$fh>;
        while (my $l = <$fh>) {
            chomp $l;
            my @u = split /!/, $l, -1;
            $map{$u[0]} = $u[1] if defined $u[0] && defined $u[1];
        }
        close $fh;
    }
    return \%map;
}

sub get_surgical_file_path {
    my ($id_cirugia) = @_;
    $id_cirugia =~ s/[^a-zA-Z0-9_\-]//g;
    return File::Spec->catfile($qx_dir, "cirugia_$id_cirugia.json");
}

sub cargar_dossier_quirurgico {
    my ($id_cirugia) = @_;
    my $path = get_surgical_file_path($id_cirugia);
    if (-e $path && open my $fh, '<:encoding(UTF-8)', $path) {
        local $/;
        my $raw = <$fh>;
        close $fh;
        if ($raw && $raw =~ /\S/) {
            my $data = eval { decode_json($raw) };
            return $data if ($data && ref($data) eq 'HASH');
        }
    }
    return undef;
}

sub guardar_dossier_quirurgico {
    my ($id_cirugia, $data) = @_;
    my $path = get_surgical_file_path($id_cirugia);
    if (open my $fh, '>:encoding(UTF-8)', $path) {
        flock($fh, LOCK_EX);
        print $fh encode_json($data);
        flock($fh, LOCK_UN);
        close $fh;
        return 1;
    }
    return 0;
}

1;

