#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Fcntl qw(:flock);
use Digest::MD5 qw(md5_hex);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

# 1. Carga de Layouts con rutas absolutas
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');

my $q = CGI->new;
my $archivo_datos = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');

# Índices del archivo usuarios.dat
use constant ID_INDEX           => 0;
use constant NOMBRE_INDEX       => 1;
use constant CORREO_LOGIN_INDEX => 2;
use constant CLAVE_INDEX        => 3;
use constant ACTIVO_INDEX       => 4;
use constant ROL_INDEX          => 5;
use constant MIN_CAMPOS         => 6;

# 1. Obtener parámetros
my $id_url    = $q->param('id')    || '';
my $token_url = $q->param('token') || '';

# 2. Cabecera HTTP (solo aquí)
print $q->header(-type => 'text/html', -charset => 'UTF-8');

# 3. Validación de parámetros
unless ($id_url =~ /^\d+$/ && $token_url =~ /^[0-9a-fA-F]{32}$/) {
    mostrar_error(
        "Error de activaci&oacute;n",
        "Los par&aacute;metros de activaci&oacute;n son incorrectos. Por favor, revisa el enlace completo.",
        $q
    );
    exit;
}

# 4. Procesar archivo y activar si corresponde
my @registros;
my $registro_encontrado = 0;
my $registro_activado   = 0;

open(my $fh, '+<:encoding(UTF-8)', $archivo_datos)
    or return mostrar_error("Error de servidor", "No se puede acceder a la base de datos.", $q);

flock($fh, LOCK_EX)
    or return mostrar_error("Error de bloqueo", "No se pudo asegurar el archivo de datos.", $q);

# Preservar cabecera si existe
my $header = <$fh>;
push @registros, (defined $header ? ($header) : ());

while (my $linea = <$fh>) {
    chomp $linea;
    my @campos = split /!/, $linea, -1;

    unless (@campos >= MIN_CAMPOS) {
        push @registros, $linea;
        next;
    }

    my $registro_id = $campos[ID_INDEX] // '';

    if ($registro_id eq $id_url) {
        $registro_encontrado = 1;

        my $correo_encontrado = $campos[CORREO_LOGIN_INDEX] // '';
        my $token_esperado    = md5_hex($registro_id . $correo_encontrado);

        if ($token_url eq $token_esperado) {
            if ($campos[ACTIVO_INDEX] == 0) {
                $campos[ACTIVO_INDEX] = 1;    # Activar
                $registro_activado = 1;       # Activación exitosa
                $linea = join('!', @campos);
            } else {
                $registro_activado = 2;       # Ya estaba activado
            }
        } else {
            flock($fh, LOCK_UN);
            close($fh);
            mostrar_error("Error de seguridad", "Token de verificaci&oacute;n incorrecto. El enlace es inv&aacute;lido o ha expirado.", $q);
            exit;
        }
    }

    push @registros, $linea;
}

# 5. Reescritura si hubo cambios
if ($registro_encontrado && $registro_activado == 1) {
    seek $fh, 0, 0;
    truncate $fh, 0;
    print $fh join("\n", @registros);
    print $fh "\n" unless @registros && $registros[-1] =~ /\n$/;
}

flock($fh, LOCK_UN);
close($fh);

# 6. Respuesta al usuario
if ($registro_activado == 1) {
    mostrar_exito("&iexcl;Activaci&oacute;n exitosa!", "Tu cuenta ha sido verificada y activada. Ya puedes iniciar sesi&oacute;n.", $q);
} elsif ($registro_activado == 2) {
    mostrar_exito("Cuenta previamente activada", "Tu cuenta ya se hab&iacute;a verificado. Ya puedes iniciar sesi&oacute;n.", $q);
} else {
    mostrar_error("No encontrado", "No se encontr&oacute; un registro asociado a este enlace de activaci&oacute;n.", $q);
}

exit;

# --- Subrutinas de visualización ---

sub mostrar_error {
    my ($titulo, $mensaje, $q_obj) = @_;

    # Evitar cabecera duplicada (sub_header controla cabecera)
    render_header(
        usuario          => 'Invitado',
        titulo           => $titulo,
        ruta_logout      => 'index.html',
        show_nav_content => 0,
        skip_header      => 1
    );

    print <<HTML;
    <div class="container mt-5" style="max-width: 600px;">
      <div class="card border-0 shadow-lg rounded-4 overflow-hidden">
        <div class="bg-danger py-4 text-center">
            <i class="bi bi-x-circle text-white" style="font-size: 4rem;"></i>
        </div>
        <div class="card-body p-5 text-center">
            <h3 class="fw-bold mb-3">$titulo</h3>
            <p class="text-muted mb-4">$mensaje</p>
            <a href="../index.html" class="btn btn-medentia px-5">Volver al Portal</a>
        </div>
      </div>
    </div>
HTML

    render_footer();
}

sub mostrar_exito {
    my ($titulo, $mensaje, $q_obj) = @_;

    render_header(
        usuario          => 'Invitado',
        titulo           => $titulo,
        ruta_logout      => 'index.html',
        show_nav_content => 0,
        skip_header      => 1
    );

    print <<HTML;
    <div class="container mt-5" style="max-width: 600px;">
      <div class="card border-0 shadow-lg rounded-4 overflow-hidden">
        <div class="bg-med-teal py-4 text-center">
            <i class="bi bi-check-circle text-white" style="font-size: 4rem;"></i>
        </div>
        <div class="card-body p-5 text-center">
            <h3 class="fw-bold mb-3">$titulo</h3>
            <p class="text-muted mb-4">$mensaje</p>
            <a href="../index.html" class="btn btn-medentia px-5">Ir al Portal</a>
        </div>
      </div>
    </div>
HTML

    render_footer();
}

1;
