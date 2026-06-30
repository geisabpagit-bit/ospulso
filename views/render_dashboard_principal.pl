#!/usr/bin/perl
# --- Dashboard Principal Premium v3.5.3 (Dynamic Data Sync) ---
use strict;
use warnings;
use utf8;
use CGI;
use File::Spec;
use FindBin;
use Time::Local;

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

    # Rutas de datos
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $citas_file = File::Spec->catfile($dat_dir, 'citas.dat');
    my $pac_file   = File::Spec->catfile($dat_dir, 'pacientes.dat');
    my $fin_file   = File::Spec->catfile($dat_dir, 'estado_cuenta.dat');
    my $menu_file  = File::Spec->catfile($dat_dir, 'menu_cards.dat');
    my $roles_file = File::Spec->catfile($dat_dir, 'roles.dat');

    # --- CARGA DINÁMICA DE MENÚ SEGÚN ROL ---
    my %menu_registry = ();
    if (-e $menu_file) {
        open(my $mf, '<:utf8', $menu_file) or die $!;
        while(my $line = <$mf>) {
            chomp($line);
            next if $line =~ /^#|^\s*$/;
            my @f = split(/\|/, $line);
            $menu_registry{$f[0]} = {
                url => $f[1],
                title => $f[2],
                desc => $f[3],
                icon => $f[4],
                color => $f[5]
            };
        }
        close($mf);
    }

    my @allowed_modules = ();
    if (-e $roles_file) {
        open(my $rf, '<:utf8', $roles_file) or die $!;
        while(my $line = <$rf>) {
            chomp($line);
            next if $line =~ /^#|^\s*$/;
            my @f = split(/\|/, $line);
            if ($f[0] eq $role) {
                # ENLACE_1 empieza en índice 2
                @allowed_modules = @f[2..$#f];
                last;
            }
        }
        close($rf);
    }

    # Definir si es vista global
    my $is_admin = ($role =~ /Administrador|Soporte/i) ? 1 : 0;

    # --- CARGA DE DATOS ---
    my %pacientes_map = ();
    my $t_pac = 0;
    if (-e $pac_file) {
        open(my $fh, '<:utf8', $pac_file) or die $!;
        while(my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^ID_PACIENTE/;
            my @f = split(/\|/, $line);
            if ($is_admin || $f[1] eq $id_medico) {
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
            # v3.5.5: F3: TIPO, F7: TOTAL, F9: ID_MEDICO
            my $m_id = $f[9] // ''; $m_id =~ s/^\s+|\s+$//g;
            if ($is_admin || $m_id eq $id_medico) {
                my $monto = $f[7] || 0;
                if ($f[3] =~ /Cargo/i) { $total_cargos += $monto; }
                elsif ($f[3] =~ /Abono/i) { $total_abonos += $monto; }
            }
        }
        close($fh);
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
            if ($is_admin || $f[1] eq $id_medico) {
                # Comparación de fecha
                my ($cy, $cm, $cd) = split(/-/, $f[3]);
                if ($cy && $cm && $cd) {
                    my $time_cita = timelocal(0,0,0,$cd,$cm-1,$cy-1900);
                    if ($time_cita >= $time_today && $time_cita <= $time_limit) {
                        $citas_hoy_count++ if $f[3] eq $hoy_str;
                        my $p_name = $pacientes_map{$f[2]} || "Paciente #$f[2]";
                        push @proximas_citas, { 
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
    my $val_cargos_f = $total_cargos / 1000;
    my $val_abonos_f = $total_abonos / 1000;

    # Homogenización de Etiquetas
    my $tit_modulos = "M&oacute;dulos de Gesti&oacute;n";
    my $tit_citas   = "Pr&oacute;ximas citas";

    print <<HTML;
    <script>
    function animateValue(obj, start, end, duration, isK) {
        let startTimestamp = null;
        const step = (timestamp) => {
            if (!startTimestamp) startTimestamp = timestamp;
            const progress = Math.min((timestamp - startTimestamp) / duration, 1);
            const current = progress * (end - start) + start;
            if (isK) {
                obj.textContent = "\$ " + current.toFixed(2) + "k";
            } else {
                obj.textContent = Math.floor(current).toLocaleString();
            }
            if (progress < 1) {
                window.requestAnimationFrame(step);
            }
        };
        window.requestAnimationFrame(step);
    }
    document.addEventListener("DOMContentLoaded", function() {
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
    });
    </script>
<style>
    /* MedentIA Bento Dashboard v1.0 (Diamond Armor Style) */
    .dash-kpi-card { 
        background: white; 
        border-radius: var(--radius-lg); 
        padding: 1.5rem; 
        border: 2px solid #19B7A5; 
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
        border: 2px solid #19B7A5;
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

<div class="animate-fade-in py-2">

    <!-- =======================================================================
         DASHBOARD MOBILE (v3.6.0 PREMIUM REFACTORED)
         ======================================================================= -->
    <div class="app-container d-md-none">
        
        <!-- Sección: KPIs Rápidos (MedentIA Edition) -->
        <div class="row g-3 mb-4">
            <div class="col-6">
                <div class="dash-kpi-card bg-med-blue h-100">
                    <span class="kpi-label-medentia">Citas Hoy</span>
                    <div class="d-flex align-items-center justify-content-between">
                        <h2 class="kpi-value-medentia counter-up m-0" data-value="$citas_hoy_count">$citas_hoy_count</h2>
                        <i class="bi bi-calendar-check text-primary fs-2"></i>
                    </div>
                </div>
            </div>
            <div class="col-6">
                <div class="dash-kpi-card bg-med-teal h-100">
                    <span class="kpi-label-medentia">Pacientes</span>
                    <div class="d-flex align-items-center justify-content-between">
                        <h2 class="kpi-value-medentia counter-up m-0" data-value="$t_pac">$t_pac</h2>
                        <i class="bi bi-people text-teal-clinical fs-2" style="color: var(--md-teal-clinical);"></i>
                    </div>
                </div>
            </div>
            <div class="col-6">
                <div class="dash-kpi-card bg-med-cyan h-100">
                    <span class="kpi-label-medentia">Cargos</span>
                    <div class="d-flex align-items-center justify-content-between">
                        <h2 class="kpi-value-medentia counter-up m-0" data-value="$val_cargos_f" data-is-k="true">$str_cargos_k</h2>
                        <i class="bi bi-wallet2 text-cyan fs-2"></i>
                    </div>
                </div>
            </div>
            <div class="col-6">
                <div class="dash-kpi-card bg-med-deep h-100">
                    <span class="kpi-label-medentia">Abonos</span>
                    <div class="d-flex align-items-center justify-content-between">
                        <h2 class="kpi-value-medentia counter-up m-0" data-value="$val_abonos_f" data-is-k="true">$str_abonos_k</h2>
                        <i class="bi bi-cash-stack text-blue-deep fs-2" style="color: var(--md-blue-deep);"></i>
                    </div>
                </div>
            </div>
        </div>

        <!-- Sección: Módulos de Gestión -->
        <section class="management-grid" aria-labelledby="mgmt-title">
            <h2 id="mgmt-title" class="section-title-v2 mb-3">$tit_modulos</h2>
            <div class="grid-container">
HTML


    # Icon Mapping for Material Icons with Colors (Jerarquía Visual)
    my %module_styles = (
        'agenda'      => { icon => 'calendar_month', bg => 'var(--calendar-bg)', color => 'var(--calendar-event)' },
        'pacientes'   => { icon => 'groups',         bg => 'var(--surface-secondary)', color => 'var(--icon-purple)' },
        'finanzas'    => { icon => 'payments',       bg => 'var(--surface-info)', color => 'var(--income)' },
        'clinicas'    => { icon => 'domain',         bg => 'var(--surface-blue)', color => 'var(--primary-blue)' },
        'usuarios'    => { icon => 'person_add',     bg => 'var(--surface-secondary)', color => 'var(--icon-purple)' },
        'reportes'    => { icon => 'analytics',      bg => 'var(--surface-info)', color => 'var(--confirmation)' },
        'tecnico'     => { icon => 'build',          bg => 'var(--surface-warn)', color => 'var(--alert)' },
        'sync_google' => { icon => 'sync',           bg => 'var(--calendar-bg)', color => 'var(--calendar-event)' },
        'mis_citas'   => { icon => 'event_note',     bg => 'var(--surface-blue)', color => 'var(--primary-blue)' },
        'mi_historial'=> { icon => 'history_edu',    bg => 'var(--surface-secondary)', color => 'var(--icon-purple)' }
    );

    foreach my $mod_key (@allowed_modules) {
        $mod_key =~ s/^\s+|\s+$//g;
        next unless $menu_registry{$mod_key};
        my $m = $menu_registry{$mod_key};
        my $u = $m->{url} || '#';
        my $href = ($u =~ /^#|sync_google_handler/) ? "#" : "../$u";
        my $onclick = ($u eq 'sync_google_handler.pl') ? "onclick='iniciarVinculacionGoogle(); return false;'" : "";
        
        my $style = $module_styles{$mod_key} || { icon => 'grid_view', bg => 'var(--surface-blue)', color => 'var(--primary-blue)' };

        print qq{
            <a href="$href" $onclick class="mgmt-card">
                <div class="icon-wrapper" style="background: $style->{bg}; color: $style->{color};">
                    <span class="material-icons">$style->{icon}</span>
                </div>
                <div class="card-content">
                    <h3>$m->{title}</h3>
                    <p>$m->{desc}</p>
                </div>
                <div class="action-btn">
                    <span class="material-icons">chevron_right</span>
                </div>
            </a>
        };
    }


    print <<HTML;
            </div>
        </section>

        <!-- Sección: Próximas Citas con Timeline -->
        <section class="appointments-section" aria-labelledby="appt-title">
            <header class="section-header">
                <h2 id="appt-title">$tit_citas</h2>
                <a href="../views/agenda_main.pl" class="text-link" style="text-decoration:none;">Ver Agenda</a>
            </header>

            <div class="timeline-container">
HTML


    if (@proximas_citas == 0) {
        print qq{<div class="bg-white rounded-4 p-4 text-center border shadow-sm"><p class="text-muted small fw-bold m-0">Sin citas en los pr&oacute;ximos 7 d&iacute;as.</p></div>};
    } else {
        # Agrupar por fecha
        my %citas_por_fecha = ();
        my @fechas_ordenadas = ();
        foreach my $c (@proximas_citas) {
            if (!$citas_por_fecha{$c->{fecha}}) {
                push @fechas_ordenadas, $c->{fecha};
            }
            push @{$citas_por_fecha{$c->{fecha}}}, $c;
        }

        foreach my $fecha (@fechas_ordenadas) {
            my $display_date = ($fecha eq $hoy_str) ? 'Hoy' : $fecha;
            # Formatear fecha legible si no es hoy
            if ($display_date ne 'Hoy') {
                my ($y, $m, $d) = split(/-/, $fecha);
                my @meses = (qw(Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic));
                $display_date = "$d " . ($meses[$m-1] || "");
            }

            print qq{
                <div class="day-group">
                    <div class="date-header">
                        <span class="dot-indicator"></span>
                        <time datetime="$fecha">$display_date</time>
                    </div>
                    <ul class="appointment-list">
            };

            foreach my $c (@{$citas_por_fecha{$fecha}}) {
                my $hora_limpia = $c->{hora};
                my ($h, $m) = split(/:/, $hora_limpia);
                my $ampm = ($h >= 12) ? 'PM' : 'AM'; $h = $h % 12; $h = 12 if $h == 0;
                my $hora_fm = sprintf("%02d:%02d %s", $h, $m, $ampm);
                my $badge_text = $c->{estado} || 'Pendiente';

                print qq{
                    <li class="appointment-item">
                        <div class="time-slot">
                            <span class="time"><span class="material-icons" style="font-size:1.1rem; color:#6C67C0;">schedule</span> $hora_fm</span>
                            <span class="badge confirmed">$badge_text</span>
                        </div>
                        <div class="patient-info">
                            <h4>$c->{nombre_paciente}</h4>
                            <p>$c->{motivo} • Consultorio Principal</p>
                        </div>
                        <button class="details-link" onclick="window.location.href='../views/agenda_main.pl'">
                            Ver detalle <span class="material-icons" style="font-size:1rem;">chevron_right</span>
                        </button>
                    </li>
                };
            }

            print "</ul></div>";
        }
    }


    print <<HTML;
            </div>
        </section>
        
        <button class="fab-btn-v2 pulse-fab" onclick="window.location.href='../views/render_consultas.pl'" title="Consulta">
            <span class="material-icons">medical_services</span>
        </button>
    </div>

    <!-- =======================================================================
         DASHBOARD DESKTOP
         ======================================================================= -->
    <div class="dash-container-desktop d-none d-md-block">
        <script>
        function iniciarVinculacionGoogle() {
            const clientId = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
            const idMed = "$id_medico"; 
            const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=\${clientId}&redirect_uri=https://sdm.pdigitalesm.com/auth/oauth_callback.pl&response_type=code&scope=https://www.googleapis.com/auth/calendar.events&access_type=offline&prompt=consent&state=\${idMed}`;
            window.open(authUrl, 'GoogleAuth', 'width=600,height=700');
        }
        </script>

        <div class="row g-4 mb-5 animate__animated animate__fadeIn">
            <div class="col-sm-6 col-lg-3">
                <div class="dash-kpi-card bg-med-blue h-100">
                    <span class="kpi-label-medentia">Citas Hoy</span>
                    <div class="d-flex align-items-center justify-content-between">
                        <h2 class="kpi-value-medentia counter-up m-0" data-value="$citas_hoy_count">$citas_hoy_count</h2>
                        <i class="bi bi-calendar-check text-primary fs-2"></i>
                    </div>
                </div>
            </div>
            <div class="col-sm-6 col-lg-3">
                <div class="dash-kpi-card bg-med-teal h-100">
                    <span class="kpi-label-medentia">Pacientes Registrados</span>
                    <div class="d-flex align-items-center justify-content-between">
                        <h2 class="kpi-value-medentia counter-up m-0" data-value="$t_pac">$t_pac</h2>
                        <i class="bi bi-people text-teal-clinical fs-2" style="color: var(--md-teal-clinical);"></i>
                    </div>
                </div>
            </div>
            <div class="col-sm-6 col-lg-3">
                <div class="dash-kpi-card bg-med-cyan h-100">
                    <span class="kpi-label-medentia">Cargos del Mes</span>
                    <div class="d-flex align-items-center justify-content-between">
                        <h2 class="kpi-value-medentia counter-up m-0" data-value="$val_cargos_f" data-is-k="true">$str_cargos_k</h2>
                        <i class="bi bi-wallet2 text-cyan fs-2"></i>
                    </div>
                </div>
            </div>
            <div class="col-sm-6 col-lg-3">
                <div class="dash-kpi-card bg-med-deep h-100">
                    <span class="kpi-label-medentia">Abonos Recibidos</span>
                    <div class="d-flex align-items-center justify-content-between">
                        <h2 class="kpi-value-medentia counter-up m-0" data-value="$val_abonos_f" data-is-k="true">$str_abonos_k</h2>
                        <i class="bi bi-cash-stack text-blue-deep fs-2" style="color: var(--md-blue-deep);"></i>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-4">
            <div class="col-lg-8">
                <h5 class="plus-jakarta fw-black mb-4">$tit_modulos</h5>
                <div class="row g-3">
HTML


    foreach my $mod_key (@allowed_modules) {
        $mod_key =~ s/^\s+|\s+$//g;
        next unless $menu_registry{$mod_key};
        my $m = $menu_registry{$mod_key};
        my $u = $m->{url} || '#';
        my $href = ($u =~ /^#|sync_google_handler/) ? "#" : "../$u";
        my $onclick = ($u eq 'sync_google_handler.pl') ? "onclick='iniciarVinculacionGoogle(); return false;'" : "";
        
        my $style = $module_styles{$mod_key} || { icon => 'grid_view', bg => 'var(--surface-blue)', color => 'var(--primary-blue)' };

        print qq{
            <div class="col-md-6">
                <a href="$href" $onclick class="cs-action-card interactive-scale" style="display:flex; align-items:center; gap:1rem; padding:1.25rem; background:white; border-radius:1.25rem; border:2px solid #19B7A5; text-decoration:none; transition:0.3s; margin-bottom:1rem;">
                    <div style="width:45px; height:45px; border-radius:12px; display:flex; align-items:center; justify-content:center; font-size:1.25rem; background: $style->{bg}; color: $style->{color};"><span class="material-icons" style="font-size:1.4rem;">$style->{icon}</span></div>
                    <div><span class="d-block fw-bold text-dark">$m->{title}</span><small class="text-muted">$m->{desc}</small></div>
                </a>
            </div>};
    }


    print <<HTML;
                </div>
            </div>
            <div class="col-lg-4">
                <h5 class="plus-jakarta fw-black mb-4">$tit_citas</h5>
                <div class="bg-white rounded-4 p-3" style="border: 2px solid #19B7A5; min-height:350px">
HTML


    if (@proximas_citas == 0) {
        print '<div class="text-center py-5"><p class="text-muted small fw-bold">Sin actividad programada.</p></div>';
    } else {
        foreach my $cita (@proximas_citas) {
            my $bCol = ($cita->{estado} =~ /Confirmada/i) ? 'bg-success-subtle text-success' : 'bg-primary-subtle text-primary';
            my $date_label = ($cita->{fecha} eq $hoy_str) ? 'Hoy' : substr($cita->{fecha}, 5);
            print qq{
                <div class="d-flex align-items-center justify-content-between p-3 bg-white rounded-4 mb-3 shadow-sm interactive-scale" style="border: 1px solid rgba(25, 183, 165, 0.4);">
                    <div style="flex-grow:1">
                        <span class="d-block fw-bold text-navy mb-1" style="font-size:0.85rem;">$cita->{nombre_paciente}</span>
                        <div class="d-flex gap-2 align-items-center"><span class="badge bg-light text-muted" style="font-size:0.6rem;">$date_label</span><small class="text-muted fw-semibold" style="font-size:0.7rem;"><i class="bi bi-clock me-1"></i>$cita->{hora}</small></div>
                    </div>
                    <div class="text-end"><span class="badge $bCol rounded-pill border-0 px-3 py-2 fw-bold" style="font-size:0.6rem;">$cita->{estado}</span></div>
                </div>};
        }
    }


    print <<HTML;
                </div>
            </div>
        </div>
    </div>
</div>
HTML
}
1;