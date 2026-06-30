# 🏥 Catálogo: CLUES (Establecimientos de Salud)
**Versión**: Diamond Edition v4.2.0

Este catálogo almacena la información principal (entidad) de los Establecimientos de Salud a nivel nacional, extraída del padrón CLUES oficial.

## Estructura del Archivo
- **Ubicación**: `dat/catalogosOF/CAT_CLUES.dat`
- **Delimitador**: `|` (Pipe)

## Descripción de las Columnas Principales
*(Nota: El archivo contiene ~65 columnas detalladas. Estas son las más relevantes para la lógica de negocio).*

1. `CLUES` (PK): Clave Única de Establecimiento de Salud.
2. `CLAVE DE LA INSTITUCION`: Código de la institución (ej. SSA, IMSS, ISSSTE).
3. `NOMBRE DE LA INSTITUCION`: Nombre oficial de la institución.
4. `CLAVE DE LA ENTIDAD` / `ENTIDAD`: Relación con `CAT_ENTIDADES.dat`.
5. `CLAVE DEL MUNICIPIO` / `MUNICIPIO`: Relación con `CAT_MUNICIPIOS.dat`.
6. `CLAVE DE LA LOCALIDAD` / `LOCALIDAD`: Relación con `CAT_LOCALIDADES.dat`.
7. `NOMBRE TIPO ESTABLECIMIENTO`: Hospital, Clínica, etc.
8. `NOMBRE DE LA UNIDAD`: Nombre completo oficial de la unidad de salud.
9. `NOMBRE COMERCIAL`: Nombre comercial del establecimiento.
10. `DOMICILIO`: Desglosado en Vialidad, Número Exterior, Número Interior, Asentamiento y Código Postal.
11. `LATITUD` / `LONGITUD`: Coordenadas geográficas.
12. `ESTATUS DE OPERACION`: Operando, Fuera de operación, etc.

## Relaciones
- **1:N** con `CAT_SUBCLUES.dat` (Servicios por unidad).
- **1:N** con `CAT_HORARIOS.dat` (Horarios por unidad).
- **N:1** con `CAT_ENTIDADES.dat`, `CAT_MUNICIPIOS.dat`, `CAT_LOCALIDADES.dat`.

## Consideraciones de Uso
- **Solo Lectura**: Este catálogo jamás debe ser modificado por la aplicación.
- **Búsqueda Rápida**: Si se requieren búsquedas por `CLUES` desde el backend, se recomienda indexar o usar hashes en Perl debido a la gran cantidad de registros.
