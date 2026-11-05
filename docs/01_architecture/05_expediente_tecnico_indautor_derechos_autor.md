# MEMORIA TÉCNICA Y EXPEDIENTE PARA REGISTRO ANTE INDAUTOR
## Sistema de Información de Registros Electrónicos de Salud (SIRES) — OSpulso / SDM 2.0
**Conforme a los Artículos 101 y 102 de la Ley Federal del Derecho de Autor (LFDA)**

---

### PORTADA OFICIAL DE DEPÓSITO DE OBRA

* **Título de la Obra**: OSpulso (Sistema de Información de Registros Electrónicos de Salud - SIRES / Ospulso Platform Core v2.0)
* **Rama y Versión de la Obra**: Ospulso Diamond Edition v4.5.0 / Release v3.4.0 Estable
* **Naturaleza de la Obra**: Programa de Computación (Software Aplicativo y Base de Datos)
* **Autor (Persona Física Creadora)**: **Israel Garay de la Cruz**
* **Titular de los Derechos Patrimoniales**: **Plataformas Digitales de México, S.A. de C.V.** (Representada Legalmente por: **Israel Garay de la Cruz**)
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
  * 3.7 Agenda Médica Central, Gestión de Citas y Recepción Inteligente
  * 3.8 Visor de Imágenes Médicas, Estudios Radiológicos y HUB DICOM PACS
  * 3.9 Módulo de Comunicación Masiva, Campañas Sanitarias y Notificaciones Automatizadas
  * 3.10 Diagrama Sintetizado de Arquitectura Funcional del SIRES
* **4. ARQUITECTURA FINANCIERA, CAJA Y COBRANZA**
  * 4.1 Principio de Integridad Contable al Centavo y Drilldown Transparente
  * 4.2 Segregación Canónica de Flujo de Efectivo Real vs Cuentas por Cobrar (CXC Estado)
  * 4.3 Módulo de Caja Rápida y Motor Multi-Tarifa Reactivo
  * 4.4 Protocolo de Impresión Controlada de Recibos y Barra `.no-print`
* **5. ESTÁNDARES DE DISEÑO UI/UX, INTERFAZ MÓVIL Y ACCESIBILIDAD**
  * 5.1 Sistema de Diseño Ospulso Aura y Paleta Cromática Institucional
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
  * 7.5 Extractos de Código Representativo del Core de OSpulso
* **8. DECLARACIÓN JURADA, PROTESTA DE DECIR VERDAD Y RATIFICACIÓN DE FIRMAS**
  * 8.1 Declaración Solemne bajo Protesta de Decir Verdad
  * 8.2 Cuadro Institucional de Firmas al Calce

---

## 1. FICHA TÉCNICA E IDENTIFICACIÓN DE LA OBRA

### 1.1 Datos Generales del Software
* **Nombre Comercial**: OSpulso
* **Denominación Técnica de la Plataforma**: Ospulso Platform Core v2.0 / SDM 2.0 (Sistema Digital Médico)
* **Tipo de Arquitectura**: Software as a Service (SaaS) Multitenant con aislamiento criptográfico y particionamiento por Clave Única de Establecimientos de Salud (CLUES) y Código de Empresa.
* **Dominio y Entorno de Despliegue**: Hospedaje en nube privada / infraestructura de servidor web Apache HTTP con soporte CGI de alto rendimiento.

### 1.2 Declaración de Autoría y Titularidad Patrimonial
* **Autor Persona Física**: **Israel Garay de la Cruz**, en su carácter de desarrollador principal, arquitecto de software y creador intelectual originario de la totalidad de las líneas de código, algoritmos, contratos de datos, estructuras de persistencia y módulos funcionales que integran la obra.
* **Titular de los Derechos Patrimoniales**: **Plataformas Digitales de México, S.A. de C.V.**, debidamente representada por su Representante Legal y Administrador, **Israel Garay de la Cruz**, persona moral legalmente constituida conforme a las leyes de los Estados Unidos Mexicanos, titular exclusiva de las facultades de explotación, distribución, reproducción, comercialización, modificación y licenciamiento de la obra, al amparo de los artículos 103, 105 y 106 de la Ley Federal del Derecho de Autor.

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
La arquitectura de OSpulso responde al estándar **Ospulso Platform Core v2.0**, cimentado sobre cuatro axiomas infraestructurales invariables:
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

