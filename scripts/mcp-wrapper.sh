#!/usr/bin/env bash
set -euo pipefail
# playwright-wrapper-mcp — wraps npx @playwright/mcp with isolated + CDP + secrets + init-page + storage-state.
# Used by opencode.jsonc: ["bash", "scripts/mcp-wrapper.sh"] (folder stays wsl-chrome on disk)
# Env: CDP_PORT, CDP_HOST, AUTH_* (from .secrets.env via --secrets)
# Note: Chromium-family (Brave/Chrome/Edge) attach via CDP. Firefox does NOT support CDP
# (WebDriver BiDi), so don't launch Firefox for --cdp-endpoint — see launch-browser-debug.ps1.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PORT="${CDP_PORT:-9222}"
HOST="$(bash "$SCRIPT_DIR/wsl-host-ip.sh")"
CDP_ENDPOINT="http://${HOST}:${PORT}"

ARGS=(
  --cdp-endpoint "$CDP_ENDPOINT"
  --isolated
  --caps devtools
)

# --secrets: dotenv file loaded by Playwright MCP into process.env for init-page
if [[ -f "$ROOT_DIR/.secrets.env" ]]; then
  ARGS+=(--secrets "$ROOT_DIR/.secrets.env")
elif [[ -f "$ROOT_DIR/config/.secrets.env" ]]; then
  ARGS+=(--secrets "$ROOT_DIR/config/.secrets.env")
fi

# --storage-state: optional seed (skip if missing/empty)
STATE="$ROOT_DIR/config/storage-state.json"
if [[ -f "$STATE" ]] && [[ -s "$STATE" ]] && python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert d.get('cookies') is not None" "$STATE" 2>/dev/null; then
  ARGS+=(--storage-state "$STATE")
fi

# --init-page: auto-login until redirect (env-driven). Compiled JS preferred if TS not available.
INIT_TS="$ROOT_DIR/scripts/init-auth.ts"
INIT_JS="$ROOT_DIR/scripts/init-auth.js"
if [[ -f "$INIT_TS" ]]; then
  ARGS+=(--init-page "$INIT_TS")
elif [[ -f "$INIT_JS" ]]; then
  ARGS+=(--init-page "$INIT_JS")
fi

# Allow extra args passthrough (e.g. --headless for CI)
exec npx -y @playwright/mcp@latest "${ARGS[@]}" "$@"
