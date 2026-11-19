# Compendio de Reglas de Negocio del Sistema OSPulso / SDM

## 1. Arquitectura SOAP Polimórfica y Multi-Especialidad
1. **Contrato Canónico JSON SOAP**: Toda consulta clínica privada debe serializarse bajo las llaves canónicas SOAP (`subjective`, `objective`, `assessment`, `plan`). Los datos dinámicos de especialidad residen obligatoriamente en `soap.objective.especialidad_data`.
2. **Core Pipeline Único**: Registro, Agenda, Expediente, Firma y Cierre con Caja forman un flujo 100% único. Se prohíbe duplicar vistas completas por especialidad (ej. no crear `consulta_pediatria.pl`).
3. **Subformularios Desacoplados (Plugin Slot)**: Los componentes por especialidad residen en `views/partials/consultas/` o `views/partials/especialidades/`. De no contar con subformulario, se renderiza el fallback seguro.

---

## 2. Catálogo Universal 3NF y Estandarización por Tenant (CLUE)
1. **Jerarquía Rigurosa**: Los catálogos por organización deben mantener la relación `Departamento (ID_DEP) -> Categoría (ID_CAT) -> Item (ID_ITEM)`.
2. **Caso Específico Imagenología / Rayos X**:
   - `ID_DEP 4`: Departamento General **IMAGENOLOGIA**.
   - `ID_CAT 16`: Categoría **RAYOS X** (perteneciente a Imagenología).
3. **Normalización y Prefijos SKU**:
   - Los prefijos SKU deben coincidir con su categoría correspondiente (`LAB-` para Análisis Clínicos, `US-` para Ecografía/Ultrasonido, `RX-` para Rayos X, `CONS-` para Consultas Médicas).
   - Secuencia canónica de consultas: `CONS-0001` a `CONS-0832` sin saltos ni duplicados.

---

## 3. Paginación y Carga Server-Side (DataTables)
1. **Paginación por Defecto**: Todas las tablas administrables DataTables deben inicializarse con un límite por defecto de **10 registros por página** (`pageLength: 10`).
2. **Server-Side AJAX & `deferRender: true`**: En vistas con volúmenes extensos (`views/manage_catalogo_universal.pl`), los datos deben ser procesados en el servidor Perl (`api/crud_catalogo_universal_api.pl`) en lotes pequeños, evitando la inyección directa de miles de filas HTML en la carga inicial DOM.

---

## 4. Caja Rápida, Resumen de Carrito y Soporte Multi-Tarifa
1. **Exclusión de Departamento Consultas**: El modal de búsqueda de conceptos del carrito omite automáticamente los servicios del departamento `CONSULTAS` (`id_dep = 1`) para evitar duplicar el flujo médico de la cabecera.
2. **Multi-Tarifa por Concepto**:
   - Cuando un servicio cuenta con múltiples tarifas comerciales válidas (ej. `ESTÁNDAR`, `URGENCIAS`, `DOMINGOS Y FESTIVOS`), se despliega un selector `<select>` para que el usuario elija la tarifa aplicable.
   - La tarifa seleccionada se puede conmutar en el modal previo y directamente en la tarjeta del carrito (`.cart-item-card`), actualizando precios, subtotal, IVA y Total a Pagar en tiempo real.
3. **Tarifa Personalizada al Vuelo ("Otra") en Consultas**:
   - Para el departamento `CONSULTAS` (`id_dep = 1`), el selector `#selTarifaConsulta` integra de forma canónica la opción `"Otra (Tarifa Personalizada)"`.
   - Al seleccionarse, expone el campo numérico `#iptTarifaOtra` permitiendo al cajero establecer un costo libre/dinámico en caliente, el cual se propaga en tiempo real a `cartItems`, `renderCart()` y al total general.
   - Guardas de validación obligatorias: se bloquea la previsualización y emisión si la tarifa elegida es "Otra" y el monto es menor o igual a $0.00 o se encuentra vacío.
