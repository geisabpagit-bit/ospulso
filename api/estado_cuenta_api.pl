#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON::PP qw(encode_json decode_json);
use FindBin;
use File::Spec;

# Protocolo SDA-11.1: Rutas Absolutas Dinámicas
my $dat_path = File::Spec->catdir($FindBin::Bin, '..', 'dat');

require "$FindBin::Bin/../auth/check_session.pl";
my $session_data = check_session();
unless ($session_data->{session_ok}) {
    print CGI->new->header(-type => 'application/json', -status => '401 Unauthorized');
    print JSON::PP->new->utf8(1)->encode({ error => "Sesión inválida o expirada" });
    exit;
}

my $q = CGI->new;
my $accion = $q->param('accion') || '';
my $id_p = $q->param('id_paciente') || '';
my $id_m_req = $q->param('id_medico') || 'SISTEMA';
my $id_os_manual = $q->param('id_os_manual') || '';
my $json_engine = JSON::PP->new->utf8(1);

sub responder {
    my ($data) = @_;
    print $q->header(-type => 'application/json', -charset => 'UTF-8');
    print $json_engine->encode($data);
    exit;
}

if ($accion eq 'get_catalogo') {
    my @s = (); my @p = ();
    my $serv_file = File::Spec->catfile($dat_path, 'servicios.dat');
    my $prod_file = File::Spec->catfile($dat_path, 'productos.dat');

    if (-e $serv_file) {
        open(my $fh, "<:encoding(UTF-8)", $serv_file); <$fh>;
        while (<$fh>) { chomp; my @c = split /\|/; push @s, { id => "S-$c[0]", nombre => $c[1], precio => $c[2] }; }
        close $fh;
    }
    if (-e $prod_file) {
        open(my $fh, "<:encoding(UTF-8)", $prod_file); <$fh>;
        while (<$fh>) { chomp; my @c = split /\|/; push @p, { id => "P-$c[0]", nombre => $c[1], precio => $c[2] }; }
        close $fh;
    }
    responder({ servicios => \@s, productos => \@p });

} elsif ($accion eq 'get_historial') {
    unless ($id_p) { responder({ error => "ID no proporcionado" }); }
    my @h = (); 
    my ($saldo_total, $cargos_sum, $abonos_sum) = (0, 0, 0);
    my $ec_file = File::Spec->catfile($dat_path, 'estado_cuenta.dat');
    
    if (-e $ec_file) {
        open(my $fh, "<:encoding(UTF-8)", $ec_file); <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @v = split /\|/, $line;
            # Estructura: ID_OS|ID_MOV|ID_PAC|TIPO|CONCEPTO|BASE|IVA|TOTAL|FECHA|ID_MED|NOTAS
            if (@v >= 9 && $v[2] eq $id_p) {
                my $tot = $v[7] + 0;
                push @h, { id_os => $v[0], id_mov => $v[1], tipo => $v[3], concepto => $v[4], total => $tot, fecha => $v[8] };
                if ($v[3] =~ /Cargo/i) { $saldo_total += $tot; $cargos_sum += $tot; } 
                else { $saldo_total -= $tot; $abonos_sum += $tot; }
            }
        }
        close $fh;
    }
    my @h_sorted = sort { ($b->{id_mov} || 0) <=> ($a->{id_mov} || 0) } @h;
    
    responder({ 
        historial => \@h_sorted, 
        saldo => $saldo_total, 
        cargos => $cargos_sum, 
        abonos => $abonos_sum 
    });

} elsif ($accion eq 'add_cargo') {
    my $pay = scalar($q->param('payload')) || '[]';
    my $items = eval { $json_engine->decode($pay) } || [];
    my $iva_f = (scalar($q->param('aplica_iva')) || '0') eq '1' ? 1 : 0;
    my $t = time();
    my @lt = localtime($t);
    my $f = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $lt[5]+1900, $lt[4]+1, $lt[3], $lt[2], $lt[1], $lt[0]);
    my $f_folio = sprintf("%04d%02d%02d", $lt[5]+1900, $lt[4]+1, $lt[3]);
    
    # GENERACIÓN DE ID_OS (Protocolo v3.5.5 Diamond)
    my $id_os = $id_os_manual;
    
    if (!$id_os) {
        my ($id_neg, $id_mat) = (1, 0);
        my $inc = 0;
        
        # 1. ID_Negocio del Médico
        my $u_file = File::Spec->catfile($dat_path, 'usuarios.dat');
        if (-e $u_file) {
            open(my $fh, "<:encoding(UTF-8)", $u_file); <$fh>;
            while(<$fh>) { chomp; my @c = split /!/; if($c[0] eq $id_m_req) { $id_neg = $c[6] // 1; last; } }
            close $fh;
        }
        
        # 2. ID_Matriz del Negocio
        my $n_file = File::Spec->catfile($dat_path, 'negocios.dat');
        if (-e $n_file) {
            open(my $fh, "<:encoding(UTF-8)", $n_file); <$fh>;
            while(<$fh>) { chomp; my @c = split /\|/; if($c[0] eq $id_neg) { $id_mat = $c[2] // 0; last; } }
            close $fh;
        }
        
        # 3. Incremental
        my $inc_file = File::Spec->catfile($dat_path, 'os_incremental.dat');
        if (-e $inc_file) {
            open(my $fh, "+<:encoding(UTF-8)", $inc_file);
            $inc = <$fh> // 0; chomp $inc; $inc++;
            seek($fh, 0, 0); truncate($fh, 0); print $fh "$inc\n";
            close $fh;
        }
        # Refactor: [YYYYMMDD]-[ID_NEG][ID_MAT]-[ID_MED]-[ID_PAC]-[INC]
        $id_os = "$f_folio-$id_neg$id_mat-$id_m_req-$id_p-$inc";
    }
    
    my $id_mov = time();
    my $ec_file = File::Spec->catfile($dat_path, 'estado_cuenta.dat');

    open(my $fh, ">>:encoding(UTF-8)", $ec_file);
    foreach my $it (@$items) {
        my $base = $it->{precio} * ($it->{cantidad} || 1);
        my $iva = $iva_f ? ($base * 0.16) : 0;
        my $total = $base + $iva; $id_mov++;
        # ID_OS|ID_MOV|ID_PAC|TIPO|CONCEPTO|BASE|IVA|TOTAL|FECHA|ID_MED|NOTAS
        print $fh "$id_os|$id_mov|$id_p|Cargo|$it->{nombre}|$base|$iva|$total|$f|$id_m_req|\n";
    }
    close $fh;
    responder({ success => 1, os => $id_os });

} elsif ($accion eq 'add_abono') {
    my $m = scalar($q->param('monto')) || 0; $m += 0;
    my $met = scalar($q->param('metodo')) || 'Efectivo';
    my $not = scalar($q->param('notas')) || '';
    my $t = time();
    my @lt = localtime($t);
    my $f = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $lt[5]+1900, $lt[4]+1, $lt[3], $lt[2], $lt[1], $lt[0]);
    my $f_folio = sprintf("%04d%02d%02d", $lt[5]+1900, $lt[4]+1, $lt[3]);

    # GENERACIÓN DE FOLIO DE RECIBO (REC)
    my ($id_neg, $id_mat) = (1, 0);
    my $inc = 0;
    
    # 1. ID_Negocio del Médico
    my $u_file = File::Spec->catfile($dat_path, 'usuarios.dat');
    if (-e $u_file) {
        open(my $fh, "<:encoding(UTF-8)", $u_file); <$fh>;
        while(<$fh>) { chomp; my @c = split /!/; if($c[0] eq $id_m_req) { $id_neg = $c[6] // 1; last; } }
        close $fh;
    }
    
    # 2. ID_Matriz del Negocio
    my $n_file = File::Spec->catfile($dat_path, 'negocios.dat');
    if (-e $n_file) {
        open(my $fh, "<:encoding(UTF-8)", $n_file); <$fh>;
        while(<$fh>) { chomp; my @c = split /\|/; if($c[0] eq $id_neg) { $id_mat = $c[2] // 0; last; } }
        close $fh;
    }
    
    # 3. Incremental Abonos
    my $inc_file = File::Spec->catfile($dat_path, 'abono_incremental.dat');
    if (-e $inc_file) {
        open(my $fh, "+<:encoding(UTF-8)", $inc_file);
        $inc = <$fh> // 0; chomp $inc; $inc++;
        seek($fh, 0, 0); truncate($fh, 0); print $fh "$inc\n";
        close $fh;
    }
    
    my $id_os = "REC-$f_folio-$id_neg$id_mat-$id_m_req-$id_p-$inc";
    my $id_mov = time();
    my $ec_file = File::Spec->catfile($dat_path, 'estado_cuenta.dat');

    open(my $fh, ">>:encoding(UTF-8)", $ec_file);
    # ID_OS|ID_MOV|ID_PAC|TIPO|CONCEPTO|BASE|IVA|TOTAL|FECHA|ID_MED|NOTAS
    print $fh "$id_os|$id_mov|$id_p|Abono|Pago con $met|0|0|$m|$f|$id_m_req|$not\n";
    close $fh;
    responder({ success => 1, folio => $id_os });

} elsif ($accion eq 'delete_movimiento') {
    my $id_m = scalar($q->param('id_mov')) || '';
    my @l;
    my $ec_file = File::Spec->catfile($dat_path, 'estado_cuenta.dat');

    open(my $fh, "<:encoding(UTF-8)", $ec_file);
    my $h = <$fh>; push @l, $h if $h;
    while (my $line = <$fh>) { 
        my @c = split /\|/, $line; 
        push @l, $line unless $c[1] eq $id_m; 
    }
    close $fh;
    open(my $wh, ">:encoding(UTF-8)", $ec_file); print $wh $_ for @l; close $wh;
    responder({ success => 1 });

} elsif ($accion eq 'update_movimiento') {
    my $id_m = scalar($q->param('id_mov')) || '';
    my @l;
    my $ec_file = File::Spec->catfile($dat_path, 'estado_cuenta.dat');

    open(my $fh, "<:encoding(UTF-8)", $ec_file);
    my $h = <$fh>; push @l, $h if $h;
    while (my $line = <$fh>) {
        my @c = split /\|/, $line;
        if ($c[1] eq $id_m) {
            $c[4] = scalar($q->param('concepto')); 
            $c[7] = scalar($q->param('monto')); 
            $c[5] = $c[7];
            $line = join('|', @c) . "\n";
            $line =~ s/\n+$/\n/;
        }
        push @l, $line;
    }
    close $fh;
    open(my $wh, ">:encoding(UTF-8)", $ec_file); print $wh $_ for @l; close $wh;
    responder({ success => 1 });
}

responder({ error => "Sin accion reconocida" });
1;
