import sys

file_path = "c:/xampp/htdocs/ospulso/css/ospulso_master_v2.css"
append_css = """

/* Sidebar Compact Mode */
.diamond-sidebar.compact {
    width: 80px !important;
}
.diamond-sidebar.compact .sidebar-brand .avatar-diamond {
    margin: 0 auto;
}
.diamond-sidebar.compact .sidebar-text {
    display: none !important;
}
.diamond-sidebar.compact .sub-link {
    justify-content: center !important;
    padding: 0.75rem !important;
}
.diamond-sidebar.compact .sub-link i,
.diamond-sidebar.compact .sub-link .material-icons {
    margin-right: 0 !important;
}
.diamond-sidebar.compact .sidebar-footer {
    padding: 1rem !important;
}
"""

with open(file_path, 'a', encoding='utf-8') as f:
    f.write(append_css)
print("CSS appended")
