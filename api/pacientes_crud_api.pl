#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use Digest::SHA qw(sha256_hex);
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
    my $id_medico_form = $input->{id_medico} // '';
    
    # 0. Lógica de Doble Propiedad (RBAC): Si quien crea es Recepcionista/Admin, y asignó a un Médico, ambos son dueños
    if (($session_data->{role} eq 'Recepcionista' || $session_data->{role} eq 'Administrador') && $id_medico_form ne '') {
        # Validar si el id_medico (usuario) es distinto al seleccionado
        if ($id_medico ne $id_medico_form) {
            $id_medico_form = "$id_medico,$id_medico_form";
        }
    } else {
        $id_medico_form = $id_medico if $id_medico_form eq '';
    }
    
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

    my $extra_tenant = ($session_data->{id_empresa} // '0') . ":" . ($session_data->{id_sucursal} // '0');

    my $nueva_linea = join("|",
        $id_paciente,
        $id_medico_form,
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
        $input->{telefono} // '',
        $extra_tenant
    );

    guardar_registro('../dat/pacientes.dat', $nueva_linea);
    guardar_antecedentes_paciente($id_paciente, $input->{tutor}, $input->{antecedentes});
    my $dom_data = $input->{domicilio} || ($input->{antecedentes} ? $input->{antecedentes}->{domicilio} : undef) || {};
    guardar_domicilio_paciente($id_paciente, $dom_data);

    # ==== REGISTRO DE USUARIO (PORTAL PACIENTE) ====
    if ($input->{correo} && $input->{correo} =~ /\@/) {
        my $correo_pac = lc($input->{correo});
        $correo_pac =~ s/^\s+|\s+$//g;
        
        my $usuarios = leer_tabla('../dat/usuarios.dat', '!');
        my $existe_usuario = 0;
        foreach my $u (@$usuarios) {
            if (lc($u->[2] // '') eq $correo_pac) {
                $existe_usuario = 1;
                last;
            }
        }
        
        if (!$existe_usuario) {
            # Contraseña por defecto: Ospulso2026!
            my $clave_hash = sha256_hex('Ospulso2026!');
            # Tenant global consolidado (0:0) para pacientes
            my $user_line = join('!', $id_paciente, $nombre, $correo_pac, $clave_hash, '1', 'Paciente', '0:0', '0', '0', '0', '', '');
            guardar_registro('../dat/usuarios.dat', $user_line);
            
            # Enviar el correo usando MIME::Lite si está disponible
            my $status_correo = 'Pendiente';
            my $has_mime_lite = eval "use MIME::Lite; 1;";
            if ($has_mime_lite) {
                my $cuerpo_html = qq{
<html>
  <body style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; line-height: 1.6; color: #1e293b; background-color: #f8fafc; margin: 0; padding: 20px;">
    <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05); border: 1px solid #e2e8f0;">
      <!-- Header -->
      <div style="background-color: #0A2A66; padding: 25px; text-align: center;">
        <h1 style="color: #ffffff; margin: 0; font-size: 24px; letter-spacing: 1px;">OSPULSO</h1>
      </div>
      
      <!-- Body -->
      <div style="padding: 30px;">
        <h2 style="color: #0A2A66; margin-top: 0; font-size: 20px;">Bienvenido(a) a su nuevo Portal Médico</h2>
        <p style="font-size: 15px;">Estimado(a) <strong>$nombre</strong>,</p>
        <p style="font-size: 15px;">Le damos la más cordial bienvenida a OsPulso.</p>
        <p style="font-size: 15px;">Hemos generado su Expediente Clínico Electrónico para garantizarle una atención médica continua, segura y de vanguardia.</p>
        <p style="font-size: 15px;">A través de nuestro portal seguro, usted podrá consultar:</p>
        <ul style="font-size: 15px; color: #334155; padding-left: 20px;">
            <li style="margin-bottom: 8px;">Próximas citas y recordatorios</li>
            <li style="margin-bottom: 8px;">Recetas e indicaciones médicas</li>
            <li style="margin-bottom: 8px;">Estados de cuenta y recibos</li>
        </ul>
        
        <div style="margin: 30px 0; padding: 20px; background-color: #f1f5f9; border-radius: 8px; border-left: 4px solid #19B7A5;">
            <p style="margin: 0 0 10px 0; font-size: 14px;"><strong>Sus credenciales de acceso:</strong></p>
            <p style="margin: 0 0 5px 0; font-size: 14px;">Usuario: <strong>$correo_pac</strong></p>
            <p style="margin: 0 0 15px 0; font-size: 14px;">Contraseña Temporal: <strong>Ospulso2026!</strong></p>
            <p style="margin: 0; font-size: 13px; color: #64748b;"><em>* Le recomendamos cambiar su contraseña al ingresar por primera vez.</em></p>
        </div>
        
        <div style="text-align: center; margin: 35px 0;">
            <a href="https://ospulso.pdigitalesm.com/" style="background-color: #19B7A5; color: #ffffff; text-decoration: none; padding: 14px 28px; border-radius: 6px; font-weight: bold; display: inline-block; font-size: 15px; text-transform: uppercase; letter-spacing: 0.5px;">Ingresar a mi Portal Médico</a>
        </div>
        
        <p style="font-size: 14px; color: #64748b;">Si usted no solicitó este registro, por favor descarte este mensaje.</p>
        <br>
        <p style="font-size: 15px; margin-bottom: 0;">Atentamente,</p>
        <p style="font-size: 15px; font-weight: bold; color: #0A2A66; margin-top: 5px;">El equipo de OsPulso</p>
      </div>
      
      <!-- Footer -->
      <div style="background-color: #f8fafc; padding: 20px 30px; border-top: 1px solid #e2e8f0; text-align: center;">
        <p style="font-size: 11px; color: #64748b; margin: 0 0 10px 0; line-height: 1.5;"><strong>Aviso de Privacidad:</strong> La información contenida en este correo electrónico es estrictamente confidencial. Sus datos son tratados bajo rigurosos estándares de seguridad de acuerdo con la LFPDPPP.</p>
        <p style="font-size: 11px; color: #94a3b8; margin: 0;">Por favor, no responda a este correo automático.</p>
      </div>
    </div>
  </body>
</html>
                };
                
                eval {
                    my $msg = MIME::Lite->new(
                        From    => 'administracion@ospulso.pdigitalesm.com',
                        To      => $correo_pac,
                        Subject => 'Bienvenido al Portal del Paciente',
                        Type    => 'text/html; charset=UTF-8',
                        Data    => $cuerpo_html,
                        Encoding=> 'quoted-printable'
                    );
                    $msg->send;
                    $status_correo = 'Enviado';
                };
                if ($@) {
                    $status_correo = 'Fallido';
                }
            }

            # Registrar en historial de correos
            my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
            my $fecha = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
            my $mail_line = join('|', int(rand(999999)), $id_paciente, 'Invitación Portal Paciente', $correo_pac, $status_correo, $fecha);
            guardar_registro('../dat/historial_correos.dat', $mail_line);
        }
    }
    # ===============================================

    print "Content-Type: application/json; charset=UTF-8\n\n";
    print JSON::PP->new->utf8(0)->encode({ok => 1, msg => "La Ficha Clínica de $nombre ha sido generada correctamente."});
    exit;
} elsif ($input->{accion} eq 'actualizar') {
    my $id_target = $input->{id};
    my $nombre = $input->{nombre} // '';
    my $rfc = $input->{rfc} // '';
    my $curp = $input->{curp} // '';
    my $id_medico_upd = $input->{id_medico} // '';

    my $registros = leer_tabla('../dat/pacientes.dat', '\|');
    my @nuevos_registros;
    my $encontrado = 0;
    
    # Validar permisos de acceso antes de permitir la actualización
    my $acceso_permitido = 0;
    foreach my $r (@$registros) {
        if ($r->[0] eq $id_target) {
            my $tenant_pac = $r->[13] // '';
            my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
            my $mi_org = $session_data->{id_empresa} || 'X';
            my $mi_sucursal = $session_data->{id_sucursal} // 0;
            my $role = $session_data->{role};
            
            if ($role eq 'Administrador Global') {
                $acceso_permitido = 1;
            } elsif ($role =~ /Administrador Organizacion|Soporte/i) {
                if ($org_pac && $org_pac eq $mi_org) {
                    $acceso_permitido = 1;
                } elsif (!$org_pac) {
                    $acceso_permitido = 1;
                }
            } elsif ($role =~ /Medico|Recepcionista/i) {
                if ($org_pac && $org_pac eq $mi_org) {
                    if (($suc_pac eq $mi_sucursal || !$suc_pac || !$mi_sucursal) && $r->[1] =~ /\b\Q$id_medico\E\b/) {
                        $acceso_permitido = 1;
                    }
                } elsif (!$org_pac && $r->[1] =~ /\b\Q$id_medico\E\b/) {
                    $acceso_permitido = 1;
                }
            }
            last;
        }
    }
    
    unless ($acceso_permitido) {
        print "Content-Type: application/json; charset=UTF-8\n\n";
        print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Acceso denegado: No tiene permisos sobre este expediente."});
        exit;
    }

    foreach my $r (@$registros) {
        if (@$r > 1 && $r->[0] eq $id_target) {
            $encontrado = 1;
            my $final_owner = $r->[1];
            if ($id_medico_upd ne '') {
                $final_owner = "$final_owner,$id_medico_upd" if $final_owner !~ /\b\Q$id_medico_upd\E\b/;
            }
            
            push @nuevos_registros, join("|",
                $id_target,
                $final_owner, # id_medico (múltiples dueños separados por coma)
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
                $input->{telefono} // '',
                $r->[13] // (($session_data->{id_empresa} // '0') . ":" . ($session_data->{id_sucursal} // '0'))
            );
        } else {
            push @nuevos_registros, join("|", @$r);
        }
    }

    if ($encontrado) {
        actualizar_archivo('../dat/pacientes.dat', "ID_PACIENTE|ID_MEDICO|NOMBRE|RFC|CURP|CORREO|FECHA_NAC|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO|TENANT", \@nuevos_registros);
        guardar_antecedentes_paciente($id_target, $input->{tutor}, $input->{antecedentes});
        my $dom_data = $input->{domicilio} || ($input->{antecedentes} ? $input->{antecedentes}->{domicilio} : undef) || {};
        guardar_domicilio_paciente($id_target, $dom_data);
        print "Content-Type: application/json; charset=UTF-8\n\n";
        print JSON::PP->new->utf8(0)->encode({ok => 1, msg => "El Expediente Clínico ha sido actualizado."});
        exit;
    } else {
        print "Content-Type: application/json; charset=UTF-8\n\n";
        print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Inconsistencia: Expediente no localizado."});
        exit;
    }
}

