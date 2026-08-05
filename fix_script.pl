my $f = 'views/render_consultas_privado.pl';
open my $fh, '<:encoding(UTF-8)', $f or die;
my @lines = <$fh>;
close $fh;
for (@lines) {
    s/const fmt = \(num\) => '\\\\\$'/const fmt = (num) => '\\\$'/g;
}
open $fh, '>:encoding(UTF-8)', $f or die;
print $fh @lines;
close $fh;
