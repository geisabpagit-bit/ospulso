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

my $id_empresa = $sd->{id_empresa} // '0';
if (!$clues) {
    my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
    if (-e $negocios_file && open(my $fn, '<:raw', $negocios_file)) {
        while(my $ln = <$fn>) {
            chomp($ln);
            my @f = split(/\|/, $ln, -1);
            my $row_id = $f[0] // '';
            $row_id =~ s/\x00//g; $row_id =~ s/^\s+|\s+$//g;
            if ($row_id eq $id_empresa || ($id_empresa eq '0' && ($row_id eq '0' || $row_id eq ''))) {
                my $c_val = $f[18] // '';
                $c_val =~ s/\x00//g; $c_val =~ s/^\s+|\s+$//g;
                $clues = $c_val if $c_val;
                last;
            }
        }
        close($fn);
    }
}

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
my $rutas = catalogo_org_utils::obtener_rutas_por_clue($clues);
my $emp_file = $rutas->{empleadosmun};
my $dep_file = $rutas->{dependencia};

my %dep_map = ();
if ($dep_file && -e $dep_file && open my $dfh, '<:encoding(UTF-8)', $dep_file) {
    while (my $dline = <$dfh>) {
        chomp $dline;
        next if $dline =~ /^\s*$/;
        my @df = split /!/, $dline, -1;
        if (defined $df[0] && length($df[0])) {
            $dep_map{$df[0]} = $df[1] // '';
        }
    }
    close $dfh;
}

my @resultados = ();
my $max_results = 50;

if ($emp_file && -e $emp_file && open my $fh, '<:encoding(UTF-8)', $emp_file) {
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        
        my @f = split /!/, $line, -1;
        my $num_empleado = $f[0] // '';
        my $nombre       = $f[1] // '';
        my $relacion     = $f[2] // '';
        my $id_dep       = $f[4] // '';
        my $telefono     = $f[5] // '';
        my $correo       = $f[6] // '';
        my $estatus      = $f[7] // '';
        
        # Omitir cabecera si existe
        next if $num_empleado =~ /^\$/;
        
        if ($num_empleado =~ /^\Q$q_str\E/i || $num_empleado eq $q_str || $nombre =~ /\Q$q_str_decoded\E/i) {
            my $nombre_dep = $dep_map{$id_dep} || ($id_dep ? "Dependencia #$id_dep" : "");
            push @resultados, {
                id => $num_empleado,
                text => "$nombre ($relacion) - Empleado #$num_empleado" . ($nombre_dep ? " - $nombre_dep" : "") . " - Estatus: $estatus",
                num_empleado   => $num_empleado,
                nombre         => $nombre,
                relacion       => $relacion,
                id_dependencia => $id_dep,
                dependencia    => $nombre_dep,
                telefono       => $telefono,
                correo         => $correo,
                estatus        => $estatus
            };
            last if scalar(@resultados) >= $max_results;
        }
    }
    close $fh;
}

print encode_json(\@resultados);
1;
