import sys
import re

file_path = "c:/xampp/htdocs/ospulso/views/render_dashboard_principal.pl"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the beginning of sub render_dashboard_principal to remove initials, menu registry, allowed modules.
# We need to inject `use utils::sub_sidebar qw(render_sidebar render_sidebar_footer);` at the top? No, it's safer to `require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');` or similar, but we can just use `require` or add it to the top.

# We will just replace from line 32 to 79 and from 349 to 442.
# Actually, let's use regex.

# 1. Add require at the top
content = content.replace("use Time::Local;\n", "use Time::Local;\nrequire File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');\n")

# 2. Remove initials code
content = re.sub(r"my \$iniciales = '';\n    my \@nombres = split\(/\\s\+/, \$usuario\);\n    \$iniciales \.= uc\(substr\(\$nombres\[0\], 0, 1\)\) if \@nombres > 0;\n    \$iniciales \.= uc\(substr\(\$nombres\[1\], 0, 1\)\) if \@nombres > 1;\n\n", "", content)

# 3. Remove menu reading
content = re.sub(r"    # --- CARGA DINÁMICA DE MENÚ SEGÚN ROL ---.*?    # Definir si es vista global\n", "    # Definir si es vista global\n", content, flags=re.DOTALL)

# 4. Replace sidebar HTML generation with render_sidebar
sidebar_pattern = re.compile(r'<link rel="stylesheet" href="\.\./css/expediente_completo\.css\?v=\$[^"]+">.*?<div class="sdm-content mt-4">', re.DOTALL)

replacement = """HTML
    utils::sub_sidebar::render_sidebar(
        usuario => $usuario,
        role => $role,
        id_medico => $id_medico,
        pagina_actual => 'dashboard'
    );
    print <<HTML;
        <div class="sdm-content mt-4">"""

content = sidebar_pattern.sub(replacement, content, count=1)

# 5. Replace footer HTML generation with render_sidebar_footer
footer_pattern = re.compile(r'                    </div>\n                </div>\n            </div>.*?</div>\n    </div>\n</div>\nHTML', re.DOTALL)

footer_replacement = """                    </div>
                </div>
            </div>
            
            <!-- Botón flotante para Consulta Express móvil -->
            <button class="fab-btn-v2 pulse-fab d-lg-none" onclick="window.location.href='../views/render_consultas.pl'" title="Consulta">
                <span class="material-icons">medical_services</span>
            </button>
HTML
    utils::sub_sidebar::render_sidebar_footer();
"""

content = footer_pattern.sub(footer_replacement, content, count=1)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
