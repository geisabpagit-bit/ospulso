let modalCitaBootstrap = null;

document.addEventListener('DOMContentLoaded', function () {
    const modalEl = document.getElementById('modalCita');
    if (modalEl && window.bootstrap) {
        modalCitaBootstrap = new bootstrap.Modal(modalEl);
    }
});

/* ============================
   UTILIDADES
============================ */

function mostrarError(msg) {
    let alerta = document.getElementById("cita_alerta");
    alerta.textContent = msg;
    alerta.classList.remove("d-none");
}

function limpiarError() {
    let alerta = document.getElementById("cita_alerta");
    alerta.textContent = "";
    alerta.classList.add("d-none");
}

/* ============================
   NUEVA CITA
============================ */

function abrirModalNuevaCita(fecha, horaIni, horaFin) {
    limpiarError();

    document.getElementById('formCita').reset();
    document.getElementById('cita_id_cita').value = "";
    document.getElementById('modalCitaLabel').textContent = "Nueva cita";
    document.getElementById('btnGuardarCita').textContent = "Guardar cita";

    document.getElementById('cita_fecha').value = fecha;
    document.getElementById('cita_hora_ini').value = horaIni;
    document.getElementById('cita_hora_fin').value = horaFin;

    document.getElementById('cita_id_medico').value = window.idMedicoSesion;

    if (window.pacientePreID) {
        document.getElementById('cita_id_paciente').value = window.pacientePreID;
        document.getElementById('cita_nombre_paciente').value = window.pacientePreNombre;
        document.getElementById('cita_nombre_paciente').disabled = true;
    } else {
        document.getElementById('cita_nombre_paciente').value = "";
        document.getElementById('cita_nombre_paciente').disabled = false;
    }

    modalCitaBootstrap.show();
}

/* ============================
   EDITAR CITA
============================ */

function editarCita(idCita) {
    limpiarError();

    let cita = window.citasDia.find(c => c.id_cita === idCita);
    if (!cita) return;

    document.getElementById('cita_id_cita').value = cita.id_cita;
    document.getElementById('cita_fecha').value = cita.fecha;
    document.getElementById('cita_hora_ini').value = cita.hora_ini;
    document.getElementById('cita_hora_fin').value = cita.hora_fin;
    document.getElementById('cita_motivo').value = cita.motivo;
    document.getElementById('cita_notas').value = cita.notas;
    document.getElementById('cita_estado').value = cita.estado;
    document.getElementById('cita_id_medico').value = cita.id_medico;
    document.getElementById('cita_id_paciente').value = cita.id_paciente;

    document.getElementById('cita_nombre_paciente').value = cita.nombre || "Paciente";
    document.getElementById('cita_nombre_paciente').disabled = true;

    document.getElementById('modalCitaLabel').textContent = "Editar cita";
    document.getElementById('btnGuardarCita').textContent = "Actualizar cita";

    modalCitaBootstrap.show();
}

/* ============================
   GUARDAR / ACTUALIZAR
============================ */


function guardarCita() {
    limpiarError();

    let idCita = document.getElementById("cita_id_cita").value;

    if (idCita) {
        actualizarCita();
    } else {
        crearCita();
    }
}


function crearCita() {
    let form = document.getElementById("formCita");
    let formData = new FormData(form);
    formData.append("accion", "create");

    fetch("citas_crud.pl", {
        method: "POST",
        body: formData
    })
        .then(r => r.json())
        .then(resp => {
            if (!resp.ok) {
                mostrarError(resp.msg);
                console.log(resp.msg);
                return;
            }
            window.location.reload();
        })
        .catch(() => mostrarError("Error de comunicación con el servidor"));
}

function actualizarCita() {
    let form = document.getElementById("formCita");
    let formData = new FormData(form);
    formData.append("accion", "update");

    fetch("citas_crud.pl", {
        method: "POST",
        body: formData
    })
        .then(r => r.json())
        .then(resp => {
            if (!resp.ok) {
                mostrarError(resp.msg);
                console.log(resp.msg);
                return;
            }
            window.location.reload();
        })
        .catch(() => mostrarError("Error de comunicación con el servidor"));
}


window.eliminarCita = function(idCita) {
    if (!confirm("¿Eliminar esta cita?")) return;

    fetch("citas_crud.pl?accion=delete&id_cita=" + encodeURIComponent(idCita))
        .then(r => r.json())
        .then(data => {
            if (data.ok) {
                location.reload();
            } else {
                alert("Error: " + data.msg);
            }
        });
};
