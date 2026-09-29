#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use Encode qw(decode encode);
use File::Spec;
use FindBin;
use Fcntl qw(:flock);
use lib "$FindBin::Bin/..";
use POSIX qw(strftime);
use utils::db_manager qw(leer_tabla actualizar_archivo);

binmode STDOUT, ':raw';

# Helper robusto para obtener parámetros CGI decodificados en UTF-8 limpio
sub param_utf8 {
    my ($cgi, $nombre) = @_;
    my $val = $cgi->param($nombre);
    return '' unless defined $val;
    return utf8::is_utf8($val) ? $val : Encode::decode('UTF-8', $val);
}

my $q = CGI->new;
my $accion = param_utf8($q, 'accion') || 'get';
my $id_paciente = param_utf8($q, 'id_paciente') || '';
$id_paciente =~ s/[^\w\-]//g; # Sanitizar ID

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$id_paciente) {
    print encode_json({ ok => 0, error => 'ID de paciente requerido' });
    exit;
}

my $dir_json = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'odontogramas');
unless (-d $dir_json) {
    mkdir $dir_json, 0755;
}
my $archivo_paciente_json = File::Spec->catfile($dir_json, "paciente_${id_paciente}.json");
my $archivo_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');

# Función para sanear cadenas con posible mojibake previo (ej. doble o triple codificación UTF-8)
sub sanear_texto_mojibake {
    my ($txt) = @_;
    return '' unless defined $txt;
    $txt =~ s/ÃƒÂ­/í/g;
    $txt =~ s/Ã­/í/g;
    $txt =~ s/Ã³/ó/g;
    $txt =~ s/Ã¡/á/g;
    $txt =~ s/Ã©/é/g;
    $txt =~ s/Ãº/ú/g;
    $txt =~ s/Ã±/ñ/g;
    $txt =~ s/Ã/Á/g;
    $txt =~ s/Ã‰/É/g;
    $txt =~ s/Ã/Í/g;
    $txt =~ s/Ã“/Ó/g;
    $txt =~ s/Ãš/Ú/g;
    $txt =~ s/Ã‘/Ñ/g;
    return $txt;
}

# Función para cargar la estructura del paciente (con migración transparente)
sub cargar_perfil_odontologia {
    my $record = {
        patientId             => $id_paciente,
        updatedAt             => '',
        dentitionType         => 'PERMANENT',
        odontogramas          => [],
    };

    if (-e $archivo_paciente_json) {
        my $json_content = '';
        if (open my $fh_in, '<:raw', $archivo_paciente_json) {
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
                if (exists $parsed->{odontogramas} && ref($parsed->{odontogramas}) eq 'ARRAY') {
                    foreach my $od (@{ $parsed->{odontogramas} }) {
                        $od->{alias} = sanear_texto_mojibake($od->{alias}) if defined $od->{alias};
                        $od->{notas} = sanear_texto_mojibake($od->{notas}) if defined $od->{notas};
                    }
                    return $parsed;
                } elsif (exists $parsed->{teeth} && ref($parsed->{teeth}) eq 'HASH') {
                    # Migración al vuelo de registro plano anterior a colección con Alias
                    my $od_legacy = {
                        id_odonto             => "OD-${id_paciente}-1",
                        alias                 => sanear_texto_mojibake($parsed->{alias}) || 'Diagnóstico Inicial',
                        fecha                 => $parsed->{fechaLocal} || $parsed->{updatedAt} || strftime("%d/%m/%Y %H:%M:%S", localtime),
                        estado                => $parsed->{estado} || 'En Proceso',
                        importe               => $parsed->{financialTotalPending} || 0,
                        notas                 => sanear_texto_mojibake($parsed->{notas}) || '',
                        teeth                 => $parsed->{teeth} || {},
                        periodontalSummary    => $parsed->{periodontalSummary} || { bleedingOnProbing => JSON::false, maxProbingDepthMm => 0 }
                    };
                    $record->{odontogramas} = [ $od_legacy ];
                    $record->{updatedAt} = $parsed->{updatedAt} || '';
                    return $record;
                }
            }
        }
    }

    # Fallback si no hay JSON: intentar leer desde odontogramas.dat
    my $registros = leer_tabla($archivo_dat, '\|');
    my %teeth_found;
    my $fecha_found = '';
    my $notas_found = '';
    foreach my $fila (@$registros) {
        if ($fila->[0] eq $id_paciente) {
            $fecha_found = $fila->[2] if $fila->[2];
            $notas_found = sanear_texto_mojibake($fila->[3]) if $fila->[3];
            for (my $i = 4; $i < @$fila; $i++) {
                if ($fila->[$i] =~ /^(\d+)=(.+)$/) {
                    my $tooth = $1;
                    my $raw_t = Encode::encode('UTF-8', $2);
                    my $val_hash = eval { decode_json($raw_t) } || {};
                    $teeth_found{$tooth} = $val_hash;
                }
            }
        }
    }

    if (%teeth_found) {
        my $od_dat = {
            id_odonto          => "OD-${id_paciente}-1",
            alias              => 'Diagnóstico Base',
            fecha              => $fecha_found || strftime("%d/%m/%Y %H:%M:%S", localtime),
            estado             => 'En Proceso',
            importe            => 0.00,
            notas              => $notas_found,
            teeth              => \%teeth_found,
            periodontalSummary => { bleedingOnProbing => JSON::false, maxProbingDepthMm => 0 }
        };
        $record->{odontogramas} = [ $od_dat ];
    }

    return $record;
}

