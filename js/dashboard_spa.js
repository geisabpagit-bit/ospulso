// --- Versión v3.2.0 (DEPRECADO - MIGRADO A SSR) ---
document.addEventListener('DOMContentLoaded', async () => {
    const safeSetText = (id, text) => {
        const el = document.getElementById(id);
        if (el) el.innerText = text;
    };

    const formatCurrency = (val) => {
        return new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(val);
    };

    try {
        const response = await fetch(`../api/dashboard_api.pl?accion=all&id_medico=\${CURRENT_ID_MEDICO}`);
        const data = await response.json();
        
        console.log("=== DASHBOARD API RESPONSE (v3.1.6.3 SUPREMA) ===");
        console.log(data);

        if (data.ok) {
            safeSetText('kpi-citas', data.stats.citas_hoy);
            safeSetText('kpi-pacientes', data.stats.pacientes_totales);
            safeSetText('kpi-cargos', formatCurrency(data.stats.cargos));
            safeSetText('kpi-abonos', formatCurrency(data.stats.abonos));

            const container = document.getElementById('lista-citas-container');
            if (container) {
                container.innerHTML = '';
                if (data.proximas_citas.length === 0) {
                    container.innerHTML = '<div class="text-center py-5"><p class="text-muted small fw-bold">No hay actividad programada para este rango.</p></div>';
                } else {
                    data.proximas_citas.forEach(cita => {
                        let bCol = 'bg-primary-subtle text-primary';
                        if(cita.estado === 'Confirmada') bCol = 'bg-success-subtle text-success';
                        else if(cita.estado === 'Cancelada') bCol = 'bg-danger-subtle text-danger';
                        
                        // Formatear etiqueta de fecha dinámica
                        let fechaEtiqueta = cita.fecha;
                        if(cita.fecha === data.rango.hoy) fechaEtiqueta = 'Hoy';
                        else if(cita.fecha === data.rango.ayer) fechaEtiqueta = 'Ayer';
                        
                        container.innerHTML += `
                            <div class="d-flex align-items-center justify-content-between p-3 bg-white rounded-4 mb-3 border shadow-sm" style="transition:0.3s">
                                <div style="flex-grow:1">
                                    <span class="d-block fw-bold text-navy mb-1" style="font-size:0.85rem;">${cita.nombre_paciente}</span>
                                    <div class="d-flex gap-2 align-items-center">
                                        <span class="badge border-0 px-2 py-1 \${fechaEtiqueta === 'Hoy' ? 'bg-primary text-white' : 'bg-light text-muted'}" style="font-size:0.6rem; border-radius:6px;">\${fechaEtiqueta}</span>
                                        <div class="vr opacity-25" style="height:10px"></div>
                                        <small class="text-muted fw-semibold" style="font-size:0.7rem;"><i class="bi bi-clock me-1"></i>\${cita.hora}</small>
                                    </div>
                                </div>
                                <div class="text-end">
                                    <span class="badge \${bCol} rounded-pill border-0 px-3 py-2 fw-bold" style="font-size:0.6rem; min-width:80px;">\${cita.estado.toUpperCase()}</span>
                                    <div class="mt-1" style="font-size:0.6rem; color:#94a3b8">\${cita.motivo}</div>
                                </div>
                            </div>
                        `;
                    });
                }
            }
        }
    } catch (e) {
        console.error("Dashboard Error:", e);
    }
});
