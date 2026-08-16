# ⚖️ Reglas de Negocio SDM v4.4.0 (Diamond Excellence)

## 1. Gestión de Citas y Agenda SPA
- **Protocolo de Color**: Programada (Navy), Confirmada (Verde), Atendida (Teal `#19B7A5`), Cancelada (Rojo), No Asistió (Ámbar).
- **Traslapes**: Validación estricta mediante algoritmo de colisión médica.
- **Insignia de Pago en Recepción**: Si una cita ha sido pagada en recepción (`Confirmada (Pagada)` o estado `pagada`), el botón **`COBRAR EN RECEPCIÓN`** (`#btn-cobrar-recepcion`) en el formulario `#modalCita` DEBE ocultarse y en su lugar se despliega la insignia verde **`✓ Consulta Pagada en Recepción`** (`#leyenda-cita-pagada`).

## 2. Finanzas y Trazabilidad "Path to Excellence"

### 2.1 Estructura Diamond Sync y Cobro por Recepción (Supuestos A, B, C)
- **OS/REC**: Nomenclatura inmutable con trazabilidad por unidad de negocio.
- **Supuesto A (Pre-Pago en Recepción)**:
  - Cuando Recepción cobra la consulta ($500), `api/citas_crud.pl` genera el Cargo y el Abono vinculados al `ID_OS` con la nota `Cita #id_cita`.
  - En `step_caja_privado.pl`, las transacciones se filtran relacionalmente por `ID_OS` e `id_cita`.
  - Si el médico **no agrega conceptos adicionales**, las tarjetas de Gestión de Caja y Programación de Cita se **OCULTAN**, el tratamiento se marca como `Cerrado` en segundo plano, se muestra el aviso de pago en recepción ($0.00 saldo pendiente) y se habilita el botón "Continuar a Cierre".
  - Si el médico **agrega conceptos adicionales** (ej. Limpieza $800), se despliega Gestión de Caja, se muestra la deducción por abono (-$500) y se calcula el saldo restante exacto ($800.00).
- **Supuesto B (Cobro Directo en Consulta)**: El médico liquida en la consulta con el paciente.
- **Supuesto C (Cobro por Recepción Post-Consulta)**: El médico selecciona "Cobro por recepción", registrando `$0.00` de abono en consulta y delegando el cobro diferido a Recepción.

### 2.2 Aislamiento de Caja Directa sin Cita Previa
- Al iniciar una consulta directa sin cita pre-agendada (`$id_cita` vacío `""`), `step_caja_privado.pl` únicamente carga saldos históricos si existe un tratamiento activo explícito (`$tiene_tratamiento && $id_os_row eq $id_tratamiento_activo`).
- Si no hay un tratamiento activo en curso (`tiene_tratamiento = 0`), **NO SE ARRASTRAN** movimientos financieros pasados ($0.00 histórico), iniciando la caja limpia únicamente con la tarifa base ($500.00) o los ítems de la sesión actual.

### 2.3 Protocolo de Impresión v4.4
- **Branding Obligatorio**: Todo reporte e nota clínica debe iniciar con los datos del negocio y del médico tratante (Nombre, Cédula Profesional, Especialidad).
- **Consolidación**: Los reportes financieros deben cerrar con un pie de tabla (`tfoot`) que muestre la suma total de cargos y abonos.
- **Privacidad**: La columna de acciones operativas debe ser invisible en cualquier salida física/impresa (`@media print`).

## 3. Navegación Dinámica en Dashboard Principal
- En *"ACTIVIDAD PROGRAMADA RECIENTE"*, para el rol `Medico`:
  - Citas en estado `Atendida`, `Finalizada` o `Completada` despliegan el botón **`Ver Consulta`** (`btn-outline-primary`), redirigiendo a `consulta_detalles.pl`.
  - Citas no finalizadas (`Confirmada`, `Agendada`, etc.) despliegan el botón **`Tomar Cita`** (`btn-success`), redirigiendo al Wizard Clínico.

## 4. Visor Bento Grid de Expediente Clínico (`consulta_detalles.pl`)
- Despliegue estructurado de la consulta con estándar *MedentIA Diamond Armor*:
  - Banner de Paciente/Médico, Grid de Signos Vitales con IMC autocalculado, Anamnesis con barra de intensidad de síntomas (1-10), Exploración Física, Metodología S.O.A.P. con Clave CIE-10, Receta Médica Expedida, Firmas Digitales Autógrafas en PNG y estilos de impresión carta.

