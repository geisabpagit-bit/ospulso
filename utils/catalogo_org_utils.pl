#!/usr/bin/perl
package catalogo_org_utils;

use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use Fcntl qw(:flock);
use Exporter 'import';

our @EXPORT_OK = qw(
    resolver_id_raiz_catalogo
    obtener_rutas_catalogo
    obtener_rutas_por_clue
    crear_catalogo_org_desde_global
    catalogo_org_existe
    get_catalogo_universal
    obtener_rutas_contadores
    obtener_siguiente_folio_blindado
);

# ─────────────────────────────────────────────────────────────
# _resolver_dat_dir()
# Determina la ruta absoluta del directorio /dat de forma inmune
# al punto de invocación del proceso.
# ─────────────────────────────────────────────────────────────
sub _resolver_dat_dir {
    my $d1 = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    return $d1 if -d $d1;

    my ($vol, $dirs, $f) = File::Spec->splitpath(__FILE__);
    my $this_dir = File::Spec->catpath($vol, $dirs, '');
    my $d2 = File::Spec->catdir($this_dir, '..', 'dat');
    return $d2 if -d $d2;

    my $d3 = File::Spec->catdir($FindBin::Bin, 'dat');
    return $d3 if -d $d3;

    return 'c:/xampp/htdocs/ospulso/dat';
}

# ─────────────────────────────────────────────────────────────
# resolver_id_raiz_catalogo($id_empresa)
# Dado el ID de un negocio, devuelve el ID de la organizacion
# raiz (ID_MATRIZ == 0). Si el negocio ya es raiz, devuelve su propio ID.
# ─────────────────────────────────────────────────────────────
sub resolver_id_raiz_catalogo {
    my ($id_empresa) = @_;
    return 0 unless $id_empresa;

    my $dat = _resolver_dat_dir();
    my $negocios_file = File::Spec->catfile($dat, 'negocios.dat');
    return $id_empresa unless -e $negocios_file;

    open(my $fh, '<:encoding(UTF-8)', $negocios_file) or return $id_empresa;
    <$fh>; # saltar cabecera
    my %negocios;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        next unless @c >= 3;
        $negocios{$c[0]} = $c[2]; # ID => ID_MATRIZ
    }
    close $fh;

    # Si el negocio es raiz (ID_MATRIZ == 0), retornar su propio ID
    if (defined $negocios{$id_empresa} && $negocios{$id_empresa} == 0) {
        return $id_empresa;
    }

    # Si es sucursal, retornar su ID_MATRIZ
    if (defined $negocios{$id_empresa} && $negocios{$id_empresa} > 0) {
        return $negocios{$id_empresa};
    }

    return $id_empresa; # fallback
}

