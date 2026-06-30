#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(encode_json);
use File::Spec;
use File::Basename;
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
my $id_imagen = $q->param('id_imagen');

if (!$id_estudio || !$id_imagen) {
    print encode_json({ ok => 0, msg => "Faltan parametros (id_estudio, id_imagen)." });
    exit;
}

my $estudios_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
my $id_paciente = '';
if (-e $estudios_dat) {
    open(my $fh, '<:encoding(UTF-8)', $estudios_dat);
    my $header = <$fh>;
    while(<$fh>) {
        chomp;
        my @cols = split(/\|/, $_);
        if ($cols[0] eq $id_estudio) {
            $id_paciente = $cols[1];
            last;
        }
    }
    close $fh;
}

if (!$id_paciente) {
    print encode_json({ ok => 0, msg => "Estudio no encontrado." });
    exit;
}

my $meta_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudiosRX', $id_paciente, $id_estudio, 'metadata.json');
if (-e $meta_path) {
    open(my $fh, '<:encoding(UTF-8)', $meta_path);
    local $/;
    my $json_text = <$fh>;
    close $fh;

    my $meta = JSON->new->utf8(1)->decode($json_text);
    if ($meta->{imagenes}) {
        my $ruta_fisica = '';
        my @new_images = grep { 
            if ($_->{id_imagen} eq $id_imagen) {
                $ruta_fisica = $_->{ruta};
                0;
            } else {
                1;
            }
        } @{$meta->{imagenes}};
        
        if (scalar(@new_images) == scalar(@{$meta->{imagenes}})) {
             print encode_json({ ok => 0, msg => "Imagen no encontrada en el estudio." });
             exit;
        }
        
        $meta->{imagenes} = \@new_images;
        
        open(my $out_fh, '>:encoding(UTF-8)', $meta_path);
        print $out_fh JSON->new->utf8(1)->encode($meta);
        close $out_fh;
        
        if ($ruta_fisica) {
            my $abs_path = File::Spec->catfile($FindBin::Bin, '..', $ruta_fisica);
            if (-e $abs_path) {
                unlink($abs_path);
            }
            my $thumb_path = $abs_path . '.jpg';
            if (-e $thumb_path) {
                unlink($thumb_path);
            }
            my $thumb_png = $abs_path . '.png';
            if (-e $thumb_png) {
                unlink($thumb_png);
            }
        }
        
        print encode_json({ ok => 1, msg => "Imagen eliminada exitosamente." });
        exit;
    }
}

print encode_json({ ok => 0, msg => "No hay imagenes para este estudio." });
