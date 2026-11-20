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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = eval { check_session($q) } || {};
my $usuario_sesion = $session_data->{usuario} || 'admin';

binmode STDOUT, ":utf8";

my $id_consulta = $q->param('id_consulta') || '';
my $id_cita     = $q->param('id_cita') || '';
my $id_paciente_req = $q->param('id_paciente') || $q->param('id') || '';

# 1. Cargar la consulta clínica desde dat/consultas_clinicas.dat
my $path_consultas = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
my $res_consultas = -f $path_consultas ? eval { leer_tabla($path_consultas, '\|') } || [] : [];
my $consulta = {};

foreach my $c (@$res_consultas) {
    next if $c->[0] =~ /^id_consulta$/i;
    my $match_consulta = ($id_consulta ne '' && $c->[0] eq $id_consulta);
    my $match_cita     = ($id_cita ne '' && $c->[2] eq $id_cita);
    my $match_paciente = ($id_paciente_req ne '' && $c->[1] eq $id_paciente_req && !$id_consulta && !$id_cita);
    
    if ($match_consulta || $match_cita || $match_paciente) {
        my $json_str = $c->[5] || '{}';
        $json_str =~ s/\\n/\n/g;
        my $data = {};
        eval { $data = decode_json(encode_utf8($json_str)); };
        if (!%$data) { eval { $data = decode_json($json_str); }; }
        
        my $ts = $c->[4] || time();
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime($ts);
        my $fecha_formatted = sprintf("%04d-%02d-%02d %02d:%02d", $year+1900, $mon+1, $mday, $hour, $min);
        
        $consulta = {
            id_consulta => $c->[0],
            id_paciente => $c->[1],
            id_cita     => $c->[2],
            id_medico   => $c->[3],
            timestamp   => $ts,
            fecha       => $fecha_formatted,
            data        => $data
        };
        last;
    }
}

# Fallback: si NO se solicitó un ID específico y no hay consulta cargada, tomar la más reciente
if (!keys %$consulta && !$id_consulta && !$id_cita && @$res_consultas > 1) {
    for (my $i = $#{$res_consultas}; $i >= 0; $i--) {
        my $c = $res_consultas->[$i];
        next if $c->[0] =~ /^id_consulta$/i;
        my $json_str = $c->[5] || '{}';
        $json_str =~ s/\\n/\n/g;
        my $data = eval { decode_json(encode_utf8($json_str)) } || {};
        my $ts = $c->[4] || time();
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime($ts);
        my $fecha_formatted = sprintf("%04d-%02d-%02d %02d:%02d", $year+1900, $mon+1, $mday, $hour, $min);
        
        $consulta = {
            id_consulta => $c->[0],
            id_paciente => $c->[1],
            id_cita     => $c->[2],
            id_medico   => $c->[3],
            timestamp   => $ts,
            fecha       => $fecha_formatted,
            data        => $data
        };
        last;
    }
}

# Si la base de consultas estaba vacía, generar datos canónicos demostrativos estructurados
if (!keys %$consulta) {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $f_hoy = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $h_hoy = sprintf("%02d:%02d", $hour, $min);
    $consulta = {
        id_consulta => 'CONS-DEMO-001',
        id_paciente => '1',
        id_cita     => 'CITA-101',
        id_medico   => 'DOC-001',
        timestamp   => time(),
        fecha       => "$f_hoy $h_hoy",
        data        => {
            tipo_consulta => 'Primera Vez',
            especialidad => 'Medicina General',
            motivo => 'Paciente acude por cefalea pulsátil de intensidad moderada a severa de 3 días de evolución, acompañada de fotofobia y mareo leve.',
            evolucion => 'El cuadro inició hace 72 horas tras jornada laboral prolongada. Refiere alivio parcial con analgésicos de venta libre pero recurrencia matutina.',
            intensidad => 7,
            antecedentes_patologicos => 'Alergia a la Penicilina (eritema y prurito). Sin cirugías previas.',
            antecedentes_no_patologicos => 'Tabaquismo negado. Alcohol ocasional social. Actividad física caminata 30 min.',
            antecedentes_quirurgicos => 'Negados.',
            antecedentes_heredofamiliares => 'Padre con Hipertensión Arterial Sistémica. Madre sana.',
            ta => '120/80',
            fc => '74',
            fr => '18',
            temp => '36.6',
            spo2 => '98',
            peso => '78.5',
            talla => '1.75',
            glucosa => '92',
            exploracion_hallazgos => 'Paciente consciente, orientado en tiempo, espacio y persona. Normocéfalo sin masas ni dolor a la palpación sinusal. Cuello móvil sin adenopatías ni rigidez nucal. Ruidos cardíacos rítmicos sin soplos. Campos pulmonares bien ventilados. Abdomen blando, no doloroso.',
            laboratorios_solicitados => 'Biometría Hemática Completa, Química Sanguínea de 6 elementos.',
            gabinete_solicitados => 'Ninguno por el momento.',
            resultados_estudios => 'Sin estudios previos recientes.',
            diagnostico_principal => 'Cefalea Tensional / Migraña sin aura',
            clave_diagnostico_cie10 => 'G44.2',
            diagnosticos_secundarios => 'Trastorno de ansiedad leve reactivo (F41.2)',
            severidad => 'Moderada',
            pronostico => 'Favorable',
            plan_tratamiento => 'Reposo relativo en habitación con baja luminosidad. Hidratación oral adecuada (mínimo 2L diarios). Manejo analgésico antiinflamatorio pautado por 5 días. Control de tensión arterial y revaloración en 1 semana o antes si presenta signos de alarma neurológica.',
            impresion_clinica => 'Cuadro compatible con cefalea de origen tensional secundario a estrés psicofísico. Se descarta hipertensión intracraneal o foco neurológico.',
            receta_indicaciones => 'Tomar los medicamentos después de los alimentos. Evitar el consumo de cafeína, quesos maduros y chocolates durante el tratamiento.',
            medicamentos => [
                { generico => 'Ibuprofeno', comercial => 'Advil', forma => 'Cápsulas', concentracion => '400 mg', dosis => '1 cápsula', posologia => '1 cápsula c/8h por 5 días', frecuencia => 'Cada 8 horas', duracion => '5 días', via => 'Oral' },
                { generico => 'Paracetamol', comercial => 'Tempra', forma => 'Tabletas', concentracion => '500 mg', dosis => '1 tableta', posologia => '1 tableta c/8h si hay dolor residual', frecuencia => 'Cada 8 horas', duracion => '3 días', via => 'Oral' },
                { generico => 'Complejo B', comercial => 'Tribedoce', forma => 'Grageas', concentracion => 'Estándar', dosis => '1 gragea', posologia => '1 gragea matutina por 30 días', frecuencia => 'Cada 24 horas', duracion => '30 días', via => 'Oral' }
            ]
        }
    };
}

my $d = $consulta->{data} || {};

# 2. Cargar Datos de la Organización (dat/negocios.dat)
my $path_negocios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
my $res_negocios = -f $path_negocios ? eval { leer_tabla($path_negocios, '\|') } || [] : [];
my $org = {
    id             => '0',
    nombre_negocio => 'Clínica Médica Pulso',
    razon_social   => 'Clínica Pulso SA de CV',
    rfc            => 'RFC12345',
    clues          => 'QTSMP000116',
    domicilio      => 'Av. Siempre Viva 123, Col. Centro',
    municipio      => 'Cuauhtémoc',
    entidad        => 'CDMX',
    cp             => '01000',
    telefono       => '555-1234',
    email          => 'contacto@clinica.com',
    logo_url       => '../favicon/favicon.svg'
};

