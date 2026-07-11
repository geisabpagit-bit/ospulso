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

use lib "$FindBin::Bin/..";
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
use utils::db_manager qw(leer_tabla);

my $sd = check_session();
my $q  = $sd->{q};

unless ($sd->{session_ok}) {
    print $q->header(-status => '302 Found', -location => '../index.html');
    exit;
}

my $usuario   = $sd->{usuario};
my $role      = $sd->{role};
my $id_medico = $sd->{id_medico};

# Seguridad Estricta: Sólo Administrador Global
if ($role ne 'Administrador Global') {
    print $q->header(-status => '403 Forbidden');
    print "<h1>Acceso Denegado</h1><p>Esta sección es exclusiva para el Administrador Global.</p>";
    exit;
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $usuario, 
    role        => $role, 
    titulo      => "Administración Global",
    skip_header => 1
);

# Leer Usuarios Actuales (para ver los ejecutivos de ventas)
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $regs = leer_tabla($archivo_usuarios, '!');
my @ejecutivos = ();
if ($regs) {
    foreach my $r (@$regs) {
        next if @$r < 7;
        if ($r->[5] eq 'Ejecutivo Ventas' && $r->[4] eq '1') {
            push @ejecutivos, { id => $r->[0], nombre => $r->[1], correo => $r->[2] };
        }
    }
}

utils::sub_sidebar::render_sidebar(role => $role, usuario => $usuario, pagina_actual => 'admin_global');
print <<HTML;
        <!-- TOPBAR -->
        <header class="bg-medentia-gradient text-white p-4 shadow-sm" style="border-bottom-left-radius: 30px; border-bottom-right-radius: 30px; margin-bottom: 2rem;">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <h2 class="fw-black mb-0"><i class="bi bi-globe me-2"></i>Administrador Global</h2>
                    <p class="text-white-50 small mb-0 mt-1">Gestión de Roles, Servidores y Fuerza de Ventas</p>
                </div>
                <button class="btn btn-danger rounded-pill px-4 fw-bold shadow-sm" onclick="hardResetDB()">
                    <i class="bi bi-exclamation-triangle-fill me-2"></i>Hard Reset DB
                </button>
            </div>
        </header>

        <!-- CONTAINER -->
        <div class="container-fluid px-4 pb-5">
            <div class="row g-4">
                
                <!-- CARD: CREAR EJECUTIVO -->
                <div class="col-12 col-xl-4">
                    <div class="card card-medentia-aura border-0 h-100 shadow-sm">
                        <div class="card-body p-4 d-flex flex-column align-items-center text-center">
                            <div class="kpi-icon-box bg-primary text-white shadow-sm mb-3" style="width: 70px; height: 70px; border-radius: 20px; display: flex; align-items: center; justify-content: center; font-size: 2rem;">
                                <i class="bi bi-person-badge"></i>
                            </div>
                            <h4 class="fw-bold text-dark mb-2">Fuerza de Ventas</h4>
                            <p class="text-muted small mb-4">Registra un nuevo Ejecutivo de Ventas directamente en la tabla usando edición en línea. Ellos tendrán acceso al CRM Comercial.</p>
                            
                            <button type="button" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm w-100 mt-auto" onclick="agregarFilaInline()">
                                <i class="bi bi-plus-circle me-2"></i>Nuevo Ejecutivo
                            </button>
                        </div>
                    </div>
                </div>
                
                <!-- LISTA DE EJECUTIVOS -->
                <div class="col-12 col-xl-8">
                    <div class="card card-medentia-aura border-0 h-100 shadow-sm">
                        <div class="card-header bg-white border-0 pt-4 pb-0 px-4">
                            <h5 class="fw-bold text-dark"><i class="bi bi-list-stars text-primary me-2"></i>Ejecutivos de Ventas Activos</h5>
                        </div>
                        <div class="card-body p-4">
                            <div class="table-responsive">
                                <table class="table table-hover align-middle border-bottom" id="tablaEjecutivos">
                                    <thead class="table-light">
                                        <tr>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Nombre</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Correo</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Contraseña</th>
                                            <th class="small text-muted fw-bold border-0 text-uppercase">Acciones</th>
                                        </tr>
                                    </thead>
                                    <tbody>
HTML

