#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json);
use Encode qw(decode_utf8);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $q = CGI->new;
my $sd = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($sd->{session_ok}) {
    print encode_json({ ok => JSON::false, msg => 'Sesión expirada' });
    exit;
}

my $q_str = $q->param('q') // '';
my $clues = $q->param('clues') // '';
$q_str =~ s/^\s+|\s+$//g;
$clues =~ s/^\s+|\s+$//g;
my $q_str_decoded = decode_utf8($q_str);

if ($q_str eq '') {
    print encode_json([]);
    exit;
}

my $sufijo = $clues ? "_${clues}" : "";
my $emp_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "empleadosmun${sufijo}.dat");

my @resultados = ();

if (-e $emp_file && open my $fh, '<:encoding(UTF-8)', $emp_file) {
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        
        my @f = split /!/, $line, -1;
        my $num_empleado = $f[0] // '';
        my $nombre       = $f[1] // '';
        my $relacion     = $f[2] // '';
        my $estatus      = $f[7] // '';
        
        if ($num_empleado eq $q_str || $nombre =~ /\Q$q_str_decoded\E/i) {
            push @resultados, {
                id => $num_empleado,
                text => "$nombre ($relacion) - Empleado #$num_empleado - Estatus: $estatus",
                nombre => $nombre,
                relacion => $relacion,
                telefono => $f[5] // '',
                correo => $f[6] // ''
            };
        }
    }
    close $fh;
}

print encode_json(\@resultados);
1;
