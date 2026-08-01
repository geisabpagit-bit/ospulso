#!/usr/bin/perl
# --- Dashboard Principal Premium v3.5.3 (Dynamic Data Sync) ---
use strict;
use warnings;
use utf8;
use CGI;
use File::Spec;
use FindBin;
use Time::Local;
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');

# 1. Formateadores Globales
sub format_currency {
    my $val = shift || 0;
    my $formatted = reverse (split '', sprintf("%.2f", $val));
    $formatted =~ s/(\d{3})(?=\d)(?!\d*\.)/$1,/g;
    return '$' . scalar reverse $formatted;
}

sub format_compact_k {
    my $val = shift || 0;
    if ($val >= 1000) {
        return sprintf("\$ %.2fk", $val / 1000);
    }
    return format_currency($val);
}

sub render_dashboard_principal {
    my %args = @_;
    my $id_medico = $args{id_medico};
    my $role = $args{role} || 'Visitante';
    my $usuario = $args{usuario} || 'Usuario';
    my $id_empresa = $args{id_empresa} || 0;
    my $id_sucursal = $args{id_sucursal} || 0;
    my $uid = lc($args{uid} // '');
    
    if ($role eq 'Administrador Global') {
        utils::sub_sidebar::render_sidebar(
            usuario => $usuario,
            role => $role,
            id_medico => $id_medico,
            pagina_actual => 'dashboard'
        );
        print <<HTML;
        <!-- Dashboard Content para Administrador Global (Vacío) -->
        <div class="container-fluid px-4 pb-5">
            <!-- Pantalla sin contenido para Administrador Global -->
        </div>
HTML
        utils::sub_sidebar::render_sidebar_footer();
        return;
    }
    
        # Rutas de datos
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $citas_file = File::Spec->catfile($dat_dir, 'citas.dat');
    my $pac_file   = File::Spec->catfile($dat_dir, 'pacientes.dat');
    my $fin_file   = File::Spec->catfile($dat_dir, 'estado_cuenta.dat');
    my $menu_file  = File::Spec->catfile($dat_dir, 'menu_cards.dat');
    my $roles_file = File::Spec->catfile($dat_dir, 'roles.dat');

    # Definir si es vista global
    my $is_admin = ($role =~ /Administrador|Soporte/i) ? 1 : 0;

    # --- CARGA DE DATOS ---
    my %pacientes_map = ();
    my %mis_pacientes_id = ();
    my $t_pac = 0;
    if (-e $pac_file) {
        open(my $fh, '<:utf8', $pac_file) or die $!;
        while(my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^ID_PACIENTE/;
            my @f = split(/\|/, $line);
            
            my $tenant_pac = $f[13] // '';
            my ($org_pac, $suc_pac) = split(/:/, $tenant_pac);
            
            my $es_mi_paciente = 0;
            if ($role eq 'Administrador Global') {
                $es_mi_paciente = 1;
            } elsif ($role =~ /Administrador Organizacion|Soporte/i) {
                if ($org_pac && $org_pac eq $id_empresa) {
                    $es_mi_paciente = 1;
                } elsif (!$org_pac) {
                    $es_mi_paciente = 1;
                }
            } elsif ($role eq 'Medico') {
                if ($org_pac && $org_pac eq $id_empresa) {
                    if (($suc_pac eq $id_sucursal || !$suc_pac || !$id_sucursal) && $f[1] eq $id_medico) {
                        $es_mi_paciente = 1;
                    }
                } elsif (!$org_pac && $f[1] eq $id_medico) {
                    $es_mi_paciente = 1;
                }
            } elsif ($role eq 'Paciente' && $uid ne '') {
                my $c = lc($f[5] // '');
                $c =~ s/^\s+|\s+$//g;
                if ($c eq $uid) {
                    $es_mi_paciente = 1;
                    $mis_pacientes_id{$f[0]} = 1;
                }
            }
            
            if ($es_mi_paciente) {
                $pacientes_map{$f[0]} = $f[2];
                $t_pac++;
            }
        }
        close($fh);
    }

    my $total_cargos = 0;
    my $total_abonos = 0;
    if (-e $fin_file) {
        open(my $fh, '<:utf8', $fin_file) or die $!;
        while(my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^ID_OS/;
            my @f = split(/\|/, $line);
            # v3.5.5: F3: TIPO, F7: TOTAL, F9: ID_MEDICO, F2: ID_PACIENTE
            my $m_id = $f[9] // ''; $m_id =~ s/^\s+|\s+$//g;
            if ($is_admin || $m_id eq $id_medico || ($role eq 'Paciente' && $mis_pacientes_id{$f[2]})) {
                my $monto = $f[7] || 0;
                if ($f[3] =~ /Cargo/i) { $total_cargos += $monto; }
                elsif ($f[3] =~ /Abono/i) { $total_abonos += $monto; }
            }
        }
        close($fh);
    }
    my $total_saldo = $total_cargos - $total_abonos;

    # --- CÁLCULO DE RANGO DE 7 DÍAS ---
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $time_today = timelocal(0,0,0,$mday,$mon,$year);
    my $time_limit = $time_today + (7 * 24 * 60 * 60); # + 7 días
    
    my $hoy_str = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
    
    my $citas_hoy_count = 0;
    my @proximas_citas = ();
    if (-e $citas_file) {
        open(my $fh, '<:utf8', $citas_file) or die $!;
        while(my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^id_cita/;
            my @f = split(/\|/, $line);
            # F1: ID_MEDICO, F2: ID_PACIENTE, F3: FECHA, F4: HORA_INI
            if ($is_admin || $f[1] eq $id_medico || ($role eq 'Paciente' && $mis_pacientes_id{$f[2]})) {
                # Comparación de fecha
                my ($cy, $cm, $cd) = split(/-/, $f[3]);
                if ($cy && $cm && $cd) {
                    my $time_cita = timelocal(0,0,0,$cd,$cm-1,$cy-1900);
                    if ($time_cita >= $time_today && $time_cita <= $time_limit) {
                        $citas_hoy_count++ if $f[3] eq $hoy_str;
                        my $p_name = $pacientes_map{$f[2]} || "Paciente #$f[2]";
                        push @proximas_citas, { 
                            id => $f[0],
                            id_paciente => $f[2],
                            nombre_paciente => $p_name, 
                            hora => $f[4], 
                            motivo => $f[6], 
                            estado => $f[8], 
                            fecha => $f[3] 
                        };
                    }
                }
            }
        }
        close($fh);
    }
    # Ordenar citas por fecha y hora
    @proximas_citas = sort { $a->{fecha} cmp $b->{fecha} || $a->{hora} cmp $b->{hora} } @proximas_citas;

    my $str_cargos_k = format_compact_k($total_cargos);
    my $str_abonos_k = format_compact_k($total_abonos);
    my $str_saldo_k  = format_compact_k($total_saldo);
    my $val_cargos_f = $total_cargos / 1000;
    my $val_abonos_f = $total_abonos / 1000;
    my $val_saldo_f  = $total_saldo / 1000;

    # Homogenización de Etiquetas
    my $tit_modulos = "M&oacute;dulos de Gesti&oacute;n";
    my $tit_citas   = "Pr&oacute;ximas citas";

    utils::sub_sidebar::render_sidebar(
        usuario => $usuario,
        role => $role,
        id_medico => $id_medico,
        pagina_actual => 'dashboard'
    );
    print <<HTML;
        <!-- Dashboard Content -->
    <script>
    function animateValue(obj, start, end, duration, isK) {
        let startTimestamp = null;
        let lastFormatted = "";
        const step = (timestamp) => {
            if (!startTimestamp) startTimestamp = timestamp;
            const progress = Math.min((timestamp - startTimestamp) / duration, 1);
            const current = progress * (end - start) + start;
            const formatted = isK ? ("$ " + current.toFixed(2) + "k") : Math.floor(current).toLocaleString();
            
            if (formatted !== lastFormatted) {
                lastFormatted = formatted;
                obj.textContent = formatted;
            }
            if (progress < 1) {
                window.requestAnimationFrame(step);
            }
        };
        window.requestAnimationFrame(step);
    }
    function initDashboardCounters() {
        setTimeout(function() {
            const counters = document.querySelectorAll(".counter-up");
            counters.forEach(function(el) {
                const val = parseFloat(el.getAttribute("data-value"));
                const isK = el.getAttribute("data-is-k") === "true";
                if (!isNaN(val)) {
                    animateValue(el, 0, val, 1500, isK);
                }
            });
        }, 300);
    }
    
    if (document.readyState === 'loading') {
        document.addEventListener("DOMContentLoaded", initDashboardCounters);
    } else {
        initDashboardCounters();
    }
    document.addEventListener("spa:contentLoaded", initDashboardCounters);
    </script>
<style>
    /* MedentIA Bento Dashboard v1.0 (Diamond Armor Style) */
    .dash-kpi-card { 
        background: white; 
        border-radius: var(--radius-lg); 
        padding: 1.5rem; 
        border: 1px solid var(--md-teal-clinical); 
        box-shadow: var(--shadow-sm);
        transition: all 0.3s ease;
    }
    .dash-kpi-card:hover { transform: translateY(-5px); box-shadow: var(--shadow-md); }
    
    .kpi-value-medentia { 
        font-size: 2.2rem; 
        font-weight: 700; 
        color: var(--md-blue-deep); 
        font-family: var(--font-primary);
        letter-spacing: -1px;
    }
    .kpi-label-medentia { 
        font-size: 0.75rem; 
        font-weight: 600; 
        color: var(--md-text-secondary); 
        text-transform: uppercase; 
        letter-spacing: 0.1em; 
        margin-bottom: 0.5rem;
        display: block;
    }
    
    .premium-kpi-card {
        border-radius: var(--radius-lg);
        padding: 1.5rem;
        border: 1px solid rgba(255,255,255,0.2);
        position: relative;
        overflow: hidden;
        transition: 0.3s;
    }
    
    .kpi-icon-v2 { font-size: 2rem; opacity: 0.8; }
    .kpi-title-v2 { font-family: var(--font-primary); font-weight: 600; opacity: 0.9; }
    
    /* Variaciones de Color MedentIA (Diamond Armor: sin bordes diferenciados) */
    .bg-med-blue { background: #eef2ff; }
    .bg-med-teal { background: #f0fdfa; }
    .bg-med-cyan { background: #ecfeff; }
    .bg-med-deep { background: #f8fbff; }

    .mgmt-card {
        background: white;
        border-radius: var(--radius-md);
        padding: 1.25rem;
        border: 1px solid var(--md-teal-clinical);
        display: flex;
        align-items: center;
        gap: 1rem;
        text-decoration: none;
        transition: 0.3s;
    }
    .mgmt-card:hover { 
        background: var(--md-white-clinical);
        border-color: var(--md-cyan-ia);
        transform: scale(1.02);
    }
    .mgmt-card h3 { font-size: 1rem; margin: 0; color: var(--md-blue-deep); font-weight: 700; }
    .mgmt-card p { font-size: 0.75rem; margin: 0; color: var(--md-text-secondary); }
    
    .icon-box {
        width: 48px; height: 48px; border-radius: 12px;
        display: flex; align-items: center; justify-content: center;
        font-size: 1.5rem;
    }

    /* --- Botón Flotante (FAB) Premium y Responsividad (Capa 2 y 4) --- */
    .fab-btn-v2 {
        position: fixed !important;
        bottom: 85px !important; /* Fallback para navegadores antiguos */
        bottom: calc(85px + env(safe-area-inset-bottom, 0px)) !important;
        right: 20px !important;
        width: 56px !important;
        height: 56px !important;
        border-radius: 50% !important;
        background: #19B7A5 !important;
        color: white !important;
        border: none !important;
        box-shadow: 0 4px 15px rgba(25, 183, 165, 0.4) !important;
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
        z-index: 5000 !important; /* Debajo de bottom_nav (5500) pero encima de contenidos */
        transition: transform 0.2s ease, background-color 0.2s !important;
        cursor: pointer !important;
    }
    .fab-btn-v2:active {
        transform: scale(0.92) !important;
    }
    .fab-btn-v2 .material-icons {
        font-size: 24px !important;
        color: white !important;
    }

    \@media (max-width: 576px) {
        .app-container {
            padding: 10px !important; /* Optimizar espacio horizontal */
            padding-bottom: 90px !important; /* Evitar que el bottom_nav tape el contenido */
        }
        .dash-kpi-card {
            padding: 1rem !important;
        }
        .kpi-value-medentia {
            font-size: 1.6rem !important; /* Prevenir desborde de números */
        }
        .mgmt-card {
            padding: 0.85rem !important;
            gap: 0.75rem !important;
        }
        .icon-wrapper {
            padding: 8px !important;
            margin-right: 8px !important;
        }
        .card-content h3 {
            font-size: 0.95rem !important;
        }
        .card-content p {
            font-size: 0.75rem !important;
        }
        .timeline-container {
            padding-left: 16px !important;
            margin-left: 4px !important;
        }
        .appointment-item {
            padding: 12px !important;
        }
        .patient-info h4 {
            font-size: 0.95rem !important;
        }
        .fab-btn-v2 {
            bottom: 75px !important; /* Fallback para navegadores antiguos */
            bottom: calc(75px + env(safe-area-inset-bottom, 0px)) !important;
            right: 15px !important;
            width: 48px !important;
            height: 48px !important;
        }
        .fab-btn-v2 .material-icons {
            font-size: 20px !important;
        }
    }
</style>

HTML
    print <<HTML;
            <!-- Google Auth Script -->
            <script>
            function iniciarVinculacionGoogle() {
                const clientId = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
                const idMed = "$id_medico"; 
                const redirectUri = encodeURIComponent(window.location.origin + '/auth/oauth_callback.pl');
                const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=\${clientId}&redirect_uri=\${redirectUri}&response_type=code&scope=https://www.googleapis.com/auth/calendar.events&access_type=offline&prompt=consent&state=\${idMed}`;
                window.open(authUrl, 'GoogleAuth', 'width=600,height=700');
            }
            </script>

            <!-- Sección: KPIs Rápidos -->
            <div class="row g-4 mb-4 animate__animated animate__fadeIn">
                <div class="col-6 col-lg-3">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">Citas Hoy</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$citas_hoy_count">$citas_hoy_count</h2>
                        </div>
                        <i class="bi bi-calendar-check text-primary fs-2 kpi-icon" style="opacity: 0.8;"></i>
                    </div>
                </div>
HTML

    if ($role eq 'Paciente') {
        my $citas_futuras = scalar(@proximas_citas);
        print <<HTML;
                <div class="col-6 col-lg-3">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">Citas Futuras</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$citas_futuras">$citas_futuras</h2>
                        </div>
                        <i class="bi bi-calendar-range fs-2 kpi-icon" style="color: var(--md-teal-clinical); opacity: 0.8;"></i>
                    </div>
                </div>
HTML
    } else {
        print <<HTML;
                <div class="col-6 col-lg-3">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">Pacientes</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$t_pac">$t_pac</h2>
                        </div>
                        <i class="bi bi-people fs-2 kpi-icon" style="color: var(--md-teal-clinical); opacity: 0.8;"></i>
                    </div>
                </div>
HTML
    }

    print <<HTML;
                <div class="col-6 col-lg-3">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">Cargos</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$val_cargos_f" data-is-k="true">$str_cargos_k</h2>
                        </div>
                        <i class="bi bi-wallet2 text-cyan fs-2 kpi-icon" style="opacity: 0.8;"></i>
                    </div>
                </div>
                <div class="col-6 col-lg-3">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">Abonos</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$val_abonos_f" data-is-k="true">$str_abonos_k</h2>
                        </div>
                        <i class="bi bi-cash-stack fs-2 kpi-icon" style="color: var(--md-blue-deep); opacity: 0.8;"></i>
                    </div>
                </div>
HTML

    if ($role eq 'Paciente') {
        print <<HTML;
                <div class="col-6 col-lg-3">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">Saldo Pendiente</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$val_saldo_f" data-is-k="true">$str_saldo_k</h2>
                        </div>
                        <i class="bi bi-bank text-danger fs-2 kpi-icon" style="opacity: 0.8;"></i>
                    </div>
                </div>
HTML
    }

    print <<HTML;
            </div>

            <!-- Sección: Próximas Citas con Timeline -->
            <div class="row g-4">
                <div class="col-12 col-lg-8 offset-lg-2">
                    <h5 class="font-primary fw-bold mb-4" style="color: var(--md-blue-deep);">$tit_citas</h5>
                    <div class="bg-white rounded-4 p-4 shadow-sm" style="border: 1px solid var(--md-teal-clinical); min-height: 350px;">
                        <div class="d-flex flex-column flex-sm-row justify-content-between align-items-start align-items-sm-center gap-2 mb-4">
                            <p class="text-secondary font-secondary m-0 small fw-bold" style="letter-spacing: 0.5px;">ACTIVIDAD PROGRAMADA RECIENTE</p>
                            <a href="../views/agenda_main.pl" class="btn btn-sm btn-outline-unify rounded-pill px-3 py-1.5 text-nowrap align-self-stretch align-self-sm-auto text-center" style="font-size: 0.75rem;">Ver Agenda Completa</a>
                        </div>
HTML

    if (@proximas_citas == 0) {
        print '<div class="text-center py-5"><p class="text-muted small fw-bold">Sin actividad programada en los próximos 7 días.</p></div>';
    } else {
        foreach my $cita (@proximas_citas) {
            my $bCol = ($cita->{estado} =~ /Confirmada/i) ? 'bg-success-subtle text-success' : 'bg-primary-subtle text-primary';
            my $date_label = ($cita->{fecha} eq $hoy_str) ? 'Hoy' : substr($cita->{fecha}, 5);
            my $btn_accion = '';
            if ($role eq 'Medico') {
                if ($cita->{estado} =~ /Atendida|Finalizada|Completada/i) {
                    $btn_accion = qq{<a href="../views/consulta_detalles.pl?id_cita=$cita->{id}&id_paciente=$cita->{id_paciente}" class="btn btn-sm btn-outline-primary fw-bold rounded-pill px-3 py-1 ms-2" style="font-size:0.75rem;"><i class="bi bi-file-earmark-medical me-1"></i> Ver Consulta</a>};
                } else {
                    $btn_accion = qq{<a href="../views/render_consultas_privado.pl?id=$cita->{id_paciente}&id_cita=$cita->{id}" class="btn btn-sm btn-success fw-bold rounded-pill px-3 py-1 ms-2" style="background: linear-gradient(135deg, #10b981, #059669); border:none; font-size:0.75rem;"><i class="bi bi-person-check me-1"></i> Tomar Cita</a>};
                }
            }
            print qq{
                <div class="d-flex align-items-center justify-content-between p-3 bg-white rounded-4 mb-3 shadow-sm interactive-scale" style="border: 1px solid rgba(25, 183, 165, 0.4);">
                    <div style="flex-grow:1">
                        <span class="d-block fw-bold text-navy mb-1" style="font-size:0.85rem;">$cita->{nombre_paciente}</span>
                        <div class="d-flex gap-2 align-items-center"><span class="badge bg-light text-muted" style="font-size:0.6rem;">$date_label</span><small class="text-muted fw-semibold" style="font-size:0.7rem;"><i class="bi bi-clock me-1"></i>$cita->{hora}</small></div>
                    </div>
                    <div class="text-end d-flex align-items-center gap-2">
                        <span class="badge $bCol rounded-pill border-0 px-3 py-2 fw-bold" style="font-size:0.6rem;">$cita->{estado}</span>
                        $btn_accion
                    </div>
                </div>\n};
        }
    }

    print <<HTML;
                    </div>
                </div>
            </div>
            

            
HTML
    utils::sub_sidebar::render_sidebar_footer();

    if ($t_pac == 0 && $role eq 'Medico') {
        print <<HTML;
<!-- MODAL DE BIENVENIDA MULTI-TENANT (Día 1) -->
<div class="modal fade" id="welcomeModal" tabindex="-1" aria-hidden="true" data-bs-backdrop="static">
    <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content border-0 rounded-4 shadow-lg" style="overflow:hidden;">
            <div class="modal-header border-0 bg-primary text-white" style="background: linear-gradient(135deg, #0A2A66 0%, #00C4C4 100%); padding: 2rem;">
                <h4 class="modal-title fw-black"><i class="bi bi-stars me-2"></i>¡Bienvenido a OSPulso, tu clínica está lista!</h4>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body p-4 p-md-5 text-center bg-light">
                <div class="mb-4">
                    <img src="../assets/img/hero_mockup.png" alt="OSPulso Dashboard" class="img-fluid rounded-4 shadow-sm" style="max-height: 200px; object-fit: cover;" onerror="this.style.display='none'">
                </div>
                <h5 class="fw-bold text-navy mb-3">Hemos creado un espacio aislado y seguro para ti.</h5>
                <p class="text-muted mb-4">Todo está configurado para que operes con fricción cero. Tu agenda está limpia, tus indicadores en cero y estás listo para registrar tu primer paciente o agendar tu primera cita.</p>
                <div class="d-flex justify-content-center gap-3 flex-wrap">
                    <a href="../views/crud_paciente.pl" class="btn btn-primary btn-lg rounded-pill px-4 fw-bold shadow-sm"><i class="bi bi-person-plus-fill me-2"></i>Registrar Paciente</a>
                    <a href="../views/agenda_main.pl" class="btn btn-outline-primary btn-lg rounded-pill px-4 fw-bold bg-white"><i class="bi bi-calendar-check me-2"></i>Ver mi Agenda</a>
                </div>
            </div>
            <div class="modal-footer border-0 justify-content-center bg-light pb-4">
                <a href="../views/perfil.pl" class="text-muted small text-decoration-none"><i class="bi bi-gear-fill me-1"></i>Configurar detalles avanzados de la clínica (Opcional)</a>
            </div>
        </div>
    </div>
</div>
<script>
    document.addEventListener("DOMContentLoaded", function() {
        var welcomeModal = new bootstrap.Modal(document.getElementById('welcomeModal'));
        welcomeModal.show();
    });
</script>
HTML
    }

}
1;