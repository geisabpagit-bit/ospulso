package utils::permisos_utils;

use strict;
use warnings;
use utf8;
use File::Spec;
use FindBin;
use Exporter 'import';

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

our @EXPORT_OK = qw(
    obtener_ruta_permisos_org
    obtener_matriz_permisos_org
    guardar_matriz_permisos_org
    obtener_ruta_permisos_usuario_org
    obtener_overrides_usuario_org
    guardar_overrides_usuario_org
    eliminar_overrides_usuario_org
    tiene_permiso_modulo
);

sub _resolver_dat_dir {
    return File::Spec->catdir($FindBin::Bin, '..', 'dat');
}

# ─────────────────────────────────────────────────────────────
# obtener_ruta_permisos_org($id_empresa)
# Resuelve la ruta del archivo de permisos roles según sea
# Organización CLUE o Organización Privada No-CLUE.
# ─────────────────────────────────────────────────────────────
sub obtener_ruta_permisos_org {
    my ($id_empresa) = @_;
    $id_empresa //= 0;

    my $dat = _resolver_dat_dir();
    my $id_raiz = catalogo_org_utils::resolver_id_raiz_catalogo($id_empresa);

    my $clues = '';
    if (defined $id_raiz && ($id_raiz eq '0' || $id_raiz eq '')) {
        $clues = 'QTSMP000116';
    } elsif (defined $id_raiz && -d File::Spec->catdir($dat, 'catalogos_CLUE', $id_raiz)) {
        $clues = $id_raiz;
    } else {
        my $neg_file = File::Spec->catfile($dat, 'negocios.dat');
        if (-e $neg_file && open(my $nf, '<:utf8', $neg_file)) {
            <$nf>;
            while (my $line = <$nf>) {
                chomp $line;
                my @f = split(/\|/, $line, -1);
                if (defined $f[0] && defined $id_raiz && $f[0] eq $id_raiz) {
                    $clues = $f[18] // '';
                    last;
                }
            }
            close $nf;
        }
    }

    if ($clues) {
        my $clue_dir = File::Spec->catdir($dat, 'catalogos_CLUE', $clues);
        return File::Spec->catfile($clue_dir, "permisos_roles_${clues}.dat");
    }

    return File::Spec->catfile($dat, "permisos_roles_${id_raiz}.dat");
}

# ─────────────────────────────────────────────────────────────
# obtener_ruta_permisos_usuario_org($id_empresa)
# Resuelve la ruta del archivo de excepciones/overrides por usuario.
# ─────────────────────────────────────────────────────────────
sub obtener_ruta_permisos_usuario_org {
    my ($id_empresa) = @_;
    my $ruta_roles = obtener_ruta_permisos_org($id_empresa);
    $ruta_roles =~ s/permisos_roles_/permisos_usuarios_/g;
    return $ruta_roles;
}

