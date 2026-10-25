#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON qw(decode_json encode_json);
use MIME::Base64 qw(encode_base64);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session($q);

print $q->header(-type => 'text/html', -charset => 'UTF-8');

unless ($session_data->{session_ok}) {
    print qq{
        <!DOCTYPE html>
        <html lang="es">
        <head><meta charset="UTF-8"><title>Acceso no autorizado | OsPulso</title></head>
        <body style="font-family: sans-serif; text-align: center; padding: 50px; background: #f8fafc;">
            <h2 style="color: #0A2A66;">Acceso No Autorizado</h2>
            <p>Debe iniciar sesión para visualizar e imprimir este reporte.</p>
            <a href="../index.html" style="color: #19B7A5; font-weight: bold;">Iniciar Sesión</a>
        </body>
        </html>
    };
    exit;
}

my $tipo     = $q->param('tipo') || 'dia_reporte';
$tipo = 'dia_reporte' if $tipo eq 'dia';
my $fecha    = $q->param('fecha') || '';
my $medicos_param  = $q->param('medicos') // 'all';
my $recursos_param = $q->param('recursos') // 'all';

# 1. Resolver fecha base (YYYY-MM-DD)
unless ($fecha =~ /^\d{4}-\d{2}-\d{2}$/) {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    $fecha = sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
}

my ($y, $m, $d) = split(/-/, $fecha);
my $my_org = $session_data->{id_empresa} // '0';
$my_org = '0' if $my_org eq '';

# Función canónica de normalización de espacios (Idéntica a normalizarTextoEspacio en JS)
sub normalizar_espacio_perl {
    my ($str) = @_;
    return '' unless defined $str;
    $str = lc($str);
    $str =~ s/[áàäâ]/a/g;
    $str =~ s/[éèëê]/e/g;
    $str =~ s/[íìïî]/i/g;
    $str =~ s/[óòöô]/o/g;
    $str =~ s/[úùüû]/u/g;
    $str =~ s/ñ/n/g;
    $str =~ s/[^a-z0-9]/ /g;
    $str =~ s/\bquirofanos?\b/qx/g;
    $str =~ s/\bconsultorios?\b/cons/g;
    $str =~ s/\s+/ /g;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

# 2. Obtener Datos de la Clínica desde negocios.dat (nombre, logo, clues, jerarquía matriz)
my $nombre_clinica = "Clínica Médica de Especialidades";
my $clues_clinica = "";
my $logo_url_clinica = "";
my %id_matriz_map;

my $neg_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $neg_file && open my $fhn, '<:encoding(UTF-8)', $neg_file) {
    my $cnt = 0;
    while (my $line = <$fhn>) {
        $cnt++;
        $line =~ s/\R//g;
        next if $cnt == 1 || $line =~ /^\s*$/;
        my @f = split(/\|/, $line);
        my $neg_id = $f[0] // '';
        my $id_mat = $f[2] // '0';
        $id_matriz_map{$neg_id} = $id_mat if $neg_id;
        
        if ($neg_id eq $my_org || ($my_org ne '0' && ($id_mat eq $my_org || $neg_id eq '723800'))) {
            $nombre_clinica = $f[1] if $f[1] && ($nombre_clinica eq "Clínica Médica de Especialidades" || $neg_id eq $my_org);
            $clues_clinica = $f[18] if scalar(@f) > 18 && $f[18] && $f[18] ne 'No aplica';
            $logo_url_clinica = $f[9] if scalar(@f) > 9 && $f[9] && $f[9] ne 'No aplica';
        }
    }
    close $fhn;
}

# Resolver Logo Oficial con incrustación Base64 Anti-Bloqueo (.htaccess)
my $logo_img_html = '';
my $logo_path = '';