## 5. Seguridad y Privilegios
- **Validación de Sesión**: Toda petición a la API clínica/financiera requiere una sesión activa validada por `check_session.pl`.
- **Candados de Negocio**: El acceso al sistema se bloquea automáticamente si la columna `activo` en `negocios.dat` es falsa.

## 6. Estándares UI/UX y Auditoría UTF-8
- **Codificación Limpia**: Estandarización de `decode_json(encode_utf8(...))` para evitar doble codificación de caracteres en conceptos financieros y textos clínicos.
- **Executive UI**: Las acciones financieras críticas se ubican en la tarjeta del perfil del paciente para máxima eficiencia operativa.

## 7. Protocolos de Desarrollo (Technical Governance)
- **Interpolación en Perl (CSS Rules)**: Al incluir bloques CSS `@media` dentro de bloques heredoc interpolados (`print <<HTML;`), el símbolo `@` **debe escaparse siempre** como `\@media`. De lo contrario, Perl intentará interpretarlo como un arreglo (`array`), provocando errores de compilación bajo `use strict`.
- **Rutas Absolutas (Protocolo 11.1)**: Es mandatorio el uso de `$FindBin::Bin` y `File::Spec` para la construcción de rutas a archivos de datos (`.dat`) o librerías (`.pl`, `.pm`), garantizando la portabilidad entre entornos Windows (XAMPP) y Linux.

## 8. Reglas de Oro de Arquitectura SOAP Polimórfica y Multi-Especialidad
1. **Contrato de Datos JSON SOAP Canónico**: Toda consulta privada debe serializarse bajo las llaves canónicas SOAP (`subjective`, `objective`, `assessment`, `plan`). Los datos dinámicos creados por especialistas DEBEN alojarse dentro de `soap.objective.especialidad_data`.
2. **Core Pipeline Único e Inviolable**: El flujo global (Paso 0 Registro, Agenda, Expediente, Firma y Cierre con Caja) es 100% ÚNICO y compartido. Está strictly PROHIBIDO duplicar vistas completas por especialidad.
3. **Subformularios Desacoplados (Plugin Slot)**: Los subformularios de especialidad deben ser componentes modulares alojados en `views/partials/consultas/` o `views/partials/especialidades/`.

## 9. Padrón de Empleados y Caja Rápida Polimórfica
### 9.1 Gestión del CRUD de Empleados
- **Prevención de Duplicados Clínicos (Colisión Inteligente)**: Al registrar un nuevo empleado, la digitación del "Núm. Empleado" dispara una validación asíncrona. Si el número ya pertenece a un Titular, el sistema auto-asigna el rol de "Beneficiario" y bloquea el campo de relación, evitando colisiones de titulares en el ecosistema.
- **Inmutabilidad en Edición**: Al editar un registro existente, el "Núm. Empleado" y la "Relación" quedan estrictamente bloqueados (`readonly`/`disabled`) para prevenir alteraciones en la jerarquía clínica que comprometerían los presupuestos y el expediente familiar.
- **Resolución de Catálogos en Caliente**: Las dependencias y municipios no se manejan como IDs crudos en la interfaz. El Backend carga los catálogos (`municipios.dat` y `dependencia.dat`) en memoria y el Frontend despliega selectores descriptivos interactivos (`<select>` bajo estándar form-floating).

### 9.2 Caja Rápida (Recibos Privados vs Públicos)
- **Flujo Intercambiable**: El wizard de Caja Rápida permite alternar entre paciente Privado y Público (Capacidad SaaS). Si es Público, se habilita la búsqueda asíncrona avanzada.
- **Mapeo Relacional de Dependencia (API)**: En la API de búsqueda (`buscar_familia_empleado.pl`), el sistema no devuelve el ID huérfano de la dependencia, sino que cruza dinámicamente con el catálogo para presentar el nombre administrativo real a la Recepcionista.
- **Trazabilidad de Impresión (Corrección de Estado)**: El sistema garantiza el pase correcto del `id_tratamiento` hacia los endpoints de emisión PDF (`imprimir_recibo_publico.pl` / `imprimir_recibo_caja.pl`), asegurando que cada movimiento quede sellado financieramente en la sesión del cajero.

**GEISABPA - Diamond Edition v4.4.0**
