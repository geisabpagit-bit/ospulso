# Impresión de Recibo Público (Estado / Municipio)

Este documento contiene las directrices de renderizado para pacientes clasificados como Estatales/Municipales, definidos bajo el script `api/imprimir_recibo_publico.pl`.

## 1. Origen Diferenciado de Datos

Los recibos públicos atienden al flujo de convenios de salud con dependencias gubernamentales.
- **Base de Datos**: Extrae su origen y metadatos estrictamente desde `dat/folios_recibos_publicos.dat`.
- **Filtro de Seguridad (Prefijo EMP)**: El sistema verifica y asume que el `$id_paciente` contenido en la base de datos comienza con el prefijo `EMP-`. 

## 2. Reglas Estilísticas y de UI

La impresión sigue las mismas rigurosas reglas de minimalismo que el recibo privado, sin embargo, su conceptualización visual asume que se anexará a un expediente burocrático (auditable por entidades federativas).

- **Grid Layout Limpio**: Ninguna línea debe traslaparse. Todos los bordes (`td`, `th`) utilizan `border: 1px solid #ddd;`.
- **Logotipos Dinámicos**: Si existe, se incrusta un logotipo desde `dat/logos/`. En la celda Fila 1 Columna 1 **jamás debe duplicarse la etiqueta** o el nombre del logotipo (como un texto *alt* que ensucie el render); se debe renderizar únicamente la imagen si existe, o un espacio en blanco/título *fallback* si no existe.
- **Formato Celda Fecha/Hora**: Para evitar truncamientos en la esquina superior derecha (Fila 1, Columna 3), la fecha y hora se fusionan en una sola línea mediante un tag unificado, con un tamaño de fuente compactado (`9px`) y la instrucción CSS `white-space: nowrap`. Solo la leyenda del Folio posee negritas.

## 3. Composición 50/50 Footer (Auditoría)

La sección inferior para recabar firmas de los servidores públicos / derechohabientes está seccionada obligatoriamente en un **layout particionado del 50%**.
- **Izquierda (50%)**: Espacio amplio y con línea continua inferior para *"Firma de Conformidad"*.
- **Derecha (50%)**: Desglose financiero y totales netos de los subsidios o cargos adicionales. 

## 4. Estándares Técnicos (Perl HTML Injection)
- **Escape de Variables de Interpolación**: Toda arroba utilizada en CSS (`\@page`, `\@media`) debe ir escapada para no detonar arreglos vacíos en Perl que resultan en *Error 500*.
- **Codificación Universal**: Generado con `-charset => 'UTF-8'` para asegurar la correcta legibilidad de acentos mexicanos en los conceptos del convenio.
