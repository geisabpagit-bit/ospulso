# Módulo de Gestión de Catálogo Universal 3NF

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

## 3. Catálogo Dinámico de Tipos de Tarifa (`tipos_tarifas_<CLUES>.dat`)
Con la evolución arquitectónica, las tarifas ya no son valores hardcodeados en código. Cada organización dispone de un catálogo extensible que alimenta dinámicamente:
1. **Matriz de Tarifas en Edición/Alta de Servicios** (`views/manage_catalogo_universal.pl`).
2. **Selector de Tarifa en Caja Rápida para Consultas Privadas** (`views/generar_recibo.pl`).
3. **Módulos de Cotizaciones y Estados de Cuenta** (`js/cotizaciones_spa.js`, `js/estado_cuenta_spa.js`).

### 3.1 Contenido Base Oficial (Auto-Semillado)
Al inicializarse el catálogo de una organización, se crean 12 tipos base:
- `1|ESTANDAR|ESTÁNDAR|Público General / Tarifa Base|1`
- `2|MUNICIPIO|MUNICIPIO|Convenio Sindical / Estatal|1`
- `3|URGENCIAS|URGENCIAS|Tarifa de Atención de Urgencias|1`
- `4|LUNES_A_SABADO|LUNES A SÁBADO|Tarifa Ordinaria|1`
- `5|DOMINGOS_Y_FESTIVOS|DOMINGOS Y FESTIVOS|Recargo Dominical / Festivo|1`
- `6|FESTIVO|DÍA FESTIVO|Atención en Día Festivo Oficial|1`
- `7|NORMAL|TURNO NORMAL|Horario Habitual de Consulta|1`
- `8|MATUTINO|TURNO MATUTINO|Horario Matutino|1`
- `9|NOCTURNO|TURNO NOCTURNO|Turno Nocturno|1`
- `10|SABADO_TARDE_DOMINGO_FESTIVO|SÁBADO TARDE / DOMINGO / FESTIVO|Guardia Fin de Semana y Festivo|1`
- `11|PAQUETE_TODO_INCLUIDO|PAQUETE TODO INCLUIDO|Paquete Integral Quirúrgico / Procedimiento|1`
- `12|PAQUETE_SOLO_CLINICA|PAQUETE SOLO CLÍNICA|Paquete Quirúrgico sin Honorarios Médicos|1`

### 3.2 Reglas de Integridad y Protección
1. **Protección de Sistema**: Las claves `ESTANDAR`, `MUNICIPIO` y `URGENCIAS` no pueden ser eliminadas ni alteradas en su clave interna para evitar descalces en flujos críticos (Caja Rápida, Convenios de Cabildo y Urgencias).
2. **Anti-Orfandad**: No es posible eliminar un tipo de tarifa si actualmente se encuentra asignado a uno o más servicios en `catalogo_precios_<CLUES>.dat`.
3. **Clave Única**: Las claves internas se formatean en mayúsculas sin espacios (`[A-Z0-9_]`) y son estrictamente únicas por organización.

---

## 4. Generación y Respeto de SKU (Nomenclatura y Varita Mágica)
- **Modo Alta**: Al seleccionar Departamento y Categoría, el frontend calcula el prefijo correspondiente (ej. `CON-MG-`) y busca el número consecutivo más alto existente en `window.CATALOGO_ITEMS` para proponer el siguiente número formateado con ceros a la izquierda (ej. `CON-MG-0001`).
- **Modo Edición**: El SKU asignado originalmente se preserva de manera intacta, evitando alterar históricos o códigos de barras ya impresos.
- **Varita Mágica (`<button><i class="bi bi-magic"></i></button>`)**:
  - Si el campo SKU ya contiene un prefijo o texto, la varita mágica respeta la familia y calcula/confirma el número consecutivo más alto correspondiente.
  - Muestra un toast de confirmación visual en pantalla.

---

## 5. Protocolo de Persistencia UTF-8 y Pure LF
- Todos los archivos `.dat` se leen y escriben con capas explícitas `:raw :encoding(UTF-8)`.
- Bloqueo exclusivo con `flock($fh, LOCK_EX)` durante operaciones de guardado.
- Formato de fin de línea estricto: **Pure LF (`\n`, 0 CRLF)**.
