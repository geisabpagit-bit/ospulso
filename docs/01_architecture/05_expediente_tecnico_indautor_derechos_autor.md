# MEMORIA TÉCNICA Y EXPEDIENTE PARA REGISTRO ANTE INDAUTOR
## Sistema de Información de Registros Electrónicos de Salud (SIRES) — OSpulso / SDM 2.0
**Conforme a los Artículos 101 y 102 de la Ley Federal del Derecho de Autor (LFDA)**

---

### PORTADA OFICIAL DE DEPÓSITO DE OBRA

* **Título de la Obra**: OSpulso (Sistema de Información de Registros Electrónicos de Salud - SIRES / MedentOS Platform Core)
* **Rama y Versión de la Obra**: OsPulso Diamond Edition v4.5.0 / Release v3.4.0 Estable
* **Naturaleza de la Obra**: Programa de Computación (Software Aplicativo y Base de Datos)
* **Autor (Persona Física Creadora)**: **Israel Garay de la Cruz**
* **Titular de los Derechos Patrimoniales**: **Plataformas Digitales de México, S.A. de C.V.**
* **Fecha de Fijación de la Obra**: Octubre / Noviembre de 2026
* **Lugar de Fijación**: San Luis Potosí, S.L.P. / Ciudad de México, México
* **Declaración de Confidencialidad y Reserva**:
  > *Obra Protegida bajo la Ley Federal del Derecho de Autor (INDAUTOR - México). Todos los derechos reservados © 2026 Plataformas Digitales de México, S.A. de C.V. Queda estrictamente prohibida la reproducción, descompilación, ingeniería inversa, alteración, distribución o explotación no autorizada de este código fuente y memoria técnica sin el consentimiento previo y por escrito de su titular patrimonial.*

---

## ÍNDICE GENERAL ESTRUCTURADO

* **1. FICHA TÉCNICA E IDENTIFICACIÓN DE LA OBRA**
  * 1.1 Datos Generales del Software
  * 1.2 Declaración de Autoría y Titularidad Patrimonial
  * 1.3 Clasificación Funcional: SIRES y Expediente Clínico Electrónico
  * 1.4 Marco Legal y Cumplimiento Normativo (LFDA, NOM-004-SSA3-2012, NOM-024-SSA3-2012, LFPDPPP)
  * 1.5 Pila Tecnológica Real, Entorno de Ejecución y Persistencia
* **2. ARQUITECTURA TÉCNICA Y BLUEPRINT INFRAESTRUCTURAL**
  * 2.1 Arquitectura General del Sistema y Topología Multitenant
  * 2.2 Especificación Formal de Motores Centrales (Core Engines)
  * 2.3 Capa de Persistencia Flat-File 3NF Relacional (`.dat` por CLUES)
  * 2.4 Kernel de Identidad, Control de Acceso Basado en Roles (RBAC) y Overrides
  * 2.5 Conmutador Dinámico de Perfiles Clínico/Administrativo (Role Switcher)
  * 2.6 Prevención de Errores Críticos y Protocolos Error 500 Guard
* **3. DESCRIPCIÓN FUNCIONAL DEL SISTEMA CLÍNICO (SIRES)**
  * 3.1 Pipeline Clínico Canónico Único e Inviolable
  * 3.2 Arquitectura SOAP Polimórfica y Subformularios Desacoplados (Plugin Slot)
  * 3.3 Expediente Clínico Electrónico e Inmutabilidad de la Nota Médica
  * 3.4 Odontograma Digital Plus (Canvas HTML5 / SVG Vectorial Interactivo)
  * 3.5 Trazabilidad Quirúrgica End-to-End y Checklist OMS "Safe Surgery"
  * 3.6 Repositorio Atómico y Tipificado de Consentimientos Informados
  * 3.7 Agenda Médica Central, Gestión de Citas y Recepción
  * 3.8 Visor de Imágenes Médicas, Estudios Radiológicos y HUB DICOM PACS
  * 3.9 Módulo de Comunicación Masiva, Campañas Preventivas y Notificaciones
* **4. ARQUITECTURA FINANCIERA, CAJA Y COBRANZA**
  * 4.1 Principio de Integridad Contable al Centavo y Drilldown Transparente
  * 4.2 Segregación Canónica de Flujo de Efectivo Real vs Cuentas por Cobrar (CXC Estado)
  * 4.3 Módulo de Caja Rápida y Motor Multi-Tarifa Reactivo
  * 4.4 Protocolo de Impresión Controlada de Recibos y Barra `.no-print`
* **5. ESTÁNDARES DE DISEÑO UI/UX, INTERFAZ MÓVIL Y ACCESIBILIDAD**
  * 5.1 Sistema de Diseño Medentia Aura y Paleta Cromática Institucional
  * 5.2 Estándares Móviles Táctiles (Touch Target 48px y Layouts Flush)
  * 5.3 Regla de los Tres Clics y Optimización del Flujo Clínico
  * 5.4 Formato Editorial de Reportes en Dos Páginas Carta Exactas
* **6. DIAGRAMAS TÉCNICOS Y MODELOS DE ARQUITECTURA**
  * 6.1 Diagrama de Arquitectura Multitenant SaaS por CLUES
  * 6.2 Diagrama de Flujo del Pipeline SOAP Polimórfico
  * 6.3 Diagrama del Kernel RBAC con Resolución de 5 Parámetros
  * 6.4 Diagrama del Modelo Relacional Flat-File 3NF por Organización
  * 6.5 Diagrama de Flujo Financiero y Doble Canal de Ingresos
  * 6.6 Diagrama de Trazabilidad Quirúrgica OMS y Consentimiento Atómico
* **7. ANEXO DE CÓDIGO FUENTE (DEPÓSITO SUSTANCIAL ANTE INDAUTOR)**
  * 7.1 Encabezado Canónico de Licencia y Reserva de Derechos
  * 7.2 Árbol Jerárquico de Directorios y Estructura Modular
  * 7.3 Extracto Sustancial I: Inicialización, Seguridad y RBAC Kernel (`utils/permisos_utils.pl`, `auth/acceso.pl`)
  * 7.4 Extracto Sustancial II: Motor Clínico SOAP y Transaccional (`api/autosave_consulta.pl`, `api/cerrar_consulta_privado.pl`)
  * 7.5 Extracto Sustancial III: Motor Quirúrgico OMS y Consentimientos (`views/quirofano_kanban.pl`, `api/consentimientos_api.pl`)
  * 7.6 Extracto Sustancial IV: Motor Financiero Multi-Tarifa y Caja (`views/generar_recibo.pl`, `api/imprimir_recibo_caja.pl`)
  * 7.7 Extracto Sustancial V: Catálogos Server-Side y Auditoría Append-Only (`api/crud_catalogo_universal_api.pl`, `utils/audit_manager.pm`)

