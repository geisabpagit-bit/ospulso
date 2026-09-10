#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(strftime);

print "Current before TZ: ", strftime("%Y-%m-%d %H:%M:%S", localtime), "\n";

BEGIN {
    $ENV{TZ} = 'America/Mexico_City';
}

print "Current after TZ: ", strftime("%Y-%m-%d %H:%M:%S", localtime), "\n";
