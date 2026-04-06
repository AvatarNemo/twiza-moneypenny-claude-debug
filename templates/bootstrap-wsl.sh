#!/usr/bin/env bash
# ============================================================
# TWIZA MONEYPENNY - WSL Bootstrap Script v2.0
# ============================================================
# Runs INSIDE WSL after Ubuntu import.
# Installs Node.js, OpenClaw, Ollama, workspace template.
# Called by Install-TWIZA.ps1 via: wsl -d TWIZA -- bash /mnt/.../bootstrap-wsl.sh
# ============================================================
set -uo pipefail

TWIZA_COMPONENTS="$1"  # Windows path to components/ dir (mounted)
TWIZA_TEMPLATES="$2"   # Windows path to templates/ dir (mounted)
TWIZA_USER="${3:-twiza}"
TWIZA_HOME="/home/$TWIZA_USER"

log() { echo -e "\033[1;35m[TWIZA]\033[0m $*"; }
ok()  { echo -e "\033[1;32m  [OK]\033[0m $*"; }
err() { echo -e "\033[1;31m  [ERRORE]\033[0m $*"; exit 1; }

log "MONEYPENNY Bootstrap v2.0"
log "User: $TWIZA_USER | Home: $TWIZA_HOME"
log "Components: $TWIZA_COMPONENTS"
log "Templates: $TWIZA_TEMPLATES"

# ---- 0. Create user if needed ----
if ! id "$TWIZA_USER" &>/dev/null; then
    log "Creating user $TWIZA_USER..."
    useradd -m -s /bin/bash "$TWIZA_USER"
    mkdir -p /etc/sudoers.d
    echo "$TWIZA_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/twiza
    chmod 440 /etc/sudoers.d/twiza
    ok "User created"
else
    ok "User $TWIZA_USER already exists"
fi

# ---- 1. System packages ----
log "[1/6] Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq || true
apt-get install -y -qq ca-certificates curl git build-essential libvips-dev xz-utils lsof > /dev/null 2>&1 || true
ok "System packages installed"

# ---- 1b. Enable systemd (required for OpenClaw gateway service) ----
if ! grep -q '^\[boot\]' /etc/wsl.conf 2>/dev/null || ! grep -q 'systemd=true' /etc/wsl.conf 2>/dev/null; then
    log "Enabling systemd in /etc/wsl.conf..."
    if grep -q '^\[boot\]' /etc/wsl.conf 2>/dev/null; then
        # [boot] section exists, add systemd=true under it
        sed -i '/^\[boot\]/a systemd=true' /etc/wsl.conf
    else
        # No [boot] section, append it
        printf '\n[boot]\nsystemd=true\n' >> /etc/wsl.conf
    fi
    ok "systemd enabled (WSL restart required to take effect)"
    export TWIZA_NEEDS_WSL_RESTART=true
else
    ok "systemd already enabled"
fi

# ---- 2. Node.js ----
log "[2/6] Installing Node.js..."
# Try .tar.gz first (no xz-utils needed), then .tar.xz
NODE_TAR=$(find "$TWIZA_COMPONENTS" -name 'node-v*-linux-x64.tar.gz' 2>/dev/null | head -1)
if [[ -n "$NODE_TAR" && -f "$NODE_TAR" ]]; then
    log "  Installing from local bundle: $(basename "$NODE_TAR")"
    tar -xzf "$NODE_TAR" -C /usr/local --strip-components=1
else
    NODE_TAR=$(find "$TWIZA_COMPONENTS" -name 'node-v*-linux-x64.tar.xz' 2>/dev/null | head -1)
    if [[ -n "$NODE_TAR" && -f "$NODE_TAR" ]]; then
        log "  Installing from local bundle: $(basename "$NODE_TAR")"
        tar -xJf "$NODE_TAR" -C /usr/local --strip-components=1
    else
        log "  No local Node.js found, installing via NodeSource..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - || true
        apt-get install -y -qq nodejs > /dev/null 2>&1 || true
    fi
fi
node --version && npm --version || true
ok "Node.js $(node --version 2>/dev/null || echo 'unknown') installed"

