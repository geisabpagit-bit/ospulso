# 📖 Documentación Maestra SDM v4.2.0
**Software Dental Mexicano - Diamond Edition (The Clinical Standard)**

## 1. Visión v4.2.0 (Liquid Motion)
Esta versión consolida la madurez de la Agenda SPA bajo el concepto "Liquid Motion Healthcare". Se ha logrado una estabilidad absoluta mediante protocolos de blindaje CSS/Perl, una responsividad inteligente que adapta la densidad de información al dispositivo, y una integración profunda de controles administrativos en la navegación móvil WebApp.

## 2. Componentes Críticos

### 2.1 Expediente Clínico Diamond (New)
- **Header Minimalista**: Cabecera (Hero) optimizada que muestra exclusivamente el nombre del paciente, maximizando el área de trabajo y reubicando las acciones principales.
- **Navegación Dock/Sidebar**: Sistema adaptativo que define el orden de pestañas: Citas, Consultas, Ficha, Finanzas, Odonto, Rayos X, Inbox.
- **Arquitectura Anidada (Mini-dock)**: Ficha Técnica, Clínico y SOAP comparten un mini-dock en su cabecera. Esto permite navegar entre ellos fluidamente como un sub-módulo e incluye acceso al Reporte y Guardado.
- **Micro-Interacciones**: Transiciones fluidas entre pestañas mediante el motor `swTab`.

### 2.2 CRM de Comunicaciones y Mensajería
- **Bitácora Inteligente**: Visualización cronológica de correos y notificaciones enviadas.
- **Detalle de Lectura**: Modal de lectura profunda con ID de registro, categoría y asunto.
- **Visor de Adjuntos (Previewer)**: Motor de previsualización integrado para imágenes (JPG/PNG) y documentos PDF sin salir de la plataforma.

### 2.3 Arquitectura "Escape" (Stacking Context Fix)
- **DOM Teleportation**: Los modales críticos se mueven automáticamente al `body` mediante JavaScript para evitar bloqueos por contenedores animados (`animate__fadeIn`).
- **Z-Index Layering**: Jerarquía estricta (Z=7000 para modales, 6900 para backdrops) para visibilidad garantizada en cualquier resolución.

### 2.4 Motor de Trazabilidad Clínica y Blindaje Legal (Agenda ↔ Consultas)
- **Separación de Responsabilidades**: Las citas (logística/calendario) viven en `dat/citas.dat` y las consultas médicas reales (acto clínico) viven en `dat/consultas_clinicas.dat`.
- **Hub de Consultas (`tab10`)**: Interfaz anidada en el expediente que consolida citas programadas por atender (detectando automáticamente citas Confirmadas, Programadas, o No Asistencias), atenciones express (walk-in) y el historial cronológico de notas médicas generadas.
- **Handshake de Estados**: Al finalizar una consulta, el sistema genera un ID único, empaqueta los datos en JSON, y cambia automáticamente el estado de la cita original en la agenda de "Programada" a "Realizada", creando un puente auditable perfecto.
- **Manejo de Citas Extemporáneas ("Tomar Cita")**: Permite al médico atender una cita pasada. El sistema verifica colisiones de horario en tiempo real y reubica la cita al horario actual asignando el estado especial `Atendida (Ext.)`.
- **Blindaje de Notas Médicas (Read-Only)**: Una vez finalizada una consulta, pasa al Historial Clínico. El sistema levanta un modal de "Solo Lectura" inmutable (evitando CRUD destructivo sobre el pasado), garantizando la integridad legal del expediente. Se incluye exportación e impresión del folio clínico.

### 2.5 Navegación Móvil Persistente (WebApp Style)
- **Bottom Navigation Bar (`sub_bottom_nav.pl`)**: Barra de navegación global fija al pie de la pantalla en dispositivos móviles, diseñada para emular la experiencia de una aplicación nativa.
- **Centralización Administrativa**: Integración directa del módulo de **Ajustes** en la barra de navegación, eliminando la redundancia de menús laterales y consolidando el control total del sistema en el pulgar del usuario.
- **Contexto Dinámico e Inteligente**: El menú se reconfigura según el módulo activo para priorizar acciones críticas:
  - **Contexto Pacientes**: Muestra `Inicio`, `+ Nuevo` (Registro rápido), `Citas` y `Ajustes`.
  - **Contexto Agenda**: Muestra `Inicio`, `Nueva Cita` (FAB destacado), `Pacientes` y `Ajustes`.