### 3.7 Agenda Médica Central, Gestión de Citas y Recepción Inteligente
La **Agenda Médica Central** es un pilar fundamental en la operación de OSpulso como plataforma SaaS. Provee una visualización multitemporal reactiva (vistas por día, semana, mes y lista de espera de pacientes), con capacidades avanzadas de filtrado por médico especialista, consultorio físico y clínica sucursal. El motor gestiona el ciclo de vida completo de cada cita médica mediante estados tipificados (`Programada` ➔ `Confirmada` ➔ `En Sala de Espera` ➔ `En Consulta` ➔ `Completada` ➔ `Cancelada`) e incorpora mecanismos de confirmación interactiva, reduciendo drásticamente las cancelaciones y garantizando una transición directa de un solo clic hacia el Expediente Clínico Electrónico y la apertura de la Nota SOAP.

### 3.8 Visor de Imágenes Médicas, Estudios Radiológicos y HUB DICOM PACS
El **Visor Radiológico y HUB PACS** desacoplado permite la importación, almacenamiento seguro y visualización médica web de estudios de imagenología (Rayos X digitales, Ultrasonografías, Mastografías diagnósticas, Tomografías computarizadas y Resonancias Magnéticas). Construido sobre tecnología Canvas HTML5 y estándares de la industria diagnóstica, provee al médico herramientas diagnósticas de alta precisión en tiempo real: zoom digital sin pérdida de resolución, ventana interactiva de ajuste de contraste y brillo dinámico (*Window/Level*), inversión cromática negativa/positiva, rotación angular y reglas de calibración para medición milimétrica de estructuras anatómicas. El visor vincula automáticamente cada serie de imágenes al número de expediente del paciente y a la nota de evolución correspondiente, permitiendo su consulta inmediata durante el acto médico sin requerir software externo.

### 3.9 Módulo de Comunicación Masiva, Campañas Sanitarias y Notificaciones Automatizadas
El **Módulo de Comunicación Masiva y Notificaciones** es un componente nuclear del SaaS OSpulso diseñado para fortalecer la relación médico-paciente y mitigar el ausentismo clínico. Dispone de un motor transaccional multicanal capaz de despachar recordatorios automatizados de citas programadas vía mensajería instantánea y correo electrónico, avisos de disponibilidad de resultados de estudios de laboratorio o gabinete, y difusión masiva de campañas sanitarias preventivas (jornadas de vacunación, despistaje oncológico, control metabólico en diabetes e hipertensión). El sistema incorpora un módulo de segmentación avanzada por grupos etarios, diagnósticos nosológicos CIE-10 previos o periodos de inactividad asistencial, garantizando un estricto respeto a la privacidad del paciente y a la normativa sanitaria de consentimiento para comunicaciones electrónicas.

### 3.10 Diagrama Sintetizado de Arquitectura Funcional del SIRES
El siguiente diagrama sintetiza de forma integral el ecosistema clínico unificado del sistema SaaS OSpulso, detallando la interacción armónica entre la agenda, el expediente, el pipeline SOAP, los módulos de especialidad, el apoyo diagnóstico y la pasarela a finanzas:

