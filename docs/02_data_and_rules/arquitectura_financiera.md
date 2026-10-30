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
  `ID_GASTO|FECHA|ID_CAT|ID_SUBCAT|ID_SUBCAT3|CONCEPTO|MONTO|PROVEEDOR|FACTURA_PATH|ID_ORIGEN|ID_CREADOR|ID_NEGOCIO|ID_ESPECIALIDAD|ID_MEDICO|RECIBOS_ASOCIADOS`
  - Toda inserción o consulta de gastos DEBE aislarse por `ID_NEGOCIO` (columna índice `[11]`).
  - Columnas extendidas para liquidación de honorarios médicos:
    * `[12] ID_ESPECIALIDAD`: Identificador de la especialidad médica.
    * `[13] ID_MEDICO`: Identificador o clave del médico tratante.
    * `[14] RECIBOS_ASOCIADOS`: Cadena separada por comas con los folios de recibos privados amparados (ej. `28858,28859`).
- **Regla Anti-Confusión `ID_ORIGEN` vs `ID_NEGOCIO`**:
  Queda estrictamente prohibido utilizar la columna `[9]` (`ID_ORIGEN`) para filtrar por empresa. El índice `[9]` corresponde al identificador del medio de pago en `dat/origen_dinero.dat`. Toda validación multi-tenant debe ejecutarse sobre el índice `[11]`.
- **Orígenes del Dinero (`dat/origen_dinero.dat`)**:
  `ID_ORIGEN|NOMBRE|DESC|ID_NEGOCIO`
  Cada organización mantiene sus propios orígenes de dinero (cajas chicas, cuentas bancarias, terminales). Al registrar una nueva organización, el sistema auto-siembra los 4 orígenes iniciales vinculados a su `ID_NEGOCIO`.
- **Categorías de Gastos (`dat/categorias.dat`, `dat/sub_categoria.dat`, `dat/sub_categoria_nivel3.dat`)**:
  `ID|NOMBRE|DESC|ID_NEGOCIO`
  Las categorías, subcategorías y niveles de detalle operan de manera autónoma por tenant. Si una organización no cuenta con categorías personalizadas, se auto-siembra el árbol base vinculado a su `ID_NEGOCIO`, garantizando que ediciones o eliminaciones no alteren a otros tenants.

### 2.9 Comprobante de Egreso y Control Operativo (`api/imprimir_recibo_gasto.pl`)
- **Naturaleza y Objetivo**: Documento oficial de egreso operativo emitido por la organización para amparar y justificar salidas de efectivo, cheques o transferencias hacia proveedores, insumos y gastos operativos.
- **Acceso desde DataTables**: La tabla `#tablaGastos` en `views/finanzas.pl?tab=gastos` incorpora en su columna *Acciones* el botón interactivo con icono de recibo (`bi bi-receipt`), disparando la función `abrirReciboGasto(idGasto)` hacia `api/imprimir_recibo_gasto.pl?id_gasto=...`.
- **Jerarquía de Importancia en Impresión**:
  1. **Proveedor o Médico / Beneficiario**: Resaltado como dato primordial en cabecera con tipografía destacada y borde teal. Si el gasto corresponde a honorarios médicos y el proveedor coincide con el especialista, la etiqueta se unifica a `Médico / Beneficiario :` eliminando filas redundantes.
  2. **Categoría y Clasificación Contable**: Despliegue jerárquico de Categoría Principal, Subcategoría y Nivel 3.
  3. **Especialidad Médica**: En egresos clínicos, se visualiza con badge contrastado.
  4. **Desglose Tabular de Recibos Amparados**: Cuando ampara recibos de ingresos, despliega una tabla estructurada con columnas auditables: `Folio Recibo`, `Fecha`, `Paciente Real`, `Servicio / Concepto Médico` e `Importe ($)`. Incluye cómputo automático de total cobrado y retención/comisión de la clínica si el monto liquidado al médico difiere del total cobrado.
  5. **Concepto y Justificación**: Descripción del egreso con indicación de comprobante fiscal adjunto si existe (`factura_path`).
  6. **Origen de Fondos**: Medio o caja dispersora (`dat/origen_dinero.dat`).
  7. **Monto en Número y Letra**: Cifra numérica formal (`$XX,XXX.XX`) acompañada de su transcripción legal en texto en pesos mexicanos (`(SON: ... PESOS XX/100 M.N.)`).
  8. **Auditoría y Doble Firma**: Bloque de firmas formales de control interno: *Entrega / Autoriza (Control Caja)* y *Recibe Conforme (Beneficiario)*.

