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
- **Regla Anti-Duplicación**: Queda strictly prohibido sumar de forma paralela `estado_cuenta.dat` y `folios_recibos_privados.dat` para calcular el flujo de efectivo global, dado que un estado de cuenta liquidado genera su recibo privado en `folios_recibos_privados.dat`, lo que duplicaría contablemente la recaudación.

### 2.4 Segregación de Flujo Real vs Cuentas por Cobrar (CXC Estado)
- **Ingreso Físico en Caja**: Efectivo, tarjetas bancarias y transferencias ingresadas vía recibos privados (`folios_recibos_privados.dat`).
- **Cuentas por Cobrar Convenios / Municipio**: Las atenciones registradas en `dat/folios_recibos_publicos.dat` corresponden a servicios amparados por convenio gubernamental con subsidio. **NO constituyen dinero en efectivo físico en caja**. Se computan en la categoría de **CXC Estado** hasta su cobro institucional.

### 2.5 Aislamiento por Empresa/Sucursal (ID_NEGOCIO|ID_SUCURSAL) con Consumo Multi-Rol Unificado
- Toda generación de recibos (privados o públicos) realizada por cualquier usuario o rol dentro de una misma empresa y sucursal (`ID_NEGOCIO|ID_SUCURSAL`) DEBE consultar e incrementar una **única secuencia consecutiva atómica compartida** para dicha sucursal en `dat/catalogos_CLUE/<CLUES>/contadores_recibos_privados_<CLUES>.dat` y `contadores_recibos_publicos_<CLUES>.dat`.
- Cada sucursal (`ID_NEGOCIO|ID_SUCURSAL`) mantiene su propio contador independiente dentro del catálogo de la organización, pero todos los roles de dicha sucursal (Recepcionista, Médico, Administrador, Especialista, etc.) consumen de forma unificada la misma secuencia consecutiva.

### 2.6 Blindaje Multi-Tenant Anti-Falsy '0' en Flat-Files (Regla de Oro)
- En Perl, el string `'0'` es considerado evaluativamente **falso** (`falsy`).
- Por tanto, está **estrictamente prohibido** utilizar condicionales de tipo `if ($id_empresa && $id_negocio)` o `$id_negocio = $f->[2] || ''`, ya que cuando una organización posee el ID `'0'` (ej. Cliente 1 / Matriz), el filtro se evalúa a falso y omite el descarte, filtrando datos de la organización 0 hacia nuevas organizaciones (ej. ID `1044365`).
- **Sintaxis Canónica Obligatoria**:
  ```perl
  my $id_negocio = $r[2] // '';
  $id_negocio =~ s/^\s+|\s+$//g;
  if (defined $id_empresa && $id_empresa ne '' && $role ne 'Administrador Global') {
      next if ($id_negocio ne $id_empresa);
  }
  ```
- Toda lectura de `folios_recibos_privados.dat`, `folios_recibos_publicos.dat`, `estado_cuenta.dat`, `gastos.dat` y `citas.dat` debe seguir esta convención para garantizar que una nueva organización inicie limpiamente en $0.00 de ingresos y egresos.

### 2.7 Gobernanza de Capacidades SaaS (`PACIENTES_ESTADO`) y Visibilidad de Tablas de Municipio
- Las organizaciones configuradas a través del módulo CRM SaaS (`views/crm_ventas.pl`) cuentan con flags de capacidades almacenados en `dat/negocios_config.dat` (`ID_ORG|PACIENTES_ESTADO|1|0`).
- **Comportamiento en `views/finanzas.pl` (`tab=ingresos`)**: Cuando `PACIENTES_ESTADO` no está activo (`0` o ausente para organizaciones secundarias/privadas), el DataTable `#dtIngresosMunicipio` y su tarjeta contenedora quedan completamente invisibles en la interfaz de usuario, renderizando únicamente `#dtIngresosPrivados`.
- **Comportamiento en Tablero Principal (`views/render_dashboard_principal.pl`)**:
  - El 5º KPI card ("CxC Estado") solo se renderiza si la organización cuenta con CLUE y la capacidad `PACIENTES_ESTADO` activa (`$has_pacientes_estado && $has_clue`). De lo contrario, se despliegan únicamente 4 tarjetas en `row-cols-md-4`.
  - En la vista de Recepcionista, el DataTable `#dtIngresosMunicipio` (últimas 24 hrs) también se suprime condicionalmente si `PACIENTES_ESTADO` no está activo.
- **Resiliencia de JavaScript**: Las funciones `renderTablaCorte(selector, ...)` implementan chequeo de existencia (`if (!$(selector).length) return;`) y los totales de tfoot validan la existencia del nodo en el DOM antes de actualizar montos, previniendo errores de ejecución.

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

---

## 4. Estándar de Reporte "Resumen Ejecutivo de Caja" (`views/finanzas.pl`)

1. **Gobernanza del Reporte Imprimible**:
   El informe generado al hacer clic en *"Imprimir Resumen"* en el tab de **Corte de Caja** (`tab=corte_caja`) debe incluir:
   - **Isotipo / Logo Institucional**: Renderizado en el extremo superior izquierdo del reporte desde `$negocio_logo_url`.
   - **Firma del Responsable**: Bloque centrado que muestra de forma explícita la firma y el nombre completo de la persona con sesión activa (`$session_data->{usuario}` / `responsable_login`).
   - **Pie del Reporte**: 
     - *Dirección de Sucursal*: Cadena estructurada igual a la del recibo de caja (`api/imprimir_recibo_caja.pl`).
     - *Fecha y Hora Larga*: Timestamp completo en formato español (ej. *Martes 22 de Septiembre de 2026, 07:18:50 PM*).
2. **Resiliencia de Payload**:
   La API `api/generar_corte_caja.pl` provee `responsable_login`, `logo_url`, `direccion_sucursal` y `fecha_hora_larga` en su objeto JSON para garantizar consistencia entre vista previa e impresión física (`@media print`).
