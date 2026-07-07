/* SDM Digital - Financial Motor SPA */
const formatter = new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });
let idPacienteGlobal = null;
let idMedicoGlobal = null;
let catalogoMaster = [];
let carritoApp = [];
let windowActiveOS = null;
let currentSaldoTotal = 0;
let pieChartInstance = null;

async function initModuloFinanciero(id, modo, idMed) {
    idPacienteGlobal = id;
    idMedicoGlobal = idMed || 'SISTEMA';
    await cargarHistorialCuentas();
    // Cargar catálogo siempre que se inicialice el módulo, ya que ambos modos pueden usar modales
    await cargarCatalogo();

    
}

async function cargarHistorialCuentas() {
    try {
        const formData = new URLSearchParams();
        formData.append('accion', 'get_historial');
        formData.append('id_paciente', idPacienteGlobal);
        
        const response = await fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: formData, credentials: 'same-origin' });
        if (!response.ok) throw new Error("Error en servidor");
        const res = await response.json();

        // Actualizar KPIs
        currentSaldoTotal = res.saldo || 0;
        if (document.getElementById('ecCargos')) document.getElementById('ecCargos').innerText = formatter.format(res.cargos || 0);
        if (document.getElementById('ecAbonos')) document.getElementById('ecAbonos').innerText = formatter.format(res.abonos || 0);
        
        // Actualizar Footer de Tabla e Impresión
        if (document.getElementById('tfCargos')) document.getElementById('tfCargos').innerText = formatter.format(res.cargos || 0);
        if (document.getElementById('tfAbonos')) document.getElementById('tfAbonos').innerText = formatter.format(res.abonos || 0);
        if (document.getElementById('printDate')) {
            const now = new Date();
            document.getElementById('printDate').innerText = now.toLocaleDateString('es-MX', { day: '2-digit', month: 'long', year: 'numeric' }) + ' ' + now.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
        }

        // Mostrar/Ocultar botón de liquidar
        const btnL = document.getElementById('btnLiquidarTodo');
        if(btnL) btnL.style.display = currentSaldoTotal > 0 ? 'block' : 'none';

        const sl = document.getElementById('ecSaldo');
        if (sl) {
            sl.innerText = formatter.format(res.saldo || 0);
            const card = document.getElementById('ecSaldoCard');
            if (card) {
                // Estilo dinámico basado en saldo
                if (res.saldo > 0) {
                    if (card.classList.contains('kpi-card')) {
                        card.style.borderColor = "#dc2626";
                        sl.style.color = "#dc2626";
                    }
                } else {
                    if (card.classList.contains('kpi-card')) {
                        card.style.borderColor = "#059669";
                        sl.style.color = "#059669";
                    }
                }
            }
        }
        
        actualizarPieChart(res.cargos || 0, res.abonos || 0);

        // Actualizar KPIs de Finanzas Dashboard (si existen en el DOM)
        if (document.getElementById('kpiIngresosTotales')) {
            const eIT = document.getElementById('kpiIngresosTotales');
            const eCC = document.getElementById('kpiCuentasCobrar');
            const eF = document.getElementById('kpiFacturacion');
            const eEC = document.getElementById('kpiEficiencia');

            if (eIT) eIT.innerText = formatter.format(res.cargos || 0);
            if (eCC) eCC.innerText = formatter.format(res.saldo || 0);
            if (eF) eF.innerText = formatter.format(res.cargos || 0); // Igualado temporalmente a cargos
            if (eEC) {
                let eff = res.cargos > 0 ? (res.abonos / res.cargos * 100) : 0;
                eEC.innerText = eff.toFixed(1) + '%';
            }

            const tbody = document.getElementById('tbodyResumenIngresos');
            if (tbody) {
                let html = '';
                const limit = Math.min((res.historial || []).length, 10);
                for(let i=0; i<limit; i++) {
                    const h = res.historial[i];
                    // Si es Abono se asume Pagado. Si es Cargo se asume Pendiente (solo representativo para la demo UI)
                    const isAbono = h.tipo.toLowerCase().includes('abono');
                    const badgeStr = isAbono ? '<span class="badge bg-success bg-opacity-10 text-success border border-success rounded-pill px-3">Pagado</span>' : '<span class="badge bg-warning bg-opacity-10 text-warning border border-warning rounded-pill px-3">Pendiente</span>';
                    
                    html += `<tr>
                        <td class="text-muted">${h.fecha.substring(0, 10)}</td>
                        <td class="fw-bold text-dark">${h.concepto}</td>
                        <td class="text-muted small">OS/2024/${h.id_os.toString().padStart(4,'0')}</td>
                        <td class="fw-bold" style="color: var(--md-blue-deep);">${h.alias || h.id_paciente}</td>
                        <td class="fw-bold text-dark">${formatter.format(h.total)}</td>
                        <td>${badgeStr}</td>
                    </tr>`;
                }
                if(limit === 0) html = '<tr><td colspan="6" class="text-center text-muted py-4">No hay transacciones registradas.</td></tr>';
                tbody.innerHTML = html;
                
                if ($.fn.DataTable) {
                    if ($.fn.DataTable.isDataTable('#tablaResumenIngresos')) {
                        $('#tablaResumenIngresos').DataTable().destroy();
                    }
                    $('#tablaResumenIngresos').DataTable({
                        dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B><"search-box"f>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                        buttons: [
                            { extend: 'copy', text: '<i class="bi bi-clipboard me-1"></i> COPIAR', className: 'btn btn-sm btn-export' },
                            { extend: 'excel', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> EXCEL', className: 'btn btn-sm btn-export' },
                            { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF', className: 'btn btn-sm btn-export' },
                            { extend: 'print', text: '<i class="bi bi-printer me-1"></i> IMPRIMIR', className: 'btn btn-sm btn-export' }
                        ],
                        language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json" },
                        order: [[0, "desc"]],
                        pageLength: 10,
                        responsive: true,
                        destroy: true
                    });
                }
            }

            // Mostrar botón de Cargos y Abonos si hay id_paciente seleccionado
            const btnCargos = document.getElementById('btnCargosAbonos');
            if (btnCargos) {
                if (idPacienteGlobal) {
                    btnCargos.href = 'estado_cuenta.pl?id=' + idPacienteGlobal;
                    btnCargos.style.display = 'inline-block';
                } else {
                    btnCargos.style.display = 'none';
                }
            }

            // Disparar render de gráfica de línea
            if(typeof renderEvolucionIngresosGlobal === 'function') renderEvolucionIngresosGlobal();
        }

        renderHistorial(res.historial || []);
    } catch (e) {
        console.error("Fallo financiero:", e);
    }
}

