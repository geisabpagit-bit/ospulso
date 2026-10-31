# Módulo de Gestión de Registros y Cuentas SaaS (Administrador Global)

## 1. Visión General
El módulo de **Gestión de Registros** (`views/manage_registros.pl`) constituye el centro de comando para la supervisión, ciclo de vida y gobernanza integral de los clientes del SaaS OSPulso. Permite al rol **Administrador Global** monitorear organizaciones y sucursales registradas, administrar licencias demo, extender periodos de prueba, gestionar la papelera (**Soft-Delete**) y ejecutar la purga total definitiva (**Hard-Delete**) de organizaciones completas.

---

## 2. Gobernanza de Acceso (RBAC) y Navegación
- **Ubicación en el Menú**: Submenú **"Ventas"** (`#c-ventas`) en [utils/sub_sidebar.pl](file:///c:/xampp/htdocs/ospulso/utils/sub_sidebar.pl).
- **Rol Mandante**: Exclusivo para `Administrador Global`.
- **Capa de Frontend**: El elemento solo se renderiza si `$role eq 'Administrador Global'`. En `views/manage_registros.pl`, cualquier intento de acceso por otro rol desencadena la rutina `render_acceso_denegado(...)`.
- **Layout Shell Mandante**: Renderizado canónico mediante `utils::sub_sidebar::render_sidebar(...)` y cierre estructural con `utils::sub_sidebar::render_sidebar_footer()` para garantizar el nesting correcto del DOM.
- **Capa de Backend**: El endpoint [api/admin_registros_api.pl](file:///c:/xampp/htdocs/ospulso/api/admin_registros_api.pl) valida la sesión de usuario y retorna HTTP 403 Forbidden ante cualquier rol no autorizado.

---

## 3. Row Grouping Jerárquico en DataTables
El listado implementa la técnica oficial de agrupación de filas (*Row Grouping*) de DataTables:
- **Nivel Organización Matriz**: Las filas maestras de grupo (`tr.group-org-header`) agrupan jerárquicamente a las sucursales pertenecientes a dicha matriz (`ID_MATRIZ`).
- **Estilos Corporativos**: Diseñado con degradado azul marino y verde teal institucional (`#0A2A66` a `#19B7A5`), indicando el ID de la matriz y el estado general. Si la organización está en papelera, el encabezado conmuta a un gradiente carmesí de alerta.
- **Lista de Sucursales**: Dentro de cada bloque de organización se muestran sus sucursales con sangría e ícono de derivación, ID, responsable, vigencia, estado y acciones individuales.

---

## 4. Ciclo de Vida: Soft-Delete y Hard-Delete (Auditoría de Purga)

### 4.1 Soft-Delete (Mover a la Papelera)
- **Alcance**: A nivel Organización Matriz.
- **Mecanismo**: Marca el campo `Activo = -1` en `dat/negocios.dat` tanto para la matriz como para todas sus sucursales hijas asociadas.
- **Efecto Operativo**: Suspende el acceso inmediato a todos los usuarios de la organización pero preserva íntegramente sus datos.
- **Restauración**: Permite restituir la organización a estado activo (`Activo = 1`) con un solo clic.

### 4.2 Hard-Delete Definitivo (Purga Total en Cascada)
- **Alcance**: A nivel Organización Matriz y solo accesible cuando la organización está en papelera.
- **Confirmación de Seguridad**: Exige al Administrador Global tipear explícitamente la palabra **`ELIMINAR`** en mayúsculas en el modal SweetAlert.
- **Auditoría de Elementos Purgados**:
  1. **Registros en Tablas (.dat)**:
     - `dat/negocios.dat`: Elimina las filas de la matriz y de todas sus sucursales hijas.
     - `dat/negocios_config.dat`: Elimina parámetros de configuración de dichos negocios.
     - `dat/usuarios.dat`: Elimina a todos los usuarios vinculados a las empresas y sucursales.
     - `dat/pacientes.dat`, `dat/pacientes_domicilio.dat`, `dat/pacientes_antecedentes.dat`: Elimina expedientes de pacientes asignados a esas clínicas.
     - `dat/citas.dat`: Elimina todas las citas médicas agendadas.
     - `dat/consultas_clinicas.dat`: Elimina notas y consultas médicas SOAP.
     - `dat/recetas.dat`: Elimina recetas médicas expedidas.
     - `dat/consentimientos.dat`: Elimina consentimientos informados firmados.
     - `dat/estado_cuenta.dat`: Elimina historial contable de cargos y abonos.
     - `dat/folios_recibos_privados.dat` y `dat/folios_recibos_publicos.dat`: Elimina recibos de caja emitidos.
     - `dat/gastos.dat`: Elimina gastos operativos de la clínica.
     - `dat/cotizaciones.dat`: Elimina presupuestos clínicos.
     - `dat/odontogramas.dat`: Elimina tratamientos odontológicos.
     - `dat/quirofano.dat`: Elimina cirugías programadas.
  2. **Archivos Físicos y Carpetas**:
     - `dat/productos_$id.dat` y `dat/servicios_$id.dat`: Catálogos locales.
     - `dat/catalogo_odontograma_$id.dat` y `dat/contadores_recibos_privados_$id.dat`: Configuración interna.
     - `dat/agenda_config_sucursal_$id.dat`: Horarios de sucursal.
     - `uploads/logos/logo_$id.*`: Logotipos institucionales.
     - `dat/agenda_config_medico_$u_id.dat` y `uploads/avatars/avatar_$u_id.*`: Agendas y fotos de usuarios.
     - Directorios físicos de pacientes `dat/estudiosRX/$p_id/`: Estudios radiológicos e imágenes.
  3. **Registro en Bitácora (`dat/audit_logs.dat`)**:
     - Se registra de forma inmutable la fecha, hora, usuario operador, acción `HARD_DELETE_ORGANIZACION` y conteo exhaustivo de negocios, usuarios, expedientes y archivos físicos destruidos.

---

## 5. Endpoints (`api/admin_registros_api.pl`)

| Acción (`action`) | Método | Parámetros | Descripción |
|---|:---:|---|---|
| `listar` | `GET` | N/A | Retorna el listado jerárquico con mapeo matriz-sucursales, cálculo de días y KPIs (`total`, `demos`, `activas`, `por_vencer`, `suspendidas`, `papelera`). |
| `obtener` | `GET` | `id` | Retorna los detalles de la sucursal/clínica para edición. |
| `soft_delete` | `POST` | `id_org` | Marca en papelera (`Activo = -1`) la organización matriz y sus sucursales. |
| `restaurar_org` | `POST` | `id_org` | Restaura de la papelera (`Activo = 1`) la organización matriz y sus sucursales. |
| `hard_delete` | `POST` | `id_org`, `confirmacion='ELIMINAR'` | Ejecuta la purga física y relacional definitiva sin dejar rastro alguno. |
| `actualizar_estado` | `POST` | `id`, `activo` (1/0) | Suspende o reactiva individualmente una sucursal en `negocios.dat`. |
| `extender_demo` | `POST` | `id`, `dias` (15, 30, 60) | Añade días a la vigencia del registro y reactiva la cuenta si estaba inactiva. |
| `editar` | `POST` | `id`, campos comerciales | Actualiza datos fiscales y de contacto de la clínica. |

---

## 6. Tratamiento de Codificación UTF-8
- **Backend**: Headers con `Content-Type: application/json; charset=UTF-8`, lectura y escritura en archivos con capa `:encoding(UTF-8)`, decodificación de parámetros mediante `safe_param` y salida con `binmode STDOUT, ':raw'` para prevenir mojibake y dobles codificaciones.
- **Frontend**: Renderizado con `charset=UTF-8` y funciones de escape seguras `escapeHtml` y `escapeJs`.
