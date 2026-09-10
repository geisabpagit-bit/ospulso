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
        
        my $id_creador = $g->[10] || '';
        if ($session_data->{role} eq 'Recepcionista') {
            next unless $id_creador eq $session_data->{usuario};
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
            $q->param('id_origen') || '',
            $session_data->{usuario} || ''
        );
        guardar_registro("$FindBin::Bin/../dat/gastos.dat", $linea);
    } else {
        # Update existente
        my $archivo = "$FindBin::Bin/../dat/gastos.dat";
        if (-e $archivo) {
            open(my $fh_in, '<:encoding(UTF-8)', $archivo);
            my @lineas = <$fh_in>;
            close $fh_in;
            
            open(my $fh_out, '>:encoding(UTF-8)', $archivo);
            foreach my $l (@lineas) {
                chomp $l;
                my @campos = split(/\|/, $l, -1);
                if ($campos[0] eq $id_gasto) {
                    # Conservar factura antigua si no se subió una nueva
                    my $final_factura = $factura_path ne "" ? $factura_path : $campos[8];
                    $l = join("|", 
                        $id_gasto,
                        $q->param('fecha') || $campos[1],
                        $q->param('id_cat') || $campos[2],
                        $q->param('id_subcat') || '',
                        $q->param('id_subcat3') || '',
                        $q->param('concepto') || $campos[5],
                        $q->param('monto') || $campos[6],
                        $q->param('proveedor') || $campos[7],
                        $final_factura,
                        $q->param('id_origen') || $campos[9],
                        $campos[10] || $session_data->{usuario} || ''
                    );
                }
                print $fh_out "$l\n";
            }
            close $fh_out;
        }
    }
    print encode_json({ success => 1, message => "Gasto guardado correctamente" });
}
elsif ($action eq 'delete_gasto') {
    my $id_gasto = $q->param('id_gasto') || '';
    if ($id_gasto) {
        eliminar_registro("$FindBin::Bin/../dat/gastos.dat", $id_gasto);
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
    my $f_inicio = $q->param('f_inicio') || '';
    my $f_fin    = $q->param('f_fin') || '';
    
    my $id_empresa = $session_data->{id_empresa} // '';
    my $role       = $session_data->{role} // 'Invitado';
    my $id_medico  = $session_data->{id_medico} // '';
    my $es_admin_global = ($role eq 'Administrador Global') ? 1 : 0;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $hoy_str = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);

    # 0. Resolver CLUES de la organización
    my $org_clues = '';
    my $negocios_file = "$FindBin::Bin/../dat/negocios.dat";
    if (-e $negocios_file) {
        my $neg_data = leer_tabla($negocios_file);
        foreach my $n (@$neg_data) {
            if ($n->[0] eq $id_empresa || (!$id_empresa && $n->[0] eq '0')) {
                $org_clues = $n->[18] // '';
                last;
            }
        }
    }
    $org_clues ||= 'QTSMP000116';

    # 1. Mapear pacientes y médicos de la organización
    my %pacientes_org;
    my %medicos_org;

    # 1.1 Pacientes estándar
    my $pac_file = "$FindBin::Bin/../dat/pacientes.dat";
    if (-e $pac_file && open(my $fhp, '<:utf8', $pac_file)) {
        while (my $line = <$fhp>) {
            chomp $line;
            next if $line =~ /^ID_PACIENTE/ || $line =~ /^\s*$/;
            my @f = split(/\|/, $line);
            my $id_pac = $f[0];
            my $tenant_pac = $f[13] // '';
            my ($org_pac) = split(/:/, $tenant_pac);
            if ($es_admin_global || !$org_pac || $org_pac eq $id_empresa || $org_pac eq '0') {
                $pacientes_org{$id_pac} = 1;
            }
        }
        close $fhp;
    }

    # 1.2 Pacientes Privados y Empleados Municipio (CLUE)
    if ($org_clues) {
        my $priv_file = "$FindBin::Bin/../dat/catalogos_CLUE/$org_clues/pacientes_privados_${org_clues}.dat";
        if (-e $priv_file && open(my $fhpriv, '<:utf8', $priv_file)) {
            while (my $line = <$fhpriv>) {
                chomp $line;
                next if $line =~ /^ID_PACIENTE/ || $line =~ /^\s*$/;
                my @f = split(/\|/, $line);
                $pacientes_org{$f[0]} = 1 if $f[0];
            }
            close $fhpriv;
        }

        my $emp_file = "$FindBin::Bin/../dat/catalogos_CLUE/$org_clues/empleadosmun_${org_clues}.dat";
        if (-e $emp_file && open(my $fhemp, '<:utf8', $emp_file)) {
            while (my $line = <$fhemp>) {
                chomp $line;
                my @f = split(/!/, $line);
                if (@f >= 2 && $f[0] ne '$c_clinumempleado') {
                    $pacientes_org{"EMP-$f[0]"} = 1;
                    $pacientes_org{$f[0]} = 1;
                }
            }
            close $fhemp;
        }

        my $med_file = "$FindBin::Bin/../dat/catalogos_CLUE/$org_clues/medicos_${org_clues}.dat";
        if (-e $med_file && open(my $fhmed, '<:utf8', $med_file)) {
            while (my $line = <$fhmed>) {
                chomp $line;
                my @f = split(/\|/, $line);
                $medicos_org{$f[0]} = 1 if $f[0];
            }
            close $fhmed;
        }
    }

    # 2. Mapear usuarios de la organización (para gastos y autorizaciones)
    my %usuarios_org;
    my $user_file = "$FindBin::Bin/../dat/usuarios.dat";
    if (-e $user_file && open(my $fhu, '<:utf8', $user_file)) {
        while (my $l = <$fhu>) {
            chomp $l;
            next if $l =~ /^id!/ || $l =~ /^\s*$/;
            my @u = split(/!/, $l, -1);
            my $u_name = $u[1] || '';
            my $u_biz  = $u[6] || '0:0';
            my ($u_org) = split(/:/, $u_biz);
            if ($es_admin_global || $u_org eq $id_empresa || $u_biz eq '0:0') {
                $usuarios_org{$u_name} = 1;
            }
        }
        close $fhu;
    }

    # 3. Recibos Emitidos e Ingresos en Caja (folios_recibos_privados y publicos)
    my $total_recibos_periodo = 0;
    my $total_recibos_hoy = 0;
    my $ingresos_recibos = 0;
    my %metodos_pago;

    # Pre-cargar meses para serie histórica
    my @meses_info;
    my %meses_ingresos;
    my %meses_gastos;
    my @nombres_mes = qw(Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic);

    for (my $i = 5; $i >= 0; $i--) {
        my ($s,$mn,$h,$md,$mo,$yr) = localtime(time - ($i * 30 * 86400));
        my $ym = sprintf("%04d-%02d", $yr+1900, $mo+1);
        my $label = $nombres_mes[$mo] . " " . substr($yr+1900, 2, 2);
        push @meses_info, { ym => $ym, label => $label };
        $meses_ingresos{$ym} = 0;
        $meses_gastos{$ym} = 0;
    }

    foreach my $rf ("$FindBin::Bin/../dat/folios_recibos_privados.dat", "$FindBin::Bin/../dat/folios_recibos_publicos.dat") {
        if (-e $rf && open(my $fhr, '<:encoding(UTF-8)', $rf)) {
            <$fhr>; # cabecera
            while (my $rline = <$fhr>) {
                chomp $rline;
                next if $rline =~ /^\s*$/;
                my @r = split(/\|/, $rline, -1);
                next if scalar(@r) < 7;
                my $r_negocio = $r[2] // '';
                my $r_fecha   = $r[6] // '';
                my $r_estatus = $r[14] // '';
                my $r_metodo  = $r[10] // 'Efectivo';
                my $r_monto   = $r[9] || 0;
                $r_monto =~ s/[^\d\.]//g;

                # Filtro multi-tenant por negocio
                next unless $es_admin_global || $r_negocio eq $id_empresa || $r_negocio eq '' || $r_negocio eq '0';

                # Filtro por rol
                if ($role eq 'Recepcionista') {
                    my $r_elab = $r[11] || '';
                    next unless ($r_elab eq $session_data->{usuario} || $r_elab eq $session_data->{uid});
                } elsif ($role eq 'Medico') {
                    my $r_med = $r[15] || '';
                    next unless ($r_med eq $id_medico);
                }

                if ($r_fecha eq $hoy_str) {
                    $total_recibos_hoy++;
                }

                # Histórico semestral (solo cobrados)
                my ($ym_r) = $r_fecha =~ /^(\d{4}-\d{2})/;
                if ($ym_r && exists $meses_ingresos{$ym_r} && $r_estatus !~ /Cancelado/i) {
                    $meses_ingresos{$ym_r} += $r_monto;
                }

                # Filtro por rango
                if ($f_inicio && $f_fin) {
                    next if ($r_fecha lt $f_inicio || $r_fecha gt $f_fin);
                } elsif ($f_inicio) {
                    next if ($r_fecha lt $f_inicio);
                } elsif ($f_fin) {
                    next if ($r_fecha gt $f_fin);
                }

                $total_recibos_periodo++;

                if ($r_estatus !~ /Cancelado/i) {
                    $ingresos_recibos += $r_monto;
                    $metodos_pago{$r_metodo} += $r_monto;
                }
            }
            close $fhr;
        }
    }

    # 4. Movimientos y Cuentas por Cobrar (desde estado_cuenta.dat)
    my @movs = @{ leer_tabla("$FindBin::Bin/../dat/estado_cuenta.dat") };
    my ($ingresos_edc, $cxc) = (0, 0);
    my %saldos;

    for my $m (@movs) {
        my $id_pac = $m->[2] || '';
        my $tipo   = $m->[3] || '';
        my $notas  = $m->[10] || '';
        my $total  = $m->[7] || 0;
        my $fecha  = $m->[8] || '';
        my $id_med = $m->[9] || '';

        # Excluir cotizaciones del balance de cargos
        next if $tipo eq 'Cargo' && $notas =~ /Presupuesto|Cotizacion/i;

        # Filtro multi-tenant permisivo e inteligente
        my $pertenece = $es_admin_global ? 1 : 0;
        $pertenece = 1 if $pacientes_org{$id_pac};
        $pertenece = 1 if $id_med && $medicos_org{$id_med};
        $pertenece = 1 if $id_pac =~ /^PRIV-|^EMP-/;
        next unless $pertenece;

        if ($role eq 'Medico') {
            next if ($id_med ne $id_medico);
        }

        $saldos{$id_pac} ||= { cargo => 0, abono => 0 };
        if ($tipo eq 'Cargo') { $saldos{$id_pac}{cargo} += $total; }
        if ($tipo eq 'Abono') { $saldos{$id_pac}{abono} += $total; }

        my $dentro_de_rango = 1;
        if ($f_inicio && $f_fin) {
            $dentro_de_rango = ($fecha ge $f_inicio && $fecha le $f_fin) ? 1 : 0;
        } elsif ($f_inicio) {
            $dentro_de_rango = ($fecha ge $f_inicio) ? 1 : 0;
        } elsif ($f_fin) {
            $dentro_de_rango = ($fecha le $f_fin) ? 1 : 0;
        }

        if ($dentro_de_rango && $tipo eq 'Abono') {
            $ingresos_edc += $total;
        }

        # Complementar histórico si no hubo recibos en ese mes
        my ($ym_m) = $fecha =~ /^(\d{4}-\d{2})/;
        if ($ym_m && exists $meses_ingresos{$ym_m} && $tipo eq 'Abono' && $ingresos_recibos == 0) {
            $meses_ingresos{$ym_m} += $total;
        }
    }

    # Ingreso mandante: de recibos o de estado de cuenta
    my $ingresos_totales = ($ingresos_recibos > 0) ? $ingresos_recibos : $ingresos_edc;

    # Calcular CxC privada y pública (Estado)
    my $cxc_estado = 0;
    for my $id (keys %saldos) {
        my $pend = $saldos{$id}{cargo} - $saldos{$id}{abono};
        if ($pend > 0.01) {
            $cxc += $pend;
            if ($id =~ /^EMP-/) {
                $cxc_estado += $pend;
            }
        }
    }

    # 5. Egresos (desde gastos.dat)
    my @gastos_raw = @{ leer_tabla("$FindBin::Bin/../dat/gastos.dat") };
    my $egresos_totales = 0;
    for my $g (@gastos_raw) {
        my $g_fecha   = $g->[1] || '';
        my $g_creador = $g->[10] || '';
        my $monto     = $g->[6] || 0;
        $monto =~ s/[^\d\.]//g;

        # Filtro multi-tenant por creador
        next unless $es_admin_global || $usuarios_org{$g_creador} || !$g_creador;

        if ($role eq 'Recepcionista') {
            next unless ($g_creador eq $session_data->{usuario});
        }

        # Serie histórica de gastos
        my ($ym_g) = $g_fecha =~ /^(\d{4}-\d{2})/;
        if ($ym_g && exists $meses_gastos{$ym_g}) {
            $meses_gastos{$ym_g} += $monto;
        }

        # Filtro por rango
        if ($f_inicio && $f_fin) {
            next if ($g_fecha lt $f_inicio || $g_fecha gt $f_fin);
        } elsif ($f_inicio) {
            next if ($g_fecha lt $f_inicio);
        } elsif ($f_fin) {
            next if ($g_fecha gt $f_fin);
        }

        $egresos_totales += $monto;
    }

    # 6. Cotizaciones activas (desde cotizaciones.dat)
    my $cotizaciones = 0;
    my $cot_dat = "$FindBin::Bin/../dat/cotizaciones.dat";
    if (-e $cot_dat && open(my $fhc, '<:encoding(UTF-8)', $cot_dat)) {
        <$fhc>; # cabecera
        while (my $cline = <$fhc>) {
            chomp $cline;
            next if $cline =~ /^\s*$/;
            my @cv = split /\|/, $cline, -1;
            next unless scalar(@cv) >= 5;
            my $c_id_pac = $cv[1] || '';
            my $c_monto  = $cv[3] + 0;
            my $c_fecha  = $cv[4] || '';

            # Filtro multi-tenant
            next unless $es_admin_global || $pacientes_org{$c_id_pac} || $c_id_pac =~ /^PRIV-|^EMP-/;

            if ($f_inicio && $f_fin) {
                next if ($c_fecha lt $f_inicio || $c_fecha gt $f_fin);
            } elsif ($f_inicio) {
                next if ($c_fecha lt $f_inicio);
            } elsif ($f_fin) {
                next if ($c_fecha gt $f_fin);
            }
            $cotizaciones += $c_monto;
        }
        close $fhc;
    }

    my $ticket_promedio = $total_recibos_periodo > 0 ? ($ingresos_totales / $total_recibos_periodo) : 0;
    my $utilidad_neta = $ingresos_totales - $egresos_totales;

    my @chart_labels   = map { $_->{label} } @meses_info;
    my @chart_ingresos = map { $meses_ingresos{$_->{ym}} || 0 } @meses_info;
    my @chart_gastos   = map { $meses_gastos{$_->{ym}} || 0 } @meses_info;

    print encode_json({
        success         => 1,
        ingresos        => $ingresos_totales,
        cxc             => $cxc,
        cxc_estado      => $cxc_estado,
        gastos          => $egresos_totales,
        utilidad        => $utilidad_neta,
        cotizaciones    => $cotizaciones,
        facturacion     => 0,
        recibos_periodo => $total_recibos_periodo,
        recibos_hoy     => $total_recibos_hoy,
        ticket_promedio => sprintf("%.2f", $ticket_promedio),
        metodos_pago    => \%metodos_pago,
        chart_series    => {
            labels   => \@chart_labels,
            ingresos => \@chart_ingresos,
            gastos   => \@chart_gastos
        }
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
