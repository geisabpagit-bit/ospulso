#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use JSON::PP;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use FindBin;
use File::Spec;
use File::Basename;
use File::Find;
use File::Copy;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";

# --- Carga de Subrutinas y Módulos ---
sub render_header;
sub render_footer;
sub render_bottom_nav;
sub get_dat_tree;

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');

# --- Validar sesión y obtener datos ---
my $session_data = check_session();
my $q          = $session_data->{q};
my $session_ok = $session_data->{session_ok};
my $usuario    = $session_data->{usuario};
my $role       = $session_data->{role};

# --- Validar Rol de Administrador Global ---
if (!$session_ok || $role ne 'Administrador Global') {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    render_header(usuario => 'Invitado', titulo => 'Acceso Denegado', ruta_logout => '../index.html', show_nav_content => 0);
    print <<HTML;
<div class="container d-flex justify-content-center align-items-center" style="min-height: 80vh;">
  <div class="card-medentia p-5 text-center border-danger border-opacity-50 shadow-lg animate__animated animate__shakeX" style="max-width: 500px; width: 100%;">
    <div class="bg-danger bg-opacity-10 text-danger rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style="width: 80px; height: 80px;">
      <i class="bi bi-shield-slash fs-1"></i>
    </div>
    <h4 class="fw-bold text-dark mb-3">Acceso Restringido</h4>
    <p class="text-muted small mb-4">No tienes los privilegios necesarios para acceder a la administración del sistema.</p>
    <a href="inicial.pl" class="btn-medentia px-4"><i class="bi bi-house me-2"></i>Volver al Inicio</a>
  </div>
</div>
HTML
    render_footer();
    exit;
}

# --- Definición de Directorios ---
my $DAT_DIR = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $NOM_DIR = File::Spec->catdir($DAT_DIR, 'catalogosOF');
my $CRM_DIR = File::Spec->catdir($DAT_DIR, 'adjuntos_crm');

# --- LÓGICA DE DETECCION DE PARAMETROS ---
my $action = $q->param('action') // 'list';
my $target_file = $q->param('file') // '';
my $group = $q->param('group') // 'global'; # global, nom, crm

# Evitar path traversal
if ($target_file) {
    $target_file = basename($target_file);
}

# --- RUTAS DE ARCHIVOS SELECCIONADOS ---
my $full_path = '';
if ($target_file) {
    if ($group eq 'global') {
        $full_path = File::Spec->catfile($DAT_DIR, $target_file);
    } elsif ($group eq 'nom') {
        $full_path = File::Spec->catfile($NOM_DIR, $target_file);
    }
}

# --- PROCESAMIENTO DE ACCIONES DE DATOS ---
my $message = '';
my $error = '';
my @headers;

# --- ACCIONES AJAX ---
if ($action eq 'get_file_info') {
    my $rel_path = $q->param('file_path') // '';
    if ($rel_path =~ /\.\./) {
        print $q->header(-type => 'application/json', -status => '400 Bad Request');
        print JSON::PP->new->utf8->encode({ error => 'Invalid path' });
        exit;
    }
    
    my $full_path = File::Spec->catfile($DAT_DIR, $rel_path);
    if (!-e $full_path || !-f $full_path) {
        print $q->header(-type => 'application/json', -status => '404 Not Found');
        print JSON::PP->new->utf8->encode({ error => 'File not found' });
        exit;
    }
    
    my $filename = basename($full_path);
    my $size = -s $full_path;
    my $size_str = sprintf("%.2f KB", $size / 1024);
    my $is_crm = ($rel_path =~ /^adjuntos_crm[\/\\]/) ? 1 : 0;
    
    my @headers = ();
    if ($filename =~ /\.dat$/) {
        if (open(my $fh, '<:encoding(UTF-8)', $full_path)) {
            my $hdr = <$fh>;
            if ($hdr) {
                chomp $hdr;
                my $sep = ($hdr =~ /!/) ? '!' : '\|';
                @headers = split /$sep/, $hdr;
                chomp @headers;
            }
            close($fh);
        }
    }
    
    my @references = ();
    if ($is_crm) {
        if (opendir(my $dh, $DAT_DIR)) {
            my @dat_files = grep { /\.dat$/ && -f File::Spec->catfile($DAT_DIR, $_) } readdir($dh);
            closedir($dh);
            
            my $crm_rel = File::Spec->abs2rel($full_path, $CRM_DIR);
            $crm_rel =~ s/\\/\//g;
            
            foreach my $df (@dat_files) {
                my $df_path = File::Spec->catfile($DAT_DIR, $df);
                if (open(my $fh, '<:encoding(UTF-8)', $df_path)) {
                    my $ln = 0;
                    while (my $line = <$fh>) {
                        $ln++;
                        chomp $line;
                        if (index($line, $filename) != -1 || index($line, $crm_rel) != -1) {
                            push @references, {
                                file => $df,
                                line => $ln,
                                content => $line
                            };
                        }
                    }
                    close($fh);
                }
            }
        }
    }
    
    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print JSON::PP->new->utf8->encode({
        name => $filename,
        path => $rel_path,
        size => $size_str,
        is_crm => $is_crm,
        headers => \@headers,
        references => \@references
    });
    exit;
}

if ($action eq 'delete_crm_file' && $q->request_method() eq 'POST') {
    my $rel_path = $q->param('file_path') // '';
    if ($rel_path =~ /\.\./ || $rel_path !~ /^adjuntos_crm[\/\\]/) {
        print $q->header(-type => 'application/json', -status => '400 Bad Request');
        print JSON::PP->new->utf8->encode({ ok => 0, error => 'Invalid path' });
        exit;
    }
    
    my $full_path = File::Spec->catfile($DAT_DIR, $rel_path);
    if (!-e $full_path || !-f $full_path) {
        print $q->header(-type => 'application/json', -status => '404 Not Found');
        print JSON::PP->new->utf8->encode({ ok => 0, error => 'File not found' });
        exit;
    }
    
    my $filename = basename($full_path);
    my $crm_rel = File::Spec->abs2rel($full_path, $CRM_DIR);
    $crm_rel =~ s/\\/\//g;
    
    # 1. Delete physical file
    my $deleted = unlink($full_path);
    if (!$deleted) {
        print $q->header(-type => 'application/json', -status => '500 Internal Server Error');
        print JSON::PP->new->utf8->encode({ ok => 0, error => "Could not delete file: $!" });
        exit;
    }
    
    # 2. Delete references in /dat/*.dat files
    my $cleaned_count = 0;
    if (opendir(my $dh, $DAT_DIR)) {
        my @dat_files = grep { /\.dat$/ && -f File::Spec->catfile($DAT_DIR, $_) } readdir($dh);
        closedir($dh);
        
        foreach my $df (@dat_files) {
            my $df_path = File::Spec->catfile($DAT_DIR, $df);
            my @lines = ();
            my $modified = 0;
            
            if (open(my $fh, '<:encoding(UTF-8)', $df_path)) {
                while (my $line = <$fh>) {
                    chomp $line;
                    if (index($line, $filename) != -1 || index($line, $crm_rel) != -1) {
                        my $sep_char = ($line =~ /!/) ? '!' : '|';
                        my @parts = split /\Q$sep_char\E/, $line, -1;
                        for my $i (0 .. $#parts) {
                            if ($parts[$i] eq $filename || $parts[$i] eq $crm_rel) {
                                $parts[$i] = '';
                                $modified = 1;
                            }
                        }
                        $line = join($sep_char, @parts);
                    }
                    push @lines, $line;
                }
                close($fh);
            }
            
            if ($modified) {
                if (open(my $out_fh, '>:encoding(UTF-8)', $df_path)) {
                    foreach my $l (@lines) {
                        print $out_fh "$l\n";
                    }
                    close($out_fh);
                    $cleaned_count++;
                }
            }
        }
    }
    
    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print JSON::PP->new->utf8->encode({ ok => 1, msg => "Archivo y $cleaned_count referencias eliminadas correctamente." });
    exit;
}

# 1. Crear Nueva Tabla
if ($action eq 'do_create_table' && $q->request_method() eq 'POST') {
    my $new_filename = $q->param('new_name') // '';
    my $columns_str = $q->param('columns') // '';
    
    $new_filename =~ s/[^a-zA-Z0-9_]//g;
    $new_filename .= '.dat' unless $new_filename =~ /\.dat$/;
    
    if ($new_filename && $columns_str) {
        my $new_path = File::Spec->catfile($DAT_DIR, $new_filename);
        if (-e $new_path) {
            $error = "El archivo $new_filename ya existe.";
        } else {
            open(my $fh, '>', $new_path) or $error = "No se pudo crear la tabla: $!";
            if (!$error) {
                binmode($fh, ":utf8");
                $columns_str =~ s/[,;|]+/|/g;
                print $fh "$columns_str\n";
                close($fh);
                $message = "Tabla $new_filename creada exitosamente.";
                $action = 'list';
            }
        }
    } else {
        $error = "Nombre de tabla y columnas requeridos.";
    }
}

