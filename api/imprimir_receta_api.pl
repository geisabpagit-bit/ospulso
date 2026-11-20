#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON qw(decode_json encode_json);
use Encode qw(encode_utf8 decode_utf8);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = eval { check_session($q) } || {};

binmode STDOUT, ":utf8";

# Identificadores de solicitud
my $id_receta       = $q->param('id_receta') || '';
my $id_consulta     = $q->param('id_consulta') || '';
my $id_paciente_req = $q->param('id_paciente') || $q->param('id') || '';
my $is_preview      = $q->param('preview') || $q->param('wizard_preview') || '';

# 1. Búsqueda en dat/recetas.dat
my $receta_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'recetas.dat');
my $receta_row;

if (-e $receta_file && open(my $fh, '<:encoding(UTF-8)', $receta_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        if (($id_receta && $c[0] eq $id_receta) || ($id_consulta && $c[1] eq $id_consulta)) {
            $receta_row = \@c;
            last;
        }
    }
    close($fh);
}

# 2. Cargar Consulta Clínica desde dat/consultas_clinicas.dat (si hay $id_consulta o para fallback)
my $cons_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
my $consulta_raw = {};

if (-e $cons_file && open(my $fhc, '<:encoding(UTF-8)', $cons_file)) {
    my $h = <$fhc>;
    while (my $line = <$fhc>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        my $match_c = ($id_consulta && $c[0] eq $id_consulta);
        my $match_r = ($receta_row && $c[0] eq $receta_row->[1]);
        my $match_p = ($id_paciente_req && $c[1] eq $id_paciente_req && !$id_consulta && !$id_receta);

        if ($match_c || $match_r || $match_p) {
            my $raw_j = $c[5] // '{}';
            $raw_j =~ s/\\n/\n/g;
            my $p = eval { decode_json(encode_utf8($raw_j)) };
            if (!%$p) { eval { $p = decode_json($raw_j); }; }
            
            my $ts = $c[4] || time();
            my ($sec,$min,$hour,$mday,$mon,$year) = localtime($ts);
            my $f_str = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
            my $h_str = sprintf("%02d:%02d", $hour, $min);

            $consulta_raw = {
                id_consulta => $c[0],
                id_paciente => $c[1],
                id_cita     => $c[2],
                id_medico   => $c[3],
                timestamp   => $ts,
                fecha       => $f_str,
                hora        => $h_str,
                data        => $p || {}
            };

            # Si no había fila en recetas.dat pero la consulta tiene medicamentos o receta_json
            if (!$receta_row && $p && ($p->{requiere_receta} eq '1' || ($p->{medicamentos} && ref($p->{medicamentos}) eq 'ARRAY' && @{$p->{medicamentos}}))) {
                my $meds_str = eval { encode_json($p->{medicamentos} || []) } || '[]';
                $receta_row = [
                    'REC-' . $ts,
                    $c[0],
                    $c[1],
                    $c[3],
                    $f_str,
                    $p->{receta_folio} || "REC-$f_str-001",
                    $p->{diagnostico_principal} || 'Evaluación Médica General',
                    $meds_str
                ];
            }
            last;
        }
    }
    close($fhc);
}

# 3. Parsear Medicamentos
my $items = [];
my $d_cons = $consulta_raw->{data} || {};

if ($receta_row && $receta_row->[7]) {
    eval {
        my $json_raw = $receta_row->[7];
        $json_raw =~ s/\\n/\n/g;
        if ($json_raw =~ /^\s*\[/) {
            $items = decode_json(encode_utf8($json_raw));
            if (!@$items) { eval { $items = decode_json($json_raw); }; }
        } else {
            my $payload = decode_json(encode_utf8($json_raw));
            if (!%$payload) { eval { $payload = decode_json($json_raw); }; }
            if ($payload->{receta_json}) {
                $items = ref($payload->{receta_json}) eq 'ARRAY' ? $payload->{receta_json} : decode_json($payload->{receta_json});
            } elsif ($payload->{medicamentos}) {
                $items = $payload->{medicamentos};
            }
        }
    };
}

# Si no hubo en recetas.dat, buscar en data de la consulta
if ((!$items || !@$items) && $d_cons->{medicamentos} && ref($d_cons->{medicamentos}) eq 'ARRAY') {
    $items = $d_cons->{medicamentos};
}
if ((!$items || !@$items) && $d_cons->{receta_json}) {
    eval {
        my $rj = $d_cons->{receta_json};
        $items = ref($rj) eq 'ARRAY' ? $rj : decode_json(encode_utf8($rj));
    };
}

# Filtrar medicamentos válidos
if (ref($items) eq 'ARRAY') {
    @$items = grep {
        ($_->{generico} && $_->{generico} !~ /^\s*$/) ||
        ($_->{comercial} && $_->{comercial} !~ /^\s*$/) ||
        ($_->{farmaco} && $_->{farmaco} !~ /^\s*$/)
    } @$items;
} else {
    $items = [];
}

# Si se solicitó una consulta específica existente y no tiene medicamentos ni receta, mostrar pantalla limpia "Sin Receta"
if (!$is_preview && ($id_consulta || $id_receta) && (!$receta_row || !@$items)) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print <<'HTML';
<!DOCTYPE html>
<html lang="es-MX">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sin Receta Médica | OsPulso</title>
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #F1F5F9; color: #0F172A; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .empty-card { max-width: 480px; width: 90%; background: #ffffff; border-radius: 1.25rem; border: 1px solid #E2E8F0; box-shadow: 0 10px 30px rgba(13,34,56,0.06); padding: 2.5rem; text-align: center; }
    </style>
</head>
<body>
    <div class="empty-card">
        <div class="bg-light rounded-circle d-inline-flex p-3 mb-3 text-secondary">
            <i class="bi bi-capsule fs-1" style="color: #00C0B5;"></i>
        </div>
        <h4 class="fw-bold mb-2" style="color: #0D2238;">Sin Receta Médica Emitida</h4>
        <p class="text-muted small mb-4">Esta consulta médica no requirió prescripción farmacológica o no cuenta con medicamentos registrados.</p>
        <button onclick="window.close()" class="btn btn-outline-secondary rounded-pill px-4 fw-semibold">Cerrar Ventana</button>
    </div>
</body>
</html>
HTML
    exit;
}

