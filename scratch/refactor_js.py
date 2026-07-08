import sys
import re

# 1. Refactor pacientes_spa.js
file_path_pacientes = "c:/xampp/htdocs/ospulso/js/pacientes_spa.js"
with open(file_path_pacientes, 'r', encoding='utf-8') as f:
    content_pac = f.read()

# Replace document.addEventListener('DOMContentLoaded', function() { with our init pattern
init_start_pac = """(function() {
function initPacientesSpa() {
    if (window._pacientesSpaInitialized) return;
    window._pacientesSpaInitialized = true;
"""
content_pac = content_pac.replace("document.addEventListener('DOMContentLoaded', function() {", init_start_pac)

# The end of the file has:
# });
# We need to replace the last }); with the end of the IIFE
# Let's find the last });
last_idx = content_pac.rfind("});")
if last_idx != -1:
    init_end_pac = """}
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initPacientesSpa);
    } else {
        initPacientesSpa();
    }
})();"""
    content_pac = content_pac[:last_idx] + init_end_pac + content_pac[last_idx+3:]

with open(file_path_pacientes, 'w', encoding='utf-8') as f:
    f.write(content_pac)


# 2. Refactor agenda_spa_new.js
file_path_agenda = "c:/xampp/htdocs/ospulso/js/agenda_spa_new.js"
with open(file_path_agenda, 'r', encoding='utf-8') as f:
    content_ag = f.read()

init_start_ag = """(function() {
function initAgendaSpa() {
    if (window._agendaSpaInitialized) {
        // Just re-run render if it's already initialized but DOM was replaced
        if (typeof renderAgenda === 'function') renderAgenda();
        return;
    }
    window._agendaSpaInitialized = true;
"""

# Wait, agenda_spa_new.js uses $(document).ready(function() {
# Let's check what it uses. I need to view agenda_spa_new.js first.
