#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use File::Spec;
use FindBin;
use lib $FindBin::Bin . '/..';
require "$FindBin::Bin/../auth/check_session.pl";
use Fcntl qw(:flock);

my $q = CGI->new;
print $q->header(-type => 'application/json', -charset => 'UTF-8');

my $session_data = check_session();

# Capa 1: Seguridad RBAC y Tenant
if (!$session_data->{session_ok} || $session_data->{role} ne 'Administrador Organizacion') {
    print encode_json({ error => 1, msg => 'Acceso denegado. Se requiere nivel de administrador de organizacion.' });
    exit;
}

my $id_empresa = $session_data->{id_empresa} // '';
my $org_clues = '';
if ($id_empresa eq '0') {
    $org_clues = 'QTSMP000116';
} else {
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $n_file = File::Spec->catfile($dat_dir, 'negocios.dat');
    if (-e $n_file && open(my $nf, '<:encoding(UTF-8)', $n_file)) {
        <$nf>;
        while (my $line = <$nf>) {
            chomp $line; my @f = split(/\|/, $line, -1);
            if ($f[0] eq $id_empresa) { $org_clues = $f[18] // ''; last; }
        }
        close $nf;
    }
}

if (!$org_clues) {
    print encode_json({ error => 1, msg => 'El entorno no cuenta con un CLUE asignado para gestionar catalogos.' });
    exit;
}

my $action = $q->param('action') || 'list_files';
my $catalog_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'catalogos_CLUE', $org_clues);
my $global_dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');

# Whitelist de patrones permitidos (archivos especificos)
my @allowed_patterns = (
    qr/^empleadosmun_$org_clues\.dat$/,
    qr/^medicos_$org_clues\.dat$/,
    qr/^especialidades_$org_clues\.dat$/,
    qr/^pacientes_privados_$org_clues\.dat$/,
    qr/^contadores_recibos_privados_$org_clues\.dat$/,
    qr/^contadores_recibos_publicos_$org_clues\.dat$/
);

# Helper: Validar y resolver path seguro
sub get_safe_catalog_path {
    my ($filename) = @_;
    
    # Prevenir path traversal
    if ($filename =~ /\.\./ || $filename =~ /\// || $filename =~ /\\/) {
        return undef;
    }
    
    my $is_allowed = 0;
    foreach my $pattern (@allowed_patterns) {
        if ($filename =~ $pattern) {
            $is_allowed = 1;
            last;
        }
    }
    
    return undef unless $is_allowed;
    
    my $file_path = File::Spec->catfile($catalog_dir, $filename);
    
    return $file_path;
}

# Helper: Detectar delimitador de un archivo
sub detect_delimiter {
    my ($file_path) = @_;
    my $fh;
    if (!open($fh, '<:encoding(UTF-8)', $file_path)) {
        return '|'; # default
    }
    my $first_line = <$fh> || '';
    close($fh);
    
    my $pipes = () = $first_line =~ /\|/g;
    my $exclams = () = $first_line =~ /\!/g;
    
    return $exclams > $pipes ? '!' : '|';
}


