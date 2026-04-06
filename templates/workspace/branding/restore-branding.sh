#!/usr/bin/env bash
#
# MONEYPENNY Branding Restore Script v2
# =======================================
# Run this after every `openclaw update` to re-apply custom branding.
# Usage: bash ~/.openclaw/workspace/branding/restore-branding.sh
#
# LESSONS LEARNED (2026-03-31):
# - NEVER inject code into the JS bundle's template literals (language picker)
#   It breaks the login flow. Use HTML + MutationObserver instead.
# - Docs redirect sed: must stop at backticks too → [^"\x60]* not [^"]*
# - localStorage key for locale is "openclaw.i18n.locale" (not openclaw-settings)
# - Step 5b (language picker) and step 7 (model manager) are now HTML-injected,
#   zero JS bundle modification → unbreakable across updates.
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_DIR="$(dirname "$(which node)")"
OPENCLAW_PKG="$NODE_DIR/../lib/node_modules/openclaw"
CONTROL_UI="$OPENCLAW_PKG/dist/control-ui"

if [[ ! -d "$CONTROL_UI" ]]; then
    echo "❌ Control UI not found at $CONTROL_UI"
    exit 1
fi

echo "🦾 MONEYPENNY Branding Restore v2"
echo "==================================="
echo "Control UI: $CONTROL_UI"
echo ""

# --- 1. Static Assets ---
echo "📁 [1/8] Copying static assets (favicons)..."
cp "$SCRIPT_DIR/favicon.ico"    "$CONTROL_UI/favicon.ico"
cp "$SCRIPT_DIR/favicon.svg"    "$CONTROL_UI/favicon.svg"
cp "$SCRIPT_DIR/favicon-32.png" "$CONTROL_UI/favicon-32.png"
echo "  ✅ favicon.ico, favicon.svg, favicon-32.png"

# --- 2. index.html base ---
echo "📄 [2/8] Patching index.html..."
HTML="$CONTROL_UI/index.html"

# Title
sed -i 's|<title>[^<]*</title>|<title>MONEYPENNY</title>|' "$HTML"

# Remove OpenClaw SVG favicon link if present
sed -i '/<link rel="icon" type="image\/svg+xml" href="\.\/favicon\.svg"/d' "$HTML"

# Add Google Fonts if not already present
if ! grep -q "fonts.googleapis.com/css2.*Titillium" "$HTML"; then
    sed -i '/<meta charset="UTF-8"/a\    <link rel="preconnect" href="https://fonts.googleapis.com">\n    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n    <link href="https://fonts.googleapis.com/css2?family=Titillium+Web:ital,wght@0,200;0,300;0,400;0,600;0,700;0,900;1,200;1,300;1,400;1,600;1,700\&display=swap" rel="stylesheet">' "$HTML"
fi
echo "  ✅ Title → MONEYPENNY, Google Fonts Titillium Web, SVG favicon link removed"

# --- 3. JS Bundle (OpenClaw → MONEYPENNY) ---
echo "🔧 [3/8] Patching JS bundle (safe seds only)..."
JS_FILE=$(find "$CONTROL_UI/assets" -name 'index-*.js' -not -name '*.bak' | head -1)
if [[ -n "$JS_FILE" ]]; then
    cp "$JS_FILE" "${JS_FILE}.bak"

    # Replace visible "OpenClaw" strings — ONLY safe context replacements
    sed -i 's/alt="OpenClaw"/alt="MONEYPENNY"/g' "$JS_FILE"
    sed -i 's|login-gate__title">OpenClaw</div>|login-gate__title">MONEYPENNY</div>|g' "$JS_FILE"
    sed -i 's|sidebar-brand__title">OpenClaw</span>|sidebar-brand__title">MONEYPENNY</span>|g' "$JS_FILE"
    # Fallback: quoted strings in JS context
    perl -i -pe 's/(?<=[,=(])"OpenClaw"(?=[,;)\]}])/"MONEYPENNY"/g' "$JS_FILE"

    REMAINING=$(grep -oP 'OpenClaw' "$JS_FILE" | grep -v 'includeInOpenClaw\|OpenClawGroup\|openclaw' | wc -l)
    echo "  ✅ JS patched: $(basename "$JS_FILE") (remaining visible 'OpenClaw': $REMAINING)"
