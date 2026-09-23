# Guía de Estilo, Tokens de Diseño y Componentes UI (SDM / OSPulso 2.0)

## 1. Paleta de Colores y Tokens CSS

La interfaz utiliza variables de color CSS alineadas con la estética clínica Medentia Aura:

```css
:root {
    --md-blue-deep: #0A2A66;      /* Azul Profundo Institucional */
    --md-teal-clinical: #19B7A5;  /* Teal Clínico Primario */
    --md-teal-dark: #0D9488;      /* Teal Oscuro para Bordes */
    --md-accent-gold: #F59E0B;    /* Dorado de Énfasis / Estado */
    --md-bg-light: #F8FBFF;       /* Fondo Claro Medentia Aura */
    --md-surface: #FFFFFF;        /* Superficie de Tarjetas */
}
```

---

## 2. Componentes UI Estandarizados

1. **Campos de Entrada Armor (`.custom-input-caja`, `.diamond-input-armor`)**:
   - Fondo `#F8FBFF`, bordes suavizados `border-radius: 1rem`, foco reactivo con anillo `rgba(25, 183, 165, 0.15)`.
2. **Botones de Acción Standard (`.btn-mobile-standard`, `.btn-mobile-action`)**:
   - Garantizan un **Touch Target mínimo de 48px** para interacción táctil fluida en dispositivos móviles.
3. **Tarjetas Adaptables de Carrito y Resumen (`.cart-item-card`)**:
   - Estilo flexible con bordes `#e9ecef`, sombras `shadow-sm` y hover animado.

---

## 3. Estilo de Barra de Exportación DataTables

Las tablas del sistema incorporan controles de exportación estandarizados estilizados según los tokens de la guía de estilo:
- **Excel**: Exportación limpia a XLSX.
- **PDF**: Generación de reportes PDF vectoriales.
- **Imprimir**: Formato plano libre de elementos de control `.no-print`.

---

## 4. Normas de Responsividad Móvil (`css/sdm_mobile_standards.css`)

- Utilizar `.container-mobile-flush` en contenedores principales para comprimir márgenes estorbosos en resoluciones menores a 768px.
- Utilizar `.mobile-edge-to-edge` para expandir tarjetas al 100% de la pantalla cuando se requiera espacio máximo.

### 4.1 Unicidad del Botón Hamburguesa de Menú Lateral
- **Fuente Única Canónica**: El botón de alternancia del menú desplegable de navegación móvil (botón hamburguesa `<button class="btn btn-menu-toggle-inline me-2 d-lg-none" onclick="toggleSidebar()">`) reside exclusivamente dentro del componente del encabezado global ([`utils/sub_header.pl`](file:///c:/xampp/htdocs/ospulso/utils/sub_header.pl)).
- **Prohibición**: Queda prohibido duplicar o renderizar botones adicionales de alternancia de menú dentro de los encabezados de módulo o tarjetas secundarias (ej. en `.diamond-header-compact` o `.profile-hero`).

### 4.2 Identidad del Encabezado Global (`utils/sub_header.pl`)
- **Logo Marca Vectorizado Sin Solapamiento**: La animación de la línea EKG en el SVG vectorial de `OsPulso` se despliega a la derecha de la palabra "Pulso" (`d="M108 32 H112 L118 18 L124 38..."`) evitando la colisión o encimado de trazos sobre las letras del nombre.
- **Multilínea de Organización & CLUE/ID**: El nombre del establecimiento se renderiza en Línea 1 (`$nombre_org` en negrita), mientras que en Línea 2 se despliegan de forma subordinada los metadatos estructurados `CLUE : [CLUES]  ID : [SUCURSAL]`.

---

## 5. Tarjetas KPI Acrílicas Centradas (`.kpi-acrilico`)

Todas las tarjetas KPI superiores exhibidas en el Dashboard Principal (`views/inicial.pl` / `views/render_dashboard_principal.pl`) y en Finanzas / Corte de Caja (`views/finanzas.pl`) mantienen **estricta consistencia visual de diseño**:
1. **Estructura Vertical Centrada**:
   - Ícono superior centrado (`.kpi-icono` con tamaño responsivo ~1.6rem e ícono Bootstrap adhoc).
   - Título en mayúsculas centrado (`.kpi-titulo` con `text-truncate`).
   - Valor en negrita centrado (`.kpi-valor` con `counter-up`).
2. **Disposición Grid en Fila Única**:
   - Utilizan una distribución de 5 columnas en escritorio/tableta (`row row-cols-2 row-cols-sm-3 row-cols-md-5`) para garantizar que las 5 métricas caben en una sola fila continua sin desbordes.
