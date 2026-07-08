package cPanelUserConfig;
package main;
use lib "c:/xampp/htdocs/ospulso";
use CGI;
$INC{"../auth/check_session.pl"} = 1;
sub check_session {
    return { session_ok => 1, q => CGI->new, usuario => "Test", role => "Medico", id_medico => 1 };
}
do "c:/xampp/htdocs/ospulso/views/pacientes.pl";
