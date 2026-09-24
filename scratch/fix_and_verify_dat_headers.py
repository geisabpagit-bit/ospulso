import os

dat_dir = r"c:\xampp\htdocs\ospulso\dat"

# 1. Fix pacientes.dat (remove trailing pipe on data rows & header)
pacientes_path = os.path.join(dat_dir, "pacientes.dat")
if os.path.exists(pacientes_path):
    with open(pacientes_path, 'r', encoding='utf-8-sig') as f:
        plines = [l.rstrip('\r\n') for l in f.readlines()]
    fixed_plines = []
    for i, line in enumerate(plines):
        if not line.strip():
            continue
        if i == 0:
            fixed_plines.append(line.rstrip('|'))
        else:
            if line.endswith('|') and len(line.split('|')) == 15:
                fixed_plines.append(line[:-1])
            else:
                fixed_plines.append(line)
    with open(pacientes_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(fixed_plines) + '\n')

# 2. Fix catalogo_cards.dat (header & separate merged line)
cat_cards_path = os.path.join(dat_dir, "catalogo_cards.dat")
cat_cards_content = (
    "CLAVE_SUBMENU|ARCHIVO_DESTINO|TÍTULO|DESCRIPCIÓN|ICONO_BS|COLOR_BS\n"
    "cat_config|views/manage_config.pl|Catálogos globales|Administración de datos Maestros y Tablas Generales.|bi-gear-fill|danger\n"
    "cat_catalogo_org|views/catalogo_servicios_org.pl|Catalogo de Servicios|Gestion de servicios y productos de la organizacion.|bi-tags-fill|warning\n"
)
with open(cat_cards_path, 'w', encoding='utf-8') as f:
    f.write(cat_cards_content)

# 3. Fix menu_cards.dat (header without comment '#', strip trailing pipes)
menu_cards_path = os.path.join(dat_dir, "menu_cards.dat")
if os.path.exists(menu_cards_path):
    with open(menu_cards_path, 'r', encoding='utf-8-sig') as f:
        mlines = [l.rstrip('\r\n') for l in f.readlines()]
    fixed_mlines = ["CLAVE_MENU|ARCHIVO_DESTINO|TÍTULO|DESCRIPCIÓN|ICONO_BS|COLOR_BS"]
    for line in mlines[1:]:
        if not line.strip() or line.strip().startswith('#'):
            continue
        row = line.rstrip('|')
        fixed_mlines.append(row)
    with open(menu_cards_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(fixed_mlines) + '\n')

# 4. Fix negocios.dat (strip BOM if present)
negocios_path = os.path.join(dat_dir, "negocios.dat")
if os.path.exists(negocios_path):
    with open(negocios_path, 'r', encoding='utf-8-sig') as f:
        ncontent = f.read()
    with open(negocios_path, 'w', encoding='utf-8') as f:
        f.write(ncontent)

# 5. Fix sub_especialidades.dat (trim spaces in header)
subespe_path = os.path.join(dat_dir, "sub_especialidades.dat")
if os.path.exists(subespe_path):
    with open(subespe_path, 'r', encoding='utf-8-sig') as f:
        slines = [l.rstrip('\r\n') for l in f.readlines()]
    if slines:
        slines[0] = "ID_ESPE|ID_SUBESPECIALIDAD|ESP_NOMBRE_SUBESPECIALIDAD"
    with open(subespe_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(slines) + '\n')

# 6. Fix roles.dat (header)
roles_path = os.path.join(dat_dir, "roles.dat")
if os.path.exists(roles_path):
    with open(roles_path, 'r', encoding='utf-8-sig') as f:
        rlines = [l.rstrip('\r\n') for l in f.readlines()]
    fixed_rlines = ["ROL|PUEDE_BUSCAR|MODULOS_PERMITIDOS"]
    for line in rlines[1:]:
        if not line.strip() or line.strip().startswith('#'):
            continue
        fixed_rlines.append(line)
    with open(roles_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(fixed_rlines) + '\n')

# 7. Fix roles_catalogo.dat (header)
roles_cat_path = os.path.join(dat_dir, "roles_catalogo.dat")
if os.path.exists(roles_cat_path):
    with open(roles_cat_path, 'r', encoding='utf-8-sig') as f:
        rclines = [l.rstrip('\r\n') for l in f.readlines()]
    fixed_rclines = ["ROL|SUB_ENLACES_PERMITIDOS"]
    for line in rclines[1:]:
        if not line.strip() or line.strip().startswith('#'):
            continue
        fixed_rclines.append(line)
    with open(roles_cat_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(fixed_rclines) + '\n')

print("All dat files fixed successfully.")