# ─────────────────────────────────────────────────────────────
# obtener_rutas_por_clue($clues)
# Devuelve hashref con rutas absolutas de archivos para cat. basado en CLUE
# ─────────────────────────────────────────────────────────────
sub obtener_rutas_por_clue {
    my ($clues) = @_;
    my $dat = _resolver_dat_dir();
    my $clue_dir = File::Spec->catdir($dat, 'catalogos_CLUE', $clues);
    my $tipos_tar_file = File::Spec->catfile($clue_dir, "tipos_tarifas_${clues}.dat");
    if (!-e $tipos_tar_file && -d $clue_dir) {
        if (open(my $fht, '>:encoding(UTF-8)', $tipos_tar_file)) {
            print $fht "ID_TARIFA|CLAVE|NOMBRE_TARIFA|DESCRIPCION|ACTIVO\n";
            print $fht "1|ESTANDAR|ESTÁNDAR|Público General / Tarifa Base|1\n";
            print $fht "2|MUNICIPIO|MUNICIPIO|Convenio Sindical / Estatal|1\n";
            print $fht "3|URGENCIAS|URGENCIAS|Tarifa de Atención de Urgencias|1\n";
            print $fht "4|LUNES_A_SABADO|LUNES A SÁBADO|Tarifa Ordinaria|1\n";
            print $fht "5|DOMINGOS_Y_FESTIVOS|DOMINGOS Y FESTIVOS|Recargo Dominical / Festivo|1\n";
            print $fht "6|FESTIVO|DÍA FESTIVO|Atención en Día Festivo Oficial|1\n";
            print $fht "7|NORMAL|TURNO NORMAL|Horario Habitual de Consulta|1\n";
            print $fht "8|MATUTINO|TURNO MATUTINO|Horario Matutino|1\n";
            print $fht "9|NOCTURNO|TURNO NOCTURNO|Turno Nocturno|1\n";
            print $fht "10|SABADO_TARDE_DOMINGO_FESTIVO|SÁBADO TARDE / DOMINGO / FESTIVO|Guardia Fin de Semana y Festivo|1\n";
            print $fht "11|PAQUETE_TODO_INCLUIDO|PAQUETE TODO INCLUIDO|Paquete Integral Quirúrgico / Procedimiento|1\n";
            print $fht "12|PAQUETE_SOLO_CLINICA|PAQUETE SOLO CLÍNICA|Paquete Quirúrgico sin Honorarios Médicos|1\n";
            close($fht);
        }
    }

    return {
        is_universal => 1,
        departamentos => File::Spec->catfile($clue_dir, "departamentos_${clues}.dat"),
        categorias => File::Spec->catfile($clue_dir, "categorias_${clues}.dat"),
        proveedores => File::Spec->catfile($clue_dir, "proveedores_${clues}.dat"),
        items => File::Spec->catfile($clue_dir, "catalogo_items_${clues}.dat"),
        precios => File::Spec->catfile($clue_dir, "catalogo_precios_${clues}.dat"),
        productos => File::Spec->catfile($clue_dir, "productos_${clues}.dat"),
        medicos => File::Spec->catfile($clue_dir, "medicos_${clues}.dat"),
        especialidades => File::Spec->catfile($clue_dir, "especialidades_${clues}.dat"),
        dependencia => File::Spec->catfile($clue_dir, "dependencia_${clues}.dat"),
        empleadosmun => File::Spec->catfile($clue_dir, "empleadosmun_${clues}.dat"),
        municipios => File::Spec->catfile($clue_dir, "municipios_${clues}.dat"),
        motivos => File::Spec->catfile($clue_dir, "motivos_${clues}.dat"),
        tipos_tarifas => $tipos_tar_file,
    };
}

# ─────────────────────────────────────────────────────────────
# obtener_rutas_catalogo($id_raiz)
# Devuelve hashref con rutas absolutas de los archivos .dat
# de servicios y productos de la organizacion.
# ─────────────────────────────────────────────────────────────
sub obtener_rutas_catalogo {
    my ($id_raiz) = @_;
    my $dat = _resolver_dat_dir();
    
    # Resolver CLUE
    my $clues = '';
    
    if (defined $id_raiz && $id_raiz eq '0') {
        $clues = 'QTSMP000116';
    } else {
        my $n_file = File::Spec->catfile($dat, 'negocios.dat');
        if (-e $n_file && open(my $nf, '<:encoding(UTF-8)', $n_file)) {
            <$nf>;
            while (my $line = <$nf>) {
                chomp $line;
                my @f = split(/\|/, $line, -1);
                if ($f[0] eq $id_raiz) {
                    $clues = $f[18] // '';
                    last;
                }
            }
            close $nf;
        }
    }
    
    if ($clues) {
        return obtener_rutas_por_clue($clues);
    }
    
    return {
        servicios => File::Spec->catfile($dat, "servicios_${id_raiz}.dat"),
        productos  => File::Spec->catfile($dat, "productos_${id_raiz}.dat"),
        medicos => File::Spec->catfile($dat, "medicos_${id_raiz}.dat"),
        especialidades => File::Spec->catfile($dat, "especialidades_${id_raiz}.dat"),
        dependencia => File::Spec->catfile($dat, "dependencia_${id_raiz}.dat"),
        empleadosmun => File::Spec->catfile($dat, "empleadosmun_${id_raiz}.dat"),
        municipios => File::Spec->catfile($dat, "municipios_${id_raiz}.dat"),
        motivos => File::Spec->catfile($dat, "motivos_${id_raiz}.dat"),
    };
}

