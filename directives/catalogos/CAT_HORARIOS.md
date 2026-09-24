# 🕒 Catálogo: HORARIOS (Jornadas de Atención)
**Versión**: Diamond Edition v4.2.0

Este catálogo almacena los horarios de apertura y cierre de las clínicas durante los días de la semana.

## Arquitectura de Datos
El origen de datos (Excel) estaba fuertemente desnormalizado (hasta 14 bloques horizontales por clínica). Este catálogo ha sido **normalizado verticalmente (1FN)**. Un mismo `CLUES` puede tener múltiples filas si maneja distintos bloques de horario en el mismo día.

## Estructura del Archivo
- **Ubicación**: `dat/catalogosOF/CAT_HORARIOS.dat`
- **Delimitador**: `|` (Pipe)

## Estructura de Columnas
1. `CLUES` (FK): Clave del establecimiento padre.
2. `DOMINGO`: `SI` o `NO`.
3. `LUNES`: `SI` o `NO`.
4. `MARTES`: `SI` o `NO`.
5. `MIERCOLES`: `SI` o `NO`.
6. `JUEVES`: `SI` o `NO`.
7. `VIERNES`: `SI` o `NO`.
8. `SABADO`: `SI` o `NO`.
9. `HORA INICIO`: Hora de apertura en formato `HH:MM`.
10. `HORA FIN`: Hora de cierre en formato `HH:MM`.

## Relaciones
- **N:1** con `CAT_CLUES.dat` mediante el campo `CLUES`.
