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

my $action = $q->param('action') || 'read';
my $file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'quirofano.dat');
my $id_org = $sd->{id_empresa} || 'ORG-000';

unless (-e $file) {
    open my $fh_init, '>:encoding(UTF-8)', $file;
    print $fh_init "ID_CIRUGIA|ID_ORG|ID_PACIENTE|ID_MEDICO|FECHA_PROGRAMADA|HORA_PROGRAMADA|ESTADO|SALA_QUIROFANO|PROCEDIMIENTO|ID_ANESTESIOLOGO|NOTAS\n";
    close $fh_init;
}

if ($action eq 'read') {
    my $fecha_filtro = $q->param('fecha') || '';
    my @registros;
    
    # Necesitamos cruzar datos de pacientes y médicos para mostrar nombres
    my %pacientes;
    my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
    if (-e $pac_file && open my $fhp, '<:encoding(UTF-8)', $pac_file) {
        my $hdr = <$fhp>;
        while (my $line = <$fhp>) {
            chomp $line;
            my @p = split /\|/, $line, -1;
            $pacientes{$p[0]} = $p[2] || 'Paciente Desconocido';
        }
        close $fhp;
    }
    
    my %medicos;
    my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    if (-e $usr_file && open my $fhu, '<:encoding(UTF-8)', $usr_file) {
        my $hdr = <$fhu>;
        while (my $line = <$fhu>) {
            chomp $line;
            my @u = split /!/, $line, -1;
            $medicos{$u[0]} = $u[1] || 'Sin Médico';
        }
        close $fhu;
    }

    if (open my $fh, '<:encoding(UTF-8)', $file) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /\|/, $line, -1;
            next unless @c >= 10;
            
            # Filtro por Organización
            next if ($c[1] ne $id_org && $id_org ne 'ORG-000');
            
            # Filtro por Fecha (si se especifica fecha, filtrar exactamente por esa fecha; si es 'todas', no filtrar)
            if ($fecha_filtro && $fecha_filtro ne 'todas') {
                next if ($c[4] ne $fecha_filtro);
            }
            
            # Si el paciente es del estado, mostramos su nombre tal cual en caso de no estar en dat/pacientes
            my $nombre_pac = $pacientes{$c[2]} // $c[2];
            
            push @registros, {
                id_cirugia       => $c[0],
                id_paciente      => $c[2],
                nombre_paciente  => $nombre_pac,
                id_medico        => $c[3],
                nombre_medico    => $medicos{$c[3]} // 'Desconocido',
                fecha            => $c[4],
                hora             => $c[5],
                estado           => $c[6],
                sala             => $c[7],
                procedimiento    => $c[8],
                id_anestesiologo => $c[9],
                nombre_anestesio => $c[9] ? ($medicos{$c[9]} // '') : '',
                notas            => $c[10] // ''
            };
        }
        close $fh;
    }
    print encode_json(\@registros);
    exit;
}
elsif ($action eq 'create') {
    my $id_paciente = $q->param('id_paciente') || '';
    my $id_medico = $q->param('id_medico') || '';
    my $fecha = $q->param('fecha_programada') || '';
    my $hora = $q->param('hora_programada') || '';
    my $sala = $q->param('sala') || '';
    my $procedimiento = $q->param('procedimiento') || '';
    my $id_anest = $q->param('id_anestesiologo') || '';
    my $notas = $q->param('notas') || '';
    
    $sala =~ s/\|/ /g;
    $procedimiento =~ s/\|/ /g;
    $notas =~ s/\|/ /g;
    
    if (!$id_paciente || !$id_medico || !$procedimiento) {
        print encode_json({ ok => JSON::false, msg => 'Datos obligatorios incompletos (Paciente, Médico y Procedimiento).' });
        exit;
    }
    
    my $id_cir = 'CIR-' . time() . '-' . int(rand(1000));
    my $linea = join('|', $id_cir, $id_org, $id_paciente, $id_medico, $fecha, $hora, 'Programada', $sala, $procedimiento, $id_anest, $notas);
    
    utils::db_manager::guardar_registro($file, $linea);
    print encode_json({ ok => JSON::true, id_cirugia => $id_cir });
    exit;
}
elsif ($action eq 'update_status') {
    my $id_cirugia = $q->param('id_cirugia') || '';
    my $nuevo_estado = $q->param('estado') || '';
    
    if (!$id_cirugia || !$nuevo_estado) {
        print encode_json({ ok => JSON::false, msg => 'Faltan parámetros' });
        exit;
    }
    
    my @lines;
    my $found = 0;
    if (open my $fh, '<:encoding(UTF-8)', $file) {
        my $cabecera = <$fh>;
        chomp $cabecera if defined $cabecera;
        
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id_cirugia && ($c[1] eq $id_org || $id_org eq 'ORG-000')) {
                $c[6] = $nuevo_estado;
                $l = join('|', @c);
                $found = 1;
            }
            push @lines, $l;
        }
        close $fh;
        if ($found) {
            utils::db_manager::actualizar_archivo($file, $cabecera, \@lines);
            print encode_json({ ok => JSON::true });
        } else {
            print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada o acceso denegado.' });
        }
    } else {
        print encode_json({ ok => JSON::false, msg => 'No se pudo leer el archivo' });
    }
    exit;
}
elsif ($action eq 'delete') {
    my $id_cirugia = $q->param('id_cirugia') || '';
    my @lines;
    my $found = 0;
    if (open my $fh, '<:encoding(UTF-8)', $file) {
        my $cabecera = <$fh>;
        chomp $cabecera if defined $cabecera;
        
        while (my $l = <$fh>) {
            chomp $l;
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id_cirugia && ($c[1] eq $id_org || $id_org eq 'ORG-000')) {
                $found = 1;
                next; # Lo omitimos para borrarlo
            }
            push @lines, $l;
        }
        close $fh;
        if ($found) {
            utils::db_manager::actualizar_archivo($file, $cabecera, \@lines);
            print encode_json({ ok => JSON::true });
        } else {
            print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada.' });
        }
    }
    exit;
}
elsif ($action eq 'get_surgical_record') {
    my $id_cirugia = $q->param('id_cirugia') || '';
    if (!$id_cirugia) {
        print encode_json({ ok => JSON::false, msg => 'ID de cirugía requerido' });
        exit;
    }

    my $dossier = cargar_dossier_quirurgico($id_cirugia);
    if ($dossier) {
        print encode_json({ ok => JSON::true, dossier => $dossier });
        exit;
    }

    # Si no existe, construir desde quirofano.dat
    my %pacientes;
    my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
    if (-e $pac_file && open my $fhp, '<:encoding(UTF-8)', $pac_file) {
        my $hdr = <$fhp>;
        while (my $line = <$fhp>) {
            chomp $line;
            my @p = split /\|/, $line, -1;
            $pacientes{$p[0]} = $p[2] || 'Paciente Desconocido';
        }
        close $fhp;
    }

    my %medicos;
    my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    if (-e $usr_file && open my $fhu, '<:encoding(UTF-8)', $usr_file) {
        my $hdr = <$fhu>;
        while (my $line = <$fhu>) {
            chomp $line;
            my @u = split /!/, $line, -1;
            $medicos{$u[0]} = $u[1] || 'Sin Médico';
        }
        close $fhu;
    }

    my $encontrado = 0;
    if (open my $fh, '<:encoding(UTF-8)', $file) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /\|/, $line, -1;
            if ($c[0] eq $id_cirugia) {
                my $nombre_pac = $pacientes{$c[2]} // $c[2];
                my $nombre_med = $medicos{$c[3]} // 'Desconocido';
                my $nombre_ane = $c[9] ? ($medicos{$c[9]} // '') : '';

                $dossier = {
                    id_cirugia => $id_cirugia,
                    id_org => $c[1] || $id_org,
                    id_paciente => $c[2],
                    nombre_paciente => $nombre_pac,
                    id_medico => $c[3],
                    nombre_medico => $nombre_med,
                    fecha => $c[4],
                    hora => $c[5],
                    estado => $c[6],
                    sala => $c[7],
                    procedimiento => $c[8],
                    id_anestesiologo => $c[9],
                    nombre_anestesio => $nombre_ane,
                    checklist_preop => {
                        identidad_verificada => 0,
                        consentimiento_firmado => 0,
                        id_consentimiento => '',
                        ayuno_confirmado => 0,
                        horas_ayuno => 8,
                        labs_validados => 0,
                        sitio_marcado => 0,
                        via_permeable => 0,
                        profilaxis_antibiotica => 0,
                        alergias_verificadas => 0,
                        observaciones_enfermeria => ''
                    },
                    transoperatorio => {
                        hora_ingreso_sala => $c[5] || '',
                        hora_inicio_anestesia => '',
                        hora_incision => '',
                        hora_cierre => '',
                        hora_salida_sala => '',
                        conteo_gasas_completo => 0,
                        conteo_compresas_completo => 0,
                        conteo_instrumental_completo => 0,
                        incidentes_accidentes => ''
                    },
                    nota_quirurgica => {
                        cirujano => $nombre_med,
                        primer_ayudante => '',
                        anestesiologo => $nombre_ane,
                        instrumentista => '',
                        circulante => '',
                        tipo_anestesia => 'General Balanceada',
                        diagnostico_preop => $c[8],
                        diagnostico_postop => $c[8],
                        operacion_planeada => $c[8],
                        operacion_realizada => $c[8],
                        descripcion_tecnica => '',
                        hallazgos => '',
                        sangrado_aprox_ml => '0',
                        piezas_patologia => '',
                        estado_salida => 'Estable a UCPA',
                        fecha_cierre => ''
                    },
                    recuperacion_ucpa => {
                        cama_ucpa => 'UCPA-01',
                        aldrete_actividad => 2,
                        aldrete_respiracion => 2,
                        aldrete_circulacion => 2,
                        aldrete_conciencia => 2,
                        aldrete_saturacion => 2,
                        aldrete_total => 10,
                        aprobado_alta => 0,
                        medico_alta => $nombre_med
                    },
                    liquidacion_insumos => {
                        horas_sala => 1,
                        costo_hora_sala => 1500,
                        honorarios_cirujano => 0,
                        honorarios_anestesio => 0,
                        insumos => [],
                        total_calculado => 1500,
                        id_movimiento_caja => '',
                        registrado_en_caja => 0
                    }
                };
                guardar_dossier_quirurgico($id_cirugia, $dossier);
                $encontrado = 1;
                last;
            }
        }
        close $fh;
    }

    if ($encontrado && $dossier) {
        print encode_json({ ok => JSON::true, dossier => $dossier });
    } else {
        print encode_json({ ok => JSON::false, msg => 'Cirugía no encontrada' });
    }
    exit;
}
elsif ($action eq 'save_preop_checklist') {
    my $id_cirugia = $q->param('id_cirugia') || '';
    if (!$id_cirugia) {
        print encode_json({ ok => JSON::false, msg => 'ID de cirugía requerido' });
        exit;
    }

    my $dossier = cargar_dossier_quirurgico($id_cirugia) || {};
    $dossier->{id_cirugia} ||= $id_cirugia;
    $dossier->{checklist_preop} = {
        identidad_verificada     => ($q->param('identidad_verificada') eq '1' || $q->param('identidad_verificada') eq 'true') ? 1 : 0,
        consentimiento_firmado   => ($q->param('consentimiento_firmado') eq '1' || $q->param('consentimiento_firmado') eq 'true') ? 1 : 0,
        id_consentimiento        => $q->param('id_consentimiento') || '',
        ayuno_confirmado         => ($q->param('ayuno_confirmado') eq '1' || $q->param('ayuno_confirmado') eq 'true') ? 1 : 0,
        horas_ayuno              => $q->param('horas_ayuno') || 8,
        labs_validados           => ($q->param('labs_validados') eq '1' || $q->param('labs_validados') eq 'true') ? 1 : 0,
        sitio_marcado            => ($q->param('sitio_marcado') eq '1' || $q->param('sitio_marcado') eq 'true') ? 1 : 0,
        via_permeable            => ($q->param('via_permeable') eq '1' || $q->param('via_permeable') eq 'true') ? 1 : 0,
        profilaxis_antibiotica   => ($q->param('profilaxis_antibiotica') eq '1' || $q->param('profilaxis_antibiotica') eq 'true') ? 1 : 0,
        alergias_verificadas     => ($q->param('alergias_verificadas') eq '1' || $q->param('alergias_verificadas') eq 'true') ? 1 : 0,
        observaciones_enfermeria => $q->param('observaciones_enfermeria') || ''
    };

    guardar_dossier_quirurgico($id_cirugia, $dossier);
    print encode_json({ ok => JSON::true, msg => 'Checklist Preoperatorio guardado exitosamente' });
    exit;
}
elsif ($action eq 'save_surgical_note') {
    my $id_cirugia = $q->param('id_cirugia') || '';
    if (!$id_cirugia) {
        print encode_json({ ok => JSON::false, msg => 'ID de cirugía requerido' });
        exit;
    }

    my $dossier = cargar_dossier_quirurgico($id_cirugia) || {};
    $dossier->{id_cirugia} ||= $id_cirugia;

    $dossier->{transoperatorio} = {
        hora_ingreso_sala             => $q->param('hora_ingreso_sala') || '',
        hora_inicio_anestesia         => $q->param('hora_inicio_anestesia') || '',
        hora_incision                 => $q->param('hora_incision') || '',
        hora_cierre                   => $q->param('hora_cierre') || '',
        hora_salida_sala              => $q->param('hora_salida_sala') || '',
        conteo_gasas_completo         => ($q->param('conteo_gasas_completo') eq '1' || $q->param('conteo_gasas_completo') eq 'true') ? 1 : 0,
        conteo_compresas_completo     => ($q->param('conteo_compresas_completo') eq '1' || $q->param('conteo_compresas_completo') eq 'true') ? 1 : 0,
        conteo_instrumental_completo => ($q->param('conteo_instrumental_completo') eq '1' || $q->param('conteo_instrumental_completo') eq 'true') ? 1 : 0,
        incidentes_accidentes         => $q->param('incidentes_accidentes') || 'Sin incidentes'
    };

    $dossier->{nota_quirurgica} = {
        cirujano            => $q->param('cirujano') || '',
        primer_ayudante     => $q->param('primer_ayudante') || '',
        anestesiologo       => $q->param('anestesiologo') || '',
        instrumentista      => $q->param('instrumentista') || '',
        circulante          => $q->param('circulante') || '',
        tipo_anestesia      => $q->param('tipo_anestesia') || 'General',
        diagnostico_preop   => $q->param('diagnostico_preop') || '',
        diagnostico_postop  => $q->param('diagnostico_postop') || '',
        operacion_planeada  => $q->param('operacion_planeada') || '',
        operacion_realizada => $q->param('operacion_realizada') || '',
        descripcion_tecnica => $q->param('descripcion_tecnica') || '',
        hallazgos           => $q->param('hallazgos') || '',
        sangrado_aprox_ml   => $q->param('sangrado_aprox_ml') || '0',
        piezas_patologia    => $q->param('piezas_patologia') || '',
        estado_salida       => $q->param('estado_salida') || 'Estable',
        fecha_cierre        => sprintf("%04d-%02d-%02d %02d:%02d", (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3], (localtime)[2], (localtime)[1])
    };

    my $aldrete_act = int($q->param('aldrete_actividad') // 2);
    my $aldrete_res = int($q->param('aldrete_respiracion') // 2);
    my $aldrete_cir = int($q->param('aldrete_circulacion') // 2);
    my $aldrete_con = int($q->param('aldrete_conciencia') // 2);
    my $aldrete_sat = int($q->param('aldrete_saturacion') // 2);
    my $aldrete_tot = $aldrete_act + $aldrete_res + $aldrete_cir + $aldrete_con + $aldrete_sat;

    $dossier->{recuperacion_ucpa} = {
        cama_ucpa           => $q->param('cama_ucpa') || 'UCPA-01',
        aldrete_actividad   => $aldrete_act,
        aldrete_respiracion => $aldrete_res,
        aldrete_circulacion => $aldrete_cir,
        aldrete_conciencia  => $aldrete_con,
        aldrete_saturacion  => $aldrete_sat,
        aldrete_total       => $aldrete_tot,
        aprobado_alta       => $aldrete_tot >= 9 ? 1 : 0,
        medico_alta         => $q->param('medico_alta') || $dossier->{nombre_medico} || ''
    };

    guardar_dossier_quirurgico($id_cirugia, $dossier);
    print encode_json({
        ok => JSON::true,
        msg => 'Nota Quirúrgica y Registro Transoperatorio guardados exitosamente',
        aldrete_total => $aldrete_tot
    });
    exit;
}
elsif ($action eq 'save_financial_closure') {
    my $id_cirugia = $q->param('id_cirugia') || '';
    if (!$id_cirugia) {
        print encode_json({ ok => JSON::false, msg => 'ID de cirugía requerido' });
        exit;
    }

    my $dossier = cargar_dossier_quirurgico($id_cirugia) || {};
    $dossier->{id_cirugia} ||= $id_cirugia;

    my $horas_sala = $q->param('horas_sala') || 1;
    my $costo_hora_sala = $q->param('costo_hora_sala') || 0;
    my $hon_cir = $q->param('honorarios_cirujano') || 0;
    my $hon_ane = $q->param('honorarios_anestesio') || 0;
    my $insumos_raw = $q->param('insumos_json') || '[]';
    my $insumos = eval { decode_json($insumos_raw) } || [];
    my $total_calculado = $q->param('total_calculado') || 0;
    my $enviar_caja = ($q->param('enviar_a_caja') eq '1' || $q->param('enviar_a_caja') eq 'true') ? 1 : 0;

    $dossier->{liquidacion_insumos} = {
        horas_sala          => $horas_sala,
        costo_hora_sala     => $costo_hora_sala,
        honorarios_cirujano => $hon_cir,
        honorarios_anestesio=> $hon_ane,
        insumos             => $insumos,
        total_calculado     => $total_calculado,
        id_movimiento_caja  => $dossier->{liquidacion_insumos}->{id_movimiento_caja} || '',
        registrado_en_caja  => $dossier->{liquidacion_insumos}->{registrado_en_caja} || 0
    };

    if ($enviar_caja && !$dossier->{liquidacion_insumos}->{registrado_en_caja}) {
        my $id_paciente = $dossier->{id_paciente} || '';
        my $nombre_pac = $dossier->{nombre_paciente} || 'Paciente';
        my $id_medico = $dossier->{id_medico} || '';
        my $procedimiento = $dossier->{procedimiento} || 'Procedimiento Quirúrgico';
        my $sala = $dossier->{sala} || 'Sala General';

        my $id_tx = "TX-QX-" . time() . "-" . int(rand(1000));
        my $id_mov = "MOV-" . time() . "-" . int(rand(1000));
        my $monto_neto = sprintf("%.2f", $total_calculado);
        my $fecha_hoy = sprintf("%04d-%02d-%02d", (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3]);

        my $linea_edo = join('|',
            $id_tx,
            $id_mov,
            $id_paciente,
            'Cargo',
            "Servicios Quirúrgicos: $procedimiento",
            $monto_neto,
            '0',
            $monto_neto,
            $fecha_hoy,
            $id_medico,
            "Cirugía #$id_cirugia | Sala: $sala | Insumos y Sala Qx",
            $nombre_pac
        ) . "\n";

        my $edo_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estado_cuenta.dat');
        if (open my $fh_edo, '>>:encoding(UTF-8)', $edo_file) {
            flock($fh_edo, LOCK_EX);
            print $fh_edo $linea_edo;
            flock($fh_edo, LOCK_UN);
            close $fh_edo;

            $dossier->{liquidacion_insumos}->{id_movimiento_caja} = $id_mov;
            $dossier->{liquidacion_insumos}->{registrado_en_caja} = 1;
        }
    }

    guardar_dossier_quirurgico($id_cirugia, $dossier);
    print encode_json({
        ok => JSON::true,
        msg => 'Pre-liquidación guardada' . ($enviar_caja ? ' e inyectada a Estado de Cuenta para cobro en Caja' : ''),
        registrado_en_caja => $dossier->{liquidacion_insumos}->{registrado_en_caja},
        id_movimiento_caja => $dossier->{liquidacion_insumos}->{id_movimiento_caja}
    });
    exit;
}
else {
    print encode_json({ ok => JSON::false, msg => 'Acción inválida' });
    exit;
}

# ==================== HELPERS DE DOSSIER QUIRURGICO ====================
sub get_surgical_file_path {
    my ($id_cirugia) = @_;
    $id_cirugia =~ s/[^a-zA-Z0-9_\-]//g;
    my $dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'quirofano');
    unless (-d $dir) {
        mkdir $dir, 0777;
    }
    return File::Spec->catfile($dir, "cirugia_$id_cirugia.json");
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
