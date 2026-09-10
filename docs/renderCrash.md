# Guía de Diagnóstico de Crash de Renderizado

## 1. Prevención de Errores de Renderizado
1. **Escape de Sigilos**: Escapar `@media` y símbolos `$` en HEREDOCs de Perl para evitar fallos de compilación.
2. **Escape de Comillas JS**: Evitar `\'` dentro de strings de JS inyectados desde Perl HEREDOC.
3. **Fuga de Tags HEREDOC**: Garantizar que el tag de cierre de HEREDOC coincida exactamente con el tag de apertura (ej. `PAGE_HTML` con `PAGE_HTML`).
