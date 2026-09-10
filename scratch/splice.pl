#!/usr/bin/perl
use strict;
use warnings;
use File::Slurp;

my $file = "c:/xampp/htdocs/ospulso/views/render_dashboard_principal.pl";
my $content = read_file($file);

my $new_block = read_file("c:/xampp/htdocs/ospulso/scratch/recepcionista_block.txt");

# The block to replace starts with:
#             <!-- Sección: Próximas Citas o Dashboard Recepcionista -->
# HTML
#
#     if ($role eq 'Recepcionista') {
#
# And ends at the FIRST `    } else {` after it.

if ($content =~ s/(<!-- Sección: Próximas Citas o Dashboard Recepcionista -->\s*HTML\s*)if \(\$role eq 'Recepcionista'\) \{.*?(^\s*\} else \{)/$1$new_block$2/ms) {
    write_file($file, $content);
    print "Replaced correctly!\n";
} else {
    print "Failed to match.\n";
}
