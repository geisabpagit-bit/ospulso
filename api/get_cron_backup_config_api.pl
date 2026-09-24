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

my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'backup_cron_config.dat');
my %config = ( enabled => 0, time => '03:00', days => '' );

if (-f $config_file) {
    open(my $fh, '<:encoding(UTF-8)', $config_file);
    while(<$fh>) {
        chomp;
        if (/^ENABLED\|(\d+)$/) { $config{enabled} = $1; }
        if (/^TIME\|(.+)$/) { $config{time} = $1; }
        if (/^DAYS\|(.+)$/) { $config{days} = $1; }
    }
    close($fh);
}

print to_json({ status => 'success', config => \%config });
