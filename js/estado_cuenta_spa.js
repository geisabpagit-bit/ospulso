/* SDM Digital - Financial Motor SPA */
var formatter = formatter || new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' });
var idPacienteGlobal = idPacienteGlobal || null;
var idMedicoGlobal = idMedicoGlobal || null;
var catalogoMaster = catalogoMaster || [];
var carritoApp = carritoApp || [];
var windowActiveOS = windowActiveOS || null;
var currentSaldoTotal = currentSaldoTotal || 0;
var pieChartInstance = pieChartInstance || null;
var pieCotizacionesInstance = pieCotizacionesInstance || null;

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
        actualizarPieChartCotizaciones(res.cotizaciones || 0);

        // Actualizar KPIs de Finanzas Dashboard
        if (typeof window.cargarDashboardKPIs === 'function') {
            window.cargarDashboardKPIs();
        }

        const tbody = document.getElementById('tbodyResumenIngresos');
        if (tbody) {
            let html = '';
            const limit = Math.min((res.historial || []).length, 10);
            for(let i=0; i<limit; i++) {
                const h = res.historial[i];
                const isAbono = h.tipo.toLowerCase().includes('abono');
                const badgeStr = isAbono ? '<span class="badge bg-success bg-opacity-10 text-success border border-success rounded-pill px-3">Pagado</span>' : '<span class="badge bg-warning bg-opacity-10 text-warning border border-warning rounded-pill px-3">Pendiente</span>';
                const rowColorClass = isAbono ? 'tr-ingreso' : 'tr-egreso';
                
                let concepto = h.concepto || '';
                let osExtra = '';
                const matchOS = concepto.match(/\(OS:\s*([^)]+)\)/);
                if (matchOS) {
                    osExtra = matchOS[1];
                    concepto = concepto.replace(/\(OS:\s*[^)]+\)/, '').trim();
                    concepto = `${concepto}<br><small class="text-muted">(OS: ${osExtra})</small>`;
                }
                
                const folioDisplay = h.id_os.toString().includes('TX') ? h.id_os : `OS/2024/${h.id_os.toString().padStart(4,'0')}`;
                
                html += `<tr class="${rowColorClass}">
                    <td class="text-muted">${h.fecha.substring(0, 10)}</td>
                    <td class="fw-bold text-dark">${concepto}</td>
                    <td class="text-muted small">${folioDisplay}</td>
                    <td class="fw-bold" style="color: var(--md-blue-deep);">${h.alias || h.paciente_nombre}</td>
                    <td class="fw-bold text-dark">${formatter.format(h.total)}</td>
                    <td>${badgeStr}</td>
                    <td class="text-center">
                        <button class="btn btn-sm btn-outline-primary shadow-sm rounded-pill" onclick="window.open('../api/ver_recibo.pl?id_os=${h.id_os}', '_blank')" title="Ver Recibo HTML"><i class="bi bi-file-earmark-text"></i></button>
                    </td>
                </tr>`;
            }
            if(limit === 0) html = '';
            tbody.innerHTML = html;
            
            if ($.fn.DataTable) {
                if ($.fn.DataTable.isDataTable('#tablaResumenIngresos')) {
                    $('#tablaResumenIngresos').DataTable().destroy();
                }
                $('#tablaResumenIngresos').DataTable({
                    scrollY: '400px',
                    scrollX: true,
                    scrollCollapse: true,
                    rowGroup: {
                        dataSrc: 2 // Agrupa por la columna 2 (Folio)
                    },
                    columnDefs: [
                        { targets: 2, visible: false } // Ocultar columna de agrupación
                    ],
                    footerCallback: function(row, data, start, end, display) {
                        var api = this.api();
                        var intVal = function(i) {
                            return typeof i === 'string' ? i.replace(/[\$,]/g, '') * 1 : typeof i === 'number' ? i : 0;
                        };
                        var total = api.column(4, { page: 'current' }).data().reduce(function(a, b) {
                            // Extract the number from HTML like <td class="fw-bold...">$1,200.00</td>
                            // DataTables data() might contain raw HTML if rendered via mRender, but here data is HTML string.
                            // Actually, data is an array of strings per column.
                            var val = typeof b === 'string' ? b.replace(/<[^>]*>?/gm, '').replace(/[\$,]/g, '') : b;
                            return intVal(a) + intVal(val);
                        }, 0);
                        var el = document.getElementById('tfootResumenMonto');
                        if(el) el.innerHTML = formatter.format(total);
                    },
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
    const gradGold = ctx.createLinearGradient(0, 0, 0, 160);
    gradGold.addColorStop(0, '#FFD700');
    gradGold.addColorStop(0.5, '#FFB300');
    gradGold.addColorStop(1, '#8B7500');

    // Metallic Green (Abonos)
    const gradGreen = ctx.createLinearGradient(0, 0, 0, 160);
    gradGreen.addColorStop(0, '#00FF7F');
    gradGreen.addColorStop(0.5, '#007A3D');
    gradGreen.addColorStop(1, '#003D1F');

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
            // Sombra base suave
            chartCtx.shadowColor = 'rgba(0, 0, 0, 0.4)';
            chartCtx.shadowBlur = 20;
            chartCtx.shadowOffsetX = 0;
            chartCtx.shadowOffsetY = 15;
        },
        afterDraw: (chart) => {
            chart.ctx.restore();
            if (!chart.getDatasetMeta(0).data[0]) return;
            const ctx = chart.ctx;
            const x = chart.chartArea.left + chart.chartArea.width / 2;
            const y = chart.chartArea.top + chart.chartArea.height / 2;
            const outerRadius = chart.getDatasetMeta(0).data[0].outerRadius;
            const innerRadius = chart.getDatasetMeta(0).data[0].innerRadius;
            
            ctx.save();
            
            // 1. Efecto Extrusión/Bisel Exterior (Outer Bevel)
            ctx.beginPath();
            ctx.arc(x, y, outerRadius - 1, 0, Math.PI * 2);
            ctx.lineWidth = 4;
            const outerBevelGrad = ctx.createLinearGradient(x, y - outerRadius, x, y + outerRadius);
            outerBevelGrad.addColorStop(0, 'rgba(255, 255, 255, 0.85)');
            outerBevelGrad.addColorStop(0.2, 'rgba(255, 255, 255, 0)');
            outerBevelGrad.addColorStop(0.8, 'rgba(0, 0, 0, 0)');
            outerBevelGrad.addColorStop(1, 'rgba(0, 0, 0, 0.5)'); 
            ctx.strokeStyle = outerBevelGrad;
            ctx.globalCompositeOperation = 'source-over';
            ctx.stroke();

            // 2. Efecto Extrusión/Bisel Interior (Inner Bevel)
            ctx.beginPath();
            ctx.arc(x, y, innerRadius + 1, 0, Math.PI * 2);
            ctx.lineWidth = 4;
            const innerBevelGrad = ctx.createLinearGradient(x, y - innerRadius, x, y + innerRadius);
            innerBevelGrad.addColorStop(0, 'rgba(0, 0, 0, 0.5)'); 
            innerBevelGrad.addColorStop(0.2, 'rgba(0, 0, 0, 0)');
            innerBevelGrad.addColorStop(0.8, 'rgba(255, 255, 255, 0)');
            innerBevelGrad.addColorStop(1, 'rgba(255, 255, 255, 0.85)'); 
            ctx.strokeStyle = innerBevelGrad;
            ctx.stroke();

            // 3. Brillo Especular Superior (Glossy Highlight)
            ctx.beginPath();
            ctx.arc(x, y, outerRadius, Math.PI, Math.PI * 2);
            ctx.arc(x, y, innerRadius, Math.PI * 2, Math.PI, true);
            ctx.closePath();
            
            const glossTop = ctx.createLinearGradient(x, y - outerRadius, x, y);
            glossTop.addColorStop(0, 'rgba(255, 255, 255, 0.7)'); // Destello fuerte arriba
            glossTop.addColorStop(0.2, 'rgba(255, 255, 255, 0.1)'); // Corte brusco (metálico)
            glossTop.addColorStop(0.3, 'rgba(255, 255, 255, 0)');
            ctx.fillStyle = glossTop;
            ctx.fill();

            // 4. Reflejo Secundario Inferior
            ctx.beginPath();
            ctx.arc(x, y, outerRadius, 0, Math.PI);
            ctx.arc(x, y, innerRadius, Math.PI, 0, true);
            ctx.closePath();
            
            const glossBottom = ctx.createLinearGradient(x, y, x, y + outerRadius);
            glossBottom.addColorStop(0, 'rgba(0, 0, 0, 0)');
            glossBottom.addColorStop(0.7, 'rgba(0, 0, 0, 0.1)');
            glossBottom.addColorStop(1, 'rgba(0, 0, 0, 0.4)');
            ctx.fillStyle = glossBottom;
            ctx.fill();

            ctx.restore();
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
                cutout: '58%',
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

function actualizarPieChartCotizaciones(cotizaciones) {
    const legCot = document.getElementById('legCotizaciones');
    const pieVal = document.getElementById('pieCenterValCotizaciones');
    if (legCot) legCot.innerText = formatter.format(cotizaciones);
    if (pieVal) pieVal.innerText = formatter.format(cotizaciones);

    const ctx = document.getElementById('pieCotizaciones');
    if (!ctx) return;

    if (pieCotizacionesInstance) {
        pieCotizacionesInstance.data.datasets[0].data = [cotizaciones, cotizaciones === 0 ? 1 : 0];
        pieCotizacionesInstance.update();
    } else {
        pieCotizacionesInstance = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: ['Cotizaciones', 'Vacío'],
                datasets: [{
                    data: [cotizaciones, cotizaciones === 0 ? 1 : 0],
                    backgroundColor: [
                        '#F59E0B',
                        '#e2e8f0'
                    ],
                    borderWidth: 0,
                    hoverOffset: 4,
                    cutout: '80%'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                if (context.label === 'Vacío') return 'Sin cotizaciones activas';
                                let val = context.raw || 0;
                                return context.label + ': ' + formatter.format(val);
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
        tb.innerHTML = '';
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
                scrollY: '400px',
                scrollX: true,
                scrollCollapse: true,
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
        
        if (data.is_universal) {
            const catMap = {};
            const depMap = {};
            (data.catalogo.departamentos || []).forEach(d => depMap[d.id_dep] = d.nombre);
            (data.catalogo.categorias || []).forEach(c => {
                catMap[c.id_cat] = { nombre: c.nombre, depto: depMap[c.id_dep] || '', id_dep: c.id_dep };
            });

            catalogoMaster = [];
            (data.catalogo.items || []).forEach(item => {
                const cat = catMap[item.id_cat] || { nombre: '', depto: '' };
                (item.precios || []).forEach(p => {
                    catalogoMaster.push({
                        id: `U-${p.id_precio}`,
                        id_item: item.id_item,
                        id_precio: p.id_precio,
                        nombre: `${item.concepto} - ${p.tipo_tarifa}`,
                        precio: p.precio_publico,
                        aplica_iva: item.aplica_iva,
                        codigo_sku: item.codigo_sku,
                        categoria: cat.nombre,
                        departamento: cat.depto,
                        id_cat: item.id_cat
                    });
                });
            });
            
            // Inject Productos
            (data.catalogo.productos || []).forEach(prod => {
                catalogoMaster.push({
                    id: `P-${prod.id_prod}`,
                    id_item: prod.id_prod,
                    nombre: `${prod.nombre} (${prod.presentacion})`,
                    precio: prod.precio,
                    aplica_iva: 0,
                    codigo_sku: prod.id_prod,
                    categoria: 'Insumos',
                    departamento: 'Farmacia',
                    id_cat: 'PROD_CAT'
                });
            });
            // Populate select filters
            if (data.catalogo.departamentos && data.catalogo.departamentos.length > 0) {
                const selDep = document.getElementById('filtroDepartamento');
                const selCat = document.getElementById('filtroCategoria');
                if (selDep) {
                    selDep.innerHTML = '<option value="">Todos los Departamentos</option>';
                    data.catalogo.departamentos.forEach(d => {
                        selDep.insertAdjacentHTML('beforeend', `<option value="${d.id_dep}">${d.nombre}</option>`);
                    });
                    selDep.onchange = function() {
                        const dep = this.value;
                        if (selCat) {
                            selCat.innerHTML = '<option value="">Todas las Categorías</option>';
                            (data.catalogo.categorias || []).forEach(c => {
                                if (dep === '' || c.id_dep == dep) {
                                    selCat.insertAdjacentHTML('beforeend', `<option value="${c.id_cat}">${c.nombre}</option>`);
                                }
                            });
                            if (dep === '' || dep === 'FARMACIA_DEP') {
                                if (data.catalogo.productos && data.catalogo.productos.length > 0) {
                                    selCat.insertAdjacentHTML('beforeend', `<option value="PROD_CAT">Productos e Insumos Médicos</option>`);
                                }
                            }
                        }
                        filtrarCatalogo();
                    };
                    // Trigger onchange to populate categories initially
                    selDep.onchange();
                }
            }
        } else {
            catalogoMaster = [...(data.servicios||[]), ...(data.productos||[])];
        }
        
        renderCatalogoGUI();
    } catch(e) {}
}

function renderCatalogoGUI(f = '', depFilter = '', catFilter = '') {
    const tbody = document.getElementById('tablaCatalogo'); if(!tbody) return;
    tbody.innerHTML = '';
    const filtered = catalogoMaster.filter(i => {
        const matchName = (i.nombre||'').toLowerCase().includes(f.toLowerCase());
        let matchCat = true;
        if (catFilter) {
            matchCat = (i.id_cat == catFilter);
        } else if (depFilter) {
            // Check if item's category belongs to this department
            matchCat = (i.id_dep == depFilter) || (depFilter === 'FARMACIA_DEP' && i.id_cat === 'PROD_CAT'); 
        }
        return matchName && matchCat;
    });
    
    let totalCount = 0;
    filtered.slice(0, 50).forEach(it => {
        totalCount++;
        let badgeDepto = it.departamento ? `<br><span class="badge bg-light text-secondary border mt-1" style="font-size:0.65rem;">${it.departamento} > ${it.categoria}</span>` : '';
        tbody.insertAdjacentHTML('beforeend', `
            <tr style="cursor:pointer;" onclick="agregarAlCarrito('${it.id}')" class="hover-shadow">
                <td class="fw-bold text-dark small" title="${it.nombre}">${it.nombre}${badgeDepto}</td>
                <td class="text-primary fw-bold text-end small align-middle">${formatter.format(it.precio)}</td>
                <td class="text-center align-middle" style="width: 40px;">
                    <div class="btn btn-sm btn-primary rounded-circle shadow-sm d-flex align-items-center justify-content-center" style="width:24px; height:24px; padding:0; border:none;"><i class="bi bi-plus" style="font-size:1rem;"></i></div>
                </td>
            </tr>`);
    });
    
    if (document.getElementById('totalConceptosBadge')) {
        document.getElementById('totalConceptosBadge').innerText = filtered.length;
    }
}

function filtrarCatalogo() { 
    const f = document.getElementById('buscadorCatalogo') ? document.getElementById('buscadorCatalogo').value : '';
    const dep = document.getElementById('filtroDepartamento') ? document.getElementById('filtroDepartamento').value : '';
    const cat = document.getElementById('filtroCategoria') ? document.getElementById('filtroCategoria').value : '';
    renderCatalogoGUI(f, dep, cat); 
}

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
    
    // Si la página invocadora define una función onCarritoCompletado, se le devuelven los items y NO se procesa por AJAX
    if (typeof window.onCarritoCompletado === 'function') {
        const itemsToReturn = JSON.parse(JSON.stringify(carritoApp)); // Clone
        window.onCarritoCompletado(itemsToReturn);
        const m = bootstrap.Modal.getInstance(document.getElementById('modalCargo'));
        if (m) m.hide();
        // Limpiar
        carritoApp = [];
        renderCarrito();
        return;
    }

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
    _initRadioCotizacion();
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
    _initRadioCotizacion();
    const el = document.getElementById('modalCargo');
    if (!el) return console.error("Modal Cargo no encontrado");
    const m = new bootstrap.Modal(el);
    m.show();
}

/**
 * Inicializa el comportamiento del radio "Cotizacion" en el modal de cargo.
 * - Al seleccionar Cotizacion: muestra selector y carga lista desde cotizaciones_api.
 * - Al seleccionar Consulta: oculta el selector y limpia el carrito.
 * Idempotente: usa data-cot-init para no registrar listeners duplicados.
 */
function _initRadioCotizacion() {
    // Resetear radio a Consulta al abrir
    const radConsulta = document.getElementById('aplica_consulta');
    const radCot      = document.getElementById('aplica_cotizacion');
    const panel       = document.getElementById('panelSelCotizacion');
    const sel         = document.getElementById('selectCotizacionCargo');
    if (radConsulta) radConsulta.checked = true;
    if (panel) panel.classList.add('d-none');
    if (sel) sel.value = '';

    // Evitar registrar el listener mas de una vez
    if (radCot && !radCot.dataset.cotInit) {
        radCot.dataset.cotInit = '1';
        radCot.addEventListener('change', function() {
            if (!this.checked) return;
            if (panel) panel.classList.remove('d-none');

            // Delegar carga al modulo cotizaciones_spa.js
            // cotPacienteId es la variable global de cotizaciones_spa.js
            var pid = (typeof cotPacienteId !== 'undefined') ? cotPacienteId : null;
            if (!pid) {
                // Intentar obtenerlo de la URL o del modulo financiero
                pid = (typeof idPacienteGlobal !== 'undefined') ? idPacienteGlobal : null;
            }

            if (pid && typeof window._cargarSelectCotizaciones === 'function') {
                // Sobreescribir cotPacienteId temporalmente si se abre desde estado_cuenta
                if (typeof cotPacienteId !== 'undefined') { cotPacienteId = pid; }
                window._cargarSelectCotizaciones();
            } else if (sel) {
                sel.innerHTML = '<option value="">-- Sin cotizaciones disponibles --</option>';
            }
        });
    }

    if (radConsulta && !radConsulta.dataset.cotInit) {
        radConsulta.dataset.cotInit = '1';
        radConsulta.addEventListener('change', function() {
            if (!this.checked) return;
            if (panel) panel.classList.add('d-none');
            if (sel) sel.value = '';
        });
    }
}

var lineChartInstance = lineChartInstance || null;
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
                html = '';
            }
            
            tbody.innerHTML = html;
            
            // Inicializar DataTable
            if ($.fn.DataTable) {
                if ($.fn.DataTable.isDataTable('#tablaCxC')) {
                    $('#tablaCxC').DataTable().destroy();
                }
                $('#tablaCxC').DataTable({
                    scrollY: '400px',
                    scrollX: true,
                    scrollCollapse: true,
                    footerCallback: function(row, data, start, end, display) {
                        var api = this.api();
                        var intVal = function(i) { return typeof i === 'string' ? i.replace(/<[^>]*>?/gm, '').replace(/[\$,]/g, '') * 1 : typeof i === 'number' ? i : 0; };
                        var cargos = api.column(2, { page: 'current' }).data().reduce(function(a, b) { return intVal(a) + intVal(b); }, 0);
                        var abonos = api.column(3, { page: 'current' }).data().reduce(function(a, b) { return intVal(a) + intVal(b); }, 0);
                        var saldo = api.column(4, { page: 'current' }).data().reduce(function(a, b) { return intVal(a) + intVal(b); }, 0);
                        var eC = document.getElementById('tfootCxCCargos'); if(eC) eC.innerHTML = formatter.format(cargos);
                        var eA = document.getElementById('tfootCxCAbonos'); if(eA) eA.innerHTML = formatter.format(abonos);
                        var eS = document.getElementById('tfootCxCSaldo'); if(eS) eS.innerHTML = formatter.format(saldo);
                    },
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

window.renderCxcEstado = async function() {
    try {
        if ($.fn.DataTable) {
            if ($.fn.DataTable.isDataTable('#dtPublicosCxC')) {
                $('#dtPublicosCxC').DataTable().destroy();
            }
            
            const dtConfig = {
                language: { url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
                dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B><"search-box"f>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                buttons: [
                    { extend: 'copy', text: '<i class="bi bi-clipboard me-1"></i> COPIAR', className: 'btn btn-sm btn-export' },
                    { extend: 'excel', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> EXCEL', className: 'btn btn-sm btn-export' },
                    { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF', className: 'btn btn-sm btn-export' },
                    { extend: 'print', text: '<i class="bi bi-printer me-1"></i> IMPRIMIR', className: 'btn btn-sm btn-export' }
                ],
                pageLength: 10,
                lengthChange: false,
                ajax: '../api/get_recibos_caja_api.pl?tipo=publicos',
                footerCallback: function(row, data, start, end, display) {
                    var api = this.api();
                    var intVal = function(i) {
                        return typeof i === 'string' ? i.replace(/[\\$,]/g, '') * 1 : typeof i === 'number' ? i : 0;
                    };
                    var total = api.column(6, { page: 'current' }).data().reduce(function(a, b) {
                        return intVal(a) + intVal(b);
                    }, 0);
                    $(api.column(6).footer()).html('$' + total.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2}));
                },
                drawCallback: function(settings) {
                    let totalVal = 0;
                    if(settings.json && settings.json.data) {
                        settings.json.data.forEach(function(row) {
                            let valStr = row[6] || '0';
                            valStr = valStr.replace(/[\\$,]/g, '');
                            totalVal += parseFloat(valStr) || 0;
                        });
                    }
                }
            };
            $('#dtPublicosCxC').DataTable(dtConfig);
        }
    } catch (error) {
        console.error("Error cargando CxC Estado", error);
    }
}


// --- Módulo Gastos ---
var catGastos = catGastos || [], subcatGastos = subcatGastos || [], subcat3Gastos = subcat3Gastos || [];
var categoriasGastosCargadas = categoriasGastosCargadas || false;

async function cargarCategoriasGastos(force = false) {
    if (categoriasGastosCargadas && !force) return;
    try {
        const res = await fetch('../api/finanzas_api.pl', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: new URLSearchParams({ action: 'get_categorias_gastos' })
        });
        
        let data;
        try {
            data = await res.clone().json();
        } catch(e) {
            const rawText = await res.text();
            console.error("GET CATEGORIAS FAILED TO PARSE JSON. RAW RESPONSE:", rawText);
            throw e;
        }
        
        if (data.success) {
            catGastos = data.categorias;
            subcatGastos = data.subcategorias;
            subcat3Gastos = data.subcategorias3;
            categoriasGastosCargadas = true;
            
            const catSelect = document.getElementById('cat_gasto');
            if (catSelect) {
                catSelect.innerHTML = '<option value="">Sin Categoría</option>';
                catGastos.forEach(c => {
                    catSelect.innerHTML += `<option value="${c.id}">${c.nombre}</option>`;
                });
            }
        } else {
            if (data.message === 'Sesión expirada') {
                window.location.reload();
            }
        }
    } catch (e) { console.error("Error cargando categorías de gastos", e); }
}

window.filtrarSubcategorias = function() {
    const idCat = document.getElementById('cat_gasto').value;
    const subcatSelect = document.getElementById('subcat_gasto');
    const subcat3Select = document.getElementById('subcat3_gasto');
    const colSub = document.getElementById('col_subcat_gasto');
    const colSub3 = document.getElementById('col_subcat3_gasto');
    
    subcatSelect.innerHTML = '<option value="">Seleccione...</option>';
    subcat3Select.innerHTML = '<option value="">Seleccione...</option>';
    
    if (!idCat) {
        colSub.style.display = 'none';
        colSub3.style.display = 'none';
        return;
    }
    
    const filtradas = subcatGastos.filter(s => s.id_cat === idCat);
    if (filtradas.length > 0) {
        colSub.style.display = 'block';
        filtradas.forEach(s => {
            subcatSelect.innerHTML += `<option value="${s.id}">${s.nombre}</option>`;
        });
        subcatSelect.innerHTML += `<option value="0">Ninguna</option>`;
    } else {
        colSub.style.display = 'none';
        subcatSelect.value = '';
    }
    colSub3.style.display = 'none';
}

window.filtrarSubcategorias3 = function() {
    const idSub = document.getElementById('subcat_gasto').value;
    const subcat3Select = document.getElementById('subcat3_gasto');
    const colSub3 = document.getElementById('col_subcat3_gasto');
    
    subcat3Select.innerHTML = '<option value="">Seleccione...</option>';
    if (!idSub || idSub === "0") {
        colSub3.style.display = 'none';
        return;
    }
    
    const filtradas = subcat3Gastos.filter(s => s.id_subcat === idSub);
    if (filtradas.length > 0) {
        colSub3.style.display = 'block';
        filtradas.forEach(s => {
            subcat3Select.innerHTML += `<option value="${s.id}">${s.nombre}</option>`;
        });
        subcat3Select.innerHTML += `<option value="0">Ninguna</option>`;
    } else {
        colSub3.style.display = 'none';
    }
}

window.renderGastos = async function() {
    try {
        const tbody = document.getElementById('tbodyGastos');
        if ($.fn.DataTable && $.fn.DataTable.isDataTable('#tablaGastos')) {
            $('#tablaGastos').DataTable().destroy();
        }
        if (tbody) tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted"><div class="spinner-border text-primary spinner-border-sm me-2"></div>Cargando...</td></tr>';
        
        const res = await fetch('../api/finanzas_api.pl', {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: new URLSearchParams({ action: 'get_gastos' })
        });
        
        let data;
        try {
            data = await res.clone().json();
        } catch(e) {
            const rawText = await res.text();
            console.error("GET GASTOS FAILED TO PARSE JSON. RAW RESPONSE:", rawText);
            throw e;
        }
        
        if (data.success && tbody) {
            let html = '';
            data.data.forEach(g => {
                const facturaBtn = g.factura_path ? 
                    `<a href="../${g.factura_path}" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill me-1" title="Ver Factura"><i class="bi bi-file-earmark-pdf"></i></a>` : 
                    '';
                
                let subCatsText = '';
                if (g.subcat_nombre !== 'N/A' && g.subcat_nombre) {
                    subCatsText = g.subcat_nombre;
                    if (g.subcat3_nombre !== 'N/A' && g.subcat3_nombre) {
                        subCatsText += ' > ' + g.subcat3_nombre;
                    }
                }
                const subCatsHtml = subCatsText ? `<small class="text-muted">${subCatsText}</small>` : '';
                const catHtml = g.cat_nombre !== 'N/A' && g.cat_nombre ? g.cat_nombre : 'Sin Categoría';

                html += `<tr>
                    <td class="text-muted small">${g.fecha || ''}</td>
                    <td>
                        <span class="fw-bold" style="color: var(--md-blue-deep);">${catHtml}</span><br>
                        ${subCatsHtml}
                    </td>
                    <td class="fw-bold text-dark">${g.proveedor || '-'}</td>
                    <td class="text-muted">${g.concepto}</td>
                    <td class="fw-bold text-danger">${formatter.format(g.monto)}</td>
                    <td class="text-center">${facturaBtn}</td>
                    <td>
                        <button class="btn btn-sm btn-outline-danger rounded-pill" onclick="eliminarGasto('${g.id_gasto}')"><i class="bi bi-trash"></i></button>
                    </td>
                </tr>`;
            });
            
            if (data.data.length === 0) {
                html = '';
            }
            
            tbody.innerHTML = html;
            
            if ($.fn.DataTable) {
                if ($.fn.DataTable.isDataTable('#tablaGastos')) $('#tablaGastos').DataTable().destroy();
                $('#tablaGastos').DataTable({
                    scrollY: '400px',
                    scrollX: true,
                    scrollCollapse: true,
                    footerCallback: function(row, data, start, end, display) {
                        var api = this.api();
                        var intVal = function(i) { return typeof i === 'string' ? i.replace(/<[^>]*>?/gm, '').replace(/[\$,]/g, '') * 1 : typeof i === 'number' ? i : 0; };
                        var total = api.column(4, { page: 'current' }).data().reduce(function(a, b) { return intVal(a) + intVal(b); }, 0);
                        var el = document.getElementById('tfootGastosMonto');
                        if(el) el.innerHTML = formatter.format(total);
                    },
                    dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B><"search-box"f>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                    buttons: [
                        { extend: 'copyHtml5', text: '<i class="bi bi-files me-1"></i> <span class="d-none d-md-inline">COPIAR</span>', className: 'btn btn-sm btn-export' },
                        { extend: 'excelHtml5', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> <span class="d-none d-md-inline">EXCEL</span>', className: 'btn btn-sm btn-export' },
                        { extend: 'pdfHtml5', text: '<i class="bi bi-file-earmark-pdf me-1"></i> <span class="d-none d-md-inline">PDF</span>', className: 'btn btn-sm btn-export' },
                        { extend: 'print', text: '<i class="bi bi-printer me-1"></i> <span class="d-none d-md-inline">IMPRIMIR</span>', className: 'btn btn-sm btn-export' }
                    ],
                    language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json" },
                    order: [[0, "desc"]],
                    pageLength: 10,
                    responsive: true,
                    destroy: true
                });
            }
        } else if (tbody) {
            tbody.innerHTML = `<tr><td colspan="7" class="text-center text-danger">${data.message || 'Error al cargar'}</td></tr>`;
            if (data.message === 'Sesión expirada') {
                window.location.reload();
            }
        }
    } catch (e) {
        console.error(e);
        const tbody = document.getElementById('tbodyGastos');
        if (tbody) tbody.innerHTML = '<tr><td colspan="7" class="text-center text-danger">Error de red</td></tr>';
    }
}

window.abrirModalGasto = async function() {
    await cargarCategoriasGastos();
    const form = document.getElementById('formGasto');
    if (form) form.reset();
    document.getElementById('fecha_gasto').value = new Date().toISOString().split('T')[0];
    const el = document.getElementById('modalGasto');
    if (el) {
        // Garantizar que escape de contextos de apilamiento en DOM
        $(el).appendTo('body');
        
        // Reiniciar visibilidad de columnas
        document.getElementById('col_subcat_gasto').style.display = 'none';
        document.getElementById('col_subcat3_gasto').style.display = 'none';
        
        new bootstrap.Modal(el).show();
    }
}

function attachFinanzasListeners() {
    const formGasto = document.getElementById('formGasto');
    if (formGasto && !formGasto.dataset.listenerAttached) {
        formGasto.dataset.listenerAttached = 'true';
        formGasto.addEventListener('submit', async (e) => {
            e.preventDefault();
            const btn = formGasto.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerHTML = '<div class="spinner-border spinner-border-sm me-2"></div>Guardando...';
            
            const payload = new FormData();
            payload.append('action', 'save_gasto');
            payload.append('fecha', document.getElementById('fecha_gasto').value);
            payload.append('id_cat', document.getElementById('cat_gasto').value);
            payload.append('id_subcat', document.getElementById('subcat_gasto').value);
            payload.append('id_subcat3', document.getElementById('subcat3_gasto').value);
            payload.append('proveedor', document.getElementById('proveedor_gasto').value);
            payload.append('concepto', document.getElementById('concepto_gasto').value);
            payload.append('monto', document.getElementById('monto_gasto').value);
            
            const fileInput = document.getElementById('factura_gasto');
            if (fileInput && fileInput.files.length > 0) {
                payload.append('factura_file', fileInput.files[0]);
            }
            
            try {
                const res = await fetch('../api/finanzas_api.pl', {
                    method: 'POST',
                    body: payload
                });
                const data = await res.json();
                if (data.success) {
                    bootstrap.Modal.getInstance(document.getElementById('modalGasto')).hide();
                    renderGastos();
                    if (typeof window.cargarDashboardKPIs === 'function') window.cargarDashboardKPIs();
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
}
document.addEventListener("DOMContentLoaded", attachFinanzasListeners);
document.addEventListener("spa:contentLoaded", attachFinanzasListeners);

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
                    renderGastos();
                    if (typeof window.cargarDashboardKPIs === 'function') window.cargarDashboardKPIs();
                    Swal.fire({icon: 'success', title: 'Eliminado', text: data.message, timer: 1500, showConfirmButton: false});
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
                let concepto = g.concepto || '';
                let osExtra = g.id_os || '';
                // Extraer el (OS: xxxx) si ya viene concatenado
                const matchOS = concepto.match(/\(OS:\s*([^)]+)\)/);
                if (matchOS) {
                    osExtra = matchOS[1];
                    concepto = concepto.replace(/\(OS:\s*[^)]+\)/, '').trim();
                }
                
                const folioDisplay = osExtra.toString().includes('TX') ? osExtra : `OS/2024/${osExtra.toString().padStart(4,'0')}`;
                
                // Formato jerárquico
                concepto = `<div class="fw-bold">${concepto}</div>`;
                
                let valToShow = g.abono > 0 ? -g.abono : (g.cargo > 0 ? g.cargo : 0);
                
                let colorClass = valToShow > 0 ? 'text-danger' : (valToShow < 0 ? 'text-success' : 'text-muted');
                let displayVal = valToShow > 0 ? `+${formatter.format(valToShow)}` : formatter.format(valToShow);
                
                html += `<tr>
                    <td class="text-muted small">${g.fecha || ''}</td>
                    <td class="fw-bold" style="color: var(--md-blue-deep);"><i class="bi bi-person-circle me-2 text-muted"></i>${g.paciente_nombre}</td>
                    <td class="text-dark">${concepto}</td>
                    <td class="text-muted small">${folioDisplay}</td>
                    <td class="fw-bold ${colorClass}">${displayVal}</td>
                    <td class="text-center">
                        <button class="btn btn-sm btn-outline-primary shadow-sm rounded-pill" onclick="window.open('../api/ver_recibo.pl?id_os=${osExtra}', '_blank')" title="Ver Recibo HTML"><i class="bi bi-file-earmark-text"></i></button>
                    </td>
                </tr>`;
            });
            
            if (data.data.length === 0) {
                html = '';
            }
            
            tbody.innerHTML = html;
            
            if ($.fn.DataTable) {
                if ($.fn.DataTable.isDataTable('#tablaIngresos')) $('#tablaIngresos').DataTable().destroy();
                $('#tablaIngresos').DataTable({
                    scrollY: '400px',
                    scrollX: true,
                    scrollCollapse: true,
                    rowGroup: {
                        dataSrc: 3, // Agrupa por la columna 3 (Folio)
                        startRender: function (rows, group) {
                            return $('<tr/>').append('<td colspan="5" class="bg-light text-primary fw-bold px-3 py-2"><i class="bi bi-folder2-open me-2"></i>Folio Agrupador: ' + group + ' <span class="badge bg-secondary ms-2">' + rows.count() + ' movimientos</span></td>');
                        }
                    },
                    columnDefs: [
                        { targets: 3, visible: false } // Ocultar columna de agrupación
                    ],
                    footerCallback: function(row, data, start, end, display) {
                        var api = this.api();
                        var intVal = function(i) { return typeof i === 'string' ? i.replace(/<[^>]*>?/gm, '').replace(/[\$,+]/g, '') * 1 : typeof i === 'number' ? i : 0; };
                        var total = api.column(4, { page: 'current' }).data().reduce(function(a, b) { return intVal(a) + intVal(b); }, 0);
                        var el = document.getElementById('tfootIngresosAbono');
                        if(el) el.innerHTML = formatter.format(total);
                    },
                    dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B><"search-box"f>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                    buttons: [
                        { extend: 'copyHtml5', text: '<i class="bi bi-files me-1"></i> <span class="d-none d-md-inline">COPIAR</span>', className: 'btn btn-sm btn-export' },
                        { extend: 'excelHtml5', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> <span class="d-none d-md-inline">EXCEL</span>', className: 'btn btn-sm btn-export' },
                        { extend: 'pdfHtml5', text: '<i class="bi bi-file-earmark-pdf me-1"></i> <span class="d-none d-md-inline">PDF</span>', className: 'btn btn-sm btn-export' },
                        { extend: 'print', text: '<i class="bi bi-printer me-1"></i> <span class="d-none d-md-inline">IMPRIMIR</span>', className: 'btn btn-sm btn-export' }
                    ],
                    language: { url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json" },
                    order: [[0, "desc"]],
                    pageLength: 10,
                    responsive: true,
                    destroy: true
                });
            }
        } else if (tbody) {
            tbody.innerHTML = `<tr><td colspan="4" class="text-center text-danger">${data.message || 'Error al cargar'}</td></tr>`;
            if (data.message === 'Sesión expirada') {
                window.location.reload();
            }
        }
    } catch (e) {
        console.error(e);
        const tbody = document.getElementById('tbodyIngresos');
        if (tbody) tbody.innerHTML = '<tr><td colspan="4" class="text-center text-danger py-4">Error al cargar historial de ingresos.</td></tr>';
    }
}


// ==========================================
// SPA: GESTION DINAMICA DE CATEGORIAS
// ==========================================
window.abrirModalCategorias = function() {
    const el = document.getElementById('modalCategorias');
    if (!el) return;
    $(el).appendTo('body');
    
    document.getElementById('mg_nombre').value = '';
    document.getElementById('mg_nivel').value = '1';
    cambiarNivelGestion();
    
    const modalGastoEl = document.getElementById('modalGasto');
    
    const reabrirGastoHandler = function() {
        el.removeEventListener('hidden.bs.modal', reabrirGastoHandler);
        if (modalGastoEl) {
            const mg = bootstrap.Modal.getInstance(modalGastoEl) || new bootstrap.Modal(modalGastoEl);
            mg.show();
        }
    };
    
    if (modalGastoEl && modalGastoEl.classList.contains('show')) {
        const mg = bootstrap.Modal.getInstance(modalGastoEl);
        if (mg) {
            const onHidden = function() {
                modalGastoEl.removeEventListener('hidden.bs.modal', onHidden);
                const mc = bootstrap.Modal.getInstance(el) || new bootstrap.Modal(el);
                mc.show();
                el.addEventListener('hidden.bs.modal', reabrirGastoHandler);
            };
            modalGastoEl.addEventListener('hidden.bs.modal', onHidden);
            mg.hide();
        } else {
            const mc = bootstrap.Modal.getInstance(el) || new bootstrap.Modal(el);
            mc.show();
            el.addEventListener('hidden.bs.modal', reabrirGastoHandler);
        }
    } else {
        const mc = bootstrap.Modal.getInstance(el) || new bootstrap.Modal(el);
        mc.show();
    }
}

window.cambiarNivelGestion = function() {
    const n = document.getElementById('mg_nivel').value;
    const parentCol = document.getElementById('mg_parent_col');
    const parentSelect = document.getElementById('mg_parent');
    const parentLabel = document.getElementById('mg_parent_label');
    
    parentSelect.innerHTML = '<option value="">Seleccione...</option>';
    
    if (n === '1') {
        parentCol.style.display = 'none';
        renderListaCategorias();
    } else if (n === '2') {
        parentCol.style.display = 'block';
        parentLabel.innerText = "Categoría Principal (Padre)";
        catGastos.forEach(c => {
            parentSelect.innerHTML += `<option value="${c.id}">${c.nombre}</option>`;
        });
        renderListaCategorias();
    } else if (n === '3') {
        parentCol.style.display = 'block';
        parentLabel.innerText = "Subcategoría Nivel 2 (Padre)";
        subcatGastos.forEach(s => {
            // Find parent cat name
            const parent = catGastos.find(c => c.id == s.id_cat);
            const parentName = parent ? parent.nombre : '';
            parentSelect.innerHTML += `<option value="${s.id}">${parentName} > ${s.nombre}</option>`;
        });
        renderListaCategorias();
    }
}

window.renderListaCategorias = function() {
    const n = document.getElementById('mg_nivel').value;
    const pId = document.getElementById('mg_parent').value;
    const tbody = document.getElementById('tbodyCategorias');
    
    tbody.innerHTML = '';
    
    let arr = [];
    if (n === '1') {
        arr = catGastos;
    } else if (n === '2') {
        if (!pId) { tbody.innerHTML = '<tr><td colspan="2" class="text-center text-muted">Seleccione un padre</td></tr>'; return; }
        arr = subcatGastos.filter(x => x.id_cat == pId);
    } else if (n === '3') {
        if (!pId) { tbody.innerHTML = '<tr><td colspan="2" class="text-center text-muted">Seleccione un padre</td></tr>'; return; }
        arr = subcat3Gastos.filter(x => x.id_subcat == pId);
    }
    
    if (arr.length === 0) {
        tbody.innerHTML = '<tr><td colspan="2" class="text-center text-muted">No hay registros</td></tr>';
        return;
    }
    
    arr.forEach(item => {
        tbody.innerHTML += `
            <tr>
                <td class="fw-medium">${item.nombre}</td>
                <td class="text-end">
                    <button class="btn btn-sm btn-outline-danger border-0" onclick="borrarCategoria('${item.id}', '${n}')"><i class="bi bi-trash"></i></button>
                </td>
            </tr>
        `;
    });
}

window.agregarCategoria = async function() {
    const n = document.getElementById('mg_nivel').value;
    const pId = document.getElementById('mg_parent').value;
    const nombre = document.getElementById('mg_nombre').value.trim();
    
    if (!nombre) {
        Swal.fire('Atención', 'Ingrese un nombre', 'warning');
        return;
    }
    if (n !== '1' && !pId) {
        Swal.fire('Atención', 'Debe seleccionar un padre', 'warning');
        return;
    }
    
    const btn = document.getElementById('btn_add_cat');
    const oldHtml = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span>';
    
    try {
        const params = new URLSearchParams({
            action: 'add_categoria',
            nivel: n,
            parent_id: pId,
            nombre: nombre
        });
        
        const res = await fetch('../api/finanzas_api.pl', {
            method: 'POST',
            body: params
        });
        const d = await res.json();
        if (d.success) {
            document.getElementById('mg_nombre').value = '';
            await cargarCategoriasGastos(true);
            if (n === '1') {
                const s = document.getElementById('cat_gasto');
                if (s) { s.value = ''; s.dispatchEvent(new Event('change')); }
            } else if (n === '2') {
                const s = document.getElementById('subcat_gasto');
                if (s) { s.value = ''; s.dispatchEvent(new Event('change')); }
            }
            cambiarNivelGestion();
            document.getElementById('mg_parent').value = pId;
            renderListaCategorias();
        } else {
            Swal.fire('Error', d.message, 'error');
        }
    } catch(e) {
        Swal.fire('Error', 'Error de red', 'error');
    }
    btn.disabled = false;
    btn.innerHTML = oldHtml;
}

window.borrarCategoria = async function(id, nivel) {
    const { isConfirmed } = await Swal.fire({
        title: '¿Borrar categoría?',
        text: 'Se verificará que no existan gastos asociados.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Sí, borrar',
        cancelButtonText: 'Cancelar'
    });
    
    if (!isConfirmed) return;
    
    try {
        const params = new URLSearchParams({ action: 'delete_categoria', id: id, nivel: nivel });
        const res = await fetch('../api/finanzas_api.pl', { method: 'POST', body: params });
        const d = await res.json();
        
        if (d.success) {
            const pId = document.getElementById('mg_parent').value;
            await cargarCategoriasGastos(true);
            if (nivel === '1') {
                const s = document.getElementById('cat_gasto');
                if (s) { s.value = ''; s.dispatchEvent(new Event('change')); }
            } else if (nivel === '2') {
                const s = document.getElementById('subcat_gasto');
                if (s) { s.value = ''; s.dispatchEvent(new Event('change')); }
            }
            cambiarNivelGestion();
            document.getElementById('mg_parent').value = pId;
            renderListaCategorias();
            Swal.fire('Borrado', 'Categoría eliminada', 'success');
        } else {
            Swal.fire('Error', d.message, 'error');
        }
    } catch(e) {
        Swal.fire('Error', 'Error de red', 'error');
    }
}

window.cargarDashboardKPIs = function() {
    if (document.getElementById('kpiIngresosTotales')) {
        fetch('../api/finanzas_api.pl', { method: 'POST', body: new URLSearchParams({action: 'get_dashboard'}), credentials: 'same-origin' })
            .then(r => r.json())
            .then(dash => {
                if (dash.success) {
                    const eIT = document.getElementById('kpiIngresosTotales');
                    const eCC = document.getElementById('kpiCuentasCobrar');
                    const eF = document.getElementById('kpiFacturacion');
                    const eEC = document.getElementById('kpiEficiencia');
                    const eEgresos = document.getElementById('kpiTotalEgresos');
                    const eCotizaciones = document.getElementById('kpiPresupuestosActivos');
                    
                    if (eIT) eIT.innerText = formatter.format(dash.ingresos || 0);
                    if (eCotizaciones) eCotizaciones.innerText = formatter.format(dash.cotizaciones || 0);
                    if (eCC) eCC.innerText = formatter.format(dash.cxc || 0);
                    if (eEgresos) eEgresos.innerText = formatter.format(dash.gastos || 0);
                    if (eF) eF.innerText = formatter.format(dash.ingresos || 0);
                    if (eEC) {
                        let cargos_totales = (dash.ingresos || 0) + (dash.cxc || 0);
                        let eff = cargos_totales > 0 ? (dash.ingresos / cargos_totales * 100) : 0;
                        eEC.innerText = eff.toFixed(1) + '%';
                    }
                    if (typeof actualizarPieChartDashboard === 'function') {
                        actualizarPieChartDashboard(dash.ingresos || 0, dash.gastos || 0);
                    }
                    if (typeof renderEvolucionIngresosGlobal === 'function') {
                        renderEvolucionIngresosGlobal();
                    }
                }
            });
    }
};

var pieFinanzasInstance = pieFinanzasInstance || null;
function actualizarPieChartDashboard(ingresos, egresos) {
    const canvas = document.getElementById('pieResumenFinanzas');
    if (!canvas) return;
    
    if (pieFinanzasInstance) {
        pieFinanzasInstance.destroy();
    }
    
    const centerVal = document.getElementById('pieCenterValFinanzas');
    if(centerVal) centerVal.innerText = formatter.format(ingresos + egresos);
    
    const legIngresos = document.getElementById('legIngresosFinanzas');
    const legEgresos = document.getElementById('legEgresosFinanzas');
    if(legIngresos) legIngresos.innerText = formatter.format(ingresos);
    if(legEgresos) legEgresos.innerText = formatter.format(egresos);
    
    const ctx = canvas.getContext('2d');
    
    // Metallic Green (Ingresos)
    const gradVerde = ctx.createLinearGradient(0, 0, 0, 160);
    gradVerde.addColorStop(0, '#00FF7F');
    gradVerde.addColorStop(0.5, '#007A3D');
    gradVerde.addColorStop(1, '#003D1F');
    
    // Metallic Red (Egresos)
    const gradRojo = ctx.createLinearGradient(0, 0, 0, 160);
    gradRojo.addColorStop(0, '#FF4D4D');
    gradRojo.addColorStop(0.5, '#A63A3A');
    gradRojo.addColorStop(1, '#5C0000');

    // Bevel Gradient for Border
    const borderGrad = ctx.createLinearGradient(0, 0, 0, 160);
    borderGrad.addColorStop(0, 'rgba(255, 255, 255, 0.85)');
    borderGrad.addColorStop(0.2, 'rgba(255, 255, 255, 0.3)');
    borderGrad.addColorStop(0.8, 'rgba(0, 0, 0, 0.15)');
    borderGrad.addColorStop(1, 'rgba(0, 0, 0, 0.7)');

    const dashboard3DPlugin = {
        id: 'dashboard3DPlugin',
        beforeDraw: (chart) => {
            const chartCtx = chart.ctx;
            chartCtx.save();
            // Sombra base suave
            chartCtx.shadowColor = 'rgba(0, 0, 0, 0.4)';
            chartCtx.shadowBlur = 20;
            chartCtx.shadowOffsetX = 0;
            chartCtx.shadowOffsetY = 15;
        },
        afterDraw: (chart) => {
            chart.ctx.restore();
            if (!chart.getDatasetMeta(0).data[0]) return;
            const ctx = chart.ctx;
            const x = chart.chartArea.left + chart.chartArea.width / 2;
            const y = chart.chartArea.top + chart.chartArea.height / 2;
            const outerRadius = chart.getDatasetMeta(0).data[0].outerRadius;
            const innerRadius = chart.getDatasetMeta(0).data[0].innerRadius;
            const thickness = outerRadius - innerRadius;

            ctx.save();
            
            // 1. Efecto Extrusión/Bisel Exterior (Outer Bevel)
            ctx.beginPath();
            ctx.arc(x, y, outerRadius - 1, 0, Math.PI * 2);
            ctx.lineWidth = 4;
            const outerBevelGrad = ctx.createLinearGradient(x, y - outerRadius, x, y + outerRadius);
            outerBevelGrad.addColorStop(0, 'rgba(255, 255, 255, 0.85)'); // Resplandor metálico puro
            outerBevelGrad.addColorStop(0.2, 'rgba(255, 255, 255, 0)');
            outerBevelGrad.addColorStop(0.8, 'rgba(0, 0, 0, 0)');
            outerBevelGrad.addColorStop(1, 'rgba(0, 0, 0, 0.5)'); 
            ctx.strokeStyle = outerBevelGrad;
            ctx.globalCompositeOperation = 'source-over';
            ctx.stroke();

            // 2. Efecto Extrusión/Bisel Interior (Inner Bevel)
            ctx.beginPath();
            ctx.arc(x, y, innerRadius + 1, 0, Math.PI * 2);
            ctx.lineWidth = 4;
            const innerBevelGrad = ctx.createLinearGradient(x, y - innerRadius, x, y + innerRadius);
            innerBevelGrad.addColorStop(0, 'rgba(0, 0, 0, 0.5)'); 
            innerBevelGrad.addColorStop(0.2, 'rgba(0, 0, 0, 0)');
            innerBevelGrad.addColorStop(0.8, 'rgba(255, 255, 255, 0)');
            innerBevelGrad.addColorStop(1, 'rgba(255, 255, 255, 0.85)'); 
            ctx.strokeStyle = innerBevelGrad;
            ctx.stroke();

            // 3. Brillo Especular Superior (Glossy Highlight)
            ctx.beginPath();
            ctx.arc(x, y, outerRadius, Math.PI, Math.PI * 2);
            ctx.arc(x, y, innerRadius, Math.PI * 2, Math.PI, true);
            ctx.closePath();
            
            const glossTop = ctx.createLinearGradient(x, y - outerRadius, x, y);
            glossTop.addColorStop(0, 'rgba(255, 255, 255, 0.7)'); // Destello fuerte arriba
            glossTop.addColorStop(0.2, 'rgba(255, 255, 255, 0.1)'); // Corte brusco (metálico)
            glossTop.addColorStop(0.3, 'rgba(255, 255, 255, 0)');
            ctx.fillStyle = glossTop;
            ctx.fill();

            // 4. Reflejo Secundario Inferior
            ctx.beginPath();
            ctx.arc(x, y, outerRadius, 0, Math.PI);
            ctx.arc(x, y, innerRadius, Math.PI, 0, true);
            ctx.closePath();
            
            const glossBottom = ctx.createLinearGradient(x, y, x, y + outerRadius);
            glossBottom.addColorStop(0, 'rgba(0, 0, 0, 0)');
            glossBottom.addColorStop(0.7, 'rgba(0, 0, 0, 0.1)');
            glossBottom.addColorStop(1, 'rgba(0, 0, 0, 0.4)');
            ctx.fillStyle = glossBottom;
            ctx.fill();

            ctx.restore();
        }
    };

    pieFinanzasInstance = new Chart(ctx, {
        type: 'doughnut',
        plugins: [dashboard3DPlugin],
        data: {
            labels: ['Ingresos', 'Egresos'],
            datasets: [{
                data: [ingresos, egresos],
                backgroundColor: [gradVerde, gradRojo],
                borderColor: [borderGrad, borderGrad],
                borderWidth: 4,
                hoverOffset: 6
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            cutout: '58%',
            layout: { padding: 12 },
            plugins: {
                legend: { display: false },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return context.label + ': ' + formatter.format(context.raw);
                        }
                    }
                }
            }
        }
    });
}
