# Flujo de Consultas Clínicas y Contrato SOAP Polimórfico

## 1. Estructura de Consulta SOAP (`views/render_consultas.pl`)

Toda consulta médica utiliza el contrato canónico JSON SOAP:
- **`subjective`**: Anamnesis, motivo de consulta e historial del paciente.
- **`objective`**: Examen físico, signos vitales y datos dinámicos de especialidad (`soap.objective.especialidad_data`).
- **`assessment`**: Diagnóstico (CIE-10), impresión clínica y juicio médico.
- **`plan`**: Plan terapéutico, indicación de medicamentos, estudios auxiliares e indicaciones.

---

## 2. Regla de Oro Polimórfica
El pipeline global es **único e inviolable**. Los subformularios de especialidad (Pediatría, Ginecología, Odontología, Oftalmología) se inyectan como componentes modulares desacoplados desde `views/partials/consultas/` o `views/partials/especialidades/`.
