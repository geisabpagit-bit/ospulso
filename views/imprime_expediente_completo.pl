#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON qw(decode_json encode_json);
use POSIX qw(strftime);
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session($q);
unless ($session_data->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $id_paciente = $q->param('id') || $q->param('id_paciente') || '';
my $usuario_emisor = $session_data->{usuario} || 'Personal Médico';
my $rol_emisor = $session_data->{role} || 'Médico';

binmode STDOUT, ":utf8";

# 1. Cargar Datos del Paciente (dat/pacientes.dat)
my $paciente = {};
my $res_pacientes = leer_tabla(File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat'), '\|');
foreach my $c (@$res_pacientes) {
    if ($c->[0] eq $id_paciente) {
        $paciente = {
            id_paciente => $c->[0],
            tenant      => $c->[1] // '',
            nombre      => $c->[2] // 'Paciente Sin Nombre',
            rfc         => $c->[3] // '',
            curp        => $c->[4] // 'SIN CURP',
            email       => $c->[5] // 'Sin correo registrado',
            f_nac       => $c->[6] // '',
            sexo        => $c->[7] // 'N/A',
            ocupacion   => $c->[8] // 'No especificada',
            e_civil     => $c->[9] // 'No especificado',
            tipo_sangre => $c->[11] // 'Desconocido',
            tel         => $c->[12] // 'Sin teléfono registrado'
        };
        last;
    }
}

unless ($paciente->{id_paciente}) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print qq{
        <!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Paciente No Encontrado</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet"></head>
        <body class="bg-light d-flex align-items-center justify-content-center vh-100">
            <div class="text-center p-5 bg-white border rounded shadow-sm" style="max-width: 480px;">
                <h2 class="text-danger fw-bold mb-3">Paciente No Encontrado</h2>
                <p class="text-muted">El expediente solicitado (ID: $id_paciente) no existe en la base de datos o fue removido.</p>
                <button class="btn btn-outline-primary mt-3" onclick="window.close()">Cerrar Ventana</button>
            </div>
        </body></html>
    };
    exit;
}

# Calcular edad
my $edad_txt = 'Edad no registrada';
if ($paciente->{f_nac} =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
    my ($ano, $mes, $dia) = ($1, $2, $3);
    my ($cur_sec,$cur_min,$cur_hour,$cur_mday,$cur_mon,$cur_year) = localtime();
    my $cur_ano = $cur_year + 1900;
    my $cur_mes = $cur_mon + 1;
    my $edad = $cur_ano - $ano;
    if ($cur_mes < $mes || ($cur_mes == $mes && $cur_mday < $dia)) {
        $edad--;
    }
    $edad_txt = "$edad años";
} elsif ($paciente->{f_nac} =~ /^(\d{2})\/(\d{2})\/(\d{4})$/) {
    my ($dia, $mes, $ano) = ($1, $2, $3);
    my ($cur_sec,$cur_min,$cur_hour,$cur_mday,$cur_mon,$cur_year) = localtime();
    my $cur_ano = $cur_year + 1900;
    my $cur_mes = $cur_mon + 1;
    my $edad = $cur_ano - $ano;
    if ($cur_mes < $mes || ($cur_mes == $mes && $cur_mday < $dia)) {
        $edad--;
    }
    $edad_txt = "$edad años";
}

# 1.1 Cargar Domicilio Habitual del Paciente (Prioridad: dat/pacientes_domicilio.dat -> JSON en antecedentes)
my $domicilio_paciente = 'No registrado';
my $dom_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes_domicilio.dat');
if (-e $dom_file && open(my $fhd, '<:encoding(UTF-8)', $dom_file)) {
    while (my $dline = <$fhd>) {
        chomp $dline;
        next if $dline =~ /^\s*$/ || $dline =~ /^ID_PACIENTE/i;
        my @dv = split /\|/, $dline, -1;
        if ($dv[0] eq $id_paciente) {
            my @partes;
            push @partes, "Calle $dv[1]" if defined $dv[1] && $dv[1] ne '';
            push @partes, "No. Ext. $dv[2]" if defined $dv[2] && $dv[2] ne '';
            push @partes, "Int. $dv[3]" if defined $dv[3] && $dv[3] ne '';
            push @partes, "Col. $dv[4]" if defined $dv[4] && $dv[4] ne '';
            push @partes, $dv[5] if defined $dv[5] && $dv[5] ne '';
            push @partes, $dv[6] if defined $dv[6] && $dv[6] ne '';
            push @partes, "C.P. $dv[7]" if defined $dv[7] && $dv[7] ne '';
            $domicilio_paciente = join(', ', @partes) if @partes;
            last;
        }
    }
    close $fhd;
}

if ($domicilio_paciente eq 'No registrado') {
    my $ant_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes_antecedentes.dat');
    if (-e $ant_path && open(my $fha, '<:encoding(UTF-8)', $ant_path)) {
        <$fha>;
        while (my $la = <$fha>) {
            chomp $la;
            next if $la =~ /^\s*$/;
            my @av = split /\|/, $la, -1;
            if ($av[0] eq $id_paciente && $av[2]) {
                my $ant_obj = {};
                eval { $ant_obj = decode_json($av[2]); };
                if (!%$ant_obj) {
                    eval { $ant_obj = decode_json(encode_utf8($av[2])); };
                }
                
                my $d_obj = ($ant_obj->{domicilio} && ref($ant_obj->{domicilio}) eq 'HASH') 
                          ? $ant_obj->{domicilio} 
                          : $ant_obj;
                          
                my @partes;
                push @partes, "Calle " . $d_obj->{calle} if $d_obj->{calle};
                push @partes, "No. " . $d_obj->{num_ext} if $d_obj->{num_ext};
                push @partes, "Int. " . $d_obj->{num_int} if $d_obj->{num_int};
                push @partes, "Col. " . $d_obj->{colonia} if $d_obj->{colonia};
                push @partes, $d_obj->{municipio} if $d_obj->{municipio};
                push @partes, $d_obj->{entidad} if $d_obj->{entidad};
                push @partes, "C.P. " . $d_obj->{cp} if $d_obj->{cp};
                
                $domicilio_paciente = join(', ', @partes) if @partes;
                last;
            }
        }
        close $fha;
    }
}

# 2. Cargar Datos de la Sucursal / Organización (dat/negocios.dat y dat/negocios_config.dat)
my $id_negocio_activo = ($session_data->{id_sucursal} && $session_data->{id_sucursal} ne '0') 
                      ? $session_data->{id_sucursal} 
                      : ($session_data->{id_empresa} // '0');

my $tipo_org_cfg = '';
my $cfg_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $cfg_file && open(my $fhc, '<:encoding(UTF-8)', $cfg_file)) {
    while (my $lc = <$fhc>) {
        chomp $lc;
        next if $lc =~ /^\s*$/ || $lc =~ /^#/;
        my @c = split /\|/, $lc, -1;
        if ($c[0] eq $id_negocio_activo && $c[1] eq 'TIPO_ORGANIZACION') {
            $tipo_org_cfg = $c[2] // '';
            last;
        }
    }
    close $fhc;
}

my $org = {
    nombre            => 'Consultorio Médico',
    razon_social      => '',
    rfc               => '',
    domicilio         => 'Dirección no registrada',
    telefono          => '',
    email             => '',
    tipo_organizacion => 'Consultorio Individual',
    clues             => ''
};

my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fhn, '<:encoding(UTF-8)', $negocios_file)) {
    <$fhn>;
    while (my $line = <$fhn>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @f = split /\|/, $line, -1;
        # 0:ID, 1:NOMBRE, 2:ID_MATRIZ, 3:Activo, 4:ini, 5:fin, 6:domicilio, 7:tel, 8:email, 9:logo, 10:rfc, 11:razon, 14:cp, 15:entidad, 16:municipio, 17:colonia, 18:clues
        if ($f[0] eq $id_negocio_activo || ($id_negocio_activo eq '0' && ($f[0] eq '0' || $f[0] eq 'ORG-000'))) {
            $org->{nombre}       = $f[1] if defined $f[1] && $f[1] ne '';
            $org->{telefono}     = $f[7] if defined $f[7] && $f[7] ne '';
            $org->{email}        = $f[8] if defined $f[8] && $f[8] ne '';
            $org->{rfc}          = $f[10] if defined $f[10] && $f[10] ne '' && $f[10] ne '1';
            $org->{razon_social} = $f[11] if defined $f[11] && $f[11] ne '';
            $org->{clues}        = $f[18] if defined $f[18] && $f[18] ne '' && $f[18] ne '0';
            
            my @partes_dom;
            push @partes_dom, $f[6] if defined $f[6] && $f[6] ne '';
            push @partes_dom, "Col. $f[17]" if defined $f[17] && $f[17] ne '';
            push @partes_dom, $f[16] if defined $f[16] && $f[16] ne '';
            push @partes_dom, $f[15] if defined $f[15] && $f[15] ne '';
            push @partes_dom, "C.P. $f[14]" if defined $f[14] && $f[14] ne '';
            $org->{domicilio} = join(', ', @partes_dom) if @partes_dom;
            last;
        }
    }
    close $fhn;
}

