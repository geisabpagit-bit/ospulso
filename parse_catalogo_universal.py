import pandas as pd
import os

excel_path = r'c:\xampp\htdocs\ospulso\dat\catalogoUniversal.xlsx'
out_dir = r'c:\xampp\htdocs\ospulso\dat'

# Dictionaries for ID tracking
deps = {}      # name -> ID
cats = {}      # (dep_id, cat_name) -> ID
provs = {}     # name -> ID
items = []     # list of dicts
precios = []   # list of dicts

dep_id_counter = 1
cat_id_counter = 1
prov_id_counter = 1
item_id_counter = 1
precio_id_counter = 1

def get_dep_id(name):
    global dep_id_counter
    name = str(name).strip().upper()
    if name not in deps:
        deps[name] = dep_id_counter
        dep_id_counter += 1
    return deps[name]

def get_cat_id(dep_id, name):
    global cat_id_counter
    name = str(name).strip().upper()
    key = (dep_id, name)
    if key not in cats:
        cats[key] = cat_id_counter
        cat_id_counter += 1
    return cats[key]

def get_prov_id(name, ptype="GENERAL"):
    global prov_id_counter
    if pd.isna(name):
        return ""
    name = str(name).strip().upper()
    if name not in provs:
        provs[name] = prov_id_counter
        prov_id_counter += 1
    return provs[name]

def safe_str(val):
    if pd.isna(val): return ""
    return str(val).strip().replace('\n', ' ').replace('\r', '').replace('|', '-')

def parse_sheet(sheet_name, df):
    global item_id_counter, precio_id_counter
    
    # If df has a single column with '|', we need to split it
    if len(df.columns) == 1 and '|' in df.columns[0]:
        col_names = df.columns[0].split('|')
        new_data = []
        for row in df.itertuples(index=False):
            val = str(row[0])
            new_data.append(val.split('|'))
        df = pd.DataFrame(new_data, columns=col_names)
        
    for index, row in df.iterrows():
        try:
            # Common fields
            codigo_sku = safe_str(row.get('codigo_sku', ''))
            
            dep_name = safe_str(row.get('departamento', 'SIN DEPARTAMENTO'))
            cat_name = safe_str(row.get('categoria', 'SIN CATEGORIA'))
            
            dep_id = get_dep_id(dep_name)
            cat_id = get_cat_id(dep_id, cat_name)
            
            # Concept mapping
            concepto = ''
            if 'concepto_servicio' in row: concepto = safe_str(row['concepto_servicio'])
            elif 'concepto_estudio' in row: concepto = safe_str(row['concepto_estudio'])
            elif 'concepto_cirugia' in row: concepto = safe_str(row['concepto_cirugia'])
            elif 'tipo_pieza_especimen' in row: concepto = safe_str(row['tipo_pieza_especimen'])
            else: concepto = "SIN CONCEPTO"
            
            # Provider mapping
            prov_name = ''
            if 'proveedor_medico' in row: prov_name = safe_str(row['proveedor_medico'])
            elif 'proveedor_laboratorio' in row: prov_name = safe_str(row['proveedor_laboratorio'])
            elif 'proveedor' in row: prov_name = safe_str(row['proveedor'])
            elif 'patologo_responsable' in row: prov_name = safe_str(row['patologo_responsable'])
            
            prov_id = get_prov_id(prov_name)
            
            # Other item fields
            aplica_iva = safe_str(row.get('aplica_iva', '0'))
            if aplica_iva == '': aplica_iva = '0'
            indicaciones = safe_str(row.get('indicaciones_preparacion', ''))
            
            tiempo_entrega = ''
            if 'tiempo_entrega' in row: tiempo_entrega = safe_str(row['tiempo_entrega'])
            elif 'tiempo_estancia' in row: tiempo_entrega = safe_str(row['tiempo_estancia'])
            
            # Append Item
            curr_item_id = item_id_counter
            items.append({
                'ID_ITEM': curr_item_id,
                'CODIGO_SKU': codigo_sku,
                'ID_CAT': cat_id,
                'CONCEPTO': concepto,
                'APLICA_IVA': aplica_iva,
                'INDICACIONES': indicaciones,
                'TIEMPO_ENTREGA': tiempo_entrega
            })
            item_id_counter += 1
            
            # Price logic depending on sheet
            sn = sheet_name.lower()
            
            def add_price(tipo_tarifa, precio_publico, costo_proveedor="0"):
                global precio_id_counter
                if pd.isna(precio_publico) or str(precio_publico).strip() == '': return
                precios.append({
                    'ID_PRECIO': precio_id_counter,
                    'ID_ITEM': curr_item_id,
                    'TIPO_TARIFA': tipo_tarifa,
                    'PRECIO_PUBLICO': safe_str(precio_publico),
                    'COSTO_PROVEEDOR': safe_str(costo_proveedor),
                    'ID_PROV': prov_id
                })
                precio_id_counter += 1

            if 'consultas' in sn:
                # 'modalidad_turno', 'costo_proveedor', 'precio_publico', 'honorario_medico', 'margen_clinica'
                modalidad = safe_str(row.get('modalidad_turno', 'ESTANDAR'))
                add_price(modalidad.upper(), row.get('precio_publico', '0'), row.get('costo_proveedor', '0'))
                
            elif 'laboratorio santiago' in sn:
                add_price('LUNES_A_SABADO', row.get('precio_normal_lunes_sabado', '0'))
                add_price('DOMINGOS_Y_FESTIVOS', row.get('precio_domingos_festivos', '0'))
                
            elif 'rayos x' in sn:
                add_price('MATUTINO', row.get('precio_clinica_matutino', '0'), row.get('costo_proveedor_matutino', '0'))
                add_price('NOCTURNO', row.get('precio_clinica_nocturno', '0'), row.get('costo_proveedor_nocturno', '0'))
                add_price('FESTIVO', row.get('precio_clinica_festivo', '0'), row.get('costo_proveedor_festivo', '0'))
                
            elif 'laboratorio francisco' in sn:
                add_price('NORMAL', row.get('precio_clinica_normal', '0'), row.get('costo_proveedor_normal', '0'))
                add_price('FESTIVO', row.get('precio_clinica_festivo', '0'), row.get('costo_proveedor_festivo', '0'))
                
            elif 'ultrasonido' in sn:
                add_price('NORMAL', row.get('precio_normal', '0'))
                add_price('SABADO_TARDE_DOMINGO_FESTIVO', row.get('precio_sabado_tarde_domingo_festivo', '0'))
                
            elif 'cirugia' in sn:
                add_price('PAQUETE_TODO_INCLUIDO', row.get('precio_paquete_todo_incluido', '0'))
                add_price('PAQUETE_SOLO_CLINICA', row.get('precio_paquete_solo_clinica', '0'))
                
            elif 'patologia' in sn:
                add_price('NORMAL', row.get('precio_clinica', '0'), row.get('costo_dr', '0'))
                
            else:
                add_price('ESTANDAR', '0', '0')
        except Exception as e:
            print(f"Error at index {index} in {sheet_name}: {e}")

