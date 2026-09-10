#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use Fcntl qw(:flock);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

binmode STDOUT, ':utf8';

my $q = CGI->new;
my $sd = check_session($q);

print $q->header(-type => 'application/json', -charset => 'UTF-8');

# 1. Validación de Sesión y RBAC
unless ($sd->{session_ok}) {
    print encode_json({ success => 0, error => 'Sesión inválida o expirada.' });
    exit;
}

my $role = $sd->{role} || '';
my $id_empresa = $sd->{id_empresa};
$id_empresa = '0' if (!defined $id_empresa || $id_empresa eq '');

unless ($role eq 'Administrador Organizacion' || $role eq 'Administrador Global') {
    print encode_json({ success => 0, error => 'Acceso denegado. Se requieren permisos de Administrador de Organización.' });
    exit;
}

# Parámetros de entrada
my $folio_priv_inicio = int($q->param('folio_privados') || 1);
my $folio_pub_inicio  = int($q->param('folio_publicos') || 1);
my $confirmacion      = uc($q->param('confirmacion') || '');

$folio_priv_inicio = 1 if ($folio_priv_inicio < 1);
$folio_pub_inicio  = 1 if ($folio_pub_inicio < 1);

unless ($confirmacion eq 'CONFIRMAR' || $confirmacion eq 'RESETEAR') {
    print encode_json({ success => 0, error => 'Debe escribir la palabra CONFIRMAR para autorizar la purga de datos.' });
    exit;
}

my $id_raiz = catalogo_org_utils::resolver_id_raiz_catalogo($id_empresa);
my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');

# Resolver CLUE de la organización
my $org_clues = '';
if ($id_empresa eq '0') {
    $org_clues = 'QTSMP000116';
} else {
    my $neg_file = File::Spec->catfile($dat_dir, 'negocios.dat');
    if (-e $neg_file && open(my $fn, '<:encoding(UTF-8)', $neg_file)) {
        <$fn>;
        while (my $line = <$fn>) {
            chomp $line;
            my @f = split(/\|/, $line, -1);
            if ($f[0] eq $id_empresa) {
                $org_clues = $f[18] // '';
                last;
            }
        }
        close $fn;
    }
}
$org_clues ||= 'QTSMP000116' if ($id_empresa eq '0');

# 2. Identificar usuarios y médicos pertenecientes a esta organización (para filtrar consultas y citas)
# NOTA: En usuarios.dat NO se borra a ningún usuario.
my %uids_org;
my $usr_file = File::Spec->catfile($dat_dir, 'usuarios.dat');
if (-e $usr_file && open(my $fu, '<:encoding(UTF-8)', $usr_file)) {
    <$fu>; # cabecera
    while (my $line = <$fu>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @u = split(/!/, $line, -1);
        # u[0]: ID/user, u[6]: ID_negocio (ej: "0:0" o "12:1")
        my $u_id = $u[0];
        my $u_neg = $u[6] // '';
        my ($u_biz) = split(/:/, $u_neg);
        $u_biz //= '';
        if ($u_biz eq $id_empresa || ($id_empresa eq '0' && ($u_biz eq '0' || $u_biz eq ''))) {
            $uids_org{$u_id} = 1;
        }
    }
    close $fu;
}

