#!/usr/bin/perl
# --- Diamond Edition v3.9.0: Multi-Role Sync API (Patient + Specialist) ---
use cPanelUserConfig;
use strict;
use warnings;
use utf8; 

use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser); 
use JSON::PP;
use lib '..';
use Digest::SHA; 
use Encode qw(decode encode); 

# --- Carga de Módulos ---
require '../auth/check_session.pl'; 

# --- CONSTANTES ---
# Usuarios
use constant U_NOMBRE_INDEX  => 1;  
use constant U_CORREO_INDEX  => 2;  
use constant U_CLAVE_INDEX   => 3;  
use constant U_BIZ_ID_INDEX  => 6;
use constant U_MIN_CAMPOS    => 6;  

# Negocios
use constant B_NOMBRE_INDEX => 1;
use constant B_DIR_INDEX    => 6;
use constant B_TEL_INDEX    => 7;
use constant B_EMAIL_INDEX  => 8;
use constant B_RFC_INDEX    => 10;
use constant B_RAZON_INDEX  => 11;
use constant B_CP_INDEX        => 14;
use constant B_ENTIDAD_INDEX   => 15;
use constant B_MUNICIPIO_INDEX => 16;
use constant B_COLONIA_INDEX   => 17;
use constant B_CLUES_INDEX     => 18;
use constant B_EXT_INDEX       => 19;
use constant B_LAT_INDEX       => 20;
use constant B_LNG_INDEX       => 21;

# Pacientes (Delimitador |)
use constant P_NOMBRE_INDEX => 2;
use constant P_RFC_INDEX    => 3;
use constant P_CURP_INDEX   => 4;
use constant P_CORREO_INDEX => 5;
use constant P_FNAC_INDEX   => 6;
use constant P_SEXO_INDEX   => 7;
use constant P_OCUP_INDEX   => 8;
use constant P_ECIV_INDEX   => 9;
use constant P_NAC_INDEX    => 10;
use constant P_SANGRE_INDEX => 11;
use constant P_TEL_INDEX    => 12;

# --- 1. CONFIGURACIÓN INICIAL ---
my $q = CGI->new;
my $json = JSON::PP->new->allow_nonref->utf8(1); 

print $q->header('application/json; charset=UTF-8');

