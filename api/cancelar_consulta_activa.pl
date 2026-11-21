#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(actualizar_archivo);
use JSON::PP;

my $q = CGI->new;
my $session_data = check_session($q);

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDIN,  ":encoding(UTF-8)");

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($session_data && $session_data->{session_ok}) {
    print JSON::PP->new->utf8(0)->encode({ ok => JSON::PP::false, msg => 'Sesión expirada o no autorizada.' });
    exit;
}

my $id_cita     = $q->param('id_cita') // '';
my $id_paciente = $q->param('id_paciente') // '';
$id_cita     =~ s/[^\w\-]//g;
$id_paciente =~ s/[^\w\-]//g;

unless ($id_paciente || $id_cita) {
    print JSON::PP->new->utf8(0)->encode({ ok => JSON::PP::false, msg => 'Parámetros id_cita o id_paciente requeridos.' });
    exit;
}

eval {
    my $dat_dir      = File::Spec->catfile($FindBin::Bin, '..', 'dat');
    my $draft_file   = File::Spec->catfile($dat_dir, 'consulta_draft.dat');
    my $citas_file   = File::Spec->catfile($dat_dir, 'citas.dat');
    my $consent_file = File::Spec->catfile($dat_dir, 'consentimientos.dat');
    my $cotiz_file   = File::Spec->catfile($dat_dir, 'cotizaciones.dat');

    my $payload = {};
    my $id_draft_target = $id_paciente ? "DRAFT-$id_paciente" : '';

    # 1. Extraer información del borrador para conocer documentos ligados
    if (-e $draft_file && open my $fh_d, '<:encoding(UTF-8)', $draft_file) {
        my $hdr = <$fh_d>;
        while (my $l = <$fh_d>) {
            chomp $l;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $match = 0;
            if ($id_draft_target && $c[0] eq $id_draft_target) {
                $match = 1;
            } elsif ($id_cita && $c[2] eq $id_cita) {
                $match = 1;
            }
            if ($match && $c[5]) {
                my $decoded = eval { JSON::PP->new->utf8(0)->decode($c[5]) };
                $payload = $decoded if $decoded;
                last;
            }
        }
        close $fh_d;
    }

    # 2. Purgar documentos generados o vinculados durante la consulta activa (REGLA 4)
    my $id_consentimiento_vinculado = $payload->{id_consentimiento_vinculado} || '';
    my $id_cotizacion               = $payload->{id_cotizacion} || '';

    # 2a. Desvincular o eliminar Consentimiento Informado si fue creado para esta consulta
    if ($id_consentimiento_vinculado && -e $consent_file) {
        my @nuevas_lineas_cons;
        my $cons_hdr = "id_consentimiento|id_consulta|id_paciente|id_medico|fecha|procedimiento|payload_json";
        if (open my $fh_c, '<:encoding(UTF-8)', $consent_file) {
            my $first = <$fh_c>;
            $cons_hdr = $first if $first;
            chomp $cons_hdr;
            while (my $line = <$fh_c>) {
                chomp $line;
                next if $line =~ /^\s*$/;
                my @p = split(/\|/, $line, -1);
                if ($p[0] eq $id_consentimiento_vinculado) {
                    # Si el consentimiento pertenece a esta cita o no tiene id_consulta cerrada definitiva,
                    # lo eliminamos o liberamos para no dejar huérfanos
                    my $cons_payload = eval { JSON::PP->new->utf8(0)->decode($p[6] || '{}') } || {};
                    my $c_id_cita = $cons_payload->{id_cita} || '';
                    my $c_id_cons = $p[1] || '';
                    if ($c_id_cita eq $id_cita || !$c_id_cons || $c_id_cons =~ /^CONS-/i) {
                        # Eliminar firmas asociadas en disco si existen
                        my $uploads_dir = File::Spec->catfile($FindBin::Bin, '..', 'uploads', 'firmas');
                        my $f_med = File::Spec->catfile($uploads_dir, "${id_consentimiento_vinculado}_medico.png");
                        my $f_pac = File::Spec->catfile($uploads_dir, "${id_consentimiento_vinculado}_paciente.png");
                        unlink $f_med if -e $f_med;
                        unlink $f_pac if -e $f_pac;
                        # Omitir de la lista para eliminarlo
                        next;
                    } else {
                        # Si era un consentimiento histórico previo, solo desvincular
                        $p[1] = '';
                        $line = join('|', @p);
                    }
                }
                push @nuevas_lineas_cons, $line;
            }
            close $fh_c;
            actualizar_archivo($consent_file, $cons_hdr, \@nuevas_lineas_cons);
        }

        # Limpiar también en el repositorio JSON de paciente (dat/consentimientos/paciente_*.json)
        if ($id_paciente) {
            my $pac_json_file = File::Spec->catfile($dat_dir, 'consentimientos', "paciente_${id_paciente}.json");
            if (-e $pac_json_file && open my $fh_pj, '<:encoding(UTF-8)', $pac_json_file) {
                local $/;
                my $raw_pj = <$fh_pj>;
                close $fh_pj;
                my $pj_data = eval { JSON::PP->new->utf8(0)->decode($raw_pj) };
                if ($pj_data && ref($pj_data->{consentimientos}) eq 'ARRAY') {
                    my @filtered_cons;
                    for my $item (@{$pj_data->{consentimientos}}) {
                        if ($item->{id_consentimiento} eq $id_consentimiento_vinculado) {
                            if (!$item->{id_consulta} || $item->{id_consulta} =~ /^CONS-/i) {
                                next; # Eliminar del JSON
                            } else {
                                $item->{utilizado} = 0;
                                $item->{id_consulta} = '';
                            }
                        }
                        push @filtered_cons, $item;
                    }
                    $pj_data->{consentimientos} = \@filtered_cons;
                    if (open my $fh_pw, '>:encoding(UTF-8)', $pac_json_file) {
                        print $fh_pw JSON::PP->new->utf8(0)->encode($pj_data);
                        close $fh_pw;
                    }
                }
            }
        }
    }

    # 2b. Eliminar o cancelar cotización si fue creada durante el borrador
    if ($id_cotizacion && -e $cotiz_file) {
        my @nuevas_cot;
        my $cot_hdr = "ID_COT|ID_PACIENTE|NOMBRE|TOTAL|FECHA|ID_MEDICO";
        if (open my $fh_ct, '<:encoding(UTF-8)', $cotiz_file) {
            my $first = <$fh_ct>;
            $cot_hdr = $first if $first;
            chomp $cot_hdr;
            while (my $line = <$fh_ct>) {
                chomp $line;
                next if $line =~ /^\s*$/;
                my @p = split(/\|/, $line, -1);
                if ($p[0] eq $id_cotizacion) {
                    # Omitir cotización generada en borrador
                    next;
                }
                push @nuevas_cot, $line;
            }
            close $fh_ct;
            actualizar_archivo($cotiz_file, $cot_hdr, \@nuevas_cot);
        }
    }

    # 3. Eliminar borrador de consulta_draft.dat
    if (-e $draft_file) {
        my @nuevas_lineas_draft;
        my $draft_hdr = "id_draft|id_paciente|id_cita|id_medico|current_step|payload_json|timestamp";
        if (open my $fh_d, '<:encoding(UTF-8)', $draft_file) {
            my $first = <$fh_d>;
            $draft_hdr = $first if $first;
            chomp $draft_hdr;
            while (my $l = <$fh_d>) {
                chomp $l;
                next if $l =~ /^\s*$/;
                my @c = split(/\|/, $l, -1);
                if ($id_draft_target && $c[0] eq $id_draft_target) {
                    next; # Eliminar
                }
                if ($id_cita && $c[2] eq $id_cita) {
                    next; # Eliminar
                }
                push @nuevas_lineas_draft, $l;
            }
            close $fh_d;
            actualizar_archivo($draft_file, $draft_hdr, \@nuevas_lineas_draft);
        }
    }

    # 4. Actualizar estado de la cita en citas.dat
    my $cita_actualizada = 0;
    if ($id_cita && -e $citas_file) {
        my @nuevas_citas;
        my $citas_hdr = "id_cita|id_medico|id_paciente|fecha|hora_ini|hora_fin|motivo|notas|estado|event_id|color|prioridad|sucursal|consultorio|id_negocio|elaborado_por";
        if (open my $fh_ci, '<:encoding(UTF-8)', $citas_file) {
            my $first = <$fh_ci>;
            $citas_hdr = $first if $first;
            chomp $citas_hdr;
            while (my $line = <$fh_ci>) {
                chomp $line;
                next if $line =~ /^\s*$/;
                my @c = split(/\|/, $line, -1);
                if ($c[0] eq $id_cita) {
                    $c[8] = 'Cancelada';
                    $c[7] = ($c[7] ? "$c[7] - " : "") . "[Consulta cancelada y borrador descartado]";
                    $line = join('|', @c);
                    $cita_actualizada = 1;
                }
                push @nuevas_citas, $line;
            }
            close $fh_ci;
            if ($cita_actualizada) {
                actualizar_archivo($citas_file, $citas_hdr, \@nuevas_citas);
            }
        }
    }

    print JSON::PP->new->utf8(0)->encode({
        ok => JSON::PP::true,
        msg => 'Consulta activa cancelada, borrador y documentos creados purgados correctamente.',
        id_cita => $id_cita,
        id_paciente => $id_paciente
    });
};

if ($@) {
    my $err = $@;
    $err =~ s/at \S+ line \d+.*//s;
    print JSON::PP->new->utf8(0)->encode({
        ok => JSON::PP::false,
        msg => "Error al cancelar consulta: $err"
    });
}

exit;
