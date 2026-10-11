document.addEventListener('DOMContentLoaded', function() {

    // =================================================================
    // LOGICA DEL MODAL DE RECUPERACION DE CONTRASENA
    // =================================================================

    const recoverEmailInput = document.getElementById('recoverEmail');
    const sendBtn = document.getElementById('sendRecoveryLinkBtn');
    const emailFeedbackDiv = document.getElementById('emailValidationFeedback');
    const recoverForm = document.getElementById('recoverForm');
    const messageDiv = document.getElementById('recoverMessage');
    
    // Referencia al Modal para poder cerrarlo programáticamente
    const forgotModalEl = document.getElementById('forgotPasswordModal');
    let forgotPasswordModal = null;
    if (forgotModalEl && typeof bootstrap !== 'undefined') {
        forgotPasswordModal = bootstrap.Modal.getOrCreateInstance(forgotModalEl);
    }

    // --- Funciones de Utilidad ---
    function isValidEmailFormat(email) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    }

    // --- Validacion de Existencia Asíncrona ---
    async function validarExistenciaCorreo() {
        if (!recoverEmailInput) return false;
        const email = recoverEmailInput.value.trim().toLowerCase();

        if (!email) {
            if (emailFeedbackDiv) {
                emailFeedbackDiv.className = 'form-text mt-1 text-muted';
                emailFeedbackDiv.textContent = 'Ingresa tu correo para verificar la cuenta.';
            }
            if (sendBtn) sendBtn.disabled = true;
            return false;
        }

        if (!isValidEmailFormat(email)) {
            if (emailFeedbackDiv) {
                emailFeedbackDiv.className = 'form-text text-danger mt-1';
                emailFeedbackDiv.textContent = 'Formato de correo no válido.';
            }
            if (sendBtn) sendBtn.disabled = true;
            return false;
        }

        if (emailFeedbackDiv) {
            emailFeedbackDiv.className = 'form-text text-info mt-1';
            emailFeedbackDiv.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Verificando cuenta...';
        }

        try {
            const response = await fetch(`auth/check_email.pl?correo=${encodeURIComponent(email)}`);
            if (!response.ok) {
                throw new Error('HTTP ' + response.status);
            }
            const data = await response.json();

            if (data.exists === 1) {
                recoverEmailInput.dataset.exists = '1';
                if (emailFeedbackDiv) {
                    emailFeedbackDiv.className = 'form-text text-success mt-1 fw-semibold';
                    emailFeedbackDiv.innerHTML = '<i class="bi bi-check-circle-fill me-1"></i> Correo encontrado. Puedes enviar el enlace.';
                }
                if (sendBtn) sendBtn.disabled = false;
                return true;
            } else {
                recoverEmailInput.dataset.exists = '0';
                if (emailFeedbackDiv) {
                    emailFeedbackDiv.className = 'form-text text-danger mt-1 fw-semibold';
                    emailFeedbackDiv.innerHTML = '<i class="bi bi-exclamation-circle-fill me-1"></i> Este correo no está registrado en el sistema.';
                }
                if (sendBtn) sendBtn.disabled = true;
                return false;
            }
        } catch (error) {
            console.error('Error en check_email.pl:', error);
            recoverEmailInput.dataset.exists = '0';
            if (emailFeedbackDiv) {
                emailFeedbackDiv.className = 'form-text text-danger mt-1';
                emailFeedbackDiv.textContent = 'Error de conexión al verificar el correo. Intenta de nuevo.';
            }
            if (sendBtn) sendBtn.disabled = true;
            return false;
        }
    }

    // --- Control del Estado del Boton y Feedback (on input) ---
    if (recoverEmailInput) {
        recoverEmailInput.addEventListener('input', function() {
            if (sendBtn) sendBtn.disabled = true;
            recoverEmailInput.dataset.exists = '0';
            if (messageDiv) {
                messageDiv.classList.add('d-none');
                messageDiv.innerHTML = '';
            }
            if (emailFeedbackDiv) {
                emailFeedbackDiv.className = 'form-text mt-1 text-muted';
                emailFeedbackDiv.textContent = 'Ingresa tu correo para verificar la cuenta.';
            }
        });

        recoverEmailInput.addEventListener('blur', validarExistenciaCorreo);

        recoverEmailInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                if (sendBtn && !sendBtn.disabled) {
                    enviarEnlaceRecuperacion();
                } else {
                    validarExistenciaCorreo();
                }
            }
        });
    }

    // --- Envio del Enlace ---
    async function enviarEnlaceRecuperacion(e) {
        if (e) e.preventDefault();

        if (!recoverEmailInput) return;

        const email = recoverEmailInput.value.trim().toLowerCase();
        if (!email || !isValidEmailFormat(email)) {
            if (emailFeedbackDiv) {
                emailFeedbackDiv.className = 'form-text text-danger mt-1';
                emailFeedbackDiv.textContent = 'Ingresa un correo electrónico válido.';
            }
            return;
        }

        // Si todavía no se verificó existencia, verificar primero
        if (recoverEmailInput.dataset.exists !== '1') {
            const existe = await validarExistenciaCorreo();
            if (!existe) return;
        }

        const urlSendLink = (recoverForm && recoverForm.action) ? recoverForm.action : 'auth/recuperar_clave.pl';

        if (sendBtn) {
            sendBtn.disabled = true;
            sendBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span> Enviando enlace...';
        }

        const bodyParams = new URLSearchParams();
        bodyParams.append('h_correo_recuperacion', email);

        try {
            const response = await fetch(urlSendLink, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
                },
                body: bodyParams.toString()
            });
            const data = await response.json();

            if (messageDiv) {
                messageDiv.className = 'alert alert-success d-flex align-items-center mb-0 mt-3 py-2 px-3 small';
                messageDiv.innerHTML = `<i class="bi bi-check-circle-fill me-2 fs-5 text-success"></i><span>${data.message || 'Enlace de recuperación enviado con éxito.'}</span>`;
                messageDiv.classList.remove('d-none');
            }

            recoverEmailInput.value = '';
            recoverEmailInput.dataset.exists = '0';
            if (emailFeedbackDiv) {
                emailFeedbackDiv.textContent = 'Ingresa tu correo para verificar la cuenta.';
                emailFeedbackDiv.className = 'form-text mt-1 text-muted';
            }

            if (sendBtn) {
                sendBtn.disabled = true;
                sendBtn.innerHTML = '<i class="bi bi-send-check me-1"></i> Enlace Enviado';
            }

            // Cerrar modal automáticamente después de 4.5 segundos
            setTimeout(() => {
                if (forgotPasswordModal) forgotPasswordModal.hide();
                if (messageDiv) {
                    messageDiv.classList.add('d-none');
                    messageDiv.innerHTML = '';
                }
                if (sendBtn) {
                    sendBtn.innerHTML = 'Enviar enlace';
                    sendBtn.disabled = true;
                }
            }, 4500);

        } catch (error) {
            console.error('Fetch error:', error);
            if (messageDiv) {
                messageDiv.className = 'alert alert-danger d-flex align-items-center mb-0 mt-3 py-2 px-3 small';
                messageDiv.innerHTML = '<i class="bi bi-exclamation-triangle-fill me-2 fs-5 text-danger"></i><span>Error de comunicación con el servidor. Intenta de nuevo.</span>';
                messageDiv.classList.remove('d-none');
            }
            if (sendBtn) {
                sendBtn.disabled = false;
                sendBtn.innerHTML = 'Enviar enlace';
            }
        }
    }

    if (recoverForm) {
        recoverForm.addEventListener('submit', enviarEnlaceRecuperacion);
    }

    if (sendBtn) {
        sendBtn.addEventListener('click', function(e) {
            if (!sendBtn.disabled) {
                enviarEnlaceRecuperacion(e);
            }
        });
    }

    // Resetear formulario al cerrar el modal
    if (forgotModalEl) {
        forgotModalEl.addEventListener('hidden.bs.modal', function () {
            if (recoverForm) recoverForm.reset();
            if (recoverEmailInput) recoverEmailInput.dataset.exists = '0';
            if (messageDiv) {
                messageDiv.classList.add('d-none');
                messageDiv.innerHTML = '';
            }
            if (emailFeedbackDiv) {
                emailFeedbackDiv.className = 'form-text mt-1 text-muted';
                emailFeedbackDiv.textContent = 'Ingresa tu correo para verificar la cuenta.';
            }
            if (sendBtn) {
                sendBtn.disabled = true;
                sendBtn.innerHTML = 'Enviar enlace';
            }
        });
    }

});