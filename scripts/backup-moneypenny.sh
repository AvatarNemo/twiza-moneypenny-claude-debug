#!/usr/bin/env bash
#
# MONEYPENNY Backup Script
# ========================
# Crea backup incrementali dei file che mi rendono unica
# Destinazione: C:\Users\chris\Documents\MP Backup\YYYYMMDD_NN\
#
# Usage: bash ~/.openclaw/workspace/scripts/backup-moneypenny.sh
#

set -euo pipefail

BACKUP_ROOT="/mnt/c/Users/chris/Documents/MP Backup"
WORKSPACE="$HOME/.openclaw/workspace"
CONFIG="$HOME/.openclaw/openclaw.json"
DATE=$(date +%Y%m%d)

# Trova il prossimo numero progressivo per oggi
COUNTER=1
while [[ -d "$BACKUP_ROOT/${DATE}_$(printf '%02d' $COUNTER)" ]]; do
    ((COUNTER++))
done
BACKUP_DIR="$BACKUP_ROOT/${DATE}_$(printf '%02d' $COUNTER)"

echo "🦾 MONEYPENNY Backup"
echo "===================="
echo "Destinazione: $BACKUP_DIR"
echo ""

mkdir -p "$BACKUP_DIR/workspace/memory"
mkdir -p "$BACKUP_DIR/workspace/branding"
mkdir -p "$BACKUP_DIR/workspace/media"
mkdir -p "$BACKUP_DIR/config"

# 1. File identità
echo "📝 [1/5] Copiando file identità..."
for f in SOUL.md USER.md IDENTITY.md AGENTS.md HEARTBEAT.md TOOLS.md MEMORY.md; do
    [[ -f "$WORKSPACE/$f" ]] && cp "$WORKSPACE/$f" "$BACKUP_DIR/workspace/"
done

# 2. Memory files
echo "🧠 [2/5] Copiando memoria..."
cp -r "$WORKSPACE/memory/"*.md "$BACKUP_DIR/workspace/memory/" 2>/dev/null || true

# 3. Branding
echo "🎨 [3/5] Copiando branding..."
cp -r "$WORKSPACE/branding/"* "$BACKUP_DIR/workspace/branding/" 2>/dev/null || true

# 4. Media
echo "🖼️ [4/5] Copiando media..."
cp -r "$WORKSPACE/media/"* "$BACKUP_DIR/workspace/media/" 2>/dev/null || true

# 5. Config (SANITIZED - rimuove API keys per sicurezza)
echo "⚙️ [5/5] Copiando config (con API keys)..."
cp "$CONFIG" "$BACKUP_DIR/config/openclaw.json"

# Calcola dimensione
SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo ""
echo "===================="
echo "✅ Backup completato!"
echo "📁 Path: $BACKUP_DIR"
echo "📦 Dimensione: $SIZE"
echo ""

# Mantieni solo gli ultimi 14 backup (7 giorni x 2 backup/giorno)
echo "🧹 Pulizia backup vecchi..."
ls -dt "$BACKUP_ROOT"/*/ 2>/dev/null | tail -n +15 | xargs rm -rf 2>/dev/null || true
echo "✅ Mantenuti ultimi 14 backup"
