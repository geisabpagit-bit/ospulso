# CAT_ENTIDADES - Catálogo de Claves de Entidades Federativas

## 1. Identificador
- **Código:** CAT_ENTIDADES
- **Órgano Rector:** INEGI

## 2. Propósito en SIRES
- Ubicar cualquier referencia geográfica en los sistemas.
- Normalizar la codificación de entidades federativas.

## 3. Estructura del Archivo
- Campos obligatorios:
  - **ID** → Código numérico de la entidad.
  - **Nombre** → Nombre oficial de la entidad federativa.
  - **Abrev** → Abreviatura oficial.
- Reglas de validación:
  - ID debe ser numérico de dos dígitos (ej. `01`, `32`).
  - Nombre debe coincidir con la denominación oficial.
  - Abrev debe ser de 2 a 3 caracteres en mayúsculas.

## 4. Ejemplo de Registro
ID: 09
Nombre: CIUDAD DE MÉXICO
Abrev: DF

## 5. Control de Integración
- **Estatus:** [Pendiente / En proceso / Validado]
- **Responsable:**  
- **Fecha de validación:**  

## 6. Notas
- Incluye códigos especiales: `00` (NO ESPECIFICADO), `88` (NO APLICA), `99` (SE IGNORA).
