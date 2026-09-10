# Directriz: CAT_CIE09_PROCEDIMIENTOS.dat

## Descripción General
Archivo plano delimitado por `!` (`CAT_CIE09_PROCEDIMIENTOS.dat`) que contiene el catálogo oficial de la Clasificación Internacional de Enfermedades, Novena Revisión, Modificación Clínica (CIE-9 MC) correspondiente a procedimientos quirúrgicos y no quirúrgicos del sector salud en México, basado en la versión 202402.

## Estructura de Columnas
El archivo contiene las siguientes 3 columnas (con cabecera en la primera línea):

1. **CATALOG_KEY**: Identificador único y clave del procedimiento CIE-9 MC (ej. `0001`, `0002`).
2. **PRO_NOMBRE**: Descripción del procedimiento clínico/quirúrgico (ej. `ULTRASONIDO TERAPÉUTICO DE VASOS DE CABEZA Y CUELLO`).
3. **CAPITULO**: Código del capítulo del catálogo al que pertenece (ej. `00`).

## Uso en Sistema
- Se utiliza para la búsqueda y registro de procedimientos clínicos en el plan terapéutico de la consulta médica y expedientes de pacientes en SDM.
