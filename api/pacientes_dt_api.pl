#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-type => 'application/json', -status => '403 Forbidden');
    print '{"error":"Sin sesion"}';
    exit;
}

my $draw   = $q->param('draw')   || 1;
my $start  = $q->param('start')  || 0;
my $length = $q->param('length') || 10;
my $search = $q->param('search[value]') || '';

my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');

my $regs = leer_tabla($archivo_pacientes, '\|');
my @filtered;

my $mi_org      = $sd->{id_empresa} || 'X';
my $mi_sucursal = $sd->{id_sucursal} // 0;
my $role        = $sd->{role};

if ($regs) {
    # Para Server Side DataTables, el orden inverso suele ser preferido (nuevos primero)
    my @reversed = reverse @$regs;
    
    foreach my $r (@reversed) {
        next if @$r < 6;
        my $id = $r->[0];
        next if $id =~ /^id_paciente/i;

        my $tenant_pac = $r->[13] // '';
        my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
        
        my $es_mi_tenant = 0;
        
        if ($role eq 'Administrador Global') {
            $es_mi_tenant = 1;
        } elsif ($role =~ /Administrador Organizacion|Soporte/i) {
            if ($org_pac && $org_pac eq $mi_org) {
                $es_mi_tenant = 1;
            } elsif (!$org_pac) {
                $es_mi_tenant = 1;
            }
        } elsif ($role =~ /Medico|Asistente|Recepcion/i) {
            if ($org_pac && $org_pac eq $mi_org) {
                if ($suc_pac eq $mi_sucursal || !$suc_pac || !$mi_sucursal) {
                    $es_mi_tenant = 1;
                }
            } elsif (!$org_pac) {
                $es_mi_tenant = 1;
            }
        }

        if ($es_mi_tenant) {
            my $nombre    = $r->[2] // '';
            my $curp      = $r->[4] // '';
            my $correo    = $r->[5] // '';
            my $fecha_nac = $r->[6] // '';
            my $sexo      = $r->[7] // '';
            my $telefono  = $r->[12] // '';

            if ($search ne '') {
                my $match = 0;
                $match = 1 if $nombre =~ /\Q$search\E/i;
                $match = 1 if $curp =~ /\Q$search\E/i;
                $match = 1 if $correo =~ /\Q$search\E/i;
                $match = 1 if $telefono =~ /\Q$search\E/i;
                next unless $match;
            }

            my $display_id = $id;
            $display_id =~ s/^PAC-TEST-//;
            $display_id =~ s/^PAC-//;
            
            utf8::decode($nombre) unless utf8::is_utf8($nombre);

            push @filtered, [
                "<span class='fw-bold text-muted ps-4'>$display_id</span>",
                "<div><span class='patient-name fw-bold text-navy'>$nombre</span><span class='patient-info-sub d-block mt-1 text-muted'><i class='bi bi-person-badge me-1'></i>$curp</span></div>",
                "<div class='patient-info-sub d-flex flex-column gap-1'><span class='text-muted'><i class='bi bi-telephone me-2'></i>$telefono</span><span class='text-muted'><i class='bi bi-envelope me-2'></i>$correo</span></div>",
                "<div class='patient-info-sub d-flex flex-column gap-1'><span class='text-muted'><i class='bi bi-calendar3 me-2'></i>$fecha_nac</span><span class='text-uppercase text-muted'><i class='bi bi-gender-ambiguous me-2'></i>$sexo</span></div>",
                "<div class='d-flex justify-content-end gap-2 pe-4'><button class='btn p-0 border-0 btn-expediente' data-id='$id' title='Resumen'><div class='icon-container-acrylic'><i class='bi bi-eye'></i></div></button><button onclick=\"confirmBorrar('$id')\" class='btn p-0 border-0 action-btn-delete' title='Eliminar'><div class='icon-container-acrylic text-danger border-danger border-opacity-25' style='background: rgba(220, 53, 69, 0.05);'><i class='bi bi-trash'></i></div></button></div>"
            ];
        }
    }
}

my $recordsTotal = scalar(@filtered);
my $recordsFiltered = $recordsTotal;

my @data = ();
if ($length > 0) {
    my $end = $start + $length - 1;
    $end = $#filtered if $end > $#filtered;
    @data = @filtered[$start .. $end] if $start <= $#filtered;
} else {
    @data = @filtered; 
}

my %response = (
    draw => int($draw),
    recordsTotal => int($recordsTotal),
    recordsFiltered => int($recordsFiltered),
    data => \@data
);

print $q->header(-type => 'application/json', -charset => 'UTF-8');
binmode STDOUT, ":raw";
print JSON::PP->new->utf8(1)->encode(\%response);
1;
