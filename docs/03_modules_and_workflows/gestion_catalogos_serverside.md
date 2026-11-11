# Módulo de Gestión de Catálogo Universal 3NF y Arquitectura Server-Side

## 1. Visión General y Arquitectura
El Módulo de **Catálogo Universal** (`views/manage_catalogo_universal.pl`) implementa una arquitectura relacional normalizada (3NF) aislada por organización/tenant bajo la clave sanitaria CLUES (`dat/catalogos_CLUE/<CLUES>/`).
Permite la administración integral de Departamentos, Categorías, Servicios, Productos y Tipos de Tarifa / Condiciones.
Su acceso desde el panel administrativo de tarjetas (`views/render_catalogo_principal.pl`) opera mediante **enrutamiento polimórfico inteligente**:
- Si la organización en sesión cuenta con clave sanitaria CLUES (`$rutas->{is_universal} == 1`), la tarjeta `cat_catalogo_org` se titula **"Catálogo Universal"** y conduce a `manage_catalogo_universal.pl`.
- Si la organización es un consultorio privado estándar sin CLUES (ej. dental o nutrición), la tarjeta se titula **"Catálogo de Servicios"** y conduce al catálogo 2D `manage_servicios.pl`, preservando la compatibilidad de cotizaciones y presupuestos históricos.

---

## 2. Estructura de Archivos Físicos por Organización
Cada tenant opera con su propio conjunto de datos bajo `dat/catalogos_CLUE/<CLUES>/`:

| Archivo | Contenido | Estructura / Columnas |
| :--- | :--- | :--- |
| `departamentos_<CLUES>.dat` | Departamentos médicos y operativos | `ID_DEP\|NOMBRE_DEPARTAMENTO` |
| `categorias_<CLUES>.dat` | Categorías asignadas a un departamento | `ID_CAT\|ID_DEP\|NOMBRE_CATEGORIA` |
| `catalogo_items_<CLUES>.dat` | Servicios y procedimientos clínicos | `ID_ITEM\|CODIGO_SKU\|ID_CAT\|CONCEPTO\|APLICA_IVA\|INDICACIONES\|TIEMPO_ENTREGA` |
| `catalogo_precios_<CLUES>.dat` | Matriz de precios por servicio y tarifa | `ID_PRECIO\|ID_ITEM\|TIPO_TARIFA\|PRECIO_PUBLICO\|COSTO_PROVEEDOR\|ID_PROV` |
| `productos_<CLUES>.dat` | Insumos, medicamentos y farmacia | `ID\|NOMBRE\|PRECIO\|CANTIDAD\|PRESENTACION\|DESCRIPCION\|STOCK_MINIMO` |
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
- **Serialización Segura a JavaScript (Anti-Mojibake)**: Al inyectar variables de catálogo en el DOM (`window.CATALOGO_TIPOS_TARIFAS`, etc.) dentro de scripts Perl con `use open qw(:std :utf8)`, se utiliza `JSON::PP->new->ascii(1)->encode(...)`. Esto escapa caracteres no ASCII a formato canónico `\uXXXX`, erradicando la doble codificación UTF-8 que generaba caracteres rotos (ej. `ESTÃNDAR` en lugar de `ESTÁNDAR`) en los dropdowns de la interfaz.

---

## 6. Blindaje Antihuérfanos en Rutas CLUE (`catalogo_org_utils.pl`)
- **Problema Prevenido**: Cuando una organización privada, consultorio o sesión sin CLUE invocaba `obtener_rutas_por_clue($clues)` con `$clues` vacío o indefinido, la concatenación `File::Spec->catdir($dat, 'catalogos_CLUE', '')` resolvía a la raíz `catalogos_CLUE/`, provocando que el auto-sembrado creara el archivo erróneo `tipos_tarifas_.dat` fuera del subdirectorio correspondiente.
- **Regla de Guarda Estricta**: La función `obtener_rutas_por_clue` implementa un guard clause temprano: si `$clues` está vacío o no contiene caracteres no vacíos (`!defined $clues || $clues !~ /\S/`), devuelve un hashref seguro con rutas vacías y `is_universal => 0`, omitiendo cualquier creación en disco.
- **Creación Segura**: La condición de auto-sembrado exige que `$clues ne ''` y que el subdirectorio específico del CLUE (`-d $clue_dir`) exista físicamente antes de emitir cualquier archivo `.dat`.

---

## 7. Visibilidad Departamental de Productos en Caja Rápida (`views/generar_recibo.pl`)
- **Problema Solucionado**: Los productos físicos (`productos_<CLUES>.dat`) carecen de columnas relacionales `ID_DEP` e `ID_CAT`. Al cargarse en memoria sin departamento (`dep: ''`), cualquier filtrado departamental en el modal de conceptos los excluía de la vista.
- **Mapeo Virtual en Tiempo de Ejecución**: En `_cargarCatalogoRecibo()`, los productos se registran bajo el departamento virtual `FARMACIA` (*"Farmacia / Insumos"*) y categoría `FARMACIA_CAT` (*"Medicamentos y Materiales"*).
- **Compatibilidad e Inmutabilidad**: Esto permite que el personal de caja filtre exclusivamente los medicamentos y materiales sin alterar la estructura física ni el contenido plano de `productos_<CLUES>.dat`, conservando la total compatibilidad con cotizaciones y recibos históricos.

---

## 8. Control Transaccional de Inventario, 7ª Columna (`stock_minimo`) y Bloqueo de Venta (P4)
- **Esquema Extendido de 7 Columnas**: Todos los archivos de productos (`dat/productos.dat`, `dat/productos_<ID_ORG>.dat` y `dat/catalogos_CLUE/<CLUES>/productos_<CLUES>.dat`) operan bajo la estructura de 7 columnas:
  `id|nombre|precio|cantidad|presentacion|descripcion|stock_minimo`.
- **Aprovisionamiento Automático en Alta de Organizaciones (`utils/catalogo_org_utils.pl`)**: Al crear una nueva organización mediante `crear_catalogo_org_desde_global()`, tanto el clonado desde `dat/productos.dat` como la inicialización por defecto garantizan la presencia de la cabecera y la 7ª columna `stock_minimo` (valor por defecto `5`).
- **CRUD Multi-Tenant Unificado**:
  - **Organizaciones con CLUES**: `views/manage_catalogo_universal.pl` y `api/crud_catalogo_universal_api.pl` (`save_producto`) gestionan y visualizan la columna `stock_minimo` junto con indicadores dinámicos de existencias (Agotado, Stock Bajo, Stock Normal).
  - **Organizaciones 2D (Sin CLUES)**: `views/manage_productos.pl`, `api/crud_productos_org_api.pl` y `api/catalogo_org_api.pl` capturan, actualizan y evalúan el umbral personalizado `stock_minimo` de cada insumo.
- **Bloqueo Estricto y Descuento Atómico en Caja Rápida (`views/generar_recibo.pl` y `api/guardar_recibo_rapido.pl`)**:
  - En el modal de conceptos, los productos con `stock <= 0` se muestran con etiqueta *"Agotado (0 disp.)"* y su botón de adición queda estrictamente bloqueado (`disabled`). Asimismo, se impide agregar al carrito una cantidad mayor a las existencias disponibles.
  - Al confirmar la emisión del recibo, `api/guardar_recibo_rapido.pl` abre el archivo de productos con bloqueo exclusivo `flock(LOCK_EX)`, verifica existencias reales en disco, rechaza la transacción si el stock es insuficiente o cero, descuenta las unidades vendidas y retorna alertas preventivas (`alertas_stock`) cuando el inventario resultante es menor o igual a `stock_minimo`.