# Función para persistir atómicamente la estructura del paciente y sincronizar tabla .dat
sub guardar_perfil_odontologia {
    my ($perfil) = @_;
    $perfil->{updatedAt} = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime);

    # Serializar a octetos UTF-8 puros para almacenamiento JSON
    my $coder = JSON->new->utf8(1)->pretty(1)->canonical(1);
    my $json_salida = eval { $coder->encode($perfil) } || '{}';

    # 1. Escritura atómica con LOCK_EX en modo :raw para preservar bytes UTF-8 exactos sin doble encoding
    if (open my $fh_out, '>:raw', $archivo_paciente_json) {
        if (flock($fh_out, LOCK_EX)) {
            print $fh_out $json_salida;
            flock($fh_out, LOCK_UN);
        }
        close $fh_out;
    }

    # 2. Sincronización en dat/odontogramas.dat (manteniendo filas de otros pacientes)
    my $registros = leer_tabla($archivo_dat, '\|');
    my @nuevos_registros;
    foreach my $fila (@$registros) {
        if ($fila->[0] ne $id_paciente) {
            push @nuevos_registros, join('|', @$fila);
        }
    }

    # Agregar filas de los odontogramas de este paciente
    foreach my $od (@{ $perfil->{odontogramas} }) {
        my $notas_clean = $od->{notas} || '';
        $notas_clean =~ s/\|/ /g;
        $notas_clean =~ s/\r?\n/ /g;

        my @cols_teeth;
        if (ref($od->{teeth}) eq 'HASH') {
            foreach my $t (sort keys %{ $od->{teeth} }) {
                # JSON como cadena de texto plano compatible con actualizar_archivo (:encoding(UTF-8))
                my $encoded = eval { JSON->new->utf8(0)->encode($od->{teeth}->{$t}) } || '{}';
                push @cols_teeth, "$t=$encoded";
            }
        }
        # Formato: ID_PACIENTE|ID_ODONTO|FECHA|NOTAS|DATOS_FDI...
        my $linea = join('|', $id_paciente, ($od->{id_odonto} || 'adulto'), ($od->{fecha} || ''), $notas_clean, @cols_teeth);
        push @nuevos_registros, $linea;
    }

    my $cabecera = 'ID_PACIENTE|TIPO|FECHA|NOTAS|DATOS_FDI';
    actualizar_archivo($archivo_dat, $cabecera, \@nuevos_registros);
    return 1;
}

