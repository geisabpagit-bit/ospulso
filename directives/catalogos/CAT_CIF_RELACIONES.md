# Directriz: Relaciones y Estructura del Catálogo CIF

## Descripción General
La Clasificación Internacional del Funcionamiento, de la Discapacidad y de la Salud (CIF) se estructura en niveles jerárquicos y calificadores que permiten una evaluación del estado de salud funcional de un paciente. Este archivo describe la relación y uso de las tablas segmentadas del catálogo.

## Tablas del Catálogo CIF
1. **CAT_CIF_1erNivel.dat**: Capítulos generales del funcionamiento (ej. `b1` Funciones mentales).
2. **CAT_CIF_2oNivel.dat**: Categorías de segundo nivel detallando subgrupos (ej. `b110` Funciones de la conciencia).
3. **CAT_CIF_3erNivel.dat**: Detalle de tercer nivel (ej. `b1100` Nivel de conciencia).
4. **CAT_CIF_4oNivel.dat**: Máximo nivel de especificidad clínica (ej. `b11420` Orientación respecto a uno mismo).

## Calificadores Asociados
Para evaluar el grado de deficiencia o capacidad en cada nivel, se asocian calificadores específicos:
- **CAT_CIF_CALFUNC.dat** (Calificador de Funciones Corporales): Mide la magnitud de deficiencias en funciones corporales (`0` a `4`, `8`, `9`).
- **CAT_CIF_CALESTRUC.dat** (Calificador de Estructuras Corporales): Mide deficiencias en estructuras corporales, incluyendo naturaleza del cambio y localización.
- **CAT_CIF_CALACTPART.dat** (Calificador de Actividades y Participación): Determina el desempeño y capacidad en la realización de tareas diarias (`0` a `4`, `8`, `9`).
- **CAT_CIF_CALAMB.dat** (Calificador de Factores Ambientales): Cuantifica facilitadores (`+0` a `+4`) y barreras (`0` a `4`).

## Uso en Sistema
En la pestaña **Estructura S.O.A.P.** en la sección **Evaluación (A)**, el médico puede registrar el código CIF correspondiente a los niveles del paciente y asignarle el calificador respectivo para cuantificar la deficiencia o barrera del entorno.
