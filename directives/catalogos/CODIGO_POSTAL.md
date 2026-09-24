# CODIGO_POSTAL - Catálogo de Códigos Postales

## 1. Identificador
- **Código:** CODIGO_POSTAL
- **Órgano Rector:** Correos de México / INEGI / SEPOMEX

## 2. Propósito en SIRES
- Ubicar domicilios en los sistemas.
- Normalizar la codificación de asentamientos, municipios y entidades.
- Integrar información oficial de SEPOMEX e INEGI.

## 3. Cabecera de Validación
El archivo `.dat` debe contener la siguiente cabecera exacta:
d_codigo|d_asenta|d_tipo_asenta|D_mnpio|d_estado|d_ciudad|d_CP|c_estado|c_oficina|c_CP|c_tipo_asenta|c_mnpio|id_asenta_cpcons|d_zona|c_cve_ciudad


## 4. Descripción de Campos
- **d_codigo** → Código Postal del asentamiento (5 dígitos).
- **d_asenta** → Nombre del asentamiento.
- **d_tipo_asenta** → Tipo de asentamiento (Catálogo SEPOMEX).
- **D_mnpio** → Nombre del municipio (INEGI, marzo 2013).
- **d_estado** → Nombre de la entidad federativa (INEGI, marzo 2013).
- **d_ciudad** → Nombre de la ciudad (Catálogo SEPOMEX).
- **d_CP** → Código Postal de la administración postal que reparte al asentamiento.
- **c_estado** → Clave de la entidad (INEGI, marzo 2013).
- **c_oficina** → Código Postal de la administración postal que reparte al asentamiento.
- **c_CP** → Campo vacío.
- **c_tipo_asenta** → Clave del tipo de asentamiento (Catálogo SEPOMEX).
- **c_mnpio** → Clave del municipio (INEGI, marzo 2013).
- **id_asenta_cpcons** → Identificador único del asentamiento (nivel municipal).
- **d_zona** → Zona en la que se ubica el asentamiento (Urbano/Rural).
- **c_cve_ciudad** → Clave de la ciudad (Catálogo SEPOMEX).

## 5. Ejemplo de Registro
07500|La Pradera|Colonia|Gustavo A. Madero|Ciudad de México|Ciudad de México|07500|09|07500||09|010|12345|Urbano|001

## 6. Control de Integración
- **Estatus:** [Pendiente / En proceso / Validado]
- **Responsable:**  
- **Fecha de validación:**  

## 7. Notas
- El catálogo se actualiza periódicamente con información oficial de SEPOMEX e INEGI.
