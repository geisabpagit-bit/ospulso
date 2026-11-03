#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON::PP;
use Encode qw(decode encode is_utf8);
use POSIX qw(strftime);
use FindBin;
use lib "$FindBin::Bin/..";

require "$FindBin::Bin/../auth/check_session.pl";

my $q = CGI->new;
my $sd = check_session();

print $q->header(-type => 'application/json', -charset => 'UTF-8');
binmode STDOUT, ":raw";

unless ($sd->{session_ok}) {
    print encode_json({ ok => 0, msg => "Sesión inválida o expirada" });
    exit;
}

sub limpiar_input_utf8 {
    my ($val) = @_;
    return '' unless defined $val;
    if (!is_utf8($val)) {
        eval { $val = decode('UTF-8', $val); };
    }
    if ($val =~ /[\xC2\xC3]/) {
        my $fixed = eval { decode('UTF-8', encode('ISO-8859-1', $val)) };
        $val = $fixed if ($fixed && !$@);
    }
    return $val;
}

my $asunto   = limpiar_input_utf8($q->param('asunto') || '');
my $cuerpo   = limpiar_input_utf8($q->param('cuerpo') || '');
my $segmento = limpiar_input_utf8($q->param('segmento') || '');

if (!$asunto || !$cuerpo || !$segmento) {
    print encode_json({ ok => 0, msg => "Parámetros incompletos (asunto, cuerpo y segmento son obligatorios)" });
    exit;
}

my $rol_sesion     = $sd->{role} || 'Staff';
my $usuario_sesion = $sd->{usuario} || 'Usuario';
my $id_usuario     = $sd->{id_registro} // $sd->{id_usuario} // '';
my $id_medico_ses  = $sd->{id_medico} // '';
my $id_empresa     = $sd->{id_empresa} // '0';

# Aplicar API-RBAC estricto
if ($rol_sesion =~ /Medico/i && $segmento ne 'mis_pacientes') {
    $segmento = 'mis_pacientes';
}

my $usuarios_file = "$FindBin::Bin/../dat/usuarios.dat";
my $pacientes_file = "$FindBin::Bin/../dat/pacientes.dat";
my $campanas_file = "$FindBin::Bin/../dat/campanas_comunicacion.dat";
my $cola_file     = "$FindBin::Bin/../dat/cola_correos_masivos.dat";

my @destinatarios = ();
my %emails_vistos = ();

sub es_email_valido {
    my ($email) = @_;
    return 0 unless defined $email;
    $email =~ s/^\s+|\s+$//g;
    return ($email =~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) ? 1 : 0;
}

