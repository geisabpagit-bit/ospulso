# 📖 Documentación Maestra SDM v4.4.0
**Software Dental Mexicano - Diamond Edition (The Clinical & Financial Standard)**

## 1. Visión v4.4.0 (Multi-Scenario Clinical & Financial Suite)
Esta versión consolida el perfeccionamiento operativo de la Suite Clínica y Financiera Privada. Se ha establecido una arquitectura SOAP polimórfica y multi-especialidad inviolable, trazabilidad financiera multi-escenario (Pre-pago en recepción, cobro en consulta y cobro diferido post-consulta), prevención de arrastre de saldos históricos en consultas directas sin cita, navegación inteligente en Dashboard con visualización Bento Grid de expedientes, módulo de recetas (NOM-024-SSA3) y consentimientos informados (NOM-004-SSA3) con firmas autógrafas/FIEL.

---

## 2. Componentes Críticos

### 2.1 Trazabilidad Financiera Multi-Escenario (Caja Privada v4.4)
El sistema soporta tres escenarios operativos integrales para el cobro de la consulta:
- **Supuesto A: Cobro Anticipado en Recepción (Pre-Pago)**:
  - Cuando el paciente paga su consulta en Recepción (`views/agenda_main.pl`), `api/citas_crud.pl` registra tanto el **Cargo** (`Consulta Médica (Cobro en Recepción)`) como el **Abono** (`Pago de Consulta ($metodo - Recepción)`) vinculando ambos movimientos al mismo `ID_OS` y registrando en la nota `Cita #id_cita`.
  - **Aislamiento por Cita**: `step_caja_privado.pl` filtra relacionalmente por `ID_OS` y `$id_cita`, evitando que citas del mismo paciente en diferentes horarios del mismo día traslapen o dupliquen montos.
  - **Flujo Transparente en Consulta sin adicionales**: Si el médico no agrega ítems adicionales, el carrito se purga automáticamente de `CONS-BASE`, las tarjetas de Gestión de Caja y Programación de Cita se **OCULTAN**, el tratamiento se marca como `Cerrado` en segundo plano y el botón *"Continuar a Cierre"* permite avanzar directamente al cierre con firmas.
  - **Flujo con adicionales en Supuesto A**: Si el médico agrega ítems adicionales (ej. Limpieza $800), se despliega la tarjeta de Gestión de Caja. La tabla lista en orden estricto: (1) Consulta Médica $500, (2) Limpieza $800, (3) Total Cargos $1,300, (4) Deducción por Abono de Recepción -$500, y (5) Saldo Restante / Monto a Pagar en **$800.00** exactos.
- **Supuesto B: Cobro Directo en Consulta**:
  - El médico realiza el cobro durante la atención médica, desglosando la tarifa de consulta e ítems adicionales en la tarjeta de Gestión de Caja.
- **Supuesto C: Cobro por Recepción Post-Consulta (Cobro Diferido)**:
  - El médico selecciona "Cobro por recepción". `cerrar_consulta_privado.pl` registra los cargos con `$monto_abono = $0.00`, derivando la liquidación total a Recepción al finalizar la atención.

### 2.2 Prevención de Arrastre de Movimientos sin Cita Previa
- **Regla de Aislamiento Directo**: Al iniciar una consulta directa desde el expediente o dashboard sin una cita pre-agendada (`$id_cita` vacío `""`), `step_caja_privado.pl` únicamente carga saldos históricos si existe un tratamiento activo explícito en curso (`$tiene_tratamiento && $id_os_row eq $id_tratamiento_activo`).
- **Garantía Operativa**: Si no existe un tratamiento activo, el saldo histórico cargado es **$0.00**, iniciando la caja limpia únicamente con la tarifa base ($500.00) o los ítems de la sesión actual, evitando arrastrar movimientos financieros pasados del día o de días anteriores.

### 2.3 Navegación Dinámica en Dashboard Principal (`views/render_dashboard_principal.pl`)
- En la sección *"ACTIVIDAD PROGRAMADA RECIENTE"*, para el rol `Medico`:
  - Si la cita está en estado `Atendida`, `Finalizada` o `Completada`, se renderiza el botón **`Ver Consulta`** (`btn-outline-primary` con `<i class="bi bi-file-earmark-medical me-1"></i>`), el cual redirige a `views/consulta_detalles.pl?id_cita=...&id_paciente=...`.
  - Si el estado de la cita no se ha finalizado aún (`Confirmada`, `Agendada`, etc.), el botón se renderiza como **`Tomar Cita`** (`btn-success` con `<i class="bi bi-person-check me-1"></i>`), dirigiendo al Wizard Clínico (`render_consultas_privado.pl`).

