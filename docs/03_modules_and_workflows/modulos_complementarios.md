# Módulos Complementarios y Especializados (SDM / OSPulso 2.0)

## 1. Visión General
Este documento agrupa la especificación de los módulos complementarios y especializados integrados en la plataforma OSPulso / SDM.

---

## 2. Especificación por Módulo

### 2.1 Agenda y Citas Médicas (`views/agenda_main.pl`, `api/citas_crud.pl`, `js/agenda_spa_new.js`)
- Administración de calendario por médico tratante, especialidad y consultorio.
- Vistas disponibles: Principal (`agenda_main.pl`), Lista (`agenda_vista_lista.pl`), Semanal (`agenda_vista_semanal.pl`) y Mensual (`agenda_vista_mensual.pl`).
- **Aislamiento Multi-Tenant y Reglas para Consultorio Individual**:
  1. **Sucursales y Sedes**: El endpoint `api/citas_crud.pl?accion=get_form_metadata` filtra estrictamente por el `id_empresa` del usuario autenticado. Para un **"Consultorio Individual"**, devuelve únicamente su sede propia sin permitir sucursales foráneas ni matrices ajenas.
  2. **Recursos Físicos (`get_recursos`)**: Si la organización es un **"Consultorio Individual"**, el sistema fuerza de forma inviolable la disponibilidad de **1 solo consultorio físico** ("Consultorio 1" y opción "Virtual") y **0 quirófanos**. En clínicas con hospitalización o múltiples sedes, consulta dinámicamente los recursos configurados en `dat/negocios_config.dat`.
  3. **Eventos y Filtro de Médicos**: La consulta de eventos (`get_events`) y el catálogo de profesionales en el modal de citas aíslan rigurosamente a los médicos pertenecientes al `id_empresa` de la sesión, impidiendo fugas entre organizaciones.
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
- **Navegación y Vista Diaria de Días Pasados**:
  1. **Empty State**: Si se navega a un día pasado sin citas registradas, la vista diaria renderiza una tarjeta acrílica centrada (`.agenda-empty-day-card`) indicando *"Sin actividad registrada para este día"* y botón de regreso a hoy.
  2. **Historial Ejecutivo y Citas No Realizadas**: Si hubo citas en el día pasado, se despliega una lista cronológica ejecutiva estilizada con acceso directo al expediente, badge de estado rojo contrastado, botón directo de **"Tomar Cita"** (`window.tomarCitaDirecto`) para citas no atendidas, botón de **"Re-agendar / Modificar"** y botón para ver el detalle.
- **Acción Canónica "Tomar Cita" y Vista Semanal Interactiva**:
  1. **Disponibilidad Universal de "Tomar Cita"**: Para cualquier cita que no se encuentre formalmente `Atendida` o `Cancelada`, el médico puede iniciar la consulta médica inmediatamente (`render_consultas.pl?id=${id_paciente}&id_cita=${id_cita}`) tanto desde los botones rápidos en las vistas Diaria, Semanal y Mensual, como desde el botón mandante `#btn-tomar-cita` en el modal de gestión de citas (`#modalCita`), tanto en modo lectura/detalle como en modo edición/re-agendar.
  2. **Vista Semanal Inteligente y Citas Extemporáneas**: En `renderWeeklySmartView` y `renderSmartSlots`, la tira de 7 días expone píldoras con el conteo de citas registradas por día. Los slots ocupados no se bloquean con `disabled`; se renderizan como tarjetas interactivas con el nombre del paciente, badge de estado y botones de acción ("Tomar Cita", "Re-agendar", "Ver Detalle"). Las citas fuera de jornada o extemporáneas se renderizan en una sección visible dedicada para garantizar que ninguna cita quede oculta.
  3. **Gestión de Colisiones Extemporáneas**: Si se toma una cita del pasado o fuera de horario que empalme con otra cita ya agendada para el momento actual, el sistema emite una alerta SweetAlert2 de confirmación previa antes de transferir el flujo a la consulta SOAP.
- **Mini Calendario Lateral con Borde Teal**:
  1. Presenta botones de navegación de mes (`<` Mes Año `>`), píldoras interactivas con indicador de día actual (`is-today`), días con citas (`has-apts`), grid CSS de 7 columnas indestructible (`.side-cal-grid`) y borde mandante teal `rgba(25, 183, 165, 0.4)`.

### 2.2 Quirófano Kanban (`views/quirofano_kanban.pl`)
- Tablero visual de flujo de cirugías en tiempo real.
- Estados: *Programada*, *En Preparación*, *En Quirófano*, *Recuperación* y *Alta Quirúrgica*.
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

### 2.7 Mapa de Módulos del Sistema
- **Dashboard / Inicial**: `views/inicial.pl`, `views/render_dashboard_principal.pl`.
- **Caja Rápida (Pública/Hospitalaria)**: `views/generar_recibo.pl`.
- **Caja Consultorio (Privada/Punto de Venta)**: `views/caja_consultorio.pl`.
- **Catálogo Universal**: `views/manage_catalogo_universal.pl`.
- **Expediente Clínico & Consultas**: `views/render_expediente_clinico.pl`, `views/render_consultas.pl`, `views/render_consultas_privado.pl`.
- **Visor Médico / PACS**: `views/render_visor_medico.pl`.
- **Finanzas**: `views/finanzas.pl`, `views/estado_cuenta.pl`.
- **Reset Operativo**: `views/admin_organizacion_reset.pl`.
- **Backup & Restore**: `views/admin_backups.pl`.