# ─────────────────────────────────────────────────────────────
# obtener_rutas_contadores($id_raiz)
# Devuelve hashref con rutas absolutas de los archivos de contadores
# de folios de la organizacion aislados por SaaS Tenant (CLUES o ID_RAIZ).
# ─────────────────────────────────────────────────────────────
sub obtener_rutas_contadores {
    my ($id_raiz) = @_;
    my $dat = _resolver_dat_dir();
    
    # Resolver CLUE
    my $clues = '';
    
    if (defined $id_raiz && $id_raiz eq '0') {
        $clues = 'QTSMP000116';
    } else {
        my $n_file = File::Spec->catfile($dat, 'negocios.dat');
        if (-e $n_file && open(my $nf, '<:encoding(UTF-8)', $n_file)) {
            <$nf>;
            while (my $line = <$nf>) {
                chomp $line;
                my @f = split(/\|/, $line, -1);
                if ($f[0] eq $id_raiz) {
                    $clues = $f[18] // '';
                    last;
                }
            }
            close $nf;
        }
    }
    
    if ($clues) {
        my $clue_dir = File::Spec->catdir($dat, 'catalogos_CLUE', $clues);
        return {
            privados => File::Spec->catfile($clue_dir, "contadores_recibos_privados_${clues}.dat"),
            publicos => File::Spec->catfile($clue_dir, "contadores_recibos_publicos_${clues}.dat"),
        };
    }
    
    # Fallback si no tiene CLUES
    return {
        privados => File::Spec->catfile($dat, "contadores_recibos_privados_${id_raiz}.dat"),
        publicos => File::Spec->catfile($dat, "contadores_recibos_publicos_${id_raiz}.dat"),
    };
}

# ─────────────────────────────────────────────────────────────
# get_catalogo_universal($id_raiz)
# Carga las 5 tablas .dat del catalogo universal en memoria y
# devuelve un hashref estructurado para JSON.
# ─────────────────────────────────────────────────────────────
sub get_catalogo_universal {
    my ($id_raiz) = @_;
    my $rutas = obtener_rutas_catalogo($id_raiz);
    return {} unless $rutas->{is_universal};

    my (@deps, @cats, @provs, @items, %precios_por_item);

    # Leer Precios
    if (-e $rutas->{precios}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{precios});
        <$fh>;
        while (<$fh>) {
            chomp; next if /^\s*$/;
            my @c = split /\|/, $_, -1;
            push @{$precios_por_item{$c[1]}}, {
                id_precio => $c[0], tipo_tarifa => ($c[2] // 'ESTANDAR'), precio_publico => ($c[3] // 0)+0, costo_proveedor => ($c[4] // 0)+0, id_prov => ($c[5] // 1)
            };
        }
        close $fh;
    }

    # Leer Items
    if (-e $rutas->{items}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{items});
        <$fh>;
        while (<$fh>) {
            chomp; next if /^\s*$/;
            my @c = split /\|/, $_, -1;
            push @items, {
                id_item => $c[0], codigo_sku => $c[1], id_cat => $c[2], concepto => $c[3],
                aplica_iva => $c[4], indicaciones => $c[5], tiempo_entrega => $c[6],
                precios => $precios_por_item{$c[0]} || []
            };
        }
        close $fh;
    }

    # Leer Departamentos
    if (-e $rutas->{departamentos}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{departamentos});
        <$fh>; while (<$fh>) { chomp; next if /^\s*$/; my @c=split/\|/; push @deps, { id_dep => $c[0], nombre => $c[1] }; }
        close $fh;
    }

    # Leer Categorias
    if (-e $rutas->{categorias}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{categorias});
        <$fh>; while (<$fh>) { chomp; next if /^\s*$/; my @c=split/\|/; push @cats, { id_cat => $c[0], id_dep => $c[1], nombre => $c[2] }; }
        close $fh;
    }

    # Leer Proveedores
    if (-e $rutas->{proveedores}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{proveedores});
        <$fh>; while (<$fh>) { chomp; next if /^\s*$/; my @c=split/\|/; push @provs, { id_prov => $c[0], nombre => $c[2] }; }
        close $fh;
    }

    # Leer Productos
    my @productos;
    if (exists $rutas->{productos} && -e $rutas->{productos}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{productos});
        <$fh>; # saltar header
        while (<$fh>) {
            chomp; next if /^\s*$/;
            my @c = split /\|/, $_, -1;
            push @productos, {
                id_prod => $c[0], nombre => $c[1], precio => $c[2], cantidad => $c[3], presentacion => $c[4], descripcion => $c[5]
            };
        }
        close $fh;
    }

    # Leer Tipos de Tarifas
    my @tipos_tarifas;
    if (exists $rutas->{tipos_tarifas} && -e $rutas->{tipos_tarifas}) {
        open(my $fh, '<:encoding(UTF-8)', $rutas->{tipos_tarifas});
        <$fh>; # saltar header
        while (<$fh>) {
            chomp; next if /^\s*$/;
            my @c = split /\|/, $_, -1;
            push @tipos_tarifas, {
                id_tarifa     => $c[0],
                clave         => $c[1],
                nombre_tarifa => $c[2],
                descripcion   => $c[3],
                activo        => ($c[4] // 1) + 0
            };
        }
        close $fh;
    }

    return {
        is_universal => 1,
        departamentos => \@deps,
        categorias => \@cats,
        proveedores => \@provs,
        items => \@items,
        productos => \@productos,
        tipos_tarifas => \@tipos_tarifas
    };
}