if ($clues_clinica) {
    my $p1 = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'logos', "logo_${clues_clinica}.jpg");
    my $p2 = File::Spec->catfile($FindBin::Bin, '..', 'img', 'logos', "logo_${clues_clinica}.jpg");
    if (-e $p1) { $logo_path = $p1; }
    elsif (-e $p2) { $logo_path = $p2; }
}
if (!$logo_path && -e File::Spec->catfile($FindBin::Bin, '..', 'dat', 'logos', "logo_QTSMP000116.jpg")) {
    $logo_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'logos', "logo_QTSMP000116.jpg");
}
if (!$logo_path && $my_org ne '0') {
    my $p3 = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'logos', "logo_${my_org}.jpg");
    my $p4 = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'logos', "logo_${my_org}.png");
    if (-e $p3) { $logo_path = $p3; }
    elsif (-e $p4) { $logo_path = $p4; }
}
if (!$logo_path && $logo_url_clinica && $logo_url_clinica ne 'No aplica') {
    my $p5 = File::Spec->catfile($FindBin::Bin, '..', $logo_url_clinica);
    $logo_path = $p5 if -e $p5;
}

if ($logo_path && -e $logo_path && open(my $lfh, '<:raw', $logo_path)) {
    my $raw_img = do { local $/; <$lfh> };
    close $lfh;
    my $b64_img = encode_base64($raw_img, '');
    my $mime = ($logo_path =~ /\.png$/i) ? 'image/png' : 'image/jpeg';
    $logo_img_html = qq{<img src="data:$mime;base64,$b64_img" alt="Logo Institucional" style="max-height: 48px; max-width: 140px; object-fit: contain;">};
} else {
    $logo_img_html = qq{<img src="../favicon/favicon.svg" alt="OSPulso Logo" style="width: 44px; height: 44px; object-fit: contain;">};
}

# 3. Precargar Médicos desde usuarios.dat
my %meds_nombres;
my $file_usu = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
if (-e $file_usu && open my $fhu, '<:encoding(UTF-8)', $file_usu) {
    my $cnt = 0;
    while (my $l = <$fhu>) {
        $cnt++;
        $l =~ s/\R//g;
        next if $cnt == 1 || $l =~ /^\s*$/;
        my @u = split(/!/, $l);
        $meds_nombres{$u[0]} = $u[1] if $u[0] && $u[1];
    }
    close $fhu;
}

# 4. Precargar Pacientes desde pacientes.dat
my %pacs_nombres;
my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
if (-e $pac_file && open my $fhp, '<:encoding(UTF-8)', $pac_file) {
    my $cnt = 0;
    while (my $l = <$fhp>) {
        $cnt++;
        $l =~ s/\R//g;
        next if $cnt == 1 || $l =~ /^\s*$/;
        my @p = split(/\|/, $l);
        $pacs_nombres{$p[0]} = $p[2] if scalar(@p) >= 3;
    }
    close $fhp;
}

# 5. Calcular Rango de Fechas según tipo de reporte
use Time::Local;
my $ts_base = eval { timelocal(0, 0, 12, $d, $m - 1, $y) } || time();
my @dias_nom = ('domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado');
my @meses_nom = ('enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre');

my ($sec0,$min0,$hour0,$mday0,$mon0,$year0,$wday0) = localtime($ts_base);
my $dia_sem_str = $dias_nom[$wday0];
my $mes_str     = $meses_nom[$mon0];

my $titulo_doc = "REPORTE DIARIO DE CITAS MÉDICAS";
my $periodo_label = "Día: $dia_sem_str, $d de $mes_str de $y";
my $f_inicio = $fecha;
my $f_fin    = $fecha;

if ($tipo eq 'semana') {
    $titulo_doc = "REPORTE SEMANAL DE CITAS MÉDICAS";
    my $iso_wday = ($wday0 == 0) ? 7 : $wday0; # 1=Lun ... 7=Dom
    my $ts_lunes = $ts_base - (($iso_wday - 1) * 86400);
    my $ts_dom   = $ts_lunes + (6 * 86400);
    my @l = localtime($ts_lunes);
    my @dm = localtime($ts_dom);
    $f_inicio = sprintf("%04d-%02d-%02d", $l[5]+1900, $l[4]+1, $l[3]);
    $f_fin    = sprintf("%04d-%02d-%02d", $dm[5]+1900, $dm[4]+1, $dm[3]);
    my $mes_ini = $meses_nom[$l[4]];
    my $mes_fin = $meses_nom[$dm[4]];
    $periodo_label = "Semana: del $l[3] de $mes_ini al $dm[3] de $mes_fin de " . ($dm[5]+1900);
} elsif ($tipo eq 'mes') {
    $titulo_doc = "REPORTE MENSUAL DE CITAS MÉDICAS";
    $f_inicio = sprintf("%04d-%02d-01", $y, $m);
    my $ts_prox = ($m == 12) ? timelocal(0, 0, 12, 1, 0, $y + 1) : timelocal(0, 0, 12, 1, $m, $y);
    my $ts_ult = $ts_prox - 86400;
    my @u = localtime($ts_ult);
    $f_fin = sprintf("%04d-%02d-%02d", $u[5]+1900, $u[4]+1, $u[3]);
    $periodo_label = "Mes: $mes_str de $y";
}

