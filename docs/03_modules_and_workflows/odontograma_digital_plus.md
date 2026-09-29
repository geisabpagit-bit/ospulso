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

---

## 3. Arquitectura de Archivos (Fase 1)
- **CSS**: `css/odontograma_plus.css` (estilos vectoriales, cuadrantes, línea media, hover teal y badges).
- **JavaScript**: `js/odontograma.js` (generador de 32 piezas, estado `window.odontogramState`, función `applySurfaceCondition` y reactividad SVG).
- **Vista**: `views/render_expediente_clinico.pl` (sección `#tab6` en subitem 2.1 Odonto).
