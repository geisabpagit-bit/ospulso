package utils::db_manager;

use strict;
use warnings;
use utf8;
eval { require cPanelUserConfig; cPanelUserConfig->import; };
use Fcntl qw(:flock);
use Digest::SHA qw(sha256_hex);
use Exporter 'import';

our @EXPORT_OK = qw(
    obtener_usuarios
    autenticar_usuario
    guardar_registro
    leer_tabla
    actualizar_archivo
    obtener_nuevo_id
    eliminar_registro
    verificar_estado_negocio
);

use FindBin;
use File::Spec;

# Rutas Absolutas Basadas en FindBin (Protocolo 11.1)
my $USUARIOS_FILE = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');

use constant MIN_CAMPOS_USUARIO => 6;

# -------------------------------------------------------------------
# LECTURA GENÉRICA DE TABLA
# -------------------------------------------------------------------
sub leer_tabla {
    my ($archivo, $separador) = @_;
    $separador //= '\|'; # Por defecto (pacientes, citas usan '|')
    $separador = '!' if $archivo =~ /usuarios\.dat/ || $archivo =~ /tokens\.dat/;
    
    my @registros;
    return \@registros unless -e $archivo;

    open my $fh, '<:encoding(UTF-8)', $archivo or return \@registros;
    my $header = <$fh>; # Asumimos línea 1 como cabecera estricta
    
    while (my $linea = <$fh>) {
        chomp $linea;
        next if $linea =~ /^\s*$/;
        next if $linea =~ /^\s*#/; 
        
        my @campos = split /$separador/, $linea, -1;
        push @registros, \@campos;
    }
    close $fh;
    return \@registros;
}

# -------------------------------------------------------------------
# ESCRITURA GENÉRICA (SEGURO CON FLOCK)
# -------------------------------------------------------------------
sub guardar_registro {
    my ($archivo, $linea_string) = @_;
    open my $fh, '>>:encoding(UTF-8)', $archivo or die "No se pudo abrir $archivo para escribir: $!";
    flock($fh, LOCK_EX) or die "No se pudo bloquear el archivo $archivo: $!";
    print $fh "$linea_string\n";
    close $fh; 
    return 1;
}

sub actualizar_archivo {
    my ($archivo, $cabecera, $registros_str_array) = @_;
    open my $fh, '>:encoding(UTF-8)', $archivo or die "No se pudo abrir $archivo para reescribir: $!";
    flock($fh, LOCK_EX) or die "No se pudo bloquear el archivo $archivo: $!";
    print $fh "$cabecera\n" if defined $cabecera && $cabecera ne '';
    foreach my $linea (@$registros_str_array) {
        print $fh "$linea\n";
    }
    close $fh;
    return 1;
}

# -------------------------------------------------------------------
# CONTADOR AUTO-INCREMENTABLE SEGURO (CON FLOCK)
# -------------------------------------------------------------------
sub obtener_nuevo_id {
    my ($archivo) = @_;
    my $id = 1;
    open my $fh, '+<:encoding(UTF-8)', $archivo or do {
        # Si no existe, crearlo
        open my $fh_new, '>:encoding(UTF-8)', $archivo or die "No se pudo crear contador $archivo";
        print $fh_new "1\n";
        close $fh_new;
        return 1;
    };
    flock($fh, LOCK_EX) or die "No se pudo bloquear contador $archivo: $!";
    my $linea = <$fh>;
    chomp $linea if defined $linea;
    $id = $linea + 1 if defined $linea && $linea =~ /^\d+$/;
    
    seek($fh, 0, 0); # rebobinar
    truncate($fh, 0);
    print $fh "$id\n";
    close $fh;
    return $id;
}

