# CAT_MUNICIPIOS - Catálogo de Claves de Municipios

## 1. Identificador
- **Código:** CAT_MUNICIPIOS
- **Órgano Rector:** INEGI

## 2. Propósito en SIRES
- Ubicar la referencia geográfica a nivel municipal en los sistemas.
- Normalizar la codificación de municipios en relación con las entidades federativas.

## 3. Estructura del Archivo
- Campos obligatorios:
  - **ID_ENTIDAD** → Código numérico de la entidad federativa a la que pertenece (2 dígitos).
  - **ID_MUNICIPIO** → Código numérico del municipio (3 dígitos).
  - **NOMBRE_MUNICIPIO** → Nombre oficial del municipio.
- Reglas de validación:
  - ID_ENTIDAD debe ser numérico de dos dígitos (ej. `01`).
  - ID_MUNICIPIO debe ser numérico de tres dígitos (ej. `001`).
  - NOMBRE_MUNICIPIO debe coincidir con la denominación oficial del INEGI.

## 4. Ejemplo de Registro
ID_ENTIDAD: 01
ID_MUNICIPIO: 001
NOMBRE_MUNICIPIO: AGUASCALIENTES

## 5. Control de Integración
- **Estatus:** Validado
- **Responsable:** SDM Data Team
- **Fecha de validación:** Junio 2026

## 6. Notas
- Utiliza como base el catálogo de la ENOE 06/2021.
- El delimitador utilizado es el carácter pipe `|`.
