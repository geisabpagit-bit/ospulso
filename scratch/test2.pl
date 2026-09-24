
use strict;
use warnings;
use CGI;
use FindBin;
use lib "$FindBin::Bin/../";
use utils::db_manager qw(leer_tabla);

my $num_empleado = "6175";
my $clues = "QTSMP000116";
my $sufijo = $clues ? "_${clues}" : "";
my $archivo_empleados = "c:/xampp/htdocs/ospulso/dat/empleadosmun${sufijo}.dat";

my $empleados = leer_tabla($archivo_empleados, "!");
print scalar(@$empleados) . " rows in file\n";

my @resultados;
foreach my $e (@$empleados) {
    if (defined $e->[0] && $e->[0] eq $num_empleado) {
        push @resultados, $e->[0];
    }
}
print "Found " . scalar(@resultados) . " results.\n";

