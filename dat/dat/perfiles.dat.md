# PERFILES.DAT - Catálogo de Perfiles Extendidos de Usuarios

## 1. Propósito
Almacenar la información complementaria de perfil de los usuarios del sistema (formación académica, nacionalidad, religión, cédula de especialidad, fotografía de avatar y firma digital autógrafa).

## 2. Formato de Archivo
Archivo plano delimitado por signo de exclamación (`!`) codificado en UTF-8.

## 3. Cabecera Exacta
`id!id_usuario!clave_formacion!clave_nacionalidad!clave_religion!cedula_especialidad!avatar_url!firma_url!fecha_actualizacion`

## 4. Descripción de Campos
- **id** → Identificador secuencial del registro de perfil.
- **id_usuario** → ID del usuario en `usuarios.dat`.
- **clave_formacion** → Clave de la formación académica en `CAT_FORMACION.dat`.
- **clave_nacionalidad** → Clave del país en `CAT_NACIONALIDADES.dat` (ej. `MEX`).
- **clave_religion** → Clave de la religión/credo en `CAT_RELIGION.dat`.
- **cedula_especialidad** → Número de Cédula de Especialidad Médica (si aplica).
- **avatar_url** → Ruta o nombre del archivo de fotografía/avatar de perfil en `uploads/avatars/`.
- **firma_url** → Ruta o nombre de la firma digitalizada transparente en `uploads/firmas/`.
- **fecha_actualizacion** → Timestamp de la última modificación (`YYYY-MM-DD HH:MM:SS`).

## 5. Ejemplo de Registro
`1!1020747209!1885!MEX!110103!CED-ESP-987654!avatar_1020747209.png!firma_1020747209.png!2026-07-31 13:30:00`