# ─────────────────────────────────────────────────────────────
# catalogo_org_existe($id_raiz)
# Devuelve 1 si ambos archivos de catalogo de la org existen.
# ─────────────────────────────────────────────────────────────
sub catalogo_org_existe {
    my ($id_raiz) = @_;
    my $rutas = obtener_rutas_catalogo($id_raiz);
    if ($rutas->{is_universal}) {
        return (-e $rutas->{productos} && -e $rutas->{departamentos}) ? 1 : 0;
    }
    return (-e $rutas->{servicios} && -e $rutas->{productos}) ? 1 : 0;
}

# ─────────────────────────────────────────────────────────────
# crear_catalogo_org_desde_global($id_raiz)
# Crea servicios_{ID}.dat y productos_{ID}.dat copiando el
# catalogo global. Si el global no existe, inserta un item base.
# Devuelve { ok => 1 } o { ok => 0, error => $msg }
# ─────────────────────────────────────────────────────────────
sub crear_catalogo_org_desde_global {
    my ($id_raiz) = @_;
    return { ok => 0, error => 'ID raiz invalido' } unless $id_raiz;

    my $rutas       = obtener_rutas_catalogo($id_raiz);
    my $dat_path    = _resolver_dat_dir();
    my $serv_global = File::Spec->catfile($dat_path, 'servicios.dat');
    my $prod_global = File::Spec->catfile($dat_path, 'productos.dat');

    eval {
        if ($rutas->{is_universal}) {
            my ($volume, $directories, $file) = File::Spec->splitpath($rutas->{productos});
            my $clue_dir = File::Spec->catpath($volume, $directories, '');
            if (!-d $clue_dir) {
                mkdir $clue_dir or die "No se pudo crear directorio $clue_dir: $!";
            }

            # ── Productos ─────────────────────────────────────────
            unless (-e $rutas->{productos}) {
                open(my $fh_out, '>:encoding(UTF-8)', $rutas->{productos}) or die "Error: $!";
                if (-e $prod_global) {
                    open(my $fh_in, '<:encoding(UTF-8)', $prod_global) or die "Error: $!";
                    while (my $line = <$fh_in>) { print $fh_out $line; }
                    close $fh_in;
                } else {
                    print $fh_out "ID|NOMBRE|PRECIO|CANTIDAD|PRESENTACION|DESCRIPCION\n";
                }
                close $fh_out;
            }
            # ── Departamentos ─────────────────────────────────────
            unless (-e $rutas->{departamentos}) {
                open(my $fh_out, '>:encoding(UTF-8)', $rutas->{departamentos}) or die "Error: $!";
                print $fh_out "ID|NOMBRE_DEPARTAMENTO\n1|Medicina General\n2|Especialidades\n3|Farmacia\n";
                close $fh_out;
            }
            # ── Categorias ────────────────────────────────────────
            unless (-e $rutas->{categorias}) {
                open(my $fh_out, '>:encoding(UTF-8)', $rutas->{categorias}) or die "Error: $!";
                print $fh_out "ID_CAT|ID_DEP|NOMBRE_CATEGORIA\n1|1|Consulta General\n2|2|Consultas de Especialidad\n3|3|Insumos Generales\n";
                close $fh_out;
            }
            # ── Proveedores ───────────────────────────────────────
            unless (-e $rutas->{proveedores}) {
                open(my $fh_out, '>:encoding(UTF-8)', $rutas->{proveedores}) or die "Error: $!";
                print $fh_out "ID_PROV|ID_MATRIZ|TIPO_PROVEEDOR|NOMBRE_PROVEEDOR|ESPECIALIDAD|TELEFONO|CORREO|DIRECCION\n1|0|INTERNO|STAFF MEDICO GENERAL|Medicina General|||\n";
                close $fh_out;
            }
            # ── Catalogo Items ────────────────────────────────────
            unless (-e $rutas->{items}) {
                open(my $fh_out, '>:encoding(UTF-8)', $rutas->{items}) or die "Error: $!";
                print $fh_out "ID_ITEM|CODIGO_SKU|ID_CAT|CONCEPTO|APLICA_IVA|INDICACIONES|TIEMPO_ENTREGA\n1|CONS-0001|1|Consulta Medica General|0|Sin preparación previa|Inmediato\n";
                close $fh_out;
            }
            # ── Catalogo Precios ──────────────────────────────────
            unless (-e $rutas->{precios}) {
                open(my $fh_out, '>:encoding(UTF-8)', $rutas->{precios}) or die "Error: $!";
                print $fh_out "ID_PRECIO|ID_ITEM|ID_PROV|TIPO_TARIFA|COSTO_BASE|PRECIO_PUBLICO|HONORARIO_FIJO|HONORARIO_PORCENTAJE\n1|1|1|ESTANDAR|100.00|500.00|150.00|0\n";
                close $fh_out;
            }
        } else {
            # ── Servicios ──────────────────────────────────────────
            unless (-e $rutas->{servicios}) {
                open(my $fh_out, '>:encoding(UTF-8)', $rutas->{servicios})
                    or die "No se pudo crear servicios_${id_raiz}.dat: $!";
                flock($fh_out, LOCK_EX);

                if (-e $serv_global) {
                    open(my $fh_in, '<:encoding(UTF-8)', $serv_global)
                        or die "No se pudo leer servicios.dat: $!";
                    while (my $line = <$fh_in>) { print $fh_out $line; }
                    close $fh_in;
                } else {
                    print $fh_out "ID|NOMBRE|PRECIO|DESCRIPCION\n";
                    print $fh_out "1|Consulta General|500.00|Servicio base de la organizacion.\n";
                }
                close $fh_out;
            }

            # ── Productos ─────────────────────────────────────────
            unless (-e $rutas->{productos}) {
                open(my $fh_out, '>:encoding(UTF-8)', $rutas->{productos})
                    or die "No se pudo crear productos_${id_raiz}.dat: $!";
                flock($fh_out, LOCK_EX);

                if (-e $prod_global) {
                    open(my $fh_in, '<:encoding(UTF-8)', $prod_global)
                        or die "No se pudo leer productos.dat: $!";
                    while (my $line = <$fh_in>) { print $fh_out $line; }
                    close $fh_in;
                } else {
                    print $fh_out "ID|NOMBRE|PRECIO|CANTIDAD|PRESENTACION|DESCRIPCION\n";
                    print $fh_out "1|Paracetamol 500mg|50.00|100|Caja 20 tabletas|Analgesico base.\n";
                }
                close $fh_out;
            }
        }
    };

    if ($@) {
        warn "[catalogo_org_utils] Error al crear catalogo org $id_raiz: $@\n";
        return { ok => 0, error => $@ };
    }

    return { ok => 1 };
}

