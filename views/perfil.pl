#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use Encode qw(decode_utf8);
use lib '..';
binmode(STDOUT, ":encoding(UTF-8)");
use utils::db_manager qw(leer_tabla verificar_estado_negocio);

# --- Declaraciones de Subrutinas ---
sub render_header;
sub render_footer;
sub render_edita_perfil; 
sub render_error_sesion; 

# --- Carga de Módulos ---
require '../auth/check_session.pl';
require '../utils/sub_header.pl';
require '../utils/sub_footer.pl';
require '../utils/sub_edita_perfil.pl';
require '../utils/render_error_sesion.pl';

# --- 1. Validar Sesión y Obtener Datos ---
my $session_data = check_session();
my $q               = $session_data->{q};
my $session_ok      = $session_data->{session_ok};
my $usuario         = $session_data->{usuario};
my $role            = $session_data->{role};
my $correo_login    = $session_data->{correo_login};
my $nombre_completo = $session_data->{nombre_completo};

# Recuperar arreglo del buscador si viene por parámetros
my @busqueda = $q->param('busqueda');

print $q->header('text/html; charset=UTF-8');

if ($session_ok) {
    # 2. Carga de Datos Extendida (Usuario + Negocio)
    my $user_data = {};
    my $biz_data  = {};
    
    # Buscar Usuario en usuarios.dat
    if (open(my $fh, '<:encoding(UTF-8)', '../dat/usuarios.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /!/, $line, -1;
            my $c_email = lc($c[2] // '');
            $c_email =~ s/^\s+|\s+$//g; # Trim corregido
            
            my $target_email = lc($correo_login // '');
            $target_email =~ s/^\s+|\s+$//g; # Trim corregido

            if ($c_email eq $target_email) {
                $user_data = {
                    id         => $c[0],
                    nombre     => $c[1],
                    correo     => $c[2],
                    activo     => $c[4],
                    rol        => $c[5],
                    id_negocio => $c[6]
                };
                last;
            }
        }
        close($fh);
    }

    # Buscar Negocio en negocios.dat
    if ($user_data->{id_negocio} && open(my $fh, '<:encoding(UTF-8)', '../dat/negocios.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /\|/, $line, -1; # negocios.dat usa pipe |
            if ($c[0] eq $user_data->{id_negocio}) {
                $biz_data = {
                    id            => $c[0],
                    nombre        => $c[1],
                    domicilio     => $c[6],
                    telefono      => $c[7],
                    email_negocio => $c[8],
                    rfc           => $c[10],
                    razon_social  => $c[11],
                    codigo_postal => $c[14] // '',
                    entidad       => $c[15] // '',
                    municipio     => $c[16] // '',
                    colonia       => $c[17] // '',
                    clues         => $c[18] // '',
                    extension     => $c[19] // '0',
                    latitud       => $c[20] // '',
                    longitud      => $c[21] // ''
                };
                last;
            }
        }
        close($fh);
    }

    # Buscar Datos de Paciente (Si aplica)
    if ($role eq 'Paciente' && open(my $fh, '<:encoding(UTF-8)', '../dat/pacientes.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /\|/, $line, -1; # pacientes.dat usa pipe |
            if ($c[5] eq $correo_login) { # Indice 5 es CORREO
                $biz_data = { # Reutilizamos biz_data como contenedor de ficha para el paciente
                    id_paciente  => $c[0],
                    nombre       => $c[2],
                    rfc          => $c[3],
                    curp         => $c[4],
                    email        => $c[5],
                    f_nac        => $c[6],
                    sexo         => $c[7],
                    ocupacion    => $c[8],
                    e_civil      => $c[9],
                    nacionalidad => $c[10],
                    tipo_sangre  => $c[11],
                    telefono     => $c[12]
                };
                last;
            }
        }
        close($fh);
    }

    # Buscar Datos de Perfil Adicional (perfiles.dat)
    my $perfil_data = { clave_formacion => '', clave_nacionalidad => '', clave_religion => '' };
    if ($user_data->{id} && open(my $fh, '<:encoding(UTF-8)', '../dat/perfiles.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /!/, $line, -1;
            if ($c[1] && $c[1] eq $user_data->{id}) {
                $perfil_data->{clave_formacion} = $c[2] // '';
                $perfil_data->{clave_nacionalidad} = $c[3] // '';
                $perfil_data->{clave_religion} = $c[4] // '';
                last;
            }
        }
        close($fh);
    }

    # Cargar CAT_FORMACION para los dropdowns
    my @cat_formacion = ();
    if ($role ne 'Paciente' && open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_FORMACION.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /!/, $line, -1;
            push @cat_formacion, {
                clave      => $c[0],
                formacion  => $c[1],
                agrupacion => $c[2],
                grado      => $c[3]
            } if @c >= 3;
        }
        close($fh);
        
        # Ordenar alfabéticamente por nombre de la formación
        @cat_formacion = sort { $a->{formacion} cmp $b->{formacion} } @cat_formacion;
    }

    # Cargar CAT_RELIGION para los dropdowns
    my @cat_religion = ();
    if ($role ne 'Paciente' && open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_RELIGION.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /!/, $line, -1;
            push @cat_religion, {
                clave_credo => $c[0],
                credo       => $c[1],
                clave_grupo => $c[2],
                grupo       => $c[3],
                clave_denom => $c[4],
                denom       => $c[5],
                clave       => $c[6],
                religion    => $c[7]
            } if @c >= 8;
        }
        close($fh);
        @cat_religion = sort { $a->{religion} cmp $b->{religion} } @cat_religion;
    }

    # Cargar CAT_NACIONALIDADES para los dropdowns
    my @cat_nacionalidades = ();
    if ($role ne 'Paciente' && open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_NACIONALIDADES.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @c = split /!/, $line, -1;
            push @cat_nacionalidades, {
                codigo_pais => $c[0],
                pais        => $c[1],
                clave       => $c[2]
            } if @c >= 3;
        }
        close($fh);
        @cat_nacionalidades = sort { $a->{pais} cmp $b->{pais} } @cat_nacionalidades;
    }

    # Verificar Estado y Suscripción del Negocio
    my $biz_status = {};
    if ($user_data->{id_negocio}) {
        $biz_status = verificar_estado_negocio($user_data->{id_negocio});
    }

    render_header(
        usuario     => $usuario,
        titulo      => "Mi Perfil - $usuario",
        ruta_logout => '../auth/cerrar_sesion.pl',
        role        => $role,
        skip_header => 1 
    );

    render_edita_perfil(
        user_data          => $user_data,
        biz_data           => $biz_data,
        biz_status         => $biz_status,
        perfil_data        => $perfil_data,
        cat_formacion      => \@cat_formacion,
        cat_religion       => \@cat_religion,
        cat_nacionalidades => \@cat_nacionalidades,
        role               => $role,
        correo_sesion      => $correo_login,
        busqueda           => \@busqueda
    );

    render_footer();
} else {
    render_error_sesion(); 
}

1;