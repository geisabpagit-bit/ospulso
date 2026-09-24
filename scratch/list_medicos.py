import os

dat_dir = r"c:\xampp\htdocs\ospulso\dat"
usuarios_path = os.path.join(dat_dir, "usuarios.dat")

with open(usuarios_path, 'r', encoding='utf-8') as f:
    lines = [l.strip() for l in f.readlines()]

print("=== MÉDICOS REGISTRADOS EN USUARIOS.DAT ===")
medicos = []
for line in lines[1:]:
    if not line or line.startswith('#'): continue
    parts = line.split('!')
    if len(parts) >= 6 and 'Medico' in parts[5]:
        medicos.append({'id': parts[0], 'nombre': parts[1], 'correo': parts[2], 'rol': parts[5], 'tenant': parts[6]})
        print(f"ID: {parts[0]} | Nombre: {parts[1]} | Correo: {parts[2]} | Rol: {parts[5]} | Tenant: {parts[6]}")

print(f"\nTotal médicos encontrados: {len(medicos)}")