# ─────────────────────────────────────────────────────────────
# obtener_overrides_usuario_org($id_empresa, [$id_usuario])
# Si se provee $id_usuario, devuelve { MODULO => { C=>1, R=>1, U=>1, D=>1 } } o undef.
# Si no se provee, devuelve { ID_USUARIO => { MODULO => { C=>1... } } }.
# ─────────────────────────────────────────────────────────────
sub obtener_overrides_usuario_org {
    my ($id_empresa, $id_usuario) = @_;
    my $ruta_usr_perm = obtener_ruta_permisos_usuario_org($id_empresa);
    my %todos_overrides = ();

    if (-e $ruta_usr_perm && open(my $fh, '<:encoding(UTF-8)', $ruta_usr_perm)) {
        <$fh>; # Saltar cabecera ID_USUARIO|MODULO|CAN_CREATE|CAN_READ|CAN_UPDATE|CAN_DELETE
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            my ($uid, $mod, $c, $r, $u, $d) = split(/\|/, $line, -1);
            next unless ($uid && $mod);
            $todos_overrides{$uid}{$mod} = {
                C => int($c // 0),
                R => int($r // 0),
                U => int($u // 0),
                D => int($d // 0),
            };
        }
        close $fh;
    }

    if (defined $id_usuario && length($id_usuario)) {
        return exists $todos_overrides{$id_usuario} ? $todos_overrides{$id_usuario} : undef;
    }

    return \%todos_overrides;
}

# ─────────────────────────────────────────────────────────────
# guardar_overrides_usuario_org($id_empresa, $id_usuario, $overrides_hashref)
# Persiste o actualiza las excepciones individuales de un usuario.
# ─────────────────────────────────────────────────────────────
sub guardar_overrides_usuario_org {
    my ($id_empresa, $id_usuario, $overrides_ref) = @_;
    return { ok => 0, msg => 'ID Usuario requerido' } unless (defined $id_usuario && length($id_usuario));

    my $todos = obtener_overrides_usuario_org($id_empresa);
    
    if (defined $overrides_ref && ref($overrides_ref) eq 'HASH' && keys %$overrides_ref) {
        $todos->{$id_usuario} = $overrides_ref;
    } else {
        delete $todos->{$id_usuario};
    }

    my $ruta_usr_perm = obtener_ruta_permisos_usuario_org($id_empresa);
    my ($vol, $dirs, $file) = File::Spec->splitpath($ruta_usr_perm);
    my $parent_dir = File::Spec->catpath($vol, $dirs, '');
    if ($parent_dir && !-d $parent_dir) {
        mkdir $parent_dir;
    }

    if (open(my $fh, '>:encoding(UTF-8)', $ruta_usr_perm)) {
        flock($fh, 2); # LOCK_EX
        print $fh "ID_USUARIO|MODULO|CAN_CREATE|CAN_READ|CAN_UPDATE|CAN_DELETE\n";
        foreach my $uid (sort keys %$todos) {
            foreach my $mod (sort keys %{$todos->{$uid}}) {
                my $perm = $todos->{$uid}{$mod};
                my $c = int($perm->{C} // 0);
                my $r = int($perm->{R} // 0);
                my $u = int($perm->{U} // 0);
                my $d = int($perm->{D} // 0);
                print $fh "$uid|$mod|$c|$r|$u|$d\n";
            }
        }
        close $fh;
        return { ok => 1, msg => 'Excepciones de usuario guardadas exitosamente' };
    } else {
        return { ok => 0, msg => "Error al escribir archivo: $!" };
    }
}

# ─────────────────────────────────────────────────────────────
# eliminar_overrides_usuario_org($id_empresa, $id_usuario)
# Elimina totalmente las excepciones de un usuario (al cambiar de rol o reseteo).
# ─────────────────────────────────────────────────────────────
sub eliminar_overrides_usuario_org {
    my ($id_empresa, $id_usuario) = @_;
    return guardar_overrides_usuario_org($id_empresa, $id_usuario, undef);
}

# ─────────────────────────────────────────────────────────────
# obtener_matriz_permisos_org($id_empresa)
# Devuelve la matriz de permisos { ROL => { MODULO => { C=>1, R=>1, U=>1, D=>1 } } }
# Si no existe archivo personalizado, aplica Fallback desde dat/roles.dat.
# ─────────────────────────────────────────────────────────────
sub obtener_matriz_permisos_org {
    my ($id_empresa) = @_;
    my $ruta_permisos = obtener_ruta_permisos_org($id_empresa);
    my %matriz = ();

    if (-e $ruta_permisos && open(my $fh, '<:encoding(UTF-8)', $ruta_permisos)) {
        <$fh>; # Saltar cabecera ROL|MODULO|CAN_CREATE|CAN_READ|CAN_UPDATE|CAN_DELETE
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            my ($rol, $mod, $c, $r, $u, $d) = split(/\|/, $line, -1);
            next unless ($rol && $mod);
            $matriz{$rol}{$mod} = {
                C => int($c // 0),
                R => int($r // 0),
                U => int($u // 0),
                D => int($d // 0),
            };
        }
        close $fh;
        return \%matriz if keys %matriz;
    }

    # FALLBACK AUTOMÁTICO: Cargar configuración base de dat/roles.dat y menu_cards.dat
    my $dat = _resolver_dat_dir();
    my $roles_file = File::Spec->catfile($dat, 'roles.dat');
    if (-e $roles_file && open(my $rf, '<:encoding(UTF-8)', $roles_file)) {
        while (my $line = <$rf>) {
            chomp $line;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            my @f = split(/\|/, $line, -1);
            my $rol_name = $f[0];
            my @modulos_permitidos = @f[2..$#f];

            foreach my $m (@modulos_permitidos) {
                $m =~ s/^\s+|\s+$//g;
                next unless length($m);
                # En fallback base, si un módulo está asignado al rol, tiene permisos completos
                $matriz{$rol_name}{$m} = { C => 1, R => 1, U => 1, D => 1 };
            }

            # Garantizar acceso Administrador Organizacion y Administrador Global
            if ($rol_name =~ /Administrador/i) {
                foreach my $m_admin ('pacientes', 'agenda', 'quirofano', 'finanzas', 'servicios', 'productos', 'usuarios', 'reportes', 'gestion_catalogos', 'tecnico', 'reset_datos_org') {
                    $matriz{$rol_name}{$m_admin} = { C => 1, R => 1, U => 1, D => 1 };
                }
            }
        }
        close $rf;
    }

    return \%matriz;
}

# ─────────────────────────────────────────────────────────────
# guardar_matriz_permisos_org($id_empresa, $matriz_hashref)
# Persiste la matriz de permisos para la organización (CLUE o No-CLUE)
# aplicando Lockout Protection para el rol Administrador.
# ─────────────────────────────────────────────────────────────
sub guardar_matriz_permisos_org {
    my ($id_empresa, $matriz_ref) = @_;
    return { ok => 0, msg => 'Datos de matriz no válidos' } unless (ref($matriz_ref) eq 'HASH');

    my $ruta_permisos = obtener_ruta_permisos_org($id_empresa);
    my ($vol, $dirs, $file) = File::Spec->splitpath($ruta_permisos);
    my $parent_dir = File::Spec->catpath($vol, $dirs, '');
    if ($parent_dir && !-d $parent_dir) {
        mkdir $parent_dir;
    }

    # LOCKOUT PROTECTION: Garantizar que Administrador Organizacion y Administrador Global conserven CRUD en usuarios y gestion_permisos
    foreach my $adm_role ('Administrador Organizacion', 'Administrador Global') {
        foreach my $critical_mod ('usuarios', 'gestion_permisos', 'pacientes', 'agenda') {
            $matriz_ref->{$adm_role}{$critical_mod} = { C => 1, R => 1, U => 1, D => 1 };
        }
    }

    if (open(my $fh, '>:encoding(UTF-8)', $ruta_permisos)) {
        flock($fh, 2); # LOCK_EX
        print $fh "ROL|MODULO|CAN_CREATE|CAN_READ|CAN_UPDATE|CAN_DELETE\n";
        foreach my $rol (sort keys %$matriz_ref) {
            foreach my $mod (sort keys %{$matriz_ref->{$rol}}) {
                my $perm = $matriz_ref->{$rol}{$mod};
                my $c = int($perm->{C} // 0);
                my $r = int($perm->{R} // 0);
                my $u = int($perm->{U} // 0);
                my $d = int($perm->{D} // 0);
                print $fh "$rol|$mod|$c|$r|$u|$d\n";
            }
        }
        close $fh;
        return { ok => 1, msg => 'Permisos guardados exitosamente' };
    } else {
        return { ok => 0, msg => "Error al escribir archivo: $!" };
    }
}

# ─────────────────────────────────────────────────────────────
# tiene_permiso_modulo($id_empresa, $role, $modulo, $accion, [$id_usuario])
# Evalua si el usuario pose una excepcion directa o en su defecto si su ROL
# posee permiso para la accion ('C','R','U','D') en el modulo.
# ─────────────────────────────────────────────────────────────
sub tiene_permiso_modulo {
    my ($id_empresa, $role, $modulo, $accion, $id_usuario) = @_;
    $role //= '';
    $modulo //= '';
    $accion //= 'R';
    $accion = uc($accion);

    # Administrador Global siempre posee acceso completo
    return 1 if ($role eq 'Administrador Global');

    # Administrador Organizacion en modulos de gestion y usuarios siempre posee acceso completo (Lockout protection)
    if ($role eq 'Administrador Organizacion' && ($modulo eq 'usuarios' || $modulo eq 'gestion_permisos')) {
        return 1;
    }

    # 1. EVALUAR EXCEPCIÓN INDIVIDUAL POR USUARIO (SI EXISTE)
    if (defined $id_usuario && length($id_usuario)) {
        my $user_overrides = obtener_overrides_usuario_org($id_empresa, $id_usuario);
        if ($user_overrides && exists $user_overrides->{$modulo}) {
            return int($user_overrides->{$modulo}{$accion} // 0);
        }
    }

    # 2. FALLBACK A LA MATRIZ DE ROL PREDETERMINADA
    my $matriz = obtener_matriz_permisos_org($id_empresa);
    
    if (exists $matriz->{$role} && exists $matriz->{$role}{$modulo}) {
        return int($matriz->{$role}{$modulo}{$accion} // 0);
    }

    return 0;
}

1;
