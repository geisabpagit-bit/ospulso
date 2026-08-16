# 📅 Documentación de Datos: citas.dat
**Versión**: Diamond Edition v4.2.0

## Estructura del Archivo
- **Delimitador**: `|` (Pipe)
- **Columnas**:
  1. `id_cita`: Identificador único (timestamp).
  2. `id_medico`: ID del médico tratante.
  3. `id_paciente`: ID del paciente.
  4. `fecha`: Fecha de la cita (YYYY-MM-DD).
  5. `hora_ini`: Hora de inicio (HH:MM).
  6. `hora_fin`: Hora de fin (HH:MM).
  7. `motivo`: Motivo de consulta o comentario libre.
  8. `notas`: Notas internas.
  9. `estado`: Estado de la cita (Programada, Confirmada, En consulta, Atendida, Cancelada).
  10. `event_id`: Identificador del evento sincronizado en Google Calendar.

## Reglas Operativas (Agenda Diamond v4.2.0)
- **Transición de Estados en Consulta**: Al iniciar una consulta médica privada vinculada a una cita (`render_consultas_privado.pl?id_cita=...`), el estado de la cita cambia automáticamente a `En consulta` y se actualiza `hora_ini` con la hora real de atención. Al firmar y finalizar la consulta (`cerrar_consulta_privado.pl`), el estado cambia definitivamente a `Atendida`.
- **Restricción de Consulta Única Activa por Médico**: Un médico no puede mantener 2 citas en estado `En consulta` de forma simultánea. Si intenta abrir una segunda consulta sin haber finalizado la previa, el sistema bloqueará la acción mediante una alerta modal que le exigirá concluir la consulta activa en curso.
- **Renderizado Verde Suave**: Las citas en estado `En consulta` se destacan con un color verde suave (`#dcfce7` con bordes `#86efac` y texto `#166534`) en todas las vistas (Diaria, Semanal Smart, Mensual Grid y Reportes).
- **Bloqueo Estricto de Drag and Drop**: Las citas en estado `En consulta` y `Atendida` (finalizadas) están completamente bloqueadas contra movimientos o reubicación de horario vía Drag & Drop.
- **Modo Solo Lectura (Readonly) para Citas Atendidas**: Al concluir una cita (`Atendida`), se ocultan los botones de edición, eliminación y recordatorios. Su ficha en `#modalCita` se abre únicamente en modo **Solo Lectura** bloqueando los inputs y ocultando la opción de guardar.
- **Motivo Obligatorio**: El campo `motivo` es estrictamente obligatorio para agendar o actualizar una cita tanto en la interfaz (JS) como en el backend (`api/citas_crud.pl`).
- **Codificación UTF-8**: Todo parámetro que provenga del UI y se guarde aquí es sanitizado con `use CGI qw(-utf8);` para evitar doble codificación JSON.
- **Anticolisiones (Traslapes)**: Las citas nuevas o reprogramadas son validadas en bloque, excluyendo del chequeo de colisión a las citas con estado `Atendida` o `Cancelada`, permitiendo el empalme de históricas pero bloqueando empalmes de agendamiento futuro.
