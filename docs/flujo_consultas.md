# 🏥 SDM - Arquitectura del Flujo Clínico (Wizard Edition v4.4.0)

## Archivos Core (Orquestadores)
- `views/render_consultas.pl` (Flujo Público/Institucional)
- `views/render_consultas_privado.pl` (Flujo Clínico-Financiero Privado con Caja)

---

# 🎯 Objetivo de la Arquitectura
El proceso de consulta médica está diseñado bajo un modelo de **Flujo Clínico Modular (Multi-Step)** con barra de progreso, persistencia incremental (Autosave), trazabilidad financiera multi-escenario (Cobro Inmediato, Pre-Pago en Recepción y Cobro Diferido) y metodología S.O.A.P. polimórfica.

---

# 🏗 Arquitectura y Componentes
El flujo se divide en 8 módulos asíncronos orquestados por JavaScript y Perl.

## 1. El Shell Principal (`render_consultas_privado.pl`)
Actúa como un cascarón (shell) que inyecta dinámicamente los componentes parciales según el progreso. Gestiona:
- Autenticación y recuperación del estado (`$draft_step`).
- Menú lateral (Stepper) y barra superior corporativa con *Teal Clínico*.
- Carga de Cédula Profesional del médico tratante (desde `usuarios.dat` índice 9).
- Contenedores principales (Wizard Panels) con estilo *MedentIA Diamond Armor*.

## 2. Los Módulos Parciales (`views/partials/consultas/`)
Cada paso del flujo clínico es un archivo `.pl` independiente que se incluye en el Shell:
- `step_registro_privado.pl`: Datos básicos (Motivo, Tipo, Especialidad, Cotización del Paciente).
- `step_anamnesis.pl`: Padecimiento, evolución, APNP y alergias.
- `step_exploracion.pl`: Signos vitales, métricas e IMC (Inyecta dinámicamente el **Odontograma Interactivo** si `id_espe == 100` Odontología).
- `step_estudios.pl`: Laboratorios solicitados o resultados analizados.
- `step_soap.pl`: Motor diagnóstico SOAP, switch opcional de catálogo **CIE-10 / Valoración CIF**, y módulo oficial de **Receta Médica (NOM-024-SSA3)** vinculando la Cédula Profesional del médico.
- `step_comunicacion.pl`: Blindaje médico-legal con explicación del plan y expedición de **Consentimiento Informado (NOM-004-SSA3)**.
- `step_caja_privado.pl`:
  - **Supuesto A (Pre-Pago en Recepción)**: Si la cita ya fue pagada en Recepción y no hay ítems adicionales, oculta automáticamente las tarjetas de caja y programación de cita, fija el tratamiento como `Cerrado` en segundo plano y habilita la transición limpia al cierre. Si hay adicionales (ej. $800), calcula la deducción del abono (-$500) y fija el saldo resultante ($800.00).
  - **Supuesto B (Cobro en Consulta)**: Cobro directo en consulta.
  - **Supuesto C (Cobro por Recepción)**: Delega la cobranza a Recepción fijando `$0.00` de abono en el Wizard.
  - **Aislamiento de Citas Directas**: Si `$id_cita` está vacío (`""`), la caja no arrastra movimientos pasados ($0.00 histórico), garantizando un inicio limpio en $500 o ítems de la sesión.
- `step_cierre_privado.pl`: Firma autógrafa digital (Pad), conversión a PNG físico en `/uploads/firmas/` y finalización del acto clínico.

## 3. Motor de Persistencia (Autosave Engine)
- **Frontend**: `js/autosave.js` y `js/consulta_flow_privado.js` interceptan los cambios de input (con un debouncer de 2000ms) y las transiciones de paso.
- **Backend Draft**: `api/autosave_consulta.pl` recibe un JSON parcial y actualiza `dat/consulta_draft.dat`. 
- **Ventaja**: Cero pérdida de datos ante desconexiones. El médico puede recargar la página y continuar exactamente donde se quedó.

## 4. Finalización y Trazabilidad Financiera
- `api/cerrar_consulta_privado.pl`:
  - Traslada la consulta desde `consulta_draft.dat` hacia la base de datos definitiva en `dat/consultas_clinicas.dat` (formato JSON dentro de flat-file) y firma el registro.
  - Genera las entradas financieras en `dat/estado_cuenta.dat`.
  - Actualiza el estado de la cita en `dat/citas.dat` a `Atendida` (color Teal `#19B7A5`).

---

# 👁 Visor Maestro de Consultas (`consulta_detalles.pl`)
Despliega un modelo *Bento Grid* interactivo para la revisión detallada del expediente clínico:
- Banner del Paciente y Médico con Cédula Profesional.
- Tarjetas Bento de Signos Vitales, Anamnesis, Barra de Intensidad de Síntomas (1-10), Exploración Física, Metodología S.O.A.P. con CIE-10, Receta Médica Expedida, y Firmas Autógrafas Digitales en PNG.
- Estilos `@media print` para impresión física de nota médica o exportación a PDF.

---

# 🔒 Reglas Innegociables del Flujo
1. **Protocolo 500 Guard**: Todo parseo de JSON (`decode_json`) y evaluación de datos debe estar envuelto en bloques `eval {}` para evitar bloqueos del CGI.
2. **UTF-8 Forzado**: Todo archivo del Wizard debe declarar `use strict; use warnings; use utf8;` y `binmode STDOUT, ":utf8";`. Estandarización de `decode_json(encode_utf8(...))` para prevenir doble codificación de caracteres.
3. **Estilo Diamond Armor**: Prohibido usar estilos inline. Todo contenedor debe heredar de `card-medentia-aura` o los inputs de `wizard-input` (Estándar #19B7A5).
4. **Escape de Escalares CSS/JS**: En bloques string interpolados o heredocs (`<<"HTML"`), se deben escapar símbolos de arroba como `\@media` para evitar errores de compilación por variables no declaradas.

**Software Dental Mexicano - Diamond Edition v4.4.0**