# SDM Viewer
## Visor Médico Modular SPA
### Arquitectura Perl + JavaScript CDN

---

# Índice

1. Introducción
2. Objetivo General
3. Objetivos Específicos
4. Alcance del Proyecto
5. Características Principales
6. Formatos Soportados
7. Arquitectura General
8. Arquitectura Frontend
9. Arquitectura Backend Perl
10. Flujo General del Sistema
11. Flujo de Carga de Archivos
12. Flujo de Renderizado
13. Renderizado por Tipo de Archivo
14. Librerías Utilizadas
15. Librerías Perl
16. Librerías JavaScript
17. Dependencias CDN
18. Estructura de Directorios
19. Diseño UI/UX
20. Módulos del Sistema
21. Módulo Viewer
22. Módulo de Herramientas
23. Módulo de Exportación
24. Módulo de Seguridad
25. Sistema SPA
26. Comunicación AJAX
27. Gestión de Archivos
28. Metadatos
29. Exportación PDF/PNG/JPEG
30. Compatibilidad de Navegadores
31. Requisitos del Servidor
32. Requisitos Frontend
33. Estrategia de Escalabilidad
34. Consideraciones Médicas
35. Consideraciones HIPAA/RGPD
36. Roadmap Futuro
37. Riesgos Técnicos
38. Conclusión

---

# 1. Introducción

SDM Viewer es un visor médico modular SPA (Single Page Application) diseñado para visualizar, analizar y exportar estudios médicos e imágenes digitales directamente desde navegador utilizando tecnologías web modernas.

El sistema está diseñado para:

- ser ligero
- portable
- escalable
- compatible con VPS básicos
- minimizar dependencias complejas

La arquitectura divide responsabilidades entre:

- Backend Perl ligero
- Frontend JavaScript especializado en visualización médica

---

# 2. Objetivo General

Desarrollar un visor médico web modular capaz de visualizar:

- DICOM
- NIfTI
- JPG
- PNG
- SVG

mediante una SPA moderna compatible con navegadores actuales.

---

# 3. Objetivos Específicos

- Visualizar imágenes médicas DICOM
- Visualizar resonancias NIfTI
- Soportar imágenes estándar
- Permitir mediciones y anotaciones
- Exportar estudios e imágenes
- Mantener arquitectura ligera
- Evitar dependencias complejas en servidor
- Permitir futura integración PACS

---

# 4. Alcance del Proyecto

El proyecto incluye:

## Incluye

- Viewer médico web
- Herramientas interactivas
- Renderizado Canvas/WebGL
- Exportación PDF
- Exportación PNG/JPEG
- SPA sin recargas
- Backend Perl CGI

## No incluye inicialmente

- PACS completo
- IA diagnóstica
- Segmentación avanzada
- Reconstrucción médica avanzada
- Machine Learning

---

# 5. Características Principales

## Viewer Médico

- Zoom
- Pan
- Window/Level
- Rotación
- Inversión
- Ajuste de contraste

## Herramientas

- Mediciones
- Ángulos
- Flechas
- Texto
- ROI
- Polígonos

## Exportación

- PDF
- PNG
- JPEG
- JSON

---

# 6. Formatos Soportados

| Formato | Tipo | Soporte |
|---|---|---|
| .dcm | DICOM | Completo |
| .nii | NIfTI | Completo |
| .nii.gz | NIfTI comprimido | Completo |
| .jpg | Imagen | Completo |
| .jpeg | Imagen | Completo |
| .png | Imagen | Completo |
| .svg | Vectorial | Completo |
| .stl | Escaneos 3D | Completo |
| .obj | Escaneos 3D | Completo |
| .tiff | Histología | Completo |
| .ply | Escaneos 3D | Completo |

| Librería | Uso |
| Cornerstone | CBCT/DICOM |
| vtk.js | volumétrico |
| Three.js | STL dental |
| dcmjs | metadata |

---

# 7. Arquitectura General

