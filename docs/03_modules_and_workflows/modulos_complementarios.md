# Módulos Complementarios y Especializados (SDM / OSPulso 2.0)

## 1. Visión General
Este documento agrupa la especificación de los módulos complementarios y especializados integrados en la plataforma OSPulso / SDM.

---

## 2. Especificación por Módulo

### 2.1 Agenda y Citas Médicas (`views/agenda_main.pl`, `api/citas_crud.pl`, `js/agenda_spa_new.js`)
- Administración de calendario por médico tratante, especialidad y consultorio.
- Vistas disponibles: Principal (`agenda_main.pl`), Lista (`agenda_vista_lista.pl`), Semanal (`agenda_vista_semanal.pl`) y Mensual (`agenda_vista_mensual.pl`).
- **Aislamiento Multi-Tenant y Reglas para Consultorio Individual vs Clínica Multi-Rol**:
  1. **Sucursales y Sedes**: El endpoint `api/citas_crud.pl?accion=get_form_metadata` filtra estrictamente por el `id_empresa` del usuario autenticado. Para un **"Consultorio Individual"**, devuelve únicamente su sede propia sin permitir sucursales foráneas ni matrices ajenas.
  2. **Recursos Físicos (`get_recursos`)**: Si la organización es un **"Consultorio Individual"**, el sistema fuerza de forma inviolable la disponibilidad de **1 solo consultorio físico** ("Consultorio 1" y opción "Virtual") y **0 quirófanos**. En clínicas con hospitalización o múltiples sedes, consulta dinámicamente los recursos configurados en `dat/negocios_config.dat`.
  3. **Eventos y Filtro de Médicos**: La consulta de eventos (`get_events`) y el catálogo de profesionales en el modal de citas aíslan rigurosamente a los médicos pertenecientes al `id_empresa` de la sesión, impidiendo fugas entre organizaciones.
  4. **Vertiente Organizacional en Modal de Citas (`#modalCita`)**:
     - **Branch A (Consultorio Individual / Monousuario)**: El director es simultáneamente Administrador y único Médico. En `#modalCita`, el selector *"PROFESIONAL ASIGNADO"* se oculta permanentemente (`d-none`), asignando al médico titular por defecto y expandiendo el campo *"Motivo de la Cita"* a ancho completo (`col-12`) para optimizar la captura clínica.
     - **Branch B (Clínica / Hospital con CLUE y Multi-Rol)**: El selector *"PROFESIONAL ASIGNADO"* es obligatorio, alimentado exclusivamente por la plantilla de médicos activos dados de alta en `views/administracion_usuarios.pl`.
