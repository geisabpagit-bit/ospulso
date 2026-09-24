// SPA Router para OSPulso
// Intercepta la navegación para una experiencia fluida sin recargas.

// Deshabilitado temporal/definitivamente por estabilidad de carga en CGI Perl
/*
document.addEventListener("click", function (e) {
    const a = e.target.closest("a");
    if (!a || !a.href) return;

    // Ignorar links externos, anchors, JS, o tabs nuevas
    if (a.origin !== location.origin || a.hash || a.href.includes("javascript:") || a.target === "_blank") return;

    // Ignorar links específicos que no deben ser SPA
    if (a.href.includes("cerrar_sesion.pl") || a.hasAttribute("data-no-spa") || a.onclick) return;

    // Solo interceptamos vistas .pl de la carpeta views/
    if (a.pathname.endsWith(".pl") && a.pathname.includes("/views/")) {
        e.preventDefault();

        // Evitar recargar la misma página si no hay query params
        if (a.href === location.href) return;

        loadPage(a.href);
    }
});
*/

window.addEventListener("popstate", function (e) {
    if (e.state && e.state.spa) {
        loadPage(location.href, false);
    } else {
        window.location.reload();
    }
});

// Guardar el estado inicial
window.history.replaceState({ spa: true }, "", location.href);

async function loadPage(url, push = true) {
    try {
        // Añadir efecto de opacidad para dar feedback visual
        const mainContent = document.querySelector('.sdm-main-content');
        if (mainContent) mainContent.style.opacity = '0.5';

        const res = await fetch(url);
        if (!res.ok) throw new Error("Network error");

        const html = await res.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, "text/html");

        // Actualizar Título
        if (doc.title) document.title = doc.title;

        // Actualizar Contenido Principal
        const newMain = doc.querySelector('.sdm-main-content');

        let scriptsToExecute = [];
        if (newMain && mainContent) {
            // Extraer scripts antes de inyectar para evitar falsos positivos de "exists"
            const scripts = newMain.querySelectorAll('script');
            scriptsToExecute = Array.from(scripts);
            scripts.forEach(s => s.remove());

            mainContent.innerHTML = newMain.innerHTML;
            // OJO: NO restauramos opacity ni pointer-events aquí todavía.
            // El contenido ya está pintado, pero los scripts (incl. los que
            // definen funciones usadas en onclick="...") aún no se han
            // re-ejecutado. Si el usuario hace clic ahora, esas funciones
            // pueden no existir aún -> "ReferenceError: X is not defined".
            mainContent.style.pointerEvents = 'none';
        } else {
            // Si la estructura no coincide, hacer navegación normal
            window.location.href = url;
            return;
        }

        // Actualizar estado activo del Sidebar
        const newSidebar = doc.querySelector('.diamond-sidebar');
        const currentSidebar = document.querySelector('.diamond-sidebar');
        if (newSidebar && currentSidebar) {
            currentSidebar.innerHTML = newSidebar.innerHTML;
        }

        // Procesar Hojas de Estilo (Evitar duplicados)
        const currentLinks = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).map(l => l.href);
        const newLinks = doc.querySelectorAll('link[rel="stylesheet"]');
        newLinks.forEach(link => {
            if (!currentLinks.includes(link.href)) {
                const newLink = document.createElement('link');
                newLink.rel = 'stylesheet';
                newLink.href = link.href;
                document.head.appendChild(newLink);
            }
        });

        // Procesar Scripts del nuevo contenido
        // En SPA, los <script> inyectados vía innerHTML no se ejecutan. Hay que recrearlos.
        const executeScriptsSequentially = async (scriptsList) => {
            for (const oldScript of scriptsList) {
                const newScript = document.createElement('script');
                if (oldScript.src) {
                    // Evitar recargar librerías pesadas si ya existen en el documento
                    const isLibrary = oldScript.src.includes("jquery") ||
                        oldScript.src.includes("datatables") ||
                        oldScript.src.includes("bootstrap") ||
                        oldScript.src.includes("sweetalert") ||
                        oldScript.src.includes("_spa");

                    if (isLibrary) {
                        const exists = document.querySelector(`script[src^="${oldScript.src.split('?')[0]}"]`);
                        if (exists) {
                            oldScript.remove();
                            continue;
                        }
                    }

                    newScript.src = oldScript.src;
                    newScript.async = false; // Mantener orden de ejecución

                    await new Promise((resolve) => {
                        let timeout = setTimeout(resolve, 3000); // 3 seconds timeout
                        newScript.onload = () => { clearTimeout(timeout); resolve(); };
                        newScript.onerror = () => { clearTimeout(timeout); resolve(); }; // Continuar aunque falle
                        document.body.appendChild(newScript);
                    });
                } else {
                    newScript.textContent = oldScript.textContent;
                    document.body.appendChild(newScript);
                }
                oldScript.remove();
            }
        };

        await executeScriptsSequentially(scriptsToExecute);

        // Ahora sí: todos los scripts (incluidas las funciones usadas en
        // los onclick del HTML recién insertado) ya están definidos.
        mainContent.style.opacity = '1';
        mainContent.style.pointerEvents = 'auto';

        if (push) {
            history.pushState({ spa: true }, "", url);
        }

        // Disparar evento personalizado para que los módulos se inicialicen
        document.dispatchEvent(new Event("spa:contentLoaded"));

    } catch (err) {
        console.error("SPA Error:", err);
        window.location.href = url; // Fallback seguro
    }
}