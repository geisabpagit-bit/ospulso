#!/usr/bin/perl
package auth;
sub check_session { return { session_ok => 1, usuario => 'admin', role => 'Medico', id_medico => 'DOC-001' }; }
$INC{'../auth/check_session.pl'} = 1;
package main;
$ENV{QUERY_STRING} = "id=1";
do './views/render_consultas_privado.pl';
