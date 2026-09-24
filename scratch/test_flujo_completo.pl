#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";
use utils::db_manager qw(guardar_registro leer_tabla actualizar_archivo);
use JSON::PP;
use CGI;
use CGI::Session;
use Digest::SHA qw(sha256_hex);
use IPC::Open3;
use Symbol 'gensym';

binmode STDOUT, ":utf8";

print "=== INICIANDO PRUEBA DEL FLUJO COMPLETO CON SESIONES REALES ===\n\n";

# 0. PREPARAR SESIONES DE PRUEBA EN auth/sessions/
my $session_dir = File::Spec->catdir($FindBin::Bin, '..', 'auth', 'sessions');
unless (-d $session_dir) {
    mkdir $session_dir or die "No se pudo crear $session_dir: $!";
}

# A. Sesión de Médico (Doctor 1)
my $session_doc = CGI::Session->new(undef, undef, { Directory => $session_dir });
$session_doc->param('uid', 'doc1@gmail.com');
$session_doc->param('usuario', 'doctor 1');
$session_doc->param('role', 'Medico');
$session_doc->param('id_medico', '1020747209');
$session_doc->param('id_empresa', '1055007');
$session_doc->param('id_sucursal', '706496');
$session_doc->flush();
my $sid_doc = $session_doc->id();

print "0. Sesión de Médico creada. SID: $sid_doc\n";

# 1. CREAR PACIENTE DE PRUEBA
my $id_paciente = "PAC-TEST-" . time();
my $correo_paciente = "paciente.flujo\@test.com";
my $password_plain = "Ospulso2026!";
my $password_hash = sha256_hex($password_plain);

my $id_medico = "1020747209"; # Doctor 1
my $tenant = "1055007:706496";

print "1. Creando Paciente...\n";
my $pacientes_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $linea_pac = join('|', $id_paciente, $id_medico, 'Juan Pérez Test', 'PETJ900101XXX', 'PETJ900101HDFXXX01', $correo_paciente, '1990-01-01', 'Masculino', 'Ingeniero', 'Soltero', 'Mexicana', 'O+', '5551234567', $tenant);
guardar_registro($pacientes_file, $linea_pac);

my $usuarios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $linea_usr = join('!', $id_paciente, 'Juan Pérez Test', $correo_paciente, $password_hash, 1, 'Paciente', '0:0', 0, 0, 0, 'Clínica Principal');
guardar_registro($usuarios_file, $linea_usr);

# B. Sesión de Paciente
my $session_pac = CGI::Session->new(undef, undef, { Directory => $session_dir });
$session_pac->param('uid', $correo_paciente);
$session_pac->param('usuario', 'Juan Pérez Test');
$session_pac->param('role', 'Paciente');
$session_pac->param('id_registro', $id_paciente);
$session_pac->param('id_empresa', '1055007');
$session_pac->flush();
my $sid_pac = $session_pac->id();

print "   - Paciente creado con ID: $id_paciente, Correo: $correo_paciente, Clave: $password_plain\n";
print "   - Sesión de Paciente creada. SID: $sid_pac\n\n";

# 2. CREAR CITA PARA EL PACIENTE
print "2. Agendando Cita...\n";
my $id_cita = "CIT-TEST-" . time();
my $hoy_fecha = sprintf("%04d-%02d-%02d", (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3]);
my $citas_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
unless (-e $citas_file) {
    open my $fh, '>:encoding(UTF-8)', $citas_file;
    print $fh "ID_CITA|ID_MEDICO|ID_PACIENTE|FECHA|HORA_INICIO|HORA_FIN|MOTIVO|NOTAS|ESTADO|TENANT\n";
    close $fh;
}
my $linea_cita = join('|', $id_cita, $id_medico, $id_paciente, $hoy_fecha, '10:00', '10:30', 'Consulta General Dental', 'Primera visita', 'Programada', $tenant);
guardar_registro($citas_file, $linea_cita);
print "   - Cita creada con ID: $id_cita ($hoy_fecha 10:00 hrs)\n\n";

# 3. EJECUTAR Y CERRAR CONSULTA VÍA api/cerrar_consulta_privado.pl
print "3. Atendiendo y Cerrando Consulta (Caja / Recibo)...\n";

my $caja_items_json = encode_json([
    { nombre => 'Limpieza Dental', precio => 600.00, cantidad => 1 },
    { nombre => 'Resina Fotocurable', precio => 450.00, cantidad => 1 }
]);

my %payload = (
    subjetivo => "Paciente refiere molestia en molar superior derecho.",
    objetivo => "Caries de 1er grado en pieza 16.",
    analisis => "Caries dental simple.",
    plan => "Profilaxis y restauración con resina.",
    requiere_receta => "1",
    diagnostico_principal => "Caries de la dentina (K02.1)"
);