$org->{tipo_organizacion} = $tipo_org_cfg || ($org->{clues} ? 'Clínica Privada' : 'Consultorio Individual');
if ($org->{nombre} =~ /dental/i) {
    $org->{tipo_organizacion} = 'Consultorio Odontológico / Dental';
} elsif ($org->{nombre} =~ /consultorio/i) {
    $org->{tipo_organizacion} = 'Consultorio Médico Individual';
}

# 3. Cargar Catálogos de Usuarios (Médicos) y Especialidades
my %usuarios_map;
my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
if (-e $usr_file && open(my $fhu, '<:encoding(UTF-8)', $usr_file)) {
    while (my $lu = <$fhu>) {
        chomp $lu;
        next if $lu =~ /^\s*$/;
        my @u = split /!/, $lu, -1;
        # u[0]=id, u[1]=nombre, u[5]=rol, u[7]=id_esp, u[9]=cedula
        $usuarios_map{$u[0]} = {
            id        => $u[0],
            nombre    => $u[1] // 'Dr(a). Médico Tratante',
            rol       => $u[5] // 'Medico',
            id_esp    => $u[7] // '',
            cedula    => $u[9] // ''
        };
        $usuarios_map{"DOC-" . sprintf("%03d", $u[0])} = $usuarios_map{$u[0]};
        $usuarios_map{"DOC-" . $u[0]} = $usuarios_map{$u[0]};
    }
    close $fhu;
}

