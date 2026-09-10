# Protocolos de Diagnóstico y Tratamiento de Errores 500

## 1. Regla Mandatoria de Diagnóstico
1. **Inspección Previa de Logs**: Extraer y leer siempre la traza de error completa del servidor Apache (`error_log`) antes de formular cualquier hipótesis.
2. **Sin Parches Superficiales**: Queda prohibido silenciar excepciones o retornar fallbacks vacíos de 0 bytes. Identificar y corregir la causa raíz.
3. **Verificación de Sintaxis**: Ejecutar `perl -c <script.pl>` inmediatamente tras modificar código Perl CGI.
