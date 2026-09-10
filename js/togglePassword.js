document.addEventListener('DOMContentLoaded', function() {

    const newPasswordInput = document.getElementById('newPassword');
    const confirmPasswordInput = document.getElementById('confirmPassword');
    const submitBtn = document.getElementById('submitBtn');
    const mismatchFeedback = document.getElementById('passwordMismatchFeedback');
    const newPasswordFeedback = document.getElementById('newPasswordFeedback'); // Feedback para la longitud
    
    // Requisito: Mínimo de 8 caracteres
    const MIN_LENGTH = 8; 

    // =================================================================
    // FUNCIÓN DE UTILIDAD: Alternar Visibilidad
    // ================================================================
    function setupToggle(toggleId, inputId) {
        const toggle = document.getElementById(toggleId);
        const input = document.getElementById(inputId);

        if (toggle && input) {
            toggle.addEventListener('click', function() {
                const isPassword = input.getAttribute('type') === 'password';
                input.setAttribute('type', isPassword ? 'text' : 'password');
                
                // Alternar icono
                const icon = this.querySelector('i');
                icon.classList.toggle('bi-eye');
                icon.classList.toggle('bi-eye-slash');
            });
        }
    }

    // Aplicar la funcionalidad a ambos campos
    setupToggle('toggleNewPassword', 'newPassword');
    setupToggle('toggleConfirmPassword', 'confirmPassword');


    // =================================================================
    // FUNCIÓN DE VALIDACIÓN PRINCIPAL
    // ================================================================
    function validatePasswords() {
        const newPass = newPasswordInput.value;
        const confirmPass = confirmPasswordInput.value;
        let validLength = false;
        let passwordsMatch = false;

        // --- 1. Validación de Longitud de Nueva Contraseña ---
        if (newPass.length >= MIN_LENGTH) {
            newPasswordInput.classList.remove('is-invalid');
            newPasswordInput.classList.add('is-valid');
            newPasswordFeedback.style.display = 'none';
            validLength = true;
        } else {
            newPasswordInput.classList.remove('is-valid');
            if (newPass.length > 0) {
                 newPasswordInput.classList.add('is-invalid');
                 newPasswordFeedback.style.display = 'block';
            } else {
                 newPasswordInput.classList.remove('is-invalid');
                 newPasswordFeedback.style.display = 'none';
            }
        }
        
        // --- 2. Validación de Coincidencia ---
        if (newPass && confirmPass) {
             if (newPass === confirmPass) {
                confirmPasswordInput.classList.add('is-valid');
                confirmPasswordInput.classList.remove('is-invalid');
                mismatchFeedback.style.display = 'none';
                passwordsMatch = true;
            } else {
                confirmPasswordInput.classList.add('is-invalid');
                confirmPasswordInput.classList.remove('is-valid');
                mismatchFeedback.style.display = 'block';
                passwordsMatch = false;
            }
        } else {
            confirmPasswordInput.classList.remove('is-valid', 'is-invalid');
            mismatchFeedback.style.display = 'none';
        }


        // --- 3. Habilitar/Deshabilitar Botón ---
        // El botón se habilita SOLAMENTE si la longitud es válida Y las contraseñas coinciden.
        if (validLength && passwordsMatch) {
            submitBtn.disabled = false;
        } else {
            submitBtn.disabled = true;
        }
    }

    // =================================================================
    // ASIGNACIÓN DE EVENTOS
    // ================================================================
    
    // Escuchar el evento 'input' para validar mientras el usuario escribe
    newPasswordInput.addEventListener('input', validatePasswords);
    confirmPasswordInput.addEventListener('input', validatePasswords);
    
    // También validar al perder el foco (blur)
    newPasswordInput.addEventListener('blur', validatePasswords);
    confirmPasswordInput.addEventListener('blur', validatePasswords);
    
    // Ejecutar una validación inicial en caso de que el navegador autocomple
    validatePasswords();
});