# 6. Parsear filtros de médicos y recursos
my %meds_filter;
if ($medicos_param ne 'all' && $medicos_param ne '' && $medicos_param ne 'none') {
    foreach my $id (split(/,/, $medicos_param)) {
        $id =~ s/^\s+|\s+$//g;
        $meds_filter{$id} = 1 if $id ne '';
    }
}

my %recs_filter;
if ($recursos_param ne 'all' && $recursos_param ne '' && $recursos_param ne 'none') {
    foreach my $r (split(/,/, $recursos_param)) {
        $r =~ s/^\s+|\s+$//g;
        $recs_filter{lc($r)} = 1 if $r ne '';
    }
}

# 7. Leer y filtrar citas desde dat/citas.dat
my @citas_filtradas;
my $total_citas = 0;
my $cnt_confirmadas = 0;
my $cnt_en_espera = 0;
my $cnt_atendidas = 0;

my $citas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
if (-e $citas_file && open my $fhc, '<:encoding(UTF-8)', $citas_file) {
    my $cnt = 0;
    while (my $line = <$fhc>) {
        $cnt++;
        $line =~ s/\R//g;
        next if $cnt == 1 || $line =~ /^\s*$/;
        my @c = split(/\|/, $line);
        next unless scalar(@c) >= 6;
        
        my $id_c   = $c[0];
        my $id_m   = $c[1];
        my $id_p   = $c[2];
        my $f_cita = $c[3];
        my $h_ini  = $c[4];
        my $h_fin  = $c[5];
        my $motivo = $c[6] // 'Consulta';
        my $estado = $c[8] // 'Programada';
        my $suc    = $c[12] // '';
        my $espacio= $c[13] // 'Consultorio 1';
        my $id_neg = $c[14] // '';

        next if $estado =~ /^Cancelada$/i;

        # Filtro de empresa / organización con tolerancia a matriz y sucursales
        if ($my_org ne '0' && $my_org ne '') {
            my $match_org = 0;
            if ($id_neg eq '' || $id_neg eq '0' || $id_neg eq $my_org) {
                $match_org = 1;
            } elsif ($suc ne '' && $suc eq $my_org) {
                $match_org = 1;
            } elsif ($id_matriz_map{$suc} && $id_matriz_map{$suc} eq $my_org) {
                $match_org = 1;
            } elsif ($id_matriz_map{$my_org} && ($id_matriz_map{$my_org} eq $id_neg || $id_matriz_map{$my_org} eq $suc)) {
                $match_org = 1;
            }
            next unless $match_org;
        }

        # Filtro de rango de fecha
        next if ($f_cita lt $f_inicio || $f_cita gt $f_fin);

        # Filtro de médicos
        if (%meds_filter) {
            next unless $meds_filter{$id_m};
        }

        # Filtro de recursos / espacios físico robusto
        if (%recs_filter) {
            my $norm_esp = normalizar_espacio_perl($espacio);
            my $match_rec = 0;
            foreach my $rf (keys %recs_filter) {
                if ($rf =~ /^suc_(\d+)_(.+)$/i) {
                    my $rf_suc = $1;
                    my $rf_sub = $2;
                    if ($suc ne '' && $suc ne '0' && $suc ne $rf_suc) {
                        next;
                    }
                    my $norm_sub = normalizar_espacio_perl($rf_sub);
                    if ($norm_esp eq $norm_sub || index($norm_esp, $norm_sub) != -1 || index($norm_sub, $norm_esp) != -1) {
                        $match_rec = 1;
                        last;
                    }
                } else {
                    my $norm_rf = normalizar_espacio_perl($rf);
                    if ($norm_esp eq $norm_rf || index($norm_esp, $norm_rf) != -1 || index($norm_rf, $norm_esp) != -1) {
                        $match_rec = 1;
                        last;
                    }
                }
            }
            next unless $match_rec;
        }

        my $pac_nombre = $pacs_nombres{$id_p} || "Paciente #$id_p";
        my $med_nombre = $meds_nombres{$id_m} || "Profesional Asignado";

        # Contadores cuantitativos
        $total_citas++;
        if ($estado =~ /^(Atendida)$/i) {
            $cnt_atendidas++;
        } elsif ($estado =~ /^(En Sala de Espera|En consulta|Consulta en proceso)$/i) {
            $cnt_en_espera++;
        } else {
            $cnt_confirmadas++;
        }

        push @citas_filtradas, {
            id        => $id_c,
            fecha     => $f_cita,
            hora_ini  => $h_ini,
            hora_fin  => $h_fin,
            paciente  => $pac_nombre,
            id_pac    => $id_p,
            motivo    => $motivo,
            medico    => $med_nombre,
            espacio   => $espacio,
            estado    => $estado
        };
    }
    close $fhc;
}

