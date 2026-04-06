#!/usr/bin/env bash
# Quick check: is branding applied? Returns 0 if OK, 1 if needs restore.
CONTROL_UI="$(dirname "$(which node)")/../lib/node_modules/openclaw/dist/control-ui"
JS_FILE=$(find "$CONTROL_UI/assets" -name 'index-*.js' -not -name '*.bak' 2>/dev/null | head -1)
[[ -z "$JS_FILE" ]] && exit 1
# If sidebar still says OpenClaw, branding is missing
grep -q 'sidebar-brand__title">OpenClaw</span>' "$JS_FILE" 2>/dev/null && exit 1
# If no fuchsia color override in CSS, branding is missing
CSS_FILE=$(find "$CONTROL_UI/assets" -name 'index-*.css' -not -name '*.bak' 2>/dev/null | head -1)
grep -q 'Titillium Web' "$CSS_FILE" 2>/dev/null || exit 1
# Check user avatar is deployed
grep -q 'user-avatar.jpg' "$CSS_FILE" 2>/dev/null || exit 1
[[ -f "$CONTROL_UI/assets/user-avatar.jpg" ]] || exit 1
# Check Italian locale registered
grep -q '`it`' "$JS_FILE" 2>/dev/null || exit 1
[[ -f "$CONTROL_UI/assets/it-locale.js" ]] || exit 1
# Check topbar language picker (now in HTML, not JS bundle)
HTML_FILE="$CONTROL_UI/index.html"
grep -q 'mp-lang-picker' "$HTML_FILE" 2>/dev/null || exit 1
# Check docs-moneypenny directory with all required pages
DOCS_DIR="$CONTROL_UI/docs-moneypenny"
for page in index.html capabilities.html connectors.html models.html privacy.html getting-started.html channels.html gateway.html nodes.html troubleshooting.html; do
    [[ -f "$DOCS_DIR/$page" ]] || exit 1
done
[[ -f "$DOCS_DIR/moneypenny-avatar.jpg" ]] || exit 1
# Check no external docs.openclaw.ai links remain
grep -q 'docs\.openclaw\.ai' "$JS_FILE" 2>/dev/null && exit 1
exit 0
