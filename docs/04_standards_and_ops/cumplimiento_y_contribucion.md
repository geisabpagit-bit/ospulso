# Cumplimiento Normativo (NOM-004 / NOM-024) y Especificaciones de Pull Request

## 1. Cumplimiento Normativo Sanitario

### 1.1 Expediente Clínico Electrónico (NOM-004-SSA3-2012 / NOM-024-SSA3-2012)
1. **Inmutabilidad y Firma Digital**: Las notas médicas SOAP finalizadas e impresas quedan autenticadas digitalmente con fecha, hora e identificador de cédula del facultativo.
2. **Confidencialidad y Privacidad**: Datos de salud protegidos estrictamente bajo RBAC; accesibles únicamente por personal autorizado.
3. **Conservación de Documentación**: Los registros médicos y archivos adjuntos se conservan por un periodo mínimo legal de 5 años.

---

## 2. Especificaciones de Pull Requests y Revisiones de Código

1. **Mensajes de Commit Convencionales**:
   - `feat:` Nuevas funcionalidades.
   - `fix:` Correcciones de errores.
   - `style:` Cambios visuales / CSS sin alterar lógica.
   - `docs:` Actualización de documentación.
   - `refactor:` Mejoras internas de código.
2. **Sincronización Git Automática**: Al completar modificaciones, ejecutar automáticamente `git add .`, `git commit` y `git push`.
3. **Verificación Previa**: Correr `perl -c <script.pl>` antes de cualquier commit.
