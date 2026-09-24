# Módulo de Visor Médico y Estándares DICOM PACS (`views/render_visor_medico.pl`)

## 1. Visión General
El **Visor Médico** (`views/render_visor_medico.pl`) administra la carga, previsualización, inspección radiológica e integración de archivos de imagen médica vinculados al expediente del paciente.

---

## 2. Formatos y Archivos Soportados

1. **Formatos Estándar de Imagen**: JPG, PNG, WEBP (fotografías clínicas, ultrasonidos impresos, estudios generales).
2. **Archivos Médicos DICOM**: `.dcm` (Radiografías digitales, Tomografías, Resonancias Magnéticas).

---

## 3. Principios de Diseño y UX/UI
- **Entorno Oscuro Clínico**: Interfaz diseñada sobre tonos oscuros/antracita para reducir la fatiga visual del facultativo durante la lectura de radiografías.
- **Herramientas PACS Integradas**:
  - Ajuste de Ventana y Nivel (Window Width / Window Level - WW/WL).
  - Herramientas de Zoom, Panorámica (Pan) y Rotación.
  - Mediciones de distancia en milímetros y marcado de regiones de interés (ROI).
- **Asociación Directa al Expediente**: Toda imagen adjunta se asocia al ID del paciente y al folio de consulta SOAP correspondiente.
