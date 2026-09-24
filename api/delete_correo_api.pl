#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $q = CGI->new;
print $q->header(-type => 'application/json', -charset => 'UTF-8');

my $sd = check_session();
if (!$sd->{session_ok}) {
    print to_json({ status => 'error', message => 'No autorizado' });
    exit;
}

my $action = $q->param('action') || '';
my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'historial_correos.dat');

if ($action eq 'delete') {
    my $id_correo = $q->param('id_correo') || '';
    if (!$id_correo) {
        print to_json({ status => 'error', message => 'Falta id_correo' });
        exit;
    }

    my @lines;
    if (open(my $fh, "<:encoding(UTF-8)", $path)) {
        @lines = <$fh>;
        close $fh;
    }

    open(my $out, ">:encoding(UTF-8)", $path) or do {
        print to_json({ status => 'error', message => 'No se pudo escribir archivo' });
        exit;
    };
    
    my $deleted = 0;
    foreach my $line (@lines) {
        chomp $line;
        my @c = split(/\|/, $line);
        if ($c[0] eq $id_correo) {
            $deleted = 1;
        } else {
            print $out "$line\n";
        }
    }
    close $out;

    print to_json({ status => 'success', message => 'Correo eliminado', deleted => $deleted });
    exit;
} elsif ($action eq 'delete_all') {
    my $id_paciente = $q->param('id_paciente') || '';
    if (!$id_paciente) {
        print to_json({ status => 'error', message => 'Falta id_paciente' });
        exit;
    }

    my @lines;
    if (open(my $fh, "<:encoding(UTF-8)", $path)) {
        @lines = <$fh>;
        close $fh;
    }

    open(my $out, ">:encoding(UTF-8)", $path) or do {
        print to_json({ status => 'error', message => 'No se pudo escribir archivo' });
        exit;
    };
    
    my $deleted = 0;
    foreach my $line (@lines) {
        chomp $line;
        my @c = split(/\|/, $line);
        if ($c[1] eq $id_paciente) {
            $deleted++;
        } else {
            print $out "$line\n";
        }
    }
    close $out;

    print to_json({ status => 'success', message => "Se eliminaron $deleted correos." });
    exit;
} else {
    print to_json({ status => 'error', message => 'Acción inválida' });
    exit;
}
