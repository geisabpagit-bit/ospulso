# Protocolo de Impresión y Flujo Controlado: Recibo Público / Convenio (`api/imprimir_recibo_publico.pl`)

## 1. Visión General
El script `api/imprimir_recibo_publico.pl` genera los recibos correspondientes a atenciones de pacientes amparados bajo convenios estatales o municipales. Representa una orden de servicio autorizada con subsidio público al 100% o cuotas reguladas por el municipio.

---

## 2. Reglas del Flujo Controlado de Impresión

### 2.1 Control de Navegación y No Auto-Print
- Al emitir una orden o recibo público desde Caja Rápida, el documento se visualiza en una nueva pestaña sin auto-disparo de impresión ni eventos `afterprint` intrusivos.

### 2.2 Toolbar de Acciones `.no-print`
- Se proporciona la barra superior estandarizada `.no-print` con los botones:
  - **`🖨️ Imprimir Recibo Público`**: Invocación manual de `window.print()`.
  - **`← Volver / Cerrar`**: Ejecución de `volverPadre()` para enfocar la pestaña origen (`generar_recibo.pl`) y cerrar la vista actual.

### 2.3 Regla CSS `@media print`
- Ocultamiento garantizado del Toolbar `.no-print` durante la impresión física o generación de PDF.

---

## 3. Naturaleza Financiera y Segregación Contable
- **Fuente Canónica**: Inserción en `dat/folios_recibos_publicos.dat`.
- **Diferenciación de Efectivo en Caja**: Los montos subsidiados por convenio municipal **NO constituyen ingreso físico en efectivo en caja**. Se computan como **Cuentas por Cobrar (CXC Estado)** en el Tablero Financiero hasta su posterior trámite de facturación y cobro institucional a la entidad pública.
