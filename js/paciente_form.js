// Helpers globales para toggles de detalle en Antecedentes
window.toggleDetalle = function(selectEl, containerId) {
    const cont = document.getElementById(containerId);
    if (!cont) return;
    if (selectEl.value === 'Sí' || selectEl.value === 'Si') {
        cont.classList.remove('d-none');
    } else {
        cont.classList.add('d-none');
        const input = cont.querySelector('input');
        if (input) input.value = '';
    }
};

window.toggleAlimentacionOtro = function(selectEl) {
    const cont = document.getElementById('pnp_alimentacion_otro_cont');
    if (!cont) return;
    if (selectEl.value === 'Otro') {
        cont.classList.remove('d-none');
    } else {
        cont.classList.add('d-none');
        const input = cont.querySelector('input');
        if (input) input.value = '';
    }
};

document.addEventListener("DOMContentLoaded", () => {
    const initBtn = document.getElementById("btnGuardarPaciente");
    const inputNombre = document.getElementById("nombreCompleto");
    const errorNombre = document.getElementById("errorNombre");
    const inputRfc = document.getElementById("rfc");
    const inputCurp = document.getElementById("curp");
    const inputTelefono = document.getElementById("telefono");
    const inputFechaNac = document.getElementById("fechaNac");

    // LÓGICA DE CÁLCULO DE EDAD Y MOSTRAR TUTOR SI MENOR DE 18 AÑOS
    function calcularEdadJS(fechaNacStr) {
        if (!fechaNacStr) return null;
        const nac = new Date(fechaNacStr + 'T00:00:00');
        if (isNaN(nac.getTime())) return null;
        const hoy = new Date();
        let edad = hoy.getFullYear() - nac.getFullYear();
        const m = hoy.getMonth() - nac.getMonth();
        if (m < 0 || (m === 0 && hoy.getDate() < nac.getDate())) {
            edad--;
        }
        return edad;
    }

    function evaluarEdadYTutor() {
        const fechaVal = inputFechaNac ? inputFechaNac.value : '';
        const edad = calcularEdadJS(fechaVal);
        const lblEdad = document.getElementById("lblEdadCalculada");
        const contTutor = document.getElementById("containerTutor");
        const inputTutor = document.getElementById("responsableTutor");

        if (edad !== null && !isNaN(edad)) {
            if (lblEdad) {
                lblEdad.innerText = `${edad} años` + (edad < 18 ? ' (Menor de edad)' : '');
                lblEdad.className = `badge ${edad < 18 ? 'bg-success-subtle text-success border border-success-subtle' : 'bg-primary text-white'} ms-2`;
                lblEdad.classList.remove('d-none');
            }
            if (edad < 18) {
                if (contTutor) contTutor.classList.remove('d-none');
                if (inputTutor) inputTutor.setAttribute('required', 'required');
            } else {
                if (contTutor) contTutor.classList.add('d-none');
                if (inputTutor) inputTutor.removeAttribute('required');
            }
        } else {
            if (lblEdad) lblEdad.classList.add('d-none');
            if (contTutor) contTutor.classList.add('d-none');
            if (inputTutor) inputTutor.removeAttribute('required');
        }
    }

    if (inputFechaNac) {
        inputFechaNac.addEventListener("change", evaluarEdadYTutor);
        inputFechaNac.addEventListener("input", evaluarEdadYTutor);
    }
    
    // --- VALIDACIÓN DE CORREO EXISTENTE AJAX ---
    const inputCorreo = document.getElementById("correo");
    if (inputCorreo) {
        inputCorreo.addEventListener("blur", function() {
            const val = this.value.trim();
            if (val && val.includes("@")) {
                $.ajax({
                    url: '../api/validar_correo_paciente_api.pl',
                    type: 'POST',
                    data: { correo: val },
                    dataType: 'json',
                    success: function(res) {
                        if(res.existe) {
                            Swal.fire({
                                title: 'Correo ya registrado',
                                text: 'Este correo ya pertenece a una cuenta de Paciente en el sistema. Puedes agregarlo pero compartirá el mismo acceso de usuario.',
                                icon: 'info',
                                toast: true,
                                position: 'top-end',
                                showConfirmButton: false,
                                timer: 5000
                            });
                        }
                    }
                });
            }
        });
    }

    // Helper para poblar select y su campo dependiente
    function setSelectAndToggle(selectId, val, containerId, inputId, inputVal) {
        const sel = document.getElementById(selectId);
        if (!sel) return;
        if (val) sel.value = val;
        if (containerId && inputId) {
            window.toggleDetalle(sel, containerId);
            if (inputVal && document.getElementById(inputId)) {
                document.getElementById(inputId).value = inputVal;
            }
        }
    }

    // LÓGICA DE ACTUALIZACIÓN HÍBRIDA (C vs U)
    const urlParams = new URLSearchParams(window.location.search);
    const editIdValEl = document.getElementById('editIdVal');
    const editId = urlParams.get('edit_id') || urlParams.get('id') || (editIdValEl ? editIdValEl.value : '');
    const accion = (editId && editId !== '') ? 'U' : (urlParams.get('accion') || 'C');

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
        
        fetch('../api/pacientes_api.pl?accion=get_perfil&id=' + editId)
            .then(res => res.json())
            .then(data => {
                if (data.ok) {
                    if (elBreadcrumbInfo) elBreadcrumbInfo.innerText = "Editando Expediente de " + data.perfil.nombre;

                    inputNombre.value = data.perfil.nombre;
                    inputRfc.value = data.perfil.rfc || '';
                    inputCurp.value = data.perfil.curp || '';
                    if (inputFechaNac) inputFechaNac.value = data.perfil.fecha_nac || '';
                    
                    let dpGen = document.getElementById("genero");
                    if (dpGen && data.perfil.sexo) dpGen.value = data.perfil.sexo;
                    
                    let dpSangre = document.getElementById("tipoSangre");
                    if (dpSangre && data.perfil.tipo_sangre) dpSangre.value = data.perfil.tipo_sangre;

                    let dpECivil = document.getElementById("estadoCivil");
                    if (dpECivil && data.perfil.estado_civil) dpECivil.value = data.perfil.estado_civil;
                    
                    inputTelefono.value = data.perfil.telefono || '';
                    if (document.getElementById("correo")) document.getElementById("correo").value = data.perfil.correo !== 'No registrado' ? data.perfil.correo : '';
                    if (document.getElementById("nacionalidad")) document.getElementById("nacionalidad").value = data.perfil.nacionalidad || '';
                    if (document.getElementById("ocupacion")) document.getElementById("ocupacion").value = data.perfil.ocupacion || '';

                    if (data.perfil.tutor && document.getElementById("responsableTutor")) {
                        document.getElementById("responsableTutor").value = data.perfil.tutor;
                    }
                    evaluarEdadYTutor();

                    // Cargar Antecedentes si existen
                    if (data.perfil.antecedentes) {
                        const ant = data.perfil.antecedentes;
                        if (ant.heredofamiliares) {
                            const hf = ant.heredofamiliares;
                            setSelectAndToggle("hf_hipertension", hf.hipertension);
                            setSelectAndToggle("hf_diabetes", hf.diabetes);
                            setSelectAndToggle("hf_cardiopatias", hf.cardiopatias);
                            setSelectAndToggle("hf_cancer", hf.cancer, "hf_cancer_tipo_cont", "hf_cancer_tipo", hf.cancer_tipo);
                            setSelectAndToggle("hf_enfermedades", hf.enfermedades, "hf_enfermedades_esp_cont", "hf_enfermedades_especificar", hf.enfermedades_especificar);
                            setSelectAndToggle("hf_alergias", hf.alergias, "hf_alergias_esp_cont", "hf_alergias_especificar", hf.alergias_especificar);
                        }
                        if (ant.personales_patologicos) {
                            const pp = ant.personales_patologicos;
                            setSelectAndToggle("pp_cronicas", pp.cronicas, "pp_cronicas_esp_cont", "pp_cronicas_especificar", pp.cronicas_especificar);
                            setSelectAndToggle("pp_cirugias", pp.cirugias, "pp_cirugias_esp_cont", "pp_cirugias_especificar", pp.cirugias_especificar);
                            setSelectAndToggle("pp_hospitalizaciones", pp.hospitalizaciones, "pp_hosp_esp_cont", "pp_hospitalizaciones_especificar", pp.hospitalizaciones_especificar);
                            setSelectAndToggle("pp_alergias", pp.alergias, "pp_alergias_esp_cont", "pp_alergias_especificar", pp.alergias_especificar);
                            setSelectAndToggle("pp_tratamientos", pp.tratamientos, "pp_trat_esp_cont", "pp_tratamientos_especificar", pp.tratamientos_especificar);
                        }
                        if (ant.personales_no_patologicos) {
                            const pnp = ant.personales_no_patologicos;
                            setSelectAndToggle("pnp_tabaquismo", pnp.tabaquismo, "pnp_tab_cant_cont", "pnp_tabaquismo_cantidad", pnp.tabaquismo_cantidad);
                            setSelectAndToggle("pnp_alcohol", pnp.alcohol, "pnp_alc_frec_cont", "pnp_alcohol_frecuencia", pnp.alcohol_frecuencia);
                            setSelectAndToggle("pnp_drogas", pnp.drogas, "pnp_drogas_tipo_cont", "pnp_drogas_tipo", pnp.drogas_tipo);
                            setSelectAndToggle("pnp_actividad_fisica", pnp.actividad_fisica, "pnp_act_fisica_cont", "pnp_actividad_fisica_tipo", pnp.actividad_fisica_tipo);
                            if (pnp.alimentacion && document.getElementById("pnp_alimentacion")) {
                                document.getElementById("pnp_alimentacion").value = pnp.alimentacion;
                                window.toggleAlimentacionOtro(document.getElementById("pnp_alimentacion"));
                                if (pnp.alimentacion === 'Otro' && document.getElementById("pnp_alimentacion_otro")) {
                                    document.getElementById("pnp_alimentacion_otro").value = pnp.alimentacion_otro || '';
                                }
                            }
                        }
                        if (ant.domicilio) {
                            const dom = ant.domicilio;
                            if (dom.cp && document.getElementById("cp_paciente")) {
                                document.getElementById("cp_paciente").value = dom.cp;
                                if (window.buscarDomicilioPorCP) {
                                    window.buscarDomicilioPorCP(dom.cp, () => {
                                        if (dom.colonia && document.getElementById("colonia_paciente")) {
                                            document.getElementById("colonia_paciente").value = dom.colonia;
                                        }
                                    });
                                }
                            }
                            if (dom.entidad && document.getElementById("entidad_paciente")) document.getElementById("entidad_paciente").value = dom.entidad;
                            if (dom.municipio && document.getElementById("municipio_paciente")) document.getElementById("municipio_paciente").value = dom.municipio;
                            if (dom.calle && document.getElementById("calle_paciente")) document.getElementById("calle_paciente").value = dom.calle;
                            if (dom.num_ext && document.getElementById("num_ext_paciente")) document.getElementById("num_ext_paciente").value = dom.num_ext;
                            if (dom.num_int && document.getElementById("num_int_paciente")) document.getElementById("num_int_paciente").value = dom.num_int;
                        }
                    }
                }
            });
    }

    // BUSCADOR SEPOMEX POR CP
    window.buscarDomicilioPorCP = function(cp, callback) {
        if (!cp) return;
        const cpClean = cp.replace(/\D/g, '');
        const statusEl = document.getElementById('cpStatus');
        const selectColonia = document.getElementById('colonia_paciente');
        const inputEntidad = document.getElementById('entidad_paciente');
        const inputMunicipio = document.getElementById('municipio_paciente');

        if (cpClean.length !== 5) {
            if (statusEl) statusEl.classList.add('d-none');
            return;
        }

        if (statusEl) {
            statusEl.innerHTML = '<span class="spinner-border spinner-border-sm me-1 text-primary"></span> Consultando SEPOMEX...';
            statusEl.className = 'small mt-1 fw-bold text-muted';
            statusEl.classList.remove('d-none');
        }

        fetch('../api/get_location.pl?cp=' + cpClean)
            .then(res => res.json())
            .then(data => {
                if (data && data.success) {
                    if (inputEntidad && data.entidad) inputEntidad.value = data.entidad;
                    if (inputMunicipio && data.municipio) inputMunicipio.value = data.municipio;
                    
                    if (selectColonia) {
                        const currentVal = selectColonia.value;
                        selectColonia.innerHTML = '<option value="">Seleccione Colonia / Asentamiento...</option>';
                        if (data.localidades && data.localidades.length > 0) {
                            data.localidades.forEach(loc => {
                                const opt = document.createElement('option');
                                opt.value = loc;
                                opt.textContent = loc;
                                selectColonia.appendChild(opt);
                            });
                            if (currentVal) {
                                selectColonia.value = currentVal;
                            } else if (data.localidades.length === 1) {
                                selectColonia.selectedIndex = 1;
                            }
                        }
                    }

                    if (statusEl) {
                        statusEl.innerHTML = '<span class="text-success"><i class="bi bi-check-circle-fill me-1"></i>CP Válido (' + (data.localidades ? data.localidades.length : 0) + ' asentamientos)</span>';
                    }
                } else {
                    if (statusEl) {
                        statusEl.innerHTML = '<span class="text-danger"><i class="bi bi-exclamation-triangle-fill me-1"></i>' + (data.message || 'Código Postal no localizado') + '</span>';
                    }
                }
                if (typeof callback === 'function') callback();
            })
            .catch(err => {
                console.error("Error buscando CP:", err);
                if (statusEl) {
                    statusEl.innerHTML = '<span class="text-danger"><i class="bi bi-exclamation-triangle-fill me-1"></i>Error de conexión al catálogo</span>';
                }
                if (typeof callback === 'function') callback();
            });
    };

    // 1. VALIDACIÓN EN TIEMPO REAL: Nombre Exclusivamente Alfabético, Acentos y Ñ
    const alphaRegex = /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]*$/;
    if (inputNombre) {
        inputNombre.addEventListener("input", function(e) {
            if (!alphaRegex.test(this.value)) {
                this.value = this.value.replace(/[^a-zA-ZáéíóúÁÉÍÓÚñÑ\s]/g, '');
                if (errorNombre) errorNombre.classList.remove("hidden");
            } else {
                if (errorNombre) errorNombre.classList.add("hidden");
            }
        });
    }

    if (inputRfc) {
        inputRfc.addEventListener("input", function() {
            this.value = this.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
        });
    }

    if (inputCurp) {
        inputCurp.addEventListener("input", function() {
            this.value = this.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
        });
    }

    if (inputTelefono) {
        inputTelefono.addEventListener("input", function() {
            this.value = this.value.replace(/[^0-9\+]/g, '');
        });
    }

    // --- MANEJO DEL SUBMIT (FETCH / JSON / PURE UTF-8) ---
    if (initBtn) {
        initBtn.addEventListener("click", async (e) => {
            e.preventDefault();

            if (!inputNombre.value.trim() || !inputTelefono.value.trim()) {
                Swal.fire({
                    icon: "warning",
                    title: "Campos Incompletos",
                    text: "Por favor provee al menos el Nombre y Teléfono del paciente para crear el Expediente."
                });
                return;
            }

            const edadCalc = calcularEdadJS(inputFechaNac ? inputFechaNac.value : '');
            const inputTutor = document.getElementById("responsableTutor");
            if (edadCalc !== null && edadCalc < 18 && inputTutor && !inputTutor.value.trim()) {
                Swal.fire({
                    icon: "warning",
                    title: "Responsable / Tutor Requerido",
                    text: "Para pacientes menores de 18 años, es obligatorio especificar el nombre del Responsable o Tutor."
                });
                return;
            }

            if (inputRfc && inputRfc.value && inputRfc.value.length !== 13) {
                Swal.fire("RFC Irregular", "Si decides capturar el RFC, debe contener exactamente 13 caracteres alfanuméricos.", "error");
                return;
            }
            if (inputCurp && inputCurp.value && inputCurp.value.length !== 18) {
                Swal.fire("CURP Irregular", "Si decides capturar la CURP, debe contener exactamente 18 caracteres alfanuméricos.", "error");
                return;
            }

            const btnOriginalText = initBtn.innerHTML;
            initBtn.innerHTML = `<span class="spinner-border spinner-border-sm me-2" role="status"></span> Procesando...`;
            initBtn.disabled = true;

            const antecedentesPayload = {
                heredofamiliares: {
                    hipertension: document.getElementById("hf_hipertension") ? document.getElementById("hf_hipertension").value : "No",
                    diabetes: document.getElementById("hf_diabetes") ? document.getElementById("hf_diabetes").value : "No",
                    cardiopatias: document.getElementById("hf_cardiopatias") ? document.getElementById("hf_cardiopatias").value : "No",
                    cancer: document.getElementById("hf_cancer") ? document.getElementById("hf_cancer").value : "No",
                    cancer_tipo: document.getElementById("hf_cancer_tipo") ? document.getElementById("hf_cancer_tipo").value.trim() : "",
                    enfermedades: document.getElementById("hf_enfermedades") ? document.getElementById("hf_enfermedades").value : "No",
                    enfermedades_especificar: document.getElementById("hf_enfermedades_especificar") ? document.getElementById("hf_enfermedades_especificar").value.trim() : "",
                    alergias: document.getElementById("hf_alergias") ? document.getElementById("hf_alergias").value : "No",
                    alergias_especificar: document.getElementById("hf_alergias_especificar") ? document.getElementById("hf_alergias_especificar").value.trim() : ""
                },
                personales_patologicos: {
                    cronicas: document.getElementById("pp_cronicas") ? document.getElementById("pp_cronicas").value : "No",
                    cronicas_especificar: document.getElementById("pp_cronicas_especificar") ? document.getElementById("pp_cronicas_especificar").value.trim() : "",
                    cirugias: document.getElementById("pp_cirugias") ? document.getElementById("pp_cirugias").value : "No",
                    cirugias_especificar: document.getElementById("pp_cirugias_especificar") ? document.getElementById("pp_cirugias_especificar").value.trim() : "",
                    hospitalizaciones: document.getElementById("pp_hospitalizaciones") ? document.getElementById("pp_hospitalizaciones").value : "No",
                    hospitalizaciones_especificar: document.getElementById("pp_hospitalizaciones_especificar") ? document.getElementById("pp_hospitalizaciones_especificar").value.trim() : "",
                    alergias: document.getElementById("pp_alergias") ? document.getElementById("pp_alergias").value : "No",
                    alergias_especificar: document.getElementById("pp_alergias_especificar") ? document.getElementById("pp_alergias_especificar").value.trim() : "",
                    tratamientos: document.getElementById("pp_tratamientos") ? document.getElementById("pp_tratamientos").value : "No",
                    tratamientos_especificar: document.getElementById("pp_tratamientos_especificar") ? document.getElementById("pp_tratamientos_especificar").value.trim() : ""
                },
                personales_no_patologicos: {
                    tabaquismo: document.getElementById("pnp_tabaquismo") ? document.getElementById("pnp_tabaquismo").value : "No",
                    tabaquismo_cantidad: document.getElementById("pnp_tabaquismo_cantidad") ? document.getElementById("pnp_tabaquismo_cantidad").value.trim() : "",
                    alcohol: document.getElementById("pnp_alcohol") ? document.getElementById("pnp_alcohol").value : "No",
                    alcohol_frecuencia: document.getElementById("pnp_alcohol_frecuencia") ? document.getElementById("pnp_alcohol_frecuencia").value.trim() : "",
                    drogas: document.getElementById("pnp_drogas") ? document.getElementById("pnp_drogas").value : "No",
                    drogas_tipo: document.getElementById("pnp_drogas_tipo") ? document.getElementById("pnp_drogas_tipo").value.trim() : "",
                    actividad_fisica: document.getElementById("pnp_actividad_fisica") ? document.getElementById("pnp_actividad_fisica").value : "No",
                    actividad_fisica_tipo: document.getElementById("pnp_actividad_fisica_tipo") ? document.getElementById("pnp_actividad_fisica_tipo").value.trim() : "",
                    alimentacion: document.getElementById("pnp_alimentacion") ? document.getElementById("pnp_alimentacion").value : "Balanceada",
                    alimentacion_otro: document.getElementById("pnp_alimentacion_otro") ? document.getElementById("pnp_alimentacion_otro").value.trim() : ""
                },
                domicilio: {
                    cp: document.getElementById("cp_paciente") ? document.getElementById("cp_paciente").value.trim() : "",
                    entidad: document.getElementById("entidad_paciente") ? document.getElementById("entidad_paciente").value.trim() : "",
                    municipio: document.getElementById("municipio_paciente") ? document.getElementById("municipio_paciente").value.trim() : "",
                    colonia: document.getElementById("colonia_paciente") ? document.getElementById("colonia_paciente").value : "",
                    calle: document.getElementById("calle_paciente") ? document.getElementById("calle_paciente").value.trim() : "",
                    num_ext: document.getElementById("num_ext_paciente") ? document.getElementById("num_ext_paciente").value.trim() : "",
                    num_int: document.getElementById("num_int_paciente") ? document.getElementById("num_int_paciente").value.trim() : ""
                }
            };

            const payload = {
                accion: (accion === 'U' && editId) ? "actualizar" : "crear",
                id: editId || "",
                nombre: inputNombre.value.trim(),
                rfc: inputRfc ? inputRfc.value.trim() : "",
                curp: inputCurp ? inputCurp.value.trim() : "",
                fecha_nac: inputFechaNac ? inputFechaNac.value : "",
                genero: document.getElementById("genero") ? document.getElementById("genero").value : "",
                estado_civil: document.getElementById("estadoCivil") ? document.getElementById("estadoCivil").value : "",
                telefono: inputTelefono.value.trim(),
                correo: document.getElementById("correo") ? document.getElementById("correo").value.trim() : "",
                nacionalidad: document.getElementById("nacionalidad") ? document.getElementById("nacionalidad").value.trim() : "",
                ocupacion: document.getElementById("ocupacion") ? document.getElementById("ocupacion").value.trim() : "",
                tipo_sangre: document.getElementById("tipoSangre") ? document.getElementById("tipoSangre").value : "",
                tutor: inputTutor ? inputTutor.value.trim() : "",
                antecedentes: antecedentesPayload
            };

            try {
                const response = await fetch('../api/pacientes_crud_api.pl', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8'
                    },
                    body: JSON.stringify(payload)
                });

                const data = await response.json();

                if (data.ok) {
                    Swal.fire({
                        icon: "success",
                        title: "¡Expediente Guardado!",
                        text: data.msg,
                        timer: 2000,
                        showConfirmButton: false
                    }).then(() => {
                        const fromParam = urlParams.get('from');
                        const returnId = editId || (data.data && data.data.id_paciente) || data.id_paciente || urlParams.get('id');
                        if (fromParam === 'expediente' && returnId) {
                            window.location.href = "render_expediente_clinico.pl?id=" + returnId + "#tab3";
                        } else {
                            window.location.href = "pacientes.pl";
                        }
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
    }
});
