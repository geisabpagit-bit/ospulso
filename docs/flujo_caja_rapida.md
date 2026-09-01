# Flujo de "Generar Recibo" - Caja Rápida

Este documento describe el flujo completo (CRUD) para la generación de Recibos de Caja Rápidos en OSPulso. Este módulo permite cobrar conceptos médicos directamente sin pasar por una consulta previa.

## 1. Arquitectura y Segmentación de Pacientes

El flujo comienza en el API `api/guardar_recibo_rapido.pl`. Se divide la lógica de almacenamiento en dos vertientes según el origen del paciente (Público vs Privado).

### Detección de Origen
La variable `$id_paciente` dicta el comportamiento del motor:
- **Pacientes Públicos (Estado / Municipio)**: Su ID contiene el prefijo `EMP-` (Ej. `EMP-6113`).
- **Pacientes Privados (Particulares)**: Su ID contiene el prefijo `PRIV-` o es un paciente registrado convencionalmente.
- **Creación dinámica (Walk-in)**: Si el ID coincide con el nombre en texto plano (el usuario escribió un nombre que no existía), el API crea al vuelo un ID temporal `PRIV-<timestamp>` y guarda el registro en la base de pacientes privados local (Ej. `pacientes_privados__QTSMP000116.dat`).

## 2. Inyección de Organización (CLUEs)

Para mantener el control multi-tenant y la compatibilidad con catálogos institucionales, el API extrae el **CLUEs** a partir del `$id_neg` de la sesión:
1. Lee `dat/negocios.dat`.
2. Busca la fila que coincida con `$id_neg`.
3. Extrae la columna 18 (Ej. `QTSMP000116`).
4. Este CLUEs es utilizado para apuntar a catálogos dinámicos si se requiere guardar o relacionar información de médicos (Ej. `medicos_QTSMP000116.dat`).

## 3. Generación del Folio (Atomicidad)

La generación del folio es **transaccional y atómica**:
- Se evalúa si es un paciente público (`is_estado`).
- Se elige el archivo contador: `contadores_recibos_publicos.dat` vs `contadores_recibos_privados.dat`.
- Se bloquea (FLOCK) y se incrementa el contador del negocio/sucursal correspondiente.
- El folio resultante (Ej. `1-0-006706`) es formateado a 6 dígitos numéricos (Ej. `6706`).

## 4. Persistencia CRUD

Una vez obtenido el Folio Impreso, el motor realiza las siguientes transacciones (C de CRUD):
1. **Archivo Maestro de Folios (`folios_recibos_*.dat`)**:
   - Se inyecta una fila completa que almacena los metadatos del recibo:
   `ID_RECIBO_FOLIO | FOLIO | ID_NEG | ID_SUC | FOLIO | ID_PACIENTE | FECHA | HORA | CARGOS | ABONOS | METODO_PAGO | ELABORADO_POR | CONCEPTO | JSON | ESTATUS | ID_MEDICO`
2. **Kárdex Financiero (`estado_cuenta.dat`)**:
   - **Registro de Cargos (Cuentas por Cobrar)**: Se genera un movimiento de tipo `Cargo` por cada ítem en el JSON de la caja.
   - **Registro de Abonos (Cobros)**: Se genera un movimiento paralelo de tipo `Abono` representando el pago en el método seleccionado (Efectivo, Tarjeta, etc.).

> [!IMPORTANT]
> El ID del movimiento (`ID_OS`) registrado en el Kárdex Financiero será exactamente el mismo Folio del recibo (Ej. `6706`). Esto permite una **vinculación estricta** para renderizar la tabla de movimientos cruzados.

## 5. Formulario de Caja Rápida (`views/generar_recibo.pl`)

### Ordenamiento Estándar de Campos
1. **Paciente Privado** (`#selPaciente`)
2. **Número Empleado (Estado)** (`#iptNumEmpleado`)
3. **Concepto del Recibo** (`#selConceptoRecibo`) -> *Ubicado inmediatamente después del número de empleado*.
4. **Especialidad** (`#containerEspecialidad`) -> *Visibilidad dinámica*.
5. **Médico Tratante** (`#containerMedico`) -> *Visibilidad dinámica*.
6. **Método de Pago** (`#selMetodoPago`)

### Reglas de Visibilidad e Interacción Dinámica (`evaluarVisibilidadMedico`)
- **Conceptos Medicos ("Consulta" / "Hospitalización")**:
  - Los contenedores `#containerEspecialidad` y `#containerMedico` permanecen **visibles**.
  - El selector `#selMedico` es **obligatorio**.
- **Otros Conceptos ("Farmacia", "Estudio / Laboratorio", "Otro")**:
  - Los contenedores `#containerEspecialidad` y `#containerMedico` permanecen **ocultos**.
  - Se remueve el atributo `required` de `#selMedico` y se vacía su selección.

## 6. Discriminación de Paciente Real vs. Trabajador Titular (Ingresos Municipio)

En la vista de Finanzas (`views/finanzas.pl`, `tab=ingresos`):
- **Paciente Real**: Es la persona (titular o beneficiario) que recibió la atención o el servicio médico. Se resuelve vía la columna `ALIAS` de `estado_cuenta.dat` o catálogos sanitarios.
- **Trabajador Titular**: Es el empleado titular de la cuenta pública/municipio (`empleadosmun_<CLUES>.dat` con relación `Empleado`).
- **Renderizado DataTables**:
  - *Renglón 1*: `<i class="bi bi-person-fill text-primary"></i> <Nombre del Paciente>` (sin textos ni etiquetas redundantes como "Paciente:").
  - *Renglón 2*: `<i class="bi bi-person-badge text-secondary"></i> Trabajador: <Num> - <Nombre Titular>` (si el paciente es un beneficiario distinto) o `<i class="bi bi-card-text text-secondary"></i> Num. Empleado: <Num>` (si el paciente es el propio trabajador).

## 7. Visualización (R de CRUD)
La visualización en las tablas del recepcionista es manejada por `api/get_recibos_caja_api.pl` y `api/generar_corte_caja.pl`. 
- Dependiendo de la pestaña (`tipo=publicos` o `tipo=privados`), se lee el archivo correspondiente.
- El ID del Médico (columna 15) es parseado en tiempo real cruzando la información con `medicos_QTSMP000116.dat`. 
- **Protocolo de Separador**: Se utiliza strictly `\|` como separador en Perl Regex para evitar divisiones de caracteres erróneas.
