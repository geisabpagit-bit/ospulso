# Módulo de Resumen Ejecutivo Semanal (Finanzas y Operación)

## 1. Visión General
El módulo de **Resumen Ejecutivo Semanal** (`views/resumen_ejecutivo.pl` y su backend `api/resumen_ejecutivo_api.pl`) provee al **Administrador de Organización** y al **Administrador Global** un centro de control analítico de alto nivel diseñado para juntas directivas, comités de operación y supervisión de caja. A diferencia del dashboard operativo tradicional, este módulo se enfoca en métricas finas: comportamiento semanal comparativo, segregación estricta entre caja real física y convenios públicos (CXC Estado), auditoría de medios de pago, demanda por departamentos clínicos y certificación forense de calidad de datos.

---

## 2. Gobernanza de Acceso (RBAC)
- **Roles Permitidos**: `Administrador Organizacion` y `Administrador Global`.
- **Capa de Frontend**: El elemento de navegación reside dentro del acordeón de **Finanzas** en [utils/sub_sidebar.pl](file:///c:/xampp/htdocs/ospulso/utils/sub_sidebar.pl) (`#c-finanzas`), destacado con el badge "Semanal". En `views/resumen_ejecutivo.pl`, roles no autorizados son bloqueados mediante `render_acceso_denegado(...)`.
- **Capa de Backend**: [api/resumen_ejecutivo_api.pl](file:///c:/xampp/htdocs/ospulso/api/resumen_ejecutivo_api.pl) exige sesión activa con rol administrativo y limita los datos automáticamente a la organización asignada (`ID_NEGOCIO`).

---

## 3. Fuentes de Datos Canónicas y Manejo de CLUE vs Organización Privada
De estricto apego a la arquitectura financiera del sistema:
- `dat/folios_recibos_privados.dat`: Fuente canónica de ingresos en ventanilla cobrados efectivamente.
- `dat/folios_recibos_publicos.dat`: Registro de órdenes de convenio público con subsidio municipal al 100% (Cuentas por Cobrar CXC Estado).
- `dat/catalogos_CLUE/[CLUE]/contadores_*.dat` (o por ID de organización si no tiene CLUE): Validación de contadores y secuencia de folios.
- `dat/negocios.dat`: Identificación de la organización matriz, sucursales dependientes, razón social y columna 18 (`clues`).

### 3.1. Diferenciación Arquitectónica: CLUE Oficial vs Organización Única / Privada
1. **Organización con CLUE (SSA)**: Entidades registradas ante la Secretaría de Salud de México cuentan con clave alfanumérica oficial (ej. `QTSMP000116`). En este escenario, el reporte acredita la clave CLUE oficial en membretes, valida contadores bajo la ruta de catálogos CLUE y evalúa convenios gubernamentales/municipales.
2. **Organización Única o Privada sin CLUE**: Consultorios, policlínicas, consultorios dentales o centros de especialidades privadas no siempre poseen o requieren CLUE. El backend detecta si la columna 18 de `negocios.dat` está vacía o contiene marcas de no aplicación (`-`, `0`, `No aplica`), identificando a la entidad formalmente por su `id_empresa` ("ID Organización: XXXXXX").
3. **Adaptación Dinámica del Prompt y Recomendaciones**: Cuando una organización no presenta órdenes de subsidio público (CXC Municipio = $0), el motor analítico ajusta los ejes estratégicos hacia convenios empresariales privados, paquetes de salud preventivos y fidelización de pacientes particulares, evitando cuestionamientos descontextualizados sobre convenios municipales.

---

## 4. Arquitectura de Endpoints (`api/resumen_ejecutivo_api.pl`)

| Parámetro | Tipo | Descripción |
|---|:---:|---|
| `tipo_periodo` | `GET` | *(Opcional)* Tipo de granularidad: `dia`, `semana` (default), `mes`, `ano`. |
| `periodo_val` | `GET` | *(Opcional)* Valor del periodo (ej. `2026-10-18` para día, `2026-W42` para semana, `2026-10` para mes, `2026` para año). Si se omite, calcula el periodo más reciente con actividad. |
| `id_empresa` | `GET` | *(Opcional)* ID del negocio a auditar (solo Administrador Global; para Administrador de Organización se fuerza el ID de su sesión). |

### Estructura de Respuesta JSON:
```json
{
  "status": "ok",
  "id_empresa": "723800",
  "nombre_negocio": "CLINICA MEDICA DE ESPECIALIDADES JUAN PABLO II",
  "clue": "QTSMP000116",
  "tipo_periodo": "semana",
  "periodo_activo": "2026-W42",
  "periodo_previo": "2026-W41",
  "dias_disponibles": ["2026-10-19", "2026-10-18", ...],
  "semanas_disponibles": ["2026-W43", "2026-W42", "2026-W41"],
  "meses_disponibles": ["2026-10", "2026-09", ...],
  "anos_disponibles": ["2026"],
  "kpis": {
    "flujo_privado": 311420.57,
    "cargos_publicos": 41057.00,
    "total_recibos": 281,
    "recibos_privados": 189,
    "recibos_publicos": 92,
    "ticket_prom_privado": 1647.73,
    "ticket_prom_publico": 446.27,
    "crec_ingresos_pct": "97.8",
    "crec_recibos_pct": "33.2",
    "calidad_datos_pct": 100
  },
  "desglose_cronologico": [...],
  "elemento_pico": { "clave": "2026-10-18", "etiqueta": "2026-10-18", "subetiqueta": "Domingo", "total_monto": 67665.00 },
  "medios_pago": [...],
  "deptos_priv": { ... },
  "deptos_pub": { ... },
  "markdown_export": "# INFORME EJECUTIVO..."
}
```

---

## 5. UI y Experiencia Ejecutiva (Estándares AGENTS.md)
- **Separación Estricta de Estilos (CSS)**: Cero bloques `<style>` en línea en `views/resumen_ejecutivo.pl`. Todas las clases ejecutivas (`.kpi-card-exec`, `.temporal-pill-btn`, `.table-executive`, `.recom-card-exec`) y reglas `@media print` residen en la hoja mandante `css/ospulso_master_v2.css`.
- **Diferenciación Visual Estricta (Régimen Mixto vs Organización Única / Privada)**:
  - **Insignias de Régimen**: Despliegue de distintivo dinámico en cabecera: `Régimen Mixto (Privado + Convenio Público)` en cian/azul para entidades con CLUE/órdenes públicas, versus `Régimen 100% Privado (Caja Directa)` en verde esmeralda para consultorios/clínicas sin convenio público.
  - **Hero KPIs Adaptativos**: En organizaciones únicas o sin subsidio público, la tarjeta `CXC ESTADO / MUNICIPIO` se oculta por completo (`display: none`), reconfigurando la grilla a 2 columnas equilibradas (`INGRESOS REALES` y `TOTAL INGRESOS GENERADOS` con origen 100% pacientes privados).
  - **Tabla de Comportamiento Cronológico Inteligente**:
    - Si tiene convenio público: Renderiza las 9 columnas clásicas (`Periodo | Detalle | Rec. Priv | Caja Priv | Rec. Púb | Fact. Mun | Total Rec | Total Recaudado | % Aporte`).
    - Si es Organización Única privada: Suprime las columnas de órdenes públicas y redundancias, mostrando 6 columnas claras y relevantes: `Periodo / Fecha | Detalle | Recibos Cobrados | Total Cobrado en Caja | Ticket Promedio | % Aporte`.
  - **Demanda por Departamentos**: Si no hay órdenes públicas, se suprimen los badges de órdenes públicas y se muestra una métrica consolidada de servicios privados sin ruido visual.
- **Herramienta IA (Prompt Detallado de Auditoría Hospitalaria Senior)**: Botón *"Copiar Prompt para IA (Claude / ChatGPT / Gamma)"* que inyecta en el portapapeles un prompt analítico completo y no solo datos brutos, contextualizado al régimen de la organización.
- **Modo Impresión / PDF Formal (Estándar Editorial de Alta Dirección)**:
  - **Ocultamiento de Controles**: La barra interactiva `#cardControlesPantalla` (`.no-print`) desaparece automáticamente en papel o PDF.
  - **Membrete Formal Institucional**: `.print-header-executive` imprime la cabecera OSPulso con nombre de la institución, CLUE u Organización ID, régimen operativo, periodo de dictamen y fecha de emisión.
  - **Preservación de Rejillas Horizontales**: Reglas flexbox forzadas en `@media print` (`.row-cols-md-2`, `.row-cols-md-3`, `.row-cols-md-4`, `.col-lg-6`) para impedir que Chrome colapse verticalmente las tarjetas de KPIs en hojas infinitas.
  - **Pie de Certificación y Firmas**: `.print-footer-executive` añade al calce del informe las tres firmas institucionales: *Responsable de Caja / Finanzas*, *Dirección Médica / Titular* y *Auditoría Suite OSPulso*, con control estricto de no fragmentación (`page-break-inside: avoid;`).

