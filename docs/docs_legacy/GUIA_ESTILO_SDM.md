# 🎨 GUÍA DE ESTILO SDM PREMIUM (v4.2.0) - "Liquid Motion & Diamond Excellence"

> [!IMPORTANT]
> **PROTOCOLO DE INTEGRIDAD CRÍTICA**: Este documento es de carácter **ACUMULATIVO**. Prohibido eliminar, recortar o sobrescribir secciones históricas al realizar actualizaciones. Toda nueva versión debe fusionar el contenido previo con las nuevas especificaciones para garantizar la trazabilidad del diseño "Diamond Edition".

Este documento define el estándar visual y de interacción obligatorio para **Software Dental Mexicano**. El estándar **Diamond Edition v3.7.4** garantiza una experiencia de usuario fluida, responsiva y totalmente dinámica.

## 1. Fundamentos Visuales (Design Tokens)

### 1.1 Paleta de Colores Institucionales
| Uso | Variable | HEX | Aplicación |
| :--- | :--- | :--- | :--- |
| **Primario (Navy)** | `--sdm-navy` | `#0d1e3d` | Navbar, Headers, Textos de título. |
| **Acción (Blue)** | `--sdm-primary` | `#3b82f6` | CTAs, Iconos activos, Autocompletado. |
| **Éxito (Green)** | `--sdm-success` | `#10b981` | Finanzas positivas, Citas confirmadas. |
| **Peligro (Red)** | `--sdm-danger` | `#ef4444` | Alertas, Cargos financieros, Cancelaciones. |
| **Fondo (Sand)** | `--sdm-bg` | `#f8fafc` | Fondo general (más claro y moderno). |
| **Contraste (White)** | `--sdm-white` | `#ffffff` | Modales, Cards, Fondo de Offcanvas. |
| **Impresión** | `--sdm-print-black` | `#000000` | Color obligatorio para textos en reportes físicos. |

### 1.1.1 Paleta Mandante: "MedentIA Diamond Healthcare"
> [!IMPORTANT]
> **Paleta Definitiva para UI Premium**: Para invocar esta estética en el futuro, solicita al agente utilizar la paleta **"MedentIA Diamond Healthcare"**. Esta combinación se basa en el archivo `css/medentia_master.css` y es el estándar mandante para elementos de interacción, "Premium Glassmorphism" y menús de navegación.

| Variable CSS | HEX | Nombre | Aplicación Mandante |
| :--- | :--- | :--- | :--- |
| `--md-teal-clinical` | `#19B7A5` | Teal Clínico | Color base unificado para Iconos en reposo (Healthcare feel). |
| `--md-blue-deep` | `#0A2A66` | Azul Profundo | Texto en hover/activo, íconos en hover, parte oscura de gradientes. |
| `--md-blue-medical` | `#124A9E` | Azul Médico | Base principal de botones CTA y parte clara de gradientes activos. |
| `--md-cyan-ia` | `#18D1E6` | Cyan IA | Iconos en estado Activo (Efecto "encendido" o Glow). |

*Uso de Glassmorphism (Aura):* Para crear fondos translúcidos al hacer hover, se debe usar la variante `rgba` de estos colores con una opacidad del `0.05` a `0.08` combinada con `backdrop-filter: blur(10px)`.

### 1.1.2 Estándar de Contenedores y Formularios (Diamond Armor)
- **Tarjetas y Cajas (ej. `.card-medentia`, `.card-medentia-aura`)**: Deben portar obligatoriamente un borde sólido de `1px` en color **Teal Clínico** (`#19B7A5`) para delimitar el área con estética médica. 
- **Sombras**: Utilizar sombras profundas (10% más oscuras que la sombra base). El estándar es `box-shadow: 0 10px 30px rgba(10, 42, 102, 0.15)` en reposo y `0.18` al hacer hover.
- **Formularios (Inputs)**: Fondo "Blanco Clínico" (`#F8FBFF`) en reposo, cambiando a borde "Teal Clínico" (`#19B7A5`) al recibir foco (clase `.diamond-input-armor`).

