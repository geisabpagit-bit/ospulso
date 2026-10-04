
document.addEventListener("DOMContentLoaded", function() {
    // 1. Restaurar preferencia de sidebar compacto exclusivamente en Desktop (>= 992px)
    if (window.innerWidth >= 992) {
        const isCompact = localStorage.getItem("ospulso_sidebar_compact") === "true";
        const sidebar = document.getElementById("moduleSidebar");
        if (sidebar && isCompact) {
            sidebar.classList.add("compact");
        }
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

    // 3. Manejo reactivo de redimensionamiento de ventana (Desktop <-> Tablet/Móvil)
    window.addEventListener("resize", function() {
        const sidebar = document.getElementById("moduleSidebar");
        if (!sidebar) return;
        if (window.innerWidth <= 991) {
            sidebar.classList.remove("compact");
        } else {
            const isCompact = localStorage.getItem("ospulso_sidebar_compact") === "true";
            if (isCompact) {
                sidebar.classList.add("compact");
            }
        }
    });
});

document.addEventListener("keydown", function(e) {
    if (e.key === "Escape") {
        const sidebar = document.getElementById("moduleSidebar");
        const overlay = document.getElementById("sidebarOverlay");
        if (sidebar && sidebar.classList.contains("show")) {
            sidebar.classList.remove("show");
            if (overlay) overlay.classList.remove("show");
        }
    }
});

window.toggleSidebar = function() {
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
            localStorage.setItem("ospulso_sidebar_compact", isCompact ? "true" : "false");
        }
    }
};

function iniciarVinculacionGoogle(idMedico) {
    const clientId = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
    const redirectUri = encodeURIComponent(window.location.origin + "/auth/oauth_callback.pl");
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=https://www.googleapis.com/auth/calendar.events&access_type=offline&prompt=consent&state=${idMedico}`;
    window.open(authUrl, "GoogleAuth", "width=600,height=700");
}

