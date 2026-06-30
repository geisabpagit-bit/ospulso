# Checklist de Especificaciones por Módulos

## Módulo 1: Acceso al portal web
- [ ] Autenticación segura (usuario/contraseña, SSO, MFA)  
- [ ] Gestión de roles (paciente, médico, recepcionista, administrador)  
- [ ] Alta disponibilidad y monitoreo de uptime  
- [ ] Seguridad: cifrado de datos, auditoría de accesos  

---

## Módulo 2: Agenda electrónica (v3.1.6 GOLD)
- [X] Selección de especialidad y horario por paciente  
- [X] Gestión de disponibilidad médica (bloques, cancelaciones)  
- [X] Interfaz para recepcionista (SPA - Split View / MiniCards Mobile)  
- [X] Notificaciones automáticas de cita y recordatorios (Simulación visual completa)  
- [X] Botones de acción rápida: Expediente, Ir a Consulta, Ficha, Eliminar.
- [X] Sistema Smart-Drag (Selección por clic único para mover citas).
- [X] Navegación Iconográfica: Switch de vistas por iconos y botón HOY independiente.
- [X] UI Premium: Alineación DataTables (Iconos Izq / Buscador Der).
- [X] Autocomplete Seguro: Filtrado por médico y blindaje de edición.
- [X] **Liquid Motion Healthcare (v4.2.0)**: Animaciones staggered y segmentación horaria (Mañana/Tarde/Noche).
- [X] **Smart Responsive Density**: Adaptación automática de 3 días (móvil) y 7 días (tablet+).
- [X] **Admin Sync**: Integración de ajustes en el menú inferior persistente para WebApp Experience.
- [X] **Stability Guard**: Blindaje contra Error 500 (CSS Escape) y ergonomía de modales (92vh).

---

## Módulo 3: Recepción y check-in
- [ ] Registro de llegada (QR, código, manual)  
- [ ] Validación de cita por recepcionista (opcional)  
- [ ] Supervisión administrativa de consultorios  

---

## Módulo 4: Consulta médica (v3.8.0 Diamond Excellence)
- [X] Expediente clínico digital unificado (SPA)
- [X] CRM de Comunicaciones con historial de envíos
- [X] Visor de Adjuntos integrado (PDF/JPG/PNG)
- [X] Navegación híbrida (Dock en Desktop / Sidebar en Mobile)
- [X] Gestión de Ficha Técnica Maestra (CRUD en tiempo real)

---

## Módulo 5: Laboratorio
- [ ] Procesamiento de estudios  
- [ ] Carga de resultados al expediente  
- [ ] Integración financiera (cargos automáticos)  
- [ ] Interoperabilidad HL7/FHIR  

---

## Módulo 6: Farmacia digital
- [ ] Validación de recetas médicas  
- [ ] Control de inventario y caducidad  
- [ ] Integración financiera automática  

---

## Módulo 7: Área de seguros
- [ ] Autorización de procedimientos  
- [ ] Aplicación de coberturas y abonos  
- [ ] Ajuste automático de estados de cuenta  
- [ ] Integración con aseguradoras vía API  

---

## Módulo 8: Estados de cuenta (v3.8.0 Path to Excellence)
- [X] Consulta de cargos y abonos con folios estructurados (OS/REC).
- [X] Cobranza Contextual: Liquidación por ítem o total en un solo clic.
- [X] **Branded Reporting v3.7.4**: Impresión blindada con detalle de movimientos y branding de clínica.
- [X] UI Premium: Botones integrados en el perfil del paciente visibles en Desktop/Tablet/Mobile.
- [X] Seguridad: API blindada con validación de sesión obligatoria.
- [X] Trazabilidad: Totales consolidados al pie de la tabla de movimientos.
- [ ] Integración de pasarelas de pago externas (Fase Futura).

---

## Módulo 9: Seguimiento y segunda cita
- [ ] Recordatorios automáticos al paciente  
- [ ] Programación de seguimiento por médico  
- [ ] Confirmación de cita por recepcionista (opcional)  
- [ ] Notificaciones seguras (correo, SMS, app)  

---

## Módulo 10: N consultas / atención continua (v3.8.0)
- [X] Historial clínico y financiero accesible al paciente (Timeline Diamond)
- [X] Documentación de evolución médica (SOAP Preview)
- [X] Comunicación logística y CRM (Msjs Tab)
- [X] Supervisión administrativa de calidad (Control de Folios)
- [X] Garantía de integridad de datos (Perl Secure Endpoints)
- [X] Soporte para adjuntos clínicos (Visor Maestro)

---

## Consideraciones transversales
- [ ] Cumplimiento normativo (HL7, FHIR, HIPAA, NOM-024)  
- [ ] Escalabilidad modular (despliegue independiente por módulo)  
- [ ] Interoperabilidad mediante APIs abiertas  
- [ ] UX/UI accesible y responsiva  
- [ ] Monitoreo y métricas (dashboards clínicos, financieros, técnicos)  
