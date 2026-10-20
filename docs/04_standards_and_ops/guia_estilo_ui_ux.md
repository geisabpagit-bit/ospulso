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

### 4.3 Fecha y Hora en Formato 24 Horas en Encabezado Global
- **Ubicación & Alineación**: Centrada de forma armónica directamente bajo el buscador de expediente `#globalSearch` en `utils/sub_header.pl`. Los elementos del navbar se alinean al top (`align-items-start`) con espaciado consistente (`gap-3`).
- **Formato Desktop**: `[Día de la semana], [Día] de [Mes] de [Año] • [HH:MM] hrs` (ej. `Jueves, 24 de Septiembre de 2026 • 14:14 hrs`).
- **Formato Móvil**: Formato compacto `[Día] [Mes corto] [Año] • [HH:MM] hrs` (ej. `24 Sep 2026 • 14:14 hrs`), garantizando legibilidad en pantallas táctiles sin desbordamientos.

### 4.4 Erradicación Estricta de Secciones `<style>` en Archivos `.pl`
- **Regla Mandatoria**: Queda estrictamente prohibida la presencia de etiquetas `<style>` dentro de cualquier archivo con extensión `.pl` (`views/*.pl`, `utils/*.pl`).
- **Hojas de Estilo Mandantes**: Todo estilo personalizado, animación o regla de diseño debe alojarse en los archivos CSS correspondientes (`css/ospulso_master_v2.css`, `css/agenda_diamond.css`, `css/theme_acrilico.css`).

### 4.5 Arquitectura Móvil Ultra Compacta del Encabezado y Gaveta Lateral
- **Encabezado en 2 Micro-Filas (`utils/sub_header.pl`)**:
  - En pantallas `<768px`, el header se desacopla del flujo horizontal de escritorio y conmuta a un contenedor vertical `.d-flex.d-md-none` de dos filas ultra-compactas:
    - **Fila 1 (Controles)**: Botón hamburguesa mini (32x32px `.btn-menu-toggle-mobile`), logo miniatura `.header-mobile-logo`, botón conmutador de perfil ultra-compacto `.btn-role-pill-mobile` (0.62rem) y avatar miniatura (30x30px `.avatar-diamond-mobile`).
    - **Fila 2 (Buscador y Tiempo)**: Input de búsqueda expandido al 100% (30px de alto, 0.72rem) y fecha/hora en una sola línea no rompible (`0.62rem`, `white-space: nowrap`) para evitar saltos indeseados.
- **Gaveta Lateral Izquierda (Drawer Móvil Premium) (`css/sub_sidebar.css` / `css/expediente_completo.css`)**:
  - En móviles (`@media (max-width: 991px)`), `.diamond-sidebar` opera como un offcanvas/drawer full-height ubicado estrictamente al `top: 0 !important;` y `left: 0 !important;` con altura `100vh`/`100dvh` y ancho adaptable `295px` (`max-width: 86vw`).
  - Permanece oculto en `transform: translateX(-100%)` y se desliza con animación fluida a `transform: translateX(0)` al activarse la clase `.show`, alineándose de forma impecable sin desajustes flotantes ni desfases de píxeles.
  - Posee borde redondeado hacia la derecha (`border-radius: 0 1.5rem 1.5rem 0`), acrílico satinado con `backdrop-filter: blur(25px)`, borde derecho turquesa clínico y sombra profunda (`box-shadow: 15px 0 45px rgba(10, 42, 102, 0.28)`).
  - La cortina `.sidebar-overlay` posee `z-index: 10490` con desenfoque de fondo y el drawer `z-index: 10500`, garantizando cierre inmediato al tocar el exterior o seleccionar cualquier módulo.
- **Hero del Paciente Anti-Distorsión en Expediente (`views/render_expediente_clinico.pl` / `css/expediente_completo.css`)**:
  - Encapsulado bajo `.expediente-hero-header` con gradiente médico profundo (`#0A2A66` a `#124A9E`), desacoplado de las reglas genéricas de `.bg-medentia-gradient` para erradicar el estiramiento elíptico anómalo de `.rounded-circle` en flex columns.
  - El avatar circular posee dimensiones fijas y controladas (`width: 44px; height: 44px; min-width: 44px; border-radius: 50%`) en móvil, alineado armónicamente con el nombre del paciente y chips demográficos visibles (`CURP`, `Edad`, `Sexo`) formateados con micro-píldoras satinadas (`.patient-hero-chip`).
- **Micro-Tipografía y Paddings Nulos/Mínimos en Dashboard Móvil**:
  - En `.sdm-content` y tarjetas KPI acrílicas, padding comprimido a `0.5rem 0.2rem` en móvil, con títulos KPI en `0.58rem` y valores en `1.05rem`.
  - Tarjetas de Citas en el Dashboard aplican `.appointment-card-mobile` con botones de acción compactos (`.btn-sm`, iconos en `me-1`) evitando botones gigantescos desproporcionados.

