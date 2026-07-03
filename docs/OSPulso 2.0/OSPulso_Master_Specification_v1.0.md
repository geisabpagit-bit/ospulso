# OSPulso Master Specification

Version: 1.0

Estado:
Living Document

Última actualización:
2026

Clasificación:
Documento Maestro del Ecosistema OSPulso

Autor:
OSPulso Engineering

Propietario:
OSPulso

Confidencialidad:
Uso interno

# FASE A

## Propósito

Este documento constituye la única fuente oficial de especificaciones funcionales, visuales, técnicas y estratégicas del ecosistema OSPulso.

Todo desarrollo futuro deberá derivarse de este documento.

No existe documentación paralela.

Toda modificación deberá realizarse primero aquí y posteriormente propagarse al resto de entregables.

Este documento gobierna:

• Marca

• Producto

• UX

• UI

• Backend

• Frontend

• IA

• Landing

• Marketing

• Motion

• Assets

• Diseño

• Documentación

• Presentaciones

# Filosofía

OSPulso no es un software.

No es un CRM.

No es un EHR.

No es un ERP.

OSPulso es un Sistema Operativo para Clínicas Modernas.

Todos los componentes del ecosistema deben responder a cuatro principios fundamentales:

1.
Simplicidad

2.
Consistencia

3.
Escalabilidad

4.
Inteligencia Operativa

# Principios del Ecosistema

## Single Source of Truth

Toda decisión nace aquí.

---

## Zero Redundancy

Nunca duplicar información.

---

## Design First

Todo desarrollo comienza con diseño.

---

## Component Driven

Todo componente es reutilizable.

---

## API First

Todo servicio deberá ser desacoplado.

---

## AI Native

Toda nueva funcionalidad deberá considerar IA desde su concepción.

---

## Mobile First

Toda interfaz deberá funcionar primero en dispositivos móviles.

---

## Accessibility First

Toda interfaz deberá cumplir estándares WCAG.

---

## Performance First

Toda pantalla deberá abrir en menos de dos segundos.

---

## Security First

Toda información deberá protegerse desde el diseño.

# Jerarquía

Master Specification

↓

Brand Book

↓

Design System

↓

UX Guidelines

↓

UI Guidelines

↓

Frontend

↓

Backend

↓

Landing

↓

Dashboard

↓

Marketing

↓

Assets

↓

Presentaciones

↓

Documentación Técnica

# Versionado

Toda modificación seguirá el siguiente flujo.

Modificar OMS

↓

Validar

↓

Aprobar

↓

Actualizar derivados

Nunca modificar un documento derivado sin actualizar previamente el OMS.

# Convenciones

## Archivos

snake_case

UTF-8

LF Unix

Markdown

---

## Imágenes

SVG

PNG

WEBP

---

## Diagramas

Mermaid

SVG

---

## Código

Backend

Perl

Frontend

SPA

JavaScript

Bootstrap

AJAX

JSON

REST

---

## Colores

Nunca utilizar colores fuera del capítulo Colors.

---

## Tipografía

Nunca utilizar fuentes fuera del capítulo Typography.

---

## Iconografía

Toda iconografía deberá provenir del sistema oficial.

OMS

│

├── BRAND

├── PRODUCT

├── DESIGN

├── UX

├── UI

├── COMPONENTS

├── LANDING

├── DASHBOARD

├── CRM

├── EHR

├── AI

├── AUTOMATION

├── API

├── SECURITY

├── MOTION

├── SOCIAL

├── SALES

├── MARKETING

├── PRESENTATIONS

├── ASSETS

└── EXPORT

# Objetivos

Este documento deberá permitir:

✓ Reconstruir completamente la marca.

✓ Reconstruir completamente el producto.

✓ Generar automáticamente un Brand Book.

✓ Generar automáticamente un Design System.

✓ Generar automáticamente documentación.

✓ Alimentar agentes de IA.

✓ Mantener consistencia durante años.

✓ Reducir deuda técnica.

✓ Facilitar onboarding de diseñadores y desarrolladores.

✓ Servir como contrato funcional entre negocio y tecnología.

# Definition of Done (DoD)

Cada capítulo se considera terminado únicamente cuando cumple:

- Consistencia con el resto del documento.
- Ausencia de contradicciones.
- Ejemplos completos.
- Reglas claras.
- Casos límite documentados.
- Decisiones justificadas.
- Terminología unificada.
- Preparado para exportación.

# =============================================================================
# FASE B
# BRAND STRATEGY
# =============================================================================

# Objetivo

Este capítulo define la identidad estratégica de OSPulso.

No describe únicamente una marca.

Define el conjunto de principios que gobiernan toda decisión relacionada con:

• Producto

• Marketing

• UX

• UI

• Comunicación

• Ventas

• Desarrollo

• Inteligencia Artificial

Todo elemento futuro deberá ser coherente con esta estrategia.

Este documento responde permanentemente cuatro preguntas:

¿Por qué existimos?

¿Qué construimos?

¿Para quién lo construimos?

¿Cómo debemos actuar?

# Declaración de Marca

Nombre Oficial

OSPulso

Descriptor

Sistema Operativo para Clínicas Modernas

Categoría

Healthcare Operating System (HOS)

Posicionamiento

Infraestructura clínica inteligente para la administración, operación y crecimiento de consultorios y clínicas.

Eslogan Principal

Menos administración.
Más medicina.

Eslogan Alternativo

La inteligencia que mantiene viva tu clínica.

Propuesta de Valor

OSPulso integra en un único ecosistema la operación clínica, administrativa y financiera mediante automatización e inteligencia artificial.

# Golden Circle

## WHY

Existimos para devolver tiempo a los profesionales de la salud.

La medicina debe concentrarse en las personas, no en procesos administrativos.

Nuestro propósito es eliminar la complejidad operativa para que cada minuto recuperado pueda convertirse en mejor atención clínica.

---

## HOW

Construimos una plataforma unificada donde agenda, expediente clínico, comunicación, inteligencia artificial y administración trabajan como un solo organismo.

No agregamos módulos.

Construimos un sistema operativo.

---

## WHAT

OSPulso es una plataforma SaaS especializada para clínicas modernas que integra:

Agenda

CRM

Expediente Clínico

Facturación

Finanzas

Automatización

Analítica

Inteligencia Artificial

Todo funcionando sobre una única arquitectura.

# Propósito

Nuestra misión no consiste en digitalizar clínicas.

Nuestra misión consiste en reducir la carga cognitiva de quienes cuidan personas.

Cada decisión de diseño deberá responder una sola pregunta:

¿Esto reduce trabajo innecesario?

Si la respuesta es no, no pertenece a OSPulso.

# Visión

Convertirnos en la infraestructura clínica digital de referencia para Latinoamérica.

Queremos que una clínica pueda operar completamente sobre OSPulso sin depender de herramientas externas para sus procesos esenciales.

OSPulso debe convertirse en el sistema operativo desde el cual se gestiona toda la experiencia clínica.

# Misión

Construir tecnología clínica intuitiva, confiable e inteligente que permita administrar consultorios y clínicas con la misma simplicidad con la que un médico atiende a un paciente.

La tecnología debe desaparecer.

La atención debe permanecer.

# Valores

## Simplicidad

Reducimos complejidad.

Nunca la agregamos.

---

## Confianza

Los datos médicos representan vidas.

La confianza es irrenunciable.

---

## Precisión

Toda información debe ser consistente.

No existen aproximaciones.

---

## Empatía

Diseñamos para personas.

No para computadoras.

---

## Innovación Responsable

No incorporamos tecnología por moda.

Sólo por utilidad clínica.

---

## Transparencia

La plataforma siempre comunica claramente qué ocurre y por qué ocurre.

---

## Evolución Continua

OSPulso nunca está terminado.

Siempre mejora.

# Personalidad

OSPulso es:

Profesional

Inteligente

Sereno

Preciso

Confiable

Humano

Discreto

Elegante

No es:

Frío

Robótico

Ruidoso

Infantil

Agresivo

Pretencioso

Complejo

# Arquetipo Principal

El Sabio

Busca conocimiento.

Reduce incertidumbre.

Facilita mejores decisiones.

---

# Arquetipo Secundario

El Cuidador

Protege.

Acompaña.

Genera confianza.

Nunca reemplaza al profesional.

Lo potencia.

# Voz de Marca

Debe transmitir:

Seguridad

Calma

Orden

Claridad

Optimismo

Nunca utilizar:

Marketing exagerado.

Promesas imposibles.

Lenguaje técnico innecesario.

Alarmismo.

Exceso de adjetivos.

# Tono

Formal

Conversacional

Profesional

Optimista

Didáctico

Nunca:

Sarcástico

Arrogante

Humorístico

Informal

# Promesa de Marca

Cada interacción con OSPulso deberá hacer sentir al usuario que tiene el control absoluto de su clínica.

La plataforma debe transmitir tranquilidad.

Nunca ansiedad.

# Posicionamiento

OSPulso no compite contra otros softwares.

Compite contra:

Excel

Papel

WhatsApp

Procesos manuales

Duplicidad de información

Desorganización

Tiempo perdido

Errores administrativos

Nuestro verdadero enemigo es el caos operativo.

# Design Principles

Toda decisión futura deberá cumplir:

Eliminar pasos.

Reducir clics.

Reducir errores.

Aumentar claridad.

Reducir carga cognitiva.

Automatizar siempre que sea posible.

Priorizar velocidad.

Priorizar accesibilidad.

Priorizar consistencia.

Si una funcionalidad viola alguno de estos principios deberá replantearse.

# Manifiesto del Producto

OSPulso no aspira a convertirse en la aplicación con más funciones.

Aspira a convertirse en la plataforma más útil.

No buscamos impresionar mediante interfaces complejas.

Buscamos desaparecer detrás del trabajo clínico.

La mejor interfaz es aquella que permite al profesional concentrarse en el paciente y olvidar que existe un software entre ambos.

# Definition of Success

OSPulso será exitoso cuando:

Los médicos dediquen más tiempo a sus pacientes.

Las recepciones reduzcan errores.

Las clínicas recuperen ingresos perdidos.

Los pacientes vivan una mejor experiencia.

El software deje de ser protagonista y se convierta en infraestructura invisible.

# =============================================================================
# FASE C
# VISUAL IDENTITY SYSTEM
# =============================================================================

# Objetivo

Este capítulo define la identidad visual oficial de OSPulso.

Toda representación gráfica de la marca deberá derivarse de estas especificaciones.

No se permiten interpretaciones personales del logotipo, colores o elementos visuales.

La identidad visual debe transmitir:

• Confianza
• Tecnología
• Salud
• Precisión
• Orden
• Simplicidad
# Filosofía Visual

OSPulso no comunica mediante ornamentos.

Comunica mediante claridad.

Cada elemento visual debe cumplir una función.

El exceso de diseño genera ruido.

La simplicidad genera confianza.

Nuestro lenguaje visual se inspira en:

• Equipamiento médico
• Interfaces clínicas
• Sistemas operativos
• Arquitectura modular
• Señalización hospitalaria
• Dashboards empresariales

Nunca en tendencias pasajeras.

# Sistema de Identidad

La identidad gráfica está formada por cinco elementos inseparables.

1.
Logotipo

2.
Sistema Tipográfico

3.
Sistema Cromático

4.
Iconografía

5.
Lenguaje Geométrico

La marca nunca depende únicamente del logotipo.

# Concepto

El logotipo representa el punto donde convergen tres ideas.

Pulso

Vida

Tecnología

El trazo ECG simboliza continuidad clínica.

No representa una enfermedad.

Representa actividad.

Representa monitoreo.

Representa confianza.

Representa atención permanente.

La tipografía transmite estabilidad.

El conjunto comunica un sistema operativo que permanece funcionando de manera silenciosa.

# Componentes

El sistema está formado por:

Wordmark

OSPulso

—

Pulse Symbol

Línea ECG

—

Descriptor

Sistema Operativo para Clínicas Modernas

—

Isotipo

Versión reducida para aplicaciones.

—

App Icon

Versión cuadrada para dispositivos móviles.

—

Favicon

Versión simplificada para navegadores.

# Arquitectura

El logotipo está construido mediante un sistema modular.

Todo elemento responde a una retícula.

Nunca debe redibujarse manualmente.

Las proporciones permanecen constantes.

Las relaciones geométricas forman parte de la identidad.

# Grid

El logotipo utiliza una retícula base de 8 unidades.

Toda proporción deriva de esta unidad.

Altura

8u

Espesor del pulso

1u

Espacio entre caracteres

0.5u

Altura del descriptor

2u

Separación descriptor

1u

# Clear Space

La zona mínima de protección equivale a la altura de la "O".

Nunca podrá existir ningún elemento dentro de esa área.

Aplica para:

Imágenes

Fondos

Textos

Fotografías

Interfaces

Videos

Presentaciones

# Minimum Size

Digital

120 px

Impresión

30 mm

Isotipo

24 px

Favicon

16 px

Nunca utilizar tamaños inferiores.

# Versiones Oficiales

Principal

Horizontal

—

Vertical

—

Solo Wordmark

—

Solo Isotipo

—

App Icon

—

Favicon

—

Monocromática

Negra

—

Monocromática

Blanca

—

Escala de grises

# Incorrect Usage

Nunca:

Cambiar colores

Rotar

Estirar

Comprimir

Aplicar sombras

Aplicar bevel

Aplicar glow

Modificar el pulso

Cambiar tipografía

Separar elementos

Agregar efectos 3D

Agregar gradientes no autorizados

# Background Rules

Preferentes

Blanco Clínico

Azul Profundo

Azul Médico

Permitidos

Fotografía con overlay

Negro

Gris muy claro

No permitidos

Fondos con bajo contraste

Fotografías saturadas

Patrones complejos

Gradientes intensos

# Photography

La fotografía oficial debe comunicar:

Luz natural

Espacios limpios

Tecnología

Profesionales reales

No utilizar imágenes artificiales.

No utilizar poses exageradas.

No utilizar hospitales antiguos.

No utilizar exceso de instrumental.

La atención siempre recae sobre la interacción humana.

# Visual Language

La geometría oficial utiliza:

Rectángulos con radios suaves

Líneas horizontales

Círculos completos

Arcos

Retículas

Espacios amplios

Nunca:

Picos

Estrellas

Polígonos agresivos

Formas caóticas

# Shape System

Radius

8

12

20

9999

Sombras

Muy suaves

Glass

Difusión amplia

Nunca sombras duras.

Nunca bordes gruesos.

# Iconography

Estilo

Outline

Stroke uniforme

Esquinas redondeadas

24 px

Grid 24

Stroke 2 px

Nunca utilizar iconografía rellena mezclada con outline.

Todo el sistema debe mantener consistencia visual.

# Illustration

Las ilustraciones oficiales utilizan:

Perspectiva isométrica

Gradientes suaves

Azules clínicos

Cyan IA

Fondos claros

Nunca caricaturas.

Nunca ilustraciones infantiles.

# Motion Identity

Las animaciones deberán transmitir:

Suavidad

Fluidez

Continuidad

Nunca rebotes exagerados.

Nunca movimientos agresivos.

Duración preferida

200–300 ms

# DoD

La identidad visual se considera completa únicamente cuando existan:

✓ Logotipo SVG maestro
✓ Variantes oficiales
✓ Retícula de construcción
✓ Área segura
✓ Manual de uso
✓ Sistema fotográfico
✓ Sistema geométrico
✓ Sistema iconográfico
✓ Sistema ilustrativo
✓ Exportaciones oficiales


# =============================================================================
# FASE D
# PRODUCT PHILOSOPHY
# =============================================================================

## D.0 Objetivo
Este capítulo define el comportamiento intelectual de OSPulso.
No describe funcionalidades.
Describe la manera en que el sistema toma decisiones.
Toda característica futura deberá obedecer estas reglas.

