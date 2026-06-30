#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI '-utf8';
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(decode_json encode_json);
use lib '..';
use FindBin;
use File::Spec;

require '../auth/check_session.pl';

my $session_data = check_session();
unless ($session_data->{session_ok}) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print encode_json({ok => 0, msg => "Sesión caducada."});
    exit;
}

my $q = $session_data->{q} || CGI->new;
my $id_paciente = $q->param('id_paciente') || '';

if (!$id_paciente) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print encode_json({ok => 0, msg => "ID de paciente requerido."});
    exit;
}

my $estudios_dat = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
my @estudios;
if (-e $estudios_dat) {
    open(my $fh, '<:encoding(UTF-8)', $estudios_dat) or die "No se pudo abrir estudios.dat: $!";
    my $header = <$fh>; # Saltar cabecera
    while (my $line = <$fh>) {
        chomp $line;
        my ($id_est, $id_pac, $fecha, $mod, $desc, $ruta, $size) = split(/\|/, $line);
        if ($id_pac eq $id_paciente) {
            my $estudio_data = {
                id_estudio  => $id_est,
                fecha       => $fecha,
                modalidad   => $mod,
                descripcion => $desc,
                ruta        => $ruta,
                size        => $size,
                imagenes    => []
            };

            # Leer metadata.json si existe
            my $meta_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudiosRX', $id_paciente, $id_est, 'metadata.json');
            if (-e $meta_path) {
                if (open(my $mfh, '<', $meta_path)) {
                    local $/;
                    my $json_text = <$mfh>;
                    close $mfh;
                    eval {
                        my $meta = JSON->new->utf8(1)->decode($json_text);
                        if ($meta->{imagenes}) {
                            $estudio_data->{imagenes} = $meta->{imagenes};
                        }
                    };
                    if ($@) {
                        print STDERR "Warning: Failed to decode metadata.json for estudio $id_est: $@\n";
                    }
                }
            } else {
                # Fallback retrocompatibilidad: buscar archivos en la ruta
                if ($ruta && $ruta ne "-") {
                    my $abs_ruta = File::Spec->catfile($FindBin::Bin, '..', $ruta);
                    if (-d $abs_ruta) {
                        if (opendir(my $dh, $abs_ruta)) {
                            my @files = readdir($dh);
                            closedir $dh;
                            foreach my $file (@files) {
                                next if $file =~ /^\./; # saltar . y ..
                                next unless $file =~ /\.(dcm|jpg|jpeg|png)$/i;
                                push @{$estudio_data->{imagenes}}, {
                                    id_imagen => "img_$file",
                                    nombre_archivo => $file,
                                    ruta => "$ruta/$file",
                                    fecha_subida => $fecha
                                };
                            }
                        }
                    } else {
                        $estudio_data->{imagenes} = [{
                            id_imagen => 'img_legacy',
                            nombre_archivo => 'legacy_img',
                            ruta => $ruta,
                            fecha_subida => $fecha
                        }];
                    }
                }
            }

            push @estudios, $estudio_data;
        }
    }
    close $fh;
}

# Ordenar cronológicamente descendente
@estudios = sort { $b->{id_estudio} <=> $a->{id_estudio} } @estudios;

print "Content-Type: application/json; charset=UTF-8\n\n";
print encode_json({
    ok => 1,
    data => \@estudios
});
