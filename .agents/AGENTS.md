
- Al terminar modificaciones, siempre realizar 'git add .', 'git commit' y 'git push' automaticamente.
- Al terminar modificaciones y la sincronización de git, SIEMPRE mostrar al final la respuesta el 'Plan de Verificación' detallado con los resultados.
- IMPORTANTE: Al crear o editar scripts .pl, si se inyecta CSS o Javascript dentro de bloques interpolados (como prints con comillas dobles o heredocs `<<"HTML"`), se deben escapar símbolos de arroba como `\@media` para evitar el error de compilación "Global symbol requires explicit package name".
- **REGLAS DE ORO DE ARQUITECTURA SOAP POLIMÓRFICA Y MULTI-ESPECIALIDAD**:
  1. **Contrato de Datos JSON SOAP Canónico**: Toda consulta privada debe serializarse bajo las llaves canónicas SOAP (`subjective`, `objective`, `assessment`, `plan`). Los datos dinámicos creados por especialistas DEBEN alojarse dentro de `soap.objective.especialidad_data`.
  2. **Core Pipeline Único e Inviolable**: El flujo global (Paso 0 Registro, Agenda, Expediente, Firma y Cierre con Caja) es 100% ÚNICO y compartido. Está estrictamente PROHIBIDO duplicar vistas completas por especialidad (ej. NO crear `consulta_pediatria.pl` ni `consulta_ginecologia.pl`).
  3. **Subformularios Desacoplados (Plugin Slot)**: Los subformularios de especialidad deben ser componentes modulares alojados en `views/partials/consultas/` o `views/partials/especialidades/`. Si una especialidad aún no cuenta con un subformulario propio, DEBE renderizarse el componente de fallback con Signos Vitales y la leyenda del módulo dinámico sin romper el flujo.