# ─────────────────────────────────────────────────────────────
# obtener_siguiente_folio_blindado($id_raiz, $is_publico, $id_neg, $id_suc)
# Genera de forma atómica y blindada el siguiente folio consecutivo:
# 1. Lee el LAST_FOLIO registrado en el archivo de contadores de la org.
# 2. Inspecciona folios_recibos_*.dat para encontrar el folio máximo existente.
# 3. Toma max(contador, max_folio_dat) para jamás retroceder ni duplicar.
# 4. Incrementa en 1, actualiza contadores_recibos_*.dat y devuelve el folio.
# ─────────────────────────────────────────────────────────────
sub obtener_siguiente_folio_blindado {
    my ($id_raiz, $is_publico, $id_neg, $id_suc) = @_;
    $id_neg = '0' unless defined $id_neg && length($id_neg);
    $id_suc = '0' unless defined $id_suc && length($id_suc);

    my $rutas_cont = obtener_rutas_contadores($id_raiz);
    my $contadores_file = $is_publico ? $rutas_cont->{publicos} : $rutas_cont->{privados};

    # Asegurar que exista el directorio padre
    my ($vol, $dirs, $f) = File::Spec->splitpath($contadores_file);
    my $parent_dir = File::Spec->catpath($vol, $dirs, '');
    if ($parent_dir && !-d $parent_dir) {
        mkdir $parent_dir;
    }

    # 1. Asegurar existencia de archivo contador
    unless (-e $contadores_file) {
        if (open my $fh_init, '>:encoding(UTF-8)', $contadores_file) {
            flock($fh_init, LOCK_EX);
            print $fh_init "ID_NEGOCIO|ID_SUCURSAL|LAST_FOLIO\n";
            close $fh_init;
        }
    }

    # 2. Obtener el máximo folio numérico ya guardado en folios_recibos_*.dat
    my $dat_dir = _resolver_dat_dir();
    my $folios_file = File::Spec->catfile($dat_dir, $is_publico ? 'folios_recibos_publicos.dat' : 'folios_recibos_privados.dat');
    my $max_guardado_dat = 0;

    if (-e $folios_file && open(my $fh_dat, '<:encoding(UTF-8)', $folios_file)) {
        <$fh_dat>; # Saltar cabecera
        while (my $line = <$fh_dat>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @cols = split(/\|/, $line, -1);
            # Columna 1: FOLIO, Columna 2: ID_NEGOCIO, Columna 3: ID_SUCURSAL
            my $f_num = $cols[1] || 0;
            my $f_neg = $cols[2] // '';
            my $f_suc = $cols[3] // '';

            if (($f_neg eq $id_neg || $id_neg eq '0') && ($f_suc eq $id_suc || $id_suc eq '0')) {
                if ($f_num =~ /^(\d+)$/) {
                    $max_guardado_dat = $1 if $1 > $max_guardado_dat;
                }
            }
        }
        close $fh_dat;
    }

    # 3. Leer y bloquear contador para calcular y escribir el siguiente folio
    my $next_folio = 1;
    my @nuevas_lineas;
    my $encontrado = 0;

    if (open my $fh_c, '+<:encoding(UTF-8)', $contadores_file) {
        flock($fh_c, LOCK_EX);
        my @lineas = <$fh_c>;
        my $cabecera = shift @lineas;
        chomp $cabecera if defined $cabecera;
        $cabecera ||= "ID_NEGOCIO|ID_SUCURSAL|LAST_FOLIO";

        foreach my $l (@lineas) {
            chomp $l;
            next if $l =~ /^\s*$/;
            my @c = split /\|/, $l, -1;
            if ($c[0] eq $id_neg && $c[1] eq $id_suc) {
                my $curr_val = int($c[2] || 0);
                my $base = ($curr_val > $max_guardado_dat) ? $curr_val : $max_guardado_dat;
                $next_folio = $base + 1;
                $c[2] = $next_folio;
                $l = join('|', @c);
                $encontrado = 1;
            }
            push @nuevas_lineas, $l;
        }

        if (!$encontrado) {
            my $base = $max_guardado_dat;
            $next_folio = $base + 1;
            push @nuevas_lineas, join('|', $id_neg, $id_suc, $next_folio);
        }

        seek($fh_c, 0, 0);
        truncate($fh_c, 0);
        print $fh_c "$cabecera\n";
        foreach my $nl (@nuevas_lineas) {
            print $fh_c "$nl\n";
        }
        close $fh_c;
    } else {
        $next_folio = $max_guardado_dat + 1;
    }

    return $next_folio;
}

1;
