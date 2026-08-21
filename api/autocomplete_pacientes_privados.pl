#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI qw(-utf8);
use JSON qw(encode_json);
use File::Spec;
use FindBin;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');

my $q = CGI->new;
my $sd = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($sd->{session_ok}) {
    print encode_json([]);
    exit;
}

my $term = lc($q->param('term') || '');
my $clues = $q->param('clues') || '';
$term =~ s/^\s+|\s+$//g;
$clues =~ s/^\s+|\s+$//g;

if (length($term) < 2 || !$clues) {
    print encode_json([]);
    exit;
}

my $priv_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', "pacientes_privados__${clues}.dat");
my @matches;

if (-e $priv_file && open(my $fh, '<:encoding(UTF-8)', $priv_file)) {
    my $header = <$fh>;
    while (my $line = <$fh>) {
        chomp $line;
        my @fields = split /\|/, $line, -1;
        if (@fields >= 2) {
            my $id = $fields[0];
            my $nombre = $fields[1];
            if (lc($nombre) =~ /\Q$term\E/) {
                push @matches, { id => $id, label => $nombre };
            }
        }
    }
    close $fh;
}

if (@matches > 20) {
    @matches = @matches[0..19];
}

print encode_json(\@matches);
exit;
