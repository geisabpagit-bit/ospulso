# Módulo de Gestión Dinámica de Catálogos (SaaS Enterprise)

El módulo de Gestión de Catálogos (ubicado en `views/gestion_catalogos.pl` y `js/gestion_catalogos.js`) es una herramienta crítica orientada exclusivamente a los usuarios con rol `Administrador Organizacion`. Permite el mantenimiento (CRUD) sobre los archivos de datos planos (`.dat`) segregados por el identificador único de la clínica (CLUE).

## 1. Arquitectura de Seguridad (Backend)

La API encargada (`api/gestion_catalogos_api.pl`) incorpora múltiples capas defensivas:

1.  **RBAC Estricto:** Bloquea incondicionalmente cualquier petición que no provenga de un `Administrador Organizacion`.
2.  **Anti Path-Traversal:** Las cadenas de nombre de archivo (`filename`) que contengan `../` o rutas absolutas `/` son rechazadas inmediatamente.
3.  **Lista Blanca de Catálogos (SaaS Whitelist):**
    El Backend impone una restricción ineludible sobre los sufijos de los archivos permitidos:
    -   `empleadosmun_<CLUE>.dat`
    -   `medicos_<CLUE>.dat`
    -   `especialidades_<CLUE>.dat`
    -   `pacientes_privados_<CLUE>.dat`
    -   `contadores_recibos_privados_<CLUE>.dat`
    -   `contadores_recibos_publicos_<CLUE>.dat`
    Cualquier intento de modificar un catálogo fuera de esta lista blanca generará un error 403 lógico.
4.  **Flock (Bloqueo Concurrente):** Las operaciones de lectura y escritura (`save` y `delete`) utilizan bloqueos exclusivos de sistema operativo (`flock`) para evitar corrupción en entornos concurrentes.

## 2. Arquitectura Dinámica del Frontend (JS)

El módulo es 100% agnóstico a las columnas. Esto significa que la API lee la primera línea del archivo para deducir las cabeceras y, de forma dinámica, el Frontend en `js/gestion_catalogos.js` crea las columnas de la DataTables y los campos del formulario modal basándose en esa lectura.

### 2.1 Patrón de Plugins (Hooks de Catálogo)
Para evitar el "Spaghetti Code" (múltiples `if/else` repartidos por todo el código para atender casos especiales de ciertos catálogos), se diseñó la variable `CatalogHooks`.

```javascript
const CatalogHooks = {
    'medicos': {
        preload: function(filename, callback) { ... },
        onCalculateId: function(dataTable) { ... },
        onRenderField: function(headerName, index, val, readonly) { ... }
    }
};
```
Esta arquitectura permite que, si un catálogo específico requiere reglas relacionales de negocio (ej. cargar los médicos para asociar pacientes), todo ese comportamiento quede encapsulado.

### 2.2 Autoinferencia de Tipos de Dato
La UI infiere el formato ideal de captura HTML5 según el nombre de la columna generada:
-   Palabras clave como `monto`, `precio` o `contador` detonan un `<input type="number">`.
-   Palabras clave como `correo` o `email` detonan un `<input type="email">`.
Esta es la primera línea de defensa para mantener la salud financiera e integridad de datos del sistema.

## 3. UI/UX: Estándares Móviles y Riesgos

1.  **Bordes Expandidos:** La interfaz usa las clases de estandarización móvil `.container-mobile-flush` y `.card-mobile-flush` dictadas en la guía de diseño de OSPulso.
2.  **Advertencia Persistente:** Dado que este módulo permite la manipulación a nivel de base de datos (`.dat`), un banner de Bootstrap de tipo `alert-danger` advierte al administrador sobre el impacto irreversible de eliminar registros (IDs) que ya poseen historial transaccional en otros módulos, evitando así rupturas relacionales con las notas de venta o expedientes médicos.
