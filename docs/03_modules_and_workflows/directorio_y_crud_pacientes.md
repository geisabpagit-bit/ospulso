# Directorio Clínico y CRUD de Pacientes (`views/pacientes.pl` y `views/crud_paciente.pl`)

## 1. Visión General
El módulo de **Pacientes** administra el padrón de expedientes clínicos institucionales del sistema OSPulso. Se articula a través de dos interfaces principales:
1. **Directorio Clínico** (`views/pacientes.pl`): Tabla maestra con DataTables protegida por RBAC multi-tenant para búsqueda, visualización y gestión de expedientes.
2. **Formulario Clínico de Paciente** (`views/crud_paciente.pl`): Interfaz integral para la inscripción oficial (alta) y actualización (edición) de fichas clínicas, antecedentes heredofamiliares, patológicos, no patológicos y localización oficial SEPOMEX.

---

## 2. Estandarización UI/UX (Estándar Finanzas)
El diseño visual se encuentra homologado con los componentes ejecutivos de `views/finanzas.pl`:
- **Header Corporativo Compacto** (`.diamond-header-compact`): Barra azul marino profundo (`#0A2A66` / `#051937`) con esquinas redondeadas (`border-radius: 14px`), tipografía blanca nítida, subtítulo descriptivo tenue y botones de acción en pastilla con bordes traslúcidos.
- **Tarjetas Clínicas con Borde Institucional**: Contenedores con clase utilitaria móvil `.card-mobile-flush`, esquinas `border-radius: 14px;`, fondo `#FFFFFF` y bordes institucionales verde azulado (`border: 1.5px solid var(--md-teal-clinical, #19B7A5) !important;`).
- **Tipografía y Jerarquía**: Encabezados con fuente `plus-jakarta`, color azul marino institucional y badges redondeados (`.badge.rounded-pill`).
- **Botones de Acción**: Botones con clase base `.rounded-pill`, estilo táctil accesible y soporte responsivo móvil (`css/sdm_mobile_standards.css`).

---

## 3. Flujo Inteligente de Alta e Importación de Empleados Municipales (Capacidad SaaS: `PACIENTES_ESTADO`)

### 3.1 Gobernanza de la Capacidad SaaS
El sistema verifica de forma estricta en el backend si la organización activa tiene habilitada la capacidad `PACIENTES_ESTADO`:
- Consulta `dat/negocios_config.dat` para `$id_empresa` y clave `PACIENTES_ESTADO == '1'`.
- En caso de la organización matriz (`0` o vacía) sin registro explícito previo, aplica el fallback canónico verificando si cuenta con clave `CLUES` asignada en `dat/negocios.dat`.
- Inyecta de forma segura las directivas `window.HAS_PACIENTES_ESTADO` y `window.ORG_CLUES`.

### 3.2 Modal de Decisión Inicial
Si la organización cuenta con `HAS_PACIENTES_ESTADO = 1`:
- Al pulsar **"Agregar nuevo paciente"** en `views/pacientes.pl`:
  - Se despliega un diálogo interactivo (SweetAlert2) consultando al operador:
    - **[ Captura Nueva ]**: Conduce a `views/crud_paciente.pl` en blanco para captura manual tradicional.
    - **[ Importar Municipio ]**: Abre de inmediato el modal de búsqueda asistida del padrón de empleados.
- Si `HAS_PACIENTES_ESTADO = 0`: Continúa directamente al formulario sin interrupciones.

### 3.3 Buscador Reactivo Asistido (Estándar Caja Rápida)
Tanto en `views/pacientes.pl` como en `views/crud_paciente.pl` (mediante botón superior *"Importar Empleado Municipio"*):
- **Campo de Entrada con Lupa**: Permite ingresar números de empleado o nombres/apellidos.
- **Sugerencias AJAX en Vivo**: A partir de **2 caracteres o dígitos**, dispara la búsqueda reactiva con *debounce* hacia `api/buscar_empleadosmun.pl`.
- **Resolución Automática de Dependencias**: El endpoint consulta el catálogo oficial de dependencias de la CLUES (`dependencia_<CLUES>.dat`) e incorpora el nombre formal de la dependencia en los resultados.
- **Lista de Resultados**: Despliega tarjetas interactivas indicando:
  - Nombre completo del paciente.
  - Relación / Parentesco (`Empleado` titular o `Beneficiario`).
  - No. de Empleado oficial.
  - Dependencia de adscripción.
  - Datos de contacto (teléfono y correo).
  - Botón de acción: *"Importar"*.

### 3.4 Volcado de Datos a "Información de Identidad"
Al seleccionar un empleado en el modal:
- **Nombre Completo** (`#nombreCompleto`): Nombre del empleado/beneficiario en MAYÚSCULAS normalizadas.
- **Teléfono de Contacto** (`#telefono`): Teléfono registrado en el padrón municipal.
- **Correo Electrónico** (`#correo`): Correo registrado o institucional.
- **Dependencia / Adscripción** (`#dependencia`): Nombre formal de la dependencia municipal.
- **No. Empleado Municipal** (`#num_empleado_estado`): Número de control en el estado/municipio.
- **Ocupación** (`#ocupacion`): "Servidor Público Municipal" o la relación de parentesco junto con la dependencia.
- **Badge Institucional**: Activa el indicador `#badgeOrigenEmpleado` señalando que proviene del padrón municipal para trazabilidad administrativa.
- **Intercomunicación entre Vistas**: Si la selección se ejecuta desde `pacientes.pl`, los datos viajan mediante `sessionStorage` seguro hacia `crud_paciente.pl`, volcándose automáticamente al renderizar y notificando al usuario mediante toast SweetAlert2.

---

## 4. Persistencia en Backend (`api/pacientes_crud_api.pl`)
- El endpoint recibe el payload JSON UTF-8 incluyendo `dependencia` y `num_empleado_estado`.
- Los datos de dependencia y número de empleado se almacenan de forma atómica dentro de la estructura de antecedentes del expediente (`dat/pacientes_antecedentes.dat`).
- Al consultar el perfil para edición (`api/pacientes_api.pl?accion=get_perfil`), ambos campos son recuperados y prellenados automáticamente en el formulario.

---

## 5. Hoja de Ruta: Fase Posterior (Importación Masiva de Rama Familiar)
En una fase posterior se habilitará la **importación masiva de toda la rama familiar**:
1. Al buscar por número de empleado, el modal agrupará visualmente al Titular y a todos sus Beneficiarios registrados en `empleadosmun_<CLUES>.dat`.
2. Se incorporará un botón de acción masiva: **"Importar Toda la Rama Familiar (N Miembros)"**.
3. El backend procesará en lote la creación de los N expedientes clínicos vinculando automáticamente al titular como responsable/tutor de los beneficiarios dependientes y asociando la misma dependencia de adscripción.
