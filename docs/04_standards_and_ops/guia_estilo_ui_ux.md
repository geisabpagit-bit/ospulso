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
- **Gaveta Lateral Izquierda Flotante en Móvil (`css/sub_sidebar.css`)**:
  - En móviles (`@media (max-width: 991px)`), `.diamond-sidebar` se desvincula de `top: 0` y `height: 100vh`. Pasa a ubicarse inmediatamente después del límite inferior del encabezado principal (`top: 86px !important; bottom: auto !important;`) con altura dinámica ajustada estrictamente a los ítems del rol activo (`height: auto; max-height: calc(100vh - 165px); overflow-y: auto;`).
  - Cuenta con tarjeta flotante redondeada (`border-radius: 1.25rem; width: 275px;`), borde turquesa clínico (`1.5px solid var(--md-teal-clinical)`), fondo satinado y animación suave (`translateX(330px)`), dejando visible y despejado el encabezado principal superior y el bottom navigation inferior.
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