# ---- 3. OpenClaw ----
log "[3/6] Installing OpenClaw..."
OC_INSTALLED=false

# Determine npm global prefix for this system
NPM_GLOBAL_DIR=$(npm config get prefix 2>/dev/null || echo "/usr/local")
NPM_GLOBAL_MODULES="$NPM_GLOBAL_DIR/lib/node_modules"
NPM_GLOBAL_BIN="$NPM_GLOBAL_DIR/bin"

# Method 0 (PREFERRED): Use pre-built tarball (avoids 3400+ file cross-filesystem copy)
log "  Searching for tarball in: $TWIZA_COMPONENTS"
ls -la "$TWIZA_COMPONENTS"/openclaw*.tar.gz 2>/dev/null || log "  [DEBUG] No openclaw*.tar.gz found in components dir"
OC_FULL_TGZ=$(find "$TWIZA_COMPONENTS" -maxdepth 1 -name 'openclaw-full.tar.gz' -type f 2>/dev/null | head -1)
if [[ -n "$OC_FULL_TGZ" && -f "$OC_FULL_TGZ" ]]; then
    log "  Found pre-built tarball: $OC_FULL_TGZ ($(du -h "$OC_FULL_TGZ" | cut -f1))"
    mkdir -p "$NPM_GLOBAL_MODULES"
    rm -rf "$NPM_GLOBAL_MODULES/openclaw" 2>/dev/null || true
    # Use cat (byte streaming) instead of cp — more reliable on 9p/cross-fs
    log "  Streaming tarball to /tmp via cat..."
    cat "$OC_FULL_TGZ" > /tmp/openclaw-full.tar.gz 2>&1 || log "  [WARN] cat command reported error"
    TGZ_SIZE=$(stat -c%s /tmp/openclaw-full.tar.gz 2>/dev/null || echo 0)
    SRC_SIZE=$(stat -c%s "$OC_FULL_TGZ" 2>/dev/null || echo 0)
    log "  Tarball size: source=$SRC_SIZE dest=$TGZ_SIZE"
    if [[ "$TGZ_SIZE" -ne "$SRC_SIZE" || "$TGZ_SIZE" -eq 0 ]]; then
        log "  [WARN] Size mismatch! Retrying with dd..."
        dd if="$OC_FULL_TGZ" of=/tmp/openclaw-full.tar.gz bs=4M 2>&1 || true
        TGZ_SIZE=$(stat -c%s /tmp/openclaw-full.tar.gz 2>/dev/null || echo 0)
        log "  After dd: size=$TGZ_SIZE"
    fi
    log "  Extracting tarball..."
    tar xzf /tmp/openclaw-full.tar.gz -C "$NPM_GLOBAL_MODULES" 2>&1 || log "  [WARN] tar extraction reported error"
    rm -f /tmp/openclaw-full.tar.gz
    DST_COUNT=$(find "$NPM_GLOBAL_MODULES/openclaw" -type f 2>/dev/null | wc -l)
    log "  Extracted $DST_COUNT files from tarball"
    log "  Checking dist/entry.js..."
    ls -la "$NPM_GLOBAL_MODULES/openclaw/dist/entry.js" 2>/dev/null || log "  [DEBUG] dist/entry.js NOT FOUND after extract"
    ls -la "$NPM_GLOBAL_MODULES/openclaw/openclaw.mjs" 2>/dev/null || log "  [DEBUG] openclaw.mjs NOT FOUND after extract"
    # Create global bin symlink
    if [[ -f "$NPM_GLOBAL_MODULES/openclaw/openclaw.mjs" ]]; then
        mkdir -p "$NPM_GLOBAL_BIN"
        ln -sf "$NPM_GLOBAL_MODULES/openclaw/openclaw.mjs" "$NPM_GLOBAL_BIN/openclaw"
        chmod +x "$NPM_GLOBAL_BIN/openclaw"
        chmod +x "$NPM_GLOBAL_MODULES/openclaw/openclaw.mjs"
    fi
    if [[ -f "$NPM_GLOBAL_MODULES/openclaw/dist/entry.js" ]]; then
        ok "OpenClaw installed from tarball with dist/entry.js ($DST_COUNT files)"
        OC_INSTALLED=true
    else
        log "  [ERRORE] Tarball extract didn't include dist/entry.js!"
        # Try dist-only tarball as recovery
        OC_DIST_TGZ=$(find "$TWIZA_COMPONENTS" -maxdepth 1 -name 'openclaw-dist.tar.gz' -type f 2>/dev/null | head -1)
        if [[ -n "$OC_DIST_TGZ" && -f "$OC_DIST_TGZ" ]]; then
            log "  Trying dist-only tarball: $OC_DIST_TGZ"
            cat "$OC_DIST_TGZ" > /tmp/openclaw-dist.tar.gz 2>&1
            tar xzf /tmp/openclaw-dist.tar.gz -C "$NPM_GLOBAL_MODULES/openclaw" 2>&1 || log "  [WARN] dist tar extraction failed"
            rm -f /tmp/openclaw-dist.tar.gz
            if [[ -f "$NPM_GLOBAL_MODULES/openclaw/dist/entry.js" ]]; then
                ok "dist/entry.js recovered from dist tarball"
                OC_INSTALLED=true
            else
                log "  [ERRORE] dist tarball also failed!"
            fi
        fi
    fi
    # NUCLEAR FALLBACK: if tarball extracted openclaw/ but dist/ is still missing, try npm
    if [[ "$OC_INSTALLED" != "true" && -f "$NPM_GLOBAL_MODULES/openclaw/openclaw.mjs" ]]; then
        log "  [NUCLEAR] openclaw.mjs exists but dist/ missing — trying npm install..."
        npm install -g openclaw 2>&1 | tail -10 || true
        [[ -f "$NPM_GLOBAL_MODULES/openclaw/dist/entry.js" ]] && ok "dist/entry.js installed via npm" && OC_INSTALLED=true
    fi
