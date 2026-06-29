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
use Encode qw(encode_utf8);
use MIME::Lite; 
use Digest::MD5;

# --- CONFIGURACIÓN DE RESPUESTA JSON ---
my $q = CGI->new;
my $json_engine = JSON::PP->new->utf8(1)->allow_nonref;
print $q->header(-type => 'application/json', -charset => 'UTF-8');

# --- CONSTANTES CON RUTAS ABSOLUTAS (Protocolo 11.1) ---
my $dirname = dirname(__FILE__);
my $archivo_tokens   = File::Spec->rel2abs("$dirname/../dat/tokens.dat");
my $archivo_usuarios = File::Spec->rel2abs("$dirname/../dat/usuarios.dat");

use constant EXPIRATION_SECONDS => 3600; 
use constant USER_NAME_INDEX => 1;      
use constant CORREO_INDEX_USER => 2; 

# -------------------------------------------------------------------
# --- FUNCIÓN: Obtener Alias/Nombre del Usuario ---
# -------------------------------------------------------------------
sub get_user_alias {
    my ($correo) = @_;
    my $user_name = ''; 
    my $correo_lower = lc($correo);
    
    if (-e $archivo_usuarios) {
        if (open(my $fh, '<:encoding(UTF-8)', $archivo_usuarios)) {
            my $header_line = <$fh>; # Saltar cabecera
            
            while (my $linea = <$fh>) {
                chomp $linea;
                next if $linea =~ /^\s*$/;
                my @campos = split /!/, $linea, -1; 
                
                # 1. Comprobar si el campo de correo (índice 2) coincide
                if (@campos > CORREO_INDEX_USER && lc($campos[CORREO_INDEX_USER]) eq $correo_lower) {
                    # 2. Obtener el Nombre (índice 1) para el saludo
                    $user_name = $campos[USER_NAME_INDEX]; 
                    last;
                }
            }
            close($fh);
        }
    }
    return $user_name || 'Usuario'; # Valor predeterminado si no se encuentra
}

# -------------------------------------------------------------------
# --- FUNCIÓN: Envío de Correo (HTML) ---
# -------------------------------------------------------------------
sub enviar_correo_recuperacion {
    my ($correo, $error_ref, $user_alias) = @_; 
    
    # 1. Generar Token
    my $timestamp = time();
    my $token_raw = "$correo|$timestamp";
    my $token = Digest::MD5->new->add($token_raw)->hexdigest;
    
    # 2. ** GUARDAR TOKEN Y CORREO **
    my $expiracion = time() + EXPIRATION_SECONDS; 

    eval {
        open(my $fh, '>>:encoding(UTF-8)', $archivo_tokens) or die "No se pudo abrir $archivo_tokens para escribir: $!";
        print $fh "$token!$correo!$expiracion\n"; 
        close($fh);
    };

    if ($@) {
        ${$error_ref} = "Error de escritura del token: $@";
        return 0; 
    }
    
    # 3. Construir URL y Contenido del Email
    my $url_recuperacion = "https://sdm.pdigitalesm.com/auth/cambiar_clave.pl?token=$token";
    
    my $from = 'administracion@sdm.pdigitalesm.com';
    my $to = $correo;
    my $subject = encode_utf8("Recuperación de Contraseña - Software Dental Mexicano"); 
    
    # Contenido de Texto Plano (Fallback)
    my $body_text = encode_utf8(
        "Hola $user_alias,\n\nHemos recibido una solicitud para restablecer tu contraseña. \n\n" .
        "Haz clic en el siguiente enlace. Caduca en 1 hora:\n\n" .
        "$url_recuperacion\n\n" .
        "Si no solicitaste este cambio, por favor ignora este correo.\n\n"
    );

    # Contenido HTML (Diseño similar a la imagen)
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
                    <p>Hola $user_alias,</p> <p>Hemos recibido una solicitud para restablecer la contraseña de tu cuenta. Por favor, haz clic en el siguiente botón para continuar:</p>
                    
                    <div class="button-container">
                        <a href="$url_recuperacion" class="button">Restablecer mi Contraseña</a>
                    </div>

                    <p>Si el botón no funciona, copia y pega el siguiente enlace en tu navegador:</p>
                    <p class="link-text"><a href="$url_recuperacion">$url_recuperacion</a></p>
                    
                    <hr>
                    <p style="font-style: italic;">Si no solicitaste este cambio, por favor ignora este correo.</p>
                </div>
                <div class="footer">
                    
                </div>
            </div>
        </body>
        </html>
    });

    # 4. Envío del Email usando MIME::Lite con sendmail
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

    if ($@) {
        ${$error_ref} = "Fallo Crítico (sendmail die): $@";
        warn "Error fatal en MIME::Lite/sendmail: $@";
        return 0;
    }
    
    if (!$success) {
        ${$error_ref} = "Fallo en el envio local. El servidor SMTP/sendmail rechazó la solicitud.";
        return 0;
    }

    return $success;
}

# -------------------------------------------------------------------
# --- SCRIPT PRINCIPAL ---
# -------------------------------------------------------------------

my $correo_recuperacion = $q->param('h_correo_recuperacion') || '';
my $error_message = 'Solicitud incompleta (POST o parametro faltante).'; 

my $response = { success => 0, message => $error_message };

if ($q->request_method eq 'POST' && $correo_recuperacion) {
    
    my $user_alias = get_user_alias($correo_recuperacion);

    # Si el correo no existe en la base de datos, respondemos con éxito para evitar la enumeración de usuarios
    if (!$user_alias || $user_alias eq 'Usuario') { # Verificamos si no se encontró el nombre
         $response->{success} = 1;
         $response->{message} = "Hemos procesado tu solicitud. Si el correo existe en nuestra base de datos, recibiras un enlace de recuperacion en breve.";
         print $json_engine->encode($response);
         exit;
    }

    # Pasamos el alias y la referencia a la variable de error
    if (enviar_correo_recuperacion($correo_recuperacion, \$error_message, $user_alias)) {
        $response->{success} = 1;
        $response->{message} = "Hemos procesado tu solicitud. Si el correo existe en nuestra base de datos, recibiras un enlace de recuperacion en breve.";
    } else {
        $response->{message} = "ERROR: $error_message";
    }
}

# Imprimir la respuesta JSON
print $json_engine->encode($response);
exit;