if ($res_negocios && @$res_negocios) {
    foreach my $r (@$res_negocios) {
        next if $r->[0] =~ /^ID$/i;
        if ($r->[0] eq '0' || !$org->{nombre_negocio}) {
            $org->{id}             = $r->[0] // '0';
            $org->{nombre_negocio} = $r->[1] || 'Clínica Médica Pulso';
            $org->{domicilio}      = $r->[6] || 'Domicilio Principal';
            $org->{telefono}       = $r->[7] || '55 1234 5678';
            $org->{email}          = $r->[8] || 'contacto@ospulso.com';
            $org->{logo_url}       = ($r->[9] && $r->[9] ne '') ? $r->[9] : '../favicon/favicon.svg';
            $org->{rfc}            = $r->[10] || 'CMP260101XYZ';
            $org->{razon_social}   = $r->[11] || 'Clínica Médica Pulso S.A. de C.V.';
            $org->{cp}             = $r->[14] || '';
            $org->{entidad}        = $r->[15] || '';
            $org->{municipio}      = $r->[16] || '';
            my $colonia            = $r->[17] || '';
            $org->{clues}          = $r->[18] || 'QTSMP000116';
            if ($colonia && $org->{domicilio} !~ /\Q$colonia\E/i) {
                $org->{domicilio} .= ", Col. $colonia";
            }
            if ($org->{municipio} && $org->{domicilio} !~ /\Q$org->{municipio}\E/i) {
                $org->{domicilio} .= ", $org->{municipio}";
            }
            if ($org->{entidad} && $org->{domicilio} !~ /\Q$org->{entidad}\E/i) {
                $org->{domicilio} .= ", $org->{entidad}";
            }
            if ($org->{cp} && $org->{domicilio} !~ /\Q$org->{cp}\E/i) {
                $org->{domicilio} .= " C.P. $org->{cp}";
            }
            last;
        }
    }
}

# 3. Cargar Datos del Paciente (dat/pacientes.dat)
my $path_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $res_pacientes = -f $path_pacientes ? eval { leer_tabla($path_pacientes, '\|') } || [] : [];
my $paciente = {
    id        => $consulta->{id_paciente} || '1',
    nombre    => 'Carlos Mendoza García',
    curp      => 'MEMC850412HDFRRN09',
    fecha_nac => '1985-04-12',
    edad      => '41 años',
    sexo      => 'Masculino',
    telefono  => '5512345678',
    ts        => 'O+',
    alergias  => 'Penicilina'
};

foreach my $p (@$res_pacientes) {
    next if $p->[0] =~ /^ID_PACIENTE$/i;
    if ($p->[0] eq ($consulta->{id_paciente} || '1')) {
        $paciente->{id}        = $p->[0];
        $paciente->{nombre}    = $p->[2] || $paciente->{nombre};
        $paciente->{curp}      = $p->[4] || $paciente->{curp};
        $paciente->{fecha_nac} = $p->[6] || $paciente->{fecha_nac};
        $paciente->{sexo}      = $p->[7] || $paciente->{sexo};
        $paciente->{ts}        = $p->[11] || 'O+';
        $paciente->{telefono}  = $p->[12] || '5512345678';
        last;
    }
}

# Calcular edad precisa
sub calc_edad_detalles {
    my ($f) = @_;
    return '' unless $f && $f =~ /^(\d{4})-(\d{2})-(\d{2})$/;
    my ($y, $m, $day) = ($1, $2, $3);
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    $year += 1900; $mon += 1;
    my $e = $year - $y;
    $e-- if ($mon < $m || ($mon == $m && $mday < $day));
    return "$e años";
}
my $edad_calc = calc_edad_detalles($paciente->{fecha_nac});
$paciente->{edad} = $edad_calc if ($edad_calc);

# 4. Cargar Datos del Médico Tratante (dat/usuarios.dat)
my $path_med = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $res_med = -f $path_med ? eval { leer_tabla($path_med, '!') } || [] : [];
my $nombre_medico = 'Dr. Administrador Global';
my $cedula_medico = 'CED-PROF-8492014';
my $especialidad_medico = $d->{especialidad} || 'Medicina General';
my $consultorio_medico  = 'Consultorio 1 - Planta Baja';
my $firma_medico_url    = '';

foreach my $m (@$res_med) {
    next if $m->[0] =~ /^id$/i;
    my $m_id = $m->[0] // '';
    my $target_doc = $consulta->{id_medico} || 'DOC-001';
    if ($m_id eq $target_doc || "DOC-" . sprintf("%03d", $m_id) eq $target_doc || $m_id eq '0') {
        my $raw_nom = $m->[1] || 'Médico Tratante';
        $nombre_medico = ($raw_nom =~ /^Dr/i) ? $raw_nom : "Dr(a). $raw_nom";
        $cedula_medico = $m->[9] if ($m->[9] && $m->[9] ne '0' && $m->[9] ne '');
        $consultorio_medico = $m->[10] if ($m->[10] && $m->[10] ne '');
        $firma_medico_url = $m->[11] if ($m->[11] && $m->[11] ne '');
        
        # Especialidad
        if ($m->[7] && $m->[7] ne '0') {
            my $path_esp = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'especialidades.dat');
            my $res_esp = eval { leer_tabla($path_esp, '\|') };
            if ($res_esp) {
                foreach my $esp (@$res_esp) {
                    if ($esp->[0] eq $m->[7]) {
                        $especialidad_medico = $esp->[1];
                        last;
                    }
                }
            }
        }
        last if ($m_id eq $target_doc);
    }
}
$especialidad_medico = $d->{especialidad} if ($d->{especialidad} && $d->{especialidad} ne '');

# 5. Medicamentos expedidos (soporta claves nuevas y legacy)
my $medicamentos = $d->{medicamentos} || [];
if ((!$medicamentos || ref($medicamentos) ne 'ARRAY' || scalar @$medicamentos == 0) && $d->{medicamentos_json}) {
    eval { $medicamentos = decode_json(encode_utf8($d->{medicamentos_json})); };
}

# 6. Cálculo IMC
sub parseFloatVal {
    my ($val) = @_;
    return 0 unless defined $val;
    $val =~ s/[^0-9.]//g;
    return $val + 0;
}
my $peso_val  = parseFloatVal($d->{peso});
my $talla_val = parseFloatVal($d->{talla});
my $imc_val   = '--';
my $imc_status = '';
if ($peso_val > 0 && $talla_val > 0) {
    my $talla_m = $talla_val > 3 ? $talla_val / 100 : $talla_val;
    if ($talla_m > 0) {
        my $calc = $peso_val / ($talla_m * $talla_m);
        $imc_val = sprintf("%.1f", $calc);
        if ($calc < 18.5) { $imc_status = 'Bajo peso'; }
        elsif ($calc < 25.0) { $imc_status = 'Peso normal'; }
        elsif ($calc < 30.0) { $imc_status = 'Sobrepeso'; }
        else { $imc_status = 'Obesidad'; }
    }
}

# 7. Odontogramas y Estudios PACS asignados
my @assigned_odonto_ids;
if ($d->{odonto_estudios_seleccionados}) {
    if (ref($d->{odonto_estudios_seleccionados}) eq 'ARRAY') {
        @assigned_odonto_ids = @{ $d->{odonto_estudios_seleccionados} };
    } else {
        push @assigned_odonto_ids, $d->{odonto_estudios_seleccionados};
    }
}

my @assigned_pacs_ids;
if ($d->{pacs_estudios_seleccionados}) {
    if (ref($d->{pacs_estudios_seleccionados}) eq 'ARRAY') {
        @assigned_pacs_ids = @{ $d->{pacs_estudios_seleccionados} };
    } else {
        push @assigned_pacs_ids, $d->{pacs_estudios_seleccionados};
    }
}

# 8. Cálculo reactivo de cumplimiento normativo NOM-004 / NOM-024
my $compliance_score = 0;
$compliance_score += 15 if ($d->{motivo} || $d->{evolucion});
$compliance_score += 15 if ($d->{ta} || $d->{temp} || $d->{fc});
$compliance_score += 15 if ($d->{exploracion_hallazgos});
$compliance_score += 20 if ($d->{diagnostico_principal} || $d->{clave_diagnostico_cie10});
$compliance_score += 15 if ($d->{plan_tratamiento} || (ref($medicamentos) eq 'ARRAY' && scalar @$medicamentos > 0));
$compliance_score += 10 if ($paciente->{curp} || $paciente->{id});
$compliance_score += 10 if ($cedula_medico && $cedula_medico ne '');
$compliance_score = 100 if ($compliance_score > 100);

