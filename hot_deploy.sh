#!/bin/bash
# ==============================================================================
# OSPulso - Hot Deploy / Actualización en Caliente
# ==============================================================================
# Script de despliegue atómico para servidores Linux / cPanel.
# Actualiza código fuente desde origin/main protegiendo al 100% la carpeta /dat.
# ==============================================================================

# 1. Doble candado de posicionamiento: Auto-posicionarse en la raíz (public_html)
DIR_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR_RAIZ"

LOG_FILE="dat/hot_deploy.log"
LOCK_FILE="dat/hot_deploy.lock"
STATUS_FILE="dat/hot_deploy.status"
BACKUP_DIR="dat_backup_seguridad_temp"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 2. Control estricto de concurrencia
if [ -f "$LOCK_FILE" ]; then
    # Verificar si el lock está huérfano (más de 10 minutos de antigüedad)
    if test "$(find "$LOCK_FILE" -mmin +10 2>/dev/null)"; then
        log "Aviso: Se detectó un lock huérfano de más de 10 minutos. Limpiando..."
        rm -f "$LOCK_FILE"
    else
        log "ERROR: Ya existe una actualización en ejecución. Abortando."
        exit 1
    fi
fi

touch "$LOCK_FILE"
log "========================================================================"
log ">>> INICIANDO ACTUALIZACIÓN EN CALIENTE DE OSPULSO (Git Hot-Deploy)"
log "Directorio de trabajo: $DIR_RAIZ"

# 3. Respaldo de seguridad previo de /dat
log "Paso 1: Respaldando datos de producción en $BACKUP_DIR..."
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

if [ -d "dat" ]; then
    \cp -rf dat/* "$BACKUP_DIR/" 2>/dev/null || true
    log "✅ Respaldo previo de /dat completado con éxito."
else
    log "⚠️ Directorio /dat no encontrado. Continuando..."
fi

# 4. Descarga y forzado del código fuente desde Git
log "Paso 2: Sincronizando con origin/main..."
if git fetch origin main >> "$LOG_FILE" 2>&1; then
    log "✅ git fetch completado."
else
    log "❌ Error en git fetch. Restaurando datos y abortando."
    echo "1" > "$STATUS_FILE"
    rm -f "$LOCK_FILE"
    exit 1
fi

# Desactivar marcas skip-worktree que puedan impedir el reset
git update-index --no-skip-worktree dat/.htaccess dat/catalogo_cards.dat dat/roles_catalogo.dat 2>/dev/null || true
git ls-files -v | grep '^S' | awk '{print $2}' | xargs -r git update-index --no-skip-worktree 2>/dev/null || true

# Limpiar archivos no trackeados fuera de dat/ que pudieran bloquear el checkout/reset
git clean -fd -e dat -e dat/* >> "$LOG_FILE" 2>&1 || true

if git reset --hard origin/main >> "$LOG_FILE" 2>&1; then
    log "✅ git reset --hard origin/main completado."
else
    log "❌ Error en git reset. Restaurando datos y abortando."
    if [ -d "$BACKUP_DIR" ]; then
        \cp -rf "$BACKUP_DIR/"* dat/ 2>/dev/null || true
        rm -rf "$BACKUP_DIR"
    fi
    echo "1" > "$STATUS_FILE"
    rm -f "$LOCK_FILE"
    exit 1
fi

# 5. Restauración íntegra y silenciosa de los datos reales de producción
log "Paso 3: Restaurando datos reales de producción sobre /dat..."
if [ -d "$BACKUP_DIR" ]; then
    \cp -rf "$BACKUP_DIR/"* dat/ 2>/dev/null || true
    rm -rf "$BACKUP_DIR"
    log "✅ Datos reales de producción restaurados al 100%."
fi

log "Paso 4: Ejecutando fix_permissions.sh..."
if [ -f "fix_permissions.sh" ]; then
    bash fix_permissions.sh >> "$LOG_FILE" 2>&1
    log "✅ Permisos 755 y saltos de línea LF aplicados."
else
    log "⚠️ fix_permissions.sh no encontrado. Asignando chmod 755 manual..."
    find api views utils -name "*.pl" -exec chmod 755 {} \; 2>/dev/null || true
fi

# 7. Liberar bloqueo y registrar éxito
echo "0" > "$STATUS_FILE"
rm -f "$LOCK_FILE"
log ">>> ACTUALIZACIÓN EN CALIENTE FINALIZADA CON ÉXITO."
log "========================================================================"
exit 0