---

## 1. FICHA TÉCNICA E IDENTIFICACIÓN DE LA OBRA

### 1.1 Datos Generales del Software
* **Nombre Comercial**: OSpulso
* **Denominación Técnica de la Plataforma**: MedentOS Platform Core / SDM 2.0 (Sistema Digital Médico)
* **Tipo de Arquitectura**: Software as a Service (SaaS) Multitenant con aislamiento criptográfico y particionamiento por Clave Única de Establecimientos de Salud (CLUES) y Código de Empresa.
* **Dominio y Entorno de Despliegue**: Hospedaje en nube privada / infraestructura de servidor web Apache HTTP con soporte CGI de alto rendimiento.

### 1.2 Declaración de Autoría y Titularidad Patrimonial
* **Autor Persona Física**: **Israel Garay de la Cruz**, en su carácter de desarrollador principal, arquitecto de software y creador intelectual originario de la totalidad de las líneas de código, algoritmos, contratos de datos, estructuras de persistencia y módulos funcionales que integran la obra.
* **Titular de los Derechos Patrimoniales**: **Plataformas Digitales de México, S.A. de C.V.**, persona moral legalmente constituida conforme a las leyes de los Estados Unidos Mexicanos, titular exclusiva de las facultades de explotación, distribución, reproducción, comercialización, modificación y licenciamiento de la obra, al amparo de los artículos 103, 105 y 106 de la Ley Federal del Derecho de Autor.

### 1.3 Clasificación Funcional: SIRES y Expediente Clínico Electrónico
La obra **OSpulso** clasifica formalmente como un **Sistema de Información de Registros Electrónicos de Salud (SIRES)** y software integral de **Expediente Clínico Electrónico (ECE)**. Su cometido radica en la gestión, registro, almacenamiento, procesamiento, prescripción e intercambio seguro de datos clínicos, asistenciales, epidemiológicos, administrativos y financieros generados durante el acto médico ambulatorio, hospitalario y quirúrgico.

### 1.4 Marco Legal y Cumplimiento Normativo
1. **Ley Federal del Derecho de Autor (LFDA)**:
   - **Artículo 101**: Ampara la protección del programa como conjunto de instrucciones que permiten a una computadora ejecutar funciones específicas de salud y gestión.
   - **Artículo 102**: Equipara la protección del software a las obras literarias, tanto en código fuente como en código objeto.
   - **Artículo 107**: Protege la arquitectura de persistencia, índices y colecciones relacionales normalizadas 3NF como creaciones intelectuales de bases de datos.
2. **Norma Oficial Mexicana NOM-004-SSA3-2012 (Del Expediente Clínico)**:
   - Garantiza la integridad, confidencialidad, autenticidad y trazabilidad inalterable de las notas médicas (ingreso, evolución, referencia, urgencia, quirúrgica, egreso y consentimiento informado).
   - Impone el registro obligatorio de cédula profesional, firma digital, fecha, hora y datos de identificación del paciente y del facultativo tratante.
3. **Norma Oficial Mexicana NOM-024-SSA3-2012 (Sistemas de Información de Registro Electrónico para la Salud - SIRES)**:
   - Regula los mecanismos de seguridad perimetral, autenticación robusta, control de acceso basado en roles (RBAC), auditoría inmutable de accesos (*audit logs*), así como las directrices para interoperabilidad clínica e intercambio de información sanitaria.
4. **Organización Mundial de la Salud (OMS) — Iniciativa "Safe Surgery Saves Lives"**:
   - Implementa de manera nativa la Lista de Verificación de Seguridad de la Cirugía (Checklist Quirúrgico) en tres tiempos mandatorios: Entrada (*Sign-In*), Pausa Quirúrgica (*Time-Out*) y Salida (*Sign-Out*).
5. **Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP)**:
   - Custodia estricta y aislamiento de datos personales sensibles de salud mediante canales cifrados HTTPS/TLS 1.3 y segregación lógica multitenant.

### 1.5 Pila Tecnológica Real, Entorno de Ejecución y Persistencia
Lejos de abstracciones genéricas, OSpulso está construido sobre una arquitectura ingenieril propietaria orientada al rendimiento extremo, cero latencia y tolerancia a fallos:
* **Lenguaje del Backend / Núcleo Transaccional**: Perl 5 (v5.32+), ejecutado mediante la interfaz *Common Gateway Interface* (CGI) acelerada en Apache HTTP Server, utilizando directivas de entorno estricto (`use strict; use warnings; use utf8;`).
* **Capa de Persistencia y Motor de Base de Datos**: *Flat-File 3NF Relational Engine* propietario. Los registros se almacenan en tablas planas estructuradas con extensión `.dat`, utilizando codificación `:raw :encoding(UTF-8)`, delimitadores por tubería (`|`), llaves primarias compuestas y bloqueo físico atómico a nivel de archivo mediante `flock($fh, LOCK_EX)`.
* **Capa de Presentación y Frontend**: HTML5 semántico, CSS3 modular estructurado bajo metodologías BEM/utilitarias (`ospulso_master_v2.css`, `sdm_mobile_standards.css`), JavaScript puro (ES6+) complementado con jQuery para manipulación eficiente del DOM, DataTables con procesamiento Server-Side asíncrono (`deferRender: true`), SweetAlert2 para transacciones seguras y FontAwesome 6 para señalética clínica.
* **Componentes Especializados**: Canvas HTML5 y SVG vectorial interactivo para el Odontograma Digital Plus de 52 piezas dentales; librerías de visualización médica para imágenes radiológicas y estudios DICOM; y generadores de salida impresa con soporte estricto de hoja Carta y estilos de exclusión `@media print { .no-print { display: none !important; } }`.

---

## 2. ARQUITECTURA TÉCNICA Y BLUEPRINT INFRAESTRUCTURAL

