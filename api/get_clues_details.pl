#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use Encode qw(decode_utf8 encode_utf8);

my $q = CGI->new;
print $q->header('application/json; charset=UTF-8');

my $clues = $q->param('clues') || '';
$clues =~ s/^\s+|\s+$//g;

if (!$clues) {
    print encode_json({ success => 0, message => "Código CLUES no proporcionado." });
    exit;
}

my %details = (
    success  => 1,
    clues    => $clues,
    nombre   => '',
    comercial => '',
    vialidad => '',
    num_ext  => '',
    num_int  => '',
    colonia  => '',
    rfc_clues => '',
    telefono  => '',
    extension => '',
    latitud   => '',
    longitud  => '',
    servicios => [],
    horarios  => []
);

# 1. Leer CAT_CLUES.dat
if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_CLUES.dat')) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split /\|/, $line, -1;
        if ($cols[0] eq $clues) {
            $details{nombre}    = $cols[17] // '';
            $details{comercial} = $cols[18] // '';
            $details{vialidad}  = $cols[21] // '';
            $details{num_ext}   = $cols[22] // '';
            $details{num_int}   = $cols[23] // '';
            $details{colonia}   = $cols[26] // '';
            $details{rfc_clues} = $cols[31] // '';
            $details{telefono}  = $cols[32] // '';
            $details{extension} = $cols[33] // '';
            $details{latitud}   = $cols[59] // '';
            $details{longitud}  = $cols[60] // '';
            last;
        }
    }
    close($fh);
}

# 2. Leer CAT_SUBCLUES.dat
if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_SUBCLUES.dat')) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split /\|/, $line, -1;
        if ($cols[0] eq $clues) {
            push @{$details{servicios}}, {
                area      => $cols[3] // '',
                servicio  => $cols[5] // '',
                ubicacion => $cols[6] // '',
                dias      => $cols[7] // ''
            };
        }
    }
    close($fh);
}

# 3. Leer CAT_HORARIOS.dat
if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_HORARIOS.dat')) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split /\|/, $line, -1;
        if ($cols[0] eq $clues) {
            push @{$details{horarios}}, {
                domingo   => $cols[1] // '',
                lunes     => $cols[2] // '',
                martes    => $cols[3] // '',
                miercoles => $cols[4] // '',
                jueves    => $cols[5] // '',
                viernes   => $cols[6] // '',
                sabado    => $cols[7] // '',
                inicio    => $cols[8] // '',
                fin       => $cols[9] // ''
            };
        }
    }
    close($fh);
}

print encode_json(\%details);
1;
