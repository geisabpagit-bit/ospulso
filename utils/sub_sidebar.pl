package utils::sub_sidebar;

use strict;
use warnings;
use utf8;
use File::Spec;
use FindBin;
use Exporter 'import';

our @EXPORT_OK = qw(render_sidebar render_sidebar_footer);

sub render_sidebar {
    my %args = @_;
    my $usuario       = $args{usuario} || 'Usuario';
    my $role          = $args{role} || 'Visitante';
    my $id_medico     = $args{id_medico} || '';
    my $pagina_actual = $args{pagina_actual} || ''; # 'dashboard', 'pacientes', 'agenda', etc.

    my $iniciales = '';
    my @nombres = split(/\s+/, $usuario);
    $iniciales .= uc(substr($nombres[0], 0, 1)) if @nombres > 0;
    $iniciales .= uc(substr($nombres[1], 0, 1)) if @nombres > 1;

    # Rutas de datos
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $menu_file  = File::Spec->catfile($dat_dir, 'menu_cards.dat');
    my $roles_file = File::Spec->catfile($dat_dir, 'roles.dat');

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
                @allowed_modules = @f[2..$#f];
                last;
            }
        }
        close($rf);
    }

    # --- CONTROL DINÁMICO DE CAPACIDADES SAAS POR ORGANIZACIÓN ---
    my $id_empresa = 0;
    eval {
        my $sd = main::check_session();
        $id_empresa = $sd->{id_empresa} || 0;
    };

    if ($id_empresa && $role ne 'Administrador Global') {
        my %capacidades = ();
        my $config_file = File::Spec->catfile($dat_dir, 'negocios_config.dat');
        if (-e $config_file) {
            if (open(my $cf, '<:utf8', $config_file)) {
                while (my $line = <$cf>) {
                    chomp($line);
                    next if $line =~ /^#|^\s*$/;
                    my ($biz_id, $key, $val) = split(/\|/, $line);
                    if ($biz_id eq $id_empresa && $key eq 'CAPACIDAD') {
                        $capacidades{$val} = 1;
                    }
                }
                close($cf);
            }
        }

        # Si tenemos capacidades configuradas, filtramos
        if (keys %capacidades) {
            my %modulo_capacidad = (
                'agenda'    => 'Agenda',
                'pacientes' => 'Expediente Clínico',
                'finanzas'  => 'Facturación',
                'reportes'  => 'Facturación',
                'productos' => 'Inventario',
                'servicios' => 'Facturación',
            );

            my @filtered_modules = ();
            foreach my $mod (@allowed_modules) {
                my $trimmed_mod = $mod;
                $trimmed_mod =~ s/^\s+|\s+$//g;
                if (exists $modulo_capacidad{$trimmed_mod}) {
                    # --- REGLA DE BYPASS DE CAPACIDADES ---
                    # 1. 'pacientes' siempre visible para Administrador Organizacion y Medico
                    if ($trimmed_mod eq 'pacientes' && ($role eq 'Administrador Organizacion' || $role eq 'Medico')) {
                        push @filtered_modules, $mod;
                        next;
                    }
                    # 2. 'servicios' y 'productos' siempre visibles para Administrador Organizacion
                    if ($role eq 'Administrador Organizacion' && ($trimmed_mod eq 'servicios' || $trimmed_mod eq 'productos')) {
                        push @filtered_modules, $mod;
                        next;
                    }
                    # 3. 'finanzas' y 'reportes' siempre visibles para Administrador Organizacion, Medico y Recepcionista
                    if (($trimmed_mod eq 'finanzas' || $trimmed_mod eq 'reportes') && 
                        ($role eq 'Administrador Organizacion' || $role eq 'Medico' || $role eq 'Recepcionista')) {
                        push @filtered_modules, $mod;
                        next;
                    }

                    my $required_cap = $modulo_capacidad{$trimmed_mod};
                    if ($capacidades{$required_cap}) {
                        push @filtered_modules, $mod;
                    }
                } else {
                    push @filtered_modules, $mod; # Módulos core sin restricción (ej: clinicas, usuarios)
                }
            }
            @allowed_modules = @filtered_modules;
        }
    }

    my %module_styles = (
        'agenda'      => { icon => 'calendar_month', bg => 'var(--calendar-bg)', color => 'var(--calendar-event)' },
        'pacientes'   => { icon => 'groups',         bg => 'var(--surface-secondary)', color => 'var(--icon-purple)' },
        'finanzas'    => { icon => 'payments',       bg => 'var(--surface-info)', color => 'var(--income)' },
        'clinicas'    => { icon => 'domain',         bg => 'var(--surface-blue)', color => 'var(--primary-blue)' },
        'usuarios'    => { icon => 'person_add',     bg => 'var(--surface-secondary)', color => 'var(--icon-purple)' },
        'servicios'   => { icon => 'medical_services',bg => 'var(--surface-info)', color => 'var(--confirmation)' },
        'productos'   => { icon => 'inventory_2',    bg => 'var(--surface-warn)', color => 'var(--alert)' },
        'reportes'    => { icon => 'analytics',      bg => 'var(--surface-info)', color => 'var(--confirmation)' },
        'tecnico'     => { icon => 'build',          bg => 'var(--surface-warn)', color => 'var(--alert)' },
        'sync_google' => { icon => 'sync',           bg => 'var(--calendar-bg)', color => 'var(--calendar-event)' },
        'mis_citas'   => { icon => 'event_note',     bg => 'var(--surface-blue)', color => 'var(--primary-blue)' },
        'mi_historial'=> { icon => 'history_edu',    bg => 'var(--surface-secondary)', color => 'var(--icon-purple)' }
    );

    # The Google Auth script needs to know the correct base URL
    # So we use standard relative paths since this is called from views/
    
    print <<HTML;