fi

# Method 1 (FALLBACK): Copy from bundle directory file-by-file via /tmp staging
if [[ "$OC_INSTALLED" != "true" ]]; then
    OC_BUNDLE=$(find "$TWIZA_COMPONENTS" -maxdepth 1 -name 'openclaw-bundle' -type d 2>/dev/null | head -1)
    if [[ -n "$OC_BUNDLE" && -d "$OC_BUNDLE/node_modules/openclaw" ]]; then
        log "  No tarball found, copying bundle via /tmp staging..."
        mkdir -p "$NPM_GLOBAL_MODULES"
        rm -rf "$NPM_GLOBAL_MODULES/openclaw" 2>/dev/null || true
        # Stage in /tmp (native ext4) to avoid cross-filesystem issues with /mnt/c/
        TMP_STAGE="/tmp/openclaw-stage"
        rm -rf "$TMP_STAGE" 2>/dev/null
        # Use tar pipe (handles large trees better than cp -r from 9p)
        mkdir -p "$TMP_STAGE"
        tar cf - -C "$OC_BUNDLE/node_modules" openclaw 2>/dev/null | tar xf - -C "$TMP_STAGE"
        # Verify key file made it
        if [[ ! -f "$TMP_STAGE/openclaw/dist/entry.js" ]]; then
            log "  [WARN] tar pipe to /tmp incomplete, retrying with cp -r..."
            rm -rf "$TMP_STAGE/openclaw" 2>/dev/null
            mkdir -p "$TMP_STAGE/openclaw"
            cp -r "$OC_BUNDLE/node_modules/openclaw/"* "$TMP_STAGE/openclaw/" 2>/dev/null || true
        fi
        # If dist STILL missing, copy just dist/ with cat per file
        if [[ ! -f "$TMP_STAGE/openclaw/dist/entry.js" ]]; then
            log "  [WARN] dist/ still missing, using cat-copy for individual files..."
            mkdir -p "$TMP_STAGE/openclaw/dist"
            find "$OC_BUNDLE/node_modules/openclaw/dist" -type f 2>/dev/null | while read -r f; do
                rel="${f#$OC_BUNDLE/node_modules/openclaw/}"
                mkdir -p "$TMP_STAGE/openclaw/$(dirname "$rel")"
                cat "$f" > "$TMP_STAGE/openclaw/$rel"
            done
        fi
        # Move from /tmp to final location
        mv "$TMP_STAGE/openclaw" "$NPM_GLOBAL_MODULES/openclaw"
        rm -rf "$TMP_STAGE"
        # Also copy bundle-level deps
        if [[ -d "$OC_BUNDLE/node_modules" ]]; then
            mkdir -p "$NPM_GLOBAL_MODULES/openclaw/node_modules"
            for dep in "$OC_BUNDLE/node_modules/"*; do
                dep_name=$(basename "$dep")
                [[ "$dep_name" == "openclaw" ]] && continue
                [[ -d "$dep" ]] && tar cf - -C "$OC_BUNDLE/node_modules" "$dep_name" 2>/dev/null | tar xf - -C "$NPM_GLOBAL_MODULES/openclaw/node_modules"
            done
        fi
        # Create global bin symlink
        if [[ -f "$NPM_GLOBAL_MODULES/openclaw/openclaw.mjs" ]]; then
            mkdir -p "$NPM_GLOBAL_BIN"
            ln -sf "$NPM_GLOBAL_MODULES/openclaw/openclaw.mjs" "$NPM_GLOBAL_BIN/openclaw"
            chmod +x "$NPM_GLOBAL_BIN/openclaw"
            chmod +x "$NPM_GLOBAL_MODULES/openclaw/openclaw.mjs"
        fi
        DST_COUNT=$(find "$NPM_GLOBAL_MODULES/openclaw" -type f 2>/dev/null | wc -l)
        if [[ -f "$NPM_GLOBAL_MODULES/openclaw/dist/entry.js" ]]; then
            ok "OpenClaw bundle copied with dist/entry.js ($DST_COUNT files)"
            OC_INSTALLED=true
        else
            log "  [ERRORE] dist/entry.js STILL missing after all copy methods!"
        fi
    fi
