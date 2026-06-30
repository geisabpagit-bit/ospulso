document.addEventListener('DOMContentLoaded', function() {

    // =================================================================
    // 1. LOGICA DEL LOGIN PRINCIPAL (Mostrar/Ocultar Contrasena)
    // ================================================================

    const togglePassword = document.getElementById('togglePassword');
    const passwordInput = document.getElementById('password');

    if (togglePassword && passwordInput) {
        togglePassword.addEventListener('click', function() {
            // Cambia el tipo de input entre 'password' y 'text'
            const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
            passwordInput.setAttribute('type', type);

            // Cambia el icono del ojo
            const icon = this.querySelector('i');
            icon.classList.toggle('bi-eye');
            icon.classList.toggle('bi-eye-slash');
        });
    }

    // =================================================================
    // 2. LOGICA DEL MODAL DE RECUPERACION DE CONTRASENA
    // =================================================================

    const recoverEmailInput = document.getElementById('recoverEmail');
    const sendBtn = document.getElementById('sendRecoveryLinkBtn');
    const emailFeedbackDiv = document.getElementById('emailValidationFeedback');
    const recoverForm = document.getElementById('recoverForm');
    const messageDiv = document.getElementById('recoverMessage');
    
    // Referencia al Modal para poder cerrarlo programáticamente
    const forgotPasswordModal = new bootstrap.Modal(document.getElementById('forgotPasswordModal'));


    // --- Funciones de Utilidad ---
    function isValidEmailFormat() {
        // Usa la validacion nativa del navegador para el formato
        return recoverEmailInput.checkValidity(); 
    }

    // --- Control del Estado del Boton y Feedback (on input) ---
    if (recoverEmailInput) {
        recoverEmailInput.addEventListener('input', function() {
            sendBtn.disabled = true;
            recoverEmailInput.dataset.exists = '0'; // Resetear estado de existencia
            messageDiv.classList.add('d-none'); // Ocultar mensaje de exito/error anterior
            emailFeedbackDiv.className = 'form-text mt-1';
            emailFeedbackDiv.textContent = 'Ingresa tu correo para verificar la cuenta.';
        });

        // --- Validacion de Existencia (on blur) ---
        recoverEmailInput.addEventListener('blur', function() {
            const email = recoverEmailInput.value.trim();

            if (!email) {
                emailFeedbackDiv.className = 'form-text mt-1';
                emailFeedbackDiv.textContent = 'Ingresa tu correo para verificar la cuenta.';
                sendBtn.disabled = true;
                return;
            }

            if (!isValidEmailFormat()) {
                emailFeedbackDiv.className = 'form-text text-danger mt-1';
                emailFeedbackDiv.textContent = 'Formato de correo invalido.';
                sendBtn.disabled = true;
                return;
            }

            // Muestra indicador de verificacion
            emailFeedbackDiv.className = 'form-text text-info mt-1';
            emailFeedbackDiv.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Verificando existencia...';

            // 🚩 Linea de FETCH con template literal revisada
            fetch(`check_email.pl?correo=${encodeURIComponent(email)}`)
            .then(response => {
                if (!response.ok) {
                    // Esto atrapa errores de HTTP (404, 500, etc.)
                    throw new Error('Error de red o servidor no disponible: ' + response.status);
                }
                return response.json();
            })
            .then(data => {
                if (data.exists === 1) {
                    // Exito: Correo existe
                    recoverEmailInput.dataset.exists = '1';
                    emailFeedbackDiv.className = 'form-text text-success mt-1';
                    emailFeedbackDiv.textContent = 'Correo encontrado. Puedes enviar el enlace.';
                    sendBtn.disabled = false; // Habilitar boton
                } else {
                    // Fallo: Correo no existe
                    recoverEmailInput.dataset.exists = '0';
                    emailFeedbackDiv.className = 'form-text text-danger mt-1';
                    emailFeedbackDiv.textContent = 'Este correo no esta registrado en el sistema.';
                    sendBtn.disabled = true; // Mantener deshabilitado
                }
            })
            .catch(error => {
                console.error('Error en check_mail.pl:', error);
                recoverEmailInput.dataset.exists = '0';
                emailFeedbackDiv.className = 'form-text text-danger mt-1';
                emailFeedbackDiv.textContent = 'Error de conexión al verificar el correo. Intenta de nuevo.';
                sendBtn.disabled = true;
            });
        });
    }


    // --- Envio del Formulario (Submit) ---
    if (recoverForm) {
        recoverForm.addEventListener('submit', function(e) {
            e.preventDefault();

            // Verificacion final del estado
            if (sendBtn.disabled || recoverEmailInput.dataset.exists !== '1') {
                alert("Por favor, verifica el correo electronico y espera la confirmacion de existencia antes de continuar.");
                return;
            }
            
            const urlSendLink = recoverForm.action;
            const email = recoverEmailInput.value.trim();
            
            sendBtn.disabled = true;
            sendBtn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Enviando enlace...';

            // Llama a recuperar_clave.pl
            const formData = new FormData();
            formData.append('h_correo_recuperacion', email); 

            fetch(urlSendLink, {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                messageDiv.textContent = data.message;
                
                // Usamos siempre alert-success por el mensaje de seguridad
                messageDiv.classList.remove('alert-danger');
                messageDiv.classList.add('alert-success'); 
                messageDiv.classList.remove('d-none');
                
                // Limpiamos el campo y volvemos a deshabilitar el boton
                recoverEmailInput.value = '';
                recoverEmailInput.dataset.exists = '0';
                emailValidationFeedback.textContent = 'Ingresa tu correo para verificar la cuenta.';
                emailValidationFeedback.className = 'form-text mt-1';
                
                sendBtn.disabled = true;
                sendBtn.innerHTML = '<i class="bi bi-envelope-fill me-1"></i> Enviar enlace';
                
                // 🚀 NUEVA LÓGICA: Esperar 5 segundos y cerrar el modal
                setTimeout(() => {
                    forgotPasswordModal.hide();
                }, 5000); // 5000 milisegundos = 5 segundos

            })
            .catch(error => {
                console.error('Fetch error:', error);
                messageDiv.textContent = 'Error de comunicacion con el servidor de recuperacion. Intenta mas tarde.';
                messageDiv.classList.remove('alert-success');
                messageDiv.classList.add('alert-danger');
                messageDiv.classList.remove('d-none');
                sendBtn.disabled = false;
                sendBtn.innerHTML = '<i class="bi bi-envelope-fill me-1"></i> Enviar enlace';
            });
        });
    }

});