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

---

## 3. Sincronización y Respaldo de Datos Vivos (`dat/`)

Para descargar datos reales de pacientes, citas y finanzas generados en producción hacia el entorno local sin riesgo de pérdida de información:
1. **Script de Sincronización FTP (`sincronizar_dat_ftp.ps1`)**:
   - Conecta a `ftp.ospulso.com:21` bajo protocolo seguro TLS/FTPS (con fallback a texto plano si el servidor lo requiere).
   - Permite selección interactiva o por parámetro del usuario (cuenta maestra `ospulso` o cuenta de cPanel `usuario@ospulso.com`).
   - Solicita la credencial de forma encriptada en memoria (`Read-Host -AsSecureString`).
   - Auto-detecta la ruta remota de la carpeta clínica (`public_html/dat`, `dat` o `/`).
   - Incluye blindaje anti-vaciado y crea un respaldo preventivo fechado (`dat_backup_YYYYMMDD_HHMMSS`) en la raíz del proyecto antes de sobreescribir.
   - Descarga de forma recursiva todos los catálogos y archivos planos hacia `c:\xampp\htdocs\ospulso\dat\`.

---

## 4. Despliegue en Caliente de Código Fuente (Git Hot-Deploy)

Para desplegar actualizaciones de código desde GitHub hacia el servidor de producción sin afectar las bases de datos planas en vivo:
1. **Script Bash Autónomo (`hot_deploy.sh`)**:
   - Auto-posicionamiento en la raíz del proyecto (`$DIR_RAIZ`, equivalente a `public_html`).
   - Candado de concurrencia mediante `dat/hot_deploy.lock` y auditoría en `dat/hot_deploy.log`.
   - Respaldo atómico preventivo de la carpeta `dat/` hacia `dat_backup_seguridad_temp/`.
   - Sincronización forzada con Git (`git fetch origin main` y `git reset --hard origin/main`).
   - Restauración íntegra de los datos reales de producción sobre `dat/` y remoción del respaldo temporal.
   - Normalización automática de permisos (`chmod 755`) y saltos de línea LF mediante `bash fix_permissions.sh`.
2. **Endpoint Seguro de Disparo (`api/hot_deploy_api.pl`)**:
   - Control de acceso estricto RBAC: Exclusivo para el rol `Administrador Global`.
   - Doble candado: `chdir(abs_path("$FindBin::Bin/.."))` para garantizar ejecución en la raíz.
   - Modos: `action=trigger` (ejecución en background) y `action=status` (monitoreo en tiempo real del log).
3. **Consola Interactiva UI (`views/administracion_catalogo.pl`)**:
   - Tarjeta dinámica `cat_hot_deploy` con confirmación modal SweetAlert2 y terminal de progreso en vivo.