# 2. Agregar Registro
elsif ($action eq 'do_add_record' && $q->request_method() eq 'POST' && $full_path && -e $full_path) {
    open(my $fh, '<', $full_path);
    binmode($fh, ":utf8");
    my $header = <$fh>;
    close($fh);
    
    if ($header) {
        chomp $header;
        my $sep = ($header =~ /!/) ? '!' : '\|';
        my $sep_write = ($header =~ /!/) ? '!' : '|';
        my @fields = split /$sep/, $header;
        my @values;
        foreach my $field (@fields) {
            my $val = $q->param("field_$field") // '';
            $val =~ s/[\r\n\t]+/ /g;
            $val =~ s/\Q$sep_write\E//g; # Prevenir inyección de delimitador flat-file
            push @values, $val;
        }
        my $line = join($sep_write, @values);
        
        open(my $fh_out, '>>', $full_path) or $error = "No se pudo abrir el archivo para escribir: $!";
        if (!$error) {
            flock($fh_out, 2);
            binmode($fh_out, ":utf8");
            print $fh_out "$line\n";
            close($fh_out);
            $message = "Registro agregado con éxito.";
            $action = 'view';
        }
    }
}

# 3. Editar Registro
elsif ($action eq 'do_edit_record' && $q->request_method() eq 'POST' && $full_path && -e $full_path) {
    my $id_to_edit = $q->param('id_to_edit') // '';
    
    open(my $fh, '<', $full_path);
    binmode($fh, ":utf8");
    my $header = <$fh>;
    my @lines;
    my $sep = ($header && $header =~ /!/) ? '!' : '\|';
    my $sep_write = ($header && $header =~ /!/) ? '!' : '|';
    
    chomp $header if $header;
    my @fields = $header ? split(/$sep/, $header) : ();
    my @values;
    foreach my $field (@fields) {
        my $val = $q->param("field_$field") // '';
        $val =~ s/[\r\n\t]+/ /g;
        $val =~ s/\Q$sep_write\E//g; # Prevenir inyección de delimitador flat-file
        push @values, $val;
    }
    my $new_line = join($sep_write, @values);

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @cols = split /$sep/, $line;
        if (($cols[0] // '') eq $id_to_edit) {
            push @lines, $new_line;
        } else {
            push @lines, $line;
        }
    }
    close($fh);
    
    open(my $fh_out, '>', $full_path) or $error = "No se pudo actualizar la tabla: $!";
    if (!$error) {
        flock($fh_out, 2);
        binmode($fh_out, ":utf8");
        print $fh_out "$header\n";
        foreach my $l (@lines) {
            print $fh_out "$l\n";
        }
        close($fh_out);
        $message = "Registro actualizado con éxito.";
    }
    $action = 'view';
}

# 4. Eliminar Registro
elsif ($action eq 'do_delete_record' && $full_path && -e $full_path) {
    my $id_to_delete = $q->param('id') // '';
    if ($id_to_delete ne '') {
        open(my $fh, '<', $full_path);
        binmode($fh, ":utf8");
        my $header = <$fh>;
        my @lines;
        my $sep = ($header && $header =~ /!/) ? '!' : '\|';
        
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @cols = split /$sep/, $line;
            if (($cols[0] // '') ne $id_to_delete) {
                push @lines, $line;
            }
        }
        close($fh);
        
        open(my $fh_out, '>', $full_path) or $error = "No se pudo reescribir la tabla: $!";
        if (!$error) {
            flock($fh_out, 2);
            binmode($fh_out, ":utf8");
            print $fh_out "$header";
            foreach my $l (@lines) {
                print $fh_out "$l\n";
            }
            close($fh_out);
            $message = "Registro eliminado.";
        }
    }
    $action = 'view';
}

# 5. Vaciar Tabla (Truncar)
elsif ($action eq 'do_truncate' && $full_path && -e $full_path) {
    open(my $fh, '<', $full_path);
    binmode($fh, ":utf8");
    my $header = <$fh>;
    close($fh);
    
    if ($header) {
        open(my $fh_out, '>', $full_path) or $error = "No se pudo truncar la tabla: $!";
        if (!$error) {
            flock($fh_out, 2);
            binmode($fh_out, ":utf8");
            print $fh_out "$header";
            close($fh_out);
            $message = "Tabla vaciada exitosamente (cabecera preservada).";
        }
    }
    $action = 'view';
}

