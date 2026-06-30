# ⚙️ Documentación de Datos: agenda_config.dat & agenda_config_medico_X.dat
**Versión**: Diamond Edition v4.2.0

## Estructura del Archivo (Formato Clave=Valor)
- **Formato**: Cada línea representa una configuración en `llave=valor`.
- **Campos Principales**:
  - `horario_inicio`: Inicio de jornada (HH:MM).
  - `horario_fin`: Fin de jornada (HH:MM).
  - `horario_comida_inicio`: Inicio receso (HH:MM).
  - `horario_comida_fin`: Fin receso (HH:MM).
  - `intervalo_minutos`: Duración del slot de la agenda (ej. 15, 30, 45, 60).
  - `dias_habiles`: Días laborables en formato ISO (1=Lunes, 7=Domingo). Separados por coma.
  - `festivos`: Fechas asueto personales (YYYY-MM-DD), separados por coma.

## Mega Regla de Guardado y Colisiones (v4.2.0)
- **Unificación Sin Versionado**: Para evitar riesgos críticos de arquitectura, el archivo de configuración es único y plano, sobrescribiendo las preferencias pasadas sin crear un sistema de versionado histórico (lo que afectaría el performance de lectura masiva).
- **Escaneo Predictivo de Agenda**: Al actualizar los horarios (vía `save_config` en `citas_crud.pl`), el backend ejecuta un escaneo completo de `citas.dat`.
- **Alerta de Conflictos (SweetAlert Warning)**: Si existen citas programadas **en el futuro** que entren en conflicto con el nuevo horario (caen en comida, fin de jornada, o un nuevo asueto), el sistema permitirá el guardado, pero enviará un `res.warning`. 
- **Acción Manual Sugerida**: La UI presentará al usuario cuántas citas colisionan para que este las reubique manualmente usando la interfaz de Drag & Drop en la vista mensual, manteniendo el histórico y el control humano sobre la agenda.
