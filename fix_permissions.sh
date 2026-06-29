#!/bin/bash
# Script de Estabilización de Permisos - Software Dental Mexicano (SDM)
# Ejecute este script en el servidor de HostGator para corregir Errores 500 de permisos.

echo "Iniciando corrección de permisos para SDM..."

# 1. Establecer permisos 755 para todos los scripts Perl
find . -name "*.pl" -exec chmod 755 {} \;
echo "✅ Scripts .pl establecidos en 755"

# 2. Establecer permisos para el directorio de sesiones
if [ -d "auth/sessions" ]; then
    chmod 755 auth/sessions
    echo "✅ Directorio auth/sessions establecido en 755"
else
    mkdir -p auth/sessions
    chmod 755 auth/sessions
    echo "✅ Directorio auth/sessions creado y establecido en 755"
fi

# 3. Asegurar finales de línea Unix (LF) - Por si acaso
find . -name "*.pl" -exec sed -i 's/\r$//' {} \;
echo "✅ Finales de línea forzados a Unix (LF)"

echo "¡Listo! El sistema debería ser ejecutable ahora."
