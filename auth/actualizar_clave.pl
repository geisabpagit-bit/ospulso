#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Digest::SHA qw(sha256_hex);
use File::Copy;
use FindBin;
use File::Spec;

# ==========================================================
# SDM - ACTUALIZAR CONTRASEÑA v3.1.6 PREMIUM
# ==========================================================

my $q = CGI->new;
my $token = $q->param('h_token') || '';
my $new_pass = $q->param('h_nueva_clave') || '';
my $conf_pass = $q->param('h_confirmar_clave') || '';

my $archivo_tokens = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'tokens.dat');
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');

my $error_msg = '';
my $success = 0;
my $correo_valid = undef;

# 1. Validaciones de Seguridad
if ($q->request_method ne 'POST') {
    $error_msg = "Método no permitido.";
} elsif (!$token || !$new_pass || $new_pass ne $conf_pass) {
    $error_msg = "Los datos son inconsistentes o las claves no coinciden.";
} elsif (length($new_pass) < 8) {
    $error_msg = "La contraseña debe tener al menos 8 caracteres.";
}

# 2. Validación de Token y Quema (Consumo)
if (!$error_msg) {
    my @tokens_restantes;
    my $current_time = time();
    
    if (open(my $fh, '<:encoding(UTF-8)', $archivo_tokens)) {
        while (my $linea = <$fh>) {
            chomp $linea;
            my ($t, $c, $exp) = split /!/, $linea;
            if ($t eq $token && $exp > $current_time) {
                $correo_valid = $c;
            } else {
                push @tokens_restantes, $linea if $exp > $current_time;
            }
        }
        close($fh);
    }
    
    if ($correo_valid) {
        # Reescribir tokens sin el usado
        if (open(my $fh_w, '>', $archivo_tokens)) {
            print $fh_w join("\n", @tokens_restantes) . "\n";
            close($fh_w);
        }
    } else {
        $error_msg = "El enlace ha caducado o ya fue utilizado.";
    }
}

# 3. Actualización de Base de Datos
if (!$error_msg && $correo_valid) {
    my $temp_file = $archivo_usuarios . ".tmp";
    my $hash = sha256_hex($new_pass);
    
    if (open(my $in, '<:encoding(UTF-8)', $archivo_usuarios) && open(my $out, '>', $temp_file)) {
        binmode $out, ":utf8";
        while (my $linea = <$in>) {
            chomp $linea;
            my @f = split /!/, $linea, -1;
            if ($f[2] && lc($f[2]) eq lc($correo_valid)) {
                $f[3] = $hash;
                print $out join('!', @f) . "\n";
            } else {
                print $out "$linea\n";
            }
        }
        close($in); close($out);
        
        if (move($temp_file, $archivo_usuarios)) {
            $success = 1;
        } else {
            $error_msg = "Error al actualizar la base de datos.";
        }
    } else {
        $error_msg = "Error de acceso a archivos de datos.";
    }
}

# 4. Renderizado Premium de Resultado
print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8"><title>Resultado - Software Dental Mexicano</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;800&display=swap" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <style>
        body { font-family: 'Plus Jakarta Sans', sans-serif; background: #0d1e3d; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { border-radius: 2.5rem; border: none; max-width: 500px; width: 90%; }
    </style>
</head>
<body>
<div class="card p-5 text-center shadow-2xl">
HTML

if ($success) {
    print <<HTML;
    <script>
        Swal.fire({
            icon: 'success',
            title: '¡Clave Actualizada!',
            text: 'Tu acceso ha sido restablecido con éxito.',
            confirmButtonText: 'IR AL LOGIN',
            confirmButtonColor: '#0d1e3d',
            allowOutsideClick: false,
            customClass: { popup: 'rounded-5' }
        }).then(() => { window.location.href = '../index.html'; });
    </script>
    <div class="py-5"><div class="spinner-border text-success"></div><p class="mt-3 fw-bold">Redirigiendo...</p></div>
HTML
} else {
    print <<HTML;
    <script>
        Swal.fire({
            icon: 'error',
            title: 'Error de Seguridad',
            text: '$error_msg',
            confirmButtonText: 'REINTENTAR',
            confirmButtonColor: '#dc3545',
            customClass: { popup: 'rounded-5' }
        }).then(() => { window.history.back(); });
    </script>
    <div class="py-5"><h2 class="text-danger fw-bold">⚠️ Fallo Crítico</h2><p>$error_msg</p></div>
HTML
}

print "</div></body></html>";
1;