- **Disponibilidad Horaria Desacoplada: Sucursal Física vs Médico Particular**:
  1. **Marco Macro de Sede Física (`dat/agenda_config_sucursal_<id_sucursal>.dat`)**: La cuadrícula general de la clínica (donde operan los múltiples consultorios y quirófanos) se rige por el horario de apertura institucional (ej. 07:00 a 21:00). Esto garantiza que la vista por espacios físicos siempre abarque la jornada completa de la sede física sin truncarse por la jornada reducida de un médico en particular.
  2. **Disponibilidad Particular del Médico (`dat/agenda_config_medico_<id_medico>.dat`)**: Cada profesional de la salud dispone de su propio horario de atención (ej. 09:00 a 14:00 o 16:00 a 20:00), receso de comida, días hábiles, límite de cancelación de citas y vacaciones/festivos individuales. Al visualizar la agenda filtrada por médico o al agendar una consulta médica, el sistema aplica reactivamente estas restricciones particulares.
  3. **Configuración Multi-Ámbito en Ajustes de Agenda (`#modalAjustes` en `views/agenda_main.pl`)**:
     - El modal `#modalAjustes` incorpora un switch de ámbito interactivo:
       - `● Horario de Sucursal`: Permite a administradores y recepcionistas configurar la apertura, cierre, comida, días de operación e inhábiles de cada sucursal/sede física (`#adj_sucursal_select`).
       - `○ Horario por Médico`: Permite configurar la disponibilidad de consulta privada del profesional seleccionado (`#adj_medico_select`).
     - Al alternar el ámbito, el modal conmuta automáticamente etiquetas, selectores y campos de captura (`cambiarAmbitoAjustes(tipo)`), cargando vía API (`api/citas_crud.pl?accion=get_config&tipo_ambito=...`) y persistiendo (`api/citas_crud.pl?accion=save_config&tipo_ambito=...`) de manera aislada e independiente.
     - **Horario Continuo / 24 Horas sin Comida**: Incorpora el switch interactivo `#adj_sin_comida` ("Omitir horario de comida / Horario continuo"). Al activarse, los campos de inicio y fin de comida se omiten y el sistema no genera falsos bloqueos de receso, permitiendo a clínicas y hospitales con atención continua operar sin pausas institucionales, dejando las comidas al relevo interno del personal.
  4. **Jornada Continua Completa (12:00 am a 11:59 pm / 24h) y Desahogo de Scroll**:
     - El motor de renderizado (`renderTimeline`, `renderSlots` y `renderSmartSlots`) normaliza el rango horario a minutos continuos (`0` a `1440 min`), garantizando que la última hora del día (23:00 a 23:59) se genere y se renderice en su totalidad.
     - Se integra un padding inferior reforzado (`padding-bottom: 4.5rem !important`) en `.dia-matrix-responsive` y un espaciador físico (`.dia-matrix-bottom-spacer` de 60px), eliminando cualquier recorte visual de la última franja horaria ocasionado por la barra horizontal o el borde de la ventana.
     - **Navegación Fluida por Límites de Scroll (Infinite Day Overscroll)**: Al llegar al tope superior (`00:00`) o al fondo inferior (`23:59`), el sistema detecta el impulso del scroll y despliega banners flotantes elegantes con retroalimentación visual (`#dia-edge-banner-top` y `#dia-edge-banner-bottom`), permitiendo deslizar continuamente o hacer clic directo para transicionar al día anterior o siguiente con reposicionamiento de scroll inteligente.
     - **Gobernanza Unificada de Viewport (Diamond Unified Viewport)**: El contenedor principal de la agenda (`body.agenda-page-layout`) bloquea todo scroll vertical parásito a nivel ventana (`height: 100vh; overflow: hidden !important`). Cada vista encapsula su propio scroll interno sin invadir jamás el menú superior corporativo ni el header de la aplicación:
       - *Vista Semanal Smart (`#view-semana-smart`)*: El carrusel de días (`#weekly-smart-scroll`) permanece anclado y visible en la parte superior, mientras que los bloques de slots (`#weekly-smart-slots`) se desplazan fluidamente en su propio contenedor con scroll vertical y padding de desahogo.
       - *Vista Mensual Grid (`#view-calendario`)*: El contenedor `#calendar-grid-sdm` mantiene las cabeceras de días (`LUN`, `MAR`, `MIÉ`, etc.) con comportamiento `sticky`, permitiendo al usuario scrollear las semanas sin alterar la barra superior de navegación.
       - *Reportes DataTables (`#view-semana` y `#view-mes`)*: La tabla `.agenda-table-responsive` se desplaza internamente dentro de su tarjeta contenedora.
  5. **Normalización ISO de Días Hábiles (Domingo = 7)**:
     - El checkbox de domingo en `#modalAjustes` utiliza el estándar canónico ISO `value="7"` (compatible con `Time::Piece->_wday` y el frontend `isWorkDay`).
     - `api/citas_crud.pl` y `js/agenda_spa_new.js` implementan tolerancia bidireccional continua (soporte de `0` y `7`), normalizando de manera transparente a `7` al persistir tanto para sucursales como para médicos.
  6. **Filtro Inteligente de Visualización y Visibilidad Global para Administración/Recepción**:
     - Para roles administrativos (`Administrador Organizacion`, `Recepcionista`, `Asistente`), la agenda carga de manera predeterminada todas las visitas activas de la institución (`id_medico=all`). Esto impide que el ID de sesión del administrador (que no es un médico con citas propias) bloquee u oculte las visitas de la clínica.
     - En organizaciones multi-rol o multi-médico, la barra superior de herramientas integra el selector dinámico `#filtro_medico_toolbar`, permitiendo al personal de recepción o dirección alternar instantáneamente entre *"Todos los Médicos"* o un profesional específico, recargando reactivamente sus citas y su configuración horaria individual.