eval {
    # -------------------------------------------------------------
    # ACCIÓN: LIST (Listado de Odontogramas para DataTable Maestro)
    # -------------------------------------------------------------
    if ($accion eq 'list') {
        my $perfil = cargar_perfil_odontologia();
        my @listado;
        foreach my $od (@{ $perfil->{odontogramas} }) {
            my $cnt_piezas = 0;
            if (ref($od->{teeth}) eq 'HASH') {
                $cnt_piezas = scalar(keys %{ $od->{teeth} });
            }
            push @listado, {
                id_odonto => $od->{id_odonto},
                alias     => $od->{alias} || 'Odontograma General',
                fecha     => $od->{fecha} || '',
                estado    => $od->{estado} || 'En Proceso',
                importe   => sprintf("%.2f", $od->{importe} || 0),
                notas     => $od->{notas} || '',
                piezas    => $cnt_piezas,
            };
        }
        print encode_json({ ok => 1, data => \@listado });
        exit;
    }

    # -------------------------------------------------------------
    # ACCIÓN: GET (Obtener un Odontograma Específico o el más reciente)
    # -------------------------------------------------------------
    elsif ($accion eq 'get') {
        my $id_odonto_req = $q->param('id_odonto') || '';
        my $perfil = cargar_perfil_odontologia();
        my $encontrado = undef;

        if ($id_odonto_req) {
            foreach my $od (@{ $perfil->{odontogramas} }) {
                if ($od->{id_odonto} eq $id_odonto_req) {
                    $encontrado = $od;
                    last;
                }
            }
        }

        # Si no se encontró por ID o no se envió ID, tomar el primero disponible
        if (!$encontrado && @{ $perfil->{odontogramas} }) {
            $encontrado = $perfil->{odontogramas}->[0];
        }

        # Si todavía no hay odontogramas, retornar plantilla vacía
        if (!$encontrado) {
            $encontrado = {
                id_odonto          => "OD-${id_paciente}-1",
                alias              => 'Diagnóstico Inicial',
                fecha              => strftime("%d/%m/%Y %H:%M:%S", localtime),
                estado             => 'En Proceso',
                importe            => 0.00,
                notas              => '',
                teeth              => {},
                periodontalSummary => { bleedingOnProbing => JSON::false, maxProbingDepthMm => 0 }
            };
        }

        print encode_json({
            ok        => 1,
            patientId => $id_paciente,
            data      => $encontrado,
        });
        exit;
    }

    # -------------------------------------------------------------
    # ACCIÓN: SAVE (Crear o Actualizar un Odontograma con Alias)
    # -------------------------------------------------------------
    elsif ($accion eq 'save') {
        my $id_odonto_req = param_utf8($q, 'id_odonto');
        my $alias_req     = sanear_texto_mojibake(param_utf8($q, 'alias'));
        my $estado_req    = param_utf8($q, 'estado') || 'En Proceso';
        my $notas_req     = sanear_texto_mojibake(param_utf8($q, 'notas'));
        my $imp_req       = $q->param('financialTotalPending') // $q->param('importe') // 0;
        my $json_raw      = param_utf8($q, 'data') || '{}';
        my $parsed_teeth  = eval { decode_json(Encode::encode('UTF-8', $json_raw)) } || {};

        # Si pasaron el objeto envuelto con .teeth
        if (ref($parsed_teeth) eq 'HASH' && exists $parsed_teeth->{teeth}) {
            $parsed_teeth = $parsed_teeth->{teeth};
        }

        my $perfil = cargar_perfil_odontologia();
        my $now_str = strftime("%d/%m/%Y %H:%M:%S", localtime);
        my $target_od = undef;

        if ($id_odonto_req && $id_odonto_req ne 'new') {
            foreach my $od (@{ $perfil->{odontogramas} }) {
                if ($od->{id_odonto} eq $id_odonto_req) {
                    $target_od = $od;
                    last;
                }
            }
        }

        if ($target_od) {
            # Actualizar existente
            $target_od->{alias}   = $alias_req if ($alias_req ne '');
            $target_od->{estado}  = $estado_req;
            $target_od->{fecha}   = $now_str;
            $target_od->{notas}   = $notas_req;
            $target_od->{importe} = sprintf("%.2f", $imp_req) + 0;
            $target_od->{teeth}   = $parsed_teeth if (ref($parsed_teeth) eq 'HASH' && %$parsed_teeth);
        } else {
            # Crear nuevo odontograma
            my $nuevo_idx = scalar(@{ $perfil->{odontogramas} }) + 1;
            my $nuevo_id = "OD-${id_paciente}-${nuevo_idx}_" . time();
            $alias_req ||= "Odontograma #" . $nuevo_idx;

            $target_od = {
                id_odonto          => $nuevo_id,
                alias              => $alias_req,
                fecha              => $now_str,
                estado             => $estado_req,
                importe            => sprintf("%.2f", $imp_req) + 0,
                notas              => $notas_req,
                teeth              => $parsed_teeth,
                periodontalSummary => { bleedingOnProbing => JSON::false, maxProbingDepthMm => 0 }
            };
            unshift @{ $perfil->{odontogramas} }, $target_od;
        }

        guardar_perfil_odontologia($perfil);

        print encode_json({
            ok        => 1,
            msg       => 'Odontograma guardado con éxito',
            id_odonto => $target_od->{id_odonto},
            alias     => $target_od->{alias},
            fecha     => $target_od->{fecha}
        });
        exit;
    }

    # -------------------------------------------------------------
    # ACCIÓN: RENAME (Modificar Alias, Estado o Notas de un Odontograma)
    # -------------------------------------------------------------
    elsif ($accion eq 'rename') {
        my $id_odonto_req = param_utf8($q, 'id_odonto');
        my $nuevo_alias   = sanear_texto_mojibake(param_utf8($q, 'alias'));
        my $nuevo_estado  = param_utf8($q, 'estado');
        my $nuevas_notas  = sanear_texto_mojibake(param_utf8($q, 'notas'));

        if (!$id_odonto_req || !$nuevo_alias) {
            print encode_json({ ok => 0, error => 'ID de odontograma y nuevo alias son requeridos' });
            exit;
        }

        my $perfil = cargar_perfil_odontologia();
        my $modificado = 0;
        foreach my $od (@{ $perfil->{odontogramas} }) {
            if ($od->{id_odonto} eq $id_odonto_req) {
                $od->{alias} = $nuevo_alias;
                $od->{estado} = $nuevo_estado if ($nuevo_estado ne '');
                $od->{notas} = $nuevas_notas if defined($nuevas_notas);
                $od->{fecha} = strftime("%d/%m/%Y %H:%M:%S", localtime);
                $modificado = 1;
                last;
            }
        }

        if ($modificado) {
            guardar_perfil_odontologia($perfil);
            print encode_json({ ok => 1, msg => 'Odontograma actualizado con éxito' });
        } else {
            print encode_json({ ok => 0, error => 'Odontograma no encontrado' });
        }
        exit;
    }

    # -------------------------------------------------------------
    # ACCIÓN: CLONE (Clonar un Odontograma para Evolución Clínica)
    # -------------------------------------------------------------
    elsif ($accion eq 'clone') {
        my $id_odonto_fuente = param_utf8($q, 'id_odonto');
        my $nuevo_alias      = sanear_texto_mojibake(param_utf8($q, 'alias'));
        
        my $perfil = cargar_perfil_odontologia();
        my $od_fuente = undef;

        if ($id_odonto_fuente) {
            foreach my $od (@{ $perfil->{odontogramas} }) {
                if ($od->{id_odonto} eq $id_odonto_fuente) {
                    $od_fuente = $od;
                    last;
                }
            }
        }
        if (!$od_fuente && @{ $perfil->{odontogramas} }) {
            $od_fuente = $perfil->{odontogramas}->[0];
        }

        if (!$od_fuente) {
            print encode_json({ ok => 0, error => 'No se encontró el odontograma base para clonar' });
            exit;
        }

        # Generar nuevo ID único
        my $nuevo_id = "OD-${id_paciente}-" . time() . "_" . int(rand(1000));
        my $alias_final = $nuevo_alias || ('Evolución - ' . strftime("%d/%m/%Y %H:%M", localtime));
        my $fecha_actual = strftime("%d/%m/%Y %H:%M:%S", localtime);

        # Clonar datos profundos de dientes y periodontal
        my $raw_teeth = eval { JSON->new->utf8(0)->encode($od_fuente->{teeth} || {}) } || '{}';
        my $cloned_teeth = eval { JSON->new->utf8(0)->decode($raw_teeth) } || {};

        my $raw_periodontal = eval { JSON->new->utf8(0)->encode($od_fuente->{periodontalSummary} || {}) } || '{}';
        my $cloned_periodontal = eval { JSON->new->utf8(0)->decode($raw_periodontal) } || {};

        my $nuevo_od = {
            id_odonto          => $nuevo_id,
            alias              => $alias_final,
            fecha              => $fecha_actual,
            estado             => 'En Proceso',
            importe            => $od_fuente->{importe} || 0,
            notas              => 'Evolución clínica derivada de ' . ($od_fuente->{alias} || 'Odontograma Base'),
            teeth              => $cloned_teeth,
            periodontalSummary => $cloned_periodontal
        };

        # Insertar al inicio de la lista
        unshift @{ $perfil->{odontogramas} }, $nuevo_od;
        guardar_perfil_odontologia($perfil);

        print encode_json({
            ok        => 1,
            msg       => 'Evolución dental creada con éxito',
            id_odonto => $nuevo_id,
            alias     => $alias_final,
            data      => $nuevo_od
        });
        exit;
    }

    # -------------------------------------------------------------
    # ACCIÓN: SET_STATUS (Cambiar Estado de un Odontograma)
    # -------------------------------------------------------------
    elsif ($accion eq 'set_status') {
        my $id_odonto_req = param_utf8($q, 'id_odonto');
        my $nuevo_estado  = param_utf8($q, 'estado') || 'Finalizado';

        if (!$id_odonto_req) {
            print encode_json({ ok => 0, error => 'ID de odontograma requerido' });
            exit;
        }

        my $perfil = cargar_perfil_odontologia();
        my $modificado = 0;
        foreach my $od (@{ $perfil->{odontogramas} }) {
            if ($od->{id_odonto} eq $id_odonto_req) {
                $od->{estado} = $nuevo_estado;
                $od->{fecha} = strftime("%d/%m/%Y %H:%M:%S", localtime);
                $modificado = 1;
                last;
            }
        }

        if ($modificado) {
            guardar_perfil_odontologia($perfil);
            print encode_json({ ok => 1, msg => "Estado actualizado a $nuevo_estado" });
        } else {
            print encode_json({ ok => 0, error => 'Odontograma no encontrado' });
        }
        exit;
    }

    # -------------------------------------------------------------
    # ACCIÓN: GET_TREATMENTS (Extraer Conceptos y Presupuesto Pendiente)
    # -------------------------------------------------------------
    elsif ($accion eq 'get_treatments') {
        my $id_odonto_req = param_utf8($q, 'id_odonto');
        my $perfil = cargar_perfil_odontologia();
        my $od_target = undef;

        if ($id_odonto_req) {
            foreach my $od (@{ $perfil->{odontogramas} }) {
                if ($od->{id_odonto} eq $id_odonto_req) {
                    $od_target = $od;
                    last;
                }
            }
        }
        if (!$od_target && @{ $perfil->{odontogramas} }) {
            $od_target = $perfil->{odontogramas}->[0];
        }

        my %PRECIOS_REF = (
            CARIES           => { nom => 'Caries Dental (Activa)',      cat => 'PENDING',  precio => 850.00 },
            CARIES_RECURRENT => { nom => 'Caries Recurrente',           cat => 'PENDING',  precio => 950.00 },
            FRACTURE         => { nom => 'Fractura Dental',             cat => 'PENDING',  precio => 1200.00 },
            SEALANT_REQ      => { nom => 'Sellador Requerido',          cat => 'PENDING',  precio => 450.00 },
            CROWN_REQ        => { nom => 'Corona Requerida',            cat => 'PENDING',  precio => 3500.00 },
            ENDO_REQ         => { nom => 'Endodoncia Indicada',         cat => 'PENDING',  precio => 2800.00 },
            EXO_REQ          => { nom => 'Exodoncia Requerida',         cat => 'PENDING',  precio => 1100.00 },
            EXTRACTION_REQ   => { nom => 'Exodoncia Requerida',         cat => 'PENDING',  precio => 1100.00 },
            COMPOSITE        => { nom => 'Obturación con Resina',       cat => 'EXISTING', precio => 850.00 },
            AMALGAM          => { nom => 'Obturación con Amalgama',     cat => 'EXISTING', precio => 700.00 },
            CROWN_DONE       => { nom => 'Corona Existente',            cat => 'EXISTING', precio => 3500.00 },
            ENDO_DONE        => { nom => 'Endodoncia Realizada',        cat => 'EXISTING', precio => 2800.00 },
            IMPLANT          => { nom => 'Implante Dental',             cat => 'EXISTING', precio => 14000.00 },
            ABSENT           => { nom => 'Pieza Ausente',               cat => 'EXISTING', precio => 0.00 },
        );

        my @items_tratamiento;
        my $total_presupuesto = 0.00;

        if ($od_target && ref($od_target->{teeth}) eq 'HASH') {
            my $teeth_map = $od_target->{teeth};
            foreach my $t_num (sort { $a <=> $b } keys %$teeth_map) {
                my $t_data = $teeth_map->{$t_num};
                next unless ref($t_data) eq 'HASH';

                if ($t_data->{status} && $t_data->{status} eq 'EXTRACTION_REQUIRED') {
                    push @items_tratamiento, {
                        id       => "OD-T-$t_num-EXO",
                        pieza    => $t_num,
                        nombre   => "Exodoncia Dental - Pieza #$t_num",
                        precio   => 1100.00,
                        cantidad => 1,
                        subtotal => 1100.00
                    };
                    $total_presupuesto += 1100.00;
                }

                if ($t_data->{surfaces} && ref($t_data->{surfaces}) eq 'HASH') {
                    foreach my $surf (keys %{$t_data->{surfaces}}) {
                        my $item = $t_data->{surfaces}->{$surf};
                        my $code = ref($item) eq 'HASH' ? ($item->{code} || 'CARIES') : $item;
                        my $info = $PRECIOS_REF{$code} || { nom => $code, cat => 'PENDING', precio => 850.00 };
                        my $costo = (ref($item) eq 'HASH' && defined($item->{price})) ? $item->{price} + 0 : $info->{precio};
                        
                        if ($info->{cat} eq 'PENDING') {
                            push @items_tratamiento, {
                                id       => "OD-T-$t_num-" . lc($surf),
                                pieza    => $t_num,
                                cara     => ucfirst($surf),
                                nombre   => "$info->{nom} (" . ucfirst($surf) . ") - Pieza #$t_num",
                                precio   => $costo,
                                cantidad => 1,
                                subtotal => $costo
                            };
                            $total_presupuesto += $costo;
                        }
                    }
                } elsif (ref($t_data) eq 'HASH') {
                    foreach my $surf (keys %$t_data) {
                        next if $surf eq 'absent' || $surf eq 'surfaces' || $surf eq 'status';
                        my $code = $t_data->{$surf};
                        my $info = $PRECIOS_REF{$code} || { nom => $code, cat => 'PENDING', precio => 850.00 };
                        if ($info->{cat} eq 'PENDING') {
                            push @items_tratamiento, {
                                id       => "OD-T-$t_num-" . lc($surf),
                                pieza    => $t_num,
                                cara     => ucfirst($surf),
                                nombre   => "$info->{nom} (" . ucfirst($surf) . ") - Pieza #$t_num",
                                precio   => $info->{precio},
                                cantidad => 1,
                                subtotal => $info->{precio}
                            };
                            $total_presupuesto += $info->{precio};
                        }
                    }
                }
            }
        }

        # Si el importe del odontograma estaba precalculado y no hubo desglose detallado
        if (!@items_tratamiento && $od_target && ($od_target->{importe} || 0) > 0) {
            push @items_tratamiento, {
                id       => "OD-T-GLOBAL",
                nombre   => "Tratamientos Odontológicos (" . ($od_target->{alias} || 'Odontograma') . ")",
                precio   => $od_target->{importe} + 0,
                cantidad => 1,
                subtotal => $od_target->{importe} + 0
            };
            $total_presupuesto = $od_target->{importe} + 0;
        }

        print encode_json({
            ok        => 1,
            id_odonto => $od_target ? $od_target->{id_odonto} : '',
            alias     => $od_target ? $od_target->{alias} : '',
            items     => \@items_tratamiento,
            total     => sprintf("%.2f", $total_presupuesto)
        });
        exit;
    }

    # -------------------------------------------------------------
    # ACCIÓN: DELETE (Eliminar un Odontograma Específico)
    # -------------------------------------------------------------
    elsif ($accion eq 'delete') {
        my $id_odonto_req = param_utf8($q, 'id_odonto');
        if (!$id_odonto_req) {
            print encode_json({ ok => 0, error => 'ID de odontograma requerido' });
            exit;
        }

        my $perfil = cargar_perfil_odontologia();
        my @conservar;
        my $eliminado = 0;
        foreach my $od (@{ $perfil->{odontogramas} }) {
            if ($od->{id_odonto} eq $id_odonto_req) {
                $eliminado = 1;
            } else {
                push @conservar, $od;
            }
        }

        if ($eliminado) {
            $perfil->{odontogramas} = \@conservar;
            guardar_perfil_odontologia($perfil);
            print encode_json({ ok => 1, msg => 'Odontograma eliminado con éxito' });
        } else {
            print encode_json({ ok => 0, error => 'El odontograma especificado no existe' });
        }
        exit;
    }

    else {
        print encode_json({ ok => 0, error => "Acción desconocida: $accion" });
        exit;
    }
};

# Error 500 Guard
if ($@) {
    print encode_json({
        ok    => 0,
        error => "Error 500 interno en API Odontograma: $@"
    });
}
1;
