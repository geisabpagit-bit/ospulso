# Módulo de Gestión de Catálogo Universal 3NF y Arquitectura Server-Side

## 1. Visión General y Arquitectura
El Módulo de **Catálogo Universal** (`views/manage_catalogo_universal.pl`) implementa una arquitectura relacional normalizada (3NF) aislada por organización/tenant bajo la clave sanitaria CLUES (`dat/catalogos_CLUE/<CLUES>/`).
Permite la administración integral de Departamentos, Categorías, Servicios, Productos y Tipos de Tarifa / Condiciones.

---

## 2. Estructura de Archivos Físicos por Organización
Cada tenant opera con su propio conjunto de datos bajo `dat/catalogos_CLUE/<CLUES>/`:

| Archivo | Contenido | Estructura / Columnas |
| :--- | :--- | :--- |
| `departamentos_<CLUES>.dat` | Departamentos médicos y operativos | `ID_DEP\|NOMBRE_DEPARTAMENTO` |
| `categorias_<CLUES>.dat` | Categorías asignadas a un departamento | `ID_CAT\|ID_DEP\|NOMBRE_CATEGORIA` |
| `catalogo_items_<CLUES>.dat` | Servicios y procedimientos clínicos | `ID_ITEM\|CODIGO_SKU\|ID_CAT\|CONCEPTO\|APLICA_IVA\|INDICACIONES\|TIEMPO_ENTREGA` |
| `catalogo_precios_<CLUES>.dat` | Matriz de precios por servicio y tarifa | `ID_PRECIO\|ID_ITEM\|TIPO_TARIFA\|PRECIO_PUBLICO\|COSTO_PROVEEDOR\|ID_PROV` |
| `productos_<CLUES>.dat` | Insumos, medicamentos y farmacia | `ID\|NOMBRE\|PRECIO\|CANTIDAD\|PRESENTACION\|DESCRIPCION` |
| `tipos_tarifas_<CLUES>.dat` | Catálogo de tipos de tarifa / condiciones | `ID_TARIFA\|CLAVE\|NOMBRE_TARIFA\|DESCRIPCION\|ACTIVO` |

---

## 3. Arquitectura DataTables Server-Side AJAX y `deferRender: true`

Para optimizar el rendimiento y la memoria en el navegador frente a catálogos extensos (más de 800 servicios):

1. **Backend Server-Side (`api/crud_catalogo_universal_api.pl`)**:
   - Incorpora la acción `datatable_servicios` que recibe `draw`, `start`, `length`, `filtro_dep`, `filtro_cat` y `filtro_texto`.
   - Efectúa el filtrado, ordenamiento y paginación en el servidor Perl devolviendo exclusivamente los registros del segmento solicitado formateados en JSON.
2. **Frontend con Renderizado Diferido (`views/manage_catalogo_universal.pl`)**:
   - Configura DataTables con `serverSide: true`, `deferRender: true` y `processing: true`.
   - Se eliminó la inyección masiva de filas `<tr>` en el HTML inicial, reduciendo el tiempo de carga del DOM a **0 ms**.
3. **Paginación Estándar de 10 Registros por Página**:
   - Ajuste global a `pageLength: 10` en `views/manage_catalogo_universal.pl` y en `js/gestion_catalogos.js`.
4. **Lista Blanca de Permisos de Edición (`api/gestion_catalogos_api.pl`)**:
   - Inclusión explícita de todos los archivos del catálogo CLUE (`catalogo_items_...`, `catalogo_precios_...`, `categorias_...`, `departamentos_...`, `productos_...`, `proveedores_...`, `tipos_tarifas_...`).

---

## 4. Reestructuración y Normalización de Catálogos por CLUE (Caso QTSMP000116)

### 4.1 Jerarquía Departamento vs Categoría
- **`departamentos_QTSMP000116.dat`**: `ID_DEP 4` corregido a **`IMAGENOLOGIA`** (Departamento General).
- **`categorias_QTSMP000116.dat`**: `ID_CAT 16|4` corregido a **`RAYOS X`** (Categoría perteneciente a Imagenología).

### 4.2 Reasignación de Inconsistencias SKU vs Categoría (31 Registros)
- **`LAB-0789` a `LAB-0795`**: Reasignados de Cat 16 (Rayos X) a `ID_CAT 15` (**Análisis Clínicos / Laboratorio**).
- **`US-0796` a `US-0814`**: Reasignados de Cat 17 (Hematología) a `ID_CAT 28` (**Ecografía / Ultrasonido**).
- **`RX-0815` a `RX-0818`**: Reasignados de Cat 15 (Análisis Clínicos) a `ID_CAT 16` (**Rayos X**).
- **`CONS-0760`**: Reasignado de Cat 39 (huérfano) a `ID_CAT 61` (**Hematología**).

### 4.3 Secuencia Canónica de SKUs en Consultas Médicas
- Reordenamiento de códigos en `catalogo_items_QTSMP000116.dat`:
  - `ID_ITEM 830`: `CONC-01` ➔ **`CONS-0830`** (Consulta Cardiología Valoración P.O.).
  - `ID_ITEM 831`: `CONH-01` ➔ **`CONS-0831`** (Consulta Hematología).
  - `ID_ITEM 832`: `CONS-0830` ➔ **`CONS-0832`** (Consulta Medicina Interna / Geriatría).
- El 100% del catálogo de consultas médicas mantiene la secuencia estandarizada `CONS-0001` a `CONS-0832`.

---

## 5. Protocolo de Persistencia y Seguridad UTF-8
- Modificaciones a catálogos se realizan bajo codificación `:raw :encoding(UTF-8)`.
- Bloqueo concurrente mediante `flock($fh, LOCK_EX)`.
- Formato de fin de línea estricto: **Pure LF (`\n`, 0 CRLF)**.
