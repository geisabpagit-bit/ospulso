#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON::PP;
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

my $rol_sesion     = $sd->{role} || 'Invitado';
my $id_usuario     = $sd->{id_registro} // $sd->{id_usuario} // '';
my $id_medico_ses  = $sd->{id_medico} // '';
my $id_empresa     = $sd->{id_empresa} // '0';

# Gobernanza RBAC: Se requiere rol administrativo o médico para operar su historial
if ($rol_sesion =~ /Paciente/i) {
    print encode_json({ ok => 0, msg => "No cuenta con permisos para limpiar el historial." });
    exit;
}

my $campanas_file = "$FindBin::Bin/../dat/campanas_comunicacion.dat";
my $cola_file     = "$FindBin::Bin/../dat/cola_correos_masivos.dat";

my %campanas_a_borrar = ();
my $campanas_eliminadas = 0;

# 1. Procesar campanas_comunicacion.dat según Tenancy RBAC
if (-f $campanas_file) {
    open(my $cfh, "<:encoding(UTF-8)", $campanas_file) or die "No se pudo leer campanas: $!";
    my $header_cmp = <$cfh>;
    my @nuevas_campanas = ($header_cmp);

    while (my $line = <$cfh>) {
        chomp($line);
        next if $line =~ /^\s*$/;
        my @c = split(/\|/, $line);
        next if @c < 13;

        my ($id_campana, $fecha, $hora, $id_rem, $usr_rem, $rol_rem, $negocio) = @c;

        my $eliminar = 0;
        if ($rol_sesion =~ /Administrador Global/i) {
            $eliminar = 1; # Global borra todo el histórico
        } elsif ($rol_sesion =~ /Medico/i) {
            $eliminar = 1 if ($id_rem eq $id_usuario || $id_rem eq $id_medico_ses);
        } else {
            # Administrador de Organización / Personal de Clínica
            $eliminar = 1 if ($negocio eq $id_empresa || $negocio =~ /^$id_empresa:/ || $id_empresa eq '0');
        }

        if ($eliminar) {
            $campanas_a_borrar{$id_campana} = 1;
            $campanas_eliminadas++;
        } else {
            push @nuevas_campanas, "$line\n";
        }
    }
    close($cfh);

    # Reescribir campanas_comunicacion.dat
    open(my $wcfh, ">:encoding(UTF-8)", $campanas_file) or die "No se pudo escribir campanas: $!";
    print $wcfh @nuevas_campanas;
    close($wcfh);
}

# 2. Purgar destinatarios asociados en cola_correos_masivos.dat
my $destinatarios_purgados = 0;
if (-f $cola_file && keys %campanas_a_borrar) {
    open(my $qfh, "<:encoding(UTF-8)", $cola_file) or die "No se pudo leer cola: $!";
    my $header_cola = <$qfh>;
    my @nuevas_colas = ($header_cola);

    while (my $qline = <$qfh>) {
        chomp($qline);
        next if $qline =~ /^\s*$/;
        my @qf = split(/\|/, $qline);
        my $cmp_id = $qf[1] // '';

        if ($campanas_a_borrar{$cmp_id}) {
            $destinatarios_purgados++;
        } else {
            push @nuevas_colas, "$qline\n";
        }
    }
    close($qfh);

    # Reescribir cola_correos_masivos.dat
    open(my $wqfh, ">:encoding(UTF-8)", $cola_file) or die "No se pudo escribir cola: $!";
    print $wqfh @nuevas_colas;
    close($wqfh);
}

print encode_json({
    ok                      => 1,
    msg                     => "Historial de campañas y destinatarios purgado exitosamente.",
    campanas_eliminadas     => $campanas_eliminadas,
    destinatarios_purgados => $destinatarios_purgados
});
