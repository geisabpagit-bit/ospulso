# ⚖️ Reglas de Negocio SDM v4.3.0 (Diamond Excellence)

## 1. Gestión de Citas y Agenda SPA
- **Protocolo de Color**: Programada (Navy), Confirmada (Verde), Atendida (Teal `#19B7A5`), Cancelada (Rojo), No Asistió (Ámbar).
- **Traslapes**: Validación estricta mediante algoritmo de colisión médica.

## 2. Finanzas y Trazabilidad "Path to Excellence"

### 2.1 Estructura Diamond Sync
- **OS/REC**: Nomenclatura inmutable con trazabilidad por unidad de negocio.
- **Detalle Financiero**: Todo estado de cuenta debe mostrar cronológicamente cada movimiento (Cargo/Abono) sin omisiones.

### 2.2 Protocolo de Impresión v3.7.4
- **Branding Obligatorio**: Todo reporte debe iniciar con los datos fiscales/comerciales del negocio (Nombre, Dir, Tel, Email).
- **Consolidación**: Los reportes deben cerrar con un pie de tabla (`tfoot`) que muestre la suma total de cargos y abonos.
- **Privacidad**: La columna de acciones operativas debe ser invisible en cualquier salida física/impresa.

## 3. Seguridad y Privilegios
- **Validación de Sesión**: Toda petición a la API financiera requiere una sesión activa validada por `check_session.pl`.
- **Candados de Negocio**: El acceso al sistema se bloquea automáticamente si la columna `activo` en `negocios.dat` es falsa.

## 4. Estándares UI/UX
- **Executive UI**: Las acciones financieras críticas se ubican en la tarjeta del perfil del paciente para máxima eficiencia operativa.
- **Responsividad Blindada**: Los componentes deben asegurar su visibilidad en impresión independientemente del tamaño de pantalla del dispositivo emisor.

## 5. Protocolos de Desarrollo (Technical Governance)
- **Interpolación en Perl (CSS Rules)**: Al incluir bloques CSS `@media` dentro de bloques heredoc interpolados (`print <<HTML;`), el símbolo `@` **debe escaparse siempre** como `\@media`. De lo contrario, Perl intentará interpretarlo como un arreglo (`array`), provocando errores de compilación bajo `use strict`.
- **Rutas Absolutas (Protocolo 11.1)**: Es mandatorio el uso de `$FindBin::Bin` y `File::Spec` para la construcción de rutas a archivos de datos (`.dat`) o librerías (`.pl`, `.pm`), garantizando la portabilidad entre entornos Windows (XAMPP) y Linux.
- **Nomenclatura SPA**:
    - `*_api.pl`: Endpoints que retornan exclusivamente JSON.
    - `*_spa.js`: Scripts controladores de lógica en el cliente.
    - `views/*.pl`: Renderizadores de interfaz híbrida.

## 6. Contextualización de Orden de Servicio (OS)
- **Cierre de Ciclo**: Los nuevos tratamientos pueden agregarse a una OS existente mediante la función `abrirModalCargoConOS(id_os)`, la cual bloquea el contexto de la orden para evitar duplicidad de folios.
- **Reinicio de Contexto**: Al abrir un cargo general, el sistema debe limpiar obligatoriamente la variable global `windowActiveOS` para garantizar la creación de un nuevo folio único.

## 7. Atribución de Movimientos y Seguridad
- **ID Médico Obligatorio**: Todo movimiento financiero debe estar vinculado al `id_medico` de la sesión activa. Está estrictamente prohibido el uso de "SISTEMA" como ID por defecto si existe un usuario médico logueado.
- **KPI Sync**: El Dashboard Principal (`inicial.pl`) filtra los montos de Cargos/Abonos basándose estrictamente en el ID del médico, garantizando que cada profesional visualice solo sus ingresos generados.

