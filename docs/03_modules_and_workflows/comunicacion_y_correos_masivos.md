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
* **Estilos Dedicados:** `css/comunicacion_masiva.css`
* **Simulador de Inbox:** Componente reactivo a la derecha que refleja de forma instantánea el asunto, remitente y sustitución de variables en tiempo real.
* **Modal de Progreso:** Animación visual de avance (0% a 100%) que informa los lotes enviados y confirma el éxito de la campaña sin recargar la página.
