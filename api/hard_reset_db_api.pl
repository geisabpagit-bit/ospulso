#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

# Seguridad estricta: Solo Administrador Global
if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Global') {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');

# Hash SHA-256 de "admin123"
my $admin_hash = "240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9";

# Hash SHA-256 de contraseñas de doctores (ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f)
my $doc_hash = "ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f";

my $usuarios_content = "id!nombre!correo!clave!activo!rol!ID_negocio!ID_ESPE!ID_SUBESPE!CEDULA!DOMICILIO!FIRMA_URL\n" .
"1!Administrador Global!admin\@ospulso.com!$admin_hash!1!Administrador Global!0:0!0!0!0!Clínica Principal!\n";

my $pacientes_content = "ID_PACIENTE|ID_MEDICO|NOMBRE|RFC|CURP|CORREO|FECHA_NAC|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO|TENANT\n";

my $ant_json = '{}';
my $ant_json2 = '{}';

my $pac_ant_content = "ID_PACIENTE|TUTOR|ANTECEDENTES_JSON|FECHA_ACTUALIZACION\n";

my %archivos = (
    'usuarios.dat' => $usuarios_content,
    'negocios.dat' => "ID|NOMBRE_NEGOCIO|ID_MATRIZ|Activo|inicio_suscripcion|fin_suscripcion|domicilio|telefono|contacto_email|logo_url|rfc|razon_social|id_tienda|id_vendedor|codigo_postal|entidad|municipio|colonia|clues|extension|latitud|longitud\n",
    'citas.dat' => "ID_CITA|ID_MEDICO|ID_PACIENTE|FECHA|HORA_INICIO|HORA_FIN|TIPO_CONSULTA|NOTAS|ESTADO|EXTRA\n",
    'pacientes.dat' => $pacientes_content,
    'pacientes_antecedentes.dat' => $pac_ant_content,
    'pacientes_domicilio.dat' => "ID_PACIENTE|CALLE|NUM_EXT|NUM_INT|COLONIA|MUNICIPIO|ESTADO|CP\n",
    'tratamientos.dat' => "ID_TRATAMIENTO|ID_PACIENTE|ID_COT|ESTADO|FECHA_INICIO|FECHA_FIN|ID_MEDICO|TOTAL|ID_CITA\n",
    'estado_cuenta.dat' => "ID_OS|ID_MOVIMIENTO|ID_PACIENTE|TIPO|CONCEPTO|MONTO_BASE|IVA|TOTAL|FECHA|ID_MEDICO|NOTAS|ALIAS\n",
    'gastos.dat' => "ID_GASTO|CONCEPTO|MONTO|FECHA|CATEGORIA|SUBCATEGORIA|METODO_PAGO|ESTADO|COMPROBANTE|ID_MEDICO\n",
    'negocios_config.dat' => "ID_NEGOCIO|CLAVE|VALOR\n",
    'cotizaciones.dat' => "ID_COT|ID_PACIENTE|NOMBRE|TOTAL|FECHA|ID_MEDICO\n",
    'cotizaciones_items.dat' => "ID_COT|CONCEPTO|PRECIO|CANTIDAD|SUBTOTAL\n",
    'consultas_clinicas.dat' => "id_consulta|id_paciente|id_cita|id_medico|timestamp|payload_json\n",
    'recetas.dat' => "id_receta|id_consulta|id_paciente|id_medico|fecha|folio|diagnostico|payload_json\n",
    'consentimientos.dat' => "id_consentimiento|id_consulta|id_paciente|id_medico|fecha|procedimiento|payload_json\n",
    'consulta_draft.dat' => "id_draft|id_paciente|id_cita|id_medico|current_step|payload_json|timestamp\n",
    'odontogramas.dat' => "ID_PACIENTE|TIPO|FECHA|NOTAS|DATOS_FDI\n",
    'estudios.dat' => "id_estudio|id_paciente|fecha|modalidad|descripcion|ruta|size\n",
    'folios_recibos_privados.dat' => "ID_RECIBO|FOLIO|ID_NEGOCIO|ID_SUCURSAL|ID_CONSULTA|ID_PACIENTE|FECHA|HORA|TOTAL_CARGOS|TOTAL_ABONOS|METODO_PAGO|ELABORADO_POR\n",
    'contadores_recibos_privados.dat' => "ID_NEGOCIO|ID_SUCURSAL|LAST_FOLIO\n",
    'folios_recibos_publicos.dat' => "ID_RECIBO|FOLIO|ID_NEGOCIO|ID_SUCURSAL|ID_CONSULTA|ID_PACIENTE|FECHA|HORA|TOTAL_CARGOS|TOTAL_ABONOS|METODO_PAGO|ELABORADO_POR\n",
    'contadores_recibos_publicos.dat' => "ID_NEGOCIO|ID_SUCURSAL|LAST_FOLIO\n",
    'categorias.dat' => "id|nombre|desc\n",
    'sub_categoria.dat' => "id|id_cat|nombre|desc\n",
    'sub_categoria_nivel3.dat' => "id|id_subcat|nombre\n",
    'agenda_config.dat' => "ID_MEDICO|CONFIG_JSON\n",
    'historial_correos.dat' => "TIMESTAMP|ID_PACIENTE|FECHA_CORREO|ASUNTO|TIPO|ADJUNTO\n",
    'tokens_google.dat' => "id_medico|refresh_token\n",
    'tokens.dat' => "id_medico!refresh_token\n",
    'facturacion.dat' => "\n",
    'perfiles.dat' => "id!id_usuario!clave_formacion!clave_nacionalidad!clave_religion\n",
    'id_cat.counter' => "0\n",
    'id_subcat.counter' => "0\n",
    'id_subcat3.counter' => "0\n",
    'id_gasto.counter' => "0\n",
    'contador_pacientes.dat' => "0\n",
    'contador_registro_inicial.dat' => "0\n",
    'abono_incremental.dat' => "0\n",
    'os_incremental.dat' => "0\n"
);