## 8. Navegación y Usabilidad Responsiva
- **Prioridad Sidebar**: En móviles, la navegación de módulos debe delegarse exclusivamente al Sidebar Lateral para no saturar el área de visualización clínica.
- **Estado de Pestañas**: La pestaña activa debe resaltarse visualmente tanto en el Dock (Desktop) como en el Sidebar (Mobile) para orientar al usuario en su flujo de trabajo.
- **Visores de Previsualización**: Todo archivo adjunto (PDF/Imagen) debe abrirse en un modal de previsualización que ocupe al menos el 90% del ancho de pantalla en móviles.

## 9. Gestión de Suscripciones (Blindaje Diamante)
- **Auto-Lock**: La expiración de la fecha en `negocios.dat` provoca la desactivación inmediata de la columna `Activo` mediante el motor `db_manager.pm`.
- **Triple Validación**: El estado de suscripción se verifica en (1) Verificación de Email, (2) Proceso de Login y (3) Cada interacción mediante `check_session.pl`.
- **Jerarquía**: Se debe distinguir visualmente entre Matriz y Sucursal mediante Badges Bento en el perfil.

## 10. Arquitectura de Perfil Mutante
- **Detección de Rol**: La interfaz de perfil debe conmutar automáticamente entre "Configuración de Clínica" y "Ficha Clínica" basándose en el rol del usuario logueado.
- **Persistencia Atómica**: Las actualizaciones de perfil deben impactar simultáneamente a `usuarios.dat`, `negocios.dat` y `pacientes.dat` según corresponda, garantizando la consistencia de la identidad.

## 11. Gestión Avanzada de Citas y Cirugías (v4.0.0)
- **Validación de Identidad**: El nombre del paciente es de **solo lectura (readonly)** durante la edición de una cita existente para prevenir errores de integridad referencial.
- **Buscador Mandatorio**: No se permite el guardado de citas si el paciente no ha sido seleccionado mediante el motor de autocompletado (validación de ID interno).
- **Regla de Cirugía (Lunch Bypass)**: Las citas marcadas como "Todo el día" o "Resto del día" (que terminan al final de la jornada laboral) omiten automáticamente la validación de traslape con el horario de comida, bajo responsabilidad del médico.
- **Normalización de Tiempos**: Para garantizar la precisión del algoritmo de colisiones, todas las horas se procesan con relleno de ceros (*padding*) de 5 caracteres (ej. `09:30`).
- **Blindaje de Slots**: Al agendar una cita de jornada completa, el sistema bloquea automáticamente todos los intervalos de 30m de ese día en la cuadrícula de disponibilidad.

## 12. Densidad Inteligente de Agenda (Smart Weekly)
- **Adaptabilidad**: El sistema debe ajustar el número de tarjetas de días visibles según el viewport: **3 días** para móviles (centrados) y **7 días** para tabletas/escritorio.
- **Sincronización de Títulos**: Las etiquetas de navegación (headers) deben ser dinámicas y descriptivas (ej: "Agenda de Hoy", "Reporte Mensual") para evitar desorientación del usuario.

## 13. Integración de Ajustes (WebApp Architecture)
- **Acceso en Móvil**: El botón de engrane (ajustes) debe integrarse exclusivamente en el menú inferior persistente en dispositivos móviles, consolidando el módulo como una WebApp coherente.
- **Acceso en Desktop**: Se mantiene la visibilidad en la cabecera principal para flujos de trabajo de alta velocidad.

## 14. Panel de Navegación Lateral (Daily View)
- **Persistencia**: En modo escritorio, la vista diaria **debe** mostrar el mini-calendario lateral izquierdo de forma permanente para permitir saltos temporales rápidos sin recargar la vista.

## 15. Estabilidad de Interfaces (Ergonomía de Modales)
- **Prevención de Desborde**: Todo modal interactivo debe limitar su altura al **92% del viewport** y delegar el scroll al cuerpo del modal (`modal-body`), garantizando que los botones de acción (Guardar/Cerrar) permanezcan siempre visibles o accesibles.