### 4.6 Homologación del Menú Lateral de Usuario (`#sdmSidebar`), Capas Z-Index y Avatar Polimórfico
- **Contenedor Flotante Estándar (`.mobile-sidebar`)**: El offcanvas de usuario `#sdmSidebar` en [`utils/sub_header.pl`](file:///c:/xampp/htdocs/ospulso/utils/sub_header.pl) adopta exactamente la misma arquitectura y clases visuales del menú responsivo de `index.html`:
  - Contenedor con borde turquesa clínico (`1.5px solid var(--md-teal-clinical)`), esquinas redondeadas (`border-radius: var(--radius-lg)`), fondo acrílico satinado con `backdrop-filter: blur(25px)`.
  - Botón de cierre cuadrado flotante `.btn-close-sidebar` (`width: 40px; height: 40px; border-radius: 12px;`) con ícono `bi-x-lg`.
  - Opciones de navegación con clase unificada `.sidebar-nav-link` (fondo blanco, borde `#e2e8f0`, hover con elevación sutil y borde turquesa).
  - Botón de cierre de sesión con estilo `.btn-solicitar-cita-mobile` adaptado con fondo semántico rojo peligroso (`background: #dc3545 !important;`).
- **Gobernanza de Capas (Z-Index Anti-Oclusión)**:
  - Para evitar que la cortina oscura de Bootstrap (`.offcanvas-backdrop` en `z-index: 105400`) tape y atrape al menú de usuario, `.offcanvas.mobile-sidebar` posee estrictamente `z-index: 105600 !important;`. El panel flota límpido y nítido por encima de la capa oscurecedora.
- **Avatar Polimórfico (`.avatar-diamond`)**:
  - El avatar preserva su contenedor canónico `class="avatar-diamond shadow-sm flex-shrink-0"`.
  - **Resolución Foto / Siglas**: Mediante [`utils/sub_header.pl`](file:///c:/xampp/htdocs/ospulso/utils/sub_header.pl), se consulta el ID de usuario en `dat/usuarios.dat` a partir de `$session_data->{usuario}` y se busca su registro en `dat/perfiles.dat`. Si existe `avatar_url` físico en el servidor, se renderiza la imagen `<img>`; en su ausencia, se generan de forma automática las iniciales en mayúscula envueltas en `.avatar-initials`.
- **Integridad Estructural en Vistas Privadas (`views/perfil.pl`)**:
  - Toda vista que requiera el sub-header DEBE encapsular su cuerpo dentro de `utils::sub_sidebar::render_sidebar(...)` y `utils::sub_sidebar::render_sidebar_footer()` finalizando con `render_bottom_nav(...)`, quedando totalmente prohibido el uso del obsoleto `utils/sub_footer.pl`.
  - [`utils/sub_header.pl`](file:///c:/xampp/htdocs/ospulso/utils/sub_header.pl) declara directamente en el `<head>` las funciones globales `window.toggleSidebar` y `window.toggleDesktopSidebar` para garantizar disponibilidad inmediata ante cualquier evento táctil o clic.
  - En [`utils/sub_edita_perfil.pl`](file:///c:/xampp/htdocs/ospulso/utils/sub_edita_perfil.pl), el botón de envío "Actualizar Perfil" se ubica en el paso final (tab Seguridad) a la derecha del botón "Anterior", y los campos de contraseña incorporan los atributos estándares de accesibilidad `autocomplete="current-password"` y `autocomplete="new-password"`.

### 4.7 Gobernanza del Menú Inferior Móvil y Estándar de Avatar en Perfil
- **Segregación RBAC en Barra Inferior Móvil (`utils/sub_bottom_nav.pl`)**:
  - El ícono del corazón (`<i class="bi bi-heart-pulse"></i>`, enlace a `render_consultas.pl`) está estrictamente restringido a nivel global para el rol **Médico**.
  - Para los demás perfiles operativos y administrativos (Administrador de Organización, Administrador Global, Recepcionista, Cajero, etc.), la barra inferior prescinde de la opción clínica manteniendo únicamente accesos a Inicio, Citas y Pacientes.
- **Unificación de Carga de Avatar en Perfil (`views/perfil.pl` / `utils/sub_edita_perfil.pl`)**:
  - Se erradica la duplicidad de componentes de subida de foto eliminando el bloque redundante en Panel 0 (Identidad de Acceso), permitiendo que los campos de datos ocupen el ancho completo.
  - La foto reside exclusivamente en la cabecera superior dentro de un **círculo perfecto** (`.profile-avatar-circle` con `aspect-ratio: 1/1`, `border-radius: 50%`, `92x92px`) con borde turquesa de 3px.
  - En presencia de foto, se renderiza con `object-fit: cover` garantizando cero deformaciones o distorsiones.
  - En ausencia de foto, se renderiza un ícono centrado `<i class="bi bi-person-fill"></i>`.
  - La interacción de cambio de fotografía se asiste con una insignia flotante `.avatar-badge-edit`.
- **Estándares y Límites para Subida de Foto**:
  - Formatos admitidos: JPG, JPEG, PNG y WebP.
  - Peso máximo: **2 MB**, con validación inmediata en frontend (`validarYPrevisualizarAvatar`) y validación en backend (`api/update_perfil.pl`).
- **Borde Turquesa Corporativo en Contenedores de Perfil**:
  - Todos los contenedores de `views/perfil.pl` (`.card-medentia-aura`, `.wizard-panel`, alertas informativas y previews de firma) portan de forma mandatoria el borde turquesa clínico corporativo (`border: 1.5px solid var(--md-teal-clinical)`).

### 4.8 Gobernanza del Menú Lateral Izquierdo (Expand / Collapse, Unificación de Controles y Responsividad)
- **Persistencia y Modos de Visualización (`utils/sub_sidebar.pl`, `css/sub_sidebar.css`, `js/sub_sidebar.js`)**:
  - **Modo Expandido (280px)**: Ancho por defecto en pantallas grandes ($\ge 992\text{px}$). Muestra avatares, textos descriptivos, chevrons y agrupaciones de menú accordion.
  - **Modo Compacto (80px)**: Activado mediante toggle de usuario. Persistido en `localStorage` con la clave `ospulso_sidebar_compact`.
- **Unificación de Controles y Erradicación de Redundancias**:
  1. **Control de Navbar Superior (`utils/sub_header.pl`) Exclusivo para Móviles y Tabletas (`d-lg-none`)**:
     - El botón de apertura lateral en el header reside únicamente para modos responsivos (`< 992px`), invocando `toggleSidebar()`. En escritorios ($\ge 992\text{px}$), se oculta por completo del navbar para evitar sobreabundancia de controles en la cabecera.
  2. **Botón Unificado en Cabecera del Sidebar (`#btnToggleDesktopSidebar`)**:
     - Ubicado en la cabecera del sidebar (`.sidebar-brand`). Tanto en modo expandido como en modo compacto, utiliza la **misma clase (`.btn-sidebar-nav-trigger`) y el mismo tamaño estandarizado (38x38px con `border-radius: 10px`)** que el botón que abre el menú.
     - En modo expandido: Se sitúa a la derecha del avatar (`ms-auto`) con ícono `bi-layout-sidebar-inset` y tooltip *"Colapsar menú (Alt+M)"*.
     - En modo compacto: Se centra armónicamente debajo del avatar (`margin: 0 auto;`) con ícono `bi-chevron-double-right` y tooltip flotante *"Expandir menú (Alt+M)"*, eliminando deformaciones o estilos de píldora divergentes.
  3. **Erradicación del Footer Toggle Redundante**:
     - Se eliminó el botón duplicado al pie del menú lateral (`.sidebar-compact-toggle-footer`), concentrando toda la interacción en el control superior y despejando el espacio útil vertical.
  4. **Atajo Universal de Teclado**: Presionar `Alt + M` alterna de forma inmediata entre el modo compacto y expandido (o despliega el drawer en móviles).
  5. **Aislamiento Estricto de la X de Cierre y Capa Traslúcida (Overlay)**:
     - La "X" de cierre (`.btn-sidebar-close-mobile`) y la capa de fondo traslúcida con desenfoque (`.sidebar-overlay`) son **exclusivas del modo Drawer en móviles y tabletas (< 992px)**.
     - En pantallas de escritorio ($\ge 992\text{px}$), tanto la "X" como el overlay están **estrictamente anulados** (`display: none !important; opacity: 0 !important; pointer-events: none !important;`). Se previene cualquier colisión en selectores CSS que pudiera forzar la visibilidad del botón de cierre en el modo colapsado o activar el oscurecimiento traslúcido de la pantalla.
- **Sincronización Visual Reactiva (`window.syncSidebarToggleVisuals`)**:
  - Unifica el estado de los íconos (`bi-layout-sidebar-inset` en expandido vs `bi-chevron-double-right` en compacto) y actualiza dinámicamente los tooltips y atributos de accesibilidad (`aria-label`, `data-sidebar-title`).
- **Gobernanza Responsiva Móvil y Tableta (< 992px)**:
  - El modo `.compact` (80px) queda **estrictamente deshabilitado** en pantallas táctiles y tabletas. En resoluciones `< 992px`, el menú opera exclusivamente como un Drawer offcanvas flotante (295px) con touch-targets de al menos 44px, fondo backdrop y auto-cierre al seleccionar cualquier sub-enlace.

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

---

## 6. Estándares Visuales de la Agenda Diamond (`views/agenda_main.pl`, `css/agenda_diamond.css`)

> **Arquitectura Unificada de 2 Hojas de Estilo**:
> - **Hoja Mandante Global (`css/ospulso_master_v2.css`)**: Centraliza tokens corporativos globales, jerarquía z-index y componentes universales compartidos como `#modalCita` (formulario, `.floating-label-premium`, `.dur-bar-premium`, slots horarios y `.ui-autocomplete`), utilizables tanto en Agenda como en Consultas Privadas.
> - **Hoja Especializada de Agenda (`css/agenda_diamond.css v4.3.0`)**: Centraliza exclusivamente el layout SPA, cabecera sticky, timeline diaria, carrusel semanal smart, vista mensual grid, mini-calendario lateral y reportes ejecutivos DataTables sin duplicidades ni @import bloqueantes.

1. **Borde Teal Distintivo en Contenedores (`.agenda-side-card`)**:
   - Tarjetas laterales, mini calendario y paneles modales aplican `border: 1px solid rgba(25, 183, 165, 0.4)` con acabado glassmorphism `backdrop-filter: blur(12px)`.
2. **Mini Calendario Lateral Dinámico**:
   - Controles de navegación mensual `< MES AÑO >` con botones circulares (`.side-cal-nav-btn`) y foco teal.
   - Píldoras de día interactivas, con resaltado de día actual (`.side-cal-day.is-today`), días con citas registradas (`.has-apts`) y día activo seleccionado (`.active`).
3. **Manejo de Días Pasados en Vista Diaria**:
   - **Empty State con Ícono Teal (`.agenda-empty-day-card`)**: Si no existió actividad registrada en una fecha pasada, se muestra una tarjeta premium centrada con el mensaje *"Sin actividad registrada para este día"* y botón de retorno rápido *"Volver al Día de Hoy"*.
   - **Historial Ejecutivo de Citas (`.agenda-past-day-container`)**: Si existieron citas pasadas, se muestra una lista cronológica ejecutiva detallando horario, paciente, motivo, badge de estado y accesos directos al expediente y ficha.
4. **Estado de Citas "No realizada"**:
   - Representación visual con tarjeta en tinte rojo sutil (`.apt-card-dia.no-realizada`), badge rojo (`.badge-no-realizada`) y acciones habilitadas para ver expediente, re-agendar o eliminar.

### 6.5 Modo Responsivo Móvil en Reportes de Agenda y DataTables (Reglas Mandantes)

1. **Barra de Exportación Icon-Only con Tooltip**:
   - En pantallas móviles (`<768px`), los botones de exportación (Copiar, Excel, PDF, Imprimir) muestran exclusivamente su ícono vectorial centrado dentro de una cápsula circular de 36x36px (`border-radius: 50%`) con borde turquesa clínico y sombra sutil.
   - Las leyendas de texto se ocultan en móvil (`d-none d-md-inline`) y se transforman en tooltips flotantes Bootstrap (`titleAttr`) activados al interactuar.
2. **Paginación y Navegación DataTables en 2 Filas Desacopladas**:
   - **Fila 1 (Información)**: `.dataTables_info` se ubica centrada horizontalmente, ocupando el 100% del ancho con micro-tipografía de `0.65rem` y peso bold (`color: #64748b`).
   - **Fila 2 (Navegación)**: `.dataTables_paginate` se posiciona inmediatamente debajo, centrada con micro-botones compactos (`height: 24px; min-width: 24px; font-size: 0.65rem`).
   - La página activa se resalta con el turquesa clínico corporativo (`#19B7A5`) y sombra suave.
3. **Buscador Reactivo Integrado**:
   - Se integra obligatoriamente el control de búsqueda (`f`) en el DOM de DataTables (`Bf`) con borde turquesa corporativo (`1.5px solid var(--md-teal-clinical)`), esquinas redondeadas en píldora (`border-radius: 50rem`) y ancho completo en vista móvil.
4. **Cards Móviles con Acento Lateral Turquesa y Cero Scroll Horizontal**:
   - Cada fila de citas transmuta en una tarjeta compacta (`border-left: 3.5px solid var(--md-teal-clinical)`).
   - Márgenes y paddings reducidos al mínimo (`padding: 6px 10px; margin-bottom: 6px`), eliminando espacios vacíos innecesarios.
   - Forzado de `overflow-x: hidden !important` en `.agenda-table-responsive` para erradicar cualquier barra de desplazamiento horizontal indeseada.
5. **Gobernanza de Drag & Drop y Vista Semanal Smart**:
   - **Exclusividad de Drag & Drop**: El arrastre de citas solo existe en la **Vista Mensual Grid** (`currentView === 'calendario'`). En la Vista Diaria (`currentView === 'dia'`), al carecer de slots de destino, el clic abre de inmediato la ficha y no se activa el modo arrastre.
   - **Drop con Validación Temporal >= Momento Actual**: El drop únicamente permite soltar citas en fechas y horas iguales o superiores a la fecha y hora presente (`isFuture(fecha, hora)`).
   - **Tarjetas de 7 Días con Acabado Acrílico (`.card-acrilico`)**: Los 7 días visibles de la Vista Semanal Smart aplican la clase `.card-acrilico` con micro-paddings, bisel translúcido y elevación 3D.
   - **Atenuación y Glassmorphism en Slots Pasados**:
     - *Horarios pasados vacíos*: Atenuados (`.slot-pasado-atenuado`) con tooltip explicativo *"No se pueden agendar citas en horarios que ya han pasado"*.
     - *Horarios pasados ocupados*: Resaltados con cristal satinado (`.slot-reservado-pasado-glass`), ícono de candado turquesa y ficha bloqueada contra re-agendamiento.
   - **Bordes Corporativos**: Todos los contenedores principales (encabezado, tarjetas de reporte, categorías y calendario) incorporan el borde turquesa corporativo (`border: 1.5px solid var(--md-teal-clinical)`).
6. **Erradicación de Doble Scroll Vertical y Anti-Solapamiento de Etiquetas**:
   - En pantallas móviles (`@media (max-width: 991px)`), `.sdm-main-content` opera estrictamente con `height: auto !important; overflow-y: visible !important;` eliminando el conflicto de doble barra de desplazamiento entre el contenedor interno y el viewport global del navegador.
   - En las tarjetas móviles de DataTables, las pseudo-etiquetas `::before` portan obligatoriamente `position: static !important; float: none !important; width: auto !important;`, anulando colisiones de posicionamiento absoluto heredadas y garantizando que la etiqueta (izquierda) y el valor (derecha) coexistan limpios en `display: flex; justify-content: space-between`.
   - El viewport principal `#app-viewport` incorpora `padding-bottom: 95px !important` para garantizar que la barra de navegación inferior fija y su botón de acción flotante no obstruyan la paginación ni los controles de reporte.
7. **Unificación Tipográfica en Tablas de Reportes (Semanal y Mensual)**:
   - Las tablas `#agendaTable` y `#mesTable` portan la clase corporativa `.table-diamond` y comparten la tipografía idéntica a la tabla del Directorio de Pacientes (`'Inter', sans-serif`).
   - **Cabeceras Sin Negritas (`thead th`)**: Se establece de forma canónica `font-weight: 500 !important;` en tamaño `0.75rem`, erradicando negritas agresivas y unificando el color con `var(--md-text-secondary, #486581)` y fondo clínico `#F8FBFF`.
   - **Cuerpo (`tbody td`)**: Tipografía en `0.8125rem` (13px), `font-weight: 400`, color `#102A43` y espaciado consistente.

---

## 7. Estándares UI Móviles del Directorio de Pacientes (`views/pacientes.pl`, `css/tabla_pacientes.css`)

1. **Supresión Absoluta del Hero Header en Modo Móvil (Imagen 2)**:
   - El encabezado superior azul (`<header id="pacientesHeroHeader" class="bg-medentia-gradient ...">`) con el título *"Directorio de Pacientes"* y el botón *"Agregar nuevo paciente"* queda estrictamente oculto en móvil mediante el selector `header#pacientesHeroHeader, #pacientesHeroHeader { display: none !important; }` anulando la especificidad de `header.bg-medentia-gradient`.
   - **Razón Arquitectónica**: Al estar en vista móvil, la barra de navegación inferior global (`utils/sub_bottom_nav.pl`) ya proporciona el botón central flotante (`+`) para el registro de nuevos pacientes, eliminando redundancia visual.
2. **Barra de Exportación Idéntica al Menú Inferior Flotante**:
   - Se erradica el borde grueso de píldora verde en el contenedor y los bordes circulares individuales de los botones.
   - En su lugar, el dock de exportación adopta el estilo del menú inferior flotante (`.sdm-main-bottom-nav`):
     - Fondo con tinte azul translúcido: `background: rgba(232, 243, 255, 0.96)`.
     - Desenfoque de cristal: `backdrop-filter: blur(15px)`.
     - Borde sutil de 1px: `border: 1px solid var(--md-teal-clinical, #19B7A5)`.
     - Esquinas ligeramente redondeadas: `border-radius: 5px`.
     - Altura compacta de `48px`, ancho de `220px a 280px` centrado.
     - Botones sin borde individual: `background: transparent; border: 1px solid transparent; color: #0A2A66; font-size: 1.25rem;` con hover suave (`transform: translateY(-2px)`).
3. **Erradicación de Solapamiento de Etiquetas (`::before`) en Tarjetas**:
   - Las pseudo-etiquetas de datos (`CONTACTO`, `F. NAC / SEXO`) utilizan de forma mandatoria `position: static !important; float: none !important; display: block !important; margin: 0 0 4px 0 !important;`.
   - Esto anula la colisión generada por `position: absolute` en resoluciones móviles, garantizando que la etiqueta quede ubicada limpia y ordenadamente arriba de los datos (teléfono, correo, fecha de nacimiento y sexo).
4. **Barra Inferior de Navegación Desacoplada en 2 Filas y Despeje Ampliado**:
   - **Fila 1 (Información de Registros)**: `.dataTables_info` se centra horizontalmente en una sola fila con tipografía nítida `0.72rem` (`#64748b`).
   - **Fila 2 (Paginador)**: `.dataTables_paginate` se ubica centrada inmediatamente abajo, con micro-botones de `28x28px`, borde suave y resaltado de página activa en turquesa corporativo (`#19b7a5`).
   - **Despeje Ampliado (Anti-Solapamiento FAB `+`)**: Se asigna `padding-bottom: 110px !important` a `#tablaPacientes_wrapper` y `margin-bottom: 120px !important` a los contenedores móviles para asegurar que el botón flotante central `+` del dock inferior flote sobre el área libre y nunca solape los controles de paginación.
5. **Optimización de Espacios y Densidad de Tarjetas**:
   - Se reduce el margen inferior entre tarjetas a solo `8px`.
   - Padding interno de celdas optimizado a `6px 12px`, suprimiendo huecos vacíos innecesarios.
   - Borde lateral izquierdo turquesa de `3.5px` (`var(--medentia-success, #19b7a5)`) para rápida jerarquía visual.

---

## 8. Estándares UI Móviles y Responsividad en Expediente Clínico (`views/render_expediente_clinico.pl`, `css/expediente_mobile.css`)

1. **Drawer de Navegación Lateral Móvil (Sidebar Drawer)**:
   - En pantallas táctiles (`< 992px`), el menú lateral de navegación se transforma en un **Drawer Flotante** anclado estrictamente a `position: fixed; top: 0; left: 0; bottom: 0; width: 280px; z-index: 1060;`.
   - Posee un backdrop/overlay semitransparente con desenfoque de cristal (`backdrop-filter: blur(4px); background: rgba(10, 42, 102, 0.45);`).
   - Se oculta de forma fluida (`transform: translateX(-100%)`) y se activa con la clase `.open` (`transform: translateX(0)`).
   - Se cierra automáticamente al pulsar fuera del panel, al interactuar con el botón de cierre (`<button class="btn-close">`) o al seleccionar cualquiera de las pestañas (`.sdm-tab-btn`).
2. **Hero Header Anti-Distorsión del Paciente**:
   - El contenedor azul superior (`.card-hero-paciente`) adapta su layout de horizontal a vertical en móviles (`flex-direction: column; align-items: center; text-align: center;`).
   - **Avatar Proporcional**: Se fija con `flex-shrink: 0; width: 72px; height: 72px; min-width: 72px; border-radius: 50%; object-fit: cover;` evitando aplastamientos o deformaciones elípticas.
   - **Tipografía Escalable**: El nombre del paciente escala a `1.25rem` con `word-break: break-word;` y las insignias (edad, sexo, tipo de sangre, estado) se ajustan con `flex-wrap: wrap; justify-content: center; gap: 4px;`.
3. **Erradicación de Doble Scroll Vertical**:
   - Se elimina la regla heredada de altura fija en `.sdm-main-content` y `#app-viewport`, fijando `height: auto !important; overflow-y: visible !important;` en móviles.
   - El scroll vertical recae de forma unificada y natural en el `window` / `body`, eliminando barras de scroll anidadas y desbordamientos indeseados.
4. **Priorización de Signos Vitales y KPIs Clínicos**:
   - En el Tab 1 (*Resumen Clínico*), las tarjetas somatométricas (Presión Arterial, Frecuencia Cardíaca, Temperatura, IMC, Glucosa) se despliegan en una cuadrícula compacta de 2 columnas (`grid-template-columns: repeat(2, 1fr)`), permitiendo al médico escanear los signos vitales de un vistazo sin necesidad de scroll horizontal.
5. **Gobernanza de Acciones Rápidas (Timeline)**:
   - En las tarjetas del historial de atenciones (Tab 10), los botones de acción (`Detalles`, `Receta`, `Consentimiento`, `Recibo`) se agrupan con `.flex-wrap` y borde redondeado tipo píldora (`rounded-pill px-3 py-1`).
   - El botón **Receta** se oculta si no hubo prescripción de fármacos y el botón **Consentimiento** se oculta si la atención no requirió dicho documento legal.

---

## 9. Estándares de Interacción del Menú Lateral y Acordeones (`utils/sub_sidebar.pl`, `css/sub_sidebar.css`, `js/sub_sidebar.js`)

1. **Alineación Total a la Izquierda y Cero Desfase (Erradicación de Cápsulas Flotantes)**:
   - En Desktop y Móvil, `.diamond-sidebar` se ancla estrictamente al margen izquierdo absoluto (`left: 0; top: 0; margin: 0 !important; border-radius: 0 !important; height: 100vh; position: sticky;`). Queda prohibido el uso de márgenes exteriores (`margin: 1rem`) o bordes redondeados en los 4 vértices que despeguen la barra de la pantalla o simulen islas flotantes que generen espacio muerto.
   - En modo expandido: ancho constante de `260px` con borde derecho sutil `1.5px solid rgba(25, 183, 165, 0.25)`.
   - En modo compacto (`.compact`): ancho constante de `68px` alineado al extremo izquierdo.
2. **Consistencia Visual y Erradicación de Desbordes en Modo Compacto (Desktop >= 992px)**:
   - **Cuadrícula Unificada de 42x42px**: Todos los elementos interactivos del menú colapsado (tanto botones de acordeón `.accordion-button` como enlaces directos y sub-enlaces `.sub-link`) comparten dimensiones idénticas: `width: 42px !important; height: 42px !important; margin: 3px auto !important; border-radius: 10px !important;`.
   - **Armonía Cromática en Estados Activos**: Se erradicó el bloque azul marino oscuro opaco `#0A2A66` que rompía la simetría. Los ítems activos se presentan bajo el estándar institucional: `background: rgba(25, 183, 165, 0.16); border: 1.5px solid var(--md-teal-clinical, #19B7A5); color: var(--md-blue-deep, #0A2A66);` con ícono teal `#19B7A5`.
   - **Simetría en Acordeones Desplegados**: Al abrirse un acordeón en modo compacto, el botón padre se mantiene como un recuadro de `42x42px` con fondo y borde teal suave (`border-left` grueso de 3px queda anulado), preservando la verticalidad pura de la columna.
   - **Cabecera Proporcional y Ergonómica**: `.sidebar-brand` aplica `padding: 12px 4px 8px 4px`, avatar `.avatar-diamond` de `38x38px` centrado y botón toggle de `34x34px`, garantizando que las iniciales no rocen ni se solapen con la barra superior.
   - **Contenedor Scrolleable con Flexbox**: `.diamond-sidebar` opera con `display: flex; flex-direction: column; overflow: hidden;` y el `.sidebar-menu` aplica `flex: 1; min-height: 0; overflow-y: auto; padding-bottom: 40px !important;`, previniendo que los últimos ítems (ej. ingresos, egresos) queden truncados por el marco de la pantalla.
3. **Rotación Coherente del Chevron en Acordeones**:
   - Cerrado (`.accordion-button.collapsed::after`): rota `0deg` apuntando hacia abajo suavemente.
   - Expandido (`.accordion-button:not(.collapsed)::after`): rota `180deg` hacia arriba mediante transición fluida `cubic-bezier(0.2, 0, 0, 1)`.
4. **Apertura Múltiple Independiente y Jerarquía Ergonómica**:
   - Se retiró el atributo `data-bs-parent="#accordionSidebar"` de todos los grupos colapsables (*Expediente*, *Diagnóstico*, *Finanzas*, *Administración*, *Ventas*), permitiendo que el usuario mantenga abiertas múltiples secciones simultáneamente sin canibalización involuntaria de menús.
   - **Precedencia Operativa de Finanzas**: Debido a su alta frecuencia de interacción en el día a día clínico (Caja, Corte de Caja, Recibos), la sección de **Finanzas** precede jerárquicamente a **Administración** en la estructura vertical del menú.
5. **Indicador de Hijo Activo (`.active-dot`)**:
   - Si una sección colapsable cerrada contiene la página en curso, se renderiza un micro-indicador luminoso turquesa (`.active-dot`) en la cabecera del acordeón, manteniendo la retroalimentación visual de la ubicación del usuario. Al desplegarse la sección, el punto se oculta automáticamente para dar protagonismo al `.sub-link.active`.
6. **Comportamiento Responsivo en Móvil y Tableta (`< 992px`)**:
   - **Drawer Completo**: La clase `.compact` queda estrictamente anulada en pantallas menores a 992px; el sidebar opera exclusivamente como un Drawer off-canvas completo de 260px con fondo blanco y borde derecho teal (`border-radius: 0 16px 16px 0 !important; z-index: 10500 !important;`).
   - **Touch Targets Estandarizados**: Botones de acordeón con `min-height: 44px;` y sub-enlaces con `min-height: 38px;` para navegación táctil sin fallos.
   - **Auto-cierre Táctil**: Al pulsar cualquier enlace o pestaña del menú en móvil/tableta, el drawer y su backdrop se cierran automáticamente para revelar el contenido sin requerir una pulsación manual en el botón de cierre o en el overlay.
7. **Tooltips Flotantes Dinámicos (`.sidebar-floating-tooltip`)**:
   - En lugar de flyouts invasivos, el sistema despliega un tooltip flotante anclado a `position: fixed` con fondo azul marino institucional translúcido (`rgba(10, 42, 102, 0.95)`), borde teal suave y sombra de elevación. Lee el atributo `data-sidebar-title` de avatares, toggles, botones de acordeón y sub-enlaces con posicionamiento vertical centrado a la derecha del ítem.

---

## 10. Estándares UI Móviles para Wizards Clínicos y Dock Inferior (`consulta_flow.css`, `sub_bottom_nav.pl`, `render_consultas_privado.pl`, `crud_paciente.pl`)

1. **Componente `.wizard-hero-header` (App-Bar Móvil No Invasiva)**:
   - **Desacoplamiento Estricto**: Todo formulario wizard clínico y administrativo de alta densidad debe utilizar `.wizard-hero-header` en sustitución del genérico `header.bg-medentia-gradient`.
   - **Erradicación de Elipses**: Los contenedores `.hero-icon-box` e íconos `.rounded-circle` mantienen forzado `flex-shrink: 0; width: 36px; height: 36px; max-width: fit-content !important;` en móvil, garantizando esferas perfectas sin estiramiento horizontal.
   - **Altura Compacta (~55px)**: El encabezado opera como una barra de aplicación móvil que no excede los 60px de altura, estructurando el ícono, título y chips de metadatos en una sola fila compacta, reservando más del 85% del viewport útil para el stepper y los campos clínicos.
2. **Dock Inferior Anclado al Fondo con Gobernanza RBAC y Simetría Canónica (`bottom_nav.css`, `utils/sub_bottom_nav.pl`)**:
   - **Single Source of Truth (`css/bottom_nav.css`)**: Centralización absoluta de las propiedades de la barra inferior anclada (`bottom: 0`, `left: 0`, `right: 0`, `width: 100%`, `height: calc(56px + env(safe-area-inset-bottom, 0px))`, `border-radius: 16px 16px 0 0`, `border-top: 1.5px solid var(--md-teal-clinical, #19B7A5)`, `background: rgba(232, 243, 255, 0.96)`, `backdrop-filter: blur(16px)`).
   - **Soporte Ergonómico Notch y Safe Area**: Soporte integrado para `env(safe-area-inset-bottom)` previniendo colisiones con el indicador gestual de inicio en iOS y Android.
   - **Arquitectura Simétrica de 5 Slots con FAB Elevado**: En todas las vistas e instancias del sistema, la barra presenta una estructura balanceada de 5 posiciones con el botón central de acción contextualmente elevado (`.dock-fab` de 48px, fondo turquesa `#00C4C4`, elevación `-12px`, esquinas redondeadas circulares).
   - **Coordinación Anti-Solapamiento con Menú Lateral**: Cuando el menú lateral izquierdo se abre en móvil (`body.sidebar-open`), la barra inferior desciende reactivamente (`transform: translateY(115%)`) para no obstruir los submenús del drawer.
   - **Segregación Estricta por Rol (RBAC)**:
     - **Rol Médico**: Acceso al FAB central y opciones de Consulta Médica (`bi-heart-pulse-fill`) en Expediente, Consulta, Agenda, Pacientes y Dashboard.
     - **Roles Administrativos / Recepción**: La opción de consulta médica se omite íntegramente por seguridad funcional; el FAB central se reconfigura hacia *Nueva Cita* (`bi-calendar-plus`), *Nuevo Paciente* (`bi-person-plus-fill`) o *Finanzas* (`bi-wallet2`).
     - **Rol Paciente**: Barra simétrica con *Inicio*, *Inbox*, FAB central *Agendar Cita* (`agendar_cita_paciente.pl`), *Mis Citas* e *Historial Clínico*.
   - **Resaltado Activo Homogéneo**: Los ítems regulares activos (`.main-tab-item.active`) proyectan un borde azul marino sutil (`1.5px solid #0A2A66`) con elevación de `-2px`, mientras el FAB activo (`.dock-fab.active`) resalta con borde blanco de `2.5px`, resplandor turquesa, escala `1.06` y elevación `-12px`.
3. **Hub de Consultas Responsivo**:
   - Las citas programadas e historial clínico implementan tarjetas flexibles (`flex-column flex-sm-row`) con micro-píldoras de estado y fecha/hora que previenen recortes de texto.
   - Touch target mínimo de 48px para los botones de acción en celulares y ancho adaptativo (`w-100 w-sm-auto`) respaldado por la utilidad `.w-sm-auto` (`width: auto !important;` en `>=576px`) en `css/sdm_mobile_standards.css` y `css/ospulso_master_v2.css`, erradicando desbordes del botón de acción fuera de la tarjeta.
   - **Gobernanza de Etiquetas en Modal de Gestión de Citas (`#modalCita`)**: Uso de etiquetas superiores canónicas `.form-label-compact` y controles compactos `.form-control-compact` / `.form-select` (38px de altura), erradicando colisiones y recortes de texto horizontal causados por `form-floating` en grids densos.
4. **Menú Lateral Móvil Compacto y Ergonómico (`css/sub_sidebar.css`, `utils/sub_sidebar.pl`)**:
   - **Anchura Ergonómica**: Limitado a `268px` (`max-width: 80vw`), reservando un 20% visible de backdrop para cierre ágil con un solo toque.
   - **Densidad Táctil Compacta**: Cabecera reducida a 56px de alto (`padding: 0.65rem 1rem`), avatar de 38px, ítems principales a 40px de altura (`padding: 8px 10px`) y sub-enlaces a 34px (`padding: 6px 10px`). Esto optimiza en un 40% el espacio vertical visible, reduciendo drásticamente la necesidad de scroll.
   - **Desacoplamiento de Stacking Context**: Eliminación de trampas de apilamiento en `.sdm-layout-wrapper` asegurando que el sidebar (`z-index: 10500`) y su overlay (`z-index: 10490`) siempre prevalezcan sobre la barra inferior.
   - **Ocultamiento Limpio**: En estado colapsado (`@media (max-width: 991px)`), `.diamond-sidebar` aplica `transform: translateX(-105%) !important; visibility: hidden !important; pointer-events: none !important; box-shadow: none !important;`, previniendo que bordes o sombras proyectadas asomen en el margen izquierdo del dispositivo.

---

## 11. Regla de Desuso y Prohibición Estricta de `utils/sub_footer.pl`

1. **Deprecación Estricta**: Queda terminantemente PROHIBIDO incluir o invocar el componente legacy `utils/sub_footer.pl` (`require '.../sub_footer.pl'` o `render_footer(...)`) en cualquier nuevo script `.pl` (vistas o endpoints), a menos que el usuario lo solicite de forma explícita.
2. **Sustitución Canónica**:
   - La navegación móvil contextualmente adaptada se delega de forma exclusiva a `utils/sub_bottom_nav.pl` invocando la subrutina `render_bottom_nav(...)`.
   - El cierre del documento HTML en las vistas debe realizarse de forma directa y limpia con `print "</body>\n</html>";` sin inyectar pies de página estáticos que colisionen o empujen innecesariamente la barra de navegación flotante.

---

## 12. Jerarquía Canónica Universal de Z-Index y Ciclo de Vida de Modales

1. **Jerarquía Z-Index Universal del Sistema (`css/ospulso_master_v2.css`)**:
   - Para erradicar solapamientos y trampas de apilamiento entre barras superiores fijas (`.sdm-navbar`, `sticky-top`), overlays laterales (`.sidebar-overlay`), modales, telones (`.modal-backdrop`) y alertas de confirmación, la escala oficial se define canónicamente:
     * **Alertas y Diálogos de Confirmación (`.swal2-container`, `Swal.fire`)**: `z-index: 110000 !important;` (Cota máxima del sistema para garantizar visibilidad sobre cualquier nivel de modales anidados)
     * **Modales Anidados de Sub-procesos (`#modalNuevaCot`, `#modalCotizaciones`)**: `z-index: 107000 - 108000 !important;`
     * **Desplegables / Autocomplete sobre Modales (`.ui-autocomplete`)**: `z-index: 106000 !important;` (Garantiza visibilidad sobre modales activos `105150` y diálogos `105160`)
     * **Modales y Diálogos Activos (`.modal`, `.modal.show`, `#expedienteModal`, `.dispatch-progress-modal`)**: `z-index: 105150 !important;` (Diálogos: `105160 !important;`)
     * **Telones de fondo (`.modal-backdrop`, `.modal-backdrop.show`, `.modal-backdrop.fade.show`)**: `z-index: 105000 !important;`
     * **Overlays de Menú Lateral Móvil (`.sidebar-overlay`)**: `z-index: 10400 !important;`
     * **Docks Inferiores y Navegación Flotante (`.bottom-bar-dock`, `.nav-dock`)**: `z-index: 1030 !important;`
     * **Cabeceras y Barras Superiores Fijas (`.sdm-navbar`, `.glass-navbar`, `nav.navbar.sticky-top`)**: `z-index: 1020 !important;`
2. **Motor Universal de Auto-Hoisting en el DOM (`utils/sub_header.pl`)**:
   - Todo diálogo modal (`.modal`) en cualquier vista del sistema queda blindado contra trampas de apilamiento (*CSS Stacking Context Traps* causadas por contenedores padres con `transform`, `filter`, `opacity`, `overflow` o clases de animación como `animate__animated animate__fadeIn`).
   - El script canónico en `utils/sub_header.pl` intercepta de manera reactiva en fase de captura (`document.addEventListener('show.bs.modal', ..., true)`) cualquier apertura de modal y lo reubica (*hoisting*) inmediatamente como hijo directo de `document.body` si aún no lo está, forzando `z-index: 105150 !important` al contenedor y `105160 !important` a `.modal-dialog`. Adicionalmente, realiza un barrido inicial en `DOMContentLoaded` para modales pre-renderizados.
   - Esta solución omnipotente garantiza que NINGÚN modal quede atrapado detrás del `sub_header.pl` (`z-index: 1020`) ni detrás del backdrop (`z-index: 105000`).
3. **Mecanismo Seguro de Cierre y Limpieza de Telón (Backdrop)**:
   - Todo modal dinámico que ejecute procesos asíncronos o por lotes debe proveer cierre multi-vía visible (botón X en cabecera y botón de acción en pie).
   - El desmonte debe limpiar exhaustivamente los telones huérfanos (`.modal-backdrop`) y remover las clases residuales `modal-open` del `<body>`, asegurando que el scroll de la interfaz nunca quede bloqueado tras la finalización de un proceso.
4. **Caso Canónico: Blindaje del Modal de Expediente y Cotizaciones (`views/pacientes.pl`)**:
   - El diálogo `#expedienteModal` se renderiza de forma estricta con posterioridad al cierre de layout mediante `utils::sub_sidebar::render_sidebar_footer()`, erradicando subordinaciones al stacking context del panel lateral o del grid de datos.
   - Su cota de apilamiento se fija en `z-index: 105100 !important;`, garantizando su elevación sobre el telón general de 105000.
   - Al interactuar con el sub-modal `#modalCotizaciones` (`z-index: 107000`), las alertas de SweetAlert2 (`Swal.fire` para "¿Eliminar cotización?") operan en `z-index: 110000 !important;`, manteniéndose siempre visibles en primer plano.

---

## 13. Estándar Universal de Jerarquía Visual en Capas para DataTables y Paneles Financieros

Para garantizar una experiencia de usuario corporativa, limpia y de alto valor estético en paneles analíticos y tablas DataTables:

1. **Patrón Cromático Mandante (Azul Marino + Blanco Clínico + Bordes Teal)**:
   - **Superficie de Tarjeta**: Fondo blanco clínico puro (`background: #FFFFFF`), sin gradientes 3D ni auras difusas residuales (`card-medentia-aura` o `.bento-card` quedan totalmente proscritas).
   - **Borde Perimetral Estándar**: Trazo sólido y sutil en Teal clínico institucional: `border: 1.5px solid var(--md-teal-clinical, #19B7A5) !important;`.
   - **Sombra Multicapa**: Elevación suave no invasiva: `box-shadow: 0 4px 15px rgba(10, 42, 102, 0.05);`.
   - **Espaciado y Esquinas**: Bordes redondeados consistentes (`rounded-4`) con padding responsive simétrico (`p-3 p-md-4`).

2. **Anatomía Canónica de Cabecera de Tabla**:
   - Todo contenedor de tabla DataTables (`#dtIngresosPrivados`, `#dtIngresosMunicipio`, `#tablaGastos`) debe incorporar una cabecera flex homogénea estructurada en dos bloques:
     * **Bloque Izquierdo (Identidad y Contexto)**:
       - *Cápsula Circular de Ícono (38x38 px)*: Círculo con fondo translúcido al 10% del color temático (Verde para ingresos privados, Cyan para convenios institucionales, Rojo para egresos/gastos).
       - *Título Jerárquico*: `font-size: 1.15rem`, `font-weight: 700`, tipografía `Plus Jakarta Sans`, color Azul Marino Profundo (`var(--md-blue-deep, #0A2A66)`).
       - *Subtítulo Descriptivo*: `font-size: 0.82rem`, color `#64748B`, explicando el alcance de los registros en el periodo.
     * **Bloque Derecho (Badge Temático Píldora)**:
       - Badge discreto en cápsula (`rounded-pill px-3 py-1 fw-semibold small`) que identifica la naturaleza del flujo contable (*Efectivo / Ventanilla*, *Convenio Institucional*, *Egresos / Salidas*).

3. **Botonería de Control y Filtrado**:
   - Botones de acción secundaria o filtros (ej. "Filtrar") utilizan Azul Marino institucional sólido (`background: var(--md-blue-deep, #0A2A66); color: #FFFFFF; border-radius: 50rem;`) erradicando la clase heredada `btn-aura-save`.
   - Botones de acción primaria (ej. "Registrar Gasto") utilizan Teal clínico (`background: var(--md-teal-clinical, #19B7A5); color: #FFFFFF; border-radius: 50rem;`).

4. **Principio de No Redundancia y Descarte de Vistas Huérfanas**:
   - Las vistas de datos no deben duplicar listados que se operan con mayor eficiencia en otros módulos.
   - La cobranza y saldos de pacientes pertenecen al punto de atención clínico (**Expediente del Paciente** en `views/pacientes.pl`); los paneles de finanzas muestran indicadores macro ejecutivos sin necesidad de arrastrar tablas secundarias desconectadas del flujo de trabajo diario.

---

## 14. Estándar Bento Grid de Cero Scroll para Modales Ejecutivos (`expedienteModal`, `tabla_pacientes.css`, `pacientes_spa.js`)

1. **Arquitectura Cero-Scroll Vertical**:
   - Todo modal de consulta rápida o resumen clínico (ej. `#expedienteModal` en `views/pacientes.pl`) debe estructurarse para desplegar su contenido completo dentro de una altura máxima de 320px en móvil y 460px en escritorio, erradicando por completo el scroll vertical del viewport.
   - Se elimina el `.modal-footer` redundante cuando la cabecera ya integra botón de cierre accesible (`.btn-close`), ahorrando entre 45px y 55px de espacio vertical crítico.
2. **Distribución Adaptable de KPIs Financieros**:
   - **En Escritorio (`>= 992px`)**: Grid simétrico 2x2 (`col-6`) en la columna izquierda, con tarjetas acrílicas de 46px de altura, etiquetas en `0.58rem` y cifras en `1.05rem`.
   - **En Móvil (`< 768px`)**: Los 4 indicadores (Cargos, Abonos, Saldo, Cotizaciones) se transforman automáticamente a 1 sola fila horizontal de 4 columnas (`col-3 col-lg-6`) de 38px de altura, ahorrando más de 90px de scroll vertical.
3. **Botonera Bento Grid Compacta**:
   - 8 accesos directos estructurados en matriz 4x2 (`.bento-action-btn-compact`), con altura máxima de 46px en desktop y 42px en móvil, iconografía vectorial de 1.15rem y etiquetas condensadas en `0.52rem` / `0.46rem`.
4. **Historial de Consultas y Empty State Lineal**:
   - El estado vacío de citas se compacta a un cintillo horizontal de 1 sola fila (`.empty-consultas-compact`, 36px) con icono alineado (`bi-clipboard2-x`), reemplazando tarjetas sobredimensionadas con paddings heredados de `p-5`.

---

## 15. Estándar Editorial de Impresión Hospitalaria y Visor de Vista Previa Modal (2 Páginas Carta)

Para erradicar la degradación visual provocada por imprimir directamente la interfaz gráfica del navegador (`window.print()` ciego sobre pantallas web):

1. **Visor de Previsualización Interactivo (`.preview-paper-stage`)**:
   - Todo módulo con capacidad de emitir informes o actas ejecutivas (ej. `views/resumen_ejecutivo.pl`) debe anteponer un modal de previsualización antes de disparar la impresora.
   - El modal despliega un fondo gris pizarra oscuro (`background-color: #525659; min-height: 80vh;`) sobre el cual se montan las hojas físicas de papel (`.report-sheet`) con fondo blanco, sombra de elevación (`box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4)`), borde sutil y dimensiones estándar Carta (8.5in x 11in, `816px` de ancho en pantalla).
   - Permite al directivo auditar cifras, firmas y saltos de página con total fidelidad previa.

2. **Aislamiento Inmune Total en `@media print`**:
   - Queda estrictamente PROHIBIDO imprimir elementos de interfaz gráfica (barras de navegación, docks inferiores fijos, menús laterales, toolbars, breadcrumbs, botones o telones de modales).
   - Se aplica la técnica de aislamiento por visibilidad:
     ```css
     @media print {
         body * { visibility: hidden !important; }
         #reporteImpresionOficial, #reporteImpresionOficial * { visibility: visible !important; }
         #reporteImpresionOficial {
             position: absolute !important;
             left: 0 !important; top: 0 !important;
             width: 100% !important; margin: 0 !important; padding: 0 !important;
         }
         .diamond-sidebar, .sdm-main-bottom-nav, .bottom-nav, .btn, .no-print {
             display: none !important;
         }
     }
     ```
   - Esto erradica de raíz que componentes con `position: fixed` (como el dock móvil `.sdm-main-bottom-nav`) se repitan flotando como cabeceras indeseadas en cada página impresa.

3. **Arquitectura Rígida de 2 Páginas Carta (Anti-Desbordes)**:
   - **Hoja 1 (`.report-page-1`)**: Alberga el membrete formal, dictamen de validez, KPIs macro, desglose cronológico de recaudación, control de medios de pago (arqueo de caja) y distribución departamental. Aplica `page-break-after: always !important; break-after: page !important;` y pie con foliado *"Página 1 de 2"*.
   - **Hoja 2 (`.report-page-2`)**: Alberga el sub-membrete de continuidad, la matriz 2x2 de los 4 Ejes Estratégicos con sus acciones de decisión, la leyenda de certificación forense de integridad contable y el bloque formal de 3 firmas (*Caja/Finanzas*, *Dirección General / Médico Titular*, *Auditoría Suite OSPulso*). Aplica `page-break-after: avoid !important; break-after: avoid !important;` y pie con foliado *"Página 2 de 2"*, impidiendo la generación de hojas huérfanas en blanco.
   - **Preservación Cromática Obligatoria**: Integración de `-webkit-print-color-adjust: exact !important; print-color-adjust: exact !important;` en badges, tablas y barras de progreso.

---

## 8. Landing Page y Suite Metodológica 5S (`index.html`)

### 8.1. Principio de Separación Estricta (CSS y JavaScript)
Conforme a las directrices de `AGENTS.md`, la página principal `index.html` opera bajo desacoplamiento absoluto de presentación y comportamiento:
1. **Cero bloques `<style>` en HTML**: Todas las clases (`.icon-5s`, `.card-5s`, `.trust-banner`, `.step-circle`, `.showcase-wrapper`, `.scroll-reveal`, `.footer-glass`) residen centralizadas en `css/ospulso_master.css`.
2. **Cero scripts embebidos**: La lógica de interacción (menú drawer responsivo, calculadora gamificada de retorno de inversión y `IntersectionObserver` de scroll reveal) reside en `js/indexLogic.js`.
3. **Respaldo de Versión Canónica**: Antes de cualquier refactorización profunda, se preserva el snapshot histórico (ej. `index_old_oct2026.html`).
4. **Cumplimiento Móvil Nativo**: Se incluye `css/sdm_mobile_standards.css` para unificar el viewport táctil y los touch targets en dispositivos móviles.

### 8.2. Gobernanza de Contraste Visual y Clases Mandantes
Para garantizar accesibilidad universal (WCAG 2.1 AA/AAA) y consistencia editorial:
1. **Contraste de Tipografía Secundaria**: Sustitución de `.text-muted` o `.text-secondary` genéricos por `.text-secondary-clinical` (`#334e68`), elevando el contraste de 3.2:1 a 7.4:1 sobre fondos claros.
2. **Iconografía de Alto Contraste**: 
   - En componentes numéricos (`.icon-5s`), texto azul profundo (`#0A2A66`) sobre fondo blanco con borde teal (`#19B7A5`) para contraste > 12:1.
   - En listas de verificación, reemplazo de `.text-info` cyan por `.text-teal-clinical` (`#0f766e`) y `.text-success` médico.
   - En el Trust Banner (`.trust-logo`), opacidad de 0.9 y texto `#1e293b` con íconos teal accesibles.
3. **Reutilización de Componentes Mandantes**:
   - Sustitución de contenedores ad-hoc por `.icon-container-acrylic` del sistema Diamond.
   - Eliminación total de estilos en línea (`style="..."`), sustituidos por utilidades semánticas (`.brand-tagline`, `.footer-brand-title`, `.footer-brand-sub`, `.footer-info-block`, `.footer-nav-link`, `.footer-copyright`, `.card-notice-note`, `.modal-footer-nav`).
4. **Showcase Visual de Plataforma (Carrusel Interactivo de 5 Vistas Homologadas)**:
   - Implementación del carrusel interactivo `.showcase-wrapper` con navegación por pills superiores (`.showcase-indicators`), controles flotantes ergonómicos y tarjetas de pie descriptivas (`.showcase-caption-card`). Todas las diapositivas comparten la misma paleta de color clínico claro (*Light Mode / Clinical Serenity*):
     - **1a. Tablero Financiero** (`img/showcase-tablero-financiero.png`): Control de ingresos en caja, métricas de recuperación y flujo operativo en tiempo real.
     - **2a. Agenda Semanal** (`img/showcase-agenda-semanal.png`): Reporte interactivo con búsqueda predictiva instantánea por paciente, ordenamiento dinámico multidireccional por columnas, trazabilidad de estados de atención, acciones de edición rápida y exportación ejecutiva directa a Excel, PDF, portapapeles o impresión; respetando el principio de anonimización NOM-004 e HIPAA.
     - **3a. Odontograma** (`img/showcase-odontograma.png`): Refactorizado en tonos clínicos claros (#F8FBFF, azul marino y teal), con mapeo anatómico 3D, selector radial y estandarización visual.
     - **4a. Vista detalle** (`img/showcase-vista-detalle.png`): Refactorizado en tema claro clínico, con exploración sagital en porcelana HD, categorización de patologías y presupuesto instantáneo.
     - **5a. Visor DICOM** (`img/showcase-visor-dicom.png`): Visualizador radiológico avanzado integrado al expediente clínico con reconstrucción tridimensional craneofacial, ajuste de calibradores milimétricos, paleta clara clínica (#F8FBFF y teal) y anonimización rigurosa de datos del paciente conforme a NOM-004 e HIPAA.
5. **Iconografía Holográfica 3D de Módulos del Ecosistema (`img/holo/`)**:
   - Refactorización de las ilustraciones de los 9 módulos de la plataforma para garantizar máxima legibilidad, identidad cohesiva y fusión perfecta con el fondo de las tarjetas (altura 120px, `.holo-module-img`):
     - **Agenda Inteligente** (`img/holo/agenda.png`): Bloque de cristal translúcido biselado con calendario digital 3D, cuadrícula de citas, reloj clínico e iluminación perimetral en neón cyan/teal.
     - **Expediente Clínico 5.0** (`img/holo/expediente.png`): Bloque de cristal biselado con carpeta médica / portapapeles 3D, cruz clínica, monitor de pulso ECG y rótulo de alta legibilidad *"EXPEDIENTE CLÍNICO"*.
     - **Caja Inteligente** (`img/holo/caja.png`): Bloque de cristal biselado con terminal de cobro digital inteligente / caja registradora POS 3D, ranura de tarjeta, teclado numérico, símbolo monetario y rótulo *"CAJA Y FINANZAS"*.
     - **Catálogos Maestros** (`img/holo/catalogos.png`): Bloque de cristal con servidores de base de datos cilíndricos, engranes clínicos, árbol de catálogos CIE-10/servicios y rótulo *"CATÁLOGOS"*.
     - **Visor Radiológico** (`img/holo/visor_radiologico.png`): Bloque de cristal con radiografía ósea digital en neón cyan, calibradores y retículas milimétricas DICOM, y rótulo *"VISOR DICOM"*.
     - **Auditoría y Trazabilidad** (`img/holo/auditoria.png`): Bloque de cristal con escáner biométrico de huella digital, escudo de candado criptográfico, cronología de accesos y rótulo *"AUDITORÍA Y TRAZABILIDAD"*.
     - **Portal del Paciente** (`img/holo/portal_paciente.png`): Bloque de cristal con credencial médica digital, escudo clínico verificado, lista de servicios (citas, laboratorio, recetas) y rótulo *"PORTAL DEL PACIENTE"*.
     - **Mensajería Integrada** (`img/holo/mensajeria.png`): Bloque de cristal con sobre de correo clínico flotante, pulso ECG interno, checkmark de entrega garantizada y rótulo *"MENSAJERÍA INTEGRADA"*.
     - **Alertas WhatsApp** (`img/holo/whatsapp.png`): Bloque de cristal con isotipo de globo conversacional WhatsApp, campana médica de notificación en neón esmeralda y rótulo *"ALERTAS WHATSAPP"*.
   - **Técnica de Difuminado Radial al Blanco (Seamless Card Blending)**: Las 9 imágenes aplican un algoritmo de fundido radial (`smoothstep` entre radio 370px y 485px, más margen perimetral) que degrada matemáticamente cualquier tinte de fondo hacia blanco puro (`#FFFFFF`) en los bordes, eliminando bordes duros y fusionando cada imagen de forma invisible con el fondo de las tarjetas `.holo-card`.
   - **Homologación**: Mismo tamaño (1024x1024), misma perspectiva frontal/isométrica suave, idéntico acabado en cristal acrílico con reflejos de estudio y supresión de elementos satelitales diminutos.
6. **Arquitectura del Menú Principal y Botones de Cabecera (`index.html`, `css/ospulso_master.css`)**:
   - **Distribución Horizontal Unificada (Single Row Navigation)**: El encabezado opera con `.container-fluid.max-w-1400`, garantizando que en resoluciones de escritorio (1280px, 1440px y superiores) los 5 enlaces (`Filosofía 5S`, `Interfaz`, `Ecosistema`, `Migración`, `Planes`) y los botones de acción convivan en una sola fila sin forzar quiebres de línea.
   - **Supresión de Quiebres de Texto (`white-space: nowrap`)**: Se aplica `white-space: nowrap !important;` tanto a los enlaces (`.navbar .menu a`) como a los botones de sesión y acceso, erradicando que términos compuestos como *"Filosofía 5S"* o *"Iniciar Sesión"* se partan en dos renglones.
   - **Dimensionamiento Ergonómico y Compacto de Botones**:
     - `.btn-nav-login`: Botón translúcido suave con borde tenue, tipografía `0.825rem`, padding `0.35rem 0.95rem` y esquinas redondeadas completas (`rounded-pill`).
     - `.btn-nav-cta`: Botón degradado en teal médico (#19B7A5 a #0d9488), tipografía `0.825rem`, padding `0.35rem 1.05rem` y sombra sutil sin sobrecargar visualmente el cuadrante superior derecho.
   - **Gobernanza Tipográfica Antidistorsión**:
     - Carga canónica de Google Fonts (`Outfit` para titulares/menú y `Plus Jakarta Sans` para lectura/subtítulos) mediante `<link rel="preconnect">` y `@import` unificado.
     - Integración de `-webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; text-rendering: optimizeLegibility;` para un renderizado ultra-nítido, eliminando aberraciones, engrosamientos artificiales o deformaciones de fuentes del sistema.







