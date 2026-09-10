# Protocolos de Diagnóstico de Errores y Prevención de Crashes

## 1. Tratamiento de Errores HTTP 500 y CGI

### 1.1 Regla Mandatoria de Diagnóstico
1. **Inspección Previa de Logs**: Queda prohibido formular hipótesis a ciegas sin antes haber extraído y leído la traza de error completa del servidor Apache (`error_log`).
2. **Prohibición de Parches Superficiales**: No se permite silenciar excepciones con `try/catch` vacíos ni retornar arreglos nulos para enmascarar un fallo. Se debe resolver la causa raíz del contrato roto.
3. **Verificación de Sintaxis**: Ejecutar `perl -c <script.pl>` inmediatamente después de cualquier edición en scripts CGI.

---

## 2. Prevención de Crashes de Renderizado (Perl HEREDOC vs JavaScript)

1. **Protección de Sigilos**:
   - Escapar símbolos de arroba como `\@media` en bloques HEREDOC dobles (`print <<"HTML"`) para evitar errores de compilación `"Global symbol requires explicit package name"`.
2. **Escape de Comillas en JavaScript Inyectado**:
   - Evitar comillas simples escapadas `\'` dentro de strings de JS delimitadas por comillas simples inyectadas desde HEREDOCs de Perl. Utilizar comillas dobles internamente o backticks de ES6.
3. **Fuga de Etiquetas HEREDOC**:
   - Verificar que la etiqueta de cierre del HEREDOC coincida idénticamente con la etiqueta de apertura (ej. `PAGE_HTML` con `PAGE_HTML`).
