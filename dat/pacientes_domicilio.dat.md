# PACIENTES_DOMICILIO.DAT - Catálogo de Domicilios de Pacientes

## 1. Propósito
Almacenar la información estructurada de domicilio (CP, Entidad, Municipio, Colonia, Calle, Números Exterior e Interior) de los pacientes de forma desacoplada y normalizada sin alterar `pacientes.dat`.

## 2. Formato de Archivo
Archivo plano delimitado por tuberías (`|`) codificado en UTF-8.

## 3. Cabecera Exacta
`ID_PACIENTE|CP|ENTIDAD|MUNICIPIO|COLONIA|CALLE|NUM_EXT|NUM_INT|FECHA_ACTUALIZACION`

## 4. Ejemplo de Registro
`PAC1785021406|07500|Ciudad de México|Gustavo A. Madero|La Pradera|Av. Central|123|Depto 4B|2026-07-28 09:15:00`