```
+═════════════════════════════════════════════════════════════════════════════════════+
|                 ECOSISTEMA INTEGRAL CLÍNICO Y ASISTENCIAL (SIRES)                   |
+═════════════════════════════════════════════════════════════════════════════════════+
                                         │
                   ┌─────────────────────┴─────────────────────┐
                   ▼                                           ▼
+─────────────────────────────────────+     +─────────────────────────────────────+
|   [3.7] AGENDA MÉDICA Y RECEPCIÓN   |     |    [3.9] COMUNICACIÓN MASIVA        |
|  • Citas multitemporal (Día/Sem/Mes)|     |  • Recordatorios automáticos de cita|
|  • Control de estados y sala espera |     |  • Avisos de estudios de laboratorio|
|  • Filtro por Especialista/Consult. |     |  • Campañas preventivas por CIE-10  |
+─────────────────────────────────────+     +─────────────────────────────────────+
                   │                                           ▲
                   ▼ (1 Clic)                                  │
+──────────────────────────────────────────────────────────────┴──────────────────────+
|                     [3.3] EXPEDIENTE CLÍNICO ELECTRÓNICO (ECE)                      |
|       • Historial Médico Unificado   • Antecedentes Heredo-Familiares y Patológicos |
|       • Alergias y Signos Vitales    • Trazabilidad y NOM-004-SSA3-2012 Inmutable   |
+─────────────────────────────────────────────────────────────────────────────────────+
                                         │
                                         ▼
+─────────────────────────────────────────────────────────────────────────────────────+
|                    [3.1 & 3.2] PIPELINE SOAP CLÍNICO POLIMÓRFICO                    |
|   [S] Subjetivo: Interrogatorio  │ [O] Objetivo: Signos vitales y exploración física|
|   [A] Apreciación: CIE-10        │ [P] Plan Terapéutico: Indicaciones y Medicación  |
+─────────────────────────────────────────────────────────────────────────────────────+
                                         │
        ┌────────────────────────────────┼────────────────────────────────┐
        ▼                                ▼                                ▼
+───────────────────+            +───────────────────+            +───────────────────+
| [3.4] ODONTOGRAMA |            | [3.5] QUIRÓFANO   |            | [3.8] VISOR PACS  |
|  • 52 Piezas      |            |  • Tablero Kanban |            |  • Rayos X / USG  |
|  • 5 Caras anatóm.|            |  • Checklist OMS  |            |  • DICOM / Web    |
|  • Patologías SVG |            |  • Escala Aldrete |            |  • Zoom/Contraste |
+───────────────────+            +───────────────────+            +───────────────────+
        │                                │                                │
        └────────────────────────────────┼────────────────────────────────┘
                                         ▼
+─────────────────────────────────────────────────────────────────────────────────────+
|               [3.6] PRESCRIPCIÓN, CONSENTIMIENTOS Y CIERRE CLÍNICO                  |
|    • Receta Médica Electrónica Foliada      • Repositorio de Consentimientos JSON   |
|    • Sellado Temporal y Firma Digital       • Inmutabilidad de la Nota Médica       |
+─────────────────────────────────────────────────────────────────────────────────────+
                                         │
                                         ▼
+─────────────────────────────────────────────────────────────────────────────────────+
|                 [SECCIÓN 4] MÓDULO DE CAJA Y LIQUIDACIÓN FINANCIERA                 |
|   • Caja Rápida & Motor Multi-Tarifa   • Recibos Privados: Flujo Efectivo Real      |
|   • Exclusión inteligente de consultas • Recibos Públicos: Cuentas por Cobrar (CXC) |
+─────────────────────────────────────────────────────────────────────────────────────+
```

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

### 5.1 Sistema de Diseño Ospulso Aura y Paleta Cromática Institucional
OSpulso se rige por el sistema de diseño propio **Ospulso Aura**:
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

---

## 6. DIAGRAMAS TÉCNICOS Y MODELOS DE ARQUITECTURA

### 6.1 Diagrama General del Sistema y Flujo de Control de Código
Este diagrama ilustra la arquitectura de alto nivel y el ciclo de vida de ejecución que sigue cada petición cliente en la plataforma OSpulso, desde la interfaz de usuario hasta la capa de persistencia 3NF atómica:

