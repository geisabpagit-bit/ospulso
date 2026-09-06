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
    my $is_admin = ($role =~ /Administrador|Soporte|Recepcionista/i) ? 1 : 0;

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
            } elsif ($role =~ /Administrador Organizacion|Soporte|Recepcionista/i) {
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
    my %saldos_estado = ();

    if ($role eq 'Recepcionista') {
        # Para Recepcionista, leer folios_recibos_privados y publicos
        my @recibos_files = (
            File::Spec->catfile($dat_dir, 'folios_recibos_privados.dat'),
            File::Spec->catfile($dat_dir, 'folios_recibos_publicos.dat')
        );
        
        my %medicos = ();
        my $usuarios_file = File::Spec->catfile($dat_dir, 'usuarios.dat');
        if (-e $usuarios_file && open(my $fu, '<:utf8', $usuarios_file)) {
            my $header = <$fu>;
            while(my $line = <$fu>) {
                chomp $line;
                my @u = split /!/, $line, -1;
                $medicos{$u[0]} = $u[1] if @u >= 2;
            }
            close $fu;
        }
        my $mi_nombre = $medicos{$usuario} || $usuario;
        
        foreach my $rfile (@recibos_files) {
            if (-e $rfile && open(my $fh, '<:utf8', $rfile)) {
                my $header = <$fh>;
                while(my $line = <$fh>) {
                    chomp($line);
                    next if $line =~ /^\s*$/;
                    my @r = split(/\|/, $line, -1);
                    my $elaborado = $r[11] // '';
                    if ($elaborado eq $usuario || $elaborado eq $mi_nombre) {
                        $total_cargos += ($r[8] || 0);
                        $total_abonos += ($r[9] || 0);
                    }
                }
                close($fh);
            }
        }
    } else {
        if (-e $fin_file) {
            open(my $fh, '<:utf8', $fin_file) or die $!;
            while(my $line = <$fh>) {
                chomp($line);
                next if $line =~ /^ID_OS/;
                my @f = split(/\|/, $line);
                # v3.5.5: F3: TIPO, F7: TOTAL, F9: ID_MEDICO, F2: ID_PACIENTE
                my $m_id = $f[9] // ''; $m_id =~ s/^\s+|\s+$//g;
                my $id_paciente = $f[2] // '';
                my $monto = $f[7] || 0;
    
                if ($is_admin || $m_id eq $id_medico || ($role eq 'Paciente' && $mis_pacientes_id{$id_paciente})) {
                    if ($f[3] =~ /Cargo/i) { $total_cargos += $monto; }
                    elsif ($f[3] =~ /Abono/i) { $total_abonos += $monto; }
                }
    
                # Acumular para CxC Estado si aplica
                if ($id_paciente =~ /^EMP-/) {
                    if ($f[3] =~ /Cargo/i && ($f[10] // '') !~ /Presupuesto|Cotizacion/i) {
                        $saldos_estado{$f[0]}{cargos} += $monto;
                    } elsif ($f[3] =~ /Abono/i) {
                        $saldos_estado{$f[0]}{abonos} += $monto;
                    }
                }
            }
            close($fh);
        }
    }
    my $total_saldo = $total_cargos - $total_abonos;
    
    my $cxc_estado_total = 0;
    foreach my $id_os (keys %saldos_estado) {
        my $ab = $saldos_estado{$id_os}{abonos} || 0;
        my $cg = $saldos_estado{$id_os}{cargos} || 0;
        $cxc_estado_total += ($ab > 0 ? $ab : $cg);
    }

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
    my $str_cxc_estado_k = format_compact_k($cxc_estado_total);
    my $val_cargos_f = $total_cargos / 1000;
    my $val_abonos_f = $total_abonos / 1000;
    my $val_saldo_f  = $total_saldo / 1000;
    my $val_cxc_estado_f = $cxc_estado_total / 1000;

    # Homogenización de Etiquetas
    my $tit_modulos = "M&oacute;dulos de Gesti&oacute;n";
    my $tit_citas   = "Pr&oacute;ximas citas";

    utils::sub_sidebar::render_sidebar(
        usuario => $usuario,
        role => $role,
        id_medico => $id_medico,
        id_empresa => $id_empresa,
        pagina_actual => 'dashboard'
    );
    print <<'JS';
    <script>
    function animateValue(obj, start, end, duration, isK) {
        let startTimestamp = null;
        let lastFormatted = null;
        const step = (timestamp) => {
            if (!startTimestamp) startTimestamp = timestamp;
            const progress = Math.min((timestamp - startTimestamp) / duration, 1);
            const current = progress * (end - start) + start;
            const formatted = isK ? ('$ ' + current.toFixed(2) + 'k') : Math.floor(current).toLocaleString();
            
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
JS
    print <<HTML;
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
    .kpi-acrilico {
        background: rgba(255, 255, 255, 0.85);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(10, 42, 102, 0.15);
        border-radius: var(--radius-lg);
        padding: 1.25rem;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
        transition: all 0.25s ease;
    }
    .kpi-acrilico:hover {
        transform: translateY(-2px);
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.08);
        border-color: var(--md-teal-clinical);
    }
    .kpi-titulo {
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
        color: var(--md-gray-text);
        letter-spacing: 0.5px;
        margin-bottom: 0.25rem;
    }
    .kpi-valor {
        font-size: 1.8rem;
        font-weight: 800;
        color: var(--md-blue-deep);
        letter-spacing: -1px;
        font-family: 'Plus Jakarta Sans', sans-serif;
    }
</style>

HTML
    print <<'JS';
            <!-- Google Auth Script -->
            <script>
            function iniciarVinculacionGoogle() {
                const clientId = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
                const idMed = document.body.dataset.idMedico || ''; 
                const redirectUri = encodeURIComponent(window.location.origin + '/auth/oauth_callback.pl');
                const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=https://www.googleapis.com/auth/calendar.events&access_type=offline&prompt=consent&state=${idMed}`;
                window.open(authUrl, 'GoogleAuth', 'width=600,height=700');
            }
            </script>
JS
    print <<HTML;
            <div class="row g-2 g-lg-4 mb-3 mb-lg-4 animate__animated animate__fadeIn card-mobile-flush">
                <div class="col-6 col-lg-2">
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
                <div class="col-6 col-lg-2">
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
                <div class="col-6 col-lg-2">
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
                <div class="col-6 col-lg-2">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">Cargos</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$val_cargos_f" data-is-k="true">$str_cargos_k</h2>
                        </div>
                        <i class="bi bi-wallet2 text-cyan fs-2 kpi-icon" style="opacity: 0.8;"></i>
                    </div>
                </div>
                <div class="col-6 col-lg-2">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">Abonos</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$val_abonos_f" data-is-k="true">$str_abonos_k</h2>
                        </div>
                        <i class="bi bi-cash-stack fs-2 kpi-icon" style="color: var(--md-blue-deep); opacity: 0.8;"></i>
                    </div>
                </div>
HTML

    if ($role eq 'Recepcionista') {
        print <<HTML;
                <div class="col-6 col-lg-2">
                    <div class="kpi-acrilico h-100 d-flex align-items-center justify-content-between">
                        <div>
                            <span class="kpi-titulo">CxC Estado</span>
                            <h2 class="kpi-valor counter-up m-0" data-value="$val_cxc_estado_f" data-is-k="true">$str_cxc_estado_k</h2>
                        </div>
                        <i class="bi bi-bank text-secondary fs-2 kpi-icon" style="opacity: 0.8;"></i>
                    </div>
                </div>
HTML
    }

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

            <!-- Sección: Próximas Citas o Dashboard Recepcionista -->
HTML

    if ($role eq 'Recepcionista') {
        print <<HTML;
            <div class="row g-4 mt-2 mb-4">
                <div class="col-12">
                    <div class="card card-medentia-aura border-0 shadow-sm p-4 rounded-4">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <div>
                                <h5 class="fw-bold m-0" style="color: var(--md-blue-deep);"><i class="bi bi-wallet2 me-2 text-primary"></i>Ingresos (Efectivo / Privados)</h5>
                                <p class="text-muted small m-0">Detalle de ingresos recibidos por servicios privados (Últimas 24 Hrs).</p>
                            </div>
                        </div>
                        <div class="table-responsive">
                            <table id="dtIngresosPrivados" class="table table-hover table-sm align-middle w-100" style="font-size: 10px !important;">
                                <thead class="table-light text-muted" style="font-size: 10.5px !important;">
                                    <tr>
                                        <th style="width: 8%;">Folio</th>
                                        <th style="width: 12%;">Fecha</th>
                                        <th style="width: 30%;">Paciente</th>
                                        <th style="width: 20%;">Médico</th>
                                        <th style="width: 12%;">Forma Pago</th>
                                        <th style="width: 10%;" class="text-end">Monto</th>
                                        <th style="width: 8%;" class="text-center">Acciones</th>
                                    </tr>
                                </thead>
                                <tbody style="font-size: 10px !important;"></tbody>
                                <tfoot class="bg-light fw-bold" style="font-size: 11px !important;">
                                    <tr>
                                        <th colspan="5" class="text-end">Total Ingresos Privados:</th>
                                        <th class="text-end text-success" id="tfootTotalPrivados">$0.00</th>
                                        <th></th>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="row g-4 mt-4 mb-5">
                <div class="col-12">
                    <div class="card card-medentia-aura border-0 shadow-sm p-3 rounded-4">
                        <div class="d-flex justify-content-between align-items-center mb-3">
                            <div>
                                <h5 class="fw-bold m-0" style="color: var(--md-blue-deep); font-size: 14px;"><i class="bi bi-building me-2 text-info"></i>Ingresos Municipio</h5>
                                <p class="text-muted small m-0" style="font-size: 11px;">Detalle de ingresos generados por derechohabientes del Municipio (Últimas 24 Hrs).</p>
                            </div>
                        </div>
                        <div class="table-responsive">
                            <table id="dtIngresosMunicipio" class="table table-hover table-sm align-middle w-100" style="font-size: 10px !important;">
                                <thead class="table-light text-muted" style="font-size: 10.5px !important;">
                                    <tr>
                                        <th style="width: 8%;">Folio OS</th>
                                        <th style="width: 12%;">Fecha</th>
                                        <th style="width: 32%;">Paciente / Trabajador</th>
                                        <th style="width: 18%;">Dependencia</th>
                                        <th style="width: 15%;">Médico</th>
                                        <th style="width: 7%;" class="text-end">Monto</th>
                                        <th style="width: 8%;" class="text-center">Acciones</th>
                                    </tr>
                                </thead>
                                <tbody style="font-size: 10px !important;"></tbody>
                                <tfoot class="bg-light fw-bold" style="font-size: 11px !important;">
                                    <tr>
                                        <th colspan="5" class="text-end">Total Ingresos Municipio:</th>
                                        <th class="text-end text-info" id="tfootTotalMunicipio">$0.00</th>
                                        <th></th>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Estilos y Scripts Datatables Premium -->
            <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
            <link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.1/css/buttons.bootstrap5.min.css">
            <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
            <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
            <script src="https://cdn.datatables.net/buttons/2.4.1/js/dataTables.buttons.min.js"></script>
            <script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.bootstrap5.min.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/pdfmake.min.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/vfs_fonts.js"></script>
            <script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.html5.min.js"></script>
            <script src="https://cdn.datatables.net/buttons/2.4.1/js/buttons.print.min.js"></script>
HTML
        print <<'JS';
            <script>
                function escapeHtml(unsafe) {
                    if (!unsafe) return '';
                    return (unsafe + '').replace(/[&<"'>]/g, function (m) {
                        return {
                            '&': '&amp;',
                            '<': '&lt;',
                            '>': '&gt;',
                            '"': '&quot;',
                            "'": '&#039;'
                        }[m];
                    });
                }

                function renderTablaCorte(selector, dataSource, columnsConfig) {
                    if ($.fn.DataTable.isDataTable(selector)) {
                        $(selector).DataTable().clear().rows.add(dataSource).draw();
                    } else {
                        // Eliminamos la barra de búsqueda modificando la propiedad dom
                        const dtConfig = {
                            language: { url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json' },
                            dom: '<"d-flex flex-wrap align-items-center justify-content-between mb-3"<"export-toolbar"B>>rt<"d-flex justify-content-between align-items-center mt-3"ip>',
                            buttons: [
                                { extend: 'copy', text: '<i class="bi bi-clipboard me-1"></i> COPIAR', className: 'btn btn-sm btn-export fw-bold' },
                                { extend: 'excel', text: '<i class="bi bi-file-earmark-spreadsheet me-1"></i> EXCEL', className: 'btn btn-sm btn-export fw-bold' },
                                { extend: 'pdf', text: '<i class="bi bi-file-earmark-pdf me-1"></i> PDF', className: 'btn btn-sm btn-export fw-bold' },
                                { extend: 'print', text: '<i class="bi bi-printer me-1"></i> IMPRIMIR', className: 'btn btn-sm btn-export fw-bold' }
                            ],
                            pageLength: 10,
                            lengthChange: false,
                            data: dataSource,
                            columns: columnsConfig,
                            createdRow: function(row, data, dataIndex) {
                                // For mobile views if needed
                            }
                        };
                        $(selector).DataTable(dtConfig);
                    }
                }

                document.addEventListener('DOMContentLoaded', function() {
                    const tzoffset = (new Date()).getTimezoneOffset() * 60000;
                    let hoy = (new Date(Date.now() - tzoffset)).toISOString().split('T')[0];

                    $.ajax({
                        url: '../api/generar_corte_caja.pl',
                        type: 'POST',
                        dataType: 'json',
                        data: { f_inicio: hoy, f_fin: hoy },
                        success: function(res) {
                            if (res.error) {
                                if (typeof Swal !== 'undefined') Swal.fire('Error', res.msg || 'Error al cargar ingresos', 'error');
                                return;
                            }

                            let dataIngresos = (res && Array.isArray(res.ingresos)) ? res.ingresos : [];
                            let dataMunicipio = (res && Array.isArray(res.cxc)) ? res.cxc : [];

                            renderTablaCorte('#dtIngresosPrivados', dataIngresos, [
                                { 
                                    data: 'folio',
                                    render: function(d) {
                                        return `<span class="badge bg-light text-dark border font-monospace px-2 py-1" style="font-size: 9.5px;">${d || ''}</span>`;
                                    }
                                },
                                { 
                                    data: 'fecha',
                                    render: function(d) {
                                        if (!d) return '';
                                        let parts = d.split(' ');
                                        let f = parts[0] || '';
                                        let h = parts[1] || '';
                                        return `<div class="text-nowrap fw-semibold" style="font-size: 10px;">${f}</div><div class="text-muted text-nowrap" style="font-size: 9.5px;">${h}</div>`;
                                    }
                                },
                                { 
                                    data: 'paciente',
                                    render: function(data, type, row) {
                                        let isCancel = (row.estatus === 'Cancelado');
                                        let pacHtml = `<div class="fw-bold ${isCancel ? 'text-decoration-line-through text-muted' : 'text-dark'}" style="font-size: 10.5px;">${data || ''}</div>`;
                                        if (isCancel) {
                                            pacHtml += `<div class="d-flex align-items-center gap-1 mt-1">
                                                <span class="badge bg-danger text-uppercase px-2 py-0" style="font-size: 8.5px;"><i class="bi bi-x-circle me-1"></i>CANCELADO</span>
                                                <span class="text-danger fw-semibold" style="font-size: 9.5px;">Motivo: ${row.motivo || 'Sin motivo registrado'}</span>
                                            </div>`;
                                        }
                                        return pacHtml;
                                    }
                                },
                                { 
                                    data: 'medico',
                                    render: function(d) {
                                        return `<span class="text-muted fw-semibold d-block text-truncate" style="max-width: 140px; font-size: 10px;" title="${d || 'N/D'}">${d || 'N/D'}</span>`;
                                    }
                                },
                                { 
                                    data: 'forma_pago',
                                    render: function(data, type, row) {
                                        if (row.estatus === 'Cancelado') {
                                            return `<span class="badge bg-danger text-uppercase px-2 py-0" style="font-size: 8.5px;"><i class="bi bi-x-circle me-1"></i>CANCELADO</span>`;
                                        }
                                        return `<span class="badge bg-light text-dark border px-2 py-1" style="font-size: 9.5px;">${data || 'Efectivo'}</span>`;
                                    }
                                },
                                { 
                                    data: 'monto', 
                                    className: 'text-end',
                                    render: function(data, type, row) {
                                        let val = parseFloat(data) || 0;
                                        let fmt = '$' + val.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                                        if (row.estatus === 'Cancelado') {
                                            return `<span class="text-decoration-line-through text-danger fw-bold text-nowrap" style="font-size: 11px;">${fmt}</span>`;
                                        }
                                        return `<span class="text-success fw-bold text-nowrap" style="font-size: 11.5px;">${fmt}</span>`;
                                    }
                                },
                                {
                                    data: null,
                                    className: 'text-center',
                                    orderable: false,
                                    render: function(data, type, row) {
                                        let f = row.folio_raw || row.folio || '';
                                        let isCancel = (row.estatus === 'Cancelado');
                                        let btnDelete = isCancel ?
                                            `<button class="btn btn-sm btn-outline-secondary rounded-pill px-2 py-0 disabled text-nowrap" style="font-size: 9px;" title="Ya está cancelado"><i class="bi bi-x-circle me-1"></i>Cancelado</button>` :
                                            `<button class="btn btn-sm btn-outline-danger shadow-sm rounded-pill px-2 py-0 text-nowrap" style="font-size: 9px;" onclick="cancelarRecibo('${f}', 'privados')" title="Cancelar Recibo"><i class="bi bi-trash-fill me-1"></i>Eliminar</button>`;
                                        return `<div class="d-flex justify-content-center align-items-center gap-1 text-nowrap">
                                            <button class="btn btn-sm btn-outline-primary shadow-sm rounded-pill px-2 py-0 text-nowrap" style="font-size: 9.5px;" onclick="window.open('../api/ver_recibo.pl?tipo=privados&id_os=${f}', '_blank')" title="Ver / Imprimir Recibo Privado"><i class="bi bi-printer-fill me-1"></i>Ver Recibo</button>
                                            ${btnDelete}
                                        </div>`;
                                    }
                                }
                            ]);

                            renderTablaCorte('#dtIngresosMunicipio', dataMunicipio, [
                                { 
                                    data: 'folio',
                                    render: function(d) {
                                        return `<span class="badge bg-light text-dark border font-monospace px-2 py-1" style="font-size: 9.5px;">${d || ''}</span>`;
                                    }
                                },
                                { 
                                    data: 'fecha',
                                    render: function(d) {
                                        if (!d) return '';
                                        let parts = d.split(' ');
                                        let f = parts[0] || '';
                                        let h = parts[1] || '';
                                        return `<div class="text-nowrap fw-semibold" style="font-size: 10px;">${f}</div><div class="text-muted text-nowrap" style="font-size: 9.5px;">${h}</div>`;
                                    }
                                },
                                { 
                                    data: 'paciente',
                                    render: function(data, type, row) {
                                        let isCancel = (row.estatus === 'Cancelado');
                                        let rawPac = (data || '').replace(/^Paciente:\s*/i, '').trim();
                                        if (!rawPac || /^Metodo:/i.test(rawPac)) {
                                            rawPac = row.trabajador_nombre || 'Empleado Estatal';
                                        }
                                        let empNum = row.num_empleado || '';
                                        let empNom = row.trabajador_nombre || '';

                                        let txtTrabajador = empNom ? (empNum ? `${empNum} - ${empNom}` : empNom) : (empNum ? empNum : '');

                                        let html = `<div class="fw-bold ${isCancel ? 'text-decoration-line-through text-muted' : 'text-dark'}" style="font-size: 10.5px;"><i class="bi bi-person-fill me-1 text-primary"></i>${escapeHtml(rawPac)}</div>`;
                                        
                                        if (txtTrabajador && rawPac.toLowerCase() !== empNom.toLowerCase()) {
                                            html += `<div class="text-muted ${isCancel ? 'text-decoration-line-through' : ''}" style="font-size: 9.5px;"><i class="bi bi-person-badge me-1 text-secondary"></i><strong>Trabajador:</strong> ${escapeHtml(txtTrabajador)}</div>`;
                                        } else if (empNum) {
                                            html += `<div class="text-muted ${isCancel ? 'text-decoration-line-through' : ''}" style="font-size: 9.5px;"><i class="bi bi-card-text me-1 text-secondary"></i><strong>Num. Empleado:</strong> ${escapeHtml(empNum)}</div>`;
                                        }

                                        if (isCancel) {
                                            html += `<div class="d-flex align-items-center gap-1 mt-1">
                                                <span class="badge bg-danger text-uppercase px-2 py-0" style="font-size: 8.5px;"><i class="bi bi-x-circle me-1"></i>CANCELADO</span>
                                                <span class="text-danger fw-semibold" style="font-size: 9.5px;">Motivo: ${escapeHtml(row.motivo || 'Sin motivo registrado')}</span>
                                            </div>`;
                                        }
                                        return html;
                                    }
                                },
                                { 
                                    data: 'dependencia',
                                    render: function(data, type, row) {
                                        let dep = data || 'Municipio';
                                        let isCancel = (row.estatus === 'Cancelado');
                                        return `<div class="d-inline-block text-truncate border rounded px-2 py-0 bg-light text-dark ${isCancel ? 'text-decoration-line-through opacity-75' : ''}" style="max-width: 150px; font-size: 9.5px;" title="${dep}"><i class="bi bi-building me-1 text-info"></i>${dep}</div>`;
                                    }
                                },
                                { 
                                    data: 'medico',
                                    render: function(d) {
                                        return `<span class="text-muted fw-semibold d-block text-truncate" style="max-width: 130px; font-size: 10px;" title="${d || 'N/D'}">${d || 'N/D'}</span>`;
                                    }
                                },
                                { 
                                    data: 'monto', 
                                    className: 'text-end',
                                    render: function(data, type, row) {
                                        let val = parseFloat(data) || 0;
                                        let fmt = '$' + val.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                                        if (row.estatus === 'Cancelado') {
                                            return `<span class="text-decoration-line-through text-danger fw-bold text-nowrap" style="font-size: 11px;">${fmt}</span>`;
                                        }
                                        return `<span class="text-info fw-bold text-nowrap" style="font-size: 11.5px;">${fmt}</span>`;
                                    }
                                },
                                {
                                    data: null,
                                    className: 'text-center',
                                    orderable: false,
                                    render: function(data, type, row) {
                                        let f = row.folio_raw || row.folio || '';
                                        let isCancel = (row.estatus === 'Cancelado');
                                        let btnDelete = isCancel ?
                                            `<button class="btn btn-sm btn-outline-secondary rounded-pill px-2 py-0 disabled text-nowrap" style="font-size: 9px;" title="Ya está cancelado"><i class="bi bi-x-circle me-1"></i>Cancelado</button>` :
                                            `<button class="btn btn-sm btn-outline-danger shadow-sm rounded-pill px-2 py-0 text-nowrap" style="font-size: 9px;" onclick="cancelarRecibo('${f}', 'publicos')" title="Cancelar Recibo"><i class="bi bi-trash-fill me-1"></i>Eliminar</button>`;
                                        return `<div class="d-flex justify-content-center align-items-center gap-1 text-nowrap">
                                            <button class="btn btn-sm btn-outline-primary shadow-sm rounded-pill px-2 py-0 text-nowrap" style="font-size: 9.5px;" onclick="window.open('../api/ver_recibo.pl?tipo=publicos&id_os=${f}', '_blank')" title="Ver / Imprimir Recibo Municipio"><i class="bi bi-printer-fill me-1"></i>Ver Recibo</button>
                                            ${btnDelete}
                                        </div>`;
                                    }
                                }
                            ]);

                            let totPriv = dataIngresos.reduce((acc, curr) => acc + (curr.estatus === 'Cancelado' ? 0 : (parseFloat(curr.monto) || 0)), 0);
                            let totMuni = dataMunicipio.reduce((acc, curr) => acc + (curr.estatus === 'Cancelado' ? 0 : (parseFloat(curr.monto) || 0)), 0);

                            let elTotPriv = document.getElementById('tfootTotalPrivados');
                            let elTotMuni = document.getElementById('tfootTotalMunicipio');
                            if (elTotPriv) elTotPriv.textContent = '$' + totPriv.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                            if (elTotMuni) elTotMuni.textContent = '$' + totMuni.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                        },
                        error: function() {
                            if (typeof Swal !== 'undefined') Swal.fire('Error', 'Fallo al comunicarse con la API', 'error');
                        }
                    });
                });
                
                function cancelarRecibo(id, tipo) {
                    Swal.fire({
                        title: '¿Cancelar Recibo?',
                        text: "Esta acción marcará el recibo como cancelado y afectará los KPIs financieros. Por favor, explique el motivo:",
                        input: 'text',
                        inputAttributes: {
                            autocapitalize: 'off',
                            required: 'true',
                            placeholder: 'Motivo de cancelación'
                        },
                        icon: 'warning',
                        showCancelButton: true,
                        confirmButtonColor: '#dc3545',
                        cancelButtonColor: '#6c757d',
                        confirmButtonText: 'Sí, Cancelar',
                        cancelButtonText: 'No',
                        preConfirm: (motivo) => {
                            if (!motivo || motivo.trim() === '') {
                                Swal.showValidationMessage('Debe ingresar un motivo de cancelación');
                                return false;
                            }
                            return motivo;
                        }
                    }).then((result) => {
                        if (result.isConfirmed) {
                            let motivo = result.value;
                            $.post('../api/cancelar_recibo_api.pl', { id_recibo: id, tipo: tipo, motivo: motivo }, function(res) {
                                if (res.ok) {
                                    Swal.fire('Cancelado', res.msg, 'success').then(() => {
                                        window.location.reload(); // Simple reload para refrescar datos rápidos en el dashboard
                                    });
                                } else {
                                    Swal.fire('Error', res.msg, 'error');
                                }
                            });
                        }
                    });
                }
            </script>
JS
    } else {
        print <<HTML;
            <div class="row g-2 g-lg-4 card-mobile-flush">
                <div class="col-12 col-lg-8 offset-lg-2">
                    <h5 class="font-primary fw-bold mb-3 mb-lg-4 mobile-condensed-title px-2 px-lg-0" style="color: var(--md-blue-deep);">$tit_citas</h5>
                    <div class="bg-white rounded-4 p-3 p-lg-4 shadow-sm mobile-edge-to-edge" style="border: 1px solid var(--md-teal-clinical); min-height: 350px;">
                        <div class="d-flex flex-column flex-sm-row justify-content-between align-items-start align-items-sm-center gap-3 mb-4">
                            <p class="text-secondary font-secondary m-0 small fw-bold" style="letter-spacing: 0.5px;">ACTIVIDAD PROGRAMADA RECIENTE</p>
HTML

    if ($role ne 'Paciente') {
        print qq{                            <a href="../views/agenda_main.pl" class="btn btn-mobile-standard btn-mobile-outline btn-mobile-full" style="font-size: 0.85rem;"><i class="bi bi-calendar-check fs-5"></i> Ver Agenda Completa</a>\n};
    }

    print <<HTML;
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
                    $btn_accion = qq{<a href="../views/consulta_detalles.pl?id_cita=$cita->{id}&id_paciente=$cita->{id_paciente}" class="btn btn-mobile-standard btn-mobile-outline mt-2 mt-sm-0 w-100"><i class="bi bi-file-earmark-medical fs-5"></i> Ver Consulta</a>};
                } else {
                    $btn_accion = qq{<a href="../views/render_consultas_privado.pl?id=$cita->{id_paciente}&id_cita=$cita->{id}" class="btn btn-mobile-standard btn-mobile-action mt-2 mt-sm-0 w-100" style="background: linear-gradient(135deg, #10b981, #059669); border:none;"><i class="bi bi-person-check fs-5"></i> Tomar Cita</a>};
                }
            }
            print qq{
                <div class="d-flex flex-column flex-sm-row align-items-start align-items-sm-center justify-content-between p-3 bg-white rounded-4 mb-3 shadow-sm interactive-scale gap-3 gap-sm-0" style="border: 1px solid rgba(25, 183, 165, 0.4);">
                    <div style="flex-grow:1; width: 100%;">
                        <span class="d-block fw-bold text-navy mb-1" style="font-size:0.95rem;">$cita->{nombre_paciente}</span>
                        <div class="d-flex gap-2 align-items-center"><span class="badge bg-light text-muted" style="font-size:0.75rem;">$date_label</span><small class="text-muted fw-semibold" style="font-size:0.8rem;"><i class="bi bi-clock me-1"></i>$cita->{hora}</small></div>
                    </div>
                    <div class="d-flex flex-column flex-sm-row align-items-stretch align-items-sm-center gap-2 w-100" style="max-width: 100%;">
                        <span class="badge $bCol rounded-pill border-0 px-3 py-2 fw-bold align-self-start align-self-sm-center" style="font-size:0.75rem;">$cita->{estado}</span>
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
    }
            
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