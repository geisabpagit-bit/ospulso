
// Sincronización visual de puntos de control del Sidebar (Cabecera de Sidebar y Navbar Responsivo)
window.syncSidebarToggleVisuals = function(isCompact) {
    const iconTop = document.getElementById("iconToggleDesktopSidebar");
    const btnTop = document.getElementById("btnToggleDesktopSidebar");
    const avatar = document.getElementById("sidebarAvatarBrand");
    const iconNavbar = document.getElementById("iconNavbarSidebarToggle");
    const btnNavbar = document.getElementById("btnNavbarDesktopSidebarToggle");

    if (isCompact) {
        if (iconTop) {
            iconTop.className = "bi bi-chevron-double-right text-teal fs-6";
        }
        if (btnTop) {
            btnTop.title = "Expandir menú lateral (Alt+M)";
            btnTop.setAttribute("aria-label", "Expandir menú lateral");
            btnTop.setAttribute("data-sidebar-title", "Expandir menú (Alt+M)");
            btnTop.classList.add("btn-active-compact");
        }
        if (avatar) {
            avatar.title = "Clic para expandir menú (Alt+M)";
            avatar.setAttribute("data-sidebar-title", "Expandir menú (Alt+M)");
        }
        if (iconNavbar) {
            iconNavbar.className = "bi bi-layout-sidebar-inset text-teal fs-5";
        }
        if (btnNavbar) {
            btnNavbar.title = "Abrir menú lateral";
            btnNavbar.classList.add("btn-active-compact");
        }
    } else {
        if (iconTop) {
            iconTop.className = "bi bi-layout-sidebar-inset text-teal fs-5";
        }
        if (btnTop) {
            btnTop.title = "Colapsar menú lateral (Alt+M)";
            btnTop.setAttribute("aria-label", "Colapsar menú lateral");
            btnTop.setAttribute("data-sidebar-title", "Colapsar menú (Alt+M)");
            btnTop.classList.remove("btn-active-compact");
        }
        if (avatar) {
            avatar.title = avatar.getAttribute("data-original-title") || "Menú principal";
            avatar.removeAttribute("data-sidebar-title");
        }
        if (iconNavbar) {
            iconNavbar.className = "bi bi-layout-sidebar-inset text-teal fs-5";
        }
        if (btnNavbar) {
            btnNavbar.title = "Abrir menú lateral";
            btnNavbar.classList.remove("btn-active-compact");
        }
    }
};

window.handleSidebarBrandClick = function() {
    const sidebar = document.getElementById("moduleSidebar");
    if (sidebar && sidebar.classList.contains("compact")) {
        window.toggleDesktopSidebar();
    }
};

window.toggleSidebar = function() {
    if (window.innerWidth >= 992) {
        const overlay = document.getElementById("sidebarOverlay");
        if (overlay) overlay.classList.remove("show");
        return;
    }
    const sidebar = document.getElementById("moduleSidebar");
    const overlay = document.getElementById("sidebarOverlay");
    if (sidebar) sidebar.classList.toggle("show");
    if (overlay) overlay.classList.toggle("show");
};

window.toggleDesktopSidebar = function() {
    const sidebar = document.getElementById("moduleSidebar");
    if (sidebar) {
        const isCompact = sidebar.classList.toggle("compact");
        if (window.innerWidth >= 992) {
            try { localStorage.setItem("ospulso_sidebar_compact", isCompact ? "true" : "false"); } catch(e){}
        }
        window.syncSidebarToggleVisuals(isCompact);
    }
};

document.addEventListener("DOMContentLoaded", function() {
    const avatar = document.getElementById("sidebarAvatarBrand");
    if (avatar && !avatar.getAttribute("data-original-title")) {
        avatar.setAttribute("data-original-title", avatar.title || "");
    }

    // 1. Restaurar preferencia de sidebar compacto exclusivamente en Desktop (>= 992px)
    if (window.innerWidth >= 992) {
        const overlay = document.getElementById("sidebarOverlay");
        if (overlay) overlay.classList.remove("show");
        const isCompact = localStorage.getItem("ospulso_sidebar_compact") === "true";
        const sidebar = document.getElementById("moduleSidebar");
        if (sidebar && isCompact) {
            sidebar.classList.add("compact");
        }
        window.syncSidebarToggleVisuals(isCompact);
    }

    // 2. Auto-cierre en móvil/tableta (< 992px) al pulsar enlaces o botones de navegación
    const sidebarMenu = document.querySelector(".sidebar-menu");
    if (sidebarMenu) {
        sidebarMenu.addEventListener("click", function(e) {
            if (window.innerWidth <= 991) {
                const link = e.target.closest(".sub-link");
                if (link) {
                    const sidebar = document.getElementById("moduleSidebar");
                    const overlay = document.getElementById("sidebarOverlay");
                    if (sidebar && sidebar.classList.contains("show")) {
                        sidebar.classList.remove("show");
                        if (overlay) overlay.classList.remove("show");
                    }
                }
            }
        });
    }

    // 3. Clic en avatar de la cabecera cuando está colapsado
    if (avatar) {
        avatar.addEventListener("click", function() {
            window.handleSidebarBrandClick();
        });
    }

    // 4. Manejo reactivo de redimensionamiento de ventana (Desktop <-> Tablet/Móvil)
    window.addEventListener("resize", function() {
        const sidebar = document.getElementById("moduleSidebar");
        const overlay = document.getElementById("sidebarOverlay");
        if (!sidebar) return;
        if (window.innerWidth <= 991) {
            sidebar.classList.remove("compact");
            window.syncSidebarToggleVisuals(false);
        } else {
            if (overlay) overlay.classList.remove("show");
            if (sidebar) sidebar.classList.remove("show");
            const isCompact = localStorage.getItem("ospulso_sidebar_compact") === "true";
            if (isCompact) {
                sidebar.classList.add("compact");
            }
            window.syncSidebarToggleVisuals(isCompact);
        }
    });

    // 5. Inicializar sistema de tooltips flotantes en modo compacto (Anti-Loop)
    initSidebarTooltips();
});

