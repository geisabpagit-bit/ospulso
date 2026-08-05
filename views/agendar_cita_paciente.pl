#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";

require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'render_error_sesion.pl');
use utils::db_manager qw(leer_tabla);

my $session_data = check_session();
my $q = $session_data->{q};

if (!$session_data->{session_ok} || $session_data->{role} ne 'Paciente') {
    render_error_sesion();
    exit;
}

my $correo_pac = lc($session_data->{uid});
$correo_pac =~ s/^\s+|\s+$//g;

# Obtener los médicos/clínicas a los que pertenece el paciente
my $archivo_pacientes = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $regs = leer_tabla($archivo_pacientes, '\|');

my %mis_medicos = ();
if ($regs) {
    foreach my $p (@$regs) {
        next if @$p < 6;
        my $c = lc($p->[5] // '');
        $c =~ s/^\s+|\s+$//g;
        if ($c eq $correo_pac) {
            my $id_medico = $p->[1] // '';
            my $tenant = $p->[13] // '';
            my $nombre_paciente = $p->[2] // '';
            my $id_paciente = $p->[0] // '';
            $mis_medicos{$id_medico} = { tenant => $tenant, nombre_paciente => $nombre_paciente, id_paciente => $id_paciente };
        }
    }
}

# Obtener nombres de los médicos
my $archivo_usuarios = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
my $usuarios = leer_tabla($archivo_usuarios, '!');
my @opciones_medicos = ();

if ($usuarios) {
    foreach my $u (@$usuarios) {
        if (exists $mis_medicos{$u->[0]}) {
            push @opciones_medicos, {
                id => $u->[0],
                nombre => $u->[1],
                id_paciente => $mis_medicos{$u->[0]}->{id_paciente}
            };
        }
    }
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario => $session_data->{usuario},
    titulo => 'Agendar Cita - OSPulso',
    ruta_logout => '../auth/cerrar_sesion.pl',
    role => $session_data->{role},
    skip_header => 1
);

print <<HTML;
<div class="sdm-layout-wrapper">
    <!-- Sidebar -->
HTML
utils::sub_sidebar::render_sidebar(
    usuario => $session_data->{usuario},
    role => $session_data->{role},
    pagina_actual => 'mis_citas'
);

print <<HTML;
    <main class="sdm-main-content">
        <!-- Header -->
        <header class="sdm-top-header d-flex justify-content-between align-items-center mb-4">
            <h4 class="mb-0 fw-bold"><i class="bi bi-calendar-plus text-primary me-2"></i> Agendar Cita</h4>
        </header>
        <div class="container container-mobile-flush mt-3 pb-5">
            <div class="row justify-content-center card-mobile-flush">
                <div class="col-12 col-md-10 col-lg-10 col-xl-8">
                    <div class="card shadow-sm border-0 rounded-4 p-4 p-lg-5 mobile-edge-to-edge">
                        <form id="formNuevaCita">
                            <div class="mb-4">
                                <label class="form-label fw-bold text-secondary" style="letter-spacing: 0.5px; font-size: 0.85rem;"><i class="bi bi-person-badge me-2"></i>ESPECIALISTA / CLÍNICA</label>
                                <select class="form-select form-select-lg shadow-sm" id="f_medico" style="border-radius: 0.75rem; font-size: 1rem;" required>
                                    <option value="">Seleccione su médico...</option>
HTML

foreach my $m (@opciones_medicos) {
    print qq{<option value="$m->{id}" data-idpac="$m->{id_paciente}">$m->{nombre}</option>\n};
}

if (@opciones_medicos == 0) {
    print qq{<option value="" disabled>No está registrado con ningún médico aún.</option>};
}

print <<HTML;
                                </select>
                            </div>
                            
                            <div class="mb-4">
                                <label class="form-label fw-bold text-secondary" style="letter-spacing: 0.5px; font-size: 0.85rem;"><i class="bi bi-calendar-event me-2"></i>FECHA DESEADA</label>
                                <input type="date" class="form-control form-control-lg shadow-sm" id="f_fecha" style="border-radius: 0.75rem; font-size: 1rem;" required min="@{[ sprintf('%04d-%02d-%02d', (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3]) ]}">
                            </div>
                            
                            <div class="mb-4">
                                <label class="form-label fw-bold text-secondary" style="letter-spacing: 0.5px; font-size: 0.85rem;"><i class="bi bi-clock me-2"></i>HORARIO</label>
                                <select class="form-select form-select-lg shadow-sm" id="f_horario" style="border-radius: 0.75rem; font-size: 1rem;" required disabled>
                                    <option value="">Seleccione una fecha primero...</option>
                                </select>
                            </div>

                            <div class="mb-4">
                                <label class="form-label fw-bold text-secondary" style="letter-spacing: 0.5px; font-size: 0.85rem;"><i class="bi bi-chat-text me-2"></i>MOTIVO DE CONSULTA</label>
                                <textarea class="form-control form-control-lg shadow-sm" id="f_motivo" rows="3" style="border-radius: 0.75rem; font-size: 1rem;" required placeholder="Ej. Revisión general, dolor de cabeza..."></textarea>
                            </div>
                            
                            <div class="d-flex flex-column flex-md-row justify-content-between align-items-stretch align-items-md-center gap-3 mt-5">
                                <a href="mis_citas.pl" class="btn btn-outline-secondary btn-lg order-2 order-md-1" style="border-radius: 0.75rem;"><i class="bi bi-x-circle fs-5 me-2"></i> Cancelar</a>
                                <button type="submit" class="btn btn-primary btn-lg order-1 order-md-2" style="border-radius: 0.75rem;"><i class="bi bi-check2-circle fs-5 me-2"></i> Confirmar Cita</button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </main>
</div>
HTML
render_bottom_nav('mis_citas');

print <<HTML;
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script>
document.addEventListener('DOMContentLoaded', function() {
    const medicoSelect = document.getElementById('f_medico');
    const fechaInput = document.getElementById('f_fecha');
    const horarioSelect = document.getElementById('f_horario');
    
    fechaInput.addEventListener('change', function() {
        if (!this.value || !medicoSelect.value) return;
        horarioSelect.innerHTML = '<option value="">Cargando horarios...</option>';
        horarioSelect.disabled = true;
        
        // Simular carga de horarios disponibles
        setTimeout(() => {
            horarioSelect.innerHTML = `
                <option value="">Seleccione un horario disponible</option>
                <option value="09:00">09:00 AM - 09:30 AM</option>
                <option value="09:30">09:30 AM - 10:00 AM</option>
                <option value="10:00">10:00 AM - 10:30 AM</option>
                <option value="11:00">11:00 AM - 11:30 AM</option>
                <option value="12:00">12:00 PM - 12:30 PM</option>
                <option value="16:00">04:00 PM - 04:30 PM</option>
                <option value="17:00">05:00 PM - 05:30 PM</option>
            `;
            horarioSelect.disabled = false;
        }, 500);
    });
    
    medicoSelect.addEventListener('change', function() {
        if (fechaInput.value) {
            fechaInput.dispatchEvent(new Event('change'));
        }
    });

    document.getElementById('formNuevaCita').addEventListener('submit', function(e) {
        e.preventDefault();
        
        const id_medico = medicoSelect.value;
        const id_paciente = medicoSelect.options[medicoSelect.selectedIndex].getAttribute('data-idpac');
        const fecha = fechaInput.value;
        const hora_ini = horarioSelect.value;
        
        if(!hora_ini) {
            Swal.fire('Error', 'Seleccione un horario válido', 'error');
            return;
        }
        
        // Calcular hora_fin (30 mins por defecto para paciente)
        const [h, m] = hora_ini.split(':').map(Number);
        let mFin = m + 30;
        let hFin = h;
        if(mFin >= 60) {
            hFin++;
            mFin -= 60;
        }
        const hora_fin = String(hFin).padStart(2, '0') + ':' + String(mFin).padStart(2, '0');
        
        const formData = new FormData();
        formData.append('accion', 'create');
        formData.append('id_medico', id_medico);
        formData.append('id_paciente', id_paciente);
        formData.append('fecha', fecha);
        formData.append('hora_ini', hora_ini);
        formData.append('hora_fin', hora_fin);
        formData.append('motivo', document.getElementById('f_motivo').value);
        formData.append('tipo', 'Consulta General de Valoración');
        formData.append('estado', 'Programada');
        
        fetch('../api/citas_crud.pl', {
            method: 'POST',
            body: formData
        })
        .then(res => res.json())
        .then(data => {
            if(data.success) {
                Swal.fire({
                    icon: 'success',
                    title: '¡Cita Agendada!',
                    text: 'Su cita ha sido programada con éxito.',
                    timer: 2000,
                    showConfirmButton: false
                }).then(() => {
                    window.location.href = 'mis_citas.pl';
                });
            } else {
                Swal.fire('Error', data.message || 'No se pudo agendar la cita', 'error');
            }
        })
        .catch(err => {
            Swal.fire('Error', 'Error de comunicación con el servidor', 'error');
        });
    });
});
</script>
HTML
render_footer();
1;
