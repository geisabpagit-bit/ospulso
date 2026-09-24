#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(encode_json);
use File::Spec;
use File::Path qw(remove_tree);
use FindBin;
use lib '..';

my $q = CGI->new;

print $q->header(-type => 'application/json', -charset => 'UTF-8');

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
my $session_data = check_session();
if (!$session_data->{session_ok}) {
    print encode_json({ ok => 0, msg => "Sesion caducada." });
    exit;
}

my $id_estudio = $q->param('id_estudio');

if (!$id_estudio) {
    print encode_json({ ok => 0, msg => "Falta ID de estudio." });
    exit;
}

my $estudios_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
my @lineas = ();
my $encontrado = 0;
my $id_paciente = '';

if (-e $estudios_dat) {
    open(my $in_fh, '<:encoding(UTF-8)', $estudios_dat);
    while(<$in_fh>) {
        chomp;
        my @cols = split(/\|/, $_);
        if ($cols[0] eq $id_estudio) {
            $encontrado = 1;
            $id_paciente = $cols[1];
            next;
        }
        push @lineas, $_;
    }
    close $in_fh;
}

if ($encontrado) {
    open(my $out_fh, '>:encoding(UTF-8)', $estudios_dat);
    foreach my $l (@lineas) {
        print $out_fh "$l\n";
    }
    close $out_fh;
    
    if ($id_paciente) {
        my $dir_fisico = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'estudiosRX', $id_paciente, $id_estudio);
        if (-d $dir_fisico) {
            remove_tree($dir_fisico);
        }
    }
    
    print encode_json({ ok => 1, msg => "Estudio y archivos eliminados correctamente." });
} else {
    print encode_json({ ok => 0, msg => "No se encontro el estudio." });
}
