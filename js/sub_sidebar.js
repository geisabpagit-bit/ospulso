
document.addEventListener("DOMContentLoaded", function() {
    // Initial bindings if needed
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
    if(sidebar) sidebar.classList.toggle("compact");
};

function iniciarVinculacionGoogle(idMedico) {
    const clientId = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
    const redirectUri = encodeURIComponent(window.location.origin + "/auth/oauth_callback.pl");
    const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=https://www.googleapis.com/auth/calendar.events&access_type=offline&prompt=consent&state=${idMedico}`;
    window.open(authUrl, "GoogleAuth", "width=600,height=700");
}

