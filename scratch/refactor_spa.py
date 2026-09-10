import sys

# 1. PACIENTES SPA JS
file_path_pac = "c:/xampp/htdocs/ospulso/js/pacientes_spa.js"
with open(file_path_pac, 'r', encoding='utf-8') as f:
    content_pac = f.read()

target_pac_start = "document.addEventListener('DOMContentLoaded', function() {"
replacement_pac_start = """function initPacientesSpa() {
    if (!document.getElementById('tablaPacientes')) return;
"""

if target_pac_start in content_pac:
    content_pac = content_pac.replace(target_pac_start, replacement_pac_start)
    last_idx = content_pac.rfind("});")
    
    replacement_pac_end = """}
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initPacientesSpa);
} else {
    initPacientesSpa();
}
document.addEventListener('spa:contentLoaded', initPacientesSpa);
"""
    if last_idx != -1:
        content_pac = content_pac[:last_idx] + replacement_pac_end + content_pac[last_idx+3:]
    
    with open(file_path_pac, 'w', encoding='utf-8') as f:
        f.write(content_pac)
    print("pacientes_spa.js refactored")

# 2. AGENDA SPA JS
file_path_ag = "c:/xampp/htdocs/ospulso/js/agenda_spa_new.js"
with open(file_path_ag, 'r', encoding='utf-8') as f:
    content_ag = f.read()

# Instead of parsing the huge $(document).ready block, we just prepend our listener.
# Since spa_router skips reloading _spa.js libraries, the event handlers bound inside $(document).ready() will REMAIN valid.
# The only thing we need is to re-render the view when the user navigates back via SPA.
prepend_ag = """
document.addEventListener('spa:contentLoaded', function() {
    if (document.querySelector('.main-container-agenda')) {
        if (typeof initClock === 'function') initClock();
        if (typeof loadFormMetadata === 'function') loadFormMetadata();
        if (typeof loadContext === 'function') loadContext();
    }
});
"""

if "spa:contentLoaded" not in content_ag:
    content_ag = prepend_ag + content_ag
    with open(file_path_ag, 'w', encoding='utf-8') as f:
        f.write(content_ag)
    print("agenda_spa_new.js refactored")
