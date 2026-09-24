# Directriz: CAT_NACIONALIDADES.dat

## Descripción General
Archivo plano delimitado por `!` (`CAT_NACIONALIDADES.dat`) que contiene el catálogo oficial de nacionalidades y códigos de países, basado en el catálogo oficial de nacionalidades.

## Estructura de Columnas
El archivo contiene las siguientes 3 columnas (con cabecera en la primera línea):

1. **CODIGO_PAIS**: Código numérico del país (ej. `223`).
2. **PAIS**: Nombre del gentilicio/nacionalidad (ej. `MEXICANA`, `ARGENTINA`).
3. **CLAVE_NACIONALIDAD**: Clave de 3 letras internacional (ISO-3) para el país/nacionalidad (ej. `MEX`, `ARG`).

## Uso en Sistema
- Se utiliza para poblar el campo de Nacionalidad en la pestaña "Identidad de Acceso" de la Configuración de Perfil de los médicos.
- La tabla transaccional `perfiles.dat` almacena únicamente el `CLAVE_NACIONALIDAD` (como `clave_nacionalidad`), el cual se vincula a este catálogo en tiempo de lectura para obtener la descripción de la nacionalidad.