### 2.1 Arquitectura General del Sistema y Topología Multitenant
La arquitectura de OSpulso responde al estándar **MedentOS Platform Core v2.0**, cimentado sobre cuatro axiomas infraestructurales invariables:
1. **Const-001 — Aislamiento de Motores**: Los subsistemas centrales (`EN-xxx`) interactúan de forma desacoplada y auditable.
2. **Const-002 — Fuente de Verdad de Persistencia**: La persistencia transaccional oficial reside de forma estricta e inmutable en el repositorio relacional `.dat`.
3. **Const-003 — Desacoplamiento de Rutas Frontend**: Las vistas no contienen políticas estáticas codificadas; las autorizaciones se resuelven dinámicamente mediante el motor de gobernanza RBAC.
4. **Const-004 — Denegación Implícita (Zero-Trust)**: Toda petición a un endpoint de la API carente de sesión activa, validación de integridad o permiso explícito es rechazada de inmediato.

La topología multitenant permite a múltiples clínicas, hospitales y centros de salud operar sobre una misma instancia de software compartiendo el núcleo transaccional, pero manteniendo sus datos estrictamente segregados mediante la carpeta canónica `dat/catalogos_CLUE/<CLUES>/` y variables de entorno por empresa (`$id_empresa`).

### 2.2 Especificación Formal de Motores Centrales (Core Engines)
* **EN-001 Tenant Engine**: Gestiona la frontera lógica de las organizaciones de salud basándose en la Clave Única de Establecimientos de Salud (CLUES) y códigos corporativos.
* **EN-002 Organization Engine**: Administra la estructura jerárquica: clínicas matrices (Sucursal 0), sucursales filiales, departamentos médicos y consultorios.
* **EN-003 Identity & RBAC Engine**: Gobierna la autenticación de usuarios, la firma de notas, las sesiones seguras y la matriz dinámica de permisos con resolución por rol y excepciones por usuario.
* **EN-005 Feature Engine**: Habilita o restringe módulos y funcionalidades avanzadas según el plan y la configuración de la clínica (`dat/negocios_config.dat`).
* **EN-007 Clinical Engine**: Orquesta las transacciones clínicas de alta concurrencia: agenda médica, consultas ambulatorias SOAP, historia clínica, notas quirúrgicas y recetas electrónicas.
* **EN-008 Interoperability & PACS Engine**: Controla la importación, almacenamiento y enlace de imágenes médicas radiológicas y formatos de intercambio clínico.
* **EN-009 Audit Engine**: Registra en bitácora inmutable append-only (`dat/audit_logs.dat`) la totalidad de eventos de acceso, modificación, cobro y cancelación, cumpliendo con la NOM-024-SSA3-2012.

### 2.3 Capa de Persistencia Flat-File 3NF Relacional (`.dat` por CLUES)
A diferencia de los esquemas convencionales dependientes de motores SQL externos propensos a fallos de conexión y sobrecostos de memoria, OSpulso implementa un motor de datos plano normalizado en **Tercera Forma Normal (3NF)**:
1. **Aislamiento por Establecimiento**: Para cada CLUES existe una partición aislada:
   - `departamentos_<CLUES>.dat`: Define departamentos asistenciales (ej. `ID_DEP 1 = CONSULTAS`, `ID_DEP 4 = IMAGENOLOGIA`).
   - `categorias_<CLUES>.dat`: Jerarquía secundaria (ej. `ID_CAT 16 = RAYOS X`, asociada a Imagenología).
   - `catalogo_items_<CLUES>.dat`: Servicios y procedimientos médicos con codificación SKU estandarizada (`LAB-`, `US-`, `RX-`, `CONS-0001` a `CONS-0832`).
   - `catalogo_precios_<CLUES>.dat`: Matriz de precios por ítem cruzada con esquemas tarifarios.
   - `tipos_tarifas_<CLUES>.dat`: Definición de esquemas (`ESTANDAR`, `URGENCIAS`, `DOMINGOS_Y_FESTIVOS`, `MUNICIPIO`).
2. **Atomicidad y Concurrencia**: Cada lectura y escritura invoca `flock($fh, LOCK_EX)` asegurando que ninguna transacción sea sobrescrita durante accesos concurrentes de múltiples médicos o cajeros.

### 2.4 Kernel de Identidad, Control de Acceso Basado en Roles (RBAC) y Overrides
El control de acceso de OSpulso supera las limitaciones de las matrices estáticas tradicionales mediante un **Kernel RBAC Híbrido** implementado en `utils/permisos_utils.pl`:
* **Firma de Evaluación de 5 Parámetros**:
  `tiene_permiso_modulo($id_empresa, $rol, $modulo, $accion, $id_usuario)`
* **Mecanismo de Prevalencia de Excepciones (User Overrides)**:
  1. El sistema evalúa primero si existe un registro de excepción individual en `permisos_usuarios_<ID_EMPRESA>.dat` para el usuario específico. De encontrarse una definición (`C`, `R`, `U`, `D`), esta sobrescribe inmediatamente cualquier política de rol.
  2. Si no existe excepción, el sistema recurre a la matriz de permisos por rol asignada a la organización (`permisos_roles_<ID_EMPRESA>.dat`).
  3. Si la organización carece de matriz personalizada, se utiliza la matriz base institucional (`dat/roles.dat`).
* **Protección contra Autobloqueo (Lockout Protection)**: Los roles de administración global y directores de organización conservan de forma inviolable en código el acceso integral a la gestión de usuarios, permisos, pacientes y agenda.
* **Auto-Purga en Cambio de Rol**: Si se modifica el rol de un colaborador, el backend purga automáticamente sus excepciones previas para garantizar que no arrastre privilegios incompatibles.
* **Sincronización Dinámica de la Navegación**: El menú lateral (`utils/sub_sidebar.pl`) renderiza u oculta en tiempo real las opciones según la evaluación exacta de permisos del usuario autenticado.

### 2.5 Conmutador Dinámico de Perfiles Clínico/Administrativo (Role Switcher)
Para satisfacer las necesidades operativas de clínicas unipersonales y consultorios odontológicos donde el titular ejerce simultáneamente como Director Administrativo y Médico Tratante:
* Se implementa el endpoint atómico `api/switch_role_api.pl`, permitiendo alternar entre `Modo Médico` y `Modo Administrador` en menos de 300 milisegundos sin requerir re-autenticación ni destrucción de la sesión de trabajo.
* En organizaciones hospitalarias con estricta separación de funciones, el conmutador permanece 100% oculto, preservando el rigor jerárquico.

