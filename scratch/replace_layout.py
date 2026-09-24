import sys

file_path = "c:/xampp/htdocs/ospulso/views/render_dashboard_principal.pl"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Part 1: initials extraction
target_header = """sub render_dashboard_principal {
    my %args = @_;
    my $id_medico = $args{id_medico};
    my $role = $args{role} || 'Visitante';
    my $is_admin = ($role eq 'Administrador') ? 1 : 0;"""

new_header = """sub render_dashboard_principal {
    my %args = @_;
    my $id_medico = $args{id_medico};
    my $role = $args{role} || 'Visitante';
    my $usuario = $args{usuario} || 'Usuario';
    my $is_admin = ($role eq 'Administrador') ? 1 : 0;
    
    my $iniciales = '';
    my @nombres = split(/\\s+/, $usuario);
    $iniciales .= uc(substr($nombres[0], 0, 1)) if @nombres > 0;
    $iniciales .= uc(substr($nombres[1], 0, 1)) if @nombres > 1;"""

content = content.replace(target_header, new_header)

# Part 2: HTML layout replacement
start_str = '<div class="animate-fade-in py-2">'
# Find the exact end string that ends the dashboard layout
# Let's search for "if ($t_pac == 0 && $role eq 'Medico') {"
end_str_marker = "if ($t_pac == 0 && $role eq 'Medico') {"
start_idx = content.find(start_str)
end_idx = content.find(end_str_marker)

# We need to backtrack from end_idx to find the closing HTML and its }
# The structure before end_str_marker is:
#     print <<HTML;
#                 </div>
#             </div>
#         </div>
#         </div>
#     </div>
# </div>
# HTML
#
#     if ($t_pac == 0 && $role eq 'Medico') {

# Let's just find the last "HTML" before end_str_marker
subcontent = content[:end_idx]
html_end_idx = subcontent.rfind("HTML\n")
if html_end_idx != -1:
    end_idx = html_end_idx + 5