eval {
    my $session_data = check_session();
    my $session_ok   = $session_data->{session_ok};
    my $correo_login = $session_data->{correo_login};
    my $user_role    = $q->param('user_role') || '';
    
    unless ($session_ok) {
        print $json->encode({ success => 0, message => "Error: Sesión no válida." });
        exit;
    }

    # DATOS COMUNES
    my $u_nombre      = decode('UTF-8', $q->param('nombre_completo') || '');
    my $clave_actual  = $q->param('clave_actual')    || '';
    my $clave_nueva   = $q->param('clave_nueva')     || '';

    unless ($u_nombre && $clave_actual) {
        print $json->encode({ success => 0, message => "Nombre y Clave Actual son requeridos." });
        exit;
    }

    # 1. ACTUALIZAR IDENTIDAD DE USUARIO (usuarios.dat)
    my ($u_success, $u_msg, $id_negocio, $id_usuario) = actualizar_usuario(
        correo       => $correo_login,
        nombre       => $u_nombre,
        clave_actual => $clave_actual,
        clave_nueva  => $clave_nueva,
    );

    unless ($u_success) {
        print $json->encode({ success => 0, message => $u_msg });
        exit;
    }

    # 2. ACTUALIZACIÓN SEGÚN ROL
    if ($user_role eq 'Paciente') {
        # MODO PACIENTE: Actualizar pacientes.dat
        my %p_data = (
            nombre => $u_nombre,
            rfc    => decode('UTF-8', $q->param('p_rfc')    || ''),
            curp   => decode('UTF-8', $q->param('p_curp')   || ''),
            fnac   => decode('UTF-8', $q->param('p_fnac')   || ''),
            sexo   => decode('UTF-8', $q->param('p_sexo')   || ''),
            sangre => decode('UTF-8', $q->param('p_sangre') || ''),
            ecivil => decode('UTF-8', $q->param('p_ecivil') || ''),
            ocup   => decode('UTF-8', $q->param('p_ocup')   || ''),
            nac    => decode('UTF-8', $q->param('p_nac')    || ''),
            tel    => decode('UTF-8', $q->param('p_tel')    || ''),
        );
        actualizar_paciente($correo_login, \%p_data);
    } else {
        # MODO ESPECIALISTA: Actualizar negocios.dat
        if ($id_negocio && $id_negocio ne '0') {
            actualizar_negocio(
                id_negocio => $id_negocio,
                nombre     => decode('UTF-8', $q->param('biz_nombre') || ''),
                rfc        => decode('UTF-8', $q->param('biz_rfc')    || ''),
                razon      => decode('UTF-8', $q->param('biz_razon')  || ''),
                tel        => decode('UTF-8', $q->param('biz_tel')    || ''),
                email      => decode('UTF-8', $q->param('biz_email')  || ''),
                dir        => decode('UTF-8', $q->param('biz_dir')    || ''),
                
                # DEBUG LOG
                debug_email => decode('UTF-8', $q->param('biz_email') || 'VACIO'),
                cp         => decode('UTF-8', $q->param('biz_cp')     || ''),
                entidad    => decode('UTF-8', $q->param('biz_entidad') || ''),
                municipio  => decode('UTF-8', $q->param('biz_municipio') || ''),
                colonia    => decode('UTF-8', $q->param('biz_colonia') || ''),
                clues      => decode('UTF-8', $q->param('biz_clues')   || ''),
                extension  => decode('UTF-8', $q->param('biz_ext')     || '0'),
                latitud    => decode('UTF-8', $q->param('biz_lat')     || ''),
                longitud   => decode('UTF-8', $q->param('biz_lng')     || ''),
            );
        }
        
        # ACTUALIZAR PERFIL EXTENDIDO (perfiles.dat)
        if ($id_usuario) {
            actualizar_perfil_extendido(
                id_usuario         => $id_usuario,
                clave_formacion    => decode('UTF-8', $q->param('biz_formacion') || ''),
                clave_nacionalidad => decode('UTF-8', $q->param('biz_nacionalidad') || ''),
                clave_religion     => decode('UTF-8', $q->param('biz_religion') || '')
            );
        }
    }

    # 3. SINCRONIZAR SESIÓN
    if ($session_data->{session}) { 
        my $nc = encode('UTF-8', $u_nombre);
        $session_data->{session}->param('usuario', $nc);
        $session_data->{session}->param('nombre_completo', $nc); 
        $session_data->{session}->flush();
    }
    
    print $json->encode({ success => 1, message => $u_msg });
};

if ($@) {
    print $json->encode({ success => 0, message => "Error Fatal: $@" });
}

# --- SUBS ---

sub actualizar_usuario {
    my %args = @_;
    my ($archivo, $temp) = ("../dat/usuarios.dat", "../dat/usuarios.tmp");
    my ($id_negocio, $found, $id_user) = (0, 0, '');
    
    open(my $in, '<:encoding(UTF-8)', $archivo) or return (0, "Error lectura");
    open(my $out, '>:encoding(UTF-8)', $temp) or return (0, "Error escritura");
    while (my $line = <$in>) {
        chomp $line;
        my @c = split /!/, $line, -1;
        if (@c < U_MIN_CAMPOS || $c[U_CORREO_INDEX] ne $args{correo}) {
            print $out "$line\n"; next;
        }
        $found = 1; $id_negocio = $c[U_BIZ_ID_INDEX]; $id_user = $c[0];
        my $sha = Digest::SHA->new(256); $sha->add($args{clave_actual});
        if ($c[U_CLAVE_INDEX] ne $sha->hexdigest) {
            close $in; close $out; unlink $temp; return (0, "Contraseña incorrecta.");
        }
        $c[U_NOMBRE_INDEX] = $args{nombre};
        if ($args{clave_nueva}) {
            my $sha_n = Digest::SHA->new(256); $sha_n->add($args{clave_nueva});
            $c[U_CLAVE_INDEX] = $sha_n->hexdigest;
        }
        print $out join('!', @c) . "\n";
    }
    close $in; close $out;
    if ($found) { rename $temp, $archivo; return (1, "Perfil Diamond Sincronizado.", $id_negocio, $id_user); }
    unlink $temp; return (0, "No encontrado.");
}