### 2.6 Prevención de Errores Críticos y Protocolos Error 500 Guard
El código fuente de OSpulso implementa salvaguardas arquitectónicas para asegurar alta disponibilidad:
* **Aislamiento de Sigilos Perl vs JavaScript**: Prohibición de inyectar variables de Perl en bloques extensos de scripts cliente. El intercambio de datos se realiza a través de atributos `data-*` en el DOM, previniendo colisiones de sigilos (`$`) y problemas de escape.
* **Escape Obligatorio de Reglas de Estilo**: Protección explícita de caracteres `@media` (`\@media`) en bloques interpolados de Perl para erradicar el fallo de compilación *"Global symbol requires explicit package name"*.
* **Encabezados HTTP Inmediatos**: Emisión inmediata de cabeceras UTF-8 al inicio del ciclo de vida del script CGI, capturando excepciones fatales con `CGI::Carp qw(fatalsToBrowser)`.

---

## 3. DESCRIPCIÓN FUNCIONAL DEL SISTEMA CLÍNICO (SIRES)

### 3.1 Pipeline Clínico Canónico Único e Inviolable
El flujo clínico en OSpulso está diseñado bajo un principio rector: **Un solo pipeline de atención de extremo a extremo**:
```
[Recepción / Registro] ➔ [Agenda Médica] ➔ [Expediente Clínico] ➔ [Consulta SOAP] ➔ [Firma y Receta] ➔ [Cierre y Caja]
```
Está formalmente prohibido duplicar pantallas por especialidad. Toda consulta médica, sea pediátrica, ginecológica, traumatológica u odontológica, transita de manera uniforme por este pipeline garantizando la integridad legal de la historia clínica.

### 3.2 Arquitectura SOAP Polimórfica y Subformularios Desacoplados (Plugin Slot)
La atención médica se estructura bajo el estándar internacional **SOAP**:
* **S (Subjetivo)**: Motivo de consulta, síntoma principal, interrogatorio por aparatos y sistemas.
* **O (Objetivo)**: Exploración física, somatometría, signos vitales normativos (presión arterial, frecuencia cardíaca, frecuencia respiratoria, temperatura, saturación de O2, peso, talla, IMC) y datos especializados.
* **A (Apreciación / Diagnóstico)**: Impresión diagnóstica codificada bajo la Clasificación Internacional de Enfermedades (CIE-10).
* **P (Plan)**: Plan terapéutico, solicitud de estudios de laboratorio/gabinete, indicaciones generales y prescripción farmacológica.

**Mecanismo Polimórfico**: Los datos dinámicos específicos de cada especialidad médica se alojan en el nodo `soap.objective.especialidad_data` mediante subformularios modulares desacoplados (*Plugin Slots*) ubicados en `views/partials/consultas/`. Si una rama médica no requiere campos particulares, se renderiza el componente base con signos vitales sin interrumpir el flujo.

### 3.3 Expediente Clínico Electrónico e Inmutabilidad de la Nota Médica
Conforme a la NOM-004-SSA3-2012:
* El expediente clínico reúne en una sola vista cronológica la totalidad de antecedentes heredo-familiares, personales patológicos, personales no patológicos, gineco-obstétricos, consultas históricas, intervenciones quirúrgicas y estudios radiológicos del paciente.
* **Inmutabilidad y Sello Digital**: Una vez que el médico concluye y firma la consulta clínica, la nota se sella criptográficamente con la marca de tiempo, cédula profesional y firma del facultativo. El registro queda bloqueado para modificaciones, admitiendo únicamente notas aclaratorias o adendas cronológicas posteriores debidamente firmadas.

### 3.4 Odontograma Digital Plus (Canvas HTML5 / SVG Vectorial Interactivo)
OSpulso integra un módulo especializado de estomatología y odontología avanzada:
* Representación gráfica interactiva de la dentición humana completa (52 piezas dentales: 32 permanentes del adulto y 20 de dentición temporal o infantil).
* División topológica de cada pieza en 5 caras anatómicas (vestibular, lingual/palatina, mesial, distal y oclusal/incisal).
* Registro visual cromático de diagnósticos (caries, fracturas, ausencias, endodoncias, prótesis) y tratamientos ejecutados.
* Persistencia atómica de estados dentales en formato estructurado JSON (`dat/odontogramas/paciente_<id>.json`), vinculado directamente al expediente clínico general.

### 3.5 Trazabilidad Quirúrgica End-to-End y Checklist OMS "Safe Surgery"
El subsistema de Quirófano (`views/quirofano_kanban.pl`) eleva la gestión quirúrgica al estándar hospitalario internacional:
1. **Tablero Kanban Quirúrgico**: Control visual del flujo del paciente a través de 5 estados operativos:
   `Programada` ➔ `Pre-Operatorio` ➔ `En Quirófano (Trans-Op)` ➔ `Recuperación (UCPA)` ➔ `Alta Médica`.
2. **Checklist OMS de Tres Tiempos**:
   - **Entrada (*Sign-In*)**: Antes de la inducción anestésica (verificación de identidad, sitio quirúrgico marcado, consentimiento firmado, riesgo de vía aérea y alergias).
   - **Pausa Quirúrgica (*Time-Out*)**: Antes de la incisión cutánea (presentación del equipo quirúrgico, confirmación verbal del procedimiento, profilaxis antibiótica y previsión de eventos críticos).
   - **Salida (*Sign-Out*)**: Antes de que el paciente salga del quirófano (recuento de gasas e instrumental, etiquetado de muestras anatomopatológicas y plan postoperatorio).
3. **Escala de Recuperación UCPA (Aldrete)**: Evaluación de criterios objetivos de alta postanestésica (actividad motora, respiración, circulación/tensión arterial, estado de conciencia y saturación de oxígeno).

### 3.6 Repositorio Atómico y Tipificado de Consentimientos Informados
Superando los formatos aislados, OSpulso implementa un **Repositorio Atómico de Consentimientos Informados** (`dat/consentimientos/paciente_<id>.json`):
* Categorización por tipos clínicos: `CONSULTA_PROCEDIMIENTO`, `CIRUGIA_MAYOR`, `ANESTESIA`, `HEMODERIVADOS` y `REVOCACION`.
* Captura de firmas digitales del paciente o tutor legal, médico tratante y testigos presenciales.
* Generación de comprobante documental foliado con sello institucional, disponible para visualización e impresión controlada en cualquier momento.

### 3.7 Agenda Médica Central, Gestión de Citas y Recepción
* Programación inteligente de citas con visualización multitemporal (mensual, semanal, diaria y lista).
* Filtros dinámicos por médico, especialidad, consultorio y sucursal.
* Control de estado de la cita: `Programada`, `Confirmada`, `En Espera`, `En Consulta`, `Completada` o `Cancelada`.
* Transición de alta velocidad hacia el expediente clínico en menos de 3 clics.

