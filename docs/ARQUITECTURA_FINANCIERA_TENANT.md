# ARQUITECTURA FINANCIERA MULTI-TENANT: CAJA, INGRESOS Y FLUJO DE EFECTIVO
**Sistema Hospitalario y Clínico: Ospulso / SDM**
**Documento Rector de Contabilidad, Cobranza y Gobernanza de Datos**

---

## 1. Visión General y Contexto Operativo

En el modelo de operación médica y administrativa de **Ospulso**, las organizaciones de salud (clínicas privadas, policlínicas y centros de salud con convenio municipal) reciben recursos económicos a través de **dos canales cardinales e independientes**:

```
+---------------------------------------------------------------------------------------------------+
|                                 CANALES DE RECAUDACIÓN EN OSPULSO                                  |
+---------------------------------------------------------------------------------------------------+
|                                                 |                                                 |
|               CANAL 1: FLUJO CLÍNICO CANÓNICO   |        CANAL 2: CAJA RÁPIDA / MOSTRADOR          |
|                                                 |                                                 |
|  * Flujo: Cita -> Expediente -> SOAP -> Caja    |  * Flujo: Llegada directa a ventanilla (Walk-in)|
|  * Paciente: Registrado con Expediente Formal   |  * Paciente: Eventual, ambulatorio o trámite     |
|  * Prestador: Médico tratante asignado          |  * Prestador: Ventanilla / Turno / Recepción    |
|  * Objeto: Honorarios médicos, procedimientos   |  * Objeto: Certificados, inyecciones, curaciones|
|  * Registro clínico: Nota SOAP / Expediente     |  * Registro clínico: Sin consulta obligatoria   |
|  * Comprobante: Recibo Clínico Formal           |  * Comprobante: Ticket Térmico / Recibo Rápido  |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Tipos de Recibos y Canales de Ingreso

De la caja y la atención hospitalaria derivan dos naturalezas de comprobantes:

### A. Ingresos Privados (Contado / Efectivo / Tarjeta / Transferencia)
- **Definición**: Recursos económicos cobrados en ventanilla en tiempo real al paciente o su acompañante.
- **Archivo Fuente**: `dat/folios_recibos_privados.dat`
- **Destino Contable**: KPI **"INGRESOS REALES (Cobrado en Caja)"**.
- **Impacto de Caja**: Entra dinero líquido al cajón físico o a la cuenta bancaria de la sucursal.
- **Tipos de Paciente**:
  1. *Privado con Expediente*: Paciente con registro en `dat/pacientes.dat` o `dat/catalogos_CLUE/<CLUES>/pacientes_privados_<CLUES>.dat`.
  2. *Privado Ambulatorio (Walk-in)*: Identificador dinámico temporal `PRIV-<timestamp><random>`. No requiere historial clínico previo para emitir un comprobante.

### B. Ingresos Públicos / Municipio (Convenios Estatales / Subsidio)
- **Definición**: Prestaciones brindadas a derechohabientes (trabajadores sindicalizados, policías, empleados municipales o sus beneficiarios) bajo convenios de salud pública.
- **Archivo Fuente**: `dat/folios_recibos_publicos.dat`
- **Destino Contable**: 
  - Si el derechohabiente paga un copago en efectivo: Ese copago entra a **"INGRESOS REALES"**.
  - El monto cubierto por el convenio entra al KPI **"CXC (ESTADO / CONVENIOS PÚBLICOS)"**.
- **Impacto de Caja**: **NO** es dinero físico en el cajón en el momento de la consulta. Es una **Cuenta por Cobrar (Activo Circulante)** que la organización liquida en un corte periódico contra el Ayuntamiento o Dependencia Estatal.
- **Tipos de Paciente**:
  1. *Trabajador Municipal Titular*: Padrón `dat/catalogos_CLUE/<CLUES>/empleadosmun_<CLUES>.dat` (Prefijo `EMP-<num>`).
  2. *Beneficiario*: Familiar directo del trabajador municipal (esposa, hijo, padre), registrado en el padrón o capturado como alias en el recibo.

---

## 3. Principios de Oro de la Arquitectura Financiera

### Principio I: Integridad Contable Bidireccional (Drilldown Transparente)
> *El Tablero Ejecutivo (KPIs) y las Vistas de Detalle (DataTables) deben coincidir al centavo en cualquier periodo seleccionado.*

Si el KPI **"INGRESOS REALES"** muestra `$1,570.00`, al hacer clic en el KPI para acceder a `views/finanzas.pl?tab=ingresos`, el DataTables de `dtIngresosPrivados` **DEBE** sumar exactamente `$1,570.00`. No puede existir discrepancia entre la cifra ejecutiva y el desglose de folios.

### Principio II: Fuente Canónica de Flujo de Efectivo (Anti-Doble Contabilidad)
- La fuente canónica e inviolable de **Flujo de Caja Cobrado** es `dat/folios_recibos_privados.dat`.
- `dat/estado_cuenta.dat` es el libro auxiliar de cuenta corriente del paciente.
- **PROHIBICIÓN ESTRICTA**: Nunca sumar montos de `estado_cuenta.dat` y `folios_recibos_privados.dat` en paralelo para calcular ingresos totales, ya que cada recibo emitido desde una consulta clínica también registra movimientos en `estado_cuenta.dat` con el mismo número de comprobante, lo que duplicaría artificialmente la facturación.

### Principio III: Separación de Flujo Real vs Devengado (Caja vs CXC)
- El efectivo, voucher de tarjeta o transferencia verificada en ventanilla es **Flujo de Caja Real**.
- Las órdenes de servicio a crédito o subsidios de municipio son **Cuentas por Cobrar (CXC)**. Nunca deben mezclarse en el mismo KPI de "Cobrado en Caja" hasta que la Tesorería Municipal emita el cheque o transferencia de liquidación.

---

## 4. Estándares de Visualización, Impresión y Auditoría

### 4.1. Reglas de Visualización en DataTables (`tab=ingresos`)
Toda fila de ingreso debe presentar con claridad:
1. **Folio Único**: Consecutivo auditable del recibo.
2. **Badge de Origen**:
   - `<span class="badge badge-origen-rapida">Caja Rápida</span>`: Trámite directo de ventanilla.
   - `<span class="badge badge-origen-consulta">Consulta Médica</span>`: Derivado de expediente y acto clínico.
3. **Paciente y Titular**: Si es de convenio municipal, mostrar tanto el nombre del paciente atendido como el del empleado titular y su dependencia.
4. **Médico / Responsable**: Profesional que atendió o cajero que cobró.
5. **Estatus y Trazabilidad**: Si un recibo fue cancelado, debe mostrarse tachado con el motivo de cancelación explícito, restándose de los totales netos.

### 4.2. Reglas de Impresión y Entrega de Comprobantes
1. **Recibo Rápido / Mostrador**:
   - Formato predeterminado: **Ticket Térmico (80mm)**.
   - Contenido: Logotipo de la clínica, CLUES, Folio único, Fecha/Hora, Nombre de paciente eventual, Desglose de servicios, Total cobrado, Nombre de cajero(a).
   - Leyenda obligatoria: *"Comprobante de Caja Mostrador - Este documento no constituye una receta médica."*
2. **Recibo Clínico / Honorarios**:
   - Formato: **Carta / Media Carta Institucional o PDF descargable**.
   - Contenido: Datos del médico (Nombre, Especialidad, Cédula Profesional), Número de Expediente Clínico, Diagnóstico general (opcional por confidencialidad), desglose de honorarios e insumos.

---

## 5. Gobernanza Multi-Tenant y RBAC

1. **Aislamiento Multi-Organización (`id_empresa` / `CLUES`)**:
   - Cada consulta o cálculo debe filtrar estrictamente por el `id_negocio` y su respectiva carpeta `catalogos_CLUE/<CLUES>/`.
   - Está estrictamente prohibido que un Administrador de Organización o Recepcionista visualice folios o gastos de otro tenant.
2. **Segregación de Funciones (RBAC)**:
   - **Recepcionista / Cajero**: Solo visualiza y arquea los recibos que fueron elaborados en su turno o por su propio usuario (`ELABORADO_POR`).
   - **Administrador de Organización**: Visualiza la totalidad de los ingresos y egresos de su clínica.
   - **Médico**: Visualiza sus honorarios generados, pero no tiene acceso al Tablero Financiero Global ni a la gestión de gastos operativos.

---

## 6. Mantenimiento y Cumplimiento Obligatorio

Cualquier nuevo desarrollo, refactorización o endpoint API (`api/finanzas_api.pl`, `api/generar_corte_caja.pl`, `api/cancelar_recibo_api.pl`, `views/finanzas.pl`) debe verificar su apego a este documento rector.
