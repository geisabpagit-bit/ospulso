#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use CGI;
use JSON::PP;
use Encode qw(decode_utf8);

my $q = CGI->new;
print $q->header('application/json; charset=UTF-8');

my $cp = $q->param('cp') || '';
$cp =~ s/^\s+|\s+$//g;

if ($cp !~ /^\d{5}$/) {
    print encode_json({ success => 0, message => "Código postal inválido." });
    exit;
}

my $c_estado = '';
my $c_mnpio  = '';
my %asentamientos_hash;

# 1. Buscar en CODIGO_POSTAL.dat
if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CODIGO_POSTAL.dat')) {
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split /\|/, $line;
        # d_codigo[0], d_asenta[1], c_estado[7], c_mnpio[11]
        if ($cols[0] eq $cp) {
            $c_estado = $cols[7] if !$c_estado;
            $c_mnpio  = $cols[11] if !$c_mnpio;
            my $asenta = $cols[1] // '';
            $asenta =~ s/^\s+|\s+$//g;
            $asentamientos_hash{$asenta} = 1 if $asenta;
        }
    }
    close($fh);
}

if (!$c_estado) {
    print encode_json({ success => 0, message => "Código postal no encontrado." });
    exit;
}

# Normalizar llaves para buscar en INEGI
$c_estado = sprintf("%02d", $c_estado);
$c_mnpio  = sprintf("%03d", $c_mnpio);

my $nombre_entidad = '';
my $nombre_municipio = '';

# 2. Buscar Entidad
if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_ENTIDADES.dat')) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split /\|/, $line;
        if ($cols[0] eq $c_estado) {
            $nombre_entidad = $cols[1];
            last;
        }
    }
    close($fh);
}

# 3. Buscar Municipio
if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_MUNICIPIOS.dat')) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split /\|/, $line;
        if ($cols[0] eq $c_estado && $cols[1] eq $c_mnpio) {
            $nombre_municipio = $cols[2];
            last;
        }
    }
    close($fh);
}

# 4. Buscar Localidades INEGI como fallback (Solo si no hubo colonias)
my $has_colonias = scalar(keys %asentamientos_hash);

if (!$has_colonias) {
    if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_LOCALIDADES.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @cols = split /\|/, $line;
            if ($cols[0] eq $c_estado && $cols[1] eq $c_mnpio) {
                my $loc = $cols[3] // '';
                $loc =~ s/^\s+|\s+$//g;
                $asentamientos_hash{$loc} = 1 if $loc;
            }
        }
        close($fh);
    }
}

my @asentamientos = sort keys %asentamientos_hash;

# 5. Buscar Establecimientos Oficiales (CLUES) por Código Postal
my @establecimientos = ();
if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_CLUES.dat')) {
    my $header = <$fh>; # Ignorar cabeceras
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split /\|/, $line, -1;
        # Índice 27 = CODIGO POSTAL, 0 = CLUES, 17 = NOMBRE DE LA UNIDAD, 62 = ULTIMO MOVIMIENTO
        if (defined $cols[27] && $cols[27] eq $cp) {
            my $ultimo_movimiento = $cols[62] // '';
            if ($ultimo_movimiento ne 'BAJA') {
                my $clues_id = $cols[0] // '';
                my $clues_nombre = $cols[17] // '';
                if ($clues_id && $clues_nombre) {
                    push @establecimientos, {
                        id     => $clues_id,
                        nombre => $clues_nombre
                    };
                }
            }
        }
    }
    close($fh);
}

my $response = {
    success          => 1,
    entidad          => $nombre_entidad,
    municipio        => $nombre_municipio,
    localidades      => \@asentamientos,
    establecimientos => \@establecimientos
};

print encode_json($response);
1;
