#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8; 
use Encode qw(encode_utf8);
use FindBin;
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";

# --- FUNCIÓN: Carga la configuración dinámica de los Cards (NIVEL 2) ---
sub cargar_config_catalogo_cards {
    my $archivo = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'catalogo_cards.dat');
    my %card_details;
    return \%card_details unless (-e $archivo);

    open(my $fh, '<:encoding(UTF-8)', $archivo) or return \%card_details;

    while (my $linea = <$fh>) {
        chomp $linea;
        next if $linea =~ /^\s*#|^\s*$/;

        # Formato: CLAVE_SUBMENU|ARCHIVO_DESTINO|TÍTULO|DESCRIPCIÓN|ICONO_BS|COLOR_BS
        my ($clave, $destino, $titulo, $descripcion, $icono, $color) = split /\|/, $linea;

        $clave =~ s/^\s+|\s+$//g;

        $card_details{$clave} = {
            destino => $destino,
            title   => $titulo,
            desc    => $descripcion,
            icon    => $icono,
            color   => $color
        };
    }
    close($fh);
    return \%card_details;
}

# --- FUNCIÓN: Carga y parseo de roles_catalogo.dat (RBAC Nivel 2) ---
sub cargar_config_roles_catalogo {
    my $archivo = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'roles_catalogo.dat');
    my %roles_config;

    return \%roles_config unless (-e $archivo);

    open(my $fh, '<:encoding(UTF-8)', $archivo) or return \%roles_config;

    while (my $linea = <$fh>) {
        chomp $linea;
        next if $linea =~ /^\s*#|^\s*$/;

        # Formato: ROL|SUB_ENLACE_1|SUB_ENLACE_2|...
        my ($role_name, @enlaces) = split /\|/, $linea;

        $role_name =~ s/^\s+|\s+$//g;

        # Almacenamos solo la lista de enlaces de segundo nivel
        $roles_config{$role_name} = \@enlaces;
    }
    close($fh);
    return \%roles_config;
}