function actualizarPieChart(cargos, abonos) {
    const canvas = document.getElementById('pieResumenConsolidado');
    if (!canvas) return;
    
    // Update custom HTML legend
    const lc = document.getElementById('legCargos');
    const la = document.getElementById('legAbonos');
    const pv = document.getElementById('pieCenterVal');
    if(lc) lc.innerText = formatter.format(cargos);
    if(la) la.innerText = formatter.format(abonos);
    if(pv) pv.innerText = formatter.format(currentSaldoTotal);

    const ctx = canvas.getContext('2d');
    
    // Metallic Gold (Cargos)
    const gradGold = ctx.createLinearGradient(0, 0, 160, 160);
    gradGold.addColorStop(0, '#fef08a');    // highlight top-left
    gradGold.addColorStop(0.2, '#eab308');  // bright
    gradGold.addColorStop(0.5, '#a16207');  // core
    gradGold.addColorStop(0.8, '#713f12');  // shadow
    gradGold.addColorStop(1, '#fde047');    // rim reflection

    // Metallic Emerald/Teal (Abonos)
    const gradGreen = ctx.createLinearGradient(0, 160, 160, 0);
    gradGreen.addColorStop(0, '#6ee7b7');
    gradGreen.addColorStop(0.2, '#10b981');
    gradGreen.addColorStop(0.5, '#047857');
    gradGreen.addColorStop(0.8, '#064e3b');
    gradGreen.addColorStop(1, '#34d399');

    // Bevel Gradient for Border (3D Extrusion illusion)
    const borderGrad = ctx.createLinearGradient(0, 0, 0, 160);
    borderGrad.addColorStop(0, 'rgba(255, 255, 255, 0.85)'); // light top rim
    borderGrad.addColorStop(0.2, 'rgba(255, 255, 255, 0.3)');
    borderGrad.addColorStop(0.8, 'rgba(0, 0, 0, 0.15)');
    borderGrad.addColorStop(1, 'rgba(0, 0, 0, 0.7)'); // dark bottom rim

    const premium3DPlugin = {
        id: 'premium3DPlugin',
        beforeDraw: (chart) => {
            const chartCtx = chart.ctx;
            chartCtx.save();
            // Deep drop shadow for floating 3D effect
            chartCtx.shadowColor = 'rgba(10, 42, 102, 0.35)';
            chartCtx.shadowBlur = 18;
            chartCtx.shadowOffsetX = 6;
            chartCtx.shadowOffsetY = 12;
        },
        afterDraw: (chart) => {
            chart.ctx.restore();
            // Draw a specular gloss overlay for the glass/metallic look
            if (!chart.getDatasetMeta(0).data[0]) return;
            const chartCtx = chart.ctx;
            const x = chart.chartArea.left + chart.chartArea.width / 2;
            const y = chart.chartArea.top + chart.chartArea.height / 2;
            const outerRadius = chart.getDatasetMeta(0).data[0].outerRadius;
            const innerRadius = chart.getDatasetMeta(0).data[0].innerRadius;
            
            chartCtx.save();
            chartCtx.beginPath();
            chartCtx.arc(x, y, outerRadius, 0, Math.PI * 2);
            chartCtx.arc(x, y, innerRadius, 0, Math.PI * 2, true);
            chartCtx.closePath();
            chartCtx.clip();
            
            // Glossy diagonal reflection
            const gloss = chartCtx.createLinearGradient(x - outerRadius, y - outerRadius, x + outerRadius, y + outerRadius);
            gloss.addColorStop(0, 'rgba(255, 255, 255, 0.55)');
            gloss.addColorStop(0.35, 'rgba(255, 255, 255, 0.05)');
            gloss.addColorStop(0.5, 'rgba(255, 255, 255, 0)');
            gloss.addColorStop(0.7, 'rgba(0, 0, 0, 0.05)');
            gloss.addColorStop(1, 'rgba(0, 0, 0, 0.45)');
            
            chartCtx.fillStyle = gloss;
            chartCtx.fill();
            chartCtx.restore();
        }
    };

    if (pieChartInstance) {
        pieChartInstance.data.datasets[0].data = [cargos, abonos];
        pieChartInstance.update();
    } else {
        pieChartInstance = new Chart(ctx, {
            type: 'doughnut',
            plugins: [premium3DPlugin],
            data: {
                labels: ['Cargos', 'Abonos'],
                datasets: [{
                    data: [cargos, abonos],
                    backgroundColor: [gradGold, gradGreen],
                    borderColor: [borderGrad, borderGrad],
                    borderWidth: 4,
                    hoverOffset: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '72%',
                layout: { padding: 12 },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        backgroundColor: 'rgba(10, 42, 102, 0.9)',
                        titleFont: { size: 14, family: "'Plus Jakarta Sans', sans-serif" },
                        bodyFont: { size: 13, weight: 'bold', family: "'Plus Jakarta Sans', sans-serif" },
                        padding: 12,
                        cornerRadius: 8,
                        boxPadding: 6,
                        callbacks: {
                            label: function(context) {
                                return ' ' + context.label + ': ' + formatter.format(context.raw);
                            }
                        }
                    }
                }
            }
        });
    }
}

