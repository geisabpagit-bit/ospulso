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

my $id_campana = $q->param('id_campana') || '';
if (!$id_campana) {
    print encode_json({ ok => 0, msg => "Parámetro id_campana requerido" });
    exit;
}

my $campanas_file = "$FindBin::Bin/../dat/campanas_comunicacion.dat";
my $cola_file     = "$FindBin::Bin/../dat/cola_correos_masivos.dat";

my $campana_info = undef;

# 1. Obtener metadatos de la campaña
if (-f $campanas_file) {
    open(my $cfh, "<:encoding(UTF-8)", $campanas_file);
    my $header = <$cfh>;
    while (my $line = <$cfh>) {
        chomp($line);
        next if $line =~ /^\s*$/;
        my @c = split(/\|/, $line);
        if ($c[0] eq $id_campana) {
            $campana_info = {
                id_campana => $c[0],
                fecha      => $c[1],
                hora       => $c[2],
                remitente  => "$c[4] ($c[5])",
                segmento   => $c[7],
                asunto     => $c[8],
                total      => int($c[9] || 0),
                enviados   => int($c[10] || 0),
                fallidos   => int($c[11] || 0),
                estado     => $c[12]
            };
            last;
        }
    }
    close($cfh);
}

unless ($campana_info) {
    print encode_json({ ok => 0, msg => "Campaña no encontrada" });
    exit;
}

# 2. Leer destinatarios en cola asociados
my @destinatarios = ();
if (-f $cola_file) {
    open(my $qfh, "<:encoding(UTF-8)", $cola_file);
    my $q_header = <$qfh>;
    while (my $line = <$qfh>) {
        chomp($line);
        next if $line =~ /^\s*$/;
        my @f = split(/\|/, $line);
        if ($f[1] eq $id_campana) {
            push @destinatarios, {
                id_cola     => $f[0],
                email       => $f[2],
                nombre      => $f[3],
                tipo        => $f[4],
                estado      => $f[7],
                intentos    => int($f[8] || 0),
                fecha_envio => $f[9] || '',
                error_msg   => $f[10] || ''
            };
        }
    }
    close($qfh);
}

print encode_json({
    ok            => 1,
    campana       => $campana_info,
    total_items   => scalar(@destinatarios),
    destinatarios => \@destinatarios
});
