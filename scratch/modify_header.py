import sys

file_path = "c:/xampp/htdocs/ospulso/utils/sub_sidebar.pl"
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Make diamond-header-compact transparent and simple
content = content.replace(
    '<div class="diamond-header-compact d-flex justify-content-between align-items-center">',
    '<div class="diamond-header-compact d-flex justify-content-between align-items-center bg-transparent border-0 shadow-none pt-3 pb-0">'
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Header made transparent")
