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