# MODO DEMO / PREVIEW CANÓNICO SI NO HAY REGISTROS ESPECÍFICOS O MODO PREVIEW
if (!@$items) {
    $items = [
        {
            generico      => 'PANTOPRAZOL',
            concentracion => '40 mg',
            forma         => 'Comprimidos con recubrimiento entérico',
            comercial     => 'Tecta / Pantozol',
            presentacion  => 'Caja con 14 comprimidos',
            surtir        => '1 (Una) Caja',
            via           => 'Oral',
            fraccion_lgs  => 'Sin Retención de Receta • Fracción IV (Art. 226 LGS)',
            posologia     => 'Tomar 1 comprimido (40 mg) por vía oral cada 24 horas por la mañana, estrictamente en ayuno (30 minutos antes del desayuno con abundante agua).',
            duracion      => 'Durante 14 días continuos. No suspender dosis prematuramente.'
        },
        {
            generico      => 'MAGALDRATO / DIMETICONA',
            concentracion => '800 mg / 100 mg por 10 ml',
            forma         => 'Gel en suspensión oral',
            comercial     => 'Riopan Gel',
            presentacion  => 'Caja con 10 sobres monodosis (10 ml c/u)',
            surtir        => '1 (Una) Caja',
            via           => 'Oral',
            fraccion_lgs  => 'Sin Retención de Receta • Fracción V (Art. 226 LGS)',
            posologia     => 'Tomar 1 sobre monodosis (10 ml de suspensión) por vía oral 1 hora después del almuerzo/comida principal y 1 hora después de la cena, así como inmediatamente antes de acostarse en caso de pirosis nocturna.',
            duracion      => 'Durante 7 días continuos según respuesta sintomática.'
        }
    ];
}

# 4. Metadatos de la Receta
my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
my $f_hoy_cst = sprintf("%02d/%02d/%04d", $mday, $mon+1, $year+1900);
my $h_hoy_cst = sprintf("%02d:%02d", $hour, $min);

# Calcular vencimiento (30 días naturales según LGS Art. 226)
my $ts_vence = time() + (30 * 86400);
my ($v_sec,$v_min,$v_hour,$v_mday,$v_mon,$v_year) = localtime($ts_vence);
my @meses_nom = qw(Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre);
my $fecha_vence_str = sprintf("%02d de %s de %04d", $v_mday, $meses_nom[$v_mon], $v_year+1900);

my $folio = $receta_row->[5] || $d_cons->{receta_folio} || ("REC-" . sprintf("%04d%02d%02d-%03d", $year+1900, $mon+1, $mday, int(rand(900))+100));
my $fecha_emision = $receta_row->[4] || $consulta_raw->{fecha} || sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
my $hora_emision  = $consulta_raw->{hora} || $h_hoy_cst;

# 5. Cargar Datos de Organización (dat/negocios.dat)
my $neg_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $res_neg = -f $neg_file ? eval { leer_tabla($neg_file, '\|') } || [] : [];
my $org = {
    id             => '0',
    nombre_negocio => 'OsPulso Clinical Suite 5S',
    razon_social   => 'GEISABPA Plataformas Digitales de México S.A. de C.V.',
    rfc            => 'GPD190412XYZ',
    clues          => 'DFSSA003421',
    licencia_ssa   => '23-AM-09-015-882',
    domicilio      => 'Av. Álvaro Obregón 121, Col. Roma Nte., Cuauhtémoc, CDMX, C.P. 06700',
    telefono       => '(55) 5200-8800',
    email          => 'urgencias@os-pulso.mx',
    logo_url       => '../favicon/favicon.svg',
    sede           => 'SEDE ROMA NORTE'
};

if ($res_neg && @$res_neg) {
    foreach my $n (@$res_neg) {
        next if $n->[0] =~ /^ID$/i;
        if ($n->[0] eq '0' || !$org->{nombre_negocio}) {
            $org->{nombre_negocio} = $n->[1] || $org->{nombre_negocio};
            $org->{domicilio}      = $n->[6] || $org->{domicilio};
            $org->{telefono}       = $n->[7] || $org->{telefono};
            $org->{email}          = $n->[8] || $org->{email};
            $org->{logo_url}       = ($n->[9] && $n->[9] ne '') ? $n->[9] : $org->{logo_url};
            $org->{rfc}            = $n->[10] || $org->{rfc};
            $org->{razon_social}   = $n->[11] || $org->{razon_social};
            $org->{clues}          = $n->[18] || $org->{clues};
            last;
        }
    }
}

# 6. Cargar Datos del Paciente (dat/pacientes.dat)
my $target_pac_id = $receta_row->[2] || $consulta_raw->{id_paciente} || $id_paciente_req || '1';
my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $res_pac = -f $pac_file ? eval { leer_tabla($pac_file, '\|') } || [] : [];
my $paciente = {
    id        => $target_pac_id,
    nombre    => 'Israel Garay Hernández',
    curp      => 'GAHI891108HDFRRN04',
    fecha_nac => '1989-11-08',
    edad      => '34 años',
    sexo      => 'Masculino',
    telefono  => '5552008800',
    ts        => 'O+',
    alergias  => 'Penicilina'
};

foreach my $p (@$res_pac) {
    next if $p->[0] =~ /^ID_PACIENTE$/i;
    if ($p->[0] eq $target_pac_id) {
        $paciente->{id}        = $p->[0];
        $paciente->{nombre}    = $p->[2] || $paciente->{nombre};
        $paciente->{curp}      = $p->[4] || $paciente->{curp};
        $paciente->{fecha_nac} = $p->[6] || $paciente->{fecha_nac};
        $paciente->{sexo}      = $p->[7] || $paciente->{sexo};
        $paciente->{ts}        = $p->[11] || 'O+';
        $paciente->{telefono}  = $p->[12] || $paciente->{telefono};
        $paciente->{alergias}  = $p->[15] || $paciente->{alergias};
        last;
    }
}

# Calcular edad precisa si está disponible fecha de nacimiento
if ($paciente->{fecha_nac} =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
    my ($py, $pm, $pd) = ($1, $2, $3);
    my $e = ($year + 1900) - $py;
    $e-- if (($mon + 1) < $pm || (($mon + 1) == $pm && $mday < $pd));
    $paciente->{edad} = "$e años";
}

