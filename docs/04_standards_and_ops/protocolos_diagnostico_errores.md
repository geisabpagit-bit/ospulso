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

---

## 4. Blindaje contra Scripts de Mantenimiento y Pruebas en Producción

### 4.1 Causa Raíz: Invocación de Scripts Huérfanos o de Prueba
- **Scripts de Reseteo No Autenticados**: Scripts como `scratch_reset.pl`, `utils/reset_tablas.pl` y `scratch/test_flujo_completo.pl` eran accesibles vía web pública (`.pl` con CGI habilitado) o invocables por tareas Cron.
- **Inyección de Datos Dummy**: La ejecución accidental de `test_flujo_completo.pl` borraba `usuarios.dat` e insertaba usuarios de prueba ficticios (`PAC-TEST-...`, `Juan Pérez Test`).

### 4.2 Medidas Defensivas Obligatorias y Auditoría Forense
1. **Eliminación Física Definitiva de Scripts Radioactivos**:
   - Se eliminaron permanentemente del repositorio (`git rm -f`): `scratch_reset.pl`, `utils/prueba_inicial.pl`, `utils/reset_tablas.pl`, `scratch/test_flujo_completo.pl` y `scratch/ejecutar_hard_reset.pl`.
2. **Blindaje Estructural en el Kernel (`utils/db_manager.pm`)**:
   - `actualizar_archivo()` cuenta con una guardia inquebrantable: si la tabla destino es crítica (`usuarios.dat`, `negocios.dat`, `negocios_config.dat`, `perfiles.dat`) y la lista de registros a escribir está vacía (`0 registros`), la operación aborta con `die` impidiendo que cualquier bug o filtro vacío trunque el archivo en disco.
3. **Bloqueo de Truncado en Consola (`views/manage_config.pl`)**:
   - La acción `do_truncate` bloquea cualquier intento de vaciar tablas maestras y el botón visual "Vaciar Tabla" permanece oculto para archivos protegidos.
4. **Vaciado de Endpoints Radioactivos (`api/hard_reset_db_api.pl`)**:
   - Se despojó de todo código de reseteo y retorna inmediatamente `403 Forbidden`.
5. **Aislamiento Perimetral y Gobernanza de Medios (Arquitectura de 4 Fases)**:
   - **Fase 1 (Control de Acceso en `dat/`)**: `dat/.htaccess` implementa una política Zero-Trust con denegación general por defecto (`Require all denied`) y bloqueo de listado (`Options -Indexes`), permitiendo mediante `FilesMatch` exclusivamente recursos estáticos autorizados (`.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.svg`, `.pdf`, `.zip`) para garantizar visualización sin exponer las bases de datos planas (`.dat`), contadores o logs.
   - **Fase 2 (Separación Canónica en `uploads/`)**: Se consolidó la estructura física de subidas (`uploads/avatars/`, `uploads/logos/`, `uploads/crm/`, `uploads/migraciones/`, `uploads/firmas/`). El archivo `uploads/.htaccess` restringe la ejecución de scripts (`RemoveHandler`, `php_flag engine off`, `Require all denied` a `.php`, `.pl`, `.py`, `.sh`) y autoriza únicamente el despacho de recursos multimedia y documentos.
   - **Fase 3 (Gobernanza de Avatares y Resiliencia Visual)**: Se configuró `.gitignore` para versionar la estructura de carpetas (`.gitkeep`) y logos oficiales. En `utils/sub_edita_perfil.pl` y `utils/sub_header.pl` se implementó validación física en disco (`-f`) y eventos `onerror` inline para fallback automático a iniciales o icono SVG neutro, eliminando recuadros rotos por desincronización de entornos.
   - **Fase 4 (Cumplimiento NOM-004 para Estudios Diagnósticos)**: La carpeta `dat/estudiosRX/` cuenta con un `.htaccess` estricto que anula la herencia de medios (`FilesMatch ".*" Require all denied`). Toda radiografía, tomografía o imagen clínica sólo puede ser consumida a través del proxy autenticado `api/read_estudio_api.pl`, el cual exige sesión médica activa (`check_session()`) y valida permisos de paciente/médico.
   - `utils/.htaccess` y `scratch/.htaccess` mantienen bloqueo total (`Require all denied`).
   - El `.htaccess` de la raíz bloquea mediante regex cualquier script que coincida con `^(scratch_.*|test.*|prueba.*|mock.*|hard_reset.*|fix_.*)\.(pl|py|sh|ps1)$`.
6. **Consistencia de Cabeceras Canónicas**:
   - Se normalizaron todos los endpoints de organizaciones y ejecutivos (`crud_organizaciones_api.pl`, `crud_ejecutivos_api.pl`) para exigir y escribir siempre la cabecera canónica de 12 columnas en `usuarios.dat`.



