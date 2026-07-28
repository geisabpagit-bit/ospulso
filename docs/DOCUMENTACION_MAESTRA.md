# 📖 Documentación Maestra SDM v4.3.0
**Software Dental Mexicano - Diamond Edition (The Clinical Standard)**

## 1. Visión v4.3.0 (Polymorphic Clinical & Financial Suite)
Esta versión consolida la madurez de la Suite Clínica y Financiera Privada. Se ha establecido una arquitectura SOAP polimórfica y multi-especialidad inviolable, un módulo de recetas médicas (NOM-024-SSA3) y consentimientos informados (NOM-004-SSA3) con firmas autógrafas/FIEL, gestión opcional de diagnósticos CIE-10/CIF, y un motor financiero flexible que permite cobro inmediato o diferido por recepción ("Cobro por recepción").

## 2. Componentes Críticos

### 2.1 Expediente Clínico Diamond (New)
- **Header Minimalista**: Cabecera (Hero) optimizada que muestra exclusivamente el nombre del paciente, maximizando el área de trabajo y reubicando las acciones principales.
- **Navegación Dock/Sidebar**: Sistema adaptativo que define el orden de pestañas: Citas, Consultas, Ficha, Finanzas, Odonto, Rayos X, Inbox.
- **Arquitectura Anidada (Mini-dock)**: Ficha Técnica, Clínico y SOAP comparten un mini-dock en su cabecera. Esto permite navegar entre ellos fluidamente como un sub-módulo e incluye acceso al Reporte y Guardado.
- **Micro-Interacciones**: Transiciones fluidas entre pestañas mediante el motor `swTab`.

### 2.2 CRM de Comunicaciones y Mensajería
- **Bitácora Inteligente**: Visualización cronológica de correos y notificaciones enviadas.
- **Detalle de Lectura**: Modal de lectura profunda con ID de registro, categoría y asunto.
- **Visor de Adjuntos (Previewer)**: Motor de previsualización integrado para imágenes (JPG/PNG) y documentos PDF sin salir de la plataforma.

### 2.3 Arquitectura "Escape" (Stacking Context Fix)
- **DOM Teleportation**: Los modales críticos se mueven automáticamente al `body` mediante JavaScript para evitar bloqueos por contenedores animados (`animate__fadeIn`).
- **Z-Index Layering**: Jerarquía estricta (Z=7000 para modales, 6900 para backdrops) para visibilidad garantizada en cualquier resolución.

### 2.4 Motor de Trazabilidad Clínica y Blindaje Legal (Agenda ↔ Consultas)
- **Separación de Responsabilidades**: Las citas (logística/calendario) viven en `dat/citas.dat` y las consultas médicas reales (acto clínico) viven en `dat/consultas_clinicas.dat`.
- **Hub de Consultas (`tab10`)**: Interfaz anidada en el expediente que consolida citas programadas por atender (detectando automáticamente citas Confirmadas, Programadas, o No Asistencias), atenciones express (walk-in) y el historial cronológico de notas médicas generadas.
- **Handshake de Estados**: Al finalizar una consulta, el sistema genera un ID único, empaqueta los datos en JSON, y cambia automáticamente el estado de la cita original en la agenda de "Programada" a "Realizada" (o "Atendida" en verde `#19B7A5`), creando un puente auditable perfecto.
- **Manejo de Citas Extemporáneas ("Tomar Cita")**: Permite al médico atender una cita pasada. El sistema verifica colisiones de horario en tiempo real y reubica la cita al horario actual asignando el estado especial `Atendida (Ext.)`.
- **Blindaje de Notas Médicas (Read-Only)**: Una vez finalizada una consulta, pasa al Historial Clínico. El sistema levanta un modal de "Solo Lectura" inmutable (evitando CRUD destructivo sobre el pasado), garantizando la integridad legal del expediente. Se incluye exportación e impresión del folio clínico.

### 2.5 Navegación Móvil Persistente (WebApp Style)
- **Bottom Navigation Bar (`sub_bottom_nav.pl`)**: Barra de navegación global fija al pie de la pantalla en dispositivos móviles, diseñada para emular la experiencia de una aplicación nativa.
- **Centralización Administrativa**: Integración directa del módulo de **Ajustes** en la barra de navegación, eliminando la redundancia de menús laterales y consolidando el control total del sistema en el pulgar del usuario.
- **Contexto Dinámico e Inteligente**: El menú se reconfigura según el módulo activo para priorizar acciones críticas:
  - **Contexto Pacientes**: Muestra `Inicio`, `+ Nuevo` (Registro rápido), `Citas` y `Ajustes`.
  - **Contexto Agenda**: Muestra `Inicio`, `Nueva Cita` (FAB destacado), `Pacientes` y `Ajustes`.
- **Blindaje de Posicionamiento**: Implementación de `position: fixed !important`, `z-index: 5500` y soporte para `safe-area-inset-bottom` para garantizar visibilidad total y compatibilidad con gestos de sistemas operativos modernos (iOS/Android).

### 2.6 Perfil Mutante & Cédula Profesional (Multi-Role Experience)
- **Interfaz Dinámica**: Unificación de la vista de perfil que alterna entre el Panel de Configuración del Negocio (para Médicos) y la Ficha Clínica Integral (para Pacientes) sin recargar la SPA.
- **Campo Cédula Profesional**: Exclusivo para el rol `Medico`, almacenado en el índice 9 de `usuarios.dat`. Se vincula automáticamente a la formalización de recetas médicas en el paso S.O.A.P. y a los endpoints de impresión PDF.

