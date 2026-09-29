# Odontograma Digital Plus (FDI / ISO 3950)

## 1. Visión General
El **Odontograma Digital Plus** es el componente de mapeo anatómico dental interactivo de OSPulso. Reemplaza el esquema legacy v2.0 por una arquitectura moderna basada en SVG vectorial 2D puro, semántica clínica internacional FDI / ISO 3950 y persistencia atómica por paciente.

---

## 2. Convenciones Clínicas y Anatómicas

### 2.1 Nomenclatura Dental FDI / ISO 3950 (32 Piezas Permanentes)
- **Cuadrante 1 (Superior Derecho del paciente)**: 18, 17, 16, 15, 14, 13, 12, 11
- **Cuadrante 2 (Superior Izquierdo del paciente)**: 21, 22, 23, 24, 25, 26, 27, 28
- **Cuadrante 4 (Inferior Derecho del paciente)**: 48, 47, 46, 45, 44, 43, 42, 41
- **Cuadrante 3 (Inferior Izquierdo del paciente)**: 31, 32, 33, 34, 35, 36, 37, 38

### 2.2 Mapeo Anatómico de Superficies
Cada corona dental se compone de 5 áreas vectoriales independientes:
1. **Oclusal (`occlusal`)**: Superficie central triturante / borde incisal.
2. **Vestibular (`vestibular`)**: Superficie exterior orientada a labios/mejillas.
   - Arcada Superior: Polígono superior (`top`).
   - Arcada Inferior: Polígono inferior (`bottom`).
3. **Lingual / Palatina (`lingual`)**: Superficie interior hacia lengua/paladar.
   - Arcada Superior: Polígono inferior (`bottom`).
   - Arcada Inferior: Polígono superior (`top`).
4. **Mesial (`mesial`)**: Superficie orientada hacia la línea media dental.
   - Cuadrantes 1 y 4 (derecha del paciente, izquierda en pantalla): Polígono derecho (`right`).
   - Cuadrantes 2 y 3 (izquierda del paciente, derecha en pantalla): Polígono izquierdo (`left`).
5. **Distal (`distal`)**: Superficie opuesta a la línea media dental.
   - Cuadrantes 1 y 4: Polígono izquierdo (`left`).
   - Cuadrantes 2 y 3: Polígono derecho (`right`).

### 2.3 Semántica de Colores
- 🔴 **Tratamientos Pendientes / Patología Activa**: `#FF3B30`
- 🔵 **Tratamientos Realizados / Condición Existente**: `#007AFF`
- ⚪ **Superficie Sana / Sin Hallazgo**: `#FFFFFF`
- 🟢 **Hover Interactivo Healthcare**: `#19B7A5`

### 2.4 Familias Anatómicas de Coronas (Fase 1.1)
- **Molares (`18-16, 26-28, 38-36, 46-48`)**: Coronas cuadrangulares/romboidales amplias (38px) con cúspides orgánicas y fisuras oclusales en cruz.
- **Premolares (`15-14, 24-25, 35-34, 44-45`)**: Coronas ovoides bicúspides (35px) con surco mesiodistal.
- **Caninos (`13, 23, 33, 43`)**: Coronas pentagonales anguladas (33px) con cúspide prominente y vertientes anatómicas.
- **Incisivos (`12-11, 21-22, 32-31, 41-42`)**: Coronas esbeltas alargadas (30px) con borde incisal estrecho y flancos proximales delgados.

---

### 2.5 Menú Contextual Clínico y Selector en Cascada (Fase 1.2)
- **Modal Glassmorphism `#modalOdontoClinico`**: Despliegue centrado y responsivo con estética Dark/Glassmorphism compatible con zoom SVG y mobile.
- **Nivel 1 (Alcance / Estructura)**:
  - `SURFACE`: Aplica a la cara seleccionada (Mesial, Distal, Oclusal, Vestibular, Lingual).
  - `CROWN`: Aplica a las 5 superficies de la corona al unísono.
  - `TOOTH`: Aplica a la pieza completa (ej. Diente Ausente con overlay `✕` visual y opacidad atenuada).
- **Nivel 2 (Categorías y Catálogo)**:
  - 🔴 **Patología / Pendiente**: Caries ($850), Fractura ($1,200), Sellador requerido ($450), Corona requerida ($4,500), Endodoncia ($3,200), Exodoncia requerida ($1,100).
  - 🔵 **Tratamiento Existente**: Resina ($850), Amalgama ($700), Corona colocada ($4,500), Endodoncia realizada ($3,200), Implante óseo ($14,000).
  - ⚪ **Sano / Limpiar**: Restaura la superficie o corona a su estado basal sin hallazgos.
  - ❌ **Pieza Ausente**: Diagnóstico a nivel de pieza completa.
- **Nivel 3 (Resumen y Presupuesto)**:
  - Recálculo dinámico automático del presupuesto estimado en base a los tratamientos marcados como pendientes (`PENDING`).
  - Sincronización bidireccional inmediata con `window.odontogramState` y visor JSON en vivo.

---

## 3. Arquitectura de Archivos
- **CSS**: `css/odontograma_plus.css` (estilos vectoriales biomórficos, anchos proporcionales por familia dental, hover teal, persistencia de color, clases `.tooth-absent`, modal glassmorphism y escalado responsivo).
- **JavaScript**: `js/odontograma.js` (generador de 32 piezas por familias anatómicas, rutas `<path>` curvas independientes, estado `window.odontogramState`, controles de zoom dinámico, modal contextual de 3 niveles, catálogo y recálculo presupuestario).
- **Vista**: `views/render_expediente_clinico.pl` (sección `#tab6` con toolbar, controles de zoom interactivo, modal `#modalOdontoClinico` y visor JSON en vivo).



