#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use File::Spec;
use open qw(:std :utf8);

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
use utils::db_manager qw(leer_tabla eliminar_registro);

my $sd = check_session();
my $q  = $sd->{q};

# Validar sesión
unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario   = $sd->{usuario};
my $role      = $sd->{role};
my $id_medico = $sd->{id_medico};
my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');

# Manejo de Borrado
if (my $did = $q->param('delete_id')) {
    if ($role =~ /Administrador|Soporte/i || $role eq 'Medico') {
        eliminar_registro($archivo_pacientes, $did, '\|', "ID_PACIENTE|ID_MEDICO|NOMBRE|RFC|CURP|CORREO|FECHA_NAC|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO");
    }
    print $q->redirect('pacientes.pl'); 
    exit;
}

# 1. Cabecera Corporativa
print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => "Directorio Clínico - SDM",
    skip_header => 1
);

my $regs = leer_tabla($archivo_pacientes, '\|');
my @list;
if ($regs) {
    foreach my $r (@$regs) {
        next if @$r < 6;
        if ($role =~ /Administrador|Soporte|Recepcionista/i || $r->[1] eq $id_medico) {
            push @list, { 
                id        => $r->[0], 
                nombre    => $r->[2], 
                curp      => $r->[4], 
                correo    => $r->[5],
                fecha_nac => $r->[6],
                sexo      => $r->[7],
                telefono  => $r->[12]
            };
        }
    }
}

print <<HTML;
<link rel="stylesheet" href="../css/ospulso_master.css">
<link rel="stylesheet" href="../css/tabla_pacientes.css">

<div class="container-fluid p-0 p-md-3">
    <!-- Tabla / Lista de Pacientes -->
    <div class="medentia-table-container">
        <div class="table-responsive">
            <table id="tablaPacientes" class="table table-medentia w-100 m-0 border-0">
                <thead>
                    <tr>
                        <th class="ps-4 py-3">ID</th>
                        <th class="py-3">NOMBRE COMPLETO</th>
                        <th class="py-3">CONTACTO</th>
                        <th class="py-3">F. NAC / SEXO</th>
                        <th class="text-end pe-4 py-3">ACCIONES</th>
                    </tr>
                </thead>
                <tbody class="border-0">
HTML

foreach my $p (@list) {
    my $display_id = sprintf("%03d", $p->{id} || 0);
    my $nombre = $p->{nombre} || 'Sin Nombre';
    my $curp = $p->{curp} || 'Sin CURP';
    my $correo = $p->{correo} || 'No registrado';
    my $telefono = $p->{telefono} || 'N/A';
    my $fecha_nac = $p->{fecha_nac} || 'N/A';
    my $sexo = $p->{sexo} || 'N/A';

    print <<ROW;
                <tr>
                    <td class="fw-bold text-muted ps-4">
                        $display_id
                    </td>
                    <td>
                        <span class="patient-name">$nombre</span>
                        <span class="patient-info-sub d-block mt-1"><i class="bi bi-person-badge me-1"></i>$curp</span>
                    </td>
                    <td>
                        <div class="patient-info-sub d-flex flex-column gap-1">
                            <span><i class="bi bi-telephone text-muted me-2"></i>$telefono</span>
                            <span><i class="bi bi-envelope text-muted me-2"></i>$correo</span>
                        </div>
                    </td>
                    <td>
                        <div class="patient-info-sub d-flex flex-column gap-1">
                            <span><i class="bi bi-calendar3 text-muted me-2"></i>$fecha_nac</span>
                            <span class="text-uppercase"><i class="bi bi-gender-ambiguous text-muted me-2"></i>$sexo</span>
                        </div>
                    </td>
                    <td class="text-end pe-4">
                        <div class="action-btn-group justify-content-end">
                            <button class="action-btn btn-expediente" data-id="$p->{id}" title="Resumen">
                                <i class="bi bi-eye"></i>
                            </button>
                            <a href="render_expediente_clinico.pl?id=$p->{id}" class="action-btn" title="Expediente">
                                <i class="bi bi-journal-medical"></i>
                            </a>
                            <a href="estado_cuenta.pl?id=$p->{id}" class="action-btn" title="Finanzas">
                                <i class="bi bi-wallet2"></i>
                            </a>
                            <a href="agenda_main.pl?id_paciente=$p->{id}" class="action-btn" title="Cita">
                                <i class="bi bi-calendar-plus"></i>
                            </a>
                            <button onclick="confirmBorrar('$p->{id}')" class="action-btn action-btn-delete" title="Eliminar">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </td>
                </tr>
ROW
}

