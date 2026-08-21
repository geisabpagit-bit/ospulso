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

my $q = CGI->new;
require "$FindBin::Bin/../auth/check_session.pl";
require "$FindBin::Bin/../utils/catalogo_org_utils.pl";
my $session_data = check_session($q);
unless ($session_data->{session_ok}) {
    print $q->header(-type => 'application/json', -status => '401 Unauthorized');
    print JSON::PP->new->utf8(1)->encode({ error => "Sesión inválida o expirada" });
    exit;
}

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

    # Resolver catalogo de la organizacion del usuario
    my $id_empresa = $session_data->{id_empresa} || 0;
    my $id_raiz = $id_empresa
        ? catalogo_org_utils::resolver_id_raiz_catalogo($id_empresa)
        : 0;

    my ($serv_file, $prod_file);
    if ($id_raiz) {
        my $rutas = catalogo_org_utils::obtener_rutas_catalogo($id_raiz);
        $serv_file = $rutas->{servicios};
        $prod_file = $rutas->{productos};
        # Si no existen aun, semillarlos desde el global (idempotente)
        unless (-e $serv_file && -e $prod_file) {
            catalogo_org_utils::crear_catalogo_org_desde_global($id_raiz);
        }
    }

    # Fallback al catalogo global si no hay archivos de org
    $serv_file = File::Spec->catfile($dat_path, 'servicios.dat')
        unless $serv_file && -e $serv_file;
    $prod_file = File::Spec->catfile($dat_path, 'productos.dat')
        unless $prod_file && -e $prod_file;

    if (-e $serv_file) {
        open(my $fh, "<:encoding(UTF-8)", $serv_file); <$fh>;
        while (<$fh>) {
            chomp; next if /^\s*$/;
            my @c = split /\|/, $_, -1;
            push @s, { id => "S-$c[0]", nombre => $c[1], precio => $c[2]+0 };
        }
        close $fh;
    }
    if (-e $prod_file) {
        open(my $fh, "<:encoding(UTF-8)", $prod_file); <$fh>;
        while (<$fh>) {
            chomp; next if /^\s*$/;
            my @c = split /\|/, $_, -1;
            push @p, { id => "P-$c[0]", nombre => $c[1], precio => $c[2]+0 };
        }
        close $fh;
    }
    responder({ servicios => \@s, productos => \@p });

} elsif ($accion eq 'get_historial') {
    my @h = (); 
    my ($saldo_total, $cargos_sum, $abonos_sum) = (0, 0, 0);
    my $ec_file = File::Spec->catfile($dat_path, 'estado_cuenta.dat');
    my $pac_file = File::Spec->catfile($dat_path, 'pacientes.dat');
    my %nombres = ();
    
    my $mi_org = $session_data->{id_empresa} || 'X';
    my $rol = $session_data->{role};

    if (-e $pac_file) {
        open(my $fh_p, "<:encoding(UTF-8)", $pac_file); <$fh_p>;
        while (my $lp = <$fh_p>) { 
            chomp $lp; 
            my @vp = split /\|/, $lp; 
            my $tenant_pac = $vp[13] // '';
            my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
            
            my $es_mi_tenant = 0;
            if ($rol eq 'Administrador Global') { $es_mi_tenant = 1; }
            elsif ($org_pac && $org_pac eq $mi_org) { $es_mi_tenant = 1; }
            elsif (!$org_pac && ($rol =~ /Administrador Organizacion|Soporte/i || $vp[1] eq $id_m_req)) { $es_mi_tenant = 1; }
            
            if ($es_mi_tenant) {
                # vp[2] es el Nombre del Paciente
                $nombres{$vp[0]} = $vp[2]; 
            }
        }
        close $fh_p;
    }
    
    my $org_clues = '';
    my $negocios_file = File::Spec->catfile($dat_path, 'negocios.dat');
    if (-e $negocios_file && open(my $nf, '<:encoding(UTF-8)', $negocios_file)) {
        while (my $line = <$nf>) {
            chomp($line);
            my @f = split(/\|/, $line, -1);
            if ($f[0] eq $mi_org) {
                $org_clues = $f[18] // '';
                last;
            }
        }
        close($nf);
    }
    
    my %mapa_folios = ();
    if ($org_clues eq 'QTSMP000116') {
        foreach my $f_name ('folios_recibos_privados.dat', 'folios_recibos_publicos.dat') {
            my $f_path = File::Spec->catfile($dat_path, $f_name);
            if (-e $f_path && open(my $fh_f, '<:encoding(UTF-8)', $f_path)) {
                <$fh_f>;
                while (my $line = <$fh_f>) {
                    chomp $line;
                    my @f = split(/\|/, $line, -1);
                    if (@f > 4 && $f[4]) {
                        $mapa_folios{$f[4]} = $f[1];
                    }
                }
                close($fh_f);
            }
        }
    }
    if (-e $ec_file) {
        open(my $fh, "<:encoding(UTF-8)", $ec_file); <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my @v = split /\|/, $line;
            if (@v >= 9) {
                if (!$id_p || $v[2] eq $id_p) {
                    my $nom_pac = $nombres{$v[2]};
                    next unless $nom_pac; # Blindaje Multi-Tenant Activo: Si no es mi paciente, ignoro la transaccion
                    
                    my $tot = $v[7] + 0;
                    my $tipo = $v[3] || '';
                    my $notas = $v[10] || '';
                    my $is_legacy_cot = ($tipo =~ /Cargo/i && $notas =~ /Presupuesto|Cotizacion/i) ? 1 : 0;
                    
                    my $id_os = $v[0];
                    if ($org_clues eq 'QTSMP000116' && $mapa_folios{$id_os}) {
                        $id_os = $mapa_folios{$id_os};
                    }
                    
                    push @h, { id_os => $id_os, id_mov => $v[1], tipo => $tipo, concepto => $v[4], total => $tot, fecha => $v[8], id_paciente => $v[2], paciente_nombre => $nom_pac, alias => ($v[11] || '') };
                    
                    unless ($is_legacy_cot) {
                        if ($tipo =~ /Cargo/i) { $saldo_total += $tot; $cargos_sum += $tot; }
                        else { $saldo_total -= $tot; $abonos_sum += $tot; }
                    }
                }
            }
        }
        close $fh;
    }
    my @h_sorted = sort { ($b->{id_mov} || 0) <=> ($a->{id_mov} || 0) } @h;
    
    # Cotizaciones: leer desde cotizaciones.dat (fuente canónica)
    my $cot_file = File::Spec->catfile($dat_path, 'cotizaciones.dat');
    my $cotizaciones_sum = 0;
    if (-e $cot_file) {
        open(my $fhc, '<:encoding(UTF-8)', $cot_file);
        <$fhc>; # saltar cabecera
        while (my $cline = <$fhc>) {
            chomp $cline;
            next if $cline =~ /^\s*$/;
            my @cv = split /\|/, $cline, -1;
            # ID_COT|ID_PACIENTE|NOMBRE|TOTAL|FECHA|ID_MEDICO
            next unless @cv >= 4;
            if (!$id_p || $cv[1] eq $id_p) {
                $cotizaciones_sum += ($cv[3] + 0);
            }
        }
        close $fhc;
    }

    responder({
        historial   => \@h_sorted,
        saldo       => $saldo_total,
        cargos      => $cargos_sum,
        abonos      => $abonos_sum,
        cotizaciones => $cotizaciones_sum
    });

} elsif ($accion eq 'add_cargo') {
    my $pay = scalar($q->param('payload')) || '[]';
    my $items = eval { $json_engine->decode($pay) } || [];
    my $iva_f = (scalar($q->param('aplica_iva')) || '0') eq '1' ? 1 : 0;
    my $alias_os = scalar($q->param('alias')) || '';
    my $aplica_para = scalar($q->param('aplica_para')) || 'Consulta';
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
        # ID_OS|ID_MOV|ID_PAC|TIPO|CONCEPTO|BASE|IVA|TOTAL|FECHA|ID_MED|NOTAS|ALIAS
        print $fh "$id_os|$id_mov|$id_p|Cargo|$it->{nombre}|$base|$iva|$total|$f|$id_m_req|$aplica_para|$alias_os\n";
    }
    close $fh;
    responder({ success => 1, os => $id_os });

} elsif ($accion eq 'add_abono') {
    my $m = scalar($q->param('monto')) || 0; $m += 0;
    my $met = scalar($q->param('metodo')) || 'Efectivo';
    my $not = scalar($q->param('notas')) || '';
    my $alias_os = scalar($q->param('alias')) || '';
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
    # ID_OS|ID_MOV|ID_PAC|TIPO|CONCEPTO|BASE|IVA|TOTAL|FECHA|ID_MED|NOTAS|ALIAS
    print $fh "$id_os|$id_mov|$id_p|Abono|Pago con $met|0|0|$m|$f|$id_m_req|$not|$alias_os\n";
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
