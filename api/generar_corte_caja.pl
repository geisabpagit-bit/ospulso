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
    my $med_file = File::Spec->catfile($dat_dir, "medicos_$org_clues.dat");
    if (-e $med_file) {
        my $m_data = leer_tabla($med_file);
        foreach my $m (@$m_data) {
            $medicos{$m->[0]} = $m->[1] || $m->[0];
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
        my $fecha = $f->[6] || '';
        my $estatus = $f->[14] || '';
        
        # Ignorar cancelados si los hubiera
        next if $estatus =~ /Cancelado/i;

        # Filtro de fechas (YYYY-MM-DD string comp)
        if ($fecha ge $f_inicio && $fecha le $f_fin) {
            my $abono = $f->[9] || 0;
            $abono =~ s/[^\d\.]//g; # limpiar
            
            $total_ingresos += $abono;
            
            # Resolver nombre del médico
            my $id_med = $f->[15] || '';
            my $nombre_med = $medicos{$id_med} || 'N/D';

            # Simplificar Folio (Extraer el último segmento)
            my $folio_raw = $f->[1] || '';
            my $folio_corto = $folio_raw;
            if ($folio_raw =~ /([^-]+)$/) {
                $folio_corto = $1;
                # Eliminar "OS/YYYY/" si llegara a quedar algo raro o simplemente forzar int
                # Usar +0 convierte "006707" a "6707" y "027380" a "27380" de forma segura.
                # Si el string no es numérico puro, intentamos limpiar ceros a la izquierda.
                $folio_corto =~ s/^0+//;
            }

            push @ingresos_filtrados, {
                folio      => $folio_corto || $folio_raw,
                fecha      => $fecha . ' ' . ($f->[7] || ''),
                paciente   => $f->[5] || 'Público General',
                medico     => $nombre_med,
                forma_pago => $f->[10] || 'Efectivo',
                monto      => $abono
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
          
            push @egresos_filtrados, {
                folio       => $f->[0],
                fecha       => $fecha,
                categoria   => $c_map{$id_cat} || 'Gasto Operativo',
                responsable => $proveedor || 'N/A',
                concepto    => $concepto,
                monto       => $monto
            };
        }
    }
}

# 6. Salida
print encode_json({
    error          => 0,
    ingresos       => \@ingresos_filtrados,
    egresos        => \@egresos_filtrados,
    total_ingresos => $total_ingresos,
    total_egresos  => $total_egresos
});
1;