my %especialidades_map;
my $esp_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'especialidades.dat');
if (-e $esp_file && open(my $fhe, '<:encoding(UTF-8)', $esp_file)) {
    <$fhe>;
    while (my $le = <$fhe>) {
        chomp $le;
        next if $le =~ /^\s*$/;
        my @e = split /\|/, $le, -1;
        $especialidades_map{$e[0]} = $e[1] if $e[0];
    }
    close $fhe;
}

# 4. Cargar Citas para vincular fecha y horario
my %citas_map;
my $citas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
if (-e $citas_file && open(my $fhc, '<:encoding(UTF-8)', $citas_file)) {
    <$fhc>;
    while (my $lc = <$fhc>) {
        chomp $lc;
        next if $lc =~ /^\s*$/;
        my @c = split /\|/, $lc, -1;
        $citas_map{$c[0]} = {
            id_cita => $c[0],
            fecha   => $c[3] // '',
            hora    => $c[4] // '',
            motivo  => $c[6] // ''
        };
    }
    close $fhc;
}

# 5. Cargar Historial de Consultas Médicas
my @consultas;
my $cons_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
if (-e $cons_file && open(my $fh_cons, '<:encoding(UTF-8)', $cons_file)) {
    my $header = <$fh_cons>;
    while (my $l = <$fh_cons>) {
        chomp $l;
        next if $l =~ /^\s*$/;
        my @c = split /\|/, $l, -1;
        if ($c[1] eq $id_paciente) {
            my $json_str = $c[5];
            $json_str =~ s/\\n/\n/g if defined $json_str;
            my $data = {};
            eval { $data = decode_json($json_str); };
            
            my ($f_orden, $h_orden);
            if ($c[2] && exists $citas_map{$c[2]} && $citas_map{$c[2]}->{fecha}) {
                $f_orden = $citas_map{$c[2]}->{fecha};
                $h_orden = $citas_map{$c[2]}->{hora} || '00:00';
            } else {
                my ($sec,$min,$hour,$mday,$mon,$year) = localtime($c[4] || time());
                $f_orden = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
                $h_orden = sprintf("%02d:%02d", $hour, $min);
            }
            
            my $fecha_fmt = "$f_orden $h_orden";
            if ($f_orden =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
                $fecha_fmt = "$3/$2/$1 $h_orden hrs";
            }
            
            # Resolver médico y especialidad
            my $id_med = $c[3] || ($data->{id_medico} // '');
            my $med_info = $usuarios_map{$id_med} || { nombre => 'Dr(a). Médico Tratante', cedula => '', id_esp => '' };
            my $med_esp = 'Medicina General';
            if ($med_info->{id_esp} && exists $especialidades_map{$med_info->{id_esp}}) {
                $med_esp = $especialidades_map{$med_info->{id_esp}};
            } elsif ($data->{especialidad_nombre}) {
                $med_esp = $data->{especialidad_nombre};
            }

            push @consultas, {
                id_consulta => $c[0],
                id_cita     => $c[2] // '',
                id_medico   => $id_med,
                med_nombre  => $med_info->{nombre},
                med_cedula  => $med_info->{cedula},
                med_esp     => $med_esp,
                timestamp   => $c[4] || 0,
                fecha_orden => $f_orden,
                hora_orden  => $h_orden,
                fecha_fmt   => $fecha_fmt,
                data        => $data
            };
        }
    }
    close $fh_cons;
}

# ORDENAR DE LA CITA MÁS RECIENTE A LA MÁS ANTIGUA (FECHA Y HORA DESCENDENTE)
@consultas = sort {
    ($b->{fecha_orden} cmp $a->{fecha_orden}) ||
    ($b->{hora_orden} cmp $a->{hora_orden}) ||
    ($b->{timestamp} <=> $a->{timestamp})
} @consultas;

# Métricas del Historial
my $total_consultas = scalar @consultas;
my $primera_consulta = 'Ninguna';
my $ultima_consulta  = 'Ninguna';
if ($total_consultas > 0) {
    $primera_consulta = $consultas[-1]->{fecha_fmt};
    $ultima_consulta  = $consultas[0]->{fecha_fmt};
}

# Diagnóstico reciente robusto
my $diag_reciente = 'Valoración médica general / Sin patología activa';
if ($total_consultas > 0) {
    foreach my $chk_cons (@consultas) {
        my $d_chk = $chk_cons->{data} || {};
        my $cand_diag = $d_chk->{diagnostico_principal} 
                     || $d_chk->{diagnostico}
                     || ($d_chk->{soap} && ref($d_chk->{soap}) eq 'HASH' ? ($d_chk->{soap}->{assessment} || $d_chk->{soap}->{diagnostico_principal} || $d_chk->{soap}->{diagnostico}) : undef)
                     || $d_chk->{soap_assessment}
                     || $d_chk->{impresion_clinica};
        if ($cand_diag && $cand_diag ne '' && $cand_diag !~ /^Sin diagn/i) {
            $diag_reciente = $cand_diag;
            my $cand_cie = $d_chk->{clave_diagnostico_cie10} 
                        || ($d_chk->{soap} && ref($d_chk->{soap}) eq 'HASH' ? $d_chk->{soap}->{clave_diagnostico_cie10} : '');
            if ($cand_cie) {
                $diag_reciente .= " (CIE-10: $cand_cie)";
            }
            last;
        } elsif ($d_chk->{motivo} && $diag_reciente =~ /^Valoración médica/i) {
            $diag_reciente = $d_chk->{motivo};
        }
    }
}

my $fecha_reporte = strftime("%d/%m/%Y %H:%M", localtime);
my $folio_reporte = "REP-CONS-$id_paciente-" . time();

print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Consultas - $paciente->{nombre}</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght\@400;600;700;800&family=Plus+Jakarta+Sans:wght\@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css">

    <style>
        \@page {
            size: letter portrait;
            margin: 12mm 14mm 14mm 14mm;
        }
        * { box-sizing: border-box; }
        body {
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f1f5f9;
            color: #0f172a;
            margin: 0;
            padding: 20px;
            font-size: 11px;
            line-height: 1.45;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }

        /* Barra de Acciones Superior (No Imprimible) */
        .no-print-bar {
            max-width: 8.5in;
            margin: 0 auto 20px auto;
            padding: 12px 20px;
            background: #0A2A66;
            color: white;
            border-radius: 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            box-shadow: 0 4px 14px rgba(10, 42, 102, 0.2);
        }
        .btn-action {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 8px 16px;
            border-radius: 8px;
            font-weight: 700;
            font-size: 12px;
            cursor: pointer;
            border: none;
            transition: all 0.2s;
            text-decoration: none;
        }
        .btn-print { background: #19B7A5; color: white; }
        .btn-print:hover { background: #139687; }
        .btn-back { background: rgba(255,255,255,0.18); color: white; border: 1px solid rgba(255,255,255,0.3); }
        .btn-back:hover { background: rgba(255,255,255,0.28); }

        /* Contenedor Hoja Carta Vertical */
        .sheet-container {
            width: 100%;
            max-width: 8.5in;
            min-height: 11in;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 12px;
            padding: 30px 36px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.06);
            border: 1px solid #e2e8f0;
        }

        /* Encabezado Institucional */
        .org-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            border-bottom: 2.5px solid #0A2A66;
            padding-bottom: 14px;
            margin-bottom: 16px;
        }
        .org-title {
            font-family: 'Outfit', sans-serif;
            font-size: 1.35rem;
            font-weight: 800;
            color: #0A2A66;
            margin: 0 0 3px 0;
            line-height: 1.2;
        }
        .org-subtitle {
            font-size: 0.82rem;
            font-weight: 700;
            color: #0f766e;
            margin: 0 0 4px 0;
        }
        .org-details {
            font-size: 0.74rem;
            color: #475569;
            margin: 0 0 2px 0;
            line-height: 1.35;
        }
        .meta-box {
            text-align: right;
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 10px 14px;
            min-width: 220px;
        }
        .meta-folio {
            font-family: 'Outfit', sans-serif;
            font-size: 0.85rem;
            font-weight: 800;
            color: #0A2A66;
            margin-bottom: 3px;
        }
        .meta-date {
            font-size: 0.73rem;
            color: #64748b;
            font-weight: 600;
            line-height: 1.35;
        }

        /* Título del Documento */
        .doc-title-banner {
            background: linear-gradient(135deg, #0A2A66 0%, #113a8a 100%);
            color: #ffffff;
            padding: 8px 14px;
            border-radius: 8px;
            text-align: center;
            font-family: 'Outfit', sans-serif;
            font-weight: 800;
            font-size: 0.95rem;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            margin-bottom: 14px;
        }

        /* Ficha del Paciente */
        .patient-card {
            border: 1px solid #cbd5e1;
            border-radius: 10px;
            background: #f8fafc;
            padding: 12px 16px;
            margin-bottom: 14px;
        }
        .patient-name-container {
            display: flex;
            align-items: center;
            margin-bottom: 8px;
            border-bottom: 1px dashed #cbd5e1;
            padding-bottom: 6px;
        }
        .patient-name {
            font-family: 'Outfit', sans-serif;
            font-size: 1.15rem;
            font-weight: 800;
            color: #0A2A66;
            margin: 0;
            line-height: 1.2;
        }
        .patient-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 6px 12px;
            font-size: 0.74rem;
        }
        .patient-item span.label {
            color: #64748b;
            font-weight: 600;
            display: block;
            text-transform: uppercase;
            font-size: 0.65rem;
            letter-spacing: 0.3px;
        }
        .patient-item span.value {
            font-weight: 700;
            color: #1e293b;
        }

        /* Resumen de Métricas */
        .kpi-row {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 10px;
            margin-bottom: 18px;
        }
        .kpi-card {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-left: 3.5px solid #0f766e;
            border-radius: 8px;
            padding: 8px 12px;
        }
        .kpi-card-title {
            font-size: 0.66rem;
            color: #64748b;
            text-transform: uppercase;
            font-weight: 700;
            margin-bottom: 2px;
        }
        .kpi-card-val {
            font-size: 0.88rem;
            font-weight: 800;
            color: #0A2A66;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        /* Sección de Historial de Consultas */
        .section-header {
            font-family: 'Outfit', sans-serif;
            font-size: 0.92rem;
            font-weight: 800;
            color: #0A2A66;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1.5px solid #e2e8f0;
            padding-bottom: 6px;
            margin-bottom: 12px;
        }

        /* Tarjeta de Cada Consulta */
        .consulta-card {
            border: 1px solid #cbd5e1;
            border-radius: 10px;
            background: #ffffff;
            margin-bottom: 12px;
            overflow: hidden;
            page-break-inside: avoid;
            break-inside: avoid;
        }
        .consulta-header {
            background: #f1f5f9;
            border-bottom: 1px solid #e2e8f0;
            padding: 8px 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .consulta-date {
            font-family: 'Outfit', sans-serif;
            font-weight: 800;
            font-size: 0.88rem;
            color: #0A2A66;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        .consulta-doctor {
            font-size: 0.74rem;
            font-weight: 700;
            color: #0f766e;
            text-align: right;
        }
        .consulta-body {
            padding: 10px 14px;
        }
        .detail-row {
            margin-bottom: 7px;
        }
        .detail-row:last-child {
            margin-bottom: 0;
        }
        .detail-label {
            font-weight: 700;
            color: #334155;
            font-size: 0.73rem;
            margin-bottom: 2px;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .detail-text {
            color: #1e293b;
            font-size: 0.74rem;
            line-height: 1.35;
        }

        /* Pastillas de Signos Vitales */
        .vitals-grid {
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
            margin: 6px 0 8px 0;
        }
        .vital-badge {
            background: #f8fafc;
            border: 1px solid #cbd5e1;
            border-radius: 6px;
            padding: 3px 8px;
            font-size: 0.7rem;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .vital-badge strong {
            color: #0A2A66;
        }

        /* Tabla de Medicamentos en Reporte */
        .meds-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 5px;
            font-size: 0.71rem;
        }
        .meds-table th {
            background: #e2e8f0;
            color: #334155;
            font-weight: 700;
            padding: 4px 8px;
            border: 1px solid #cbd5e1;
            text-align: left;
        }
        .meds-table td {
            padding: 4px 8px;
            border: 1px solid #cbd5e1;
            color: #1e293b;
        }

        /* Firmas de Validación */
        .signature-section {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 40px;
            margin-top: 35px;
            padding-top: 10px;
            page-break-inside: avoid;
            break-inside: avoid;
        }
        .signature-box {
            text-align: center;
        }
        .signature-line {
            border-top: 1.2px solid #0f172a;
            width: 75%;
            margin: 45px auto 4px auto;
        }
        .signature-title {
            font-size: 0.75rem;
            font-weight: 700;
            color: #0A2A66;
            margin: 0;
        }
        .signature-sub {
            font-size: 0.68rem;
            color: #64748b;
            margin: 2px 0 0 0;
        }

        /* Pie de Página Normativo */
        .report-footer {
            border-top: 1px solid #cbd5e1;
            margin-top: 25px;
            padding-top: 10px;
            font-size: 0.66rem;
            color: #64748b;
            text-align: center;
            line-height: 1.35;
            page-break-inside: avoid;
            break-inside: avoid;
        }

        /* Estilos de Impresión */
        \@media print {
            body {
                background: #ffffff !important;
                padding: 0 !important;
                margin: 0 !important;
            }
            .no-print-bar {
                display: none !important;
            }
            .sheet-container {
                box-shadow: none !important;
                border: none !important;
                border-radius: 0 !important;
                padding: 0 !important;
                max-width: 100% !important;
                width: 100% !important;
            }
        }
    </style>
</head>
<body>

    <!-- Barra de Acciones Superior (No Imprimible) -->
    <div class="no-print-bar">
        <div style="display: flex; align-items: center; gap: 10px;">
            <i class="bi bi-file-earmark-medical-fill fs-5" style="color: #19B7A5;"></i>
            <span style="font-weight: 700; font-size: 13px;">Reporte Clínico de Consultas</span>
            <span style="background: rgba(255,255,255,0.18); padding: 3px 8px; border-radius: 12px; font-size: 10px;">Hoja Carta Vertical</span>
        </div>
        <div style="display: flex; gap: 8px;">
            <button class="btn-action btn-print" onclick="window.print()">
                <i class="bi bi-printer-fill"></i> Imprimir Reporte
            </button>
            <button class="btn-action btn-back" onclick="cerrarORegresar()">
                <i class="bi bi-arrow-left-circle-fill"></i> Regresar / Cerrar
            </button>
        </div>
    </div>

    <!-- Contenedor Hoja Carta Vertical -->
    <div class="sheet-container">

        <!-- 1. Encabezado Institucional -->
        <header class="org-header">
            <div>
                <h1 class="org-title">$org->{nombre}</h1>
                <div class="org-subtitle">$org->{tipo_organizacion} @{[$org->{clues} ? "| CLUES: $org->{clues}" : ""]}</div>
                <p class="org-details">
                    @{[$org->{razon_social} && $org->{razon_social} ne $org->{nombre} ? "$org->{razon_social} &bull; " : ""]}
                    @{[$org->{rfc} ? "RFC: $org->{rfc} &bull; " : ""]}
                    $org->{domicilio}
                </p>
                @{[$org->{telefono} || $org->{email} ? qq{<p class="org-details">@{[$org->{telefono} ? "Tel. $org->{telefono}" : ""]}@{[$org->{telefono} && $org->{email} ? " &bull; " : ""]}@{[$org->{email} ? "Correo: $org->{email}" : ""]}</p>} : ""]}
            </div>
            <div class="meta-box">
                <div class="meta-folio">$folio_reporte</div>
                <div class="meta-date"><i class="bi bi-clock-history me-1"></i>Emisión: $fecha_reporte hrs</div>
                <div class="meta-date"><i class="bi bi-person-check me-1"></i>Por: $usuario_emisor ($rol_emisor)</div>
            </div>
        </header>

        <!-- 2. Banner de Título de Reporte -->
        <div class="doc-title-banner">
            <i class="bi bi-journal-medical me-2"></i>Historial de Consultas y Atenciones Médicas
        </div>

        <!-- 3. Ficha Resumen del Paciente -->
        <section class="patient-card">
            <div class="patient-name-container">
                <span class="badge bg-primary bg-opacity-10 text-primary border me-2" style="font-size: 0.72rem; padding: 4px 8px; font-weight: 700;">
                    <i class="bi bi-person-vcard-fill me-1"></i>PACIENTE
                </span>
                <span class="patient-name">$paciente->{nombre}</span>
                <span style="font-size: 0.72rem; color: #64748b; font-weight: 600; margin-left: 8px;">(Expediente: EXP-$paciente->{id_paciente})</span>
            </div>
            <div class="patient-grid">
                <div class="patient-item">
                    <span class="label">CURP</span>
                    <span class="value">$paciente->{curp}</span>
                </div>
                <div class="patient-item">
                    <span class="label">Edad / F. Nac.</span>
                    <span class="value">$edad_txt ($paciente->{f_nac})</span>
                </div>
                <div class="patient-item">
                    <span class="label">Sexo / Estado Civil</span>
                    <span class="value">$paciente->{sexo} / $paciente->{e_civil}</span>
                </div>
                <div class="patient-item">
                    <span class="label">Grupo Sanguíneo</span>
                    <span class="value" style="color: #dc2626;">$paciente->{tipo_sangre}</span>
                </div>
                <div class="patient-item">
                    <span class="label">Teléfono de Contacto</span>
                    <span class="value">$paciente->{tel}</span>
                </div>
                <div class="patient-item">
                    <span class="label">Correo Electrónico</span>
                    <span class="value">$paciente->{email}</span>
                </div>
                <div class="patient-item" style="grid-column: span 2;">
                    <span class="label">Domicilio Habitual</span>
                    <span class="value">$domicilio_paciente</span>
                </div>
            </div>
        </section>

        <!-- 4. Resumen Estadístico del Expediente -->
        <div class="kpi-row">
            <div class="kpi-card">
                <div class="kpi-card-title">Consultas Totales</div>
                <div class="kpi-card-val">$total_consultas atención(es)</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-card-title">Primera Consulta</div>
                <div class="kpi-card-val">$primera_consulta</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-card-title">Última Atención</div>
                <div class="kpi-card-val">$ultima_consulta</div>
            </div>
            <div class="kpi-card">
                <div class="kpi-card-title">Diagnóstico Principal Reciente</div>
                <div class="kpi-card-val" title="$diag_reciente">$diag_reciente</div>
            </div>
        </div>

        <!-- 5. Listado Cronológico de Consultas -->
        <div class="section-header">
            <span><i class="bi bi-clock-history me-1" style="color: #0f766e;"></i>Registro Detallado de Atenciones (Cronológico Inverso)</span>
            <span style="font-size: 0.72rem; color: #64748b; font-weight: 600;">$total_consultas registro(s)</span>
        </div>
HTML

if (@consultas) {
    foreach my $c (@consultas) {
        my $cd = $c->{data} || {};
        my $motivo = $cd->{motivo} || 'Consulta médica general / valoración';
        my $evolucion = $cd->{evolucion} || '';
        
        my $diag_p = $cd->{diagnostico_principal} 
                  || $cd->{diagnostico} 
                  || ($cd->{soap} && ref($cd->{soap}) eq 'HASH' ? ($cd->{soap}->{assessment} || $cd->{soap}->{diagnostico_principal} || $cd->{soap}->{diagnostico}) : undef)
                  || $cd->{soap_assessment}
                  || $cd->{impresion_clinica}
                  || $cd->{motivo}
                  || 'Atención y valoración médica general';
                  
        my $cie10 = $cd->{clave_diagnostico_cie10} 
                 || ($cd->{soap} && ref($cd->{soap}) eq 'HASH' ? $cd->{soap}->{clave_diagnostico_cie10} : '')
                 || '';
                 
        my $diag_sec = $cd->{diagnosticos_secundarios} || '';
        my $plan = $cd->{plan_tratamiento} || $cd->{plan} || 'Continuar con las indicaciones médicas y medidas generales.';

        # Badges de Signos Vitales
        my @vitals_badges;
        push @vitals_badges, qq{<span class="vital-badge">TA: <strong>$cd->{ta}</strong> mmHg</span>} if $cd->{ta};
        push @vitals_badges, qq{<span class="vital-badge">FC: <strong>$cd->{fc}</strong> lpm</span>} if $cd->{fc};
        push @vitals_badges, qq{<span class="vital-badge">FR: <strong>$cd->{fr}</strong> rpm</span>} if $cd->{fr};
        push @vitals_badges, qq{<span class="vital-badge">Temp: <strong>$cd->{temp}</strong> &deg;C</span>} if $cd->{temp};
        push @vitals_badges, qq{<span class="vital-badge">SpO2: <strong>$cd->{spo2}</strong> %</span>} if $cd->{spo2};
        push @vitals_badges, qq{<span class="vital-badge">Peso: <strong>$cd->{peso}</strong> kg</span>} if $cd->{peso};
        push @vitals_badges, qq{<span class="vital-badge">Talla: <strong>$cd->{talla}</strong> m</span>} if $cd->{talla};
        push @vitals_badges, qq{<span class="vital-badge">Glucosa: <strong>$cd->{glucosa}</strong> mg/dL</span>} if $cd->{glucosa};
        
        my $vitals_html = '';
        if (@vitals_badges) {
            $vitals_html = qq{<div class="vitals-grid">} . join('', @vitals_badges) . qq{</div>};
        }

        # Medicamentos
        my $meds_html = '';
        if ($cd->{medicamentos} && ref($cd->{medicamentos}) eq 'ARRAY' && @{$cd->{medicamentos}}) {
            my $rows_meds = '';
            foreach my $m (@{$cd->{medicamentos}}) {
                my $nom = $m->{farmaco} || $m->{medicamento} || 'Fármaco';
                my $pres = $m->{presentacion} || '--';
                my $dos = $m->{dosis} || '--';
                my $frec = $m->{frecuencia} || '--';
                my $dur = $m->{duracion} || '--';
                my $via = $m->{via} || 'Oral';
                $rows_meds .= qq{
                    <tr>
                        <td style="font-weight: 700;">$nom</td>
                        <td>$pres</td>
                        <td>$dos</td>
                        <td>$frec</td>
                        <td>$dur</td>
                        <td>$via</td>
                    </tr>
                };
            }
            $meds_html = qq{
                <div style="margin-top: 6px;">
                    <span class="detail-label"><i class="bi bi-capsule me-1 text-primary"></i>Fármacos y Prescripción Médica:</span>
                    <table class="meds-table">
                        <thead>
                            <tr>
                                <th>Medicamento</th>
                                <th>Presentación</th>
                                <th>Dosis</th>
                                <th>Frecuencia</th>
                                <th>Duración</th>
                                <th>Vía</th>
                            </tr>
                        </thead>
                        <tbody>
                            $rows_meds
                        </tbody>
                    </table>
                </div>
            };
        }

        my $folio_tag = $c->{id_cita} ? qq{<span style="font-size: 0.7rem; color: #64748b; font-weight: 600; margin-left: 6px;">(Cita: #$c->{id_cita})</span>} : "";
        my $cedula_tag = $c->{med_cedula} ? " &bull; Céd. Prof. $c->{med_cedula}" : "";

        print <<CONSULTA_HTML;
        <div class="consulta-card">
            <div class="consulta-header">
                <div class="consulta-date">
                    <i class="bi bi-calendar2-check-fill text-teal" style="color: #0f766e;"></i>
                    $c->{fecha_fmt} $folio_tag
                </div>
                <div class="consulta-doctor">
                    $c->{med_nombre} ($c->{med_esp}$cedula_tag)
                </div>
            </div>
            <div class="consulta-body">
                <div class="detail-row">
                    <span class="detail-label"><i class="bi bi-chat-left-dots-fill text-secondary"></i>Motivo de Consulta:</span>
                    <div class="detail-text">$motivo</div>
                </div>
                @{[$evolucion ? qq{
                <div class="detail-row">
                    <span class="detail-label"><i class="bi bi-activity text-secondary"></i>Padecimiento Actual:</span>
                    <div class="detail-text">$evolucion</div>
                </div>} : ""]}
                $vitals_html
                <div class="detail-row" style="background: #f8fafc; padding: 6px 10px; border-radius: 6px; border-left: 3px solid #0A2A66;">
                    <span class="detail-label" style="color: #0A2A66;"><i class="bi bi-clipboard2-pulse-fill me-1"></i>Diagnóstico:</span>
                    <div class="detail-text fw-bold" style="color: #0A2A66;">
                        $diag_p @{[$cie10 ? qq{<span class="badge bg-light text-dark border ms-1">CIE-10: $cie10</span>} : ""]}
                    </div>
                    @{[$diag_sec ? qq{<div class="detail-text text-muted small mt-1"><strong>Dx Secundarios:</strong> $diag_sec</div>} : ""]}
                </div>
                <div class="detail-row mt-2">
                    <span class="detail-label"><i class="bi bi-check2-circle text-teal" style="color: #0f766e;"></i>Plan y Manejo Terapéutico:</span>
                    <div class="detail-text">$plan</div>
                </div>
                $meds_html
            </div>
        </div>
CONSULTA_HTML
    }
} else {
    print <<NO_CONSULTAS;
    <div style="border: 2px dashed #cbd5e1; border-radius: 12px; padding: 40px; text-align: center; background: #f8fafc; margin: 20px 0;">
        <i class="bi bi-folder2-open display-6 text-muted mb-2 d-block"></i>
        <h4 style="font-family: 'Outfit', sans-serif; font-weight: 700; color: #475569; margin-bottom: 4px;">Sin Consultas Médicas Registradas</h4>
        <p style="color: #64748b; font-size: 0.8rem; margin: 0;">El paciente aún no cuenta con historial de consultas o atenciones médicas finalizadas en el expediente clínico.</p>
    </div>
NO_CONSULTAS
}

print <<HTML;
        <!-- 6. Sección de Firmas y Validación Médica -->
        <section class="signature-section">
            <div class="signature-box">
                <div class="signature-line"></div>
                <p class="signature-title">Firma del Médico Responsable</p>
                <p class="signature-sub">$usuario_emisor &bull; $rol_emisor</p>
                <p class="signature-sub">Cédula Profesional y Sello Institucional</p>
            </div>
            <div class="signature-box">
                <div class="signature-line"></div>
                <p class="signature-title">Firma de Conformidad del Paciente</p>
                <p class="signature-sub">$paciente->{nombre}</p>
                <p class="signature-sub">Paciente / Tutor / Familiar Responsable</p>
            </div>
        </section>

        <!-- 7. Pie de Página Normativo -->
        <footer class="report-footer">
            <p style="margin: 0 0 3px 0;">
                Documento clínico oficial emitido bajo los estándares de la <strong>Norma Oficial Mexicana NOM-004-SSA3-2012</strong>, del expediente clínico.
            </p>
            <p style="margin: 0 0 3px 0;">
                <strong>Aviso de Privacidad y Confidencialidad:</strong> La información contenida en este reporte es confidencial y para uso exclusivo del paciente y profesionales de la salud autorizados.
            </p>
            <p style="margin: 0; font-weight: 600;">
                Sistema OsPulso Health Cloud &bull; Expediente Electrónico Unificado &bull; $folio_reporte
            </p>
        </footer>

    </div>

    <script>
        function cerrarORegresar() {
            if (window.opener && !window.opener.closed) {
                window.close();
            } else if (window.history.length > 1) {
                window.history.back();
            } else {
                window.close();
            }
        }
    </script>
</body>
</html>
HTML

1;
