#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI '-utf8';
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(encode_json);
use File::Spec;
use FindBin;
use lib '..';

my $q = CGI->new;

print $q->header(-type => 'application/json', -charset => 'UTF-8');

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
my $session_data = check_session();
if (!$session_data->{session_ok}) {
    print encode_json({ ok => 0, msg => "Sesión caducada." });
    exit;
}

my $id_estudio = $q->param('id_estudio');
my $descripcion = $q->param('descripcion');

if (!$id_estudio || !$descripcion) {
    print encode_json({ ok => 0, msg => "Faltan datos (ID de estudio o nueva descripción)." });
    exit;
}

my $estudios_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
my @lineas = ();
my $encontrado = 0;

if (-e $estudios_dat) {
    open(my $in_fh, '<:encoding(UTF-8)', $estudios_dat);
    while(<$in_fh>) {
        chomp;
        my @cols = split(/\|/, $_);
        if ($cols[0] eq $id_estudio) {
            $encontrado = 1;
            $cols[4] = $descripcion; # Actualizar la descripción (índice 4 según dat/estudios.dat: id|id_paciente|fecha|modalidad|descripcion|ruta|size)
            push @lineas, join('|', @cols);
        } else {
            push @lineas, $_;
        }
    }
    close $in_fh;
}

if ($encontrado) {
    open(my $out_fh, '>:encoding(UTF-8)', $estudios_dat);
    foreach my $l (@lineas) {
        print $out_fh "$l\n";
    }
    close $out_fh;
    print encode_json({ ok => 1, msg => "Estudio actualizado correctamente." });
} else {
    print encode_json({ ok => 0, msg => "No se encontró el estudio." });
}
