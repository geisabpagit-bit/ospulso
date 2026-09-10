import sys
import re

file_path = "c:/xampp/htdocs/ospulso/views/agenda_main.pl"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Require sub_sidebar.pl
content = content.replace(
    "require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');",
    "require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');\nrequire File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_sidebar.pl');"
)

# 2. Add render_sidebar call
# It currently has:
# print <<HTML;
#     <!-- Datos de Sesión para JS -->
#     <input type="hidden" id="f_medico" value="$id_medico">
#     <script>
#         window.idPacientePre = "$id_paciente_pre";
#         window.nombrePacientePre = "$nombre_paciente_pre";
#     </script>
# 
#     <link rel="stylesheet" href="../css/agenda_diamond.css?v=4.2.0">
# 
#     <div class="main-container-agenda">

target_layout = """print <<HTML;
    <!-- Datos de Sesión para JS -->
    <input type="hidden" id="f_medico" value="$id_medico">
    <script>
        window.idPacientePre = "$id_paciente_pre";
        window.nombrePacientePre = "$nombre_paciente_pre";
    </script>

    <link rel="stylesheet" href="../css/agenda_diamond.css?v=4.2.0">

    <div class="main-container-agenda">"""

replacement_layout = """print <<HTML;
    <!-- Datos de Sesión para JS -->
    <input type="hidden" id="f_medico" value="$id_medico">
    <script>
        window.idPacientePre = "$id_paciente_pre";
        window.nombrePacientePre = "$nombre_paciente_pre";
    </script>

    <link rel="stylesheet" href="../css/agenda_diamond.css?v=4.2.0">
HTML

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    pagina_actual => 'agenda'
);

print <<HTML;
    <div class="main-container-agenda">"""

content = content.replace(target_layout, replacement_layout)

# 3. Add footer closing
# It currently has:
#     <script src="../js/agenda_spa_new.js?v=4.0.3_Premium"></script>
# </body>
# </html>
# HTML
# 
# render_bottom_nav('agenda');

target_footer = """    <script src="../js/agenda_spa_new.js?v=4.0.3_Premium"></script>
</body>
</html>
HTML

render_bottom_nav('agenda');"""

replacement_footer = """    <script src="../js/agenda_spa_new.js?v=4.0.3_Premium"></script>
HTML
utils::sub_sidebar::render_sidebar_footer();
print <<HTML;
</body>
</html>
HTML

render_bottom_nav('agenda');"""

content = content.replace(target_footer, replacement_footer)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