print <<'HTML';
                </tbody>
            </table>
        </div>
    </div>
</div>


<!-- Offcanvas de Resumen Responsivo -->
<div class="offcanvas offcanvas-end shadow-lg border-0" tabindex="-1" id="expedienteCanvas" style="max-width: 100%; width: 550px; border-left: 4px solid #19B7A5 !important;">
  <div class="offcanvas-header border-bottom bg-light">
    <h5 class="fw-black m-0 plus-jakarta"><i class="bi bi-person-lines-fill me-2 text-primary"></i>Resumen de Expediente</h5>
    <button type="button" class="btn-close" data-bs-dismiss="offcanvas"></button>
  </div>
  <div class="offcanvas-body p-0 bg-white" id="expedienteContenido">
     <div class="text-center py-5 text-muted"><div class="spinner-border spinner-border-sm me-2"></div>Cargando datos...</div>
  </div>
</div>

<!-- Scripts y Librerías de Exportación (Regla 4.3) -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">

<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>

<!-- Librerías de exportación -->
<script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/vfs_fonts.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>

<!-- Diagnóstico de Dispositivos y Polyfills para Tizen TV / WebView -->
<script>
    (function() {
        // 1. Detectar entorno de bajos recursos o TV
        var ua = navigator.userAgent || '';
        window.SDM_IS_LOW_MEM = /Tizen|SmartTV|Web0S|WebView|Xbox|Nintendo/i.test(ua);
        
        // 2. Captura global de errores (Capa 5 - Logs y Diagnóstico)
        window.onerror = function(message, source, lineno, colno, error) {
            console.error("[SDM Diagnostic] Crash detectado:", message, "en", source, "línea:", lineno);
            var contenido = document.getElementById('expedienteContenido');
            if (contenido && (contenido.innerHTML.indexOf('Cargando') > -1 || contenido.innerHTML.trim() === '')) {
                contenido.innerHTML = '<div class="alert alert-warning m-4 shadow-sm border-0">' +
                    '<h6 class="fw-bold mb-2"><i class="bi bi-exclamation-triangle-fill me-2"></i>Compatibilidad Limitada</h6>' +
                    '<p class="mb-0 small">El navegador de este dispositivo (Smart TV / WebView) experimentó un problema de memoria o falta de compatibilidad. Por favor intente recargar.</p>' +
                    '</div>';
            }
            return false;
        };
    })();
</script>

<script src="../js/pacientes_spa.js"></script>

