# 🏥 SDM - Arquitectura del Flujo Clínico (Wizard Edition v4.3.0)

## Archivos Core (Orquestadores)
- `views/render_consultas.pl` (Flujo Público/Institucional)
- `views/render_consultas_privado.pl` (Flujo Clínico-Financiero Privado con Caja)

---

# 🎯 Objetivo de la Arquitectura
El proceso de consulta médica está diseñado bajo un modelo de **Flujo Clínico Modular (Multi-Step)** con barra de progreso, persistencia incremental (Autosave) y estructura S.O.A.P. polimórfica. Esta arquitectura es el pilar de la suite clínica "MedentIA Diamond", asegurando velocidad operativa, prevención de pérdida de datos, trazabilidad financiero-clínica y blindaje médico-legal.

---

# 🏗 Arquitectura y Componentes
El flujo se aleja de formularios monolíticos y POSTs gigantes. Se divide en 8 módulos asíncronos orquestados por JavaScript y Perl.

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
- `step_exploracion.pl`: Signos vitales, métricas y exploración física (Inyecta dinámicamente el **Odontograma Interactivo** si `id_espe == 100` Odontología).
- `step_estudios.pl`: Laboratorios solicitados o resultados analizados.
- `step_soap.pl`: Motor diagnóstico SOAP, switch opcional de catálogo **CIE-10 / Valoración CIF**, y módulo oficial de **Receta Médica (NOM-024-SSA3)** vinculando la Cédula Profesional del médico.
- `step_comunicacion.pl`: Blindaje médico-legal con explicación del plan y expedición de **Consentimiento Informado (NOM-004-SSA3)**.
- `step_caja_privado.pl`: Gestión de Caja, carrito de conceptos, selección de Destino de Tratamiento ("Alta Médica" por default si no hay cotización previa) y opción de **"Cobro por recepción"**.
- `step_cierre_privado.pl`: Firma autógrafa digital (Pad), conversión a PNG físico en `/uploads/firmas/` y finalización del acto clínico.

## 3. Motor de Persistencia (Autosave Engine)
- **Frontend**: `js/autosave.js` y `js/consulta_flow_privado.js` interceptan los cambios de input (con un debouncer de 2000ms) y las transiciones de paso.
- **Backend Draft**: `api/autosave_consulta.pl` recibe un JSON parcial y actualiza `dat/consulta_draft.dat`. 
- **Ventaja**: Cero pérdida de datos ante desconexiones. El médico puede recargar la página y continuar exactamente donde se quedó.

## 4. Finalización y Trazabilidad Financiera
- `api/cerrar_consulta_privado.pl`:
  - Traslada la consulta desde `consulta_draft.dat` hacia la base de datos definitiva en `dat/consultas_clinicas.dat` (formato JSON dentro de flat-file) y firma el registro.
  - Genera las entradas financieras en `dat/estado_cuenta.dat`: si se selecciona "Cobro por recepción", escribe únicamente el **Cargo** (por $500 tarifa consulta o ítems) sin **Abono**, dejando el saldo pendiente a cobro por Recepción.
  - Actualiza el estado de la cita en `dat/citas.dat` a `Atendida` (color Teal `#19B7A5`).
- **Odontograma**: Si se utilizó, el mapa dental interactivo SVG persiste de forma paralela usando `js/odontograma_spa.js` hacia `api/odontograma_api.pl`.

---

# 👁 Observabilidad y Reportes

## Expediente Clínico (`render_expediente_clinico.pl`)
La vista de historial lee la estructura JSON generada por el Wizard y mapea de forma inteligente el diagnóstico (`diagnostico_principal`), el motivo, el estado de cita "Atendida" en verde y la identidad del médico tratante.

## Visor Maestro, Receta y Consentimiento (`consulta_detalles.pl`, `imprimir_receta_api.pl`, `imprimir_consentimiento_api.pl`)
- **Web**: Despliega un modelo *Bento Grid* interactivo y estilizado para la revisión detallada de la consulta por parte de auditores o médicos interconsultantes.
- **PDF e Impresión**: Generación de Receta Médica oficial con Cédula Profesional y Consentimiento Informado con firma digital lista para imprimir en formato carta oficial.

---

# 🔒 Reglas Innegociables del Flujo
1. **Protocolo 500 Guard**: Todo parseo de JSON (`decode_json`) y evaluación de datos debe estar envuelto en bloques `eval {}` para evitar bloqueos del CGI.
2. **UTF-8 Forzado**: Todo archivo del Wizard debe declarar `use strict; use warnings; use utf8;` y `binmode STDOUT, ":utf8";` debido al amplio uso de vocabulario médico con tildes y caracteres latinos.
3. **Estilo Diamond Armor**: Prohibido usar estilos inline. Todo contenedor debe heredar de `card-medentia-aura` o los inputs de `wizard-input` (Estándar #19B7A5).
4. **Escape de Escalares CSS/JS**: En bloques string interpolados o heredocs (`<<"HTML"`), se deben escapar símbolos de arroba como `\@media` para evitar errores de compilación por variables no declaradas.