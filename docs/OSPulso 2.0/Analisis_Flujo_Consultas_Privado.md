# 📋 Análisis Técnico y Funcional: Flujo de Consultas Privadas y Control de Sesión

**Versión**: OsPulso Diamond Edition v4.5.0  
**Ámbito**: Módulo de Consultas Privadas, Expediente Clínico y Caja  
**Estado**: Fuente Canónica Principal de Verdad (Actualizado 2026)

---

## 📌 1. Visión General
El módulo de **Consultas Privadas** ([views/render_consultas_privado.pl](file:///c:/xampp/htdocs/ospulso/views/render_consultas_privado.pl)) administra el ciclo de vida completo de la atención médica particular y de convenio en un wizard estructurado en 8 pasos.

---

## 🛡️ 2. Mecanismos de Control y Gobernanza Clínica

### A. Inicialización de Tiempo y Datos de Cita
- **Con Cita Previa**: Se leen datos de `citas.dat` (paciente, médico, motivo). Si la cita no estaba iniciada, el backend actualiza automáticamente el campo `HORA_INICIO_REAL` con la marca de tiempo de entrada del facultativo.
- **Sin Cita / Express**: Se inicializa con el momento real de inicio (`localtime`).

### B. Restricción Estricta de Consulta Única Activa por Médico
- **Regla Clínica**: Un médico no puede mantener 2 consultas activas en paralelo.
- **Validación Backend**: Al intentar abrir una consulta, el backend analiza `citas.dat`. Si el facultativo (`$id_medico`) ya posee una cita en estado **`En consulta`** diferente, se bloquea la navegación desplegando una alerta modal (SweetAlert2) que le exige finalizar la consulta activa previa.

### C. Visualización de "Continuar Consulta" y Badges
- **Navegación Fluida**: En [views/render_expediente_clinico.pl](file:///c:/xampp/htdocs/ospulso/views/render_expediente_clinico.pl), el botón de la cita activa se transforma en **`Continuar con la consulta ▶`** (`btn-info text-white`).
- **Badge en Pacientes**: En `views/pacientes.pl`, el estado se renderiza con el badge **`En Consulta`** con enlace interactivo.

### D. Grid Responsivo de 4 Columnas
- Formulario de registro ([step_registro_privado.pl](file:///c:/xampp/htdocs/ospulso/views/partials/consultas/step_registro_privado.pl)):
  - **Escritorio y Tablet (`≥ 768px`)**: Grid de **4 columnas simétricas** (`col-12 col-md-3`).
  - **Móvil (`< 768px`)**: Colapso a **1 columna** (`col-12`).

### E. Cálculo Automático de Edad
- Se extrae `FECHA_NAC` de `dat/pacientes.dat` y se calcula la edad en años con `calcular_edad($fecha_nac)` desplegándola junto al Sexo en el header del expediente.

---

## ⚙️ 3. Innovaciones Técnicas del Wizard

### A. Trazabilidad de Tratamientos Abiertos
- Si el paciente cuenta con un tratamiento activo en `dat/tratamientos.dat`, el Paso 0 bloquea el tipo a *Seguimiento* y calcula el saldo histórico leyendo `dat/estado_cuenta.dat`.

### B. Carrito Local y Cargos Directos (`modalCargoConsultas`)
- El Paso 6 integra `modalCargoConsultas` consumiendo `/api/estado_cuenta_api.pl?accion=get_catalogo`.
- Permite agregar servicios/medicamentos adicionales en memoria, serializando los ítems en `caja_items_json` para que `cerrar_consulta_privado.pl` anexe los cargos a la orden de servicio.

### C. Solución al Conflicto Backdrop Trap
- Modales anidados (`modalCargoConsultas`, `modalCita`) ejecutan `document.body.appendChild(modalEl)` al abrirse, moviéndolos a la raíz del DOM para evitar quedar atrapados tras el telón oscuro `.modal-backdrop` de Bootstrap.

### D. Hub PACS y Visor DICOM
- En `step_estudios.pl`, se consulta `dat/estudios.dat` mostrando miniaturas `.jpg`/`.png` y enlaces directos al Visor DICOM (`render_visor_medico.pl`).

---

## 💰 4. Vinculación con Caja Rápida y Multi-Tarifa
Al finalizar la consulta, la orden se envía a Caja Rápida ([views/generar_recibo.pl](file:///c:/xampp/htdocs/ospulso/views/generar_recibo.pl)):
- **Atención Comercial Privada**: Aplica esquema comercial con soporte Multi-Tarifa (`ESTÁNDAR`, `URGENCIAS`, `DOMINGOS Y FESTIVOS`).
- **Atención Convenio Municipio**: Valida tabulador público en `dat/folios_recibos_publicos.dat` computando el cobro como **Cuentas por Cobrar (CXC Estado)**.