# Ordenar cronológicamente
@citas_filtradas = sort { ($a->{fecha} . ' ' . $a->{hora_ini}) cmp ($b->{fecha} . ' ' . $b->{hora_ini}) } @citas_filtradas;

# Generar Folio y Fecha de Emisión
my ($s_now,$m_now,$h_now,$d_now,$mon_now,$y_now) = localtime(time);
my $fecha_emision = sprintf("%02d/%02d/%04d %02d:%02d hrs", $d_now, $mon_now + 1, $y_now + 1900, $h_now, $m_now);
my $folio_reporte = "SDM-REP-" . substr(time(), -6);

# Etiquetas de Filtros
my $medicos_label = (%meds_filter) ? scalar(keys %meds_filter) . " médico(s) seleccionado(s)" : "Todos los Médicos";
my $espacios_label = (%recs_filter) ? scalar(keys %recs_filter) . " espacio(s) seleccionado(s)" : "Todos los Espacios";

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>$titulo_doc | OsPulso</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --md-blue-deep: #0A2A66;
            --md-teal-clinical: #19B7A5;
        }
        body { 
            font-family: 'Plus Jakarta Sans', sans-serif; 
            background: #f1f5f9; 
            color: #1e293b; 
            margin: 0; 
            padding: 20px 0 40px 0; 
        }
        .doc-card { 
            max-width: 980px; 
            margin: 1.25rem auto; 
            background: #ffffff; 
            border-radius: 18px; 
            border: 1.5px solid var(--md-blue-deep); 
            box-shadow: 0 15px 35px rgba(10, 42, 102, 0.08); 
            padding: 2.5rem; 
        }
        .header-brand { 
            border-bottom: 2px solid var(--md-blue-deep); 
            padding-bottom: 1.5rem; 
            margin-bottom: 1.5rem; 
        }
        .kpi-box {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 0.85rem;
            text-align: center;
            box-shadow: 0 2px 6px rgba(0,0,0,0.03);
        }
        .kpi-title {
            font-size: 0.68rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #64748b;
            display: block;
            margin-bottom: 0.25rem;
        }
        .kpi-val {
            font-size: 1.65rem;
            font-weight: 800;
            line-height: 1;
        }
        .table-rep th {
            background-color: #F8FBFF !important;
            color: var(--md-blue-deep) !important;
            font-size: 0.74rem !important;
            font-weight: 700 !important;
            text-transform: uppercase !important;
            letter-spacing: 0.5px !important;
            border-bottom: 2px solid #cbd5e1 !important;
            padding: 0.65rem 0.6rem !important;
        }
        .table-rep td {
            font-size: 0.82rem !important;
            vertical-align: middle !important;
            padding: 0.65rem 0.6rem !important;
            border-bottom: 1px solid #f1f5f9 !important;
        }
        .footer-legal { 
            border-top: 1px solid #cbd5e1; 
            margin-top: 2rem; 
            padding-top: 1.25rem; 
            font-size: 0.72rem; 
            color: #64748b; 
        }
        \@media print {
            body { 
                background: #ffffff !important; 
                padding: 0 !important; 
                margin: 0 !important; 
                -webkit-print-color-adjust: exact !important; 
                print-color-adjust: exact !important; 
            }
            .no-print { 
                display: none !important; 
            }
            .doc-card { 
                border: none !important; 
                box-shadow: none !important; 
                padding: 0 !important; 
                margin: 0 !important; 
                max-width: 100% !important; 
                width: 100% !important; 
            }
            \@page { 
                size: letter portrait; 
                margin: 10mm 12mm; 
            }
            tr { 
                page-break-inside: avoid !important; 
            }
        }
    </style>