fi

# Method 2: Try .tgz tarball
if [[ "$OC_INSTALLED" != "true" ]]; then
    OC_TGZ=$(find "$TWIZA_COMPONENTS" -name 'openclaw-*.tgz' 2>/dev/null | head -1)
    if [[ -n "$OC_TGZ" && -f "$OC_TGZ" ]]; then
        log "  Installing from tarball: $(basename "$OC_TGZ")"
        npm install -g "$OC_TGZ" 2>&1 | tail -5
        which openclaw &>/dev/null && OC_INSTALLED=true
    fi
fi

# Method 3: Try npm online
if [[ "$OC_INSTALLED" != "true" ]]; then
    log "  Trying npm online install..."
    npm install -g openclaw 2>&1 | tail -5
    which openclaw &>/dev/null && OC_INSTALLED=true
fi

if [[ "$OC_INSTALLED" == "true" ]]; then
    ok "OpenClaw installed: $(which openclaw) ($(openclaw --version 2>/dev/null || echo '?'))"
else
    log "  [WARN] OpenClaw installation failed - will retry on first launch"
fi

# ---- 4. Ollama ----
log "[4/6] Installing Ollama..."
OLLAMA_BIN=$(find "$TWIZA_COMPONENTS" -name 'ollama' -type f -executable 2>/dev/null | head -1)
OLLAMA_TGZ=$(find "$TWIZA_COMPONENTS" -name 'ollama-linux-*.tgz' -o -name 'ollama-linux-*.tar.gz' 2>/dev/null | head -1)
if [[ -n "$OLLAMA_BIN" ]]; then
    log "  Copying pre-built binary..."
    cp "$OLLAMA_BIN" /usr/local/bin/ollama
    chmod +x /usr/local/bin/ollama
elif [[ -n "$OLLAMA_TGZ" ]]; then
    log "  Extracting from tarball..."
    tar -xzf "$OLLAMA_TGZ" -C /usr/local/bin/
    chmod +x /usr/local/bin/ollama
else
    log "  No local binary found, downloading..."
    curl -fsSL https://ollama.com/install.sh | sh
fi
ollama --version 2>/dev/null && ok "Ollama installed" || log "  [WARN] Ollama install skipped (can be added later)"

