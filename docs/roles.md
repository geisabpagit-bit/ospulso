# Matriz de Gobernanza y Control de Acceso Basado en Roles (RBAC)

## 1. Roles del Sistema

| Rol | Permisos Principales | Vistas Permitidas | Restricciones |
| :--- | :--- | :--- | :--- |
| **Administrador** | Control total de organización, usuarios, catálogos 3NF y finanzas. | 100% de la plataforma | Ninguna |
| **Médico / Especialista** | Consulta SOAP, expediente clínico, notas de evolución, recetas y órdenes de laboratorio/imagen. | Agenda, Expediente, Consultas, Visor Médico | Sin acceso a corte de caja directo ni configuración global |
| **Recepcionista** | Agendamiento, registro de pacientes, cobro en Caja Rápida, emisión de recibos y cortes de caja. | Agenda, Caja Rápida, Pacientes, Impresión Recibos | Sin acceso a notas SOAP clínicas privadas |
| **Paciente** | Portal de paciente para consulta de recetas, citas y estado de cuenta. | Portal Paciente | Acceso exclusivo a sus propios registros |

---

## 2. Segregación de Funciones (UI-RBAC y API-RBAC)

1. **API-RBAC (Backend)**: Toda API Perl (`api/*.pl`) valida la sesión activa (`check_session()`) y verifica `$sd->{role}` antes de procesar cualquier transacción.
2. **UI-RBAC (Frontend)**: Los componentes de acción sensible se renderizan condicionalmente ocultando botones o secciones según el rol autenticado.
