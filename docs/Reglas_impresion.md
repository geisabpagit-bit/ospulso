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
- **Recibos de Caja Privados (Walk-in y Particulares)**: Implementado en `api/imprimir_recibo_caja.pl`. Ver documentación detallada en [impresion_recibo_caja.md](file:///c:/xampp/htdocs/ospulso/docs/impresion_recibo_caja.md).
- **Recibos Públicos (Estado/Municipio)**: Implementado en `api/imprimir_recibo_publico.pl`. Ver reglas en [impresion_recibo_publico.md](file:///c:/xampp/htdocs/ospulso/docs/impresion_recibo_publico.md).
- **Flujo Global (CRUD) de Caja Rápida**: Documentado en [flujo_caja_rapida.md](file:///c:/xampp/htdocs/ospulso/docs/flujo_caja_rapida.md).