Este documento gobierna:
• UX
• IA
• Automatización
• Backend
• Frontend
• APIs
• Componentes
• Dashboards
• Landing
• CRM
• Expediente Clínico

Todo comportamiento operativo deriva de este capítulo.

## D.1 Filosofía
OSPulso no reemplaza al profesional.

Amplifica sus capacidades.
Nunca decide por el médico.
Nunca diagnostica.
Nunca sustituye el criterio clínico.
Reduce carga administrativa.
Reduce tiempo muerto.
Reduce errores.
Incrementa información útil.
Incrementa velocidad.
Incrementa trazabilidad.

## D.2 Primer Principio - El paciente nunca debe esperar por culpa del software.
Toda decisión futura deberá favorecer la continuidad clínica.

## D.3 Segundo Principio - El médico nunca debe buscar información.
La información debe llegar antes de ser solicitada.

Ejemplo:

Paciente confirmado.
↓
Expediente abierto automáticamente.
↓
Últimos estudios visibles.
↓
Tratamientos visibles.
↓
Alertas visibles.
↓
Cronología disponible.
Todo antes del primer clic.

## D.4 Tercer Principio - Una captura.
Múltiples usos.
Toda información registrada una sola vez.
Nunca duplicar captura.
Nunca duplicar formularios.
Nunca duplicar expedientes.

## D.5 Cuarto Principio - La automatización siempre tiene prioridad.
Si una tarea puede automatizarse.
Debe automatizarse.

## D.6 Inteligencia Clínica Operativa - ICO
(Inteligencia Clínica Operativa)
ICO es el modelo operativo interno de OSPulso.

No es IA.
La IA forma parte de ICO.
ICO representa la coordinación inteligente entre:
Agenda
Expediente
CRM
Cobranza
Analytics
Comunicación
Automatización
Todos los módulos colaboran entre sí.

## D.7 Modelo Mental
Paciente
↓
Consulta
↓
Información
↓
Conocimiento
↓
Decisión
↓
Acción
↓
Seguimiento
↓
Aprendizaje
↓
Mejora Continua

Toda funcionalidad futura deberá ubicarse en alguna parte de este flujo.

## D.8 Modelo de Información
Toda entidad posee:
Origen
↓
Responsable
↓
Tiempo
↓
Estado
↓
Historial
↓
Relaciones
↓
Auditoría

Nunca existen registros aislados.

## D.9 Automatización
Toda automatización deberá cumplir:
No bloquear.
Ser reversible.
Ser auditable.
Ser transparente.
Poder deshabilitarse.
Nunca ocultar decisiones.

## D.10 IA
La IA nunca reemplaza.
Sugiere.
Resume.
Prioriza.
Clasifica.
Relaciona.
Predice.
Documenta.
Nunca diagnostica automáticamente.
Nunca modifica información clínica sin autorización.

## D.11 Jerarquía
Persona
↓
Proceso
↓
Información
↓
Automatización
↓
IA
Nunca invertir esta jerarquía.

## D.12 Modelo de Interfaces
Toda pantalla responde tres preguntas.
¿Dónde estoy?
¿Qué puedo hacer?
¿Qué ocurre después?
Si alguna pantalla no responde estas tres preguntas.
Debe rediseñarse.

## D.13 Arquitectura Cognitiva
Toda pantalla debe reducir:
Carga cognitiva.
Tiempo de decisión.
Cantidad de clics.
Errores.
Tiempo de capacitación.

## D.14 Principio del Segundo Cero
Si una acción tarda más de dos segundos.

Debe mostrar progreso.
Si tarda más de cinco segundos.
Debe replantearse arquitectónicamente.

## D.15 Principio del Silencio
El mejor software es el que desaparece.
El usuario nunca debería pensar en OSPulso.
Debe pensar únicamente en su paciente.

## D.16 Arquitectura Invisible
OSPulso debe comportarse como un sistema nervioso.

No como una colección de módulos.
Todo parece conectado.
Porque realmente lo está.

## D.17 Definición de Inteligencia
Para OSPulso, inteligencia significa:
Reducir trabajo.
No agregar funciones.
Reducir decisiones.
No agregar configuraciones.
Reducir incertidumbre.
No agregar complejidad.

## D.18 Principio del Orden
Cada pantalla debe transmitir:
Calma.
Orden.
Seguridad.
Claridad.
Nunca ansiedad.
Nunca urgencia.
Nunca saturación visual.

## D.19 Definition of Done
Este capítulo queda completo cuando cualquier nueva funcionalidad pueda responder:

¿Por qué existe?
¿Qué problema elimina?
¿Qué principio cumple?
¿Cómo reduce carga cognitiva?
¿Cómo mejora el flujo clínico?
¿Qué automatiza?
¿Cómo protege al paciente?

# =============================================================================
# FASE E
# PLATFORM ARCHITECTURE
# =============================================================================

## E.0 Objetivo
Este capítulo define la arquitectura conceptual de OSPulso.

No documenta tecnologías.

Documenta responsabilidades.

Todo módulo del ecosistema deberá existir porque resuelve una responsabilidad claramente definida.

Nunca existirán módulos por conveniencia técnica.

Cada módulo deberá aportar valor clínico, administrativo o estratégico.

La arquitectura debe permanecer estable aunque cambien tecnologías, lenguajes o frameworks.

## E.1 Definición
OSPulso es un Healthcare Operating System (HOS).

Su arquitectura se organiza alrededor de dominios de negocio.

No alrededor de pantallas.

No alrededor de tablas.

No alrededor de tecnologías.

Cada dominio representa una capacidad operativa de la clínica.

## E.2 Dominios del Ecosistema
OSPulso

│

├── Core

├── Clinical

├── Patients

├── Scheduling

├── Finance

├── CRM

├── Communication

├── Analytics

├── AI

├── Documents

├── Security

├── Integrations

└── Administration

## E.3 Core
El Core representa el corazón del sistema.

Responsabilidades

• Usuarios

• Roles

• Configuración

• Organización

• Clínicas

• Sucursales

• Parámetros

• Auditoría

• Catálogos

El Core nunca contiene lógica clínica.

Su función es sostener al ecosistema.

## E.4 Clinical Domain
Responsable del ciclo médico.

Incluye:

Expediente

SOAP

Diagnósticos

Odontograma

Prescripciones

Recetas

Estudios

Radiología

Tratamientos

Consentimientos

Evoluciones

Seguimientos

Es el dominio más importante del sistema.

## E.5 Patients
Responsable de toda la información relacionada con el paciente.

No contiene información clínica.

Contiene:

Identidad

Contacto

Familiares

Seguros

Documentación

Consentimientos

Historial administrativo

Toda referencia clínica apunta al expediente.

## E.6 Scheduling
Responsable del tiempo.

Agenda

Disponibilidad

Recursos

Consultorios

Calendarios

Confirmaciones

Recordatorios

Reagendamientos

Colisiones

Todo evento del sistema depende de este dominio.

## E.7 Finance
Responsable del flujo económico.

Presupuestos

Pagos

Abonos

Facturación

Cuentas

Estados financieros

Comisiones

Cajas

Cobranza

Indicadores financieros

Nunca administra expedientes.

Nunca administra pacientes.

Sólo administra dinero.

## E.8 CRM
Responsable de la relación con el paciente.

Lead

Prospecto

Paciente

Seguimiento

Campañas

Embudos

Conversión

Retención

Fidelización

El CRM no conoce diagnósticos.

Conoce relaciones.

## E.9 Communication
Toda interacción con el exterior.

Correo

SMS

WhatsApp

Notificaciones

Llamadas

Recordatorios

Automatizaciones

Toda comunicación deberá quedar registrada.

## E.10 Analytics
Toda decisión estratégica nace aquí.

KPIs

Dashboards

Reportes

Business Intelligence

Indicadores

Comparativos

Predicciones

No modifica datos.

Sólo interpreta.

## E.11 AI Domain - Artificial Intelligence
La IA opera como un servicio transversal.

Nunca posee datos propios.

Consume información de:

Clinical

CRM

Scheduling

Finance

Analytics

Genera:

Resúmenes

Clasificaciones

Alertas

Predicciones

Priorizaciones

Nunca altera registros sin autorización.

## E.12 Documents
Todo documento oficial.

PDF

XML

Imágenes

Radiografías

Consentimientos

Laboratorios

Recetas

Archivos externos

Todo documento posee trazabilidad.

## E.13 Security
Autenticación

Autorización

Sesiones

Permisos

Logs

Auditoría

Firmas

Cifrado

Trazabilidad

La seguridad nunca depende del frontend.

## E.14 Integrations
APIs

FHIR

HL7

DICOM

PACS

Correo

WhatsApp

Google

Microsoft

Stripe

SAT

Toda integración es desacoplada.

Nunca forma parte del Core.

## E.15 Administration
Configuración global.

Parámetros.

Catálogos.

Personalización.

Plantillas.

Usuarios.

Sucursales.

Licenciamiento.

Respalda al resto del ecosistema.

## E.16 Relaciones
Patient

↓

Scheduling

↓

Clinical

↓

Finance

↓

CRM

↓

Analytics

↓

AI

Toda información fluye en esta dirección.

Nunca al revés.

## E.17 Dependencias - Reglas
Core

↓

Todos

Scheduling

↓

Clinical

↓

Finance

↓

Analytics

↓

AI

Los módulos superiores nunca conocen implementaciones inferiores.

Sólo contratos.

## E.18 Principios Arquitectónicos
Alta cohesión.

Bajo acoplamiento.

Responsabilidad única.

APIs desacopladas.

Eventos antes que polling.

Configuración antes que código.

Auditoría por defecto.

Escalabilidad horizontal.

Versionado de APIs.

Backward Compatibility.

## E.19 Definition of Done
Este capítulo se considera completo cuando:

✓ Todo módulo posee una responsabilidad única.

✓ No existen dependencias circulares.

✓ Toda funcionalidad pertenece a un dominio.

✓ Todo dato tiene propietario.

✓ Todo proceso tiene responsable.

✓ Toda integración está desacoplada.

✓ Toda decisión puede justificarse arquitectónicamente.

Debe ser comprensible para todos.

# =============================================================================
# FASE F
# DOMAIN MODEL & UBIQUITOUS LANGUAGE
# =============================================================================
## F.0 Objetivo
Este capítulo define el modelo conceptual de negocio de OSPulso.

Su propósito es establecer un lenguaje único para todo el ecosistema.

Toda conversación técnica, funcional o comercial deberá utilizar esta terminología.

No existirán sinónimos para una misma entidad.

Toda entidad deberá tener:

• Definición

• Responsabilidad

• Ciclo de vida

• Relaciones

• Reglas

• Eventos

El modelo de dominio gobierna tanto el software como la documentación y los agentes de inteligencia artificial.

## F.1 Lenguaje Ubicuo

Las siguientes palabras poseen un significado oficial.

Paciente
Persona que recibe atención clínica.

Nunca:
Cliente
Usuario
Consumidor
---

Profesional
Persona autorizada para brindar atención clínica.

Incluye:
Médico
Odontólogo
Especialista
Enfermería
---

Consulta

Interacción clínica documentada entre un paciente y un profesional.

---
Cita
Evento programado dentro de la agenda.
Una cita puede o no generar una consulta.
---

Expediente
Conjunto completo de información clínica de un paciente.

Nunca existe más de un expediente activo por paciente.

---
Tratamiento

Plan clínico compuesto por uno o más procedimientos.

---
Procedimiento
Acción clínica individual.
---

Documento
Elemento digital asociado a una entidad del sistema.

---
Organización
Entidad propietaria de la licencia.
---

Sucursal
Unidad operativa perteneciente a una organización.
---
Usuario
Persona autenticada dentro del sistema.
No necesariamente es un profesional.

## F.2 Entidades Raíz
Organización
│
├── Sucursal
│      │
│      ├── Profesional
│      │
│      ├── Agenda
│      │
│      ├── Pacientes
│      │
└── Recursos

## F.3 Entidades Principales
Organización
Sucursal
Usuario
Rol
Permiso
Paciente
Profesional
Agenda
Cita
Consulta
Expediente
Tratamiento
Procedimiento
Documento
Pago
Factura
Inventario
Producto
Receta
Prescripción
Radiografía
Estudio
Mensaje
Notificación
Campaña
Reporte
Dashboard

## F.4 Objetos de Valor
Nombre
CURP
RFC
Correo
Teléfono
Dirección
Coordenadas
Dinero
Fecha
Hora
Periodo
Color
Estado
Firma
Identificador
No poseen identidad propia.
Sólo describen entidades.

## F.5 Agregados
Paciente
↓
Expediente
↓
Consulta
↓
SOAP
↓
Diagnósticos
↓
Tratamientos
↓
Recetas
↓
Documentos
Agenda
↓
Cita
↓
Confirmación
↓
Recordatorio
↓
Check-in
↓
Consulta

## F.6 Eventos
PacienteRegistrado
PacienteActualizado
CitaProgramada
CitaConfirmada
PacienteLlegó
ConsultaIniciada
ConsultaFinalizada
SOAPGuardado
TratamientoCreado
PagoRegistrado
FacturaEmitida
DocumentoAdjuntado
IAResumenGenerado
RecordatorioEnviado
ReporteGenerado
Cada evento representa un hecho.
Nunca un comando.

## F.7 Comandos
RegistrarPaciente
ActualizarPaciente
ProgramarCita
CancelarCita
IniciarConsulta
GuardarSOAP
EmitirReceta
RegistrarPago
EmitirFactura
EnviarMensaje
CrearCampaña
ExportarDocumento
Los comandos representan intención.
Los eventos representan hechos.

## F.8 Estados
Paciente
Activo
Inactivo
Archivado
---
Cita
Programada
Confirmada
En espera
En consulta
Finalizada
Cancelada
No asistió
---
Consulta
Abierta
En progreso
Finalizada
Firmada
Archivada
---
Factura
Pendiente
Emitida
Pagada
Cancelada

## F.9 Relaciones
Paciente
↓
Expediente
↓
Consulta
↓
Tratamiento
↓
Pago
↓
Factura

## F.10 Reglas Inmutables
Nunca dos expedientes activos para un paciente.
Nunca una consulta sin paciente.
Nunca una receta sin consulta.
Nunca un pago sin referencia.
Nunca una factura sin movimiento financiero.
Nunca una cita sin agenda.
Nunca eliminar información clínica.
Sólo archivar.
Toda modificación deja auditoría.

## F.11 Auditoría
Toda entidad posee:
CreadoPor
CreadoEn
ModificadoPor
ModificadoEn
Origen
Versión
Estado
Historial

## F.12 Ownership
Paciente
↓
Organización
↓
Sucursal
↓
Profesional Responsable
↓
Consulta
↓
Documento

Nunca existen entidades huérfanas.

## F.13 Lenguaje Prohibido
Nunca utilizar:
Ficha
Registro Médico
Archivo
Hoja
Cliente
Ficha Clínica
Usuario Médico
Paciente Cliente
Siempre utilizar la terminología oficial.

## F.14 Catálogos
Todos los catálogos deberán cumplir:
Identificador

Código
Descripción
Estado
Fecha de Alta
Fecha de Baja
Versión
Nunca almacenar texto libre cuando exista catálogo oficial.

## F.15 Identificadores
Cada entidad posee:
UUID interno
ID incremental visible
Código corto
Código QR (cuando aplique)
Nunca utilizar únicamente IDs autoincrementales para integraciones.

## F.16 Reglas de Integridad
No existen relaciones implícitas.
Toda referencia debe estar validada.
Toda entidad debe existir antes de ser relacionada.
Toda eliminación física está prohibida para información clínica.
Se utilizará archivado lógico y versionado.

## F.17 Modelo Temporal
Toda entidad registra:
Fecha de creación
Fecha de modificación
Fecha efectiva
Fecha de vigencia
Zona horaria
Usuario responsable
Esto permite reconstruir cualquier estado histórico del sistema.