- **Catálogo Canónico de Estados de Citas (`dat/catalogo_estados_citas.dat`)**:
  El sistema implementa 7 estados canónicos de citas médicas totalmente sincronizados entre backend (`api/citas_crud.pl`), vistas modales (`views/agenda_main.pl`) y motor visual SPA (`js/agenda_spa_new.js`):
  1. `Programada` (#0A2A66 / badge azul marino)
  2. `Confirmada` (#10b981 / badge esmeralda)
  3. `En Sala de Espera` (#f59e0b / badge ámbar)
  4. `Consulta en proceso` / `En consulta` (#059669 / badge verde oscuro clínico, `#dcfce7`)
  5. `Atendida` (#19B7A5 / badge teal corporativo)
  6. `No realizada` (#ef4444 / badge rojo de alerta)
  7. `Cancelada` (#dc2626 / badge carmesí)
- **Leyenda Canónica de Colores en Barra de Herramientas (`views/agenda_main.pl`)**:
  En la barra superior de acciones, junto a los ajustes de jornada, se integra el dropdown interactivo `dropdownLeyendaColores` con ícono de paleta (`bi-palette`), permitiendo a recepcionistas y médicos consultar en cualquier momento el significado clínico y operativo de los 7 colores de estados de citas.
- **Reglas Canónicas de Empalmes y Duraciones Especiales ("Día Completo" y "Resto del Día")**:
  1. **Día Completo (`duracionCita === 'all'`)**: Queda estrictamente prohibido agendar o guardar una cita de día completo si existe **cualquier cita** en esa fecha para el médico o consultorio (salvo que esté cancelada o no realizada). En el selector de slots, se presenta un banner clínico expansivo a ancho completo (`.slot-alert-banner`) informando que las citas existentes deben ser reprogramadas o eliminadas. Al intentar guardar, tanto el frontend (`saveCita`) como el backend (`api/citas_crud.pl`) aplican un cerrojo inviolable que rechaza la operación.
  2. **Resto del Día (`duracionCita === 'rest'`)**: Un bloque que abarca desde la hora seleccionada hasta el fin de la jornada (`laborEnd`) solo es elegible si ningún evento activo intersecta dicho intervalo. Si un bloque intermedio o final tiene colisión con una cita posterior, el botón correspondiente se muestra bloqueado (`.btn-slot-conflict`) y, al hacer clic, despliega una alerta SweetAlert2 interactiva detallando con precisión el horario, paciente y motivo de la cita que impide abarcar el resto del día. Si ningún horario del día es viable, se antepone un banner a ancho completo notificando la situación.
  3. **Integridad de Citas Atendidas**: En `api/citas_crud.pl`, las citas en estado `Atendida` forman parte activa de la detección de colisiones y no pueden ser sobreescritas por citas de jornada completa o empalmadas.
- **Sincronía y Blindaje de Citas Vencidas ("No realizada") en Toda la Agenda**:
  1. **Doble Capa de Saneamiento (Backend & Frontend)**: Si una cita programada o confirmada no fue atendida ni cancelada y su fecha/hora de finalización ya expiró (`fecha < hoy` o `fecha == hoy && hora_fin < hora_actual`), el backend (`api/citas_crud.pl`) actualiza automáticamente su estado a `No realizada` al consultar la agenda y persiste el cambio en `dat/citas.dat` preservando `id_negocio` y `elaborado_por`. De forma complementaria y preventiva, el motor frontend (`js/agenda_spa_new.js`) evalúa la fecha y hora al renderizar tanto el *Historial de Días Pasados*, la *Vista Diaria de Hoy*, la *Vista Móvil*, la *Vista Mensual Grid* (Desktop y Móvil) y los *Reportes Semanal/Mensual*, garantizando que cualquier cita expirada no atendida ni cancelada se refleje visualmente como `No realizada` con su distintivo badge rojo visible (`#ef4444`). Las citas en `Consulta en proceso` o `En consulta` están estrictamente exentas de esta regla tanto en backend como frontend para proteger la atención clínica activa aunque rebase el horario previsto.
  2. El modal de gestión de citas permite además la selección y edición manual del estado `No realizada`.
  3. Las citas con estado `No realizada` se excluyen de la detección de colisiones de horario para no bloquear nuevas reservas y se les inhabilita el drag-and-drop.
- **Reglas de Creación de Citas y Ciclo de Vida**:
  1. **Restricción de Estados en Nuevas Citas**: Está estrictamente prohibido crear una cita nueva manual con estado `Cancelada`, `No realizada` o `Atendida`. El selector en modal (`views/agenda_main.pl` / `js/agenda_spa_new.js`) solo expone `Programada`, `Confirmada` o `En Sala de Espera`, y el backend (`api/citas_crud.pl`) rechaza con error 400 cualquier intento directo.
  2. **Seteo Automático a "Consulta en proceso" y Conclusión a "Atendida"**: Al iniciar una consulta clínica (con o sin cita previa), el backend fija el estado en `Consulta en proceso` en `dat/citas.dat` y bloquea al médico contra sesiones paralelas concurrentes. Al finalizar el wizard clínico de consultas tanto privadas (`api/cerrar_consulta_privado.pl`) como públicas (`api/cerrar_consulta.pl`), el estado transiciona inmutablemente a `Atendida` (#19B7A5), liberando el cerrojo del médico, eliminando borradores en `consulta_draft.dat` y enlazando los recibos de caja.
  3. **Gobernanza de Cobro en Recepción**: Si la organización es de tipo `Consultorio Individual` o `Consultorio Compartido`, el botón de `Cobrar en Recepción` se oculta permanentemente del modal de gestión de citas, dado que estos entornos carecen de ventanilla receptiva hospitalaria y el cobro se realiza directamente en consultorio.
- **Vista Mensual Grid Desktop & Móvil (`switchView('calendario')`)**:
  1. **Cabeceras de Días**: Fondo azul marino corporativo (`#0A2A66`) con texto blanco (`#ffffff`) en negrita (`font-weight: 700`) tanto para nombres completos/cortos en desktop (`.cal-grid-header-day`) como píldoras en móvil (`.cal-grid-header-day-mobile`).
  2. **Interacción Overmouse**: Al pasar el cursor sobre cualquier casilla de día (`.calendar-cell:hover`), se aplica un fondo suave contrastado (`#f0fdfa`) y un borde corporativo teal mandante (`outline: 2px solid var(--md-teal-clinical, #19B7A5); outline-offset: -2px`) sin desfasar el grid CSS.
  3. **Protección en Desktop**: Las citas expiradas en la cuadrícula mensual desktop se renderizan con el estilo de `No realizada` (fondo y acento `#ef4444`, texto blanco) e inhabilitan el drag-and-drop para evitar alteraciones ilegítimas del historial.
  4. **Sanitización Visual y Limpieza de Grid**: Las celdas de días no laborables del médico conservan un fondo sutil desaturado (`#f8fafc`) y borde superior discreto sin estampar etiquetas de texto *"NO LABORABLE"*, evitando la contaminación visual del calendario mensual. Únicamente se etiqueta con badge rojo visible los días festivos (`FESTIVO`).
  5. **Sincronización de Cabecera al Cambiar Vistas**: La función `switchView(v)` actualiza reactivamente el título de navegación temporal (`renderHeaders()`) asegurando que al entrar a la vista mensual se muestre el mes correspondiente (ej. `OCTUBRE 2026`) y no el rango semanal previo.
- **Garantía Inviolable de Unicidad de Paciente (Anti-Colisión Multi-Tenant)**:
  1. **Monotonía Global de IDs (`api/pacientes_crud_api.pl`)**: Al registrar un nuevo paciente, el backend evalúa el `max(ID_PACIENTE)` existente en `dat/pacientes.dat`. Si el valor obtenido por `contador_pacientes.dat` es menor o igual al máximo real, se fuerza dinámicamente `$id_paciente = max_id + 1` y se sincroniza el contador. Esto erradica colisiones de ID entre organizaciones aún ante desfasajes del archivo contador.
  2. **Filtro Multi-Tenant en Búsqueda y Resolutores de Citas**: `api/citas_crud.pl` (`obtener_nombre_paciente` y `obtener_correo_paciente`) y `api/autocomplete_pacientes.pl` aíslan estrictamente las consultas al `id_negocio` / `mi_org` de la sesión, impidiendo que una cita o expediente muestre nombres de pacientes registrados bajo el mismo ID en otra organización.
- **Navegación y Vista Diaria de Días Pasados**:
  1. **Empty State**: Si se navega a un día pasado sin citas registradas, la vista diaria renderiza una tarjeta acrílica centrada (`.agenda-empty-day-card`) indicando *"Sin actividad registrada para este día"* y botón de regreso a hoy.
  2. **Historial Ejecutivo y Citas No Realizadas**: Si hubo citas en el día pasado, se despliega una lista cronológica ejecutiva estilizada con acceso directo al expediente, badge de estado rojo contrastado, botón directo de **"Tomar Cita"** (`window.tomarCitaDirecto`) para citas no atendidas, botón de **"Re-agendar / Modificar"** y botón para ver el detalle.
- **Acción Canónica "Tomar Cita" y Vista Semanal Interactiva**:
  1. **Disponibilidad Universal de "Tomar Cita"**: Para cualquier cita que no se encuentre formalmente `Atendida` o `Cancelada`, el médico puede iniciar la consulta médica inmediatamente (`render_consultas.pl?id=${id_paciente}&id_cita=${id_cita}`) tanto desde los botones rápidos en las vistas Diaria, Semanal y Mensual, como desde el botón mandante `#btn-tomar-cita` en el modal de gestión de citas (`#modalCita`), tanto en modo lectura/detalle como en modo edición/re-agendar.
  2. **Vista Semanal Inteligente (Smart View), Citas de Todo el Día y Multi-Slot**: En `renderWeeklySmartView` y `renderSmartSlots`, la tira de 7 días expone píldoras con el conteo de citas registradas por día. Para evitar la fragmentación visual del cronograma:
     - **Citas de Día Completo / Jornada Completa**: Si una cita abarca la jornada (`aHi <= laborStart && aHf >= laborEnd` o duración >= jornada - 30m o >= 6 hrs o motivo explícito), el motor NO genera 20 micro-tarjetas redundantes de 30 minutos. En su lugar, renderiza en la parte superior una **Tarjeta Hero Ejecutiva** (`.all-day-hero-card`) a ancho completo con badge *JORNADA COMPLETA*, badge de estado dinámico, horario, duración, avatar, nombre, expediente, motivo y un juego unificado de botones de acción (`Tomar Cita Ahora`, `Expediente`, `Re-agendar`, `Ver Detalle`). Las secciones MAÑANA y TARDE muestran un banner cohesivo (`.smart-shift-covered`) indicando que el turno está cubierto.
     - **Citas Multi-Slot (Rango horario prolongado)**: Para citas que cubren múltiples bloques de tiempo sin ser de jornada completa (ej. 10:00 a 12:00), la ranura inicial (`isAptStart`) muestra el rango completo (`10:00 - 12:00`), título y botones de acción, mientras que las ranuras intermedias o subsecuentes se renderizan como ranuras de continuación limpias (`.slot-continuation`) con el indicador `↳ Continúa` sin duplicar botones interactivos.
     - **Citas Extemporáneas o Fuera de Horario**: Si existen citas que no encajan en las ranuras estándar y no corresponden a jornada completa, se renderizan en una sección visible dedicada (`CITAS FUERA DE HORARIO / EXTEMPORÁNEAS`) para garantizar que ninguna cita quede oculta.
  3. **Gestión de Colisiones Extemporáneas**: Si se toma una cita del pasado o fuera de horario que empalme con otra cita ya agendada para el momento actual, el sistema emite una alerta SweetAlert2 de confirmación previa antes de transferir el flujo a la consulta SOAP.
- **Filtrado Universal Reactivo y Coherencia Multi-Especialidad (`getFilteredAppointments`)**:
  1. **Motor de Filtrado Centralizado**: Tanto la Vista Diaria (`renderTimeline`), la Vista Semanal Smart (`renderWeeklySmartView` y `renderSmartSlots`), la Vista Mensual Grid Desktop (`renderGrid`), la Vista Mensual Móvil (`renderMobileCalendar` / `renderMobileDayList`) y los Reportes Operativos (`renderTable('semana')` y `renderTable('mes')`) consultan obligatoriamente la función canónica `getFilteredAppointments()`.
  2. **Multi-Check de Médicos y Espacios Físicos (Consultorios / Quirófanos)**: El toolbar mantiene visible y activo en todas las vistas (`Día`, `Semana` y `Mes`) tanto el selector de Médicos (`window.medicosChecked`) como el de Espacios Físicos (`window.recursosChecked`). Al alternar consultorios o quirófanos, todas las vistas responden reactivamente (`renderView()`) filtrando las citas asignadas a dichos espacios en el carrusel semanal, cuadrícula mensual y reportes.
  3. **Preservación de Estado Inter-Vistas y Memoria Persistente (`localStorage`)**: Al conmutar entre Día, Semana y Mes mediante `switchView(v)`, las selecciones de médicos y espacios físicos se conservan intactas en memoria activa. Adicionalmente, el sistema persiste dichas selecciones en `localStorage` (`ospulso_agenda_filtro_medicos_<sucursal>` y `ospulso_agenda_filtro_recursos_<sucursal>`), garantizando que al refrescar la página, cambiar de sesión o regresar a la agenda, los filtros elegidos por el usuario se restauren de forma inmediata y automática.
  4. **Coherencia y Sincronización Temporal Inter-Vistas (Semana Lunes a Domingo & ISO Local)**:
     - *Alineación Canónica de Semana Smart*: El carrusel interactivo (`#weekly-smart-scroll`) renderiza estrictamente los 7 días (Lunes a Domingo) correspondientes a la semana activa, erradicando desfasajes arbitrarios (`+-3 días`) y garantizando una coincidencia del 100% con la cabecera institucional (`SEMANA: DD MES - DD MES`). Cada tarjeta presenta su indicador de día actual, badge de citas en tiempo real (`1 cita`, etc.) y selección reactiva de slots.
     - *Saneamiento Anticolisión de Timezone en `getISO`*: La normalización de fechas opera de manera determinista extrayendo año, mes y día locales (`getFullYear()`, `getMonth()`, `getDate()`) sin depender de mutaciones por `getTimezoneOffset()`, eliminando pérdidas o corrimientos de citas entre días pasados y presentes al conmutar vistas.
     - *Filtrado Centralizado en Matriz Diaria*: `renderTimeline()` delega el filtrado de eventos a `getFilteredAppointments()`, asegurando que la matriz de consultorios y quirófanos refleje instantáneamente las citas y espacios filtrados en el toolbar.
- **Homologación Universal de Popup Intermedio de Inspección Rápida (`#appointmentQuickModal`)**:
  1. **Experiencia de Clic Unificada**: Tanto en la Vista Diaria, la Vista Semanal Smart (`renderSmartSlots`), la Vista Mensual Grid Desktop (`renderGrid`) como la Vista Móvil de Mes (`renderMobileDayList`), al hacer clic en cualquier cita se activa prioritariamente el modal de inspección rápida (`window.openAppointmentQuickDetail(id)`), actuando como paso intermedio de confirmación y desahogo visual antes de la edición completa.
  2. **Poblado Exhaustivo y Fiel de Datos**:
     - *Cabecera*: Estado canónico de la cita con color corporativo dinámico (`#quickModalHeader`) y punto de luz activo (`#quickModalDot`).
     - *Paciente y Expediente*: Nombre completo en negrita y badge con número de expediente (`Exp. #<id>`).
     - *Teléfono*: Enlace directo `tel:<numero>` con ícono de llamada.
     - *Médico Asignado*: Resolución dinámica del nombre desde catálogo o DOM para profesionales asignados.
     - *Motivo de Consulta*: Texto descriptivo truncado con tooltip completo.
     - *Espacio Asignado*: Consultorio o quirófano asignado con badge gris.
     - *Badge de Pago de Alto Contraste*: Badge verde esmeralda `Pagado` o amarillo ámbar `Pendiente de Pago`.
     - *Tarjeta de Fecha en Amarillo Avena*: Bloque visual de fecha destacada (`#quickModalMes`, `#quickModalDiaNum`, `#quickModalDiaSemana`, `#quickModalHora`).
     - *Botones de Acción*: Iniciar Cita / En Consulta (con redirección al wizard SOAP), Expediente Clínico (enlace en nueva pestaña), Editar / Re-agendar (abre `#modalCita` con todos los campos editables), Cobrar en Recepción y Eliminar Cita.
- **Módulo de Resumen e Impresión de Citas Filtradas (`#modalImpresionAgenda`)**:
  1. **Acceso Universal en Toolbar**: La barra de herramientas expone el botón de impresión (`#btn_imprimir_agenda`) con ícono `bi-printer-fill`, accesible en las vistas Día, Semana y Mes.
  2. **Vista Intermedia de Previsualización**: Al presionar el botón, se despliega `#modalImpresionAgenda` (`window.abrirModalImpresionAgenda()`), que calcula dinámicamente el rango de fechas según la vista activa (Día específico, Semana de lunes a domingo, o Mes calendario completo), aplica los filtros de médicos y espacios seleccionados, y genera una tabla limpia con fecha, horario, paciente, médico, espacio, motivo y estado canónico.
  3. **Aislamiento Estricto de Impresión (`@media print`)**: El contenedor `#printReportContainer` está integrado en el motor de estilos mandante (`css/ospulso_master_v2.css`) con aislamiento absoluto `visibility: visible !important`, ocultando automáticamente barras laterales, barras de navegación, botones y modales circundantes al enviar a impresión física o exportación a PDF (`window.ejecutarImpresionAgendaDirecta()` / `window.print()`).
- **Mini Calendario Lateral con Borde Teal**:
  1. Presenta botones de navegación de mes (`<` Mes Año `>`), píldoras interactivas con indicador de día actual (`is-today`), días con citas (`has-apts`), grid CSS de 7 columnas indestructible (`.side-cal-grid`) y borde mandante teal `rgba(25, 183, 165, 0.4)`.

### 2.2 Quirófano Kanban (`views/quirofano_kanban.pl`)
- **Monitor de Piso en Tiempo Real (Floor Execution Only)**: Tablero visual de ejecución de procedimientos quirúrgicos para el día en curso.
- **Centralización Única en Agenda Central**:
  1. **Cancelación de Agendamiento Paralelo**: Queda prohibido programar citas o cirugías directamente desde `quirofano_kanban.pl`. Toda reserva quirúrgica (asignación de cirujano, anestesiólogo, quirófano y horario) se realiza exclusivamente desde la Agenda Central (`views/agenda_main.pl`), seleccionando el recurso "Quirófano".
  2. **Sincronización Transversal**: La Agenda Central detecta automáticamente si el médico asignado tiene consulta o cirugía programada en ese horario, evitando colisiones tanto de espacio (quirófano ocupado) como de agenda profesional (médico en consulta externa simultánea).
  3. **Monitor del Día**: `quirofano_kanban.pl` se enfoca estrictamente en la operación del día hoy (`#lblFechaHoy`) y cuenta con acceso directo a la Agenda Central mediante el botón *"Programar en Agenda Central"*.
- Estados del Tablero: *Programada*, *Pre-Operatorio*, *En Quirófano*, *Recuperación* y *Alta*.
- **Gobernanza de Capacidades SaaS (`MANEJA_HOSPITALIZACION`) & RBAC**:
  1. **Capacidad SaaS de Organización**: Para que el ítem *"Tablero Quirófano"* sea visible en el menú lateral (`utils/sub_sidebar.pl`) y accesible en `views/quirofano_kanban.pl`, la organización debe contar con la casilla de verificación **"Hospitalización"** activa en sus capacidades SaaS (`dat/negocios_config.dat` con `ID_ORG|MANEJA_HOSPITALIZACION|1`). Si no está activa (`0` o ausente para organizaciones privadas), la opción se oculta automáticamente del menú lateral y el acceso directo a la vista es bloqueado mediante `render_acceso_denegado`.
  2. **Control RBAC y Excepciones Activas**: Adicionalmente a la capacidad activa de la organización, el usuario debe poseer permiso de lectura (`R`) evaluado dinámicamente por la función `utils::permisos_utils::tiene_permiso_modulo($id_empresa, $role, 'quirofano', 'R', $id_usuario_sesion)` (matriz `permisos_roles_*.dat` o excepciones `permisos_usuarios_*.dat`).

### 2.3 Odontograma SPA (`js/odontograma_spa.js`)
- Lienzo gráfico interactivo sobre HTML5 Canvas para odontología.
- Marcación de hallazgos (caries, endodoncias, extracciones, implantes) con nomenclatura internacional FDI.

### 2.4 Reset Operativo de Organización (`views/admin_organizacion_reset.pl`, `api/reset_datos_organizacion_api.pl`)
- Módulo de mantenimiento preventivo y puesta a punto para iniciar operaciones limpias por organización (`id_empresa`).
- **Aislamiento Multi-Tenant Estricto**: Mapea exhaustivamente los identificadores de usuarios y médicos registrados de la organización solicitante (`%uids_org`). La purga en `estado_cuenta.dat`, `citas.dat`, `consultas_clinicas.dat`, `recetas.dat`, `consentimientos.dat` y `gastos.dat` evalúa estrictamente la pertenencia contra este mapa y el identificador `ID_NEGOCIO` (columna `[11]` en gastos), protegiendo al 100% los registros de otros consultorios o tenants independientemente de si el reset se ejecuta desde la organización principal (`0`) o tenants secundarios.
- **Datos Eliminados**: Recibos de caja rápida de la organización (`folios_recibos_privados.dat` y `folios_recibos_publicos.dat`), movimientos de estado de cuenta de sus médicos, citas de agenda médica de sus médicos, consultas clínicas SOAP, recetas, consentimientos, notas de borrador, odontogramas clínicos y tratamientos dentales (en `odontogramas.dat` y archivos atómicos `dat/odontogramas/paciente_<id>.json`), gastos operativos del tenant, cotizaciones/tratamientos y pacientes de mostrador de CLUE (`pacientes_privados_<CLUES>.dat`).
- **Datos Conservados**: Cuentas de usuario y médicos (médicos, recepcionistas, administradores), catálogo universal o privado de servicios/productos, tarifas, categorías y orígenes de dinero configurados, dependencias y expediente clínico base de pacientes.
- **Gobernanza de Folios y Diferenciación Ontológica**:
  1. **Organizaciones con CLUE y `PACIENTES_ESTADO = 1`**: La UI despliega configuración dual para definir el folio inicial de *Recibos Privados* y *Recibos Públicos (Convenios)*, actualizando ambos contadores en `contadores_recibos_privados_<CLUES>.dat` y `contadores_recibos_publicos_<CLUES>.dat`.
  2. **Consultorio Individual y Consultorio Compartido (sin `PACIENTES_ESTADO`)**: La UI despliega un formulario simplificado exclusivo para el *Folio Inicial de Recibos Privados* (por defecto `#1`, pero editable si el médico requiere continuar una foliatura previa o de migración), actualizando `contadores_recibos_privados_<id_empresa>.dat` sin mostrar ni alterar contadores públicos inexistentes.

### 2.5 Caja Consultorio / Punto de Venta (`views/caja_consultorio.pl`)
- Módulo de cobro ágil y directo diseñado específicamente para **"Consultorio Individual"** y **"Consultorio Compartido"** que no operan bajo convenios públicos (`PACIENTES_ESTADO = 0`).
- **Bifurcación en Menú Lateral**: Reemplaza el ítem *"Generar Recibo"* (`views/generar_recibo.pl`) por *"Caja"* (`views/caja_consultorio.pl`) en la sección de Finanzas de `utils/sub_sidebar.pl`.
- **Arquitectura del Carrito Reactivo**:
  1. Reutiliza la ontología clínica del paso de caja del wizard (`step_caja_privado.pl`): buscador de catálogo unificado, entrada manual rápida, tabla de catálogo y lista interactiva de conceptos con cantidades y subtotales.
  2. Selector dual de paciente: permite cobro rápido a "Público General" (mostrador / walk-in) o vinculación con pacientes de expediente clínico.
  3. Formas de pago: Efectivo, Tarjeta y Transferencia; modalidad de Liquidación completa o Abono parcial.
  4. Persistencia e integridad: emite folios privados consecutivos e inscribe cargos y abonos en `dat/folios_recibos_privados.dat` y `dat/estado_cuenta.dat` a través de `api/guardar_recibo_rapido.pl`, con enlace para impresión inmediata mediante `api/imprimir_recibo_caja_consultorio.pl`.

### 2.6 Respaldo y Recuperación Integral (`views/admin_backups.pl`, `api/backup_db_api.pl`, `api/restore_db_api.pl`)
- Módulo administrativo exclusivo para **Administrador Global** encargado del ciclo de vida y seguridad de datos de la plataforma SaaS.
- **Funcionalidades Clave**:
  1. **Generación Manual Inmediata**: Creación de empaquetados `.zip` atómicos de toda la base de datos plana (`dat/`) y archivos adjuntos (`uploads/`), excluyendo subdirectorios de backups anteriores y migraciones para evitar duplicidad de tamaño.
  2. **Programación Automática (Cron)**: Configuración configurable de días y horarios de ejecución automática con retención y purga rotativa de 3 días (`api/save_cron_backup_config_api.pl` y `api/get_cron_backup_config_api.pl`).
  3. **Restauración y Eliminación Controlada**: Despliegue de confirmaciones destructivas SweetAlert2 antes de aplicar restauraciones o purgas manuales de respaldos históricos en `dat/backups/`.
  4. **Gobernanza RBAC y UI Estándar**: Integración con el layout unificado de OSPulso (`utils/sub_sidebar.pl`, `utils/sub_bottom_nav.pl`) y protección estricta con fallback amigable mediante `utils/sub_acceso_denegado.pl`.

### 2.7 Agenda Clínica Inteligente (`views/agenda_main.pl`, `js/agenda_spa_new.js`)
- Motor de agenda multi-vista de alta fidelidad clínica (Día Matricial de Espacios, Semana Smart, Mes Grid y Reportes Operativos).
- **Gobernanza de Viewport Inviolable (`css/ospulso_master_v2.css`)**:
  1. `body.agenda-page-layout`: opera como contenedor Flexbox vertical estricto (`height: 100vh; max-height: 100vh; overflow: hidden !important;`).
  2. Menú institucional superior (`.sdm-navbar`): fijado como primer elemento `flex-shrink: 0; position: relative !important; z-index: 1060;` impidiendo cualquier solapamiento o invasión por scroll de ventana.
  3. Contenedor de contenido (`main.container-fluid`, `.sdm-layout-wrapper`, `.main-container-agenda`): confinado a `height: calc(100vh - 65px)` con scroll vertical interno exclusivo por vista (`#weekly-smart-slots-container`, `#calendar-grid-sdm`, `.dia-matrix-responsive`).
- **Normalización Canónica Universal de Espacios Físicos (`normalizarTextoEspacio`)**:
  1. Homologación tolerante a diacríticos y acentos (NFD replace): elimina tildes (`Quirófano` <=> `quirofano`).
  2. Equivalencia de sinónimos: `qx` <=> `quirofano`, `cons` <=> `consultorio`.
  3. Coherencia multi-recurso en `getFilteredAppointments` y `getAppointmentColumnId`: asegura que citas registradas con nombres acentuados en `dat/citas.dat` (ej. `Quirófano 1`) se vinculen con precisión matemática a los filtros de recursos multi-sucursal (`suc_965257_quirofano_1`) y se mantengan visibles en Día, Semana Smart y Mes Grid al alternar vistas.
- **Cuarentena de Compatibilidad**: Rutinas obsoletas o stubs legacy se agrupan al final de `js/agenda_spa_new.js` y `css/ospulso_master_v2.css` para proteger retrocompatibilidad global.

### 2.8 Mapa de Módulos del Sistema
- **Dashboard / Inicial**: `views/inicial.pl`, `views/render_dashboard_principal.pl`.
- **Agenda Clínica**: `views/agenda_main.pl`.
- **Caja Rápida (Pública/Hospitalaria)**: `views/generar_recibo.pl`.
- **Caja Consultorio (Privada/Punto de Venta)**: `views/caja_consultorio.pl`.
- **Catálogo Universal**: `views/manage_catalogo_universal.pl`.
- **Expediente Clínico & Consultas**: `views/render_expediente_clinico.pl`, `views/render_consultas.pl`, `views/render_consultas_privado.pl`.
- **Visor Médico / PACS**: `views/render_visor_medico.pl`.
- **Finanzas**: `views/finanzas.pl`, `views/estado_cuenta.pl`.
- **Reset Operativo**: `views/admin_organizacion_reset.pl`.
- **Backup & Restore**: `views/admin_backups.pl`.


