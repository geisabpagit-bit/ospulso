# 🗄️ Documentación de Datos: usuarios.dat
**Versión**: Diamond Edition v3.9.0

## Estructura del Archivo
- **Delimitador**: `!` (Exclamación)
- **Columnas**:
  1. `id`: Identificador único (Auto-incremental).
  2. `nombre`: Nombre completo del usuario.
  3. `correo`: Email de acceso (Llave primaria lógica, siempre `lc()`).
  4. `clave`: Hash SHA-256 de la contraseña.
  5. `activo`: `1` (Activo), `0` (Pendiente/Bloqueado).
  6. `rol`: `Medico`, `Paciente`, `Administrador`, `Asistente`.
  7. `id_negocio`: ID de vinculación con `negocios.dat` o `extra` (empresa:sucursal).
  8. `id_espe`: ID de especialidad (del catálogo `especialidades.dat`, ej. `100` = Odontología, `5` = Medicina Familiar).
  9. `id_subespe`: ID de sub-especialidad (del catálogo `sub_especialidades.dat`, ej. `100.1` = Ortodoncia).
  10. `cedula`: Cédula profesional oficial del médico.
  11. `domicilio`: Domicilio / dirección del consultorio o establecimiento médico.
  12. `firma_url`: Identificador o URL de la firma digital del médico.

## Reglas de Integridad (v3.9.0)
- **Validación de Sesión**:- Todos los usuarios (excepto el SuperAdmin) deben estar rigurosamente vinculados a un ID de negocio válido en `negocios.dat`.
- Cualquier modificación a este archivo debe registrarse en el log del sistema para auditoría, ya que maneja identidades y permisos operativos de toda la plataforma.

### 🏗️ Arquitectura de Renderizado (Actualización Diamond Edition)
- **Interfaz y Sesión**: Los datos de perfil (Avatar UI) ahora adoptan estilos premium redondos (`ui-avatars.com`) inyectados dinámicamente en los Dashboards.
- **Roles en Exportaciones**: En DataTables o listados del CRM, la columna de Acciones se excluye de las rutinas de PDFMake e Impresión (Reglas de Exportación de `GUIA_ESTILO_SDM.md` Punto 7).
- **Normalización**: Las búsquedas por correo deben aplicar siempre `s/\s//g` y `lc()` antes de comparar.