## F.18 Convenciones de Nomenclatura
Entidades:
PascalCase
Eventos:
PascalCase en pasado
(Ej. ConsultaFinalizada)

Comandos:
Verbo + Sustantivo
(Ej. ProgramarCita)

APIs:
kebab-case

Archivos:
snake_case

Variables:
camelCase

Clases:
PascalCase

Constantes:
UPPER_SNAKE_CASE

## F.19 Definition of Done
Este capítulo se considera completo cuando:
✓ Todas las áreas utilizan el mismo lenguaje.
✓ No existen términos ambiguos.
✓ Toda entidad tiene propietario.
✓ Toda entidad tiene reglas.
✓ Toda entidad tiene eventos.
✓ Toda entidad tiene estados.
✓ Toda entidad tiene auditoría.
✓ Todo desarrollador puede construir el modelo de datos únicamente leyendo este capítulo.
✓ Cualquier agente de IA puede interpretar correctamente el dominio del negocio sin requerir contexto adicional.

# =============================================================================
# FASE G
# BUSINESS RULES & CLINICAL WORKFLOW ENGINE
# =============================================================================
## G.0 Objetivo

Este capítulo define el comportamiento operativo del ecosistema OSPulso.

No documenta código.
No documenta pantallas.
Documenta procesos.
Cada flujo operativo deberá obedecer estas reglas.
Toda decisión del software deberá derivarse de este documento.
Las reglas aquí definidas tienen prioridad sobre cualquier implementación técnica.

## G.1 Filosofía Operativa
Toda clínica funciona mediante procesos.
No mediante pantallas.

OSPulso automatiza procesos.
Nunca pantallas.

Cada módulo representa una etapa del flujo clínico.

Nunca una colección de formularios.

Todo flujo tiene:
Inicio
↓
Validación
↓
Proceso
↓
Resultado
↓
Auditoría
↓
Seguimiento

## G.2 Flujo Maestro
Lead
↓
Paciente
↓
Cita
↓
Recepción
↓
Consulta
↓
SOAP
↓
Diagnóstico
↓
Tratamiento
↓
Cobro
↓
Seguimiento
↓
Analytics
↓
IA
↓
Aprendizaje

## G.3 Workflow Clínico
Paciente agenda
↓
Confirma
↓
Llega
↓
Check-in
↓
Espera
↓
Consulta
↓
SOAP
↓
Diagnóstico
↓
Plan
↓
Receta
↓
Indicaciones
↓
Pago
↓
Seguimiento
↓
Alta

## G.4 Estados Globales
Todo workflow deberá utilizar estados oficiales.

Pendiente
Programado
Confirmado
En espera
En proceso
Completado
Cancelado
Archivado
Nunca inventar estados nuevos sin modificar este documento.

## G.5 Motor de Estados
Pendiente
↓
Programado
↓
Confirmado
↓
Check-in
↓
En Consulta
↓
Finalizado
↓
Seguimiento
↓
Alta
Toda transición debe quedar registrada.

## G.6 Recepción
Objetivo
Confirmar identidad.
Actualizar expediente.
Verificar documentos.
Registrar llegada.

Reglas
No puede iniciar consulta sin check-in.
No puede existir check-in duplicado.
Debe registrarse hora real.
Debe registrarse recepcionista.
Debe quedar evidencia.

## G.7 Agenda
Toda cita debe poseer:
Paciente
Profesional
Sucursal
Consultorio
Horario
Duración
Estado
Color
Motivo
Prioridad
No pueden existir traslapes.
Toda colisión deberá impedir confirmación.

## G.8 Consulta
Toda consulta posee:
Motivo
Anamnesis
Exploración
SOAP
Diagnóstico
Tratamiento
Prescripción
Seguimiento
Firma
Fecha
Hora
Profesional Responsable
No existen consultas parcialmente cerradas.

## G.9 SOAP
Subjetivo
Objetivo
Análsis
Plan
El sistema deberá validar que los cuatro apartados existan antes del cierre clínico.
No se permitirá finalizar una consulta incompleta.

## G.10 Tratamientos
Todo tratamiento:
Pertenece a una consulta.
Posee responsable.
Tiene estado.
Tiene costo.
Tiene duración.
Tiene seguimiento.
Puede dividirse en múltiples procedimientos.

## G.11 Procedimientos
Todo procedimiento:
Tiene fecha.
Tiene duración.
Tiene profesional.
Tiene evidencia.
Puede generar documentos.
Puede generar imágenes.
Puede generar recetas.

## G.12 Prescripciones
Toda receta deberá contener:
Consulta origen.
Profesional.
Paciente.
Medicamentos.
Indicaciones.
Firma.
Fecha.
Nunca podrá existir una receta sin consulta.

## G.13 Documentos
Todo documento deberá poseer:
Origen.
Versión.
Autor.
Fecha.
Hash.
Auditoría.
Nunca reemplazar archivos.
Siempre versionar.

## G.14 Finanzas
Todo movimiento financiero deberá registrar:
Origen.
Referencia.
Responsable.
Fecha.
Concepto.
Monto.
Estado.
No existen movimientos anónimos.
No existen modificaciones sin auditoría.

## G.15 CRM
Todo contacto deberá registrar:
Origen.
Canal.
Resultado.
Próxima acción.
Responsable.
Toda interacción genera historial.

## G.16 Inventario
Todo movimiento:
Entrada.
Salida.
Ajuste.
Transferencia.
Caducidad.
Lote.
Proveedor.
Nunca modificar existencias manualmente sin dejar evidencia.

## G.17 IA
La IA podrá:
Resumir consultas.
Detectar pendientes.
Priorizar pacientes.
Clasificar documentos.
Sugerir recordatorios.
Generar resúmenes.
Nunca:
Diagnosticar automáticamente.
Modificar expedientes.
Eliminar información.
Firmar documentos.

## G.18 Automatización
Toda automatización deberá:
Ser reversible.
Registrar auditoría.
Poder pausarse.
Poder deshabilitarse.
Poder reintentarse.
Nunca ejecutarse silenciosamente.

## G.19 Reglas de Auditoría
Toda operación registra:
Usuario.

IP.
Fecha.
Hora.
Entidad.
Acción.
Resultado.
Versión.
Dispositivo.
Nunca existen operaciones sin trazabilidad.

## G.20 Reglas Clínicas
Nunca eliminar expedientes.
Nunca eliminar consultas.
Nunca eliminar recetas.
Nunca eliminar tratamientos.
Solo archivar.
Toda corrección genera nueva versión.
Toda modificación conserva el histórico.
Toda firma es inmutable.

## G.21 Reglas de UX
El usuario nunca deberá perder información.
Toda acción crítica requiere confirmación.
Toda operación larga muestra progreso.
Toda validación ocurre antes del envío.
Toda pantalla conserva contexto.
Toda navegación puede recuperarse.
Nunca mostrar errores técnicos al usuario final.

## G.22 Flujos de Error
Error
↓
Detectar
↓
Registrar
↓
Informar
↓
Recuperar
↓
Auditar
↓
Continuar
El sistema nunca termina abruptamente un proceso sin dejar evidencia.

## G.23 Reglas de Seguridad
Toda operación requiere autorización.
Todo acceso requiere autenticación.
Toda sesión posee expiración.
Toda API valida permisos.
Todo documento posee propietario.
Toda descarga queda registrada.

## G.24 KPIs Operativos
Tiempo promedio de espera.
Tiempo promedio de consulta.
Cancelaciones.
No asistencias.
Conversión de leads.
Cobranza.
Ocupación de agenda.
Tiempo de cierre clínico.
Satisfacción del paciente.
Tiempo de respuesta del sistema.
Estos indicadores forman parte del núcleo del producto.

## G.25 Definition of Done
Una funcionalidad se considera completa únicamente cuando:

✓ Respeta el flujo clínico.
✓ Respeta las reglas del dominio.
✓ Tiene auditoría.
✓ Posee estados.
✓ Posee validaciones.
✓ Puede automatizarse.
✓ Es accesible.
✓ Es reversible cuando aplique.
✓ Genera eventos.
✓ Es observable mediante KPIs.

# =============================================================================
# FASE H
# REGULATORY COMPLIANCE & GOVERNANCE
# =============================================================================

## H.0 Objetivo
Este capítulo establece el marco normativo, regulatorio y de gobierno que rige el funcionamiento de OSPulso.

Su finalidad es garantizar que toda funcionalidad del sistema sea diseñada considerando los requisitos legales, clínicos, técnicos y de auditoría aplicables.

La regulación no constituye una característica adicional del sistema.

Forma parte de su arquitectura.

Toda nueva funcionalidad deberá evaluarse contra este capítulo antes de su implementación.

## H.1 Filosofía de Cumplimiento
El cumplimiento normativo no es un módulo.

Es una propiedad transversal del ecosistema.

Todo dato debe ser:
Confiable.
Íntegro.
Trazable.
Recuperable.
Auditable.

Toda operación debe poder justificarse técnica y jurídicamente.

La regulación se incorpora desde el diseño y no como una validación posterior.

## H.2 Principios de Gobierno
Legalidad
Integridad
Disponibilidad
Confidencialidad
No Repudio
Trazabilidad
Auditoría Permanente
Versionamiento
Responsabilidad
Seguridad por Diseño

## H.3 Marco Normativo
El diseño de OSPulso considera como referencia principal:

NOM-004-SSA3
Expediente Clínico.

NOM-024-SSA3
Interoperabilidad y Sistemas de Información para la Salud.

FHIR
Intercambio de información clínica.

HL7
Mensajería clínica.

DICOM
Imágenes médicas.

SAT
Facturación electrónica.

Ley Federal de Protección de Datos Personales.

Buenas prácticas internacionales de desarrollo seguro.

Las implementaciones podrán adaptarse conforme evolucionen las disposiciones oficiales.

## H.4 Gobierno del Dato
Todo dato posee:
Propietario.
Origen.
Responsable.
Fecha de creación.
Fecha de modificación.
Estado.
Versión.
Historial.
Clasificación.
Ningún dato existe sin propietario.

## H.5 Clasificación de Información
Pública
Interna
Confidencial
Clínica
Financiera
Administrativa
Sistema
Cada clasificación determina:
Permisos.
Retención.
Auditoría.
Exportación.
Respaldo.

## H.6 Gobierno Documental
Todo documento deberá registrar:
Identificador.

Versión.
Autor.
Fecha.
Origen.
Entidad relacionada.
Firma.
Hash.
Estado.
Nunca se reemplaza un documento.
Siempre se versiona.

## H.7 Firma
Toda firma deberá registrar:
Firmante.
Fecha.
Hora.
IP.
Dispositivo.
Versión del documento.
Motivo.
La firma representa una aceptación explícita.
Nunca podrá modificarse posteriormente.

## H.8 Auditoría
Toda acción deberá generar evidencia.
Crear.
Modificar.
Consultar.
Exportar.
Imprimir.
Firmar.
Eliminar (cuando aplique).
Toda evidencia deberá permanecer disponible para revisión.

## H.9 Trazabilidad
Toda entidad deberá permitir reconstruir:
Quién.
Qué.
Cuándo.
Dónde.
Por qué.
Resultado.
Nunca existirán operaciones opacas.

## H.10 Retención
La política de conservación será configurable por organización conforme a la legislación aplicable.

Como principio arquitectónico:
Nunca eliminar información clínica de manera física.
La eliminación lógica deberá conservar auditoría, referencias y metadatos necesarios para reconstruir el historial.

## H.11 Acceso
Todo acceso requiere:
Autenticación.
Autorización.
Rol.
Permisos.
Contexto.
Toda autorización deberá ser verificable.
No existen permisos implícitos.

## H.12 Roles
Administrador.
Dirección.
Recepción.
Profesional (Medico).
Asistente.
Caja.
Auditor.
Paciente.
Cada rol define capacidades.
Nunca interfaces distintas.
Las capacidades determinan la interfaz visible.

## H.13 Integridad
Toda transacción deberá cumplir:
Atomicidad.
Consistencia.
Aislamiento.
Durabilidad.
Cuando una operación falle:
Debe revertirse completamente.
Nunca dejar información parcialmente persistida.

## H.14 Disponibilidad
Toda funcionalidad crítica deberá contemplar:
Respaldo.
Recuperación.
Continuidad operativa.
Reintentos.
Notificación.
Registro.

El sistema deberá degradarse de forma controlada ante fallos.

## H.15 Seguridad

Toda pantalla.
Todo API.
Todo documento.
Todo archivo.
Todo proceso.
Toda integración.
Todo componente.
Debe diseñarse considerando seguridad desde su origen.
Nunca como una fase posterior.

## H.16 Interoperabilidad

Las integraciones deberán ser desacopladas.
Las interfaces públicas deberán utilizar estándares abiertos cuando sea posible.
Las adaptaciones específicas se implementarán mediante conectores independientes.
El núcleo del sistema no deberá depender de un proveedor externo.

## H.17 Riesgos
Todo cambio deberá evaluar:
Impacto clínico.
Impacto operativo.
Impacto financiero.
Impacto legal.
Impacto tecnológico.
Impacto en experiencia de usuario.
Toda decisión significativa deberá documentarse.

## H.18 Observabilidad
Toda operación crítica deberá generar información suficiente para:
Monitoreo.
Diagnóstico.
Auditoría.
Trazabilidad.
Métricas.
Alertamiento.
La observabilidad forma parte del diseño del sistema.

## H.19 Definition of Done
Una funcionalidad cumple esta fase cuando:
✓ Respeta la normativa definida.
✓ Genera auditoría.
✓ Es trazable.
✓ Mantiene integridad.
✓ Respeta los permisos.
✓ Es observable.
✓ Es recuperable.
✓ Es interoperable.
✓ Mantiene gobierno del dato.
✓ Cumple el modelo de seguridad del ecosistema.

# =============================================================================
# FASE I
# UX ARCHITECTURE & HUMAN INTERACTION MODEL
# =============================================================================

## I.0 Objetivo

Este capítulo define la arquitectura de experiencia de usuario (UX) de OSPulso.

No describe pantallas específicas.

No define componentes visuales.

Define cómo interactúan las personas con el sistema.

Toda decisión de interfaz deberá responder primero a la experiencia del usuario y, posteriormente, a criterios visuales o tecnológicos.

La experiencia precede al diseño.

## I.1 Filosofía UX

OSPulso debe comportarse como un asistente silencioso.

Nunca obliga al usuario a adaptarse al software.

El software se adapta al flujo natural del trabajo clínico.

La interfaz nunca será protagonista.

La atención al paciente siempre será el centro.

## I.2 Principios Fundamentales
• Un objetivo por pantalla.
• Una decisión por paso.
• Información antes que acciones.
• Acciones antes que configuración.
• Contexto antes que navegación.
• Prevención antes que corrección.
• Consistencia antes que creatividad.
• Claridad antes que densidad.
• Velocidad antes que cantidad de funciones.

## I.3 Modelo Mental del Usuario

Paciente
        │
        ▼
Recepción
        │
        ▼
Profesional
        │
        ▼
Administración
        │
        ▼
Dirección

Cada rol percibe el sistema de forma distinta.

La interfaz deberá adaptarse al rol, no al revés.

## I.4 Carga Cognitiva

La interfaz deberá minimizar:

- Memorización.
- Búsquedas.
- Escritura repetitiva.
- Cambios de contexto.
- Decisiones innecesarias.
- Interrupciones.

El usuario debe reconocer más de lo que recuerda.

## I.5 Navegación

Toda pantalla deberá responder de inmediato:

1. ¿Dónde estoy?
2. ¿Qué puedo hacer?
3. ¿Qué ocurre después?
4. ¿Cómo regreso?

Nunca más de tres niveles de profundidad para tareas frecuentes.

## I.6 Flujo de Atención
Agenda
   │
Check-in
   │
