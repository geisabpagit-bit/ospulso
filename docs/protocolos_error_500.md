## 1 Protocolos de Desarrollo y Estabilidad (Error 500 Guard)
Para garantizar la alta disponibilidad de la plataforma y evitar errores de servidor (HTTP 500), todo desarrollo debe cumplir con:

### 1.1 Blindaje de Interpolación Perl (CSS)
Al inyectar bloques de CSS o JavaScript dentro de scripts Perl (`.pl`) mediante cadenas de doble comilla o bloques `HERE-DOC` (ej. `print <<HTML;`), los símbolos `@` son interpretados como arreglos (arrays).
- **Protocolo**: Es obligatorio escapar todo símbolo `@` anteponiendo una barra invertida `\`.
- **Ejemplos**: `\@media`, `\@keyframes`, `\@import`.
- **Riesgo**: Omitir este escape provoca un error de compilación inmediato (`Global symbol "@..." requires explicit package name`).

### 1.2 Portabilidad y Ejecución Unix/Linux
Para asegurar que los scripts funcionen sin modificaciones en servidores Windows (XAMPP) y entornos Unix (Producción), se deben seguir estos lineamientos:
- **Shebang Universal**: Todo script debe iniciar con `#!/usr/bin/perl` (o la ruta correspondiente al entorno).
- **Integridad de Rutas (FindBin)**: No utilizar rutas relativas (`./api/`) para carga de librerías. Usar siempre:
  ```perl
  use FindBin;
  use lib "$FindBin::Bin/.."; # O la ruta al core del sistema
  ```
- **Line Endings (EOL)**: Los archivos deben guardarse con formato de fin de línea **LF** (Unix) para evitar el error `\r: command not found` al ejecutar en servidores Linux.
- **Codificacion**: Todos los archivos deben estar en codificacion UTF-8 para evitar errores de visualizacion en HTML o CSS. En Perl se debe usar 'use utf8;' para que el motor   reconozca caracteres especiales y evitar errores en la interpolacion.