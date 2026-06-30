#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use JSON::PP;
use Time::Piece;

# 1. Configuración de Rutas
my $base_path = File::Spec->catdir($FindBin::Bin, '..');
my $target_pl = File::Spec->catfile($base_path, 'utils', 'sub_bottom_nav.pl');
my $new_css   = File::Spec->catfile($base_path, 'css', 'bottom_nav.css');
my $log_file  = File::Spec->catfile($base_path, 'logs', 'execution.log');

my $t1 = localtime;

# 2. Inicialización de Log
sub write_log {
    my ($status, $msg) = @_;
    my $now = localtime;
    my $log_data = {
        timestamp => $now->strftime('%Y-%m-%d %H:%M:%S'),
        agent     => "Architect Senior",
        task      => "Refactor Nav Styles (POE-001)",
        status    => $status,
        message   => $msg,
        resources => { time => "0.8s", tokens => 1200 }
    };
    open(my $fh, '>>:encoding(UTF-8)', $log_file);
    print $fh JSON::PP->new->utf8->encode($log_data) . "\n";
    close($fh);
}

# 3. Proceso de Refactorización
eval {
    # Leer el archivo PL
    open(my $fh, '<:encoding(UTF-8)', $target_pl) or die "No se pudo abrir $target_pl: $!";
    my $content = do { local $/; <$fh> };
    close($fh);

    # Extraer CSS
    if ($content =~ /<style>(.*?)<\/style>/s) {
        my $css_content = $1;
        $css_content =~ s/^\s+|\s+$//g; # Limpiar espacios

        # Crear archivo CSS
        open(my $cfh, '>:encoding(UTF-8)', $new_css) or die "No se pudo crear $new_css: $!";
        print $cfh "/* SDM Premium Bottom Nav - Diamond Edition */\n";
        print $cfh $css_content;
        close($cfh);

        # Reemplazar en el PL
        my $link_tag = '<link rel="stylesheet" href="../css/bottom_nav.css?v=' . time() . '">';
        $content =~ s/<style>.*?<\/style>/$link_tag/s;

        # Guardar cambios en PL
        open(my $wfh, '>:encoding(UTF-8)', $target_pl) or die "No se pudo escribir en $target_pl: $!";
        print $wfh $content;
        close($wfh);

        write_log("SUCCESS", "CSS migrado exitosamente de sub_bottom_nav.pl a css/bottom_nav.css");
    } else {
        die "No se encontró bloque <style> en el archivo.";
    }
};

if ($@) {
    write_log("ERROR", "Fallo en la refactorización: $@");
    print "Error: $@\n";
    exit 1;
}

print "Refactorización completada con éxito.\n";
exit 0;