# 1. Resolver Destinatarios
if ($segmento =~ /^todos_admin_org|ejecutivos_ventas|broadcast_plataforma|personal_clinica|solo_medicos|solo_recepcion$/) {
    if (-f $usuarios_file) {
        open(my $fh, "<:encoding(UTF-8)", $usuarios_file) or die "Error al abrir usuarios.dat: $!";
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^\s*$/;
            my @cols = split(/!/, $line);
            next if @cols < 7;
            my $id     = $cols[0] // '';
            my $nombre = $cols[1] // '';
            my $correo = lc($cols[2] // '');
            my $activo = $cols[4] // '0';
            my $rol    = $cols[5] // '';
            my $negocio = $cols[6] // '';

            next unless $activo eq '1';

            my $cumple = 0;
            if ($segmento eq 'todos_admin_org') {
                $cumple = 1 if $rol =~ /Administrador Organizacion/i;
            } elsif ($segmento eq 'ejecutivos_ventas') {
                $cumple = 1 if $rol =~ /Ejecutivo Ventas/i;
            } elsif ($segmento eq 'broadcast_plataforma') {
                $cumple = 1;
            } elsif ($segmento eq 'personal_clinica') {
                $cumple = 1 if ($negocio =~ /^$id_empresa:/ || $id_empresa eq '0');
            } elsif ($segmento eq 'solo_medicos') {
                $cumple = 1 if ($rol =~ /Medico/i && ($negocio =~ /^$id_empresa:/ || $id_empresa eq '0'));
            } elsif ($segmento eq 'solo_recepcion') {
                $cumple = 1 if ($rol =~ /Recepcionista/i && ($negocio =~ /^$id_empresa:/ || $id_empresa eq '0'));
            }

            if ($cumple && es_email_valido($correo) && !$emails_vistos{$correo}) {
                $emails_vistos{$correo} = 1;
                push @destinatarios, {
                    id     => $id,
                    nombre => $nombre,
                    email  => $correo,
                    tipo   => 'usuario'
                };
            }
        }
        close($fh);
    }
} elsif ($segmento =~ /^todos_pacientes_global|todos_pacientes_clinica|mis_pacientes$/) {
    if (-f $pacientes_file) {
        open(my $fh, "<:encoding(UTF-8)", $pacientes_file) or die "Error al abrir pacientes.dat: $!";
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^\s*$/;
            my @cols = split(/\|/, $line);
            next if @cols < 6;
            my $id_pac = $cols[0] // '';
            my $id_med = $cols[1] // '';
            my $nombre = $cols[2] // '';
            my $correo = lc($cols[5] // '');
            my $tenant = $cols[13] // '';

            my $cumple = 0;
            if ($segmento eq 'todos_pacientes_global') {
                $cumple = 1;
            } elsif ($segmento eq 'todos_pacientes_clinica') {
                $cumple = 1 if ($tenant =~ /^$id_empresa:/ || $id_empresa eq '0');
            } elsif ($segmento eq 'mis_pacientes') {
                $cumple = 1 if ($id_med eq $id_medico_ses || $id_med eq $id_usuario);
            }

            if ($cumple && es_email_valido($correo) && !$emails_vistos{$correo}) {
                $emails_vistos{$correo} = 1;
                push @destinatarios, {
                    id     => $id_pac,
                    nombre => $nombre,
                    email  => $correo,
                    tipo   => 'paciente'
                };
            }
        }
        close($fh);
    }
} elsif ($segmento eq 'individual_org') {
    my $custom_json = $q->param('destinatarios_custom') || '';
    if ($custom_json) {
        my $arr = eval { decode_json($custom_json) };
        if ($arr && ref($arr) eq 'ARRAY') {
            foreach my $item (@$arr) {
                my $e = lc(limpiar_input_utf8($item->{email} // ''));
                my $n = limpiar_input_utf8($item->{nombre} // $e);
                if (es_email_valido($e) && !$emails_vistos{$e}) {
                    $emails_vistos{$e} = 1;
                    push @destinatarios, {
                        id     => $item->{id} // 'INDIVIDUAL',
                        nombre => $n,
                        email  => $e,
                        tipo   => $item->{tipo} // 'individual'
                    };
                }
            }
        }
    }
    my $single_email  = lc(limpiar_input_utf8($q->param('email_individual') || ''));
    my $single_nombre = limpiar_input_utf8($q->param('nombre_individual') || $single_email);
    if ($single_email && es_email_valido($single_email) && !$emails_vistos{$single_email}) {
        $emails_vistos{$single_email} = 1;
        push @destinatarios, {
            id     => 'INDIVIDUAL',
            nombre => $single_nombre,
            email  => $single_email,
            tipo   => 'individual'
        };
    }
}

if (!@destinatarios) {
    print encode_json({ ok => 0, msg => "No se encontraron destinatarios válidos para el segmento seleccionado." });
    exit;
}

# 2. Generar IDs y Fechas
my $ahora_fecha = strftime("%Y-%m-%d", localtime);
my $ahora_hora  = strftime("%H:%M:%S", localtime);
my $id_campana  = "CMP_" . strftime("%Y%m%d%H%M%S", localtime) . "_" . int(rand(1000));
my $total = scalar(@destinatarios);

# 2.1 Procesar Archivos Adjuntos (Hasta 2 archivos, máximo 5 MB en total)
my @adjuntos_guardados = ();
my $peso_total_adjuntos = 0;
my $max_bytes = 5 * 1024 * 1024; # 5 MB

my $upload_dir_base = "$FindBin::Bin/../uploads/adjuntos_campanas";
unless (-d "$FindBin::Bin/../uploads") {
    mkdir("$FindBin::Bin/../uploads", 0777);
}
unless (-d $upload_dir_base) {
    mkdir($upload_dir_base, 0777);
}
my $campana_upload_dir = "$upload_dir_base/$id_campana";

# Buscar parámetros de adjuntos (adjunto_1, adjunto_2 o campo general)
my @upload_param_names = ('adjunto_1', 'adjunto_2', 'archivos', 'adjuntos');
my @file_handles_found = ();

foreach my $pname (@upload_param_names) {
    my @fhs = $q->upload($pname);
    foreach my $fh (@fhs) {
        push @file_handles_found, { fh => $fh, orig => $q->param($pname) } if $fh;
    }
}

if (@file_handles_found > 2) {
    print encode_json({ ok => 0, msg => "Se permite un máximo de 2 archivos adjuntos." });
    exit;
}

if (@file_handles_found > 0) {
    mkdir($campana_upload_dir, 0777) unless -d $campana_upload_dir;

    foreach my $item (@file_handles_found) {
        my $fh = $item->{fh};
        my $filename = $item->{orig} // '';
        # Limpiar nombre
        $filename =~ s/^.*[\\\/]//; # Quitar ruta de windows o unix
        $filename =~ s/[^\w\.\-\s]/_/g; # Caracteres seguros

        # Validar extensión permitida
        unless ($filename =~ /\.(jpe?g|png|webp|gif|pdf|docx?|txt|xlsx?|csv)$/i) {
            print encode_json({ ok => 0, msg => "El archivo '$filename' no tiene un formato permitido (Solo imágenes, documentos de texto y hojas de cálculo)." });
            exit;
        }

        my $target_path = "$campana_upload_dir/$filename";
        open(my $out_fh, ">:raw", $target_path) or die "No se pudo guardar adjunto $filename: $!";
        my $bytes_leidos = 0;
        my $buffer;
        while (my $bytes = read($fh, $buffer, 4096)) {
            $bytes_leidos += $bytes;
            $peso_total_adjuntos += $bytes;
            if ($peso_total_adjuntos > $max_bytes) {
                close($out_fh);
                unlink($target_path);
                print encode_json({ ok => 0, msg => "El peso total de los archivos adjuntos excede el límite máximo de 5 MB." });
                exit;
            }
            print $out_fh $buffer;
        }
        close($out_fh);
        push @adjuntos_guardados, $filename;
    }
}

my $adjuntos_str = join(";", @adjuntos_guardados);

# Sanitizar strings para evitar romper delimitadores flat-file
my $asunto_limpio = $asunto;
$asunto_limpio =~ s/\|/ /g;
$asunto_limpio =~ s/\n|\r/ /g;

my $cuerpo_encoded = $cuerpo;
$cuerpo_encoded =~ s/\|/&#124;/g;
$cuerpo_encoded =~ s/\r\n|\r|\n/<br>/g;

# 3. Guardar en campanas_comunicacion.dat (con adjuntos en columna 14)
open(my $cfh, ">>:encoding(UTF-8)", $campanas_file) or die "No se pudo abrir campanas_comunicacion.dat: $!";
print $cfh "$id_campana|$ahora_fecha|$ahora_hora|$id_usuario|$usuario_sesion|$rol_sesion|$id_empresa|$segmento|$asunto_limpio|$total|0|0|EN_PROCESO|$adjuntos_str\n";
close($cfh);

# 4. Encolar Destinatarios en cola_correos_masivos.dat
open(my $qfh, ">>:encoding(UTF-8)", $cola_file) or die "No se pudo abrir cola_correos_masivos.dat: $!";
my $item_num = 1;
foreach my $dst (@destinatarios) {
    my $id_cola = "${id_campana}_" . $item_num++;
    my $nombre_dst = limpiar_input_utf8($dst->{nombre} // '');
    $nombre_dst =~ s/\|/ /g;
    my $email_dst  = $dst->{email} // '';
    my $tipo_dst   = $dst->{tipo} // 'usuario';

    print $qfh "$id_cola|$id_campana|$email_dst|$nombre_dst|$tipo_dst|$asunto_limpio|$cuerpo_encoded|PENDIENTE|0||\n";
}
close($qfh);

print encode_json({
    ok         => 1,
    id_campana => $id_campana,
    total      => $total,
    adjuntos   => scalar(@adjuntos_guardados),
    msg        => "Campaña encolada exitosamente para $total destinatarios."
});