Consulta
   │
SOAP
   │
Tratamiento
   │
Cobro
   │
Seguimiento

Cada transición debe sentirse natural, sin romper el contexto.

## I.7 Jerarquía de Información

Nivel 1: Identidad del paciente.
Nivel 2: Motivo de atención.
Nivel 3: Estado actual.
Nivel 4: Acciones disponibles.
Nivel 5: Información histórica.
Nivel 6: Configuración.

## I.8 Patrones de Interacción

- Confirmación progresiva.
- Autoguardado cuando sea seguro.
- Deshacer antes que eliminar.
- Acciones rápidas para tareas frecuentes.
- Atajos de teclado en escritorio.
- Componentes táctiles amplios en móviles.

## I.9 Estados de la Interfaz

Toda pantalla deberá contemplar:

- Cargando.
- Vacía.
- Con datos.
- Error recuperable.
- Error crítico.
- Sin conexión.
- Sin permisos.
- Proceso completado.

Nunca dejar un estado sin representación visual.

## I.10 Errores

Los errores deben:

- Explicar qué ocurrió.
- Explicar por qué ocurrió.
- Indicar cómo resolverlo.
- Permitir continuar cuando sea posible.

Nunca mostrar mensajes técnicos al usuario final.

## I.11 Definition of Done

Una experiencia se considera correcta cuando:

✓ Reduce la carga cognitiva.
✓ Minimiza los clics.
✓ Mantiene el contexto.
✓ Evita errores.
✓ Es accesible.
✓ Es consistente.
✓ Es comprensible sin capacitación extensa.
✓ Permite completar la tarea con confianza.

# =============================================================================
# FASE J
# USER INTERFACE SYSTEM (UIS)
# =============================================================================

## J.0 Objetivo

Este capítulo define el Sistema Oficial de Interfaces de Usuario (UIS) de OSPulso.

Su propósito es garantizar consistencia visual, funcional y técnica en todos los productos del ecosistema.

El UIS no describe páginas.

Describe componentes reutilizables.

Todo elemento visible deberá pertenecer al UIS.

No existirán componentes "especiales".

Todo componente deberá ser reutilizable, documentado y accesible.

## J.1 Filosofía

La interfaz no debe llamar la atención.

Debe transmitir confianza.

El usuario debe concentrarse en el paciente.

No en el software.

Toda interfaz debe sentirse:
Silenciosa.
Ordenada.
Consistente.
Respirable.
Profesional.
Cada componente existe porque reduce esfuerzo cognitivo.
Nunca porque "se ve bonito".

## J.2 Arquitectura Visual
UIScreen
│
├── Layout
├── Containers
├── Navigation
├── Components
├── Feedback
├── Data Display
├── Forms
├── Actions
└── Utilities

## J.3 Jerarquía
Nivel 1
Paciente
↓
Nivel 2
Proceso
↓
Nivel 3
Acciones
↓
Nivel 4
Información secundaria
↓
Nivel 5
Metadatos
Nunca invertir esta jerarquía.

## J.4 Grid
Base

8 px

Micro Grid

4 px

Macro Grid

16 px

Desktop

12 columnas

Tablet

8 columnas

Mobile

4 columnas

Todo el sistema deriva de estas medidas.

Nunca utilizar espaciados arbitrarios.

## J.5 Layout
Toda pantalla se divide en:
Header
↓
Context Bar
↓
Workspace
↓
Actions
↓
Footer
El Workspace concentra la mayor parte del espacio disponible.
El Header nunca supera el 10% del alto visible.

## J.6 Espaciado - Spacing Scale
4
8
12
16
24
32
48
64
96
Nunca utilizar valores fuera de esta escala.

## J.7 Elevación - Elevation
Nivel 0
Background

Nivel 1
Cards

Nivel 2
Dropdowns

Nivel 3
Dialogs

Nivel 4
Modals

Nivel 5
Critical Overlay

Toda elevación utiliza sombra suave.
Nunca sombras duras.

## J.8 Border Radius
4
8
12
16
20
9999

Cada componente define uno de estos radios.
Nunca radios distintos.

## J.9 Contenedores - Containers
Page
Workspace
Section
Panel
Card
Widget
Modal
Drawer
Popover
Tooltip

## J.10 Cards
Las tarjetas representan contexto.
No acciones.
Toda card posee:
Título
Contenido
Acciones
Estado
Nunca utilizar una card como botón gigante.
La interacción pertenece a sus acciones.

## J.11 Botones - Buttons
Primary
Secondary
Ghost
Outline
Danger
Success
Warning
Info
Icon
FAB
Split Button
Dropdown Button
Todo botón representa una intención.
Nunca utilizar botones por color solamente.
El texto comunica la acción.

## J.12 Formularios - Forms
Toda captura utiliza:
Label
↓
Input
↓
Helper
↓
Validación
↓
Estado
Nunca utilizar placeholders como etiquetas.

## J.13 Inputs
Text
Textarea
Search
Password
Email
Phone
Number
Date
Time
Datetime
Currency
Percentage
Autocomplete
Tags
Rich Text
Masked
Readonly
Disabled

## J.14 Selectores - Selectors
Select
Autocomplete
Radio
Checkbox
Toggle
Segmented Control
Chip Selector
Tree
Multi Select

## J.15 Navegación - Navigation
Top Navbar
Sidebar
Breadcrumb
Tabs
Steps
FAB
Bottom Navigation
Context Menu
Command Palette

## J.16 Tablas - Data Tables
Toda tabla soporta:
Ordenamiento
Búsqueda
Filtros
Agrupación
Paginación
Exportación
Columnas configurables
Acciones rápidas
Estado vacío
Carga
Errores

## J.17 Dashboards
Toda pantalla Dashboard utiliza:
KPIs
↓
Widgets
↓
Timeline
↓
Actividad
↓
Acciones
↓
Detalle

## J.18 Feedback
Toast
Alert
Inline Validation
Banner
Progress
Skeleton
Loading
Snackbar
Empty State
Success State
Confirmation
Toda acción genera retroalimentación.

## J.19 Estados - Component States
Default
Hover
Focus
Pressed
Selected
Disabled
Loading
Error
Success
Warning
Active
Visited
Todos documentados.
Nunca estados implícitos.

## J.20 Modales - Dialogs
Information
Confirmation
Danger
Wizard
Fullscreen
Side Panel
Drawer
Nunca utilizar un modal para navegación.
Los modales resuelven tareas.
No reemplazan páginas.

## J.21 Iconografía - Icons
Outline
24 px
Stroke 2 px
Grid 24
Nunca mezclar estilos.
Toda acción importante posee icono.
Nunca depender únicamente del icono.
Siempre acompañar con texto cuando la acción sea crítica.

## J.22 Tipografía en UI - UI Typography
Display
H1
H2
H3
Subtitle
Body
Caption
Label
Button
Code
Numeric
Toda jerarquía deriva de la escala tipográfica oficial.

## J.23 Colores Semánticos - Semantic Colors
Primary
Secondary
Success
Warning
Danger
Info
Neutral
Disabled
Skeleton
Overlay
Los colores representan significado.
Nunca decoración.

## J.24 Accesibilidad - Accessibility
Contraste WCAG AA mínimo.
Navegación por teclado.
Focus visible.
ARIA.
Lectores de pantalla.
No depender únicamente del color.
Componentes táctiles ≥ 44 px.
Mensajes comprensibles.

## J.25 Responsive
Desktop
≥1200

Laptop
992–1199

Tablet
768–991
Mobile
<768

Todo componente posee comportamiento documentado en cada breakpoint.

## J.26 Motion
Duración
150–300 ms

Curvas suaves.
Nunca rebotes exagerados.
Las animaciones comunican estado.
Nunca distraen.

## J.27 Tokens
Toda propiedad visual deberá provenir de un token.
Nunca utilizar valores hardcode.
Color
Typography
Radius
Spacing
Elevation
Opacity
Animation
Z-index

## J.28 Component Inventory
Foundation
↓
Atoms
↓
Molecules
↓
Organisms
↓
Templates
↓
Pages
Modelo basado en Atomic Design.

## J.29 Anti Patterns
No duplicar componentes.
No modificar Bootstrap directamente.
No CSS inline.
No IDs para estilos.
No JavaScript embebido.
No múltiples componentes para la misma función.
No inconsistencias visuales entre módulos.

## J.30 Definition of Done - DoD
El UIS estará completo cuando:
✓ Todo componente esté documentado.
✓ Existan variantes.
✓ Existan estados.
✓ Existan ejemplos.
✓ Existan reglas de uso.
✓ Existan reglas de accesibilidad.
✓ Existan tokens.
✓ Existan restricciones.
✓ Existan ejemplos de código.
✓ Todo el frontend pueda construirse únicamente utilizando este sistema.

# =============================================================================
# FASE K
# VISUAL FOUNDATIONS & DESIGN TOKENS
# =============================================================================

## K.0 Objetivo
Este capítulo define las bases visuales oficiales del ecosistema OSPulso.

Todo atributo visual del sistema deberá derivarse de un Design Token.

Queda estrictamente prohibido utilizar valores visuales directamente dentro del código fuente.

Toda propiedad deberá referenciar un token oficial.

Este documento constituye la única fuente de verdad para:
• Colores
• Tipografía
• Espaciados
• Radios
• Elevaciones
• Transparencias
• Animaciones
• Breakpoints
• Z-index
• Tamaños

Los componentes nunca conocen valores.
Sólo conocen tokens.

## K.1 Filosofía
El diseño es un sistema.
No una colección de estilos.

Cada decisión visual deberá ser:
Consistente.
Escalable.
Reutilizable.
Versionable.
Documentada.
Toda modificación visual deberá realizarse cambiando un token.
Nunca modificando componentes individuales.

## K.2 Arquitectura
Foundation
↓
Design Tokens
↓
Components
↓
Templates
↓
Layouts
↓
Screens

## K.3 Taxonomía

Global Tokens
↓
Alias Tokens
↓
Semantic Tokens
↓
Component Tokens
Nunca acceder directamente a Global Tokens desde un componente.

## K.4 Global Colors
Blue 50
Blue 100
Blue 200
Blue 300
Blue 400
Blue 500
Blue 600
Blue 700
Blue 800
Blue 900
Teal 50
...
Gray 50
...

White
Black
Transparent
No contienen significado.
Sólo color.

## K.5 Alias
primary
secondary
accent
neutral
background
surface
border
overlay
Nunca utilizar Global Tokens directamente.

## K.6 Semantic Tokens
success
warning
danger
info
pending
loading
disabled
selected
focused
hover
pressed
visited
active
El componente sólo conoce estos nombres.

## K.7 Typography Tokens

display-xl
display-lg
display-md
display-sm
headline
title
subtitle
body-lg
body
body-sm
caption
label
button
code

## K.8 Font Families
font.primary
font.secondary
font.mono
font.numeric
K.9 Weight
100
200
300
400
500
600
700
800

Nunca utilizar pesos arbitrarios.

## K.10 Line Height
tight
normal
relaxed
loose

## K.11 Letter Spacing
xs
sm
md
lg
xl

## K.12 Radius
radius.none
radius.xs
radius.sm
radius.md
radius.lg
radius.xl
radius.full

## K.13 Spacing
space.0
space.1
space.2
space.3
space.4
space.5
space.6
space.8
space.10
space.12
space.16
space.24
Toda separación proviene de aquí.

## K.14 Shadows
shadow.none
shadow.sm
shadow.md
shadow.lg
shadow.xl

## K.15 Opacity
opacity.0
opacity.25
opacity.50
opacity.75
opacity.100

## K.16 Blur
blur.none
blur.sm
blur.md
blur.lg
K.17 Motion
motion.fast
motion.normal
motion.slow
motion.curve.standard
motion.curve.decelerate
motion.curve.accelerate

## K.18 Breakpoints
mobile
tablet
laptop
desktop
wide

## K.19 Elevation
surface
raised
floating
dialog
modal
toast

## K.20 Z Index
base
dropdown
sticky
overlay
modal
popover
tooltip
notification
Nunca usar números.

## K.21 Icon Tokens
icon.xs
icon.sm
icon.md
icon.lg
icon.xl

## K.22 Grid
grid.mobile
grid.tablet
grid.desktop
grid.wide

## K.23 Containers
container.xs
container.sm
container.md
container.lg
container.xl

## K.24 Naming Convention
color.primary.background
color.primary.text
color.primary.border
color.success.background
space.8
radius.md
shadow.lg
font.body
motion.fast
Todo sigue exactamente el mismo patrón.

## K.25 Versionado
Todo token posee:
Nombre.
Categoría.
Descripción.
Valor.
Fecha.
Versión.
Estado.
Nunca eliminar tokens.
Sólo deprecarlos.
    
## K.26 Compatibilidad
Los Design Tokens deberán poder exportarse a:

CSS Variables
SCSS
LESS
Tailwind
Bootstrap
Figma Variables
JSON
Android
iOS
Flutter
React
Vue
Angular
Perl Templates

## K.27 Token Registry
Todo token deberá registrarse en:

/tokens
tokens.json
tokens.css
tokens.scss
tokens.md
Nunca mantener múltiples definiciones inconsistentes.

## K.28 Anti Patterns
Nunca escribir:
#0A2A66
padding:17px
margin:19px
border-radius:13px
font-size:21px
Todo proviene de un token.

## K.29 Definition of Done
Este capítulo se considera completo cuando:
✓ Todo valor visual proviene de un token.
✓ No existen colores hardcode.
✓ No existen tipografías hardcode.
✓ No existen radios hardcode.
✓ No existen sombras hardcode.
✓ Todos los tokens poseen documentación.
✓ Todos los tokens poseen versión.
✓ Todos los componentes utilizan exclusivamente tokens.

# =============================================================================
# FASE L
# FRONTEND EXPERIENCE ARCHITECTURE (FXA)
# =============================================================================

## L.0 Objetivo

Este capítulo define la arquitectura oficial del Frontend de OSPulso.
No documenta componentes visuales.
No documenta reglas de negocio.
Documenta el comportamiento del cliente.
El navegador constituye un Runtime Inteligente.

Su función consiste en:
• Administrar la navegación
• Administrar vistas
• Administrar estado
• Administrar sesiones
• Administrar comunicación con Backend
• Administrar sincronización
• Administrar experiencia del usuario
Toda aplicación web deberá obedecer esta arquitectura.

## L.1 Filosofía

El navegador no representa páginas HTML.
Representa una aplicación.

La navegación nunca recarga completamente el sitio.

Todo cambio ocurre dentro del Runtime SPA.

La percepción de velocidad es tan importante como la velocidad real.

El usuario nunca debe sentir que "cambió de página".

Debe sentir continuidad.

## L.2 Arquitectura General
Browser
↓
SPA Runtime
↓
View Manager
↓
State Manager
↓
Ajax Engine
↓
API Client
↓
Backend Perl
↓
Business Engine

## L.3 Shell SPA

La aplicación inicia cargando únicamente:
• HTML Base
• CSS Global
• Tokens
• Bootstrap
• Librerías
• Router
• Runtime

Todo el contenido posterior será dinámico.

Nunca volver a cargar el documento completo salvo cierre de sesión o actualización mayor.

## L.4 Ciclo de Vida

Application Start
↓
Authentication
↓
Bootstrap Runtime
↓
Load User Context
↓
Load Menu
↓
Load Dashboard
↓
User Interaction
↓
Ajax
↓
DOM Update
↓
Idle
↓
Next Interaction

## L.5 Router
Toda navegación utiliza rutas internas.
Nunca navegación física.
Ejemplos
/dashboard
/pacientes
/agenda
/consulta
/expediente
/reportes
/configuracion

El Router mantiene el historial del navegador.
Debe permitir navegación mediante Back y Forward sin pérdida de contexto.

