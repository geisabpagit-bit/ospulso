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
- **Comportamiento en `views/finanzas.pl` (`tab=ingresos` y `tab=corte_caja`)**: 
  - En **Ingresos**: Cuando `PACIENTES_ESTADO` no está activo (`0` o ausente para organizaciones secundarias/privadas), el DataTable `#dtIngresosMunicipio` y su tarjeta contenedora quedan completamente invisibles en la interfaz de usuario, renderizando únicamente `#dtIngresosPrivados`.
  - En **Corte de Caja Diario**: Si `PACIENTES_ESTADO` no está activo, el KPI `#cc_cxc` ("Ingresos Municipio") y la pestaña/tabla `#cc_tab_cxc` se omiten por completo, rebalanceando la grilla a 3 columnas (`col-md-4`) y manteniendo visibles exclusivamente `#dtCorteIngresos` y `#dtCorteEgresos`.
  - Ambas tablas (`#dtIngresosPrivados` y `#dtCorteIngresos`) disponen de la columna interactiva de **Acciones** para reimpresión y cancelación de recibos vía `api/ver_recibo.pl`.
- **Comportamiento en Tablero Principal (`views/render_dashboard_principal.pl`)**:
  - El 5º KPI card ("CxC Estado") solo se renderiza si la organización cuenta con CLUE y la capacidad `PACIENTES_ESTADO` activa (`$has_pacientes_estado && $has_clue`). De lo contrario, se despliegan únicamente 4 tarjetas en `row-cols-md-4`.
  - En la vista de Recepcionista, el DataTable `#dtIngresosMunicipio` (últimas 24 hrs) también se suprime condicionalmente si `PACIENTES_ESTADO` no está activo.
### 2.8 Aislamiento Multi-Tenant de Egresos, Categorías y Orígenes de Dinero
- **Esquema de Gastos (`dat/gastos.dat`)**:
  `ID_GASTO|FECHA|ID_CAT|ID_SUBCAT|ID_SUBCAT3|CONCEPTO|MONTO|PROVEEDOR|FACTURA_PATH|ID_ORIGEN|ID_CREADOR|ID_NEGOCIO`
  Toda inserción o consulta de gastos DEBE aislarse por `ID_NEGOCIO` (columna índice `[11]`).
- **Regla Anti-Confusión `ID_ORIGEN` vs `ID_NEGOCIO`**:
  Queda estrictamente prohibido utilizar la columna `[9]` (`ID_ORIGEN`) para filtrar por empresa. El índice `[9]` corresponde al identificador del medio de pago en `dat/origen_dinero.dat`. Toda validación multi-tenant debe ejecutarse sobre el índice `[11]`.
- **Orígenes del Dinero (`dat/origen_dinero.dat`)**:
  `ID_ORIGEN|NOMBRE|DESC|ID_NEGOCIO`
  Cada organización mantiene sus propios orígenes de dinero (cajas chicas, cuentas bancarias, terminales). Al registrar una nueva organización, el sistema auto-siembra los 4 orígenes iniciales vinculados a su `ID_NEGOCIO`.
- **Categorías de Gastos (`dat/categorias.dat`, `dat/sub_categoria.dat`, `dat/sub_categoria_nivel3.dat`)**:
  `ID|NOMBRE|DESC|ID_NEGOCIO`
  Las categorías, subcategorías y niveles de detalle operan de manera autónoma por tenant. Si una organización no cuenta con categorías personalizadas, se auto-siembra el árbol base vinculado a su `ID_NEGOCIO`, garantizando que ediciones o eliminaciones no alteren a otros tenants.

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

---

## 5. Gobernanza de Sincronización de Cuentas por Cobrar (CXC y CXC Estado) y Reset Operativo

1. **Sincronización Bidireccional de CxC Privadas**:
   - El KPI de *Cuentas por Cobrar (Saldos Privados)* en `views/finanzas.pl` (`#kpiCuentasCobrar`) y la API `api/finanzas_api.pl` (`get_resumen`) se calculan a partir de `dat/estado_cuenta.dat`, excluyendo de forma estricta los registros de pacientes institucionales (`^EMP-`).
   - El valor del KPI coincide exactamente al centavo con la suma de la columna de saldos pendientes en `tab=cxc` (`#tablaCxC`).

2. **Cómputo Canónico de CxC Estado (Convenios Públicos)**:
   - Los servicios otorgados a derechohabientes del Estado con subsidio al 100% no se registran como cargos en `estado_cuenta.dat`, sino que se asientan como órdenes/recibos en `dat/folios_recibos_publicos.dat`.
   - El KPI `#kpiCxcEstado` se obtiene sumando la columna `TOTAL_CARGOS` (índice 8) de `folios_recibos_publicos.dat` para recibos no cancelados del tenant (`id_negocio`), coincidiendo de forma idéntica con el pie de tabla de `tab=cxc_estado` (`#dtPublicosCxC`).

3. **Gobernanza del Reset Operativo sobre Cuentas por Cobrar**:
   - Al ejecutar el Reset Operativo (`api/reset_datos_organizacion_api.pl`), la purga de cuentas por cobrar en `estado_cuenta.dat` evalúa bidireccionalmente la pertenencia del registro tanto por médico tratante (`%uids_org`) como por paciente (`%pacientes_org`), garantizando que cargos generados sin médico asignado sean purgados y los saldos pendientes queden en $0.00.
   - En `api/get_recibos_caja_api.pl`, el filtro multi-tenant sobre `folios_recibos_publicos.dat` aplica de forma estricta la regla 2.6 para evitar que recibos de la organización matriz 0 se filtren hacia nuevas organizaciones.

