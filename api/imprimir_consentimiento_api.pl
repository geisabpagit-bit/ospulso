#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON qw(decode_json);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session($q);

print $q->header(-type => 'text/html', -charset => 'UTF-8');

unless ($session_data->{session_ok}) {
    print "<h1>Acceso no autorizado</h1>";
    exit;
}

my $id_consentimiento = $q->param('id_consentimiento') || '';
my $id_consulta       = $q->param('id_consulta') || '';

my $cons_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consentimientos.dat');
my $cons_row;

if (-e $cons_file && open(my $fh, '<:encoding(UTF-8)', $cons_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        if (($id_consentimiento && $c[0] eq $id_consentimiento) || ($id_consulta && $c[1] eq $id_consulta)) {
            $cons_row = \@c;
            last;
        }
    }
    close($fh);
}

my $fecha         = $cons_row ? ($cons_row->[4] // '2026-07-27') : '2026-07-27';
my $procedimiento = $cons_row ? ($cons_row->[5] // 'Procedimiento Médico Quirúrgico / Evaluativo') : 'Procedimiento Médico General';
my $id_paciente   = $cons_row ? $cons_row->[2] : ($q->param('id_paciente') || '2');
my $id_medico     = $cons_row ? $cons_row->[3] : ($session_data->{id_medico} || '1088603479');

# Datos Paciente
my $paciente_name = "Paciente Oficial";
my $pac_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $pacientes = leer_tabla($pac_file, '\|');
if ($pacientes) {
    foreach my $p (@$pacientes) {
        if ($p->[0] eq $id_paciente) {
            $paciente_name = $p->[2] // $paciente_name;
            last;
        }
    }
}

# Datos Médico
my $medico_name = $session_data->{usuario} || "Dr. Médico Especialista";
my $medico_cedula = "12345678";
my $institucion_name = "Clínica Principal - OsPulso Salud";

my $usr_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $usr_data = leer_tabla($usr_file, '!');
if ($usr_data) {
    foreach my $u (@$usr_data) {
        if ($u->[0] eq $id_medico || lc($u->[2]//'') eq lc($medico_name)) {
            $medico_name   = $u->[1] // $medico_name;
            $medico_cedula = $u->[9] // '12345678';
            last;
        }
    }
}

# Parsear Payload JSON de Consentimiento
my $c_data = {};
my $firma_pac_url = '';
my $firma_med_url = '';

if ($cons_row && $cons_row->[6]) {
    eval {
        my $json_raw = $cons_row->[6];
        $json_raw =~ s/\\n/\n/g;
        $c_data = decode_json($json_raw);
        
        $firma_pac_url = $c_data->{firma_paciente_data} || '';
        $firma_pac_url = "../$firma_pac_url" if $firma_pac_url =~ m{^uploads/};
        
        $firma_med_url = $c_data->{firma_medico_data} || '';
        $firma_med_url = "../$firma_med_url" if $firma_med_url =~ m{^uploads/};
    };
}

my $objetivo     = $c_data->{procedimiento_objetivo} || 'Restablecer la salud del paciente y eliminar afecciones detectadas.';
my $beneficios   = $c_data->{procedimiento_beneficios} || 'Control de síntomas, alivio del dolor y recuperación de la función.';
my $riesgos      = $c_data->{procedimiento_riesgos} || 'Molestias temporales, inflamación leve o sensibilidad en la zona tratada.';
my $alternativas = $c_data->{procedimiento_alternativas} || 'Tratamiento farmacológico paliativo / Abordaje conservador.';

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Consentimiento Informado | OsPulso</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css" rel="stylesheet">
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #f8fafc; color: #1e293b; }
        .doc-card { max-width: 850px; margin: 2rem auto; background: white; border-radius: 20px; border: 2px solid #0A2A66; box-shadow: 0 15px 35px rgba(0,0,0,0.08); padding: 3rem; }
        .header-brand { border-bottom: 2px solid #0A2A66; padding-bottom: 1.5rem; margin-bottom: 2rem; }
        .legal-box { background: #fffbe0; border-left: 4px solid #f59e0b; border-radius: 12px; padding: 1.25rem; margin-bottom: 1.5rem; }
        .footer-legal { border-top: 1px solid #cbd5e1; margin-top: 3rem; padding-top: 1.5rem; font-size: 0.75rem; color: #64748b; }
        .signature-img { max-height: 90px; width: auto; object-fit: contain; }
        \@media print {
            .no-print { display: none !important; }
            .doc-card { border: none; box-shadow: none; padding: 0; margin: 0; }
        }
    </style>
</head>
<body>
    <div class="container no-print text-end mt-3 mb-0" style="max-width: 850px;">
        <button onclick="window.print()" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm me-2"><i class="bi bi-printer me-2"></i>Imprimir Consentimiento</button>
        <button onclick="window.close()" class="btn btn-outline-secondary rounded-pill px-3">Cerrar</button>
    </div>

    <div class="doc-card">
        <!-- Reglas_impresion.md: Cabecera -->
        <div class="header-brand d-flex justify-content-between align-items-center">
            <div>
                <h2 class="fw-black text-navy mb-0" style="color: #0A2A66;"><i class="bi bi-file-earmark-medical-fill me-2" style="color: #19B7A5;"></i>DOCUMENTO DE CONSENTIMIENTO INFORMADO</h2>
                <span class="text-uppercase fw-bold text-muted small" style="letter-spacing: 1px;">NOM-004-SSA3-2012 | Expediente Clínico Oficial</span>
            </div>
            <div class="text-end">
                <span class="badge bg-primary rounded-pill px-3 py-2 fw-bold d-block mb-1">OFICIAL</span>
                <span class="small fw-bold text-secondary">Fecha: $fecha</span>
            </div>
        </div>

        <!-- Identificación -->
        <div class="row g-3 mb-4 p-3 rounded-3 bg-light border">
            <div class="col-md-6">
                <span class="small text-muted d-block"><strong>Paciente Otorgante:</strong></span>
                <span class="fw-bold text-dark fs-5">$paciente_name</span>
            </div>
            <div class="col-md-6 text-md-end border-start ps-md-3">
                <span class="small text-muted d-block"><strong>Médico Tratante Responsable:</strong></span>
                <span class="fw-bold text-navy fs-6" style="color: #0A2A66;">$medico_name</span>
                <span class="small text-muted d-block">Cédula Prof: $medico_cedula | $institucion_name</span>
            </div>
        </div>

        <!-- Procedimiento -->
        <div class="mb-4">
            <h6 class="fw-bold mb-2 text-navy" style="color: #0A2A66;"><i class="bi bi-diagram-3-fill me-2 text-primary"></i>1. DESCRIPCIÓN DEL PROCEDIMIENTO Y OBJETIVOS</h6>
            <div class="p-3 bg-light rounded-3 border mb-3">
                <strong>Procedimiento Aceptado:</strong> $procedimiento<br>
                <strong>Objetivo Clínico:</strong> $objetivo<br>
                <strong>Beneficios Esperados:</strong> $beneficios
            </div>
        </div>

        <div class="mb-4">
            <h6 class="fw-bold mb-2 text-navy" style="color: #0A2A66;"><i class="bi bi-exclamation-triangle-fill me-2 text-warning"></i>2. RIESGOS, COMPLICACIONES Y ALTERNATIVAS</h6>
            <div class="p-3 bg-light rounded-3 border mb-3">
                <strong>Riesgos y Complicaciones Posibles:</strong> $riesgos<br>
                <strong>Alternativas Disponibles:</strong> $alternativas
            </div>
        </div>

        <!-- Derechos del Paciente -->
        <div class="legal-box mb-4">
            <h6 class="fw-bold text-warning-emphasis mb-2"><i class="bi bi-shield-check me-2"></i>3. DERECHOS DEL PACIENTE Y REVOCACIÓN</h6>
            <p class="small text-dark mb-0">
                El paciente manifiesta haber sido informado de manera oportuna, clara y comprensible sobre la naturaleza de su padecimiento, los riesgos inherentes al procedimiento y las alternativas médicas. Asimismo, confirma su derecho a **revocar de forma libre y voluntaria** este consentimiento en cualquier momento antes de la intervención.
            </p>
        </div>

        <!-- Formalización y Firmas Digitizables -->
        <div class="row align-items-end mt-5 pt-3">
            <div class="col-md-6 text-center">
                <div class="border rounded-3 p-2 bg-light mb-2 text-center" style="min-height: 100px;">
                    @{[ $firma_pac_url ? qq(<img src="$firma_pac_url" class="signature-img">) : qq(<div class="py-4 text-muted small">Firma Digital Plasmada</div>) ]}
                </div>
                <span class="fw-bold small text-navy d-block" style="color: #0A2A66;">Firma del Paciente / Tutor</span>
                <span class="small text-muted">$paciente_name</span>
            </div>
            <div class="col-md-6 text-center border-start">
                <div class="border rounded-3 p-2 bg-light mb-2 text-center" style="min-height: 100px;">
                    @{[ $firma_med_url ? qq(<img src="$firma_med_url" class="signature-img">) : qq(<div class="py-4 text-muted small">Firma Digital Plasmada</div>) ]}
                </div>
                <span class="fw-bold small text-navy d-block" style="color: #0A2A66;">Firma del Médico Responsable</span>
                <span class="small text-muted">$medico_name - Céd. $medico_cedula</span>
            </div>
        </div>

        <!-- Reglas_impresion.md: Pie de Página -->
        <div class="footer-legal d-flex justify-content-between align-items-center">
            <div>
                <strong>Confidencialidad Legal:</strong> Documento médico-legal registrado conforme a la NOM-004-SSA3-2012.
            </div>
            <div class="text-end fw-bold">
                Página 1 de 1 | $institucion_name
            </div>
        </div>
    </div>
</body>
</html>
HTML
1;
