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

my $rol_sesion     = $sd->{role} || 'Invitado';
my $id_usuario     = $sd->{id_registro} // $sd->{id_usuario} // '';
my $id_medico_ses  = $sd->{id_medico} // '';
my $id_empresa     = $sd->{id_empresa} // '0';

my $campanas_file = "$FindBin::Bin/../dat/campanas_comunicacion.dat";
my @campanas = ();

if (-f $campanas_file) {
    open(my $fh, "<:encoding(UTF-8)", $campanas_file) or die "No se pudo leer campanas: $!";
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^\s*$/;
        my @c = split(/\|/, $line);
        next if @c < 13;

        my ($id_campana, $fecha, $hora, $id_rem, $usr_rem, $rol_rem, $negocio, $segmento, $asunto, $total, $ok_count, $fail_count, $estado) = @c;

        # Filtrado RBAC por Tenancy y Privacidad
        my $permitido = 0;
        if ($rol_sesion =~ /Administrador Global/i) {
            $permitido = 1; # Visibilidad completa
        } elsif ($rol_sesion =~ /Medico/i) {
            # Solo sus propias campañas
            $permitido = 1 if ($id_rem eq $id_usuario || $id_rem eq $id_medico_ses);
        } else {
            # Administrador de Organización / Personal: solo su clínica
            $permitido = 1 if ($negocio eq $id_empresa || $negocio =~ /^$id_empresa:/ || $id_empresa eq '0');
        }

        if ($permitido) {
            my $t = int($total || 0);
            my $ok = int($ok_count || 0);
            my $tasa = ($t > 0) ? int(($ok / $t) * 100) : 0;

            push @campanas, {
                id_campana => $id_campana,
                fecha      => $fecha,
                hora       => $hora,
                remitente  => "$usr_rem ($rol_rem)",
                segmento   => $segmento,
                asunto     => $asunto,
                total      => $t,
                enviados   => $ok,
                fallidos   => int($fail_count || 0),
                tasa_exito => "$tasa%",
                estado     => $estado
            };
        }
    }
    close($fh);
}

# Ordenar de la más reciente a la más antigua
@campanas = reverse @campanas;

print encode_json({
    ok       => 1,
    total    => scalar(@campanas),
    campanas => \@campanas
});