### 2.10 Liquidación Dinámica de Honorarios Médicos y Consultas (`#modalGasto`)
- **Detección Condicional por Categoría**:
  Al seleccionar una categoría que contenga las palabras `honorarios`, `consultas especialidad` o `consultas generales` (insensible a mayúsculas/minúsculas):
  - El modal de egresos `#modalGasto` despliega un contenedor dinámico (`#contenedor_honorarios_medicos`) con borde cian y fondo suave.
  - Para categorías operativas estándar ("Insumos", "Papelería", "Mantenimiento", "Sin Categoría", etc.), este contenedor permanece estrictamente oculto (`display: none`).
- **Campos Médicos Integrados (UI/UX)**:
  1. **Especialidad Médica**: Selector poblado dinámicamente desde `api/finanzas_api.pl?action=get_medicos_especialidades`. Al cambiar de especialidad, filtra en cascada el catálogo de médicos tratantes.
  2. **Médico Tratante (Anti-Duplicidad)**: Selector del especialista con deduplicación dual (backend y frontend) por identificador y nombre normalizado, evitando repeticiones provenientes de múltiples catálogos. Al seleccionar un médico:
     - Auto-llena el campo `Proveedor / Beneficiario` con el nombre del médico.
     - Consulta de forma asíncrona sus recibos de consulta activos mediante `api/finanzas_api.pl?action=get_recibos_medico&id_medico=...&nombre_medico=...`.
  3. **Recibos de Ingresos Asociados (Checklist Múltiple con Paciente y Concepto)**:
     - Desplegable tipo dropdown con checkboxes individuales por recibo.
     - Cada elemento visualiza de forma estructurada: `Folio`, `Importe ($)`, `Fecha`, `Nombre Real del Paciente` (resuelto exhaustivamente desde `pacientes_privados_<CLUES>.dat`, `estado_cuenta.dat` y `pacientes.dat`) y `Concepto / Servicio Médico` (desglosado desde el payload de items JSON).
     - Permite selección individual o múltiple ("Seleccionar / Deseleccionar Todos").
     - **Auto-cálculo y Sugerencia**: La suma acumulada de los recibos seleccionados se calcula en tiempo real; si el campo `Monto ($)` está en $0.00 o coincide con el cálculo anterior, se auto-actualiza automáticamente. El campo `Concepto` se pre-redacta sugiriendo los folios amparados (ej. `Honorarios Médicos - DRA HYPATIA GUILLEN (Recibos: #28988, #28983)`).
- **Motor de Resolución Inteligente y Bidireccional de Recibos Médicos (`get_recibos_medico`)**:
  - En la práctica operativa de emisión de recibos en caja rápida o mostrador, el especialista puede registrarse con variantes en el nombre (ej. `DR VICTOR TSUTSUMI` en recibos de consulta vs `DR VICTOR TSUTSUMI HARA` en el catálogo de médicos), o bien la columna `id_medico` en `folios_recibos_privados.dat` almacena el ID del ítem de consulta en lugar del ID numérico del médico (ej. items `4` y `14` para Consulta Traumatología).
  - Para erradicar falsos negativos y garantizar 100% de recuperabilidad:
    1. **Mapeo Cruzado de Ítems de Consulta**: El backend indexa `catalogo_items_<CLUES>.dat` para asociar los IDs de conceptos de consulta de cada especialidad con el médico correspondiente.
    2. **Normalización y Matching Bidireccional de Tokens**: Se eliminan prefijos de título profesional (`DR`, `DRA`, `LIC`, `MEDICO`, etc.) y se evalúa coincidencia bidireccional (A dentro de B o B dentro de A), así como intersección de tokens mayores a 3 caracteres entre el catálogo de médicos y el payload de items de cada recibo.
    3. **Trazabilidad en Impresión**: `api/imprimir_recibo_gasto.pl` replica idéntica lógica heurística bidireccional sobre el campo `proveedor` para resolver el médico y su especialidad al emitir el comprobante formal de egreso.
- **Aislamiento Multi-Tenant de Categorías y Sanitización UTF-8**:
  - En la vista previa e impresión de comprobantes de egreso (`api/imprimir_recibo_gasto.pl`), la resolución de la categoría principal, subcategorías y origen de dinero evalúa de forma obligatoria el `ID_NEGOCIO` del gasto, erradicando confusiones con registros homónimos de otros consultorios (ej. ID 2 = Honorarios Médicos en tenant 723800 vs Marketing en tenant 0).
  - Integración de función reparadora de secuencias UTF-8 (`reparar_utf8`), previniendo cualquier anomalía de Mojibake (doble codificación) en pantalla o impresión PDF.
