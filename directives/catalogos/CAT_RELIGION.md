# Directriz: CAT_RELIGION.dat

## Descripción General
Archivo plano delimitado por `!` (`CAT_RELIGION.dat`) que contiene el catálogo oficial de religiones y credos en México, basado en el catálogo oficial de religión 20200701.

## Estructura de Columnas
El archivo contiene las siguientes 8 columnas (con cabecera en la primera línea):

1. **CLAVE_CREDO**: Identificador del credo principal.
2. **CREDO**: Nombre del credo general (ej. `CRISTIANO`, `OTROS CREDOS`).
3. **CLAVE_GRUPO**: Clave del grupo religioso.
4. **GRUPO**: Nombre del grupo religioso (ej. `Católicos`, `Judaico`).
5. **CLAVE_DENOMINACION**: Clave de la denominación.
6. **DENOMINACION**: Nombre de la denominación (ej. `Católicos`, `Judaísmo`).
7. **CLAVE_RELIGION**: Identificador único y clave principal de la religión (ej. `110101`).
8. **RELIGION**: Nombre específico de la religión/denominación detallada (ej. `Católico Apostólico Romano`).

## Uso en Sistema
- Se utiliza para poblar el campo de Religión en la pestaña "Identidad de Acceso" de la Configuración de Perfil de los médicos.
- La tabla transaccional `perfiles.dat` almacena únicamente el `CLAVE_RELIGION` (como `clave_religion`), el cual se vincula a este catálogo en tiempo de lectura para obtener la descripción textual completa.
