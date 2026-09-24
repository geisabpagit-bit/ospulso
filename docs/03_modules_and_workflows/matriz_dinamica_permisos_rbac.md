# Matriz Dinámica de Permisos por Rol (RBAC Multi-Tenant)

## 1. Visión General
La **Matriz Dinámica de Permisos por Rol** es el subsistema de gobernanza de seguridad en OSPulso / SDM que permite al **Administrador de Organización** asignar y configurar dinámicamente las facultades CRUD (`Crear`, `Leer`, `Actualizar`, `Borrar`) por cada rol y módulo del sistema.

---

## 2. Arquitectura de Datos y Resolución Multi-Tenant

### 2.1 Aislamiento de Archivos de Permisos
El sistema soporta indistintamente organizaciones gubernamentales / CLUE y clínicas privadas independientes:

- **Organizaciones con CLUE**: Se persisten en `dat/catalogos_CLUE/<CLUE>/permisos_roles_<CLUE>.dat`.
- **Organizaciones Privadas No-CLUE**: Se persisten por el ID Raíz de la empresa en `dat/permisos_roles_<id_raiz>.dat`.

### 2.2 Fallback Automático Transparente
Si una organización no ha personalizado su matriz de permisos:
1. `utils/permisos_utils.pl` detecta la ausencia del archivo de la organización.
2. Carga automáticamente las reglas por defecto definidas en `dat/roles.dat`.
3. Esto garantiza que las clínicas nuevas operen de inmediato sin interrupciones ni requerir configuración inicial obligatoria.

### 2.3 Protección contra Bloqueo Accidental (Lockout Protection)
En código backend (`utils/permisos_utils.pl` y `api/gestion_permisos_roles_api.pl`), se fuerza una regla inviolable:
- Los roles `Administrador Organizacion` y `Administrador Global` **siempre conservan permisos completos (`CRUD`)** en los módulos críticos de *Usuarios* (`usuarios`) y *Gestión de Permisos* (`gestion_permisos`), impidiendo que un administrador bloquee accidentalmente su propia cuenta.

---

## 3. Componentes del Subsistema

### 3.1 Kernel de Autorización (`utils/permisos_utils.pl`)
- `obtener_ruta_permisos_org($id_empresa)`: Resuelve la ruta `.dat` adecuada según el tenant.
- `obtener_matriz_permisos_org($id_empresa)`: Carga el hash estructurado con fallback.
- `guardar_matriz_permisos_org($id_empresa, $matriz)`: Guarda en disco aplicando Lockout Protection.
- `tiene_permiso_modulo($id_empresa, $role, $modulo, $accion)`: Evalúa facultades (`C`, `R`, `U`, `D`).

### 3.2 Renderizado Dinámico del Menú Lateral (`utils/sub_sidebar.pl`)
- El menú lateral izquierdo invoca `tiene_permiso_modulo($id_empresa, $role, $mod, 'R')` para cada sección.
- Si el usuario posee facultad de lectura (`R`), la opción se renderiza en pantalla; si no, permanece oculta.

### 3.3 Consola de Administración UI (`views/gestion_permisos_roles.pl`)
- Interfaz interactiva de **alta densidad (Compact Premium UI)** exclusiva para Administradores de Organización.
- **Roles Canónicos Dinámicos**: Carga automática de todos los roles de `dat/roles.dat` (incluyendo *Recepcionista*, *Médico*, *Enfermería*, *Ejecutivo Ventas*, *Soporte*), asegurando visibilidad independientemente de la existencia de usuarios previamente creados.
- **Drilldown Rol vs Usuarios**: Badges táctiles en cabeceras de columnas que exhiben el conteo de usuarios activos por rol en la organización y despliegan un modal interactivo con el desglose de personal.
- **Buscador de Módulos & Acciones Masivas**: Input de filtrado instantáneo por nombre/id de módulo y toggles masivos por fila (*Fila All/Off*) y por columna (*Todos/Ninguno*).
- Badges colorimétricos intuitivos para facultades CRUD:
  - `C`: Crear / Registrar (Verde)
  - `R`: Leer / Ver en Menú (Azul)
  - `U`: Actualizar / Editar (Naranja)
  - `D`: Borrar / Anular (Rojo)