sub actualizar_negocio {
    my %args = @_;
    my ($archivo, $temp) = ("../dat/negocios.dat", "../dat/negocios.tmp");
    open(my $in, '<:encoding(UTF-8)', $archivo) or return;
    open(my $out, '>:encoding(UTF-8)', $temp) or return;
    while (my $line = <$in>) {
        chomp $line;
        my @c = split /\|/, $line, -1;
        if ($c[0] ne $args{id_negocio}) { print $out "$line\n"; next; }
        $c[B_NOMBRE_INDEX] = $args{nombre}; $c[B_RFC_INDEX] = $args{rfc};
        $c[B_RAZON_INDEX] = $args{razon}; $c[B_TEL_INDEX] = $args{tel};
        $c[B_EMAIL_INDEX] = $args{email}; $c[B_DIR_INDEX] = $args{dir};
        $c[B_CP_INDEX] = $args{cp} // ''; $c[B_ENTIDAD_INDEX] = $args{entidad} // '';
        $c[B_MUNICIPIO_INDEX] = $args{municipio} // ''; $c[B_COLONIA_INDEX] = $args{colonia} // '';
        $c[B_CLUES_INDEX] = $args{clues} // '';
        $c[B_EXT_INDEX]   = $args{extension} // '0';
        $c[B_LAT_INDEX]   = $args{latitud} // '';
        $c[B_LNG_INDEX]   = $args{longitud} // '';
        print $out join('|', @c) . "\n";
        
        # Guardar en log de depuracion
        if(open(my $log_fh, '>>', '../logs/debug_email.log')) {
            print $log_fh "Actualizando Negocio $args{id_negocio}: email=$args{email} (Raw: $args{debug_email})\n";
            close($log_fh);
        }
    }
    close $in; close $out; rename $temp, $archivo;
}

sub actualizar_paciente {
    my ($correo, $d) = @_;
    my ($archivo, $temp) = ("../dat/pacientes.dat", "../dat/pacientes.tmp");
    open(my $in, '<:encoding(UTF-8)', $archivo) or return;
    open(my $out, '>:encoding(UTF-8)', $temp) or return;
    while (my $line = <$in>) {
        chomp $line;
        my @c = split /\|/, $line, -1;
        if ($c[P_CORREO_INDEX] ne $correo) { print $out "$line\n"; next; }
        $c[P_NOMBRE_INDEX] = $d->{nombre}; $c[P_RFC_INDEX] = $d->{rfc};
        $c[P_CURP_INDEX]   = $d->{curp};   $c[P_FNAC_INDEX] = $d->{fnac};
        $c[P_SEXO_INDEX]   = $d->{sexo};   $c[P_SANGRE_INDEX] = $d->{sangre};
        $c[P_ECIV_INDEX]   = $d->{ecivil}; $c[P_OCUP_INDEX] = $d->{ocup};
        $c[P_NAC_INDEX]    = $d->{nac};    $c[P_TEL_INDEX] = $d->{tel};
        print $out join('|', @c) . "\n";
    }
    close $in; close $out; rename $temp, $archivo;
}

sub actualizar_perfil_extendido {
    my %args = @_;
    my ($archivo, $temp) = ("../dat/perfiles.dat", "../dat/perfiles.tmp");
    my $found = 0;
    my $max_id = 0;
    
    if (open(my $in, '<:encoding(UTF-8)', $archivo)) {
        open(my $out, '>:encoding(UTF-8)', $temp) or return;
        my $header = <$in>;
        print $out $header if $header;
        
        while (my $line = <$in>) {
            chomp $line;
            my @c = split /!/, $line, -1;
            
            # Tracking max ID for auto-increment
            $max_id = $c[0] if $c[0] =~ /^\d+$/ && $c[0] > $max_id;
            
            if ($c[1] eq $args{id_usuario}) {
                $found = 1;
                $c[2] = $args{clave_formacion};
                $c[3] = $args{clave_nacionalidad};
                $c[4] = $args{clave_religion};
                print $out join('!', @c) . "\n";
            } else {
                print $out "$line\n";
            }
        }
        
        if (!$found) {
            # Insert new record
            my $new_id = $max_id + 1;
            print $out "$new_id!$args{id_usuario}!$args{clave_formacion}!$args{clave_nacionalidad}!$args{clave_religion}\n";
        }
        
        close $in; close $out; rename $temp, $archivo;
    }
}

1;