- **Persistencia y Retrocompatibilidad**:
  Los valores capturados (`id_especialidad`, `id_medico`, `recibos_asociados`) se transmiten al backend `api/finanzas_api.pl?action=save_gasto` y se almacenan en las columnas `[12]`, `[13]` y `[14]` de `dat/gastos.dat`. Si los valores no son enviados explícitamente en el payload pero existen en el texto del concepto o proveedor, el backend ejecuta auto-inferencia inteligente para salvaguardar la trazabilidad. Registros históricos previos a esta versión mantienen compatibilidad íntegra gracias al manejo de valores por defecto vacíos.

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
   - Está estrictamente prohibido generar cargos inventados de "Consulta Médica" por el monto del abono recibido ni volver a inyectar como cargo nuevo la cotización global original.
   - En el frontend (`views/partials/consultas/step_caja_privado.pl`), la bandera `isNuevaConversion` se condiciona con `!isTratamientoActivo`, impidiendo que los ítems del tratamiento presupuestado se dupliquen dentro de la tabla de cobros ni inflen el saldo pendiente acumulado.
   - En el backend (`api/cerrar_consulta_privado.pl`), las consultas de seguimiento de un tratamiento activo (`$es_tratamiento_existente`) no adicionan `$total_cot` como cargo exigible de esa sesión, fijando como base de cobranza el saldo global pendiente del paciente (`$saldo_global_paciente`).
   - El importe entregado por el paciente (ej. $1,000.00 en la 2ª cita) se asienta como abono al tratamiento preexistente, amortizando la deuda de $2,200.00 a un nuevo saldo remanente de $1,200.00 en el recibo (`Folio #2`).

3. **Liquidación Final, Cierre Automático y Desglose Transparente de Totales**:
   - Al cubrirse el saldo remanente (ej. $1,200.00 en la 3ª cita), el sistema asienta el abono, marca el `Saldo Remanente` en `$0.00 (Liquidado)`, actualiza el tratamiento en `dat/tratamientos.dat` a `ESTADO = Cerrado` con su `FECHA_FIN` y emite su comprobante consecutivo (`Folio #3`) con estatus `Liquidado`.
   - En `api/imprimir_recibo_caja_consultorio.pl`, se audita dinámicamente la secuencia de pagos del tratamiento en `dat/estado_cuenta.dat`: desglosando `Total Tratamiento`, `Abonos Anteriores (-$)`, `IMPORTE COBRADO`, `Total Pagado Acumulado` y `Saldo Remanente ($0.00 Liquidado)`, evitando discrepancias o falsos saldos en contra del paciente.

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

---

## 8. Gobernanza de KPIs del Dashboard Principal y Sincronización Multi-Rol (Día Actual 00:00 - 24:00 hrs)

Para garantizar la máxima integridad contable y apego al control de acceso basado en roles (RBAC):

1. **Ventana Temporal Canónica (Día Actual)**:
   - Los indicadores de desempeño financiero en el Tablero Principal (`views/render_dashboard_principal.pl`) calculan exclusivamente los movimientos comprendidos de **00:00 a 24:00 hrs del día en curso** (`$hoy_str = YYYY-MM-DD`). Queda prohibido sumar acumulados históricos sin filtro de fecha en la vista principal.

2. **Matriz RBAC de Visibilidad por Rol**:
   - **Administrador Organización / Soporte**: Dispone del consolidated view; computa el acumulado de todos los usuarios pertenecientes a su clínica (`id_empresa`).
   - **Recepcionista**: Computa **única y exclusivamente los recibos generados personalmente** durante su turno del día (`elaborado_por == $usuario`). Además, **el KPI `CxC Estado` se oculta por completo**, ajustando el tablero a 4 tarjetas (`row-cols-md-4`), ya que la recepción administra caja física y no cuentas por cobrar de convenios gubernamentales.
   - **Médico**: Computa exclusivamente los recibos correspondientes a sus propias consultas o atenciones registradas en el día (`id_medico == $id_medico` o `elaborado_por == $usuario`).

3. **Sincronización Bidireccional Datatables - KPIs**:
   - Los totales exhibidos en las tarjetas KPI (`#kpiValorIngresos` y `#kpiValorCxcEstado`) corresponden exactamente a la suma calculada por `api/generar_corte_caja.pl` para el rango del día actual y se sincronizan reactivamente en los pies de tabla (`#tfootTotalPrivados` y `#tfootTotalMunicipio`), garantizando que no existan discrepancias entre las tarjetas superiores y las tablas detalladas.

