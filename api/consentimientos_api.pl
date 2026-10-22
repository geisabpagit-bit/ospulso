#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON qw(decode_json encode_json);
use File::Spec;
use FindBin;
use Fcntl qw(:flock);
use MIME::Base64 qw(decode_base64);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla actualizar_archivo);

binmode STDOUT, ':raw';

my $q = CGI->new;
my $session_data = check_session($q);

print $q->header(-type => 'application/json', -charset => 'UTF-8');

unless ($session_data && $session_data->{session_ok}) {
    print encode_json({ ok => 0, error => 'Sesión no válida o expirada' });
    exit;
}

my $usuario_sesion = $session_data->{usuario} || '';
my $id_medico_sesion = $session_data->{id_medico} // $session_data->{id_registro} // '';

my $accion = $q->param('accion') || $q->param('action') || 'list';
my $id_paciente = $q->param('id_paciente') || '';
$id_paciente =~ s/[^\w\-]//g;

if (!$id_paciente) {
    print encode_json({ ok => 0, error => 'ID de paciente requerido' });
    exit;
}

my $dir_json = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'consentimientos');
unless (-d $dir_json) {
    mkdir $dir_json, 0755;
}
my $archivo_paciente_json = File::Spec->catfile($dir_json, "paciente_${id_paciente}.json");
my $archivo_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consentimientos.dat');
my $firmas_dir = File::Spec->catdir($FindBin::Bin, '..', 'uploads', 'firmas');
unless (-d $firmas_dir) {
    mkdir $firmas_dir, 0755;
}

# Helper: Cargar historial de consentimientos del paciente (JSON atómico con fallback y sincronización desde consentimientos.dat)
sub cargar_consentimientos_paciente {
    my ($id_p) = @_;
    my @lista = ();
    my %ids_existentes = ();

    # 1. Intentar cargar desde JSON atómico
    if (-e $archivo_paciente_json && open(my $fh_j, '<:encoding(UTF-8)', $archivo_paciente_json)) {
        local $/;
        my $content = <$fh_j>;
        close($fh_j);
        my $data = eval { decode_json($content) };
        if ($data && ref($data) eq 'HASH' && ref($data->{consentimientos}) eq 'ARRAY') {
            @lista = @{ $data->{consentimientos} };
            foreach my $it (@lista) {
                $ids_existentes{$it->{id_consentimiento}} = 1 if $it->{id_consentimiento};
            }
        }
    }

    # 2. Cargar/Sincronizar desde consentimientos.dat si hay registros no migrados
    if (-e $archivo_dat && open(my $fh_d, '<:encoding(UTF-8)', $archivo_dat)) {
        my $header = <$fh_d>;
        my $hubo_migracion = 0;
        while (my $line = <$fh_d>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @cols = split(/\|/, $line, -1);
            # Cols: 0:id_cons, 1:id_consul, 2:id_pac, 3:id_med, 4:fecha, 5:procedimiento, 6:payload_json
            next unless scalar(@cols) >= 6;
            if ($cols[2] eq $id_p) {
                my $cid = $cols[0];
                unless ($ids_existentes{$cid}) {
                    my $raw_j = $cols[6] // '{}';
                    $raw_j =~ s/\\n/\n/g;
                    my $parsed_j = eval { decode_json($raw_j) } // {};

                    push @lista, {
                        id_consentimiento => $cid,
                        id_consulta       => $cols[1] || '',
                        id_cirugia        => $parsed_j->{id_cirugia} || '',
                        id_paciente       => $cols[2],
                        id_medico         => $cols[3],
                        nombre_medico     => $parsed_j->{nombre_medico} || '',
                        tipo              => $parsed_j->{tipo_consentimiento} || 'CONSULTA_PROCEDIMIENTO',
                        fecha             => $cols[4] || '',
                        hora              => $parsed_j->{hora_consulta} || '12:00',
                        procedimiento     => $cols[5] || 'Procedimiento Médico',
                        objetivo          => $parsed_j->{procedimiento_objetivo} || '',
                        beneficios        => $parsed_j->{procedimiento_beneficios} || '',
                        riesgos           => $parsed_j->{procedimiento_riesgos} || '',
                        alternativas      => $parsed_j->{procedimiento_alternativas} || '',
                        firmas            => {
                            paciente => $parsed_j->{firma_paciente_data} || '',
                            medico   => $parsed_j->{firma_medico_data} || ''
                        },
                        estado            => 'Firmado'
                    };
                    $ids_existentes{$cid} = 1;
                    $hubo_migracion = 1;
                }
            }
        }
        close($fh_d);

        # Si encontramos registros en el .dat que no estaban en el JSON atómico, persistir el JSON
        if ($hubo_migracion) {
            guardar_json_atomico($id_p, \@lista);
        }
    }

    # Ordenar por fecha y hora descendente (más recientes primero)
    @lista = sort { ($b->{fecha} cmp $a->{fecha}) || ($b->{hora} cmp $a->{hora}) } @lista;
    return \@lista;
}

