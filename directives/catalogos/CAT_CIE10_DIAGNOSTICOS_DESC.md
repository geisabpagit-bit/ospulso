# Directriz: CAT_CIE10_DIAGNOSTICOS.dat

## Descripción General
Archivo plano delimitado por `!` (`CAT_CIE10_DIAGNOSTICOS.dat`) que contiene la Clasificación Internacional de Enfermedades, Décima Revisión (CIE-10), adaptada para diagnósticos asociados en el expediente clínico de SDM, basado en la versión oficial del catálogo de abril de 2024.

## Estructura de Columnas
El archivo contiene las siguientes 3 columnas (con cabecera en la primera línea):

1. **CATALOG_KEY**: Clave alfanumérica única del diagnóstico/código CIE-10 (ej. `A000`, `J172`).
2. **NOMBRE**: Nombre descriptivo de la enfermedad o afección (ej. `CÓLERA DEBIDO A VIBRIO CHOLERAE 01, BIOTIPO CHOLERAE`).
3. **CAPITULO**: Título del capítulo correspondiente al diagnóstico en el árbol CIE-10 (ej. `CIERTAS ENFERMEDADES INFECCIOSAS Y PARASITARIAS`).

## Uso en Sistema
- Se integra en la pestaña **Estructura S.O.A.P.** en el wizard clínico de consultas médicas.
- Sirve como selector autocomplete para registrar de forma codificada los diagnósticos y valoraciones clínicas de los pacientes en el expediente.