---

## 9. Gobernanza UI/UX del Resumen Financiero y Navegación Dual en Sidebar

1. **Navegación Dual al Módulo Financiero (Sidebar UX)**:
   - Al pulsar el encabezado de "Finanzas" en el menú lateral principal (`utils/sub_sidebar.pl`), el sistema navega directamente a `views/finanzas.pl`, abriendo de inmediato el Resumen General y desplegando automáticamente el menú con todos sus sub-módulos operativos.
   - Si el usuario ya se encuentra dentro de `views/finanzas.pl` en otra pestaña (ej. Egresos o Corte de Caja), hacer clic en "Finanzas" conmuta de inmediato a la pestaña `#tab_resumen` sin recargar la página.
   - Se erradica por completo el sub-ítem redundante "Resumen General" del interior del acordeón.

2. **Jerarquía Visual en 3 Capas (Azul Marino + Blanco + Bordes Teal)**:
   - **Capa 1 (Hero KPIs - Flujo de Efectivo)**: Tarjetas destacadas en 3 columnas: Ingresos Reales Cobrados (`#kpiIngresosTotales`), Total Gastos (`#kpiTotalEgresos`) y Utilidad Neta & Margen (`#kpiUtilidadNeta`), con bordes teal clínicos (`var(--md-teal-clinical, #19B7A5)`), tipografía en Azul Marino (`#0A2A66`) y fondo blanco puro.
   - **Capa 2 (Operación y Cobranza)**: Fila simétrica de 4 columnas que agrupa Cuentas por Cobrar Privadas (`#kpiCuentasCobrar`), CxC Estado (`#kpiCxcEstado` según capacidades SaaS), Recibos Emitidos (`#kpiTotalRecibos`) y Eficiencia de Cobro (`#kpiEficiencia`).
   - **Capa 3 (Analítica Visual Limpia)**: Gráfica de evolución semestral y dona de balance del periodo en tarjetas blancas con bordes teal sutiles, sustituyendo las esferas con degradados 3D por leyendas de indicadores planos y tipografía institucional legible.

3. **Homogeneización Visual en DataTables de Recepción (Dashboard Principal)**:
   - Se erradican las discrepancias de tamaño (`14px` vs `h5`), padding (`p-3` vs `p-4`) y estilos dispersos entre los contenedores de `#dtIngresosPrivados` e `#dtIngresosMunicipio` en `views/render_dashboard_principal.pl`.
   - Ambos contenedores adoptan el patrón unificado: tarjeta blanca sólida (`#FFFFFF`), bordes perimetrales en Teal clínico (`var(--md-teal-clinical, #19B7A5)`), cabeceras con cápsulas circulares de icono (38px), títulos estandarizados en `1.15rem` con tipografía Plus Jakarta Sans en Azul Marino (`#0A2A66`), subtítulos uniformes en `0.82rem` y badges temáticos discretos (*Efectivo / Ventanilla* vs *Convenio Institucional*).

4. **Dock Premium de Filtros, Título Sincronizado y Estandarización de Ingresos (`views/finanzas.pl`, `tab=ingresos`)**:
   - **Depuración de Encabezado Redundante y Sincronización Superior**:
     * La cabecera superior `.diamond-header-compact` (`#mainPageTitle` y `#mainPageSubtitle`) ahora se actualiza dinámicamente al alternar al tab:
       - **Título**: `<i class="bi bi-graph-up-arrow me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>Historial de Ingresos`
       - **Subtítulo**: `Filtro y registro de ingresos por rango de fecha.`
     * Se erradicó el encabezado redundante del cuerpo del tab, optimizando el espacio vertical en pantalla.
   - **Dock Premium con Borde Teal en Una Sola Fila**:
     * Implementación idéntica al dock de egresos con borde perimetral Teal Clínico (`1.5px solid var(--md-teal-clinical, #19B7A5)`), bordes redondeados (`14px`) y fondo blanco.
     * **Rango de Fechas (`.financial-date-range-bar`)**: Cápsula de fechas con inputs limpios y flecha separadora.
     * **Filtro Dinámico por Médico (Cápsula Ejecutiva)**:
       - Menú desplegable `#filtro_medico_ingresos` estilizado con opción por defecto `"Todos"`.
       - Detección y población automática del catálogo de médicos activos en el periodo consultado.
       - **Filtrado Reactivo Multi-Tabla**: Opera simultáneamente sobre las tablas `#dtIngresosPrivados` y `#dtIngresosMunicipio` (a pesar de las diferencias de columnas donde Municipio incluye la columna Dependencia y ambas convergen en la columna Médico), recalculando al instante los totales del pie de página sin latencia de red.
     * **Botón Filtrar**: Ubicado a la derecha con estilo píldora (`rounded-pill`) en Azul Marino (`#0A2A66`).
   - **Renombramiento Canónico de Tarjeta**:
     * Se actualizó la leyenda de la tarjeta de cobranza directa a `"Ingresos Privados"` (eliminando la denominación obsoleta `Ingresos (Efectivo / Privados)`).

