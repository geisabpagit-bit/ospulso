# 01_MEDENTOS_CORE_ARCHITECTURE_v1.0_APPROVED

## Índice
1. Vision Statement
2. Propósito y Alcance
3. Foundation Rules & Global Constraints
4. Capas del Sistema e Infraestructura Técnica
5. Especificación Formal de Motores Principales (Core Engines)
6. Reglas de Comunicación y Contratos entre Componentes
7. Roadmap Técnico y Evolutivo

---

## 1. Vision Statement
MedentOS Platform es una plataforma SaaS multitenant para la administración clínica, interoperabilidad, inteligencia artificial y gestión empresarial del sector salud. Está diseñada para escalar de forma elástica desde un consultorio individual hasta una red hospitalaria nacional mediante un conjunto de motores desacoplados, configurables y auditables basados en eventos.

## 2. Propósito y Alcance
Este documento establece de manera exclusiva la arquitectura base y el modelo técnico de infraestructura de MedentOS Platform Core v2.0. Define los límites lógicos, restricciones de ingeniería, capacidades de los motores de software y las directrices de acoplamiento.

> ### 🛑 Restricción de Contenido (Axioma Mandante)
> Este documento nunca describe entidades de negocio, atributos clínicos, catálogos médicos, ni semántica del lenguaje ubicuo. Su dominio es puramente computacional e infraestructural. Cualquier mapeo de datos debe referenciarse unívocamente al documento `02_MEDENTOS_DOMAIN_MODEL_SPECIFICATION_v1.0.md`.

## 3. Foundation Rules & Global Constraints

* **Const-001 — Aislamiento de Motores:** Ningún motor principal (`EN-xxx`) puede depender, invocar directamente por RPC, o acoplarse en tiempo de compilación a otro motor. La interacción permitida se realiza única y exclusivamente a través del despacho de Eventos de Dominio (`DE-xxx`) administrados por el bus de mensajería asíncrono.
* **Const-002 — Fuente de Verdad de Persistencia:** El origen oficial e inmutable de datos transaccionales del Core está dictado estrictamente por la capa de acceso a datos de bajo nivel (`DAT`). Queda prohibido el uso de JSON o cachés locales volátiles como fuentes de verdad transaccional.
* **Const-003 — Desacoplamiento de Rutas Frontend:** Queda prohibido el hardcoding de URLs, paths de enrutamiento o políticas de acceso estáticas en los componentes de la interfaz de usuario. Los endpoints operativos deben consumirse dinámicamente mediante el contrato expuesto por el Feature Engine (`EN-005`).
* **Const-004 — Denegación Implícita / Zero-Trust:** Todo intento de interacción con las APIs del sistema carente de un token criptográfico de autorización explícito y un emparejamiento de permisos válido será rechazado por defecto a nivel de infraestructura perimetral.

## 4. Capas del Sistema e Infraestructura Técnica

1. **Capa de API y Presentación:** Expone contratos HTTPS/REST y WebSockets.
2. **Capa Lógica (Core Engines Layer):** Aloja los componentes computacionales (`EN-xxx`).
3. **Capa de Contratos y Mensajería:** Bus de datos que procesa eventos inmutables `DE-xxx`.
4. **Capa de Datos de Red (`DAT`):** Drivers de persistencia relacional y almacenamiento plano de alta velocidad.

## 5. Especificación Formal de Motores Principales

### EN-001 Tenant Engine
Orquesta aislamiento lógico, fronteras criptográficas y ciclo de vida de espacios de clientes. Entidad: `DM-001 Tenant`.

### EN-002 Organization Engine
Administra topología corporativa, sucursales, unidades operativas y perfiles institucionales. Entidades: `DM-002`, `DM-003`, `DM-004`, `DM-006`.

### EN-003 Identity & RBAC Engine
Gobierna autenticación, firmas criptográficas, sesiones y RBAC. Entidades: `DM-011`, `DM-022`.

### EN-004 Provisioning Engine
Ejecuta la inicialización transaccional de nuevos espacios de cliente. Entidad: `DM-001`.

### EN-005 Feature Engine
Resuelve capacidades funcionales y addons asociados a un plan comercial. Entidades: `DM-020`, `DM-021`.

### EN-006 Billing Engine
Administra suscripciones, pagos, periodos de gracia y bloqueo por impago. Entidades: `DM-017`, `DM-018`, `DM-019`.

### EN-007 Clinical Engine
Procesa transacciones clínicas de alta concurrencia, agendas, sesiones de trabajo y estados históricos. Entidades: `DM-010`–`DM-016`.

### EN-008 Interoperability Engine
Traduce y serializa payloads hacia/desde estándares abiertos: HL7, FHIR, DICOM y pasarelas regulatorias. Entidades: `DM-005`, `DM-016`.

Cada protocolo se implementará mediante Connectors desacoplados.

### EN-009 Audit Engine
Captura trazas de auditoría de forma asíncrona, inmutable y append-only. Entidad: `DM-023`.

## 6. Reglas de Comunicación y Contratos

1. Un componente de API puede realizar peticiones síncronas de lectura (Queries) a interfaces tipadas.
2. Las acciones de mutación (Commands) se procesan mediante colas internas controladas.
3. Los motores no se invocan directamente para mutaciones; los eventos de dominio (`DE-xxx`) propagan cambios de forma asíncrona.

## 7. Roadmap Técnico

* **Fase 1:** Consolidación del Core Multitenant.
* **Fase 2:** Interoperabilidad y Flexibilidad Comercial.
* **Fase 3:** Escalabilidad y Automatización Inteligente.

---
**Document Status**
* **Document:** Architecture Baseline
* **Version:** 1.0
* **Status:** APPROVED
* **Owner:** MedentOS Architecture Review Board
* **Next Document Link:** `02_MEDENTOS_DOMAIN_MODEL_SPECIFICATION_v1.0.md`