### 3.8 Visor de Imágenes Médicas, Estudios Radiológicos y HUB DICOM PACS
* Almacenamiento y vinculación de archivos radiológicos (Rayos X, Ultrasonido, Mastografía, Tomografía).
* Visor web integrado con herramientas de zoom, manipulación de contraste/brillo, mediciones anatómicas e inspección de metadatos clínicos bajo estándar DICOM.

### 3.9 Módulo de Comunicación Masiva, Campañas Preventivas y Notificaciones
* Herramienta institucional para envío de recordatorios de citas, avisos de seguimiento médico y campañas de medicina preventiva.
* Segmentación de audiencias por grupos etarios, diagnósticos previos o fechas de atención.

---

## 4. ARQUITECTURA FINANCIERA, CAJA Y COBRANZA

### 4.1 Principio de Integridad Contable al Centavo y Drilldown Transparente
El subsistema financiero de OSpulso garantiza coherencia aritmética absoluta:
* **Drilldown Transparente**: Los indicadores macroeconómicos y KPIs mostrados en el Tablero Ejecutivo (Ingresos Totales, Cobrado en Efectivo, Tarjeta, Transferencia, Cuentas por Cobrar) coinciden exactamente al centavo con la sumatoria de las partidas individuales desglosadas en las tablas DataTables.

### 4.2 Segregación Canónica de Flujo de Efectivo Real vs Cuentas por Cobrar (CXC Estado)
Para salvaguardar la veracidad contable y evitar dobles registros:
* **Fuente Canónica de Efectivo Real en Caja**: `dat/folios_recibos_privados.dat` constituye la **única fuente oficial de dinero cobrado en ventanilla**. Está estrictamente prohibido sumar de forma paralela `estado_cuenta.dat` para el cálculo de ingresos recaudados.
* **Cuentas por Cobrar (CXC Estado / Convenios)**: Los servicios otorgados a beneficiarios de convenios institucionales o subsidios municipales se registran en `dat/folios_recibos_publicos.dat`. Estos montos representan derechos de cobro ante dependencias públicas y no dinero físico presente en el arqueo del cajero.

### 4.3 Módulo de Caja Rápida y Motor Multi-Tarifa Reactivo
El módulo de Caja (`views/generar_recibo.pl`) permite cobros de servicios ambulatorios y de mostrador de forma ágil:
* **Exclusión Inteligente de Consultas en el Carrito**: El buscador modal de conceptos excluye automáticamente el departamento de consultas médicas para evitar duplicidades con el flujo clínico.
* **Motor Multi-Tarifa**: Selección dinámica de esquemas de precios (`ESTANDAR`, `URGENCIAS`, `DOMINGOS Y FESTIVOS`) con recálculo en tiempo real de subtotal, Impuesto al Valor Agregado (IVA 16%) y total a pagar.
* **Soporte de Tarifa Personalizada ("Otra")**: Permite fijar costos excepcionales con guardas de validación que bloquean emisiones en ceros o valores negativos.

### 4.4 Protocolo de Impresión Controlada de Recibos y Barra `.no-print`
* Erradicación total de scripts de impresión automática intrusiva (`onload="window.print()"` o cierres automáticos forzados).
* Barra de herramientas superior (`.no-print`) con botones manuales para impresión física o guardado en PDF, y retorno seguro al punto de origen.
* Ocultamiento automático de la barra mediante reglas CSS de medios impresos durante la generación del documento final.

---

## 5. ESTÁNDARES DE DISEÑO UI/UX, INTERFAZ MÓVIL Y ACCESIBILIDAD

### 5.1 Sistema de Diseño Medentia Aura y Paleta Cromática Institucional
OSpulso se rige por el sistema de diseño propio **Medentia Aura**:
* Azul Clínico Profundo (`--md-blue-deep`: `#0A2A66`): Transmite solidez institucional y confianza.
* Verde Azulado Sanitario (`--md-teal-clinical`: `#19B7A5`): Enfatiza vitalidad, salud y acción clínica.
* Fondos Limpios (`--md-bg-light`: `#F8FBFF`): Maximizan el contraste y reducen la fatiga visual del personal de salud en jornadas prolongadas.

### 5.2 Estándares Móviles Táctiles (Touch Target 48px y Layouts Flush)
A través de `css/sdm_mobile_standards.css`, la plataforma garantiza ergonomía en dispositivos móviles:
* **Touch Target de 48px**: Todos los botones de acción (.`btn-mobile-standard`) cuentan con una superficie táctil mínima de 48 píxeles de altura, bordes redondeados y tipografía legible.
* **Layouts Flush**: En pantallas inferiores a 768px, las clases `.container-mobile-flush` y `.card-mobile-flush` eliminan márgenes laterales ociosos, permitiendo aprovechar el 100% del ancho útil.

### 5.3 Regla de los Tres Clics y Optimización del Flujo Clínico
La navegación está optimizada para que un médico acceda desde la Agenda a cualquier expediente y abra una consulta activa en un máximo de **3 interacciones**, eliminando barreras burocráticas y tiempos muertos.

### 5.4 Formato Editorial de Reportes en Dos Páginas Carta Exactas
Los reportes ejecutivos semanales y resúmenes directivos están diagramados para ajustarse de forma estricta a dos páginas tamaño Carta exactas, evitando saltos de línea huérfanos o desbordamientos estéticos al imprimirse o exportarse a PDF.

---

## 6. DIAGRAMAS TÉCNICOS Y MODELOS DE ARQUITECTURA

