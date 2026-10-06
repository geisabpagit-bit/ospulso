# Módulo de Comunicación y Correo Masivo Jerárquico (Multi-Tenant)

## 1. Visión General y Propósito
El **Centro de Comunicaciones y Difusión** (`views/comunicacion_masiva.pl`) provee una plataforma integral de mensajería electrónica orientada a la difusión de memorándums, avisos administrativos, campañas preventivas de salud y seguimiento comercial.

Su diseño previene la sobrecarga del servidor y garantiza la reputación del dominio frente a filtros anti-spam (Gmail, Outlook, Yahoo) mediante envíos individualizados, personalización dinámica y despacho asíncrono progresivo por lotes.

---

## 2. Matriz de Gobernanza y Alcance RBAC

El sistema segmenta estrictamente a los destinatarios permitidos en función del rol de la sesión activa:

| Rol Remitente | Audiencia Permitida | Caso de Uso | Restricción / Frontera |
|---|---|---|---|
| **Administrador Global** | • Todos los Administradores de Organización (Dueños de Clínicas)<br>• Equipo de Ventas<br>• Broadcast a todo el personal de la plataforma<br>• Todos los pacientes del ecosistema | Avisos de mantenimiento de servidor, cambios de términos legales, anuncios corporativos. | Acceso absoluto y transversal a todo el SaaS. |
| **Ejecutivo de Ventas** | • Dueños y Administradores de Organización asignados<br>• Leads y Prospectos de CRM | Campañas de prospección comercial, seguimiento a cotizaciones y onboarding. | Acotado a cuentas comerciales; sin acceso a expedientes clínicos. |
| **Administrador de Organización** | • Todo el personal de su clínica (`ID_negocio`)<br>• Médicos de su clínica<br>• Recepción y caja<br>• Todos los pacientes de su organización | Memorándums internos, horarios de días festivos, campañas institucionales de salud. | **Frontera de Tenant:** Estrictamente prohibido acceder a personal o pacientes de otras organizaciones. |
| **Médico** | • Únicamente sus pacientes atendidos (`id_medico`) | Cuidados preventivos estacionales, avisos de cambios en agenda privada. | **Secreto Profesional y NOM-024:** Solo puede contactar a pacientes que hayan recibido atención bajo su cédula. |

---

## 3. Arquitectura Técnica de Despacho Progresivo

```mermaid
flowchart TD
    UI["Vista: comunicacion_masiva.pl"] -->|1. Redacción + Segmento| PREV["Simulador en Vivo"]
    UI -->|2. Iniciar Campaña| API_ENC["api/crear_campana_correo_api.pl"]
    API_ENC -->|3. Registro Rápido < 1s| QUEUE[("dat/cola_correos_masivos.dat")]
    UI -->|4. Peticiones de Lotes AJAX| API_DISP["api/despachar_lote_correos_api.pl"]
    QUEUE -->|5. Lotes de 10 en 10| API_DISP
    API_DISP -->|6. Envíos 1 a 1 con SMTP| SMTP["Servidor SMTP cPanel"]
    API_DISP -->|7. Auditoría| AUDIT[("dat/historial_correos.dat")]
    API_DISP -->>|8. % de Progreso| MODAL["Modal con Barra de Progreso"]
```

### 3.1 Prevención de Bloqueos Anti-SPAM
1. **Envíos Individualizados (1 a 1):** Ningún correo se envía en cadena masiva con `CC` o `BCC`. Cada persona recibe un mensaje dirigido exclusivamente a su dirección con su nombre en el saludo.
2. **Pausas entre Lotes:** El despacho secuencial respeta los límites por hora de cPanel (evitando el baneo del IP del servidor).
3. **Pie de Desuscripción Institucional:** Cumplimiento con estándares internacionales CAN-SPAM.

---

## 4. Variables Dinámicas de Personalización

El redactor soporta las siguientes etiquetas que se sustituyen en el cuerpo del mensaje:

| Variable | Descripción | Ejemplo de Sustitución |
|---|---|---|
| `{{nombre}}` | Nombre de pila o razón del destinatario | Juan Pérez |
| `{{clinica}}` | Nombre comercial de la clínica o SaaS | OSPulso Red Dental |
| `{{medico}}` | Nombre del facultativo tratante | Dr. Roberto Martínez |
| `{{fecha}}` | Fecha en formato legible | 05 Oct 2026 |

---

## 5. Componentes de la Interfaz

