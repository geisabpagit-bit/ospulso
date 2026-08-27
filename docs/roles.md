# 👥 Definición de Roles SDM (Protocolo RIC-OFE)

Este documento establece la identidad, responsabilidades y alcances de cada actor dentro del ecosistema **Software Dental Mexicano (Diamond Edition)**, siguiendo el estándar de comunicación estructurada.

---

## 1. Administrador Global & Administrador Organización
🔹 **R – Rol**: Gobernanza corporativa, administración multi-tenant y control de catálogo maestro.  
🔹 **I – Instrucción**: Administrar la infraestructura de clínicas/organizaciones, usuarios, catálogos 3NF (Servicios, Productos, Departamentos, Categorías) y configuraciones de respaldo.  
🔹 **C – Contexto**: Entorno SaaS multi-tenant segregado por `id_raiz` / `id_empresa` con control estricto RBAC (UI y API).  
🔹 **O – Output**: Padrón de usuarios, estructura de catálogo universal 3NF en mayúsculas, reportes consolidados y copias de seguridad de la base de datos.  
🔹 **F – Frase ejemplo**: "El estado de suscripción del negocio ha sido validado y los parámetros de sincronización global son correctos."  
🔹 **E – Extra**: Pregúntame si necesitas auditar algún folio específico o modificar permisos de nivel técnico.

---

## 2. Médico
🔹 **R – Rol**: Profesional de la salud dental enfocado en la excelencia clínica y la precisión operativa.  
🔹 **I – Instrucción**: Gestionar la agenda clínica, realizar diagnósticos, ejecutar planes de tratamiento y mantener el expediente clínico actualizado.  
🔹 **C – Contexto**: Interfaz moderna con slots de 30m, reglas de cirugía (bypass de comida) y sincronización con Google Calendar.  
🔹 **O – Output**: Planes de tratamiento (OS), notas de evolución, recetas y visualización de agenda diaria/semanal.  
🔹 **F – Frase ejemplo**: "He reservado la jornada completa para esta cirugía extemporánea siguiendo el protocolo de cirugía del sistema."  
🔹 **E – Extra**: Avísame si detectas alguna colisión de horario que requiera una reubicación manual inmediata.

---

## 3. Recepcionista / Operativo
🔹 **R – Rol**: Coordinador de hospitalidad, flujo operativo, recepción y caja.  
🔹 **I – Instrucción**: Administrar el calendario de citas, gestionar la cobranza (Pre-pago Supuesto A, Cobro directo o Cobro diferido post-consulta) y registrar atención rápida.  
🔹 **C – Contexto**: Registro de usuarios desacoplado de especialidades médicas, emisión de recibos branded con datos CLUE/Sucursal sin paréntesis.  
🔹 **O – Output**: Comprobantes de pago branded (PDF), recordatorios de citas, folios REC y reportes de caja diaria.  
🔹 **F – Frase ejemplo**: "Su cita ha sido confirmada en el sistema y su estado de cuenta refleja el abono realizado hoy bajo el folio REC correspondente."  
🔹 **E – Extra**: Solicita mi intervención si un paciente presenta dudas sobre su historial de saldos pendientes.

---

## 4. Paciente
🔹 **R – Rol**: Usuario final del servicio dental con enfoque en transparencia y seguimiento de salud.  
🔹 **I – Instrucción**: Consultar citas programadas, revisar el historial de tratamientos y validar la transparencia de sus estados de cuenta.  
🔹 **C – Contexto**: Acceso web blindado mediante sesión activa, visibilidad total de folios OS/REC y notificaciones automáticas.  
🔹 **O – Output**: Vista personal de citas, descarga de estados de cuenta en PDF y gestión de perfil básico.  
🔹 **F – Frase ejemplo**: "Deseo consultar el detalle de mi última consulta y verificar el saldo restante de mi tratamiento actual."  
🔹 **E – Extra**: Infórmame si algún dato de mi ficha de identidad debe ser actualizado para mantener mi expediente vigente.

---

## 5. Soporte Técnico
🔹 **R – Rol**: Especialista en infraestructura, despliegue y mantenimiento del ecosistema SDM.  
🔹 **I – Instrucción**: Garantizar la disponibilidad del servidor, auditar logs de error y asegurar la correcta sincronización de APIs externas.  
🔹 **C – Contexto**: Entorno técnico basado en Perl (.pl), scripts de mantenimiento, backups seguros (`auto_backup_` y `ospulso_backup_`) y manejo de permisos de archivos.  
🔹 **O – Output**: Diagnósticos de sistema, parches de seguridad y reportes de integridad de bases de datos.  
🔹 **F – Frase ejemplo**: "La sincronización con la API de Google ha sido restablecida y los permisos de escritura en el directorio `/dat` han sido corregidos."  
🔹 **E – Extra**: Notifícame de inmediato si detectas un error 500 en la terminal o fallos en el motor de autocompletado.

---

## 6. Arquitectura RBAC (Role-Based Access Control)
OSPulso 2.0 opera bajo un modelo **RBAC Nivel 3 (Estricto)**, asegurando que las funciones clínicas y financieras nunca se traslapen indebidamente, garantizando el Principio de Menor Privilegio:

* **Segregación de Funciones**: Un rol (ej. Médico) hereda únicamente los permisos de su dominio (Wizard Clínico). `Administrador Global` y `Administrador Organizacion` poseen derechos CRUD sobre el Catálogo Universal 3NF.
* **UI-RBAC (Frontend Dinámico)**: La interfaz gráfica reacciona activamente al rol de la sesión. 
  * *Ejemplo 1*: En la administración de usuarios, la selección del rol `Recepcionista` oculta los selectores de especialidades médicas.
  * *Ejemplo 2*: En la vista de Catálogo Universal, únicamente los roles de Administración visualizan las acciones de creación, edición y borrado de servicios/categorías.
* **API-RBAC (Protección de Backend)**: Middleware `check_session.pl` y validación implícita de roles en `api/*.pl` (ej. `crud_catalogo_universal_api.pl`, `administracion_usuarios_api.pl`), bloqueando cualquier acceso no autorizado a nivel de endpoints.

---
**GEISABPA - Diamond Edition v4.4.1**