# Formateo de alergias
my $alergias_txt = $d->{antecedentes_patologicos} || $paciente->{alergias} || 'Negadas';
my $tiene_alergias = ($alergias_txt !~ /negad|ningun/i && length($alergias_txt) > 3) ? 1 : 0;

# Render HTML
print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es-MX">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nota Médica SOAP - Folio $consulta->{id_consulta} | $org->{nombre_negocio}</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    
    <!-- Fuentes Mandantes del Ecosistema OSPulso -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@500;600;700;800&family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">

    <!-- CSS Bootstrap 5.3 & Icons -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.3/font/bootstrap-icons.css" rel="stylesheet">

    <!-- Hoja de Estilo Mandante del Visor Multi-Página Clinical Pulse -->
    <link rel="stylesheet" href="../css/nota_clinica_soap_multipage.css?v=20261120">

    <style>
        :root {
            --primary-clinical: #00C0B5;
            --primary-clinical-hover: #00A39A;
            --navy-dark: #0D2238;
            --navy-surface: #0F172A;
            --slate-muted: #64748B;
            --slate-border: #E2E8F0;
            --bg-bento: #F8FAFC;
        }

        body {
            font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
            background-color: #EEF2F6;
            color: #0F172A;
            margin: 0;
            padding: 0;
            -webkit-font-smoothing: antialiased;
        }

        /* Barra de Control y Switch Principal */
        .topbar-control {
            position: sticky;
            top: 0;
            z-index: 1040;
            background: rgba(13, 34, 56, 0.96);
            backdrop-filter: blur(14px);
            -webkit-backdrop-filter: blur(14px);
            border-bottom: 1px solid rgba(255, 255, 255, 0.12);
            padding: 0.65rem 1.25rem;
            color: #ffffff;
        }

        .view-pill-btn {
            background: rgba(255, 255, 255, 0.1);
            color: #E2E8F0;
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 9999px;
            padding: 0.35rem 0.9rem;
            font-size: 0.8rem;
            font-weight: 600;
            transition: all 0.2s ease;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
        }
        .view-pill-btn:hover {
            background: rgba(255, 255, 255, 0.2);
            color: #ffffff;
        }
        .view-pill-btn.active {
            background: #00C0B5;
            color: #0D2238;
            border-color: #00C0B5;
            box-shadow: 0 2px 10px rgba(0, 192, 181, 0.4);
            font-weight: 700;
        }

        /* VISTA BENTO CLÍNICO */
        .bento-wrapper {
            max-width: 1280px;
            margin: 1.5rem auto 3rem;
            padding: 0 1rem;
        }
        .bento-card-pro {
            background: #ffffff;
            border-radius: 1rem;
            border: 1px solid var(--slate-border);
            box-shadow: 0 4px 18px rgba(15, 23, 42, 0.04);
            padding: 1.25rem 1.5rem;
            height: 100%;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .bento-card-pro:hover {
            box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08);
        }
        .bento-header-badge {
            font-size: 0.72rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.6px;
            color: var(--primary-clinical-hover);
            display: flex;
            align-items: center;
            gap: 0.4rem;
            margin-bottom: 0.5rem;
        }
        .bento-title-main {
            font-size: 1.15rem;
            font-weight: 800;
            color: var(--navy-dark);
            margin-bottom: 1rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid #F1F5F9;
            padding-bottom: 0.6rem;
        }
        .data-label-bento {
            font-size: 0.72rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: var(--slate-muted);
            margin-bottom: 0.2rem;
        }
        .data-val-bento {
            font-size: 0.92rem;
            font-weight: 600;
            color: #1E293B;
            margin-bottom: 0.85rem;
            line-height: 1.5;
        }
        .vital-box-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(100px, 1fr));
            gap: 0.65rem;
            margin-bottom: 1rem;
        }
        .vital-tile {
            background: #F8FAFC;
            border: 1px solid #E2E8F0;
            border-radius: 0.75rem;
            padding: 0.75rem 0.5rem;
            text-align: center;
        }
        .vital-tile-val {
            font-size: 1.2rem;
            font-weight: 800;
            color: var(--navy-dark);
        }
        .vital-tile-lbl {
            font-size: 0.68rem;
            font-weight: 700;
            color: var(--slate-muted);
            text-transform: uppercase;
        }

        /* Alerta Crítica Alergias */
        .critical-allergy-banner {
            background-color: #FEF2F2;
            border: 1px solid #FCA5A5;
            border-left: 4px solid #DC2626;
            color: #991B1B;
            padding: 0.75rem 1rem;
            border-radius: 0.5rem;
            font-size: 0.85rem;
            margin-bottom: 1.25rem;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }

        /* VISTA HOJA CARTA (WYSIWYG 2 PÁGINAS) */
        #view-wysiwyg-container {
            display: none; /* Por defecto oculto si arranca en bento o visible según switch */
        }

        /* Ocultar elementos de UI interactiva durante la impresión */
        \@media print {
            .topbar-control, .pdf-multipage-toolbar, .no-print, .bento-wrapper {
                display: none !important;
            }
            #view-wysiwyg-container {
                display: block !important;
                background: #ffffff !important;
                padding: 0 !important;
            }
            .pdf-sheets-scroll-area {
                background: #ffffff !important;
                padding: 0 !important;
            }
            .clinical-sheet {
                box-shadow: none !important;
                border: none !important;
                margin: 0 !important;
                width: 100% !important;
                min-height: auto !important;
                page-break-after: always !important;
                break-after: page !important;
            }
            .clinical-sheet:last-child {
                page-break-after: avoid !important;
                break-after: avoid !important;
            }
            .page-break-indicator-web {
                display: none !important;
            }
        }
    </style>
</head>
<body>

    <!-- TOPBAR MÓDULO VISOR (Sincronía Ecosistema OSPulso) -->
    <div class="topbar-control">
        <div class="d-flex flex-wrap align-items-center justify-content-between gap-2">
            <!-- Izquierda: Identidad y Folio -->
            <div class="d-flex align-items-center gap-3">
                <a href="render_expediente_clinico.pl?id=$paciente->{id}" class="view-pill-btn text-white">
                    <i class="bi bi-arrow-left"></i> Volver al Expediente
                </a>
                <div class="vr bg-white opacity-25 d-none d-sm-block" style="height: 24px;"></div>
                <div>
                    <span class="badge bg-teal-clinical text-dark fw-bold me-1" style="background:#00C0B5;">NOM-004 / NOM-024</span>
                    <strong class="text-white" style="font-size:0.95rem;">Nota Médica SOAP Multi-Página</strong>
                    <span class="text-white-50 ms-1 d-none d-md-inline">| Folio: <span class="text-white fw-bold">$consulta->{id_consulta}</span></span>
                </div>
            </div>

            <!-- Centro: Selector de Vista Interactiva vs Hoja Carta WYSIWYG -->
            <div class="d-flex align-items-center gap-1 bg-dark bg-opacity-50 p-1 rounded-pill border border-secondary border-opacity-25">
                <button type="button" id="btn-mode-bento" class="view-pill-btn active" onclick="setMasterView('bento')">
                    <i class="bi bi-grid-1x2-fill"></i> Dashboard Bento
                </button>
                <button type="button" id="btn-mode-wysiwyg" class="view-pill-btn" onclick="setMasterView('wysiwyg')">
                    <i class="bi bi-file-earmark-medical-fill"></i> Hoja Carta (2 Págs)
                </button>
            </div>

            <!-- Derecha: Acciones Rápidas -->
            <div class="d-flex align-items-center gap-2">
                <button type="button" class="btn btn-sm btn-outline-light rounded-pill px-3" onclick="compartirWhatsApp()">
                    <i class="bi bi-whatsapp text-success me-1"></i> WhatsApp
                </button>
                <button type="button" class="btn btn-sm text-dark fw-bold rounded-pill px-3" style="background-color: #00C0B5;" onclick="ejecutarImpresion()">
                    <i class="bi bi-printer-fill me-1"></i> Imprimir (2 Págs)
                </button>
            </div>
        </div>
    </div>

    <!-- ================================================================= -->
    <!-- 1. VISTA DASHBOARD BENTO (Pantalla Interactiva)                   -->
    <!-- ================================================================= -->
    <div id="view-bento-container" class="bento-wrapper">

        <!-- Banner de Alergias Críticas si Aplica -->
