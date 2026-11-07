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

my $enabled = $q->param('enabled') ? 1 : 0;
my $days    = $q->param('days') // '';

# Soporte flexible para horarios: parámetro "time" separado por comas o time1, time2, time3
my @raw_times;
if (my $time_param = $q->param('time')) {
    push @raw_times, split(',', $time_param);
}
for my $idx (1..3) {
    if (my $t = $q->param("time$idx")) {
        push @raw_times, $t;
    }
}

my %seen_times;
my @clean_times;
foreach my $t (@raw_times) {
    $t =~ s/^\s+|\s+$//g;
    if ($t =~ /^([01]\d|2[0-3]):([0-5]\d)$/) {
        my $formatted = sprintf("%02d:%02d", $1, $2);
        if (!$seen_times{$formatted}) {
            $seen_times{$formatted} = 1;
            push @clean_times, $formatted;
        }
    }
}

# Ordenar cronológicamente y limitar a 3 horarios
@clean_times = sort @clean_times;
if (@clean_times > 3) {
    @clean_times = @clean_times[0..2];
}

if ($enabled) {
    if (!@clean_times) {
        print to_json({ status => 'error', message => 'Debes configurar al menos un horario de respaldo válido (ej. 04:00).' });
        exit;
    }
    if ($days eq '') {
        print to_json({ status => 'error', message => 'Debes seleccionar al menos un día de la semana.' });
        exit;
    }
}

my $joined_times = join(',', @clean_times);
my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'backup_cron_config.dat');

if (open(my $fh, '>:encoding(UTF-8)', $config_file)) {
    print $fh "ENABLED|$enabled\n";
    print $fh "TIME|$joined_times\n";
    print $fh "DAYS|$days\n";
    close($fh);
    print to_json({ 
        status  => 'success',
        message => 'Programación de respaldos guardada correctamente.',
        config  => {
            enabled => $enabled,
            time    => $joined_times,
            times   => \@clean_times,
            days    => $days
        }
    });
} else {
    print to_json({ status => 'error', message => "No se pudo guardar la configuración: $!" });
}
