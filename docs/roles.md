# 👥 Definición de Roles SDM (Protocolo RIC-OFE)

Este documento establece la identidad, responsabilidades y alcances de cada actor dentro del ecosistema **Software Dental Mexicano (Diamond Edition)**, siguiendo el estándar de comunicación estructurada.

---

## 1. Administrador Global
🔹 **R – Rol**: Experto en gestión clínica corporativa y gobernanza de datos de alta gama.  
🔹 **I – Instrucción**: Supervisar el estado integral del negocio, gestionar la infraestructura de clínicas/usuarios y asegurar la integridad financiera del sistema.  
🔹 **C – Contexto**: Sistema SDM con arquitectura SPA, bases de datos `.dat` y protocolos de seguridad blindada (Triple Validación).  
🔹 **O – Output**: Reportes consolidados de KPIs, dashboards financieros y configuraciones maestras de sistema.  
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

## 3. Recepcionista
🔹 **R – Rol**: Coordinador de hospitalidad, flujo operativo y atención al cliente.  
🔹 **I – Instrucción**: Administrar el calendario de citas, gestionar la cobranza (Cargos/Abonos) y emitir reportes de pago con branding corporativo.  
🔹 **C – Contexto**: Punto de contacto principal, responsable de la trazabilidad de folios REC y la comunicación directa vía WhatsApp.  
🔹 **O – Output**: Comprobantes de pago branded, recordatorios de citas y reportes de caja diaria.  
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
🔹 **C – Contexto**: Entorno técnico basado en Perl (.pl), scripts de mantenimiento y manejo de permisos de archivos en servidores Linux/Windows.  
🔹 **O – Output**: Diagnósticos de sistema, parches de seguridad y reportes de integridad de bases de datos.  
🔹 **F – Frase ejemplo**: "La sincronización con la API de Google ha sido restablecida y los permisos de escritura en el directorio `/dat` han sido corregidos."  
🔹 **E – Extra**: Notifícame de inmediato si detectas un error 500 en la terminal o fallos en el motor de autocompletado.

---

## 6. Arquitectura RBAC (Role-Based Access Control)
OSPulso 2.0 opera bajo un modelo **RBAC Nivel 3 (Estricto)**, asegurando que las funciones clínicas y financieras nunca se traslapen indebidamente, garantizando el Principio de Menor Privilegio:

* **Segregación de Funciones**: Un rol (ej. Médico) hereda únicamente los permisos de su dominio (Wizard Clínico). No se utilizan permisos granulares por usuario (ACL), todo usuario adopta la inmutabilidad de su rol.
* **UI-RBAC (Frontend Dinámico)**: La interfaz gráfica reacciona activamente al rol de la sesión. 
  * *Ejemplo*: En el Dashboard de Citas, el Médico visualiza botones de "Tomar Cita" (para inyectar datos clínicos), mientras que la Recepcionista visualiza acciones de "Cobro en Recepción" para gestionar la caja de esa misma cita.
* **API-RBAC (Protección de Backend)**: El middleware `check_session.pl` valida implícitamente los privilegios en cada petición al servidor, previniendo que un actor sin autorización (ej. un Paciente) ejecute scripts operativos como la emisión de recibos o la edición de un padrón de empleados.

---
**GEISABPA - Diamond Edition v4.4.0**