### 1.2 Tipografía
- **Títulos**: `Plus Jakarta Sans`, Sans-serif (800/900 Extra Bold).
- **Cuerpo**: `Inter`, Sans-serif (400 Regular / 600 Semi Bold).
- **Cifras**: `Inter` / `Plus Jakarta Sans` con espaciado ajustado.

## 2. Arquitectura de Navegación (Universal)

### 2.1 Cabecera Unificada (WebApp)
- **Modo Mobile (< 768px)**:
  - **Orden (L -> R)**: 1. Buscador Unificado | 2. Icono de Usuario (Trigger Sidebar).
  - **Buscador**: Fondo oscuro/transparente con icono de lupa persistente.
- **Modo Desktop (>= 768px)**:
  - **Buscador**: Centrado.
  - **Logo GEISABPA**: Alineado a la izquierda con enlace a `inicial.pl`.
  - **Dropdown de Usuario**: Debe inicializarse manualmente con `new bootstrap.Dropdown()` para garantizar operatividad.

### 2.2 Menú de Navegación Inferior (Persistent Nav - Mobile Only)
1. **Inicio** (`bi-house-door`): Acceso al Dashboard Principal.
2. **Botón de Acción Principal (FAB Style)**:
   - **Modo Pacientes**: `+ Nuevo` (`bi-person-plus-fill`) → Registro rápido de pacientes.
   - **Modo Agenda**: `Nueva Cita` (`bi-plus-circle-fill`) → Apertura de modal de citas.
3. **Agenda / Citas** (`bi-calendar3`): Acceso a la Agenda Clínica SPA.
4. **Contexto Activo**: Muestra el módulo actual (ej. Pacientes `bi-people-fill`) para orientación del usuario.
- **Estilo**: `position: fixed !important`, `z-index: 5500`, fondo con `backdrop-filter: blur(10px)` y sombra suave.

## 3. Componentes de Alta Gama

### 3.1 Minimalist Patient Header (Diamond v3.8.0)
- **Diseño Ultra-Limpio**: La cabecera del expediente se reduce a su mínima expresión mostrando exclusivamente el nombre del paciente, eliminando insignias, identificadores y botones flotantes para maximizar el área de trabajo vertical.
- **Reubicación de Acciones**: Las llamadas a la acción principales fueron reubicadas de manera contextual: "+ Consulta" vive en el encabezado de "Citas", mientras que "Reporte" y "Guardar Cambios" radican en la sub-navegación anidada.
- **Padding Estilizado**: Reducción de espaciado y eliminación de márgenes negativos para que el Dock fluya naturalmente debajo de la cabecera.

### 3.2 Dashboard Bento y KPI Cards
- **KPI Cards (Grid 2x2)**: 
  - Bordes redondeados de `20px`.
  - Iconos en cajas de color pastel (subtle colors).
  - **Protocolo de Montos**: Cantidades ≥ $1,000 se expresan en "k" (ej: $ 3.59k).
- **Módulos de Gestión (List View)**: Tarjetas horizontales de `24px` de radio, sincronizadas con `menu_cards.dat`.

### 3.3 Reporte Corporativo (Print Standard)
- **Header**: Título de negocio en Navy/Black con borde inferior de 3px.
- **Body**: Tabla de movimientos con fuente de 8pt, celdas en negro puro y bordes sutiles.
- **Footer**: Resumen consolidado con línea de separación gruesa (`tfoot`).

## 4. Gestión de Agenda Clínica (SPA Engine)

### 4.1 Navegación y Cabecera Dinámica
- **Selector de Vistas**: Día (`bi-calendar-event`), Semana (`bi-calendar-range`), Mes (`bi-calendar-month`).
- **Navegación Temporal**: Actualización dinámica de etiquetas (HOY, MAÑANA, AYER).
- **Colores del Calendario**: Azul (Laborables), Rojo (Festivos), Gris (Fines de semana).

### 4.2 Vista Diaria (Split View)
- **Panel Izquierdo (30%)**: Mini-calendario interactivo para selección rápida de fecha.
- **Panel Derecho (70%)**: Timeline de horas con scroll vertical e intervalos de 30 min.

