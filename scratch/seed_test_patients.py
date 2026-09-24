import os
import json
import datetime

dat_dir = r"c:\xampp\htdocs\ospulso\dat"
today_str = datetime.date.today().strftime("%Y-%m-%d")

# 1. Prepare Patients data
pacientes_path = os.path.join(dat_dir, "pacientes.dat")
pacientes_header = "ID_PACIENTE|ID_MEDICO|NOMBRE|RFC|CURP|CORREO|FECHA_NAC|SEXO|OCUPACION|ESTADO_CIVIL|NACIONALIDAD|TIPO_SANGRE|TELEFONO|TENANT"

pacientes_rows = [
    f"1|1020747209|Carlos Mendoza García|MEMC850412H34|MEMC850412HDFRRN09|carlos.mendoza@test.com|1985-04-12|Masculino|Ingeniero|Casado|Mexicana|O+|5512345678|1055007:706496",
    f"2|1088603479|María Fernanda López Reyes|LORM920820M56|LORM920820MDFPNN01|maria.lopez@test.com|1992-08-20|Femenino|Diseñadora|Soltera|Mexicana|A+|5598765432|1055007:591522"
]

with open(pacientes_path, 'w', encoding='utf-8') as f:
    f.write(pacientes_header + "\n" + "\n".join(pacientes_rows) + "\n")

# 2. Prepare Antecedentes data
antecedentes_path = os.path.join(dat_dir, "pacientes_antecedentes.dat")
antecedentes_header = "ID_PACIENTE|TUTOR|ANTECEDENTES_JSON|FECHA_ACTUALIZACION"

ant_p1 = {
    "heredofamiliares": {"hipertension": "Sí", "diabetes": "No", "cardiopatias": "No", "cancer": "No", "cancer_tipo": "", "alergias": "No", "alergias_especificar": ""},
    "personales_patologicos": {"cronicas": "No", "cronicas_especificar": "", "cirugias": "No", "cirugias_especificar": "", "hospitalizaciones": "No", "hospitalizaciones_especificar": "", "alergias": "Sí", "alergias_especificar": "Penicilina", "tratamientos": "No", "tratamientos_especificar": ""},
    "personales_no_patologicos": {"tabaquismo": "No", "tabaquismo_cantidad": "", "alcohol": "Ocasional", "alcohol_frecuencia": "Social", "drogas": "No", "drogas_tipo": "", "actividad_fisica": "Sí", "actividad_fisica_tipo": "Caminata", "alimentacion": "Balanceada", "alimentacion_otro": ""}
}

ant_p2 = {
    "heredofamiliares": {"hipertension": "No", "diabetes": "Sí", "cardiopatias": "No", "cancer": "No", "cancer_tipo": "", "alergias": "No", "alergias_especificar": ""},
    "personales_patologicos": {"cronicas": "No", "cronicas_especificar": "", "cirugias": "Sí", "cirugias_especificar": "Apendicectomía 2018", "hospitalizaciones": "No", "hospitalizaciones_especificar": "", "alergias": "No", "alergias_especificar": "", "tratamientos": "No", "tratamientos_especificar": ""},
    "personales_no_patologicos": {"tabaquismo": "No", "tabaquismo_cantidad": "", "alcohol": "No", "alcohol_frecuencia": "", "drogas": "No", "drogas_tipo": "", "actividad_fisica": "Sí", "actividad_fisica_tipo": "Yoga", "alimentacion": "Saludable", "alimentacion_otro": ""}
}

antecedentes_rows = [
    f"1||{json.dumps(ant_p1, ensure_ascii=False)}|{today_str}",
    f"2||{json.dumps(ant_p2, ensure_ascii=False)}|{today_str}"
]

with open(antecedentes_path, 'w', encoding='utf-8') as f:
    f.write(antecedentes_header + "\n" + "\n".join(antecedentes_rows) + "\n")

# 3. Prepare Citas data
citas_path = os.path.join(dat_dir, "citas.dat")
citas_header = "ID_CITA|ID_MEDICO|ID_PACIENTE|FECHA|HORA_INICIO|HORA_FIN|MOTIVO|NOTAS|ESTADO|EXTRA"

citas_rows = [
    f"101|1020747209|1|{today_str}|09:00|09:30|Consulta General de Valoración|Evaluación clínica inicial|Programada|",
    f"102|1088603479|2|{today_str}|10:00|10:30|Consulta Médica Preventiva|Revisión de rutina|Programada|"
]

with open(citas_path, 'w', encoding='utf-8') as f:
    f.write(citas_header + "\n" + "\n".join(citas_rows) + "\n")

# 4. Update contador_pacientes.dat to 2
contador_path = os.path.join(dat_dir, "contador_pacientes.dat")
with open(contador_path, 'w', encoding='utf-8') as f:
    f.write("2\n")

print("=== PACIENTES Y CITAS DE PRUEBA CREADOS EXITOSAMENTE ===")
print("Paciente 1 asignado a Médico 1020747209 (doctor 1): Carlos Mendoza García")
print("Paciente 2 asignado a Médico 1088603479 (doctor dos): María Fernanda López Reyes")
