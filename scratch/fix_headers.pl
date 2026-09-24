use strict;
use warnings;

sub prepend {
    my ($f, $h) = @_;
    open(my $in, "<:encoding(UTF-8)", $f) or return;
    my @lines = <$in>;
    close $in;
    
    # Prevenir duplicar cabeceras si ya existen
    if (@lines > 0 && $lines[0] =~ /^id\|/) {
        return;
    }
    
    open(my $out, ">:encoding(UTF-8)", $f);
    print $out "$h\n";
    print $out @lines;
    close $out;
}

prepend("c:/xampp/htdocs/ospulso/dat/categorias.dat", "id|nombre|desc");
prepend("c:/xampp/htdocs/ospulso/dat/sub_categoria.dat", "id|id_cat|nombre|desc");
prepend("c:/xampp/htdocs/ospulso/dat/sub_categoria_nivel3.dat", "id|id_subcat|nombre");
