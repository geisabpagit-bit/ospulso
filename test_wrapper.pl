#!/usr/bin/perl
BEGIN {
    package auth;
    sub check_session { return { session_ok => 1, usuario => 'admin', role => 'Medico', id_medico => 'DOC-001' }; }
    $INC{'../auth/check_session.pl'} = 1;
}
$ENV{QUERY_STRING} = "id=3&id_cita=1785898474";
do './views/render_consultas_privado.pl';
