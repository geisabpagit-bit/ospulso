#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
binmode STDOUT, ":utf8";
use CGI;
use FindBin;
use File::Spec;
use lib $FindBin::Bin . '/..';
require "$FindBin::Bin/../auth/check_session.pl";
require "$FindBin::Bin/../utils/sub_header.pl";
require "$FindBin::Bin/../utils/sub_sidebar.pl";
require "$FindBin::Bin/../utils/sub_footer.pl";

my $q = CGI->new;
my $session_data = check_session();

if (!$session_data->{session_ok} || $session_data->{role} ne 'Administrador Organizacion') {
    print $q->redirect(-uri => '../index.html');
    exit;
}

my $usuario = $session_data->{usuario};
my $role = $session_data->{role};
my $id_medico = $session_data->{id_usuario} || '';
my $id_empresa = $session_data->{id_empresa} || '';
my $nombre_completo = $session_data->{nombre_completo} || $usuario;

my $org_clues = '';
if ($id_empresa eq '0') {
    $org_clues = 'QTSMP000116';
} else {
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $n_file = File::Spec->catfile($dat_dir, 'negocios.dat');
    if (-e $n_file && open(my $nf, '<:encoding(UTF-8)', $n_file)) {
        <$nf>;
        while (my $line = <$nf>) {
            chomp $line; my @f = split(/\|/, $line, -1);
            if ($f[0] eq $id_empresa) { $org_clues = $f[18] // ''; last; }
        }
        close $nf;
    }
}

if (!$org_clues) {
    print $q->redirect(-uri => 'inicial.pl');
    exit;
}

render_header(
    titulo => 'Gestión de Catálogos (CRUD) - OSPulso',
    role  => $role,
    usuario => $usuario
);

print <<'HTML';
<!-- DataTables CSS -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<!-- DataTables JS (necesario antes de su uso) -->
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>

<style>
    /* Estilos específicos de la vista */
    .catalog-wrapper { padding: 20px; }
    #table-container { min-height: 300px; }
    .table-container th { white-space: nowrap; }
    #dynamic-form-fields .form-group { margin-bottom: 1rem; }
</style>
<div id="wrapper">
HTML

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    id_empresa => $id_empresa,
    pagina_actual => 'gestion_catalogos'
);

print <<"HTML";
    <div id="content-wrapper" class="d-flex flex-column">
        <div id="content">
            <!-- Topbar placeholder si es necesario, asumimos integrado en sub_header o custom -->
            
            <div class="container-fluid catalog-wrapper">
                
                <div class="alert alert-danger shadow-sm border-danger border-2 rounded-4 mb-4" role="alert">
                    <h4 class="alert-heading text-danger fw-bold"><i class="bi bi-exclamation-triangle-fill me-2"></i> Zona de Alto Riesgo - Modificación Directa de Base de Datos</h4>
                    <p class="mb-0">Usted está accediendo a los catálogos en crudo correspondientes a su Tenant (<strong>$org_clues</strong>). Las modificaciones y eliminaciones aquí son inmediatas y definitivas. <strong>ADVERTENCIA:</strong> Cambiar o eliminar un ID (Columna 0) que ya fue usado históricamente en finanzas o pacientes, romperá la integridad de la base de datos de manera irreversible.</p>
                </div>

                <div class="card shadow-sm border-0 rounded-4 mb-4">
                    <div class="card-header bg-white py-3 d-flex flex-column flex-md-row align-items-center justify-content-between border-0 rounded-top-4">
                        <h5 class="m-0 fw-bold" style="color: var(--md-blue-deep);"><i class="bi bi-database-gear me-2 text-primary"></i> Gestión Dinámica de Catálogos</h5>
                        
                        <div class="d-flex align-items-center mt-3 mt-md-0 w-100 w-md-50">
                            <label for="catalogSelector" class="form-label me-3 m-0 text-nowrap fw-semibold text-muted">Seleccionar Catálogo:</label>
                            <select id="catalogSelector" class="form-select form-select-sm shadow-none border-primary">
                                <option value="">Cargando catálogos...</option>
                            </select>
                        </div>
                    </div>
                    
                    <div class="card-body p-4">
                        <div class="d-flex justify-content-end mb-3">
                            <button id="btnNewRecord" class="btn btn-primary btn-sm rounded-3 shadow-sm" style="display: none;" onclick="openModal('add')">
                                <i class="bi bi-plus-lg me-1"></i> Añadir Registro
                            </button>
                        </div>
                        
                        <div class="table-responsive" id="table-container">
                            <div class="text-center text-muted p-5">
                                <i class="bi bi-file-earmark-text fs-1 mb-2 d-block"></i>
                                Seleccione un catálogo para visualizar sus datos.
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Footer -->
        <footer class="sticky-footer bg-white">
            <div class="container my-auto">
                <div class="copyright text-center my-auto text-muted">
                    <span>Ospulso &copy; 2026</span>
                </div>
            </div>
        </footer>
    </div>
