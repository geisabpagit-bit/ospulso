#!/usr/bin/perl
#!/usr/bin/perl
use strict;
use warnings;
use utf8;

binmode STDOUT, ":utf8";

# Archivos a limpiar con sus cabeceras
my %archivos = (
    "../dat/usuarios.dat"              => "id!nombre!correo!clave!activo!rol!extra\n",
    "../dat/pacientes.dat"             => "id_paciente!id_medico!nombre!curp!rfc!email!fecha_nac!sexo!ocupacion!estado_civil!nacionalidad!tipo_sangre!telefono\n",
    "../dat/citas.dat"                 => "id_cita|id_medico|id_paciente|fecha|hora_ini|hora_fin|motivo|notas|estado|event_id",
    "../dat/tokens_google.dat"         => "id_medico|refresh_token\n",
    "../dat/contador_registro_inicial.dat" => "1\n"   # contador reiniciado en 1
);

# Crear carpeta dat si no existe
# mkdir "dat" unless -d "dat";

foreach my $archivo (keys %archivos) {
    # Abrir en modo escritura, crea el archivo si no existe
    open my $fh, '>:encoding(UTF-8)', $archivo or die "No se pudo crear/limpiar $archivo: $!";
    print $fh $archivos{$archivo};   # escribe cabecera o contador inicial
    close $fh;
    print "✅ Archivo $archivo reiniciado con cabecera.\n";
}

print "\n🚀 Ambiente de prueba reiniciado. Todas las tablas tienen su cabecera y empiezan desde fila 1.\n";
