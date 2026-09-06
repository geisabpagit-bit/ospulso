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
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
print $q->header(-type => 'application/json', -charset => 'UTF-8');

my $session_data = check_session();

# 1. Validar RBAC
if (!$session_data->{session_ok} || $session_data->{role} !~ /Administrador Organizacion|Recepcionista/i) {
    print encode_json({ error => 1, msg => 'Acceso denegado. Se requiere nivel de administrador o recepcionista.' });
    exit;
}

# 2. Leer Parámetros
my $f_inicio = $q->param('f_inicio') || '';
my $f_fin    = $q->param('f_fin')    || '';

if (!$f_inicio || !$f_fin) {
    print encode_json({ error => 1, msg => 'Debe proporcionar un rango de fechas.' });
    exit;
}

# 3. Datos de la Organización
my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
my $id_empresa = $session_data->{id_empresa} // '';

# Obtener CLUES para leer folios
my $org_clues = '';
my $negocios_file = File::Spec->catfile($dat_dir, 'negocios.dat');
my $negocios_data = leer_tabla($negocios_file);
foreach my $neg (@$negocios_data) {
    if ($neg->[0] eq $id_empresa) {
        $org_clues = $neg->[18] // '';
        last;
    }
}

# Diccionario de médicos para resolver ID a Nombre
my %medicos = ();
if ($org_clues) {
    require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
    my $med_file = catalogo_org_utils::obtener_rutas_por_clue($org_clues)->{medicos};
    if (-e $med_file) {
        my $m_data = leer_tabla($med_file);
        foreach my $m (@$m_data) {
            # Índice 2 suele ser el Nombre_Completo en medicos_CLUE.dat
            $medicos{$m->[0]} = $m->[2] || $m->[1] || $m->[0];
        }
    }
}

# Diccionario de pacientes para resolver ID a Nombre
my %pacientes = ();
my $pac_file = File::Spec->catfile($dat_dir, 'pacientes.dat');
if (-e $pac_file) {
    my $p_data = leer_tabla($pac_file);
    foreach my $p (@$p_data) {
        # Índice 2 es NOMBRE según las cabeceras de pacientes.dat
        $pacientes{$p->[0]} = $p->[2] || $p->[0];
    }
}
if ($org_clues) {
    my $priv_file = File::Spec->catfile($dat_dir, 'catalogos_CLUE', $org_clues, "pacientes_privados_${org_clues}.dat");
    if (-e $priv_file) {
        my $priv_data = leer_tabla($priv_file);
        foreach my $p (@$priv_data) {
            # Índice 1 es NOMBRE_COMPLETO
            $pacientes{$p->[0]} = $p->[1] || $p->[0];
        }
        my %dependencias = ();
        my %empleados = ();

        # Dependencias del Municipio
        my $dep_file = catalogo_org_utils::obtener_rutas_por_clue($org_clues)->{dependencia};
        if (-e $dep_file && open(my $dfh, '<:encoding(UTF-8)', $dep_file)) {
            <$dfh>; # Omitir header
            while (my $line = <$dfh>) {
                chomp $line;
                my @d = split(/!/, $line, -1);
                if (@d >= 2) {
                    $dependencias{$d[0]} = $d[1] // '';
                }
            }
            close($dfh);
        }

        # Empleados Públicos (Estado) para Cuentas por Cobrar
        my $emp_file = catalogo_org_utils::obtener_rutas_por_clue($org_clues)->{empleadosmun};
        if (-e $emp_file && open(my $efh, '<:encoding(UTF-8)', $emp_file)) {
            while (my $line = <$efh>) {
                chomp $line;
                my @f = split(/!/, $line);
                if (scalar(@f) >= 2 && $f[0] ne '$c_clinumempleado') {
                    my $num_emp = $f[0];
                    my $nombre_emp = $f[1] || '';
                    my $tipo_emp = $f[2] || '';
                    my $id_dep = $f[4] || '';

                    if ($tipo_emp eq 'Empleado' || !exists $empleados{$num_emp}) {
                        $empleados{$num_emp} = {
                            num        => $num_emp,
                            nombre     => $nombre_emp,
                            id_dep     => $id_dep,
                            dep_nombre => $dependencias{$id_dep} || ''
                        };
                    }

                    my $key = 'EMP-' . $num_emp;
                    if (!exists $pacientes{$key}) {
                        $pacientes{$key} = $nombre_emp;
                    }
                }
            }
            close($efh);
        }
    }
}

