# Compendio de Reglas de Negocio del Sistema OSPulso / SDM

## 1. Arquitectura SOAP Polimórfica y Multi-Especialidad
1. **Contrato Canónico JSON SOAP**: Toda consulta clínica privada debe serializarse bajo las llaves canónicas SOAP (`subjective`, `objective`, `assessment`, `plan`). Los datos dinámicos de especialidad residen obligatoriamente en `soap.objective.especialidad_data`.
2. **Core Pipeline Único**: Registro, Agenda, Expediente, Firma y Cierre con Caja forman un flujo 100% único. Se prohíbe duplicar vistas completas por especialidad (ej. no crear `consulta_pediatria.pl`).
3. **Subformularios Desacoplados (Plugin Slot)**: Los componentes por especialidad residen en `views/partials/consultas/` o `views/partials/especialidades/`. De no contar con subformulario, se renderiza el fallback seguro.

---

## 2. Catálogo Universal 3NF y Estandarización por Tenant (CLUE)
1. **Jerarquía Rigurosa**: Los catálogos por organización deben mantener la relación `Departamento (ID_DEP) -> Categoría (ID_CAT) -> Item (ID_ITEM)`.
2. **Caso Específico Imagenología / Rayos X**:
   - `ID_DEP 4`: Departamento General **IMAGENOLOGIA**.
   - `ID_CAT 16`: Categoría **RAYOS X** (perteneciente a Imagenología).
3. **Normalización y Prefijos SKU**:
   - Los prefijos SKU deben coincidir con su categoría correspondiente (`LAB-` para Análisis Clínicos, `US-` para Ecografía/Ultrasonido, `RX-` para Rayos X, `CONS-` para Consultas Médicas).
   - Secuencia canónica de consultas: `CONS-0001` a `CONS-0832` sin saltos ni duplicados.

---

## 3. Paginación y Carga Server-Side (DataTables)
1. **Paginación por Defecto**: Todas las tablas administrables DataTables deben inicializarse con un límite por defecto de **10 registros por página** (`pageLength: 10`).
2. **Server-Side AJAX & `deferRender: true`**: En vistas con volúmenes extensos (`views/manage_catalogo_universal.pl`), los datos deben ser procesados en el servidor Perl (`api/crud_catalogo_universal_api.pl`) en lotes pequeños, evitando la inyección directa de miles de filas HTML en la carga inicial DOM.

---

## 4. Caja Rápida, Resumen de Carrito y Soporte Multi-Tarifa
1. **Exclusión de Departamento Consultas**: El modal de búsqueda de conceptos del carrito omite automáticamente los servicios del departamento `CONSULTAS` (`id_dep = 1`) para evitar duplicar el flujo médico de la cabecera.
2. **Multi-Tarifa por Concepto**:
   - Cuando un servicio cuenta con múltiples tarifas comerciales válidas (ej. `ESTÁNDAR`, `URGENCIAS`, `DOMINGOS Y FESTIVOS`), se despliega un selector `<select>` para que el usuario elija la tarifa aplicable.
   - La tarifa seleccionada se puede conmutar en el modal previo y directamente en la tarjeta del carrito (`.cart-item-card`), actualizando precios, subtotal, IVA y Total a Pagar en tiempo real.
3. **Resumen de Carrito UI/UX**:
   - Contenedor flexible adaptable (`flex: 1 1 auto; min-height: 100px; max-height: 420px; overflow-y: auto;`).
   - Alineación al píxel exacto en la columna derecha para precios, subtotales, IVA y botón de emisión.

---

## 5. Protocolo de Impresión Controlada de Recibos
1. **Sin Auto-Print ni Cierre Automático**: Se prohíbe el uso de `onload="window.print()"` o eventos `afterprint` que cierren de forma forzada las ventanas de recibos.
2. **Toolbar `.no-print`**: Todo recibo (privado o público) debe desplegar una barra de acciones visible en pantalla con botones manuales para:
   - `🖨️ Imprimir Recibo` (`window.print()`).
   - `← Volver / Cerrar` (`volverPadre()`).
3. **Protección CSS**: La barra `.no-print` se oculta automáticamente durante la impresión física o generación de archivos PDF.

---

## 6. Integridad Contable y Segregación Financiera
1. **Fuente Canónica de Efectivo**: `dat/folios_recibos_privados.dat` es la única fuente de ingresos cobrados en efectivo en caja. No debe sumarse con `estado_cuenta.dat` para evitar doble contabilidad.
2. **Cuentas por Cobrar (Estado)**: Los recibos públicos subsidiados de `dat/folios_recibos_publicos.dat` corresponden a Cuentas por Cobrar (CXC Estado) y no constituyen dinero físico en la caja del cajero.

---

## 7. Estándares Técnicos de Codificación (Perl & JS)
1. **Escape de Comillas en JavaScript Inyectado desde Perl**: Al inyectar JavaScript en HEREDOCs dobles de Perl (`print <<"HTML"`), evitar comillas simples escapadas `\'` en cadenas JS delimitadas por comillas simples. Usar comillas dobles internamente o backticks de ES6.
2. **Protección de Sigilos**: Escapar símbolos de arroba como `\@media` en HEREDOCs dobles de Perl para prevenir errores de compilación `"Global symbol requires explicit package name"`.
3. **Persistencia UTF-8 LF**: Todo archivo de datos `.dat` debe manipularse con `:raw :encoding(UTF-8)`, bloqueo `flock` y fin de línea `\n` (0 CRLF).
