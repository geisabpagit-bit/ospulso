# 🩺 Catálogo: SUBCLUES (Áreas y Servicios)
**Versión**: Diamond Edition v4.2.0

Este catálogo almacena las diferentes áreas, servicios y ubicaciones físicas disponibles dentro de un establecimiento de salud (CLUES).

## Arquitectura de Datos
El origen de datos (Excel) estaba desnormalizado horizontalmente. Este catálogo ha sido **normalizado verticalmente (1FN)**, lo que significa que un mismo `CLUES` puede tener múltiples filas en este archivo, una por cada servicio.

## Estructura del Archivo
- **Ubicación**: `dat/catalogosOF/CAT_SUBCLUES.dat`
- **Delimitador**: `|` (Pipe)

## Estructura de Columnas
1. `CLUES` (FK): Clave del establecimiento padre.
2. `SUBCLUES`: Clave del sub-establecimiento o área específica.
3. `CLAVE AREA`: Código interno del área.
4. `AREA`: Nombre del área (ej. "CONSULTA EXTERNA", "HOSPITALIZACION").
5. `CLAVE SERVICIO`: Código interno del servicio médico.
6. `SERVICIO`: Nombre del servicio (ej. "GINECOLOGIA", "MEDICINA GENERAL").
7. `UBICACION FISICA`: Descripción de en qué parte del edificio se encuentra.
8. `DIAS Y HORAS DE SERVICIO`: Texto descriptivo (si aplica) del servicio.

## Relaciones
- **N:1** con `CAT_CLUES.dat` mediante el campo `CLUES`.