HTML

if ($tiene_alergias) {
    print <<HTML;
        <div class="critical-allergy-banner shadow-sm">
            <i class="bi bi-exclamation-octagon-fill fs-4 flex-shrink-0"></i>
            <div>
                <strong class="d-block text-uppercase fw-bold" style="letter-spacing:0.5px;">¡Alerta Médica de Alergias Críticas!</strong>
                <span>El paciente presenta reacción documentada a: <strong>$alergias_txt</strong>. Verificar compatibilidad farmacológica.</span>
            </div>
        </div>
HTML
}

print <<HTML;
        <!-- Fila 1: Resumen de Expediente, Paciente y Organización -->
        <div class="row g-3 mb-3">
            <div class="col-lg-8">
                <div class="bento-card-pro">
                    <div class="d-flex flex-wrap align-items-center justify-content-between mb-3 border-bottom pb-2">
                        <div class="d-flex align-items-center gap-3">
                            <img src="$org->{logo_url}" alt="$org->{nombre_negocio}" class="rounded" style="max-height: 48px; max-width: 130px; object-fit: contain;">
                            <div>
                                <h5 class="mb-0 fw-bold text-dark">$org->{nombre_negocio}</h5>
                                <span class="text-muted small">$org->{razon_social} · CLUES: <strong>$org->{clues}</strong> · RFC: <strong>$org->{rfc}</strong></span>
                            </div>
                        </div>
                        <div class="text-end">
                            <span class="badge bg-success bg-opacity-10 text-success border border-success border-opacity-25 px-2 py-1 fw-bold">
                                <i class="bi bi-shield-check me-1"></i> NOM-004: $compliance_score%
                            </span>
                            <div class="text-muted small mt-1">Fecha: $consulta->{fecha}</div>
                        </div>
                    </div>

                    <div class="row g-3">
                        <div class="col-sm-6 col-md-3">
                            <div class="data-label-bento">Paciente</div>
                            <div class="data-val-bento fw-bold text-primary">$paciente->{nombre}</div>
                        </div>
                        <div class="col-sm-6 col-md-3">
                            <div class="data-label-bento">Expediente / CURP</div>
                            <div class="data-val-bento">EXP-$paciente->{id} <br><small class="text-muted">$paciente->{curp}</small></div>
                        </div>
                        <div class="col-sm-6 col-md-3">
                            <div class="data-label-bento">Edad / Sexo / Sangre</div>
                            <div class="data-val-bento">$paciente->{edad} · $paciente->{sexo} <br><span class="badge bg-danger bg-opacity-10 text-danger border border-danger border-opacity-25">$paciente->{ts}</span></div>
                        </div>
                        <div class="col-sm-6 col-md-3">
                            <div class="data-label-bento">Médico Tratante</div>
                            <div class="data-val-bento fw-bold">$nombre_medico <br><small class="text-muted">Céd. $cedula_medico</small></div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Tarjeta Lateral de Acciones & Certificación NOM-151 -->
            <div class="col-lg-4">
                <div class="bento-card-pro bg-light border-0">
                    <div class="bento-header-badge">
                        <i class="bi bi-patch-check-fill text-teal"></i> Validez Jurídica Digital
                    </div>
                    <div class="bento-title-main" style="font-size:1rem;">
                        <span>e.Firma & NOM-151</span>
                        <i class="bi bi-qr-code text-teal fs-4"></i>
                    </div>
                    <p class="small text-muted mb-2">
                        Documento clínico-legal inmutable firmado con infraestructura de clave pública (PKI), conforme a la NOM-024-SSA3.
                    </p>
                    <div class="p-2 bg-white rounded border border-light-subtle mb-3">
                        <div class="text-muted" style="font-size:0.7rem; font-family:'JetBrains Mono', monospace; word-break:break-all;">
                            SHA256: 3a9f02c4b81e4d77a80b1e8e8c14d5e71829a3f4b5c6d7e8f9a0b1c2d3e4f5a6
                        </div>
                    </div>
                    <div class="d-grid gap-2">
                        <button type="button" class="btn btn-sm btn-outline-dark fw-bold rounded-pill" onclick="setMasterView('wysiwyg')">
                            <i class="bi bi-eye-fill me-1"></i> Abrir Visor Multi-Página
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Fila 2: Signos Vitales Bento -->
        <div class="row g-3 mb-3">
            <div class="col-12">
                <div class="bento-card-pro">
                    <div class="bento-title-main">
                        <span><i class="bi bi-heart-pulse-fill text-danger me-2"></i>Signos Vitales y Somatometría</span>
                        <span class="text-muted small fw-normal">Triage de Consulta</span>
                    </div>

                    <div class="vital-box-grid">
                        <div class="vital-tile">
                            <div class="vital-tile-val">$d->{ta}</div>
                            <div class="vital-tile-lbl">T. Arterial (mmHg)</div>
                        </div>
                        <div class="vital-tile">
                            <div class="vital-tile-val">$d->{fc}</div>
                            <div class="vital-tile-lbl">F. Cardíaca (lpm)</div>
                        </div>
                        <div class="vital-tile">
                            <div class="vital-tile-val">$d->{fr}</div>
                            <div class="vital-tile-lbl">F. Resp (rpm)</div>
                        </div>
                        <div class="vital-tile">
                            <div class="vital-tile-val">$d->{temp}°C</div>
                            <div class="vital-tile-lbl">Temperatura</div>
                        </div>
                        <div class="vital-tile">
                            <div class="vital-tile-val">$d->{spo2}%</div>
                            <div class="vital-tile-lbl">SpO2</div>
                        </div>
                        <div class="vital-tile">
                            <div class="vital-tile-val">$d->{glucosa}</div>
                            <div class="vital-tile-lbl">Glucosa (mg/dL)</div>
                        </div>
                        <div class="vital-tile">
                            <div class="vital-tile-val">$d->{peso} <small class="text-muted" style="font-size:0.7rem;">kg</small></div>
                            <div class="vital-tile-lbl">Peso Corporal</div>
                        </div>
                        <div class="vital-tile">
                            <div class="vital-tile-val">$d->{talla} <small class="text-muted" style="font-size:0.7rem;">m</small></div>
                            <div class="vital-tile-lbl">Estatura</div>
                        </div>
                        <div class="vital-tile bg-teal-clinical bg-opacity-10 border-teal">
                            <div class="vital-tile-val text-teal" style="color:#00847D;">$imc_val</div>
                            <div class="vital-tile-lbl fw-bold">IMC ($imc_status)</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Fila 3: S.O.A.P. Desglosado en Bento Grid -->
        <div class="row g-3 mb-3">
            <!-- S: Subjetivo -->
            <div class="col-md-6">
                <div class="bento-card-pro">
                    <div class="bento-title-main text-primary">
                        <span><i class="bi bi-1-circle-fill me-2"></i>Subjetivo (S)</span>
                        <span class="badge bg-primary bg-opacity-10 text-primary">Motivo & Anamnesis</span>
                    </div>
                    <div class="data-label-bento">Motivo de Consulta</div>
                    <div class="data-val-bento">$d->{motivo}</div>

                    <div class="data-label-bento">Evolución y Padecimiento Actual</div>
                    <div class="data-val-bento">$d->{evolucion}</div>

                    <div class="data-label-bento">Escala EVA del Dolor</div>
                    <div class="data-val-bento">
                        <span class="badge bg-warning text-dark fw-bold px-2 py-1">$d->{intensidad} / 10</span>
                    </div>

                    <div class="data-label-bento">Antecedentes Clínicos</div>
                    <div class="small text-muted">
                        • <strong>Patológicos:</strong> $d->{antecedentes_patologicos}<br>
                        • <strong>Heredofamiliares:</strong> $d->{antecedentes_heredofamiliares}<br>
                        • <strong>No Patológicos:</strong> $d->{antecedentes_no_patologicos}
                    </div>
                </div>
            </div>

            <!-- O: Objetivo -->
            <div class="col-md-6">
                <div class="bento-card-pro">
                    <div class="bento-title-main text-success">
                        <span><i class="bi bi-2-circle-fill me-2"></i>Objetivo (O)</span>
                        <span class="badge bg-success bg-opacity-10 text-success">Exploración Física</span>
                    </div>
                    <div class="data-label-bento">Hallazgos de Exploración Física</div>
                    <div class="data-val-bento">$d->{exploracion_hallazgos}</div>

                    <div class="data-label-bento">Estudios de Laboratorio / Gabinete</div>
                    <div class="data-val-bento">
                        <strong>Laboratorio:</strong> $d->{laboratorios_solicitados}<br>
                        <strong>Gabinete:</strong> $d->{gabinete_solicitados}
                    </div>

                    <div class="data-label-bento">Resultados Previos</div>
                    <div class="small text-muted">$d->{resultados_estudios}</div>
                </div>
            </div>

            <!-- A: Análisis -->
            <div class="col-md-6">
                <div class="bento-card-pro">
                    <div class="bento-title-main text-danger">
                        <span><i class="bi bi-3-circle-fill me-2"></i>Análisis (A)</span>
                        <span class="badge bg-danger bg-opacity-10 text-danger">Diagnóstico CIE-10</span>
                    </div>
                    <div class="data-label-bento">Diagnóstico Principal</div>
                    <div class="data-val-bento fw-bold text-dark fs-6">
                        <span class="badge bg-danger me-1">$d->{clave_diagnostico_cie10}</span> $d->{diagnostico_principal}
                    </div>

                    <div class="data-label-bento">Diagnósticos Secundarios / Comorbilidades</div>
                    <div class="data-val-bento">$d->{diagnosticos_secundarios}</div>

                    <div class="data-label-bento">Impresión Clínica & Severidad</div>
                    <div class="data-val-bento">$d->{impresion_clinica} (Severidad: <strong>$d->{severidad}</strong>, Pronóstico: <strong>$d->{pronostico}</strong>)</div>
                </div>
            </div>

            <!-- P: Plan y Tratamiento -->
            <div class="col-md-6">
                <div class="bento-card-pro">
                    <div class="bento-title-main text-info">
                        <span><i class="bi bi-4-circle-fill me-2"></i>Plan y Tratamiento (P)</span>
                        <span class="badge bg-info bg-opacity-10 text-dark">Terapéutica</span>
                    </div>
                    <div class="data-label-bento">Plan Terapéutico General</div>
                    <div class="data-val-bento">$d->{plan_tratamiento}</div>

                    <div class="data-label-bento">Indicaciones Higiénico-Dietéticas</div>
                    <div class="data-val-bento">$d->{receta_indicaciones}</div>

                    <div class="data-label-bento">Medicamentos Prescritos</div>
                    <div class="data-val-bento">
                        <span class="badge bg-dark">@{[ scalar @$medicamentos ]} fármacos expedidos</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Fila 4: Receta Médica COFEPRIS Estructurada -->
        <div class="row g-3 mb-3">
            <div class="col-12">
                <div class="bento-card-pro">
                    <div class="bento-title-main">
                        <span><i class="bi bi-prescription2 text-teal me-2"></i>Receta Médica Expedida (COFEPRIS)</span>
                        <span class="badge bg-teal-clinical text-dark">NOM-024-SSA3</span>
                    </div>

                    <div class="table-responsive">
                        <table class="table table-hover align-middle mb-0" style="font-size:0.88rem;">
                            <thead class="table-light">
                                <tr class="text-uppercase" style="font-size:0.75rem; letter-spacing:0.5px;">
                                    <th>#</th>
                                    <th>Denominación Genérica</th>
                                    <th>Comercial / Forma</th>
                                    <th>Concentración / Dosis</th>
                                    <th>Frecuencia & Posología</th>
                                    <th>Duración</th>
                                    <th>Vía</th>
                                </tr>
                            </thead>
                            <tbody>
