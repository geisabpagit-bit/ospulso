# Diccionario de Datos Completo del Sistema OSPulso / SDM 2.0

## 1. Archivos de Identidad, Perfiles y Negocios (`dat/`)

### 1.1 `usuarios.dat`
Almacena las cuentas de usuario, credenciales y vinculación organizacional. Delimitador: `!`.

| Campo | Nombre | Tipo | Descripción |
| :--- | :--- | :--- | :--- |
| 1 | `id` | Int (PK) | Identificador único del usuario (Auto-incremental) |
| 2 | `nombre` | String | Nombre completo del usuario |
| 3 | `correo` | String | Email de acceso (Llave primaria lógica, sanitizado con `lc()` y sin espacios) |
| 4 | `clave` | String | Hash SHA-256 de la contraseña |
| 5 | `activo` | Char(1) | `1` (Activo), `0` (Inactivo/Bloqueado) |
| 6 | `rol` | String | Rol de acceso: `Administrador`, `Medico`, `Recepcionista`, `Paciente`, `Asistente` |
| 7 | `id_negocio` | String | ID de vinculación con `negocios.dat` |
| 8 | `id_espe` | Int | ID de especialidad médica (ej. `100` = Odontología, `5` = Medicina Familiar) |
| 9 | `id_subespe` | String | ID de sub-especialidad |
| 10 | `cedula` | String | Cédula profesional oficial |
| 11 | `domicilio` | String | Dirección del consultorio o establecimiento |
| 12 | `firma_url` | String | Nombre o ruta del archivo de firma digitalizada |

### 1.2 `perfiles.dat`
Almacena información complementaria y extendida del perfil de usuario. Delimitador: `!`.

| Campo | Nombre | Tipo | Descripción |
| :--- | :--- | :--- | :--- |
| 1 | `id` | Int (PK) | Identificador secuencial |
| 2 | `id_usuario` | Int (FK) | ID del usuario relacionado en `usuarios.dat` |
| 3 | `clave_formacion` | String | Clave de formación académica |
| 4 | `clave_nacionalidad` | String | Clave ISO del país de origen (ej. `MEX`) |
| 5 | `clave_religion` | String | Clave de credo o religión |
| 6 | `cedula_especialidad` | String | Número de cédula de especialidad médica |
| 7 | `avatar_url` | String | Nombre de archivo avatar en `uploads/avatars/` |
| 8 | `firma_url` | String | Nombre de archivo firma transparente en `uploads/firmas/` |
| 9 | `fecha_actualizacion` | Timestamp | Fecha y hora de última modificación (`YYYY-MM-DD HH:MM:SS`) |

### 1.3 `negocios.dat`
Catálogo de establecimientos, clínicas y sucursales del tenant. Delimitador: `|`.

| Campo | Nombre | Tipo | Descripción |
| :--- | :--- | :--- | :--- |
| 1 | `ID` | String (PK) | Identificador único de la clínica |
| 2 | `NOMBRE_NEGOCIO` | String | Nombre comercial oficial |
| 3 | `ID_MATRIZ` | Char(1) | `0` (Matriz), `1` (Sucursal) |
| 4 | `Activo` | Char(1) | Estado de suscripción: `1` (Activo), `0` (Suspendido) |
| 5 | `inicio_suscripcion` | Date | Fecha inicio de suscripción (`YYYY-MM-DD`) |
| 6 | `fin_suscripcion` | Date | Fecha vencimiento de suscripción (`YYYY-MM-DD`) |
| 14 | `codigo_postal` | String | Código postal a 5 dígitos |
| 15 | `entidad` | String | Estado o Entidad federativa |
| 16 | `municipio` | String | Municipio o Alcaldía |
| 17 | `colonia` | String | Colonia o Asentamiento |
| 18 | `CLUES` | String | Clave Única de Establecimientos de Salud |
| 19 | `extension` | String | Extensión telefónica de la clínica |
| 20 | `latitud` | Decimal | Coordenada geográfica (Latitud) |
| 21 | `longitud` | Decimal | Coordenada geográfica (Longitud) |

---