<script>
    $(document).ready(function() {
        if ($('#tablaPacientes').length) {
            var table = $('#tablaPacientes').DataTable({
                language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                // dom: B=Botones, t=Tabla, i=Info, p=Paginas. (Se quita 'f' de buscador interno)
                dom: '<"p-3 d-flex justify-content-start align-items-center"B>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
                buttons: {
                    dom: {
                        container: {
                            className: 'dt-buttons export-toolbar'
                        },
                        button: {
                            className: 'btn-export'
                        }
                    },
                    buttons: [
                        { 
                            extend: 'copy', 
                            text: '<i class="bi bi-clipboard"></i> Copiar',
                            exportOptions: { columns: [0, 1, 2, 3] }
                        },
                        { 
                            extend: 'excel', 
                            text: '<i class="bi bi-file-earmark-excel"></i> Excel', 
                            title: 'Hospital SDM',
                            messageTop: 'Módulo: Directorio de Pacientes',
                            messageBottom: 'Aviso de confidencialidad: Este documento contiene información confidencial destinada únicamente al receptor autorizado.\r\nCódigo interno: SDM-DIR-PAC',
                            exportOptions: { columns: [0, 1, 2, 3] },
                            customize: function(xlsx) {
                                var sheet = xlsx.xl.worksheets['sheet1.xml'];
                                $('row c[r^="A1"]', sheet).attr('s', '2');
                            }
                        },
                        { 
                            extend: 'pdf', 
                            text: '<i class="bi bi-file-earmark-pdf"></i> PDF', 
                            title: 'Hospital SDM',
                            messageTop: 'Módulo: Directorio de Pacientes',
                            exportOptions: { columns: [0, 1, 2, 3] },
                            customize: function (doc) {
                                doc.styles.tableHeader = { fillColor: '#0d1e3d', color: 'white', alignment: 'center', bold: true, fontSize: 10 };
                                
                                // Buscar el índice exacto donde está la tabla
                                var tableIndex = -1;
                                for (var i = 0; i < doc.content.length; i++) {
                                    if (doc.content[i].table) {
                                        tableIndex = i;
                                        break;
                                    }
                                }

                                if (tableIndex > -1) {
                                    // Ajustar anchos y márgenes para las 4 columnas exportadas
                                    doc.content[tableIndex].table.widths = ['10%', '35%', '30%', '25%'];
                                    doc.content[tableIndex].margin = [0, 10, 0, 10];
                                    
                                    // Remover todo lo inyectado por defecto antes de la tabla (title, messageTop)
                                    if (tableIndex > 0) {
                                        doc.content.splice(0, tableIndex);
                                    }
                                }

                                var now = new Date();
                                var jsDate = now.getDate().toString().padStart(2, '0') + '/' + (now.getMonth() + 1).toString().padStart(2, '0') + '/' + now.getFullYear();
                                
                                doc['header'] = (function() {
                                    return {
                                        columns: [
                                            { alignment: 'left', text: 'Hospital SDM\nMódulo: Directorio de Pacientes\nFecha: ' + jsDate, margin: [20, 20], fontSize: 10, bold: true }
                                        ]
                                    };
                                });
                                
                                doc.pageMargins = [20, 80, 20, 80];
                                
                                doc['footer'] = (function(page, pages) {
                                    return {
                                        columns: [
                                            { alignment: 'left', text: 'Aviso de confidencialidad: Este documento contiene información confidencial destinada únicamente al receptor autorizado.\nCódigo interno: SDM-DIR-PAC', fontSize: 8 },
                                            { alignment: 'right', text: 'Página ' + page.toString() + ' de ' + pages.toString(), fontSize: 8 }
                                        ],
                                        margin: [20, 10]
                                    }
                                });
                            }
                        },
                        { 
                            extend: 'print', 
                            text: '<i class="bi bi-printer"></i> Imprimir',
                            title: '',
                            exportOptions: { columns: [0, 1, 2, 3] },
                            customize: function (win) {
                                var now = new Date();
                                var jsDate = now.getDate().toString().padStart(2, '0') + '/' + (now.getMonth() + 1).toString().padStart(2, '0') + '/' + now.getFullYear();
                                
                                $(win.document.body).css('font-family', 'Inter, sans-serif');
                                $(win.document.body).prepend(
                                    '<div style="text-align:center; margin-bottom: 20px;">' +
                                    '<h2>Hospital SDM</h2>' +
                                    '<p><strong>Módulo:</strong> Directorio de Pacientes<br>' +
                                    '<strong>Fecha:</strong> ' + jsDate + '</p>' +
                                    '</div><hr>'
                                );
                                $(win.document.body).append(
                                    '<hr><div style="font-size: 0.8rem; text-align:center; margin-top: 20px;">' +
                                    '<p><strong>Aviso de confidencialidad:</strong> Este documento contiene información confidencial destinada únicamente al receptor autorizado.</p>' +
                                    '<p><strong>Código interno:</strong> SDM-DIR-PAC</p>' +
                                    '</div>'
                                );
                            }
                        }
                    ]
                },
                pageLength: 10,
                responsive: true
            });

            // Sincronización con el Buscador Global del Header (Regla 4.3 Adaptada)
            $('#globalSearch').on('keyup', function() {
                table.search(this.value).draw();
                
                // Experiencia Premium: Ocultar paginador durante la búsqueda
                if (this.value.length > 0) {
                    $('.dataTables_paginate, .dataTables_info').fadeOut(200);
                } else {
                    $('.dataTables_paginate, .dataTables_info').fadeIn(200);
                }
            });
        }
    });

    function confirmBorrar(id) {
        if(confirm("¿Seguro que desea eliminar al paciente ID " + id + "?")) { 
            window.location.href = 'pacientes.pl?delete_id=' + id; 
        }
    }
</script>
HTML

print "</main>\n";
render_bottom_nav('pacientes');
print "</body></html>\n";
1;
