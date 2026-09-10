# Módulos Complementarios y Especializados (SDM / OSPulso 2.0)

## 1. Visión General
Este documento agrupa la especificación de los módulos complementarios y especializados integrados en la plataforma OSPulso / SDM.

---

## 2. Especificación por Módulo

### 2.1 Agenda y Citas Médicas (`views/agenda_main.pl`)
- Administración de calendario por médico tratante, especialidad y consultorio.
- Vistas disponibles: Principal (`agenda_main.pl`), Lista (`agenda_vista_lista.pl`), Semanal (`agenda_vista_semanal.pl`) y Mensual (`agenda_vista_mensual.pl`).

### 2.2 Quirófano Kanban (`views/quirofano_kanban.pl`)
- Tablero visual de flujo de cirugías en tiempo real.
- Estados: *Programada*, *En Preparación*, *En Quirófano*, *Recuperación* y *Alta Quirúrgica*.

### 2.3 Odontograma SPA (`js/odontograma_spa.js`)
- Lienzo gráfico interactivo sobre HTML5 Canvas para odontología.
- Marcación de hallazgos (caries, endodoncias, extracciones, implantes) con nomenclatura internacional FDI.

### 2.4 Mapa de Módulos del Sistema
- **Dashboard / Inicial**: `views/inicial.pl`, `views/render_dashboard_principal.pl`.
- **Caja Rápida**: `views/generar_recibo.pl`.
- **Catálogo Universal**: `views/manage_catalogo_universal.pl`.
- **Expediente Clínico & Consultas**: `views/render_expediente_clinico.pl`, `views/render_consultas.pl`.
- **Visor Médico / PACS**: `views/render_visor_medico.pl`.
- **Finanzas**: `views/finanzas.pl`, `views/estado_cuenta.pl`.
