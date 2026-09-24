# CAT_LOCALIDADES - Catálogo de Claves de Localidades

## 1. Identificador
- **Código:** CAT_LOCALIDADES
- **Órgano Rector:** INEGI

## 2. Propósito en SIRES
- Ubicar la referencia geográfica a nivel de localidad en los sistemas.
- Normalizar la codificación de localidades en relación con las entidades federativas y municipios.

## 3. Estructura del Archivo
- Campos obligatorios:
  - **ID_ENTIDAD** → Código numérico de la entidad federativa (2 dígitos).
  - **ID_MUNICIPIO** → Código numérico del municipio (3 dígitos).
  - **ID_LOCALIDAD** → Código numérico de la localidad (4 dígitos).
  - **NOMBRE_LOCALIDAD** → Nombre oficial de la localidad.
- Reglas de validación:
  - ID_ENTIDAD debe ser numérico de dos dígitos (ej. `01`).
  - ID_MUNICIPIO debe ser numérico de tres dígitos (ej. `001`).
  - ID_LOCALIDAD debe ser numérico de cuatro dígitos (ej. `0001`).
  - NOMBRE_LOCALIDAD debe coincidir con la denominación oficial del INEGI.

## 4. Ejemplo de Registro
ID_ENTIDAD: 01
ID_MUNICIPIO: 001
ID_LOCALIDAD: 0001
NOMBRE_LOCALIDAD: AGUASCALIENTES

## 5. Control de Integración
- **Estatus:** Validado
- **Responsable:** SDM Data Team
- **Fecha de validación:** Junio 2026

## 6. Notas
- Utiliza como base el catálogo de la ENOE 06/2021.
- El delimitador utilizado es el carácter pipe `|`.