else
    echo "  ⚠️  No JS bundle found!"
fi

# --- 4. CSS Bundle (fonts + fuchsia + user avatar) ---
echo "🎨 [4/8] Patching CSS bundle..."
CSS_FILE=$(find "$CONTROL_UI/assets" -name 'index-*.css' -not -name '*.bak' | head -1)
if [[ -n "$CSS_FILE" ]]; then
    cp "$CSS_FILE" "${CSS_FILE}.bak"

    # Font: Titillium Web as primary body font
    sed -i 's/--font-body: *"[^"]*", *"Inter"/--font-body: "Titillium Web", "Inter"/' "$CSS_FILE"
    sed -i 's/--font-body: *"Inter"/--font-body: "Titillium Web", "Inter"/' "$CSS_FILE"

    # Fuchsia Shakazamba Colors
    # Dark theme — #ff5c5c → #FF0080
    sed -i 's/--accent: *#ff5c5c/--accent:#FF0080/g' "$CSS_FILE"
    sed -i 's/--accent-hover: *#ff7070/--accent-hover:#FF1A93/g' "$CSS_FILE"
    sed -i 's/--accent-muted: *#ff5c5c/--accent-muted:#FF0080/g' "$CSS_FILE"
    sed -i 's/--accent-subtle: *#ff5c5c1a/--accent-subtle:#FF00801a/g' "$CSS_FILE"
    sed -i 's/--accent-subtle: *rgba(255, 92, 92, .1)/--accent-subtle:rgba(255, 0, 128, .12)/g' "$CSS_FILE"
    sed -i 's/--accent-glow: *rgba(255, 92, 92, .2)/--accent-glow:rgba(255, 0, 128, .25)/g' "$CSS_FILE"
    sed -i 's/--primary: *#ff5c5c/--primary:#FF0080/g' "$CSS_FILE"
    sed -i 's/--ring: *#ff5c5c/--ring:#FF0080/g' "$CSS_FILE"

    # Light theme — #dc2626 → #CC0066
    sed -i 's/--accent: *#dc2626/--accent:#CC0066/g' "$CSS_FILE"
    sed -i 's/--accent-hover: *#ef4444/--accent-hover:#E60073/g' "$CSS_FILE"
    sed -i 's/--accent-muted: *#dc2626/--accent-muted:#CC0066/g' "$CSS_FILE"
    sed -i 's/--accent-subtle: *rgba(220, 38, 38, .08)/--accent-subtle:rgba(214, 0, 110, .1)/g' "$CSS_FILE"
    sed -i 's/--accent-glow: *rgba(220, 38, 38, .1)/--accent-glow:rgba(214, 0, 110, .15)/g' "$CSS_FILE"
    sed -i 's/--primary: *#dc2626/--primary:#CC0066/g' "$CSS_FILE"
    sed -i 's/--ring: *#dc2626/--ring:#CC0066/g' "$CSS_FILE"

    # User Avatar Override
    USER_AVATAR_SRC="$SCRIPT_DIR/user-avatar.jpg"
    if [[ -f "$USER_AVATAR_SRC" ]]; then
        cp "$USER_AVATAR_SRC" "$CONTROL_UI/assets/user-avatar.jpg"
        if ! grep -q 'user-avatar.jpg' "$CSS_FILE"; then
            echo '.chat-avatar.user{background:url(./user-avatar.jpg) center/cover no-repeat!important;color:transparent!important;border-color:color-mix(in srgb,var(--accent) 30%,transparent)!important}' >> "$CSS_FILE"
        fi
        echo "  ✅ User avatar override applied"
    fi

    echo "  ✅ CSS patched: $(basename "$CSS_FILE")"
else
    echo "  ⚠️  No CSS bundle found!"
fi

# --- 5. Italian Locale (JS bundle registration) ---
echo "🇮🇹 [5/8] Installing Italian translation..."
IT_LOCALE="$SCRIPT_DIR/it-locale.js"
if [[ -f "$IT_LOCALE" && -n "$JS_FILE" ]]; then
    cp "$IT_LOCALE" "$CONTROL_UI/assets/it-locale.js"

    if ! grep -q '`it`' "$JS_FILE"; then
        python3 - "$JS_FILE" << 'PYEOF'