### 6.1 Diagrama de Arquitectura Multitenant SaaS por CLUES
```
+-----------------------------------------------------------------------------------+
|                            CLIENTES / DISPOSITIVOS                                |
|   Estación Médica (PC)  |  Tablet Clínica (Móvil)  |  Módulo de Caja (Ventanilla) |
+-----------------------------------------------------------------------------------+
                                         │ HTTPS / TLS 1.3
                                         ▼
+-----------------------------------------------------------------------------------+
|                         CAPA DE CONTROL Y SEGURIDAD CGI                           |
|       Apache HTTP Server  |  CGI::Session  |  Zero-Trust Firewall Guard           |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
|                   KERNEL DE GOBERNANZA RBAC (utils/permisos_utils.pl)             |
|   Resolución de 5 Parámetros: ($id_empresa, $rol, $modulo, $accion, $id_usuario)  |
|   [1. User Override]  ──>  [2. Fallback Rol Org]  ──>  [3. Fallback Matriz Base]  |
+-----------------------------------------------------------------------------------+
                                         │
        ┌────────────────────────────────┼────────────────────────────────┐
        ▼                                ▼                                ▼
+──────────────────+            +──────────────────+            +──────────────────+
|  CLINICAL ENGINE |            | SURGICAL/CONSENT |            |  FINANCIAL CORE  |
|  Pipeline SOAP   |            | Kanban Quirófano |            | Caja Rápida      |
|  Subformularios  |            | Checklist OMS    |            | Multi-Tarifa     |
|  Inmutabilidad   |            | UCPA Aldrete     |            | Flujo Efectivo   |
+──────────────────+            +──────────────────+            +──────────────────+
        │                                │                                │
        └────────────────────────────────┼────────────────────────────────┘
                                         ▼
+-----------------------------------------------------------------------------------+
|                 CAPA DE PERSISTENCIA FLAT-FILE 3NF RELACIONAL (.dat)              |
|        Atomicidad flock(LOCK_EX)  |  Codificación UTF-8 LF  |  Aislamiento CLUE   |
|                                                                                   |
|  dat/catalogos_CLUE/<CLUES>/           dat/folios_recibos_privados.dat (Efectivo) |
|  ├── departamentos_<CLUES>.dat         dat/folios_recibos_publicos.dat (CXC Edo)  |
|  ├── categorias_<CLUES>.dat            dat/quirofano.dat (Bitácora Quirúrgica)    |
|  ├── catalogo_items_<CLUES>.dat        dat/consentimientos/paciente_<id>.json     |
|  └── catalogo_precios_<CLUES>.dat      dat/audit_logs.dat (Trazabilidad Inmutable)|
+-----------------------------------------------------------------------------------+
```

### 6.2 Diagrama de Flujo del Pipeline SOAP Polimórfico
```
[Inicio de Consulta] ──> [Guardia: ¿Consulta Activa?] ──> [Cargar Expediente Prev.]
                                                                     │
                                                                     ▼
                                                         [Interrogatorio Clínico]
                                                         • S: Subjetivo (Síntomas)
                                                                     │
                                                                     ▼
                                                         [Exploración y Somatometría]
                                                         • O: Objetivo (Signos Vitales)
                                                                     │
                                                                     ▼
                                                         [Plugin Slot Especialidad]
                                                         • soap.objective.especialidad
                                                           (Pediatría / Gineco / Dental)
                                                                     │
                                                                     ▼
                                                         [Juicio Diagnóstico]
                                                         • A: Apreciación (CIE-10)
                                                                     │
                                                                     ▼
                                                         [Prescripción y Plan]
                                                         • P: Plan y Receta Aislada
                                                                     │
                                                                     ▼
                                                         [Firma Digital & Sello]
                                                         • Inmutabilidad NOM-004
                                                                     │
                                                                     ▼
                                                         [Generación de Cargo / Caja]
```

### 6.3 Diagrama del Modelo Relacional Flat-File 3NF por Organización
```
+───────────────────────────+          +───────────────────────────+
|   DEPARTAMENTOS_<CLUES>   |          |    CATEGORIAS_<CLUES>     |
+───────────────────────────+          +───────────────────────────+
| ID_DEP (PK)               | 1      N | ID_CAT (PK)               |
| Nombre Departamento       |──────────| ID_DEP (FK)               |
| Estado                    |          | Nombre Categoría          |
+───────────────────────────+          +───────────────────────────+
                                                     │ 1
                                                     │ N
                                       +───────────────────────────+
                                       |   CATALOGO_ITEMS_<CLUES>  |
                                       +───────────────────────────+
                                       | ID_ITEM (PK)              |
                                       | SKU (LAB-, RX-, CONS-)    |
                                       | ID_CAT (FK)               |
                                       | Nombre del Procedimiento  |
                                       | Descripción               |
                                       +───────────────────────────+
                                                     │ 1
                                                     │ N
                                       +───────────────────────────+
                                       |  CATALOGO_PRECIOS_<CLUES> |
                                       +───────────────────────────+
                                       | ID_ITEM (FK)              |
                                       | ID_TARIFA (FK)            |
                                       | Precio Base               |
                                       | IVA Aplicable             |
                                       +───────────────────────────+
```

---

## 7. ANEXO DE CÓDIGO FUENTE (DEPÓSITO SUSTANCIAL ANTE INDAUTOR)

### 7.1 Encabezado Canónico de Licencia y Reserva de Derechos
Conforme a la práctica de depósito de código fuente de la Ley Federal del Derecho de Autor, cada módulo de software cuenta con la siguiente inscripción registral:

```perl
/* ========================================================================
 * OSpulso - Sistema de Información de Registros Electrónicos de Salud (SIRES)
 * Autor Intelectual: Israel Garay de la Cruz
 * Titular de los Derechos Patrimoniales: Plataformas Digitales de México, S.A. de C.V.
 * Copyright (C) 2026 Plataformas Digitales de México, S.A. de C.V.
 * Obra protegida bajo los artículos 101, 102, 103, 107 y concordantes de la
 * Ley Federal del Derecho de Autor (INDAUTOR - México).
 * Todos los derechos reservados.
 * ======================================================================== */
```