// Sistema de Tooltips Flotantes para Menú Compacto (Anti-Loop, Ultraligero y Seguro)
window.sidebarFloatingTooltip = window.sidebarFloatingTooltip || null;

function initSidebarTooltips() {
    if (!window.sidebarFloatingTooltip) {
        window.sidebarFloatingTooltip = document.createElement("div");
        window.sidebarFloatingTooltip.className = "sidebar-floating-tooltip";
        document.body.appendChild(window.sidebarFloatingTooltip);
    }

    const sidebar = document.getElementById("moduleSidebar");
    if (!sidebar) return;

    sidebar.addEventListener("mouseenter", function(e) {
        handleTooltipShow(e);
    }, true);

    sidebar.addEventListener("mouseleave", function(e) {
        handleTooltipHide();
    }, true);

    sidebar.addEventListener("mousemove", function(e) {
        handleTooltipShow(e);
    }, true);

    window.addEventListener("scroll", handleTooltipHide, true);

    // Prevención de loops: si se hace clic en un acordeón estando colapsado, expandir
    sidebar.addEventListener("click", function(e) {
        if (sidebar.classList.contains("compact")) {
            const accordBtn = e.target.closest(".accordion-button");
            if (accordBtn) {
                // Expandir inmediatamente para mostrar las opciones completas sin bucles de hover
                window.toggleDesktopSidebar();
            }
        }
    });
}

function handleTooltipShow(e) {
    const sidebar = document.getElementById("moduleSidebar");
    if (!sidebar || !sidebar.classList.contains("compact") || window.innerWidth < 992) {
        handleTooltipHide();
        return;
    }

    const target = e.target.closest(".sub-link, .accordion-button, .avatar-diamond, #btnToggleDesktopSidebar, .btn-sidebar-nav-trigger");
    if (!target || !sidebar.contains(target)) {
        handleTooltipHide();
        return;
    }

    let text = target.getAttribute("data-sidebar-title");
    if (!text && target.title) {
        text = target.title;
        target.setAttribute("data-sidebar-title", text);
        target.removeAttribute("title"); // Evitar colisión con tooltip nativo
    }
    if (!text) {
        const textSpan = target.querySelector(".sidebar-text");
        if (textSpan) text = textSpan.textContent.trim();
    }
    if (!text && target.id === "sidebarAvatarBrand") {
        text = target.getAttribute("data-original-title") || "Menú Principal";
    }

    if (!text || text.length === 0) {
        handleTooltipHide();
        return;
    }

    if (!window.sidebarFloatingTooltip) {
        window.sidebarFloatingTooltip = document.createElement("div");
        window.sidebarFloatingTooltip.className = "sidebar-floating-tooltip";
        document.body.appendChild(window.sidebarFloatingTooltip);
    }

    window.sidebarFloatingTooltip.textContent = text;
    const rect = target.getBoundingClientRect();
    
    window.sidebarFloatingTooltip.style.top = (rect.top + (rect.height / 2) - 14) + "px";
    window.sidebarFloatingTooltip.style.left = (rect.right + 12) + "px";
    window.sidebarFloatingTooltip.classList.add("show");
}

function handleTooltipHide() {
    if (window.sidebarFloatingTooltip) {
        window.sidebarFloatingTooltip.classList.remove("show");
    }
}

document.addEventListener("keydown", function(e) {
    if (e.key === "Escape") {
        const sidebar = document.getElementById("moduleSidebar");
        const overlay = document.getElementById("sidebarOverlay");
        if (sidebar && sidebar.classList.contains("show")) {
            sidebar.classList.remove("show");
            if (overlay) overlay.classList.remove("show");
        }
    }
    // Atajo universal Alt + M para alternar sidebar
    if (e.altKey && (e.key === "m" || e.key === "M")) {
        e.preventDefault();
        if (window.innerWidth >= 992) {
            window.toggleDesktopSidebar();
        } else {
            window.toggleSidebar();
        }
    }
});

function iniciarVinculacionGoogle(idMedico) {
    const clientId = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
    const redirectUri = encodeURIComponent(window.location.origin + "/auth/oauth_callback.pl");
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=https://www.googleapis.com/auth/calendar.events&access_type=offline&prompt=consent&state=${idMedico}`;
    window.open(authUrl, "GoogleAuth", "width=600,height=700");
}