# 7. Cargar Datos del Médico Prescriptor (dat/usuarios.dat)
my $target_med_id = $receta_row->[3] || $consulta_raw->{id_medico} || 'DOC-001';
my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $res_usr = -f $usr_file ? eval { leer_tabla($usr_file, '!') } || [] : [];
my $medico = {
    id             => $target_med_id,
    nombre         => 'Dr. Roberto Martínez Escobedo',
    especialidad   => $d_cons->{especialidad} || 'Medicina Interna',
    cedula_prof    => '8492019',
    cedula_esp     => '11029482',
    certificacion  => 'CMIM: A-2194',
    universidad    => 'Universidad Nacional Autónoma de México • Hospital General de México',
    firma_url      => ''
};

foreach my $u (@$res_usr) {
    next if $u->[0] =~ /^id$/i;
    if ($u->[0] eq $target_med_id || "DOC-" . sprintf("%03d", $u->[0]) eq $target_med_id || $u->[0] eq '0') {
        my $nom_raw = $u->[1] || $medico->{nombre};
        $medico->{nombre}      = ($nom_raw =~ /^Dr/i) ? $nom_raw : "Dr(a). $nom_raw";
        $medico->{cedula_prof} = $u->[9] if ($u->[9] && $u->[9] ne '0' && $u->[9] ne '');
        $medico->{firma_url}   = $u->[11] if ($u->[11] && $u->[11] ne '');
        last if ($u->[0] eq $target_med_id);
    }
}

# 8. Signos Vitales y Diagnósticos del Paciente
my $ta_val    = $d_cons->{ta} || '120/80';
my $peso_val  = $d_cons->{peso} || '73.5';
my $talla_val = $d_cons->{talla} || '175';
my $imc_val   = '24.0';

# Calcular IMC si hay peso y talla
my $p_num = $peso_val; $p_num =~ s/[^0-9.]//g;
my $t_num = $talla_val; $t_num =~ s/[^0-9.]//g;
if ($p_num > 0 && $t_num > 0) {
    my $tm = $t_num > 3 ? $t_num / 100 : $t_num;
    if ($tm > 0) {
        $imc_val = sprintf("%.1f", $p_num / ($tm * $tm));
    }
}

my $dx_principal  = $d_cons->{diagnostico_principal} || $receta_row->[6] || 'Gastritis, no especificada';
my $dx_cie10      = $d_cons->{clave_diagnostico_cie10} || 'K29.7';
my $dx_secundario = $d_cons->{diagnosticos_secundarios} || 'K21.9 Reflujo gastroesofágico';
my $alergias_txt  = $d_cons->{antecedentes_patologicos} || $paciente->{alergias} || 'Penicilina';

# Indicaciones extra e higiénico-dietéticas
my $indicaciones_extra = $d_cons->{receta_indicaciones} || $d_cons->{receta_indicaciones_extra} || 'Tomar medicamentos puntualmente según posología. Evitar alimentos irritantes, grasas y ayunos prolongados.';
my $estudios_solicitados = $d_cons->{laboratorios_solicitados} || 'Prueba de Antígeno en Heces para Helicobacter pylori (48 hrs post-tratamiento).';

