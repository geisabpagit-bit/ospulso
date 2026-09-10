# Protocolo de Impresión y Flujo Controlado: Recibo Privado (`api/imprimir_recibo_caja.pl`)

## 1. Visión General
El script `api/imprimir_recibo_caja.pl` es responsable de generar la representación impresa y digital de los recibos de cobro privados emitidos a través de **Caja Rápida** o los módulos financieros del sistema.

---

## 2. Reglas del Flujo Controlado de Impresión

### 2.1 Erradicación del Auto-Disparo (`onload`) y Cierre Prematuro
- **Comportamiento Anterior (Deprecado)**: El script incluía `onload="window.print()"` y una función `afterprint` que cerraba automáticamente la ventana. Esto provocaba que el diálogo del sistema se abriera sin dar tiempo al usuario de revisar la pantalla y cerraba la pestaña intempestivamente si el usuario cancelaba.
- **Nuevo Comportamiento Canónico**: La vista se carga de forma estática en una nueva pestaña del navegador. No se fuerza el diálogo de impresión automáticamente.

### 2.2 Barra de Herramientas Superior (`.no-print`)
El encabezado del recibo incluye una barra de acciones interactiva visible solo en pantalla:
1. **`🖨️ Imprimir Recibo`**: Botón de acción con estilo accesible que ejecuta `window.print()` manualmente al hacer clic.
2. **`← Volver / Cerrar`**: Dispara la función `volverPadre()`.
   - Si la ventana fue abierta como una pestaña o ventana emergente (`window.opener`), devuelve el foco a la ventana principal (`generar_recibo.pl`) y cierra la pestaña actual (`window.close()`).
   - Si se navegó directamente, regresa al historial anterior (`history.back()`).

### 2.3 Regla CSS para Medios Impresos (`@media print`)
Para garantizar que la barra de herramientas no aparezca impresas en papel ni en exportaciones PDF:
```css
@media print {
    .no-print {
        display: none !important;
    }
}
```

---

## 3. Integridad Contable del Recibo Privado
- **Fuente Canónica**: Registro único en `dat/folios_recibos_privados.dat`.
- **Folio y Cadena Digital**: Incluye número de folio consecutivo, desglose de IVA (si aplica), forma de pago (Efectivo, Tarjeta, Transferencia), sello/firma del cajero y desglose detallado de conceptos.
