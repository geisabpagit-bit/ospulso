# 03_MEDENTOS_LOGICAL_ARCHITECTURE_v1.0

## Document Status
| Property | Value |
|---|---|
| Document | MEDENTOS LOGICAL ARCHITECTURE |
| Version | 1.0 |
| Status | DRAFT — PHASE 3 |
| Depends On | `01_MEDENTOS_CORE_ARCHITECTURE_v1.0_APPROVED.md` |
| Depends On | `02_MEDENTOS_DOMAIN_MODEL_SPECIFICATION_v1.0.md` |
| Architecture Level | Logical Architecture |
| Scope | MedentOS Platform Core |

## 1. Propósito y Alcance
Define la arquitectura lógica de implementación de MedentOS, traduciendo las restricciones del Core Architecture y el Domain Model a módulos, contratos, comunicación, persistencia, seguridad, auditoría, provisioning e interoperabilidad.

No redefine entidades, reglas clínicas ni lenguaje ubicuo. No define todavía código fuente ni infraestructura física.

## 2. Principios de Implementación Lógica
- Separación estricta de responsabilidades.
- Dependencias unidireccionales.
- Separación Domain / Infrastructure.
- Tenant Context obligatorio.
- CQRS para Commands y Queries.
- Contratos explícitos y versionados.
- Persistencia transaccional en DAT.
- JSON como transporte/configuración/proyección, no como fuente de verdad.

## 3. Mapa de Módulos Lógicos
| ID | Módulo lógico | Engine | Responsabilidad |
|---|---|---|---|
| LM-001 | Tenant Module | EN-001 | Contexto y aislamiento Tenant |
| LM-002 | Organization Module | EN-002 | Organización y unidades |
| LM-003 | Identity Module | EN-003 | Identidad, autenticación y RBAC |
| LM-004 | Provisioning Module | EN-004 | Alta y preparación de Tenant |
| LM-005 | Feature Module | EN-005 | Features y capacidades |
| LM-006 | Billing Module | EN-006 | Suscripción, facturación y pagos |
| LM-007 | Clinical Module | EN-007 | Operación clínica |
| LM-008 | Interoperability Module | EN-008 | Estándares y conectores |
| LM-009 | Audit Module | EN-009 | Auditoría |

## 4. Estructura Lógica General
Presentation/API → Application/Engine → Domain Contracts → Persistence/Infrastructure.

Los módulos se mantienen aislados mediante contratos.

## 5. Correspondencia Engines ↔ Módulos
Cada `EN-xxx` posee un único `LM-xxx` propietario y se vincula a las entidades `DM-xxx` establecidas por el documento 02.

## 6. Correspondencia Domain Model ↔ Persistencia
Aggregate Root → Repository Contract → Persistence Adapter → DAT.

Las entidades no acceden directamente al almacenamiento.

## 7. Arquitectura DAT / JSON / Proyecciones
DAT es la fuente transaccional. JSON sirve como transporte, payload, respuesta API, configuración no transaccional o proyección. Los Read Models son derivados de eventos y nunca sustituyen la fuente transaccional.

## 8. Contratos Internos
Command Contract, Query Contract, Event Contract, Repository Contract, Authorization Contract, Tenant Context Contract y Feature Resolution Contract.

## 9. CQRS Aplicado
Query: Request → Auth → Tenant → Authorization → Feature → Query Handler → Read Model → Response.

Command: Request → Auth → Tenant → Authorization → Feature → Command Handler → Aggregate → Validation → Transaction → DAT → Domain Event.

## 10. Event Bus Interno
Los Domain Events son inmutables, versionados, identificables y auditables. El Event Bus permite consumidores independientes.

## 11. API Layer
La API es la frontera de entrada. Nunca accede directamente a DAT.

## 12. Seguridad Lógica
La autorización combina Tenant + User + Role + Permission + Feature + Resource. La regla por defecto es DENY.