4. **Resumen de Carrito UI/UX**:
   - Contenedor flexible adaptable (`flex: 1 1 auto; min-height: 100px; max-height: 420px; overflow-y: auto;`).
   - Alineación al píxel exacto en la columna derecha para precios, subtotales, IVA y botón de emisión.

---

## 5. Protocolo de Impresión Controlada de Recibos
1. **Sin Auto-Print ni Cierre Automático**: Se prohíbe el uso de `onload="window.print()"` o eventos `afterprint` que cierren de forma forzada las ventanas de recibos.
2. **Toolbar `.no-print`**: Todo recibo (privado o público) debe desplegar una barra de acciones visible en pantalla con botones manuales para:
   - `🖨️ Imprimir Recibo` (`window.print()`).
   - `← Volver / Cerrar` (`volverPadre()`).
3. **Protección CSS**: La barra `.no-print` se oculta automáticamente durante la impresión física o generación de archivos PDF.

---

## 6. Integridad Contable y Segregación Financiera
1. **Fuente Canónica de Efectivo**: `dat/folios_recibos_privados.dat` es la única fuente de ingresos cobrados en efectivo en caja. No debe sumarse con `estado_cuenta.dat` para evitar doble contabilidad.
2. **Cuentas por Cobrar (Estado)**: Los recibos públicos subsidiados de `dat/folios_recibos_publicos.dat` corresponden a Cuentas por Cobrar (CXC Estado) y no constituyen dinero físico en la caja del cajero.

---

## 7. Estándares Técnicos de Codificación (Perl & JS)
1. **Escape de Comillas en JavaScript Inyectado desde Perl**: Al inyectar JavaScript en HEREDOCs dobles de Perl (`print <<"HTML"`), evitar comillas simples escapadas `\'` en cadenas JS delimitadas por comillas simples. Usar comillas dobles internamente o backticks de ES6.
2. **Protección de Sigilos**: Escapar símbolos de arroba como `\@media` en HEREDOCs dobles de Perl para prevenir errores de compilación `"Global symbol requires explicit package name"`.
3. **Persistencia UTF-8 LF**: Todo archivo de datos `.dat` debe manipularse con `:raw :encoding(UTF-8)`, bloqueo `flock` y fin de línea `\n` (0 CRLF).

---

## 8. Gobernanza RBAC y Excepciones por Usuario (User Overrides)
1. **Firma Canónica de Evaluación de 5 Parámetros**:
   - `utils::permisos_utils::tiene_permiso_modulo($id_empresa, $role, $modulo, $accion, $id_usuario)`.
   - Evalúa primero si el `$id_usuario` cuenta con una excepción grabada en `permisos_usuarios_[ID_EMPRESA].dat`. Si existe, su valor `C, R, U, D` prevalece sobre la matriz del rol.
2. **Lockout Protection Inviolable**:
   - Los roles `Administrador Global` y `Administrador Organizacion` mantienen garantizado de forma física en código el acceso CRUD completo a `usuarios`, `gestion_permisos`, `pacientes` y `agenda`, imposibilitando el autobloqueo administrativo accidental.
3. **Auto-Limpieza de Excepciones en Cambio de Rol**:
   - Al editar la cuenta de un colaborador en `api/editar_usuario_api.pl` y modificar su rol operativo, el backend ejecuta automáticamente `eliminar_overrides_usuario_org()` para purgar cualquier permiso excepcional previo y forzar la adopción limpia de su nuevo rol.
4. **Sincronización Dinámica de Menú Lateral**:
   - El componente `utils/sub_sidebar.pl` evalúa `tiene_permiso_modulo()` pasando el `$id_usuario_sesion` de la sesión activa, garantizando que si a un colaborador se le otorga o revoca un módulo mediante excepción individual, la opción se dibuje u oculte en tiempo real en la navegación.

---

## 9. Emisión de Recibos de Consultorio y Continuación de Tratamiento

