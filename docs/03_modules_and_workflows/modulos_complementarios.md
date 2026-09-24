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
- **Saneamiento Automático de Citas Vencidas ("No realizada")**:
  1. Si una cita programada o confirmada no fue atendida ni cancelada y su fecha/hora de finalización ya expiró (`fecha < hoy` o `fecha == hoy && hora_fin < hora_actual`), el backend (`api/citas_crud.pl`) actualiza automáticamente su estado a `No realizada` al consultar la agenda y persiste el cambio en `dat/citas.dat`.
  2. El modal de gestión de citas permite además la selección y edición manual del estado `No realizada`.
  3. Las citas con estado `No realizada` se excluyen de la detección de colisiones de horario para no bloquear nuevas reservas.
- **Navegación y Vista Diaria de Días Pasados**:
  1. **Empty State**: Si se navega a un día pasado sin citas registradas, la vista diaria renderiza una tarjeta acrílica centrada (`.agenda-empty-day-card`) indicando *"Sin actividad registrada para este día"* y botón de regreso a hoy.
  2. **Historial Ejecutivo**: Si hubo citas en el día pasado, se despliega una lista cronológica ejecutiva estilizada con acceso directo al expediente y detalle de la cita.
- **Mini Calendario Lateral con Borde Teal**:
  1. Presenta botones de navegación de mes (`<` Mes Año `>`), píldoras interactivas con indicador de día actual (`is-today`), días con citas (`has-apts`) y borde mandante teal `rgba(25, 183, 165, 0.4)`.

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
- **Datos Eliminados**: Recibos de caja rápida, movimientos de estado de cuenta, citas de agenda, consultas clínicas SOAP, recetas, consentimientos, notas de borrador, gastos operativos, pacientes de mostrador y cotizaciones/tratamientos.
- **Datos Conservados**: Cuentas de usuario (médicos, recepcionistas, administradores), catálogo universal de servicios/productos, tarifas y configuraciones del tenant.
- **Gobernanza de Folios y Diferenciación Ontológica**:
  1. **Organizaciones con CLUE y `PACIENTES_ESTADO = 1`**: La UI despliega los campos numéricos de configuración para definir el folio inicial de recibos privados y recibos públicos (convenios municipales).
  2. **Consultorio Individual o sin `PACIENTES_ESTADO`**: Se oculta la solicitud de folios y el backend reinicia automáticamente a cero (`LAST_FOLIO = 0`, próximo recibo emitido #1) el único contador de recibos privados de la organización en `contadores_recibos_privados_*.dat`, sin requerir configuración manual ni tocar contadores públicos.

### 2.5 Mapa de Módulos del Sistema
- **Dashboard / Inicial**: `views/inicial.pl`, `views/render_dashboard_principal.pl`.
- **Caja Rápida**: `views/generar_recibo.pl`.
- **Catálogo Universal**: `views/manage_catalogo_universal.pl`.
- **Expediente Clínico & Consultas**: `views/render_expediente_clinico.pl`, `views/render_consultas.pl`.
- **Visor Médico / PACS**: `views/render_visor_medico.pl`.
- **Finanzas**: `views/finanzas.pl`, `views/estado_cuenta.pl`.
- **Reset Operativo**: `views/admin_organizacion_reset.pl`.
