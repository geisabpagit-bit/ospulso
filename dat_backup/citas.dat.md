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
  9. `estado`: Estado de la cita (Programada, Confirmada, Atendida, Cancelada).
  10. `event_id`: Identificador del evento sincronizado en Google Calendar.

## Reglas Operativas (Agenda Diamond v4.2.0)
- **Codificación UTF-8**: Todo parámetro que provenga del UI y se guarde aquí es sanitizado con `use CGI qw(-utf8);` para evitar doble codificación JSON.
- **Guardado de Duración Real**: Al realizar "Check-In" y "Firmar y Finalizar", el estado cambia a `Atendida`, y los campos `hora_ini` y `hora_fin` se sobrescriben con la duración efectiva de la consulta.
- **Anticolisiones (Traslapes)**: Las citas nuevas o reprogramadas son validadas en bloque, excluyendo del chequeo de colisión a las citas con estado `Atendida` o `Cancelada`, permitiendo el empalme de históricas pero bloqueando empalmes de agendamiento futuro.
- **Predictibilidad (Mega Regla)**: La tabla de citas es analizada preventivamente al guardar la configuración de horario en `agenda_config_medico_X.dat` para advertir sobre citas preexistentes que caen fuera de los nuevos márgenes o días no laborables.