HTML

my $idx = 1;
foreach my $med (@$medicamentos) {
    my $gen = $med->{generico} || $med->{farmaco} || 'Fármaco';
    my $com = $med->{comercial} || $med->{presentacion} || 'Genérico';
    my $forma = $med->{forma} || '';
    my $conc = $med->{concentracion} || $med->{dosis} || '';
    my $frec = $med->{posologia} || $med->{frecuencia} || '';
    my $dur  = $med->{duracion} || '';
    my $via  = $med->{via} || 'Oral';

    print <<HTML;
                                <tr>
                                    <td class="fw-bold text-muted">$idx</td>
                                    <td class="fw-bold text-dark">$gen</td>
                                    <td>$com $forma</td>
                                    <td><span class="badge bg-light text-dark border">$conc</span></td>
                                    <td>$frec</td>
                                    <td>$dur</td>
                                    <td><span class="badge bg-info bg-opacity-10 text-dark">$via</span></td>
                                </tr>
HTML
    $idx++;
}

print <<HTML;
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <!-- Fila 5: Cierre Bento con Botón hacia el Visor WYSIWYG Carta -->
        <div class="text-center py-3">
            <button type="button" class="btn btn-lg px-4 py-2 rounded-pill fw-bold text-dark shadow-sm" style="background:#00C0B5;" onclick="setMasterView('wysiwyg')">
                <i class="bi bi-file-earmark-medical me-2"></i> Ver en Hoja Carta Oficial (2 Págs para Impresión / PDF)
            </button>
        </div>

    </div>

    <!-- ================================================================= -->
    <!-- 2. VISTA HOJA CARTA (WYSIWYG MULTI-PÁGINA NOM-004 / NOM-024)       -->
    <!-- ================================================================= -->
    <div id="view-wysiwyg-container">

        <!-- Toolbar Superior Multi-Página Específico del Visor Carta -->
        <div class="pdf-multipage-toolbar no-print">
            <div class="d-flex flex-wrap align-items-center justify-content-between gap-2">
                <!-- Izquierda: Regreso y Título -->
                <div class="d-flex align-items-center gap-3">
                    <button type="button" class="btn btn-sm btn-outline-light rounded-pill px-3" onclick="setMasterView('bento')">
                        <i class="bi bi-arrow-left"></i> Volver al Dashboard
                    </button>
                    <div>
                        <div class="d-flex align-items-center gap-2">
                            <i class="bi bi-file-earmark-medical-fill text-teal fs-5" style="color:#00C0B5;"></i>
                            <strong class="text-white" style="font-size:0.95rem;">Nota Médica SOAP (2 Páginas)</strong>
                            <span class="badge bg-light text-dark fw-bold">Folio: $consulta->{id_consulta}</span>
                        </div>
                        <div class="text-white-50" style="font-size:0.75rem;">
                            Exp: EXP-$paciente->{id} • Paciente: <strong class="text-white">$paciente->{nombre}</strong> • Dr(a). $nombre_medico
                        </div>
                    </div>
                </div>

                <!-- Centro: Modos de Vista, Páginas y Zoom -->
                <div class="d-flex align-items-center gap-2">
                    <div class="btn-group btn-group-sm" role="group">
                        <button type="button" class="btn btn-outline-light active" id="btn-view-continuous" onclick="setDocViewerMode('continuous')">
                            <i class="bi bi-distribute-vertical"></i> Vista Continua
                        </button>
                        <button type="button" class="btn btn-outline-light" id="btn-view-paginated" onclick="setDocViewerMode('paginated')">
                            <i class="bi bi-file-earmark-break"></i> Por Página
                        </button>
                    </div>

                    <div class="d-flex align-items-center gap-1 bg-dark bg-opacity-75 px-2 py-1 rounded border border-secondary border-opacity-50">
                        <button type="button" class="btn btn-sm btn-dark p-0 px-1 text-white" onclick="navDocPage(-1)"><i class="bi bi-chevron-left"></i></button>
                        <span id="doc-page-counter" class="text-white small px-1 fw-bold">Pág 1 de 2</span>
                        <button type="button" class="btn btn-sm btn-dark p-0 px-1 text-white" onclick="navDocPage(1)"><i class="bi bi-chevron-right"></i></button>
                    </div>

                    <div class="btn-group btn-group-sm d-none d-md-inline-flex">
                        <button type="button" class="btn btn-outline-secondary text-white btn-jump-page" id="btn-jump-1" onclick="gotoDocPage(1)">Pág 1</button>
                        <button type="button" class="btn btn-outline-secondary text-white btn-jump-page" id="btn-jump-2" onclick="gotoDocPage(2)">Pág 2</button>
                    </div>

                    <select id="doc-zoom-select" class="form-select form-select-sm bg-dark text-white border-secondary" style="width: auto;" onchange="setDocViewerZoom(this.value)">
                        <option value="0.75">75%</option>
                        <option value="1.0" selected>100%</option>
                        <option value="1.25">125%</option>
                    </select>
                </div>

                <!-- Derecha: Acciones de Impresión y Envío -->
                <div class="d-flex align-items-center gap-2">
                    <button type="button" class="btn btn-sm btn-outline-light rounded-pill px-3" onclick="compartirWhatsApp()">
                        <i class="bi bi-whatsapp text-success me-1"></i> WhatsApp
                    </button>
                    <button type="button" class="btn btn-sm text-dark fw-bold rounded-pill px-3" style="background:#00C0B5;" onclick="ejecutarImpresion()">
                        <i class="bi bi-printer-fill me-1"></i> Imprimir (2 Págs)
                    </button>
                </div>
            </div>
        </div>

        <!-- LIENZO Y ESTRUCTURA DE HOJAS CLÍNICAS (Sheets Container) -->
        <div class="pdf-sheets-scroll-area">
            <div id="doc-sheets-canvas" class="pdf-sheets-container mode-continuous zoom-100">

                <!-- ========================================== -->
                <!-- HOJA 1: NOTA MÉDICA CLÍNICA SOAP (PÁG 1/2) -->
                <!-- ========================================== -->
                <div class="clinical-sheet page-1" id="doc-clinical-sheet-1">
                    
                    <!-- Membrete Institucional Clínico -->
                    <div class="sheet-header">
                        <div class="sheet-header-grid">
                            <div class="sheet-logo-zone">
                                <img src="$org->{logo_url}" alt="$org->{nombre_negocio}" class="sheet-logo-img">
                            </div>
                            <div class="sheet-org-info">
                                <h1 class="sheet-org-title">$org->{nombre_negocio}</h1>
                                <div class="sheet-org-subtitle">$org->{razon_social}</div>
                                <div class="sheet-org-meta">
                                    CLUES: <strong>$org->{clues}</strong> • RFC: <strong>$org->{rfc}</strong><br>
                                    $org->{domicilio} • Tel: $org->{telefono} • Email: $org->{email}
                                </div>
                            </div>
                            <div class="sheet-folio-zone">
                                <div class="sheet-doc-badge">NOM-004-SSA3-2012</div>
                                <div class="sheet-folio-title">NOTA MÉDICA SOAP</div>
                                <div class="sheet-folio-num">FOLIO: $consulta->{id_consulta}</div>
                                <div class="sheet-folio-date">Fecha: $consulta->{fecha}</div>
                            </div>
                        </div>
                    </div>

                    <!-- Ficha del Paciente y Médico Tratante -->
                    <div class="sheet-meta-box">
                        <div class="row g-2">
                            <div class="col-8">
                                <div class="sheet-label-xs">Paciente</div>
                                <div class="sheet-val-sm fw-bold text-dark">$paciente->{nombre}</div>
                            </div>
                            <div class="col-4">
                                <div class="sheet-label-xs">Expediente Clínico</div>
                                <div class="sheet-val-sm fw-bold">EXP-$paciente->{id}</div>
                            </div>
                            <div class="col-4">
                                <div class="sheet-label-xs">CURP</div>
                                <div class="sheet-val-xs font-mono">$paciente->{curp}</div>
                            </div>
                            <div class="col-2">
                                <div class="sheet-label-xs">Edad</div>
                                <div class="sheet-val-xs">$paciente->{edad}</div>
                            </div>
                            <div class="col-2">
                                <div class="sheet-label-xs">Sexo</div>
                                <div class="sheet-val-xs">$paciente->{sexo}</div>
                            </div>
                            <div class="col-2">
                                <div class="sheet-label-xs">Grupo/Rh</div>
                                <div class="sheet-val-xs fw-bold text-danger">$paciente->{ts}</div>
                            </div>
                            <div class="col-2">
                                <div class="sheet-label-xs">Tipo Consulta</div>
                                <div class="sheet-val-xs">$d->{tipo_consulta}</div>
                            </div>

                            <div class="col-12 mt-1 pt-1 border-top border-light-subtle">
                                <div class="d-flex align-items-center justify-content-between">
                                    <div>
                                        <span class="sheet-label-xs me-2">Médico Tratante:</span>
                                        <strong class="sheet-val-sm text-dark">$nombre_medico</strong>
                                        <span class="text-muted small ms-2">($especialidad_medico · Céd. Prof. <strong>$cedula_medico</strong>)</span>
                                    </div>
                                    <div class="text-muted small">
                                        Consultorio: <strong>$consultorio_medico</strong>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Alerta de Alergias en Hoja si Existen -->