```text
┌─────────────────────────┐
│      Frontend SPA       │
│ Bootstrap + JS Viewer   │
└──────────┬──────────────┘
           │ AJAX/JSON
┌──────────▼──────────────┐
│      Backend Perl       │
│ CGI + JSON + Upload     │
└──────────┬──────────────┘
           │
┌──────────▼──────────────┐
│    Filesystem Storage   │
└─────────────────────────┘
```

---

# 8. Arquitectura Frontend

## Tecnologías

- HTML5
- CSS3
- Bootstrap 5
- JavaScript ES6
- Canvas
- WebGL

## Responsabilidades

- Renderizado
- Herramientas médicas
- Navegación SPA
- Interfaz
- Exportaciones cliente

---

# 9. Arquitectura Backend Perl

## Responsabilidades

- Recepción de archivos
- Validación
- Sesiones
- Seguridad
- Entrega JSON
- Logs
- Exportaciones servidor

## Filosofía

El backend NO procesa imágenes médicas complejas.

---

# 10. Flujo General del Sistema

```text
Usuario carga archivo
        ↓
Perl valida archivo
        ↓
Frontend recibe JSON
        ↓
JS renderiza estudio
        ↓
Usuario interactúa
        ↓
Exportación opcional
```

---

# 11. Flujo de Carga de Archivos

## Métodos soportados

- Drag & Drop
- Input file
- AJAX upload

## Validaciones

- Extensión
- Tamaño
- MIME type

---

# 12. Flujo de Renderizado

## DICOM

dcmjs → Cornerstone

## NIfTI

nifti-reader-js → vtk.js

## JPG/PNG/SVG

Canvas/Image API

---

# 13. Renderizado por Tipo de Archivo

## DICOM

- CornerstoneJS
- CornerstoneTools

## NIfTI

- vtk.js
- nifti-reader-js

## JPG/PNG

- HTML5 Canvas

## SVG

- SVG inline renderer

---

# 14. Librerías Utilizadas

---

# 15. Librerías Perl

## Core

```perl
use CGI;
use JSON;
use MIME::Base64;
use File::Basename;
use File::Path qw(make_path);
```

## Opcionales

```perl
use CGI::Session;
```

---

# 16. Librerías JavaScript

| Librería | Función |
|---|---|
| Bootstrap | UI |
| Axios | AJAX |
| Cornerstone | DICOM |
| CornerstoneTools | Herramientas |
| dcmjs | Parseo DICOM |
| vtk.js | MRI 3D |
| nifti-reader-js | NIfTI |
| jsPDF | PDF |
| html2canvas | Capturas |

---

# 17. Dependencias CDN

## Bootstrap

```html
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
```

## Axios

```html
<script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
```

## Cornerstone

```html
<script src="https://unpkg.com/@cornerstonejs/core"></script>
```

## CornerstoneTools

```html
<script src="https://unpkg.com/@cornerstonejs/tools"></script>
```

## dcmjs

```html
<script src="https://unpkg.com/dcmjs"></script>
```

## vtk.js

```html
<script src="https://unpkg.com/vtk.js"></script>
```

## NIfTI

```html
<script src="https://cdn.jsdelivr.net/npm/nifti-reader-js/dist/nifti-reader.js"></script>
```

## jsPDF

```html
<script src="https://cdn.jsdelivr.net/npm/jspdf"></script>
```

## html2canvas

```html
<script src="https://cdn.jsdelivr.net/npm/html2canvas"></script>
```

---

# 18. Estructura de Directorios

```text
/sdm-viewer
│
├── /cgi-bin
│   ├── upload.cgi
│   ├── api.cgi
│   └── auth.cgi
│
├── /assets
│   ├── /css
│   ├── /js
│   ├── /img
│   └── /vendor
│
├── /storage
│   ├── /dicom
│   ├── /nii
│   ├── /images
│   └── /temp
│
├── /exports
│
└── index.html
```

---

# 19. Diseño UI/UX

## Layout

```text
┌──────────────────────────────┐
│ Navbar                       │
├──────────┬───────────────────┤
│ Sidebar  │ Viewer            │
│ Estudios │ Canvas/WebGL      │
├──────────┴─────────┬─────────┤
│ Tools              │ Metadata│
└────────────────────┴─────────┘
```

