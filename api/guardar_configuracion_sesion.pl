#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/..";
use CGI;
use JSON;
use Fcntl qw(:flock);
use File::Spec;

BEGIN {
    $ENV{TZ} = 'America/Mexico_City';
}
use POSIX qw(tzset);
eval { tzset(); };

require "$FindBin::Bin/../auth/check_session.pl";

my $q = CGI->new;
my $session_data = main::check_session();

print $q->header(-type => 'application/json', -charset => 'utf-8');

if (!$session_data || $session_data->{role} ne 'Administrador Global') {
    print encode_json({ status => 'error', message => 'Acceso denegado. Se requiere nivel Administrador Global.' });
    exit;
}

my $timeout = $q->param('timeout');
if (!defined $timeout || $timeout !~ /^\d+$/ || $timeout < 1) {
    print encode_json({ status => 'error', message => 'El límite de tiempo debe ser un número entero válido mayor a 0.' });
    exit;
}

my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
my @lines;
my $found = 0;

eval {
    # Si no existe, lo creamos
    if (!-e $config_file) {
        open(my $fh_new, '>:utf8', $config_file);
        print $fh_new "ID_NEGOCIO|CLAVE|VALOR\n";
        close($fh_new);
    }

    open(my $fh, '+<:utf8', $config_file) or die "No se pudo abrir $config_file: $!";
    flock($fh, LOCK_EX) or die "No se pudo bloquear el archivo de configuración";
    
    @lines = <$fh>;
    seek($fh, 0, 0);
    truncate($fh, 0);
    
    foreach my $line (@lines) {
        chomp($line);
        next if $line =~ /^\s*$/;
        my @cols = split(/\|/, $line);
        
        # Buscar la clave global
        if (defined $cols[0] && $cols[0] eq '0' && defined $cols[1] && $cols[1] eq 'GLOBAL_SESSION_TIMEOUT') {
            print $fh "0|GLOBAL_SESSION_TIMEOUT|$timeout\n";
            $found = 1;
        } else {
            print $fh "$line\n";
        }
    }
    
    if (!$found) {
        print $fh "0|GLOBAL_SESSION_TIMEOUT|$timeout\n";
    }
    
    flock($fh, LOCK_UN);
    close($fh);
};

if ($@) {
    print encode_json({ status => 'error', message => "Error del Servidor (Protocolo 500 Guard): $@" });
} else {
    print encode_json({ status => 'success', message => 'Configuración de inactividad guardada correctamente.' });
}
