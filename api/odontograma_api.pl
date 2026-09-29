#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use File::Spec;
use FindBin;
use Fcntl qw(:flock);
use lib "$FindBin::Bin/..";
use POSIX qw(strftime);
use utils::db_manager qw(leer_tabla actualizar_archivo);

my $q = CGI->new;
my $accion = $q->param('accion') || 'get';
my $id_paciente = $q->param('id_paciente') || '';
$id_paciente =~ s/[^\w\-]//g; # Sanitizar ID

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$id_paciente) {
    print encode_json({ ok => 0, msg => 'ID de paciente requerido' });
    exit;
}

my $dir_json = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'odontogramas');
unless (-d $dir_json) {
    mkdir $dir_json, 0755;
}
my $archivo_paciente_json = File::Spec->catfile($dir_json, "paciente_${id_paciente}.json");
my $archivo_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');

if ($accion eq 'save') {
    my $json_raw = $q->param('data') || '{}';
    my $parsed_data = eval { decode_json($json_raw) } || {};
    
    # Determinar si pasaron el objeto completo o solo el hash de dientes
    my $teeth_hash = {};
    if (ref($parsed_data) eq 'HASH') {
        if (exists $parsed_data->{teeth} && ref($parsed_data->{teeth}) eq 'HASH') {
            $teeth_hash = $parsed_data->{teeth};
        } else {
            $teeth_hash = $parsed_data;
        }
    }

    my $notas_text = $q->param('notas') // ($parsed_data->{notas} || '');
    my $financial_pending = $q->param('financialTotalPending');
    if (!defined $financial_pending && ref($parsed_data) eq 'HASH' && defined $parsed_data->{financialTotalPending}) {
        $financial_pending = $parsed_data->{financialTotalPending};
    }
    $financial_pending = sprintf("%.2f", $financial_pending || 0);

    my $periodontal = (ref($parsed_data) eq 'HASH' && ref($parsed_data->{periodontalSummary}) eq 'HASH')
        ? $parsed_data->{periodontalSummary}
        : { bleedingOnProbing => JSON::false, maxProbingDepthMm => 0 };

    my $iso_now = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);
    my $fecha_fmt = strftime("%d/%m/%Y %H:%M:%S", localtime);

    # Estructura canónica según docs/odontograma_plus.md
    my $canonical_record = {
        patientId             => $id_paciente,
        updatedAt             => $iso_now,
        fechaLocal            => $fecha_fmt,
        dentitionType         => 'PERMANENT',
        teeth                 => $teeth_hash,
        periodontalSummary    => $periodontal,
        financialTotalPending => $financial_pending + 0,
        notas                 => $notas_text,
    };

    # 1. Escritura Atómica en JSON del Paciente con FLOCK EXCLUSIVO
    my $json_salida = eval {
        my $coder = JSON->new->utf8->pretty(1);
        $coder->encode($canonical_record);
    } || '{}';

    my $write_ok = 0;
    if (open my $fh_json, '>', $archivo_paciente_json) {
        if (flock($fh_json, LOCK_EX)) {
            binmode $fh_json, ':raw';
            print $fh_json $json_salida;
            flock($fh_json, LOCK_UN);
            $write_ok = 1;
        }
        close $fh_json;
    }

    # 2. Sincronización en dat/odontogramas.dat para índices y reportes globales
    my $notas_dat = $notas_text;
    $notas_dat =~ s/\|/ /g;
    $notas_dat =~ s/\r?\n/ /g;

    my @adult_cols;
    my @child_cols;
    foreach my $tooth (sort keys %$teeth_hash) {
        my $val = encode_json($teeth_hash->{$tooth});
        if ($tooth =~ /^[1234][1-8]$/) {
            push @adult_cols, "$tooth=$val";
        } elsif ($tooth =~ /^[5678][1-5]$/) {
            push @child_cols, "$tooth=$val";
        }
    }

    my $adult_line = join('|', $id_paciente, 'adulto', $fecha_fmt, $notas_dat, @adult_cols);
    my $child_line = join('|', $id_paciente, 'nino', $fecha_fmt, $notas_dat, @child_cols);

    my $registros = leer_tabla($archivo_dat, '\|');
    my @nuevos_registros;
    foreach my $fila (@$registros) {
        if ($fila->[0] ne $id_paciente) {
            push @nuevos_registros, join('|', @$fila);
        }
    }
    push @nuevos_registros, $adult_line;
    push @nuevos_registros, $child_line;

    my $cabecera = "ID_PACIENTE|TIPO|FECHA|NOTAS|DATOS_FDI";
    actualizar_archivo($archivo_dat, $cabecera, \@nuevos_registros);

    if ($write_ok) {
        print encode_json({
            ok        => 1,
            msg       => 'Odontograma guardado con persistencia JSON y tabla FDI exitosa',
            updatedAt => $iso_now,
            fecha     => $fecha_fmt,
            patientId => $id_paciente
        });
    } else {
        print encode_json({
            ok  => 0,
            msg => 'No se pudo escribir en el archivo JSON del paciente (bloqueo fallido)'
        });
    }
} 
else {
    # ACCIÓN: GET (Recuperar Odontograma)
    # Primero: Intentar leer el JSON canónico del paciente con LOCK_SH
    if (-e $archivo_paciente_json) {
        my $json_content = '';
        if (open my $fh_in, '<', $archivo_paciente_json) {
            if (flock($fh_in, LOCK_SH)) {
                local $/;
                $json_content = <$fh_in>;
                flock($fh_in, LOCK_UN);
            }
            close $fh_in;
        }

        if ($json_content) {
            my $parsed = eval { decode_json($json_content) };
            if ($parsed && ref($parsed) eq 'HASH') {
                print encode_json({
                    ok     => 1,
                    source => 'patient_json',
                    data   => $parsed
                });
                exit;
            }
        }
    }

    # Segundo: Fallback a dat/odontogramas.dat si el JSON aún no ha sido creado
    my $registros = leer_tabla($archivo_dat, '\|');
    my %teeth_found = ();
    my $fecha_found = '';
    my $notas_found = '';

    foreach my $fila (@$registros) {
        if ($fila->[0] eq $id_paciente) {
            $fecha_found = $fila->[2] if $fila->[2];
            $notas_found = $fila->[3] if $fila->[3];

            for (my $i = 4; $i < @$fila; $i++) {
                if ($fila->[$i] =~ /^(\d+)=(.+)$/) {
                    my $tooth = $1;
                    my $val_hash = eval { decode_json($2) } || {};
                    $teeth_found{$tooth} = $val_hash;
                }
            }
        }
    }

    my $legacy_adapter = {
        patientId             => $id_paciente,
        updatedAt             => '',
        fechaLocal            => $fecha_found,
        dentitionType         => 'PERMANENT',
        teeth                 => \%teeth_found,
        periodontalSummary    => { bleedingOnProbing => JSON::false, maxProbingDepthMm => 0 },
        financialTotalPending => 0.00,
        notas                 => $notas_found
    };

    print encode_json({
        ok     => 1,
        source => 'dat_table',
        data   => $legacy_adapter
    });
}