import re, sys

js_file = sys.argv[1]
with open(js_file, "r") as f:
    content = f.read()

changes = 0

# 1. Add 'it' to supported locales array
content, n = re.subn(
    r'(\[`zh-CN`,`zh-TW`,`pt-BR`,`de`,`es`\])',
    r'[`zh-CN`,`zh-TW`,`pt-BR`,`de`,`es`,`it`]',
    content
)
changes += n

# 2. Add loader entry after es
es_pattern = re.compile(r'(es:\{exportName:`es`,loader:\(\)=>(\w+)\(\(\)=>import\(`\./es-[^`]+`\),\[\],import\.meta\.url\)\})')
m = es_pattern.search(content)
if m:
    es_entry = m.group(1)
    func_name = m.group(2)
    it_entry = ',it:{exportName:`it`,loader:()=>' + func_name + '(()=>import(`./it-locale.js`),[],import.meta.url)}'
    content = content.replace(es_entry, es_entry + it_entry)
    changes += 1

# 3. Add Italian to languages list
content, n = re.subn(
    r'es:`Español \(Spanish\)`\}',
    'es:`Español (Spanish)`,it:`Italiano`}',
    content
)
changes += n

with open(js_file, "w") as f:
    f.write(content)

print(f"  ✅ Italian locale registered ({changes} patches)")
PYEOF
    else
        echo "  ✅ Italian locale already registered"
    fi
else
    echo "  ⚠️  Italian locale file or JS bundle not found, skipping"
fi

# --- 6. Docs link → local docs-moneypenny ---
echo "📚 [6/8] Redirecting docs links..."
if [[ -n "$JS_FILE" ]]; then
    if grep -q 'docs\.openclaw\.ai' "$JS_FILE"; then
        # IMPORTANT: stop at both " and backtick to avoid corrupting template literals
        sed -i 's|https://docs\.openclaw\.ai[^"\x60]*|/docs-moneypenny/index.html|g' "$JS_FILE"
        sed -i 's|href:`/docs-moneypenny/index.html`,external:!0|href:`/docs-moneypenny/index.html`|g' "$JS_FILE"
        echo "  ✅ Docs links redirected to local TWIZA docs"
    else
        echo "  ✅ Docs links already redirected"
    fi
fi