## 16. Reglas de Oro de Arquitectura SOAP Polimórfica y Multi-Especialidad
1. **Contrato de Datos JSON SOAP Canónico**: Toda consulta privada debe serializarse bajo las llaves canónicas SOAP (`subjective`, `objective`, `assessment`, `plan`). Los datos dinámicos creados por especialistas DEBEN alojarse dentro de `soap.objective.especialidad_data`.
2. **Core Pipeline Único e Inviolable**: El flujo global (Paso 0 Registro, Agenda, Expediente, Firma y Cierre con Caja) es 100% ÚNICO y compartido. Está estrictamente PROHIBIDO duplicar vistas completas por especialidad (ej. NO crear `consulta_pediatria.pl` ni `consulta_ginecologia.pl`).
3. **Subformularios Desacoplados (Plugin Slot)**: Los subformularios de especialidad deben ser componentes modulares alojados en `views/partials/consultas/` o `views/partials/especialidades/`. Si una especialidad aún no cuenta con un subformulario propio, DEBE renderizarse el componente de fallback con Signos Vitales y la leyenda del módulo dinámico sin romper el flujo.

## 17. Gestión Financiera de Caja y Cobro por Recepción (v4.3)
- **Alta Médica por Defecto**: Si la cotización en Paso Registro es "ninguna" o vacía, la lista "Destino del Tratamiento" debe tener por defecto la opción "Finalizar y Cerrar tratamiento (Alta médica)".
- **Cobro por Recepción**: La opción "Cobro por recepción" fija el abono inmediato del Wizard en `$0.00` y delega la cobranza al personal con rol `Recepcionista`. El backend registra exclusivamente el **Cargo** en `estado_cuenta.dat` sin generar **Abono**, dejando el saldo pendiente.
- **Protección de Saldo Negativo**: Toda consulta con abono directo pero sin cotización previa genera automáticamente un cargo explícito por "Consulta Médica" por igual monto, garantizando que el saldo neto nunca quede negativo (-$500.00).

## 18. Cédula Profesional y Prescripción Médica (NOM-024-SSA3)
- **Atributo Inmutable de Médico**: El campo "Cédula Profesional" reside en el índice 9 de `usuarios.dat`.
- **Enlace Automático**: Al renderizar el paso SOAP y formalizar la receta médica, la cédula del médico tratante se inyecta automáticamente en la UI y en la plantilla PDF de impresión oficial.

## 19. Consentimiento Informado (NOM-004-SSA3) y Firma Digital/FIEL
- **Aceptación Obligatoria**: La expedición de consentimientos informados exige el marcado explícito de la casilla de explicación y riesgos en el paso Comunicación.
- **Desacoplamiento de Firmas**: Las firmas autógrafas capturadas en canvas se guardan en el servidor como imágenes PNG físicas (`uploads/firmas/*.png`) referenciadas en JSON, manteniendo compatibilidad con Firma Electrónica Avanzada FIEL/e.firma.

## 20. Selección Opcional de Diagnósticos CIE-10 y CIF
- **Default Desactivado**: El switch `¿Utilizar el catálogo oficial Diagnóstico CIE-10 / Valoración CIF?` inicia desactivado (NO).
- **Validación Dinámica**: Al estar desactivado, los campos CIE-10 y CIF se ocultan y no se exige la propiedad `required`. Al activarlo (SÍ), se despliega el catálogo y se exige la selección de diagnóstico principal.

### 📋 Reglas de Registro Diamond Edition (v4.2)
1.  **Sincronización de ID**: Todo nuevo registro debe obtener su ID desde `contador_registro_inicial.dat` usando `abs(time)` como respaldo. Se debe usar `flock` durante la actualización del contador.
2.  **Integridad de Persistencia**: El archivo `usuarios.dat` debe terminar siempre en un salto de línea (`\n`). Cada nuevo registro debe asegurar un salto de línea previo si el archivo no lo tiene.
3.  **Transparencia de Sincronización**: Si el usuario desactiva el consentimiento de Google Calendar, el sistema DEBE mostrar una advertencia visual (Warning) antes de procesar el registro, informando sobre la pérdida de sincronización de agenda.
4.  **Confirmación Post-OAuth**: Tras el retorno exitoso de Google, el sistema debe redirigir al landing page (`index.html`) para mostrar el modal de éxito unificado, nunca quedarse en una página de callback estática.

**GEISABPA - Diamond Edition v4.3.0**