1. **Jerarquía Canónica de Procedencias para `NOTA / CONCEPTO`**:
   - **Procedencia 1 (Cotización)**: Si la consulta tiene una cotización vinculada, la cabecera del recibo (`NOTA / CONCEPTO`) adopta obligatoriamente el **Nombre de la Cotización** (`dat/cotizaciones.dat`), y sus procedimientos pasan como ítems a la tabla.
   - **Procedencia 2 (Odontograma)**: Si no hay cotización pero se seleccionó un odontograma en el Paso 3 / Paso 6, la cabecera adopta el **Nombre/Alias del Odontograma** registrado en "Odontogramas Clínicos Disponibles", y sus tratamientos presupuestados pasan como ítems a la tabla.
   - **Procedencia 3 (Carrito Directo)**: Si no hay cotización ni odontograma y se agregaron servicios/conceptos directamente al carrito, la cabecera adopta `"Consulta Odontológica"` (para especialidad dental) o `"Consulta Médica"` (demás especialidades), y los ítems del carrito pasan como ítems a la tabla.
   - **Procedencia 4 (Tratamiento por Saldo Pendiente o Continuación)**: Si la consulta genera un saldo pendiente ($cargos > $abono), se convierte automáticamente en un **Tratamiento Activo** (`dat/tratamientos.dat`). En consultas de continuación pura (abono a saldo sin nuevos servicios clínicos con costo), la cabecera adopta `"Abono a Cuenta de Tratamiento"` o `"Liquidación de Tratamiento"`.

