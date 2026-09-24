#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use File::Spec;
use FindBin;

my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
opendir(my $dh, $dat_dir) or die "Cannot open $dat_dir: $!";
my @files = sort readdir($dh);
closedir($dh);

print "=== REPORTE DE DISCREPANCIAS ENTRE CABECERAS Y REGISTROS EN DAT ===\n\n";

foreach my $file (@files) {
    next unless $file =~ /\.dat$/;
    my $filepath = File::Spec->catfile($dat_dir, $file);
    next unless -f $filepath;
    
    open(my $fh, "<:encoding(UTF-8)", $filepath) or next;
    my @lines = <$fh>;
    close($fh);
    
    next unless @lines;
    
    my $header_raw = $lines[0];
    chomp $header_raw;
    $header_raw =~ s/\r//g;
    
    my $delim = ($header_raw =~ /!/) ? '!' : '\|';
    my @header_cols = split(/$delim/, $header_raw, -1);
    my $num_header_cols = scalar(@header_cols);
    
    my %discrepancies;
    my $total_data_rows = 0;
    
    for (my $i = 1; $i < scalar(@lines); $i++) {
        my $line = $lines[$i];
        chomp $line;
        $line =~ s/\r//g;
        next if $line =~ /^\s*$/;
        next if $line =~ /^#/; # Omitir líneas de comentario
        
        $total_data_rows++;
        my @row_cols = split(/$delim/, $line, -1);
        my $cnt = scalar(@row_cols);
        if ($cnt != $num_header_cols) {
            $discrepancies{$cnt}++;
        }
    }
    
    if (%discrepancies || $lines[0] =~ /^\s*#/) {
        print "--------------------------------------------------\n";
        print "ARCHIVO: $file (Delim: '$delim')\n";
        print "Cabecera (Línea 1, Cols: $num_header_cols): $header_raw\n";
        if (%discrepancies) {
            print "DISCREPANCIAS DETECTADAS ($total_data_rows registros de datos reales):\n";
            foreach my $cnt (sort keys %discrepancies) {
                print "  - Con $cnt columnas: $discrepancies{$cnt} registros (Diferencia: " . ($cnt - $num_header_cols) . " cols)\n";
            }
        }
        if ($lines[0] =~ /^\s*#/) {
            print "ADVERTENCIA: La primera línea es un COMENTARIO (#) en lugar de una cabecera de columnas puras!\n";
        }
        if (scalar(@lines) > 1) {
            my $sample_data = $lines[1];
            chomp $sample_data;
            $sample_data =~ s/\r//g;
            my @sc = split(/$delim/, $sample_data, -1);
            print "Línea 2 Ejemplo (" . scalar(@sc) . " cols): $sample_data\n";
        }
    }
}

print "\n=== FIN DEL REPORTE ===\n";
