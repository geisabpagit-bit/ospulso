/**
 * OSPulso - Gestión Dinámica de Catálogos
 * Arquitectura basada en Hooks para escalabilidad y mantenibilidad.
 */

let currentCatalog = '';
let currentHeaders = [];
let currentDelimiter = '|';
let dataTable = null;
let crudModal = null;
let modalMode = 'add'; // 'add' or 'edit'

// --- SISTEMA DE HOOKS (PLUGINS) ---
const CatalogHooks = {
    'medicos': {
        state: { especialidadesOptions: '' },
        preload: function(filename, callback) {
            let espFile = filename.replace('medicos_', 'especialidades_');
            $.post('../api/gestion_catalogos_api.pl', { action: 'read', filename: espFile }, (resEsp) => {
                this.state.especialidadesOptions = '<option value="">-- Seleccionar Especialidad --</option>';
                if (!resEsp.error && resEsp.rows) {
                    resEsp.rows.forEach(r => {
                        let id = r[0] || '';
                        let name = r[1] || 'Sin Nombre';
                        this.state.especialidadesOptions += `<option value="${id}">${name}</option>`;
                    });
                }
                callback();
            }).fail(() => {
                this.state.especialidadesOptions = '<option value="">Error al cargar especialidades</option>';
                callback();
            });
        },
        onCalculateId: function(dataTable) {
            let maxId = 0;
            if (dataTable) {
                let allData = dataTable.rows().data().toArray();
                allData.forEach(r => {
                    let currentId = parseInt(r.col_0, 10);
                    if (!isNaN(currentId) && currentId > maxId) {
                        maxId = currentId;
                    }
                });
            }
            return maxId + 1;
        },
        onRenderField: function(h, i, val, readonly) {
            if (h === '$T_medidespeciali') {
                let html = `
                    <div class="col-md-6 form-group">
                        <label class="form-label fw-semibold text-muted small">${h}</label>
                        <select class="form-select shadow-none select2-enable" id="input_col_${i}" style="width: 100%;">
                            ${this.state.especialidadesOptions}
                        </select>
                    </div>
                `;
                if (val) {
                    setTimeout(() => {
                        let sel = $(`#input_col_${i}`);
                        if (sel.length) {
                            sel.val(val).trigger('change');
                        }
                    }, 50);
                }
                return html;
            }
            return null; // Fallback al render genérico
        }
    }
};

// --- CORE FUNCIONES ---

function getActiveHook() {
    for (let prefix in CatalogHooks) {
        if (currentCatalog.startsWith(prefix + '_')) {
            return CatalogHooks[prefix];
        }
    }
    return null;
}

document.addEventListener("DOMContentLoaded", function() {
    // Mover modal al body para evitar z-index trap
    let modalEl = document.getElementById('crudModal');
    if (modalEl) {
        document.body.appendChild(modalEl);
        crudModal = new bootstrap.Modal(modalEl);
    }
    
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
    
    let hook = getActiveHook();
    if (hook && typeof hook.preload === 'function') {
        hook.preload(filename, () => {
            fetchMainCatalog(filename);
        });
    } else {
        fetchMainCatalog(filename);
    }
}

function fetchMainCatalog(filename) {
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
                    <button class="btn btn-outline-primary btn-mobile-standard" title="Editar" onclick="openModal('edit', '${escapedId}')"><i class="bi bi-pencil"></i></button>
                    <button class="btn btn-outline-danger btn-mobile-standard" title="Eliminar" onclick="deleteRecord('${escapedId}')"><i class="bi bi-trash"></i></button>
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

// Validación Frontend por Nombre de Columna
function getInputTypeAndValidation(headerName) {
    let lower = (headerName || '').toLowerCase();
    if (lower.includes('email') || lower.includes('correo')) return { type: 'email' };
    if (lower.includes('monto') || lower.includes('precio') || lower.includes('costo') || lower.includes('contador')) return { type: 'number', step: 'any' };
    if (lower.includes('fecha')) return { type: 'date' };
    if (lower.includes('telefono') || lower.includes('celular')) return { type: 'tel' };
    return { type: 'text' };
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
    
    let hook = getActiveHook();
    let autoId = '';
    if (mode === 'add' && hook && typeof hook.onCalculateId === 'function') {
        autoId = hook.onCalculateId(dataTable);
    }

    currentHeaders.forEach((h, i) => {
        let val = rowData[i] || '';
        let readonly = (i === 0 && mode === 'edit') ? 'readonly' : '';
        
        if (mode === 'add' && i === 0 && autoId !== '') {
            val = autoId;
            readonly = 'readonly';
        }

        let customRender = null;
        if (hook && typeof hook.onRenderField === 'function') {
            customRender = hook.onRenderField(h, i, val, readonly);
        }

        if (customRender) {
            html += customRender;
        } else {
            let inputProps = getInputTypeAndValidation(h);
            let extras = inputProps.step ? `step="${inputProps.step}"` : '';
            html += `
                <div class="col-md-6 form-group">
                    <label class="form-label fw-semibold text-muted small">${h || 'Columna ' + i}</label>
                    <input type="${inputProps.type}" ${extras} class="form-control shadow-none" id="input_col_${i}" value="${val}" ${readonly} required>
                </div>
            `;
        }
    });
    
    container.innerHTML = html;
    
    // Inicializar Select2 si hay elementos
    if ($('.select2-enable').length > 0 && typeof $.fn.select2 !== 'undefined') {
        $('.select2-enable').select2({
            dropdownParent: $('#crudModal'),
            theme: 'bootstrap-5',
            language: 'es'
        });
    }
    
    crudModal.show();
}

function saveRecord() {
    let form = document.getElementById('crudForm');
    if (!form.checkValidity()) {
        form.reportValidity(); // Dispara la validación nativa HTML5
        return;
    }

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