### 4.3 Vistas de Lista (DataTables - Semana y Mes)
- **Filtros Dinámicos**: Por día, semana o mes según la vista activa.
- **Iconos de Exportación (IZQUIERDA)**: PDF, Excel, Copiar, Imprimir (usando colores institucionales).
- **Buscador Integrado (DERECHA)**: Filtrado instantáneo en cliente.
- **Adaptación Mobile**: Los registros tabulares deben transformarse en formato **MiniCard** responsivo.

### 4.4 Modal "Gestión de Citas"
- **Paciente**: Autocompletado blindado (estilo search-as-you-type).
- **Disponibilidad**: Basada en `agenda_config.dat`.
- **Slots Horarios**: Botones dinámicos (Gris=Pasado, Rojo=Ocupado, Azul=Seleccionado).

## 5. Animaciones y Micro-interacciones
- **Counter-Up**: Animación incremental de valores numéricos al cargar.
- **Staggered Entry**: Aparecimiento secuencial de elementos (delay de `100ms`).
- **Haptic Feedback**: Efecto de escala (`0.97`) al presionar elementos interactivos.
- **Glow Status**: Brillo dinámico sutil en badges (`glow-success`).

## 6. Responsividad y Protocolos Técnicos
- **Zero Overflow**: Prohibido el scroll horizontal (`overflow-x: hidden`).
- **Separación de CSS**: Estricta prohibición de bloques `<style>` dentro de scripts `.pl`. Todos los estilos específicos (ej. `expediente_completo.css`) deben modularizarse y ubicarse en el directorio `/css/`.
- **SDA-11.1 Paths**: Uso obligatorio de rutas absolutas mediante `$FindBin::Bin`.
- **No d-none in Print**: Prohibido ocultar detalles de movimientos en la vista de impresión.
- **Perl Interpolation**: Escapar siempre el símbolo `@` como `\@media` cuando (excepcionalmente) haya que inyectar CSS en heredocs.

## 7. Protocolo de Exportación Corporativa (DataTables Diamond)
Para mantener la identidad institucional en documentos físicos y digitales, toda exportación debe cumplir con:

### 7.1 Barra de Herramientas Estándar
- **Componentes**: Debe incluir obligatoriamente 4 botones: `COPIAR`, `EXCEL`, `PDF` e `IMPRIMIR`.
- **Estética**: Se prohíbe el estilo nativo gris de DataTables. Todos deben envolverse en un contenedor `export-toolbar` (con `backdrop-filter` Glassmorphism) y cada botón con clase `btn-export`.
- **Responsividad**: La barra debe usar `flex-wrap` para ajustarse en dispositivos móviles sin desbordar el contenedor.
- **ExportOptions**: Por norma general, excluir siempre la columna de "Acciones" (generalmente la última) usando `exportOptions: { columns: [0, 1, 2, 3] }` u omitiendo la columna de los botones HTML para evitar ensuciar los reportes.

### 7.2 Estándar PDF (pdfmake) y DataTables (Fixes Críticos)
- **Encabezados**: Color de fondo `--sdm-navy` (`#0d1e3d`) con texto blanco y negrita.
- **Integridad de Arrays (docMeasure.js TypeError)**: 
  - ¡NUNCA reescribir ni aplicar `filter` directamente al arreglo `doc.content` original que inyecta DataTables! Esto corrompe las referencias de memoria de pdfMake.
  - Para encontrar la tabla y aplicarle estilos: iterar con un `for` o `findIndex` sobre `doc.content` buscando `node.table`.
  - Para borrar encabezados basura inyectados por DataTables: usar `splice(0, tableIndex)` de forma segura.
  - **Widths Exactos**: Siempre asignar la misma cantidad de `widths` que columnas exportadas (`doc.content[tableIndex].table.widths = [...]`). De lo contrario, `pdfMake` lanzará TypeError en `_minWidth`.

### 7.3 Reglas Globales de Impresión
Todos los reportes y exportaciones deben seguir al pie de la letra `Reglas_impresion.md`, inyectando:
1. Nombre del Hospital y Módulo en la Cabecera.
2. Fecha dinámica de generación en formato DD/MM/AAAA.
3. Aviso legal de Confidencialidad y Código Interno de área en los pies de página.