- Envía actualizaciones AJAX a `api/gestion_permisos_roles_api.pl`.

### 3.4 API Backend (`api/gestion_permisos_roles_api.pl`)
- `get_matrix`: Parsea dinámicamente `dat/roles.dat` y `dat/usuarios.dat`, retornando la lista de módulos, roles canónicos, matriz CRUD, `conteo_usuarios` y `usuarios_por_rol` en JSON.
- `save_matrix`: Valida los datos recibidos, aplica la salvaguarda de lockout y persiste atómicamente la matriz.

---

### 3.5 Consola de Gestión de Personal (`views/administracion_usuarios.pl`)
- **Consumo Dinámico de Roles**: El selector `<select id="form_rol">` consume dinámicamente todos los roles canónicos de `dat/roles.dat` (*Administrador Organización*, *Médico*, *Recepcionista*, *Enfermería*, *Ejecutivo Ventas*, *Soporte*).
- **Badges Visuales Colorimétricos**: Cada colaborador en DataTables exhibe un badge estilizado y codificado por color según su rol.
- **Botón Táctico [🛡️ Permisos]**: Permite abrir el modal `#modalPermisosUsuario` en la fila de cualquier colaborador para consultar en tiempo real las facultades CRUD activas del rol de ese usuario.
- **Puerta de Enlace a la Matriz (`?rol=XXXX`)**: El modal de permisos incluye el botón *"Personalizar Facultades de este Rol en la Matriz"*, el cual redirige a `gestion_permisos_roles.pl?rol=NombreRol` auto-enfocando la vista del rol seleccionado.

---

## 4. Flujo Integrado Bidireccional Rol vs Usuarios

```
[Roles Canónicos] ──> [Matriz RBAC por Rol] <──────> [Gestión de Personal / Usuarios]
 (dat/roles.dat)   (gestion_permisos_roles.pl)       (administracion_usuarios.pl)
```

1. **Gestión de Menú y Poderes**: El Administrador de Organización ajusta las facultades `C`, `R`, `U`, `D` por rol en la matriz.
2. **Asignación a Usuarios**: En la Gestión de Personal, al crear o editar colaboradores, se seleccionan los mismos roles canónicos.
3. **Consulta Instantánea de Permisos**: Al hacer clic en `[🛡️ Permisos]` en la fila de un usuario, se inspeccionan sus módulos y facultades activas.
4. **Navegación Enfocada Bidireccional**:
   - Desde la Matriz: Clic en *"X usu."* -> Abre modal de personal -> Enlace a edición de usuario.
   - Desde Usuarios: Clic en *"Permisos"* -> Clic en *"Personalizar Facultades"* -> Abre Matriz enfocada en `?rol=NombreRol`.

---

## 5. Diagnóstico de Impacto y Matriz de Bugs en Procesos CRUD Globales

### 5.1 Calificación del Diagnóstico de Cambio: MODERADO / TRANSPARENTE
- **Operación General (Transparente)**: Para las clínicas y empresas operativas, la integración de la Matriz RBAC es **100% transparente**. El mecanismo de *Fallback Automático* en `utils/permisos_utils.pl` garantiza que si no se ha guardado un archivo personalizado `permisos_roles_*.dat`, el sistema hereda intactas las reglas predeterminadas de `dat/roles.dat` sin interrumpir la operación ni provocar pantallas de error.
- **Arquitectura Backend & APIs (Moderado)**: El acoplamiento entre la UI (menú lateral responsivo) y el Kernel RBAC es total para la facultad de lectura (`R`). No obstante, a nivel de backend existían endpoints legacy (`api/*.pl`) que realizaban validaciones estáticas `if ($role ne 'Administrador Organizacion')` en lugar de consultar la función canónica `tiene_permiso_modulo($id_empresa, $role, $mod, $accion)`.

### 5.2 Matriz de Diagnóstico de Bugs e Inconsistencias