### 2.4 Visor Maestro de Consulta Bento Grid (`views/consulta_detalles.pl`)
- Resumen clínico integral con la arquitectura visual *MedentIA Diamond*:
  - **Banner de Identificación**: Nombre del Paciente, Sexo, Grupo Sanguíneo, Alergias en rojo alerta, Teléfono, CURP, Médico Tratante, Cédula y Especialidad.
  - **Grid de Signos Vitales**: T.A., F.C., F.R., Temp, SpO2 e **IMC calculado automáticamente** con estatus nutricional (Bajo peso, Normal, Sobrepeso, Obesidad).
  - **Anamnesis & Padecimiento**: Motivo, Evolución, Barra gráfica de intensidad de dolor/síntomas (1-10) y Antecedentes.
  - **Exploración Física & Estudios**: Hallazgos clínicos por regiones y laboratorios/gabinete solicitados.
  - **S.O.A.P. & Diagnóstico (CIE-10)**: Diagnóstico Principal con Clave CIE-10, diagnósticos secundarios, severidad, pronóstico y Plan de Tratamiento (P).
  - **Receta Médica Expedida**: Tabla de fármacos prescritos, dosificación, posología, vía de administración e indicaciones.
  - **Firmas Autógrafas Digitales**: Implicación de firmas en PNG del médico tratante y del paciente/tutor.
  - **Estilos de Impresión (`@media print`)**: Formato estandarizado para generación de nota clínica física o PDF.

### 2.5 Insignia y Visibilidad Dinámica "Cobrar en Recepción" (`views/agenda_main.pl` / `js/agenda_spa_new.js`)
- En el modal de gestión de citas (`#modalCita`):
  - Cuando una cita ya fue pagada en Recepción (`Confirmada (Pagada)` o estado `pagada`):
    - El botón **`COBRAR EN RECEPCIÓN`** (`#btn-cobrar-recepcion`) se oculta automáticamente (`d-none`).
    - Se despliega la insignia verde **`✓ Consulta Pagada en Recepción`** (`#leyenda-cita-pagada`).
  - Al completar la transacción en Recepción desde el modal, el callback de JS actualiza el objeto local en tiempo real, oculta el botón e intercambia el botón por la insignia sin recargar la página.

### 2.6 Auditoría UTF-8 y Estandarización JSON
### 2.7 Catálogo Universal 3NF Multi-Tenant (`views/manage_catalogo_universal.pl`)
- **Arquitectura de Datos 3NF**: Gestión centralizada multi-tenant segregada por `id_raiz` / `id_empresa` para Servicios, Productos, Departamentos y Categorías.
- **Filtros en Cascada y Búsqueda Avanzada**:
  - Panel dinámico con selector de **Departamento** $\rightarrow$ selector en cascada de **Categoría** $\rightarrow$ campo de **Texto Libre**.
  - Integración nativa con DataTables (`$.fn.dataTable.ext.search`) y barra de exportación estilizada (*Copiar*, *Excel*, *PDF*, *Imprimir*).
- **Estandarización UI/UX Premium (Azul Marino `#0A2A66`)**:
  - Desanidación de capas contenedoras (`container-mobile-flush` / `card-mobile-flush`) eliminando márgenes redundantes y el efecto de "caja sobre caja".
  - Paleta institucional mandante en pestañas y botones (`.btn-navy-primary` y `.btn-navy-outline`) previniendo el desbordamiento de texto.
- **Normalización en MAYÚSCULAS**:
  - Transformación instantánea a MAYÚSCULAS en el Frontend (`oninput="this.value = this.value.toUpperCase()"`) y sanitización en el Backend API (`$nombre = uc($nombre);`).
- **Gobernanza RBAC**: Acceso habilitado únicamente para `Administrador Global` y `Administrador Organizacion`.

### 2.8 Gestión de Usuarios y Roles Operativos (`views/administracion_usuarios.pl`)
- **Sincronización Polimórfica de Roles**:
  - Permite la alta y edición tanto de personal médico (`Medico`) como de personal operativo (`Recepcionista`).
  - Al seleccionar el rol `Recepcionista`, el sistema oculta y omite los campos de especialidad médica y subespecialidad, presentando una entrada libre para el nombre del colaborador o la lista institucional de médicos asignables.

