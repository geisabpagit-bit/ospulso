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
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');

use utils::audit_manager qw(log_audit);
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

# Seguridad Estricta RBAC / Privacidad Multi-Tenant
if ($role =~ /Administrador Global/i) {
    require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_acceso_denegado.pl');
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    render_acceso_denegado(
        q             => $q,
        usuario       => $usuario,
        role          => $role,
        titulo        => "Pacientes - Acceso Restringido",
        mensaje       => "Por políticas de privacidad multi-tenant y confidencialidad médica (NOM-004), el Administrador Global no tiene acceso al padrón de pacientes de las organizaciones.",
        rol_requerido => "Médico / Recepcionista / Administrador Organización"
    );
    exit;
}

my $id_medico = $sd->{id_medico} || '';
my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');

# Manejo de Borrado
if (my $did = $q->param('delete_id')) {
    my $regs = leer_tabla($archivo_pacientes, '\|');
    my $acceso_permitido = 0;
    foreach my $r (@$regs) {
        if ($r->[0] eq $did) {
            my $tenant_pac = $r->[13] // '';
            my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
            my $mi_org = $sd->{id_empresa} || 'X';
            my $mi_sucursal = $sd->{id_sucursal} // 0;
            
            if ($role eq 'Administrador Global') {
                $acceso_permitido = 1;
            } elsif ($role =~ /Administrador Organizacion|Soporte/i) {
                if ($org_pac && $org_pac eq $mi_org) {
                    $acceso_permitido = 1;
                } elsif (!$org_pac) {
                    $acceso_permitido = 1;
                }
            } elsif ($role =~ /Medico|Asistente|Recepcion/i) {
                if ($org_pac && $org_pac eq $mi_org) {
                    if ($suc_pac eq $mi_sucursal || !$suc_pac || !$mi_sucursal) {
                        $acceso_permitido = 1;
                    }
                } elsif (!$org_pac) {
                    $acceso_permitido = 1;
                }
            }
            last;
        }
    }
    
    if ($acceso_permitido) {
        log_audit('Pacientes', 'Eliminar', "Se elimino al paciente con ID: $did", $did, $usuario);
        eliminar_registro($archivo_pacientes, $did, '\|', "ID_PACIENTE|ID_MEDICO|NOMBRE|RFC|CURP|CORREO|FECHA_NAC|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO|TENANT");
    }
    print $q->redirect('pacientes.pl'); 
    exit;
}

# 1. Cabecera Corporativa
print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => "Directorio Clínico",
    skip_header => 1
);