eval {
    # 3. Purga en folios_recibos_privados.dat
    my $priv_rec_file = File::Spec->catfile($dat_dir, 'folios_recibos_privados.dat');
    if (-e $priv_rec_file && open(my $fh_rp, '<:encoding(UTF-8)', $priv_rec_file)) {
        my @lines = <$fh_rp>;
        close $fh_rp;
        my $cab = shift @lines;
        chomp $cab if defined $cab;
        my @conservar;
        foreach my $l (@lines) {
            chomp $l; next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $neg = $c[2] // '';
            # Si no es de esta empresa, se conserva
            if ($neg ne $id_empresa && !($id_empresa eq '0' && ($neg eq '0' || $neg eq ''))) {
                push @conservar, $l;
            }
        }
        if (open(my $fh_out, '>:encoding(UTF-8)', $priv_rec_file)) {
            flock($fh_out, LOCK_EX);
            print $fh_out "$cab\n" if defined $cab;
            print $fh_out "$_\n" foreach @conservar;
            close $fh_out;
        }
    }

    # 4. Purga en folios_recibos_publicos.dat
    my $pub_rec_file = File::Spec->catfile($dat_dir, 'folios_recibos_publicos.dat');
    if (-e $pub_rec_file && open(my $fh_rpub, '<:encoding(UTF-8)', $pub_rec_file)) {
        my @lines = <$fh_rpub>;
        close $fh_rpub;
        my $cab = shift @lines;
        chomp $cab if defined $cab;
        my @conservar;
        foreach my $l (@lines) {
            chomp $l; next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $neg = $c[2] // '';
            if ($neg ne $id_empresa && !($id_empresa eq '0' && ($neg eq '0' || $neg eq ''))) {
                push @conservar, $l;
            }
        }
        if (open(my $fh_out, '>:encoding(UTF-8)', $pub_rec_file)) {
            flock($fh_out, LOCK_EX);
            print $fh_out "$cab\n" if defined $cab;
            print $fh_out "$_\n" foreach @conservar;
            close $fh_out;
        }
    }

    # 5. Purga en estado_cuenta.dat
    my $edo_file = File::Spec->catfile($dat_dir, 'estado_cuenta.dat');
    if (-e $edo_file && open(my $fh_edo, '<:encoding(UTF-8)', $edo_file)) {
        my @lines = <$fh_edo>;
        close $fh_edo;
        my $cab = shift @lines;
        chomp $cab if defined $cab;
        my @conservar;
        foreach my $l (@lines) {
            chomp $l; next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            # c[9]: ID_MEDICO
            my $m_id = $c[9] // '';
            if (!$uids_org{$m_id}) {
                push @conservar, $l;
            }
        }
        if (open(my $fh_out, '>:encoding(UTF-8)', $edo_file)) {
            flock($fh_out, LOCK_EX);
            print $fh_out "$cab\n" if defined $cab;
            print $fh_out "$_\n" foreach @conservar;
            close $fh_out;
        }
    }

    # 6. Purga en citas.dat
    my $citas_file = File::Spec->catfile($dat_dir, 'citas.dat');
    if (-e $citas_file && open(my $fh_cit, '<:encoding(UTF-8)', $citas_file)) {
        my @lines = <$fh_cit>;
        close $fh_cit;
        my $cab = shift @lines;
        chomp $cab if defined $cab;
        my @conservar;
        foreach my $l (@lines) {
            chomp $l; next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $m_id = $c[1] // '';
            if (!$uids_org{$m_id}) {
                push @conservar, $l;
            }
        }
        if (open(my $fh_out, '>:encoding(UTF-8)', $citas_file)) {
            flock($fh_out, LOCK_EX);
            print $fh_out "$cab\n" if defined $cab;
            print $fh_out "$_\n" foreach @conservar;
            close $fh_out;
        }
    }

    # 7. Purga en consultas_clinicas.dat, recetas.dat, consentimientos.dat, consulta_draft.dat
    foreach my $fn_clinica ('consultas_clinicas.dat', 'recetas.dat', 'consentimientos.dat', 'consulta_draft.dat') {
        my $path_clin = File::Spec->catfile($dat_dir, $fn_clinica);
        if (-e $path_clin && open(my $fh_cl, '<:encoding(UTF-8)', $path_clin)) {
            my @lines = <$fh_cl>;
            close $fh_cl;
            my $cab = shift @lines;
            chomp $cab if defined $cab;
            my @conservar;
            foreach my $l (@lines) {
                chomp $l; next if $l =~ /^\s*$/;
                my @c = split(/\|/, $l, -1);
                my $m_id = $c[3] // '';
                if (!$uids_org{$m_id}) {
                    push @conservar, $l;
                }
            }
            if (open(my $fh_out, '>:encoding(UTF-8)', $path_clin)) {
                flock($fh_out, LOCK_EX);
                print $fh_out "$cab\n" if defined $cab;
                print $fh_out "$_\n" foreach @conservar;
                close $fh_out;
            }
        }
    }

    # 8. Purga en gastos.dat
    my $gastos_file = File::Spec->catfile($dat_dir, 'gastos.dat');
    if (-e $gastos_file && open(my $fh_g, '<:encoding(UTF-8)', $gastos_file)) {
        my @lines = <$fh_g>;
        close $fh_g;
        my $cab = shift @lines;
        chomp $cab if defined $cab;
        my @conservar;
        foreach my $l (@lines) {
            chomp $l; next if $l =~ /^\s*$/;
            my @c = split(/\|/, $l, -1);
            my $m_id = $c[9] // '';
            if (!$uids_org{$m_id}) {
                push @conservar, $l;
            }
        }
        if (open(my $fh_out, '>:encoding(UTF-8)', $gastos_file)) {
            flock($fh_out, LOCK_EX);
            print $fh_out "$cab\n" if defined $cab;
            print $fh_out "$_\n" foreach @conservar;
            close $fh_out;
        }
    }

    # 9. Limpiar pacientes_privados_${org_clues}.dat (pacientes de mostrador)
    if ($org_clues) {
        my $priv_pac_file = File::Spec->catfile($dat_dir, 'catalogos_CLUE', $org_clues, "pacientes_privados_${org_clues}.dat");
        if (-e $priv_pac_file) {
            if (open(my $fh_pp, '>:encoding(UTF-8)', $priv_pac_file)) {
                flock($fh_pp, LOCK_EX);
                print $fh_pp "ID_PACIENTE|NOMBRE_COMPLETO|FECHA_REGISTRO\n";
                close $fh_pp;
            }
        }
    }

    # 10. Actualizar Contadores de Folios solicitados por el usuario
    # Para que el próximo folio sea $folio_inicio, seteamos LAST_FOLIO = $folio_inicio - 1
    my $last_priv_target = $folio_priv_inicio - 1;
    my $last_pub_target  = $folio_pub_inicio - 1;
    $last_priv_target = 0 if $last_priv_target < 0;
    $last_pub_target  = 0 if $last_pub_target < 0;

    my $rutas_contadores = catalogo_org_utils::obtener_rutas_contadores($id_raiz);

    # Actualizar contador privado
    my $file_cont_priv = $rutas_contadores->{privados};
    my @lines_cp;
    my $enc_priv = 0;
    if (-e $file_cont_priv && open(my $fh_cp, '<:encoding(UTF-8)', $file_cont_priv)) {
        @lines_cp = <$fh_cp>;
        close $fh_cp;
    }
    my $cab_cp = shift @lines_cp;
    chomp $cab_cp if defined $cab_cp;
    $cab_cp ||= "ID_NEGOCIO|ID_SUCURSAL|LAST_FOLIO";
    my @nuevas_cp;
    foreach my $l (@lines_cp) {
        chomp $l; next if $l =~ /^\s*$/;
        my @c = split(/\|/, $l, -1);
        if ($c[0] eq $id_empresa) {
            $c[2] = $last_priv_target;
            $l = join('|', @c);
            $enc_priv = 1;
        }
        push @nuevas_cp, $l;
    }
    push @nuevas_cp, "$id_empresa|0|$last_priv_target" unless $enc_priv;
    if (open(my $fh_out_cp, '>:encoding(UTF-8)', $file_cont_priv)) {
        flock($fh_out_cp, LOCK_EX);
        print $fh_out_cp "$cab_cp\n";
        print $fh_out_cp "$_\n" foreach @nuevas_cp;
        close $fh_out_cp;
    }

    # Actualizar contador público
    my $file_cont_pub = $rutas_contadores->{publicos};
    my @lines_cpub;
    my $enc_pub = 0;
    if (-e $file_cont_pub && open(my $fh_cpub, '<:encoding(UTF-8)', $file_cont_pub)) {
        @lines_cpub = <$fh_cpub>;
        close $fh_cpub;
    }
    my $cab_cpub = shift @lines_cpub;
    chomp $cab_cpub if defined $cab_cpub;
    $cab_cpub ||= "ID_NEGOCIO|ID_SUCURSAL|LAST_FOLIO";
    my @nuevas_cpub;
    foreach my $l (@lines_cpub) {
        chomp $l; next if $l =~ /^\s*$/;
        my @c = split(/\|/, $l, -1);
        if ($c[0] eq $id_empresa) {
            $c[2] = $last_pub_target;
            $l = join('|', @c);
            $enc_pub = 1;
        }
        push @nuevas_cpub, $l;
    }
    push @nuevas_cpub, "$id_empresa|0|$last_pub_target" unless $enc_pub;
    if (open(my $fh_out_cpub, '>:encoding(UTF-8)', $file_cont_pub)) {
        flock($fh_out_cpub, LOCK_EX);
        print $fh_out_cpub "$cab_cpub\n";
        print $fh_out_cpub "$_\n" foreach @nuevas_cpub;
        close $fh_out_cpub;
    }
};

if ($@) {
    print encode_json({
        success => 0,
        error => "Error al ejecutar el reset de la organización: $@"
    });
    exit;
}

print encode_json({
    success => 1,
    msg => "Reset operativo completado exitosamente. Todos los usuarios creados permanecen intactos. Los folios iniciarán en: Recibos Privados #$folio_priv_inicio y Recibos Públicos #$folio_pub_inicio.",
    folio_privados => $folio_priv_inicio,
    folio_publicos => $folio_pub_inicio
});
