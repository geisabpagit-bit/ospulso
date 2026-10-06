#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON::PP;
use POSIX qw(strftime);
use FindBin;
use lib "$FindBin::Bin/..";

require "$FindBin::Bin/../auth/check_session.pl";

my $q = CGI->new;
my $sd = check_session();

print $q->header(-type => 'application/json', -charset => 'UTF-8');
binmode STDOUT, ":raw";

unless ($sd->{session_ok}) {
    print encode_json({ ok => 0, msg => "Sesión inválida o expirada" });
    exit;
}

my $id_campana = $q->param('id_campana') || '';
my $lote_size  = int($q->param('lote_size') || 10);
$lote_size = 10 if $lote_size < 1 || $lote_size > 50;

if (!$id_campana) {
    print encode_json({ ok => 0, msg => "El parámetro id_campana es obligatorio" });
    exit;
}

my $cola_file     = "$FindBin::Bin/../dat/cola_correos_masivos.dat";
my $campanas_file = "$FindBin::Bin/../dat/campanas_comunicacion.dat";
my $historial_file = "$FindBin::Bin/../dat/historial_correos.dat";

unless (-f $cola_file) {
    print encode_json({ ok => 0, msg => "No existe la cola de correos masivos" });
    exit;
}

my $has_mime_lite = eval "use MIME::Lite; 1;";

# 1. Leer cola y extraer elementos a despachar en este lote
my @lineas_cola = ();
my @lote_a_procesar = ();
my $total_campana = 0;
my $pendientes_antes = 0;

open(my $qfh, "<:encoding(UTF-8)", $cola_file) or die "No se pudo leer cola: $!";
my $q_header = <$qfh>;
push @lineas_cola, $q_header;

while (my $line = <$qfh>) {
    chomp($line);
    next if $line =~ /^\s*$/;
    my @f = split(/\|/, $line);
    if ($f[1] eq $id_campana) {
        $total_campana++;
        if ($f[7] eq 'PENDIENTE') {
            $pendientes_antes++;
            if (@lote_a_procesar < $lote_size) {
                push @lote_a_procesar, \@f;
                next; # Lo modificaremos abajo
            }
        }
    }
    push @lineas_cola, "$line\n";
}
close($qfh);

my $ahora_completo = strftime("%Y-%m-%d %H:%M:%S", localtime);
my $procesados_ahora = 0;
my $nuevos_enviados = 0;
my $nuevos_fallidos = 0;

# 2. Despachar cada correo del lote
foreach my $item (@lote_a_procesar) {
    my ($id_cola, $cmp_id, $email, $nombre, $tipo, $asunto, $cuerpo_html, $estado, $intentos, $fecha_envio, $error_msg) = @$item;

    # Sustitución dinámica de variables de personalización
    my $cuerpo_personalizado = $cuerpo_html;
    $cuerpo_personalizado =~ s/\{\{nombre\}\}/$nombre/g;
    $cuerpo_personalizado =~ s/\{\{clinica\}\}/OSPulso Clínicas/g;
    $cuerpo_personalizado =~ s/\{\{medico\}\}/Dr. Tratante/g;
    $cuerpo_personalizado =~ s/\{\{fecha\}\}/$ahora_completo/g;
    $cuerpo_personalizado =~ s/&#124;/\|/g;

    my $envio_exitoso = 0;
    my $detalle_err = "";

    if ($has_mime_lite) {
        eval {
            my $html_template = qq{
                <html>
                <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6; background-color: #f8fafc; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden;">
                        <div style="background: #0A2A66; padding: 20px; color: #ffffff;">
                            <h2 style="margin: 0; font-size: 20px;">$asunto</h2>
                        </div>
                        <div style="padding: 25px;">
                            $cuerpo_personalizado
                        </div>
                        <div style="background: #f1f5f9; padding: 15px; font-size: 12px; color: #64748b; text-align: center; border-top: 1px solid #e2e8f0;">
                            Este es un mensaje institucional generado por la plataforma OSPulso.
                        </div>
                    </div>
                </body>
                </html>
            };

            my $msg = MIME::Lite->new(
                From    => 'notificaciones@ospulso.com',
                To      => $email,
                Subject => $asunto,
                Type    => 'text/html; charset=UTF-8',
                Data    => $html_template
            );
            $msg->send;
            $envio_exitoso = 1;
        };
        if ($@) {
            $detalle_err = "Error SMTP: $@";
            $detalle_err =~ s/\r|\n|\|/ /g;
        }
    } else {
        # Modo simulación para entornos locales sin sendmail/SMTP
        $envio_exitoso = 1;
        $detalle_err = "Entorno local (Simulado exitoso)";
    }

    $procesados_ahora++;
    $intentos++;
    if ($envio_exitoso) {
        $estado = "ENVIADO";
        $fecha_envio = $ahora_completo;
        $nuevos_enviados++;

        # Asentar en historial canónico
        if (-f $historial_file) {
            open(my $hfh, ">>:encoding(UTF-8)", $historial_file);
            print $hfh time() . "|$id_cola|$ahora_completo|$asunto|$email|Enviado Masivo\n";
            close($hfh);
        }
    } else {
        $estado = "FALLIDO";
        $error_msg = $detalle_err;
        $nuevos_fallidos++;
    }

    push @lineas_cola, "$id_cola|$cmp_id|$email|$nombre|$tipo|$asunto|$cuerpo_html|$estado|$intentos|$fecha_envio|$error_msg\n";
}

# 3. Reescribir cola actualizada
open(my $wfh, ">:encoding(UTF-8)", $cola_file) or die "No se pudo escribir cola: $!";
print $wfh @lineas_cola;
close($wfh);

# 4. Actualizar contadores en campanas_comunicacion.dat
my $pendientes_restantes = $pendientes_antes - $procesados_ahora;
$pendientes_restantes = 0 if $pendientes_restantes < 0;

if (-f $campanas_file) {
    my @lineas_cmp = ();
    open(my $cfh, "<:encoding(UTF-8)", $campanas_file);
    while (my $cline = <$cfh>) {
        chomp($cline);
        my @c = split(/\|/, $cline);
        if ($c[0] eq $id_campana) {
            $c[10] = ($c[10] || 0) + $nuevos_enviados;
            $c[11] = ($c[11] || 0) + $nuevos_fallidos;
            $c[12] = ($pendientes_restantes == 0) ? "COMPLETADO" : "EN_PROCESO";
            $cline = join("|", @c);
        }
        push @lineas_cmp, "$cline\n";
    }
    close($cfh);

    open(my $cwfh, ">:encoding(UTF-8)", $campanas_file);
    print $cwfh @lineas_cmp;
    close($cwfh);
}

my $porcentaje = ($total_campana > 0) ? int((($total_campana - $pendientes_restantes) / $total_campana) * 100) : 100;

print encode_json({
    ok                   => 1,
    id_campana           => $id_campana,
    procesados           => $procesados_ahora,
    pendientes_restantes => $pendientes_restantes,
    total                => $total_campana,
    porcentaje           => $porcentaje,
    completado           => ($pendientes_restantes == 0 ? 1 : 0)
});