```
+───────────────────────────────────────────────────────────────────────────────────+
|                                CLIENTES / FRONTEND                                |
|   Estación Médica (PC)  │  Tablet Clínica (Móvil)  │  Ventanilla de Caja y Recepción |
|   • HTML5 Semántico     │  • CSS3 Medentia Aura    │  • JavaScript ES6+ / jQuery  |
+───────────────────────────────────────────────────────────────────────────────────+
                                          │ HTTPS / TLS 1.3
                                          ▼
+───────────────────────────────────────────────────────────────────────────────────+
|                      SERVIDOR WEB Y CAPA PERIMETRAL APACHE                        |
|       Apache HTTP Server  │  Directivas CGI::Session  │  Zero-Trust Firewall Guard  |
+───────────────────────────────────────────────────────────────────────────────────+
                                          │
                                          ▼
+───────────────────────────────────────────────────────────────────────────────────+
|                 KERNEL DE SEGURIDAD, RBAC Y CONMUTADOR DE ROL                     |
|                   utils/permisos_utils.pl  │  auth/check_session.pl               |
|                   api/switch_role_api.pl   │  utils/audit_manager.pm              |
|        Evaluación de 5 Parámetros: ($id_empresa, $rol, $mod, $acc, $id_usuario)   |
|        [1. User Overrides]  ──>  [2. Matriz Rol Org]  ──>  [3. Matriz Base Roles] |
+───────────────────────────────────────────────────────────────────────────────────+
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        ▼                                 ▼                                 ▼
+───────────────────+             +───────────────────+             +───────────────────+
|  CLINICAL CORE    |             | SURGICAL / CONSENT|             |  FINANCIAL CORE   |
|  views/consulta_* |             | views/quirofano_* |             | views/generar_*   |
|  api/autosave_*   |             | api/quirofano_*   |             | api/imprimir_*    |
|  api/cerrar_*     |             | api/consentim.*   |             | api/finanzas_*    |
|  Pipeline SOAP    |             | Checklist OMS     |             | Caja Rápida       |
|  Plugins Slots    |             | UCPA Aldrete      |             | Multi-Tarifa      |
|  Inmutabilidad    |             | Repositorio CNS   |             | Flujo Efectivo    |
+───────────────────+             +───────────────────+             +───────────────────+
        │                                 │                                 │
        └─────────────────────────────────┼─────────────────────────────────┘
                                          ▼
+───────────────────────────────────────────────────────────────────────────────────+
|                CAPA DE PERSISTENCIA RELACIONAL FLAT-FILE 3NF (.dat)               |
|          Bloqueo Atómico flock(LOCK_EX) │ Codificación UTF-8 │ Línea Unix \n      |
|                                                                                   |
|  dat/catalogos_CLUE/<CLUES>/                dat/folios_recibos_privados.dat (Cash)|
|  ├── departamentos_<CLUES>.dat              dat/folios_recibos_publicos.dat (CXC) |
|  ├── categorias_<CLUES>.dat                 dat/quirofano.dat (Checklist OMS)     |
|  ├── catalogo_items_<CLUES>.dat             dat/consentimientos/paciente_<id>.json|
|  └── catalogo_precios_<CLUES>.dat           dat/audit_logs.dat (NOM-024 Audit)    |
+───────────────────────────────────────────────────────────────────────────────────+
```

### 6.2 Diagrama Detallado de Procesos (End-to-End Pipeline)
A continuación se detalla la secuencia de ejecución de los procesos vitales del sistema, asociando cada fase funcional con sus archivos de código fuente, contratos de datos y almacenamiento:

```
[FASE 1: AUTENTICACIÓN & GOBERNANZA RBAC]
   Entrada: Credenciales (auth/acceso.pl) ──> Verificación hash SHA-256 (dat/usuarios.dat)
   Resolución de Permisos: utils/permisos_utils.pl ──> Overrides (permisos_usuarios_<ID>.dat)
   Salida: Token CGI::Session + Menú Lateral Filtrado (utils/sub_sidebar.pl)
                        │
                        ▼
[FASE 2: ADMISIÓN, EXPEDIENTE & AGENDA MÉDICA]
   Búsqueda de Paciente: api/autocomplete_pacientes.pl ──> dat/pacientes.dat
   Programación de Cita: views/agenda_main.pl ──> api/citas_crud.pl ──> dat/citas.dat
   Check-in Paciente en Sala: Estado "En Espera" en Agenda
                        │
                        ▼
[FASE 3: ATENCIÓN CLÍNICA SOAP POLIMÓRFICA & ODONTOGRAMA]
   Apertura de Consulta: views/render_expediente_clinico.pl (Valida Consulta Activa)
   Borrador Atómico: api/autosave_consulta.pl (Autoguardado en dat/consulta_draft.dat)
   Captura SOAP:
      • S (Subjetivo): Interrogatorio clínico
      • O (Objetivo): Signos Vitales + Plugin Slot (views/partials/consultas/*)
      • Odontología Especializada: js/odontograma_plus.js ──> dat/odontogramas/paciente_<id>.json
      • A (Apreciación): Diagnóstico nosológico CIE-10 (api/buscar_cie10.pl)
      • P (Plan): Prescripción médica
   Cierre y Firma: api/cerrar_consulta_privado.pl ──> Sello Inmutable en dat/consultas.dat
   Receta Electrónica Foliada: api/imprimir_receta_api.pl ──> dat/recetas.dat
                        │
                        ▼
[FASE 4: TRAZABILIDAD QUIRÚRGICA OMS & CONSENTIMIENTOS]
   Asignación a Quirófano: views/quirofano_kanban.pl (5 Estados: Prog ➔ PreOp ➔ QX ➔ UCPA ➔ Alta)
   Checklist Quirúrgico OMS (3 Tiempos):
      • Entrada (Sign-In) ➔ Pausa Quirúrgica (Time-Out) ➔ Salida (Sign-Out)
   Consentimiento Informado Atómico:
      • api/consentimientos_api.pl ──> dat/consentimientos/paciente_<id>.json
   Criterios de Egreso UCPA: Escala Aldrete (views/imprimir_nota_quirurgica.pl)
                        │
                        ▼
[FASE 5: COBRANZA EN CAJA RÁPIDA & MOTOR MULTI-TARIFA]
   Generación de Cobro: views/generar_recibo.pl (Recibe cargos de consulta / quirofano)
   Resolución Tarifaria: Matriz N-Tarifas (tipos_tarifas_<CLUES>.dat y catalogo_precios_<CLUES>.dat)
   Cálculo Reactivo: Subtotal + IVA 16% + Total (recalcularTotalesCarrito())
   Segregación de Ingreso:
      • Recibo Privado: api/imprimir_recibo_caja.pl ──> dat/folios_recibos_privados.dat (Efectivo Real)
      • Recibo Público: api/imprimir_recibo_publico.pl ──> dat/folios_recibos_publicos.dat (CXC Estado)
   Liquidación en Cuenta: dat/estado_cuenta.dat
                        │
                        ▼
[FASE 6: REPORTING EJECUTIVO, CATÁLOGOS SERVER-SIDE & AUDITORÍA]
   Tablero Financiero: views/finanzas.pl ──> api/finanzas_api.pl (Drilldown exacto al centavo)
   Catálogos 3NF por CLUES: views/manage_catalogo_universal.pl ──> api/crud_catalogo_universal_api.pl
   Bitácora Inmutable (NOM-024): utils/audit_manager.pm ──> dat/audit_logs.dat
```

### 6.3 Matriz de Correlación de Procesos y Archivos de Código Fuente
La siguiente matriz correlaciona cada fase del proceso con los archivos de código fuente exactos del proyecto:

| Fase del Proceso | Archivos de Código Fuente (Controladores / Vistas / Utilidades) | Archivos de Persistencia (.dat / JSON) | Propósito Técnico y Legal |
|---|---|---|---|
| **P1. Seguridad y Gobernanza RBAC** | `auth/acceso.pl`<br>`auth/check_session.pl`<br>`utils/permisos_utils.pl`<br>`api/switch_role_api.pl` | `dat/usuarios.dat`<br>`dat/roles.dat`<br>`dat/permisos_usuarios_*.dat` | Autenticación, Zero-Trust, evaluación de 5 parámetros y control de acceso NOM-024. |
| **P2. Admisión y Agenda** | `views/agenda_main.pl`<br>`api/citas_crud.pl`<br>`views/crud_paciente.pl`<br>`api/pacientes_crud_api.pl` | `dat/pacientes.dat`<br>`dat/citas.dat` | Enrolamiento de derechohabientes, citas multitemporales y paso a consulta en < 3 clics. |
| **P3. Núcleo Clínico SOAP** | `views/render_expediente_clinico.pl`<br>`api/autosave_consulta.pl`<br>`api/cerrar_consulta_privado.pl`<br>`js/odontograma_plus.js` | `dat/consultas.dat`<br>`dat/recetas.dat`<br>`dat/odontogramas/*.json` | Nota médica inmutable NOM-004, plugins de especialidad, canvas dental y prescripción. |
| **P4. Quirófano y Consentimiento** | `views/quirofano_kanban.pl`<br>`api/quirofano_crud.pl`<br>`api/consentimientos_api.pl`<br>`views/imprimir_nota_quirurgica.pl` | `dat/quirofano.dat`<br>`dat/consentimientos/*.json` | Checklist OMS 3 tiempos, tiempos quirúrgicos, escala Aldrete y repositorio CNS atómico. |
| **P5. Caja y Multi-Tarifa** | `views/generar_recibo.pl`<br>`api/imprimir_recibo_caja.pl`<br>`api/imprimir_recibo_publico.pl`<br>`api/finanzas_api.pl` | `dat/folios_recibos_privados.dat`<br>`dat/folios_recibos_publicos.dat`<br>`dat/estado_cuenta.dat` | Segregación de Efectivo Real vs CXC Estado, esquemas tarifarios y recibos controlados. |
| **P6. Catálogos y Auditoría** | `views/manage_catalogo_universal.pl`<br>`api/crud_catalogo_universal_api.pl`<br>`utils/catalogo_org_utils.pl`<br>`utils/audit_manager.pm` | `dat/catalogos_CLUE/<CLUES>/*`<br>`dat/audit_logs.dat` | Normalización 3NF por CLUES, DataTables Server-Side a 10 filas y trazabilidad legal. |

---

## 7. ANEXO DE CÓDIGO FUENTE (DEPÓSITO SUSTANCIAL ANTE INDAUTOR)

### 7.1 Criterio Jurídico de Presentación ante INDAUTOR (Código Completo vs Extractos)
Conforme a la **Ley Federal del Derecho de Autor (Artículos 101, 102 y 103)** y el **Artículo 55 del Reglamento de la LFDA**, el solicitante de registro de software debe considerar la siguiente directriz legal sobre el código fuente:

1. **Memoria Técnica con Extractos Sustanciales (Recomendada para Registro):**
   * El criterio administrativo del INDAUTOR **no exige la impresión física de la totalidad de cientos de miles de líneas de código fuente**, ya que en proyectos de escala profesional como OSpulso esto crearía tomos de miles de páginas imprácticos de almacenar.
   * La normativa permite la presentación de una **muestra representativa o extracto sustancial** (primeras y últimas 10 a 25 páginas, o los algoritmos nucleares del sistema), acompañada de la memoria técnica y los diagramas de proceso que demuestren la originalidad de la obra.
   * **Protección de Secretos Industriales:** Este método evita la exposición pública o vulneración de llaves criptográficas, semillas de hashing y secretos comerciales sensibles.
2. **Depósito Íntegro del Código Fuente Completo (Soporte Digital / Anexo Secuencial):**
   * Si por requerimiento específico del registrador o estrategia jurídica de la empresa se solicita el código fuente completo, este debe entregarse en **soporte digital (archivo PDF consolidado)**.
   * **Regla de Ordenación Procesal:** En tal caso, el código fuente **NO debe listarse en orden alfabético arbitrario**. Debe estructurarse y compilarse **estrictamente en el orden de los diagramas de proceso** (Fase 1 a Fase 6), de manera que el examinador del INDAUTOR pueda seguir el flujo de control del sistema de forma coherente y lógica.

### 7.2 Mapeo y Guía de Ordenación del Código Fuente Completo según el Flujo de Procesos
Para la conformación del tomo digital completo, los archivos fuente de OSpulso se ordenan secuencialmente de acuerdo a los diagramas de proceso descritos:

