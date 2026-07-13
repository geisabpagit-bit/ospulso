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
    "../dat/citas.dat"                 => "id_cita|id_medico|id_paciente|fecha|hora_ini|hora_fin|motivo|notas|estado|event_id\n",
    "../dat/tokens_google.dat"         => "id_medico|refresh_token\n",
    "../dat/contador_registro_inicial.dat" => "1\n",   # contador reiniciado en 1
    "../dat/negocios.dat"              => "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud\n",
    "../dat/negocios_config.dat"       => "ID_NEGOCIO|CLAVE|VALOR\n",
    "../dat/cotizaciones.dat"          => "ID_COT|ID_PACIENTE|NOMBRE|TOTAL|FECHA|ID_MEDICO\n",
    "../dat/cotizaciones_items.dat"    => "ID_COT|CONCEPTO|PRECIO|CANTIDAD|SUBTOTAL\n",
    "../dat/gastos.dat"                => "ID_GASTO|CONCEPTO|MONTO|FECHA|CATEGORIA|SUBCATEGORIA|METODO_PAGO|ESTADO|COMPROBANTE|ID_MEDICO\n",
    "../dat/estado_cuenta.dat"         => "ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS\n",
    "../dat/consulta_draft.dat"        => "id_draft|id_paciente|id_cita|id_medico|current_step|payload_json|timestamp\n",
    "../dat/odontogramas.dat"          => "ID_PACIENTE|TIPO|FECHA|NOTAS|DATOS_FDI\n",
    "../dat/estudios.dat"              => "id_estudio|id_paciente|fecha|modalidad|descripcion|ruta|size\n",
    "../dat/historial_correos.dat"     => "TIMESTAMP|ID_PACIENTE|FECHA_CORREO|ASUNTO|TIPO|ADJUNTO\n",
    "../dat/tokens.dat"                => "id_medico!refresh_token\n",
    "../dat/facturacion.dat"           => ""
);

# Crear carpeta dat si no existe
# mkdir "dat" unless -d "dat";

foreach my $archivo (keys %archivos) {
    # Abrir en modo escritura, crea el archivo si no existe
    open my $fh, '>:encoding(UTF-8)', $archivo or die "No se pudo crear/limpiar $archivo: $!";
    print $fh $archivos{$archivo} if $archivos{$archivo};   # escribe cabecera o contador inicial
    close $fh;
    print "✅ Archivo $archivo reiniciado con cabecera.\n";
}

# 2. Borrar catálogos dinámicos (servicios_*.dat y productos_*.dat)
my @catalogos_dinamicos = glob("../dat/servicios_*.dat ../dat/productos_*.dat");
foreach my $cat (@catalogos_dinamicos) {
    unlink $cat or warn "No se pudo borrar $cat: $!";
    print "🗑️  Catálogo dinámico borrado: $cat\n";
}

# 3. Reiniciar archivos de contador (.counter) y similares
my @contadores = glob("../dat/*.counter");
push @contadores, "../dat/contador_pacientes.dat";

foreach my $contador (@contadores) {
    open my $fh, '>:encoding(UTF-8)', $contador or die "No se pudo reiniciar $contador: $!";
    print $fh "1\n";
    close $fh;
    print "🔢 Contador reiniciado: $contador\n";
}

print "\n🚀 Ambiente de prueba reiniciado. Todas las tablas tienen su cabecera y empiezan desde fila 1.\n";
