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

---

## 3. Protocolo de Sincronización y Blindaje de Datos Flat-File (.dat)

### 3.1 Causa Raíz de Inaccesibilidad por Sincronización
- **Vaciado Inadvertido por FTP**: Si se ejecuta una sincronización desde un servidor remoto/staging cuya base flat-file contiene archivos vírgenes o solo encabezados (ej. `negocios.dat`, `negocios_config.dat`, `perfiles.dat`), la sobreescritura local destruye los tenants registrados.
- **Efecto Cascada en Autenticación**: Al quedar `negocios.dat` sin los registros de organizaciones (ej. ID `723800`), la subrutina `verificar_estado_negocio` en `auth/acceso.pl` reporta cuenta inactiva o suscripción vencida, bloqueando a todo el personal ("Acceso Denegado").

### 3.2 Blindaje Preventivo Mandatorio (`sincronizar_dat_ftp.ps1`)
1. **Respaldo Automático con Timestamp**: Todo proceso de sincronización debe generar obligatoriamente una copia íntegra en `dat_backup_YYYYMMDD_HHMMSS/` antes de procesar cualquier archivo.
2. **Protección Anti-Vaciado (Guardia de Tamaño)**:
   - Las tablas críticas del sistema (`negocios.dat`, `negocios_config.dat`, `perfiles.dat`, `usuarios.dat`, `estado_cuenta.dat`, `pacientes.dat`, `citas.dat`) no se deben sobreescribir si el archivo remoto tiene un tamaño $\le 250$ bytes (solo encabezado) mientras el archivo local cuenta con registros activos.
   - Para forzar la sobreescritura intencional se requiere el parámetro explícito `-ForceOverwrite`.

