
use strict;
use warnings;
use JSON::PP;
use FindBin;
use lib "$FindBin::Bin/../";
use utils::db_manager qw(leer_tabla);

my $clues = "QTSMP000116";
my $num_empleado = "6175";
my $sufijo = $clues ? "_${clues}" : "";
my $archivo_empleados = "c:/xampp/htdocs/ospulso/dat/empleadosmun${sufijo}.dat";
my $empleados = leer_tabla($archivo_empleados, "!");

my @resultados;
foreach my $e (@$empleados) {
    if (defined $e->[0] && $e->[0] eq $num_empleado) {
        push @resultados, {
            id => $e->[0],
            nombre => $e->[1] // "",
            relacion => $e->[2] // ""
        };
    }
}
print JSON::PP->new->utf8(0)->encode({ ok => 1, resultados => \@resultados });