sub guardar_json_atomico {
    my ($id_p, $lista_ref) = @_;
    my $payload = {
        id_paciente     => $id_p,
        actualizado     => time(),
        consentimientos => $lista_ref
    };
    if (open(my $fh_w, '>:encoding(UTF-8)', $archivo_paciente_json)) {
        flock($fh_w, LOCK_EX);
        print $fh_w encode_json($payload);
        flock($fh_w, LOCK_UN);
        close($fh_w);
        return 1;
    }
    return 0;
}

# --- CONTROLADOR DE ACCIONES ---

if ($accion eq 'list') {
    my $lista = cargar_consentimientos_paciente($id_paciente);
    print encode_json({
        ok => 1,
        id_paciente => $id_paciente,
        total => scalar(@$lista),
        consentimientos => $lista
    });
    exit;
}

if ($accion eq 'get') {
    my $id_c = $q->param('id_consentimiento') || '';
    my $lista = cargar_consentimientos_paciente($id_paciente);
    my ($encontrado) = grep { $_->{id_consentimiento} eq $id_c } @$lista;
    if ($encontrado) {
        print encode_json({ ok => 1, consentimiento => $encontrado });
    } else {
        print encode_json({ ok => 0, error => 'Consentimiento no encontrado' });
    }
    exit;
}

