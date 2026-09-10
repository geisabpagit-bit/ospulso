# OSPulso Master Blueprint v2.0 & Strategy Guide

**Versión**: OsPulso Diamond Edition v4.5.0  
**Ámbito**: Arquitectura de Producto, Ingeniería y Modelo Operativo  
**Estado**: Fuente Canónica Principal de Verdad (Actualizado 2026)

---

## 📌 1. Visión y Posicionamiento Estratégico

OSPulso no es una simple aplicación web; es el **Sistema Operativo Clínico Infraestructural** diseñado para clínicas privadas, centros médicos y redes de salud en Latinoamérica.

### Misión
Reducir a cero la fricción operativa del profesional médico y del equipo de recepción, garantizando integridad contable al centavo y trazabilidad clínica ininterrumpida.

---

## 🏛️ 2. Arquitectura de Ingeniería y Base de Datos 3NF

### A. Estructura Relacional por Tenant (`dat/catalogos_CLUE/<CLUES>/`)
Cada organización opera con su catálogo aislado bajo norma 3NF:
- `departamentos_<CLUES>.dat` (Departamentos: ej. `ID_DEP 4` = `IMAGENOLOGIA`).
- `categorias_<CLUES>.dat` (Categorías: ej. `ID_CAT 16` = `RAYOS X`).
- `catalogo_items_<CLUES>.dat` (Servicios con SKUs estandarizados `LAB-`, `US-`, `RX-`, `CONS-0001` a `CONS-0832`).
- `catalogo_precios_<CLUES>.dat` (Matriz N-Tarifas relacional por ítem).
- `tipos_tarifas_<CLUES>.dat` (Catálogo extensible: `ESTANDAR`, `MUNICIPIO`, `URGENCIAS`, `DOMINGOS_Y_FESTIVOS`, `PAQUETE_TODO_INCLUIDO`).

### B. Carga Eficiente Server-Side DataTables (`deferRender: true`)
- **Backend AJAX (`api/crud_catalogo_universal_api.pl`)**: Procesamiento server-side con la acción `datatable_servicios` para paginación y búsqueda eficiente.
- **Paginación Estándar de 10 Registros**: Configuración por defecto a `pageLength: 10` en frontend y administración.

---

## 💰 3. Arquitectura Financiera, Caja y Cobranza

1. **Fuente Canónica de Efectivo Real**: `dat/folios_recibos_privados.dat` es la **única fuente de efectivo cobrado en ventanilla**. Prohibido sumar en paralelo `estado_cuenta.dat` para evitar doble contabilidad.
2. **Segregación CXC Estado**: Las atenciones de convenio público (`folios_recibos_publicos.dat`) corresponden a Cuentas por Cobrar (CXC Estado) y no constituyen efectivo físico en caja.
3. **Módulo Multi-Tarifa en Recibos (`views/generar_recibo.pl`)**:
   - Selector `<select>` de tarifa activa en modal y fila de carrito.
   - Recálculo automático de precio unitario, subtotal, IVA (16%) y Total a Pagar.
   - Tarjeta de resumen flexible (`flex: 1 1 auto; max-height: 420px; overflow-y: auto;`) con alineación al píxel derecho.

---

## 🎨 4. Sistema UI/UX y Responsividad Móvil

1. **Tokens de Diseño Medentia Aura**: `--md-blue-deep` (`#0A2A66`), `--md-teal-clinical` (`#19B7A5`), `--md-bg-light` (`#F8FBFF`).
2. **Usabilidad Táctil Móvil**: Integración de `.btn-mobile-standard` asegurando **Touch Target mínimo de 48px**.
3. **Regla de los 3 Clics**: Navegación fluida Agenda ➔ Paciente ➔ Expediente en menos de 3 clics sin pantallas innecesarias.

---

## 🛡️ 5. Protocolos de Estabilidad Backend (Error 500 Guard)

- **Blindaje de Interpolación Perl**: Escapar obligatoriamente `@media` como `\@media` en bloques HEREDOC para evitar errores de compilación `"Global symbol requires explicit package name"`.
- **Escape de Comillas JS**: Evitar `\'` dentro de strings de JS delimitados por comillas simples inyectados desde Perl HEREDOC.
- **Rutas e Integridad**: Uso estricto de `FindBin`, Shebang universal `#!/usr/bin/perl`, codificación UTF-8 `:raw` y fin de línea LF (Unix).

---

## 🚀 6. Hito de Entrega "Pepito" (V1.0 Milestone)

1. Agenda Inteligente Viva con confirmación en 1 clic.
2. Núcleo Clínico Normativo SOAP (NOM-004-SSA3-2012 / NOM-024).
3. Tablero Financiero conectado con drilldown exacto al centavo.
4. Experiencia Mobile-First & PWA.
5. Estabilidad a prueba de caídas con Error 500 Guard activo.
