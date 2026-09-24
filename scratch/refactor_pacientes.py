import sys

file_path = "c:/xampp/htdocs/ospulso/views/pacientes.pl"

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
# <link rel="stylesheet" href="../css/ospulso_master_v2.css">
# <link rel="stylesheet" href="../css/tabla_pacientes.css">
# 
# <div class="container-fluid p-0 p-md-3">

target_layout = """print <<HTML;
<link rel="stylesheet" href="../css/ospulso_master_v2.css">
<link rel="stylesheet" href="../css/tabla_pacientes.css">

<div class="container-fluid p-0 p-md-3">"""

replacement_layout = """print <<HTML;
<link rel="stylesheet" href="../css/ospulso_master_v2.css">
<link rel="stylesheet" href="../css/tabla_pacientes.css">
HTML

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    pagina_actual => 'pacientes'
);

print <<HTML;
<div class="container-fluid p-0 p-md-3">"""

content = content.replace(target_layout, replacement_layout)

# 3. Add footer closing
# It currently has:
# render_bottom_nav('pacientes');
# print "</body></html>\n";

target_footer = """render_bottom_nav('pacientes');
print "</body></html>\\n";"""

replacement_footer = """utils::sub_sidebar::render_sidebar_footer();
render_bottom_nav('pacientes');
print "</body></html>\\n";"""

content = content.replace(target_footer, replacement_footer)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done")
