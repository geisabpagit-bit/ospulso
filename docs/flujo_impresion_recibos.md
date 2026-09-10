# Protocolo Unificado de Impresión Controlada y Generación de Recibos

## 1. Visión General
Este documento reúne las normas, especificaciones de interfaz y reglas contables para la generación e impresión de **Recibos Privados** y **Recibos Públicos / Convenios** emitidos desde Caja Rápida o los módulos de cobranza del sistema.

---

## 2. Reglas Generales de Impresión Controlada

### 2.1 Erradicación del Auto-Disparo (`onload`) y Cierre Forzado
- **Comportamiento Canónico**: Todo recibo se despliega en una nueva pestaña del navegador como una vista estática e inspeccionable.
- **Prohibición**: Queda prohibido inyectar `onload="window.print()"` o funciones `afterprint` que fuercen el cuadro de diálogo inmediatamente o cierren la ventana al imprimir o cancelar.

### 2.2 Barra de Herramientas Interactiva (`.no-print`)
Todo recibo incluye una barra superior de acciones visible únicamente en pantalla:
1. **`🖨️ Imprimir Recibo`**: Ejecuta `window.print()` manualmente solo cuando el usuario lo decide.
2. **`← Volver / Cerrar`**: Dispara la función `volverPadre()`.
   - Si la ventana fue abierta como emergente/pestaña (`window.opener`), enfoca la ventana principal (`generar_recibo.pl`) y cierra la pestaña actual (`window.close()`).
   - Si se navegó directamente, ejecuta retorno en el historial (`history.back()`).

### 2.3 Regla CSS para Medios Impresos
```css
@media print {
    .no-print {
        display: none !important;
    }
}
```

---

## 3. Especificaciones por Tipo de Recibo

### 3.1 Recibo Privado (`api/imprimir_recibo_caja.pl`)
- **Naturaleza**: Cobro comercial directo en ventanilla a Pacientes Privados.
- **Fuente Canónica**: Inserción única en `dat/folios_recibos_privados.dat`.
- **Efectivo Real**: Representa ingreso físico de caja en efectivo, tarjeta o transferencia.
- **Contenido**: Folio consecutivo, desglose de IVA (16%), sello/firma del cajero y lista detallada de conceptos con su tarifa aplicada.

### 3.2 Recibo Público / Convenio (`api/imprimir_recibo_publico.pl`)
- **Naturaleza**: Orden de atención médica amparada bajo convenio gubernamental/municipal con subsidio.
- **Fuente Canónica**: Inserción en `dat/folios_recibos_publicos.dat`.
- **Contabilidad CXC Estado**: **NO constituye ingreso de efectivo físico en caja**. Se computa como Cuentas por Cobrar (CXC Estado) hasta su cobro institucional.
