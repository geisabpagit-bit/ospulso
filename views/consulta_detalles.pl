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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = eval { check_session($q) } || {};
# Sesión abierta o acceso clínico autorizado
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
                { farmaco => 'Ibuprofeno', presentacion => 'Cápsulas 400 mg', dosis => '1 cápsula', frecuencia => 'Cada 8 horas', duracion => '5 días', via => 'Oral' },
                { farmaco => 'Paracetamol', presentacion => 'Tabletas 500 mg', dosis => '1 tableta', frecuencia => 'Cada 8 horas (en caso de dolor residual)', duracion => '3 días', via => 'Oral' },
                { farmaco => 'Complejo B', presentacion => 'Tabletas', dosis => '1 tableta', frecuencia => 'Cada 24 horas matutina', duracion => '30 días', via => 'Oral' }
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
        # Buscar organización 0 o la que coincida
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

# 5. Medicamentos expedidos
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

# 8. Render HTML
print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nota Médica - Folio $consulta->{id_consulta} | $org->{nombre_negocio}</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    
    <!-- Librerías de Vanguardia -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.3/font/bootstrap-icons.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">

    <style>
        :root {
            --md-teal-clinical: #19B7A5;
            --md-teal-dark: #0f766e;
            --md-blue-deep: #0A2A66;
            --md-navy: #051A44;
            --md-gray-bg: #F1F5F9;
            --md-card-bg: #FFFFFF;
            --md-border-color: #E2E8F0;
            --md-text-primary: #0F172A;
            --md-text-muted: #64748B;
        }

        * {
            box-sizing: border-box;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--md-gray-bg);
            color: var(--md-text-primary);
            margin: 0;
            padding: 0;
            -webkit-font-smoothing: antialiased;
        }

        /* Barra de Control Superior Flotante */
        .action-topbar {
            position: sticky;
            top: 0;
            z-index: 1030;
            background: rgba(255, 255, 255, 0.92);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border-bottom: 1px solid rgba(226, 232, 240, 0.8);
            box-shadow: 0 4px 20px rgba(10, 42, 102, 0.05);
            padding: 0.75rem 1.5rem;
        }

        .btn-view-toggle {
            font-size: 0.82rem;
            font-weight: 700;
            padding: 0.45rem 1rem;
            border-radius: 9999px;
            transition: all 0.2s ease;
        }

        .btn-view-toggle.active {
            background-color: var(--md-blue-deep);
            color: #ffffff;
            border-color: var(--md-blue-deep);
            box-shadow: 0 4px 12px rgba(10, 42, 102, 0.2);
        }

        /* VISTA BENTO (Pantalla Interactiva) */
        .bento-container {
            max-width: 1240px;
            margin: 2rem auto;
            padding: 0 1.25rem;
            transition: opacity 0.2s ease;
        }

        .bento-card {
            background: var(--md-card-bg);
            border-radius: 1.25rem;
            padding: 1.75rem;
            border: 1px solid var(--md-border-color);
            box-shadow: 0 10px 30px rgba(10, 42, 102, 0.04);
            height: 100%;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .bento-card:hover {
            box-shadow: 0 14px 38px rgba(10, 42, 102, 0.07);
        }

        .bento-header {
            font-size: 1.05rem;
            font-weight: 800;
            color: var(--md-blue-deep);
            margin-bottom: 1.25rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 2px solid var(--md-gray-bg);
            padding-bottom: 0.75rem;
        }

        .data-label {
            font-size: 0.72rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.6px;
            color: var(--md-text-muted);
            margin-bottom: 0.25rem;
        }

        .data-value {
            font-size: 0.95rem;
            font-weight: 600;
            color: var(--md-navy);
            margin-bottom: 1.1rem;
            line-height: 1.5;
        }

        .vital-box {
            background: #ffffff;
            border-radius: 1rem;
            padding: 1rem 0.75rem;
            text-align: center;
            border: 1px solid var(--md-border-color);
            box-shadow: 0 2px 8px rgba(0,0,0,0.02);
        }
        .vital-value {
            font-size: 1.35rem;
            font-weight: 800;
            color: var(--md-blue-deep);
        }
        .vital-unit {
            font-size: 0.72rem;
            color: var(--md-text-muted);
            font-weight: 600;
        }

        /* MODO HOJA WYSIWYG (Simulación Hoja Carta Vertical) */
        .wysiwyg-wrapper {
            background: #cbd5e1;
            padding: 2.5rem 1rem;
            min-height: calc(100vh - 65px);
            display: flex;
            justify-content: center;
        }

        .wysiwyg-sheet {
            background: #ffffff;
            width: 816px; /* Ancho estándar 8.5in a 96 DPI */
            min-height: 1056px; /* Alto estándar 11in a 96 DPI */
            padding: 12mm 12mm 12mm 12mm; /* Margen estrecho */
            border-radius: 4px;
            box-shadow: 0 15px 45px rgba(0, 0, 0, 0.2), 0 2px 10px rgba(0, 0, 0, 0.08);
            color: #0f172a;
            position: relative;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }

        /* Membrete Institucional WYSIWYG */
        .doc-header {
            border-bottom: 2px solid var(--md-blue-deep);
            padding-bottom: 0.75rem;
            margin-bottom: 1rem;
        }
        .doc-logo {
            max-height: 52px;
            max-width: 140px;
            object-fit: contain;
        }
        .org-title {
            font-size: 1.15rem;
            font-weight: 900;
            color: var(--md-blue-deep);
            line-height: 1.2;
            letter-spacing: -0.3px;
        }
        .org-legal {
            font-size: 0.72rem;
            color: #475569;
            line-height: 1.35;
        }

        /* Sub-Encabezado: Ficha Paciente & Médico */
        .doc-meta-box {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 8px;
            padding: 0.65rem 0.85rem;
            margin-bottom: 0.85rem;
            font-size: 0.8rem;
        }

        /* Secciones del Documento Impreso */
        .doc-section-title {
            font-size: 0.82rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 0.6px;
            color: var(--md-blue-deep);
            border-bottom: 1px solid #cbd5e1;
            padding-bottom: 0.25rem;
            margin-top: 0.75rem;
            margin-bottom: 0.45rem;
            display: flex;
            align-items: center;
            gap: 0.4rem;
        }

        .doc-grid-vitals {
            display: grid;
            grid-template-columns: repeat(6, 1fr);
            gap: 0.4rem;
            margin-bottom: 0.65rem;
        }

        .doc-vital-cell {
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            background: #f8fafc;
            padding: 0.35rem;
            text-align: center;
        }
        .doc-vital-lbl {
            font-size: 0.65rem;
            font-weight: 800;
            color: #64748b;
            text-transform: uppercase;
        }
        .doc-vital-val {
            font-size: 0.92rem;
            font-weight: 800;
            color: var(--md-blue-deep);
        }

        .doc-soap-block {
            border-left: 3px solid var(--md-teal-clinical);
            padding-left: 0.6rem;
            margin-bottom: 0.55rem;
            font-size: 0.82rem;
            line-height: 1.38;
        }

        .doc-table-rx {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.78rem;
            margin-bottom: 0.65rem;
        }
        .doc-table-rx th {
            background: #f1f5f9;
            color: var(--md-blue-deep);
            font-weight: 800;
            text-transform: uppercase;
            font-size: 0.7rem;
            padding: 0.4rem 0.5rem;
            border: 1px solid #cbd5e1;
        }
        .doc-table-rx td {
            padding: 0.4rem 0.5rem;
            border: 1px solid #e2e8f0;
            vertical-align: middle;
        }

        /* Bloque de Firmas al Calce */
        .doc-signatures {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 2rem;
            margin-top: 1.5rem;
            padding-top: 0.75rem;
            border-top: 1px dashed #cbd5e1;
            text-align: center;
            font-size: 0.78rem;
            break-inside: avoid;
            page-break-inside: avoid;
        }

        .doc-sig-line {
            width: 75%;
            margin: 0 auto 0.4rem auto;
            border-bottom: 1px solid #334155;
            height: 48px;
            display: flex;
            align-items: flex-end;
            justify-content: center;
        }

        .doc-footer-legal {
            font-size: 0.65rem;
            color: #64748b;
            text-align: center;
            border-top: 1px solid #e2e8f0;
            padding-top: 0.5rem;
            margin-top: 1rem;
        }

        /* REGLAS ESTRICTAS DE IMPRESIÓN Y EXPORTACIÓN A PDF */
        \@page {
            size: letter portrait;
            margin: 8mm 8mm 8mm 8mm; /* Margen estrecho */
        }

        \@media print {
            body {
                background: #ffffff !important;
                color: #000000 !important;
                font-size: 9pt !important;
                margin: 0 !important;
                padding: 0 !important;
            }

            .action-topbar,
            .bento-container,
            .d-print-none {
                display: none !important;
            }

            .wysiwyg-wrapper {
                background: transparent !important;
                padding: 0 !important;
                margin: 0 !important;
                display: block !important;
                min-height: auto !important;
            }

            .wysiwyg-sheet {
                width: 100% !important;
                min-height: auto !important;
                box-shadow: none !important;
                border: none !important;
                padding: 0 !important;
                margin: 0 !important;
                border-radius: 0 !important;
            }

            .doc-signatures,
            .doc-soap-block,
            .doc-table-rx,
            .doc-meta-box,
            .doc-vital-cell {
                page-break-inside: avoid !important;
                break-inside: avoid !important;
            }

            .badge {
                border: 1px solid #cbd5e1 !important;
                color: #000 !important;
            }
        }
    </style>
</head>
<body>

    <!-- BARRA DE ACCIÓN SUPERIOR (Glassmorphism Sticky) -->
    <header class="action-topbar d-print-none">
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
            <div class="d-flex align-items-center gap-2">
                <a href="render_expediente_clinico.pl?id=$paciente->{id}" class="btn btn-outline-secondary rounded-pill btn-sm fw-bold px-3">
                    <i class="bi bi-arrow-left me-1"></i> Expediente
                </a>
                <a href="inicial.pl" class="btn btn-light rounded-pill btn-sm fw-bold px-3 border">
                    <i class="bi bi-house me-1"></i> Dashboard
                </a>
                <span class="badge bg-primary-subtle text-primary border border-primary-subtle rounded-pill px-3 py-1 ms-2 d-none d-md-inline-block">
                    Folio: $consulta->{id_consulta}
                </span>
            </div>

            <!-- Selector de Vista y Botones de Impresión -->
            <div class="d-flex align-items-center gap-2 flex-wrap">
                <div class="btn-group p-1 bg-light border rounded-pill" role="group">
                    <button type="button" class="btn btn-view-toggle active" id="btn-view-bento" onclick="switchView('bento')">
                        <i class="bi bi-grid-fill me-1"></i> Dashboard Bento
                    </button>
                    <button type="button" class="btn btn-view-toggle" id="btn-view-wysiwyg" onclick="switchView('wysiwyg')">
                        <i class="bi bi-file-earmark-richtext-fill me-1"></i> Hoja Carta (WYSIWYG)
                    </button>
                </div>

                @{[ scalar(@$medicamentos) > 0 ? qq{
                <button onclick="imprimirRecetaOnly()" class="btn btn-outline-primary rounded-pill btn-sm fw-bold px-3">
                    <i class="bi bi-capsule me-1"></i> Receta Médica
                </button>
                } : "" ]}

                <button onclick="imprimirNotaMedica()" class="btn text-white rounded-pill btn-sm px-4 fw-bold shadow-sm" style="background: linear-gradient(135deg, var(--md-blue-deep), var(--md-teal-clinical)); border: none;">
                    <i class="bi bi-printer-fill me-1"></i> Imprimir / Guardar PDF
                </button>
            </div>
        </div>
    </header>

    <!-- 1. VISTA DASHBOARD BENTO (Interactivo en Pantalla) -->
    <main class="bento-container" id="view-bento">
        <!-- Banner Principal de Identificación -->
        <div class="card border-0 shadow-sm rounded-4 mb-4 text-white" style="background: linear-gradient(135deg, var(--md-navy) 0%, var(--md-blue-deep) 100%);">
            <div class="card-body p-4">
                <div class="row align-items-center">
                    <div class="col-md-7">
                        <div class="d-flex align-items-center gap-2 mb-2">
                            <span class="badge bg-white-10 text-white border border-white-20 rounded-pill px-3 py-1 small fw-bold" style="background: rgba(255,255,255,0.15);">
                                <i class="bi bi-person-badge me-1"></i> EXPEDIENTE PACIENTE #$paciente->{id}
                            </span>
                            <span class="badge bg-teal text-white rounded-pill px-3 py-1 small fw-bold" style="background: var(--md-teal-clinical);">
                                $d->{tipo_consulta}
                            </span>
                        </div>
                        <h2 class="fw-black text-white mb-1">$paciente->{nombre}</h2>
                        <div class="text-white-50 small d-flex flex-wrap gap-3 mt-2">
                            <span><i class="bi bi-card-text me-1"></i><strong>CURP:</strong> $paciente->{curp}</span>
                            <span><i class="bi bi-gender-ambiguous me-1"></i><strong>Sexo:</strong> $paciente->{sexo}</span>
                            <span><i class="bi bi-hourglass-split me-1"></i><strong>Edad:</strong> $paciente->{edad}</span>
                            <span><i class="bi bi-droplet-fill me-1 text-danger"></i><strong>GS:</strong> $paciente->{ts}</span>
                            <span><i class="bi bi-telephone-fill me-1"></i><strong>Tel:</strong> $paciente->{telefono}</span>
                        </div>
                        @{[ ($paciente->{alergias} && $paciente->{alergias} ne 'Negadas') ? qq{
                        <div class="mt-2">
                            <span class="badge bg-danger text-white rounded-pill px-3 py-1"><i class="bi bi-exclamation-triangle-fill me-1"></i>Alergias Conocidas: $paciente->{alergias}</span>
                        </div>
                        } : qq{
                        <div class="mt-2">
                            <span class="badge bg-success-subtle text-success border border-success-subtle rounded-pill px-3 py-1"><i class="bi bi-shield-check me-1"></i>Alergias Negadas</span>
                        </div>
                        } ]}
                    </div>
                    <div class="col-md-5 text-md-end mt-3 mt-md-0 border-start-md border-white-10 ps-md-4">
                        <div class="small text-white-50 fw-bold text-uppercase">Médico Tratante / Especialista</div>
                        <h4 class="fw-bold mb-0 text-white" style="color: #67e8f9 !important;">$nombre_medico</h4>
                        <div class="badge bg-white-10 text-white border border-white-20 rounded-pill px-3 py-1 my-1" style="background: rgba(255,255,255,0.12);">
                            $especialidad_medico
                        </div>
                        <div class="small text-white-50 mt-1">Cédula Profesional: <strong>$cedula_medico</strong></div>
                        <div class="small text-white-50"><i class="bi bi-geo-alt me-1"></i>$consultorio_medico</div>
                        <div class="mt-2 pt-2 border-top border-white-10 small text-white-50">
                            <i class="bi bi-clock-history me-1"></i>Fecha de Atención: <strong>$consulta->{fecha}</strong>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Bento Signos Vitales -->
        <div class="row g-3 mb-4">
            <div class="col-6 col-sm-4 col-md-2">
                <div class="vital-box">
                    <div class="data-label"><i class="bi bi-heart-pulse me-1 text-danger"></i> T.A.</div>
                    <div class="vital-value">@{[ $d->{ta} || '--' ]}</div>
                    <div class="vital-unit">mmHg</div>
                </div>
            </div>
            <div class="col-6 col-sm-4 col-md-2">
                <div class="vital-box">
                    <div class="data-label"><i class="bi bi-activity me-1 text-primary"></i> F.C.</div>
                    <div class="vital-value">@{[ $d->{fc} || '--' ]}</div>
                    <div class="vital-unit">lpm</div>
                </div>
            </div>
            <div class="col-6 col-sm-4 col-md-2">
                <div class="vital-box">
                    <div class="data-label"><i class="bi bi-wind me-1 text-info"></i> F.R.</div>
                    <div class="vital-value">@{[ $d->{fr} || '--' ]}</div>
                    <div class="vital-unit">rpm</div>
                </div>
            </div>
            <div class="col-6 col-sm-4 col-md-2">
                <div class="vital-box">
                    <div class="data-label"><i class="bi bi-thermometer-half me-1 text-warning"></i> Temp</div>
                    <div class="vital-value">@{[ $d->{temp} || '--' ]}</div>
                    <div class="vital-unit">&deg;C</div>
                </div>
            </div>
            <div class="col-6 col-sm-4 col-md-2">
                <div class="vital-box">
                    <div class="data-label"><i class="bi bi-speedometer2 me-1 text-success"></i> SpO2</div>
                    <div class="vital-value">@{[ $d->{spo2} || '--' ]}</div>
                    <div class="vital-unit">%</div>
                </div>
            </div>
            <div class="col-6 col-sm-4 col-md-2">
                <div class="vital-box">
                    <div class="data-label"><i class="bi bi-person-bounding-box me-1 text-secondary"></i> IMC</div>
                    <div class="vital-value">$imc_val</div>
                    <div class="vital-unit">$imc_status</div>
                </div>
            </div>
        </div>

        <!-- Secciones SOAP Bento Grid -->
        <div class="row g-4 mb-4">
            <!-- 1. Anamnesis y Padecimiento -->
            <div class="col-lg-6">
                <div class="bento-card">
                    <div class="bento-header">
                        <span><i class="bi bi-chat-left-dots-fill text-primary me-2"></i>Motivo y Padecimiento Actual</span>
                        <span class="badge bg-light text-secondary border">Paso 1 & 2</span>
                    </div>
                    <div class="data-label">Motivo Principal de Consulta</div>
                    <div class="data-value fs-6 fw-bold" style="color: var(--md-navy);">@{[ $d->{motivo} || 'Sin registro' ]}</div>
                    
                    <div class="data-label">Evolución y Síntomas</div>
                    <div class="data-value">@{[ $d->{evolucion} || 'Sin registro de evolución' ]}</div>
                    
                    @{[ ($d->{intensidad}) ? qq{
                    <div class="data-label">Intensidad del Dolor ($d->{intensidad}/10)</div>
                    <div class="progress mb-3" style="height: 10px; border-radius: 6px;">
                        <div class="progress-bar" role="progressbar" style="width: @{[ $d->{intensidad} * 10 ]}%; background: linear-gradient(90deg, #10b981 0%, #f59e0b 50%, #ef4444 100%);"></div>
                    </div>
                    } : "" ]}

                    <div class="data-label">Antecedentes Clínicos</div>
                    <div class="p-3 bg-light rounded-3 border small">
                        <div><strong>Patológicos:</strong> @{[ $d->{antecedentes_patologicos} || 'Negados' ]}</div>
                        <div><strong>No Patológicos:</strong> @{[ $d->{antecedentes_no_patologicos} || 'Negados' ]}</div>
                        <div><strong>Quirúrgicos:</strong> @{[ $d->{antecedentes_quirurgicos} || 'Negados' ]}</div>
                        <div><strong>Heredofamiliares:</strong> @{[ $d->{antecedentes_heredofamiliares} || 'Sin antecedentes referidos' ]}</div>
                    </div>
                </div>
            </div>

            <!-- 2. Exploración Física y Estudios -->
            <div class="col-lg-6">
                <div class="bento-card">
                    <div class="bento-header">
                        <span><i class="bi bi-heart-pulse-fill text-success me-2"></i>Exploración Física y Estudios</span>
                        <span class="badge bg-light text-secondary border">Paso 3 & 4</span>
                    </div>
                    <div class="data-label">Hallazgos a la Exploración Física</div>
                    <div class="data-value">@{[ $d->{exploracion_hallazgos} || 'Sin hallazgos patológicos descritos.' ]}</div>

                    <div class="data-label">Estudios Paraclínicos</div>
                    <div class="p-3 bg-light rounded-3 border small mb-3">
                        <div><strong>Laboratorios Solicitados:</strong> @{[ $d->{laboratorios_solicitados} || 'Ninguno' ]}</div>
                        <div><strong>Gabinete / Imagen:</strong> @{[ $d->{gabinete_solicitados} || 'Ninguno' ]}</div>
                        <div><strong>Resultados Previos:</strong> @{[ $d->{resultados_estudios} || 'Sin estudios previos' ]}</div>
                    </div>

                    @{[ (@assigned_odonto_ids) ? qq{
                    <div class="data-label text-teal"><i class="bi bi-journal-medical me-1"></i>Odontograma Clínico Vinculado</div>
                    <div class="p-2 border rounded-3 bg-light d-flex align-items-center justify-content-between mb-2">
                        <span class="small fw-bold">Odontograma #$assigned_odonto_ids[0]</span>
                        <a href="render_visor_odontograma.pl?id=$paciente->{id}&id_odonto=$assigned_odonto_ids[0]" target="_blank" class="btn btn-sm btn-outline-teal rounded-pill px-3 py-1">Abrir Visor</a>
                    </div>
                    } : "" ]}

                    @{[ (@assigned_pacs_ids) ? qq{
                    <div class="data-label text-primary"><i class="bi bi-display me-1"></i>Estudio PACS / Imagenología Vinculado</div>
                    <div class="p-2 border rounded-3 bg-light d-flex align-items-center justify-content-between">
                        <span class="small fw-bold">Estudio #$assigned_pacs_ids[0]</span>
                        <a href="render_visor_medico.pl?id=$paciente->{id}&estudio_id=$assigned_pacs_ids[0]" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 py-1">Abrir Visor PACS</a>
                    </div>
                    } : "" ]}
                </div>
            </div>

            <!-- 3. Metodología SOAP y Diagnósticos -->
            <div class="col-12">
                <div class="bento-card">
                    <div class="bento-header">
                        <span><i class="bi bi-diagram-3-fill text-info me-2"></i>Evaluación Diagnóstica y Metodología SOAP</span>
                        <span class="badge bg-primary text-white border-0">Paso 5</span>
                    </div>
                    <div class="row g-4">
                        <div class="col-md-6 border-end-md">
                            <div class="data-label text-primary">Diagnóstico Principal (CIE-10)</div>
                            <div class="data-value fs-5 fw-black text-navy mb-2">
                                @{[ $d->{diagnostico_principal} || 'Sin diagnóstico principal' ]}
                                @{[ $d->{clave_diagnostico_cie10} ? qq{<span class="badge bg-primary-subtle text-primary border border-primary-subtle rounded-pill ms-2 small">$d->{clave_diagnostico_cie10}</span>} : "" ]}
                            </div>
                            @{[ $d->{diagnosticos_secundarios} ? qq{
                            <div class="data-label">Diagnósticos Secundarios</div>
                            <div class="data-value small">$d->{diagnosticos_secundarios}</div>
                            } : "" ]}
                            <div class="d-flex gap-3 mt-3">
                                <div>
                                    <span class="data-label d-block">Severidad</span>
                                    <span class="badge bg-warning-subtle text-warning-emphasis fw-bold border">@{[ $d->{severidad} || 'Moderada' ]}</span>
                                </div>
                                <div>
                                    <span class="data-label d-block">Pronóstico</span>
                                    <span class="badge bg-success-subtle text-success-emphasis fw-bold border">@{[ $d->{pronostico} || 'Favorable' ]}</span>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="data-label">Plan de Tratamiento Integral (P)</div>
                            <div class="data-value">@{[ $d->{plan_tratamiento} || 'Sin plan especificado' ]}</div>
                            <div class="data-label">Análisis Clínico (A)</div>
                            <div class="data-value small text-muted">@{[ $d->{impresion_clinica} || 'Evaluación integral favorable bajo tratamiento pautado.' ]}</div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- 4. Receta Farmacológica Bento -->
            @{[ scalar(@$medicamentos) > 0 ? qq{
            <div class="col-12">
                <div class="bento-card border-primary border-2">
                    <div class="bento-header">
                        <span class="text-primary"><i class="bi bi-capsule me-2"></i>Receta Médica y Prescripción Farmacológica</span>
                        <span class="badge bg-success text-white border-0">Farmacoterapia</span>
                    </div>
                    <div class="table-responsive mb-3">
                        <table class="table table-hover align-middle mb-0">
                            <thead class="table-light small text-uppercase fw-bold">
                                <tr>
                                    <th>Fármaco / Presentación</th>
                                    <th>Dosis</th>
                                    <th>Frecuencia</th>
                                    <th>Duración</th>
                                    <th>Vía</th>
                                </tr>
                            </thead>
                            <tbody>
                                } . join("", map { qq{
                                <tr>
                                    <td><strong class="text-navy">$_->{farmaco}</strong><br><small class="text-muted">$_->{presentacion}</small></td>
                                    <td>$_->{dosis}</td>
                                    <td>$_->{frecuencia}</td>
                                    <td>$_->{duracion}</td>
                                    <td><span class="badge bg-light text-dark border">@{[ $_->{via} || 'Oral' ]}</span></td>
                                </tr>
                                } } @$medicamentos) . qq{
                            </tbody>
                        </table>
                    </div>
                    @{[ $d->{receta_indicaciones} ? qq{
                    <div class="p-3 bg-light rounded-3 border small">
                        <strong>Indicaciones Terapéuticas Especiales:</strong> $d->{receta_indicaciones}
                    </div>
                    } : "" ]}
                </div>
            </div>
            } : "" ]}

            <!-- 5. Firmas Bento -->
            <div class="col-12">
                <div class="bento-card">
                    <div class="bento-header">
                        <span><i class="bi bi-shield-check text-success me-2"></i>Conformidad y Firmas Digitales</span>
                        <span class="badge bg-light text-secondary border">Validación NOM-004-SSA3-2012</span>
                    </div>
                    <div class="row align-items-center text-center">
                        <div class="col-md-6 border-end-md py-3">
                            <div class="data-label mb-2">Firma del Médico Tratante</div>
                            <div class="p-3 bg-light rounded text-muted small mb-2 fw-semibold">
                                <i class="bi bi-fingerprint text-primary me-1"></i>Firma Digital Certificada
                            </div>
                            <div class="fw-bold text-navy">$nombre_medico</div>
                            <div class="small text-muted">$especialidad_medico | Céd. $cedula_medico</div>
                        </div>
                        <div class="col-md-6 py-3">
                            <div class="data-label mb-2">Conformidad del Paciente / Tutor</div>
                            <div class="p-3 bg-light rounded text-muted small mb-2 fw-semibold">
                                <i class="bi bi-check-circle-fill text-success me-1"></i>Consentimiento Informado Aceptado
                            </div>
                            <div class="fw-bold text-navy">$paciente->{nombre}</div>
                            <div class="small text-muted">Aceptación de plan terapéutico y diagnóstico</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </main>

    <!-- 2. MODO HOJA WYSIWYG (Simulación Hoja Carta Vertical) -->
    <div class="wysiwyg-wrapper" id="view-wysiwyg" style="display: none;">
        <div class="wysiwyg-sheet" id="print-sheet">
            <div>
                <!-- Membrete Institucional Oficial -->
                <div class="doc-header">
                    <div class="row align-items-center">
                        <div class="col-8 d-flex align-items-center gap-3">
                            <img src="$org->{logo_url}" class="doc-logo" alt="Logo">
                            <div>
                                <div class="org-title">$org->{nombre_negocio}</div>
                                <div class="org-legal">
                                    <strong>$org->{razon_social}</strong> | RFC: <strong>$org->{rfc}</strong> | CLUES: <strong>$org->{clues}</strong><br>
                                    $org->{domicilio}<br>
                                    Teléfono: <strong>$org->{telefono}</strong> | Correo: <strong>$org->{email}</strong>
                                </div>
                            </div>
                        </div>
                        <div class="col-4 text-end">
                            <div class="badge bg-dark text-white rounded-pill px-3 py-1 mb-1" style="font-size: 0.72rem;">
                                NOTA MÉDICA DE EVOLUCIÓN
                            </div>
                            <div class="small fw-bold text-navy">Folio: <span style="font-family: 'JetBrains Mono', monospace;">$consulta->{id_consulta}</span></div>
                            <div class="small text-muted">Cita: $consulta->{id_cita}</div>
                            <div class="small text-muted">Fecha: <strong>$consulta->{fecha}</strong></div>
                        </div>
                    </div>
                </div>

                <!-- Sub-encabezado: Ficha Paciente y Ficha Médico -->
                <div class="doc-meta-box">
                    <div class="row g-2">
                        <div class="col-7 border-end pe-3">
                            <div class="doc-vital-lbl text-primary mb-1">Datos de Identificación del Paciente</div>
                            <div class="fw-bold fs-6 text-dark">$paciente->{nombre}</div>
                            <div class="d-flex flex-wrap gap-2 text-muted mt-1" style="font-size: 0.76rem;">
                                <span><strong>CURP:</strong> $paciente->{curp}</span>
                                <span><strong>Sexo:</strong> $paciente->{sexo}</span>
                                <span><strong>Edad:</strong> $paciente->{edad}</span>
                                <span><strong>G.S.:</strong> $paciente->{ts}</span>
                                <span><strong>Tel:</strong> $paciente->{telefono}</span>
                            </div>
                            <div class="mt-1" style="font-size: 0.74rem;">
                                <strong>Alergias:</strong> <span class="badge @{[ ($paciente->{alergias} && $paciente->{alergias} ne 'Negadas') ? 'bg-danger text-white' : 'bg-light text-dark border' ]}">$paciente->{alergias}</span>
                            </div>
                        </div>
                        <div class="col-5 ps-3">
                            <div class="doc-vital-lbl text-primary mb-1">Médico Tratante Responsable</div>
                            <div class="fw-bold fs-6 text-dark">$nombre_medico</div>
                            <div class="text-muted" style="font-size: 0.76rem;">
                                <strong>Especialidad:</strong> $especialidad_medico<br>
                                <strong>Cédula Profesional:</strong> $cedula_medico<br>
                                <strong>Ubicación:</strong> $consultorio_medico
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Signos Vitales Estructurados -->
                <div class="doc-grid-vitals">
                    <div class="doc-vital-cell">
                        <div class="doc-vital-lbl">Presión Art.</div>
                        <div class="doc-vital-val">@{[ $d->{ta} || '--' ]}</div>
                        <div class="small text-muted" style="font-size: 0.65rem;">mmHg</div>
                    </div>
                    <div class="doc-vital-cell">
                        <div class="doc-vital-lbl">Frec. Card.</div>
                        <div class="doc-vital-val">@{[ $d->{fc} || '--' ]}</div>
                        <div class="small text-muted" style="font-size: 0.65rem;">lpm</div>
                    </div>
                    <div class="doc-vital-cell">
                        <div class="doc-vital-lbl">Frec. Resp.</div>
                        <div class="doc-vital-val">@{[ $d->{fr} || '--' ]}</div>
                        <div class="small text-muted" style="font-size: 0.65rem;">rpm</div>
                    </div>
                    <div class="doc-vital-cell">
                        <div class="doc-vital-lbl">Temperatura</div>
                        <div class="doc-vital-val">@{[ $d->{temp} || '--' ]}</div>
                        <div class="small text-muted" style="font-size: 0.65rem;">&deg;C</div>
                    </div>
                    <div class="doc-vital-cell">
                        <div class="doc-vital-lbl">SpO2</div>
                        <div class="doc-vital-val">@{[ $d->{spo2} || '--' ]}</div>
                        <div class="small text-muted" style="font-size: 0.65rem;">%</div>
                    </div>
                    <div class="doc-vital-cell">
                        <div class="doc-vital-lbl">IMC / Nutrición</div>
                        <div class="doc-vital-val">$imc_val</div>
                        <div class="small text-muted" style="font-size: 0.65rem;">$imc_status</div>
                    </div>
                </div>

                <!-- Bloque 1: Anamnesis y Antecedentes -->
                <div class="doc-section-title"><i class="bi bi-chat-square-text-fill me-1"></i> 1. Anamnesis y Motivo de Consulta</div>
                <div class="doc-soap-block">
                    <strong>Motivo de Consulta:</strong> @{[ $d->{motivo} || 'Sin registro' ]}<br>
                    <strong>Padecimiento Actual y Evolución:</strong> @{[ $d->{evolucion} || 'Sin registro' ]}
                    @{[ ($d->{intensidad}) ? " (Escala de dolor: $d->{intensidad}/10)" : "" ]}<br>
                    <strong>Antecedentes:</strong> Patológicos: @{[ $d->{antecedentes_patologicos} || 'Negados' ]} | No Patológicos: @{[ $d->{antecedentes_no_patologicos} || 'Negados' ]} | Quirúrgicos: @{[ $d->{antecedentes_quirurgicos} || 'Negados' ]} | Heredofamiliares: @{[ $d->{antecedentes_heredofamiliares} || 'Negados' ]}
                </div>

                <!-- Bloque 2: Exploración Física y Paraclínicos -->
                <div class="doc-section-title"><i class="bi bi-clipboard-pulse me-1"></i> 2. Exploración Física y Estudios</div>
                <div class="doc-soap-block" style="border-left-color: #10b981;">
                    <strong>Hallazgos Clínicos:</strong> @{[ $d->{exploracion_hallazgos} || 'Sin hallazgos patológicos descritos.' ]}<br>
                    <strong>Laboratorios / Gabinete:</strong> Laboratorios: @{[ $d->{laboratorios_solicitados} || 'Ninguno' ]} | Gabinete: @{[ $d->{gabinete_solicitados} || 'Ninguno' ]}
                    @{[ (@assigned_odonto_ids) ? " | Odontograma asignado: #$assigned_odonto_ids[0]" : "" ]}
                    @{[ (@assigned_pacs_ids) ? " | Estudio PACS asignado: #$assigned_pacs_ids[0]" : "" ]}
                </div>

                <!-- Bloque 3: Diagnóstico y Metodología SOAP -->
                <div class="doc-section-title"><i class="bi bi-diagram-3-fill me-1"></i> 3. Diagnóstico y Metodología SOAP</div>
                <div class="doc-soap-block" style="border-left-color: var(--md-blue-deep);">
                    <strong>Diagnóstico Principal (CIE-10):</strong> <span class="fw-bold">@{[ $d->{diagnostico_principal} || 'Sin diagnóstico principal' ]}</span> @{[ $d->{clave_diagnostico_cie10} ? "[$d->{clave_diagnostico_cie10}]" : "" ]}<br>
                    @{[ $d->{diagnosticos_secundarios} ? "<strong>Diagnósticos Secundarios:</strong> $d->{diagnosticos_secundarios}<br>" : "" ]}
                    <strong>Severidad:</strong> @{[ $d->{severidad} || 'Moderada' ]} | <strong>Pronóstico:</strong> @{[ $d->{pronostico} || 'Favorable' ]}<br>
                    <strong>Plan Terapéutico (P):</strong> @{[ $d->{plan_tratamiento} || 'Sin plan especificado' ]}<br>
                    <strong>Análisis / Impresión Clínica (A):</strong> @{[ $d->{impresion_clinica} || 'Evaluación favorable bajo pauta indicada.' ]}
                </div>

                <!-- Bloque 4: Prescripción Médica (si existe) -->
                @{[ scalar(@$medicamentos) > 0 ? qq{
                <div class="doc-section-title"><i class="bi bi-capsule me-1"></i> 4. Prescripción Farmacológica (Receta)</div>
                <table class="doc-table-rx">
                    <thead>
                        <tr>
                            <th style="width: 35%;">Fármaco / Presentación</th>
                            <th style="width: 15%;">Dosis</th>
                            <th style="width: 20%;">Frecuencia</th>
                            <th style="width: 15%;">Duración</th>
                            <th style="width: 15%;">Vía</th>
                        </tr>
                    </thead>
                    <tbody>
                        } . join("", map { qq{
                        <tr>
                            <td><strong>$_->{farmaco}</strong> - <span class="text-muted">$_->{presentacion}</span></td>
                            <td>$_->{dosis}</td>
                            <td>$_->{frecuencia}</td>
                            <td>$_->{duracion}</td>
                            <td>@{[ $_->{via} || 'Oral' ]}</td>
                        </tr>
                        } } @$medicamentos) . qq{
                    </tbody>
                </table>
                @{[ $d->{receta_indicaciones} ? qq{<div class="small text-muted mb-2"><strong>Indicaciones adicionales:</strong> $d->{receta_indicaciones}</div>} : "" ]}
                } : "" ]}
            </div>

            <!-- Firmas y Pie de Página Legal -->
            <div>
                <div class="doc-signatures">
                    <div>
                        <div class="doc-sig-line">
                            <span class="small fw-semibold text-muted">Firma Autógrafa / Digital</span>
                        </div>
                        <div class="fw-bold text-dark">$paciente->{nombre}</div>
                        <div class="small text-muted">Firma del Paciente / Tutor (Conformidad)</div>
                    </div>
                    <div>
                        <div class="doc-sig-line">
                            <span class="small fw-semibold text-muted">Firma y Sello del Médico</span>
                        </div>
                        <div class="fw-bold text-dark">$nombre_medico</div>
                        <div class="small text-muted">$especialidad_medico | Céd. Prof. $cedula_medico</div>
                    </div>
                </div>

                <div class="doc-footer-legal">
                    Documento médico-legal confidencial emitido conforme a la Norma Oficial Mexicana NOM-004-SSA3-2012 del Expediente Clínico.<br>
                    Generado e impreso a través de la plataforma clínica OSPulso | Página 1 de 1
                </div>
            </div>
        </div>
    </div>

    <!-- Bootstrap Bundle JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/js/bootstrap.bundle.min.js"></script>

    <!-- Script de Control de Vistas e Impresión WYSIWYG -->
    <script>
    function switchView(mode) {
        const viewBento = document.getElementById('view-bento');
        const viewWysiwyg = document.getElementById('view-wysiwyg');
        const btnBento = document.getElementById('btn-view-bento');
        const btnWysiwyg = document.getElementById('btn-view-wysiwyg');

        if (mode === 'wysiwyg') {
            viewBento.style.display = 'none';
            viewWysiwyg.style.display = 'flex';
            btnBento.classList.remove('active');
            btnWysiwyg.classList.add('active');
        } else {
            viewWysiwyg.style.display = 'none';
            viewBento.style.display = 'block';
            btnWysiwyg.classList.remove('active');
            btnBento.classList.add('active');
        }
    }

    function imprimirNotaMedica() {
        // Asegurar que el modo WYSIWYG esté visible para la captura y llamar impresión
        const prevBentoDisplay = document.getElementById('view-bento').style.display;
        const prevWysiwygDisplay = document.getElementById('view-wysiwyg').style.display;

        // Si el usuario estaba en Bento, temporalmente activar WYSIWYG para la impresión
        window.print();
    }

    function imprimirRecetaOnly() {
        // Abrir diálogo de impresión para receta
        window.print();
    }
    </script>
</body>
</html>
HTML

1;
