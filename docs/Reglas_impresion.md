### Reglas globales.
**  Todo documento debe contener la codificaciÃ³n UTF-8 y debe comprobarse antes de entregar una versiÃ³n final de la impresiÃ³n para evitar problemas con acentos y caracteres especiales (ej. "MÃ©dico" vs "M&eacute;dico").

---
# Cabecera
**Hospital [nombre del negocio]*  
**Modulo:** [Nombre del TABLERO O FUNCION]  

**Fecha:** [DD/MM/AAAA]  

---

# Cuerpo del documento
[Escribir aquÃ­ el contenido principal del reporte, carta o escrito.  
Usar pÃ¡rrafos claros, tÃ­tulos y subtÃ­tulos si es necesario.]

---

# Pie de impresiÃ³n
**DirecciÃ³n:** 
**TelÃ©fono:** 
**Correo:** 

**Aviso de confidencialidad:**  
Este documento contiene informaciÃ³n confidencial destinada Ãºnicamente al receptor autorizado.  

**CÃ³digo interno:** [Clave del Ã¡rea]  
**PÃ¡gina X de Y**

---
# Documentos Específicos
- **Nota de Evolución / Detalles de Consulta**: Implementado en `views/consulta_detalles.pl`. Utiliza un diseño Bento-Grid (CSS @media print) que aplasta márgenes y desactiva sombras para formato carta.
- **Recibos de Caja**: Implementado en `api/imprimir_recibo_caja.pl`. Formato estricto a Media Carta (5.5" x 8.5" usando CSS `@page { size: 5.5in 8.5in; margin: 0; }`). Los montos usan formato moneda con separación de miles. La codificación es UTF-8. El folio es consecutivo (guardado en `folios_recibos_privados.dat` o PMIX correspondientes) e inmutable por sucursal. Incluye campos de firma, logo y detalle de los conceptos de la consulta.