# -------------------------------------------------------------------
# ELIMINAR REGISTRO POR ID (COLUMNA 0)
# -------------------------------------------------------------------
sub eliminar_registro {
    my ($archivo, $id_eliminar, $separador, $cabecera) = @_;
    $separador //= '\|';
    $cabecera //= '';

    open my $fh_in, '<:encoding(UTF-8)', $archivo or return 0;
    flock($fh_in, 1); # LOCK_SH = 1
    my @lineas = <$fh_in>;
    close $fh_in;

    my @nuevas;
    my $primera = 1;
    foreach my $linea (@lineas) {
        if ($primera && $cabecera ne '') {
            push @nuevas, $linea; # Mantener cabecera
            $primera = 0;
            next;
        }
        $primera = 0;
        my @campos = split /$separador/, $linea, -1;
        # Asumiendo que el ID siempre está en la primera columna
        chomp(my $col_id = $campos[0] // '');
        if ($col_id ne $id_eliminar) {
            push @nuevas, $linea;
        }
    }

    open my $fh_out, '>:encoding(UTF-8)', $archivo or return 0;
    flock($fh_out, 2); # LOCK_EX = 2
    print $fh_out @nuevas;
    close $fh_out;
    return 1;
}

# -------------------------------------------------------------------
# AUTENTICACIÓN (Migrado con soporte Multi-Tenant Empresa > Sucursal)
# Formato: id!nombre!correo!clave!activo!rol!extra
# extra = id_empresa:id_sucursal
# -------------------------------------------------------------------
sub autenticar_usuario {
    my ($correo_ingresado, $clave_ingresada) = @_;
    my $registros = leer_tabla($USUARIOS_FILE, '!');
    
    my $hash_ingresado = sha256_hex($clave_ingresada);

    foreach my $campos (@$registros) {
        next unless @$campos >= MIN_CAMPOS_USUARIO;
        
        my $correo = lc($campos->[2] // '');
        my $clave  = $campos->[3];
        
        if ($correo eq lc($correo_ingresado)) {
            if ($clave eq $hash_ingresado) {
                my $estado_activo = $campos->[4];
                if ($estado_activo == 1) {
                    
                    # Parsear futuro Multi-Tenant desde campo "extra"
                    my $extra = $campos->[6] // '';
                    my ($id_empresa, $id_sucursal) = split /:/, $extra;
                    $id_empresa //= ''; 
                    $id_sucursal //= '';
                    
                    my %data = (
                        id          => $campos->[0],
                        nombre      => $campos->[1],
                        correo      => $campos->[2],
                        rol         => $campos->[5],
                        id_empresa  => $id_empresa,
                        id_sucursal => $id_sucursal
                    );
                    return (1, "OK", \%data);
                } else {
                    return (0, "PENDIENTE", undef);
                }
            }
            last; # Contraseña incorrecta
        }
    }
    return (0, "Acceso Denegado", undef);
}

# -------------------------------------------------------------------
# VERIFICACIÓN DE ESTADO DE NEGOCIO (Automatización de Suscripción)
# -------------------------------------------------------------------
sub verificar_estado_negocio {
    my ($id_negocio) = @_;
    my $NEGOCIOS_FILE = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
    my $registros = leer_tabla($NEGOCIOS_FILE, '\|');
    
    use Time::Local;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $hoy_str = sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
    
    my $resultado = { activo => 0, tipo => 'Matriz', inicio => '', fin => '', expired => 0 };
    my $found = 0;
    my @nuevas_lineas;
    my $header = "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor";

    foreach my $campos (@$registros) {
        if ($campos->[0] eq $id_negocio) {
            $found = 1;
            $resultado->{tipo}   = ($campos->[2] == 0) ? 'Matriz' : 'Sucursal';
            $resultado->{inicio} = $campos->[4] // '';
            $resultado->{fin}    = $campos->[5] // '';
            $resultado->{activo} = $campos->[3];

            # Regla de Negocio: Autodesactivación por fecha
            if ($resultado->{fin} && $hoy_str gt $resultado->{fin}) {
                $resultado->{expired} = 1;
                if ($campos->[3] == 1) {
                    $campos->[3] = 0; # Desactivar en el archivo
                    $resultado->{activo} = 0;
                }
            }
        }
        push @nuevas_lineas, join('|', @$campos);
    }

    if ($found && $resultado->{expired}) {
        # Actualizar archivo si hubo cambio
        actualizar_archivo($NEGOCIOS_FILE, $header, \@nuevas_lineas);
    }

    return $resultado;
}

1;
