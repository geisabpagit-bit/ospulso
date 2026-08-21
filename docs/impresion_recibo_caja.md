# Impresión de Recibo Privado (Caja Fuerte)

Este documento contiene las reglas de negocio, diseño y arquitectura para el motor de impresión de Recibos Privados (`api/imprimir_recibo_caja.pl`). 

## 1. Reglas de Diseño Estricto

### Formato y Medidas
- **Tamaño Físico**: Media Carta (5.5" x 8.5").
- **CSS Responsivo para Print**: Se inyecta la directiva `@page { size: 5.5in 8.5in; margin: 0; }`.
- **Tipografía**: La jerarquía principal depende de la familia *Plus Jakarta Sans*. No obstante, por retrocompatibilidad con navegadores antiguos de impresoras térmicas (EPSON/Star), el contenedor principal cuenta con un fallback explícito a `Arial, sans-serif`.
- **Minimalismo de Líneas**: Está prohibido el uso de negritas innecesarias, sombreados extravagantes y líneas superpuestas. Los bordes de las tablas deben utilizar la propiedad `border-collapse: collapse` y tener un grosor ultra delgado (`1px solid #ddd`).

### Distribución del Footer
La sección final del recibo (Firmas, Importes y QR) debe distribuirse asimétricamente mediante una celda maestra con proporciones estrictas:
- **50% del ancho**: Destinado para el bloque de Firmas de aceptación.
- **50% del ancho**: Destinado para el bloque de Montos Monetarios (Subtotal, Descuentos, Total Neto).

## 2. Orquestación Dinámica y Personalización (Branding)

El recibo se personaliza por inquilino (`Tenant`) leyendo el archivo `dat/negocios.dat`.
- **Nombre Comercial**: Renderizado en el encabezado central (Fila 1, Columna 2).
- **Logotipo**: Si existe un logo para el CLUEs/Negocio en `dat/logos/logo_<CLUE>.png` o `.jpg`, se renderizará automáticamente en la Fila 1, Columna 1. Si no existe, se muestra un *fallback* textual.

## 3. Protocolos de Prevención de Errores (Error 500 Guard)

Debido a que el layout HTML/CSS está embebido dentro del motor backend de Perl mediante sintaxis `HEREDOC` y `qq{}`:
1. **Escapado de Arrobas CSS**: Las reglas complejas de CSS obligatoriamente deben escapar el sigilo de arroba, ej. `\@media screen { }` y `\@page { }`. El no hacerlo arroja el error fatal *"Global symbol requires explicit package name"*.
2. **Uso de Datos en Memoria**: Para evitar inyecciones defectuosas de variables Javascript, todos los metadatos se renderizan en el HTML estático provisto por Perl antes de enviarse al navegador del cliente. No se usa JavaScript dinámico.

## 4. Origen de los Datos
El script obtiene el recibo de la base `dat/folios_recibos_privados.dat` cruzando el folio (último segmento del ID). La variable `$recibo->{elaborado_por}` despliega el usuario cajero logueado al momento del cobro.