## 2. Archivos de Pacientes y Domicilios (`dat/`)

### 2.1 `pacientes.dat`
Ficha de identificación y expediente general de pacientes. Delimitador: `|`.

| Campo | Nombre | Tipo | Descripción |
| :--- | :--- | :--- | :--- |
| 1 | `ID` | String (PK) | Identificador único de paciente (`PAC...`) |
| 2 | `NOMBRE` | String | Nombre completo del paciente |
| 6 | `CORREO` | String | Email (llave de vinculación con `usuarios.dat`) |
| 7 | `FECHA_NAC` | Date | Fecha de nacimiento (`YYYY-MM-DD`) para cálculo de Edad al vuelo |

### 2.2 `pacientes_domicilio.dat`
Catálogo de domicilio estructurado de pacientes. Delimitador: `|`.

| Campo | Nombre | Tipo | Descripción |
| :--- | :--- | :--- | :--- |
| 1 | `ID_PACIENTE` | String (FK) | ID del paciente en `pacientes.dat` |
| 2 | `CP` | String | Código postal |
| 3 | `ENTIDAD` | String | Entidad federativa |
| 4 | `MUNICIPIO` | String | Municipio o Alcaldía |
| 5 | `COLONIA` | String | Colonia o localidad |
| 6 | `CALLE` | String | Nombre de la calle |
| 7 | `NUM_EXT` | String | Número exterior |
| 8 | `NUM_INT` | String | Número interior |
| 9 | `FECHA_ACTUALIZACION` | Timestamp | Timestamp de última edición |

---

## 3. Archivos de Agenda y Citas (`dat/`)

### 3.1 `citas.dat`
Registro principal de la agenda médica y estados de citas. Delimitador: `|`.

| Campo | Nombre | Tipo | Descripción |
| :--- | :--- | :--- | :--- |
| 1 | `id_cita` | String (PK) | Timestamp único de la cita |
| 2 | `id_medico` | String (FK) | ID del médico asignado en `usuarios.dat` |
| 3 | `id_paciente` | String (FK) | ID del paciente en `pacientes.dat` |
| 4 | `fecha` | Date | Fecha programada (`YYYY-MM-DD`) |
| 5 | `hora_ini` | String | Hora inicio (`HH:MM`) |
| 6 | `hora_fin` | String | Hora fin (`HH:MM`) |
| 7 | `motivo` | String | Motivo de consulta (Campo estrictamente obligatorio) |
| 8 | `notas` | String | Comentarios internos |
| 9 | `estado` | String | `Programada`, `Confirmada`, `En consulta`, `Atendida`, `Cancelada` |
| 10 | `event_id` | String | ID del evento sincronizado en Google Calendar |

### 3.2 `agenda_config.dat` (y `agenda_config_medico_X.dat`)
Configuración de jornadas, intervalos y descansos de la agenda. Formato: `llave=valor`.

| Llave | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `horario_inicio` | String | Hora inicio jornada (`HH:MM`) | `08:00` |
| `horario_fin` | String | Hora fin jornada (`HH:MM`) | `20:00` |
| `horario_comida_inicio` | String | Inicio receso comida | `14:00` |
| `horario_comida_fin` | String | Fin receso comida | `15:00` |
| `intervalo_minutos` | Int | Duración del slot de atención (min) | `30` |
| `dias_habiles` | String | Días laborables ISO (1=Lunes, 7=Dom) | `1,2,3,4,5,6` |
| `festivos` | String | Lista de fechas asueto (`YYYY-MM-DD`) | `2026-11-16,2026-12-25` |

---

## 4. Archivos de Catálogo Universal 3NF (`dat/catalogos_CLUE/<CLUES>/`)

### 4.1 `departamentos_<CLUES>.dat`
| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_DEP` | Int (PK) | Identificador de departamento | `4` |
| `NOMBRE_DEPARTAMENTO` | String | Nombre del departamento | `IMAGENOLOGIA` |

### 4.2 `categorias_<CLUES>.dat`
| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_CAT` | Int (PK) | Identificador de categoría | `16` |
| `ID_DEP` | Int (FK) | ID del departamento padre | `4` |
| `NOMBRE_CATEGORIA` | String | Nombre de la categoría | `RAYOS X` |