## L.6 View Manager
Toda vista posee un ciclo de vida.
Inicialización
↓
Carga
↓
Render
↓
Interacción
↓
Actualización
↓
Destrucción

No se mantienen vistas ocultas innecesariamente en memoria.

## L.7 Estado del Cliente
El estado se divide en:

Estado Global
↓
Estado de Módulo
↓
Estado de Vista
↓
Estado Temporal

El estado temporal nunca persiste entre sesiones.

El estado global representa el contexto del usuario autenticado.

## L.8 Contexto
Toda vista conoce:
Usuario
Organización
Sucursal
Rol
Permisos
Tema
Idioma
Sesión
Nunca consultar nuevamente esta información mientras la sesión permanezca válida.

## L.9 Ajax Engine
Toda comunicación utiliza un cliente único.
Responsabilidades:
Enviar solicitudes
Cancelar solicitudes
Reintentos
Timeout
Control de concurrencia
Control de errores
Registro
Nunca realizar llamadas Ajax directamente desde componentes individuales.

## L.10 API Client
Todo acceso al Backend pasa por una única capa.
Responsabilidades:
Serialización JSON
Headers
Autenticación
Tokens
Errores
Logs
Versionado
El Frontend nunca conoce detalles internos del Backend.

## L.11 Formularios Inteligentes
Todo formulario:
Valida antes de enviar.
Detecta cambios.
Previene pérdida de información.
Muestra progreso.
Permite recuperación.
Nunca envía datos inválidos al servidor cuando la validación puede realizarse en cliente.

## L.12 Persistencia Temporal
El Runtime podrá almacenar temporalmente:
Filtros
Ordenamientos
Búsquedas
Preferencias
Última vista
Siempre respetando la privacidad del usuario.
Nunca almacenar información clínica sensible fuera del servidor.

## L.13 Caché
Cache de:
Catálogos
Configuración
Iconografía
Plantillas
Permisos
Nunca cachear expedientes clínicos ni información sensible salvo estrategias explícitas y controladas.

## L.14 Sincronización
Toda actualización deberá:
Detectar conflictos.
Actualizar vistas activas.
Invalidar caché cuando corresponda.
Mantener consistencia entre módulos.
El usuario nunca deberá ver información incoherente dentro de la misma sesión.

## L.15 Manejo de Errores
Errores de red.
Errores de autenticación.
Errores de autorización.
Errores de validación.
Errores del servidor.
Timeout.
Sesión expirada.
Cada categoría posee una estrategia específica de recuperación.

## L.16 Carga Progresiva
La aplicación utilizará:
Skeletons.
Lazy Loading.
Carga diferida.
Prefetch inteligente.
Render incremental.
La percepción de velocidad tiene prioridad sobre la carga masiva de información.

## L.17 Navegación Contextual
El usuario nunca pierde el contexto.
Toda navegación conserva:
Paciente activo.
Consulta activa.
Sucursal.
Filtros.
Ordenamientos.
Búsquedas.
La continuidad del trabajo clínico tiene prioridad sobre la navegación.

## L.18 Accesibilidad
Todo componente del Runtime deberá:
Ser navegable por teclado.
Mantener foco.
Gestionar lectores de pantalla.
Evitar cambios inesperados.
Informar estados dinámicos mediante mecanismos accesibles.

## L.19 Observabilidad
El Runtime registrará:
Errores JavaScript.
Tiempo de carga.
Tiempo de render.
Tiempo Ajax.
Errores de red.
Uso de componentes.
No registrará información clínica identificable en métricas técnicas.

## L.20 Seguridad
Nunca confiar en validaciones del cliente.
Nunca almacenar credenciales.
Nunca exponer lógica crítica.
Nunca asumir permisos.
Toda autorización pertenece al servidor.

## L.21 Integración con Backend Perl
El Frontend se comunica exclusivamente mediante:
Ajax
↓
JSON
↓
REST
↓
CGI Perl

El Frontend nunca accede directamente a archivos .dat.
Nunca interpreta reglas de negocio.
Nunca modifica estructuras persistentes.

## L.22 Performance Budget
Primer render:
< 2 segundos

Cambio de vista:
< 500 ms

Respuesta Ajax esperada:
< 300 ms
Carga diferida para operaciones costosas.
Toda degradación deberá ser medible.

## L.23 Definition of Done
La arquitectura Frontend se considera completa cuando:

✓ Toda navegación ocurre dentro del Runtime SPA.
✓ Toda comunicación pasa por un cliente Ajax único.
✓ Existe separación entre UI y lógica de negocio.
✓ El contexto del usuario permanece consistente.
✓ Los errores son recuperables.
✓ El rendimiento es medible.
✓ La seguridad depende del servidor.
✓ El Runtime puede evolucionar sin alterar el dominio del negocio.

# =============================================================================
# FASE M
# APPLICATION RUNTIME & SERVICE ARCHITECTURE (ARSA)
# =============================================================================

## M.0 Objetivo
Este capítulo define la arquitectura de ejecución del servidor OSPulso.

No describe la interfaz de usuario.
No describe la base de datos.
No describe el dominio.
Describe cómo el sistema ejecuta los casos de uso.

El Runtime del Servidor es responsable de:
• Orquestar procesos
• Validar solicitudes
• Ejecutar reglas de negocio
• Gestionar transacciones
• Administrar servicios
• Generar respuestas

Todo caso de uso deberá ejecutarse siguiendo esta arquitectura.

## M.1 Filosofía
El Backend no responde páginas.
Resuelve casos de uso.
Toda petición representa una intención del usuario.
El servidor interpreta esa intención y coordina los servicios necesarios.
Los módulos nunca se comunican mediante HTML.
Se comunican mediante contratos de aplicación.

## M.2 Arquitectura General
Browser
↓
SPA Runtime
↓
Ajax
↓
REST Endpoint
↓
Application Runtime
↓
Application Service
↓
Domain
↓
Infrastructure
↓
.dat / JSON / Storage

## M.3 Flujo de Ejecución
Request
↓
Authentication
↓
Authorization
↓
Validation
↓
Application Service
↓
Domain Rules
↓
Persistence
↓
Audit
↓
Response

Toda petición sigue exactamente este flujo.

## M.4 Request Pipeline
Toda solicitud atraviesa:
1. Parseo.
2. Validación estructural.
3. Validación de sesión.
4. Validación de permisos.
5. Validación del dominio.
6. Ejecución.
7. Persistencia.
8. Auditoría.
9. Respuesta.
Nunca alterar este orden.

## M.5 Casos de Uso - Use Cases
Cada servicio implementa un único caso de uso.

Ejemplos:
RegistrarPaciente
ActualizarPaciente
ProgramarCita
CancelarCita
IniciarConsulta
GuardarSOAP
EmitirReceta
RegistrarPago
EmitirFactura
GenerarReporte
No existen servicios genéricos.

## M.6 Application Service
Responsabilidades:
Coordinar servicios.
Invocar reglas de dominio.
Abrir transacciones.
Cerrar transacciones.
Publicar eventos.
Registrar auditoría.
Nunca contiene lógica clínica compleja.
Nunca accede directamente al Frontend.

## M.7 Domain Service
Toda lógica médica pertenece aquí.
Ejemplos:
Validar SOAP.
Calcular edad.
Validar tratamiento.
Detectar conflictos.
Aplicar reglas clínicas.
Determinar estados.
No conoce infraestructura.

## M.8 Infrastructure
Responsable de:
Lectura DAT.
Escritura DAT.
Generación JSON.
Logs.
Correo.
Archivos.
Impresión.
Integraciones.
No contiene reglas del negocio.

## M.9 Repositories - Repository Pattern
Toda entidad posee un repositorio.
PacienteRepository
AgendaRepository
ConsultaRepository
FacturaRepository
DocumentoRepository
Los repositorios abstraen la persistencia.
El dominio nunca conoce archivos.
    
## M.10 Persistencia - Persistence
La persistencia oficial utiliza:
Archivos .dat
JSON derivados
Versionado
Índices
Cache
El Runtime nunca manipula archivos directamente.
Siempre utiliza repositorios.

## M.11 Transacciones - Transactions
Toda operación crítica deberá ser:
Atómica.
Consistente.
Reversible cuando aplique.
Auditable.
Una falla revierte toda la operación.

## M.12 Validaciones - Validation Layers
1. Cliente.
2. Endpoint.
3. Servicio.
4. Dominio.
5. Persistencia.

Nunca depender únicamente del cliente.

## M.13 Manejo de Errores - Error Strategy
Clasificar errores:
Validación.
Permisos.
Negocio.
Infraestructura.
Integración.
Sistema.

Cada categoría posee una respuesta uniforme.

## M.14 Logging
Toda petición registra:
ID.
Usuario.
IP.
Ruta.
Tiempo.
Resultado.
Errores.
Duración.
Nunca registrar contraseñas o información sensible.

## M.15 Auditoría - Audit Trail
Toda modificación genera:
Entidad.
Acción.
Antes.
Después.
Usuario.
Fecha.
Origen.
Motivo.

## M.16 Eventos - Event Dispatcher
El Runtime publica eventos.
Ejemplos:
PacienteRegistrado.
ConsultaFinalizada.
PagoRegistrado.
FacturaEmitida.
DocumentoFirmado.
Los consumidores reaccionan.
Nunca bloquean el flujo principal.

## M.17 Integraciones - External Services
Correo.
WhatsApp.
FHIR.
HL7.
DICOM.
SAT.
Google Calendar.

Toda integración se realiza mediante adaptadores.

Nunca desde el dominio.

## M.18 Seguridad - Security
El Runtime valida:
Sesión.
Permisos.
CSRF.
Rate Limit.
Origen.
Integridad.
Todas las decisiones de seguridad ocurren en servidor.

## M.19 Respuesta - Response
Formato oficial:
JSON
Toda respuesta contiene:
status
code
message
timestamp
requestId
data
errors
meta

Nunca devolver HTML para operaciones Ajax.

## M.20 Performance
Tiempo objetivo:
Validación
<10 ms

Servicio
<100 ms

Persistencia
<150 ms

Respuesta completa
<300 ms

Toda degradación deberá registrarse.

## M.21 Observabilidad - Observability
Métricas:
Tiempo.
Errores.
Uso.
Servicios.
Eventos.
Colas.
Integraciones.
Toda métrica posee identificación única.

## M.22 Convenciones Perl - Perl Runtime Standards
Todos los scripts CGI deberán iniciar con:
#!/usr/bin/perl

use cPanelUserConfig;
use strict;
use warnings;
use CGI;
use JSON::PP;

Codificación:
UTF-8
Saltos de línea:
LF Unix
Permisos:
755

Las reglas de estilo se documentarán en la especificación técnica correspondiente.

## M.23 Estructura Física Recomendada
/cgi-bin
    /api
    /services
    /domain
    /repositories
    /infrastructure
    /validators
    /events
    /middleware
    /config
    /utils

/dat
/json
/img
/pdfs
/logs
/cache
/tmp

## M.24 Definition of Done - DoD
El Runtime se considera completo cuando:

✓ Todo caso de uso posee Application Service.
✓ Toda regla pertenece al dominio.
✓ Toda persistencia utiliza repositorios.
✓ Toda respuesta es uniforme.
✓ Todo error es clasificable.
✓ Toda operación genera auditoría.
✓ Todo evento es publicable.
✓ Toda integración es desacoplada.
✓ Toda petición puede rastrearse extremo a extremo.

# =============================================================================
# FASE N
# ENTERPRISE MODULAR MONOLITH ARCHITECTURE (EMMA)
# =============================================================================

## N.0 Objetivo
Este capítulo define la arquitectura modular oficial de OSPulso.

El sistema será implementado como un Monolito Modular.

Cada dominio constituye un módulo independiente.

Los módulos colaboran mediante contratos internos.

Nunca mediante dependencias implícitas.

La modularidad tiene prioridad sobre la separación física.

El objetivo es obtener:
• Alta cohesión
• Bajo acoplamiento
• Escalabilidad
• Mantenibilidad
• Facilidad de despliegue
• Evolución gradual

## N.1 Filosofía
OSPulso es una sola aplicación.
No un conjunto de aplicaciones.
Sin embargo,
cada módulo posee autonomía conceptual.

El sistema deberá poder evolucionar durante años sin requerir reescrituras completas.

La separación ocurre por responsabilidades.
No por carpetas.

## N.2 Arquitectura
OSPulso
│
├── Core
├── Patients
├── Scheduling
├── Clinical
├── CRM
├── Finance
├── Analytics
├── AI
├── Communication
├── Documents
├── Security
├── Integrations
└── Administration

## N.3 Principio Fundamental - Modularidad
Todo módulo responde únicamente una pregunta:

¿Qué responsabilidad posee?

Nunca:
¿Qué tablas administra?

Nunca:
¿Qué pantallas contiene?
Los módulos representan capacidades del negocio.

## N.4 Independencia
Todo módulo puede evolucionar.
Todo módulo puede probarse.
Todo módulo puede documentarse.
Todo módulo puede reemplazarse.
Siempre que respete el contrato oficial.

## N.5 Estructura Interna
Clinical
│
├── Application
├── Domain
├── Infrastructure
├── Contracts
├── Events
├── DTO
└── Tests

Todos los módulos utilizan exactamente la misma estructura.

## N.6 Contratos - Contracts
Los módulos nunca consumen implementaciones.
Consumen contratos.

Ejemplo:
Scheduling solicita:
ClinicalContract

Nunca:
ClinicalRepository
Esto evita acoplamiento.

## N.7 Comunicación
Module A
↓
Application Service
↓
Contract
↓
Application Service
↓

Module B
Nunca:
Repository → Repository.

Nunca:
Controller → Controller.
Nunca:
CGI → CGI.

## N.8 Dependencias Permitidas
Core
↓
Todos
Clinical
↓
Finance
↓
Analytics
↓
AI
Dependencias circulares prohibidas.

## N.9 Eventos - Internal Events
Los módulos se notifican mediante eventos.
Ejemplos
PacienteRegistrado
↓
Scheduling
↓
CRM
↓
Analytics
↓
AI
El emisor desconoce quién consume el evento.

## N.10 Application Layer
Coordina.
Nunca decide.
Nunca persiste.
Nunca renderiza.
Nunca valida reglas clínicas.
Su única responsabilidad consiste en ejecutar casos de uso.

## N.11 Domain Layer
Toda decisión pertenece aquí.
Reglas.
Estados.
Validaciones.
Eventos.
Políticas.

Nunca conoce:
CGI
JSON
HTML
Bootstrap
AJAX
Archivos

## N.12 Infrastructure Layer
Implementa:
DAT
JSON
Correo
Logs
PDF
SAT
FHIR
HL7
DICOM
Integraciones
Nunca contiene reglas clínicas.

## N.13 Shared Kernel
Sólo contiene:
Tipos comunes.
Excepciones.
Helpers.
Interfaces.
Eventos base.
Nunca lógica de negocio.
Nunca entidades clínicas.

## N.14 Anti Corruption Layer - ACL
Toda integración externa pasa por una capa de adaptación.

FHIR
↓
ACL
↓
Clinical
Nunca conectar directamente un proveedor con el dominio.

## N.15 Versionado - Module Version
Cada módulo posee:
Versión.
Autor.
Dependencias.
Eventos publicados.
Eventos consumidos.
Contratos.
Nunca depender únicamente de la versión global.

## N.16 Configuración - Configuration
Todo módulo puede configurarse.
Nunca modificar código.

Toda personalización ocurre mediante configuración.

## N.17 Observabilidad - Module Metrics
Cada módulo registra:
Tiempo.
Errores.
Eventos.
Uso.
Integraciones.
Toda métrica identifica el módulo origen.

## N.18 Escalabilidad - Evolución
Si un módulo requiere escalar.
Podrá migrarse a:
Servicio independiente.
Worker.
Proceso asíncrono.
Microservicio.
Sin modificar el resto del ecosistema.
La arquitectura debe facilitar esta transición.