# 6. Cargar CSV para Actualizar Catálogo NOM
elsif ($action eq 'do_upload_csv' && $group eq 'nom' && $full_path && -e $full_path) {
    my $upload_fh = $q->upload('csv_file');
    if ($upload_fh) {
        open(my $fh_orig, '<', $full_path);
        binmode($fh_orig, ":utf8");
        my $header = <$fh_orig>;
        close($fh_orig);
        
        if ($header) {
            chomp $header;
            my @new_lines;
            while (my $line = <$upload_fh>) {
                $line = decode_utf8($line) unless utf8::is_utf8($line);
                chomp $line;
                $line =~ s/\r//g;
                next if $line =~ /^\s*$/;
                
                my $comma_count = ($line =~ tr/,//);
                my $semi_count = ($line =~ tr/;//);
                my $sep = $comma_count >= $semi_count ? ',' : ';';
                
                my @fields;
                if ($line =~ /"/) {
                    while ($line =~ /\s*(?:\"([^\"]*)\"|([^$sep]*))\s*(?:$sep|$)/g) {
                        my $val = defined $1 ? $1 : $2;
                        push @fields, $val if defined $val;
                    }
                } else {
                    @fields = split /\Q$sep\E/, $line, -1;
                }
                
                push @new_lines, join('|', @fields);
            }
            
            open(my $fh_out, '>', $full_path) or $error = "No se pudo actualizar el catálogo NOM: $!";
            if (!$error) {
                flock($fh_out, 2);
                binmode($fh_out, ":utf8");
                print $fh_out "$header\n";
                foreach my $nl (@new_lines) {
                    print $fh_out "$nl\n";
                }
                close($fh_out);
                $message = "Catálogo NOM actualizado correctamente desde CSV.";
            }
        }
    } else {
        $error = "No se seleccionó ningún archivo CSV válido.";
    }
    $action = 'view';
}

# 7. Eliminar Archivo Adjunto
elsif ($action eq 'do_delete_attachment') {
    my $att_file = $q->param('att_file') // '';
    if ($att_file && $att_file !~ /\.\./) {
        my $att_path = File::Spec->catfile($CRM_DIR, $att_file);
        if (-e $att_path && -f $att_path) {
            unlink($att_path);
            $message = "Archivo adjunto eliminado.";
        } else {
            $error = "El archivo adjunto no existe o es inválido.";
        }
    }
    $action = 'list';
}

sub decode_utf8 {
    my ($str) = @_;
    eval { $str = Encode::decode('UTF-8', $str); };
    return $str;
}

# --- RENDERIZADO DE VISTA ---
# --- Obtener listas de archivos y entidades (siempre disponibles) ---
my @global_files;
my @nom_files;
my @attachments;
my %entidades;

if (-d $DAT_DIR) {
    opendir(my $dh, $DAT_DIR);
    @global_files = sort grep { /\.dat$/ && -f File::Spec->catfile($DAT_DIR, $_) } readdir($dh);
    closedir($dh);
}

if (-d $NOM_DIR) {
    opendir(my $dh, $NOM_DIR);
    @nom_files = sort grep { /\.dat$/ && -f File::Spec->catfile($NOM_DIR, $_) } readdir($dh);
    closedir($dh);
}

if (-d $CRM_DIR) {
    find(sub {
        if (-f $_) {
            my $rel_path = File::Spec->abs2rel($File::Find::name, $CRM_DIR);
            $rel_path =~ s/\\/\//g;
            my $size = -s $File::Find::name;
            push @attachments, { path => $rel_path, size => $size };
        }
    }, $CRM_DIR);
}

my $entidades_path = File::Spec->catfile($NOM_DIR, 'CAT_ENTIDADES.dat');
if (-e $entidades_path) {
    open(my $efh, '<', $entidades_path);
    binmode($efh, ":utf8");
    my $hdr = <$efh>; # Skip header
    while (my $line = <$efh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my ($id, $nombre, $abrev) = split /\|/, $line;
        if ($id =~ /^\d+$/ && $id >= 1 && $id <= 32) {
            $entidades{$id} = $nombre;
        }
    }
    close($efh);
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');

render_header(
    usuario     => $usuario,
    titulo      => "Consola de Datos Maestros",
    ruta_logout => '../auth/cerrar_sesion.pl',
    role        => $role,
    skip_header => 1
);

# --- CARGAR RECURSOS GLOBALES DE DATATABLES (Protocolo Guía de Estilo 7) ---
print <<HTML;
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">
<!-- Recursos de Visualización en Árbol -->
<link rel="stylesheet" href="https://unpkg.com/tabulator-tables@5.5.4/dist/css/tabulator_bootstrap5.min.css">
<style>
    /* Tabulator custom layout for clinical aesthetic */
    .tabulator {
        background-color: #ffffff;
        border: 1px solid rgba(0,0,0,0.08) !important;
        font-family: inherit;
    }
    .tabulator-header {
        background-color: #f8fafc !important;
        border-bottom: 2px solid rgba(0,0,0,0.06) !important;
        color: #1e293b !important;
        font-weight: 700 !important;
    }
    .tabulator-row {
        border-bottom: 1px solid rgba(0,0,0,0.04) !important;
    }
</style>
HTML

# Toast de Notificaciones
if ($message || $error) {
    my $icon = $error ? 'error' : 'success';
    my $title = $error ? 'Error' : 'Éxito';
    my $text = $error ? $error : $message;
    $text =~ s/'/\\'/g;
    print <<HTML;
    <script>
        \$(document).ready(function() {
            Swal.fire({
                icon: '$icon',
                title: '$title',
                text: '$text',
                confirmButtonColor: '#0A2A66'
            });
        });
    </script>
HTML
}

# --- CARGAR MUNICIPIOS ---
my %municipios_por_estado;
my $muni_path = File::Spec->catfile($NOM_DIR, 'CAT_MUNICIPIOS.dat');
if (-e $muni_path) {
    if (open(my $mfh, '<:encoding(UTF-8)', $muni_path)) {
        my $hdr = <$mfh>; # Skip header
        while (my $line = <$mfh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my ($ent_id, $muni_id, $muni_nombre) = split /\|/, $line;
            if ($ent_id && $muni_nombre) {
                $ent_id =~ s/^\s+|\s+$//g;
                $muni_nombre =~ s/^\s+|\s+$//g;
                push @{$municipios_por_estado{$ent_id}}, $muni_nombre;
            }
        }
        close($mfh);
    }
}
my $municipios_json = JSON::PP->new->utf8->canonical->encode(\%municipios_por_estado);

# --- CARGAR CAPÍTULOS CIE-10 ---
my @cie10_capitulos;
my $cie10_path = File::Spec->catfile($NOM_DIR, 'CAT_CIE10_DIAGNOSTICOS.dat');
if (-e $cie10_path) {
    my %seen_caps;
    if (open(my $cfh, '<:encoding(UTF-8)', $cie10_path)) {
        my $hdr = <$cfh>; # Skip header
        while (my $line = <$cfh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @cols = split /!/, $line;
            if (defined $cols[2]) {
                my $cap = $cols[2];
                $cap =~ s/^\s+|\s+$//g;
                if ($cap ne '') {
                    $seen_caps{$cap} = 1;
                }
            }
        }
        close($cfh);
    }
    @cie10_capitulos = sort keys %seen_caps;
}

# Declaramos variables para la tabla seleccionada si existe
@headers = ();
my @rows;
my $is_large_file = 0;
my $estado_nombre = '';
my $c_estado_filter = $q->param('c_estado') // '';
my $c_postal_filter = $q->param('c_postal') // '';
$c_postal_filter =~ s/\s+//g;
my $d_mnpio_filter = $q->param('d_mnpio') // '';
$d_mnpio_filter =~ s/^\s+|\s+$//g;
my $c_capitulo_filter = $q->param('c_capitulo') // '';
$c_capitulo_filter =~ s/^\s+|\s+$//g;
my $should_load_data = 1;
my $clues_json = '{}';

# --- LÓGICA DE RECORRIDO DE DIRECTORIOS PARA ARBOL ---
my $nested_json_val = 'null';
if (!$target_file) {
    my @nested_tree;
    my $counter = 0;
    get_dat_tree($DAT_DIR, \$counter, \@nested_tree);
    $nested_json_val = JSON::PP->new->utf8->canonical->encode(\@nested_tree);
}

if ($target_file && $full_path && -e $full_path) {
    open(my $fh, '<', $full_path);
    binmode($fh, ":utf8");
    my $header = <$fh>;
    
    my $sep = ($header && $header =~ /!/) ? '!' : '\|';
    
    if ($header) {
        @headers = split /$sep/, $header;
        chomp @headers;
    }
    
    if (($target_file eq 'CODIGO_POSTAL.dat' || $target_file eq 'CAT_CLUES.dat') && $c_estado_filter eq '') {
        $should_load_data = 0;
    }
    if ($target_file eq 'CODIGO_POSTAL.dat' && $d_mnpio_filter eq '') {
        $should_load_data = 0;
    }
    if ($target_file eq 'CAT_CIE10_DIAGNOSTICOS.dat' && $c_capitulo_filter eq '') {
        $should_load_data = 0;
    }
    
    if ($should_load_data) {
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/ || $line =~ /^\s*#/;
            my @cols = split /$sep/, $line;
            
            # Filtro por Estado/Capítulo para catálogos masivos
            if ($target_file eq 'CODIGO_POSTAL.dat') {
                next unless ($cols[7] // '') eq $c_estado_filter;
                if ($d_mnpio_filter ne '') {
                    my $clean_filter = lc($d_mnpio_filter);
                    $clean_filter =~ tr/áéíóúüñ/aeioun/;
                    my $clean_col = lc($cols[3] // '');
                    $clean_col =~ tr/áéíóúüñ/aeioun/;
                    next unless $clean_col eq $clean_filter;
                }
            } elsif ($target_file eq 'CAT_CLUES.dat') {
                next unless ($cols[3] // '') eq $c_estado_filter;
                if ($c_postal_filter ne '') {
                    next unless ($cols[27] // '') eq $c_postal_filter;
                }
            } elsif ($target_file eq 'CAT_CIE10_DIAGNOSTICOS.dat') {
                next unless ($cols[2] // '') eq $c_capitulo_filter;
            }
            
            push @rows, \@cols;
        }
    }
    close($fh);
    
    $is_large_file = (scalar @rows > 1000) ? 1 : 0;
    
    if (($target_file eq 'CODIGO_POSTAL.dat' || $target_file eq 'CAT_CLUES.dat') && $c_estado_filter ne '') {
        $estado_nombre = $entidades{$c_estado_filter} // "Código $c_estado_filter";
    }
    
    if ($target_file eq 'CAT_CLUES.dat' && $should_load_data) {
        my %clues_hash;
        foreach my $r (@rows) {
            my %row_data;
            for (my $i = 0; $i < scalar @headers; $i++) {
                $row_data{$headers[$i]} = $r->[$i] // '';
            }
            $clues_hash{$r->[0]} = \%row_data;
        }
        my $json_obj = JSON::PP->new->utf8->canonical;
        $clues_json = $json_obj->encode(\%clues_hash);
    }
}

# --- RENDERIZADO DEL CONTENEDOR PRINCIPAL ---
print <<HTML;
<div class="container mt-2 animate__animated animate__fadeIn">
    <!-- Cabecera de la Consola -->
    <div class="d-flex justify-content-between align-items-center mb-4 border-bottom pb-3">
        <h3 class="fw-bold m-0"><i class="bi bi-database-fill text-primary me-2"></i>Consola de Datos Maestros</h3>
        <button class="btn btn-medentia btn-sm" onclick="showCreateTableModal()">
            <i class="bi bi-plus-circle me-1"></i> Nueva Tabla
        </button>
    </div>
    
    <!-- Contenedor 1: Selectores de Catálogos (Bento Grid) -->
    <div class="row g-4 mb-4">
        <!-- Globales de Sistema -->
        <div class="col-12 col-md-6">
            <div class="card-medentia p-4 h-100 d-flex flex-column justify-content-between">
                <div>
                    <h5 class="fw-bold text-primary mb-3 border-bottom pb-2">
                        <i class="bi bi-hdd-network-fill me-2"></i>Globales Sistema
                    </h5>
                    <p class="text-muted small">Configuraciones transaccionales y maestros de datos.</p>
                    <select class="form-select mb-3 rounded-3" id="selectGlobal">
                        <option value="">-- Seleccionar tabla --</option>
HTML
foreach my $f (@global_files) {
    my $size = -s File::Spec->catfile($DAT_DIR, $f);
    my $sel = ($group eq 'global' && $target_file eq $f) ? 'selected' : '';
    print qq(<option value="$f" $sel>$f ($size bytes)</option>\n);
}
print <<HTML;
                    </select>
                </div>
                <button onclick="goGlobal()" class="btn btn-medentia w-100 mt-3">
                    <i class="bi bi-gear-fill me-2"></i>Gestionar Tabla
                </button>
            </div>
        </div>
        
        <!-- Oficiales NOM -->
        <div class="col-12 col-md-6">
            <div class="card-medentia p-4 h-100 d-flex flex-column justify-content-between">
                <div>
                    <h5 class="fw-bold text-teal mb-3 border-bottom pb-2" style="color: var(--md-teal-clinical);">
                        <i class="bi bi-journal-bookmark-fill me-2"></i>Oficiales NOM
                    </h5>
                    <p class="text-muted small">Catálogos normativos oficiales e históricos.</p>
                    <select class="form-select mb-3 rounded-3" id="selectNom">
                        <option value="">-- Seleccionar catálogo --</option>
HTML
foreach my $f (@nom_files) {
    my $size = -s File::Spec->catfile($NOM_DIR, $f);
    my $size_mb = sprintf("%.2f MB", $size / 1024 / 1024);
    my $sel = ($group eq 'nom' && $target_file eq $f) ? 'selected' : '';
    print qq(<option value="$f" $sel>$f ($size_mb)</option>\n);
}
print <<HTML;
                    </select>
                </div>
                <button onclick="goNom()" class="btn btn-outline-info w-100 mt-3 rounded-3" style="color: var(--md-teal-clinical); border-color: var(--md-teal-clinical);">
                    <i class="bi bi-eye-fill me-2"></i>Consultar Tabla
                </button>
            </div>
        </div>
    </div>
HTML

# Renderizado del Contenedor 2: Visor de Datos Activo
if ($target_file && $full_path && -e $full_path) {
    print <<HTML;
    <!-- Contenedor 2: Visor de Datos Activo -->
    <div class="row mb-4">
        <div class="col-12">
            <div class="card-medentia p-4">
                <div class="d-flex justify-content-between align-items-center mb-4 border-bottom pb-3 flex-wrap gap-3">
                    <div>
                        <h4 class="fw-bold m-0 text-primary">
                            <i class="bi bi-table me-2"></i>Tabla Activa: $target_file
                        </h4>
HTML
    if ($estado_nombre) {
        my $c_postal_esc = CGI::escapeHTML($c_postal_filter);
        my $d_mnpio_esc = CGI::escapeHTML($d_mnpio_filter);
        print <<HTML;
                        <div class="mt-2 d-flex align-items-center gap-2 flex-wrap">
                            <span class="badge bg-medentia-gradient px-3 py-2 fs-7">
                                <i class="bi bi-geo-alt-fill me-1"></i> Estado: $estado_nombre
                            </span>
HTML
        if ($c_postal_filter ne '') {
            print <<HTML;
                            <span class="badge bg-info px-3 py-2 fs-7">
                                <i class="bi bi-mailbox me-1"></i> C.P.: $c_postal_esc
                            </span>
HTML
        }
        if ($d_mnpio_filter ne '') {
            print <<HTML;
                            <span class="badge bg-success px-3 py-2 fs-7">
                                <i class="bi bi-geo-fill me-1"></i> Municipio: $d_mnpio_esc
                            </span>
HTML
        }
        print <<HTML;
                            <button class="btn btn-outline-secondary btn-sm" onclick="showSelectEstadoModal()">
                                <i class="bi bi-funnel-fill"></i> Cambiar Filtros
                            </button>
                        </div>
HTML
    } elsif ($target_file eq 'CODIGO_POSTAL.dat' || $target_file eq 'CAT_CLUES.dat') {
        print <<HTML;
                        <div class="mt-2">
                            <button class="btn btn-outline-warning btn-sm" onclick="showSelectEstadoModal()">
                                <i class="bi bi-funnel-fill me-1"></i> Seleccionar Estado para Filtrar
                            </button>
                        </div>
HTML
    } elsif ($target_file eq 'CAT_CIE10_DIAGNOSTICOS.dat') {
        if ($c_capitulo_filter ne '') {
            my $c_capitulo_esc = CGI::escapeHTML($c_capitulo_filter);
            print <<HTML;
                        <div class="mt-2 d-flex align-items-center gap-2 flex-wrap">
                            <span class="badge bg-medentia-gradient px-3 py-2 fs-7">
                                <i class="bi bi-funnel-fill me-1"></i> Capítulo: $c_capitulo_esc
                            </span>
                            <button class="btn btn-outline-secondary btn-sm" onclick="showSelectCapituloModal()">
                                <i class="bi bi-funnel-fill"></i> Cambiar Filtros
                            </button>
                        </div>
HTML
        } else {
            print <<HTML;
                        <div class="mt-2">
                            <button class="btn btn-outline-warning btn-sm" onclick="showSelectCapituloModal()">
                                <i class="bi bi-funnel-fill me-1"></i> Seleccionar Capítulo para Filtrar
                            </button>
                        </div>
HTML
        }
    }
    
    if ($is_large_file && $target_file ne 'CODIGO_POSTAL.dat' && $target_file ne 'CAT_CLUES.dat' && $target_file ne 'CAT_CIE10_DIAGNOSTICOS.dat') {
        print qq(<span class="badge bg-warning text-dark mt-2"><i class="bi bi-exclamation-triangle-fill me-1"></i>Mostrando primeros 1000 registros por rendimiento</span>);
    }
    print <<HTML;
                    </div>
                    <div class="d-flex gap-2">
HTML
    if ($group eq 'global') {
        print <<HTML;
                        <button class="btn btn-outline-danger btn-sm" onclick="confirmTruncate();">
                            <i class="bi bi-trash-fill me-1"></i> Vaciar Tabla
                        </button>
                        <button class="btn btn-medentia btn-sm" onclick="showAddRecordModal()">
                            <i class="bi bi-plus-lg me-1"></i> Nuevo Registro
                        </button>
HTML
    } elsif ($group eq 'nom') {
        print <<HTML;
                        <button class="btn btn-outline-secondary btn-sm me-2" onclick="showStructureModal()">
                            <i class="bi bi-info-circle me-1"></i> Estructura
                        </button>
                        <button class="btn btn-outline-info btn-sm" onclick="showUploadCsvModal()">
                            <i class="bi bi-filetype-csv me-1"></i> Actualizar desde CSV
                        </button>
HTML
    }
    print <<HTML;
                    </div>
                </div>
HTML
    if (!$should_load_data) {
        if ($target_file eq 'CAT_CIE10_DIAGNOSTICOS.dat') {
            print <<HTML;
                <div class="text-center py-5 my-3 text-muted bg-light rounded-3 border border-dashed border-secondary border-opacity-25 animate__animated animate__fadeIn">
                    <i class="bi bi-funnel text-warning display-4 d-block mb-3 animate__animated animate__pulse animate__infinite"></i>
                    <h5 class="fw-bold text-dark">Filtro de Capítulo Requerido</h5>
                    <p class="mb-3 small px-3">Este catálogo de diagnósticos contiene más de 14,000 registros. Por favor, selecciona un Capítulo para poder realizar la consulta.</p>
                    <button class="btn btn-medentia btn-sm px-4 py-2 shadow-sm" onclick="showSelectCapituloModal()">
                        <i class="bi bi-funnel-fill"></i> Seleccionar Capítulo
                    </button>
                </div>
HTML
        } else {
            print <<HTML;
                <div class="text-center py-5 my-3 text-muted bg-light rounded-3 border border-dashed border-secondary border-opacity-25 animate__animated animate__fadeIn">
                    <i class="bi bi-funnel text-warning display-4 d-block mb-3 animate__animated animate__pulse animate__infinite"></i>
                    <h5 class="fw-bold text-dark">Filtro de Estado Requerido</h5>
                    <p class="mb-3 small px-3">Este catálogo contiene un volumen masivo de datos. Por favor, selecciona un Estado de la República para poder realizar la consulta.</p>
                    <button class="btn btn-medentia btn-sm px-4 py-2 shadow-sm" onclick="showSelectEstadoModal()">
                        <i class="bi bi-geo-alt-fill me-1"></i> Seleccionar Estado
                    </button>
                </div>
HTML
        }
    }
    my $responsive_class = $should_load_data ? '' : 'd-none';
    print <<HTML;
                
                <div class="table-responsive $responsive_class">
                    <table id="tablaConfig" class="table table-hover align-middle w-100">
                        <thead class="table-light">
                            <tr>
HTML
    if ($target_file eq 'CAT_CLUES.dat') {
        foreach my $h ('CLUES', 'MUNICIPIO', 'NOMBRE COMERCIAL', 'CODIGO POSTAL') {
            print "<th class='fw-bold text-dark'>$h</th>";
        }
    } else {
        foreach my $h (@headers) {
            print "<th class='fw-bold text-dark'>$h</th>";
        }
        if ($group eq 'global') {
            print "<th class='fw-bold text-dark text-end'>Acciones</th>";
        }
    }
    print <<HTML;
                            </tr>
                        </thead>
                        <tbody>
HTML
    if (!$should_load_data) {
        # Dejar tbody vacío para evitar discrepancia de número de columnas en DataTables
    } else {
        my $count = 0;
        foreach my $r (@rows) {
            $count++;
            if ($target_file ne 'CODIGO_POSTAL.dat' && $target_file ne 'CAT_CLUES.dat') {
                last if $count > 1000;
            }
            if ($target_file eq 'CAT_CLUES.dat') {
                my $id_val = CGI::escapeHTML($r->[0] // '');
                my $muni_val = CGI::escapeHTML($r->[6] // '');
                my $nom_val = CGI::escapeHTML($r->[18] // '');
                my $cp_val = CGI::escapeHTML($r->[27] // '');
                
                print <<HTML;
                <tr class="clues-row" data-id="$id_val" style="cursor: pointer;">
                    <td>$id_val</td>
                    <td>$muni_val</td>
                    <td>$nom_val</td>
                    <td>$cp_val</td>
                </tr>
HTML
            } else {
                print "<tr>";
                for (my $i = 0; $i < scalar @headers; $i++) {
                    my $val = CGI::escapeHTML($r->[$i] // '');
                    print "<td>$val</td>";
                }
                if ($group eq 'global') {
                    my $id_val = CGI::escapeHTML($r->[0] // '');
                    print <<HTML;
                    <td class="text-end text-nowrap">
                        <button class="btn btn-outline-primary btn-sm rounded-circle me-1 edit-btn" data-id="$id_val" title="Editar">
                            <i class="bi bi-pencil"></i>
                        </button>
                        <a href="?action=do_delete_record&file=$target_file&group=$group&id=$id_val" class="btn btn-outline-danger btn-sm rounded-circle" onclick="return confirm('¿Seguro que deseas eliminar este registro?');" title="Eliminar">
                            <i class="bi bi-trash"></i>
                        </a>
                    </td>
HTML
                }
                print "</tr>";
            }
        }
    }
    print <<HTML;
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
HTML
}

# Renderizado del Contenedor 3: Archivos Adjuntos (Blob Storage)
print <<HTML;
    <!-- Contenedor 3: Archivos Adjuntos (Blob Storage) -->
    <div class="row">
        <div class="col-12">
            <div class="card-medentia p-4">
                <h5 class="fw-bold text-dark mb-3 border-bottom pb-2" style="color: var(--md-text-primary);">
                    <i class="bi bi-file-earmark-arrow-up-fill me-2"></i>Archivos Adjuntos (Blob Storage)
                </h5>
                
                <div class="table-responsive">
                    <table id="tablaAdjuntos" class="table table-hover align-middle w-100">
                        <thead class="table-light">
                            <tr>
                                <th class="fw-bold text-dark small">Archivo</th>
                                <th class="fw-bold text-dark small">Tamaño</th>
                                <th class="fw-bold text-dark small text-end">Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
HTML
foreach my $att (@attachments) {
    my $name = basename($att->{path});
    my $path_encoded = $att->{path};
    my $size_kb = sprintf("%.1f KB", $att->{size}/1024);
    print <<HTML;
                            <tr>
                                <td class="text-truncate small" style="max-width: 250px;" title="$name">$name</td>
                                <td class="small">$size_kb</td>
                                <td class="text-end text-nowrap">
                                    <a href="../dat/adjuntos_crm/$path_encoded" target="_blank" class="btn btn-light btn-sm rounded-circle" title="Descargar">
                                        <i class="bi bi-download"></i>
                                    </a>
                                    <a href="?action=do_delete_attachment&att_file=$path_encoded" class="btn btn-outline-danger btn-sm rounded-circle" onclick="return confirm('¿Eliminar adjunto?');" title="Borrar">
                                        <i class="bi bi-trash"></i>
                                    </a>
                                </td>
                            </tr>
HTML
}
print <<HTML;
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

HTML

if (!$target_file) {
    print <<HTML;
    <!-- Sección: Estructura de Directorios -->
    <div class="row mt-5 animate__animated animate__fadeIn">
        <div class="col-12">
            <div class="border-bottom pb-2 mb-4">
                <h4 class="fw-bold text-dark m-0"><i class="bi bi-diagram-3-fill text-primary me-2"></i>Estructura de Directorios /dat</h4>
                <p class="text-muted small">Explorador jerárquico interactivo de la carpeta de datos maestros utilizando Tabulator.</p>
            </div>
        </div>
    </div>

    <!-- Tabulator Tree Data -->
    <div class="row g-4 mb-5">
        <div class="col-12 col-lg-7">
            <div class="card-medentia p-4 h-100">
                <h5 class="fw-bold text-teal mb-3" style="color: var(--md-teal-clinical);"><i class="bi bi-diagram-3-fill me-1"></i>Visualización de Estructura /dat con Tabulator</h5>
                <div id="tabulatorTreeGrid" style="border-radius: 12px; overflow: hidden;"></div>
            </div>
        </div>
        <div class="col-12 col-lg-5">
            <div class="card-medentia p-4 h-100 bg-light border-0 d-flex flex-column justify-content-between" id="detailsCard">
                <div id="detailsCardContent">
                    <h5 class="fw-bold text-dark mb-3" id="detailsCardTitle"><i class="bi bi-info-circle-fill text-teal me-2" style="color: var(--md-teal-clinical);"></i>Explicación: Tabulator</h5>
                    <p class="text-muted small">Esta implementación utiliza una librería moderna de grillas basada en datos JSON estructurados jerárquicamente en el lado del cliente.</p>
                    <ul class="text-muted small ps-3">
                        <li class="mb-2"><strong>Ventajas</strong>: Alto rendimiento gracias al renderizado virtual (solo pinta las filas visibles), interactividad en tiempo real (ordenación, filtros dinámicos) y sin dependencias externas.</li>
                        <li class="mb-2"><strong>Desventajas</strong>: Curva de aprendizaje más pronunciada y requerimiento de parseo JSON estructurado en el backend.</li>
                        <li class="mb-2"><strong>Visualización</strong>: Interfaz fluida, controles interactivos tipo "toggle" y adaptabilidad total a temas modernos de diseño.</li>
                    </ul>
                </div>
                <div class="alert alert-info bg-info bg-opacity-10 text-info border-0 small m-0 rounded-3" id="detailsCardFooter">
                    <i class="bi bi-lightning-charge-fill me-1 fw-bold"></i> <strong>Nota Técnica</strong>: La opción ideal para catálogos oficiales pesados o expedientes interactivos de alta carga de datos.
                </div>
            </div>
        </div>
    </div>
HTML
}

print <<HTML;
</div>

<!-- Modal: Crear Tabla -->
<div class="modal fade" id="createTableModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content card-medentia p-4 border-0">
            <div class="modal-header border-0 pb-0">
                <h5 class="modal-title fw-bold"><i class="bi bi-grid-3x3-gap-fill text-primary me-2"></i>Crear Nueva Tabla (.dat)</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body border-0">
                <form action="manage_config.pl" method="POST">
                    <input type="hidden" name="action" value="do_create_table">
                    <div class="mb-3">
                        <label class="form-label small fw-bold">Nombre de la Tabla</label>
                        <input type="text" name="new_name" class="form-control rounded-3" placeholder="ej. catalogo_materiales" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label small fw-bold">Columnas (Separadas por pipe '|')</label>
                        <input type="text" name="columns" class="form-control rounded-3" placeholder="ej. ID|Nombre|Precio|Unidad" required>
                        <div class="form-text small text-muted">La primera columna siempre se considerará como ID de llave primaria.</div>
                    </div>
                    <button type="submit" class="btn-medentia w-100 mt-2">CREAR TABLA</button>
                </form>
            </div>
        </div>
    </div>
</div>
HTML

# Pre-escapar valores de filtros para interpolación en heredocs sin usar @{[ ]} (Protocolo 13)
my $c_postal_esc = CGI::escapeHTML($c_postal_filter);
my $d_mnpio_esc = CGI::escapeHTML($d_mnpio_filter);

print <<HTML;
<!-- Modal: Seleccionar Estado de la República -->
<div class="modal fade" id="selectEstadoModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content card-medentia p-4 border-0">
            <div class="modal-header border-0 pb-0">
                <h5 class="modal-title fw-bold"><i class="bi bi-geo-alt-fill text-primary me-2"></i>Seleccionar Estado</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body border-0">
                <form action="manage_config.pl" method="GET" id="selectEstadoForm">
                    <input type="hidden" name="action" value="view">
                    <input type="hidden" name="file" value="$target_file" id="selectEstadoFile">
                    <input type="hidden" name="group" value="nom">
                    <div class="mb-3">
                        <label class="form-label small fw-bold">Estado de la República</label>
                        <select name="c_estado" class="form-select rounded-3" required id="selectEstadoCombo">
                            <option value="">-- Seleccione un Estado --</option>
HTML
foreach my $id (sort keys %entidades) {
    my $nombre = $entidades{$id};
    my $sel_est = ($c_estado_filter eq $id) ? 'selected' : '';
    print qq(<option value="$id" $sel_est>$id - $nombre</option>\n);
}
print <<HTML;
                        </select>
                    </div>
                    <div class="mb-3 d-none" id="cpFilterGroup">
                        <label class="form-label small fw-bold">Código Postal (Opcional)</label>
                        <input type="text" name="c_postal" id="selectEstadoCP" class="form-control rounded-3" placeholder="ej. 20000" maxlength="5" value="$c_postal_esc">
                        <div class="form-text small text-muted">Ingresa el código postal para reducir los resultados.</div>
                    </div>
                    <div class="mb-3 d-none" id="mnpioFilterGroup">
                        <label class="form-label small fw-bold">Municipio (Requerido)</label>
                        <select name="d_mnpio" id="selectEstadoMnpio" class="form-select rounded-3">
                            <option value="">-- Seleccione primero un Estado --</option>
                        </select>
                        <div class="form-text small text-muted">Seleccione el municipio para filtrar los códigos postales.</div>
                    </div>
                    <button type="submit" class="btn-medentia w-100 mt-2">FILTRAR Y CONSULTAR</button>
                </form>
            </div>
        </div>
    </div>
</div>

<!-- Modal: Seleccionar Capítulo de CIE-10 (DOM Teleportation Protocol) -->
<div class="modal fade" id="selectCapituloModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content card-medentia p-4 border-0">
            <div class="modal-header border-0 pb-0">
                <h5 class="modal-title fw-bold text-primary"><i class="bi bi-funnel-fill me-2"></i>Filtrar por Capítulo</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body border-0">
                <form action="manage_config.pl" method="GET" id="selectCapituloForm">
                    <input type="hidden" name="action" value="view">
                    <input type="hidden" name="file" value="CAT_CIE10_DIAGNOSTICOS.dat">
                    <input type="hidden" name="group" value="nom">
                    <div class="mb-3">
                        <label class="form-label small fw-bold">Capítulo CIE-10</label>
                        <select name="c_capitulo" class="form-select rounded-3" required id="selectCapituloCombo">
                            <option value="">-- Seleccione un Capítulo --</option>
HTML
foreach my $cap (@cie10_capitulos) {
    my $cap_esc = CGI::escapeHTML($cap);
    my $sel_cap = ($c_capitulo_filter eq $cap) ? 'selected' : '';
    print qq(<option value="$cap_esc" $sel_cap>$cap_esc</option>\n);
}
print <<HTML;
                        </select>
                    </div>
                    <button type="submit" class="btn-medentia w-100 mt-2">FILTRAR Y CONSULTAR</button>
                </form>
            </div>
        </div>
    </div>
</div>
HTML

print <<HTML;
<!-- Modal: Detalles de CLUES -->
<div class="modal fade" id="cluesDetailModal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content card-medentia p-4 border-0">
            <div class="modal-header border-0 pb-0">
                <h5 class="modal-title fw-bold text-primary"><i class="bi bi-hospital text-primary me-2"></i>Detalle de la Unidad (CLUES)</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body border-0" id="cluesDetailModalBody">
                <!-- Se llenará dinámicamente -->
            </div>
        </div>
    </div>
</div>
HTML

# Modales de CRUD Activo si hay tabla seleccionada
if ($target_file && $full_path && -e $full_path) {
    print <<HTML;
    <!-- Modal: Agregar Registro -->
    <div class="modal fade" id="addRecordModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content card-medentia p-4 border-0">
                <div class="modal-header border-0 pb-0">
                    <h5 class="modal-title fw-bold"><i class="bi bi-plus-circle-fill text-primary me-2"></i>Agregar Registro</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body border-0">
                    <form action="manage_config.pl" method="POST">
                        <input type="hidden" name="action" value="do_add_record">
                        <input type="hidden" name="file" value="$target_file">
                        <input type="hidden" name="group" value="$group">
HTML
    my $is_first = 1;
    foreach my $h (@headers) {
        my $req = $is_first ? 'required' : '';
        $is_first = 0;
        print <<HTML;
                        <div class="mb-3">
                            <label class="form-label small fw-bold">$h</label>
                            <input type="text" name="field_$h" class="form-control rounded-3" $req>
                        </div>
HTML
    }
    print <<HTML;
                        <button type="submit" class="btn-medentia w-100 mt-2">GUARDAR REGISTRO</button>
                    </form>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Modal: Editar Registro -->
    <div class="modal fade" id="editRecordModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content card-medentia p-4 border-0">
                <div class="modal-header border-0 pb-0">
                    <h5 class="modal-title fw-bold"><i class="bi bi-pencil-square text-primary me-2"></i>Editar Registro</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body border-0">
                    <form action="manage_config.pl" method="POST" id="editRecordForm">
                        <input type="hidden" name="action" value="do_edit_record">
                        <input type="hidden" name="file" value="$target_file">
                        <input type="hidden" name="group" value="$group">
                        <input type="hidden" name="id_to_edit" id="id_to_edit">
HTML
    $is_first = 1;
    foreach my $h (@headers) {
        my $req = $is_first ? 'required' : '';
        $is_first = 0;
        print <<HTML;
                        <div class="mb-3">
                            <label class="form-label small fw-bold">$h</label>
                            <input type="text" name="field_$h" id="edit_field_$h" class="form-control rounded-3" $req>
                        </div>
HTML
    }
    print <<HTML;
                        <button type="submit" class="btn-medentia w-100 mt-2">GUARDAR CAMBIOS</button>
                    </form>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Modal: Cargar CSV -->
    <div class="modal fade" id="uploadCsvModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content card-medentia p-4 border-0">
                <div class="modal-header border-0 pb-0">
                    <h5 class="modal-title fw-bold"><i class="bi bi-file-earmark-arrow-up text-info me-2"></i>Actualizar Catálogo desde CSV</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body border-0">
                    <form action="manage_config.pl" method="POST" enctype="multipart/form-data">
                        <input type="hidden" name="action" value="do_upload_csv">
                        <input type="hidden" name="file" value="$target_file">
                        <input type="hidden" name="group" value="$group">
                        <div class="mb-3">
                            <label class="form-label small fw-bold">Seleccionar archivo CSV</label>
                            <input type="file" name="csv_file" class="form-control rounded-3" accept=".csv" required>
                            <div class="form-text small text-muted">
                                El archivo CSV debe tener la misma estructura y número de columnas que la tabla original. El delimitador se detectará de forma automática.
                            </div>
                        </div>
                        <button type="submit" class="btn-medentia w-100 mt-2">CARGAR Y REEMPLAZAR</button>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <!-- Modal: Estructura de la Tabla (DOM Teleportation Protocol) -->
    <div class="modal fade" id="tableStructureModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content card-medentia p-4 border-0">
                <div class="modal-header border-0 pb-0">
                    <h5 class="modal-title fw-bold text-primary"><i class="bi bi-info-circle-fill me-2"></i>Estructura de la Tabla</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body border-0">
                    <p class="text-muted small">Cabeceras y orden de las columnas en <strong>$target_file</strong>:</p>
                    <div class="list-group rounded-3 shadow-sm" style="max-height: 50vh; overflow-y: auto;">
HTML
    my $col_idx = 0;
    foreach my $h (@headers) {
        my $h_esc = CGI::escapeHTML($h);
        print <<HTML;
                        <div class="list-group-item d-flex justify-content-between align-items-center">
                            <span class="text-dark small fw-bold">$h_esc</span>
                            <span class="badge bg-light text-muted border rounded-pill px-2 py-1 fs-8">Índice $col_idx</span>
                        </div>
HTML
        $col_idx++;
    }
    print <<HTML;
                    </div>
                </div>
            </div>
        </div>
    </div>
HTML
}

# --- CARGAR SCRIPTS DE JS GLOBALES ANTES DE BOTTOM NAV Y FOOTER ---
print <<HTML;
<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>

<script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/vfs_fonts.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>

<!-- Scripts de Visualización en Árbol -->
<script src="https://unpkg.com/tabulator-tables@5.5.4/dist/js/tabulator.min.js"></script>

<script>
    window.nestedTreeData = $nested_json_val;

    // Funciones para detalles dinámicos y eliminación de CRM
    function loadFileDetails(filePath) {
        var titleEl = document.getElementById('detailsCardTitle');
        var contentEl = document.getElementById('detailsCardContent');
        
        if (!titleEl || !contentEl) return;
        
        titleEl.innerHTML = '<i class="bi bi-hourglass-split text-teal me-2" style="color: var(--md-teal-clinical);"></i>Cargando...';
        contentEl.innerHTML = '<div class="text-center py-4"><div class="spinner-border text-info" role="status"><span class="visually-hidden">Cargando...</span></div></div>';
        
        fetch('manage_config.pl?action=get_file_info&file_path=' + encodeURIComponent(filePath))
            .then(function(response) { return response.json(); })
            .then(function(data) {
                if (data.error) {
                    Swal.fire('Error', data.error, 'error');
                    return;
                }
                
                titleEl.textContent = 'Detalles (' + data.name + ')';
                var html = '';
                
                if (data.is_crm) {
                    html += '<button class="btn btn-danger btn-sm mb-4 w-100 d-flex align-items-center justify-content-center gap-2 rounded-3 shadow-sm py-2" onclick="deleteCrmFile(\\\'' + data.path + '\\\', ' + (data.references.length > 0) + ')">';
                    html += '<i class="bi bi-trash3-fill"></i> Eliminar Archivo Adjunto';
                    html += '</button>';
                }
                
                html += '<div class="mb-3">';
                html += '<p class="text-muted small mb-1"><strong>Ruta relativa:</strong> <code>dat/' + data.path + '</code></p>';
                html += '<p class="text-muted small mb-3"><strong>Tamaño:</strong> ' + data.size + '</p>';
                html += '</div>';
                
                if (data.headers && data.headers.length > 0) {
                    html += '<h6 class="fw-bold text-dark mb-2 small"><i class="bi bi-list-columns-reverse text-teal me-1" style="color: var(--md-teal-clinical);"></i>Estructura de Columnas:</h6>';
                    html += '<div class="list-group rounded-3 shadow-sm mb-3" style="max-height: 250px; overflow-y: auto;">';
                    data.headers.forEach(function(h, idx) {
                        html += '<div class="list-group-item d-flex justify-content-between align-items-center py-2">';
                        html += '<span class="text-dark small fw-bold">' + h + '</span>';
                        html += '<span class="badge bg-light text-muted border rounded-pill px-2 py-1 fs-8">Índice ' + idx + '</span>';
                        html += '</div>';
                    });
                    html += '</div>';
                } else if (data.name.match(/\\.dat\$/i)) {
                    html += '<div class="alert alert-secondary border-0 small rounded-3 py-2">';
                    html += 'Este archivo .dat está vacío o no contiene cabeceras.';
                    html += '</div>';
                }
                
                if (data.is_crm && data.references && data.references.length > 0) {
                    html += '<div class="alert alert-warning bg-warning bg-opacity-10 text-warning border-0 small rounded-3 mt-3 shadow-sm">';
                    html += '<div class="d-flex gap-2">';
                    html += '<i class="bi bi-exclamation-triangle-fill fs-5 mt-1"></i>';
                    html += '<div>';
                    html += '<strong class="d-block mb-1">¡Referencias Encontradas!</strong>';
                    html += 'Este archivo está registrado en los siguientes catálogos:';
                    html += '<ul class="mb-0 ps-3 mt-1 small">';
                    data.references.forEach(function(r) {
                        html += '<li><code>' + r.file + '</code> (Línea ' + r.line + ')</li>';
                    });
                    html += '</ul>';
                    html += '<span class="d-block mt-2 fw-semibold">Al borrar este archivo, se limpiará automáticamente la referencia/registro en cada uno de estos archivos .dat.</span>';
                    html += '</div>';
                    html += '</div>';
                    html += '</div>';
                }
                
                contentEl.innerHTML = html;
            })
            .catch(function(err) {
                console.error(err);
                titleEl.textContent = 'Error';
                contentEl.innerHTML = '<div class="alert alert-danger border-0 small rounded-3">No se pudo cargar la información del archivo.</div>';
            });
    }

    function deleteCrmFile(filePath, hasReferences) {
        var warningText = 'Esta acción eliminará permanentemente el archivo físico adjunto.';
        if (hasReferences) {
            warningText += ' Además, se buscarán y limpiarán todas las referencias a este archivo en los archivos .dat correspondientes.';
        }
        
        Swal.fire({
            title: '¿Confirmar eliminación?',
            text: warningText,
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then(function(result) {
            if (result.isConfirmed) {
                Swal.fire({
                    title: 'Eliminando archivo...',
                    allowOutsideClick: false,
                    didOpen: function() {
                        Swal.showLoading();
                    }
                });
                
                var formData = new FormData();
                formData.append('action', 'delete_crm_file');
                formData.append('file_path', filePath);
                
                fetch('manage_config.pl', {
                    method: 'POST',
                    body: formData
                })
                .then(function(response) { return response.json(); })
                .then(function(data) {
                    if (data.ok) {
                        Swal.fire('Eliminado', data.msg, 'success').then(function() {
                            window.location.reload();
                        });
                    } else {
                        Swal.fire('Error', data.error || 'No se pudo eliminar el archivo', 'error');
                    }
                })
                .catch(function(err) {
                    console.error(err);
                    Swal.fire('Error', 'Error en la petición de red', 'error');
                });
            }
        });
    }

    // Funciones del Modal con DOM Teleportation Protocol
    function showCreateTableModal() {
        const modalEl = document.getElementById('createTableModal');
        if (modalEl.parentElement !== document.body) {
            document.body.appendChild(modalEl);
        }
        const bootstrapModal = new bootstrap.Modal(modalEl);
        bootstrapModal.show();
    }
    
    function updateMunicipiosCombo(stateId, selectedMnpio = '') {
        const mnpioSelect = document.getElementById('selectEstadoMnpio');
        if (!mnpioSelect) return;
        
        mnpioSelect.innerHTML = '<option value="">-- Seleccione un Municipio --</option>';
        
        if (stateId && window.municipiosPorEstado && window.municipiosPorEstado[stateId]) {
            const munis = window.municipiosPorEstado[stateId];
            munis.forEach(muni => {
                const opt = document.createElement('option');
                opt.value = muni;
                opt.textContent = muni;
                if (muni === selectedMnpio) {
                    opt.selected = true;
                }
                mnpioSelect.appendChild(opt);
            });
        } else {
            mnpioSelect.innerHTML = '<option value="">-- Seleccione primero un Estado --</option>';
        }
    }

    function showSelectCapituloModal() {
        const modalEl = document.getElementById('selectCapituloModal');
        if (modalEl) {
            if (modalEl.parentElement !== document.body) {
                document.body.appendChild(modalEl);
            }
            const bootstrapModal = new bootstrap.Modal(modalEl);
            bootstrapModal.show();
        }
    }

    function showSelectEstadoModal() {
        const modalEl = document.getElementById('selectEstadoModal');
        if (modalEl.parentElement !== document.body) {
            document.body.appendChild(modalEl);
        }
        
        // Mostrar/ocultar filtros dinámicos según la tabla de destino
        const fileInput = document.getElementById('selectEstadoFile');
        const cpFilterGroup = document.getElementById('cpFilterGroup');
        const cpInput = document.getElementById('selectEstadoCP');
        const mnpioFilterGroup = document.getElementById('mnpioFilterGroup');
        const mnpioInput = document.getElementById('selectEstadoMnpio');
        
        if (fileInput) {
            const activeFile = fileInput.value;
            
            if (activeFile === 'CAT_CLUES.dat') {
                if (cpFilterGroup) cpFilterGroup.classList.remove('d-none');
                if (cpInput) cpInput.required = false;
                
                if (mnpioFilterGroup) mnpioFilterGroup.classList.add('d-none');
                if (mnpioInput) {
                    mnpioInput.value = '';
                    mnpioInput.required = false;
                }
            } else if (activeFile === 'CODIGO_POSTAL.dat') {
                if (cpFilterGroup) cpFilterGroup.classList.add('d-none');
                if (cpInput) {
                    cpInput.value = '';
                    cpInput.required = false;
                }
                
                if (mnpioFilterGroup) mnpioFilterGroup.classList.remove('d-none');
                if (mnpioInput) mnpioInput.required = true;
                
                // Poblar el combo con el estado y municipio activo
                const activeState = document.getElementById('selectEstadoCombo').value;
                const currentMnpio = "$d_mnpio_esc";
                updateMunicipiosCombo(activeState, currentMnpio);
            } else {
                if (cpFilterGroup) cpFilterGroup.classList.add('d-none');
                if (cpInput) cpInput.value = '';
                if (mnpioFilterGroup) mnpioFilterGroup.classList.add('d-none');
                if (mnpioInput) {
                    mnpioInput.value = '';
                    mnpioInput.required = false;
                }
            }
        }
        
        const bootstrapModal = new bootstrap.Modal(modalEl);
        bootstrapModal.show();
    }

    function showAddRecordModal() {
        const modalEl = document.getElementById('addRecordModal');
        if (modalEl) {
            if (modalEl.parentElement !== document.body) {
                document.body.appendChild(modalEl);
            }
            const bootstrapModal = new bootstrap.Modal(modalEl);
            bootstrapModal.show();
        }
    }

    function showUploadCsvModal() {
        const modalEl = document.getElementById('uploadCsvModal');
        if (modalEl) {
            if (modalEl.parentElement !== document.body) {
                document.body.appendChild(modalEl);
            }
            const bootstrapModal = new bootstrap.Modal(modalEl);
            bootstrapModal.show();
        }
    }

    function showStructureModal() {
        const modalEl = document.getElementById('tableStructureModal');
        if (modalEl) {
            if (modalEl.parentElement !== document.body) {
                document.body.appendChild(modalEl);
            }
            const bootstrapModal = new bootstrap.Modal(modalEl);
            bootstrapModal.show();
        }
    }

    function goGlobal() {
        const val = document.getElementById('selectGlobal').value;
        if (val) {
            window.location.href = "?action=view&file=" + val + "&group=global";
        } else {
            Swal.fire('Atención', 'Por favor selecciona una tabla', 'warning');
        }
    }
    
    function goNom() {
        const val = document.getElementById('selectNom').value;
        if (val) {
            if (val === 'CODIGO_POSTAL.dat' || val === 'CAT_CLUES.dat') {
                const fileInput = document.getElementById('selectEstadoFile');
                if (fileInput) {
                    fileInput.value = val;
                }
                showSelectEstadoModal();
            } else if (val === 'CAT_CIE10_DIAGNOSTICOS.dat') {
                showSelectCapituloModal();
            } else {
                window.location.href = "?action=view&file=" + val + "&group=nom";
            }
        } else {
            Swal.fire('Atención', 'Por favor selecciona un catálogo', 'warning');
        }
    }
    
    \$(document).ready(function() {
        if (document.getElementById('tabulatorTreeGrid') && window.nestedTreeData) {
            new Tabulator("#tabulatorTreeGrid", {
                data: window.nestedTreeData,
                dataTree: true,
                dataTreeStartExpanded: false,
                layout: "fitColumns",
                rowClick: function(e, row) {
                    const rowData = row.getData();
                    if (rowData.type === 'Archivo') {
                        loadFileDetails(rowData.path);
                    }
                },
                columns: [
                    {title: "Nombre", field: "name", widthGrow: 3, responsive: 0, formatter: function(cell) {
                        const val = cell.getValue();
                        const rowData = cell.getRow().getData();
                        const icon = rowData.type === 'Carpeta' 
                            ? '<i class="bi bi-folder-fill text-warning me-2"></i>' 
                            : '<i class="bi bi-file-earmark-code text-info me-2"></i>';
                        return icon + val;
                    }},
                    {title: "Tipo", field: "type", widthGrow: 1},
                    {title: "Tamaño", field: "size", widthGrow: 1, hozAlign: "right"}
                ]
            });
        }

        if (\$('#tablaAdjuntos').length) {
            \$('#tablaAdjuntos').DataTable({
                language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                dom: '<"d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2"Bf>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                buttons: {
                    dom: {
                        container: {
                            className: 'dt-buttons export-toolbar'
                        },
                        button: {
                            className: 'btn-export'
                        }
                    },
                    buttons: [
                        { 
                            extend: 'copy', 
                            text: '<i class="bi bi-clipboard"></i> Copiar',
                            exportOptions: { columns: ':not(:last-child)' }
                        },
                        { 
                            extend: 'excel', 
                            text: '<i class="bi bi-file-earmark-excel"></i> Excel', 
                            title: 'Adjuntos_CRM',
                            exportOptions: { columns: ':not(:last-child)' }
                        },
                        { 
                            extend: 'pdf', 
                            text: '<i class="bi bi-file-earmark-pdf"></i> PDF', 
                            title: 'Adjuntos_CRM',
                            exportOptions: { columns: ':not(:last-child)' }
                        },
                        { 
                            extend: 'print', 
                            text: '<i class="bi bi-printer"></i> Imprimir',
                            title: '',
                            exportOptions: { columns: ':not(:last-child)' }
                        }
                    ]
                },
                pageLength: 5,
                responsive: true
            });
        }
    });
</script>
HTML

if ($target_file && $full_path && -e $full_path) {
    my $headers_js = join(',', map { qq('$_') } @headers);
    my $export_columns = ($group eq 'global') ? "':not(:last-child)'" : "'*'" ;
    
    print <<HTML;
    <script>
        window.cluesDetails = $clues_json;
        window.municipiosPorEstado = $municipios_json;
        \$(document).ready(function() {
            \$(document).on('change', '#selectEstadoCombo', function() {
                const stateId = \$(this).val();
                updateMunicipiosCombo(stateId);
            });

            if (\$('#tablaConfig').length) {
                \$('#tablaConfig').DataTable({
                    language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                    dom: '<"d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2"Bf>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                    buttons: {
                        dom: {
                            container: {
                                className: 'dt-buttons export-toolbar'
                            },
                            button: {
                                className: 'btn-export'
                            }
                        },
                        buttons: [
                            { 
                                extend: 'copy', 
                                text: '<i class="bi bi-clipboard"></i> Copiar',
                                exportOptions: { columns: $export_columns }
                            },
                            { 
                                extend: 'excel', 
                                text: '<i class="bi bi-file-earmark-excel"></i> Excel', 
                                title: 'Tabla_$target_file',
                                exportOptions: { columns: $export_columns }
                            },
                            { 
                                extend: 'pdf', 
                                text: '<i class="bi bi-file-earmark-pdf"></i> PDF', 
                                title: 'Tabla_$target_file',
                                exportOptions: { columns: $export_columns },
                                customize: function(doc) {
                                    doc.styles.tableHeader = { fillColor: '#0A2A66', color: 'white', alignment: 'center', bold: true, fontSize: 10 };
                                }
                            },
                            { 
                                extend: 'print', 
                                text: '<i class="bi bi-printer"></i> Imprimir',
                                title: '',
                                exportOptions: { columns: $export_columns }
                            }
                        ]
                    },
                    pageLength: 15,
                    responsive: true
                });
            }

            // Manejador del botón editar usando índices de columnas (inmune a caracteres especiales en cabeceras)
            \$(document).on('click', '.edit-btn', function() {
                const id = \$(this).data('id');
                \$('#id_to_edit').val(id);
                
                const \$row = \$(this).closest('tr');
                const \$tds = \$row.find('td');
                
                const headers = [$headers_js];
                headers.forEach((h, index) => {
                    const val = \$tds.eq(index).text() || '';
                    const inputEl = document.getElementById('edit_field_' + h);
                    if (inputEl) {
                        inputEl.value = val.trim();
                    }
                });
                
                const modalEl = document.getElementById('editRecordModal');
                if (modalEl) {
                    if (modalEl.parentElement !== document.body) {
                        document.body.appendChild(modalEl); // DOM Teleportation Protocol
                    }
                    const bootstrapModal = new bootstrap.Modal(modalEl);
                    bootstrapModal.show();
                }
            });

            // Manejador del clic en fila de CLUES para mostrar modal detalle
            \$(document).on('click', '.clues-row', function() {
                const id = \$(this).data('id');
                const data = window.cluesDetails ? window.cluesDetails[id] : null;
                if (!data) return;
                
                let html = '<div class="table-responsive" style="max-height: 60vh; overflow-y: auto; padding-right: 8px;">';
                html += '<table class="table table-striped table-sm align-middle mb-0">';
                html += '<tbody>';
                
                // Iterar campos y valores (2 columnas verticales campo y valor)
                for (const [key, value] of Object.entries(data)) {
                    const valEsc = value !== null && value !== undefined ? value : '';
                    html += `<tr>
                        <td class="fw-bold text-muted py-2 w-40" style="font-size: 0.85rem; border-color: rgba(0,0,0,0.05);">\${key}</td>
                        <td class="text-dark py-2 w-60" style="font-size: 0.85rem; border-color: rgba(0,0,0,0.05);">\${valEsc || '-'}</td>
                    </tr>`;
                }
                
                html += '</tbody></table></div>';
                
                \$('#cluesDetailModalBody').html(html);
                
                const modalEl = document.getElementById('cluesDetailModal');
                if (modalEl) {
                    if (modalEl.parentElement !== document.body) {
                        document.body.appendChild(modalEl); // DOM Teleportation Protocol
                    }
                    const bootstrapModal = new bootstrap.Modal(modalEl);
                    bootstrapModal.show();
                }
            });
        });
    </script>
HTML
}

# 3. Renderizamos la navegación inferior (Móvil)
render_bottom_nav('ajustes');

# 4. Renderizamos el pie de página
render_footer();

sub get_dat_tree {
    my ($dir, $counter_ref, $nested_list_ref) = @_;
    
    return unless -d $dir;
    opendir(my $dh, $dir) or return;
    my @items = sort grep { $_ ne '.' && $_ ne '..' && $_ ne '.git' && $_ ne 'xlsx' } readdir($dh);
    closedir($dh);
    
    foreach my $item (@items) {
        my $path = File::Spec->catfile($dir, $item);
        my $is_dir = -d $path ? 1 : 0;
        my $size = $is_dir ? 0 : -s $path;
        
        $$counter_ref++;
        my $id = $$counter_ref;
        
        my $rel_path = File::Spec->abs2rel($path, $DAT_DIR);
        $rel_path =~ s/\\/\//g;
        
        my $node = {
            id => $id,
            name => $item,
            path => $rel_path,
            type => $is_dir ? 'Carpeta' : 'Archivo',
            size => $is_dir ? '-' : sprintf("%.2f KB", $size / 1024)
        };
        push @$nested_list_ref, $node;
        
        if ($is_dir) {
            $node->{_children} = [];
            get_dat_tree($path, $counter_ref, $node->{_children});
            delete $node->{_children} unless scalar @{$node->{_children}};
        }
    }
}

1;
