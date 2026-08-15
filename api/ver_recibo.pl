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
    print $q->redirect(-uri => '../auth/login.pl');
    exit;
}

my $id_os = $q->param('id_os') || '';
unless ($id_os) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8', -status => '400 Bad Request');
    print "<h1>Error</h1><p>ID OS requerido para visualizar el recibo.</p>";
    exit;
}

my $file_pub = "$FindBin::Bin/../dat/folios_recibos_publicos.dat";
my $is_pub = 0;

if (-e $file_pub) {
    my $pub_data = leer_tabla($file_pub, '\|');
    for my $r (@$pub_data) {
        if ($r->[4] && $r->[4] eq $id_os) {
            $is_pub = 1;
            last;
        }
    }
}

if ($is_pub) {
    print $q->redirect(-uri => "imprimir_recibo_publico.pl?id_consulta=$id_os");
} else {
    print $q->redirect(-uri => "imprimir_recibo_caja.pl?id_consulta=$id_os");
}
1;
