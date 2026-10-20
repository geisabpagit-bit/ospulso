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
        const loginForm = document.getElementById('premiumLoginForm');
        const loginCard = document.querySelector('.login-card');
        const overlay = document.getElementById('loadingOverlay');
        const loadingText = overlay ? overlay.querySelector('p') : null;

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
        const togglePasswordBtn = document.getElementById('togglePassword');
        if (togglePasswordBtn) {
            togglePasswordBtn.addEventListener('click', function() {
                const isPass = passInput.type === 'password';
                passInput.type = isPass ? 'text' : 'password';
                const eyeIcon = this.querySelector('i');
                if (eyeIcon) {
                    if (isPass) {
                        eyeIcon.className = 'bi bi-eye-fill';
                    } else {
                        eyeIcon.className = 'bi bi-eye-slash-fill';
                    }
                }
            });
        }

        // Verificación de Correo en Tiempo Real (Debounce)
        let emailTimer;
        function verificarCorreo() {
            clearTimeout(emailTimer);
            const correo = emailInput.value.trim().toLowerCase();
            
            // Reset visual inmediato
            emailInput.classList.remove('is-valid', 'is-invalid');
            feedbackDiv.className = 'form-text mt-1';
            feedbackDiv.textContent = 'Verificando disponibilidad...';
            
            if (!correo || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo)) {
                feedbackDiv.textContent = 'Introduce un correo válido.';
                emailInput.dataset.exists = '0';
                updateLoginBtnState();
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
            }, 500); // 500ms de espera tras terminar de teclear
        }

        emailInput.addEventListener('input', verificarCorreo);
        emailInput.addEventListener('change', verificarCorreo);

        // Recordar correos ingresados (localStorage + datalist)
        function cargarCorreosRecordados() {
            try {
                const recents = JSON.parse(localStorage.getItem('ospulso_recent_emails') || '[]');
                const datalist = document.getElementById('recentEmailsList');
                if (datalist && recents.length > 0) {
                    datalist.innerHTML = recents.map(em => `<option value="${em}"></option>`).join('');
                }
                const lastEmail = localStorage.getItem('ospulso_last_email');
                if (lastEmail && (!emailInput.value || emailInput.value.trim() === '')) {
                    emailInput.value = lastEmail;
                    verificarCorreo();
                }
            } catch (err) {}
        }

        const loginModalEl = document.getElementById('loginModal');
        if (loginModalEl) {
            loginModalEl.addEventListener('show.bs.modal', cargarCorreosRecordados);
        }
        cargarCorreosRecordados();

        passInput.addEventListener('input', updateLoginBtnState);

        // Salida cinematográfica con frases aleatorias y almacenamiento del correo
        loginForm.addEventListener('submit', function(e) {
            // Guardar correo para recordarlo en futuros inicios de sesión
            const userEmail = emailInput.value.trim().toLowerCase();
            if (userEmail && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(userEmail)) {
                try {
                    let recents = JSON.parse(localStorage.getItem('ospulso_recent_emails') || '[]');
                    recents = recents.filter(item => item !== userEmail);
                    recents.unshift(userEmail);
                    if (recents.length > 5) recents.pop();
                    localStorage.setItem('ospulso_recent_emails', JSON.stringify(recents));
                    localStorage.setItem('ospulso_last_email', userEmail);
                } catch (err) {}
            }

            // Elegir frase aleatoria
            const randomQuote = dentalQuotes[Math.floor(Math.random() * dentalQuotes.length)];
            if (loadingText) loadingText.textContent = randomQuote;

            if (overlay) overlay.classList.add('show');
            if (loginCard) loginCard.classList.add('animate-exit');
            
            // El navegador procederá a ejecutar el submit nativo síncronamente.
        });
    }, 0);

    // --- LÓGICA DE INTERFAZ 5S (SIDEBAR MÓVIL, CALCULADORA Y SCROLL REVEAL) ---
    // 1. Sidebar Móvil
    const openBtn = document.getElementById('openMobileMenu');
    const closeBtn = document.getElementById('closeMobileMenu');
    const sidebar = document.getElementById('mobileSidebar');
    const navOverlay = document.getElementById('sidebarOverlay');

    function toggleSidebar() {
        if (!sidebar || !navOverlay) return;
        sidebar.classList.toggle('open');
        navOverlay.classList.toggle('show');
        document.body.style.overflow = sidebar.classList.contains('open') ? 'hidden' : '';
    }

    if (openBtn) openBtn.addEventListener('click', toggleSidebar);
    if (closeBtn) closeBtn.addEventListener('click', toggleSidebar);
    if (navOverlay) navOverlay.addEventListener('click', toggleSidebar);

    document.querySelectorAll('.sidebar-nav-link').forEach(link => {
        link.addEventListener('click', toggleSidebar);
    });

    // 2. Calculadora de Eficiencia Clínica (Gamificada)
    const citasSlider = document.getElementById('citasSlider');
    const citasValue = document.getElementById('citasValue');
    const savedHoursVal = document.getElementById('savedHoursVal');
    const recoveredMoneyVal = document.getElementById('recoveredMoneyVal');

    function updateEfficiencyCalc() {
        if (!citasSlider) return;
        const citas = parseInt(citasSlider.value, 10);
        if (citasValue) citasValue.textContent = citas;
        
        // Métricas en positivo:
        const recoveredAppointments = Math.round(citas * 0.24);
        const recoveredMoney = recoveredAppointments * 1200; 
        const savedHours = Math.round(citas * 0.3); // 30% del volumen = horas ahorradas en admin

        if (savedHoursVal) {
            savedHoursVal.textContent = savedHours + " hrs";
            savedHoursVal.classList.remove('animate__animated', 'animate__headShake');
            void savedHoursVal.offsetWidth;
            savedHoursVal.classList.add('animate__animated', 'animate__headShake');
        }

        if (recoveredMoneyVal) {
            recoveredMoneyVal.textContent = `$${recoveredMoney.toLocaleString('es-MX')} MXN`;
            recoveredMoneyVal.classList.remove('animate__animated', 'animate__headShake');
            void recoveredMoneyVal.offsetWidth;
            recoveredMoneyVal.classList.add('animate__animated', 'animate__headShake');
        }
    }

    if (citasSlider) {
        citasSlider.addEventListener('input', updateEfficiencyCalc);
        updateEfficiencyCalc();
    }

    // 3. Scroll Reveal Observer
    const observerOptions = { root: null, rootMargin: '0px', threshold: 0.15 };
    const revealObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    document.querySelectorAll('.scroll-reveal').forEach(el => {
        revealObserver.observe(el);
    });
});