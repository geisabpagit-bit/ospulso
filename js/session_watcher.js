/**
 * js/session_watcher.js
 * Control de Sesiones Inactivas (Step 13)
 * Protege la sesión si el usuario queda inactivo.
 */

const SessionWatcher = {
    timeoutMs: 30 * 60 * 1000, // 30 minutos totales para expiración
    warningMs: 25 * 60 * 1000, // 25 minutos para mostrar aviso
    timer: null,
    warningTimer: null,
    isWarning: false,

    init: function() {
        this.resetTimers();
        this.bindEvents();
    },

    bindEvents: function() {
        const events = ['mousemove', 'keydown', 'scroll', 'click', 'touchstart'];
        const debounceReset = this.debounce(() => this.resetTimers(), 1000); // 1 sec debounce
        events.forEach(evt => document.addEventListener(evt, debounceReset, { passive: true }));
    },

    resetTimers: function() {
        if(this.isWarning) return; // Bloquear resets si ya se muestra el modal
        
        clearTimeout(this.timer);
        clearTimeout(this.warningTimer);

        this.warningTimer = setTimeout(() => this.showWarning(), this.warningMs);
        this.timer = setTimeout(() => this.expireSession(), this.timeoutMs);
    },

    showWarning: function() {
        this.isWarning = true;
        if (typeof Swal !== 'undefined') {
            Swal.fire({
                title: 'Sesión por Expirar',
                text: 'Por seguridad, cerraremos tu sesión debido a inactividad. ¿Deseas mantenerla activa?',
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#3085d6',
                cancelButtonColor: '#d33',
                confirmButtonText: 'Mantener Sesión',
                cancelButtonText: 'Cerrar Ahora',
                timer: this.timeoutMs - this.warningMs,
                timerProgressBar: true,
                allowOutsideClick: false
            }).then((result) => {
                if (result.isConfirmed) {
                    this.renewSession();
                } else if (result.dismiss === Swal.DismissReason.timer || result.dismiss === Swal.DismissReason.cancel) {
                    this.expireSession();
                }
            });
        } else {
            // Fallback si SweetAlert2 no está cargado
            this.expireSession();
        }
    },

    renewSession: function() {
        // Ping simple al servidor para renovar la cookie/sesión en backend
        fetch('../auth/check_session.pl')
            .then(() => {
                this.isWarning = false;
                this.resetTimers();
            })
            .catch(() => {
                // Si el backend no responde, podría ser que ya se cayó la red o la sesión murió de todos modos
                this.expireSession();
            });
    },

    expireSession: function() {
        // Eliminar cookies del cliente por seguridad o simplemente redirigir al logout
        window.location.replace('../index.html'); // Logout implícito para redireccionar al login
    },

    debounce: function(func, wait) {
        let timeout;
        return function(...args) {
            clearTimeout(timeout);
            timeout = setTimeout(() => func.apply(this, args), wait);
        };
    }
};

// Auto-iniciar al cargar el DOM
document.addEventListener('DOMContentLoaded', () => {
    SessionWatcher.init();
});