new_layout = """<link rel="stylesheet" href="../css/expediente_completo.css?v=$^T">
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
            <div class="sidebar-brand-text lh-1">
                <h5 class="m-0 fw-black text-dark">OSPulso</h5>
                <small class="text-muted fw-bold" style="font-size: 0.6rem;">DIAMOND v3.8.0</small>
            </div>
            <button class="btn btn-light rounded-circle p-2 shadow-sm d-lg-none ms-auto" onclick="toggleSidebar()"><i class="bi bi-x-lg"></i></button>
            <button class="btn-sidebar-toggle d-none d-lg-flex ms-auto" onclick="toggleDesktopSidebar()"><i class="bi bi-layout-sidebar text-muted"></i></button>
        </div>

        <div class="sidebar-menu flex-grow-1 mt-3 px-2">
            <a href="inicial.pl" class="sub-link active w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                <i class="bi bi-grid-1x2-fill text-primary me-2" style="font-size:1.2rem;"></i> Dashboard
            </a>
HTML

    foreach my $mod_key (@allowed_modules) {
        $mod_key =~ s/^\\s+|\\s+$//g;
        next unless $menu_registry{$mod_key};
        my $m = $menu_registry{$mod_key};
        my $u = $m->{url} || '#';
        my $href = ($u =~ /^#|sync_google_handler/) ? "#" : "../$u";
        my $onclick = ($u eq 'sync_google_handler.pl') ? "onclick='iniciarVinculacionGoogle(); return false;'" : "";
        
        my $style = $module_styles{$mod_key} || { icon => 'grid_view', bg => 'var(--surface-blue)', color => 'var(--primary-blue)' };

        print qq{
            <a href="$href" $onclick class="sub-link w-100 text-start text-decoration-none d-flex align-items-center mb-1">
                <span class="material-icons me-2" style="font-size:1.2rem; color: $style->{color}">$style->{icon}</span> $m->{title}
            </a>
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
        <div class="diamond-header-compact d-flex justify-content-between align-items-center">
            <div class="d-flex align-items-center gap-3">
                <button class="btn btn-menu-toggle-inline d-lg-none" onclick="toggleSidebar()">
                    <i class="bi bi-list"></i>
                </button>
                <div class="profile-hero text-start">
                    <h4 class="text-truncate m-0 text-white fw-bold" style="max-width: 60vw; letter-spacing: -0.5px;">Hola, $usuario</h4>
                </div>
            </div>
        </div>

        <div class="sdm-content mt-4">
            <!-- Google Auth Script -->
            <script>
            function iniciarVinculacionGoogle() {
                const clientId = "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com";
                const idMed = "$id_medico"; 
                const redirectUri = encodeURIComponent(window.location.origin + '/auth/oauth_callback.pl');
                const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=\\${clientId}&redirect_uri=\\${redirectUri}&response_type=code&scope=https://www.googleapis.com/auth/calendar.events&access_type=offline&prompt=consent&state=\\${idMed}`;
                window.open(authUrl, 'GoogleAuth', 'width=600,height=700');
            }
            </script>

            <!-- Sección: KPIs Rápidos -->
            <div class="row g-4 mb-4 animate__animated animate__fadeIn">
                <div class="col-6 col-lg-3">
                    <div class="dash-kpi-card bg-med-blue h-100">
                        <span class="kpi-label-medentia">Citas Hoy</span>
                        <div class="d-flex align-items-center justify-content-between">
                            <h2 class="kpi-value-medentia counter-up m-0" data-value="$citas_hoy_count">$citas_hoy_count</h2>
                            <i class="bi bi-calendar-check text-primary fs-2"></i>
                        </div>
                    </div>
                </div>
                <div class="col-6 col-lg-3">
                    <div class="dash-kpi-card bg-med-teal h-100">
                        <span class="kpi-label-medentia">Pacientes</span>
                        <div class="d-flex align-items-center justify-content-between">
                            <h2 class="kpi-value-medentia counter-up m-0" data-value="$t_pac">$t_pac</h2>
                            <i class="bi bi-people text-teal-clinical fs-2" style="color: var(--md-teal-clinical);"></i>
                        </div>
                    </div>
                </div>
                <div class="col-6 col-lg-3">
                    <div class="dash-kpi-card bg-med-cyan h-100">
                        <span class="kpi-label-medentia">Cargos</span>
                        <div class="d-flex align-items-center justify-content-between">
                            <h2 class="kpi-value-medentia counter-up m-0" data-value="$val_cargos_f" data-is-k="true">$str_cargos_k</h2>
                            <i class="bi bi-wallet2 text-cyan fs-2"></i>
                        </div>
                    </div>
                </div>
                <div class="col-6 col-lg-3">
                    <div class="dash-kpi-card bg-med-deep h-100">
                        <span class="kpi-label-medentia">Abonos</span>
                        <div class="d-flex align-items-center justify-content-between">
                            <h2 class="kpi-value-medentia counter-up m-0" data-value="$val_abonos_f" data-is-k="true">$str_abonos_k</h2>
                            <i class="bi bi-cash-stack text-blue-deep fs-2" style="color: var(--md-blue-deep);"></i>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Sección: Próximas Citas con Timeline -->
            <div class="row g-4">
                <div class="col-12 col-lg-8 offset-lg-2">
                    <h5 class="plus-jakarta fw-black mb-4">$tit_citas</h5>
                    <div class="bg-white rounded-4 p-4 shadow-sm" style="border: 2px solid #19B7A5; min-height: 350px;">
                        <div class="d-flex justify-content-between align-items-center mb-4">
                            <p class="text-muted m-0 small fw-bold">ACTIVIDAD PROGRAMADA RECIENTE</p>
                            <a href="../views/agenda_main.pl" class="btn btn-sm btn-outline-primary rounded-pill px-3">Ver Agenda Completa</a>
                        </div>
HTML

    if (@proximas_citas == 0) {
        print '<div class="text-center py-5"><p class="text-muted small fw-bold">Sin actividad programada en los próximos 7 días.</p></div>\\n';
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
                </div>\\n};
        }
    }

    print <<HTML;
                    </div>
                </div>
            </div>
            
            <!-- Botón flotante para Consulta Express móvil -->
            <button class="fab-btn-v2 pulse-fab d-lg-none" onclick="window.location.href='../views/render_consultas.pl'" title="Consulta">
                <span class="material-icons">medical_services</span>
            </button>
            
        </div>
    </div>
</div>
HTML"""

if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + new_layout + content[end_idx:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replacement successful")
else:
    print(f"Indices not found: start_idx={start_idx}, end_idx={end_idx}")