# 4. Procesar Ingresos (Recibos Privados)
my $archivo_ingresos = File::Spec->catfile($dat_dir, 'folios_recibos_privados.dat');
my @ingresos_filtrados = ();
my $total_ingresos = 0;

if (-e $archivo_ingresos) {
    my $ing_data = leer_tabla($archivo_ingresos);
    foreach my $f (@$ing_data) {
        my $id_negocio = $f->[2] || '';
        if ($id_empresa && $id_negocio && $id_negocio ne $id_empresa) {
            next;
        }

        # Filtro RBAC Recepcionista
        my $elaborado_por = $f->[11] || '';
        if ($session_data->{role} eq 'Recepcionista') {
            my $mi_user = $session_data->{usuario};
            my $mi_uid = $session_data->{uid};
            my $mi_nombre = $session_data->{nombre_completo} || $medicos{$mi_user} || $mi_user;
            next unless ($elaborado_por eq $mi_user || $elaborado_por eq $mi_nombre || $elaborado_por eq $mi_uid);
        }

        my $fecha = $f->[6] || '';
        my $estatus = $f->[14] || '';
        my $is_cancelado = ($estatus =~ /Cancelado/i) ? 1 : 0;

        # Filtro de fechas (YYYY-MM-DD string comp)
        if ($fecha ge $f_inicio && $fecha le $f_fin) {
            my $abono = $f->[9] || 0;
            $abono =~ s/[^\d\.]//g; # limpiar
            
            if (!$is_cancelado) {
                $total_ingresos += $abono;
            }
            
            # Resolver nombre del médico
            my $id_med = $f->[15] || '';
            my $nombre_med = $id_med ? ($medicos{$id_med} || $id_med || 'N/D') : 'N/D';

            # Simplificar Folio (Extraer el último segmento)
            my $folio_raw = $f->[1] || '';
            my $folio_corto = $folio_raw;
            if ($folio_raw =~ /([^-]+)$/) {
                $folio_corto = $1;
                $folio_corto =~ s/^0+//;
            }

            # Resolver nombre del paciente
            my $id_pac = $f->[5] || '';
            my $nombre_pac = $pacientes{$id_pac} || $id_pac || 'Público General';

            push @ingresos_filtrados, {
                folio      => $folio_corto || $folio_raw,
                folio_raw  => $folio_raw,
                fecha      => $fecha . ' ' . ($f->[7] || ''),
                paciente   => $nombre_pac,
                medico     => $nombre_med,
                forma_pago => $f->[10] || 'Efectivo',
                monto      => $abono,
                estatus    => $is_cancelado ? 'Cancelado' : 'Activo',
                motivo     => $is_cancelado ? ($f->[16] || $f->[15] || 'Sin motivo registrado') : ''
            };
        }
    }
}

# 4.5. Procesar Cuentas por Cobrar (Recibos Públicos)
my $archivo_publicos = File::Spec->catfile($dat_dir, 'folios_recibos_publicos.dat');
my @cxc_filtrados = ();
my $total_cxc = 0;

# Indexar ALIAS de pacientes desde estado_cuenta.dat
my %pacientes_edc = ();
my $edc_file = File::Spec->catfile($dat_dir, 'estado_cuenta.dat');
if (-e $edc_file && open(my $fhe, '<:encoding(UTF-8)', $edc_file)) {
    my $he = <$fhe>;
    while (my $le = <$fhe>) {
        chomp $le;
        my @e = split /\|/, $le, -1;
        next if ($e[3] && $e[3] =~ /Cancelac/i) || ($e[4] && $e[4] =~ /Cancelac/i);
        if (defined $e[11] && $e[11] ne '') {
            my $alias = $e[11];
            next if $alias =~ /Metodo:/i || $alias =~ /^Cargo/i || $alias =~ /^Abono/i;
            $alias =~ s/.*Paciente:\s*//i;
            $alias =~ s/^\s+|\s+$//g;
            if ($alias && $alias !~ /^Metodo:/i) {
                $pacientes_edc{$e[0]} = $alias if $e[0];
            }
        }
    }
    close($fhe);
}

