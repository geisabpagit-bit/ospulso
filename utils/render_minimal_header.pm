# render_minimal_header.pm

package render_minimal_header;

use strict;
use warnings;
use utf8;
use CGI;
use Encode qw(encode_utf8);

# Exportar la función
use parent 'Exporter';
our @EXPORT = qw(print_minimal_header);

# Inicializar CGI dentro del paquete
my $q = CGI->new;

sub print_minimal_header {
    my ($title) = @_;
    
    # 1. IMPRIMIR EL HEADER HTML INCLUYENDO LOS ENLACES CORREGIDOS
    print $q->start_html(
        -title => encode_utf8($title),
        -charset => 'UTF-8',
        -head => [
            { -name => 'viewport', -content => 'width=device-width, initial-scale=1' },
            # URLs con sintaxis corregida
            { -rel => 'stylesheet', -href => 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css' },
            { -rel => 'stylesheet', -href => 'https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css' },
            { -rel => 'stylesheet', -href => 'https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css' },
            { -rel => 'stylesheet', -href => 'css/indexStyle.css' }
        ]
    );
    
    # 2. IMPRIMIR EL CONTENIDO MÍNIMO DE LA BARRA DE NAVEGACIÓN
    print encode_utf8(qq{
    <nav class="navbar navbar-expand-lg navbar-dark px-3">
        <a class="navbar-brand responsive-title" href="#">
            <i class="bi bi-hospital me-2"></i>Software Dental Mexicano
        </a>
    </nav>
    });
}

1;