#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON;

my $q = CGI->new;
print $q->header(-type => 'application/json', -charset => 'UTF-8');

my $query = lc($q->param('q') // '');
my $results = [];

if (length($query) >= 2) {
    if (open(my $fh, '<:encoding(UTF-8)', '../dat/catalogosOF/CAT_CIE10_DIAGNOSTICOS.dat')) {
        my $header = <$fh>;
        while (my $line = <$fh>) {
            chomp $line;
            my ($key, $nombre, $cap) = split /!/, $line, -1;
            next unless $key && $nombre;
            if (index(lc($key), $query) != -1 || index(lc($nombre), $query) != -1) {
                push @$results, { id => $key, text => "$key - $nombre", capitulo => $cap // '' };
                last if @$results >= 30; # limit to 30 results
            }
        }
        close($fh);
    }
}

print encode_json($results);
1;
