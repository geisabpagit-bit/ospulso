```
# ESPECIFICACIÓN TÉCNICA Y ARQUITECTURA: ODONTOGRAMA DIGITAL PLUS

## 1. OBJETIVO DEL PROYECTO
Reemplazar el módulo legacy del odontograma en el SaaS actual por una versión interactiva, ligera, accesible y moderna. El nuevo componente se integrará dentro de la vista existente de "Edición de Expediente" (`/expediente/editar.pl` o plantilla equivalente), conservando intacto el sistema de control de acceso, gestión de sesiones, usuarios y mecanismos de encriptación actuales.

---

## 2. RESTRICCIONES TÉCNICAS Y STACK TECNOLÓGICO
- **Frontend:** Vanilla JavaScript (ES6+), SVG Nativo 2D vectorial, Bootstrap 5.3. 
  - *Restricción estricta:* SIN React, SIN Vue, SIN Node.js, SIN procesos de compilación o empaquetado (npm/webpack).
- **Backend:** Perl (módulos existentes para autenticación, sesiones y seguridad).
- **Almacenamiento:** Archivos planos JSON por paciente (encriptados/desencriptados de acuerdo con la lógica actual del SaaS).
- **Librerías Perl recomendadas:** `JSON::XS` / `JSON::PP` (procesamiento rápido) y `File::Slurper` / `flock` (escritura atómica con bloqueo de archivo).

---

## 3. ESTÁNDARES CLÍNICOS Y CONVENCIONES

### A. Nomenclatura Dental (FDI / ISO 3950)
- **Código de 2 dígitos por pieza:**
  - **Dentición Permanente (Adultos):** 
    - Cuadrante 1 (Superior Derecho): `11` al `18`
    - Cuadrante 2 (Superior Izquierdo): `21` al `28`
    - Cuadrante 3 (Inferior Izquierdo): `31` al `38`
    - Cuadrante 4 (Inferior Derecho): `41` al `48`
  - **Dentición Decidua (Infantil/Temporal):**
    - Cuadrante 5 (Superior Derecho): `51` al `55`
    - Cuadrante 6 (Superior Izquierdo): `61` al `65`
    - Cuadrante 7 (Inferior Izquierdo): `71` al `75`
    - Cuadrante 8 (Inferior Derecho): `81` al `85`
  - **Áreas Generales / Regiones (ISO 3950):** `00` (Cavidad oral), `01` (Maxilar), `02` (Mandibular), `10-40` (Cuadrantes completos), `03-08` (Sextantes).

### B. Mapeo de Superficies Anatómicas por Diente
Cada corona dental se compone de 5 áreas vectoriales independientes (*hitboxes*):
1. **Mesial (`M`):** Superficie orientada hacia la línea media.
2. **Distal (`D`):** Superficie opuesta a la línea media.
3. **Oclusal / Incisal (`O` / `I`):** Superficie triturante o borde cortante.
4. **Vestibular / Facial (`V` / `F`):** Superficie externa orientada hacia los labios/mejillas.
5. **Lingual / Palatina (`L` / `P`):** Superficie interna orientada hacia la lengua o paladar.

### C. Convención Estándar de Colores
- 🔴 **Tratamientos Pendientes / Patologías Activas:** `#FF3B30` (Rojo neón/clínico).
  - *Ejemplos:* Caries activa, fracturas, exodoncia indicada, restauración desadaptada.
- 🔵 **Tratamientos Realizados / Condiciones Existentes:** `#007AFF` (Azul eléctrico).
  - *Ejemplos:* Amalgama/resina existente, endodoncia concluida, corona, implante placed.

---

## 4. ESTRUCTURA DEL ARCHIVO PLANO JSON (`paciente_ID.json`)

Cada paciente tendrá un archivo plano JSON persistido en el servidor (`/datos/expedientes/paciente_1234.json`):

```json
{
  "patientId": "12345",
  "updatedAt": "2026-09-28T20:25:00Z",
  "dentitionType": "PERMANENT",
  "teeth": {
    "16": {
      "status": "PRESENT",
      "surfaces": {
        "mesial": {
          "code": "CARIES",
          "state": "PENDING_TREATMENT",
          "colorHex": "#FF3B30",
          "price": 85.00
        },
        "occlusal": {
          "code": "COMPOSITE",
          "state": "EXISTING_CONDITION",
          "colorHex": "#007AFF",
          "price": 0.00
        }
      },
      "root": {
        "code": "ENDODONTICS_COMPLETED",
        "state": "EXISTING_CONDITION",
        "colorHex": "#007AFF"
      }
    }
  },
  "periodontalSummary": {
    "bleedingOnProbing": true,
    "maxProbingDepthMm": 4
  },
  "financialTotalPending": 85.00
}

```

---

## 5\. ESPECIFICACIONES DE FRONTEND (JS + SVG + BOOTSTRAP 5.3)

### A. Estructura HTML/SVG del Mapa Dental

* Canvas renderizado mediante un elemento `<div>
  
</div>

```

1. Al cargar la página (`DOMContentLoaded`), `odontograma.js` ejecuta un `fetch('/api/obtener_odontograma.pl?patientId=12345')`.
2. Al presionar el botón general "Guardar Expediente", se invoca la función `saveOdontogram()` mediante `fetch()` en segundo plano o junto con el envío del formulario principal.

---

## 8\. PLAN DE EJECUCIÓN CON GOOGLE ANTIGRAVITY

1. **Fase 1 (Frontend Layout &amp; SVG):** Generar el marcado SVG de las 32 piezas y el script de pintado/eventos en `odontograma.js`.
2. **Fase 2 (Popovers Bootstrap &amp; Cascade Menu):** Crear los menús flotantes y el selector en cascada para la marcación de superficies.
3. **Fase 3 (Backend Perl &amp; Archivos Planos):** Implementar los scripts Perl de lectura y escritura en JSON con bloqueo de archivos.
4. **Fase 4 (Integración Final):** Acoplar el odontograma a la vista de edición de expediente existente y probar el flujo completo.

```

---
```