/**
 * ==========================================================================
 * OSPulso - Progressive Web App (PWA) Service Worker v1.0
 * Soporte Offline, Caché de Shell y Experiencia Nativa de Aplicación
 * ==========================================================================
 */

const CACHE_NAME = 'ospulso-pwa-v1.1';

// Recursos críticos para arranque instantáneo (App Shell)
const STATIC_ASSETS = [
    './',
    './index.html',
    './manifest.json',
    './css/ospulso_master.css',
    './css/sdm_mobile_standards.css',
    './favicon/favicon.svg',
    './favicon/apple-touch-icon.png',
    './favicon/icon-192x192.png',
    './favicon/icon-512x512.png',
    './favicon/favicon.ico'
];

// 1. Instalación del Service Worker y precaché de recursos estáticos
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            console.log('[PWA] Precaching Shell de OsPulso...');
            return cache.addAll(STATIC_ASSETS).catch((err) => {
                console.warn('[PWA] Advertencia en precaché inicial (algunos recursos pueden no estar disponibles offline):', err);
            });
        }).then(() => self.skipWaiting())
    );
});

// 2. Activación y purga de cachés obsoletas
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((name) => {
                    if (name !== CACHE_NAME) {
                        console.log('[PWA] Eliminando caché obsoleta:', name);
                        return caches.delete(name);
                    }
                })
            );
        }).then(() => self.clients.claim())
    );
});

// 3. Estrategia de peticiones (Network First con Fallback a Caché para contenido fresco)
self.addEventListener('fetch', (event) => {
    // Excluir llamadas POST, APIs CGI (.pl) y extensiones no cacheables de autenticación
    if (event.request.method !== 'GET') {
        return;
    }

    const url = new URL(event.request.url);

    // Omitir endpoints Perl dinámicos de sesión/auth para evitar stale data
    if (url.pathname.includes('/api/') || url.pathname.includes('/auth/')) {
        return;
    }

    // Para navegación principal HTML (Network First -> Caché)
    if (event.request.mode === 'navigate') {
        event.respondWith(
            fetch(event.request)
                .then((response) => {
                    // Guardar copia fresca en caché
                    if (response && response.status === 200) {
                        const copy = response.clone();
                        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
                    }
                    return response;
                })
                .catch(() => {
                    return caches.match(event.request).then((cached) => {
                        return cached || caches.match('./index.html');
                    });
                })
        );
        return;
    }

    // Para recursos estáticos (CSS, JS, Fonts, Img): Stale-While-Revalidate
    event.respondWith(
        caches.match(event.request).then((cachedResponse) => {
            const fetchPromise = fetch(event.request)
                .then((networkResponse) => {
                    if (networkResponse && networkResponse.status === 200) {
                        const responseToCache = networkResponse.clone();
                        caches.open(CACHE_NAME).then((cache) => {
                            cache.put(event.request, responseToCache);
                        });
                    }
                    return networkResponse;
                })
                .catch(() => {
                    // Si falla la red, el retorno de cachedResponse bastará
                });

            return cachedResponse || fetchPromise;
        })
    );
});
