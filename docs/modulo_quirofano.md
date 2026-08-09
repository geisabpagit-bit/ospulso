# Módulo Kanban de Quirófano

## 1. Arquitectura General
El módulo Kanban de Quirófano es una vista SPA dedicada a la gestión de intervenciones quirúrgicas y ambulatorias. Se encuentra disponible exclusivamente para los roles de **Médico**, **Enfermería** y **Administrador**.

### Ubicación
- **Vista**: `views/quirofano_kanban.pl`
- **Controlador API**: `api/quirofano_crud.pl`
- **Base de Datos (Origen)**: `dat/quirofano.dat`

## 2. Flujo de Estados
El paciente transita por 5 estados obligatorios dentro del bloque quirúrgico:
1. **Programada**: Paciente agendado pero que aún no se encuentra físicamente en preparación para el quirófano.
2. **Pre-Operatorio**: El paciente está en la sala de preparación, evaluado por anestesiología y/o enfermería (consentimientos, signos).
3. **En Quirófano**: El paciente se encuentra dentro de la sala quirúrgica (procedimiento activo).
4. **Recuperación**: El paciente está en la Unidad de Cuidados Post Anestésicos (UCPA) o en observación ambulatoria.
5. **Alta**: El paciente ha sido dado de alta del bloque quirúrgico o trasladado a piso (hospitalización).

## 3. Omisión de Salas de Quirófano (Política de Implementación Temporal)
> [!NOTE]
> Hasta nuevo aviso, la figura física de "Sala / Quirófano" (Ej. Sala 1, Sala 2) ha sido **omitida** del agendamiento y de la tarjeta del Kanban.
> Esto obedece a que la gestión de infraestructura hospitalaria se diseñará posteriormente mediante un proceso de sincronización con sucursales y la configuración de `tipo_organizacion` (solo activo si es Hospital).
>
> Por el momento, la cirugía se agenda directamente sobre el bloque quirúrgico de la organización a la que el Médico pertenezca, asumiendo su disponibilidad.

## 4. Estándares Técnicos Móviles
La interfaz del Kanban implementa las normas de `css/sdm_mobile_standards.css` para aprovechar el 100% de la pantalla en dispositivos pequeños:
- `.container-mobile-flush` aplicado al contenedor principal.
- `.card-mobile-flush` aplicado a los modales.
- Botones amigables al tacto con `.btn-mobile-standard` combinados con `.btn-mobile-action` o `.btn-mobile-outline`.

## 5. Protocolo de Errores 500 y Sigilos de Perl
Para evitar colisiones entre el compilador de Perl y el parser de JavaScript:
- Se utilizan etiquetas separadoras `HTML` para los bloques de DOM puro y `JS` (con heredocs aislados por comillas simples `print <<'JS';`) para los bloques lógicos del Frontend.
- Los atributos HTML `data-*` son el vehículo de transmisión de estado del Backend al Frontend.
- Todas las salidas de vistas al STDOUT están forzadas a `binmode STDOUT, ":utf8";` para evitar truncamiento de acentos (Error 500 fatal).
