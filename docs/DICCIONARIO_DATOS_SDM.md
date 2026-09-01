# Diccionario de Datos y Mapeo de Entidades (SDM)

Esta guía documenta la estructura del backend basada en archivos `.dat`, la conformación de folios y las reglas de extracción para mapear correctamente la información hacia el Frontend. Sirve como referencia estricta para futuros desarrollos y mantenimiento.

---

## 1. Pacientes (Identidades Mixtas)

El sistema maneja dos flujos principales de pacientes: **Privados** y **Públicos (Estado/Municipio)**. Sus catálogos y formatos difieren significativamente.

### Pacientes Privados
- **Fuente de Datos:** `dat/pacientes_privados__<CLUES>.dat` (y el archivo global `dat/pacientes.dat`).
- **Separador:** Pipe `|`
- **Índices Clave (pacientes_privados):**
  - `[0]` = ID del Paciente (Ej: `1`, `2`, o con prefijo `PRIV-X`).
  - `[1]` = Nombre Completo.
- **Regla de Frontend:** Si un folio de recibo privado no trae un prefijo claro, se asume que es privado y se busca en esta tabla.

### Pacientes Públicos (Empleados del Estado / Municipio)
- **Fuente de Datos:** `dat/empleadosmun_<CLUES>.dat`
- **Separador:** Cierre de Exclamación `!`
- **Índices Clave:**
  - `[0]` = ID del Empleado (Ej: `6113`).
  - `[1]` = Nombre Completo.
  - `[2]` = Relación (`Empleado` o `Beneficiario`).
- **Comportamiento Especial (El Problema del Prefijo y Beneficiarios):**
  - En las tablas transaccionales (como CxC o recibos públicos), el sistema guarda el ID del paciente inyectando el prefijo `EMP-` (Ej: `EMP-6113`).
  - Al cruzar los datos contra `empleadosmun_...dat`, se debe **limpiar el prefijo `EMP-`** o **inyectarlo artificialmente** al leer el catálogo para que las llaves coincidan.
  - **Diferenciación de Titular vs Beneficiario**: Un empleado (Ej: `6113`) puede tener N beneficiarios en `empleadosmun_...dat`. El motor backend indexa a los titulares filtrando estrictamente los registros con `[2] eq 'Empleado'`, garantizando que la propiedad `trabajador_nombre` sea siempre el titular del expediente. El nombre del **Paciente Real** se extrae de la columna `ALIAS` de `estado_cuenta.dat` (`Paciente: <Nombre Real>`).

---

## 2. Médicos (Staff)

- **Fuente de Datos:** `dat/medicos_<CLUES>.dat`
- **Separador:** Pipe `|`
- **Índices Clave:**
  - `[0]` = ID del Médico (Ej: `12`, `45`).
  - `[1]` = Nombre del Médico (Ej: `DRA JANETH AREVALO`).
- **Reglas de Fallback:** Si un ID no se encuentra en el diccionario, el Frontend siempre debe renderizar el ID puro como método de seguridad (Ej: `Desconocido (ID: 12)`) para facilitar el rastreo.

---

## 3. Conformación y Limpieza de Folios

Los folios que inyecta el sistema central (o los puntos de venta) suelen venir encadenados con llaves de sucursal o año. Para la UI (Frontend), el usuario final **solo requiere ver el consecutivo absoluto (el último tramo)**.

### Reglas de Extracción (Expresiones Regulares / Split):
Toda vista (como Finanzas, Cortes, Tablas) debe aplicar la regla de **"último nodo"** si el folio incluye guiones (`-`) o diagonales (`/`).

- **Orden de Servicio (OS):**
  - Crudo: `OS/2024/1034408-674546-006707`
  - Limpio: **`6707`**
- **Transacción de Caja Directa (TX):**
  - Crudo: `TX-1787332451-159`
  - Limpio: **`159`**
- **Recibo Directo CLUES:**
  - Crudo: `1034408-674546-027380`
  - Limpio: **`27380`**

*Fragmento de código Perl recomendado para limpiar folios en el Backend antes de enviarlos como JSON:*
```perl
my $folio_crudo = "OS/2024/1034408-674546-006707";
# Extraer solo los números después del último guion o slash
my $folio_limpio = $folio_crudo;
if ($folio_limpio =~ /[-\/](0*[^-\/]+)$/) {
    $folio_limpio = $1; 
}
# Resultado: 6707
```

---

## 4. Fuentes de Ingresos / Egresos Transaccionales

- **Ingresos Privados (Efectivo):** `dat/folios_recibos_privados.dat`
- **CxC / Ingresos Públicos:** `dat/folios_recibos_publicos.dat`
- **Egresos (Gastos Operativos):** `dat/egresos_caja_<CLUES>.dat`

## 5. Mejores Prácticas de Arquitectura Frontend vs Backend

1. **Diccionarios en Memoria (Backend):** Cuando un script `.pl` como el `generar_corte_caja.pl` necesite armar una tabla, NUNCA debe hacer consultas al archivo de catálogo `.dat` fila por fila (adentro de un loop). Se deben cargar los catálogos en Hashes (Diccionarios) (`%pacientes`, `%medicos`) al inicio del script y usarlos para resolver O(1) dentro del loop transaccional.
2. **Delegar al Backend la Resolución:** El Frontend (JavaScript/HTML) NO debe encargarse de adivinar a quién pertenece un ID. La respuesta JSON ya debe traer las llaves: `paciente: "Ortiz Perez Hector"` en lugar de `paciente_id: "EMP-6113"`.
3. **El Frontend solo renderiza:** Aplica el estándar `GUIA_ESTILO_SDM.md` para las tablas, DataTables y KPIs. No incrustes reglas de negocio contables en el Frontend si es posible realizar el cálculo de agrupaciones en el `.pl`.