df_all = pd.read_excel(excel_path, sheet_name=None)
for sheet_name, df_sheet in df_all.items():
    parse_sheet(sheet_name, df_sheet)

# Write out the files
with open(os.path.join(out_dir, 'departamentos_QTSMP000116.dat'), 'w', encoding='utf-8') as f:
    f.write("ID_DEP|NOMBRE_DEP\n")
    for name, did in sorted(deps.items(), key=lambda x: x[1]):
        f.write(f"{did}|{name}\n")

with open(os.path.join(out_dir, 'categorias_QTSMP000116.dat'), 'w', encoding='utf-8') as f:
    f.write("ID_CAT|ID_DEP|NOMBRE_CAT\n")
    for (dep_id, name), cid in sorted(cats.items(), key=lambda x: x[1]):
        f.write(f"{cid}|{dep_id}|{name}\n")

with open(os.path.join(out_dir, 'proveedores_QTSMP000116.dat'), 'w', encoding='utf-8') as f:
    f.write("ID_PROV|TIPO|NOMBRE_PROVEEDOR\n")
    for name, pid in sorted(provs.items(), key=lambda x: x[1]):
        f.write(f"{pid}|GENERAL|{name}\n")

with open(os.path.join(out_dir, 'catalogo_items_QTSMP000116.dat'), 'w', encoding='utf-8') as f:
    f.write("ID_ITEM|CODIGO_SKU|ID_CAT|CONCEPTO|APLICA_IVA|INDICACIONES|TIEMPO_ENTREGA\n")
    for i in items:
        f.write(f"{i['ID_ITEM']}|{i['CODIGO_SKU']}|{i['ID_CAT']}|{i['CONCEPTO']}|{i['APLICA_IVA']}|{i['INDICACIONES']}|{i['TIEMPO_ENTREGA']}\n")

with open(os.path.join(out_dir, 'catalogo_precios_QTSMP000116.dat'), 'w', encoding='utf-8') as f:
    f.write("ID_PRECIO|ID_ITEM|TIPO_TARIFA|PRECIO_PUBLICO|COSTO_PROVEEDOR|ID_PROV\n")
    for p in precios:
        f.write(f"{p['ID_PRECIO']}|{p['ID_ITEM']}|{p['TIPO_TARIFA']}|{p['PRECIO_PUBLICO']}|{p['COSTO_PROVEEDOR']}|{p['ID_PROV']}\n")

print("Generacion de .dat exitosa.")
