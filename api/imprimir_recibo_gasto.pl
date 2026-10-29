#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use File::Spec;
use FindBin;
use JSON qw(decode_json);
use MIME::Base64 qw(encode_base64);
use lib "$FindBin::Bin/..";

my $script_dir = $FindBin::Bin;
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

binmode STDOUT, ':utf8';

my $q = CGI->new;
my $session_data = check_session($q);

unless ($session_data->{session_ok}) {
    print $q->redirect(-uri => '../index.pl');
    exit;
}

my $id_gasto = $q->param('id_gasto') || '';
$id_gasto =~ s/^\s+|\s+$//g;

if (!$id_gasto) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<h1>Error: Falta ID de Gasto</h1>";
    exit;
}

# 1. Leer Gasto desde dat/gastos.dat
# Columnas: ID_GASTO|FECHA|ID_CAT|ID_SUBCAT|ID_SUBCAT3|CONCEPTO|MONTO|PROVEEDOR|FACTURA_PATH|ID_ORIGEN|ID_CREADOR|ID_NEGOCIO
my $gasto = undef;
my $gastos_file = File::Spec->catfile($script_dir, '..', 'dat', 'gastos.dat');

if (-e $gastos_file && open(my $fh, '<:encoding(UTF-8)', $gastos_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @c = split /\|/, $line, -1;
        if ($c[0] eq $id_gasto) {
            $gasto = {
                id_gasto     => $c[0],
                fecha        => $c[1] // '',
                id_cat       => $c[2] // '',
                id_subcat    => $c[3] // '',
                id_subcat3   => $c[4] // '',
                concepto     => $c[5] // '',
                monto        => $c[6] // 0,
                proveedor    => $c[7] // '',
                factura_path => $c[8] // '',
                id_origen    => $c[9] // '',
                id_creador   => $c[10] // '',
                id_negocio   => $c[11] // '0',
                id_especialidad   => $c[12] // '',
                id_medico         => $c[13] // '',
                recibos_asociados => $c[14] // ''
            };
            last;
        }
    }
    close $fh;
}

if (!$gasto) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print "<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'><title>Error - Gasto no encontrado</title>";
    print "<style>body{font-family:sans-serif;text-align:center;padding:50px;background:#f8fafc;color:#1e293b;}</style></head><body>";
    print "<h2 style='color:#dc2626;'>Comprobante de Egreso No Encontrado</h2>";
    print "<p>El registro de egreso solicitado (#" . $q->escapeHTML($id_gasto) . ") no existe o fue eliminado.</p>";
    print "<button onclick='window.close();' style='padding:8px 16px;background:#0A2A66;color:#fff;border:none;border-radius:6px;cursor:pointer;'>Cerrar Ventana</button>";
    print "</body></html>";
    exit;
}

# 2. Control Multitenant
my $ses_org = $session_data->{id_empresa} // '';
my $ses_role = $session_data->{role} // '';
if ($ses_role ne 'Administrador Global' && defined $ses_org && $ses_org ne '') {
    my $g_emp = $gasto->{id_negocio} // '0';
    if ($g_emp ne $ses_org && !($g_emp eq '0' && $ses_org eq '0')) {
        print $q->header(-type => 'text/html', -charset => 'UTF-8');
        print "<h1>Acceso Denegado: Este comprobante pertenece a otra organización.</h1>";
        exit;
    }
}

# Función para reparar posibles cadenas con doble codificación UTF-8
sub reparar_utf8 {
    my ($str) = @_;
    return '' unless defined $str;
    if ($str =~ /[\xC2\xC3][\x80-\xBF]/) {
        eval {
            require Encode;
            my $bytes = Encode::encode('latin1', $str);
            my $decoded = Encode::decode('utf8', $bytes);
            $str = $decoded if $decoded;
        };
    }
    return $str;
}

# 3. Resolver Categorías, Subcategorías y Nivel 3 con Aislamiento Multi-Tenant Estricto
my $target_negocio_id = $gasto->{id_negocio} || $session_data->{id_empresa} || '0';
$target_negocio_id =~ s/^\s+|\s+$//g;

my $cat_nombre    = 'Sin Categoría';
my $subcat_nombre = '';
my $subcat3_nombre = '';

if ($gasto->{id_cat}) {
    my $cat_file = File::Spec->catfile($script_dir, '..', 'dat', 'categorias.dat');
    if (-e $cat_file && open(my $fc, '<:encoding(UTF-8)', $cat_file)) {
        <$fc>;
        my $cat_fallback = '';
        while (my $l = <$fc>) {
            chomp $l;
            my @f = split /\|/, $l, -1;
            my $f_neg = $f[3] // '0';
            $f_neg =~ s/^\s+|\s+$//g;
            if ($f[0] eq $gasto->{id_cat}) {
                $cat_fallback ||= $f[1];
                if ($f_neg eq $target_negocio_id || (!$f_neg && $target_negocio_id eq '0')) {
                    $cat_nombre = $f[1] // 'Sin Categoría';
                    $cat_fallback = '';
                    last;
                }
            }
        }
        $cat_nombre = $cat_fallback if $cat_fallback && $cat_nombre eq 'Sin Categoría';
        close $fc;
    }
}

