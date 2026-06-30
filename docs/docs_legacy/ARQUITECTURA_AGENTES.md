# MANUAL DE ARQUITECTURA DE AGENTES (v3.7.4) - SDM

## 1. Mapa de Agentes Especializados (v3.7.4)

### 1.1 Agente de Gobernanza (Business Lock Agent)
- **Función**: Validación binaria del estado del negocio. Impide la carga de cualquier módulo si el negocio está inactivo.

### 1.2 Agente de Reportes (Excellence Reporting Agent)
- **Función**: Orquestación de datos de `negocios.dat` y `estado_cuenta.dat` para generar salidas impresas branded. Asegura que el detalle de movimientos nunca sea omitido por reglas de responsividad.

### 1.3 Agente de Seguridad (API Guardian)
- **Función**: Interceptor de peticiones que garantiza que cada llamado a los datos financieros cuente con un token de sesión válido.

## 2. Estándares de Comunicación
- **Data Flow**: Los agentes operan sobre archivos `.dat` con bloqueo de escritura preventivo.
- **UI Bridge**: Los componentes de interfaz se comunican con los agentes vía JSON asíncrono.

---
**GEISABPA - Estándar de Agentes v3.7.4 (PATH TO EXCELLENCE)**
