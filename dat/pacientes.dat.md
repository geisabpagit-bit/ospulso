# 👤 Documentación de Datos: pacientes.dat
**Versión**: Diamond Edition v3.9.0

## Estructura del Archivo
- **Delimitador**: `|` (Pipe)
- **Columnas Críticas**:
  1. `ID`: Identificador único del paciente.
  2. `NOMBRE`: Nombre completo.
  ...
  6. `CORREO`: Email de vinculación (Llave de sincronización con `usuarios.dat`).
  7. `FECHA_NAC`: Fecha de nacimiento (`YYYY-MM-DD`), utilizada para calcular la Edad en tiempo real en la ficha clínica y en consultas médicas (`render_consultas_privado.pl`).

## Reglas de Sincronización (Mutant Profile)
- **Cálculo de Edad Dinámico**: La edad del paciente se calcula al vuelo comparando `FECHA_NAC` contra la fecha actual (`localtime`), desplegándose a un lado de `SEXO` en el registro de consulta.
- **Vínculo de Identidad**: Todo usuario con rol `Paciente` en `usuarios.dat` debe tener un registro correspondiente aquí vinculado por el campo `CORREO`.
- **Edición Unificada**: Al actualizar el perfil del paciente, los datos de identidad (Nombre, Clave) se guardan en `usuarios.dat`, mientras que los datos clínicos y de contacto se guardan en `pacientes.dat`.
- **Prioridad de Datos**: En caso de discrepancia, `usuarios.dat` es la fuente de verdad para el Nombre y Credenciales, y `pacientes.dat` para la Ficha Clínica.

### 🏗️ Arquitectura de Renderizado (Actualización Diamond Edition)
- **Dashboard Horizontal**: Los datos de pacientes extraídos de este archivo se renderizan a través de `pacientes_spa.js` y `pacientes.pl` utilizando un Offcanvas Responsivo con Layout Compacto (Zoom 80%).
- **KPIs Bento**: Integración de métricas de `estado_cuenta.dat` en un Grid 1x3 estricto.
- **Botones Exportación**: Uso de DataTables con `dom` configurado para export-toolbar Glassmorphism, garantizando `exportOptions` para no exportar la columna HTML de acciones y blindando `pdfMake` contra TypeErrors.