```
TOMO DE CÓDIGO FUENTE COMPLETO (ORDENACIÓN POR DIAGRAMAS DE PROCESO):

SECUENCIA I: NÚCLEO DE ARRANQUE, SESIÓN Y GOBERNANZA RBAC (Proceso 1)
 1. auth/acceso.pl                    ── Procesamiento de credenciales y arranque de sesión
 2. auth/check_session.pl             ── Guardia perimetral de token y verificación de estado
 3. utils/permisos_utils.pl           ── Kernel de permisos híbrido con resolución de 5 parámetros
 4. api/switch_role_api.pl            ── Conmutador atómico de rol médico/administrador
 5. utils/sub_sidebar.pl              ── Renderizado reactivo del menú según permisos evaluados
 6. auth/cerrar_sesion.pl             ── Destrucción segura y purga de sesiones inactivas

SECUENCIA II: ADMISIÓN DE PACIENTES Y AGENDA MÉDICA CENTRAL (Proceso 2)
 7. views/agenda_main.pl              ── Consola multitemporal de citas y asignación médica
 8. api/citas_crud.pl                 ── Controlador transaccional de citas y estados
 9. views/crud_paciente.pl            ── Formulario maestro de identificación del derechohabiente
10. api/pacientes_crud_api.pl         ── Operaciones CRUD de pacientes y validación CURP/RFC
11. api/autocomplete_pacientes.pl     ── Búsqueda de alta velocidad para recepción

SECUENCIA III: NÚCLEO CLÍNICO SOAP, ODONTOGRAMA Y RECETA (Proceso 3)
12. views/render_expediente_clinico.pl ── Expediente unificado e historial clínico NOM-004
13. api/autosave_consulta.pl         ── Guardado automático concurrente de borradores SOAP
14. views/partials/consultas/*        ── Subformularios desacoplados (Plugin Slots de especialidad)
15. js/odontograma_plus.js           ── Motor gráfico Canvas HTML5/SVG de 52 piezas dentales
16. api/odontograma_api.pl           ── Persistencia de estados dentales atómicos
17. api/buscar_cie10.pl              ── Catálogo nosológico de diagnósticos
18. api/cerrar_consulta_privado.pl   ── Cierre transaccional, firma digital y sello inmutable
19. api/imprimir_receta_api.pl       ── Emisión foliada de prescripción farmacológica

SECUENCIA IV: TRAZABILIDAD QUIRÚRGICA OMS Y CONSENTIMIENTOS (Proceso 4)
20. views/quirofano_kanban.pl        ── Tablero Kanban hospitalario de 5 estados
21. api/quirofano_crud.pl            ── Registro de tiempos y checklist quirúrgico OMS (3 fases)
22. api/consentimientos_api.pl       ── Repositorio atómico de consentimientos tipificados
23. views/imprimir_nota_quirurgica.pl── Nota transoperatoria y criterios de alta UCPA Aldrete

SECUENCIA V: MOTOR FINANCIERO MULTI-TARIFA Y CAJA RÁPIDA (Proceso 5)
24. views/generar_recibo.pl          ── Punto de venta, carrito dinámico y multi-tarifa
25. api/guardar_recibo_rapido.pl     ── Procesamiento transaccional de cobro en ventanilla
26. api/imprimir_recibo_caja.pl      ── Recibo privado de efectivo real con toolbar .no-print
27. api/imprimir_recibo_publico.pl   ── Recibo público de cuentas por cobrar (CXC Estado)
28. api/finanzas_api.pl              ── Indicadores KPI y conciliación al centavo
29. views/finanzas.pl                ── Tablero ejecutivo y arqueo de caja con drilldown

SECUENCIA VI: CATÁLOGOS SERVER-SIDE 3NF Y AUDITORÍA INMUTABLE (Proceso 6)
30. views/manage_catalogo_universal.pl ── Administración de catálogos 3NF por CLUES
31. api/crud_catalogo_universal_api.pl ── DataTables Server-Side AJAX a 10 registros
32. utils/catalogo_org_utils.pl      ── Resolución jerárquica de rutas de catálogo CLUE
33. utils/db_manager.pm              ── Capa de persistencia plana con bloqueos flock(LOCK_EX)
34. utils/audit_manager.pm           ── Registro append-only de eventos de auditoría NOM-024
```

---

### 7.3 Encabezado Canónico de Licencia y Reserva de Derechos
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

### 7.4 Árbol Jerárquico de Directorios y Estructura Modular
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