if (@ejecutivos) {
    foreach my $e (@ejecutivos) {
        print <<HTML;
                                        <tr data-id="$$e{id}">
                                            <td class="editable-cell" data-field="nombre">$$e{nombre}</td>
                                            <td class="editable-cell" data-field="correo">$$e{correo}</td>
                                            <td class="editable-cell text-muted" data-field="clave"><em>Oculta (Click para cambiar)</em></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-danger rounded-pill btn-borrar-inline"><i class="bi bi-trash"></i></button>
                                            </td>
                                        </tr>
HTML
    }
} else {
    # DataTables will handle the empty state automatically.
}

print <<HTML;
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    </main><style>
  .editable-cell { cursor: pointer; transition: background-color 0.2s; }
  .editable-cell:hover { background-color: #f1f5f9; outline: 1px dashed #cbd5e1; }
  .editing-input { width: 100%; border: 1px solid #3b82f6; border-radius: 4px; padding: 4px 8px; outline: none; }
  .new-row-highlight { background-color: #f0fdf4 !important; }
</style>

<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>

<script>
    let dtEjecutivos;

    \$(document).ready(function() {
        dtEjecutivos = \$('#tablaEjecutivos').DataTable({
            language: { url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json' },
            dom: '<"p-3 d-flex justify-content-end align-items-center"f>rt<"p-3 d-flex justify-content-between align-items-center"i p>',
            ordering: false,
            paging: false
        });

        // Inline Editing - Click to Edit
        \$('#tablaEjecutivos tbody').on('click', '.editable-cell', function(e) {
            e.stopPropagation();
            if (\$(this).find('input').length > 0) return; // Ya está en modo edición

            const \$cell = \$(this);
            let currentText = \$cell.text().trim();
            if (currentText.includes('Oculta')) currentText = '';

            const field = \$cell.data('field');
            const type = (field === 'clave') ? 'password' : 'text';
            
            const \$input = \$('<input>', {
                type: type,
                class: 'editing-input',
                value: currentText,
                placeholder: (field === 'clave') ? 'Nueva contraseña' : ''
            });

            \$cell.html(\$input);
            \$input.focus();

            // Guardar al perder el foco o Enter
            \$input.on('blur keydown', function(e) {
                if (e.type === 'keydown' && e.which !== 13) return; // Si es tecla y no es Enter, salir
                
                const newValue = \$(this).val().trim();
                const \$row = \$cell.closest('tr');
                const id = \$row.data('id');
                const isNew = \$row.hasClass('new-row-highlight');

                if (isNew) {
                    // Solo restaurar texto si es nuevo (el guardado se hace global)
                    \$cell.html(newValue === '' && field === 'clave' ? '<em>Oculta</em>' : newValue);
                    if(e.type === 'keydown') \$input.trigger('blur'); // Evitar bucle si es Enter
                    return;
                }

                // Guardado API (Update)
                const fd = new FormData();
                fd.append('action', 'edit');
                fd.append('id', id);
                // Si estoy editando un campo, los demás deben permanecer
                const currentName = \$row.find('td[data-field="nombre"]').text().trim();
                const currentEmail = \$row.find('td[data-field="correo"]').text().trim();
                
                let sendName = (field === 'nombre') ? newValue : currentName;
                let sendEmail = (field === 'correo') ? newValue : currentEmail;
                let sendClave = (field === 'clave') ? newValue : '';

                fd.append('nombre', sendName);
                fd.append('correo', sendEmail);
                fd.append('clave', sendClave);

                fetch('../api/crud_ejecutivos_api.pl', { method: 'POST', body: fd })
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        // DataTables internal update
                        let newHtml = field === 'clave' ? '<em class="text-muted">Oculta</em>' : newValue;
                        dtEjecutivos.cell(\$cell).data(newHtml).draw(false);
                    } else {
                        Swal.fire('Error', data.message, 'error');
                        dtEjecutivos.cell(\$cell).data(currentText || '<em class="text-muted">Oculta</em>').draw(false);
                    }
                }).catch(() => {
                    dtEjecutivos.cell(\$cell).data(currentText).draw(false);
                });
            });
        });

        // Borrar Registro (Soft Delete)
        \$('#tablaEjecutivos tbody').on('click', '.btn-borrar-inline', function() {
            const \$row = \$(this).closest('tr');
            const id = \$row.data('id');
            const isNew = \$row.hasClass('new-row-highlight');

            if (isNew) {
                dtEjecutivos.row(\$row).remove().draw();
                return;
            }

            Swal.fire({
                title: '¿Eliminar Ejecutivo?',
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#d33',
                confirmButtonText: 'Sí, borrar'
            }).then((result) => {
                if (result.isConfirmed) {
                    const fd = new FormData();
                    fd.append('action', 'remove');
                    fd.append('id', id);
                    fetch('../api/crud_ejecutivos_api.pl', { method: 'POST', body: fd })
                    .then(r => r.json())
                    .then(data => {
                        if (data.status === 'success') {
                            dtEjecutivos.row(\$row).remove().draw();
                        } else {
                            Swal.fire('Error', data.message, 'error');
                        }
                    });
                }
            });
        });
    });

    // Añadir Fila (Create)
    window.agregarFilaInline = function() {
        const trNode = dtEjecutivos.row.add([
            '<input type="text" class="editing-input form-control-sm" placeholder="Nombre completo">',
            '<input type="text" class="editing-input form-control-sm" placeholder="Correo">',
            '<input type="password" class="editing-input form-control-sm" placeholder="Contraseña">',
            '<button class="btn btn-sm btn-success rounded-pill btn-save-new"><i class="bi bi-check-lg"></i></button> <button class="btn btn-sm btn-outline-secondary rounded-pill btn-borrar-inline"><i class="bi bi-x"></i></button>'
        ]).draw(false).node();

        const \$row = \$(trNode);
        \$row.addClass('new-row-highlight').attr('data-id', 'new');
        \$row.find('td:eq(0)').addClass('editable-cell').attr('data-field', 'nombre');
        \$row.find('td:eq(1)').addClass('editable-cell').attr('data-field', 'correo');
        \$row.find('td:eq(2)').addClass('editable-cell').attr('data-field', 'clave');
        
        \$row.find('.btn-save-new').on('click', function() {
            const btn = \$(this);
            const nombre = \$row.find('td[data-field="nombre"] input').val();
            const correo = \$row.find('td[data-field="correo"] input').val();
            const clave  = \$row.find('td[data-field="clave"] input').val();

            if(!nombre || !correo || !clave) {
                Swal.fire('Atención', 'Todos los campos son obligatorios.', 'warning');
                return;
            }

            btn.prop('disabled', true);

            const fd = new FormData();
            fd.append('action', 'create');
            fd.append('nombre', nombre);
            fd.append('correo', correo);
            fd.append('clave', clave);

            fetch('../api/crud_ejecutivos_api.pl', { method: 'POST', body: fd })
            .then(r => r.json())
            .then(data => {
                if (data.status === 'success') {
                    \$row.removeClass('new-row-highlight');
                    \$row.attr('data-id', data.id);
                    
                    dtEjecutivos.row(\$row).data([
                        nombre,
                        correo,
                        '<em class="text-muted">Oculta (Click para cambiar)</em>',
                        '<button class="btn btn-sm btn-outline-danger rounded-pill btn-borrar-inline"><i class="bi bi-trash"></i></button>'
                    ]).draw(false);
                    
                    Swal.fire('¡Éxito!', 'Ejecutivo guardado', 'success');
                } else {
                    btn.prop('disabled', false);
                    Swal.fire('Error', data.message, 'error');
                }
            }).catch(err => {
                btn.prop('disabled', false);
                Swal.fire('Error', 'Error de red', 'error');
            });
        });
    };

    window.hardResetDB = function() {
        Swal.fire({
            title: '¿Peligro Inminente!',
            text: 'Estás a punto de borrar TODA la base de datos operativa y resetear el sistema. Esto no se puede deshacer. ¿Proceder?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#3085d6',
            confirmButtonText: 'Sí, PURGAR TODO',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                Swal.fire({
                    title: 'Purgando Base de Datos...',
                    allowOutsideClick: false,
                    didOpen: () => { Swal.showLoading(); }
                });

                fetch('../api/hard_reset_db_api.pl')
                .then(res => res.json())
                .then(data => {
                    if (data.status === 'success') {
                        Swal.fire(
                            '¡Base de Datos Purgada!',
                            'El sistema está en blanco. El Administrador Global ha sido reinstaurado.',
                            'success'
                        ).then(() => {
                            window.location.href = '../index.html'; // Obliga a reingresar
                        });
                    } else {
                        Swal.fire('Error', data.message, 'error');
                    }
                })
                .catch(err => {
                    Swal.fire('Error', 'Fallo de red al intentar resetear.', 'error');
                });
            }
        });
    }
</script>
</body>
</html>
HTML

render_bottom_nav('admin_global');
1;
