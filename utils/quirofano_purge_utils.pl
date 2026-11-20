package utils::quirofano_purge_utils;
use strict;
use warnings;
use utf8;
use File::Spec;
use FindBin;
use JSON qw(decode_json encode_json);
use Fcntl qw(:flock);

sub obtener_dat_dir {
    return File::Spec->catdir($FindBin::Bin, '..', 'dat');
}

sub obtener_uploads_firmas_dir {
    return File::Spec->catdir($FindBin::Bin, '..', 'uploads', 'firmas');
}

sub a_minutos_local {
    my ($hhmm) = @_;
    return -1 unless defined $hhmm && $hhmm =~ /^(\d{1,2}):(\d{2})/;
    return int($1) * 60 + int($2);
}

sub escribir_archivo_seguro {
    my ($filepath, $header, $lines_ref) = @_;
    if (open(my $fh, '>:encoding(UTF-8)', $filepath)) {
        flock($fh, LOCK_EX);
        print $fh "$header\n" if defined $header && $header ne '';
        foreach my $l (@$lines_ref) {
            next unless defined $l;
            print $fh "$l\n";
        }
        close($fh);
        return 1;
    }
    return 0;
}

sub restaurar_stock_catalogo_3nf {
    my ($devolver_ref) = @_;
    return 0 unless $devolver_ref && ref($devolver_ref) eq 'HASH' && scalar(keys %$devolver_ref) > 0;

    my $dat_dir  = obtener_dat_dir();
    my $file_ins = File::Spec->catfile($dat_dir, 'quirofano', 'catalogo_insumos.dat');
    return 0 unless -e $file_ins;

    my @lines;
    if (open(my $fh, '<:encoding(UTF-8)', $file_ins)) {
        @lines = <$fh>;
        close($fh);
    }
    return 0 unless @lines;

    my $header = shift @lines;
    chomp $header if defined $header;
    $header =~ s/\r//g if defined $header;

    my $unidades_restauradas = 0;
    my @out;
    foreach my $l (@lines) {
        chomp $l;
        $l =~ s/\r//g;
        next if $l =~ /^\s*$/;
        my @c = split(/\|/, $l, -1);
        my $id_ins = $c[0] // '';
        if ($id_ins ne '' && exists $devolver_ref->{$id_ins} && $devolver_ref->{$id_ins} > 0) {
            my $actual = int($c[7] // 0);
            my $sumar  = int($devolver_ref->{$id_ins});
            $c[7] = $actual + $sumar;
            $unidades_restauradas += $sumar;
            $l = join('|', @c);
        }
        push @out, $l;
    }

    escribir_archivo_seguro($file_ins, $header, \@out);
    return $unidades_restauradas;
}

# =========================================================================
# 1. DESAMARRE INVERSO 1-A-1 DE UNA CIRUGÍA (PURGA DE TRAZO COMPLETO)
# =========================================================================
sub purgar_trazo_cirugia_individual {
    my ($id_cirugia, $id_org) = @_;
    $id_cirugia //= '';
    $id_cirugia =~ s/^\s+|\s+$//g;
    return { ok => 0, msg => 'ID de cirugía no especificado.' } unless $id_cirugia ne '';

    my $dat_dir    = obtener_dat_dir();
    my $qx_dir     = File::Spec->catdir($dat_dir, 'quirofano');
    my $cons_dir   = File::Spec->catdir($dat_dir, 'consentimientos');
    my $firmas_dir = obtener_uploads_firmas_dir();

    my $file_qx       = File::Spec->catfile($dat_dir, 'quirofano.dat');
    my $file_dossier  = File::Spec->catfile($qx_dir, "cirugia_${id_cirugia}.json");
    my $file_cons_3nf = File::Spec->catfile($qx_dir, 'consumo_insumos.dat');
    my $file_trm      = File::Spec->catfile($qx_dir, 'tramites_ingreso.dat');
    my $file_rec_alta = File::Spec->catfile($qx_dir, 'recetas_alta.dat');
    my $file_rentas   = File::Spec->catfile($dat_dir, 'rentas_espacios.dat');
    my $file_citas    = File::Spec->catfile($dat_dir, 'citas.dat');
    my $file_edo      = File::Spec->catfile($dat_dir, 'estado_cuenta.dat');
    my $file_recibos  = File::Spec->catfile($dat_dir, 'folios_recibos_privados.dat');
    my $file_cons_dat = File::Spec->catfile($dat_dir, 'consentimientos.dat');

    my %resumen = (
        id_cirugia               => $id_cirugia,
        cirugia_eliminada        => 0,
        dossier_json_eliminado   => 0,
        unidades_stock_devueltas => 0,
        consumos_3nf_eliminados  => 0,
        tramites_eliminados      => 0,
        recetas_alta_eliminadas  => 0,
        rentas_eliminadas        => 0,
        citas_eliminadas         => 0,
        consentimientos_purgados => 0,
        firmas_png_eliminadas    => 0,
        cargos_edo_cta_purgados  => 0,
        recibos_caja_purgados    => 0
    );

    my $id_paciente      = '';
    my $id_medico        = '';
    my $id_sala_renta    = '';
    my $id_cita_paciente = '';
    my $id_consentimiento= '';
    my %recibos_target;
    my %movimientos_edo_target;
    my %rentas_target;
    my %citas_target;

    $citas_target{"CITA-QX-$id_cirugia"} = 1;

    # A. Leer dossier JSON si existe
    my $dossier;
    if (-e $file_dossier && open(my $fhd, '<:raw', $file_dossier)) {
        local $/;
        my $raw = <$fhd>;
        close($fhd);
        eval { $dossier = decode_json($raw); };
    }

    if ($dossier && ref($dossier) eq 'HASH') {
        $id_paciente      = $dossier->{id_paciente} // '';
        $id_medico        = $dossier->{id_medico} // '';
        $id_sala_renta    = $dossier->{id_sala_renta} // '';
        $id_cita_paciente = $dossier->{id_cita_paciente} // '';

        $rentas_target{$id_sala_renta} = 1 if $id_sala_renta ne '';
        $citas_target{$id_cita_paciente} = 1 if $id_cita_paciente ne '';

        if ($dossier->{tramites_ingreso} && ref($dossier->{tramites_ingreso}) eq 'HASH') {
            my $tr = $dossier->{tramites_ingreso};
            $id_consentimiento = $tr->{id_consentimiento} // '';
            my $f_dep = $tr->{folio_recibo_caja} // '';
            $recibos_target{$f_dep} = 1 if $f_dep ne '';
        }
        if ($dossier->{liquidacion_insumos} && ref($dossier->{liquidacion_insumos}) eq 'HASH') {
            my $lq = $dossier->{liquidacion_insumos};
            my $id_mov = $lq->{id_movimiento_caja} // '';
            my $f_fin  = $lq->{folio_recibo_finiquito} // '';
            $movimientos_edo_target{$id_mov} = 1 if $id_mov ne '';
            $recibos_target{$f_fin} = 1 if $f_fin ne '';
        }
    }

    # B. Eliminar fila de dat/quirofano.dat y recolectar IDs de la fila
    if (-e $file_qx && open(my $fhq, '<:encoding(UTF-8)', $file_qx)) {
        my @lines = <$fhq>;
        close($fhq);
        my $cab = shift @lines;
        chomp $cab if defined $cab;
        $cab =~ s/\r//g if defined $cab;
        $cab ||= "ID_CIRUGIA|ID_ORG|ID_PACIENTE|ID_MEDICO|FECHA_PROGRAMADA|HORA_PROGRAMADA|ESTADO|SALA_QUIROFANO|PROCEDIMIENTO|ID_ANESTESIOLOGO|NOTAS|TIPO_CIRUGIA|ID_RENTA_ESPACIO|FOLIO_EXPEDIENTE";

        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            if (($c[0] // '') eq $id_cirugia) {
                $id_paciente   ||= ($c[2] // '');
                $id_medico     ||= ($c[3] // '');
                $id_sala_renta ||= ($c[12] // '');
                $rentas_target{$c[12]} = 1 if defined $c[12] && $c[12] ne '';
                $rentas_target{$id_cirugia} = 1;
                $resumen{cirugia_eliminada}++;
                next;
            }
            push @keep, $l;
        }
        escribir_archivo_seguro($file_qx, $cab, \@keep);
    }

    # C. Revertir stock de insumos 3NF y limpiar consumo_insumos.dat
    my %devolver_stock;
    if (-e $file_cons_3nf && open(my $fhc, '<:encoding(UTF-8)', $file_cons_3nf)) {
        my @lines = <$fhc>;
        close($fhc);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            if (($c[2] // '') eq $id_cirugia) {
                my $id_ins = $c[3] // '';
                my $cant   = int($c[5] // 0);
                $devolver_stock{$id_ins} += $cant if ($id_ins ne '' && $cant > 0);
                $resumen{consumos_3nf_eliminados}++;
                next;
            }
            push @keep, $l;
        }
        escribir_archivo_seguro($file_cons_3nf, $cab, \@keep);
    }
    # Si no estaba en consumo_insumos.dat pero sí en dossier->{consumos_3nf}
    if (scalar(keys %devolver_stock) == 0 && $dossier && ref($dossier->{consumos_3nf}) eq 'ARRAY') {
        foreach my $it (@{$dossier->{consumos_3nf}}) {
            my $id_ins = $it->{id_insumo} // '';
            my $cant   = int($it->{cantidad} // 0);
            $devolver_stock{$id_ins} += $cant if ($id_ins ne '' && $cant > 0);
        }
    }
    if (scalar(keys %devolver_stock) > 0) {
        $resumen{unidades_stock_devueltas} = restaurar_stock_catalogo_3nf(\%devolver_stock);
    }

    # D. Limpiar tramites_ingreso.dat
    if (-e $file_trm && open(my $fht, '<:encoding(UTF-8)', $file_trm)) {
        my @lines = <$fht>;
        close($fht);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            if (($c[2] // '') eq $id_cirugia) {
                my $f_rec = $c[10] // '';
                $recibos_target{$f_rec} = 1 if $f_rec ne '';
                $resumen{tramites_eliminados}++;
                next;
            }
            push @keep, $l;
        }
        escribir_archivo_seguro($file_trm, $cab, \@keep);
    }

    # E. Limpiar recetas_alta.dat
    if (-e $file_rec_alta && open(my $fhr, '<:encoding(UTF-8)', $file_rec_alta)) {
        my @lines = <$fhr>;
        close($fhr);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            if (($c[2] // '') eq $id_cirugia) {
                $resumen{recetas_alta_eliminadas}++;
                next;
            }
            push @keep, $l;
        }
        escribir_archivo_seguro($file_rec_alta, $cab, \@keep);
    }

    # F. Limpiar renta de espacio vinculada en dat/rentas_espacios.dat
    if (-e $file_rentas && open(my $fhren, '<:encoding(UTF-8)', $file_rentas)) {
        my @lines = <$fhren>;
        close($fhren);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $r_id    = $c[0] // '';
            my $r_mot   = $c[11] // '';
            my $r_not   = $c[12] // '';
            my $r_folio = $c[16] // '';
            if ($rentas_target{$r_id} || $r_not =~ /Folio QX:\s*\Q$id_cirugia\E\b/i || $r_mot =~ /Folio QX:\s*\Q$id_cirugia\E\b/i) {
                $rentas_target{$r_id} = 1 if $r_id ne '';
                $recibos_target{$r_folio} = 1 if ($r_folio ne '' && $r_folio =~ /^RC?-/);
                $resumen{rentas_eliminadas}++;
                next;
            }
            push @keep, $l;
        }
        escribir_archivo_seguro($file_rentas, $cab, \@keep);
    }

    # G. Limpiar cita vinculada en dat/citas.dat
    if (-e $file_citas && open(my $fhcit, '<:encoding(UTF-8)', $file_citas)) {
        my @lines = <$fhcit>;
        close($fhcit);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $cit_id  = $c[0] // '';
            my $cit_not = $c[7] // '';
            if ($citas_target{$cit_id} || $cit_not =~ /Folio QX:\s*\Q$id_cirugia\E\b/i) {
                $resumen{citas_eliminadas}++;
                next;
            }
            push @keep, $l;
        }
        escribir_archivo_seguro($file_citas, $cab, \@keep);
    }

    # H. Limpiar consentimiento quirúrgico del paciente y firma PNG
    if ($id_paciente ne '') {
        my $p_cons_file = File::Spec->catfile($cons_dir, "paciente_${id_paciente}.json");
        if (-e $p_cons_file && open(my $fhcp, '<:raw', $p_cons_file)) {
            local $/;
            my $raw = <$fhcp>;
            close($fhcp);
            my $cdata;
            eval { $cdata = decode_json($raw); };
            if ($cdata && ref($cdata) eq 'HASH') {
                my $modificado = 0;
                foreach my $arr_key ('documentos', 'consentimientos') {
                    next unless exists $cdata->{$arr_key} && ref($cdata->{$arr_key}) eq 'ARRAY';
                    my @nuevos_docs;
                    foreach my $doc (@{$cdata->{$arr_key}}) {
                        my $doc_cir = $doc->{id_cirugia} // '';
                        my $doc_id  = $doc->{id_consentimiento} // '';
                        if ($doc_cir eq $id_cirugia || ($id_consentimiento ne '' && $doc_id eq $id_consentimiento)) {
                            $resumen{consentimientos_purgados}++;
                            $modificado = 1;
                            my $firma_url = $doc->{firma_paciente_url} || ($doc->{firmas} ? $doc->{firmas}->{paciente} : '') || '';
                            if ($firma_url && $firma_url =~ /([^\/\\]+\.png)$/i) {
                                my $png_path = File::Spec->catfile($firmas_dir, $1);
                                if (-e $png_path && unlink($png_path)) {
                                    $resumen{firmas_png_eliminadas}++;
                                }
                            }
                            next;
                        }
                        push @nuevos_docs, $doc;
                    }
                    $cdata->{$arr_key} = \@nuevos_docs;
                }
                if ($modificado) {
                    if (open(my $fhw, '>:raw', $p_cons_file)) {
                        print $fhw encode_json($cdata);
                        close($fhw);
                    }
                }
            }
        }
    }

    # Limpiar firmas PNG sueltas con el nombre firma_pac_<id_cirugia>_*.png
    if (-d $firmas_dir && opendir(my $dfd, $firmas_dir)) {
        while (my $fn = readdir($dfd)) {
            if ($fn =~ /^firma_pac_\Q$id_cirugia\E_/i) {
                my $fp = File::Spec->catfile($firmas_dir, $fn);
                if (-e $fp && unlink($fp)) {
                    $resumen{firmas_png_eliminadas}++;
                }
            }
        }
        closedir($dfd);
    }

    # Limpiar dat/consentimientos.dat si tuviera referencia
    if (-e $file_cons_dat && open(my $fhcd, '<:encoding(UTF-8)', $file_cons_dat)) {
        my @lines = <$fhcd>;
        close($fhcd);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            if (($id_consentimiento ne '' && ($c[0] // '') eq $id_consentimiento) || $l =~ /\b\Q$id_cirugia\E\b/) {
                next;
            }
            push @keep, $l;
        }
        escribir_archivo_seguro($file_cons_dat, $cab, \@keep);
    }

    # I. Limpiar cargos en dat/estado_cuenta.dat EXCLUSIVAMENTE de esta cirugía
    if (-e $file_edo && open(my $fhedo, '<:encoding(UTF-8)', $file_edo)) {
        my @lines = <$fhedo>;
        close($fhedo);
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $id_os  = $c[0] // '';
            my $id_mov = $c[1] // '';
            my $notas  = $c[10] // '';
            if (($id_mov ne '' && $movimientos_edo_target{$id_mov}) ||
                ($id_os  ne '' && $movimientos_edo_target{$id_os})  ||
                ($notas =~ /\b\Q$id_cirugia\E\b/i)) {
                $resumen{cargos_edo_cta_purgados}++;
                next;
            }
            push @keep, $l;
        }
        if (open(my $fhout, '>:encoding(UTF-8)', $file_edo)) {
            flock($fhout, LOCK_EX);
            print $fhout "$_\n" foreach @keep;
            close($fhout);
        }
    }

    # J. Limpiar recibos en dat/folios_recibos_privados.dat EXCLUSIVAMENTE de esta cirugía / renta
    if (-e $file_recibos && open(my $fhrec, '<:encoding(UTF-8)', $file_recibos)) {
        my @lines = <$fhrec>;
        close($fhrec);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $id_rec  = $c[0] // '';
            my $id_cons = $c[4] // '';
            my $conc    = $c[11] // '';
            my $conc2   = $c[12] // '';
            my $ref16   = $c[16] // '';

            if (($id_rec ne '' && $recibos_target{$id_rec}) ||
                ($id_cons eq $id_cirugia) ||
                ($ref16 eq $id_cirugia) ||
                ($id_cons ne '' && $rentas_target{$id_cons}) ||
                ($conc =~ /\b\Q$id_cirugia\E\b/i) ||
                ($conc2 =~ /\b\Q$id_cirugia\E\b/i)) {
                $resumen{recibos_caja_purgados}++;
                next;
            }
            push @keep, $l;
        }
        escribir_archivo_seguro($file_recibos, $cab, \@keep);
    }

    # K. Eliminar archivo JSON del dossier quirúrgico
    if (-e $file_dossier && unlink($file_dossier)) {
        $resumen{dossier_json_eliminado} = 1;
    }

    return {
        ok      => 1,
        msg     => "Trazo completo de la cirugía #$id_cirugia eliminado exitosamente.",
        resumen => \%resumen
    };
}

# =========================================================================
# 2. DESAMARRE INVERSO 1-A-1 DESDE SLOT DE AGENDA DE ESPACIOS
# =========================================================================
sub purgar_citas_abiertas_slot_espacio {
    my ($fecha, $hi, $hf, $espacio, $id_arrendatario, $id_renta, $id_cita_directa) = @_;
    my $dat_dir    = obtener_dat_dir();
    my $file_citas = File::Spec->catfile($dat_dir, 'citas.dat');
    return 0 unless -e $file_citas;

    my @lines;
    if (open(my $fh, '<:encoding(UTF-8)', $file_citas)) {
        @lines = <$fh>;
        close($fh);
    }
    return 0 unless @lines;

    my $cab = shift @lines;
    chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;

    my $min_ini = a_minutos_local($hi);
    my $min_fin = a_minutos_local($hf);
    my $esp_norm = lc($espacio // '');
    $esp_norm =~ s/[^a-z0-9]//g;

    my $eliminadas = 0;
    my @cirugias_a_purgar;
    my @keep;

    foreach my $l (@lines) {
        chomp $l; $l =~ s/\r//g;
        next if $l =~ /^\s*$/;
        my @c = split(/\|/, $l, -1);
        my $cit_id   = $c[0] // '';
        my $cit_med  = $c[1] // '';
        my $cit_fec  = $c[3] // '';
        my $cit_hi   = $c[4] // '';
        my $cit_hf   = $c[5] // '';
        my $cit_not  = $c[7] // '';
        my $cit_cons = $c[13] // '';

        my $borrar = 0;
        if ($id_cita_directa && $cit_id eq $id_cita_directa) {
            $borrar = 1;
        } elsif ($id_renta && $cit_not =~ /\b\Q$id_renta\E\b/i) {
            $borrar = 1;
        } elsif ($fecha && $cit_fec eq $fecha) {
            my $c_ini = a_minutos_local($cit_hi);
            my $c_fin = a_minutos_local($cit_hf);
            $c_fin = $c_ini + 30 if ($c_fin <= $c_ini);
            my $traslapa = ($min_ini >= 0 && $min_fin > $min_ini && $c_ini < $min_fin && $c_fin > $min_ini) ? 1 : 0;

            if ($traslapa) {
                my $c_esp_norm = lc($cit_cons);
                $c_esp_norm =~ s/[^a-z0-9]//g;
                my $mismo_espacio = ($esp_norm ne '' && $c_esp_norm ne '' && ($esp_norm eq $c_esp_norm || index($esp_norm, $c_esp_norm) != -1 || index($c_esp_norm, $esp_norm) != -1)) ? 1 : 0;
                my $mismo_medico  = ($id_arrendatario && $id_arrendatario ne 'EXTERNO' && $cit_med eq $id_arrendatario) ? 1 : 0;
                if ($mismo_espacio || $mismo_medico) {
                    $borrar = 1;
                }
            }
        }

        if ($borrar) {
            $eliminadas++;
            if ($cit_not =~ /Folio QX:\s*([0-9A-Za-z\-]+)/i) {
                push @cirugias_a_purgar, $1;
            }
            next;
        }
        push @keep, $l;
    }

    escribir_archivo_seguro($file_citas, $cab, \@keep);

    foreach my $cid (@cirugias_a_purgar) {
        purgar_trazo_cirugia_individual($cid, '');
    }

    return $eliminadas;
}

# =========================================================================
# 3. ESCÁNER Y RECOLECTOR FORENSE DE DATOS / ARCHIVOS HUÉRFANOS
# =========================================================================
sub auditar_y_purgar_huerfanos_org {
    my ($id_org, $ejecutar_purga) = @_;
    $id_org //= '0';
    $id_org = '0' if $id_org eq '';
    $ejecutar_purga = $ejecutar_purga ? 1 : 0;

    my $dat_dir    = obtener_dat_dir();
    my $qx_dir     = File::Spec->catdir($dat_dir, 'quirofano');
    my $cons_dir   = File::Spec->catdir($dat_dir, 'consentimientos');
    my $firmas_dir = obtener_uploads_firmas_dir();

    my $file_qx       = File::Spec->catfile($dat_dir, 'quirofano.dat');
    my $file_pac      = File::Spec->catfile($dat_dir, 'pacientes.dat');
    my $file_usr      = File::Spec->catfile($dat_dir, 'usuarios.dat');
    my $file_cons_3nf = File::Spec->catfile($qx_dir, 'consumo_insumos.dat');
    my $file_trm      = File::Spec->catfile($qx_dir, 'tramites_ingreso.dat');
    my $file_rec_alta = File::Spec->catfile($qx_dir, 'recetas_alta.dat');
    my $file_rentas   = File::Spec->catfile($dat_dir, 'rentas_espacios.dat');
    my $file_citas    = File::Spec->catfile($dat_dir, 'citas.dat');
    my $file_edo      = File::Spec->catfile($dat_dir, 'estado_cuenta.dat');
    my $file_recibos  = File::Spec->catfile($dat_dir, 'folios_recibos_privados.dat');

    # 1. Mapear Pacientes válidos
    my %pacientes_validos;
    if (-e $file_pac && open(my $fhp, '<:encoding(UTF-8)', $file_pac)) {
        <$fhp>;
        while (my $l = <$fhp>) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            $pacientes_validos{$c[0]} = $c[2] // "Paciente #$c[0]" if defined $c[0] && $c[0] ne '';
        }
        close($fhp);
    }

    # 2. Mapear Cirugías Activas/Válidas en dat/quirofano.dat
    my %cirugias_validas;
    my @huerfanos_encontrados;
    my %recibos_huerfanos_target;
    my %devolver_stock_huerfano;

    if (-e $file_qx && open(my $fhq, '<:encoding(UTF-8)', $file_qx)) {
        my @lines = <$fhq>;
        close($fhq);
        shift @lines; # cabecera
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $cid  = $c[0] // '';
            my $cpac = $c[2] // '';
            $cirugias_validas{$cid} = 1 if $cid ne '';
            $pacientes_validos{$cpac} ||= "Paciente Qx #$cpac" if $cpac ne '';
        }
    }

    # 3. Escanear Dossiers JSON en dat/quirofano/cirugia_*.json
    if (-d $qx_dir && opendir(my $dqx, $qx_dir)) {
        while (my $fn = readdir($dqx)) {
            if ($fn =~ /^cirugia_(.+)\.json$/i) {
                my $cid = $1;
                if (!exists $cirugias_validas{$cid}) {
                    my $full_p = File::Spec->catfile($qx_dir, $fn);
                    # Leer posibles recibos huérfanos dentro del JSON antes de borrarlo
                    if (open(my $fhj, '<:raw', $full_p)) {
                        local $/; my $raw = <$fhj>; close($fhj);
                        my $dj; eval { $dj = decode_json($raw); };
                        if ($dj && ref($dj) eq 'HASH') {
                            if ($dj->{tramites_ingreso} && $dj->{tramites_ingreso}->{folio_recibo_caja}) {
                                $recibos_huerfanos_target{$dj->{tramites_ingreso}->{folio_recibo_caja}} = $cid;
                            }
                            if ($dj->{liquidacion_insumos} && $dj->{liquidacion_insumos}->{folio_recibo_finiquito}) {
                                $recibos_huerfanos_target{$dj->{liquidacion_insumos}->{folio_recibo_finiquito}} = $cid;
                            }
                        }
                    }
                    push @huerfanos_encontrados, {
                        categoria => 'Dossier JSON Quirúrgico Huérfano',
                        archivo   => "dat/quirofano/$fn",
                        id        => $cid,
                        detalle   => "Archivo $fn sin registro padre en dat/quirofano.dat"
                    };
                    unlink($full_p) if $ejecutar_purga;
                }
            }
        }
        closedir($dqx);
    }

    # 4. Escanear consumo_insumos.dat
    if (-e $file_cons_3nf && open(my $fhc, '<:encoding(UTF-8)', $file_cons_3nf)) {
        my @lines = <$fhc>;
        close($fhc);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $id_cns = $c[0] // '';
            my $cid    = $c[2] // '';
            my $id_ins = $c[3] // '';
            my $cant   = int($c[5] // 0);
            if ($cid eq '' || !exists $cirugias_validas{$cid}) {
                push @huerfanos_encontrados, {
                    categoria => 'Consumo 3NF Huérfano (Stock Retornable)',
                    archivo   => 'dat/quirofano/consumo_insumos.dat',
                    id        => $id_cns,
                    detalle   => "Consumo #$id_cns ($cant u. de $id_ins) apunta a cirugía inexistente #$cid"
                };
                if ($ejecutar_purga) {
                    $devolver_stock_huerfano{$id_ins} += $cant if ($id_ins ne '' && $cant > 0);
                    next;
                }
            }
            push @keep, $l;
        }
        if ($ejecutar_purga) {
            escribir_archivo_seguro($file_cons_3nf, $cab, \@keep);
            restaurar_stock_catalogo_3nf(\%devolver_stock_huerfano) if scalar(keys %devolver_stock_huerfano) > 0;
        }
    }

    # 5. Escanear tramites_ingreso.dat
    if (-e $file_trm && open(my $fht, '<:encoding(UTF-8)', $file_trm)) {
        my @lines = <$fht>;
        close($fht);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $id_trm = $c[0] // '';
            my $cid    = $c[2] // '';
            my $f_rec  = $c[10] // '';
            if ($cid eq '' || !exists $cirugias_validas{$cid}) {
                $recibos_huerfanos_target{$f_rec} = $cid if $f_rec ne '';
                push @huerfanos_encontrados, {
                    categoria => 'Trámite de Admisión Quirúrgica Huérfano',
                    archivo   => 'dat/quirofano/tramites_ingreso.dat',
                    id        => $id_trm,
                    detalle   => "Trámite #$id_trm apunta a cirugía inexistente #$cid"
                };
                next if $ejecutar_purga;
            }
            push @keep, $l;
        }
        if ($ejecutar_purga) {
            escribir_archivo_seguro($file_trm, $cab, \@keep);
        }
    }

    # 6. Escanear recetas_alta.dat
    if (-e $file_rec_alta && open(my $fhr, '<:encoding(UTF-8)', $file_rec_alta)) {
        my @lines = <$fhr>;
        close($fhr);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $id_rec = $c[0] // '';
            my $cid    = $c[2] // '';
            if ($cid eq '' || !exists $cirugias_validas{$cid}) {
                push @huerfanos_encontrados, {
                    categoria => 'Receta de Alta Quirúrgica Huérfana',
                    archivo   => 'dat/quirofano/recetas_alta.dat',
                    id        => $id_rec,
                    detalle   => "Receta #$id_rec apunta a cirugía inexistente #$cid"
                };
                next if $ejecutar_purga;
            }
            push @keep, $l;
        }
        if ($ejecutar_purga) {
            escribir_archivo_seguro($file_rec_alta, $cab, \@keep);
        }
    }

    # 7. Escanear dat/rentas_espacios.dat (Rentas quirúrgicas huérfanas o malformadas sin cirugía padre)
    my %rentas_validas;
    if (-e $file_rentas && open(my $fhren, '<:encoding(UTF-8)', $file_rentas)) {
        my @lines = <$fhren>;
        close($fhren);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $r_id    = $c[0] // '';
            my $r_mot   = $c[11] // '';
            my $r_not   = $c[12] // '';
            my $r_folio = $c[16] // '';

            my $qx_ref = '';
            if ($r_not =~ /Folio QX:\s*([0-9A-Za-z\-]+)/i) {
                $qx_ref = $1;
            } elsif ($r_mot =~ /Folio QX:\s*([0-9A-Za-z\-]+)/i) {
                $qx_ref = $1;
            }

            if (($qx_ref ne '' && !exists $cirugias_validas{$qx_ref}) ||
                ($r_id =~ /^REN-QX-/ && $qx_ref eq '' && !exists $cirugias_validas{$r_id})) {
                $recibos_huerfanos_target{$r_folio} = $r_id if ($r_folio ne '' && $r_folio =~ /^RC?-/);
                push @huerfanos_encontrados, {
                    categoria => 'Renta de Espacio Quirúrgico Huérfana',
                    archivo   => 'dat/rentas_espacios.dat',
                    id        => $r_id,
                    detalle   => "Reserva #$r_id vinculada a cirugía inexistente (" . ($qx_ref || 'sin padre en quirofano.dat') . ")"
                };
                next if $ejecutar_purga;
            }
            $rentas_validas{$r_id} = 1 if $r_id ne '';
            push @keep, $l;
        }
        if ($ejecutar_purga) {
            escribir_archivo_seguro($file_rentas, $cab, \@keep);
        }
    }

    # 8. Escanear dat/citas.dat (Citas CITA-QX-* huérfanas o de pacientes eliminados)
    if (-e $file_citas && open(my $fhcit, '<:encoding(UTF-8)', $file_citas)) {
        my @lines = <$fhcit>;
        close($fhcit);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $cit_id  = $c[0] // '';
            my $cit_pac = $c[2] // '';
            my $cit_not = $c[7] // '';

            my $qx_ref = '';
            if ($cit_not =~ /Folio QX:\s*([0-9A-Za-z\-]+)/i) {
                $qx_ref = $1;
            }

            if (($qx_ref ne '' && !exists $cirugias_validas{$qx_ref}) ||
                ($cit_id =~ /^CITA-QX-/ && $qx_ref eq '')) {
                push @huerfanos_encontrados, {
                    categoria => 'Cita Quirúrgica Huérfana',
                    archivo   => 'dat/citas.dat',
                    id        => $cit_id,
                    detalle   => "Cita #$cit_id apunta a cirugía inexistente (" . ($qx_ref || 'CITA-QX sin cirugía') . ")"
                };
                next if $ejecutar_purga;
            }
            if ($cit_pac =~ /^\d+$/ && !exists $pacientes_validos{$cit_pac}) {
                push @huerfanos_encontrados, {
                    categoria => 'Cita con Paciente Eliminado',
                    archivo   => 'dat/citas.dat',
                    id        => $cit_id,
                    detalle   => "Cita #$cit_id apunta a ID_PACIENTE=$cit_pac inexistente en pacientes.dat"
                };
                next if $ejecutar_purga;
            }
            push @keep, $l;
        }
        if ($ejecutar_purga) {
            escribir_archivo_seguro($file_citas, $cab, \@keep);
        }
    }

    # 9. Escanear Consentimientos Quirúrgicos Huérfanos en dat/consentimientos/paciente_*.json y Firmas PNG
    if (-d $cons_dir && opendir(my $dcons, $cons_dir)) {
        while (my $fn = readdir($dcons)) {
            if ($fn =~ /^paciente_(.+)\.json$/i) {
                my $pid = $1;
                my $full_p = File::Spec->catfile($cons_dir, $fn);

                if ($pid =~ /^\d+$/ && !exists $pacientes_validos{$pid}) {
                    push @huerfanos_encontrados, {
                        categoria => 'Archivo de Consentimiento de Paciente Inexistente',
                        archivo   => "dat/consentimientos/$fn",
                        id        => "PAC-$pid",
                        detalle   => "El paciente #$pid ya no existe en dat/pacientes.dat"
                    };
                    unlink($full_p) if $ejecutar_purga;
                    next;
                }

                if (open(my $fhcp, '<:raw', $full_p)) {
                    local $/; my $raw = <$fhcp>; close($fhcp);
                    my $cdata; eval { $cdata = decode_json($raw); };
                    if ($cdata && ref($cdata) eq 'HASH') {
                        my $mod = 0;
                        foreach my $arr_key ('documentos', 'consentimientos') {
                            next unless exists $cdata->{$arr_key} && ref($cdata->{$arr_key}) eq 'ARRAY';
                            my @keep_docs;
                            foreach my $doc (@{$cdata->{$arr_key}}) {
                                my $dcir = $doc->{id_cirugia} // '';
                                my $did  = $doc->{id_consentimiento} // 'CNS-QX';
                                if ($dcir ne '' && !exists $cirugias_validas{$dcir}) {
                                    push @huerfanos_encontrados, {
                                        categoria => 'Consentimiento Quirúrgico Huérfano',
                                        archivo   => "dat/consentimientos/$fn",
                                        id        => $did,
                                        detalle   => "Consentimiento #$did del paciente #$pid apunta a cirugía inexistente #$dcir"
                                    };
                                    $mod = 1;
                                    next if $ejecutar_purga;
                                }
                                push @keep_docs, $doc;
                            }
                            $cdata->{$arr_key} = \@keep_docs if $ejecutar_purga;
                        }
                        if ($ejecutar_purga && $mod) {
                            if (open(my $fhw, '>:raw', $full_p)) {
                                print $fhw encode_json($cdata);
                                close($fhw);
                            }
                        }
                    }
                }
            }
        }
        closedir($dcons);
    }

    if (-d $firmas_dir && opendir(my $dfir, $firmas_dir)) {
        while (my $fn = readdir($dfir)) {
            if ($fn =~ /^firma_pac_(CIR-[0-9A-Za-z\-]+)_\d+\.png$/i) {
                my $cid = $1;
                if (!exists $cirugias_validas{$cid}) {
                    my $fp = File::Spec->catfile($firmas_dir, $fn);
                    push @huerfanos_encontrados, {
                        categoria => 'Firma Digital PNG Huérfana',
                        archivo   => "uploads/firmas/$fn",
                        id        => $fn,
                        detalle   => "Imagen de firma quirúrgica sin cirugía activa ($cid)"
                    };
                    unlink($fp) if $ejecutar_purga;
                }
            }
        }
        closedir($dfir);
    }

    # 10. Escanear Cargos Quirúrgicos Huérfanos en dat/estado_cuenta.dat
    if (-e $file_edo && open(my $fhedo, '<:encoding(UTF-8)', $file_edo)) {
        my @lines = <$fhedo>;
        close($fhedo);
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $id_os  = $c[0] // '';
            my $id_mov = $c[1] // '';
            my $notas  = $c[10] // '';

            if ($notas =~ /Cirug[ií]a #(CIR-[0-9A-Za-z\-]+)/i || $notas =~ /Folio:\s*(CIR-[0-9A-Za-z\-]+)/i) {
                my $cid = $1;
                if (!exists $cirugias_validas{$cid}) {
                    push @huerfanos_encontrados, {
                        categoria => 'Cargo de Estado de Cuenta Quirúrgico Huérfano',
                        archivo   => 'dat/estado_cuenta.dat',
                        id        => $id_mov || $id_os,
                        detalle   => "Cargo $id_mov ($c[4]) referencia cirugía eliminada #$cid"
                    };
                    next if $ejecutar_purga;
                }
            }
            push @keep, $l;
        }
        if ($ejecutar_purga) {
            if (open(my $fhout, '>:encoding(UTF-8)', $file_edo)) {
                flock($fhout, LOCK_EX);
                print $fhout "$_\n" foreach @keep;
                close($fhout);
            }
        }
    }

    # 11. Escanear Recibos Privados Quirúrgicos/Espacios Huérfanos en dat/folios_recibos_privados.dat
    if (-e $file_recibos && open(my $fhrec, '<:encoding(UTF-8)', $file_recibos)) {
        my @lines = <$fhrec>;
        close($fhrec);
        my $cab = shift @lines;
        chomp $cab if defined $cab; $cab =~ s/\r//g if defined $cab;
        my @keep;
        foreach my $l (@lines) {
            chomp $l; $l =~ s/\r//g;
            next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $id_rec  = $c[0] // '';
            my $id_cons = $c[4] // '';
            my $conc    = ($c[11] // '') . ' ' . ($c[12] // '');
            my $ref16   = $c[16] // '';

            my $es_huerfano = 0;
            my $motivo_h    = '';

            if (exists $recibos_huerfanos_target{$id_rec}) {
                $es_huerfano = 1;
                $motivo_h = "Recibo #$id_rec vinculado a registro huérfano ($recibos_huerfanos_target{$id_rec})";
            } elsif ($ref16 =~ /^CIR-/ && !exists $cirugias_validas{$ref16}) {
                $es_huerfano = 1;
                $motivo_h = "Recibo #$id_rec referencia cirugía inexistente #$ref16";
            } elsif ($id_cons =~ /^CIR-/ && !exists $cirugias_validas{$id_cons}) {
                $es_huerfano = 1;
                $motivo_h = "Recibo #$id_rec referencia cirugía inexistente #$id_cons";
            } elsif ($id_cons =~ /^REN-/ && !exists $rentas_validas{$id_cons}) {
                $es_huerfano = 1;
                $motivo_h = "Recibo de renta #$id_rec referencia reserva de espacio eliminada #$id_cons";
            } elsif ($conc =~ /Folio:\s*(CIR-[0-9A-Za-z\-]+)/i && !exists $cirugias_validas{$1}) {
                $es_huerfano = 1;
                $motivo_h = "Recibo quirúrgico #$id_rec referencia cirugía eliminada #$1";
            }

            if ($es_huerfano) {
                push @huerfanos_encontrados, {
                    categoria => 'Recibo de Caja Quirúrgico/Espacio Huérfano',
                    archivo   => 'dat/folios_recibos_privados.dat',
                    id        => $id_rec,
                    detalle   => $motivo_h
                };
                next if $ejecutar_purga;
            }
            push @keep, $l;
        }
        if ($ejecutar_purga) {
            escribir_archivo_seguro($file_recibos, $cab, \@keep);
        }
    }

    return {
        ok               => 1,
        ejecutado        => $ejecutar_purga,
        total_huerfanos  => scalar(@huerfanos_encontrados),
        huerfanos        => \@huerfanos_encontrados
    };
}

1;
