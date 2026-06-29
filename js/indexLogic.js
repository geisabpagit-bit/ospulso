document.addEventListener('DOMContentLoaded', function() {
    // Diferir la inicialización para evitar bloquear el hilo de DOMContentLoaded y prevenir violaciones de Forced Reflow
    setTimeout(function() {
        // --- GESTIÓN DE ÉXITO DE REGISTRO (Diamond Flow) ---
        const urlParams = new URLSearchParams(window.location.search);
        if (urlParams.get('registration') === 'success') {
            const isOAuth = urlParams.get('oauth') === '1';
            const registeredEmail = urlParams.get('email') || 'tu correo';
            const modalTitle = isOAuth ? '¡Registro y Conexión Exitosa!' : '¡Registro Exitoso!';
            const oauthNote = isOAuth ? '<p class="text-success fw-bold small mb-2"><i class="bi bi-google me-1"></i>Sincronización con Google Calendar activada</p>' : '';
            
            const showSuccessModal = () => {
                const successModalHtml = `
                <div class="modal fade" id="regSuccessModal" tabindex="-1" aria-hidden="true">
                    <div class="modal-dialog modal-dialog-centered">
                        <div class="modal-content border-0 shadow-premium" style="border-radius: 2.5rem;">
                            <div class="modal-body text-center p-5">
                                <div class="icon-pulse-container mb-4 mx-auto" style="width: 80px; height: 80px; background: #ecfdf5; color: #00b894; border-radius: 25px; display: flex; align-items: center; justify-content: center; font-size: 2.5rem;">
                                    <i class="bi bi-envelope-check-fill"></i>
                                </div>
                                <h3 class="fw-bold text-navy mb-3">${modalTitle}</h3>
                                ${oauthNote}
                                <p class="text-muted mb-4">Hemos enviado un enlace de activación a:<br><strong class="text-navy">${registeredEmail}</strong></p>
                                <p class="small text-navy-50 mb-4">Por favor, revisa tu bandeja de entrada (y la carpeta de spam) para activar tu consultorio.</p>
                                <button type="button" class="btn-medentia-action w-100 py-3" data-bs-dismiss="modal">Entendido, ir al correo</button>
                            </div>
                        </div>
                    </div>
                </div>`;
                
                document.body.insertAdjacentHTML('beforeend', successModalHtml);
                const modalEl = document.getElementById('regSuccessModal');
                const modalObj = new bootstrap.Modal(modalEl);
                modalObj.show();
                
                // Limpiar la URL sin recargar
                window.history.replaceState({}, document.title, window.location.pathname);
            };

            if (typeof bootstrap !== 'undefined') {
                showSuccessModal();
            } else {
                window.addEventListener('load', showSuccessModal);
            }
        }
        const emailInput = document.getElementById('email');
        const passInput = document.getElementById('password');
        const loginBtn = document.getElementById('loginSubmitBtn');
        const feedbackDiv = document.getElementById('emailFeedback');
        const loginForm = document.getElementById('loginForm');
        const loginCard = document.querySelector('.login-card');
        const overlay = document.getElementById('loadingOverlay');
        const loadingText = overlay.querySelector('p'); // El párrafo dentro del overlay

        // Frases personalizadas para el consultorio
        const dentalQuotes = [
            "Preparando tu agenda del día...",
            "Cargando expedientes clínicos...",
            "Sincronizando inventario dental...",
            "Configurando tu unidad de trabajo...",
            "Verificando citas próximas...",
            "Optimizando tu panel de control..."
        ];

        function updateLoginBtnState() {
            const emailExists = emailInput.dataset.exists === '1';
            const businessActive = emailInput.dataset.businessActive === '1';
            const passValid = passInput.value.trim().length >= 4;
            loginBtn.disabled = !(emailExists && businessActive && passValid);
        }

        // Toggle Password
        document.getElementById('togglePassword').addEventListener('click', function() {
            const isPass = passInput.type === 'password';
            passInput.type = isPass ? 'text' : 'password';
            this.querySelector('i').classList.toggle('bi-eye');
            this.querySelector('i').classList.toggle('bi-eye-slash');
        });

        // Verificación de Correo en Tiempo Real (Debounce)
        let emailTimer;
        emailInput.addEventListener('input', function() {
            clearTimeout(emailTimer);
            const correo = this.value.trim().toLowerCase();
            
            // Reset visual inmediato
            this.classList.remove('is-valid', 'is-invalid');
            feedbackDiv.className = 'form-text mt-1';
            feedbackDiv.textContent = 'Verificando disponibilidad...';
            
            if (!correo || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)) {
                feedbackDiv.textContent = 'Introduce un correo válido.';
                return;
            }

            emailTimer = setTimeout(async () => {
                feedbackDiv.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Buscando cuenta...';
                
                try {
                    const response = await fetch(`auth/check_email.pl?correo=${encodeURIComponent(correo)}`);
                    const data = await response.json();
                    
                    if (data.exists === 1) {
                        emailInput.dataset.exists = '1';
                        const bActive = Number(data.business_active);
                        emailInput.dataset.businessActive = bActive === 0 ? '0' : '1';

                        if (bActive === 0) {
                            emailInput.classList.add('is-invalid');
                            feedbackDiv.className = 'form-text text-danger mt-1 fw-bold';
                            feedbackDiv.innerHTML = '<i class="bi bi-exclamation-octagon-fill"></i> Suscripción Vencida o Cuenta Inactiva.';
                        } else {
                            emailInput.classList.add('is-valid');
                            feedbackDiv.className = 'form-text text-success mt-1';
                            feedbackDiv.textContent = 'Cuenta encontrada. Puedes continuar.';
                        }
                    } else {
                        emailInput.dataset.exists = '0';
                        emailInput.classList.add('is-invalid');
                        feedbackDiv.className = 'form-text text-danger mt-1';
                        feedbackDiv.textContent = 'Este correo no está registrado.';
                    }
                } catch (e) {
                    feedbackDiv.textContent = 'Error de conexión.';
                }
                updateLoginBtnState();
            }, 600); // 600ms de espera tras terminar de teclear
        });

        passInput.addEventListener('input', updateLoginBtnState);

        // Salida cinematográfica con frases aleatorias
        loginForm.addEventListener('submit', function(e) {
            // NOTA: Se elimina e.preventDefault() y setTimeout() para garantizar 
            // compatibilidad con iOS/iPadOS y prevenir el bloqueo del "User Gesture Token".
            
            // Elegir frase aleatoria
            const randomQuote = dentalQuotes[Math.floor(Math.random() * dentalQuotes.length)];
            loadingText.textContent = randomQuote;

            overlay.classList.add('show');
            loginCard.classList.add('animate-exit');
            
            // El navegador procederá a ejecutar el submit nativo síncronamente.
        });

        // Lógica para el modal de recuperación de contraseña (Diamond Refactor)
        const btnRecover = document.getElementById('btnRecoverPassword');
        const recoverForm = document.getElementById('recoverPasswordForm');
        const recoveryEmail = document.getElementById('recoveryEmail');
        const recoveryMsg = document.getElementById('recoveryMessage');

        if (btnRecover) {
            btnRecover.disabled = true; // Deshabilitado por defecto

            recoveryEmail.addEventListener('blur', async function() {
                const email = this.value.trim();
                if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
                    recoveryMsg.innerHTML = '<span class="text-danger small">Correo no válido.</span>';
                    btnRecover.disabled = true;
                    return;
                }

                recoveryMsg.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Verificando...';
                
                try {
                    const response = await fetch(`auth/check_email.pl?correo=${encodeURIComponent(email)}`);
                    const data = await response.json();
                    
                    if (data.exists === 1) {
                        recoveryMsg.innerHTML = '<span class="text-success small"><i class="bi bi-check-circle me-1"></i> Cuenta encontrada.</span>';
                        btnRecover.disabled = false;
                    } else {
                        recoveryMsg.innerHTML = '<span class="text-danger small"><i class="bi bi-exclamation-circle me-1"></i> No existe una cuenta con este correo.</span>';
                        btnRecover.disabled = true;
                    }
                } catch (e) {
                    recoveryMsg.innerHTML = '<span class="text-danger small">Error de conexión.</span>';
                }
            });

            btnRecover.addEventListener('click', async function() {
                const email = recoveryEmail.value.trim();
                btnRecover.disabled = true;
                btnRecover.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span> Enviando...';

                try {
                    const formData = new FormData(recoverForm);
                    const response = await fetch('auth/recuperar_clave.pl', {
                        method: 'POST',
                        body: formData
                    });
                    
                    const data = await response.json();
                    
                    if (data.success) {
                        recoveryMsg.innerHTML = `<span class="text-success fw-bold"><i class="bi bi-send-check me-1"></i> ${data.message}</span>`;
                        setTimeout(() => {
                            const modal = bootstrap.Modal.getInstance(document.getElementById('forgotPasswordModal'));
                            if (modal) modal.hide();
                        }, 3500);
                    } else {
                        recoveryMsg.innerHTML = `<span class="text-danger small">${data.message}</span>`;
                        btnRecover.disabled = false;
                        btnRecover.textContent = 'Enviar enlace';
                    }
                } catch (e) {
                    recoveryMsg.innerHTML = '<span class="text-danger small">Error al enviar enlace.</span>';
                    btnRecover.disabled = false;
                    btnRecover.textContent = 'Enviar enlace';
                }
            });
        }

        // Limpiar modal al cerrar
        const forgotModal = document.getElementById('forgotPasswordModal');
        if (forgotModal) {
            forgotModal.addEventListener('hidden.bs.modal', function () {
                if (recoverForm) recoverForm.reset();
                if (recoveryMsg) recoveryMsg.innerHTML = '';
                if (btnRecover) {
                    btnRecover.disabled = false;
                    btnRecover.textContent = 'Enviar enlace';
                }
            });
        }
    }, 0);
});