4. **Autonomía de Categorías de Gastos**:
   - Las operaciones de edición y eliminación (`edit_categoria`, `delete_categoria`) en `api/finanzas_api.pl` validan la columna `id_negocio`, y los contadores en `dat/id_cat.counter`, `dat/id_subcat.counter` y `dat/id_subcat3.counter` se mantienen inicializados con valores superiores a los catálogos base para prevenir colisiones de ID entre organizaciones.

---

## 6. Arquitectura de Cobranza en Continuación de Tratamientos y Saldos Remanentes en Recibos

1. **Ciclo de Vida: Cotización -> Tratamiento Activo -> Abonos -> Liquidación**:
   - Una cotización seleccionada en una consulta se convierte en un registro en `dat/tratamientos.dat` (`ESTADO = Abierto`).
   - El monto presupuestado inicial (ej. $3,400.00) genera los cargos en `dat/estado_cuenta.dat`.
   - Si el paciente abona parcialmente (ej. $1,200.00), el recibo emitido (`Folio #1`) desglosa el `Total Servicios / Tratamiento ($3,400.00)`, el `IMPORTE COBRADO ($1,200.00)` y el **`Saldo Remanente ($2,200.00)`** con estatus `Cobrado` (En Proceso).

2. **Gobernanza de Consultas Subsecuentes (Continuación de Tratamiento)**:
   - Toda consulta de continuación vinculada a un tratamiento abierto o con saldo pendiente arrastrado tiene tarifa de **$0.00** por concepto de consulta de seguimiento.
   - Está estrictamente prohibido generar cargos inventados de "Consulta Médica" por el monto del abono recibido.
   - El importe entregado por el paciente (ej. $1,000.00 en la 2ª cita) se asienta como abono al tratamiento preexistente, amortizando la deuda de $2,200.00 a un nuevo saldo remanente de $1,200.00 en el recibo (`Folio #2`).

3. **Liquidación Final y Cierre Automático**:
   - Al cubrirse el saldo remanente (ej. $1,200.00 en la 3ª cita), el sistema asienta el abono, marca el `Saldo Remanente` en `$0.00 (Liquidado)`, actualiza el tratamiento en `dat/tratamientos.dat` a `ESTADO = Cerrado` con su `FECHA_FIN` y emite su comprobante consecutivo (`Folio #3`).

4. **Integridad de Folios y Blindaje Anti-Falsos Positivos**:
   - En `api/imprimir_recibo_caja_consultorio.pl`, la búsqueda del comprobante se realiza exclusivamente por coincidencia exacta de folio consecutivo (`c_folio`), identificador de recibo (`c_id`) o identificador de consulta (`c_cons`), prohibiendo el uso de expresiones regulares con terminación de dígitos.
   - En `views/render_expediente_clinico.pl`, se erradica la indexación por fecha de paciente (`PAC_id_fecha`), garantizando que cada consulta del expediente enlace unívocamente a su propio folio consecutivo sin usurpar el primer recibo del día.

---

## 7. Jerarquía Canónica de Procedencias del Recibo y Regla Antimultiplicación

Para garantizar la coherencia visual y contable entre la tabla de conceptos y el desglose de totales:

1. **Jerarquía Canónica de Procedencias para `NOTA / CONCEPTO` (Cabecera)**:
   - **Procedencia 1 (Cotización)**: Si la consulta tiene una cotización asignada, el concepto de cabecera es el **Nombre de la Cotización** (`dat/cotizaciones.dat`) y sus conceptos desglosados pasan a la tabla.
   - **Procedencia 2 (Odontograma)**: Si no tiene cotización pero cuenta con un odontograma asignado en el Paso 3 / Paso 6, el concepto de cabecera es el **Nombre/Alias del Odontograma** registrado en "Odontogramas Clínicos Disponibles", y sus tratamientos presupuestados pasan a la tabla.
   - **Procedencia 3 (Carrito Directo)**: Si no tiene cotización ni odontograma y se agregaron servicios/productos del carrito, el concepto de cabecera es `"Consulta Odontológica"` (especialidad dental) o `"Consulta Médica"` (otras especialidades), y los ítems del carrito pasan a la tabla.
   - **Procedencia 4 (Tratamiento por Saldo Pendiente o Continuación)**: Si la consulta genera un saldo pendiente ($cargos > $abono), se convierte automáticamente en un **Tratamiento Activo** (`dat/tratamientos.dat`). En consultas de continuación pura (abono a deuda sin nuevos servicios con costo), el concepto de cabecera es `"Abono a Cuenta de Tratamiento"` o `"Liquidación de Tratamiento"`.

2. **Regla Antimultiplicación de Ítems en la Tabla (Aritmética Coherente)**:
   - En consultas que ya contienen procedimientos clínicos con costo propio, la tabla de conceptos **debe listar única y exclusivamente los procedimientos clínicos reales** (ej. Pieza #42 de $950.00 y Pieza #47 de $850.00 = $1,800.00).
   - Está **estrictamente prohibido** inyectar una fila adicional de "Abono a Cuenta de Tratamiento" dentro de la tabla si ya existen cargos con costo en la sesión, ya que esto duplicaría artificialmente la suma de los renglones frente al importe cobrado.
   - La fila de concepto `Abono a Cuenta de Tratamiento` o `Liquidación de Tratamiento` se inserta en la tabla **únicamente** en consultas de seguimiento puro donde no hubo nuevos procedimientos clínicos (tarifa de consulta a $0.00).