function renderHistorial(historial) {
    // Intentar renderizar en modo Tabla
    const tb = document.getElementById('tbEdoCuenta');
    if (tb) {
        if ($.fn.DataTable && $.fn.DataTable.isDataTable('#dtEdoCuenta')) {
            $('#dtEdoCuenta').DataTable().destroy();
        }
        tb.innerHTML = historial.length ? '' : '<tr><td colspan="6" class="text-center py-5 text-muted fw-bold">Sin movimientos.</td></tr>';
        historial.forEach(m => {
            const isC = m.tipo === 'Cargo';
            const display_os = m.alias ? m.alias : m.id_os;
            tb.insertAdjacentHTML('beforeend', `
                <tr>
                    <td class="ps-4 small text-primary fw-bold" title="OS: ${m.id_os}">${display_os}</td>
                    <td class="small text-muted fw-bold">${m.fecha}</td>
                    <td><div class="d-flex align-items-center gap-3">
                        <div class="btn btn-sm ${isC?'btn-light text-danger':'btn-light text-success'} rounded-3" style="width:35px; height:35px; display:flex; align-items:center; justify-content:center;">
                            <i class="bi ${isC?'bi-receipt':'bi-cash-coin'}"></i>
                        </div>
                        <span class="fw-bold text-dark small">${m.concepto}</span>
                    </div></td>
                    <td class="text-end fw-black ${isC?'text-danger':''}">${isC ? formatter.format(m.total) : '-'}</td>
                    <td class="text-end fw-black ${!isC?'text-success':''}">${!isC ? formatter.format(m.total) : '-'}</td>
                    <td class="text-center">
                        <div class="d-flex gap-1 justify-content-center">
                            <button onclick="imprimirOS('${m.id_os}')" title="Imprimir Recibo" class="btn btn-sm btn-outline-dark border-0"><i class="bi bi-printer"></i></button>
                            ${isC ? `<button onclick="abrirModalAbonoContextual(${m.total}, '${m.concepto.replace(/'/g, "\\'")}', '${m.id_os}', '${m.alias || ''}')" title="Abonar a este ítem" class="btn btn-sm btn-outline-success border-0"><i class="bi bi-cash-coin"></i></button>` : ''}
                            ${isC ? `<button onclick="abrirModalCargoConOS('${m.id_os}', '${m.alias || ''}')" title="Agregar ítem a esta OS" class="btn btn-sm btn-outline-primary border-0"><i class="bi bi-folder-plus"></i></button>` : ''}
                            <button onclick="prepararEdicion('${m.id_mov}', '${m.concepto.replace(/'/g, "\\'")}', '${m.total}')" class="btn btn-sm btn-outline-secondary border-0"><i class="bi bi-pencil"></i></button>
                            <button onclick="eliminarMovimiento('${m.id_mov}')" class="btn btn-sm btn-outline-danger border-0"><i class="bi bi-trash"></i></button>
                        </div>
                    </td>
                </tr>`);
        });
        
        if (historial.length && $.fn.DataTable) {
            $('#dtEdoCuenta').DataTable({
                destroy: true,
                language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json" },
                order: [[1, "desc"]],
                paging: true,
                info: true,
                searching: true,
                responsive: true
            });
        }
    }

    // Intentar renderizar en modo Bento (Agrupado por OS/Alias)
    const container = document.getElementById('bentoTransactionsContainer');
    if (container) {
        container.innerHTML = historial.length ? '' : '<div class="p-5 text-center text-muted fw-bold small">No se encontraron movimientos registrados.</div>';
        
        const grouped = {};
        historial.forEach(m => {
            const display_os = m.alias ? m.alias : m.id_os;
            if (!grouped[display_os]) grouped[display_os] = [];
            grouped[display_os].push(m);
        });

        Object.keys(grouped).forEach(os_key => {
            const txs = grouped[os_key];
            const real_os = txs[0].id_os;
            const alias = txs[0].alias || '';
            
            let htmlTxs = txs.map(m => {
                const isC = m.tipo === 'Cargo';
                return `
                <div class="d-flex justify-content-between align-items-center p-2 rounded-3 border border-slate-100" style="background: var(--md-white-clinical);">
                    <div class="d-flex align-items-center gap-3">
                        <div class="rounded-circle d-flex align-items-center justify-content-center shadow-sm ${isC?'bg-danger-subtle text-danger':'bg-success-subtle text-success'}" style="width:32px; height:32px;">
                            <i class="bi ${isC?'bi-receipt':'bi-cash-coin'}" style="font-size:1rem;"></i>
                        </div>
                        <div>
                            <p class="mb-0 fw-bold text-dark lh-1" style="font-size: 0.85rem;">${m.concepto}</p>
                            <small class="text-muted" style="font-size: 0.65rem;">${m.fecha}</small>
                        </div>
                    </div>
                    <div class="text-end d-flex align-items-center gap-2">
                        <span class="fw-black ${isC?'text-dark':'text-success'}">${isC?'':'-'}${formatter.format(m.total)}</span>
                        <div class="dropdown">
                            <button class="btn btn-sm btn-link text-muted p-0 ms-1" data-bs-toggle="dropdown"><i class="bi bi-three-dots-vertical"></i></button>
                            <ul class="dropdown-menu dropdown-menu-end shadow-sm border-0" style="border-radius: 12px; font-size: 0.85rem;">
                                ${isC ? `<li><a class="dropdown-item" href="#" onclick="abrirModalAbonoContextual(${m.total}, '${m.concepto.replace(/'/g, "\\'")}', '${m.id_os}', '${m.alias || ''}')"><i class="bi bi-cash-coin me-2 text-success"></i>Abonar</a></li>` : ''}
                                <li><a class="dropdown-item" href="#" onclick="prepararEdicion('${m.id_mov}', '${m.concepto.replace(/'/g, "\\'")}', '${m.total}')"><i class="bi bi-pencil me-2 text-muted"></i>Editar</a></li>
                                <li><hr class="dropdown-divider"></li>
                                <li><a class="dropdown-item text-danger" href="#" onclick="eliminarMovimiento('${m.id_mov}')"><i class="bi bi-trash me-2"></i>Eliminar</a></li>
                            </ul>
                        </div>
                    </div>
                </div>`;
            }).join('');

            container.insertAdjacentHTML('beforeend', `
                <div class="bento-card p-3 border shadow-sm mb-3 animate__animated animate__fadeInUp" style="border-radius:1.5rem;">
                    <div class="d-flex flex-column flex-sm-row justify-content-between align-items-sm-center gap-2 mb-3">
                        <span class="badge bg-primary-subtle text-primary border-0 rounded-pill px-3 py-2 fw-bold text-start text-wrap lh-sm" style="font-size:0.8rem; letter-spacing: -0.2px;">
                            <i class="bi bi-folder2-open me-2"></i>${os_key}
                        </span>
                        <div class="d-flex gap-2">
                            <button onclick="imprimirOS('${real_os}')" class="btn btn-sm btn-light border shadow-sm rounded-pill px-3 py-1 fw-bold" style="font-size: 0.75rem;"><i class="bi bi-printer text-dark me-1"></i>Imprimir</button>
                            <button onclick="abrirModalCargoConOS('${real_os}', '${alias}')" class="btn btn-sm btn-primary shadow-sm rounded-pill px-3 py-1 fw-bold" style="font-size: 0.75rem;"><i class="bi bi-cart-plus me-1"></i>Agregar</button>
                        </div>
                    </div>
                    <div class="d-flex flex-column gap-2">
                        ${htmlTxs}
                    </div>
                </div>`);
        });
    }
}

async function cargarCatalogo() {
    try {
        const res = await fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: new URLSearchParams({accion: 'get_catalogo'}), credentials: 'same-origin' });
        const data = await res.json();
        catalogoMaster = [...(data.servicios||[]), ...(data.productos||[])];
        renderCatalogoGUI();
    } catch(e) {}
}

function renderCatalogoGUI(f = '') {
    const tbody = document.getElementById('tablaCatalogo'); if(!tbody) return;
    tbody.innerHTML = '';
    const filtered = catalogoMaster.filter(i => (i.nombre||'').toLowerCase().includes(f.toLowerCase()));
    
    filtered.forEach(it => {
        tbody.insertAdjacentHTML('beforeend', `
            <tr style="cursor:pointer;" onclick="agregarAlCarrito('${it.id}')" class="hover-shadow">
                <td class="fw-bold text-dark small" title="${it.nombre}">${it.nombre}</td>
                <td class="text-primary fw-bold text-end small">${formatter.format(it.precio)}</td>
                <td class="text-center" style="width: 40px;">
                    <div class="btn btn-sm btn-primary rounded-circle shadow-sm d-flex align-items-center justify-content-center" style="width:24px; height:24px; padding:0; border:none;"><i class="bi bi-plus" style="font-size:1rem;"></i></div>
                </td>
            </tr>`);
    });
}

function filtrarCatalogo() { renderCatalogoGUI(document.getElementById('buscadorCatalogo').value); }

function agregarCargoManual() {
    const n = document.getElementById('manual_nombre'), p = document.getElementById('manual_precio');
    if(!n.value || !p.value) return Swal.fire("Aviso", "Indique descripción y precio", "warning");
    const id = 'MAN-'+Date.now();
    carritoApp.push({ id, nombre: n.value, precio: parseFloat(p.value), cantidad: 1 });
    n.value = ''; p.value = ''; refrescarGUICarrito();
}

function agregarAlCarrito(id) {
    const it = catalogoMaster.find(x => x.id === id); if(!it) return;
    let ex = carritoApp.find(x => x.id === id);
    if(ex) ex.cantidad++; else carritoApp.push({ ...it, precio: parseFloat(it.precio), cantidad: 1 });
    refrescarGUICarrito();
}

function refrescarGUICarrito() {
    const uli = document.getElementById('listaCarrito'); if(!uli) return;
    uli.innerHTML = carritoApp.length === 0 ? '<div class="text-center p-10 text-slate-300 font-bold small">El carrito está vacío.</div>' : '';
    let total = 0;
    carritoApp.forEach((c, i) => {
        const st = c.precio * c.cantidad; total += st;
        uli.insertAdjacentHTML('beforeend', `
            <div class="bg-slate-50 p-3 rounded-2xl border border-slate-100 d-flex flex-column flex-sm-row justify-content-between align-items-sm-center gap-2">
                <div class="lh-sm flex-grow-1">
                    <span class="fw-black text-slate-800 d-block mb-1 text-xs uppercase">${c.nombre}</span>
                    <small class="text-slate-400 fw-bold">${formatter.format(c.precio)} c/u</small>
                </div>
                <div class="d-flex align-items-center justify-content-between justify-content-sm-end gap-3 flex-wrap">
                    <div class="d-flex align-items-center gap-2 bg-white rounded-pill px-2 py-1 border shadow-sm">
                        <button class="btn btn-sm btn-light rounded-circle p-1 d-flex align-items-center justify-content-center" style="width: 24px; height: 24px;" onclick="updateCartItemQty(${i}, -1)"><i class="bi bi-dash"></i></button>
                        <span class="fw-bold px-2 text-sm">${c.cantidad}</span>
                        <button class="btn btn-sm btn-light rounded-circle p-1 d-flex align-items-center justify-content-center" style="width: 24px; height: 24px;" onclick="updateCartItemQty(${i}, 1)"><i class="bi bi-plus"></i></button>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <span class="fw-black text-primary d-inline-block text-end" style="min-width: 70px;">${formatter.format(st)}</span>
                        <button class="btn btn-sm btn-white text-danger border shadow-sm rounded-xl p-2" onclick="removeCartItem(${i})"><i class="bi bi-trash"></i></button>
                    </div>
                </div>
            </div>`);
    });
    
    const iva = document.getElementById('checkFactura') && document.getElementById('checkFactura').checked ? (total * 0.16) : 0;
    const tv = document.getElementById('carritoTotal');
    if (tv) tv.innerText = formatter.format(total + iva);
}

function removeCartItem(idx) { carritoApp.splice(idx, 1); refrescarGUICarrito(); }

function updateCartItemQty(idx, delta) {
    if (carritoApp[idx].cantidad + delta <= 0) {
        Swal.fire({
            title: '¿Eliminar ítem?',
            text: "¿Deseas quitar este concepto del cargo?",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc2626',
            cancelButtonColor: '#64748b',
            confirmButtonText: 'Sí, quitar'
        }).then((result) => {
            if (result.isConfirmed) {
                removeCartItem(idx);
            }
        });
    } else {
        carritoApp[idx].cantidad += delta;
        refrescarGUICarrito();
    }
}

async function procesarCarrito() {
    if(carritoApp.length === 0) return;
    const btn = document.getElementById('btnProcesarCargo');
    const oldText = btn.innerHTML;
    btn.disabled = true; btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> PROCESANDO...';
    
    try {
        const fd = new URLSearchParams();
        fd.append('accion', 'add_cargo');
        fd.append('id_paciente', idPacienteGlobal);
        fd.append('id_medico', idMedicoGlobal);
        fd.append('id_os_manual', windowActiveOS || '');
        const cf = document.getElementById('checkFactura');
        fd.append('aplica_iva', (cf && cf.checked) ? '1' : '0');
        const aliasIn = document.getElementById('alias_os_cargo');
        fd.append('alias', aliasIn ? aliasIn.value : '');
        const apIn = document.querySelector('input[name="aplica_para"]:checked');
        fd.append('aplica_para', apIn ? apIn.value : '');
        fd.append('payload', JSON.stringify(carritoApp));
        const res = await fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' });
        const json = await res.json();
        if(json.success) {
            const m = bootstrap.Modal.getInstance(document.getElementById('modalCargo'));
            if (m) m.hide();
            await cargarHistorialCuentas();
            Swal.fire("Éxito", "Cargo registrado correctamente", "success");
        }
    } catch(e) { console.error(e); }
    btn.disabled = false; btn.innerHTML = oldText;
}

async function abrirModalAbono() {
    const modalEl = document.getElementById('modalAbono');
    if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
    document.getElementById('modalAbonoTitle').innerText = 'Registrar Abono Global';
    document.getElementById('montoAbono').value = '';
    document.getElementById('notasAbono').value = '';
    const aliasIn = document.getElementById('alias_os_abono');
    if (aliasIn) {
        aliasIn.value = 'ABONO GLOBAL';
        aliasIn.setAttribute('disabled', 'disabled');
        aliasIn.setAttribute('readonly', 'readonly');
    }
    const m = bootstrap.Modal.getOrCreateInstance(modalEl);
    m.show();
}

function abrirModalAbonoContextual(monto, concepto, id_os, alias) {
    const modalEl = document.getElementById('modalAbono');
    if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
    document.getElementById('modalAbonoTitle').innerHTML = `<i class="bi bi-cash-coin me-2"></i>Liquidar: <span class="text-success">${concepto}</span>`;
    document.getElementById('montoAbono').value = monto;
    document.getElementById('notasAbono').value = `Pago de: ${concepto} (OS: ${id_os})`;
    const aliasIn = document.getElementById('alias_os_abono');
    if (aliasIn) {
        aliasIn.value = alias || id_os;
        aliasIn.setAttribute('disabled', 'disabled');
        aliasIn.setAttribute('readonly', 'readonly');
    }
    const m = bootstrap.Modal.getOrCreateInstance(modalEl);
    m.show();
}

function liquidarSaldoTotal() {
    if(currentSaldoTotal <= 0) return;
    const modalEl = document.getElementById('modalAbono');
    if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
    document.getElementById('modalAbonoTitle').innerHTML = `<i class="bi bi-wallet2 me-2"></i>Liquidaci&oacute;n de Cuenta Total`;
    document.getElementById('montoAbono').value = currentSaldoTotal;
    document.getElementById('notasAbono').value = `Liquidaci&oacute;n total de saldo pendiente.`;
    const m = bootstrap.Modal.getOrCreateInstance(modalEl);
    m.show();
}

function procesarAbono() {
    const val = document.getElementById('montoAbono').value;
    const met = document.getElementById('metodoAbono').value;
    const not = document.getElementById('notasAbono').value;
    
    if(!val || parseFloat(val) <= 0) return Swal.fire("Atención", "Ingrese un monto válido", "warning");

    const fd = new FormData();
    fd.append('accion', 'add_abono');
    fd.append('id_paciente', idPacienteGlobal);
    fd.append('id_medico', idMedicoGlobal);
    fd.append('monto', val);
    fd.append('metodo', met);
    fd.append('notas', not);
    
    const aliasIn = document.getElementById('alias_os_abono');
    fd.append('alias', aliasIn ? aliasIn.value : '');

    fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' })
        .then(r => r.json())
        .then(data => {
            if(data.success) {
                Swal.fire("Éxito", "Abono registrado correctamente", "success");
                bootstrap.Modal.getInstance(document.getElementById('modalAbono')).hide();
                cargarHistorialCuentas(); // Refresco inmediato
            }
        });
}

function imprimirEstadoCuenta() {
    const rows = document.querySelectorAll('#tbEdoCuenta tr');
    if(rows.length === 0 || (rows.length === 1 && rows[0].innerText.includes('Sin movimientos'))) {
        window.print(); return;
    }
    
    const osMap = new Map();
    rows.forEach(r => {
        const td = r.querySelector('td.ps-4');
        if(td) {
            const id_os = td.getAttribute('title').replace('OS: ', '').trim();
            const display = td.innerText.trim();
            if(id_os) osMap.set(id_os, display);
        }
    });
    
    if(osMap.size === 0) {
        window.print(); return;
    }
    
    let optionsHtml = `<option value="ALL">🖨️ Historial Completo del Paciente</option>`;
    osMap.forEach((display, id_os) => {
        optionsHtml += `<option value="${id_os}">${display} (${id_os})</option>`;
    });
    
    Swal.fire({
        title: 'Reporte de Estado de Cuenta',
        html: `
            <p class="text-muted small mb-3">Selecciona si deseas imprimir todo el estado de cuenta, o aislar un agrupamiento específico (OS / Alias).</p>
            <select id="sw_print_os" class="form-select form-select-lg rounded-3 shadow-sm border-0 bg-light fw-bold text-dark">
                ${optionsHtml}
            </select>
        `,
        showCancelButton: true,
        confirmButtonText: '<i class="bi bi-printer me-2"></i>Imprimir Reporte',
        confirmButtonColor: '#174975',
        cancelButtonText: 'Cancelar'
    }).then((result) => {
        if(result.isConfirmed) {
            const selection = document.getElementById('sw_print_os').value;
            if(selection === 'ALL') {
                window.print();
            } else {
                imprimirOS(selection);
            }
        }
    });
}

function imprimirOS(id_os) {
    const rows = document.querySelectorAll('#tbEdoCuenta tr');
    let hasMatch = false;
    rows.forEach(r => {
        const td = r.querySelector('td.ps-4');
        if(td) {
            const rowOs = td.getAttribute('title').replace('OS: ', '').trim();
            if(rowOs !== id_os) {
                r.classList.add('d-none-print');
            } else {
                r.classList.remove('d-none-print');
                hasMatch = true;
            }
        }
    });
    
    if(hasMatch) {
        window.print();
    } else {
        Swal.fire("Aviso", "No se encontraron movimientos para imprimir en esta OS.", "info");
    }
    
    rows.forEach(r => r.classList.remove('d-none-print'));
}

function eliminarMovimiento(id) {
    Swal.fire({ title: '¿Eliminar registro?', text: "Esta acción no se puede deshacer.", icon: 'warning', showCancelButton: true, confirmButtonColor: '#dc2626', cancelButtonColor: '#64748b', confirmButtonText: 'Sí, borrar' }).then((result) => {
        if (result.isConfirmed) {
            fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: new URLSearchParams({accion: 'delete_movimiento', id_mov: id}), credentials: 'same-origin' })
            .then(r => r.json()).then(res => { if(res.success) { cargarHistorialCuentas(); Swal.fire("Eliminado", "El registro ha sido borrado", "success"); } });
        }
    });
}

function prepararEdicion(id, concepto, total) {
    Swal.fire({
        title: 'Modificar Registro',
        html: `
            <div class="text-start mb-3"><label class="small fw-bold text-muted uppercase">Concepto</label><input id="sw_concepto" class="form-control rounded-3" value="${concepto}"></div>
            <div class="text-start mb-3"><label class="small fw-bold text-muted uppercase">Monto Final</label><input id="sw_monto" class="form-control rounded-3" type="number" step="0.01" value="${total}"></div>
        `,
        showCancelButton: true, confirmButtonText: 'Actualizar', confirmButtonColor: '#174975',
        preConfirm: () => {
            return { c: document.getElementById('sw_concepto').value, m: document.getElementById('sw_monto').value };
        }
    }).then((r) => {
        if (r.isConfirmed) {
            const fd = new URLSearchParams({ accion: 'update_movimiento', id_mov: id, concepto: r.value.c, monto: r.value.m });
            fetch('../api/estado_cuenta_api.pl', { method: 'POST', body: fd, credentials: 'same-origin' }).then(r => r.json()).then(res => { 
                if(res.success) { cargarHistorialCuentas(); Swal.fire("Actualizado", "Registro modificado con éxito", "success"); } 
            });
        }
    });
}

/** 
 * INTERFAZ DE ACTIVACIÓN DE MODALES
 * Estas funciones son llamadas desde views/estado_cuenta.pl
 */

function abrirModalCargo() {
    windowActiveOS = null;
    document.getElementById('modalCargoTitle').innerHTML = '<i class="bi bi-cart-plus me-3"></i>Nueva Orden de Servicio';
    carritoApp = [];
    refrescarGUICarrito();
    const aliasIn = document.getElementById('alias_os_cargo');
    if (aliasIn) {
        aliasIn.value = '';
        aliasIn.removeAttribute('disabled');
        aliasIn.removeAttribute('readonly');
    }
    const el = document.getElementById('modalCargo');
    if (!el) return console.error("Modal Cargo no encontrado");
    const m = new bootstrap.Modal(el);
    m.show();
}

function abrirModalCargoConOS(id_os, alias) {
    windowActiveOS = id_os;
    document.getElementById('modalCargoTitle').innerHTML = `<i class="bi bi-plus-circle-dotted me-3"></i>Agregar a OS: <span class="text-primary">${id_os}</span>`;
    carritoApp = [];
    refrescarGUICarrito();
    const aliasIn = document.getElementById('alias_os_cargo');
    if (aliasIn) {
        aliasIn.value = alias || id_os;
        aliasIn.setAttribute('disabled', 'disabled');
        aliasIn.setAttribute('readonly', 'readonly');
    }
    const el = document.getElementById('modalCargo');
    if (!el) return console.error("Modal Cargo no encontrado");
    const m = new bootstrap.Modal(el);
    m.show();
}

let lineChartInstance = null;
function renderEvolucionIngresosGlobal() {
    const canvas = document.getElementById("lineEvolucionIngresos");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    
    if (lineChartInstance) lineChartInstance.destroy();

    const gradBlue = ctx.createLinearGradient(0, 0, 0, 250);
    gradBlue.addColorStop(0, "rgba(59, 130, 246, 0.4)");
    gradBlue.addColorStop(1, "rgba(59, 130, 246, 0.0)");

    const gradGold = ctx.createLinearGradient(0, 0, 0, 250);
    gradGold.addColorStop(0, "rgba(234, 179, 8, 0.4)");
    gradGold.addColorStop(1, "rgba(234, 179, 8, 0.0)");

    lineChartInstance = new Chart(ctx, {
        type: "line",
        data: {
            labels: ["Ene", "Feb", "Mar", "Abr", "May", "Jun"],
            datasets: [
                {
                    label: "Este A\xF1o",
                    data: [80000, 150000, 220000, 190000, 260000, 290000],
                    borderColor: "#2563eb",
                    backgroundColor: gradBlue,
                    borderWidth: 3,
                    pointBackgroundColor: "#fff",
                    pointBorderColor: "#2563eb",
                    pointBorderWidth: 2,
                    pointRadius: 4,
                    pointHoverRadius: 6,
                    fill: true,
                    tension: 0.4
                },
                {
                    label: "A\xF1o Anterior",
                    data: [60000, 110000, 130000, 120000, 170000, 180000],
                    borderColor: "#eab308",
                    backgroundColor: gradGold,
                    borderWidth: 3,
                    borderDash: [5, 5],
                    pointBackgroundColor: "#fff",
                    pointBorderColor: "#eab308",
                    pointBorderWidth: 2,
                    pointRadius: 4,
                    pointHoverRadius: 6,
                    fill: true,
                    tension: 0.4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    position: "top",
                    align: "start",
                    labels: {
                        usePointStyle: true,
                        boxWidth: 8,
                        font: { family: "sans-serif", weight: "bold", size: 11 }
                    }
                }
            },
            scales: {
                x: { grid: { display: false } },
                y: { grid: { color: "rgba(0,0,0,0.04)" } }
            }
        }
    });
}

window.renderCxC = async function() {
    try {
        const tbody = document.getElementById('tbodyCxC');
        if (tbody) tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted"><div class="spinner-border text-primary spinner-border-sm me-2"></div>Cargando datos...</td></tr>';
        
        const res = await fetch('../api/finanzas_api.pl', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: new URLSearchParams({ action: 'get_cxc' })
        });
        const data = await res.json();
        
        if (data.success && tbody) {
            let html = '';
            data.data.forEach(p => {
                const badge = p.saldo_pendiente > 0 ? '<span class="badge bg-danger bg-opacity-10 text-danger border border-danger rounded-pill px-3">Deuda Activa</span>' : '';
                html += `<tr>
                    <td class="fw-bold" style="color: var(--md-blue-deep);"><i class="bi bi-person-circle me-2 text-muted"></i>${p.nombre}</td>
                    <td class="text-muted small">${p.ultimo_movimiento.substring(0, 10) || 'N/A'}</td>
                    <td class="text-muted">${formatter.format(p.cargos_acumulados)}</td>
                    <td class="text-success">${formatter.format(p.abonos_acumulados)}</td>
                    <td class="fw-bold text-danger">${formatter.format(p.saldo_pendiente)}</td>
                    <td>
                        ${badge}
                        <a href="estado_cuenta.pl?id=${p.id_paciente}" class="btn btn-sm btn-light ms-2 shadow-sm rounded-pill fw-bold text-primary" title="Ir al estado de cuenta">Cobrar <i class="bi bi-arrow-right-short"></i></a>
                    </td>
                </tr>`;
            });
            
            if (data.data.length === 0) {
                html = '<tr><td colspan="6" class="text-center text-muted py-4"><i class="bi bi-check-circle text-success fs-3 d-block mb-2"></i>No hay pacientes con cuentas por cobrar. ¡Excelente!</td></tr>';
            }
            
            tbody.innerHTML = html;
            
            // Inicializar DataTable
            if ($.fn.DataTable) {
                if ($.fn.DataTable.isDataTable('#tablaCxC')) {
                    $('#tablaCxC').DataTable().destroy();
                }
                $('#tablaCxC').DataTable({
                    dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B><"search-box"f>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                    buttons: [
                        { extend: 'copy', text: '<i class="bi bi-clipboard me-1"></i> COPIAR', className: 'btn btn-sm btn-export' },
                        { extend: 'excel', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> EXCEL', className: 'btn btn-sm btn-export' },
                        { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF', className: 'btn btn-sm btn-export' },
                        { extend: 'print', text: '<i class="bi bi-printer me-1"></i> IMPRIMIR', className: 'btn btn-sm btn-export' }
                    ],
                    language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json" },
                    order: [[4, "desc"]], // Ordenar por saldo pendiente mayor a menor
                    pageLength: 10,
                    responsive: true,
                    destroy: true
                });
            }
        }
    } catch (error) {
        console.error("Error cargando CxC", error);
        const tbody = document.getElementById('tbodyCxC');
        if (tbody) tbody.innerHTML = '<tr><td colspan="6" class="text-center text-danger py-4">Error al cargar cuentas por cobrar.</td></tr>';
    }
}

// --- Módulo Gastos ---
let catGastos = [], subcatGastos = [], subcat3Gastos = [];
let categoriasGastosCargadas = false;

async function cargarCategoriasGastos() {
    if (categoriasGastosCargadas) return;
    try {
        const res = await fetch('../api/finanzas_api.pl', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: new URLSearchParams({ action: 'get_categorias_gastos' })
        });
        const data = await res.json();
        if (data.success) {
            catGastos = data.categorias;
            subcatGastos = data.subcategorias;
            subcat3Gastos = data.subcategorias3;
            categoriasGastosCargadas = true;
            
            const catSelect = document.getElementById('cat_gasto');
            if (catSelect) {
                catSelect.innerHTML = '<option value="">Seleccione...</option>';
                catGastos.forEach(c => {
                    catSelect.innerHTML += `<option value="${c.id}">${c.nombre}</option>`;
                });
            }
        }
    } catch (e) { console.error("Error cargando categorías de gastos", e); }
}

window.filtrarSubcategorias = function() {
    const idCat = document.getElementById('cat_gasto').value;
    const subcatSelect = document.getElementById('subcat_gasto');
    const subcat3Select = document.getElementById('subcat3_gasto');
    
    subcatSelect.innerHTML = '<option value="">Seleccione...</option>';
    subcat3Select.innerHTML = '<option value="">Seleccione...</option>';
    
    if (!idCat) return;
    
    const filtradas = subcatGastos.filter(s => s.id_cat === idCat);
    filtradas.forEach(s => {
        subcatSelect.innerHTML += `<option value="${s.id}">${s.nombre}</option>`;
    });
}

window.filtrarSubcategorias3 = function() {
    const idSub = document.getElementById('subcat_gasto').value;
    const subcat3Select = document.getElementById('subcat3_gasto');
    
    subcat3Select.innerHTML = '<option value="">Seleccione...</option>';
    if (!idSub) return;
    
    const filtradas = subcat3Gastos.filter(s => s.id_subcat === idSub);
    filtradas.forEach(s => {
        subcat3Select.innerHTML += `<option value="${s.id}">${s.nombre}</option>`;
    });
}

window.renderGastos = async function() {
    try {
        const tbody = document.getElementById('tbodyGastos');
        if (tbody) tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted"><div class="spinner-border text-primary spinner-border-sm me-2"></div>Cargando...</td></tr>';
        
        const res = await fetch('../api/finanzas_api.pl', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: new URLSearchParams({ action: 'get_gastos' })
        });
        const data = await res.json();
        
        if (data.success && tbody) {
            let html = '';
            data.data.forEach(g => {
                html += `<tr>
                    <td class="text-muted small">${g.fecha || ''}</td>
                    <td>
                        <span class="fw-bold" style="color: var(--md-blue-deep);">${g.cat_nombre}</span><br>
                        <small class="text-muted">${g.subcat_nombre} > ${g.subcat3_nombre}</small>
                    </td>
                    <td class="fw-bold text-dark">${g.concepto}</td>
                    <td class="fw-bold text-danger">${formatter.format(g.monto)}</td>
                    <td>
                        <button class="btn btn-sm btn-outline-danger rounded-pill" onclick="eliminarGasto('${g.id_gasto}')"><i class="bi bi-trash"></i></button>
                    </td>
                </tr>`;
            });
            
            if (data.data.length === 0) {
                html = '<tr><td colspan="5" class="text-center text-muted py-4"><i class="bi bi-inbox d-block fs-3 mb-2"></i>No hay gastos registrados.</td></tr>';
            }
            
            tbody.innerHTML = html;
            
            if ($.fn.DataTable) {
                if ($.fn.DataTable.isDataTable('#tablaGastos')) $('#tablaGastos').DataTable().destroy();
                $('#tablaGastos').DataTable({
                    dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B><"search-box"f>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                    buttons: [
                        { extend: 'excel', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> EXCEL', className: 'btn btn-sm btn-export' },
                        { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF', className: 'btn btn-sm btn-export' }
                    ],
                    language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json" },
                    order: [[0, "desc"]],
                    pageLength: 10,
                    responsive: true,
                    destroy: true
                });
            }
        }
    } catch (e) { console.error(e); }
}

window.abrirModalGasto = async function() {
    await cargarCategoriasGastos();
    const form = document.getElementById('formGasto');
    if (form) form.reset();
    document.getElementById('fecha_gasto').value = new Date().toISOString().split('T')[0];
    const el = document.getElementById('modalGasto');
    if (el) new bootstrap.Modal(el).show();
}

document.addEventListener("DOMContentLoaded", () => {
    const formGasto = document.getElementById('formGasto');
    if (formGasto) {
        formGasto.addEventListener('submit', async (e) => {
            e.preventDefault();
            const btn = formGasto.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerHTML = '<div class="spinner-border spinner-border-sm me-2"></div>Guardando...';
            
            const payload = new URLSearchParams({
                action: 'save_gasto',
                fecha: document.getElementById('fecha_gasto').value,
                id_cat: document.getElementById('cat_gasto').value,
                id_subcat: document.getElementById('subcat_gasto').value,
                id_subcat3: document.getElementById('subcat3_gasto').value,
                concepto: document.getElementById('concepto_gasto').value,
                monto: document.getElementById('monto_gasto').value
            });
            
            try {
                const res = await fetch('../api/finanzas_api.pl', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    body: payload
                });
                const data = await res.json();
                if (data.success) {
                    bootstrap.Modal.getInstance(document.getElementById('modalGasto')).hide();
                    renderGastos();
                    Swal.fire({icon: 'success', title: 'Éxito', text: data.message, timer: 1500, showConfirmButton: false});
                } else {
                    Swal.fire({icon: 'error', title: 'Error', text: data.message});
                }
            } catch (error) {
                Swal.fire({icon: 'error', title: 'Error', text: 'Ocurrió un error al guardar el gasto.'});
            } finally {
                btn.disabled = false;
                btn.innerHTML = 'Guardar Gasto';
            }
        });
    }
});

window.eliminarGasto = function(id) {
    Swal.fire({
        title: '¿Eliminar gasto?',
        text: "Esta acción no se puede deshacer",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Sí, eliminar',
        cancelButtonText: 'Cancelar'
    }).then(async (result) => {
        if (result.isConfirmed) {
            try {
                const res = await fetch('../api/finanzas_api.pl', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    body: new URLSearchParams({ action: 'delete_gasto', id_gasto: id })
                });
                const data = await res.json();
                if (data.success) {
                    Swal.fire({icon: 'success', title: 'Eliminado', text: data.message, timer: 1500, showConfirmButton: false});
                    renderGastos();
                } else {
                    Swal.fire({icon: 'error', title: 'Error', text: data.message});
                }
            } catch (e) {
                Swal.fire({icon: 'error', title: 'Error', text: 'Error al intentar eliminar el gasto.'});
            }
        }
    });
}

// --- Módulo Ingresos ---
window.renderIngresos = async function() {
    try {
        const tbody = document.getElementById('tbodyIngresos');
        if (tbody) tbody.innerHTML = '<tr><td colspan="4" class="text-center text-muted"><div class="spinner-border text-primary spinner-border-sm me-2"></div>Cargando datos...</td></tr>';
        
        const res = await fetch('../api/finanzas_api.pl', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: new URLSearchParams({ action: 'get_ingresos' })
        });
        const data = await res.json();
        
        if (data.success && tbody) {
            let html = '';
            data.data.forEach(g => {
                html += `<tr>
                    <td class="text-muted small">${g.fecha || ''}</td>
                    <td class="fw-bold" style="color: var(--md-blue-deep);"><i class="bi bi-person-circle me-2 text-muted"></i>${g.paciente_nombre}</td>
                    <td class="text-dark">${g.concepto} (OS: ${g.id_os})</td>
                    <td class="fw-bold text-success">+${formatter.format(g.abono)}</td>
                </tr>`;
            });
            
            if (data.data.length === 0) {
                html = '<tr><td colspan="4" class="text-center text-muted py-4"><i class="bi bi-inbox d-block fs-3 mb-2"></i>No hay abonos registrados.</td></tr>';
            }
            
            tbody.innerHTML = html;
            
            if ($.fn.DataTable) {
                if ($.fn.DataTable.isDataTable('#tablaIngresos')) $('#tablaIngresos').DataTable().destroy();
                $('#tablaIngresos').DataTable({
                    dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B><"search-box"f>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                    buttons: [
                        { extend: 'excel', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> EXCEL', className: 'btn btn-sm btn-export' },
                        { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF', className: 'btn btn-sm btn-export' },
                        { extend: 'print', text: '<i class="bi bi-printer me-1"></i> IMPRIMIR', className: 'btn btn-sm btn-export' }
                    ],
                    language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json" },
                    order: [[0, "desc"]],
                    pageLength: 10,
                    responsive: true,
                    destroy: true
                });
            }
        }
    } catch (e) {
        console.error(e);
        const tbody = document.getElementById('tbodyIngresos');
        if (tbody) tbody.innerHTML = '<tr><td colspan="4" class="text-center text-danger py-4">Error al cargar historial de ingresos.</td></tr>';
    }
}

