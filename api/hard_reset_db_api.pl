#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use JSON;

my $q = CGI->new;
print $q->header(-type => 'application/json', -charset => 'UTF-8', -status => '403 Forbidden');
print encode_json({ status => 'error', message => 'Acceso denegado: Este endpoint ha sido deshabilitado de forma definitiva.' });
exit;