## 13. Feature Resolution Runtime
Tenant → TenantSubscription → TenantFeature → FeatureCatalog → Permission → Runtime Capability.

## 14. Interoperability Connectors
El Interoperability Module utiliza conectores desacoplados para FHIR, HL7, DICOM, SIRES y futuras integraciones.

## 15. Audit Trail Architecture
Engine → Domain Event → Audit Handler → AuditLog → Append-Only DAT.

## 16. Bootstrap / Provisioning Pipeline
Registration → Validation → Commercial Activation → Tenant Creation → Provisioning → Organization Setup → Identity Setup → Feature Assignment → Initial Configuration → Audit → Tenant Ready.

## 17. Logical Traceability Matrix
La trazabilidad inicial vincula LM-xxx ↔ EN-xxx ↔ DM-xxx y servirá como base para API, Workflows, Features y persistencia.

## 18. Reglas de Dependencia
- `LOGIC-001`: Un módulo no accede al almacenamiento de otro.
- `LOGIC-002`: Aggregate Roots no acceden directamente a DAT.
- `LOGIC-003`: API no accede directamente a DAT.
- `LOGIC-004`: Comunicación mediante contratos explícitos.
- `LOGIC-005`: Mutaciones generan Domain Events cuando corresponda.
- `LOGIC-006`: Toda operación Tenant-scoped conserva Tenant Context.
- `LOGIC-007`: Features se evalúan dinámicamente.
- `LOGIC-008`: Connectors externos desacoplados.
- `LOGIC-009`: Audit no modifica transacciones originales.
- `LOGIC-010`: Proyecciones no son fuente transaccional.

## 19. Manejo de Errores
Diferenciar Authentication, Authorization, Tenant, Feature, Validation, Domain, Persistence, Integration e Infrastructure Errors. Los errores internos no se exponen directamente. No se permiten excepciones no controladas como respuesta 500.

## 20. Idempotencia
Commands y eventos críticos utilizan Request ID, Correlation ID, Command ID y Event ID cuando corresponda, especialmente para pagos, provisioning e interoperabilidad.

## 21. Observabilidad
Operaciones significativas deben poder rastrearse mediante Tenant ID, Actor ID, Correlation ID, Request ID, Command/Event ID y Timestamp.

## 22. Escalabilidad
Los módulos deben poder evolucionar desde ejecución local hacia workers distribuidos sin alterar los contratos lógicos.

## 23. Preparación para SIRES
Un Tenant privado puede operar sin interoperabilidad regulatoria; un Tenant público/regulado puede habilitar RegulatoryProfile e Interoperability/SIRES Connector mediante configuración y capacidades.

## 24. Preparación para IA
La IA se integrará como agente/adaptador sobre contratos y eventos autorizados. No será fuente autónoma de verdad clínica.

## 25. Lifecycle de Módulos
DEFINED → IMPLEMENTED → TESTED → ENABLED → MONITORED → DEPRECATED.

## 26. Checklist de Validación
Verificar módulos, dependencias, Aggregate Roots, persistencia DAT, seguridad Tenant/RBAC/Feature, eventos, idempotencia, conectores, errores, observabilidad y recuperación.

## 27. Relación con Documentos Anteriores
01 Core Architecture define cómo debe comportarse arquitectónicamente la plataforma. 02 Domain Model define qué significa el dominio. 03 Logical Architecture define cómo se organizarán lógicamente los componentes para implementar ambos.

## 28. Regla de Precedencia
Core Architecture > Domain Model > Logical Architecture > Physical Architecture > Implementation.

## 29. Próximo Documento
`04_MEDENTOS_PHYSICAL_ARCHITECTURE`

## 30. Document Status
* **Document:** 03_MEDENTOS_LOGICAL_ARCHITECTURE
* **Version:** 1.0
* **Status:** DRAFT
* **Phase:** 3
* **Architecture Baseline:** PENDING REVIEW
