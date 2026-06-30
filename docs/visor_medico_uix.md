# ✅ Checklist Modular — Refactor Premium Healthcare

## 1. Navbar Clínico
- [ ] Implementar fondo `--md-blue-deep` con gradiente `bg-medentia-gradient`.
- [ ] Añadir logo MedentIA y título “VIEWER”.
- [ ] Incluir accesos rápidos: Agenda, PACS, Exportar.
- [ ] Perfil profesional con avatar y nombre del médico.
- [ ] Responsividad: menú hamburguesa en móvil.

## 2. Panel Izquierdo — Estudios
- [ ] Tarjetas `card-medentia` para cada estudio.
- [ ] Miniaturas con borde `--md-gray-soft` y hover `--shadow-md`.
- [ ] Filtro superior con icono de búsqueda y placeholder “Buscar estudios…”.
- [ ] Colapsado automático en pantallas pequeñas.

## 3. Área Central — Visor DICOM
- [ ] Fondo `--md-white-clinical` y bordes suaves.
- [ ] Herramientas flotantes: Zoom, Pan, ROI, Medir, Ángulo, Texto, Polígono, Borrar.
- [ ] Botones estilo pill con glow `--md-cyan-ia`.
- [ ] Feedback visual activo (botón verde al seleccionar herramienta).
- [ ] Barra inferior con modos: NORMAL, INVERTIR, HUESO, B/N, Reset.

## 4. Panel Derecho — Herramientas y Calibradores
- [ ] Sección “HERRAMIENTAS” con botones verticales.
- [ ] Sliders para Zoom, Contraste y Brillo con valores visibles.
- [ ] Colores semánticos: azul para activo, gris para inactivo.
- [ ] Transiciones suaves al ajustar calibradores.

## 5. Iconografía y Micro‑interacciones
- [ ] Íconos lineales pastel‑tecnológicos (azul, menta, lavanda).
- [ ] Animaciones sutiles: check dibujado, ROI iluminado.
- [ ] Íconos HDPI para máxima nitidez.

## 6. Responsividad Total
- [ ] Mobile first: tarjetas apiladas, scroll suave.
- [ ] Tablet: grid modular con paneles expandibles.
- [ ] Desktop: distribución 3 columnas (izq‑centro‑der).
- [ ] Ajuste automático de tipografía y espaciado.

## 7. Accesibilidad y UX
- [ ] Contraste AA+ entre texto y fondo.
- [ ] Etiquetas ARIA en botones y sliders.
- [ ] Feedback visual y auditivo opcional.
- [ ] Modo oscuro opcional con inversión de paleta.



## Hito v1.0.0 Pre-final
El sistema de Interfaz de Usuario para el visor medico ha alcanzado la version 1.0.0 de forma estable.
- Se establecio el carrusel en formato horizontal en la barra lateral, eliminando doble scroll y colisiones (clipping) de botones de borrado.
- Sincronizacion total SPA al eliminar recursos.
