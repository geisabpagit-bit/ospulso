#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use LWP::UserAgent;
use JSON::PP;
use FindBin;
use File::Spec;

# ==========================================================
# SDM - CALLBACK DE GOOGLE CALENDAR v3.1.6
# Optimizado para HostGator y Sincronización Diamante
# ==========================================================

binmode STDOUT, ":encoding(UTF-8)";

my $q = CGI->new;
my $code  = $q->param('code') // '';
my $state = $q->param('state') // ''; # ID del Médico
my $error = $q->param('error') // '';

my $client_id     = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
my $client_secret = "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";
my $redirect_uri  = "https://sdm.pdigitalesm.com/auth/oauth_callback.pl";
my $tokens_file   = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'tokens_google.dat');

# print $q->header(-type => 'text/html', -charset => 'UTF-8'); # ELIMINADO: Rompe redirecciones

if ($error) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print_ui("Error de Autorización", "Google informó un error: $error", "btn-danger");
    exit;
}

unless ($code) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print_ui("Acceso Denegado", "No se recibió el código de autorización de Google.", "btn-warning");
    exit;
}

# --- INTERCAMBIO SEGURO ---
my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 }, timeout => 15);
$ua->agent("SoftwareDentalMexicano/3.1");

my $resp = $ua->post("https://oauth2.googleapis.com/token", [
    code          => $code,
    client_id     => $client_id,
    client_secret => $client_secret,
    redirect_uri  => $redirect_uri,
    grant_type    => 'authorization_code',
]);

if ($resp->is_success) {
    my $data = eval { decode_json($resp->decoded_content) };
    my $rt = $data->{refresh_token} if $data;
    
    if ($rt && $state) {
        actualizar_token_archivo($state, $rt);
        
        # Obtener correo para el modal de éxito
        my $user_email = obtener_correo_por_id($state);
        print $q->redirect("../index.html?registration=success&email=" . CGI::escape($user_email) . "&oauth=1");
        exit;
    } else {
        print $q->header(-type => 'text/html', -charset => 'UTF-8');
        print_ui("Aviso de Seguridad", "Google no envió un nuevo token. Si ya habías vinculado esta cuenta, intenta desvincular 'Software Dental Mexicano' en Google y reintenta.", "btn-info");
    }
} else {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print_ui("Falla de Intercambio", "Google rechazó el código: " . $resp->status_line, "btn-danger");
    # Registro de error para depuración silenciosa
    log_debug("OAUTH ERROR: " . $resp->decoded_content);
}

sub actualizar_token_archivo {
    my ($id_m, $tk) = @_;
    my @lineas;
    my $encontrado = 0;
    
    if (open my $fh, '<:encoding(UTF-8)', $tokens_file) {
        @lineas = <$fh>;
        close $fh;
    }
    
    foreach (@lineas) {
        if (/^$id_m\|/) {
            $_ = "$id_m|$tk\n";
            $encontrado = 1;
        }
    }
    push @lineas, "$id_m|$tk\n" unless $encontrado;
    
    if (open my $fh, '>', $tokens_file) {
        binmode $fh, ":utf8";
        print $fh @lineas;
        close $fh;
    }
}

sub log_debug {
    my $msg = shift;
    my $log = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'google_sync.log');
    if (open my $fh, '>>:encoding(UTF-8)', $log) {
        print $fh "[" . scalar(localtime) . "] $msg\n";
        close $fh;
    }
}

sub obtener_correo_por_id {
    my ($id_buscado) = @_;
    my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    return "usuario" unless -e $archivo_usuarios;
    
    open(my $fh, '<:encoding(UTF-8)', $archivo_usuarios) or return "usuario";
    while (<$fh>) {
        my @c = split /!/, $_;
        if ($c[0] eq $id_buscado) {
            close $fh;
            return $c[2] || "tu correo";
        }
    }
    close $fh;
    return "tu correo";
}

sub print_ui {
    my ($tit, $msg, $cls) = @_;
    my $icon = ($tit =~ /Exitosa/i) ? "bi-check-circle-fill" : "bi-shield-fill-exclamation";
    my $icon_color = ($tit =~ /Exitosa/i) ? "#00b894" : "#ef4444";
    my $btn_class = ($tit =~ /Exitosa/i) ? "btn-medentia-success" : "btn-medentia-danger";
    
    print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OSPulso | $tit</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="../css/ospulso_master.css">
    <style>
        body { 
            background: #f8fafc; 
            display: flex; 
            align-items: center; 
            justify-content: center; 
            height: 100vh; 
            margin: 0;
            font-family: 'Plus Jakarta Sans', sans-serif;
        }
        .diamond-card {
            background: white;
            border-radius: 2.5rem;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.1);
            padding: 3.5rem;
            text-align: center;
            max-width: 500px;
            width: 90%;
            border: 1px solid rgba(0,0,0,0.05);
        }
        .icon-box {
            width: 90px;
            height: 90px;
            border-radius: 2rem;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 2rem;
            font-size: 3rem;
            background: #f8fafc;
        }
        .btn-medentia-success {
            background: #00b894;
            color: white;
            border: none;
            padding: 1rem 2.5rem;
            border-radius: 1.2rem;
            font-weight: 700;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
        }
        .btn-medentia-success:hover {
            background: #00a383;
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(0, 184, 148, 0.2);
            color: white;
        }
        .btn-medentia-danger {
            background: #ef4444;
            color: white;
            border: none;
            padding: 1rem 2.5rem;
            border-radius: 1.2rem;
            font-weight: 700;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
        }
        .btn-medentia-danger:hover {
            background: #dc2626;
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(239, 68, 68, 0.2);
            color: white;
        }
    </style>
</head>
<body>
    <div class="diamond-card animate__animated animate__fadeIn">
        <div class="icon-box" style="color: $icon_color;">
            <i class="bi $icon"></i>
        </div>
        <h2 class="fw-bold text-navy mb-3">$tit</h2>
        <p class="text-muted mb-4 px-3">$msg</p>
        <a href="../index.html" class="$btn_class">
            <i class="bi bi-arrow-left me-2"></i>Volver al Login
        </a>
    </div>
</body>
</html>
HTML
}
1;