* **Vista:** `views/comunicacion_masiva.pl`
* **Estilos Dedicados:** `css/comunicacion_masiva.css` (Diseño de alto contraste institucional: fondo azul marino profundo `#0A2A66` y tipografía blanca nítida `#FFFFFF` con acento turquesa `#19B7A5`).
* **Simulador de Inbox:** Componente reactivo a la derecha que refleja de forma instantánea el asunto, remitente y sustitución de variables en tiempo real.
* **Modal de Progreso:** Animación visual de avance (0% a 100%) que informa los lotes enviados y confirma el éxito de la campaña sin recargar la página.
* **Biblioteca de Plantillas Clínicas:** Catálogo modular con 4 plantillas precargadas (Prevención y Chequeo Anual, Días Festivos, Cuidados Post-Tratamiento y Bienvenida al Portal Digital) con inyección directa de 1-clic al redactor.
* **Termómetro de Salud Anti-SPAM (Spam Score Meter):** Analizador reactivo en tiempo real que evalúa longitud de asunto, mayúsculas, palabras detonantes y presencia de variables para predecir la entregabilidad a bandeja principal (Inbox).
* **Modal de Auditoría Granular:** Visor en tiempo real que desglosa cada destinatario de una campaña, fecha exacta de entrega, reintentos y estados (`ENVIADO`, `PENDIENTE`, `FALLIDO`).

---

## 6. Endpoints y Estructuras de Datos Backend

### 6.1 Endpoints API
* **`api/comunicacion_audiencia_api.pl`**: Calcula de forma dinámica la audiencia según el rol de la sesión activa y deduplica destinatarios válidos omitiendo correos sintácticamente incorrectos.
* **`api/crear_campana_correo_api.pl`**: Registra la campaña en `campanas_comunicacion.dat` y desglosa los registros de los destinatarios en la cola `cola_correos_masivos.dat` en menos de 1 segundo.
* **`api/despachar_lote_correos_api.pl`**: Ejecuta el despacho secuencial por lotes configurables (5 a 10 correos), sustituye dinámicamente las variables de personalización, actualiza los contadores de entrega y registra la auditoría en `historial_correos.dat`.
* **`api/listar_campanas_comunicacion_api.pl`**: Recupera el histórico de campañas filtrado con estricto RBAC (Global vs Tenant vs Médico tratante) en orden cronológico inverso.
* **`api/detalle_campana_comunicacion_api.pl`**: Retorna los metadatos y la lista individualizada de destinatarios en cola de una campaña específica para auditoría forense de entrega.

### 6.2 Estructura Flat-File (`dat/`)
* **`dat/campanas_comunicacion.dat`**:
  `ID_CAMPANA|FECHA|HORA|ID_REMITENTE|USUARIO_REMITENTE|ROL_REMITENTE|ID_NEGOCIO|SEGMENTO|ASUNTO|TOTAL_DESTINATARIOS|ENVIADOS_OK|FALLIDOS|ESTADO`
* **`dat/cola_correos_masivos.dat`**:
  `ID_COLA|ID_CAMPANA|EMAIL_DESTINATARIO|NOMBRE_DESTINATARIO|TIPO_DESTINATARIO|ASUNTO|CUERPO_HTML|ESTADO|INTENTOS|FECHA_ENVIO|ERROR_MSG`

---

## 7. Protocolo de Gobernanza Z-Index y Ciclo de Vida de Modales

Para garantizar accesibilidad total, ergonomía visual y prevenir bloqueos de pantalla por backdrops huérfanos o colisiones con encabezados (`sub_header.pl`):
1. **Jerarquía Z-Index Universal (Anti-Colisión Navbar/Modales/Backdrop)**:
   * **Barras de Navegación y Cabeceras** (`.sdm-navbar`, `.glass-navbar`, `nav.navbar.sticky-top`): `z-index: 1020 !important;`.
   * **Docks Flotantes Inferiores** (`.bottom-bar-dock`, `.nav-dock`): `z-index: 1030 !important;`.
   * **Overlays de Sidebar Lateral** (`.sidebar-overlay`): `z-index: 10400 !important;`.
   * **Telones de Modales** (`.modal-backdrop`, `.modal-backdrop.show`, `.modal-backdrop.fade.show`): `z-index: 105000 !important;`.
   * **Modales Activos y Diálogos** (`.modal`, `.modal.show`, `.dispatch-progress-modal`): `z-index: 105100 !important;`.
2. **Aislamiento de Stacking Context en el DOM**:
   * Los modales (`#modalDespacho`, `#modalAuditoriaCampana`) se ubican estrictamente **después** del cierre de la estructura del layout principal mediante `utils::sub_sidebar::render_sidebar_footer();`. Esto evita que queden atrapados dentro del árbol subordinado del sidebar o del contenedor de la página.
3. **Cierre Multi-Vía y Limpieza de Backdrop**:
   * El modal de despacho integra botón de cierre en cabecera (`#btnCerrarModalX`), botón de éxito en pie (`#btnCerrarModalExito`) y un interceptor de desmonte (`hidden.bs.modal`) que purga cualquier clase residual en `document.body` y elimina backdrops huérfanos en el DOM.
4. **Encoding Puro UTF-8**:
   * Los controladores JSON emiten cabeceras UTF-8 con directiva `use open qw(:utf8);` y flujo `binmode STDOUT, ":raw"` para evitar doble serialización o mojibake de caracteres especiales.