if ($accion eq 'save') {
    my $tipo_cons    = $q->param('tipo_consentimiento') || 'CONSULTA_PROCEDIMIENTO';
    my $proc_desc    = $q->param('procedimiento_descripcion') || 'Procedimiento Médico';
    my $proc_obj     = $q->param('procedimiento_objetivo') || '';
    my $proc_ben     = $q->param('procedimiento_beneficios') || '';
    my $proc_ries    = $q->param('procedimiento_riesgos') || '';
    my $proc_alt     = $q->param('procedimiento_alternativas') || '';
    my $id_cirugia   = $q->param('id_cirugia') || '';
    my $id_consulta  = $q->param('id_consulta') || '';
    my $id_med       = $q->param('id_medico') || $id_medico_sesion || 'DOC-00';
    my $nombre_med   = $q->param('nombre_medico') || $usuario_sesion || 'Médico Especialista';

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $hoy_fecha = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $hoy_hora  = sprintf("%02d:%02d", $hour, $min);

    my $id_cons = $q->param('id_consentimiento') || ('CNS-' . time() . '-' . int(rand(1000)));

    # Procesar firmas en base64
    my %firmas_urls = ( paciente => '', medico => '' );
    foreach my $t ('paciente', 'medico') {
        my $b64 = $q->param("firma_${t}_data") || '';
        if ($b64 =~ /^data:image\/(png|jpeg);base64,(.*)$/) {
            my $ext = $1;
            my $base64 = $2;
            my $img_data = decode_base64($base64);
            my $fname = "${id_cons}_${t}.${ext}";
            my $fpath = File::Spec->catfile($firmas_dir, $fname);
            if (open my $fh_img, '>:raw', $fpath) {
                print $fh_img $img_data;
                close $fh_img;
                $firmas_urls{$t} = "uploads/firmas/$fname";
            }
        } elsif ($b64 =~ m{^uploads/}) {
            $firmas_urls{$t} = $b64;
        }
    }

    my $nuevo_item = {
        id_consentimiento => $id_cons,
        id_consulta       => $id_consulta,
        id_cirugia        => $id_cirugia,
        id_paciente       => $id_paciente,
        id_medico         => $id_med,
        nombre_medico     => $nombre_med,
        tipo              => $tipo_cons,
        fecha             => $hoy_fecha,
        hora              => $hoy_hora,
        procedimiento     => $proc_desc,
        objetivo          => $proc_obj,
        beneficios        => $proc_ben,
        riesgos           => $proc_ries,
        alternativas      => $proc_alt,
        firmas            => \%firmas_urls,
        estado            => 'Firmado'
    };

    # 1. Guardar en JSON Atómico
    my $lista = cargar_consentimientos_paciente($id_paciente);
    my @filtrada = grep { $_->{id_consentimiento} ne $id_cons } @$lista;
    unshift @filtrada, $nuevo_item;
    guardar_json_atomico($id_paciente, \@filtrada);

    # 2. Sincronizar en consentimientos.dat
    my %full_payload = (
        %$nuevo_item,
        procedimiento_descripcion => $proc_desc,
        procedimiento_objetivo    => $proc_obj,
        procedimiento_beneficios  => $proc_ben,
        procedimiento_riesgos     => $proc_ries,
        procedimiento_alternativas=> $proc_alt,
        firma_paciente_data       => $firmas_urls{paciente},
        firma_medico_data         => $firmas_urls{medico},
        requiere_consentimiento   => '1'
    );
    my $json_payload_str = encode_json(\%full_payload);
    $json_payload_str =~ s/\r|\n/\\n/g;

    my $cons_cabecera = "id_consentimiento|id_consulta|id_paciente|id_medico|fecha|procedimiento|payload_json";
    my @lineas_dat = ();
    my $reemplazado = 0;
    if (-e $archivo_dat && open(my $fh_dat, '<:encoding(UTF-8)', $archivo_dat)) {
        my $h = <$fh_dat>;
        $cons_cabecera = $h ? $h : "$cons_cabecera\n";
        chomp $cons_cabecera;
        while (my $l = <$fh_dat>) {
            chomp $l;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            if ($c[0] eq $id_cons || ($id_consulta && $c[1] eq $id_consulta)) {
                push @lineas_dat, join('|', $id_cons, $id_consulta, $id_paciente, $id_med, $hoy_fecha, $proc_desc, $json_payload_str);
                $reemplazado = 1;
            } else {
                push @lineas_dat, $l;
            }
        }
        close($fh_dat);
    }
    push @lineas_dat, join('|', $id_cons, $id_consulta, $id_paciente, $id_med, $hoy_fecha, $proc_desc, $json_payload_str) unless $reemplazado;
    utils::db_manager::actualizar_archivo($archivo_dat, $cons_cabecera, \@lineas_dat);

    print encode_json({
        ok => 1,
        msg => 'Consentimiento informado guardado correctamente',
        id_consentimiento => $id_cons,
        consentimiento => $nuevo_item
    });
    exit;
}

if ($accion eq 'delete') {
    my $id_c = $q->param('id_consentimiento') || '';
    if (!$id_c) {
        print encode_json({ ok => 0, error => 'ID de consentimiento requerido' });
        exit;
    }

    # Purgar en JSON atómico
    my $lista = cargar_consentimientos_paciente($id_paciente);
    my @filtrada = grep { $_->{id_consentimiento} ne $id_c } @$lista;
    guardar_json_atomico($id_paciente, \@filtrada);

    # Purgar en consentimientos.dat
    if (-e $archivo_dat && open(my $fh_dat, '<:encoding(UTF-8)', $archivo_dat)) {
        my $cons_cabecera = <$fh_dat>;
        chomp $cons_cabecera;
        my @lineas_dat = ();
        while (my $l = <$fh_dat>) {
            chomp $l;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            next if $c[0] eq $id_c;
            push @lineas_dat, $l;
        }
        close($fh_dat);
        utils::db_manager::actualizar_archivo($archivo_dat, $cons_cabecera, \@lineas_dat);
    }

    print encode_json({ ok => 1, msg => 'Consentimiento revocado/eliminado exitosamente' });
    exit;
}

print encode_json({ ok => 0, error => 'Acción no reconocida' });
1;
