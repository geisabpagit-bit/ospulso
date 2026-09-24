function resaltarHoraActual() {
    const ahora = new Date();
    const horas = ahora.getHours();
    const minutos = ahora.getMinutes();
    
    // Redondeamos a la media hora más cercana hacia abajo (ej: 08:45 -> 08:30)
    const bloqueMinutos = minutos < 30 ? "00" : "30";
    const horaFormateada = `${horas}:${bloqueMinutos}`;
    // Ajuste para horas de un solo dígito como "8:00"
    const horaFormateadaCorta = `${horas}:${bloqueMinutos}`; 

    // 1. Quitamos el resaltado previo
    document.querySelectorAll('.agenda-fila-actual').forEach(el => {
        el.classList.remove('agenda-fila-actual');
    });

    // 2. Buscamos la fila que coincide
    const celdasHoras = document.querySelectorAll('.agenda-hora-cell');
    
    celdasHoras.forEach(celda => {
        const textoHora = celda.innerText.trim(); // Lee "8:00", "14:30", etc.
        
        if (textoHora === horaFormateada || textoHora === horaFormateadaCorta) {
            // Resaltamos el padre (la fila completa)
            const filaHora = celda.closest('.agenda-hora-row');
            const index = Array.from(filaHora.parentNode.children).indexOf(filaHora);
            
            // Resaltar la fila de la hora
            filaHora.classList.add('agenda-fila-actual');
            
            // Resaltar también la fila del slot correspondiente (está en la otra columna)
            const columnaSlots = document.querySelector('.agenda-slots-col');
            if (columnaSlots) {
                const filaSlot = columnaSlots.children[index];
                if (filaSlot) filaSlot.classList.add('agenda-fila-actual');
            }
        }
    });
}

// Ejecutar al cargar la página
document.addEventListener('DOMContentLoaded', () => {
    resaltarHoraActual();
    // Actualizar cada minuto
    setInterval(resaltarHoraActual, 60000);
});