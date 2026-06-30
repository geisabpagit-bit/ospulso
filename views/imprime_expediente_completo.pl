#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON qw(decode_json);
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

my $id_paciente = $q->param('id') || '';
my $paciente = {};
my $odontograma = {};

eval {
    binmode STDOUT, ":utf8";

    # Cargar Datos Maestro
    my $res = leer_tabla(File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat'), '\|');
    foreach my $c (@$res) {
        if ($c->[0] eq $id_paciente) {
            $paciente = { id_paciente=>$c->[0], nombre=>$c->[2], curp=>$c->[4], email=>$c->[5], f_nac=>$c->[6], sexo=>$c->[7], ocupacion=>$c->[8], e_civil=>$c->[9], tipo_sangre=>$c->[11], tel=>$c->[12] };
            last;
        }
    }
    
    die "Paciente no encontrado" unless $paciente->{id_paciente};

    # Cargar Odontograma
    my $archivo = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');
    if (-e $archivo) {
        open(my $fh, "<:encoding(UTF-8)", $archivo) or die "Error IO Odontograma: $!";
        while(<$fh>) {
            chomp;
            my ($p_id, $tipo, $fecha, $notas, @dientes) = split /\|/, $_;
            if ($p_id eq $id_paciente) {
                foreach my $diente_str (@dientes) {
                    if ($diente_str =~ /^(\d+)=(.+)$/) {
                        $odontograma->{$1} = decode_json($2);
                    }
                }
                last;
            }
        }
        close $fh;
    }
};
if ($@) {
    my $error = $@;
    open(my $log, '>>:encoding(UTF-8)', "$FindBin::Bin/../logs/execution.log");
    print $log "[".strftime("%Y-%m-%d %H:%M:%S", localtime)."] [ERROR 500] imprime_expediente_completo.pl: $error\n" if $log;
    close($log) if $log;

    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print qq{
        <!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Error 500</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet"></head>
        <body class="bg-light d-flex align-items-center justify-content-center vh-100">
            <div class="text-center p-5 bg-white border rounded shadow-sm">
                <h1 class="text-danger fw-bold">Error 500</h1>
                <p class="text-muted">Falla en generación de reporte completo. El incidente ha sido registrado.</p>
                <button class="btn btn-outline-secondary mt-3" onclick="window.close()">Cerrar</button>
            </div>
        </body></html>
    };
    exit;
}

my $fecha_actual = strftime("%d/%m/%Y", localtime);

print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Expediente Completo - $paciente->{nombre}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body { font-family: 'Arial', sans-serif; background: white; color: #1e293b; font-size: 12px; margin: 0; padding: 0; -webkit-print-color-adjust: exact; }
        .print-page { max-width: 900px; margin: 0 auto; padding: 30px; }
        
        /* Reglas de Impresión: Cabecera */
        .report-header { border-bottom: 2px solid #0A2A66; margin-bottom: 20px; padding-bottom: 10px; }
        .report-header h2 { margin: 0; color: #0A2A66; font-size: 24px; font-weight: bold; }
        .report-header p { margin: 5px 0 0 0; font-size: 14px; }
        
        /* Reglas de Impresión: Pie de Página */
        .report-footer { border-top: 1px solid #cbd5e1; margin-top: 40px; padding-top: 10px; font-size: 10px; color: #64748b; text-align: center; }
        .report-footer p { margin: 3px 0; }

        .section-title { background: #f1f5f9; border-left: 5px solid #0A2A66; padding: 8px 15px; font-weight: 800; text-transform: uppercase; margin: 25px 0 15px 0; }
        
        .kpi-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
        .kpi-box { border: 1px solid #e2e8f0; padding: 15px; border-radius: 10px; }
        .kpi-label { font-size: 10px; font-weight: 800; color: #64748b; text-transform: uppercase; }
        .kpi-value { font-size: 14px; font-weight: 700; color: #0A2A66; }

        /* Odontograma Impresion */
        .tooth-print { width: 45px; text-align: center; display: inline-block; margin: 2px; }
        .tooth-svg { width: 40px; height: 40px; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.1)); }
        .tooth-num { font-size: 9px; font-weight: bold; display: block; margin-bottom: 2px; }
        
        \@media print {
            .no-print { display: none !important; }
            body { padding: 0; }
            .print-page { width: 100%; max-width: 100%; padding: 0; }
        }
    </style>
</head>
<body onload="window.print()">

    <div class="no-print bg-dark text-white p-2 text-center mb-4">
        <strong>VISTA DE IMPRESIÓN CLÍNICA</strong> - <a href="javascript:window.close()" class="text-white">Cerrar</a>
    </div>

    <div class="print-page">
        <!-- Cabecera Estandarizada -->
        <div class="report-header d-flex justify-content-between align-items-end">
            <div>
                <h2>Hospital SDM Diamond</h2>
                <p><strong>M&oacute;dulo:</strong> Expediente Cl&iacute;nico Completo</p>
                <p><strong>Fecha:</strong> $fecha_actual</p>
            </div>
            <div class="text-end">
                <p class="mb-0 small fw-bold">Folio: SDM-$paciente->{id_paciente}</p>
            </div>
        </div>

        <div class="section-title">I. Datos del Paciente</div>
        <div class="row">
            <div class="col-8">
                <p class="mb-1"><span class="fw-bold">Nombre:</span> $paciente->{nombre}</p>
                <p class="mb-1"><span class="fw-bold">CURP:</span> $paciente->{curp}</p>
                <p class="mb-1"><span class="fw-bold">Email:</span> $paciente->{email}</p>
            </div>
            <div class="col-4">
                <p class="mb-1"><span class="fw-bold">Tel&eacute;fono:</span> $paciente->{tel}</p>
                <p class="mb-1"><span class="fw-bold">Sexo:</span> $paciente->{sexo}</p>
                <p class="mb-1"><span class="fw-bold">Sangre:</span> <span class="text-danger fw-bold">$paciente->{tipo_sangre}</span></p>
            </div>
        </div>

        <div class="section-title">II. Resumen de Salud</div>
        <div class="kpi-grid">
            <div class="kpi-box"><span class="kpi-label">Ocupaci&oacute;n</span><div class="kpi-value">$paciente->{ocupacion}</div></div>
            <div class="kpi-box"><span class="kpi-label">Estado Civil</span><div class="kpi-value">$paciente->{e_civil}</div></div>
            <div class="kpi-box"><span class="kpi-label">Fecha Nacimiento</span><div class="kpi-value">$paciente->{f_nac}</div></div>
        </div>

        <div class="section-title">III. Odontograma Actualizado</div>
        <div class="border rounded-4 p-4 text-center">
            <!-- Fila Superior -->
            <div class="mb-4">
                @{[ render_odontograma_print($odontograma, [18,17,16,15,14,13,12,11, 21,22,23,24,25,26,27,28]) ]}
            </div>
            <!-- Fila Inferior -->
            <div>
                @{[ render_odontograma_print($odontograma, [48,47,46,45,44,43,42,41, 31,32,33,34,35,36,37,38]) ]}
            </div>
            
            <div class="mt-4 d-flex justify-content-center gap-4">
                <div class="small"><span style="display:inline-block; width:12px; height:12px; background:#ef4444; border:1px solid #000;"></span> Caries</div>
                <div class="small"><span style="display:inline-block; width:12px; height:12px; background:#3b82f6; border:1px solid #000;"></span> Corona</div>
                <div class="small"><span style="display:inline-block; width:12px; height:12px; background:#1e293b; border:1px solid #000;"></span> Extracci&oacute;n</div>
                <div class="small"><span style="display:inline-block; width:12px; height:12px; background:#06b6d4; border:1px solid #000;"></span> Implante</div>
                <div class="small"><span style="display:inline-block; width:12px; height:12px; background:#f59e0b; border:1px solid #000;"></span> Pr&oacute;tesis</div>
            </div>
        </div>

        <div class="section-title">IV. Consentimiento y Firmas</div>
        <div class="row mt-5">
            <div class="col-6 text-center">
                <div style="border-top: 1px solid #000; width: 80%; margin: 60px auto 0 auto; padding-top: 5px;">
                    <p class="fw-bold mb-0">Firma del Paciente</p>
                </div>
            </div>
            <div class="col-6 text-center">
                <div style="border-top: 1px solid #000; width: 80%; margin: 60px auto 0 auto; padding-top: 5px;">
                    <p class="fw-bold mb-0">Sello y Firma M&eacute;dica</p>
                </div>
            </div>
        </div>

        <!-- Pie de Impresión Estandarizado -->
        <div class="report-footer mt-5">
            <p><strong>Direcci&oacute;n:</strong> Av Reforma 100, CDMX | <strong>Tel&eacute;fono:</strong> 555-1234-567 | <strong>Correo:</strong> contacto\@sdm.com</p>
            <p><strong>Aviso de confidencialidad:</strong> Este documento contiene informaci&oacute;n confidencial destinada &uacute;nicamente al receptor autorizado.</p>
            <p><strong>C&oacute;digo interno:</strong> SDM-EXP-$paciente->{id_paciente} | <strong>P&aacute;gina 1 de 1</strong></p>
        </div>
    </div>
</body>
</html>
HTML

sub render_odontograma_print {
    my ($data, $range) = @_;
    my $html = "";
    my %colors = ( caries => '#ef4444', corona => '#3b82f6', extraccion => '#1e293b', sano => '#10b981', implante => '#06b6d4', protesis => '#f59e0b' );

    foreach my $id (@$range) {
        my $state = $data->{$id} || { extracted => 0, faces => {}, whole_status => undef };
        my $faces_html = "";
        
        my $isSup = ($id >= 11 && $id <= 28) || ($id >= 51 && $id <= 65);
        my $topFace = $isSup ? 'vestibular' : 'lingual';
        my $bottomFace = $isSup ? 'palatino' : 'vestibular';
        my $quad = int($id / 10);
        my $leftFace = ($quad==1||$quad==4||$quad==5||$quad==8) ? 'distal' : 'mesial';
        my $rightFace = ($quad==1||$quad==4||$quad==5||$quad==8) ? 'mesial' : 'distal';

        my @coords = (
            { p => "10,10 90,10 75,25 25,25", pos => $topFace },
            { p => "25,75 75,75 90,90 10,90", pos => $bottomFace },
            { p => "10,10 25,25 25,75 10,90", pos => $leftFace },
            { p => "90,10 90,90 75,75 75,25", pos => $rightFace }
        );

        # Si todo el diente está afectado por estado completo
        if ($state->{extracted} || ($state->{whole_status} && $state->{whole_status} =~ /extraccion/)) {
            foreach my $c (@coords) { $faces_html .= qq{<polygon points="$c->{p}" fill="$colors{extraccion}" stroke="#cbd5e1" stroke-width="2"/>}; }
            $faces_html .= qq{<rect x="25" y="25" width="50" height="50" fill="$colors{extraccion}" stroke="#cbd5e1" stroke-width="2"/>};
        } elsif ($state->{whole_status}) {
            my $color = $colors{$state->{whole_status}} || 'white';
            foreach my $c (@coords) { $faces_html .= qq{<polygon points="$c->{p}" fill="$color" stroke="#cbd5e1" stroke-width="2"/>}; }
            $faces_html .= qq{<rect x="25" y="25" width="50" height="50" fill="$color" stroke="#cbd5e1" stroke-width="2"/>};
        } else {
            foreach my $c (@coords) {
                my $fill = $colors{$state->{faces}->{$c->{pos}}} || 'white';
                $faces_html .= qq{<polygon points="$c->{p}" fill="$fill" stroke="#cbd5e1" stroke-width="2"/>};
            }
            my $c_fill = $colors{$state->{faces}->{oclusal}} || 'white';
            $faces_html .= qq{<rect x="25" y="25" width="50" height="50" fill="$c_fill" stroke="#cbd5e1" stroke-width="2"/>};
        }

        $html .= qq{
            <div class="tooth-print">
                <span class="tooth-num">$id</span>
                <svg viewBox="0 0 100 100" class="tooth-svg">$faces_html</svg>
            </div>
        };
    }
    return $html;
}