</head>
<body>
    <!-- Barra Superior de Control de Impresión (No-Print) -->
    <div class="container no-print d-flex align-items-center justify-content-between mb-3" style="max-width: 980px;">
        <div class="d-flex align-items-center gap-2">
            <span class="badge bg-white text-navy border fw-bold px-3 py-2 shadow-xs" style="color: var(--md-blue-deep);">
                <i class="bi bi-file-earmark-ruled me-1 text-teal" style="color: var(--md-teal-clinical);"></i> Vista de Impresión Oficial
            </span>
        </div>
        <div class="d-flex align-items-center gap-2">
            <button onclick="window.print()" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm" style="background-color: var(--md-blue-deep); border-color: var(--md-blue-deep);">
                <i class="bi bi-printer-fill me-2" style="color: var(--md-teal-clinical);"></i>Imprimir Reporte
            </button>
            <button onclick="window.close()" class="btn btn-outline-secondary rounded-pill px-4 fw-semibold bg-white shadow-xs">
                <i class="bi bi-x-lg me-1"></i>Cerrar
            </button>
        </div>
    </div>

    <!-- Documento Clínico Formal (.doc-card) -->
    <div class="doc-card" id="documentoReporte">
        <!-- Encabezado Institucional -->
        <div class="header-brand d-flex justify-content-between align-items-center">
            <div class="d-flex align-items-center gap-3">
                <div class="d-flex align-items-center justify-content-center rounded-3 bg-white border shadow-xs p-1" style="min-width: 54px; height: 54px;">
                    $logo_img_html
                </div>
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep); font-size: 1.35rem; letter-spacing: 0.5px;">$nombre_clinica</h3>
                    <h5 class="fw-bold m-0" style="color: var(--md-teal-clinical); font-size: 1rem;">$titulo_doc</h5>
                    <span class="badge bg-light text-navy border px-2.5 py-1 small mt-1 fw-bold" style="color: var(--md-blue-deep); font-size: 0.78rem;">$periodo_label</span>
                </div>
            </div>
            <div class="text-end">
                <span class="badge bg-primary-subtle text-primary border border-primary px-3 py-1 fw-bold small d-inline-block mb-1" style="font-size: 0.76rem;">$folio_reporte</span>
                <div class="text-muted small" style="font-size: 0.75rem;">Emisión: $fecha_emision</div>
            </div>
        </div>

        <!-- Píldoras de Filtros Activos -->
        <div class="d-flex flex-wrap align-items-center gap-2 mb-3 bg-light p-2.5 rounded-3 border">
            <span class="fw-bold small" style="color: var(--md-blue-deep); font-size: 0.80rem;"><i class="bi bi-funnel-fill text-primary me-1"></i>Filtros Activos:</span>
            <span class="badge bg-white text-dark border fw-semibold px-2.5 py-1.5" id="filtroBadgeMedicos"><i class="bi bi-person-badge text-primary me-1"></i>Médicos: $medicos_label</span>
            <span class="badge bg-white text-dark border fw-semibold px-2.5 py-1.5" id="filtroBadgeEspacios"><i class="bi bi-door-open-fill text-teal me-1" style="color: var(--md-teal-clinical);"></i>Espacios: $espacios_label</span>
        </div>

        <!-- Resumen Cuantitativo (KPIs) -->
        <div class="row g-2 mb-4">
            <div class="col-3">
                <div class="kpi-box">
                    <span class="kpi-title">Total Citas</span>
                    <span class="kpi-val" id="kpiValTotal" style="color: var(--md-blue-deep);">$total_citas</span>
                </div>
            </div>
            <div class="col-3">
                <div class="kpi-box">
                    <span class="kpi-title">Confirmadas / Prog.</span>
                    <span class="kpi-val text-primary" id="kpiValConfirmadas">$cnt_confirmadas</span>
                </div>
            </div>
            <div class="col-3">
                <div class="kpi-box">
                    <span class="kpi-title">En Sala / Atención</span>
                    <span class="kpi-val text-warning" id="kpiValProceso">$cnt_en_espera</span>
                </div>
            </div>
            <div class="col-3">
                <div class="kpi-box">
                    <span class="kpi-title">Atendidas</span>
                    <span class="kpi-val" id="kpiValAtendidas" style="color: var(--md-teal-clinical);">$cnt_atendidas</span>
                </div>
            </div>
        </div>

        <!-- Tabla Estilizada de Citas -->
        <div class="table-responsive rounded-3 border mb-4">
            <table class="table table-hover table-rep align-middle mb-0">
                <thead>
                    <tr>
                        <th class="py-2.5 px-3">Fecha</th>
                        <th class="py-2.5 px-2">Horario</th>
                        <th class="py-2.5 px-3">Paciente</th>
                        <th class="py-2.5 px-2">Motivo</th>
                        <th class="py-2.5 px-2">Médico</th>
                        <th class="py-2.5 px-2">Espacio</th>
                        <th class="py-2.5 px-2 text-center">Estado</th>
                    </tr>
                </thead>
                <tbody id="citasTableBody">