if ($gasto->{id_subcat}) {
    my $sc_file = File::Spec->catfile($script_dir, '..', 'dat', 'sub_categoria.dat');
    if (-e $sc_file && open(my $fsc, '<:encoding(UTF-8)', $sc_file)) {
        <$fsc>;
        my $sc_fallback = '';
        while (my $l = <$fsc>) {
            chomp $l;
            my @f = split /\|/, $l, -1;
            my $f_neg = $f[4] // '0';
            $f_neg =~ s/^\s+|\s+$//g;
            if ($f[0] eq $gasto->{id_subcat}) {
                $sc_fallback ||= $f[2];
                if ($f_neg eq $target_negocio_id || (!$f_neg && $target_negocio_id eq '0')) {
                    $subcat_nombre = $f[2] // '';
                    $sc_fallback = '';
                    last;
                }
            }
        }
        $subcat_nombre = $sc_fallback if $sc_fallback && !$subcat_nombre;
        close $fsc;
    }
}

if ($gasto->{id_subcat3}) {
    my $sc3_file = File::Spec->catfile($script_dir, '..', 'dat', 'sub_categoria_nivel3.dat');
    if (-e $sc3_file && open(my $fsc3, '<:encoding(UTF-8)', $sc3_file)) {
        <$fsc3>;
        my $sc3_fallback = '';
        while (my $l = <$fsc3>) {
            chomp $l;
            my @f = split /\|/, $l, -1;
            my $f_neg = $f[3] // '0';
            $f_neg =~ s/^\s+|\s+$//g;
            if ($f[0] eq $gasto->{id_subcat3}) {
                $sc3_fallback ||= $f[2];
                if ($f_neg eq $target_negocio_id || (!$f_neg && $target_negocio_id eq '0')) {
                    $subcat3_nombre = $f[2] // '';
                    $sc3_fallback = '';
                    last;
                }
            }
        }
        $subcat3_nombre = $sc3_fallback if $sc3_fallback && !$subcat3_nombre;
        close $fsc3;
    }
}

# 4. Resolver Origen del Dinero con Aislamiento Multi-Tenant
my $origen_nombre = 'Efectivo / Caja General';
if ($gasto->{id_origen}) {
    my $orig_file = File::Spec->catfile($script_dir, '..', 'dat', 'origen_dinero.dat');
    if (-e $orig_file && open(my $fo, '<:encoding(UTF-8)', $orig_file)) {
        <$fo>;
        my $o_fallback = '';
        while (my $l = <$fo>) {
            chomp $l;
            my @f = split /\|/, $l, -1;
            my $f_neg = $f[3] // '0';
            $f_neg =~ s/^\s+|\s+$//g;
            if ($f[0] eq $gasto->{id_origen}) {
                $o_fallback ||= $f[1];
                if ($f_neg eq $target_negocio_id || (!$f_neg && $target_negocio_id eq '0')) {
                    $origen_nombre = $f[1] // 'Efectivo / Caja General';
                    $o_fallback = '';
                    last;
                }
            }
        }
        $origen_nombre = $o_fallback if $o_fallback && $origen_nombre eq 'Efectivo / Caja General';
        close $fo;
    }
}