5. **Dock Premium de Filtros y Egresos Operativos (`views/finanzas.pl`, `tab=gastos`)**:
   - **Depuración de Encabezado Redundante**:
     * Se erradicó el bloque duplicado de título/subtítulo que se mostraba en el cuerpo de `#tab_gastos`, dado que la cabecera general `.diamond-header-compact` (`#mainPageTitle` y `#mainPageSubtitle`) ya exhibe de forma nítida la redacción canónica y su icono:
       - **Título**: `<i class="bi bi-cash-stack me-2 text-danger"></i>Control de Egresos y Gastos Operativos`
       - **Subtítulo**: `Administración, comprobación y clasificación de gastos operativos, proveedores y pagos de la organización.`
   - **Dock Premium con Borde Teal en Una Sola Fila**:
     * Se refactorizó la barra de filtros integrando una tarjeta dock premium inspirada y estandarizada con el diseño del *Tablero Financiero Ejecutivo*:
       - Borde perimetral en Teal Clínico (`1.5px solid var(--md-teal-clinical, #19B7A5)`), fondo blanco y esquinas redondeadas (`border-radius: 14px`).
       - Disposición `flex` horizontal en una sola fila que agrupa controles de fecha, selectores en cápsula y botón de acción principal.
     * **Controles Cápsula (Executive Pills)**:
       - Rango de fechas (`.financial-date-range-bar`) con inputs limpios transparentes en cápsula fluida.
       - Selector de Categoría en píldora con borde translúcido teal (`rgba(25, 183, 165, 0.4)`), texto semibold y menú dinámico.
       - Selector de Subcategoría en cascada con estado inicial **Hidden** (`d-none` / `display: none`): permanece oculto hasta que se elija una categoría. Si la categoría seleccionada posee hijos, se despliega el selector con las opciones; de lo contrario, muestra la insignia `"Sin Subcategorias"` (`#badge_sin_subcat_gasto`).
       - **Botones de Acción**: Agrupados en el extremo derecho con el botón `Filtrar` (Azul Marino `#0A2A66`) posicionado inmediatamente a la izquierda del botón `+ Registrar Gasto` (Teal Clínico `#19B7A5`), ambos con acabado `rounded-pill`.
   - Modal `#modalGasto` armonizado con cabecera en Azul Marino/Teal y botón de guardado institucional.

