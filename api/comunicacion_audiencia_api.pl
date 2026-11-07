#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON::PP;
use Encode qw(decode encode is_utf8);
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

my $rol_sesion    = $sd->{role} || '';
my $id_usuario    = $sd->{id_registro} // $sd->{id_usuario} // '';
my $id_medico_ses = $sd->{id_medico} // '';
my $id_empresa    = $sd->{id_empresa} // '0';

my $segmento = $q->param('segmento') || 'default';

# Detección de Organización sin CLUE o Administrador único/Médico
my $sin_clue = 0;
my $admin_es_medico = 0;
my $clues_org = '';
my $id_matriz_org = '0';

if ($id_empresa && $id_empresa ne '0') {
    my $neg_file = "$FindBin::Bin/../dat/negocios.dat";
    if (-f $neg_file && open(my $fh_n, "<:encoding(UTF-8)", $neg_file)) {
        my @lineas_neg = <$fh_n>;
        close($fh_n);
        shift @lineas_neg;
        foreach my $line (@lineas_neg) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @cols = split(/\|/, $line);
            if ($cols[0] eq $id_empresa) {
                $clues_org = $cols[18] // '';
                $id_matriz_org = $cols[2] // '0';
                last;
            }
        }
        # Si es sucursal y no tiene CLUE propio, hereda de matriz
        if ((!$clues_org || $clues_org eq '0' || $clues_org =~ /^No\s*(asignada|aplica)$/i) && $id_matriz_org && $id_matriz_org ne '0') {
            foreach my $line (@lineas_neg) {
                chomp $line;
                next if $line =~ /^\s*$/;
                my @cols = split(/\|/, $line);
                if ($cols[0] eq $id_matriz_org) {
                    $clues_org = $cols[18] // '';
                    last;
                }
            }
        }
    }
    $clues_org =~ s/^\s+|\s+$//g;
    if (!$clues_org || $clues_org eq '0' || $clues_org =~ /^No\s*(asignada|aplica)$/i) {
        $sin_clue = 1;
    }

    # Detección precisa de consultorio individual (admin y médico es una sola persona sin colaboradores)
    my $usr_file = "$FindBin::Bin/../dat/usuarios.dat";
    if (-f $usr_file && open(my $fh_u, "<:encoding(UTF-8)", $usr_file)) {
        <$fh_u>;
        my $admin_es_dual = 0;
        my $colaboradores_org = 0;
        while (my $line = <$fh_u>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @cols = split(/!/, $line);
            next if @cols < 7;
            my $u_id     = $cols[0] // '';
            my $u_email  = lc($cols[2] // '');
            my $u_activo = $cols[4] // '0';
            my $u_rol    = $cols[5] // '';
            my $u_neg    = $cols[6] // '';
            my $u_ced    = $cols[9] // '';
            $u_ced =~ s/^\s+|\s+$//g;

            if ($u_neg =~ /^$id_empresa:/) {
                my $es_mismo_usuario = ($u_id eq $id_usuario || (defined $sd->{correo_login} && $u_email eq lc($sd->{correo_login})));
                if ($es_mismo_usuario) {
                    if ($u_rol =~ /Administrador/i && $u_rol =~ /Medico/i) {
                        $admin_es_dual = 1;
                    }
                } else {
                    if ($u_activo eq '1') {
                        $colaboradores_org++;
                    }
                }
            }
        }
        close($fh_u);
        if ($admin_es_dual && $colaboradores_org == 0) {
            $admin_es_medico = 1;
        }
    }
}

my $solo_pacientes = ($sin_clue || $admin_es_medico) ? 1 : 0;
$solo_pacientes = 0 if ($rol_sesion =~ /Administrador Global/i);

# Si la organización no tiene CLUE o admin es médico, reconducir cualquier segmento de personal a pacientes
if ($solo_pacientes && $segmento =~ /^personal_clinica|solo_medicos|solo_recepcion$/) {
    $segmento = 'todos_pacientes_clinica';
}

sub sanear_utf8 {
    my ($str) = @_;
    return '' unless defined $str;
    if ($str =~ /[\xC2\xC3]/) {
        my $fixed = eval { decode('UTF-8', encode('ISO-8859-1', $str)) };
        return $fixed if ($fixed && !$@);
    }
    return $str;
}

# Validación de Gobernanza RBAC en Backend (API-RBAC)
if ($rol_sesion =~ /Medico/i && $segmento ne 'mis_pacientes' && $segmento ne 'miembros_organizacion' && $segmento ne 'individual_org') {
    # El médico solo tiene permiso de consultar su propia cartera
    $segmento = 'mis_pacientes';
}

my $usuarios_file = "$FindBin::Bin/../dat/usuarios.dat";
my $pacientes_file = "$FindBin::Bin/../dat/pacientes.dat";

my @destinatarios = ();
my %emails_vistos = ();
my $invalidos = 0;

sub es_email_valido {
    my ($email) = @_;
    return 0 unless defined $email;
    $email =~ s/^\s+|\s+$//g;
    return ($email =~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) ? 1 : 0;
}

