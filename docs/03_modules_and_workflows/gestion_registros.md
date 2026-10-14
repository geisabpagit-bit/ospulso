# Módulo de Gestión de Registros y Cuentas SaaS (Administrador Global)

## 1. Visión General
El módulo de **Gestión de Registros** (`views/manage_registros.pl`) constituye el centro de comando para la supervisión y ciclo de vida de los clientes del SaaS OSPulso. Permite al rol **Administrador Global** monitorear clínicas registradas desde la landing page pública ([index.html](file:///c:/xampp/htdocs/ospulso/index.html)), administrar licencias demo, extender periodos de prueba y realizar altas o modificaciones administrativas.

---

## 2. Gobernanza de Acceso (RBAC)
- **Rol Mandante**: Exclusivo para `Administrador Global`.
- **Capa de Frontend**: El elemento de navegación en [utils/sub_sidebar.pl](file:///c:/xampp/htdocs/ospulso/utils/sub_sidebar.pl) (`#c-administracion`) solo se renderiza si `$role eq 'Administrador Global'`. En `views/manage_registros.pl`, cualquier intento de acceso por otro rol desencadena la rutina `render_acceso_denegado(...)`.
- **Capa de Backend**: El endpoint [api/admin_registros_api.pl](file:///c:/xampp/htdocs/ospulso/api/admin_registros_api.pl) valida la sesión de usuario y retorna HTTP 403 Forbidden ante cualquier rol no autorizado.

---

## 3. Fuentes de Datos Involucradas (Flat-Files)
- `dat/negocios.dat`: Almacena el catálogo de clínicas y consultorios (ID, nombre, estatus `Activo`, `inicio_suscripcion`, `fin_suscripcion`, datos de contacto, RFC y domicilio).
- `dat/usuarios.dat`: Relaciona a los usuarios titulares administradores asignados a cada negocio (`ID_negocio`).

---

## 4. Arquitectura de Endpoints (`api/admin_registros_api.pl`)

| Acción (`action`) | Método | Parámetros | Descripción |
|---|:---:|---|---|
| `listar` | `GET` | N/A | Retorna el arreglo de clínicas, administrador vinculado, cálculo de días restantes y resumen de KPIs (`total`, `demos`, `activas`, `por_vencer`, `suspendidas`). |
| `obtener` | `GET` | `id` | Retorna los detalles de la clínica seleccionada para edición. |
| `actualizar_estado` | `POST` | `id`, `activo` (1/0) | Suspende o reactiva el acceso de la clínica en `dat/negocios.dat` con bloqueo `flock`. |
| `extender_demo` | `POST` | `id`, `dias` (15, 30, 60) | Añade días a la vigencia del registro y reactiva la cuenta si estaba inactiva. |
| `editar` | `POST` | `id`, campos comerciales | Actualiza los datos fiscales y de contacto de la clínica. |

---

## 5. UI y Experiencia de Usuario
- **Framework Visual**: Integra [css/ospulso_master_v2.css](file:///c:/xampp/htdocs/ospulso/css/ospulso_master_v2.css) y [css/sdm_mobile_standards.css](file:///c:/xampp/htdocs/ospulso/css/sdm_mobile_standards.css).
- **Tarjetas KPI**: Resumen superior con contadores en tiempo real.
- **Filtros Rápidos**: Botones de segmentación instantánea por estado (*Todos*, *Demos*, *Pagadas*, *Por Vencer*, *Suspendidas*).
- **Acciones Rápidas**:
  - Contacto directo vía enlace WhatsApp con saludo personalizado.
  - Modales ligeros para extender días de prueba o actualizar datos sin recargar la página.
  - Confirmaciones de seguridad con `SweetAlert2`.
