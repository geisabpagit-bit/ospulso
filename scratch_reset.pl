#!/usr/bin/perl
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';

my $dat_dir = "dat";

my %headers = (
    "usuarios.dat" => "ID!NOMBRE!CORREO!CLAVE!ACTIVO!ROL!EXTRA",
    "negocios.dat" => "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud",
    "pacientes.dat" => "ID_PACIENTE|ID_MEDICO|NOMBRE_COMPLETO|RFC|CURP|CORREO|FECHA_NACIMIENTO|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO",
    "citas.dat" => "ID_CITA|ID_MEDICO|ID_PACIENTE|FECHA|HORA_INICIO|HORA_FIN|TIPO_CONSULTA|NOTAS|ESTADO|EXTRA",
    "consulta_draft.dat" => "id_draft|id_paciente|id_cita|id_medico|current_step|payload_json|timestamp",
    "estado_cuenta.dat" => "ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS",
    "estudios.dat" => "id_estudio|id_paciente|fecha|modalidad|descripcion|ruta|size",
    "historial_correos.dat" => "TIMESTAMP|ID_PACIENTE|FECHA_CORREO|ASUNTO|TIPO|ADJUNTO",
    "odontogramas.dat" => "ID_PACIENTE|TIPO|FECHA|NOTAS|DATOS_FDI",
    "perfiles.dat" => "id!id_usuario!clave_formacion!clave_nacionalidad!clave_religion",
    "tokens.dat" => "id_medico!refresh_token",
    "tokens_google.dat" => "id_medico|refresh_token"
);

my @counters = (
    "contador_pacientes.dat",
    "contador_registro_inicial.dat",
    "abono_incremental.dat",
    "os_incremental.dat"
);

# 1. Reset tables with headers
foreach my $file (keys %headers) {
    my $path = "$dat_dir/$file";
    if (open(my $fh, '>:encoding(UTF-8)', $path)) {
        print $fh $headers{$file} . "\n";
        close($fh);
        print "Reseteado: $file\n";
    } else {
        print "Error abriendo $file: $!\n";
    }
}

# 2. Reset counters to 0
foreach my $file (@counters) {
    my $path = "$dat_dir/$file";
    if (open(my $fh, '>:encoding(UTF-8)', $path)) {
        print $fh "0\n";
        close($fh);
        print "Reseteado: $file a 0\n";
    } else {
        print "Error abriendo $file: $!\n";
    }
}

print "Todos los resets completados.\n";
