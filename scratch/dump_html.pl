#!/usr/bin/perl
package cPanelUserConfig;
use strict;
use warnings;
use CGI;
use lib "c:/xampp/htdocs/ospulso";

# Mock check_session
BEGIN {
    $INC{'../auth/check_session.pl'} = 1;
    *check_session = sub {
        return {
            session_ok => 1,
            q => CGI->new,
            usuario => 'TestUser',
            role => 'Administrador',
            id_medico => 1,
        };
    };
}

# Redirect STDOUT
open my $fh, '>', 'c:/xampp/htdocs/ospulso/scratch/pacientes_html.html' or die "Cannot open: $!";
select $fh;

do "c:/xampp/htdocs/ospulso/views/pacientes.pl";
close $fh;
