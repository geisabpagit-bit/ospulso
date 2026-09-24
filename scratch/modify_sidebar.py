import sys

file_path = "c:/xampp/htdocs/ospulso/utils/sub_sidebar.pl"
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove OSPulso DIAMOND
brand_text = """            <div class="sidebar-brand-text lh-1">
                <h5 class="m-0 fw-black text-dark">OSPulso</h5>
                <small class="text-muted fw-bold" style="font-size: 0.6rem;">DIAMOND v3.8.0</small>
            </div>"""
content = content.replace(brand_text, "")

# 2. Add sidebar-text span to links
# Dashboard
content = content.replace(
    '<i class="bi bi-grid-1x2-fill text-primary me-2" style="font-size:1.2rem;"></i> Dashboard',
    '<i class="bi bi-grid-1x2-fill text-primary me-2" style="font-size:1.2rem;"></i> <span class="sidebar-text">Dashboard</span>'
)
# Modules
content = content.replace(
    '<span class="material-icons me-2" style="font-size:1.2rem; color: $style->{color}">$style->{icon}</span> $m->{title}',
    '<span class="material-icons me-2" style="font-size:1.2rem; color: $style->{color}">$style->{icon}</span> <span class="sidebar-text">$m->{title}</span>'
)
# Ajustes
content = content.replace(
    '<i class="bi bi-gear-fill me-2 text-secondary" style="font-size:1rem;"></i> Ajustes',
    '<i class="bi bi-gear-fill me-2 text-secondary" style="font-size:1rem;"></i> <span class="sidebar-text">Ajustes</span>'
)

# 3. Remove Hola, $usuario
profile_hero = """                <div class="profile-hero text-start">
                    <h4 class="text-truncate m-0 text-white fw-bold" style="max-width: 60vw; letter-spacing: -0.5px;">Hola, $usuario</h4>
                </div>"""
content = content.replace(profile_hero, "")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("sub_sidebar.pl modified successfully")