### 4.3 `catalogo_items_<CLUES>.dat`
| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_ITEM` | Int (PK) | Identificador del servicio | `815` |
| `CODIGO_SKU` | String | SKU canónico estandarizado | `RX-0815` |
| `ID_CAT` | Int (FK) | ID de categoría asignada | `16` |
| `CONCEPTO` | String | Descripción del servicio/estudio | `RAYOS X TORAX PA` |
| `APLICA_IVA` | Char(1) | Flag retención de IVA (1/0) | `0` |
| `INDICACIONES` | String | Indicaciones previas al paciente | `Ayuno de 8 hrs` |
| `TIEMPO_ENTREGA` | String | Tiempo de entrega de resultados | `24 HORAS` |

### 4.4 `catalogo_precios_<CLUES>.dat`
| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_PRECIO` | Int (PK) | ID del registro de precio | `3420` |
| `ID_ITEM` | Int (FK) | ID del servicio relacionado | `815` |
| `TIPO_TARIFA` | String | Clave de tarifa (`ESTANDAR`, `URGENCIAS`...) | `ESTANDAR` |
| `PRECIO_PUBLICO` | Decimal | Precio unitario al público | `450.00` |
| `COSTO_PROVEEDOR` | Decimal | Costo interno o proveedor | `150.00` |
| `ID_PROV` | String | Identificador de proveedor | `PROV-01` |

### 4.5 `tipos_tarifas_<CLUES>.dat`
| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `ID_TARIFA` | Int (PK) | ID del esquema de tarifa | `3` |
| `CLAVE` | String | Clave única en mayúsculas (`[A-Z0-9_]`) | `URGENCIAS` |
| `NOMBRE_TARIFA` | String | Nombre visible en selectores | `URGENCIAS` |
| `DESCRIPCION` | String | Descripción operativa | `Atención de Urgencias` |
| `ACTIVO` | Char(1) | Estado operativo (`1`/`0`) | `1` |

---

## 5. Archivos de Control Financiero y Recibos (`dat/`)

### 5.1 `folios_recibos_privados.dat`
Fuente canónica e inviolable de ingresos cobrados en efectivo / ventanilla. Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `FOLIO` | String (PK) | Folio privado único | `REC-001245` |
| `FECHA_HORA` | Timestamp | Timestamp exacto de emisión | `2026-09-10 13:30:00` |
| `ID_PACIENTE` | String | ID del paciente cobrado | `PAC-0941` |
| `PACIENTE_NOMBRE`| String | Nombre del paciente | `JUAN PEREZ SANCHEZ` |
| `ID_MEDICO` | String | ID del médico tratante | `MED-004` |
| `TOTAL_COBRADO` | Decimal | Monto neto cobrado en caja | `850.00` |
| `FORMA_PAGO` | String | `EFECTIVO`, `TARJETA`, `TRANSFERENCIA` | `EFECTIVO` |
| `DESGLOSE_JSON` | JSON | Estructura JSON de conceptos y tarifas | `[{...}]` |
| `USUARIO_CAJA` | String | Usuario de sesión que cobró | `recepcion1` |

### 5.2 `folios_recibos_publicos.dat`
Registro de órdenes subsidiadas bajo convenio gubernamental (CXC Estado). Delimitador: `|`.

| Campo | Tipo | Descripción | Ejemplo |
| :--- | :--- | :--- | :--- |
| `FOLIO` | String (PK) | Folio público consecutivo | `REC-PUB-000412` |
| `FECHA_HORA` | Timestamp | Timestamp de emisión | `2026-09-10 13:35:00` |
| `NUM_EMPLEADO` | String | Número de empleado municipal | `EMP-4481` |
| `PACIENTE_NOMBRE`| String | Nombre del beneficiario | `MARIA LOPEZ` |
| `TOTAL_SUBSIDIO`| Decimal | Valor abonado a CXC Estado | `1760.00` |
| `DESGLOSE_JSON` | JSON | Lista de conceptos autorizados | `[{...}]` |
