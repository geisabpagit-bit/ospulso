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

# 2. Control estricto de concurrencia con detección de PID activo
if [ -f "$LOCK_FILE" ]; then
    PREV_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$PREV_PID" ] && kill -0 "$PREV_PID" 2>/dev/null; then
        log "ERROR: Ya existe una actualización en ejecución (PID: $PREV_PID). Abortando."
        exit 1
    else
        log "Aviso: Se detectó un bloqueo inactivo o huérfano (PID no activo: $PREV_PID). Liberando..."
        rm -f "$LOCK_FILE"
    fi
fi

echo "$$" > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM
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

# Limpiar posibles bloqueos huérfanos internos de Git (.git/index.lock, etc.)
rm -f .git/index.lock .git/refs/heads/main.lock 2>/dev/null || true
git merge --abort 2>/dev/null || true
git rebase --abort 2>/dev/null || true

FETCH_OUTPUT=$(git fetch origin main 2>&1)
FETCH_STATUS=$?
echo "$FETCH_OUTPUT" >> "$LOG_FILE"

if [ $FETCH_STATUS -eq 0 ]; then
    log "✅ git fetch completado."
else
    log "❌ Error en git fetch: $FETCH_OUTPUT"
    log "Restaurando datos y abortando."
    if [ -d "$BACKUP_DIR" ]; then
        \cp -rf "$BACKUP_DIR/"* dat/ 2>/dev/null || true
        rm -rf "$BACKUP_DIR"
    fi
    echo "1" > "$STATUS_FILE"
    rm -f "$LOCK_FILE"
    exit 1
fi

# Desactivar temporalmente marcas skip-worktree y assume-unchanged para permitir el reset
git ls-files -z dat/ | xargs -0 -r git update-index --no-skip-worktree --no-assume-unchanged 2>/dev/null || true

# Limpiar archivos no trackeados fuera de dat/ que pudieran bloquear el checkout/reset
git clean -fd -e dat -e dat/* >> "$LOG_FILE" 2>&1 || true

# Forzar sobreescritura de todo el working tree al estado de origin/main (elimina conflictos de 'not uptodate')
git checkout -f origin/main -- . >> "$LOG_FILE" 2>&1 || true

# Sincronizar el índice de Git directamente con origin/main
git reset --mixed origin/main >> "$LOG_FILE" 2>&1 || true

# Ejecutar git reset hard para alinear HEAD y working tree
RESET_OUTPUT=$(git reset --hard origin/main 2>&1)
RESET_STATUS=$?
echo "$RESET_OUTPUT" >> "$LOG_FILE"

# Fallback incondicional si el reset devolviera advertencia
if [ $RESET_STATUS -ne 0 ]; then
    log "Aviso: git reset inicial requirió forzado. Aplicando checkout forzado de rama (checkout -B main origin/main -f)..."
    RESET_OUTPUT=$(git checkout -B main origin/main -f 2>&1)
    RESET_STATUS=$?
    echo "$RESET_OUTPUT" >> "$LOG_FILE"
fi

if [ $RESET_STATUS -eq 0 ]; then
    log "✅ Sincronización de código con origin/main completada con éxito."
else
    log "❌ Error en sincronización Git: $RESET_OUTPUT"
    log "Restaurando datos y abortando."
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

# Re-aplicar skip-worktree universal sobre TODOS los archivos de /dat trackeados para que Git nunca vuelva a rastrearlos
git ls-files -z dat/ | xargs -0 -r git update-index --skip-worktree 2>/dev/null || true
log "✅ Blindaje skip-worktree re-activado sobre todos los archivos de /dat."

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

