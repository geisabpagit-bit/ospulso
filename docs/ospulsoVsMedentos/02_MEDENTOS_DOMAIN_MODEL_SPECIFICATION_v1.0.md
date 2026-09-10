# 02_MEDENTOS_DOMAIN_MODEL_SPECIFICATION_v1.0

## 1. Propósito y Alcance
Define el modelo de dominio de MedentOS y su semántica, entidades, agregados, objetos de valor, contextos y eventos. Este documento depende de `01_MEDENTOS_CORE_ARCHITECTURE_v1.0_APPROVED.md`.

## 2. Bounded Contexts
Los contextos se identifican como `BC-xxx` y mantienen límites semánticos explícitos.

## 3. Domain Entities
Las entidades se identifican como `DM-xxx`, incluyendo Tenant, Organization, BusinessProfile, OperationalProfile, RegulatoryProfile, HealthcareUnit, HealthcareProvider, User, Patient, Appointment, ClinicalEncounter, ClinicalRecord, Diagnosis, Invoice, Payment, TenantSubscription, FeatureCatalog, TenantFeature, Permission y AuditLog.

## 4. Aggregate Roots
Los Aggregate Roots se identifican como `AR-xxx` y tienen un único Engine propietario conforme al Core Architecture.

## 5. Value Objects
Los Value Objects se identifican y catalogan de forma explícita, incluyendo los utilizados por perfiles organizacionales, agenda, clínica, facturación, permisos e interoperabilidad.

## 6. Domain Events
Los eventos se identifican como `DE-xxx`, con origen, consumidores y naturaleza definidos. Incluyen eventos de Tenant, organización, identidad, clínica, facturación, features, interoperabilidad y auditoría.

## 7. Use Cases
Los casos de uso se identifican como `UC-xxx` y representan comportamientos del dominio sin introducir detalles de infraestructura.

## 8. Workflows
Los workflows se identifican como `WF-xxx` y describen secuencias de negocio.

## 9. Features
Las capacidades funcionales se identifican como `FE-xxx` y se relacionan con `FeatureCatalog` y `TenantFeature`.

## 10. Framework Alignment
El modelo mantiene trazabilidad 1:1 con los Engines (`EN-xxx`) definidos en el documento 01 y no redefine responsabilidades de infraestructura.

## 11. Document Status
* **Document:** Domain Model Specification
* **Version:** 1.0
* **Status:** APPROVED
* **Baseline:** FROZEN
* **Next:** `03_MEDENTOS_LOGICAL_ARCHITECTURE_v1.0.md`
