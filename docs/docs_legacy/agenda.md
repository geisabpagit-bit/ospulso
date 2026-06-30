# 📅 Macroproceso de Agenda (SDM Smart Agenda SPA)

Este documento centraliza todas las particularidades, reglas de negocio y estándares aplicables al macroproceso de gestión de citas y agenda electrónica en el Software Dental Mexicano (SDM), extrayendo los lineamientos de la arquitectura **Diamond Excellence v4.2.0**.

---

## 1. Reglas de Negocio y Operación

### 1.1 Estados y Protocolo de Color
- **Programada**: Azul Marino (Navy).
- **Confirmada**: Verde (Éxito).
- **Atendida**: Azul Profundo (Deep Blue).
- **Cancelada**: Rojo (Peligro/Alerta).
- **No Asistió**: Ámbar/Naranja.

### 1.2 Flujo de Citas desde Pacientes (CRM)
- **Precarga Automática**: Si un usuario accede a la agenda proveniente del módulo de pacientes, cualquier intento de agendar ("Nueva Cita" o al hacer clic en un slot libre) bloqueará el buscador y preasignará al paciente.
- **Transición a Consulta**: En el modo de edición de cita, se presentará el botón "Tomar Cita e Ir a Consulta" únicamente si la cita pertenece a la fecha actual (o anterior) y si la hora de la misma no supera en más de 1 hora a la hora actual.

### 1.3 Algoritmo de Colisión (Traslapes)
- **Validación Estricta (Guardado)**: Al intentar guardar una cita, el sistema verifica que la hora de inicio y fin no se empalme con ninguna otra cita programada para ese día y médico, previniendo colisiones de agendamiento manual.
- **Excepción de Colisión**: Las citas que han concluido y tienen el estado "Atendida" son ignoradas por el algoritmo de colisión, liberando el slot en la base de datos para citas retroactivas o emergencias.
- **Blindaje de Slots**: Al agendar una cita de jornada completa (o resto del día), el sistema bloquea automáticamente todos los intervalos afectados en la cuadrícula de disponibilidad.
- **Regla de Cirugía (Lunch Bypass)**: Citas marcadas como "Todo el día" o "Resto del día" omiten la validación de traslape con el horario de comida, recayendo la responsabilidad en el médico.
- **Normalización**: Las horas se procesan con relleno de ceros (padding) a 5 caracteres (ej. `09:30`) para garantizar exactitud.

### 1.4 Integridad Referencial
- **Validación de Identidad**: Durante la edición de una cita existente, el nombre del paciente es de **solo lectura (readonly)** para prevenir errores de asignación.
- **Buscador Mandatorio**: El registro de una cita requiere que el paciente sea seleccionado mediante el autocompletado (garantizando un ID válido).

### 1.5 Trazabilidad Clínica y Guardado Dinámico
- **Handshake de Estados y Tiempo Real**: Al finalizar una consulta médica presionando "Firmar y Finalizar Consulta", el sistema actualiza automáticamente la cita en la agenda. El estado cambia a "Atendida", y se sobreescriben la **fecha, hora de inicio y duración aproximada** para reflejar el tiempo real invertido, independientemente del horario originalmente agendado.

---

## 2. Experiencia de Usuario (UI/UX) y Navegación

### 2.1 Arquitectura Visual (Liquid Motion Healthcare)
- **Segmentación Horaria**: División visual clara (MAÑANA, TARDE, NOCHE) con iconos para escaneo rápido.
- **Animaciones Staggered**: Aparición secuencial de slots (delay de `0.03s`) para un efecto fluido al cargar días.

### 2.2 Densidad Inteligente (Smart Weekly)
- **Adaptabilidad de Viewport**: 
  - **Mobile**: Vista semanal centrada mostrando **3 días** (asegurando legibilidad).
  - **Desktop/Tablet**: Vista equilibrada de **7 días**.
- **Sincronización de Títulos**: Cabeceras dinámicas y descriptivas (ej: "Agenda de Hoy") según la fecha o vista activa.

### 2.3 Panel de Navegación Lateral (Desktop)
- En modo escritorio, la vista diaria **debe** fijar un mini-calendario lateral interactivo para saltos temporales rápidos (Split View 30/70).

### 2.4 Control de Ajustes y Modal
- **Mobile WebApp**: El botón de "Ajustes" desaparece de la cabecera y se aloja en la navegación inferior persistente (Bottom Nav).
- **Desktop**: Se mantiene en la cabecera operativa.
- **Ergonomía de Modales**: Altura máxima de `92vh` con scroll interno en `modal-body` para no perder de vista los botones de guardado.

---

## 3. Vistas y Reportes (SPA Engine)

- **Vistas Operativas**: 
  - Día (Timeline con intervalos, e.g., 30m).
  - Semana Smart (Tarjetas flexibles).
  - Mensual (Calendario Grid).
- **Reportes (DataTables)**:
  - Semanal y Mensual.
  - Exportación estándar: PDF, Excel, Copiar, Imprimir (usando colores institucionales e iconos a la izquierda).
  - Adaptación Mobile: Uso de **MiniCards** en lugar de desbordar la tabla.
