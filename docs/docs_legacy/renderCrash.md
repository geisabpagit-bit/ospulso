# ✅ Prompt Técnico - SPA (Perl + JS + AJAX)
## Prioridad: Correcta visualización en Smart TV y WebView

### 1. Optimización de Memoria
- [ ] **Reducir bundles JS** con Webpack/esbuild.
- [ ] **Lazy loading** en componentes React.
- [ ] **Liberar recursos**: `clearInterval`, `removeEventListener`.

### 2. Compatibilidad de APIs
- [ ] Detectar entorno con `navigator.userAgent`.
- [ ] Servir **polyfills** (Promise, fetch).
- [ ] Evitar APIs no soportadas en Tizen/WebView (WebRTC, WebGL avanzado).

### 3. Comunicación AJAX ↔ Perl
- [ ] Respuestas JSON con `Content-Type: application/json`.
- [ ] Manejo de errores en `fetch`/`$.ajax` (timeouts, status codes).
- [ ] Validar datos antes de renderizar para evitar crashes.

### 4. Fallback UI
- [ ] Implementar **Error Boundaries** en React.
- [ ] Mostrar **modo básico** si el navegador no soporta funciones críticas.
- [ ] Evitar renderizado pesado en dispositivos con poca RAM.

### 5. Logs y Diagnóstico
- [ ] Registrar errores en servidor (Perl: `Log::Log4perl`).
- [ ] Capturar `window.onerror` y enviar reporte.
- [ ] Monitorear consumo de memoria en dispositivos embebidos.

### 6. Pruebas en Dispositivos
- [ ] Probar en **Smart TV Samsung (Tizen Browser)**.
- [ ] Validar en **Android WebView**.
- [ ] Usar emuladores o servicios como BrowserStack para compatibilidad.

---

## 📋 Ejemplo Práctico

### Perl Backend
```perl
print "Content-Type: application/json\n\n";
my $response = { status => "ok", data => \@resultados };
print encode_json($response);

