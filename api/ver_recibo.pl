#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib "$FindBin::Bin/..";
require "$FindBin::Bin/../auth/check_session.pl";
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $sd = check_session();
if (!$sd->{session_ok}) {
    print $q->redirect(-uri => '../index.html');
    exit;
}

my $id_os = $q->param('id_os') || '';
my $tipo  = $q->param('tipo')  || '';

unless ($id_os) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8', -status => '400 Bad Request');
    print "<h1>Error</h1><p>ID OS requerido para visualizar el recibo.</p>";
    exit;
}

if ($tipo eq 'publicos' || $tipo eq 'publico' || $tipo eq 'municipio') {
    print $q->redirect(-uri => "imprimir_recibo_publico.pl?id_consulta=$id_os");
    exit;
}

# 1. Resolver si el recibo es público o privado
my $file_pub = "$FindBin::Bin/../dat/folios_recibos_publicos.dat";
my $is_pub = 0;

if (-e $file_pub) {
    my $pub_data = leer_tabla($file_pub, '\|');
    for my $r (@$pub_data) {
        if (($r->[0] && $r->[0] eq $id_os) || ($r->[1] && $r->[1] eq $id_os) || ($r->[4] && $r->[4] eq $id_os)) {
            $is_pub = 1;
            last;
        }
    }
}

if ($is_pub) {
    print $q->redirect(-uri => "imprimir_recibo_publico.pl?id_consulta=$id_os");
    exit;
}

# 2. Si es privado, resolver si la organización es Consultorio Individual/Compartido o Institución CLUE
my $es_consultorio = 0;
my $id_negocio_rec = '';

my $file_priv = "$FindBin::Bin/../dat/folios_recibos_privados.dat";
if (-e $file_priv) {
    my $priv_data = leer_tabla($file_priv, '\|');
    for my $r (@$priv_data) {
        if (($r->[0] && $r->[0] eq $id_os) || ($r->[1] && $r->[1] eq $id_os) || ($r->[4] && $r->[4] eq $id_os)) {
            $id_negocio_rec = $r->[2] // '';
            last;
        }
    }
}
$id_negocio_rec ||= $sd->{id_empresa} // '';

if ($id_negocio_rec ne '') {
    my $cfg_file = "$FindBin::Bin/../dat/negocios_config.dat";
    if (-e $cfg_file && open(my $fh_cfg, '<:encoding(UTF-8)', $cfg_file)) {
        while (my $line = <$fh_cfg>) {
            $line =~ s/\R//g;
            next if $line =~ /^#|^\s*$/;
            my @f = split(/\|/, $line);
            if ($f[0] eq $id_negocio_rec && $f[1] eq 'TIPO_ORGANIZACION') {
                if ($f[2] && $f[2] =~ /Consultorio/i) {
                    $es_consultorio = 1;
                }
                last;
            }
        }
        close($fh_cfg);
    }
    
    # Si no tiene CLUE en negocios.dat, tratar como consultorio privado
    if (!$es_consultorio) {
        my $neg_file = "$FindBin::Bin/../dat/negocios.dat";
        if (-e $neg_file && open(my $fh_n, '<:encoding(UTF-8)', $neg_file)) {
            <$fh_n>;
            while (my $ln = <$fh_n>) {
                $ln =~ s/\x00//g;
                chomp $ln;
                my @n = split(/\|/, $ln, -1);
                if ($n[0] eq $id_negocio_rec) {
                    my $clue = $n[18] // '';
                    $clue =~ s/^\s+|\s+$//g;
                    if (!$clue || $clue eq '0') {
                        $es_consultorio = 1;
                    }
                    last;
                }
            }
            close($fh_n);
        }
    }
}

if ($es_consultorio) {
    print $q->redirect(-uri => "imprimir_recibo_caja_consultorio.pl?id_consulta=$id_os");
} else {
    print $q->redirect(-uri => "imprimir_recibo_caja.pl?id_consulta=$id_os");
}
1;