| ID Bug | Módulo / Archivo Afectado | Descripción de la Inconsistencia | Nivel de Severidad | Diagnóstico de Cambio | Solución Técnica Aplicada / Recomendada |
|---|---|---|---|---|---|
| **BUG-01** | `api/crud_servicios_org_api.pl`, `api/crud_productos_org_api.pl` | Los endpoints de creación/edición/borrado de servicios y productos verificaban `$role ne 'Administrador Organizacion'`, bloqueando roles autorizados en la matriz o ignorando restricciones de borrado (`D`). | **Alta** | **Moderado** | Reemplazar validación estática por `tiene_permiso_modulo($id_empresa, $role, 'servicios', 'C'/'U'/'D')`. |
| **BUG-02** | `api/alta_usuario_api.pl`, `api/editar_usuario_api.pl` | Las APIs de gestión de personal rechazaban roles canónicos válidos como *Enfermería*, *Ejecutivo Ventas* o *Soporte* al tener una validación estática `if ($rol ne 'Medico' && $rol ne 'Recepcionista')`. | **Alta** | **Moderado** | Reemplazar la lista rígida por la comprobación de existencia del rol en el catálogo dinámico `dat/roles.dat`. |
| **BUG-03** | `views/manage_servicios.pl`, `views/manage_productos.pl` | Los encabezados de las vistas de servicios y productos verificaban únicamente el rol estático de administrador, impidiendo el acceso a roles que la matriz habilitó para lectura. | **Media** | **Moderado** | Modificar la guarda del encabezado para evaluar `tiene_permiso_modulo($id_empresa, $role, 'servicios', 'R')`. |
| **BUG-04** | `api/pacientes_crud_api.pl` | Las operaciones de modificación y eliminación de expediente verificaban regex de roles antiguos (`/Recepcionista|Asistente/i`) sin sincronizar con facultades de borrado (`D`) del rol actual. | **Media** | **Moderado** | Integrar `tiene_permiso_modulo($id_empresa, $role, 'pacientes', 'U'/'D')` antes de alterar expedientes. |
| **BUG-05** | `views/administracion_usuarios.pl` | En navegadores móviles o resoluciones estrechas, la tabla de usuarios presentaba desbordamiento horizontal sin selector táctil enfocado por rol. | **Baja** | **Transparente** | Integrar filtrado por rol y utilidades de la guía de estándares móviles `sdm_mobile_standards.css`. |

---

## 6. Plan de Alineación & Blindaje Backend/Vistas

1. **Blindaje de APIs Backend (Fase 1)**: Actualizar endpoints en `api/` para sustituir comparaciones rígidas por evaluaciones dinámicas con `tiene_permiso_modulo()`.
2. **Sincronización de Roles Canónicos en Alta de Personal (Fase 2)**: Permitir la creación de cualquier usuario cuyo rol exista en `dat/roles.dat`.
3. **Acceso Consistente a Vistas (Fase 3)**: Proteger las vistas de administración validando la facultad `R` (Read) contra la matriz multi-tenant.
4. **Validación Automática y Control de Versiones (Fase 4)**: Ejecutar pruebas de sintaxis `perl -c`, sincronizar git mediante commit & push automático e informar el Plan de Verificación al usuario.

---

## 7. Arquitectura de Excepciones y Permisos Especiales por Usuario (User Overrides)

### 7.1 Modelo Híbrido Granular (RBAC + Excepciones Individuales)
El sistema evoluciona de un modelo **RBAC Puro** a una arquitectura **Híbrida con Excepciones Individuales**. Este mecanismo permite otorgar o revocar facultades específicas (`C`, `R`, `U`, `D`) a un colaborador en particular (ej. conceder permiso al módulo `servicios` únicamente a un usuario con el rol de *Recepcionista*), sin modificar las reglas generales de su rol ni crear roles duplicados.

```
+-------------------------------------------------------------------------+
|                  Cadena de Evaluación de Permisos                       |
+-------------------------------------------------------------------------+
|  1. ¿Es Administrador Global o Lockout Protection?                      |
|     └─> Sí: Concede Acceso Total (1)                                    |
|                                                                         |
|  2. ¿El ID_USUARIO tiene Excepción Grabada en permisos_usuarios_*.dat?  |
|     └─> Sí: Retorna Permiso Explicito del Usuario (C, R, U, D)          |
|                                                                         |
|  3. Fallback a Matriz por Rol (permisos_roles_*.dat o dat/roles.dat)     |
|     └─> Retorna Permiso del Rol (C, R, U, D)                            |
+-------------------------------------------------------------------------+
```