### 2.9 Formato Normativo de Pie de Recibos (`api/imprimir_recibo_publico.pl` / `api/imprimir_recibo_caja.pl`)
- **Formato Estándar CLUE / Sucursal**:
  - El pie de los recibos impresos (públicos y de caja) recupera dinámicamente los datos de la unidad médica desde `CAT_CLUES.dat` (si cuenta con clave CLUE) o como fallback desde `negocios.dat`.
  - Desglose limpio **sin paréntesis**: *Dirección Completa (Calle y No.), Colonia / Localidad, Municipio o Alcaldía, Entidad Federativa, Teléfono de Oficina / Clínica, Código Postal*.

### 2.10 Gestión Segura de Copias de Seguridad (`views/admin_backups.pl` & APIs)
- **Prevención de Disparos Automáticos**: Atributos explícitos `type="button"` en todos los controles para evitar la generación involuntaria de backups al cargar la página.
- **Soporte Completo de Eliminación**: Expresión regular actualizada en `api/delete_backup_api.pl` y `api/restore_db_api.pl` permitiendo gestionar tanto autobackups (`auto_backup_ospulso_...`) como respaldos manuales (`ospulso_backup_...`).

---

## 3. Guía de Arquitectura
- **Backend**: Perl Modular (`views/*.pl`, `api/*.pl`) con persistencia en flat-files (`.dat`) respaldados por bloqueos atómicos (`flock`).
- **Frontend**: SPA con Vanilla JS, Bootstrap 5, Animate.css y SweetAlert2.
- **Estilos (CSS)**: Sistema de diseño *MedentIA Diamond Armor* en archivos `.css` independientes.
- **Seguridad**: Middleware de sesión `check_session.pl`, hashing SHA-256 y blindaje de suscripción.

## 4. Módulos Específicos
- **Quirófano y Hospitalización**: [Documentación del Módulo Kanban de Quirófano](modulo_quirofano.md)

---

## 5. Historial de Ajustes Técnicos Recientes (v4.4.1)
- **Cobro Anticipado Recepción (Supuesto A)**: Asociación relacional por `ID_OS` y deducción exacta del abono de recepción (-$500.00) ante conceptos adicionales ($800.00 -> $800.00 neto).
- **Ocultamiento Transparente de Paneles**: Supuesto A sin adicionales oculta automáticamente Gestión de Caja y Programación de Cita.
- **Aislamiento de Caja sin Cita**: Eliminación de arrastre de saldos pasados ($0.00 históricos) en consultas directas sin cita previa.
- **Navegación Dinámica Dashboard**: Botones dinámicos "Ver Consulta" vs "Tomar Cita" según estado de la cita.
- **Refactorización Bento Grid `consulta_detalles.pl`**: Visor de expediente clínico completo con Signos Vitales, SOAP, Receta, Firmas e Impresión.
- **Insignia "Consulta Pagada en Recepción"**: Alternancia automática del botón de cobro e insignia verde en el formulario de la Agenda.
- **Catálogo Universal 3NF**: Refactorización de layout, barra de filtros en cascada, tema Azul Marino `#0A2A66`, normalización a MAYÚSCULAS y RBAC de Administradores.
- **Administración de Usuarios Operativos**: Módulo de alta/edición de Recepcionistas desacoplado de especialidades médicas.
- **Pie de Recibos CLUE / Sucursal**: Formateo sin paréntesis de la ubicación física en recibos de caja y públicos.
- **Seguridad en Módulo de Backups**: Prevención de autobackups al ingresar a la vista y soporte de borrado para prefijos `auto_backup_` y `ospulso_backup_`.

**Software Dental Mexicano - Diamond Edition v4.4.1**

### 2.7 M�dulo de Gesti�n Din�mica de Cat�logos (Enterprise)
- **Aislamiento de Configuraci�n Base**: Un administrador puede mantener archivos .dat de listas maestras a nivel tenant (CLUE) bajo un sistema CRUD agn�stico y validado.
- Ver detalles t�cnicos y arquitectura Frontend (Hooks de Cat�logo) en: [M�dulo Gesti�n de Cat�logos](modulo_gestion_catalogos.md)
