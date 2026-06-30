#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use lib '..';
use utils::db_manager qw(leer_tabla obtener_nuevo_id guardar_registro actualizar_archivo);

# Forzamos STDOUT a utf8
binmode STDOUT, ":utf8";

require '../auth/check_session.pl';
my $session_data = check_session();
unless ($session_data->{session_ok}) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Sesión caducada. Por favor recargue la página."});
    exit;
}
my $id_medico = $session_data->{id_medico};

# --- CAPTURA DE PAYLOAD PURA JSON / UTF-8 SPA ---
my $q = $session_data->{q};
my $json_text = $q->param('POSTDATA') || '';
unless ($json_text) {
    read(STDIN, $json_text, $ENV{'CONTENT_LENGTH'} || 0);
}

# utf8(1) es CRITICO: Convierte los raw bytes que entran vía la petición en strings puros de perl.
# Conserva los acentos (é) y Ñ de forma nativa sin mal-formarse (Ã±).
my $input = eval { JSON::PP->new->utf8(1)->decode($json_text) };

unless ($input) {
    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Error interno en interpretación JSON de la petición."});
    exit;
}

if ($input->{accion} eq 'crear') {
    # Extracción de Datos
    my $nombre = $input->{nombre} // '';
    my $rfc = $input->{rfc} // '';
    my $curp = $input->{curp} // '';
    
    # 1. Blindaje Backend - Nombres Puros
    if ($nombre =~ /[^a-zA-ZáéíóúÁÉÍÓÚñÑ\s]/) {
        print "Content-Type: application/json; charset=UTF-8\n\n";
        print JSON::PP->new->utf8(0)->encode({ok=>0, msg=>"El Sistema Abortó: El nombre contiene elementos no permitidos."});
        exit;
    }

    # Búsqueda de Duplicados Críticos
    my $registros = leer_tabla('../dat/pacientes.dat', '\|');
    foreach my $r (@$registros) {
        next unless @$r >= 6; # Safety bounds
        if ($nombre && lc($r->[2]) eq lc($nombre)) {
            print "Content-Type: application/json; charset=UTF-8\n\n";
            print JSON::PP->new->utf8(0)->encode({ok=>0, msg=>"Inconsistencia: Un expediente con este nombre idéntico ya existe."});
            exit;
        }
        if ($rfc && lc($r->[3]) eq lc($rfc)) {
            print "Content-Type: application/json; charset=UTF-8\n\n";
            print JSON::PP->new->utf8(0)->encode({ok=>0, msg=>"Inconsistencia: Este RFC ($rfc) ya se encuentra resguardado."});
            exit;
        }
        if ($curp && uc($r->[4]) eq uc($curp)) {
            print "Content-Type: application/json; charset=UTF-8\n\n";
            print JSON::PP->new->utf8(0)->encode({ok=>0, msg=>"Inconsistencia: Este CURP ya está amarrado a otro expediente."});
            exit;
        }
    }

    # Creación e Inyección
    my $id_paciente = obtener_nuevo_id('../dat/contador_pacientes.dat');

    my $nueva_linea = join("|",
        $id_paciente,
        $id_medico,
        $nombre,
        uc($rfc),
        uc($curp),
        $input->{correo} // '',
        $input->{fecha_nac} // '',
        $input->{genero} // '',
        $input->{ocupacion} // '',
        $input->{estado_civil} // '',
        $input->{nacionalidad} // '',
        $input->{tipo_sangre} // '',
        $input->{telefono} // ''
    ) . "|";

    guardar_registro('../dat/pacientes.dat', $nueva_linea);

    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 1, msg => "La Ficha Clínica de $nombre ha sido generada correctamente."});
    exit;
} elsif ($input->{accion} eq 'actualizar') {
    my $id_target = $input->{id};
    my $nombre = $input->{nombre} // '';
    my $rfc = $input->{rfc} // '';
    my $curp = $input->{curp} // '';

    my $registros = leer_tabla('../dat/pacientes.dat', '\|');
    my @nuevos_registros;
    my $encontrado = 0;

    foreach my $r (@$registros) {
        if (@$r > 1 && $r->[0] eq $id_target) {
            $encontrado = 1;
            push @nuevos_registros, join("|",
                $id_target,
                $r->[1], # id_medico
                $nombre,
                uc($rfc),
                uc($curp),
                $input->{correo} // '',
                $input->{fecha_nac} // '',
                $input->{genero} // '',
                $input->{ocupacion} // '',
                $input->{estado_civil} // '',
                $input->{nacionalidad} // '',
                $input->{tipo_sangre} // '',
                $input->{telefono} // ''
            ) . "|";
        } else {
            push @nuevos_registros, join("|", @$r);
        }
    }

    if ($encontrado) {
        actualizar_archivo('../dat/pacientes.dat', "ID_PACIENTE|ID_MEDICO|NOMBRE|RFC|CURP|CORREO|FECHA_NAC|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO", \@nuevos_registros);
        print "Content-Type: application/json; charset=UTF-8\n\n";
        print JSON::PP->new->utf8(0)->encode({ok => 1, msg => "El Expediente Clínico ha sido actualizado."});
        exit;
    } else {
        print "Content-Type: application/json; charset=UTF-8\n\n";
        print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Inconsistencia: Expediente no localizado."});
        exit;
    }
}

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Comando sin reconocimiento en el servidor Central."});
exit;

