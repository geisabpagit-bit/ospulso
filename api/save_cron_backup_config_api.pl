#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;
use FindBin;
use File::Spec;
use open qw(:std :utf8);

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $sd = check_session();
my $q  = $sd->{q};

print $q->header(-type => 'application/json', -charset => 'UTF-8');

if (!$sd->{session_ok} || $sd->{role} ne 'Administrador Global') {
    print to_json({ status => 'error', message => 'No autorizado' });
    exit;
}

my $enabled = $q->param('enabled') || 0;
my $time    = $q->param('time') || '';
my $days    = $q->param('days') || '';

my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'backup_cron_config.dat');

if (open(my $fh, '>:encoding(UTF-8)', $config_file)) {
    print $fh "ENABLED|$enabled\n";
    print $fh "TIME|$time\n";
    print $fh "DAYS|$days\n";
    close($fh);
    print to_json({ status => 'success' });
} else {
    print to_json({ status => 'error', message => "No se pudo guardar la configuración: $!" });
}
