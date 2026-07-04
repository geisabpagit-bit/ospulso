#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use JSON::PP;
use File::Basename;
use File::Spec;
use lib dirname(__FILE__) . '/..';
use Digest::SHA qw(sha256_hex);
use Digest::MD5 qw(md5_hex);
use Encode qw(decode_utf8);
use MIME::Lite;
use utils::db_manager qw(leer_tabla actualizar_archivo obtener_nuevo_id crear_nuevo_negocio);

# --- PROTOCOLO 11.2: Forzar UTF-8 ---
binmode(STDOUT, ":utf8");
binmode(STDIN,  ":utf8");

use FindBin;
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_contador = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'contador_registro_inicial.dat');

my $q = CGI->new;
my $titulo_error = "Error de Registro";

# 1. Asegurar persistencia de cabecera si el archivo está vacío
unless (-e $archivo_usuarios && -s $archivo_usuarios > 10) {
    open(my $fh, '>:encoding(UTF-8)', $archivo_usuarios);
    print $fh "id!nombre!correo!clave!activo!rol!extra\n";
    close($fh);
}

# 2. Parámetros
my $nombre     = decode_utf8($q->param('h_admin_nombre') // '');
my $correo     = decode_utf8($q->param('h_admin_correo') // '');
my $clave      = $q->param('h_admin_clave') // '';
my $clave_conf = $q->param('h_admin_clave_confirm') // '';
my $tipo_uni   = decode_utf8($q->param('tipo_unidad') // 'Privado');
my $nom_neg    = decode_utf8($q->param('h_admin_negocio') // 'Clínica Nueva');
my $consent    = $q->param('consent_calendar') // '';

# 3. Validaciones
unless ($nombre && $correo && $clave && $nom_neg) {
    print_error("Campos incompletos.", $q, $titulo_error);
    exit;
}

if ($clave ne $clave_conf) {
    print_error("Las contraseñas no coinciden.", $q, $titulo_error);
    exit;
}

if (registro_existe($archivo_usuarios, $correo)) {
    print_error("El correo <strong>$correo</strong> ya está registrado.", $q, $titulo_error);
    exit;
}

# 4. Gestión Segura del Contador e ID (Sincronización Absoluta)
my $registro_id = obtener_nuevo_id($archivo_contador);
my $clave_hash  = sha256_hex($clave);

# Creación de Negocio Multi-Tenant
my $nuevo_id_negocio = crear_nuevo_negocio($nom_neg, $correo, $tipo_uni);

# Asegurar salto de línea previo si es necesario (Protocolo de Integridad)
preparar_archivo_para_anexo($archivo_usuarios);

# 5. Guardar Usuario - Estado 0 = PENDIENTE, enlazado al nuevo Negocio
my $linea = join('!', $registro_id, $nombre, $correo, $clave_hash, 0, 'Medico', "$nuevo_id_negocio:") . "\n";
open(my $out, '>>:encoding(UTF-8)', $archivo_usuarios) or die "Error al guardar: $!";
print $out $linea;
close($out);

# 6. Envío de Correo de Activación
enviar_correo_activacion($nombre, $correo, $registro_id);

# 7. Redirección Inteligente
if ($consent) {
    my $client_id    = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
    my $host         = $ENV{'HTTP_HOST'} || 'ospulso.pdigitalesm.com';
    my $redirect_uri = "https://$host/auth/oauth_callback.pl";
    my $scope        = "https://www.googleapis.com/auth/calendar";
    my $auth_url     = "https://accounts.google.com/o/oauth2/v2/auth?client_id=$client_id&redirect_uri=$redirect_uri&response_type=code&scope=$scope&access_type=offline&prompt=consent&state=$registro_id";
    print $q->redirect($auth_url);
} else {
    # Redirección al Landing con flag de éxito para mostrar Modal Diamond
    print $q->redirect("../index.html?registration=success&email=" . CGI::escape($correo));
}
exit;

# --- SUBRUTINAS ---

sub enviar_correo_activacion {
    my ($nom, $eml, $id) = @_;
    my $token = md5_hex($id . $eml);
    my $host  = $ENV{'HTTP_HOST'} || 'ospulso.pdigitalesm.com';
    my $link  = "https://$host/auth/correo_verificado_reg.pl?id=$id&token=$token";

    my $html = qq{
        <html>
        <body style="font-family: Arial, sans-serif; color: #0A2A66;">
            <div style="max-width: 600px; margin: 0 auto; border: 1px solid #e2e8f0; border-radius: 20px; overflow: hidden;">
                <div style="background: #124A9E; padding: 20px; text-align: center; color: white;">
                    <div style="margin-bottom: 15px;">
                        <svg viewBox="0 0 500 120" fill="none" xmlns="http://www.w3.org/2000/svg" style="height: 40px;">
                            <g>
                                <path d="M40 60C40 43.4315 53.4315 30 70 30" stroke="#124A9E" stroke-width="6" stroke-linecap="round"></path>
                                <circle cx="40" cy="60" r="4" fill="#18D1E6"></circle>
                                <path d="M40 60C40 76.5685 53.4315 90 70 90" stroke="#124A9E" stroke-width="6" stroke-linecap="round"></path>
                                <circle cx="70" cy="30" r="4" fill="#18D1E6"></circle>
                                <circle cx="70" cy="90" r="4" fill="#18D1E6"></circle>
                                <path d="M55 45H40" stroke="#124A9E" stroke-width="4"></path>
                                <path d="M55 75H40" stroke="#124A9E" stroke-width="4"></path>
                                <rect x="75" y="35" width="50" height="50" rx="10" fill="#124A9E"></rect>
                                <path d="M100 45V75M85 60H115" stroke="white" stroke-width="8" stroke-linecap="round"></path>
                            </g>
                            <text x="150" y="82" font-family="Arial, sans-serif" font-weight="800" font-size="64" fill="#ffffff">OS</text>
                            <text x="260" y="82" font-family="Arial, sans-serif" font-weight="800" font-size="64" fill="#18D1E6">Pulso</text>
                        </svg>
                    </div>
                    <h2 style="margin:0; font-size: 1.2rem; font-weight: 500;">Sistema Operativo para Clínicas Modernas</h2>
                </div>
                <div style="padding: 30px; line-height: 1.6;">
                    <p>Hola <strong>$nom</strong>,</p>
                    <p>Gracias por unirte a OsPulso. Para activar tu unidad, haz clic en el siguiente botón:</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="$link" style="background: #00b894; color: white; padding: 12px 25px; text-decoration: none; border-radius: 10px; font-weight: bold;">Activar mi Cuenta</a>
                    </div>
                    <p style="font-size: 12px; color: #64748b;">Si no solicitaste este registro, puedes ignorar este correo.</p>
                </div>
            </div>
        </body>
        </html>
    };

    eval {
        # PROTOCOLO 13: SIEMPRE escapar el @ como \@
        my $msg = MIME::Lite->new(
            From    => "administracion\@ospulso.pdigitalesm.com",
            To      => $eml,
            Subject => 'Activa tu cuenta de OsPulso',
            Type    => 'text/html',
            Data    => $html
        );
        $msg->attr('content-type.charset' => 'UTF-8');
        $msg->send;
    };
    if ($@) {
        warn "Error enviando correo: $@";
    }
}

sub preparar_archivo_para_anexo {
    my ($archivo) = @_;
    return unless -e $archivo;
    open(my $fh, '+<', $archivo) or return;
    seek($fh, 0, 2);
    my $pos = tell($fh);
    if ($pos > 0) {
        seek($fh, -1, 2);
        my $last_char;
        read($fh, $last_char, 1);
        if ($last_char ne "\n") {
            seek($fh, 0, 2);
            print $fh "\n";
        }
    }
    close($fh);
}

sub obtener_nuevo_id {
    my ($archivo) = @_;
    my $id;
    if (-e $archivo) {
        open(my $fh, '+<:encoding(UTF-8)', $archivo);
        flock($fh, 2);
        my $num = <$fh>;
        $id = ($num && $num =~ /(\d+)/) ? abs($1) : abs(time);
        seek $fh, 0, 0;
        truncate $fh, 0;
        print $fh (abs($id) + 1) . "\n";
        close $fh;
    } else {
        $id = abs(time);
        open(my $fh, '>:encoding(UTF-8)', $archivo);
        print $fh (abs($id) + 1) . "\n";
        close $fh;
    }
    return abs($id);
}

sub registro_existe {
    my ($file, $mail) = @_;
    return 0 unless -e $file;
    open(my $fh, '<:encoding(UTF-8)', $file) or return 0;
    while (<$fh>) {
        my @c = split /!/, $_;
        if ($c[2] && $c[2] eq $mail) { close $fh; return 1; }
    }
    close $fh; return 0;
}

sub print_error {
    my ($msg, $q_obj, $titulo) = @_;
    print $q_obj->header(-type => 'text/html', -charset => 'UTF-8');
    print <<HTML;
    <style>body{font-family:sans-serif; display:flex; align-items:center; justify-content:center; height:100vh; background:#f8fafc; color:#0A2A66;}</style>
    <div style="text-align:center; padding:2rem; background:white; border-radius:2rem; box-shadow:0 10px 30px rgba(0,0,0,0.05);">
        <h2 style="color:#e11d48;">$titulo</h2>
        <p>$msg</p>
        <a href='../auth/registro.pl' style="color:#124A9E; font-weight:bold;">Intentar de nuevo</a>
    </div>
HTML
}
1;