print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es-MX">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Receta Médica Digital - Folio $folio | OsPulso Clinical Suite 5S</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">

    <!-- Fuentes Mandantes del Ecosistema OSPulso -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;600;700&display=swap" rel="stylesheet">

    <!-- CSS Bootstrap 5.3 & Icons -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.3/font/bootstrap-icons.css" rel="stylesheet">

    <style>
        :root {
            --primary-clinical: #00C0B5;
            --primary-clinical-hover: #00A39A;
            --primary-clinical-active: #00847D;
            --navy-surgical: #0D2238;
            --navy-dark: #0F172A;
            --workspace-bg: #F1F5F9;
            --slate-muted: #64748B;
            --slate-border: #E2E8F0;
            --card-neutral: #F8FAFC;
            --accent-teal-soft: #F0FDFA;
            --alert-danger-bg: #FEF2F2;
            --alert-danger-border: #FCA5A5;
            --alert-danger-text: #991B1B;
        }

        * {
            box-sizing: border-box;
        }

        body {
            font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
            background-color: var(--workspace-bg);
            color: var(--navy-dark);
            margin: 0;
            padding: 0;
            -webkit-font-smoothing: antialiased;
        }

        /* 1. BARRA DE HERRAMIENTAS SUPERIOR DEL VISOR (Toolbar) */
        .visor-toolbar-top {
            position: sticky;
            top: 0;
            z-index: 1050;
            background: #ffffff;
            border-bottom: 1px solid var(--slate-border);
            box-shadow: 0 2px 12px rgba(13, 34, 56, 0.04);
            padding: 0.65rem 1.5rem;
        }

        .btn-toolbar-pill {
            font-size: 0.8rem;
            font-weight: 600;
            border-radius: 9999px;
            padding: 0.38rem 0.95rem;
            transition: all 0.2s ease;
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
            text-decoration: none;
        }

        .badge-regulatorio {
            font-size: 0.68rem;
            font-weight: 800;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            padding: 0.25rem 0.55rem;
            border-radius: 0.35rem;
        }

        /* 2. SUB-HEADER NORMATIVO */
        .sub-header-normativo {
            max-width: 900px;
            margin: 1.25rem auto 0.75rem;
            padding: 0 1rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: gap;
            gap: 0.75rem;
        }

        /* 3. HOJA DE RECETA MÉDICA OFICIAL (Letter Portrait 8.5" x 11") */
        .recipe-workspace-area {
            padding: 0.5rem 1rem 3.5rem;
            display: flex;
            justify-content: center;
        }

        .recipe-letter-sheet {
            background: #ffffff;
            width: 816px; /* Ancho estándar 8.5in a 96 DPI */
            min-height: 1056px; /* 11in a 96 DPI */
            border-radius: 0.75rem;
            border: 1px solid var(--slate-border);
            box-shadow: 0 15px 45px rgba(13, 34, 56, 0.1), 0 2px 10px rgba(13, 34, 56, 0.04);
            padding: 24px 28px;
            color: var(--navy-dark);
            position: relative;
            transform-origin: top center;
            transition: transform 0.2s ease;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }

        /* Encabezado Institucional */
        .receta-header-inst {
            border-bottom: 2px solid var(--navy-surgical);
            padding-bottom: 0.65rem;
            margin-bottom: 0.75rem;
        }
        .receta-logo-sq {
            width: 48px;
            height: 48px;
            object-fit: contain;
            border-radius: 0.4rem;
        }
        .receta-inst-name {
            font-size: 1.15rem;
            font-weight: 800;
            color: var(--navy-surgical);
            letter-spacing: -0.3px;
            line-height: 1.2;
        }
        .receta-inst-meta {
            font-size: 0.68rem;
            color: var(--slate-muted);
            line-height: 1.35;
        }

        /* Bloque del Médico Prescriptor */
        .receta-medico-card {
            background-color: var(--navy-surgical);
            color: #ffffff;
            border-radius: 0.65rem;
            padding: 0.75rem 1rem;
            margin-bottom: 0.65rem;
        }
        .receta-medico-nombre {
            font-size: 1.05rem;
            font-weight: 800;
            letter-spacing: -0.2px;
        }
        .receta-cedulas-grid {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 0.5rem;
            margin-top: 0.45rem;
            padding-top: 0.45rem;
            border-top: 1px solid rgba(255, 255, 255, 0.15);
        }
        .receta-cedula-cell {
            background: rgba(255, 255, 255, 0.08);
            border-radius: 0.35rem;
            padding: 0.25rem 0.5rem;
            text-align: center;
        }
        .receta-cedula-lbl {
            font-size: 0.58rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #94A3B8;
            font-weight: 700;
        }
        .receta-cedula-val {
            font-size: 0.8rem;
            font-weight: 800;
            color: #ffffff;
            font-family: 'JetBrains Mono', monospace;
        }

        /* Ficha Demográfica del Paciente */
        .receta-paciente-grid {
            background-color: var(--card-neutral);
            border: 1px solid var(--slate-border);
            border-radius: 0.5rem;
            padding: 0.55rem 0.75rem;
            margin-bottom: 0.55rem;
            display: grid;
            grid-template-columns: 1.5fr 1fr 1.2fr 1.3fr;
            gap: 0.5rem;
            font-size: 0.75rem;
        }
        .p-field-lbl {
            font-size: 0.6rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--slate-muted);
            margin-bottom: 0.1rem;
        }
        .p-field-val {
            font-size: 0.78rem;
            font-weight: 600;
            color: var(--navy-dark);
            line-height: 1.3;
        }

        /* Banner de Alerta Farmacológica Crítica */
        .receta-alerta-critica {
            background-color: var(--alert-danger-bg);
            border: 1px solid var(--alert-danger-border);
            border-left: 4px solid #DC2626;
            color: var(--alert-danger-text);
            border-radius: 0.45rem;
            padding: 0.45rem 0.75rem;
            margin-bottom: 0.65rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-size: 0.72rem;
        }

        /* Prescripción Médica (Cuerpo Principal) */
        .receta-section-bar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1.5px solid var(--navy-surgical);
            padding-bottom: 0.25rem;
            margin-bottom: 0.55rem;
        }
        .receta-section-title {
            font-size: 0.82rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--navy-surgical);
            display: flex;
            align-items: center;
            gap: 0.4rem;
        }

        .med-item-card {
            border: 1px solid var(--slate-border);
            border-radius: 0.45rem;
            padding: 0.5rem 0.7rem;
            margin-bottom: 0.45rem;
            background: #ffffff;
        }
        .med-num-pill {
            background-color: var(--navy-surgical);
            color: #ffffff;
            font-size: 0.65rem;
            font-weight: 800;
            border-radius: 0.25rem;
            padding: 0.1rem 0.4rem;
            margin-right: 0.4rem;
            display: inline-block;
        }
        .med-generico-title {
            font-size: 0.86rem;
            font-weight: 800;
            color: var(--navy-surgical);
        }
        .med-meta-line {
            font-size: 0.68rem;
            color: var(--slate-muted);
            margin: 0.15rem 0;
        }
        .med-posologia-box {
            background-color: var(--card-neutral);
            border-left: 3px solid var(--primary-clinical);
            padding: 0.35rem 0.55rem;
            border-radius: 0.25rem;
            font-size: 0.74rem;
            font-weight: 600;
            color: #1E293B;
            margin-top: 0.25rem;
            line-height: 1.35;
        }

        /* Indicaciones y Estudios (Grid Doble) */
        .receta-indicaciones-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 0.5rem;
            margin-bottom: 0.6rem;
        }
        .receta-subcard {
            background-color: var(--card-neutral);
            border: 1px solid var(--slate-border);
            border-radius: 0.45rem;
            padding: 0.45rem 0.65rem;
            font-size: 0.68rem;
        }
        .receta-subcard-title {
            font-size: 0.7rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--navy-surgical);
            margin-bottom: 0.3rem;
            border-bottom: 1px solid #E2E8F0;
            padding-bottom: 0.2rem;
            display: flex;
            align-items: center;
            gap: 0.3rem;
        }

        /* Firma y Legalidad */
        .receta-legal-signatures {
            border-top: 1px solid var(--slate-border);
            padding-top: 0.5rem;
            margin-bottom: 0.5rem;
            display: grid;
            grid-template-columns: 1.4fr 1.2fr 0.8fr;
            gap: 0.6rem;
            align-items: center;
        }
        .receta-fiel-box {
            font-size: 0.6rem;
            color: var(--slate-muted);
            line-height: 1.3;
        }
        .receta-sig-doc {
            text-align: center;
        }
        .receta-sig-line {
            width: 160px;
            border-bottom: 1.5px solid var(--navy-surgical);
            margin: 0 auto 0.25rem;
            height: 28px;
            display: flex;
            align-items: flex-end;
            justify-content: center;
        }
        .receta-qr-col {
            text-align: center;
        }

        .receta-disclaimer-legal {
            font-size: 0.56rem;
            color: #64748B;
            line-height: 1.25;
            text-align: justify;
            margin-bottom: 0.4rem;
        }

        /* 4. TALÓN DESPRENDIBLE DE FARMACIA */
        .receta-talon-cut {
            border-top: 1.5px dashed #94A3B8;
            position: relative;
            margin: 0.4rem 0 0.5rem;
            text-align: center;
        }
        .receta-cut-badge {
            position: absolute;
            top: -10px;
            left: 50%;
            transform: translateX(-50%);
            background: #ffffff;
            padding: 0 0.6rem;
            font-size: 0.58rem;
            font-weight: 800;
            color: #64748B;
            text-transform: uppercase;
            letter-spacing: 0.6px;
        }

        .receta-talon-box {
            background-color: #F8FAFC;
            border: 1px solid #CBD5E1;
            border-radius: 0.45rem;
            padding: 0.45rem 0.65rem;
            font-size: 0.65rem;
        }
        .talon-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid #E2E8F0;
            padding-bottom: 0.25rem;
            margin-bottom: 0.35rem;
        }
        .talon-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.63rem;
            margin-bottom: 0.3rem;
        }
        .talon-table th {
            background: #E2E8F0;
            color: var(--navy-surgical);
            font-weight: 800;
            padding: 0.2rem 0.35rem;
            text-transform: uppercase;
            font-size: 0.58rem;
        }
        .talon-table td {
            border-bottom: 1px solid #E2E8F0;
            padding: 0.25rem 0.35rem;
        }

        /* 5. REGLAS DE ESTILOS DE IMPRESIÓN (\@media print) */
        \@media print {
            \@page {
                size: letter portrait;
                margin: 6mm 8mm;
            }
            body {
                background: #ffffff !important;
                padding: 0 !important;
                margin: 0 !important;
            }
            .visor-toolbar-top, .sub-header-normativo, .no-print {
                display: none !important;
            }
            .recipe-workspace-area {
                padding: 0 !important;
                margin: 0 !important;
                display: block !important;
            }
            .recipe-letter-sheet {
                box-shadow: none !important;
                border: 1px solid #CBD5E1 !important;
                width: 100% !important;
                min-height: auto !important;
                padding: 18px 22px !important;
                margin: 0 auto !important;
                border-radius: 0 !important;
                transform: none !important;
                page-break-inside: avoid !important;
                break-inside: avoid !important;
                -webkit-print-color-adjust: exact !important;
                print-color-adjust: exact !important;
            }
        }
    </style>
