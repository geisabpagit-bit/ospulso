# Guía de Estilo, Tokens de Diseño y Componentes UI (SDM / OSPulso 2.0)

## 1. Paleta de Colores y Tokens CSS

La interfaz utiliza variables de color CSS alineadas con la estética clínica Medentia Aura:

```css
:root {
    --md-blue-deep: #0A2A66;      /* Azul Profundo Institucional */
    --md-teal-clinical: #19B7A5;  /* Teal Clínico Primario */
    --md-teal-dark: #0D9488;      /* Teal Oscuro para Bordes */
    --md-accent-gold: #F59E0B;    /* Dorado de Énfasis / Estado */
    --md-bg-light: #F8FBFF;       /* Fondo Claro Medentia Aura */
    --md-surface: #FFFFFF;        /* Superficie de Tarjetas */
}
```

---

## 2. Componentes UI Estandarizados

1. **Campos de Entrada Armor (`.custom-input-caja`, `.diamond-input-armor`)**:
   - Fondo `#F8FBFF`, bordes suavizados `border-radius: 1rem`, foco reactivo con anillo `rgba(25, 183, 165, 0.15)`.
2. **Botones de Acción Standard (`.btn-mobile-standard`, `.btn-mobile-action`)**:
   - Garantizan un **Touch Target mínimo de 48px** para interacción táctil fluida en dispositivos móviles.
3. **Tarjetas Adaptables de Carrito y Resumen (`.cart-item-card`)**:
   - Estilo flexible con bordes `#e9ecef`, sombras `shadow-sm` y hover animado.

---

## 3. Estilo de Barra de Exportación DataTables

Las tablas del sistema incorporan controles de exportación estandarizados estilizados según los tokens de la guía de estilo:
- **Excel**: Exportación limpia a XLSX.
- **PDF**: Generación de reportes PDF vectoriales.
- **Imprimir**: Formato plano libre de elementos de control `.no-print`.

---

## 4. Normas de Responsividad Móvil (`css/sdm_mobile_standards.css`)

- Utilizar `.container-mobile-flush` en contenedores principales para comprimir márgenes estorbosos en resoluciones menores a 768px.
- Utilizar `.mobile-edge-to-edge` para expandir tarjetas al 100% de la pantalla cuando se requiera espacio máximo.
