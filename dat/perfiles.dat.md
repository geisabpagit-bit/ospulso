# Schema: perfiles.dat

## Descripción
Tabla transaccional que funge como extensión directa ("uno a uno") de la tabla principal `usuarios.dat`. 
Contiene información profesional, académica y operativa específica de cada usuario, especialmente diseñada para los usuarios con rol de "Especialista" o "Médico". 
Esto permite evitar la saturación de la tabla de control de acceso (`usuarios.dat`) con campos clínicos o de metadata.

## Formato
Delimitado por `!`

## Columnas (Estructura Inicial)
1. **id**: Entero. Consecutivo y llave primaria (PK) del registro de perfil.
2. **id_usuario**: Entero. Llave foránea (FK) que referencia a la columna `id` de `usuarios.dat`.
3. **clave_formacion**: Cadena/Entero. Llave foránea (FK) que referencia a la columna `CATALOG_KEY` de `CAT_FORMACION.dat`. Determina la Formación Académica del médico. Si está vacío, significa que el usuario no ha especificado su formación académica.
4. **clave_nacionalidad**: Cadena (ISO-3). Llave foránea (FK) que referencia a la columna `CLAVE_NACIONALIDAD` de `CAT_NACIONALIDADES.dat`. Determina la nacionalidad del médico.
5. **clave_religion**: Cadena (6 dígitos). Llave foránea (FK) que referencia a la columna `CLAVE_RELIGION` de `CAT_RELIGION.dat`. Determina la religión del médico.

