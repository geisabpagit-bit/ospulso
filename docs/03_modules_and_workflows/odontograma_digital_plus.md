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

### 2.6 OSOdontograma Viewer Pro & Hub Odontológico (Arquitectura Standalone y Multi-Estudio con Alias)
- **Patrón PACS/Viewer Multi-Estudio**: Al igual que el Visor de Rayos X (`render_visor_medico.pl`), el Odontograma cuenta con una arquitectura multi-estudio que permite a cada paciente tener múltiples odontogramas (ej. "Diagnóstico Inicial 2026", "Plan Ortodoncia", "Evolución Post-Quirúrgica"):
  - **Hub Odontológico (`#tab6` en `views/render_expediente_clinico.pl`)**: Layout ejecutivo optimizado a **100% del ancho disponible** con jerarquía visual de 4 niveles:
    1. **Nivel 1 (Hero Header)**: Título clínico, badges FDI/ISO 3950, botón "+ Nuevo Odontograma" y CTA principal *"Lanzar Visor Pro"*.
    2. **Nivel 2 (Bento KPI Grid Horizontal)**: 4 métricas críticas en fila (Presupuesto Estimado en rojo clínico formateado como `$0.00 MXN` sin barras invertidas, Patologías Activas en ámbar, Tratamientos Existentes en azul, Total Odontogramas Registrados en teal).
    3. **Nivel 3 (Observaciones del Odontólogo)**: Callout banner con estilo glassmorphism para notas diagnósticas y fecha de última sincronización.
    4. **Nivel 4 (DataTables Maestro 5 Columnas)**: Tabla `#tablaOdontoHub` al **100% de ancho** (`col-12`) con las 5 columnas requeridas:
       - **Nombre**: Alias descriptivo del odontograma (ej. "Plan Ortodoncia 2026"), badge `#ID` y contador de piezas registradas.
       - **Fecha**: Fecha de registro o última actualización clínica.
       - **Estado**: Badge con semántica visual (`En Proceso / Activo`, `Planificado / Presupuesto`, `Finalizado / Completado`, `Histórico`).
       - **Importe**: Monto presupuestado sugerido formateado estrictamente como `$X.XX MXN` (sin prefijos `\$`).
       - **Acciones (CRUD + Ojo 👁️)**:
         - 👁️ **Ver Detalle Clínico**: Abre el modal `#modalDetalleOdonto` mostrando las 6 columnas anatómicas completas (Pieza FDI, Diente/Familia, Cara/Zona, Diagnóstico, Estado Clínico e Importe Sugerido).
         - 🖥️ **Abrir Visor Pro**: Enlace directo al visor `render_visor_odontograma.pl?id=<id>&id_odonto=<id_odonto>`.
         - 🏷️ **Renombrar / Metadatos**: Modal `#modalRenombrarOdonto` para actualizar Alias, Estado y Observaciones.
         - 🗑️ **Eliminar**: Modal de confirmación SweetAlert2 y borrado seguro vía `api/odontograma_api.pl?accion=delete`.
  - **OSOdontograma Viewer (`views/render_visor_odontograma.pl`)**: Visor médico a pantalla completa (`100vw × 100vh`) con sincronización de Alias en tiempo real, HUD flotante de zoom, lienzo anatómico espacioso y persistencia atómica con `api/odontograma_api.pl`.


### 2.8 Modelado Porcelana 3D, Puente Circular Glassmorphic y Catálogo SaaS (Fase 9)
- **Modelado Anatómico Porcelánico 3D**: Cada una de las 32 piezas (FDI 18 a 48) integra esmalte volumétrico de porcelana biomórfica con gradientes vectoriales (`porcelain-crown-grad`, `porcelain-root-grad`), sombras sutiles, fisuras oclusales y raíces anatómicas realistas:
  - **Molares Superiores (18..16, 26..28)**: 3 raíces anatómicas divergentes apuntando hacia arriba.
  - **Molares Inferiores (48..46, 36..38)**: 2 raíces robustas (mesial y distal) apuntando hacia abajo.
  - **Premolares, Caninos e Incisivos**: Raíces cónicas estilizadas preservando la orientación maxilar/mandibular.