my $regs = leer_tabla($archivo_pacientes, '\|');
my @list;
if ($regs) {
    foreach my $r (@$regs) {
        next if @$r < 6;
        # Extraer Tenant del Paciente (Indice 13)
        my $tenant_pac = $r->[13] // '';
        my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
        
        my $mi_org = $sd->{id_empresa} || 'X';
        my $mi_sucursal = $sd->{id_sucursal} // 0;
        my $es_mi_tenant = 0;
        
        # Administrador Global ve todo
        if ($role eq 'Administrador Global') {
            $es_mi_tenant = 1;
        } 
        # Administrador Organización / Soporte
        elsif ($role =~ /Administrador Organizacion|Soporte/i) {
            if ($org_pac && $org_pac eq $mi_org) {
                $es_mi_tenant = 1;
            } elsif (!$org_pac) {
                $es_mi_tenant = 1;
            }
        }
        # Médico / Asistente ve pacientes de su organización / sucursal
        elsif ($role =~ /Medico|Asistente|Recepcion/i) {
            if ($org_pac && $org_pac eq $mi_org) {
                if ($suc_pac eq $mi_sucursal || !$suc_pac || !$mi_sucursal) {
                    $es_mi_tenant = 1;
                }
            } elsif (!$org_pac) {
                $es_mi_tenant = 1;
            }
        }

        if ($es_mi_tenant) {
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

# --- VERIFICAR SAAS CAPABILITIES (PACIENTES_ESTADO) Y CLUES ---
my $has_pacientes_estado = 0;
my $found_pacientes_estado = 0;
my $id_empresa = $sd->{id_empresa} // '';
my $org_clues = '';

my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
if (-e $negocios_file && open(my $fn, '<:raw', $negocios_file)) {
    while(my $ln = <$fn>) {
        chomp($ln);
        my @f = split(/\|/, $ln, -1);
        my $row_id = $f[0] // '';
        $row_id =~ s/\x00//g; $row_id =~ s/^\s+|\s+$//g;
        if ($row_id eq $id_empresa || ($id_empresa eq '0' && ($row_id eq '0' || $row_id eq ''))) {
            my $c_val = $f[18] // '';
            $c_val =~ s/\x00//g; $c_val =~ s/^\s+|\s+$//g;
            $org_clues = $c_val if $c_val;
            last;
        }
    }
    close($fn);
}

my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
if (-e $config_file && open(my $cf, '<:utf8', $config_file)) {
    while (my $line = <$cf>) {
        chomp($line);
        next if $line =~ /^#|^\s*$/;
        my ($biz_id, $key, $val) = split(/\|/, $line);
        if ($biz_id eq $id_empresa && $key eq 'PACIENTES_ESTADO') {
            $has_pacientes_estado = ($val eq '1') ? 1 : 0;
            $found_pacientes_estado = 1;
            last;
        }
    }
    close($cf);
}
if (!$found_pacientes_estado && ($id_empresa eq '0' || $id_empresa eq '') && length($org_clues)) {
    $has_pacientes_estado = 1;
}

print <<HTML;
<link rel="stylesheet" href="../css/ospulso_master_v2.css">
<link rel="stylesheet" href="../css/tabla_pacientes.css?v=$^T">
<link rel="stylesheet" href="../css/sdm_mobile_standards.css?v=1.1">
HTML

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    pagina_actual => 'pacientes'
);

print <<HTML;
        <!-- TOPBAR / HEADER CORPORATIVO (ESTÁNDAR IMAGEN 2: Oculto en móvil al existir menú inferior/global) -->
        <header id="pacientesHeroHeader" class="bg-medentia-gradient text-white p-4 shadow-sm mb-4 d-none d-md-block" style="border-radius: 1.5rem;">
            <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-white bg-opacity-10 p-3 rounded-circle d-flex align-items-center justify-content-center" style="width: 54px; height: 54px;">
                        <i class="bi bi-people-fill fs-3 text-white"></i>
                    </div>
                    <div>
                        <h2 class="fw-black mb-0 text-white" style="letter-spacing: -0.5px;">Directorio de Pacientes</h2>
                        <p class="text-white-50 small mb-0 mt-1">Gestión integral de expedientes clínicos</p>
                    </div>
                </div>
                <div>
                    <button type="button" class="btn text-white fw-bold rounded-pill px-4 py-2 shadow-sm d-flex align-items-center gap-2" style="background: #082050; border: 1px solid rgba(255,255,255,0.2);" onclick="iniciarAltaPaciente()">
                        <i class="bi bi-person-plus-fill text-white"></i><span>Agregar nuevo paciente</span>
                    </button>
                </div>
            </div>
        </header>

<div class="container-fluid p-0 p-md-3 container-mobile-flush">
    <!-- Tabla / Lista de Pacientes -->
    <div class="rounded-4 shadow-sm bg-white mb-4 card-mobile-flush">
        <div class="table-responsive">
            <table id="tablaPacientes" class="table table-diamond w-100 m-0 border-0">
                <thead>
                    <tr>
                        <th class="ps-4 py-3 border-top-0">ID</th>
                        <th class="py-3 border-top-0">NOMBRE COMPLETO</th>
                        <th class="py-3 border-top-0">CONTACTO</th>
                        <th class="py-3 border-top-0">F. NAC / SEXO</th>
                        <th class="text-end pe-4 py-3 border-top-0">ACCIONES</th>
                    </tr>
                </thead>
                <tbody class="border-0">
                <!-- Los datos se inyectarán vía AJAX por DataTables -->
HTML

print <<'HTML';
                </tbody>
            </table>
        </div>
    </div>
</div>
HTML

utils::sub_sidebar::render_sidebar_footer();

print <<'HTML';
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

<!-- Modal de Resumen Blindado (Aislado de Stacking Context y con z-index 105150 superior a backdrop) -->
<div class="modal fade modal-diamond" id="expedienteModal" tabindex="-1" aria-labelledby="expedienteModalLabel" aria-hidden="true" style="z-index: 105150 !important;">
  <div class="modal-dialog modal-lg modal-dialog-centered">
    <div class="modal-content border-0 shadow-lg">
      <div class="modal-header">
        <h5 class="modal-title d-flex align-items-center" id="expedienteModalLabel">
            <i class="bi bi-person-lines-fill me-2" style="color: #00C4C4 !important;"></i> 
            <span id="modalHeaderTitle">Resumen de Expediente</span>
        </h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close" onclick="if(window.cerrarModalExpediente) window.cerrarModalExpediente();"></button>
      </div>
      <div class="modal-body" id="expedienteContenido">
         <div class="text-center py-4 text-muted"><div class="spinner-border spinner-border-sm me-2 text-primary"></div>Cargando expediente...</div>
      </div>
    </div>
  </div>
</div>

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

<!-- Scripts Específicos para Pacientes SPA -->
<script>
    window.USER_ROLE = '$role';
</script>
<script src="../js/pacientes_spa.js?v=20260707_0017"></script>
<script src="../js/cotizaciones_spa.js?v=20260711_0001"></script>

<script>
    $(document).ready(function() {
        if ($('#tablaPacientes').length) {
            var table = $('#tablaPacientes').DataTable({
                serverSide: true,
                processing: true,
                ajax: {
                    url: '../api/pacientes_dt_api.pl',
                    type: 'POST'
                },
                language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
                // dom: B=Botones, t=Tabla, i=Info, p=Paginas. (Se quita 'f' de buscador interno)
                dom: '<"pacientes-dt-header p-2 p-md-3 d-flex justify-content-center justify-content-md-start align-items-center"B>rt<"pacientes-dt-footer p-2 p-md-3 d-flex flex-column flex-md-row justify-content-between align-items-center gap-2"i p>',
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
                            text: '<i class="bi bi-clipboard"></i><span class="export-label d-none d-md-inline ms-1">Copiar</span>',
                            titleAttr: 'Copiar al portapapeles',
                            exportOptions: { columns: [0, 1, 2, 3] }
                        },
                        { 
                            extend: 'excel', 
                            text: '<i class="bi bi-file-earmark-excel"></i><span class="export-label d-none d-md-inline ms-1">Excel</span>', 
                            titleAttr: 'Exportar a Excel',
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
                            text: '<i class="bi bi-file-earmark-pdf"></i><span class="export-label d-none d-md-inline ms-1">PDF</span>', 
                            titleAttr: 'Exportar a PDF',
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
                            text: '<i class="bi bi-printer"></i><span class="export-label d-none d-md-inline ms-1">Imprimir</span>',
                            titleAttr: 'Imprimir listado',
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
                initComplete: function() {
                    if (typeof bootstrap !== 'undefined' && bootstrap.Tooltip) {
                        var tooltipTriggerList = [].slice.call(document.querySelectorAll('#tablaPacientes_wrapper [title]'));
                        tooltipTriggerList.map(function (tooltipTriggerEl) {
                            return new bootstrap.Tooltip(tooltipTriggerEl, { container: 'body' });
                        });
                    }
                },
                pageLength: 10,
                responsive: true
            });

            // Sincronización con el Buscador Global del Header (Regla 4.3 Adaptada)
            $('#globalSearch').on('keyup', function() {
                table.search(this.value).draw();
                
                // Experiencia Premium: Ocultar paginador durante la búsqueda
                // Experiencia Premium: Fade Effect
                if (this.value.length > 0) {
                    $('.dataTables_info').fadeOut(200);
                } else {
                    $('.dataTables_info').fadeIn(200);
                }
            });
        }
    });

    function confirmBorrar(id) {
        Swal.fire({
            title: '¿Eliminar paciente?',
            text: "Esta acción no se puede deshacer y borrará permanentemente sus datos.",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#e74c3c',
            cancelButtonColor: '#486581',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar',
            background: '#ffffff',
            customClass: {
                popup: 'rounded-4 shadow-lg'
            }
        }).then((result) => {
            if (result.isConfirmed) {
                window.location.href = 'pacientes.pl?delete_id=' + id;
            }
        });
    }

    // --- FLUJO INTELIGENTE DE ALTA DE PACIENTE (CAPACIDAD SAAS) ---
    window.HAS_PACIENTES_ESTADO = $has_pacientes_estado;
    window.ORG_CLUES = "$org_clues";

    function iniciarAltaPaciente() {
        if (!window.HAS_PACIENTES_ESTADO) {
            sessionStorage.removeItem('sdm_import_empleado');
            window.location.href = 'crud_paciente.pl';
            return;
        }

        Swal.fire({
            title: 'Registro de Paciente',
            text: '¿Deseas realizar una captura en blanco o importar un empleado de municipio?',
            icon: 'question',
            showCancelButton: true,
            showDenyButton: true,
            confirmButtonColor: '#0A2A66',
            denyButtonColor: '#19B7A5',
            cancelButtonColor: '#64748b',
            confirmButtonText: '<i class="bi bi-pencil-square me-1"></i> Captura Nueva',
            denyButtonText: '<i class="bi bi-building-down me-1"></i> Importar Municipio',
            cancelButtonText: 'Cancelar',
            customClass: {
                popup: 'rounded-4 shadow-lg'
            }
        }).then((result) => {
            if (result.isConfirmed) {
                sessionStorage.removeItem('sdm_import_empleado');
                window.location.href = 'crud_paciente.pl';
            } else if (result.isDenied) {
                abrirModalImportarEmpleadoPacientes();
            }
        });
    }

    let debounceTimerPacientes = null;
    function debounceBuscarEmpleadoPacientes(val) {
        clearTimeout(debounceTimerPacientes);
        if (!val || val.trim().length < 2) return;
        debounceTimerPacientes = setTimeout(() => {
            ejecutarBusquedaEmpleadoPacientes();
        }, 350);
    }

    function abrirModalImportarEmpleadoPacientes() {
        const el = document.getElementById('modalImportarEmpleadoPacientes');
        if (!el) return;
        if (window.bootstrap && bootstrap.Modal) {
            const modal = bootstrap.Modal.getOrCreateInstance(el);
            modal.show();
        } else {
            $(el).modal('show');
        }
        setTimeout(() => {
            const inp = document.getElementById('iptBuscarEmpleadoPacientes');
            if (inp) {
                inp.focus();
                inp.select();
            }
        }, 400);
    }

    function escapeHtmlSafe(str) {
        if (!str) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function ejecutarBusquedaEmpleadoPacientes() {
        const inp = document.getElementById('iptBuscarEmpleadoPacientes');
        const cont = document.getElementById('resEmpleadoPacientesCont');
        if (!inp || !cont) return;
        const qStr = inp.value.trim();
        if (qStr.length < 2) {
            cont.innerHTML = '<div class="alert alert-warning py-2 px-3 small m-2"><i class="bi bi-exclamation-circle me-1"></i>Ingresa al menos 2 caracteres o dígitos para buscar.</div>';
            return;
        }

        cont.innerHTML = `
            <div class="text-center py-5 text-muted">
                <div class="spinner-border text-primary spinner-border-sm me-2" role="status"></div>
                <span class="small fw-semibold">Consultando padrón oficial...</span>
            </div>`;

        $.ajax({
            url: '../api/buscar_empleadosmun.pl',
            type: 'POST',
            data: { q: qStr, clues: window.ORG_CLUES || '' },
            dataType: 'json',
            success: function(data) {
                if (!data || data.length === 0) {
                    cont.innerHTML = `
                        <div class="text-center py-4 text-muted">
                            <i class="bi bi-person-x fs-1 text-secondary opacity-50 d-block mb-2"></i>
                            <span class="fw-bold small text-dark">No se encontraron registros en el padrón</span>
                            <p class="text-muted small m-0" style="font-size:0.75rem;">Verifica el número de empleado o la ortografía del nombre.</p>
                        </div>`;
                    return;
                }

                let html = '<div class="list-group list-group-flush gap-2">';
                data.forEach((emp) => {
                    let isBeneficiario = emp.relacion && emp.relacion.toLowerCase() !== 'empleado';
                    let badgeClass = isBeneficiario ? 'bg-info text-dark' : 'bg-primary text-white';
                    let depHtml = emp.dependencia ? `<div class="small text-muted text-truncate" style="font-size:0.73rem;"><i class="bi bi-building me-1"></i>${escapeHtmlSafe(emp.dependencia)}</div>` : '';
                    let telHtml = emp.telefono ? `<span class="me-2"><i class="bi bi-telephone me-1"></i>${escapeHtmlSafe(emp.telefono)}</span>` : '';
                    let corHtml = emp.correo ? `<span><i class="bi bi-envelope me-1"></i>${escapeHtmlSafe(emp.correo)}</span>` : '';

                    let empJson = JSON.stringify(emp).replace(/'/g, "&apos;");

                    html += `
                        <div class="list-group-item bg-light rounded-3 p-2.5 border shadow-2xs d-flex align-items-center justify-content-between gap-2">
                            <div class="overflow-hidden flex-grow-1 min-w-0">
                                <div class="d-flex align-items-center gap-2 mb-1 flex-wrap">
                                    <span class="fw-bold text-dark text-truncate small" style="font-size:0.85rem;">${escapeHtmlSafe(emp.nombre)}</span>
                                    <span class="badge ${badgeClass} rounded-pill px-2 py-0.5" style="font-size:0.65rem;">${escapeHtmlSafe(emp.relacion || 'Empleado')}</span>
                                    <span class="badge bg-secondary-subtle text-secondary rounded-pill px-2 py-0.5" style="font-size:0.65rem;">No. #${escapeHtmlSafe(emp.num_empleado)}</span>
                                </div>
                                ${depHtml}
                                <div class="small text-muted mt-1" style="font-size:0.72rem;">
                                    ${telHtml}${corHtml}
                                </div>
                            </div>
                            <button type="button" class="btn btn-sm rounded-pill text-white px-3 fw-bold flex-shrink-0" style="background: var(--md-teal-clinical, #19B7A5); font-size:0.75rem;" onclick='seleccionarEmpleadoParaImportarPacientes(${empJson})'>
                                <i class="bi bi-box-arrow-in-down-right me-1"></i>Importar
                            </button>
                        </div>`;
                });
                html += '</div>';
                cont.innerHTML = html;
            },
            error: function(xhr, status, err) {
                console.error("Error al buscar empleados:", err);
                cont.innerHTML = '<div class="alert alert-danger py-2 px-3 small m-2">Error de comunicación con el servidor al consultar el padrón.</div>';
            }
        });
    }

    function seleccionarEmpleadoParaImportarPacientes(emp) {
        if (!emp) return;
        sessionStorage.setItem('sdm_import_empleado', JSON.stringify(emp));
        const el = document.getElementById('modalImportarEmpleadoPacientes');
        if (el) {
            if (window.bootstrap && bootstrap.Modal) {
                const modal = bootstrap.Modal.getInstance(el);
                if (modal) modal.hide();
            } else {
                $(el).modal('hide');
            }
        }
        window.location.href = 'crud_paciente.pl?origen=municipio';
    }
</script>

<!-- MODAL PARA IMPORTACIÓN ASISTIDA EN DIRECTORIO (ESTÁNDAR IMAGEN 3) -->
<div class="modal fade" id="modalImportarEmpleadoPacientes" tabindex="-1" aria-labelledby="modalImportarEmpleadoPacientesLabel" aria-hidden="true" style="z-index: 105160 !important;">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 shadow-lg" style="border-radius: 16px; overflow: hidden;">
            <div class="modal-header text-white px-4 py-3" style="background: var(--md-blue-deep, #0A2A66);">
                <div class="d-flex align-items-center gap-2">
                    <div class="rounded-circle d-flex align-items-center justify-content-center" style="width: 34px; height: 34px; background: rgba(255,255,255,0.15);">
                        <i class="bi bi-building-down text-white fs-6"></i>
                    </div>
                    <div>
                        <h6 class="modal-title fw-bold m-0" id="modalImportarEmpleadoPacientesLabel">Importar Empleado de Municipio / Estado</h6>
                        <span class="text-white-50 small" style="font-size: 0.75rem;">Búsqueda directa en el padrón oficial de la organización</span>
                    </div>
                </div>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-3 p-md-4 bg-light">
                <div class="mb-3">
                    <label class="small fw-bold text-muted mb-1 ps-1">Número de Empleado o Nombre</label>
                    <div class="input-group shadow-xs">
                        <span class="input-group-text bg-white border-end-0 rounded-pill-start ps-3" style="border-color: #cbd5e1;"><i class="bi bi-search text-muted"></i></span>
                        <input type="text" id="iptBuscarEmpleadoPacientes" class="form-control border-start-0 border-end-0 py-2.5 fw-bold" placeholder="Escribe al menos 2 letras o dígitos del No. de empleado..." style="border-color: #cbd5e1;" oninput="debounceBuscarEmpleadoPacientes(this.value)" onkeypress="if(event.key==='Enter') ejecutarBusquedaEmpleadoPacientes()">
                        <button class="btn text-white rounded-pill-end px-3 px-md-4 fw-bold" type="button" style="background: var(--md-blue-deep, #0A2A66);" onclick="ejecutarBusquedaEmpleadoPacientes()">
                            Buscar
                        </button>
                    </div>
                    <div class="form-text small ps-2 text-muted" style="font-size: 0.75rem;">
                        <i class="bi bi-info-circle me-1"></i>Puedes ingresar el número exacto de empleado o su nombre/apellidos para ver sugerencias automáticas.
                    </div>
                </div>

                <div id="resEmpleadoPacientesCont" class="p-2 bg-white rounded-3 border" style="min-height: 200px; max-height: 360px; overflow-y: auto;">
                    <div class="text-center py-5 text-muted">
                        <i class="bi bi-person-badge fs-1 text-secondary opacity-50 d-block mb-2"></i>
                        <span class="fw-bold small">Ingresa un criterio de búsqueda</span>
                        <p class="text-muted small m-0" style="font-size: 0.75rem;">Los empleados y su rama familiar de beneficiarios se desplegarán aquí.</p>
                    </div>
                </div>

                <!-- Aviso Fase Posterior: Rama Familiar Completa -->
                <div class="mt-3 p-2.5 rounded-3 border d-flex align-items-center justify-content-between gap-2" style="background: #f0fdfa; border-color: #ccfbf1 !important;">
                    <div class="d-flex align-items-center gap-2 small" style="color: #0f766e; font-size: 0.75rem;">
                        <i class="bi bi-diagram-3-fill fs-6"></i>
                        <span><b>Rama Familiar:</b> Se muestran el empleado titular y sus beneficiarios asociados. En esta fase puedes importar individualmente a cualquiera de ellos.</span>
                    </div>
                </div>
            </div>
            <div class="modal-footer bg-white border-top px-4 py-2.5 d-flex justify-content-end">
                <button type="button" class="btn btn-sm btn-light border rounded-pill px-4 fw-semibold" data-bs-dismiss="modal">Cerrar</button>
            </div>
        </div>
    </div>
</div>
HTML

render_bottom_nav('pacientes');

print "</body></html>\n";
1;