## 8. Arquitectura de Interfaces "Dashboard Horizontal"
Los Canvas/Offcanvas tipo "Resumen de Expediente" dejan de ser apilamientos verticales.
- Deben presentarse en layout compacto ("Zoom 80%" o base `0.85rem`).
- **KPIs (Bento)**: En Grid 1x3 estricto (`flex-nowrap`, `col-4`) para Cargos, Abonos y Saldo, unificando color de fondo tenue. *Protocolo Diamond Armor*: Estas tarjetas deben incluir un borde sólido `2px solid var(--md-teal-clinical) !important;`.
- **Toolbar Operativa**: Uso de Grid o flexbox ajustado. Los botones de acción principal (Correo, Cita, Expediente, etc.) deben basarse en la clase `.btn-toolbar-medentia` la cual comparte la estética **Glassmorphism Hover** de la navegación lateral (Fondo transparente, icono Teal Clínico y transición *cubic-bezier*; al hacer hover: fondo Cyan IA translúcido con blur, borde Cyan, texto Azul Profundo y expansión `scale(1.05)`).
- **Historial Horizontal**: Los listados históricos (tarjetas `.card-consulta`) deben manejarse como Carruseles Flexibles portando el borde `2px solid var(--md-teal-clinical) !important;`, con botones Chevron de navegación por JS y ocultando la scrollbar nativa.
- **Títulos**: Centrados, en mayúsculas y con tipografía institucional.
- **Pie de Página**: Obligatorio incluir la fecha de generación (L) y la numeración de páginas (R) en color gris suave (`#64748b`).
- **Cuerpo**: Tamaño de fuente reducido (9pt) para maximizar la visibilidad de datos.

### 7.3 Estándar Excel (JSZip)
- **Títulos**: La primera celda (A1) debe contener el nombre del reporte en negrita.
- **Formato**: Ajuste automático de columnas y celdas limpias sin bordes innecesarios.

## 8. Protocolo de Superposición (Stacking Context Fix)
Para evitar que los modales queden "detrás" del fondo oscuro (backdrop) en contenedores con animaciones o filtros, se aplica el **DOM Teleportation Protocol**:
- **Acción**: Antes de mostrar cualquier modal crítico (`modalCargo`, `modalAbono`, `modalMensaje`), el script debe verificar si el elemento es hijo directo del `body`.
- **Implementación**: `if (modalEl.parentElement !== document.body) document.body.appendChild(modalEl);`
- **Z-Index Standard**: Modales (7000), Backdrops (6900).

## 9. Diamond Clinical Dashboard (v3.8.0)
- **Navegación Sidebar (Mobile)**: Menú lateral con efecto `backdrop-filter: blur(30px)` y ancho adaptativo de 290px.
- **Orden del Dock**: La jerarquía estandarizada de izquierda a derecha es: Citas, Consultas, Ficha, Finanzas, Odonto, Rayos X, Inbox.
- **Sub-navegación Anidada (Mini-dock)**: Ficha Técnica, Dashboard Clínico (Bento) y SOAP están interconectados mediante un mini-dock interno tipo píldora (`bg-light rounded-pill border`). Este sub-módulo contiene botones grises para pestañas y botones institucionales de **Reporte** y **Guardar Cambios** (fondo azul marino `--sdm-navy`, texto blanco).
- **CRM Communications**: Listado de mensajes con iconos de estado y visor de adjuntos (Previewer) integrado en modal.
- **Contextual Actions**: Botones de acción rápida dentro de tablas (Abonar ítem, Agregar a OS) con iconos iconográficos (`bi-cash-coin`, `bi-folder-plus`).

