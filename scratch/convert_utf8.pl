use strict;
use warnings;
use Encode qw(encode decode);

sub convert_to_utf8 {
    my $file = shift;
    return unless -f $file;
    open(my $in, '<', $file) or return;
    my $raw = do { local $/; <$in> };
    close($in);
    
    # Check if it's already valid UTF-8
    eval { decode('UTF-8', $raw, Encode::FB_CROAK) };
    if ($@) {
        # Not valid UTF-8, assume CP1252/Latin1
        my $decoded = decode('cp1252', $raw);
        open(my $out, '>', $file) or return;
        print $out encode('UTF-8', $decoded);
        close($out);
    }
}

convert_to_utf8("c:/xampp/htdocs/ospulso/dat/categorias.dat");
convert_to_utf8("c:/xampp/htdocs/ospulso/dat/sub_categoria.dat");
convert_to_utf8("c:/xampp/htdocs/ospulso/dat/sub_categoria_nivel3.dat");
convert_to_utf8("c:/xampp/htdocs/ospulso/dat/gastos.dat");