- **Blindaje de Posicionamiento**: Implementación de `position: fixed !important`, `z-index: 5500` y soporte para `safe-area-inset-bottom` para garantizar visibilidad total y compatibilidad con gestos de sistemas operativos modernos (iOS/Android).

### 2.6 Perfil Mutante (Multi-Role Experience)
- **Interfaz Dinámica**: Unificación de la vista de perfil que alterna entre el Panel de Configuración del Negocio (para Médicos) y la Ficha Clínica Integral (para Pacientes) sin recargar la SPA.
- **Sincronización Transversal**: Motor de persistencia que garantiza que los cambios en el perfil se reflejen en los archivos `.dat` correspondientes según el contexto del usuario.

### 2.7 Blindaje Diamante de Suscripción
- **Acceso Condicional**: Capa de seguridad que invalida el acceso al sistema si el negocio asociado está marcado como inactivo o su fecha de suscripción ha expirado.
- **Garantía Operativa**: Verificación recursiva en el middleware de sesión, impidiendo que usuarios operen en clínicas con licencias vencidas.

### 2.8 Catálogos Oficiales Mandantes (Norma Oficial)
- **Integridad Referencial**: Los catálogos oficiales (ej. Localidades, Entidades, Formación Académica, CLUES) son de solo lectura (`.dat` delimitados). Garantizan la estandarización federal de los datos.
- **Implementación Híbrida UI/UX**: Se utilizan técnicas de **Databinding Unidireccional** (ej. Código Postal auto-llenando Entidad/Municipio) y **Autocomplete Nativo (Datalist)** (ej. Formación Académica) para manejar de forma eficiente miles de registros sin ralentizar la interfaz, inyectando silenciosamente las llaves primarias (`CATALOG_KEY`) hacia el backend.
- **Transaccionalidad Aislada**: Las selecciones de catálogos se almacenan en tablas relacionales uno-a-uno como `perfiles.dat` (para la metadata del Médico Especialista) o `negocios.dat` (para ubicaciones), preservando la ligereza de la tabla central `usuarios.dat`.

## 3. Guía de Arquitectura
- **Backend**: Perl Modular con procesamiento de adjuntos en `/dat/adjuntos_crm/`.
- **Frontend**: SPA con Vanilla JS, Bootstrap 5 y Animate.css.
- **Estilos (CSS)**: Estricta separación de estilos en archivos `.css` independientes (ej. `expediente_completo.css`), eliminando los bloques en línea en scripts `.pl`.
- **Seguridad**: Validación de sesión en tiempo real, cifrado SHA-256 y blindaje de suscripción circular.

## 5. Historial de Ajustes Técnicos Recientes (v4.2.0)
- **Engine Liquid Motion**: Implementación de animaciones staggered y segmentación horaria en la agenda.
- **Smart Weekly View**: Refactorización del motor de renderizado para visualización adaptativa (3 días móvil / 7 días tablet).
- **Smart Drag & Drop**: Implementación de reubicación manual asistida en la vista mensual, con algoritmo pre-cálculo de colisiones y bloqueo absoluto de programación en horarios pasados.
- **Stability Guard (Protocolo 13)**: Blindaje de caracteres especiales en interpolación Perl para evitar Errores 500.
- **Ergonomía de Modales**: Implementación global de `max-height` y scroll interno para prevenir desbordes de pantalla.
- **Admin Mobile Integration**: Migración del control de ajustes a la barra de navegación inferior (`sub_bottom_nav.pl`).
- **DataTables Diamond Style**: Estandarización de 4 botones de exportación (Copiar, Excel, PDF, Imprimir) alineados a la izquierda.


### 🔐 Módulo de Acceso Diamond (Implementación May-2026)
*   **Seguridad**: Blindaje contra inyección de cabeceras en redirecciones y validación de sesiones con el nuevo `render_error_sesion`.
*   **Registro Sincronizado**: Unificación de la experiencia de éxito para registros con y sin OAuth de Google.
*   **Persistencia de Datos**: Uso de `flock` para el contador de IDs y garantía de integridad de saltos de línea (`\n`) en archivos `.dat`.
*   **Validación Proactiva**: Sistema de debounce (600ms) para verificar existencia de correos en tiempo real sin saturar el servidor.
**Software Dental Mexicano - Diamond Edition v4.2.0**
