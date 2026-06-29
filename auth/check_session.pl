#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use lib '..';
eval {
    require utils::db_manager;
    utils::db_manager->import(qw(verificar_estado_negocio));
};

use FindBin;
use File::Spec;

sub check_session {
    my ($external_q) = @_;
    my $q = $external_q || CGI->new;
    my $session;
    my $session_ok = 0;
    my %user_data;

    # Localizar siempre la carpeta /auth/sessions/ de forma absoluta (Protocolo 11.1)
    my $session_dir = File::Spec->catdir($FindBin::Bin, '..', 'auth', 'sessions');
    
    # Fallback si no existe (algunos scripts están en /auth/ mismo)
    if (!-d $session_dir) {
        $session_dir = File::Spec->catdir($FindBin::Bin, 'sessions');
    }

    eval {
        $session = CGI->new->{session} || CGI::Session->load(undef, $q, { Directory => $session_dir });
    };

    if (defined $session && !$session->is_expired && !$session->is_empty) {
        my $uid  = $session->param('uid')      || '';
        my $unm  = $session->param('usuario')  || '';
        my $rol  = $session->param('role')     || 'Invitado';
        my $idm  = $session->param('id_medico') || '';

        if ($uid && $unm) {
            $session_ok = 1;

            # --- BLINDAJE DIAMANTE: Verificar Suscripción en Tiempo Real ---
            if ($rol ne 'Administrador Global') {
                my $id_negocio = $session->param('id_empresa') || $idm || 0;
                if ($id_negocio) {
                    my $biz = verificar_estado_negocio($id_negocio);
                    if (!$biz->{activo}) {
                        $session_ok = 0; # Invalidar acceso si el negocio no está activo
                    }
                }
            }

            %user_data = ( uid => $uid, correo_login => $uid, usuario => $unm, role => $rol, id_medico => $idm, session => $session, q => $q );
        }
    }

    return { q => $q, session_ok => $session_ok, (%user_data) };
}
1;
