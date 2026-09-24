import pandas as pd
import sys

try:
    df = pd.read_excel(r'c:\xampp\htdocs\ospulso\dat\catalogoUniversal.xlsx', sheet_name=None)
    for sheet_name, sheet_df in df.items():
        print(f"--- Sheet: {sheet_name} ---")
        print("Columns:", sheet_df.columns.tolist())
        print("Shape:", sheet_df.shape)
        print("First 5 rows:")
        print(sheet_df.head().to_string())
        print("\n")
except Exception as e:
    print(f"Error: {e}")