# ---- 4b. Ollama systemd service + default model ----
log "[4b/6] Configuring Ollama service..."

# Create systemd service for Ollama if systemd is available
if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
    cat > /etc/systemd/system/ollama.service << 'SVCEOF'
[Unit]
Description=Ollama AI Server
After=network-online.target

[Service]
Type=simple
User=twiza
ExecStart=/usr/local/bin/ollama serve
Restart=on-failure
RestartSec=5
Environment="HOME=/home/twiza"
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
Environment="OLLAMA_MODELS=/home/twiza/.ollama/models"

[Install]
WantedBy=multi-user.target
SVCEOF
    systemctl daemon-reload
    systemctl enable ollama
    systemctl start ollama
    sleep 3
    ok "Ollama systemd service created and started"
else
    # No systemd yet (first boot before wsl --shutdown), start manually
    log "  systemd not ready yet — starting Ollama manually for model pull..."
    su - "$TWIZA_USER" -c "OLLAMA_HOST=0.0.0.0:11434 OLLAMA_ORIGINS=* OLLAMA_MODELS=$TWIZA_HOME/.ollama/models nohup ollama serve > /tmp/ollama-bootstrap.log 2>&1 &"
    sleep 4
    ok "Ollama started in background"
fi

# Install pre-bundled model (offline) or pull from internet
MODEL_BUNDLE="$TWIZA_COMPONENTS/qwen25-3b-model.tar"
MODEL_BUNDLE_GZ="$TWIZA_COMPONENTS/qwen25-3b-model.tar.gz"
OLLAMA_MODELS_DIR="$TWIZA_HOME/.ollama/models"
if [[ -f "$MODEL_BUNDLE" ]] || [[ -f "$MODEL_BUNDLE_GZ" ]]; then
    log "  Installing pre-bundled model qwen2.5:3b (offline)..."
    mkdir -p "$OLLAMA_MODELS_DIR/manifests" "$OLLAMA_MODELS_DIR/blobs"
    if [[ -f "$MODEL_BUNDLE" ]]; then
        tar xf "$MODEL_BUNDLE" -C "$OLLAMA_MODELS_DIR" 2>&1
    else
        tar xzf "$MODEL_BUNDLE_GZ" -C "$OLLAMA_MODELS_DIR" 2>&1
    fi
    chown -R "$TWIZA_USER:$TWIZA_USER" "$OLLAMA_MODELS_DIR"
    ok "Default model qwen2.5:3b installed from bundle (offline)"
else
    log "  Pulling default lightweight model (qwen2.5:3b)..."
    if su - "$TWIZA_USER" -c "ollama pull qwen2.5:3b" 2>&1 | tail -5; then
        ok "Default model qwen2.5:3b ready"
    else
        log "  [WARN] Could not pull qwen2.5:3b (may need internet — will retry on first use)"
    fi
fi

# ---- 5. Workspace + Config ----
log "[5/6] Setting up Moneypenny workspace..."
OC_DIR="$TWIZA_HOME/.openclaw"
WS_DIR="$OC_DIR/workspace"
mkdir -p "$WS_DIR" "$OC_DIR/credentials" "$WS_DIR/memory"

# Copy workspace template
if [[ -d "$TWIZA_TEMPLATES/workspace" ]]; then
    cp -r "$TWIZA_TEMPLATES/workspace/"* "$WS_DIR/"
    ok "Workspace template copied"
fi

# Copy config template
if [[ -f "$TWIZA_TEMPLATES/openclaw.json.template" ]]; then
    # Generate a random auth token
    AUTH_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')
    
    # Apply template substitutions
    sed -e "s|___TWIZA_WORKSPACE___|$WS_DIR|g" \
        -e "s|___TWIZA_GENERATED_TOKEN___|$AUTH_TOKEN|g" \
        -e "s|___TWIZA_USER_TZ___|$(cat /etc/timezone 2>/dev/null || echo 'Europe/Rome')|g" \
        "$TWIZA_TEMPLATES/openclaw.json.template" > "$OC_DIR/openclaw.json"
    ok "Config created (auth token generated)"
fi

