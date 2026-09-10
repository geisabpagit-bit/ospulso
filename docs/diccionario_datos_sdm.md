# Diccionario de Datos del Sistema OSPulso / SDM

## 1. Archivos de Catálogo Universal 3NF (`dat/catalogos_CLUE/<CLUES>/`)

### 1.1 `departamentos_<CLUES>.dat`
Almacena los departamentos médicos y administrativos por tenant. Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_DEP` | Int (PK) | Identificador único del departamento | `4` |
| `NOMBRE_DEPARTAMENTO` | String | Nombre oficial del departamento | `IMAGENOLOGIA` |

### 1.2 `categorias_<CLUES>.dat`
Almacena las categorías pertenecientes a un departamento. Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_CAT` | Int (PK) | Identificador único de la categoría | `16` |
| `ID_DEP` | Int (FK) | ID del departamento padre | `4` |
| `NOMBRE_CATEGORIA` | String | Nombre oficial de la categoría | `RAYOS X` |

### 1.3 `catalogo_items_<CLUES>.dat`
Almacena los servicios, procedimientos y estudios clínicos. Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_ITEM` | Int (PK) | Identificador único del servicio | `815` |
| `CODIGO_SKU` | String | Código SKU único estandarizado | `RX-0815` |
| `ID_CAT` | Int (FK) | ID de la categoría asignada | `16` |
| `CONCEPTO` | String | Descripción del estudio/servicio | `RAYOS X TORAX PA` |
| `APLICA_IVA` | Char(1) | Flag si aplica retención/impuesto (1/0) | `0` |
| `INDICACIONES` | String | Instrucciones previas para el paciente | `Ayuno de 8 horas` |
| `TIEMPO_ENTREGA` | String | Tiempo estimado de entrega de resultados | `24 HORAS` |

### 1.4 `catalogo_precios_<CLUES>.dat`
Matriz relacional de precios por servicio y tipo de tarifa. Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_PRECIO` | Int (PK) | Identificador del registro de tarifa | `3420` |
| `ID_ITEM` | Int (FK) | ID del servicio relacionado | `815` |
| `TIPO_TARIFA` | String | Clave de la tarifa (`ESTANDAR`, `URGENCIAS`, etc.) | `ESTANDAR` |
| `PRECIO_PUBLICO` | Decimal | Precio unitario al público/paciente | `450.00` |
| `COSTO_PROVEEDOR` | Decimal | Costo interno o proveedor | `150.00` |
| `ID_PROV` | String | Identificador del proveedor asignado | `PROV-01` |

### 1.5 `tipos_tarifas_<CLUES>.dat`
Catálogo extensible de esquemas tarifarios por tenant. Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_TARIFA` | Int (PK) | Identificador del esquema tarifario | `3` |
| `CLAVE` | String | Clave única en mayúsculas (`[A-Z0-9_]`) | `URGENCIAS` |
| `NOMBRE_TARIFA` | String | Nombre visible en selectores e interfaz | `URGENCIAS` |
| `DESCRIPCION` | String | Explicación operativa de la tarifa | `Atención fuera de horario` |
| `ACTIVO` | Char(1) | Estado operativo de la tarifa (1/0) | `1` |

---

## 2. Archivos de Control Financiero y Recibos (`dat/`)

### 2.1 `folios_recibos_privados.dat`
Fuente canónica de ingresos cobrados en efectivo / ventanilla. Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `FOLIO` | String (PK) | Folio único consecutivo | `REC-001245` |
| `FECHA_HORA` | Timestamp | Fecha y hora exacta del cobro | `2026-09-10 13:30:00` |
| `ID_PACIENTE` | String | ID del paciente cobrado | `PAC-0941` |
| `PACIENTE_NOMBRE`| String | Nombre completo del paciente | `JUAN PEREZ SANCHEZ` |
| `ID_MEDICO` | String | ID del médico tratante | `MED-004` |
| `TOTAL_COBRADO` | Decimal | Monto neto recaudado en caja | `850.00` |
| `FORMA_PAGO` | String | Efectivo, Tarjeta, Transferencia | `EFECTIVO` |
| `DESGLOSE_JSON` | JSON | Estructura JSON con conceptos y tarifas | `[{...}]` |
| `USUARIO_CAJA` | String | Usuario de sesión que realizó el cobro | `recepcion1` |

### 2.2 `folios_recibos_publicos.dat`
Registro de recibos/órdenes médicas subsidiadas por convenio (CXC Estado). Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `FOLIO` | String (PK) | Folio público consecutivo | `REC-PUB-000412` |
| `FECHA_HORA` | Timestamp | Fecha y hora de emisión | `2026-09-10 13:35:00` |
| `NUM_EMPLEADO` | String | Número de empleado/beneficiario municipal | `EMP-4481` |
| `PACIENTE_NOMBRE`| String | Nombre del beneficiario | `MARIA LOPEZ` |
| `TOTAL_SUBSIDIO`| Decimal | Valor total abonado a CXC Estado | `1760.00` |
| `DESGLOSE_JSON` | JSON | Lista de conceptos autorizados | `[{...}]` |