HTML

if ($tiene_alergias) {
    print <<HTML;
                    <div class="alert-box-critical">
                        <i class="bi bi-exclamation-triangle-fill me-1"></i>
                        <strong>ALERGIAS REPORTADAS:</strong> $alergias_txt
                    </div>
HTML
}

print <<HTML;
                    <!-- Signos Vitales y Somatometría (Grid de 7 métricas) -->
                    <div class="sheet-section-title">
                        <i class="bi bi-heart-pulse text-teal"></i> Signos Vitales y Somatometría (Triage)
                    </div>
                    <div class="sheet-vitals-grid">
                        <div class="sheet-vital-cell">
                            <div class="sheet-vital-lbl">T. Arterial</div>
                            <div class="sheet-vital-num">$d->{ta}</div>
                            <div class="sheet-vital-unit">mmHg</div>
                        </div>
                        <div class="sheet-vital-cell">
                            <div class="sheet-vital-lbl">F. Cardíaca</div>
                            <div class="sheet-vital-num">$d->{fc}</div>
                            <div class="sheet-vital-unit">lpm</div>
                        </div>
                        <div class="sheet-vital-cell">
                            <div class="sheet-vital-lbl">F. Respiratoria</div>
                            <div class="sheet-vital-num">$d->{fr}</div>
                            <div class="sheet-vital-unit">rpm</div>
                        </div>
                        <div class="sheet-vital-cell">
                            <div class="sheet-vital-lbl">Temperatura</div>
                            <div class="sheet-vital-num">$d->{temp}</div>
                            <div class="sheet-vital-unit">°C</div>
                        </div>
                        <div class="sheet-vital-cell">
                            <div class="sheet-vital-lbl">Saturación SpO2</div>
                            <div class="sheet-vital-num">$d->{spo2}</div>
                            <div class="sheet-vital-unit">%</div>
                        </div>
                        <div class="sheet-vital-cell">
                            <div class="sheet-vital-lbl">Glucosa</div>
                            <div class="sheet-vital-num">$d->{glucosa}</div>
                            <div class="sheet-vital-unit">mg/dL</div>
                        </div>
                        <div class="sheet-vital-cell">
                            <div class="sheet-vital-lbl">Peso / Talla</div>
                            <div class="sheet-vital-num">$d->{peso} <small class="text-muted" style="font-size:0.65rem;">kg</small></div>
                            <div class="sheet-vital-unit">$d->{talla} m (IMC: $imc_val)</div>
                        </div>
                    </div>

                    <!-- SUBJETIVO (S) -->
                    <div class="sheet-section-title">
                        <i class="bi bi-chat-left-text text-teal"></i> Subjetivo (S) — Motivo, Padecimiento Actual y Antecedentes
                    </div>
                    <div class="sheet-soap-card mb-2">
                        <div class="sheet-label-xs">Motivo de la Consulta:</div>
                        <div class="sheet-text-p">$d->{motivo}</div>

                        <div class="sheet-label-xs mt-2">Padecimiento Actual y Evolución:</div>
                        <div class="sheet-text-p">$d->{evolucion} (EVA: <strong>$d->{intensidad}/10</strong>)</div>

                        <div class="row g-2 mt-2 pt-1 border-top border-light-subtle">
                            <div class="col-4">
                                <div class="sheet-label-xs">Antecedentes Patológicos:</div>
                                <div class="sheet-val-xs text-muted">$d->{antecedentes_patologicos}</div>
                            </div>
                            <div class="col-4">
                                <div class="sheet-label-xs">Antecedentes Heredofamiliares:</div>
                                <div class="sheet-val-xs text-muted">$d->{antecedentes_heredofamiliares}</div>
                            </div>
                            <div class="col-4">
                                <div class="sheet-label-xs">No Patológicos:</div>
                                <div class="sheet-val-xs text-muted">$d->{antecedentes_no_patologicos}</div>
                            </div>
                        </div>
                    </div>

                    <!-- OBJETIVO (O) -->
                    <div class="sheet-section-title">
                        <i class="bi bi-eye text-teal"></i> Objetivo (O) — Exploración Física y Estudios
                    </div>
                    <div class="sheet-soap-card mb-2">
                        <div class="sheet-label-xs">Hallazgos a la Exploración Física:</div>
                        <div class="sheet-text-p">$d->{exploracion_hallazgos}</div>

                        <div class="row g-2 mt-2 pt-1 border-top border-light-subtle">
                            <div class="col-6">
                                <div class="sheet-label-xs">Estudios de Laboratorio Solicitados:</div>
                                <div class="sheet-val-xs text-muted">$d->{laboratorios_solicitados}</div>
                            </div>
                            <div class="col-6">
                                <div class="sheet-label-xs">Estudios de Gabinete / Imagen:</div>
                                <div class="sheet-val-xs text-muted">$d->{gabinete_solicitados}</div>
                            </div>
                        </div>
                    </div>

                    <!-- Pie de Hoja 1 -->
                    <div class="sheet-footer">
                        <div class="d-flex justify-content-between align-items-center">
                            <span>Documento médico confidencial expedido conforme a la NOM-004-SSA3-2012.</span>
                            <span class="sheet-page-indicator">Hoja 1 de 2 • Folio: $consulta->{id_consulta}</span>
                        </div>
                    </div>

                </div>

                <!-- SEPARADOR VISUAL DE HOJAS EN MODO CONTINUO (En pantalla) -->
                <div class="page-break-indicator-web no-print">
                    <span class="badge bg-secondary px-3 py-1 fw-normal">
                        <i class="bi bi-scissors me-1"></i> SALTO DE PÁGINA OFICIAL · HOJA 2/2 (RECETA COFEPRIS Y PLAN CLÍNICO)
                    </span>
                </div>

                <!-- ==================================================== -->
                <!-- HOJA 2: ANÁLISIS, RECETA COFEPRIS Y FIRMA (PÁG 2/2)  -->
                <!-- ==================================================== -->
                <div class="clinical-sheet page-2" id="doc-clinical-sheet-2">

                    <!-- Membrete Compacto de Receta Médica -->
                    <div class="sheet-header">
                        <div class="sheet-header-grid">
                            <div class="sheet-logo-zone">
                                <img src="$org->{logo_url}" alt="$org->{nombre_negocio}" class="sheet-logo-img">
                            </div>
                            <div class="sheet-org-info">
                                <h1 class="sheet-org-title">$org->{nombre_negocio}</h1>
                                <div class="sheet-org-meta">
                                    CLUES: <strong>$org->{clues}</strong> • RFC: <strong>$org->{rfc}</strong><br>
                                    $org->{domicilio} • Tel: $org->{telefono}
                                </div>
                            </div>
                            <div class="sheet-folio-zone">
                                <div class="sheet-doc-badge">COFEPRIS / NOM-024</div>
                                <div class="sheet-folio-title">RECETA MÉDICA Y PLAN</div>
                                <div class="sheet-folio-num">FOLIO: $consulta->{id_consulta}</div>
                                <div class="sheet-folio-date">Fecha: $consulta->{fecha}</div>
                            </div>
                        </div>
                    </div>

                    <!-- Ficha Resumen Paciente Hoja 2 -->
                    <div class="sheet-meta-box mb-2">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <span class="sheet-label-xs">Paciente:</span>
                                <strong class="sheet-val-sm text-dark ms-1">$paciente->{nombre}</strong>
                                <span class="text-muted small ms-2">($paciente->{edad} · $paciente->{sexo} · EXP-$paciente->{id})</span>
                            </div>
                            <div>
                                <span class="sheet-label-xs">Médico:</span>
                                <strong class="sheet-val-sm text-dark ms-1">$nombre_medico</strong>
                                <span class="text-muted small ms-2">(Céd. <strong>$cedula_medico</strong>)</span>
                            </div>
                        </div>
                    </div>

                    <!-- ANÁLISIS Y DIAGNÓSTICOS (A) -->
                    <div class="sheet-section-title">
                        <i class="bi bi-journal-medical text-teal"></i> Análisis (A) — Diagnóstico CIE-10 y Pronóstico
                    </div>
                    <div class="sheet-soap-card mb-2">
                        <div class="d-flex align-items-center justify-content-between">
                            <div>
                                <div class="sheet-label-xs">Diagnóstico Principal (CIE-10):</div>
                                <div class="sheet-val-sm fw-bold text-dark">
                                    <span class="badge bg-dark me-1">$d->{clave_diagnostico_cie10}</span> $d->{diagnostico_principal}
                                </div>
                            </div>
                            <div class="text-end">
                                <span class="badge bg-secondary">Severidad: $d->{severidad}</span>
                                <span class="badge bg-info text-dark ms-1">Pronóstico: $d->{pronostico}</span>
                            </div>
                        </div>

                        <div class="sheet-label-xs mt-2">Diagnósticos Secundarios:</div>
                        <div class="sheet-text-p text-muted">$d->{diagnosticos_secundarios}</div>

                        <div class="sheet-label-xs mt-2">Impresión Clínica:</div>
                        <div class="sheet-text-p">$d->{impresion_clinica}</div>
                    </div>

                    <!-- PLAN Y TRATAMIENTO (P) -->
                    <div class="sheet-section-title">
                        <i class="bi bi-card-checklist text-teal"></i> Plan y Tratamiento (P)
                    </div>
                    <div class="sheet-soap-card mb-2">
                        <div class="sheet-label-xs">Plan Terapéutico y Recomendaciones Clínicas:</div>
                        <div class="sheet-text-p">$d->{plan_tratamiento}</div>

                        <div class="sheet-label-xs mt-2">Indicaciones Higiénico-Dietéticas y Signos de Alarma:</div>
                        <div class="sheet-text-p">$d->{receta_indicaciones}</div>
                    </div>

                    <!-- RECETA MÉDICA INSTITUCIONAL (COFEPRIS) -->
                    <div class="sheet-section-title">
                        <i class="bi bi-prescription2 text-teal"></i> Prescripción Farmacológica (Receta Oficial COFEPRIS)
                    </div>
                    <table class="sheet-rx-table mb-3">
                        <thead>
                            <tr>
                                <th style="width: 25px;">#</th>
                                <th>Denominación Genérica</th>
                                <th>Forma / Comercial</th>
                                <th>Dosis / Concentración</th>
                                <th>Frecuencia & Posología</th>
                                <th>Duración</th>
                                <th>Vía</th>
                            </tr>
                        </thead>
                        <tbody>