if ($action eq 'list_files') {
    my @files = ();
    
    # Escanear catalog_dir
    if (opendir(my $dh, $catalog_dir)) {
        while (my $file = readdir($dh)) {
            next if $file =~ /^\./;
            my $path = get_safe_catalog_path($file);
            if ($path && -e $path) {
                push @files, $file;
            }
        }
        closedir($dh);
    }
    
    # Añadir explicitamente pacientes si existe
    my $pac_file = "pacientes_privados_${org_clues}.dat";
    if (get_safe_catalog_path($pac_file) && -e get_safe_catalog_path($pac_file)) {
        push @files, $pac_file;
    }
    
    print encode_json({ success => 1, files => \@files });
}
elsif ($action eq 'read') {
    my $filename = $q->param('filename');
    my $file_path = get_safe_catalog_path($filename);
    
    if (!$file_path || !-e $file_path) {
        print encode_json({ error => 1, msg => 'Archivo no permitido o inexistente.' });
        exit;
    }
    
    my $delim = detect_delimiter($file_path);
    my @headers = ();
    my @rows = ();
    
    if (open(my $fh, '<:encoding(UTF-8)', $file_path)) {
        my $first_line = <$fh>;
        if ($first_line) {
            chomp $first_line;
            @headers = split(/\Q$delim\E/, $first_line, -1);
        }
        
        while (my $line = <$fh>) {
            chomp $line;
            my @cols = split(/\Q$delim\E/, $line, -1);
            push @rows, \@cols;
        }
        close($fh);
    }
    
    print encode_json({ success => 1, headers => \@headers, rows => \@rows, delimiter => $delim });
}
elsif ($action eq 'save') {
    my $filename = $q->param('filename');
    my $file_path = get_safe_catalog_path($filename);
    
    if (!$file_path) {
        print encode_json({ error => 1, msg => 'Archivo no permitido.' });
        exit;
    }
    
    my $delim = detect_delimiter($file_path);
    my $data_json = $q->param('data'); # Array JSON con los valores
    my $row_data = decode_json($data_json);
    
    my $primary_id = $row_data->[0];
    if (!defined $primary_id || $primary_id eq '') {
        print encode_json({ error => 1, msg => 'El ID (Columna 0) es requerido.' });
        exit;
    }
    
    my $new_line = join($delim, @$row_data);
    
    if (!-e $file_path) {
        print encode_json({ error => 1, msg => 'Archivo no existe.' });
        exit;
    }
    
    # Read all, replace if id matches, otherwise append
    my @lines;
    my $header = '';
    my $found = 0;
    
    open(my $fh, '<:encoding(UTF-8)', $file_path) or do {
        print encode_json({ error => 1, msg => 'Error abriendo archivo para lectura.' });
        exit;
    };
    flock($fh, LOCK_SH);
    $header = <$fh> || '';
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split(/\Q$delim\E/, $line, -1);
        if (defined $cols[0] && $cols[0] eq $primary_id) {
            push @lines, $new_line;
            $found = 1;
        } else {
            push @lines, $line;
        }
    }
    close($fh);
    
    if (!$found) {
        push @lines, $new_line;
    }
    
    # Write back
    open(my $fhw, '>:encoding(UTF-8)', $file_path) or do {
        print encode_json({ error => 1, msg => 'Error abriendo archivo para escritura.' });
        exit;
    };
    flock($fhw, LOCK_EX);
    print $fhw $header;
    foreach my $l (@lines) {
        print $fhw "$l\n";
    }
    close($fhw);
    
    print encode_json({ success => 1, msg => 'Registro guardado exitosamente.', op => $found ? 'update' : 'insert' });
}
elsif ($action eq 'delete') {
    my $filename = $q->param('filename');
    my $file_path = get_safe_catalog_path($filename);
    
    if (!$file_path) {
        print encode_json({ error => 1, msg => 'Archivo no permitido.' });
        exit;
    }
    
    my $primary_id = $q->param('id');
    if (!defined $primary_id || $primary_id eq '') {
        print encode_json({ error => 1, msg => 'El ID (Columna 0) es requerido.' });
        exit;
    }
    
    my $delim = detect_delimiter($file_path);
    my @lines;
    my $header = '';
    my $found = 0;
    
    open(my $fh, '<:encoding(UTF-8)', $file_path) or do {
        print encode_json({ error => 1, msg => 'Error abriendo archivo para lectura.' });
        exit;
    };
    flock($fh, LOCK_SH);
    $header = <$fh> || '';
    while (my $line = <$fh>) {
        chomp $line;
        my @cols = split(/\Q$delim\E/, $line, -1);
        if (defined $cols[0] && $cols[0] eq $primary_id) {
            $found = 1;
            next; # Skip appending this line
        }
        push @lines, $line;
    }
    close($fh);
    
    if ($found) {
        open(my $fhw, '>:encoding(UTF-8)', $file_path) or do {
            print encode_json({ error => 1, msg => 'Error abriendo archivo para escritura.' });
            exit;
        };
        flock($fhw, LOCK_EX);
        print $fhw $header;
        foreach my $l (@lines) {
            print $fhw "$l\n";
        }
        close($fhw);
        print encode_json({ success => 1, msg => 'Registro eliminado exitosamente.' });
    } else {
        print encode_json({ error => 1, msg => 'Registro no encontrado.' });
    }
}
else {
    print encode_json({ error => 1, msg => 'Acción inválida.' });
}
