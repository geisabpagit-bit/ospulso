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

Todas las tarjetas KPI superiores exhibidas en el Dashboard Principal (`views/inicial.pl` / `views/render_dashboard_principal.pl`) para los roles Recepcionista, Médico y Administrador, así como en Finanzas / Corte de Caja (`views/finanzas.pl`), mantienen **estricta consistencia visual y acabado acrílico 3D premium**:
1. **Acabado Glassmorphism Acrílico Idéntico**:
   - Fondo de degradado translúcido: `linear-gradient(135deg, rgba(255, 255, 255, 0.55) 0%, rgba(255, 255, 255, 0.12) 100%)`.
   - Filtro de desenfoque de cristal profundo: `backdrop-filter: blur(16px)`.
   - Bisel especular cian luminoso: `border-top: 1.5px solid rgba(0, 255, 255, 0.7); border-left: 1.5px solid rgba(0, 255, 255, 0.5); border-bottom/right: 1px solid rgba(0, 255, 255, 0.15)`.
   - Iluminación 3D multidireccional con cuatro sombras internas (`inset 0px 4px 8px rgba(255, 255, 255, 0.85)`, `inset 0px -6px 10px rgba(0, 77, 77, 0.15)`, etc.) y sombra flotante (`0 15px 35px rgba(0, 0, 0, 0.16)`).
   - Micro-animación de elevación táctil en hover (`transform: translateY(-5px)`).
2. **Estructura Vertical Centrada**:
   - Ícono superior centrado (`.kpi-icono` con tamaño responsivo ~1.85rem e ícono adhoc con color semántico).
   - Título en mayúsculas centrado (`.kpi-titulo` en `Plus Jakarta Sans`, bold, `text-truncate`).
   - Valor numérico / monetario destacado (`.kpi-valor` en `Outfit`, 800 weight, con animación `counter-up` en una sola línea horizontal).
3. **Homogenización Financiera de Etiquetas**:
   - **Ingresos** (antes Cargos): Ícono `bi-arrow-down-circle` verde (`text-success`), calcula recaudación cobrada.
   - **Egresos** (antes Abonos): Ícono `bi-arrow-up-circle` rojo (`text-danger`), calcula erogaciones operativas desde `gastos.dat`.
4. **Gobierno y Visibilidad Condicional de "CxC Estado" por CLUE**:
   - La métrica **"CxC Estado"** (Cuentas por Cobrar de Pacientes Estado/Convenios) se muestra de forma **exclusiva y condicional si la organización cuenta con CLUE activo** registrado en `dat/negocios.dat`.
   - **Adaptabilidad de Fila Única**: Si la organización cuenta con CLUE (5 tarjetas activas: Citas Hoy, Pacientes, Ingresos, Egresos, CxC Estado), el contenedor aplica `row-cols-md-5`. Si la organización no cuenta con CLUE (4 tarjetas activas), el contenedor conmuta dinámicamente a `row-cols-md-4`, garantizando un despliegue armónico en una sola fila continua sin desbordes.
