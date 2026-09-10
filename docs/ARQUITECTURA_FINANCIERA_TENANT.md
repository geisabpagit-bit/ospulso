# Arquitectura Financiera, Caja y Cobranza Multi-Tenant

## 1. Visión General
Este documento constituye la **Fuente Canónica de Verdad** para la arquitectura financiera, flujos de ingresos, cobranza y caja dentro de la plataforma OSPulso / SDM. Todas las modificaciones backend en `api/finanzas_api.pl`, `api/generar_corte_caja.pl`, `views/finanzas.pl`, `views/generar_recibo.pl` y reportes deben apegarse estrictamente a estos principios.

---

## 2. Los Cuatro Pilares Financieros Canónicos

### 2.1 Integridad Contable Bidireccional (Drilldown Transparente)
- Los indicadores de desempeño (KPIs) exhibidos en el Tablero Ejecutivo Financiero **DEBEN cuadrar al centavo** con la suma exacta de las transacciones desplegadas en las tablas detalladas (DataTables) para cualquier rango de fechas seleccionado.

### 2.2 Canales Coexistentes de Ingreso
1. **Flujo Clínico Canónico**: Originado desde la consulta médica SOAP, orden hospitalaria o estado de cuenta del expediente del paciente.
2. **Flujo de Caja Rápida / Mostrador**: Servicios ambulatorios directos, productos de farmacia, laboratorio o urgencias cobrados en ventanilla sin requerir consulta previa.
Ambos canales convergen en el flujo de caja operativo del tenant.

### 2.3 Fuente Canónica de Efectivo Real (Anti-Doble Contabilidad)
- La **fuente única e inviolable** de ingresos cobrados en efectivo/ventanilla es:
  `dat/folios_recibos_privados.dat` (o `dat/catalogos_CLUE/<CLUES>/folios_recibos_privados.dat`).
- **Regla Anti-Duplicación**: Queda estrictamente prohibido sumar de forma paralela `estado_cuenta.dat` y `folios_recibos_privados.dat` para calcular el flujo de efectivo global, dado que un estado de cuenta liquidado genera su recibo privado en `folios_recibos_privados.dat`, lo que duplicaría contablemente la recaudación.

### 2.4 Segregación de Flujo Real vs Cuentas por Cobrar (CXC Estado)
- **Ingreso Físico en Caja**: Efectivo, tarjetas bancarias y transferencias ingresadas vía recibos privados (`folios_recibos_privados.dat`).
- **Cuentas por Cobrar Convenios / Municipio**: Las atenciones registradas en `dat/folios_recibos_publicos.dat` corresponden a servicios amparados por convenio gubernamental con subsidio. **NO constituyen dinero en efectivo físico en caja**. Se computan en la categoría de **CXC Estado** hasta su cobro institucional.

---

## 3. Matriz Multi-Tarifa por Organización (`tipos_tarifas_<CLUES>.dat`)

1. **Definición Dinámica de Precios**:
   Cada concepto del catálogo universal (`catalogo_items_<CLUES>.dat`) puede asociar múltiples esquemas de precio en `catalogo_precios_<CLUES>.dat`:
   - `ESTANDAR`: Tarifa comercial base para público general.
   - `MUNICIPIO`: Tarifa convenida para beneficiarios de gobierno o sindicato.
   - `URGENCIAS`: Recargo por atención de urgencias fuera de horario.
   - `DOMINGOS_Y_FESTIVOS`: Recargo dominical / festivo.
   - `PAQUETE_TODO_INCLUIDO`: Precio paquete para intervenciones o estudios complejos.

2. **Selección y Reevaluación Dinámica en Recibos**:
   - En **Caja Rápida** (`views/generar_recibo.pl`), el usuario puede seleccionar libremente la tarifa aplicable por cada concepto agregado al carrito.
   - El sistema reevalúa unitarios, subtotales, IVA y total global en tiempo real sin romper el acumulado contable.