# Copy docs-moneypenny to control-ui
DOCS_MP_SRC="$SCRIPT_DIR/../docs-moneypenny"
DOCS_MP_DEST="$CONTROL_UI/docs-moneypenny"
if [[ -d "$DOCS_MP_SRC" ]]; then
    mkdir -p "$DOCS_MP_DEST"
    cp -r "$DOCS_MP_SRC"/* "$DOCS_MP_DEST/"
    echo "  ✅ docs-moneypenny copied ($(ls "$DOCS_MP_SRC"/*.html 2>/dev/null | wc -l) pages)"
else
    echo "  ⚠️  docs-moneypenny not found at $DOCS_MP_SRC"
fi

# --- 7. Language Picker + Model Manager (HTML injection — SAFE) ---
# ⚠️ NEVER inject these into the JS bundle! It breaks the login flow.
# Use standalone DOM scripts via index.html + MutationObserver instead.
echo "🌐🧠 [7/8] Injecting Language Picker + Model Manager (HTML-safe mode)..."
if ! grep -q 'mp-lang-picker' "$HTML"; then
    cat >> "$HTML" << 'HTMLEOF'
    <style>
      .mp-lang-picker{display:flex;align-items:center;margin-right:4px}
      .mp-lang-select{appearance:none;-webkit-appearance:none;background:var(--bg-secondary,#1a1a2e);color:var(--text-primary,#e0e0e0);border:1px solid var(--border,#333);border-radius:8px;padding:4px 24px 4px 8px;font-size:13px;cursor:pointer;outline:none;transition:border-color .15s,box-shadow .15s;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%23999' stroke-width='2'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E");background-repeat:no-repeat;background-position:right 6px center;min-width:0;max-width:140px}
      .mp-lang-select:hover,.mp-lang-select:focus{border-color:#FF0080}
      .mp-lang-select option{background:var(--bg-primary,#0d0d1a);color:var(--text-primary,#e0e0e0)}
      .mp-model-btn{display:flex;align-items:center;justify-content:center;width:32px;height:32px;border-radius:8px;border:1px solid var(--border-primary,#333);background:var(--bg-secondary,#1a1a1a);color:var(--text-primary,#fff);cursor:pointer;font-size:16px;transition:all .2s;margin-right:4px}
      .mp-model-btn:hover{border-color:#FF0080;background:#FF0080;color:#fff}
    </style>
    <script>
    (function(){
      var LANGS={en:"English","zh-CN":"\u4e2d\u6587(\u7b80)","zh-TW":"\u4e2d\u6587(\u7e41)","pt-BR":"Portugu\u00eas",de:"Deutsch",es:"Espa\u00f1ol",it:"Italiano"};
      function getStoredLocale(){try{var v=localStorage.getItem("openclaw.i18n.locale");if(v)return v}catch(e){}return null}
      function setStoredLocale(v){try{localStorage.setItem("openclaw.i18n.locale",v)}catch(e){}}
      function injectPicker(){
        var topbar=document.querySelector(".topbar-status");
        if(!topbar||!topbar.parentNode)return;
        if(topbar.parentNode.querySelector(".mp-lang-picker"))return;
        var cur=getStoredLocale()||"en";
        var wrap=document.createElement("div");wrap.className="mp-lang-picker";wrap.title="Language";
        var sel=document.createElement("select");sel.className="mp-lang-select";
        for(var k in LANGS){var opt=document.createElement("option");opt.value=k;opt.textContent=LANGS[k];if(k===cur)opt.selected=true;sel.appendChild(opt)}
        sel.onchange=function(){setStoredLocale(sel.value);location.reload()};
        wrap.appendChild(sel);
        topbar.parentNode.insertBefore(wrap,topbar);
      }
      function injectModelBtn(){
        var topbar=document.querySelector(".topbar-status");
        if(!topbar||!topbar.parentNode)return;
        if(topbar.parentNode.querySelector(".mp-model-btn"))return;
        var btn=document.createElement("button");btn.className="mp-model-btn";btn.title="Gestione Modelli AI";btn.innerHTML="\ud83e\udde0";
        btn.onclick=function(){window.open("/docs-moneypenny/model-manager.html","_twiza_models","width=1100,height=800")};
        topbar.parentNode.insertBefore(btn,topbar);
      }
      function inject(){injectPicker();injectModelBtn()}
      inject();
      new MutationObserver(function(){inject()}).observe(document.body,{childList:true,subtree:true});
    })();
    </script>
HTMLEOF
    echo "  ✅ Language Picker + Model Manager injected via HTML (safe mode)"
else
    echo "  ✅ Language Picker + Model Manager already present"
fi

# --- 8. Patch CSP to allow Ollama connect ---
echo "🔌 [8/8] Patching CSP for Ollama..."
GW_JS=$(find "$OPENCLAW_PKG/dist" -name 'gateway-cli-*.js' -not -name '*.bak' 2>/dev/null | head -1)
if [ -n "$GW_JS" ] && [ -f "$GW_JS" ] && grep -q "connect-src 'self' ws: wss:\"" "$GW_JS"; then
    sed -i "s|connect-src 'self' ws: wss:\"|connect-src 'self' ws: wss: http://localhost:11434 http://127.0.0.1:11434\"|" "$GW_JS"
    echo "  ✅ CSP patched for Ollama connect"
elif [ -n "$GW_JS" ] && [ -f "$GW_JS" ] && grep -q "http://localhost:11434" "$GW_JS"; then
    echo "  ✅ CSP already patched for Ollama"
else
    echo "  ⚠️ Gateway JS not found or CSP format changed — manual patch needed"
fi

# --- Summary ---
echo ""
echo "==================================="
echo "🦾 Branding restored! (v2 — battle-tested)"
echo ""
echo "Now do ONE of:"
echo "  • Restart gateway:  openclaw gateway restart"
echo "  • Or just hard-refresh the browser: Ctrl+Shift+R"
echo ""
