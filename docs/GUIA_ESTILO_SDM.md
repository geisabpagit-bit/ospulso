# Guía de Estilo y Sistema de Diseño SDM / OSPulso 2.0

## 1. Paleta de Colores y Tokens CSS

La interfaz utiliza variables de color CSS personalizadas alineadas con estética médica clínica moderna y glassmorphism:

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
   - Fondo `#F8FBFF`, bordes suavizados `border-radius: 1rem`, foco con anillo `rgba(25, 183, 165, 0.15)`.
2. **Botones de Acción Standard (`.btn-mobile-standard`, `.btn-mobile-action`)**:
   - Garantizan un **Touch Target mínimo de 48px** para usabilidad táctil en pantallas móviles y tabletas.
3. **Tarjetas Adaptables de Carrito y Resumen (`.cart-item-card`)**:
   - Fondo blanco con borde discreto `#e9ecef`, sombra sutil `shadow-sm` y hover reactivo.

---

## 3. Normas de Responsividad Móvil (`css/sdm_mobile_standards.css`)

- Usar `.container-mobile-flush` en contenedores principales para eliminar paddings estorbosos en `< 768px`.
- Usar `.mobile-edge-to-edge` para expandir elementos al 100% de la pantalla cuando sea necesario.
