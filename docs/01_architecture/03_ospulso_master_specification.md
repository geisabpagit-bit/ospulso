# OSPulso Master Specification v1.0 & System Constitution

**Versión**: OsPulso Diamond Edition v4.5.0  
**Ámbito**: Especificación Técnica y Arquitectónica Global del Sistema  
**Estado**: Fuente Canónica Principal de Verdad (Actualizado 2026)

---

## 📌 1. Constitución del Producto

Este documento establece los principios normativos y la especificación técnica maestra para el ecosistema **OSPulso / SDM 2.0**.

Toda evolución futura de la plataforma deberá preservar:
1. **Identidad de Dominio**: El software sirve al acto médico y a la gestión clínica eficiente.
2. **Coherencia Arquitectónica**: Respeto estricto a las bases de datos relacionales normalizadas 3NF por tenant y aislamiento sanitario por CLUES.
3. **Calidad y Resiliencia**: Cero tolerancia a errores 500 no capturados y observabilidad total.

---

## 🏛️ 2. Especificación Técnica por Capas

### A. Capa de Datos (Flat-File Engine 3NF)
- **Persistencia**: Archivos `.dat` bajo `dat/catalogos_CLUE/<CLUES>/` leídos y escritos con capas explícitas `:raw :encoding(UTF-8)` y bloqueo concurrente `flock($fh, LOCK_EX)`.
- **Estructura 3NF**: Separación estricta en Departamentos, Categorías, Items, Precios y Tipos de Tarifa.
- **Normalización CLUE**:
  - `ID_DEP 4` = `IMAGENOLOGIA` (Departamento General).
  - `ID_CAT 16` = `RAYOS X` (Categoría perteneciente a Imagenología).
  - Secuencia canónica de SKUs: `LAB-`, `US-`, `RX-`, `CONS-0001` a `CONS-0832`.

### B. Capa de Servicios y Performance (Server-Side DataTables)
- **Carga Diferida**: Implementación de `serverSide: true` y `deferRender: true` en [views/manage_catalogo_universal.pl](file:///c:/xampp/htdocs/ospulso/views/manage_catalogo_universal.pl) vía [api/crud_catalogo_universal_api.pl](file:///c:/xampp/htdocs/ospulso/api/crud_catalogo_universal_api.pl).
- **Límite de Paginación**: Límite estándar predeterminado de **10 registros por página** (`pageLength: 10`).

### C. Capa de Cobranza y Motor Multi-Tarifa (`views/generar_recibo.pl`)
- **Gestión Multi-Tarifa**: Soporte dinámico para múltiples esquemas de precio (`ESTÁNDAR`, `URGENCIAS`, `DOMINGOS Y FESTIVOS`, `PAQUETE_TODO_INCLUIDO`).
- **Renderizado Reactivo**: Selectores `<select>` en tabla modal de búsqueda y en el carrito principal (`.cart-item-card`) con recálculo dinámico de precios, subtotal, IVA (16%) y Total a Pagar.
- **Contenedor Adaptable**: Layout de resumen en tarjeta con `flex: 1 1 auto; max-height: 420px; overflow-y: auto;` y alineación simétrica vertical.

### D. Capa de Impresión Controlada (`.no-print`)
- **Sin Auto-Print**: Eliminación de `onload="window.print()"` y `afterprint` en `imprimir_recibo_caja.pl` y `imprimir_recibo_publico.pl`.
- **Toolbar Superior**: Botones de acción manual `🖨️ Imprimir Recibo` y `← Volver / Cerrar` (`volverPadre()`).
- **Ocultamiento Impreso**: Ocultamiento de la barra en impresión o PDF vía `@media print { .no-print { display: none !important; } }`.

---

## 🛡️ 3. Gobernanza, Seguridad y Normatividad (NOM-004 / NOM-024)

1. **Inmutabilidad y Sello Digital**: Las notas clínicas finalizadas e impresas quedan firmadas digitalmente con fecha, hora e identificador de cédula del médico.
2. **Segregación de Roles (RBAC)**: Enrutamiento seguro y restricción estricta de permisos para Administrador, Médico/Especialista, Recepción y Paciente.
3. **Flujo Contable Canónico**: `folios_recibos_privados.dat` representa el flujo de efectivo real en ventanilla, mientras que `folios_recibos_publicos.dat` representa Cuentas por Cobrar (CXC Estado).

---

## 🚀 4. Definición de Hecho (Definition of Done)

La excelencia del sistema se garantiza cuando:
- [x] La sintaxis de todo script Perl pasa la verificación `perl -c <script.pl>`.
- [x] Toda consulta cumple con el contrato JSON SOAP polimórfico.
- [x] El catálogo respeta la jerarquía 3NF por CLUE y la paginación a 10 registros.
- [x] El módulo financiero cuadra al centavo con drilldown transparente.
- [x] La documentación está al día y sincronizada con el repositorio Git.
