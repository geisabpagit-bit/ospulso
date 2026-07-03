# 🏢 Documentación de Datos: negocios.dat
**Versión**: Diamond Edition v3.9.0 (Subscription Engine)

## Estructura del Archivo
- **Delimitador**: `|` (Pipe)
- **Columnas Críticas**:
  1. `ID`: Identificador único del negocio.
  2. `NOMBRE_NEGOCIO`: Nombre comercial.
  3. `ID_MATRIZ`: `0` (Matriz), `1` (Sucursal).
  4. `Activo`: `1` (Activo), `0` (Inactivo/Suspendido).
  5. `inicio_suscripcion`: Fecha de inicio (AAAA-MM-DD).
  6. `fin_suscripcion`: Fecha de vencimiento (AAAA-MM-DD).
  7. ... (Datos de contacto y fiscales).
  14. `codigo_postal`: C.P. a 5 dígitos.
  15. `entidad`: Nombre oficial de la entidad federativa.
  16. `municipio`: Nombre oficial del municipio o alcaldía.
  17. `colonia`: Nombre del asentamiento o localidad.
  18. `CLUES`: Clave Única de Establecimientos de Salud.
  19. `extension`: Extensión telefónica de la clínica. (Valor '0' si no aplica).
  20. `latitud`: Coordenada geográfica (Latitud).
  21. `longitud`: Coordenada geográfica (Longitud).

## Reglas de Negocio "Blindaje Diamante"
- **Auto-Desactivación**: Si `Fecha Actual > fin_suscripcion`, el motor de base de datos (`db_manager.pm`) debe setear automáticamente la columna `Activo` en `0`.
- **Jerarquía**: El Badge de la UI debe reflejar `ID_MATRIZ`. Las sucursales pueden heredar reglas de la matriz pero mantienen su estado de suscripción independiente.
- **Validación en Tiempo Real**: El archivo `check_session.pl` consulta este registro en cada petición para asegurar que el negocio no haya sido suspendido mientras el usuario está logueado. En caso de reestructuración de la base de datos, validar que la extracción por posición `[2]` siga coincidiendo con la longitud esperada.

### 🏗️ Arquitectura de Renderizado (Actualización Diamond Edition)
- **Interfaz Visual**: Se abandona el diseño en bloques verticales. Los datos y estadísticas operativas de las clínicas se renderizan ahora a través de Dashboards con estructura Bento Grid y componentes UI responsivos (Zoom 80% de compactación visual).
- **Exportación DataTables**: Cualquier listado de clínicas exportado debe ajustarse al `export-toolbar` Glassmorphism y la exclusión de columnas de acción.