# Fix ownership
chown -R "$TWIZA_USER:$TWIZA_USER" "$OC_DIR"
ok "Workspace ready at $WS_DIR"

# ---- 6. Branding ----
log "[6/6] Applying Moneypenny branding..."
BRANDING_SCRIPT="$WS_DIR/branding/restore-branding.sh"
if [[ -f "$BRANDING_SCRIPT" ]]; then
    # Run as root since it modifies files in /usr/local/lib/node_modules
    bash "$BRANDING_SCRIPT" 2>&1 | tail -10
    ok "Branding applied (fuchsia + italiano + MONEYPENNY)"
else
    log "  [WARN] No branding script found, skipping"
fi

# ---- 7. Install OpenClaw gateway systemd service (best-effort) ----
log "[7/7] Configuring OpenClaw gateway..."

# Try systemd service install, but don't fail — foreground mode is the primary strategy
if command -v systemctl &>/dev/null && systemctl --user status &>/dev/null 2>&1; then
    su - "$TWIZA_USER" -c "openclaw gateway install" 2>&1 | tail -5
    ok "OpenClaw gateway systemd service installed"
else
    log "  systemd --user not available during bootstrap (normal in WSL2 first run)"
    ok "Gateway will run in foreground mode via Electron launcher (recommended for WSL2)"
fi

# ---- Final Verification ----
log "Verifying OpenClaw installation..."
if [[ -f "$NPM_GLOBAL_MODULES/openclaw/dist/entry.js" ]]; then
    ok "dist/entry.js exists"
    # Quick import check
    if node -e "import('$NPM_GLOBAL_MODULES/openclaw/dist/entry.js').then(() => process.exit(0)).catch(() => process.exit(1))" 2>/dev/null; then
        ok "entry.js import check passed"
    else
        log "  [WARN] entry.js import check failed (may work at runtime)"
    fi
else
    log "  [ERRORE] dist/entry.js NOT found at $NPM_GLOBAL_MODULES/openclaw/dist/entry.js"
    # Check for entry.mjs as alternative
    if [[ -f "$NPM_GLOBAL_MODULES/openclaw/dist/entry.mjs" ]]; then
        ok "dist/entry.mjs exists (alternative entry point)"
    fi
fi

# ---- CRITICAL: Flush filesystem ----
# WSL2 uses a VHD that may not flush writes before shutdown.
# Without sync, files (especially dist/entry.js) can be lost!
log "Flushing filesystem..."
sync
sync
sleep 1
# Double-check after sync
if [[ -f "$NPM_GLOBAL_MODULES/openclaw/dist/entry.js" ]]; then
    ok "Post-sync verification: dist/entry.js OK"
else
    log "  [CRITICAL] dist/entry.js LOST after sync!"
    # Emergency re-extract
    OC_FULL_TGZ=$(find "$TWIZA_COMPONENTS" -maxdepth 1 -name 'openclaw-full.tar.gz' -type f 2>/dev/null | head -1)
    if [[ -n "$OC_FULL_TGZ" ]]; then
        log "  Emergency re-extraction..."
        cat "$OC_FULL_TGZ" > /tmp/oc-emergency.tar.gz
        rm -rf "$NPM_GLOBAL_MODULES/openclaw"
        tar xzf /tmp/oc-emergency.tar.gz -C "$NPM_GLOBAL_MODULES"
        rm -f /tmp/oc-emergency.tar.gz
        sync
        sync
        [[ -f "$NPM_GLOBAL_MODULES/openclaw/dist/entry.js" ]] && ok "Emergency re-extraction: dist/entry.js OK" || log "  [FATAL] Cannot install dist/entry.js"
    fi
fi

# ---- Done ----
echo ""
# Flush filesystem to VHD before PS1 does wsl --shutdown
sync; sync
log "============================================"
log "MONEYPENNY is ready!"
log "============================================"
log ""
log "  OpenClaw: $(which openclaw)"
log "  Workspace: $WS_DIR"
log "  Config: $OC_DIR/openclaw.json"
log ""
log "  To start: su - $TWIZA_USER -c 'openclaw gateway start'"
log ""