HTML

if (@citas_filtradas == 0) {
    print qq{
        <tr>
            <td colspan="7" class="text-center py-5 text-muted">
                <i class="bi bi-calendar-x fs-2 d-block mb-1 opacity-50"></i>
                No se registraron citas en este periodo con los filtros seleccionados.
            </td>
        </tr>
    };
} else {
    foreach my $c (@citas_filtradas) {
        my $h_disp = ($c->{hora_fin}) ? "$c->{hora_ini} - $c->{hora_fin}" : $c->{hora_ini};
        my $st = $c->{estado};
        my $badge_cls = ($st =~ /^Atendida$/i) ? 'bg-success text-white' : 
                        ($st =~ /^(En Sala de Espera)$/i) ? 'bg-warning text-dark' : 
                        ($st =~ /^(En consulta|Consulta en proceso)$/i) ? 'bg-info text-white' : 'bg-primary text-white';
        my $exp_str = ($c->{id_pac}) ? qq{<small class="text-muted d-block" style="font-size:0.75rem;">#$c->{id_pac}</small>} : '';

        print qq{
            <tr>
                <td class="fw-bold text-nowrap px-3">$c->{fecha}</td>
                <td class="text-nowrap px-2"><span class="badge bg-light text-dark border px-2 py-1">$h_disp</span></td>
                <td class="px-3">
                    <strong style="color: var(--md-blue-deep);">$c->{paciente}</strong>
                    $exp_str
                </td>
                <td class="text-muted px-2" style="max-width: 180px;">$c->{motivo}</td>
                <td class="text-secondary px-2">$c->{medico}</td>
                <td class="px-2"><span class="badge bg-light text-secondary border px-2 py-1">$c->{espacio}</span></td>
                <td class="text-center px-2">
                    <span class="badge $badge_cls px-2 py-1" style="font-size: 0.72rem;">\U$st</span>
                </td>
            </tr>
        };
    }
}

print <<HTML;
                </tbody>
            </table>
        </div>

        <!-- Pie de Página Formal y Validación -->
        <div class="footer-legal">
            <div class="row align-items-center g-3">
                <div class="col-7">
                    <p class="m-0" style="line-height: 1.45;">
                        <strong>Aviso de Confidencialidad y Secreto Médico:</strong> Este reporte contiene información clínica confidencial protegida por la legislación sanitaria vigente y la NOM-004-SSA3-2012. Queda estrictamente prohibida su divulgación o reproducción no autorizada.
                    </p>
                </div>
                <div class="col-5 text-end">
                    <div class="d-inline-block text-center border-top border-dark pt-1 px-4" style="min-width: 220px;">
                        <span class="fw-bold d-block" style="color: var(--md-blue-deep); font-size: 0.75rem;">Nombre y Firma de Autorización</span>
                        <span class="text-muted" style="font-size: 0.68rem;">Coordinación Médica / Recepción</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Script de sincronización reactiva desde sessionStorage -->
    <script>
    document.addEventListener("DOMContentLoaded", function() {
        try {
            var raw = sessionStorage.getItem("ospulso_reporte_agenda_payload");
            if (raw) {
                var p = JSON.parse(raw);
                if (p && Array.isArray(p.citas) && p.citas.length > 0) {
                    var currentRows = document.querySelectorAll("#citasTableBody tr");
                    var esVacio = currentRows.length === 0 || (currentRows.length === 1 && currentRows[0].textContent.indexOf("No se registraron") !== -1);
                    
                    if (esVacio && p.citas.length > 0) {
                        var tbody = document.getElementById("citasTableBody");
                        tbody.innerHTML = "";
                        
                        p.citas.forEach(function(a) {
                            var f = (a.start) ? a.start.split("T")[0] : (a.fecha || "$fecha");
                            var h = (a.start && a.start.indexOf("T") !== -1) ? a.start.split("T")[1].substring(0, 5) : (a.hora_ini || "");
                            var hFin = (a.end && a.end.indexOf("T") !== -1) ? a.end.split("T")[1].substring(0, 5) : (a.hora_fin || "");
                            var hDisp = hFin ? (h + " - " + hFin) : h;
                            var st = (a.extendedProps && a.extendedProps.estado) || a.estado || "Programada";
                            var pacNom = a.title || a.paciente || "Paciente";
                            var expNum = (a.extendedProps && a.extendedProps.id_paciente) ? ("#" + a.extendedProps.id_paciente) : (a.id_pac ? ("#" + a.id_pac) : "");
                            var motivo = (a.extendedProps && a.extendedProps.motivo) || a.motivo || "Consulta General";
                            var mNom = (a.extendedProps && (a.extendedProps.medico || a.extendedProps.doctor)) || a.medico || "Profesional Asignado";
                            var espNom = (a.extendedProps && (a.extendedProps.consultorio || a.extendedProps.recurso || a.extendedProps.lugar)) || a.espacio || "Consultorio 1";
                            
                            var badgeCls = "bg-primary text-white";
                            var stLow = st.toLowerCase();
                            if (stLow.indexOf("atendida") !== -1) badgeCls = "bg-success text-white";
                            else if (stLow.indexOf("espera") !== -1) badgeCls = "bg-warning text-dark";
                            else if (stLow.indexOf("proceso") !== -1 || stLow.indexOf("consulta") !== -1) badgeCls = "bg-info text-white";
                            
                            var tr = document.createElement("tr");
                            tr.innerHTML = '<td class="fw-bold text-nowrap px-3">' + f + '</td>' +
                                           '<td class="text-nowrap px-2"><span class="badge bg-light text-dark border px-2 py-1">' + hDisp + '</span></td>' +
                                           '<td class="px-3"><strong style="color: var(--md-blue-deep);">' + pacNom + '</strong>' + 
                                           (expNum ? '<small class="text-muted d-block" style="font-size:0.75rem;">' + expNum + '</small>' : '') + '</td>' +
                                           '<td class="text-muted px-2" style="max-width: 180px;">' + motivo + '</td>' +
                                           '<td class="text-secondary px-2">' + mNom + '</td>' +
                                           '<td class="px-2"><span class="badge bg-light text-secondary border px-2 py-1">' + espNom + '</span></td>' +
                                           '<td class="text-center px-2"><span class="badge ' + badgeCls + ' px-2 py-1" style="font-size: 0.72rem;">' + st.toUpperCase() + '</span></td>';
                            tbody.appendChild(tr);
                        });
                        
                        if (p.kpis) {
                            var kTotal = document.getElementById("kpiValTotal");
                            var kConf = document.getElementById("kpiValConfirmadas");
                            var kProc = document.getElementById("kpiValProceso");
                            var kAtend = document.getElementById("kpiValAtendidas");
                            if (kTotal) kTotal.textContent = p.kpis.total || p.citas.length;
                            if (kConf) kConf.textContent = p.kpis.confirmadas || 0;
                            if (kProc) kProc.textContent = p.kpis.enProceso || 0;
                            if (kAtend) kAtend.textContent = p.kpis.atendidas || 0;
                        }
                    }
                }
            }
        } catch(e) { console.warn("Sync warning", e); }
    });
    </script>
</body>
</html>
HTML