# Definir variables de contexto para CxC (Trabajadores y Dependencias)
my %dependencias = ();
my %empleados = ();
if ($org_clues) {
    require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');
    my $dep_file = catalogo_org_utils::obtener_rutas_por_clue($org_clues)->{dependencia};
    if (-e $dep_file && open(my $dfh, '<:encoding(UTF-8)', $dep_file)) {
        <$dfh>;
        while (my $line = <$dfh>) {
            chomp $line;
            my @d = split(/!/, $line, -1);
            if (@d >= 2) { $dependencias{$d[0]} = $d[1] // ''; }
        }
        close($dfh);
    }
    my $emp_file = catalogo_org_utils::obtener_rutas_por_clue($org_clues)->{empleadosmun};
    if (-e $emp_file && open(my $efh, '<:encoding(UTF-8)', $emp_file)) {
        while (my $line = <$efh>) {
            chomp $line;
            my @f = split(/!/, $line);
            if (scalar(@f) >= 2 && $f[0] ne '$c_clinumempleado') {
                my $num_emp = $f[0];
                my $nom_emp = $f[1] || '';
                my $rel_emp = $f[2] || '';
                my $id_dep  = $f[4] || '';

                # Preservar al TRABAJADOR TITULAR (Relación == Empleado)
                if ($rel_emp eq 'Empleado' || !exists $empleados{$num_emp}) {
                    $empleados{$num_emp} = {
                        num        => $num_emp,
                        nombre     => $nom_emp,
                        dep_nombre => $dependencias{$id_dep} || ''
                    };
                }
            }
        }
        close($efh);
    }
}

if (-e $archivo_publicos) {
    my $pub_data = leer_tabla($archivo_publicos);
    foreach my $f (@$pub_data) {
        my $id_negocio = $f->[2] || '';
        if ($id_empresa && $id_negocio && $id_negocio ne $id_empresa) {
            next;
        }

        # Filtro RBAC Recepcionista
        my $elaborado_por = $f->[11] || '';
        if ($session_data->{role} eq 'Recepcionista') {
            my $mi_user = $session_data->{usuario};
            my $mi_uid = $session_data->{uid};
            my $mi_nombre = $session_data->{nombre_completo} || $medicos{$mi_user} || $mi_user;
            next unless ($elaborado_por eq $mi_user || $elaborado_por eq $mi_nombre || $elaborado_por eq $mi_uid);
        }

        my $fecha = $f->[6] || '';
        my $estatus = $f->[14] || '';
        my $is_cancelado = ($estatus =~ /Cancelado/i) ? 1 : 0;
        
        if ($fecha ge $f_inicio && $fecha le $f_fin) {
            my $abono = $f->[9] || 0;
            $abono =~ s/[^\d\.]//g;
            
            if (!$is_cancelado) {
                $total_cxc += $abono;
            }
            
            my $id_med = $f->[15] || '';
            my $nombre_med = $id_med ? ($medicos{$id_med} || $id_med || 'N/D') : 'N/D';

            my $folio_raw = $f->[1] || '';
            my $id_recibo = $f->[0] || '';
            my $id_consulta = $f->[4] || '';

            my $folio_corto = $folio_raw;
            if ($folio_raw =~ /([^-]+)$/) {
                $folio_corto = $1;
                $folio_corto =~ s/^0+//;
            }

            my $id_pac = $f->[5] || '';

            # Extraer número de empleado del ID_PACIENTE
            my $num_emp = '';
            if ($id_pac =~ /^EMP-(.+)/) { $num_emp = $1; } else { $num_emp = $id_pac; }

            # 1. Obtener Nombre del TRABAJADOR TITULAR
            my $trabajador_nom = ($num_emp && $empleados{$num_emp}) ? $empleados{$num_emp}->{nombre} : '';
            my $dep_nom = ($num_emp && $empleados{$num_emp}) ? $empleados{$num_emp}->{dep_nombre} : '';

            # 2. Obtener Nombre del PACIENTE REAL que recibió la consulta/servicio
            my $nombre_pac = '';
            if ($folio_raw && $pacientes_edc{$folio_raw}) {
                $nombre_pac = $pacientes_edc{$folio_raw};
            } elsif ($id_recibo && $pacientes_edc{$id_recibo}) {
                $nombre_pac = $pacientes_edc{$id_recibo};
            } elsif ($id_consulta && $pacientes_edc{$id_consulta}) {
                $nombre_pac = $pacientes_edc{$id_consulta};
            } elsif ($pacientes{$id_pac}) {
                $nombre_pac = $pacientes{$id_pac};
            }

            if (!$nombre_pac || $nombre_pac eq $id_pac || $nombre_pac =~ /^Metodo:/i) {
                $nombre_pac = $trabajador_nom || $id_pac || 'Empleado Estatal';
            }

            push @cxc_filtrados, {
                folio             => $folio_corto || $folio_raw,
                folio_raw         => $folio_raw,
                fecha             => $fecha . ' ' . ($f->[7] || ''),
                paciente          => $nombre_pac,
                num_empleado      => $num_emp,
                trabajador_nombre => $trabajador_nom,
                dependencia       => $dep_nom || 'Municipio',
                medico            => $nombre_med,
                forma_pago        => $f->[10] || 'Crédito CxC',
                monto             => $abono,
                estatus           => $is_cancelado ? 'Cancelado' : 'Activo',
                motivo            => $is_cancelado ? ($f->[16] || $f->[15] || 'Sin motivo registrado') : ''
            };
        }
    }
}

# 5. Procesar Egresos (Gastos)
my $archivo_egresos = File::Spec->catfile($dat_dir, 'gastos.dat');
my @egresos_filtrados = ();
my $total_egresos = 0;

if (-e $archivo_egresos) {
    my @cat = @{ leer_tabla(File::Spec->catfile($dat_dir, 'categorias.dat')) };
    my %c_map = map { $_->[0] => $_->[1] } @cat;

    my $od_file = File::Spec->catfile($dat_dir, 'origenes_dinero.dat');
    my %o_map = ();
    if (-e $od_file) {
        my $od_data = leer_tabla($od_file);
        %o_map = map { $_->[0] => $_->[1] } @$od_data;
    }

    my $egr_data = leer_tabla($archivo_egresos);
    foreach my $f (@$egr_data) {
        my $fecha = $f->[1] || '';
        my ($solo_fecha) = split(/\s+/, $fecha);
        $solo_fecha = '' unless defined $solo_fecha;

        if ($solo_fecha ge $f_inicio && $solo_fecha le $f_fin) {
            my $monto = $f->[6] || 0;
            $monto =~ s/[^\d\.]//g; # limpiar
            
            $total_egresos += $monto;
            
            my $id_cat = $f->[2] || '';
            my $concepto = $f->[5] || '';
            my $proveedor = $f->[7] || '';
            my $id_origen = $f->[9] || '';
            my $origen_nombre = $id_origen ? ($o_map{$id_origen} || 'Desconocido') : 'No Especificado';
          
            push @egresos_filtrados, {
                folio         => $f->[0],
                fecha         => $fecha,
                categoria     => $c_map{$id_cat} || 'Gasto Operativo',
                responsable   => $proveedor || 'N/A',
                concepto      => $concepto,
                monto         => $monto,
                id_origen     => $id_origen,
                origen_nombre => $origen_nombre
            };
        }
    }
}

# 6. Responder JSON
print encode_json({
    ok       => JSON::true,
    ingresos => \@ingresos_filtrados,
    egresos  => \@egresos_filtrados,
    cxc      => \@cxc_filtrados,
    total_ingresos => $total_ingresos,
    total_egresos  => $total_egresos,
    total_cxc      => $total_cxc
});
1;
