document.addEventListener('DOMContentLoaded', function () {
  const emailInput = document.getElementById('email');
  const loginBtn = document.getElementById('loginSubmitBtn'); // Usar ID para mayor claridad
  const feedbackDiv = document.getElementById('emailFeedback'); // SELECCIONAR el div que ya existe

  // Pequeña corrección en la expresión regular para que sea más robusta y no necesite doble barra en el JS
  function isValidEmailFormat(email) {
    // Expresión regular estándar para formato básico de email
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  // Evento input: limpiar estado
  emailInput.addEventListener('input', function () {
    loginBtn.disabled = true;
    emailInput.dataset.exists = '0';
    // Quitar clases de validación de Bootstrap
    emailInput.classList.remove('is-valid', 'is-invalid');
    // Resetear el feedback al estado inicial
    feedbackDiv.className = 'form-text mt-1';
    feedbackDiv.textContent = 'Ingresa tu correo para verificar la cuenta.';
  });

  // Evento blur: validar existencia (Lógica alineada con loginScript.js)
  emailInput.addEventListener('blur', function () {
    const correo = emailInput.value.trim().toLowerCase();

    if (!correo) {
      feedbackDiv.className = 'form-text mt-1';
      feedbackDiv.textContent = 'Ingresa tu correo para verificar la cuenta.';
      loginBtn.disabled = true;
      return;
    }

    if (!isValidEmailFormat(correo)) {
      feedbackDiv.className = 'form-text text-danger mt-1';
      feedbackDiv.textContent = 'Formato de correo inválido.';
      loginBtn.disabled = true;
      return;
    }

    // Spinner de verificación (Alineado con loginScript.js)
    feedbackDiv.className = 'form-text text-info mt-1';
    feedbackDiv.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Verificando existencia...';

    fetch(`auth/check_email.pl?correo=${encodeURIComponent(correo)}`)
      .then(response => {
        if (!response.ok) {
          // Captura de errores de HTTP
          throw new Error('Error de red o servidor no disponible: ' + response.status);
        }
        return response.json();
      })
      .then(data => {
        if (data.exists === 1) {
          // Éxito: Correo existe
          emailInput.dataset.exists = '1';
          emailInput.classList.add('is-valid');
          emailInput.classList.remove('is-invalid');
          feedbackDiv.className = 'form-text text-success mt-1';
          feedbackDiv.textContent = 'Correo encontrado. Puedes iniciar sesión.';
          loginBtn.disabled = false; // Habilitar el botón de login
        } else {
          // Fallo: Correo no existe
          emailInput.dataset.exists = '0';
          emailInput.classList.add('is-invalid');
          emailInput.classList.remove('is-valid');
          feedbackDiv.className = 'form-text text-danger mt-1';
          feedbackDiv.textContent = 'Este correo no está registrado en el sistema.';
          loginBtn.disabled = true; // Mantener deshabilitado
        }
      })
      .catch(error => {
        console.error('Error en check_email.pl:', error);
        emailInput.dataset.exists = '0';
        emailInput.classList.add('is-invalid');
        emailInput.classList.remove('is-valid');
        feedbackDiv.className = 'form-text text-danger mt-1';
        feedbackDiv.textContent = 'Error de conexión al verificar el correo. Intenta de nuevo.';
        loginBtn.disabled = true;
      });
  });
});