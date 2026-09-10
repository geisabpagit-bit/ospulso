# Reglas Generales de Impresión de Documentos y Recibos

## 1. Reglas de Impresión
1. **Acción Manual**: Toda ventana de impresión debe ser activada manualmente por el usuario desde la interfaz. Prohibido `onload="window.print()"`.
2. **Toolbar Oculto**: Todo control interactivo (`.no-print`) debe ocultarse en papel usando `@media print { .no-print { display: none !important; } }`.
3. **Control de Cierre**: La ventana no debe cerrarse automáticamente tras imprimir. Utilizar `volverPadre()` para control explícito del usuario.