<link rel="stylesheet" href="../css/sub_sidebar.css?v=$^T">
<script src="../js/spa_router.js?v=$^T" defer></script>
<script src="../js/sub_sidebar.js?v=$^T" defer></script>

<div class="sdm-layout-wrapper animate__animated animate__fadeIn">
    <!-- Sidebar Left -->
    <nav class="diamond-sidebar" id="moduleSidebar">
        <div class="sidebar-brand">
            <div class="avatar-diamond">$iniciales</div>

            <button class="btn btn-light rounded-circle p-2 shadow-sm d-lg-none ms-auto" onclick="toggleSidebar()"><i class="bi bi-x-lg"></i></button>
            <button class="btn-sidebar-toggle d-none d-lg-flex ms-auto" onclick="toggleDesktopSidebar()"><i class="bi bi-layout-sidebar text-muted"></i></button>
        </div>

        <div class="sidebar-menu accordion accordion-flush flex-grow-1 mt-3 px-2" id="accordionSidebar">
HTML
    

    my %is_allowed = ();
    foreach my $mod (@allowed_modules) {
        my $trimmed = $mod;
        $trimmed =~ s/^\s+|\s+$//g;
        $is_allowed{$trimmed} = 1;
    }

    # 1. Dashboard
    my $dash_active = ($pagina_actual eq 'dashboard') ? 'active' : '';
    print qq{
            <a href="inicial.pl" class="sub-link $dash_active w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                <i class="bi bi-grid-1x2-fill text-primary me-2" style="font-size:1.2rem;"></i> <span class="sidebar-text">Dashboard</span>
            </a>
    };

    # 2. Administración Accordion (Gestion de Clínicas, Personal, Servicios, Productos)
    my $show_admin = 0;
    if ($is_allowed{clinicas} || $is_allowed{usuarios} || $is_allowed{servicios} || $is_allowed{productos}) {
        $show_admin = 1;
    }

    if ($show_admin) {
        my $admin_active = ($pagina_actual eq 'clinicas' || $pagina_actual eq 'usuarios' || $pagina_actual eq 'servicios' || $pagina_actual eq 'productos') ? 'show' : '';
        my $collapsed_class = ($admin_active eq 'show') ? '' : 'collapsed';
        
        print qq{
            <!-- Administración Accordion -->
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-administracion">
                    <button class="accordion-button $collapsed_class" type="button" data-bs-toggle="collapse" data-bs-target="#c-administracion" aria-expanded="false" aria-controls="c-administracion">
                        <i class="bi bi-shield-lock-fill text-primary" style="font-size:1.2rem; color: var(--md-teal-clinical) !important;"></i> <span class="sidebar-text ms-2">Administraci&oacute;n</span>
                    </button>
                </h2>
                <div id="c-administracion" class="accordion-collapse collapse $admin_active" aria-labelledby="h-administracion" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body pb-0 pt-1">
        };
        
        my %admin_mod_names = (
            'clinicas'  => { file => 'manage_clinicas.pl', icon => 'bi-building-gear', title => 'Gesti&oacute;n de Cl&iacute;nicas' },
            'usuarios'  => { file => 'administracion_usuarios.pl', icon => 'bi-people-fill', title => 'Gesti&oacute;n de Personal' },
            'servicios' => { file => 'manage_servicios.pl', icon => 'bi-heart-pulse-fill', title => 'Gesti&oacute;n de Servicios' },
            'productos' => { file => 'manage_productos.pl', icon => 'bi-box-seam-fill', title => 'Gesti&oacute;n de Productos' }
        );
        
        foreach my $k ('clinicas', 'usuarios', 'servicios', 'productos') {
            if ($is_allowed{$k}) {
                my $active_sub = ($pagina_actual eq $k) ? 'active' : '';
                my $cfg = $admin_mod_names{$k};
                print qq{
                    <a href="../views/$cfg->{file}" class="sub-link $active_sub w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                        <i class="bi $cfg->{icon} me-2 text-muted" style="font-size:1.1rem;"></i> <span class="sidebar-text">$cfg->{title}</span>
                    </a>
                };
            }
        }
        
        print qq{
                    </div>
                </div>
            </div>
        };
    }

    # Separador después de Administración
    if ($show_admin) {
        print qq{<hr class="my-2 opacity-25 sidebar-separator">};
    }

    # 3. Pacientes (Flat Link)
    if ($is_allowed{pacientes}) {
        my $m = $menu_registry{pacientes};
        my $style = $module_styles{pacientes};
        my $active_class = ($pagina_actual eq 'pacientes') ? 'active' : '';
        print qq{
            <a href="../$m->{url}" class="sub-link $active_class w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                <span class="material-icons me-2" style="color: $style->{color}; font-size:1.2rem;">$style->{icon}</span> <span class="sidebar-text">$m->{title}</span>
            </a>
        };
    }

    # 4. Agenda Dinámica (Flat Link)
    if ($is_allowed{agenda}) {
        my $m = $menu_registry{agenda};
        my $style = $module_styles{agenda};
        my $active_class = ($pagina_actual eq 'agenda') ? 'active' : '';
        print qq{
            <a href="../$m->{url}" class="sub-link $active_class w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                <span class="material-icons me-2" style="color: $style->{color}; font-size:1.2rem;">$style->{icon}</span> <span class="sidebar-text">$m->{title}</span>
            </a>
        };
        
        # Ajustes de Agenda eliminado

    }

    # Separador después de Pacientes / Agenda Dinámica
    if ($is_allowed{pacientes} || $is_allowed{agenda}) {
        print qq{<hr class="my-2 opacity-25 sidebar-separator">};
    }

    # Menú del Expediente Clínico (Solo se muestra cuando pagina_actual es 'expediente')
    if ($pagina_actual eq 'expediente') {
        print qq{
            <!-- 1. Atención Clínica -->
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-clinica">
                    <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#c-clinica" aria-expanded="false" aria-controls="c-clinica">
                        <i class="bi bi-heart-pulse-fill text-danger" style="font-size: 1.1rem;"></i><span class="sidebar-text ms-2">Atenci&oacute;n Cl&iacute;nica</span>
                    </button>
                </h2>
                <div id="c-clinica" class="accordion-collapse collapse" aria-labelledby="h-clinica" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body pb-0 pt-1">
                        <button class="sub-link active w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab0', this)"><i class="bi bi-calendar3 text-muted me-2"></i><span class="sidebar-text">1.1 Citas</span></button>
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab10', this)"><i class="bi bi-activity text-muted me-2"></i><span class="sidebar-text">1.2 Consultas</span></button>
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab3', this)"><i class="bi bi-person-gear text-muted me-2"></i><span class="sidebar-text">1.3 Ficha Paciente</span></button>
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab2', this)"><i class="bi bi-grid-1x2 text-muted me-2"></i><span class="sidebar-text">1.4 Dashboard</span></button>
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab4', this)"><i class="bi bi-journal-text text-muted me-2"></i><span class="sidebar-text">1.5 SOAP</span></button>
                    </div>
                </div>
            </div>

            <!-- 2. Diagnóstico -->
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-diag">
                    <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#c-diag" aria-expanded="false" aria-controls="c-diag">
                        <i class="bi bi-search text-primary" style="font-size: 1.1rem;"></i><span class="sidebar-text ms-2">Diagn&oacute;stico</span>
                    </button>
                </h2>
                <div id="c-diag" class="accordion-collapse collapse" aria-labelledby="h-diag" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body pb-0 pt-1">
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab6', this)"><i class="bi bi-diagram-3-fill text-muted me-2"></i><span class="sidebar-text">2.1 Odonto</span></button>
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab7', this)"><i class="bi bi-camera-video-fill text-muted me-2"></i><span class="sidebar-text">2.2 Rayos X</span></button>
                    </div>
                </div>
            </div>

            <!-- 3. Administración (Expediente) -->
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-admin-exp">
                    <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#c-admin-exp" aria-expanded="false" aria-controls="c-admin-exp">
                        <i class="bi bi-briefcase-fill text-success" style="font-size: 1.1rem;"></i><span class="sidebar-text ms-2">Administraci&oacute;n</span>
                    </button>
                </h2>
                <div id="c-admin-exp" class="accordion-collapse collapse" aria-labelledby="h-admin-exp" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body pb-0 pt-1">
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab1', this)"><i class="bi bi-wallet2 text-muted me-2"></i><span class="sidebar-text">3.1 Finanzas</span></button>
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab5', this)"><i class="bi bi-inbox text-muted me-2"></i><span class="sidebar-text">3.2 Inbox</span></button>
                    </div>
                </div>
            </div>

            <!-- 4. Interoperabilidad -->
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-inter">
                    <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#c-inter" aria-expanded="false" aria-controls="c-inter">
                        <i class="bi bi-share-fill text-info" style="font-size: 1.1rem;"></i><span class="sidebar-text ms-2">Interoperabilidad</span>
                    </button>
                </h2>
                <div id="c-inter" class="accordion-collapse collapse" aria-labelledby="h-inter" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body pb-0 pt-1">
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab8', this)"><i class="bi bi-braces text-muted me-2"></i><span class="sidebar-text">4.1 FHIR</span></button>
                        <button class="sub-link w-100 text-start border-0 bg-transparent mb-1 d-flex align-items-center" onclick="swTab('tab9', this)"><i class="bi bi-pci-card text-muted me-2"></i><span class="sidebar-text">4.2 HL7</span></button>
                    </div>
                </div>
            </div>
            
            <hr class="my-2 opacity-25 sidebar-separator">
        };
    }

    # 5. Finanzas Accordion
    if ($is_allowed{finanzas}) {
        my $fin_active = ($pagina_actual eq 'finanzas') ? 'show' : '';
        my $collapsed_class = ($fin_active eq 'show') ? '' : 'collapsed';
        
        print qq{
            <!-- Finanzas Integradas -->
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-finanzas">
                    <button class="accordion-button $collapsed_class" type="button" data-bs-toggle="collapse" data-bs-target="#c-finanzas" aria-expanded="false" aria-controls="c-finanzas">
                        <i class="bi bi-cash-stack text-success" style="color: var(--md-teal-clinical) !important;"></i> <span class="sidebar-text ms-2">Finanzas</span>
                    </button>
                </h2>
                <div id="c-finanzas" class="accordion-collapse collapse $fin_active" aria-labelledby="h-finanzas" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body pb-0 pt-1">
                        <a href="../views/finanzas.pl?tab=resumen" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1"><i class="bi bi-pie-chart-fill text-muted me-2"></i><span class="sidebar-text">Resumen General</span></a>
                        <a href="../views/finanzas.pl?tab=ingresos" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1"><i class="bi bi-arrow-down-circle-fill text-success me-2"></i><span class="sidebar-text">Ingresos</span></a>
                        <a href="../views/finanzas.pl?tab=gastos" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1"><i class="bi bi-arrow-up-circle-fill text-danger me-2"></i><span class="sidebar-text">Gastos (Egresos)</span></a>
                        <a href="../views/finanzas.pl?tab=cxc" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1"><i class="bi bi-exclamation-triangle-fill text-warning me-2"></i><span class="sidebar-text">Cuentas por Cobrar</span></a>
                        <hr class="my-2 opacity-25">
                        <a href="../views/finanzas.pl?tab=facturacion" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1"><i class="bi bi-receipt text-muted me-2"></i><span class="sidebar-text">Facturaci&oacute;n PAC</span></a>
                        <a href="../views/finanzas.pl?tab=reportes" class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1"><i class="bi bi-file-earmark-bar-graph-fill text-muted me-2"></i><span class="sidebar-text">Reportes (P&L)</span></a>
                    </div>
                </div>
            </div>
        };

        # Separador después de Finanzas
        print qq{<hr class="my-2 opacity-25 sidebar-separator">};
    }

    # 6. Ventas Accordion (Ejecutivo Ventas o Administrador Global)
    if ( ($is_allowed{crm_ventas} && $role eq 'Ejecutivo Ventas') || ($is_allowed{admin_global} && $role eq 'Administrador Global') ) {
        my $ventas_active = ($pagina_actual eq 'crm_ventas' || $pagina_actual eq 'admin_ejecutivos') ? 'show' : '';
        my $collapsed_class = ($ventas_active eq 'show') ? '' : 'collapsed';
        
        my $crm_html = '';
        if ($role eq 'Ejecutivo Ventas') {
            my $crm_active = ($pagina_actual eq 'crm_ventas') ? 'active' : '';
            $crm_html = qq{
                <a href="../views/crm_ventas.pl" class="sub-link $crm_active w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                    <i class="bi bi-shop me-2 text-primary" style="font-size:1.1rem;"></i> <span class="sidebar-text">CRM Ventas</span>
                </a>
            };
        }
        my $ejec_html = '';
        if ($role eq 'Administrador Global') {
            my $ejec_active = ($pagina_actual eq 'admin_ejecutivos') ? 'active' : '';
            $ejec_html = qq{
                <a href="../views/admin_ejecutivos.pl" class="sub-link $ejec_active w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                    <i class="bi bi-people-fill me-2 text-primary" style="font-size:1.1rem;"></i> <span class="sidebar-text">Ejecutivos</span>
                </a>
            };
        }
        
        print qq{
            <div class="accordion-item bg-transparent border-0 mb-1">
                <h2 class="accordion-header" id="h-ventas">
                    <button class="accordion-button $collapsed_class" type="button" data-bs-toggle="collapse" data-bs-target="#c-ventas" aria-expanded="false" aria-controls="c-ventas">
                        <i class="material-icons text-primary" style="font-size:1.2rem;">briefcase</i> <span class="sidebar-text ms-2">Ventas</span>
                    </button>
                </h2>
                <div id="c-ventas" class="accordion-collapse collapse $ventas_active" aria-labelledby="h-ventas" data-bs-parent="#accordionSidebar">
                    <div class="accordion-body pb-0 pt-1">
                        $crm_html
                        $ejec_html
                    </div>
                </div>
            </div>
            <hr class="my-2 opacity-25 sidebar-separator">
        };
    }

    # 7. Cualquier otro módulo permitido plano que no hayamos dibujado aún (ej: tecnico, sync_google, etc.)
    my %grouped_or_drawn = (
        'clinicas'   => 1,
        'usuarios'   => 1,
        'servicios'  => 1,
        'productos'  => 1,
        'pacientes'  => 1,
        'agenda'     => 1,
        'finanzas'   => 1,
        'crm_ventas' => 1
    );
    if ($role eq 'Administrador Organizacion') {
        $grouped_or_drawn{'reportes'} = 1;
    }

    foreach my $mod_key (keys %is_allowed) {
        next if $grouped_or_drawn{$mod_key};
        next unless $menu_registry{$mod_key};
        my $m = $menu_registry{$mod_key};
        my $u = $m->{url} || '#';
        my $href = ($u =~ /^#|sync_google_handler/) ? "#" : "../$u";
        my $onclick = ($u eq 'sync_google_handler.pl') ? "onclick=\"iniciarVinculacionGoogle('$id_medico'); return false;\"" : "";
        
        my $style = $module_styles{$mod_key} || { icon => 'grid_view', bg => 'var(--surface-blue)', color => 'var(--primary-blue)' };
        my $active_class = ($pagina_actual eq $mod_key) ? 'active' : '';

        print qq{
            <a href="$href" $onclick class="sub-link $active_class w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                <span class="material-icons me-2" style="color: $style->{color}; font-size:1.2rem;">$style->{icon}</span> <span class="sidebar-text">$m->{title}</span>
            </a>
        };
    }

    print <<HTML;
        </div>
    </nav>

    <!-- Overlay para cerrar el menú en móvil -->
    <div class="sidebar-overlay" id="sidebarOverlay" onclick="toggleSidebar()"></div>

    <!-- Main Content -->
    <div class="sdm-main-content">
        <!-- Header Compacto -->
        <div class="diamond-header-compact d-lg-none d-flex justify-content-between align-items-center border-0 shadow-none pt-3 pb-0" style="background: transparent !important;">
            <div class="d-flex align-items-center gap-3">
                <button class="btn btn-menu-toggle-inline" onclick="toggleSidebar()">
                    <i class="bi bi-list"></i>
                </button>

            </div>
        </div>

        <div class="sdm-content mt-2 mt-lg-0">
HTML
}

sub render_sidebar_footer {
    print <<HTML;
        </div> <!-- Fin de sdm-content -->
    </div> <!-- Fin de sdm-main-content -->
</div> <!-- Fin de sdm-layout-wrapper -->
HTML
}

1;