### 7.2 Persistencia de Excepciones por Organización
* **Archivo de Persistencia:** `dat/permisos_usuarios_[ID_EMPRESA].dat` (o en su catálogo CLUE correspondiente).
* **Formato Canónico:**
  `ID_USUARIO|MODULO|CAN_CREATE|CAN_READ|CAN_UPDATE|CAN_DELETE`

### 7.3 Firma del Kernel y APIs
* **Kernel (`utils/permisos_utils.pl`):**
  - `tiene_permiso_modulo($id_empresa, $role, $modulo, $accion, $id_usuario)`
  - `obtener_overrides_usuario_org($id_empresa, $id_usuario)`
  - `guardar_overrides_usuario_org($id_empresa, $id_usuario, $overrides_hashref)`
  - `eliminar_overrides_usuario_org($id_empresa, $id_usuario)`
* **API AJAX (`api/gestion_permisos_usuario_api.pl`):**
  - `action=get`: Obtiene la combinación de matriz de rol + excepciones activas del usuario.
  - `action=save`: Persiste las casillas sobreescritas para el colaborador.
  - `action=reset`: Elimina todas las excepciones y restablece al rol.

### 7.4 Reglas de Gobernanza en Cambio de Rol
Cuando el Administrador edita a un colaborador en `views/administracion_usuarios.pl` (`api/editar_usuario_api.pl`) y modifica su **Rol Operativo**, el sistema **elimina automáticamente las excepciones individuales previas** (`eliminar_overrides_usuario_org`), garantizando que el usuario asuma de forma limpia la matriz de su nuevo rol sin arrastrar privilegios u omisiones obsoletas.

---

## 8. Arquitectura de Conmutador de Perfil (Role Switcher Multirrol)

### 8.1 Propósito y Casos de Uso
Diseñado para consultorios unipersonales (ej. Consultorio Dental) donde un único usuario ejerce simultáneamente dos funciones esenciales:
- **Director / Administrador de Organización**: Control de finanzas, cortes de caja, gestión de personal y catálogos.
- **Médico Tratante / Especialista**: Agenda médica, expediente clínico SOAP, odontograma y emisión de recetas.

### 8.2 Principio de Rol Activo Puro
Para no comprometer la pureza de las matrices RBAC ni crear roles híbridos artificiales (como `Medico-Admin` que desestabilizarían las reglas):
- En cualquier instante dado, la sesión tiene un único **Rol Activo** (`$session->param('role')`).
- Los módulos, barras laterales ([utils/sub_sidebar.pl](file:///c:/xampp/htdocs/ospulso/utils/sub_sidebar.pl)) y endpoints de validación evalúan estrictamente el rol activo.
- Los roles permitidos para conmutar residen en `$session->param('roles_disponibles')` (ej. `Administrador Organizacion,Medico`).

### 8.3 Endpoint de Conmutación Atómica (`api/switch_role_api.pl`)
- **Parámetro:** `nuevo_rol` (`Medico` o `Administrador Organizacion`). Resuelve tanto desde el cuerpo del POST (`FormData` vía `$q->param`) como desde la query string (`$q->url_param`), garantizando compatibilidad total con CGI.pm.
- **Validación:** Verifica que `nuevo_rol` pertenezca a la lista de roles autorizados del usuario (extraída de sesión o [dat/usuarios.dat](file:///c:/xampp/htdocs/ospulso/dat/usuarios.dat)).
- **Transacción:** Actualiza `$session->param('role', $nuevo_rol)` y ejecuta `$session->flush()`.
- **Tiempo de Respuesta:** < 300 ms, recargando la interfaz sin requerir relogueo ni teclear credenciales.

### 8.4 UI Conmutador en Encabezado (`utils/sub_header.pl`)
- Si el usuario tiene un solo rol (Cliente 1 / Policlínica con CLUE), el conmutador permanece **100% oculto e invisible**.
- Si el usuario tiene multirrol activo, se renderiza un botón interactivo con micro-animación en la barra superior (`.btn-role-pill`) y una opción directa en el menú offcanvas (`#sdmSidebar`).