## N.19 Reglas de Oro - Golden Rules
Un módulo.
Una responsabilidad.
Un lenguaje.
Un contrato.
Una auditoría.
Un propietario.
Una documentación.
Siempre.

## N.20 Convención Física
/modules
/core
/clinical
/patients
/finance
/crm
/analytics
/security
/integrations
/shared
/application
/infrastructure
/contracts
/events

## N.21 Ciclo de Vida de un Módulo
Definición
↓
Diseño
↓
Contratos
↓
Eventos
↓
Implementación
↓
Pruebas
↓
Documentación
↓
Liberación
↓
Monitoreo
↓
Evolución

## N.22 Reglas para Perl CGI - Perl Compatibility
La modularidad es lógica, no tecnológica.
Cada módulo puede implementarse mediante:
CGI Perl
Librerías Perl
Paquetes Perl
Módulos reutilizables
El lenguaje no limita la arquitectura.
La arquitectura gobierna al lenguaje.

## N.23 Definition of Done - DoD
La arquitectura modular se considera completa cuando:

✓ Ningún módulo conoce la implementación interna de otro.
✓ Toda comunicación ocurre mediante contratos.
✓ No existen dependencias circulares.
✓ Toda integración utiliza adaptadores.
✓ Todo módulo posee documentación.
✓ Todo módulo posee métricas.
✓ Todo módulo puede evolucionar independientemente.
✓ Toda lógica clínica permanece aislada del framework y de la infraestructura.

# =============================================================================
# FASE O
# ENGINEERING STANDARDS & DEVELOPMENT GOVERNANCE
# =============================================================================

## O.0 Objetivo
Este capítulo establece las normas oficiales de ingeniería para el desarrollo de OSPulso.

Todo desarrollador, arquitecto, consultor o colaborador deberá seguir estas reglas.

Estas normas son obligatorias para garantizar:
• Consistencia
• Calidad
• Escalabilidad
• Seguridad
• Legibilidad
• Mantenibilidad
• Evolución del producto
Las decisiones personales nunca tienen prioridad sobre este documento.

## O.1 Filosofía
El software debe ser fácil de modificar.
No solamente fácil de escribir.

Toda línea de código será leída muchas más veces de las que será escrita.

La claridad tiene prioridad sobre la creatividad.
La simplicidad tiene prioridad sobre la complejidad.
Toda implementación deberá facilitar el mantenimiento futuro.

## O.2 Principios
Una responsabilidad por módulo.
Una responsabilidad por archivo.
Una responsabilidad por función.
Funciones pequeñas.
Clases pequeñas.
Scripts pequeños.
Alta cohesión.
Bajo acoplamiento.
Código expresivo.
Código predecible.
Código auditable.

## O.3 Convenciones Globales - Naming Convention
Archivos
snake_case

Variables
camelCase

Funciones
camelCase

Paquetes Perl
PascalCase

Constantes
UPPER_SNAKE_CASE

Endpoints
kebab-case

Rutas
snake_case

Nunca mezclar estilos.

## O.4 Estándares Perl
Todo CGI inicia con:
#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use Encode;
Toda salida utiliza UTF-8.
Todos los archivos utilizan LF Unix.
Nunca utilizar módulos experimentales sin aprobación.

## O.5 Organización Física - Estructura de Directorios
/cgi-bin
    /api
    /application
    /domain
    /infrastructure
    /repositories
    /services
    /events
    /validators
    /middleware
    /templates
    /config
    /utils

/assets
/css
/js
/img
/fonts
/dat
/json
/logs
/cache
/tmp
/tests
/docs

## O.6 Estándares HTML
HTML semántico.
Sin estilos inline.
Sin JavaScript inline.
Sin tablas para maquetación.
Etiquetas correctamente anidadas.
Uso consistente de atributos ARIA cuando corresponda.
Todo formulario utiliza labels visibles.
Todo elemento interactivo posee identificación única.

## O.7 Estándares CSS
Bootstrap como base.
Design Tokens obligatorios.
Variables CSS.
Componentes reutilizables.

No utilizar:
!important
Estilos duplicados
Selectores excesivamente específicos
Todo CSS vive en archivos externos.

## O.8 Estándares JavaScript
SPA.
Namespace único OSPulso.
Sin variables globales.
Separación por módulos.
Funciones puras cuando sea posible.
Delegación de eventos.
Una única librería Ajax oficial.
Nunca mezclar lógica de negocio con manipulación del DOM.

## O.9 AJAX
Todas las solicitudes pasan por:
AjaxClient
Nunca utilizar llamadas directas.
Toda petición registra:
requestId
timestamp
endpoint
duración
usuario
Toda respuesta sigue el contrato JSON oficial.

## O.10 JSON
UTF-8
camelCase
ISO-8601
UUID
Objetos consistentes
Sin claves ambiguas

Toda respuesta contiene:
status
code
message
data
meta
requestId

## O.11 Archivos DAT
UTF-8
LF Unix
Delimitador |
Cabecera obligatoria
Checksum opcional
Versionado
Sin TAB.
Sin espacios innecesarios.
Sin líneas vacías internas.
Toda modificación genera respaldo.

## O.12 APIs - REST
GET
POST
PUT
PATCH
DELETE
JSON
HTTPS
Versionado
Nunca utilizar GET para modificar información.
Nunca exponer rutas internas.

## O.13 Errores - Error Strategy
Todo error posee:
Código
Categoría
Mensaje técnico
Mensaje usuario
Origen
requestId
Nunca mostrar stack traces al usuario.
Nunca mostrar rutas del servidor.
Nunca mostrar SQL o detalles internos.

## O.14 Logging
Categorías:
INFO
WARNING
ERROR
SECURITY
AUDIT
DEBUG (solo desarrollo)

Cada entrada registra:
Fecha
Hora
Usuario
IP
Módulo
Acción
Resultado
Duración
requestId

## O.15 Auditoría
Toda modificación registra:
Antes
Después
Usuario
Fecha
IP
Origen
Motivo
Entidad
Versión
La auditoría nunca puede deshabilitarse en producción.

## O.16 Seguridad - Security
CSRF
XSS
Rate Limit
Sanitización
Escape de salida
Validación del servidor
Cookies seguras
Sesiones expiran automáticamente
Nunca confiar en el cliente.