eval {
    use Fcntl qw(:flock);
    
    # 1. Resetear tablas estáticas definidas en el hash
    foreach my $archivo (keys %archivos) {
        my $ruta = File::Spec->catfile($dir, $archivo);
        open(my $fh, '>:utf8', $ruta) or die "Error abriendo $archivo: $!";
        flock($fh, 2);
        print $fh $archivos{$archivo};
        close($fh);
    }

    # 2. Borrar catálogos dinámicos generados por la organización y archivos temporales
    my @catalogos_dinamicos = glob(File::Spec->catfile($dir, "servicios_*.dat"));
    push @catalogos_dinamicos, glob(File::Spec->catfile($dir, "productos_*.dat"));
    push @catalogos_dinamicos, glob(File::Spec->catfile($dir, "agenda_config_medico_*.dat"));
    push @catalogos_dinamicos, glob(File::Spec->catfile($dir, "consultas_privado.dat"));
    push @catalogos_dinamicos, glob(File::Spec->catfile($dir, "consultas_bd.dat"));
    push @catalogos_dinamicos, glob(File::Spec->catfile($dir, "estudios.txt"));
    push @catalogos_dinamicos, glob(File::Spec->catfile($dir, "estudios2.dat"));
    
    foreach my $cat (@catalogos_dinamicos) {
        if (-e $cat) {
            unlink $cat;
        }
    }

    # 3. Limpiar carpetas de adjuntos, estudios RX, facturas, firmas y descargas
    limpiar_directorio(File::Spec->catdir($dir, "adjuntos_crm"));
    limpiar_directorio(File::Spec->catdir($dir, "estudiosRX"));
    limpiar_directorio(File::Spec->catdir($FindBin::Bin, '..', 'uploads', 'firmas'));
    limpiar_directorio(File::Spec->catdir($FindBin::Bin, '..', 'uploads', 'facturas'));
    limpiar_directorio(File::Spec->catdir($FindBin::Bin, '..', 'uploads', 'estudios'));
};

sub limpiar_directorio {
    my ($dir_path) = @_;
    return unless -d $dir_path;
    
    require File::Path;
    opendir(my $dh, $dir_path) or return;
    while (my $entry = readdir($dh)) {
        next if $entry eq '.' || $entry eq '..';
        my $full_path = File::Spec->catdir($dir_path, $entry);
        if (-d $full_path) {
            File::Path::remove_tree($full_path);
        } else {
            unlink $full_path;
        }
    }
    closedir($dh);
}

if ($@) {
    print encode_json({ status => 'error', message => "Error en reseteo: $@" });
    exit;
}

print encode_json({ status => 'success', message => 'Base de datos operativa reiniciada correctamente junto con catálogos dinámicos y archivos adjuntos.' });
1;
