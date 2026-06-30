Analiza el flujo actual del archivo render_visor_medico.pl:

1. **Diagnóstico técnico**:
   - El script guarda una sola imagen y sobrescribe la anterior.
   - No existe lógica de acumulación ni índice de imágenes.
   - Se requiere ampliar la lógica para soportar múltiples imágenes por estudio.

2. **Propuesta de mejora**:
   - Implementar almacenamiento incremental en carpetas por paciente/estudio.
   - Nombrar archivos con índice o timestamp (imagen_001.png, imagen_002.png...).
   - Mantener un archivo metadata.json con referencias a todas las imágenes.
   - Usar variable de sesión o token para identificar el estudio activo.
   - Consolidar el estudio solo al subir todos los archivos.

3. **Modelo de datos JSON para estudios médicos**:
   - Estructura principal con id_estudio, id_paciente, nombre_estudio, fecha_creacion, estado.
   - Array de imágenes con id_imagen, nombre_archivo, ruta, fecha_subida, notas y anotaciones.
   - Bloque de metadatos técnicos (equipo, resolución, formato, versión).
   - Array de observaciones médicas con autor, fecha y texto.

4. **JSON Schema de validación**:
   - Validar tipos de datos (integer, string, date-time).
   - Asegurar que cada imagen tenga id_imagen, nombre_archivo, ruta y fecha_subida.
   - Controlar estado con enum ["en_edicion", "finalizado"].
   - Arrays para imágenes y observaciones médicas.
   - Modularidad para validar bloques independientes.

5. **Ejemplo de integración en Perl**:
   - Al guardar imagen:
     - Crear carpeta si no existe.
     - Calcular índice incremental.
     - Guardar archivo con nombre único.
     - Actualizar metadata.json.
   - Validar JSON contra el Schema antes de persistir.

Objetivo: Documentar y visualizar el flujo completo desde el diagnóstico técnico hasta la validación de datos, asegurando escalabilidad, trazabilidad y compatibilidad con estándares médicos (FHIR).
