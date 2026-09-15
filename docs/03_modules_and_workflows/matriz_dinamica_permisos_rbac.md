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
- Interfaz interactiva exclusiva para Administradores de Organización.
- Presenta una matriz responsiva con switches para `C`, `R`, `U`, `D` agrupados por rol.
- Permite seleccionar todos / ninguno por columna de rol.
- Envía actualizaciones AJAX a `api/gestion_permisos_roles_api.pl`.

### 3.4 API Backend (`api/gestion_permisos_roles_api.pl`)
- `get_matrix`: Retorna la lista de módulos, roles y el estado de la matriz en JSON.
- `save_matrix`: Valida los datos recibidos, aplica la salvaguarda de lockout y persiste atómicamente la matriz.
