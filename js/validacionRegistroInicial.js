// Archivo: /js/validacionRegistroInicial.js

(function () {
  'use strict' // Esto ayuda a escribir código JavaScript más limpio y seguro.

  // 1. Obtener todos los formularios a los que queremos aplicar estilos de validación personalizados
  var forms = document.querySelectorAll('.needs-validation')

  // 2. Convertir los formularios en un Array y luego iterar sobre ellos
  Array.prototype.slice.call(forms)
    .forEach(function (form) {
      // 3. Adjuntar un 'event listener' al evento 'submit' (envío) del formulario
      form.addEventListener('submit', function (event) {
        
        // Obtenemos los campos de contraseña
        const clave = document.getElementById('adminClave');
        const claveConfirm = document.getElementById('adminClaveConfirm');
        const feedbackConfirm = document.getElementById('confirmClaveFeedback');

        // Reiniciamos la validación custom para la confirmación de contraseña
        claveConfirm.setCustomValidity(''); 
        
        // 4. Validación de Contraseñas Personalizada: Checar que coincidan
        // Solo checamos la coincidencia, si el formato es malo (longitud, !) ya lo validó HTML5/Pattern.
        if (clave.value !== claveConfirm.value) {
            // Si las contraseñas no coinciden
            claveConfirm.setCustomValidity('Las contraseñas no coinciden.');
            feedbackConfirm.textContent = 'Las contraseñas deben ser idénticas.';
            // Forzamos el estado de error en el campo (Aunque Bootstrap lo hace, es buena práctica)
            claveConfirm.classList.add('is-invalid'); 
        } else {
            // Si las contraseñas coinciden
            claveConfirm.setCustomValidity(''); // Mensaje vacío = OK
            feedbackConfirm.textContent = 'Debe confirmar su contraseña.'; // Restaurar mensaje por defecto
            claveConfirm.classList.remove('is-invalid');
        }

        // 5. Verificar la validez general del formulario
        if (!form.checkValidity()) {
          // Si NO es válido (incluyendo la validación custom de clave), detenemos el envío
          event.preventDefault()
          event.stopPropagation()
        }

        // 6. Agregamos la clase 'was-validated' para mostrar el feedback de error/éxito
        form.classList.add('was-validated')
      }, false)
    })
})()