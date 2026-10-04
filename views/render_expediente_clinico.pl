#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(decode_json encode_json);
use FindBin;
use lib "$FindBin::Bin/..";
use File::Spec;

# --- CONFIGURACIÓN DE RUTAS ABSOLUTAS (Protocolo 11.1) ---
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();

# Redireccionar si no hay sesión
if (!$session_data->{session_ok}) {
    print $q->header(-type => 'text/html', -charset => 'UTF-8');
    print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Sesión Expirada</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght\@400;600;800&display=swap" rel="stylesheet">
</head>
<body>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            Swal.fire({
                title: 'Sesión Expirada',
                text: 'Por seguridad, tu sesión ha terminado. Serás redirigido al inicio.',
                icon: 'warning',
                confirmButtonText: 'Aceptar',
                confirmButtonColor: '#0d6efd',
                allowOutsideClick: false,
                timer: 4000,
                timerProgressBar: true
            }).then(() => {
                window.location.href = '../index.html';
            });
        });
    </script>
</body>
</html>
HTML
}

my $id_target = $q->param('id') || '';
my $paciente = cargar_datos_paciente($id_target);

if ($paciente) {
    my $tenant_pac = $paciente->{tenant} // '';
    my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
    my $mi_org = $session_data->{id_empresa} || 'X';
    my $mi_sucursal = $session_data->{id_sucursal} // 0;
    my $role = $session_data->{role};
    my $id_medico = $session_data->{id_medico};
    
    my $acceso_permitido = 0;
    if ($role eq 'Administrador Global') {
        $acceso_permitido = 1;
    } elsif ($org_pac && $org_pac eq $mi_org) {
        # Si el paciente pertenece a esta organización, todos los de la org pueden verlo
        $acceso_permitido = 1;
    } elsif (!$org_pac) {
        # Paciente legado sin org
        if ($role =~ /Administrador Organizacion|Soporte/i) {
            $acceso_permitido = 1;
        } elsif ($role eq 'Medico' && $paciente->{id_medico} eq $id_medico) {
            $acceso_permitido = 1;
        }
    }
    
    if (!$acceso_permitido) {
        render_acceso_denegado(
            q => $q, usuario => ($session_data->{usuario} // 'Usuario'), role => $role,
            mensaje => 'No tienes los permisos necesarios para visualizar este expediente clínico.',
            rol_requerido => 'Personal Médico o Administrador de la Organización'
        );
        exit;
    }
}

print $q->header(-type => 'text/html', -charset => 'UTF-8');
render_header(
    usuario     => $session_data->{usuario}, 
    role        => $session_data->{role}, 
    titulo      => 'SDM Digital - Expediente Unificado', 
    skip_header => 1
);

if ($paciente) {
    my $id_negocio_activo = ($session_data->{id_sucursal} && $session_data->{id_sucursal} ne '0') ? $session_data->{id_sucursal} : ($session_data->{id_empresa} // '0');
    my $tipo_organizacion = 'Consultorio Individual';
    my $org_nombre = '';
    my $org_clues  = '';

    my $config_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios_config.dat');
    if (-e $config_file && open(my $fhc, '<:encoding(UTF-8)', $config_file)) {
        while (my $line = <$fhc>) {
            chomp $line;
            next if $line =~ /^#|^\s*$/;
            my @f = split /\|/, $line;
            if ($f[0] eq $id_negocio_activo && $f[1] eq 'TIPO_ORGANIZACION') {
                $tipo_organizacion = $f[2] // 'Consultorio Individual';
                last;
            }
        }
        close $fhc;
    }

    my $negocios_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'negocios.dat');
    if (-e $negocios_file && open(my $fhn, '<:encoding(UTF-8)', $negocios_file)) {
        <$fhn>;
        while (my $line = <$fhn>) {
            chomp $line;
            next if $line =~ /^\s*$/;
            my @f = split /\|/, $line, -1;
            if ($f[0] eq $id_negocio_activo || ($id_negocio_activo eq '0' && ($f[0] eq '0' || $f[0] eq 'ORG-000'))) {
                $org_nombre = $f[1] // '';
                $org_clues  = $f[18] // '';
                last;
            }
        }
        close $fhn;
    }

    # Heurística canónica: si no tiene CLUE institucional o el nombre indica consultorio:
    if ($tipo_organizacion eq 'Clínica') {
        if (!$org_clues || $org_clues eq '0' || $org_nombre =~ /consultorio|dental/i) {
            $tipo_organizacion = 'Consultorio Individual';
        }
    }
    my $es_consultorio = ($tipo_organizacion =~ /Consultorio/i) ? 1 : 0;
    my $recibo_script = $es_consultorio ? 'imprimir_recibo_caja_consultorio.pl' : 'imprimir_recibo_caja.pl';

    my @citas = cargar_citas_paciente($id_target);
    my @correos = cargar_historial_correos($id_target);
    my $consultas = cargar_historial_consultas($id_target);
    render_expediente_completo($paciente, \@citas, \@correos, $consultas, $session_data->{id_medico}, $recibo_script);
}

print "</main>\n";
render_bottom_nav('expediente', id_paciente => $id_target);
print "</body></html>\n";

sub parseFloatVal {
    my ($val) = @_;
    return 0 unless defined $val;
    $val =~ s/[^0-9.]//g;
    return $val ne '' ? $val + 0 : 0;
}

sub render_expediente_completo {
    my ($d, $citas_ref, $correos_ref, $consultas_ref, $id_medico_actual, $recibo_script) = @_;
    $recibo_script ||= 'imprimir_recibo_caja_consultorio.pl';
    my $count_c = scalar @$citas_ref;
    my $count_m = scalar @$correos_ref;
    my $count_consultas = scalar @$consultas_ref;
    my $edad = calcular_edad($d->{f_nac});
    my $curp = $d->{curp} || 'Sin CURP';
    my $sexo = $d->{sexo} || 'N/A';

    # --- MÉTRICAS Y KPIS PARA DASHBOARD CLÍNICO 1.4 ---
    my $ultima_cons = (@$consultas_ref) ? $consultas_ref->[0] : undef;
    
    # Buscar la consulta más reciente que contenga signos vitales registrados
    my $cons_con_signos = undef;
    foreach my $c (@$consultas_ref) {
        my $cd = $c->{data} || {};
        if (($cd->{ta} && $cd->{ta} ne '--') || 
            ($cd->{fc} && $cd->{fc} ne '--') || 
            ($cd->{fr} && $cd->{fr} ne '--') || 
            ($cd->{temp} && $cd->{temp} ne '--') || 
            ($cd->{peso} && $cd->{peso} ne '0') || 
            ($cd->{talla} && $cd->{talla} ne '0') ||
            ($cd->{spo2} && $cd->{spo2} ne '--') ||
            ($cd->{soap} && $cd->{soap}->{objective})) {
            $cons_con_signos = $c;
            last;
        }
    }
    my $cons_signos_ref = $cons_con_signos || $ultima_cons;
    my $ult_data = $cons_signos_ref ? ($cons_signos_ref->{data} || {}) : {};
    my $fecha_signos = $cons_signos_ref ? ($cons_signos_ref->{fecha} || $cons_signos_ref->{fecha_orden} || '') : '';
    my $badge_fecha_signos = $fecha_signos 
        ? qq{<span class="badge bg-teal-subtle text-teal border rounded-pill px-3 py-1 fw-bold"><i class="bi bi-clock-history me-1"></i>Última Consulta: $fecha_signos</span>} 
        : qq{<span class="badge bg-secondary-subtle text-muted rounded-pill px-3 py-1">Sin consultas previas</span>};
    
    my $ta_val = $ult_data->{ta} || $ult_data->{TA} || $ult_data->{presion} 
        || ($ult_data->{soap} && $ult_data->{soap}->{objective} && ($ult_data->{soap}->{objective}->{ta} || $ult_data->{soap}->{objective}->{TA})) 
        || '--';

    my $fc_val = $ult_data->{fc} || $ult_data->{FC} || $ult_data->{frecuencia_cardiaca} 
        || ($ult_data->{soap} && $ult_data->{soap}->{objective} && ($ult_data->{soap}->{objective}->{fc} || $ult_data->{soap}->{objective}->{FC})) 
        || '--';

    my $fr_val = $ult_data->{fr} || $ult_data->{FR} || $ult_data->{frecuencia_respiratoria} 
        || ($ult_data->{soap} && $ult_data->{soap}->{objective} && ($ult_data->{soap}->{objective}->{fr} || $ult_data->{soap}->{objective}->{FR})) 
        || '--';

    my $temp_val = $ult_data->{temp} || $ult_data->{TEMP} || $ult_data->{temperatura} 
        || ($ult_data->{soap} && $ult_data->{soap}->{objective} && ($ult_data->{soap}->{objective}->{temp} || $ult_data->{soap}->{objective}->{TEMP})) 
        || '--';

    my $spo2_val = $ult_data->{spo2} || $ult_data->{SPO2} || $ult_data->{oximetria} || $ult_data->{saturacion} 
        || ($ult_data->{soap} && $ult_data->{soap}->{objective} && ($ult_data->{soap}->{objective}->{spo2} || $ult_data->{soap}->{objective}->{SPO2})) 
        || '--';

    my $peso_raw = $ult_data->{peso} || $ult_data->{PESO} 
        || ($ult_data->{soap} && $ult_data->{soap}->{objective} && ($ult_data->{soap}->{objective}->{peso} || $ult_data->{soap}->{objective}->{PESO})) 
        || $d->{peso} || 0;

    my $talla_raw = $ult_data->{talla} || $ult_data->{TALLA} || $ult_data->{estatura} 
        || ($ult_data->{soap} && $ult_data->{soap}->{objective} && ($ult_data->{soap}->{objective}->{talla} || $ult_data->{soap}->{objective}->{TALLA})) 
        || $d->{talla} || 0;

    my $peso_val = parseFloatVal($peso_raw);
    my $talla_val = parseFloatVal($talla_raw);
    my $diag_activo = $ult_data->{diagnostico_principal} || $ult_data->{diagnostico} 
        || ($ult_data->{soap} && $ult_data->{soap}->{assessment} && $ult_data->{soap}->{assessment}->{diagnostico_principal}) 
        || 'Sin diagnóstico registrado';
    my $cie10_activo = $ult_data->{clave_diagnostico_cie10} 
        || ($ult_data->{soap} && $ult_data->{soap}->{assessment} && $ult_data->{soap}->{assessment}->{clave_diagnostico_cie10}) 
        || '';
    
    # Cálculo de IMC y Clasificación Nutricional
    my $imc_val = '--';
    my $imc_status = 'Sin registro';
    my $imc_perc = 0;
    my $imc_badge = 'bg-secondary';
    if ($peso_val > 0 && $talla_val > 0) {
        my $t_m = $talla_val > 3 ? $talla_val / 100 : $talla_val;
        my $calc = $peso_val / ($t_m * $t_m);
        $imc_val = sprintf("%.1f", $calc);
        if ($calc < 18.5) { 
            $imc_status = 'Bajo Peso'; $imc_badge = 'bg-warning text-dark'; $imc_perc = 25; 
        } elsif ($calc < 25.0) { 
            $imc_status = 'Normal'; $imc_badge = 'bg-success'; $imc_perc = 50; 
        } elsif ($calc < 30.0) { 
            $imc_status = 'Sobrepeso'; $imc_badge = 'bg-warning text-dark'; $imc_perc = 75; 
        } else { 
            $imc_status = 'Obesidad'; $imc_badge = 'bg-danger'; $imc_perc = 95; 
        }
    }
    
    # Asistencia a Citas (%)
    my $citas_atendidas = scalar(grep { $_->{estado} =~ /Atendida|Realizada/i } @$citas_ref);
    my $pct_asistencia = $count_c > 0 ? sprintf("%.0f", ($citas_atendidas / $count_c) * 100) : 100;
    
    # Alergias
    my $alergias_txt = $d->{alergias} || 'Negadas';
    my $tiene_alergias = ($alergias_txt ne '' && $alergias_txt !~ /Negada|Ninguna|Sin/i);

    print <<HTML;
<link rel="stylesheet" href="../css/expediente_completo.css?v=$^T">
<link rel="stylesheet" href="../css/odontograma_plus.css?v=$^T">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.53/vfs_fonts.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>
HTML

    utils::sub_sidebar::render_sidebar(
        usuario => $session_data->{usuario},
        role => $session_data->{role},
        id_medico => $session_data->{id_medico},
        pagina_actual => 'expediente',
        id_paciente => $paciente->{id_paciente}
    );

    print <<'JS';
<script>
    let odontogramaInit = false;

    function swTab(id, b) {
        if (window.innerWidth <= 991) {
            if(b && b.classList.contains('sub-link')){
                const sidebar = document.getElementById('moduleSidebar');
                const overlay = document.getElementById('sidebarOverlay');
                if (sidebar && sidebar.classList.contains('show')) toggleSidebar();
            }
        }

        document.querySelectorAll('.sdm-tab-sec').forEach(s => s.classList.add('d-none'));
        const target = document.getElementById(id);
        if(target) target.classList.remove('d-none');

        // Ocultar header azul si la pestaña activa es tab3 (Ficha de Identificación) por información repetitiva
        const mainHeader = document.getElementById('mainPatientHeader');
        if (mainHeader) {
            if (id === 'tab3') {
                mainHeader.classList.add('d-none');
            } else {
                mainHeader.classList.remove('d-none');
            }
        }

        if (b && b.classList.contains('sub-link')) {
            document.querySelectorAll('.sub-link').forEach(n => n.classList.remove('active'));
            b.classList.add('active');
        }
        
        if (id === 'tab6') {
            setTimeout(() => {
                if (window.jQuery && $.fn.DataTable && $.fn.DataTable.isDataTable('#tablaOdontoHub')) {
                    $('#tablaOdontoHub').DataTable().columns.adjust().draw();
                }
            }, 60);
        }

        if(b && b.classList.contains('sub-link')){
            window.scrollTo({ top: 0, behavior: 'smooth' });
            const mainContent = document.querySelector('.sdm-main-content');
            if (mainContent) mainContent.scrollTop = 0;
        }
    }
    
    function checkHashTab() {
        const hash = window.location.hash;
        if (hash) {
            let tabId = hash.substring(1);
            if (tabId === 'tab0' || tabId === 'tab4') tabId = 'tab10';
            const targetBtn = document.querySelector('.sub-link[onclick*="' + tabId + '"]');
            if (targetBtn) {
                swTab(tabId, targetBtn);
            } else {
                swTab(tabId);
            }
        }
    }
    document.addEventListener('DOMContentLoaded', function() {
        window.scrollTo(0, 0);
        const mainContent = document.querySelector('.sdm-main-content');
        if (mainContent) mainContent.scrollTop = 0;
        checkHashTab();
    });
    window.addEventListener('hashchange', checkHashTab);
</script>
JS

    print <<HTML;

        <!-- TOPBAR / HEADER CORPORATIVO (EXPEDIENTE HERO PREMIUM ANTI-DISTORSIÓN) -->
        <header id="mainPatientHeader" class="expediente-hero-header text-white mb-3 container-mobile-flush">
            <div class="patient-hero-inner d-flex align-items-center gap-3">
                <div class="patient-hero-avatar flex-shrink-0 d-flex align-items-center justify-content-center">
                    <i class="bi bi-person-vcard-fill fs-3 text-white"></i>
                </div>
                <div class="patient-hero-content flex-grow-1">
                    <h2 class="patient-hero-name mb-0 text-white">$d->{nombre}</h2>
                    <div class="patient-hero-chips d-flex flex-wrap align-items-center gap-2 mt-2">
                        <span class="patient-hero-chip"><i class="bi bi-fingerprint me-1"></i><strong class="patient-chip-lbl">CURP:</strong> $curp</span>
                        <span class="patient-hero-chip"><i class="bi bi-calendar3 me-1"></i><strong class="patient-chip-lbl">Edad:</strong> $edad a&ntilde;os</span>
                        <span class="patient-hero-chip"><i class="bi bi-gender-ambiguous me-1"></i><strong class="patient-chip-lbl">Sexo:</strong> $sexo</span>
                    </div>
                </div>
            </div>
        </header>

        <div class="mt-4">
HTML

    # --- PROCESAMIENTO DEL HUB MULTI-ODONTOGRAMA ---
    my $ODONTO_FILE_PATH = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas.dat');
    my $ODONTO_JSON_PATH = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'odontogramas', "paciente_$d->{id_paciente}.json");

    my %PRECIOS_MAP = (
        CARIES           => { nom => 'Caries Dental (Activa)',      cat => 'PENDING',  precio => 850.00 },
        CARIES_RECURRENT => { nom => 'Caries Recurrente',           cat => 'PENDING',  precio => 950.00 },
        FRACTURE         => { nom => 'Fractura Dental',             cat => 'PENDING',  precio => 1200.00 },
        SEALANT_REQ      => { nom => 'Sellador Requerido',          cat => 'PENDING',  precio => 450.00 },
        CROWN_REQ        => { nom => 'Corona Requerida',            cat => 'PENDING',  precio => 3500.00 },
        ENDO_REQ         => { nom => 'Endodoncia Indicada',         cat => 'PENDING',  precio => 2800.00 },
        EXO_REQ          => { nom => 'Exodoncia Requerida',         cat => 'PENDING',  precio => 1100.00 },
        EXTRACTION_REQ   => { nom => 'Exodoncia Requerida',         cat => 'PENDING',  precio => 1100.00 },
        COMPOSITE        => { nom => 'Obturación con Resina',       cat => 'EXISTING', precio => 850.00 },
        AMALGAM          => { nom => 'Obturación con Amalgama',     cat => 'EXISTING', precio => 700.00 },
        CROWN_DONE       => { nom => 'Corona Existente',            cat => 'EXISTING', precio => 3500.00 },
        ENDO_DONE        => { nom => 'Endodoncia Realizada',        cat => 'EXISTING', precio => 2800.00 },
        IMPLANT          => { nom => 'Implante Dental',             cat => 'EXISTING', precio => 14000.00 },
        ABSENT           => { nom => 'Pieza Ausente',               cat => 'EXISTING', precio => 0.00 },
    );

    my %DENTAL_NAMES = (
        18 => 'Tercer Molar Sup. Der.',    17 => 'Segundo Molar Sup. Der.',    16 => 'Primer Molar Sup. Der.',
        15 => 'Segundo Premolar Sup. Der.', 14 => 'Primer Premolar Sup. Der.',   13 => 'Canino Sup. Der.',
        12 => 'Incisivo Lateral Sup. Der.', 11 => 'Incisivo Central Sup. Der.',
        21 => 'Incisivo Central Sup. Izq.', 22 => 'Incisivo Lateral Sup. Izq.', 23 => 'Canino Sup. Izq.',
        24 => 'Primer Premolar Sup. Izq.',  25 => 'Segundo Premolar Sup. Izq.', 26 => 'Primer Molar Sup. Izq.',
        27 => 'Segundo Molar Sup. Izq.',    28 => 'Tercer Molar Sup. Izq.',
        38 => 'Tercer Molar Inf. Izq.',    37 => 'Segundo Molar Inf. Izq.',    36 => 'Primer Molar Inf. Izq.',
        35 => 'Segundo Premolar Inf. Izq.', 34 => 'Primer Premolar Inf. Izq.',   33 => 'Canino Inf. Izq.',
        32 => 'Incisivo Lateral Inf. Izq.', 31 => 'Incisivo Central Inf. Izq.',
        41 => 'Incisivo Central Inf. Der.', 42 => 'Incisivo Lateral Inf. Der.', 43 => 'Canino Inf. Der.',
        44 => 'Primer Premolar Inf. Der.',  45 => 'Segundo Premolar Inf. Der.', 46 => 'Primer Molar Inf. Der.',
        47 => 'Segundo Molar Inf. Der.',    48 => 'Tercer Molar Inf. Der.',
    );

    my @odontogramas_list;
    my $loaded_from_json = 0;

    if (-e $ODONTO_JSON_PATH) {
        my $json_raw = '';
        if (open my $fh_j, '<:raw', $ODONTO_JSON_PATH) {
            local $/;
            $json_raw = <$fh_j>;
            close $fh_j;
        }
        my $patient_data = eval { decode_json($json_raw) };
        if ($patient_data && ref($patient_data) eq 'HASH') {
            $loaded_from_json = 1;
            if (exists $patient_data->{odontogramas} && ref($patient_data->{odontogramas}) eq 'ARRAY') {
                foreach my $od_item (@{ $patient_data->{odontogramas} }) {
                    if ($od_item->{alias}) {
                        $od_item->{alias} =~ s/ÃƒÂ­/í/g;
                        $od_item->{alias} =~ s/Ã­/í/g;
                        $od_item->{alias} =~ s/Ã³/ó/g;
                        $od_item->{alias} =~ s/Ã¡/á/g;
                        $od_item->{alias} =~ s/Ã©/é/g;
                        $od_item->{alias} =~ s/Ãº/ú/g;
                        $od_item->{alias} =~ s/Ã±/ñ/g;
                    }
                    if ($od_item->{notas}) {
                        $od_item->{notas} =~ s/ÃƒÂ­/í/g;
                        $od_item->{notas} =~ s/Ã­/í/g;
                        $od_item->{notas} =~ s/Ã³/ó/g;
                        $od_item->{notas} =~ s/Ã¡/á/g;
                        $od_item->{notas} =~ s/Ã©/é/g;
                        $od_item->{notas} =~ s/Ãº/ú/g;
                        $od_item->{notas} =~ s/Ã±/ñ/g;
                    }
                }
                @odontogramas_list = @{ $patient_data->{odontogramas} };
            } elsif (exists $patient_data->{teeth} && ref($patient_data->{teeth}) eq 'HASH') {
                my $legacy_alias = $patient_data->{alias} || 'Diagnóstico Inicial';
                $legacy_alias =~ s/ÃƒÂ­/í/g; $legacy_alias =~ s/Ã­/í/g;
                my $legacy_notas = $patient_data->{notas} || '';
                $legacy_notas =~ s/ÃƒÂ­/í/g; $legacy_notas =~ s/Ã­/í/g;
                push @odontogramas_list, {
                    id_odonto             => "OD-$d->{id_paciente}-1",
                    alias                 => $legacy_alias,
                    fecha                 => $patient_data->{fechaLocal} || $patient_data->{updatedAt} || 'Recientemente',
                    estado                => $patient_data->{estado} || 'En Proceso',
                    importe               => $patient_data->{financialTotalPending} || 0,
                    notas                 => $legacy_notas,
                    teeth                 => $patient_data->{teeth} || {},
                    periodontalSummary    => $patient_data->{periodontalSummary} || {}
                };
            }
        }
    }

    if (!$loaded_from_json) {
        my $odonto_registros = -e $ODONTO_FILE_PATH ? leer_tabla($ODONTO_FILE_PATH, '\|') : [];
        my %teeth_found;
        my $fecha_found = '';
        my $notas_found = '';
        foreach my $f (@$odonto_registros) {
            if ($f->[0] eq $d->{id_paciente}) {
                $fecha_found = $f->[2] if $f->[2];
                $notas_found = $f->[3] if $f->[3];
                for (my $i = 4; $i < @$f; $i++) {
                    if ($f->[$i] =~ /^(\d+)=(.+)$/) {
                        my $tooth = $1;
                        my $val_hash = eval { decode_json($2) } || {};
                        $teeth_found{$tooth} = $val_hash;
                    }
                }
            }
        }
        if (%teeth_found) {
            push @odontogramas_list, {
                id_odonto          => "OD-$d->{id_paciente}-1",
                alias              => 'Diagnóstico Base',
                fecha              => $fecha_found || 'Recientemente',
                estado             => 'En Proceso',
                importe            => 0.00,
                notas              => $notas_found,
                teeth              => \%teeth_found,
                periodontalSummary => {}
            };
        }
    }

    # Procesar hallazgos de cada odontograma y calcular métricas globales
    my $total_presupuesto_hub = 0.00;
    my $count_pendientes_hub = 0;
    my $count_existentes_hub = 0;
    my $odonto_fecha_act = 'Sin registros';
    my $odonto_notas = 'Sin observaciones clínicas registradas.';
    my %odonto_collection_client;

    foreach my $od (@odontogramas_list) {
        my @od_hallazgos;
        my $od_presupuesto = 0.00;
        my $od_pendientes = 0;
        my $od_existentes = 0;
        my %od_piezas_map;

        my $teeth_map = (ref($od->{teeth}) eq 'HASH') ? $od->{teeth} : {};
        foreach my $tooth (sort { $a <=> $b } keys %$teeth_map) {
            my $t_data = $teeth_map->{$tooth};
            next unless ref($t_data) eq 'HASH';
            $od_piezas_map{$tooth} = 1;
            my $tooth_nom = $DENTAL_NAMES{$tooth} || "Pieza #$tooth";

            if ($t_data->{status} && ($t_data->{status} eq 'ABSENT' || $t_data->{absent})) {
                push @od_hallazgos, {
                    pieza       => $tooth,
                    nombre      => $tooth_nom,
                    cara        => 'Pieza Completa',
                    diagnostico => 'Pieza Ausente ✕',
                    categoria   => 'EXISTING',
                    costo       => 0.00,
                };
                $od_existentes++;
            }

            if ($t_data->{status} && $t_data->{status} eq 'EXTRACTION_REQUIRED') {
                push @od_hallazgos, {
                    pieza       => $tooth,
                    nombre      => $tooth_nom,
                    cara        => 'Pieza Completa',
                    diagnostico => 'Exodoncia Requerida',
                    categoria   => 'PENDING',
                    costo       => 1100.00,
                };
                $od_presupuesto += 1100.00;
                $od_pendientes++;
            }

            if ($t_data->{surfaces} && ref($t_data->{surfaces}) eq 'HASH') {
                foreach my $surf (keys %{$t_data->{surfaces}}) {
                    my $item = $t_data->{surfaces}->{$surf};
                    my $code = ref($item) eq 'HASH' ? ($item->{code} || 'DESCONOCIDO') : $item;
                    my $info = $PRECIOS_MAP{$code} || { nom => $code, cat => 'PENDING', precio => 850.00 };
                    my $costo = (ref($item) eq 'HASH' && defined($item->{price})) ? $item->{price} : $info->{precio};

                    if ($info->{cat} eq 'PENDING') {
                        $od_presupuesto += $costo;
                        $od_pendientes++;
                    } else {
                        $od_existentes++;
                    }

                    push @od_hallazgos, {
                        pieza       => $tooth,
                        nombre      => $tooth_nom,
                        cara        => ucfirst($surf),
                        diagnostico => $info->{nom},
                        categoria   => $info->{cat},
                        costo       => $costo,
                    };
                }
            } elsif (ref($t_data) eq 'HASH') {
                foreach my $surf (keys %$t_data) {
                    next if $surf eq 'absent' || $surf eq 'surfaces' || $surf eq 'status';
                    my $code = $t_data->{$surf};
                    my $info = $PRECIOS_MAP{$code} || { nom => $code, cat => 'PENDING', precio => 850.00 };
                    if ($info->{cat} eq 'PENDING') {
                        $od_presupuesto += $info->{precio};
                        $od_pendientes++;
                    } else {
                        $od_existentes++;
                    }
                    push @od_hallazgos, {
                        pieza       => $tooth,
                        nombre      => $tooth_nom,
                        cara        => ucfirst($surf),
                        diagnostico => $info->{nom},
                        categoria   => $info->{cat},
                        costo       => $info->{precio},
                    };
                }
            }
        }

        # Actualizar importe si no estaba fijado
        $od->{importe} = $od_presupuesto if (!defined($od->{importe}) || $od->{importe} == 0);
        $od->{alias} ||= 'Odontograma General';
        $od->{estado} ||= 'En Proceso';
        $od->{fecha} ||= 'Recientemente';

        $total_presupuesto_hub += $od->{importe};
        $count_pendientes_hub += $od_pendientes;
        $count_existentes_hub += $od_existentes;
        $odonto_fecha_act = $od->{fecha} if $od->{fecha} && $odonto_fecha_act eq 'Sin registros';
        $odonto_notas = $od->{notas} if $od->{notas} && $odonto_notas eq 'Sin observaciones clínicas registradas.';

        $odonto_collection_client{$od->{id_odonto}} = {
            id_odonto  => $od->{id_odonto},
            alias      => $od->{alias},
            fecha      => $od->{fecha},
            estado     => $od->{estado},
            importe    => sprintf("%.2f", $od->{importe}),
            notas      => $od->{notas} || '',
            hallazgos  => \@od_hallazgos,
            tot_piezas => scalar(keys %od_piezas_map),
        };
    }

    my $presupuesto_fmt = sprintf("%.2f", $total_presupuesto_hub);
    my $total_odonto_registros = scalar(@odontogramas_list);
    my $odonto_json_data = eval { JSON->new->utf8(0)->encode(\%odonto_collection_client) } || '{}';
    $odonto_json_data =~ s/</\\u003c/g;

    print <<HTML;
        <!-- 6: ODONTOGRAMA (HUB EJECUTIVO FULL-WIDTH) -->
        <section class="sdm-tab-sec d-none" id="tab6">
            <!-- NIVEL 1: ENCABEZADO PRINCIPAL (SANITIZADO SIN BOTONES DUPLICADOS) -->
            <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3">
                <div>
                    <div class="d-flex align-items-center gap-2 mb-1">
                        <span class="badge bg-teal text-white rounded-pill px-3 py-1 fw-bold" style="background-color: var(--md-teal-clinical, #19B7A5) !important;">FDI / ISO 3950</span>
                        <span class="badge bg-navy text-white rounded-pill px-3 py-1 fw-bold">Dentici&oacute;n Permanente (32 Piezas)</span>
                    </div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Hub Cl&iacute;nico Odontol&oacute;gico</h3>
                    <p class="text-muted small fw-bold mb-0">GESTI&Oacute;N MULTI-ODONTOGRAMA Y PLAN DE TRATAMIENTO</p>
                </div>
            </div>

            <!-- NIVEL 2: FILA DE KPIs Y MÉTRICAS CLÍNICAS (4 CARDS HORIZONTALES) -->
            <div class="row g-3 mb-4">
                <!-- Card 1: Presupuesto Estimado -->
                <div class="col-12 col-sm-6 col-xl-3">
                    <div class="card-medentia-aura border-0 p-4 h-100 position-relative overflow-hidden">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <span class="small fw-bold text-muted text-uppercase">Presupuesto Estimado</span>
                            <div class="p-2 bg-danger-subtle text-danger rounded-circle d-flex align-items-center justify-content-center" style="width: 38px; height: 38px;">
                                <i class="bi bi-wallet2 fs-5"></i>
                            </div>
                        </div>
                        <h3 class="fw-black text-danger m-0 mb-1">\$$presupuesto_fmt <span class="fs-6 text-muted">MXN</span></h3>
                        <span class="small text-muted fw-bold">Tratamientos pendientes acumulados</span>
                    </div>
                </div>

                <!-- Card 2: Patologías Activas / Pendientes -->
                <div class="col-12 col-sm-6 col-xl-3">
                    <div class="card-medentia-aura border-0 p-4 h-100 position-relative overflow-hidden">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <span class="small fw-bold text-muted text-uppercase">Patolog&iacute;as Activas</span>
                            <div class="p-2 bg-warning-subtle text-warning-emphasis rounded-circle d-flex align-items-center justify-content-center" style="width: 38px; height: 38px;">
                                <i class="bi bi-exclamation-triangle-fill fs-5 text-warning"></i>
                            </div>
                        </div>
                        <h3 class="fw-black m-0 mb-1" style="color: var(--md-blue-deep);">$count_pendientes_hub <span class="fs-6 text-muted">Pendientes</span></h3>
                        <span class="small text-muted fw-bold">Caries, fracturas, endodoncias req.</span>
                    </div>
                </div>

                <!-- Card 3: Tratamientos Previos / Existentes -->
                <div class="col-12 col-sm-6 col-xl-3">
                    <div class="card-medentia-aura border-0 p-4 h-100 position-relative overflow-hidden">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <span class="small fw-bold text-muted text-uppercase">Tratamientos Previos</span>
                            <div class="p-2 bg-primary-subtle text-primary rounded-circle d-flex align-items-center justify-content-center" style="width: 38px; height: 38px;">
                                <i class="bi bi-shield-check fs-5"></i>
                            </div>
                        </div>
                        <h3 class="fw-black text-primary m-0 mb-1">$count_existentes_hub <span class="fs-6 text-muted">Realizados</span></h3>
                        <span class="small text-muted fw-bold">Resinas, coronas, implantes previos</span>
                    </div>
                </div>

                <!-- Card 4: Odontogramas Registrados -->
                <div class="col-12 col-sm-6 col-xl-3">
                    <div class="card-medentia-aura border-0 p-4 h-100 position-relative overflow-hidden">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <span class="small fw-bold text-muted text-uppercase">Estudios Registrados</span>
                            <div class="p-2 rounded-circle d-flex align-items-center justify-content-center" style="width: 38px; height: 38px; background: rgba(25, 183, 165, 0.15); color: #19B7A5;">
                                <i class="bi bi-journals fs-5"></i>
                            </div>
                        </div>
                        <h3 class="fw-black m-0 mb-1" style="color: var(--md-blue-deep);">$total_odonto_registros <span class="fs-6 text-muted">Odontogramas</span></h3>
                        <span class="small text-muted fw-bold">&Uacute;ltima act: $odonto_fecha_act</span>
                    </div>
                </div>
            </div>

            <!-- NIVEL 3: BANNER DE OBSERVACIONES CLÍNICAS (SANITIZADO SIN BOTÓN DUPLICADO) -->
            <div class="card-medentia-aura border-0 p-3 mb-4 d-flex flex-row align-items-center justify-content-between flex-wrap gap-3" style="background: rgba(248, 250, 252, 0.9);">
                <div class="d-flex align-items-center gap-3">
                    <div class="p-2 bg-white rounded-circle shadow-xs" style="color: var(--md-teal-clinical, #19B7A5);">
                        <i class="bi bi-chat-left-quote-fill fs-5"></i>
                    </div>
                    <div>
                        <span class="small fw-bold text-muted text-uppercase d-block lh-1 mb-1">Observaciones del Odont&oacute;logo Tratante:</span>
                        <span class="fw-bold text-dark fs-6">$odonto_notas</span>
                    </div>
                </div>
                <div class="d-flex align-items-center gap-2">
                    <span class="badge bg-white text-muted border px-3 py-2 fw-semibold">
                        <i class="bi bi-clock-history me-1 text-teal" style="color: var(--md-teal-clinical, #19B7A5);"></i>Sincronizado: $odonto_fecha_act
                    </span>
                </div>
            </div>

            <!-- NIVEL 4: DATATABLE AL 100% DEL ANCHO DISPONIBLE (5 COLUMNAS: NOMBRE, FECHA, ESTADO, IMPORTE, ACCIONES) -->
            <div class="card-medentia-aura p-4 border-0 mb-4">
                <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                    <div>
                        <h5 class="fw-black m-0" style="color: var(--md-blue-deep);">
                            <i class="bi bi-journal-medical me-2" style="color: var(--md-teal-clinical, #19B7A5);"></i>Cat&aacute;logo de Odontogramas del Paciente
                        </h5>
                        <p class="text-muted small fw-bold mb-0">GESTIONE ESTUDIOS, PLANES DE TRATAMIENTO Y DETALLES ANAT&Oacute;MICOS</p>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <span class="badge bg-light text-navy border px-3 py-2 fw-bold">
                            Total Registros: <span class="text-teal" style="color: var(--md-teal-clinical, #19B7A5); font-weight: 900;">$total_odonto_registros</span>
                        </span>
HTML

    if (@odontogramas_list) {
        print <<HTML;
                        <button type="button" onclick="abrirModalNuevoOdonto()" class="btn btn-outline-medentia btn-sm rounded-pill px-3 fw-bold d-flex align-items-center gap-1">
                            <i class="bi bi-plus-circle"></i>Nuevo Odontograma
                        </button>
                    </div>
                </div>

                <div class="table-responsive">
                    <table class="table table-hover align-middle mb-0" id="tablaOdontoHub" style="width:100%">
                        <thead class="table-light">
                            <tr>
                                <th class="ps-3 border-0 rounded-start-3">Nombre</th>
                                <th class="border-0" style="width: 170px;">Fecha</th>
                                <th class="border-0 text-center" style="width: 150px;">Estado</th>
                                <th class="border-0 text-end" style="width: 170px;">Importe</th>
                                <th class="border-0 text-center pe-3 rounded-end-3" style="width: 170px;">Acciones</th>
                            </tr>
                        </thead>
                        <tbody class="small">
HTML

        foreach my $od (@odontogramas_list) {
            my $od_id = $od->{id_odonto} || '';
            my $od_alias = $od->{alias} || 'Odontograma General';
            my $od_fecha = $od->{fecha} || 'Sin fecha';
            my $od_estado = $od->{estado} || 'En Proceso';
            my $od_imp_fmt = sprintf("%.2f", $od->{importe} || 0);

            # Escape para atributos JS
            my $od_alias_js = $od_alias; $od_alias_js =~ s/'/\\'/g; $od_alias_js =~ s/"/&quot;/g;
            my $od_id_js = $od_id; $od_id_js =~ s/'/\\'/g;
            my $od_alias_html = $od_alias;
            my $od_fecha_html = $od_fecha;

            my $badge_estado = '<span class="badge bg-secondary-subtle text-secondary border px-3 py-1">Histórico</span>';
            if ($od_estado =~ /En Proceso|Activo/i) {
                $badge_estado = '<span class="badge bg-warning-subtle text-warning-emphasis border border-warning-subtle px-3 py-1"><i class="bi bi-clock-history me-1"></i>En Proceso</span>';
            } elsif ($od_estado =~ /Planificado|Presupuesto/i) {
                $badge_estado = '<span class="badge bg-info-subtle text-info-emphasis border border-info-subtle px-3 py-1"><i class="bi bi-calendar-check me-1"></i>Planificado</span>';
            } elsif ($od_estado =~ /Finalizado|Completado/i) {
                $badge_estado = '<span class="badge bg-success-subtle text-success border border-success-subtle px-3 py-1"><i class="bi bi-check-circle-fill me-1"></i>Finalizado</span>';
            }

            my $cnt_piezas = 0;
            if (ref($od->{teeth}) eq 'HASH') {
                $cnt_piezas = scalar(keys %{ $od->{teeth} });
            }

            print <<HTML;
                            <tr>
                                <td class="ps-3">
                                    <div class="d-flex align-items-center gap-2">
                                        <div class="p-2 rounded-circle bg-primary-subtle text-primary d-flex align-items-center justify-content-center" style="width: 38px; height: 38px; flex-shrink: 0;">
                                            <i class="bi bi-journal-medical fs-5"></i>
                                        </div>
                                        <div>
                                            <div class="fw-bold text-dark fs-6">$od_alias_html</div>
                                            <div class="d-flex align-items-center gap-2">
                                                <span class="badge bg-light text-muted border" style="font-size: 0.72rem;">#$od_id</span>
                                                <span class="small text-muted" style="font-size: 0.75rem;"><i class="bi bi-diagram-3 me-1"></i>$cnt_piezas piezas con registro</span>
                                            </div>
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <div class="fw-semibold text-secondary small"><i class="bi bi-calendar3 me-1" style="color: var(--md-teal-clinical, #19B7A5);"></i>$od_fecha_html</div>
                                </td>
                                <td class="text-center">$badge_estado</td>
                                <td class="text-end fw-black text-danger fs-6">\$$od_imp_fmt <span class="small text-muted fw-normal">MXN</span></td>
                                <td class="text-center pe-3">
                                    <div class="d-flex align-items-center justify-content-center gap-1">
                                        <!-- OJO: Abre modal con el detalle anatómico de dientes -->
                                        <button type="button" class="btn btn-sm btn-outline-info rounded-circle shadow-xs" title="Ver Detalle Clínico Anatómico" onclick="verDetalleOdonto('$od_id_js')" style="width: 32px; height: 32px; padding: 0;">
                                            <i class="bi bi-eye-fill"></i>
                                        </button>
                                        <!-- VISOR: Abre en OSOdontograma Viewer Pro -->
                                        <a href="render_visor_odontograma.pl?id=$d->{id_paciente}&id_odonto=$od_id" target="_blank" class="btn btn-sm btn-outline-primary rounded-circle shadow-xs" title="Abrir y Editar en OSOdontograma Viewer" style="width: 32px; height: 32px; padding: 0; display: inline-flex; align-items: center; justify-content: center;">
                                            <i class="bi bi-display"></i>
                                        </a>
                                        <!-- RENOMBRAR: Editar Alias, Estado y Notas -->
                                        <button type="button" class="btn btn-sm btn-outline-secondary rounded-circle shadow-xs" title="Editar Alias, Estado u Observaciones" onclick="editarOdontoMeta('$od_id_js')" style="width: 32px; height: 32px; padding: 0;">
                                            <i class="bi bi-tag-fill"></i>
                                        </button>
                                        <!-- ELIMINAR: Borrar Odontograma -->
                                        <button type="button" class="btn btn-sm btn-outline-danger rounded-circle shadow-xs" title="Eliminar Odontograma" onclick="eliminarOdonto('$od_id_js', '$od_alias_js')" style="width: 32px; height: 32px; padding: 0;">
                                            <i class="bi bi-trash3-fill"></i>
                                        </button>
                                    </div>
                                </td>
                            </tr>
HTML
        }

        print <<HTML;
                        </tbody>
                    </table>
                </div>
HTML
    } else {
        print <<HTML;
                    </div>
                </div>

                <div class="text-center py-5">
                    <div class="p-3 bg-light rounded-circle d-inline-flex align-items-center justify-content-center mb-3" style="width: 70px; height: 70px;">
                        <i class="bi bi-journal-plus display-6" style="color: var(--md-teal-clinical, #19B7A5);"></i>
                    </div>
                    <h5 class="fw-bold text-dark mb-1">Sin odontogramas registrados</h5>
                    <p class="text-muted small mb-4">La dentici&oacute;n permanente del paciente no tiene estudios ni planes de tratamiento registrados a&uacute;n.</p>
                    <button type="button" onclick="abrirModalNuevoOdonto()" class="btn btn-medentia px-4 py-2 rounded-pill fw-bold shadow-sm d-inline-flex align-items-center gap-2">
                        <i class="bi bi-plus-circle-fill"></i>
                        <span>Crear Primer Odontograma en OSOdontograma Viewer</span>
                    </button>
                </div>
HTML
    }

    print <<HTML;
            </div>

            <!-- Contenedor JSON seguro para hidratar cliente JS -->
            <script id="odontoCollectionJson" type="application/json">$odonto_json_data</script>
        </section>
HTML

    print <<'JS';
        <!-- Controladores y DataTables para el Hub Odontológico Multi-Estudio -->
        <script>
            window.ID_PACIENTE_ODONTO = '';
            const urlParams = new URLSearchParams(window.location.search);
            window.ID_PACIENTE_ODONTO = urlParams.get('id') || '';

            try {
                const elJson = document.getElementById('odontoCollectionJson');
                window.ODONTO_COLLECTION = elJson ? JSON.parse(elJson.textContent || '{}') : {};
            } catch(e) {
                console.error('Error parseando ODONTO_COLLECTION:', e);
                window.ODONTO_COLLECTION = {};
            }

            document.addEventListener('DOMContentLoaded', function() {
                // Mover modales odontológicos directamente a document.body para evitar trampas de apilamiento
                ['modalDetalleOdonto', 'modalNuevoOdonto', 'modalRenombrarOdonto'].forEach(function(id) {
                    var m = document.getElementById(id);
                    if (m && m.parentNode !== document.body) {
                        document.body.appendChild(m);
                    }
                });

                // 1. Inicializar DataTable Maestro de Odontogramas (5 columnas) sólo si existe en el DOM
                if (document.getElementById('tablaOdontoHub') && window.jQuery && $.fn.DataTable && !$.fn.DataTable.isDataTable('#tablaOdontoHub')) {
                    $('#tablaOdontoHub').DataTable({
                        language: { url: 'https://cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
                        pageLength: 10,
                        order: [[1, 'desc']],
                        dom: "<'row mb-3 align-items-center'<'col-sm-12 col-md-6 d-flex flex-wrap gap-2'B><'col-sm-12 col-md-6'f>>" +
                             "<'row'<'col-sm-12'tr>>" +
                             "<'row mt-3'<'col-sm-12 col-md-5'i><'col-sm-12 col-md-7'p>>",
                        buttons: [
                            { extend: 'copy', text: '<i class="bi bi-clipboard me-1"></i> COPY', className: 'btn btn-light fw-bolder border shadow-sm', style: 'border-radius: 12px;' },
                            { extend: 'excel', text: '<i class="bi bi-file-earmark-excel me-1"></i> EXCEL', className: 'btn btn-light fw-bolder border shadow-sm', style: 'border-radius: 12px;' },
                            { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF', className: 'btn btn-light fw-bolder border shadow-sm', style: 'border-radius: 12px;' },
                            { extend: 'print', text: '<i class="bi bi-printer me-1"></i> PRINT', className: 'btn btn-light fw-bolder border shadow-sm', style: 'border-radius: 12px;' }
                        ]
                    });
                    $('.dt-buttons .btn').css({ 'border-radius': '12px', 'font-weight': '800', 'color': '#475569', 'border-color': '#e2e8f0' });
                    $('#tablaOdontoHub_filter input').attr('placeholder', 'Buscar odontograma...').addClass('form-control rounded-pill px-3 shadow-sm').css('border-color', '#e2e8f0');
                    $('#tablaOdontoHub_filter label').contents().filter(function(){ return this.nodeType === 3; }).remove();
                }

                // 2. Inicializar DataTable de Detalle Anatómico (dentro del modal)
                if (window.jQuery && $.fn.DataTable && !$.fn.DataTable.isDataTable('#tablaDetalleHallazgos')) {
                    $('#tablaDetalleHallazgos').DataTable({
                        language: { url: 'https://cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
                        pageLength: 10,
                        order: [[0, 'asc']],
                        dom: "<'row mb-3 align-items-center'<'col-sm-12 col-md-6'l><'col-sm-12 col-md-6'f>>" +
                             "<'row'<'col-sm-12'tr>>" +
                             "<'row mt-3'<'col-sm-12 col-md-5'i><'col-sm-12 col-md-7'p>>"
                    });
                    $('#tablaDetalleHallazgos_filter input').attr('placeholder', 'Filtrar piezas o condiciones...').addClass('form-control rounded-pill px-3 shadow-sm').css('border-color', '#e2e8f0');
                }
            });

            // Función: Ver Detalle Anatómico en Modal (Ojo 👁️)
            window.verDetalleOdonto = function(idOdonto) {
                const item = window.ODONTO_COLLECTION[idOdonto];
                if (!item) {
                    if (window.Swal) Swal.fire({ icon: 'warning', title: 'Aviso', text: 'No se encontraron hallazgos registrados para este odontograma.' });
                    return;
                }

                document.getElementById('detalleOdontoAlias').textContent = item.alias || 'Odontograma General';
                document.getElementById('detalleOdontoFecha').innerHTML = '<i class="bi bi-clock-history me-1"></i>' + (item.fecha || 'Sin fecha');
                
                let badgeClass = 'bg-secondary-subtle text-secondary';
                if (item.estado === 'En Proceso' || item.estado === 'Activo') badgeClass = 'bg-warning-subtle text-warning-emphasis border border-warning-subtle';
                else if (item.estado === 'Planificado') badgeClass = 'bg-info-subtle text-info-emphasis border border-info-subtle';
                else if (item.estado === 'Finalizado') badgeClass = 'bg-success-subtle text-success border border-success-subtle';

                document.getElementById('detalleOdontoEstado').className = 'badge ' + badgeClass + ' px-3 py-1';
                document.getElementById('detalleOdontoEstado').textContent = item.estado || 'En Proceso';

                document.getElementById('detalleOdontoPiezas').textContent = (item.tot_piezas || 0) + ' Piezas Afectadas';
                document.getElementById('detalleOdontoImporte').textContent = '$' + (item.importe || '0.00') + ' MXN';

                const notasEl = document.getElementById('detalleOdontoNotas');
                if (item.notas && item.notas.trim() !== '') {
                    notasEl.innerHTML = '<div class="alert alert-light border small text-dark mb-3"><i class="bi bi-chat-quote-fill me-2 text-teal"></i><strong>Observaciones:</strong> ' + $('<div>').text(item.notas).html() + '</div>';
                } else {
                    notasEl.innerHTML = '';
                }

                const btnVisor = document.getElementById('btnVisorDesdeModal');
                if (btnVisor) {
                    btnVisor.href = 'render_visor_odontograma.pl?id=' + window.ID_PACIENTE_ODONTO + '&id_odonto=' + encodeURIComponent(idOdonto);
                }

                if (window.jQuery && $.fn.DataTable) {
                    const dt = $('#tablaDetalleHallazgos').DataTable();
                    dt.clear();
                    if (item.hallazgos && item.hallazgos.length > 0) {
                        item.hallazgos.forEach(h => {
                            const isPending = (h.categoria === 'PENDING');
                            const badgeEst = isPending
                                ? '<span class="badge bg-danger-subtle text-danger border border-danger-subtle"><i class="bi bi-exclamation-circle-fill me-1"></i>Pendiente</span>'
                                : '<span class="badge bg-primary-subtle text-primary border border-primary-subtle"><i class="bi bi-check-circle-fill me-1"></i>Existente</span>';
                            const costoClass = isPending ? 'text-danger fw-black' : 'text-primary fw-bold';
                            const costoFmt = '$' + parseFloat(h.costo || 0).toFixed(2) + ' MXN';

                            dt.row.add([
                                '<span class="badge bg-light border text-navy fs-6 px-3 py-1">#' + h.pieza + '</span>',
                                '<div class="fw-bold text-dark">' + h.nombre + '</div>',
                                '<span class="badge bg-secondary-subtle text-secondary border px-2 py-1">' + h.cara + '</span>',
                                '<div class="fw-bold">' + h.diagnostico + '</div>',
                                '<div class="text-center">' + badgeEst + '</div>',
                                '<div class="text-end ' + costoClass + ' fs-6">' + costoFmt + '</div>'
                            ]);
                        });
                    }
                    dt.draw();
                }

                const modalEl = document.getElementById('modalDetalleOdonto');
                if (modalEl && modalEl.parentNode !== document.body) {
                    document.body.appendChild(modalEl);
                }
                const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
                modal.show();
            };

            // Función: Abrir modal para crear nuevo odontograma
            window.abrirModalNuevoOdonto = function() {
                document.getElementById('formNuevoOdonto').reset();
                const now = new Date();
                const fechaStr = now.toLocaleDateString('es-MX', { year: 'numeric', month: 'short', day: 'numeric' });
                document.getElementById('nuevo_alias').value = 'Plan Odontología ' + fechaStr;
                const modalEl = document.getElementById('modalNuevoOdonto');
                if (modalEl && modalEl.parentNode !== document.body) {
                    document.body.appendChild(modalEl);
                }
                const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
                modal.show();
            };

            // Función: Guardar nuevo odontograma vía API
            window.guardarNuevoOdonto = function() {
                const alias = document.getElementById('nuevo_alias').value.trim();
                const estado = document.getElementById('nuevo_estado').value;
                const notas = document.getElementById('nuevo_notas').value.trim();

                if (!alias) {
                    if (window.Swal) Swal.fire({ icon: 'warning', title: 'Atención', text: 'Por favor asigna un nombre o alias al odontograma.' });
                    return;
                }

                const formData = new FormData();
                formData.append('accion', 'save');
                formData.append('id_paciente', window.ID_PACIENTE_ODONTO);
                formData.append('id_odonto', 'new');
                formData.append('alias', alias);
                formData.append('estado', estado);
                formData.append('notas', notas);
                formData.append('data', JSON.stringify({}));

                fetch('../api/odontograma_api.pl', {
                    method: 'POST',
                    body: formData
                })
                .then(r => r.json())
                .then(res => {
                    if (res.ok) {
                        const modalEl = document.getElementById('modalNuevoOdonto');
                        const modal = bootstrap.Modal.getInstance(modalEl);
                        if (modal) modal.hide();

                        const redirectUrl = 'render_visor_odontograma.pl?id=' + encodeURIComponent(window.ID_PACIENTE_ODONTO) + '&id_odonto=' + encodeURIComponent(res.id_odonto);
                        const hubUrl = 'render_expediente_clinico.pl?id=' + encodeURIComponent(window.ID_PACIENTE_ODONTO) + '#tab6';
                        if (window.Swal) {
                            Swal.fire({
                                icon: 'success',
                                title: '¡Odontograma Creado!',
                                text: 'Se ha creado el odontograma "' + alias + '". Abriendo visor...',
                                timer: 1500,
                                showConfirmButton: false
                            }).then(() => {
                                window.open(redirectUrl, '_blank');
                                window.location.href = hubUrl;
                                window.location.reload();
                            });
                        } else {
                            window.open(redirectUrl, '_blank');
                            window.location.href = hubUrl;
                            window.location.reload();
                        }
                    } else {
                        if (window.Swal) Swal.fire({ icon: 'error', title: 'Error', text: res.error || 'No se pudo crear el odontograma.' });
                        else alert(res.error || 'Error al crear odontograma');
                    }
                })
                .catch(err => {
                    console.error(err);
                    if (window.Swal) Swal.fire({ icon: 'error', title: 'Error de Red', text: 'No se pudo contactar al servidor.' });
                });
            };

            // Función: Abrir modal para editar metadatos
            window.editarOdontoMeta = function(idOdonto) {
                const item = window.ODONTO_COLLECTION[idOdonto];
                if (!item) return;

                document.getElementById('edit_id_odonto').value = idOdonto;
                document.getElementById('edit_alias').value = item.alias || '';
                document.getElementById('edit_estado').value = item.estado || 'En Proceso';
                document.getElementById('edit_notas').value = item.notas || '';

                const modalEl = document.getElementById('modalRenombrarOdonto');
                if (modalEl && modalEl.parentNode !== document.body) {
                    document.body.appendChild(modalEl);
                }
                const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
                modal.show();
            };

            // Función: Guardar cambios de metadatos vía API
            window.guardarRenombrarOdonto = function() {
                const idOdonto = document.getElementById('edit_id_odonto').value;
                const alias = document.getElementById('edit_alias').value.trim();
                const estado = document.getElementById('edit_estado').value;
                const notas = document.getElementById('edit_notas').value.trim();

                if (!alias) {
                    if (window.Swal) Swal.fire({ icon: 'warning', title: 'Atención', text: 'El alias no puede estar vacío.' });
                    return;
                }

                const formData = new FormData();
                formData.append('accion', 'rename');
                formData.append('id_paciente', window.ID_PACIENTE_ODONTO);
                formData.append('id_odonto', idOdonto);
                formData.append('alias', alias);
                formData.append('estado', estado);
                formData.append('notas', notas);

                fetch('../api/odontograma_api.pl', {
                    method: 'POST',
                    body: formData
                })
                .then(r => r.json())
                .then(res => {
                    if (res.ok) {
                        const modalEl = document.getElementById('modalRenombrarOdonto');
                        const modal = bootstrap.Modal.getInstance(modalEl);
                        if (modal) modal.hide();

                        const hubUrl = 'render_expediente_clinico.pl?id=' + encodeURIComponent(window.ID_PACIENTE_ODONTO) + '#tab6';
                        if (window.Swal) {
                            Swal.fire({
                                icon: 'success',
                                title: 'Actualizado',
                                text: 'Metadatos del odontograma actualizados correctamente.',
                                timer: 1200,
                                showConfirmButton: false
                            }).then(() => {
                                window.location.href = hubUrl;
                                window.location.reload();
                            });
                        } else {
                            window.location.href = hubUrl;
                            window.location.reload();
                        }
                    } else {
                        if (window.Swal) Swal.fire({ icon: 'error', title: 'Error', text: res.error || 'No se pudo actualizar.' });
                        else alert(res.error || 'Error al actualizar');
                    }
                })
                .catch(err => {
                    console.error(err);
                    if (window.Swal) Swal.fire({ icon: 'error', title: 'Error de Red', text: 'No se pudo contactar al servidor.' });
                });
            };

            // Función: Eliminar odontograma con confirmación SweetAlert2
            window.eliminarOdonto = function(idOdonto, alias) {
                const procederEliminar = () => {
                    const formData = new FormData();
                    formData.append('accion', 'delete');
                    formData.append('id_paciente', window.ID_PACIENTE_ODONTO);
                    formData.append('id_odonto', idOdonto);

                    fetch('../api/odontograma_api.pl', {
                        method: 'POST',
                        body: formData
                    })
                    .then(r => r.json())
                    .then(res => {
                        if (res.ok) {
                            const hubUrl = 'render_expediente_clinico.pl?id=' + encodeURIComponent(window.ID_PACIENTE_ODONTO) + '#tab6';
                            if (window.Swal) {
                                Swal.fire({
                                    icon: 'success',
                                    title: 'Eliminado',
                                    text: 'El odontograma ha sido eliminado.',
                                    timer: 1200,
                                    showConfirmButton: false
                                }).then(() => {
                                    window.location.href = hubUrl;
                                    window.location.reload();
                                });
                            } else {
                                window.location.href = hubUrl;
                                window.location.reload();
                            }
                        } else {
                            if (window.Swal) Swal.fire({ icon: 'error', title: 'Error', text: res.error || 'No se pudo eliminar el odontograma.' });
                            else alert(res.error || 'Error al eliminar');
                        }
                    })
                    .catch(err => {
                        console.error(err);
                        if (window.Swal) Swal.fire({ icon: 'error', title: 'Error de Red', text: 'No se pudo contactar al servidor.' });
                    });
                };

                if (window.Swal) {
                    Swal.fire({
                        title: '¿Eliminar odontograma?',
                        html: 'Se eliminará el odontograma <strong>"' + $('<div>').text(alias).html() + '"</strong> y todos sus hallazgos asociados.<br><span class="text-danger small">Esta acción no se puede deshacer.</span>',
                        icon: 'warning',
                        showCancelButton: true,
                        confirmButtonColor: '#d33',
                        cancelButtonColor: '#64748b',
                        confirmButtonText: '<i class="bi bi-trash3 me-1"></i> Sí, eliminar',
                        cancelButtonText: 'Cancelar'
                    }).then((result) => {
                        if (result.isConfirmed) {
                            procederEliminar();
                        }
                    });
                } else {
                    if (confirm('¿Eliminar el odontograma "' + alias + '"? Esta acción no se puede deshacer.')) {
                        procederEliminar();
                    }
                }
            };
        </script>
JS

    print <<HTML;
        <!-- 10: CONSULTAS (HUB CLÍNICO) -->
        <section class="sdm-tab-sec d-none" id="tab10">
            <div class="d-flex justify-content-between align-items-start align-items-md-center mb-4 flex-column flex-md-row gap-3">
                <div class="d-flex align-items-center gap-3">
                    <div class="rounded-circle d-flex align-items-center justify-content-center flex-shrink-0" style="width: 44px; height: 44px; background: rgba(25, 183, 165, 0.12); border: 1.5px solid rgba(25, 183, 165, 0.3);">
                        <i class="bi bi-heart-pulse-fill fs-5" style="color: var(--md-teal-clinical);"></i>
                    </div>
                    <div>
                        <h3 class="fw-black m-0" style="color: var(--md-blue-deep); letter-spacing: -0.5px;">Hub de Consultas</h3>
                        <p class="text-muted small fw-bold m-0" style="letter-spacing: 0.5px;">ATENCI&Oacute;N CL&Iacute;NICA Y TRAZABILIDAD</p>
                    </div>
                </div>
                <div class="d-flex gap-2 flex-wrap w-100 w-md-auto">
                    <a href="agenda_main.pl?id=$paciente->{id_paciente}" class="btn btn-outline-medentia flex-grow-1 flex-md-grow-0 d-flex align-items-center justify-content-center rounded-pill px-3 py-2 small fw-bold">
                        <i class="bi bi-calendar-event me-2" style="color: var(--md-teal-clinical);"></i>Gestionar Agenda
                    </a>
                    <a href="render_consultas_privado.pl?id=$paciente->{id_paciente}" class="btn btn-medentia flex-grow-1 flex-md-grow-0 d-flex align-items-center justify-content-center rounded-pill px-3 py-2 small fw-bold shadow-sm">
                        <i class="bi bi-lightning-charge-fill me-2" style="color: var(--md-cyan-ia);"></i>Consulta Express (Sin Cita)
                    </a>
                </div>
            </div>

            <!-- Panel Superior: Citas Pendientes de Atención -->
            <h5 class="fw-black mb-3" style="color: var(--md-blue-deep);"><i class="bi bi-calendar-check-fill me-2" style="color: var(--md-teal-clinical);"></i>Citas Programadas Listas para Atenderse</h5>
            <div class="row g-3 mb-5">
HTML
    my $hay_citas_pendientes = 0;
    foreach my $c (@$citas_ref) {
        if ($c->{estado} !~ /Realizada|Atendida|Cancelada/i) {
            $hay_citas_pendientes = 1;
            my $is_en_consulta = ($c->{estado} =~ /En consulta|proceso/i);
            my $badge_color = $is_en_consulta ? 'info' : ($c->{estado} =~ /Confirmada/i) ? 'success' : ($c->{estado} =~ /No Asistió|No Asistio/i) ? 'warning' : 'primary';
            my $btn_label = $is_en_consulta ? "Continuar con la consulta" : "Iniciar";
            my $btn_class = $is_en_consulta ? "btn btn-info text-white btn-sm d-flex align-items-center px-4 rounded-pill shadow-sm fw-bold" : "btn btn-medentia btn-sm d-flex align-items-center px-4 rounded-pill fw-bold";
            my $medico_nombre_pend = obtener_nombre_medico($c->{id_medico});
            print <<HTML;
                <div class="col-12 col-xl-6">
                    <div class="card-medentia-aura p-3 p-md-4 h-100 d-flex flex-column flex-sm-row justify-content-between align-items-start align-items-sm-center gap-3 border-0 shadow-sm" style="border-left: 5px solid var(--bs-$badge_color) !important; border-radius: 1.25rem;">
                        <div class="flex-grow-1 min-w-0 w-100">
                            <div class="d-flex align-items-center gap-2 flex-wrap mb-2">
                                <span class="badge bg-${badge_color} text-white px-2 py-1 small rounded-pill fw-bold">$c->{estado}</span>
                                <span class="badge bg-light text-secondary border px-2 py-1 small rounded-pill"><i class="bi bi-clock me-1"></i>$c->{fecha} &bull; $c->{hora}</span>
                            </div>
                            <h5 class="fw-bold m-0 text-truncate text-wrap" style="color: var(--md-blue-deep); font-size: 1.05rem;">$c->{motivo}</h5>
                            <p class="small text-muted m-0 mt-1 d-flex align-items-center"><i class="bi bi-person-badge me-1 text-primary"></i><strong>M&eacute;dico:</strong>&nbsp;$medico_nombre_pend</p>
                        </div>
                        <div class="w-100 w-sm-auto flex-shrink-0 mt-2 mt-sm-0">
                            <a href="render_consultas_privado.pl?id=$paciente->{id_paciente}&id_cita=$c->{id_cita}" class="$btn_class w-100 w-sm-auto justify-content-center">
                                $btn_label <i class="bi bi-arrow-right-short ms-1 fs-5"></i>
                            </a>
                        </div>
                    </div>
                </div>
HTML
        }
    }
    if (!$hay_citas_pendientes) {
        print <<HTML;
                <div class="col-12">
                    <div class="card-medentia-aura text-center p-5 border-0 shadow-sm" style="border-radius: 1.25rem;">
                        <i class="bi bi-calendar-x display-6 d-block mb-3 opacity-25" style="color: var(--md-blue-deep);"></i>
                        <span class="fw-bold text-muted">No hay citas programadas pendientes de atenci&oacute;n para este paciente.</span>
                    </div>
                </div>
HTML
    }
    print <<HTML;
            </div>

            <!-- Panel Inferior: Historial Cronológico de Consultas -->
            <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-journal-medical me-2" style="color: var(--md-teal-clinical);"></i>Historial de Consultas</h5>
            <div class="timeline-diamond mb-5">
HTML
    if (@$consultas_ref) {
        foreach my $cons (@$consultas_ref) {
            my $diagnostico = $cons->{data}->{diagnostico_principal} || $cons->{data}->{diagnostico} || 'Sin diagnóstico registrado';
            my $motivo = $cons->{data}->{motivo} || 'Consulta general';
            # Truncar textos largos
            my $diag_trunc = length($diagnostico) > 80 ? substr($diagnostico, 0, 80) . '...' : $diagnostico;
            
            my $badge_cita = $cons->{id_cita} ? "<span class='badge bg-info-subtle text-info border border-info-subtle mb-2'><i class='bi bi-link-45deg me-1'></i>Vinculado a Cita</span>" : "<span class='badge bg-secondary-subtle text-secondary border border-secondary-subtle mb-2'>Consulta Express</span>";
            
            my $meds_count = $cons->{meds_count} // 0;
            if (!$meds_count && $cons->{data}->{medicamentos} && ref($cons->{data}->{medicamentos}) eq 'ARRAY') {
                $meds_count = scalar @{$cons->{data}->{medicamentos}};
            }
            my $tiene_receta = $cons->{tiene_receta} // (($cons->{data}->{requiere_receta} && $cons->{data}->{requiere_receta} eq '1' && $meds_count > 0) ? 1 : 0);
            my $receta_html = $tiene_receta ? "<div class='mt-3 pt-3 border-top'><span class='badge bg-light text-dark border'><i class='bi bi-capsule text-primary me-1'></i> $meds_count F&aacute;rmaco(s) recetado(s)</span></div>" : "";
            my $btn_receta = $tiene_receta ? qq{<a href="../api/imprimir_receta_api.pl?id_consulta=$cons->{id_consulta}" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-capsule me-1"></i>Receta</a>} : "";

            my $tiene_consentimiento = $cons->{tiene_consentimiento} // (($cons->{data}->{requiere_consentimiento} && $cons->{data}->{requiere_consentimiento} eq '1') ? 1 : 0);
            my $btn_consentimiento = $tiene_consentimiento ? qq{<a href="../api/imprimir_consentimiento_api.pl?id_consulta=$cons->{id_consulta}" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-file-earmark-text me-1"></i>Consentimiento</a>} : "";

            my $nombre_medico = obtener_nombre_medico($cons->{id_medico});

            my $recibo_param_str = $cons->{folio_recibo} ? "id_consulta=$cons->{folio_recibo}&folio=$cons->{folio_recibo}" : "id_consulta=$cons->{id_consulta}";

            print <<HTML;
                <div class="timeline-item">
                    <div class="timeline-dot" style="border-color: var(--md-teal-clinical)"></div>
                    <div class="timeline-card card-medentia-aura p-3 p-md-4 border-0 shadow-sm" style="border-radius: 1.25rem;">
                        <div class="d-flex justify-content-between align-items-start mb-2 flex-column flex-md-row gap-3">
                            <div>
                                $badge_cita
                                <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);">$motivo</h5>
                                <p class="text-muted small mt-2 mb-0"><strong>Dx:</strong> $diag_trunc</p>
                            </div>
                            <div class="text-start text-md-end w-100 w-md-auto">
                                <div class="fw-black" style="font-size: 1.1rem; color: var(--md-teal-clinical);">$cons->{fecha}</div>
                                <div class="small text-muted fw-bold">M&eacute;dico: $nombre_medico</div>
                                <div class="d-flex gap-2 justify-content-start justify-content-md-end mt-2 flex-wrap">
                                    <a href="consulta_detalles.pl?id_consulta=$cons->{id_consulta}" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-eye-fill me-1"></i>Detalles</a>
                                    $btn_receta
                                    $btn_consentimiento
                                    <a href="../api/$recibo_script?$recibo_param_str" target="_blank" class="btn btn-sm btn-outline-primary rounded-pill px-3 fw-bold"><i class="bi bi-receipt me-1"></i>Recibo</a>
                                </div>
                            </div>
                        </div>
                        $receta_html
                    </div>
                </div>
HTML
        }
    } else {
        print <<HTML;
                <div class="card-medentia-aura text-center p-5">
                    <i class="bi bi-folder2-open display-1 opacity-25 mb-3 d-block" style="color: var(--md-blue-deep);"></i>
                    <h4 class="fw-black" style="color: var(--md-blue-deep);">Sin Historial Cl&iacute;nico</h4>
                    <p class="mx-auto text-muted" style="max-width: 500px;">A&uacute;n no hay consultas médicas finalizadas para este paciente.</p>
                </div>
HTML
    }
    print <<HTML;
            </div>
        </section>

        <!-- 7: RADIOGRAFÍAS / HUB DE ESTUDIOS -->
        <section class="sdm-tab-sec d-none" id="tab7">
            <div class="d-flex justify-content-between align-items-center mb-5 flex-wrap gap-3">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Hub de Im&aacute;genes y Estudios</h3>
                    <p class="text-muted small fw-bold">ADMINISTRADOR PACS Y VISOR DICOM</p>
                </div>
                <div class="d-flex gap-2 p-1 bg-transparent flex-wrap">
                    <a href="render_visor_medico.pl?id=$paciente->{id_paciente}" target="_blank" class="btn btn-medentia btn-sm d-flex align-items-center px-4">
                        <i class="bi bi-display me-2" style="color: var(--md-cyan-ia);"></i>Lanzar SDM Viewer
                    </a>
                </div>
            </div>

            <!-- Funciones de Subida removidas hacia el visor -->

            <!-- Bento Grid para el Hub de Estudios -->
            <div class="row g-4">
                <!-- Historial Reciente de Estudios (Dinámico) -->
                <div class="col-lg-8">
                    <h5 class="fw-black mt-1 mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-clock-history me-2" style="color: var(--md-teal-clinical);"></i>Estudios PACS</h5>
                    <div class="table-responsive card-medentia-aura p-4 h-100 border-0">
                        <table class="table table-hover align-middle mb-0" id="tablaEstudiosRX" style="width:100%">
                            <thead class="table-light">
                                <tr>
                                    <th class="ps-3 border-0 rounded-start-3">Fecha</th>
                                    <th class="border-0">Modalidad</th>
                                    <th class="border-0">Descripci&oacute;n</th>
                                    <th class="border-0 text-end pe-3 rounded-end-3">Acci&oacute;n</th>
                                </tr>
                            </thead>
                            <tbody class="small">
HTML
    my $ESTUDIOS_FILE_PATH = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');
    my $todos_estudios = leer_tabla($ESTUDIOS_FILE_PATH, '\|');
    my @estudios_pac = grep { $_->[1] eq $d->{id_paciente} } @$todos_estudios;
    
    # Sort reverse chronological (assuming simple string sort works for DD/MM/YYYY, though ideal is proper date sort)
    # We will just reverse the array since new ones are appended.
    @estudios_pac = reverse @estudios_pac;
    
    if (@estudios_pac) {
        foreach my $est (@estudios_pac) {
            my $id_estudio = $est->[0];
            my $fecha = $est->[2];
            my $modalidad = $est->[3];
            my $desc = $est->[4];
            
            my $mod_badge = 'bg-secondary-subtle text-secondary border border-secondary-subtle';
            if ($modalidad eq 'CT') { $mod_badge = 'bg-primary-subtle text-primary border border-primary-subtle'; }
            elsif ($modalidad eq 'XR') { $mod_badge = 'bg-info-subtle text-info border border-info-subtle'; }
            elsif ($modalidad eq 'MR') { $mod_badge = 'bg-warning-subtle text-warning border border-warning-subtle'; }
            
            # Sanitizar descripcion para JS
            my $safe_desc = $desc;
            $safe_desc =~ s/'/\\'/g;

            print <<HTML;
                                <tr>
                                    <td class="ps-3 fw-bold">$fecha</td>
                                    <td><span class="badge $mod_badge">$modalidad</span></td>
                                    <td class="fw-bold text-dark">$desc</td>
                                    <td class="text-end pe-3 text-nowrap">
                                        <a href="render_visor_medico.pl?id=$d->{id_paciente}&estudio_id=$id_estudio" target="_blank" class="btn btn-sm rounded-circle btn-outline-primary ms-1" style="width: 32px; height: 32px; padding: 0; line-height: 30px;" title="Abrir Visor"><i class="bi bi-box-arrow-up-right"></i></a>
                                        <button class="btn btn-sm rounded-circle btn-outline-warning ms-1" style="width: 32px; height: 32px; padding: 0; line-height: 30px;" onclick="editarEstudio($id_estudio, '$safe_desc')" title="Editar Descripción"><i class="bi bi-pencil"></i></button>
                                        <button class="btn btn-sm rounded-circle btn-outline-danger ms-1" style="width: 32px; height: 32px; padding: 0; line-height: 30px;" onclick="eliminarEstudio($id_estudio)" title="Eliminar"><i class="bi bi-trash"></i></button>
                                    </td>
                                </tr>
HTML
        }
    } else {
        # Dejamos el tbody vacio para que DataTables muestre su propio mensaje de "sin datos"
    }
    
    print <<HTML;
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Axios para acciones de estudio -->
                <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
HTML

    print <<'JS';
                <script>
                    document.addEventListener('DOMContentLoaded', function() {
                        const tbl = $('#tablaEstudiosRX').DataTable({
                            language: { url: 'https://cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
                            pageLength: 10,
                            dom: "<'row mb-3 align-items-center'<'col-sm-12 col-md-6 d-flex flex-wrap gap-2'B><'col-sm-12 col-md-6'f>>" +
                                 "<'row'<'col-sm-12'tr>>" +
                                 "<'row mt-3'<'col-sm-12 col-md-5'i><'col-sm-12 col-md-7'p>>",
                            buttons: [
                                {
                                    extend: 'copy',
                                    text: '<i class="bi bi-clipboard me-1"></i> COPY',
                                    className: 'btn btn-light fw-bolder border shadow-sm',
                                    style: 'border-radius: 12px;'
                                },
                                {
                                    extend: 'excel',
                                    text: '<i class="bi bi-file-earmark-excel me-1"></i> EXCEL',
                                    className: 'btn btn-light fw-bolder border shadow-sm',
                                    style: 'border-radius: 12px;'
                                },
                                {
                                    extend: 'pdf',
                                    text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF',
                                    className: 'btn btn-light fw-bolder border shadow-sm',
                                    style: 'border-radius: 12px;'
                                },
                                {
                                    extend: 'print',
                                    text: '<i class="bi bi-printer me-1"></i> PRINT',
                                    className: 'btn btn-light fw-bolder border shadow-sm',
                                    style: 'border-radius: 12px;'
                                }
                            ]
                        });
                        
                        // Aplicar estilos post-init a la barra de búsqueda y botones
                        $('.dt-buttons .btn').css({ 'border-radius': '12px', 'font-weight': '800', 'color': '#475569', 'border-color': '#e2e8f0' });
                        $('.dataTables_filter input').attr('placeholder', 'Buscar...').addClass('form-control rounded-pill px-3 shadow-sm').css('border-color', '#e2e8f0');
                        $('.dataTables_filter label').contents().filter(function(){ return this.nodeType === 3; }).remove();
                    });

                    function eliminarEstudio(id) {
                        Swal.fire({
                            title: '¿Eliminar Estudio?',
                            text: 'Esta acción no se puede deshacer.',
                            icon: 'warning',
                            showCancelButton: true,
                            confirmButtonColor: '#dc3545',
                            confirmButtonText: 'Sí, eliminar',
                            cancelButtonText: 'Cancelar'
                        }).then((result) => {
                            if (result.isConfirmed) {
                                axios.post('../api/delete_estudio_api.pl', new URLSearchParams({id_estudio: id}))
                                .then(res => {
                                    if(res.data.ok) {
                                        Swal.fire('Eliminado', 'El estudio ha sido borrado.', 'success').then(() => {
                                            let dt = $('#tablaEstudiosRX').DataTable();
                                            let row = $('button[onclick*="eliminarEstudio("]').filter(function() {
                                                return $(this).attr('onclick').indexOf(String(id)) !== -1;
                                            }).closest('tr');
                                            if (row.length) dt.row(row).remove().draw();
                                        });
                                    } else {
                                        Swal.fire('Error', res.data.msg, 'error');
                                    }
                                });
                            }
                        });
                    }

                    function editarEstudio(id, descActual) {
                        Swal.fire({
                            title: 'Editar Descripción',
                            input: 'text',
                            inputValue: descActual,
                            showCancelButton: true,
                            confirmButtonText: 'Guardar',
                            cancelButtonText: 'Cancelar',
                            inputValidator: (value) => {
                                if (!value) return 'La descripción no puede estar vacía';
                            }
                        }).then((result) => {
                            if (result.isConfirmed) {
                                axios.post('../api/update_estudio_api.pl', new URLSearchParams({
                                    id_estudio: id, 
                                    descripcion: result.value
                                }))
                                .then(res => {
                                    if(res.data.ok) {
                                        Swal.fire('Actualizado', 'La descripción ha sido cambiada.', 'success').then(() => {
                                            let td = $('button[onclick*="editarEstudio("]').filter(function() {
                                                return $(this).attr('onclick').indexOf(String(id)) !== -1;
                                            }).closest('tr').find('td').eq(1);
                                            if(td.length) td.text(result.value);
                                        });
                                    } else {
                                        Swal.fire('Error', res.data.msg, 'error');
                                    }
                                });
                            }
                        });
                    }
                </script>
JS

    print <<HTML;


                <!-- Resumen de Almacenamiento -->
                <div class="col-lg-4">
                    <div class="card-medentia-aura p-4 border-0 h-100">
                        <h6 class="fw-black mb-4 uppercase" style="color: var(--md-blue-deep); font-size: 0.8rem; letter-spacing: 1px;">Almacenamiento PACS</h6>
                        
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">2.4 <span class="fs-6 text-muted">GB</span></h3>
                            <i class="bi bi-hdd-network fs-3" style="color: var(--md-teal-clinical);"></i>
                        </div>
                        <p class="small text-muted fw-bold mb-4">Espacio utilizado por el paciente</p>

                        <div class="progress mb-3" style="height: 8px; border-radius: 10px;">
                            <div class="progress-bar bg-primary" role="progressbar" style="width: 45%" aria-valuenow="45" aria-valuemin="0" aria-valuemax="100"></div>
                        </div>
                        
                        <ul class="list-group list-group-flush small">
                            <li class="list-group-item px-0 d-flex justify-content-between align-items-center border-0 py-1">
                                <span><i class="bi bi-circle-fill text-primary me-2" style="font-size: 0.5rem;"></i>Tomograf&iacute;as (CT)</span>
                                <span class="fw-bold text-dark">1.8 GB</span>
                            </li>
                            <li class="list-group-item px-0 d-flex justify-content-between align-items-center border-0 py-1">
                                <span><i class="bi bi-circle-fill text-info me-2" style="font-size: 0.5rem;"></i>Radiograf&iacute;as (XR)</span>
                                <span class="fw-bold text-dark">450 MB</span>
                            </li>
                            <li class="list-group-item px-0 d-flex justify-content-between align-items-center border-0 py-1">
                                <span><i class="bi bi-circle-fill text-secondary me-2" style="font-size: 0.5rem;"></i>Fotograf&iacute;as</span>
                                <span class="fw-bold text-dark">150 MB</span>
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </section>

        <!-- 1: FINANZAS (OPERATIVO TOTAL) -->
        <section class="sdm-tab-sec d-none" id="tab1">
            <h3 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-wallet2 me-2" style="color: var(--md-teal-clinical);"></i>Estado de Cuenta</h3>
            <div class="row g-3 mb-4">
                <div class="col-md-3"><div class="card-medentia-aura border-0 p-4 h-100">
                    <span class="small fw-bold text-muted text-uppercase mb-2 d-block">Saldo Pendiente</span>
                    <div class="d-flex justify-content-between align-items-center">
                        <h3 id="ecSaldo" class="fw-black text-danger m-0">\$0.00</h3>
                        <button onclick="abrirModalAbono()" class="btn btn-sm btn-outline-success fw-bold rounded-pill px-3 py-1">PAGAR</button>
                    </div>
                </div></div>
                <div class="col-md-3"><div class="card-medentia-aura border-0 p-4 h-100"><span class="small fw-bold text-muted text-uppercase mb-2 d-block">Cargos</span><h4 id="ecCargos" class="m-0 fw-bold" style="color: var(--md-blue-deep);">\$0.00</h4></div></div>
                <div class="col-md-3"><div class="card-medentia-aura border-0 p-4 h-100"><span class="small fw-bold text-muted text-uppercase mb-2 d-block">Abonos</span><h4 id="ecAbonos" class="m-0 text-success fw-bold">\$0.00</h4></div></div>
                <div class="col-md-3">
                    <button class="btn btn-medentia w-100 h-100 fw-black d-flex flex-column align-items-center justify-content-center" onclick="abrirModalCarrito()">
                        <i class="bi bi-cart-plus mb-2" style="font-size: 1.5rem; color: var(--md-cyan-ia);"></i>NUEVO CARGO
                    </button>
                </div>
            </div>
            <div class="card-medentia-aura border-0 p-4 overflow-hidden">
                <h6 class="fw-black mb-3" style="color: var(--md-blue-deep);">Movimientos de Cuenta</h6>
                <div class="table-responsive">
                    <table class="table table-sm table-hover align-middle mb-0">
                        <thead class="table-light"><tr><th class="ps-3">Folio</th><th>Fecha</th><th>Concepto</th><th class="text-end">Cargo</th><th class="text-end">Abono</th></tr></thead>
                        <tbody id="tbEdoCuenta" class="small"><tr><td colspan="5" class="text-center py-4">Iniciando motor financiero...</td></tr></tbody>
                    </table>
                </div>
            </div>
        </section>

        <!-- 2: DASHBOARD CLÍNICO (SUB-MÓDULO 1.4 REFACTORIZADO / RESUMEN) -->
        <section class="sdm-tab-sec" id="tab2">
            <!-- NIVEL 1: SIGNOS VITALES DE ÚLTIMA CONSULTA (DIRECTO DEBAJO DEL HERO) -->
            <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
                <h6 class="fw-black m-0 uppercase" style="color: var(--md-blue-deep); letter-spacing: 0.5px;"><i class="bi bi-activity me-1" style="color: var(--md-teal-clinical);"></i> Signos Vitales de &Uacute;ltima Consulta</h6>
                <div>$badge_fecha_signos</div>
            </div>
            <div class="row g-2 g-md-3 mb-4">
                <div class="col-4 col-md-2">
                    <div class="card-medentia-aura p-2 p-md-3 text-center border-0 shadow-sm h-100 d-flex flex-column justify-content-center" style="border-radius: 1rem; background: white;">
                        <span class="d-block small fw-bold text-muted text-uppercase mb-1" style="font-size: 0.7rem;"><i class="bi bi-heart-pulse text-danger me-1"></i> T.A.</span>
                        <div class="fw-black fs-6 fs-md-5" style="color: var(--md-blue-deep);">$ta_val</div>
                        <span class="small text-muted" style="font-size: 0.65rem;">mmHg</span>
                    </div>
                </div>
                <div class="col-4 col-md-2">
                    <div class="card-medentia-aura p-2 p-md-3 text-center border-0 shadow-sm h-100 d-flex flex-column justify-content-center" style="border-radius: 1rem; background: white;">
                        <span class="d-block small fw-bold text-muted text-uppercase mb-1" style="font-size: 0.7rem;"><i class="bi bi-activity text-primary me-1"></i> F.C.</span>
                        <div class="fw-black fs-6 fs-md-5" style="color: var(--md-blue-deep);">$fc_val</div>
                        <span class="small text-muted" style="font-size: 0.65rem;">bpm</span>
                    </div>
                </div>
                <div class="col-4 col-md-2">
                    <div class="card-medentia-aura p-2 p-md-3 text-center border-0 shadow-sm h-100 d-flex flex-column justify-content-center" style="border-radius: 1rem; background: white;">
                        <span class="d-block small fw-bold text-muted text-uppercase mb-1" style="font-size: 0.7rem;"><i class="bi bi-wind text-info me-1"></i> F.R.</span>
                        <div class="fw-black fs-6 fs-md-5" style="color: var(--md-blue-deep);">$fr_val</div>
                        <span class="small text-muted" style="font-size: 0.65rem;">rpm</span>
                    </div>
                </div>
                <div class="col-4 col-md-2">
                    <div class="card-medentia-aura p-2 p-md-3 text-center border-0 shadow-sm h-100 d-flex flex-column justify-content-center" style="border-radius: 1rem; background: white;">
                        <span class="d-block small fw-bold text-muted text-uppercase mb-1" style="font-size: 0.7rem;"><i class="bi bi-thermometer-half text-warning me-1"></i> Temp</span>
                        <div class="fw-black fs-6 fs-md-5" style="color: var(--md-blue-deep);">$temp_val</div>
                        <span class="small text-muted" style="font-size: 0.65rem;">&deg;C</span>
                    </div>
                </div>
                <div class="col-4 col-md-2">
                    <div class="card-medentia-aura p-2 p-md-3 text-center border-0 shadow-sm h-100 d-flex flex-column justify-content-center" style="border-radius: 1rem; background: white;">
                        <span class="d-block small fw-bold text-muted text-uppercase mb-1" style="font-size: 0.7rem;"><i class="bi bi-speedometer2 text-success me-1"></i> SpO2</span>
                        <div class="fw-black fs-6 fs-md-5" style="color: var(--md-blue-deep);">$spo2_val</div>
                        <span class="small text-muted" style="font-size: 0.65rem;">%</span>
                    </div>
                </div>
                <div class="col-4 col-md-2">
                    <div class="card-medentia-aura p-2 p-md-3 text-center border-0 shadow-sm h-100 d-flex flex-column justify-content-center" style="border-radius: 1rem; background: white;">
                        <span class="d-block small fw-bold text-muted text-uppercase mb-1" style="font-size: 0.7rem;"><i class="bi bi-droplet-fill text-danger me-1"></i> Sangre</span>
                        <div class="fw-black fs-6 fs-md-5" style="color: var(--md-blue-deep);">$d->{tipo_sangre}</div>
                        <span class="small text-muted" style="font-size: 0.65rem;">Grupo / Rh</span>
                    </div>
                </div>
            </div>

            <!-- NIVEL 2: KPIS DE TRAZABILIDAD CLÍNICA & ADHERENCIA -->
            <div class="row g-3 mb-4">
                <!-- KPI: Consultas Atendidas -->
                <div class="col-md-4">
                    <div class="card-medentia-aura p-4 border-0 shadow-sm h-100" style="border-radius: 1.25rem; background: white;">
                        <div class="d-flex align-items-center justify-content-between mb-3">
                            <span class="small fw-bold text-muted text-uppercase">Atenciones Cl&iacute;nicas</span>
                            <div class="p-2 rounded-circle bg-primary-subtle text-primary"><i class="bi bi-journal-check fs-4"></i></div>
                        </div>
                        <div class="display-6 fw-black" style="color: var(--md-blue-deep);">$count_consultas</div>
                        <p class="small text-muted fw-semibold mb-0 mt-1">Consultas m&eacute;dicas realizadas en expediente</p>
                    </div>
                </div>

                <!-- KPI: Adherencia a Citas -->
                <div class="col-md-4">
                    <div class="card-medentia-aura p-4 border-0 shadow-sm h-100" style="border-radius: 1.25rem; background: white;">
                        <div class="d-flex align-items-center justify-content-between mb-3">
                            <span class="small fw-bold text-muted text-uppercase">Adherencia a Citas</span>
                            <div class="p-2 rounded-circle bg-success-subtle text-success"><i class="bi bi-calendar-check fs-4"></i></div>
                        </div>
                        <div class="display-6 fw-black text-success">${pct_asistencia}%</div>
                        <p class="small text-muted fw-semibold mb-0 mt-1">$citas_atendidas atendidas de $count_c citas programadas</p>
                    </div>
                </div>

                <!-- KPI: Ficha Social & Contacto -->
                <div class="col-md-4">
                    <div class="card-medentia-aura p-4 border-0 shadow-sm h-100" style="border-radius: 1.25rem; background: white;">
                        <div class="d-flex align-items-center justify-content-between mb-2">
                            <span class="small fw-bold text-muted text-uppercase">Ficha Social y Contacto</span>
                            <div class="p-2 rounded-circle bg-info-subtle text-info"><i class="bi bi-person-badge fs-4"></i></div>
                        </div>
                        <div class="small fw-bold mb-1" style="color: var(--md-blue-deep);">Ocupaci&oacute;n: <span class="fw-normal text-muted">$d->{ocupacion}</span></div>
                        <div class="small fw-bold mb-1" style="color: var(--md-blue-deep);">Estado Civil: <span class="fw-normal text-muted">$d->{e_civil}</span></div>
                        <div class="small fw-bold mb-0" style="color: var(--md-blue-deep);">Tel&eacute;fono: <span class="fw-normal text-muted">$d->{tel}</span></div>
                    </div>
                </div>
            </div>

            <!-- NIVEL 3: ALERTAS CLÍNICAS & EVALUACIÓN IMC / NUTRICIONAL -->
            <div class="row g-3 mb-4">
                <div class="col-lg-7">
                    <!-- Alertas Médicas & Alergias -->
                    <div class="card-medentia-aura p-4 h-100 border-0 shadow-sm" style="border-radius: 1.25rem; background: #ffffff;">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <span class="small fw-bold text-uppercase" style="letter-spacing: 0.5px; color: #e11d48;"><i class="bi bi-shield-exclamation me-1"></i> Alertas M&eacute;dicas y Alergias</span>
                            <span class="badge @{[ $tiene_alergias ? 'bg-danger text-white' : 'bg-success-subtle text-success border border-success-subtle' ]} rounded-pill px-3 py-1 fw-bold">
                                @{[ $tiene_alergias ? 'REACCIÓN ADVERSA REGISTRADA' : 'SIN ALERGIAS CONOCIDAS' ]}
                            </span>
                        </div>
                        
                        @{[ $tiene_alergias ? qq{
                            <div class="d-flex align-items-center gap-3 p-3 bg-danger-subtle rounded-4 border border-danger-subtle mb-2">
                                <i class="bi bi-exclamation-octagon-fill text-danger fs-2"></i>
                                <div>
                                    <h6 class="m-0 fw-black text-danger">Alergias Reportadas: $alergias_txt</h6>
                                    <p class="m-0 small text-danger-emphasis">Precaución al prescribir fármacos o aplicar materiales en tratamiento.</p>
                                </div>
                            </div>
                        } : qq{
                            <div class="d-flex align-items-center gap-3 p-3 bg-light rounded-4 border mb-2">
                                <i class="bi bi-check-circle-fill text-success fs-3"></i>
                                <div>
                                    <h6 class="m-0 fw-bold" style="color: var(--md-blue-deep);">Sin Alergias Medicamentosas Registradas</h6>
                                    <p class="m-0 small text-muted">El paciente no refiere reacciones adversas ni sensibilidad a fármacos al momento.</p>
                                </div>
                            </div>
                        } ]}
                        
                        <div class="mt-3 pt-3 border-top d-flex justify-content-between align-items-center">
                            <span class="small text-muted fw-bold">Diagn&oacute;stico Activo:</span>
                            <span class="fw-bold" style="color: var(--md-blue-deep);">$diag_activo @{[ $cie10_activo ? "<span class='badge bg-primary-subtle text-primary border rounded-pill ms-1'>$cie10_activo</span>" : "" ]}</span>
                        </div>
                    </div>
                </div>

                <div class="col-lg-5">
                    <!-- Resumen Salud e IMC Card Blanco -->
                    <div class="card-medentia-aura p-4 h-100 border-0 shadow-sm" style="border-radius: 1.25rem; background: #ffffff !important;">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <span class="small fw-bold text-uppercase" style="letter-spacing: 0.5px; color: var(--md-blue-deep);"><i class="bi bi-person-bounding-box me-1" style="color: var(--md-teal-clinical);"></i> Estado Nutricional e IMC</span>
                            <span class="badge $imc_badge rounded-pill px-3 py-1 fw-bold">$imc_status</span>
                        </div>
                        <div class="row align-items-center my-2">
                            <div class="col-6">
                                <div class="display-5 fw-black" style="color: var(--md-blue-deep); line-height: 1;">$imc_val</div>
                                <div class="small text-muted fw-semibold mt-1">kg/m&sup2; (IMC)</div>
                            </div>
                            <div class="col-6 text-end">
                                <div class="small text-muted fw-bold">Peso: <strong class="fs-6" style="color: var(--md-blue-deep);">$peso_val kg</strong></div>
                                <div class="small text-muted fw-bold mt-2">Talla: <strong class="fs-6" style="color: var(--md-blue-deep);">$talla_val cm</strong></div>
                            </div>
                        </div>
                        <div class="mt-3">
                            <div class="progress" style="height: 8px; background: #e2e8f0; border-radius: 10px;">
                                <div class="progress-bar bg-info" role="progressbar" style="width: ${imc_perc}%; border-radius: 10px;"></div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- 3: FICHA DE IDENTIFICACIÓN (SOLO LECTURA) -->
        <section class="sdm-tab-sec d-none" id="tab3">
            <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);"><i class="bi bi-person-vcard-fill me-2" style="color: var(--md-teal-clinical);"></i>Ficha de Identificación</h3>
                    <p class="text-muted small fw-bold mb-0">EXPEDIENTE MAESTRO DEL PACIENTE (LECTURA)</p>
                </div>
                <div>
                    <a href="crud_paciente.pl?id=$paciente->{id_paciente}&from=expediente" class="btn btn-medentia btn-sm rounded-pill px-4 py-2 fw-bold shadow-sm d-inline-flex align-items-center gap-2">
                        <i class="bi bi-pencil-square" style="color: var(--md-cyan-ia);"></i><span>Editar Ficha</span>
                    </a>
                </div>
            </div>

            <div class="row g-4">
                <div class="col-lg-8">
                    <div class="card-medentia-aura p-5 h-100">
                        <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-person-lines-fill me-2" style="color: var(--md-teal-clinical);"></i>Informaci&oacute;n de Identidad</h5>
                        <div class="row g-3">
                            <div class="col-md-12"><div class="form-floating diamond-input-armor"><input class="form-control" value="$paciente->{nombre}" readonly disabled><label>Nombre Completo</label></div></div>
                            <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" value="$paciente->{rfc}" readonly disabled><label>RFC</label></div></div>
                            <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" value="$paciente->{curp}" readonly disabled><label>CURP</label></div></div>
                            <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" value="$paciente->{email}" readonly disabled><label>Correo Electr&oacute;nico</label></div></div>
                            <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" value="$paciente->{tel}" readonly disabled><label>Tel&eacute;fono de Contacto</label></div></div>
                            <div class="col-md-4">
                                <div class="form-floating diamond-input-armor">
                                    <input class="form-control" value="$paciente->{sexo}" readonly disabled>
                                    <label>G&eacute;nero</label>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="form-floating diamond-input-armor">
                                    <input class="form-control" value="$paciente->{f_nac}" readonly disabled>
                                    <label>Fecha de Nacimiento @{[ $edad ne '' ? "<span class='badge " . ($edad < 18 ? "bg-success-subtle text-success border border-success-subtle" : "bg-primary text-white") . " ms-1'>$edad a&ntilde;os" . ($edad < 18 ? " (Menor de edad)" : "") . "</span>" : "" ]}</label>
                                </div>
                            </div>
                            <div class="col-md-4"><div class="form-floating diamond-input-armor"><input class="form-control" value="$paciente->{nacionalidad}" readonly disabled><label>Nacionalidad</label></div></div>
                            @{[ ($edad ne '' && $edad < 18) || $paciente->{tutor} ? qq{
                                <div class="col-md-12 mt-3">
                                    <div class="form-floating diamond-input-armor">
                                        <input type="text" class="form-control fw-bold border-success-subtle" value="$paciente->{tutor}" readonly disabled>
                                        <label class="text-success fw-bold"><i class="bi bi-shield-person-fill me-1" style="color: var(--md-teal-clinical);"></i>Responsable / Tutor Legal *</label>
                                    </div>
                                </div>
                            } : '' ]}
                        </div>
                    </div>
                </div>
                <div class="col-lg-4">
                    <div class="card-medentia-aura p-5 h-100">
                        <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-heart-pulse-fill me-2" style="color: var(--md-teal-clinical);"></i>Datos Cl&iacute;nicos</h5>
                        <div class="mb-4 diamond-input-armor">
                            <label class="small fw-bold text-muted mb-2 ps-1">Grupo Sangu&iacute;neo</label>
                            <input class="form-control py-3 fw-bold" value="$paciente->{tipo_sangre}" readonly disabled>
                        </div>
                        <div class="mb-4 diamond-input-armor">
                            <label class="small fw-bold text-muted mb-2 ps-1">Estado Civil</label>
                            <input class="form-control py-3 fw-bold" value="$paciente->{e_civil}" readonly disabled>
                        </div>
                        <div class="mb-4 diamond-input-armor">
                            <label class="small fw-bold text-muted mb-2 ps-1">Ocupaci&oacute;n</label>
                            <div class="input-group">
                                <span class="input-group-text border-0 bg-transparent ps-3"><i class="bi bi-briefcase" style="color: var(--md-teal-clinical);"></i></span>
                                <input class="form-control py-3 fw-bold" value="$paciente->{ocupacion}" readonly disabled>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- CARD DOMICILIO (SOLO LECTURA) -->
            @{[ do {
                my $ant = $paciente->{antecedentes} // {};
                my $dom = $paciente->{domicilio} || $ant->{domicilio} || {};
                my $cp = $dom->{cp} || 'No registrado';
                my $ent = $dom->{entidad} || 'No registrada';
                my $mun = $dom->{municipio} || 'No registrado';
                my $col = $dom->{colonia} || 'No registrada';
                my $calle = $dom->{calle} || 'No registrada';
                my $n_ext = $dom->{num_ext} || '--';
                my $n_int = $dom->{num_int} ? " Int. $dom->{num_int}" : '';

                qq{
                    <div class="card-medentia-aura p-5 border-0 shadow-sm mt-4 mb-4" style="border-radius: 1.5rem; background: #ffffff;">
                        <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                            <h5 class="fw-black m-0" style="color: var(--md-blue-deep);"><i class="bi bi-geo-alt-fill me-2" style="color: var(--md-teal-clinical);"></i>Domicilio</h5>
                            <span class="badge bg-light text-muted border px-3 py-1 rounded-pill small fw-bold"><i class="bi bi-patch-check-fill text-info me-1"></i>Cat&aacute;logo Oficial SEPOMEX / INEGI</span>
                        </div>
                        <div class="row g-3">
                            <div class="col-md-3"><div class="form-floating diamond-input-armor"><input class="form-control" value="$cp" readonly disabled><label>C&oacute;digo Postal (CP)</label></div></div>
                            <div class="col-md-4"><div class="form-floating diamond-input-armor"><input class="form-control" value="$ent" readonly disabled><label>Entidad Federativa</label></div></div>
                            <div class="col-md-5"><div class="form-floating diamond-input-armor"><input class="form-control" value="$mun" readonly disabled><label>Municipio / Alcald&iacute;a</label></div></div>
                            <div class="col-md-5"><div class="form-floating diamond-input-armor"><input class="form-control" value="$col" readonly disabled><label>Colonia / Asentamiento</label></div></div>
                            <div class="col-md-7"><div class="form-floating diamond-input-armor"><input class="form-control" value="$calle" readonly disabled><label>Calle / Avenida</label></div></div>
                            <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" value="$n_ext" readonly disabled><label>N&uacute;mero Exterior</label></div></div>
                            <div class="col-md-6"><div class="form-floating diamond-input-armor"><input class="form-control" value="$n_int" readonly disabled><label>N&uacute;mero Interior</label></div></div>
                        </div>
                    </div>
                };
            } ]}

            <!-- M&Oacute;DULO COMPLETO DE ANTECEDENTES DEL EXPEDIENTE (SOLO RESUMEN ESTRUCTURADO) -->
            @{[ do {
                my $ant = $paciente->{antecedentes} // {};
                my $hf  = $ant->{heredofamiliares} // {};
                my $pp  = $ant->{personales_patologicos} // {};
                my $pnp = $ant->{personales_no_patologicos} // {};

                my $fmt_badge = sub {
                    my ($label, $val, $spec) = @_;
                    my $is_si = ($val && $val =~ /S[ií]/i);
                    my $badge_cls = $is_si ? 'bg-danger-subtle text-danger border border-danger-subtle' : 'bg-light text-muted border';
                    my $icon = $is_si ? '<i class="bi bi-exclamation-triangle-fill me-1"></i>' : '<i class="bi bi-check-circle me-1"></i>';
                    my $txt = "$icon<strong>$label:</strong> " . ($val || 'No');
                    if ($is_si && $spec) {
                        $txt .= " <em>($spec)</em>";
                    }
                    return qq{<span class="badge $badge_cls p-2 fw-medium text-wrap text-start me-1 mb-1">$txt</span>};
                };

                my $hf_html = '';
                $hf_html .= $fmt_badge->("Hipertensión", $hf->{hipertension});
                $hf_html .= $fmt_badge->("Diabetes", $hf->{diabetes});
                $hf_html .= $fmt_badge->("Cardiopatías", $hf->{cardiopatias});
                $hf_html .= $fmt_badge->("Cáncer", $hf->{cancer}, $hf->{cancer_tipo});
                $hf_html .= $fmt_badge->("Hereditarias", $hf->{enfermedades}, $hf->{enfermedades_especificar});
                $hf_html .= $fmt_badge->("Alergias Fam.", $hf->{alergias}, $hf->{alergias_especificar});

                my $pp_html = '';
                $pp_html .= $fmt_badge->("Crónicas", $pp->{cronicas}, $pp->{cronicas_especificar});
                $pp_html .= $fmt_badge->("Cirugías", $pp->{cirugias}, $pp->{cirugias_especificar});
                $pp_html .= $fmt_badge->("Hospitalizaciones", $pp->{hospitalizaciones}, $pp->{hospitalizaciones_especificar});
                $pp_html .= $fmt_badge->("Alergias", $pp->{alergias}, $pp->{alergias_especificar});
                $pp_html .= $fmt_badge->("Tratamientos", $pp->{tratamientos}, $pp->{tratamientos_especificar});

                my $pnp_html = '';
                $pnp_html .= $fmt_badge->("Tabaquismo", $pnp->{tabaquismo}, $pnp->{tabaquismo_cantidad} ? "$pnp->{tabaquismo_cantidad} cig/día" : '');
                $pnp_html .= $fmt_badge->("Alcoholismo", $pnp->{alcohol}, $pnp->{alcohol_frecuencia});
                $pnp_html .= $fmt_badge->("Drogas", $pnp->{drogas}, $pnp->{drogas_tipo});
                $pnp_html .= $fmt_badge->("Act. Física", $pnp->{actividad_fisica}, $pnp->{actividad_fisica_tipo});
                my $alim_txt = $pnp->{alimentacion} || 'Balanceada';
                if ($alim_txt eq 'Otro' && $pnp->{alimentacion_otro}) {
                    $alim_txt .= " ($pnp->{alimentacion_otro})";
                }
                $pnp_html .= qq{<span class="badge bg-light text-dark border p-2 fw-medium me-1 mb-1"><i class="bi bi-egg-fried me-1 text-info"></i><strong>Alimentación:</strong> $alim_txt</span>};

                qq{
                    <div class="card-medentia-aura p-5 border-0 shadow-sm mt-4" style="border-radius: 1.5rem; background: #ffffff;">
                        <h5 class="fw-black mb-4" style="color: var(--md-blue-deep);"><i class="bi bi-journal-medical me-2" style="color: var(--md-teal-clinical);"></i>Antecedentes</h5>
                        <div class="row g-3">
                            <div class="col-md-4">
                                <div class="p-3 bg-white rounded-3 border h-100 shadow-sm">
                                    <div class="fw-bold small mb-2 border-bottom pb-1" style="color: var(--md-blue-deep);"><i class="bi bi-people-fill me-1" style="color: var(--md-teal-clinical);"></i>Heredofamiliares</div>
                                    <div class="d-flex flex-wrap">$hf_html</div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="p-3 bg-white rounded-3 border h-100 shadow-sm">
                                    <div class="fw-bold small mb-2 border-bottom pb-1" style="color: var(--md-blue-deep);"><i class="bi bi-file-earmark-medical-fill me-1" style="color: var(--md-teal-clinical);"></i>Personales Patol&oacute;gicos</div>
                                    <div class="d-flex flex-wrap">$pp_html</div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="p-3 bg-white rounded-3 border h-100 shadow-sm">
                                    <div class="fw-bold small mb-2 border-bottom pb-1" style="color: var(--md-blue-deep);"><i class="bi bi-heart-pulse me-1" style="color: var(--md-teal-clinical);"></i>Personales No Patol&oacute;gicos</div>
                                    <div class="d-flex flex-wrap">$pnp_html</div>
                                </div>
                            </div>
                        </div>
                    </div>
                };
            } ]}
        </section>

        <!-- 8: FHIR (INTEROPERABILIDAD) -->
        <section class="sdm-tab-sec d-none" id="tab8">
            <div class="d-flex justify-content-between align-items-center mb-5">
                <div>
                    <h3 class="fw-black m-0" style="color: var(--md-blue-deep);">Nodo HL7-FHIR R4</h3>
                    <p class="text-muted small fw-bold">EST&Aacute;NDAR INTERNACIONAL DE SALUD</p>
                </div>
                <button class="btn btn-medentia rounded-pill px-4 shadow-sm" onclick="exportFHIR()">
                    <i class="bi bi-filetype-json me-2" style="color: var(--md-cyan-ia);"></i>Exportar Recurso JSON
                </button>
            </div>

            <div class="row g-4">
                <div class="col-lg-6">
                    <div class="card-medentia-aura p-4 border-0 h-100">
                        <h6 class="fw-black mb-3" style="color: var(--md-teal-clinical);">Recurso: Patient</h6>
                        <pre class="bg-light p-3 rounded-4 small" style="color: #0369a1; font-family: 'Courier New';">
{
  "resourceType": "Patient",
  "id": "$paciente->{id_paciente}",
  "active": true,
  "name": [{ "text": "$paciente->{nombre}" }],
  "gender": "@{[lc $paciente->{sexo}]}",
  "birthDate": "$paciente->{f_nac}",
  "telecom": [{ "system": "phone", "value": "$paciente->{tel}" }]
}</pre>
                    </div>
                </div>
                <div class="col-lg-6">
                    <div class="card-medentia-aura p-4 border-0 h-100">
                        <h6 class="fw-black mb-3" style="color: var(--md-teal-clinical);">Endpoints Activos</h6>
                        <div class="list-group list-group-flush small">
                            <div class="list-group-item d-flex justify-content-between align-items-center px-0">
                                <span>SMART on FHIR API</span>
                                <span class="badge bg-success-subtle text-success">ONLINE</span>
                            </div>
                            <div class="list-group-item d-flex justify-content-between align-items-center px-0">
                                <span>HL7 V2 Gateway</span>
                                <span class="badge bg-success-subtle text-success">ONLINE</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- 9: HL7 GATEWAY -->
        <section class="sdm-tab-sec d-none" id="tab9">
            <h3 class="fw-black mb-5" style="color: var(--md-blue-deep);">Monitor de Mensajería HL7 v2.5</h3>
            <div class="card-medentia-aura p-4 border-0" style="background: var(--md-blue-deep); color: white; font-family: 'Courier New'; font-size: 0.85rem; line-height: 1.6;">
                <div class="mb-3">
                    <span class="text-success fw-bold">[SENT]</span> MSH|^~\\&|SDM|CENTRO_DENTAL|LAB|HOSPITAL|202604261945||ADT^A01|101|P|2.5
                </div>
                <div class="mb-3">
                    <span class="text-success fw-bold">[SENT]</span> PID|1||$paciente->{id_paciente}||$paciente->{nombre}||19850520|M|||AV REFORMA 100^^CDMX
                </div>
                <div class="mb-3 text-info">
                    <span class="fw-bold">[ACK]</span> MSA|AA|101|Message received successfully
                </div>
            </div>
            <div class="mt-4 p-4 card-medentia-aura border-0">
                <h6 class="fw-bold"><i class="bi bi-broadcast me-2" style="color: var(--md-teal-clinical);"></i>Conectividad Activa</h6>
                <p class="small text-muted mb-0">El sistema est&aacute; escuchando peticiones en el puerto 5001 para la recepci&oacute;n de resultados de laboratorio e im&aacute;genes DICOM.</p>
            </div>
        </section>

        <!-- 5: MENSAJES (COMUNICACIONES) -->
        <section class="sdm-tab-sec d-none" id="tab5">
            <h3 class="fw-black mb-5" style="color: var(--md-blue-deep);">Comunicaciones Enviadas</h3>
            <div class="row g-3">
HTML
    if (@$correos_ref) {
        foreach my $corr (@$correos_ref) {
            # Capturar todos los detalles
            my $id_msg = $corr->{id_correo};
            my $cat    = $corr->{categoria} || 'General';
            my $adj    = $corr->{adjunto}   || 'Ninguno';
            my $asunto_esc = $corr->{asunto}; $asunto_esc =~ s/'/\\'/g;
            my $cuerpo_esc = $corr->{cuerpo}; $cuerpo_esc =~ s/'/\\'/g;
            $cuerpo_esc =~ s/\r?\n/\\n/g;

            print qq{
                <div class="col-12">
                    <div class="card-medentia-aura p-4 border-0 d-flex gap-4 align-items-center transition-all" 
                         onclick="verDetalleMensaje('$id_msg', '$asunto_esc', '$corr->{fecha}', '$cuerpo_esc', '$cat', '$adj')"
                         style="cursor: pointer;">
                        <div class="p-3 rounded-4" style="background: rgba(25, 183, 165, 0.1); color: var(--md-teal-clinical);">
                            <i class="bi bi-envelope-check fs-3"></i>
                        </div>
                        <div class="flex-grow-1 overflow-hidden">
                            <div class="d-flex align-items-center justify-content-between gap-2 mb-1">
                                <h6 class="fw-bold m-0 text-truncate">$corr->{asunto}</h6>
                                <span class="badge bg-light text-muted small fw-bold">$corr->{fecha}</span>
                            </div>
                            <div class="d-flex align-items-center gap-2">
                                <span class="badge bg-primary-subtle text-primary border-0 rounded-pill px-2 py-1" style="font-size:0.6rem;">$cat</span>
                                <p class="small text-muted mb-0 text-truncate">$corr->{cuerpo}</p>
                            </div>
                        </div>
                        <div class="text-muted opacity-25">
                            <i class="bi bi-chevron-right fs-4"></i>
                        </div>
                    </div>
                </div>
            };
        }
    } else {
        print qq{<div class="text-center py-5 opacity-25"><i class="bi bi-chat-left-dots display-1 d-block mb-3"></i><p class="fw-bold">No hay mensajes registrados en la bit&aacute;cora.</p></div>};
    }
    print <<HTML;
            </div>
        </section>
HTML
    utils::sub_sidebar::render_sidebar_footer();

print <<HTML;
<script src="https://cdn.jsdelivr.net/npm/sweetalert2\@11"></script>
<script src="../js/estado_cuenta_spa.js?v=$^T"></script>
<script src="../js/odontograma.js?v=$^T"></script>
<script src="../js/odontograma_spa.js?v=$^T"></script>
<script>
    document.addEventListener('DOMContentLoaded', () => { 
        initModuloFinanciero('$d->{id_paciente}', 'bento', '$id_medico_actual');
    });
    
    function abrirModalCarrito() { 
        windowActiveOS = null; // Reiniciar contexto de OS
        const modalEl = document.getElementById('modalCargo');
        if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        carritoApp = []; 
        refrescarGUICarrito(); 
        m.show(); 
    }
    
    function abrirModalCargoConOS(id_os) {
        windowActiveOS = id_os;
        const modalEl = document.getElementById('modalCargo');
        if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
        carritoApp = [];
        refrescarGUICarrito();
        bootstrap.Modal.getOrCreateInstance(modalEl).show();
    }
    
    function abrirModalAbono() { 
        const modalEl = document.getElementById('modalAbono');
        if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        document.getElementById('montoAbono').value = ''; 
        m.show(); 
    }

    function verDetalleMensaje(id, asunto, fecha, cuerpo, cat, adjunto) {
        console.log("DEBUG: verDetalleMensaje triggered", {id, asunto, fecha, cuerpo, cat, adjunto});
        
        const modalEl = document.getElementById('modalMensaje');
        if (modalEl && modalEl.parentElement !== document.body) {
            console.log("DEBUG: Teleporting modalMensaje to body...");
            document.body.appendChild(modalEl);
        }

        document.getElementById('msgDetailID').innerText = id;
        document.getElementById('msgDetailAsunto').innerText = asunto;
        document.getElementById('msgDetailFecha').innerText = fecha;
        document.getElementById('msgDetailCuerpo').innerText = cuerpo;
        document.getElementById('msgDetailCat').innerText = cat;
        
        const adjContainer = document.getElementById('msgDetailAdjunto');
        const adjSpan = adjContainer.querySelector('span');
        adjSpan.innerText = adjunto;
        
        if(adjunto !== 'Sin adjuntos' && adjunto !== 'Ninguno') {
            adjContainer.style.cursor = 'pointer';
            adjContainer.onclick = () => abrirAdjunto(adjunto);
            adjSpan.classList.add('text-primary');
        } else {
            adjContainer.style.cursor = 'default';
            adjContainer.onclick = null;
            adjSpan.classList.remove('text-primary');
        }
        
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        
        modalEl.addEventListener('shown.bs.modal', function () {
            console.log("DEBUG: Modal shown. Checking Z-Index...");
            const backdrop = document.querySelector('.modal-backdrop');
            console.log("Modal Z-Index:", window.getComputedStyle(modalEl).zIndex);
            if(backdrop) console.log("Backdrop Z-Index:", window.getComputedStyle(backdrop).zIndex);
            
            // Comprobar ancestros para Stacking Context
            let parent = modalEl.parentElement;
            while (parent && parent !== document.body) {
                const s = window.getComputedStyle(parent);
                if (s.transform !== 'none' || s.opacity < 1 || s.filter !== 'none') {
                    console.warn("DEBUG WARNING: Parent has Stacking Context property!", parent, {
                        transform: s.transform,
                        opacity: s.opacity,
                        filter: s.filter
                    });
                }
                parent = parent.parentElement;
            }
        }, { once: true });

        m.show();
    }

    function abrirAdjunto(file) {
        console.log("DEBUG: abrirAdjunto", file);
        const modalEl = document.getElementById('modalPreview');
        if (modalEl && modalEl.parentElement !== document.body) {
            console.log("DEBUG: Teleporting modalPreview to body...");
            document.body.appendChild(modalEl);
        }

        const url = '../dat/adjuntos_crm/$d->{id_paciente}/' + file;
        const previewBody = document.getElementById('previewBody');
        previewBody.innerHTML = '';
        
        const ext = file.split('.').pop().toLowerCase();
        if(['jpg','jpeg','png','webp','gif'].includes(ext)) {
            previewBody.innerHTML = '<div class="preview-container"><img src="' + url + '" class="animate__animated animate__zoomIn"></div>';
        } else if(ext === 'pdf') {
            previewBody.innerHTML = '<div class="preview-container"><iframe src="' + url + '"></iframe></div>';
        } else {
            console.log("DEBUG: Non-previewable file, opening in new tab", url);
            window.open(url, '_blank');
            return;
        }
        
        document.getElementById('previewTitle').innerText = file;
        const m = bootstrap.Modal.getOrCreateInstance(modalEl);
        m.show();
    }

    function verXRay(url, titulo) {
        Swal.fire({
            title: titulo,
            imageAlt: 'Radiografía del Paciente',
            imageUrl: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&q=80&w=800',
            imageWidth: 800,
            background: '#000',
            color: '#fff',
            confirmButtonText: 'Cerrar Visor',
            confirmButtonColor: 'var(--sdm-blue)'
        });
    }

    function exportFHIR() {
        Swal.fire({
            title: 'Exportando Recurso FHIR',
            html: 'Generando bundle de interoperabilidad...',
            timer: 1500,
            didOpen: () => { Swal.showLoading(); }
        }).then(() => {
            Swal.fire('Éxito', 'Recurso Patient/$d->{id_paciente} exportado correctamente a JSON R4', 'success');
        });
    }
    
    async function guardarFichaMaster() {
        const form = document.getElementById('formFichaCRUD');
        const formData = new FormData(form);
        
        // Mapeo dinámico al estándar de pacientes_crud_api.pl
        const payload = {
            accion: 'actualizar',
            id: formData.get('id_paciente'),
            nombre: formData.get('nombre'),
            rfc: formData.get('rfc'),
            curp: formData.get('curp'),
            correo: formData.get('email'),
            fecha_nac: formData.get('f_nac'),
            genero: formData.get('sexo'),
            ocupacion: formData.get('ocupacion'),
            estado_civil: formData.get('e_civil'),
            nacionalidad: formData.get('nacionalidad'),
            tipo_sangre: formData.get('sangre'),
            telefono: formData.get('telefono')
        };

        Swal.fire({ 
            title: 'Sincronizando con Nodo Central', 
            html: 'Validando integridad del expediente...',
            allowOutsideClick: false,
            didOpen: () => { Swal.showLoading(); } 
        });
        
        try {
            const res = await fetch('../api/pacientes_crud_api.pl', { 
                method: 'POST', 
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload) 
            });
            const data = await res.json();
            
            if (data.ok) { 
                Swal.fire({
                    icon: 'success',
                    title: '¡Sincronizaci&oacute;n Exitosa!',
                    text: data.msg,
                    confirmButtonColor: 'var(--sdm-blue)'
                }); 
            } else {
                Swal.fire("Inconsistencia", data.msg || "Error en el servidor central", "warning");
            }
        } catch(e) { 
            Swal.fire("Error Cr&iacute;tico", "No se pudo establecer conexi&oacute;n con el Nodo de Datos.", "error"); 
        }
    }

    function verDetalleConsulta(id_consulta, fecha, medico) {
        const rawJson = document.getElementById('data_cons_' + id_consulta).value;
        let data = {};
        try { data = JSON.parse(rawJson); } catch(e) { console.error("JSON Error", e); }
        
        document.getElementById('detConsID').innerText = id_consulta;
        document.getElementById('detConsFecha').innerText = fecha;
        document.getElementById('detConsMed').innerText = medico;
        
        document.getElementById('detConsMotivo').innerText = data.motivo || 'N/A';
        document.getElementById('detConsPeso').innerText = data.peso ? data.peso + ' kg' : '--';
        document.getElementById('detConsFC').innerText = data.fc ? data.fc + ' bpm' : '--';
        document.getElementById('detConsTA').innerText = data.ta || '--';
        document.getElementById('detConsTemp').innerText = data.temperatura ? data.temperatura + ' °C' : '--';
        
        document.getElementById('detConsExploracion').innerText = data.exploracion || 'Sin registro';
        document.getElementById('detConsDiagnostico').innerText = data.diagnostico || 'Sin registro';
        document.getElementById('detConsTratamiento').innerText = data.tratamiento || 'Sin registro';
        
        const tbReceta = document.getElementById('detConsReceta');
        tbReceta.innerHTML = '';
        if (data.medicamentos && data.medicamentos.length > 0) {
            data.medicamentos.forEach(m => {
                tbReceta.innerHTML += "<tr>" +
                    "<td>" + (m.nombre || '') + "</td>" +
                    "<td>" + (m.cantidad || '') + "</td>" +
                    "<td>" + (m.indicaciones || '') + "</td>" +
                "</tr>";
            });
            document.getElementById('detConsRecetaCont').classList.remove('d-none');
        } else {
            document.getElementById('detConsRecetaCont').classList.add('d-none');
        }
        
        // Link para impresión
        document.getElementById('btnImprimirNota').onclick = function() {
            window.open('imprime_nota_medica.pl?id_consulta=' + id_consulta, '_blank');
        };
        
        const modalEl = document.getElementById('modalDetalleConsulta');
        if (modalEl && modalEl.parentElement !== document.body) document.body.appendChild(modalEl);
        bootstrap.Modal.getOrCreateInstance(modalEl).show();
    }
</script>

<!-- MODALES PREMIUM CRYSTAL (FUERA DE CONTENEDORES PARA EVITAR PROBLEMAS DE CAPAS) -->
<div class="modal fade" id="modalCargo" tabindex="-1">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl overflow-hidden" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header bg-dark text-white p-4 px-5 border-0">
                <h3 class="fw-black m-0 plus-jakarta"><i class="bi bi-cart-plus me-3 text-info"></i>Cat&aacute;logo de Servicios</h3>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-5">
                <div class="row g-4">
                    <div class="col-lg-7">
                        <div class="input-group input-group-lg mb-4">
                            <span class="input-group-text bg-white border-end-0 rounded-start-4"><i class="bi bi-search"></i></span>
                            <input id="buscadorCatalogo" class="form-control border-start-0 rounded-end-4 shadow-sm" placeholder="Buscar tratamiento..." onkeyup="filtrarCatalogo()">
                        </div>
                        <div id="divCatalogo" class="row g-2 overflow-auto" style="max-height: 450px; padding-right: 10px;"></div>
                    </div>
                    <div class="col-lg-5">
                        <div class="bg-light rounded-5 p-4 shadow-inner d-flex flex-column h-100">
                             <h5 class="fw-black mb-3 text-primary uppercase small tracking-widest">Resumen de Cargo</h5>
                             <div id="listaCarrito" class="flex-grow-1 overflow-auto mb-4" style="max-height: 350px;"></div>
                             <div class="pt-3 border-top">
                                <div class="form-check form-switch mb-3">
                                    <input class="form-check-input" type="checkbox" id="checkFactura" onchange="refrescarGUICarrito()">
                                    <label class="form-check-label small fw-bold text-muted" for="checkFactura">Aplica IVA (Factura)</label>
                                </div>
                                <div class="d-flex justify-content-between align-items-center mb-4">
                                    <span class="fw-bold text-muted">TOTAL A CARGAR</span>
                                    <span class="h2 fw-black text-dark m-0" id="carritoTotal">\$0.00</span>
                                </div>
                                <button id="btnProcesarCargo" class="btn btn-primary w-100 py-3 fw-bold rounded-4 shadow-lg" onclick="procesarCarrito()">CONFIRMAR CARGO</button>
                             </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalAbono" tabindex="-1">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <h3 class="fw-black plus-jakarta" id="modalAbonoTitle">Registrar Pago</h3>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4 pt-0 text-center">
                <div class="p-4 bg-success-subtle rounded-4 mb-4 mt-3">
                    <span class="kpi-label text-success">Monto a Recibir</span>
                    <input id="montoAbono" class="bg-transparent border-0 w-100 text-center fw-black display-4 text-success" placeholder="\$0.00">
                </div>
                <div class="mb-4 text-start">
                    <label class="kpi-label">M&eacute;todo de Pago</label>
                    <select id="metodoAbono" class="form-select py-3 rounded-4 border-0 bg-light fw-bold">
                        <option>Efectivo</option>
                        <option>Tarjeta</option>
                        <option>Transferencia</option>
                    </select>
                </div>
                <input type="hidden" id="notasAbono" value="">
                <button class="btn btn-success btn-lg w-100 py-3 rounded-4 fw-black shadow-lg" onclick="procesarAbono()">CONFIRMAR ABONO</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalDetalleConsulta" tabindex="-1">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-primary text-white p-2 rounded-3 shadow-sm"><i class="bi bi-file-earmark-medical-fill fs-5"></i></div>
                    <h4 class="fw-black m-0 plus-jakarta">Expediente Cl&iacute;nico</h4>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4">
                <div class="bg-light rounded-4 p-3 mb-4 d-flex justify-content-between align-items-center border">
                    <div>
                        <span class="badge bg-secondary-subtle text-secondary mb-1" id="detConsID"></span>
                        <div class="small fw-bold text-dark"><i class="bi bi-calendar-event me-1 text-primary"></i> <span id="detConsFecha"></span></div>
                    </div>
                    <div class="text-end">
                        <div class="small text-muted fw-bold">M&eacute;dico Tratante</div>
                        <div class="fw-black text-dark" id="detConsMed"></div>
                    </div>
                </div>

                <div class="row g-4 mb-4">
                    <div class="col-md-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Motivo de Consulta</label>
                        <div class="p-3 bg-white border rounded-4 shadow-sm" id="detConsMotivo" style="min-height: 60px;"></div>
                    </div>
                    <div class="col-md-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Signos Vitales</label>
                        <div class="d-flex gap-2 flex-wrap">
                            <span class="badge bg-light text-dark border p-2"><i class="bi bi-person-standing text-primary me-1"></i> <span id="detConsPeso"></span></span>
                            <span class="badge bg-light text-dark border p-2"><i class="bi bi-heart-pulse text-danger me-1"></i> <span id="detConsFC"></span></span>
                            <span class="badge bg-light text-dark border p-2"><i class="bi bi-activity text-warning me-1"></i> <span id="detConsTA"></span></span>
                            <span class="badge bg-light text-dark border p-2"><i class="bi bi-thermometer text-info me-1"></i> <span id="detConsTemp"></span></span>
                        </div>
                    </div>
                </div>

                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Exploraci&oacute;n F&iacute;sica</label>
                    <div class="p-3 bg-light border rounded-4 text-dark" id="detConsExploracion"></div>
                </div>

                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Diagn&oacute;stico</label>
                    <div class="p-3 bg-danger-subtle border border-danger-subtle rounded-4 text-danger-emphasis fw-bold" id="detConsDiagnostico"></div>
                </div>

                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Plan / Tratamiento</label>
                    <div class="p-3 bg-success-subtle border border-success-subtle rounded-4 text-success-emphasis" id="detConsTratamiento"></div>
                </div>

                <div id="detConsRecetaCont" class="mb-2 d-none">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-2 d-block"><i class="bi bi-prescription2 text-primary me-1"></i> Receta Emitida</label>
                    <div class="table-responsive bg-white rounded-4 border shadow-sm">
                        <table class="table table-sm table-hover mb-0">
                            <thead class="bg-light"><tr><th class="ps-3">F&aacute;rmaco</th><th>Cant.</th><th>Indicaciones</th></tr></thead>
                            <tbody id="detConsReceta" class="small"></tbody>
                        </table>
                    </div>
                </div>
            </div>
            <div class="modal-footer border-0 p-4 pt-0 d-flex justify-content-between">
                <div class="small text-muted fw-bold"><i class="bi bi-shield-lock-fill text-success me-1"></i> Registro Hist&oacute;rico (Solo Lectura)</div>
                <div class="d-flex gap-2">
                    <button type="button" class="btn btn-light rounded-pill px-4 fw-bold" data-bs-dismiss="modal">Cerrar</button>
                    <button type="button" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm" id="btnImprimirNota"><i class="bi bi-printer-fill me-2"></i>Imprimir Nota</button>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalMensaje" tabindex="-1">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-primary-subtle text-primary p-2 rounded-3"><i class="bi bi-envelope-open-fill"></i></div>
                    <h4 class="fw-black m-0 plus-jakarta">Detalle del Mensaje</h4>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4 pt-4">
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Asunto del Mensaje</label>
                    <h5 id="msgDetailAsunto" class="fw-bold text-dark"></h5>
                </div>
                <div class="row g-3 mb-4">
                    <div class="col-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">ID Registro</label>
                        <div id="msgDetailID" class="fw-bold text-dark small"></div>
                    </div>
                    <div class="col-6">
                        <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Categor&iacute;a</label>
                        <span id="msgDetailCat" class="badge bg-primary-subtle text-primary border-0 rounded-pill px-3 py-1"></span>
                    </div>
                </div>
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Fecha de Env&iacute;o</label>
                    <div id="msgDetailFecha" class="small fw-bold text-primary"></div>
                </div>
                <div class="mb-4">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-1 d-block">Archivo Adjunto</label>
                    <div id="msgDetailAdjunto" class="small fw-bold text-dark"><i class="bi bi-paperclip me-1"></i> <span></span></div>
                </div>
                <hr class="my-4 opacity-10">
                <div class="bg-light p-4 rounded-4 border">
                    <label class="small fw-bold text-muted uppercase tracking-widest mb-2 d-block">Contenido / Cuerpo</label>
                    <p id="msgDetailCuerpo" class="m-0 text-dark" style="white-space: pre-wrap; line-height: 1.6;"></p>
                </div>
            </div>
            <div class="modal-footer border-0 p-4 pt-0">
                <button class="btn btn-navy w-100 py-3 rounded-4 fw-bold text-white shadow-lg" style="background: var(--sdm-navy);" data-bs-dismiss="modal">CERRAR LECTURA</button>
            </div>
        </div>
    </div>
</div>

<div class="modal fade" id="modalPreview" tabindex="-1">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content rounded-5 border-0 shadow-2xl p-2" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(20px);">
            <div class="modal-header border-0 p-4 pb-0">
                <div class="d-flex align-items-center gap-3">
                    <div class="bg-dark text-white p-2 rounded-3"><i class="bi bi-eye-fill"></i></div>
                    <h4 class="fw-black m-0 plus-jakarta" id="previewTitle">Vista Previa</h4>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4" id="previewBody">
            </div>
        </div>
    </div>
</div>

<!-- MODAL 1: DETALLE CLÍNICO ANATÓMICO (ACTIVADO POR EL OJO 👁️) -->
<div class="modal fade" id="modalDetalleOdonto" tabindex="-1" aria-labelledby="modalDetalleOdontoLabel" aria-hidden="true" style="z-index: 7500 !important;">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content rounded-4 border-0 shadow-lg" style="background: rgba(255,255,255,0.98); backdrop-filter: blur(15px);">
            <div class="modal-header border-0 pb-0 pt-4 px-4 d-flex justify-content-between align-items-center">
                <div class="d-flex align-items-center gap-3">
                    <div class="p-3 rounded-circle text-white shadow-sm" style="background: linear-gradient(135deg, var(--md-teal-clinical, #19B7A5), #0d9488);">
                        <i class="bi bi-eye-fill fs-4"></i>
                    </div>
                    <div>
                        <div class="d-flex align-items-center gap-2 mb-1">
                            <span class="badge bg-teal text-white rounded-pill px-3 py-1 fw-bold" style="background-color: var(--md-teal-clinical, #19B7A5) !important;">FDI / ISO 3950</span>
                            <span class="badge bg-light text-muted border px-2 py-1" id="detalleOdontoFecha"></span>
                            <span id="detalleOdontoEstado"></span>
                        </div>
                        <h4 class="fw-black text-dark m-0" id="detalleOdontoAlias">Detalle del Odontograma</h4>
                        <p class="text-muted small fw-bold mb-0">HALLAZGOS CL&Iacute;NICOS Y TRATAMIENTOS ASIGNADOS POR PIEZA DENTAL</p>
                    </div>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-4">
                <!-- Metadatos superiores del modal -->
                <div class="row g-3 mb-3">
                    <div class="col-md-6">
                        <div class="card bg-light border-0 p-3 rounded-3 d-flex flex-row align-items-center justify-content-between">
                            <div>
                                <span class="small fw-bold text-muted text-uppercase d-block">Piezas Afectadas</span>
                                <h5 class="fw-black text-dark m-0" id="detalleOdontoPiezas">0 Piezas</h5>
                            </div>
                            <i class="bi bi-diagram-3-fill fs-3 text-teal" style="color: var(--md-teal-clinical, #19B7A5);"></i>
                        </div>
                    </div>
                    <div class="col-md-6">
                        <div class="card bg-light border-0 p-3 rounded-3 d-flex flex-row align-items-center justify-content-between">
                            <div>
                                <span class="small fw-bold text-muted text-uppercase d-block">Presupuesto Estimado</span>
                                <h5 class="fw-black text-danger m-0" id="detalleOdontoImporte">$0.00 MXN</h5>
                            </div>
                            <i class="bi bi-wallet2 fs-3 text-danger"></i>
                        </div>
                    </div>
                </div>

                <div id="detalleOdontoNotas"></div>

                <!-- Tabla de Hallazgos Anatómicos (6 Columnas) -->
                <div class="table-responsive">
                    <table class="table table-hover align-middle mb-0" id="tablaDetalleHallazgos" style="width:100%">
                        <thead class="table-light">
                            <tr>
                                <th class="ps-3 border-0 rounded-start-3" style="width: 100px;">Pieza FDI</th>
                                <th class="border-0">Diente y Familia Anat&oacute;mica</th>
                                <th class="border-0" style="width: 140px;">Cara / Zona</th>
                                <th class="border-0">Diagn&oacute;stico / Condici&oacute;n</th>
                                <th class="border-0 text-center" style="width: 130px;">Estado Cl&iacute;nico</th>
                                <th class="border-0 text-end pe-3 rounded-end-3" style="width: 150px;">Importe Sugerido</th>
                            </tr>
                        </thead>
                        <tbody class="small">
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="modal-footer border-0 p-4 pt-0 d-flex justify-content-between">
                <a id="btnVisorDesdeModal" href="#" target="_blank" class="btn btn-medentia rounded-pill px-4 fw-bold shadow-sm d-flex align-items-center gap-2">
                    <i class="bi bi-display" style="color: var(--md-cyan-ia);"></i>
                    <span>Abrir en OSOdontograma Viewer Pro</span>
                </a>
                <button type="button" class="btn btn-light rounded-pill px-4 fw-bold border" data-bs-dismiss="modal">Cerrar</button>
            </div>
        </div>
    </div>
</div>

<!-- MODAL 2: CREAR NUEVO ODONTOGRAMA -->
<div class="modal fade" id="modalNuevoOdonto" tabindex="-1" aria-labelledby="modalNuevoOdontoLabel" aria-hidden="true" style="z-index: 7500 !important;">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content rounded-4 border-0 shadow-lg">
            <div class="modal-header border-0 pb-0 pt-4 px-4">
                <div class="d-flex align-items-center gap-2">
                    <div class="p-2 rounded-circle bg-primary-subtle text-primary">
                        <i class="bi bi-plus-circle-fill fs-5"></i>
                    </div>
                    <h5 class="fw-bold m-0 text-dark">Nuevo Odontograma</h5>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-4">
                <form id="formNuevoOdonto" onsubmit="event.preventDefault(); guardarNuevoOdonto();">
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted text-uppercase">Nombre / Alias del Odontograma <span class="text-danger">*</span></label>
                        <input type="text" id="nuevo_alias" class="form-control rounded-3" placeholder="Ej. Diagnóstico Inicial 2026, Plan Ortodoncia" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted text-uppercase">Estado del Estudio</label>
                        <select id="nuevo_estado" class="form-select rounded-3">
                            <option value="En Proceso" selected>En Proceso / Activo</option>
                            <option value="Planificado">Planificado / Presupuesto</option>
                            <option value="Finalizado">Finalizado / Completado</option>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted text-uppercase">Observaciones Cl&iacute;nicas Iniciales</label>
                        <textarea id="nuevo_notas" class="form-control rounded-3" rows="3" placeholder="Notas, motivos de consulta dental o especificaciones..."></textarea>
                    </div>
                    <div class="d-flex justify-content-end gap-2 mt-4">
                        <button type="button" class="btn btn-light rounded-pill px-4 fw-bold border" data-bs-dismiss="modal">Cancelar</button>
                        <button type="submit" class="btn btn-medentia rounded-pill px-4 fw-bold shadow-sm">
                            <i class="bi bi-arrow-right-circle me-1"></i>Crear y Abrir Visor
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>

<!-- MODAL 3: RENOMBRAR / EDITAR METADATOS -->
<div class="modal fade" id="modalRenombrarOdonto" tabindex="-1" aria-labelledby="modalRenombrarOdontoLabel" aria-hidden="true" style="z-index: 7500 !important;">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content rounded-4 border-0 shadow-lg">
            <div class="modal-header border-0 pb-0 pt-4 px-4">
                <div class="d-flex align-items-center gap-2">
                    <div class="p-2 rounded-circle bg-secondary-subtle text-secondary">
                        <i class="bi bi-tag-fill fs-5"></i>
                    </div>
                    <h5 class="fw-bold m-0 text-dark">Editar Metadatos del Odontograma</h5>
                </div>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-4">
                <form id="formRenombrarOdonto" onsubmit="event.preventDefault(); guardarRenombrarOdonto();">
                    <input type="hidden" id="edit_id_odonto">
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted text-uppercase">Nombre / Alias <span class="text-danger">*</span></label>
                        <input type="text" id="edit_alias" class="form-control rounded-3" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted text-uppercase">Estado del Estudio</label>
                        <select id="edit_estado" class="form-select rounded-3">
                            <option value="En Proceso">En Proceso / Activo</option>
                            <option value="Planificado">Planificado / Presupuesto</option>
                            <option value="Finalizado">Finalizado / Completado</option>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="form-label small fw-bold text-muted text-uppercase">Observaciones Cl&iacute;nicas</label>
                        <textarea id="edit_notas" class="form-control rounded-3" rows="3"></textarea>
                    </div>
                    <div class="d-flex justify-content-end gap-2 mt-4">
                        <button type="button" class="btn btn-light rounded-pill px-4 fw-bold border" data-bs-dismiss="modal">Cancelar</button>
                        <button type="submit" class="btn btn-primary rounded-pill px-4 fw-bold shadow-sm">
                            <i class="bi bi-check2-circle me-1"></i>Guardar Cambios
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>
    </div>
HTML
    utils::sub_sidebar::render_sidebar_footer();
}

sub calcular_edad {
    my ($fecha_nac) = @_;
    return 'N/A' unless $fecha_nac && $fecha_nac =~ /^(\d{4})-(\d{2})-(\d{2})$/;
    my ($ano, $mes, $dia) = ($1, $2, $3);
    my (undef, undef, undef, $mday, $mon, $year) = localtime();
    $year += 1900;
    $mon += 1;
    my $edad = $year - $ano;
    if ($mon < $mes || ($mon == $mes && $mday < $dia)) {
        $edad--;
    }
    return $edad >= 0 ? $edad : 0;
}

sub cargar_datos_paciente {
    my ($id) = @_; my $res = leer_tabla(File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat'), '\|');
    foreach my $c (@$res) { if ($c->[0] eq $id) { 
        my $n = $c->[2]//'';
        my $pac_data = { 
            id_paciente  => $c->[0], 
            id_medico    => $c->[1], 
            nombre       => $n, 
            iniciales    => uc(substr($n,0,1)||'P'), 
            rfc          => $c->[3], 
            curp         => $c->[4], 
            email        => $c->[5], 
            f_nac        => $c->[6], 
            sexo         => $c->[7], 
            ocupacion    => $c->[8], 
            e_civil      => $c->[9], 
            nacionalidad => $c->[10],
            tipo_sangre  => $c->[11], 
            tel          => $c->[12],
            tenant       => $c->[13] // '',
            tutor        => '',
            antecedentes => {}
        }; 

        my $ant_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes_antecedentes.dat');
        if (-e $ant_file && open(my $fha, '<:encoding(UTF-8)', $ant_file)) {
            while (my $aline = <$fha>) {
                chomp $aline;
                next if $aline =~ /^\s*$/;
                my @av = split /\|/, $aline, -1;
                if (@av >= 3 && $av[0] eq $id) {
                    $pac_data->{tutor} = $av[1] || '';
                        eval {
                            $pac_data->{antecedentes} = JSON::PP->new->decode($av[2]);
                        } || eval {
                            $pac_data->{antecedentes} = JSON::PP->new->utf8(1)->decode($av[2]);
                        };
                    last;
                }
            }
            close $fha;
        }

        my $dom_file = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes_domicilio.dat');
        $pac_data->{domicilio} = {
            cp => '', entidad => '', municipio => '', colonia => '', calle => '', num_ext => '', num_int => ''
        };
        if (-e $dom_file && open(my $fhd, '<:encoding(UTF-8)', $dom_file)) {
            while (my $dline = <$fhd>) {
                chomp $dline;
                next if $dline =~ /^\s*$/ || $dline =~ /^ID_PACIENTE/i;
                my @dv = split /\|/, $dline, -1;
                if (@dv >= 8 && $dv[0] eq $id) {
                    $pac_data->{domicilio} = {
                        cp        => $dv[1] // '',
                        entidad   => $dv[2] // '',
                        municipio => $dv[3] // '',
                        colonia   => $dv[4] // '',
                        calle     => $dv[5] // '',
                        num_ext   => $dv[6] // '',
                        num_int   => $dv[7] // ''
                    };
                    last;
                }
            }
            close $fhd;
        }

        return $pac_data;
    } }
    return undef;
}

sub cargar_citas_paciente {
    my ($id) = @_; my @h; my $res = leer_tabla(File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat'), '\|');
    foreach my $c (@$res) {
        if ($c->[2] eq $id) {
            my $estado = $c->[8] // 'Programada';
            my $notas  = $c->[7] // '';
            # Si el estado comienza con [Atencion: y hay una columna posterior con el estado real
            if ($estado =~ /^\[Atencion:/ && defined $c->[9] && $c->[9] ne '') {
                $notas .= " - $estado";
                $estado = $c->[9];
            }
            push @h, { id_cita=>$c->[0], id_medico=>$c->[1]||'N/A', fecha=>$c->[3], hora=>$c->[4], motivo=>$c->[6], notas=>$notas, estado=>$estado };
        }
    }
    return sort { ($b->{fecha} cmp $a->{fecha}) || (($b->{hora} // '') cmp ($a->{hora} // '')) } @h;
}

sub cargar_historial_consultas {
    my ($id) = @_; my @h; 
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consultas_clinicas.dat');
    open(my $fh, "<:encoding(UTF-8)", $path) or return \@h;
    my $cabecera = <$fh>;

    # Mapeo de citas para asociar fecha y hora exactas
    my $citas_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'citas.dat');
    my %citas_map;
    if (-e $citas_path && open(my $fhc, "<:encoding(UTF-8)", $citas_path)) {
        <$fhc>;
        while(my $lc = <$fhc>) {
            chomp $lc;
            next if $lc =~ /^\s*$/;
            my @fc = split /\|/, $lc, -1;
            $citas_map{$fc[0]} = { fecha => ($fc[3] // ''), hora => ($fc[4] // '') };
        }
        close $fhc;
    }

    # Mapeo de recibos en folios_recibos_privados.dat para asociar folio directo de impresión
    my $recibos_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'folios_recibos_privados.dat');
    my %recibos_map;
    if (-e $recibos_path && open(my $fhr, "<:encoding(UTF-8)", $recibos_path)) {
        <$fhr>;
        while(my $lr = <$fhr>) {
            chomp $lr;
            next if $lr =~ /^\s*$/;
            my @fr = split /\|/, $lr, -1;
            my $r_id    = $fr[0] // '';
            my $r_folio = $fr[1] // '';
            my $r_cons  = $fr[4] // '';
            my $r_pac   = $fr[5] // '';
            my $r_fec   = $fr[6] // '';
            
            my $r_info = {
                id_recibo => $r_id,
                folio     => $r_folio || $r_id,
                total     => $fr[8] || 0
            };
            if ($r_cons ne '') {
                $recibos_map{$r_cons} = $r_info;
            }
            if ($r_id ne '') {
                $recibos_map{$r_id} //= $r_info;
            }
            if ($r_folio ne '') {
                $recibos_map{$r_folio} //= $r_info;
            }
            if ($r_pac ne '' && $r_fec ne '') {
                $recibos_map{"PAC_${r_pac}_${r_fec}"} //= $r_info;
            }
        }
        close $fhr;
    }

    # Mapeo de recetas en recetas.dat
    my $recetas_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'recetas.dat');
    my %recetas_map;
    if (-e $recetas_path && open(my $fhref, "<:encoding(UTF-8)", $recetas_path)) {
        <$fhref>;
        while(my $lr = <$fhref>) {
            chomp $lr;
            next if $lr =~ /^\s*$/;
            my @fr = split /\|/, $lr, -1;
            my $c_id = $fr[1] // '';
            $recetas_map{$c_id} = 1 if $c_id ne '';
        }
        close $fhref;
    }

    # Mapeo de consentimientos en consentimientos.dat
    my $consent_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'consentimientos.dat');
    my %consent_map;
    if (-e $consent_path && open(my $fhcs, "<:encoding(UTF-8)", $consent_path)) {
        <$fhcs>;
        while(my $lc = <$fhcs>) {
            chomp $lc;
            next if $lc =~ /^\s*$/;
            my @fc = split /\|/, $lc, -1;
            my $c_id = $fc[1] // '';
            $consent_map{$c_id} = 1 if $c_id ne '';
        }
        close $fhcs;
    }

    while(<$fh>){ 
        chomp; 
        my @c = split /\|/, $_, -1; 
        if($c[1] eq $id){ 
            my $json_str = $c[5];
            $json_str =~ s/\\n/\n/g if defined $json_str;
            my $data = {};
            eval { $data = decode_json($json_str); };
            
            my ($f_orden, $h_orden);
            if ($c[2] && exists $citas_map{$c[2]} && $citas_map{$c[2]}->{fecha}) {
                $f_orden = $citas_map{$c[2]}->{fecha};
                $h_orden = $citas_map{$c[2]}->{hora} || '00:00';
            } else {
                my ($sec,$min,$hour,$mday,$mon,$year) = localtime($c[4] || time());
                $f_orden = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
                $h_orden = sprintf("%02d:%02d", $hour, $min);
            }
            my $fecha_str = "$f_orden $h_orden";
            
            # Resolver folio de recibo directo con coincidencia estricta
            my $folio_recibo = '';
            if (exists $recibos_map{$c[0]}) {
                $folio_recibo = $recibos_map{$c[0]}->{folio};
            } elsif ($c[2] && exists $recibos_map{$c[2]}) {
                $folio_recibo = $recibos_map{$c[2]}->{folio};
            }

            my $id_cons = $c[0];
            my $meds_count = 0;
            if ($data->{medicamentos} && ref($data->{medicamentos}) eq 'ARRAY') {
                $meds_count = scalar @{$data->{medicamentos}};
            }
            my $tiene_receta = (exists $recetas_map{$id_cons} || ($data->{requiere_receta} && $data->{requiere_receta} eq '1' && $meds_count > 0)) ? 1 : 0;
            my $tiene_consentimiento = (exists $consent_map{$id_cons} || ($data->{requiere_consentimiento} && $data->{requiere_consentimiento} eq '1')) ? 1 : 0;
            
            push @h, { 
                id_consulta          => $c[0], 
                id_cita              => $c[2],
                id_medico            => $c[3],
                timestamp            => $c[4] || 0,
                fecha_orden          => $f_orden,
                hora_orden           => $h_orden,
                fecha                => $fecha_str,
                folio_recibo         => $folio_recibo,
                tiene_receta         => $tiene_receta,
                tiene_consentimiento => $tiene_consentimiento,
                meds_count           => $meds_count,
                data                 => $data
            }; 
        } 
    }
    close $fh;
    my @sorted = sort { 
        ($b->{fecha_orden} cmp $a->{fecha_orden}) || 
        ($b->{hora_orden} cmp $a->{hora_orden}) || 
        ($b->{timestamp} <=> $a->{timestamp}) 
    } @h;
    return \@sorted;
}

sub cargar_historial_correos {
    my ($id) = @_; my @h; 
    my $path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'historial_correos.dat');
    open(my $fh, "<:encoding(UTF-8)", $path) or return @h;
    while(<$fh>){ 
        chomp; 
        my @c = split /\|/; 
        if($c[1] eq $id){ 
            push @h, { 
                id_correo => $c[0], 
                fecha     => $c[2], 
                asunto    => $c[3], 
                cuerpo    => $c[4] || 'Sin contenido',
                categoria => $c[4] || 'General',
                adjunto   => $c[5] || 'Sin adjuntos'
            }; 
        } 
    }
    close $fh; return @h;
}
my %cache_nombres_medicos;

sub limpiar_titulo_medico {
    my ($nombre) = @_;
    return '' unless defined $nombre;
    $nombre =~ s/^\s*(?:Dr\(a\)\.?|Dra?\.?|Doctor(?:a)?|Lic\.?|Licenciado(?:a)?|Mtro\.?|Mtra\.?|Ing\.?|MEDICO\.?)\s+//i;
    $nombre =~ s/\s+/ /g;
    $nombre =~ s/^\s+|\s+$//g;
    return $nombre;
}

sub obtener_nombre_medico {
    my ($id) = @_;
    $id = '' unless defined $id;
    $id =~ s/^\s+|\s+$//g;

    return 'Médico Tratante' if ($id eq '' || $id eq 'N/A' || $id eq '0');

    # Si ya se encuentra en caché, devolver inmediatamente
    return $cache_nombres_medicos{$id} if exists $cache_nombres_medicos{$id};

    # Si el valor ya contiene letras y no es un ID numérico ni un código DOC-xxx
    if ($id !~ /^\d+$/ && $id !~ /^DOC-\d+$/i && $id =~ /[a-zA-ZáéíóúÁÉÍÓÚñÑ]{3,}/) {
        my $limpio = limpiar_titulo_medico($id);
        $cache_nombres_medicos{$id} = $limpio;
        return $limpio;
    }

    # 1. Comparar con la sesión activa si coincide el id_medico o uid
    if (defined $session_data && ref($session_data) eq 'HASH' && $session_data->{usuario}) {
        if (($session_data->{id_medico} && $session_data->{id_medico} eq $id) ||
            ($session_data->{uid} && $session_data->{uid} eq $id)) {
            my $nom_ses = limpiar_titulo_medico($session_data->{usuario});
            $cache_nombres_medicos{$id} = $nom_ses;
            return $nom_ses;
        }
    }

    # 2. Buscar en dat/usuarios.dat
    my $usr_path = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'usuarios.dat');
    if (-e $usr_path) {
        my $res = leer_tabla($usr_path, '!');
        if ($res && ref($res) eq 'ARRAY') {
            foreach my $row (@$res) {
                my $uid = $row->[0] // '';
                $uid =~ s/^\s+|\s+$//g;
                my $doc_formatted = "DOC-" . sprintf("%03d", ($uid =~ /^\d+$/ ? $uid : 0));
                my $doc_direct    = "DOC-" . $uid;
                if ($uid eq $id || $doc_formatted eq $id || $doc_direct eq $id) {
                    my $nom = limpiar_titulo_medico($row->[1]);
                    if ($nom ne '') {
                        $cache_nombres_medicos{$id} = $nom;
                        return $nom;
                    }
                }
            }
        }
    }

    # 3. Buscar en catálogos CLUE o medicos_*.dat
    my $clues_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat', 'catalogos_CLUE');
    if (-d $clues_dir && opendir(my $dh, $clues_dir)) {
        my @subdirs = readdir($dh);
        closedir($dh);
        foreach my $sd (@subdirs) {
            next if $sd =~ /^\./;
            my $med_clue_file = File::Spec->catfile($clues_dir, $sd, "medicos_$sd.dat");
            if (-e $med_clue_file && open(my $fh, "<:encoding(UTF-8)", $med_clue_file)) {
                <$fh>; # cabecera
                while (my $line = <$fh>) {
                    chomp $line;
                    my @parts = split /\|/, $line;
                    my $mid = $parts[0] // '';
                    $mid =~ s/^\s+|\s+$//g;
                    if ($mid eq $id) {
                        close $fh;
                        my $nom = limpiar_titulo_medico($parts[2] // '');
                        if ($nom ne '') {
                            $cache_nombres_medicos{$id} = $nom;
                            return $nom;
                        }
                    }
                }
                close $fh;
            }
        }
    }

    # 4. Fallback a sesión activa si el usuario logueado es médico
    if (defined $session_data && ref($session_data) eq 'HASH' && $session_data->{role} && $session_data->{role} =~ /Medico/i && $session_data->{usuario}) {
        my $nom_ses = limpiar_titulo_medico($session_data->{usuario});
        $cache_nombres_medicos{$id} = $nom_ses;
        return $nom_ses;
    }

    # 5. Si es solo número que no se pudo resolver, nunca exponer el ID crudo
    if ($id =~ /^\d+$/) {
        my $fallback = 'Médico Tratante';
        $cache_nombres_medicos{$id} = $fallback;
        return $fallback;
    }

    my $final = limpiar_titulo_medico($id);
    $cache_nombres_medicos{$id} = $final;
    return $final;
}
1;