# --- SUBRUTINA PRINCIPAL: Genera las tarjetas de Catálogos ---
sub render_catalogo_principal {
    my %args = @_;
    my $role = $args{role} || 'Invitado';

    # 1. Cargar los sub-enlaces de acceso del rol
    my $roles_submenu = cargar_config_roles_catalogo();
    my @menu_keys = @{$roles_submenu->{$role} || []};

    # 2. Cargar los detalles visuales de los cards de catálogo
    my $CARD_DETAILS = cargar_config_catalogo_cards();

    print <<'HTML';
<div class="container mt-2">
    <div class="d-flex justify-content-between align-items-center mb-4 border-bottom pb-3">
        <h3 class="fw-bold m-0"><i class="bi bi-tools text-primary me-2"></i>Catálogos y Mantenimiento</h3>
        <span class="badge bg-danger bg-opacity-10 text-danger px-3 py-2 rounded-pill fs-6 fw-bold border border-danger border-opacity-25">Nivel: Administrador</span>
    </div>
    <div class="row g-4 justify-content-start">
HTML

    # Generación de Cards basada en el Rol (NIVEL 2)
    foreach my $menu_key (@menu_keys) {
        $menu_key =~ s/^\s+|\s+$//g;
        next unless $CARD_DETAILS->{$menu_key};

        my $details = $CARD_DETAILS->{$menu_key};
        my $url     = $details->{destino} || 'administracion_catalogo.pl';
        $url =~ s/^views\///; # Evitar duplicación de carpeta /views/ al estar ya en ella

        print <<CARD_HTML;
        <div class="col-12 col-sm-6 col-md-4 col-lg-3 animate__animated animate__fadeInUp">
            <a href="$url" class="text-decoration-none">
                <div class="card-medentia h-100 border-top border-4 border-$details->{color} d-flex flex-column justify-content-between p-3">
                    <div class="card-body text-center p-0 mb-3">
                        <div class="my-3">
                            <i class="bi $details->{icon} fs-1 text-$details->{color}"></i>
                        </div>
                        <h5 class="card-title text-dark fw-bold mb-2">$details->{title}</h5>
                        <p class="card-text small text-muted mb-0">$details->{desc}</p>
                    </div>
                    <div class="border-0 pt-2 mt-2 border-top small text-end text-$details->{color} fw-bold">
                        Acceder <i class="bi bi-arrow-right-circle-fill ms-1"></i>
                    </div>
                </div>
            </a>
        </div>
CARD_HTML
    }

    if (@menu_keys == 0) {
        print <<NO_CARDS;
        <div class="col-12 mt-5">
            <div class="alert alert-warning text-center shadow">
                <h4 class="alert-heading"><i class="bi bi-lock-fill me-2"></i>Acceso Restringido</h4>
                <p>Tu rol (<strong>$role</strong>) no tiene sub-opciones de catálogo configuradas.</p>
            </div>
        </div>
NO_CARDS
    }

    print <<'HTML';
    </div>
</div>
HTML

    # --- Script JS Aislado con comillas simples (Sin colisión de sigilos) para Hot Deploy ---
    print <<'JS';
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
window.iniciarHotDeploy = function() {
    Swal.fire({
        title: '¿Actualización en Caliente?',
        html: `<div class="text-start small">
            <p class="mb-2">Esta acción sincronizará el código fuente del sistema descargando la última versión de <strong>origin/main</strong> en segundo plano.</p>
            <div class="alert alert-info py-2 px-3 small border-0 mb-0">
                <i class="bi bi-shield-check me-2"></i><strong>Garantía de Integridad:</strong> La carpeta <code>/dat</code> está protegida con respaldo automático previo y restauración atómica.
            </div>
        </div>`,
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#19B7A5',
        cancelButtonColor: '#6c757d',
        confirmButtonText: '<i class="bi bi-lightning-charge-fill me-1"></i>Sí, actualizar ahora',
        cancelButtonText: 'Cancelar'
    }).then((result) => {
        if (result.isConfirmed) {
            ejecutarHotDeploy();
        }
    });
};

function ejecutarHotDeploy() {
    Swal.fire({
        title: 'Iniciando actualización...',
        html: `<div class="text-center py-2">
            <div class="spinner-border text-primary mb-3" role="status"></div>
            <p class="small text-muted mb-2">Descargando cambios y ejecutando verificación de permisos...</p>
            <div id="deployTerminal" class="p-2 text-start font-monospace bg-dark text-light rounded small" style="height: 160px; overflow-y: auto; font-size: 0.75rem;">
                Conectando con el servidor...
            </div>
        </div>`,
        allowOutsideClick: false,
        showConfirmButton: false
    });

    fetch('../api/hot_deploy_api.pl?action=trigger')
    .then(r => r.json())
    .then(data => {
        if (data.status === 'started' || data.status === 'already_running') {
            monitorearHotDeploy();
        } else {
            Swal.fire('Error', data.message || 'No se pudo iniciar el proceso.', 'error');
        }
    })
    .catch(err => {
        Swal.fire('Error de Conexión', 'No se pudo conectar con api/hot_deploy_api.pl', 'error');
    });
}

function monitorearHotDeploy() {
    const pollInterval = setInterval(() => {
        fetch('../api/hot_deploy_api.pl?action=status')
        .then(r => r.json())
        .then(res => {
            const terminal = document.getElementById('deployTerminal');
            if (terminal && res.log) {
                terminal.innerText = res.log;
                terminal.scrollTop = terminal.scrollHeight;
            }

            if (!res.running) {
                clearInterval(pollInterval);
                setTimeout(() => {
                    Swal.fire({
                        icon: 'success',
                        title: '¡Actualización Completada!',
                        text: 'El sistema se ha actualizado con éxito a la última versión.',
                        confirmButtonColor: '#19B7A5',
                        confirmButtonText: 'Recargar Sistema'
                    }).then(() => {
                        window.location.reload();
                    });
                }, 1000);
            }
        })
        .catch(err => {
            console.warn("Sondeando estado...", err);
        });
    }, 2000);
}
</script>
JS
}

1;