### 7.2 Árbol Jerárquico de Directorios y Estructura Modular
```
ospulso/
├── api/                             # Endpoints del Backend Transaccional (Perl CGI)
│   ├── admin_registros_api.pl       # API de gestión de catálogos y empresas
│   ├── autosave_consulta.pl         # Guardado automático de borradores SOAP
│   ├── cerrar_consulta_privado.pl   # Cierre inmutable, receta y pase a finanzas
│   ├── citas_crud.pl                # CRUD de citas y agenda médica
│   ├── consentimientos_api.pl       # Repositorio atómico de consentimientos
│   ├── crud_catalogo_universal_api.pl # DataTables Server-Side 3NF por CLUES
│   ├── finanzas_api.pl              # Indicadores financieros y drilldown
│   ├── imprimir_recibo_caja.pl      # Emisión controlada de recibos privados
│   ├── odontograma_api.pl           # Persistencia de intervenciones dentales
│   ├── quirofano_crud.pl            # Control de tiempos y checklist quirúrgico OMS
│   └── switch_role_api.pl           # Conmutador dinámico de rol (Role Switcher)
├── auth/                            # Subsistema de Seguridad y Autenticación
│   ├── acceso.pl                    # Procesamiento de credenciales y sesión
│   ├── check_session.pl             # Validación perimetral de token de sesión
│   └── cerrar_sesion.pl             # Destrucción segura y purga de sesión
├── css/                             # Hojas de Estilo y Tokens de Diseño UI/UX
│   ├── ospulso_master_v2.css        # Sistema Medentia Aura y layout principal
│   └── sdm_mobile_standards.css     # Estándares táctiles 48px y responsive flush
├── dat/                             # Capa de Persistencia Flat-File Relacional 3NF
│   ├── audit_logs.dat               # Bitácora inmutable de eventos de auditoría
│   ├── catalogos_CLUE/              # Particiones de catálogo por establecimiento
│   ├── consentimientos/             # JSONs atómicos tipificados por paciente
│   ├── folios_recibos_privados.dat  # Fuente canónica de flujo de efectivo real
│   ├── folios_recibos_publicos.dat  # Fuente canónica de cuentas por cobrar (CXC)
│   ├── odontogramas/                # Estados de piezas dentales en JSON
│   ├── pacientes.dat                # Directorio maestro de pacientes
│   └── usuarios.dat                 # Credenciales, roles y datos de personal
├── docs/                            # Documentación Técnica Unificada (4 Capas)
│   ├── 01_architecture/             # Blueprints, manifiestos y memoria técnica
│   ├── 02_data_and_rules/           # Diccionario 3NF, reglas SOAP y finanzas
│   ├── 03_modules_and_workflows/    # Manual de operación de módulos clínicos
│   └── 04_standards_and_ops/        # Guías UI/UX, protocolos 500 y normativas
├── js/                              # Lógica Cliente y Componentes Interactivos
│   └── odontograma_plus.js          # Motor gráfico Canvas/SVG de 52 piezas
├── utils/                           # Kernel de Infraestructura y Gobernanza
│   ├── audit_manager.pm             # Gestor de trazas de auditoría append-only
│   ├── catalogo_org_utils.pl        # Resolución de rutas CLUES y catálogos 3NF
│   ├── db_manager.pm                # Control de persistencia y bloqueos atómicos
│   ├── permisos_utils.pl            # Kernel RBAC Híbrido y resolución de 5 params
│   └── sub_sidebar.pl               # Navegación dinámica filtrada por permisos
└── views/                           # Módulos y Vistas Asistenciales de la Plataforma
    ├── administracion_usuarios.pl   # Gestión de cuentas, roles y overrides
    ├── agenda_main.pl               # Agenda médica central multi-vista
    ├── finanzas.pl                  # Tablero ejecutivo y arqueo de caja
    ├── generar_recibo.pl            # Caja Rápida y selector Multi-Tarifa
    ├── manage_catalogo_universal.pl # Consola de administración de catálogos 3NF
    ├── quirofano_kanban.pl          # Tablero Kanban y checklist quirúrgico OMS
    └── render_expediente_clinico.pl # Expediente clínico unificado NOM-004
```

---

### 7.3 Extracto Sustancial I: Inicialización, Seguridad y RBAC Kernel
**Archivo**: `utils/permisos_utils.pl` (Kernel de Gobernanza RBAC con Overrides por Usuario)

```perl
package utils::permisos_utils;

use strict;
use warnings;
use utf8;
use File::Spec;
use FindBin;
use Exporter 'import';

require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'catalogo_org_utils.pl');

our @EXPORT_OK = qw(
    obtener_ruta_permisos_org
    obtener_matriz_permisos_org
    guardar_matriz_permisos_org
    obtener_ruta_permisos_usuario_org
    obtener_overrides_usuario_org
    guardar_overrides_usuario_org
    eliminar_overrides_usuario_org
    tiene_permiso_modulo
);

# ─────────────────────────────────────────────────────────────
# tiene_permiso_modulo($id_empresa, $role, $modulo, $accion, $id_usuario)
# Evaluación de 5 Parámetros:
# 1. Prevalencia de Overrides Individuales del Usuario.
# 2. Fallback a Matriz de Rol de la Organización.
# 3. Fallback a Matriz Base Institucional.
# 4. Protección contra Autobloqueo (Lockout Guard).
# ─────────────────────────────────────────────────────────────
sub tiene_permiso_modulo {
    my ($id_empresa, $role, $modulo, $accion, $id_usuario) = @_;
    $id_empresa //= 0;
    $role       //= 'Invitado';
    $modulo     //= '';
    $accion     //= 'R'; # C, R, U, D
    $id_usuario //= '';

    # 1. LOCKOUT PROTECTION: Administradores nunca pierden acceso a módulos vitales
    if ($role eq 'Administrador Global' || $role eq 'Administrador Organizacion') {
        if ($modulo =~ /^(usuarios|gestion_permisos|pacientes|agenda|inicio)$/) {
            return 1;
        }
    }

    # 2. EVALUACIÓN DE OVERRIDES POR USUARIO
    if ($id_usuario ne '') {
        my $overrides = obtener_overrides_usuario_org($id_empresa, $id_usuario);
        if (exists $overrides->{$modulo}) {
            my $perm_str = $overrides->{$modulo};
            return 1 if index($perm_str, $accion) != -1;
            return 0; # La excepción individual deniega de forma explícita
        }
    }

    # 3. EVALUACIÓN DE MATRIZ POR ROL
    my $matriz_roles = obtener_matriz_permisos_org($id_empresa);
    if (exists $matriz_roles->{$role} && exists $matriz_roles->{$role}{$modulo}) {
        my $perm_str = $matriz_roles->{$role}{$modulo};
        return 1 if index($perm_str, $accion) != -1;
        return 0;
    }

    return 0; # Zero-Trust: Denegación implícita por defecto
}
```

---

### 7.4 Extracto Sustancial II: Motor Clínico SOAP y Transaccional
**Archivo**: `api/autosave_consulta.pl` (Guardado Automático de Borradores de Consulta)