- **Puente Circular Glassmorphic (Radial Floating HUD Dial)**: Al interactuar con cualquier pieza dental, emerge un HUD orbital concéntrico flotante con efecto `backdrop-filter: blur(18px)` y borde neón cyan:
  - 5 botones radiales con iconos direccionales para las caras: **Oclusal** (12h), **Mesial** (3h), **Vestibular** (5h), **Lingual** (7h) y **Distal** (9h).
  - **Núcleo Central Dinámico**: Despliega el número de pieza FDI (`#16`), la cara activa y un indicador en miniatura de su estado.
  - **Interacción por Doble Clic**: Un doble clic en el núcleo central abre el modal clínico contextual de 3 niveles preconfigurado con la pieza y cara seleccionadas.
- **Catálogo Clínico SaaS Reestructurado en 3 Grupos**:
  - 🔴 **Grupo 1: Patología / Hallazgo**: Caries Activa, Caries Recurrente, Fractura, Diente Ausente, Extracción Indicada.
  - 🟠 **Grupo 2: Estado de Tratamiento / Restauración**: Amalgama (Adaptada / Desadaptada), Resina (Adaptada / Desadaptada), Corona (Buena / Desadaptada), Perno (Bueno / Malo), Sellante (Bueno / Desadaptado), Provisional, Endodoncia (Buena / Mala), Implante (Bueno / Malo), Póntico de Puente Fijo.
  - 🟢 **Grupo 3: Estado Normal**: Diente Sano (Sin Hallazgos), Otros Hallazgos Fisiológicos.
- **Sanitización de la Leyenda Clínica**: Eliminación total de nombres literales de colores en la leyenda inferior (ej. "(Rojo)", "(Azul)", "(Blanco)"), sustituidos por terminología clínica limpia y badges luminosos.
- **Inmutabilidad y Cero Rompimiento (Zero Breaking Changes)**: Contrato de selectores, DOM IDs (`#odontograma-svg-container`, `#modalOdontoClinico`, `.tooth-card`, `.tooth-surface`), nombres de métodos globales y contratos JSON intactos para transparencia total en toda la suite.

---

## 3. Arquitectura de Archivos y Persistencia
- **CSS**: `css/odontograma_plus.css` (estilos vectoriales biomórficos, anchos proporcionales por familia dental, hover teal, persistencia de color, clases `.tooth-absent`, `.tooth-extraction-req`, `.tooth-endo-pending`, `.tooth-endo-done`, puente circular `#odonto-radial-menu`, `.radial-glass-disc`, `.radial-nucleus`, `.surface-defective`, modal glassmorphism y visor a pantalla completa).
- **JavaScript**: `js/odontograma.js` (generador de 32 piezas de porcelana 3D por familias anatómicas con raíces, rutas `<path>` curvas independientes, controlador del Puente Circular orbital, estado reactivo `window.odontogramState`, hidratación con `window.loadOdontogramState()`, controles de zoom dinámico, modal contextual de 3 niveles, catálogo SaaS de 3 grupos y recálculo presupuestario).
- **Visor Standalone**: `views/render_visor_odontograma.pl` (aplicación médica completa a `100vw × 100vh` con selector de Alias, Protocolo 11.1 de rutas absolutas, leyenda sanitizada y modal estructurado en 3 grupos).
- **Hub Ejecutivo**: `views/render_expediente_clinico.pl` (sección `#tab6` con DataTable maestro de 5 columnas, modal de hallazgos anatómicos de 6 columnas, modales de creación/renombrado y cálculo de KPIs).
- **Backend API**: `api/odontograma_api.pl` (soporta acciones `list`, `get`, `save`, `rename`, `delete`, `clone`, `set_status`, `get_treatments` con persistencia JSON multi-odontograma en `dat/odontogramas/paciente_<id>.json`, `%PRECIOS_REF` ampliado a las 3 categorías SaaS, `flock` concurrente y sincronización en `.dat`).
- **Gobernanza y Reset Operativo**: Integración con `api/reset_datos_organizacion_api.pl` y `api/hard_reset_db_api.pl` para purgar odontogramas (tanto en `odontogramas.dat` como en los archivos atómicos `dat/odontogramas/paciente_<id>.json`) preservando intactos los registros de otros consultorios o tenants.