2. **Regla de Oro Antimultiplicación de Ítems (Aritmética Coherente)**:
   - En consultas que ya cuentan con procedimientos clínicos presupuestados o cargados con costo propio, la tabla de conceptos **debe listar exclusivamente los procedimientos clínicos reales** (ej. Pieza #42 de $950.00 y Pieza #47 de $850.00 = $1,800.00).
   - Está **estrictamente prohibido** inyectar una fila de "Abono a Cuenta de Tratamiento" dentro de la tabla si ya hay cargos con costo en la sesión, ya que esto duplicaría la suma visual frente al importe cobrado. El abono amortiza dichos procedimientos en el bloque inferior (`IMPORTE COBRADO`).
   - La fila de concepto `Abono a Cuenta de Tratamiento` o `Liquidación de Tratamiento` se inserta en la tabla de ítems **únicamente** en consultas de seguimiento puro donde no hubo nuevos procedimientos clínicos (tarifa de consulta a $0.00).

3. **Ciclo de Vida de Tratamientos a Abonos**:
   - En consultas subsecuentes de un tratamiento abierto con saldo pendiente:
     - La consulta médica aplica tarifa de **$0.00** (sin inventar cargos de consulta general por el monto del abono).
     - El recibo (`api/imprimir_recibo_caja_consultorio.pl`) desglosa el `Total Servicios / Tratamiento`, el `IMPORTE COBRADO` y el **`Saldo Remanente`**.
     - Al cubrirse el saldo, el remanente se refleja como `$0.00 (Liquidado)`, el estatus pasa a `Liquidado` y el tratamiento en `dat/tratamientos.dat` se sella a `ESTADO = Cerrado` con su fecha de conclusión.

---

## 10. Aislamiento Estricto de Receta Médica y Prevención de Fuga de Prescripciones

1. **Persistencia Condicional en `dat/recetas.dat`**:
   - Únicamente se crea o actualiza un registro en `dat/recetas.dat` si `$requiere_receta eq '1'` Y la lista de medicamentos contiene al menos un fármaco válido.
   - En consultas sin prescripción de fármacos o con el switch desmarcado, se garantiza que `recetas.dat` no reciba ninguna fila y se purga cualquier registro previo asociado al `id_consulta`.
2. **Sanitización Previa al Guardado**:
   - En `views/partials/consultas/step_soap.pl`, al desmarcar el switch *"¿Expedir Receta Médica?"*, se purga de inmediato el array en memoria, se limpia el DOM y se resetea `receta_json_input.value = "[]"`.
   - En `views/render_consultas_privado.pl`, la función `finalizarConsulta` sanitiza el `FormData` forzando `requiere_receta = '0'` y eliminando folios e indicaciones residuales.
   - En `api/cerrar_consulta_privado.pl`, si `requiere_receta ne '1'`, se purga el `payload_json` de llaves residuales antes de persistir en `consultas_clinicas.dat`.
3. **Erradicación de Fallbacks Ficticios**:
   - En `api/imprimir_receta_api.pl`, queda estrictamente prohibida la inyección de medicamentos simulados (`Paracetamol/Tempra`) o identificadores falsos. Si una consulta no cuenta con receta emitida, despliega un aviso formal y concluye de forma segura.

---

## 11. Aislamiento Estricto de Consentimiento Informado y Gobernanza de Acciones Clínicas

1. **Persistencia Condicional en `dat/consentimientos.dat`**:
   - Únicamente se genera registro en `dat/consentimientos.dat` y se extraen físicamente archivos de firma `.png` si `$requiere_consentimiento eq '1'`.
   - Si no se seleccionó consentimiento, se purgan de `%payload` las firmas y campos del procedimiento, y se elimina cualquier registro residual de `dat/consentimientos.dat`.
2. **Limpieza Reactiva de Lienzos de Firma**:
   - Al desmarcar el switch de consentimiento o abrir una nueva consulta, `toggleSeccionConsentimiento(false)` borra físicamente los lienzos de firma (`canvasPaciente.clear()`, `canvasMedico.clear()`), vacía los campos base64 ocultos y limpia los inputs de texto del procedimiento.
3. **Visibilidad Condicional de Botones de Acción en Expediente y Portal**:
   - En `views/render_expediente_clinico.pl`, `views/mis_consultas.pl` y `api/get_mis_consultas.pl`, los botones **"Receta"** y **"Consentimiento"** se renderizan de forma estrictamente condicional.
   - Si la consulta no tiene medicamentos prescritos, el botón **"Receta"** se omite.
   - Si la consulta no requirió consentimiento informado emitido, el botón **"Consentimiento"** no aparece en la interfaz.

---

## 12. Gobernanza del Expediente Clínico: Unificación y Erradicación de Redundancias

1. **Unificación de Citas y Consultas**:
   - La pestaña legacy `Citas` (`tab0`) queda suprimida del menú lateral de navegación. El **Hub de Consultas (`tab10`)** asume el control integral tanto de citas agendadas como del historial clínico de atenciones finalizadas.
   - Cualquier redirección o enlace histórico hacia `#tab0` es interceptado por `checkHashTab()` y canalizado fluidamente hacia `#tab10`.
2. **Supresión del Botón Redundante de Reporte**:
   - Se retiró el botón superior de "Generar Reporte" del encabezado del expediente, ya que las acciones de exportación y consulta detallada residen en sus respectivos submódulos clínicos.
3. **Resolución Canónica del Nombre Médico (`limpiar_titulo_medico`)**:
   - Se garantiza la visualización del nombre de pila y apellidos reales del facultativo tratante (vía `usuarios.dat`, sesión activa o catálogos CLUE), eliminando identificadores opacos numéricos y prefijos redundantes (`Dr(a).`) ante la etiqueta de la interfaz.

---

## 13. Segregación RBAC Multi-Tenant del Administrador Global (NOM-004 y Privacidad)

1. **Principio de Privacidad Organizacional**:
   - El rol `Administrador Global` es una figura técnica de infraestructura, gobernanza global de la plataforma SaaS y mantenimiento de catálogos maestros.
   - Carece de facultades asistenciales o directivas sobre organizaciones específicas.
2. **Módulos Clínicos y Financieros Restringidos**:
   - En `utils/sub_sidebar.pl`, `utils/permisos_utils.pl`, `views/pacientes.pl` y `views/agenda_main.pl`:
     - **Finanzas**: Ocultado y denegado (`finanzas = 0`).
     - **Pacientes**: Ocultado y denegado (`pacientes = 0`).
     - **Agenda Dinámica**: Ocultado y denegado (`agenda = 0`).
     - **Quirófano / Hospitalización**: Ocultado y denegado (`quirofano = 0`).
3. **Saneamiento del Submenú Administración**:
   - Para no invadir la gestión propia de cada organización/clínica, se omiten expresamente del submenú "Administración":
     - **Gestión de Clínicas / Sucursales** (`clinicas = 0` $\rightarrow$ `views/manage_clinicas.pl`).
     - **Gestión de Personal** (`usuarios = 0` $\rightarrow$ `views/administracion_usuarios.pl`).
     - **Catálogo Universal / Servicios / Productos** (`servicios = 0`, `productos = 0` $\rightarrow$ `views/manage_catalogo_universal.pl`, `manage_servicios.pl`, `manage_productos.pl`).
     - **Reset Operativo Org** (`reset_datos_org = 0` $\rightarrow$ `views/admin_organizacion_reset.pl`, `api/reset_datos_organizacion_api.pl`).
   - El `Administrador Global` conserva exclusivamente herramientas transversales de plataforma:
     - **Gestión de Registros** (`views/manage_registros.pl en submenú **Ventas**`).
     - **Matriz de Permisos** (`gestion_permisos_roles.pl`).
     - **Usuarios en Línea** (`usuarios_online.pl`).
     - **Catálogos y Mantenimiento** (`administracion_catalogo.pl`).
     - **Gestión de Catálogos** (`gestion_catalogos.pl`).

---

## 14. Gobernanza de Agenda de Espacios (Renta de Consultorios y Quirófanos)

1. **Activación por Capacidad SaaS (`Renta de Espacios`)**:
   - La Agenda de Espacios (`views/agenda_espacios.pl`) únicamente se habilita para organizaciones que posean la capacidad `Renta de Espacios` registrada en `dat/negocios_config.dat` (`<ID_ORG>|CAPACIDAD|Renta de Espacios`), configurable desde `views/crm_ventas.pl`.
2. **Estructura Condicional del Menú Lateral (`utils/sub_sidebar.pl`)**:
   - **Organización CON `Renta de Espacios`**: Se reemplaza el enlace directo de Agenda por el grupo desplegable **"Agendas"**, conteniendo los sub-ítems **"Pacientes"** (`views/agenda_main.pl`) y **"Espacios"** (`views/agenda_espacios.pl`).
   - **Organización SIN `Renta de Espacios`**: Se conserva intacto el menú original sin desplegable adicional.
   - En ambos escenarios se aplica rigurosamente la evaluación RBAC (`tiene_permiso_modulo`) para el rol activo y posibles excepciones por usuario.
3. **Fuente Canónica de Inventario Físico**:
   - Los espacios disponibles para arrendamiento se generan dinámicamente a partir del total de `CONSULTORIOS` y `QUIROFANOS` configurados por sucursal en `views/manage_clinicas.pl` (`dat/negocios_config.dat`).
4. **Regla Inviolable Anticolisión Transversal**:
   - Ningún consultorio o quirófano puede reservarse en `dat/rentas_espacios.dat` si presenta intersección horaria en la misma fecha y sucursal con otra renta activa o con una cita/cirugía activa en `dat/citas.dat` (salvo que la cita pertenezca al mismo médico titular del bloque rentado).
   - Las reservas con estado `Cancelada` o `No realizada` liberan inmediatamente el recurso físico en ambas agendas.
5. **Bloqueo Estricto de Fechas y Horas Pasadas (Anticolisión Temporal)**:
   - Queda estrictamente prohibido crear o reprogramar una reserva de espacio antes de la fecha y hora actual (`fecha < hoy` o `fecha == hoy && hora_ini < hora_actual`).
   - La restricción se aplica en doble capa: en el frontend (`#f_fecha` con atributo `min`, deshabilitación de slots pasados, validación en `saveCita` y `dropS` / `dropManualDrag`) y de forma inviolable en el backend (`validar_no_pasado` dentro de `api/espacios_crud.pl`).
   - Se exceptúan únicamente las transiciones de estado operativas (`En Uso`, `Finalizada`, `Cancelada`) sobre reservas ya creadas cuya hora de inicio acaba de cumplirse.
6. **Modalidades de Cobertura en Rango de Fechas (Continuo vs Recurrente)**:
   - **Escenario 1: Bloque Continuo (24h+)**:
     - *Definición Operativa*: El profesional o arrendatario aparta el consultorio o quirófano ininterrumpidamente día y noche desde la fecha y hora de entrega inicial hasta la fecha y hora de devolución final (sin huecos intermedios).
     - *Impacto en Cuadrícula*: En la fecha de inicio se bloquea desde la hora de arranque hasta el final de la jornada; en los días intermedios el espacio se bloquea las 24 horas del día de forma total; y en la fecha final se bloquea desde la apertura hasta la hora de entrega final.
     - *Detección de Colisión*: Cualquier evento preexistente de citas o espacios en cualquiera de los días u horas del intervalo completo dispara una alerta impidiendo el guardado.
   - **Escenario 2: Mismo Horario por Día (Renta Recurrente por Turno)**:
     - *Definición Operativa*: El profesional contrata el espacio únicamente dentro de una franja de horario específica fija (ej. 09:00 a 14:00 hrs) repetida a lo largo de un rango de fechas (ej. Lunes a Viernes).
     - *Impacto en Cuadrícula*: Las mañanas tempranas, tardes o noches de cada uno de los días del rango permanecen plenamente libres y disponibles para otros turnos, médicos colaboradores o pacientes ambulatorios.
     - *Cálculo de Tarifa*: Soporta modalidad "Por Día" ($n 	imes \text{tarifa\_diaria}$) o "Total del Rango" (tarifa plana global por el paquete de días).

---

## 15. Gobernanza de la Línea de Tiempo en Vivo (Timeline Live) y Elementos UX en Agenda

1. **Línea de Tiempo en Tiempo Real (#FF0000)**:
   - Toda vista diaria matricial de agenda (clínica o de espacios) debe proyectar una línea horizontal de 2px en rojo vivo (`#FF0000`) con halo resplandeciente (`box-shadow`), ubicada en `z-index: 22` con `pointer-events: none`.
   - Se posiciona verticalmente según la fórmula matemática exacta:
     $$\text{posición} = \text{tbody.offsetTop} + \left(\frac{(\text{hora} \times 60 + \text{minuto} + \text{segundo}/60) - \text{inicio\_jornada}}{\text{minutos\_totales\_jornada}}\right) \times \text{tbody.offsetHeight}$$
   - Se recalcula automáticamente cada 15 segundos y al redimensionar la ventana con transición suave.
2. **Visibilidad Contextual y Segregación por Fecha**:
   - La línea roja y el marcador del mini-mapa se activan **única y exclusivamente** cuando la fecha visualizada coincide con el día de hoy del sistema (`selectedDate === today`).
   - Al navegar a fechas pasadas o futuras, la línea y el marcador se ocultan de forma automática sin alterar la grilla.
3. **Etiqueta Flotante y Estado de Próximo Evento**:
   - En la columna horaria izquierda se proyecta un pill rojo con animación de punto blanco pulsante (`.timeline-live-time-pill`).
   - Sobre la línea roja flota una etiqueta interactiva (`.timeline-live-next-badge`) que diagnostica en tiempo real:
     - Si hay un evento en curso: `"En curso: [Título] (restan X min)"`.
     - Si hay un evento futuro programado para hoy: `"Próximo: [Título] a las HH:MM (en X min)"`.
     - Si no hay más citas en el día: `"Sin más eventos pendientes hoy"`.
4. **Mini-Mapa del Día y Snap-To-Now**:
   - En la cabecera de la matriz se renderiza el mini-mapa del día (`.timeline-day-minimap`) con barra de progreso del tiempo transcurrido (`.minimap-past-fill`), bloques de citas programadas (`.minimap-event-block`) y marcador circular rojo pulsante (`.minimap-marker`).
   - El botón **"Ir a Ahora"** (`#btn-snap-now-toolbar` / `.btn-timeline-now`) retorna al usuario a la fecha actual si está en otro día y enfoca suavemente la pantalla sobre la línea de tiempo viva con un destello visual de confirmación.
5. **Progreso Dinámico y Pulso de Anticipación**:
   - Toda cita o renta que se encuentre transcurriendo en el momento exacto proyecta una barra de progreso inferior animada en verde esmeralda (`.apt-progress-bar`).
   - Todo evento que inicie dentro de los próximos 15 minutos despliega un halo de pulso suave en tono ámbar/dorado (`.apt-imminent-pulse`).

---

## 16. Paridad y Homogeneización de la Suite de Agendas (Médica & Espacios)

1. **Paridad Total de Celdas de Días Adyacentes en Vista Mensual**:
   - Queda estrictamente prohibido renderizar contenedores vacíos, grises o deshabilitados en los días pertenecientes al mes anterior o posterior que completan la grilla mensual.
   - Las celdas adyacentes (`.calendar-cell-other-month`) deben portar tramado radial sutil, número de día tenue, badge abreviado del mes (`.other-month-badge`) y soportar 100% de operatividad: visualización de citas, clic para agendar (`handleSlotClick`), arrastre drag & drop entre meses (`dropS`) y salto directo a la vista diaria (`goDay`).
2. **Arquitectura de Barra de Herramientas en Dos Niveles (Two-Tier Toolbar)**:
   - Ambas agendas estructuran su toolbar en:
     - **Nivel 1 (Cabecera Navy Contextual `.agenda-toolbar-tier1`)**: Título formal del módulo, contadores en tiempo real (citas activas o espacios habilitados/bloqueados), botón de acción primario (`+ Nueva Cita` o `Reservar Espacio`) y botón de configuración rápida.
     - **Nivel 2 (Bandeja Operativa Blanca `.agenda-toolbar-tier2`)**: Controles de navegación de fecha (`HOY`, `Ahora` con timeline live, selector de fecha), botones de vista (`Día`, `Semana`, `Mes`), menú compacto `Reportes & Export` (`#dropdownReportesExport`) y selectores ejecutivos (Médicos, Espacios, Estados y alternador de mini-calendario lateral).
3. **Modal de Configuración y Ajustes Operativos Premium (`#modalAjustes` / `.modal-apertura-premium`)**:
   - Diseño unificado de dos columnas (`zoom: 0.75`), cabecera corporativa con icono y badge teal.
   - Columna izquierda: Horarios de apertura/cierre en `.field-card`, días de atención en píldoras `.btn-day-pill` con micro-dot luminoso y switch reactivo para omitir horario de comida sin recarga de página.
   - Columna derecha: Intervalo con selector segmentado y slider táctil, límite de cancelación de citas y administración de días inhábiles en tags ámbar (`.date-tag-amber`) con motivos configurables y pie con aviso legal de cumplimiento de la Norma Oficial Mexicana NOM-004.
4. **Modal de Gestión de Citas y Reservas (`#modalCita` / `.modal-diamond`)**:
   - Diseño canónico de 2 columnas (7 cols ficha izquierda / 5 cols duración y anticolisión derecha).
   - Columna izquierda: Datos del paciente/arrendatario con búsqueda predictiva, fecha, motivo/especialidad, profesional, sede, consultorio, estado, prioridad y color de cita.
   - Columna derecha: Sección de duración con badge superior interactivo (`#lbl_slider_duracion_badge`), slider táctil continuo (`#slider_duracion_renta`), píldoras segmentadas rápidas (`#btn-group-duracion`), tarjeta amarilla avena de bloqueo (`#bloqueo-horario-avena`) con candado e intervalo, y contenedor de horarios disponibles anticolisión sincronizado con pacientes y espacios físicos.





