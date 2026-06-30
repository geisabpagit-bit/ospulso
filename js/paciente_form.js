document.addEventListener("DOMContentLoaded", () => {
    const initBtn = document.getElementById("btnGuardarPaciente");
    const inputNombre = document.getElementById("nombreCompleto");
    const errorNombre = document.getElementById("errorNombre");
    const inputRfc = document.getElementById("rfc");
    const inputCurp = document.getElementById("curp");
    const inputTelefono = document.getElementById("telefono");

    // LÓGICA DE ACTUALIZACIÓN HÍBRIDA (C vs U)
    const urlParams = new URLSearchParams(window.location.search);
    const accion = urlParams.get('accion') || 'C';
    const editId = urlParams.get('edit_id');

    // Mapeo Dinámico de Interfaz
    const elBreadcrumbInfo  = document.getElementById('breadcrumb-title');
    const elHeroTitle       = document.getElementById('page-hero-title');
    const elHeroSub         = document.getElementById('page-subtitle');
    const btnTextoGuardar   = document.getElementById('btn-text-guardar');

    if (accion === 'U' && editId) {
        // Modo Actualizar
        if (elHeroTitle) elHeroTitle.innerText = "Editar Expediente";
        if (elHeroSub) elHeroSub.innerText = "Modifica los datos que necesites corregir o complementar.";
        if (elBreadcrumbInfo) elBreadcrumbInfo.innerText = "Editando Paciente";
        if (btnTextoGuardar) btnTextoGuardar.innerText = "Actualizar Expediente";
        
        // Fetch patient data string (we know from pacientes_api.pl it's ?accion=get_perfil&id=)
        fetch('../api/pacientes_api.pl?accion=get_perfil&id=' + editId)
            .then(res => res.json())
            .then(data => {
                if (data.ok) {
                    // Update Breadcrumb con nombre real
                    if (elBreadcrumbInfo) elBreadcrumbInfo.innerText = "Editando Expediente de " + data.perfil.nombre;

                    inputNombre.value = data.perfil.nombre;
                    inputRfc.value = data.perfil.rfc || '';
                    inputCurp.value = data.perfil.curp || '';
                    document.getElementById("fechaNac").value = data.perfil.fecha_nac || '';
                    // Need to check for undefined since some fields might miss
                    let dpGen = document.getElementById("genero");
                    if (dpGen) {
                        for(let opt of dpGen.options) {
                            if(opt.value == data.perfil.sexo) dpGen.value = opt.value;
                        }
                    }
                    let dpSangre = document.getElementById("tipoSangre");
                    if (dpSangre) {
                        for(let opt of dpSangre.options) {
                            if(opt.value == data.perfil.tipo_sangre) dpSangre.value = opt.value;
                        }
                    }
                    inputTelefono.value = data.perfil.telefono || '';
                    
                    if (document.getElementById("correo")) document.getElementById("correo").value = data.perfil.correo !== 'No registrado' ? data.perfil.correo : '';
                    if (document.getElementById("nacionalidad")) document.getElementById("nacionalidad").value = data.perfil.nacionalidad || '';
                    if (document.getElementById("ocupacion")) document.getElementById("ocupacion").value = data.perfil.ocupacion || '';
                }
            });
    }


    // 1. VALIDACIÓN EN TIEMPO REAL: Nombre Exclusivamente Alfabético, Acentos y Ñ
    const alphaRegex = /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]*$/;
    inputNombre.addEventListener("input", function(e) {
        if (!alphaRegex.test(this.value)) {
            // Bloquea inyección y revierte al último string válido
            this.value = this.value.replace(/[^a-zA-ZáéíóúÁÉÍÓÚñÑ\s]/g, '');
            errorNombre.classList.remove("hidden");
        } else {
            errorNombre.classList.add("hidden");
        }
    });

    // 2. VALIDACIÓN: RFC Alfanumérico exacto 13 chars front-limit
    inputRfc.addEventListener("input", function() {
        this.value = this.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
    });

    // 3. VALIDACIÓN: CURP Alfanumérica exacto 18 chars front-limit
    inputCurp.addEventListener("input", function() {
        this.value = this.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
    });

    // 4. VALIDACIÓN: Teléfono exclusivo números
    inputTelefono.addEventListener("input", function() {
        this.value = this.value.replace(/[^0-9\+]/g, '');
    });

    // --- MANEJO DEL SUBMIT (FETCH / JSON / PURE UTF-8) ---
    initBtn.addEventListener("click", async (e) => {
        e.preventDefault();

        // Validaciones Finales Previas al Envío
        if (!inputNombre.value.trim() || !inputTelefono.value.trim()) {
            Swal.fire({
                icon: "warning",
                title: "Campos Incompletos",
                text: "Por favor provee al menos el Nombre y Teléfono del paciente para crear el Expediente."
            });
            return;
        }

        // Limit Strict Checks
        if (inputRfc.value && inputRfc.value.length !== 13) {
            Swal.fire("RFC Irregular", "Si decides capturar el RFC, debe contener exactamente 13 caracteres alfanuméricos.", "error");
            return;
        }
        if (inputCurp.value && inputCurp.value.length !== 18) {
            Swal.fire("CURP Irregular", "Si decides capturar la CURP, debe contener exactamente 18 caracteres alfanuméricos.", "error");
            return;
        }

        const btnOriginalText = initBtn.innerHTML;
        initBtn.innerHTML = `<span class="spinner-border spinner-border-sm me-2" role="status"></span> Procesando...`;
        initBtn.disabled = true;

        // Estructura JSON Cuidando UTF-8
        const payload = {
            accion: (accion === 'U' && editId) ? "actualizar" : "crear",
            id: editId || "",
            nombre: inputNombre.value.trim(),
            rfc: inputRfc.value.trim(),
            curp: inputCurp.value.trim(),
            fecha_nac: document.getElementById("fechaNac").value,
            genero: document.getElementById("genero").value,
            estado_civil: document.getElementById("estadoCivil").value,
            telefono: inputTelefono.value.trim(),
            correo: document.getElementById("correo").value.trim(),
            nacionalidad: document.getElementById("nacionalidad").value.trim(),
            ocupacion: document.getElementById("ocupacion").value.trim(),
            tipo_sangre: document.getElementById("tipoSangre").value
        };

        try {
            console.log("=== DEBUG INIT ===");
            console.log("Payload enviado hacia el API:", payload);

            // El Content-Type charset=UTF-8 protege que el payload viaje inalterado desde el browser al Perl STDIN
            const response = await fetch('../api/pacientes_crud_api.pl', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8'
                },
                body: JSON.stringify(payload)
            });

            const data = await response.json();
            console.log("Respuesta del servidor:", data);

            if (data.ok) {
                Swal.fire({
                    icon: "success",
                    title: "¡Expediente Abierto!",
                    text: data.msg,
                    timer: 2000,
                    showConfirmButton: false
                }).then(() => {
                    window.location.href = "pacientes.pl";
                });
            } else {
                Swal.fire("El registro fue rechazado", data.msg || "Ocurrió un error inesperado en la validación.", "error");
                initBtn.disabled = false;
                initBtn.innerHTML = btnOriginalText;
            }
        } catch (error) {
            console.error("Error Fetch API:", error);
            Swal.fire("Falla de Conectividad", "No fue posible comunicarse con el túnel Back-End.", "error");
            initBtn.disabled = false;
            initBtn.innerHTML = btnOriginalText;
        }
    });
});