## O.17 Git
main
develop
feature/*
release/*
hotfix/*

Versionado Semántico:
MAJOR.MINOR.PATCH
Todo commit requiere mensaje descriptivo.
No realizar commits directos a main.

## O.18 Code Review - Checklist
Cumple arquitectura.
Cumple dominio.
Cumple UX.
Cumple seguridad.
Cumple rendimiento.
Cumple accesibilidad.
Cumple normativa.
No introduce deuda técnica.
No rompe compatibilidad.
Está documentado.

## O.19 Calidad - QA
Smoke Tests
Regression
Clinical Validation
Financial Validation
Performance
Accessibility
Security
Cross Browser
Responsive
Toda funcionalidad debe validarse antes de liberarse.

## O.20 Documentación - Documentation
Todo módulo incluye:
README
Arquitectura
Dependencias
Eventos
Contratos
Configuración
Casos de uso
Limitaciones
Historial de cambios
La documentación forma parte del código.

## O.21 Gestión de Configuración - Configuration
Nunca almacenar configuraciones en el código.
Toda configuración proviene de archivos dedicados.

Las credenciales nunca forman parte del repositorio.

Las configuraciones son versionadas y documentadas.

## O.22 Gestión de Dependencias - Dependencies
Preferir módulos estándar de Perl.
Evaluar dependencias externas antes de incorporarlas.

Registrar versión, licencia y motivo de uso.

Eliminar dependencias obsoletas.

Mantener inventario actualizado.

## O.23 Rendimiento - Performance
Toda optimización deberá estar respaldada por mediciones.
Evitar optimizaciones prematuras.
Documentar cuellos de botella conocidos.
Definir presupuestos de rendimiento por módulo.

## O.24 Compatibilidad - Compatibility
Compatibilidad mínima:
Linux
Apache
Perl estable
Bootstrap oficial
Navegadores modernos soportados por el proyecto
Toda incompatibilidad conocida deberá documentarse.

## O.25 Checklist de Liberación - Release Checklist
✓ QA aprobado.
✓ Auditoría funcional.
✓ Revisión de seguridad.
✓ Migraciones verificadas.
✓ Documentación actualizada.
✓ Versionado aplicado.
✓ Logs revisados.
✓ Copia de seguridad disponible.
✓ Plan de reversión documentado.

## O.26 Definition of Done - DoD
Una implementación cumple esta fase cuando:
✓ Respeta las convenciones del proyecto.
✓ Cumple la arquitectura.
✓ Está documentada.
✓ Es segura.
✓ Es mantenible.
✓ Es medible.
✓ Es auditable.
✓ Es versionable.
✓ Puede ser comprendida por un desarrollador nuevo únicamente leyendo el OMS.

# =============================================================================
# FASE P
# IMPLEMENTATION BLUEPRINT (IBP)
# =============================================================================

## P.0 Objetivo
Este capítulo define el orden oficial de construcción del ecosistema OSPulso.

No establece prioridades comerciales.

Establece dependencias técnicas.

Cada etapa existe porque la siguiente depende de ella.

Nunca deberán desarrollarse módulos fuera de esta secuencia sin una justificación arquitectónica documentada.

El objetivo es minimizar deuda técnica, retrabajo y dependencias circulares.

## P.1 Filosofía
OSPulso se construye desde el núcleo hacia el exterior.

No desde las pantallas hacia el backend.

La secuencia correcta es:

Arquitectura
↓
Infraestructura
↓
Servicios
↓
Dominio
↓
UX
↓
UI
↓
Experiencia
↓
Optimización

Nunca invertir este flujo.

## P.2 Roadmap Maestro
Foundation
↓
Platform Core
↓
Business Core
↓
Clinical Core
↓
Financial Core
↓
CRM
↓
Analytics
↓
Artificial Intelligence
↓
Integrations
↓
Optimization
↓
Production

## P.3 Etapa 0 — Foundation - Stage 0
Objetivo
Preparar el entorno de desarrollo.

Incluye:
Repositorio Git.
Estructura física.
Convenciones.
Bootstrap.
Tokens.
Configuraciones.
Linters.
Scripts.
Pipeline.
Nada de negocio se implementa aquí.

## P.4 Etapa 1 — Platform Core - Stage 1
Implementar:
Usuarios.
Roles.
Permisos.
Autenticación.
Sesiones.
Configuración.
Catálogos.
Auditoría.
Logging.
Eventos.
Sin esta etapa no existe plataforma.

## P.5 Etapa 2 — Shared Kernel - Stage 2
Construir:
Helpers.
DTO.
Contracts.
Repositories Base.
Application Base.
Exceptions.
Middlewares.
Utilities.
Todo módulo utilizará este núcleo.

## P.6 Etapa 3 — Patients - Stage 3
Implementar:
Paciente.
Contacto.
Identificación.
Expediente Administrativo.
Búsquedas.
Importaciones.
Exportaciones.
Validaciones.
A partir de aquí existe un sujeto clínico.

## P.7 Etapa 4 — Scheduling - Stage 4
Construir:
Agenda.
Calendario.
Disponibilidad.
Recursos.
Consultorios.
Recordatorios.
Confirmaciones.
No Shows.
Colisiones.
Sin agenda no existe operación clínica.

## P.8 Etapa 5 — Clinical Core - Stage 5
Implementar:
Consulta.
SOAP.
Odontograma.
Diagnóstico.
Tratamientos.
Prescripciones.
Recetas.
Notas.
Consentimientos.
Este es el corazón de OSPulso.

## P.9 Etapa 6 — Clinical Documents - Stage 6
Implementar:
PDF.
Radiografías.
DICOM.
Adjuntos.
Laboratorios.
Consentimientos.
Firmas.
Versionado.
Toda evidencia clínica vive aquí.

## P.10 Etapa 7 — Finance - Stage 7
Construir:
Presupuestos.
Pagos.
Facturación.
Caja.
Cobranza.
Comisiones.
Estados financieros.
Reportes.
El dominio financiero permanece independiente del clínico.

## P.11 Etapa 8 — CRM - Stage 8
Implementar:
Leads.
Prospectos.
Campañas.
Seguimientos.
Automatizaciones.
Conversión.
Retención.
Relación con pacientes.

## P.12 Etapa 9 — Inventory - Stage 9
Implementar:
Productos.
Servicios.
Insumos.
Lotes.
Caducidades.
Movimientos.
Proveedores.
Compras.

## P.13 Etapa 10 — Analytics - Stage 10
Construir:
KPIs.
Dashboards.
Reportes.
Indicadores.
Business Intelligence.
Métricas.
Alertas.
Predicciones descriptivas.

## P.14 Etapa 11 — Artificial Intelligence - Stage 11
Integrar:
ICO.
Resúmenes.
Clasificación.
Priorización.
Sugerencias.
Asistentes.
Automatización inteligente.
La IA nunca reemplaza reglas del dominio.

## P.15 Etapa 12 — Integrations - Stage 12
Implementar:
FHIR.
HL7.
DICOM.
SAT.
WhatsApp.
Correo.
Google Calendar.
Servicios externos.
Toda integración utiliza adaptadores.

## P.16 Etapa 13 — UX Refinement - Stage 13
Optimizar:
Flujos.
Microinteracciones.
Accesibilidad.
Responsive.
Tiempo de navegación.
Reducción de clics.
Consistencia.
El producto ya funciona.
Ahora se perfecciona.

## P.17 Etapa 14 — Performance - Stage 14
Optimizar:
Consultas.
Cache.
Compresión.
Minificación.
Lazy Loading.
Preloading.
Render.
Consumo de memoria.
Toda optimización se basa en métricas.

## P.18 Etapa 15 — Security Hardening - Stage 15
Validar:
CSRF.
XSS.
Rate Limit.
Headers.
Permisos.
Auditoría.
Firmas.
Logs.
PenTesting.
Antes de producción.
    
## P.19 Etapa 16 — Production - Stage 16
Preparar:
Backups.
Migraciones.
Rollback.
Monitoreo.
Alertas.
Documentación.
Checklist.
Capacitación.
Liberación.
Aquí termina el proyecto.
Y comienza el producto.

## P.20 Dependencias
Core
↓
Patients
↓
Scheduling
↓
Clinical
↓
Finance
↓
CRM
↓
Analytics
↓
AI
↓
Integrations

Nunca alterar este orden sin una ADR (Architecture Decision Record).

## P.21 Paralelización - Parallel Work
Pueden desarrollarse en paralelo:
UX
UI
Documentación
Marketing
Landing
Presentaciones
Siempre que respeten el dominio oficial.

## P.22 Definition of Done - DoD
Cada etapa finaliza cuando:
✓ Todas las dependencias están satisfechas.
✓ QA aprobado.
✓ Documentación actualizada.
✓ KPIs definidos.
✓ Auditoría habilitada.
✓ Seguridad validada.
✓ Pruebas de regresión exitosas.
✓ Arquitectura revisada.
✓ Checklist de liberación completado.

## P.23 Architecture Decision Records (ADR) - ADR (Architecture Decision Records)
Toda decisión arquitectónica relevante deberá registrarse mediante un ADR.

    ## Objetivo

    Mantener un historial de decisiones técnicas y funcionales para comprender el contexto del sistema a lo largo del tiempo.

    ## Estructura mínima

    - Identificador (ADR-0001, ADR-0002, ...)
    - Fecha
    - Estado (Propuesto, Aprobado, Reemplazado, Obsoleto)
    - Contexto
    - Problema
    - Alternativas evaluadas
    - Decisión adoptada
    - Justificación
    - Consecuencias
    - Impacto en arquitectura
    - Referencias al OMS

    ## Reglas

    - Ningún cambio estructural importante se implementa sin ADR.
    - Los ADR forman parte de la documentación oficial del proyecto.
    - Un ADR nunca se elimina; puede ser reemplazado por otro.

## P.24 Roadmap de Evolución - Evolución del Producto
    ## Versión 1.x
    Clínica privada, monolito modular, operación estándar.

    ## Versión 2.x
    Capacidades de negocio (Business Capabilities), multiempresa, convenios, mayor automatización e IA.

    ## Versión 3.x
    Hospitales, interoperabilidad ampliada, despliegues distribuidos, servicios desacoplados donde aporten valor.

    La evolución debe preservar la compatibilidad del núcleo siempre que sea posible.

## P.25 Definition of Success
El Implementation Blueprint se considera exitoso cuando un equipo nuevo puede construir OSPulso siguiendo este documento, sin depender del conocimiento implícito de sus autores.

El OMS deja de ser únicamente documentación y se convierte en el plano oficial de construcción del producto.

# =============================================================================
# FASE Q
# ARCHITECTURE GOVERNANCE & DECISION MANAGEMENT (AGDM)
# =============================================================================

## Q.0 Objetivo
Este capítulo establece el modelo oficial de gobierno de arquitectura para OSPulso.

Su propósito es preservar la coherencia del ecosistema durante toda su evolución.

Toda decisión relevante deberá documentarse.

Toda excepción deberá justificarse.

Toda modificación arquitectónica deberá ser trazable.

El gobierno de arquitectura es responsabilidad compartida entre el equipo técnico y el equipo de producto.
## Q.1 Filosofía
La arquitectura es un activo estratégico.
No pertenece a un desarrollador.
No pertenece a una tecnología.
Pertenece al producto.
Las decisiones se documentan.
Las excepciones se aprueban.
La deuda técnica se registra.
La evolución se planifica.
Nunca se improvisa.

## Q.2 Principios de Gobierno
Consistencia.
Trazabilidad.
Transparencia.
Responsabilidad.
Reproducibilidad.
Versionado.
Revisión continua.
Mejora incremental.
Toda decisión debe poder explicarse años después de haber sido tomada.

## Q.3 Architecture Decision Records (ADR)
Toda decisión estructural requiere un ADR.
Ejemplos:
Cambio de arquitectura.
Nuevo módulo.
Cambio de persistencia.
Cambio de API.
Cambio de proveedor.
Cambio de seguridad.
Cambio de IA.
Cambio de estándares.

## Q.4 Plantilla ADR - Estructura
ADR-0001
Título
Estado
Fecha
Autores
Contexto
Problema
Alternativas
Decisión
Justificación
Consecuencias
Impacto
Riesgos
Referencias
Estado Final

## Q.5 Estados ADR
Propuesto
En revisión
Aprobado
Implementado
Reemplazado
Obsoleto
Nunca eliminar ADR.
Sólo cambiar su estado.

## Q.6 Registro de Riesgos - Risk Register
Cada riesgo registra:
ID
Descripción
Probabilidad
Impacto
Prioridad
Responsable
Mitigación
Estado
Fecha
Categoría

## Q.7 Clasificación de Riesgos - Categorías
Arquitectura
Seguridad
Normatividad
Operación
Infraestructura
UX
Frontend
Backend
Integraciones
IA
Negocio
Legal
Finanzas

## Q.8 Matriz de Riesgo
Impacto
Alto
■■■
Medio
■■
Bajo
■
×
Probabilidad

Todo riesgo debe posicionarse en la matriz.

## Q.9 Registro de Deuda Técnica - Technical Debt
Toda deuda registra:
ID
Descripción
Origen
Impacto
Costo estimado
Beneficio esperado
Fecha
Responsable
Plan de eliminación
Nunca ocultar deuda técnica.
Toda deuda aceptada deberá documentarse.

## Q.10 Supuestos Arquitectónicos - Assumptions
Todo supuesto registra:
Descripción
Justificación
Impacto
Fecha
Validez
Dependencias
Los supuestos deberán revisarse periódicamente.

## Q.11 Restricciones - Constraints
Ejemplos:
Backend Perl CGI.
Persistencia DAT.
SPA.
Bootstrap.
Sin Docker obligatorio.
Orientado inicialmente a clínicas privadas.

Cada restricción posee:
Origen.
Justificación.
Impacto.
Fecha de revisión.

## Q.12 Registro de Excepciones - Exceptions
Toda excepción requiere:
Motivo.
Responsable.
Duración.
Impacto.
Plan de regularización.
Aprobación.
Las excepciones nunca se vuelven permanentes sin revisión.

## Q.13 Comité de Arquitectura - Architecture Review Board
Responsabilidades:
Revisar ADR.
Aprobar excepciones.
Evaluar riesgos.
Revisar deuda técnica.
Validar estándares.
Aprobar cambios estructurales.
Resolver conflictos de arquitectura.

## Q.14 Criterios de Revisión - Review Checklist
Respeta el dominio.
Respeta la arquitectura.
Respeta UX.
Respeta seguridad.
Respeta ingeniería.
Respeta normativa.
Respeta escalabilidad.
Respeta mantenibilidad.
Toda revisión utiliza el mismo checklist.

## Q.15 Gestión del Cambio - Change Management
Toda modificación registra:
Origen.
Motivo.
Impacto.
Riesgo.
Dependencias.
Versiones afectadas.
Plan de despliegue.
Plan de reversión.

## Q.16 Versionado del OMS - OMS Versioning
Semantic Versioning:
Major
Minor
Patch

Cada versión registra:
Fecha.
Autores.
Cambios.
ADR relacionados.
Compatibilidad.
Notas de migración.

## Q.17 Indicadores de Arquitectura - Architecture KPIs
Número de ADR abiertos.
Número de ADR implementados.
Deuda técnica pendiente.
Cobertura documental.
Cumplimiento de estándares.
Dependencias circulares.
Tiempo medio de revisión.
Número de excepciones activas.

## Q.18 Auditoría Arquitectónica - Architecture Audit
Periodicidad recomendada:
Trimestral.
Revisión de:
Módulos.
Dependencias.
Estándares.
Seguridad.
Documentación.
Riesgos.
La auditoría genera un informe ejecutivo.

## Q.19 Lecciones Aprendidas - Lessons Learned
Cada proyecto relevante documenta:
Contexto.
Qué funcionó.
Qué falló.
Qué se mejorará.
Recomendaciones.
Estas lecciones alimentan futuras versiones del OMS.

## Q.20 Definition of Done - DoD
El modelo de gobierno se considera completo cuando:
✓ Toda decisión importante tiene ADR.
✓ Toda deuda técnica está registrada.
✓ Todos los riesgos tienen responsable.
✓ Toda excepción posee fecha de revisión.
✓ El OMS está versionado.
✓ Existe un proceso formal para aprobar cambios.
✓ La arquitectura puede evolucionar sin perder coherencia.

# =============================================================================
# FASE R
# PLATFORM INFRASTRUCTURE & INTEGRATION ARCHITECTURE (PIIA)
# =============================================================================

## R.0 Objetivo
Este capítulo define la infraestructura oficial del ecosistema OSPulso.

Su propósito consiste en garantizar que toda operación técnica ocurra bajo un modelo uniforme.

La infraestructura proporciona:

• Persistencia
• Comunicación
• Integraciones
• Operación
• Recuperación
• Monitoreo
• Disponibilidad

La infraestructura nunca implementa reglas del negocio.

Únicamente sostiene al ecosistema.

## R.1 Filosofía
La infraestructura debe ser invisible.

El usuario nunca debe preocuparse por servidores.

Nunca por almacenamiento.

Nunca por integraciones.

Nunca por respaldos.

Todo debe funcionar como un servicio transparente.

La simplicidad operacional tiene prioridad sobre la sofisticación tecnológica.

## R.2 Arquitectura General
Frontend SPA
↓
REST APIs
↓
Application Runtime
↓
Repositories
↓
Storage Layer
↓
Infrastructure Services
↓
Linux
↓
Apache
↓
Filesystem

## R.3 API Architecture - REST
Todas las APIs son:
Stateless
JSON
UTF-8
HTTPS
Versionadas
Idempotentes cuando aplique.
Cada endpoint representa un caso de uso.
Nunca una tabla.
Nunca un archivo.

## R.4 Convención REST
GET
POST
PUT
PATCH
DELETE
HEAD
OPTIONS
Nunca utilizar GET para operaciones que modifiquen información.

## R.5 Contrato JSON
Toda respuesta contiene:
status
code
message
requestId
timestamp
data
errors
meta

Ejemplo

{
  "status":"success",
  "code":200,
  "message":"Paciente registrado",
  "requestId":"REQ-202600001",
  "timestamp":"2026-07-03T18:40:00Z",
  "data":{},
  "meta":{}
}

## R.6 Persistencia - Persistence
Persistencia oficial:
DAT
↓
JSON
↓
Índices
↓
Cache

Toda modificación genera auditoría.

Nunca escribir directamente desde el Frontend.

## R.7 Archivos DAT
Todo DAT cumple:
UTF-8
LF Unix
|
Cabecera
Checksum opcional
Versionado
Respaldo
Bloqueo durante escritura

## R.8 JSON
JSON constituye la representación de intercambio.
Nunca la fuente primaria.
Todo JSON deriva del repositorio oficial.
El JSON podrá regenerarse en cualquier momento.

## R.9 Índices
Todo catálogo importante posee índices.
Tipos:
Por ID.
Por Código.
Por Nombre.
Por Estado.
Por Fecha.
Los índices aceleran lectura.
Nunca sustituyen la fuente oficial.

## R.10 Cache
La infraestructura podrá cachear:
Catálogos.
Configuraciones.
Permisos.
Plantillas.
Iconografía.
Nunca cachear información clínica editable sin estrategia explícita de invalidación.

## R.11 Locking
Toda escritura crítica utiliza bloqueo.
Objetivos:
Evitar corrupción.
Evitar escritura concurrente.
Garantizar integridad.
El bloqueo debe ser breve y auditable.

## R.12 Jobs
Procesos programados:
Respaldos.
Sincronización.
Limpieza.
Recordatorios.
Reconstrucción de índices.
Generación de reportes.
Nunca ejecutar tareas largas durante una petición HTTP.

## R.13 Integraciones
Toda integración utiliza adaptadores.
FHIR
HL7
DICOM
SAT
Correo
WhatsApp
Google Calendar
SMS
Servicios propios
Cada adaptador es desacoplado del dominio.

## R.14 Almacenamiento
/dat
/json
/img
/pdfs
/logs
/cache
/tmp
/uploads
/backups
Cada directorio tiene una única responsabilidad.

## R.15 Apache
Servidor oficial:
Apache HTTP Server
CGI habilitado.
HTTPS obligatorio.
Compresión Gzip.
Headers seguros.
Logs separados.
Configuración versionada.

## R.16 Linux
Sistema operativo objetivo:
Linux
Permisos mínimos.
Usuario dedicado.
Servicios aislados.
Rotación de logs.
Cron.
Firewall.
Actualizaciones controladas.

## R.17 Backups
Toda instalación deberá implementar:
Respaldo diario.
Respaldo semanal.
Respaldo mensual.
Pruebas periódicas de restauración.
Los respaldos deben estar cifrados cuando contengan información sensible.

## R.18 Recuperación
Toda estrategia contempla:
Fallo de aplicación.
Fallo de almacenamiento.
Fallo eléctrico.
Fallo humano.
Corrupción de archivos.
La recuperación deberá estar documentada y ensayada.

## R.19 Monitoreo
Monitorear:
CPU.
RAM.
Disco.
Apache.
CGI.
Tiempo de respuesta.
Errores.
Jobs.
Backups.
Integraciones.
Toda alerta debe tener un responsable.

## R.20 Observabilidad
Registrar:
RequestId.
Tiempo.
Endpoint.
Usuario.
Resultado.
Errores.
Eventos.
Módulo.
Integración.
Sin observabilidad no existe operación confiable.

## R.21 Disponibilidad
Objetivos:
Alta disponibilidad cuando aplique.
Degradación controlada.
Mantenimiento planificado.
Recuperación rápida.
Documentación operativa.

## R.22 Escalabilidad
La plataforma debe crecer mediante:
Más CPU.
Más RAM.
Separación de módulos.
Workers.
Cache.
Optimización.
La arquitectura debe permitir evolución sin rediseño.

## R.23 Versionado
Toda infraestructura registra:
Versión.
Fecha.
Autor.
Cambios.
Compatibilidad.
Plan de reversión.

## R.24 Checklist Operativo
Antes de producción:
✓ HTTPS.
✓ Backups.
✓ Firewall.
✓ Logs.
✓ Rotación.
✓ Monitoreo.
✓ Cron.
✓ Permisos.
✓ Auditoría.
✓ Restauración validada.

## R.25 Definition of Done
La infraestructura se considera completa cuando:
✓ Toda API respeta el contrato oficial.
✓ Toda persistencia es auditable.
✓ Existen respaldos.
✓ Existe recuperación.
✓ Existe monitoreo.
✓ Existe observabilidad.
✓ Las integraciones están desacopladas.
✓ La plataforma puede desplegarse de forma repetible.
✓ Toda operación crítica posee procedimientos documentados.

# =============================================================================
# FASE S
# INTELLIGENT CLINICAL OPERATIONS ARCHITECTURE (ICOA)
# =============================================================================

## S.0 Objetivo
Este capítulo define la arquitectura oficial de Inteligencia Clínica Operativa (ICO).

ICO constituye el sistema nervioso del ecosistema OSPulso.

Su propósito consiste en:

• Reducir trabajo administrativo.

• Incrementar velocidad operativa.

• Mejorar la calidad de la información.

• Priorizar actividades.

• Automatizar procesos repetitivos.

• Asistir la toma de decisiones.

ICO nunca reemplaza al profesional.

ICO amplifica sus capacidades.

## S.1 Filosofía
La inteligencia no consiste en responder preguntas.

Consiste en reducir trabajo.

Toda capacidad inteligente deberá eliminar complejidad.

Nunca agregarla.

ICO existe para permitir que el profesional dedique más tiempo al paciente.

No al software.

## S.2 Arquitectura General
Usuario
↓
Frontend
↓
Application Runtime
↓
ICO Engine
↓
AI Services
↓
Automation Services
↓
Knowledge Services
↓
Business Rules
↓
Infrastructure

## S.3 Componentes de ICO
ICO
├── Context Engine
├── Knowledge Engine
├── Prompt Engine
├── Automation Engine
├── Decision Support
├── Classification
├── Prediction
├── Summarization
├── Document Intelligence
├── Communication Intelligence
└── Learning Engine

## S.4 Principio Fundamental
ICO nunca toma decisiones clínicas.
ICO propone.
Resume.
Relaciona.
Prioriza.
Organiza.
Explica.
El profesional conserva la responsabilidad final.

## S.5 Context Engine
Responsable de construir el contexto necesario para cada interacción.
Integra información de:
Paciente.
Consulta.
Agenda.
Tratamientos.
Historial.
CRM.
Documentos.
Permisos.
Organización.
Nunca expone información fuera del contexto autorizado.

## S.6 Prompt Engine
Todo modelo de lenguaje recibe instrucciones mediante plantillas oficiales.
Los prompts son:
Versionados.
Auditables.
Reutilizables.
Probados.
Nunca se construyen dinámicamente sin validación.
Toda modificación genera una nueva versión.

## S.7 Knowledge Engine
Centraliza las fuentes de conocimiento utilizadas por ICO.
Incluye:
Guías clínicas.
Protocolos internos.
Catálogos.
Documentación del sistema.
Normatividad.
Manuales.
Base documental institucional.
El motor de conocimiento nunca modifica las fuentes originales.

## S.8 Recuperación de Conocimiento
Antes de consultar un modelo de lenguaje:
Identificar intención.
Localizar contexto.
Filtrar información relevante.
Construir contexto.
Validar permisos.
Invocar modelo.
Reducir el contexto innecesario tiene prioridad sobre aumentar el volumen de información.

## S.9 Automatización
ICO automatiza:
Recordatorios.
Seguimientos.
Clasificación documental.
Generación de borradores.
Resúmenes.
Asignaciones.
Alertas.
Nunca automatiza decisiones clínicas sin validación humana.

## S.10 Clasificación Inteligente
ICO podrá clasificar:
Documentos.
Mensajes.
Correos.
Imágenes.
Radiografías.
Solicitudes.
Incidencias.
La clasificación siempre podrá ser revisada por un usuario autorizado.

## S.11 Resúmenes
ICO podrá generar:
Resumen clínico.
Resumen administrativo.
Resumen financiero.
Resumen de seguimiento.
Resumen documental.
Todo resumen deberá indicar que fue generado mediante asistencia inteligente.

## S.12 Asistencia
ICO podrá asistir en:
Redacción.
Búsqueda.
Explicación.
Navegación.
Documentación.
Capacitación.
Nunca ocultará el origen de la información presentada.

## S.13 Predicción
ICO podrá identificar:
Pacientes con riesgo de abandono.
Huecos en agenda.
Retrasos.
Pendientes.
Sobrecarga operativa.
Tendencias.
Las predicciones son recomendaciones.
Nunca instrucciones obligatorias.

## S.14 Agentes
Cada agente posee:
Objetivo.
Contexto.
Permisos.
Herramientas.
Límites.
Memoria temporal.
Auditoría.
Versionado.

## S.15 Memoria
ICO distingue:
Memoria de sesión.
Memoria operativa.
Memoria documental.
Memoria de configuración.
La memoria clínica oficial permanece en el expediente.
Nunca en el modelo de IA.

## S.16 Observabilidad
Toda interacción registra:
Usuario.
Modelo utilizado.
Versión del prompt.
Contexto empleado.
Tiempo de respuesta.
Resultado.
Costo estimado.
Nunca registrar información innecesaria fuera de los controles de privacidad establecidos.

## S.17 Supervisión
Toda capacidad inteligente debe permitir:
Aceptar.
Modificar.
Rechazar.
Solicitar nueva propuesta.
El profesional mantiene el control.

## S.18 Seguridad
ICO deberá:
Validar permisos.
Proteger contexto.
Evitar filtraciones.
Controlar acceso a modelos.
Respetar clasificación documental.

Toda interacción es auditable.

## S.19 Integración
ICO consume información mediante contratos oficiales.
Nunca accede directamente a:
DAT.
JSON.
Frontend.
Base documental.
Toda interacción ocurre mediante servicios de aplicación.

## S.20 KPIs
Tiempo ahorrado.
Automatizaciones ejecutadas.
Resúmenes aceptados.
Correcciones realizadas.
Predicciones útiles.
Uso por módulo.
Tiempo promedio de respuesta.
Satisfacción del usuario.
Estos indicadores permiten medir el impacto real de ICO.

## S.21 Evolución

ICO deberá permitir incorporar nuevos modelos, proveedores y agentes sin modificar el dominio del negocio.

La inteligencia es reemplazable.
La arquitectura permanece.

## S.22 Definition of Done
La arquitectura ICO se considera completa cuando:
✓ Toda capacidad inteligente tiene un propósito definido.
✓ Los prompts están versionados.
✓ Existe supervisión humana.
✓ La memoria está delimitada.
✓ La auditoría es completa.
✓ El contexto es controlado.
✓ Los agentes operan mediante contratos.
✓ El dominio permanece independiente del proveedor de IA.
✓ Toda automatización puede deshabilitarse sin afectar el funcionamiento del sistema.

# =============================================================================
# FASE T
# SECURITY, QUALITY & OPERATIONAL EXCELLENCE (SQOE)
# =============================================================================

## T.0 Objetivo
Este capítulo establece el modelo oficial de excelencia operacional de OSPulso.

Toda funcionalidad deberá cumplir criterios mínimos de:
• Seguridad
• Calidad
• Rendimiento
• Disponibilidad
• Recuperación
• Observabilidad
• Resiliencia
• Continuidad

La excelencia operacional forma parte del producto.
No constituye una etapa posterior.

## T.1 Filosofía
Todo sistema falla.
La diferencia radica en cómo responde.
OSPulso deberá:
• Detectar.
• Contener.
• Recuperar.
• Aprender.
• Mejorar.

Toda falla constituye una oportunidad de mejora del producto.

## T.2 Pilares
Seguridad
↓
Calidad
↓
Disponibilidad
↓
Resiliencia
↓
Observabilidad
↓
Recuperación
↓
Mejora Continua

## T.3 Security by Design
Toda funcionalidad incorpora seguridad desde su diseño.
Nunca como una fase posterior.

Toda operación valida:
• Autenticación.
• Autorización.
• Contexto.
• Permisos.
• Auditoría.
• Integridad.

Toda decisión crítica ocurre en el servidor.

## T.4 Modelo Zero Trust
Nunca confiar automáticamente en:
• Cliente.
• Red.
• Usuario.
• Sesión.
• Dispositivo.
• Integración.

Toda solicitud debe validarse explícitamente.

## T.5 Gestión de Identidad
Todo usuario posee:
• Identidad.
• Rol.
• Permisos.
• Sesión.
• Contexto.
• Historial.

La identidad nunca se comparte entre usuarios.

Toda sesión es individual.

## T.6 Gestión de Sesiones
Las sesiones deberán:
• Expirar automáticamente.
• Invalidarse al cerrar sesión.
• Rotar identificadores.
• Detectar inactividad.
• Permitir cierre remoto.
• Registrar actividad relevante.

## T.7 Protección de Datos
Toda información sensible deberá:
• Clasificarse.
• Protegerse.
• Auditarse.
• Respaldarse.
• Eliminarse únicamente conforme a la política oficial de retención.

Los datos nunca se exponen innecesariamente.

## T.8 Calidad
La calidad se evalúa mediante:
• Correctitud.
• Consistencia.
• Confiabilidad.
• Usabilidad.
• Mantenibilidad.
• Seguridad.
• Escalabilidad.
• Observabilidad.

## T.9 Estrategia de Pruebas
Unitarias
↓
Integración
↓
Aplicación
↓
Flujos Clínicos
↓
Aceptación
↓
Producción Controlada

Toda funcionalidad posee al menos una estrategia de validación.

## T.10 Validación Clínica
Toda funcionalidad clínica deberá validar:
• Integridad del expediente.
• Reglas del dominio.
• Trazabilidad.
• Estados.
• Auditoría.
• Consistencia documental.

No se libera funcionalidad clínica sin validación específica.

## T.11 Rendimiento
Objetivos:
• Tiempo de respuesta.
• Consumo de memoria.
• Concurrencia.
• Escalabilidad.
• Latencia.

Toda funcionalidad se valida contra objetivos de rendimiento antes de producción.

## T.12 Disponibilidad
Objetivos:
• 99.9% anual.
• Recuperación en < 5 minutos.
• Métricas de servicio.

Toda funcionalidad es desplegada con estrategia de disponibilidad.

## T.13 Resiliencia
Todo componente debe:
• Fallar de forma controlada.
• Limpiar estado residual.
• Notificar falla a observabilidad.
• Permitir recuperación manual.
• Mantener integridad del dominio.

## T.14 Continuidad Operativa
Toda organización deberá disponer de:
• Respaldos.
• Plan de recuperación.
• Procedimientos de contingencia.
• Documentación.
• Responsables.

La continuidad forma parte de la operación diaria.

## T.15 Observabilidad
Registrar:
• Logs.
• Métricas.
• Eventos.
• Alertas.
• Trazas.
• Indicadores.

Toda información debe permitir comprender el estado real del sistema.

## T.16 Alertamiento
Toda alerta posee:
• Prioridad.
• Origen.
• Descripción.
• Responsable.
• Tiempo de atención.
• Estado.
• Historial.

## T.17 Recuperación

Toda estrategia contempla:
• Restauración.
• Rollback.
• Reconstrucción.
• Validación.
• Auditoría.
• Pruebas periódicas.

No basta con generar respaldos.
Debe demostrarse que pueden restaurarse.

## T.18 Gestión de Incidentes
Todo incidente registra:
• Fecha.
• Origen.
• Impacto.
• Usuarios afectados.
• Causa raíz.
• Acciones correctivas.
• Acciones preventivas.
• Estado.

## T.19 Mejora Continua
Toda incidencia relevante genera:
• Análisis.
• Lecciones aprendidas.
• ADR cuando aplique.
• Actualización documental.
• Revisión arquitectónica.

El producto evoluciona continuamente.

## T.20 KPIs
• Disponibilidad.
• Tiempo medio de respuesta.
• Tiempo medio de recuperación.
• Incidentes abiertos.
• Incidentes cerrados.

• Cobertura de pruebas.
• Cobertura documental.
• Cobertura de auditoría.
• Satisfacción del usuario.
• Tiempo de resolución.

## T.21 Checklist Operacional
✓ Seguridad validada.
✓ QA aprobado.
✓ Auditoría activa.
✓ Logs disponibles.
✓ Monitoreo habilitado.
✓ Respaldos verificados.
✓ Recuperación probada.
✓ Documentación actualizada.
✓ KPIs definidos.
✓ Riesgos revisados.

## T.22 Definition of Done
La excelencia operacional se considera alcanzada cuando:
✓ El sistema es seguro.
✓ El sistema es observable.
✓ El sistema puede recuperarse.
✓ Las pruebas son suficientes.
✓ Los riesgos son conocidos.
✓ La documentación está vigente.
✓ La calidad es medible.
✓ La plataforma puede evolucionar con confianza.

# =============================================================================
# FASE U
# PRODUCT CONSTITUTION & ECOSYSTEM EVOLUTION (PCEE)
# =============================================================================

## U.0 Objetivo

Este capítulo constituye el cierre oficial del OMS.

Define la estrategia de evolución permanente del ecosistema OSPulso.

El producto deberá poder evolucionar durante décadas sin perder coherencia arquitectónica.

La evolución del producto deberá respetar siempre:

• Arquitectura
• Dominio
• Ingeniería
• UX
• UI
• Seguridad
• ICO
• Gobierno

Todo cambio futuro deberá mantener la identidad del ecosistema.

## U.1 Filosofía

OSPulso no es un software.
Es un ecosistema.
El software cambia.
La arquitectura evoluciona.
La tecnología se reemplaza.
La visión permanece.
Toda decisión futura deberá fortalecer el ecosistema.
Nunca fragmentarlo.

## U.2 Misión Permanente

Reducir la carga operativa del profesional de la salud.
Incrementar la calidad de la atención.
Automatizar procesos repetitivos.
Mejorar la trazabilidad clínica.
Facilitar la toma de decisiones.
Construir una plataforma sostenible para el sector salud.

## U.3 Visión

Convertirse en el Sistema Operativo Clínico de referencia para Latinoamérica.
Integrar personas, procesos, inteligencia y tecnología en un único ecosistema.
Mantener una arquitectura abierta, modular y preparada para evolucionar.

## U.4 Valores

Paciente primero.
Simplicidad.
Transparencia.
Trazabilidad.
Innovación responsable.
Seguridad.
Calidad.
Respeto por el profesional.
Mejora continua.
Conocimiento compartido.

## U.5 Ciclo de Vida
Idea
↓
Análisis
↓
Arquitectura
↓
Diseño
↓
Implementación
↓
QA
↓
Producción
↓
Observación
↓
Mejora
↓
Nueva Versión

## U.6 Modelo de Versionado

Semantic Versioning
MAJOR
MINOR
PATCH

Toda versión documenta:
Objetivos.
Cambios.
Migraciones.
Compatibilidad.
ADR relacionados.
Breaking Changes.

## U.7 Gestión del Conocimiento

Todo conocimiento deberá documentarse.
No depender de personas.
Todo módulo incluye:
Arquitectura.
Diagramas.
Eventos.
Casos de uso.
Dependencias.
Configuración.
Ejemplos.
Historial.
El conocimiento pertenece al producto.
No al desarrollador.

## U.8 Documentación Oficial

El ecosistema mantiene:
OMS
Brand Book
Developer Guide
API Specification
Deployment Guide
User Manual
Administrator Manual
Clinical Manual
Training Manual
Release Notes
ADR Repository
Knowledge Base

## U.9 Formación

Toda incorporación al proyecto sigue un plan de capacitación.
Arquitectura.
Dominio.
UX.
Ingeniería.
Normatividad.
ICO.
Buenas prácticas.
El objetivo es reducir la dependencia del conocimiento informal.

## U.10 Roadmap
V1
    ↓
V1.x
    ↓
V2
    ↓
V3
    ↓
Enterprise
    ↓
Government
    ↓
Hospital
    ↓
International

## U.11 Compatibilidad

Toda nueva versión deberá preservar la compatibilidad cuando sea técnicamente posible.
Cuando no sea posible:
Documentar.
Justificar.
Migrar.
Versionar.
Nunca romper compatibilidad sin estrategia.

## U.12 Deprecación

Toda funcionalidad obsoleta sigue el proceso:
Anuncio.
Documentación.
Periodo de transición.
Migración.
Retiro.
Nunca eliminar funcionalidades inesperadamente.

## U.13 Extensiones

OSPulso podrá incorporar:
Plugins.
Conectores.
Adaptadores.
Integraciones.
Agentes ICO.
Cada extensión deberá respetar los contratos oficiales del ecosistema.

## U.14 Comunidad
El crecimiento del producto contempla:
Partners.
Consultores.
Desarrolladores.
Integradores.
Instituciones.
Universidades.
Comunidad técnica.
Todos trabajan sobre una arquitectura común.

## U.15 Innovación

Toda innovación deberá responder:
¿Qué problema resuelve?
¿Qué principio arquitectónico fortalece?
¿Qué impacto produce?
¿Cómo se medirá su éxito?
La innovación nunca sustituye la disciplina arquitectónica.

## U.16 Gobernanza del Conocimiento

Todo documento posee:
Propietario.
Versión.
Fecha.
Historial.
Estado.
Referencias.
Los documentos forman parte del producto.

## U.17 Índice Maestro del OMS
A  OMS Architecture
B  Brand Strategy
C  Visual Identity
D  Product Philosophy
E  Platform Architecture
F  Domain Model
G  Business Rules
H  Compliance
I  UX Architecture
J  UI System
K  Visual Foundations
L  Frontend Experience
M  Application Runtime
N  Enterprise Modular Monolith
O  Engineering Standards
P  Implementation Blueprint
Q  Architecture Governance
R  Platform Infrastructure
S  Intelligent Clinical Operations
T  Security & Operational Excellence
U  Product Constitution

## U.18 Roadmap Estratégico

Versión 1
Clínicas privadas.

Versión 2
Business Capabilities.
Multiempresa.

Versión 3
Hospitales.

Versión 4
Gobierno.

Versión 5
Federación Nacional.

Versión 6
Internacionalización.

Versión 7
Ecosistema Global.

## U.19 Definition of Success

OSPulso será exitoso cuando:

La arquitectura sobreviva al cambio tecnológico.

Los nuevos desarrolladores comprendan el ecosistema rápidamente.

Las decisiones sean trazables.

La documentación permanezca vigente.

La innovación ocurra sin romper el núcleo.

La plataforma evolucione sin perder identidad.

## U.20 Manifiesto OSPulso

Creemos que la tecnología debe reducir la complejidad.

Creemos que la información clínica pertenece al paciente.

Creemos que la inteligencia debe asistir, nunca reemplazar.

Creemos que la arquitectura es un compromiso con el futuro.

Creemos que la calidad se diseña.

Creemos que la seguridad es inseparable del software.

Creemos que documentar es construir.

Creemos que un ecosistema sólido puede transformar la atención médica.

Este documento constituye la referencia oficial para la evolución de OSPulso.