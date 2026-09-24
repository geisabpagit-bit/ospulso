# Directriz: CAT_FORMACION.dat

## Descripción General
Archivo plano delimitado por `!` (`CAT_FORMACION.dat`) que contiene el catálogo oficial de formaciones académicas del sector salud en México, basado en la tabla de datos abiertos 201706.

## Estructura de Columnas
El archivo contiene las siguientes 4 columnas (con cabecera en la primera línea):

1. **CATALOG_KEY**: Identificador único de la formación (ej. `120`).
2. **FORMACION_ACADEMICA**: Nombre descriptivo de la carrera o especialidad (ej. `MEDICO CIRUJANO`).
3. **AGRUPACION**: Categoría general a la que pertenece la formación (ej. `MEDICINA`).
4. **GRADO**: Nivel académico de la formación.

## Uso en Sistema
- Se utiliza para poblar el listado de formaciones académicas en la Configuración de Perfil para los especialistas médicos.
- La tabla transaccional `perfiles.dat` almacena únicamente el `CATALOG_KEY` (como `clave_formacion`), el cual se vincula a este catálogo en tiempo de lectura para obtener la descripción textual completa.
