#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/..";
use CGI;
use JSON;
use File::Spec;

BEGIN {
    $ENV{TZ} = 'America/Mexico_City';
}
use POSIX qw(tzset);
eval { tzset(); };

require "$FindBin::Bin/../auth/check_session.pl";

my $q = CGI->new;
my $session_data = main::check_session();

print $q->header(-type => 'application/json', -charset => 'utf-8');

if (!$session_data || ($session_data->{role} ne 'Administrador Global' && $session_data->{role} ne 'Administrador Organizacion')) {
    print encode_json({ status => 'error', message => 'Acceso denegado.' });
    exit;
}

my $admin_role = $session_data->{role};
my $admin_empresa = $session_data->{id_empresa} || '';

# Leer configuración global
my $timeout_minutes = 30;
my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while(<$cf>) {
        chomp;
        my @f = split(/\|/);
        if ($f[0] eq '0' && $f[1] eq 'GLOBAL_SESSION_TIMEOUT') {
            $timeout_minutes = int($f[2]) if $f[2] =~ /^\d+$/;
            last;
        }
    }
    close($cf);
}
my $timeout_seconds = $timeout_minutes * 60;
my $current_time = time();

my @online_users;

eval {
    my $session_dir = File::Spec->catdir($FindBin::Bin, '..', 'auth', 'sessions');
    if (!-d $session_dir) {
        $session_dir = File::Spec->catdir($FindBin::Bin, 'sessions');
    }
    
    opendir(my $dh, $session_dir) or die "No se pudo leer directorio de sesiones: $!";
    my @files = grep { /^cgisess_/ && -f File::Spec->catfile($session_dir, $_) } readdir($dh);
    closedir($dh);
    
    foreach my $file (@files) {
        my $filepath = File::Spec->catfile($session_dir, $file);
        
        # Leer archivo sin afectar ATIME
        if (open(my $fh, '<:encoding(UTF-8)', $filepath)) {
            local $/ = undef;
            my $content = <$fh>;
            close($fh);
            
            my ($atime) = $content =~ /'_SESSION_ATIME'\s*=>\s*(\d+)/;
            next unless $atime;
            
            my $diff = $current_time - $atime;
            
            if ($diff <= $timeout_seconds) {
                my ($uid) = $content =~ /'uid'\s*=>\s*'([^']+)'/;
                my ($usuario) = $content =~ /'usuario'\s*=>\s*'([^']+)'/;
                my ($id_empresa) = $content =~ /'id_empresa'\s*=>\s*'([^']+)'/;
                my ($role) = $content =~ /'role'\s*=>\s*'([^']+)'/;
                my ($ip) = $content =~ /'_SESSION_REMOTE_ADDR'\s*=>\s*'([^']+)'/;
                
                # RBAC
                if ($admin_role eq 'Administrador Organizacion') {
                    next if !$id_empresa || $id_empresa ne $admin_empresa;
                }
                
                my $mins_ago = int($diff / 60);
                my $actividad = $mins_ago == 0 ? "Hace un momento" : "Hace $mins_ago min";
                
                push @online_users, {
                    usuario => $usuario || 'Desconocido',
                    role => $role || 'N/A',
                    ip => $ip || 'N/A',
                    actividad => $actividad
                } if $uid;
            }
        }
    }
};

if ($@) {
    print encode_json({ status => 'error', message => "Error del Servidor (Protocolo 500 Guard): $@" });
} else {
    print encode_json({ status => 'success', data => \@online_users, timeout_config => $timeout_minutes });
}
