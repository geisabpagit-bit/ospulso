#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser); # MANDATORIO PARA AISLAR EL ERROR 500

# 1. Enviar cabecera lo antes posible para evitar Error 500 por cabeceras inexistentes
use CGI;
my $q = CGI->new;
print $q->header(-type => 'application/json', -charset => 'UTF-8');

# Log de depuración inicial
# warn "[SDM DEBUG] check_email.pl iniciado\n";

use utf8;
use JSON::PP;
use FindBin;
use File::Spec;

# 2. Inclusión de librería (Posible punto de fallo)
use lib "$FindBin::Bin/..";
eval {
    require utils::db_manager;
    utils::db_manager->import(qw(leer_tabla verificar_estado_negocio));
};
if ($@) {
    print JSON::PP->new->utf8->encode({ success => 0, error => "Error al cargar db_manager: $@" });
    exit;
}

# --- CONFIGURACIÓN ---
use constant CORREO_INDEX => 2;
my $json = JSON::PP->new->utf8(1)->allow_nonref;

my $correo_a_validar = $q->param('correo') || '';

# Limpieza estricta de entrada
$correo_a_validar =~ s/\s//g;
$correo_a_validar = lc($correo_a_validar);

# Respuesta por defecto
my $response = { exists => 0, status => "ok", debug_path => $FindBin::Bin };

# --- LÓGICA DE BÚSQUEDA ---
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');

if (!-e $archivo_usuarios) {
    $response->{error} = "Archivo de datos no encontrado en: $archivo_usuarios";
} elsif ($correo_a_validar) {
    eval {
        my $usuarios = leer_tabla($archivo_usuarios, '!');
        foreach my $campos (@$usuarios) {
            if (@$campos > CORREO_INDEX && lc($campos->[CORREO_INDEX]) eq $correo_a_validar) {
                $response->{exists} = 1;
                
                # Verificar suscripción del negocio asociado
                my $id_negocio = $campos->[6] // 0; # ID_negocio está en índice 6
                if ($id_negocio) {
                    my $biz = verificar_estado_negocio($id_negocio);
                    $response->{business_active} = $biz->{activo};
                } else {
                    $response->{business_active} = 1; # Si no tiene negocio asociado (ej. paciente), se asume activo
                }
                last;
            }
        }
    };
    if ($@) {
        $response->{error} = "Error en leer_tabla: $@";
    }
} else {
    $response->{error} = "No se proporcionó un correo válido.";
}

# Envío de respuesta
print $json->encode($response);
1;