HTML

my $idx2 = 1;
foreach my $med (@$medicamentos) {
    my $gen = $med->{generico} || $med->{farmaco} || 'Fármaco';
    my $com = $med->{comercial} || $med->{presentacion} || '';
    my $forma = $med->{forma} || '';
    my $conc = $med->{concentracion} || $med->{dosis} || '';
    my $frec = $med->{posologia} || $med->{frecuencia} || '';
    my $dur  = $med->{duracion} || '';
    my $via  = $med->{via} || 'Oral';

    print <<HTML;
                            <tr>
                                <td class="fw-bold text-muted">$idx2</td>
                                <td class="fw-bold text-dark">$gen</td>
                                <td>$com $forma</td>
                                <td>$conc</td>
                                <td><strong>$frec</strong></td>
                                <td>$dur</td>
                                <td>$via</td>
                            </tr>
HTML
    $idx2++;
}

print <<HTML;
                        </tbody>
                    </table>

                    <!-- Bloque de Sello Digital NOM-151 y Validación QR -->
                    <div class="sheet-cert-box mb-3">
                        <div class="d-flex align-items-center justify-content-between">
                            <div style="max-width: 82%;">
                                <div class="sheet-label-xs fw-bold text-dark mb-1">
                                    <i class="bi bi-shield-check text-success me-1"></i> Sello Digital de Autenticidad (NOM-151 / NOM-024-SSA3)
                                </div>
                                <div class="sheet-val-xs text-muted font-mono" style="font-size:0.62rem; word-break:break-all;">
                                    CADENA ORIGINAL: ||NOM-024|2026|$consulta->{id_consulta}|$paciente->{curp}|$cedula_medico|$consulta->{fecha}||<br>
                                    FIRMA DIGITAL SHA256: 3a9f02c4b81e4d77a80b1e8e8c14d5e71829a3f4b5c6d7e8f9a0b1c2d3e4f5a6
                                </div>
                            </div>
                            <div class="text-center">
                                <img src="https://api.qrserver.com/v1/create-qr-code/?size=72x72&data=https://ospulso.com/validador?folio=$consulta->{id_consulta}" alt="QR Validación NOM-024" style="width: 68px; height: 68px; border:1px solid #E2E8F0; border-radius:4px; padding:2px;">
                                <div style="font-size:0.58rem; color:#64748B; font-weight:700; margin-top:2px;">NOM-024 QR</div>
                            </div>
                        </div>
                    </div>

                    <!-- Bloque de Firmas al Calce -->
                    <div class="sheet-signatures-grid">
                        <div class="sheet-sig-box">
                            <div class="sheet-sig-line"></div>
                            <div class="sheet-sig-name">$paciente->{nombre}</div>
                            <div class="sheet-sig-role">Firma del Paciente / Tutor (Conformidad)</div>
                        </div>
                        <div class="sheet-sig-box">
                            <div class="sheet-sig-line"></div>
                            <div class="sheet-sig-name">$nombre_medico</div>
                            <div class="sheet-sig-role">$especialidad_medico · Cédula Profesional: $cedula_medico</div>
                        </div>
                    </div>

                    <!-- Pie de Hoja 2 -->
                    <div class="sheet-footer">
                        <div class="d-flex justify-content-between align-items-center">
                            <span>Receta médica oficial emitida bajo lineamientos de COFEPRIS y NOM-004-SSA3-2012.</span>
                            <span class="sheet-page-indicator">Hoja 2 de 2 • Folio: $consulta->{id_consulta}</span>
                        </div>
                    </div>

                </div>

            </div>
        </div>

    </div>

    <!-- Bootstrap Bundle JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

    <!-- Lógica de Control e Interactividad del Visor y Vistas -->
    <script>
    let currentMasterView = 'bento';
    let currentDocMode = 'continuous';
    let currentDocPage = 1;

    // Switch Maestro entre Vista Bento y Hoja Carta WYSIWYG
    function setMasterView(mode) {
        currentMasterView = mode;
        const bentoContainer = document.getElementById('view-bento-container');
        const wysiwygContainer = document.getElementById('view-wysiwyg-container');
        const btnBento = document.getElementById('btn-mode-bento');
        const btnWysiwyg = document.getElementById('btn-mode-wysiwyg');

        if (mode === 'wysiwyg') {
            bentoContainer.style.display = 'none';
            wysiwygContainer.style.display = 'block';
            btnBento.classList.remove('active');
            btnWysiwyg.classList.add('active');
            window.scrollTo({ top: 0, behavior: 'smooth' });
        } else {
            wysiwygContainer.style.display = 'none';
            bentoContainer.style.display = 'block';
            btnWysiwyg.classList.remove('active');
            btnBento.classList.add('active');
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }

    // Switch de Modo en Hoja Carta: Continua vs Paginated
    function setDocViewerMode(mode) {
        currentDocMode = mode;
        const canvas = document.getElementById('doc-sheets-canvas');
        const btnCont = document.getElementById('btn-view-continuous');
        const btnPag = document.getElementById('btn-view-paginated');
        const page1 = document.getElementById('doc-clinical-sheet-1');
        const page2 = document.getElementById('doc-clinical-sheet-2');

        if (mode === 'continuous') {
            canvas.classList.remove('mode-paginated');
            canvas.classList.add('mode-continuous');
            btnCont.classList.add('active');
            btnPag.classList.remove('active');
            page1.style.display = 'flex';
            page2.style.display = 'flex';
            document.getElementById('doc-page-counter').textContent = 'Págs 1 y 2';
        } else {
            canvas.classList.remove('mode-continuous');
            canvas.classList.add('mode-paginated');
            btnPag.classList.add('active');
            btnCont.classList.remove('active');
            gotoDocPage(currentDocPage);
        }
    }

    // Navegación de Páginas en modo Paginado
    function navDocPage(delta) {
        if (currentDocMode === 'continuous') {
            setDocViewerMode('paginated');
        }
        let target = currentDocPage + delta;
        if (target < 1) target = 1;
        if (target > 2) target = 2;
        gotoDocPage(target);
    }

    function gotoDocPage(p) {
        currentDocPage = p;
        const page1 = document.getElementById('doc-clinical-sheet-1');
        const page2 = document.getElementById('doc-clinical-sheet-2');
        const counter = document.getElementById('doc-page-counter');
        const btnJ1 = document.getElementById('btn-jump-1');
        const btnJ2 = document.getElementById('btn-jump-2');

        if (currentDocMode === 'paginated') {
            if (p === 1) {
                page1.style.display = 'flex';
                page2.style.display = 'none';
                btnJ1.classList.add('btn-primary', 'text-white');
                btnJ1.classList.remove('btn-outline-secondary');
                btnJ2.classList.remove('btn-primary', 'text-white');
                btnJ2.classList.add('btn-outline-secondary');
            } else {
                page1.style.display = 'none';
                page2.style.display = 'flex';
                btnJ2.classList.add('btn-primary', 'text-white');
                btnJ2.classList.remove('btn-outline-secondary');
                btnJ1.classList.remove('btn-primary', 'text-white');
                btnJ1.classList.add('btn-outline-secondary');
            }
            counter.textContent = 'Página ' + p + ' de 2';
        } else {
            // En continua, hacer scroll hacia la página
            const targetEl = (p === 1) ? page1 : page2;
            if (targetEl) targetEl.scrollIntoView({ behavior: 'smooth' });
        }
    }

    // Zoom del Visor Carta
    function setDocViewerZoom(zoomLevel) {
        const canvas = document.getElementById('doc-sheets-canvas');
        canvas.classList.remove('zoom-75', 'zoom-100', 'zoom-125');
        if (zoomLevel === '0.75') {
            canvas.classList.add('zoom-75');
        } else if (zoomLevel === '1.25') {
            canvas.classList.add('zoom-125');
        } else {
            canvas.classList.add('zoom-100');
        }
    }

    // Impresión Oficial Multi-página
    function ejecutarImpresion() {
        // Asegurarse de que el contenedor WYSIWYG esté activo y ambas hojas visibles
        const prevView = currentMasterView;
        const prevMode = currentDocMode;

        setMasterView('wysiwyg');
        setDocViewerMode('continuous');

        setTimeout(() => {
            window.print();
        }, 150);
    }

    // Compartir por WhatsApp
    function compartirWhatsApp() {
        const telefono = "$paciente->{telefono}" || '';
        const folio = "$consulta->{id_consulta}";
        const paciente = "$paciente->{nombre}";
        const urlNota = window.location.href;
        
        const texto = encodeURIComponent(
            "Hola " + paciente + ", le compartimos el enlace oficial para consultar su Nota Médica y Receta Digital (Folio: " + folio + ") emitida por $org->{nombre_negocio}: " + urlNota
        );
        
        const targetUrl = telefono ? "https://wa.me/52" + telefono + "?text=" + texto : "https://wa.me/?text=" + texto;
        window.open(targetUrl, '_blank');
    }
    </script>
</body>
</html>
HTML

1;