# 5. Resolver Datos del Negocio y CLUES (Idéntico a imprimir_recibo_caja.pl)
my $negocio = {
    nombre    => 'Organización Médica',
    domicilio => 'Dirección no registrada',
    telefono  => 'Sin teléfono',
    logo_url  => '',
    clues     => ''
};
my $negocios_file = File::Spec->catfile($script_dir, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fhn, '<:encoding(UTF-8)', $negocios_file)) {
    <$fhn>;
    while (my $ln = <$fhn>) {
        chomp $ln;
        my @n = split /\|/, $ln, -1;
        if ($n[0] eq $target_negocio_id || ($target_negocio_id eq '0' && $n[0])) {
            $negocio->{nombre}    = $n[1] // '';
            $negocio->{domicilio} = ($n[3] // '') . ', ' . ($n[4] // '') . ', ' . ($n[7] // '') . ', ' . ($n[8] // '');
            $negocio->{telefono}  = $n[12] // '';
            $negocio->{clues}     = $n[18] // $n[1] // '';
            $negocio->{logo_url}  = $n[9] // '';
            last if $n[0] eq $target_negocio_id;
        }
    }
    close $fhn;
}

# 5.1 Datos estructurados para el pie (CLUE o Sucursal)
my $clue_encontrada = 0;
my ($pie_calle_no, $pie_colonia, $pie_municipio, $pie_entidad, $pie_telefono, $pie_cp) = ('', '', '', '', '', '');

my $clues_id_actual = $negocio->{clues} // '';
if ($clues_id_actual) {
    my $cat_clues_file = File::Spec->catfile($script_dir, '..', 'dat', 'catalogosOF', 'CAT_CLUES.dat');
    if (-e $cat_clues_file && open(my $fh_clue, '<:encoding(UTF-8)', $cat_clues_file)) {
        <$fh_clue>;
        while (my $line = <$fh_clue>) {
            chomp $line;
            next unless $line;
            my @c = split /\|/, $line, -1;
            if (@c > 32 && $c[0] eq $clues_id_actual) {
                my $vialidad_tipo = $c[20] // '';
                my $vialidad_nom  = $c[21] // '';
                my $num_ext       = $c[22] // '';
                
                my $dir_calle = join(' ', grep { $_ ne '' } ($vialidad_tipo, $vialidad_nom, $num_ext));
                $pie_calle_no  = $dir_calle || ($c[28] // '');
                $pie_colonia   = $c[26] || $c[8] || '';
                $pie_municipio = $c[6] // '';
                $pie_entidad   = $c[4] // '';
                $pie_telefono  = $c[32] // '';
                $pie_cp        = $c[27] // '';
                $clue_encontrada = 1;
                last;
            }
        }
        close $fh_clue;
    }
}

if (!$clue_encontrada) {
    if ($target_negocio_id && -e $negocios_file && open(my $fn_suc, '<:encoding(UTF-8)', $negocios_file)) {
        <$fn_suc>;
        while (my $line = <$fn_suc>) {
            chomp $line;
            my @n = split /\|/, $line, -1;
            if ($n[0] eq $target_negocio_id) {
                $pie_calle_no  = $n[6] // '';
                $pie_colonia   = $n[17] // '';
                $pie_municipio = $n[16] // '';
                $pie_entidad   = $n[15] // '';
                $pie_telefono  = $n[7] // '';
                $pie_cp        = $n[14] // '';
                last;
            }
        }
        close $fn_suc;
    }
}

foreach ($pie_calle_no, $pie_colonia, $pie_municipio, $pie_entidad, $pie_telefono, $pie_cp) {
    s/[\(\)]//g;
    s/^\s+|\s+$//g;
}

my @pie_partes;
push @pie_partes, $pie_calle_no        if $pie_calle_no ne '';
push @pie_partes, $pie_colonia         if $pie_colonia ne '';
push @pie_partes, $pie_municipio       if $pie_municipio ne '';
push @pie_partes, $pie_entidad         if $pie_entidad ne '';
push @pie_partes, "Tel. $pie_telefono" if $pie_telefono ne '';
push @pie_partes, "C.P. $pie_cp"       if $pie_cp ne '';

my $texto_pie_recibo = join(", ", @pie_partes);
$texto_pie_recibo ||= $negocio->{domicilio} || 'Dirección de la Organización Clínica';

# 6. Logo en Base64
my $logo_html = '';
my $logo_path = '';

if ($negocio->{clues} eq 'QTSMP000116') {
    my $p_img = File::Spec->catfile($script_dir, '..', 'img', 'logos', 'logo_QTSMP000116.jpg');
    my $p_dat = File::Spec->catfile($script_dir, '..', 'dat', 'logos', 'logo_QTSMP000116.jpg');
    $logo_path = -e $p_img ? $p_img : (-e $p_dat ? $p_dat : '');
} elsif ($negocio->{logo_url}) {
    my $p_url = File::Spec->catfile($script_dir, '..', $negocio->{logo_url});
    $logo_path = -e $p_url ? $p_url : '';
}

if ($logo_path && -e $logo_path && open(my $lfh, '<:raw', $logo_path)) {
    my $raw_img = do { local $/; <$lfh> };
    close $lfh;
    my $b64_img = encode_base64($raw_img, '');
    my $mime_type = ($logo_path =~ /\.png$/i) ? 'image/png' : 'image/jpeg';
    $logo_html = qq{<img src="data:$mime_type;base64,$b64_img" alt="Logo" style="max-height: 80px; max-width: 200px;">};
} elsif ($negocio->{logo_url}) {
    $logo_html = qq{<img src="../$negocio->{logo_url}" alt="Logo" style="max-height: 80px; max-width: 200px;">};
} else {
    $logo_html = qq{<h2 style="margin:0; color:#0A2A66; font-size:18px;">$negocio->{nombre}</h2>};
}

# 7. Elaborado / Registrado Por
my $raw_creador = $gasto->{id_creador} // '';
$raw_creador =~ s/^\s+|\s+$//g;
my $elaborado_por = $raw_creador;

if ($raw_creador ne '') {
    my $usr_file = File::Spec->catfile($script_dir, '..', 'dat', 'usuarios.dat');
    if (-e $usr_file && open(my $fu, '<:encoding(UTF-8)', $usr_file)) {
        while (my $lu = <$fu>) {
            chomp $lu;
            next if $lu =~ /^\s*$/ || $lu =~ /^#/ || $lu =~ /^ID!/i;
            my @u = split /!/, $lu, -1;
            if (@u >= 3 && ($u[0] eq $raw_creador || lc($u[2]) eq lc($raw_creador) || lc($u[1]) eq lc($raw_creador))) {
                $elaborado_por = $u[1] if $u[1];
                last;
            }
        }
        close $fu;
    }
}
$elaborado_por ||= 'Administración de Caja';

# 8. Formateo de Moneda y Monto en Letras
sub formato_moneda {
    my ($monto) = @_;
    $monto ||= 0;
    my $fmt = sprintf("%.2f", $monto);
    while ($fmt =~ s/^(-?\d+)(\d{3})/$1,$2/) {}
    return '$' . $fmt;
}

sub numero_a_letras {
    my ($monto) = @_;
    $monto ||= 0;
    my $entero = int($monto);
    my $centavos = int(($monto - $entero) * 100 + 0.5);
    
    my @unidades = ("", "UN", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE");
    my @especiales = ("DIEZ", "ONCE", "DOCE", "TRECE", "CATORCE", "QUINCE", "DIECISEIS", "DIECISIETE", "DIECIOCHO", "DIECINUEVE");
    my @decenas = ("", "DIEZ", "VEINTE", "TREINTA", "CUARENTA", "CINCUENTA", "SESENTA", "SETENTA", "OCHENTA", "NOVENTA");
    my @centenas = ("", "CIENTO", "DOSCIENTOS", "TRESCIENTOS", "CUATROCIENTOS", "QUINIENTOS", "SEISCIENTOS", "SETECIENTOS", "OCHOCIENTOS", "NOVECIENTOS");
    
    my $convertir_tres_digitos = sub {
        my ($n) = @_;
        return "" if $n == 0;
        return "CIEN" if $n == 100;
        
        my $c = int($n / 100);
        my $resto = $n % 100;
        my $d = int($resto / 10);
        my $u = $resto % 10;
        
        my $texto = "";
        $texto .= $centenas[$c] . " " if $c > 0;
        
        if ($resto >= 10 && $resto <= 19) {
            $texto .= $especiales[$resto - 10];
        } elsif ($resto >= 21 && $resto <= 29) {
            my $u_txt = ($u == 1) ? "UN" : $unidades[$u];
            $texto .= "VEINTI" . $u_txt;
        } elsif ($resto == 20) {
            $texto .= "VEINTE";
        } elsif ($d > 2) {
            $texto .= $decenas[$d];
            $texto .= " Y " . (($u == 1) ? "UN" : $unidades[$u]) if $u > 0;
        } elsif ($u > 0) {
            $texto .= ($u == 1) ? "UN" : $unidades[$u];
        }
        $texto =~ s/^\s+|\s+$//g;
        return $texto;
    };
    
    my $texto_entero = "";
    if ($entero == 0) {
        $texto_entero = "CERO";
    } elsif ($entero == 1) {
        $texto_entero = "UN";
    } else {
        my $millones = int($entero / 1000000);
        my $resto_millones = $entero % 1000000;
        my $miles = int($resto_millones / 1000);
        my $unidades_final = $resto_millones % 1000;
        
        if ($millones > 0) {
            if ($millones == 1) {
                $texto_entero .= "UN MILLON ";
            } else {
                $texto_entero .= $convertir_tres_digitos->($millones) . " MILLONES ";
            }
        }
        
        if ($miles > 0) {
            if ($miles == 1) {
                $texto_entero .= "MIL ";
            } else {
                $texto_entero .= $convertir_tres_digitos->($miles) . " MIL ";
            }
        }
        
        if ($unidades_final > 0) {
            $texto_entero .= $convertir_tres_digitos->($unidades_final);
        }
    }
    
    $texto_entero =~ s/^\s+|\s+$//g;
    my $moneda = ($entero == 1) ? "PESO" : "PESOS";
    return sprintf("(SON: %s %s %02d/100 M.N.)", $texto_entero, $moneda, $centavos);
}

my $monto_num = $gasto->{monto} || 0;
my $monto_formateado = formato_moneda($monto_num);
my $monto_en_letras  = numero_a_letras($monto_num);

# 9. Folio y Jerarquía de Datos (Con Sanitización UTF-8)
my $folio_egreso = ($id_gasto =~ /^\d+$/) ? sprintf("EGR-%05d", $id_gasto) : "EGR-$id_gasto";
my $proveedor_display = uc(reparar_utf8($gasto->{proveedor} || 'DIVERSO / PÚBLICO GENERAL'));
$cat_nombre    = reparar_utf8($cat_nombre);
$subcat_nombre = reparar_utf8($subcat_nombre);
$subcat3_nombre= reparar_utf8($subcat3_nombre);
$origen_nombre = reparar_utf8($origen_nombre);
$gasto->{concepto} = reparar_utf8($gasto->{concepto});
$elaborado_por = reparar_utf8($elaborado_por);

# Inferencia de Recibos Asociados desde el Concepto si no se guardaron en la columna
if (!$gasto->{recibos_asociados} && $gasto->{concepto} =~ /Recibos:\s*#?([0-9,\s#]+)\)/i) {
    my $f_str = $1;
    $f_str =~ s/#//g;
    $f_str =~ s/\s+//g;
    $gasto->{recibos_asociados} = $f_str;
}

# Breadcrumb jerárquico de categorías
my $arbol_categoria_html = qq{<span class="badge-cat-main">$cat_nombre</span>};
if ($subcat_nombre && $subcat_nombre ne 'N/A') {
    $arbol_categoria_html .= qq{ <span class="cat-sep">▸</span> <span class="badge-cat-sub">$subcat_nombre</span>};
}
if ($subcat3_nombre && $subcat3_nombre ne 'N/A') {
    $arbol_categoria_html .= qq{ <span class="cat-sep">▸</span> <span class="badge-cat-sub3">$subcat3_nombre</span>};
}

# 3.1 Resolver Datos Médicos si aplica (Honorarios / Consultas)
my $especialidad_nombre_res = '';
my $medico_nombre_res = '';

if ($gasto->{id_especialidad}) {
    my $cat_clues = $negocio->{clues};
    if ($cat_clues) {
        my $esp_file = File::Spec->catfile($script_dir, '..', 'dat', 'catalogos_CLUE', $cat_clues, "especialidades_${cat_clues}.dat");
        if (-e $esp_file && open(my $fe, '<:encoding(UTF-8)', $esp_file)) {
            while (my $le = <$fe>) {
                chomp $le;
                my @e = split /\|/, $le, -1;
                if ($e[0] eq $gasto->{id_especialidad}) {
                    $especialidad_nombre_res = $e[1] // '';
                    last;
                }
            }
            close $fe;
        }
    }
    if (!$especialidad_nombre_res) {
        my $esp_dat = File::Spec->catfile($script_dir, '..', 'dat', 'especialidades.dat');
        if (-e $esp_dat && open(my $fe, '<:encoding(UTF-8)', $esp_dat)) {
            while (my $le = <$fe>) {
                chomp $le;
                my @e = split /\|/, $le, -1;
                if ($e[0] eq $gasto->{id_especialidad}) {
                    $especialidad_nombre_res = $e[1] // '';
                    last;
                }
            }
            close $fe;
        }
    }
    $especialidad_nombre_res ||= $gasto->{id_especialidad};
}

if ($gasto->{id_medico}) {
    my $cat_clues = $negocio->{clues};
    if ($cat_clues) {
        my $med_file = File::Spec->catfile($script_dir, '..', 'dat', 'catalogos_CLUE', $cat_clues, "medicos_${cat_clues}.dat");
        if (-e $med_file && open(my $fm, '<:encoding(UTF-8)', $med_file)) {
            while (my $lm = <$fm>) {
                chomp $lm;
                my @m = split /\|/, $lm, -1;
                if ($m[0] eq $gasto->{id_medico}) {
                    $medico_nombre_res = $m[2] // '';
                    last;
                }
            }
            close $fm;
        }
    }
    if (!$medico_nombre_res) {
        my $usr_file = File::Spec->catfile($script_dir, '..', 'dat', 'usuarios.dat');
        if (-e $usr_file && open(my $fu, '<:encoding(UTF-8)', $usr_file)) {
            while (my $lu = <$fu>) {
                chomp $lu;
                my @u = split /!/, $lu, -1;
                if ($u[0] eq $gasto->{id_medico}) {
                    $medico_nombre_res = $u[1] // '';
                    last;
                }
            }
            close $fu;
        }
    }
    $medico_nombre_res ||= $gasto->{id_medico};
}

# Fallback: Inferencia desde el Proveedor si el concepto o categoría indican honorarios
if (!$medico_nombre_res && ($gasto->{proveedor} =~ /^(DR|DRA|M[EÉ]DICO|LIC)/i || $cat_nombre =~ /honorarios/i)) {
    my $cat_clues = $negocio->{clues} || 'QTSMP000116';
    my $med_file = File::Spec->catfile($script_dir, '..', 'dat', 'catalogos_CLUE', $cat_clues, "medicos_${cat_clues}.dat");
    if (-e $med_file && open(my $fm, '<:encoding(UTF-8)', $med_file)) {
        my $prov_clean = uc($gasto->{proveedor});
        $prov_clean =~ s/^\s+|\s+$//g;
        while (my $lm = <$fm>) {
            chomp $lm;
            my @m = split /\|/, $lm, -1;
            if (@m >= 3) {
                my $m_nom = uc($m[2]);
                $m_nom =~ s/^\s+|\s+$//g;
                if ($m_nom eq $prov_clean || $prov_clean =~ /\Q$m_nom\E/) {
                    $medico_nombre_res = $m[2];
                    if (!$especialidad_nombre_res && $m[1]) {
                        my $esp_file = File::Spec->catfile($script_dir, '..', 'dat', 'catalogos_CLUE', $cat_clues, "especialidades_${cat_clues}.dat");
                        if (-e $esp_file && open(my $fe, '<:encoding(UTF-8)', $esp_file)) {
                            while (my $le = <$fe>) {
                                chomp $le;
                                my @e = split /\|/, $le, -1;
                                if ($e[0] eq $m[1]) {
                                    $especialidad_nombre_res = $e[1];
                                    last;
                                }
                            }
                            close $fe;
                        }
                    }
                    last;
                }
            }
        }
        close $fm;
    }
}

# Preparar bloque HTML para honorarios si existen datos
my $bloque_honorarios_html = '';
my $es_cat_honorarios = ($cat_nombre =~ /honorarios/i || $cat_nombre =~ /consultas?\s*especialidad/i || $cat_nombre =~ /consultas?\s*generales?/i) ? 1 : 0;

if ($es_cat_honorarios || $medico_nombre_res || $especialidad_nombre_res || $gasto->{recibos_asociados}) {
    my $med_display = uc(reparar_utf8($medico_nombre_res || $gasto->{proveedor} || 'NO ESPECIFICADO'));
    my $esp_display = uc(reparar_utf8($especialidad_nombre_res || 'CONSULTA MÉDICA'));
    
    my $rec_row = '';
    if ($gasto->{recibos_asociados}) {
        my @fol_arr = split /,/, $gasto->{recibos_asociados};
        my $fol_txt = join(', ', map { "Folio #$_" } @fol_arr);
        $rec_row = qq{
            <tr>
                <td class="info-label-cell" style="vertical-align: top;">Recibos de Ingreso Amparados :</td>
                <td colspan="2">
                    <div style="font-weight: 700; color: #047857; font-size: 11px; margin-bottom: 2px;">
                        $fol_txt
                    </div>
                    <span style="font-size: 9.5px; color: #64748b;">Comprobantes de ingreso liquidados correspondientes a los honorarios médicos.</span>
                </td>
            </tr>
        };
    }
    
    $bloque_honorarios_html = qq{
        <tr>
            <td class="info-label-cell" style="border-left: 4px solid #19B7A5;">Médico Tratante :</td>
            <td colspan="2" style="font-weight: 800; color: #0A2A66; font-size: 12px; text-transform: uppercase;">
                $med_display
            </td>
        </tr>
        <tr>
            <td class="info-label-cell">Especialidad :</td>
            <td colspan="2">
                <span style="background: #e0f2fe; color: #0369a1; padding: 3px 8px; border-radius: 4px; font-weight: 700; font-size: 11px; display: inline-block;">
                    $esp_display
                </span>
            </td>
        </tr>
        $rec_row
    };
}

# Comprobante / Factura adjunta
my $adjunto_html = '';
if ($gasto->{factura_path}) {
    my $f_link = "../" . $gasto->{factura_path};
    $adjunto_html = qq{
        <div class="comprobante-tag no-print">
            <span style="font-weight: 700; color: #0284c7;">📁 Factura / Comprobante Adjunto:</span>
            <a href="$f_link" target="_blank" style="color: #0284c7; text-decoration: underline; margin-left: 6px;">Visualizar Archivo Digital</a>
        </div>
        <div class="comprobante-tag print-only" style="display: none;">
            <span style="font-weight: 700; color: #334155;">📁 Comprobante Digital:</span> Factura / Archivo Fiscal registrado y resguardado en sistema.
        </div>
    };
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Comprobante de Egreso $folio_egreso</title>

    <!-- OSPulso Brand Identity (Favicons) -->
    <link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
    <link rel="icon" type="image/png" sizes="16x16" href="../favicon/favicon-16x16.png">
    <link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="64x64" href="../favicon/favicon-64x64.png">
    <link rel="icon" type="image/png" sizes="128x128" href="../favicon/favicon-128x128.png">
    <link rel="icon" type="image/x-icon" href="../favicon/favicon.ico">
    <link rel="apple-touch-icon" sizes="180x180" href="../favicon/apple-touch-icon.png">
    <link rel="manifest" href="../favicon/site.webmanifest">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght\@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        /* CSS Específico para Impresión en Hoja Carta Vertical */
        \@page {
            size: letter portrait;
            margin: 15mm;
        }
        * {
            box-sizing: border-box;
        }
        body {
            font-family: 'Plus Jakarta Sans', Arial, sans-serif;
            margin: 0;
            padding: 0;
            color: #0f172a;
            font-size: 11px;
            background: #fff;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }
        .receipt-container {
            width: 100%;
            max-width: 100%;
            box-sizing: border-box;
            margin: 0 auto;
        }
        .grid-receipt {
            width: 100%;
            border-collapse: collapse;
            border-spacing: 0;
            margin-bottom: 8px;
            font-size: 11px;
            color: #000;
            font-family: Arial, sans-serif;
            font-weight: normal;
        }
        .grid-receipt td {
            border: 1px solid #94a3b8;
            padding: 7px 10px;
            vertical-align: middle;
            font-weight: normal;
        }
        .header-row td {
            text-align: center;
        }
        .col-logo { width: 25%; }
        .col-clinic { 
            width: 45%; 
            font-size: 13px; 
            font-weight: bold; 
            text-transform: uppercase; 
            color: #0A2A66; 
            text-align: center; 
        }
        .col-folio { width: 30%; font-size: 11px; color: #000; text-align: center; }
        .info-label-cell {
            width: 25%;
            font-weight: bold;
            color: #000;
            background: #f8fafc;
            font-size: 10.5px;
        }
        .primary-highlight-cell {
            background: #ffffff;
            font-weight: normal;
        }
        .proveedor-destacado {
            font-size: 13px;
            font-weight: 800;
            color: #0A2A66;
            letter-spacing: 0.3px;
        }
        .badge-cat-main {
            background: #e0f2fe;
            color: #0369a1;
            padding: 3px 8px;
            border-radius: 4px;
            font-weight: 700;
            font-size: 11px;
            display: inline-block;
        }
        .badge-cat-sub {
            background: #f1f5f9;
            color: #334155;
            padding: 2px 7px;
            border-radius: 4px;
            font-weight: 600;
            font-size: 10.5px;
            display: inline-block;
        }
        .badge-cat-sub3 {
            background: #f8fafc;
            color: #64748b;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 10px;
            display: inline-block;
            border: 1px dashed #cbd5e1;
        }
        .cat-sep {
            color: #94a3b8;
            font-size: 10px;
            margin: 0 4px;
        }
        .comprobante-tag {
            margin-top: 6px;
            font-size: 10px;
            background: #f0fdf4;
            border: 1px solid #bbf7d0;
            padding: 4px 8px;
            border-radius: 4px;
        }
        .monto-total-box {
            text-align: right;
            padding: 10px 14px;
        }
        .monto-total-val {
            font-size: 16px;
            font-weight: 800;
            color: #b91c1c;
            margin-bottom: 4px;
        }
        .monto-letras-val {
            font-size: 9.5px;
            color: #334155;
            font-style: italic;
            margin-bottom: 8px;
        }
        .signature-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
            margin-bottom: 10px;
        }
        .signature-table td {
            width: 50%;
            border: none !important;
            padding: 10px 20px;
            text-align: center;
        }
        .signature-line {
            border-top: 1px solid #475569;
            padding-top: 5px;
            font-size: 10px;
            color: #000;
        }
        .signature-role {
            font-size: 9px;
            color: #64748b;
        }
        \@media screen {
            body { 
                background: #e2e8f0; 
                padding: 24px; 
            }
            .receipt-container {
                max-width: 7.5in;
                background: white;
                box-shadow: 0 4px 15px rgba(0,0,0,0.1);
                padding: 0.4in;
                border-radius: 6px;
            }
        }
        \@media print {
            body { 
                background: #fff; 
                padding: 0; 
                margin: 0; 
            }
            .no-print { 
                display: none !important; 
            }
            .print-only {
                display: block !important;
            }
            .receipt-container {
                width: 100% !important;
                max-width: 100% !important;
                padding: 0 !important;
                margin: 0 !important;
                box-shadow: none !important;
                border: none !important;
            }
        }
    </style>
</head>
<body>
    <div class="no-print" style="max-width: 8.5in; margin: 0 auto 15px auto; padding: 12px 20px; background: #0A2A66; color: white; border-radius: 12px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 12px rgba(10,42,102,0.15); font-family: 'Plus Jakarta Sans', sans-serif;">
        <div style="display: flex; align-items: center; gap: 10px;">
            <span style="background: rgba(25,183,165,0.25); color: #19B7A5; border: 1px solid rgba(25,183,165,0.5); padding: 4px 10px; border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase;">Comprobante de Egreso</span>
            <span style="font-weight: 700; font-size: 14px;">Folio #$folio_egreso</span>
        </div>
        <div style="display: flex; gap: 10px; align-items: center;">
            <button type="button" onclick="volverPadre()" style="background: rgba(255,255,255,0.15); color: white; border: 1px solid rgba(255,255,255,0.3); padding: 7px 16px; border-radius: 8px; font-weight: 700; font-size: 12px; cursor: pointer; transition: all 0.2s;">
                ← Volver / Cerrar
            </button>
            <button type="button" onclick="window.print()" style="background: #19B7A5; color: white; border: none; padding: 7px 18px; border-radius: 8px; font-weight: 800; font-size: 12px; cursor: pointer; box-shadow: 0 2px 6px rgba(25,183,165,0.4); transition: all 0.2s;">
                🖨️ Imprimir / Guardar PDF
            </button>
        </div>
    </div>
    
    <div class="receipt-container" style="font-family: Arial, sans-serif;">
        <table class="grid-receipt">
            <!-- 1. Encabezado Institucional -->
            <tr class="header-row">
                <td class="col-logo">
                    <div style="text-align: center;">
                        $logo_html
                    </div>
                </td>
                <td class="col-clinic">
                    $negocio->{nombre}<br>
                    <span style="font-size: 10px; font-weight: bold; color: #475569; letter-spacing: 0.5px;">COMPROBANTE DE EGRESO Y GASTO OPERATIVO</span>
                </td>
                <td class="col-folio" style="font-size: 9px; white-space: nowrap; text-align: center;">
                    Fecha: <b>$gasto->{fecha}</b><br>
                    <span style="margin-top: 4px; display:inline-block; font-weight: bold; color: #64748b;">Folio de Egreso</span><br>
                    <span style="font-size: 12px; font-weight: bold; color: #0A2A66;">$folio_egreso</span><br>
                    <span style="margin-top: 4px; display: inline-block; font-size: 8.5px; color: #059669; font-weight: bold; background: #ecfdf5; border: 1px solid #a7f3d0; padding: 1px 6px; border-radius: 3px;">APLICADO / PAGADO</span>
                </td>
            </tr>

            <!-- 2. Jerarquía Primordial: PROVEEDOR / BENEFICIARIO -->
            <tr>
                <td class="info-label-cell" style="border-left: 4px solid #19B7A5;">Proveedor / Beneficiario :</td>
                <td colspan="2" class="primary-highlight-cell">
                    <div class="proveedor-destacado">$proveedor_display</div>
                </td>
            </tr>

            <!-- 3. Jerarquía Primordial: CATEGORÍA Y SUB-CLASIFICACIÓN -->
            <tr>
                <td class="info-label-cell" style="border-left: 4px solid #0A2A66;">Categoría / Clasificación :</td>
                <td colspan="2" class="primary-highlight-cell">
                    $arbol_categoria_html
                </td>
            </tr>

            $bloque_honorarios_html

            <!-- 4. Concepto y Justificación Operativa -->
            <tr>
                <td class="info-label-cell" style="vertical-align: top;">Concepto / Justificación :</td>
                <td colspan="2">
                    <div style="font-size: 11px; color: #0f172a; line-height: 1.4;">$gasto->{concepto}</div>
                    $adjunto_html
                </td>
            </tr>

            <!-- 5. Forma de Pago y Origen de Fondos -->
            <tr>
                <td class="info-label-cell">Origen de Fondos / Caja :</td>
                <td colspan="2">
                    <span style="border: 1px solid #94a3b8; border-radius: 4px; padding: 2px 8px; font-size: 10px; font-weight: 600; display: inline-block; background: #f8fafc;">
                        $origen_nombre
                    </span>
                </td>
            </tr>

            <!-- 6. Total e Importe con Letra -->
            <tr>
                <td colspan="3" class="monto-total-box">
                    <div class="monto-total-val">TOTAL PAGADO : $monto_formateado</div>
                    <div class="monto-letras-val">$monto_en_letras</div>
                    <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px dashed #cbd5e1; padding-top: 6px; margin-top: 4px;">
                        <span style="font-size: 9.5px; color: #64748b;">Tipo de Transacción: Salida Operativa de Caja</span>
                        <span style="font-size: 10px; font-weight: normal; color: #334155; white-space: nowrap;">Registró : <b>$elaborado_por</b></span>
                    </div>
                </td>
            </tr>

            <!-- 7. Firmas de Control Interno (Auditoría) -->
            <tr>
                <td colspan="3" style="padding: 10px 14px 6px 14px; background: #fafafa;">
                    <table class="signature-table">
                        <tr>
                            <td>
                                <div style="height: 38px;"></div>
                                <div class="signature-line">
                                    <b>$elaborado_por</b><br>
                                    <span class="signature-role">Entrega / Autoriza (Control Caja)</span>
                                </div>
                            </td>
                            <td>
                                <div style="height: 38px;"></div>
                                <div class="signature-line">
                                    <b>$proveedor_display</b><br>
                                    <span class="signature-role">Recibe Conforme (Beneficiario)</span>
                                </div>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- 8. Pie de Página Institucional -->
            <tr>
                <td colspan="3" style="text-align: center; font-size: 8px; font-weight: normal; padding: 6px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; letter-spacing: -0.2px; color: #475569;">
                    $texto_pie_recibo
                </td>
            </tr>
        </table>
    </div>

    <script>
        function volverPadre() {
            if (window.opener && !window.opener.closed) {
                window.opener.focus();
                window.close();
            } else if (window.history.length > 1) {
                window.history.back();
            } else {
                window.location.href = '../views/finanzas.pl?tab=gastos';
            }
        }
    </script>
</body>
</html>
HTML