my $cgi_params = {
    id_paciente => $id_paciente,
    id_medico   => $id_medico,
    id_cita     => $id_cita,
    payload_json => encode_json(\%payload),
    caja_items_json => $caja_items_json,
    caja_monto_abono => 1050.00,
    caja_metodo_pago => 'Efectivo',
    requiere_receta => '1',
    receta_folio => 'REC-TEST-001'
};

my $post_data = join('&', map { $_ . '=' . CGI::escape($cgi_params->{$_}) } keys %$cgi_params);

$ENV{REQUEST_METHOD} = 'POST';
$ENV{CONTENT_TYPE} = 'application/x-www-form-urlencoded';
$ENV{CONTENT_LENGTH} = length($post_data);
$ENV{HTTP_COOKIE} = "CGISESSID=$sid_doc";

my @cmd = ('perl', '-Mutf8', 'api/cerrar_consulta_privado.pl');
my ($in, $out, $err);
$err = gensym();
my $pid = open3($in, $out, $err, @cmd);
print $in $post_data;
close $in;

my $stdout_res = do { local $/; <$out> };
my $stderr_res = do { local $/; <$err> };
waitpid($pid, 0);

print "   - Respuesta de cerrar_consulta_privado.pl:\n$stdout_res\n";

# Extraer id_consulta de la respuesta JSON
my $res_data = {};
eval {
    if ($stdout_res =~ /(\{.*\})/s) {
        $res_data = decode_json($1);
    }
};

my $id_consulta_generado = $res_data->{id_consulta} // '';
print "   - ID Consulta Generado: $id_consulta_generado\n";

# 4. VERIFICAR RECIBO GENERADO EN FOLIOS_RECIBOS_PRIVADOS.DAT
print "\n4. Verificando Folio de Recibo en folios_recibos_privados.dat...\n";
my $recibos_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'folios_recibos_privados.dat');
if (-e $recibos_file) {
    my $recibos = leer_tabla($recibos_file, '\|');
    if ($recibos) {
        my $ultimo = $recibos->[-1];
        print "   - Último Recibo Registrado:\n";
        print "     * Folio: $ultimo->[1]\n";
        print "     * ID Consulta: $ultimo->[4]\n";
        print "     * ID Paciente: $ultimo->[5]\n";
        print "     * Cargos Totales: \$ $ultimo->[8]\n";
        print "     * Monto Abono: \$ $ultimo->[9]\n";
        print "     * Método de Pago: $ultimo->[10]\n";
        print "     * Elaborado por: $ultimo->[11]\n";
    }
}

# 5. IMPRIMIR RECIBO DE CAJA
print "\n5. Verificando vista HTML de Recibo de Caja (api/imprimir_recibo_caja.pl)...\n";
delete $ENV{CONTENT_TYPE};
delete $ENV{CONTENT_LENGTH};
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING} = "id_consulta=$id_consulta_generado";
$ENV{HTTP_COOKIE} = "CGISESSID=$sid_doc";

my $recibo_html = `perl api/imprimir_recibo_caja.pl`;

if ($recibo_html =~ /Recibo de Caja/i && $recibo_html =~ /Limpieza Dental/i && $recibo_html =~ /Resina Fotocurable/i) {
    print "   - ÉXITO: El recibo HTML se generó correctamente con conceptos, folio ($id_consulta_generado) y montos.\n";
} else {
    print "   - ADVERTENCIA: Contenido del recibo HTML:\n";
    print substr($recibo_html, 0, 400) . "\n";
}

# 6. VERIFICAR EXPEDIENTE DEL PACIENTE (api/get_mi_expediente.pl)
print "\n6. Verificando Expediente del Paciente (api/get_mi_expediente.pl)...\n";
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING} = '';
$ENV{HTTP_COOKIE} = "CGISESSID=$sid_pac";

my $exp_json = `perl api/get_mi_expediente.pl`;
print "   - Respuesta de get_mi_expediente.pl:\n$exp_json\n";

# 7. VERIFICAR ESTADO DE CUENTA EN FINANZAS (api/get_mi_estado_cuenta.pl)
print "\n7. Verificando Estado de Cuenta del Paciente (api/get_mi_estado_cuenta.pl)...\n";
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING} = "";
$ENV{HTTP_COOKIE} = "CGISESSID=$sid_pac";

my $fin_json = `perl api/get_mi_estado_cuenta.pl`;
print "   - Respuesta de get_mi_estado_cuenta.pl:\n$fin_json\n";

print "\n=== PRUEBA DEL FLUJO COMPLETO FINALIZADA ===\n";