# --- Resolución según Segmento ---
if ($segmento =~ /^todos_admin_org|ejecutivos_ventas|broadcast_plataforma|personal_clinica|solo_medicos|solo_recepcion$/) {
    if (-f $usuarios_file) {
        open(my $fh, "<:encoding(UTF-8)", $usuarios_file) or die "Error al abrir usuarios.dat: $!";
        my $header = <$fh>; # saltar cabecera
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
                $cumple = 1; # Todos los usuarios del SaaS
            } elsif ($segmento eq 'personal_clinica') {
                $cumple = 1 if ($negocio =~ /^$id_empresa:/ || $id_empresa eq '0');
            } elsif ($segmento eq 'solo_medicos') {
                $cumple = 1 if ($rol =~ /Medico/i && ($negocio =~ /^$id_empresa:/ || $id_empresa eq '0'));
            } elsif ($segmento eq 'solo_recepcion') {
                $cumple = 1 if ($rol =~ /Recepcionista/i && ($negocio =~ /^$id_empresa:/ || $id_empresa eq '0'));
            }

            if ($cumple) {
                if (es_email_valido($correo)) {
                    unless ($emails_vistos{$correo}) {
                        $emails_vistos{$correo} = 1;
                        push @destinatarios, {
                            id     => $id,
                            nombre => $nombre,
                            email  => $correo,
                            tipo   => 'usuario',
                            rol    => $rol
                        };
                    }
                } else {
                    $invalidos++;
                }
            }
        }
        close($fh);
    }
} elsif ($segmento =~ /^todos_pacientes_global|todos_pacientes_clinica|mis_pacientes$/) {
    if (-f $pacientes_file) {
        open(my $fh, "<:encoding(UTF-8)", $pacientes_file) or die "Error al abrir pacientes.dat: $!";
        my $header = <$fh>; # saltar cabecera
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^\s*$/;
            my @cols = split(/\|/, $line);
            next if @cols < 6;
            my $id_pac    = $cols[0] // '';
            my $id_med    = $cols[1] // '';
            my $nombre    = $cols[2] // '';
            my $correo    = lc($cols[5] // '');
            my $tenant    = $cols[13] // '';

            my $cumple = 0;
            if ($segmento eq 'todos_pacientes_global') {
                $cumple = 1;
            } elsif ($segmento eq 'todos_pacientes_clinica') {
                $cumple = 1 if ($tenant =~ /^$id_empresa:/ || $id_empresa eq '0');
            } elsif ($segmento eq 'mis_pacientes') {
                $cumple = 1 if ($id_med eq $id_medico_ses || $id_med eq $id_usuario);
            }

            if ($cumple) {
                if (es_email_valido($correo)) {
                    unless ($emails_vistos{$correo}) {
                        $emails_vistos{$correo} = 1;
                        push @destinatarios, {
                            id     => $id_pac,
                            nombre => sanear_utf8($nombre),
                            email  => $correo,
                            tipo   => 'paciente'
                        };
                    }
                } else {
                    $invalidos++;
                }
            }
        }
        close($fh);
    }
} elsif ($segmento eq 'miembros_organizacion' || $segmento eq 'individual_org') {
    # 1. Personal y colaboradores de la organización (se omite si solo_pacientes está activo)
    if (!$solo_pacientes && -f $usuarios_file) {
        open(my $fh, "<:encoding(UTF-8)", $usuarios_file);
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^\s*$/;
            my @cols = split(/!/, $line);
            next if @cols < 7;
            my $id      = $cols[0] // '';
            my $nombre  = sanear_utf8($cols[1] // '');
            my $correo  = lc($cols[2] // '');
            my $activo  = $cols[4] // '0';
            my $rol     = $cols[5] // '';
            my $negocio = $cols[6] // '';

            next unless $activo eq '1';
            my $cumple = ($negocio =~ /^$id_empresa:/ || $id_empresa eq '0' || $rol_sesion =~ /Administrador Global/i);
            if ($cumple && es_email_valido($correo) && !$emails_vistos{$correo}) {
                $emails_vistos{$correo} = 1;
                push @destinatarios, {
                    id     => $id,
                    nombre => $nombre,
                    email  => $correo,
                    tipo   => "Personal ($rol)",
                    rol    => $rol
                };
            }
        }
        close($fh);
    }

    # 2. Pacientes de la organización
    if (-f $pacientes_file) {
        open(my $fh, "<:encoding(UTF-8)", $pacientes_file);
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^\s*$/;
            my @cols = split(/\|/, $line);
            next if @cols < 6;
            my $id_pac = $cols[0] // '';
            my $id_med = $cols[1] // '';
            my $nombre = sanear_utf8($cols[2] // '');
            my $correo = lc($cols[5] // '');
            my $tenant = $cols[13] // '';

            my $cumple = 0;
            if ($rol_sesion =~ /Medico/i) {
                $cumple = 1 if ($id_med eq $id_medico_ses || $id_med eq $id_usuario);
            } else {
                $cumple = 1 if ($tenant =~ /^$id_empresa:/ || $id_empresa eq '0' || $rol_sesion =~ /Administrador Global/i);
            }

            if ($cumple && es_email_valido($correo) && !$emails_vistos{$correo}) {
                $emails_vistos{$correo} = 1;
                push @destinatarios, {
                    id     => $id_pac,
                    nombre => $nombre,
                    email  => $correo,
                    tipo   => 'Paciente'
                };
            }
        }
        close($fh);
    }
}

print encode_json({
    ok                  => 1,
    segmento            => $segmento,
    total_destinatarios => scalar(@destinatarios),
    total_omitidos      => $invalidos,
    destinatarios       => \@destinatarios
});