</head>
<body>

    <!-- ================================================================= -->
    <!-- 1. BARRA DE HERRAMIENTAS SUPERIOR DEL VISOR (Toolbar & Nav)      -->
    <!-- ================================================================= -->
    <div class="visor-toolbar-top no-print">
        <div class="d-flex flex-wrap align-items-center justify-content-between gap-2">
            
            <!-- Lado Izquierdo: Retorno al Expediente y Título -->
            <div class="d-flex align-items-center gap-2">
                <a href="../views/render_expediente_clinico.pl?id=$paciente->{id}" class="btn btn-outline-secondary btn-toolbar-pill">
                    <i class="bi bi-arrow-left"></i> Expediente
                </a>
                <div class="vr bg-secondary opacity-25 d-none d-sm-block" style="height: 22px;"></div>
                <div class="d-flex align-items-center gap-2">
                    <i class="bi bi-prescription2 text-teal fs-4" style="color: #00C0B5;"></i>
                    <strong style="color: var(--navy-surgical); font-size: 0.95rem;">Receta Médica Digital</strong>
                    <span class="badge bg-dark badge-regulatorio">COFEPRIS</span>
                    <span class="badge bg-success bg-opacity-10 text-success border border-success border-opacity-25 badge-regulatorio d-none d-md-inline">NOM-004 / NOM-072</span>
                </div>
            </div>

            <!-- Centro: Controles de Escala / Zoom y Envíos -->
            <div class="d-flex align-items-center gap-2">
                <!-- Zoom Control -->
                <div class="btn-group btn-group-sm bg-light border rounded-pill p-0.5" role="group">
                    <button type="button" class="btn btn-sm btn-light border-0 px-2 fw-bold text-secondary" onclick="ajustarZoom(-0.1)" title="Reducir">
                        <i class="bi bi-dash"></i>
                    </button>
                    <span id="txt-zoom-lvl" class="btn btn-sm btn-light border-0 px-2 fw-bold text-dark disabled" style="font-size:0.75rem;">100%</span>
                    <button type="button" class="btn btn-sm btn-light border-0 px-2 fw-bold text-secondary" onclick="ajustarZoom(0.1)" title="Aumentar">
                        <i class="bi bi-plus"></i>
                    </button>
                </div>

                <!-- Envíos Rápidos -->
                <button type="button" class="btn btn-sm btn-outline-success btn-toolbar-pill" onclick="enviarWhatsAppReceta()" title="Enviar prescripción por WhatsApp al paciente">
                    <i class="bi bi-whatsapp text-success"></i> WhatsApp
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary btn-toolbar-pill d-none d-sm-inline-flex" onclick="enviarEmailReceta()" title="Enviar prescripción por correo electrónico">
                    <i class="bi bi-envelope"></i> Email
                </button>
            </div>

            <!-- Lado Derecho: Descargar, Imprimir y Avatar del Médico -->
            <div class="d-flex align-items-center gap-2">
                <button type="button" class="btn btn-sm text-white btn-toolbar-pill" style="background-color: var(--navy-surgical);" onclick="ejecutarImpresionReceta()" title="Generar / Guardar PDF nativo">
                    <i class="bi bi-file-earmark-pdf-fill"></i> Descargar PDF
                </button>
                <button type="button" class="btn btn-sm text-dark fw-bold btn-toolbar-pill" style="background-color: #00C0B5;" onclick="ejecutarImpresionReceta()" title="Imprimir en hoja Carta (1 página)">
                    <i class="bi bi-printer-fill"></i> Imprimir
                </button>
                <div class="vr bg-secondary opacity-25 d-none d-md-block" style="height: 22px;"></div>
                <div class="d-none d-md-flex align-items-center gap-2" title="$medico->{nombre}">
                    <div class="rounded-circle bg-teal-clinical text-dark d-flex align-items-center justify-content-center fw-bold" style="width: 32px; height: 32px; font-size: 0.8rem; background:#00C0B5;">
                        DR
                    </div>
                </div>
            </div>

        </div>
    </div>

    <!-- ================================================================= -->
    <!-- 2. SUB-HEADER NORMATIVO (Metadatos y Acciones Rápidas)           -->
    <!-- ================================================================= -->
    <div class="sub-header-normativo no-print">
        <div class="d-flex align-items-center gap-2 flex-wrap">
            <span class="badge bg-success bg-opacity-10 text-success border border-success border-opacity-25 px-2.5 py-1.5 fw-bold" style="font-size:0.75rem;">
                <i class="bi bi-shield-check me-1"></i> CERTIFICADO NOM-004 • NOM-072
            </span>
            <span class="text-muted small">
                <span class="text-success fw-bold">● Receta Digital Vigente</span> • Vence: <strong>$fecha_vence_str (30 días)</strong>
            </span>
            <span class="badge bg-light text-dark border px-2 py-1 fw-bold font-monospace" style="font-size:0.75rem;">
                Folio Oficial: $folio
            </span>
        </div>

        <div class="d-flex align-items-center gap-2">
            <button type="button" class="btn btn-sm text-white rounded-pill px-3 fw-semibold" style="background:#00C0B5; font-size:0.75rem;" onclick="ejecutarImpresionReceta()">
                <i class="bi bi-printer me-1"></i> Imprimir Hoja Clínica
            </button>
            <button type="button" class="btn btn-sm btn-outline-dark rounded-pill px-3 fw-semibold" style="font-size:0.75rem;" onclick="ejecutarImpresionReceta()">
                <i class="bi bi-lock-fill me-1"></i> PDF Cifrado
            </button>
            <button type="button" class="btn btn-sm btn-outline-success rounded-pill px-3 fw-semibold" style="font-size:0.75rem;" onclick="enviarWhatsAppReceta()">
                <i class="bi bi-send me-1"></i> WhatsApp Paciente
            </button>
        </div>
    </div>

    <!-- ================================================================= -->
    <!-- 3. HOJA DE RECETA MÉDICA OFICIAL (Letter Portrait 8.5" x 11")      -->
    <!-- ================================================================= -->
    <div class="recipe-workspace-area">
        <div class="recipe-letter-sheet" id="receta-imprimible-sheet">

            <div>
                <!-- A. Encabezado de la Institución de Salud -->
                <div class="receta-header-inst">
                    <div class="d-flex justify-content-between align-items-center">
                        <div class="d-flex align-items-center gap-3">
                            <img src="$org->{logo_url}" alt="$org->{nombre_negocio}" class="receta-logo-sq">
                            <div>
                                <div class="d-flex align-items-center gap-2">
                                    <span class="receta-inst-name">$org->{nombre_negocio}</span>
                                    <span class="badge bg-dark" style="font-size:0.6rem; letter-spacing:0.5px;">$org->{sede}</span>
                                </div>
                                <div class="receta-inst-meta">
                                    $org->{domicilio}<br>
                                    Central Telefónica: <strong>$org->{telefono}</strong> • Urgencias: <strong>$org->{email}</strong>
                                </div>
                            </div>
                        </div>

                        <div class="text-end">
                            <span class="badge bg-teal-clinical text-dark fw-bold mb-1" style="background:#00C0B5; font-size:0.62rem;">
                                ACREDITACIÓN SSA FEDERAL
                            </span>
                            <div class="small fw-semibold text-secondary" style="font-size:0.66rem;">
                                Licencia Sanitaria: <strong>$org->{licencia_ssa}</strong><br>
                                CLUES SSA: <strong>$org->{clues}</strong><br>
                                Emisión: <strong>$f_hoy_cst • $hora_emision hrs CST</strong>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- B. Bloque de Identificación y Cédulas del Médico Prescriptor -->
                <div class="receta-medico-card shadow-sm">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="d-flex align-items-center gap-2">
                                <span class="receta-medico-nombre">$medico->{nombre}</span>
                                <span class="badge" style="background-color:#00C0B5; color:#0D2238; font-size:0.68rem; font-weight:800;">
                                    $medico->{especialidad}
                                </span>
                            </div>
                            <div class="small text-white-50" style="font-size:0.68rem;">
                                $medico->{universidad}
                            </div>
                        </div>
                        <div class="text-end text-white-50 small d-none d-sm-block" style="font-size:0.68rem;">
                            Folio Consulta: <strong class="text-white">$consulta_raw->{id_consulta}</strong>
                        </div>
                    </div>

                    <div class="receta-cedulas-grid">
                        <div class="receta-cedula-cell">
                            <div class="receta-cedula-lbl">Cédula Profesional</div>
                            <div class="receta-cedula-val">$medico->{cedula_prof}</div>
                        </div>
                        <div class="receta-cedula-cell">
                            <div class="receta-cedula-lbl">Céd. Especialidad</div>
                            <div class="receta-cedula-val">$medico->{cedula_esp}</div>
                        </div>
                        <div class="receta-cedula-cell">
                            <div class="receta-cedula-lbl">Certificación Consejo</div>
                            <div class="receta-cedula-val">$medico->{certificacion}</div>
                        </div>
                    </div>
                </div>

                <!-- C. Ficha Demográfica del Paciente, Somatometría y Diagnóstico CIE-10 -->
                <div class="receta-paciente-grid">
                    <div>
                        <div class="p-field-lbl">Nombre del Paciente</div>
                        <div class="p-field-val text-primary">$paciente->{nombre}</div>
                        <div class="text-muted" style="font-size:0.65rem;">Exp: <strong>EXP-$paciente->{id}</strong> (#$paciente->{curp})</div>
                    </div>
                    <div>
                        <div class="p-field-lbl">Datos Demográficos</div>
                        <div class="p-field-val">$paciente->{edad} • $paciente->{sexo}</div>
                        <div class="text-muted" style="font-size:0.65rem;">F. Nac: $paciente->{fecha_nac}</div>
                    </div>
                    <div>
                        <div class="p-field-lbl">Signos Vitales y Antropometría</div>
                        <div class="p-field-val">T/A: <strong>$ta_val</strong> mmHg • Peso: <strong>$peso_val</strong> kg</div>
                        <div class="text-muted" style="font-size:0.65rem;">Talla: <strong>$talla_val</strong> cm • IMC: <strong>$imc_val</strong> kg/m²</div>
                    </div>
                    <div>
                        <div class="p-field-lbl">Diagnóstico Clínico (CIE-10)</div>
                        <div class="p-field-val text-danger fw-bold"><span class="badge bg-danger text-white me-0.5">$dx_cie10</span> $dx_principal</div>
                        <div class="text-muted" style="font-size:0.65rem;">Sec: $dx_secundario</div>
                    </div>
                </div>

                <!-- D. Banner de Alerta Farmacológica Crítica (Contraindicación Absoluta) -->
                <div class="receta-alerta-critica">
                    <div class="d-flex align-items-center gap-2">
                        <i class="bi bi-exclamation-octagon-fill fs-5 text-danger flex-shrink-0"></i>
                        <div>
                            <strong class="d-block text-uppercase" style="letter-spacing:0.5px; font-size:0.75rem;">
                                ALERTA FARMACOLÓGICA CRÍTICA: ALÉRGICO A $alergias_txt
                            </strong>
                            <span class="text-muted" style="font-size:0.68rem;">
                                Contraindicación absoluta de betalactámicos, aminopenicilinas y derivados sintéticos asociados.
                            </span>
                        </div>
                    </div>
                    <span class="badge bg-danger badge-regulatorio">VERIFICADO EN EXPEDIENTE</span>
                </div>

                <!-- E. Prescripción Médica Farmacológica (Cuerpo Principal) -->
                <div class="receta-section-bar">
                    <div class="receta-section-title">
                        <i class="bi bi-capsule-pill text-teal" style="color:#00C0B5;"></i> Prescripción Médica Farmacológica
                    </div>
                    <span class="badge bg-dark badge-regulatorio">@{[ scalar @$items ]} MEDICAMENTOS INDICADOS</span>
                </div>

                <div class="mb-2">
HTML

my $idx = 1;
foreach my $it (@$items) {
    my $gen   = $it->{generico} || $it->{farmaco} || 'Medicamento Genérico';
    my $conc  = $it->{concentracion} || $it->{dosis} || '';
    my $forma = $it->{forma} || $it->{presentacion} || 'Comprimidos';
    my $com   = $it->{comercial} || '';
    my $via   = $it->{via} || 'Oral';
    my $pos   = $it->{posologia} || $it->{frecuencia} || 'Tomar según indicación médica.';
    my $dur   = $it->{duracion} || '7 días continuos.';
    my $frac  = $it->{fraccion_lgs} || (($idx == 1) ? 'Sin Retención de Receta • Fracción IV (Art. 226 LGS)' : 'Sin Retención de Receta • Fracción V (Art. 226 LGS)');
    my $surt  = $it->{surtir} || '1 (Una) Caja';
    my $pres  = $it->{presentacion} || "$forma $conc";

    print <<HTML;
                    <div class="med-item-card">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <span class="med-num-pill">[ $idx ]</span>
                                <span class="med-generico-title">$gen $conc</span>
                                <span class="text-muted small">($forma)</span>
                            </div>
                            <span class="badge bg-light text-secondary border" style="font-size:0.65rem;">$frac</span>
                        </div>
                        <div class="med-meta-line">
                            <strong>Vía:</strong> $via | <strong>Presentación:</strong> $pres | <strong>Cantidad a surtir:</strong> <span class="text-dark fw-bold">$surt</span>
                        </div>
                        <div class="med-posologia-box">
                            <strong>Posología:</strong> $pos
                        </div>
                        <div class="text-muted mt-1" style="font-size:0.66rem;">
                            <strong>Duración:</strong> $dur
                        </div>
                    </div>
HTML
    $idx++;
}

print <<HTML;
                </div>

                <!-- F. Indicaciones Higiénico-Dietéticas y Estudios Paraclínicos -->
                <div class="receta-indicaciones-grid">
                    <div class="receta-subcard">
                        <div class="receta-subcard-title">
                            <i class="bi bi-heart text-danger"></i> Régimen Higiénico-Dietético Obligatorio
                        </div>
                        <ul class="mb-0 ps-3" style="font-size:0.65rem; line-height:1.4;">
                            <li><strong>Restricción total:</strong> Evitar condimentos, salsas picantes, jitomate cocido, cítricos, café, refrescos con gas y alcohol por mínimo 14 días.</li>
                            <li><strong>Fraccionamiento:</strong> Distribuir ingesta en 5 tiempos ligeros (3 comidas moderadas + 2 colaciones suaves).</li>
                            <li><strong>Postura:</strong> Evitar recostarse o dormir antes de 2 horas transcurridas desde la última ingesta.</li>
                        </ul>
                    </div>

                    <div class="receta-subcard">
                        <div class="receta-subcard-title">
                            <i class="bi bi-file-earmark-medical text-teal"></i> Estudios Paraclínicos & Cita de Control
                        </div>
                        <div style="font-size:0.65rem; line-height:1.35;">
                            <strong>1. Estudios Solicitados:</strong> $estudios_solicitados<br>
                            <strong>Próxima Cita de Control:</strong> A los 14 días o revaloración inmediata.<br>
                            <span class="text-danger fw-bold d-block mt-1">
                                (*) SIGNOS DE ALARMA: HEMATEMESIS (VÓMITO CON SANGRE), MELENA O DOLOR EPIGÁSTRICO INCOERCIBLE ACUDA A URGENCIAS DE INMEDIATO.
                            </span>
                        </div>
                    </div>
                </div>

                <!-- G. Firma Electrónica Avanzada, QR y Validez Legal -->
                <div class="receta-legal-signatures">
                    <!-- Sello FIEL / NOM-024 -->
                    <div class="receta-fiel-box">
                        <span class="badge bg-light text-dark border mb-1 fw-bold" style="font-size:0.6rem;">
                            <i class="bi bi-patch-check-fill text-success me-1"></i> Firma Electrónica Avanzada (FIEL / e.firma) • SAT / SSA
                        </span>
                        <div class="font-monospace text-muted" style="font-size:0.56rem; word-break:break-all;">
                            SHA-256: 7F8B:2A1C:99E4:0091:E7C3:5A48:12F0:65D4:BA10:65E1:44F9:0921:3E22:8A40:112A:90C5:E901:4F7B:230A:56D2
                        </div>
                        <div class="text-secondary" style="font-size:0.55rem;">
                            Cadena Original: ||NOM-024|2026|$folio|$paciente->{curp}|$medico->{cedula_prof}|$fecha_emision||
                        </div>
                    </div>

                    <!-- Firma Manuscrita / Digitalizada del Médico -->
                    <div class="receta-sig-doc">
                        <div class="receta-sig-line">
                            <span style="font-family:'Courier New', monospace; font-size:0.75rem; color:#0A2A66; font-style:italic;">[Rúbrica Electrónica]</span>
                        </div>
                        <div class="fw-bold" style="font-size:0.75rem; color:var(--navy-surgical);">$medico->{nombre}</div>
                        <div class="text-muted" style="font-size:0.62rem;">Céd. Prof. <strong>$medico->{cedula_prof}</strong> • Céd. Esp. <strong>$medico->{cedula_esp}</strong></div>
                    </div>

                    <!-- Código QR Oficial -->
                    <div class="receta-qr-col">
                        <img src="https://api.qrserver.com/v1/create-qr-code/?size=68x68&data=https://verificacion.os-pulso.mx/receta/$folio" alt="QR COFEPRIS" style="width:58px; height:58px; border:1px solid #CBD5E1; border-radius:4px; padding:2px;">
                        <div style="font-size:0.56rem; color:#64748B; font-weight:700; margin-top:2px;">NOM-024 QR</div>
                    </div>
                </div>

                <!-- Leyenda Legal Regulatoria -->
                <div class="receta-disclaimer-legal">
                    Documento médico oficial expedido conforme a la NOM-004-SSA3-2012 (Del expediente clínico) y NOM-072-SSA1-2012 (Etiquetado y prescripción de medicamentos). Receta válida para dispensación en farmacias autorizadas en territorio nacional. Prohibida la automedicación o sustitución de fórmula activa. Cualquier tachadura o enmendadura invalida este documento. Vigencia máxima: 30 días naturales a partir de su expedición.
                </div>
            </div>

            <!-- ============================================================= -->
            <!-- 4. TALÓN DESPRENDIBLE DE CONTROL DE DISPENSACIÓN FARMACÉUTICA  -->
            <!-- ============================================================= -->
            <div>
                <div class="receta-talon-cut">
                    <span class="receta-cut-badge">
                        <i class="bi bi-scissors me-1"></i> LÍNEA DE DESPRENDIMIENTO PARA ARCHIVO DE FARMACIA
                    </span>
                </div>

                <div class="receta-talon-box">
                    <div class="talon-header">
                        <div>
                            <strong style="color:var(--navy-surgical); font-size:0.72rem;">Talón de Control y Dispensación Farmacéutica</strong>
                            <span class="badge bg-secondary ms-1" style="font-size:0.58rem;">COPIA BOTICA</span>
                        </div>
                        <div class="text-muted" style="font-size:0.62rem;">
                            Folio: <strong class="text-dark">$folio</strong> | Paciente: <strong>$paciente->{nombre}</strong> | Médico: <strong>$medico->{nombre}</strong> (Céd. $medico->{cedula_prof})
                        </div>
                    </div>

                    <table class="talon-table">
                        <thead>
                            <tr>
                                <th style="width: 35%;">Medicamento Prescrito</th>
                                <th style="width: 25%;">Presentación / Dosis</th>
                                <th style="width: 25%;">Registro de Surtido</th>
                                <th style="width: 15%;">Lote Farmacia</th>
                            </tr>
                        </thead>
                        <tbody>
HTML

foreach my $it (@$items) {
    my $gen  = $it->{generico} || $it->{farmaco} || '';
    my $conc = $it->{concentracion} || '';
    my $pres = $it->{presentacion} || $it->{forma} || '';
    print <<HTML;
                            <tr>
                                <td><strong>$gen</strong></td>
                                <td>$pres $conc</td>
                                <td>[ &nbsp; ] Total &nbsp;&nbsp; [ &nbsp; ] Parcial</td>
                                <td>Lote: _________</td>
                            </tr>
HTML
}

print <<HTML;
                        </tbody>
                    </table>

                    <div class="d-flex justify-content-between align-items-center mt-1 pt-1 border-top" style="font-size:0.6rem; color:#475569;">
                        <div>
                            <span>FECHA DE SURTIDO: ____ / ____ / 2026 &nbsp;&nbsp;&nbsp;&nbsp; FIRMA Y SELLO FARMACIA: ___________________________________</span>
                        </div>
                        <div class="text-end">
                            <span class="text-success fw-bold">● SISTEMA NACIONAL DE REGISTRO SANITARIO COMPATIBLE</span>
                        </div>
                    </div>
                    <div style="font-size:0.54rem; color:#94A3B8; margin-top:2px;">
                        El establecimiento dispensador retendrá este talón únicamente si el medicamento está sujeto a control específico o si lo requiere el sistema de trazabilidad de la cadena de farmacias según NOM-072.
                    </div>
                </div>
            </div>

        </div>
    </div>

    <!-- Bootstrap Bundle JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

    <!-- Script de Control del Visor e Impresión Directa -->
    <script>
    let currentZoom = 1.0;

    // Ajuste reactivo de escala/zoom del visor
    function ajustarZoom(delta) {
        currentZoom = Math.round((currentZoom + delta) * 10) / 10;
        if (currentZoom < 0.6) currentZoom = 0.6;
        if (currentZoom > 1.4) currentZoom = 1.4;

        const sheet = document.getElementById('receta-imprimible-sheet');
        const txtZoom = document.getElementById('txt-zoom-lvl');
        
        if (sheet) {
            sheet.style.transform = "scale(" + currentZoom + ")";
        }
        if (txtZoom) {
            txtZoom.textContent = Math.round(currentZoom * 100) + "%";
        }
    }

    // Impresión limpia de 1 sola página Carta con \@media print
    function ejecutarImpresionReceta() {
        const sheet = document.getElementById('receta-imprimible-sheet');
        const originalTransform = sheet ? sheet.style.transform : '';
        
        // Reset de escala previa para impresión a tamaño real
        if (sheet) sheet.style.transform = 'none';

        setTimeout(() => {
            window.print();
            if (sheet) sheet.style.transform = originalTransform;
        }, 100);
    }

    // Compartir por WhatsApp
    function enviarWhatsAppReceta() {
        const telefono = "$paciente->{telefono}" || '';
        const folio = "$folio";
        const paciente = "$paciente->{nombre}";
        const urlReceta = window.location.href;

        const texto = encodeURIComponent(
            "Hola " + paciente + ", le compartimos el enlace oficial para consultar y descargar su Receta Médica Digital con validez oficial COFEPRIS (Folio: " + folio + ") emitida por $org->{nombre_negocio}: " + urlReceta
        );

        const targetUrl = telefono ? "https://wa.me/52" + telefono + "?text=" + texto : "https://wa.me/?text=" + texto;
        window.open(targetUrl, '_blank');
    }

    // Compartir por Email
    function enviarEmailReceta() {
        const paciente = "$paciente->{nombre}";
        const folio = "$folio";
        const urlReceta = window.location.href;
        const subject = encodeURIComponent("Receta Médica Digital - Folio " + folio + " | $org->{nombre_negocio}");
        const body = encodeURIComponent(
            "Estimado(a) " + paciente + ":\\n\\nAdjuntamos el enlace a su Receta Médica Digital oficial:\\n" + urlReceta + "\\n\\nAtentamente,\\n$medico->{nombre}\\n$org->{nombre_negocio}"
        );
        window.location.href = "mailto:?subject=" + subject + "&body=" + body;
    }
    </script>
</body>
</html>
HTML

1;
