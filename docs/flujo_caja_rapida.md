# Flujo Operativo y UX de Caja Rápida (`views/generar_recibo.pl`)

## 1. Visión General
El módulo de **Caja Rápida** permite la emisión ágil de recibos tanto para **Pacientes Privados** (flujo con cobro en ventanilla y recibo privado) como para **Pacientes de Convenio / Estado / Municipio** (órdenes médicas con subsidio municipal y recibo público foliado).

---

## 2. Reglas de Negocio en la Interfaz (UX)

### 2.1 Ordenamiento Alfabético de Departamentos y Preselección
- El selector `Concepto del Recibo (Departamento)` carga la lista de departamentos activos ordenados **estrictamente de forma alfabética**.
- Por defecto, el departamento **`CONSULTAS`** (`id_dep = 1`) queda **preseleccionado automáticamente**, desplegando de inmediato los controles clínicos de Especialidad y Médico Tratante.

### 2.2 Filtrado Dinámico de Especialidades por Tipo de Paciente y Tarifa Activa
Para evitar errores de cobro o selección de servicios no disponibles, la lista de **Especialidades** se filtra de forma reactiva según la tarifa disponible:

1. **Paciente Privado (`pacienteTipoActual === 'privado'`)**:
   - Se evalúan las especialidades de consultas (`id_dep = 1`).
   - Solo se muestran aquellas especialidades que cuenten con al menos un médico cuya tarifa privada (`ESTANDAR` u otra distinta a `MUNICIPIO`) sea **mayor a $0.00**.
   - **Especialidades excluidas automáticamente**: Aquellas cuya tarifa comercial sea `$0.00` (por ejemplo, *Angiología*, *Alergología*, *Cardiología*, etc., que son exclusivas de convenio público).
   
2. **Paciente de Convenio / Estado / Municipio (`pacienteTipoActual === 'estado'`)**:
   - Solo se muestran aquellas especialidades que cuenten con al menos un médico cuya tarifa `MUNICIPIO` sea **mayor a $0.00**.
   - **Especialidades excluidas automáticamente**: Aquellas que no formen parte del tabulador municipal acordado (por ejemplo, *Medicina Interna / Geriatría*, *Traumatología / Ortopedia*).

### 2.3 Filtrado en Cascada a Nivel de Médico Tratante
- Dentro de la especialidad seleccionada, el selector de `Médico Tratante` filtra y muestra únicamente a los facultativos que tienen tarifa activa (`> $0.00`) para el tipo de paciente en curso.
- Los médicos se presentan con su nombre completo ordenado alfabéticamente.

---

## 3. Conmutación Reactiva
- Si el usuario busca y selecciona un beneficiario municipal mediante el campo **Número de Empleado**, el sistema conmuta instantáneamente al tabulador `estado`, recalculando la lista de especialidades visibles (habilitando *Angiología*, etc.).
- Si se limpia el campo de Número de Empleado o se selecciona un **Paciente Privado**, el sistema regresa inmediatamente al esquema comercial privado.