6. **Eliminación y Depuración de Pestañas Redundantes de CxC (`views/finanzas.pl`, `tab=cxc` y `tab=cxc_estado`)**:
   - Se erradicaron por completo los contenedores y pestañas secundarias `#tab_cxc` y `#tab_cxc_estado` tanto de `views/finanzas.pl` como del acordeón de navegación de [utils/sub_sidebar.pl](file:///c:/xampp/htdocs/ospulso/utils/sub_sidebar.pl).
   - **Justificación de Arquitectura y UX**:
     * La cobranza privada se ejecuta en el punto de atención clínico: en el **Expediente del Paciente** (`views/pacientes.pl`), en el **Cierre de Consulta SOAP** (Paso 6) o en **Caja Rápida / Mostrador**, haciendo estéril una tabla plana de saldos globales en Finanzas.
     * Los recibos del Municipio (`CxC Estado`) ya cuentan con visualización filtrable en **Historial de Ingresos** (`#dtIngresosMunicipio`), en **Corte de Caja Diario** (`#dtCorteCxC`) y en el módulo dedicado de **Recibos Públicos** (`views/recibos_publicos.pl`), por lo que mantener una tercera tabla representaba redundancia innecesaria.
   - **Preservación Ejecutiva en Resumen General**:
     * Los indicadores macro `#kpiCuentasCobrar` y `#kpiCxcEstado` se conservan en la Capa 2 del Resumen General de Finanzas como tarjetas ejecutivas de lectura patrimonial pura (sin saltos a pestañas inexistentes), enlazando la gestión de saldos privados directamente al Padrón de Pacientes (`views/pacientes.pl`).
   - **Optimización de Rendimiento**:
     * Se eliminó la inicialización en el DOM de 2 instancias complejas de DataTables y sus llamadas AJAX asociadas (`renderCxC` y `renderCxcEstado`), aligerando la carga de la vista y la interacción en dispositivos móviles.




7. **Optimización UI/UX Móvil del Tablero Financiero Ejecutivo (Márgenes Cero y Padding Flush)**:
   - **Compresión de Márgenes y Padding Perimetral**:
     * Se eliminaron los paddings redundantes anidados (`.sdm-content` a 4px laterales en móviles, `.container-mobile-flush` con márgenes laterales en cero y `.card-mobile-flush` con bordes de 12px y padding compacto de 0.75rem/0.5rem), erradicando la pérdida de ~48px por lateral en resoluciones menores a 768px.
     * El encabezado `.diamond-header-compact` adopta padding compacto de 8px 12px y bordes integrados.
   - **Control Segmentado de Períodos (`#filterPillsGroup`)**:
     * Reemplazo de botones anchos fijos por un segmented control elástico (`flex: 1 1 0`) con `white-space: nowrap` y tipografía responsiva (0.72rem en móvil), eliminando el salto de línea de "Este Mes" que distorsionaba el botón en una esfera azul vertical fuera de proporción.
   - **Barra de Rango de Fechas Fluida (`.financial-date-range-bar`)**:
     * Reemplazo de inputs con ancho estático de 130px por inputs fluidos (`.financial-date-input` con `flex: 1`), evitando el desbordamiento horizontal fuera del borde perimetral de la tarjeta.
   - **Jerarquía Responsiva de KPIs (Capas 1, 2 y 3)**:
     * Aplicación de `.card-mobile-flush` en las tarjetas KPI y de analítica con espaciado uniforme `g-2 g-md-3`, tipografía optimizada para lectura rápida en pantallas pequeñas y preservación de contrastes de alta gama en Azul Marino (`#0A2A66`) y Teal Clínico (`#19B7A5`).

---

## 10. Segregación RBAC en Tablero Financiero (Recepcionista vs Administrador Organización)

1. **Principio de Segregación de Datos Personales vs Globales**:
   - Los datos consolidados, la cartera global de cuentas por cobrar privadas, las cotizaciones y los convenios públicos (`CxC Estado`) son de consulta **exclusiva del Administrador Organización**.
   - El usuario con rol **Recepcionista** visualiza única y exclusivamente los datos que ha capturado personalmente durante sus turnos de caja:
     * **Ingresos Reales**: Suma estricta de sus propios recibos emitidos en [dat/folios_recibos_privados.dat](file:///c:/xampp/htdocs/ospulso/dat/folios_recibos_privados.dat) (`ELABORADO_POR == $session_data->{usuario} || $session_data->{uid} || $session_data->{correo_login}`).
     * **Prohibición de Fallback a `estado_cuenta.dat`**: Queda estrictamente prohibido aplicar fallbacks a abonos de `estado_cuenta.dat` para el rol Recepcionista. Si la recepcionista no ha emitido recibos en el periodo seleccionado, su monto de ingresos reales es estrictamente **$0.00**.
     * **Total Gastos**: Registros de [dat/gastos.dat](file:///c:/xampp/htdocs/ospulso/dat/gastos.dat) creados por su usuario (`ID_CREADOR == $session_data->{usuario}`).
     * **Cuentas por Cobrar y Cotizaciones**: Puestas en $0.00 y omitidas en la Capa 2 para recepcionistas, ya que no administra créditos clínicos ni carteras institucionales.

2. **Adaptación de la Interfaz según Rol (`views/finanzas.pl`)**:
   - **Para Recepcionista**:
     * Encabezado: *"Mi Tablero de Caja / Turno"* con subtítulo *"Métricas personales de cobranza, recibos y turno activo"*.
     * Badges: *"Cobrado Personal"*, *"Egresos Personales"*, *"Flujo de Turno"*.
     * Capa 2: Grilla compacta de 2 columnas enfocada en *Recibos Emitidos (Personales)* y *Eficiencia Cobro Turno* (ocultando CxC Privadas y CxC Estado).
   - **Para Administrador Organización**:
     * Mantiene el consolidado macro de 3 capas con visión global de la clínica.
