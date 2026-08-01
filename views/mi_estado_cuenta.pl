#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use FindBin;
use File::Spec;

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'render_error_sesion.pl');

my $session_data = check_session();
my $q          = $session_data->{q};
my $session_ok = $session_data->{session_ok};
my $usuario    = $session_data->{usuario};
my $role       = $session_data->{role};

if (!$session_ok || $role ne 'Paciente') {
    render_error_sesion();
    exit;
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');

render_header(
    usuario     => $usuario,
    titulo      => 'OsPulso - Mi Estado de Cuenta',
    ruta_logout => '../auth/cerrar_sesion.pl',
    role        => $role,
    skip_header => 1
);

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    pagina_actual => 'mi_estado_cuenta'
);

print <<'HTML';
<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h2><i class="bi bi-wallet2 me-2 text-primary"></i> Mi Estado de Cuenta</h2>
        <div class="card bg-primary text-white shadow-sm" style="min-width: 200px;">
            <div class="card-body py-2 text-center">
                <small>Saldo Pendiente Global</small>
                <h4 class="mb-0" id="saldo_total">$0.00</h4>
            </div>
        </div>
    </div>

    <div class="card shadow-sm">
        <div class="card-body">
            <div id="fin_loader" class="text-center py-5">
                <div class="spinner-border text-primary" role="status"></div>
                <p class="mt-2 text-muted">Cargando tus movimientos...</p>
            </div>
            
            <div id="fin_empty" class="text-center py-5" style="display:none;">
                <i class="bi bi-receipt display-1 text-muted"></i>
                <h4 class="mt-3">Sin movimientos registrados</h4>
                <p class="text-muted">Tus cargos y abonos aparecerán aquí.</p>
            </div>

            <div class="table-responsive" id="fin_table_container" style="display:none;">
                <table class="table table-hover align-middle">
                    <thead class="table-light">
                        <tr>
                            <th>Fecha</th>
                            <th>ID / Folio</th>
                            <th>Concepto</th>
                            <th>Médico</th>
                            <th>Tipo</th>
                            <th class="text-end">Monto</th>
                        </tr>
                    </thead>
                    <tbody id="fin_tbody">
                        <!-- Llenado vía JS -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<script>
$(document).ready(function() {
    $.ajax({
        url: '../api/get_mi_estado_cuenta.pl',
        type: 'GET',
        dataType: 'json',
        success: function(res) {
            $('#fin_loader').hide();
            if(res.ok) {
                // Formateador de moneda
                const formatter = new Intl.NumberFormat('es-MX', {
                    style: 'currency',
                    currency: 'MXN',
                });
                
                $('#saldo_total').text(formatter.format(res.saldo_total));
                if(res.saldo_total <= 0) {
                    $('#saldo_total').parent().parent().removeClass('bg-primary').addClass('bg-success');
                    $('#saldo_total').parent().find('small').text('Saldo a Favor / Liquidado');
                } else {
                    $('#saldo_total').parent().parent().removeClass('bg-primary').addClass('bg-danger');
                }

                if(res.movimientos.length > 0) {
                    $('#fin_table_container').fadeIn();
                    let html = '';
                    res.movimientos.forEach(m => {
                        let textClass = m.tipo === 'Cargo' ? 'text-danger' : 'text-success';
                        let prefix = m.tipo === 'Cargo' ? '+' : '-';
                        let f = new Date(m.fecha * 1000).toLocaleString('es-MX', {year:'numeric', month:'short', day:'numeric'});
                        
                        html += `<tr>
                            <td>${f}</td>
                            <td><small class="text-muted">${m.id_os}</small></td>
                            <td><strong>${m.concepto}</strong></td>
                            <td><i class="bi bi-person-badge me-1"></i> ${m.medico_nombre}</td>
                            <td><span class="badge ${m.tipo === 'Cargo' ? 'bg-danger' : 'bg-success'}">${m.tipo}</span></td>
                            <td class="text-end ${textClass}"><strong>${prefix}${formatter.format(m.total)}</strong></td>
                        </tr>`;
                    });
                    $('#fin_tbody').html(html);
                } else {
                    $('#fin_empty').fadeIn();
                }
            } else {
                Swal.fire('Error', res.msg, 'error');
            }
        },
        error: function() {
            $('#fin_loader').hide();
            Swal.fire('Error', 'No se pudo cargar el estado de cuenta', 'error');
        }
    });
});
</script>
HTML

utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('mi_estado_cuenta');

1;
