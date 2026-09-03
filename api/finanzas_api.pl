#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(decode_json encode_json);
use FindBin;
use lib "$FindBin::Bin/..";

require "$FindBin::Bin/../auth/check_session.pl";
use utils::db_manager qw(leer_tabla guardar_registro eliminar_registro obtener_nuevo_id);

$CGI::POST_MAX = 1024 * 1024 * 10; # 10MB limit
binmode STDIN;
my $q = CGI->new;
my $session_data = check_session();

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (0 && !$session_data->{session_ok}) {
    print encode_json({ success => 0, message => "Sesión expirada" });
    exit;
}

my $action = $q->param('action') || '';

if ($action eq 'get_cxc') {
    # Cuentas por Cobrar: se recorre estado_cuenta.dat y pacientes.dat
    my @pacientes_raw = @{ leer_tabla("$FindBin::Bin/../dat/pacientes.dat") };
    my %nombres_pacientes;
    for my $p (@pacientes_raw) {
        $nombres_pacientes{$p->[0]} = "$p->[1] $p->[2]";
    }

    my @movimientos_raw = @{ leer_tabla("$FindBin::Bin/../dat/estado_cuenta.dat") };
    
    my %saldos;
    for my $mov (@movimientos_raw) {
        my $id_paciente = $mov->[2];
        my $tipo = $mov->[3] || '';
        my $notas = $mov->[10] || '';
        
        # Ignorar Cotizaciones (no son ingresos reales)
        next if $tipo eq 'Cargo' && $notas =~ /Presupuesto|Cotizacion/i;
        
        # Filtro de médico si el rol es Medico
        if ($session_data->{role} eq 'Medico') {
            next if ($mov->[9] || '') ne $session_data->{id_medico};
        }
        
        my $cargo = ($tipo eq 'Cargo') ? ($mov->[7] || 0) : 0;
        my $abono = ($tipo eq 'Abono') ? ($mov->[7] || 0) : 0;
        my $fecha = $mov->[8] || '';
        
        if (!exists $saldos{$id_paciente}) {
            $saldos{$id_paciente} = {
                id_paciente => $id_paciente,
                nombre => $nombres_pacientes{$id_paciente} || "Desconocido",
                cargos_acumulados => 0,
                abonos_acumulados => 0,
                saldo_pendiente => 0,
                ultimo_movimiento => ''
            };
        }
        
        $saldos{$id_paciente}{cargos_acumulados} += $cargo;
        $saldos{$id_paciente}{abonos_acumulados} += $abono;
        # Update latest date if this is newer
        if ($fecha gt $saldos{$id_paciente}{ultimo_movimiento}) {
            $saldos{$id_paciente}{ultimo_movimiento} = $fecha;
        }
    }
    
    my $filter_estado = $q->param('filter_estado') || '0';
    
    my @cxc;
    for my $id (keys %saldos) {
        if ($filter_estado eq '1') {
            next unless $id =~ /^EMP-/;
        } else {
            next if $id =~ /^EMP-/;
        }
        
        $saldos{$id}{saldo_pendiente} = $saldos{$id}{cargos_acumulados} - $saldos{$id}{abonos_acumulados};
        if ($saldos{$id}{saldo_pendiente} > 0.01) { # Tolerance for floats
            push @cxc, $saldos{$id};
        }
    }
    
    print encode_json({ success => 1, data => \@cxc });
}
elsif ($action eq 'get_gastos') {
    my @gastos_raw = @{ leer_tabla("$FindBin::Bin/../dat/gastos.dat") };
    
    # We need to map category names for convenience
    my @cat = @{ leer_tabla("$FindBin::Bin/../dat/categorias.dat") };
    my @subcat = @{ leer_tabla("$FindBin::Bin/../dat/sub_categoria.dat") };
    my @subcat3 = @{ leer_tabla("$FindBin::Bin/../dat/sub_categoria_nivel3.dat") };
    
    my @orig = ();
    my $origen_file = "$FindBin::Bin/../dat/origen_dinero.dat";
    if (-e $origen_file) {
        @orig = @{ leer_tabla($origen_file) };
    }
    
    my %c_map = map { $_->[0] => $_->[1] } @cat;
    my %s_map = map { $_->[0] => $_->[2] } @subcat;
    my %s3_map = map { $_->[0] => $_->[2] } @subcat3;
    my %o_map = map { $_->[0] => $_->[1] } @orig;
    
    my $f_inicio = $q->param('f_inicio') || '';
    my $f_fin = $q->param('f_fin') || '';

    my @gastos;
    for my $g (@gastos_raw) {
        my $fecha_gasto = $g->[1] || '';
        
        # Filtrar por fecha
        if ($f_inicio && $f_fin) {
            next if ($fecha_gasto lt $f_inicio || $fecha_gasto gt $f_fin);
        }

        my $id_cat = $g->[2] || '';
        my $id_subcat = $g->[3] || '';
        my $id_subcat3 = $g->[4] || '';
        my $id_origen = $g->[9] || '';
        
        push @gastos, {
            id_gasto => $g->[0],
            fecha => $fecha_gasto,
            id_cat => $id_cat,
            id_subcat => $id_subcat,
            id_subcat3 => $id_subcat3,
            concepto => $g->[5],
            monto => $g->[6],
            proveedor => $g->[7] || '',
            factura_path => $g->[8] || '',
            id_origen => $id_origen,
            origen_nombre => $o_map{$id_origen} || 'Efectivo / Caja General',
            cat_nombre => $c_map{$id_cat} || 'N/A',
            subcat_nombre => $s_map{$id_subcat} || 'N/A',
            subcat3_nombre => $s3_map{$id_subcat3} || 'N/A'
        };
    }
    
    # Sort by fecha desc
    @gastos = sort { $b->{fecha} cmp $a->{fecha} } @gastos;
    print encode_json({ success => 1, data => \@gastos });
}
elsif ($action eq 'save_gasto') {
    my $id_gasto = $q->param('id_gasto') || '';
    
    # Manejar subida de archivo factura
    my $factura_file = $q->upload('factura_file');
    my $factura_path = "";
    if ($factura_file) {
        my $filename = $q->param('factura_file');
        my ($ext) = $filename =~ /(\.[^.]+)$/;
        $ext = lc($ext || '');
        my $new_filename = time() . "_" . int(rand(10000)) . $ext;
        
        my $upload_dir = "$FindBin::Bin/../uploads";
        mkdir $upload_dir unless -d $upload_dir;
        $upload_dir .= "/facturas";
        mkdir $upload_dir unless -d $upload_dir;
        
        my $save_path = "$upload_dir/$new_filename";
        if (open(my $out_fh, '>', $save_path)) {
            binmode $out_fh;
            while (my $bytesread = read($factura_file, my $buffer, 1024)) {
                print $out_fh $buffer;
            }
            close $out_fh;
            $factura_path = "uploads/facturas/$new_filename";
        }
    }
    
    if (!$id_gasto) {
        my $nuevo_id = obtener_nuevo_id("$FindBin::Bin/../dat/id_gasto.counter");
        my $linea = join("|", 
            $nuevo_id,
            $q->param('fecha') || '',
            $q->param('id_cat') || '',
            $q->param('id_subcat') || '',
            $q->param('id_subcat3') || '',
            $q->param('concepto') || '',
            $q->param('monto') || 0,
            $q->param('proveedor') || '',
            $factura_path,
            $q->param('id_origen') || ''
        );
        guardar_registro("$FindBin::Bin/../dat/gastos.dat", $linea);
    } else {
        # Update is not fully implemented in db_manager without rewriting, ignoring for now.
    }
    print encode_json({ success => 1, message => "Gasto guardado correctamente" });
}
elsif ($action eq 'delete_gasto') {
    my $id_gasto = $q->param('id_gasto') || '';
    if ($id_gasto) {
        eliminar_registro("$FindBin::Bin/../dat/gastos.dat", 'id_gasto', $id_gasto);
        print encode_json({ success => 1, message => "Gasto eliminado" });
    } else {
        print encode_json({ success => 0, message => "ID no especificado" });
    }
}
elsif ($action eq 'get_ingresos') {
    my @movimientos_raw = @{ leer_tabla("$FindBin::Bin/../dat/estado_cuenta.dat") };
    my @pacientes_raw = @{ leer_tabla("$FindBin::Bin/../dat/pacientes.dat") };
    
    my %nombres;
    for my $p (@pacientes_raw) {
        $nombres{$p->[0]} = "$p->[1] $p->[2]";
    }
    
    my @ingresos;
    for my $m (@movimientos_raw) {
        my $tipo = $m->[3] || '';
        my $notas = $m->[10] || '';
        my $total = $m->[7] || 0;
        
        # Ignorar cotizaciones en ingresos (no son ingresos reales)
        next if $tipo eq 'Cargo' && $notas =~ /Presupuesto|Cotizacion/i;
        
        # Filtro de médico si el rol es Medico
        if ($session_data->{role} eq 'Medico') {
            next if ($m->[9] || '') ne $session_data->{id_medico};
        }
        
        if ($total > 0) {
            push @ingresos, {
                id_movimiento => $m->[1],
                id_paciente => $m->[2],
                id_os => $m->[0],
                fecha => $m->[8],
                tipo => $tipo,
                concepto => $m->[4],
                cargo => ($tipo eq 'Cargo') ? $total : 0,
                abono => ($tipo eq 'Abono') ? $total : 0,
                paciente_nombre => $m->[11] || $nombres{$m->[2]} || 'Desconocido'
            };
        }
    }
    
    @ingresos = sort { $b->{fecha} cmp $a->{fecha} } @ingresos;
    print encode_json({ success => 1, data => \@ingresos });
}
elsif ($action eq 'get_dashboard') {
    # 1. Ingresos y CxC (desde estado_cuenta.dat)
    my @movs = @{ leer_tabla("$FindBin::Bin/../dat/estado_cuenta.dat") };
    my ($ingresos_totales, $cxc) = (0, 0);
    my %saldos;
    for my $m (@movs) {
        my $id_pac = $m->[2];
        my $tipo   = $m->[3] || '';
        my $notas  = $m->[10] || '';
        my $total  = $m->[7] || 0;

        # Excluir entradas legadas tipo cotizacion/presupuesto del balance
        next if $tipo eq 'Cargo' && $notas =~ /Presupuesto|Cotizacion/i;

        $saldos{$id_pac} ||= { cargo => 0, abono => 0 };
        if ($tipo eq 'Cargo') { $saldos{$id_pac}{cargo} += $total; }
        if ($tipo eq 'Abono') { $saldos{$id_pac}{abono} += $total; $ingresos_totales += $total; }
    }

    for my $id (keys %saldos) {
        my $pend = $saldos{$id}{cargo} - $saldos{$id}{abono};
        $cxc += $pend if $pend > 0;
    }

    # 2. Egresos
    my @gastos_raw = @{ leer_tabla("$FindBin::Bin/../dat/gastos.dat") };
    my $egresos_totales = 0;
    for my $g (@gastos_raw) {
        $egresos_totales += ($g->[6] || 0);
    }

    # 3. Cotizaciones: total global desde cotizaciones.dat (fuente canonica)
    my $cotizaciones = 0;
    my $cot_dat = "$FindBin::Bin/../dat/cotizaciones.dat";
    if (-e $cot_dat) {
        open(my $fhc, '<:encoding(UTF-8)', $cot_dat);
        <$fhc>; # saltar cabecera
        while (my $cline = <$fhc>) {
            chomp $cline;
            next if $cline =~ /^\s*$/;
            my @cv = split /\|/, $cline, -1;
            # ID_COT|ID_PACIENTE|NOMBRE|TOTAL|FECHA|ID_MEDICO
            next unless scalar(@cv) >= 4;
            $cotizaciones += ($cv[3] + 0);
        }
        close $fhc;
    }

    print encode_json({
        success      => 1,
        ingresos     => $ingresos_totales,
        cxc          => $cxc,
        gastos       => $egresos_totales,
        cotizaciones => $cotizaciones
    });
}
elsif ($action eq 'get_categorias_gastos') {
    my @cat = @{ leer_tabla("$FindBin::Bin/../dat/categorias.dat") };
    my @subcat = @{ leer_tabla("$FindBin::Bin/../dat/sub_categoria.dat") };
    my @subcat3 = @{ leer_tabla("$FindBin::Bin/../dat/sub_categoria_nivel3.dat") };
    
    my @cat_map = map { { id => $_->[0], nombre => $_->[1], desc => $_->[2] } } @cat;
    my @subcat_map = map { { id => $_->[0], id_cat => $_->[1], nombre => $_->[2], desc => $_->[3] } } @subcat;
    my @subcat3_map = map { { id => $_->[0], id_subcat => $_->[1], nombre => $_->[2] } } @subcat3;
    
    print encode_json({ success => 1, categorias => \@cat_map, subcategorias => \@subcat_map, subcategorias3 => \@subcat3_map });
}
elsif ($action eq 'add_categoria') {
    my $nivel = $q->param('nivel') || '1';
    my $nombre = $q->param('nombre') || '';
    my $parent_id = $q->param('parent_id') || '';
    
    if (!$nombre) {
        print encode_json({ success => 0, message => 'Nombre requerido' });
        exit;
    }
    
    if ($nivel eq '1') {
        my $nid = obtener_nuevo_id("$FindBin::Bin/../dat/id_cat.counter");
        my $l = "$nid|$nombre|";
        open(my $f, ">>:encoding(UTF-8)", "$FindBin::Bin/../dat/categorias.dat");
        print $f "$l\n";
        close $f;
    } elsif ($nivel eq '2') {
        if (!$parent_id) { print encode_json({ success=>0, message=>'Padre requerido' }); exit; }
        my $nid = obtener_nuevo_id("$FindBin::Bin/../dat/id_subcat.counter");
        my $l = "$nid|$parent_id|$nombre|";
        open(my $f, ">>:encoding(UTF-8)", "$FindBin::Bin/../dat/sub_categoria.dat");
        print $f "$l\n";
        close $f;
    } elsif ($nivel eq '3') {
        if (!$parent_id) { print encode_json({ success=>0, message=>'Padre requerido' }); exit; }
        my $nid = obtener_nuevo_id("$FindBin::Bin/../dat/id_subcat3.counter");
        my $l = "$nid|$parent_id|$nombre";
        open(my $f, ">>:encoding(UTF-8)", "$FindBin::Bin/../dat/sub_categoria_nivel3.dat");
        print $f "$l\n";
        close $f;
    }
    print encode_json({ success => 1 });
}
elsif ($action eq 'edit_categoria') {
    my $id = $q->param('id');
    my $nivel = $q->param('nivel');
    my $nombre = $q->param('nombre') || '';
    
    if (!$id || !$nivel || !$nombre) {
        print encode_json({ success=>0, message=>'ID, nivel o nombre faltante' });
        exit;
    }
    
    my $file = "";
    if ($nivel eq '1') { $file = "categorias.dat"; }
    elsif ($nivel eq '2') { $file = "sub_categoria.dat"; }
    elsif ($nivel eq '3') { $file = "sub_categoria_nivel3.dat"; }
    
    my $path = "$FindBin::Bin/../dat/$file";
    my @lines;
    open(my $in, "<:encoding(UTF-8)", $path);
    while(<$in>) {
        my $line = $_;
        chomp($line);
        my @cols = split(/\|/, $line, -1);
        if ($cols[0] eq $id) {
            if ($nivel eq '1') {
                $cols[1] = $nombre;
            } elsif ($nivel eq '2' || $nivel eq '3') {
                $cols[2] = $nombre;
            }
            push @lines, join("|", @cols);
        } else {
            push @lines, $line;
        }
    }
    close $in;
    
    open(my $out, ">:encoding(UTF-8)", $path);
    for my $l (@lines) {
        print $out "$l\n";
    }
    close $out;
    
    print encode_json({ success => 1 });
}
elsif ($action eq 'delete_categoria') {
    my $id = $q->param('id');
    my $nivel = $q->param('nivel');
    
    if (!$id || !$nivel) { print encode_json({ success=>0, message=>'ID o nivel faltante' }); exit; }
    
    # Validation against gastos
    my @gastos = @{ leer_tabla("$FindBin::Bin/../dat/gastos.dat") };
    for my $g (@gastos) {
        # g[2] is id_cat, g[3] is id_subcat, g[4] is id_subcat3
        if ($nivel eq '1' && $g->[2] eq $id) {
            print encode_json({ success=>0, message=>'No se puede borrar porque hay gastos registrados con esta categoría.' });
            exit;
        } elsif ($nivel eq '2' && $g->[3] eq $id) {
            print encode_json({ success=>0, message=>'No se puede borrar porque hay gastos registrados con esta subcategoría.' });
            exit;
        } elsif ($nivel eq '3' && $g->[4] eq $id) {
            print encode_json({ success=>0, message=>'No se puede borrar porque hay gastos registrados con este detalle.' });
            exit;
        }
    }
    
    # Do deletion
    my $file = "";
    if ($nivel eq '1') { $file = "categorias.dat"; }
    elsif ($nivel eq '2') { $file = "sub_categoria.dat"; }
    elsif ($nivel eq '3') { $file = "sub_categoria_nivel3.dat"; }
    
    my $path = "$FindBin::Bin/../dat/$file";
    my @lines;
    open(my $in, "<:encoding(UTF-8)", $path);
    while(<$in>) {
        my $line = $_;
        chomp($line);
        my @cols = split(/\|/, $line, -1);
        if ($cols[0] eq $id && $cols[0] ne 'id') { # Ensure not deleting header
            # Skip this line
        } else {
            push @lines, $line;
        }
    }
    close $in;
    
    open(my $out, ">:encoding(UTF-8)", $path);
    for my $l (@lines) {
        print $out "$l\n";
    }
    close $out;
    
    print encode_json({ success => 1 });
}
elsif ($action eq 'get_origenes_dinero') {
    my $origen_file = "$FindBin::Bin/../dat/origen_dinero.dat";
    
    # Auto-seed si no existe
    if (!-e $origen_file) {
        open(my $f, ">:encoding(UTF-8)", $origen_file);
        print $f "1|Efectivo / Caja Chica|Efectivo físico en sucursal\n";
        print $f "2|Caja General|Efectivo principal\n";
        print $f "3|Transferencia Bancaria|Pago electrónico\n";
        print $f "4|Tarjeta de Crédito / Débito|Terminal bancaria\n";
        close $f;
        open(my $c, ">", "$FindBin::Bin/../dat/id_origen_dinero.counter");
        print $c "4";
        close $c;
    }
    
    my @orig = @{ leer_tabla($origen_file) };
    my @orig_map = map { { id => $_->[0], nombre => $_->[1], desc => $_->[2] } } @orig;
    
    print encode_json({ success => 1, origenes => \@orig_map });
}
elsif ($action eq 'add_origen_dinero') {
    my $nombre = $q->param('nombre') || '';
    my $desc = $q->param('desc') || '';
    if (!$nombre) {
        print encode_json({ success => 0, message => 'Nombre requerido' });
        exit;
    }
    my $nid = obtener_nuevo_id("$FindBin::Bin/../dat/id_origen_dinero.counter");
    my $l = "$nid|$nombre|$desc";
    open(my $f, ">>:encoding(UTF-8)", "$FindBin::Bin/../dat/origen_dinero.dat");
    print $f "$l\n";
    close $f;
    print encode_json({ success => 1 });
}
elsif ($action eq 'edit_origen_dinero') {
    my $id = $q->param('id');
    my $nombre = $q->param('nombre') || '';
    my $desc = $q->param('desc') || '';
    
    if (!$id || !$nombre) {
        print encode_json({ success=>0, message=>'ID o nombre faltante' });
        exit;
    }
    
    my $path = "$FindBin::Bin/../dat/origen_dinero.dat";
    my @lines;
    open(my $in, "<:encoding(UTF-8)", $path);
    while(<$in>) {
        my $line = $_;
        chomp($line);
        my @cols = split(/\|/, $line, -1);
        if ($cols[0] eq $id) {
            $cols[1] = $nombre;
            $cols[2] = $desc;
            push @lines, join("|", @cols);
        } else {
            push @lines, $line;
        }
    }
    close $in;
    
    open(my $out, ">:encoding(UTF-8)", $path);
    for my $l (@lines) {
        print $out "$l\n";
    }
    close $out;
    
    print encode_json({ success => 1 });
}
elsif ($action eq 'delete_origen_dinero') {
    my $id = $q->param('id');
    if (!$id) { print encode_json({ success=>0, message=>'ID faltante' }); exit; }
    
    my @gastos = @{ leer_tabla("$FindBin::Bin/../dat/gastos.dat") };
    for my $g (@gastos) {
        if (($g->[9] || '') eq $id) {
            print encode_json({ success=>0, message=>'No se puede borrar porque hay gastos registrados con este origen de dinero.' });
            exit;
        }
    }
    
    my $path = "$FindBin::Bin/../dat/origen_dinero.dat";
    my @lines;
    open(my $in, "<:encoding(UTF-8)", $path);
    while(<$in>) {
        my $line = $_;
        chomp($line);
        my @cols = split(/\|/, $line, -1);
        if ($cols[0] eq $id && $cols[0] ne 'id') {
            # Skip this line
        } else {
            push @lines, $line;
        }
    }
    close $in;
    
    open(my $out, ">:encoding(UTF-8)", $path);
    for my $l (@lines) {
        print $out "$l\n";
    }
    close $out;
    
    print encode_json({ success => 1 });
}
else {
    print encode_json({ success => 0, message => "Acción desconocida" });
}
