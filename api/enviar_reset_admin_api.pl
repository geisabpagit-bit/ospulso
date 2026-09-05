#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use File::Basename;
use MIME::Lite;
use Digest::MD5;
use Encode qw(encode_utf8 decode_utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Organizacion') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $id_org_matriz = $sd->{id_empresa};
my $correo = lc(decode_utf8($q->param('correo') // ''));
$correo =~ s/^\s+|\s+$//g;

if (!$correo) {
    print encode_json({ status => 'error', message => 'El correo es obligatorio.' });
    exit;
}

my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $archivo_tokens   = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'tokens.dat');

# Verificar que el usuario exista y pertenezca a la organización
my $regs_usuarios = leer_tabla($archivo_usuarios, '!');
my $usuario_encontrado = 0;
my $user_alias = 'Usuario';

if ($regs_usuarios) {
    foreach my $r (@$regs_usuarios) {
        next if @$r < 7;
        my $cor_exist = lc($r->[2] // '');
        $cor_exist =~ s/^\s+|\s+$//g;
        
        my $extra = $r->[6];
        my ($org_id, $suc_id) = split(/:/, $extra);
        $org_id //= '';

        if ($cor_exist eq $correo) {
            # Verificar que sea de la organización
            if ($org_id eq $id_org_matriz) {
                $usuario_encontrado = 1;
                $user_alias = $r->[1] // 'Usuario';
            } else {
                print encode_json({ status => 'error', message => 'El usuario no pertenece a tu organización.' });
                exit;
            }
            last;
        }
    }
}

if (!$usuario_encontrado) {
    print encode_json({ status => 'error', message => 'Usuario no encontrado.' });
    exit;
}

# --- ENVÍO DE CORREO (Adaptado de recuperar_clave.pl) ---
my $timestamp = time();
my $token_raw = "$correo|$timestamp";
my $token = Digest::MD5->new->add($token_raw)->hexdigest;

my $expiracion = time() + 3600; 

eval {
    open(my $fh, '>>:encoding(UTF-8)', $archivo_tokens) or die "Error: $!";
    print $fh "$token!$correo!$expiracion\n"; 
    close($fh);
};

if ($@) {
    print encode_json({ status => 'error', message => 'Error interno al generar el token.' });
    exit;
}

my $host = $ENV{'HTTP_HOST'} || 'ospulso.pdigitalesm.com';
my $url_recuperacion = "https://$host/auth/cambiar_clave.pl?token=$token";

my $from = 'administracion@ospulso.pdigitalesm.com';
my $to = $correo;
my $subject = encode_utf8("Restablecer Contraseña - Software Dental Mexicano"); 

my $body_text = encode_utf8(
    "Hola $user_alias,\n\nTu Administrador ha solicitado restablecer tu contraseña para acceder a OSPulso. \n\n" .
    "Haz clic en el siguiente enlace. Caduca en 1 hora:\n\n" .
    "$url_recuperacion\n\n" .
    "Si tú no lo solicitaste o no sabes de qué se trata, consulta con el Director de tu Clínica.\n\n"
);

my $cuerpo_html = encode_utf8(qq{
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Recuperación de Contraseña</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f4f4f4; }
            .container { max-width: 600px; margin: 20px auto; background-color: #ffffff; padding: 20px; border-radius: 8px; box-shadow: 0 0 10px rgba(0, 0, 0, 0.1); }
            .header { color: #007bff; font-size: 24px; margin-bottom: 20px; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
            .content { line-height: 1.6; color: #333333; }
            .button-container { text-align: center; margin: 30px 0; }
            .button { background-color: #28a745; color: white !important; padding: 12px 25px; text-decoration: none; border-radius: 5px; font-weight: bold; display: inline-block; }
            .footer { margin-top: 20px; padding-top: 10px; border-top: 1px solid #eeeeee; font-size: 12px; color: #777777; }
            .link-text { word-break: break-all; color: #007bff; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">¡Restablecer Contraseña en Software Dental Mexicano!</div>
            <div class="content">
                <p>Hola $user_alias,</p> <p>Tu Administrador ha solicitado enviarte un enlace de acceso para tu cuenta. Por favor, haz clic en el siguiente botón para asignar una nueva contraseña:</p>
                
                <div class="button-container">
                    <a href="$url_recuperacion" class="button">Configurar mi Contraseña</a>
                </div>

                <p>Si el botón no funciona, copia y pega el siguiente enlace en tu navegador:</p>
                <p class="link-text"><a href="$url_recuperacion">$url_recuperacion</a></p>
                
                <hr>
                <p style="font-style: italic;">Si no solicitaste este cambio o no sabes de qué se trata, consulta con el Director de tu Clínica.</p>
            </div>
        </div>
    </body>
    </html>
});

my $success = 0; 
eval {
    my $msg = MIME::Lite->new(
        From    => $from,
        To      => $to,
        Subject => $subject,
        Type    => 'multipart/alternative',
    );
    $msg->attach(Type => 'text/plain', Data => $body_text, Charset => 'utf-8');
    $msg->attach(Type => 'text/html', Data => $cuerpo_html, Charset => 'utf-8');
    $msg->send; 
    $success = 1; 
};

if ($@ || !$success) {
    print encode_json({ status => 'error', message => 'El correo no pudo ser enviado por un error del servidor.' });
    exit;
}

print encode_json({ status => 'success', message => 'Correo de restablecimiento enviado exitosamente.' });
1;
