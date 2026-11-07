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

if (!$sd->{session_ok} || $sd->{role} !~ /Administrador Global/i) {
    print to_json({ status => 'error', message => 'No autorizado' });
    exit;
}

my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'backup_cron_config.dat');
my %config = ( enabled => 0, time => '04:00', days => '1,2,3,4,5,6,0' );

if (-f $config_file) {
    if (open(my $fh, '<:encoding(UTF-8)', $config_file)) {
        while(<$fh>) {
            chomp;
            if (/^ENABLED\|(\d+)$/) { $config{enabled} = int($1); }
            if (/^TIME\|(.+)$/)    { $config{time} = $1; }
            if (/^DAYS\|(.+)$/)    { $config{days} = $1; }
        }
        close($fh);
    }
}

my @times_arr = split(',', $config{time});
@times_arr = grep { /^\d{1,2}:\d{2}$/ } @times_arr;
$config{times} = \@times_arr;

print to_json({ status => 'success', config => \%config });