---

## 4. Estado de Ejecución de las Fases

| Fase | Descripción Técnica | Entregables Clave | Estatus |
|---|---|---|:---:|
| **Fase 1** | Frontend Layout & SVG Anatómico Biomórfico | 32 piezas FDI, 4 familias (Molar, Premolar, Canino, Incisivo), 5 hitboxes vectoriales por corona, CSS con hover teal. | ✅ COMPLETADA |
| **Fase 2** | Menú Contextual, Selector en Cascada & Visor Standalone | Modal Glassmorphism de 3 niveles (Alcance, Condición, Precio), badges visuales y visor PACS a pantalla completa (`100vw × 100vh`). | ✅ COMPLETADA |
| **Fase 3** | Backend Perl & Archivos Planos Canónicos | `api/odontograma_api.pl` con guardado JSON atómico por paciente (`dat/odontogramas/paciente_<id>.json`), `flock` concurrente y fallback a `.dat`. | ✅ COMPLETADA |
| **Fase 4** | Integración Final & Hub Clínico Odontológico | Tab 6 en `views/render_expediente_clinico.pl` a 100% de ancho, 4 Bento cards de KPI, sincronización en vivo y empty state interactivo. | ✅ COMPLETADA |
| **Fase 5** | Multi-Odontograma con Alias, CRUD y Drilldown Anatómico | Soporte multi-odontograma con Alias, DataTable maestro de 5 columnas (`Nombre`, `Fecha`, `Estado`, `Importe`, `Acciones`), modal de 6 columnas activado por 👁️, erradicación de backslash en `$0.00 MXN` y Protocolos 500/11.1. | ✅ COMPLETADA |
| **Fase 6** | Sanitización Visual, Prevención DataTables TN/4, Redirección #tab6 y Pipeline UTF-8 | Eliminación de botones redundantes en Nivel 1 y 3; supresión de `<table>` con `colspan` en 0 registros para erradicar alerta `tn/4` de DataTables; navegación persistente a `render_expediente_clinico.pl?id=[id]#tab6` en callbacks CRUD; pipeline atómico `:raw` con saneamiento automático de mojibake (`ÃƒÂ­` -> `í`). | ✅ COMPLETADA |
| **Fase 7** | Integración en Wizard Clínico (Paso 3) y Consulta Detalles | Incorporación de `#tablaConsultaOdontogramas` (6 columnas) en `views/partials/consultas/step_exploracion.pl` con switch reactivo; soporte multi-estudio en APIs de cierre; despliegue de odontogramas y estudios de rayos X (PACS) en `views/consulta_detalles.pl` con enlace directo a visores clínicos. | ✅ COMPLETADA |
| **Fase 8** | Evolución Dental ("Antes y Después"), Facturación en Caja y Sello | Clonación profunda (`clone`), extracción de presupuesto (`get_treatments`), inyección reactiva en Caja (Paso 6) y cambio atómico a estado `Finalizado` al cerrar la consulta en `api/cerrar_consulta_privado.pl`. | ✅ COMPLETADA |
| **Fase 9** | Modelado Porcelana 3D, Puente Circular Glassmorphic y Catálogo SaaS 3 Grupos | 32 piezas de porcelana 3D con raíces anatómicas (3 superiores, 2 inferiores), HUD orbital concéntrico flotante con doble clic, catálogo en 3 grupos (Patología, Restauración, Normal), badges adaptada/desadaptada y leyenda sanitizada. | ✅ COMPLETADA |









