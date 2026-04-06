#!/bin/bash
# Riapplica tutte le customizzazioni UI dopo un aggiornamento OpenClaw
set -e

UI_DIR="/home/chris/.nvm/versions/node/v24.13.1/lib/node_modules/openclaw/dist/control-ui"
PATCH_DIR="/home/chris/.openclaw/workspace/ui-patches"
WORKSPACE="/home/chris/.openclaw/workspace"

echo "🦾 Applicando patch UI Moneypenny..."

# 1. Favicon
echo "  → Favicon (Twiza logo)"
cp "$PATCH_DIR/favicon/favicon.svg" "$UI_DIR/favicon.svg"
cp "$PATCH_DIR/favicon/favicon-32.png" "$UI_DIR/favicon-32.png"
cp "$PATCH_DIR/favicon/favicon.ico" "$UI_DIR/favicon.ico" 2>/dev/null || true

# 2. Avatar utente
echo "  → Avatar utente (Christian DreamWorks)"
cp "$WORKSPACE/media/christian/05-dreamworks-avatar.jpg" "$UI_DIR/assets/user-avatar.jpg"

# 3. index.html patches (title + CSS)
echo "  → Patching index.html (title + font + avatar CSS)"
# Replace title
sed -i 's|<title>[^<]*</title>|<title>MONEYPENNY</title>|' "$UI_DIR/index.html"

# Add custom style block if not already present
if ! grep -q "font-size: 1.265rem" "$UI_DIR/index.html"; then
  sed -i '/<\/head>/i\    <style>\
      .message-content, .message-content p, .message-content li, .message-content code {\
        font-size: 1.265rem !important;\
        line-height: 1.6 !important;\
      }\
      .chat-avatar.user {\
        background-image: url('\''./assets/user-avatar.jpg'\'') !important;\
        background-size: cover !important;\
        background-position: center !important;\
        color: transparent !important;\
      }\
    </style>' "$UI_DIR/index.html"
fi

echo "✅ Patch applicate! Ricarica la pagina."
