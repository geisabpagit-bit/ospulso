package utils::audit_manager;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use POSIX qw(strftime);
use Fcntl qw(:flock);
use FindBin;
use File::Spec;

our @EXPORT_OK = qw(log_audit);

my $AUDIT_FILE = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'audit_logs.dat');

sub log_audit {
    my ($modulo, $accion, $descripcion, $id_registro, $id_usuario) = @_;
    
    $modulo //= 'Desconocido';
    $accion //= 'Desconocida';
    $descripcion //= '';
    $id_registro //= '';
    $id_usuario //= 'Sistema';
    
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    
    # Sanitizar para evitar saltos de línea y pipes
    $descripcion =~ s/\|/ - /g;
    $descripcion =~ s/\r?\n/ /g;
    
    my $linea = join('|', $timestamp, $id_usuario, $modulo, $accion, $id_registro, $descripcion);
    
    open my $fh, '>>:encoding(UTF-8)', $AUDIT_FILE or do {
        warn "No se pudo abrir $AUDIT_FILE: $!";
        return 0;
    };
    
    flock($fh, LOCK_EX);
    print $fh "$linea\n";
    close $fh;
    
    return 1;
}

1;