## 10. Mobile Ultra-Premium Architecture (v3.8.0)
Para ofrecer una experiencia de gama alta en teléfonos inteligentes, se implementan los siguientes estándares:
- **Inline Menu Toggle**: El botón para desplegar el menú lateral (`bi-list`) vive integrado orgánicamente en el `diamond-header` en la esquina superior derecha, erradicando botones flotantes (FAB) intrusivos que saturaban la pantalla inferior.
- **Density Optimization**: Reducción de fuentes base a `0.85rem` y paddings internos de contenedores a `1.2rem` en dispositivos móviles.
- **Sidebar Auto-Close**: El menú lateral debe cerrarse automáticamente tras la selección exitosa de una pestaña para optimizar el área de trabajo.
- **Haptic Touch Targets**: Los botones e iconos deben tener un área mínima de interacción de `44x44px` y efecto de escala al presionar.

## 11. Aura Design & Bento WebApp Experience (Mobile)
Para lograr una experiencia de alta gama en dispositivos móviles, se implementa el protocolo **Aura Design**:

### 11.1 Tarjetas de Información (Bento Style)
- **Fondo**: Degradado lineal `linear-gradient(180deg, #f0f7ff 0%, #ffffff 100%)`.
- **Borde de Cristal**: Borde sutil de `1px solid rgba(59, 130, 246, 0.12)`.
- **Sombras con Matiz**: Sombras difusas con tinte azulado `rgba(59, 130, 246, 0.08)`.
- **Transparencia**: Uso obligatorio de `background: transparent !important` en celdas (`td`) para permitir la visibilidad del degradado de la fila (`tr`).
- **Densidad**: Padding interno de `0.8rem` y margen entre tarjetas de `0.75rem` para maximizar el uso de pantalla.
- **Hojeada Táctica**: Los listados de movimientos (OS/REC) deben mostrar el badge de estado (`Pagado`, `Pendiente`) con colores contrastantes para una lectura rápida.

### 11.2 Optimización de Interacción (Clean UX)
- **Búsqueda Dinámica**: Al activar el buscador global, el paginador y la información de registros de DataTables deben ocultarse mediante un efecto de fundido (`fadeOut`) para centrar la atención en los resultados.
- **Haptic Active State**: Las tarjetas deben reaccionar al tacto con una escala de `0.98` y un cambio de color a `#e6f0ff`.
- **Zero Wasted Space**: Eliminación de paddings superiores y laterales excesivos en contenedores `container-fluid` para que el contenido fluya desde los bordes.

## 12. Formularios Premium (Diamond Floating Labels)
Para los módulos de alta densidad (Agenda, Ficha), se aplica el estándar **Floating Armor**:
- **Etiquetas Flotantes**: Tamaño reducido a `0.65rem` con tipografía en mayúsculas y color tenue para no distraer.
- **Input Styling**: Bordes redondeados de `1rem (16px)`, fondo `bg-light` (`#f8fafc`) y eliminación de bordes visibles al estar inactivos.
- **Slim Duration Bar**: Los selectores de duración (`dur-bar-premium`) deben ser compactos, utilizando botones de tipo *pill* con bordes sutiles y estados activos en azul institucional.
- **Cuadrícula de Slots**: Visualización compacta en 3 columnas para móviles, con un contenedor de altura limitada (`max-height: 120px`) y scroll interno para mantener el modal dentro de los límites de la pantalla sin necesidad de scroll global.
- **Jerarquía de Capas (Z-Index Armor)**:
  - Alertas y Popups (SweetAlert2): `5000` (Debe flotar sobre todo).
  - Modales Críticos: `4100`.
  - Backdrops: `4050`.

## 13. Protocolos de Desarrollo y Estabilidad (Error 500 Guard)
Para garantizar la alta disponibilidad de la plataforma y evitar errores de servidor (HTTP 500), todo desarrollo debe cumplir con:

### 13.1 Blindaje de Interpolación Perl (CSS)
Al inyectar bloques de CSS o JavaScript dentro de scripts Perl (`.pl`) mediante cadenas de doble comilla o bloques `HERE-DOC` (ej. `print <<HTML;`), los símbolos `@` son interpretados como arreglos (arrays).
- **Protocolo**: Es obligatorio escapar todo símbolo `@` anteponiendo una barra invertida `\`.
- **Ejemplos**: `\@media`, `\@keyframes`, `\@import`.
- **Riesgo**: Omitir este escape provoca un error de compilación inmediato (`Global symbol "@..." requires explicit package name`).

### 13.2 Portabilidad y Ejecución Unix/Linux
Para asegurar que los scripts funcionen sin modificaciones en servidores Windows (XAMPP) y entornos Unix (Producción), se deben seguir estos lineamientos:
- **Shebang Universal**: Todo script debe iniciar con `#!/usr/bin/perl` (o la ruta correspondiente al entorno).
- **Integridad de Rutas (FindBin)**: No utilizar rutas relativas (`./api/`) para carga de librerías. Usar siempre:
  ```perl
  use FindBin;
  use lib "$FindBin::Bin/.."; # O la ruta al core del sistema
  ```
- **Line Endings (EOL)**: Los archivos deben guardarse con formato de fin de línea **LF** (Unix) para evitar el error `\r: command not found` al ejecutar en servidores Linux.

## 14. Liquid Motion Healthcare Design (v4.2.0)
Para proyectar una imagen de tecnología médica de vanguardia, se aplica el motor de diseño **Liquid Motion**:
- **Staggered Entry**: Las tarjetas de días y slots deben aparecer con un retraso secuencial (`animation-delay`) de `0.03s` entre elementos, creando un efecto de "ola" al cargar.
- **Visual Segmentation**: La cuadrícula de horarios se divide en secciones visuales claras (MAÑANA, TARDE, NOCHE) con iconos descriptivos para facilitar el escaneo rápido.
- **Healthcare Color Palette**: Uso de degradados suaves (`#103070` a `#3b82f6`) en elementos activos para transmitir confianza y modernidad.

## 15. Smart Responsive Density (Agenda)
La visualización de la agenda se adapta dinámicamente a la densidad de píxeles:
- **Mobile (3-Day View)**: Centrado obligatorio de 3 días para mantener legibilidad absoluta de los números de fecha.
- **Tablet/Desktop (7-Day View)**: Centrado equilibrado de la semana completa.
- **Floating Controls**: El botón "Hoy" y los toggles de vista en móvil flotan en una barra superior compacta, eliminando ruido visual.
- **Modal Ergonomics**: Todos los modales deben tener un `max-height: 92vh` con scroll interno en `modal-body` para evitar que el contenido rebase el viewport.


## 💎 Componentes Diamond Edition (Actualización v4.2)

### 1. Sistema de Alertas y Éxito
*   **Modal de Éxito Diamond**: Utiliza una estructura Bento con `border-radius: 2.5rem`, sombra profunda (`shadow-premium`) e iconos con animación `pulse`.
*   **Variantes de Registro**:
    *   *Registro Estándar*: Título "¡Registro Exitoso!".
    *   *Registro con OAuth*: Título "¡Registro y Conexión Exitosa!" con nota de sincronización en verde médico.

### 2. Protocolos Técnicos de Estilo
*   **Protocolo 13 (Escape Crítico)**: Es obligatorio escapar el símbolo `@` como `\@` en cualquier bloque de texto Perl (`qq`, `print <<HTML`, etc.) que contenga CSS (`@keyframes`) o direcciones de correo para evitar errores de compilación.
*   **Integridad UTF-8**: Se debe forzar `binmode(STDOUT, ":utf8")` en todos los puntos de entrada para garantizar la visualización correcta de caracteres especiales (ñ, á, é).

### 3. Paleta Médica Refinada
*   **Verde Médico (Validación)**: `#00b894` (Fuerte, para botones de éxito y validaciones).
*   **Azul Deep MedentIA**: `#124A9E` (Color mandante para acciones primarias).
*   **Rojo Alerta**: `#ef4444` (Para tarjetas de acceso denegado y errores críticos).

### 4. Animaciones Aura
*   **Hover Dinámico**: Los botones `btn-medentia-action` deben invertir su contraste y escalar suavemente al 1.02% en eventos de hover.
*   **Icon Pulse**: Los iconos de alerta o éxito deben tener una micro-animación de pulso suave para guiar la atención del usuario.
**GEISABPA - Diamond Edition v4.2.0**