sub guardar_antecedentes_paciente {
    my ($id_paciente, $tutor, $antecedentes_obj) = @_;
    my $file = '../dat/pacientes_antecedentes.dat';
    my $json_str = eval { JSON::PP->new->encode($antecedentes_obj || {}) } || '{}';
    $json_str =~ s/\r?\n//g;
    
    my $tutor_clean = $tutor // '';
    $tutor_clean =~ s/\|/ /g;
    
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $fecha_actual = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    
    my @lines;
    my $found = 0;
    if (-e $file && open(my $fh, '<:encoding(UTF-8)', $file)) {
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @v = split /\|/, $line, -1;
            if ($v[0] eq $id_paciente) {
                $found = 1;
                push @lines, "$id_paciente|$tutor_clean|$json_str|$fecha_actual";
            } else {
                push @lines, $line;
            }
        }
        close $fh;
    }
    unless ($found) {
        push @lines, "$id_paciente|$tutor_clean|$json_str|$fecha_actual";
    }
    
    if (open(my $out, '>:encoding(UTF-8)', $file)) {
        foreach my $l (@lines) {
            print $out "$l\n";
        }
        close $out;
    }
}

sub guardar_domicilio_paciente {
    my ($id_paciente, $dom_obj) = @_;
    return unless $id_paciente;
    my $file = '../dat/pacientes_domicilio.dat';
    
    my $cp = $dom_obj->{cp} // '';
    my $ent = $dom_obj->{entidad} // '';
    my $mun = $dom_obj->{municipio} // '';
    my $col = $dom_obj->{colonia} // '';
    my $calle = $dom_obj->{calle} // '';
    my $num_ext = $dom_obj->{num_ext} // '';
    my $num_int = $dom_obj->{num_int} // '';
    
    for ($cp, $ent, $mun, $col, $calle, $num_ext, $num_int) { s/\|/ /g; s/\r?\n/ /g; }
    
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    my $fecha_actual = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    
    my $nueva_linea = "$id_paciente|$cp|$ent|$mun|$col|$calle|$num_ext|$num_int|$fecha_actual";
    
    my @lines;
    my $found = 0;
    if (-e $file && open(my $fh, '<:encoding(UTF-8)', $file)) {
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/ || $line =~ /^ID_PACIENTE/i;
            my @v = split /\|/, $line, -1;
            if ($v[0] eq $id_paciente) {
                $found = 1;
                push @lines, $nueva_linea;
            } else {
                push @lines, $line;
            }
        }
        close $fh;
    }
    unless ($found) {
        push @lines, $nueva_linea;
    }
    
    if (open(my $out, '>:encoding(UTF-8)', $file)) {
        print $out "ID_PACIENTE|CP|ENTIDAD|MUNICIPIO|COLONIA|CALLE|NUM_EXT|NUM_INT|FECHA_ACTUALIZACION\n";
        foreach my $l (@lines) {
            print $out "$l\n";
        }
        close $out;
    }
}

print "Content-Type: application/json; charset=UTF-8\n\n";
print JSON::PP->new->utf8(0)->encode({ok => 0, msg => "Comando sin reconocimiento en el servidor Central."});
exit;

