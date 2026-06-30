# 🏥 SDM - Arquitectura del Flujo Clínico (Wizard Edition)

## Archivo Core (Orquestador)
`views/render_consultas.pl`

---

# 🎯 Objetivo de la Arquitectura
El proceso de consulta médica está diseñado bajo un modelo de **Flujo Clínico Modular (Multi-Step)** con barra de progreso, persistencia incremental (Autosave) y estructura S.O.A.P. Esta arquitectura es el pilar de la suite clínica "MedentIA Diamond", asegurando velocidad operativa, prevención de pérdida de datos y trazabilidad médico-legal.

---

# 🏗 Arquitectura y Componentes
El flujo se aleja de formularios monolíticos y POSTs gigantes. Se divide en módulos asíncronos orquestados por JavaScript y Perl.

## 1. El Shell Principal (`render_consultas.pl`)
Actúa como un cascarón (shell) que inyecta dinámicamente los componentes parciales según el progreso. Gestiona:
- Autenticación y recuperación del estado (`$draft_step`).
- Menú lateral (Stepper) estilizado con *Teal Clínico*.
- Contenedores principales (Wizard Panels) con estilo *MedentIA Diamond Armor*.

## 2. Los Módulos Parciales (`views/partials/consultas/`)
Cada paso del flujo clínico es un archivo `.pl` independiente que se incluye en el Shell:
- `step_registro.pl`: Datos básicos (Motivo, Tipo, Especialidad).
- `step_anamnesis.pl`: Padecimiento, evolución, APNP y alergias.
- `step_exploracion.pl`: Signos vitales, métricas y exploración física (Inyecta dinámicamente el **Odontograma Interactivo** si la especialidad es Odontología).
- `step_estudios.pl`: Laboratorios solicitados o resultados analizados.
- `step_soap.pl`: Motor diagnóstico, CIE-10 (Próximamente), impresión diagnóstica.
- `step_receta.pl`: Módulo independiente de prescripción de medicamentos.
- `step_cierre.pl`: Checklists legales, acuerdos médicos, firma y botón de finalización.

## 3. Motor de Persistencia (Autosave Engine)
- **Frontend**: `js/autosave.js` y `js/consulta_flow.js` interceptan los cambios de input (con un debouncer de 2000ms) y las transiciones de paso.
- **Backend Draft**: `api/autosave_consulta.pl` recibe un JSON parcial y actualiza `dat/consulta_draft.dat`. 
- **Ventaja**: Cero pérdida de datos ante desconexiones. El médico puede recargar la página y continuar exactamente donde se quedó.

## 4. Finalización y Trazabilidad
- `api/cerrar_consulta.pl`: Traslada la consulta desde `consulta_draft.dat` hacia la base de datos definitiva en `dat/consultas_clinicas.dat` (formato JSON dentro de flat-file) y firma el registro.
- **Odontograma**: Si se utilizó, el mapa dental interactivo SVG persiste de forma paralela usando `js/odontograma_spa.js` hacia `api/odontograma_api.pl`.

---

# 👁 Observabilidad y Reportes

## Expediente Clínico (`render_expediente_clinico.pl`)
La vista de historial lee la estructura JSON generada por el Wizard y mapea de forma inteligente el diagnóstico (`diagnostico_principal`), el motivo y la identidad del médico tratante (mediante `obtener_nombre_medico()`).

## Visor Maestro y Notas de Evolución (`consulta_detalles.pl`)
- **Web**: Despliega un modelo *Bento Grid* interactivo y estilizado para la revisión detallada de la consulta por parte de auditores o médicos interconsultantes.
- **Impresión**: A través de las reglas de `@media print`, oculta la interfaz web y genera una Nota Médica de ancho completo (100%) lista para el formato carta oficial (Apegado a las Reglas de Impresión SDM).

---

# 🔒 Reglas Innegociables del Flujo
1. **Protocolo 500 Guard**: Todo parseo de JSON (`decode_json`) y evaluación de datos debe estar envuelto en bloques `eval {}` para evitar bloqueos del CGI.
2. **UTF-8 Forzado**: Todo archivo del Wizard debe declarar `binmode STDOUT, ":utf8";` debido al amplio uso de vocabulario médico con tildes y caracteres latinos.
3. **Estilo Diamond Armor**: Prohibido usar estilos inline. Todo contenedor debe heredar de `card-medentia-aura` o los inputs de `wizard-input` (Estándar #19B7A5).