---

# 20. Módulos del Sistema

- Upload
- Viewer
- Tools
- Metadata
- Export
- Logs
- Auth

---

# 21. Módulo Viewer

## Responsabilidades

- Render
- Zoom
- Pan
- Navegación slices
- Contraste

---

# 22. Módulo de Herramientas

## Herramientas

- Length
- Angle
- ROI
- Arrow
- Text
- Polygon

---

# 23. Módulo de Exportación

## Formatos

- PDF
- PNG
- JPEG
- JSON

---

# 24. Módulo de Seguridad

## Validaciones

- MIME
- Extensión
- Sesiones
- Tokens

## Recomendaciones

- HTTPS obligatorio
- Sanitización
- Límites upload

---

# 25. Sistema SPA

## Navegación

```javascript
history.pushState()
```

## Objetivos

- Sin recargas
- Mejor UX
- Mayor velocidad

---

# 26. Comunicación AJAX

## Tecnología

Axios

## Formato

JSON

---

# 27. Gestión de Archivos

## Flujo

```text
Upload
→ Validación
→ Storage
→ JSON Response
→ Viewer
```

---

# 28. Metadatos

## DICOM

- PatientName
- StudyDate
- Modality
- SeriesDescription

## NIfTI

- Dimensiones
- Voxels
- Orientation

---

# 29. Exportación PDF/PNG/JPEG

## Tecnologías

- jsPDF
- html2canvas

---

# 30. Compatibilidad de Navegadores

| Navegador | Compatible |
|---|---|
| Chrome | Sí |
| Edge | Sí |
| Firefox | Sí |
| Safari | Parcial |

---

# 31. Requisitos del Servidor

## Backend

- Perl 5.x
- Apache/Nginx
- CGI habilitado

## Recursos mínimos

- 2 GB RAM
- 2 CPU
- 20 GB SSD

---

# 32. Requisitos Frontend

## Navegador moderno

- WebGL
- Canvas
- ES6

---

# 33. Estrategia de Escalabilidad

## Futuro

- PACS
- DICOMweb
- FHIR
- IA
- Segmentación

---

# 34. Consideraciones Médicas

El sistema NO reemplaza diagnóstico médico profesional.

---

# 35. Consideraciones HIPAA/RGPD

## Recomendaciones

- HTTPS
- Logs
- Control acceso
- Cifrado
- Auditoría

---

# 36. Roadmap Futuro

## Fase 1

- Viewer básico

## Fase 2

- Herramientas médicas

## Fase 3

- PACS

## Fase 4

- IA médica

---

# 37. Riesgos Técnicos

| Riesgo | Impacto |
|---|---|
| Archivos grandes | Alto |
| Navegadores antiguos | Medio |
| MRI volumétrico | Alto |
| WebGL limitado | Medio |

---

# 38. Conclusión

SDM Viewer propone una arquitectura moderna, modular y ligera basada en:

- Perl estándar
- JavaScript moderno
- Renderizado cliente
- CDN gratuitos
- SPA médica

La solución minimiza dependencias de servidor y maximiza compatibilidad, rendimiento y escalabilidad futura.

---

# 39. Hito de Version (v1.0.0 - Pre-final)

La Version 1.0.0 del MedentOs Viewer establece el sistema como una Single Page Application (SPA) robusta. Se integraron con exito:
- **Interfaz Bento/Diamond**: Panel lateral de estudios, navbar compacto, y carrusel inferior (o lateral refactorizado) limpio con scrollbars invisibles.
- **Anotaciones y Herramientas**: Integracion total de CornerstoneTools (Medicion, Angulo, Poligono) compatibles con caracteres UTF-8 en sus inputs.
- **Exportacion y Reportes**: Reportes PDF y capturas PNG de alta calidad sin desbordamiento de imagenes.
- **Seguridad**: Scripts API blindados con LF line-endings para prevenir errores 500 en servidores cPanel/Linux, y sanitizacion robusta de payloads.

Esta version garantiza funcionalidad en produccion.
