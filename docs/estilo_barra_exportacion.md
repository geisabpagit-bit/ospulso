# MedentIA - Clinical Intelligence Core  
## Guía de Estilo: Botones de Exportación Premium (Glassmorphism)

### 🎨 Descripción
Estilos diseñados para la **barra de herramientas de exportación** en interfaces clínicas digitales.  
Basado en **Bootstrap 5.x**, con enfoque en **Glassmorphism** y variantes premium para interacción fluida.

---

### 📐 Variables principales
- **Primary (`--medentia-primary`)**: Azul institucional `#0a2a66`  
- **Secondary (`--medentia-secondary`)**: Cian brillante `#18d1e6`  
- **Border (`--medentia-border`)**: Gris suave `#dad9df`  
- **Glass Background (`--medentia-bg-glass`)**: Blanco translúcido `rgba(255, 255, 255, 0.7)`

---

### 🖥️ Código CSS

```css
/*
 * MedentIA - Clinical Intelligence Core
 * Estilos para Botones de Exportación Premium (Glassmorphism)
 * Basado en Bootstrap 5.x
 */

:root {
  --medentia-primary: #0a2a66;
  --medentia-secondary: #18d1e6;
  --medentia-border: #dad9df;
  --medentia-bg-glass: rgba(255, 255, 255, 0.7);
}

/* Contenedor de la barra de herramientas con Glassmorphism */
.export-toolbar {
  background: var(--medentia-bg-glass);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 1rem;
  padding: 0.625rem;
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  box-shadow: 0 8px 32px 0 rgba(10, 42, 102, 0.05);
  width: fit-content;
}

/* Estilo base de los botones de exportación */
.btn-export {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.625rem;
  padding: 0.625rem 1.25rem;
  background-color: #ffffff;
  color: var(--medentia-primary);
  font-family: 'Inter', sans-serif;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border: 1px solid var(--medentia-border);
  border-radius: 0.75rem;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  cursor: pointer;
  text-decoration: none;
}

/* Iconos dentro de los botones */
.btn-export i, 
.btn-export svg {
  font-size: 1.1rem;
  color: var(--medentia-primary);
  transition: color 0.3s ease;
}

/* Estados de interacción (Animación y Efecto Elevación) */
.btn-export:hover {
  background-color: #f4f3f9;
  border-color: var(--medentia-secondary);
  color: var(--medentia-primary);
  transform: translateY(-3px);
  box-shadow: 0 6px 15px rgba(24, 209, 230, 0.2);
}

.btn-export:hover i,
.btn-export:hover svg {
  color: var(--medentia-secondary);
}

.btn-export:active {
  transform: translateY(-1px);
  box-shadow: 0 2px 8px rgba(24, 209, 230, 0.1);
}

/* Variantes opcionales para estados de carga o deshabilitados */
.btn-export:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
  box-shadow: none;
}
