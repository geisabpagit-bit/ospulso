# Tareas Pendientes - SDM Digital v4.2.0

## ✅ Completado Recientemente (Hitos v3.8 "Diamond Clinical")
- [x] **Refactorización Expediente "Command Center"**: Interfaz Diamond Excellence en `render_expediente_clinico.pl`.
- [x] **CRM de Comunicaciones**: Bitácora de mensajes con detalle profundo y motor de lectura.
- [x] **Visor de Adjuntos Maestro**: Previsualización integrada de PDF e imágenes sin redirecciones.
- [x] **Navegación Híbrida Sidebar/Dock**: Menú lateral dinámico para móviles con overlay de cristal.
- [x] **Arquitectura de Escape (Modales)**: Implementación de DOM Teleportation y ergonomía de altura (92vh).
- [x] **Agenda "Liquid Motion Healthcare"**: Motor de animaciones y segmentación horaria visual.
- [x] **Smart Weekly Sync**: Refactorización responsiva para visualización dinámica (3/7 días).
- [x] **Smart Drag & Drop**: Motor de reubicación manual asistida para vista mensual, con limpieza de colisiones lógicas.
- [x] **Admin WebApp Transition**: Integración de ajustes en barra de navegación inferior móvil.
- [x] **Actualización Documentación v4.2.0**: Sincronización total de manuales técnicos.

## 🚀 Próximos Pasos (Roadmap)
- [x] **Candados de Negocio**: Implementar validación de columna `activo` en `negocios.dat` para bloqueo de suscripción.
- [ ] **Automatización de Recordatorios**: Finalizar el script backend para envío masivo vía WhatsApp/Email.
- [ ] **Sincronización Bidireccional Google**: Refinar la descarga de eventos externos hacia SDM.
- [ ] **Firma Digital**: Módulo de consentimiento informado en tabletas.
- [x] **Integración de Cornerstone.js en Visor PACS**:
    - **Objetivo**: Reemplazar los mockups HTML de herramientas de anotación (Medir, Ángulo, ROI, Texto, Polígono) con el motor real de `@cornerstonejs/tools`.
    - **Detalles Técnicos**: Cargar imágenes DICOM a través de `cornerstoneWADOImageLoader`, inicializar la librería central y habilitar herramientas de anotación que analicen la metadata en vivo (distancias en mm, densidades Hounsfield) sin bloquear el *Pan* / *Zoom* nativo.
- [ ] **Procesamiento e Integración de Catálogos Oficiales Faltantes**:
    - [x] `CAT_CIF` (Clasificación Internacional del Funcionamiento)
    - [ ] `CAT_MATERIAL_CURACION`
    - [ ] `CAT_INSTRUMENTAL_EQUIPO_MEDICO`
    - [ ] `CAT_MEDICAMENTOS`
    - [ ] `CAT_VIA_ADMINISTRACION`
    - [ ] `CAT_LENGUAS_INDIGENAS`
    - [x] `CAT_RELIGION`
    - [x] `CAT_NACIONALIDADES`

## 🛠️ Optimización Técnica
- [ ] **LocalStorage Cache**: Implementar caché local para acelerar la carga de la agenda.
- [ ] **Compresión de Activos**: Minificar JS/CSS para producción.

---
*GEISABPA - Roadmap v4.2.0 (Liquid Motion Edition)*
