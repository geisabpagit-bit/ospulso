#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON::PP;
use FindBin;
use lib "$FindBin::Bin/..";

require "$FindBin::Bin/../auth/check_session.pl";

my $q = CGI->new;
my $sd = check_session();

print $q->header(-type => 'application/json', -charset => 'UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ ok => 0, msg => "Sesión inválida o expirada" });
    exit;
}

my $rol_sesion    = $sd->{role} || '';
my $id_usuario    = $sd->{id_registro} // $sd->{id_usuario} // '';
my $id_medico_ses = $sd->{id_medico} // '';
my $id_empresa    = $sd->{id_empresa} // '0';

my $segmento = $q->param('segmento') || 'default';

# Validación de Gobernanza RBAC en Backend (API-RBAC)
if ($rol_sesion =~ /Medico/i && $segmento ne 'mis_pacientes') {
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
                            nombre => $nombre,
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
}

print encode_json({
    ok                  => 1,
    segmento            => $segmento,
    total_destinatarios => scalar(@destinatarios),
    total_omitidos      => $invalidos,
    destinatarios       => \@destinatarios
});
