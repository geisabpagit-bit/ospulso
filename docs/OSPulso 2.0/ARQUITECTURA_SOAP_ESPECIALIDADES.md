# 🏛️ Arquitectura de Software: Wizard Clínico Dinámico SOAP y Sistema Polimórfico de Especialidades

**Versión**: OsPulso Diamond Edition v4.2.0  
**Ámbito**: Módulo de Consultas Privadas y Gestión de Personal

---

## 📌 1. Principio Fundamental
El sistema opera bajo un **Core Pipeline Único (80% compartido)** e **Inyectores de Especialidad Pluggables (20% dinámico)**.

Esta arquitectura garantiza que el software pueda crecer hasta incluir decenas de especialidades médicas (Pediatría, Ginecología, Cirugía, Nutriología, Cardiología, etc.) **sin duplicar código operativo** (Caja, Agenda, Expedientes, Firma Digital, PDF) y sin generar un monolito ingobernable.

---

## 🛡️ 2. Las 3 Reglas de Oro de Arquitectura

### 1. Contrato de Datos JSON SOAP Canónico
Todas las consultas registradas en `dat/consultas_clinicas.dat` deben serializar sus datos en formato JSON bajo las 4 claves principales de la metodología SOAP:
- **`subjective`**: Anamnesis, motivo de consulta e historial.
- **`objective`**:
  - `signos_vitales`: TA, FC, FR, Temp, Peso, Talla, IMC, SpO2 (Universales).
  - `id_espe`: ID numérico de la especialidad.
  - `especialidad_data`: Objeto JSON con los campos y métricas nativas del subformulario del especialista.
- **`assessment`**: Diagnóstico principal (CIE-10), diagnósticos secundarios y análisis clínico.
- **`plan`**: Tratamiento, prescripción/receta médica, indicaciones y estudios ordenados.

### 2. Core Pipeline Único e Inviolable
- Existe un único wizard principal de consulta privada: [views/render_consultas_privado.pl](file:///c:/xampp/htdocs/ospulso/views/render_consultas_privado.pl).
- Está **estrictamente prohibido crear copias o scripts paralelos por especialidad** (ej. NO crear `consulta_pediatria.pl` ni `consulta_ginecologia.pl`).
- Todos los médicos, independientemente de su especialidad, transitan por la misma secuencia de pasos de control (Registro -> Anamnesis -> Exploración -> Estudios -> SOAP -> Acuerdos -> Caja -> Cierre).

### 3. Subformularios Desacoplados (Plugin Slot)
- Los módulos por especialidad se alojan como componentes independientes en `views/partials/consultas/` o `views/partials/especialidades/`.
- La pestaña **Exploración Física / Objetivo (O)** evalúa el `id_espe_medico` cargado inmutablemente desde el perfil del médico (`usuarios.dat`):
  - **Si existe subformulario nativo (ej. Odontología / ID 100)**: Renderiza la herramienta específica (Odontograma interactivo).
  - **Si no existe aún el subformulario nativo**: Renderiza automáticamente el **Módulo de Fallback Universal**, mostrando los Signos Vitales básicos y la tarjeta informativa:
    `"(Aquí van los subformularios según la especialidad)"`.

---

## 🛠️ 3. Guía de Integración para Nuevas Especialidades

Cuando se diseñe un nuevo módulo con un médico especialista (ej. Pediatría, Nutriología, Ginecología):

1. **Definición de Campos**: Crear el componente parcial en `views/partials/especialidades/paso_nombre.pl`.
2. **Inyección en el Slot Objetivo**: En [step_exploracion.pl](file:///c:/xampp/htdocs/ospulso/views/partials/consultas/step_exploracion.pl), agregar el bloque condicional por `id_espe`:
   ```perl
   if ($id_espe eq '3') { # Pediatría
       $subformulario_html = render_modulo_pediatria($paciente);
   }
   ```
3. **Persistencia**: Garantizar que los campos del nuevo subformulario se empaqueten dentro de `especialidad_data`.