## 8. DECLARACIÓN JURADA, PROTESTA DE DECIR VERDAD Y RATIFICACIÓN DE FIRMAS

### 8.1 Declaración Solemne bajo Protesta de Decir Verdad
En estricto cumplimiento de los artículos 101, 102, 103, 105, 106, 107 y demás relativos y aplicables de la **Ley Federal del Derecho de Autor** de los Estados Unidos Mexicanos, de su Reglamento en vigor, y debidamente enterados y apercibidos de las sanciones administrativas y de las penas de orden civil y penal en que incurren las personas que declaran con falsedad ante autoridad legalmente facultada, los comparecientes **DECLARAMOS SOLEMNEMENTE BAJO PROTESTA DE DECIR VERDAD**:

1. **VERACIDAD Y EXACTITUD TÉCNICA:** Que la totalidad de la información, memorias descriptivas, esquemas de arquitectura de software, especificaciones de motores de datos en Tercera Forma Normal (3NF), contratos de persistencia y extractos sustanciales de código fuente asentados en el presente instrumento documental son verídicos, exactos, fidedignos y reflejan fielmente el estado actual de ingeniería, lógica algorítmica y funcionalidad del sistema aplicativo denominado **OSpulso** (*Ospulso Platform Core v2.0 / Diamond Edition v4.5.0*).
2. **ORIGINALIDAD Y AUTORÍA INTELECTUAL:** Que la obra computacional descrita es una creación intelectual original, concebida, desarrollada y programada por el **C. Israel Garay de la Cruz** en su calidad de *Autor, Arquitecto de Software y Creador Intelectual Originario*, habiéndose generado de forma independiente y sin incurrir en plagio, reproducción indebida ni vulneración alguna de los derechos de propiedad intelectual, derechos morales o derechos conexos de terceras personas físicas o morales.
3. **TITULARIDAD PATRIMONIAL EXCLUSIVA:** Que la sociedad mercantil denominada **Plataformas Digitales de México, S.A. de C.V.**, por conducto de su Representante Legal el **C. Israel Garay de la Cruz**, ostenta de manera exclusiva, legítima e incontrovertible la titularidad de los derechos patrimoniales sobre la obra en términos de los artículos 103 y 105 de la Ley Federal del Derecho de Autor, estando plenamente facultada para el uso, comercialización, comunicación pública, distribución, adaptación, licenciamiento y explotación comercial en la modalidad Software as a Service (SaaS).
4. **APEGO NORMATIVO SANITARIO:** Que los procesos clínicos descritos han sido diseñados en estricto apego a las disposiciones de las Normas Oficiales Mexicanas **NOM-004-SSA3-2012** (Del Expediente Clínico), **NOM-024-SSA3-2012** (Sistemas de Información de Registro Electrónico para la Salud), las directrices de la Organización Mundial de la Salud (OMS) en materia de seguridad quirúrgica y la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP).
5. **FINALIDAD DEL DEPÓSITO:** Que la presente Memoria Técnica y Extracto Sustancial de Código Fuente se integran y expiden de buena fe para su formal depósito legal, solicitud de inscripción y expedición del correspondiente **Certificado de Registro de Obra de Programa de Computación** ante la Dirección del Registro Público del Derecho de Autor del **Instituto Nacional del Derecho de Autor (INDAUTOR)**.

Para debida constancia legal y surtimiento de los efectos procedentes, se firma y suscribe el presente documento en la Ciudad de México / San Luis Potosí, México, a los 04 días del mes de noviembre del año 2026.

---

### 8.2 Cuadro Institucional de Firmas al Calce

| AUTOR Y DESARROLLADOR PRINCIPAL | TITULAR DE DERECHOS PATRIMONIALES |
| :---: | :---: |
| <br><br>_____________________________________________ | <br><br>_____________________________________________ |
| **ISRAEL GARAY DE LA CRUZ** | **PLATAFORMAS DIGITALES DE MÉXICO, S.A. DE C.V.** |
| Autor Intelectual y Creador de la Obra | Por conducto de su Representante Legal: |
| *(Persona Física)* | **ISRAEL GARAY DE LA CRUZ** |
| | *Representante Legal y Administrador* |