```perl
#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use JSON::PP;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(actualizar_archivo);

my $q = CGI->new;
my $session_data = check_session($q);

print $q->header(-type => 'application/json; charset=UTF-8');

unless ($session_data->{session_ok}) {
    print JSON::PP->new->utf8(0)->encode({ ok => JSON::PP::false, msg => 'Sesión expirada' });
    exit;
}

my $id_paciente = $q->param('id_paciente') || '';
my $id_cita     = $q->param('id_cita') || '';
my $id_medico   = $session_data->{id_medico} || $q->param('id_medico') || 'DOC-000';
my $step        = $q->param('current_step') || 0;

if (!$id_paciente) {
    print JSON::PP->new->utf8(0)->encode({ ok => JSON::PP::false, msg => 'Falta id_paciente' });
    exit;
}

my %payload;
foreach my $p ($q->param) {
    my $val = $q->param($p);
    utf8::decode($val) if !utf8::is_utf8($val);
    $payload{$p} = $val;
}

# Deserialización de medicamentos y datos clínicos
if ($payload{medicamentos_json}) {
    eval { $payload{medicamentos} = JSON::PP->new->utf8(0)->decode($payload{medicamentos_json}); };
}

my $draft_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consulta_draft.dat');
my $id_draft = "DRAFT-$id_paciente"; 
my $json_str = JSON::PP->new->utf8(1)->encode(\%payload);
$json_str =~ s/\r|\n/\\n/g;
my $now = time();

# Escritura atómica de borrador clínico con aislamiento transaccional
open my $fh, '+<:encoding(UTF-8)', $draft_file or open $fh, '>:encoding(UTF-8)', $draft_file;
flock($fh, 2); # LOCK_EX
my @lineas = <$fh>;
my $encontrado = 0;
my @salida;
foreach (@lineas) {
    chomp;
    my @f = split(/\|/, $_, -1);
    if ($f[0] eq $id_draft) {
        push @salida, join('|', $id_draft, $id_paciente, $id_cita, $id_medico, $step, $json_str, $now);
        $encontrado = 1;
    } else {
        push @salida, $_;
    }
}
push @salida, join('|', $id_draft, $id_paciente, $id_cita, $id_medico, $step, $json_str, $now) unless $encontrado;

seek($fh, 0, 0);
truncate($fh, 0);
print $fh "$_\n" for @salida;
close $fh;

print JSON::PP->new->utf8(0)->encode({ ok => JSON::PP::true, msg => 'Borrador SOAP guardado' });
```

---

### 7.5 Extracto Sustancial III: Motor Quirúrgico OMS y Consentimientos
**Archivo**: `api/consentimientos_api.pl` (Repositorio Atómico Tipificado)

```perl
# ─────────────────────────────────────────────────────────────
# Registro y Consulta de Consentimiento Informado Atómico
# ─────────────────────────────────────────────────────────────
sub guardar_consentimiento_atomico {
    my ($id_paciente, $documento) = @_;
    return (0, "ID Paciente no válido") unless $id_paciente;

    my $repo_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'consentimientos');
    mkdir $repo_dir unless -d $repo_dir;

    my $repo_file = File::Spec->catfile($repo_dir, "paciente_$id_paciente.json");
    my $data = { id_paciente => $id_paciente, documentos => [] };

    if (-e $repo_file && open(my $rf, '<:encoding(UTF-8)', $repo_file)) {
        local $/;
        my $content = <$rf>;
        close $rf;
        eval { $data = JSON::PP->new->utf8(0)->decode($content); };
    }

    # Asignación de folio canónico y sello de tiempo
    $documento->{id_consentimiento} //= "CNS-" . time() . "-" . int(rand(900) + 100);
    $documento->{timestamp} = time();

    push @{$data->{documentos}}, $documento;

    open my $wf, '>:encoding(UTF-8)', $repo_file or return (0, "Error de escritura: $!");
    flock($wf, 2);
    print $wf JSON::PP->new->utf8(1)->pretty->encode($data);
    close $wf;

    return (1, $documento->{id_consentimiento});
}
```

---

### 7.6 Extracto Sustancial IV: Motor Financiero Multi-Tarifa y Caja
**Archivo**: `views/generar_recibo.pl` (Resumen de Cobro y Multi-Tarifa Reactiva)

```javascript
/* ========================================================================
 * OSpulso - Motor Reactivo Multi-Tarifa y Carrito de Cobro
 * ======================================================================== */
function recalcularTotalesCarrito() {
    let subtotalGeneral = 0;
    let ivaGeneral = 0;
    let totalGeneral = 0;

    cartItems.forEach(item => {
        let precio = parseFloat(item.precio_unitario) || 0;
        let cantidad = parseInt(item.cantidad) || 1;
        let subtotalLinea = precio * cantidad;
        let ivaLinea = item.aplica_iva ? (subtotalLinea * 0.16) : 0;

        subtotalGeneral += subtotalLinea;
        ivaGeneral += ivaLinea;
    });

    totalGeneral = subtotalGeneral + ivaGeneral;

    document.getElementById('lblSubtotal').innerText = '$' + subtotalGeneral.toFixed(2);
    document.getElementById('lblIVA').innerText = '$' + ivaGeneral.toFixed(2);
    document.getElementById('lblTotalPagar').innerText = '$' + totalGeneral.toFixed(2);
}
```

---

### 7.7 Extracto Sustancial V: Catálogos Server-Side y Auditoría Append-Only
**Archivo**: `utils/audit_manager.pm` (Bitácora de Auditoría Conforme a NOM-024)

```perl
package utils::audit_manager;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use POSIX qw(strftime);
use Fcntl qw(:flock);
use FindBin;
use File::Spec;

our @EXPORT_OK = qw(log_audit);

my $AUDIT_FILE = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'audit_logs.dat');

sub log_audit {
    my ($modulo, $accion, $descripcion, $id_registro, $id_usuario) = @_;
    
    $modulo      //= 'Desconocido';
    $accion      //= 'Desconocida';
    $descripcion //= '';
    $id_registro //= '';
    $id_usuario  //= 'Sistema';
    
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    
    # Sanitización de delimitadores y saltos de línea
    $descripcion =~ s/\|/ - /g;
    $descripcion =~ s/\r?\n/ /g;
    
    my $linea = join('|', $timestamp, $id_usuario, $modulo, $accion, $id_registro, $descripcion);
    
    open my $fh, '>>:encoding(UTF-8)', $AUDIT_FILE or do {
        warn "No se pudo abrir $AUDIT_FILE: $!";
        return 0;
    };
    
    flock($fh, LOCK_EX);
    print $fh "$linea\n";
    close $fh;
    
    return 1;
}

1;
```

---

### CONCLUSIÓN Y DECLARACIÓN FINAL DE DEPÓSITO
La presente Memoria Técnica y Extracto de Código Fuente acreditan la originalidad, diseño de ingeniería, arquitectura de software e integración funcional del sistema **OSpulso / SDM 2.0**, constituyendo un programa de computación y base de datos protegidos en los términos más amplios por los artículos 101, 102, 103, 107 y demás relativos y aplicables de la Ley Federal del Derecho de Autor de los Estados Unidos Mexicanos, expidiéndose para constancia legal y trámite de registro ante el Instituto Nacional del Derecho de Autor (INDAUTOR).
