import os
import glob

dat_dir = r"c:\xampp\htdocs\ospulso\dat"
files = sorted(glob.glob(os.path.join(dat_dir, "*.dat")))

print("=== DEEP DB AUDIT REPORT FOR DAT FILES ===")

for filepath in files:
    filename = os.path.basename(filepath)
    with open(filepath, 'r', encoding='utf-8-sig', errors='replace') as f:
        lines = [l.rstrip('\r\n') for l in f.readlines()]
    
    if not lines:
        print(f"\n[{filename}] - FILE EMPTY (0 bytes)")
        continue
    
    header = lines[0]
    delim = '!' if '!' in header else '|'
    header_cols = header.split(delim)
    
    data_lines = lines[1:]
    # Remove comment lines and blank lines
    non_comment_rows = [(idx+2, row) for idx, row in enumerate(data_lines) if row.strip() and not row.strip().startswith('#')]
    
    row_lengths = {}
    row_details = []
    
    for line_num, row in non_comment_rows:
        cols = row.split(delim)
        cnt = len(cols)
        row_lengths[cnt] = row_lengths.get(cnt, 0) + 1
        if cnt != len(header_cols):
            row_details.append((line_num, cnt, row))
            
    print(f"\nFile: {filename}")
    print(f"  Delimiter: '{delim}' | Header cols ({len(header_cols)}): {header_cols}")
    print(f"  Total Data Rows: {len(non_comment_rows)}")
    
    if header.startswith('#'):
        print(f"  [!] WARNING: Line 1 starts with comment '#' -> '{header}'")
        
    if row_lengths:
        print(f"  Row column distribution: {row_lengths}")
        if any(k != len(header_cols) for k in row_lengths.keys()):
            print(f"  [!] MISMATCH DETECTED: Header has {len(header_cols)} cols, but data has {list(row_lengths.keys())}")
            for lnum, cnt, rtext in row_details[:5]:
                print(f"      Row L{lnum} ({cnt} cols): {rtext}")
    else:
        print("  (No data rows)")

print("\n=== AUDIT COMPLETE ===")
