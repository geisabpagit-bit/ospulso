# Módulo de Resumen Ejecutivo Semanal (Finanzas y Operación)

## 1. Visión General
El módulo de **Resumen Ejecutivo Semanal** (`views/resumen_ejecutivo.pl` y su backend `api/resumen_ejecutivo_api.pl`) provee al **Administrador de Organización** y al **Administrador Global** un centro de control analítico de alto nivel diseñado para juntas directivas, comités de operación y supervisión de caja. A diferencia del dashboard operativo tradicional, este módulo se enfoca en métricas finas: comportamiento semanal comparativo, segregación estricta entre caja real física y convenios públicos (CXC Estado), auditoría de medios de pago, demanda por departamentos clínicos y certificación forense de calidad de datos.

---

## 2. Gobernanza de Acceso (RBAC)
- **Roles Permitidos**: `Administrador Organizacion` y `Administrador Global`.
- **Capa de Frontend**: El elemento de navegación reside dentro del acordeón de **Finanzas** en [utils/sub_sidebar.pl](file:///c:/xampp/htdocs/ospulso/utils/sub_sidebar.pl) (`#c-finanzas`), destacado con el badge "Semanal". En `views/resumen_ejecutivo.pl`, roles no autorizados son bloqueados mediante `render_acceso_denegado(...)`.
- **Capa de Backend**: [api/resumen_ejecutivo_api.pl](file:///c:/xampp/htdocs/ospulso/api/resumen_ejecutivo_api.pl) exige sesión activa con rol administrativo y limita los datos automáticamente a la organización asignada (`ID_NEGOCIO`).

---

## 3. Fuentes de Datos Canónicas
De estricto apego a la arquitectura financiera del sistema:
- `dat/folios_recibos_privados.dat`: Fuente canónica de ingresos en ventanilla cobrados efectivamente.
- `dat/folios_recibos_publicos.dat`: Registro de órdenes de convenio público con subsidio municipal al 100% (Cuentas por Cobrar CXC Estado).
- `dat/catalogos_CLUE/QTSMP000116/contadores_*.dat`: Validación de contadores y secuencia de folios.
- `dat/negocios.dat`: Identificación de la clínica, razón social y clave CLUE.

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
- **Separación Estricta de Estilos (CSS)**: Cero bloques `<style>` en línea en `views/resumen_ejecutivo.pl`. Todas las clases ejecutivas (`.kpi-card-exec`, `.temporal-pill-btn`, `.table-executive`, etc.) y reglas `@media print` residen en la hoja mandante `css/ospulso_master_v2.css`.
- **Selector Multi-Temporal Dinámico**: Píldoras de selección instantánea para alternar entre **Día**, **Semana**, **Mes** y **Año**, adaptando la tabla cronológica y el elemento pico automáticamente.
- **Herramienta IA (Exportación 1 Clic)**: Botón *"Copiar para IA (Gamma / Notion)"* que inyecta en el portapapeles el markdown pre-estructurado del periodo activo para crear presentaciones directivas en segundos.
- **Modo Impresión / PDF**: Estilos `@media print` que suprimen el sidebar y barras de navegación, dejando un informe membretado limpio.