</div> <!-- End of Wrapper -->

<!-- Modal CRUD Dinamico -->
<div class="modal fade" id="crudModal" tabindex="-1" aria-hidden="true" data-bs-backdrop="static">
  <div class="modal-dialog modal-dialog-centered modal-lg">
    <div class="modal-content border-0 shadow-lg rounded-4">
      <div class="modal-header bg-light border-0 rounded-top-4">
        <h5 class="modal-title fw-bold" style="color: var(--md-blue-deep);" id="crudModalTitle"><i class="bi bi-pencil-square me-2 text-primary"></i> Registro</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body p-4">
        <form id="crudForm">
            <div id="dynamic-form-fields" class="row"></div>
        </form>
      </div>
      <div class="modal-footer border-0 bg-light rounded-bottom-4">
        <button type="button" class="btn btn-secondary rounded-3" data-bs-dismiss="modal">Cancelar</button>
        <button type="button" class="btn btn-primary rounded-3 px-4 shadow-sm" onclick="saveRecord()">Guardar Cambios</button>
      </div>
    </div>
  </div>
</div>
HTML

print <<'JS';
<script>
    let currentCatalog = '';
    let currentHeaders = [];
    let currentDelimiter = '|';
    let dataTable = null;
    let crudModal = null;
    let modalMode = 'add'; // 'add' or 'edit'

    document.addEventListener("DOMContentLoaded", function() {
        // Fix: Mover modal al body para evitar que quede atrapado en capas inferiores (z-index bug)
        document.body.appendChild(document.getElementById('crudModal'));
        crudModal = new bootstrap.Modal(document.getElementById('crudModal'));
        loadCatalogs();
        
        document.getElementById('catalogSelector').addEventListener('change', function() {
            let val = this.value;
            if (val) {
                loadTableData(val);
            } else {
                document.getElementById('table-container').innerHTML = `<div class="text-center text-muted p-5"><i class="bi bi-file-earmark-text fs-1 mb-2 d-block"></i>Seleccione un catálogo para visualizar sus datos.</div>`;
                document.getElementById('btnNewRecord').style.display = 'none';
            }
        });
    });

    function loadCatalogs() {
        $.post('../api/gestion_catalogos_api.pl', { action: 'list_files' }, function(res) {
            let sel = document.getElementById('catalogSelector');
            if (res.error) {
                Swal.fire('Error', res.msg, 'error');
                sel.innerHTML = `<option value="">Error al cargar</option>`;
                return;
            }
            if (res.files && res.files.length > 0) {
                let opts = '<option value="">-- Seleccione un archivo --</option>';
                res.files.forEach(f => {
                    opts += `<option value="${f}">${f}</option>`;
                });
                sel.innerHTML = opts;
            } else {
                sel.innerHTML = `<option value="">No hay catálogos autorizados disponibles.</option>`;
            }
        }).fail(function() {
            Swal.fire('Error', 'No se pudo conectar con la API', 'error');
        });
    }

    function loadTableData(filename) {
        currentCatalog = filename;
        Swal.fire({ title: 'Cargando datos...', allowOutsideClick: false, didOpen: () => { Swal.showLoading(); } });
        
        $.post('../api/gestion_catalogos_api.pl', { action: 'read', filename: filename }, function(res) {
            if (res.error) {
                Swal.fire('Error', res.msg, 'error');
                return;
            }
            Swal.close();
            
            currentHeaders = res.headers || [];
            currentDelimiter = res.delimiter || '|';
            let rows = res.rows || [];
            
            renderTable(currentHeaders, rows);
            document.getElementById('btnNewRecord').style.display = 'inline-block';
        }).fail(function() {
            Swal.fire('Error', 'Fallo al leer archivo', 'error');
        });
    }

    function renderTable(headers, rows) {
        if (dataTable) {
            dataTable.destroy();
            dataTable = null;
        }
        
        let container = document.getElementById('table-container');
        let thead = '<tr>';
        headers.forEach(h => {
            thead += `<th>${h || 'Columna'}</th>`;
        });
        thead += `<th class="text-center" style="width: 100px;">Acciones</th></tr>`;
        
        let html = `
            <table id="dynamicTable" class="table table-hover table-sm align-middle w-100" style="font-size: 13px;">
                <thead class="table-light text-muted">${thead}</thead>
                <tbody></tbody>
            </table>
        `;
        container.innerHTML = html;
        
        let tableData = rows.map(r => {
            let obj = { _raw: r };
            headers.forEach((h, i) => {
                obj['col_' + i] = r[i] || '';
            });
            return obj;
        });
        
        let columns = headers.map((h, i) => ({ data: 'col_' + i }));
        columns.push({
            data: null,
            orderable: false,
            className: 'text-center',
            render: function(data, type, row) {
                let id = row.col_0;
                let escapedId = id ? id.toString().replace(/'/g, "\\'") : '';
                return `
                    <div class="btn-group btn-group-sm">
                        <button class="btn btn-outline-primary" title="Editar" onclick="openModal('edit', '${escapedId}')"><i class="bi bi-pencil"></i></button>
                        <button class="btn btn-outline-danger" title="Eliminar" onclick="deleteRecord('${escapedId}')"><i class="bi bi-trash"></i></button>
                    </div>
                `;
            }
        });
        
        dataTable = $('#dynamicTable').DataTable({
            data: tableData,
            columns: columns,
            language: { url: 'https://cdn.datatables.net/plug-ins/1.13.4/i18n/es-ES.json' },
            pageLength: 25,
            responsive: true,
            order: [[0, 'asc']]
        });
    }

    function openModal(mode, id = null) {
        modalMode = mode;
        let container = document.getElementById('dynamic-form-fields');
        let html = '';
        
        let rowData = [];
        if (mode === 'edit' && id !== null && dataTable) {
            document.getElementById('crudModalTitle').innerHTML = '<i class="bi bi-pencil-square me-2 text-primary"></i> Editar Registro';
            let allData = dataTable.rows().data().toArray();
            let row = allData.find(r => r.col_0 == id);
            if (row) rowData = row._raw;
        } else {
            document.getElementById('crudModalTitle').innerHTML = '<i class="bi bi-plus-circle me-2 text-primary"></i> Nuevo Registro';
        }
        
        currentHeaders.forEach((h, i) => {
            let val = rowData[i] || '';
            let readonly = (i === 0 && mode === 'edit') ? 'readonly' : ''; // ID column readonly in edit mode
            html += `
                <div class="col-md-6 form-group">
                    <label class="form-label fw-semibold text-muted small">${h || 'Columna ' + i}</label>
                    <input type="text" class="form-control shadow-none" id="input_col_${i}" value="${val}" ${readonly}>
                </div>
            `;
        });
        
        container.innerHTML = html;
        crudModal.show();
    }

    function saveRecord() {
        let newData = [];
        for (let i = 0; i < currentHeaders.length; i++) {
            let el = document.getElementById(`input_col_${i}`);
            if (el) {
                newData.push(el.value.trim());
            } else {
                newData.push('');
            }
        }
        
        if (!newData[0]) {
            Swal.fire('Atención', 'El ID (primera columna) no puede estar vacío.', 'warning');
            return;
        }
        
        Swal.fire({ title: 'Guardando...', allowOutsideClick: false, didOpen: () => { Swal.showLoading(); } });
        
        $.post('../api/gestion_catalogos_api.pl', {
            action: 'save',
            filename: currentCatalog,
            data: JSON.stringify(newData)
        }, function(res) {
            if (res.error) {
                Swal.fire('Error', res.msg, 'error');
            } else {
                crudModal.hide();
                Swal.fire('Éxito', res.msg, 'success');
                loadTableData(currentCatalog);
            }
        }).fail(function() {
            Swal.fire('Error', 'Fallo al procesar solicitud', 'error');
        });
    }

    function deleteRecord(id) {
        Swal.fire({
            title: '¿Eliminar registro?',
            text: `Se eliminará irreversiblemente el registro con ID: ${id}`,
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Sí, eliminar',
            cancelButtonText: 'Cancelar'
        }).then((result) => {
            if (result.isConfirmed) {
                Swal.fire({ title: 'Eliminando...', allowOutsideClick: false, didOpen: () => { Swal.showLoading(); } });
                
                $.post('../api/gestion_catalogos_api.pl', {
                    action: 'delete',
                    filename: currentCatalog,
                    id: id
                }, function(res) {
                    if (res.error) {
                        Swal.fire('Error', res.msg, 'error');
                    } else {
                        Swal.fire('Eliminado', res.msg, 'success');
                        loadTableData(currentCatalog);
                    }
                }).fail(function() {
                    Swal.fire('Error', 'Fallo de conexión', 'error');
                });
            }
        });
    }
</script>
JS

render_footer();