### 2.7 Blindaje Diamante de Suscripción
- **Acceso Condicional**: Capa de seguridad que invalida el acceso al sistema si el negocio asociado está marcado como inactivo o su fecha de suscripción ha expirado.
- **Garantía Operativa**: Verificación recursiva en el middleware de sesión, impidiendo que usuarios operen en clínicas con licencias vencidas.

### 2.8 Catálogos Oficiales Mandantes (Norma Oficial)
- **Integridad Referencial**: Los catálogos oficiales (ej. Localidades, Entidades, Formación Académica, CLUES) son de solo lectura (`.dat` delimitados). Garantizan la estandarización federal de los datos.
- **Implementación Híbrida UI/UX**: Se utilizan técnicas de **Databinding Unidireccional** (ej. Código Postal auto-llenando Entidad/Municipio) y **Autocomplete Nativo (Datalist)** (ej. Formación Académica) para manejar de forma eficiente miles de registros sin ralentizar la interfaz, inyectando silenciosamente las llaves primarias (`CATALOG_KEY`) hacia el backend.
- **Transaccionalidad Aislada**: Las selecciones de catálogos se almacenan en tablas relacionales uno-a-uno como `perfiles.dat` (para la metadata del Médico Especialista) o `negocios.dat` (para ubicaciones), preservando la ligereza de la tabla central `usuarios.dat`.

### 2.9 Arquitectura SOAP Polimórfica y Multi-Especialidad
- **Contrato JSON Canónico**: Toda consulta médica se serializa bajo las llaves canónicas SOAP (`subjective`, `objective`, `assessment`, `plan`). Los subformularios específicos por especialidad guardan sus variables dentro de `soap.objective.especialidad_data`.
- **Core Pipeline Único**: Flujo global 100% compartido (Paso 0 Registro, Agenda, Expediente, Firma y Cierre con Caja). Prohibido duplicar vistas completas por especialidad.
- **Plugin Slot**: Componentes modulares inyectados dinámicamente según la especialidad del médico tratante (ej. Odontograma SVG para Odontología `id_espe == 100`, con fallback a Signos Vitales).

### 2.10 Módulo de Recetas (NOM-024) y Consentimiento (NOM-004) con Firmas Digitales
- **Receta Médica Oficial**: Extracción de productos desde `dat/productos.dat`, dosificación, posología, folio de control de receta y datos oficiales del médico tratante (Nombre, Cédula Profesional, Domicilio).
- **Consentimiento Informado**: Blindaje legal en el paso de Comunicación. Generación de PDF e impresiones oficiales (`api/imprimir_receta_api.pl`, `api/imprimir_consentimiento_api.pl`).
- **Firma Autógrafa / FIEL**: Captura de firma digital en canvas (Pad), guardado en `uploads/firmas/*.png` y estructura lista para integración con Firma Electrónica Avanzada FIEL/e.firma.

### 2.11 Gestión Financiera Privada & "Cobro por Recepción"
- **Cobro Inmediato o Diferido**: En el Paso Caja Privada, el médico puede liquidar inmediatamente o delegar el cobro a recepción mediante la opción **"Cobro por recepción"**.
- **Consolidación de Cargos/Abonos**: Cuando se elige "Cobro por recepción", `cerrar_consulta_privado.pl` registra el **Cargo** de la consulta ($500 base o ítems seleccionados) con un **Abono de $0.00**, dejando el saldo pendiente para ser cobrado por un `Recepcionista`.
- **Protección de Saldo Negativo**: Si el médico aplica un abono directo en consulta sin cotización previa, el backend genera automáticamente el cargo por "Consulta Médica" por igual monto, evitando saldos negativos en el estado de cuenta.

## 3. Guía de Arquitectura
- **Backend**: Perl Modular con procesamiento de adjuntos en `/dat/adjuntos_crm/` y firmas en `/uploads/firmas/`.
- **Frontend**: SPA con Vanilla JS, Bootstrap 5 y Animate.css.
- **Estilos (CSS)**: Estricta separación de estilos en archivos `.css` independientes, eliminando los bloques en línea en scripts `.pl`.
- **Seguridad**: Validación de sesión en tiempo real, cifrado SHA-256 y blindaje de suscripción circular.

## 5. Historial de Ajustes Técnicos Recientes (v4.3.0)
- **Cédula Profesional Sync**: Integración del campo Cédula Profesional en perfiles de médicos, formulario SOAP y generación de recetas.
- **Toggle Opcional CIE-10 / CIF**: Implementación del switch dinámico en el paso SOAP que habilita u oculta los buscadores CIE-10 y CIF sin exigir campos obligatorios cuando está apagado.
- **Cobro por Recepción**: Adición del estado financiero diferido en el Wizard de Caja para delegación de cobro a recepción.
- **Consolidación Financiera Auto-Cargo**: Generación automática de cargos por tarifa base de consulta ($500) para evitar saldos negativos.
- **Optimización Base64 a PNG**: Extracción de firmas digitales del JSON a imágenes PNG físicas en el servidor.
- **Hard Reset DB Update**: Inclusión de tablas clínicas (`consultas_clinicas.dat`, `recetas.dat`, `consentimientos.dat`) y la carpeta de firmas en la limpieza operativa del Administrador Global.
- **Auditoría UTF-8**: Estandarización de `use strict; use warnings; use utf8;` en todos los archivos parciales del Wizard de Consultas.

**Software Dental Mexicano - Diamond Edition v4.3.0**
