#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use FindBin;
use File::Spec;
use Cwd qw(abs_path);
use JSON::PP qw(encode_json);

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS ---
use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $q = CGI->new;
my $session_data = check_session();

# 1. Validación de Sesión
unless ($session_data->{session_ok}) {
    print $q->header(-type => 'application/json', -status => '401 Unauthorized', -charset => 'UTF-8');
    print encode_json({ status => 'error', message => 'Sesión expirada o no válida.' });
    exit;
}

# 2. Control de Acceso Estricto RBAC: Exclusivo Administrador Global
my $role = $session_data->{role} || '';
unless ($role =~ /Administrador Global/i) {
    print $q->header(-type => 'application/json', -status => '403 Forbidden', -charset => 'UTF-8');
    print encode_json({ status => 'error', message => 'Acceso denegado: Acción exclusiva de Administrador Global.' });
    exit;
}

# 3. Doble Candado: Posicionamiento garantizado en la raíz (public_html)
my $root_dir = abs_path("$FindBin::Bin/..");
chdir($root_dir) or do {
    print $q->header(-type => 'application/json', -status => '500 Internal Error', -charset => 'UTF-8');
    print encode_json({ status => 'error', message => "No se pudo cambiar al directorio raíz: $!" });
    exit;
};

my $dat_dir   = File::Spec->catdir($root_dir, 'dat');
my $lock_file = File::Spec->catfile($dat_dir, 'hot_deploy.lock');
my $log_file  = File::Spec->catfile($dat_dir, 'hot_deploy.log');

my $action = $q->param('action') || 'status';

if ($action eq 'trigger') {
    # Verificar si ya hay un despliegue en curso
    if (-f $lock_file) {
        my $mtime = (stat($lock_file))[9] || time;
        if ((time - $mtime) < 600) {
            print $q->header(-type => 'application/json', -charset => 'UTF-8');
            print encode_json({
                status  => 'already_running',
                message => 'Existe una actualización en ejecución actualmente.'
            });
            exit;
        } else {
            unlink($lock_file); # Limpiar lock huérfano
        }
    }

    # Iniciar hot_deploy.sh en segundo plano
    my $cmd = "";
    if ($^O =~ /MSWin32/i) {
        # Compatibilidad en entorno local Windows con Git Bash
        my $git_bash = 'C:\Program Files\Git\bin\bash.exe';
        if (-f $git_bash) {
            $cmd = qq{"$git_bash" "$root_dir/hot_deploy.sh" > "$log_file" 2>&1};
        } else {
            $cmd = qq{bash "$root_dir/hot_deploy.sh" > "$log_file" 2>&1};
        }
        # En Windows ejecutar de fondo con start /b
        system("start /b $cmd");
    } else {
        # Entorno Linux / cPanel (Hostgator)
        $cmd = qq{cd "$root_dir" && bash hot_deploy.sh > "$log_file" 2>&1 &};
        system($cmd);
    }

    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print encode_json({
        status  => 'started',
        message => 'Actualización en caliente iniciada en segundo plano con éxito.'
    });
    exit;
}
elsif ($action eq 'status') {
    my $is_running = (-f $lock_file) ? 1 : 0;
    my @lines = ();

    if (-f $log_file && open(my $fh, '<:encoding(UTF-8)', $log_file)) {
        my @all = <$fh>;
        close($fh);
        # Tomar las últimas 35 líneas del log
        my $start = scalar(@all) > 35 ? scalar(@all) - 35 : 0;
        @lines = @all[$start .. $#all];
    }

    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print encode_json({
        status  => 'success',
        running => $is_running,
        log     => join('', @lines)
    });
    exit;
}
else {
    print $q->header(-type => 'application/json', -status => '400 Bad Request', -charset => 'UTF-8');
    print encode_json({ status => 'error', message => 'Acción desconocida.' });
    exit;
}
