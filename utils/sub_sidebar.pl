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
<link rel="stylesheet" href="../css/expediente_completo.css?v=$^T">
<script src="../js/spa_router.js?v=$^T" defer></script>
<script>
    function toggleSidebar() {
        const sidebar = document.getElementById('moduleSidebar');
        const overlay = document.getElementById('sidebarOverlay');
        if (sidebar) sidebar.classList.toggle('show');
        if (overlay) overlay.classList.toggle('show');
    }
    function toggleDesktopSidebar() {
        const sidebar = document.getElementById('moduleSidebar');
        if(sidebar) sidebar.classList.toggle('compact');
    }
</script>
<div class="sdm-layout-wrapper animate__animated animate__fadeIn">
    <!-- Sidebar Left -->
    <nav class="diamond-sidebar" id="moduleSidebar">
        <div class="sidebar-brand">
            <div class="avatar-diamond d-flex align-items-center justify-content-center" style="width: 45px; height: 45px; font-size: 1.2rem; border-width: 2px;">$iniciales</div>

            <button class="btn btn-light rounded-circle p-2 shadow-sm d-lg-none ms-auto" onclick="toggleSidebar()"><i class="bi bi-x-lg"></i></button>
            <button class="btn-sidebar-toggle d-none d-lg-flex ms-auto" onclick="toggleDesktopSidebar()"><i class="bi bi-layout-sidebar text-muted"></i></button>
        </div>

        <div class="sidebar-menu flex-grow-1 mt-3 px-2">
HTML
    
    my $dash_active = ($pagina_actual eq 'dashboard') ? 'active' : '';
    print qq{
            <a href="inicial.pl" class="sub-link $dash_active w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                <i class="bi bi-grid-1x2-fill text-primary me-2" style="font-size:1.2rem;"></i> <span class="sidebar-text">Dashboard</span>
            </a>
    };

    foreach my $mod_key (@allowed_modules) {
        $mod_key =~ s/^\s+|\s+$//g;
        next if $mod_key eq 'crm_ventas' && $role eq 'Administrador Global';
        next unless $menu_registry{$mod_key};
        my $m = $menu_registry{$mod_key};
        my $u = $m->{url} || '#';
        my $href = ($u =~ /^#|sync_google_handler/) ? "#" : "../$u";
        my $onclick = ($u eq 'sync_google_handler.pl') ? "onclick='iniciarVinculacionGoogle(); return false;'" : "";
        
        my $style = $module_styles{$mod_key} || { icon => 'grid_view', bg => 'var(--surface-blue)', color => 'var(--primary-blue)' };
        my $active_class = ($pagina_actual eq $mod_key) ? 'active' : '';

        print qq{
            <a href="$href" $onclick class="sub-link $active_class w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                <span class="material-icons me-2" style="font-size:1.2rem; color: $style->{color}">$style->{icon}</span> <span class="sidebar-text">$m->{title}</span>
            </a>
        };

        if ($mod_key eq 'agenda') {
            my $ajustes_href = ($pagina_actual eq 'agenda') ? "#" : "../views/agenda_main.pl?open_settings=1";
            my $ajustes_onclick = ($pagina_actual eq 'agenda') ? "onclick='abrirModalAjustes(); return false;'" : "";
            print qq{
                <a href="$ajustes_href" $ajustes_onclick class="sub-link ms-4 text-start text-decoration-none d-flex align-items-center mb-2" style="font-size: 0.85rem; opacity: 0.85;">
                    <i class="bi bi-gear-fill me-2 text-secondary" style="font-size:1rem;"></i> <span class="sidebar-text">Ajustes</span>
                </a>
            };
        }
    }

    # Renderizar módulo colapsable "Ventas" para el Administrador Global
    if ($role eq 'Administrador Global') {
        my $ventas_active = ($pagina_actual eq 'crm_ventas' || $pagina_actual eq 'admin_ejecutivos') ? 'show' : '';
        my $collapsed_class = ($ventas_active eq 'show') ? '' : 'collapsed';
        my $crm_active = ($pagina_actual eq 'crm_ventas') ? 'active' : '';
        my $ejec_active = ($pagina_actual eq 'admin_ejecutivos') ? 'active' : '';
        
        print qq{
            <div class="mb-1">
                <a class="sub-link w-100 text-start text-decoration-none d-flex align-items-center justify-content-between $collapsed_class" 
                   data-bs-toggle="collapse" href="#menuVentas" role="button" aria-expanded="false" style="outline: none;">
                    <span class="d-flex align-items-center">
                        <span class="material-icons me-2" style="font-size:1.2rem; color: var(--primary-blue)">briefcase</span>
                        <span class="sidebar-text fw-bold">Ventas</span>
                    </span>
                    <i class="bi bi-chevron-down small text-muted sidebar-text ms-auto"></i>
                </a>
                <div class="collapse $ventas_active" id="menuVentas">
                    <a href="../views/crm_ventas.pl" class="sub-link $crm_active w-100 text-start text-decoration-none d-flex align-items-center mb-1 ps-4" style="font-size:0.9rem;">
                        <span class="material-icons me-2" style="font-size:1.1rem; color: var(--primary-blue)">store</span> <span class="sidebar-text">CRM Ventas</span>
                    </a>
                    <a href="../views/admin_ejecutivos.pl" class="sub-link $ejec_active w-100 text-start text-decoration-none d-flex align-items-center mb-1 ps-4" style="font-size:0.9rem;">
                        <span class="material-icons me-2" style="font-size:1.1rem; color: var(--primary-blue)">people</span> <span class="sidebar-text">Ejecutivos</span>
                    </a>
                </div>
            </div>
        };
    }

    print <<HTML;
        </div>
        
        <div class="p-3 sidebar-footer">
            <a href="../auth/cerrar_sesion.pl" class="btn btn-danger w-100 rounded-pill fw-bold d-flex justify-content-center align-items-center"><i class="bi bi-box-arrow-right me-2"></i><span class="sidebar-text">Salir</span></a>
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
